#!/usr/bin/env python3
"""Author a context-first proof of one Room of Days acoustic world.

The candidate family derives every role from the approved C contact, one modal
body bank, one bounded pitch walk, and one close early-reflection fingerprint.
It renders a matched current-family control and a unified-family candidate.
All output is audition-only under ``design/audits``; runtime assets are never
modified.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path
from typing import Iterable

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt


SAMPLE_RATE = 48_000
VARIANT_COUNT = 3
RENDER_VERSION = "room-world-author-v1"
CONTACT_MASTER_ID = "approved-c-contact-v1"
BODY_MASTER_ID = "room-modal-bank-v1"
SPACE_MASTER_ID = "room-close-reflection-v1"
MODAL_RATIOS = (1.0, 1.498, 2.17)
MODAL_DETUNE_CENTS = (0.0, -4.0, 7.0)
SPACE_TAPS = ((22.0, -24.0), (29.0, -29.0), (34.0, -34.0))
PITCH_TOKENS = (
    {"id": "d", "root_hz": 587.330, "up_hz": 659.255, "down_hz": 440.000},
    {"id": "e", "root_hz": 659.255, "up_hz": 739.989, "down_hz": 493.883},
    {"id": "a", "root_hz": 440.000, "up_hz": 493.883, "down_hz": 329.628},
)
ROLE_TARGET_DBFS = {
    "open": -30.0,
    "select": -29.2,
    "navigate": -28.2,
    "place": -27.6,
    "complete-bloom": -25.4,
}
ROLE_DURATIONS = {
    "open": 0.052,
    "select": 0.065,
    "navigate": 0.082,
    "place": 0.118,
    "complete-bloom": 0.205,
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _db(value: float) -> float:
    return 10 ** (value / 20)


def _filter(
    audio: np.ndarray,
    *,
    highpass_hz: float | None = None,
    lowpass_hz: float | None = None,
    order: int = 3,
) -> np.ndarray:
    result = audio
    if highpass_hz is not None:
        result = sosfilt(
            butter(order, highpass_hz, btype="highpass", fs=SAMPLE_RATE, output="sos"),
            result,
        )
    if lowpass_hz is not None:
        result = sosfilt(
            butter(order, lowpass_hz, btype="lowpass", fs=SAMPLE_RATE, output="sos"),
            result,
        )
    return result


def _bandpass(audio: np.ndarray, low_hz: float, high_hz: float, order: int = 3) -> np.ndarray:
    return _filter(
        _filter(audio, highpass_hz=low_hz, order=order),
        lowpass_hz=high_hz,
        order=order,
    )


def _read_mono(path: Path) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float64", always_2d=True)
    mono = np.mean(audio, axis=1)
    if rate != SAMPLE_RATE:
        divisor = math.gcd(rate, SAMPLE_RATE)
        mono = resample_poly(mono, SAMPLE_RATE // divisor, rate // divisor)
    return mono.astype(np.float64)


def _fit(audio: np.ndarray, seconds: float) -> np.ndarray:
    frames = round(seconds * SAMPLE_RATE)
    result = np.zeros(frames, dtype=np.float64)
    result[: min(frames, len(audio))] = audio[:frames]
    return result


def _place(base: np.ndarray, audio: np.ndarray, at_seconds: float, gain: float = 1.0) -> None:
    start = round(at_seconds * SAMPLE_RATE)
    if start >= len(base):
        return
    end = min(len(base), start + len(audio))
    base[start:end] += audio[: end - start] * gain


def _normalize_peak(audio: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(audio))) or 1.0
    return audio / peak


def _phone_rms(audio: np.ndarray) -> float:
    probe = _filter(audio, highpass_hz=260, lowpass_hz=8_000, order=2)
    return float(np.sqrt(np.mean(probe * probe))) if len(probe) else 0.0


def _contact_master(approved_c: np.ndarray) -> np.ndarray:
    frames = round(0.014 * SAMPLE_RATE)
    contact = _fit(approved_c, frames / SAMPLE_RATE)
    contact = _filter(contact, highpass_hz=180, lowpass_hz=6_200, order=3)
    # Preserve C's immediate onset, then turn its first mechanism gesture into
    # a reusable close-contact master with no old-room or literal-Foley tail.
    fade_start = round(0.0055 * SAMPLE_RATE)
    contact[fade_start:] *= np.cos(
        np.linspace(0, math.pi / 2, len(contact) - fade_start)
    ) ** 2
    contact -= float(np.mean(contact[-max(1, round(0.002 * SAMPLE_RATE)) :]))
    return _normalize_peak(contact)


def _modal_body(
    root_hz: float,
    seconds: float,
    decay_ms: float,
    *,
    seed: int,
    low_support: bool = False,
    drift_cents: float = 0.0,
    excitation_gain: float = 0.18,
) -> np.ndarray:
    # excitation_gain defaults to the locked studies' historical value so
    # existing renders stay byte-identical; polish rounds pass lower values
    # when several bodies stack (summed uncorrelated excitation beds read as
    # a recording noise floor — owner, 2026-08-21).
    frames = round(seconds * SAMPLE_RATE)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    progress = np.minimum(1.0, t / max(seconds * 0.62, 1 / SAMPLE_RATE))
    root_curve = root_hz * 2 ** (drift_cents * progress / 1200)
    root_phase = np.cumsum(2 * math.pi * root_curve / SAMPLE_RATE)
    attack = 1.0 - np.exp(-t / 0.00055)
    amplitudes = (0.48, 0.225, 0.085)
    decay_scales = (1.0, 0.72, 0.48)
    phases = (0.12, 0.81, 1.74)
    body = np.zeros(frames, dtype=np.float64)
    for ratio, detune, amplitude, decay_scale, phase in zip(
        MODAL_RATIOS,
        MODAL_DETUNE_CENTS,
        amplitudes,
        decay_scales,
        phases,
    ):
        tuned_ratio = ratio * 2 ** (detune / 1200)
        body += (
            amplitude
            * np.sin(root_phase * tuned_ratio + phase)
            * attack
            * np.exp(-t / ((decay_ms / 1000) * decay_scale))
        )
    if low_support:
        support = np.sin(root_phase * 0.5 + 0.43)
        support *= attack * np.exp(-t / ((decay_ms / 1000) * 1.12))
        body += support * 0.095
    # A small correlated excitation keeps the modes from reading as clean
    # synthesizer sines or a notification chime.
    excitation = _bandpass(
        np.random.default_rng(seed).standard_normal(frames), 360, 3_000, order=2
    )
    excitation = _normalize_peak(excitation)
    excitation *= attack * np.exp(-t / max(0.003, decay_ms / 1000 * 0.56))
    body += excitation * excitation_gain
    body = _filter(body, highpass_hz=170, lowpass_hz=4_200, order=3)
    return _normalize_peak(body)


def _room_bus(dry: np.ndarray, send: float) -> np.ndarray:
    direct = _filter(dry, highpass_hz=165, lowpass_hz=7_200, order=2)
    reflected = _filter(direct, highpass_hz=210, lowpass_hz=3_000, order=2)
    wet = direct.copy()
    for delay_ms, gain_db in SPACE_TAPS:
        delay = round(delay_ms / 1000 * SAMPLE_RATE)
        if delay >= len(wet):
            continue
        wet[delay:] += reflected[: len(wet) - delay] * _db(gain_db) * send
    return wet


def _park(audio: np.ndarray, fade_ms: float) -> np.ndarray:
    result = audio.copy()
    dc_window = min(len(result), max(1, round(0.004 * SAMPLE_RATE)))
    result -= float(np.mean(result[-dc_window:]))
    fade = min(len(result), max(1, round(fade_ms / 1000 * SAMPLE_RATE)))
    result[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
    return result


def _space_ir() -> np.ndarray:
    ir = np.zeros(round(0.040 * SAMPLE_RATE), dtype=np.float64)
    ir[0] = 1.0
    for delay_ms, gain_db in SPACE_TAPS:
        ir[round(delay_ms / 1000 * SAMPLE_RATE)] = _db(gain_db)
    return ir


def _role_stems(
    role: str,
    token: dict[str, float | str],
    contact: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, float]:
    seconds = ROLE_DURATIONS[role]
    contact_stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    body_stem = np.zeros_like(contact_stem)
    root = float(token["root_hz"])
    up = float(token["up_hz"])
    down = float(token["down_hz"])

    if role == "open":
        _place(contact_stem, contact, 0.0, 0.78)
        _place(body_stem, _modal_body(root, seconds, 20, seed=1_100), 0.0, 0.19)
        _place(body_stem, _modal_body(up, seconds - 0.009, 13, seed=1_120), 0.009, 0.065)
        send = 0.72
    elif role == "select":
        _place(contact_stem, contact, 0.0, 0.88)
        _place(body_stem, _modal_body(root, seconds, 28, seed=1_200), 0.0, 0.235)
        _place(contact_stem, contact, 0.013, 0.075)
        _place(body_stem, _modal_body(down, seconds - 0.013, 17, seed=1_220), 0.013, 0.095)
        send = 0.82
    elif role == "navigate":
        # Preserve approved C's weighted two-stage gesture using the exact same
        # contact master as every other role, then voice it through the shared
        # modal body instead of hiding a full unrelated click underneath.
        _place(contact_stem, contact, 0.0, 0.98)
        _place(contact_stem, contact, 0.006, 0.075)
        _place(body_stem, _modal_body(root, seconds, 34, seed=1_300, drift_cents=-38), 0.0, 0.22)
        _place(body_stem, _modal_body(down, seconds - 0.014, 24, seed=1_320), 0.014, 0.115)
        send = 0.92
    elif role == "place":
        _place(contact_stem, contact, 0.0, 0.91)
        _place(body_stem, _modal_body(down, seconds, 47, seed=1_400, low_support=True, drift_cents=-25), 0.0, 0.31)
        _place(contact_stem, contact, 0.024, 0.055)
        final_root = max(root / 2, 293.665)
        _place(body_stem, _modal_body(final_root, seconds - 0.024, 35, seed=1_420, low_support=True), 0.024, 0.16)
        send = 1.0
    elif role == "complete-bloom":
        # This is the confirmed outcome only. The flow composes it 75 ms after
        # one shared accepted-state contact, preventing an unrelated double hit.
        _place(body_stem, _modal_body(root, seconds, 98, seed=1_500, low_support=True, drift_cents=9), 0.0, 0.43)
        _place(body_stem, _modal_body(root * 1.5, seconds - 0.014, 112, seed=1_520, drift_cents=-7), 0.014, 0.24)
        _place(body_stem, _modal_body(up, seconds - 0.052, 76, seed=1_540), 0.052, 0.065)
        # Slow bloom envelope distinguishes meaning without importing a chime.
        bloom = 1.0 - np.exp(-np.arange(len(body_stem)) / SAMPLE_RATE / 0.0075)
        body_stem *= bloom
        send = 1.12
    else:
        raise ValueError(f"unknown role: {role}")

    release = min(len(body_stem), round((0.016 if role != "complete-bloom" else 0.036) * SAMPLE_RATE))
    body_stem[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    contact_stem[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    return contact_stem, body_stem, send


def _render_family(
    role: str,
    contact: np.ndarray,
) -> tuple[list[np.ndarray], list[np.ndarray], list[np.ndarray]]:
    wet: list[np.ndarray] = []
    dry: list[np.ndarray] = []
    contact_only: list[np.ndarray] = []
    for token in PITCH_TOKENS:
        contact_stem, body_stem, send = _role_stems(role, token, contact)
        raw = contact_stem + body_stem
        fade_ms = 8.0 if role == "complete-bloom" else 5.0
        dry.append(_park(_room_bus(raw, 0.0), fade_ms))
        contact_only.append(_park(_room_bus(contact_stem, 0.0), fade_ms))
        wet.append(_park(_room_bus(raw, send), fade_ms))

    energies = [_phone_rms(audio) for audio in wet]
    target = _db(ROLE_TARGET_DBFS[role])
    scaled_wet: list[np.ndarray] = []
    scaled_dry: list[np.ndarray] = []
    scaled_contacts: list[np.ndarray] = []
    for index, audio in enumerate(wet):
        gain = target / max(energies[index], 1e-12)
        peak = float(np.max(np.abs(audio * gain)))
        if peak > _db(-6.0):
            gain *= _db(-6.0) / peak
        scaled_wet.append(audio * gain)
        scaled_dry.append(dry[index] * gain)
        scaled_contacts.append(contact_only[index] * gain)
    return scaled_wet, scaled_dry, scaled_contacts


def _sequence(
    families: dict[str, list[np.ndarray]],
    *,
    complete_bloom: list[np.ndarray],
) -> tuple[np.ndarray, list[dict[str, object]]]:
    timeline = [
        (0.30, "navigate", 0),
        (1.05, "open", 1),
        (1.72, "select", 2),
        (2.18, "select", 0),
        (2.92, "place", 1),
        (3.75, "navigate", 2),
        (4.55, "open", 0),
        (5.30, "select", 1),
        (5.375, "complete-bloom", 1),
    ]
    result = np.zeros(round(6.10 * SAMPLE_RATE), dtype=np.float64)
    evidence: list[dict[str, object]] = []
    for at, role, variant in timeline:
        audio = complete_bloom[variant] if role == "complete-bloom" else families[role][variant]
        _place(result, audio, at)
        evidence.append({"at_seconds": at, "role": role, "variant": variant + 1})
    return result, evidence


def _load_control_assets(control_root: Path, streak_path: Path) -> dict[str, list[np.ndarray]]:
    assets: dict[str, list[np.ndarray]] = {
        "navigate": [_read_mono(control_root / "roles" / "navigate-dak" / f"{i}.wav") for i in range(1, 4)],
        "open": [_read_mono(control_root / "roles" / "open-tak" / f"{i}.wav") for i in range(1, 4)],
        "select": [_read_mono(control_root / "roles" / "select-tuk" / f"{i}.wav") for i in range(1, 4)],
        "place": [_read_mono(streak_path)] * 3,
        "complete-bloom": [_read_mono(control_root / "roles" / "complete-bloop" / "current.wav")] * 3,
    }
    # Give the control the exact same semantic loudness ladder as the candidate.
    # This preserves its old timbres/envelopes while preventing a raw export or
    # runtime gain difference from deciding the cohesion comparison.
    calibrated: dict[str, list[np.ndarray]] = {}
    for role, variants in assets.items():
        target = _db(ROLE_TARGET_DBFS[role])
        calibrated[role] = []
        for audio in variants:
            gain = target / max(_phone_rms(audio), 1e-12)
            peak = float(np.max(np.abs(audio * gain)))
            if peak > _db(-6.0):
                gain *= _db(-6.0) / peak
            calibrated[role].append(audio * gain)
    return calibrated


def _control_sequence(assets: dict[str, list[np.ndarray]]) -> tuple[np.ndarray, list[dict[str, object]]]:
    return _sequence(assets, complete_bloom=assets["complete-bloom"])


def _matched_pair(control: np.ndarray, candidate: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    target = min(_phone_rms(control), _phone_rms(candidate))
    return (
        control * target / max(_phone_rms(control), 1e-12),
        candidate * target / max(_phone_rms(candidate), 1e-12),
    )


def _fatigue_sequence(families: dict[str, list[np.ndarray]]) -> tuple[np.ndarray, list[dict[str, object]]]:
    pattern = ("open", "select", "navigate", "open", "select", "place") * 3
    step = 0.125
    result = np.zeros(round(2.58 * SAMPLE_RATE), dtype=np.float64)
    timeline: list[dict[str, object]] = []
    for index, role in enumerate(pattern):
        at = 0.16 + index * step
        variant = index % VARIANT_COUNT
        gain = 1.0 if index == 0 else 0.93 if index < 3 else 0.885
        _place(result, families[role][variant], at, gain)
        timeline.append(
            {
                "at_seconds": at,
                "role": role,
                "variant": variant + 1,
                "rate_gain": gain,
            }
        )
    return result, timeline


def _lineage_reel(items: Iterable[np.ndarray], spacing: float = 0.34) -> np.ndarray:
    items = list(items)
    length = spacing * max(0, len(items) - 1) + max((len(item) for item in items), default=0) / SAMPLE_RATE + 0.12
    reel = np.zeros(round(length * SAMPLE_RATE), dtype=np.float64)
    for index, audio in enumerate(items):
        _place(reel, audio, index * spacing)
    return reel


def _write(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    if peak >= 1.0:
        audio = audio * (_db(-0.3) / peak)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def build_study(
    output: Path,
    approved_c_root: Path,
    control_root: Path,
    streak_path: Path,
) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    approved_paths = [approved_c_root / "variants" / f"dak-c-{i}.wav" for i in range(1, 4)]
    for path in approved_paths:
        if not path.exists():
            raise FileNotFoundError(path)
    approved = [_read_mono(path) for path in approved_paths]
    contact = _contact_master(approved[0])
    _write(output / "shared" / "contact-master.wav", contact)
    _write(output / "shared" / "space-fingerprint-ir.wav", _space_ir())
    approved_anchor_target = output / "diagnostics" / "approved-c-anchor.wav"
    approved_anchor_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(approved_paths[0], approved_anchor_target)
    if _sha256(approved_paths[0]) != _sha256(approved_anchor_target):
        raise RuntimeError("approved C anchor changed during diagnostic copy")

    roles = ("open", "select", "navigate", "place", "complete-bloom")
    wet_families: dict[str, list[np.ndarray]] = {}
    dry_families: dict[str, list[np.ndarray]] = {}
    contact_families: dict[str, list[np.ndarray]] = {}
    role_manifest: dict[str, object] = {}
    for role in roles:
        wet, dry, contacts = _render_family(role, contact)
        wet_families[role] = wet
        dry_families[role] = dry
        contact_families[role] = contacts
        paths: list[str] = []
        dry_paths: list[str] = []
        for index in range(VARIANT_COUNT):
            target = output / "roles" / role / f"{index + 1}.wav"
            dry_target = output / "diagnostics" / "bus-bypass" / role / f"{index + 1}.wav"
            _write(target, wet[index])
            _write(dry_target, dry[index])
            paths.append(target.relative_to(output).as_posix())
            dry_paths.append(dry_target.relative_to(output).as_posix())
        role_manifest[role] = {
            "variant_paths": paths,
            "bus_bypass_paths": dry_paths,
            "duration_ms": ROLE_DURATIONS[role] * 1000,
            "natural_phone_rms_target_dbfs": ROLE_TARGET_DBFS[role],
            "derivation": {
                "render_version": RENDER_VERSION,
                "contact_master_id": CONTACT_MASTER_ID if role != "complete-bloom" else None,
                "body_master_id": BODY_MASTER_ID,
                "space_fingerprint_id": SPACE_MASTER_ID,
                "variant_axis": "global_phrase_token",
                "pitch_tokens": [token["id"] for token in PITCH_TOKENS],
            },
        }

    candidate_flow, timeline = _sequence(
        wet_families, complete_bloom=wet_families["complete-bloom"]
    )
    dry_flow, _ = _sequence(
        dry_families, complete_bloom=dry_families["complete-bloom"]
    )
    control_assets = _load_control_assets(control_root, streak_path)
    control_flow, control_timeline = _control_sequence(control_assets)
    matched_control, matched_candidate = _matched_pair(control_flow, candidate_flow)

    candidate_fatigue, fatigue_timeline = _fatigue_sequence(wet_families)
    control_fatigue, _ = _fatigue_sequence(control_assets)
    matched_control_fatigue, matched_candidate_fatigue = _matched_pair(
        control_fatigue, candidate_fatigue
    )

    flow_paths = {
        "control_natural": "flows/control-current-natural.wav",
        "candidate_natural": "flows/candidate-room-natural.wav",
        "control_matched": "flows/control-current-level-matched.wav",
        "candidate_matched": "flows/candidate-room-level-matched.wav",
        "candidate_bus_bypass": "flows/candidate-room-bus-bypass.wav",
        "control_fatigue": "flows/control-current-fatigue-matched.wav",
        "candidate_fatigue": "flows/candidate-room-fatigue-matched.wav",
    }
    _write(output / flow_paths["control_natural"], control_flow)
    _write(output / flow_paths["candidate_natural"], candidate_flow)
    _write(output / flow_paths["control_matched"], matched_control)
    _write(output / flow_paths["candidate_matched"], matched_candidate)
    _write(output / flow_paths["candidate_bus_bypass"], dry_flow)
    _write(output / flow_paths["control_fatigue"], matched_control_fatigue)
    _write(output / flow_paths["candidate_fatigue"], matched_candidate_fatigue)

    contact_reel = _lineage_reel(
        [contact_families[role][0] for role in ("open", "select", "navigate", "place")]
    )
    body_reel = _lineage_reel(
        [
            dry_families[role][0] - contact_families[role][0]
            for role in ("open", "select", "navigate", "place", "complete-bloom")
        ]
    )
    _write(output / "diagnostics" / "contact-lineage.wav", contact_reel)
    _write(output / "diagnostics" / "body-lineage.wav", body_reel)

    control_input_paths = [
        control_root / "roles" / role / f"{index}.wav"
        for role in ("navigate-dak", "open-tak", "select-tuk")
        for index in range(1, 4)
    ] + [
        control_root / "roles" / "complete-bloop" / "current.wav",
        streak_path,
    ]
    audio_hashes = {
        path.relative_to(output).as_posix(): _sha256(path)
        for path in sorted(output.rglob("*.wav"))
    }
    manifest = {
        "study": "room-sonic-world-v1",
        "question": "Does the unified sequence feel like one Room while its verbs remain distinct?",
        "runtime_changed": False,
        "render_contract": {
            "render_version": RENDER_VERSION,
            "contact_master": {
                "id": CONTACT_MASTER_ID,
                "path": "shared/contact-master.wav",
                "source": "first approved C mechanism, shaped to a 14 ms reusable contact",
                "source_path": str(approved_paths[0].resolve()),
                "source_sha256": _sha256(approved_paths[0]),
                "approved_anchor_family": {
                    str(path.resolve()): _sha256(path) for path in approved_paths
                },
            },
            "body_master": {
                "id": BODY_MASTER_ID,
                "modal_ratios": list(MODAL_RATIOS),
                "modal_detune_cents": list(MODAL_DETUNE_CENTS),
                "pitch_hypothesis": "D-major pentatonic; pending physical-device audition",
            },
            "space_fingerprint": {
                "id": SPACE_MASTER_ID,
                "path": "shared/space-fingerprint-ir.wav",
                "taps": [
                    {"delay_ms": delay, "gain_db": gain}
                    for delay, gain in SPACE_TAPS
                ],
                "feedback": 0,
                "reflection_lowpass_hz": 3000,
            },
            "permitted_variant_axis": "global_phrase_token only",
        },
        "roles": role_manifest,
        "audition": {
            "timeline": timeline,
            "control_timeline": control_timeline,
            "flow_paths": flow_paths,
            "level_control_order": "randomized first by the browser per session",
            "natural_order": "randomized independently after the level-controlled verdict",
            "hierarchy_control": "Both systems use the same per-role phone-band RMS targets; the level-control pass additionally matches whole-sequence energy.",
            "first_gate": "Which sequence feels more like one Room, if either?",
            "second_gate": "Do open, select, navigate, place, and complete remain distinguishable?",
            "diagnostics": {
                "contacts": "diagnostics/contact-lineage.wav",
                "bodies": "diagnostics/body-lineage.wav",
                "bus_bypass": flow_paths["candidate_bus_bypass"],
                "approved_c_anchor": "diagnostics/approved-c-anchor.wav",
                "fatigue_control": flow_paths["control_fatigue"],
                "fatigue_candidate": flow_paths["candidate_fatigue"],
                "fatigue_timeline": fatigue_timeline,
            },
        },
        "provenance": {
            "reference_video_audio_used": False,
            "shipping_assets_changed": False,
            "control_sources": {
                str(path.resolve()): _sha256(path) for path in control_input_paths
            },
        },
        "generated_audio_sha256": audio_hashes,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--approved-c-study", type=Path, required=True)
    parser.add_argument("--control-study", type=Path, required=True)
    parser.add_argument("--current-streak", type=Path, required=True)
    args = parser.parse_args()
    print(
        json.dumps(
            build_study(
                args.output,
                args.approved_c_study,
                args.control_study,
                args.current_streak,
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
