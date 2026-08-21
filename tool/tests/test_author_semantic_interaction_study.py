import hashlib
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf


MODULE_PATH = Path(__file__).parents[1] / "author_semantic_interaction_study.py"
SPEC = importlib.util.spec_from_file_location("author_semantic_interaction_study", MODULE_PATH)
study = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = study
SPEC.loader.exec_module(study)

REPO_ROOT = Path(__file__).parents[2]
APPROVED_C = REPO_ROOT / "design" / "audits" / "2026-08-20" / "weighted-click-system-v1"
CURRENT_COMPLETE = REPO_ROOT / "assets" / "sfx" / "complete.wav"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SemanticInteractionStudyTest(unittest.TestCase):
    def test_tak_and_tuk_are_distinct_families(self):
        tak = study.render_open_tak()
        tuk = study.render_select_tuk()
        self.assertEqual(study.VARIANT_COUNT, len(tak))
        self.assertEqual(study.VARIANT_COUNT, len(tuk))
        self.assertEqual(round(study.TAK_SECONDS * study.SAMPLE_RATE), len(tak[0]))
        self.assertEqual(round(study.TUK_SECONDS * study.SAMPLE_RATE), len(tuk[0]))
        tak_metrics = study.anchor._metrics(tak[0], click_aligned=True)
        tuk_metrics = study.anchor._metrics(tuk[0], click_aligned=True)
        self.assertGreater(tak_metrics["body_4_28ms"]["centroid_hz"], tuk_metrics["body_4_28ms"]["centroid_hz"] + 250)
        self.assertGreater(tak_metrics["contact_to_body_rms_db"], tuk_metrics["contact_to_body_rms_db"])

    def test_note_walk_is_audible_but_role_bounded(self):
        self.assertGreater(max(study.TAK_CENTS) - min(study.TAK_CENTS), 240)
        self.assertGreater(max(study.TUK_CENTS) - min(study.TUK_CENTS), 240)
        self.assertLessEqual(max(map(abs, study.TAK_CENTS)), 200)
        self.assertLessEqual(max(map(abs, study.TUK_CENTS)), 200)
        tak = study.render_open_tak()
        tuk = study.render_select_tuk()
        self.assertFalse(np.allclose(tak[0], tak[3]))
        self.assertFalse(np.allclose(tuk[0], tuk[3]))

    def test_generated_clicks_are_clean_and_parked(self):
        for family, variants, tail_start_ms in (
            ("tak", study.render_open_tak(), 34.0),
            ("tuk", study.render_select_tuk(), 45.0),
        ):
            for audio in variants:
                peak = float(np.max(np.abs(audio)))
                tail = audio[round(tail_start_ms / 1000 * study.SAMPLE_RATE):]
                tail_peak = float(np.max(np.abs(tail))) if len(tail) else 0.0
                self.assertLessEqual(20 * np.log10(peak or 1e-12), -8.9, family)
                self.assertLess(20 * np.log10((tail_peak or 1e-12) / (peak or 1e-12)), -50, family)
                metrics = study.anchor._metrics(audio, click_aligned=True)
                self.assertLess(metrics["onset_ms"], 0.25, family)
                self.assertLess(metrics["transient_0_4ms"]["air_over_8khz_pct"], 4.0, family)

    def test_build_preserves_both_user_approved_anchors(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest = study.build_study(root, APPROVED_C, CURRENT_COMPLETE)
            for index in range(1, study.VARIANT_COUNT + 1):
                self.assertEqual(
                    sha256(APPROVED_C / "variants" / f"dak-c-{index}.wav"),
                    sha256(root / "roles" / "navigate-dak" / f"{index}.wav"),
                )
            self.assertEqual(
                sha256(CURRENT_COMPLETE),
                sha256(root / "roles" / "complete-bloop" / "current.wav"),
            )
            self.assertFalse(manifest["runtime_changed"])

    def test_build_writes_lossless_generated_roles_and_valid_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            study.build_study(root, APPROVED_C, CURRENT_COMPLETE)
            generated = sorted((root / "roles" / "open-tak").glob("*.wav"))
            generated += sorted((root / "roles" / "select-tuk").glob("*.wav"))
            self.assertEqual(10, len(generated))
            infos = [sf.info(path) for path in generated]
            self.assertEqual({study.SAMPLE_RATE}, {item.samplerate for item in infos})
            self.assertEqual({1}, {item.channels for item in infos})
            self.assertEqual({"PCM_24"}, {item.subtype for item in infos})
            parsed = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(
                {"navigate-dak", "open-tak", "select-tuk", "complete-bloop"},
                set(parsed["roles"]),
            )
            self.assertTrue((root / "normal-flow.wav").exists())


if __name__ == "__main__":
    unittest.main()
