import importlib.util
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf


MODULE_PATH = Path(__file__).parents[1] / "author_stone_texture_study.py"
SPEC = importlib.util.spec_from_file_location("author_stone_texture_study", MODULE_PATH)
study = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = study
SPEC.loader.exec_module(study)


def make_fixture(path: Path) -> None:
    frames = round(0.62 * study.SAMPLE_RATE)
    t = np.arange(frames, dtype=np.float64) / study.SAMPLE_RATE
    audio = np.zeros((frames, 2), dtype=np.float64)
    for onset, gain in ((0.0068, 0.58), (0.1286, 0.72), (0.1597, 0.11)):
        local = np.maximum(0.0, t - onset)
        envelope = (local >= 0) * np.exp(-local / 0.020)
        body = np.sin(2 * math.pi * 520 * local) + 0.42 * np.sin(2 * math.pi * 1370 * local)
        hit = gain * envelope * body
        audio[:, 0] += hit
        audio[:, 1] += np.pad(hit[:-3], (3, 0)) * 0.98
    peak = float(np.max(np.abs(audio))) or 1.0
    sf.write(path, audio * 0.88 / peak, study.SAMPLE_RATE, subtype="PCM_16")


class StoneTextureStudyTest(unittest.TestCase):
    def test_candidate_set_is_blind_and_changes_texture_only(self):
        self.assertEqual(tuple("abcdef"), tuple(item.slug for item in study.CANDIDATES))
        self.assertEqual({study.TAP_SECONDS}, {study.TAP_SECONDS for _ in study.CANDIDATES})
        self.assertEqual(2, len(study.CONTACT_CROPS))
        self.assertTrue(all(item.raw_gain > 0 for item in study.CANDIDATES))
        self.assertEqual(0.0, study.CANDIDATES[0].body_gain)
        self.assertEqual(0.0, study.CANDIDATES[0].mineral_gain)
        self.assertTrue(any(item.body_gain for item in study.CANDIDATES))
        self.assertTrue(any(item.mineral_gain for item in study.CANDIDATES))

    def test_source_hash_is_enforced(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "fixture.wav"
            make_fixture(source)
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                study.load_source(source)
            audio, record = study.load_source(source, expected_sha256=None)
            self.assertEqual(study.SAMPLE_RATE, record["sample_rate_hz"])
            self.assertEqual(2, audio.shape[1])

    def test_taps_are_deterministic_prompt_and_clean(self):
        with tempfile.TemporaryDirectory() as directory:
            source_path = Path(directory) / "fixture.wav"
            make_fixture(source_path)
            source, _ = study.load_source(source_path, expected_sha256=None)
            tap = study.render_tap(source, study.CANDIDATES[3], 0)
            self.assertTrue(np.array_equal(tap, study.render_tap(source, study.CANDIDATES[3], 0)))
            self.assertEqual((round(study.TAP_SECONDS * study.SAMPLE_RATE), 2), tap.shape)
            self.assertTrue(np.all(np.isfinite(tap)))
            self.assertLess(float(np.max(np.abs(tap))), 1.0)
            mono = np.mean(tap, axis=1)
            audible = np.flatnonzero(np.abs(mono) >= 10 ** (-60 / 20))
            self.assertLess(audible[0] / study.SAMPLE_RATE, 0.012)
            tail = math.sqrt(float(np.mean(mono[-round(0.012 * study.SAMPLE_RATE):] ** 2)))
            body = math.sqrt(float(np.mean(mono[:round(0.100 * study.SAMPLE_RATE)] ** 2)))
            self.assertLess(tail, body * 0.16)

    def test_build_writes_uniform_lossless_candidates_and_provenance(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "fixture.wav"
            output = root / "study"
            make_fixture(source)
            report = study.build_study(source, output, expected_source_sha256=None)
            files = sorted(output.glob("stone-?.wav"))
            self.assertEqual(6, len(files))
            infos = [sf.info(path) for path in files]
            self.assertEqual({study.SAMPLE_RATE}, {info.samplerate for info in infos})
            self.assertEqual({2}, {info.channels for info in infos})
            self.assertEqual({"PCM_24"}, {info.subtype for info in infos})
            self.assertEqual(1, len({info.frames for info in infos}))
            self.assertTrue((output / "stone-texture-full-reel.wav").exists())
            self.assertTrue((output / "stone-texture-rapid-reel.wav").exists())
            manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
            self.assertEqual(6, len(manifest["candidates"]))
            self.assertEqual(report["source"]["sha256"], manifest["source"]["sha256"])


if __name__ == "__main__":
    unittest.main()
