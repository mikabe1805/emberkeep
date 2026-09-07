"""Local A/B comparison; both pieces are now approved production music."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

import numpy as np

from prepare_music_listening_room import ROOT, AUDIT, SR, read, encode, world

DEST = ROOT / 'build/web/umbrella-review-20260906'
STUDY = AUDIT / 'umbrella-new-theme'


def main():
    manifest = json.loads((STUDY / 'manifest.json').read_text(encoding='utf-8'))
    for name, evidence in manifest['artifacts'].items():
        actual = hashlib.sha256((STUDY / name).read_bytes()).hexdigest()
        if actual != evidence['sha256']:
            raise ValueError(f'Candidate changed after its render verification: {name}')
    DEST.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'tool/preview/umbrella-review.html', DEST / 'index.html')
    tracks = {
        'umbrella': ROOT / 'assets/music/take_01.m4a',
        'new': STUDY / 'lamp-left-on.m4a',
    }
    events = (
        (1.0, 'materials/page/navigate/1.wav'),
        (3.2, 'materials/glass/select/1.wav'),
        (5.0, 'materials/brass/place/1.wav'),
        (8.0, 'completion/completion-composite.wav'),
        (11.0, 'materials/page/navigate/2.wav'),
        (12.0, 'materials/glass/select/2.wav'),
    )
    cues = [(at, read(ROOT / 'assets/sfx/room' / relative)) for at, relative in events]
    peaks = {}
    for name, source in tracks.items():
        shutil.copyfile(source, DEST / f'{name}.m4a')
        samples = read(source)
        # Natural runtime levels. Only the app's existing duck envelope is added.
        bed = samples[round(14 * SR):round(30 * SR)].copy()
        envelope = np.ones(len(bed))
        for at, _ in cues:
            start = round(at * SR)
            hold = .46 if at == 8 else .14
            down, held, up = round(.08 * SR), round((hold - .08) * SR), round(.4 * SR)
            curve = np.concatenate([np.linspace(1, .4, down), np.full(held, .4), np.linspace(.4, 1, up)])
            end = min(len(bed), start + len(curve))
            envelope[start:end] = np.minimum(envelope[start:end], curve[:end-start])
        bed *= envelope
        for at, cue in cues:
            world._place(bed, cue, at, 1.0)
        peaks[name] = float(np.max(np.abs(bed)))
        if peaks[name] >= 1:
            raise ValueError(f'Clipping in {name} flow')
        encode(bed, DEST / f'{name}-flow.mp3')
    shutil.copyfile(STUDY / 'lamp-left-on-hook-18s.m4a', DEST / 'new-hook.m4a')
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(tracks['umbrella']),
                    '-t', '18', '-af', 'afade=t=out:st=17.88:d=0.12',
                    '-c:a', 'aac', '-b:a', '96k', str(DEST / 'umbrella-hook.m4a')], check=True)
    (AUDIT / 'umbrella-listening-room.json').write_text(json.dumps({
        'url': 'http://127.0.0.1:8393/umbrella-review-20260906/',
        'candidate_sha256': hashlib.sha256(tracks['new'].read_bytes()).hexdigest(),
        'anchor_sha256': hashlib.sha256(tracks['umbrella'].read_bytes()).hexdigest(),
        'sfx_event_times': [at for at, _ in events],
        'flow_peaks': peaks,
        'runtime_music': 'umbrella-brush and Lamp left on alternate; Focus remains separate',
        'listening_verdict': 'owner approved: it sounds pretty good! you can add it to the app',
    }, indent=2) + '\n', encoding='utf-8')
    # Keep an old bookmarked listening-room URL useful after the web rebuild,
    # without presenting rejected studies as active choices again.
    old = ROOT / 'build/web/sound-review-20260906'
    old.mkdir(exist_ok=True)
    (old / 'index.html').write_text('''<!doctype html><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="refresh" content="0;url=/umbrella-review-20260906/">
<title>Room of Days · Updated listening room</title>
<p>The earlier music studies have been set aside.</p>
<p><a href="/umbrella-review-20260906/">Open the umbrella comparison</a></p>''', encoding='utf-8')
    print(DEST)


if __name__ == '__main__':
    main()
