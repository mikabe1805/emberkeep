#!/usr/bin/env python3
"""Author the Room of Days notification-voice audition (room-notification-voice-v1).

The one sound users hear most often — the reminder notification — is the only
sound the app never designed: both platforms play the stock OS chime today
(`lib/platform/notifications_native.dart` passes no custom sound). This study
auditions a voice for that moment, built from the same acoustic world as
everything else: the approved contact master, the modal body bank, the
D-major pentatonic field, and the close room fingerprint.

The concept is "the room knocks." A reminder is the room gently asking for
its keeper — never an alarm, never a reward, and (per the app's oldest rule)
never a guilt trip. Every candidate is therefore a complete, quiet gesture
with a patient ending; nothing sparkles, snaps, or insists.

Render-polish discipline (2026-08-21) is baked in: stacked bodies carry the
reduced 0.09 excitation bed and reflection sends stay modest so nothing reads
as a recording noise floor on a lone lock-screen sound.

Nothing is written to runtime assets. Output lands under design/audits; the
shipping path (iOS Runner-bundle sound + a NEW Android notification channel,
since channels bake their sound at creation) is documented in the study
README and waits for the owner's verdict.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path

import numpy as np

import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-notification-voice-v1"
RENDER_VERSION = "room-notification-author-v1"

A4, D5, E5, A5, B5 = 440.000, 587.330, 659.255, 880.000, 987.767

# A lone sound with no visual context needs a little more presence than an
# in-app place (-27.6) but stays under the earned-event tier (levelup -24.8).
NOTIFICATION_TARGET_DBFS = -27.0
EXCITATION = 0.09  # render-polish bed, not the legacy 0.18


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _calibrate(audio: np.ndarray, target_dbfs: float) -> np.ndarray:
    gain = world._db(target_dbfs) / max(world._phone_rms(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _render_knock_once(contact: np.ndarray) -> np.ndarray:
    # One soft knock: a single seated contact and one warm root that lets go.
    seconds = 0.44
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.85)
    world._place(
        stem,
        world._modal_body(
            D5, seconds, 58, seed=7_100, low_support=True, drift_cents=-6,
            excitation_gain=EXCITATION,
        ),
        0.002,
        0.50,
    )
    return world._park(world._room_bus(stem, 0.85), 26.0)


def _render_knock_paced(contact: np.ndarray) -> np.ndarray:
    # The classic gentle double knock, answered upward: root, then its fifth.
    # The rising pair is the world's "invitation" shape (streak's cousin,
    # much quieter and slower).
    seconds = 0.62
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.78)
    world._place(
        stem,
        world._modal_body(
            D5, seconds, 54, seed=7_200, low_support=True, drift_cents=-5,
            excitation_gain=EXCITATION,
        ),
        0.002,
        0.46,
    )
    world._place(stem, contact, 0.175, 0.6)
    world._place(
        stem,
        world._modal_body(
            A5, seconds - 0.175, 48, seed=7_220, drift_cents=-8,
            excitation_gain=EXCITATION,
        ),
        0.177,
        0.26,
    )
    return world._park(world._room_bus(stem, 0.8), 28.0)


def _render_knock_settle(contact: np.ndarray) -> np.ndarray:
    # The same double knock, answered downward: root, then the fourth below.
    # Settling instead of rising — the patient version; nothing is demanded.
    seconds = 0.62
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.78)
    world._place(
        stem,
        world._modal_body(
            D5, seconds, 54, seed=7_300, low_support=True, drift_cents=-5,
            excitation_gain=EXCITATION,
        ),
        0.002,
        0.46,
    )
    world._place(stem, contact, 0.175, 0.52)
    world._place(
        stem,
        world._modal_body(
            A4, seconds - 0.175, 58, seed=7_320, low_support=True,
            drift_cents=-7, excitation_gain=EXCITATION,
        ),
        0.177,
        0.32,
    )
    return world._park(world._room_bus(stem, 0.8), 30.0)


def _render_field_call(contact: np.ndarray) -> np.ndarray:
    # No knock metaphor: two small finds rising through the field with a
    # faint third — a distant call from the room, loot's far-away relative.
    seconds = 0.70
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.56)
    world._place(
        stem,
        world._modal_body(
            D5, seconds, 50, seed=7_400, low_support=True, drift_cents=-6,
            excitation_gain=EXCITATION,
        ),
        0.002,
        0.40,
    )
    world._place(stem, contact, 0.22, 0.42)
    world._place(
        stem,
        world._modal_body(
            E5, seconds - 0.22, 46, seed=7_420, drift_cents=-8,
            excitation_gain=EXCITATION,
        ),
        0.222,
        0.25,
    )
    world._place(stem, contact, 0.43, 0.3)
    world._place(
        stem,
        world._modal_body(
            B5, seconds - 0.43, 42, seed=7_440, drift_cents=-9,
            excitation_gain=EXCITATION,
        ),
        0.432,
        0.14,
    )
    return world._park(world._room_bus(stem, 0.78), 30.0)


_PAGE_TEMPLATE = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>notification voice · room of days</title>
<style>
  body {{ margin: 0; padding: 28px 18px 60px; background: #191008;
    color: #e8d9bd; font: 15px/1.5 Georgia, serif; }}
  main {{ max-width: 560px; margin: 0 auto; }}
  h1 {{ font-size: 21px; letter-spacing: 0.06em; color: #f0dfae;
    font-weight: normal; margin: 0 0 4px; }}
  p.lede {{ color: #b09a72; font-size: 13px; margin: 0 0 26px; }}
  .card {{ background: rgba(240, 214, 150, 0.06);
    border: 1px solid rgba(240, 214, 150, 0.18); border-radius: 14px;
    padding: 16px 16px 14px; margin-bottom: 14px; }}
  .card h2 {{ font-size: 15px; margin: 0 0 3px; color: #f0dfae;
    font-weight: normal; letter-spacing: 0.04em; }}
  .card p {{ margin: 0 0 12px; font-size: 12.5px; color: #b09a72; }}
  button {{ background: linear-gradient(160deg, #6d4d1f, #4b3413);
    color: #f4e6c0; border: 1px solid rgba(240, 214, 150, 0.35);
    border-radius: 999px; padding: 10px 22px; font: 13px Georgia, serif;
    letter-spacing: 0.08em; }}
  button:active {{ transform: translateY(1px); }}
  .note {{ font-size: 12px; color: #8d7752; margin-top: 26px; }}
</style>
<main>
  <h1>THE ROOM KNOCKS</h1>
  <p class="lede">four candidate voices for the reminder notification —
  same contact, same bodies, same room as everything else. listen on the
  phone speaker; imagine the screen is dark and this is all you get.</p>
  {cards}
  <p class="note">audition only — nothing ships until a verdict lands in
  LISTENING-RESULT.md. the final gate is a real lock-screen delivery, since
  the OS plays notification sounds on its own channel and volume.</p>
</main>
<script>
  function play(id) {{
    document.querySelectorAll('audio').forEach(a => {{ a.pause(); a.currentTime = 0; }});
    document.getElementById(id).play();
  }}
</script>
"""

