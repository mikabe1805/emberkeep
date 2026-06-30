#!/usr/bin/env python3
"""Synthesize soft, warm UI sounds for Emberkeep (candlelit-glass aesthetic).

Design goals (owner feedback: the old set felt harsh; wanted softer + higher
quality): gentle marimba/music-box/bell timbres, smooth click-free envelopes
(no hard onsets/cutoffs — the main cause of "cheap synth" harshness), pleasant
pentatonic intervals, light reverb for air. Pure stdlib (math, wave, struct).
"""
import math
import os
import struct
import wave

SR = 44100

# equal-temperament note frequencies
NOTE = {
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99,
    'A5': 880.00, 'B5': 987.77, 'C6': 1046.50, 'D6': 1174.66, 'E6': 1318.51,
    'F6': 1396.91, 'G6': 1567.98, 'A6': 1760.00, 'C7': 2093.00,
    'G4': 392.00, 'C4': 261.63, 'E4': 329.63, 'A4': 440.00,
}


def _env(n, attack, release, decay_tau):
    """Smooth amplitude envelope across n samples: short raised-cosine attack,
    exponential body decay, raised-cosine release. No discontinuities → no clicks."""
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    out = [0.0] * n
    for i in range(n):
        if i < a:
            amp = 0.5 - 0.5 * math.cos(math.pi * i / a)        # ease-in
        else:
            amp = math.exp(-(i - a) / (SR * decay_tau))         # exp decay
        if i > n - r:                                           # ease-out tail
            amp *= 0.5 - 0.5 * math.cos(math.pi * (n - i) / r)
        out[i] = amp
    return out


def note(freq, dur, kind='marimba', detune=0.0, gain=1.0):
    """One struck note. `kind` shapes the harmonic recipe + decay."""
    n = int(SR * dur)
    if kind == 'marimba':         # warm, woody, fast-ish decay
        partials = [(1.0, 1.0), (2.01, 0.28), (3.0, 0.12), (4.2, 0.05)]
        tau = dur * 0.32
        attack, release = 0.004, min(0.08, dur * 0.4)
    elif kind == 'music_box':     # bright, glassy, longer ring
        partials = [(1.0, 1.0), (2.0, 0.5), (3.0, 0.18), (5.4, 0.08)]
        tau = dur * 0.45
        attack, release = 0.003, min(0.10, dur * 0.4)
    elif kind == 'bell':          # inharmonic shimmer
        partials = [(1.0, 1.0), (2.76, 0.34), (5.4, 0.16), (8.1, 0.06)]
        tau = dur * 0.5
        attack, release = 0.003, min(0.12, dur * 0.4)
    elif kind == 'soft':          # nearly pure sine pip (ticks)
        partials = [(1.0, 1.0), (2.0, 0.06)]
        tau = dur * 0.3
        attack, release = 0.006, min(0.05, dur * 0.45)
    else:
        partials = [(1.0, 1.0)]
        tau = dur * 0.3
        attack, release = 0.005, dur * 0.4

    env = _env(n, attack, release, tau)
    buf = [0.0] * n
    for mult, pamp in partials:
        f = freq * mult * (1.0 + detune)
        w = 2 * math.pi * f / SR
        # higher partials decay faster (natural, less metallic-sustain)
        hd = 1.0 / (1.0 + (mult - 1.0) * 0.6)
        for i in range(n):
            e = env[i] * (hd + (1 - hd) * math.exp(-i / (SR * tau)))
            buf[i] += math.sin(w * i) * pamp * e
    return [s * gain for s in buf]


def mix(total_dur):
    return [0.0] * int(SR * total_dur)


def place(buf, samples, at):
    o = int(SR * at)
    for i, s in enumerate(samples):
        j = o + i
        if 0 <= j < len(buf):
            buf[j] += s


