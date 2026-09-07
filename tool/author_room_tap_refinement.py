"""Audition-only mastering of the approved Room gestures; never writes assets/."""
from __future__ import annotations

import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt

import author_room_sonic_world_study as world
from prepare_music_listening_room import read as decode

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'design/audits/2026-09-06/tap-refinement'
PREVIEW = ROOT / 'build/web/sound-review-20260906/taps'
SR = 48000
FAMILIES = ('current', 'refined', 'weightier')
RUNTIME = ROOT / 'assets/sfx/room'
SOURCE = OUT / 'current'
WALK = (0, 2, 1, 3, 1, 4, 2, 0, 3, 4, 1, 2, 4, 0)
GAINS = (1, .93, .93, .885)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preserve_sources():
    """Freeze the audition anchor before integration; never master a master twice."""
    manifest_path = OUT / 'source-manifest.json'
    if manifest_path.exists():
        records = json.loads(manifest_path.read_text(encoding='utf-8'))
    else:
        records = {}
        for path in sorted(RUNTIME.rglob('*.wav')):
            relative = path.relative_to(RUNTIME).as_posix()
            target = SOURCE / relative
            if target.exists() and digest(target) != digest(path):
                raise ValueError(f'Original source differs from audition anchor: {relative}')
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists():
                shutil.copyfile(path, target)
            records[relative] = digest(target)
        manifest_path.write_text(json.dumps(records, indent=2)+'\n', encoding='utf-8')
    for relative, expected in records.items():
        if digest(SOURCE / relative) != expected:
            raise ValueError(f'Archived source changed: {relative}')


def read(path):
    data, rate = sf.read(path, dtype='float64')
    if rate != SR or data.ndim != 1:
        raise ValueError(f'Expected mono 48k master: {path}')
    return data


def write(path, samples):
    # The approved +1.5 dB X master peaks at -5.325 dBFS. Keep that anchor's
    # natural level, with at least 5 dB of headroom throughout this comparison.
    if not np.isfinite(samples).all() or abs(samples).max() >= 10 ** (-5 / 20):
        raise ValueError(f'Invalid or insufficient headroom: {path}')
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, samples, SR, subtype='PCM_24')


def band(samples, low, high):
    return sosfiltfilt(butter(3, [low, high], btype='bandpass', fs=SR, output='sos'), samples)


def energy(samples):
    return float(np.sum(band(samples, 260, 8000) ** 2))


def shape(samples, lane, family):
    """Complementary bands retain source phase, gesture, tuning and duration.

    The treatment moves energy into the existing compact body, retaining the
    onset edge but shortening the higher-frequency grain after contact. It
    adds no notes, Foley, compression, noise floor, or reverberation.
    """
    t = np.arange(len(samples)) / SR
    low = sosfiltfilt(butter(2, 1450, fs=SR, output='sos'), samples)
    rounded = sosfiltfilt(butter(2, 4700, fs=SR, output='sos'), samples)
    middle, air = rounded - low, samples - rounded
    stronger = family == 'weightier'
    body = {'wood': .22, 'slate': .18, 'page': .04, 'glass': .12, 'brass': .16}[lane]
    if stronger:
        body *= 2.0
    body_window = (1 - np.exp(-t / .0014)) * np.exp(-t / .040)
    air_floor = .68 if not stronger else .52
    air_gain = air_floor + (1 - air_floor) * np.exp(-t / .0055)
    mid_gain = 1 + (.035 if not stronger else .055) * body_window
    # Let the page keep its moving fiber gesture; avoid manufacturing a thunk.
    if lane == 'page':
        air_gain = .88 + .12 * np.exp(-t / .014)
        mid_gain = 1 + (.02 if not stronger else .045) * np.sin(np.pi * t / (len(samples) / SR)) ** 2
    result = low * (1 + body * body_window) + middle * mid_gain + air * air_gain
    # Ring stays short, while the initial glass distinction is preserved.
    if lane == 'glass':
        result *= np.exp(-np.maximum(t - .024, 0) * (3 if not stronger else 6))
    # Keep the very first contact samples and the original file boundary.
    blend = np.clip(t / .0004, 0, 1)
    result = samples * (1 - blend) + result * blend
    end = min(len(result), round(.0015 * SR))
    result[-end:] *= np.cos(np.linspace(0, math.pi / 2, end)) ** 2
    return result


