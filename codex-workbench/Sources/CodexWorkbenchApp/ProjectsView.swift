import CodexWorkbenchCore
import SwiftUI

struct ProjectsView: View {
    @ObservedObject var model: WorkbenchAppModel

    private var insights: WorkspaceInsightsPresentation {
        AccountPresentationBuilder.workspaceInsights(payload: model.accountPayload)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.lg) {
                PageHeader(
                    eyebrow: "Projects",
                    title: "项目与任务",
                    description: "按真实工作区查看项目统计、最近任务、上下文摘要与接续关系。",
                    trailing: AnyView(
                        Button("刷新") { Task { await model.refreshAll() } }
                            .disabled(model.isRefreshing)
                    )
                )

                if let error = model.accountError {
                    InsightsNotice(message: error)
                }

                if insights.projectsAvailable {
                    projectContent
                } else if model.isRefreshing && model.accountPayload == nil {
                    InsightsLoadingState(message: "正在读取项目历史…")
                } else {
                    InsightsUnavailableState(
                        systemImage: "externaldrive.badge.questionmark",
                        title: "项目数据源不可用",
                        message: "工作台尚未从本地 Codex 历史库读取到项目排行；这不代表项目数量为 0。"
                    )
                }

                recentTasksContent
            }
            .padding(.horizontal, WorkbenchSpacing.lg)
            .padding(.vertical, WorkbenchSpacing.lg)
            .frame(maxWidth: 1_180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("projects-page")
    }

    @ViewBuilder
    private var recentTasksContent: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
            SectionTitle(
                "最近任务",
                detail: "\(model.workspaceCatalog.recentThreads.count) 个任务 · \(model.workspaceCatalog.contextSummaryCount) 个有摘要"
            )
            if model.workspaceCatalog.projects.isEmpty {
                SurfaceCard {
                    QuietEmptyState(
                        systemImage: "bubble.left.and.bubble.right",
                        title: "还没有任务目录",
                        message: "当前 metadata 目录中没有可展示的真实任务；不会用操作日志推断任务数量。"
                    )
                    .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(model.workspaceCatalog.projects.prefix(8), id: \.path) { project in
                    SurfaceCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(project.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text("\(project.threads.count) 个任务")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, WorkbenchSpacing.md)
                            .padding(.vertical, WorkbenchSpacing.sm)
                            Divider()
                            ForEach(Array(project.threads.prefix(6).enumerated()), id: \.element.id) { index, thread in
                                WorkspaceThreadRow(thread: thread) {
                                    CodexIntegrationService.openThread(thread.id)
                                }
                                if index < min(project.threads.count, 6) - 1 {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var projectContent: some View {
        if insights.projects.isEmpty {
            SurfaceCard {
                QuietEmptyState(
                    systemImage: "folder",
                    title: "还没有项目活动",
                    message: "数据源可用，但本地历史中暂时没有带工作目录的任务。"
                )
                .frame(maxWidth: .infinity)
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: WorkbenchSpacing.sm)],
                spacing: WorkbenchSpacing.sm
            ) {
                InsightSummaryTile(
                    title: "项目",
                    value: "\(insights.projects.count)",
                    detail: "有本地活动记录",
                    systemImage: "folder"
                )
                InsightSummaryTile(
                    title: "对话",
                    value: "\(insights.projects.reduce(0) { $0 + $1.threadCount })",
                    detail: "跨项目累计",
                    systemImage: "bubble.left.and.bubble.right"
                )
                InsightSummaryTile(
                    title: "Tokens",
                    value: compact(insights.projects.reduce(0) { $0 + $1.tokensUsed }),
                    detail: "本地任务历史累计",
                    systemImage: "number"
                )
            }

            VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
                SectionTitle("项目排行", detail: "按 Tokens 从高到低")
                SurfaceCard(padding: 0) {
                    ForEach(Array(insights.projects.enumerated()), id: \.element.path) { index, project in
                        ProjectRankingRow(rank: index + 1, project: project)
                        if index < insights.projects.count - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        }
    }

    private func compact(_ value: Int) -> String {
        let number = Double(value)
        if abs(number) >= 1_000_000_000 { return String(format: "%.1fB", number / 1_000_000_000) }
        if abs(number) >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
        if abs(number) >= 1_000 { return String(format: "%.1fK", number / 1_000) }
        return "\(value)"
    }
}

private struct WorkspaceThreadRow: View {
    let thread: WorkspaceThreadPresentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                Image(systemName: thread.sourceThreadID == nil ? "bubble.left" : "arrow.triangle.branch")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: WorkbenchSpacing.xs) {
                        Text(thread.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if thread.hasContextSummary {
                            StatusChip("有摘要", color: .indigo, systemImage: "doc.text.fill")
                        }
                    }
                    if let sourceTitle = thread.sourceThreadTitle {
                        Text("接续自：\(sourceTitle)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let topic = thread.contextTopic {
                        Text(topic)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: WorkbenchSpacing.sm)
                Text(thread.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, WorkbenchSpacing.md)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            thread.sourceThreadTitle.map { "\(thread.title)，接续自 \($0)" }
                ?? thread.title
        )
        .accessibilityHint("在 Codex 中打开这个任务")
    }
}

private struct ProjectRankingRow: View {
    let rank: Int
    let project: AccountProjectRankingItem

    var body: some View {
        HStack(spacing: WorkbenchSpacing.sm) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Image(systemName: "folder.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(project.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: WorkbenchSpacing.lg) {
                ProjectValue(title: "对话", value: "\(project.threadCount)")
                ProjectValue(title: "Tokens", value: compact(project.tokensUsed))
                ProjectValue(title: "最近活动", value: updatedText)
                    .frame(width: 120, alignment: .leading)
            }
        }
        .padding(.horizontal, WorkbenchSpacing.md)
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var updatedText: String {
        guard project.latestUpdatedAt > 0 else { return "--" }
        let raw = Double(project.latestUpdatedAt)
        let seconds = raw > 10_000_000_000 ? raw / 1_000 : raw
        return Date(timeIntervalSince1970: seconds).formatted(date: .numeric, time: .omitted)
    }

    private func compact(_ value: Int) -> String {
        let number = Double(value)
        if abs(number) >= 1_000_000 { return String(format: "%.1fM", number / 1_000_000) }
        if abs(number) >= 1_000 { return String(format: "%.1fK", number / 1_000) }
        return "\(value)"
    }
}

private struct ProjectValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
        }
        .frame(width: 64, alignment: .leading)
    }
}

struct InsightSummaryTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
    }
}

struct InsightsLoadingState: View {
    let message: String

    var body: some View {
        SurfaceCard {
            HStack(spacing: WorkbenchSpacing.sm) {
                ProgressView().controlSize(.small)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
        }
    }
}

struct InsightsUnavailableState: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        SurfaceCard {
            QuietEmptyState(systemImage: systemImage, title: title, message: message)
                .frame(maxWidth: .infinity)
        }
    }
}

struct InsightsNotice: View {
    let message: String

    var body: some View {
        SurfaceCard {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
