"""room-music-v2 — jazzy calm lofi beds: B minor inside the D-major field.

Owner signal (2026-08-31, verbatim): "the current music is super peaceful and
could be good for maybe a meditation timer mode thing, but i was imagining
more jazzy calm lofi type background music, specifically it's raining
somewhere else/the place where it rained from undertale/deltarune type thing
was what i imagined". Standing (2026-08-29): "i would love some music though
i loved the music direction you came up with and then how the buttons could
be on beat with the background music" — taps are NEVER quantized; answers may
land on the grid.

The register under audition is the two Toby Fox rain-track renditions
("It's Raining Somewhere Else" / "The place where it rained"): minor-seventh
planing with zero dominant function, two bars per chord, ballad two-feel
bass, one soft shaker, narrow stepwise melody entering off the downbeat.
Mapped into the house field: the music is B-minor jazz, every pitch diatonic
to D major (D E F# G A B C#), so the D-major-pentatonic interaction taps are
consonant with every chord by construction. The loop, two bars per chord:

    | Bm9 | Bm9 | F#m7(11) | F#m7(11) | A9sus | A9sus | Em9 | Em9 |

Bridge (once per render where the candidate calls for it, one bar each):
Gmaj9 -> A13 -> Dmaj9 -> Em9 — the only major-quality chords and the only
functional dominant, C# and G kept mid-voice, every top voice pentatonic.

Three 96 s candidates, each asking one question:

- ``windowseat`` — 96 BPM straight; the full mapped anatomy (keys intro,
  lead + bass + shaker, EP-ish handoff, bridge, 4-bar breakdown to rain and
  air, return, slowing tag). Is the reference register itself the answer?
- ``umbrella`` — 72 BPM swung ~57%; thump + rim under the chords, the rain
  as the hi-hat, a sparse behind-the-beat motif. Did he want a head-nod?
- ``drizzle`` — free placement, no percussion; the loop's suspended chords
  every 8-12 s with 2-3-note lead fragments. How much jazz density does a
  BACKGROUND want?

Rain is OUR window (the OST tracks have no rain): Poisson micro-droplet
pings, no broadband wash, levelled -20..-26 dB under the music's phone-band
RMS. Everything is grown from the shared sonic world — modal bank, room
fingerprint, no imported samples — level-matched at -36.0 dBFS phone-band
RMS under a -6 dBFS ceiling, PCM_16 mono 48 kHz, seeds 13000-13499, fully
deterministic. The harmonic loop repeating is the register's idiom; the
PERFORMANCE never repeats (seeded velocity/timing/voicing variation), and a
shipped bed stays a generative in-app system, never a fixed loop.

Run from the repo root:

    python tool/author_room_music_v2_study.py \
        --output design/audits/2026-08-31/room-music-v2
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import author_room_music_study as music
import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-music-v2"
RENDER_VERSION = "room-music-v2-author-v4"

BED_SECONDS = music.BED_SECONDS
FLOW_SECONDS = music.FLOW_SECONDS
TARGET_DBFS = music.TARGET_DBFS
WORLD_ROOT = music.WORLD_ROOT

# ── the field ──────────────────────────────────────────────────────────
# Everything diatonic to D major; taps (D E F# A B) are a subset.
PENT_PCS = frozenset((2, 4, 6, 9, 11))          # D E F# A B
DIATONIC_PCS = frozenset((1, 2, 4, 6, 7, 9, 11))  # + C# G


def _hz(midi: int) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


# Chord bank. Voicings are rootless-leaning (3rd/7th + one extension),
# chord mass ~250-1500 Hz; every voicing's TOP note is a pentatonic degree,
# C# and G only ever mid-voice. Bass roots live around A2-A3.
CHORDS: dict[str, dict[str, object]] = {
    "Bm9": {
        "bass": 47,
        "pcs": (11, 2, 6, 9, 1),
        "voicings": ((62, 66, 69), (57, 62, 66), (66, 69, 74), (57, 61, 66)),
    },
    "F#m7(11)": {
        "bass": 54,
        "pcs": (6, 9, 1, 4, 11),
        "voicings": ((57, 61, 64), (61, 64, 69), (57, 64, 66), (64, 69, 71)),
    },
    "A9sus": {
        "bass": 45,
        "pcs": (9, 2, 4, 7, 11),
        "voicings": ((55, 59, 64), (62, 67, 71), (55, 62, 64), (64, 67, 71)),
    },
    "Em9": {
        "bass": 52,
        "pcs": (4, 7, 11, 2, 6),
        "voicings": ((55, 59, 62), (55, 62, 66), (59, 62, 66), (62, 67, 71)),
    },
    "Gmaj9": {
        "bass": 55,
        "pcs": (7, 11, 2, 6, 9),
        "voicings": ((59, 62, 66), (59, 66, 69), (62, 66, 69)),
    },
    "A13": {
        "bass": 45,
        "pcs": (9, 1, 4, 7, 11, 6),
        "voicings": ((61, 67, 71), (55, 61, 64), (61, 64, 67, 71)),
    },
    "Dmaj9": {
        "bass": 50,
        "pcs": (2, 6, 9, 1, 4),
        "voicings": ((54, 61, 64), (57, 61, 66), (61, 66, 69)),
    },
}

LOOP = ("Bm9", "Bm9", "F#m7(11)", "F#m7(11)", "A9sus", "A9sus", "Em9", "Em9")
BRIDGE = ("Gmaj9", "A13", "Dmaj9", "Em9")

BASS_DIA = (45, 47, 49, 50, 52, 54, 55, 57, 59)   # A2..B3 diatonic ladder
BASS_FIFTH = {47: 54, 54: 49, 45: 52, 52: 47, 55: 50, 50: 45}

LEAD_DIA = (62, 64, 66, 67, 69, 71, 73, 74, 76, 78, 79, 81, 83, 85, 86)

KEYS_GAIN = 0.11
LEAD_GAIN = 0.16
BASS_GAIN = 0.15
SHAKER_GAIN = 0.020
THUMP_GAIN = 0.065
RIM_GAIN = 0.030
RAIN_SEND = 0.5
DRIZZLE_AIR_DB = -12.0  # the whisper of v1 drone air under drizzle (continuity law)

KEYS_EXCITATION = 0.012   # several bodies sound at once; noise per minute (§8)
LEAD_EXCITATION = 0.02


# ── score + Paired Return guard ────────────────────────────────────────


class _Score:
    """Every pitched placement, recorded for the music verifier."""

    def __init__(self, bpm: float, swing: float | None, grid: str) -> None:
        self.meta = {"bpm": bpm, "swing": swing, "grid": grid}
        self.events: list[dict[str, object]] = []
        self.chords: list[dict[str, object]] = []

    def add(self, t: float, voice: str, midi: int, vel: float, dur_ms: float) -> None:
        self.events.append({
            "t": round(float(t), 4),
            "voice": voice,
            "hz": round(_hz(midi), 3),
            "midi": int(midi),
            "vel": round(float(vel), 3),
            "dur_ms": round(float(dur_ms), 1),
        })

    def hit(self, t: float, voice: str, vel: float, dur_ms: float) -> None:
        """An unpitched hit (thump/rim/shaker) — logged so the 10-25 ms
        behind-grid drag is auditable from data, not just by ear."""
        self.events.append({
            "t": round(float(t), 4),
            "voice": voice,
            "hz": None,
            "midi": None,
            "vel": round(float(vel), 3),
            "dur_ms": round(float(dur_ms), 1),
        })

    def chord(self, t: float, name: str, dur_s: float) -> None:
        self.chords.append({"t": round(float(t), 4), "name": name, "dur_s": round(dur_s, 4)})

    def as_dict(self) -> dict[str, object]:
        return {
            "meta": self.meta,
            "chords": self.chords,
            "events": sorted(
                self.events,
                key=lambda e: (e["t"], e["voice"], -1 if e["midi"] is None else e["midi"]),
            ),
        }


class _MotifGuard:
    """FULL sliding-window Paired Return exclusion: no voice may ever sound
    four consecutive pitches equal to D5 A5 E5 D5. Checking each new pitch
    against the voice's previous three covers every interior window (v2
    closes v1's prefix/suffix gap)."""

    MOTIF = (74, 81, 76, 74)

    def __init__(self) -> None:
        self._hist: dict[str, list[int]] = {}

    def vet(self, voice: str, midi: int, substitute: int = 71) -> int:
        hist = self._hist.setdefault(voice, [])
        if len(hist) >= 3 and tuple(hist[-3:]) == self.MOTIF[:3] and midi == self.MOTIF[3]:
            midi = substitute  # B4 — pentatonic, stepwise from D5
        hist.append(int(midi))
        return midi

    def would_complete(self, voice: str, midi: int) -> bool:
        hist = self._hist.get(voice, [])
        return len(hist) >= 3 and tuple(hist[-3:]) == self.MOTIF[:3] and midi == self.MOTIF[3]

    def push(self, voice: str, midi: int) -> None:
        self._hist.setdefault(voice, []).append(int(midi))


