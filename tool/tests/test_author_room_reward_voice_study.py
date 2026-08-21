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

import author_room_reward_voice_study as reward  # noqa: E402
import author_room_sonic_world_study as world  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def band_energy(audio: np.ndarray, low: float, high: float) -> float:
    probe = world._filter(audio, highpass_hz=low, lowpass_hz=high, order=3)
    return float(np.sum(probe * probe))


class RoomRewardVoiceStudyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.room = ROOT / "design/audits/2026-08-20/room-sonic-world-v1"
        cls.previous = cls.room / "flows/control-current-natural.wav"
        cls.previous_reward = ROOT / "design/audits/2026-08-20/semantic-interaction-voices-v1/roles/complete-bloop/current.wav"

    def build(self, output: Path) -> dict[str, object]:
        return reward.build_study(output, self.room, self.previous, self.previous_reward)

    def test_build_is_staging_only_and_preserves_locked_inputs(self) -> None:
        watched = [
            self.room / "shared/contact-master.wav",
            self.room / "roles/complete-bloom/2.wav",
            self.room / "roles/open/1.wav",
            self.previous,
            self.previous_reward,
        ]
        before = {path: sha256(path) for path in watched}
        with tempfile.TemporaryDirectory() as temporary:
            manifest = self.build(Path(temporary) / "study")
            self.assertFalse(manifest["runtime_changed"])
            self.assertFalse(manifest["provenance"]["shipping_assets_changed"])
            self.assertFalse(manifest["provenance"]["reference_video_audio_used"])
            self.assertEqual(manifest["render_contract"]["outcome_delay_ms"], 75.0)
            self.assertEqual(manifest["locked_everyday_family"]["roles"], ["open", "select", "navigate", "place"])
        self.assertEqual(before, {path: sha256(path) for path in watched})

    def test_audio_is_deterministic_pcm24_mono_finite_and_unclipped(self) -> None:
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            first_root = Path(first) / "study"
            second_root = Path(second) / "study"
            first_manifest = self.build(first_root)
            second_manifest = self.build(second_root)
            self.assertEqual(
                first_manifest["generated_audio_sha256"],
                second_manifest["generated_audio_sha256"],
            )
            self.assertEqual(len(first_manifest["generated_audio_sha256"]), 29)
            for relative, expected_hash in first_manifest["generated_audio_sha256"].items():
                path = first_root / relative
                info = sf.info(path)
                self.assertEqual(info.samplerate, reward.SAMPLE_RATE)
                self.assertEqual(info.channels, 1)
                self.assertEqual(info.subtype, "PCM_24")
                audio, _ = sf.read(path, dtype="float64")
                self.assertTrue(np.all(np.isfinite(audio)))
                self.assertLess(float(np.max(np.abs(audio))), 1.0)
                self.assertEqual(sha256(path), expected_hash)

    def test_baseline_is_exact_and_compound_delay_is_atomic(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            self.build(output)
            baseline_source = self.room / "roles/complete-bloom/2.wav"
            self.assertEqual(sha256(baseline_source), sha256(output / "rewards/baseline/matched.wav"))
            delay = round(reward.OUTCOME_DELAY_SECONDS * reward.SAMPLE_RATE)
            composites = []
            for reward_id in ("baseline", *reward.MECHANISMS):
                audio, _ = sf.read(output / "composites" / reward_id / "matched.wav", dtype="float64")
                composites.append(audio)
            reference = composites[0][:delay]
            for audio in composites[1:]:
                np.testing.assert_array_equal(audio[:delay], reference)
            self.assertGreater(
                max(float(np.max(np.abs(audio[delay:] - composites[0][delay:]))) for audio in composites[1:]),
                1e-3,
            )

    def test_matched_energy_and_unchanged_flow_prefix_are_exact(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            self.build(output)
            reward_audio = {}
            flow_audio = {}
            for reward_id in ("baseline", *reward.MECHANISMS):
                reward_audio[reward_id], _ = sf.read(output / "rewards" / reward_id / "matched.wav", dtype="float64")
                flow_audio[reward_id], _ = sf.read(output / "flows" / reward_id / "matched.wav", dtype="float64")
            energies = [reward._phone_energy(audio) for audio in reward_audio.values()]
            spread_db = 20 * math.log10(max(energies) / min(energies))
            self.assertLess(spread_db, 0.002)
            onset = round(5.375 * reward.SAMPLE_RATE)
            baseline_prefix = flow_audio["baseline"][:onset]
            for reward_id in reward.MECHANISMS:
                np.testing.assert_array_equal(flow_audio[reward_id][:onset], baseline_prefix)
            flow_energies = [reward._phone_energy(audio) for audio in flow_audio.values()]
            flow_spread_db = 20 * math.log10(max(flow_energies) / min(flow_energies))
            self.assertLess(flow_spread_db, 0.002)

            final_control, _ = sf.read(
                output / "controls/previous-reward-locked-family-flow.wav",
                dtype="float64",
            )
            np.testing.assert_array_equal(final_control[:onset], baseline_prefix)

    def test_challengers_have_the_intended_mechanism_contrast(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "study"
            self.build(output)
            audio = {
                reward_id: sf.read(output / "rewards" / reward_id / "matched.wav", dtype="float64")[0]
                for reward_id in ("baseline", *reward.MECHANISMS)
            }
            first_ten = round(0.010 * reward.SAMPLE_RATE)
            baseline_early = float(np.sum(audio["baseline"][:first_ten] ** 2) / np.sum(audio["baseline"] ** 2))
            edge_early = float(np.sum(audio["receipt-edge"][:first_ten] ** 2) / np.sum(audio["receipt-edge"] ** 2))
            self.assertGreater(edge_early, baseline_early * 2.0)

            baseline_presence = band_energy(audio["baseline"], 2_000, 6_500) / float(
                np.sum(audio["baseline"] ** 2)
            )
            receipt_presence = band_energy(audio["receipt-edge"], 2_000, 6_500) / float(
                np.sum(audio["receipt-edge"] ** 2)
            )
            answered_presence = band_energy(audio["answered-detent"], 2_000, 6_500) / float(
                np.sum(audio["answered-detent"] ** 2)
            )
            self.assertGreater(receipt_presence, baseline_presence * 1.25)
            self.assertGreater(answered_presence, baseline_presence * 1.15)

            baseline_low = band_energy(audio["baseline"], 170, 600)
            seated_low = band_energy(audio["seated-catch"], 170, 600)
            self.assertGreater(seated_low, baseline_low * 1.8)

            def median_ms(item: np.ndarray) -> float:
                cumulative = np.cumsum(item * item)
                return float(np.searchsorted(cumulative, cumulative[-1] * 0.5) / reward.SAMPLE_RATE * 1000)

            self.assertGreater(median_ms(audio["answered-detent"]), median_ms(audio["baseline"]) + 20)

            baseline_energy = reward._phone_energy(audio["baseline"])
            for reward_id in reward.MECHANISMS:
                natural, _ = sf.read(output / "rewards" / reward_id / "natural.wav", dtype="float64")
                lift = 20 * math.log10(reward._phone_energy(natural) / baseline_energy)
                self.assertAlmostEqual(lift, reward.NATURAL_LIFT_DB, places=3)


if __name__ == "__main__":
    unittest.main()
