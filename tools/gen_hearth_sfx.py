"""Build Morrowloom's two polished hearth cues from CC0 recordings."""

from __future__ import annotations

import shutil
import subprocess
import urllib.request
from pathlib import Path


SOURCES = {
    "ignition.flac": "https://opengameart.org/sites/default/files/ignition.flac",
    "fire-loop.wav": "https://opengameart.org/sites/default/files/fire.wav",
}

IGNITION_GRAPH = (
    "[0:a]atrim=start=0.02:end=1.16,asetpts=PTS-STARTPTS,"
    "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=70,lowpass=f=14000,"
    "bass=g=4:f=190:w=0.7,volume=1.10,afade=t=in:st=0:d=0.015,"
    "afade=t=out:st=0.88:d=0.26[bright];"
    "[0:a]atrim=start=0.02:end=1.16,asetpts=PTS-STARTPTS,"
    "pan=mono|c0=0.5*c0+0.5*c1,asetrate=38000,aresample=44100,"
    "highpass=f=48,lowpass=f=8200,bass=g=7:f=145:w=0.75,"
    "treble=g=-3:f=3000:w=0.8,volume=1.25,adelay=20,"
    "afade=t=in:st=0:d=0.02,afade=t=out:st=1.03:d=0.27[deep];"
    "[1:a]atrim=start=14.8:duration=3.30,asetpts=PTS-STARTPTS,"
    "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=60,lowpass=f=10500,"
    "bass=g=4:f=200:w=0.7,treble=g=-1.5:f=4200:w=0.8,volume=2.6,"
    "afade=t=in:st=0:d=0.04,afade=t=out:st=2.52:d=0.78[bed];"
    "[bright][deep][bed]amix=inputs=3:weights='1.0 1.0 0.95':normalize=0,"
    "alimiter=limit=0.78:attack=5:release=150,"
    "loudnorm=I=-20.5:TP=-2.5:LRA=7[out]"
)

ROOM_FILTERS = (
    "pan=mono|c0=0.5*c0+0.5*c1,highpass=f=65,lowpass=f=8500,"
    "bass=g=5:f=190:w=0.7,treble=g=-2.5:f=3600:w=0.8,"
    "afade=t=in:st=0:d=0.12,afade=t=out:st=1.38:d=0.47,"
    "loudnorm=I=-25:TP=-5:LRA=4"
)


def fetch_sources(source_dir: Path) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    source_dir.mkdir(parents=True, exist_ok=True)
    for filename, url in SOURCES.items():
        path = source_dir / filename
        if not path.exists():
            print(f"downloading CC0 source: {url}")
            urllib.request.urlretrieve(url, path)
        paths[filename] = path
    return paths


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required to rebuild the hearth cues")

    root = Path(__file__).resolve().parents[1]
    sources = fetch_sources(root / "output" / "audio-source")
    output_dir = root / "assets" / "sfx"
    output_dir.mkdir(parents=True, exist_ok=True)

    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-i",
            str(sources["ignition.flac"]),
            "-i",
            str(sources["fire-loop.wav"]),
            "-filter_complex",
            IGNITION_GRAPH,
            "-map",
            "[out]",
            "-ar",
            "44100",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(output_dir / "hearth.wav"),
        ]
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-v",
            "error",
            "-ss",
            "16.2",
            "-t",
            "1.85",
            "-i",
            str(sources["fire-loop.wav"]),
            "-af",
            ROOM_FILTERS,
            "-ar",
            "44100",
            "-ac",
            "1",
            "-c:a",
            "pcm_s16le",
            str(output_dir / "hearth_room.wav"),
        ]
    )
    print("wrote hearth.wav (ignition + fire) and hearth_room.wav (quiet fire)")


if __name__ == "__main__":
    main()
