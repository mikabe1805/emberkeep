"""Soft hand tap palette + softened event voices + celebration phrase.

Everything is grown from the Room's shared world (copied read-only into ssrc/):
the contact master (softened), the 1.0 / 1.498 / 2.17 modal bank, the D-major
pentatonic pitch field and the 22/29/34 ms room fingerprint. Nothing in the app
worktree is modified. Renders at 48 kHz, written as mono 44.1 kHz 16-bit wav.
"""
import sys, json, math
sys.dont_write_bytecode = True
HERE = __import__('pathlib').Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / 'ssrc'))
sys.path.insert(0, str(HERE))
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt
import author_room_sonic_world_study as world
from measure import measure, measure_file, read_mono, db

W = Path('C:/Users/mikus/Downloads/experimentProject/app/.worktrees/class-day-journey')
SFX = W / 'assets/sfx'
OUT = Path('C:/tmp/cdj/sound-v3')
SR = world.SAMPLE_RATE  # 48000
OUT_SR = 44100


def hz(name):
    return {'D4': 293.665, 'E4': 329.628, 'F#4': 369.994, 'A4': 440.0, 'B4': 493.883,
            'D5': 587.330, 'E5': 659.255, 'F#5': 739.989, 'A5': 880.0, 'B5': 987.767,
            'D6': 1174.659, 'E6': 1318.510, 'F#6': 1479.978, 'A6': 1760.0, 'B6': 1975.533}[name]


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
        a, sr = sf.read(str(HERE / 'ssrc/contact-master.wav'), dtype='float64')
        _CONTACT = a
    return _CONTACT


def soft_contact(n, atk_ms, rng, band=(300, 2500), tau_ms=9.0, master_mix=0.55):
    """The same hand, softened: the approved contact master smoothed with a
    raised-cosine kernel, plus a band-limited noise grain with its own soft
    attack. 300 Hz to 2.5 kHz, rolled off above ~3 kHz."""
    t = np.arange(n) / SR
    # (a) smoothed contact master
    k = max(3, round(atk_ms / 1000 * SR))
    kern = np.hanning(k * 2 + 1)
    kern /= kern.sum()
    m = np.convolve(contact_master(), kern, mode='full')
    m = np.concatenate([np.zeros(round(rng.uniform(0.0, 0.0006) * SR)), m])
    m = world._bandpass(m, band[0], band[1], order=2)
    m = m / (np.max(np.abs(m)) or 1)
    mm = np.zeros(n)
    mm[:min(n, len(m))] = m[:n]
    mm *= np.exp(-np.maximum(t - 0.004, 0) / 0.006)
    # (b) noise grain
    g = rng.standard_normal(n)
    g = world._bandpass(g, band[0], band[1], order=2)
    g /= np.max(np.abs(g)) or 1
    g *= attack_env(n, atk_ms) * np.exp(-t / (tau_ms / 1000))
    c = master_mix * mm + (1 - master_mix) * g
    c = world._filter(c, lowpass_hz=3000, order=2)
    return c / (np.max(np.abs(c)) or 1)


def modal(f0, n, atk_ms, tau_ms, *, partials, glide_c=0.0, glide_ms=18.0, thud=0.0,
          thud_tau=0.9, rng=None, detune=(0.0, -4.0, 7.0)):
    """Short damped modal body on the shared 1 / 1.498 / 2.17 bank.
    partials = ((ratio, amp, decay_scale), ...)."""
    t = np.arange(n) / SR
    # slight upward lift into the note
    cents_off = -glide_c * np.exp(-t / (glide_ms / 1000))
    f = f0 * 2 ** (cents_off / 1200)
    ph = np.cumsum(2 * math.pi * f / SR)
    env_a = attack_env(n, atk_ms)
    body = np.zeros(n)
    for i, (ratio, amp, dscale) in enumerate(partials):
        d = detune[i] if i < len(detune) else 0.0
        tuned = ratio * 2 ** (d / 1200)
        body += amp * np.sin(ph * tuned + rng.uniform(0, 2 * math.pi)) * np.exp(-t / (tau_ms / 1000 * dscale))
    if thud:
        body += thud * np.sin(ph * 0.5 + rng.uniform(0, 2 * math.pi)) * np.exp(-t / (tau_ms / 1000 * thud_tau))
    return body * env_a


