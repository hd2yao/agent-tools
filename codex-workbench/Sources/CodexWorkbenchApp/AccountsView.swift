import CodexWorkbenchCore
import SwiftUI

struct AccountsView: View {
    @ObservedObject var model: WorkbenchAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                PageHeader(
                    eyebrow: "Accounts",
                    title: "账号管理",
                    description: "账号是工具台中的独立模块。最近任务、桌面默认和统计归因不会混作同一个“当前账号”。",
                    trailing: AnyView(
                        Button("刷新额度") {
                            Task { await model.refreshAll(refreshResetCredits: true) }
                        }
                        .disabled(model.isRefreshing)
                    )
                )

                if let roles = model.accountPayload?.profileRoles {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 210, maximum: 340), spacing: WorkbenchSpacing.sm)],
                        spacing: WorkbenchSpacing.sm
                    ) {
                        AccountRoleCard(
                            title: "最近活动任务",
                            detail: "只代表最近任务的账号匹配",
                            role: roles.task,
                            systemImage: "bubble.left.and.bubble.right"
                        )
                        AccountRoleCard(
                            title: "桌面默认",
                            detail: "Codex App 当前默认账号",
                            role: roles.desktop,
                            systemImage: "macwindow"
                        )
                        AccountRoleCard(
                            title: "统计归因",
                            detail: "本地用量归因记录",
                            role: roles.attribution,
                            systemImage: "chart.bar"
                        )
                    }
                }

                if let error = model.accountError {
                    SurfaceCard {
                        HStack(spacing: WorkbenchSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("账号数据已降级")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                    SectionTitle(
                        "账号 Profile",
                        detail: model.accountPayload.map { "\($0.profiles.count) 个" }
                    )
                    if let payload = model.accountPayload, !payload.profiles.isEmpty {
                        ForEach(payload.profiles) { profile in
                            AccountProfileCard(
                                profile: profile,
                                roles: payload.profileRoles,
                                isDesktopProfile: model.desktopProfileName == profile.name,
                                switchingProfile: model.switchingProfile,
                                onSwitch: { model.switchProfile(profile.name) }
                            )
                        }
                    } else if model.isRefreshing {
                        SurfaceCard {
                            HStack(spacing: WorkbenchSpacing.sm) {
                                ProgressView().controlSize(.small)
                                Text("正在读取账号与额度…")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 80)
                        }
                    } else {
                        SurfaceCard {
                            QuietEmptyState(
                                systemImage: "person.crop.circle.badge.questionmark",
                                title: "没有可显示的账号",
                                message: "独立 Profile Switcher 仍可继续使用；重新构建工具台可恢复账号模块。"
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                SurfaceCard {
                    HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模块边界")
                                .font(.system(size: 11, weight: .semibold))
                            Text("工具台调用 Profile Switcher 的账号后端；Profile Switcher 仍可独立运行，也不会承载全局操作日志。")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(WorkbenchSpacing.lg)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("accounts-page")
    }
}

private struct AccountRoleCard: View {
    let title: String
    let detail: String
    let role: AccountRole
    let systemImage: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    StatusChip(role.confidence.displayName, color: role.confidence.color)
                }
                Text(role.profile ?? "未知")
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(role.source)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        }
    }
}

private struct AccountProfileCard: View {
    let profile: AccountProfile
    let roles: AccountProfileRoles?
    let isDesktopProfile: Bool
    let switchingProfile: String?
    let onSwitch: () -> Void

    private var primary: AccountQuotaWindow? { profile.rateLimits.primary }
    private var remainingPercent: Double? { primary?.remainingPercent }
    private var resetCount: Int? {
        profile.resetCreditDetails?.availableCount
            ?? profile.rateLimits.resetCredits?.availableCount
    }

    var body: some View {
        SurfaceCard(selected: isDesktopProfile) {
            HStack(alignment: .center, spacing: WorkbenchSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if isDesktopProfile {
                            StatusChip("桌面默认", color: .accentColor)
                        }
                    }
                    HStack(spacing: 5) {
                        if roles?.task.profile == profile.name {
                            StatusChip("最近任务", color: roles?.task.confidence.color ?? .orange)
                        }
                        if roles?.attribution.profile == profile.name {
                            StatusChip("统计归因", color: .secondary)
                        }
                    }
                    Text(profile.remoteStale == true ? "远端状态为缓存" : "账号状态已更新")
                        .font(.system(size: 9))
                        .foregroundStyle(
                            profile.remoteStale == true
                                ? Color.orange
                                : Color(nsColor: .tertiaryLabelColor)
                        )
                }
                .frame(minWidth: 145, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("主要额度")
                            .font(.system(size: 10, weight: .medium))
                        Spacer()
                        Text(remainingText)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.workbenchBorder.opacity(0.5))
                            Capsule()
                                .fill(quotaColor)
                                .frame(width: proxy.size.width * max(0, min(1, (remainingPercent ?? 0) / 100)))
                        }
                    }
                    .frame(height: 6)
                    Text(resetTimeText)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(minWidth: 170, maxWidth: 260)

                VStack(alignment: .leading, spacing: 3) {
                    Text("重置卡")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(resetCount.map(String.init) ?? "—")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    Text("可用次数")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(width: 64, alignment: .leading)

                Button(action: onSwitch) {
                    if switchingProfile == profile.name {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("切换中")
                        }
                    } else {
                        Text(isDesktopProfile ? "当前账号" : "切换并重启 Codex")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isDesktopProfile || switchingProfile != nil)
                .frame(width: 132)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var remainingText: String {
        guard let remainingPercent else { return "—" }
        return "\(Int(remainingPercent.rounded()))% 可用"
    }

    private var resetTimeText: String {
        guard let date = primary?.resetsAtDate else { return "重置时间未知" }
        return "重置于 \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var quotaColor: Color {
        guard let remainingPercent else { return .secondary }
        if remainingPercent <= 10 { return .red }
        if remainingPercent <= 30 { return .orange }
        return .accentColor
    }
}
