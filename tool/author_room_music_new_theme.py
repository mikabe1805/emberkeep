#!/usr/bin/env python3
"""Author one original, song-shaped sibling to Room's umbrella-brush music.

The owner correction this study answers is musical rather than technical:
the earlier variety pieces were usable ambience, but did not feel like actual
music with a hook worth reopening the app to hear.  This renderer therefore
writes one fixed 28-bar score with an A-A'-B-A form, an eight-bar lead melody,
an answering half, and a four-bar bridge.  Only microtiming, velocity, and
timbre are seeded; the notes, rhythms, harmony, and arrangement are explicit.

The sound remains inside the approved umbrella-brush world.  It imports the
same modal keys/lead, two-feel bass, thump, papery rim, dark brush grain, room
bus, loudness target, and D-major/B-minor pitch law from
``author_room_music_v2_study.py``.  It imports no samples and does not copy or
transcribe a reference melody.  The reserved Paired Return cue
D5-A5-E5-D5 is rejected by a full per-voice sliding-window check.

Run from the repository root:

    python tool/author_room_music_new_theme.py \
      --output design/audits/2026-09-06/sound-and-music/umbrella-new-theme
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path
from typing import Iterable

import numpy as np
import soundfile as sf

import author_room_music_study as music
import author_room_music_v2_study as v2
import author_room_sonic_world_study as world
import sonic_taste_gate


STUDY_ID = "umbrella-new-theme"
PIECE_ID = "lamp-left-on"
TITLE = "Lamp left on"
RENDER_VERSION = "umbrella-authored-theme-v1"
SAMPLE_RATE = world.SAMPLE_RATE
SECONDS = 96.0
BPM = 72.0
SWING = 0.57
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
TARGET_DBFS = v2.TARGET_DBFS
RESERVED_MOTIF = (74, 81, 76, 74)
DIATONIC_PCS = v2.DIATONIC_PCS


# A written note is (swung-eighth position, MIDI, notated duration in beats,
# nominal velocity).  Every A bar has an intentional onset; there are no
# randomly generated lead fragments.  The four-onset rhythm at 2/3/5/6 is the
# hook: two close notes, a breath, then a short-long answer.
WrittenNote = tuple[int, int, float, float]
WrittenBar = tuple[WrittenNote, ...]

THEME_A: tuple[WrittenBar, ...] = (
    ((2, 71, 0.35, 0.73), (3, 74, 0.45, 0.69), (5, 78, 0.35, 0.77), (6, 76, 1.45, 0.72)),
    ((0, 74, 0.75, 0.68), (2, 71, 0.50, 0.70), (4, 69, 0.50, 0.65), (6, 71, 1.60, 0.74)),
    ((2, 69, 0.35, 0.67), (3, 71, 0.45, 0.70), (5, 73, 0.35, 0.65), (6, 76, 1.45, 0.73)),
    ((1, 73, 0.35, 0.66), (3, 71, 0.45, 0.69), (4, 69, 0.50, 0.65), (6, 66, 1.60, 0.72)),
    ((2, 71, 0.35, 0.69), (3, 74, 0.45, 0.72), (5, 76, 0.35, 0.72), (6, 78, 1.45, 0.77)),
    ((0, 81, 1.10, 0.78), (3, 78, 0.35, 0.70), (4, 76, 0.50, 0.68), (6, 74, 1.40, 0.73)),
    ((2, 71, 0.35, 0.70), (3, 74, 0.45, 0.70), (5, 78, 0.35, 0.75), (6, 76, 1.40, 0.71)),
    ((0, 74, 0.65, 0.68), (2, 71, 0.50, 0.69), (4, 69, 0.50, 0.65), (6, 71, 1.75, 0.76)),
)

# A' keeps the complete four-bar question and the opening of the answer, then
# lets the hook climb once before settling.  This is development, not a newly
# generated phrase.
THEME_A_PRIME: tuple[WrittenBar, ...] = THEME_A[:6] + (
    ((0, 76, 0.75, 0.68), (2, 78, 0.35, 0.72), (3, 81, 0.45, 0.78),
     (5, 78, 0.35, 0.71), (6, 76, 1.35, 0.73)),
    THEME_A[7],
)

# The bridge changes the rhythm and reaches the single B5 high point.  Its
# final A4 is a small pickup into the exact return of A.
BRIDGE_B: tuple[WrittenBar, ...] = (
    ((0, 74, 1.35, 0.72), (3, 71, 0.35, 0.66), (4, 69, 0.55, 0.65), (6, 71, 1.00, 0.70)),
    ((0, 73, 0.50, 0.66), (2, 76, 0.55, 0.70), (4, 78, 0.65, 0.74), (6, 76, 0.95, 0.70)),
    ((0, 78, 0.30, 0.72), (1, 81, 0.45, 0.76), (3, 83, 0.75, 0.80), (6, 81, 0.95, 0.75)),
    ((0, 78, 0.60, 0.70), (2, 76, 0.60, 0.69), (4, 74, 0.60, 0.68),
     (6, 71, 0.50, 0.66), (7, 69, 0.35, 0.61)),
)

SECTIONS: tuple[tuple[str, int, tuple[WrittenBar, ...]], ...] = (
    ("A1", 0, THEME_A),
    ("A2", 8, THEME_A_PRIME),
    ("B", 16, BRIDGE_B),
    ("A_return", 20, THEME_A),
)

PROGRESSION = tuple(v2.LOOP) + tuple(v2.LOOP) + tuple(v2.BRIDGE) + tuple(v2.LOOP)

# Every voicing is selected explicitly from the approved v2 chord bank.  The
# performance code still rolls and humanizes it, but does not invent harmony.
CHORD_UNITS: tuple[tuple[int, str, int, tuple[int, ...]], ...] = (
    (0, "Bm9", 2, (57, 62, 66)),
    (2, "F#m7(11)", 2, (57, 64, 66)),
    (4, "A9sus", 2, (55, 62, 64)),
    (6, "Em9", 2, (55, 62, 66)),
    (8, "Bm9", 2, (57, 61, 66)),
    (10, "F#m7(11)", 2, (61, 64, 69)),
    (12, "A9sus", 2, (55, 59, 64)),
    (14, "Em9", 2, (59, 62, 66)),
    (16, "Gmaj9", 1, (59, 62, 66)),
    (17, "A13", 1, (61, 67, 71)),
    (18, "Dmaj9", 1, (57, 61, 66)),
    (19, "Em9", 1, (55, 62, 66)),
    (20, "Bm9", 2, (57, 62, 66)),
    (22, "F#m7(11)", 2, (57, 64, 66)),
    (24, "A9sus", 2, (55, 62, 64)),
    (26, "Em9", 2, (59, 62, 66)),
)

# The upper dyad answers the full chord at written phrase points.  These bars
# are fixed so the comping also articulates the form.
SYNCOPATED_COMP_BARS = frozenset((1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27))
BRUSH_BREATHS = frozenset((7, 15, 19, 27))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _note_name(midi: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi % 12]}{midi // 12 - 1}"


def _pos(bar_start: float, eighth: int) -> float:
    return bar_start + (eighth // 2) * BEAT + (SWING * BEAT if eighth % 2 else 0.0)


def _section_for_bar(bar_index: int) -> str:
    if bar_index < 8:
        return "A1"
    if bar_index < 16:
        return "A2"
    if bar_index < 20:
        return "B"
    return "A_return"


def _notated_score() -> dict[str, object]:
    result: dict[str, object] = {
        "meter": "4/4",
        "bpm": BPM,
        "swing": SWING,
        "form": "A1 (8 bars) | A2 developed (8 bars) | B (4 bars) | A return (8 bars)",
        "hook_rhythm": "swung eighth positions 2, 3, 5, 6: short, short, breath, short-long",
        "sections": [],
    }
    sections: list[dict[str, object]] = []
    for section_name, start_bar, written_bars in SECTIONS:
        bars: list[dict[str, object]] = []
        for local_bar, events in enumerate(written_bars):
            absolute_bar = start_bar + local_bar
            bars.append({
                "bar": absolute_bar + 1,
                "chord": PROGRESSION[absolute_bar],
                "notes": [
                    {
                        "eighth": eighth,
                        "beat": round(eighth / 2 + 1, 2),
                        "midi": midi,
                        "note": _note_name(midi),
                        "notated_duration_beats": duration,
                        "nominal_velocity": velocity,
                    }
                    for eighth, midi, duration, velocity in events
                ],
            })
        sections.append({"name": section_name, "start_bar": start_bar + 1, "bars": bars})
    result["sections"] = sections
    return result


def _render() -> tuple[np.ndarray, v2._Score, dict[str, object]]:
    rng = np.random.default_rng(90_601)
    brush_rng = np.random.default_rng(90_619)
    guard = v2._MotifGuard()
    score = v2._Score(BPM, SWING, "4/4; fixed A-A'-B-A score on swung eighths")
    score.meta.update({
        "piece_id": PIECE_ID,
        "title": TITLE,
        "form": "A1:1-8 | A2:9-16 | B:17-20 | A_return:21-28",
        "written_melody": _notated_score(),
        "authorship": "fixed original notes/rhythms/harmony; seeded performance microvariation only",
    })
    stem = np.zeros(round(SECONDS * SAMPLE_RATE), dtype=np.float64)

    # Harmony: full rolled chord at every harmonic unit, a quieter upper-dyad
    # renewal in the second bar, and one written offbeat answer on response bars.
    key_counter = 0
    unit_for_bar: dict[int, tuple[int, str, int, tuple[int, ...]]] = {}
    for unit in CHORD_UNITS:
        start_bar, name, duration_bars, voicing = unit
        score.chord(start_bar * BAR, name, duration_bars * BAR)
        for bar_index in range(start_bar, start_bar + duration_bars):
            unit_for_bar[bar_index] = unit
        guard.push("keys-top", voicing[-1])
        key_counter = v2._play_keys(
            stem, score, rng,
            at=start_bar * BAR + rng.uniform(-0.003, 0.006),
            voicing=voicing,
            decay=(1_350.0, 1_900.0),
            gain_scale=0.96 if start_bar < 8 else 1.0,
            seed_base=90_650, counter=key_counter, total=SECONDS,
        )
        if duration_bars == 2:
            second_bar = start_bar + 1
            key_counter = v2._play_keys(
                stem, score, rng,
                at=second_bar * BAR + rng.uniform(0.002, 0.010),
                voicing=voicing[-2:],
                decay=(950.0, 1_350.0), gain_scale=0.58,
                seed_base=90_650, counter=key_counter, total=SECONDS,
            )

    for bar_index in sorted(SYNCOPATED_COMP_BARS):
        _, _, _, voicing = unit_for_bar[bar_index]
        key_counter = v2._play_keys(
            stem, score, rng,
            at=_pos(bar_index * BAR, 3) + rng.uniform(0.006, 0.014),
            voicing=voicing[-2:], decay=(780.0, 1_100.0), gain_scale=0.34,
            seed_base=90_650, counter=key_counter, total=SECONDS,
        )

    # Bass: the approved two-feel on every bar.  Chord boundaries get the
    # existing two-note diatonic walk; interior bars keep the fifth on beat 4.
    bass_counter = 0
    chord_change_after = {
        start_bar + duration_bars - 1 for start_bar, _, duration_bars, _ in CHORD_UNITS
    }
    for bar_index, name in enumerate(PROGRESSION):
        root = int(v2.CHORDS[name]["bass"])
        next_name = PROGRESSION[bar_index + 1] if bar_index + 1 < len(PROGRESSION) else "Bm9"
        walk_to = int(v2.CHORDS[next_name]["bass"]) if bar_index in chord_change_after else None
        bass_counter = v2._bass_two_feel(
            stem, score, rng,
            bar_t=bar_index * BAR, beat=BEAT, swing=SWING, root=root,
            walk_to=walk_to, drag=rng.uniform(0.010, 0.020),
            seed_base=91_300, counter=bass_counter, total=SECONDS,
        )

    # The umbrella kit, now present from the opening bar.  Section dynamics
    # are arranged, while every hit retains the approved 10-25 ms drag.
    for bar_index in range(len(PROGRESSION)):
        section = _section_for_bar(bar_index)
        section_gain = {"A1": 0.86, "A2": 0.95, "B": 0.78, "A_return": 1.0}[section]
        for eighth, base_velocity in ((0, 0.94), (4, 0.80)):
            velocity = base_velocity * section_gain * rng.uniform(0.94, 1.04)
            at = _pos(bar_index * BAR, eighth) + rng.uniform(0.010, 0.025)
            hit = v2._thump(rng)
            world._place(stem, hit, at, v2.THUMP_GAIN * velocity)
            score.hit(at, "thump", velocity, len(hit) / SAMPLE_RATE * 1000.0)
        for eighth in (2, 6):
            velocity = 0.75 * section_gain * rng.uniform(0.94, 1.04)
            at = _pos(bar_index * BAR, eighth) + rng.uniform(0.010, 0.025)
            hit = v2._rim(rng)
            world._place(stem, hit, at, v2.RIM_GAIN * velocity)
            score.hit(at, "rim", velocity, len(hit) / SAMPLE_RATE * 1000.0)

        # One missing last offbeat at each section edge gives the hand room to
        # turn the phrase over.  Otherwise the brush is a steady swung eighth.
        for eighth in range(8):
            if bar_index in BRUSH_BREATHS and eighth == 7:
                continue
            velocity = (
                brush_rng.uniform(0.50, 0.70)
                if eighth % 2 == 0
                else brush_rng.uniform(0.32, 0.50)
            ) * section_gain
            at = _pos(bar_index * BAR, eighth) + brush_rng.uniform(0.008, 0.020)
            grain = v2._shaker_grain(brush_rng)
            world._place(stem, grain, at, v2.SHAKER_GAIN * velocity)
            score.hit(at, "shaker", velocity, len(grain) / SAMPLE_RATE * 1000.0)

    # Melody: each written note arrives just behind its swung grid point.
    # `_play_lead` is the exact approved umbrella lead voice; only the score is
    # new.  A2 is slightly held back so the literal A return reads clearly.
    lead_counter = 0
    first_melody_time = None
    for section_name, start_bar, written_bars in SECTIONS:
        section_scale = {"A1": 0.98, "A2": 0.92, "B": 0.94, "A_return": 1.0}[section_name]
        for local_bar, events in enumerate(written_bars):
            bar_index = start_bar + local_bar
            for eighth, midi, duration_beats, nominal_velocity in events:
                safe_midi = guard.vet("lead", midi, substitute=71)
                at = _pos(bar_index * BAR, eighth) + rng.uniform(0.012, 0.026)
                first_melody_time = at if first_melody_time is None else min(first_melody_time, at)
                decay_ms = min(900.0, 300.0 + duration_beats * 270.0)
                velocity = nominal_velocity * section_scale * rng.uniform(0.96, 1.035)
                v2._play_lead(
                    stem, score, rng,
                    t=at, midi=safe_midi, vel=velocity, decay_ms=decay_ms,
                    seed=92_000 + lead_counter * 17, total=SECONDS,
                )
                lead_counter += 1

    bed = world._room_bus(stem, music.PHRASE_SEND)
    bed = music._calibrate(bed, TARGET_DBFS)
    bed = music._finish(bed, fade_seconds=2.2)
    true_peak = v2._true_peak(bed)
    if true_peak > world._db(-6.0):
        bed *= world._db(-6.2) / true_peak

    info = {
        "piece_id": PIECE_ID,
        "title": TITLE,
        "bpm": BPM,
        "swing": SWING,
        "bars": len(PROGRESSION),
        "program_seconds": round(len(PROGRESSION) * BAR, 4),
        "master_seconds": SECONDS,
        "form": "A1 (8) | A2 developed (8) | B (4) | A return (8)",
        "harmony": "Bm9 | F#m7(11) | A9sus | Em9, two bars each; bridge Gmaj9 | A13 | Dmaj9 | Em9",
        "arrangement": "approved rolled modal keys, written lead, two-feel bass, thump, papery rim, steady dark swung brush",
        "first_melody_onset_seconds": round(float(first_melody_time), 4),
        "lead_note_count": lead_counter,
    }
    return bed, score, info


def _motif_qc(score: v2._Score) -> dict[str, object]:
    by_voice: dict[str, list[int]] = {}
    for event in sorted(score.events, key=lambda item: (float(item["t"]), str(item["voice"]))):
        if event["midi"] is not None:
            by_voice.setdefault(str(event["voice"]), []).append(int(event["midi"]))
    matches = {
        voice: [
            index for index in range(len(notes) - 3)
            if tuple(notes[index:index + 4]) == RESERVED_MOTIF
        ]
        for voice, notes in by_voice.items()
    }
    matches = {voice: positions for voice, positions in matches.items() if positions}
    return {
        "reserved_motif": "D5-A5-E5-D5",
        "passed": not matches,
        "matches": matches,
        "voices_scanned": {voice: len(notes) for voice, notes in by_voice.items()},
    }


def _pitch_qc(score: v2._Score) -> dict[str, object]:
    offenders = [
        {"t": event["t"], "voice": event["voice"], "midi": event["midi"]}
        for event in score.events
        if event["midi"] is not None and int(event["midi"]) % 12 not in DIATONIC_PCS
    ]
    return {
        "law": "all pitched events diatonic to D major; interaction field D E F# A B remains a subset",
        "passed": not offenders,
        "offenders": offenders,
    }


def _form_qc(info: dict[str, object]) -> dict[str, object]:
    hook_bars = []
    for section_name, start_bar, written_bars in SECTIONS:
        for local_bar, events in enumerate(written_bars):
            rhythm = tuple(note[0] for note in events)
            if rhythm == (2, 3, 5, 6):
                hook_bars.append({"section": section_name, "bar": start_bar + local_bar + 1})
    exact_return = THEME_A == SECTIONS[-1][2]
    return {
        "expected_form": ["A1", "A2", "B", "A_return"],
        "actual_form": [name for name, _, _ in SECTIONS],
        "bars_by_section": [len(bars) for _, _, bars in SECTIONS],
        "hook_rhythm_occurrences": hook_bars,
        "hook_occurrence_count": len(hook_bars),
        "hook_arrives_early": float(info["first_melody_onset_seconds"]) < 1.0,
        "exact_eight_bar_return": exact_return,
        "passed": (
            [name for name, _, _ in SECTIONS] == ["A1", "A2", "B", "A_return"]
            and [len(bars) for _, _, bars in SECTIONS] == [8, 8, 4, 8]
            and len(hook_bars) >= 10
            and float(info["first_melody_onset_seconds"]) < 1.0
            and exact_return
        ),
    }


def _waveform_qc(audio: np.ndarray, score: v2._Score) -> dict[str, object]:
    peak = float(np.max(np.abs(audio)))
    phone_rms = world._phone_rms(audio)
    true_peak = v2._true_peak(audio)
    jumps: list[float] = []
    for event in score.events:
        if event["midi"] is None:
            continue
        end = round((float(event["t"]) + float(event["dur_ms"]) / 1000.0) * SAMPLE_RATE)
        if 1 <= end < len(audio):
            jumps.append(float(abs(audio[end] - audio[end - 1])))
    # Ignore the composed fade-out when checking that the bed does not fall
    # into accidental digital silence between phrases.
    window = round(0.5 * SAMPLE_RATE)
    body = audio[:round(93.0 * SAMPLE_RATE)]
    window_rms = [
        float(np.sqrt(np.mean(body[start:start + window] ** 2)))
        for start in range(0, max(1, len(body) - window + 1), window)
    ]
    return {
        "duration_seconds": round(len(audio) / SAMPLE_RATE, 6),
        "sample_peak": round(peak, 8),
        "sample_peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 3),
        "true_peak": round(true_peak, 8),
        "true_peak_dbfs": round(20 * math.log10(max(true_peak, 1e-12)), 3),
        "phone_band_rms_dbfs": round(20 * math.log10(max(phone_rms, 1e-12)), 3),
        "dc_offset": round(float(np.mean(audio)), 10),
        "max_mixed_note_end_sample_jump": round(max(jumps, default=0.0), 8),
        "minimum_half_second_rms_before_fade": round(min(window_rms, default=0.0), 9),
        "minimum_half_second_dbfs_before_fade": round(
            20 * math.log10(max(min(window_rms, default=0.0), 1e-12)), 3
        ),
        "passed": (
            abs(len(audio) / SAMPLE_RATE - SECONDS) < 1e-6
            and true_peak <= world._db(-6.0) + 1e-7
            and abs(20 * math.log10(max(phone_rms, 1e-12)) - TARGET_DBFS) <= 0.35
            and abs(float(np.mean(audio))) <= 1e-4
            and max(jumps, default=0.0) <= 0.02
            and min(window_rms, default=0.0) > world._db(-80.0)
        ),
    }


def _write_master(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def _write_hook(path: Path, audio: np.ndarray, seconds: float = 18.0) -> None:
    excerpt = audio[:round(seconds * SAMPLE_RATE)].copy()
    fade = round(0.7 * SAMPLE_RATE)
    excerpt[-fade:] *= np.cos(np.linspace(0.0, math.pi / 2.0, fade)) ** 2
    sf.write(path, excerpt, SAMPLE_RATE, subtype="PCM_24")


def _encode_aac(source: Path, target: Path) -> None:
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-fflags", "+bitexact",
        "-i", str(source), "-map_metadata", "-1", "-c:a", "aac",
        "-flags:a", "+bitexact", "-b:a", "96k", "-ar", str(SAMPLE_RATE),
        "-ac", "1", "-movflags", "+faststart", str(target),
    ], check=True)


def _render_spectrogram(source: Path, target: Path) -> None:
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-i", str(source),
        "-lavfi", "showspectrumpic=s=1600x900:legend=1:scale=log:color=channel",
        "-frames:v", "1", str(target),
    ], check=True)


def _probe(path: Path) -> dict[str, object]:
    result = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration:stream=codec_name,sample_rate,channels,bit_rate",
        "-of", "json", str(path),
    ], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def _lead_sheet_markdown(notated: dict[str, object]) -> str:
    lines = [
        f"# {TITLE} — auditable lead sheet",
        "",
        "Original Room of Days audition score. No imported sample, borrowed melody, or reference transcription.",
        "",
        f"- 4/4, {BPM:g} BPM, swung eighths at {SWING:.2f}",
        "- form: A1 (8 bars) | A2 developed (8 bars) | B (4 bars) | A return (8 bars)",
        "- hook rhythm: swung eighth positions 2, 3, 5, 6 — short, short, breath, short-long",
        "- pitch field: D major / B minor; C# and G remain diatonic colors",
        "- reserved interaction motif D5-A5-E5-D5 is excluded",
        "",
        "`beat` is one-indexed; `.5` denotes the swung offbeat after that beat.",
        "",
    ]
    for section in notated["sections"]:  # type: ignore[index]
        lines.extend((f"## {section['name']}", ""))
        for bar in section["bars"]:  # type: ignore[index]
            notes = " · ".join(
                f"{note['note']}@{note['beat']:g}({note['notated_duration_beats']:g}b)"
                for note in bar["notes"]
            )
            lines.append(f"- bar {bar['bar']:02d} · {bar['chord']}: {notes}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _readme() -> str:
    return f"""# {STUDY_ID} — {TITLE}

