import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from contextlib import redirect_stderr, redirect_stdout


class ImportTests(unittest.TestCase):
    def test_module_imports(self):
        import codex_profile  # noqa: F401


class ProfileHelperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.old_shared_home = os.environ.get("CODEX_SHARED_HOME")
        os.environ["CODEX_SHARED_HOME"] = str(self.root / "shared-codex")

    def tearDown(self):
        if self.old_shared_home is None:
            os.environ.pop("CODEX_SHARED_HOME", None)
        else:
            os.environ["CODEX_SHARED_HOME"] = self.old_shared_home
        self.tmp.cleanup()

    def test_validate_profile_name_accepts_safe_names(self):
        from codex_profile import validate_profile_name

        self.assertEqual(validate_profile_name("account-a"), "account-a")
        self.assertEqual(validate_profile_name("work_2"), "work_2")
        self.assertEqual(validate_profile_name("personal.2026"), "personal.2026")

    def test_validate_profile_name_rejects_unsafe_names(self):
        from codex_profile import validate_profile_name

        bad_names = ["", ".", "..", "../work", "a/b", "a b", "a;b", "$HOME"]
        for name in bad_names:
            with self.subTest(name=name):
                with self.assertRaises(ValueError):
                    validate_profile_name(name)

    def test_profile_path_stays_under_root(self):
        from codex_profile import profile_path

        self.assertEqual(profile_path(self.root, "account-a"), self.root / "account-a")

    def test_ensure_profile_creates_user_only_directory(self):
        from codex_profile import ensure_profile

        path = ensure_profile(self.root, "account-a")

        self.assertTrue(path.is_dir())
        mode = path.stat().st_mode & 0o777
        self.assertEqual(mode, 0o700)

    def test_profile_status_checks_files_without_reading_contents(self):
        from codex_profile import profile_status

        profile = self.root / "account-a"
        profile.mkdir()
        (profile / "auth.json").write_text("secret-token-placeholder", encoding="utf-8")

        status = profile_status(profile)

        self.assertEqual(
            status,
            {"exists": True, "has_auth": True, "has_config": False},
        )

    def test_build_codex_env_sets_codex_home(self):
        from codex_profile import build_codex_env

        env = build_codex_env({"PATH": "/bin", "CODEX_HOME": "/old"}, self.root)

        self.assertEqual(env["PATH"], "/bin")
        self.assertEqual(env["CODEX_HOME"], str(self.root))

    def test_prepare_profile_links_history_to_shared_home(self):
        from codex_profile import prepare_profile_home

        profile = self.root / "account-a"
        shared_home = self.root / "shared-codex"
        profile.mkdir()
        (shared_home).mkdir()
        (shared_home / "state_5.sqlite").write_bytes(b"sqlite-placeholder")

        prepare_profile_home(profile, shared_home)

        for name in ("sessions", "archived_sessions", "history.jsonl", "state_5.sqlite"):
            with self.subTest(name=name):
                link = profile / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (shared_home / name).resolve())

        sqlite_link = profile / "sqlite" / "state_5.sqlite"
        self.assertTrue(sqlite_link.is_symlink())
        self.assertEqual(sqlite_link.resolve(), (shared_home / "state_5.sqlite").resolve())

    def test_prepare_profile_links_skills_to_shared_home(self):
        from codex_profile import prepare_profile_home

        profile = self.root / "account-a"
        shared_home = self.root / "shared-codex"
        profile.mkdir()
        shared_home.mkdir()
        (profile / "skills" / "profile-skill").mkdir(parents=True)
        (profile / "skills" / "profile-skill" / "SKILL.md").write_text("profile", encoding="utf-8")
        (shared_home / "skills" / "shared-skill").mkdir(parents=True)
        (shared_home / "skills" / "shared-skill" / "SKILL.md").write_text("shared", encoding="utf-8")

        prepare_profile_home(profile, shared_home)

        skills_link = profile / "skills"
        self.assertTrue(skills_link.is_symlink())
        self.assertEqual(skills_link.resolve(), (shared_home / "skills").resolve())
        self.assertTrue((shared_home / "skills" / "profile-skill" / "SKILL.md").is_file())
        self.assertTrue((shared_home / "skills" / "shared-skill" / "SKILL.md").is_file())

    def test_prepare_profile_links_local_workspace_entries_to_shared_home(self):
        from codex_profile import prepare_profile_home

        profile = self.root / "account-a"
        shared_home = self.root / "shared-codex"
        profile.mkdir()
        shared_home.mkdir()
        directory_entries = (
            "pets",
            "plugins",
            "vendor_imports",
            "computer-use",
            "attachments",
            "generated_images",
            "shell_snapshots",
            "ambient-suggestions",
            "browser",
            "automations",
            "rules",
            "superpowers",
            "worktrees",
            "cache",
        )
        file_entries = ("session_index.jsonl", "AGENTS.md")
        json_entries = ("models_cache.json",)
        for name in directory_entries:
            (profile / name / "from-profile.txt").mkdir(parents=True)
            (shared_home / name / "from-shared.txt").mkdir(parents=True)
        for name in file_entries:
            (profile / name).write_text("from-profile\n", encoding="utf-8")
            (shared_home / name).write_text("from-shared\n", encoding="utf-8")
        for name in json_entries:
            (profile / name).write_text('{"profile":["one"]}\n', encoding="utf-8")
            (shared_home / name).write_text('{"shared":["one"]}\n', encoding="utf-8")

        prepare_profile_home(profile, shared_home)

        for name in directory_entries:
            with self.subTest(name=name):
                link = profile / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (shared_home / name).resolve())
                self.assertTrue((shared_home / name / "from-profile.txt").is_dir())
                self.assertTrue((shared_home / name / "from-shared.txt").is_dir())
        for name in file_entries:
            with self.subTest(name=name):
                link = profile / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (shared_home / name).resolve())
                self.assertEqual(
                    (shared_home / name).read_text(encoding="utf-8"),
                    "from-shared\nfrom-profile\n",
                )
        for name in json_entries:
            with self.subTest(name=name):
                link = profile / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (shared_home / name).resolve())
                self.assertEqual(
                    (shared_home / name).read_text(encoding="utf-8"),
                    '{"shared":["one"],"profile":["one"]}\n',
                )

    def test_prepare_profile_merges_and_links_global_state(self):
        from codex_profile import prepare_profile_home

        profile = self.root / "account-a"
        shared_home = self.root / "shared-codex"
        profile.mkdir()
        shared_home.mkdir()
        (profile / ".codex-global-state.json").write_text(
            '{"project-order":["/work/current"],"thread-workspace-root-hints":{"t1":"/work/current"}}',
            encoding="utf-8",
        )
        (shared_home / ".codex-global-state.json").write_text(
            '{"project-order":["/work/old"],"thread-workspace-root-hints":{"t0":"/work/old"}}',
            encoding="utf-8",
        )

        prepare_profile_home(profile, shared_home)

        state_link = profile / ".codex-global-state.json"
        self.assertTrue(state_link.is_symlink())
        self.assertEqual(state_link.resolve(), (shared_home / ".codex-global-state.json").resolve())
        self.assertEqual(
            (shared_home / ".codex-global-state.json").read_text(encoding="utf-8"),
            '{"project-order":["/work/old","/work/current"],"thread-workspace-root-hints":{"t0":"/work/old","t1":"/work/current"}}\n',
        )


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.old_root = os.environ.get("CODEX_PROFILE_ROOT")
        self.old_shared_home = os.environ.get("CODEX_SHARED_HOME")
        os.environ["CODEX_PROFILE_ROOT"] = str(self.root)
        os.environ["CODEX_SHARED_HOME"] = str(self.root / "shared-codex")

    def tearDown(self):
        if self.old_root is None:
            os.environ.pop("CODEX_PROFILE_ROOT", None)
        else:
            os.environ["CODEX_PROFILE_ROOT"] = self.old_root
        if self.old_shared_home is None:
            os.environ.pop("CODEX_SHARED_HOME", None)
        else:
            os.environ["CODEX_SHARED_HOME"] = self.old_shared_home
        self.tmp.cleanup()

    def test_init_command_creates_profile(self):
        from codex_profile import main

        out = io.StringIO()
        with redirect_stdout(out):
            code = main(["init", "account-a"])

        self.assertEqual(code, 0)
        self.assertTrue((self.root / "account-a").is_dir())

    def test_list_command_does_not_print_auth_contents(self):
        from codex_profile import main

        profile = self.root / "account-a"
        profile.mkdir()
        (profile / "auth.json").write_text("do-not-print-this", encoding="utf-8")

        out = io.StringIO()
        with redirect_stdout(out):
            code = main(["list"])

        self.assertEqual(code, 0)
        output = out.getvalue()
        self.assertIn("account-a", output)
        self.assertIn("auth: yes", output)
        self.assertNotIn("do-not-print-this", output)

    def test_use_requires_existing_profile(self):
        from codex_profile import main

        err = io.StringIO()
        with redirect_stderr(err):
            code = main(["use", "missing", "--", "--version"])

        self.assertEqual(code, 2)
        self.assertIn("profile not found", err.getvalue())

    def test_app_command_restarts_desktop_and_launches_app(self):
        import codex_profile
        from codex_profile import main

        profile = self.root / "account-a"
        profile.mkdir()
        calls = []
        old_quit = codex_profile.quit_codex_desktop
        old_wait = codex_profile.wait_for_codex_desktop_exit
        old_launch = codex_profile.wait_for_codex_desktop_launch
        old_pid = codex_profile.codex_desktop_pid
        old_run = codex_profile.run_codex
        old_record = codex_profile.record_active_profile
        try:
            codex_profile.quit_codex_desktop = lambda: calls.append(("quit", None))
            codex_profile.wait_for_codex_desktop_exit = lambda: calls.append(("wait", None)) or True
            codex_profile.wait_for_codex_desktop_launch = lambda: calls.append(("launch", None)) or True
            codex_profile.codex_desktop_pid = lambda: 24680
            codex_profile.run_codex = lambda home, args: calls.append((home, list(args))) or 0
            codex_profile.record_active_profile = (
                lambda name, **kwargs: calls.append(("active", name, kwargs))
            )

            code = main(["app", "account-a"])
        finally:
            codex_profile.quit_codex_desktop = old_quit
            codex_profile.wait_for_codex_desktop_exit = old_wait
            codex_profile.wait_for_codex_desktop_launch = old_launch
            codex_profile.codex_desktop_pid = old_pid
            codex_profile.run_codex = old_run
            codex_profile.record_active_profile = old_record

        self.assertEqual(code, 0)
        self.assertEqual(
            calls,
            [
                ("quit", None),
                ("wait", None),
                (profile, ["app"]),
                ("launch", None),
                ("active", "account-a", {"profile_home": profile, "codex_pid": 24680}),
            ],
        )

    def test_app_command_aborts_when_desktop_does_not_quit(self):
        import codex_profile
        from codex_profile import main

        profile = self.root / "account-a"
        profile.mkdir()
        calls = []
        old_quit = codex_profile.quit_codex_desktop
        old_wait = codex_profile.wait_for_codex_desktop_exit
        old_launch = codex_profile.wait_for_codex_desktop_launch
        old_pid = codex_profile.codex_desktop_pid
        old_run = codex_profile.run_codex
        old_record = codex_profile.record_active_profile
        try:
            codex_profile.quit_codex_desktop = lambda: calls.append(("quit", None))
            codex_profile.wait_for_codex_desktop_exit = lambda: calls.append(("wait", None)) or False
            codex_profile.wait_for_codex_desktop_launch = lambda: calls.append(("launch", None)) or True
            codex_profile.codex_desktop_pid = lambda: 24680
            codex_profile.run_codex = lambda home, args: calls.append((home, list(args))) or 0
            codex_profile.record_active_profile = (
                lambda name, **kwargs: calls.append(("active", name, kwargs))
            )

            err = io.StringIO()
            with redirect_stderr(err):
                code = main(["app", "account-a"])
        finally:
            codex_profile.quit_codex_desktop = old_quit
            codex_profile.wait_for_codex_desktop_exit = old_wait
            codex_profile.wait_for_codex_desktop_launch = old_launch
            codex_profile.codex_desktop_pid = old_pid
            codex_profile.run_codex = old_run
            codex_profile.record_active_profile = old_record

        self.assertEqual(code, 1)
        self.assertEqual(calls, [("quit", None), ("wait", None)])
        self.assertIn("did not quit", err.getvalue())

    def test_app_command_aborts_when_desktop_does_not_launch(self):
        import codex_profile
        from codex_profile import main

        profile = self.root / "account-a"
        profile.mkdir()
        calls = []
        old_quit = codex_profile.quit_codex_desktop
        old_wait = codex_profile.wait_for_codex_desktop_exit
        old_launch = codex_profile.wait_for_codex_desktop_launch
        old_pid = codex_profile.codex_desktop_pid
        old_run = codex_profile.run_codex
        old_record = codex_profile.record_active_profile
        try:
            codex_profile.quit_codex_desktop = lambda: calls.append(("quit", None))
            codex_profile.wait_for_codex_desktop_exit = lambda: calls.append(("wait", None)) or True
            codex_profile.wait_for_codex_desktop_launch = lambda: calls.append(("launch", None)) or False
            codex_profile.codex_desktop_pid = lambda: None
            codex_profile.run_codex = lambda home, args: calls.append((home, list(args))) or 0
            codex_profile.record_active_profile = (
                lambda name, **kwargs: calls.append(("active", name, kwargs))
            )

            err = io.StringIO()
            with redirect_stderr(err):
                code = main(["app", "account-a"])
        finally:
            codex_profile.quit_codex_desktop = old_quit
            codex_profile.wait_for_codex_desktop_exit = old_wait
            codex_profile.wait_for_codex_desktop_launch = old_launch
            codex_profile.codex_desktop_pid = old_pid
            codex_profile.run_codex = old_run
            codex_profile.record_active_profile = old_record

        self.assertEqual(code, 1)
        self.assertEqual(calls, [("quit", None), ("wait", None), (profile, ["app"]), ("launch", None)])
        self.assertIn("did not launch", err.getvalue())

    def test_app_command_can_skip_restart(self):
        import codex_profile
        from codex_profile import main

        profile = self.root / "account-a"
        profile.mkdir()
        calls = []
        old_quit = codex_profile.quit_codex_desktop
        old_wait = codex_profile.wait_for_codex_desktop_exit
        old_launch = codex_profile.wait_for_codex_desktop_launch
        old_pid = codex_profile.codex_desktop_pid
        old_run = codex_profile.run_codex
        old_record = codex_profile.record_active_profile
        try:
            codex_profile.quit_codex_desktop = lambda: calls.append(("quit", None))
            codex_profile.wait_for_codex_desktop_exit = lambda: calls.append(("wait", None)) or True
            codex_profile.wait_for_codex_desktop_launch = lambda: calls.append(("launch", None)) or True
            codex_profile.codex_desktop_pid = lambda: 24680
            codex_profile.run_codex = lambda home, args: calls.append((home, list(args))) or 0
            codex_profile.record_active_profile = (
                lambda name, **kwargs: calls.append(("active", name, kwargs))
            )

            code = main(["app", "account-a", "--no-restart"])
        finally:
            codex_profile.quit_codex_desktop = old_quit
            codex_profile.wait_for_codex_desktop_exit = old_wait
            codex_profile.wait_for_codex_desktop_launch = old_launch
            codex_profile.codex_desktop_pid = old_pid
            codex_profile.run_codex = old_run
            codex_profile.record_active_profile = old_record

        self.assertEqual(code, 0)
        self.assertEqual(
            calls,
            [(profile, ["app"]), ("launch", None), ("active", "account-a", {"profile_home": profile, "codex_pid": 24680})],
        )

    def test_active_profile_roundtrip(self):
        from codex_profile import read_active_profile, record_active_profile

        record_active_profile("account-a")

        self.assertEqual(read_active_profile(), "account-a")

    def test_active_profile_record_includes_managed_launch_metadata(self):
        from codex_profile import read_active_profile_record, record_active_profile

        profile_home = self.root / "account-a"
        record_active_profile("account-a", profile_home=profile_home, codex_pid=12345)

        record = read_active_profile_record()

        self.assertEqual(record["active_profile"], "account-a")
        self.assertEqual(record["profile_home"], str(profile_home))
        self.assertEqual(record["codex_pid"], 12345)
        self.assertEqual(record["shared_home"], str(self.root / "shared-codex"))
        self.assertIn("managed_launch_at", record)

    def test_desktop_status_marks_managed_launch_when_pid_matches(self):
        import codex_profile
        from codex_profile import build_desktop_status, record_active_profile

        profile_home = self.root / "account-a"
        record_active_profile("account-a", profile_home=profile_home, codex_pid=12345)

        old_pid = codex_profile.codex_desktop_pid
        try:
            codex_profile.codex_desktop_pid = lambda: 12345

            status = build_desktop_status()
        finally:
            codex_profile.codex_desktop_pid = old_pid

        self.assertTrue(status["running"])
        self.assertTrue(status["managed"])
        self.assertEqual(status["active_profile"], "account-a")
        self.assertEqual(status["codex_pid"], 12345)

    def test_desktop_status_marks_manual_launch_when_pid_differs(self):
        import codex_profile
        from codex_profile import build_desktop_status, record_active_profile

        profile_home = self.root / "account-a"
        record_active_profile("account-a", profile_home=profile_home, codex_pid=12345)

        old_pid = codex_profile.codex_desktop_pid
        try:
            codex_profile.codex_desktop_pid = lambda: 99999

            status = build_desktop_status()
        finally:
            codex_profile.codex_desktop_pid = old_pid

        self.assertTrue(status["running"])
        self.assertFalse(status["managed"])
        self.assertIn("manual", status["state"])

    def test_status_payload_includes_active_profile(self):
        from codex_profile import build_status_payload, record_active_profile

        record_active_profile("account-a")

        self.assertEqual(build_status_payload()["active_profile"], "account-a")

    def test_ui_command_starts_dashboard(self):
        import codex_profile
        from codex_profile import main

        calls = []
        old_run = codex_profile.run_dashboard
        try:
            codex_profile.run_dashboard = lambda host, port, open_browser: (
                calls.append((host, port, open_browser)) or 0
            )

            code = main(["ui", "--port", "9000", "--no-open"])
        finally:
            codex_profile.run_dashboard = old_run

        self.assertEqual(code, 0)
        self.assertEqual(calls, [("127.0.0.1", 9000, False)])

    def test_status_command_prints_json(self):
        import codex_profile
        from codex_profile import main

        old_build = codex_profile.build_status_payload
        try:
            codex_profile.build_status_payload = lambda: {
                "profiles": [{"name": "account-a", "auth": "present"}]
            }
            out = io.StringIO()
            with redirect_stdout(out):
                code = main(["status", "--json"])
        finally:
            codex_profile.build_status_payload = old_build

        self.assertEqual(code, 0)
        self.assertEqual(
            json.loads(out.getvalue()),
            {"profiles": [{"name": "account-a", "auth": "present"}]},
        )


if __name__ == "__main__":
    unittest.main()
