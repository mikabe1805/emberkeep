#!/usr/bin/env python3
"""Author the class-day score: the beds and thirty-two swells for the app.

Written 2026-10-11. The owner heard a music sketch on the listening page
(C:/tmp/cdj/sound-v3, "umbrella and brush", 72 BPM, a 16-bar form) and said
"also changing the music after you marked a class was super cool". In the
sketch, pressing "You marked a class" brings the bass and a night bell in
for two bars, on the beat, then settles back. This tool turns that sketch
into the files the app plays. It adds no new instrument and no sample.

What the sketch does at run time and what the app can do are not the same.
The sketch loops five stems on one Web Audio clock. The app's audio plugin
has no loop points, no start-at-time and no shared clock, so the app plays
PRE-MIXED files instead (see lib/class_day_score.dart):

  * bed_between_P.m4a and bed_evening_P.m4a, for P = 0 to 5: one 16-bar pass
    each, UNFOLDED. The stems are rendered with their natural tail and the
    tail is kept (6.5 s) instead of being folded back onto the start. The app
    starts the next pass exactly one form (53.333 s) after the last one began,
    while the first rings out, so two chained passes add up to the sketch's
    circular loop sample for sample.
  * swell_00.m4a to swell_31.m4a: two bars of bass and busy night bells cut
    from the same circular stems at every strong beat (beat 1 and 3 of every
    bar, 32 of the form's 64 beats), so the bass follows the chords wherever
    the class is marked. The envelope is baked in: a 120 ms cosine rise that
    completes on the beat, a hold for two bars, then the sketch's 0.55 s
    release.

PERFORMANCES. One 53 s form repeating all class day is the failure the owner
already named in the room's music, so the beds are recorded in six
performances of the same song. They SHARE the harmonic skeleton: the same
chords in the same bars, and the very same bass line (the sketch's bass stem,
byte for byte), so all thirty-two swells are valid over every performance. A
performance changes only what sits on top: which voicings the keys pick and
where they land in the bar, the second hits, a few short pentatonic figures,
the brushes' pattern, and where the Evening's slow night bells fall. Each
control is the sketch's own (a seed, the voicing pick, the pickup chord, the
ghost thump, the skipped grain) made into a parameter; performance 0 is the
sketch note for note. The app walks the performances in a shuffled order
(PerformanceWalk in lib/class_day_score_clock.dart). See PERFORMANCES below.

The five stems are rendered by the sketch's own renderer, carried over below
(render_music.py, with only the final fold() moved out of each render
function so the unfolded signal is also available). `--check` proves the
stems still match the sketch's (and the hashes this tool recorded).

Run from the worktree root:

    python tool/author_class_day_score.py            # write the 44 files + manifest
    python tool/author_class_day_score.py --check    # no writes: prove the shipped
                                                     # files are this recipe's output
    python tool/author_class_day_score.py --sketch C:/tmp/cdj/sound-v3
                                                     # also compare the stems to the
                                                     # sketch's own stem files

Needs numpy, scipy, soundfile and ffmpeg. Outputs: assets/music/class_day/*.m4a
(AAC-LC 96 kbps 48 kHz mono, like the app's other music) and
design/audits/2026-10-11/class-day-score/manifest.json.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import NamedTuple

import numpy as np
import soundfile as sf
from scipy.signal import lfilter

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import author_room_music_study as music  # noqa: E402
import author_room_music_v2_study as v2  # noqa: E402
import author_room_sonic_world_study as world  # noqa: E402

OUT_DIR = ROOT / "assets/music/class_day"
AUDIT_DIR = ROOT / "design/audits/2026-10-11/class-day-score"
MANIFEST = AUDIT_DIR / "manifest.json"
DEFAULT_SKETCH = Path("C:/tmp/cdj/sound-v3")

# ---------------------------------------------------------------------------
# The sketch's form (render_music.py, carried over unchanged)
# ---------------------------------------------------------------------------

SR = world.SAMPLE_RATE  # 48000
BPM = 72.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
SWING = 0.57
BARS = 16
N = round(BARS * BAR * SR)  # 2,560,000 frames = 53.333 s
TAIL_S = 10.0
L = N + round(TAIL_S * SR)
TOTAL = L / SR

# 16 bars: A section (8) then B section with the one-bar bridge chords (8)
CHORD_BARS = [
    "Bm9", "Bm9", "F#m7(11)", "F#m7(11)", "A9sus", "A9sus", "Em9", "Em9",
    "Bm9", "Bm9", "F#m7(11)", "F#m7(11)", "Gmaj9", "A13", "Dmaj9", "Em9",
]
UNIT_STARTS = [0, 2, 4, 6, 8, 10, 12, 13, 14, 15]


def pos(bar_t, eighths):
    return bar_t + (eighths // 2) * BEAT + (SWING * BEAT if eighths % 2 else 0.0)


def fold(buf):
    """Fold the tail back onto the start: the loop is circular."""
    out = buf[:N].copy()
    tail = buf[N:]
    out[: len(tail)] += tail
    return out


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def rc_rise(n):
    x = np.arange(n) / max(n, 1)
    return 0.5 - 0.5 * np.cos(math.pi * x)


# ---------------------------------------------------------------- performances
#
# The score is ONE song (the 16 bars, the chords, the bass line) and several
# PERFORMANCES of it. A performance changes only what sits on top of the bass:
# which voicings the keys pick and where they land in the bar, the short
# pentatonic figures the keys sometimes answer with, the brushes' pattern, and
# where the night bells fall in the Evening. The controls below are the
# sketch's own (seeds, the voicing pick, the pickup chord, the ghost thump, the
# skipped grain), made into parameters. SKETCH_* is the performance the owner
# heard on the listening page: with those controls the renderers below make
# the sketch's stems sample for sample, and performance 0 is exactly that.
#
# Nothing here is new synthesis: the same keys body (v2._play_keys), the same
# thump, rim and grain, the same bell. No sample.


class KeysControls(NamedTuple):
    seed: int = 14_100  # the voicing picks and the hit timing
    sound_seed: int = 14_110  # the keys body's own noise (v2._play_keys seed_base)
    keep_p: float = 0.4  # bar 2 of a unit repeats the whole voicing, else its top two
    lay: tuple[float, float] = (-0.004, 0.008)  # where a bar's chord lands against its beat
    pickups: tuple[tuple[int, float], ...] = ((3, 0.5),)  # (swung eighth, chance) second hits
    pickup_lay: tuple[float, float] = (-0.003, 0.008)
    pickup_gain: float = 0.5
    decay_scale: float = 1.0  # < 1 is a drier, closer touch (the tail only gets shorter)
    figure_p: float = 0.0  # chance, per bar, of a short pentatonic figure
    figure_shapes: tuple[str, ...] = ()
    figure_slots: tuple[int, ...] = ()  # swung eighths a figure may start on
    figure_seed: int = 0
    figure_gain: float = 0.6
    avoid_busy_bells: bool = False  # keep second hits off the slots the swell's bells sound on


class BrushControls(NamedTuple):
    seed: int = 14_400  # thump and rim
    grain_seed: int = 14_490  # the shaker grains
    ghost_p: float = 0.30  # chance of a soft extra thump each bar
    ghost_slot: int = 7
    two_keep: float = 1.0  # chance the thump on beat 3 sounds
    rim_keep: float = 1.0  # chance each backbeat rim sounds
    rim_ghost_p: float = 0.0  # chance of a very soft extra rim each bar
    rim_ghost_slot: int = 5
    shaker_skip: float = 0.05
    thin_bars: tuple[int, ...] = ()  # bars where the shaker breathes (skips more)
    accent: str = "beats"  # "beats" | "offbeats" | "flat": where the shaker leans
    arc: tuple[float, ...] | None = None  # per-bar shaker level over the 16 bars
    var_seed: int = 0  # the draws only a varied pattern needs


class BellsControls(NamedTuple):
    seed: int
    placements: tuple[tuple[int, int, int, float], ...]  # (bar, swung eighth, midi, velocity)


SKETCH_KEYS = KeysControls()
SKETCH_BRUSHES = BrushControls()

# Slow night bells for the Evening: hand-placed, chord-aware, gentle (A5 B5 D6
# only, as the sketch's), none after bar 14 so the tail dies before the next pass.
BELLS_SLOW = (
    (0, 2, 81, 0.62), (3, 2, 83, 0.60), (6, 2, 86, 0.62), (8, 5, 83, 0.58),
    (11, 2, 81, 0.60), (14, 2, 86, 0.60),
)
SKETCH_BELLS = BellsControls(14_600, BELLS_SLOW)

FIGURE_SHAPES = {  # steps along the chord's pentatonic tones: three notes, or two
    "rise": (1, 1),
    "fall": (-1, -1),
    "turn": (1, -1),
    "dip": (-1, 1),
    "leap": (2, -1),
    "echo": (0,),
    "step": (1,),
}
FIGURE_REGISTER = (62, 76)  # D4 to E5: the keys' own range, under the busy bells
FIGURE_LAST_BAR = 14  # a figure on the last bar would still be ringing into the next pass


class Performance(NamedTuple):
    index: int
    name: str
    feel: str  # one plain sentence on how it plays
    keys: KeysControls
    brushes: BrushControls
    bells: BellsControls


# The swell's busy bells are fixed (the swells are shared); a figure keeps off
# the slots they sound on.
BELLS_BUSY = [  # (bar, swung eighth, midi, velocity): hand-placed, chord-aware, all pentatonic
    (1, 3, 86, 0.70), (3, 3, 90, 0.75), (3, 7, 88, 0.50), (5, 5, 83, 0.60), (7, 3, 86, 0.70),
    (9, 3, 90, 0.70), (11, 5, 88, 0.55), (12, 4, 83, 0.60), (13, 3, 90, 0.70), (14, 3, 93, 0.65),
    (14, 7, 90, 0.45), (15, 5, 88, 0.60),
]
BUSY_SLOTS = frozenset((bar, e) for bar, e, _m, _v in BELLS_BUSY)


def figure_pool(chord):
    """The chord's pentatonic tones in the keys' range: what a figure walks on."""
    pcs = set(v2.CHORDS[chord]["pcs"])
    lo, hi = FIGURE_REGISTER
    return [m for m in range(lo, hi + 1) if m % 12 in v2.PENT_PCS and m % 12 in pcs]


def plan_figures(c: KeysControls):
    """bar -> [(swung eighth, midi), ...], drawn from the figure seed alone, so
    adding or moving a figure never changes the chords around it."""
    plan = {}
    if c.figure_p <= 0 or not c.figure_shapes:
        return plan
    rng = np.random.default_rng(c.figure_seed)
    last = -9
    for b, name in enumerate(CHORD_BARS):
        roll = rng.random()
        shape = c.figure_shapes[int(rng.integers(len(c.figure_shapes)))]
        slot = c.figure_slots[int(rng.integers(len(c.figure_slots)))]
        pick = float(rng.random())
        if roll >= c.figure_p or b > FIGURE_LAST_BAR or b - last < 2:
            continue
        steps = FIGURE_SHAPES[shape]
        pool = figure_pool(name)
        walks = []
        for start in range(len(pool)):
            idx = [start]
            for s in steps:
                idx.append(idx[-1] + s)
            if all(0 <= i < len(pool) for i in idx):
                walks.append(idx)
        if not walks or slot + len(steps) > 7:
            continue
        walk = walks[int(pick * len(walks)) % len(walks)]
        slots = [slot + i for i in range(len(walk))]
        if any((b, e) in BUSY_SLOTS for e in slots):
            continue
        plan[b] = [(e, pool[i]) for e, i in zip(slots, walk)]
        last = b
    return plan


# Gentle bell pools by chord (the sketch's): a slow bell is one of these.
BELL_POOL = {
    "Bm9": (81, 83, 86, 90),
    "F#m7(11)": (81, 83, 88, 90),
    "A9sus": (81, 83, 86, 88),
    "Em9": (83, 86, 88, 90),
    "Gmaj9": (83, 86, 90, 93),
    "A13": (81, 86, 88, 90),
    "Dmaj9": (81, 86, 90, 93),
}

PERFORMANCES = (
    Performance(
        0, "the sketch",
        "The performance on the listening page, note for note.",
        SKETCH_KEYS, SKETCH_BRUSHES, SKETCH_BELLS,
    ),
    Performance(
        1, "charleston",
        "Nearly every bar gets a second hit on the and of two; the brushes keep the sketch's lean.",
        KeysControls(
            seed=15_100, sound_seed=15_110, keep_p=0.55, lay=(-0.002, 0.010),
            pickups=((3, 0.9),), pickup_lay=(-0.002, 0.010), avoid_busy_bells=True,
        ),
        BrushControls(seed=15_130, grain_seed=15_140, ghost_p=0.22, shaker_skip=0.04),
        BellsControls(15_160, (
            (1, 5, 86, 0.60), (3, 2, 81, 0.58), (5, 5, 83, 0.62),
            (7, 2, 86, 0.60), (10, 2, 83, 0.58), (13, 2, 86, 0.60),
        )),
    ),
    Performance(
        2, "open hand",
        "Fewer second hits and five short figures on the and of three; a lighter brush that breathes.",
        KeysControls(
            seed=15_200, sound_seed=15_210, lay=(0.0, 0.012), pickups=((3, 0.2),),
            figure_p=0.5, figure_shapes=("fall", "turn", "rise", "dip"), figure_slots=(5,),
            figure_seed=15_220, avoid_busy_bells=True,
        ),
        BrushControls(
            seed=15_230, grain_seed=15_240, ghost_p=0.15, two_keep=0.9, rim_keep=0.85,
            shaker_skip=0.16, thin_bars=(3, 7, 11), var_seed=15_250,
        ),
        BellsControls(15_260, (
            (0, 5, 86, 0.60), (2, 2, 83, 0.60), (5, 2, 81, 0.58), (8, 2, 86, 0.62),
            (9, 5, 83, 0.56), (12, 5, 86, 0.60), (14, 2, 81, 0.58),
        )),
    ),
    Performance(
        3, "late push",
        "The keys lay back and answer on the and of three, with four short figures on the and of one; the brushes lean on the offbeats.",
        KeysControls(
            seed=15_300, sound_seed=15_310, lay=(0.004, 0.016), pickups=((5, 0.6),),
            pickup_gain=0.45, figure_p=0.25, figure_shapes=("echo", "step"), figure_slots=(1,),
            figure_seed=15_322, figure_gain=0.55, avoid_busy_bells=True,
        ),
        BrushControls(
            seed=15_330, grain_seed=15_340, ghost_p=0.38, ghost_slot=5, shaker_skip=0.06,
            accent="offbeats",
        ),
        BellsControls(15_360, (
            (1, 2, 83, 0.60), (4, 5, 86, 0.62), (6, 5, 83, 0.58),
            (10, 5, 81, 0.58), (13, 5, 86, 0.60),
        )),
    ),
    Performance(
        4, "rolling",
        "A busier hand: second hits on the and of two and of three, four rising figures, ghost thumps and rims on the brushes.",
        KeysControls(
            seed=15_400, sound_seed=15_410, keep_p=0.25, pickups=((3, 0.55), (5, 0.35)),
            pickup_gain=0.45, figure_p=0.3, figure_shapes=("rise", "leap"), figure_slots=(5,),
            figure_seed=15_420, avoid_busy_bells=True,
        ),
        BrushControls(
            seed=15_430, grain_seed=15_440, ghost_p=0.45, shaker_skip=0.02, rim_ghost_p=0.35,
            accent="flat", var_seed=15_450,
        ),
        BellsControls(15_460, (
            (0, 2, 86, 0.60), (2, 5, 81, 0.60), (5, 5, 86, 0.58),
            (8, 2, 83, 0.58), (11, 5, 81, 0.58), (13, 5, 86, 0.60),
        )),
    ),
    Performance(
        5, "close and dry",
        "A drier, closer touch that repeats each voicing more often, four figures; the brushes are softer in the first half and fuller in the second.",
        KeysControls(
            seed=15_500, sound_seed=15_510, keep_p=0.7, decay_scale=0.8, pickups=((3, 0.35),),
            figure_p=0.35, figure_shapes=("turn", "dip", "fall"), figure_slots=(1, 5),
            figure_seed=15_520, avoid_busy_bells=True,
        ),
        BrushControls(
            seed=15_530, grain_seed=15_540, ghost_p=0.25, shaker_skip=0.08,
            arc=(0.85,) * 8 + (1.12,) * 8, thin_bars=(7,), var_seed=15_550,
        ),
        BellsControls(15_560, (
            (1, 2, 86, 0.60), (3, 5, 83, 0.58), (6, 2, 83, 0.62),
            (9, 5, 86, 0.58), (12, 2, 86, 0.60), (14, 2, 81, 0.60),
        )),
    ),
)
PERFORMANCE_COUNT = len(PERFORMANCES)


# ---------------------------------------------------------------- keys
def render_keys(c: KeysControls = SKETCH_KEYS, with_score: bool = False):
    rng = np.random.default_rng(c.seed)
    guard = v2._MotifGuard()
    score = v2._Score(BPM, SWING, "swung eighths")
    stem = np.zeros(L)
    kc = 0
    prev = None
    figures = plan_figures(c)
    decay_full = (1_400.0 * c.decay_scale, 2_000.0 * c.decay_scale)
    decay_pick = (1_000.0 * c.decay_scale, 1_500.0 * c.decay_scale)
    for b, name in enumerate(CHORD_BARS):
        new_unit = b >= 12 or b % 2 == 0
        if new_unit or prev is None:
            voicing = v2._pick_voicing(rng, guard, name, prev)
            prev = voicing
            gs = 1.0
        else:
            voicing = prev if rng.random() < c.keep_p else prev[-2:]
            gs = 0.65
        kc = v2._play_keys(
            stem, score, rng, at=b * BAR + rng.uniform(*c.lay),
            voicing=tuple(voicing), decay=decay_full, gain_scale=gs,
            seed_base=c.sound_seed, counter=kc, total=TOTAL,
        )
        score.chord(b * BAR, name, BAR)
        for eighth, chance in c.pickups:
            if rng.random() < chance:
                at = pos(b * BAR, eighth) + rng.uniform(*c.pickup_lay)
                if b in figures:
                    continue  # the figure has this bar's air
                if c.avoid_busy_bells and (b, eighth) in BUSY_SLOTS:
                    continue
                kc = v2._play_keys(
                    stem, score, rng, at=at,
                    voicing=tuple(prev[-2:]), decay=decay_pick, gain_scale=c.pickup_gain,
                    seed_base=c.sound_seed, counter=kc, total=TOTAL,
                )
    # Figures last, from their own generator and their own body counter.
    if figures:
        frng = np.random.default_rng(c.figure_seed + 1)
        fc = 1_000
        for b in sorted(figures):
            for eighth, midi in figures[b]:
                fc = v2._play_keys(
                    stem, score, frng,
                    at=pos(b * BAR, eighth) + frng.uniform(0.004, 0.016),
                    voicing=(midi,), decay=(1_000.0 * c.decay_scale, 1_500.0 * c.decay_scale),
                    gain_scale=c.figure_gain, seed_base=c.sound_seed, counter=fc, total=TOTAL,
                )
    out = world._room_bus(stem, music.PHRASE_SEND)
    return (out, score) if with_score else out


# ---------------------------------------------------------------- bass
def bass_note(midi, dur_s, tau_s, rng):
    """Upright-pizzicato-like bass that reads on a phone: the fundamental is
    kept for headphones, but the weight sits in harmonics 3 to 8 (about
    400 to 1300 Hz), which fade quickly like a plucked string. The ear
    rebuilds the pitch from the harmonic series even where the speaker cannot
    reproduce the root."""
    f = hz(midi)
    n = round(dur_s * SR)
    t = np.arange(n) / SR
    amps = np.array([0.36, 0.46, 0.48, 0.46, 0.34, 0.18, 0.08, 0.03])
    boost = 1.0
    if f < 130:
        boost = 2.3
    elif f < 180:
        boost = 1.7
    elif f < 230:
        boost = 1.35
    out = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * 2 ** (rng.uniform(-2.0, 2.0) / 1200)
        if fk > 1900:
            continue
        a = amps[k - 1] * (boost if fk >= 400 else 1.0)
        tau_k = tau_s / (1 + 0.8 * (k - 1))
        out += a * np.sin(2 * math.pi * fk * t + rng.uniform(0, 2 * math.pi)) * np.exp(-t / tau_k)
    atk = round(rng.uniform(0.008, 0.013) * SR)
    out[:atk] *= rc_rise(atk)
    out = world._filter(out, highpass_hz=55, lowpass_hz=1800, order=2)
    return out / (np.max(np.abs(out)) or 1)


def play_bass(stem, t, midi, vel, tau_ms, rng, gain=0.15):
    t = max(0.0, t)
    if t >= TOTAL - 0.15:
        return
    dur = min(tau_ms / 1000 * 4.0, TOTAL - t - 0.05, 2.2)
    world._place(stem, bass_note(midi, dur, tau_ms / 1000, rng), t, gain * vel)


def bass_two_feel(stem, rng, bar_t, root, walk_to, drag):
    def p(e):
        return pos(bar_t, e)

    ev = [
        (p(0), root, rng.uniform(0.85, 1.0), rng.uniform(380.0, 480.0)),
        (p(3), root + 12, rng.uniform(0.55, 0.72), rng.uniform(240.0, 320.0)),
    ]
    if walk_to is None:
        ev.append((p(6), v2.BASS_FIFTH[root], rng.uniform(0.7, 0.88), rng.uniform(320.0, 420.0)))
    else:
        w1, w2 = v2._bass_walk(rng, root, walk_to)
        ev.append((p(6), w1, rng.uniform(0.6, 0.78), rng.uniform(200.0, 280.0)))
        ev.append((p(7), w2, rng.uniform(0.6, 0.78), rng.uniform(200.0, 280.0)))
    for at, midi, vel, tau in ev:
        play_bass(stem, at + drag + rng.uniform(-0.005, 0.005), midi, vel, tau, rng)


def bass_bus(dry, send):
    """Room fingerprint with a low shelf kept (70 Hz), bass keeps its root."""
    direct = world._filter(dry, highpass_hz=60, lowpass_hz=2600, order=2)
    reflected = world._filter(direct, highpass_hz=210, lowpass_hz=3000, order=2)
    wet = direct.copy()
    for delay_ms, gain_db in world.SPACE_TAPS:
        d = round(delay_ms / 1000 * SR)
        wet[d:] += reflected[: len(wet) - d] * world._db(gain_db) * send
    return wet


def render_bass():
    rng = np.random.default_rng(14_300)
    stem = np.zeros(L)
    for k, b in enumerate(UNIT_STARTS):
        name = CHORD_BARS[b]
        root = int(v2.CHORDS[name]["bass"])
        drag = rng.uniform(0.010, 0.020)
        if b >= 12:
            nxt = CHORD_BARS[(b + 1) % BARS]
            bass_two_feel(stem, rng, b * BAR, root, int(v2.CHORDS[nxt]["bass"]), drag)
            continue
        nxt_name = CHORD_BARS[(b + 2) % BARS]
        bass_two_feel(stem, rng, b * BAR, root, None, drag)
        bass_two_feel(
            stem, rng, (b + 1) * BAR, root, int(v2.CHORDS[nxt_name]["bass"]),
            rng.uniform(0.010, 0.020),
        )
    return bass_bus(stem, music.PHRASE_SEND)


# ---------------------------------------------------------------- brushes
def render_brushes(c: BrushControls = SKETCH_BRUSHES):
    rng = np.random.default_rng(c.seed)
    brush = np.random.default_rng(c.grain_seed)
    var = np.random.default_rng(c.var_seed)  # only a varied pattern draws from it
    stem = np.zeros(L)
    for b in range(BARS):
        bar_t = b * BAR
        for eighths, vel in ((0, rng.uniform(0.85, 1.0)), (4, rng.uniform(0.72, 0.9))):
            at = pos(bar_t, eighths) + rng.uniform(0.010, 0.025)
            if eighths == 4 and c.two_keep < 1.0 and var.random() >= c.two_keep:
                continue
            world._place(stem, v2._thump(rng), at, v2.THUMP_GAIN * vel)
        if rng.random() < c.ghost_p:
            at = pos(bar_t, c.ghost_slot) + rng.uniform(0.010, 0.025)
            world._place(stem, v2._thump(rng), at, v2.THUMP_GAIN * 0.5)
        for eighths in (2, 6):
            at = pos(bar_t, eighths) + rng.uniform(0.010, 0.025)
            if c.rim_keep < 1.0 and var.random() >= c.rim_keep:
                continue
            world._place(stem, v2._rim(rng), at, v2.RIM_GAIN * rng.uniform(0.70, 0.80))
        if c.rim_ghost_p > 0 and var.random() < c.rim_ghost_p:
            at = pos(bar_t, c.rim_ghost_slot) + var.uniform(0.010, 0.025)
            world._place(stem, v2._rim(var), at, v2.RIM_GAIN * var.uniform(0.30, 0.45))
        level = 1.0 if c.arc is None else c.arc[b]
        skip = 0.45 if b in c.thin_bars else c.shaker_skip
        for eighths in range(8):
            if brush.random() < skip:
                continue
            if c.accent == "flat":
                vel = brush.uniform(0.40, 0.58)
            elif (eighths % 2 == 0) == (c.accent == "beats"):
                vel = brush.uniform(0.50, 0.70)
            else:
                vel = brush.uniform(0.32, 0.50)
            at = pos(bar_t, eighths) + brush.uniform(0.008, 0.020)
            world._place(stem, v2._shaker_grain(brush), at, v2.SHAKER_GAIN * vel * level)
    return world._room_bus(stem, music.PHRASE_SEND)


# ---------------------------------------------------------------- bells
def bell_note(midi, dur_s, tau_s, rng, atk_ms=8.0, vel=1.0):
    """Soft night bell: a clean fundamental with a slightly detuned twin for a
    slow shimmer, a gentle octave, no sharp attack, nothing above ~3 kHz."""
    f = hz(midi)
    n = round(dur_s * SR)
    t = np.arange(n) / SR
    twin = 1.0 + rng.uniform(0.0022, 0.0034)
    ph = rng.uniform(0, 2 * math.pi, size=4)
    out = (
        np.sin(2 * math.pi * f * t + ph[0]) * 1.0
        + np.sin(2 * math.pi * f * twin * t + ph[1]) * 0.45
        + np.sin(2 * math.pi * f * 2.0 * t + ph[2]) * 0.14 * np.exp(-t / (tau_s * 0.35))
        + np.sin(2 * math.pi * f * 3.0 * t + ph[3]) * 0.03 * np.exp(-t / (tau_s * 0.2))
    )
    out *= np.exp(-t / tau_s)
    na = round(atk_ms / 1000 * SR)
    out[:na] *= rc_rise(na)
    out = world._filter(out, highpass_hz=500, lowpass_hz=3200, order=2)
    return vel * out / (np.max(np.abs(out)) or 1)


def render_bells(slow=False, c: BellsControls | None = None):
    """The busy bells (the swell's) or the slow ones (the Evening's)."""
    if c is None:
        c = SKETCH_BELLS if slow else BellsControls(14_500, tuple(BELLS_BUSY))
    rng = np.random.default_rng(c.seed)
    stem = np.zeros(L)
    for bar, e, midi, vel in c.placements:
        at = pos(bar * BAR, e) + rng.uniform(0.012, 0.035)
        tau = rng.uniform(2.4, 3.0) if slow else rng.uniform(1.5, 2.2)
        atk = 14.0 if slow else rng.uniform(6.0, 10.0)
        world._place(
            stem, bell_note(midi, min(tau * 4, TOTAL - at - 0.05), tau, rng, atk_ms=atk),
            at, 0.5 * vel * rng.uniform(0.92, 1.0),
        )
    return world._room_bus(stem, music.PHRASE_SEND)


def phone_rms_db(a):
    return 20 * math.log10(max(world._phone_rms(a), 1e-12))


def db(x):
    return 20 * math.log10(max(float(x), 1e-12))


# ---------------------------------------------------------------------------
# What this tool adds: the stems as the sketch scaled them, then the beds and
# the swells.
# ---------------------------------------------------------------------------

TARGET_RMS = {"keys": -37.0, "bass": -41.0, "brushes": -46.0}  # sketch: phone-band RMS
TARGET_PEAK = {"bells": -26.0, "bells_slow": -28.0}  # sketch: sample peak
STEM_NAMES = ("keys", "bass", "brushes", "bells", "bells_slow")

BED_TAIL_S = 6.5  # kept past the form; the stems are silent in practice by 6.2 s
BED_TARGET_DB = -36.0  # phone-band RMS: the level of every take in the rotation
BED_END_FADE_S = 0.05

# The sketch's states (template.html ST): per-stem gain, and the keys' lowpass.
BETWEEN_GAINS = {"keys": 1.0, "brushes": 0.55}
BETWEEN_LP_HZ = 9000.0
EVENING_GAINS = {"keys": 0.9, "bass": 0.35, "bells_slow": 1.0}
EVENING_LP_HZ = 900.0
LP_Q_DB = 0.6  # Web Audio's lowpass Q is in dB

SWELL_GAIN = 0.85  # the sketch's marked state: bass and busy bells at 0.85
SWELL_COUNT = 32  # every strong beat (1 and 3) of 64
SWELL_PREROLL_S = 0.15  # the app starts a swell this much before its beat
SWELL_RISE_S = 0.12  # cosine rise, complete on the beat
SWELL_HOLD_BARS = 2
SWELL_RELEASE_TAU_S = 0.55  # the sketch's release (applyBase(0.55))
SWELL_TAIL_S = 2.5
SWELL_END_FADE_S = 0.3
SWELL_TARGET_DB = -38.2  # phone-band RMS over the two held bars

ENCODE_ARGS = ["-ac", "1", "-ar", "48000", "-c:a", "aac", "-b:a", "96k"]


def render_raw_stems():
    """The five stems, UNFOLDED, before the sketch's scaling."""
    return {
        "keys": render_keys(),
        "bass": render_bass(),
        "brushes": render_brushes(),
        "bells": render_bells(False),
        "bells_slow": render_bells(True),
    }


