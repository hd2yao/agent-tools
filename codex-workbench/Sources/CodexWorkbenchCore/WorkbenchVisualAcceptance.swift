import Foundation

public struct WorkbenchVisualAcceptanceConfiguration: Equatable, Sendable {
    public static let fixtureEnvironmentKey = "CODEX_WORKBENCH_VISUAL_FIXTURE"
    public static let appearanceEnvironmentKey = "CODEX_WORKBENCH_VISUAL_APPEARANCE"
    public static let surfaceEnvironmentKey = "CODEX_WORKBENCH_VISUAL_SURFACE"

    public enum Fixture: String, Equatable, Sendable {
        case stale
        case error
        case switching
        case local
        case restartConfirmation = "restart-confirmation"
        case restarting
        case diagnostics
    }

    public enum Appearance: String, Equatable, Sendable {
        case dark
        case light
    }

    public enum Surface: String, Equatable, Sendable {
        case menu
    }

    public let fixture: Fixture?
    public let appearance: Appearance?
    public let surface: Surface?

    public init(fixture: Fixture?, appearance: Appearance?, surface: Surface?) {
        self.fixture = fixture
        self.appearance = appearance
        self.surface = surface
    }

    public var liveOperationsAllowed: Bool {
        fixture == nil
    }

    public var windowSceneID: String {
        fixture == nil ? "main" : "visual-acceptance"
    }

    public static func parse(environment: [String: String]) -> Self {
        let fixture = environment[fixtureEnvironmentKey].flatMap(Fixture.init(rawValue:))
        return Self(
            fixture: fixture,
            appearance: environment[appearanceEnvironmentKey].flatMap(Appearance.init(rawValue:)),
            surface: fixture.flatMap { _ in
                environment[surfaceEnvironmentKey].flatMap(Surface.init(rawValue:))
            }
        )
    }
}

public enum WorkbenchVisualRestartStage: Equatable, Sendable {
    case preparing
    case quitting
    case launching
    case verifying
}

public enum WorkbenchStartupPolicy {
    public static func shouldMigrateLoginItem(
        configuration: WorkbenchVisualAcceptanceConfiguration
    ) -> Bool {
        configuration.liveOperationsAllowed
    }
}

public struct WorkbenchVisualAcceptanceSnapshot: Equatable, Sendable {
    public let payload: AccountDashboardPayload?
    public let errorMessage: String?
    public let switchingProfile: String?
    public let lastUpdatedAt: Date
    public let isCodexRunning: Bool
    public let blocksLiveOperations: Bool
    public let banner: String
    public let workspaceCatalog: WorkspaceCatalogPresentation
    public let restartConfirmationReason: AccountRestartConfirmationReason?
    public let restartStage: WorkbenchVisualRestartStage?
    public let presentsDiagnostics: Bool
    public let diagnosticSnapshot: WorkbenchDiagnosticSnapshot

    public static func make(
        for fixture: WorkbenchVisualAcceptanceConfiguration.Fixture,
        now: Date = Date()
    ) -> Self {
        let payload: AccountDashboardPayload?
        switch fixture {
        case .error:
            payload = nil
        case .local:
            payload = sampleLocalPayload(now: now)
        default:
            payload = samplePayload(now: now)
        }
        return Self(
            payload: payload,
            errorMessage: errorMessage(for: fixture, now: now),
            switchingProfile: fixture == .switching ? "hd-master" : nil,
            lastUpdatedAt: fixture == .stale ? now.addingTimeInterval(-600) : now,
            isCodexRunning: true,
            blocksLiveOperations: true,
            banner: "视觉验收模式 · 不执行真实账号操作",
            workspaceCatalog: sampleWorkspaceCatalog(now: now),
            restartConfirmationReason: fixture == .restartConfirmation ? .runningTask : nil,
            restartStage: fixture == .restarting ? .verifying : nil,
            presentsDiagnostics: fixture == .diagnostics,
            diagnosticSnapshot: sampleDiagnosticSnapshot()
        )
    }

