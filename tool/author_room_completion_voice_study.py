#!/usr/bin/env python3
"""Author the completion-voice audition (room-completion-voice-v2).

Owner signal (2026-08-27): "the completion isnt as satisfying." The shipped
completion composite dates to room-reward-voice-v1 — rendered BEFORE the
2026-08-21 render-polish discipline, so its three stacked modal bodies still
carry the legacy 0.18 excitation beds and the untrimmed reflection send: the
exact "low quality recording vibe" mechanism that was fixed in every other
master but never re-applied here.

Four candidates against the shipped control, all the same permanence grammar
(accepted contact, then the Answered Detent 75 ms later; weight, never
brightness):

- polish        — the shipped gesture byte-for-byte in intent, re-rendered
                  under polish discipline (0.09 beds, trimmed send).
- deeper-seat   — polish + a heavier two-part accepted seat and denser root.
- weighted-answer — polish + the answer carries its own physical catch.
- longer-settle — polish + a longer believable ring (0.36 s), same voices.

Every candidate is level-matched to the shipped control's phone-band energy
so loudness cannot win. Output is audition-only under design/audits; runtime
masters are untouched until a verdict lands.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-completion-voice-v2"
OUTCOME_DELAY_SECONDS = 0.075
D_ROOT, D_ANSWER, D_SUPPORT = 587.330, 880.000, 440.000
POLISH_EXCITATION = 0.09
POLISH_SEND_TRIM = 0.8


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _phone_energy(audio: np.ndarray) -> float:
    probe = world._filter(audio, highpass_hz=260, lowpass_hz=8_000, order=2)
    return float(np.sqrt(np.sum(probe * probe)))


def _match_energy(audio: np.ndarray, target: float) -> np.ndarray:
    gain = target / max(_phone_energy(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _receipt_edge(contact: np.ndarray, seconds: float) -> np.ndarray:
    frames = round(seconds * SAMPLE_RATE)
    edge = world._fit(contact, seconds)
    edge = world._filter(edge, highpass_hz=1_600, lowpass_hz=5_200, order=3)
    edge = world._normalize_peak(edge)
    attack = min(frames, round(0.0007 * SAMPLE_RATE))
    if attack:
        edge[:attack] *= np.linspace(0.0, 1.0, attack)
    fade_start = min(frames, round(0.006 * SAMPLE_RATE))
    if fade_start < frames:
        edge[fade_start:] *= (
            np.cos(np.linspace(0, math.pi / 2, frames - fade_start)) ** 2
        )
    return edge


def _finish(result: np.ndarray, send: float) -> np.ndarray:
    release = min(len(result), round(0.040 * SAMPLE_RATE))
    result[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    return world._park(world._room_bus(result, send), 28.0)


def _detent(
    contact: np.ndarray,
    *,
    seconds: float = 0.285,
    contact_gain: float = 0.095,
    double_seat: bool = False,
    root_decay: float = 73,
    root_gain: float = 0.35,
    answer_decay: float = 127,
    answer_gain: float = 0.245,
    answer_catch: float = 0.0,
    support_decay: float = 112,
    support_gain: float = 0.115,
    send: float = 1.06 * POLISH_SEND_TRIM,
    excitation: float = POLISH_EXCITATION,
) -> np.ndarray:
    """The Answered Detent recipe from room-reward-voice-v1, parameterized.
    Defaults reproduce the shipped gesture under polish discipline."""
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    edge = _receipt_edge(contact, min(seconds, 0.012))
    world._place(result, world._fit(contact, 0.014), 0.0, contact_gain)
    if double_seat:
        world._place(result, world._fit(contact, 0.011), 0.005, contact_gain * 0.62)
    world._place(result, edge, 0.0, 0.28)
    world._place(
        result,
        world._modal_body(
            D_ROOT, seconds, root_decay, seed=2_300, low_support=True,
            drift_cents=-7, excitation_gain=excitation,
        ),
        0.002,
        root_gain,
    )
    world._place(
        result,
        world._modal_body(
            D_ANSWER, seconds - 0.058, answer_decay, seed=2_320,
            drift_cents=-12, excitation_gain=excitation,
        ),
        0.058,
        answer_gain,
    )
    if answer_catch > 0:
        world._place(result, world._fit(contact, 0.010), 0.058, answer_catch)
    world._place(
        result,
        world._modal_body(
            D_SUPPORT, seconds - 0.058, support_decay, seed=2_340,
            drift_cents=-15, excitation_gain=excitation,
        ),
        0.058,
        support_gain,
    )
    return _finish(result, send)


def _composite(accepted: np.ndarray, detent: np.ndarray) -> np.ndarray:
    seconds = max(0.43, OUTCOME_DELAY_SECONDS + len(detent) / SAMPLE_RATE + 0.025)
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(result, accepted, 0.0)
    world._place(result, detent, OUTCOME_DELAY_SECONDS)
    return result


def _flow(ordinary: list[np.ndarray], composite: np.ndarray) -> np.ndarray:
    """Two everyday clasps, then the completion — the gesture in context."""
    seconds = 1.15 + len(composite) / SAMPLE_RATE + 0.1
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(result, ordinary[0], 0.0)
    world._place(result, ordinary[1], 0.55)
    world._place(result, composite, 1.15)
    return result


CANDIDATES = {
    "polish": (
        "POLISHED, AS SHIPPED",
        "the exact shipped gesture, re-rendered under the render-polish "
        "discipline the rest of the app got on 08-21 -- quieter noise beds, "
        "subliminal room.",
        dict(),
    ),
    "deeper-seat": (
        "DEEPER SEAT",
        "polish plus a heavier two-part accepted seat and a denser root -- "
        "fuller through body, not volume.",
        dict(contact_gain=0.15, double_seat=True, root_decay=88,
             root_gain=0.42, support_gain=0.16),
    ),
    "weighted-answer": (
        "WEIGHTED ANSWER",
        "polish plus the answer arriving with its own small physical catch, "
        "like a latch truly seating.",
        dict(answer_catch=0.07, answer_gain=0.30, answer_decay=140),
    ),
    "longer-settle": (
        "LONGER SETTLE",
        "polish with a longer believable ring -- the same voices given room "
        "to settle (0.36 s).",
        dict(seconds=0.36, root_decay=96, answer_decay=168,
             support_decay=140, send=1.06 * 0.85),
    ),
}


def build_study(output: Path, world_root: Path, runtime_sfx: Path) -> dict:
    contact = world._fit(
        world._read_mono(world_root / "shared" / "contact-master.wav"), 0.014
    )
    accepted = world._read_mono(runtime_sfx / "room" / "completion" / "accepted-select-2.wav")
    control = world._read_mono(runtime_sfx / "room" / "completion" / "completion-composite.wav")
    ordinary = [
        world._read_mono(runtime_sfx / "room" / "ordinary" / "navigate" / "1.wav"),
        world._read_mono(runtime_sfx / "room" / "ordinary" / "open" / "3.wav"),
    ]
    target = _phone_energy(control)

    manifest = {"study": STUDY_ID, "level_reference": "shipped composite",
                "candidates": {}}
    renders = {"control": control}
    for name, (_, _, params) in CANDIDATES.items():
        renders[name] = _match_energy(
            _composite(accepted, _detent(contact, **params)), target
        )

    for name, audio in renders.items():
        world._write(output / "candidates" / f"{name}.wav", audio)
        world._write(output / "flows" / f"{name}-flow.wav", _flow(ordinary, audio))
        manifest["candidates"][name] = {
            "sha256": _sha256(output / "candidates" / f"{name}.wav"),
            "seconds": round(len(audio) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(audio))), 6),
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
        print(f"  {name}: {meta['seconds']}s peak {meta['peak']}")


if __name__ == "__main__":
    main()
