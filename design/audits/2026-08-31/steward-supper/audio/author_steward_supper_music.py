"""steward-supper-music-v1 — one loopable room theme for explicit owner audition.

Successor to the recovered 2026-08-29 studies (see `recovered/RECOVERY.md`).
The owner approved the DIRECTION verbatim ("i would love some music though i
loved the music direction you came up with and then how the buttons could be
on beat with the background music"); no candidate file was ever auditioned.
This study turns that direction into one 112-second piece composed as a
seamless loop, because runtime (`lib/background_music.dart`) plays
`music/room-theme.m4a` with `ReleaseMode.loop` at the final measured gain
of 0.35. That later runtime mix decision is recorded separately from the
original study's authorship and remains subject to owner audition.

The instrument is the room's own voice: the world study's damped modal body
(`tool/author_room_sonic_world_study.py`) given a soft 12–35 ms bloom attack
in place of the 0.55 ms contact snap — a lamplit, thumb-piano-adjacent tone.
It is deliberately NOT presented as a piano, strings, or any real instrument;
local synthesis cannot honestly fake those, and the room already speaks this
voice through every approved tap, so the music and the interactions are one
world by construction. Every pitch sits on the D-major pentatonic field; the
Paired Return motif (D5 A5 E5 D5) is excluded so the easter egg stays rare.

Setting the piece is written for: the candlelit inhabited room, and the small
side room where the Steward eats supper by a rainy window. Warm, reflective,
never sentimental; quiet enough to read over. The rain is not literal (a
noise bed reads as hiss — world rule); it appears as slow falling answer
contours in the middle section, like water finding its way down a pane.

Form (28 bars of 4/4 at 60 bpm = 112.0 s exactly; the seam lands in the
sparsest air so the loop is a held breath, not an edit):

    bars  0–3   air and the softest tread — the room, inhabited
    bars  4–11  three low phrases: the room speaks under candlelight
    bars 12–18  supper by the window: low statements, falling high answers
    bars 19–24  a gentle wander — the quiet high point, still readable-over
    bars 25–27  one closing phrase settles on D and decays into the loop

Everything is placed modulo the loop length (tails wrap into bar 0), the
drone is generated with an 8 s wrap crossfade so the seam is phase-continuous,
and the room bus is applied over a tiled copy so reflections also wrap.
Deterministic seeds 13000–13400; no wall clock, no uncontrolled randomness.

Run from this directory:

    python author_steward_supper_music.py --output steward-supper-music-v1

The bundled AAC is encoded separately (see README) so the recipe stays
dependency-light; this script renders masters and evidence WAVs only.
"""

from __future__ import annotations

import sys

sys.dont_write_bytecode = True  # never pollute tool/__pycache__ (not owned)

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, sosfilt

HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parents[4]
sys.path.insert(0, str(WORKTREE / "tool"))

import author_room_sonic_world_study as world  # noqa: E402

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "steward-supper-music-v1"
RENDER_VERSION = "steward-supper-author-v1"

BPM = 60.0
BEAT = 60.0 / BPM             # 1.0 s
EIGHTH = BEAT / 2.0           # 0.5 s
BAR = BEAT * 4.0              # 4.0 s
BARS = 28
LOOP_SECONDS = BARS * BAR     # 112.0 s
LOOP_FRAMES = round(LOOP_SECONDS * SAMPLE_RATE)

TARGET_LUFS = -24.0
EXCITATION = 0.025            # per-note; a bed's noise budget is per minute
PHRASE_SEND = 0.85 * 0.8
DRONE_SEND = 0.40
PLAYER_VOLUME = 0.35          # Final BackgroundMusicController gain, after measured mix review.

WORLD_ROOT = WORKTREE / "design/audits/2026-08-20/room-sonic-world-v1"
SFX_ROOT = WORKTREE / "assets/sfx"

# D-major pentatonic, spelled exactly as the sibling studies spell it.
D3, A3 = 146.8325, 220.000
D4, E4, FS4, A4, B4 = 293.665, 329.628, 369.994, 440.000, 493.883
D5, E5, FS5, A5, B5 = 587.330, 659.255, 739.989, 880.000, 987.767
SCALE = (D4, E4, FS4, A4, B4, D5, E5, FS5, A5, B5)
STABLE = {0, 3, 5, 8}         # D4, A4, D5, A5
PAIRED_RETURN = (D5, A5, E5, D5)


