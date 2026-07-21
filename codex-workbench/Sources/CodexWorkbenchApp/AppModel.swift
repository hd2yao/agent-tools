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

enum AccountSwitchStage: Equatable {
    case switching(profile: String)
    case verifying(profile: String)

    var profile: String {
        switch self {
        case .switching(let profile), .verifying(let profile):
            profile
        }
    }
}

enum AccountRestartStage: Equatable {
    case preparing
    case quitting
    case launching
    case verifying
}

@MainActor
final class WorkbenchAppModel: ObservableObject {
    @Published var selectedModule: AppModule? = .overview
    @Published private(set) var events: [OperationEvent] = []
    @Published private(set) var ledgerWarnings: [String] = []
    @Published private(set) var accountPayload: AccountDashboardPayload?
    @Published private(set) var accountError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var accountSwitchStage: AccountSwitchStage?
    @Published private(set) var accountRestartStage: AccountRestartStage?
    @Published private(set) var accountRestartConfirmation: AccountRestartConfirmationReason?
    @Published private(set) var diagnosticSnapshot = WorkbenchDiagnosticsBuilder.build(
        WorkbenchDiagnosticInput(
            installedApps: [],
            selectedAppURL: nil,
            backendAvailable: false,
            accountMode: .unavailable,
            managedProfileCount: 0
        )
    )
    @Published private(set) var isCodexRunning = false
    @Published private(set) var isLegacyProfileSwitcherRunning = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var accountLastSuccessfulRefresh: Date?
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
    private let visualAcceptanceConfiguration: WorkbenchVisualAcceptanceConfiguration
    private let visualAcceptanceSnapshot: WorkbenchVisualAcceptanceSnapshot?
    private let officialRateLimitObserver = OfficialRateLimitObserver()
    private let automaticResetCoordinator = AutomaticResetCoordinator()
    private var accountRefreshFreshness = AccountRefreshFreshness()
    private var recentAccountFailureStage: String?

