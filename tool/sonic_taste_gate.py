#!/usr/bin/env python3
"""Small, dependency-free WAV QC and preference-session helper.

This tool measures technical properties and records human choices.  It does
not infer whether a sound is aesthetically good.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
import sys
import wave
from collections import defaultdict
from itertools import combinations
from pathlib import Path
from typing import Any, Iterable


EPSILON = 1e-12


def _decode_pcm(raw: bytes, width: int) -> list[float]:
    """Decode little-endian PCM to the conventional -1..1 range."""
    if width == 1:
        return [(value - 128) / 128.0 for value in raw]
    if width == 2:
        return [value / 32768.0 for value in struct.unpack("<%dh" % (len(raw) // 2), raw)]
    if width == 3:
        values = []
        for offset in range(0, len(raw), 3):
            value = raw[offset] | (raw[offset + 1] << 8) | (raw[offset + 2] << 16)
            if value & 0x800000:
                value -= 0x1000000
            values.append(value / 8388608.0)
        return values
    if width == 4:
        return [value / 2147483648.0 for value in struct.unpack("<%di" % (len(raw) // 4), raw)]
    raise ValueError("only 8-, 16-, 24-, and 32-bit PCM WAV is supported")


def _spectral_band_ratios(samples: list[float], sample_rate: int) -> dict[str, float | None]:
    """A deliberately small windowed DFT for broad QC bands, not pitch analysis."""
    count = min(1024, len(samples))
    if count < 32:
        return {"low_frequency_energy_ratio": None, "presence_energy_ratio": None,
                "brightness_energy_ratio": None, "air_energy_ratio": None,
                "spectral_centroid_hz": None}
    # Follow the loudest gesture rather than the middle of the file. A UI cue
    # can contain intentional silence or a long tail; the salient transient and
    # body are the useful place to assess broad frequency balance.
    peak_index = max(range(len(samples)), key=lambda index: abs(samples[index]))
    start = min(max(0, peak_index - count // 8), len(samples) - count)
    windowed = [samples[start + index] * (0.5 - 0.5 * math.cos(2 * math.pi * index / (count - 1)))
                for index in range(count)]
    low = presence = bright = air = total = weighted_frequency = 0.0
    for bin_index in range(1, count // 2 + 1):
        angle = -2.0 * math.pi * bin_index / count
        real = sum(value * math.cos(angle * index) for index, value in enumerate(windowed))
        imag = sum(value * math.sin(angle * index) for index, value in enumerate(windowed))
        energy = real * real + imag * imag
        frequency = bin_index * sample_rate / count
        total += energy
        weighted_frequency += frequency * energy
        if frequency < 250:
            low += energy
        if 2000 <= frequency < 6000:
            presence += energy
        if frequency >= 4000:
            bright += energy
        if frequency >= 8000:
            air += energy
    if total <= EPSILON:
        return {"low_frequency_energy_ratio": 0.0, "presence_energy_ratio": 0.0,
                "brightness_energy_ratio": 0.0, "air_energy_ratio": 0.0,
                "spectral_centroid_hz": 0.0}
    return {"low_frequency_energy_ratio": low / total,
            "presence_energy_ratio": presence / total,
            "brightness_energy_ratio": bright / total,
            "air_energy_ratio": air / total,
            "spectral_centroid_hz": weighted_frequency / total}


def qc_file(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {"path": str(path)}
    try:
        with wave.open(str(path), "rb") as wav:
            channels, width, rate, frames = wav.getnchannels(), wav.getsampwidth(), wav.getframerate(), wav.getnframes()
            if wav.getcomptype() != "NONE":
                raise ValueError("compressed WAV is unsupported (%s)" % wav.getcomptype())
            raw = wav.readframes(frames)
        decoded = _decode_pcm(raw, width)
        channel_frames = [decoded[offset:offset + channels]
                          for offset in range(0, len(decoded), channels)]
        mono = [sum(frame) / channels for frame in channel_frames]
        frame_peaks = [max((abs(value) for value in frame), default=0.0)
                       for frame in channel_frames]
        peak = max((abs(value) for value in decoded), default=0.0)
        mean = sum(decoded) / len(decoded) if decoded else 0.0
        rms = math.sqrt(sum(value * value for value in decoded) / len(decoded)) if decoded else 0.0
        mono_rms = math.sqrt(sum(value * value for value in mono) / len(mono)) if mono else 0.0
        quantization_step = 1.0 / (128 if width == 1 else 2 ** (width * 8 - 1))
        audible_threshold = max(10 ** (-60 / 20), quantization_step)
        attack_threshold = max(peak * 0.1, quantization_step)
        onset = next((index / rate for index, value in enumerate(frame_peaks)
                      if value >= audible_threshold), None)
        attack_10pct = next((index / rate for index, value in enumerate(frame_peaks)
                             if value >= attack_threshold), None)
        clipped = sum(abs(value) >= 0.999 for value in decoded)
        tail_length = min(len(mono), max(1, round(rate * 0.1)),
                          max(1, round(len(mono) * 0.1)))
        tail = mono[-tail_length:]
        tail_rms = math.sqrt(sum(value * value for value in tail) / len(tail)) if tail else 0.0
        tail_relative_db = 20 * math.log10(max(tail_rms, EPSILON) / max(mono_rms, EPSILON))
        stereo_correlation = None
        mono_fold_loss_db = None
        if channels == 2 and channel_frames:
            left = [frame[0] for frame in channel_frames]
            right = [frame[1] for frame in channel_frames]
            left_mean = sum(left) / len(left)
            right_mean = sum(right) / len(right)
            covariance = sum((a - left_mean) * (b - right_mean)
                             for a, b in zip(left, right))
            left_energy = sum((value - left_mean) ** 2 for value in left)
            right_energy = sum((value - right_mean) ** 2 for value in right)
            denominator = math.sqrt(left_energy * right_energy)
            stereo_correlation = covariance / denominator if denominator > EPSILON else None
            mono_fold_loss_db = 20 * math.log10(max(mono_rms, EPSILON) / max(rms, EPSILON))
        result.update({
            "status": "ok", "sample_rate_hz": rate, "channels": channels,
            "sample_width_bits": width * 8, "duration_seconds": frames / rate if rate else 0.0,
            "peak": peak, "rms": rms, "dc_offset": mean, "onset_seconds": onset,
            "attack_10pct_seconds": attack_10pct,
            "crest_factor_db": 20 * math.log10(peak / max(rms, EPSILON)),
            "clipping_sample_ratio": clipped / len(decoded) if decoded else 0.0,
            "clipping_detected": bool(clipped),
            "tail_window_ms": 1000 * tail_length / rate if rate else 0.0,
            "tail_rms_final_window": tail_rms,
            "tail_relative_to_program_db": tail_relative_db,
            "stereo_correlation": stereo_correlation,
            "mono_fold_loss_db": mono_fold_loss_db,
        })
        result.update(_spectral_band_ratios(mono, rate))
    except (EOFError, ValueError, wave.Error, struct.error) as error:
        result.update({"status": "unsupported_or_invalid", "error": str(error)})
    return result


def _audio_paths(inputs: Iterable[str]) -> list[Path]:
    paths: list[Path] = []
    for raw in inputs:
        path = Path(raw)
        if path.is_dir():
            paths.extend(sorted(item for item in path.rglob("*") if item.is_file() and item.suffix.lower() == ".wav"))
        else:
            paths.append(path)
    return paths


def run_qc(inputs: Iterable[str]) -> dict[str, Any]:
    reports = [qc_file(path) if path.exists() else {"path": str(path), "status": "missing", "error": "file not found"}
               for path in _audio_paths(inputs)]
    return {"tool": "sonic_taste_gate", "mode": "qc", "files": reports,
            "summary": {"total": len(reports), "ok": sum(item["status"] == "ok" for item in reports)}}


def _load_json(path: str) -> Any:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def make_session(manifest_path: str) -> dict[str, Any]:
    manifest = _load_json(manifest_path)
    candidates = manifest["candidates"] if isinstance(manifest, dict) else manifest
    if not isinstance(candidates, list):
        raise ValueError("manifest must be a candidate list or contain a candidates list")
    normalized = []
    seen = set()
    for candidate in candidates:
        if not isinstance(candidate, dict) or not all(isinstance(candidate.get(key), str) and candidate[key] for key in ("id", "role", "path")):
            raise ValueError("each candidate requires non-empty string id, role, and path")
        if candidate["id"] in seen:
            raise ValueError("candidate ids must be unique: %s" % candidate["id"])
        seen.add(candidate["id"])
        normalized.append({key: candidate[key] for key in ("id", "role", "path")})
    normalized.sort(key=lambda item: (item["role"], item["id"]))
    pairs = []
    by_role: dict[str, list[dict[str, str]]] = defaultdict(list)
    for candidate in normalized:
        by_role[candidate["role"]].append(candidate)
    for role in sorted(by_role):
        for a, b in combinations(by_role[role], 2):
            pairs.append({"id": "%s:%s__%s" % (role, a["id"], b["id"]), "role": role,
                          "a": a["id"], "b": b["id"]})
    return {"format": "sonic-taste-session/v1", "candidates": normalized, "pairs": pairs,
            "rating_choices": ["a", "b", "no_preference", "both_bad"]}


def _connected(ids: list[str], comparisons: list[tuple[str, str]]) -> bool:
    if len(ids) < 2:
        return False
    links = {item: set() for item in ids}
    for a, b in comparisons:
        links[a].add(b); links[b].add(a)
    visited, todo = set(), [ids[0]]
    while todo:
        current = todo.pop()
        if current in visited:
            continue
        visited.add(current); todo.extend(links[current] - visited)
    return len(visited) == len(ids)


def fit_session(session_path: str, ratings_path: str) -> dict[str, Any]:
    session = _load_json(session_path)
    candidates = {item["id"]: item for item in session.get("candidates", [])}
    pairs = {item["id"]: item for item in session.get("pairs", [])}
    ratings = []
    with open(ratings_path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            if not raw.strip():
                continue
            try:
                rating = json.loads(raw)
                pair = pairs[rating["pair_id"]]
                choice = rating["choice"]
                if choice == "tie":
                    choice = "no_preference"
                if choice not in ("a", "b", "no_preference", "both_bad"):
                    raise ValueError("unknown choice")
                ratings.append((pair, choice))
            except (KeyError, ValueError, json.JSONDecodeError) as error:
                raise ValueError("invalid rating on line %d: %s" % (number, error)) from error
    role_results = []
    by_role: dict[str, list[tuple[dict[str, str], str]]] = defaultdict(list)
    for pair, choice in ratings:
        by_role[pair["role"]].append((pair, choice))
    for role in sorted({item["role"] for item in candidates.values()}):
        ids = sorted(item["id"] for item in candidates.values() if item["role"] == role)
        role_ratings = by_role[role]
        usable = [(pair, choice) for pair, choice in role_ratings if choice != "both_bad"]
        scores = {item: 0.0 for item in ids}
        # Fixed-iteration, lightly regularized logistic Bradley-Terry fit.
        for _ in range(300):
            gradients = {item: -0.02 * scores[item] for item in ids}
            for pair, choice in usable:
                a, b = pair["a"], pair["b"]
                probability_a = 1.0 / (1.0 + math.exp(max(-50.0, min(50.0, scores[b] - scores[a]))))
                outcome_a = 1.0 if choice == "a" else 0.0 if choice == "b" else 0.5
                gradients[a] += outcome_a - probability_a
                gradients[b] -= outcome_a - probability_a
            for item in ids:
                scores[item] += 0.04 * gradients[item]
        mean_score = sum(scores.values()) / len(ids) if ids else 0.0
        scores = {item: scores[item] - mean_score for item in ids}
        comparisons = [(pair["a"], pair["b"]) for pair, _ in usable]
        connected = _connected(ids, comparisons)
        sufficient = len(usable) >= max(1, len(ids) - 1) and connected
        bad_counts = {item: 0 for item in ids}
        for pair, choice in role_ratings:
            if choice == "both_bad":
                bad_counts[pair["a"]] += 1; bad_counts[pair["b"]] += 1
        role_results.append({"role": role, "status": "ok" if sufficient else "insufficient_data",
                             "message": "Connected comparison coverage is available." if sufficient else "Need connected comparisons across every candidate; scores are provisional.",
                             "ratings": len(role_ratings), "usable_comparisons": len(usable),
                             "both_bad_ratings": len(role_ratings) - len(usable),
                             "scores": [{"id": item, "score": scores[item], "both_bad_count": bad_counts[item]} for item in ids]})
    return {"format": "sonic-taste-fit/v1", "ratings_read": len(ratings), "roles": role_results}


def _write_json(path: str, value: Any) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    qc = commands.add_parser("qc"); qc.add_argument("inputs", nargs="+"); qc.add_argument("--json-out", required=True)
    session = commands.add_parser("make-session"); session.add_argument("--manifest", required=True); session.add_argument("--out", required=True)
    fit = commands.add_parser("fit"); fit.add_argument("--session", required=True); fit.add_argument("--ratings", required=True); fit.add_argument("--out", required=True)
    args = parser.parse_args(argv)
    try:
        result = run_qc(args.inputs) if args.command == "qc" else make_session(args.manifest) if args.command == "make-session" else fit_session(args.session, args.ratings)
        _write_json(args.json_out if args.command == "qc" else args.out, result)
        return 0
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("sonic_taste_gate: %s" % error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
