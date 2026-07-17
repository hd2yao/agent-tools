import Foundation

public struct AccountMenuPresentation: Equatable, Sendable {
    public let profile: String?
    public let profileDisplayName: String
    public let quotaText: String
    public let quotaWindowLabel: String
    public let secondaryQuotaText: String
    public let secondaryQuotaWindowLabel: String
    public let resetCreditText: String
    public let runtimeLabel: String
    public let runtimeSymbol: String
    public let accessibilityLabel: String

    public init(
        profile: String?,
        profileDisplayName: String,
        quotaText: String,
        quotaWindowLabel: String,
        secondaryQuotaText: String,
        secondaryQuotaWindowLabel: String,
        resetCreditText: String,
        runtimeLabel: String,
        runtimeSymbol: String,
        accessibilityLabel: String
    ) {
        self.profile = profile
        self.profileDisplayName = profileDisplayName
        self.quotaText = quotaText
        self.quotaWindowLabel = quotaWindowLabel
        self.secondaryQuotaText = secondaryQuotaText
        self.secondaryQuotaWindowLabel = secondaryQuotaWindowLabel
        self.resetCreditText = resetCreditText
        self.runtimeLabel = runtimeLabel
        self.runtimeSymbol = runtimeSymbol
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct AccountRuntimePresentation: Equatable, Sendable {
    public let state: String
    public let label: String
    public let detail: String
    public let symbol: String

    public init(state: String, label: String, detail: String, symbol: String) {
        self.state = state
        self.label = label
        self.detail = detail
        self.symbol = symbol
    }
}

public struct AccountDetailsPresentation: Equatable, Sendable {
    public let currentProfile: AccountProfile?
    public let otherProfiles: [AccountProfile]
    public let currentResetCards: [AccountResetCreditCard]

    public init(
        currentProfile: AccountProfile?,
        otherProfiles: [AccountProfile],
        currentResetCards: [AccountResetCreditCard]
    ) {
        self.currentProfile = currentProfile
        self.otherProfiles = otherProfiles
        self.currentResetCards = currentResetCards
    }
}

public struct WorkspaceInsightsPresentation: Equatable, Sendable {
    public let projectsAvailable: Bool
    public let toolsAvailable: Bool
    public let skillsAvailable: Bool
    public let projects: [AccountProjectRankingItem]
    public let tools: [AccountToolRankingItem]
    public let skills: [AccountSkillRankingItem]

    public init(
        projectsAvailable: Bool,
        toolsAvailable: Bool,
        skillsAvailable: Bool,
        projects: [AccountProjectRankingItem],
        tools: [AccountToolRankingItem],
        skills: [AccountSkillRankingItem]
    ) {
        self.projectsAvailable = projectsAvailable
        self.toolsAvailable = toolsAvailable
        self.skillsAvailable = skillsAvailable
        self.projects = projects
        self.tools = tools
        self.skills = skills
    }
}

public enum AccountPresentationBuilder {
    public static func menu(payload: AccountDashboardPayload?) -> AccountMenuPresentation {
        let profileName = payload?.activeProfile ?? payload?.desktopStatus?.activeProfile
        let profile = payload?.profiles.first { $0.name == profileName }
        let window = profile?.rateLimits.primary
        let secondaryWindow = profile?.rateLimits.secondary
        let quotaText = window?.remainingPercent.map(formatPercent) ?? "--"
        let quotaWindowLabel = windowLabel(minutes: window?.windowMinutes)
        let secondaryQuotaText = secondaryWindow?.remainingPercent.map(formatPercent) ?? "--"
        let secondaryQuotaWindowLabel = windowLabel(minutes: secondaryWindow?.windowMinutes)
        let resetCreditText = (
            profile?.resetCreditDetails?.availableCount
                ?? profile?.rateLimits.resetCredits?.availableCount
                ?? profile?.rateLimits.creditsAvailable
        ).map(String.init) ?? "--"
        let runtime = runtime(status: payload?.runtimeStatus)
        let accountText = profileName.map { "当前登录账号 \($0)" } ?? "当前登录账号未知"
        let quotaDescription = window?.remainingPercent == nil
            ? "额度未知"
            : "\(quotaWindowLabel) \(quotaText)"

        return AccountMenuPresentation(
            profile: profileName,
            profileDisplayName: profileDisplayName(profileName),
            quotaText: quotaText,
            quotaWindowLabel: quotaWindowLabel,
            secondaryQuotaText: secondaryQuotaText,
            secondaryQuotaWindowLabel: secondaryQuotaWindowLabel,
            resetCreditText: resetCreditText,
            runtimeLabel: runtime.label,
            runtimeSymbol: runtime.symbol,
            accessibilityLabel: "\(accountText)，\(quotaDescription)，Codex \(runtime.label)"
        )
    }

    public static func profileDisplayName(_ profile: String?) -> String {
        guard let profile else { return "未知账号" }
        return profile.hasPrefix("hd-") ? String(profile.dropFirst(3)) : profile
    }

    public static func usageSourceLabel(_ source: String?) -> String {
        switch source {
        case "account_usage": "官方账号用量"
        case "local", "local_usage": "本地用量"
        case nil, "": "本地与官方数据"
        default: "账号统计"
        }
    }

    public static func quotaWindowName(minutes: Int?) -> String? {
        switch minutes {
        case 300:
            return "5 小时"
        case 10_080:
            return "7 日"
        case let value? where value % (24 * 60) == 0:
            return "\(value / (24 * 60)) 日"
        case let value? where value % 60 == 0:
            return "\(value / 60) 小时"
        case let value?:
            return "\(value) 分钟"
        case nil:
            return nil
        }
    }

    public static func details(payload: AccountDashboardPayload?) -> AccountDetailsPresentation {
        guard let payload else {
            return AccountDetailsPresentation(
                currentProfile: nil,
                otherProfiles: [],
                currentResetCards: []
            )
        }
        let currentName = payload.activeProfile ?? payload.desktopStatus?.activeProfile
        let currentProfile = payload.profiles.first { $0.name == currentName }
        let otherProfiles = payload.profiles
            .filter { $0.name != currentName }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let resetCards = (currentProfile?.resetCreditDetails?.credits ?? []).sorted { lhs, rhs in
            let lhsUsed = lhs.used == true
            let rhsUsed = rhs.used == true
            if lhsUsed != rhsUsed { return !lhsUsed }
            return (lhs.expiresAt ?? .greatestFiniteMagnitude)
                < (rhs.expiresAt ?? .greatestFiniteMagnitude)
        }
        return AccountDetailsPresentation(
            currentProfile: currentProfile,
            otherProfiles: otherProfiles,
            currentResetCards: resetCards
        )
    }

    public static func workspaceInsights(
        payload: AccountDashboardPayload?
    ) -> WorkspaceInsightsPresentation {
        WorkspaceInsightsPresentation(
            projectsAvailable: payload?.projectRankings?.available ?? false,
            toolsAvailable: payload?.toolRankings?.available ?? false,
            skillsAvailable: payload?.skillRankings?.available ?? false,
            projects: (payload?.projectRankings?.projects ?? []).sorted { lhs, rhs in
                if lhs.tokensUsed == rhs.tokensUsed { return lhs.name < rhs.name }
                return lhs.tokensUsed > rhs.tokensUsed
            },
            tools: (payload?.toolRankings?.tools ?? []).sorted { lhs, rhs in
                if lhs.callCount == rhs.callCount { return lhs.id < rhs.id }
                return lhs.callCount > rhs.callCount
            },
            skills: (payload?.skillRankings?.skills ?? []).sorted { lhs, rhs in
                if lhs.useCount == rhs.useCount { return lhs.name < rhs.name }
                return lhs.useCount > rhs.useCount
            }
        )
    }

    public static func runtime(status: AccountRuntimeStatus?) -> AccountRuntimePresentation {
        guard let status else {
            return AccountRuntimePresentation(
                state: "unknown",
                label: "未知",
                detail: "尚未读取运行状态",
                symbol: "questionmark.circle"
            )
        }

        switch status.state {
        case "running":
            let detail = status.activeProcessCount > 0
                ? "\(status.activeProcessCount) 个对话进程正在运行"
                : "最近 90 秒内有 Codex 输出"
            return AccountRuntimePresentation(
                state: "running",
                label: "运行中",
                detail: detail,
                symbol: "bolt.circle.fill"
            )
        case "waiting":
            return AccountRuntimePresentation(
                state: "waiting",
                label: "待接手",
                detail: "最近 15 分钟内有活动，可能等你继续",
                symbol: "pause.circle.fill"
            )
        case "idle":
            return AccountRuntimePresentation(
                state: "idle",
                label: "空闲",
                detail: "当前没有运行中的对话",
                symbol: "circle"
            )
        default:
            return AccountRuntimePresentation(
                state: "unknown",
                label: "未知",
                detail: "尚未读取运行状态",
                symbol: "questionmark.circle"
            )
        }
    }

    private static func formatPercent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static func windowLabel(minutes: Int?) -> String {
        quotaWindowName(minutes: minutes)?
            .replacingOccurrences(of: " ", with: "")
            .appending("剩余")
            ?? "额度"
    }
}
