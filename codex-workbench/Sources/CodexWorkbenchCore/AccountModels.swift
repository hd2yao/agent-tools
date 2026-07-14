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
    public let primary: AccountQuotaWindow?
    public let secondary: AccountQuotaWindow?
    public let resetCredits: AccountResetCredits?

    public init(
        planType: String? = nil,
        limitName: String? = nil,
        primary: AccountQuotaWindow? = nil,
        secondary: AccountQuotaWindow? = nil,
        resetCredits: AccountResetCredits? = nil
    ) {
        self.planType = planType
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.resetCredits = resetCredits
    }
}

public struct AccountResetCreditDetails: Codable, Equatable, Sendable {
    public let availableCount: Int?
    public let nextExpirationAt: TimeInterval?

    public init(availableCount: Int? = nil, nextExpirationAt: TimeInterval? = nil) {
        self.availableCount = availableCount
        self.nextExpirationAt = nextExpirationAt
    }
}

public struct AccountProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }

    public let name: String
    public let auth: String
    public let config: String
    public let rateLimits: AccountRateLimits
    public let resetCreditDetails: AccountResetCreditDetails?
    public let remoteStale: Bool?
    public let remoteError: String?

    public init(
        name: String,
        auth: String,
        config: String,
        rateLimits: AccountRateLimits,
        resetCreditDetails: AccountResetCreditDetails? = nil,
        remoteStale: Bool? = nil,
        remoteError: String? = nil
    ) {
        self.name = name
        self.auth = auth
        self.config = config
        self.rateLimits = rateLimits
        self.resetCreditDetails = resetCreditDetails
        self.remoteStale = remoteStale
        self.remoteError = remoteError
    }
}

public struct AccountDashboardPayload: Codable, Equatable, Sendable {
    public let generatedAt: Date
    public let activeProfile: String?
    public let desktopStatus: AccountDesktopStatus?
    public let profileRoles: AccountProfileRoles?
    public let profiles: [AccountProfile]

    public init(
        generatedAt: Date,
        activeProfile: String?,
        desktopStatus: AccountDesktopStatus?,
        profileRoles: AccountProfileRoles?,
        profiles: [AccountProfile]
    ) {
        self.generatedAt = generatedAt
        self.activeProfile = activeProfile
        self.desktopStatus = desktopStatus
        self.profileRoles = profileRoles
        self.profiles = profiles
    }

    public static func decode(data: Data) throws -> AccountDashboardPayload {
        try LedgerRepository.decoder().decode(AccountDashboardPayload.self, from: data)
    }
}
