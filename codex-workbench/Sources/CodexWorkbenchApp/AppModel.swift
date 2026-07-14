import AppKit
import CodexWorkbenchCore
import Combine
import Foundation

private struct LedgerRefreshResult: Sendable {
    let events: [OperationEvent]
    let warnings: [String]
    let appendedCount: Int
}

private struct AccountRefreshResult: Sendable {
    let payload: AccountDashboardPayload?
    let errorMessage: String?
}

@MainActor
final class WorkbenchAppModel: ObservableObject {
    @Published var selectedModule: AppModule? = .overview
    @Published private(set) var events: [OperationEvent] = []
    @Published private(set) var ledgerWarnings: [String] = []
    @Published private(set) var accountPayload: AccountDashboardPayload?
    @Published private(set) var accountError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var switchingProfile: String?
    @Published private(set) var isCodexRunning = false
    @Published private(set) var lastUpdated: Date?
    @Published var searchText = ""
    @Published var importanceFilter: EventImportance?
    @Published var actorFilter: EventActorType?
    @Published var statusFilter: EventStatus?
    @Published var selectedEventID: String?

    private var hasBootstrapped = false
    private let ledgerURL: URL
    private let accountGateway: AccountGateway?

    init() {
        ledgerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/operation-ledger/events.jsonl")
        accountGateway = AccountBackendLocator.bundled() ?? Self.developmentAccountGateway()
        updateCodexRunningState()
    }

    var filteredEvents: [OperationEvent] {
        let filter = ActivityFilter(
            query: searchText,
            importances: importanceFilter.map { [$0] } ?? [],
            actorTypes: actorFilter.map { [$0] } ?? [],
            statuses: statusFilter.map { [$0] } ?? []
        )
        return events.filter(filter.matches)
    }

    var selectedEvent: OperationEvent? {
        guard let selectedEventID else { return nil }
        return events.first { $0.id == selectedEventID }
    }

    var todayEventCount: Int {
        events.filter { Calendar.current.isDateInToday($0.occurredAt) }.count
    }

    var attentionCount: Int {
        events.filter {
            Calendar.current.isDateInToday($0.occurredAt)
                && ActivityInsights.requiresAttention($0)
        }.count
    }

    var desktopProfileName: String? {
        accountPayload?.profileRoles?.desktop.profile
            ?? accountPayload?.desktopStatus?.activeProfile
            ?? accountPayload?.activeProfile
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        Task { await refreshAll() }
    }

    func refreshAll(refreshResetCredits: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        updateCodexRunningState()

        let ledgerURL = ledgerURL
        async let ledgerResult: LedgerRefreshResult = Task.detached(priority: .userInitiated) {
            let snapshot = LocalEvidenceReader().read()
            let reconciled = EvidenceReconciler().events(from: snapshot)
            let writeResult = LedgerWriter().append(events: reconciled, to: ledgerURL)
            let loaded = LedgerRepository().load(from: ledgerURL)
            return LedgerRefreshResult(
                events: loaded.events,
                warnings: snapshot.warnings + writeResult.warnings + loaded.warnings.map(\.message),
                appendedCount: writeResult.appendedCount
            )
        }.value

        let gateway = accountGateway
        async let accountResult: AccountRefreshResult = Task.detached(priority: .utility) {
            guard let gateway else {
                return AccountRefreshResult(payload: nil, errorMessage: "未找到账号模块。")
            }
            do {
                let payload = try gateway.loadStatus(refreshResetCredits: refreshResetCredits)
                return AccountRefreshResult(payload: payload, errorMessage: nil)
            } catch {
                return AccountRefreshResult(
                    payload: nil,
                    errorMessage: (error as? LocalizedError)?.errorDescription ?? "无法读取账号状态。"
                )
            }
        }.value

        let ledger = await ledgerResult
        events = ledger.events
        ledgerWarnings = ledger.warnings
        lastUpdated = Date()

        let account = await accountResult
        if let payload = account.payload {
            accountPayload = payload
        }
        accountError = account.errorMessage
        lastUpdated = Date()
        isRefreshing = false
    }

    func selectEvent(_ event: OperationEvent) {
        selectedEventID = selectedEventID == event.id ? nil : event.id
    }

    func switchProfile(_ profile: String) {
        guard switchingProfile == nil, let gateway = accountGateway else { return }
        switchingProfile = profile
        let previousProfile = desktopProfileName
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    try gateway.switchProfile(profile)
                    return AccountRefreshResult(payload: nil, errorMessage: nil)
                } catch {
                    return AccountRefreshResult(
                        payload: nil,
                        errorMessage: (error as? LocalizedError)?.errorDescription ?? "账号切换失败。"
                    )
                }
            }.value
            switchingProfile = nil
            if let errorMessage = result.errorMessage {
                accountError = errorMessage
                return
            }
            recordAccountSwitch(from: previousProfile, to: profile)
            await refreshAll()
        }
    }

    func updateCodexRunningState() {
        isCodexRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.openai.codex"
        ).isEmpty
    }

    private func recordAccountSwitch(from previousProfile: String?, to profile: String) {
        let now = Date()
        let event = OperationEvent(
            schemaVersion: 1,
            id: StableEventID.make(parts: ["account-switch", profile, String(now.timeIntervalSince1970)]),
            occurredAt: now,
            recordedAt: now,
            category: .account,
            action: "account_switched",
            title: "已切换 Codex 桌面账号",
            summary: "已切换到 \(profile)，并通过 Profile Switcher 重启 Codex。",
            status: .success,
            importance: .critical,
            certainty: .confirmed,
            actor: EventActor(type: .app, id: "codex-workbench", label: "Codex 工具台"),
            account: EventAccount(profile: profile),
            sourceChain: [
                EventActor(type: .app, id: "codex-workbench", label: "Codex 工具台"),
                EventActor(type: .app, id: "codex-profile-switcher", label: "Profile Switcher"),
            ],
            before: previousProfile.map { .object(["desktop_profile": .string($0)]) },
            after: .object(["desktop_profile": .string(profile)]),
            evidence: [EventEvidence(kind: "app_action", label: "账号切换完成")]
        )
        _ = LedgerWriter().append(events: [event], to: ledgerURL)
    }

    private static func developmentAccountGateway() -> AccountGateway? {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return AccountBackendLocator.development(repositoryRoot: root)
    }
}
