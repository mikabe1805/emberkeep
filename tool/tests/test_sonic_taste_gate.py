import importlib.util
import json
import math
import tempfile
import unittest
import wave
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "sonic_taste_gate.py"
SPEC = importlib.util.spec_from_file_location("sonic_taste_gate", MODULE_PATH)
gate = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(gate)


class SonicTasteGateTest(unittest.TestCase):
    def _write_tone(self, path: Path, frequency: float = 100.0) -> None:
        rate, frames = 8000, 800
        data = b"".join(int(12000 * math.sin(2 * math.pi * frequency * index / rate)).to_bytes(2, "little", signed=True)
                        for index in range(frames))
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1); output.setsampwidth(2); output.setframerate(rate); output.writeframes(data)

    def test_qc_reports_pcm_metrics_and_bands(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "low.wav"; self._write_tone(path)
            report = gate.qc_file(path)
        self.assertEqual("ok", report["status"])
        self.assertEqual(8000, report["sample_rate_hz"])
        self.assertAlmostEqual(0.1, report["duration_seconds"], places=3)
        self.assertGreater(report["low_frequency_energy_ratio"], 0.8)
        self.assertLess(report["brightness_energy_ratio"], 0.01)
        self.assertIn("tail_relative_to_program_db", report)
        self.assertIn("presence_energy_ratio", report)
        self.assertIn("attack_10pct_seconds", report)
        self.assertIsNone(report["stereo_correlation"])

    def test_session_is_deterministic_and_role_local(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / "manifest.json"
            manifest.write_text(json.dumps({"candidates": [
                {"id": "wood-b", "role": "tap", "path": "b.wav"}, {"id": "reward", "role": "reward", "path": "r.wav"},
                {"id": "wood-a", "role": "tap", "path": "a.wav"}]}), encoding="utf-8")
            session = gate.make_session(str(manifest))
        self.assertEqual(["tap:wood-a__wood-b"], [pair["id"] for pair in session["pairs"]])

    def test_fit_marks_disconnected_role_insufficient(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); manifest = root / "manifest.json"; ratings = root / "ratings.jsonl"
            manifest.write_text(json.dumps([{"id": key, "role": "tap", "path": key + ".wav"} for key in ("a", "b", "c")]), encoding="utf-8")
            session = gate.make_session(str(manifest)); (root / "session.json").write_text(json.dumps(session), encoding="utf-8")
            ratings.write_text(json.dumps({"pair_id": "tap:a__b", "choice": "a"}) + "\n", encoding="utf-8")
            result = gate.fit_session(str(root / "session.json"), str(ratings))
        self.assertEqual("insufficient_data", result["roles"][0]["status"])

    def test_fit_prefers_repeated_winner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); manifest = root / "manifest.json"; session_path = root / "session.json"; ratings = root / "ratings.jsonl"
            manifest.write_text(json.dumps([{"id": key, "role": "tap", "path": key + ".wav"} for key in ("a", "b")]), encoding="utf-8")
            session_path.write_text(json.dumps(gate.make_session(str(manifest))), encoding="utf-8")
            ratings.write_text("".join(json.dumps({"pair_id": "tap:a__b", "choice": "a"}) + "\n" for _ in range(3)), encoding="utf-8")
            result = gate.fit_session(str(session_path), str(ratings))
        scores = {item["id"]: item["score"] for item in result["roles"][0]["scores"]}
        self.assertEqual("ok", result["roles"][0]["status"]); self.assertGreater(scores["a"], scores["b"])

    def test_fit_accepts_no_preference_without_inventing_a_winner(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); manifest = root / "manifest.json"; session_path = root / "session.json"; ratings = root / "ratings.jsonl"
            manifest.write_text(json.dumps([{"id": key, "role": "tap", "path": key + ".wav"} for key in ("a", "b")]), encoding="utf-8")
            session_path.write_text(json.dumps(gate.make_session(str(manifest))), encoding="utf-8")
            ratings.write_text(json.dumps({"pair_id": "tap:a__b", "choice": "no_preference"}) + "\n", encoding="utf-8")
            result = gate.fit_session(str(session_path), str(ratings))
        scores = {item["id"]: item["score"] for item in result["roles"][0]["scores"]}
        self.assertEqual("ok", result["roles"][0]["status"])
        self.assertAlmostEqual(scores["a"], scores["b"])


if __name__ == "__main__":
    unittest.main()
