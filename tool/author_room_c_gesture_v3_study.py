#!/usr/bin/env python3
"""Author a full-gesture C-centered phone click study.

Every ordinary cue is a complete 60 ms mechanism.  The historical system is
the exact approved C asset; the two challengers reuse the same deterministic
contact/body/closure physics rather than EQ-ing the later, truncated Room
contact master.  Output is staging-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_sonic_world_study as world
import author_weighted_click_study as weighted


SAMPLE_RATE = weighted.SAMPLE_RATE
STUDY_ID = "room-c-gesture-v3"
RENDER_VERSION = "room-c-gesture-v3-author-2"
ORDINARY_ROLES = ("open", "select", "navigate", "place")
VARIANT_COUNT = weighted.VARIANT_COUNT
CLICK_SECONDS = weighted.CLICK_SECONDS
COMPLETION_SELECT_AT = 5.300
DETENT_AT = 5.375
RAPID_STEP_SECONDS = 0.125
SLOW_STEP_SECONDS = 0.320
RATE_GAINS = (1.0, 0.93, 0.93, 0.885)
# The last attested phone study found the ordinary family too quiet at full
# device volume.  Keep level out of this comparison by applying one common
# scalar to C and both challengers.  The raw approved C files remain copied
# byte-for-byte under anchor/ for lineage proof.
COMMON_AUDITION_LIFT_DB = 1.5
COMMON_AUDITION_GAIN = 10 ** (COMMON_AUDITION_LIFT_DB / 20)

# (body gain, decay milliseconds, closure gain, closure delay milliseconds).
# C itself is special: it is copied whole, never re-rendered.
ROLE_SPECS = {
    "c-role-family": {
        "open": (0.205, 8.8, 0.076, 6.0),
        "select": (0.235, 9.7, 0.082, 6.0),
        "navigate": None,
        "place": (0.335, 12.2, 0.082, 6.0),
    },
    "c-clasp-family": {
        "open": (0.225, 9.2, 0.115, 8.5),
        "select": (0.270, 10.4, 0.115, 8.5),
        "navigate": (0.285, 11.0, 0.115, 8.5),
        "place": (0.360, 12.8, 0.115, 8.5),
    },
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not np.all(np.isfinite(audio)) or float(np.max(np.abs(audio))) >= 1.0:
        raise ValueError(f"refusing invalid or clipped audio: {path}")
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def _phone_rms(audio: np.ndarray) -> float:
    return world._phone_rms(audio)


def _scale_to_variant_reference(audio: np.ndarray, reference: np.ndarray) -> np.ndarray:
    """Match one challenger exactly to its corresponding approved C take."""
    gain = _phone_rms(reference) / max(_phone_rms(audio), 1e-12)
    scaled = audio * gain
    if float(np.max(np.abs(scaled))) >= 1.0:
        raise ValueError("C-matched challenger would clip")
    return scaled


def _render_original_physics(
    body_gain: float, body_decay_ms: float, closure_gain: float,
    closure_delay_ms: float, variant: int,
) -> np.ndarray:
    """The approved authoring physics, with only declared role parameters moved."""
    mechanism = weighted.Mechanism("v3", body_gain, body_decay_ms, closure_gain)
    rate = SAMPLE_RATE * weighted.OVERSAMPLE
    frames = round(CLICK_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate
    contact = weighted._contact_layer(variant, t, rate)
    body = weighted._body_layer(mechanism, variant, t, rate)
    if closure_delay_ms == weighted.CLOSURE_DELAY_MS:
        closure = weighted._closure_layer(mechanism, variant, t, rate)
    else:
        local = t - closure_delay_ms / 1000
        active = local >= 0
        local = np.maximum(local, 0.0)
        noise = weighted._normalize_peak(weighted._bandpass(
            np.random.default_rng(20_261_002 + variant * 173).standard_normal(len(t)),
            rate, 880, 4_500, order=3,
        ))
        low = weighted._normalize_peak(weighted._bandpass(
            np.random.default_rng(20_261_027 + variant * 179).standard_normal(len(t)),
            rate, 480, 1_650, order=2,
        ))
        envelope = active * (1.0 - np.exp(-local / 0.00010))
        envelope *= np.exp(-local / (weighted.CLOSURE_DECAY_MS / 1000))
        closure = weighted._normalize_peak(noise * envelope * 0.76 + low * envelope * 0.42)
    audio = contact * weighted.CONTACT_GAIN + body * body_gain + closure * closure_gain
    audio = weighted._filter(audio, rate, highpass_hz=160, lowpass_hz=10_000, order=3)
    release = round(rate * 0.022)
    audio[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    audio = weighted.resample_poly(audio, 1, weighted.OVERSAMPLE, window=("kaiser", 9.0))
    audio = audio[: round(CLICK_SECONDS * SAMPLE_RATE)]
    audio -= float(np.mean(audio[-round(0.010 * SAMPLE_RATE):]))
    return audio.astype(np.float64)


def _closure_energy(audio: np.ndarray, delay_ms: float) -> float:
    start = round((delay_ms - 1.0) / 1000 * SAMPLE_RATE)
    end = round((delay_ms + 4.0) / 1000 * SAMPLE_RATE)
    return float(np.sum(audio[max(0, start):end] ** 2))


def _role_audio(system: str, role: str, variant: int, anchors: list[np.ndarray]) -> np.ndarray:
    anchor = anchors[variant]
    if system == "historical-c" or (system == "c-role-family" and role == "navigate"):
        audio = anchor.copy()
    else:
        spec = ROLE_SPECS[system][role]
        assert spec is not None
        audio = _scale_to_variant_reference(_render_original_physics(*spec, variant), anchor)
    lifted = audio * COMMON_AUDITION_GAIN
    if float(np.max(np.abs(lifted))) >= 1.0:
        raise ValueError("common audition lift would clip")
    return lifted


def _place(base: np.ndarray, audio: np.ndarray, at: float, gain: float = 1.0) -> None:
    world._place(base, audio, at, gain)


def _slow(family: dict[str, list[np.ndarray]]) -> np.ndarray:
    pattern = ("open", "select", "navigate", "place", "select", "navigate")
    result = np.zeros(round(2.05 * SAMPLE_RATE), dtype=np.float64)
    for index, role in enumerate(pattern):
        _place(result, family[role][weighted.VARIANT_WALK[index]], 0.12 + index * SLOW_STEP_SECONDS)
    return result


def _rapid(family: dict[str, list[np.ndarray]]) -> np.ndarray:
    pattern = ("open", "select", "navigate", "place", "open") * 2
    result = np.zeros(round(1.52 * SAMPLE_RATE), dtype=np.float64)
    for index, role in enumerate(pattern):
        gain = RATE_GAINS[min(index, len(RATE_GAINS) - 1)]
        _place(result, family[role][weighted.VARIANT_WALK[index]], 0.12 + index * RAPID_STEP_SECONDS, gain)
    return result


def _completion(accepted: np.ndarray, detent: np.ndarray) -> np.ndarray:
    result = np.zeros(round(6.10 * SAMPLE_RATE), dtype=np.float64)
    _place(result, accepted, COMPLETION_SELECT_AT)
    _place(result, detent, DETENT_AT)
    return result


def _full_flow(family: dict[str, list[np.ndarray]], completion: np.ndarray) -> np.ndarray:
    timeline = ((0.30, "navigate", 0), (1.05, "open", 1), (1.72, "select", 2),
                (2.18, "select", 0), (2.92, "place", 1), (3.75, "navigate", 2),
                (4.55, "open", 0))
    result = completion.copy()
    for at, role, variant in timeline:
        _place(result, family[role][variant], at)
    return result


def _metrics(audio: np.ndarray) -> dict[str, float]:
    peak = max(float(np.max(np.abs(audio))), 1e-12)
    return {
        "phone_rms_dbfs": 20 * math.log10(max(_phone_rms(audio), 1e-12)),
        "peak_dbfs": 20 * math.log10(peak),
        "attack_0_4ms_energy": float(np.sum(audio[:round(.004 * SAMPLE_RATE)] ** 2)),
        "body_4_28ms_energy": float(np.sum(audio[round(.004 * SAMPLE_RATE):round(.028 * SAMPLE_RATE)] ** 2)),
        "closure_5_10ms_energy": _closure_energy(audio, 6.0),
        "tail_after_55ms_relative_peak_db": 20 * math.log10(max(float(np.max(np.abs(audio[round(.055 * SAMPLE_RATE):]))), 1e-12) / peak),
    }


def build_study(output: Path, approved_root: Path, room_root: Path, reward_root: Path) -> dict[str, object]:
    anchor_paths = [approved_root / "variants" / f"dak-c-{index}.wav" for index in range(1, VARIANT_COUNT + 1)]
    accepted_path = room_root / "roles" / "select" / "2.wav"
    detent_path = reward_root / "rewards" / "answered-detent" / "natural.wav"
    for path in [*anchor_paths, accepted_path, detent_path]:
        if not path.exists():
            raise FileNotFoundError(path)
    output.mkdir(parents=True, exist_ok=True)
    (output / "anchor").mkdir(exist_ok=True)
    (output / "locked").mkdir(exist_ok=True)
    for index, path in enumerate(anchor_paths, 1):
        shutil.copyfile(path, output / "anchor" / f"dak-c-{index}.wav")
    anchors = [world._read_mono(path) for path in anchor_paths]
    accepted, detent = world._read_mono(accepted_path), world._read_mono(detent_path)
    completion = _completion(accepted, detent)
    _write(output / "locked" / "completion-composite.wav", completion)
    shutil.copyfile(accepted_path, output / "locked" / "accepted-select-2.wav")
    shutil.copyfile(detent_path, output / "locked" / "answered-detent-natural.wav")

    systems: dict[str, dict[str, list[np.ndarray]]] = {}
    records: dict[str, object] = {}
    for system in ("historical-c", "c-role-family", "c-clasp-family"):
        family = {role: [_role_audio(system, role, variant, anchors) for variant in range(VARIANT_COUNT)] for role in ORDINARY_ROLES}
        systems[system] = family
        paths: dict[str, list[str]] = {}
        metrics: dict[str, list[dict[str, float]]] = {}
        for role, variants in family.items():
            paths[role], metrics[role] = [], []
            for index, audio in enumerate(variants, 1):
                relative = Path("roles") / system / role / f"{index}.wav"
                _write(output / relative, audio)
                paths[role].append(relative.as_posix())
                metrics[role].append(_metrics(audio))
        isolated: dict[str, str] = {}
        for role in ORDINARY_ROLES:
            relative = Path("isolated") / system / f"{role}.wav"
            _write(output / relative, family[role][0])
            isolated[role] = relative.as_posix()
        slow_path, rapid_path, flow_path = (Path("slow") / f"{system}.wav", Path("rapid") / f"{system}.wav", Path("flows") / f"{system}.wav")
        _write(output / slow_path, _slow(family)); _write(output / rapid_path, _rapid(family)); _write(output / flow_path, _full_flow(family, completion))
        records[system] = {"role_paths": paths, "isolated": isolated, "slow": slow_path.as_posix(), "rapid": rapid_path.as_posix(), "flow": flow_path.as_posix(), "metrics": metrics}

    generated = {path.relative_to(output).as_posix(): _sha256(path) for path in sorted(output.rglob("*.wav"))}
    candidates = {
        "C": {
            "label": "old C gesture intact",
            "source_system": "historical-c",
            "single": records["historical-c"]["isolated"]["navigate"],
            "slow": records["historical-c"]["slow"],
            "rapid": records["historical-c"]["rapid"],
            "flow": records["historical-c"]["flow"],
        },
        "X": {
            "label": "challenger",
            "source_system": "c-clasp-family",
            "single": records["c-clasp-family"]["isolated"]["navigate"],
            "slow": records["c-clasp-family"]["slow"],
            "rapid": records["c-clasp-family"]["rapid"],
            "flow": records["c-clasp-family"]["flow"],
        },
    }
    manifest = {
        "study": STUDY_ID, "runtime_changed": False,
        "render_version": RENDER_VERSION,
        "generated_audio_asset_count": len(generated),
        "level_lift_db": COMMON_AUDITION_LIFT_DB,
        "render_contract": {"render_version": RENDER_VERSION, "sample_rate_hz": SAMPLE_RATE, "ordinary_duration_ms": CLICK_SECONDS * 1000, "ordinary_common_audition_lift_db": COMMON_AUDITION_LIFT_DB, "ordinary_common_audition_gain": COMMON_AUDITION_GAIN, "no_room_bus": True, "no_v1_contact_master_input": True, "rapid_step_ms": RAPID_STEP_SECONDS * 1000, "rapid_gains": list(RATE_GAINS)},
        "source_graph": {"anchor": {str(path.resolve()): _sha256(path) for path in anchor_paths}, "historical_c": "approved C variants with waveform shape unchanged and only the declared common audition scalar", "role_family": "original weighted contact/body/6ms closure physics", "clasp_family": "original weighted contact/body with 8.5ms explicit clasp closure", "forbidden_input": str((room_root / "shared" / "contact-master.wav").resolve())},
        "systems": records,
        "candidates": candidates,
        "audition_contract": {
            "fixed_anchor": "C",
            "challengers": ["X"],
            "primary_required_listens": ["single", "slow"],
            "rapid_is_diagnostic_only": True,
            "omitted_from_human_comparison": ["c-role-family"],
            "none_is_valid_and_stops": True,
        },
        "locked_completion": {"accepted_select_source": str(accepted_path.resolve()), "answered_detent_source": str(detent_path.resolve()), "accepted_select_sha256": _sha256(accepted_path), "answered_detent_sha256": _sha256(detent_path), "accepted_select_at_seconds": COMPLETION_SELECT_AT, "answered_detent_at_seconds": DETENT_AT, "outcome_delay_ms": 75.0},
        "generated_audio_sha256": generated,
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "qc.json").write_text(json.dumps({"study": STUDY_ID, "systems": {name: record["metrics"] for name, record in records.items()}}, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--approved-c-study", type=Path, required=True)
    parser.add_argument("--room-study", type=Path, required=True)
    parser.add_argument("--reward-study", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.approved_c_study, args.room_study, args.reward_study), indent=2))


if __name__ == "__main__":
    main()
