#!/usr/bin/env python3
"""Author the class chime: six pitched takes for the Doorway's hang.

Written 2026-10-11, after the owner auditioned the "Soft hand" tap palette on
his phone and asked that the class chime vary its note instead of repeating
one ("it'd be best if you also vary the keys of the class chime rather than
sticking to just one note").

The chime is the SAME synthesis the Soft hand uses for its brass lane, not a
new instrument: `render_brass` below is the Soft hand's own brass renderer
(design/audits/2026-10-11/soft-hand/render_taps.py), carried over line for
line, and the chime is that renderer driven by a different spec. Every piece
of the shared world comes from tool/author_room_sonic_world_study.py and the
approved contact master:

  * the contact master (softened: raised-cosine smoothed, band-limited grain),
  * the felt-muted brass dyad (root x 1.007 beat, 1.5 and 2.0 partials, a
    small soft bell partial at 2.756),
  * the 22 / 29 / 34 ms room fingerprint,
  * the D-major pentatonic pitch field (SOUND-DESIGN.md section 3).

No sample, no foreign synthesis. The six takes are the field's rising line:
D5 E5 F#5 A5 B5 D6. Take N plays for the Nth class kept today (the seventh
starts over at 1). One file per step, so a step is always the same note.

Run from the worktree root:

    python tool/author_class_chime.py                 # write the masters
    python tool/author_class_chime.py --handoff DIR   # also write listening copies
    python tool/author_class_chime.py --check         # no writes: prove the
                                                      # synthesis still matches
                                                      # the shipped Soft hand

Needs numpy, scipy and soundfile. Output: assets/sfx/room/class_chime/N.wav
(mono PCM 16-bit 44.1 kHz, like the Soft hand takes) and
design/audits/2026-10-11/class-chime/manifest.json.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

import author_room_sonic_world_study as world  # noqa: E402

CONTACT_MASTER = (
    ROOT / "design/audits/2026-08-20/room-sonic-world-v1/shared/contact-master.wav"
)
CHIME_DIR = ROOT / "assets/sfx/room/class_chime"
AUDIT_DIR = ROOT / "design/audits/2026-10-11/class-chime"

SR = world.SAMPLE_RATE  # 48000: the world renders at 48 kHz
OUT_SR = 44100  # written as mono 44.1 kHz 16-bit, like the Soft hand

STEPS = 6
SEED_BASE = 16000

# The pitch field (D-major pentatonic: D E F# A B), in the phone-readable
# 550 to 1400 Hz body band. The sixth step is the octave root.
NOTES = ("D5", "E5", "F#5", "A5", "B5", "D6")
HZ = {
    "D4": 293.665,
    "E4": 329.628,
    "F#4": 369.994,
    "A4": 440.0,
    "B4": 493.883,
    "D5": 587.330,
    "E5": 659.255,
    "F#5": 739.989,
    "A5": 880.0,
    "B5": 987.767,
    "D6": 1174.659,
    "E6": 1318.510,
    "F#6": 1479.978,
    "A6": 1760.0,
    "B6": 1975.533,
}


# ---------------------------------------------------------------------------
# The Soft hand's shared parts, carried over from render_taps.py unchanged.
# ---------------------------------------------------------------------------


def cents(f, c):
    return f * 2 ** (c / 1200)


def rc_rise(n):
    """Raised-cosine rise 0 -> 1 over n samples."""
    x = np.arange(n) / max(n, 1)
    return 0.5 - 0.5 * np.cos(math.pi * x)


def attack_env(n_total, atk_ms):
    env = np.ones(n_total)
    na = min(n_total, round(atk_ms / 1000 * SR))
    env[:na] = rc_rise(na)
    return env


_CONTACT = None


def contact_master():
    global _CONTACT
    if _CONTACT is None:
        a, _sr = sf.read(str(CONTACT_MASTER), dtype="float64")
        _CONTACT = a
    return _CONTACT


def soft_contact(n, atk_ms, rng, band=(300, 2500), tau_ms=9.0, master_mix=0.55):
    """The same hand, softened: the approved contact master smoothed with a
    raised-cosine kernel, plus a band-limited noise grain with its own soft
    attack. 300 Hz to 2.5 kHz, rolled off above ~3 kHz."""
    t = np.arange(n) / SR
    k = max(3, round(atk_ms / 1000 * SR))
    kern = np.hanning(k * 2 + 1)
    kern /= kern.sum()
    m = np.convolve(contact_master(), kern, mode="full")
    m = np.concatenate([np.zeros(round(rng.uniform(0.0, 0.0006) * SR)), m])
    m = world._bandpass(m, band[0], band[1], order=2)
    m = m / (np.max(np.abs(m)) or 1)
    mm = np.zeros(n)
    mm[: min(n, len(m))] = m[:n]
    mm *= np.exp(-np.maximum(t - 0.004, 0) / 0.006)
    g = rng.standard_normal(n)
    g = world._bandpass(g, band[0], band[1], order=2)
    g /= np.max(np.abs(g)) or 1
    g *= attack_env(n, atk_ms) * np.exp(-t / (tau_ms / 1000))
    c = master_mix * mm + (1 - master_mix) * g
    c = world._filter(c, lowpass_hz=3000, order=2)
    return c / (np.max(np.abs(c)) or 1)


def softknee(a, thr=0.6, slope=0.45):
    """Gently rounds the single highest peaks so the crest stays low."""
    p = np.max(np.abs(a)) or 1.0
    T = thr * p
    mag = np.abs(a)
    return np.where(mag > T, np.sign(a) * (T + (mag - T) * slope), a)


def to_44k(a):
    return resample_poly(a, 147, 160)


def db(x):
    return 20 * math.log10(max(x, 1e-12))


def measure(a, sr):
    """Peak, crest, attack, HF share and phone-band RMS: the Soft hand's own
    measurement (design/audits/2026-10-11/soft-hand/measure.py)."""
    pk = float(np.max(np.abs(a)))
    rms = float(np.sqrt(np.mean(a * a)))
    hp = sosfilt(butter(2, 4000, "highpass", fs=sr, output="sos"), a)
    hf = float(np.sqrt(np.mean(hp * hp)))
    win = max(1, round(0.0005 * sr))
    n = len(a) // win
    peaks = np.array([np.max(np.abs(a[i * win : (i + 1) * win])) for i in range(n)])
    pkdb = 20 * np.log10(np.maximum(peaks, 1e-12))
    mx = pkdb.max()
    idx = int(np.argmax(pkdb >= mx - 1.0))
    bp = sosfilt(butter(2, [260, 8000], "bandpass", fs=sr, output="sos"), a)
    return dict(
        dur_ms=round(len(a) / sr * 1000, 1),
        peak=round(db(pk), 2),
        rms=round(db(rms), 2),
        crest=round(db(pk) - db(rms), 2),
        hf=round(db(hf) - db(rms), 2),
        attack_ms=round(idx * 0.5, 1),
        phone_rms=round(db(float(np.sqrt(np.mean(bp * bp)))), 2),
    )


def finish(
    dry,
    send,
    dur_ms,
    target_peak_db,
    fade_ms=8.0,
    lp=3400,
    knee=(0.6, 0.45),
    crest_max=13.6,
    hf_max=-20.5,
):
    """Room fingerprint (subliminal), park the tail, level to the peak target.
    If a take lands above the crest or HF-share ceilings, the peak knee gets a
    little stronger and the lowpass a little lower until it passes."""
    n = round(dur_ms / 1000 * SR)
    d0 = np.zeros(n)
    d0[: min(n, len(dry))] = dry[:n]
    knees = [
        knee,
        (0.5, 0.38),
        (0.42, 0.32),
        (0.35, 0.26),
        (0.3, 0.2),
        (0.25, 0.15),
        (0.2, 0.1),
        (0.15, 0.06),
    ]
    wet = None
    if lp < 3000:
        knees = [(1.0, 1.0)] + knees  # tonal glass: try with no knee first
    for step, kn in enumerate(knees):
        d = softknee(d0, *kn)
        d = world._filter(d, highpass_hz=180, lowpass_hz=lp * (0.93**step), order=2)
        wet = world._room_bus(d, send)
        wet = world._park(wet, fade_ms)
        wet = wet / np.max(np.abs(to_44k(wet))) * 10 ** (target_peak_db / 20)
        m = measure(to_44k(wet), OUT_SR)
        if m["crest"] <= crest_max and m["hf"] <= hf_max:
            break
    return wet


def write44(path, a, peak_db=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    y = to_44k(a)
    if peak_db is not None:
        y = y / np.max(np.abs(y)) * 10 ** (peak_db / 20)
    pk = np.max(np.abs(y))
    if pk > 0.98:
        y = y * 0.98 / pk
    sf.write(str(path), y, OUT_SR, subtype="PCM_16")
    return y


def jit(rng, base, frac):
    return base * (1 + rng.uniform(-frac, frac))


# The Soft hand's brass partials: (amplitude, extra decay scale) for the root,
# the 1.007 beating twin, the 1.5, 2.0 and 2.756 partials. A spec may restate
# them; the defaults reproduce the shipped brass lane bit for bit.
BRASS_AMPS = (0.40, 0.17, 0.14, 0.08, 0.05)


def render_brass(verb, spec, take_i, seed):
    """The Soft hand's brass renderer (render_taps.py), unchanged in what it
    does with the defaults. `spec` may also carry `amps` and `contact_gain`."""
    rng = np.random.default_rng(seed)
    note, c = spec["takes"][take_i]
    f0 = cents(HZ[note], c)
    n = round((spec["dur"] + 40) / 1000 * SR)
    t = np.arange(n) / SR
    atk = rng.uniform(*spec["atk"])
    tau = jit(rng, spec["tau"], 0.10) / 1000
    amps = spec.get("amps", BRASS_AMPS)
    if spec.get("bell_ref_hz"):
        # keep the small bell partial from climbing into the handset's
        # fatiguing 3 to 5 kHz as the root rises: above the reference pitch
        # its amplitude follows (ref / root) ** 1.2
        amps = amps[:4] + (amps[4] * min(1.0, (spec["bell_ref_hz"] / f0) ** 1.2),)
    # the twin's detune: the Soft hand's root x 1.007, or (a chime) a fixed beat
    # rate in Hz so the shimmer is the same slow pulse on every step
    twin = 1 + spec["beat_hz"] / f0 if spec.get("beat_hz") else 1.007
    ph0 = np.array([math.pi / 2, math.pi / 2, 1.0, 2.0, 0.5, 0.0])
    # felt-muted dyad with a slow beat (root x 1.007), 1.5 and 2.0 partials,
    # and a small soft bell partial high above (gold-only primary)
    body = (
        amps[0] * np.sin(2 * math.pi * f0 * t + ph0[0])
        + amps[1] * np.sin(2 * math.pi * f0 * twin * t + ph0[1])
        + amps[2] * np.sin(2 * math.pi * f0 * 1.5 * t + ph0[2]) * np.exp(-t / (tau * 0.7))
        + amps[3] * np.sin(2 * math.pi * f0 * 2.0 * t + ph0[3]) * np.exp(-t / (tau * 0.55))
        + amps[4] * np.sin(2 * math.pi * f0 * 2.756 * t + ph0[4]) * np.exp(-t / (tau * 0.4))
    )
    body *= np.exp(-t / tau) * attack_env(n, atk)
    ct = soft_contact(n, atk, rng, band=(300, 1800), tau_ms=7.0)
    voice = body / (np.max(np.abs(body)) or 1) + spec.get("contact_gain", 0.22) * rng.uniform(0.85, 1.15) * ct
    if spec.get("settle"):
        dly, gain = spec["settle"]
        ds = round(dly * rng.uniform(0.9, 1.15) * SR)
        sb = body[: n - ds] / (np.max(np.abs(body)) or 1)
        sett = np.zeros(n)
        sett[ds:] = sb * gain * 0.6
        voice = voice + sett
    return finish(
        voice,
        spec["send"],
        spec["dur"],
        spec["peak"] + rng.uniform(-0.4, 0.4),
        fade_ms=spec.get("fade_ms", 9.0),
        crest_max=spec.get("crest_max", 13.6),
    )


# ---------------------------------------------------------------------------
# The chime: the brass renderer, a longer warmer decay, a softer attack and
# the field's rising line.
# ---------------------------------------------------------------------------

# Soft hand brass/place is the reference: tau 120, 300 ms, peak -16.5 dBFS,
# attack 5 ms, settle after 30 ms. The chime differs only in what a chime
# needs: more time to ring (tau 135, 480 ms: about -20 dB by 310 ms, -31 dB at
# the end, then parked), a softer rise (6 to 7 ms), a 2.0 partial that carries
# the pitch on a phone speaker (which rolls off below ~800 Hz, so the octave
# overtone is what the ear reads as the note), a quieter 1.5 so the dyad does
# not smear the line toward the fifth, a twin that beats at a fixed, slow
# 3.5 Hz (the 1.007 detune would pulse 4 Hz on D5 but 8 Hz on D6, a wobble on
# the high steps; the beat is the metal tell, not a tremolo) and softer (0.10
# against 0.40), and no second seat: the ticket hangs once.
CHIME = dict(
    takes=[(note, 0) for note in NOTES],
    tau=135,
    atk=(6.0, 7.0),
    dur=480,
    send=0.9,
    peak=-16.0,
    amps=(0.40, 0.10, 0.05, 0.12, 0.06),
    beat_hz=3.5,
    contact_gain=0.20,
    bell_ref_hz=740,
    fade_ms=10.0,
    crest_max=15.5,
)

# The level the whole line is calibrated to, by phone-band RMS like every
# other master (SOUND-DESIGN section 5), so no step jumps out of the line.
PHONE_RMS_TARGET = -30.0
PEAK_CEILING_DB = -12.0  # far under the -6 dBFS hard ceiling


def render_chime(step_i):
    """Step `step_i` (0-based) of the line, deterministic."""
    seed = SEED_BASE + step_i
    wet = render_brass("hang", CHIME, step_i, seed)
    m = measure(to_44k(wet), OUT_SR)
    wet = wet * 10 ** ((PHONE_RMS_TARGET - m["phone_rms"]) / 20)
    if db(float(np.max(np.abs(to_44k(wet))))) > PEAK_CEILING_DB:
        raise RuntimeError(f"step {step_i + 1} would peak above {PEAK_CEILING_DB} dBFS")
    return wet


# ---------------------------------------------------------------------------
# Checks, manifest, listening copies.
# ---------------------------------------------------------------------------


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_wav(path):
    a, sr = sf.read(str(path), dtype="float64", always_2d=True)
    return a.mean(axis=1), sr


def fundamental_hz(a, sr, lo=400.0, hi=1500.0):
    """The strongest spectral peak of the body (after the contact), in Hz,
    refined by parabolic interpolation."""
    seg = a[round(0.030 * sr) : round(0.230 * sr)]
    seg = seg * np.hanning(len(seg))
    size = 1 << 17
    spec = np.abs(np.fft.rfft(seg, size))
    freqs = np.fft.rfftfreq(size, 1 / sr)
    band = (freqs >= lo) & (freqs <= hi)
    i = int(np.argmax(np.where(band, spec, 0)))
    y0, y1, y2 = spec[i - 1], spec[i], spec[i + 1]
    d = 0.5 * (y0 - y2) / (y0 - 2 * y1 + y2)
    return float(freqs[i] + d * (freqs[1] - freqs[0]))


def floor_db(a, sr):
    """The level BETWEEN the musical peaks (500 to 3000 Hz, after the contact),
    relative to the body's strongest peak: the inter-partial noise floor that
    SOUND-DESIGN section 8 budgets. Lower is cleaner."""
    seg = a[round(0.040 * sr) : round(0.240 * sr)]
    seg = seg * np.hanning(len(seg))
    size = 1 << 16
    spec = np.abs(np.fft.rfft(seg, size))
    freqs = np.fft.rfftfreq(size, 1 / sr)
    band = (freqs >= 500) & (freqs <= 3000)
    s = spec[band]
    peak = float(np.max(spec[(freqs >= 300) & (freqs <= 3500)]))
    # the median of the band is "between the peaks" for a sparse tonal sound
    return db(float(np.median(s)) / peak)


def check_against_soft_hand():
    """Re-render the shipped Soft hand brass/place take 1 with this file's
    renderer and compare it with the committed master. Passing proves the
    chime is driven by the same synthesis the owner auditioned."""
    spec = dict(
        takes=[("E5", 0), ("D5", 0), ("E5", 7), ("E5", -8), ("B4", 0)],
        tau=120,
        atk=(5.0, 5.0),
        dur=300,
        send=0.9,
        peak=-16.5,
        settle=(0.030, 0.35),
    )
    # render_taps.py: lane order wood(4) slate(3) glass(2) brass(2), seed
    # 15000 + lane_index * 20 + take; brass/place is lane index 10.
    wet = render_brass("place", spec, 0, 15000 + 10 * 20 + 0)
    y = to_44k(wet)
    pk = np.max(np.abs(y))
    if pk > 0.98:
        y = y * 0.98 / pk
    ours = np.round(y * 32768).clip(-32768, 32767).astype(np.int32)
    shipped, _sr = sf.read(
        str(ROOT / "assets/sfx/room/materials/brass/place/1.wav"), dtype="int16"
    )
    shipped = shipped.astype(np.int32)
    n = min(len(ours), len(shipped))
    worst = int(np.max(np.abs(ours[:n] - shipped[:n])))
    return dict(samples=n, length_match=len(ours) == len(shipped), worst_lsb=worst)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--handoff", help="also write named listening copies here")
    ap.add_argument("--check", action="store_true", help="no writes: check the synthesis")
    args = ap.parse_args()

    if args.check:
        result = check_against_soft_hand()
        print(json.dumps(result))
        return 0 if result["length_match"] and result["worst_lsb"] <= 2 else 1

    records = {}
    for i in range(STEPS):
        wet = render_chime(i)
        path = CHIME_DIR / f"{i + 1}.wav"
        write44(path, wet)
        a, sr = read_wav(path)
        m = measure(a, sr)
        f0 = fundamental_hz(a, sr)
        want = HZ[NOTES[i]]
        records[f"assets/sfx/room/class_chime/{i + 1}.wav"] = dict(
            sha256=sha256(path),
            step=i + 1,
            note=NOTES[i],
            target_hz=want,
            measured_hz=round(f0, 2),
            cents_off=round(1200 * math.log2(f0 / want), 1),
            inter_partial_floor_db=round(floor_db(a, sr), 1),
            **m,
        )
    manifest = dict(
        study="class-chime",
        date="2026-10-11",
        status="rendered for the owner's phone; shipped, not yet heard",
        why=(
            "owner, after the Soft hand audition: \"it'd be best if you also vary the keys of "
            "the class chime rather than sticking to just one note\""
        ),
        rule=(
            "the Nth class kept today plays step N; the seventh starts over at step 1; a class "
            "set aside does not count; an undone and re-kept class takes the next free step"
        ),
        synthesis=(
            "tool/author_class_chime.py: the Soft hand's own brass renderer (render_taps.py "
            "render_brass) on the shared world (tool/author_room_sonic_world_study.py, the "
            "approved contact master, the 22/29/34 ms room fingerprint), driven by the "
            "D-major pentatonic field D5 E5 F#5 A5 B5 D6; no sample, no foreign synthesis"
        ),
        format="mono PCM 16-bit 44.1 kHz",
        phone_rms_target_dbfs=PHONE_RMS_TARGET,
        runtime_scale="doorway_cues.dart plays the chime at its own volume scale; the files are the level ladder",
        records=records,
    )
    AUDIT_DIR.mkdir(parents=True, exist_ok=True)
    (AUDIT_DIR / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    for key, rec in records.items():
        print(key, rec["note"], rec["measured_hz"], f"{rec['cents_off']:+.1f}c", rec["peak"], rec["phone_rms"], rec["crest"], rec["attack_ms"], rec["hf"], rec["inter_partial_floor_db"])

    if args.handoff:
        out = Path(args.handoff)
        out.mkdir(parents=True, exist_ok=True)
        line = []
        gap = round(0.62 * OUT_SR)
        total = np.zeros(gap * (STEPS - 1) + OUT_SR)
        for i in range(STEPS):
            src = CHIME_DIR / f"{i + 1}.wav"
            name = NOTES[i].replace("#", "sharp")
            (out / f"class-chime-{i + 1}-{name}.wav").write_bytes(src.read_bytes())
            a, _ = read_wav(src)
            total[i * gap : i * gap + len(a)] += a
        sf.write(str(out / "class-chime-line.wav"), total, OUT_SR, subtype="PCM_16")
    return 0


if __name__ == "__main__":
    sys.exit(main())
