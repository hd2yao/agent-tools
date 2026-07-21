import CodexWorkbenchCore
import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: WorkbenchAppModel

    private var recentEvents: [OperationEvent] {
        Array(model.events.filter {
            $0.importance == .critical || $0.importance == .important
        }.prefix(7))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                PageHeader(
                    eyebrow: "Overview",
                    title: "运行概览",
                    description: "把跨任务的关键操作、账号与上下文状态放在一个可信的视图里。",
                    trailing: AnyView(lastUpdatedView)
                )

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 205, maximum: 280), spacing: WorkbenchSpacing.sm)],
                    alignment: .leading,
                    spacing: WorkbenchSpacing.sm
                ) {
                    SummaryTile(
                        title: "Codex",
                        value: model.runtimePresentation.label,
                        detail: model.runtimePresentation.detail,
                        systemImage: model.runtimePresentation.symbol,
                        color: runtimeColor
                    )
                    SummaryTile(
                        title: "当前登录账号",
                        value: AccountPresentationBuilder.profileDisplayName(model.desktopProfileName),
                        detail: desktopAccountDetail,
                        systemImage: "person.crop.circle",
                        color: .teal
                    )
                    SummaryTile(
                        title: "今日事件",
                        value: String(model.todayEventCount),
                        detail: "最新操作始终在最上方",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        color: .blue
                    )
                    SummaryTile(
                        title: "需关注",
                        value: String(model.attentionCount),
                        detail: "额度 / 账号 / 失败 / 推断",
                        systemImage: "exclamationmark.circle",
                        color: model.attentionCount > 0 ? .orange : .secondary
                    )
                }

                SurfaceCard(padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionTitle("最近活动", detail: "跨全部 Codex 任务")
                            .padding(.horizontal, WorkbenchSpacing.md)
                            .padding(.vertical, WorkbenchSpacing.sm)
                        Divider()
                        if recentEvents.isEmpty {
                            QuietEmptyState(
                                systemImage: "clock.badge.questionmark",
                                title: "还没有操作事件",
                                message: "刷新后会从 context card、任务台账和账号状态中补录可证实的事件。"
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                                CompactEventRow(event: event) {
                                    model.selectedEventID = event.id
                                    model.selectedModule = .activity
                                }
                                if index < recentEvents.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                            SectionTitle("证据覆盖")
                            EvidenceFactLine(
                                title: "任务目录",
                                detail: "\(model.workspaceCatalog.recentThreads.count) 个真实任务"
                            )
                            EvidenceFactLine(
                                title: "上下文摘要",
                                detail: "\(model.workspaceCatalog.contextSummaryCount) 个任务有摘要"
                            )
                            EvidenceFactLine(
                                title: "工作流文件",
                                detail: "\(model.workspaceCatalog.workflows.hooks.count) 个 Hook · \(model.workspaceCatalog.workflows.automations.count) 个自动化"
                            )
                            if model.ledgerWarnings.isEmpty {
                                Label("本轮没有证据读取警告", systemImage: "checkmark.circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(model.ledgerWarnings.prefix(3).enumerated()), id: \.offset) { _, warning in
                                    Label(warning, systemImage: "exclamationmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.orange)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                            SectionTitle("工作原则")
                            Label("事实、推断、无法证实分开展示", systemImage: "checkmark.seal")
                            Label("只记录关键操作，不保存认证内容", systemImage: "lock.shield")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, WorkbenchSpacing.lg)
            .padding(.vertical, WorkbenchSpacing.lg)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("overview-page")
    }

    private var lastUpdatedView: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text("最后更新")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(model.lastUpdated?.formatted(date: .omitted, time: .shortened) ?? "正在读取")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var desktopAccountDetail: String {
        guard let status = model.accountPayload?.desktopStatus else {
            return model.accountError ?? "等待账号模块"
        }
        return status.managed ? "当前登录状态已接管" : "当前登录状态未接管"
    }

    private var runtimeColor: Color {
        switch model.runtimePresentation.state {
        case "running": .green
        case "waiting": .orange
        case "idle": .secondary
        default: .secondary
        }
    }
}

private struct SummaryTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let color: Color

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                HStack {
                    Label(title, systemImage: systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Circle().fill(color).frame(width: 7, height: 7)
                }
                Text(value)
                    .font(.system(size: 22, weight: .semibold, design: value.allSatisfy(\.isNumber) ? .monospaced : .default))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        }
    }
}

struct CompactEventRow: View {
    let event: OperationEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchSpacing.sm) {
                Image(systemName: event.category.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(event.category.color)
                    .frame(width: 30, height: 30)
                    .background(event.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(event.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: WorkbenchSpacing.md)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(event.occurredAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(event.actor.label)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, WorkbenchSpacing.md)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.title)，\(event.status.displayName)，\(event.actor.label)")
    }
}

private struct EvidenceFactLine: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}