def render_performance_stems(index):
    """What one performance plays on top of the shared bass: its keys, its
    brushes and its slow bells, UNFOLDED, before scaling (the busy bells are
    the swells' and do not vary)."""
    p = PERFORMANCES[index]
    return {
        "keys": render_keys(p.keys),
        "brushes": render_brushes(p.brushes),
        "bells_slow": render_bells(True, p.bells),
    }


def scale_stems(raw):
    """The sketch's gains (computed on the folded, circular stem as the sketch
    did) applied to both the folded stems and the unfolded ones."""
    folded = {k: fold(a) for k, a in raw.items()}
    gains = {}
    for k, a in folded.items():
        if k in TARGET_PEAK:
            gains[k] = 10 ** (TARGET_PEAK[k] / 20) / float(np.max(np.abs(a)))
        else:
            gains[k] = 10 ** (TARGET_RMS[k] / 20) / world._phone_rms(a)
    scaled_folded = {k: folded[k] * gains[k] for k in raw}
    scaled_raw = {k: raw[k] * gains[k] for k in raw}
    return scaled_raw, scaled_folded, gains


def int16_of(a):
    """The samples as the sketch wrote them: PCM_16 through soundfile."""
    buf = io.BytesIO()
    sf.write(buf, a, SR, format="WAV", subtype="PCM_16")
    buf.seek(0)
    data, _sr = sf.read(buf, dtype="int16")
    return data