# ── shared small helpers ─────────────────────────────────────────────────


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _note(
    hz: float,
    seconds: float,
    decay_ms: float,
    *,
    seed: int,
    bloom_s: float,
    drift_cents: float,
) -> np.ndarray:
    """The musical body: the world's modal voice with a soft bloom attack."""
    body = world._modal_body(
        hz,
        seconds,
        decay_ms,
        seed=seed,
        low_support=hz < 340.0,
        drift_cents=drift_cents,
        excitation_gain=EXCITATION,
    )
    t = np.arange(len(body)) / SAMPLE_RATE
    return body * (1.0 - np.exp(-t / max(bloom_s, 1e-4)))


def _place_wrap(base: np.ndarray, audio: np.ndarray, at_seconds: float, gain: float) -> None:
    """Place audio at a loop position; anything past the end wraps to bar 0."""
    n = len(base)
    start = round(at_seconds * SAMPLE_RATE) % n
    first = min(len(audio), n - start)
    base[start : start + first] += audio[:first] * gain
    remaining = len(audio) - first
    if remaining > 0:
        if remaining > n:
            raise ValueError("note longer than the loop itself")
        base[:remaining] += audio[first:] * gain


def _loop_bus(dry: np.ndarray, send: float) -> np.ndarray:
    """Room bus whose reflections wrap across the seam: run the causal bus
    over two tiled copies and keep the second, which has heard the first's
    tail — exactly what looping playback produces."""
    tiled = world._room_bus(np.tile(dry, 2), send)
    return tiled[len(dry) :].copy()


def _drone_loop(rng: np.random.Generator, layers, tide_depth: float) -> np.ndarray:
    """Warm detuned air, generated 8 s long past the loop and wrap-crossfaded
    so the seam is phase-continuous. Pure tones only — no noise bed. A very
    shallow bar tide (peaking at each downbeat) gives the air a pulse you
    feel rather than hear."""
    xfade_s = 8.0
    frames = LOOP_FRAMES + round(xfade_s * SAMPLE_RATE)
    t = np.arange(frames) / SAMPLE_RATE
    out = np.zeros(frames)
    for hz, gain in layers:
        detune = 1.0 + rng.uniform(0.0035, 0.0060)
        phase_a, phase_b = rng.uniform(0, 2 * math.pi, size=2)
        pair = 0.5 * (
            np.sin(2 * math.pi * hz * t + phase_a)
            + np.sin(2 * math.pi * hz * detune * t + phase_b)
        )
        breath_rate = rng.uniform(0.008, 0.030)
        breath_phase = rng.uniform(0, 2 * math.pi)
        breath = 0.55 + 0.45 * np.sin(2 * math.pi * breath_rate * t + breath_phase)
        out += pair * breath * gain
    tide_phase = (t % BAR) / BAR
    tide = (1.0 - tide_depth) + tide_depth * (0.5 + 0.5 * np.cos(2 * math.pi * tide_phase)) ** 2
    out *= tide
    out = world._filter(out, highpass_hz=120, lowpass_hz=2_600, order=2)
    xfade = round(xfade_s * SAMPLE_RATE)
    loop = out[:LOOP_FRAMES].copy()
    fade_in = np.sin(np.linspace(0, math.pi / 2, xfade)) ** 2
    loop[:xfade] = out[LOOP_FRAMES:] * (1.0 - fade_in) + out[:xfade] * fade_in
    return loop


# ── phrase language ──────────────────────────────────────────────────────


def _snap(at: float, rng: np.random.Generator) -> float:
    """Eighth-note grid, humanized ±15 ms — it breathes, never ticks."""
    return round(at / EIGHTH) * EIGHTH + rng.uniform(-0.015, 0.015)


def _arch_velocities(count: int, rng: np.random.Generator) -> list[float]:
    """A human phrase swells toward its middle and lets go at its end."""
    vels = []
    for i in range(count):
        arc = math.sin(math.pi * (i + 0.5) / count)
        vels.append((0.62 + 0.30 * arc) * rng.uniform(0.90, 1.0))
    vels[-1] *= 0.78  # the last word of a sentence is quieter, not louder
    return vels


