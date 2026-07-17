import CodexWorkbenchCore
import SwiftUI

struct AccountsView: View {
    @ObservedObject var model: WorkbenchAppModel

    private var details: AccountDetailsPresentation {
        AccountPresentationBuilder.details(payload: model.accountPayload)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                PageHeader(
                    eyebrow: "Accounts",
                    title: "账号管理",
                    description: "查看 Codex 当前实际登录账号的额度、重置卡和用量，并在同一工作台安全切换账号。",
                    trailing: AnyView(
                        Button("刷新额度") {
                            Task { await model.refreshAll(refreshResetCredits: true) }
                        }
                        .disabled(model.isRefreshing)
                        .accessibilityLabel("刷新账号额度")
                    )
                )

                if model.isLegacyProfileSwitcherRunning {
                    AccountNotice(
                        title: "冷备 App 正在运行",
                        message: "为避免重复提醒或自动使用重置卡，工作台的账号自动化已暂停。退出旧 Profile Switcher 后刷新即可恢复。",
                        color: .orange,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                }

                if let error = model.accountError {
                    AccountNotice(
                        title: "账号数据已降级",
                        message: error,
                        color: .orange,
                        systemImage: "exclamationmark.circle.fill"
                    )
                }

                if let current = details.currentProfile {
                    CurrentAccountSection(
                        profile: current,
                        payload: model.accountPayload,
                        runtime: model.runtimePresentation
                    )

                    ResetCreditsSection(
                        profile: current,
                        cards: details.currentResetCards
                    )

                    AccountUsageSection(profile: current)
                } else if model.isRefreshing {
                    SurfaceCard {
                        HStack(spacing: WorkbenchSpacing.sm) {
                            ProgressView().controlSize(.small)
                            Text("正在确认当前登录账号与额度…")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 92)
                    }
                } else {
                    SurfaceCard {
                        QuietEmptyState(
                            systemImage: "person.crop.circle.badge.questionmark",
                            title: "当前登录账号未知",
                            message: "工作台没有拿到可靠的登录状态，因此不会把最近任务或统计归因账号当作当前账号。"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                OtherAccountsSection(
                    profiles: details.otherProfiles,
                    currentProfile: model.currentProfileName,
                    switchStage: model.accountSwitchStage,
                    onSwitch: model.switchProfile
                )

                AccountDiagnosticsSection(payload: model.accountPayload)
            }
            .padding(.horizontal, WorkbenchSpacing.lg)
            .padding(.vertical, WorkbenchSpacing.lg)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("accounts-page")
    }
}

private struct CurrentAccountSection: View {
    let profile: AccountProfile
    let payload: AccountDashboardPayload?
    let runtime: AccountRuntimePresentation

    var body: some View {
        SurfaceCard(selected: true) {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.md) {
                HStack(alignment: .center, spacing: WorkbenchSpacing.sm) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(AccountPresentationBuilder.profileDisplayName(profile.name))
                                .font(.system(size: 18, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            StatusChip("当前登录账号", color: .accentColor, systemImage: "checkmark.circle.fill")
                        }
                        Text(profile.name)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        StatusChip(
                            runtime.label,
                            color: runtimeColor,
                            systemImage: runtime.symbol
                        )
                        Text(managedText)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 185, maximum: 300), spacing: WorkbenchSpacing.sm)],
                    alignment: .leading,
                    spacing: WorkbenchSpacing.sm
                ) {
                    AccountQuotaTile(
                        title: quotaTitle(profile.rateLimits.primary, fallback: "主要额度"),
                        window: profile.rateLimits.primary
                    )
                    AccountQuotaTile(
                        title: quotaTitle(profile.rateLimits.secondary, fallback: "其他额度"),
                        window: profile.rateLimits.secondary
                    )
                    ResetCreditSummaryTile(profile: profile)
                }

                HStack(spacing: WorkbenchSpacing.md) {
                    Label(planText, systemImage: "person.text.rectangle")
                    Label(statusText, systemImage: "checkmark.shield")
                    if profile.remoteStale == true {
                        Label("远端数据为暂存", systemImage: "clock.badge.exclamationmark")
                            .foregroundStyle(Color.orange)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var managedText: String {
        payload?.desktopStatus?.managed == true ? "登录状态已接管" : "登录状态未接管"
    }

    private var planText: String {
        "套餐：\(profile.account?.planType?.uppercased() ?? profile.rateLimits.planType?.uppercased() ?? "未知")"
    }

    private var statusText: String {
        profile.auth == "present" && profile.config == "present" ? "认证与配置完整" : "账号文件不完整"
    }

    private var runtimeColor: Color {
        switch runtime.state {
        case "running": .green
        case "waiting": .orange
        default: .secondary
        }
    }

    private func quotaTitle(_ window: AccountQuotaWindow?, fallback: String) -> String {
        AccountPresentationBuilder.quotaWindowName(minutes: window?.windowMinutes)
            .map { "\($0)额度" }
            ?? fallback
    }
}

private struct AccountQuotaTile: View {
    let title: String
    let window: AccountQuotaWindow?

    private var remaining: Double? { window?.remainingPercent }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(remaining.map { "\(Int($0.rounded()))%" } ?? "--")
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.workbenchBorder.opacity(0.5))
                    Capsule()
                        .fill(quotaColor)
                        .frame(width: proxy.size.width * max(0, min(1, (remaining ?? 0) / 100)))
                }
            }
            .frame(height: 6)
            Text(resetText)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(WorkbenchSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.workbenchWindow.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.workbenchBorder.opacity(0.55), lineWidth: 0.5)
        )
    }

    private var resetText: String {
        guard let date = window?.resetsAtDate else { return "重置时间未知" }
        return "重置于 \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var quotaColor: Color {
        guard let remaining else { return .secondary }
        if remaining <= 10 { return .red }
        if remaining <= 30 { return .orange }
        return .accentColor
    }
}