_CARD_TEMPLATE = """  <div class="card">
    <h2>{title}</h2>
    <p>{blurb}</p>
    <button onclick="play('{id}')">LISTEN</button>
    <audio id="{id}" src="data:audio/wav;base64,{b64}"></audio>
  </div>
"""

CANDIDATES = {
    "knock-once": (
        "one knock",
        "a single seated contact, one warm root, done. the quietest ask.",
        _render_knock_once,
    ),
    "knock-paced": (
        "two knocks, rising",
        "the gentle double knock answered by its fifth — an invitation.",
        _render_knock_paced,
    ),
    "knock-settle": (
        "two knocks, settling",
        "the same knock answered downward — the patient version.",
        _render_knock_settle,
    ),
    "field-call": (
        "a call from the field",
        "three small finds rising through the pentatonic, far away.",
        _render_field_call,
    ),
}


def build_study(output: Path, world_root: Path) -> dict[str, object]:
    contact_path = world_root / "shared" / "contact-master.wav"
    if not contact_path.exists():
        raise FileNotFoundError(contact_path)
    contact = world._fit(world._read_mono(contact_path), 0.014)

    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "contact_master": str(contact_path).replace("\\", "/"),
        "contact_master_sha256": _sha256(contact_path),
        "target_phone_band_dbfs": NOTIFICATION_TARGET_DBFS,
        "excitation_gain": EXCITATION,
        "candidates": {},
    }
    cards = []
    for name, (title, blurb, render) in CANDIDATES.items():
        audio = _calibrate(render(contact), NOTIFICATION_TARGET_DBFS)
        path = output / "candidates" / f"{name}.wav"
        world._write(path, audio)
        manifest["candidates"][name] = {
            "sha256": _sha256(path),
            "seconds": round(len(audio) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(audio))), 6),
            "phone_band_rms_dbfs": round(
                20 * np.log10(max(world._phone_rms(audio), 1e-12)), 2
            ),
        }
        cards.append(
            _CARD_TEMPLATE.format(
                id=name,
                title=title.upper(),
                blurb=blurb,
                b64=base64.b64encode(path.read_bytes()).decode("ascii"),
            )
        )

    (output / "index.html").write_text(
        _PAGE_TEMPLATE.format(cards="".join(cards)), encoding="utf-8"
    )
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--world-study",
        type=Path,
        default=Path("design/audits/2026-08-20/room-sonic-world-v1"),
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = build_study(args.output, args.world_study)
    print(json.dumps({k: v for k, v in manifest.items() if k != "candidates"}))
    for name, meta in manifest["candidates"].items():
        print(f"  {name}: {meta['seconds']}s  {meta['phone_band_rms_dbfs']} dBFS")


if __name__ == "__main__":
    main()
