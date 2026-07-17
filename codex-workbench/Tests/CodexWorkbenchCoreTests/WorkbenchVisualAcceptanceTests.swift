import CodexWorkbenchCore
import Foundation

func runWorkbenchVisualAcceptanceTests(_ runner: inout TestRunner) {
    let disabled = WorkbenchVisualAcceptanceConfiguration.parse(environment: [:])
    runner.expect(disabled.fixture == nil, "Visual fixture must be disabled by default")
    runner.expect(disabled.appearance == nil, "Visual appearance must follow the system by default")

    let configured = WorkbenchVisualAcceptanceConfiguration.parse(environment: [
        "CODEX_WORKBENCH_VISUAL_FIXTURE": "switching",
        "CODEX_WORKBENCH_VISUAL_APPEARANCE": "dark",
        "CODEX_WORKBENCH_VISUAL_SURFACE": "menu",
    ])
    runner.expect(configured.fixture == .switching, "Known fixture names should be parsed")
    runner.expect(configured.appearance == .dark, "Known appearance names should be parsed")
    runner.expect(configured.surface == .menu, "Known visual surfaces should be parsed")
    runner.expect(!configured.liveOperationsAllowed, "Fixture mode must block live account operations")
    runner.expect(
        !WorkbenchStartupPolicy.shouldMigrateLoginItem(configuration: configured),
        "Fixture mode must not register, unregister, or migrate login items"
    )
    runner.expect(
        configured.windowSceneID == "visual-acceptance",
        "Fixture windows must not reuse the production window autosave identity"
    )

    let appearanceOnly = WorkbenchVisualAcceptanceConfiguration.parse(environment: [
        "CODEX_WORKBENCH_VISUAL_APPEARANCE": "dark",
    ])
    runner.expect(
        appearanceOnly.liveOperationsAllowed,
        "Process-only appearance overrides must preserve normal workbench behavior"
    )
    runner.expect(
        WorkbenchVisualAcceptanceConfiguration.parse(environment: [
            "CODEX_WORKBENCH_VISUAL_SURFACE": "menu",
        ]).surface == nil,
        "Visual preview surfaces must require a fixture"
    )
    runner.expect(disabled.liveOperationsAllowed, "Normal launches must preserve live operations")
    runner.expect(
        WorkbenchStartupPolicy.shouldMigrateLoginItem(configuration: disabled),
        "Normal launches should retain the one-time login-item migration"
    )
    runner.expect(disabled.windowSceneID == "main", "Normal launches must retain the production window identity")

    let ignored = WorkbenchVisualAcceptanceConfiguration.parse(environment: [
        "CODEX_WORKBENCH_VISUAL_FIXTURE": "production",
        "CODEX_WORKBENCH_VISUAL_APPEARANCE": "sepia",
        "CODEX_WORKBENCH_VISUAL_SURFACE": "settings",
    ])
    runner.expect(ignored.fixture == nil, "Unknown fixtures must not change production behavior")
    runner.expect(ignored.appearance == nil, "Unknown appearances must not change production behavior")
    runner.expect(ignored.surface == nil, "Unknown visual surfaces must not change production behavior")

    let stale = WorkbenchVisualAcceptanceSnapshot.make(for: .stale)
    runner.expect(stale.payload?.activeProfile == "hd-sarah-blackwell", "Stale fixture should retain a current account")
    runner.expect(
        stale.errorMessage == "账号状态刷新失败。正在展示 10 分钟前成功读取的暂存数据。",
        "Stale fixture should reuse the production cache-age wording"
    )
    runner.expect(stale.switchingProfile == nil, "Stale fixture must not pretend a switch is running")
    runner.expect(stale.blocksLiveOperations, "Fixture states must block real account operations")

    let error = WorkbenchVisualAcceptanceSnapshot.make(for: .error)
    runner.expect(error.payload == nil, "Error fixture should cover the unavailable account state")
    runner.expect(error.errorMessage?.contains("无法读取") == true, "Error fixture should expose a safe user-facing reason")

    let switching = WorkbenchVisualAcceptanceSnapshot.make(for: .switching)
    runner.expect(switching.payload?.activeProfile == "hd-sarah-blackwell", "Switching fixture should preserve the source account")
    runner.expect(switching.switchingProfile == "hd-master", "Switching fixture should target the other account")
    runner.expect(
        switching.banner == "视觉验收模式 · 不执行真实账号操作",
        "Fixture screenshots must visibly disclose synthetic state"
    )
    runner.expect(
        switching.payload?.profiles.contains(where: { $0.name == "hd-master" }) == true,
        "Fixture should cover the alternate account row"
    )
}