# ── voices ─────────────────────────────────────────────────────────────


def _mnote(
    midi: int,
    seconds: float,
    decay_ms: float,
    *,
    seed: int,
    bloom_s: float,
    drift_cents: float,
    excitation: float,
    dark_lp: float | None = None,
) -> np.ndarray:
    """A musical body from the shared modal bank, soft bloom attack, with a
    per-voice excitation budget (keys 0.012, lead 0.02 — §8 per-minute law)."""
    hz = _hz(midi)
    body = world._modal_body(
        hz,
        seconds,
        decay_ms,
        seed=seed,
        low_support=hz < 340.0,
        drift_cents=drift_cents,
        excitation_gain=excitation,
    )
    if dark_lp is not None:
        body = world._filter(body, lowpass_hz=dark_lp, order=2)
    t = np.arange(len(body)) / SAMPLE_RATE
    return body * (1.0 - np.exp(-t / max(bloom_s, 1e-4)))


def _thump(rng: np.random.Generator) -> np.ndarray:
    """Lofi kick-thump: felt not heard. Soft 100-300 Hz fundamental for
    headphones plus a quiet 500-1200 Hz knock the phone can hear; bloom
    attack, NO contact transient — it must never read as a UI tap."""
    dur = 0.32
    n = round(dur * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    f = 92.0 + 66.0 * np.exp(-t / 0.035)
    phase = np.cumsum(2 * math.pi * f / SAMPLE_RATE)
    bloom = 1.0 - np.exp(-t / 0.012)
    body = np.sin(phase + rng.uniform(0, 2 * math.pi)) * bloom * np.exp(-t / 0.11)
    knock_hz = rng.uniform(620.0, 940.0)
    knock = (
        np.sin(2 * math.pi * knock_hz * t + rng.uniform(0, 2 * math.pi))
        * (1.0 - np.exp(-t / 0.006))
        * np.exp(-t / 0.028)
        * 0.30
    )
    out = world._filter(body + knock, lowpass_hz=1_400, order=2)
    return world._normalize_peak(out)


def _rim(rng: np.random.Generator) -> np.ndarray:
    """Papery dark sidestick: short damped body, clearly darker and quieter
    than any UI contact (3-6 ms bloom, nothing like the 0.55 ms snap)."""
    dur = 0.09
    n = round(dur * SAMPLE_RATE)
    t = np.arange(n) / SAMPLE_RATE
    bloom = 1.0 - np.exp(-t / rng.uniform(0.003, 0.006))
    out = np.sin(2 * math.pi * rng.uniform(760.0, 840.0) * t + rng.uniform(0, 2 * math.pi))
    out = out * np.exp(-t / 0.022)
    second = np.sin(2 * math.pi * rng.uniform(1_150.0, 1_350.0) * t + rng.uniform(0, 2 * math.pi))
    out = out + second * np.exp(-t / 0.013) * 0.45
    paper = world._bandpass(rng.standard_normal(n), 600, 2_200, order=2)
    out = (out + world._normalize_peak(paper) * np.exp(-t / 0.012) * 0.18) * bloom
    return world._normalize_peak(world._filter(out, lowpass_hz=2_600, order=2))


def _shaker_grain(rng: np.random.Generator) -> np.ndarray:
    """A short soft dark grain cluster — time passing, not percussion."""
    dur = 0.034
    n = round(dur * SAMPLE_RATE)
    out = np.zeros(n)
    for _ in range(int(rng.integers(2, 4))):
        g_dur = rng.uniform(0.012, 0.020)
        gn = round(g_dur * SAMPLE_RATE)
        gt = np.arange(gn) / SAMPLE_RATE
        grain = world._bandpass(rng.standard_normal(gn), 900, 3_400, order=2)
        grain = world._normalize_peak(grain)
        grain *= (1.0 - np.exp(-gt / 0.002)) * np.exp(-gt / 0.008)
        world._place(out, grain, rng.uniform(0.0, 0.010), rng.uniform(0.5, 1.0))
    return world._normalize_peak(world._filter(out, lowpass_hz=3_800, order=2))


def _rain(
    seconds: float,
    seed: int,
    *,
    base_hz: float,
    gust_depth: float,
    period_range: tuple[float, float],
    drip_prob: float,
    pulse: tuple[float, float, float] | None = None,
) -> np.ndarray:
    """Poisson micro-droplet rain: 1-3 ms pings in ~1.2-3.8 kHz, slow density
    gusts on 10-30 s cycles, occasional larger drip in a lower band. NO
    broadband wash anywhere — a swish is the §8 veto; rain is many tiny snaps.
    ``pulse`` = (depth, beat_s, swing) lets droplet density breathe with the
    swung eighth grid (umbrella: the rain is the hi-hat)."""
    rng = np.random.default_rng(seed)
    out = np.zeros(round(seconds * SAMPLE_RATE))
    period = rng.uniform(*period_range)
    gust_phase = rng.uniform(0, 2 * math.pi)
    period_b = rng.uniform(*period_range)
    gust_phase_b = rng.uniform(0, 2 * math.pi)

    def _grid_pull(t: float) -> float:
        if pulse is None:
            return 0.0
        depth, beat, swing = pulse
        b = math.floor(t / beat)
        near = min(
            abs(t - b * beat),
            abs(t - (b * beat + swing * beat)),
            abs(t - (b + 1) * beat),
        )
        return depth * math.exp(-((near / 0.04) ** 2))

    max_rate = base_hz * (1.0 + gust_depth) * (1.0 + (pulse[0] if pulse else 0.0))
    t = rng.exponential(1.0 / max_rate)
    count = 0
    while t < seconds - 0.05:
        gust = 1.0 + 0.5 * gust_depth * (
            math.sin(2 * math.pi * t / period + gust_phase)
            + math.sin(2 * math.pi * t / period_b + gust_phase_b)
        )
        rate = base_hz * max(gust, 0.12) * (1.0 + _grid_pull(t))
        if rng.random() < rate / max_rate:
            if rng.random() < drip_prob:
                f0 = rng.uniform(650.0, 1_150.0)
                dur = rng.uniform(0.0045, 0.0060)
                amp = rng.uniform(0.55, 0.9)
            else:
                f0 = rng.uniform(1_400.0, 3_400.0)
                dur = rng.uniform(0.001, 0.003)
                amp = rng.uniform(0.25, 1.0)
            gn = max(8, round(dur * SAMPLE_RATE))
            gt = np.arange(gn) / SAMPLE_RATE
            env = np.sin(math.pi * np.minimum(gt / dur, 1.0)) ** 2
            grain = np.sin(2 * math.pi * f0 * gt + rng.uniform(0, 2 * math.pi)) * env
            world._place(out, grain, t, amp)
            count += 1
        t += rng.exponential(1.0 / max_rate)
    # keep every ping well under the 4-5 kHz handset fatigue band
    return world._filter(out, highpass_hz=480, lowpass_hz=3_800, order=3)


# ── players ────────────────────────────────────────────────────────────


def _pick_voicing(
    rng: np.random.Generator,
    guard: _MotifGuard,
    chord: str,
    prev: tuple[int, ...] | None,
) -> tuple[int, ...]:
    options = [v for v in CHORDS[chord]["voicings"] if v != prev]  # type: ignore[index]
    order = rng.permutation(len(options))
    for k in order:
        voicing = options[int(k)]
        if not guard.would_complete("keys-top", voicing[-1]):
            guard.push("keys-top", voicing[-1])
            return voicing
    voicing = options[int(order[0])]
    guard.push("keys-top", voicing[-1])
    return voicing


def _play_keys(
    stem: np.ndarray,
    score: _Score,
    rng: np.random.Generator,
    *,
    at: float,
    voicing: tuple[int, ...],
    decay: tuple[float, float],
    gain_scale: float,
    seed_base: int,
    counter: int,
    total: float,
) -> int:
    """One rolled chord: 15-35 ms bottom-up with per-note velocity scatter."""
    roll = rng.uniform(0.015, 0.035)
    spread = roll / max(len(voicing) - 1, 1)
    for i, midi in enumerate(voicing):
        onset = max(0.0, at + i * spread + rng.uniform(-0.002, 0.002))
        if onset >= total - 0.1:
            continue
        vel = rng.uniform(0.58, 0.95)
        decay_ms = rng.uniform(*decay)
        dur = min(decay_ms / 1000.0 * 4.0, total - onset - 0.05, 9.0)
        world._place(
            stem,
            _mnote(
                midi, dur, decay_ms,
                seed=seed_base + counter * 17,
                bloom_s=rng.uniform(0.012, 0.030),
                drift_cents=rng.uniform(-5.0, 3.0),
                excitation=KEYS_EXCITATION,
            ),
            onset,
            KEYS_GAIN * gain_scale * vel,
        )
        score.add(onset, "keys", midi, vel, dur * 1000.0)
        counter += 1
    return counter


def _play_lead(
    stem: np.ndarray,
    score: _Score,
    rng: np.random.Generator,
    *,
    t: float,
    midi: int,
    vel: float,
    decay_ms: float,
    seed: int,
    total: float,
    dark: bool = False,
) -> None:
    t = max(0.0, t)
    if t >= total - 0.15:
        return
    if midi % 12 not in PENT_PCS:
        decay_ms *= 0.55  # C#/G only pass mid-phrase — damp them like a player would
    dur = min(decay_ms / 1000.0 * 4.0, total - t - 0.05, 8.0)
    world._place(
        stem,
        _mnote(
            midi, dur, decay_ms,
            seed=seed,
            bloom_s=rng.uniform(0.010, 0.028),
            drift_cents=rng.uniform(-5.0, 3.0),
            excitation=0.015 if dark else LEAD_EXCITATION,
            dark_lp=2_400.0 if dark else None,
        ),
        t,
        LEAD_GAIN * vel,
    )
    score.add(t, "lead", midi, vel, dur * 1000.0)


def _play_bass_note(
    stem: np.ndarray,
    score: _Score,
    rng: np.random.Generator,
    *,
    t: float,
    midi: int,
    vel: float,
    decay_ms: float,
    seed: int,
    total: float,
) -> None:
    t = max(0.0, t)
    if t >= total - 0.15:
        return
    dur = min(decay_ms / 1000.0 * 4.0, total - t - 0.05, 2.2)
    world._place(
        stem,
        _mnote(
            midi, dur, decay_ms,
            seed=seed,
            bloom_s=rng.uniform(0.007, 0.013),
            drift_cents=rng.uniform(-4.0, 2.0),
            excitation=0.015,
        ),
        t,
        BASS_GAIN * vel,
    )
    score.add(t, "bass", midi, vel, dur * 1000.0)


def _bass_walk(rng: np.random.Generator, from_root: int, to_root: int) -> tuple[int, int]:
    """Two diatonic eighth notes stepping into the next chord's root."""
    ti = BASS_DIA.index(to_root)
    ascending = to_root >= from_root
    if ascending and ti >= 2:
        return BASS_DIA[ti - 2], BASS_DIA[ti - 1]
    if not ascending and ti + 2 < len(BASS_DIA):
        return BASS_DIA[ti + 2], BASS_DIA[ti + 1]
    if ti >= 2:
        return BASS_DIA[ti - 2], BASS_DIA[ti - 1]
    return BASS_DIA[ti + 2], BASS_DIA[ti + 1]


def _bass_two_feel(
    stem: np.ndarray,
    score: _Score,
    rng: np.random.Generator,
    *,
    bar_t: float,
    beat: float,
    swing: float,
    root: int,
    walk_to: int | None,
    drag: float,
    seed_base: int,
    counter: int,
    total: float,
) -> int:
    """Root on 1, octave on and-of-2, fifth on 4; when ``walk_to`` is given,
    beat 4 becomes the eighth-note walk-up into the next chord's root."""

    def pos(eighths: int) -> float:
        return bar_t + (eighths // 2) * beat + (swing * beat if eighths % 2 else 0.0)

    events: list[tuple[float, int, float, float]] = [
        (pos(0), root, rng.uniform(0.85, 1.0), rng.uniform(380.0, 480.0)),
        (pos(3), root + 12, rng.uniform(0.55, 0.72), rng.uniform(240.0, 320.0)),
    ]
    if walk_to is None:
        events.append((pos(6), BASS_FIFTH[root], rng.uniform(0.7, 0.88), rng.uniform(320.0, 420.0)))
    else:
        w1, w2 = _bass_walk(rng, root, walk_to)
        events.append((pos(6), w1, rng.uniform(0.6, 0.78), rng.uniform(200.0, 280.0)))
        events.append((pos(7), w2, rng.uniform(0.6, 0.78), rng.uniform(200.0, 280.0)))
    for at, midi, vel, decay_ms in events:
        _play_bass_note(
            stem, score, rng,
            t=at + drag + rng.uniform(-0.005, 0.005),
            midi=midi, vel=vel, decay_ms=decay_ms,
            seed=seed_base + counter * 17, total=total,
        )
        counter += 1
    return counter


def _lead_walk(
    rng: np.random.Generator,
    guard: _MotifGuard,
    n: int,
    final_pcs: frozenset[int],
    sustained: list[bool],
    voice: str = "lead",
) -> list[int]:
    """Narrow, stepwise, centered B4/D5 — the phrase's MEAN pitch must land
    in the B4-D5 band (a high bright lead is anti-idiom for lofi); one
    arching leap at most, and the snapped final tone may not mint a second
    one; sustained tones and the final tone resolve to pentatonic degrees;
    C#/G may pass mid-phrase. Every pitch is vetted through the Paired
    Return guard."""
    start_choices = (4, 5, 7)  # A4 B4 D5
    idx = int(start_choices[int(rng.integers(0, len(start_choices)))])
    leap_used = False
    indices: list[int] = []
    for i in range(n):
        if i:
            first_half = i < n / 2
            r = rng.random()
            if r < 0.60:
                step = 1 if rng.random() < (0.62 if first_half else 0.38) else -1
            elif r < 0.80:
                step = 2 if rng.random() < (0.58 if first_half else 0.40) else -2
            elif r < 0.90 and not leap_used:
                step = int(rng.integers(3, 5)) * (1 if rng.random() < 0.5 else -1)
                leap_used = True
            else:
                step = 0
            idx = max(1, min(13, idx + step))
        indices.append(idx)

    def snap(j: int, pcs: frozenset[int]) -> int:
        candidates = [k for k in range(len(LEAD_DIA)) if LEAD_DIA[k] % 12 in pcs]
        return min(candidates, key=lambda k: (abs(k - j), k))

    final_snap_pcs = frozenset(final_pcs) & PENT_PCS or PENT_PCS

    def snapped(idxs: list[int]) -> list[int]:
        out = list(idxs)
        for i in range(n):
            if sustained[i] and LEAD_DIA[out[i]] % 12 not in PENT_PCS:
                out[i] = snap(out[i], PENT_PCS)
        out[-1] = snap(out[-1], final_snap_pcs)
        # one arching leap per phrase, enforced on the SOUNDED contour: the
        # drawn walk allows exactly one >=3-scale-degree leap, but snapping
        # can mint another (the final chord-tone snap, or a sustained C#/G
        # pulled a degree further mid-phrase). Any offender is re-snapped to
        # the nearest allowed degree within 2 scale degrees of its
        # predecessor — chord-tone pentatonic for the final tone, pentatonic
        # for sustained tones, diatonic otherwise.
        seen = 0
        for i in range(1, n):
            if abs(out[i] - out[i - 1]) < 3:
                continue
            seen += 1
            final = i == n - 1
            if not ((final and leap_used) or seen > 1):
                continue
            pcs = final_snap_pcs if final else (
                PENT_PCS if sustained[i] else DIATONIC_PCS
            )
            near = [
                k for k in range(len(LEAD_DIA))
                if LEAD_DIA[k] % 12 in pcs and abs(k - out[i - 1]) <= 2
            ]
            if not near:
                near = [
                    k for k in range(len(LEAD_DIA))
                    if LEAD_DIA[k] % 12 in PENT_PCS and abs(k - out[i - 1]) <= 2
                ]
            out[i] = min(near, key=lambda k: (abs(k - out[i]), k))
            seen -= 1  # the re-snapped interval is now stepwise
        return out

    # keep the SOUNDED phrase's mean in the B4-D5 band (midi 71-74):
    # transpose the drawn contour by scale steps until the snapped result
    # complies (bounded — accepts the closest fit if snapping fights back)
    result = snapped(indices)
    for _ in range(6):
        mean = sum(LEAD_DIA[k] for k in result) / n
        if mean > 74.0 and min(indices) > 1:
            indices = [k - 1 for k in indices]
        elif mean < 71.0 and max(indices) < 13:
            indices = [k + 1 for k in indices]
        else:
            break
        result = snapped(indices)
    return [guard.vet(voice, LEAD_DIA[k]) for k in result]


# ── candidate: windowseat ──────────────────────────────────────────────


def _render_windowseat(score: _Score) -> tuple[np.ndarray, dict[str, object]]:
    """96 BPM, straight eighths — the full mapped reference anatomy."""
    rng = np.random.default_rng(13_000)
    guard = _MotifGuard()
    beat = 60.0 / 96.0
    bar = beat * 4.0
    total = BED_SECONDS
    frames = round(total * SAMPLE_RATE)
    stem = np.zeros(frames)

    bars = list(LOOP) * 3 + list(BRIDGE) + list(LOOP[:4]) + list(LOOP[4:]) + ["Bm9", "Bm9"]
    # 24 loop + 4 bridge + 4 breakdown + 4 return + 2 tag = 38 bars = 95 s
    breakdown = set(range(28, 32))
    for b, name in enumerate(bars):
        if b % 2 == 0 or b in range(24, 28):
            score.chord(b * bar, name, bar * (1 if b in range(24, 28) else 2))

    # keys — comping everywhere except the breakdown
    kc = 0
    prev_voicing: tuple[int, ...] | None = None
    for b, name in enumerate(bars):
        if b in breakdown:
            continue
        new_unit = b in range(24, 28) or b % 2 == 0 or b == 32
        if new_unit or prev_voicing is None:
            voicing = _pick_voicing(rng, guard, name, prev_voicing)
            prev_voicing = voicing
            gain_scale = 1.0
        else:
            voicing = prev_voicing if rng.random() < 0.45 else prev_voicing[-2:]
            gain_scale = 0.7
        kc = _play_keys(
            stem, score, rng,
            at=b * bar + rng.uniform(-0.006, 0.012),
            voicing=tuple(voicing),
            decay=(1_900.0, 2_600.0),
            gain_scale=gain_scale * (0.9 if b < 4 else 1.0),
            seed_base=13_010, counter=kc, total=total,
        )
        if 4 <= b < 28 and rng.random() < 0.35:
            kc = _play_keys(
                stem, score, rng,
                at=b * bar + 2 * beat + rng.uniform(-0.004, 0.012),
                voicing=tuple(prev_voicing[-2:]),
                decay=(1_400.0, 1_900.0),
                gain_scale=0.55,
                seed_base=13_010, counter=kc, total=total,
            )

    # bass — two-feel from bar 4; rests in breakdown; single tag root
    bc = 0
    unit_starts = [b for b in range(4, 24, 2)] + list(range(24, 28)) + [32, 34]
    for b in unit_starts:
        name = bars[b]
        root = int(CHORDS[name]["bass"])  # type: ignore[arg-type]
        if b in range(24, 28):  # bridge: one bar per chord, walk each bar
            nxt = bars[b + 1] if b + 1 < len(bars) else "Bm9"
            into_breakdown = (b + 1) in breakdown
            bc = _bass_two_feel(
                stem, score, rng,
                bar_t=b * bar, beat=beat, swing=0.5, root=root,
                walk_to=None if into_breakdown else int(CHORDS[nxt]["bass"]),  # type: ignore[arg-type]
                drag=rng.uniform(0.0, 0.008), seed_base=13_050, counter=bc, total=total,
            )
            continue
        nxt_name = bars[b + 2] if b + 2 < len(bars) else "Bm9"
        nxt_root = int(CHORDS[nxt_name]["bass"])  # type: ignore[arg-type]
        bc = _bass_two_feel(
            stem, score, rng,
            bar_t=b * bar, beat=beat, swing=0.5, root=root, walk_to=None,
            drag=rng.uniform(0.0, 0.008), seed_base=13_050, counter=bc, total=total,
        )
        walk_target = None if (b + 2) in breakdown else nxt_root
        bc = _bass_two_feel(
            stem, score, rng,
            bar_t=(b + 1) * bar, beat=beat, swing=0.5, root=root, walk_to=walk_target,
            drag=rng.uniform(0.0, 0.008), seed_base=13_050, counter=bc, total=total,
        )
    _play_bass_note(
        stem, score, rng,
        t=36 * bar + rng.uniform(0.0, 0.01), midi=47, vel=0.8,
        decay_ms=900.0, seed=13_050 + bc * 17, total=total,
    )

    # shaker — the only constant percussion, straight eighths, very quiet
    shaker_bars = [b for b in range(4, 28) if b not in breakdown] + list(range(32, 36))
    for b in shaker_bars:
        for e in range(8):
            at = b * bar + e * (beat / 2.0) + rng.uniform(-0.004, 0.004)
            vel = (0.62 if e % 2 == 0 else 0.45) * rng.uniform(0.82, 1.12)
            grain = _shaker_grain(rng)
            world._place(stem, grain, at, SHAKER_GAIN * vel)
            score.hit(at, "shaker", vel, len(grain) / SAMPLE_RATE * 1000.0)

    # lead — phrases entering on beat 2; EP-ish darker body bars 16-23
    def chord_at(t: float) -> str:
        return bars[min(int(t // bar), len(bars) - 1)]

    phrase_bars = ((4, False), (8, False), (12, False), (16, True), (20, True),
                   (25, False), (32, False))
    phrases = 0
    lc = 0
    for start_bar, dark in phrase_bars:
        n = int(rng.integers(3, 8))
        t = start_bar * bar + beat + rng.uniform(0.005, 0.015)
        gaps = []
        for _ in range(n - 1):
            r = rng.random()
            gaps.append(0.5 if r < 0.35 else 1.0 if r < 0.75 else 1.5 if r < 0.9 else 2.0)
        times = [t]
        for g in gaps:
            times.append(times[-1] + g * beat)
        durs = [g * beat * rng.uniform(0.8, 0.95) for g in gaps] + [beat * rng.uniform(1.2, 2.0)]
        sustained = [d >= 0.5 for d in durs]
        midis = _lead_walk(
            rng, guard, n,
            frozenset(CHORDS[chord_at(times[-1])]["pcs"]),  # type: ignore[arg-type]
            sustained,
        )
        for i, midi in enumerate(midis):
            _play_lead(
                stem, score, rng,
                t=times[i] + rng.uniform(0.005, 0.015),
                midi=midi, vel=rng.uniform(0.6, 0.95),
                decay_ms=rng.uniform(900.0, 1_400.0) * (1.3 if i == n - 1 else 1.0),
                seed=13_030 + lc * 17, total=total, dark=dark,
            )
            lc += 1
        phrases += 1
    # slowing tag: one long resolving B4
    tag_midi = guard.vet("lead", 71)
    _play_lead(
        stem, score, rng,
        t=36 * bar + beat + rng.uniform(0.01, 0.02),
        midi=tag_midi, vel=0.7, decay_ms=2_200.0,
        seed=13_030 + lc * 17, total=total,
    )
    phrases += 1

    # breakdown air: a faint B-minor drone breathing under the rain
    drone = music._drone(
        12.0, rng,
        [(_hz(47), 0.30), (_hz(54), 0.26), (_hz(59), 0.22), (_hz(66), 0.07)],
    )
    fade = round(3.0 * SAMPLE_RATE)
    drone[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
    drone_stem = np.zeros(frames)
    world._place(drone_stem, drone, 28 * bar - 1.0, 0.55)

    music_bus = world._room_bus(stem, music.PHRASE_SEND) + world._room_bus(
        drone_stem, music.DRONE_SEND
    )
    rain = _rain(
        total, 13_080,
        base_hz=2.8, gust_depth=0.45, period_range=(14.0, 26.0), drip_prob=0.03,
    )
    bed, measured = _mix_rain(music_bus, rain, -25.0)
    info = {
        "bpm": 96.0, "swing": None, "feel": "96 BPM, straight eighths",
        "bars": len(bars), "phrase_count": phrases,
        "chord_events": len(score.chords),
        "rain_offset_target_db": -25.0, "rain_under_music_db": measured,
    }
    return bed, info


# ── candidate: umbrella ────────────────────────────────────────────────


def _render_umbrella(
    score: _Score, hat: str = "rain", seed_offset: int = 0
) -> tuple[np.ndarray, dict[str, object]]:
    """72 BPM, swung eighths at ~57% — the lofi head-nod question.

    ``hat`` picks what carries the eighth-note air (the 2026-08-31 verdict
    rejected the droplet voice — "they dont even sound like rain they sound
    like bubble taps?" — while naming umbrella the winner, and umbrella's
    design leaned on the rain as its hi-hat):
    "rain"  — the auditioned original, byte-identical (default);
    "none"  — the hat removed entirely, nothing added;
    "brush" — a dark swung shaker-brush on the eighths (own rng stream, so
              the underlying performance stays byte-identical to the
              auditioned render — the A/B isolates the hat treatment).

    ``seed_offset`` (0-7) shifts every seed stream by the same amount to
    yield a DIFFERENT PERFORMANCE of the same approved grammar — the
    rotation material for the shipped generative system (never a fixed
    loop). Offset 0 is byte-identical to the auditioned render; the seed
    bases are ≥5 apart so equal offsets never collide within one render.
    """
    if hat not in ("rain", "none", "brush"):
        raise ValueError(f"unknown hat mode: {hat}")
    if not 0 <= seed_offset <= 7:
        raise ValueError(f"seed_offset outside the rotation block: {seed_offset}")
    rng = np.random.default_rng(13_100 + seed_offset)
    guard = _MotifGuard()
    beat = 60.0 / 72.0
    swing = 0.57
    bar = beat * 4.0
    total = BED_SECONDS
    frames = round(total * SAMPLE_RATE)
    stem = np.zeros(frames)

    bars = list(LOOP) * 2 + list(BRIDGE) + list(LOOP)  # 28 bars = 93.33 s
    bridge_bars = set(range(16, 20))
    for b, name in enumerate(bars):
        if b in bridge_bars or b % 2 == 0:
            score.chord(b * bar, name, bar * (1 if b in bridge_bars else 2))

    def pos(bar_t: float, eighths: int) -> float:
        return bar_t + (eighths // 2) * beat + (swing * beat if eighths % 2 else 0.0)

    # keys — chords rolled ON the grid, dustier decays
    kc = 0
    prev_voicing: tuple[int, ...] | None = None
    for b, name in enumerate(bars):
        new_unit = b in bridge_bars or b % 2 == 0
        if new_unit or prev_voicing is None:
            voicing = _pick_voicing(rng, guard, name, prev_voicing)
            prev_voicing = voicing
            gain_scale = 1.0
        else:
            voicing = prev_voicing if rng.random() < 0.4 else prev_voicing[-2:]
            gain_scale = 0.65
        kc = _play_keys(
            stem, score, rng,
            at=b * bar + rng.uniform(-0.004, 0.008),
            voicing=tuple(voicing),
            decay=(1_400.0, 2_000.0),
            gain_scale=gain_scale,
            seed_base=13_110 + seed_offset, counter=kc, total=total,
        )
        if rng.random() < 0.5:
            kc = _play_keys(
                stem, score, rng,
                at=pos(b * bar, 3) + rng.uniform(-0.003, 0.008),
                voicing=tuple(prev_voicing[-2:]),
                decay=(1_000.0, 1_500.0),
                gain_scale=0.5,
                seed_base=13_110 + seed_offset, counter=kc, total=total,
            )

    # bass — swung two-feel throughout
    bc = 0
    unit_starts = list(range(0, 16, 2)) + list(range(16, 20)) + list(range(20, 28, 2))
    for b in unit_starts:
        name = bars[b]
        root = int(CHORDS[name]["bass"])  # type: ignore[arg-type]
        drag = rng.uniform(0.010, 0.020)
        if b in bridge_bars:
            nxt = bars[b + 1] if b + 1 < len(bars) else "Bm9"
            bc = _bass_two_feel(
                stem, score, rng,
                bar_t=b * bar, beat=beat, swing=swing, root=root,
                walk_to=int(CHORDS[nxt]["bass"]),  # type: ignore[arg-type]
                drag=drag, seed_base=13_150 + seed_offset, counter=bc, total=total,
            )
            continue
        nxt_name = bars[b + 2] if b + 2 < len(bars) else "Bm9"
        bc = _bass_two_feel(
            stem, score, rng,
            bar_t=b * bar, beat=beat, swing=swing, root=root, walk_to=None,
            drag=drag, seed_base=13_150 + seed_offset, counter=bc, total=total,
        )
        bc = _bass_two_feel(
            stem, score, rng,
            bar_t=(b + 1) * bar, beat=beat, swing=swing, root=root,
            walk_to=int(CHORDS[nxt_name]["bass"]),  # type: ignore[arg-type]
            drag=rng.uniform(0.010, 0.020), seed_base=13_150 + seed_offset, counter=bc, total=total,
        )

    # thump + rim — felt not heard, dragging 10-25 ms behind; NO hi-hats
    # (the rain is the hi-hat). No cymbals, no fills.
    for b in range(2, len(bars)):
        bar_t = b * bar
        for eighths, vel in ((0, rng.uniform(0.85, 1.0)), (4, rng.uniform(0.72, 0.9))):
            drag = rng.uniform(0.010, 0.025)
            at = pos(bar_t, eighths) + drag
            hit = _thump(rng)
            world._place(stem, hit, at, THUMP_GAIN * vel)
            score.hit(at, "thump", vel, len(hit) / SAMPLE_RATE * 1000.0)
        if rng.random() < 0.30:
            drag = rng.uniform(0.010, 0.025)
            at = pos(bar_t, 7) + drag
            hit = _thump(rng)
            world._place(stem, hit, at, THUMP_GAIN * 0.5)
            score.hit(at, "thump", 0.5, len(hit) / SAMPLE_RATE * 1000.0)
        for eighths in (2, 6):
            drag = rng.uniform(0.010, 0.025)
            vel = rng.uniform(0.70, 0.80)
            at = pos(bar_t, eighths) + drag
            hit = _rim(rng)
            world._place(stem, hit, at, RIM_GAIN * vel)
            score.hit(at, "rim", vel, len(hit) / SAMPLE_RATE * 1000.0)

    # lead — one sparse motif surfacing every few loop cycles, behind the beat
    motif_rng = np.random.default_rng(13_130 + seed_offset)
    n = 5
    rhythm = (2, 3, 5, 8, 11)  # eighth positions from the entry bar (beat 2 on)
    base_durs = [0.7, 0.55, 0.9, 0.8, 1.4]
    sustained = [d >= 0.5 for d in base_durs]
    motif = _lead_walk(
        motif_rng, guard, n, frozenset(CHORDS["Bm9"]["pcs"]), sustained,  # type: ignore[arg-type]
    )
    lc = 0
    appearances = (5, 12, 22)
    for a, start_bar in enumerate(appearances):
        drop_last = a == 1 and n > 3
        count = n - 1 if drop_last else n
        seq = motif[:count]
        if a > 0:
            seq = list(seq)
            for m in seq:
                guard.push("lead", m)  # windows recur across appearances
        for i, midi in enumerate(seq):
            t = pos(start_bar * bar, rhythm[i]) + rng.uniform(0.015, 0.030)
            _play_lead(
                stem, score, rng,
                t=t, midi=midi, vel=rng.uniform(0.55, 0.85),
                decay_ms=rng.uniform(800.0, 1_200.0) * (1.3 if i == count - 1 else 1.0),
                seed=13_135 + seed_offset + lc * 17, total=total,
            )
            lc += 1

    if hat == "brush":
        # The hat role re-voiced: the windowseat shaker's grain family on the
        # SWUNG eighths, alternating strong/weak, dragging with the kit —
        # the researched "dark closed hats" grammar, nothing droplet-like.
        # Own rng stream so every note above is byte-identical to "rain".
        brush_rng = np.random.default_rng(13_190 + seed_offset)
        for b in range(2, len(bars)):
            bar_t = b * bar
            for eighths in range(8):
                if brush_rng.random() < 0.05:
                    continue  # a skipped grain now and then — a hand, not a machine
                vel = (
                    brush_rng.uniform(0.50, 0.70)
                    if eighths % 2 == 0
                    else brush_rng.uniform(0.32, 0.50)
                )
                at = pos(bar_t, eighths) + brush_rng.uniform(0.008, 0.020)
                grain = _shaker_grain(brush_rng)
                world._place(stem, grain, at, SHAKER_GAIN * vel)
                score.hit(at, "shaker", vel, len(grain) / SAMPLE_RATE * 1000.0)

    music_bus = world._room_bus(stem, music.PHRASE_SEND)
    info = {
        "bpm": 72.0, "swing": swing, "feel": "72 BPM, swung eighths ~57% (light MPC feel)",
        "bars": len(bars), "phrase_count": len(appearances),
        "chord_events": len(score.chords),
        "hat": hat,
    }
    if hat == "rain":
        rain = _rain(
            total, 13_180 + seed_offset,
            base_hz=7.5, gust_depth=0.5, period_range=(10.0, 20.0), drip_prob=0.02,
            pulse=(0.9, beat, swing),
        )
        bed, measured = _mix_rain(music_bus, rain, -21.0)
        info["rain_offset_target_db"] = -21.0
        info["rain_under_music_db"] = measured
    else:
        bed = music_bus
    return bed, info


# ── candidate: drizzle ─────────────────────────────────────────────────


def _render_drizzle(score: _Score) -> tuple[np.ndarray, dict[str, object]]:
    """~66 BPM feel, free placement — jazz color at v1's furniture density."""
    rng = np.random.default_rng(13_200)
    guard = _MotifGuard()
    total = BED_SECONDS
    frames = round(total * SAMPLE_RATE)
    stem = np.zeros(frames)

    transitions = {
        "Bm9": (("A9sus", 0.5), ("Em9", 0.35), ("Gmaj9", 0.15)),
        "A9sus": (("Bm9", 0.45), ("Em9", 0.40), ("Gmaj9", 0.15)),
        "Em9": (("Bm9", 0.5), ("A9sus", 0.4), ("Gmaj9", 0.1)),
        "Gmaj9": (("Bm9", 0.6), ("Em9", 0.4)),
    }
    kc = 0
    lc = 0
    fragments = 0
    chords = 0
    gmaj9_used = False
    prev_voicing: tuple[int, ...] | None = None
    name = "Bm9"
    t = rng.uniform(1.2, 2.2)
    while t < total - 8.0:
        voicing = _pick_voicing(rng, guard, name, prev_voicing)
        prev_voicing = voicing
        dur_here = rng.uniform(8.0, 12.0)
        score.chord(t, name, dur_here)
        kc = _play_keys(
            stem, score, rng,
            at=t, voicing=tuple(voicing),
            decay=(2_600.0, 3_400.0), gain_scale=1.0,
            seed_base=13_210, counter=kc, total=total,
        )
        chords += 1
        if rng.random() < 0.55:
            n = int(rng.integers(2, 4))
            ft = t + rng.uniform(2.0, 4.0)
            gaps = [rng.uniform(0.8, 1.6) for _ in range(n - 1)]
            durs = gaps + [rng.uniform(1.4, 2.2)]
            midis = _lead_walk(
                rng, guard, n,
                frozenset(CHORDS[name]["pcs"]),  # type: ignore[arg-type]
                [True] * n,
            )
            for i, midi in enumerate(midis):
                _play_lead(
                    stem, score, rng,
                    t=ft, midi=midi, vel=rng.uniform(0.5, 0.8),
                    decay_ms=rng.uniform(1_100.0, 1_600.0),
                    seed=13_230 + lc * 17, total=total,
                )
                lc += 1
                if i < n - 1:
                    ft += gaps[i]
            fragments += 1
        # mostly Bm9 <-> A9sus <-> Em9, rare Gmaj9 — AT MOST ONCE per render
        # and NEVER the final chord (the render ends suspended on a core
        # chord); NO dominant/Dmaj9 arrival. Deterministic enforcement: the
        # Gmaj9 option is removed once used, and removed whenever the next
        # chord could be the last one placed (its start past total - 20 s —
        # chord durations run 8-12 s and the loop exits at total - 8 s).
        allow_gmaj9 = (not gmaj9_used) and (t + dur_here < total - 20.0)
        options = [
            (nxt, p) for nxt, p in transitions[name]
            if nxt != "Gmaj9" or allow_gmaj9
        ]
        scale = sum(p for _, p in options)
        r = rng.random()
        acc = 0.0
        name = options[-1][0]
        for nxt, p in options:
            acc += p / scale
            if r < acc:
                name = nxt
                break
        if name == "Gmaj9":
            gmaj9_used = True
        t += dur_here

    music_bus = world._room_bus(stem, music.PHRASE_SEND)
    # Continuity law (2026-08-31 spectrogram review): the sparsest bed must
    # never read as stopped — v1's furniture density always kept the drone
    # breathing, and this render was hitting digital zero between phrases.
    # drizzle therefore carries a whisper of the v1 air, level-set relative
    # to the music so the floor is audible in the gaps and submerged under
    # the chords, exactly like the rain rule.
    drone = music._drone(
        total, np.random.default_rng(13_290),
        [(music.D3, 0.26), (music.A3, 0.30), (music.D4, 0.22), (music.A4, 0.08)],
    )
    drone_bus = world._room_bus(drone, music.DRONE_SEND)
    drone_bus *= (
        world._phone_rms(music_bus) * world._db(DRIZZLE_AIR_DB)
        / max(world._phone_rms(drone_bus), 1e-12)
    )
    air_db = 20 * math.log10(
        max(world._phone_rms(drone_bus), 1e-12)
        / max(world._phone_rms(music_bus), 1e-12)
    )
    music_bus = music_bus + drone_bus
    rain = _rain(
        total, 13_280,
        base_hz=1.4, gust_depth=0.6, period_range=(18.0, 30.0), drip_prob=0.04,
    )
    bed, measured = _mix_rain(music_bus, rain, -24.0)
    info = {
        "bpm": 66.0, "swing": None, "feel": "~66 BPM feel, free placement (no grid, no percussion)",
        "bars": None, "phrase_count": fragments,
        "chord_events": chords,
        "gmaj9_events": int(gmaj9_used),
        "air_offset_target_db": DRIZZLE_AIR_DB, "air_under_music_db": round(air_db, 2),
        "rain_offset_target_db": -24.0, "rain_under_music_db": measured,
    }
    return bed, info


# ── rain mix + answers demo ────────────────────────────────────────────


def _mix_rain(
    music_bus: np.ndarray, rain_dry: np.ndarray, offset_db: float
) -> tuple[np.ndarray, float]:
    """Scale the rain to sit ``offset_db`` below the music's phone-band RMS
    (research window −20..−26); return the mix and the measured offset."""
    rain_bus = world._room_bus(rain_dry, RAIN_SEND)
    music_rms = world._phone_rms(music_bus)
    rain_rms = world._phone_rms(rain_bus)
    gain = music_rms * world._db(offset_db) / max(rain_rms, 1e-12)
    scaled = rain_bus * gain
    measured = 20 * math.log10(max(world._phone_rms(scaled), 1e-12) / max(music_rms, 1e-12))
    return music_bus + scaled, round(measured, 2)


def _true_peak(mono: np.ndarray, oversample: int = 4) -> float:
    """BS.1770-style true peak: the sample peak of a band-limited 4x
    reconstruction (FFT zero-pad interpolation). Inter-sample peaks sit
    above the raw sample peak, so guarding on this instead of ``max(abs)``
    keeps the written file's reconstructed waveform under the ceiling."""
    spec = np.fft.rfft(mono)
    up = np.fft.irfft(spec, n=len(mono) * oversample) * oversample
    return float(np.max(np.abs(up)))


def _next_swung_eighth(at: float, beat: float, swing: float, min_gap: float = 0.05) -> float:
    """The first swung-eighth grid point strictly after ``at + min_gap``."""
    target = at + min_gap
    b = math.floor(target / beat)
    while True:
        for candidate in (b * beat, b * beat + swing * beat):
            if candidate >= target:
                return candidate
        b += 1


def _render_umbrella_answers(
    bed: np.ndarray,
    roles: dict[str, np.ndarray],
    contact: np.ndarray,
    score: _Score,
) -> np.ndarray:
    """The loved mechanic in the new register: human-timed taps (instant,
    deliberately off-grid contacts), each answered by a soft high pentatonic
    tone snapped to the next SWUNG eighth. Taps are never quantized —
    answers are."""
    rng = np.random.default_rng(13_400)
    guard = _MotifGuard()
    beat = 60.0 / 72.0
    swing = 0.57
    frames = round(FLOW_SECONDS * SAMPLE_RATE)
    out = bed[:frames].copy()
    world._place(out, roles["navigate"], 1.3, 1.0)
    answer_midis = (74, 78, 81, 76, 83)  # D5 F#5 A5 E5 B5 — pentatonic only
    taps = (3.2, 4.35, 6.9, 9.3, 11.8)
    events = []
    for i, base in enumerate(taps):
        at = base + rng.uniform(-0.12, 0.12)  # human, off-grid on purpose
        world._place(out, contact, at, 0.5)
        answer_at = _next_swung_eighth(at, beat, swing)
        midi = guard.vet("answers", answer_midis[i])
        decay = rng.uniform(500.0, 700.0)
        world._place(
            out,
            _mnote(
                midi, 1.8, decay,
                seed=13_410 + i * 17,
                bloom_s=0.006,
                drift_cents=rng.uniform(-4.0, 2.0),
                excitation=LEAD_EXCITATION,
            ),
            answer_at,
            0.11,
        )
        events.append({
            "tap_t": round(at, 4),
            "answer_t": round(answer_at, 4),
            "voice": "answers",
            "midi": int(midi),
            "hz": round(_hz(midi), 3),
            "vel": 0.7,
            "dur_ms": round(decay * 4, 1),
        })
    score.meta["answers_demo"] = {
        "grid": "swung eighths, 57%",
        "rule": "taps never quantized; answers snap to the next swung eighth",
        "events": events,
    }
    # the same -6 dBFS peak guard music._calibrate applies to the beds,
    # applied to the SUMMED mix (bed + contacts + answers) — the bed's
    # calibrated level is never lowered on its own. Guarded AFTER _finish:
    # its DC-offset trim shifts the waveform and would nudge a guarded
    # peak back over the ceiling. Measured as a 4x-oversampled TRUE peak
    # and scaled to 0.1 dB below the ceiling: scaling the sample peak to
    # exactly -6 dBFS left inter-sample reconstruction peaks (plus int16
    # quantization) landing just over it.
    out = music._finish(out, 0.5)
    ceiling = world._db(-6.0)
    guard_target = world._db(-6.1)
    peak = _true_peak(out)
    if peak > ceiling:
        out = out * (guard_target / peak)
    return out


# ── study assembly ─────────────────────────────────────────────────────


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_study(output: Path, world_root: Path) -> dict[str, object]:
    contact_path = world_root / "shared" / "contact-master.wav"
    contact = world._fit(world._read_mono(contact_path), 0.014)
    roles = {}
    for role in ("navigate", "open", "select", "place"):
        role_path = world_root / "roles" / role / "1.wav"
        if not role_path.exists():
            raise FileNotFoundError(f"world role master missing: {role_path}")
        roles[role] = world._read_mono(role_path)

    candidates = (
        ("windowseat", _render_windowseat, 96.0, None, "straight eighths"),
        ("umbrella", _render_umbrella, 72.0, 0.57, "swung eighths"),
        ("drizzle", _render_drizzle, 66.0, None, "free"),
    )
    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "companion_to": "design/audits/2026-08-29/room-music-v1",
        "world_root": world_root.as_posix(),
        "contact_master": contact_path.as_posix(),
        "contact_master_sha256": _sha256(contact_path),
        "role_sources": {
            role: {"path": (world_root / "roles" / role / "1.wav").as_posix(),
                   "sha256": _sha256(world_root / "roles" / role / "1.wav")}
            for role in roles
        },
        "harmony": {
            "center": "B minor inside the D-major field (all pitches diatonic to D major)",
            "loop": "| Bm9 | Bm9 | F#m7(11) | F#m7(11) | A9sus | A9sus | Em9 | Em9 |",
            "bridge": "Gmaj9 -> A13 -> Dmaj9 -> Em9 (once per render where the candidate calls for it)",
            "tap_field": "D E F# A B — a subset of the harmony's scale; consonance by construction",
        },
        "target_phone_band_dbfs": TARGET_DBFS,
        "excitation_gain": {"keys": KEYS_EXCITATION, "lead": LEAD_EXCITATION},
        "rain": "Poisson micro-droplet grains, no broadband wash; level -20..-26 dB under the music's phone-band RMS",
        "seed_block": "13000-13499",
        "sample_format": "PCM_16",
        "candidates": {},
    }

    for name, renderer, bpm, swing, grid in candidates:
        score = _Score(bpm, swing, grid)
        bed, info = renderer(score)
        bed = music._finish(music._calibrate(bed, TARGET_DBFS))
        candidate_path = output / "candidates" / f"{name}.wav"
        music._write_16(candidate_path, bed)
        flow_path = output / "flows" / f"{name}-flow.wav"
        music._write_16(flow_path, music._flow(bed, roles))
        entry: dict[str, object] = dict(info)
        if name == "umbrella":
            answers_path = output / "flows" / "umbrella-answers.wav"
            music._write_16(
                answers_path, _render_umbrella_answers(bed, roles, contact, score)
            )
            entry["answers_sha256"] = _sha256(answers_path)
        score_path = output / f"{name}-score.json"
        score_path.parent.mkdir(parents=True, exist_ok=True)
        score_path.write_text(
            json.dumps(score.as_dict(), indent=2) + "\n", encoding="utf-8"
        )
        entry.update({
            "sha256": _sha256(candidate_path),
            "flow_sha256": _sha256(flow_path),
            "score": f"{name}-score.json",
            "score_sha256": _sha256(score_path),
            "seconds": round(len(bed) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(bed))), 6),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(world._phone_rms(bed), 1e-12)), 2
            ),
            "note_events": sum(1 for e in score.events if e["midi"] is not None),
            "percussion_events": sum(1 for e in score.events if e["midi"] is None),
        })
        manifest["candidates"][name] = entry  # type: ignore[index]

    manifest_path = output / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--world-study", type=Path, default=WORLD_ROOT)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.world_study), indent=2))


if __name__ == "__main__":
    main()
