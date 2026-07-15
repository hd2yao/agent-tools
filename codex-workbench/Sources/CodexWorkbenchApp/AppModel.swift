import AppKit
import CodexWorkbenchCore
import Combine
import Foundation

private struct LedgerRefreshResult: Sendable {
    let events: [OperationEvent]
    let warnings: [String]
    let appendedCount: Int
    let snapshot: EvidenceSnapshot
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
    private var pollingTask: Task<Void, Never>?
    private let ledgerURL: URL
    private let observationStateURL: URL
    private let accountGateway: AccountGateway?
    private let officialRateLimitObserver = OfficialRateLimitObserver()

    init() {
        ledgerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/operation-ledger/events.jsonl")
        observationStateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/operation-ledger/state/observation-state.json")
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
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self?.refreshAll(refreshResetCredits: true)
            }
        }
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
            let pruneResult = LedgerMaintenance().prune(
                actions: ["quota_usage_updated", "quota_reset_time_updated"],
                from: ledgerURL
            )
            let loaded = LedgerRepository().load(from: ledgerURL)
            return LedgerRefreshResult(
                events: loaded.events,
                warnings: snapshot.warnings
                    + writeResult.warnings
                    + pruneResult.warnings
                    + loaded.warnings.map(\.message),
                appendedCount: writeResult.appendedCount,
                snapshot: snapshot
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
        let account = await accountResult
        if let payload = account.payload {
            accountPayload = payload
        }
        accountError = account.errorMessage

        let observationStateURL = observationStateURL
        let observedAt = Date()
        let observationResult = await Task.detached(priority: .utility) {
            let store = ObservationStateStore()
            let previous = store.load(from: observationStateURL)
            let reconciliation = ObservationStateReconciler().reconcile(
                previous: previous,
                evidence: ledger.snapshot,
                accountPayload: account.payload,
                accountError: account.errorMessage,
                existingEvents: ledger.events,
                observedAt: observedAt
            )
            let writeResult = LedgerWriter().append(events: reconciliation.events, to: ledgerURL)
            let didSave = store.save(reconciliation.state, to: observationStateURL)
            let loaded = LedgerRepository().load(from: ledgerURL)
            let workflowRevisions = WorkflowEventHistoryEnricher().revisions(
                events: loaded.events,
                catalog: ledger.snapshot.threadCatalog,
                recordedAt: observedAt
            )
            let revisionWriteResult = LedgerWriter().appendRevisions(
                events: workflowRevisions,
                to: ledgerURL
            )
            let finalLedger = revisionWriteResult.appendedCount > 0
                ? LedgerRepository().load(from: ledgerURL)
                : loaded
            var warnings = ledger.warnings
                + writeResult.warnings
                + revisionWriteResult.warnings
                + finalLedger.warnings.map(\.message)
            if !didSave {
                warnings.append("无法保存操作日志观察基线。")
            }
            return LedgerRefreshResult(
                events: EventContextEnricher().enrich(
                    events: finalLedger.events,
                    catalog: ledger.snapshot.threadCatalog
                ),
                warnings: warnings,
                appendedCount: ledger.appendedCount
                    + writeResult.appendedCount
                    + revisionWriteResult.appendedCount,
                snapshot: ledger.snapshot
            )
        }.value

        events = observationResult.events
        ledgerWarnings = observationResult.warnings
        configureOfficialRateLimitObserver()
        lastUpdated = Date()
        isRefreshing = false
    }

    func handleSystemWake() {
        Task { await refreshAll(refreshResetCredits: true) }
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
            withBundleIdentifier: CodexIntegration.bundleIdentifier
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
            actor: EventActor(type: .app, id: "codex-workbench", label: "Codex 观测站"),
            account: EventAccount(profile: profile),
            sourceChain: [
                EventActor(type: .app, id: "codex-workbench", label: "Codex 观测站"),
                EventActor(type: .app, id: "codex-profile-switcher", label: "Profile Switcher"),
            ],
            before: previousProfile.map { .object(["desktop_profile": .string($0)]) },
            after: .object(["desktop_profile": .string(profile)]),
            evidence: [EventEvidence(kind: "app_action", label: "账号切换完成")]
        )
        _ = LedgerWriter().append(events: [event], to: ledgerURL)
    }

    private func configureOfficialRateLimitObserver() {
        guard
            let profileName = desktopProfileName,
            let profileHome = accountPayload?.profiles.first(where: { $0.name == profileName })?.path
        else {
            officialRateLimitObserver.stop()
            return
        }
        officialRateLimitObserver.start(profileHome: profileHome) { [weak self] in
            Task { await self?.refreshAll(refreshResetCredits: true) }
        }
    }

    private static func developmentAccountGateway() -> AccountGateway? {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return AccountBackendLocator.development(repositoryRoot: root)
    }
}
