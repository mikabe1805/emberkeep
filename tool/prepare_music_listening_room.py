"""Archive the rejected early studies; use prepare_umbrella_listening_room for review."""
from pathlib import Path
import json
import math
import shutil
import subprocess
import tempfile

import numpy as np
import soundfile as sf
import author_room_sonic_world_study as world

ROOT = Path(__file__).resolve().parent.parent
AUDIT = ROOT / 'design/audits/2026-09-06/sound-and-music'
DEST = ROOT / 'build/web/music-studies-set-aside-20260906'
SR = world.SAMPLE_RATE


def read(path):
    result = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
                             '-ac', '1', '-ar', str(SR), 'pipe:1'], capture_output=True, check=True)
    return np.frombuffer(result.stdout, dtype=np.float32).astype(np.float64)


def encode(samples, path):
    with tempfile.TemporaryDirectory(prefix='rod-music-flow-') as folder:
        source = Path(folder) / 'flow.wav'
        sf.write(source, samples, SR, subtype='PCM_24')
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(source), '-c:a', 'libmp3lame',
                        '-b:a', '128k', str(path)], check=True)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'tool/preview/sound-review.html', DEST / 'index.html')
    tracks = {
        'umbrella': ROOT / 'assets/music/take_01.m4a',
        'a-little-further': AUDIT / 'a-little-further/a-little-further.m4a',
        'window-light': AUDIT / 'music-variety/window-light.m4a',
        'small-hours': AUDIT / 'music-variety/small-hours.m4a',
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
    decoded = {}
    for name, source in tracks.items():
        shutil.copyfile(source, DEST / f'{name}.m4a')
        decoded[name] = read(source)
        bed = decoded[name][round(14 * SR):round(30 * SR)].copy()
        # Same 80 ms attack / 400 ms recovery and 0.4 floor as MusicDucker.
        # The completion file owns its contact, so there is no extra tap at 8s.
        envelope = np.ones(len(bed))
        for at, _ in cues:
            start = round(at * SR)
            hold = .46 if at == 8 else .14
            down, held, up = round(.08 * SR), round((hold - .08) * SR), round(.4 * SR)
            curve = np.concatenate([np.linspace(1,.4,down), np.full(held,.4), np.linspace(.4,1,up)])
            end = min(len(bed), start + len(curve))
            envelope[start:end] = np.minimum(envelope[start:end], curve[:end-start])
        bed *= envelope
        for at, cue in cues: world._place(bed, cue, at, 1.0)
        encode(bed, DEST / f'{name}-flow.mp3')
    # Use the runtime's 2.5-second linear crossfade at 93.5s, not a bespoke
    # audition transition that would flatter a seam the app cannot reproduce.
    old = decoded['umbrella'][round(86 * SR):].copy()
    mixed = np.zeros(round(20 * SR))
    fade = round(2.5 * SR)
    old[-fade:] *= np.linspace(1, 0, fade)
    world._place(mixed, old, 0, 1)
    new = decoded['a-little-further'][:round(12.5 * SR)].copy()
    new[:fade] *= np.linspace(0, 1, fade)
    world._place(mixed, new, 7.5, 1)
    encode(mixed, DEST / 'a-little-further-transition.mp3')
    (AUDIT / 'listening-room.json').write_text(json.dumps({
        'url': 'http://127.0.0.1:8393/music-studies-set-aside-20260906/',
        'status': 'set aside by owner; not candidates for runtime integration',
        'tracks': list(tracks), 'sfx_event_times': [at for at, _ in events],
        'mix': 'runtime-equivalent natural gains and envelope, no audition-only loudness boost',
        'audio_perception': 'not available to the root model in this session; listening verdict pending',
    }, indent=2) + '\n', encoding='utf-8')
    print(DEST)


if __name__ == '__main__': main()
