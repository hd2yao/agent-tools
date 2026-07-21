import CodexWorkbenchCore
import SwiftUI

struct ToolsSkillsView: View {
    @ObservedObject var model: WorkbenchAppModel

    private var insights: WorkspaceInsightsPresentation {
        AccountPresentationBuilder.workspaceInsights(payload: model.accountPayload)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                PageHeader(
                    eyebrow: "Tools & Skills",
                    title: "工具与自动化",
                    description: "查看动态工具、Skill、Hook 与自动化的真实本地证据。",
                    trailing: AnyView(
                        Button("刷新") { Task { await model.refreshAll() } }
                            .disabled(model.isRefreshing)
                    )
                )

                if let error = model.accountError {
                    InsightsNotice(message: error)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: WorkbenchSpacing.sm)],
                    alignment: .leading,
                    spacing: WorkbenchSpacing.sm
                ) {
                    rankingPanel(
                        title: "动态工具",
                        detail: insights.toolsAvailable ? "\(insights.tools.count) 项" : "数据源不可用",
                        available: insights.toolsAvailable,
                        isEmpty: insights.tools.isEmpty,
                        emptyMessage: "还没有动态工具调用记录"
                    ) {
                        ForEach(Array(insights.tools.enumerated()), id: \.element.id) { index, tool in
                            ToolRankingRow(rank: index + 1, tool: tool)
                            if index < insights.tools.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }

                    rankingPanel(
                        title: "Skills",
                        detail: skillDetail,
                        available: insights.skillsAvailable,
                        isEmpty: insights.skills.isEmpty,
                        emptyMessage: "还没有 Skill 使用记录"
                    ) {
                        ForEach(Array(insights.skills.enumerated()), id: \.element.name) { index, skill in
                            SkillRankingRow(rank: index + 1, skill: skill)
                            if index < insights.skills.count - 1 { Divider().padding(.leading, 44) }
                        }
                    }
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: WorkbenchSpacing.sm)],
                    alignment: .leading,
                    spacing: WorkbenchSpacing.sm
                ) {
                    workflowPanel(
                        title: "Hooks",
                        detail: "\(model.workspaceCatalog.workflows.hooks.count) 项",
                        items: model.workspaceCatalog.workflows.hooks,
                        emptyMessage: "没有从工作流文件中识别到 Hook"
                    )
                    workflowPanel(
                        title: "自动化",
                        detail: "\(model.workspaceCatalog.workflows.automations.count) 项",
                        items: model.workspaceCatalog.workflows.automations,
                        emptyMessage: "没有从工作流文件中识别到自动化"
                    )
                }

                SurfaceCard {
                    HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("统计口径")
                                .font(.system(size: 11, weight: .semibold))
                            Text("工具排行来自本地任务数据库中的动态工具关联；Skill 排行来自本地任务记录中的 SKILL.md 读取证据。没有数据时不会显示为 0 次成功。")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, WorkbenchSpacing.lg)
            .padding(.vertical, WorkbenchSpacing.lg)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("tools-skills-page")
    }

    private func workflowPanel(
        title: String,
        detail: String,
        items: [WorkflowItemPresentation],
        emptyMessage: String
    ) -> some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(title, detail: detail)
                    .padding(.horizontal, WorkbenchSpacing.md)
                    .padding(.vertical, WorkbenchSpacing.sm)
                Divider()
                if items.isEmpty {
                    Text(emptyMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 84)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        WorkflowItemRow(item: item)
                        if index < items.count - 1 { Divider().padding(.leading, 44) }
                    }
                }
            }
        }
    }

    private var skillDetail: String {
        guard insights.skillsAvailable else { return "数据源不可用" }
        let badLines = model.accountPayload?.skillRankings?.badLineCount ?? 0
        return badLines > 0 ? "\(insights.skills.count) 项 · \(badLines) 条记录无法解析" : "\(insights.skills.count) 项"
    }

    @ViewBuilder
    private func rankingPanel<Content: View>(
        title: String,
        detail: String,
        available: Bool,
        isEmpty: Bool,
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                SectionTitle(title, detail: detail)
                    .padding(.horizontal, WorkbenchSpacing.md)
                    .padding(.vertical, WorkbenchSpacing.sm)
                Divider()
                if !available {
                    QuietEmptyState(
                        systemImage: "externaldrive.badge.questionmark",
                        title: "数据源不可用",
                        message: "本地 Codex 历史暂未提供该排行。"
                    )
                    .frame(maxWidth: .infinity, minHeight: 116)
                } else if isEmpty {
                    Text(emptyMessage)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 84)
                } else {
                    content()
                }
            }
        }
    }
}

private struct WorkflowItemRow: View {
    let item: WorkflowItemPresentation

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchSpacing.xs) {
            Image(systemName: "bolt.horizontal.circle")
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.purpose ?? "未声明用途")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: WorkbenchSpacing.sm)
            RankedValue(title: "状态", value: item.status ?? "未声明")
            RankedValue(title: "计划", value: item.schedule ?? "未声明")
        }
        .padding(.horizontal, WorkbenchSpacing.md)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

private struct ToolRankingRow: View {
    let rank: Int
    let tool: AccountToolRankingItem

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            RankLabel(rank: rank)
            VStack(alignment: .leading, spacing: 3) {
                Text(tool.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(tool.namespace.isEmpty ? "本地工具" : tool.namespace)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: WorkbenchSpacing.sm)
            RankedValue(title: "调用", value: "\(tool.callCount)")
            RankedValue(title: "相关 Tokens", value: compact(tool.threadTokens))
        }
        .padding(.horizontal, WorkbenchSpacing.md)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }
}

private struct SkillRankingRow: View {
    let rank: Int
    let skill: AccountSkillRankingItem

    var body: some View {
        HStack(spacing: WorkbenchSpacing.xs) {
            RankLabel(rank: rank)
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(skill.latestTimestamp ?? "最近时间未知")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: WorkbenchSpacing.sm)
            RankedValue(title: "使用", value: "\(skill.useCount)")
        }
        .padding(.horizontal, WorkbenchSpacing.md)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

private struct RankLabel: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(Color.workbenchWindow.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct RankedValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .frame(width: 68, alignment: .trailing)
    }
}
