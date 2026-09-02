"""room-music-v1 — quiet beds for the room, grown from the sonic world.

Owner signal (2026-08-29, verbatim): "to be fair that fire thing was because
that fire sound on repeat was annoying, ambience definitely feels a little
sparse right now" — repetition was the veto, not ambience itself — and, of
the proposed direction (sparse never-repeating D-pentatonic music from the
world modules, taps landing in tune): "im very impressed and totally agree
with the direction you proposed".

Four 96-second candidate beds, every pitched element on the D-major
pentatonic field through the shared modal bank and room fingerprint, so the
interaction sounds are consonant with the bed by construction. No sample is
imported; no phrase repeats inside a render (generative placement, seeded);
the Paired Return motif (D5 A5 E5 D5) is explicitly excluded so the easter
egg stays rare.

Musical notes differ from interaction strikes on purpose: each modal body is
given a soft bloom attack (12-35 ms) in place of the 0.55 ms contact snap,
longer decays, and a per-note excitation bed of 0.025 (far under the 0.09
event discipline — a bed's noise budget is per MINUTE, not per note; §8).

Candidates are level-matched at -36.0 dBFS phone-band RMS — a deliberate
floor under the interaction ladder (open -30.0 … levelup -24.8) so an
earned sound always owns the air. The in-app level is a later dial; the
audition judges character, not loudness. Candidate wavs are PCM_16 (a 96 s
bed at -36 dBFS needs no 24-bit headroom, and the audition page stays
phone-light); the manifest records every hash.

Run from the repo root:

    python tool/author_room_music_study.py \
        --output design/audits/2026-08-29/room-music-v1
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-music-v1"
RENDER_VERSION = "room-music-author-v1"

BED_SECONDS = 96.0
FLOW_SECONDS = 16.0
TARGET_DBFS = -36.0
EXCITATION = 0.025  # per-note; a bed's noise budget is per minute (§8)
PHRASE_SEND = 0.85 * 0.8  # phrases through the room, event-trimmed
DRONE_SEND = 0.40  # the drone barely touches the reflections

WORLD_ROOT = Path("design/audits/2026-08-20/room-sonic-world-v1")

# D-major pentatonic, spelled exactly as the sibling studies spell it.
D3, A3 = 146.8325, 220.000
D4, E4, FS4, A4, B4 = 293.665, 329.628, 369.994, 440.000, 493.883
D5, E5, FS5, A5, B5 = 587.330, 659.255, 739.989, 880.000, 987.767
SCALE = (D4, E4, FS4, A4, B4, D5, E5, FS5, A5, B5)
STABLE = {0, 3, 5, 8}  # D4, A4, D5, A5 — phrases resolve here
PAIRED_RETURN = (D5, A5, E5, D5)  # never emit the easter egg's motif


def _fresh_rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _note(
    hz: float,
    seconds: float,
    decay_ms: float,
    *,
    seed: int,
    bloom_s: float,
    drift_cents: float,
) -> np.ndarray:
    """A musical body: the world's modal voice with a soft bloom attack."""
    body = world._modal_body(
        hz,
        seconds,
        decay_ms,
        seed=seed,
        low_support=hz < 340.0,
        drift_cents=drift_cents,
        excitation_gain=EXCITATION,
    )
    t = np.arange(len(body)) / SAMPLE_RATE
    return body * (1.0 - np.exp(-t / max(bloom_s, 1e-4)))


