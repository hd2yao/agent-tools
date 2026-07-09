import json
import tempfile
import unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread


class DashboardNormalizationTests(unittest.TestCase):
    def test_summarize_account_usage_marks_today_missing_when_account_data_lags(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import summarize_account_usage

        result = summarize_account_usage(
            {
                "dailyUsageBuckets": [
                    {"startDate": "2026-07-06", "tokens": 10},
                    {"startDate": "2026-07-07", "tokens": 20},
                    {"startDate": "2026-07-08", "tokens": 30},
                ]
            },
            now=datetime(2026, 7, 9, 1, 0, tzinfo=timezone.utc),
        )

        self.assertIsNone(result["today_tokens"])
        self.assertFalse(result["today_available"])
        self.assertEqual(result["latest_date"], "2026-07-08")
        self.assertEqual(result["last_7_tokens"], 60)
        self.assertEqual(result["last_14_tokens"], 60)

    def test_summarize_account_usage_uses_today_when_present(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import summarize_account_usage

        result = summarize_account_usage(
            {
                "dailyUsageBuckets": [
                    {"startDate": "2026-07-08", "tokens": 30},
                    {"startDate": "2026-07-09", "tokens": 45},
                ]
            },
            now=datetime(2026, 7, 9, 1, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(result["today_tokens"], 45)
        self.assertTrue(result["today_available"])
        self.assertEqual(result["latest_date"], "2026-07-09")
        self.assertEqual(result["last_7_tokens"], 75)

    def test_normalize_reset_credit_details_masks_ids_and_parses_times(self):
        from codex_profile_dashboard import normalize_reset_credit_details

        result = normalize_reset_credit_details(
            {
                "available_count": 2,
                "total_earned_count": 4,
                "credits": [
                    {
                        "id": "RateLimitResetCredit-abcdef123456",
                        "status": "available",
                        "granted_at": "2026-06-18T00:36:51Z",
                        "expires_at": "2026-07-18T00:36:51Z",
                    },
                    {
                        "id": "RateLimitResetCredit-fedcba654321",
                        "status": "used",
                        "created_at": 1783000000,
                        "expiration_time": 1785600000000,
                        "used": True,
                    },
                ],
            }
        )

        self.assertTrue(result["available"])
        self.assertEqual(result["available_count"], 2)
        self.assertEqual(result["total_earned_count"], 4)
        self.assertEqual(result["earliest_expires_at"], 1784335011)
        self.assertEqual(result["credits"][0]["status"], "available")
        self.assertEqual(result["credits"][0]["granted_at"], 1781743011)
        self.assertEqual(result["credits"][0]["expires_at"], 1784335011)
        self.assertEqual(result["credits"][0]["used"], False)
        self.assertRegex(result["credits"][0]["id"], r"^Rate\.\.\.3456 hash:[0-9a-f]{10}$")
        self.assertNotIn("abcdef123456", result["credits"][0]["id"])
        self.assertEqual(result["credits"][1]["used"], True)

    def test_normalize_rate_limits_adds_remaining_percent(self):
        from codex_profile_dashboard import normalize_rate_limits

        payload = {
            "rateLimits": {
                "limitId": "codex",
                "limitName": "Codex",
                "planType": "plus",
                "primary": {
                    "usedPercent": 25,
                    "windowDurationMins": 300,
                    "resetsAt": 1782700000,
                },
                "secondary": None,
                "credits": {"availableCount": 2, "expiresAt": 1783000000},
            }
        }

        result = normalize_rate_limits(payload)

        self.assertEqual(result["limit_id"], "codex")
        self.assertEqual(result["limit_name"], "Codex")
        self.assertEqual(result["plan_type"], "plus")
        self.assertEqual(result["credits_available"], 2)
        self.assertEqual(result["reset_credits"]["available_count"], 2)
        self.assertEqual(result["reset_credits"]["expires_at"], 1783000000)
        self.assertEqual(result["primary"]["used_percent"], 25)
        self.assertEqual(result["primary"]["remaining_percent"], 75)
        self.assertEqual(result["primary"]["window_minutes"], 300)
        self.assertEqual(result["primary"]["resets_at"], 1782700000)
        self.assertIsNone(result["secondary"])

    def test_normalize_rate_limits_supports_current_credit_balance_shape(self):
        from codex_profile_dashboard import normalize_rate_limits

        payload = {
            "rateLimits": {
                "limitId": "codex",
                "planType": "plus",
                "credits": {"balance": 1, "hasCredits": True, "unlimited": False},
            }
        }

        result = normalize_rate_limits(payload)

        self.assertEqual(result["credits_available"], 1)
        self.assertEqual(result["reset_credits"]["available_count"], 1)
        self.assertTrue(result["reset_credits"]["has_credits"])
        self.assertFalse(result["reset_credits"]["unlimited"])

    def test_normalize_rate_limits_supports_top_level_reset_credits(self):
        from codex_profile_dashboard import normalize_rate_limits

        payload = {
            "rateLimits": {"limitId": "codex"},
            "rateLimitResetCredits": {
                "availableCount": 3,
                "expiresAt": 1783100000,
            },
        }

        result = normalize_rate_limits(payload)

        self.assertEqual(result["credits_available"], 3)
        self.assertEqual(result["reset_credits"]["available_count"], 3)
        self.assertEqual(result["reset_credits"]["expires_at"], 1783100000)


class LocalTokenSnapshotTests(unittest.TestCase):
    def test_read_latest_token_count_snapshot(self):
        from codex_profile_dashboard import read_local_token_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "sessions" / "2026" / "06" / "29" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps(
                    {
                        "timestamp": "2026-06-29T01:00:00Z",
                        "payload": {
                            "type": "event_msg",
                            "message": {
                                "type": "token_count",
                                "info": {
                                    "total_token_usage": {
                                        "input_tokens": 10,
                                        "cached_input_tokens": 4,
                                        "output_tokens": 3,
                                        "reasoning_output_tokens": 2,
                                        "total_tokens": 15,
                                    },
                                    "rate_limits": {
                                        "limitId": "codex",
                                        "primary": {"usedPercent": 8},
                                    },
                                },
                            },
                        },
                    }
                )
                + "\n"
                + "{bad-json\n",
                encoding="utf-8",
            )

            result = read_local_token_snapshot(root)

            self.assertEqual(result["event_count"], 1)
            self.assertEqual(result["bad_line_count"], 1)
            self.assertEqual(result["total"]["input_tokens"], 10)
            self.assertEqual(result["total"]["cached_input_tokens"], 4)
            self.assertEqual(result["latest_timestamp"], "2026-06-29T01:00:00Z")
            self.assertEqual(result["rate_limits"]["primary"]["used_percent"], 8)
            self.assertEqual(result["daily"][0]["date"], "2026-06-29")
            self.assertEqual(result["daily"][0]["total_tokens"], 15)

    def test_token_snapshot_counts_only_latest_token_count_per_rollout(self):
        from codex_profile_dashboard import read_local_token_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "sessions" / "2026" / "06" / "29" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps(
                    {
                        "timestamp": "2026-06-29T01:00:00Z",
                        "type": "turn_context",
                        "payload": {"model": "gpt-5.5"},
                    }
                )
                + "\n"
                + json.dumps(
                    {
                        "timestamp": "2026-06-29T01:01:00Z",
                        "payload": {
                            "type": "token_count",
                            "info": {
                                "total_token_usage": {
                                    "input_tokens": 10,
                                    "cached_input_tokens": 4,
                                    "output_tokens": 3,
                                    "reasoning_output_tokens": 2,
                                    "total_tokens": 15,
                                }
                            },
                        },
                    }
                )
                + "\n"
                + json.dumps(
                    {
                        "timestamp": "2026-06-29T01:02:00Z",
                        "payload": {
                            "type": "token_count",
                            "info": {
                                "total_token_usage": {
                                    "input_tokens": 20,
                                    "cached_input_tokens": 8,
                                    "output_tokens": 6,
                                    "reasoning_output_tokens": 4,
                                    "total_tokens": 30,
                                }
                            },
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            result = read_local_token_snapshot(root)

            self.assertEqual(result["event_count"], 2)
            self.assertEqual(result["daily"], [{"date": "2026-06-29", **result["total"]}])
            self.assertEqual(result["by_model"][0]["model"], "gpt-5.5")
            self.assertEqual(result["by_model"][0]["total_tokens"], 30)

    def test_token_snapshot_skips_non_dict_messages(self):
        from codex_profile_dashboard import read_local_token_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "sessions" / "2026" / "06" / "29" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps({"payload": {"type": "event_msg", "message": "plain text"}})
                + "\n",
                encoding="utf-8",
            )

            result = read_local_token_snapshot(root)

            self.assertEqual(result["event_count"], 0)
            self.assertEqual(result["bad_line_count"], 0)

    def test_token_snapshot_skips_rollout_files_that_disappear_during_scan(self):
        from codex_profile_dashboard import read_local_token_snapshot

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            rollout = root / "sessions" / "2026" / "07" / "06" / "rollout-vanished.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.symlink_to(root / "missing-rollout.jsonl")

            result = read_local_token_snapshot(root)

            self.assertEqual(result["event_count"], 0)
            self.assertEqual(result["bad_line_count"], 0)


class TokenAttributionTests(unittest.TestCase):
    def test_record_attribution_baseline_writes_active_profile_snapshot(self):
        from codex_profile_dashboard import (
            read_attribution_ledger,
            record_attribution_baseline,
        )

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}, "latest_timestamp": "2026-07-09T01:00:00Z"},
                managed=True,
                now_seconds=1000,
            )

            ledger = read_attribution_ledger(shared)

            self.assertEqual(ledger["active_profile"], "account-a")
            self.assertEqual(ledger["baseline"]["total_tokens"], 100)
            self.assertEqual(ledger["baseline"]["latest_timestamp"], "2026-07-09T01:00:00Z")
            self.assertTrue(ledger["managed"])

    def test_summarize_profile_attribution_estimates_today_from_switch_delta(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import (
            record_attribution_baseline,
            summarize_profile_attribution,
        )

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}},
                managed=True,
                now_seconds=1783584000,
            )

            result = summarize_profile_attribution(
                shared,
                "account-a",
                {"total": {"total_tokens": 165}},
                {"dailyUsageBuckets": [{"startDate": "2026-07-08", "tokens": 40}]},
                now=datetime(2026, 7, 9, 4, 0, tzinfo=timezone.utc),
            )

            self.assertEqual(result["today_estimated_tokens"], 65)
            self.assertEqual(result["today_display_tokens"], 65)
            self.assertEqual(result["today_source"], "attribution_estimate")
            self.assertTrue(result["estimate_available"])
            self.assertEqual(result["active_profile"], "account-a")

    def test_summarize_profile_attribution_uses_official_today_when_available(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import (
            record_attribution_baseline,
            summarize_profile_attribution,
        )

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}},
                managed=True,
                now_seconds=1783584000,
            )

            result = summarize_profile_attribution(
                shared,
                "account-a",
                {"total": {"total_tokens": 165}},
                {"dailyUsageBuckets": [{"startDate": "2026-07-09", "tokens": 72}]},
                now=datetime(2026, 7, 9, 4, 0, tzinfo=timezone.utc),
            )

            self.assertEqual(result["today_display_tokens"], 72)
            self.assertEqual(result["today_source"], "official")
            self.assertEqual(result["today_estimated_tokens"], 65)

    def test_summarize_profile_attribution_compares_previous_official_day(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import (
            record_attribution_baseline,
            summarize_profile_attribution,
        )

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}},
                managed=True,
                now_seconds=1783497600,
            )
            record_attribution_baseline(
                shared,
                "account-b",
                {"total": {"total_tokens": 165}},
                managed=True,
                now_seconds=1783501200,
            )

            result = summarize_profile_attribution(
                shared,
                "account-a",
                {"total": {"total_tokens": 165}},
                {
                    "dailyUsageBuckets": [
                        {"startDate": "2026-07-08", "tokens": 60},
                    ]
                },
                now=datetime(2026, 7, 9, 4, 0, tzinfo=timezone.utc),
            )

            accuracy = result["previous_day_accuracy"]
            self.assertEqual(accuracy["date"], "2026-07-08")
            self.assertEqual(accuracy["estimated_tokens"], 65)
            self.assertEqual(accuracy["official_tokens"], 60)
            self.assertEqual(accuracy["delta_tokens"], 5)
            self.assertAlmostEqual(accuracy["delta_percent"], 8.333333333333332)

    def test_summarize_profile_attribution_does_not_attribute_unmanaged_usage(self):
        from datetime import datetime, timezone

        from codex_profile_dashboard import (
            record_attribution_baseline,
            summarize_profile_attribution,
        )

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}},
                managed=False,
                now_seconds=1000,
            )

            result = summarize_profile_attribution(
                shared,
                "account-a",
                {"total": {"total_tokens": 165}},
                None,
                now=datetime(2026, 7, 9, 4, 0, tzinfo=timezone.utc),
            )

            self.assertIsNone(result["today_estimated_tokens"])
            self.assertFalse(result["estimate_available"])
            self.assertEqual(result["today_source"], "unavailable")