def refine(samples, lane, family):
    result = shape(samples, lane, family)
    return result * math.sqrt(energy(samples) / max(energy(result), 1e-20))


def diagnostics():
    """Recover the actual shared material contact/body/space, then shade them.

    Full source reconstructions must match the shipped PCM within one 24-bit
    quantization step. Component reels use the full cue's gain, never their
    own normalization, so the decomposition remains honest.
    """
    import author_room_material_shading_study as material
    material._enable_polish()
    contact = world._fit(world._read_mono(ROOT / 'design/audits/2026-08-20/room-sonic-world-v1/shared/contact-master.wav'), .014)
    layers = []
    errors = {}
    for lane, verb in [('slate','select'),('page','navigate'),('glass','select'),('brass','place')]:
        source = read(SOURCE / f'materials/{lane}/{verb}/1.wav')
        stem, send = material._lane_stems(lane,verb,world.PITCH_TOKENS[0],0,contact)
        body, _ = material._lane_stems(lane,verb,world.PITCH_TOKENS[0],0,np.zeros_like(contact))
        wet = world._park(world._room_bus(stem,send),6.0)
        calibrated = material._calibrate(wet,material.LANE_TARGET_DBFS[(lane,verb)])
        error = float(abs(source-calibrated).max())
        if error > 1.2e-7:
            raise ValueError(f'Source decomposition drift: {lane}: {error}')
        errors[lane] = error
        gain = float(np.dot(calibrated,wet)/np.dot(wet,wet))
        contact_wet = world._park(world._room_bus(stem-body,send),6.0)*gain
        body_wet = calibrated-contact_wet
        dry = world._park(stem.copy(),6.0)*gain
        layers.append((lane,calibrated,contact_wet,body_wet,dry))
    for family in FAMILIES:
        reels = {name:np.zeros(round(2.6*SR)) for name in ('contact-lineage','body-lineage','space-present','space-bypass')}
        for i,(lane,full,contact_wet,body_wet,dry) in enumerate(layers):
            normalizer = 1 if family == 'current' else math.sqrt(energy(full)/energy(shape(full,lane,family)))
            for name,component in [('contact-lineage',contact_wet),('body-lineage',body_wet),('space-present',full),('space-bypass',dry)]:
                output = component if family == 'current' else shape(component,lane,family)*normalizer
                place(reels[name],output,.25+i*.5)
        for name, reel in reels.items():
            write(OUT/family/'diagnostics'/f'{name}.wav',reel)
    return errors


def place(base, samples, at, gain=1):
    i = round(at * SR)
    count = min(len(samples), len(base) - i)
    if count > 0:
        base[i:i + count] += samples[:count] * gain


