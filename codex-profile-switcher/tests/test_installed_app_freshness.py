import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFY_SCRIPT = ROOT / "verify-menubar-install.sh"


class InstalledAppFreshnessTests(unittest.TestCase):
    def test_verifier_guards_source_mtime_and_three_column_runtime_copy(self):
        self.assertTrue(VERIFY_SCRIPT.is_file())
        source = VERIFY_SCRIPT.read_text(encoding="utf-8")
        self.assertIn("CodexProfileMenuBar.swift", source)
        self.assertIn("-nt", source)
        self.assertIn("5小时剩余", source)
        self.assertIn("7日剩余", source)
        self.assertIn("今日 token", source)

    def test_verifier_starts_bundled_helper_with_gui_runtime_path(self):
        source = VERIFY_SCRIPT.read_text(encoding="utf-8")

        self.assertIn('HELPER="$APP_DIR/Contents/Resources/codex-profile-switcher/codex_profile.py"', source)
        self.assertIn(
            'RUNTIME_PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"',
            source,
        )
        self.assertIn(
            'env PATH="$RUNTIME_PATH" /usr/bin/env python3 "$HELPER" --help',
            source,
        )


if __name__ == "__main__":
    unittest.main()
