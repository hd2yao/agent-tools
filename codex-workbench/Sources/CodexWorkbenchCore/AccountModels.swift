import Foundation

public enum AccountRoleConfidence: String, Codable, Sendable {
    case confirmed
    case inferred
    case unknown

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

public struct AccountRole: Codable, Equatable, Sendable {
    public let profile: String?
    public let source: String
    public let confidence: AccountRoleConfidence
    public let observedAt: TimeInterval?
    private let threadId: String?

    public var threadID: String? { threadId }

    public init(
        profile: String?,
        source: String,
        confidence: AccountRoleConfidence,
        observedAt: TimeInterval? = nil,
        threadID: String? = nil
    ) {
        self.profile = profile
        self.source = source
        self.confidence = confidence
        self.observedAt = observedAt
        self.threadId = threadID
    }
}

public struct AccountProfileRoles: Codable, Equatable, Sendable {
    public let task: AccountRole
    public let desktop: AccountRole
    public let attribution: AccountRole
    public let taskMatchesDesktop: Bool?

    public init(
        task: AccountRole,
        desktop: AccountRole,
        attribution: AccountRole,
        taskMatchesDesktop: Bool?
    ) {
        self.task = task
        self.desktop = desktop
        self.attribution = attribution
        self.taskMatchesDesktop = taskMatchesDesktop
    }
}

public struct AccountDesktopStatus: Codable, Equatable, Sendable {
    public let running: Bool
    public let managed: Bool
    public let state: String
    public let message: String?
    public let activeProfile: String?

    public init(running: Bool, managed: Bool, state: String, message: String?, activeProfile: String?) {
        self.running = running
        self.managed = managed
        self.state = state
        self.message = message
        self.activeProfile = activeProfile
    }
}

public struct AccountRuntimeStatus: Codable, Equatable, Sendable {
    public let state: String
    public let light: String
    public let label: String
    public let activeProcessCount: Int
    public let recentProcessCount: Int
    public let latestActivityAgeMs: Int?

    public init(
        state: String,
        light: String,
        label: String,
        activeProcessCount: Int,
        recentProcessCount: Int,
        latestActivityAgeMs: Int? = nil
    ) {
        self.state = state
        self.light = light
        self.label = label
        self.activeProcessCount = activeProcessCount
        self.recentProcessCount = recentProcessCount
        self.latestActivityAgeMs = latestActivityAgeMs
    }
}

public struct AccountAttributionSummary: Codable, Equatable, Sendable {
    public let activeProfile: String?
    public let managed: Bool?

    public init(activeProfile: String? = nil, managed: Bool? = nil) {
        self.activeProfile = activeProfile
        self.managed = managed
    }
}

public struct AccountTokenUsageTotals: Codable, Equatable, Sendable {
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
}

public struct AccountTokenUsageByDate: Codable, Equatable, Sendable {
    public let date: String
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
}

public struct AccountTokenUsageByModel: Codable, Equatable, Sendable {
    public let model: String
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningOutputTokens: Int
    public let totalTokens: Int
}

public struct AccountLocalTokenSnapshot: Codable, Equatable, Sendable {
    public let eventCount: Int
    public let latestTimestamp: String?
    public let total: AccountTokenUsageTotals
    public let daily: [AccountTokenUsageByDate]?
    public let byModel: [AccountTokenUsageByModel]?
}

public struct AccountStatusSummary: Codable, Equatable, Sendable {
    public let available: Bool?
    public let type: String?
    public let planType: String?
    public let emailPresent: Bool?
    public let requiresOpenAIAuth: Bool?

    public init(
        available: Bool? = nil,
        type: String? = nil,
        planType: String? = nil,
        emailPresent: Bool? = nil,
        requiresOpenAIAuth: Bool? = nil
    ) {
        self.available = available
        self.type = type
        self.planType = planType
        self.emailPresent = emailPresent
        self.requiresOpenAIAuth = requiresOpenAIAuth
    }
}

public struct AccountQuotaWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double?
    public let remainingPercent: Double?
    public let windowMinutes: Int?
    public let resetsAt: TimeInterval?

