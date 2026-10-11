"""Measurement shared by both palettes: peak, crest, attack, HF share, phone-band RMS.
Same definitions as the sound audit (C:/tmp/cdj/sound-audit/measure.sh):
 peak = sample peak dBFS; rms over the whole file; crest = peak - rms;
 HF share = RMS above 4 kHz (2-pole high-pass) minus total RMS, in dB;
 attack = start of the first 0.5 ms window whose peak is within 1 dB of the file peak.
"""
import math
from pathlib import Path
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

def read_mono(p):
    a, sr = sf.read(str(p), dtype='float64', always_2d=True)
    return a.mean(axis=1), sr

def db(x):
    return 20*math.log10(max(x, 1e-12))

def measure(a, sr):
    pk = float(np.max(np.abs(a)))
    rms = float(np.sqrt(np.mean(a*a)))
    hp = sosfilt(butter(2, 4000, 'highpass', fs=sr, output='sos'), a)
    hf = float(np.sqrt(np.mean(hp*hp)))
    win = max(1, round(0.0005*sr))
    n = len(a)//win
    peaks = np.array([np.max(np.abs(a[i*win:(i+1)*win])) for i in range(n)])
    pkdb = 20*np.log10(np.maximum(peaks, 1e-12))
    mx = pkdb.max()
    idx = int(np.argmax(pkdb >= mx-1.0))
    bp = sosfilt(butter(2, [260, 8000], 'bandpass', fs=sr, output='sos'), a)
    return dict(dur_ms=round(len(a)/sr*1000,1), peak=round(db(pk),2), rms=round(db(rms),2),
                crest=round(db(pk)-db(rms),2), hf=round(db(hf)-db(rms),2),
                attack_ms=round(idx*0.5,1), phone_rms=round(db(float(np.sqrt(np.mean(bp*bp)))),2))

def measure_file(p):
    a, sr = read_mono(p)
    return measure(a, sr)

if __name__ == '__main__':
    import sys
    for p in sys.argv[1:]:
        print(p, measure_file(p))
