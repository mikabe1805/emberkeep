"""room-music-rotation-v1 — the shipped umbrella-brush material.

Owner verdicts (2026-08-31, verbatim): "actually umbrella is the best one",
then, of the hat A/B: "i think umbrella-brush is my favorite!"

The shipped form is a GENERATIVE system, never a fixed loop — the approved
thing is the GRAMMAR, not one render. This study prepares the rotation
material: eight takes of the same umbrella-brush grammar, each a different
seeded performance (seed_offset 0-7 shifts every stream together), take-01
byte-identical to the audition winner. The runtime shuffles takes with no
immediate repeat and crossfades at the seams, so no session sounds like the
last and no minute repeats — the answer to the fire-loop complaint, at the
scale of whole performances.

Run from the repo root:

    python tool/author_room_music_rotation_study.py \
        --output design/audits/2026-08-31/room-music-rotation-v1
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

STUDY_ID = "room-music-rotation-v1"
RENDER_VERSION = "rotation-author-v1"
SAMPLE_RATE = world.SAMPLE_RATE
TAKES = 8


def build_study(output: Path) -> dict[str, object]:
    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "companion_to": "design/audits/2026-08-31/room-music-umbrella-hat-v1",
        "grammar": "umbrella-brush (hat='brush'), 72 BPM swung ~57%, "
                   "Bm9|F#m7(11)|A9sus|Em9 + one Gmaj9->A13->Dmaj9->Em9 bridge",
        "takes": TAKES,
        "take_01_is_the_audition_winner": True,
        "target_phone_band_dbfs": v2.TARGET_DBFS,
        "seed_block": "13000-13499 (seed_offset 0-7)",
        "sample_format": "PCM_16",
        "candidates": {},
    }

    for offset in range(TAKES):
        name = f"take-{offset + 1:02d}"
        score = v2._Score(72.0, 0.57, "swung eighths")
        bed, info = v2._render_umbrella(score, hat="brush", seed_offset=offset)
        bed = music._finish(music._calibrate(bed, v2.TARGET_DBFS))
        candidate_path = output / "candidates" / f"{name}.wav"
        music._write_16(candidate_path, bed)
        score_path = output / f"{name}-score.json"
        score_path.parent.mkdir(parents=True, exist_ok=True)
        score_path.write_text(
            json.dumps(score.as_dict(), indent=2) + "\n", encoding="utf-8"
        )
        entry: dict[str, object] = dict(info)
        entry.update({
            "seed_offset": offset,
            "sha256": v2._sha256(candidate_path),
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
    args = parser.parse_args()
    print(json.dumps(build_study(args.output), indent=2))


if __name__ == "__main__":
    main()
