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
    runner.expect(presentation.quotaText == "87%", "Menu bar should show the active profile primary quota")
    runner.expect(presentation.runtimeLabel == "运行中", "Menu bar should show the shared runtime state")
    runner.expect(presentation.runtimeSymbol == "bolt.circle.fill", "Running state should have a non-color symbol")
    runner.expect(
        presentation.accessibilityLabel == "当前登录账号 hd-master，5小时剩余 87%，Codex 运行中",
        "Menu status should expose account, quota window, value, and runtime"
    )

    let unknown = AccountPresentationBuilder.menu(payload: nil)
    runner.expect(unknown.quotaText == "--", "Unknown quota must not be shown as zero")
    runner.expect(unknown.runtimeLabel == "未知", "Missing runtime must stay unknown")
}
