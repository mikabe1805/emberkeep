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


MODULE_PATH = Path(__file__).parents[1] / "author_click_finish_study.py"
SPEC = importlib.util.spec_from_file_location("author_click_finish_study", MODULE_PATH)
study = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = study
SPEC.loader.exec_module(study)

ANCHOR_ROOT = (
    Path(__file__).parents[2]
    / "design"
    / "audits"
    / "2026-08-20"
    / "weighted-click-system-v1"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class ClickFinishStudyTest(unittest.TestCase):
    def test_matrix_is_three_weights_by_core_plus_four_finishes(self):
        self.assertEqual(["light", "settled", "weighty"], [item.slug for item in study.WEIGHTS])
        self.assertEqual(["room", "page", "lens", "gilt"], [item.slug for item in study.FINISHES])
        families = study.render_families()
        self.assertEqual(3 * 5, len(families))
        self.assertTrue(all(len(items) == study.VARIANT_COUNT for items in families.values()))

    def test_settled_core_is_the_approved_c_signal(self):
        approved = study.anchor.render_families()["c"]
        candidate = study.render_families()["settled-core"]
        for expected, actual in zip(approved, candidate):
            self.assertTrue(np.allclose(expected, actual, rtol=0, atol=5e-16))

    def test_weight_changes_body_without_changing_contact_or_closure_recipe(self):
        light, settled, weighty = study.WEIGHTS
        self.assertLess(light.body_gain, settled.body_gain)
        self.assertLess(settled.body_gain, weighty.body_gain)
        self.assertLess(light.body_decay_ms, settled.body_decay_ms)
        self.assertLess(settled.body_decay_ms, weighty.body_decay_ms)
        families = study.render_families()
        levels = [
            20 * math.log10(study.anchor._phone_band_rms(families[f"{item.slug}-core"][0]))
            for item in study.WEIGHTS
        ]
        self.assertGreater(levels[1], levels[0])
        self.assertGreater(levels[2], levels[1])

    def test_all_primary_clicks_are_prompt_clean_and_parked(self):
        families = study.render_families()
        for family, variants in families.items():
            for audio in variants:
                metrics = study.anchor._metrics(audio, click_aligned=True)
                self.assertEqual(round(study.CLICK_SECONDS * study.SAMPLE_RATE), len(audio), family)
                self.assertLessEqual(metrics["peak_dbfs"], -5.8, family)
                self.assertLess(metrics["onset_ms"], 0.25, family)
                self.assertLess(metrics["tail_after_55ms_relative_peak_db"], -65, family)
                self.assertGreater(metrics["transient_0_4ms"]["centroid_hz"], 1_500, family)
                self.assertLess(metrics["transient_0_4ms"]["centroid_hz"], 3_300, family)
                self.assertLess(metrics["transient_0_4ms"]["air_over_8khz_pct"], 3.5, family)
                self.assertGreater(metrics["body_4_28ms"]["spectral_flatness"], 0.035, family)

    def test_finish_tints_are_distinct_and_level_control_is_matched(self):
        families = study.render_families()
        centroids = []
        for finish in study.FINISHES:
            metrics = study.anchor._metrics(
                families[study.family_id("settled", finish)][0], click_aligned=True
            )
            centroids.append(metrics["transient_0_4ms"]["centroid_hz"])
        self.assertGreater(max(centroids) - min(centroids), 350)

        matched = study.render_families(level_matched=True)
        levels = [
            20 * math.log10(study.anchor._phone_band_rms(study.render_sequence(items)))
            for items in matched.values()
        ]
        self.assertLess(max(levels) - min(levels), 0.05)

    def test_build_copies_anchor_bytes_and_writes_lossless_matrix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = study.build_study(root, ANCHOR_ROOT)
            for index in range(1, study.VARIANT_COUNT + 1):
                source = ANCHOR_ROOT / "variants" / f"dak-c-{index}.wav"
                copied = root / "anchor" / f"c-{index}.wav"
                self.assertEqual(sha256(source), sha256(copied))

            primary = sorted((root / "families").glob("*/*.wav"))
            matched = sorted((root / "level-matched" / "families").glob("*/*.wav"))
            # Settled/core primary points at the five byte-identical anchor files.
            self.assertEqual(14 * study.VARIANT_COUNT, len(primary))
            self.assertEqual(15 * study.VARIANT_COUNT, len(matched))
            infos = [sf.info(path) for path in primary + matched]
            self.assertEqual({study.SAMPLE_RATE}, {item.samplerate for item in infos})
            self.assertEqual({1}, {item.channels for item in infos})
            self.assertEqual({"PCM_24"}, {item.subtype for item in infos})
            manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
            self.assertTrue(manifest["approved_anchor"]["copied_byte_for_byte"])
            self.assertEqual(15, len(manifest["families"]))
            self.assertEqual("PCM_24 mono", report["sample_format"])


if __name__ == "__main__":
    unittest.main()
