import CodexWorkbenchCore
import Foundation

private final class AppTestRunner {
    private(set) var failures = 0

    func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !condition() else { return }
        failures += 1
        fputs("FAIL: \(file):\(line): \(message)\n", stderr)
    }
}

private final class RestartGatewayRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var restartOutcomes: [Result<Data, AccountGatewayError>]
    private let statusData: Data
    private var commands: [AccountCommand] = []

    init(
        restartOutcomes: [Result<Data, AccountGatewayError>],
        statusData: Data
    ) {
        self.restartOutcomes = restartOutcomes
        self.statusData = statusData
    }

    func run(_ command: AccountCommand) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        commands.append(command)
        if command.arguments.contains("status") {
            return statusData
        }
        guard !restartOutcomes.isEmpty else {
            throw AccountGatewayError.processFailed(99)
        }
        return try restartOutcomes.removeFirst().get()
    }

    func capturedArguments() -> [[String]] {
        lock.lock()
        defer { lock.unlock() }
        return commands.map(\.arguments)
    }
}

@main
private struct WorkbenchAppModelRestartTests {
    @MainActor
    static func main() async {
        let runner = AppTestRunner()
        await liveRejectionAndConfirmedRetry(runner)
        cancellation(runner)
        await successfulRestart(runner)
        await verificationMismatch(runner)
        guard runner.failures == 0 else { exit(1) }
        print("PASS: CodexWorkbenchAppTests")
    }

    @MainActor
    private static func liveRejectionAndConfirmedRetry(_ runner: AppTestRunner) async {
        let recorder = RestartGatewayRecorder(
            restartOutcomes: [
                .failure(.restartConfirmationRequired(.runningTask)),
                .failure(.codexDesktopLaunchFailed),
            ],
            statusData: payloadData(active: "hd-master", runtime: "running")
        )
        guard let fixture = try? makeModel(recorder: recorder, runtime: "idle") else {
            runner.expect(false, "Could not create rejection fixture")
            return
        }
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        fixture.model.requestRestartCurrentCodex()
        let rejectionObserved = await waitUntil {
            fixture.model.accountRestartConfirmation == .runningTask
                && fixture.model.accountRestartStage == nil
        }
        runner.expect(
            rejectionObserved,
            "A live backend rejection should restore the confirmation state"
        )
        runner.expect(
            recorder.capturedArguments().first
                == ["restart", "--profile", "hd-master"],
            "The first restart attempt must not carry an active-work override"
        )

        fixture.model.confirmRestartCurrentCodex()
        let confirmedFailureObserved = await waitUntil {
            fixture.model.accountRestartStage == nil
                && fixture.model.accountError?.contains("未能重新启动") == true
        }
        runner.expect(
            confirmedFailureObserved,
            "A confirmed retry should surface a later launch failure"
        )
        runner.expect(
            recorder.capturedArguments().dropFirst().first
                == ["restart", "--profile", "hd-master", "--allow-active"],
            "Only the confirmed retry may carry --allow-active"
        )
    }

    @MainActor
    private static func cancellation(_ runner: AppTestRunner) {
        let recorder = RestartGatewayRecorder(
            restartOutcomes: [],
            statusData: payloadData(active: "hd-master", runtime: "running")
        )
        guard let fixture = try? makeModel(recorder: recorder, runtime: "running") else {
            runner.expect(false, "Could not create cancellation fixture")
            return
        }
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        fixture.model.requestRestartCurrentCodex()
        runner.expect(
            fixture.model.accountRestartConfirmation == .runningTask,
            "Cached running work should ask for confirmation"
        )
        fixture.model.cancelRestartCurrentCodex()
        runner.expect(
            fixture.model.accountRestartConfirmation == nil,
            "Cancellation should clear the confirmation state"
        )
        runner.expect(
            fixture.model.events.first?.action == "restart_cancelled",
            "Cancellation should append a skipped operation event"
        )
        runner.expect(
            recorder.capturedArguments().isEmpty,
            "Cancellation must not execute the backend"
        )
    }

    @MainActor
    private static func successfulRestart(_ runner: AppTestRunner) async {
        let recorder = RestartGatewayRecorder(
            restartOutcomes: [.success(Data())],
            statusData: payloadData(active: "hd-master", runtime: "idle")
        )
        guard let fixture = try? makeModel(recorder: recorder, runtime: "idle") else {
            runner.expect(false, "Could not create success fixture")
            return
        }
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        fixture.model.requestRestartCurrentCodex()
        let successObserved = await waitUntil {
            fixture.model.accountRestartStage == nil
                && fixture.model.events.contains { $0.action == "account_restarted" }
        }
        runner.expect(
            successObserved,
            "A verified restart should append a success event"
        )
        runner.expect(fixture.model.accountError == nil, "A verified restart should clear errors")
        runner.expect(
            fixture.model.currentProfileName == "hd-master",
            "A verified restart should keep the current account"
        )
    }

    @MainActor
    private static func verificationMismatch(_ runner: AppTestRunner) async {
        let recorder = RestartGatewayRecorder(
            restartOutcomes: [.success(Data())],
            statusData: payloadData(active: "hd-other", runtime: "idle")
        )
        guard let fixture = try? makeModel(recorder: recorder, runtime: "idle") else {
            runner.expect(false, "Could not create mismatch fixture")
            return
        }
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        fixture.model.requestRestartCurrentCodex()
        let mismatchObserved = await waitUntil {
            fixture.model.accountRestartStage == nil
                && fixture.model.events.contains { $0.action == "account_restart_failed" }
        }
        runner.expect(
            mismatchObserved,
            "A verification mismatch should append a failure event"
        )
        runner.expect(
            fixture.model.accountError?.contains("实际为 hd-other") == true,
            "A mismatch should explain the observed account"
        )
    }

    @MainActor
    private static func makeModel(
        recorder: RestartGatewayRecorder,
        runtime: String
    ) throws -> (model: WorkbenchAppModel, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("workbench-app-model-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let gateway = AccountGateway(
            commandBuilder: AccountCommandBuilder(
                executableURL: URL(fileURLWithPath: "/test/CodexAccountBackend"),
                argumentPrefix: []
            ),
            commandRunner: { [recorder] command in
                try recorder.run(command)
            }
        )
        let payload = try AccountDashboardPayload.decode(
            data: payloadData(active: "hd-master", runtime: runtime)
        )
        return (
            WorkbenchAppModel(
                testingGateway: gateway,
                payload: payload,
                ledgerURL: root.appendingPathComponent("events.jsonl")
            ),
            root
        )
    }

    @MainActor
    private static func waitUntil(
        _ predicate: @escaping @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<200 {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    private static func payloadData(active: String, runtime: String) -> Data {
        Data(
            """
            {
              "generated_at":"2026-07-21T04:00:00Z",
              "account_mode":"managed_profiles",
              "active_profile":"\(active)",
              "runtime_status":{"state":"\(runtime)","light":"green","label":"运行状态","active_process_count":1,"recent_process_count":1},
              "desktop_status":{"running":true,"managed":true,"state":"managed_default_home","active_profile":"\(active)"},
              "profiles":[{"name":"\(active)","path":"/tmp/\(active)","auth":"present","config":"present","account":{"available":true,"type":"chatgpt"},"rate_limits":{}}]
            }
            """.utf8
        )
    }
}
