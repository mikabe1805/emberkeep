from __future__ import annotations

import hashlib
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

import author_room_phone_click_v2_study as study  # noqa: E402
import author_room_sonic_world_study as world  # noqa: E402


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class RoomPhoneClickV2StudyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.room = ROOT / "design/audits/2026-08-20/room-sonic-world-v1"
        cls.reward = ROOT / "design/audits/2026-08-20/room-reward-voice-v1"

    def build(self, output: Path) -> dict[str, object]:
        return study.build_study(output, self.room, self.reward)

    def test_deterministic_and_sources_immutable(self) -> None:
        watched = [
            self.room / "shared/contact-master.wav",
            self.reward / "rewards/answered-detent/natural.wav",
            *[
                self.room / "roles" / role / f"{index}.wav"
                for role in study.ORDINARY_ROLES
                for index in range(1, study.VARIANT_COUNT + 1)
            ],
        ]
        before = {path: sha256(path) for path in watched}
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_root = Path(first) / "study"
            a = self.build(first_root)
            b = self.build(Path(second) / "study")
            self.assertEqual(a["generated_audio_sha256"], b["generated_audio_sha256"])
            self.assertEqual(len(a["generated_audio_sha256"]), 87)
            self.assertEqual(
                a["generated_audio_sha256"],
                {
                    path.relative_to(first_root).as_posix(): sha256(path)
                    for path in sorted(first_root.rglob("*.wav"))
                },
            )
            self.assertFalse(a["runtime_changed"])
        self.assertEqual(before, {path: sha256(path) for path in watched})

    def test_pcm_clean_tails_and_locked_completion(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            for relative in manifest["generated_audio_sha256"]:
                path = output / relative
                info = sf.info(path)
                self.assertEqual((info.samplerate, info.channels, info.subtype), (study.SAMPLE_RATE, 1, "PCM_24"))
                audio, _ = sf.read(path, dtype="float64")
                self.assertTrue(np.all(np.isfinite(audio)))
                self.assertLess(float(np.max(np.abs(audio))), 1.0)
            self.assertEqual(sha256(self.reward / "rewards/answered-detent/natural.wav"), sha256(output / "locked/answered-detent-natural.wav"))
            completion, _ = sf.read(output / "locked/completion-composite.wav", dtype="float64")
            for candidate in manifest["candidates"].values():
                flow, _ = sf.read(output / candidate["flow"], dtype="float64")
                start = round(study.COMPLETION_SELECT_AT * study.SAMPLE_RATE)
                np.testing.assert_allclose(flow[start:], completion[start:], atol=2e-7, rtol=0)
            self.assertEqual(manifest["locked_completion"]["outcome_delay_ms"], 75.0)

    def test_texture_energy_contrast_and_level_steps(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            ledger = manifest["candidates"]["ledger-edge@+3.0dB"]
            seat = manifest["candidates"]["double-seat@+3.0dB"]
            for candidate in manifest["candidates"].values():
                for role_metrics in candidate["metrics"].values():
                    for metrics in role_metrics:
                        self.assertLess(metrics["tail_relative_peak_db"], -40.0)
            for role in study.ORDINARY_ROLES:
                a, _ = sf.read(output / ledger["role_paths"][role][0], dtype="float64")
                b, _ = sf.read(output / seat["role_paths"][role][0], dtype="float64")
                self.assertLess(abs(20 * math.log10(world._phone_rms(a) / world._phone_rms(b))), 0.05)
            self.assertGreater(ledger["metrics"]["select"][0]["edge_1600_4200_energy"], 1e-6)
            self.assertGreater(seat["metrics"]["place"][0]["seat_650_1800_energy"], ledger["metrics"]["place"][0]["seat_650_1800_energy"] * 1.15)
            ratio_a = ledger["metrics"]["place"][0]["low_250_450_energy"] / ledger["metrics"]["place"][0]["seat_650_1800_energy"]
            ratio_b = seat["metrics"]["place"][0]["low_250_450_energy"] / seat["metrics"]["place"][0]["seat_650_1800_energy"]
            self.assertLess(ratio_b, ratio_a)
            for texture in study.TEXTURES:
                a = manifest["candidates"][f"{texture}@+2.0dB"]["metrics"]["select"][0]["phone_rms_dbfs"]
                b = manifest["candidates"][f"{texture}@+3.5dB"]["metrics"]["select"][0]["phone_rms_dbfs"]
                self.assertAlmostEqual(b - a, 1.5, delta=0.03)

    def test_rapid_runs_are_safe(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            manifest = self.build(output)
            for candidate in manifest["candidates"].values():
                rapid, _ = sf.read(output / candidate["rapid"], dtype="float64")
                self.assertTrue(np.all(np.isfinite(rapid)))
                self.assertLess(float(np.max(np.abs(rapid))), 1.0)
                self.assertAlmostEqual(len(rapid) / study.SAMPLE_RATE, 2.25, delta=1 / study.SAMPLE_RATE)


if __name__ == "__main__":
    unittest.main()