def breath(n, rng, rise_ms=17.0, total_ms=62.0, band=(650, 2500)):
    """A soft paper breath: band-limited noise, slow rise, no sharp edge."""
    g = world._bandpass(rng.standard_normal(n), band[0], band[1], order=2)
    g /= np.max(np.abs(g)) or 1
    env = np.zeros(n)
    tn = min(n, round(total_ms / 1000 * SR))
    x = np.arange(tn) / tn
    env[:tn] = np.sin(math.pi * x ** 0.8) ** 2
    return g * env


def softknee(a, thr=0.6, slope=0.45):
    """Gently rounds the single highest peaks so the crest stays low."""
    p = np.max(np.abs(a)) or 1.0
    T = thr * p
    mag = np.abs(a)
    return np.where(mag > T, np.sign(a) * (T + (mag - T) * slope), a)


def finish(dry, send, dur_ms, target_peak_db, fade_ms=8.0, lp=3400, knee=(0.6, 0.45), crest_max=13.6, hf_max=-20.5):
    """Room fingerprint (subliminal), park the tail, level to the peak target.
    If a take lands above the crest or HF-share ceilings, the peak knee gets a
    little stronger and the lowpass a little lower until it passes."""
    n = round(dur_ms / 1000 * SR)
    d0 = np.zeros(n)
    d0[:min(n, len(dry))] = dry[:n]
    knees = [knee, (0.5, 0.38), (0.42, 0.32), (0.35, 0.26), (0.3, 0.2), (0.25, 0.15), (0.2, 0.1), (0.15, 0.06)]
    wet = None
    if lp < 3000:
        knees = [(1.0, 1.0)] + knees  # tonal glass: try with no knee first
    for step, kn in enumerate(knees):
        d = softknee(d0, *kn)
        d = world._filter(d, highpass_hz=180, lowpass_hz=lp * (0.93 ** step), order=2)
        wet = world._room_bus(d, send)
        wet = world._park(wet, fade_ms)
        wet = wet / np.max(np.abs(to_44k(wet))) * 10 ** (target_peak_db / 20)
        m = measure(to_44k(wet), OUT_SR)
        if m['crest'] <= crest_max and m['hf'] <= hf_max:
            break
    return wet


def to_44k(a):
    return resample_poly(a, 147, 160)


