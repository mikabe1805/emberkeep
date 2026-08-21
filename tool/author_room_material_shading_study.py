#!/usr/bin/env python3
"""Author the Room of Days material-shading audition (room-material-shading-v1).

Owner direction (2026-08-21, verbatim): "when im clicking around i want the
interactable surfaces to feel like different 'textures' of sound and
interaction, so maybe buttons should feel more like stone slates and have a
satisfying 'dak' sound and flipping between the pages is a different sound and
tapping around is the current sound".

History this must honor:
  • The earlier literal-Foley material family was vetoed twice ("recorded in a
    really old recording studio", "not fresh and satisfying"); the family that
    finally passed the phone gate is SYNTHESIZED — the approved C contact +
    modal body + close room fingerprint. So materials here are SHADINGS of
    that engine, never sample swaps: same contact master, same reflection
    fingerprint, same D-major pentatonic tokens, same take discipline.
  • Minecraft is the owner's named reference for material-follows-surface;
    the lesson taken is the SYSTEM (material lanes + takes + variation), not
    recorded sourcing.
  • The wood clasp stays untouched as the everyday baseline ("tapping around
    is the current sound") — it is rendered here only as the A/B anchor.

Lanes (material x verb), matching where each texture will be wired:
  slate  : select / place / navigate — faceted stone-cut buttons and commits;
           the satisfying weighted "dak": heavier double contact, stiffer
           denser body, mineral grain, shorter ring than wood.
  page   : navigate / open — moving between tabs, journal pages, calendar
           modes; a parchment flick: noise-led slide that LANDS on a soft
           contact carrying the field note, so page turns keep the melodic
           walk alive.
  glass  : select / place — glass switches and cosmetic/preview surfaces;
           one small damped bright-side mode pair, never piercing.
  brass  : select / place — precious commits (purchase, keepsake, share);
           a felt-muted dyad with a slow warm beat, rare by design.

Each lane renders 3 takes on the world's pitch tokens (d/e/a) — the same
global-phrase variant axis as the shipped clasps, so material never breaks
the no-repeat walk or the Paired Return grammar.

Nothing is written to runtime assets. Output lands under design/audits.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

import author_room_sonic_world_study as world

SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-material-shading-v1"
RENDER_VERSION = "room-material-author-v1"

# --polish (render-polish-v2): identical gestures; only the render artifacts
# the owner flagged change — quieter modal excitation beds, a narrower and
# shorter mineral grain, and a page flick rebuilt from fiber crackle over a
# reduced noise wash instead of pure filtered noise ("swish").
POLISH = False


def _enable_polish() -> None:
    global POLISH, STUDY_ID, RENDER_VERSION
    POLISH = True
    STUDY_ID = "room-material-shading-v2-polish"
    RENDER_VERSION = "room-material-author-v2-polish"
    orig_modal = world._modal_body

    def quiet_modal(*args, **kwargs):
        kwargs.setdefault("excitation_gain", 0.09)
        return orig_modal(*args, **kwargs)

    world._modal_body = quiet_modal

# Phone-band RMS ladder. Slate marks commitment so it sits a step above the
# wood clasp's matching verbs; page is a view change, mid-quiet; glass and
# brass are small and rare. (Wood reference: open -30.0 / select -29.2 /
# navigate -28.2 / place -27.6 dBFS.)
LANE_TARGET_DBFS = {
    ("slate", "select"): -28.6,
    ("slate", "navigate"): -27.6,
    ("slate", "place"): -27.0,
    ("page", "navigate"): -28.8,
    ("page", "open"): -29.4,
    ("glass", "select"): -29.6,
    ("glass", "place"): -29.0,
    ("brass", "select"): -29.2,
    ("brass", "place"): -28.4,
}

LANE_DURATIONS = {
    ("slate", "select"): 0.060,
    ("slate", "navigate"): 0.074,
    ("slate", "place"): 0.104,
    ("page", "navigate"): 0.112,
    ("page", "open"): 0.096,
    ("glass", "select"): 0.058,
    ("glass", "place"): 0.084,
    ("brass", "select"): 0.088,
    ("brass", "place"): 0.118,
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _seed(material: str, verb: str, token_index: int, part: int) -> int:
    # zlib.crc32 is stable across processes; Python's hash() is salted and
    # would break byte-identical regeneration.
    import zlib
    key = f"{material}/{verb}/{token_index}/{part}".encode()
    return zlib.crc32(key) % 100_000 + 10_000


def _mineral_grain(seconds: float, seed: int, low_hz: float, high_hz: float,
                   decay_ms: float) -> np.ndarray:
    """Stone's identity lives in a dense correlated grain, not a longer ring:
    band-passed noise with a fast body-coupled decay."""
    frames = round(seconds * SAMPLE_RATE)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    grain = world._bandpass(
        np.random.default_rng(seed).standard_normal(frames), low_hz, high_hz,
        order=2,
    )
    grain = world._normalize_peak(grain)
    attack = 1.0 - np.exp(-t / 0.00040)
    return grain * attack * np.exp(-t / (decay_ms / 1000))


def _stiff_body(root_hz: float, seconds: float, decay_ms: float, *,
                seed: int) -> np.ndarray:
    """A slate plate: stiffer, denser mode stack than the wood bank — the
    free-plate-like ratio set from the material-perception literature
    (Aramaki/Giordano: identity = frequency-dependent damping + density),
    with fast upper decay. This is weight-and-grain shading of the approved
    gesture, NOT mineral realism — the owner's standing correction: "im not
    looking for stone on stone sound system"."""
    frames = round(seconds * SAMPLE_RATE)
    t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
    attack = 1.0 - np.exp(-t / 0.00045)
    ratios = (1.0, 1.52, 1.94, 2.71)
    amplitudes = (0.46, 0.28, 0.16, 0.07)
    decay_scales = (1.0, 0.64, 0.42, 0.27)
    phases = (0.21, 1.03, 1.96, 2.61)
    body = np.zeros(frames, dtype=np.float64)
    for ratio, amplitude, decay_scale, phase in zip(
        ratios, amplitudes, decay_scales, phases
    ):
        body += (
            amplitude
            * np.sin(2 * math.pi * root_hz * ratio * t + phase)
            * attack
            * np.exp(-t / ((decay_ms / 1000) * decay_scale))
        )
    body = world._filter(body, highpass_hz=210, lowpass_hz=4_600, order=3)
    return world._normalize_peak(body)


