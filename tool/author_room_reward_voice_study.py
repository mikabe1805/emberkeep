#!/usr/bin/env python3
"""Author a focused Room of Days completion-reward audition.

The accepted everyday interaction family is treated as immutable input. This
study changes only the confirmed reward beginning 75 ms after the accepted
selection contact. Every challenger inherits the Room contact, modal body,
pitch field, and close reflection fingerprint. Nothing is written to runtime
assets.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_sonic_world_study as world


SAMPLE_RATE = world.SAMPLE_RATE
STUDY_ID = "room-reward-voice-v1"
RENDER_VERSION = "room-reward-author-v1"
OUTCOME_DELAY_SECONDS = 0.075
NATURAL_LIFT_DB = 0.65
PITCH_TOKEN = {
    "id": "d",
    "support_hz": 440.000,
    "root_hz": 587.330,
    "answer_hz": 880.000,
}
MECHANISMS = {
    "receipt-edge": {
        "duration_seconds": 0.245,
        "reveal_name": "Receipt edge",
        "intent": "clean release edge followed by a compact warm bloom",
    },
    "seated-catch": {
        "duration_seconds": 0.295,
        "reveal_name": "Seated catch",
        "intent": "dense low-mid latch body that settles with weight",
    },
    "answered-detent": {
        "duration_seconds": 0.285,
        "reveal_name": "Answered detent",
        "intent": "physical catch followed by one restrained delayed answer",
    },
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _db(value: float) -> float:
    return 10 ** (value / 20)


def _phone_energy(audio: np.ndarray) -> float:
    probe = world._filter(audio, highpass_hz=260, lowpass_hz=8_000, order=2)
    return float(np.sqrt(np.sum(probe * probe)))


def _scale_to_energy(audio: np.ndarray, target: float) -> np.ndarray:
    gain = target / max(_phone_energy(audio), 1e-12)
    peak = float(np.max(np.abs(audio * gain)))
    if peak > _db(-6.0):
        raise ValueError(
            f"reward would exceed the -6 dBFS authoring ceiling ({20 * math.log10(peak):.2f} dBFS)"
        )
    return audio * gain


def _receipt_edge(contact: np.ndarray, seconds: float) -> np.ndarray:
    frames = round(seconds * SAMPLE_RATE)
    edge = world._fit(contact, seconds)
    edge = world._filter(edge, highpass_hz=1_600, lowpass_hz=5_200, order=3)
    edge = world._normalize_peak(edge)
    attack = min(frames, round(0.0007 * SAMPLE_RATE))
    if attack:
        edge[:attack] *= np.linspace(0.0, 1.0, attack)
    fade_start = min(frames, round(0.006 * SAMPLE_RATE))
    if fade_start < frames:
        edge[fade_start:] *= np.cos(
            np.linspace(0, math.pi / 2, frames - fade_start)
        ) ** 2
    return edge


def _render_mechanism(mechanism: str, contact: np.ndarray) -> np.ndarray:
    spec = MECHANISMS[mechanism]
    seconds = float(spec["duration_seconds"])
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    edge = _receipt_edge(contact, min(seconds, 0.012))
    support = float(PITCH_TOKEN["support_hz"])
    root = float(PITCH_TOKEN["root_hz"])
    answer = float(PITCH_TOKEN["answer_hz"])

    if mechanism == "receipt-edge":
        world._place(result, edge, 0.0, 0.54)
        world._place(
            result,
            world._modal_body(root, seconds, 92, seed=2_100, low_support=True, drift_cents=-8),
            0.002,
            0.39,
        )
        world._place(
            result,
            world._modal_body(support, seconds - 0.010, 72, seed=2_120, drift_cents=-12),
            0.010,
            0.18,
        )
        world._place(
            result,
            world._modal_body(answer, seconds - 0.048, 88, seed=2_140, drift_cents=-5),
            0.048,
            0.075,
        )
        send = 1.02
    elif mechanism == "seated-catch":
        world._place(result, world._fit(contact, 0.014), 0.0, 0.115)
        world._place(result, edge, 0.0, 0.23)
        world._place(
            result,
            world._modal_body(support, seconds, 122, seed=2_200, low_support=True, drift_cents=-18),
            0.001,
            0.46,
        )
        world._place(
            result,
            world._modal_body(root, seconds - 0.014, 108, seed=2_220, low_support=True, drift_cents=-9),
            0.014,
            0.29,
        )
        world._place(
            result,
            world._modal_body(answer, seconds - 0.064, 132, seed=2_240, drift_cents=-6),
            0.064,
            0.105,
        )
        send = 1.08
    elif mechanism == "answered-detent":
        world._place(result, world._fit(contact, 0.014), 0.0, 0.095)
        world._place(result, edge, 0.0, 0.28)
        world._place(
            result,
            world._modal_body(root, seconds, 73, seed=2_300, low_support=True, drift_cents=-7),
            0.002,
            0.35,
        )
        world._place(
            result,
            world._modal_body(answer, seconds - 0.058, 127, seed=2_320, drift_cents=-12),
            0.058,
            0.245,
        )
        world._place(
            result,
            world._modal_body(support, seconds - 0.058, 112, seed=2_340, drift_cents=-15),
            0.058,
            0.115,
        )
        send = 1.06
    else:
        raise ValueError(f"unknown mechanism: {mechanism}")

    release = min(len(result), round(0.040 * SAMPLE_RATE))
    result[-release:] *= np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    # Reflections arrive after the gesture's own release, so the final master
    # receives a longer post-bus park. This keeps the compact room fingerprint
    # without leaving a headphone-visible edit at the file boundary.
    return world._park(world._room_bus(result, send), 28.0)


def _composite(accepted_contact: np.ndarray, reward: np.ndarray) -> np.ndarray:
    seconds = max(0.43, OUTCOME_DELAY_SECONDS + len(reward) / SAMPLE_RATE + 0.025)
    result = np.zeros(round(seconds * SAMPLE_RATE), dtype=np.float64)
    world._place(result, accepted_contact, 0.0)
    world._place(result, reward, OUTCOME_DELAY_SECONDS)
    return result


def _load_locked_roles(room_root: Path) -> dict[str, list[np.ndarray]]:
    return {
        role: [world._read_mono(room_root / "roles" / role / f"{index}.wav") for index in range(1, 4)]
        for role in ("open", "select", "navigate", "place")
    }


def _flow(roles: dict[str, list[np.ndarray]], reward: np.ndarray) -> np.ndarray:
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
    result = np.zeros(round(6.10 * SAMPLE_RATE), dtype=np.float64)
    for at, role, variant in timeline:
        world._place(result, roles[role][variant], at)
    world._place(result, reward, 5.30 + OUTCOME_DELAY_SECONDS)
    return result


def _write(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if float(np.max(np.abs(audio))) >= 1.0:
        raise ValueError(f"refusing to write clipped audio: {path}")
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def build_study(
    output: Path,
    room_root: Path,
    previous_control: Path,
    previous_reward_path: Path,
) -> dict[str, object]:
    output.mkdir(parents=True, exist_ok=True)
    contact_path = room_root / "shared" / "contact-master.wav"
    baseline_reward_path = room_root / "roles" / "complete-bloom" / "2.wav"
    accepted_contact_path = room_root / "roles" / "select" / "2.wav"
    for path in (
        contact_path,
        baseline_reward_path,
        accepted_contact_path,
        previous_control,
        previous_reward_path,
    ):
        if not path.exists():
            raise FileNotFoundError(path)

    contact = world._read_mono(contact_path)
    baseline_reward = world._read_mono(baseline_reward_path)
    accepted_contact = world._read_mono(accepted_contact_path)
    target_energy = _phone_energy(baseline_reward)
    natural_target_energy = target_energy * _db(NATURAL_LIFT_DB)
    roles = _load_locked_roles(room_root)

    reward_sets: dict[str, dict[str, np.ndarray]] = {
        "baseline": {
            "matched": baseline_reward.copy(),
            "natural": baseline_reward.copy(),
        }
    }
    for mechanism in MECHANISMS:
        raw = _render_mechanism(mechanism, contact)
        reward_sets[mechanism] = {
            "matched": _scale_to_energy(raw, target_energy),
            "natural": _scale_to_energy(raw, natural_target_energy),
        }

    reward_manifest: dict[str, object] = {}
    for reward_id, modes in reward_sets.items():
        mode_paths: dict[str, object] = {}
        for mode, reward in modes.items():
            reward_path = output / "rewards" / reward_id / f"{mode}.wav"
            composite_path = output / "composites" / reward_id / f"{mode}.wav"
            flow_path = output / "flows" / reward_id / f"{mode}.wav"
            _write(reward_path, reward)
            _write(composite_path, _composite(accepted_contact, reward))
            _write(flow_path, _flow(roles, reward))
            mode_paths[mode] = {
                "reward": reward_path.relative_to(output).as_posix(),
                "composite": composite_path.relative_to(output).as_posix(),
                "flow": flow_path.relative_to(output).as_posix(),
                "phone_energy": _phone_energy(reward),
                "peak_dbfs": 20 * math.log10(max(float(np.max(np.abs(reward))), 1e-12)),
            }
        if reward_id == "baseline":
            reveal_name = "Current unified bloom"
            intent = "the exact completion bloom heard in the accepted system proof"
            duration_seconds = len(baseline_reward) / SAMPLE_RATE
        else:
            reveal_name = str(MECHANISMS[reward_id]["reveal_name"])
            intent = str(MECHANISMS[reward_id]["intent"])
            duration_seconds = float(MECHANISMS[reward_id]["duration_seconds"])
        reward_manifest[reward_id] = {
            "reveal_name": reveal_name,
            "intent": intent,
            "duration_ms": duration_seconds * 1000,
            "paths": mode_paths,
            "derivation": {
                "render_version": RENDER_VERSION,
                "contact_master_id": world.CONTACT_MASTER_ID if reward_id != "baseline" else None,
                "body_master_id": world.BODY_MASTER_ID,
                "space_fingerprint_id": world.SPACE_MASTER_ID,
                "pitch_token": PITCH_TOKEN["id"] if reward_id != "baseline" else "existing-e-take",
                "study_axis": "reward_mechanism",
            },
        }

    # Preserve the exact prior full-system benchmark for diagnosis, but do not
    # use it for the reward decision: its everyday cues differ. The final blind
    # control revoices only the old completion on the locked Room family.
    previous_target = output / "controls" / "previous-mixed-natural.wav"
    previous_target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(previous_control, previous_target)
    previous_ending = world._read_mono(previous_control)[round(5.30 * SAMPLE_RATE) : round(5.80 * SAMPLE_RATE)]
    _write(output / "controls" / "previous-mixed-ending.wav", previous_ending)

    previous_reward_raw = world._park(world._read_mono(previous_reward_path), 36.0)
    previous_reward_gain = _db(world.ROLE_TARGET_DBFS["complete-bloom"]) / max(
        world._phone_rms(previous_reward_raw), 1e-12
    )
    previous_reward = previous_reward_raw * previous_reward_gain
    previous_reward_peak = float(np.max(np.abs(previous_reward)))
    if previous_reward_peak > _db(-6.0):
        previous_reward *= _db(-6.0) / previous_reward_peak
    isolated_control_paths = {
        "reward": "controls/previous-reward-locked-family.wav",
        "ending": "controls/previous-reward-locked-family-ending.wav",
        "flow": "controls/previous-reward-locked-family-flow.wav",
    }
    previous_reward_ending = _composite(accepted_contact, previous_reward)
    previous_reward_flow = _flow(roles, previous_reward)
    _write(output / isolated_control_paths["reward"], previous_reward)
    _write(output / isolated_control_paths["ending"], previous_reward_ending)
    _write(output / isolated_control_paths["flow"], previous_reward_flow)
    representative_challenger_flow = _flow(
        roles, reward_sets["receipt-edge"]["natural"]
    )

    locked_paths = [
        room_root / "roles" / role / f"{index}.wav"
        for role in ("open", "select", "navigate", "place")
        for index in range(1, 4)
    ]
    source_paths = locked_paths + [
        contact_path,
        baseline_reward_path,
        accepted_contact_path,
        previous_control,
        previous_reward_path,
    ]
    generated_hashes = {
        path.relative_to(output).as_posix(): _sha256(path)
        for path in sorted(output.rglob("*.wav"))
    }
    manifest = {
        "study": STUDY_ID,
        "question": "Which completion ending would you want to earn again?",
        "runtime_changed": False,
        "locked_everyday_family": {
            "source_study": str(room_root.resolve()),
            "roles": ["open", "select", "navigate", "place"],
            "source_hashes": {str(path.resolve()): _sha256(path) for path in locked_paths},
        },
        "render_contract": {
            "render_version": RENDER_VERSION,
            "contact_master_id": world.CONTACT_MASTER_ID,
            "body_master_id": world.BODY_MASTER_ID,
            "space_fingerprint_id": world.SPACE_MASTER_ID,
            "fixed_pitch_token": PITCH_TOKEN,
            "outcome_delay_ms": OUTCOME_DELAY_SECONDS * 1000,
            "matched_reward_energy_reference": "exact current unified complete-bloom take 2",
            "natural_reward_lift_db": NATURAL_LIFT_DB,
            "mechanism_is_only_primary_study_axis": True,
        },
        "rewards": reward_manifest,
        "audition": {
            "challenger_order": list(MECHANISMS),
            "tournament_rule": "incumbent versus one new mechanism; equal or both-bad retains incumbent",
            "tournament_mode": "matched",
            "final_mode": "natural",
            "final_control": {
                "id": "previous-reward",
                "reveal_name": "Previous reward on the locked Room family",
                "flow": isolated_control_paths["flow"],
                "ending": isolated_control_paths["ending"],
                "reward": isolated_control_paths["reward"],
                "diagnostic_original_full_flow": previous_target.relative_to(output).as_posix(),
                "control_rule": "same locked everyday roles; only the previous calibrated completion reward differs; its final source boundary is parked to remove the old edit",
                "level_note": "intended natural hierarchy; not a loudness-neutral comparison",
                "reward_phone_energy_db_over_matched_baseline": 20
                * math.log10(_phone_energy(previous_reward) / target_energy),
                "whole_flow_phone_energy_db_over_challengers": 20
                * math.log10(
                    _phone_energy(previous_reward_flow)
                    / _phone_energy(representative_challenger_flow)
                ),
            },
            "full_flow_timeline": [
                {"at_seconds": 0.30, "role": "navigate"},
                {"at_seconds": 1.05, "role": "open"},
                {"at_seconds": 1.72, "role": "select"},
                {"at_seconds": 2.18, "role": "select"},
                {"at_seconds": 2.92, "role": "place"},
                {"at_seconds": 3.75, "role": "navigate"},
                {"at_seconds": 4.55, "role": "open"},
                {"at_seconds": 5.30, "role": "accepted-contact"},
                {"at_seconds": 5.375, "role": "completion-reward"},
            ],
            "identity_reveal": "after all tournament and final natural verdicts",
        },
        "feedback_source": {
            "study": "room-sonic-world-v1",
            "listening_route": "desktop-or-laptop-speaker",
            "matched_choice_resolved": "unified candidate",
            "distinct_choice": "yes",
            "natural_choice_resolved": "previous mixed study",
            "verbatim_reason": "it sounds pretty good! The reward sounds could be better though and more crisp i guess or satisfying or full?",
        },
        "provenance": {
            "reference_video_audio_used": False,
            "shipping_assets_changed": False,
            "source_hashes": {str(path.resolve()): _sha256(path) for path in source_paths},
        },
        "generated_audio_sha256": generated_hashes,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--room-study", type=Path, required=True)
    parser.add_argument("--previous-control", type=Path, required=True)
    parser.add_argument("--previous-reward", type=Path, required=True)
    args = parser.parse_args()
    print(
        json.dumps(
            build_study(
                args.output,
                args.room_study,
                args.previous_control,
                args.previous_reward,
            ),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
