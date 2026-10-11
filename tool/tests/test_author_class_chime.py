from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[2]
TOOL_ROOT = ROOT / "tool"
if str(TOOL_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOL_ROOT))

import author_class_chime as chime  # noqa: E402


def as_int16(wet: np.ndarray) -> np.ndarray:
    """What write44 puts on disk, without writing."""
    y = chime.to_44k(wet)
    peak = np.max(np.abs(y))
    if peak > 0.98:
        y = y * 0.98 / peak
    return np.round(y * 32768).clip(-32768, 32767).astype(np.int32)


class ClassChimeTest(unittest.TestCase):
    def test_the_line_is_the_pitch_fields_rising_pentatonic(self) -> None:
        self.assertEqual(chime.NOTES, ("D5", "E5", "F#5", "A5", "B5", "D6"))
        self.assertEqual(chime.STEPS, 6)
        classes = {n.rstrip("0123456789") for n in chime.NOTES}
        self.assertEqual(classes, {"D", "E", "F#", "A", "B"})
        hz = [chime.HZ[n] for n in chime.NOTES]
        self.assertEqual(hz, sorted(hz))
        self.assertAlmostEqual(hz[-1] / hz[0], 2.0, places=2)

    def test_it_is_the_soft_hands_own_brass_synthesis(self) -> None:
        # The chime is render_brass with a different spec, so the same
        # function must still reproduce a shipped Soft hand brass take.
        result = chime.check_against_soft_hand()
        self.assertTrue(result["length_match"], result)
        self.assertLessEqual(result["worst_lsb"], 2, result)

    def test_the_shipped_masters_regenerate(self) -> None:
        # Within two 16-bit steps: a different numpy or scipy may round a
        # float differently, the sound is the same.
        for i in range(chime.STEPS):
            ours = as_int16(chime.render_chime(i))
            shipped, sr = sf.read(
                str(ROOT / f"assets/sfx/room/class_chime/{i + 1}.wav"), dtype="int16"
            )
            self.assertEqual(sr, chime.OUT_SR)
            self.assertEqual(len(ours), len(shipped), f"step {i + 1}")
            worst = int(np.max(np.abs(ours - shipped.astype(np.int32))))
            self.assertLessEqual(worst, 2, f"step {i + 1}")

    def test_rendering_is_deterministic(self) -> None:
        a = chime.render_chime(2)
        b = chime.render_chime(2)
        self.assertTrue(np.array_equal(a, b))

    def test_each_step_sounds_its_note_and_sits_on_one_level(self) -> None:
        phone = []
        for i, note in enumerate(chime.NOTES):
            a, sr = chime.read_wav(ROOT / f"assets/sfx/room/class_chime/{i + 1}.wav")
            cents = 1200 * math.log2(chime.fundamental_hz(a, sr) / chime.HZ[note])
            self.assertLess(abs(cents), 10, f"{note} is {cents:+.1f} cents off")
            m = chime.measure(a, sr)
            phone.append(m["phone_rms"])
            self.assertLess(m["peak"], -12.0, "far under the -6 dBFS ceiling")
            self.assertTrue(300 <= m["dur_ms"] <= 520, "a short, warm decay")
        self.assertLess(max(phone) - min(phone), 0.25, "no step jumps out")

    def test_the_manifest_records_what_the_script_measured(self) -> None:
        manifest = json.loads(
            (ROOT / "design/audits/2026-10-11/class-chime/manifest.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(len(manifest["records"]), chime.STEPS)
        for key, record in manifest["records"].items():
            self.assertEqual(record["sha256"], chime.sha256(ROOT / key), key)
            self.assertEqual(record["note"], chime.NOTES[record["step"] - 1])


if __name__ == "__main__":
    unittest.main()
