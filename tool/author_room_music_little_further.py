#!/usr/bin/env python3
"""An original Room score: felt keys finding a little forward motion.

Uses the project's original felt-piano synthesis, the approved umbrella's
muted bass/brush voices, and its close room reflections. No imported samples
or reference melody. The composition is fixed and auditable; seeded timing
and velocity give this one performance a human scale, not infinite variety.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess

import numpy as np
import soundfile as sf

import author_room_music_study as music
import author_room_music_v2_study as v2
import author_room_music_variety_study as piano
import author_room_sonic_world_study as world

SR = world.SAMPLE_RATE
SECONDS = 96.0
TARGET = music.TARGET_DBFS


def render():
    rng = np.random.default_rng(60_906)
    beat, bar = 60 / 72, 60 / 72 * 4
    score = v2._Score(72, 0.56, '4/4, felt keys with a restrained brush two-feel')
    guard = v2._MotifGuard()
    stem = np.zeros(round(SECONDS * SR))
    chords = (
        ('Dmaj9', (50, 57, 61, 66)), ('D6add9', (50, 57, 59, 64)),
        ('Gmaj9', (43, 50, 54, 59)), ('G6', (43, 50, 52, 59)),
        ('Bm9', (47, 54, 57, 62)), ('Bm11', (47, 54, 62, 64)),
        ('A9sus', (45, 52, 55, 59)), ('A13', (45, 52, 61, 66)),
        ('Dmaj9', (50, 57, 61, 66)), ('Gmaj9', (43, 50, 54, 59)),
        ('Em9', (40, 47, 54, 62)), ('A9sus', (45, 52, 59, 62)),
        ('D6add9', (50, 57, 59, 64)), ('Dmaj9', (50, 57, 61, 66)),
    )
    # Four-bar invitation, eight-bar first phrase, four-bar breath,
    # eight-bar answer, then a four-bar quiet return.
    score.meta['form'] = [
        {'bars': [0, 3], 'role': 'invitation, keys alone'},
        {'bars': [4, 11], 'role': 'first phrase, bass and brush arrive'},
        {'bars': [12, 15], 'role': 'breath, percussion rests'},
        {'bars': [16, 23], 'role': 'answer, a small returning groove'},
        {'bars': [24, 27], 'role': 'quiet return, no new percussion'},
    ]
    for i, (name, tones) in enumerate(chords):
        at = i * bar * 2
        piano._place_chord(stem, score, guard, at=at, name=name, tones=tones,
                           duration=2 * bar, seed=61_000 + i * 97,
                           velocity=0.18 if i in (0, 1, 6, 7, 12, 13) else 0.21,
                           note_seconds=7.8 if i == 13 else 5.0)
        if i not in (0, 6, 7, 13):
            piano._place_note(stem, score, guard, at=at + bar + beat * 0.56,
                              midi=tones[-2], voice='felt-answer', velocity=0.072,
                              seconds=2.3, seed=62_000 + i * 41, onset_ms=22)

    # A written theme and response. The intervals return, but the second
    # appearance changes its destination; the reward's four-note signature
    # is never part of the accompaniment.
    phrases = (
        (2, ((0.5, 66), (1.56, 69), (3, 71), (4.56, 69), (6, 64))),
        (8, ((1, 64), (2.56, 66), (4, 62), (5.56, 59), (7, 62))),
        (16, ((0.5, 66), (1.56, 69), (3, 71), (4.56, 69), (6, 66))),
        (22, ((0.5, 64), (2, 69), (3.56, 66), (5, 64), (6.56, 62))),
    )
    for p, (start_bar, notes) in enumerate(phrases):
        for n, (offset, midi) in enumerate(notes):
            piano._place_note(stem, score, guard,
                              at=start_bar * bar + offset * beat + rng.uniform(.008, .018),
                              midi=midi, voice='little-further-theme',
                              velocity=.19 if n == len(notes) - 1 else .17,
                              seconds=4.2 if n == len(notes) - 1 else 2.9,
                              seed=63_000 + p * 103 + n * 19, onset_ms=17 + n)

    for b in (*range(4, 12), *range(16, 24)):
        at = b * bar
        root = chords[b // 2][1][0]
        # The same umbrella bass, played half as often and lower in the mix.
        for k, (offset, midi) in enumerate(((0, root + 12), (2.56, root + 19))):
            v2._play_bass_note(stem, score, rng, t=at + offset * beat + .018,
                               midi=midi, vel=.29 if k == 0 else .17,
                               decay_ms=390, seed=64_000 + b * 31 + k, total=SECONDS)
        for offset, velocity in ((0, .45), (2, .25)):
            hit = v2._thump(rng)
            onset = at + offset * beat + .018
            world._place(stem, hit, onset, v2.THUMP_GAIN * velocity)
            score.hit(onset, 'felt-thump', velocity, len(hit) / SR * 1000)
        for eighth in (0, 2, 3, 4, 6, 7):
            offset = eighth // 2 + (0.56 if eighth % 2 else 0)
            onset = at + offset * beat + rng.uniform(.012, .021)
            brush = v2._shaker_grain(rng)
            velocity = .35 if eighth % 2 == 0 else .23
            world._place(stem, brush, onset, v2.SHAKER_GAIN * velocity)
            score.hit(onset, 'dark-brush', velocity, len(brush) / SR * 1000)

    bed = world._room_bus(stem, .24)
    bed = music._finish(music._calibrate(bed, TARGET), fade_seconds=2)
    # A short front fade protects a file start without delaying its music.
    front = round(.012 * SR)
    bed[:front] *= np.sin(np.linspace(0, math.pi / 2, front)) ** 2
    return bed, score


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    bed, score = render()
    wav = args.output / 'a-little-further.wav'
    encoded = args.output / 'a-little-further.m4a'
    sf.write(wav, bed, SR, subtype='PCM_24')
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(wav), '-c:a', 'aac',
                    '-b:a', '96k', '-ar', str(SR), '-movflags', '+faststart',
                    str(encoded)], check=True)
    (args.output / 'a-little-further-score.json').write_text(
        json.dumps(score.as_dict(), indent=2) + '\n', encoding='utf-8')
    report = {
        'id': 'a-little-further', 'title': 'A little further',
        'render_version': 'little-further-author-v1', 'seconds': len(bed) / SR,
        'peak_dbfs': round(20 * math.log10(max(np.max(np.abs(bed)), 1e-12)), 3),
        'phone_band_rms_dbfs': round(20 * math.log10(world._phone_rms(bed)), 3),
        'dc': float(np.mean(bed)), 'sample_rate': SR,
        'source_graph': {
            'body': 'original felt piano from author_room_music_variety_study',
            'bass_and_brush': 'original approved umbrella voice recipes from author_room_music_v2_study',
            'space': 'shared Room early reflection bus, send 0.24',
            'score': 'original written theme, harmony and form in this script',
        },
        'masters': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (wav, encoded)},
        'approval': {'technical': 'pending', 'cohesion': 'pending', 'physical_device': 'pending'},
    }
    (args.output / 'manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
