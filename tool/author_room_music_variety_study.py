#!/usr/bin/env python3
"""Render two original, deterministic Room of Days music auditions.

This is deliberately an audition authoring tool.  It never touches the
runtime music bundle or its approval records.  The pieces share the Room's
reflection and loudness contracts, but their melodies, forms, harmony, and
felt-piano voice are composed here rather than derived from a reference track.

Run from the repository root:

    python tool/author_room_music_variety_study.py \
        --output design/audits/2026-09-01/goals-everyday-review/daily-review-and-music/audio
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_music_study as music
import author_room_music_v2_study as v2
import author_room_sonic_world_study as world


STUDY_ID = "daily-review-original-music-variety-v1"
RENDER_VERSION = "felt-piano-variety-author-v1"
SAMPLE_RATE = world.SAMPLE_RATE
TARGET_DBFS = v2.TARGET_DBFS
MOTIF = (74, 81, 76, 74)  # D5 A5 E5 D5: reserved reward identity.


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _hz(midi: int, cents: float = 0.0) -> float:
    return 440.0 * 2 ** ((midi - 69 + cents / 100.0) / 12.0)


def _felt_piano(
    midi: int,
    seconds: float,
    *,
    seed: int,
    velocity: float,
    onset_ms: float,
) -> np.ndarray:
    """A quiet, intentionally non-modal felt piano: fundamental first.

    Two gently detuned fundamentals supply width without stereo tricks; upper
    partials decay faster and sit well below the fundamental.  A 10--25 ms
    bloom removes the notification-like edge of a synthetic instant attack.
    """
    frames = max(1, round(seconds * SAMPLE_RATE))
    time = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    rng = np.random.default_rng(seed)
    onset = max(0.010, min(0.025, onset_ms / 1000.0))
    attack = 1.0 - np.exp(-time / onset)
    # Long low notes settle more slowly, but no unbounded sustained pad.
    base_decay = 2.4 + 1.55 * velocity + (0.75 if midi < 55 else 0.0)
    result = np.zeros(frames, dtype=np.float64)
    for detune, gain in ((-3.3, 0.62), (2.7, 0.55)):
        phase = rng.uniform(0.0, 2 * math.pi)
        result += gain * np.sin(2 * math.pi * _hz(midi, detune) * time + phase)
    for partial, gain, decay_scale in ((2, 0.105, 0.48), (3, 0.045, 0.30), (4, 0.016, 0.20)):
        phase = rng.uniform(0.0, 2 * math.pi)
        result += (
            gain
            * np.sin(2 * math.pi * _hz(midi) * partial * time + phase)
            * np.exp(-time / (base_decay * decay_scale))
        )
    result *= attack * np.exp(-time / base_decay)
    # Each placed voice owns a release.  The main array mixer otherwise cuts
    # an arbitrary nonzero waveform sample at its scheduled end, creating a
    # click that a whole-program fade cannot repair.
    release_seconds = min(0.35, max(0.15, seconds * 0.18))
    release_frames = min(frames, round(release_seconds * SAMPLE_RATE))
    if release_frames > 1:
        result[-release_frames:] *= np.cos(
            np.linspace(0, math.pi / 2, release_frames)
        ) ** 2
    # Felt removes brittle air but keeps enough upper body for a phone speaker.
    return world._filter(result, highpass_hz=105, lowpass_hz=3_650, order=2)


def _place_note(
    stem: np.ndarray,
    score: v2._Score,
    guard: v2._MotifGuard,
    *,
    at: float,
    midi: int,
    voice: str,
    velocity: float,
    seconds: float,
    seed: int,
    onset_ms: float,
) -> None:
    safe_midi = guard.vet(voice, midi, substitute=71)
    score.add(at, voice, safe_midi, velocity, seconds * 1000)
    world._place(
        stem,
        _felt_piano(
            safe_midi,
            seconds,
            seed=seed,
            velocity=velocity,
            onset_ms=onset_ms,
        ),
        at,
        velocity,
    )


def _place_chord(
    stem: np.ndarray,
    score: v2._Score,
    guard: v2._MotifGuard,
    *,
    at: float,
    name: str,
    tones: tuple[int, ...],
    duration: float,
    seed: int,
    velocity: float = 0.26,
    note_seconds: float | None = None,
) -> None:
    score.chord(at, name, duration)
    for index, midi in enumerate(tones):
        _place_note(
            stem,
            score,
            guard,
            at=at + index * 0.012,
            midi=midi,
            voice="harmony",
            velocity=velocity * (1.0 if index == 0 else 0.86),
            seconds=note_seconds if note_seconds is not None else min(duration * 0.72, 7.4),
            seed=seed + index * 19,
            onset_ms=18 + index,
        )


def _render_window_light() -> tuple[np.ndarray, v2._Score, dict[str, object]]:
    """48 BPM waltz: twelve two-bar harmonic fields and breathing phrases."""
    bpm, beats_per_bar, bars = 48.0, 3, 24
    beat, bar = 60 / bpm, 60 / bpm * beats_per_bar
    program_seconds = bars * bar
    score = v2._Score(bpm, None, "3/4, sparse felt-piano waltz")
    guard = v2._MotifGuard()
    stem = np.zeros(round((program_seconds + 6.0) * SAMPLE_RATE), dtype=np.float64)
    chords = (
        ("Dadd9", (50, 57, 64, 66)), ("Bm7", (47, 54, 57, 62)),
        ("Gmaj9", (43, 50, 54, 57)), ("Asus2", (45, 52, 57, 59)),
        ("Em9", (40, 47, 50, 54, 55)), ("Bm11", (47, 54, 57, 62, 64)),
        ("Gmaj7", (43, 50, 54, 59)), ("Dadd9/F#", (42, 50, 57, 64)),
        ("Em9", (40, 47, 50, 54, 55)), ("Aadd9", (45, 52, 59, 61)),
        ("Dadd9", (50, 57, 61, 64)), ("D6", (50, 57, 59, 66)),
    )
    for index, (name, tones) in enumerate(chords):
        at = index * 2 * bar
        _place_chord(stem, score, guard, at=at, name=name, tones=tones,
                     duration=2 * bar, seed=20_100 + index * 83,
                     note_seconds=13.0 if index == len(chords) - 1 else None)
        # A single interior touch makes the waltz breathe rather than pulse.
        if index not in (3, 7, 10):
            _place_note(stem, score, guard, at=at + bar + 0.12,
                        midi=tones[-2], voice="harmony", velocity=0.105,
                        seconds=2.7, seed=20_600 + index * 31, onset_ms=21)

    # Original upper register phrases.  Phrase gaps are compositional silence,
    # not a random omission.  The second half alters contour and resolution.
    phrases = (
        (1.08, ((66, 0.0), (64, 1.35), (69, 2.9))),
        (12.00, ((64, 0.0), (62, 1.45), (59, 3.15))),
        (31.00, ((66, 0.0), (69, 1.22), (71, 2.65), (69, 4.05))),
        (49.25, ((64, 0.0), (66, 1.25), (62, 2.75))),
        (67.60, ((71, 0.0), (69, 1.25), (66, 2.65), (64, 4.20))),
        (79.80, ((66, 0.0), (64, 1.45), (62, 2.9), (66, 4.25))),
    )
    for phrase_index, (start, notes) in enumerate(phrases):
        for note_index, (midi, offset) in enumerate(notes):
            _place_note(stem, score, guard, at=start + offset, midi=midi,
                        voice="window-light-melody", velocity=0.235,
                        seconds=4.2 if note_index == len(notes) - 1 else 3.1,
                        seed=21_200 + phrase_index * 101 + note_index * 17,
                        onset_ms=15 + note_index * 2)

    bed = world._room_bus(stem, 0.24)
    bed = music._finish(music._calibrate(bed, TARGET_DBFS), fade_seconds=2.0)
    return bed, score, {
        "id": "window-light",
        "title": "Window light",
        "form": "24 bars of 3/4 at 48 BPM (90 s) plus a 6 s tail",
        "arrangement": "sparse felt-piano harmony; six upper phrases with deliberate 1--2 bar rests",
        "harmony": [name for name, _ in chords],
    }


def _render_small_hours() -> tuple[np.ndarray, v2._Score, dict[str, object]]:
    """60 BPM 4/4 nocturne with a different form, motion and melody."""
    bpm, beats_per_bar, bars = 60.0, 4, 22
    beat, bar = 60 / bpm, 60 / bpm * beats_per_bar
    program_seconds = bars * bar
    score = v2._Score(bpm, None, "4/4, gentle two-note felt-piano accompaniment")
    guard = v2._MotifGuard()
    stem = np.zeros(round((program_seconds + 8.0) * SAMPLE_RATE), dtype=np.float64)
    chords = (
        ("G6", (43, 50, 52, 59)), ("Dadd9/F#", (42, 50, 57, 64)),
        ("Em7", (40, 47, 50, 55)), ("Bm7", (47, 54, 57, 62)),
        ("Cmaj9", (48, 55, 59, 62, 64)), ("Gadd9/B", (47, 50, 55, 57)),
        ("Am7", (45, 52, 55, 60)), ("Dsus2", (38, 45, 52, 57)),
        ("Em9", (40, 47, 50, 54, 55)), ("Cmaj9", (48, 55, 59, 62, 64)),
        ("G6", (43, 50, 52, 59)),
    )
    for chord_index, (name, tones) in enumerate(chords):
        chord_start = chord_index * 2 * bar
        # The sixth harmony would normally begin at 40 s. Delaying it to 44 s
        # leaves the complete 40--44 s bar with no new note onsets at all.
        harmony_at = chord_start + (bar if chord_index == 5 else 0.0)
        harmony_duration = bar if chord_index == 5 else 2 * bar
        _place_chord(stem, score, guard, at=harmony_at, name=name, tones=tones,
                     duration=harmony_duration, seed=30_100 + chord_index * 79,
                     velocity=0.19,
                     note_seconds=15.5 if chord_index == len(chords) - 1 else None)
        # Bar 11 (index 10) has no new accompaniment or melody onsets.
        for local_bar in range(2):
            bar_index = chord_index * 2 + local_bar
            if bar_index == 10:
                continue
            low, open_tone = tones[0], tones[-1]
            for hit_index, beat_offset in enumerate((0.0, 1.5, 3.0)):
                _place_note(stem, score, guard,
                            at=chord_start + local_bar * bar + beat_offset * beat,
                            midi=low if hit_index % 2 == 0 else open_tone,
                            voice="small-hours-accompaniment",
                            velocity=0.105 if hit_index != 1 else 0.085,
                            seconds=2.5, seed=31_000 + bar_index * 23 + hit_index,
                            onset_ms=20 + hit_index)

    # Independent lower melody: its first ascent is D--G--A--B, then the
    # answer falls E--D; later phrases change rhythm and destination.
    phrases = (
        (5.20, ((62, 0.0), (67, 1.25), (69, 2.65), (71, 4.05))),
        (12.10, ((64, 0.0), (62, 1.55), (59, 3.05))),
        (27.15, ((62, 0.0), (64, 1.4), (67, 2.8), (69, 4.25))),
        (46.20, ((59, 0.0), (62, 1.6), (64, 3.1))),
        (61.20, ((67, 0.0), (64, 1.45), (62, 2.75), (59, 4.15))),
        (76.35, ((62, 0.0), (67, 1.3), (64, 2.8), (62, 4.5))),
    )
    for phrase_index, (start, notes) in enumerate(phrases):
        for note_index, (midi, offset) in enumerate(notes):
            _place_note(stem, score, guard, at=start + offset, midi=midi,
                        voice="small-hours-melody", velocity=0.205,
                        seconds=3.3 if note_index < len(notes) - 1 else 4.6,
                        seed=32_000 + phrase_index * 97 + note_index * 13,
                        onset_ms=16 + note_index)

    bed = world._room_bus(stem, 0.24)
    bed = music._finish(music._calibrate(bed, TARGET_DBFS), fade_seconds=2.4)
    return bed, score, {
        "id": "small-hours",
        "title": "Small hours",
        "form": "22 bars of 4/4 at 60 BPM (88 s) plus an 8 s tail",
        "arrangement": "no percussion; two-note accompaniment at beats 0, 1.5, and 3; one middle bar with no new notes",
        "harmony": [name for name, _ in chords],
    }


def _motif_check(score: v2._Score) -> dict[str, object]:
    by_voice: dict[str, list[int]] = {}
    for event in score.events:
        midi = event["midi"]
        if midi is not None:
            by_voice.setdefault(str(event["voice"]), []).append(int(midi))
    matches = {
        voice: [index for index in range(len(notes) - 3) if tuple(notes[index:index + 4]) == MOTIF]
        for voice, notes in by_voice.items()
    }
    matches = {voice: indices for voice, indices in matches.items() if indices}
    return {"reserved_motif": "D5-A5-E5-D5", "passed": not matches, "matches": matches}


def _metrics(audio: np.ndarray) -> dict[str, float]:
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    rms = float(np.sqrt(np.mean(audio * audio))) if len(audio) else 0.0
    tail_start = max(0, len(audio) - round(6 * SAMPLE_RATE))
    tail_end = max(tail_start + 1, len(audio) - round(2 * SAMPLE_RATE))
    tail = audio[tail_start:tail_end]
    tail_rms = float(np.sqrt(np.mean(tail * tail))) if len(tail) else 0.0
    return {
        "duration_seconds": round(len(audio) / SAMPLE_RATE, 4),
        "peak": round(peak, 7),
        "peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 3),
        "dc_offset": round(float(np.mean(audio)), 9),
        "rms": round(rms, 8),
        "phone_band_rms_dbfs": round(20 * math.log10(max(world._phone_rms(audio), 1e-12)), 3),
        "pre_final_fade_tail_rms": round(tail_rms, 8),
    }


def _seam_qc(audio: np.ndarray, score: v2._Score) -> dict[str, object]:
    """Check the mixed WAV at each scheduled pitched-note end.

    This does not claim perceptual approval. It catches the mechanical fault
    this study is susceptible to: a placed waveform ending on a nonzero sample.
    """
    jumps: list[float] = []
    for event in score.events:
        if event["midi"] is None:
            continue
        end = round((float(event["t"]) + float(event["dur_ms"]) / 1000) * SAMPLE_RATE)
        if 1 <= end < len(audio):
            jumps.append(float(abs(audio[end] - audio[end - 1])))
    maximum = max(jumps, default=0.0)
    terminal = float(abs(audio[-1] - audio[-2])) if len(audio) > 1 else 0.0
    return {
        "checked_note_ends": len(jumps),
        "max_mixed_sample_jump": round(maximum, 8),
        "terminal_sample_jump": round(terminal, 8),
        "threshold": 0.02,
        "passed": maximum <= 0.02 and terminal <= 0.002,
    }


def _encode(source: Path, m4a: Path, excerpt: Path) -> None:
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-i", str(source), "-c:a", "aac",
        "-b:a", "96k", "-ar", "48000", "-ac", "1", str(m4a),
    ], check=True)
    subprocess.run([
        "ffmpeg", "-y", "-v", "error", "-i", str(source), "-t", "12",
        "-c:a", "libmp3lame", "-b:a", "64k", "-ar", "24000", "-ac", "1", str(excerpt),
    ], check=True)


def build_study(output: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    renderers = (_render_window_light, _render_small_hours)
    dependency_paths = (
        Path(__file__), Path("tool/author_room_music_study.py"),
        Path("tool/author_room_music_v2_study.py"), Path("tool/author_room_sonic_world_study.py"),
    )
    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "purpose": "original audition-only composition variety; no runtime asset integration",
        "sample_rate_hz": SAMPLE_RATE,
        "target_phone_band_dbfs": TARGET_DBFS,
        "room_synthesis_dependencies": {
            str(path).replace("\\", "/"): _sha256(path) for path in dependency_paths
        },
        "source_policy": "explicitly authored notes and forms; no imported recordings, samples, melodies, or arrangement transcription",
        "candidates": {},
    }
    for renderer in renderers:
        audio, score, info = renderer()
        candidate_id = str(info["id"])
        wav = output / f"{candidate_id}.wav"
        m4a = output / f"{candidate_id}.m4a"
        excerpt = output / f"{candidate_id}-excerpt-12s.mp3"
        score_path = output / f"{candidate_id}-score.json"
        music._write_16(wav, audio)
        score_path.write_text(json.dumps(score.as_dict(), indent=2) + "\n", encoding="utf-8")
        _encode(wav, m4a, excerpt)
        entry = dict(info)
        entry.update({
            "wav": wav.name, "m4a": m4a.name, "excerpt_mp3": excerpt.name,
            "score": score_path.name, "score_sha256": _sha256(score_path),
            "source_sha256": {wav.name: _sha256(wav), m4a.name: _sha256(m4a), excerpt.name: _sha256(excerpt)},
            "quality": _metrics(audio), "motif_check": _motif_check(score),
            "seam_qc": _seam_qc(audio, score),
            "event_counts": {
                "pitched": sum(event["midi"] is not None for event in score.events),
                "unpitched": sum(event["midi"] is None for event in score.events),
            },
        })
        if not entry["motif_check"]["passed"]:
            raise ValueError(f"reserved reward motif appeared in {candidate_id}")
        if not entry["seam_qc"]["passed"]:
            raise ValueError(f"note-end discontinuity check failed in {candidate_id}")
        if entry["quality"]["peak"] > world._db(-6.0) + 1e-6:
            raise ValueError(f"peak exceeds -6 dBFS in {candidate_id}")
        manifest["candidates"][candidate_id] = entry
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output), indent=2))


if __name__ == "__main__":
    main()