    public init(
        usedPercent: Double? = nil,
        remainingPercent: Double? = nil,
        windowMinutes: Int? = nil,
        resetsAt: TimeInterval? = nil
    ) {
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    public var resetsAtDate: Date? {
        resetsAt.map(Date.init(timeIntervalSince1970:))
    }
}

public struct AccountResetCredits: Codable, Equatable, Sendable {
    public let available: Bool?
    public let availableCount: Int?
    public let hasCredits: Bool?
    public let unlimited: Bool?
    public let expiresAt: TimeInterval?

    public init(
        available: Bool? = nil,
        availableCount: Int? = nil,
        hasCredits: Bool? = nil,
        unlimited: Bool? = nil,
        expiresAt: TimeInterval? = nil
    ) {
        self.available = available
        self.availableCount = availableCount
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.expiresAt = expiresAt
    }
}

public struct AccountRateLimits: Codable, Equatable, Sendable {
    public let planType: String?
    public let limitName: String?
    public let creditsAvailable: Int?
    public let primary: AccountQuotaWindow?
    public let secondary: AccountQuotaWindow?
    private let rateLimitReachedType: String?
    public let resetCredits: AccountResetCredits?

    public var reachedType: String? { rateLimitReachedType }

    public init(
        planType: String? = nil,
        limitName: String? = nil,
        creditsAvailable: Int? = nil,
        primary: AccountQuotaWindow? = nil,
        secondary: AccountQuotaWindow? = nil,
        reachedType: String? = nil,
        resetCredits: AccountResetCredits? = nil
    ) {
        self.planType = planType
        self.limitName = limitName
        self.creditsAvailable = creditsAvailable
        self.primary = primary
        self.secondary = secondary
        self.rateLimitReachedType = reachedType
        self.resetCredits = resetCredits
    }
}

public struct AccountResetCreditConsumeResult: Codable, Equatable, Sendable {
    public let ok: Bool
    public let outcome: String?
    public let expiresAt: TimeInterval?
    public let error: String?

    public static func decode(data: Data) throws -> AccountResetCreditConsumeResult {
        try LedgerRepository.decoder().decode(AccountResetCreditConsumeResult.self, from: data)
    }
}

public struct AccountResetCreditReminder: Codable, Equatable, Sendable {
    public let kind: String
    public let at: TimeInterval

    public init(kind: String, at: TimeInterval) {
        self.kind = kind
        self.at = at
    }
}

public struct AccountResetCreditCard: Codable, Equatable, Sendable {
    public let id: String?
    public let status: String?
    public let used: Bool?
    public let resetType: String?
    public let title: String?
    public let description: String?
    public let grantedAt: TimeInterval?
    public let expiresAt: TimeInterval?
    public let reminders: [AccountResetCreditReminder]?

    public init(
        id: String? = nil,
        status: String? = nil,
        used: Bool? = nil,
        resetType: String? = nil,
        title: String? = nil,
        description: String? = nil,
        grantedAt: TimeInterval? = nil,
        expiresAt: TimeInterval? = nil,
        reminders: [AccountResetCreditReminder]? = nil
    ) {
        self.id = id
        self.status = status
        self.used = used
        self.resetType = resetType
        self.title = title
        self.description = description
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.reminders = reminders
    }

    public var stableID: String {
        id ?? "expiry-\(expiresAt ?? 0)-\(grantedAt ?? 0)"
    }
}

public struct AccountResetCreditDetails: Codable, Equatable, Sendable {
    public let available: Bool?
    public let availableCount: Int?
    public let totalEarnedCount: Int?
    public let credits: [AccountResetCreditCard]
    public let earliestExpiresAt: TimeInterval?
    public let nextExpirationAt: TimeInterval?

    public init(
        available: Bool? = nil,
        availableCount: Int? = nil,
        totalEarnedCount: Int? = nil,
        credits: [AccountResetCreditCard] = [],
        earliestExpiresAt: TimeInterval? = nil,
        nextExpirationAt: TimeInterval? = nil
    ) {
        self.available = available
        self.availableCount = availableCount
        self.totalEarnedCount = totalEarnedCount
        self.credits = credits
        self.earliestExpiresAt = earliestExpiresAt
        self.nextExpirationAt = nextExpirationAt
    }

