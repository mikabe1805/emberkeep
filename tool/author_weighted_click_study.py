#!/usr/bin/env python3
"""Author a blind, abstract weighted-click system for Room of Days.

The target is a compact virtual mechanism closing: an immediate contact, a
short midrange body that implies mass, and (for some candidates) a quiet
second closure.  It deliberately avoids literal material Foley, room sound,
and melodic UI chimes.  Each mechanism has five related microvariants so it
can be evaluated as a repeated interaction family rather than a one-shot SFX.

Outputs are staging-only files under ``design/audits``.  This tool never writes
to ``assets/sfx`` or changes runtime routing.

Requires NumPy, SciPy, and SoundFile.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, resample_poly, sosfilt


SAMPLE_RATE = 48_000
OVERSAMPLE = 4
CLICK_SECONDS = 0.060
VARIANT_COUNT = 5


@dataclass(frozen=True)
class Mechanism:
    slug: str
    body_gain: float
    body_decay_ms: float
    closure_gain: float


# A strict 2 x 2 study: light/weighted body x single/two-stage closure.  Contact,
# tuning, export gain, and closure treatment are otherwise identical.  This
# lets a preference answer a useful question instead of merely picking between
# four unrelated timbres.
MECHANISMS = (
    Mechanism("a", 0.255, 10.5, 0.000),
    Mechanism("b", 0.405, 14.5, 0.000),
    Mechanism("c", 0.255, 10.5, 0.076),
    Mechanism("d", 0.405, 14.5, 0.076),
)

CONTACT_GAIN = 0.620
CONTACT_DECAY_MS = 2.05
CLOSURE_DELAY_MS = 6.0
CLOSURE_DECAY_MS = 1.45

# Pitch belongs only to the compact body; the contact and closure retain the
# same identity.  The movement is intentionally sub-semitonal to start.  If
# the physical gesture is approved, the palette can become more expressive.
PITCH_MULTIPLIERS = (1.000, 1.021, 0.987, 1.036, 1.009)
VARIANT_GAIN_DB = (0.00, -0.30, 0.18, -0.18, 0.08)
GRAIN_MULTIPLIERS = (1.000, 0.955, 1.035, 0.978, 1.018)

# A deterministic non-repeating walk.  It is used by both the rendered reels
# and the browser lab so the two listening contexts exercise the same family.
VARIANT_WALK = (0, 2, 1, 3, 1, 4, 2, 0, 3, 4, 1, 2, 4, 0)

RATE_ENVELOPE = {
    "rapid_threshold_ms": 110,
    "fast_threshold_ms": 180,
    "rapid_gains": (1.0, 0.93, 0.93, 0.885),
    "tail_suppression_threshold_ms": 70,
    "max_voices": 2,
}


def _filter(
    audio: np.ndarray,
    rate: int,
    *,
    highpass_hz: float | None = None,
    lowpass_hz: float | None = None,
    order: int = 3,
) -> np.ndarray:
    result = audio
    if highpass_hz is not None:
        result = sosfilt(
            butter(order, highpass_hz, btype="highpass", fs=rate, output="sos"),
            result,
        )
    if lowpass_hz is not None:
        result = sosfilt(
            butter(order, lowpass_hz, btype="lowpass", fs=rate, output="sos"),
            result,
        )
    return result


def _bandpass(audio: np.ndarray, rate: int, low_hz: float, high_hz: float, order: int = 3) -> np.ndarray:
    result = _filter(audio, rate, highpass_hz=low_hz, order=order)
    return _filter(result, rate, lowpass_hz=high_hz, order=order)


def _normalize_peak(audio: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(audio))) or 1.0
    return audio / peak


def _contact_layer(variant: int, t: np.ndarray, rate: int) -> np.ndarray:
    rng = np.random.default_rng(20_260_820 + variant * 97)
    noise = rng.standard_normal(len(t))
    brightness = GRAIN_MULTIPLIERS[variant]
    edge = _normalize_peak(
        _bandpass(
            noise,
            rate,
            1_280 * brightness,
            min(7_400 * brightness, rate * 0.43),
            order=3,
        )
    )
    body_noise = _normalize_peak(
        _bandpass(
            np.random.default_rng(20_260_841 + variant * 101).standard_normal(len(t)),
            rate,
            470,
            2_450,
            order=3,
        )
    )
    attack = 1.0 - np.exp(-t / 0.00012)
    edge_envelope = attack * np.exp(-t / (CONTACT_DECAY_MS / 1000))
    body_envelope = attack * np.exp(-t / 0.00315)
    return _normalize_peak(edge * edge_envelope * 0.72 + body_noise * body_envelope * 0.48)


def _body_layer(mechanism: Mechanism, variant: int, t: np.ndarray, rate: int) -> np.ndarray:
    pitch = PITCH_MULTIPLIERS[variant]
    decay = mechanism.body_decay_ms / 1000
    attack = 1.0 - np.exp(-t / 0.00022)

    # A brief inharmonic cluster suggests mass without turning the click into a
    # musical note.  Independent decay times stop the modes from moving as one
    # obvious oscillator.
    frequencies = (610 * pitch, 925 * pitch, 1_385 * pitch, 1_925 * pitch)
    amplitudes = (0.48, 0.235, 0.125, 0.060)
    decay_scales = (1.00, 0.69, 0.43, 0.27)
    phases = (0.11, 0.73, 1.67, 2.31)
    # Each mode owns its own short decay; no shared gliding fundamental.
    modal = sum(
        amplitude
        * np.sin(2 * math.pi * frequency * t + phase_offset)
        * attack
        * np.exp(-t / (decay * decay_scale))
        for frequency, amplitude, decay_scale, phase_offset in zip(
            frequencies, amplitudes, decay_scales, phases
        )
    )

    # Clean, filtered excitation is a substantial part of the body.  It gives
    # the mechanism texture and prevents the old smooth/boopy sine character.
    rng = np.random.default_rng(20_260_911 + variant * 131)
    excitation = _normalize_peak(_bandpass(rng.standard_normal(len(t)), rate, 340, 2_750, order=2))
    texture = _normalize_peak(
        _bandpass(
            np.random.default_rng(20_260_939 + variant * 137).standard_normal(len(t)),
            rate,
            820,
            4_100,
            order=2,
        )
    )
    broad_envelope = attack * np.exp(-t / (decay * 0.78))
    body = modal * 0.68 + excitation * broad_envelope * 0.245
    body += texture * attack * np.exp(-t / (decay * 0.42)) * 0.095
    return _normalize_peak(body)


def _closure_layer(mechanism: Mechanism, variant: int, t: np.ndarray, rate: int) -> np.ndarray:
    if mechanism.closure_gain <= 0:
        return np.zeros_like(t)
    local = t - CLOSURE_DELAY_MS / 1000
    active = local >= 0
    local_positive = np.maximum(local, 0.0)
    rng = np.random.default_rng(20_261_002 + variant * 173)
    noise = _normalize_peak(_bandpass(rng.standard_normal(len(t)), rate, 880, 4_500, order=3))
    envelope = active * (1.0 - np.exp(-local_positive / 0.00010))
    envelope *= np.exp(-local_positive / (CLOSURE_DECAY_MS / 1000))
    low = _normalize_peak(
        _bandpass(
            np.random.default_rng(20_261_027 + variant * 179).standard_normal(len(t)),
            rate,
            480,
            1_650,
            order=2,
        )
    )
    return _normalize_peak(noise * envelope * 0.76 + low * envelope * 0.42)


def synth_click_raw(mechanism: Mechanism, variant: int) -> np.ndarray:
    if variant not in range(VARIANT_COUNT):
        raise ValueError(f"variant must be 0..{VARIANT_COUNT - 1}")
    rate = SAMPLE_RATE * OVERSAMPLE
    frames = round(CLICK_SECONDS * rate)
    t = np.arange(frames, dtype=np.float64) / rate

    contact = _contact_layer(variant, t, rate)
    body = _body_layer(mechanism, variant, t, rate)
    closure = _closure_layer(mechanism, variant, t, rate)
    audio = (
        contact * CONTACT_GAIN
        + body * mechanism.body_gain
        + closure * mechanism.closure_gain
    )
    audio = _filter(audio, rate, highpass_hz=160, lowpass_hz=10_000, order=3)

    # Park every mechanism before the current +65 ms success-cue separation.
    # The longer shared gate begins after the perceived mechanism has settled,
    # then reaches mathematical silence at the file boundary.
    release = round(rate * 0.022)
    audio[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    audio = resample_poly(audio, 1, OVERSAMPLE, window=("kaiser", 9.0))
    audio = audio[: round(CLICK_SECONDS * SAMPLE_RATE)]
    audio -= float(np.mean(audio[-round(0.010 * SAMPLE_RATE):]))
    return audio.astype(np.float64)


def _phone_band_rms(audio: np.ndarray) -> float:
    probe = _filter(audio, SAMPLE_RATE, highpass_hz=260, lowpass_hz=8_000, order=2)
    return float(np.sqrt(np.mean(probe * probe)))


def _raw_families() -> dict[str, list[np.ndarray]]:
    return {
        mechanism.slug: [
            synth_click_raw(mechanism, index) * 10 ** (VARIANT_GAIN_DB[index] / 20)
            for index in range(VARIANT_COUNT)
        ]
        for mechanism in MECHANISMS
    }


def render_families(*, level_matched: bool = False) -> dict[str, list[np.ndarray]]:
    """Render families with either shared contact gain or equalized energy.

    The primary pass applies one global gain to every candidate, preserving the
    exact same contact transient.  The optional control pass equalizes average
    phone-band energy per family so a preference can be checked against simple
    loudness salience.
    """
    families = _raw_families()
    # Calibrate each microvariant once across all candidates.  The same factor
    # is then applied to A-D, so variant texture changes without one family
    # receiving a private loudness advantage.
    variant_energies = []
    for index in range(VARIANT_COUNT):
        variant_energies.append(
            math.sqrt(
                sum(_phone_band_rms(families[slug][index]) ** 2 for slug in families)
                / len(families)
            )
        )
    variant_target = sum(variant_energies) / len(variant_energies)
    families = {
        slug: [
            audio * variant_target / (variant_energies[index] or 1.0)
            for index, audio in enumerate(variants)
        ]
        for slug, variants in families.items()
    }
    ceiling = 10 ** (-6.0 / 20)
    common_peak = max(float(np.max(np.abs(audio))) for variants in families.values() for audio in variants)
    common_gain = ceiling / (common_peak or 1.0)
    families = {
        slug: [audio * common_gain for audio in variants]
        for slug, variants in families.items()
    }
    if not level_matched:
        return families

    energies = {
        slug: math.sqrt(
            sum(_phone_band_rms(audio) ** 2 for audio in variants) / len(variants)
        )
        for slug, variants in families.items()
    }
    # Use the quietest family as the control target; the matched pass never
    # raises a peak above the already-safe primary export.
    target = min(energies.values())
    return {
        slug: [audio * target / (energies[slug] or 1.0) for audio in variants]
        for slug, variants in families.items()
    }


def render_variants(mechanism: Mechanism, *, level_matched: bool = False) -> list[np.ndarray]:
    return render_families(level_matched=level_matched)[mechanism.slug]


def silence(seconds: float) -> np.ndarray:
    return np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)


def rate_gain(click_index: int, interval_ms: float | None) -> float:
    if click_index <= 0 or interval_ms is None:
        return 1.0
    if interval_ms <= RATE_ENVELOPE["rapid_threshold_ms"]:
        rapid_gains = RATE_ENVELOPE["rapid_gains"]
        return float(rapid_gains[min(click_index, len(rapid_gains) - 1)])
    if interval_ms <= RATE_ENVELOPE["fast_threshold_ms"]:
        return 0.93
    return 1.0


def render_sequence(variants: list[np.ndarray], *, step_seconds: float, count: int, rapid: bool) -> np.ndarray:
    lead_seconds = 0.085
    tail_seconds = 0.170
    total = lead_seconds + step_seconds * (count - 1) + CLICK_SECONDS + tail_seconds
    result = np.zeros(round(total * SAMPLE_RATE), dtype=np.float64)
    for index in range(count):
        variant = variants[VARIANT_WALK[index]]
        # Apple's keyboard precedent lowers frequent click volume subtly as
        # interaction speed increases; keep the attenuation common to every
        # candidate so it cannot bias the mechanism comparison.
        gain = 1.0 if not rapid else rate_gain(index, step_seconds * 1000 if index else None)
        start = round((lead_seconds + index * step_seconds) * SAMPLE_RATE)
        end = min(len(result), start + len(variant))
        result[start:end] += variant[: end - start] * gain
    return result


def render_candidate(variants: list[np.ndarray]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    measured = render_sequence(variants, step_seconds=0.245, count=7, rapid=False)
    rapid = render_sequence(variants, step_seconds=0.105, count=12, rapid=True)
    combined = np.concatenate((silence(0.110), measured, silence(0.390), rapid, silence(0.240)))
    return combined, measured, rapid


def _spectrum_metrics(audio: np.ndarray) -> dict[str, float]:
    if not len(audio) or not np.any(audio):
        return {
            "centroid_hz": 0.0,
            "weight_350_1000hz_pct": 0.0,
            "confirm_1000_2000hz_pct": 0.0,
            "edge_2000_6000hz_pct": 0.0,
            "air_over_8khz_pct": 0.0,
            "spectral_flatness": 0.0,
        }
    # Do not Hann-window an onset-aligned click: a Hann window is zero at the
    # first sample and previously erased the very transient we needed to judge.
    size = 1 << max(1, (len(audio) * 4 - 1).bit_length())
    spectrum = np.abs(np.fft.rfft(audio, n=size)) ** 2
    frequencies = np.fft.rfftfreq(size, 1 / SAMPLE_RATE)
    power = float(np.sum(spectrum)) or 1.0
    flat_band = spectrum[(frequencies >= 250) & (frequencies <= 6_000)]
    floor = max(float(np.max(flat_band)) * 1e-12 if len(flat_band) else 1e-18, 1e-18)
    flatness = (
        float(np.exp(np.mean(np.log(flat_band + floor))) / np.mean(flat_band + floor))
        if len(flat_band)
        else 0.0
    )
    return {
        "centroid_hz": round(float(np.sum(frequencies * spectrum) / power), 2),
        "weight_350_1000hz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 350) & (frequencies < 1_000)])) / power,
            3,
        ),
        "confirm_1000_2000hz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 1_000) & (frequencies < 2_000)])) / power,
            3,
        ),
        "edge_2000_6000hz_pct": round(
            100 * float(np.sum(spectrum[(frequencies >= 2_000) & (frequencies < 6_000)])) / power,
            3,
        ),
        "air_over_8khz_pct": round(
            100 * float(np.sum(spectrum[frequencies >= 8_000])) / power,
            3,
        ),
        "spectral_flatness": round(flatness, 5),
    }


def _window_metrics(audio: np.ndarray, start_ms: float, end_ms: float) -> dict[str, float]:
    start = max(0, round(start_ms / 1000 * SAMPLE_RATE))
    end = min(len(audio), round(end_ms / 1000 * SAMPLE_RATE))
    segment = audio[start:end]
    peak = float(np.max(np.abs(segment))) if len(segment) else 0.0
    rms = float(np.sqrt(np.mean(segment * segment))) if len(segment) else 0.0
    return {
        "start_ms": start_ms,
        "end_ms": end_ms,
        "peak_dbfs": round(20 * math.log10(peak or 1e-12), 3),
        "rms_dbfs": round(20 * math.log10(rms or 1e-12), 3),
        **_spectrum_metrics(segment),
    }


def _metrics(audio: np.ndarray, *, click_aligned: bool = False) -> dict[str, object]:
    peak = float(np.max(np.abs(audio))) or 1e-12
    active = audio[np.abs(audio) >= 10 ** (-60 / 20)]
    if not len(active):
        active = audio
    rms = float(np.sqrt(np.mean(active * active))) or 1e-12
    audible = np.flatnonzero(np.abs(audio) >= 10 ** (-60 / 20))
    tail = audio[-round(0.010 * SAMPLE_RATE):]
    tail_rms = float(np.sqrt(np.mean(tail * tail))) or 1e-12
    spectrum = _spectrum_metrics(audio)
    result: dict[str, object] = {
        "duration_seconds": round(len(audio) / SAMPLE_RATE, 4),
        "peak_dbfs": round(20 * math.log10(peak), 3),
        "active_rms_dbfs": round(20 * math.log10(rms), 3),
        "phone_band_rms_dbfs": round(20 * math.log10(_phone_band_rms(audio) or 1e-12), 3),
        "onset_ms": round(1000 * (int(audible[0]) / SAMPLE_RATE if len(audible) else 0.0), 3),
        "tail_relative_db": round(20 * math.log10(tail_rms / rms), 3),
        "crest_db": round(20 * math.log10(peak / rms), 3),
        "spectrum": spectrum,
    }
    if click_aligned:
        transient = _window_metrics(audio, 0.0, 4.0)
        body = _window_metrics(audio, 4.0, 28.0)
        closure = _window_metrics(audio, 5.0, 10.0)
        tail_start = min(len(audio), round(0.055 * SAMPLE_RATE))
        tail_peak = float(np.max(np.abs(audio[tail_start:]))) if tail_start < len(audio) else 0.0
        contact_rms = 10 ** (float(transient["rms_dbfs"]) / 20)
        body_rms = 10 ** (float(body["rms_dbfs"]) / 20)
        result["transient_0_4ms"] = transient
        result["body_4_28ms"] = body
        result["closure_5_10ms"] = closure
        result["contact_to_body_rms_db"] = round(
            20 * math.log10((contact_rms or 1e-12) / (body_rms or 1e-12)),
            3,
        )
        result["tail_after_55ms_relative_peak_db"] = round(
            20 * math.log10((tail_peak or 1e-12) / peak),
            3,
        )
    return result


def _dither(audio: np.ndarray, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    lsb = 1.0 / (2 ** 23)
    return audio + (rng.random(len(audio)) - rng.random(len(audio))) * lsb * 0.5


def write_wav(path: Path, audio: np.ndarray, *, seed: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, _dither(audio, seed), SAMPLE_RATE, subtype="PCM_24")


def build_study(output: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    variants_root = output / "variants"
    manifest: dict[str, object] = {
        "study": "weighted-click-system-v1",
        "source": {
            "kind": "deterministic procedural synthesis",
            "recorded_foley": False,
            "room_or_reverb": False,
            "recipe": "tool/author_weighted_click_study.py",
        },
        "candidates": [],
        "families": {},
        "rate_envelope": {
            key: list(value) if isinstance(value, tuple) else value
            for key, value in RATE_ENVELOPE.items()
        },
    }
    report: dict[str, object] = {
        "sample_rate_hz": SAMPLE_RATE,
        "sample_format": "PCM_24 mono",
        "click_duration_ms": CLICK_SECONDS * 1000,
        "measured_step_ms": 245,
        "rapid_step_ms": 105,
        "variant_walk": list(VARIANT_WALK),
        "comparison_design": "2x2: light/weighted body x single/two-stage closure",
        "mechanisms": {},
    }
    full_reel: list[np.ndarray] = [silence(0.280)]
    rapid_reel: list[np.ndarray] = [silence(0.210)]
    matched_rapid_reel: list[np.ndarray] = [silence(0.210)]
    families = render_families()
    matched_families = render_families(level_matched=True)

    for mechanism_index, mechanism in enumerate(MECHANISMS):
        variants = families[mechanism.slug]
        matched_variants = matched_families[mechanism.slug]
        variant_paths: list[str] = []
        matched_variant_paths: list[str] = []
        variant_metrics: list[dict[str, object]] = []
        matched_variant_metrics: list[dict[str, object]] = []
        for variant_index, (audio, matched_audio) in enumerate(zip(variants, matched_variants)):
            relative = Path("variants") / f"dak-{mechanism.slug}-{variant_index + 1}.wav"
            write_wav(
                output / relative,
                audio,
                seed=20_262_000 + mechanism_index * 100 + variant_index,
            )
            variant_paths.append(relative.as_posix())
            variant_metrics.append(_metrics(audio, click_aligned=True))
            matched_relative = Path("level-matched") / "variants" / f"dak-{mechanism.slug}-{variant_index + 1}.wav"
            write_wav(
                output / matched_relative,
                matched_audio,
                seed=20_262_500 + mechanism_index * 100 + variant_index,
            )
            matched_variant_paths.append(matched_relative.as_posix())
            matched_variant_metrics.append(_metrics(matched_audio, click_aligned=True))

        combined, measured, rapid = render_candidate(variants)
        matched_combined, _, matched_rapid = render_candidate(matched_variants)
        filename = f"dak-{mechanism.slug}.wav"
        write_wav(output / filename, combined, seed=20_263_000 + mechanism_index)
        matched_filename = Path("level-matched") / filename
        write_wav(output / matched_filename, matched_combined, seed=20_263_500 + mechanism_index)
        full_reel.extend((combined, silence(0.620)))
        rapid_reel.extend((rapid, silence(0.420)))
        matched_rapid_reel.extend((matched_rapid, silence(0.420)))
        manifest["candidates"].append({
            "id": f"dak-{mechanism.slug}",
            "role": "repeated_weighted_contact",
            "path": filename,
        })
        manifest["families"][f"dak-{mechanism.slug}"] = {
            "variant_paths": variant_paths,
            "level_matched_variant_paths": matched_variant_paths,
            "no_immediate_repeat": True,
            "rapid_gain_scale": [1.0, 0.93, 0.885],
        }
        report["mechanisms"][mechanism.slug] = {
            "recipe": asdict(mechanism),
            "combined": _metrics(combined),
            "measured": _metrics(measured),
            "rapid": _metrics(rapid),
            "variants": variant_metrics,
            "level_matched": {
                "combined": _metrics(matched_combined),
                "rapid": _metrics(matched_rapid),
                "variants": matched_variant_metrics,
            },
        }

    write_wav(output / "weighted-click-full-reel.wav", np.concatenate(full_reel), seed=20_264_001)
    write_wav(output / "weighted-click-rapid-reel.wav", np.concatenate(rapid_reel), seed=20_264_002)
    write_wav(
        output / "level-matched" / "weighted-click-rapid-reel.wav",
        np.concatenate(matched_rapid_reel),
        seed=20_264_003,
    )
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "metrics.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output), indent=2))


if __name__ == "__main__":
    main()
