import Foundation

public struct AccountMenuPresentation: Equatable, Sendable {
    public let profile: String?
    public let quotaText: String
    public let quotaWindowLabel: String
    public let runtimeLabel: String
    public let runtimeSymbol: String
    public let accessibilityLabel: String

    public init(
        profile: String?,
        quotaText: String,
        quotaWindowLabel: String,
        runtimeLabel: String,
        runtimeSymbol: String,
        accessibilityLabel: String
    ) {
        self.profile = profile
        self.quotaText = quotaText
        self.quotaWindowLabel = quotaWindowLabel
        self.runtimeLabel = runtimeLabel
        self.runtimeSymbol = runtimeSymbol
        self.accessibilityLabel = accessibilityLabel
    }
}

public enum AccountPresentationBuilder {
    public static func menu(payload: AccountDashboardPayload?) -> AccountMenuPresentation {
        let profileName = payload?.activeProfile ?? payload?.desktopStatus?.activeProfile
        let profile = payload?.profiles.first { $0.name == profileName }
        let window = profile?.rateLimits.primary
        let quotaText = window?.remainingPercent.map(formatPercent) ?? "--"
        let quotaWindowLabel = windowLabel(minutes: window?.windowMinutes)
        let runtimeLabel = nonEmpty(payload?.runtimeStatus?.label) ?? "未知"
        let runtimeSymbol = symbol(light: payload?.runtimeStatus?.light)
        let accountText = profileName.map { "当前登录账号 \($0)" } ?? "当前登录账号未知"
        let quotaDescription = window?.remainingPercent == nil
            ? "额度未知"
            : "\(quotaWindowLabel) \(quotaText)"

        return AccountMenuPresentation(
            profile: profileName,
            quotaText: quotaText,
            quotaWindowLabel: quotaWindowLabel,
            runtimeLabel: runtimeLabel,
            runtimeSymbol: runtimeSymbol,
            accessibilityLabel: "\(accountText)，\(quotaDescription)，Codex \(runtimeLabel)"
        )
    }

    private static func formatPercent(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    private static func windowLabel(minutes: Int?) -> String {
        switch minutes {
        case 300:
            return "5小时剩余"
        case 10_080:
            return "7日剩余"
        case let value? where value % (24 * 60) == 0:
            return "\(value / (24 * 60))日剩余"
        case let value? where value % 60 == 0:
            return "\(value / 60)小时剩余"
        case let value?:
            return "\(value)分钟剩余"
        case nil:
            return "额度"
        }
    }

    private static func symbol(light: String?) -> String {
        switch light {
        case "green":
            return "bolt.circle.fill"
        case "yellow":
            return "pause.circle.fill"
        case "red":
            return "circle"
        default:
            return "questionmark.circle"
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }
}
