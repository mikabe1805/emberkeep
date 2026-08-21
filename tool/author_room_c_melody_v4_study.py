#!/usr/bin/env python3
"""Author the Room of Days X-click melodic-phrase phone study.

The physical X gesture selected in ``room-c-gesture-v3`` is an immutable
source layer.  This study adds one short, dry resonance made from the same
modal language as the locked Answered Detent reward.  The two candidates use
the same X takes, note stems, levels, timings, and note multiset; only the
stateful phrase order changes.  Outputs remain staging-only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
from collections import Counter
from pathlib import Path

import numpy as np
import soundfile as sf

import author_room_sonic_world_study as world
import author_weighted_click_study as weighted


SAMPLE_RATE = 48_000
STUDY_ID = "room-c-melody-v4"
RENDER_VERSION = "room-c-melody-v4-author-1"
X_SYSTEM = "c-clasp-family"
ORDINARY_ROLES = ("open", "select", "navigate", "place")
VARIANT_COUNT = 5
CLICK_SECONDS = 0.060
MEANING_ONSET_SECONDS = 0.0105
MEANING_RMS_DBFS = -36.5
PHRASE_RESET_MS = 850
RAPID_TONAL_LIMIT = 4
RAPID_STEP_SECONDS = 0.125
SLOW_STEP_SECONDS = 0.320
RATE_GAINS = (1.0, 0.93, 0.93, 0.885)
COMPLETION_SELECT_AT = 5.300
DETENT_AT = 5.375
SYSTEM_VARIANT_AXIS = "ordinary global_phrase_position; locked completion none"

NOTES = {
    "a4": {"name": "A4", "midi": 69, "frequency_hz": 440.000},
    "d5": {"name": "D5", "midi": 74, "frequency_hz": 587.330},
    "e5": {"name": "E5", "midi": 76, "frequency_hz": 659.255},
    "fs5": {"name": "F#5", "midi": 78, "frequency_hz": 739.989},
    "a5": {"name": "A5", "midi": 81, "frequency_hz": 880.000},
}

# Same eight-note multiset, two meaningfully different contours.  This keeps
# loudness and register distribution fair while testing phrase shape alone.
PHRASES = {
    "paired-return": {
        "reveal_name": "Paired return",
        "intent": "small call-and-answer cells that repeatedly come home",
        "tokens": ("d5", "a5", "e5", "d5", "a4", "e5", "fs5", "d5"),
    },
    "gentle-arc": {
        "reveal_name": "Gentle arc",
        "intent": "one gradual rise, a warm dip, and a final return home",
        "tokens": ("d5", "e5", "fs5", "a5", "e5", "d5", "a4", "d5"),
    },
}

SLOW_ROLES = (
    "navigate",
    "open",
    "select",
    "place",
    "open",
    "select",
    "navigate",
    "place",
)
FLOW_TIMELINE = (
    (0.300, "navigate", 0),
    (1.050, "open", 1),
    (1.720, "select", 2),
    (2.180, "select", 0),
    (2.920, "place", 1),
    (3.750, "navigate", 2),
    (4.550, "open", 0),
)
RAPID_ROLES = ("open", "select", "navigate", "place") * 3


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def _write(path: Path, audio: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not np.all(np.isfinite(audio)):
        raise ValueError(f"non-finite audio: {path}")
    if float(np.max(np.abs(audio))) >= 1.0:
        raise ValueError(f"clipped audio: {path}")
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def _read(path: Path) -> np.ndarray:
    return world._read_mono(path)


def _db(value: float) -> float:
    return 10 ** (value / 20)


def _phone_energy(audio: np.ndarray) -> float:
    probe = world._filter(audio, highpass_hz=260, lowpass_hz=8_000, order=2)
    return float(np.sqrt(np.sum(probe * probe)))


def _meaning_stem(token: str) -> np.ndarray:
    """A short resonant color after X's 8.5 ms physical clasp."""
    spec = NOTES[token]
    seconds = CLICK_SECONDS - MEANING_ONSET_SECONDS
    body = world._modal_body(
        float(spec["frequency_hz"]),
        seconds,
        22.0,
        seed=20_260_900 + int(spec["midi"]) * 37,
        drift_cents=-4.0,
    )
    body = world._filter(body, highpass_hz=300, lowpass_hz=3_700, order=3)
    body = world._park(body, 15.0)
    result = np.zeros(round(CLICK_SECONDS * SAMPLE_RATE), dtype=np.float64)
    world._place(result, body, MEANING_ONSET_SECONDS)
    result *= _db(MEANING_RMS_DBFS) / max(world._phone_rms(result), 1e-12)
    return world._park(result, 2.0)