One original, fixed composition for owner audition beside the approved
umbrella-brush score. This answers the correction that the previous studies
were usable but did not feel like actual music with a memorable reason to
return.

## What is composed

- **A1, bars 1–8:** the hook arrives on beat 2 of the first bar. Bars 1–4 ask;
  bars 5–8 answer and return to B.
- **A2, bars 9–16:** the question repeats exactly; the answer makes one higher
  turn, then settles.
- **B, bars 17–20:** one chord per bar and a broader rhythm reach the piece's
  single B5 high point, then step back toward the opening.
- **A return, bars 21–28:** the complete original eight-bar melody returns.

The rhythm, melody, harmony, and arrangement are fixed in the source and in
`{PIECE_ID}-score.json`. Seeds vary only microtiming, velocity, oscillator
phase, and brush grains. The sound graph is the approved umbrella-brush graph:
modal rolled keys and lead, two-feel bass, thump, papery rim, dark swung brush,
and the Room's close three-reflection bus. No samples are imported. The named
Toby Fox tracks are a structural and emotional reference only; no melody or
audio is borrowed or transcribed.

## Files

- `{PIECE_ID}-master.wav` — 96 s, mono 48 kHz PCM24 master
- `{PIECE_ID}.m4a` — full 96 s AAC audition
- `{PIECE_ID}-hook-18s.wav` / `.m4a` — opening hook excerpt
- `{PIECE_ID}-score.json` — every sounding note/hit plus the written form
- `LEAD-SHEET.md` — readable bar-by-bar melody
- `qc.json` and `sonic-taste-gate-qc.json` — structural and technical checks
- `spectrogram.png` — rendered full-program inspection