    private static func errorMessage(
        for fixture: WorkbenchVisualAcceptanceConfiguration.Fixture,
        now: Date
    ) -> String? {
        switch fixture {
        case .stale:
            AccountRefreshFreshness(lastSuccessfulAt: now.addingTimeInterval(-600))
                .failureMessage(
                    error: "账号状态刷新失败。",
                    hasCachedPayload: true,
                    now: now
                )
        case .error:
            "无法读取账号状态；请检查内置账号模块。"
        case .switching, .local, .restartConfirmation, .restarting, .diagnostics:
            nil
        }
    }

    private static func sampleLocalPayload(now: Date) -> AccountDashboardPayload {
        let local = sampleProfile(
            name: "local-default",
            remainingPercent: 64,
            resetCreditCount: 0,
            now: now
        )
        return AccountDashboardPayload(
            generatedAt: now,
            activeProfile: local.name,
            accountMode: .localDefault,
            desktopStatus: AccountDesktopStatus(
                running: true,
                managed: false,
                state: "local_default",
                message: "本机当前账号",
                activeProfile: local.name
            ),
            profileRoles: nil,
            profiles: [local],
            runtimeStatus: AccountRuntimeStatus(
                state: "idle",
                light: "red",
                label: "空闲",
                activeProcessCount: 0,
                recentProcessCount: 0
            )
        )
    }

    private static func samplePayload(now: Date) -> AccountDashboardPayload {
        let blackwell = sampleProfile(
            name: "hd-sarah-blackwell",
            remainingPercent: 49,
            resetCreditCount: 1,
            now: now
        )
        let master = sampleProfile(
            name: "hd-master",
            remainingPercent: 53,
            resetCreditCount: 2,
            now: now
        )
        let currentRole = AccountRole(
            profile: blackwell.name,
            source: "visual_acceptance_fixture",
            confidence: .confirmed
        )
        return AccountDashboardPayload(
            generatedAt: now,
            activeProfile: blackwell.name,
            desktopStatus: AccountDesktopStatus(
                running: true,
                managed: true,
                state: "managed_default_home",
                message: nil,
                activeProfile: blackwell.name
            ),
            profileRoles: AccountProfileRoles(
                task: currentRole,
                desktop: currentRole,
                attribution: currentRole,
                taskMatchesDesktop: true
            ),
            profiles: [blackwell, master],
            runtimeStatus: AccountRuntimeStatus(
                state: "running",
                light: "green",
                label: "运行中",
                activeProcessCount: 1,
                recentProcessCount: 1,
                latestActivityAgeMs: 1_200
            ),
            attributionSummary: AccountAttributionSummary(
                activeProfile: blackwell.name,
                managed: true
            ),
            projectRankings: AccountProjectRankings(
                available: true,
                projects: [
                    AccountProjectRankingItem(
                        name: "tools",
                        path: "/Users/example/program/tools",
                        threadCount: 2,
                        tokensUsed: 324_000,
                        latestUpdatedAt: Int(now.addingTimeInterval(-600).timeIntervalSince1970)
                    ),
                ]
            ),
            toolRankings: AccountToolRankings(
                available: true,
                tools: [
                    AccountToolRankingItem(
                        id: "functions.exec_command",
                        namespace: "functions",
                        name: "exec_command",
                        callCount: 18,
                        latestUpdatedAt: Int(now.addingTimeInterval(-900).timeIntervalSince1970),
                        threadTokens: 42_000
                    ),
                ]
            ),
            skillRankings: AccountSkillRankings(
                available: true,
                skills: [
                    AccountSkillRankingItem(
                        name: "executing-plans",
                        useCount: 4,
                        latestTimestamp: ISO8601DateFormatter().string(from: now.addingTimeInterval(-1_200))
                    ),
                ],
                badLineCount: 0
            )
        )
    }