    init() {
        let configuration = WorkbenchVisualAcceptanceConfiguration.parse(
            environment: ProcessInfo.processInfo.environment
        )
        visualAcceptanceConfiguration = configuration
        ledgerURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/operation-ledger/events.jsonl")
        observationStateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/operation-ledger/state/observation-state.json")
        if let fixture = configuration.fixture {
            let snapshot = WorkbenchVisualAcceptanceSnapshot.make(for: fixture)
            visualAcceptanceSnapshot = snapshot
            accountGateway = nil
            selectedModule = .accounts
            accountPayload = snapshot.payload
            accountError = snapshot.errorMessage
            accountSwitchStage = snapshot.switchingProfile.map { .switching(profile: $0) }
            isCodexRunning = snapshot.isCodexRunning
            lastUpdated = snapshot.lastUpdatedAt
            if snapshot.payload != nil {
                accountRefreshFreshness.recordSuccess(at: snapshot.lastUpdatedAt)
                accountLastSuccessfulRefresh = snapshot.lastUpdatedAt
            }
        } else {
            visualAcceptanceSnapshot = nil
            accountGateway = AccountBackendLocator.bundled() ?? Self.developmentAccountGateway()
            updateRunningApplicationState()
        }
        refreshDiagnostics()
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

    var currentProfileName: String? {
        AccountPresentationBuilder.confirmedCurrentProfileName(payload: accountPayload)
    }

    var desktopProfileName: String? {
        currentProfileName
    }

    var switchingProfile: String? {
        accountSwitchStage?.profile
    }

    var isVisualAcceptanceMode: Bool {
        visualAcceptanceSnapshot != nil
    }

    var visualAcceptanceBanner: String? {
        visualAcceptanceSnapshot?.banner
    }

    var visualAcceptanceSurface: WorkbenchVisualAcceptanceConfiguration.Surface? {
        visualAcceptanceConfiguration.surface
    }

    var windowSceneID: String {
        visualAcceptanceConfiguration.windowSceneID
    }

    var runtimePresentation: AccountRuntimePresentation {
        AccountPresentationBuilder.runtime(status: accountPayload?.runtimeStatus)
    }

    var accountAutomationAvailability: AccountAutomationAvailability {
        AccountRuntimePolicy.automationAvailability(
            legacyProfileSwitcherRunning: isLegacyProfileSwitcherRunning
        )
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        guard visualAcceptanceConfiguration.liveOperationsAllowed else { return }
        automaticResetCoordinator.start()
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
        guard visualAcceptanceConfiguration.liveOperationsAllowed else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        updateRunningApplicationState()

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
        let accountRefreshCompletedAt = Date()
        if let payload = account.payload {
            accountPayload = payload
            accountRefreshFreshness.recordSuccess(at: accountRefreshCompletedAt)
            accountLastSuccessfulRefresh = accountRefreshCompletedAt
            accountError = nil
        } else if let errorMessage = account.errorMessage {
            accountError = accountRefreshFreshness.failureMessage(
                error: errorMessage,
                hasCachedPayload: accountPayload != nil,
                now: accountRefreshCompletedAt
            )
        }

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
            let contextRevisions = ContextEventHistoryEnricher().revisions(
                events: loaded.events,
                cards: ledger.snapshot.contextCards,
                catalog: ledger.snapshot.threadCatalog,
                recordedAt: observedAt
            )
            let workflowRevisions = WorkflowEventHistoryEnricher().revisions(
                events: loaded.events,
                catalog: ledger.snapshot.threadCatalog,
                currentWorkflowFiles: ledger.snapshot.workflowFiles,
                recordedAt: observedAt
            )
            let revisionWriteResult = LedgerWriter().appendRevisions(
                events: contextRevisions + workflowRevisions,
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
        refreshDiagnostics()
        lastUpdated = Date()
        isRefreshing = false
        if let payload = account.payload {
            automaticResetCoordinator.process(
                payload: payload,
                gateway: accountGateway
            ) { [weak self] _, _ in
                Task { await self?.refreshAll(refreshResetCredits: true) }
            }
        }
    }

    func handleSystemWake() {
        Task { await refreshAll(refreshResetCredits: true) }
    }

    func selectEvent(_ event: OperationEvent) {
        selectedEventID = selectedEventID == event.id ? nil : event.id
    }

    func switchProfile(_ profile: String) {
        guard visualAcceptanceConfiguration.liveOperationsAllowed else { return }
        guard
            accountSwitchStage == nil,
            accountRestartStage == nil,
            accountRestartConfirmation == nil,
            let gateway = accountGateway
        else { return }
        accountSwitchStage = .switching(profile: profile)
        let previousProfile = currentProfileName
        Task {
            let switchError = await Task.detached(priority: .userInitiated) {
                do {
                    try gateway.switchProfile(profile)
                    return nil as String?
                } catch {
                    return (error as? LocalizedError)?.errorDescription ?? "账号切换失败。"
                }
            }.value
            if let errorMessage = switchError {
                recordAccountSwitchFailure(
                    expected: profile,
                    actual: previousProfile,
                    reason: "switch_command_failed"
                )
                accountSwitchStage = nil
                accountError = errorMessage
                return
            }

            accountSwitchStage = .verifying(profile: profile)
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    return AccountRefreshResult(
                        payload: try gateway.loadStatus(refreshResetCredits: true),
                        errorMessage: nil
                    )
                } catch {
                    return AccountRefreshResult(
                        payload: nil,
                        errorMessage: (error as? LocalizedError)?.errorDescription ?? "无法验证切换后的账号。"
                    )
                }
            }.value

            guard let payload = result.payload else {
                recordAccountSwitchFailure(
                    expected: profile,
                    actual: previousProfile,
                    reason: "verification_unavailable"
                )
                accountSwitchStage = nil
                accountError = result.errorMessage ?? "无法验证切换后的账号。"
                return
            }
            switch AccountSwitchVerifier.verify(payload: payload, expectedProfile: profile) {
            case .verified:
                accountPayload = payload
                let verifiedAt = Date()
                accountRefreshFreshness.recordSuccess(at: verifiedAt)
                accountLastSuccessfulRefresh = verifiedAt
                accountError = nil
                accountSwitchStage = nil
                recordAccountSwitch(from: previousProfile, to: profile)
                await refreshAll(refreshResetCredits: true)
            case .mismatch(let expected, let actual):
                recordAccountSwitchFailure(
                    expected: expected,
                    actual: actual,
                    reason: "verification_mismatch"
                )
                accountSwitchStage = nil
                accountError = "账号切换未通过验证：目标为 \(expected)，实际为 \(actual ?? "未知")。"
            case .unmanaged(let actual):
                recordAccountSwitchFailure(
                    expected: profile,
                    actual: actual,
                    reason: "unmanaged_login"
                )
                accountSwitchStage = nil
                accountError = "账号切换未通过验证：\(actual ?? "未知账号") 尚未被工作台接管。"
            }
        }
    }

    func requestRestartCurrentCodex() {
        guard visualAcceptanceConfiguration.liveOperationsAllowed else { return }
        guard
            accountSwitchStage == nil,
            accountRestartStage == nil,
            accountRestartConfirmation == nil,
            accountGateway != nil,
            let payload = accountPayload,
            payload.accountMode != .unavailable,
            let profile = currentProfileName
        else { return }

        switch AccountRestartPolicy.decision(runtimeState: payload.runtimeStatus?.state) {
        case .restartNow:
            performRestartCurrentCodex(expectedMode: payload.accountMode, profile: profile)
        case .confirm(let reason):
            accountRestartConfirmation = reason
        }
    }

