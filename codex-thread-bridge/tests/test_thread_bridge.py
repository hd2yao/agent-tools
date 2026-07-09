import json
import sqlite3
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import thread_bridge
import codex_thread_bridge


class ThreadBridgeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name) / "codex"
        self.home.mkdir()
        self.thread_id = "thread-1"
        self.rollout = self.home / "sessions" / "2026" / "07" / "07" / "rollout-thread-1.jsonl"
        self.rollout.parent.mkdir(parents=True)
        self._write_sqlite()
        self._write_global_state()
        self._write_session_index()
        self._write_context_card()
        self._write_rollout()

    def tearDown(self):
        self.tmp.cleanup()

    def _write_sqlite(self):
        conn = sqlite3.connect(self.home / "state_5.sqlite")
        try:
            conn.execute(
                """
                create table threads (
                    id text primary key,
                    rollout_path text not null,
                    created_at integer not null,
                    updated_at integer not null,
                    source text not null,
                    model_provider text not null,
                    cwd text not null,
                    title text not null,
                    sandbox_policy text not null,
                    approval_mode text not null,
                    tokens_used integer not null default 0,
                    preview text not null default ''
                )
                """
            )
            conn.execute(
                """
                insert into threads (
                    id, rollout_path, created_at, updated_at, source, model_provider,
                    cwd, title, sandbox_policy, approval_mode, tokens_used, preview
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    self.thread_id,
                    str(self.rollout),
                    100,
                    200,
                    "local",
                    "openai",
                    "/tmp/source-project",
                    "Source Thread",
                    "workspace-write",
                    "never",
                    1234,
                    "First user request",
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def _write_global_state(self):
        (self.home / ".codex-global-state.json").write_text(
            json.dumps(
                {
                    "projectless-thread-ids": [self.thread_id],
                    "thread-projectless-output-directories": {
                        self.thread_id: "/tmp/source-project/outputs"
                    },
                    "thread-workspace-root-hints": {"other-thread": "/tmp/other"},
                    "project-order": ["/tmp/source-project"],
                }
            )
            + "\n",
            encoding="utf-8",
        )

    def _write_session_index(self):
        (self.home / "session_index.jsonl").write_text(
            json.dumps(
                {
                    "id": self.thread_id,
                    "thread_name": "Readable Source Thread",
                    "updated_at": "2026-07-07T01:02:03Z",
                }
            )
            + "\n",
            encoding="utf-8",
        )

    def _write_context_card(self):
        card_dir = self.home / "context-cards"
        card_dir.mkdir()
        (card_dir / "20260707-source-thread.md").write_text(
            "\n".join(
                [
                    "# Codex 上下文摘要卡片",
                    "",
                    f"- 会话 ID: `{self.thread_id}`",
                    "- 项目路径: `/tmp/source-project`",
                    "",
                    "## 当前主题",
                    "",
                    "- Build a bridge",
                    "",
                    "## 最近助手进展",
                    "",
                    "- Wrote the design",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

    def _write_rollout(self):
        records = [
            {
                "timestamp": "2026-07-07T01:00:00Z",
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "user",
                    "content": [{"type": "input_text", "text": "请继续这个工具"}],
                },
            },
            {
                "timestamp": "2026-07-07T01:01:00Z",
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "assistant",
                    "content": [{"type": "output_text", "text": "已经完成调研"}],
                },
            },
            {
                "timestamp": "2026-07-07T01:01:00Z",
                "type": "response_item",
                "payload": {
                    "type": "message",
                    "role": "assistant",
                    "content": [{"type": "output_text", "text": "已经完成调研"}],
                },
            },
        ]
        self.rollout.write_text(
            "\n".join(json.dumps(record, ensure_ascii=False) for record in records) + "\n",
            encoding="utf-8",
        )

    def test_list_threads_merges_sqlite_global_state_and_session_index(self):
        threads = thread_bridge.list_threads(self.home)

        self.assertEqual(len(threads), 1)
        self.assertEqual(threads[0].id, self.thread_id)
        self.assertEqual(threads[0].title, "Readable Source Thread")
        self.assertEqual(threads[0].cwd, "/tmp/source-project")
        self.assertTrue(threads[0].projectless)
        self.assertEqual(threads[0].context_card_paths, [self.home / "context-cards" / "20260707-source-thread.md"])

    def test_build_context_pack_uses_card_and_recent_rollout_messages(self):
        pack = thread_bridge.build_context_pack(self.home, self.thread_id, max_events=2)

        self.assertIn("# Codex Thread Continuation Pack", pack)
        self.assertIn("Source Thread ID: `thread-1`", pack)
        self.assertIn("Readable Source Thread", pack)
        self.assertIn("First user request", pack)
        self.assertIn("Build a bridge", pack)
        self.assertIn("用户: 请继续这个工具", pack)
        self.assertIn("助手: 已经完成调研", pack)

    def test_recent_rollout_messages_dedupes_adjacent_duplicates(self):
        messages = thread_bridge.recent_rollout_messages(self.rollout, max_events=5)

        self.assertEqual(
            messages,
            [
                ("用户", "请继续这个工具"),
                ("助手", "已经完成调研"),
            ],
        )

    def test_context_pack_redacts_common_secret_patterns(self):
        card_path = self.home / "context-cards" / "20260707-source-thread.md"
        with card_path.open("a", encoding="utf-8") as handle:
            handle.write("- card token sk-proj-cardabcdefghijklmnopqrstuvwxyz123456\n")
        with self.rollout.open("a", encoding="utf-8") as handle:
            handle.write(
                json.dumps(
                    {
                        "timestamp": "2026-07-07T01:02:00Z",
                        "type": "response_item",
                        "payload": {
                            "type": "message",
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "token sk-proj-abcdefghijklmnopqrstuvwxyz123456",
                                }
                            ],
                        },
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )

        pack = thread_bridge.build_context_pack(self.home, self.thread_id, max_events=5)

        self.assertIn("[REDACTED]", pack)
        self.assertNotIn("sk-proj-cardabcdefghijklmnopqrstuvwxyz123456", pack)
        self.assertNotIn("sk-proj-abcdefghijklmnopqrstuvwxyz123456", pack)

    def test_assignment_plan_is_dry_run_and_describes_required_state_changes(self):
        plan = thread_bridge.build_assignment_plan(
            self.home,
            self.thread_id,
            "/tmp/target-project",
        )

        self.assertEqual(plan["thread_id"], self.thread_id)
        self.assertEqual(plan["target_project"], "/tmp/target-project")
        self.assertEqual(plan["current_cwd"], "/tmp/source-project")
        self.assertIn("state_5.sqlite: update threads.cwd", plan["changes"])
        self.assertIn(".codex-global-state.json: remove from projectless-thread-ids", plan["changes"])
        self.assertIn(".codex-global-state.json: set thread-workspace-root-hints", plan["changes"])

    def test_cli_list_outputs_thread_title(self):
        stdout = StringIO()
        with redirect_stdout(stdout):
            exit_code = codex_thread_bridge.main(
                ["--codex-home", str(self.home), "list", "--limit", "1"]
            )

        self.assertEqual(exit_code, 0)
        self.assertIn("thread-1", stdout.getvalue())
        self.assertIn("Readable Source Thread", stdout.getvalue())

    def test_cli_pack_outputs_continuation_pack(self):
        stdout = StringIO()
        with redirect_stdout(stdout):
            exit_code = codex_thread_bridge.main(
                ["--codex-home", str(self.home), "pack", self.thread_id, "--max-events", "2"]
            )

        self.assertEqual(exit_code, 0)
        self.assertIn("# Codex Thread Continuation Pack", stdout.getvalue())
        self.assertIn("用户: 请继续这个工具", stdout.getvalue())

    def test_cli_assign_project_outputs_json_dry_run_plan(self):
        stdout = StringIO()
        with redirect_stdout(stdout):
            exit_code = codex_thread_bridge.main(
                [
                    "--codex-home",
                    str(self.home),
                    "assign-project",
                    self.thread_id,
                    "--project",
                    "/tmp/target-project",
                    "--json",
                ]
            )

        self.assertEqual(exit_code, 0)
        payload = json.loads(stdout.getvalue())
        self.assertTrue(payload["dry_run"])
        self.assertEqual(payload["target_project"], "/tmp/target-project")


if __name__ == "__main__":
    unittest.main()