def _drone(seconds: float, rng: np.random.Generator, layers) -> np.ndarray:
    """Warm mid-band air: detuned sine pairs breathing on unrelated slow
    cycles. Pure tones only — a drone with a noise bed is a hiss floor."""
    frames = round(seconds * SAMPLE_RATE)
    t = np.arange(frames) / SAMPLE_RATE
    out = np.zeros(frames)
    for hz, gain in layers:
        detune = 1.0 + rng.uniform(0.0035, 0.0060)
        phase_a, phase_b = rng.uniform(0, 2 * math.pi, size=2)
        pair = 0.5 * (
            np.sin(2 * math.pi * hz * t + phase_a)
            + np.sin(2 * math.pi * hz * detune * t + phase_b)
        )
        breath_rate = rng.uniform(0.008, 0.030)  # 33-125 s cycles
        breath_phase = rng.uniform(0, 2 * math.pi)
        breath = 0.55 + 0.45 * np.sin(2 * math.pi * breath_rate * t + breath_phase)
        out += pair * breath * gain
    swell = 1.0 - np.exp(-t / 6.0)  # the room fades up over ~6 s, never pops on
    out *= swell
    return world._filter(out, highpass_hz=120, lowpass_hz=2_600, order=2)


def _walk_phrase(rng: np.random.Generator, length: int, lo: int, hi: int, rise_bias: float):
    """A stepwise pentatonic walk that arcs and resolves on D or A."""
    while True:
        idx = int(rng.integers(lo, hi + 1))
        degrees = [idx]
        for step_at in range(length - 1):
            first_half = step_at < (length - 1) / 2
            bias = rise_bias if first_half else -rise_bias
            r = rng.random()
            if r < 0.32 + bias:
                idx += 1
            elif r < 0.64:
                idx -= 1
            elif r < 0.76:
                idx += 2 if rng.random() < 0.5 + bias else -2
            elif r < 0.82:
                pass  # repeated tone
            else:
                idx += int(rng.integers(-3, 4))
            idx = max(lo, min(hi, idx))
            degrees.append(idx)
        # land somewhere stable inside the register
        stable = sorted(s for s in STABLE if lo <= s <= hi) or [lo]
        degrees[-1] = min(stable, key=lambda s: abs(s - degrees[-1]))
        tones = tuple(SCALE[d] for d in degrees)
        if tones[-4:] != PAIRED_RETURN and tones[:4] != PAIRED_RETURN:
            return degrees


def _place_phrase(
    stem: np.ndarray,
    contact: np.ndarray | None,
    rng: np.random.Generator,
    *,
    at: float,
    degrees,
    seconds_total: float,
    spacing: tuple[float, float],
    decay: tuple[float, float],
    gain: float,
    seed_base: int,
    note_index: int,
) -> tuple[float, int]:
    """Schedule one phrase; returns (end_time, next_note_index)."""
    t = at
    for i, degree in enumerate(degrees):
        hz = SCALE[degree]
        last = i == len(degrees) - 1
        decay_ms = rng.uniform(*decay) * (1.4 if last else 1.0)
        remaining = max(seconds_total - t - 0.05, 0.4)
        dur = min(decay_ms / 1000.0 * 4.0, remaining)
        vel = rng.uniform(0.55, 1.0)
        if contact is not None and i == 0:
            world._place(stem, contact, t, 0.05 * vel)
        world._place(
            stem,
            _note(
                hz,
                dur,
                decay_ms,
                seed=seed_base + note_index * 17,
                bloom_s=rng.uniform(0.012, 0.035),
                drift_cents=rng.uniform(-5.0, 3.0),
            ),
            t + 0.002,
            gain * vel,
        )
        note_index += 1
        if not last:
            t += rng.uniform(*spacing)
    return t, note_index


