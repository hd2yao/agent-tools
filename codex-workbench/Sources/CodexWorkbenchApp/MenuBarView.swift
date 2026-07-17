import AppKit
import CodexWorkbenchCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: WorkbenchAppModel
    @Environment(\.openWindow) private var openWindow

    private var presentation: AccountMenuPresentation {
        AccountPresentationBuilder.menu(payload: model.accountPayload)
    }

    private var recentEvents: [OperationEvent] {
        Array(model.events.filter { $0.importance != .diagnostic }.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchSpacing.sm) {
            accountHeader

            HStack(spacing: WorkbenchSpacing.xs) {
                MenuMetric(
                    title: presentation.quotaWindowLabel,
                    value: presentation.quotaText,
                    systemImage: "gauge.with.dots.needle.33percent"
                )
                MenuMetric(
                    title: presentation.secondaryQuotaWindowLabel,
                    value: presentation.secondaryQuotaText,
                    systemImage: "calendar"
                )
                MenuMetric(
                    title: "可用重置卡",
                    value: presentation.resetCreditText,
                    systemImage: "arrow.counterclockwise.circle"
                )
            }

            if let banner = model.visualAcceptanceBanner {
                MenuNotice(
                    text: banner,
                    color: .blue,
                    systemImage: "eye.fill"
                )
            }

            if model.isLegacyProfileSwitcherRunning {
                MenuNotice(
                    text: "旧 Profile Switcher 正在运行，提醒和自动重置已暂停",
                    color: .orange,
                    systemImage: "exclamationmark.triangle.fill"
                )
            } else if let error = model.accountError {
                MenuNotice(
                    text: error,
                    color: .orange,
                    systemImage: "exclamationmark.circle.fill"
                )
            }

            profileSwitcher

            HStack(spacing: WorkbenchSpacing.xs) {
                Button {
                    showWorkbench(module: .accounts)
                } label: {
                    Label("账号详情", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showWorkbench(module: .overview)
                } label: {
                    Label("打开工作台", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.regular)

            Divider()

            VStack(alignment: .leading, spacing: WorkbenchSpacing.xs) {
                HStack {
                    Text("最近重要操作")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button("查看全部") { showWorkbench(module: .activity) }
                        .buttonStyle(.plain)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                if recentEvents.isEmpty {
                    Text(model.isRefreshing ? "正在读取本地日志…" : "暂无可显示的操作")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                } else {
                    ForEach(recentEvents) { event in
                        MenuBarEventRow(event: event)
                    }
                }
            }

            Divider()

            HStack(spacing: WorkbenchSpacing.sm) {
                Button("设置…", action: openPreferences)
                Button(model.isCodexRunning ? "切到 Codex" : "打开 Codex", action: CodexIntegrationService.openCodex)
                Spacer()
                Button("刷新") {
                    Task { await model.refreshAll(refreshResetCredits: true) }
                }
                .disabled(model.isRefreshing || model.isVisualAcceptanceMode)
                Button("退出") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(WorkbenchSpacing.md)
        .frame(width: 360)
        .task { model.bootstrap() }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didLaunchApplicationNotification
            )
        ) { notification in
            model.updateRunningApplicationState()
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                application.bundleIdentifier == CodexIntegration.bundleIdentifier,
                WorkbenchPreferences.shouldShowWhenCodexLaunches
            else { return }
            showWorkbench(module: model.selectedModule ?? .overview)
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didTerminateApplicationNotification
            )
        ) { _ in
            model.updateRunningApplicationState()
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter.publisher(
                for: NSWorkspace.didWakeNotification
            )
        ) { _ in
            model.handleSystemWake()
        }
    }

    private var accountHeader: some View {
        HStack(spacing: WorkbenchSpacing.sm) {
            Image(systemName: presentation.runtimeSymbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(runtimeColor)
                .frame(width: 36, height: 36)
                .background(runtimeColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.profileDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("当前登录账号")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: WorkbenchSpacing.sm)
            StatusChip(
                presentation.runtimeLabel,
                color: runtimeColor,
                systemImage: presentation.runtimeSymbol
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var profileSwitcher: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("快速切换账号")
                .font(.system(size: 11, weight: .semibold))

            if let payload = model.accountPayload, !payload.profiles.isEmpty {
                ForEach(payload.profiles) { profile in
                    Button {
                        guard profile.name != model.currentProfileName else { return }
                        model.switchProfile(profile.name)
                    } label: {
                        HStack(spacing: WorkbenchSpacing.xs) {
                            Text(AccountPresentationBuilder.profileDisplayName(profile.name))
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(profile.rateLimits.primary?.remainingPercent.map {
                                "\(Int($0.rounded()))%"
                            } ?? "--")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            profileState(profile)
                        }
                        .padding(.horizontal, WorkbenchSpacing.xs)
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        profile.name == model.currentProfileName
                            ? Color.workbenchSelection
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .disabled(
                        model.isVisualAcceptanceMode
                            || model.switchingProfile != nil
                            || profile.name == model.currentProfileName
                    )
                    .accessibilityLabel(profileAccessibilityLabel(profile))
                }
            } else {
                Text(model.isRefreshing ? "正在读取账号…" : "账号状态不可用")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func profileState(_ profile: AccountProfile) -> some View {
        if profile.name == model.currentProfileName {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
        } else if model.switchingProfile == profile.name {
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text(switchStageText)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
    }

    private var switchStageText: String {
        switch model.accountSwitchStage {
        case .switching: "切换中"
        case .verifying: "验证中"
        case nil: ""
        }
    }

    private func profileAccessibilityLabel(_ profile: AccountProfile) -> String {
        let state = profile.name == model.currentProfileName ? "当前登录账号" : "可切换"
        let quota = profile.rateLimits.primary?.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "未知"
        let window = AccountPresentationBuilder.quotaWindowName(
            minutes: profile.rateLimits.primary?.windowMinutes
        ) ?? "主要"
        return "\(AccountPresentationBuilder.profileDisplayName(profile.name))，\(state)，\(window)剩余额度 \(quota)"
    }

    private func showWorkbench(module: AppModule) {
        model.selectedModule = module
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first { $0.title == "Codex 观测站" }?.makeKeyAndOrderFront(nil)
        }
    }

    private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var runtimeColor: Color {
        switch model.runtimePresentation.state {
        case "running": .green
        case "waiting": .orange
        default: .secondary
        }
    }
}

private struct MenuMetric: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .padding(WorkbenchSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color.workbenchCard, in: RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.workbenchBorder.opacity(0.65), lineWidth: 0.5)
        )
    }
}

private struct MenuNotice: View {
    let text: String
    let color: Color
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, WorkbenchSpacing.xs)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
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
        .padding(.vertical, 2)
    }
}
