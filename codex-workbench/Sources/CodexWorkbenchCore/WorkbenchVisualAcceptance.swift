import Foundation

public struct WorkbenchVisualAcceptanceConfiguration: Equatable, Sendable {
    public static let fixtureEnvironmentKey = "CODEX_WORKBENCH_VISUAL_FIXTURE"
    public static let appearanceEnvironmentKey = "CODEX_WORKBENCH_VISUAL_APPEARANCE"
    public static let surfaceEnvironmentKey = "CODEX_WORKBENCH_VISUAL_SURFACE"

    public enum Fixture: String, Equatable, Sendable {
        case stale
        case error
        case switching
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

    public static func make(
        for fixture: WorkbenchVisualAcceptanceConfiguration.Fixture,
        now: Date = Date()
    ) -> Self {
        let payload = fixture == .error ? nil : samplePayload(now: now)
        return Self(
            payload: payload,
            errorMessage: errorMessage(for: fixture, now: now),
            switchingProfile: fixture == .switching ? "hd-master" : nil,
            lastUpdatedAt: fixture == .stale ? now.addingTimeInterval(-600) : now,
            isCodexRunning: true,
            blocksLiveOperations: true,
            banner: "视觉验收模式 · 不执行真实账号操作"
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
        case .switching:
            nil
        }
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
}
