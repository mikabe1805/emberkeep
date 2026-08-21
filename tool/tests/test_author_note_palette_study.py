import importlib.util
import math
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf


MODULE_PATH = Path(__file__).parents[1] / "author_note_palette_study.py"
SPEC = importlib.util.spec_from_file_location("author_note_palette_study", MODULE_PATH)
study = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = study
SPEC.loader.exec_module(study)


class NotePaletteStudyTest(unittest.TestCase):
    def test_palettes_change_grammar_without_changing_phrase_length(self):
        self.assertEqual(6, len(study.PALETTES))
        self.assertEqual({8}, {len(palette.phrase) for palette in study.PALETTES})
        self.assertEqual(6, len({palette.phrase for palette in study.PALETTES}))
        for palette in study.PALETTES:
            self.assertTrue(set(palette.phrase).issubset(set(palette.collection)))

    def test_carrier_is_fast_clean_and_tuned(self):
        audio = study.synth_note(study.ROOT_MIDI)
        self.assertTrue(np.array_equal(audio, study.synth_note(study.ROOT_MIDI)))
        self.assertEqual((round(study.NOTE_DURATION_SECONDS * study.SAMPLE_RATE), 2), audio.shape)
        self.assertTrue(np.all(np.isfinite(audio)))
        self.assertLess(float(np.max(np.abs(audio))), 1.0)
        mono = np.mean(audio, axis=1)
        audible = np.flatnonzero(np.abs(mono) >= 10 ** (-60 / 20))
        self.assertLess(audible[0] / study.SAMPLE_RATE, 0.005)
        tail_rms = math.sqrt(float(np.mean(mono[-round(0.010 * study.SAMPLE_RATE):] ** 2)))
        body_rms = math.sqrt(float(np.mean(mono[:round(0.100 * study.SAMPLE_RATE)] ** 2)))
        self.assertLess(tail_rms, body_rms * 0.15)

        spectrum = np.abs(np.fft.rfft(mono * np.hanning(len(mono))))
        frequencies = np.fft.rfftfreq(len(mono), 1 / study.SAMPLE_RATE)
        dominant = float(frequencies[int(np.argmax(spectrum))])
        self.assertAlmostEqual(study.midi_frequency(study.ROOT_MIDI), dominant, delta=8.0)

    def test_build_writes_uniform_lossless_blind_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = study.build_study(root)
            files = sorted(root.glob("palette-?.wav"))
            self.assertEqual(6, len(files))
            infos = [sf.info(path) for path in files]
            self.assertEqual({study.SAMPLE_RATE}, {info.samplerate for info in infos})
            self.assertEqual({2}, {info.channels for info in infos})
            self.assertEqual({"PCM_24"}, {info.subtype for info in infos})
            self.assertEqual(1, len({info.frames for info in infos}))
            self.assertEqual("D5", report["root_note"])
            self.assertTrue((root / "note-palette-full-reel.wav").exists())
            self.assertTrue((root / "note-palette-rapid-reel.wav").exists())
            self.assertTrue((root / "manifest.json").exists())


if __name__ == "__main__":
    unittest.main()