def _walk(rng: np.random.Generator, length: int, lo: int, hi: int, rise_bias: float):
    """Stepwise pentatonic walk that arcs and resolves on D or A."""
    while True:
        idx = int(rng.integers(lo, hi + 1))
        degrees = [idx]
        for step_at in range(length - 1):
            first_half = step_at < (length - 1) / 2
            bias = rise_bias if first_half else -rise_bias
            r = rng.random()
            if r < 0.32 + bias:
                idx += 1
            elif r < 0.64:
                idx -= 1
            elif r < 0.76:
                idx += 2 if rng.random() < 0.5 + bias else -2
            elif r < 0.82:
                pass
            else:
                idx += int(rng.integers(-3, 4))
            idx = max(lo, min(hi, idx))
            degrees.append(idx)
        stable = sorted(s for s in STABLE if lo <= s <= hi) or [lo]
        degrees[-1] = min(stable, key=lambda s: abs(s - degrees[-1]))
        tones = tuple(SCALE[d] for d in degrees)
        if tones[-4:] != PAIRED_RETURN and tones[:4] != PAIRED_RETURN:
            return degrees


def _falling_answer(rng: np.random.Generator, length: int):
    """Rain on the pane: a high answer that only ever steps downward,
    settling on D5 or A5."""
    top = int(rng.integers(7, 10))
    degrees = [top]
    idx = top
    for _ in range(length - 1):
        idx -= 1 if rng.random() < 0.7 else 2
        idx = max(5, idx)
        degrees.append(idx)
    stable_high = [s for s in (5, 8) if s <= degrees[-1] + 1]
    degrees[-1] = min(stable_high or [5], key=lambda s: abs(s - degrees[-1]))
    return degrees


class NoteLog:
    """Every scheduled melodic pitch in order, for the motif-exclusion check."""

    def __init__(self) -> None:
        self.tones: list[float] = []

    def add(self, hz: float) -> None:
        self.tones.append(hz)

    def assert_no_paired_return(self) -> None:
        for i in range(len(self.tones) - 3):
            if tuple(self.tones[i : i + 4]) == PAIRED_RETURN:
                raise AssertionError("Paired Return motif leaked into the piece")


def _play_phrase(
    stem: np.ndarray,
    rng: np.random.Generator,
    log: NoteLog,
    *,
    at_bar: float,
    degrees,
    decay: tuple[float, float],
    gain: float,
    seed_base: int,
    note_index: int,
    final_stretch: float = 1.0,
) -> tuple[float, int]:
    """One phrase on the humanized eighth grid. Returns (end_s, note_index)."""
    t = _snap(at_bar * BAR, rng)
    vels = _arch_velocities(len(degrees), rng)
    for i, degree in enumerate(degrees):
        hz = SCALE[degree]
        last = i == len(degrees) - 1
        decay_ms = rng.uniform(*decay) * (1.5 if last else 1.0)
        dur = min(decay_ms / 1000.0 * 4.0, 10.0)
        _place_wrap(
            stem,
            _note(
                hz,
                dur,
                decay_ms,
                seed=seed_base + note_index * 17,
                bloom_s=rng.uniform(0.012, 0.035),
                drift_cents=rng.uniform(-5.0, 3.0),
            ),
            t,
            gain * vels[i],
        )
        log.add(hz)
        note_index += 1
        if not last:
            steps = 1 if rng.random() < 0.62 else 2
            stretch = final_stretch if i == len(degrees) - 2 else 1.0
            t = _snap(t + steps * EIGHTH * stretch, rng)
    return t, note_index


# ── the piece ────────────────────────────────────────────────────────────


