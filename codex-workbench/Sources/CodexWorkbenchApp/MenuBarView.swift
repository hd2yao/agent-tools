import AppKit
import CodexWorkbenchCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: WorkbenchAppModel
    @Environment(\.openWindow) private var openWindow

    private var recentEvents: [OperationEvent] {
        Array(model.events.filter { $0.importance != .diagnostic }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.md) {
            HStack(spacing: WorkbenchSpacing.sm) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex 工具台")
                        .font(.system(size: 14, weight: .semibold))
                    Text(model.isCodexRunning ? "Codex 正在运行" : "Codex 当前未运行")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(model.isCodexRunning ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
            }

            VStack(spacing: WorkbenchSpacing.xs) {
                Button(action: showWorkbench) {
                    Label("打开工具台", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: CodexIntegrationService.openCodex) {
                    Label(model.isCodexRunning ? "切到 Codex" : "打开 Codex", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Divider()

            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                HStack {
                    Text("最近重要操作")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(model.events.count) 条")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if recentEvents.isEmpty {
                    Text(model.isRefreshing ? "正在读取本地日志…" : "暂无可显示的操作")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    ForEach(recentEvents) { event in
                        MenuBarEventRow(event: event)
                    }
                }
            }

            Divider()

            HStack {
                Button("设置…", action: openPreferences)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("刷新") {
                    Task { await model.refreshAll() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(model.isRefreshing)
            }
            .font(.system(size: 10))
        }
        .padding(WorkbenchSpacing.md)
        .frame(width: 350)
        .task { model.bootstrap() }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification
            )
        ) { notification in
            model.updateCodexRunningState()
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                application.bundleIdentifier == CodexIntegration.bundleIdentifier,
                WorkbenchPreferences.shouldShowWhenCodexLaunches
            else { return }
            showWorkbench()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification
            )
        ) { _ in
            model.updateCodexRunningState()
        }
    }

    private func showWorkbench() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "Codex 工具台" }?.makeKeyAndOrderFront(nil)
        }
    }

    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MenuBarEventRow: View {
    let event: OperationEvent

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchSpacing.xs) {
            Image(systemName: event.category.systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(event.category.color)
                .frame(width: 22, height: 22)
                .background(event.category.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: WorkbenchSpacing.xs)
            Text(event.actor.label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}
