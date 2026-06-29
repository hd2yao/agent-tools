import json
import tempfile
import unittest
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
from pathlib import Path
from threading import Thread


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
