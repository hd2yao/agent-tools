import CodexWorkbenchCore
import Foundation

func runAccountGatewayTests(_ runner: inout TestRunner) {
    let payloadJSON = #"""
    {
      "generated_at":"2026-07-14T13:55:08.500568+00:00",
      "active_profile":"hd-master",
      "runtime_status":{"state":"running","light":"green","label":"运行中","active_process_count":1,"recent_process_count":1,"latest_activity_age_ms":1200},
      "desktop_status":{"running":true,"managed":true,"state":"managed_default_home","message":"ok","active_profile":"hd-master"},
      "profile_roles":{"task":{"profile":"hd-sarah-blackwell","source":"recent_active_thread_rate_limit_match","confidence":"inferred","observed_at":1784037295,"thread_id":"019f6067-342c-7b22-a9fc-cd50ded08d86"},"desktop":{"profile":"hd-master","source":"desktop_bridge_record","confidence":"confirmed"},"attribution":{"profile":"hd-master","source":"attribution_ledger","confidence":"confirmed"},"task_matches_desktop":false},
      "attribution_summary":{"active_profile":"hd-master","managed":true},
      "local_snapshot":{"event_count":5,"latest_timestamp":"2026-07-17T08:00:00Z","total":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":140},"daily":[{"date":"2026-07-17","input_tokens":100,"cached_input_tokens":20,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":140}],"by_model":[{"model":"gpt-5.6","input_tokens":100,"cached_input_tokens":20,"output_tokens":30,"reasoning_output_tokens":10,"total_tokens":140}]},
      "project_rankings":{"available":true,"projects":[{"name":"tools","path":"/safe/tools","thread_count":3,"tokens_used":1000,"latest_updated_at":1784632000}]},
      "tool_rankings":{"available":true,"tools":[{"id":"functions.exec","namespace":"functions","name":"exec","call_count":9,"latest_updated_at":1784632000,"thread_tokens":3000}]},
      "skill_rankings":{"available":true,"skills":[{"name":"brainstorming","use_count":2,"latest_timestamp":"2026-07-17T08:00:00Z"}],"bad_line_count":0},
      "profiles":[{
        "name":"hd-master",
        "path":"/Users/dysania/.codex/profiles/hd-master",
        "auth":"present",
        "config":"present",
        "account":{"available":true,"type":"chatgpt","plan_type":"plus","email_present":true,"requires_openai_auth":true},
        "rate_limits":{"primary":{"used_percent":13,"remaining_percent":87,"window_minutes":300,"resets_at":1784632385},"secondary":{"used_percent":38,"remaining_percent":62,"window_minutes":10080,"resets_at":1785032385},"rate_limit_reached_type":"primary","reset_credits":{"available":true,"available_count":2}},
        "reset_credit_details":{"available":true,"available_count":2,"total_earned_count":4,"earliest_expires_at":1784732385,"credits":[{"id":"masked","status":"available","used":false,"title":"额度重置","expires_at":1784732385,"reminders":[{"kind":"one_hour","at":1784728785}]}]},
        "reset_credit_stale":false,
        "reset_credit_error":null,
        "usage":{"summary":{"lifetimeTokens":50000,"peakDailyTokens":9000,"currentStreakDays":3},"dailyUsageBuckets":[{"startDate":"2026-07-16","tokens":8000},{"startDate":"2026-07-17","tokens":1234}]},
        "usage_metrics":{"today_tokens":1234,"today_available":true,"last_7_tokens":9000,"last_14_tokens":17000,"latest_date":"2026-07-17","source":"account_usage"},
        "token_attribution":{"active_profile":"hd-master","managed":true,"estimate_available":true,"today_estimated_tokens":1200,"today_official_tokens":1234,"today_display_tokens":1234,"today_source":"official"},
        "remote_stale":false,
        "remote_error":null
      }]
    }
    """#
    let decoded = try? AccountDashboardPayload.decode(data: Data(payloadJSON.utf8))
    runner.expect(decoded?.activeProfile == "hd-master", "Active profile should decode")
    runner.expect(decoded?.desktopStatus?.running == true, "Desktop running state should decode")
    runner.expect(decoded?.profileRoles?.task.confidence == .inferred, "Task role inference should stay explicit")
    runner.expect(decoded?.profileRoles?.desktop.confidence == .confirmed, "Desktop role should stay confirmed")
    runner.expect(decoded?.profileRoles?.task.threadID == "019f6067-342c-7b22-a9fc-cd50ded08d86", "Task role should retain thread id")
    runner.expect(decoded?.runtimeStatus?.state == "running", "Runtime state should decode")
    runner.expect(decoded?.runtimeStatus?.activeProcessCount == 1, "Runtime process count should decode")
    runner.expect(decoded?.profiles.first?.account?.planType == "plus", "Account plan should decode")
    runner.expect(decoded?.profiles.first?.rateLimits.primary?.remainingPercent == 87, "Primary remaining quota should decode")
    runner.expect(decoded?.profiles.first?.rateLimits.secondary?.remainingPercent == 62, "Secondary quota should decode")
    runner.expect(decoded?.profiles.first?.rateLimits.resetCredits?.availableCount == 2, "Reset credits should decode")
    runner.expect(decoded?.profiles.first?.resetCreditDetails?.credits.count == 1, "Individual reset credits should decode")
    runner.expect(decoded?.profiles.first?.resetCreditDetails?.credits.first?.reminders?.first?.kind == "one_hour", "Reset credit reminders should decode")
    runner.expect(decoded?.profiles.first?.usageMetrics?.todayTokens == 1_234, "Account usage metrics should decode")
    runner.expect(decoded?.profiles.first?.usage?.dailyUsageBuckets?.last?.tokens == 1_234, "Daily usage buckets should decode")
    runner.expect(decoded?.profiles.first?.tokenAttribution?.todayDisplayTokens == 1_234, "Token attribution should decode")
    runner.expect(decoded?.attributionSummary?.activeProfile == "hd-master", "Attribution summary should decode")
    runner.expect(decoded?.localSnapshot?.total.totalTokens == 140, "Local token snapshot should decode")
    runner.expect(decoded?.localSnapshot?.byModel?.first?.model == "gpt-5.6", "Local model totals should decode")
    runner.expect(decoded?.projectRankings?.projects.first?.threadCount == 3, "Project rankings should decode")
    runner.expect(decoded?.toolRankings?.tools.first?.callCount == 9, "Tool rankings should decode")
    runner.expect(decoded?.skillRankings?.skills.first?.useCount == 2, "Skill rankings should decode")
    runner.expect(decoded?.profiles.first?.path == "/Users/dysania/.codex/profiles/hd-master", "Profile home should decode for the observer")
    runner.expect(decoded?.profiles.first?.rateLimits.reachedType == "primary", "Official reached state should decode")

    let pythonURL = URL(fileURLWithPath: "/usr/bin/python3")
    let helperURL = URL(fileURLWithPath: "/Applications/Codex 观测站.app/Contents/Resources/codex-profile-switcher/codex_profile.py")
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
    runner.expect(
        builder.consumeResetCreditCommand(profile: "hd-master", idempotencyKey: "stable-key")?.arguments
            == [helperURL.path, "consume-reset-credit", "hd-master", "--idempotency-key", "stable-key"],
        "Reset consumption should reuse the sanitized Python command contract"
    )
    runner.expect(
        builder.consumeResetCreditCommand(profile: "../../bad", idempotencyKey: "stable-key") == nil,
        "Reset consumption must reject unsafe profile names"
    )
    runner.expect(
        builder.consumeResetCreditCommand(profile: "hd-master", idempotencyKey: "") == nil,
        "Reset consumption must reject an empty idempotency key"
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

    let consumeJSON = #"{"ok":true,"outcome":"alreadyRedeemed","expires_at":1784335011,"error":null}"#
    let consumeResult = try? AccountResetCreditConsumeResult.decode(data: Data(consumeJSON.utf8))
    runner.expect(consumeResult?.ok == true, "Reset consumption result should decode its success state")
    runner.expect(consumeResult?.outcome == "alreadyRedeemed", "Reset outcome should preserve backend semantics")
    runner.expect(consumeResult?.expiresAt == 1_784_335_011, "Reset result should decode the selected expiry")

    let busyFailure = AccountGatewayError.processFailure(
        code: 1,
        standardError: "Codex Desktop did not quit within 12 seconds; switch aborted.\n"
    )
    runner.expect(busyFailure == .codexDesktopBusy, "Known switch preconditions should have a safe error")
    runner.expect(
        busyFailure.errorDescription?.contains("任务") == true,
        "The user should understand why Codex could not switch accounts"
    )
    let unknownFailure = AccountGatewayError.processFailure(
        code: 42,
        standardError: "secret backend detail"
    )
    runner.expect(unknownFailure == .processFailed(42), "Unknown backend errors should retain only the exit code")
    runner.expect(
        unknownFailure.errorDescription?.contains("secret backend detail") == false,
        "Unknown stderr must never be exposed"
    )
}
