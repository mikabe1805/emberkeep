"""room-music-umbrella-hat-v1 — umbrella won; what carries its eighths now?

Owner verdict (2026-08-31, verbatim, in order):

    "i really enjoy windowseat best, but best to leave out the rain sounds
    etc. they arent needed in the first place, and they dont even sound like
    rain they sound like bubble taps? i mean i kind of enjoy that sound
    effect so it can be used for a later app's tapping sound"

    "actually umbrella is the best one"

The droplet voice is rejected as it sounds ("bubble taps"), and umbrella —
the winner — is the one candidate whose percussion design leaned on that
voice (the rain was the hi-hat). This confirmation study resolves the fork
by ear instead of by assumption: the same umbrella performance three ways,
byte-identical in every note, differing ONLY in the hat treatment.

- `umbrella-rain`  — the auditioned original, byte-identical to
  room-music-v2's umbrella.wav (the reference point).
- `umbrella-bare`  — the hat removed entirely: thump, rim, keys, bass,
  motif, nothing else.
- `umbrella-brush` — the hat re-voiced as a dark swung shaker-brush on the
  eighths (the windowseat shaker's grain family, alternating strong/weak,
  dragging with the kit) — the lofi "dark closed hats" grammar, nothing
  droplet-like.

Run from the repo root:

    python tool/author_room_music_umbrella_hat_study.py \
        --output design/audits/2026-08-31/room-music-umbrella-hat-v1
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np

import author_room_music_study as music
import author_room_music_v2_study as v2
import author_room_sonic_world_study as world

STUDY_ID = "room-music-umbrella-hat-v1"
RENDER_VERSION = "umbrella-hat-author-v1"
SAMPLE_RATE = world.SAMPLE_RATE


def build_study(output: Path, world_root: Path) -> dict[str, object]:
    roles = {}
    for role in ("navigate", "open", "select", "place"):
        role_path = world_root / "roles" / role / "1.wav"
        if not role_path.exists():
            raise FileNotFoundError(f"world role master missing: {role_path}")
        roles[role] = world._read_mono(role_path)

    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "companion_to": "design/audits/2026-08-31/room-music-v2",
        "world_root": world_root.as_posix(),
        "question": "umbrella won; the droplet hat is vetoed as it sounds — "
                    "bare kit, or a dark swung brush?",
        "target_phone_band_dbfs": v2.TARGET_DBFS,
        "seed_block": "13000-13499 (shared with room-music-v2; brush stream 13190)",
        "sample_format": "PCM_16",
        "candidates": {},
    }

    for name, hat in (
        ("umbrella-rain", "rain"),
        ("umbrella-bare", "none"),
        ("umbrella-brush", "brush"),
    ):
        score = v2._Score(72.0, 0.57, "swung eighths")
        bed, info = v2._render_umbrella(score, hat=hat)
        bed = music._finish(music._calibrate(bed, v2.TARGET_DBFS))
        candidate_path = output / "candidates" / f"{name}.wav"
        music._write_16(candidate_path, bed)
        flow_path = output / "flows" / f"{name}-flow.wav"
        music._write_16(flow_path, music._flow(bed, roles))
        score_path = output / f"{name}-score.json"
        score_path.parent.mkdir(parents=True, exist_ok=True)
        score_path.write_text(
            json.dumps(score.as_dict(), indent=2) + "\n", encoding="utf-8"
        )
        entry: dict[str, object] = dict(info)
        entry.update({
            "sha256": v2._sha256(candidate_path),
            "flow_sha256": v2._sha256(flow_path),
            "score": f"{name}-score.json",
            "score_sha256": v2._sha256(score_path),
            "seconds": round(len(bed) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(bed))), 6),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(world._phone_rms(bed), 1e-12)), 2
            ),
            "note_events": sum(1 for e in score.events if e["midi"] is not None),
            "percussion_events": sum(1 for e in score.events if e["midi"] is None),
        })
        manifest["candidates"][name] = entry  # type: ignore[index]

    manifest_path = output / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--world-study", type=Path, default=v2.WORLD_ROOT)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.world_study), indent=2))


if __name__ == "__main__":
    main()