def int16_sha(a):
    return hashlib.sha256(int16_of(a).tobytes()).hexdigest()


def webaudio_lowpass(x, f0_hz, q_db=LP_Q_DB, fs=SR):
    """A Web Audio BiquadFilterNode lowpass (its spec's coefficients; Q in dB)."""
    w0 = 2 * math.pi * f0_hz / fs
    alpha_q = math.sin(w0) / (2 * 10 ** (q_db / 20))
    cosw = math.cos(w0)
    b = np.array([(1 - cosw) / 2, 1 - cosw, (1 - cosw) / 2])
    a = np.array([1 + alpha_q, -2 * cosw, 1 - alpha_q])
    return lfilter(b / a[0], a / a[0], x)


def mix_state(stems, gains, lp_hz):
    """The sketch's state: the keys pass the lowpass, then each stem its gain."""
    out = np.zeros(len(stems["keys"]))
    for name, g in gains.items():
        a = webaudio_lowpass(stems[name], lp_hz) if name == "keys" else stems[name]
        out = out + g * a
    return out


def end_fade(a, seconds):
    n = round(seconds * SR)
    out = a.copy()
    out[-n:] *= 0.5 + 0.5 * np.cos(math.pi * np.arange(n) / n)
    return out


def build_beds(scaled_raw, scaled_folded):
    """Between and Evening: one unfolded pass plus a 6.5 s natural tail."""
    beds = {}
    states = {
        "between": (BETWEEN_GAINS, BETWEEN_LP_HZ),
        "evening": (EVENING_GAINS, EVENING_LP_HZ),
    }
    keep = N + round(BED_TAIL_S * SR)
    for name, (gains, lp) in states.items():
        full = mix_state(scaled_raw, gains, lp)  # the whole 10 s tail
        circular = fold(full)  # what the sketch's loop sounds like
        sketch_db = phone_rms_db(circular)
        gain = 10 ** (BED_TARGET_DB / 20) / world._phone_rms(circular)
        cut = full[N + round(BED_TAIL_S * SR):]
        bed = end_fade(full[:keep] * gain, BED_END_FADE_S)
        # Everything in the bed but the shared bass, circular: so a test can
        # take it out of the decoded file and see only the bass that is left.
        bass_part = gains.get("bass", 0.0) * scaled_raw["bass"]
        beds[name] = {
            "audio": bed,
            "audio_full": full * gain,
            "circular_without_bass": (fold(full - bass_part) * gain).astype(np.float32),
            "sketch_phone_rms_db": round(sketch_db, 2),
            "loop_phone_rms_db": round(phone_rms_db(fold(bed)), 2),
            "gain": float(gain),
            "gain_db": round(db(gain), 2),
            "cut_tail_peak_db": round(db(np.max(np.abs(cut)) * gain), 1),
        }
    return beds