private struct ResetCreditSummaryTile: View {
    let profile: AccountProfile

    private var count: Int? {
        profile.resetCreditDetails?.availableCount
            ?? profile.rateLimits.resetCredits?.availableCount
            ?? profile.rateLimits.creditsAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
            Text("可用重置卡")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(count.map(String.init) ?? "--")
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
            Text(expiryText)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(WorkbenchSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.workbenchWindow.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.workbenchBorder.opacity(0.55), lineWidth: 0.5)
        )
    }

    private var expiryText: String {
        guard
            let value = profile.resetCreditDetails?.earliestExpiresAt
                ?? profile.rateLimits.resetCredits?.expiresAt
        else {
            return "到期时间未知"
        }
        let date = Date(timeIntervalSince1970: value)
        return "最早于 \(date.formatted(date: .abbreviated, time: .shortened)) 到期"
    }
}

private struct ResetCreditsSection: View {
    let profile: AccountProfile
    let cards: [AccountResetCreditCard]

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
            SectionTitle("重置卡明细", detail: cards.isEmpty ? nil : "\(cards.count) 张记录")
            SurfaceCard(padding: 0) {
                if cards.isEmpty {
                    HStack(spacing: WorkbenchSpacing.sm) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("暂无逐张明细")
                                .font(.system(size: 11, weight: .medium))
                            Text(profile.resetCreditError ?? "后端没有返回可展示的重置卡记录。")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(WorkbenchSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(cards.enumerated()), id: \.element.stableID) { index, card in
                        ResetCreditRow(card: card)
                        if index < cards.count - 1 {
                            Divider().padding(.leading, WorkbenchSpacing.md)
                        }
                    }
                }
            }
        }
    }
}

private struct ResetCreditRow: View {
    let card: AccountResetCreditCard

    var body: some View {
        HStack(spacing: WorkbenchSpacing.sm) {
            Image(systemName: statusSymbol)
                .foregroundStyle(statusColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(card.title ?? "额度重置卡")
                    .font(.system(size: 11, weight: .medium))
                Text(card.description ?? "可在官方确认额度耗尽后恢复可用额度")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: WorkbenchSpacing.md)
            VStack(alignment: .trailing, spacing: 3) {
                StatusChip(statusText, color: statusColor, systemImage: statusSymbol)
                Text(expiryText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, WorkbenchSpacing.md)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        if card.used == true { return "已使用" }
        if let expiry = card.expiresAt, expiry <= Date().timeIntervalSince1970 { return "已过期" }
        return "可用"
    }

    private var statusColor: Color {
        statusText == "可用" ? .green : .secondary
    }

    private var statusSymbol: String {
        statusText == "可用" ? "checkmark.circle.fill" : "circle.slash"
    }

    private var expiryText: String {
        guard let expiry = card.expiresAt else { return "到期时间未知" }
        return "到期：\(Date(timeIntervalSince1970: expiry).formatted(date: .abbreviated, time: .shortened))"
    }
}

private struct AccountUsageSection: View {
    let profile: AccountProfile

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
            SectionTitle(
                "账号用量",
                detail: AccountPresentationBuilder.usageSourceLabel(profile.usageMetrics?.source)
            )
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150, maximum: 250), spacing: WorkbenchSpacing.sm)],
                spacing: WorkbenchSpacing.sm
            ) {
                UsageMetric(title: "今日 Tokens", value: compact(profile.usageMetrics?.todayTokens))
                UsageMetric(title: "近 7 日", value: compact(profile.usageMetrics?.last7Tokens))
                UsageMetric(title: "历史累计", value: compact(profile.usage?.summary?.lifetimeTokens))
                UsageMetric(
                    title: "连续使用",
                    value: profile.usage?.summary?.currentStreakDays.map { "\($0) 天" } ?? "--"
                )
            }
        }
    }

    private func compact(_ value: Int?) -> String {
        guard let value else { return "--" }
        let number = Double(value)
        if abs(number) >= 1_000_000_000 { return String(format: "%.1fB", number / 1_000_000_000) }
        if abs(number) >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
        if abs(number) >= 1_000 { return String(format: "%.1fK", number / 1_000) }
        return "\(value)"
    }
}