def write44(path, a, peak_db=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    y = to_44k(a)
    if peak_db is not None:
        y = y / np.max(np.abs(y)) * 10 ** (peak_db / 20)
    pk = np.max(np.abs(y))
    if pk > 0.98:
        y = y * 0.98 / pk
    sf.write(str(path), y, OUT_SR, subtype='PCM_16')
    return y


# --------------------------------------------------------------------------
# lane recipes
# --------------------------------------------------------------------------
# note: each lane lists 5 takes as (note name, cents offset). Pitch stays inside
# the D-major pentatonic neighbourhood of the verb's own note.

WOOD = {
    'open': dict(note_label='A', takes=[('A5', 0), ('A5', 7), ('B5', 0), ('A5', -9), ('A5', 3)],
                 tau=46, atk=(4.6, 5.0), dur=150, send=0.8, peak=-16.5, glide=26, thud=0.10,
                 contact=0.50, ctau=10.0, partials=((1.0, .48, 1.0), (1.498, .225, .5), (2.17, .085, .3))),
    'select': dict(note_label='F#', takes=[('F#5', 0), ('F#5', 6), ('E5', 0), ('F#5', -8), ('A5', 0)],
                   tau=38, atk=(4.4, 5.0), dur=120, send=0.8, peak=-17.5, glide=12, thud=0.05,
                   contact=0.44, ctau=9.0, partials=((1.0, .48, 1.0), (1.498, .16, .45), (2.17, .05, .28))),
    'navigate': dict(note_label='D', takes=[('D5', 0), ('D5', 7), ('E5', 0), ('D5', -8), ('B4', 0)],
                     tau=52, atk=(4.6, 5.0), dur=200, send=0.9, peak=-16.0, glide=14, thud=0.14,
                     contact=0.50, ctau=10.0, breath=0.30, tock_at=0.026,
                     partials=((1.0, .48, 1.0), (1.498, .225, .5), (2.17, .085, .3))),
    'place': dict(note_label='E', takes=[('E5', 0), ('B4', 0), ('E5', 8), ('E5', -7), ('B4', 5)],
                  tau=66, atk=(4.7, 5.0), dur=250, send=1.0, peak=-15.5, glide=0, thud=0.20,
                  contact=0.55, ctau=11.0, settle=(0.036, 0.45),
                  partials=((1.0, .48, 1.0), (1.498, .225, .5), (2.17, .085, .3))),
}

SLATE = {
    'navigate': dict(note_label='D', takes=[('D5', 0), ('D5', 7), ('E5', 0), ('D5', -8), ('B4', 0)],
                     tau=36, atk=(4.5, 5.0), dur=150, send=0.9, peak=-15.0, glide=0, thud=0.20,
                     contact=0.52, ctau=7.0, band=(300, 1900), double=(0.005, 0.5),
                     partials=((1.0, .48, 1.0), (1.498, .20, .6), (2.17, .06, .4))),
    'select': dict(note_label='E', takes=[('E5', 0), ('E5', 6), ('D5', 0), ('E5', -8), ('F#5', 0)],
                   tau=32, atk=(4.4, 5.0), dur=110, send=0.85, peak=-16.5, glide=0, thud=0.14,
                   contact=0.46, ctau=6.0, band=(300, 1900), double=(0.004, 0.4),
                   partials=((1.0, .48, 1.0), (1.498, .16, .6), (2.17, .05, .4))),
    'place': dict(note_label='B', takes=[('B4', 0), ('E5', 0), ('B4', 7), ('B4', -8), ('E5', 5)],
                  tau=46, atk=(4.6, 5.0), dur=170, send=1.0, peak=-14.5, glide=0, thud=0.28,
                  contact=0.58, ctau=8.0, band=(300, 1900), double=(0.005, 0.5), settle=(0.030, 0.30),
                  partials=((1.0, .48, 1.0), (1.498, .22, .6), (2.17, .07, .4))),
}

GLASS = {
    'select': dict(note_label='D', takes=[('D6', 0), ('D6', 8), ('B5', 0), ('D6', -7), ('E6', 0)],
                   tau=26, atk=(4.4, 5.0), dur=100, send=0.74, peak=-17.5,
                   partials=((1.0, .48, 1.0), (2.32, .10, .45))),
    'place': dict(note_label='A', takes=[('A5', 0), ('A5', 6), ('B5', 0), ('A5', -8), ('F#5', 0)],
                  tau=38, atk=(4.5, 5.0), dur=150, send=0.8, peak=-16.5,
                  partials=((1.0, .48, 1.0), (2.32, .12, .45)), seat=0.26),
}

BRASS = {
    'select': dict(note_label='A', takes=[('A5', 0), ('A5', 7), ('B5', 0), ('A5', -8), ('F#5', 0)],
                   tau=85, atk=(5.0, 5.0), dur=220, send=0.9, peak=-17.5),
    'place': dict(note_label='E', takes=[('E5', 0), ('D5', 0), ('E5', 7), ('E5', -8), ('B4', 0)],
                  tau=120, atk=(5.0, 5.0), dur=300, send=0.9, peak=-16.5, settle=(0.030, 0.35)),
}


def jit(rng, base, frac):
    return base * (1 + rng.uniform(-frac, frac))


def render_wood_like(lane, verb, spec, take_i, seed):
    rng = np.random.default_rng(seed)
    note, c = spec['takes'][take_i]
    f0 = cents(hz(note), c)
    n = round((spec['dur'] + 40) / 1000 * SR)
    atk = rng.uniform(*spec['atk'])
    tau = jit(rng, spec['tau'], 0.12)
    tock_at = spec.get('tock_at', 0.0)
    partials = tuple((r, a * rng.uniform(0.9, 1.1), d) for r, a, d in spec['partials'])
    nb = n - round(tock_at * SR)
    body = modal(f0, nb, atk, tau, partials=partials, glide_c=spec['glide'] * rng.uniform(0.8, 1.2),
                 thud=spec['thud'] * rng.uniform(0.85, 1.15), rng=rng)
    band = spec.get('band', (300, 2500))
    ct = soft_contact(nb, atk, rng, band=(band[0] * rng.uniform(0.95, 1.1), band[1] * rng.uniform(0.92, 1.06)),
                      tau_ms=spec['ctau'] * rng.uniform(0.85, 1.15))
    voice = body / (np.max(np.abs(body)) or 1) + spec['contact'] * rng.uniform(0.88, 1.12) * ct
    if spec.get('double'):
        dly, gain = spec['double']
        ds = round(dly * SR)
        ct2 = np.zeros(nb)
        ct2[ds:] = ct[:nb - ds]
        voice = voice + spec['contact'] * gain * ct2
    if spec.get('settle'):
        dly, gain = spec['settle']
        dly *= rng.uniform(0.9, 1.15)
        ds = round(dly * SR)
        sf0 = f0 * 0.75 if f0 > 600 else f0
        sb = modal(sf0, nb - ds, atk, tau * 0.7, partials=partials[:2], thud=0.1, rng=rng)
        sc = soft_contact(nb - ds, atk, rng, tau_ms=6.0)
        sett = np.zeros(nb)
        sett[ds:] = (sb / (np.max(np.abs(sb)) or 1) + 0.25 * sc) * gain
        voice = voice + sett
    out = np.zeros(n)
    s0 = round(tock_at * SR)
    out[s0:] = voice[:n - s0]
    if spec.get('breath'):
        out[:] += spec['breath'] * rng.uniform(0.85, 1.15) * breath(n, rng)
    return finish(out, spec['send'], spec['dur'], spec['peak'] + rng.uniform(-0.4, 0.4))


def render_glass(verb, spec, take_i, seed):
    rng = np.random.default_rng(seed)
    note, c = spec['takes'][take_i]
    f0 = cents(hz(note), c)
    n = round((spec['dur'] + 40) / 1000 * SR)
    atk = rng.uniform(*spec['atk'])
    tau = jit(rng, spec['tau'], 0.12)
    partials = tuple((r * rng.uniform(0.995, 1.005), a * rng.uniform(0.9, 1.1), d) for r, a, d in spec['partials'])
    body = modal(f0, n, atk, tau, partials=partials, glide_c=-4, rng=rng, detune=(0.0, 3.0))
    body /= (np.max(np.abs(body)) or 1)
    ct = soft_contact(n, atk, rng, band=(700, 2600), tau_ms=5.0, master_mix=0.35)
    voice = body + 0.20 * rng.uniform(0.85, 1.15) * ct
    if spec.get('seat'):
        sb = modal(f0 / 2, n, atk, tau * 1.1, partials=((1.0, .5, 1.0), (1.498, .12, .6)), rng=rng)
        voice = voice + spec['seat'] * sb / (np.max(np.abs(sb)) or 1)
    return finish(voice, spec['send'], spec['dur'], spec['peak'] + rng.uniform(-0.4, 0.4), fade_ms=7.0, lp=2700)


def render_brass(verb, spec, take_i, seed):
    rng = np.random.default_rng(seed)
    note, c = spec['takes'][take_i]
    f0 = cents(hz(note), c)
    n = round((spec['dur'] + 40) / 1000 * SR)
    t = np.arange(n) / SR
    atk = rng.uniform(*spec['atk'])
    tau = jit(rng, spec['tau'], 0.10) / 1000
    ph0 = np.array([math.pi / 2, math.pi / 2, 1.0, 2.0, 0.5, 0.0])
    # felt-muted dyad with a slow beat (root x 1.007), 1.5 and 2.0 partials,
    # and a small soft bell partial high above (gold-only primary)
    body = (0.40 * np.sin(2 * math.pi * f0 * t + ph0[0]) +
            0.17 * np.sin(2 * math.pi * f0 * 1.007 * t + ph0[1]) +
            0.14 * np.sin(2 * math.pi * f0 * 1.5 * t + ph0[2]) * np.exp(-t / (tau * 0.7)) +
            0.08 * np.sin(2 * math.pi * f0 * 2.0 * t + ph0[3]) * np.exp(-t / (tau * 0.55)) +
            0.05 * np.sin(2 * math.pi * f0 * 2.756 * t + ph0[4]) * np.exp(-t / (tau * 0.4)))
    body *= np.exp(-t / tau) * attack_env(n, atk)
    ct = soft_contact(n, atk, rng, band=(300, 1800), tau_ms=7.0)
    voice = body / (np.max(np.abs(body)) or 1) + 0.22 * rng.uniform(0.85, 1.15) * ct
    if spec.get('settle'):
        dly, gain = spec['settle']
        ds = round(dly * rng.uniform(0.9, 1.15) * SR)
        sb = body[:n - ds] / (np.max(np.abs(body)) or 1)
        sett = np.zeros(n)
        sett[ds:] = sb * gain * 0.6
        voice = voice + sett
    return finish(voice, spec['send'], spec['dur'], spec['peak'] + rng.uniform(-0.4, 0.4), fade_ms=9.0)


def render_page(verb, take_i, seed):
    """Page: keep the shipped parchment character, re-level and round it."""
    src = SFX / f'room/materials/page/{verb}'
    rng = np.random.default_rng(seed)
    base_i = take_i % 3
    a, sr = read_mono(src / f'{base_i + 1}.wav')
    if take_i >= 3:
        # two extra takes: the same page, a touch faster or slower
        ratio = 1.035 if take_i == 3 else 0.965
        a = resample_poly(a, 1000, round(1000 * ratio))
    cutoff = rng.uniform(2300, 2700)
    a0 = a
    for step in range(6):
        a = world._filter(a0, lowpass_hz=cutoff * (0.92 ** step), order=3)
        if measure(a, sr)['hf'] <= -19.0:
            break
    # round the micro-crackles: 2 ms raised-cosine onset
    na = round(0.002 * sr)
    a[:na] *= rc_rise(na)
    # tame the landing peak a little (soft knee), then level
    pk = np.max(np.abs(a))
    thr = 0.55 * pk
    over = np.abs(a) > thr
    a = np.where(over, np.sign(a) * (thr + (np.abs(a) - thr) * 0.45), a)
    a = world._park(a, 6.0)
    return a, -16.5 + rng.uniform(-0.4, 0.4)


# --------------------------------------------------------------------------
# events and phrase
# --------------------------------------------------------------------------
EVENT_PEAK = -11.0


def soft_event(name, path, atk_ms=5.5, lp=4400):
    a, sr = read_mono(path)
    assert sr == SR
    a = world._filter(a, lowpass_hz=lp, order=2)
    n = round(atk_ms / 1000 * sr)
    a[:n] *= rc_rise(n)
    a = world._park(a, 5.0)
    return a / np.max(np.abs(a)) * 10 ** (EVENT_PEAK / 20)


def main():
    result = {'taps': {}, 'events': {}, 'celebration': {}}
    lanes = []
    for verb, spec in WOOD.items():
        lanes.append(('wood', verb, spec, 'room'))
    for verb, spec in SLATE.items():
        lanes.append(('slate', verb, spec, 'room'))
    for verb, spec in GLASS.items():
        lanes.append(('glass', verb, spec, 'glass'))
    for verb, spec in BRASS.items():
        lanes.append(('brass', verb, spec, 'brass'))
    seed_base = 15000
    for li, (lane, verb, spec, kind) in enumerate(lanes):
        for i in range(5):
            seed = seed_base + li * 20 + i
            if kind == 'room':
                a = render_wood_like(lane, verb, spec, i, seed)
            elif kind == 'glass':
                a = render_glass(verb, spec, i, seed)
            else:
                a = render_brass(verb, spec, i, seed)
            write44(OUT / f'taps/{lane}/{verb}/{i + 1}.wav', a)
    for verb in ('open', 'navigate'):
        for i in range(5):
            a, tgt = render_page(verb, i, seed_base + 900 + (0 if verb == 'open' else 10) + i)
            write44(OUT / f'taps/page/{verb}/{i + 1}.wav', a, tgt)

    # events
    ev = {'streak': SFX / 'streak.wav', 'crit': SFX / 'crit.wav', 'loot': SFX / 'loot.wav',
          'levelup': SFX / 'levelup.wav', 'boing': SFX / 'boing.wav'}
    for k in range(6):
        ev[f'stat_{k}'] = SFX / f'stat_{k}.wav'
    soft_ev = {}
    for name, p in ev.items():
        a = soft_event(name, p)
        soft_ev[name] = a
        write44(OUT / f'events/{name}.wav', a, EVENT_PEAK)

    # celebration: stacked (today) vs one phrase (new)
    comp, _ = read_mono(SFX / 'room/completion/completion-composite.wav')
    stk = {k: read_mono(SFX / f'{k}.wav')[0] for k in ('streak', 'crit', 'loot')}
    L = round(1.0 * SR)
    stacked = np.zeros(L)
    for i, a in enumerate([comp, stk['streak'], stk['crit'], stk['loot']]):
        s = round(i * 0.085 * SR)
        stacked[s:s + len(a)] += a[:L - s]
    eighth = 60 / 72 / 2
    phrase = np.zeros(round(1.9 * SR))
    drop = 10 ** (-5 / 20)
    voices = [(comp, 0.0, 1.0), (soft_ev['stat_4'], 1 * eighth, drop), (soft_ev['streak'], 2 * eighth, drop)]
    for a, t, g in voices:
        s = round(t * SR)
        phrase[s:s + len(a)] += a[:len(phrase) - s] * g
    phrase = world._park(phrase, 20.0)
    stacked = world._park(stacked, 20.0)
    write44(OUT / 'celebration/stacked.wav', stacked)
    write44(OUT / 'celebration/phrase.wav', phrase)
    print('rendered')


if __name__ == '__main__':
    main()
