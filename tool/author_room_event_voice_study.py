#!/usr/bin/env python3
"""Author the Room of Days event-voice audition (round: room-event-voice-v1).

The accepted everyday X family, Paired Return, and completion composite are
immutable inputs. This study re-voices the LAST remaining Gen-1 palette — the
event sounds that still ship as bare sine blips from a different acoustic
world: streak, crit, loot, levelup, boing, and the six stat tones.

Owner feedback driving it (2026-08-21): tapping around "all just sounds like
the same popping sound that feels like a popping bubbles stim toy … not
polished and expensive". The everyday tier already passed its phone gates; the
bubble-toy read is strongest where a clasp world collides with legacy sine
bloops every time an outcome lands. Every candidate here therefore inherits
the Room contact master, modal body bank, D-major pentatonic field, and close
reflection fingerprint — the same derivation chain as the shipped clasps.

Like the approved Room masters, candidates carry their intended phone level in
the file; if a candidate ships, its `Sfx._volume` entry moves to 1.0.

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
STUDY_ID = "room-event-voice-v1"
RENDER_VERSION = "room-event-author-v1"

# --polish (render-polish-v2): identical gestures, notes, and weights; only
# the render artifacts the owner flagged ("low quality recording vibe",
# 2026-08-21) change — each stacked modal body carries far less of its own
# excitation-noise bed, and the reflection send on long events is trimmed so
# the room fingerprint stays subliminal. Activated via monkeypatched world
# helpers so every gesture recipe below stays byte-identical in source.
POLISH = False


def _enable_polish() -> None:
    global POLISH, STUDY_ID, RENDER_VERSION
    POLISH = True
    STUDY_ID = "room-event-voice-v2-polish"
    RENDER_VERSION = "room-event-author-v2-polish"
    orig_modal = world._modal_body
    orig_bus = world._room_bus

    def quiet_modal(*args, **kwargs):
        kwargs.setdefault("excitation_gain", 0.09)
        return orig_modal(*args, **kwargs)

    def trimmed_bus(dry, send):
        return orig_bus(dry, send * 0.8)

    world._modal_body = quiet_modal
    world._room_bus = trimmed_bus

# D-major pentatonic field, low octave to the crown.
D4, E4, FS4, A4, B4 = 293.665, 329.628, 369.994, 440.000, 493.883
D5, E5, A5 = 587.330, 659.255, 880.000

# Natural phone-band RMS ladder, extending the world's role ladder. The stat
# tick is the quietest event; levelup is the largest earned moment and still
# sits under nothing-louder-than-the-fire discipline.
EVENT_TARGET_DBFS = {
    "streak": -26.8,
    "crit": -25.2,
    "loot": -25.6,
    "levelup": -24.8,
    "boing": -28.2,
    "stat": -28.8,
}

STAT_TONES = (D4, E4, FS4, A4, B4, D5)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _calibrate(audio: np.ndarray, target_dbfs: float) -> np.ndarray:
    gain = world._db(target_dbfs) / max(world._phone_rms(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > world._db(-6.0):
        gain *= world._db(-6.0) / peak
    return audio * gain


def _bloom(stem: np.ndarray, seconds: float) -> np.ndarray:
    """The complete-bloom trick: a slow onset so meaning opens instead of
    snapping — distinguishes an outcome without importing a chime."""
    envelope = 1.0 - np.exp(-np.arange(len(stem)) / SAMPLE_RATE / seconds)
    return stem * envelope


def _render_streak(contact: np.ndarray) -> np.ndarray:
    # A kept-rhythm answer: one catch, root, and its fifth arriving above —
    # the two-note answer the sonic world reserves for outcomes.
    seconds = 0.32
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.9)
    world._place(
        stem,
        world._modal_body(D5, seconds, 52, seed=3_100, low_support=True, drift_cents=-6),
        0.002,
        0.32,
    )
    world._place(stem, contact, 0.085, 0.4)
    world._place(
        stem,
        world._modal_body(A5, seconds - 0.085, 46, seed=3_120, drift_cents=-9),
        0.085,
        0.185,
    )
    return world._park(world._room_bus(stem, 1.0), 22.0)


def _render_crit(contact: np.ndarray) -> np.ndarray:
    # The heavier cousin of streak: a weighted double catch and a denser body,
    # livelier through weight and speed — never through brightness.
    seconds = 0.34
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 1.0)
    world._place(stem, contact, 0.007, 0.5)
    world._place(
        stem,
        world._modal_body(D5, seconds, 62, seed=3_200, low_support=True, drift_cents=-8),
        0.002,
        0.36,
    )
    world._place(
        stem,
        world._modal_body(E5, seconds - 0.02, 40, seed=3_220, drift_cents=-12),
        0.02,
        0.115,
    )
    world._place(stem, contact, 0.055, 0.45)
    world._place(
        stem,
        world._modal_body(A5, seconds - 0.055, 66, seed=3_240, drift_cents=-7),
        0.055,
        0.26,
    )
    return world._park(world._room_bus(stem, 1.05), 24.0)


def _render_loot(contact: np.ndarray) -> np.ndarray:
    # Discovery: three small finds rising through the field, the last body
    # opening into the room — per the world sheet, discovery is where breath
    # and space are allowed to appear.
    seconds = 0.46
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    for at, tone, contact_gain, body_gain, decay, seed in (
        (0.0, A4, 0.55, 0.22, 40, 3_300),
        (0.09, D5, 0.45, 0.26, 55, 3_320),
        (0.19, E5, 0.4, 0.30, 88, 3_340),
    ):
        world._place(stem, contact, at, contact_gain)
        world._place(
            stem,
            world._modal_body(
                tone,
                seconds - at,
                decay,
                seed=seed,
                low_support=tone is E5,
                drift_cents=-6,
            ),
            at + 0.002,
            body_gain,
        )
    return world._park(world._room_bus(stem, 1.1), 26.0)


def _render_levelup(contact: np.ndarray) -> np.ndarray:
    # Ceremony: a sparse phrase from the same world. Low root, its octave, the
    # fifth above, then one blooming crown dyad — composed, no fanfare sparkle.
    seconds = 0.95
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.85)
    world._place(
        stem,
        world._modal_body(D4, seconds, 90, seed=3_400, low_support=True, drift_cents=-5),
        0.002,
        0.30,
    )
    world._place(stem, contact, 0.14, 0.5)
    world._place(
        stem,
        world._modal_body(D5, seconds - 0.14, 100, seed=3_420, low_support=True),
        0.14,
        0.30,
    )
    world._place(stem, contact, 0.30, 0.4)
    world._place(
        stem,
        world._modal_body(A5, seconds - 0.30, 130, seed=3_440, drift_cents=-6),
        0.30,
        0.24,
    )
    crown = np.zeros(round((seconds - 0.50) * SAMPLE_RATE), dtype=np.float64)
    world._place(
        crown,
        world._modal_body(D5, seconds - 0.50, 150, seed=3_460, low_support=True, drift_cents=9),
        0.0,
        0.30,
    )
    world._place(
        crown,
        world._modal_body(A5, seconds - 0.52, 140, seed=3_480, drift_cents=-4),
        0.02,
        0.17,
    )
    world._place(stem, _bloom(crown, 0.012), 0.50)
    return world._park(world._room_bus(stem, 1.15), 34.0)


def _render_boing(contact: np.ndarray) -> np.ndarray:
    # The friendly settle: a mistake sits back down and nothing scolds. Two
    # soft catches stepping downward with a gentle sag — never a rubber toy.
    seconds = 0.30
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.8)
    world._place(
        stem,
        world._modal_body(A4, seconds, 44, seed=3_500, drift_cents=-35),
        0.002,
        0.30,
    )
    world._place(stem, contact, 0.075, 0.45)
    world._place(
        stem,
        world._modal_body(D4, seconds - 0.075, 55, seed=3_520, low_support=True, drift_cents=-20),
        0.075,
        0.26,
    )
    return world._park(world._room_bus(stem, 0.9), 22.0)


def _render_stat(contact: np.ndarray, tone: float, index: int) -> np.ndarray:
    # One small find per stat: a light catch and a single field tone. Six of
    # these ascend the pentatonic, so a full stat sweep plays the field.
    seconds = 0.24
    stem = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(stem, contact, 0.0, 0.75)
    world._place(
        stem,
        world._modal_body(
            tone,
            seconds,
            46,
            seed=3_600 + index * 20,
            low_support=index < 3,
            drift_cents=-7,
        ),
        0.002,
        0.30,
    )
    return world._park(world._room_bus(stem, 0.85), 18.0)


def _flow(roles: dict[str, list[np.ndarray]], event: np.ndarray) -> np.ndarray:
    # The reward study's context timeline: ordinary clicking, then the event.
    timeline = [
        (0.30, "navigate", 0),
        (1.05, "open", 1),
        (1.72, "select", 2),
        (2.18, "select", 0),
        (2.92, "place", 1),
        (3.75, "navigate", 2),
        (4.55, "open", 0),
        (5.30, "select", 1),
    ]
    seconds = max(6.10, 5.375 + len(event) / SAMPLE_RATE + 0.05)
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    for at, role, variant in timeline:
        world._place(result, roles[role][variant], at)
    world._place(result, event, 5.375)
    return result


def _stat_run(stats: list[np.ndarray]) -> np.ndarray:
    result = np.zeros(round(1.35 * SAMPLE_RATE), dtype=np.float64)
    for index, audio in enumerate(stats):
        world._place(result, audio, 0.06 + index * 0.135)
    return result


def _load_roles(room_root: Path) -> dict[str, list[np.ndarray]]:
    return {
        role: [
            world._read_mono(room_root / "roles" / role / f"{index}.wav")
            for index in range(1, 4)
        ]
        for role in ("open", "select", "navigate", "place")
    }


def build_study(output: Path, room_root: Path, legacy_sfx: Path) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    contact_path = room_root / "shared" / "contact-master.wav"
    if not contact_path.exists():
        raise FileNotFoundError(contact_path)
    contact = world._fit(world._read_mono(contact_path), 0.014)
    roles = _load_roles(room_root)

    renders: dict[str, np.ndarray] = {
        "streak": _render_streak(contact),
        "crit": _render_crit(contact),
        "loot": _render_loot(contact),
        "levelup": _render_levelup(contact),
        "boing": _render_boing(contact),
    }
    for index, tone in enumerate(STAT_TONES):
        renders[f"stat_{index}"] = _render_stat(contact, tone, index)

    manifest_events: dict[str, object] = {}
    stat_candidates: list[np.ndarray] = []
    stat_controls: list[np.ndarray] = []
    for name, raw in renders.items():
        target = EVENT_TARGET_DBFS["stat" if name.startswith("stat_") else name]
        candidate = _calibrate(raw, target)
        legacy_path = legacy_sfx / f"{name}.wav"
        control = _calibrate(
            world._park(world._read_mono(legacy_path), 12.0), target
        )
        candidate_path = output / "events" / f"{name}.wav"
        control_path = output / "controls" / f"current-{name}.wav"
        world._write(candidate_path, candidate)
        world._write(control_path, control)
        entry: dict[str, object] = {
            "candidate": candidate_path.relative_to(output).as_posix(),
            "matched_control": control_path.relative_to(output).as_posix(),
            "natural_phone_rms_target_dbfs": target,
            "duration_ms": len(candidate) / SAMPLE_RATE * 1000,
            "derivation": {
                "render_version": RENDER_VERSION,
                "contact_master_id": world.CONTACT_MASTER_ID,
                "body_master_id": world.BODY_MASTER_ID,
                "space_fingerprint_id": world.SPACE_MASTER_ID,
                "pitch_field": "D-major pentatonic",
            },
        }
        if name.startswith("stat_"):
            stat_candidates.append(candidate)
            stat_controls.append(control)
        else:
            flow_candidate = output / "flows" / name / "candidate.wav"
            flow_control = output / "flows" / name / "current.wav"
            world._write(flow_candidate, _flow(roles, candidate))
            world._write(flow_control, _flow(roles, control))
            entry["flows"] = {
                "candidate": flow_candidate.relative_to(output).as_posix(),
                "current": flow_control.relative_to(output).as_posix(),
            }
        manifest_events[name] = entry

    world._write(output / "flows" / "stat-run" / "candidate.wav", _stat_run(stat_candidates))
    world._write(output / "flows" / "stat-run" / "current.wav", _stat_run(stat_controls))

    locked_paths = [
        room_root / "roles" / role / f"{index}.wav"
        for role in ("open", "select", "navigate", "place")
        for index in range(1, 4)
    ]
    manifest = {
        "study": STUDY_ID,
        "question": (
            "Do outcomes finally live in the same Room as the clasps, and does"
            " each event still say what it means?"
        ),
        "runtime_changed": False,
        "owner_feedback_source": {
            "date": "2026-08-21",
            "verbatim": (
                "right now there's little to no variety between the"
                " “textures” of taps or different interactions when"
                " tapping around so it all just sounds like the same popping"
                " sound that feels like a popping bubbles stim toy, ie, not"
                " polished and expensive like i like"
            ),
        },
        "render_contract": {
            "render_version": RENDER_VERSION,
            "contact_master_id": world.CONTACT_MASTER_ID,
            "body_master_id": world.BODY_MASTER_ID,
            "space_fingerprint_id": world.SPACE_MASTER_ID,
            "pitch_field": "D-major pentatonic (D E F# A B)",
            "event_targets_dbfs": EVENT_TARGET_DBFS,
            "shipping_note": (
                "candidates carry their phone level in-file; a shipped"
                " candidate moves its Sfx._volume entry to 1.0"
            ),
        },
        "events": manifest_events,
        "locked_everyday_family": {
            "source_study": str(room_root.resolve()),
            "source_hashes": {
                str(path.resolve()): _sha256(path) for path in locked_paths
            },
        },
        "provenance": {
            "reference_video_audio_used": False,
            "shipping_assets_changed": False,
            "legacy_sources": {
                str((legacy_sfx / f"{name}.wav").resolve()): _sha256(
                    legacy_sfx / f"{name}.wav"
                )
                for name in renders
            },
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
    parser.add_argument("--legacy-sfx", type=Path, required=True)
    parser.add_argument("--polish", action="store_true")
    args = parser.parse_args()
    if args.polish:
        _enable_polish()
    print(
        json.dumps(
            build_study(args.output, args.room_study, args.legacy_sfx), indent=2
        )
    )


if __name__ == "__main__":
    main()
