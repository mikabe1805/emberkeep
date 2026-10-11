from __future__ import annotations

import hashlib
import json
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TOOL_ROOT = ROOT / "tool"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))

import author_class_day_score as score  # noqa: E402

MANIFEST = ROOT / "design/audits/2026-10-11/class-day-score/manifest.json"
SKETCH = Path("C:/tmp/cdj/sound-v3")


class ClassDayScoreTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        # One render of the five stems (about ten seconds) serves every test.
        cls.raw = score.render_raw_stems()
        cls.scaled_raw, cls.scaled_folded, cls.gains = score.scale_stems(cls.raw)
        cls.beds = score.build_beds(cls.scaled_raw, cls.scaled_folded)
        cls.swells = score.build_swells(cls.scaled_folded, cls.beds["between"])

    def test_the_form_is_the_sketchs(self) -> None:
        self.assertEqual(score.BPM, 72.0)
        self.assertEqual(score.BARS, 16)
        self.assertEqual(score.N, 2_560_000)  # 53.333 s at 48 kHz
        self.assertEqual(score.SR, 48_000)
        self.assertEqual(len(score.CHORD_BARS), 16)
        self.assertEqual(score.SWELL_COUNT, 32)  # every strong beat of 64

    def test_the_stems_are_the_sketchs_stems(self) -> None:
        # Re-rendered, they are the stems the owner heard, sample for sample
        # (hashes of the int16 samples the sketch wrote), and what this tool
        # recorded when it built the shipped files.
        for name in score.STEM_NAMES:
            ours = score.int16_sha(self.scaled_folded[name])
            self.assertEqual(
                ours, self.manifest["stems"][name]["int16_sha256"], name
            )
        if SKETCH.exists():
            import soundfile as sf

            for name in score.STEM_NAMES:
                theirs, _sr = sf.read(str(SKETCH / "music/stems" / f"{name}.wav"), dtype="int16")
                self.assertTrue(
                    np.array_equal(theirs, score.int16_of(self.scaled_folded[name])), name
                )

    def test_rendering_is_deterministic(self) -> None:
        again = score.render_keys()
        self.assertTrue(np.array_equal(again, self.raw["keys"]))

    def test_two_chained_passes_are_the_circular_loop(self) -> None:
        # The app starts pass 2 exactly one form after pass 1 while pass 1
        # rings out. Added together they must equal the sketch's circular loop
        # over the overlap, or the seam would be audible.
        for name, bed in self.beds.items():
            full = bed["audio_full"]
            pass1 = bed["audio"]
            tail = len(pass1) - score.N
            loop = score.fold(full)
            # Pass 2 begins N samples after pass 1: its first `tail` samples
            # land on pass 1's tail.
            together = pass1[score.N:] + pass1[:tail]
            err = np.max(np.abs(together - loop[:tail]))
            # The only difference allowed is the 50 ms end fade on a tail that
            # has already died away.
            self.assertLess(err, 1e-9, name)

    def test_the_tail_that_is_cut_was_already_silent(self) -> None:
        for name, bed in self.beds.items():
            self.assertLess(bed["cut_tail_peak_db"], -80, name)

    def test_beds_sit_at_the_rotations_level(self) -> None:
        for name, bed in self.beds.items():
            circular = score.fold(bed["audio_full"])
            self.assertAlmostEqual(score.phone_rms_db(circular), score.BED_TARGET_DB, delta=0.02, msg=name)
        # The sketch's own levels, before the bed gain.
        self.assertAlmostEqual(self.beds["between"]["sketch_phone_rms_db"], -36.83, delta=0.05)
        self.assertAlmostEqual(self.beds["evening"]["sketch_phone_rms_db"], -35.81, delta=0.05)

    def test_there_are_thirty_two_swells_each_two_bars_long_with_clean_edges(self) -> None:
        self.assertEqual(len(self.swells), 32)
        want = round((score.SWELL_PREROLL_S + score.SWELL_HOLD_BARS * score.BAR + score.SWELL_TAIL_S) * score.SR)
        held = slice(
            round(score.SWELL_PREROLL_S * score.SR),
            round((score.SWELL_PREROLL_S + score.SWELL_HOLD_BARS * score.BAR) * score.SR),
        )
        for k, swell in enumerate(self.swells):
            audio = swell["audio"]
            self.assertEqual(len(audio), want, k)
            self.assertEqual(swell["beat"], 2 * k)
            self.assertLess(abs(audio[0]), 1e-9, k)
            self.assertLess(abs(audio[-1]), 1e-9, k)
            self.assertAlmostEqual(score.phone_rms_db(audio[held]), score.SWELL_TARGET_DB, delta=0.02, msg=str(k))

    def test_the_envelope_rises_to_the_beat_holds_two_bars_then_releases(self) -> None:
        n = round((score.SWELL_PREROLL_S + score.SWELL_HOLD_BARS * score.BAR + score.SWELL_TAIL_S) * score.SR)
        env = score.swell_envelope(n)
        beat = round(score.SWELL_PREROLL_S * score.SR)
        rise = round(score.SWELL_RISE_S * score.SR)
        self.assertEqual(float(env[0]), 0.0)
        self.assertLess(float(env[beat - rise - 10]), 1e-6, "silent until the rise begins")
        self.assertAlmostEqual(float(env[beat]), 1.0, places=3, msg="full on the beat")
        self.assertLess(float(env[beat - rise // 2]), 0.6, "half way up half way through")
        self.assertGreater(float(env[beat - rise // 2]), 0.4)
        end_hold = beat + round(score.SWELL_HOLD_BARS * score.BAR * score.SR)
        self.assertTrue(np.allclose(env[beat:end_hold - 5], 1.0, atol=1e-6), "held for two bars")
        after = round(score.SWELL_RELEASE_TAU_S * score.SR)
        self.assertAlmostEqual(float(env[end_hold + after]), float(np.exp(-1)), places=2)
        self.assertLess(float(env[-1]), 1e-9)

    def test_a_swell_is_cut_from_the_bar_it_belongs_to(self) -> None:
        # Swell k is the window of the circular bass and bells starting 150 ms
        # before beat 2k, so beat 2k sits 150 ms into the file.
        src = score.SWELL_GAIN * (self.scaled_folded["bass"] + self.scaled_folded["bells"])
        for k in (0, 7, 31):
            start = round((2 * k * score.BEAT - score.SWELL_PREROLL_S) * score.SR)
            n = len(self.swells[k]["audio"])
            window = src[(start + np.arange(n)) % score.N]
            audio = self.swells[k]["audio"]
            held = slice(round(0.2 * score.SR), round(6.0 * score.SR))
            # The same signal, scaled by the envelope (1.0 in the hold) and a
            # per-file trim: their ratio is the trim, a constant.
            ratio = audio[held] / np.where(np.abs(window[held]) < 1e-9, np.nan, window[held])
            ratio = ratio[np.isfinite(ratio)]
            trim = 10 ** (self.swells[k]["trim_db"] / 20)
            # trim_db is recorded to 0.01 dB: a ratio within 0.2%.
            self.assertLess(abs(float(np.median(ratio)) / trim - 1), 0.002, k)

    def test_the_webaudio_lowpass_is_a_lowpass(self) -> None:
        t = np.arange(48_000) / score.SR
        low = np.sin(2 * np.pi * 100 * t)
        high = np.sin(2 * np.pi * 8_000 * t)
        out_low = score.webaudio_lowpass(low, 900.0)
        out_high = score.webaudio_lowpass(high, 900.0)
        self.assertGreater(np.max(np.abs(out_low[2000:])), 0.98)
        self.assertLess(np.max(np.abs(out_high[2000:])), 0.02)

    def test_the_manifest_matches_the_files_on_disk(self) -> None:
        records = self.manifest["records"]
        self.assertEqual(len(records), 34)
        for rel, record in records.items():
            data = (ROOT / rel).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record["sha256"], rel)
            self.assertEqual(len(data), record["bytes"], rel)
        self.assertEqual(self.manifest["total_bytes"], sum(r["bytes"] for r in records.values()))

    def test_the_shipped_files_are_this_recipes_output(self) -> None:
        # Decoded, each shipped file must still be its master (AAC is lossy, so
        # by correlation and level, not by bytes).
        self.assertEqual(score.check(SKETCH if SKETCH.exists() else None), 0)


if __name__ == "__main__":
    unittest.main()
