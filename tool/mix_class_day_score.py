#!/usr/bin/env python3
"""Mix a scripted class day offline, from the shipped files and the app's plan.

The score is built from commands: which file to start, when, and at what
volume. test/class_day_score_plan_test.dart runs a scripted day through the
REAL music controller and the REAL class-day score (on fake time and a
recording transport) and writes build/class_day_plan/plan.json: every file the
app would start, when its first sample would sound, and every volume it would
set. This tool decodes the shipped .m4a files (assets/music/class_day and the
files the plan names), places each at its first sample to the sample, holds
each volume call until the next, and adds the class chimes and completion
sounds the Doorway plays. So what you hear is what those commands make; a
wrong file or a wrong beat in the app would be wrong here too.

    flutter test --no-pub test/class_day_score_plan_test.dart
    python tool/mix_class_day_score.py OUT_DIR

The plan test writes two days: plan.json (a short one) and plan-varied.json (a
longer day that crosses three pass boundaries, every pass another performance
of the form). Mix the long one with

    python tool/mix_class_day_score.py OUT_DIR --plan build/class_day_plan/plan-varied.json \\
        --name day-varied --main-only

which writes only day-varied.wav and day-varied-phone.wav, and prints how the
level and the waveform behave across each pass boundary.

writes in OUT_DIR:

  day.wav                       the day, every level as in the app, scaled by
                                ONE constant so the loudest peak is -1 dBFS
                                (the app's music sits at -36 dBFS phone-band
                                RMS; the constant is printed and written to
                                ORDER.txt)
  day-phone.wav                 the same, through a phone speaker's band
                                (260 Hz to 8 kHz)
  day-without-swells.wav        the same day with the swells left out: what
                                they add
  day-swell-early-40ms.wav      every swell 40 ms early (inside the budget)
  day-swell-late-40ms.wav       every swell 40 ms late (inside the budget)
  day-swell-late-90ms-dropped.wav
                                every swell 90 ms late: the app drops a start
                                more than 60 ms from its beat, so these have
                                no swell, only the chimes

Needs numpy, scipy, soundfile and ffmpeg.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parent.parent
SR = 48_000
DROP_MS = 60  # lib/class_day_score.dart ClassDayScore.lateDrop


def decode(path: Path) -> np.ndarray:
    """A file as the phone's decoder would give it: mono 48 kHz float."""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("ffmpeg is required")
    proc = subprocess.run(
        [ffmpeg, "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
        capture_output=True,
        check=True,
    )
    return np.frombuffer(proc.stdout, dtype="<f4").astype(np.float64)


class Library:
    def __init__(self) -> None:
        self._cache: dict[str, np.ndarray] = {}

    def get(self, asset: str) -> np.ndarray:
        if asset not in self._cache:
            self._cache[asset] = decode(ROOT / "assets" / asset)
        return self._cache[asset]


def held_gain(times_micros: np.ndarray, volumes: list[list[float]]) -> np.ndarray:
    """The volume in force at each time: each setVolume call holds until the
    next, as the player does."""
    at = np.array([v[0] for v in volumes], dtype=np.float64)
    level = np.array([v[1] for v in volumes], dtype=np.float64)
    idx = np.searchsorted(at, times_micros, side="right") - 1
    return np.where(idx >= 0, level[np.clip(idx, 0, None)], 0.0)


def mix(
    plan: dict, lib: Library, shift_ms: float = 0.0, swells: bool = True, cues: bool = True
) -> np.ndarray:
    length = round((plan["durationMs"] / 1000 + 3.0) * SR)
    out = np.zeros(length)
    for voice in plan["voices"]:
        shift = 0.0
        if voice["kind"] == "swell":
            if not swells or abs(shift_ms) > DROP_MS:
                continue  # the app drops a start more than 60 ms from its beat
            shift = shift_ms
        audio = lib.get(voice["asset"])
        start = round((voice["zeroAtMicros"] / 1e6 + shift / 1000) * SR)
        n = min(len(audio), length - start)
        if n <= 0:
            continue
        times = (start + np.arange(n)) / SR * 1e6 - shift * 1000
        gain = held_gain(times, voice["volumes"])
        released = voice.get("releasedAtMs")
        if released is not None:
            gain = np.where(times >= released * 1000, 0.0, gain)
        out[start:start + n] += audio[:n] * gain
    for cue in plan["cues"] if cues else []:
        audio = lib.get(cue["asset"])
        start = round(cue["t"] / 1000 * SR)
        n = min(len(audio), length - start)
        if n > 0:
            out[start:start + n] += audio[:n] * cue["volume"]
    return out


def phone_band(a: np.ndarray) -> np.ndarray:
    hp = butter(2, 260, "highpass", fs=SR, output="sos")
    lp = butter(2, 8000, "lowpass", fs=SR, output="sos")
    return sosfilt(lp, sosfilt(hp, a))


def db(x: float) -> float:
    return 20 * math.log10(max(float(x), 1e-12))


def rms_db(a: np.ndarray) -> float:
    return db(math.sqrt(float(np.mean(a * a))))


def write(path: Path, a: np.ndarray, scale: float) -> None:
    y = a * scale
    if np.max(np.abs(y)) > 1.0:
        sys.exit(f"{path.name} clips after scaling")
    sf.write(str(path), y, SR, subtype="PCM_16")


def stats(plan: dict, base: np.ndarray, without: np.ndarray) -> list[str]:
    """What the swells add to the music alone (no chimes), in the phone band,
    over each swell's two bars."""
    lines = []
    for voice in plan["voices"]:
        if voice["kind"] != "swell":
            continue
        beat = voice["zeroAtMicros"] / 1e6 + 0.15
        held = slice(round(beat * SR), round((beat + 2 * 4 * 60 / 72) * SR))
        with_swell = rms_db(phone_band(base[held]))
        without_swell = rms_db(phone_band(without[held]))
        lines.append(
            f"{voice['asset']}: beat at {beat:.3f} s, bed {without_swell:.1f} dBFS -> "
            f"with swell {with_swell:.1f} dBFS (+{with_swell - without_swell:.1f} dB) over its two bars"
        )
    return lines


def seams(plan: dict, music: np.ndarray) -> list[str]:
    """How the music behaves where one pass hands over to the next: the
    phone-band level in the 4 s either side, and the largest sample-to-sample
    jump in the 100 ms around the boundary against the same measure over the
    4 s before it (a click would stand out)."""
    beds = [v for v in plan["voices"] if v["kind"] == "bed"]
    lines = []
    for i in range(1, len(beds)):
        t = beds[i]["zeroAtMicros"] / 1e6
        before = music[round((t - 4.0) * SR):round(t * SR)]
        after = music[round(t * SR):round((t + 4.0) * SR)]
        around = music[round((t - 0.05) * SR):round((t + 0.05) * SR)]
        step = float(np.max(np.abs(np.diff(around))))
        ref = float(np.max(np.abs(np.diff(before))))
        lines.append(
            f"boundary {i} at {t:6.2f} s: {beds[i - 1]['asset'].split('/')[-1]} -> "
            f"{beds[i]['asset'].split('/')[-1]}; phone-band level {rms_db(phone_band(before)):.1f} -> "
            f"{rms_db(phone_band(after)):.1f} dBFS; largest step in the 100 ms around it "
            f"{step / ref:.2f} x the 4 s before"
        )
    return lines


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("out", type=Path, help="folder to write the WAVs into")
    parser.add_argument("--plan", type=Path, default=ROOT / "build/class_day_plan/plan.json")
    parser.add_argument("--name", default="day", help="file name stem of the WAVs (default: day)")
    parser.add_argument(
        "--main-only", action="store_true",
        help="write only NAME.wav and NAME-phone.wav, not the without-swells and timing variants",
    )
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    args.out.mkdir(parents=True, exist_ok=True)
    lib = Library()

    base = mix(plan, lib)
    without = mix(plan, lib, swells=False)
    # One constant for every file, so they stay comparable and level-matched.
    peak = float(np.max(np.abs(base)))
    scale = 10 ** (-1.0 / 20) / peak
    scale_db = db(scale)

    outputs = {
        f"{args.name}.wav": base,
        f"{args.name}-phone.wav": phone_band(base),
    }
    if not args.main_only:
        outputs.update(
            {
                f"{args.name}-without-swells.wav": without,
                f"{args.name}-swell-early-40ms.wav": mix(plan, lib, shift_ms=-40),
                f"{args.name}-swell-late-40ms.wav": mix(plan, lib, shift_ms=40),
                f"{args.name}-swell-late-90ms-dropped.wav": mix(plan, lib, shift_ms=90),
            }
        )
    for name, audio in outputs.items():
        write(args.out / name, audio, scale)
        print(f"wrote {name}  {len(audio) / SR:.1f} s")
    music_only = mix(plan, lib, cues=False)
    report = stats(plan, music_only, mix(plan, lib, swells=False, cues=False))
    for line in report:
        print(line)
    for line in seams(plan, mix(plan, lib, swells=False, cues=False)):
        print(line)
    print(f"one constant on every file: {scale_db:+.1f} dB (the app's levels, plus this)")
    for line in plan["script"]:
        print(f"{line['t'] / 1000:7.1f} s  {line['what']}")


if __name__ == "__main__":
    main()
