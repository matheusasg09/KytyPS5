"""Integration checks for staged formatting with a disposable Git repository."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("kyty_format", Path(__file__).with_name("format.py"))
formatter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(formatter)


class FormatTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="kyty-format-"))
        self.git("init", "-q")
        self.git("config", "user.name", "matheusasg09")
        self.git("config", "user.email", "matheusasg09@gmail.com")
        self.git("config", "core.autocrlf", "false")
        source = Path(__file__).resolve().parent.parent
        (self.root / "src").mkdir()
        shutil.copyfile(source / ".pre-commit-config.yaml", self.root / ".pre-commit-config.yaml")
        shutil.copyfile(source / "src/.clang-format", self.root / "src/.clang-format")
        self.git("add", ".")
        self.git("commit", "-qm", "fixture")

    def git(self, *args):
        return formatter.git(self.root, *args)

    def stage_bad_source(self):
        path = self.root / "src/example.cpp"
        path.write_text("int main(){return 0;}\n")
        self.git("add", "src/example.cpp")
        return path

    def test_actual_official_hook_formats_then_blocks_without_staging(self):
        path = self.stage_bad_source()
        staged = self.git("show", ":src/example.cpp")
        self.assertEqual(formatter.run(self.root, "staged", []), 1)
        self.assertNotEqual(path.read_bytes(), staged)
        self.assertEqual(self.git("show", ":src/example.cpp"), staged)
        self.git("add", "src/example.cpp")
        self.assertEqual(formatter.run(self.root, "staged", []), 0)
        self.assertEqual(formatter.run(self.root, "check", ["src/example.cpp"]), 0)

    def test_partial_staging_preserves_both_versions(self):
        path = self.stage_bad_source()
        staged = self.git("show", ":src/example.cpp")
        path.write_text("int main(){return 42;}\n")
        working = path.read_bytes()
        with self.assertRaisesRegex(ValueError, "não staged"):
            formatter.run(self.root, "staged", [])
        self.assertEqual(path.read_bytes(), working)
        self.assertEqual(self.git("show", ":src/example.cpp"), staged)

    def test_read_only_check_reports_unformatted_source(self):
        path = self.stage_bad_source()
        content = path.read_bytes()
        self.assertNotEqual(formatter.run(self.root, "check", ["src/example.cpp"]), 0)
        self.assertEqual(path.read_bytes(), content)

    def test_unknown_hook_config_is_refused_before_execution(self):
        self.stage_bad_source()
        path = self.root / ".pre-commit-config.yaml"
        path.write_text(path.read_text().replace("v22.1.3", "v22.1.4"))
        with self.assertRaisesRegex(ValueError, "configuração oficial mudou"):
            formatter.run(self.root, "check", ["src/example.cpp"])

    def test_outside_source_and_traversal(self):
        self.assertEqual(formatter.select_paths(self.root, "check", ["tests/example.cpp"]), [])
        with self.assertRaises(ValueError):
            formatter.select_paths(self.root, "check", ["src/../../outside.cpp"])


if __name__ == "__main__":
    unittest.main()