def swell_envelope(n):
    """Rise (complete on the beat), two-bar hold, 0.55 s release, end fade."""
    t = np.arange(n) / SR
    beat_t = SWELL_PREROLL_S
    held_until = beat_t + SWELL_HOLD_BARS * BAR
    rise_from = beat_t - SWELL_RISE_S
    env = np.ones(n)
    rising = t < beat_t
    x = np.clip((t - rise_from) / SWELL_RISE_S, 0.0, 1.0)
    env[rising] = (0.5 - 0.5 * np.cos(math.pi * x))[rising]
    releasing = t > held_until
    env[releasing] = np.exp(-(t[releasing] - held_until) / SWELL_RELEASE_TAU_S)
    return end_fade(env, SWELL_END_FADE_S)


def build_swells(scaled_folded, between_bed, all_between=None):
    """Thirty-two windows cut from the circular bass and busy-bell stems.

    The swell is shared by every performance: it is cut from the bass and the
    busy bells, which no performance changes. [between_bed] is performance 0's
    (the lift and peak recorded as before); [all_between] lists every
    performance's Between bed, and each swell also records how it sits over
    each of them."""
    source = SWELL_GAIN * (scaled_folded["bass"] + scaled_folded["bells"])
    n = round((SWELL_PREROLL_S + SWELL_HOLD_BARS * BAR + SWELL_TAIL_S) * SR)
    beds = [between_bed] if all_between is None else list(all_between)
    circulars = [fold(bed["audio_full"]) for bed in beds]
    between_circular = fold(between_bed["audio_full"])
    env = swell_envelope(n)
    held = slice(
        round(SWELL_PREROLL_S * SR),
        round((SWELL_PREROLL_S + SWELL_HOLD_BARS * BAR) * SR),
    )
    swells = []
    for k in range(SWELL_COUNT):
        start = round((2 * k * BEAT - SWELL_PREROLL_S) * SR)
        idx = (start + np.arange(n)) % N
        window = source[idx] * env
        before = phone_rms_db(window[held])
        trim = SWELL_TARGET_DB - before
        audio = window * 10 ** (trim / 20)
        # Over the Between bed it would sound with: the lift, and the peak.
        beneath = between_circular[idx]
        together = beneath + audio
        lifts, peaks = [], []
        for circ in circulars:
            under = circ[idx]
            both = under + audio
            lifts.append(round(phone_rms_db(both[held]) - phone_rms_db(under[held]), 2))
            peaks.append(round(db(np.max(np.abs(both))), 2))
        swells.append(
            {
                "audio": audio,
                "beat": 2 * k,
                "pre_trim_phone_rms_db": round(before, 2),
                "trim_db": round(trim, 2),
                "held_phone_rms_db": round(phone_rms_db(audio[held]), 2),
                "lift_over_between_db": round(
                    phone_rms_db(together[held]) - phone_rms_db(beneath[held]), 2
                ),
                "with_between_peak_db": round(db(np.max(np.abs(together))), 2),
                "lift_by_performance_db": lifts,
                "with_between_peak_by_performance_db": peaks,
            }
        )
    return swells