class AppServerClientTests(unittest.TestCase):
    def test_build_rpc_request(self):
        from codex_profile_dashboard import build_rpc_request

        self.assertEqual(
            build_rpc_request(3, "account/rateLimits/read"),
            {"jsonrpc": "2.0", "id": 3, "method": "account/rateLimits/read"},
        )

    def test_resolve_codex_binary_prefers_app_bundle_binary(self):
        from codex_profile_dashboard import resolve_codex_binary

        with tempfile.TemporaryDirectory() as tmp:
            bundled = Path(tmp) / "Codex.app" / "Contents" / "Resources" / "codex"
            bundled.parent.mkdir(parents=True)
            bundled.write_text("#!/bin/sh\n", encoding="utf-8")

            result = resolve_codex_binary(
                app_binary=bundled,
                path_lookup=lambda _: "/opt/homebrew/bin/codex",
            )

            self.assertEqual(result, str(bundled))


class ProfileApiTests(unittest.TestCase):
    def test_build_profiles_payload_does_not_include_secret_contents(self):
        from codex_profile_dashboard import build_profiles_payload

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            profile = root / "account-a"
            profile.mkdir(parents=True)
            shared.mkdir()
            (profile / "auth.json").write_text("secret-token", encoding="utf-8")

            result = build_profiles_payload(root, shared, read_remote=False)

            text = json.dumps(result)
            self.assertIn("account-a", text)
            self.assertNotIn("secret-token", text)
            self.assertEqual(result["profiles"][0]["auth"], "present")

    def test_build_profiles_payload_uses_cached_remote_status_on_transient_failure(self):
        from codex_profile_dashboard import build_profiles_payload

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            profile = root / "account-a"
            profile.mkdir(parents=True)
            shared.mkdir()

            successful_remote = {
                "ok": True,
                "rate_limits": {
                    "rateLimits": {
                        "limitId": "codex",
                        "planType": "plus",
                        "primary": {"usedPercent": 25, "resetsAt": 1782700000},
                        "credits": {"balance": 1},
                    }
                },
                "usage": {"dailyUsageBuckets": [{"startDate": "2026-07-01", "tokens": 42}]},
                "error": None,
            }

            first = build_profiles_payload(
                root,
                shared,
                read_remote=True,
                remote_reader=lambda _: successful_remote,
                now_seconds=1000,
            )

            self.assertEqual(first["profiles"][0]["rate_limits"]["plan_type"], "plus")
            self.assertFalse(first["profiles"][0]["remote_stale"])

            second = build_profiles_payload(
                root,
                shared,
                read_remote=True,
                remote_reader=lambda _: {
                    "ok": False,
                    "rate_limits": None,
                    "usage": None,
                    "error": "app-server timeout",
                },
                now_seconds=1060,
            )

            profile_payload = second["profiles"][0]
            self.assertEqual(profile_payload["rate_limits"]["plan_type"], "plus")
            self.assertEqual(
                profile_payload["rate_limits"]["primary"]["remaining_percent"],
                75,
            )
            self.assertEqual(profile_payload["usage"]["dailyUsageBuckets"][0]["tokens"], 42)
            self.assertEqual(profile_payload["usage_metrics"]["last_7_tokens"], 42)
            self.assertTrue(profile_payload["remote_stale"])
            self.assertEqual(profile_payload["remote_error"], "app-server timeout")

    def test_build_profiles_payload_includes_reset_credit_details(self):
        from codex_profile_dashboard import build_profiles_payload

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            profile = root / "account-a"
            profile.mkdir(parents=True)
            shared.mkdir()
            (profile / "auth.json").write_text("{}", encoding="utf-8")

            def remote_reader(_profile):
                return {
                    "ok": True,
                    "rate_limits": {
                        "rateLimits": {
                            "limitId": "codex",
                            "credits": {"balance": 1},
                        }
                    },
                    "usage": None,
                    "error": None,
                }

            def reset_credit_reader(_profile):
                return {
                    "ok": True,
                    "details": {
                        "available": True,
                        "available_count": 1,
                        "credits": [
                            {
                                "status": "available",
                                "expires_at": 1784344611,
                            }
                        ],
                        "earliest_expires_at": 1784344611,
                    },
                    "error": None,
                }

            result = build_profiles_payload(
                root,
                shared,
                remote_reader=remote_reader,
                reset_credit_reader=reset_credit_reader,
            )

            details = result["profiles"][0]["reset_credit_details"]
            self.assertEqual(details["available_count"], 1)
            self.assertEqual(details["earliest_expires_at"], 1784344611)
            self.assertEqual(details["credits"][0]["status"], "available")

    def test_build_profiles_payload_includes_token_attribution(self):
        from codex_profile_dashboard import build_profiles_payload, record_attribution_baseline

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            profile = root / "account-a"
            profile.mkdir(parents=True)
            shared.mkdir()
            record_attribution_baseline(
                shared,
                "account-a",
                {"total": {"total_tokens": 100}},
                managed=True,
                now_seconds=1783584000,
            )
            rollout = shared / "sessions" / "2026" / "07" / "09" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps(
                    {
                        "timestamp": "2026-07-09T04:10:00Z",
                        "payload": {
                            "type": "token_count",
                            "info": {
                                "total_token_usage": {
                                    "input_tokens": 120,
                                    "cached_input_tokens": 50,
                                    "output_tokens": 20,
                                    "reasoning_output_tokens": 10,
                                    "total_tokens": 165,
                                }
                            },
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            result = build_profiles_payload(root, shared, read_remote=False, now_seconds=1783587600)

            attribution = result["profiles"][0]["token_attribution"]
            self.assertEqual(attribution["today_display_tokens"], 65)
            self.assertEqual(attribution["today_source"], "attribution_estimate")
            self.assertEqual(result["attribution_summary"]["active_profile"], "account-a")

    def test_build_profiles_payload_seeds_attribution_baseline_for_active_profile(self):
        from codex_profile_dashboard import build_profiles_payload, read_attribution_ledger

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            (root / "account-a").mkdir(parents=True)
            shared.mkdir()
            rollout = shared / "sessions" / "2026" / "07" / "09" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                json.dumps(
                    {
                        "timestamp": "2026-07-09T04:10:00Z",
                        "payload": {
                            "type": "token_count",
                            "info": {
                                "total_token_usage": {
                                    "input_tokens": 80,
                                    "cached_input_tokens": 20,
                                    "output_tokens": 10,
                                    "reasoning_output_tokens": 0,
                                    "total_tokens": 90,
                                }
                            },
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )

            result = build_profiles_payload(
                root,
                shared,
                read_remote=False,
                active_profile="account-a",
                now_seconds=1783587600,
            )

            self.assertEqual(result["attribution_summary"]["active_profile"], "account-a")
            self.assertEqual(result["profiles"][0]["token_attribution"]["today_display_tokens"], 0)
            self.assertEqual(read_attribution_ledger(shared)["baseline"]["total_tokens"], 90)

    def test_read_sqlite_history_summary(self):
        import sqlite3
        from codex_profile_dashboard import read_sqlite_history_summary

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            conn = sqlite3.connect(shared / "state_5.sqlite")
            try:
                conn.execute("create table threads (tokens_used integer)")
                conn.execute("insert into threads values (10)")
                conn.execute("insert into threads values (15)")
                conn.commit()
            finally:
                conn.close()

            result = read_sqlite_history_summary(shared)

            self.assertTrue(result["available"])
            self.assertEqual(result["thread_count"], 2)
            self.assertEqual(result["tokens_used"], 25)

    def test_read_project_rankings_groups_threads_by_workspace(self):
        import sqlite3
        from codex_profile_dashboard import read_project_rankings

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            conn = sqlite3.connect(shared / "state_5.sqlite")
            try:
                conn.execute(
                    "create table threads (id text, cwd text, tokens_used integer, updated_at integer)"
                )
                conn.execute("insert into threads values ('t1', '/work/alpha', 40, 100)")
                conn.execute("insert into threads values ('t2', '/work/alpha', 60, 200)")
                conn.execute("insert into threads values ('t3', '/work/beta', 20, 300)")
                conn.commit()
            finally:
                conn.close()

            result = read_project_rankings(shared, limit=2)

            self.assertTrue(result["available"])
            self.assertEqual(result["projects"][0]["name"], "alpha")
            self.assertEqual(result["projects"][0]["path"], "/work/alpha")
            self.assertEqual(result["projects"][0]["tokens_used"], 100)
            self.assertEqual(result["projects"][0]["thread_count"], 2)
            self.assertEqual(result["projects"][0]["latest_updated_at"], 200)
            self.assertEqual(result["projects"][1]["name"], "beta")

    def test_read_tool_rankings_groups_dynamic_tools(self):
        import sqlite3
        from codex_profile_dashboard import read_tool_rankings

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            conn = sqlite3.connect(shared / "state_5.sqlite")
            try:
                conn.execute(
                    "create table threads (id text, tokens_used integer, updated_at integer)"
                )
                conn.execute(
                    "create table thread_dynamic_tools (thread_id text, name text, namespace text)"
                )
                conn.execute("insert into threads values ('t1', 40, 100)")
                conn.execute("insert into threads values ('t2', 80, 300)")
                conn.execute("insert into thread_dynamic_tools values ('t1', 'exec_command', 'tools')")
                conn.execute("insert into thread_dynamic_tools values ('t2', 'exec_command', 'tools')")
                conn.execute("insert into thread_dynamic_tools values ('t2', 'apply_patch', 'tools')")
                conn.commit()
            finally:
                conn.close()

            result = read_tool_rankings(shared, limit=2)

            self.assertTrue(result["available"])
            self.assertEqual(result["tools"][0]["name"], "exec_command")
            self.assertEqual(result["tools"][0]["namespace"], "tools")
            self.assertEqual(result["tools"][0]["call_count"], 2)
            self.assertEqual(result["tools"][0]["latest_updated_at"], 300)
            self.assertEqual(result["tools"][1]["name"], "apply_patch")

    def test_read_skill_rankings_counts_skill_file_reads(self):
        from codex_profile_dashboard import read_skill_rankings

        with tempfile.TemporaryDirectory() as tmp:
            shared = Path(tmp)
            rollout = shared / "sessions" / "2026" / "07" / "09" / "rollout-test.jsonl"
            rollout.parent.mkdir(parents=True)
            rollout.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "timestamp": "2026-07-09T01:00:00Z",
                                "type": "event_msg",
                                "payload": {
                                    "type": "exec_command_end",
                                    "parsed_cmd": [
                                        {
                                            "type": "read",
                                            "path": "/Users/me/.codex/skills/frontend-ui-guardrail/SKILL.md",
                                        }
                                    ],
                                },
                            }
                        ),
                        json.dumps(
                            {
                                "timestamp": "2026-07-09T02:00:00Z",
                                "type": "event_msg",
                                "payload": {
                                    "type": "exec_command_end",
                                    "parsed_cmd": [
                                        {
                                            "type": "read",
                                            "path": "/Users/me/.codex/skills/frontend-ui-guardrail/SKILL.md",
                                        }
                                    ],
                                },
                            }
                        ),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = read_skill_rankings(shared)

            self.assertTrue(result["available"])
            self.assertEqual(result["skills"][0]["name"], "frontend-ui-guardrail")
            self.assertEqual(result["skills"][0]["use_count"], 2)
            self.assertEqual(result["skills"][0]["latest_timestamp"], "2026-07-09T02:00:00Z")

    def test_build_profiles_payload_includes_local_rankings(self):
        import sqlite3
        from codex_profile_dashboard import build_profiles_payload

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "profiles"
            shared = Path(tmp) / "shared"
            (root / "account-a").mkdir(parents=True)
            shared.mkdir()
            conn = sqlite3.connect(shared / "state_5.sqlite")
            try:
                conn.execute(
                    "create table threads (id text, cwd text, tokens_used integer, updated_at integer)"
                )
                conn.execute(
                    "create table thread_dynamic_tools (thread_id text, name text, namespace text)"
                )
                conn.execute("insert into threads values ('t1', '/work/alpha', 100, 200)")
                conn.execute("insert into thread_dynamic_tools values ('t1', 'exec_command', 'tools')")
                conn.commit()
            finally:
                conn.close()

            result = build_profiles_payload(root, shared, read_remote=False)

            self.assertEqual(result["project_rankings"]["projects"][0]["name"], "alpha")
            self.assertEqual(result["tool_rankings"]["tools"][0]["name"], "exec_command")
            self.assertIn("skill_rankings", result)


class RuntimeStatusTests(unittest.TestCase):
    def test_runtime_status_is_green_with_live_process(self):
        from codex_profile_dashboard import read_runtime_status

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "shared"
            profiles = root / "profiles"
            path = shared / "process_manager" / "chat_processes.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                json.dumps([{"osPid": 123, "updatedAtMs": 1000}]),
                encoding="utf-8",
            )

            result = read_runtime_status(
                shared,
                profiles,
                now_ms=10_000,
                pid_alive=lambda pid: pid == 123,
            )

            self.assertEqual(result["state"], "running")
            self.assertEqual(result["light"], "green")
            self.assertEqual(result["active_process_count"], 1)

    def test_runtime_status_is_yellow_with_recent_activity(self):
        from codex_profile_dashboard import read_runtime_status

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "shared"
            profiles = root / "profiles"
            path = shared / "process_manager" / "chat_processes.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                json.dumps([{"osPid": 123, "updatedAtMs": 1000}]),
                encoding="utf-8",
            )

            result = read_runtime_status(
                shared,
                profiles,
                now_ms=61_000,
                pid_alive=lambda pid: False,
            )

            self.assertEqual(result["state"], "waiting")
            self.assertEqual(result["light"], "yellow")
            self.assertEqual(result["recent_process_count"], 1)

    def test_runtime_status_is_red_without_recent_activity(self):
        from codex_profile_dashboard import read_runtime_status

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shared = root / "shared"
            profiles = root / "profiles"
            path = shared / "process_manager" / "chat_processes.json"
            path.parent.mkdir(parents=True)
            path.write_text(
                json.dumps([{"osPid": 123, "updatedAtMs": 1000}]),
                encoding="utf-8",
            )

            result = read_runtime_status(
                shared,
                profiles,
                now_ms=1_000_000,
                pid_alive=lambda pid: False,
            )

            self.assertEqual(result["state"], "idle")
            self.assertEqual(result["light"], "red")


class DashboardServerTests(unittest.TestCase):
    def test_switch_endpoint_calls_callback(self):
        from codex_profile_dashboard import make_handler

        calls = []
        handler = make_handler(
            Path("/tmp/profiles"),
            Path("/tmp/shared"),
            switch_profile=lambda name: calls.append(name) or 0,
        )
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            body = json.dumps({"name": "account-a"})
            conn = HTTPConnection("127.0.0.1", server.server_port, timeout=5)
            conn.request(
                "POST",
                "/api/switch",
                body=body,
                headers={"Content-Type": "application/json"},
            )
            response = conn.getresponse()
            payload = json.loads(response.read().decode("utf-8"))
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)

        self.assertEqual(response.status, 200)
        self.assertEqual(payload, {"ok": True, "returncode": 0})
        self.assertEqual(calls, ["account-a"])


if __name__ == "__main__":
    unittest.main()