    private enum CodingKeys: String, CodingKey {
        case available
        case availableCount
        case totalEarnedCount
        case credits
        case earliestExpiresAt
        case nextExpirationAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        available = try container.decodeIfPresent(Bool.self, forKey: .available)
        availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount)
        totalEarnedCount = try container.decodeIfPresent(Int.self, forKey: .totalEarnedCount)
        credits = try container.decodeIfPresent([AccountResetCreditCard].self, forKey: .credits) ?? []
        earliestExpiresAt = try container.decodeIfPresent(TimeInterval.self, forKey: .earliestExpiresAt)
        nextExpirationAt = try container.decodeIfPresent(TimeInterval.self, forKey: .nextExpirationAt)
    }
}

public struct AccountUsageSummary: Codable, Equatable, Sendable {
    public let lifetimeTokens: Int?
    public let peakDailyTokens: Int?
    public let longestRunningTurnSec: Int?
    public let currentStreakDays: Int?
    public let longestStreakDays: Int?
}

public struct AccountDailyUsageBucket: Codable, Equatable, Sendable {
    public let startDate: String
    public let tokens: Int
}

public struct AccountUsage: Codable, Equatable, Sendable {
    public let summary: AccountUsageSummary?
    public let dailyUsageBuckets: [AccountDailyUsageBucket]?
}

public struct AccountUsageMetrics: Codable, Equatable, Sendable {
    public let todayTokens: Int?
    public let todayAvailable: Bool?
    public let last7Tokens: Int?
    public let last14Tokens: Int?
    public let latestDate: String?
    public let source: String?
}

public struct AccountAttributionAccuracy: Codable, Equatable, Sendable {
    public let date: String
    public let estimatedTokens: Int
    public let officialTokens: Int
    public let deltaTokens: Int
    public let deltaPercent: Double?
}

public struct AccountTokenAttribution: Codable, Equatable, Sendable {
    public let activeProfile: String?
    public let managed: Bool
    public let estimateAvailable: Bool
    public let todayEstimatedTokens: Int?
    public let todayOfficialTokens: Int?
    public let todayDisplayTokens: Int?
    public let todaySource: String?
    public let previousDayAccuracy: AccountAttributionAccuracy?
}

public struct AccountProjectRankingItem: Codable, Equatable, Sendable {
    public let name: String
    public let path: String
    public let threadCount: Int
    public let tokensUsed: Int
    public let latestUpdatedAt: Int
}

public struct AccountProjectRankings: Codable, Equatable, Sendable {
    public let available: Bool
    public let projects: [AccountProjectRankingItem]
}

public struct AccountToolRankingItem: Codable, Equatable, Sendable {
    public let id: String
    public let namespace: String
    public let name: String
    public let callCount: Int
    public let latestUpdatedAt: Int
    public let threadTokens: Int
}

public struct AccountToolRankings: Codable, Equatable, Sendable {
    public let available: Bool
    public let tools: [AccountToolRankingItem]
}

public struct AccountSkillRankingItem: Codable, Equatable, Sendable {
    public let name: String
    public let useCount: Int
    public let latestTimestamp: String?
}

public struct AccountSkillRankings: Codable, Equatable, Sendable {
    public let available: Bool
    public let skills: [AccountSkillRankingItem]
    public let badLineCount: Int?
}

public struct AccountProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }

    public let name: String
    public let path: String?
    public let auth: String
    public let config: String
    public let account: AccountStatusSummary?
    public let rateLimits: AccountRateLimits
    public let resetCreditDetails: AccountResetCreditDetails?
    public let resetCreditStale: Bool?
    public let resetCreditError: String?
    public let usage: AccountUsage?
    public let usageMetrics: AccountUsageMetrics?
    public let tokenAttribution: AccountTokenAttribution?
    public let remoteStale: Bool?
    public let remoteError: String?

    public init(
        name: String,
        path: String? = nil,
        auth: String,
        config: String,
        rateLimits: AccountRateLimits,
        resetCreditDetails: AccountResetCreditDetails? = nil,
        remoteStale: Bool? = nil,
        remoteError: String? = nil,
        account: AccountStatusSummary? = nil,
        resetCreditStale: Bool? = nil,
        resetCreditError: String? = nil,
        usage: AccountUsage? = nil,
        usageMetrics: AccountUsageMetrics? = nil,
        tokenAttribution: AccountTokenAttribution? = nil
    ) {
        self.name = name
        self.path = path
        self.auth = auth
        self.config = config
        self.account = account
        self.rateLimits = rateLimits
        self.resetCreditDetails = resetCreditDetails
        self.resetCreditStale = resetCreditStale
        self.resetCreditError = resetCreditError
        self.usage = usage
        self.usageMetrics = usageMetrics
        self.tokenAttribution = tokenAttribution
        self.remoteStale = remoteStale
        self.remoteError = remoteError
    }
}

