import hashlib
import importlib.util
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf


MODULE_PATH = Path(__file__).parents[1] / "author_weighted_click_study.py"
SPEC = importlib.util.spec_from_file_location("author_weighted_click_study", MODULE_PATH)
study = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = study
SPEC.loader.exec_module(study)


class WeightedClickStudyTest(unittest.TestCase):
    def test_mechanisms_and_walk_define_a_small_nonrepeating_system(self):
        self.assertEqual(tuple("abcd"), tuple(item.slug for item in study.MECHANISMS))
        self.assertEqual(study.VARIANT_COUNT, len(study.PITCH_MULTIPLIERS))
        self.assertEqual(study.VARIANT_COUNT, len(study.VARIANT_GAIN_DB))
        self.assertTrue(all(a != b for a, b in zip(study.VARIANT_WALK, study.VARIANT_WALK[1:])))
        self.assertTrue(all(0 <= item < study.VARIANT_COUNT for item in study.VARIANT_WALK))
        a, b, c, d = study.MECHANISMS
        self.assertEqual((a.body_gain, a.body_decay_ms), (c.body_gain, c.body_decay_ms))
        self.assertEqual((b.body_gain, b.body_decay_ms), (d.body_gain, d.body_decay_ms))
        self.assertEqual(0.0, a.closure_gain)
        self.assertEqual(0.0, b.closure_gain)
        self.assertEqual(c.closure_gain, d.closure_gain)
        self.assertGreater(b.body_gain, a.body_gain)

    def test_click_is_deterministic_prompt_short_and_clean(self):
        click = study.synth_click_raw(study.MECHANISMS[2], 3)
        self.assertTrue(np.array_equal(click, study.synth_click_raw(study.MECHANISMS[2], 3)))
        self.assertEqual(round(study.CLICK_SECONDS * study.SAMPLE_RATE), len(click))
        self.assertTrue(np.all(np.isfinite(click)))
        self.assertGreater(float(np.max(np.abs(click))), 0.01)
        audible = np.flatnonzero(np.abs(click) >= 10 ** (-60 / 20))
        self.assertLess(audible[0] / study.SAMPLE_RATE, 0.003)
        body_rms = math.sqrt(float(np.mean(click[:round(0.050 * study.SAMPLE_RATE)] ** 2)))
        tail_rms = math.sqrt(float(np.mean(click[-round(0.010 * study.SAMPLE_RATE):] ** 2)))
        self.assertLess(tail_rms, body_rms * 0.10)
        metrics = study._metrics(click, click_aligned=True)
        self.assertLess(metrics["tail_after_55ms_relative_peak_db"], -40)
        self.assertGreater(metrics["transient_0_4ms"]["centroid_hz"], 1_500)
        self.assertGreater(metrics["body_4_28ms"]["spectral_flatness"], 0.02)

    def test_variants_are_distinct_but_level_controlled(self):
        variants = study.render_variants(study.MECHANISMS[1])
        hashes = {hashlib.sha256(item.tobytes()).hexdigest() for item in variants}
        self.assertEqual(study.VARIANT_COUNT, len(hashes))
        levels = [20 * math.log10(study._phone_band_rms(item)) for item in variants]
        self.assertLess(max(levels) - min(levels), 1.6)
        self.assertLess(max(float(np.max(np.abs(item))) for item in variants), 1.0)

    def test_candidates_share_contact_and_rapid_envelope_is_stable(self):
        rate = study.SAMPLE_RATE * study.OVERSAMPLE
        t = np.arange(round(study.CLICK_SECONDS * rate), dtype=np.float64) / rate
        reference = study._contact_layer(2, t, rate)
        for _ in study.MECHANISMS:
            self.assertTrue(np.array_equal(reference, study._contact_layer(2, t, rate)))
        self.assertEqual(
            [1.0, 0.93, 0.93, 0.885, 0.885],
            [study.rate_gain(index, 105 if index else None) for index in range(5)],
        )

    def test_primary_peaks_are_close_and_level_control_is_energy_matched(self):
        primary = study.render_families()
        for variant_index in range(study.VARIANT_COUNT):
            peaks = [
                20 * math.log10(float(np.max(np.abs(primary[item.slug][variant_index]))))
                for item in study.MECHANISMS
            ]
            self.assertLess(max(peaks) - min(peaks), 1.5)
        matched = study.render_families(level_matched=True)
        rapid_levels = []
        for item in study.MECHANISMS:
            _, _, rapid = study.render_candidate(matched[item.slug])
            rapid_levels.append(20 * math.log10(study._phone_band_rms(rapid)))
        self.assertLess(max(rapid_levels) - min(rapid_levels), 0.1)

    def test_build_writes_lossless_blind_families_and_reels(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = study.build_study(root)
            candidates = sorted(root.glob("dak-?.wav"))
            variants = sorted((root / "variants").glob("dak-?-?.wav"))
            matched_variants = sorted((root / "level-matched" / "variants").glob("dak-?-?.wav"))
            self.assertEqual(4, len(candidates))
            self.assertEqual(4 * study.VARIANT_COUNT, len(variants))
            self.assertEqual(4 * study.VARIANT_COUNT, len(matched_variants))
            infos = [sf.info(path) for path in candidates + variants + matched_variants]
            self.assertEqual({study.SAMPLE_RATE}, {item.samplerate for item in infos})
            self.assertEqual({1}, {item.channels for item in infos})
            self.assertEqual({"PCM_24"}, {item.subtype for item in infos})
            candidate_infos = [sf.info(path) for path in candidates]
            self.assertEqual(1, len({item.frames for item in candidate_infos}))
            self.assertTrue((root / "weighted-click-full-reel.wav").exists())
            self.assertTrue((root / "weighted-click-rapid-reel.wav").exists())
            self.assertTrue((root / "level-matched" / "weighted-click-rapid-reel.wav").exists())
            manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(4, len(manifest["candidates"]))
            self.assertEqual(4, len(manifest["families"]))
            self.assertFalse(manifest["source"]["recorded_foley"])
            self.assertEqual(110, manifest["rate_envelope"]["rapid_threshold_ms"])
            self.assertEqual("PCM_24 mono", report["sample_format"])


if __name__ == "__main__":
    unittest.main()