def _combine(core: np.ndarray, meaning: np.ndarray) -> np.ndarray:
    if len(core) != round(CLICK_SECONDS * SAMPLE_RATE):
        raise ValueError("approved X core is not the locked 60 ms gesture")
    result = core + meaning
    if float(np.max(np.abs(result))) > _db(-3.0):
        raise ValueError("melodic X cue exceeds the -3 dBFS ceiling")
    return result


def _place(base: np.ndarray, audio: np.ndarray, at: float, gain: float = 1.0) -> None:
    world._place(base, audio, at, gain)


def _slow(
    tokens: tuple[str, ...], cues: dict[str, dict[str, list[np.ndarray]]]
) -> np.ndarray:
    result = np.zeros(round(2.62 * SAMPLE_RATE), dtype=np.float64)
    for index, (role, token) in enumerate(zip(SLOW_ROLES, tokens)):
        variant = weighted.VARIANT_WALK[index]
        _place(result, cues[token][role][variant], 0.18 + index * SLOW_STEP_SECONDS)
    return result


def _rapid(
    tokens: tuple[str, ...],
    cues: dict[str, dict[str, list[np.ndarray]]],
    cores: dict[str, list[np.ndarray]],
) -> np.ndarray:
    result = np.zeros(round(1.66 * SAMPLE_RATE), dtype=np.float64)
    for index, role in enumerate(RAPID_ROLES):
        variant = weighted.VARIANT_WALK[index]
        if index < RAPID_TONAL_LIMIT:
            audio = cues[tokens[index]][role][variant]
        else:
            audio = cores[role][variant]
        gain = RATE_GAINS[min(index, len(RATE_GAINS) - 1)]
        _place(result, audio, 0.12 + index * RAPID_STEP_SECONDS, gain)
    return result


def _pause_probe(
    tokens: tuple[str, ...], cues: dict[str, dict[str, list[np.ndarray]]]
) -> np.ndarray:
    """One, two, and three-click bursts, each beginning again at home."""
    result = np.zeros(round(4.02 * SAMPLE_RATE), dtype=np.float64)
    groups = ((0.18,), (1.30, 1.62), (2.75, 3.07, 3.39))
    role_walk = ("navigate", "open", "select")
    for group in groups:
        for index, at in enumerate(group):
            role = role_walk[index]
            variant = weighted.VARIANT_WALK[index]
            _place(result, cues[tokens[index]][role][variant], at)
    return result


def _flow(
    tokens: tuple[str, ...],
    cues: dict[str, dict[str, list[np.ndarray]]],
    completion: np.ndarray,
) -> np.ndarray:
    result = completion.copy()
    for index, (at, role, variant) in enumerate(FLOW_TIMELINE):
        _place(result, cues[tokens[index]][role][variant], at)
    return result


def _metric(audio: np.ndarray) -> dict[str, float]:
    peak = max(float(np.max(np.abs(audio))), 1e-12)
    tail = max(float(np.max(np.abs(audio[-round(0.001 * SAMPLE_RATE) :]))), 1e-12)
    return {
        "phone_rms_dbfs": 20 * math.log10(max(world._phone_rms(audio), 1e-12)),
        "phone_energy_db": 20 * math.log10(max(_phone_energy(audio), 1e-12)),
        "peak_dbfs": 20 * math.log10(peak),
        "final_1ms_relative_peak_db": 20 * math.log10(tail / peak),
    }


