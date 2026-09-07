"""Preserve and level-match the generated music audition for local review.

This processes a returned media artifact, not a shipping music license or a
claim of perceptual approval. Nothing is added to assets/music by this tool.
"""
from pathlib import Path
import hashlib
import json
import math
import subprocess

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfiltfilt
import author_room_sonic_world_study as world

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'design/audits/2026-09-06/sound-and-music/the-lamp-is-on'
SR = world.SAMPLE_RATE


def main():
    source = OUT / 'source.mp3'
    decoded = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(source), '-f', 'f32le',
                               '-ar', str(SR), '-ac', '2', 'pipe:1'], capture_output=True, check=True)
    samples = np.frombuffer(decoded.stdout, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    samples = sosfiltfilt(butter(2, 25, btype='highpass', fs=SR, output='sos'), samples, axis=0)
    before_rms = world._phone_rms(samples.mean(axis=1))
    gain = min(world._db(-36) / before_rms, world._db(-6) / np.max(np.abs(samples)))
    samples *= gain
    fade = round(.015 * SR)
    samples[:fade] *= np.sin(np.linspace(0, math.pi / 2, fade))[:,None] ** 2
    samples[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade))[:,None] ** 2
    master = OUT / 'the-lamp-is-on-master.wav'
    sf.write(master, samples, SR, subtype='PCM_24')
    aac = OUT / 'the-lamp-is-on.m4a'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(master), '-c:a', 'aac', '-b:a', '128k',
                    '-movflags', '+faststart', str(aac)], check=True)
    excerpt = OUT / 'the-lamp-is-on-excerpt.mp3'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-ss', '7', '-i', str(master), '-t', '24',
                    '-c:a', 'libmp3lame', '-b:a', '128k', str(excerpt)], check=True)
    metadata = {
        'title': 'The lamp is on',
        'purpose': 'full-composition audition, not integrated into the runtime playlist',
        'provider': 'vidIQ music-generation tool',
        'job_id': 'job_3563abb3-59fa-4a75-b796-d52b910fc277',
        'music_id': 'f860d6df-9e77-4b92-829e-b678b22f8eaf',
        'source_url': 'https://ai-music-tracks.s3.us-east-1.amazonaws.com/965818a4-fa10-433d-ae67-b757af1842d5/f860d6df-9e77-4b92-829e-b678b22f8eaf.wav',
        'source_format': 'MPEG audio layer III, stereo 44.1 kHz; despite the provider URL .wav suffix',
        'seconds': len(samples) / SR, 'sample_rate': SR, 'channels': 2,
        'processing': 'decode to 48 kHz float stereo, zero-phase 25 Hz highpass to remove source DC, static attenuation to approved music phone-band target, 15 ms edge fades, PCM24 master and AAC128k encoding',
        'gain_db': 20 * math.log10(gain),
        'phone_band_rms_dbfs': 20 * math.log10(world._phone_rms(samples.mean(axis=1))),
        'peak_dbfs': 20 * math.log10(np.max(np.abs(samples))),
        'dc_offset': [float(x) for x in np.mean(samples,axis=0)],
        'hashes': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (source, master, aac, excerpt)},
        'provenance': 'Text-only original composition brief. No reference audio, copied melody, lyrics, artist recording or voice sample was submitted.',
        'rights': {
            'tool_description': 'The tool describes its output as original royalty-free background music.',
            'terms_url': 'https://vidiq.com/terms/',
            'reviewed': '2026-09-06',
            'scope': 'Section 14 says vidIQ does not clear third-party rights and grants no content license except express rights in its terms. Confirm app-distribution rights before bundling this generated candidate.',
            'shipping_clearance': 'pending'
        },
        'approval': {'technical': 'pass', 'cohesion': 'pending', 'physical_device': 'pending'}
    }
    (OUT / 'manifest.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:metadata[k] for k in ('seconds','gain_db','phone_band_rms_dbfs','peak_dbfs','dc_offset')},indent=2))


if __name__ == '__main__': main()
