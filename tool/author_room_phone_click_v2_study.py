#!/usr/bin/env python3
"""Author a phone-focused everyday-click texture study for Room of Days.

Completion is deliberately outside the experiment: the approved accepted select
and Answered detent are copied into every flow at their existing absolute
positions.  Only ordinary open/select/navigate/place events before completion
change, so crispness/fullness and system level cannot accidentally re-litigate
the earned outcome.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_sonic_world_study as world


SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-phone-click-v2"
RENDER_VERSION = "room-phone-click-v2-author-1"
ORDINARY_ROLES = ("open", "select", "navigate", "place")
TEXTURES = ("ledger-edge", "double-seat")
LEVEL_LIFTS_DB = (2.0, 3.0, 3.5)
TEXTURE_COMPARISON_LIFT_DB = 3.0
COMPLETION_SELECT_AT = 5.300
DETENT_AT = 5.375
RAPID_STEP_SECONDS = 0.125
VARIANT_COUNT = world.VARIANT_COUNT


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _db(value: float) -> float:
    return 10 ** (value / 20)


def _write(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not np.all(np.isfinite(audio)) or float(np.max(np.abs(audio))) >= 1.0:
        raise ValueError(f"refusing invalid or clipped audio: {path}")
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def _edge(contact: np.ndarray, seconds: float) -> np.ndarray:
    """A short phone-readable contact edge, never a separate Foley click."""
    result = world._fit(contact, seconds)
    result = world._filter(result, highpass_hz=1_600, lowpass_hz=4_200, order=3)
    frames = len(result)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    # It lives from 0 to roughly 9 ms and has no bright late tail.
    result *= (1.0 - np.exp(-t / 0.00028)) * np.exp(-t / 0.0034)
    return world._normalize_peak(result)


def _seat(contact: np.ndarray, seconds: float, *, variant: int) -> np.ndarray:
    """Compact 650--1800 Hz seat derived from the approved contact gesture."""
    frames = round(seconds * SAMPLE_RATE)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    source = world._fit(contact, seconds)
    source = world._filter(source, highpass_hz=650, lowpass_hz=1_800, order=3)
    # A correlated, bounded excitation supplies body without inventing a low
    # thump that only one phone speaker happens to reproduce.
    rng = np.random.default_rng(20_286_100 + variant)
    grain = world._bandpass(rng.standard_normal(frames), 650, 1_800, order=2)
    grain = world._normalize_peak(grain)
    envelope = (1.0 - np.exp(-t / 0.00065)) * np.exp(-t / 0.0095)
    # Keep the body recognisably descended from the approved physical contact.
    # The correlated grain prevents a pure filtered copy, but it is a
    # sweetener rather than the material itself.
    result = source * 0.72 + grain * 0.28
    result *= envelope
    return world._normalize_peak(result)


def _texture_role(base: np.ndarray, contact: np.ndarray, texture: str, variant: int) -> np.ndarray:
    seconds = len(base) / SAMPLE_RATE
    result = base.copy()
    edge = _edge(contact, seconds)
    result += edge * 0.105
    if texture == "double-seat":
        # This must read as a genuinely different press mechanism on a phone,
        # not another near-identical EQ finish.  It remains below the contact
        # and inside the same 24 ms causal gesture.
        result += _seat(contact, seconds, variant=variant) * 0.135
    elif texture != "ledger-edge":
        raise ValueError(f"unknown texture: {texture}")
    return world._park(result, 5.0)


def _scale_role(audio: np.ndarray, role: str, lift_db: float) -> np.ndarray:
    target = _db(world.ROLE_TARGET_DBFS[role] + lift_db)
    gain = target / max(world._phone_rms(audio), 1e-12)
    result = audio * gain
    # The study intentionally tries a high everyday hierarchy.  Preserve the
    # declared RMS deltas unless it would actually clip; peak headroom is
    # reported in QC rather than silently deciding the level comparison.
    if float(np.max(np.abs(result))) >= 1.0:
        raise ValueError(f"{role} at +{lift_db} dB would clip")
    return result


def _load_roles(room_root: Path) -> dict[str, list[np.ndarray]]:
    return {
        role: [world._read_mono(room_root / "roles" / role / f"{index}.wav") for index in range(1, VARIANT_COUNT + 1)]
        for role in ORDINARY_ROLES
    }


def _ordinary_timeline() -> list[tuple[float, str, int]]:
    return [
        (0.30, "navigate", 0), (1.05, "open", 1), (1.72, "select", 2),
        (2.18, "select", 0), (2.92, "place", 1), (3.75, "navigate", 2),
        (4.55, "open", 0),
    ]


def _completion_composite(accepted: np.ndarray, detent: np.ndarray) -> np.ndarray:
    result = np.zeros(round(6.10 * SAMPLE_RATE), dtype=np.float64)
    world._place(result, accepted, COMPLETION_SELECT_AT)
    world._place(result, detent, DETENT_AT)
    return result


def _flow(families: dict[str, list[np.ndarray]], completion: np.ndarray) -> np.ndarray:
    result = completion.copy()
    for at, role, variant in _ordinary_timeline():
        world._place(result, families[role][variant], at)
    return result


def _rapid(families: dict[str, list[np.ndarray]]) -> np.ndarray:
    pattern = ("open", "select", "navigate", "place") * 4
    result = np.zeros(round(2.25 * SAMPLE_RATE), dtype=np.float64)
    for index, role in enumerate(pattern):
        # Shared fatigue policy; it is not another experimental axis.
        gain = 1.0 if index == 0 else 0.93 if index < 3 else 0.885
        world._place(result, families[role][index % VARIANT_COUNT], 0.16 + index * RAPID_STEP_SECONDS, gain)
    return result


def _band_energy(audio: np.ndarray, low: float, high: float) -> float:
    probe = world._filter(audio, highpass_hz=low, lowpass_hz=high, order=3)
    return float(np.sum(probe * probe))


def _metrics(audio: np.ndarray) -> dict[str, float]:
    peak = max(float(np.max(np.abs(audio))), 1e-12)
    tail = max(float(np.max(np.abs(audio[-round(.005 * SAMPLE_RATE):]))), 1e-12)
    return {
        "phone_rms_dbfs": 20 * math.log10(max(world._phone_rms(audio), 1e-12)),
        "peak_dbfs": 20 * math.log10(peak),
        "tail_relative_peak_db": 20 * math.log10(tail / peak),
        "edge_1600_4200_energy": _band_energy(audio[:round(.010 * SAMPLE_RATE)], 1_600, 4_200),
        "seat_650_1800_energy": _band_energy(audio[:round(.024 * SAMPLE_RATE)], 650, 1_800),
        "low_250_450_energy": _band_energy(audio, 250, 450),
    }


def build_study(output: Path, room_root: Path, reward_root: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    contact_path = room_root / "shared" / "contact-master.wav"
    accepted_path = room_root / "roles" / "select" / "2.wav"
    detent_path = reward_root / "rewards" / "answered-detent" / "natural.wav"
    source_paths = [contact_path, accepted_path, detent_path] + [
        room_root / "roles" / role / f"{index}.wav" for role in ORDINARY_ROLES for index in range(1, VARIANT_COUNT + 1)
    ]
    for path in source_paths:
        if not path.exists():
            raise FileNotFoundError(path)

    contact = world._read_mono(contact_path)
    bases = _load_roles(room_root)
    accepted = world._read_mono(accepted_path)
    detent = world._read_mono(detent_path)
    completion = _completion_composite(accepted, detent)
    _write(output / "locked" / "completion-composite.wav", completion)
    # Preserve independently hashable source evidence too, rather than relying
    # on a re-encoded extraction from the composite.
    (output / "locked" / "answered-detent-natural.wav").write_bytes(detent_path.read_bytes())
    (output / "locked" / "accepted-select-2.wav").write_bytes(accepted_path.read_bytes())

    candidates: dict[tuple[str, float], dict[str, list[np.ndarray]]] = {}
    candidate_records: dict[str, object] = {}
    for texture in TEXTURES:
        raw = {role: [_texture_role(item, contact, texture, index) for index, item in enumerate(items)] for role, items in bases.items()}
        for lift in LEVEL_LIFTS_DB:
            families = {role: [_scale_role(item, role, lift) for item in items] for role, items in raw.items()}
            candidates[(texture, lift)] = families
            key = f"{texture}@+{lift:.1f}dB"
            paths: dict[str, list[str]] = {}
            metrics: dict[str, list[dict[str, float]]] = {}
            for role, items in families.items():
                paths[role] = []
                metrics[role] = []
                for index, audio in enumerate(items, 1):
                    relative = Path("roles") / texture / f"lift-{lift:.1f}" / role / f"{index}.wav"
                    _write(output / relative, audio)
                    paths[role].append(relative.as_posix())
                    metrics[role].append(_metrics(audio))
            flow_path = Path("flows") / texture / f"lift-{lift:.1f}.wav"
            rapid_path = Path("rapid") / texture / f"lift-{lift:.1f}.wav"
            _write(output / flow_path, _flow(families, completion))
            _write(output / rapid_path, _rapid(families))
            candidate_records[key] = {"texture": texture, "ordinary_lift_db": lift, "role_paths": paths, "metrics": metrics, "flow": flow_path.as_posix(), "rapid": rapid_path.as_posix()}

    hashes = {path.relative_to(output).as_posix(): _sha256(path) for path in sorted(output.rglob("*.wav"))}
    manifest = {
        "study": STUDY_ID,
        "runtime_changed": False,
        "question": "Which everyday Room click remains crisp and full on a phone without competing with completion?",
        "render_contract": {"render_version": RENDER_VERSION, "sample_rate_hz": SAMPLE_RATE, "ordinary_roles": list(ORDINARY_ROLES), "shared_phrase_tokens": [item["id"] for item in world.PITCH_TOKENS], "space_fingerprint_id": world.SPACE_MASTER_ID, "texture_comparison_lift_db": TEXTURE_COMPARISON_LIFT_DB, "level_pass_lifts_db": list(LEVEL_LIFTS_DB), "rapid_step_ms": RAPID_STEP_SECONDS * 1000},
        "axes": {"texture": {"ledger-edge": "1.6-4.2 kHz contact edge over current Room bodies", "double-seat": "same edge plus compact 650-1800 Hz derived seat"}, "system_level": "ordinary-role lift only; completion absolute source is locked", "level_safety_note": "+2.0 dB is the hierarchy-safe end, +3.0 dB the intended compromise, and +3.5 dB an upper-bound audition rather than a presumed shipping default"},
        "locked_completion": {"accepted_select_source": str(accepted_path.resolve()), "answered_detent_source": str(detent_path.resolve()), "accepted_select_sha256": _sha256(accepted_path), "answered_detent_sha256": _sha256(detent_path), "accepted_select_at_seconds": COMPLETION_SELECT_AT, "answered_detent_at_seconds": DETENT_AT, "outcome_delay_ms": 75.0, "completion_composite": "locked/completion-composite.wav"},
        "source_hashes": {str(path.resolve()): _sha256(path) for path in source_paths},
        "candidates": candidate_records,
        "qc": {"device_profiles": ["small-phone-highpass", "mid-forward-phone", "presence-notch-phone"], "rule": "profiles are analysis-only guards; no production candidate is EQ-matched to one handset"},
        "generated_audio_sha256": hashes,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "qc.json").write_text(json.dumps({"study": STUDY_ID, "candidate_metrics": {key: value["metrics"] for key, value in candidate_records.items()}}, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--room-study", type=Path, required=True)
    parser.add_argument("--reward-study", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.room_study, args.reward_study), indent=2))


if __name__ == "__main__":
    main()
