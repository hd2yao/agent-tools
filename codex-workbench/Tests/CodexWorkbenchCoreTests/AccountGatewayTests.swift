import CodexWorkbenchCore
import Foundation

func runAccountGatewayTests(_ runner: inout TestRunner) {
    let payloadJSON = #"{"generated_at":"2026-07-14T13:55:08.500568+00:00","active_profile":"hd-master","desktop_status":{"running":true,"managed":true,"state":"managed_default_home","message":"ok","active_profile":"hd-master"},"profile_roles":{"task":{"profile":"hd-master","source":"recent_active_thread_rate_limit_match","confidence":"inferred","observed_at":1784037295,"thread_id":"019f6067-342c-7b22-a9fc-cd50ded08d86"},"desktop":{"profile":"hd-master","source":"desktop_bridge_record","confidence":"confirmed"},"attribution":{"profile":"hd-master","source":"attribution_ledger","confidence":"confirmed"},"task_matches_desktop":true},"profiles":[{"name":"hd-master","path":"/Users/dysania/.codex/profiles/hd-master","auth":"present","config":"present","account":{"type":"chatgpt","email":"must-not-be-modeled@example.com"},"rate_limits":{"primary":{"used_percent":11,"remaining_percent":89,"window_minutes":10080,"resets_at":1784632385},"secondary":null,"rate_limit_reached_type":"primary","reset_credits":{"available":true,"available_count":3}},"reset_credit_details":{"available_count":3,"next_expiration_at":null},"remote_stale":false,"remote_error":null}]}"#
    let decoded = try? AccountDashboardPayload.decode(data: Data(payloadJSON.utf8))
    runner.expect(decoded?.activeProfile == "hd-master", "Active profile should decode")
    runner.expect(decoded?.desktopStatus?.running == true, "Desktop running state should decode")
    runner.expect(decoded?.profileRoles?.task.confidence == .inferred, "Task role inference should stay explicit")
    runner.expect(decoded?.profileRoles?.desktop.confidence == .confirmed, "Desktop role should stay confirmed")
    runner.expect(decoded?.profileRoles?.task.threadID == "019f6067-342c-7b22-a9fc-cd50ded08d86", "Task role should retain thread id")
    runner.expect(decoded?.profiles.first?.rateLimits.primary?.remainingPercent == 89, "Primary remaining quota should decode")
    runner.expect(decoded?.profiles.first?.rateLimits.resetCredits?.availableCount == 3, "Reset credits should decode")
    runner.expect(decoded?.profiles.first?.path == "/Users/dysania/.codex/profiles/hd-master", "Profile home should decode for the observer")
    runner.expect(decoded?.profiles.first?.rateLimits.reachedType == "primary", "Official reached state should decode")

    let pythonURL = URL(fileURLWithPath: "/usr/bin/python3")
    let helperURL = URL(fileURLWithPath: "/Applications/Codex 工具台.app/Contents/Resources/codex-profile-switcher/codex_profile.py")
    let builder = AccountCommandBuilder(pythonURL: pythonURL, helperURL: helperURL)
    let status = builder.statusCommand(refreshResetCredits: false)
    runner.expect(status.executableURL == pythonURL, "Status should use the selected Python runtime")
    runner.expect(status.arguments == [helperURL.path, "status", "--json"], "Status should call the JSON contract")
    runner.expect(
        builder.statusCommand(refreshResetCredits: true).arguments.last == "--refresh-reset-credits",
        "Explicit refresh should request fresh reset credits"
    )
    runner.expect(
        builder.switchCommand(profile: "hd-master")?.arguments == [helperURL.path, "app", "hd-master"],
        "Switch should reuse the existing app command"
    )
    runner.expect(builder.switchCommand(profile: "../../bad") == nil, "Unsafe profile names must be rejected")
    runner.expect(builder.switchCommand(profile: "name with space") == nil, "Whitespace profile names must be rejected")

    let environment = AccountCommandBuilder.processEnvironment(base: ["PATH": "/custom/bin"])
    runner.expect(
        environment["PYTHONDONTWRITEBYTECODE"] == "1",
        "Bundled Python must not mutate the signed app by writing bytecode caches"
    )
    runner.expect(
        environment["PATH"]?.hasSuffix(":/custom/bin") == true,
        "Python environment should preserve the caller PATH"
    )
}
