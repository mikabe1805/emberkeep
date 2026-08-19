from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tool.audit_capture_manifest import (
    ManifestError,
    check_manifest,
    collect_image_references,
    write_manifest,
)


class AuditCaptureManifestTest(unittest.TestCase):
    def setUp(self) -> None:
        self._temp = tempfile.TemporaryDirectory()
        self.addCleanup(self._temp.cleanup)
        self.root = Path(self._temp.name)
        (self.root / "nested").mkdir()
        (self.root / "first.png").write_bytes(b"first capture\n")
        (self.root / "nested" / "second.webp").write_bytes(
            b"second capture\n"
        )
        self.readme = self.root / "README.md"
        self.readme.write_text(
            "Opened `nested/second.webp` and `first.png`. "
            "A family like `ignored_{one,two}.png` is not one image.\n",
            encoding="utf-8",
        )
        self.manifest = self.root / "capture-manifest.sha256"

    def test_write_and_check_cover_exact_readme_images(self) -> None:
        references = collect_image_references(self.readme)

        write_manifest(self.root, references, self.manifest)
        checked = check_manifest(
            self.root,
            self.manifest,
            required_references=references,
        )

        self.assertEqual(checked, 2)
        entries = [
            line
            for line in self.manifest.read_text(encoding="utf-8").splitlines()
            if line and not line.startswith("#")
        ]
        self.assertTrue(entries[0].endswith("  first.png"))
        self.assertTrue(entries[1].endswith("  nested/second.webp"))

    def test_check_rejects_changed_capture_bytes(self) -> None:
        references = collect_image_references(self.readme)
        write_manifest(self.root, references, self.manifest)
        (self.root / "first.png").write_bytes(b"changed\n")

        with self.assertRaisesRegex(ManifestError, "Hash mismatch.*first.png"):
            check_manifest(
                self.root,
                self.manifest,
                required_references=references,
            )

    def test_check_rejects_an_opened_image_missing_from_manifest(self) -> None:
        references = collect_image_references(self.readme)
        write_manifest(self.root, references, self.manifest)
        (self.root / "third.png").write_bytes(b"third capture\n")
        self.readme.write_text(
            self.readme.read_text(encoding="utf-8")
            + "Opened `third.png` too.\n",
            encoding="utf-8",
        )

        with self.assertRaisesRegex(
            ManifestError,
            "Manifest is missing README image references: third.png",
        ):
            check_manifest(
                self.root,
                self.manifest,
                required_references=collect_image_references(self.readme),
            )


if __name__ == "__main__":
    unittest.main()