def _page_gesture(seconds: float, *, seed: int, flick_hz: tuple[float, float],
                  land_at: float) -> np.ndarray:
    """The parchment flick: two noise grains whose band centre travels, then
    silence-shaped release into the landing beat. No pitch of its own.
    In polish mode the steady wash drops and a run of fiber micro-crackles
    carries the paper identity — a flip is many tiny snaps, not a swish."""
    frames = round(seconds * SAMPLE_RATE)
    rng = np.random.default_rng(seed)
    gesture = np.zeros(frames, dtype=np.float64)
    wash_a, wash_b = (0.52, 0.28) if POLISH else (0.8, 0.42)
    first = round(frames * 0.52)
    grain_a = world._bandpass(rng.standard_normal(first), flick_hz[0],
                              flick_hz[0] * 2.6, order=2)
    grain_a *= np.hanning(first) ** 1.35
    world._place(gesture, world._normalize_peak(grain_a), 0.0, wash_a)
    second = round(frames * 0.40)
    grain_b = world._bandpass(rng.standard_normal(second), flick_hz[1],
                              flick_hz[1] * 2.3, order=2)
    grain_b *= np.hanning(second) ** 1.2
    world._place(gesture, world._normalize_peak(grain_b),
                 max(0.0, land_at - second / SAMPLE_RATE * 0.55), wash_b)
    if POLISH:
        # fiber crackle: ~14 micro-snaps whose density and level follow the
        # flick, each a 1.5 ms band-passed ping
        snap_len = round(0.0015 * SAMPLE_RATE)
        window = np.hanning(snap_len)
        span = max(land_at, 0.02)
        for index in range(14):
            u = rng.random() ** 0.62          # densify toward the release
            at = u * span
            ping = world._bandpass(rng.standard_normal(snap_len),
                                   900, 2_600, order=2)
            level = 0.10 + 0.16 * u
            world._place(gesture, world._normalize_peak(ping) * window,
                         at, level)
    return gesture


