import json
import tempfile
import unittest
from pathlib import Path


class DashboardNormalizationTests(unittest.TestCase):
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
                "credits": {"availableCount": 2},
            }
        }

        result = normalize_rate_limits(payload)

        self.assertEqual(result["limit_id"], "codex")
        self.assertEqual(result["limit_name"], "Codex")
        self.assertEqual(result["plan_type"], "plus")
        self.assertEqual(result["credits_available"], 2)
        self.assertEqual(result["primary"]["used_percent"], 25)
        self.assertEqual(result["primary"]["remaining_percent"], 75)
        self.assertEqual(result["primary"]["window_minutes"], 300)
        self.assertEqual(result["primary"]["resets_at"], 1782700000)
        self.assertIsNone(result["secondary"])


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


class AppServerClientTests(unittest.TestCase):
    def test_build_rpc_request(self):
        from codex_profile_dashboard import build_rpc_request

        self.assertEqual(
            build_rpc_request(3, "account/rateLimits/read"),
            {"jsonrpc": "2.0", "id": 3, "method": "account/rateLimits/read"},
        )


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


if __name__ == "__main__":
    unittest.main()
