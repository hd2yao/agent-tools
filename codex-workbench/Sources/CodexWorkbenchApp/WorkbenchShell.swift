import CodexWorkbenchCore
import SwiftUI

struct WorkbenchShell: View {
    @ObservedObject var model: WorkbenchAppModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: WorkbenchLayout.sidebarMinimum,
                    ideal: WorkbenchLayout.sidebarIdeal,
                    max: WorkbenchLayout.sidebarMaximum
                )
        } detail: {
            detail
                .background(Color.workbenchWindow)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                StatusChip(
                    model.isCodexRunning ? "Codex 运行中" : "Codex 未运行",
                    color: model.isCodexRunning ? .green : .secondary
                )
                .accessibilityLabel(model.isCodexRunning ? "Codex 正在运行" : "Codex 未运行")

                Button {
                    Task { await model.refreshAll(refreshResetCredits: model.selectedModule == .accounts) }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing)
                .help("刷新操作日志与账号状态")
            }
        }
    }

    private var sidebar: some View {
        List(selection: $model.selectedModule) {
            Section {
                ForEach(AppModule.allCases, id: \.self) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            } header: {
                Text("工作台")
            }

            Section {
                Label("任务与线程", systemImage: "point.3.filled.connected.trianglepath.dotted")
                Label("Hook 与自动化", systemImage: "bolt.horizontal.circle")
                Label("上下文健康", systemImage: "waveform.path.ecg")
            } header: {
                Text("即将推出")
            }
            .foregroundStyle(.tertiary)

            Section {
                HStack(spacing: WorkbenchSpacing.xs) {
                    Circle()
                        .fill(model.ledgerWarnings.isEmpty ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.ledgerWarnings.isEmpty ? "数据源正常" : "数据源已降级")
                            .font(.system(size: 11, weight: .medium))
                        Text("\(model.events.count) 条跨任务事件")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: WorkbenchSpacing.sm) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Codex 工具台")
                        .font(.system(size: 13, weight: .semibold))
                    Text("本地运行控制台")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, WorkbenchSpacing.sm)
            .padding(.vertical, WorkbenchSpacing.md)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedModule ?? .overview {
        case .overview:
            OverviewView(model: model)
        case .activity:
            ActivityView(model: model)
        case .accounts:
            AccountsView(model: model)
        }
    }
}