def reverb(buf, taps=((0.019, 0.22), (0.031, 0.16), (0.045, 0.11),
                      (0.063, 0.075), (0.088, 0.05), (0.117, 0.03)),
           tail=0.4):
    """Light early-reflection reverb (no feedback → stable). Adds air."""
    n = len(buf)
    out = list(buf) + [0.0] * int(SR * tail)
    for d_s, g in taps:
        d = int(SR * d_s)
        for i in range(n):
            out[i + d] += buf[i] * g
    return out


def normalize(buf, peak=0.7):
    m = max((abs(s) for s in buf), default=1.0) or 1.0
    k = peak / m
    return [s * k for s in buf]


def write_wav(path, buf):
    buf = normalize(buf)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in buf:
            v = int(max(-1.0, min(1.0, s)) * 32767)
            frames += struct.pack('<h', v)
        w.writeframes(bytes(frames))
    print(f'  {os.path.basename(path):14s} {len(buf)/SR:.2f}s')


def build():
    out = {}

    # tick — a whisper-soft rounded pip (every tap)
    out['tick'] = note(NOTE['A5'], 0.07, 'soft', gain=0.7)

    # stat_0..5 — gentle marimba blips, ascending pentatonic (pitch per stat)
    penta = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6']
    for i, nm in enumerate(penta):
        out[f'stat_{i}'] = note(NOTE[nm], 0.26, 'marimba', gain=0.85)

    # complete — a warm rising two-note (a perfect fifth), music-box
    b = mix(0.5)
    place(b, note(NOTE['C5'], 0.34, 'music_box'), 0.0)
    place(b, note(NOTE['G5'], 0.40, 'music_box', gain=0.95), 0.10)
    out['complete'] = reverb(b, tail=0.3)

    # streak — a cozy ascending major triad
    b = mix(0.6)
    for k, nm in enumerate(['C5', 'E5', 'G5']):
        place(b, note(NOTE[nm], 0.42, 'music_box', gain=0.9), 0.08 * k)
    out['streak'] = reverb(b, tail=0.35)

    # crit — a bright sparkle run (excited but still soft), light detune shimmer
    b = mix(0.55)
    for k, nm in enumerate(['G5', 'C6', 'E6', 'G6']):
        place(b, note(NOTE[nm], 0.30, 'bell', detune=0.004, gain=0.7), 0.055 * k)
    out['crit'] = reverb(b, tail=0.4)

    # loot — a soft struck bell chord with shimmer tail (a little treasure)
    b = mix(0.7)
    for nm in ['C5', 'E5', 'G5']:
        place(b, note(NOTE[nm], 0.6, 'bell', gain=0.6), 0.0)
    place(b, note(NOTE['C6'], 0.5, 'music_box', gain=0.4), 0.14)
    out['loot'] = reverb(b, tail=0.5)

    # levelup — a warm ascending arpeggio resolving up an octave, soft pad below
    b = mix(1.0)
    for k, nm in enumerate(['C5', 'E5', 'G5', 'C6', 'E6']):
        place(b, note(NOTE[nm], 0.5, 'music_box', gain=0.8), 0.10 * k)
    # a gentle sustaining pad (C major) underneath for body
    for nm in ['C4', 'E4', 'G4']:
        place(b, note(NOTE[nm], 0.9, 'marimba', gain=0.28), 0.0)
    out['levelup'] = reverb(b, tail=0.5)

    # boing — a soft downward two-note (undo / remove), rounded not comical
    b = mix(0.4)
    place(b, note(NOTE['E5'], 0.22, 'marimba', gain=0.8), 0.0)
    place(b, note(NOTE['C5'], 0.26, 'marimba', gain=0.7), 0.09)
    out['boing'] = reverb(b, tail=0.2)

    return out


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    dest = os.environ.get('SFX_DEST') or os.path.join(here, 'out')
    os.makedirs(dest, exist_ok=True)
    print(f'writing to {dest}')
    for name, buf in build().items():
        write_wav(os.path.join(dest, f'{name}.wav'), buf)
    print('done.')


if __name__ == '__main__':
    main()