def metrics(samples):
    peak = float(np.max(np.abs(samples)))
    onset = np.flatnonzero(np.abs(samples) > 10 ** (-60 / 20))
    return {'duration_ms': len(samples) / SR * 1000, 'peak_dbfs': 20 * math.log10(max(peak, 1e-12)),
            'dc': float(np.mean(samples)), 'onset_ms_at_minus60dbfs': float(onset[0] / SR * 1000) if len(onset) else None,
            'phone_band_energy': energy(samples), 'last_sample': float(samples[-1])}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    preserve_sources()
    paths = sorted([*SOURCE.glob('ordinary/*/*.wav'), *SOURCE.glob('materials/*/*/*.wav')])
    before = {str(p.relative_to(ROOT)): digest(p) for p in RUNTIME.rglob('*.wav')}
    cues, rendered, records = {}, {}, {}
    for path in paths:
        relative = path.relative_to(SOURCE).as_posix()
        group = str(Path(relative).parent).replace('\\', '/')
        cues.setdefault(group, []).append(relative)
        lane = 'wood' if relative.startswith('ordinary/') else relative.split('/')[1]
        source = read(path)
        for family in FAMILIES:
            target = OUT / family / relative
            audio = source.copy() if family == 'current' else refine(source, lane, family)
            target.parent.mkdir(parents=True, exist_ok=True)
            if family != 'current':
                write(target, audio)
            final = read(target)
            rendered[(family, relative)] = final
            m = metrics(final)
            m['phone_energy_delta_db'] = 10 * math.log10(energy(final) / energy(source))
            if abs(m['phone_energy_delta_db']) > .01:
                raise ValueError(f'Unfair level difference: {target}')
            if m['onset_ms_at_minus60dbfs'] > 10 or abs(m['dc']) > .001:
                raise ValueError(f'Onset/DC gate: {target}')
            records[f'{family}/{relative}'] = {'sha256': digest(target), 'source': str(path.relative_to(ROOT)).replace('\\', '/'),
                'source_sha256': digest(path), 'treatment': family, 'source_graph': ['approved-contact-body-closure', 'source-material-shading', 'complementary-band-envelope-v1'], 'metrics': m}

    locked = OUT / 'locked'
    locked.mkdir(exist_ok=True)
    paired_records = {}
    for path in sorted(SOURCE.glob('paired_return/*/*/*.wav')):
        relative = path.relative_to(SOURCE).as_posix()
        _, token, role, take = relative.split('/')
        plain_relative = f'ordinary/{role}/{take}'
        old_plain = read(SOURCE / plain_relative)
        original = read(path)
        for family in FAMILIES:
            target = OUT / family / relative
            samples = original.copy()
            samples[:len(old_plain)] += rendered[(family, plain_relative)] - old_plain
            if family != 'current':
                write(target, samples)
            final = read(target)
            # Only the plain base changes; preserve the already approved note.
            old_meaning = original - old_plain
            new_meaning = final - rendered[(family, plain_relative)]
            error = float(abs(old_meaning - new_meaning).max())
            if error > 1.2e-7:
                raise ValueError(f'Paired meaning changed: {target}: {error}')
            paired_records[f'{family}/{relative}'] = {
                'sha256': digest(target), 'source': path.relative_to(ROOT).as_posix(),
                'source_sha256': digest(path), 'plain_source': plain_relative,
                'treatment': 'same plain-base substitution as auditioned paired-return reel',
                'meaning_max_abs_error': error, 'metrics': metrics(final),
            }
    (OUT/'paired-manifest.json').write_text(json.dumps(paired_records,indent=2)+'\n',encoding='utf-8')

    outcome = SOURCE / 'completion/answered-detent-natural.wav'
    shutil.copyfile(outcome, locked / outcome.name)
    answer = read(outcome)
    timeline = [(.3,'materials/page/navigate/1.wav'), (1.1,'ordinary/open/2.wav'),
        (1.8,'materials/glass/select/2.wav'), (2.5,'materials/slate/select/3.wav'),
        (3.2,'materials/brass/place/1.wav'), (4.1,'materials/page/open/3.wav'),
        (5.2,'ordinary/open/3.wav'), (6.25,'ordinary/select/2.wav'),
        (7.9,'materials/brass/select/3.wav'), (8.9,'materials/page/navigate/2.wav')]
    music = decode(ROOT / 'assets/music/lamp-left-on.m4a')[:round(10.5 * SR)]
    music_alt = decode(ROOT / 'assets/music/take_01.m4a')[:round(10.5 * SR)]
    reel_qc = {}
    for family in FAMILIES:
        flow = np.zeros(round(10.5 * SR))
        for at, rel in timeline:
            place(flow, rendered[(family,rel)], at)
        place(flow, answer, 6.325)
        write(OUT / family / 'flow.wav', flow)
        write(OUT / family / 'matched.wav', flow)  # cues already matched individually
        single = np.zeros(round(4.2 * SR))
        for i in range(5):
            place(single,rendered[(family,f'ordinary/open/{i+1}.wav')],.25+i*.75)
        write(OUT / family / 'single.wav',single)
        rapid = np.zeros(round(4.2 * SR))
        rapid_paths = ['ordinary/open','materials/glass/select','materials/slate/select','materials/brass/place','materials/page/navigate']
        last_take = {}
        for i in range(28):
            group = rapid_paths[i % len(rapid_paths)]
            take = WALK[i % len(WALK)] % len(cues[group])
            if last_take.get(group) == take:
                take = (take + 1) % len(cues[group])
            last_take[group] = take
            place(rapid, rendered[(family,cues[group][take])],.2+i*.125, GAINS[min(i,3)])
        write(OUT / family / 'rapid.wav',rapid)
        for title, bed in [('with-music',music),('with-umbrella',music_alt)]:
            envelope = np.ones(len(flow))
            for at, rel in timeline:
                hold = .46 if at == 6.25 else .14
                ndown, nhold, nup = round(.08*SR), round((hold-.08)*SR), round(.4*SR)
                curve = np.r_[np.linspace(1,.4,ndown),np.full(nhold,.4),np.linspace(.4,1,nup)]
                start = round(at*SR)
                stop = min(start+len(curve),len(envelope))
                envelope[start:stop] = np.minimum(envelope[start:stop],curve[:stop-start])
            mixed = flow + bed * envelope
            write(OUT / family / f'{title}.wav',mixed)
            reel_qc[f'{family}/{title}'] = metrics(mixed)
        # The existing rare melody remains its original meaning layer. Only
        # the changed ordinary base is substituted in this diagnostic reel.
        phrase = np.zeros(round(4.4*SR))
        for i in range(8):
            take = WALK[i] + 1
            rel = f'ordinary/open/{take}.wav'
            voice = rendered[(family,rel)]
            if i >= 4:
                token = ('d5','a5','e5','d5')[i-4]
                original_pair = read(SOURCE / f'paired_return/{token}/open/{take}.wav')
                original_plain = read(SOURCE / rel)
                voice = original_pair.copy()
                voice[:len(original_plain)] += rendered[(family,rel)] - original_plain
            place(phrase,voice,.3+i*.4)
        write(OUT / family / 'paired-return.wav',phrase)
    write(OUT / 'locked/silence.wav', np.zeros(SR))
    decomposition_errors = diagnostics()
    after = {str(p.relative_to(ROOT)): digest(p) for p in RUNTIME.rglob('*.wav')}
    if before != after:
        raise ValueError('Production masters changed')
    manifest = {'study':'room-tap-refinement-v1','status':'audition only; owner taste decision pending',
        'families':list(FAMILIES),'cues':cues,'records':records,'reel_qc':reel_qc,
        'source_runtime_unchanged':True,'music':'exact approved Lamp left on and umbrella take01; no gain change',
        'completion':'locked Answered Detent at75ms after one contact; no second generic click',
        'comparison':'Same cue durations and phone-band energy within0.01dB; perceived loudness still requires listening',
        'diagnostics':'Original shared material contact/body separated from deterministic source; space bypass removes only the inherited room bus; all use full-cue gain',
        'source_decomposition_max_errors':decomposition_errors,
        'sensory_verdict':'No audio perception available to root; owner audition required',
        'recipe_sha256':digest(Path(__file__))}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    for path in sorted(OUT.rglob('*.wav')):
        destination=PREVIEW/path.relative_to(OUT)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,destination)
    shutil.copyfile(OUT/'manifest.json',PREVIEW/'manifest.json')
    html=ROOT/'tool/preview/tap-review.html'
    if html.exists():
        shutil.copyfile(html,PREVIEW/'index.html')
    print(json.dumps({'cues':len(records),'root':str(OUT),'preview':str(PREVIEW),
        'production_unchanged':True,'worst_peak_dbfs':max(x['metrics']['peak_dbfs'] for x in records.values())}))


if __name__ == '__main__':
    main()
