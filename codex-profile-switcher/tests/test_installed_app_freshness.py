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


if __name__ == "__main__":
    unittest.main()
