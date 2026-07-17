import Foundation

public struct AccountCommand: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}

public struct AccountCommandBuilder: Equatable, Sendable {
    public let pythonURL: URL
    public let helperURL: URL

    public init(pythonURL: URL, helperURL: URL) {
        self.pythonURL = pythonURL
        self.helperURL = helperURL
    }

    public func statusCommand(refreshResetCredits: Bool) -> AccountCommand {
        var arguments = [helperURL.path, "status", "--json"]
        if refreshResetCredits {
            arguments.append("--refresh-reset-credits")
        }
        return AccountCommand(executableURL: pythonURL, arguments: arguments)
    }

    public func switchCommand(profile: String) -> AccountCommand? {
        guard Self.isSafeProfileName(profile) else { return nil }
        return AccountCommand(
            executableURL: pythonURL,
            arguments: [helperURL.path, "app", profile]
        )
    }

    public func consumeResetCreditCommand(
        profile: String,
        idempotencyKey: String
    ) -> AccountCommand? {
        guard
            Self.isSafeProfileName(profile),
            Self.isSafeIdempotencyKey(idempotencyKey)
        else {
            return nil
        }
        return AccountCommand(
            executableURL: pythonURL,
            arguments: [
                helperURL.path,
                "consume-reset-credit",
                profile,
                "--idempotency-key",
                idempotencyKey,
            ]
        )
    }

    public static func isSafeProfileName(_ value: String) -> Bool {
        value.range(
            of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$"#,
            options: .regularExpression
        ) != nil
    }

    public static func isSafeIdempotencyKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 256
    }

    public static func processEnvironment(base: [String: String]) -> [String: String] {
        var environment = base
        environment["PATH"] = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            base["PATH"] ?? "",
        ].joined(separator: ":")
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        return environment
    }
}

public enum AccountGatewayError: Error, Equatable, LocalizedError, Sendable {
    case backendMissing
    case codexDesktopBusy
    case codexDesktopLaunchFailed
    case accountConflict
    case invalidProfile
    case launchFailed
    case processFailed(Int32)
    case invalidPayload

    public var errorDescription: String? {
        switch self {
        case .backendMissing: "账号模块不可用，请重新构建观测站。"
        case .codexDesktopBusy: "Codex 仍有任务正在运行，未能安全退出。请等任务结束后再切换账号。"
        case .codexDesktopLaunchFailed: "账号已准备，但 Codex 未能重新启动。请手动打开 Codex 后刷新状态。"
        case .accountConflict: "检测到 Codex 认证账号意外变化。为保护两个账号，切换已中止。"
        case .invalidProfile: "账号名称不符合安全规则。"
        case .launchFailed: "无法启动账号模块。"
        case .processFailed(let code): "账号模块执行失败（退出码 \(code)）。"
        case .invalidPayload: "账号状态数据格式不兼容。"
        }
    }

    public static func processFailure(code: Int32, standardError: String) -> AccountGatewayError {
        if standardError.contains("Codex Desktop did not quit within 12 seconds; switch aborted.") {
            return .codexDesktopBusy
        }
        if standardError.contains(
            "Codex auth account changed unexpectedly; switch aborted to preserve both accounts."
        ) {
            return .accountConflict
        }
        if standardError.contains("Codex Desktop did not launch within 12 seconds after `codex app`.") {
            return .codexDesktopLaunchFailed
        }
        return .processFailed(code)
    }
}

public struct AccountGateway: Sendable {
    public let commandBuilder: AccountCommandBuilder

    public init(commandBuilder: AccountCommandBuilder) {
        self.commandBuilder = commandBuilder
    }

    public func loadStatus(refreshResetCredits: Bool = false) throws -> AccountDashboardPayload {
        let data = try run(commandBuilder.statusCommand(refreshResetCredits: refreshResetCredits))
        do {
            return try AccountDashboardPayload.decode(data: data)
        } catch {
            throw AccountGatewayError.invalidPayload
        }
    }

    public func switchProfile(_ profile: String) throws {
        guard let command = commandBuilder.switchCommand(profile: profile) else {
            throw AccountGatewayError.invalidProfile
        }
        _ = try run(command)
    }

    public func consumeResetCredit(
        profile: String,
        idempotencyKey: String
    ) throws -> AccountResetCreditConsumeResult {
        guard let command = commandBuilder.consumeResetCreditCommand(
            profile: profile,
            idempotencyKey: idempotencyKey
        ) else {
            throw AccountGatewayError.invalidProfile
        }
        let data = try run(command)
        do {
            return try AccountResetCreditConsumeResult.decode(data: data)
        } catch {
            throw AccountGatewayError.invalidPayload
        }
    }

    private func run(_ command: AccountCommand) throws -> Data {
        guard
            FileManager.default.isExecutableFile(atPath: command.executableURL.path),
            FileManager.default.fileExists(atPath: commandBuilder.helperURL.path)
        else {
            throw AccountGatewayError.backendMissing
        }

        let process = Process()
        let output = Pipe()
        let errorOutput = Pipe()
        process.executableURL = command.executableURL
        process.arguments = command.arguments
        process.standardOutput = output
        process.standardError = errorOutput
        process.environment = AccountCommandBuilder.processEnvironment(
            base: ProcessInfo.processInfo.environment
        )

        do {
            try process.run()
        } catch {
            throw AccountGatewayError.launchFailed
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorOutput.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let standardError = String(data: errorData, encoding: .utf8) ?? ""
            throw AccountGatewayError.processFailure(
                code: process.terminationStatus,
                standardError: standardError
            )
        }
        return data
    }
}

public enum AccountBackendLocator {
    public static func bundled(resourceURL: URL? = Bundle.main.resourceURL) -> AccountGateway? {
        guard let resourceURL else { return nil }
        let helperURL = resourceURL
            .appendingPathComponent("codex-profile-switcher", isDirectory: true)
            .appendingPathComponent("codex_profile.py")
        guard let pythonURL = resolvePython() else { return nil }
        return AccountGateway(
            commandBuilder: AccountCommandBuilder(pythonURL: pythonURL, helperURL: helperURL)
        )
    }

    public static func development(repositoryRoot: URL) -> AccountGateway? {
        let helperURL = repositoryRoot
            .appendingPathComponent("codex-profile-switcher", isDirectory: true)
            .appendingPathComponent("codex_profile.py")
        guard let pythonURL = resolvePython() else { return nil }
        return AccountGateway(
            commandBuilder: AccountCommandBuilder(pythonURL: pythonURL, helperURL: helperURL)
        )
    }

    private static func resolvePython() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
