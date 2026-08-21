#!/usr/bin/env python3
"""Build audition-only hearth fwooshes from licensed fire recordings.

This deliberately does not write into ``assets/sfx``.  It is a listening tool
for shaping one satisfying ignition gesture before a runtime asset is chosen.
The user's Krotos example is analysis-only and is never mixed into an output.
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy.interpolate import PchipInterpolator
from scipy.signal import butter, sosfiltfilt


SAMPLE_RATE = 48_000


def decode(path: Path) -> np.ndarray:
    completed = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
            "-ac", "2", "-ar", str(SAMPLE_RATE), "-f", "f32le", "pipe:1",
        ],
        check=True,
        capture_output=True,
    )
    audio = np.frombuffer(completed.stdout, dtype="<f4").astype(np.float64)
    return audio.reshape(-1, 2)


def write_wav(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(audio, -1, 1)
    pcm = np.round(pcm * 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def crop(audio: np.ndarray, start: float, end: float) -> np.ndarray:
    return audio[round(start * SAMPLE_RATE):round(end * SAMPLE_RATE)].copy()


def fit(audio: np.ndarray, seconds: float) -> np.ndarray:
    target = round(seconds * SAMPLE_RATE)
    if len(audio) == target:
        return audio.copy()
    old = np.linspace(0.0, 1.0, len(audio), endpoint=False)
    new = np.linspace(0.0, 1.0, target, endpoint=False)
    return np.column_stack([
        np.interp(new, old, audio[:, channel]) for channel in range(audio.shape[1])
    ])


def filtered(audio: np.ndarray, low: float, high: float) -> np.ndarray:
    nyquist = SAMPLE_RATE / 2
    low = max(12.0, low)
    high = min(nyquist * 0.98, high)
    sos = butter(3, [low / nyquist, high / nyquist], btype="bandpass", output="sos")
    return sosfiltfilt(sos, audio, axis=0)


def rms(audio: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(audio))))


def mono(audio: np.ndarray) -> np.ndarray:
    return np.mean(audio, axis=1)


def band_balance(signal: np.ndarray, flavor: str) -> np.ndarray:
    """Aim at the reference's low-mid pressure, without a static pitched hum."""
    if signal.ndim == 1:
        signal = signal[:, None]
    if signal.shape[1] == 1:
        signal = np.repeat(signal, 2, axis=1)

    # Relative RMS targets, referenced to the 120-300 Hz pressure body.
    targets = {
        "soft": ((65, 120, -10.0), (120, 300, 0.0), (300, 1_000, -13.0),
                 (1_000, 3_000, -28.0), (3_000, 8_000, -33.0)),
        "alive": ((65, 120, -9.0), (120, 300, 0.0), (300, 1_000, -10.5),
                  (1_000, 3_000, -25.0), (3_000, 8_000, -29.5)),
        "round": ((65, 120, -11.0), (120, 300, 0.0), (300, 1_000, -12.0),
                  (1_000, 3_000, -27.0), (3_000, 8_000, -32.0)),
    }[flavor]

    result = np.zeros_like(signal)
    for low, high, target_db in targets:
        band = filtered(signal, low, high)
        level = rms(band)
        if level > 1e-8:
            result += band / level * (10 ** (target_db / 20))
    return result


def macro_envelope(length: int, variant: str) -> np.ndarray:
    duration = length / SAMPLE_RATE
    if variant == "patient":
        points = (
            (0.00, 0.000), (0.08, 0.012), (0.28, 0.055), (0.34, 0.10),
            (0.65, 0.50), (0.84, 0.82), (0.93, 1.00), (1.02, 0.83),
            (1.18, 0.53), (1.40, 0.18), (1.60, 0.015), (duration, 0.0),
        )
    elif variant == "lively":
        points = (
            (0.00, 0.000), (0.06, 0.015), (0.23, 0.065), (0.30, 0.10),
            (0.58, 0.50), (0.78, 0.84), (0.87, 1.00), (0.97, 0.79),
            (1.11, 0.58), (1.35, 0.17), (1.56, 0.012), (duration, 0.0),
        )
    else:
        points = (
            (0.00, 0.000), (0.10, 0.010), (0.30, 0.060), (0.37, 0.10),
            (0.68, 0.50), (0.88, 0.86), (0.96, 1.00), (1.06, 0.80),
            (1.22, 0.46), (1.43, 0.14), (1.62, 0.010), (duration, 0.0),
        )
    x, y = zip(*points)
    timeline = np.arange(length) / SAMPLE_RATE
    env = PchipInterpolator(x, y)(np.clip(timeline, 0, duration))

    # Two uneven pressure ripples at the crest. They are amplitude movement in
    # recorded fire, not added tones.
    crest_window = np.exp(-0.5 * ((timeline - 0.94) / 0.17) ** 2)
    ripple = 1 + crest_window * (
        0.045 * np.sin(2 * math.pi * 8.1 * timeline + 0.4)
        + 0.025 * np.sin(2 * math.pi * 13.7 * timeline + 1.7)
    )
    return np.clip(env * ripple, 0, None)


