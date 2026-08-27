#!/usr/bin/env python3
"""Author the level-up ceremony audition (room-levelup-ceremony-v1).

Owner direction (2026-08-27, in the same message that approved the
longer-settle completion): "make sure there's also an actually longer
celebratory sound for actual achievements like level ups."

The shipped levelup is a 0.95 s sparse phrase (low root, octave, fifth, one
blooming crown dyad). With completion now settling over 0.46 s, the level-up
ceremony must clearly outrank it — longer and fuller, still composed: weight
and duration carry the celebration, never brightness or fanfare sparkle.
All candidates grow from the shipped phrase's own bones (same contacts, same
modal bank, D-major field) under render-polish discipline.

Candidates:
- procession  (~1.9 s) — the shipped phrase, then a resolving arrival:
              F#5 answered by a long low-supported D5 ring. Celebration
              that lands home.
- peal        (~2.15 s) — a wider rising walk through the field over a long
              root bed, crowned late: D5, F#5, A5, a light B5, then the
              crown dyad blooming with long rings.
- crown-echo  (~2.4 s) — the shipped ceremony at its own pace, a breath,
              then a quiet echo of the crown an octave down settling into
              the room. Celebration, then afterglow.

Audition only; the runtime master and the suppression-window change ship
after a verdict. Level-matched to the shipped control's phone-band RMS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-levelup-ceremony-v1"
D4, FS4, A4 = 293.665, 369.994, 440.000
D5, FS5, A5, B5 = 587.330, 739.989, 880.000, 987.767
EX = 0.09
SEND = 1.15 * 0.8


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _phone_rms(audio: np.ndarray) -> float:
    return world._phone_rms(audio)


def _match_rms(audio: np.ndarray, target: float) -> np.ndarray:
    gain = target / max(_phone_rms(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _bloom(stem: np.ndarray, seconds: float) -> np.ndarray:
    envelope = 1.0 - np.exp(-np.arange(len(stem)) / SAMPLE_RATE / seconds)
    return stem * envelope


def _body(hz, seconds, decay, seed, **kw):
    kw.setdefault("excitation_gain", EX)
    return world._modal_body(hz, seconds, decay, seed=seed, **kw)


def _shipped_phrase(stem: np.ndarray, contact: np.ndarray, seconds: float) -> None:
    """The shipped levelup gesture, re-voiced under polish discipline."""
    world._place(stem, contact, 0.0, 0.85)
    world._place(stem, _body(D4, seconds, 90, 3_400, low_support=True, drift_cents=-5), 0.002, 0.30)
    world._place(stem, contact, 0.14, 0.5)
    world._place(stem, _body(D5, seconds - 0.14, 100, 3_420, low_support=True), 0.14, 0.30)
    world._place(stem, contact, 0.30, 0.4)
    world._place(stem, _body(A5, seconds - 0.30, 130, 3_440, drift_cents=-6), 0.30, 0.24)
    crown = np.zeros(round((seconds - 0.50) * SAMPLE_RATE), dtype=np.float64)
    world._place(crown, _body(D5, seconds - 0.50, 150, 3_460, low_support=True, drift_cents=9), 0.0, 0.30)
    world._place(crown, _body(A5, seconds - 0.52, 140, 3_480, drift_cents=-4), 0.02, 0.17)
    world._place(stem, _bloom(crown, 0.012), 0.50)


def _render_procession(contact: np.ndarray) -> np.ndarray:
    seconds = 1.9
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    _shipped_phrase(stem, contact, 0.95)
    world._place(stem, contact, 1.02, 0.38)
    world._place(stem, _body(FS5, seconds - 1.02, 120, 3_500, drift_cents=-7), 1.02, 0.16)
    world._place(stem, contact, 1.24, 0.5)
    world._place(
        stem,
        _body(D5, seconds - 1.24, 205, 3_520, low_support=True, drift_cents=-9),
        1.24,
        0.30,
    )
    return world._park(world._room_bus(stem, SEND), 40.0)


def _render_peal(contact: np.ndarray) -> np.ndarray:
    seconds = 2.15
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.9)
    world._place(stem, _body(D4, seconds, 150, 3_600, low_support=True, drift_cents=-4), 0.002, 0.30)
    steps = [(0.0, D5, 135, 0.26, 0.55), (0.22, FS5, 140, 0.22, 0.45),
             (0.46, A5, 150, 0.20, 0.40), (0.72, B5, 130, 0.12, 0.30)]
    for at, hz, decay, gain, catch in steps:
        if at > 0:
            world._place(stem, contact, at, catch)
        world._place(stem, _body(hz, seconds - at, decay, 3_620 + round(at * 100), drift_cents=-6), at + 0.002, gain)
    crown = np.zeros(round((seconds - 0.95) * SAMPLE_RATE), dtype=np.float64)
    world._place(crown, _body(D5, seconds - 0.95, 210, 3_700, low_support=True, drift_cents=8), 0.0, 0.30)
    world._place(crown, _body(A5, seconds - 0.97, 190, 3_720, drift_cents=-5), 0.02, 0.17)
    world._place(stem, _bloom(crown, 0.014), 0.95)
    return world._park(world._room_bus(stem, SEND), 40.0)


def _render_crown_echo(contact: np.ndarray) -> np.ndarray:
    seconds = 2.4
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    _shipped_phrase(stem, contact, 0.95)
    echo = np.zeros(round((seconds - 1.35) * SAMPLE_RATE), dtype=np.float64)
    world._place(echo, _body(D4, seconds - 1.35, 240, 3_800, low_support=True, drift_cents=-6), 0.0, 0.14)
    world._place(echo, _body(A4, seconds - 1.37, 220, 3_820, drift_cents=-10), 0.02, 0.08)
    world._place(stem, _bloom(echo, 0.05), 1.35)
    return world._park(world._room_bus(stem, SEND * 0.95), 40.0)


CANDIDATES = {
    "procession": ("PROCESSION", _render_procession,
                   "the shipped phrase, then a resolving arrival -- celebration that lands home."),
    "peal": ("PEAL", _render_peal,
             "a wider rising walk through the field over a long root, crowned late with long rings."),
    "crown-echo": ("CROWN &amp; ECHO", _render_crown_echo,
                   "the shipped ceremony, a breath, then its crown echoed an octave down into the room."),
}


def build_study(output: Path, world_root: Path, runtime_sfx: Path) -> dict:
    contact = world._fit(
        world._read_mono(world_root / "shared" / "contact-master.wav"), 0.014
    )
    control = world._read_mono(runtime_sfx / "levelup.wav")
    completion = world._read_mono(
        runtime_sfx / "room" / "completion" / "completion-composite.wav"
    )
    ordinary = [
        world._read_mono(runtime_sfx / "room" / "ordinary" / "navigate" / "1.wav"),
        world._read_mono(runtime_sfx / "room" / "ordinary" / "open" / "3.wav"),
    ]
    target = _phone_rms(control)

    renders = {"control": control}
    for name, (_, render, _) in CANDIDATES.items():
        renders[name] = _match_rms(render(contact), target)

    manifest = {"study": STUDY_ID, "level_reference": "shipped levelup.wav",
                "candidates": {}}
    for name, audio in renders.items():
        world._write(output / "candidates" / f"{name}.wav", audio)
        # In context: two clasps, a completion, then the ceremony — the real
        # order of a completing tap that crosses a level.
        seconds = 1.75 + len(audio) / SAMPLE_RATE + 0.1
        flow = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
        world._place(flow, ordinary[0], 0.0)
        world._place(flow, ordinary[1], 0.5)
        world._place(flow, completion, 1.0)
        world._place(flow, audio, 1.75)
        world._write(output / "flows" / f"{name}-flow.wav", flow)
        manifest["candidates"][name] = {
            "sha256": _sha256(output / "candidates" / f"{name}.wav"),
            "seconds": round(len(audio) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(audio))), 6),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(_phone_rms(audio), 1e-12)), 2
            ),
        }

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
    parser.add_argument("--runtime-sfx", type=Path, default=Path("assets/sfx"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = build_study(args.output, args.world_study, args.runtime_sfx)
    for name, meta in manifest["candidates"].items():
        print(f"  {name}: {meta['seconds']}s  {meta['phone_band_rms_dbfs']} dBFS  peak {meta['peak']}")


if __name__ == "__main__":
    main()