def render_theme() -> tuple[np.ndarray, dict[str, object]]:
    rng = np.random.default_rng(13_000)
    log = NoteLog()

    drone = _drone_loop(
        np.random.default_rng(13_050),
        [(D3, 0.28), (A3, 0.32), (D4, 0.25), (FS4, 0.07)],
        tide_depth=0.10,
    ) * 0.85

    stem = np.zeros(LOOP_FRAMES)

    # The tread: the softest low footstep on most bar downbeats. A few bars
    # are skipped so it stays a person moving about, not a metronome.
    step_rng = np.random.default_rng(13_100)
    skipped = {3, 9, 14, 22, 26}
    for bar in range(BARS):
        if bar in skipped:
            continue
        hz = A3 if bar in (5, 13, 21) else D3
        _place_wrap(
            stem,
            _note(
                hz, 1.6, 260.0,
                seed=13_110 + bar * 17,
                bloom_s=0.008,
                drift_cents=step_rng.uniform(-3.0, 1.0),
            ),
            bar * BAR + step_rng.uniform(-0.012, 0.012),
            step_rng.uniform(0.034, 0.052),
        )

    note_index = 0
    phrase_count = 0

    # bars 4–11 — the room speaks low, three unhurried sentences
    for at_bar, length in ((4.25, 3), (7.5, 2), (10.25, 4)):
        degrees = _walk(rng, length, 0, 4, rise_bias=0.05)
        _, note_index = _play_phrase(
            stem, rng, log,
            at_bar=at_bar, degrees=degrees,
            decay=(1900.0, 2700.0), gain=0.155,
            seed_base=13_200, note_index=note_index,
        )
        phrase_count += 1

    # bars 12–18 — supper by the window: low statement, falling high answer
    for at_bar, low_len, ans_len in ((12.25, 3, 2), (15.75, 2, 3)):
        low = _walk(rng, low_len, 0, 4, rise_bias=0.04)
        end, note_index = _play_phrase(
            stem, rng, log,
            at_bar=at_bar, degrees=low,
            decay=(1800.0, 2500.0), gain=0.15,
            seed_base=13_240, note_index=note_index,
        )
        answer = _falling_answer(rng, ans_len)
        _, note_index = _play_phrase(
            stem, rng, log,
            at_bar=(end + rng.uniform(1.5, 2.4)) / BAR, degrees=answer,
            decay=(850.0, 1300.0), gain=0.095,
            seed_base=13_260, note_index=note_index,
        )
        phrase_count += 1

    # bars 19–24 — the wander: two walking phrases, one soft octave echo
    echo_done = False
    for at_bar, length in ((19.5, 5), (22.4, 4)):
        degrees = _walk(rng, length, 0, 9, rise_bias=0.10)
        end, note_index = _play_phrase(
            stem, rng, log,
            at_bar=at_bar, degrees=degrees,
            decay=(1400.0, 2200.0), gain=0.145,
            seed_base=13_300, note_index=note_index,
        )
        if not echo_done and degrees[-1] + 5 <= 9:
            hz = SCALE[degrees[-1] + 5]
            _place_wrap(
                stem,
                _note(
                    hz, 2.2, rng.uniform(750.0, 1000.0),
                    seed=13_340 + note_index * 17,
                    bloom_s=0.020,
                    drift_cents=rng.uniform(-4.0, 2.0),
                ),
                end + 0.9,
                0.045,
            )
            log.add(hz)
            note_index += 1
            echo_done = True
        phrase_count += 1

    # bars 25–27 — the close: settle to D4, the last spacing broadened like
    # a sentence ending, its tail decaying into the loop's opening air
    closing = [3, 1, 0]  # A4 → E4 → D4
    _, note_index = _play_phrase(
        stem, rng, log,
        at_bar=25.5, degrees=closing,
        decay=(2300.0, 3000.0), gain=0.15,
        seed_base=13_380, note_index=note_index,
        final_stretch=1.8,
    )
    phrase_count += 1

    log.assert_no_paired_return()

    mix = _loop_bus(stem, PHRASE_SEND) + _loop_bus(drone, DRONE_SEND)
    mix -= float(np.mean(mix))  # remove DC uniformly; no fades — it loops
    info = {
        "bars": BARS,
        "bpm": BPM,
        "phrase_count": phrase_count,
        "melodic_notes": len(log.tones),
        "footstep_bars_skipped": sorted(skipped),
    }
    return mix, info


# ── measurement: BS.1770-4 integrated loudness, true peak, seam ─────────


_PRE_SOS = np.array([
    [1.53512485958697, -2.69169618940638, 1.19839281085285,
     1.0, -1.69065929318241, 0.73248077421585],
])
_RLB_SOS = np.array([
    [1.0, -2.0, 1.0, 1.0, -1.99004745483398, 0.99007225036621],
])


def integrated_lufs(audio: np.ndarray) -> float:
    """ITU-R BS.1770-4 integrated loudness of a mono 48 kHz signal.
    The K-weighting coefficients are the standard's own 48 kHz tables."""
    weighted = sosfilt(_RLB_SOS, sosfilt(_PRE_SOS, audio))
    block = round(0.400 * SAMPLE_RATE)
    hop = round(0.100 * SAMPLE_RATE)
    if len(weighted) < block:
        raise ValueError("signal shorter than one gating block")
    starts = range(0, len(weighted) - block + 1, hop)
    z = np.array([
        float(np.mean(weighted[s : s + block] ** 2)) for s in starts
    ])
    loudness = -0.691 + 10 * np.log10(np.maximum(z, 1e-12))
    abs_gated = z[loudness > -70.0]
    if not len(abs_gated):
        return -70.0
    rel_threshold = -0.691 + 10 * math.log10(float(np.mean(abs_gated))) - 10.0
    gated = z[(loudness > -70.0) & (loudness > rel_threshold)]
    if not len(gated):
        return -70.0
    return -0.691 + 10 * math.log10(float(np.mean(gated)))