def _lane_stems(material: str, verb: str, token: dict[str, float | str],
                token_index: int, contact: np.ndarray) -> tuple[np.ndarray, float]:
    seconds = LANE_DURATIONS[(material, verb)]
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    root = float(token["root_hz"])
    up = float(token["up_hz"])
    down = float(token["down_hz"])

    if material == "slate":
        # The dak: heavier double contact into a stiff plate with mineral
        # grain. Livelier through weight and grain, never brightness.
        world._place(stem, contact, 0.0, 1.0)
        world._place(stem, contact, 0.005, 0.34)
        grain_lo, grain_hi, grain_decay, grain_gain = (
            (500, 1_900, 7.0, 0.26) if POLISH else (420, 2_600, 9.5, 0.30)
        )
        grain = _mineral_grain(min(seconds, 0.030),
                               _seed(material, verb, token_index, 1),
                               grain_lo, grain_hi, grain_decay)
        world._place(stem, grain, 0.0006, grain_gain)
        if verb == "select":
            world._place(stem, _stiff_body(root, seconds, 15,
                                           seed=_seed(material, verb, token_index, 2)),
                         0.001, 0.24)
            send = 0.78
        elif verb == "navigate":
            world._place(stem, _stiff_body(root, seconds, 19,
                                           seed=_seed(material, verb, token_index, 2)),
                         0.001, 0.27)
            world._place(stem, _stiff_body(down, seconds - 0.012, 13,
                                           seed=_seed(material, verb, token_index, 3)),
                         0.012, 0.12)
            send = 0.88
        else:  # place — the committed seat: a third settle contact, low anchor
            world._place(stem, contact, 0.021, 0.16)
            world._place(stem, _stiff_body(down, seconds, 26,
                                           seed=_seed(material, verb, token_index, 2)),
                         0.001, 0.30)
            world._place(stem, _stiff_body(max(root / 2, 293.665),
                                           seconds - 0.021, 21,
                                           seed=_seed(material, verb, token_index, 3)),
                         0.021, 0.15)
            send = 0.96
    elif material == "page":
        land_at = seconds * (0.56 if verb == "navigate" else 0.50)
        world._place(stem, _page_gesture(seconds,
                                         seed=_seed(material, verb, token_index, 1),
                                         flick_hz=(620.0, 940.0),
                                         land_at=land_at), 0.0, 0.62)
        # the page lands: a soft contact carrying the field note, so tabs and
        # pages keep feeding the global melodic walk
        world._place(stem, contact, land_at, 0.5)
        world._place(stem, world._modal_body(root, seconds - land_at, 16,
                                             seed=_seed(material, verb, token_index, 2)),
                     land_at + 0.001, 0.14)
        send = 0.84
    elif material == "glass":
        # Glass reads as glass in the 1.0-2.6 kHz band (Aramaki's stimuli sat
        # at C5-C6), so the body lives an OCTAVE above the token — same pitch
        # class, so the field survives — sparse, clean, quickly damped.
        world._place(stem, contact, 0.0, 0.72)
        body = world._modal_body(up * 2, seconds, 22 if verb == "select" else 30,
                                 seed=_seed(material, verb, token_index, 2),
                                 drift_cents=-4)
        body = world._filter(body, highpass_hz=650, lowpass_hz=4_800, order=2)
        world._place(stem, body, 0.001, 0.20 if verb == "select" else 0.24)
        if verb == "place":
            world._place(stem, world._modal_body(root, seconds - 0.016, 22,
                                                 seed=_seed(material, verb, token_index, 3)),
                         0.016, 0.11)
        send = 0.74
    elif material == "brass":
        world._place(stem, contact, 0.0, 0.80)
        frames = len(stem)
        t = np.arange(frames, dtype=np.float64) / SAMPLE_RATE
        decay = 0.052 if verb == "select" else 0.070
        # brass = density + roughness: a slow beat inside the critical band
        # plus 1.5 and 2.0 partials — felt-muted, never a chime
        dyad = (
            0.30 * np.sin(2 * math.pi * root * t + 0.31)
            + 0.24 * np.sin(2 * math.pi * root * 1.007 * t + 1.12)
            + 0.12 * np.sin(2 * math.pi * root * 1.5 * t + 2.02)
            + 0.07 * np.sin(2 * math.pi * root * 2.0 * t + 0.77)
        )
        dyad *= (1.0 - np.exp(-t / 0.0009)) * np.exp(-t / decay)
        dyad = world._filter(dyad, highpass_hz=250, lowpass_hz=3_800, order=3)
        world._place(stem, world._normalize_peak(dyad), 0.002,
                     0.24 if verb == "select" else 0.28)
        if verb == "place":
            world._place(stem, contact, 0.024, 0.14)
        send = 0.90
    else:
        raise ValueError(f"unknown material: {material}")

    release = min(len(stem), round(0.014 * SAMPLE_RATE))
    stem[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    return stem, send


def _calibrate(audio: np.ndarray, target_dbfs: float) -> np.ndarray:
    gain = world._db(target_dbfs) / max(world._phone_rms(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _render_lane(material: str, verb: str,
                 contact: np.ndarray) -> list[np.ndarray]:
    takes: list[np.ndarray] = []
    for token_index, token in enumerate(world.PITCH_TOKENS):
        stem, send = _lane_stems(material, verb, token, token_index, contact)
        wet = world._park(world._room_bus(stem, send), 6.0)
        takes.append(_calibrate(wet, LANE_TARGET_DBFS[(material, verb)]))
    return takes


def _click_around(roles: dict[str, list[np.ndarray]],
                  lanes: dict[tuple[str, str], list[np.ndarray]],
                  *, shaded: bool) -> np.ndarray:
    """A natural browse: tap around lists (wood), flip a page, press a slate
    button, flick a toggle, seat a commit — the exact 'clicking around' the
    owner described, with and without material shading."""
    def pick(material: str, verb: str, take: int) -> np.ndarray:
        if shaded and (material, verb) in lanes:
            return lanes[(material, verb)][take % 3]
        return roles[verb][take % 3]

    timeline = [
        (0.30, ("wood", "open", 0)),
        (0.92, ("wood", "select", 1)),
        (1.48, ("page", "navigate", 2)),
        (2.30, ("wood", "open", 1)),
        (2.86, ("slate", "select", 0)),
        (3.42, ("glass", "select", 2)),
        (4.04, ("wood", "select", 2)),
        (4.66, ("page", "navigate", 0)),
        (5.44, ("slate", "place", 1)),
    ]
    result = np.zeros(round(6.40 * SAMPLE_RATE), dtype=np.float64)
    for at, (material, verb, take) in timeline:
        world._place(result, pick(material, verb, take), at)
    return result


def _reel(items: list[np.ndarray], spacing: float = 0.42) -> np.ndarray:
    length = spacing * max(0, len(items) - 1) + max(
        (len(item) for item in items), default=0
    ) / SAMPLE_RATE + 0.15
    reel = np.zeros(round(length * SAMPLE_RATE), dtype=np.float64)
    for index, audio in enumerate(items):
        world._place(reel, audio, index * spacing)
    return reel


def build_study(output: Path, room_root: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    contact_path = room_root / "shared" / "contact-master.wav"
    if not contact_path.exists():
        raise FileNotFoundError(contact_path)
    contact = world._fit(world._read_mono(contact_path), 0.014)
    roles = {
        role: [world._read_mono(room_root / "roles" / role / f"{index}.wav")
               for index in range(1, 4)]
        for role in ("open", "select", "navigate", "place")
    }

    lanes: dict[tuple[str, str], list[np.ndarray]] = {}
    lane_manifest: dict[str, object] = {}
    for (material, verb), target in LANE_TARGET_DBFS.items():
        takes = _render_lane(material, verb, contact)
        lanes[(material, verb)] = takes
        paths = []
        for index, take in enumerate(takes):
            path = output / "materials" / material / verb / f"{index + 1}.wav"
            world._write(path, take)
            paths.append(path.relative_to(output).as_posix())
        lane_manifest[f"{material}/{verb}"] = {
            "take_paths": paths,
            "duration_ms": LANE_DURATIONS[(material, verb)] * 1000,
            "natural_phone_rms_target_dbfs": target,
            "wood_anchor": f"roles/{verb}",
        }

    # per-material identity reels (3 takes each of its lanes), wood anchor first
    for material in ("slate", "page", "glass", "brass"):
        material_lanes = [takes for (m, _v), takes in lanes.items() if m == material]
        world._write(output / "reels" / f"{material}.wav",
                     _reel([take for takes in material_lanes for take in takes]))
    world._write(output / "reels" / "wood-anchor.wav",
                 _reel([roles[verb][0] for verb in ("open", "select",
                                                    "navigate", "place")]))

    # the decisive comparison: the same browse, unshaded vs shaded
    world._write(output / "flows" / "click-around-current.wav",
                 _click_around(roles, lanes, shaded=False))
    world._write(output / "flows" / "click-around-shaded.wav",
                 _click_around(roles, lanes, shaded=True))

    locked_paths = [room_root / "roles" / role / f"{index}.wav"
                    for role in ("open", "select", "navigate", "place")
                    for index in range(1, 4)]
    manifest = {
        "study": STUDY_ID,
        "question": ("Does clicking around finally feel like touching different"
                     " textures in one room — and does each material read as"
                     " itself on the phone speaker?"),
        "runtime_changed": False,
        "owner_feedback_source": {
            "date": "2026-08-21",
            "verbatim": ("when im clicking around i want the interactable"
                         " surfaces to feel like different \"textures\" of"
                         " sound and interaction, so maybe buttons should feel"
                         " more like stone slates and have a satisfying \"dak\""
                         " sound and flipping between the pages is a different"
                         " sound and tapping around is the current sound etc"),
        },
        "render_contract": {
            "render_version": RENDER_VERSION,
            "contact_master_id": world.CONTACT_MASTER_ID,
            "space_fingerprint_id": world.SPACE_MASTER_ID,
            "pitch_field": "D-major pentatonic tokens (d/e/a), same walk axis",
            "material_axis": ("body/grain shading of the one approved"
                              " mechanism — never sample replacement"),
            "lane_targets_dbfs": {f"{m}/{v}": t
                                  for (m, v), t in LANE_TARGET_DBFS.items()},
        },
        "lanes": lane_manifest,
        "locked_everyday_family": {
            "source_study": str(room_root.resolve()),
            "source_hashes": {str(path.resolve()): _sha256(path)
                              for path in locked_paths},
        },
        "provenance": {
            "reference_video_audio_used": False,
            "shipping_assets_changed": False,
        },
        "generated_audio_sha256": {
            path.relative_to(output).as_posix(): _sha256(path)
            for path in sorted(output.rglob("*.wav"))
        },
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--room-study", type=Path, required=True)
    parser.add_argument("--polish", action="store_true")
    args = parser.parse_args()
    if args.polish:
        _enable_polish()
    print(json.dumps(build_study(args.output, args.room_study), indent=2))


if __name__ == "__main__":
    main()