def with_width(mid: np.ndarray, side_source: np.ndarray, side_db: float) -> np.ndarray:
    side = (side_source[:, 0] - side_source[:, 1]) * 0.5
    side -= float(np.mean(side))
    mid_level = rms(mid)
    side_level = rms(side)
    if side_level > 1e-8:
        side *= mid_level * (10 ** (side_db / 20)) / side_level
    return np.column_stack((mid + side, mid - side))


def finish(audio: np.ndarray, peak_dbfs: float = -5.0) -> np.ndarray:
    audio -= np.mean(audio, axis=0, keepdims=True)
    peak = float(np.max(np.abs(audio)))
    if peak:
        audio *= (10 ** (peak_dbfs / 20)) / peak
    fade_in = round(0.012 * SAMPLE_RATE)
    fade_out = round(0.065 * SAMPLE_RATE)
    audio[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    audio[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    return audio


def fireplace_tail(fireplace: np.ndarray, seconds: float, start: float) -> np.ndarray:
    tail = fit(crop(fireplace, start, start + seconds + 0.2), seconds)
    tail = filtered(tail, 90, 3_800)
    timeline = np.arange(len(tail)) / SAMPLE_RATE
    env = np.interp(
        timeline,
        [0.0, 0.34, 0.75, 1.10, seconds],
        [0.0, 0.035, 0.12, 0.09, 0.0],
    )
    level = rms(tail)
    return tail / max(level, 1e-8) * env[:, None]


def make_candidates(
    bursts: np.ndarray,
    loop: np.ndarray,
    ignition: np.ndarray,
    fireplace: np.ndarray,
) -> dict[str, np.ndarray]:
    seconds = 1.70
    length = round(seconds * SAMPLE_RATE)

    # A: one real performed burst, with a second take ghosting the crest. This
    # is the closest structural match to the softer reference examples.
    burst_a = fit(crop(bursts, 2.10, 4.06), seconds)
    burst_b = fit(crop(bursts, 5.77, 8.25), seconds)
    raw_a = burst_a * 0.86 + np.roll(burst_b, round(0.035 * SAMPLE_RATE), axis=0) * 0.14
    body_a = mono(band_balance(raw_a, "soft"))
    env_a = macro_envelope(length, "patient")
    tail_a = fireplace_tail(fireplace, seconds, 20.0)
    mid_a = body_a * env_a + mono(tail_a) * 0.055
    side_a = fit(crop(loop, 2.0, 3.8), seconds) * env_a[:, None] + tail_a * 0.12
    side_a = band_balance(side_a, "soft") * env_a[:, None]
    candidate_a = finish(with_width(mid_a, side_a, -9.0), -5.2)

    # B: a slightly more animated stereo flame body. It retains a touch more
    # upper turbulence, but remains far below notification-like brightness.
    loop_b = fit(crop(loop, 4.1, 5.9), seconds)
    burst_c = fit(crop(bursts, 9.91, 13.79), seconds)
    raw_b = loop_b * 0.68 + burst_c * 0.32
    balanced_b = band_balance(raw_b, "alive")
    mid_b_source = mono(balanced_b)
    env_b = macro_envelope(length, "lively")
    tail_b = fireplace_tail(fireplace, seconds, 31.0)
    mid_b = mid_b_source * env_b + mono(tail_b) * 0.045
    side_b = balanced_b * env_b[:, None] + tail_b * 0.10
    candidate_b = finish(with_width(mid_b, side_b, -8.3), -5.5)

    # C: a rounder hearth ignition built around the older real flare recording,
    # with the new performed burst supplying the missing 120-1000 Hz movement.
    flare_c = fit(ignition, seconds)
    burst_d = fit(crop(bursts, 15.08, 20.71), seconds)
    raw_c = flare_c * 0.58 + burst_d * 0.42
    balanced_c = band_balance(raw_c, "round")
    env_c = macro_envelope(length, "round")
    tail_c = fireplace_tail(fireplace, seconds, 42.0)
    mid_c = mono(balanced_c) * env_c + mono(tail_c) * 0.070
    side_c = balanced_c * env_c[:, None] + tail_c * 0.16
    candidate_c = finish(with_width(mid_c, side_c, -9.5), -5.0)

    return {
        "fwoosh-a-warm-pressure.wav": candidate_a,
        "fwoosh-b-living-flame.wav": candidate_b,
        "fwoosh-c-hearth-bloom.wav": candidate_c,
    }


def moving_rms(audio: np.ndarray, milliseconds: float = 35) -> np.ndarray:
    signal = mono(audio)
    window = max(1, round(milliseconds / 1000 * SAMPLE_RATE))
    kernel = np.ones(window) / window
    return np.sqrt(np.convolve(signal * signal, kernel, mode="same"))


def metrics(audio: np.ndarray) -> dict[str, float | dict[str, float]]:
    mid = (audio[:, 0] + audio[:, 1]) * 0.5
    side = (audio[:, 0] - audio[:, 1]) * 0.5
    bands = {
        "65_120": rms(filtered(audio, 65, 120)),
        "120_300": rms(filtered(audio, 120, 300)),
        "300_1000": rms(filtered(audio, 300, 1_000)),
        "1000_3000": rms(filtered(audio, 1_000, 3_000)),
        "3000_8000": rms(filtered(audio, 3_000, 8_000)),
    }
    body = max(bands["120_300"], 1e-12)
    relative = {
        name: round(20 * math.log10(max(value, 1e-12) / body), 2)
        for name, value in bands.items()
    }
    envelope = moving_rms(audio)
    peak_index = int(np.argmax(envelope))
    peak = max(float(envelope[peak_index]), 1e-12)
    rise = {}
    for threshold in (0.1, 0.5, 0.9):
        hits = np.flatnonzero(envelope[:peak_index + 1] >= peak * threshold)
        rise[str(threshold)] = round((hits[0] if len(hits) else 0) / SAMPLE_RATE, 3)
    return {
        "duration_s": round(len(audio) / SAMPLE_RATE, 3),
        "peak_dbfs": round(20 * math.log10(max(float(np.max(np.abs(audio))), 1e-12)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms(audio), 1e-12)), 2),
        "crest_s": round(peak_index / SAMPLE_RATE, 3),
        "rise_s": rise,
        "bands_relative_to_120_300_db": relative,
        "side_to_mid_db": round(20 * math.log10(max(rms(side), 1e-12) / max(rms(mid), 1e-12)), 2),
        "lr_correlation": round(float(np.corrcoef(audio[:, 0], audio[:, 1])[0, 1]), 3),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bursts", type=Path, required=True)
    parser.add_argument("--loop", type=Path, required=True)
    parser.add_argument("--ignition", type=Path, required=True)
    parser.add_argument("--fireplace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    candidates = make_candidates(
        decode(args.bursts), decode(args.loop), decode(args.ignition), decode(args.fireplace)
    )
    report = {}
    for filename, audio in candidates.items():
        write_wav(args.output / filename, audio)
        report[filename] = metrics(audio)

    gap = np.zeros((round(0.95 * SAMPLE_RATE), 2), dtype=np.float64)
    reel = np.concatenate([
        np.zeros((round(0.20 * SAMPLE_RATE), 2), dtype=np.float64),
        *[part for pair in ((audio, gap) for audio in candidates.values()) for part in pair],
    ])
    write_wav(args.output / "fire-fwoosh-audition-reel.wav", reel)
    (args.output / "metrics.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