def _cue_contract(role: str) -> dict[str, object]:
    meaning = {
        "open": "Ordinary content is available to inspect.",
        "select": "A small choice has seated into a new state.",
        "navigate": "A real destination change has been accepted.",
        "place": "Useful work has been put where it belongs.",
    }[role]
    actions = {
        "open": ["Open a journal entry or quiet sheet"],
        "select": ["Choose a date, filter, or toggle"],
        "navigate": ["Switch a tab, page, or calendar period"],
        "place": ["Save, add, schedule, or pin an item"],
    }[role]
    priority_class = "placement" if role == "place" else (
        "navigation" if role == "navigate" else "contact"
    )
    priority = 2 if role in ("navigate", "place") else 1
    return {
        "id": role,
        "verb": role,
        "meaning": meaning,
        "representative_actions": actions,
        "frequency": "occasional" if role == "place" else "frequent",
        "priority": priority,
        "priority_class": priority_class,
        "timing": "At the accepted visual state change; never for a no-op.",
        "timing_class": "confirmed_outcome" if role == "place" else "immediate",
        "gesture": "The approved complete X clasp plus one quiet global phrase resonance.",
        "shared_traits": ["transient", "body", "harmonic_field", "texture", "space"],
        "distinctive_traits": [f"X {role} weight", "global phrase position, not widget-local randomness"],
        "layer_plan": {
            "contact_master_id": "approved-x-complete-gesture-v3",
            "body_master_id": "approved-x-body-and-clasp-v3",
            "space_fingerprint_id": "room-dry-close-v4",
            "signature_source_id": "room-short-resonance-v4",
            "layers": ["contact", "body", "signature", "space"],
            "pitch_token": "One D-major-pentatonic token from the active global phrase.",
            "variant_axis": SYSTEM_VARIANT_AXIS,
            "derivation": "The byte-locked X core remains whole; a dry equal-energy resonance begins after its clasp and ends inside the same 60 ms master.",
        },
        "variant_count": 5,
        "no_immediate_repeat": True,
        "motion": "X onset aligns under the finger; the resonance belongs to the same visual settle.",
        "haptic": "Existing short selection feedback where already warranted.",
        "cooldown_ms": 55 if role == "navigate" else 35,
        "silent_when": ["The value or destination did not change", "The press becomes a scroll", "The control is disabled or busy"],
    }


