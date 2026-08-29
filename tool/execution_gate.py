#!/usr/bin/env python3
"""Phase gate for carrying an approved product direction into implementation.

The gate intentionally validates evidence and progression, not taste. Existing
project capture and review workflows remain the source of the actual renders,
interaction checks, and device evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


PHASES = {"direction": 0, "slice": 1, "expansion": 2, "handoff": 3}
CHANGE_CLASSES = {
    "new_direction",
    "approved_direction_execution",
    "fidelity_correction",
    "focused_polish",
}
FULL_CHECKPOINT_CLASSES = {"new_direction", "approved_direction_execution"}
STATUSES = {
    "draft",
    "direction_locked",
    "slice_ready_for_owner",
    "expanding",
    "visual_evidence_ready",
    "owner_device_accepted",
    "blocked",
    "superseded",
}
RESULTS = {"pending", "pass", "fail", "blocked"}
VERDICTS = {"pending", "pass", "blocked"}
ARTIFACT_KINDS = {
    "reference",
    "render",
    "comparison",
    "interaction",
    "device_recording",
    "test_report",
    "critique",
    "manifest",
}
EVIDENCE_LAYERS = {"automated", "rendered", "device", "owner"}
IMPLEMENTATION_DATA_SOURCES = {
    "production_equivalent",
    "deterministic_fixture",
    "real_device",
    "test_output",
}
DISPOSITIONS = {"update", "inherits", "not_affected", "deferred"}
PHASE_STATUSES = {
    "direction": {"direction_locked", "slice_ready_for_owner", "expanding", "visual_evidence_ready", "owner_device_accepted"},
    "slice": {"expanding", "visual_evidence_ready", "owner_device_accepted"},
    "expansion": {"visual_evidence_ready", "owner_device_accepted"},
    "handoff": {"visual_evidence_ready", "owner_device_accepted"},
}
PLACEHOLDERS = {
    "",
    "...",
    "n/a",
    "none",
    "replace me",
    "replace-me",
    "tbd",
    "todo",
}


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.errors.append(message)

    def warn(self, condition: bool, message: str) -> None:
        if not condition:
            self.warnings.append(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"missing {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def substantive(value: Any, minimum: int = 8) -> bool:
    if not isinstance(value, str):
        return False
    cleaned = " ".join(value.strip().split())
    return len(cleaned) >= minimum and cleaned.lower() not in PLACEHOLDERS


def valid_date(value: Any) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return True
    except ValueError:
        return False


def timestamp(value: str) -> float:
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.timestamp()
    return parsed.timestamp()


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def valid_sha256(value: Any) -> bool:
    if not isinstance(value, str) or len(value) != 64:
        return False
    return all(character in "0123456789abcdefABCDEF" for character in value)


def brief_digest(brief: dict[str, Any]) -> str:
    """Digest the direction contract while allowing its phase status to advance."""
    contract = {key: value for key, value in brief.items() if key != "status"}
    encoded = json.dumps(
        contract,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def git_root(start: Path) -> Path:
    result = subprocess.run(
        ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ValueError(f"{start} is not inside a Git repository")
    return Path(result.stdout.strip()).resolve()


def path_within(root: Path, location: str) -> tuple[bool, Path]:
    file_part = location.split("#", 1)[0]
    candidate = Path(file_part)
    if not candidate.is_absolute():
        candidate = root / candidate
    candidate = candidate.resolve()
    try:
        candidate.relative_to(root)
        return True, candidate
    except ValueError:
        return False, candidate


def is_tracked(root: Path, path: Path) -> bool:
    try:
        relative = path.relative_to(root).as_posix()
    except ValueError:
        return False
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", relative],
        check=False,
        capture_output=True,
    )
    return result.returncode == 0


def revision_pathspecs(brief: dict[str, Any]) -> list[str]:
    scope = brief.get("revision_scope", {})
    include = scope.get("include", []) if isinstance(scope, dict) else []
    exclude = scope.get("exclude", []) if isinstance(scope, dict) else []
    specs = [str(item) for item in include if substantive(item, 1)]
    for item in exclude:
        if substantive(item, 1):
            normalized = str(item).replace("\\", "/").rstrip("/")
            specs.extend([f":(exclude){normalized}", f":(exclude){normalized}/**"])
    return specs


def current_revision(root: Path, brief: dict[str, Any]) -> str:
    head_result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    head = head_result.stdout.strip()
    specs = revision_pathspecs(brief)
    if not specs:
        raise ValueError("brief.revision_scope.include must name implementation paths")

    diff = subprocess.run(
        ["git", "-C", str(root), "diff", "--binary", "HEAD", "--", *specs],
        check=True,
        capture_output=True,
    ).stdout
    untracked_raw = subprocess.run(
        [
            "git",
            "-C",
            str(root),
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            *specs,
        ],
        check=True,
        capture_output=True,
    ).stdout
    untracked = sorted(path for path in untracked_raw.split(b"\0") if path)

    if not diff and not untracked:
        return f"commit:{head}"

    digest = hashlib.sha256()
    digest.update(head.encode("ascii"))
    digest.update(b"\0tracked-diff\0")
    digest.update(diff)
    digest.update(b"\0untracked\0")
    for raw_path in untracked:
        relative = raw_path.decode("utf-8", errors="surrogateescape")
        file_path = root / relative
        digest.update(raw_path)
        digest.update(b"\0")
        if file_path.is_file():
            with file_path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        else:
            digest.update(b"<missing-or-non-file>")
        digest.update(b"\0")
    return f"worktree:{head[:12]}:{digest.hexdigest()[:24]}"


def check_durable_path(
    report: Report, root: Path, location: Any, label: str
) -> Path | None:
    if not substantive(location, 1):
        report.errors.append(f"{label} needs a repository-relative path")
        return None
    inside, path = path_within(root, str(location))
    report.require(inside, f"{label} must be durable inside the repository: {location}")
    report.require(path.is_file(), f"{label} does not exist: {location}")
    return path if inside and path.is_file() else None


def validate_brief(
    brief: dict[str, Any], root: Path, requested_phase: str, report: Report
) -> None:
    report.require(brief.get("schema_version") == 1, "brief.schema_version must be 1")
    for field in ("id", "project", "surface", "scope", "user_job"):
        report.require(substantive(brief.get(field)), f"brief.{field} must be concrete")

    change_class = brief.get("change_class")
    report.require(change_class in CHANGE_CLASSES, "brief.change_class is invalid")
    status = brief.get("status")
    report.require(status in STATUSES, "brief.status is invalid")
    report.require(status in PHASE_STATUSES[requested_phase], f"brief.status has not reached {requested_phase}")
    report.require(valid_date(brief.get("locked_at")), "brief.locked_at must be an ISO date/time")

    conflicts = brief.get("source_conflicts")
    report.require(isinstance(conflicts, list), "brief.source_conflicts must be a list")
    if isinstance(conflicts, list) and conflicts:
        report.errors.append("active source conflicts must be resolved before direction lock")

    sources = brief.get("active_sources")
    report.require(isinstance(sources, list) and len(sources) >= 1, "at least one active source is required")
    priorities: list[int] = []
    if isinstance(sources, list):
        for index, source in enumerate(sources):
            label = f"brief.active_sources[{index}]"
            if not isinstance(source, dict):
                report.errors.append(f"{label} must be an object")
                continue
            for field in ("id", "kind", "judged_state", "viewport"):
                report.require(substantive(source.get(field)), f"{label}.{field} must be concrete")
            report.require(valid_date(source.get("approved_at")), f"{label}.approved_at must be ISO")
            priority = source.get("priority")
            report.require(isinstance(priority, int) and priority > 0, f"{label}.priority must be positive")
            if isinstance(priority, int):
                priorities.append(priority)
            source_path = check_durable_path(report, root, source.get("location"), f"{label}.location")
            if source_path is not None:
                expected_digest = source.get("content_sha256")
                report.require(valid_sha256(expected_digest), f"{label}.content_sha256 must be a SHA-256 digest")
                if valid_sha256(expected_digest):
                    report.require(
                        file_sha256(source_path) == str(expected_digest).lower(),
                        f"{label}.location changed after direction lock",
                    )
                report.warn(is_tracked(root, source_path), f"{label}.location is not tracked yet: {source.get('location')}")
    report.require(len(priorities) == len(set(priorities)), "active source priorities must be unique")

    superseded = brief.get("superseded_sources", [])
    report.require(isinstance(superseded, list), "brief.superseded_sources must be a list")
    if isinstance(superseded, list):
        for index, source in enumerate(superseded):
            label = f"brief.superseded_sources[{index}]"
            report.require(isinstance(source, dict), f"{label} must be an object")
            if isinstance(source, dict):
                report.require(substantive(source.get("location"), 1), f"{label}.location is required")
                report.require(substantive(source.get("reason")), f"{label}.reason must explain supersession")

    edge = brief.get("edge_contract")
    report.require(isinstance(edge, dict), "brief.edge_contract must be an object")
    if isinstance(edge, dict):
        for key in ("product", "interaction", "visual"):
            item = edge.get(key)
            report.require(isinstance(item, dict), f"brief.edge_contract.{key} is required")
            if isinstance(item, dict):
                report.require(substantive(item.get("decision"), 20), f"edge {key} decision is too vague")
                report.require(substantive(item.get("proof"), 16), f"edge {key} needs observable proof")

    fallbacks = brief.get("anti_fallbacks")
    report.require(isinstance(fallbacks, list) and len(fallbacks) >= 1, "at least one concrete anti-fallback is required")
    if isinstance(fallbacks, list):
        for index, item in enumerate(fallbacks):
            label = f"brief.anti_fallbacks[{index}]"
            report.require(isinstance(item, dict), f"{label} must be an object")
            if isinstance(item, dict):
                report.require(substantive(item.get("fallback")), f"{label}.fallback is required")
                report.require(substantive(item.get("why"), 16), f"{label}.why must be concrete")

    first = brief.get("first_real_slice")
    report.require(isinstance(first, dict), "brief.first_real_slice must be an object")
    if isinstance(first, dict):
        for field in ("scenario", "real_inputs", "user_action", "expected_outcome", "state_boundary"):
            report.require(substantive(first.get(field), 12), f"first_real_slice.{field} must be concrete")
        states = first.get("required_states")
        minimum = 3 if change_class in FULL_CHECKPOINT_CLASSES else 1
        report.require(isinstance(states, list) and len(states) >= minimum, f"first_real_slice needs at least {minimum} disproving state(s)")
        if isinstance(states, list):
            ids: list[str] = []
            for index, state in enumerate(states):
                label = f"first_real_slice.required_states[{index}]"
                report.require(isinstance(state, dict), f"{label} must be an object")
                if isinstance(state, dict):
                    report.require(substantive(state.get("id"), 2), f"{label}.id is required")
                    report.require(substantive(state.get("state")), f"{label}.state is required")
                    report.require(substantive(state.get("why_can_disprove"), 16), f"{label}.why_can_disprove is required")
                    if isinstance(state.get("id"), str):
                        ids.append(state["id"])
            report.require(len(ids) == len(set(ids)), "required state ids must be unique")

    ripple = brief.get("ripple_map")
    minimum_ripple = 3 if change_class in FULL_CHECKPOINT_CLASSES else 1
    report.require(isinstance(ripple, list) and len(ripple) >= minimum_ripple, f"ripple_map needs at least {minimum_ripple} row(s)")
    if isinstance(ripple, list):
        ids: list[str] = []
        for index, row in enumerate(ripple):
            label = f"brief.ripple_map[{index}]"
            report.require(isinstance(row, dict), f"{label} must be an object")
            if not isinstance(row, dict):
                continue
            report.require(substantive(row.get("id"), 2), f"{label}.id must be concrete")
            report.require(substantive(row.get("state"), 4), f"{label}.state must be concrete")
            for field in ("surface_or_primitive", "expected_effect", "verification_plan"):
                report.require(substantive(row.get(field)), f"{label}.{field} must be concrete")
            report.require(row.get("disposition") in DISPOSITIONS, f"{label}.disposition is invalid")
            if row.get("disposition") in {"not_affected", "deferred"}:
                report.require(substantive(row.get("reason"), 16), f"{label}.reason is required")
            if isinstance(row.get("id"), str):
                ids.append(row["id"])
        report.require(len(ids) == len(set(ids)), "ripple row ids must be unique")

    report.require(substantive(brief.get("unverified_property"), 20), "brief.unverified_property must name the plausible hidden failure")
    decisive = brief.get("decisive_check")
    report.require(isinstance(decisive, dict), "brief.decisive_check must be an object")
    if isinstance(decisive, dict):
        for field in ("method", "target", "pass_condition"):
            report.require(substantive(decisive.get(field), 12), f"decisive_check.{field} must be concrete")

    scope = brief.get("revision_scope")
    report.require(isinstance(scope, dict), "brief.revision_scope must be an object")
    if isinstance(scope, dict):
        report.require(isinstance(scope.get("include"), list) and bool(scope.get("include")), "revision_scope.include is required")
        report.require(isinstance(scope.get("exclude", []), list), "revision_scope.exclude must be a list")

    inheritance = brief.get("inherits_from")
    if change_class in {"fidelity_correction", "focused_polish"}:
        report.require(isinstance(inheritance, dict), "focused work must inherit an accepted full execution brief")
        if isinstance(inheritance, dict):
            report.require(substantive(inheritance.get("brief_id")), "inherits_from.brief_id is required")
            report.require(
                substantive(inheritance.get("direction_unchanged_reason"), 20),
                "inherits_from.direction_unchanged_reason must explain why the direction cannot change",
            )
            parent_path = check_durable_path(
                report,
                root,
                inheritance.get("brief_location"),
                "inherits_from.brief_location",
            )
            if parent_path is not None:
                report.require(parent_path.name == "brief.json", "inherits_from.brief_location must point to brief.json")
                report.require(is_tracked(root, parent_path), "the inherited brief must be tracked")
                try:
                    parent = load_json(parent_path)
                except ValueError as exc:
                    report.errors.append(str(exc))
                else:
                    report.require(parent.get("id") == inheritance.get("brief_id"), "inherits_from.brief_id does not match its brief")
                    report.require(parent.get("id") != brief.get("id"), "a brief cannot inherit itself")
                    report.require(parent.get("change_class") in FULL_CHECKPOINT_CLASSES, "focused work must inherit a full-checkpoint direction")
                    report.require(
                        parent.get("status") in {"expanding", "visual_evidence_ready", "owner_device_accepted"},
                        "focused work can only inherit a direction whose first slice was owner-accepted",
                    )
                    report.require(
                        parent.get("active_sources") == brief.get("active_sources"),
                        "focused work must preserve the inherited active sources exactly",
                    )
                    report.require(
                        parent.get("edge_contract") == brief.get("edge_contract"),
                        "focused work must preserve the inherited edge contract exactly",
                    )


def validate_artifact(
    artifact: Any,
    label: str,
    root: Path,
    report: Report,
    revision_time: float | None,
) -> str | None:
    if not isinstance(artifact, dict):
        report.errors.append(f"{label} must be an object")
        return None
    kind = artifact.get("kind")
    report.require(kind in ARTIFACT_KINDS, f"{label}.kind is invalid")
    report.require(substantive(artifact.get("state"), 4), f"{label}.state must name the represented state")
    generated_at = artifact.get("generated_at")
    report.require(valid_date(generated_at), f"{label}.generated_at must be ISO")
    artifact_path = check_durable_path(report, root, artifact.get("path"), f"{label}.path")
    expected_digest = artifact.get("content_sha256")
    report.require(valid_sha256(expected_digest), f"{label}.content_sha256 must be a SHA-256 digest")
    if artifact_path is not None and valid_sha256(expected_digest):
        report.require(
            file_sha256(artifact_path) == str(expected_digest).lower(),
            f"{label}.path content no longer matches its inspected artifact",
        )
    if valid_date(generated_at) and revision_time is not None:
        report.require(timestamp(generated_at) >= revision_time, f"{label} predates the recorded implementation revision")
        if artifact_path is not None:
            report.require(artifact_path.stat().st_mtime + 1 >= revision_time, f"{label} file predates the recorded implementation revision")
    report.require(
        artifact.get("data_source") in {"reference", "production_equivalent", "deterministic_fixture", "real_device", "test_output"},
        f"{label}.data_source is invalid",
    )
    return kind if isinstance(kind, str) else None


def matching_checks(
    evidence: dict[str, Any],
    requirement_id: str,
    *,
    minimum_phase: str,
    require_production_equivalent: bool,
    artifact_kinds: set[str] | None = None,
    artifact_data_sources: set[str] | None = None,
    evidence_layers: set[str] | None = None,
) -> list[dict[str, Any]]:
    checks = evidence.get("checks", [])
    if not isinstance(checks, list):
        return []
    matches: list[dict[str, Any]] = []
    for check in checks:
        if not isinstance(check, dict):
            continue
        phase = check.get("phase")
        if (
            check.get("requirement_id") != requirement_id
            or check.get("result") != "pass"
            or phase not in PHASES
            or PHASES[phase] < PHASES[minimum_phase]
        ):
            continue
        if require_production_equivalent and check.get("production_equivalent_input") is not True:
            continue
        if evidence_layers is not None and check.get("evidence_layer") not in evidence_layers:
            continue
        if artifact_kinds is not None or artifact_data_sources is not None:
            artifacts = check.get("artifacts")
            if not isinstance(artifacts, list) or not any(
                isinstance(artifact, dict)
                and (artifact_kinds is None or artifact.get("kind") in artifact_kinds)
                and (
                    artifact_data_sources is None
                    or artifact.get("data_source") in artifact_data_sources
                )
                for artifact in artifacts
            ):
                continue
        matches.append(check)
    return matches


def validate_evidence(
    brief: dict[str, Any],
    evidence: dict[str, Any],
    root: Path,
    requested_phase: str,
    report: Report,
) -> None:
    report.require(evidence.get("schema_version") == 1, "evidence.schema_version must be 1")
    report.require(evidence.get("brief_id") == brief.get("id"), "evidence.brief_id must match brief.id")
    current_brief_digest = brief_digest(brief)
    report.require(valid_sha256(evidence.get("brief_sha256")), "evidence.brief_sha256 must be a SHA-256 digest")
    report.require(
        evidence.get("brief_sha256") == current_brief_digest,
        "evidence is bound to a different direction brief",
    )
    evidence_phase = evidence.get("phase")
    report.require(evidence_phase in PHASES, "evidence.phase is invalid")
    if evidence_phase in PHASES:
        report.require(PHASES[evidence_phase] >= PHASES[requested_phase], f"evidence.phase has not reached {requested_phase}")

    if PHASES[requested_phase] == PHASES["direction"]:
        return

    revision = evidence.get("implementation_revision")
    report.require(substantive(revision, 12), "evidence.implementation_revision is required after direction lock")
    captured_at = evidence.get("revision_captured_at")
    report.require(valid_date(captured_at), "evidence.revision_captured_at must be ISO")
    revision_time = timestamp(captured_at) if valid_date(captured_at) else None
    try:
        actual_revision = current_revision(root, brief)
        report.require(revision == actual_revision, f"evidence is stale: recorded {revision!r}, current {actual_revision!r}")
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        report.errors.append(f"could not calculate implementation revision: {exc}")

    checks = evidence.get("checks")
    report.require(isinstance(checks, list), "evidence.checks must be a list")
    artifact_records: list[dict[str, Any]] = []
    if isinstance(checks, list):
        ids: list[str] = []
        for index, check in enumerate(checks):
            label = f"evidence.checks[{index}]"
            report.require(isinstance(check, dict), f"{label} must be an object")
            if not isinstance(check, dict):
                continue
            for field in ("id", "requirement_id", "method", "input_state", "inspected_by", "observation"):
                report.require(substantive(check.get(field)), f"{label}.{field} must be concrete")
            if isinstance(check.get("id"), str):
                ids.append(check["id"])
            report.require(check.get("phase") in PHASES, f"{label}.phase is invalid")
            report.require(check.get("evidence_layer") in EVIDENCE_LAYERS, f"{label}.evidence_layer is invalid")
            report.require(check.get("result") in RESULTS, f"{label}.result is invalid")
            report.require(isinstance(check.get("production_equivalent_input"), bool), f"{label}.production_equivalent_input must be boolean")
            artifacts = check.get("artifacts")
            if check.get("result") == "pass":
                report.require(isinstance(artifacts, list) and bool(artifacts), f"passing {label} needs durable artifacts")
            if isinstance(artifacts, list):
                for artifact_index, artifact in enumerate(artifacts):
                    kind = validate_artifact(
                        artifact,
                        f"{label}.artifacts[{artifact_index}]",
                        root,
                        report,
                        revision_time,
                    )
                    if kind:
                        artifact_records.append(
                            {
                                "check_id": check.get("id"),
                                "check_result": check.get("result"),
                                "phase": check.get("phase"),
                                "kind": kind,
                                "path": artifact.get("path") if isinstance(artifact, dict) else None,
                                "generated_at": artifact.get("generated_at") if isinstance(artifact, dict) else None,
                                "data_source": artifact.get("data_source") if isinstance(artifact, dict) else None,
                                "production_equivalent": check.get("production_equivalent_input") is True,
                                "evidence_layer": check.get("evidence_layer"),
                            }
                        )
        report.require(len(ids) == len(set(ids)), "evidence check ids must be unique")

    check_by_id = {
        check.get("id"): check
        for check in checks or []
        if isinstance(check, dict) and isinstance(check.get("id"), str)
    }

    def bound_artifacts(
        check_ids: Any,
        *,
        minimum_phase: str,
        evidence_layer: str | None = None,
        require_real_device: bool = False,
    ) -> tuple[bool, list[dict[str, Any]]]:
        if not isinstance(check_ids, list) or not check_ids:
            return False, []
        records: list[dict[str, Any]] = []
        for check_id in check_ids:
            check = check_by_id.get(check_id)
            if (
                not isinstance(check_id, str)
                or not isinstance(check, dict)
                or check.get("result") != "pass"
                or check.get("phase") not in PHASES
                or PHASES[check["phase"]] < PHASES[minimum_phase]
                or check.get("production_equivalent_input") is not True
                or (evidence_layer is not None and check.get("evidence_layer") != evidence_layer)
            ):
                return False, []
            check_records = [
                artifact
                for artifact in artifact_records
                if artifact.get("check_id") == check_id
                and artifact.get("check_result") == "pass"
                and artifact.get("data_source") in IMPLEMENTATION_DATA_SOURCES
            ]
            if not check_records:
                return False, []
            if require_real_device and not any(
                artifact.get("data_source") == "real_device" for artifact in check_records
            ):
                return False, []
            records.extend(check_records)
        return True, records

    edge_artifact_kinds = {
        "edge.product": {"render", "comparison", "interaction", "device_recording", "test_report"},
        "edge.interaction": {"interaction", "device_recording", "test_report"},
        "edge.visual": {"render", "comparison"},
    }
    for edge_id, artifact_kinds in edge_artifact_kinds.items():
        report.require(
            bool(
                matching_checks(
                    evidence,
                    edge_id,
                    minimum_phase="slice",
                    require_production_equivalent=True,
                    artifact_kinds=artifact_kinds,
                    artifact_data_sources=IMPLEMENTATION_DATA_SOURCES,
                )
            ),
            f"slice lacks phase-bound production-equivalent proof for {edge_id}",
        )

    first = brief.get("first_real_slice", {})
    for state in first.get("required_states", []) if isinstance(first, dict) else []:
        if isinstance(state, dict) and substantive(state.get("id"), 1):
            report.require(
                bool(
                    matching_checks(
                        evidence,
                        f"state:{state['id']}",
                        minimum_phase="slice",
                        require_production_equivalent=True,
                        artifact_kinds={"render", "comparison", "interaction", "device_recording", "test_report"},
                        artifact_data_sources=IMPLEMENTATION_DATA_SOURCES,
                    )
                ),
                f"slice lacks phase-bound production-equivalent proof for state:{state['id']}",
            )

    slice_render = any(
        PHASES.get(phase, -1) >= PHASES["slice"]
        and kind in {"render", "comparison"}
        and production_equivalent
        and artifact.get("data_source") in {"production_equivalent", "deterministic_fixture", "real_device"}
        for artifact in artifact_records
        for phase, kind, production_equivalent in [
            (artifact.get("phase"), artifact.get("kind"), artifact.get("production_equivalent"))
        ]
    )
    slice_behavior = any(
        PHASES.get(phase, -1) >= PHASES["slice"]
        and kind in {"interaction", "device_recording", "test_report"}
        and production_equivalent
        and artifact.get("data_source") in IMPLEMENTATION_DATA_SOURCES
        for artifact in artifact_records
        for phase, kind, production_equivalent in [
            (artifact.get("phase"), artifact.get("kind"), artifact.get("production_equivalent"))
        ]
    )
    report.require(slice_render, "slice needs an inspected current render/comparison with production-equivalent input")
    report.require(slice_behavior, "slice needs interaction or behavior evidence with production-equivalent input")

    critique = evidence.get("independent_critique")
    report.require(isinstance(critique, dict), "evidence.independent_critique is required")
    if isinstance(critique, dict):
        report.require(substantive(critique.get("reviewer")), "independent critique needs a reviewer")
        report.require(critique.get("authored_implementation") is False, "independent reviewer cannot be the slice author")
        report.require(critique.get("result") == "pass", "independent critique must pass before slice progression")
        reviewed_check_ids = critique.get("reviewed_check_ids")
        report.require(isinstance(reviewed_check_ids, list) and bool(reviewed_check_ids), "independent critique needs reviewed_check_ids")
        valid_review_check_ids = {
            check_id
            for check_id in reviewed_check_ids or []
            if isinstance(check_id, str)
            and isinstance(check_by_id.get(check_id), dict)
            and check_by_id[check_id].get("result") == "pass"
            and check_by_id[check_id].get("phase") in PHASES
            and PHASES[check_by_id[check_id]["phase"]] >= PHASES["slice"]
            and check_by_id[check_id].get("production_equivalent_input") is True
        }
        report.require(
            isinstance(reviewed_check_ids, list) and len(valid_review_check_ids) == len(reviewed_check_ids),
            "independent critique may only reference passing production-equivalent slice checks",
        )
        reviewed_requirements = {
            check_by_id[check_id].get("requirement_id")
            for check_id in valid_review_check_ids
            if isinstance(check_by_id.get(check_id), dict)
        }
        report.require(
            {"edge.product", "edge.interaction", "edge.visual"}.issubset(reviewed_requirements),
            "independent critique must review all three edge proofs",
        )
        artifacts = critique.get("reviewed_artifacts")
        report.require(isinstance(artifacts, list) and bool(artifacts), "independent critique needs reviewed artifacts")
        eligible_review_paths = {
            artifact.get("path")
            for artifact in artifact_records
            if artifact.get("check_id") in valid_review_check_ids
            and artifact.get("check_result") == "pass"
            and artifact.get("phase") in PHASES
            and PHASES[artifact["phase"]] >= PHASES["slice"]
            and artifact.get("production_equivalent") is True
            and artifact.get("data_source") in IMPLEMENTATION_DATA_SOURCES
        }
        if isinstance(artifacts, list):
            for index, location in enumerate(artifacts):
                check_durable_path(report, root, location, f"independent_critique.reviewed_artifacts[{index}]")
                report.require(location in eligible_review_paths, f"independent_critique.reviewed_artifacts[{index}] is not bound to a reviewed current-slice check")
        findings = critique.get("findings")
        report.require(isinstance(findings, list), "independent_critique.findings must be a list")
        if isinstance(findings, list) and findings:
            for index, finding in enumerate(findings):
                label = f"independent_critique.findings[{index}]"
                report.require(isinstance(finding, dict), f"{label} must be an object")
                if isinstance(finding, dict):
                    report.require(substantive(finding.get("finding"), 12), f"{label}.finding is required")
                    report.require(finding.get("disposition") in {"resolved", "accepted", "pending"}, f"{label}.disposition is invalid")
                    report.require(finding.get("disposition") != "pending", f"{label} is still pending")
                    if finding.get("disposition") in {"resolved", "accepted"}:
                        report.require(substantive(finding.get("evidence"), 8), f"{label}.evidence is required")
        else:
            report.require(substantive(critique.get("no_material_findings_observation"), 20), "a no-findings critique needs a concrete observation")

    checkpoint = evidence.get("owner_checkpoint")
    report.require(isinstance(checkpoint, dict), "evidence.owner_checkpoint is required")
    if isinstance(checkpoint, dict):
        required = brief.get("change_class") in FULL_CHECKPOINT_CLASSES
        report.require(checkpoint.get("required") is required, f"owner_checkpoint.required must be {required} for this change class")
        decision = checkpoint.get("decision")
        if required:
            report.require(decision == "accepted", "the early owner checkpoint must be explicitly accepted before expansion")
        else:
            report.require(decision in {"accepted", "not_required"}, "focused work must record accepted or not_required")
        report.require(substantive(checkpoint.get("exact_feedback_or_waiver_reason"), 12), "owner checkpoint needs exact feedback/reference or a concrete not-required reason")
        if decision == "accepted":
            report.require(valid_date(checkpoint.get("requested_at")), "owner checkpoint needs requested_at")
            report.require(valid_date(checkpoint.get("decided_at")), "owner checkpoint needs decided_at")
            report.require(checkpoint.get("reviewed_revision") == revision, "owner checkpoint is not bound to the current implementation revision")
            report.require(
                checkpoint.get("reviewed_brief_sha256") == current_brief_digest,
                "owner checkpoint is not bound to the current direction brief",
            )
            binding_ok, checkpoint_artifacts = bound_artifacts(
                checkpoint.get("reviewed_check_ids"),
                minimum_phase="slice",
            )
            report.require(binding_ok, "owner checkpoint must reference passing production-equivalent slice checks")
            checkpoint_requirements = {
                check_by_id[check_id].get("requirement_id")
                for check_id in checkpoint.get("reviewed_check_ids") or []
                if isinstance(check_by_id.get(check_id), dict)
            }
            report.require(
                {"edge.product", "edge.interaction", "edge.visual"}.issubset(checkpoint_requirements),
                "owner checkpoint must review all three edge proofs",
            )
            reviewed_paths = checkpoint.get("reviewed_artifacts")
            report.require(isinstance(reviewed_paths, list) and bool(reviewed_paths), "owner checkpoint needs reviewed_artifacts")
            eligible_paths = {artifact.get("path") for artifact in checkpoint_artifacts}
            if isinstance(reviewed_paths, list):
                for index, location in enumerate(reviewed_paths):
                    report.require(location in eligible_paths, f"owner_checkpoint.reviewed_artifacts[{index}] is not bound to its reviewed checks")
            reviewed_records = [
                artifact for artifact in checkpoint_artifacts if artifact.get("path") in (reviewed_paths or [])
            ]
            report.require(
                any(artifact.get("kind") in {"render", "comparison"} for artifact in reviewed_records),
                "owner checkpoint must include a current rendered artifact",
            )
            report.require(
                any(artifact.get("kind") in {"interaction", "device_recording", "test_report"} for artifact in reviewed_records),
                "owner checkpoint must include current interaction or behavior evidence",
            )
            valid_review_times = [
                timestamp(str(artifact["generated_at"]))
                for artifact in reviewed_records
                if valid_date(artifact.get("generated_at"))
            ]
            if valid_date(checkpoint.get("requested_at")) and valid_review_times:
                report.require(
                    timestamp(checkpoint["requested_at"]) >= max(valid_review_times),
                    "owner checkpoint was requested before its reviewed artifacts were generated",
                )
            if valid_date(checkpoint.get("requested_at")) and valid_date(checkpoint.get("decided_at")):
                report.require(
                    timestamp(checkpoint["decided_at"]) >= timestamp(checkpoint["requested_at"]),
                    "owner checkpoint decision predates its request",
                )

    if PHASES[requested_phase] < PHASES["expansion"]:
        return

    remaining = evidence.get("remaining_gates")
    report.require(isinstance(remaining, list), "evidence.remaining_gates must be a list")
    gate_ids: set[str] = set()
    if isinstance(remaining, list):
        for index, gate in enumerate(remaining):
            label = f"evidence.remaining_gates[{index}]"
            report.require(isinstance(gate, dict), f"{label} must be an object")
            if isinstance(gate, dict):
                for field in ("id", "gate", "why", "owner_or_system", "next_action"):
                    report.require(substantive(gate.get(field)), f"{label}.{field} must be concrete")
                report.require(isinstance(gate.get("blocking"), bool), f"{label}.blocking must be boolean")
                if isinstance(gate.get("id"), str):
                    gate_ids.add(gate["id"])

    for row in brief.get("ripple_map", []):
        if not isinstance(row, dict) or not substantive(row.get("id"), 1):
            continue
        requirement = f"ripple:{row['id']}"
        if row.get("disposition") == "deferred":
            report.require(row.get("remaining_gate_id") in gate_ids, f"deferred {requirement} needs a matching remaining gate")
        else:
            report.require(
                bool(
                    matching_checks(
                        evidence,
                        requirement,
                        minimum_phase="expansion",
                        require_production_equivalent=True,
                        artifact_kinds={"render", "comparison", "interaction", "device_recording", "test_report", "manifest"},
                        artifact_data_sources=IMPLEMENTATION_DATA_SOURCES,
                    )
                ),
                f"expansion lacks phase-bound production-equivalent proof for {requirement}",
            )

    deviations = evidence.get("deviations")
    report.require(isinstance(deviations, list), "evidence.deviations must be a list")
    if isinstance(deviations, list):
        for index, deviation in enumerate(deviations):
            label = f"evidence.deviations[{index}]"
            report.require(isinstance(deviation, dict), f"{label} must be an object")
            if not isinstance(deviation, dict):
                continue
            for field in ("source_decision", "implementation_decision", "reason", "user_visible_consequence"):
                report.require(substantive(deviation.get(field)), f"{label}.{field} must be concrete")
            report.require(deviation.get("status") in {"resolved", "approved", "rejected", "pending"}, f"{label}.status is invalid")
            report.require(deviation.get("status") != "pending", f"{label} is still pending")
            if deviation.get("owner_approval_required") is True:
                report.require(deviation.get("status") == "approved", f"{label} requires owner approval")
                report.require(substantive(deviation.get("approval_reference"), 8), f"{label}.approval_reference is required")

    if PHASES[requested_phase] < PHASES["handoff"]:
        return

    failed_checks = [
        check
        for check in evidence.get("checks", [])
        if isinstance(check, dict) and check.get("result") == "fail"
    ]
    report.require(not failed_checks, "handoff cannot contain failed checks")
    blocking_non_external = [
        check
        for check in evidence.get("checks", [])
        if isinstance(check, dict)
        and check.get("result") in {"pending", "blocked"}
        and check.get("evidence_layer") in {"automated", "rendered"}
    ]
    report.require(not blocking_non_external, "automated/rendered checks cannot remain blocked at handoff")
    final_visual = any(
        artifact.get("phase") in PHASES
        and PHASES[artifact["phase"]] >= PHASES["handoff"]
        and artifact.get("kind") in {"render", "comparison"}
        and artifact.get("production_equivalent") is True
        and artifact.get("check_result") == "pass"
        and artifact.get("data_source") in {"production_equivalent", "deterministic_fixture", "real_device"}
        for artifact in artifact_records
    )
    report.require(final_visual, "handoff needs a final current production-equivalent render or comparison")
    report.require(
        bool(
            matching_checks(
                evidence,
                "final:comparison",
                minimum_phase="handoff",
                require_production_equivalent=True,
                artifact_kinds={"render", "comparison"},
                artifact_data_sources={"production_equivalent", "deterministic_fixture", "real_device"},
                evidence_layers={"rendered", "device"},
            )
        ),
        "handoff needs an explicit final:comparison check against the current build",
    )
    report.require(
        bool(
            matching_checks(
                evidence,
                "final:code-complete",
                minimum_phase="handoff",
                require_production_equivalent=True,
                artifact_kinds={"test_report"},
                artifact_data_sources={"test_output"},
                evidence_layers={"automated"},
            )
        ),
        "handoff needs an explicit final:code-complete automated test report",
    )

    verdicts = evidence.get("verdicts")
    report.require(isinstance(verdicts, dict), "evidence.verdicts must be an object")
    if isinstance(verdicts, dict):
        for key in ("code_complete", "visual_evidence_ready", "owner_device_accepted"):
            report.require(verdicts.get(key) in VERDICTS, f"verdicts.{key} is invalid")
        report.require(verdicts.get("code_complete") == "pass", "handoff requires code_complete=pass")
        report.require(verdicts.get("visual_evidence_ready") == "pass", "handoff requires visual_evidence_ready=pass")
        acceptance = evidence.get("owner_device_acceptance")
        report.require(isinstance(acceptance, dict), "evidence.owner_device_acceptance must be an object")
        owner = acceptance.get("owner") if isinstance(acceptance, dict) else None
        device = acceptance.get("device") if isinstance(acceptance, dict) else None
        report.require(isinstance(owner, dict), "owner_device_acceptance.owner must be an object")
        report.require(isinstance(device, dict), "owner_device_acceptance.device must be an object")
        if isinstance(owner, dict):
            report.require(owner.get("decision") in {"pending", "accepted", "blocked"}, "owner acceptance decision is invalid")
        if isinstance(device, dict):
            report.require(isinstance(device.get("required"), bool), "device acceptance must say whether device evidence is required")
            report.require(device.get("decision") in {"pending", "accepted", "blocked", "not_required"}, "device acceptance decision is invalid")

        def require_current_acceptance(
            receipt: dict[str, Any],
            *,
            label: str,
            evidence_layer: str,
            real_device: bool,
        ) -> None:
            report.require(valid_date(receipt.get("decided_at")), f"{label}.decided_at must be ISO")
            report.require(receipt.get("accepted_revision") == revision, f"{label} is not bound to the current implementation revision")
            report.require(
                receipt.get("accepted_brief_sha256") == current_brief_digest,
                f"{label} is not bound to the current direction brief",
            )
            binding_ok, receipt_artifacts = bound_artifacts(
                receipt.get("evidence_check_ids"),
                minimum_phase="handoff",
                evidence_layer=evidence_layer,
                require_real_device=real_device,
            )
            report.require(
                binding_ok,
                f"{label} must reference passing current-revision {evidence_layer} evidence"
                + (" from a real device" if real_device else ""),
            )
            artifact_times = [
                timestamp(str(artifact["generated_at"]))
                for artifact in receipt_artifacts
                if valid_date(artifact.get("generated_at"))
            ]
            if valid_date(receipt.get("decided_at")) and artifact_times:
                report.require(
                    timestamp(receipt["decided_at"]) >= max(artifact_times),
                    f"{label} decision predates its evidence",
                )

        if verdicts.get("owner_device_accepted") != "pass":
            blocking_external = [gate for gate in remaining or [] if isinstance(gate, dict) and gate.get("blocking")]
            report.require(bool(blocking_external), "a non-pass owner/device verdict needs a blocking remaining gate")
            report.require(brief.get("status") != "owner_device_accepted", "brief.status cannot claim owner/device acceptance while its verdict is non-pass")
        else:
            blocking_external = [gate for gate in remaining or [] if isinstance(gate, dict) and gate.get("blocking")]
            report.require(not blocking_external, "owner/device accepted cannot coexist with blocking remaining gates")
            report.require(brief.get("status") == "owner_device_accepted", "a passing owner/device verdict requires brief.status=owner_device_accepted")
            if isinstance(owner, dict):
                report.require(owner.get("decision") == "accepted", "owner_device_accepted=pass requires explicit owner acceptance")
                report.require(substantive(owner.get("exact_feedback"), 12), "final owner acceptance needs exact feedback/reference")
            device_required = isinstance(device, dict) and device.get("required") is True
            if isinstance(owner, dict):
                require_current_acceptance(
                    owner,
                    label="owner_device_acceptance.owner",
                    evidence_layer="owner",
                    real_device=device_required,
                )
            if isinstance(device, dict) and device_required:
                report.require(device.get("decision") == "accepted", "required physical-device acceptance must be explicit")
                report.require(substantive(device.get("observation_or_reason"), 12), "device acceptance needs a concrete observation")
                require_current_acceptance(
                    device,
                    label="owner_device_acceptance.device",
                    evidence_layer="device",
                    real_device=True,
                )
            elif isinstance(device, dict):
                report.require(device.get("decision") == "not_required", "non-device work must explicitly record device=not_required")
                report.require(device.get("accepted_revision") == revision, "device not-required decision is not bound to the current revision")
                report.require(device.get("accepted_brief_sha256") == current_brief_digest, "device not-required decision is not bound to the current direction brief")
                report.require(valid_date(device.get("decided_at")), "device not-required decision needs decided_at")
                report.require(substantive(device.get("observation_or_reason"), 16), "device not-required decision needs a concrete reason")


def validate(record: Path, phase: str) -> tuple[Report, Path, dict[str, Any]]:
    record = record.resolve()
    if record.is_file():
        record = record.parent
    brief = load_json(record / "brief.json")
    evidence = load_json(record / "evidence.json")
    root = git_root(record)
    report = Report()
    validate_brief(brief, root, phase, report)
    if phase == "handoff":
        for index, source in enumerate(brief.get("active_sources", [])):
            if isinstance(source, dict) and substantive(source.get("location"), 1):
                inside, source_path = path_within(root, str(source["location"]))
                if inside and source_path.is_file():
                    report.require(is_tracked(root, source_path), f"handoff source is not tracked: active_sources[{index}]")
    validate_evidence(brief, evidence, root, phase, report)
    return report, root, brief


def print_report(report: Report, phase: str, record: Path) -> None:
    state = "PASS" if not report.errors else "BLOCKED"
    print(f"Execution gate {state}: {phase} ({record})")
    for message in report.errors:
        print(f"  ERROR: {message}")
    for message in report.warnings:
        print(f"  WARNING: {message}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    check_parser = subparsers.add_parser("check", help="validate a phase")
    check_parser.add_argument("record", type=Path, help="directory containing brief.json and evidence.json")
    check_parser.add_argument("--phase", choices=PHASES, required=True)

    revision_parser = subparsers.add_parser("revision", help="print the current scoped implementation revision")
    revision_parser.add_argument("record", type=Path)

    digest_parser = subparsers.add_parser("digest", help="print a file's SHA-256 digest")
    digest_parser.add_argument("path", type=Path)

    brief_digest_parser = subparsers.add_parser("brief-digest", help="print the canonical direction-brief digest")
    brief_digest_parser.add_argument("record", type=Path)

    args = parser.parse_args()
    try:
        if args.command == "digest":
            path = args.path.resolve()
            if not path.is_file():
                raise ValueError(f"missing file: {path}")
            print(file_sha256(path))
            return 0

        if args.command == "brief-digest":
            record = args.record.resolve()
            if record.is_file():
                record = record.parent
            print(brief_digest(load_json(record / "brief.json")))
            return 0

        if args.command == "revision":
            record = args.record.resolve()
            if record.is_file():
                record = record.parent
            brief = load_json(record / "brief.json")
            root = git_root(record)
            print(current_revision(root, brief))
            return 0

        report, _, _ = validate(args.record, args.phase)
        print_report(report, args.phase, args.record)
        return 0 if not report.errors else 1
    except (OSError, subprocess.SubprocessError, ValueError) as exc:
        print(f"Execution gate ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
