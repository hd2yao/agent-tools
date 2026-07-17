import CodexWorkbenchCore
import Foundation

func runAccountPresentationTests(_ runner: inout TestRunner) {
    let payloadJSON = #"""
    {
      "generated_at":"2026-07-17T08:00:00Z",
      "active_profile":"hd-master",
      "runtime_status":{"state":"running","light":"green","label":"运行中","active_process_count":1,"recent_process_count":1,"latest_activity_age_ms":1200},
      "desktop_status":{"running":true,"managed":true,"state":"managed_default_home","message":"ok","active_profile":"hd-master"},
      "profile_roles":{"task":{"profile":"hd-sarah-blackwell","source":"recent_active_thread_rate_limit_match","confidence":"inferred"},"desktop":{"profile":"hd-master","source":"desktop_bridge_record","confidence":"confirmed"},"attribution":{"profile":"hd-sarah-blackwell","source":"attribution_ledger","confidence":"confirmed"},"task_matches_desktop":false},
      "profiles":[
        {"name":"hd-master","auth":"present","config":"present","rate_limits":{"primary":{"remaining_percent":87,"window_minutes":300},"secondary":{"remaining_percent":62,"window_minutes":10080}}},
        {"name":"hd-sarah-blackwell","auth":"present","config":"present","rate_limits":{"primary":{"remaining_percent":100,"window_minutes":300}}}
      ]
    }
    """#
    let payload = try? AccountDashboardPayload.decode(data: Data(payloadJSON.utf8))
    let presentation = AccountPresentationBuilder.menu(payload: payload)

    runner.expect(presentation.profile == "hd-master", "Menu bar must use the actual active profile")
    runner.expect(presentation.profileDisplayName == "master", "Menu bar should use the compact profile name")
    runner.expect(presentation.quotaText == "87%", "Menu bar should show the active profile primary quota")
    runner.expect(presentation.secondaryQuotaText == "62%", "Popover should show the active profile weekly quota")
    runner.expect(presentation.secondaryQuotaWindowLabel == "7日剩余", "Weekly quota should keep its window label")
    runner.expect(presentation.resetCreditText == "--", "Missing reset credit data must stay unknown")
    runner.expect(presentation.runtimeLabel == "运行中", "Menu bar should show the shared runtime state")
    runner.expect(presentation.runtimeSymbol == "bolt.circle.fill", "Running state should have a non-color symbol")
    runner.expect(
        presentation.accessibilityLabel == "当前登录账号 hd-master，5小时剩余 87%，Codex 运行中",
        "Menu status should expose account, quota window, value, and runtime"
    )

    let unknown = AccountPresentationBuilder.menu(payload: nil)
    runner.expect(unknown.quotaText == "--", "Unknown quota must not be shown as zero")
    runner.expect(unknown.runtimeLabel == "未知", "Missing runtime must stay unknown")

    let inconsistentJSON = #"""
    {
      "generated_at":"2026-07-17T08:00:00Z",
      "active_profile":"hd-master",
      "desktop_status":{"running":true,"managed":true,"state":"managed_default_home","active_profile":"hd-sarah-blackwell"},
      "profiles":[
        {"name":"hd-master","auth":"present","config":"present","rate_limits":{"primary":{"remaining_percent":87,"window_minutes":300}}},
        {"name":"hd-sarah-blackwell","auth":"present","config":"present","rate_limits":{"primary":{"remaining_percent":42,"window_minutes":300}}}
      ]
    }
    """#
    let inconsistentPayload = try? AccountDashboardPayload.decode(data: Data(inconsistentJSON.utf8))
    let inconsistent = AccountPresentationBuilder.menu(payload: inconsistentPayload)
    runner.expect(inconsistent.profile == nil, "Mismatched auth and desktop records must not invent a current account")
    runner.expect(inconsistent.quotaText == "--", "Mismatched account state must not show either account's quota as current")

    let unmanagedJSON = #"""
    {
      "generated_at":"2026-07-17T08:00:00Z",
      "active_profile":"hd-master",
      "desktop_status":{"running":true,"managed":false,"state":"manual_or_unknown","active_profile":"hd-master"},
      "profiles":[{"name":"hd-master","auth":"present","config":"present","rate_limits":{"primary":{"remaining_percent":87,"window_minutes":300}}}]
    }
    """#
    let unmanagedPayload = try? AccountDashboardPayload.decode(data: Data(unmanagedJSON.utf8))
    runner.expect(
        AccountPresentationBuilder.menu(payload: unmanagedPayload).profile == nil,
        "An unmanaged desktop session must remain unknown even when its stale record matches"
    )

    let running = AccountPresentationBuilder.runtime(
        status: AccountRuntimeStatus(
            state: "running",
            light: "red",
            label: "空闲",
            activeProcessCount: 2,
            recentProcessCount: 2
        )
    )
    runner.expect(running.label == "运行中", "Runtime state should be the canonical status source")
    runner.expect(running.symbol == "bolt.circle.fill", "Running should have a distinct symbol")
    runner.expect(running.detail == "2 个对话进程正在运行", "Running detail should include the active count")

    let recentOutput = AccountPresentationBuilder.runtime(
        status: AccountRuntimeStatus(
            state: "running",
            light: "green",
            label: "运行中",
            activeProcessCount: 0,
            recentProcessCount: 1
        )
    )
    runner.expect(recentOutput.detail == "最近 90 秒内有 Codex 输出", "Recent output should remain running")

    let waiting = AccountPresentationBuilder.runtime(
        status: AccountRuntimeStatus(
            state: "waiting",
            light: "yellow",
            label: "待接手",
            activeProcessCount: 0,
            recentProcessCount: 1
        )
    )
    runner.expect(waiting.label == "待接手", "Waiting state should keep the existing product wording")
    runner.expect(waiting.symbol == "pause.circle.fill", "Waiting should not rely on color alone")
    runner.expect(waiting.detail == "最近 15 分钟内有活动，可能等你继续", "Waiting should explain the next action")

    let idle = AccountPresentationBuilder.runtime(
        status: AccountRuntimeStatus(
            state: "idle",
            light: "red",
            label: "空闲",
            activeProcessCount: 0,
            recentProcessCount: 0
        )
    )
    runner.expect(idle.label == "空闲", "Idle state should remain explicit")
    runner.expect(idle.symbol == "circle", "Idle should have a non-color symbol")
    runner.expect(idle.detail == "当前没有运行中的对话", "Idle detail should not imply the app is closed")

    let missingRuntime = AccountPresentationBuilder.runtime(status: nil)
    runner.expect(missingRuntime.label == "未知", "Missing runtime should stay unknown")
    runner.expect(missingRuntime.symbol == "questionmark.circle", "Unknown should have an explicit symbol")

    runner.expect(
        AccountPresentationBuilder.usageSourceLabel("account_usage") == "官方账号用量",
        "Internal source identifiers should be translated for the account page"
    )
    runner.expect(
        AccountPresentationBuilder.usageSourceLabel("future_backend") == "账号统计",
        "Unknown source identifiers should not leak into the user interface"
    )
    runner.expect(
        AccountPresentationBuilder.quotaWindowName(minutes: 300) == "5 小时"
            && AccountPresentationBuilder.quotaWindowName(minutes: 10_080) == "7 日",
        "Quota window names should follow the official duration"
    )
    runner.expect(
        AccountPresentationBuilder.quotaWindowName(minutes: nil) == nil,
        "Missing window metadata must not be guessed"
    )
}