def _sonic_system() -> dict[str, object]:
    cues = [_cue_contract(role) for role in ORDINARY_ROLES]
    cues.append({
        "id": "complete",
        "verb": "complete",
        "meaning": "A quest or routine was genuinely finished.",
        "representative_actions": ["Complete a quest", "Finish a routine"],
        "frequency": "occasional",
        "priority": 3,
        "priority_class": "completion",
        "timing": "Accepted Select take 2, then the Answered Detent exactly 75 ms later.",
        "timing_class": "atomic_composed_outcome",
        "gesture": "The already-selected physical catch and restrained D-to-A answer.",
        "shared_traits": ["harmonic_field", "dynamics"],
        "distinctive_traits": ["locked earned outcome", "resets and replaces the ordinary phrase"],
        "layer_plan": {
            "contact_master_id": "locked-accepted-select-2-v3",
            "body_master_id": "locked-answered-detent-v1",
            "space_fingerprint_id": "locked-answered-detent-space-v1",
            "signature_source_id": "locked-completion-composite-v3",
            "layers": ["locked_contact", "locked_body", "locked_signature", "locked_space"],
            "pitch_token": "Locked inside the approved composite; ordinary phrase state does not alter it.",
            "variant_axis": SYSTEM_VARIANT_AXIS,
            "derivation": "The exact previously selected completion composite is copied without re-rendering and clears phrase state.",
        },
        "variant_count": 1,
        "no_immediate_repeat": False,
        "motion": "The catch aligns with acceptance and the answer follows the earned receipt.",
        "haptic": "One success haptic synchronized to the accepted catch.",
        "cooldown_ms": 180,
        "silent_when": ["Completion is unconfirmed", "The event was already acknowledged"],
    })
    return {
        "format": "sonic-system/v1",
        "product": {
            "name": "Room of Days",
            "promise": "A warm physical room answers ordinary movement with satisfying clasps that become quietly musical only through use.",
            "owner_quotes": [
                "i like when there's a rhythm and it feels melodic.",
                "sounds really great but can you make the clicking melodic variations sound better overall when clicking around?",
            ],
        },
        "world": {
            "sensory_words": ["close", "warm", "weighty", "playful", "restrained"],
            "avoid": [
                "random independent note choice",
                "an endless rising scale",
                "a notification jingle on every tap",
                "brittle sparkle, audible room tail, or synthetic sine purity",
                "altering the approved X contact, clasp, or level while testing melody",
            ],
            "shared_dna": {
                "transient": "The complete selected X contact and 8.5 ms clasp remain the loudest causal event.",
                "body": "The entire approved 60 ms X body remains, with only a quieter inherited short resonance added after the clasp.",
                "harmonic_field": "Audition hypothesis: D-major-pentatonic A4, D5, E5, F-sharp5, and A5; one global eight-step contour, reset after 850 ms quiet.",
                "texture": "X's filtered micro-grain and inharmonic body remain unchanged; the meaning resonance uses the reward's correlated-excitation modal language.",
                "space": "Ordinary cues stay centered and dry, parked by 60 ms with no room bus or audible reverb tail.",
                "dynamics": "The X level stays at its approved +1.5 dB phone lift; resonance is roughly ten decibels quieter, and rapid use suppresses melody after four taps.",
            },
        },
        "mix": {
            "priority_order": ["completion", "placement", "navigation", "contact"],
            "priority_map": {"contact": 1, "navigation": 2, "placement": 2, "completion": 3},
            "voice_cap": 2,
            "rapid_policy": "One global clock advances the phrase across controls. Reset after 850 ms quiet. Apply X's 1.0, 0.93, 0.93, 0.885 rapid gains and suppress tonal continuation after the fourth rapid event.",
            "ducking_policy": "A completion clears ordinary resonance immediately; a new ordinary onset may steal only the prior resonance tail, never its own X core.",
            "silence_policy": ["Already-selected states", "scrolling or typing", "disabled and busy controls", "cancel or dismiss without a commit"],
            "compound_outcome_rule": "An action emits one X-plus-phrase cue or one atomic locked contact-to-completion plan, never both independently.",
            "voice_stealing_rule": "Completion steals every ordinary resonance; at the ordinary voice cap the newer X core plays and the older resonance tail fades first.",
            "state_dedupe_rule": "State-transition IDs dedupe repeated callbacks independently of the legitimate global phrase clock.",
            "settings_rule": "Respect sound disabled, native silent behavior, external audio mixing, and reduced-feedback settings before scheduling.",
        },
        "render_contract": {
            "version": RENDER_VERSION,
            "shared_sources": {
                "contact": {"id": "approved-x-complete-gesture-v3", "recipe": "Byte-locked complete X source masters from room-c-gesture-v3."},
                "body": {"id": "approved-x-body-and-clasp-v3", "recipe": "The same complete X source, including its body and explicit 8.5 ms clasp."},
                "space": {"id": "room-dry-close-v4", "recipe": "No room bus; every ordinary master is mono and parked inside 60 ms."},
                "signature": {"id": "room-short-resonance-v4", "recipe": "Equal-energy 49.5 ms modal/excitation stems derived from the selected reward language and beginning at 10.5 ms."},
            },
            "variant_axis": SYSTEM_VARIANT_AXIS,
        },
        "cues": cues,
        "auditions": [{
            "id": "melodic-world-flow",
            "context": "Navigate, open, select twice, place, navigate, open, then complete a quest at the same cadence for both phrase contours.",
            "sequence": ["navigate", "open", "select", "select", "place", "navigate", "open", "select", "complete"],
            "question": "Which contour makes clicking around feel musical while remaining one Room instrument?",
            "comparison": {
                "control": "candidates/paired-return/flow.wav",
                "candidate": "candidates/gentle-arc/flow.wav",
                "timings_ms": [300, 1050, 1720, 2180, 2920, 3750, 4550, 5300, 5375],
                "order": "Randomized A/B per browser session; identities remain hidden until the final verdict.",
                "natural_mix": True,
                "level_control": {
                    "control": "candidates/paired-return/flow.wav",
                    "candidate": "candidates/gentle-arc/flow.wav",
                },
                "verdicts": ["paired-return", "gentle-arc", "both", "neither"],
            },
        }],
        "provenance": {
            "policy": "Only deterministic project-authored synthesis and already approved project masters are used; reference audio is never copied.",
            "records": [
                {"id": "approved-x-v3", "status": "physical mechanism approved", "note": "Selected on an iPhone built-in speaker; contact, clasp, and +1.5 dB lift are locked."},
                {"id": "answered-detent-v1", "status": "completion approved", "note": "Copied byte-for-byte and scheduled 75 ms after its accepted-state contact."},
            ],
        },
        "approval": {"technical": "pass", "semantic": "pass", "cohesion": "pending", "physical_device": "pending"},
    }


