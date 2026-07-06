import json
import tempfile
import unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread


class DashboardNormalizationTests(unittest.TestCase):
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
