from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
TOOL_ROOT = ROOT / "tool"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))
import author_room_c_melody_v4_study as study  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> np.ndarray:
    audio, rate = sf.read(path, dtype="float64")
    if rate != study.SAMPLE_RATE:
        raise AssertionError(f"unexpected sample rate for {path}: {rate}")
    return audio


class CMelodyV4StudyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.v3 = ROOT / "design/audits/2026-08-20/room-c-gesture-v3"
        cls.temporary = tempfile.TemporaryDirectory()
        cls.output = Path(cls.temporary.name) / "study"
        cls.manifest = study.build_study(cls.output, cls.v3)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def test_x_core_and_locked_completion_are_byte_identical(self) -> None:
        source = json.loads((self.v3 / "manifest.json").read_text(encoding="utf-8"))
        source_x = source["systems"][study.X_SYSTEM]
        for role in study.ORDINARY_ROLES:
            for source_relative, locked_relative in zip(
                source_x["role_paths"][role],
                self.manifest["source_graph"]["locked_x_paths"][role],
            ):
                self.assertEqual(
                    sha(self.v3 / source_relative), sha(self.output / locked_relative)
                )
        for name, relative in self.manifest["locked_completion"]["paths"].items():
            self.assertEqual(sha(self.v3 / "locked" / name), sha(self.output / relative))
        self.assertTrue(self.manifest["render_contract"]["x_core_is_byte_locked"])

    def test_each_master_is_exact_x_plus_one_declared_note_stem(self) -> None:
        for token in study.NOTES:
            stem = read(self.output / self.manifest["source_graph"]["meaning_note_stems"][token])
            for role in study.ORDINARY_ROLES:
                for index, cue_relative in enumerate(
                    self.manifest["qc"]["cues"][token][role], start=1
                ):
                    # qc entries are metrics; source paths are deterministic.
                    cue = read(self.output / "cues" / token / role / f"{index}.wav")
                    core = read(self.output / "locked-x" / "roles" / role / f"{index}.wav")
                    np.testing.assert_allclose(cue, core + stem, atol=3e-7, rtol=0)

    def test_note_stems_are_equal_level_distinct_and_clean(self) -> None:
        stems = []
        for token, relative in self.manifest["source_graph"]["meaning_note_stems"].items():
            audio = read(self.output / relative)
            metric = self.manifest["qc"]["meaning"][token]
            self.assertAlmostEqual(metric["phone_rms_dbfs"], study.MEANING_RMS_DBFS, delta=0.06)
            self.assertLessEqual(metric["peak_dbfs"], -3.0)
            self.assertLess(metric["final_1ms_relative_peak_db"], -45.0)
            stems.append(audio)
        for left, right in zip(stems, stems[1:]):
            correlation = float(np.corrcoef(left, right)[0, 1])
            self.assertLess(abs(correlation), 0.96)

    def test_phrase_order_is_only_candidate_axis_and_levels_are_fair(self) -> None:
        paired = self.manifest["candidates"]["paired-return"]
        arc = self.manifest["candidates"]["gentle-arc"]
        self.assertEqual(Counter(paired["tokens"]), Counter(arc["tokens"]))
        self.assertEqual(sha(self.output / paired["paths"]["single"]), sha(self.output / arc["paths"]["single"]))
        for kind in ("phrase", "flow", "rapid", "pause_probe"):
            level_a = paired["metrics"][kind]["phone_energy_db"]
            level_b = arc["metrics"][kind]["phone_energy_db"]
            self.assertLess(abs(level_a - level_b), 0.12, kind)
        self.assertEqual(self.manifest["render_contract"]["comparison_axis"], "phrase token order only")

    def test_completion_boundary_and_rapid_tonal_limit_are_exact(self) -> None:
        completion = read(
            self.output
            / self.manifest["locked_completion"]["paths"]["completion-composite.wav"]
        )
        completion_start = round(study.COMPLETION_SELECT_AT * study.SAMPLE_RATE)
        for candidate in self.manifest["candidates"].values():
            flow = read(self.output / candidate["paths"]["flow"])
            np.testing.assert_allclose(
                flow[completion_start:], completion[completion_start:], atol=3e-7, rtol=0
            )

            rapid = read(self.output / candidate["paths"]["rapid"])
            tokens = candidate["tokens"]
            for index, role in enumerate(study.RAPID_ROLES):
                variant = study.weighted.VARIANT_WALK[index]
                gain = study.RATE_GAINS[min(index, len(study.RATE_GAINS) - 1)]
                if index < study.RAPID_TONAL_LIMIT:
                    expected = read(
                        self.output
                        / "cues"
                        / tokens[index]
                        / role
                        / f"{variant + 1}.wav"
                    )
                else:
                    expected = read(
                        self.output
                        / "locked-x"
                        / "roles"
                        / role
                        / f"{variant + 1}.wav"
                    )
                start = round((0.12 + index * study.RAPID_STEP_SECONDS) * study.SAMPLE_RATE)
                actual = rapid[start : start + len(expected)]
                np.testing.assert_allclose(actual, expected * gain, atol=3e-7, rtol=0)

    def test_every_wave_is_phone_safe_and_manifest_hashes_are_complete(self) -> None:
        actual = {}
        for path in sorted(self.output.rglob("*.wav")):
            info = sf.info(path)
            self.assertEqual((info.samplerate, info.channels, info.subtype), (48_000, 1, "PCM_24"))
            audio = read(path)
            self.assertTrue(np.all(np.isfinite(audio)))
            self.assertLess(float(np.max(np.abs(audio))), 1.0)
            actual[path.relative_to(self.output).as_posix()] = sha(path)
        self.assertEqual(self.manifest["generated_audio_asset_count"], len(actual))
        self.assertEqual(self.manifest["generated_audio_sha256"], actual)

    def test_study_build_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            other = study.build_study(Path(temporary) / "study", self.v3)
        self.assertEqual(
            self.manifest["generated_audio_sha256"], other["generated_audio_sha256"]
        )

    def test_sonic_contract_records_pending_physical_pitch_gate(self) -> None:
        contract = json.loads((self.output / "sonic-system.json").read_text(encoding="utf-8"))
        self.assertEqual(contract["format"], "sonic-system/v1")
        self.assertEqual(
            contract["render_contract"]["variant_axis"],
            study.SYSTEM_VARIANT_AXIS,
        )
        self.assertEqual(contract["approval"]["physical_device"], "pending")
        self.assertIn("sounds really great", contract["product"]["owner_quotes"][1])


if __name__ == "__main__":
    unittest.main()