public enum AccountMode: String, Codable, Equatable, Sendable {
    case managedProfiles = "managed_profiles"
    case localDefault = "local_default"
    case unavailable

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unavailable
    }
}

public struct AccountDashboardPayload: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let activeProfile: String?
    public let accountMode: AccountMode
    public let runtimeStatus: AccountRuntimeStatus?
    public let desktopStatus: AccountDesktopStatus?
    public let profileRoles: AccountProfileRoles?
    public let attributionSummary: AccountAttributionSummary?
    public let localSnapshot: AccountLocalTokenSnapshot?
    public let projectRankings: AccountProjectRankings?
    public let toolRankings: AccountToolRankings?
    public let skillRankings: AccountSkillRankings?
    public let profiles: [AccountProfile]

    public init(
        generatedAt: Date,
        activeProfile: String?,
        accountMode: AccountMode = .managedProfiles,
        desktopStatus: AccountDesktopStatus?,
        profileRoles: AccountProfileRoles?,
        profiles: [AccountProfile],
        runtimeStatus: AccountRuntimeStatus? = nil,
        attributionSummary: AccountAttributionSummary? = nil,
        localSnapshot: AccountLocalTokenSnapshot? = nil,
        projectRankings: AccountProjectRankings? = nil,
        toolRankings: AccountToolRankings? = nil,
        skillRankings: AccountSkillRankings? = nil
    ) {
        self.generatedAt = generatedAt
        self.activeProfile = activeProfile
        self.accountMode = accountMode
        self.runtimeStatus = runtimeStatus
        self.desktopStatus = desktopStatus
        self.profileRoles = profileRoles
        self.attributionSummary = attributionSummary
        self.localSnapshot = localSnapshot
        self.projectRankings = projectRankings
        self.toolRankings = toolRankings
        self.skillRankings = skillRankings
        self.profiles = profiles
    }

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case activeProfile
        case accountMode
        case runtimeStatus
        case desktopStatus
        case profileRoles
        case attributionSummary
        case localSnapshot
        case projectRankings
        case toolRankings
        case skillRankings
        case profiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        activeProfile = try container.decodeIfPresent(String.self, forKey: .activeProfile)
        accountMode = try container.decodeIfPresent(AccountMode.self, forKey: .accountMode)
            ?? .managedProfiles
        runtimeStatus = try container.decodeIfPresent(AccountRuntimeStatus.self, forKey: .runtimeStatus)
        desktopStatus = try container.decodeIfPresent(AccountDesktopStatus.self, forKey: .desktopStatus)
        profileRoles = try container.decodeIfPresent(AccountProfileRoles.self, forKey: .profileRoles)
        attributionSummary = try container.decodeIfPresent(
            AccountAttributionSummary.self,
            forKey: .attributionSummary
        )
        localSnapshot = try container.decodeIfPresent(
            AccountLocalTokenSnapshot.self,
            forKey: .localSnapshot
        )
        projectRankings = try container.decodeIfPresent(
            AccountProjectRankings.self,
            forKey: .projectRankings
        )
        toolRankings = try container.decodeIfPresent(
            AccountToolRankings.self,
            forKey: .toolRankings
        )
        skillRankings = try container.decodeIfPresent(
            AccountSkillRankings.self,
            forKey: .skillRankings
        )
        profiles = try container.decode([AccountProfile].self, forKey: .profiles)
    }

    public static func decode(data: Data) throws -> AccountDashboardPayload {
        try LedgerRepository.decoder().decode(AccountDashboardPayload.self, from: data)
    }
}
