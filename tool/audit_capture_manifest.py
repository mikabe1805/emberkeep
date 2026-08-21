"""Write and verify SHA-256 receipts for the visual-audit evidence.

The audit intentionally leaves the large render-dump corpus ignored. This
manifest binds every exact PNG/WebP path cited by the audit README to the bytes
that were opened, without pretending those ignored images are Git baselines.
"""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path, PurePosixPath
from typing import Iterable


APP_ROOT = Path(__file__).resolve().parents[1]
_CODE_SPAN = re.compile(r"`([^`\r\n]+)`")
_EXACT_IMAGE_PATH = re.compile(r"[A-Za-z0-9_./-]+\.(?:png|webp)", re.IGNORECASE)
_MANIFEST_ENTRY = re.compile(r"([0-9a-f]{64})  (.+)")


class ManifestError(RuntimeError):
    pass


def _normalize_reference(reference: str) -> str:
    normalized = reference.replace("\\", "/")
    path = PurePosixPath(normalized)
    if path.is_absolute() or ".." in path.parts:
        raise ManifestError(f"Image reference must stay under the app root: {reference}")
    return path.as_posix()


def collect_image_references(readme: Path) -> list[str]:
    references: set[str] = set()
    for code_span in _CODE_SPAN.findall(readme.read_text(encoding="utf-8")):
        if not _EXACT_IMAGE_PATH.fullmatch(code_span):
            continue
        references.add(_normalize_reference(code_span))
    if not references:
        raise ManifestError(f"No exact PNG/WebP references found in {readme}")
    return sorted(references)


def _resolve_under_root(root: Path, reference: str) -> Path:
    root = root.resolve()
    candidate = (root / Path(reference)).resolve()
    if candidate != root and root not in candidate.parents:
        raise ManifestError(f"Image reference escapes the app root: {reference}")
    return candidate


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(root: Path, references: Iterable[str], output: Path) -> int:
    normalized = sorted({_normalize_reference(reference) for reference in references})
    if not normalized:
        raise ManifestError("Cannot write an empty capture manifest")
    entries: list[str] = []
    for reference in normalized:
        image = _resolve_under_root(root, reference)
        if not image.is_file():
            raise ManifestError(f"Missing cited audit image: {reference}")
        entries.append(f"{_sha256(image)}  {reference}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "# SHA-256 of every exact PNG/WebP path cited by the audit README\n"
        + "\n".join(entries)
        + "\n",
        encoding="utf-8",
        newline="\n",
    )
    return len(entries)


def _read_manifest(manifest: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line_number, raw_line in enumerate(
        manifest.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = _MANIFEST_ENTRY.fullmatch(line)
        if match is None:
            raise ManifestError(f"Malformed manifest line {line_number}: {raw_line}")
        digest, raw_reference = match.groups()
        reference = _normalize_reference(raw_reference)
        if reference in entries:
            raise ManifestError(f"Duplicate manifest path: {reference}")
        entries[reference] = digest
    if not entries:
        raise ManifestError(f"Capture manifest is empty: {manifest}")
    return entries


def check_manifest(
    root: Path,
    manifest: Path,
    *,
    required_references: Iterable[str] = (),
) -> int:
    entries = _read_manifest(manifest)
    required = {
        _normalize_reference(reference) for reference in required_references
    }
    missing = sorted(required - entries.keys())
    if missing:
        raise ManifestError(
            "Manifest is missing README image references: " + ", ".join(missing)
        )
    extra = sorted(entries.keys() - required) if required else []
    if extra:
        raise ManifestError(
            "Manifest contains images no longer cited by the README: "
            + ", ".join(extra)
        )
    for reference, expected in entries.items():
        image = _resolve_under_root(root, reference)
        if not image.is_file():
            raise ManifestError(f"Missing manifested audit image: {reference}")
        actual = _sha256(image)
        if actual != expected:
            raise ManifestError(
                f"Hash mismatch for {reference}: expected {expected}, got {actual}"
            )
    return len(entries)


def _path_under_root(root: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else root / path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("write", "check"))
    parser.add_argument("--root", default=str(APP_ROOT))
    parser.add_argument("--readme", required=True)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    readme = _path_under_root(root, args.readme)
    manifest = _path_under_root(root, args.manifest)
    references = collect_image_references(readme)
    try:
        if args.mode == "write":
            count = write_manifest(root, references, manifest)
            print(f"Wrote {count} capture hashes to {manifest.relative_to(root)}")
        else:
            count = check_manifest(
                root,
                manifest,
                required_references=references,
            )
            print(f"Verified {count} capture hashes from {manifest.relative_to(root)}")
    except ManifestError as error:
        parser.exit(1, f"error: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
