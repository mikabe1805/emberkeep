#!/usr/bin/env python3
"""Expand the approved weighted-click C into weight and finish families.

The approved C click remains the immutable reference.  This study changes two
orthogonal properties around it:

* weight changes only the compact body gain and damping;
* finish colors the contact/body spectrum without literal material Foley.

Outputs are staging-only files under ``design/audits``.  Nothing is copied into
``assets/sfx`` and no runtime routing is changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from scipy.signal import resample_poly


TOOL_ROOT = Path(__file__).resolve().parent
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))
import author_weighted_click_study as anchor  # noqa: E402


SAMPLE_RATE = anchor.SAMPLE_RATE
OVERSAMPLE = anchor.OVERSAMPLE
CLICK_SECONDS = anchor.CLICK_SECONDS
VARIANT_COUNT = anchor.VARIANT_COUNT
RAPID_STEP_MS = 125


@dataclass(frozen=True)
class Weight:
    slug: str
    label: str
    body_gain: float
    body_decay_ms: float
    purpose: str


@dataclass(frozen=True)
class Finish:
    slug: str
    label: str
    contact_highpass_hz: float
    contact_lowpass_hz: float
    contact_filter_mix: float
    body_highpass_hz: float
    body_lowpass_hz: float
    body_filter_mix: float
    texture_low_hz: float
    texture_high_hz: float
    texture_mix: float
    mode_frequencies_hz: tuple[float, ...]
    mode_mix: float
    closure_lowpass_hz: float
    closure_filter_mix: float
    closure_gain_scale: float
    purpose: str


WEIGHTS = (
    Weight("light", "Light", 0.205, 9.0, "selectors, chips, toggles, and quick browsing"),
    Weight("settled", "Settled · C", 0.255, 10.5, "ordinary cards and room controls"),
    # Weight comes from a denser mid-body, not a long low note.  Keeping this
    # close to C preserves the approved "dak" while still making decisive
    # controls feel more planted on a phone speaker.
    Weight("weighty", "Weighty", 0.305, 11.5, "commit, place, save, and primary actions"),
)

# These are acoustic finishes, not recordings of props.  Their names describe
# the app surface that would receive the tint if it survives the audition.
FINISHES = (
    Finish(
        "room",
        "Warm room",
        720,
        6_650,
        0.29,
        200,
        2_500,
        0.30,
        250,
        1_520,
        0.18,
        (),
        0.0,
        3_250,
        0.39,
        0.95,
        "warm carved controls and general room navigation",
    ),
    Finish(
        "page",
        "Soft page",
        940,
        5_950,
        0.46,
        380,
        2_650,
        0.39,
        560,
        3_150,
        0.225,
        (),
        0.0,
        3_050,
        0.46,
        0.86,
        "calendar, journal, notes, and planning controls",
    ),
    Finish(
        "lens",
        "Clear lens",
        1_480,
        9_650,
        0.29,
        610,
        4_550,
        0.27,
        860,
        4_450,
        0.095,
        (1_880, 3_060),
        0.095,
        6_050,
        0.24,
        1.045,
        "switches, pickers, previews, and precise utility selection",
    ),
    Finish(
        "gilt",
        "Quiet gilt",
        1_120,
        9_150,
        0.21,
        350,
        4_050,
        0.25,
        620,
        3_450,
        0.085,
        (1_430, 2_180, 3_020),
        0.120,
        5_350,
        0.24,
        1.075,
        "honey buttons and durable, committed choices",
    ),
)

CORE_SLUG = "core"
RATE_ENVELOPE = {
    "rapid_threshold_ms": 135,
    "fast_threshold_ms": 210,
    "rapid_gains": (1.0, 0.93, 0.93, 0.885),
    "tail_suppression_threshold_ms": 70,
    "max_voices": 2,
}


def family_id(weight: Weight | str, finish: Finish | str) -> str:
    weight_slug = weight.slug if isinstance(weight, Weight) else weight
    finish_slug = finish.slug if isinstance(finish, Finish) else finish
    return f"{weight_slug}-{finish_slug}"


def _mechanism(weight: Weight) -> anchor.Mechanism:
    return anchor.Mechanism(weight.slug, weight.body_gain, weight.body_decay_ms, 0.076)


def _normalize_peak(audio: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(audio))) or 1.0
    return audio / peak


def _filtered_blend(
    audio: np.ndarray,
    rate: int,
    *,
    highpass_hz: float | None,
    lowpass_hz: float | None,
    mix: float,
) -> np.ndarray:
    if mix <= 0:
        return audio
    filtered = anchor._filter(
        audio,
        rate,
        highpass_hz=highpass_hz,
        lowpass_hz=lowpass_hz,
        order=2,
    )
    filtered = _normalize_peak(filtered)
    return _normalize_peak(audio * (1.0 - mix) + filtered * mix)


def _texture_layer(finish: Finish, weight: Weight, variant: int, t: np.ndarray, rate: int) -> np.ndarray:
    finish_index = next(index for index, item in enumerate(FINISHES) if item.slug == finish.slug)
    rng = np.random.default_rng(20_268_000 + finish_index * 1_003 + variant * 149)
    texture = anchor._bandpass(
        rng.standard_normal(len(t)),
        rate,
        finish.texture_low_hz,
        finish.texture_high_hz,
        order=2,
    )
    attack = 1.0 - np.exp(-t / 0.00022)
    envelope = attack * np.exp(-t / (weight.body_decay_ms / 1000 * 0.58))
    return _normalize_peak(texture) * envelope


def _mode_tint(finish: Finish, weight: Weight, variant: int, t: np.ndarray) -> np.ndarray:
    if not finish.mode_frequencies_hz:
        return np.zeros_like(t)
    pitch = anchor.PITCH_MULTIPLIERS[variant]
    attack = 1.0 - np.exp(-t / 0.00018)
    result = np.zeros_like(t)
    for index, frequency in enumerate(finish.mode_frequencies_hz):
        amplitude = 1.0 / (1.0 + index * 0.72)
        decay = weight.body_decay_ms / 1000 * (0.46 - index * 0.075)
        result += amplitude * np.sin(
            2 * math.pi * frequency * pitch * t + 0.41 + index * 0.79
        ) * attack * np.exp(-t / max(decay, 0.0024))
    return _normalize_peak(result)


def synth_raw(weight: Weight, finish: Finish | None, variant: int) -> np.ndarray:
    if variant not in range(VARIANT_COUNT):
        raise ValueError(f"variant must be 0..{VARIANT_COUNT - 1}")
    mechanism = _mechanism(weight)
    if finish is None:
        # Settled/core is exactly the approved C synthesis recipe.
        return anchor.synth_click_raw(mechanism, variant)

    rate = SAMPLE_RATE * OVERSAMPLE
    frames = round(CLICK_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate
    contact = anchor._contact_layer(variant, t, rate)
    body = anchor._body_layer(mechanism, variant, t, rate)
    closure = anchor._closure_layer(mechanism, variant, t, rate)

    contact = _filtered_blend(
        contact,
        rate,
        highpass_hz=finish.contact_highpass_hz,
        lowpass_hz=finish.contact_lowpass_hz,
        mix=finish.contact_filter_mix,
    )
    body = _filtered_blend(
        body,
        rate,
        highpass_hz=finish.body_highpass_hz,
        lowpass_hz=finish.body_lowpass_hz,
        mix=finish.body_filter_mix,
    )
    texture = _texture_layer(finish, weight, variant, t, rate)
    mode = _mode_tint(finish, weight, variant, t)
    retained = max(0.0, 1.0 - finish.texture_mix - finish.mode_mix)
    body = _normalize_peak(
        body * retained + texture * finish.texture_mix + mode * finish.mode_mix
    )
    closure = _filtered_blend(
        closure,
        rate,
        highpass_hz=620,
        lowpass_hz=finish.closure_lowpass_hz,
        mix=finish.closure_filter_mix,
    )

    audio = (
        contact * anchor.CONTACT_GAIN
        + body * weight.body_gain
        + closure * 0.076 * finish.closure_gain_scale
    )
    audio = anchor._filter(audio, rate, highpass_hz=160, lowpass_hz=10_000, order=3)
    release = round(rate * 0.022)
    audio[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    audio = resample_poly(audio, 1, OVERSAMPLE, window=("kaiser", 9.0))
    audio = audio[: round(CLICK_SECONDS * SAMPLE_RATE)]
    audio -= float(np.mean(audio[-round(0.010 * SAMPLE_RATE):]))
    return audio.astype(np.float64)


def _anchor_variant_scales() -> tuple[float, ...]:
    approved = anchor.render_families()["c"]
    mechanism = anchor.MECHANISMS[2]
    scales = []
    for variant in range(VARIANT_COUNT):
        raw = anchor.synth_click_raw(mechanism, variant)
        raw *= 10 ** (anchor.VARIANT_GAIN_DB[variant] / 20)
        denominator = float(np.dot(raw, raw)) or 1.0
        scales.append(float(np.dot(approved[variant], raw)) / denominator)
    return tuple(scales)


def render_families(*, level_matched: bool = False) -> dict[str, list[np.ndarray]]:
    scales = _anchor_variant_scales()
    families: dict[str, list[np.ndarray]] = {}
    finishes: tuple[Finish | None, ...] = (None, *FINISHES)
    for weight in WEIGHTS:
        for finish in finishes:
            slug = CORE_SLUG if finish is None else finish.slug
            families[family_id(weight, slug)] = [
                synth_raw(weight, finish, variant)
                * 10 ** (anchor.VARIANT_GAIN_DB[variant] / 20)
                * scales[variant]
                for variant in range(VARIANT_COUNT)
            ]
    if not level_matched:
        return families

    energies = {
        key: math.sqrt(
            sum(anchor._phone_band_rms(audio) ** 2 for audio in variants)
            / len(variants)
        )
        for key, variants in families.items()
    }
    target = min(energies.values())
    return {
        key: [audio * target / (energies[key] or 1.0) for audio in variants]
        for key, variants in families.items()
    }


def rate_gain(click_index: int, interval_ms: float | None) -> float:
    if click_index <= 0 or interval_ms is None:
        return 1.0
    if interval_ms <= RATE_ENVELOPE["rapid_threshold_ms"]:
        gains = RATE_ENVELOPE["rapid_gains"]
        return float(gains[min(click_index, len(gains) - 1)])
    if interval_ms <= RATE_ENVELOPE["fast_threshold_ms"]:
        return 0.93
    return 1.0


def render_sequence(variants: list[np.ndarray], *, count: int = 10) -> np.ndarray:
    lead_seconds = 0.085
    step_seconds = RAPID_STEP_MS / 1000
    total = lead_seconds + step_seconds * (count - 1) + CLICK_SECONDS + 0.170
    result = np.zeros(round(total * SAMPLE_RATE), dtype=np.float64)
    for index in range(count):
        variant = variants[anchor.VARIANT_WALK[index]]
        start = round((lead_seconds + index * step_seconds) * SAMPLE_RATE)
        end = min(len(result), start + len(variant))
        result[start:end] += variant[: end - start] * rate_gain(
            index, RAPID_STEP_MS if index else None
        )
    return result


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_wav(path: Path, audio: np.ndarray, seed: int) -> None:
    anchor.write_wav(path, audio, seed=seed)


def _copy_anchor(anchor_root: Path, output: Path) -> tuple[list[str], dict[str, str]]:
    target_root = output / "anchor"
    target_root.mkdir(parents=True, exist_ok=True)
    paths = []
    hashes = {}
    for variant in range(VARIANT_COUNT):
        source = anchor_root / "variants" / f"dak-c-{variant + 1}.wav"
        if not source.exists():
            raise FileNotFoundError(f"approved C anchor is missing: {source}")
        target = target_root / f"c-{variant + 1}.wav"
        shutil.copyfile(source, target)
        relative = target.relative_to(output).as_posix()
        paths.append(relative)
        hashes[relative] = _sha256(target)
        if _sha256(source) != hashes[relative]:
            raise RuntimeError(f"anchor copy changed bytes: {source}")
    source_reel = anchor_root / "dak-c.wav"
    if source_reel.exists():
        target_reel = target_root / "c-reference.wav"
        shutil.copyfile(source_reel, target_reel)
        relative = target_reel.relative_to(output).as_posix()
        hashes[relative] = _sha256(target_reel)
    return paths, hashes


def build_study(output: Path, anchor_root: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    anchor_paths, anchor_hashes = _copy_anchor(anchor_root, output)
    primary = render_families()
    matched = render_families(level_matched=True)

    manifest: dict[str, object] = {
        "study": "click-weight-finish-v1",
        "approved_anchor": {
            "source_study": anchor_root.as_posix(),
            "source_candidate": "C",
            "variant_paths": anchor_paths,
            "sha256": anchor_hashes,
            "copied_byte_for_byte": True,
        },
        "source": {
            "kind": "approved C procedural mechanism plus deterministic spectral finishes",
            "recorded_foley": False,
            "literal_material_recordings": False,
            "room_or_reverb": False,
            "recipe": "tool/author_click_finish_study.py",
        },
        "weights": [asdict(item) for item in WEIGHTS],
        "finishes": [asdict(item) for item in FINISHES],
        "families": {},
        "rate_envelope": {
            key: list(value) if isinstance(value, tuple) else value
            for key, value in RATE_ENVELOPE.items()
        },
        "rapid_step_ms": RAPID_STEP_MS,
        "variant_walk": list(anchor.VARIANT_WALK),
    }
    report: dict[str, object] = {
        "sample_rate_hz": SAMPLE_RATE,
        "sample_format": "PCM_24 mono",
        "duration_ms": CLICK_SECONDS * 1000,
        "anchor_sha256": anchor_hashes,
        "families": {},
    }
    all_reel = [anchor.silence(0.220)]

    for family_index, (key, variants) in enumerate(primary.items()):
        weight_slug, finish_slug = key.split("-", 1)
        paths: list[str] = []
        matched_paths: list[str] = []
        for variant_index, (audio, matched_audio) in enumerate(
            zip(variants, matched[key])
        ):
            if key == family_id("settled", CORE_SLUG):
                relative = Path(anchor_paths[variant_index])
            else:
                relative = Path("families") / key / f"{variant_index + 1}.wav"
                _write_wav(
                    output / relative,
                    audio,
                    20_269_000 + family_index * 100 + variant_index,
                )
            matched_relative = (
                Path("level-matched") / "families" / key / f"{variant_index + 1}.wav"
            )
            _write_wav(
                output / matched_relative,
                matched_audio,
                20_271_000 + family_index * 100 + variant_index,
            )
            paths.append(relative.as_posix())
            matched_paths.append(matched_relative.as_posix())

        rapid = render_sequence(variants)
        matched_rapid = render_sequence(matched[key])
        manifest["families"][key] = {
            "weight": weight_slug,
            "finish": finish_slug,
            "variant_paths": paths,
            "level_matched_variant_paths": matched_paths,
            "no_immediate_repeat": True,
        }
        report["families"][key] = {
            "rapid": anchor._metrics(rapid),
            "level_matched_rapid": anchor._metrics(matched_rapid),
            "variants": [
                anchor._metrics(audio, click_aligned=True) for audio in variants
            ],
        }
        if finish_slug != CORE_SLUG:
            all_reel.extend((rapid, anchor.silence(0.280)))

    # Compact fallback reels mirror the two-stage browser audition.
    weight_reel = [anchor.silence(0.180)]
    for weight in WEIGHTS:
        weight_reel.extend(
            (render_sequence(primary[family_id(weight, CORE_SLUG)]), anchor.silence(0.340))
        )
    _write_wav(output / "weight-pass.wav", np.concatenate(weight_reel), 20_273_001)
    _write_wav(output / "finish-pass.wav", np.concatenate(all_reel), 20_273_002)
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (output / "metrics.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--anchor-study", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.anchor_study), indent=2))


if __name__ == "__main__":
    main()
