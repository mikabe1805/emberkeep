#!/usr/bin/env python3
"""Render a blind Room of Days stone-contact texture study.

The study keeps timing, source contact, loudness, and mastering fixed while
changing only the short texture around the impact.  A licensed, uncompressed
concrete-on-concrete recording remains the dominant layer in every candidate.
Its own low, middle, and edge bands are reshaped separately; no oscillator,
musical note, or reverb is added.  Outputs are audition files under
``design/audits`` and are never
written to ``assets/sfx`` by this tool.

Requires NumPy, SciPy, and SoundFile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt


SAMPLE_RATE = 48_000
TAP_SECONDS = 0.142
SOURCE_SHA256 = "0376417edbf134682f5b654db6892b747a5261d41c55c6778ee1c00991bad853"
SOURCE_TITLE = "Foley Concrete Set On Concrete 01.wav"
SOURCE_PAGE = "https://www.adobe.com/products/audition/offers/audition-dlc.html"
SOURCE_DOWNLOAD = "https://download.adobe.com/pub/adobe/audition/offers/adobeauditiondlcsfx/foley.zip"
SOURCE_TERMS = "https://www.adobe.com/legal/terms.html#content-files"


@dataclass(frozen=True)
class Candidate:
    slug: str
    raw_gain: float
    body_gain: float = 0.0
    mineral_gain: float = 0.0
    edge_gain: float = 0.0
    body_scale: float = 1.0
    body_decay_scale: float = 1.0


# Neutral slugs keep the listening pass blind.  Descriptions live in the
# README key and should only be read after the listener forms an impression.
CANDIDATES = (
    Candidate("a", raw_gain=1.00),
    Candidate("b", raw_gain=0.96, body_gain=0.300),
    Candidate("c", raw_gain=0.97, mineral_gain=0.255),
    Candidate("d", raw_gain=0.95, body_gain=0.220, mineral_gain=0.145),
    Candidate("e", raw_gain=0.96, body_gain=0.070, mineral_gain=0.105, edge_gain=0.235),
    Candidate(
        "f",
        raw_gain=0.93,
        body_gain=0.420,
        mineral_gain=0.040,
        body_scale=0.82,
        body_decay_scale=1.28,
    ),
)

# Both contacts are real events from the same close recording.  Each crop
# begins about 5 ms before its impact, so pointer-down feedback stays prompt.
CONTACT_CROPS = (
    (0.0010, 0.1180, 24.0),
    (0.1230, 0.1575, 13.0),
)

VELOCITIES = (0.94, 1.00, 0.965, 0.915, 0.985, 0.945, 1.00, 0.955, 0.925, 0.975)
CONTACT_ORDER = (0, 1, 0, 1, 0, 1, 1, 0, 1, 0)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _filter(
    audio: np.ndarray,
    *,
    highpass_hz: float | None = None,
    lowpass_hz: float | None = None,
    order: int = 3,
) -> np.ndarray:
    result = audio
    if highpass_hz is not None:
        sos = butter(order, highpass_hz, btype="highpass", fs=SAMPLE_RATE, output="sos")
        result = sosfilt(sos, result, axis=0)
    if lowpass_hz is not None:
        sos = butter(order, lowpass_hz, btype="lowpass", fs=SAMPLE_RATE, output="sos")
        result = sosfilt(sos, result, axis=0)
    return result


def _fade(audio: np.ndarray, attack_ms: float, release_ms: float) -> np.ndarray:
    result = audio.copy()
    attack = min(len(result), max(1, round(SAMPLE_RATE * attack_ms / 1000)))
    release = min(len(result), max(1, round(SAMPLE_RATE * release_ms / 1000)))
    result[:attack] *= (np.sin(np.linspace(0, math.pi / 2, attack)) ** 2)[:, None]
    result[-release:] *= (np.cos(np.linspace(0, math.pi / 2, release)) ** 2)[:, None]
    return result


def _narrow_stereo(audio: np.ndarray, side_gain: float = 0.28) -> np.ndarray:
    mid = np.mean(audio, axis=1)
    side = (audio[:, 0] - audio[:, 1]) * 0.5
    return np.column_stack((mid + side * side_gain, mid - side * side_gain))


def load_source(path: Path, expected_sha256: str | None = SOURCE_SHA256) -> tuple[np.ndarray, dict[str, object]]:
    if not path.is_file():
        raise ValueError(f"source does not exist: {path}")
    digest = _sha256(path)
    if expected_sha256 is not None and digest.lower() != expected_sha256.lower():
        raise ValueError(
            "source SHA-256 does not match the approved Adobe recording: "
            f"expected {expected_sha256}, got {digest}"
        )
    info = sf.info(path)
    if info.samplerate != SAMPLE_RATE or info.channels != 2:
        raise ValueError("source must be 48 kHz stereo")
    audio, rate = sf.read(path, always_2d=True, dtype="float64")
    if rate != SAMPLE_RATE or len(audio) < round(0.30 * SAMPLE_RATE):
        raise ValueError("source is too short for the approved contact crops")
    return audio, {
        "title": SOURCE_TITLE,
        "sha256": digest,
        "sample_rate_hz": info.samplerate,
        "channels": info.channels,
        "source_subtype": info.subtype,
        "source_page": SOURCE_PAGE,
        "download": SOURCE_DOWNLOAD,
        "terms": SOURCE_TERMS,
        "license": "Adobe Audition royalty-free sound effects; source remains cache-only",
    }


def _extract_contact(source: np.ndarray, crop: tuple[float, float, float]) -> np.ndarray:
    start_seconds, end_seconds, release_ms = crop
    segment = source[round(start_seconds * SAMPLE_RATE): round(end_seconds * SAMPLE_RATE)].copy()
    segment = _narrow_stereo(segment)
    segment = _filter(segment, highpass_hz=105, lowpass_hz=14_200, order=3)
    segment -= np.mean(segment, axis=0, keepdims=True)
    segment = _fade(segment, 0.35, release_ms)
    target_frames = round(TAP_SECONDS * SAMPLE_RATE)
    if len(segment) > target_frames:
        segment = segment[:target_frames]
    else:
        segment = np.pad(segment, ((0, target_frames - len(segment)), (0, 0)))
    return segment


def _normalized_layer(audio: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(audio))) or 1.0
    return audio / peak


def _body_layer(contact: np.ndarray, frequency_scale: float, decay_scale: float) -> np.ndarray:
    # Reuse the physical recording's low-mid content instead of fabricating a
    # pitched resonator.  The envelope only changes how much mass follows the
    # initial collision.
    body = _filter(
        contact,
        highpass_hz=145,
        lowpass_hz=1_050 * frequency_scale,
        order=3,
    )
    t = np.arange(len(body), dtype=np.float64) / SAMPLE_RATE
    body *= np.exp(-t / (0.053 * decay_scale))[:, None]
    return _normalized_layer(body)


def _mineral_layer(contact: np.ndarray) -> np.ndarray:
    mineral = _filter(contact, highpass_hz=820, lowpass_hz=4_250, order=3)
    t = np.arange(len(mineral), dtype=np.float64) / SAMPLE_RATE
    mineral *= np.exp(-t / 0.041)[:, None]
    return _normalized_layer(mineral)


def _edge_layer(contact: np.ndarray) -> np.ndarray:
    edge = _filter(contact, highpass_hz=1_850, lowpass_hz=7_800, order=3)
    frames = len(edge)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    edge *= np.exp(-t / 0.0095)[:, None]
    return _normalized_layer(edge)


def _program_rms(audio: np.ndarray) -> float:
    """Return a broad phone-relevant RMS for level matching."""
    probe = _filter(audio, highpass_hz=140, lowpass_hz=12_500, order=2)
    mono = np.mean(probe, axis=1)
    return float(np.sqrt(np.mean(mono * mono)))


def _normalize_tap(audio: np.ndarray, target_rms_dbfs: float = -26.0) -> np.ndarray:
    result = audio.copy()
    rms = _program_rms(result) or 1.0
    result *= 10 ** (target_rms_dbfs / 20) / rms
    peak = float(np.max(np.abs(result))) or 1.0
    ceiling = 10 ** (-4.5 / 20)
    if peak > ceiling:
        result *= ceiling / peak
    result -= np.mean(result[-round(0.020 * SAMPLE_RATE):], axis=0, keepdims=True)
    return _fade(result, 0.20, 13.0)


def render_tap(source: np.ndarray, candidate: Candidate, contact_index: int) -> np.ndarray:
    raw = _extract_contact(source, CONTACT_CROPS[contact_index])
    audio = raw * candidate.raw_gain
    if candidate.body_gain:
        body = _body_layer(raw, candidate.body_scale, candidate.body_decay_scale)
        audio += body * candidate.body_gain
    if candidate.mineral_gain:
        mineral = _mineral_layer(raw)
        audio += mineral * candidate.mineral_gain
    if candidate.edge_gain:
        audio += _edge_layer(raw) * candidate.edge_gain
    audio = _filter(audio, highpass_hz=92, lowpass_hz=14_500, order=2)
    return _normalize_tap(audio)


def silence(seconds: float) -> np.ndarray:
    return np.zeros((round(seconds * SAMPLE_RATE), 2), dtype=np.float64)


def render_phrase(source: np.ndarray, candidate: Candidate, step_seconds: float, count: int) -> np.ndarray:
    lead_seconds = 0.095
    tail_seconds = 0.210
    total_seconds = lead_seconds + step_seconds * (count - 1) + TAP_SECONDS + tail_seconds
    result = np.zeros((round(total_seconds * SAMPLE_RATE), 2), dtype=np.float64)
    for index in range(count):
        tap = render_tap(source, candidate, CONTACT_ORDER[index]) * VELOCITIES[index]
        start = round((lead_seconds + index * step_seconds) * SAMPLE_RATE)
        end = min(len(result), start + len(tap))
        result[start:end] += tap[: end - start]
    return result


def render_candidate(source: np.ndarray, candidate: Candidate) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    measured = render_phrase(source, candidate, 0.285, 6)
    rapid = render_phrase(source, candidate, 0.118, 10)
    combined = np.concatenate((silence(0.120), measured, silence(0.480), rapid, silence(0.260)))
    # Match the rapid pass, where repetition makes small loudness biases most
    # noticeable.  The same gain is then applied to both listening contexts.
    gain = 10 ** (-30.7 / 20) / (_program_rms(rapid) or 1.0)
    measured *= gain
    rapid *= gain
    combined *= gain
    return combined, measured, rapid


def _metrics(audio: np.ndarray) -> dict[str, float]:
    mono = np.mean(audio, axis=1)
    active = mono[np.abs(mono) >= 10 ** (-60 / 20)]
    if not len(active):
        active = mono
    peak = float(np.max(np.abs(audio))) or 1e-12
    rms = float(np.sqrt(np.mean(active * active))) or 1e-12
    spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono)))) ** 2
    frequencies = np.fft.rfftfreq(len(mono), 1 / SAMPLE_RATE)
    power = float(np.sum(spectrum)) or 1.0
    left_rms = float(np.sqrt(np.mean(audio[:, 0] ** 2))) or 1e-12
    right_rms = float(np.sqrt(np.mean(audio[:, 1] ** 2))) or 1e-12
    stereo_rms = math.sqrt((left_rms * left_rms + right_rms * right_rms) / 2)
    mono_rms = float(np.sqrt(np.mean(mono * mono))) or 1e-12
    return {
        "duration_seconds": round(len(audio) / SAMPLE_RATE, 4),
        "peak_dbfs": round(20 * math.log10(peak), 3),
        "active_rms_dbfs": round(20 * math.log10(rms), 3),
        "phone_band_rms_dbfs": round(20 * math.log10(_program_rms(audio) or 1e-12), 3),
        "spectral_centroid_hz": round(float(np.sum(frequencies * spectrum) / power), 2),
        "body_180_900hz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 180) & (frequencies < 900)])) / power, 3
        ),
        "mineral_900_4000hz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 900) & (frequencies < 4_000)])) / power, 3
        ),
        "presence_4_8khz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 4_000) & (frequencies < 8_000)])) / power, 3
        ),
        "air_over_8khz_pct": round(
            100 * float(np.sum(spectrum[frequencies >= 8_000])) / power, 3
        ),
        "mono_fold_loss_db": round(20 * math.log10(mono_rms / stereo_rms), 3),
    }


def write_wav(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def build_study(
    source_path: Path,
    output: Path,
    *,
    expected_source_sha256: str | None = SOURCE_SHA256,
) -> dict[str, object]:
    source, source_record = load_source(source_path, expected_source_sha256)
    output.mkdir(parents=True, exist_ok=True)
    full_reel: list[np.ndarray] = [silence(0.300)]
    rapid_reel: list[np.ndarray] = [silence(0.220)]
    metrics: dict[str, object] = {}
    manifest: dict[str, object] = {
        "study": "stone-texture-study-v1",
        "source": source_record,
        "candidates": [],
    }

    for candidate in CANDIDATES:
        combined, measured, rapid = render_candidate(source, candidate)
        filename = f"stone-{candidate.slug}.wav"
        write_wav(output / filename, combined)
        full_reel.extend((combined, silence(0.720)))
        rapid_reel.extend((rapid, silence(0.460)))
        manifest["candidates"].append({
            "id": f"stone-{candidate.slug}",
            "role": "repeated_stone_contact_texture",
            "path": filename,
        })
        taps = [render_tap(source, candidate, index) for index in range(len(CONTACT_CROPS))]
        metrics[candidate.slug] = {
            "combined": _metrics(combined),
            "measured": _metrics(measured),
            "rapid": _metrics(rapid),
            "contact_variants": [_metrics(tap) for tap in taps],
        }

    write_wav(output / "stone-texture-full-reel.wav", np.concatenate(full_reel))
    write_wav(output / "stone-texture-rapid-reel.wav", np.concatenate(rapid_reel))
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    report = {
        "sample_rate_hz": SAMPLE_RATE,
        "sample_format": "PCM_24",
        "tap_duration_ms": TAP_SECONDS * 1000,
        "measured_step_ms": 285,
        "rapid_step_ms": 118,
        "source": source_record,
        "candidates": metrics,
    }
    (output / "metrics.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--allow-unverified-source",
        action="store_true",
        help="Allow a development fixture instead of the approved Adobe source hash.",
    )
    args = parser.parse_args()
    expected = None if args.allow_unverified_source else SOURCE_SHA256
    print(json.dumps(build_study(args.source, args.output, expected_source_sha256=expected), indent=2))


if __name__ == "__main__":
    main()
