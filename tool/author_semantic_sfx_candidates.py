#!/usr/bin/env python3
"""Author three audition-only semantic sound directions for Room of Days.

This script deliberately does not replace runtime assets.  It creates a
selection set under ``design/audits`` so the sonic direction can be judged as
a family before any event is rewired.

Every audible layer comes from a recorded object or acoustic instrument.  No
oscillators, synthesized bells, procedural sparkle, or algorithmic reverb are
used.  The only musical vocabulary is an open D/A fifth, with C used once as a
low-weight colour.  Ordinary actions stay object-first; a clear three-note
gesture is reserved for genuine rank advancement.
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


SAMPLE_RATE = 48_000


@dataclass(frozen=True)
class Direction:
    slug: str
    title: str
    object_gain: float
    resonance_gain: float
    tail_scale: float
    width: float
    lowpass_hz: float
    ember_gain: float


DIRECTIONS = (
    Direction(
        "a-ledger", "The Ledger", 1.00, 0.17, 0.72, 0.18, 3_900, 0.00,
    ),
    Direction(
        "b-hearth", "The Hearth", 0.82, 0.25, 0.94, 0.42, 4_300, 0.045,
    ),
    Direction(
        "c-relic", "The Relic", 0.72, 0.34, 1.14, 0.62, 4_700, 0.00,
    ),
)


SOURCE_FILES = {
    "sansula": "sansula_cabled_mess_380739.mp3",
    "brass": "brass_bowl_fossarts_762642.mp3",
    "glass": "glass_bowl_anthousai_448071.mp3",
    "paper": "paper_brokenmachinery_730078.mp3",
    "wood": "wood_mealwyrm_495814.mp3",
    "wax": "wax_seal_cerise_759526.mp3",
    "latch": "small_door_latch_chewiesmissus_213397.mp3",
    "drawer": "wood_drawer_fossarts_740297.mp3",
}


SOURCE_FUNDAMENTALS = {
    "sansula": 349.90,
    "brass": 780.60,
    "glass": 543.70,
}


NOTES = {
    "c4": 261.63,
    "d4": 293.66,
    "a4": 440.00,
    "d5": 587.33,
}


CUE_ORDER = (
    "boundary_soft",
    "plan_place",
    "goal_seal",
    "quest_latch",
    "streak_ward",
    "keepsake_found",
    "ledger_close",
    "rank_advance",
)


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
    pcm = np.clip(np.rint(audio * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def seconds(value: float) -> int:
    return round(value * SAMPLE_RATE)


def fade(audio: np.ndarray, attack_ms: float, release_ms: float) -> np.ndarray:
    result = audio.copy()
    attack = min(len(result), max(1, round(attack_ms * SAMPLE_RATE / 1000)))
    release = min(len(result), max(1, round(release_ms * SAMPLE_RATE / 1000)))
    result[:attack] *= (np.sin(np.linspace(0, math.pi / 2, attack)) ** 2)[:, None]
    result[-release:] *= (np.cos(np.linspace(0, math.pi / 2, release)) ** 2)[:, None]
    return result


def bandpass(
    audio: np.ndarray,
    highpass_hz: float,
    lowpass_hz: float,
    high_order: int = 2,
    low_order: int = 4,
) -> np.ndarray:
    high = butter(
        high_order, highpass_hz, btype="highpass", fs=SAMPLE_RATE, output="sos",
    )
    low = butter(
        low_order, lowpass_hz, btype="lowpass", fs=SAMPLE_RATE, output="sos",
    )
    return sosfilt(low, sosfilt(high, audio, axis=0), axis=0)


def peak(audio: np.ndarray) -> float:
    return float(np.max(np.abs(audio))) if len(audio) else 0.0


def peak_normalize(audio: np.ndarray, dbfs: float) -> np.ndarray:
    current = peak(audio) or 1.0
    return audio * (10 ** (dbfs / 20) / current)


def body_normalize(audio: np.ndarray) -> np.ndarray:
    if not len(audio):
        return audio
    probe = np.abs(audio)
    reference = float(np.percentile(probe, 99.2)) or 1.0
    return audio / reference


def activity_start(audio: np.ndarray, threshold_db: float = -38.0) -> int:
    mono = np.mean(audio, axis=1)
    frame = max(1, round(0.002 * SAMPLE_RATE))
    usable = len(mono) - len(mono) % frame
    if usable <= 0:
        return 0
    envelope = np.sqrt(np.mean(mono[:usable].reshape(-1, frame) ** 2, axis=1))
    threshold = max(float(np.max(envelope)) * 0.055, 10 ** (threshold_db / 20))
    active = np.flatnonzero(envelope >= threshold)
    return max(0, int(active[0] * frame) - seconds(0.003)) if len(active) else 0


def slice_audio(
    source: np.ndarray,
    start_s: float,
    duration_s: float,
    *,
    find_onset: bool = False,
) -> np.ndarray:
    start = seconds(start_s)
    if find_onset:
        start += activity_start(source[start:])
    end = start + seconds(duration_s)
    clip = source[max(0, start):max(0, end)].copy()
    wanted = seconds(duration_s)
    if len(clip) < wanted:
        clip = np.pad(clip, ((0, wanted - len(clip)), (0, 0)))
    return clip


def stereo_width(audio: np.ndarray, amount: float) -> np.ndarray:
    mid = (audio[:, 0] + audio[:, 1]) * 0.5
    side = (audio[:, 0] - audio[:, 1]) * 0.5 * amount
    return np.column_stack((mid + side, mid - side))


def pitch_resample(audio: np.ndarray, source_hz: float, target_hz: float) -> np.ndarray:
    ratio = target_hz / source_hz
    positions = np.arange(0, len(audio), ratio)
    source_positions = np.arange(len(audio))
    channels = [np.interp(positions, source_positions, audio[:, channel]) for channel in range(2)]
    return np.column_stack(channels)


def acoustic_voice(
    sources: dict[str, np.ndarray],
    instrument: str,
    note: str,
    duration_s: float,
    decay_s: float,
    direction: Direction,
) -> np.ndarray:
    source = sources[instrument]
    start = activity_start(source)
    clean = source[start:start + seconds(2.2)].copy()
    clean -= np.mean(clean, axis=0, keepdims=True)
    shifted = pitch_resample(clean, SOURCE_FUNDAMENTALS[instrument], NOTES[note])
    wanted = seconds(duration_s)
    if len(shifted) < wanted:
        shifted = np.pad(shifted, ((0, wanted - len(shifted)), (0, 0)))
    voice = shifted[:wanted]
    voice = bandpass(voice, 105, direction.lowpass_hz)
    voice = body_normalize(voice)
    t = np.arange(len(voice)) / SAMPLE_RATE
    voice *= np.exp(-t / max(0.05, decay_s * direction.tail_scale))[:, None]
    voice = fade(voice, 4.5, min(90, duration_s * 220))
    return stereo_width(voice, direction.width)


def object_voice(
    clip: np.ndarray,
    highpass_hz: float,
    lowpass_hz: float,
    direction: Direction,
    *,
    attack_ms: float = 1.5,
    release_ms: float = 18,
) -> np.ndarray:
    result = bandpass(clip, highpass_hz, min(lowpass_hz, direction.lowpass_hz))
    result -= np.mean(result, axis=0, keepdims=True)
    result = body_normalize(result)
    result = fade(result, attack_ms, release_ms)
    return stereo_width(result, max(0.12, direction.width * 0.72))


def blank(duration_s: float) -> np.ndarray:
    return np.zeros((seconds(duration_s), 2), dtype=np.float64)


def add(base: np.ndarray, layer: np.ndarray, at_s: float, gain: float) -> None:
    start = seconds(at_s)
    if start >= len(base):
        return
    usable = min(len(layer), len(base) - start)
    base[start:start + usable] += layer[:usable] * gain


def finish(audio: np.ndarray, direction: Direction, target_dbfs: float) -> np.ndarray:
    result = bandpass(audio, 65, direction.lowpass_hz)
    result = np.tanh(result * 0.94) / math.tanh(0.94)
    result = fade(result, 1.2, 28)
    result -= np.mean(result, axis=0, keepdims=True)
    return peak_normalize(result, target_dbfs)


def ember_layer(
    fire: np.ndarray,
    duration_s: float,
    direction: Direction,
    start_s: float = 0.38,
) -> np.ndarray:
    clip = slice_audio(fire, start_s, duration_s)
    clip = bandpass(clip, 120, 1_500)
    clip = body_normalize(clip)
    clip = fade(clip, 90, 120)
    return stereo_width(clip, direction.width)


def build_boundary(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = 0.14 + 0.03 * DIRECTIONS.index(direction)
    result = blank(total)
    wood = slice_audio(sources["wood"], 0.620, total)
    wood = object_voice(wood, 120, 2_250, direction, release_ms=24)
    add(result, wood, 0, 0.48 * direction.object_gain)
    return finish(result, direction, -13.5)


def build_plan_place(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = 0.25 + 0.04 * DIRECTIONS.index(direction)
    result = blank(total)
    paper = slice_audio(sources["paper"], 0.028, min(total, 0.24))
    paper = object_voice(paper, 420, 3_250, direction, attack_ms=2.0, release_ms=26)
    wood = slice_audio(sources["wood"], 1.226, 0.105)
    wood = object_voice(wood, 140, 2_800, direction, release_ms=22)
    add(result, paper, 0, 0.42 * direction.object_gain)
    add(result, wood, 0.075, 0.17 * direction.object_gain)
    if direction.slug != "a-ledger":
        note = acoustic_voice(sources, "sansula", "d4", total - 0.08, 0.11, direction)
        add(result, note, 0.08, direction.resonance_gain * 0.38)
    return finish(result, direction, -13.0)


def build_goal_seal(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.48, 0.60, 0.72)[DIRECTIONS.index(direction)]
    result = blank(total)
    wax = slice_audio(sources["wax"], 0.188, 0.26)
    wax = object_voice(wax, 100, 3_300, direction, release_ms=42)
    add(result, wax, 0, 0.72 * direction.object_gain)
    note = acoustic_voice(sources, "sansula", "d4", total - 0.07, 0.30, direction)
    add(result, note, 0.07, direction.resonance_gain * 0.90)
    if direction.slug == "c-relic":
        fifth = acoustic_voice(sources, "brass", "a4", total - 0.16, 0.42, direction)
        add(result, fifth, 0.16, direction.resonance_gain * 0.26)
    return finish(result, direction, -10.5)


def build_quest_latch(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.38, 0.48, 0.58)[DIRECTIONS.index(direction)]
    result = blank(total)
    latch = slice_audio(sources["latch"], 0.208, min(0.29, total))
    latch = object_voice(latch, 110, 3_650, direction, release_ms=34)
    add(result, latch, 0, 0.64 * direction.object_gain)
    note = acoustic_voice(sources, "sansula", "d4", total - 0.052, 0.24, direction)
    add(result, note, 0.052, direction.resonance_gain * 0.92)
    if direction.slug == "b-hearth":
        ember = ember_layer(sources["fire"], total - 0.12, direction, 0.54)
        add(result, ember, 0.12, direction.ember_gain * 0.42)
    return finish(result, direction, -9.8)


def build_streak_ward(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.56, 0.72, 0.86)[DIRECTIONS.index(direction)]
    result = blank(total)
    wood = slice_audio(sources["wood"], 1.226, 0.13)
    wood = object_voice(wood, 120, 2_650, direction, release_ms=28)
    add(result, wood, 0, 0.31 * direction.object_gain)
    add(result, wood, 0.165, 0.24 * direction.object_gain)
    first = acoustic_voice(sources, "sansula", "d4", total - 0.035, 0.35, direction)
    add(result, first, 0.035, direction.resonance_gain * 0.77)
    second_instrument = "glass" if direction.slug != "a-ledger" else "sansula"
    second = acoustic_voice(
        sources, second_instrument, "d5", total - 0.21, 0.38, direction,
    )
    add(result, second, 0.21, direction.resonance_gain * (0.28 if direction.slug != "a-ledger" else 0.20))
    return finish(result, direction, -11.0)


def build_keepsake(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.62, 0.78, 0.94)[DIRECTIONS.index(direction)]
    result = blank(total)
    drawer = slice_audio(sources["drawer"], 3.365, min(0.36, total))
    drawer = object_voice(drawer, 85, 3_450, direction, release_ms=46)
    add(result, drawer, 0, 0.65 * direction.object_gain)
    brass = acoustic_voice(sources, "brass", "d5", total - 0.15, 0.55, direction)
    add(result, brass, 0.15, direction.resonance_gain * 0.86)
    if direction.slug == "b-hearth":
        ember = ember_layer(sources["fire"], total - 0.20, direction, 0.47)
        add(result, ember, 0.20, direction.ember_gain * 0.65)
    if direction.slug == "c-relic":
        weight = acoustic_voice(sources, "sansula", "c4", total - 0.08, 0.44, direction)
        add(result, weight, 0.08, direction.resonance_gain * 0.19)
    return finish(result, direction, -10.8)


def build_ledger_close(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.58, 0.72, 0.86)[DIRECTIONS.index(direction)]
    result = blank(total)
    paper = slice_audio(sources["paper"], 0.105, min(0.29, total))
    paper = object_voice(paper, 360, 3_100, direction, attack_ms=4, release_ms=48)
    wax = slice_audio(sources["wax"], 0.730, 0.24)
    wax = object_voice(wax, 105, 3_200, direction, release_ms=46)
    add(result, paper, 0, 0.31 * direction.object_gain)
    add(result, wax, 0.115, 0.54 * direction.object_gain)
    root = acoustic_voice(sources, "sansula", "d4", total - 0.15, 0.48, direction)
    add(result, root, 0.15, direction.resonance_gain * 0.68)
    fifth = acoustic_voice(sources, "brass", "a4", total - 0.22, 0.53, direction)
    add(result, fifth, 0.22, direction.resonance_gain * 0.27)
    if direction.slug == "b-hearth":
        ember = ember_layer(sources["fire"], total - 0.16, direction, 0.50)
        add(result, ember, 0.16, direction.ember_gain * 0.58)
    return finish(result, direction, -10.0)


def build_rank_advance(sources: dict[str, np.ndarray], direction: Direction) -> np.ndarray:
    total = (0.88, 1.02, 1.18)[DIRECTIONS.index(direction)]
    result = blank(total)
    wax = slice_audio(sources["wax"], 0.188, 0.24)
    wax = object_voice(wax, 100, 3_350, direction, release_ms=44)
    add(result, wax, 0, 0.56 * direction.object_gain)
    placements = (("d4", 0.085), ("a4", 0.255), ("d5", 0.455))
    for index, (note, at_s) in enumerate(placements):
        instrument = "sansula" if index < 2 else "brass"
        voice = acoustic_voice(
            sources, instrument, note, total - at_s, 0.56 - index * 0.04, direction,
        )
        gains = (0.74, 0.52, 0.40)
        add(result, voice, at_s, direction.resonance_gain * gains[index])
    if direction.slug == "b-hearth":
        ember = ember_layer(sources["fire"], total - 0.17, direction, 0.42)
        add(result, ember, 0.17, direction.ember_gain * 0.72)
    return finish(result, direction, -8.8)


BUILDERS = {
    "boundary_soft": build_boundary,
    "plan_place": build_plan_place,
    "goal_seal": build_goal_seal,
    "quest_latch": build_quest_latch,
    "streak_ward": build_streak_ward,
    "keepsake_found": build_keepsake,
    "ledger_close": build_ledger_close,
    "rank_advance": build_rank_advance,
}


def silence(duration_s: float) -> np.ndarray:
    return blank(duration_s)


def concatenate(parts: list[np.ndarray]) -> np.ndarray:
    return np.concatenate(parts, axis=0) if parts else blank(0)


def metrics(audio: np.ndarray) -> dict[str, float]:
    mono = np.mean(audio, axis=1)
    rms = float(np.sqrt(np.mean(mono * mono))) if len(mono) else 0.0
    peak_value = peak(audio)
    spectrum = np.fft.rfft(mono * np.hanning(len(mono))) if len(mono) else np.zeros(1)
    energy = np.abs(spectrum) ** 2
    frequencies = np.fft.rfftfreq(len(mono), 1 / SAMPLE_RATE) if len(mono) else np.zeros(1)
    total_energy = float(np.sum(energy)) or 1.0
    centroid = float(np.sum(frequencies * energy) / total_energy)
    upper = float(np.sum(energy[frequencies >= 5_000]) / total_energy)
    return {
        "duration_ms": round(len(audio) * 1000 / SAMPLE_RATE, 1),
        "peak_dbfs": round(20 * math.log10(max(peak_value, 1e-9)), 2),
        "rms_dbfs": round(20 * math.log10(max(rms, 1e-9)), 2),
        "spectral_centroid_hz": round(centroid, 1),
        "energy_above_5khz_percent": round(upper * 100, 2),
    }


def build_reel(cues: dict[str, np.ndarray]) -> tuple[np.ndarray, list[dict[str, object]]]:
    parts: list[np.ndarray] = []
    timecodes: list[dict[str, object]] = []
    cursor = 0.0
    lead = 0.45
    parts.append(silence(lead))
    cursor += lead
    for index, cue_name in enumerate(CUE_ORDER):
        cue = cues[cue_name]
        timecodes.append({"cue": cue_name, "starts_at_seconds": round(cursor, 3)})
        parts.append(cue)
        cursor += len(cue) / SAMPLE_RATE
        gap = 0.62 if index < len(CUE_ORDER) - 1 else 0.55
        parts.append(silence(gap))
        cursor += gap
    return concatenate(parts), timecodes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--acoustic-root", required=True, type=Path)
    parser.add_argument("--contact-root", required=True, type=Path)
    parser.add_argument("--semantic-root", required=True, type=Path)
    parser.add_argument("--fire", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    locations = {
        "sansula": args.acoustic_root / SOURCE_FILES["sansula"],
        "brass": args.acoustic_root / SOURCE_FILES["brass"],
        "glass": args.acoustic_root / SOURCE_FILES["glass"],
        "paper": args.acoustic_root / SOURCE_FILES["paper"],
        "wood": args.contact_root / SOURCE_FILES["wood"],
        "wax": args.semantic_root / SOURCE_FILES["wax"],
        "latch": args.semantic_root / SOURCE_FILES["latch"],
        "drawer": args.semantic_root / SOURCE_FILES["drawer"],
        "fire": args.fire,
    }
    missing = [str(path) for path in locations.values() if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing source files:\n" + "\n".join(missing))

    sources = {name: decode(path) for name, path in locations.items()}
    report: dict[str, object] = {
        "sample_rate": SAMPLE_RATE,
        "source_files": {name: str(path) for name, path in locations.items()},
        "directions": {},
    }
    args.output.mkdir(parents=True, exist_ok=True)

    rendered: dict[str, dict[str, np.ndarray]] = {}
    for direction in DIRECTIONS:
        direction_root = args.output / direction.slug
        cues: dict[str, np.ndarray] = {}
        cue_metrics: dict[str, object] = {}
        for cue_name in CUE_ORDER:
            cue = BUILDERS[cue_name](sources, direction)
            cues[cue_name] = cue
            cue_metrics[cue_name] = metrics(cue)
            write_wav(direction_root / f"{cue_name}.wav", cue)

        rendered[direction.slug] = cues

        reel, timecodes = build_reel(cues)
        write_wav(args.output / f"{direction.slug}-audition.wav", reel)
        report["directions"][direction.slug] = {
            "title": direction.title,
            "cues": cue_metrics,
            "timecodes": timecodes,
            "reel": metrics(reel),
        }

    # Recommended use is hierarchical, not one uniform intensity.  Dry object
    # cues handle routine boundaries and placement; hearth-weight cues carry
    # daily meaning; only discovery and true advancement use the Relic voice.
    recommended_sources = {
        "boundary_soft": "a-ledger",
        "plan_place": "a-ledger",
        "goal_seal": "b-hearth",
        "quest_latch": "b-hearth",
        "streak_ward": "b-hearth",
        "keepsake_found": "c-relic",
        "ledger_close": "b-hearth",
        "rank_advance": "c-relic",
    }
    recommended = {
        cue_name: rendered[direction_slug][cue_name]
        for cue_name, direction_slug in recommended_sources.items()
    }
    recommended_reel, recommended_timecodes = build_reel(recommended)
    write_wav(args.output / "recommended-gradient-audition.wav", recommended_reel)
    report["recommended_gradient"] = {
        "source_direction_by_cue": recommended_sources,
        "timecodes": recommended_timecodes,
        "reel": metrics(recommended_reel),
    }

    with (args.output / "metrics.json").open("w", encoding="utf-8") as output:
        json.dump(report, output, indent=2)
        output.write("\n")


if __name__ == "__main__":
    main()