def true_peak_dbtp(audio: np.ndarray) -> float:
    over = resample_poly(audio, 4, 1)
    return 20 * math.log10(max(float(np.max(np.abs(over))), 1e-12))


def seam_metrics(audio: np.ndarray) -> dict[str, float]:
    """Numeric evidence that end→start plays without a click: the first
    difference across the seam must look like every other first difference."""
    tiled = np.concatenate([audio[-SAMPLE_RATE:], audio[:SAMPLE_RATE]])
    diff = np.abs(np.diff(tiled))
    seam_at = SAMPLE_RATE - 1
    seam_diff = float(diff[seam_at])
    body_diff = np.abs(np.diff(audio))
    p999 = float(np.quantile(body_diff, 0.999))
    win = round(0.050 * SAMPLE_RATE)
    rms = lambda x: float(np.sqrt(np.mean(x**2)))
    return {
        "seam_step_abs": float(np.abs(audio[0] - audio[-1])),
        "seam_first_difference": seam_diff,
        "body_first_difference_p999": p999,
        "seam_diff_vs_body_p999_ratio": seam_diff / max(p999, 1e-12),
        "rms_50ms_before_seam_dbfs": 20 * math.log10(max(rms(audio[-win:]), 1e-12)),
        "rms_50ms_after_seam_dbfs": 20 * math.log10(max(rms(audio[:win]), 1e-12)),
    }


def calibrate_lufs(audio: np.ndarray, target: float) -> tuple[np.ndarray, float]:
    out = audio
    measured = integrated_lufs(out)
    for _ in range(3):
        out = out * (10 ** ((target - measured) / 20))
        measured = integrated_lufs(out)
        if abs(measured - target) < 0.05:
            break
    return out, measured


# ── evidence renders ─────────────────────────────────────────────────────


