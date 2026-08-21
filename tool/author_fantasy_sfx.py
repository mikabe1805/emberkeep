#!/usr/bin/env python3
"""Author Room of Days' restrained fantasy interaction palette.

This is an offline production tool, not an app dependency. It combines the
licensed foley contacts already in ``assets/sfx`` with short resonances from
real acoustic instruments. The result stays tactile on pointer-down while all
families share one suspended pentatonic language: C, D, E, G, and A.

Required source previews and their licenses are recorded in
``assets/sfx/SOURCES.md``. Run with NumPy/SciPy and ffmpeg available::

  python tool/author_fantasy_sfx.py \
    --sources <downloaded-source-directory> \
    --foley assets/sfx \
    --output <staging-directory> \
    --audition <audit-directory>
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt


SAMPLE_RATE = 44_100


@dataclass(frozen=True)
class Family:
    name: str
    root_hz: float
    upper_hz: float
    instrument: str
    instrument_f0: float
    duration_ms: int
    contact_gain: float
    tone_gain: float
    upper_gain: float
    highpass_hz: float
    lowpass_hz: float
    peak_dbfs: float
    tone_delay_ms: float
    decay_ms: float


# D-centered suspended pentatonic: D E G A C. It shares C/E/G with the
# existing reward cues, so a delayed completion sound resolves rather than
# colliding harmonically with the contact beneath it.
FAMILIES = (
    Family("wood", 293.66, 440.00, "sansula", 349.9, 150, .34, .78, .31, 95, 3_400, -8.5, 8, 78),
    Family("stone", 392.00, 587.33, "glass", 543.7, 138, .42, .66, .27, 150, 4_000, -8.8, 7, 66),
    Family("parchment", 659.25, 880.00, "glass", 543.7, 165, .28, .58, .22, 260, 4_200, -9.5, 12, 92),
    Family("brass", 523.25, 783.99, "brass", 780.6, 185, .18, .88, .36, 130, 5_000, -9.0, 9, 108),
    Family("glass", 880.00, 1_318.51, "glass", 543.7, 175, .14, .82, .30, 360, 6_000, -10.0, 10, 96),
)

SOURCE_FILES = {
    "sansula": "sansula_cabled_mess_380739.mp3",
    "brass": "brass_bowl_fossarts_762642.mp3",
    "glass": "glass_bowl_anthousai_448071.mp3",
    "paper": "paper_brokenmachinery_730078.mp3",
}


def decode(path: Path) -> np.ndarray:
    completed = subprocess.run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-i", str(path),
            "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "f32le", "pipe:1",
        ],
        check=True,
        capture_output=True,
    )
    return np.frombuffer(completed.stdout, dtype="<f4").astype(np.float64)


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as source:
        if (
            source.getnchannels() != 1
            or source.getsampwidth() != 2
            or source.getframerate() != SAMPLE_RATE
        ):
            raise ValueError(f"Unexpected foley format: {path}")
        data = source.readframes(source.getnframes())
    return np.frombuffer(data, dtype="<i2").astype(np.float64) / 32768.0


def write_wav(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(np.rint(audio * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def bandpass(audio: np.ndarray, highpass_hz: float, lowpass_hz: float) -> np.ndarray:
    high = butter(2, highpass_hz, btype="highpass", fs=SAMPLE_RATE, output="sos")
    low = butter(4, lowpass_hz, btype="lowpass", fs=SAMPLE_RATE, output="sos")
    return sosfilt(low, sosfilt(high, audio))


def fade(audio: np.ndarray, attack_ms: float, release_ms: float) -> np.ndarray:
    result = audio.copy()
    attack = min(len(result), max(1, round(attack_ms * SAMPLE_RATE / 1000)))
    release = min(len(result), max(1, round(release_ms * SAMPLE_RATE / 1000)))
    result[:attack] *= np.sin(np.linspace(0, math.pi / 2, attack)) ** 2
    result[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    return result


def normalize_peak(audio: np.ndarray, peak_dbfs: float) -> np.ndarray:
    peak = float(np.max(np.abs(audio))) or 1.0
    return audio * (10 ** (peak_dbfs / 20) / peak)


def normalize_body(audio: np.ndarray) -> np.ndarray:
    probe = audio[: min(len(audio), round(.12 * SAMPLE_RATE))]
    rms = float(np.sqrt(np.mean(probe * probe))) or 1.0
    return audio / rms


def activity_start(audio: np.ndarray) -> int:
    frame = max(1, round(.002 * SAMPLE_RATE))
    usable = len(audio) - len(audio) % frame
    envelope = np.sqrt(np.mean(audio[:usable].reshape(-1, frame) ** 2, axis=1))
    threshold = max(float(np.max(envelope)) * .08, 10 ** (-45 / 20))
    active = np.flatnonzero(envelope >= threshold)
    first = int(active[0] * frame) if len(active) else 0
    return max(0, first - round(.004 * SAMPLE_RATE))


def pitch_resample(audio: np.ndarray, source_hz: float, target_hz: float) -> np.ndarray:
    rate = target_hz / source_hz
    positions = np.arange(0, len(audio), rate)
    return np.interp(positions, np.arange(len(audio)), audio)


def instrument_voice(
    source: np.ndarray,
    source_hz: float,
    target_hz: float,
    length: int,
    detune_cents: float,
) -> np.ndarray:
    start = activity_start(source)
    clean = source[start : start + round(1.25 * SAMPLE_RATE)].copy()
    clean -= float(np.mean(clean))
    target = target_hz * 2 ** (detune_cents / 1200)
    shifted = pitch_resample(clean, source_hz, target)
    if len(shifted) < length:
        shifted = np.pad(shifted, (0, length - len(shifted)))
    return normalize_body(shifted[:length])


def contact_voice(audio: np.ndarray, length: int, family: str) -> np.ndarray:
    clip = audio[:length].copy()
    if len(clip) < length:
        clip = np.pad(clip, (0, length - len(clip)))
    filters = {
        "wood": (130, 3_600),
        "stone": (260, 4_500),
        "parchment": (560, 4_800),
        "brass": (260, 4_600),
        "glass": (720, 5_600),
        "tick": (180, 3_800),
    }
    clip = bandpass(clip, *filters[family])
    clip = fade(clip, 1.5, 10)
    peak = float(np.max(np.abs(clip))) or 1.0
    return clip / peak


def paper_contact(source: np.ndarray, variant: int, length: int) -> np.ndarray:
    # Three small gestures in the CC0 paper-slide recording.
    at = (.040, .115, .197)[variant - 1]
    pre = round(.005 * SAMPLE_RATE)
    start = max(0, round(at * SAMPLE_RATE) - pre)
    return contact_voice(source[start : start + length], length, "parchment")


def build_contact(
    family: Family,
    variant: int,
    instruments: dict[str, np.ndarray],
    foley_root: Path,
) -> np.ndarray:
    duration_ms = family.duration_ms + (-5, 0, 5)[variant - 1]
    total = round(duration_ms * SAMPLE_RATE / 1000)
    detune = (-3.0, 0.0, 3.0)[variant - 1]
    delay = round((family.tone_delay_ms + variant - 2) * SAMPLE_RATE / 1000)
    body_length = total - delay

    root = instrument_voice(
        instruments[family.instrument], family.instrument_f0,
        family.root_hz, body_length, detune,
    )
    upper = instrument_voice(
        instruments[family.instrument], family.instrument_f0,
        family.upper_hz, body_length, detune,
    )
    tone = root + upper * (family.upper_gain + (-.02, 0, .02)[variant - 1])
    tone = normalize_body(tone)
    t = np.arange(body_length) / SAMPLE_RATE
    tone *= np.exp(-t / (family.decay_ms / 1000))
    tone = fade(tone, 6.5, 16)

    contact_length = min(total, round((52 + 3 * variant) * SAMPLE_RATE / 1000))
    if family.name == "parchment":
        contact = paper_contact(instruments["paper"], variant, contact_length)
    else:
        contact = contact_voice(
            read_wav(foley_root / f"tap_{family.name}_{variant}.wav"),
            contact_length,
            family.name,
        )

    result = np.zeros(total, dtype=np.float64)
    result[:contact_length] += contact * family.contact_gain
    result[delay:] += tone * family.tone_gain
    result = bandpass(result, family.highpass_hz, family.lowpass_hz)
    result = np.tanh(result * 1.08) / math.tanh(1.08)
    result = fade(result, 1.2, 13)
    result -= float(np.mean(result))
    return normalize_peak(result, family.peak_dbfs)


def build_legacy_tick(
    name: str,
    root_hz: float,
    upper_hz: float,
    duration_ms: int,
    lowpass_hz: float,
    contact: np.ndarray,
    sansula: np.ndarray,
) -> np.ndarray:
    total = round(duration_ms * SAMPLE_RATE / 1000)
    delay = round(.008 * SAMPLE_RATE)
    body = total - delay
    root = instrument_voice(sansula, 349.9, root_hz, body, 0)
    upper = instrument_voice(sansula, 349.9, upper_hz, body, 0)
    tone = normalize_body(root + upper * .25)
    t = np.arange(body) / SAMPLE_RATE
    tone *= np.exp(-t / .064)
    tone = fade(tone, 6, 14)
    click_length = min(total, round(.045 * SAMPLE_RATE))
    click = contact_voice(contact, click_length, "tick")
    result = np.zeros(total, dtype=np.float64)
    result[:click_length] += click * .27
    result[delay:] += tone * .72
    result = bandpass(result, 120, lowpass_hz)
    result = fade(result, 1.2, 12)
    return normalize_peak(result, -9.0 if name != "tick_lift" else -9.5)


def silence(milliseconds: float) -> np.ndarray:
    return np.zeros(round(milliseconds * SAMPLE_RATE / 1000), dtype=np.float64)


def metrics(audio: np.ndarray) -> dict[str, float]:
    peak = float(np.max(np.abs(audio)))
    rms = float(np.sqrt(np.mean(audio * audio)))
    spectrum = np.abs(np.fft.rfft(audio * np.hanning(len(audio)))) ** 2
    frequencies = np.fft.rfftfreq(len(audio), 1 / SAMPLE_RATE)
    power = float(np.sum(spectrum)) or 1.0
    return {
        "duration_ms": round(len(audio) / SAMPLE_RATE * 1000, 1),
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-12)), 2),
        "centroid_hz": round(float(np.sum(frequencies * spectrum) / power)),
        "under_500hz_pct": round(float(np.sum(spectrum[frequencies <= 500]) / power) * 100, 2),
        "over_5khz_pct": round(float(np.sum(spectrum[frequencies >= 5_000]) / power) * 100, 2),
    }


def make_auditions(
    output_root: Path,
    before_root: Path,
    audition_root: Path,
) -> None:
    audition_root.mkdir(parents=True, exist_ok=True)
    reel = [silence(180)]
    for family in FAMILIES:
        for variant in range(1, 4):
            reel.extend((read_wav(output_root / f"tap_{family.name}_{variant}.wav"), silence(240)))
        reel.append(silence(420))
    write_wav(audition_root / "interaction-sounds-audition.wav", np.concatenate(reel))

    comparison = [silence(180)]
    for family in FAMILIES:
        comparison.extend((read_wav(before_root / f"tap_{family.name}_1.wav"), silence(330)))
    comparison.append(silence(950))
    for family in FAMILIES:
        comparison.extend((read_wav(output_root / f"tap_{family.name}_1.wav"), silence(330)))
    write_wav(audition_root / "interaction-sounds-before-after.wav", np.concatenate(comparison))

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--foley", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--audition", type=Path, required=True)
    args = parser.parse_args()

    instruments = {
        name: decode(args.sources / filename)
        for name, filename in SOURCE_FILES.items()
    }
    report: dict[str, dict[str, float]] = {}

    for family in FAMILIES:
        for variant in range(1, 4):
            audio = build_contact(family, variant, instruments, args.foley)
            filename = f"tap_{family.name}_{variant}.wav"
            write_wav(args.output / filename, audio)
            report[filename] = metrics(audio)

    tick_specs = (
        ("tick", 587.33, 880.00, 125, 3_600, "tap_wood_1.wav"),
        ("tick_warm", 587.33, 880.00, 132, 3_000, "tap_wood_2.wav"),
        ("tick_lift", 659.25, 880.00, 145, 4_200, "tap_wood_3.wav"),
    )
    for name, root, upper, duration, lowpass, contact_name in tick_specs:
        audio = build_legacy_tick(
            name, root, upper, duration, lowpass,
            read_wav(args.foley / contact_name), instruments["sansula"],
        )
        write_wav(args.output / f"{name}.wav", audio)
        report[f"{name}.wav"] = metrics(audio)

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "metrics.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    make_auditions(args.output, args.foley, args.audition)
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
