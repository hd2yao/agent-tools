import CodexWorkbenchCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: WorkbenchAppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: WorkbenchSpacing.md) {
                VStack(alignment: .leading, spacing: WorkbenchSpacing.xxs) {
                    Text("诊断与修复")
                        .font(.system(size: 20, weight: .semibold))
                    Text("检查 Codex 安装、账号来源与内置后端；复制内容已自动脱敏。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await model.refreshAll(refreshResetCredits: true)
                        model.refreshDiagnostics()
                    }
                } label: {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small)
                        Text("正在刷新")
                    } else {
                        Label("刷新诊断", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing || model.isVisualAcceptanceMode)
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(WorkbenchSpacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: WorkbenchSpacing.md) {
                    ForEach(model.diagnosticSnapshot.findings, id: \.id) { finding in
                        diagnosticFinding(finding)
                    }

                    if !model.diagnosticSnapshot.appSummaries.isEmpty {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                                SectionTitle("已发现的 Codex App")
                                ForEach(model.diagnosticSnapshot.appSummaries, id: \.self) { summary in
                                    Text(summary)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
                .padding(WorkbenchSpacing.lg)
            }

            Divider()

            HStack(spacing: WorkbenchSpacing.sm) {
                Button(action: CodexIntegrationService.openCodex) {
                    Label(model.isCodexRunning ? "切到 Codex" : "打开 Codex", systemImage: "terminal")
                }

                Button {
                    model.requestRestartCurrentCodex()
                } label: {
                    if model.accountRestartStage != nil {
                        ProgressView().controlSize(.small)
                        Text("正在重启")
                    } else {
                        Label("安全重启", systemImage: "arrow.clockwise.circle")
                    }
                }
                .disabled(
                    model.currentProfileName == nil
                        || model.accountRestartStage != nil
                        || model.accountSwitchStage != nil
                        || model.isVisualAcceptanceMode
                )

                if model.diagnosticSnapshot.revealTargets.count == 1,
                   let target = model.diagnosticSnapshot.revealTargets.first {
                    Button {
                        CodexIntegrationService.revealDiagnosticTarget(target)
                    } label: {
                        Label("Finder 显示", systemImage: "folder")
                    }
                } else {
                    Menu {
                        ForEach(
                            Array(model.diagnosticSnapshot.revealTargets.enumerated()),
                            id: \.offset
                        ) { _, target in
                            Button(target.label) {
                                CodexIntegrationService.revealDiagnosticTarget(target)
                            }
                        }
                    } label: {
                        Label("Finder 显示", systemImage: "folder")
                    }
                    .disabled(model.diagnosticSnapshot.revealTargets.isEmpty)
                }

                Spacer()

                Button {
                    CodexIntegrationService.copyDiagnosticSummary(model.diagnosticSnapshot)
                } label: {
                    Label("复制脱敏摘要", systemImage: "doc.on.doc")
                }
                .accessibilityHint("复制不含完整路径和认证内容的诊断摘要")
            }
            .padding(WorkbenchSpacing.md)
        }
        .frame(minWidth: 640, idealWidth: 680, minHeight: 500, idealHeight: 560)
        .background(Color.workbenchWindow)
        .alert("确认重启 Codex", isPresented: restartConfirmationBinding) {
            Button("取消", role: .cancel) {
                model.cancelRestartCurrentCodex()
            }
            Button("仍然重启", role: .destructive) {
                model.confirmRestartCurrentCodex()
            }
        } message: {
            Text(restartConfirmationMessage)
        }
        .accessibilityIdentifier("diagnostics-sheet")
    }

    private func diagnosticFinding(_ finding: DiagnosticFinding) -> some View {
        SurfaceCard {
            HStack(alignment: .top, spacing: WorkbenchSpacing.sm) {
                Image(systemName: findingSymbol(finding.level))
                    .foregroundStyle(findingColor(finding.level))
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: WorkbenchSpacing.xxs) {
                    Text(finding.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(finding.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: WorkbenchSpacing.sm)
                StatusChip(finding.level.displayName, color: findingColor(finding.level))
            }
        }
    }

    private var restartConfirmationBinding: Binding<Bool> {
        Binding(
            get: { model.accountRestartConfirmation != nil },
            set: { isPresented in
                if !isPresented, model.accountRestartConfirmation != nil {
                    model.cancelRestartCurrentCodex()
                }
            }
        )
    }

    private var restartConfirmationMessage: String {
        switch model.accountRestartConfirmation {
        case .runningTask:
            "检测到 Codex 正在运行任务。重启会中断当前任务，确认仍要继续吗？"
        case .waitingTask:
            "检测到待接手任务。重启可能中断尚未完成的状态，确认仍要继续吗？"
        case .unknownState:
            "当前运行状态无法可靠确认。为避免误中断，只有明确确认后才会重启。"
        case nil:
            ""
        }
    }

    private func findingColor(_ level: DiagnosticLevel) -> Color {
        switch level {
        case .info: .blue
        case .warning: .orange
        case .error: .red
        }
    }

    private func findingSymbol(_ level: DiagnosticLevel) -> String {
        switch level {
        case .info: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

private extension DiagnosticLevel {
    var displayName: String {
        switch self {
        case .info: "正常"
        case .warning: "注意"
        case .error: "异常"
        }
    }
}