def _write(path: Path, audio: np.ndarray, subtype: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    if peak >= 1.0:
        raise ValueError(f"render would clip: peak {peak:.4f} at {path.name}")
    sf.write(path, audio, SAMPLE_RATE, subtype=subtype)


def _sfx(rel: str) -> np.ndarray:
    return world._read_mono(SFX_ROOT / rel)


def render_audition_reel(master: np.ndarray, music_gain: float) -> np.ndarray:
    """Ordinary product use over the theme: approved production masters at
    their shipped in-file levels (runtime volume 1.0), music underneath at
    the given gain. Starts mid-piece (t=40 s) so phrases are present."""
    seconds = 32.0
    frames = round(seconds * SAMPLE_RATE)
    start = round(40.0 * SAMPLE_RATE)
    out = np.tile(master, 2)[start : start + frames] * music_gain

    ordinary = {
        verb: [_sfx(f"room/ordinary/{verb}/{i}.wav") for i in range(1, 6)]
        for verb in ("open", "select", "navigate", "place")
    }
    completion = _sfx("room/completion/completion-composite.wav")

    timeline = [
        (1.0, "navigate", 0), (2.2, "open", 1), (3.1, "select", 2),
        (4.0, "select", 3), (5.4, "place", 4), (8.2, "navigate", 1),
        (9.0, "open", 2), (10.1, "select", 0),
    ]
    for at, verb, take in timeline:
        world._place(out, ordinary[verb][take], at, 1.0)
    world._place(out, completion, 12.5, 1.0)
    # 13.5–19.5: nothing — reading over the music
    world._place(out, ordinary["select"][1], 19.6, 1.0)
    world._place(out, ordinary["navigate"][2], 20.4, 1.0)
    for i in range(5):  # legitimate rapid alternation, shipped masters as-is
        world._place(out, ordinary["select"][i], 21.2 + i * 0.18, 1.0)
    world._place(out, ordinary["place"][0], 24.0, 1.0)
    world._place(out, completion, 26.5, 1.0)
    fade = round(0.4 * SAMPLE_RATE)
    out[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
    return out


def render_spectrogram(master: np.ndarray, path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(14, 4.5), dpi=110)
    ax.specgram(master, NFFT=4096, Fs=SAMPLE_RATE, noverlap=2048, cmap="magma",
                vmin=-140, vmax=-40)
    ax.set_ylim(0, 4000)
    ax.set_xlabel("seconds")
    ax.set_ylabel("Hz")
    ax.set_title("steward-supper-theme master — 112 s loop (seam at 0/112)")
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


# ── build ────────────────────────────────────────────────────────────────


def build(output: Path) -> dict[str, object]:
    master, info = render_theme()
    master, measured_lufs = calibrate_lufs(master, TARGET_LUFS)

    peak = float(np.max(np.abs(master)))
    tp = true_peak_dbtp(master)
    if tp > -3.0:
        raise ValueError(f"true peak {tp:.2f} dBTP above -3 dBTP guard")

    master_path = output / "master" / "steward-supper-theme-master.wav"
    _write(master_path, master, "PCM_24")

    # loop seam audition: exactly what looping playback crosses — the last
    # 10 s followed by the first 10 s, no processing at the joint
    seam_path = output / "evidence" / "loop-seam-audition.wav"
    _write(seam_path, np.concatenate([master[-10 * SAMPLE_RATE :], master[: 10 * SAMPLE_RATE]]), "PCM_16")

    music_only_path = output / "evidence" / "music-only-player-gain.wav"
    _write(music_only_path, master[: round(40 * SAMPLE_RATE)] * PLAYER_VOLUME, "PCM_16")

    reel_player_path = output / "evidence" / "audition-reel-player-gain.wav"
    reel_player = render_audition_reel(master, PLAYER_VOLUME)
    _write(reel_player_path, reel_player, "PCM_16")

    reel_master_path = output / "evidence" / "audition-reel-master-level.wav"
    _write(reel_master_path, render_audition_reel(master, 1.0), "PCM_16")

    spectrogram_path = output / "evidence" / "master-spectrogram.png"
    spectrogram_path.parent.mkdir(parents=True, exist_ok=True)
    render_spectrogram(master, spectrogram_path)

    music_at_player = master * PLAYER_VOLUME
    measurements = {
        "master": {
            "path": master_path.relative_to(output).as_posix(),
            "sample_rate": SAMPLE_RATE,
            "channels": 1,
            "subtype": "PCM_24",
            "frames": len(master),
            "seconds": len(master) / SAMPLE_RATE,
            "integrated_lufs_bs1770_4": round(measured_lufs, 2),
            "target_lufs": TARGET_LUFS,
            "sample_peak_dbfs": round(20 * math.log10(max(peak, 1e-12)), 2),
            "true_peak_dbtp_4x": round(tp, 2),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(world._phone_rms(master), 1e-12)), 2
            ),
            "dc_offset": float(np.mean(master)),
            "seam": seam_metrics(master),
        },
        "at_player_volume_0_35": {
            "integrated_lufs_bs1770_4": round(integrated_lufs(music_at_player), 2),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(world._phone_rms(music_at_player), 1e-12)), 2
            ),
            "note": "final local review gain from BackgroundMusicController (0.35 linear = -9.1 dB); phone taste approval remains pending",
        },
        "composition": info,
    }

    manifest = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "recipe": "author_steward_supper_music.py",
        "seed_block": "13000-13400",
        "loop": {"bars": BARS, "bpm": BPM, "seconds": LOOP_SECONDS},
        "world_root": WORLD_ROOT.as_posix(),
        "predecessors": {
            "room-music-v1": "recovered/room-music-v1 (direction approved 2026-08-29; files never auditioned)",
            "room-music-pulse-v1": "recovered/room-music-pulse-v1 (same)",
        },
        "provenance": {
            "synthesis": "deterministic project-authored synthesis only: world modal voice + detuned sine air through the shared room bus",
            "samples_imported": False,
            "reference_audio_used": False,
            "external_services_used": False,
            "paired_return_motif_excluded": True,
            "sfx_in_reels": "approved production masters read from assets/sfx at shipped levels; not modified",
        },
        "files": {},
        "measurements": measurements,
    }
    for p in (master_path, seam_path, music_only_path, reel_player_path, reel_master_path):
        manifest["files"][p.relative_to(output).as_posix()] = _sha256(p)  # type: ignore[index]

    (output / "measurements.json").write_text(
        json.dumps(measurements, indent=2) + "\n", encoding="utf-8"
    )
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=HERE / STUDY_ID)
    args = parser.parse_args()
    manifest = build(args.output)
    print(json.dumps(manifest["measurements"], indent=2))


if __name__ == "__main__":
    main()
