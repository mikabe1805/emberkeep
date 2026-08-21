from __future__ import annotations

import hashlib
import json
import math
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

import author_room_sonic_world_study as study  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


class RoomSonicWorldStudyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.approved = ROOT / "design/audits/2026-08-20/weighted-click-system-v1"
        cls.control = ROOT / "design/audits/2026-08-20/semantic-interaction-voices-v1"
        cls.streak = ROOT / "assets/sfx/streak.wav"

    def build(self, output: Path) -> dict[str, object]:
        return study.build_study(output, self.approved, self.control, self.streak)

    def test_build_is_staging_only_and_records_shared_derivation(self) -> None:
        watched = [
            self.streak,
            ROOT / "assets/sfx/complete.wav",
            self.approved / "variants/dak-c-1.wav",
        ]
        before = {path: sha256(path) for path in watched}
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            self.assertFalse(manifest["runtime_changed"])
            contract = manifest["render_contract"]
            self.assertEqual(contract["contact_master"]["id"], study.CONTACT_MASTER_ID)
            self.assertEqual(contract["body_master"]["id"], study.BODY_MASTER_ID)
            self.assertEqual(contract["space_fingerprint"]["id"], study.SPACE_MASTER_ID)
            for role, record in manifest["roles"].items():
                derivation = record["derivation"]
                self.assertEqual(derivation["body_master_id"], study.BODY_MASTER_ID)
                self.assertEqual(derivation["space_fingerprint_id"], study.SPACE_MASTER_ID)
                self.assertEqual(derivation["variant_axis"], "global_phrase_token")
                if role != "complete-bloom":
                    self.assertEqual(derivation["contact_master_id"], study.CONTACT_MASTER_ID)
        self.assertEqual(before, {path: sha256(path) for path in watched})

    def test_audio_is_pcm24_mono_finite_and_unclipped(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            for role, record in manifest["roles"].items():
                for relative in record["variant_paths"]:
                    path = output / relative
                    info = sf.info(path)
                    self.assertEqual(info.samplerate, study.SAMPLE_RATE)
                    self.assertEqual(info.channels, 1)
                    self.assertEqual(info.subtype, "PCM_24")
                    self.assertAlmostEqual(
                        info.duration,
                        study.ROLE_DURATIONS[role],
                        delta=1 / study.SAMPLE_RATE,
                    )
                    audio, _ = sf.read(path, dtype="float64")
                    self.assertTrue(np.all(np.isfinite(audio)))
                    self.assertLess(float(np.max(np.abs(audio))), 1.0)
                    tail_peak = float(np.max(np.abs(audio[-round(0.001 * study.SAMPLE_RATE) :])))
                    program_peak = float(np.max(np.abs(audio)))
                    self.assertLess(
                        20 * math.log10(max(tail_peak, 1e-12) / max(program_peak, 1e-12)),
                        -48.0,
                    )

    def test_level_control_and_compound_completion_timing_are_exact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            paths = manifest["audition"]["flow_paths"]
            control = study._read_mono(output / paths["control_matched"])
            candidate = study._read_mono(output / paths["candidate_matched"])
            difference_db = abs(
                20
                * math.log10(
                    max(study._phone_rms(control), 1e-12)
                    / max(study._phone_rms(candidate), 1e-12)
                )
            )
            self.assertLess(difference_db, 0.05)
            self.assertEqual(len(control), len(candidate))
            timeline = manifest["audition"]["timeline"]
            accepted = next(item for item in timeline if item["at_seconds"] == 5.3)
            bloom = next(item for item in timeline if item["role"] == "complete-bloom")
            self.assertEqual(accepted["role"], "select")
            self.assertAlmostEqual(
                (bloom["at_seconds"] - accepted["at_seconds"]) * 1000,
                75.0,
                places=6,
            )
            diagnostics = manifest["audition"]["diagnostics"]
            fatigue_control = study._read_mono(output / diagnostics["fatigue_control"])
            fatigue_candidate = study._read_mono(output / diagnostics["fatigue_candidate"])
            fatigue_difference_db = abs(
                20
                * math.log10(
                    max(study._phone_rms(fatigue_control), 1e-12)
                    / max(study._phone_rms(fatigue_candidate), 1e-12)
                )
            )
            self.assertLess(fatigue_difference_db, 0.05)
            self.assertEqual(len(diagnostics["fatigue_timeline"]), 18)
            control_assets = study._load_control_assets(self.control, self.streak)
            for role, variants in control_assets.items():
                for audio in variants:
                    measured = 20 * math.log10(max(study._phone_rms(audio), 1e-12))
                    self.assertAlmostEqual(measured, study.ROLE_TARGET_DBFS[role], delta=0.12)

    def test_space_fingerprint_is_short_feedforward_and_audible_only_as_glue(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            fingerprint = manifest["render_contract"]["space_fingerprint"]
            self.assertEqual(fingerprint["feedback"], 0)
            self.assertEqual(
                [(tap["delay_ms"], tap["gain_db"]) for tap in fingerprint["taps"]],
                list(study.SPACE_TAPS),
            )
            wet = study._read_mono(output / manifest["roles"]["navigate"]["variant_paths"][0])
            dry = study._read_mono(output / manifest["roles"]["navigate"]["bus_bypass_paths"][0])
            self.assertGreater(float(np.sqrt(np.mean((wet - dry) ** 2))), 1e-5)
            ir = study._read_mono(output / fingerprint["path"])
            nonzero = np.flatnonzero(np.abs(ir) > 1e-6)
            expected = [0] + [round(ms / 1000 * study.SAMPLE_RATE) for ms, _ in study.SPACE_TAPS]
            self.assertEqual(nonzero.tolist(), expected)

    def test_manifest_is_deterministic_and_excludes_reference_audio(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            output_a = Path(first) / "study"
            output_b = Path(second) / "study"
            manifest_a = self.build(output_a)
            manifest_b = study.build_study(
                output_b,
                self.approved.resolve(),
                self.control.resolve(),
                self.streak.resolve(),
            )
            self.assertFalse(manifest_a["provenance"]["reference_video_audio_used"])
            self.assertIn("diagnostics/approved-c-anchor.wav", manifest_a["generated_audio_sha256"])
            for role in manifest_a["roles"]:
                paths_a = manifest_a["roles"][role]["variant_paths"]
                paths_b = manifest_b["roles"][role]["variant_paths"]
                self.assertEqual(
                    [sha256(output_a / path) for path in paths_a],
                    [sha256(output_b / path) for path in paths_b],
                )
            comparable_a = json.loads((output_a / "manifest.json").read_text())
            comparable_b = json.loads((output_b / "manifest.json").read_text())
            # Absolute control/source paths are the same inputs in both builds.
            self.assertEqual(comparable_a, comparable_b)


if __name__ == "__main__":
    unittest.main()