private struct UsageMetric: View {
    let title: String
    let value: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
    }
}

private struct OtherAccountsSection: View {
    let profiles: [AccountProfile]
    let currentProfile: String?
    let switchStage: AccountSwitchStage?
    let onSwitch: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
            SectionTitle("其他账号", detail: profiles.isEmpty ? "没有其他可切换账号" : "\(profiles.count) 个")
            if profiles.isEmpty {
                SurfaceCard {
                    Text("当前没有其他已配置账号。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                }
            } else {
                ForEach(profiles) { profile in
                    OtherAccountRow(
                        profile: profile,
                        switchStage: switchStage,
                        onSwitch: { onSwitch(profile.name) }
                    )
                }
            }
        }
    }
}

private struct OtherAccountRow: View {
    let profile: AccountProfile
    let switchStage: AccountSwitchStage?
    let onSwitch: () -> Void

    var body: some View {
        SurfaceCard {
            HStack(spacing: WorkbenchSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AccountPresentationBuilder.profileDisplayName(profile.name))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(profile.name)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(minWidth: 130, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                CompactAccountValue(
                    title: quotaTitle(profile.rateLimits.primary, fallback: "主要"),
                    value: quota(profile.rateLimits.primary)
                )
                CompactAccountValue(
                    title: quotaTitle(profile.rateLimits.secondary, fallback: "其他"),
                    value: quota(profile.rateLimits.secondary)
                )
                CompactAccountValue(title: "重置卡", value: resetCount)

                Button(action: onSwitch) {
                    if switchStage?.profile == profile.name {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.small)
                            Text(stageText)
                        }
                    } else {
                        Text("切换并重启 Codex")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(switchStage != nil)
                .frame(width: 132)
                .accessibilityLabel(
                    "切换到 \(AccountPresentationBuilder.profileDisplayName(profile.name)) 并重启 Codex"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func quota(_ window: AccountQuotaWindow?) -> String {
        window?.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "--"
    }

    private var resetCount: String {
        (
            profile.resetCreditDetails?.availableCount
                ?? profile.rateLimits.resetCredits?.availableCount
                ?? profile.rateLimits.creditsAvailable
        ).map(String.init) ?? "--"
    }

    private func quotaTitle(_ window: AccountQuotaWindow?, fallback: String) -> String {
        AccountPresentationBuilder.quotaWindowName(minutes: window?.windowMinutes) ?? fallback
    }

    private var stageText: String {
        switch switchStage {
        case .switching: "切换中"
        case .verifying: "验证中"
        case nil: ""
        }
    }
}

private struct CompactAccountValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .frame(width: 58, alignment: .leading)
    }
}

private struct AccountDiagnosticsSection: View {
    let payload: AccountDashboardPayload?

    var body: some View {
        DisclosureGroup("高级诊断") {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                if let roles = payload?.profileRoles {
                    DiagnosticLine(title: "最近任务（可能为推断）", role: roles.task)
                    DiagnosticLine(title: "统计归因", role: roles.attribution)
                }
                if let status = payload?.desktopStatus {
                    HStack {
                        Text("账号接管")
                        Spacer()
                        Text(status.message ?? status.state)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Text("这些诊断值不会用于决定页面顶部的当前登录账号。")
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 10))
            .padding(.top, WorkbenchSpacing.xs)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(WorkbenchSpacing.md)
        .background(Color.workbenchCard, in: RoundedRectangle(cornerRadius: WorkbenchRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchRadius.card)
                .stroke(Color.workbenchBorder.opacity(0.65), lineWidth: 0.5)
        )
    }
}

private struct DiagnosticLine: View {
    let title: String
    let role: AccountRole

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(role.profile.map(AccountPresentationBuilder.profileDisplayName) ?? "未知")
                .foregroundStyle(.secondary)
            StatusChip(role.confidence.displayName, color: role.confidence.color)
        }
    }
}

private struct AccountNotice: View {
    let title: String
    let message: String
    let color: Color
    let systemImage: String

    var body: some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                Image(systemName: systemImage)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(message)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
