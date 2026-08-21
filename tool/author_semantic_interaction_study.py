#!/usr/bin/env python3
"""Author a role-first interaction sound study for Room of Days.

This study corrects the previous material/finish framing.  It preserves the
approved C click byte-for-byte as the navigation ``dak`` and the current app
completion cue byte-for-byte as the earned ``bloop``.  It authors two genuinely
different everyday voices between them:

* ``open_tak``: a short, dry opening/button contact;
* ``select_tuk``: a rounder choice-settling contact with a tiny closure.

All output is audition-only under ``design/audits``.  The tool never edits
runtime assets or sound routing.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly


TOOL_ROOT = Path(__file__).resolve().parent
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))
import author_weighted_click_study as anchor  # noqa: E402


SAMPLE_RATE = 48_000
OVERSAMPLE = 4
VARIANT_COUNT = 5
TAK_SECONDS = 0.038
TUK_SECONDS = 0.050

# These are deliberately more audible than C's sub-semitonal body drift.  The
# role remains stable because only the short damped body moves; contact shape
# and timing do not.
TAK_CENTS = (0.0, 125.0, -90.0, 180.0, 60.0)
TUK_CENTS = (0.0, 110.0, -90.0, 190.0, 45.0)
VARIANT_WALK = (0, 2, 1, 4, 3, 1, 0, 4, 2, 3, 0, 1)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _attack_decay(t: np.ndarray, attack_s: float, decay_s: float) -> np.ndarray:
    return (1.0 - np.exp(-t / attack_s)) * np.exp(-t / decay_s)


def _noise(seed: int, length: int, rate: int, low_hz: float, high_hz: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return anchor._normalize_peak(
        anchor._bandpass(rng.standard_normal(length), rate, low_hz, high_hz, order=3)
    )


def _modal_body(
    t: np.ndarray,
    root_hz: float,
    ratios: tuple[float, ...],
    amplitudes: tuple[float, ...],
    decays_ms: tuple[float, ...],
    phases: tuple[float, ...],
) -> np.ndarray:
    attack = 1.0 - np.exp(-t / 0.00016)
    body = np.zeros_like(t)
    for ratio, amplitude, decay_ms, phase in zip(ratios, amplitudes, decays_ms, phases):
        body += (
            amplitude
            * np.sin(2 * math.pi * root_hz * ratio * t + phase)
            * attack
            * np.exp(-t / (decay_ms / 1000))
        )
    return anchor._normalize_peak(body)


def _finish_click(audio: np.ndarray, duration_s: float, *, release_ms: float) -> np.ndarray:
    rate = SAMPLE_RATE * OVERSAMPLE
    audio = anchor._filter(audio, rate, highpass_hz=220, lowpass_hz=9_200, order=3)
    release = min(len(audio), round(release_ms / 1000 * rate))
    audio[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    audio = resample_poly(audio, 1, OVERSAMPLE, window=("kaiser", 9.0))
    audio = audio[: round(duration_s * SAMPLE_RATE)]
    # Remove any residual conversion offset using only the parked tail.
    tail = max(1, round(0.006 * SAMPLE_RATE))
    audio -= float(np.mean(audio[-tail:]))
    return audio.astype(np.float64)


def synth_open_tak_raw(variant: int) -> np.ndarray:
    if variant not in range(VARIANT_COUNT):
        raise ValueError(f"variant must be 0..{VARIANT_COUNT - 1}")
    rate = SAMPLE_RATE * OVERSAMPLE
    frames = round(TAK_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate
    pitch = 2 ** (TAK_CENTS[variant] / 1200)

    contact = _noise(20_268_210 + variant * 109, frames, rate, 1_720, 7_650)
    contact *= _attack_decay(t, 0.000075, 0.00155)
    lower_contact = _noise(20_268_240 + variant * 113, frames, rate, 760, 3_350)
    lower_contact *= _attack_decay(t, 0.00011, 0.00245)

    body = _modal_body(
        t,
        1_320 * pitch,
        (1.0, 1.49, 2.31),
        (0.62, 0.255, 0.105),
        (6.3, 3.8, 2.15),
        (0.17, 0.92, 1.81),
    )
    texture = _noise(20_268_270 + variant * 127, frames, rate, 960, 4_450)
    texture *= _attack_decay(t, 0.00015, 0.0037)

    audio = contact * 0.60 + lower_contact * 0.25 + body * 0.165 + texture * 0.075
    return _finish_click(audio, TAK_SECONDS, release_ms=12.0)


def synth_select_tuk_raw(variant: int) -> np.ndarray:
    if variant not in range(VARIANT_COUNT):
        raise ValueError(f"variant must be 0..{VARIANT_COUNT - 1}")
    rate = SAMPLE_RATE * OVERSAMPLE
    frames = round(TUK_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate
    pitch = 2 ** (TUK_CENTS[variant] / 1200)

    contact = _noise(20_268_510 + variant * 131, frames, rate, 720, 4_850)
    contact *= _attack_decay(t, 0.00011, 0.00235)
    body = _modal_body(
        t,
        720 * pitch,
        (1.0, 1.56, 2.38),
        (0.62, 0.265, 0.115),
        (9.4, 6.0, 3.6),
        (0.10, 0.78, 1.58),
    )
    texture = _noise(20_268_540 + variant * 137, frames, rate, 360, 2_650)
    texture *= _attack_decay(t, 0.00018, 0.0061)

    local = t - 0.011
    active = local >= 0
    local = np.maximum(local, 0.0)
    closure = _noise(20_268_570 + variant * 139, frames, rate, 520, 2_900)
    closure *= active * _attack_decay(local, 0.00009, 0.00135)

    audio = contact * 0.47 + body * 0.285 + texture * 0.125 + closure * 0.060
    return _finish_click(audio, TUK_SECONDS, release_ms=17.0)


def _calibrate_family(raw: list[np.ndarray], peak_dbfs: float) -> list[np.ndarray]:
    energies = [anchor._phone_band_rms(audio) for audio in raw]
    target = sum(energies) / len(energies)
    balanced = [audio * target / (energy or 1.0) for audio, energy in zip(raw, energies)]
    ceiling = 10 ** (peak_dbfs / 20)
    common_peak = max(float(np.max(np.abs(audio))) for audio in balanced) or 1.0
    gain = ceiling / common_peak
    return [audio * gain for audio in balanced]


def render_open_tak() -> list[np.ndarray]:
    return _calibrate_family(
        [synth_open_tak_raw(index) for index in range(VARIANT_COUNT)], -9.5
    )


def render_select_tuk() -> list[np.ndarray]:
    return _calibrate_family(
        [synth_select_tuk_raw(index) for index in range(VARIANT_COUNT)], -9.0
    )


def _read_for_flow(path: Path) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float64", always_2d=True)
    mono = np.mean(audio, axis=1)
    if rate != SAMPLE_RATE:
        divisor = math.gcd(rate, SAMPLE_RATE)
        mono = resample_poly(mono, SAMPLE_RATE // divisor, rate // divisor)
    return mono


def _place(base: np.ndarray, audio: np.ndarray, at_seconds: float, gain: float = 1.0) -> None:
    start = round(at_seconds * SAMPLE_RATE)
    end = min(len(base), start + len(audio))
    if end > start:
        base[start:end] += audio[: end - start] * gain


def build_study(output: Path, approved_c_root: Path, current_complete: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    navigate_root = output / "roles" / "navigate-dak"
    tak_root = output / "roles" / "open-tak"
    tuk_root = output / "roles" / "select-tuk"
    complete_root = output / "roles" / "complete-bloop"
    for root in (navigate_root, tak_root, tuk_root, complete_root):
        root.mkdir(parents=True, exist_ok=True)

    navigate_paths: list[str] = []
    navigate_hashes: dict[str, str] = {}
    for index in range(VARIANT_COUNT):
        source = approved_c_root / "variants" / f"dak-c-{index + 1}.wav"
        if not source.exists():
            raise FileNotFoundError(f"approved C variant missing: {source}")
        target = navigate_root / f"{index + 1}.wav"
        shutil.copyfile(source, target)
        if _sha256(source) != _sha256(target):
            raise RuntimeError(f"approved C changed during copy: {source}")
        relative = target.relative_to(output).as_posix()
        navigate_paths.append(relative)
        navigate_hashes[relative] = _sha256(target)

    if not current_complete.exists():
        raise FileNotFoundError(f"current completion cue missing: {current_complete}")
    completion_target = complete_root / "current.wav"
    shutil.copyfile(current_complete, completion_target)
    if _sha256(current_complete) != _sha256(completion_target):
        raise RuntimeError("current completion cue changed during copy")

    tak = render_open_tak()
    tuk = render_select_tuk()
    tak_paths: list[str] = []
    tuk_paths: list[str] = []
    for index, audio in enumerate(tak):
        target = tak_root / f"{index + 1}.wav"
        anchor.write_wav(target, audio, seed=20_269_000 + index)
        tak_paths.append(target.relative_to(output).as_posix())
    for index, audio in enumerate(tuk):
        target = tuk_root / f"{index + 1}.wav"
        anchor.write_wav(target, audio, seed=20_269_100 + index)
        tuk_paths.append(target.relative_to(output).as_posix())

    completion = _read_for_flow(completion_target)
    # A representative click-around flow: move, open, select twice, open, then
    # a small accepted-state contact followed 65 ms later by the current bloop.
    navigate = [_read_for_flow(output / path) for path in navigate_paths]
    flow = np.zeros(round(3.05 * SAMPLE_RATE), dtype=np.float64)
    _place(flow, navigate[0], 0.18)
    _place(flow, tak[0], 0.72)
    _place(flow, tuk[0], 1.18, 0.90)
    _place(flow, tuk[2], 1.47, 0.86)
    _place(flow, tak[2], 1.92)
    _place(flow, tuk[1], 2.38, 0.88)
    _place(flow, completion, 2.445)
    peak = float(np.max(np.abs(flow))) or 1.0
    if peak > 10 ** (-5.5 / 20):
        flow *= 10 ** (-5.5 / 20) / peak
    anchor.write_wav(output / "normal-flow.wav", flow, seed=20_269_400)

    completion_info = sf.info(completion_target)
    manifest = {
        "study": "semantic-interaction-voices-v1",
        "question": "Do these sound like four distinct, satisfying interaction verbs?",
        "runtime_changed": False,
        "roles": {
            "navigate-dak": {
                "label": "Switch page",
                "voice": "dak",
                "use": "accepted page, tab, major section, or calendar period/view traversal",
                "variant_paths": navigate_paths,
                "copied_byte_for_byte_from_approved_c": True,
                "sha256": navigate_hashes,
            },
            "open-tak": {
                "label": "Open journal entry",
                "voice": "tak",
                "use": "open a card, entry, sheet, or ordinary light button",
                "variant_paths": tak_paths,
                "duration_ms": TAK_SECONDS * 1000,
                "pitch_offsets_cents": list(TAK_CENTS),
            },
            "select-tuk": {
                "label": "Choose a date",
                "voice": "tuk",
                "use": "a toggle, date, filter, pin, or small state visibly settles",
                "variant_paths": tuk_paths,
                "duration_ms": TUK_SECONDS * 1000,
                "pitch_offsets_cents": list(TUK_CENTS),
            },
            "complete-bloop": {
                "label": "Finish quest",
                "voice": "bloop",
                "use": "confirmed quest or routine completion only",
                "path": completion_target.relative_to(output).as_posix(),
                "copied_byte_for_byte_from_current_runtime": True,
                "sha256": _sha256(completion_target),
                "sample_rate_hz": completion_info.samplerate,
                "sample_format": completion_info.subtype,
                "duration_ms": round(completion_info.duration * 1000, 3),
                "after_contact_delay_ms": 65,
            },
        },
        "variant_walk": list(VARIANT_WALK),
        "flow_path": "normal-flow.wav",
        "silence_contract": [
            "already-selected tab",
            "scroll, typing, loading, and passive preview",
            "cancel or not-now",
            "background sync and most network errors",
        ],
    }
    metrics = {
        "navigate_dak": [
            anchor._metrics(audio, click_aligned=True) for audio in navigate
        ],
        "open_tak": [anchor._metrics(audio, click_aligned=True) for audio in tak],
        "select_tuk": [anchor._metrics(audio, click_aligned=True) for audio in tuk],
        "complete_bloop": {
            "duration_seconds": completion_info.duration,
            "sample_rate_hz": completion_info.samplerate,
            "channels": completion_info.channels,
            "subtype": completion_info.subtype,
            "sha256": _sha256(completion_target),
        },
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--approved-c-study", type=Path, required=True)
    parser.add_argument("--current-complete", type=Path, required=True)
    args = parser.parse_args()
    print(
        json.dumps(
            build_study(args.output, args.approved_c_study, args.current_complete),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
