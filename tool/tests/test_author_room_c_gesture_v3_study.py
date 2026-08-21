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
import author_room_c_gesture_v3_study as study  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CGestureV3StudyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.approved = ROOT / "design/audits/2026-08-20/weighted-click-system-v1"
        cls.room = ROOT / "design/audits/2026-08-20/room-sonic-world-v1"
        cls.reward = ROOT / "design/audits/2026-08-20/room-reward-voice-v1"

    def build(self, output: Path) -> dict[str, object]:
        return study.build_study(output, self.approved, self.room, self.reward)

    def test_exact_anchor_hashes_full_duration_and_no_contact_master(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            self.assertTrue(manifest["render_contract"]["no_v1_contact_master_input"])
            for index in range(1, 6):
                self.assertEqual(sha(self.approved / "variants" / f"dak-c-{index}.wav"), sha(root / "anchor" / f"dak-c-{index}.wav"))
            for system, record in manifest["systems"].items():
                for paths in record["role_paths"].values():
                    for relative in paths:
                        info = sf.info(root / relative)
                        self.assertEqual((info.samplerate, info.channels, info.subtype), (study.SAMPLE_RATE, 1, "PCM_24"))
                        self.assertEqual(info.frames, round(study.CLICK_SECONDS * study.SAMPLE_RATE))
                if system == "historical-c":
                    for role in study.ORDINARY_ROLES:
                        for variant, relative in enumerate(record["role_paths"][role]):
                            rendered, _ = sf.read(root / relative, dtype="float64")
                            anchor, _ = sf.read(root / "anchor" / f"dak-c-{variant + 1}.wav", dtype="float64")
                            np.testing.assert_allclose(
                                rendered,
                                anchor * study.COMMON_AUDITION_GAIN,
                                atol=2e-7,
                                rtol=0,
                            )

    def test_common_phone_lift_is_applied_equally(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            contract = manifest["render_contract"]
            self.assertEqual(contract["render_version"], "room-c-gesture-v3-author-2")
            self.assertAlmostEqual(contract["ordinary_common_audition_lift_db"], 1.5)
            for variant in range(5):
                raw, _ = sf.read(root / "anchor" / f"dak-c-{variant + 1}.wav", dtype="float64")
                expected_db = 20 * math.log10(study._phone_rms(raw)) + 1.5
                for record in manifest["systems"].values():
                    for role in study.ORDINARY_ROLES:
                        self.assertAlmostEqual(
                            record["metrics"][role][variant]["phone_rms_dbfs"],
                            expected_db,
                            delta=0.05,
                        )

    def test_ordinary_cues_have_attack_body_closure_and_clean_tail(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            for record in manifest["systems"].values():
                for values in record["metrics"].values():
                    for metric in values:
                        self.assertGreater(metric["attack_0_4ms_energy"], 1e-5)
                        self.assertGreater(metric["body_4_28ms_energy"], 1e-6)
                        self.assertGreater(metric["closure_5_10ms_energy"], 1e-7)
                        self.assertLess(metric["tail_after_55ms_relative_peak_db"], -40.0)
                        self.assertLessEqual(metric["peak_dbfs"], -3.0)

    def test_variant_level_match_and_material_family_difference(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            for variant in range(5):
                expected = manifest["systems"]["historical-c"]["metrics"]["open"][variant]["phone_rms_dbfs"]
                for system, record in manifest["systems"].items():
                    for role in study.ORDINARY_ROLES:
                        self.assertAlmostEqual(record["metrics"][role][variant]["phone_rms_dbfs"], expected, delta=0.05)
            historical = manifest["systems"]["historical-c"]["metrics"]["navigate"][0]
            clasp = manifest["systems"]["c-clasp-family"]["metrics"]["navigate"][0]
            self.assertGreater(abs(historical["closure_5_10ms_energy"] - clasp["closure_5_10ms_energy"]), 1e-5)
            role = manifest["systems"]["c-role-family"]["metrics"]
            self.assertNotEqual(role["open"][0]["body_4_28ms_energy"], role["place"][0]["body_4_28ms_energy"])

    def test_rapid_policy_and_locked_completion_are_exact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            self.assertEqual(manifest["render_contract"]["rapid_gains"], list(study.RATE_GAINS))
            self.assertEqual(sha(self.room / "roles/select/2.wav"), sha(root / "locked/accepted-select-2.wav"))
            self.assertEqual(sha(self.reward / "rewards/answered-detent/natural.wav"), sha(root / "locked/answered-detent-natural.wav"))
            flows = []
            start = round(study.COMPLETION_SELECT_AT * study.SAMPLE_RATE)
            for record in manifest["systems"].values():
                audio, _ = sf.read(root / record["flow"], dtype="float64")
                self.assertTrue(np.all(np.isfinite(audio)))
                self.assertLess(float(np.max(np.abs(audio))), 1.0)
                flows.append(audio[start:])
            for flow in flows[1:]:
                np.testing.assert_allclose(flow, flows[0], atol=2e-7, rtol=0)

    def test_deterministic_manifest_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            a = self.build(Path(first) / "study"); b = self.build(Path(second) / "study")
            self.assertEqual(a["generated_audio_sha256"], b["generated_audio_sha256"])

    def test_manifest_hashes_cover_every_generated_wave(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            actual = {
                path.relative_to(root).as_posix(): sha(path)
                for path in sorted(root.rglob("*.wav"))
            }
            self.assertEqual(manifest["generated_audio_sha256"], actual)

    def test_human_audition_is_exact_c_against_one_useful_challenger(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / "study"; manifest = self.build(root)
            self.assertEqual(set(manifest["candidates"]), {"C", "X"})
            self.assertEqual(manifest["candidates"]["C"]["source_system"], "historical-c")
            self.assertEqual(manifest["candidates"]["X"]["source_system"], "c-clasp-family")
            self.assertEqual(manifest["audition_contract"]["challengers"], ["X"])
            self.assertEqual(manifest["audition_contract"]["omitted_from_human_comparison"], ["c-role-family"])
            for candidate in manifest["candidates"].values():
                for kind in ("single", "slow", "rapid", "flow"):
                    self.assertTrue((root / candidate[kind]).is_file())


if __name__ == "__main__":
    unittest.main()