# ---------------------------------------------------------------------------
# Encoding and measuring
# ---------------------------------------------------------------------------


def ffmpeg_exe():
    exe = shutil.which("ffmpeg")
    if not exe:
        sys.exit("ffmpeg is required (AAC-LC encode)")
    return exe


def ffmpeg_version():
    out = subprocess.run([ffmpeg_exe(), "-version"], capture_output=True, text=True, check=True)
    return out.stdout.splitlines()[0]


def encode_m4a(audio, dest: Path):
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "master.wav"
        sf.write(str(wav), audio, SR, subtype="PCM_16")
        subprocess.run(
            [
                ffmpeg_exe(), "-y", "-v", "error", "-i", str(wav), *ENCODE_ARGS,
                "-fflags", "+bitexact", "-flags:a", "+bitexact", "-map_metadata", "-1",
                "-movflags", "+faststart", str(dest),
            ],
            check=True,
        )


def decode_m4a(path: Path):
    """Decode as the app's platform decoder would, priming removed."""
    proc = subprocess.run(
        [ffmpeg_exe(), "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", "48000", "-"],
        capture_output=True, check=True,
    )
    return np.frombuffer(proc.stdout, dtype="<f4").astype(np.float64)


def sha_file(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def duration_of(path: Path):
    out = subprocess.run(
        [shutil.which("ffprobe") or "ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return round(float(out.stdout.strip()), 3)


def levels(a):
    return {
        "phone_rms_dbfs": round(phone_rms_db(a), 2),
        "peak_dbfs": round(db(np.max(np.abs(a))), 2),
        "first_sample": float(a[0]),
        "last_sample": float(a[-1]),
    }


def render_all(sketch: Path | None):
    """Everything the tool makes, in memory: the sketch's five stems, the other
    performances' stems, every bed, and the thirty-two swells."""
    raw = render_raw_stems()
    scaled_raw, scaled_folded, gains = scale_stems(raw)
    stem_records = {}
    for k in STEM_NAMES:
        rec = {"int16_sha256": int16_sha(scaled_folded[k]), "gain": float(gains[k])}
        sketch_wav = sketch / "music" / "stems" / f"{k}.wav" if sketch else None
        if sketch_wav is not None and sketch_wav.exists():
            theirs, _sr = sf.read(str(sketch_wav), dtype="int16")
            rec["matches_sketch"] = bool(np.array_equal(theirs, int16_of(scaled_folded[k])))
        stem_records[k] = rec
    performances = []
    for p in PERFORMANCES:
        if p.index == 0:
            mine_raw, mine_folded = scaled_raw, scaled_folded
        else:
            # The performance's own stems, scaled by the sketch's rules; the
            # bass is the sketch's, shared, so the swells stay valid.
            own_raw, own_folded, _g = scale_stems(render_performance_stems(p.index))
            mine_raw = {**own_raw, "bass": scaled_raw["bass"]}
            mine_folded = {**own_folded, "bass": scaled_folded["bass"]}
        beds = build_beds(mine_raw, mine_folded)
        performances.append(
            {
                "performance": p,
                # The bass is every performance's, byte for byte: the swells are
                # cut from it.
                "stems": {
                    k: int16_sha(mine_folded[k])
                    for k in ("keys", "brushes", "bells_slow", "bass")
                },
                "beds": beds,
            }
        )
    swells = build_swells(
        scaled_folded,
        performances[0]["beds"]["between"],
        [pf["beds"]["between"] for pf in performances],
    )
    for i, pf in enumerate(performances):
        pf["lift_db"] = [s["lift_by_performance_db"][i] for s in swells]
    return {
        "stem_records": stem_records,
        "scaled_raw": scaled_raw,
        "scaled_folded": scaled_folded,
        "performances": performances,
        "swells": swells,
    }


def bed_name(state, index):
    return f"bed_{state}_{index}.m4a"


def write_assets():
    sketch = DEFAULT_SKETCH if DEFAULT_SKETCH.exists() else None
    made = render_all(sketch)
    for rec_name, rec in made["stem_records"].items():
        if rec.get("matches_sketch") is False:
            sys.exit(f"stem {rec_name} no longer matches the sketch's stem")
    if OUT_DIR.exists():
        for old in OUT_DIR.glob("*.m4a"):
            old.unlink()
    files = {}

    def add(rel, audio, extra):
        dest = OUT_DIR / rel
        encode_m4a(audio, dest)
        runtime = f"assets/music/class_day/{rel}"
        files[runtime] = {
            "sha256": sha_file(dest),
            "bytes": dest.stat().st_size,
            "duration_s": duration_of(dest),
            **levels(audio),
            **extra,
        }

    performance_records = []
    for pf in made["performances"]:
        p = pf["performance"]
        record_files = {}
        for state in ("between", "evening"):
            b = pf["beds"][state]
            add(
                bed_name(state, p.index),
                b["audio"],
                {
                    "role": f"bed ({state})",
                    "performance": p.index,
                    "sketch_phone_rms_db": b["sketch_phone_rms_db"],
                    "loop_phone_rms_db": b["loop_phone_rms_db"],
                    "gain_db": b["gain_db"],
                    "cut_tail_peak_db": b["cut_tail_peak_db"],
                },
            )
            record_files[state] = f"assets/music/class_day/{bed_name(state, p.index)}"
        performance_records.append(
            {
                "index": p.index,
                "name": p.name,
                "feel": p.feel,
                "files": record_files,
                "stems": pf["stems"],
                "figures": {
                    str(bar): [list(note) for note in notes]
                    for bar, notes in plan_figures(p.keys).items()
                },
                "swell_lift_over_between_db": {
                    "min": min(pf["lift_db"]),
                    "mean": round(sum(pf["lift_db"]) / len(pf["lift_db"]), 2),
                    "max": max(pf["lift_db"]),
                },
                "controls": {
                    "keys": p.keys._asdict(),
                    "brushes": p.brushes._asdict(),
                    "slow_bells": {
                        "seed": p.bells.seed,
                        "placements": [list(x) for x in p.bells.placements],
                    },
                },
            }
        )
    for k, s in enumerate(made["swells"]):
        add(
            f"swell_{k:02d}.m4a",
            s["audio"],
            {
                "role": "swell",
                "beat": s["beat"],
                "pre_trim_phone_rms_db": s["pre_trim_phone_rms_db"],
                "trim_db": s["trim_db"],
                "held_phone_rms_db": s["held_phone_rms_db"],
                "lift_over_between_db": s["lift_over_between_db"],
                "with_between_peak_db": s["with_between_peak_db"],
                "lift_by_performance_db": s["lift_by_performance_db"],
                "with_between_peak_by_performance_db": s["with_between_peak_by_performance_db"],
            },
        )
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    total = sum(f["bytes"] for f in files.values())
    manifest = {
        "study": "class-day-score",
        "date": "2026-10-11",
        "status": "built for the owner's phone; shipped, not yet heard in the app",
        "why": (
            "owner, about the listening page's music sketch: \"also changing the music "
            "after you marked a class was super cool\"; and, about repetition in the "
            "room's music, \"that fire thing was because that fire sound on repeat was "
            "annoying\" (so the one 53 s form is played in six performances)"
        ),
        "form": {
            "bpm": BPM,
            "beat_s": BEAT,
            "bar_s": BAR,
            "bars": BARS,
            "chord_bars": CHORD_BARS,
            "pass_s": N / SR,
            "pass_frames_48k": N,
            "bed_tail_s": BED_TAIL_S,
            "swell_preroll_s": SWELL_PREROLL_S,
            "swell_rise_s": SWELL_RISE_S,
            "swell_hold_bars": SWELL_HOLD_BARS,
            "swell_release_tau_s": SWELL_RELEASE_TAU_S,
            "swell_tail_s": SWELL_TAIL_S,
            "swell_count": SWELL_COUNT,
            "swell_beats": [2 * k for k in range(SWELL_COUNT)],
            "performance_count": PERFORMANCE_COUNT,
        },
        "recipe": (
            "tool/author_class_day_score.py: the sketch's renderer (render_music.py) carried "
            "over, stems unfolded; the song (the 16 bars, the chords, the bass line) is shared "
            "and a performance changes only the keys' voicings, hit rhythm and figures, the "
            "brushes' pattern and the Evening's slow bells, by the sketch's own controls "
            "(seeds, voicing pick, second hit, ghost thump, skipped grain); performance 0 is "
            "the sketch note for note. Between = keys (9 kHz lowpass) + 0.55 brushes; Evening = "
            "0.9 keys (900 Hz lowpass, Q 0.6 dB) + 0.35 bass + 1.0 slow bells; each bed gained "
            "to -36.0 dBFS phone-band RMS, 50 ms end fade, 6.5 s natural tail; swell k = 0.85 "
            "(bass + busy bells) from the circular stems from beat 2k minus 0.15 s, 120 ms "
            "cosine rise ending on the beat, two bars held, 0.55 s release, 2.5 s tail, 0.3 s "
            "end fade, trimmed to -38.2 dBFS over the held bars; no sample, no foreign synthesis"
        ),
        "format": "AAC-LC 96 kbps 48 kHz mono, m4a (ffmpeg native aac, bitexact, no metadata)",
        "encoder": ffmpeg_version(),
        "phone_rms_target_dbfs": {"bed": BED_TARGET_DB, "swell": SWELL_TARGET_DB},
        "runtime_scale": "lib/class_day_score.dart plays every file at 1.0 times fades and the shared duck",
        "total_bytes": total,
        "stems": made["stem_records"],
        "performances": performance_records,
        "records": files,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {len(files)} files, {total} bytes, manifest {MANIFEST}")


def check_masters(made):
    masters = {}
    for pf in made["performances"]:
        i = pf["performance"].index
        masters[bed_name("between", i)] = pf["beds"]["between"]["audio"]
        masters[bed_name("evening", i)] = pf["beds"]["evening"]["audio"]
    for k, s in enumerate(made["swells"]):
        masters[f"swell_{k:02d}.m4a"] = s["audio"]
    return masters


def check(sketch: Path | None, made=None):
    """No writes: the stems equal the recorded (and the sketch's) stems, and
    each shipped file is this recipe's output (correlation and level). Pass
    [made] (from render_all) to reuse a render."""
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if made is None:
        made = render_all(sketch)
    bad = []
    for k, rec in made["stem_records"].items():
        want = manifest["stems"][k]["int16_sha256"]
        if rec["int16_sha256"] != want:
            bad.append(f"stem {k} differs from the recorded hash")
        if rec.get("matches_sketch") is False:
            bad.append(f"stem {k} differs from the sketch's stem")
    for pf, recorded in zip(made["performances"], manifest["performances"]):
        for stem, sha in pf["stems"].items():
            if recorded["stems"][stem] != sha:
                bad.append(f"performance {recorded['index']} stem {stem} differs from the recorded hash")
    masters = check_masters(made)
    worst_corr = 1.0
    for rel, master in masters.items():
        shipped = decode_m4a(OUT_DIR / rel)
        n = min(len(shipped), len(master))
        a, b = shipped[:n], master[:n]
        corr = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))
        worst_corr = min(worst_corr, corr)
        gap = abs(phone_rms_db(a) - phone_rms_db(b))
        if corr < 0.97 or gap > 0.5:
            bad.append(f"{rel}: correlation {corr:.4f}, level gap {gap:.2f} dB")
    if bad:
        print("\n".join(bad))
        return 1
    print(
        f"ok: 5 stems identical, {PERFORMANCE_COUNT} performances, "
        f"{len(masters)} files match their masters (worst correlation {worst_corr:.4f})"
    )
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="prove the shipped files match this recipe; no writes")
    parser.add_argument("--sketch", type=Path, default=None, help="the sketch folder, to compare its stems")
    args = parser.parse_args()
    sketch = args.sketch or (DEFAULT_SKETCH if DEFAULT_SKETCH.exists() else None)
    if args.check:
        sys.exit(check(sketch))
    write_assets()


if __name__ == "__main__":
    main()
