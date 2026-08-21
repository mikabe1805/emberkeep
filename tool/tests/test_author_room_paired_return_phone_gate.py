from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
TOOL_ROOT = ROOT / "tool"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))
import author_room_paired_return_phone_gate as gate  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float64")
    if rate != gate.SAMPLE_RATE:
        raise AssertionError(f"unexpected sample rate for {path}: {rate}")
    return audio


class PairedReturnPhoneGateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.v3 = ROOT / "design/audits/2026-08-20/room-c-gesture-v3"
        cls.v4 = ROOT / "design/audits/2026-08-20/room-c-melody-v4"
        cls.reward = ROOT / "design/audits/2026-08-20/room-reward-voice-v1"
        cls.temporary = tempfile.TemporaryDirectory()
        cls.output = Path(cls.temporary.name) / "gate"
        cls.manifest = gate.build(cls.output, cls.v3, cls.v4, cls.reward)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def audio_for_event(self, event: dict[str, object]) -> np.ndarray:
        if event["state"] == "atomic_completion":
            return read(self.output / "locked-reward/answered-detent-natural-composite.wav")
        core = read(self.output / "locked-v3/cores" / str(event["role"]) / f"{event['take']}.wav")
        token = event["token"]
        if token:
            return core + read(self.output / "locked-v4/meaning" / f"{str(token).lower()}.wav")
        return core

    def assert_event_is_audible_and_exact(self, reel: np.ndarray, event: dict[str, object]) -> None:
        expected = self.audio_for_event(event) * float(event["gain"])
        start = round(float(event["at_seconds"]) * gate.SAMPLE_RATE)
        actual = reel[start:start + len(expected)]
        onset = round(0.015 * gate.SAMPLE_RATE)
        self.assertGreater(float(np.max(np.abs(expected[:onset]))), 1e-4, event)
        self.assertGreater(float(np.max(np.abs(actual[:onset]))), 1e-4, event)
        np.testing.assert_allclose(actual, expected, atol=3e-7, rtol=0)

    def test_atomic_completion_and_all_v3_takes_are_locked(self) -> None:
        self.assertEqual(self.manifest["render_version"], "room-paired-return-phone-gate-author-2")
        canonical = self.reward / gate.ATOMIC_COMPLETION_RELATIVE
        copied = self.output / "locked-reward/answered-detent-natural-composite.wav"
        self.assertEqual(sha(canonical), sha(copied))
        self.assertEqual(len(read(copied)), 20_640)
        self.assertNotIn("completion-composite.wav", self.manifest["source_sha256"])
        source = json.loads((self.v3 / "manifest.json").read_text(encoding="utf-8"))
        for role in gate.CORE_ROLES:
            for take, source_relative in enumerate(source["systems"]["c-clasp-family"]["role_paths"][role], 1):
                self.assertEqual(sha(self.v3 / source_relative), sha(self.output / "locked-v3/cores" / role / f"{take}.wav"))
            self.assertEqual(self.manifest["used_v3_takes_by_role"][role], [1, 2, 3, 4, 5])

    def test_discovery_shows_single_approved_return_then_cooldown_plain(self) -> None:
        record = self.manifest["reels"]["discovery"]
        events = record["events"]
        reel = read(self.output / record["file"])
        self.assertEqual([event["token"] for event in events[4:8]], ["D5", "A5", "E5", "D5"])
        self.assertTrue(all(event["state"] == "plain" for event in events[:4]))
        self.assertEqual(events[8]["state"], "plain")
        self.assertTrue(all(event["state"] == "cooldown_plain" and event["token"] is None for event in events[9:]))
        self.assertEqual(self.manifest["contract"]["rare_paired_return"]["cooldown_seconds"], 90)
        self.assertEqual(self.manifest["contract"]["rare_paired_return"]["once_per_screen"], 1)
        for event in events:
            self.assert_event_is_audible_and_exact(reel, event)

    def test_armed_rapid_abort_uses_gain_ladder_and_never_catches_up(self) -> None:
        record = self.manifest["reels"]["rapid_stays_plain"]
        events = record["events"]
        reel = read(self.output / record["file"])
        self.assertEqual([event["state"] for event in events[:5]], ["plain", "plain", "plain", "plain", "motif"])
        self.assertEqual(events[4]["token"], "D5")
        self.assertEqual(events[5]["state"], "rapid_abort")
        self.assertLess(events[5]["at_ms"] - events[4]["at_ms"], gate.RAPID_ABORT_LT_MS)
        self.assertEqual([event["gain"] for event in events[4:9]], list(gate.ARMED_RAPID_BURST_GAINS))
        self.assertEqual(events[5]["gain"], 0.93)
        self.assertTrue(all(event["token"] is None for event in events[5:]))
        self.assertTrue(all(event["state"] == "post_abort_plain" for event in events[9:]))
        for event in events:
            self.assert_event_is_audible_and_exact(reel, event)

    def test_completion_is_atomic_then_later_eligible_x_is_plain(self) -> None:
        record = self.manifest["reels"]["completion_interrupts"]
        events = record["events"]
        reel = read(self.output / record["file"])
        atomic = next(event for event in events if event["state"] == "atomic_completion")
        d5 = next(event for event in events if event["state"] == "motif")
        self.assertEqual(d5["token"], "D5")
        self.assertEqual(atomic["at_ms"] - d5["at_ms"], 80)
        self.assert_event_is_audible_and_exact(reel, atomic)
        later = [event for event in events if event["state"] == "post_completion_plain"]
        self.assertTrue(later)
        self.assertTrue(all(event["token"] is None for event in later))
        for event in events:
            self.assert_event_is_audible_and_exact(reel, event)

    def test_approved_walk_skips_repeated_boundary_candidate(self) -> None:
        emitted = [gate.approved_variant_at(index) for index in range(len(gate.VARIANT_WALK) * 2 + 1)]
        self.assertTrue(all(left[0] != right[0] for left, right in zip(emitted, emitted[1:])))
        self.assertEqual(emitted[len(gate.VARIANT_WALK) - 1], (0, len(gate.VARIANT_WALK) - 1))
        self.assertEqual(emitted[len(gate.VARIANT_WALK)], (2, 1))
        for record in self.manifest["reels"].values():
            takes = [event["take"] for event in record["events"] if event["take"] is not None]
            self.assertTrue(all(left != right for left, right in zip(takes, takes[1:])))

    def test_reels_are_safe_deterministic_and_sonic_contract_is_complete(self) -> None:
        actual = {}
        for path in sorted((self.output / "reels").glob("*.wav")):
            info = sf.info(path)
            self.assertEqual((info.samplerate, info.channels, info.subtype), (48_000, 1, "PCM_24"))
            audio = read(path)
            self.assertTrue(np.all(np.isfinite(audio)))
            self.assertLess(float(np.max(np.abs(audio))), 1.0)
            actual[path.relative_to(self.output).as_posix()] = sha(path)
        self.assertEqual(actual, self.manifest["generated_audio_sha256"])
        with tempfile.TemporaryDirectory() as temp:
            other = gate.build(Path(temp) / "gate", self.v3, self.v4, self.reward)
        self.assertEqual(self.manifest["generated_audio_sha256"], other["generated_audio_sha256"])
        contract = json.loads((self.output / "sonic-system.json").read_text(encoding="utf-8"))
        for key in ("product", "world", "mix", "render_contract", "cues", "auditions", "approval", "provenance"):
            self.assertIn(key, contract)
        self.assertTrue(any(item["id"] == "historical-v4-phrase-comparison" for item in contract["auditions"]))
        self.assertTrue(all(cue["layer_plan"]["variant_axis"] == contract["render_contract"]["variant_axis"] for cue in contract["cues"]))
        self.assertEqual(
            contract["approval"],
            {"technical": "pass", "semantic": "pass", "cohesion": "pass", "physical_device": "pass"},
        )
        self.assertEqual(
            self.manifest["contract"]["rare_paired_return"]["status"],
            "physically approved bounded rare easter egg",
        )

    def test_html_is_truthful_iphone_only_and_locks_one_verdict(self) -> None:
        html = (ROOT / "design/audits/2026-08-20/room-paired-return-phone-gate-v1/index.html").read_text(encoding="utf-8")
        for token in ("Preview result", "iphoneLike", "iPad|Android", "android-preview-only", "ipad-preview-only", "touch-mac-preview-only", "route_attestation", "route_evidence", "physical_gate_eligible", "physical_gate_passed", "state.verdict)return", "A reel is still playing", "data:image/svg+xml"):
            self.assertIn(token, html)
        self.assertIn("iphoneLike&&$('#route').checked", html)
        self.assertIn("state.heard.size===3", html)
        audio_context_at = html.index("state.ctx=new AC()")
        resume_at = html.index("const resumePromise=state.ctx.resume()")
        manifest_fetch_at = html.index("await fetch('manifest.json')")
        await_resume_at = html.index("await resumePromise")
        self.assertLess(audio_context_at, resume_at)
        self.assertLess(resume_at, manifest_fetch_at)
        self.assertLess(manifest_fetch_at, await_resume_at)
        self.assertNotIn("Stopping or replaying", html)
        self.assertNotIn("approved v4", html.lower())


if __name__ == "__main__":
    unittest.main()