def build_study(output: Path, v3_root: Path) -> dict[str, object]:
    manifest_path = v3_root / "manifest.json"
    if not manifest_path.is_file():
        raise FileNotFoundError(manifest_path)
    v3 = json.loads(manifest_path.read_text(encoding="utf-8"))
    if v3.get("study") != "room-c-gesture-v3":
        raise ValueError("v3 source is not room-c-gesture-v3")
    source_record = v3["systems"][X_SYSTEM]
    output.mkdir(parents=True, exist_ok=True)

    cores: dict[str, list[np.ndarray]] = {}
    x_source_hashes: dict[str, str] = {}
    locked_x_paths: dict[str, list[str]] = {}
    for role in ORDINARY_ROLES:
        cores[role] = []
        locked_x_paths[role] = []
        for index, relative in enumerate(source_record["role_paths"][role], 1):
            source = v3_root / relative
            destination = output / "locked-x" / "roles" / role / f"{index}.wav"
            _copy(source, destination)
            cores[role].append(_read(source))
            key = Path(relative).as_posix()
            x_source_hashes[key] = _sha256(source)
            locked_x_paths[role].append(destination.relative_to(output).as_posix())

    control = {}
    control_sources = {
        "single": source_record["isolated"]["navigate"],
        "phrase": source_record["slow"],
        "rapid": source_record["rapid"],
        "flow": source_record["flow"],
    }
    for kind, relative in control_sources.items():
        destination = output / "control" / f"plain-x-{kind}.wav"
        _copy(v3_root / relative, destination)
        control[kind] = destination.relative_to(output).as_posix()

    locked = {}
    for name in (
        "accepted-select-2.wav",
        "answered-detent-natural.wav",
        "completion-composite.wav",
    ):
        source = v3_root / "locked" / name
        destination = output / "locked" / name
        _copy(source, destination)
        locked[name] = destination.relative_to(output).as_posix()
    completion = _read(output / locked["completion-composite.wav"])

    stems = {token: _meaning_stem(token) for token in NOTES}
    stem_paths = {}
    stem_metrics = {}
    for token, audio in stems.items():
        path = output / "meaning" / f"{token}.wav"
        _write(path, audio)
        stem_paths[token] = path.relative_to(output).as_posix()
        stem_metrics[token] = _metric(audio)

    cues: dict[str, dict[str, list[np.ndarray]]] = {
        token: {role: [] for role in ORDINARY_ROLES} for token in NOTES
    }
    cue_paths: dict[str, dict[str, list[str]]] = {
        token: {role: [] for role in ORDINARY_ROLES} for token in NOTES
    }
    cue_metrics: dict[str, dict[str, list[dict[str, float]]]] = {
        token: {role: [] for role in ORDINARY_ROLES} for token in NOTES
    }
    for token, stem in stems.items():
        for role in ORDINARY_ROLES:
            for index, core in enumerate(cores[role], 1):
                audio = _combine(core, stem)
                path = output / "cues" / token / role / f"{index}.wav"
                _write(path, audio)
                cues[token][role].append(audio)
                cue_paths[token][role].append(path.relative_to(output).as_posix())
                cue_metrics[token][role].append(_metric(audio))

    candidates = {}
    for phrase_id, spec in PHRASES.items():
        tokens = tuple(spec["tokens"])
        root = output / "candidates" / phrase_id
        rendered = {
            "single": cues[tokens[0]]["navigate"][0],
            "phrase": _slow(tokens, cues),
            "flow": _flow(tokens, cues, completion),
            "rapid": _rapid(tokens, cues, cores),
            "pause_probe": _pause_probe(tokens, cues),
        }
        paths = {}
        metrics = {}
        for kind, audio in rendered.items():
            path = root / f"{kind.replace('_', '-')}.wav"
            _write(path, audio)
            paths[kind] = path.relative_to(output).as_posix()
            metrics[kind] = _metric(audio)
        candidates[phrase_id] = {
            "reveal_name": spec["reveal_name"],
            "intent": spec["intent"],
            "tokens": list(tokens),
            "notes": [NOTES[token]["name"] for token in tokens],
            "paths": paths,
            "metrics": metrics,
        }

    generated = {
        path.relative_to(output).as_posix(): _sha256(path)
        for path in sorted(output.rglob("*.wav"))
    }
    manifest = {
        "study": STUDY_ID,
        "runtime_changed": False,
        "render_version": RENDER_VERSION,
        "generated_audio_asset_count": len(generated),
        "source_study": str(v3_root.resolve()),
        "source_study_manifest_sha256": _sha256(manifest_path),
        "render_contract": {
            "sample_rate_hz": SAMPLE_RATE,
            "cue_duration_ms": CLICK_SECONDS * 1000,
            "x_core_is_byte_locked": True,
            "x_common_phone_lift_db": v3["level_lift_db"],
            "meaning_onset_ms": MEANING_ONSET_SECONDS * 1000,
            "meaning_phone_rms_dbfs": MEANING_RMS_DBFS,
            "phrase_reset_ms": PHRASE_RESET_MS,
            "rapid_tonal_limit": RAPID_TONAL_LIMIT,
            "rapid_step_ms": RAPID_STEP_SECONDS * 1000,
            "rapid_gains": list(RATE_GAINS),
            "no_room_bus": True,
            "comparison_axis": "phrase token order only",
        },
        "source_graph": {
            "x_system": X_SYSTEM,
            "x_role_sources": x_source_hashes,
            "locked_x_paths": locked_x_paths,
            "meaning_master_id": "room-short-resonance-v4",
            "meaning_note_stems": stem_paths,
            "meaning_derivation": "room-modal-bank-v1, 22 ms decay, dry, equal phone RMS, begins after the approved X clasp",
            "cue_derivation": "byte-locked X role take plus one meaning-note stem; no resampling, pitch shift, EQ, or gain change to X",
        },
        "notes": NOTES,
        "phrases": {
            phrase_id: {
                "tokens": list(spec["tokens"]),
                "notes": [NOTES[token]["name"] for token in spec["tokens"]],
                "multiset": dict(sorted(Counter(spec["tokens"]).items())),
                "reset_ms": PHRASE_RESET_MS,
                "rapid_rule": f"first {RAPID_TONAL_LIMIT} events keep the phrase; later rapid events use plain X",
            }
            for phrase_id, spec in PHRASES.items()
        },
        "control": control,
        "candidates": candidates,
        "audition_contract": {
            "randomized_hidden_sides": True,
            "required_primary_listens": ["single", "phrase", "flow"],
            "rapid_is_diagnostic_only": True,
            "plain_x_is_fixed_anchor_not_a_competitor": True,
            "neither_means_keep_plain_x": True,
            "identity_reveal": "after final verdict",
        },
        "locked_completion": {
            "paths": locked,
            "accepted_select_sha256": _sha256(output / locked["accepted-select-2.wav"]),
            "answered_detent_sha256": _sha256(output / locked["answered-detent-natural.wav"]),
            "completion_composite_sha256": _sha256(output / locked["completion-composite.wav"]),
            "accepted_select_at_seconds": COMPLETION_SELECT_AT,
            "answered_detent_at_seconds": DETENT_AT,
            "outcome_delay_ms": 75.0,
        },
        "qc": {"meaning": stem_metrics, "cues": cue_metrics},
        "generated_audio_sha256": generated,
    }
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    (output / "qc.json").write_text(
        json.dumps(
            {
                "study": STUDY_ID,
                "meaning": stem_metrics,
                "candidates": {
                    key: value["metrics"] for key, value in candidates.items()
                },
                "max_generated_peak_dbfs": max(
                    metric["peak_dbfs"]
                    for token in cue_metrics.values()
                    for role in token.values()
                    for metric in role
                ),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    (output / "sonic-system.json").write_text(
        json.dumps(_sonic_system(), indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--v3-study", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build_study(args.output, args.v3_study), indent=2))


if __name__ == "__main__":
    main()
