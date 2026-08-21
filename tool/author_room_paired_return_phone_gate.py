#!/usr/bin/env python3
"""Author the deterministic, iPhone-only Paired Return regression gate.

This is not an A/B. It renders a narrow behavioral gate from immutable
approved sources: all five v3 X takes, v4's bounded Paired Return
stems, and the canonical atomic Answered Detent composite from reward-voice-v1.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
import soundfile as sf

import author_weighted_click_study as weighted


SAMPLE_RATE = 48_000
STUDY_ID = "room-paired-return-phone-gate-v1"
RENDER_VERSION = "room-paired-return-phone-gate-author-2"
ELIGIBLE_MIN_MS = 180
ELIGIBLE_MAX_MS = 700
RAPID_ABORT_LT_MS = 180
MOTIF_AFTER_ELIGIBLE_ACTIONS = 4
MOTIF_TOKENS = ("d5", "a5", "e5", "d5")
CORE_ROLES = ("navigate", "open", "select", "place")
VARIANT_WALK = weighted.VARIANT_WALK
RAPID_GAINS = (1.0, 0.93, 0.93, 0.885)
ARMED_RAPID_BURST_GAINS = (*RAPID_GAINS, RAPID_GAINS[-1])
COOLDOWN_SECONDS = 90
SCREEN_LIMIT = 1
ATOMIC_COMPLETION_RELATIVE = "composites/answered-detent/natural.wav"
VARIANT_AXIS = "approved v3 global five-take walk; phrase state is shared across controls within one stable screen"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read(path: Path) -> np.ndarray:
    audio, sample_rate = sf.read(path, always_2d=False, dtype="float64")
    if sample_rate != SAMPLE_RATE:
        raise ValueError(f"unexpected sample rate for {path}: {sample_rate}")
    return np.asarray(audio, dtype=np.float64)


def write(path: Path, audio: np.ndarray) -> None:
    if not np.all(np.isfinite(audio)) or np.max(np.abs(audio), initial=0.0) >= 1:
        raise ValueError(f"invalid render: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, audio, SAMPLE_RATE, subtype="PCM_24")


def place(canvas: np.ndarray, clip: np.ndarray, seconds: float, gain: float = 1.0) -> None:
    start = round(seconds * SAMPLE_RATE)
    end = start + len(clip)
    if end > len(canvas):
        raise ValueError("clip exceeds reel canvas")
    canvas[start:end] += clip * gain


def scheduled(duration: float, events: list[dict[str, object]]) -> np.ndarray:
    result = np.zeros(round(duration * SAMPLE_RATE), dtype=np.float64)
    for event in events:
        place(result, event["audio"], float(event["at_seconds"]), float(event["gain"]))
    return result


def metric(audio: np.ndarray) -> dict[str, float]:
    peak = float(np.max(np.abs(audio), initial=0.0))
    rms = float(np.sqrt(np.mean(audio * audio)))
    return {"duration_ms": round(len(audio) * 1000 / SAMPLE_RATE, 3), "peak": peak, "rms": rms}


def approved_variant_at(sequence: int) -> tuple[int, int]:
    """Return a no-immediate-repeat take from the approved global walk.

    The authored walk ends and begins with take zero. When a longer gate ever
    wraps it, skip that duplicate boundary candidate exactly as the production
    router does instead of blindly applying modulo arithmetic.
    """
    if sequence < 0:
        raise ValueError("variant sequence cannot be negative")
    emitted = -1
    previous: int | None = None
    cursor = 0
    while True:
        position = cursor % len(VARIANT_WALK)
        candidate = VARIANT_WALK[position]
        cursor += 1
        if candidate == previous:
            continue
        emitted += 1
        if emitted == sequence:
            return candidate, position
        previous = candidate


def _event(
    sequence: int,
    at_seconds: float,
    role: str,
    state: str,
    cores: dict[str, list[np.ndarray]],
    stems: dict[str, np.ndarray],
    token: str | None = None,
    gain: float = 1.0,
) -> dict[str, object]:
    take_index, walk_position = approved_variant_at(sequence)
    core = cores[role][take_index]
    audio = core if token is None else core + stems[token]
    return {
        "at_seconds": at_seconds,
        "at_ms": round(at_seconds * 1000),
        "role": role,
        "take": take_index + 1,
        "variant_walk_position": walk_position,
        "state": state,
        "token": token.upper() if token else None,
        "gain": gain,
        "audio": audio,
    }


def _public_events(events: list[dict[str, object]]) -> list[dict[str, object]]:
    return [{key: value for key, value in event.items() if key != "audio"} for event in events]


def _cue(role: str) -> dict[str, object]:
    meaning = {
        "open": "Ordinary content becomes available to inspect.",
        "select": "A small choice seats into a changed state.",
        "navigate": "A real destination change is accepted.",
        "place": "Useful work is put where it belongs.",
    }[role]
    actions = {
        "open": ["Open a journal entry or quiet sheet"],
        "select": ["Choose a date, filter, or toggle"],
        "navigate": ["Switch a tab, page, or calendar period"],
        "place": ["Save, add, schedule, or pin an item"],
    }[role]
    return {
        "id": role,
        "verb": role,
        "meaning": meaning,
        "representative_actions": actions,
        "frequency": "occasional" if role == "place" else "frequent",
        "priority": 2 if role in ("navigate", "place") else 1,
        "priority_class": "navigation" if role == "navigate" else ("placement" if role == "place" else "contact"),
        "timing": "At the accepted visual state change; never for a no-op.",
        "timing_class": "confirmed_outcome" if role == "place" else "immediate",
        "gesture": "One approved v3 X contact/body take, selected by the global no-repeat walk.",
        "shared_traits": ["transient", "body", "harmonic_field", "texture", "space"],
        "distinctive_traits": [f"X {role} weight", "global take position rather than widget-local randomness"],
        "layer_plan": {
            "contact_master_id": "approved-x-complete-gesture-v3",
            "body_master_id": "approved-x-body-and-clasp-v3",
            "space_fingerprint_id": "room-dry-close-v3",
            "signature_source_id": "paired-return-approved-v4",
            "layers": ["contact", "body", "signature", "space"],
            "pitch_token": "None in everyday use; D5/A5/E5/D5 only in the rare phone-approved motif.",
            "variant_axis": VARIANT_AXIS,
            "derivation": "Everyday use is core-only. The phone-approved Paired Return layer is added only after the active stable-screen rarity gate opens.",
        },
        "variant_count": 5,
        "no_immediate_repeat": True,
        "motion": "The X onset aligns under the finger and the visual state settle.",
        "haptic": "Existing short selection feedback where already warranted.",
        "cooldown_ms": 35,
        "silent_when": ["The value or destination did not change", "The press becomes a scroll", "The control is disabled or busy"],
    }


def _sonic_system() -> dict[str, object]:
    cues = [_cue(role) for role in CORE_ROLES]
    cues.append({
        "id": "complete",
        "verb": "complete",
        "meaning": "A quest or routine was genuinely finished.",
        "representative_actions": ["Complete a quest", "Finish a routine"],
        "frequency": "occasional",
        "priority": 3,
        "priority_class": "outcome",
        "timing": "Accepted Select take 2 followed by the Answered Detent exactly 75 ms later, rendered atomically.",
        "timing_class": "atomic_composed_outcome",
        "gesture": "The locked earned contact-to-answer composite.",
        "shared_traits": ["harmonic_field", "dynamics", "body"],
        "distinctive_traits": ["locked earned outcome", "clears rare phrase state"],
        "layer_plan": {
            "contact_master_id": "locked-accepted-select-2-v3",
            "body_master_id": "locked-answered-detent-v1",
            "space_fingerprint_id": "locked-answered-detent-space-v1",
            "signature_source_id": "locked-answered-detent-composite-v1",
            "layers": ["locked_contact", "locked_body", "locked_signature", "locked_space"],
            "pitch_token": "Locked inside the canonical atomic composite; the rare phrase cannot alter it.",
            "variant_axis": VARIANT_AXIS,
            "derivation": "The canonical 430 ms answered-detent natural composite is copied without re-rendering before scheduling.",
        },
        "variant_count": 1,
        "no_immediate_repeat": False,
        "motion": "The accepted catch and answer form one earned receipt.",
        "haptic": "One success haptic synchronized to the accepted catch.",
        "cooldown_ms": 180,
        "silent_when": ["Completion is unconfirmed", "The event was already acknowledged"],
    })
    return {
        "format": "sonic-system/v1",
        "product": {
            "name": "Room of Days",
            "promise": "A warm, physical room answers ordinary movement with restrained clasps; the rare Paired Return is an earned detail rather than everyday noise.",
            "owner_quotes": ["i like when there's a rhythm and it feels melodic.", "sounds really great but can you make the clicking melodic variations sound better overall when clicking around?"],
        },
        "world": {
            "sensory_words": ["close", "warm", "weighty", "playful", "restrained"],
            "avoid": ["random independent note choice", "an endless rising scale", "a notification jingle on every tap", "brittle sparkle, audible room tail, or synthetic sine purity", "letting the approved return escape its rarity gate"],
            "shared_dna": {
                "transient": "The approved v3 X contact and 8.5 ms clasp remain the audible causal event.",
                "body": "All ordinary events use the complete v3 X core selected from its five-take family.",
                "harmonic_field": "Phone-approved bounded D-major-pentatonic D5/A5/E5/D5 after an active stable-screen eligibility gate; ordinary X has no pitch token.",
                "texture": "The filtered v3 micro-grain and inharmonic body remain unchanged; v4's short modal stem is only the rare signature layer.",
                "space": "Ordinary cues are centered and dry, parked inside their short masters with no room bus.",
                "dynamics": "Everyday X uses approved source level; a sub-180 ms rapid run follows 1.0/0.93/0.93/0.885 and clears the motif.",
            },
        },
        "mix": {
            "priority_order": ["outcome", "placement", "navigation", "contact"],
            "priority_map": {"contact": 1, "navigation": 2, "placement": 2, "outcome": 3},
            "voice_cap": 2,
            "rapid_policy": "The active stable-screen eligibility clock advances only at 180–700 ms and clears on a screen change. Any interval below 180 ms aborts the rare motif; the armed D5-through-rapid burst uses 1.0, 0.93, 0.93, 0.885, and 0.885 gains and later eligible events stay plain without catch-up.",
            "ducking_policy": "Completion clears the rare phrase immediately; a newer ordinary X may steal only an older resonance tail, never its own X core.",
            "silence_policy": ["Already-selected states", "scrolling or typing", "disabled and busy controls", "cancel or dismiss without a commit"],
            "compound_outcome_rule": "An action emits one X cue or the atomic locked completion plan, never both independently.",
            "voice_stealing_rule": "At the two-voice cap, completion has priority and drops rare resonance tails first.",
            "state_dedupe_rule": "State-transition IDs dedupe callbacks independently from the active-screen eligibility clock, screen limit, and global cooldown.",
            "settings_rule": "Respect sound disabled, native silent behavior, external audio mixing, and reduced-feedback settings before scheduling.",
        },
        "render_contract": {
            "version": RENDER_VERSION,
            "shared_sources": {
                "contact": {"id": "approved-x-complete-gesture-v3", "recipe": "All five byte-copied c-clasp-family X takes from room-c-gesture-v3."},
                "body": {"id": "approved-x-body-and-clasp-v3", "recipe": "The same complete approved X sources including their body and explicit clasp."},
                "space": {"id": "room-dry-close-v3", "recipe": "No room bus; the gate uses the already rendered short source masters."},
                "signature": {"id": "paired-return-approved-v4", "recipe": "Physically approved bounded D5/A5/E5/D5 meaning layers from room-c-melody-v4."},
            },
            "variant_axis": VARIANT_AXIS,
        },
        "cues": cues,
        "auditions": [{
            "id": "paired-return-regression-phone-gate",
            "context": "Three deterministic phone reels: discovery/cooldown, armed rapid abort, and atomic completion interruption.",
            "sequence": ["navigate", "open", "select", "place", "complete"],
            "question": "On an iPhone built-in speaker, does the selected motif stay rare, abort cleanly, and never compete with completion?",
        }, {
            "id": "historical-v4-phrase-comparison",
            "context": "Historical evidence only: the prior room-c-melody-v4 randomized phrase A/B that selected the Paired Return contour for this exploratory regression target.",
            "sequence": ["navigate", "open", "select", "select", "place", "navigate", "open", "select", "complete"],
            "question": "Historical question: which same-level phrase contour made clicking around feel melodic without becoming a jingle? This gate does not reopen that decision.",
            "comparison": {
                "control": "../room-c-melody-v4/candidates/gentle-arc/flow.wav",
                "candidate": "../room-c-melody-v4/candidates/paired-return/flow.wav",
                "timings_ms": [300, 1050, 1720, 2180, 2920, 3750, 4550, 5300, 5375],
                "order": "Historical randomized A/B per browser session; identities were hidden until final verdict.",
                "natural_mix": True,
                "level_control": {"control": "../room-c-melody-v4/candidates/gentle-arc/flow.wav", "candidate": "../room-c-melody-v4/candidates/paired-return/flow.wav"},
                "verdicts": ["paired-return", "gentle-arc", "both", "neither"],
            },
        }],
        "provenance": {
            "policy": "Only deterministic project-authored synthesis and physically approved project masters are copied; unused v4 notes and audition reels remain excluded from production.",
            "records": [
                {"id": "approved-x-v3", "status": "physical mechanism approved", "note": "All five source takes are byte-copied and exercised through the approved global walk."},
                {"id": "paired-return-v4", "status": "physically approved bounded rare easter egg", "note": "D5/A5/E5/D5 passed the corrected iPhone 17 behavioral gate; the longer v4 phrase remains excluded."},
                {"id": "answered-detent-atomic-v1", "status": "completion approved", "note": "Canonical composites/answered-detent/natural.wav is copied byte-for-byte before scheduling."},
            ],
        },
        "approval": {"technical": "pass", "semantic": "pass", "cohesion": "pass", "physical_device": "pass"},
    }


def build(output: Path, v3_root: Path, v4_root: Path, reward_root: Path) -> dict[str, object]:
    v3 = json.loads((v3_root / "manifest.json").read_text(encoding="utf-8"))
    v4 = json.loads((v4_root / "manifest.json").read_text(encoding="utf-8"))
    reward_manifest = json.loads((reward_root / "manifest.json").read_text(encoding="utf-8"))
    if v3.get("study") != "room-c-gesture-v3" or v4.get("study") != "room-c-melody-v4":
        raise ValueError("expected the approved v3 and v4 source manifests")
    if reward_manifest.get("study") != "room-reward-voice-v1":
        raise ValueError("expected room-reward-voice-v1 as the atomic completion source")
    system = v3["systems"]["c-clasp-family"]
    if tuple(v4["phrases"]["paired-return"]["tokens"][:4]) != MOTIF_TOKENS:
        raise ValueError("v4 Paired Return no longer matches the approved bounded four-note motif")

    output.mkdir(parents=True, exist_ok=True)
    for generated in ("locked-v3", "locked-v4", "locked-reward", "reels"):
        target = output / generated
        if target.exists():
            shutil.rmtree(target)
    for generated in ("manifest.json", "qc.json", "sonic-system.json"):
        (output / generated).unlink(missing_ok=True)

    source_hashes: dict[str, str] = {}
    cores: dict[str, list[np.ndarray]] = {}
    for role in CORE_ROLES:
        role_paths = system["role_paths"][role]
        if len(role_paths) != 5:
            raise ValueError(f"v3 no longer has five approved takes for {role}")
        cores[role] = []
        for take, relative in enumerate(role_paths, 1):
            source = v3_root / relative
            destination = output / "locked-v3" / "cores" / role / f"{take}.wav"
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            source_hashes[f"v3/{relative}"] = sha256(source)
            cores[role].append(read(source))
    stems: dict[str, np.ndarray] = {}
    for token in dict.fromkeys(MOTIF_TOKENS):
        source = v4_root / "meaning" / f"{token}.wav"
        destination = output / "locked-v4" / "meaning" / f"{token}.wav"
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        source_hashes[f"v4/meaning/{token}.wav"] = sha256(source)
        stems[token] = read(source)
    completion_source = reward_root / ATOMIC_COMPLETION_RELATIVE
    if not completion_source.is_file():
        raise FileNotFoundError(completion_source)
    completion_destination = output / "locked-reward" / "answered-detent-natural-composite.wav"
    completion_destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(completion_source, completion_destination)
    source_hashes[f"reward/{ATOMIC_COMPLETION_RELATIVE}"] = sha256(completion_source)
    completion = read(completion_source)
    if len(completion) != round(0.430 * SAMPLE_RATE):
        raise ValueError("canonical atomic completion is no longer 430 ms")

    discovery_roles = ("navigate", "open", "select", "place", "navigate", "open", "select", "place", "navigate", "open", "select", "place", "navigate", "open")
    discovery_events = []
    for index, role in enumerate(discovery_roles):
        token = MOTIF_TOKENS[index - 4] if 4 <= index < 8 else None
        state = "motif" if token else ("cooldown_plain" if index >= 9 else "plain")
        discovery_events.append(_event(index, 0.20 + index * 0.35, role, state, cores, stems, token))
    discovery = scheduled(5.05, discovery_events)

    rapid_plan = (
        (0.20, "select", "plain", None, 1.0), (0.55, "place", "plain", None, 1.0),
        (0.90, "navigate", "plain", None, 1.0), (1.25, "open", "plain", None, 1.0),
        (1.60, "place", "motif", "d5", ARMED_RAPID_BURST_GAINS[0]), (1.72, "select", "rapid_abort", None, ARMED_RAPID_BURST_GAINS[1]),
        (1.84, "navigate", "rapid_plain", None, ARMED_RAPID_BURST_GAINS[2]), (1.96, "place", "rapid_plain", None, ARMED_RAPID_BURST_GAINS[3]),
        (2.08, "select", "rapid_plain", None, ARMED_RAPID_BURST_GAINS[4]), (2.48, "place", "post_abort_plain", None, 1.0),
        (2.83, "open", "post_abort_plain", None, 1.0), (3.18, "navigate", "post_abort_plain", None, 1.0),
        (3.53, "open", "post_abort_plain", None, 1.0), (3.88, "select", "post_abort_plain", None, 1.0),
    )
    rapid_events = [_event(index, at, role, state, cores, stems, token, gain) for index, (at, role, state, token, gain) in enumerate(rapid_plan)]
    rapid = scheduled(4.18, rapid_events)

    completion_plan = (
        (0.20, "navigate", "plain", None, 1.0), (0.55, "open", "plain", None, 1.0),
        (0.90, "select", "plain", None, 1.0), (1.25, "place", "plain", None, 1.0),
        (1.60, "navigate", "motif", "d5", 1.0), (2.20, "open", "post_completion_plain", None, 1.0),
        (2.55, "select", "post_completion_plain", None, 1.0), (2.90, "place", "post_completion_plain", None, 1.0),
        (3.25, "navigate", "post_completion_plain", None, 1.0),
    )
    completion_events = [_event(index, at, role, state, cores, stems, token, gain) for index, (at, role, state, token, gain) in enumerate(completion_plan)]
    completion_at = 1.68
    atomic_event = {"at_seconds": completion_at, "at_ms": round(completion_at * 1000), "role": "completion", "take": None, "variant_walk_position": None, "state": "atomic_completion", "token": None, "gain": 1.0, "audio": completion}
    completion_all_events = sorted([*completion_events, atomic_event], key=lambda event: float(event["at_seconds"]))
    completion_reel = scheduled(3.58, completion_all_events)

    raw_reels = {
        "discovery": {"file": "reels/discovery.wav", "audio": discovery, "events": discovery_events, "purpose": "Varied plain X, one D5-A5-E5-D5 return, plain X, then a second qualifying run held plain by the one-per-screen and 90-second cooldown."},
        "rapid_stays_plain": {"file": "reels/rapid-stays-plain.wav", "audio": rapid, "events": rapid_events, "purpose": "Four eligible X events and D5 arm the motif; a 120 ms event aborts it, and both rapid and later eligible X events stay plain without catch-up."},
        "completion_interrupts": {"file": "reels/completion-interrupts.wav", "audio": completion_reel, "events": completion_all_events, "purpose": "D5 is followed 80 ms later by the canonical 430 ms atomic completion, then a later plain eligible X proves the motif was cleared."},
    }
    reels: dict[str, dict[str, object]] = {}
    generated_hashes = {}
    for name, record in raw_reels.items():
        path = output / str(record["file"])
        write(path, record["audio"])
        reels[name] = {"file": record["file"], "purpose": record["purpose"], "events": _public_events(record["events"]), "metrics": metric(read(path))}
        generated_hashes[str(record["file"])] = sha256(path)
    used_takes = {role: sorted({int(event["take"]) for record in reels.values() for event in record["events"] if event["role"] == role and event["take"] is not None}) for role in CORE_ROLES}
    if any(takes != [1, 2, 3, 4, 5] for takes in used_takes.values()):
        raise ValueError(f"gate does not exercise all five approved takes: {used_takes}")

    sonic_system = _sonic_system()
    (output / "sonic-system.json").write_text(json.dumps(sonic_system, indent=2) + "\n", encoding="utf-8")
    manifest = {
        "study": STUDY_ID, "render_version": RENDER_VERSION,
        "purpose": "Short physical-phone regression gate for the rare Paired Return easter egg.", "not_an_ab": True,
        "source_studies": {"v3": "room-c-gesture-v3", "v4": "room-c-melody-v4", "reward": "room-reward-voice-v1"},
        "source_paths": {"v3_root": str(v3_root), "v4_root": str(v4_root), "reward_root": str(reward_root), "atomic_completion": ATOMIC_COMPLETION_RELATIVE},
        "contract": {"everyday_default": "v3 X slight variations only, chosen from the approved global variant walk.", "rare_paired_return": {"status": "physically approved bounded rare easter egg", "trigger": f"after {MOTIF_AFTER_ELIGIBLE_ACTIONS} eligible ordinary actions", "eligible_interval_ms": [ELIGIBLE_MIN_MS, ELIGIBLE_MAX_MS], "tokens": ["D5", "A5", "E5", "D5"], "cooldown_seconds": COOLDOWN_SECONDS, "once_per_screen": SCREEN_LIMIT}, "rapid_policy": {"below_ms": RAPID_ABORT_LT_MS, "armed_burst_gains": list(ARMED_RAPID_BURST_GAINS), "result": "D5 begins the armed burst; a sub-180 ms event attenuates to .93, aborts active motif state, and later eligible events do not catch up."}, "completion_policy": {"result": "interrupt and clear ordinary motif state", "composite": "accepted-select-2 + answered-detent-natural @ +75ms", "source": f"room-reward-voice-v1/{ATOMIC_COMPLETION_RELATIVE}", "duration_ms": 430, "scheduled_after_d5_onset_ms": 80}},
        "reels": reels, "used_v3_takes_by_role": used_takes,
        "source_sha256": source_hashes, "generated_audio_sha256": generated_hashes,
        "physical_gate": {"requires": ["route_attestation", "full_volume_attestation", "device_model", "room_condition", "natural_completion_of_all_reels"], "eligible_browser": "actual iPhone-like user agent plus self-attested built-in-speaker route", "desktop_preview_is_eligible": False, "android_ipad_touch_mac_preview_only": True},
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    qc = {"study": STUDY_ID, "render_version": RENDER_VERSION, "technical": "pass", "reels": {name: record["metrics"] for name, record in reels.items()}, "checks": {"motif_tokens": list(MOTIF_TOKENS), "eligible_interval_ms": [ELIGIBLE_MIN_MS, ELIGIBLE_MAX_MS], "cooldown_seconds": COOLDOWN_SECONDS, "once_per_screen": SCREEN_LIMIT, "rapid_has_no_stems_after_abort": True, "completion_has_no_catchup": True, "completion_atomic_source_sha256": source_hashes[f"reward/{ATOMIC_COMPLETION_RELATIVE}"], "all_five_v3_takes_exercised_by_role": used_takes}}
    (output / "qc.json").write_text(json.dumps(qc, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=root / "design/audits/2026-08-20/room-paired-return-phone-gate-v1")
    parser.add_argument("--v3-root", type=Path, default=root / "design/audits/2026-08-20/room-c-gesture-v3")
    parser.add_argument("--v4-root", type=Path, default=root / "design/audits/2026-08-20/room-c-melody-v4")
    parser.add_argument("--reward-root", type=Path, default=root / "design/audits/2026-08-20/room-reward-voice-v1")
    args = parser.parse_args()
    build(args.output, args.v3_root, args.v4_root, args.reward_root)


if __name__ == "__main__":
    main()