    func confirmRestartCurrentCodex() {
        guard
            accountRestartConfirmation != nil,
            accountRestartStage == nil,
            accountSwitchStage == nil,
            let payload = accountPayload,
            payload.accountMode != .unavailable,
            let profile = currentProfileName
        else { return }
        accountRestartConfirmation = nil
        performRestartCurrentCodex(expectedMode: payload.accountMode, profile: profile)
    }

    func cancelRestartCurrentCodex() {
        guard accountRestartConfirmation != nil else { return }
        accountRestartConfirmation = nil
        appendAccountOperationEvent(
            AccountOperationEventFactory.restartCancelled(profile: currentProfileName)
        )
    }

    func updateRunningApplicationState() {
        isCodexRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: CodexIntegration.bundleIdentifier
        ).isEmpty
        isLegacyProfileSwitcherRunning = AccountRuntimeServices.legacyProfileSwitcherIsRunning()
    }

    func refreshDiagnostics() {
        diagnosticSnapshot = AccountRuntimeServices.diagnosticSnapshot(
            payload: accountPayload,
            recentFailureStage: recentAccountFailureStage
        )
    }

    private func recordAccountSwitch(from previousProfile: String?, to profile: String) {
        recentAccountFailureStage = nil
        appendAccountOperationEvent(
            AccountOperationEventFactory.switchSucceeded(from: previousProfile, to: profile)
        )
        refreshDiagnostics()
    }

    private func recordAccountSwitchFailure(expected: String, actual: String?, reason: String) {
        recentAccountFailureStage = reason
        appendAccountOperationEvent(
            AccountOperationEventFactory.switchFailed(
                expected: expected,
                actual: actual,
                reason: reason
            )
        )
        refreshDiagnostics()
    }

    private func performRestartCurrentCodex(expectedMode: AccountMode, profile: String) {
        guard let gateway = accountGateway else { return }
        accountRestartStage = .preparing
        let managedProfile = expectedMode == .managedProfiles ? profile : nil

        Task {
            accountRestartStage = .quitting
            let restartError = await Task.detached(priority: .userInitiated) {
                do {
                    try gateway.restartCurrentAccount(profile: managedProfile)
                    return nil as String?
                } catch {
                    return (error as? LocalizedError)?.errorDescription ?? "Codex 重启失败。"
                }
            }.value
            if let errorMessage = restartError {
                appendAccountOperationEvent(
                    AccountOperationEventFactory.restartFailed(
                        profile: profile,
                        reason: "restart_command_failed"
                    )
                )
                recentAccountFailureStage = "restart_command_failed"
                refreshDiagnostics()
                accountRestartStage = nil
                accountError = errorMessage
                return
            }

            accountRestartStage = .launching
            updateRunningApplicationState()
            await Task.yield()
            accountRestartStage = .verifying
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    return AccountRefreshResult(
                        payload: try gateway.loadStatus(refreshResetCredits: true),
                        errorMessage: nil
                    )
                } catch {
                    return AccountRefreshResult(
                        payload: nil,
                        errorMessage: (error as? LocalizedError)?.errorDescription
                            ?? "无法验证重启后的账号。"
                    )
                }
            }.value

            guard let payload = result.payload else {
                appendAccountOperationEvent(
                    AccountOperationEventFactory.restartFailed(
                        profile: profile,
                        reason: "verification_unavailable"
                    )
                )
                recentAccountFailureStage = "verification_unavailable"
                refreshDiagnostics()
                accountRestartStage = nil
                accountError = result.errorMessage ?? "无法验证重启后的账号。"
                return
            }

            switch AccountRestartVerifier.verify(
                payload: payload,
                expectedMode: expectedMode,
                expectedProfile: profile
            ) {
            case .verified:
                accountPayload = payload
                let verifiedAt = Date()
                accountRefreshFreshness.recordSuccess(at: verifiedAt)
                accountLastSuccessfulRefresh = verifiedAt
                accountError = nil
                accountRestartStage = nil
                appendAccountOperationEvent(
                    AccountOperationEventFactory.restartSucceeded(profile: profile)
                )
                recentAccountFailureStage = nil
                refreshDiagnostics()
                await refreshAll(refreshResetCredits: true)
            case .mismatch(let expected, let actual):
                appendAccountOperationEvent(
                    AccountOperationEventFactory.restartFailed(
                        profile: expected,
                        reason: "verification_mismatch"
                    )
                )
                recentAccountFailureStage = "verification_mismatch"
                refreshDiagnostics()
                accountRestartStage = nil
                accountError = "Codex 重启未通过验证：预期账号为 \(expected ?? "未知")，实际为 \(actual ?? "未知")。"
            }
        }
    }

    private func appendAccountOperationEvent(_ event: OperationEvent) {
        let result = LedgerWriter().append(events: [event], to: ledgerURL)
        guard result.appendedCount == 1 else { return }
        events = (events + [event]).sorted { $0.occurredAt > $1.occurredAt }
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
