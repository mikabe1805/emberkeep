import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "execution_gate.py"
SPEC = importlib.util.spec_from_file_location("execution_gate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
execution_gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(execution_gate)


class CurrentRevisionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(
            ["git", "-C", str(self.root), "config", "user.email", "gate@example.invalid"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(self.root), "config", "user.name", "Execution Gate"],
            check=True,
        )
        (self.root / "lib").mkdir()
        (self.root / "lib" / "surface.txt").write_text("initial\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "-qm", "implementation"], check=True)
        self.brief = {"revision_scope": {"include": ["lib"], "exclude": []}}

    def tearDown(self):
        self.temp.cleanup()

    def _commit(self, message):
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.root), "commit", "-qm", message], check=True)

    def test_documentation_only_commit_keeps_clean_scoped_revision(self):
        initial = execution_gate.current_revision(self.root, self.brief)
        (self.root / "design").mkdir()
        (self.root / "design" / "evidence.md").write_text("evidence\n", encoding="utf-8")
        self._commit("record evidence")

        self.assertEqual(execution_gate.current_revision(self.root, self.brief), initial)

    def test_implementation_change_moves_scoped_revision(self):
        initial = execution_gate.current_revision(self.root, self.brief)
        (self.root / "lib" / "surface.txt").write_text("changed\n", encoding="utf-8")
        self._commit("change implementation")

        changed = execution_gate.current_revision(self.root, self.brief)
        self.assertNotEqual(changed, initial)
        self.assertTrue(changed.startswith("commit:"))


if __name__ == "__main__":
    unittest.main()