Technical validity does not establish whether the melody is lovable or gets
stuck in the listener's head. That remains the owner's phone/headphone
audition gate. Nothing here changes the runtime bundle.
"""


def build_study(output: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    audio, score, info = _render()

    master = output / f"{PIECE_ID}-master.wav"
    aac = output / f"{PIECE_ID}.m4a"
    hook_master = output / f"{PIECE_ID}-hook-18s.wav"
    hook_aac = output / f"{PIECE_ID}-hook-18s.m4a"
    score_path = output / f"{PIECE_ID}-score.json"
    lead_sheet_path = output / "LEAD-SHEET.md"
    qc_path = output / "qc.json"
    gate_qc_path = output / "sonic-taste-gate-qc.json"
    spectrogram_path = output / "spectrogram.png"
    readme_path = output / "README.md"

    _write_master(master, audio)
    _write_hook(hook_master, audio)
    _encode_aac(master, aac)
    _encode_aac(hook_master, hook_aac)
    _render_spectrogram(master, spectrogram_path)

    notated = _notated_score()
    score_path.write_text(json.dumps(score.as_dict(), indent=2) + "\n", encoding="utf-8")
    lead_sheet_path.write_text(_lead_sheet_markdown(notated), encoding="utf-8", newline="\n")
    readme_path.write_text(_readme(), encoding="utf-8", newline="\n")

    checks = {
        "waveform": _waveform_qc(audio, score),
        "pitch_field": _pitch_qc(score),
        "reserved_motif": _motif_qc(score),
        "form_and_hook": _form_qc(info),
    }
    checks["passed"] = all(bool(check["passed"]) for check in checks.values())
    qc_path.write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
    if not checks["passed"]:
        raise ValueError(f"composition QC failed: {checks}")

    gate_qc = sonic_taste_gate.run_qc([str(master), str(hook_master)])
    gate_qc_path.write_text(json.dumps(gate_qc, indent=2) + "\n", encoding="utf-8")
    if gate_qc["summary"]["ok"] != 2:
        raise ValueError(f"sonic taste gate could not read both WAVs: {gate_qc}")

    source_paths: Iterable[Path] = (
        Path(__file__),
        Path("tool/author_room_music_study.py"),
        Path("tool/author_room_music_v2_study.py"),
        Path("tool/author_room_sonic_world_study.py"),
    )
    artifact_paths = (
        master, aac, hook_master, hook_aac, score_path, lead_sheet_path,
        qc_path, gate_qc_path, spectrogram_path, readme_path,
    )
    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "piece": info,
        "purpose": "one original authored musical sibling for review; no runtime or bundle edits",
        "source_policy": "fixed original score; no imported samples, borrowed melody, or reference transcription",
        "source_graph": {
            "keys_and_lead": "author_room_music_v2_study._play_keys/_play_lead and shared modal body",
            "bass": "author_room_music_v2_study._bass_two_feel",
            "groove": "author_room_music_v2_study._thump/_rim/_shaker_grain",
            "space": "Room close three-reflection bus",
            "pitch_law": "B minor inside D major; every pitch class diatonic to D major",
        },
        "dependency_sha256": {path.as_posix(): _sha256(path) for path in source_paths},
        "artifacts": {
            path.name: {
                "sha256": _sha256(path),
                **({"probe": _probe(path)} if path.suffix.lower() in (".wav", ".m4a") else {}),
            }
            for path in artifact_paths
        },
        "qc": checks,
        "approval": {
            "technically_valid": True,
            "semantically_mapped": True,
            "cohesive_in_audition_flow": "unverified — requires listening",
            "owner_phone_or_headphone_approved": False,
        },
    }
    manifest_path = output / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output), indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"author_room_music_new_theme: {error}", file=sys.stderr)
        raise SystemExit(2)