def _calibrate(audio: np.ndarray, target_dbfs: float) -> np.ndarray:
    gain = world._db(target_dbfs) / max(world._phone_rms(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _finish(audio: np.ndarray, fade_seconds: float = 0.4) -> np.ndarray:
    tail = audio[-round(0.004 * SAMPLE_RATE):]
    if len(tail):
        audio = audio - float(np.mean(tail))
    fade = round(fade_seconds * SAMPLE_RATE)
    if fade and len(audio) > fade:
        audio[-fade:] *= np.cos(np.linspace(0, math.pi / 2, fade)) ** 2
    return audio


def _write_16(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(audio))) if len(audio) else 0.0
    if peak >= 1.0:
        audio = audio * (world._db(-0.3) / peak)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_16")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


# ── the four beds ──────────────────────────────────────────────────────


def _render_room_air(contact: np.ndarray) -> tuple[np.ndarray, int]:
    """Drone only — is what's missing music, or just air?"""
    rng = _fresh_rng(12_100)
    drone = _drone(
        BED_SECONDS,
        rng,
        [(D3, 0.30), (A3, 0.34), (D4, 0.30), (A4, 0.10)],
    )
    return world._room_bus(drone, DRONE_SEND), 0


def _render_hearthside(contact: np.ndarray) -> tuple[np.ndarray, int]:
    """The room hums, and very occasionally says something low."""
    rng = _fresh_rng(12_200)
    drone = _drone(
        BED_SECONDS,
        rng,
        [(D3, 0.28), (A3, 0.32), (D4, 0.26), (FS4, 0.08)],
    ) * 0.85
    stem = np.zeros(round(BED_SECONDS * SAMPLE_RATE))
    t = rng.uniform(8.0, 14.0)
    note_index = 0
    phrases = 0
    while t < BED_SECONDS - 10.0:
        degrees = _walk_phrase(rng, int(rng.integers(2, 5)), 0, 4, rise_bias=0.04)
        t, note_index = _place_phrase(
            stem, None, rng,
            at=t, degrees=degrees, seconds_total=BED_SECONDS,
            spacing=(0.55, 1.05), decay=(2000.0, 3000.0), gain=0.16,
            seed_base=12_210, note_index=note_index,
        )
        phrases += 1
        t += rng.uniform(22.0, 38.0)
    return world._room_bus(stem, PHRASE_SEND) + world._room_bus(drone, DRONE_SEND), phrases


def _render_emberlight(contact: np.ndarray) -> tuple[np.ndarray, int]:
    """A low statement, then a soft high answer — call and response."""
    rng = _fresh_rng(12_300)
    drone = _drone(
        BED_SECONDS,
        rng,
        [(D3, 0.26), (A3, 0.30), (D4, 0.24), (A4, 0.09)],
    ) * 0.70
    stem = np.zeros(round(BED_SECONDS * SAMPLE_RATE))
    t = rng.uniform(6.0, 11.0)
    note_index = 0
    phrases = 0
    while t < BED_SECONDS - 12.0:
        low = _walk_phrase(rng, int(rng.integers(2, 4)), 0, 4, rise_bias=0.05)
        t, note_index = _place_phrase(
            stem, None, rng,
            at=t, degrees=low, seconds_total=BED_SECONDS,
            spacing=(0.50, 0.95), decay=(1800.0, 2600.0), gain=0.16,
            seed_base=12_310, note_index=note_index,
        )
        t += rng.uniform(1.4, 2.6)
        high = _walk_phrase(rng, int(rng.integers(1, 3)), 5, 9, rise_bias=0.0)
        t, note_index = _place_phrase(
            stem, None, rng,
            at=t, degrees=high, seconds_total=BED_SECONDS,
            spacing=(0.45, 0.80), decay=(700.0, 1100.0), gain=0.10,
            seed_base=12_330, note_index=note_index,
        )
        phrases += 1
        t += rng.uniform(16.0, 30.0)
    return world._room_bus(stem, PHRASE_SEND) + world._room_bus(drone, DRONE_SEND), phrases


def _render_wander(contact: np.ndarray) -> tuple[np.ndarray, int]:
    """The calm-adventury one: lighter air, walking phrases, octave echoes."""
    rng = _fresh_rng(12_400)
    drone = _drone(
        BED_SECONDS,
        rng,
        [(D3, 0.24), (A3, 0.28), (D4, 0.22), (A4, 0.08)],
    ) * 0.55
    stem = np.zeros(round(BED_SECONDS * SAMPLE_RATE))
    t = rng.uniform(5.0, 9.0)
    note_index = 0
    phrases = 0
    echo_ok = True
    while t < BED_SECONDS - 12.0:
        degrees = _walk_phrase(rng, int(rng.integers(3, 7)), 0, 9, rise_bias=0.10)
        end, note_index = _place_phrase(
            stem, contact, rng,
            at=t, degrees=degrees, seconds_total=BED_SECONDS,
            spacing=(0.40, 0.85), decay=(1400.0, 2200.0), gain=0.15,
            seed_base=12_410, note_index=note_index,
        )
        if echo_ok and rng.random() < 0.5 and degrees[-1] + 5 <= 9:
            world._place(
                stem,
                _note(
                    SCALE[degrees[-1] + 5],
                    2.2,
                    rng.uniform(750.0, 1000.0),
                    seed=12_490 + note_index * 17,
                    bloom_s=0.020,
                    drift_cents=rng.uniform(-4.0, 2.0),
                ),
                end + 0.9,
                0.05,
            )
            echo_ok = False
        else:
            echo_ok = True
        phrases += 1
        t = end + rng.uniform(11.0, 22.0)
    return world._room_bus(stem, PHRASE_SEND) + world._room_bus(drone, DRONE_SEND), phrases


# ── flows: the bed underneath real interaction masters ─────────────────


def _flow(bed: np.ndarray, roles: dict[str, np.ndarray]) -> np.ndarray:
    frames = round(FLOW_SECONDS * SAMPLE_RATE)
    out = bed[:frames].copy()
    for at, role in (
        (1.2, "navigate"), (3.0, "open"), (5.2, "select"),
        (7.4, "place"), (9.8, "select"), (12.2, "navigate"),
    ):
        world._place(out, roles[role], at, 1.0)
    return _finish(out, 0.5)


def build_study(output: Path, world_root: Path) -> dict[str, object]:
    contact_path = world_root / "shared" / "contact-master.wav"
    contact = world._fit(world._read_mono(contact_path), 0.014)
    roles = {}
    for role in ("navigate", "open", "select", "place"):
        role_path = world_root / "roles" / role / "1.wav"
        if not role_path.exists():
            raise FileNotFoundError(f"world role master missing: {role_path}")
        roles[role] = world._read_mono(role_path)

    renderers = {
        "room-air": _render_room_air,
        "hearthside": _render_hearthside,
        "emberlight": _render_emberlight,
        "wander": _render_wander,
    }
    manifest: dict[str, object] = {
        "study": STUDY_ID,
        "render_version": RENDER_VERSION,
        "world_root": world_root.as_posix(),
        "contact_master": contact_path.as_posix(),
        "contact_master_sha256": _sha256(contact_path),
        "role_sources": {
            role: {"path": (world_root / "roles" / role / "1.wav").as_posix(),
                   "sha256": _sha256(world_root / "roles" / role / "1.wav")}
            for role in roles
        },
        "target_phone_band_dbfs": TARGET_DBFS,
        "excitation_gain_per_note": EXCITATION,
        "seed_block": "12100-12500",
        "sample_format": "PCM_16",
        "candidates": {},
    }

    for name, renderer in renderers.items():
        bed, phrases = renderer(contact)
        bed = _finish(_calibrate(bed, TARGET_DBFS))
        candidate_path = output / "candidates" / f"{name}.wav"
        _write_16(candidate_path, bed)
        flow_path = output / "flows" / f"{name}-flow.wav"
        _write_16(flow_path, _flow(bed, roles))
        manifest["candidates"][name] = {  # type: ignore[index]
            "sha256": _sha256(candidate_path),
            "flow_sha256": _sha256(flow_path),
            "seconds": round(len(bed) / SAMPLE_RATE, 4),
            "peak": round(float(np.max(np.abs(bed))), 6),
            "phone_band_rms_dbfs": round(
                20 * math.log10(max(world._phone_rms(bed), 1e-12)), 2
            ),
            "phrase_count": phrases,
        }

    manifest_path = output / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--world-study", type=Path, default=WORLD_ROOT)
    args = parser.parse_args()
    manifest = build_study(args.output, args.world_study)
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
