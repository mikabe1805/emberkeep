#!/usr/bin/env python3
"""Render a blind note-palette study for repeated Room of Days taps.

This tool changes one variable only: pitch grammar. Every candidate uses the
same deterministic, dry, procedurally authored carrier, timing, dynamics, and
mastering. Outputs are audition files under ``design/audits``; this script does
not write to ``assets/sfx`` or alter runtime routing.

Requires NumPy, SciPy, and SoundFile.
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt


SAMPLE_RATE = 48_000
OVERSAMPLE = 4
NOTE_DURATION_SECONDS = 0.165
ROOT_MIDI = 74  # D5: present on phone speakers without forcing every palette high.


@dataclass(frozen=True)
class Palette:
    slug: str
    collection: tuple[int, ...]
    phrase: tuple[int, ...]


# Neutral slugs keep the first listen blind. Descriptive/theory labels live in
# the study README and should be read only after forming an initial preference.
PALETTES = (
    Palette("a", (0, 2, 4, 7, 9), (0, 2, 4, 7, 9, 7, 4, 2)),
    Palette("b", (0, 4, 7, 9, 12), (0, 4, 9, 12, 9, 7, 4, 0)),
    Palette("c", (0, 2, 4, 6, 7, 9, 11, 12), (0, 2, 6, 7, 11, 12, 7, 2)),
    Palette("d", (0, 7, 12, 14), (0, 7, 12, 7, 14, 12, 7, 0)),
    Palette("e", (0, 4, 7, 12, 16), (0, 4, 7, 12, 16, 12, 7, 4)),
    Palette("f", (0, 5, 10, 12, 17), (0, 5, 10, 12, 17, 12, 10, 5)),
)

# The same small dynamic contour is applied to every phrase. It prevents the
# rapid pass from sounding like a diagnostic tone train without favoring a
# particular palette.
VELOCITIES = (0.91, 0.95, 0.98, 1.00, 0.97, 0.94, 0.92, 0.89)


def midi_frequency(midi_note: int) -> float:
    return 440.0 * 2 ** ((midi_note - 69) / 12)


def midi_name(midi_note: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi_note % 12]}{midi_note // 12 - 1}"


def _fade_edges(audio: np.ndarray, attack_ms: float, release_ms: float, rate: int) -> np.ndarray:
    result = audio.copy()
    attack = min(len(result), max(1, round(rate * attack_ms / 1000)))
    release = min(len(result), max(1, round(rate * release_ms / 1000)))
    result[:attack] *= (np.sin(np.linspace(0, math.pi / 2, attack)) ** 2)[:, None]
    result[-release:] *= (np.cos(np.linspace(0, math.pi / 2, release)) ** 2)[:, None]
    return result


def _bandpass(audio: np.ndarray, low_hz: float, high_hz: float, rate: int) -> np.ndarray:
    highpass = butter(2, low_hz, btype="highpass", fs=rate, output="sos")
    lowpass = butter(4, high_hz, btype="lowpass", fs=rate, output="sos")
    return sosfilt(lowpass, sosfilt(highpass, audio, axis=0), axis=0)


def synth_note(midi_note: int) -> np.ndarray:
    """Create one close, modern soft-mallet carrier at four-times oversampling."""
    rate = SAMPLE_RATE * OVERSAMPLE
    frames = round(NOTE_DURATION_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate
    frequency = midi_frequency(midi_note)

    attack = 1.0 - np.exp(-t / 0.00072)
    fundamental_envelope = attack * (
        0.70 * np.exp(-t / 0.052) + 0.30 * np.exp(-t / 0.118)
    )
    tone = np.sin(2 * math.pi * frequency * t + 0.08) * fundamental_envelope

    # Shorter upper modes supply a crisp, legible edge without a bell tail.
    partials = (
        (2.006, 0.205, 0.040, 0.41),
        (2.995, 0.074, 0.025, 1.09),
        (4.070, 0.028, 0.014, 1.73),
    )
    for ratio, gain, decay, phase in partials:
        envelope = attack * np.exp(-t / decay)
        tone += gain * np.sin(2 * math.pi * frequency * ratio * t + phase) * envelope

    # An identical, extremely short shaped-noise impulse gives every note the
    # same tactile cause. It is narrow stereo but the tonal body stays centered.
    rng = np.random.default_rng(20_260_820)
    noise = rng.standard_normal(frames)
    noise_filter = butter(3, (2_400, 10_500), btype="bandpass", fs=rate, output="sos")
    noise = sosfilt(noise_filter, noise)
    noise /= float(np.max(np.abs(noise))) or 1.0
    noise_envelope = (1.0 - np.exp(-t / 0.00018)) * np.exp(-t / 0.0019)
    noise *= noise_envelope * 0.048
    side_delay = max(1, round(rate * 0.00017))
    delayed_noise = np.pad(noise[:-side_delay], (side_delay, 0))

    audio = np.column_stack((tone + noise, tone + delayed_noise * 0.91))
    audio = _bandpass(audio, 120, 12_500, rate)
    audio = np.tanh(audio * 1.045) / math.tanh(1.045)
    audio = _fade_edges(audio, 0.45, 17.0, rate)

    # Proper polyphase downsampling keeps upper modes band-limited.
    audio = resample_poly(audio, 1, OVERSAMPLE, axis=0, window=("kaiser", 9.0))
    audio -= np.mean(audio, axis=0, keepdims=True)

    probe = audio[: round(0.120 * SAMPLE_RATE)]
    rms = float(np.sqrt(np.mean(probe * probe))) or 1.0
    audio *= 10 ** (-22.0 / 20) / rms
    peak = float(np.max(np.abs(audio))) or 1.0
    ceiling = 10 ** (-9.5 / 20)
    if peak > ceiling:
        audio *= ceiling / peak
    return audio.astype(np.float64)


def silence(seconds: float) -> np.ndarray:
    return np.zeros((round(seconds * SAMPLE_RATE), 2), dtype=np.float64)


def render_phrase(palette: Palette, step_seconds: float) -> np.ndarray:
    lead_seconds = 0.110
    tail_seconds = 0.235
    total_seconds = (
        lead_seconds
        + step_seconds * (len(palette.phrase) - 1)
        + NOTE_DURATION_SECONDS
        + tail_seconds
    )
    result = np.zeros((round(total_seconds * SAMPLE_RATE), 2), dtype=np.float64)
    for index, (interval, velocity) in enumerate(zip(palette.phrase, VELOCITIES)):
        note = synth_note(ROOT_MIDI + interval) * velocity
        start = round((lead_seconds + index * step_seconds) * SAMPLE_RATE)
        end = min(len(result), start + len(note))
        result[start:end] += note[: end - start]

    # All phrases share one ceiling; no candidate wins by being louder.
    peak = float(np.max(np.abs(result))) or 1.0
    target = 10 ** (-8.8 / 20)
    result *= target / peak
    return result


def render_candidate(palette: Palette) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    measured = render_phrase(palette, 0.245)
    rapid = render_phrase(palette, 0.132)
    combined = np.concatenate((
        silence(0.180),
        measured,
        silence(0.580),
        rapid,
        silence(0.300),
    ))
    return combined, measured, rapid


def _spectral_metrics(audio: np.ndarray) -> dict[str, float]:
    mono = np.mean(audio, axis=1)
    active = mono[np.abs(mono) >= 10 ** (-60 / 20)]
    if not len(active):
        active = mono
    peak = float(np.max(np.abs(audio))) or 1e-12
    rms = float(np.sqrt(np.mean(active * active))) or 1e-12
    window = mono * np.hanning(len(mono))
    spectrum = np.abs(np.fft.rfft(window)) ** 2
    frequencies = np.fft.rfftfreq(len(window), 1 / SAMPLE_RATE)
    power = float(np.sum(spectrum)) or 1.0
    return {
        "duration_seconds": round(len(audio) / SAMPLE_RATE, 4),
        "peak_dbfs": round(20 * math.log10(peak), 3),
        "active_rms_dbfs": round(20 * math.log10(rms), 3),
        "spectral_centroid_hz": round(float(np.sum(frequencies * spectrum) / power), 2),
        "presence_2_6khz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 2_000) & (frequencies < 6_000)])) / power,
            3,
        ),
        "air_over_8khz_pct": round(
            100 * float(np.sum(spectrum[frequencies >= 8_000])) / power,
            3,
        ),
    }


def write_wav(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def build_study(output: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    full_reel: list[np.ndarray] = [silence(0.350)]
    rapid_reel: list[np.ndarray] = [silence(0.250)]
    metrics: dict[str, object] = {}
    manifest = {"candidates": []}

    for palette in PALETTES:
        combined, measured, rapid = render_candidate(palette)
        filename = f"palette-{palette.slug}.wav"
        write_wav(output / filename, combined)
        full_reel.extend((combined, silence(0.820)))
        rapid_reel.extend((rapid, silence(0.610)))
        manifest["candidates"].append({
            "id": f"palette-{palette.slug}",
            "role": "repeated_tap_note_palette",
            "path": filename,
        })
        metrics[palette.slug] = {
            "collection_semitones": list(palette.collection),
            "phrase_semitones": list(palette.phrase),
            "phrase_notes": [midi_name(ROOT_MIDI + interval) for interval in palette.phrase],
            "combined": _spectral_metrics(combined),
            "measured": _spectral_metrics(measured),
            "rapid": _spectral_metrics(rapid),
        }

    write_wav(output / "note-palette-full-reel.wav", np.concatenate(full_reel))
    write_wav(output / "note-palette-rapid-reel.wav", np.concatenate(rapid_reel))
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8",
    )
    report = {
        "sample_rate_hz": SAMPLE_RATE,
        "sample_format": "PCM_24",
        "root_note": midi_name(ROOT_MIDI),
        "note_duration_ms": NOTE_DURATION_SECONDS * 1000,
        "measured_step_ms": 245,
        "rapid_step_ms": 132,
        "palettes": metrics,
    }
    (output / "metrics.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8",
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output), indent=2))


if __name__ == "__main__":
    main()