    private static func sampleProfile(
        name: String,
        remainingPercent: Double,
        resetCreditCount: Int,
        now: Date
    ) -> AccountProfile {
        let expiryBase = now.addingTimeInterval(27 * 24 * 60 * 60).timeIntervalSince1970
        let cards = (0..<resetCreditCount).map { index in
            AccountResetCreditCard(
                id: "visual-fixture-\(name)-\(index)",
                status: "available",
                used: false,
                resetType: "full",
                title: "Full reset",
                description: "视觉验收样例，不会执行真实额度重置。",
                expiresAt: expiryBase + Double(index * 86_400)
            )
        }
        return AccountProfile(
            name: name,
            auth: "present",
            config: "present",
            rateLimits: AccountRateLimits(
                planType: "plus",
                primary: AccountQuotaWindow(
                    usedPercent: 100 - remainingPercent,
                    remainingPercent: remainingPercent,
                    windowMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970
                ),
                secondary: nil,
                resetCredits: AccountResetCredits(
                    available: true,
                    availableCount: resetCreditCount
                )
            ),
            resetCreditDetails: AccountResetCreditDetails(
                available: true,
                availableCount: resetCreditCount,
                totalEarnedCount: resetCreditCount,
                credits: cards,
                earliestExpiresAt: cards.first?.expiresAt
            ),
            remoteStale: false,
            remoteError: nil,
            account: AccountStatusSummary(
                available: true,
                type: "chatgpt",
                planType: "plus",
                emailPresent: false,
                requiresOpenAIAuth: true
            ),
            resetCreditStale: false,
            resetCreditError: nil
        )
    }

    private static func sampleWorkspaceCatalog(now: Date) -> WorkspaceCatalogPresentation {
        let source = WorkspaceThreadPresentation(
            id: "11111111-1111-4111-8111-111111111111",
            title: "Codex 工作台产品化",
            projectName: "tools",
            projectPath: "/Users/example/program/tools",
            updatedAt: now.addingTimeInterval(-3_600),
            sourceThreadID: nil,
            sourceThreadTitle: nil,
            hasContextSummary: true,
            contextTopic: "工作台产品化"
        )
        let continued = WorkspaceThreadPresentation(
            id: "22222222-2222-4222-8222-222222222222",
            title: "接续：工作台发行",
            projectName: "tools",
            projectPath: "/Users/example/program/tools",
            updatedAt: now.addingTimeInterval(-600),
            sourceThreadID: source.id,
            sourceThreadTitle: source.title,
            hasContextSummary: false,
            contextTopic: nil
        )
        let hook = WorkflowItemPresentation(
            id: "fixture-hook",
            name: "上下文摘要 Hook",
            status: "enabled",
            schedule: nil,
            purpose: "压缩前生成任务摘要",
            modifiedAt: now.addingTimeInterval(-1_800)
        )
        let automation = WorkflowItemPresentation(
            id: "fixture-automation",
            name: "每周回顾",
            status: "active",
            schedule: "MON 09:00",
            purpose: "整理本周任务证据",
            modifiedAt: now.addingTimeInterval(-1_200)
        )
        return WorkspaceCatalogPresentation(
            projects: [
                WorkspaceProjectPresentation(
                    name: "tools",
                    path: "/Users/example/program/tools",
                    updatedAt: continued.updatedAt,
                    threads: [continued, source]
                )
            ],
            recentThreads: [continued, source],
            contextSummaryCount: 1,
            workflows: WorkflowCatalogPresentation(hooks: [hook], automations: [automation])
        )
    }

    private static func sampleDiagnosticSnapshot() -> WorkbenchDiagnosticSnapshot {
        WorkbenchDiagnosticsBuilder.build(
            WorkbenchDiagnosticInput(
                installedApps: [
                    DiagnosticAppInstallation(
                        url: URL(fileURLWithPath: "/Applications/ChatGPT.app"),
                        bundleIdentifier: CodexIntegration.bundleIdentifier,
                        version: "1.2026.190",
                        isRunning: true
                    ),
                    DiagnosticAppInstallation(
                        url: URL(fileURLWithPath: "/Applications/Codex.app"),
                        bundleIdentifier: CodexIntegration.bundleIdentifier,
                        version: "1.2026.180",
                        isRunning: false
                    ),
                ],
                selectedAppURL: URL(fileURLWithPath: "/Applications/ChatGPT.app"),
                backendAvailable: true,
                accountMode: .managedProfiles,
                managedProfileCount: 2,
                defaultHomeAvailable: true
            )
        )
    }
}
