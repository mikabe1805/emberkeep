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
import author_room_music_v2_study as v2  # noqa: E402

MANIFEST = ROOT / "design/audits/2026-10-11/class-day-score/manifest.json"
SKETCH = Path("C:/tmp/cdj/sound-v3")
OUT = ROOT / "assets/music/class_day"
PERFORMANCES = range(score.PERFORMANCE_COUNT)


def bar_of(t: float) -> int:
    """The bar a keys note belongs to; a chord may land a few ms ahead of its beat."""
    return int((t + 0.02) // score.BAR)


def coefficient(window: np.ndarray, ref: np.ndarray) -> float:
    """How much of [ref] there is in [window] (least squares)."""
    return float(np.dot(window, ref) / np.dot(ref, ref))


def fold_decoded(x: np.ndarray) -> np.ndarray:
    """A decoded bed as the circular loop it adds up to when passes are chained."""
    out = x[: score.N].copy()
    tail = x[score.N : score.N + round(score.BED_TAIL_S * score.SR)]
    out[: len(tail)] += tail
    return out


class ClassDayScoreTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        # One render of everything (about a minute) serves every test.
        cls.made = score.render_all(SKETCH if SKETCH.exists() else None)
        cls.scaled_folded = cls.made["scaled_folded"]
        cls.performances = cls.made["performances"]
        cls.beds = cls.performances[0]["beds"]  # the sketch's own
        cls.swells = cls.made["swells"]
        cls.scores = {
            p.index: score.render_keys(p.keys, with_score=True)[1] for p in score.PERFORMANCES
        }

    # ------------------------------------------------------------ the sketch

    def test_the_form_is_the_sketchs(self) -> None:
        self.assertEqual(score.BPM, 72.0)
        self.assertEqual(score.BARS, 16)
        self.assertEqual(score.N, 2_560_000)  # 53.333 s at 48 kHz
        self.assertEqual(score.SR, 48_000)
        self.assertEqual(len(score.CHORD_BARS), 16)
        self.assertEqual(score.SWELL_COUNT, 32)  # every strong beat of 64
        self.assertEqual(score.PERFORMANCE_COUNT, 6)

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

    def test_performance_zero_is_the_sketch_note_for_note(self) -> None:
        # The renderers take the sketch's controls as parameters; with the
        # sketch's own they make the sketch's stems exactly.
        p0 = score.PERFORMANCES[0]
        self.assertEqual(p0.keys, score.SKETCH_KEYS)
        self.assertEqual(p0.brushes, score.SKETCH_BRUSHES)
        self.assertEqual(p0.bells, score.SKETCH_BELLS)
        self.assertEqual(p0.keys.seed, 14_100)
        self.assertEqual(p0.keys.pickups, ((3, 0.5),))
        again = score.fold(score.render_keys(p0.keys)) * float(self.made["stem_records"]["keys"]["gain"])
        self.assertEqual(score.int16_sha(again), self.manifest["stems"]["keys"]["int16_sha256"])

    def test_rendering_is_deterministic(self) -> None:
        for index in (0, 3):
            p = score.PERFORMANCES[index]
            self.assertTrue(np.array_equal(score.render_keys(p.keys), score.render_keys(p.keys)), index)

    # --------------------------------------------------------------- the beds

    def test_two_chained_passes_are_the_circular_loop(self) -> None:
        # The app starts pass 2 exactly one form after pass 1 while pass 1
        # rings out. Added together they must equal the sketch's circular loop
        # over the overlap, or the seam would be audible.
        for pf in self.performances:
            for name, bed in pf["beds"].items():
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
                self.assertLess(err, 1e-9, f"performance {pf['performance'].index} {name}")

    def test_the_tail_that_is_cut_was_already_silent(self) -> None:
        for pf in self.performances:
            for name, bed in pf["beds"].items():
                self.assertLess(
                    bed["cut_tail_peak_db"], -80, f"performance {pf['performance'].index} {name}"
                )

    def test_every_bed_begins_and_ends_at_silence(self) -> None:
        for pf in self.performances:
            for name, bed in pf["beds"].items():
                audio = bed["audio"]
                where = f"performance {pf['performance'].index} {name}"
                self.assertLess(abs(float(audio[0])), 1e-9, where)
                self.assertLess(abs(float(audio[-1])), 1e-9, where)

    def test_every_bed_sits_at_the_rotations_level(self) -> None:
        for pf in self.performances:
            for name, bed in pf["beds"].items():
                circular = score.fold(bed["audio_full"])
                self.assertAlmostEqual(
                    score.phone_rms_db(circular), score.BED_TARGET_DB, delta=0.02,
                    msg=f"performance {pf['performance'].index} {name}",
                )
        # The sketch's own levels, before the bed gain.
        self.assertAlmostEqual(self.beds["between"]["sketch_phone_rms_db"], -36.83, delta=0.05)
        self.assertAlmostEqual(self.beds["evening"]["sketch_phone_rms_db"], -35.81, delta=0.05)

    def test_peaks_stay_where_the_sketchs_were(self) -> None:
        # Same loudness gives about the same peak; none may come near the -6
        # dBFS ceiling, and none more than 2 dB above the sketch's own.
        for state in ("between", "evening"):
            sketch_peak = score.db(np.max(np.abs(self.beds[state]["audio"])))
            for pf in self.performances:
                peak = score.db(np.max(np.abs(pf["beds"][state]["audio"])))
                self.assertLess(peak, -14, f"performance {pf['performance'].index} {state}")
                self.assertLess(
                    peak - sketch_peak, 2.0, f"performance {pf['performance'].index} {state}"
                )

    # ------------------------------------------------------------ the swells

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

    def test_a_swell_lifts_every_performance_about_two_db(self) -> None:
        for index in PERFORMANCES:
            lifts = [s["lift_by_performance_db"][index] for s in self.swells]
            peaks = [s["with_between_peak_by_performance_db"][index] for s in self.swells]
            self.assertGreater(min(lifts), 1.0, index)
            self.assertLess(max(lifts), 3.3, index)
            self.assertAlmostEqual(sum(lifts) / len(lifts), 2.1, delta=0.3, msg=str(index))
            self.assertLess(max(peaks), -12, index)

    def test_the_webaudio_lowpass_is_a_lowpass(self) -> None:
        t = np.arange(48_000) / score.SR
        low = np.sin(2 * np.pi * 100 * t)
        high = np.sin(2 * np.pi * 8_000 * t)
        out_low = score.webaudio_lowpass(low, 900.0)
        out_high = score.webaudio_lowpass(high, 900.0)
        self.assertGreater(np.max(np.abs(out_low[2000:])), 0.98)
        self.assertLess(np.max(np.abs(out_high[2000:])), 0.02)

    # ------------------------------------------------------- the performances

    def test_there_are_six_performances_and_they_are_not_the_same(self) -> None:
        self.assertEqual(len(score.PERFORMANCES), 6)
        self.assertEqual([p.index for p in score.PERFORMANCES], list(range(6)))
        seeds = [p.keys.seed for p in score.PERFORMANCES]
        self.assertEqual(len(set(seeds)), 6)
        self.assertEqual(len({p.keys.sound_seed for p in score.PERFORMANCES}), 6)
        self.assertEqual(len({p.brushes.seed for p in score.PERFORMANCES}), 6)
        self.assertEqual(len({p.bells.seed for p in score.PERFORMANCES}), 6)
        for state in ("between", "evening"):
            loops = [score.fold(pf["beds"][state]["audio_full"]) for pf in self.performances]
            for i in PERFORMANCES:
                for j in range(i + 1, score.PERFORMANCE_COUNT):
                    r = float(
                        np.dot(loops[i], loops[j]) / (np.linalg.norm(loops[i]) * np.linalg.norm(loops[j]))
                    )
                    self.assertLess(abs(r), 0.5, f"{state} {i} and {j} are too alike")
        # Their stems differ too, one by one.
        for stem in ("keys", "brushes", "bells_slow"):
            shas = {pf["stems"][stem] for pf in self.performances}
            self.assertEqual(len(shas), 6, stem)

    def test_every_performance_plays_the_same_chords_in_the_same_bars(self) -> None:
        for index, sc in self.scores.items():
            self.assertEqual(
                [(c["name"]) for c in sc.chords], score.CHORD_BARS, f"performance {index}"
            )
            for chord in sc.chords:
                bar = round(chord["t"] / score.BAR)
                self.assertAlmostEqual(chord["t"], bar * score.BAR, delta=1e-3)
            for event in sc.events:
                if event["voice"] != "keys":
                    continue
                chord = score.CHORD_BARS[bar_of(event["t"])]
                self.assertIn(
                    event["midi"] % 12,
                    v2.CHORDS[chord]["pcs"],
                    f"performance {index}: {event['midi']} over {chord} at {event['t']}",
                )

    def test_the_keys_stay_in_their_range_and_never_ring_into_the_next_pass(self) -> None:
        for index, sc in self.scores.items():
            for event in sc.events:
                self.assertGreaterEqual(event["midi"], 54, index)
                self.assertLessEqual(event["midi"], 76, index)
                # Nothing begins in the last half second of the form.
                self.assertLess(event["t"], score.N / score.SR - 0.5, index)

    def test_figures_are_short_pentatonic_phrases_clear_of_the_swells_bells(self) -> None:
        total = 0
        for p in score.PERFORMANCES:
            plan = score.plan_figures(p.keys)
            if p.keys.figure_p <= 0:
                self.assertEqual(plan, {}, p.index)
                continue
            self.assertGreaterEqual(len(plan), 1, f"performance {p.index} plays no figure")
            bars = sorted(plan)
            for a, b in zip(bars, bars[1:]):
                self.assertGreaterEqual(b - a, 2, "figures are punctuation, not a line")
            for bar, notes in plan.items():
                total += 1
                self.assertLessEqual(bar, score.FIGURE_LAST_BAR)
                self.assertIn(len(notes), (2, 3))
                chord = score.CHORD_BARS[bar]
                for slot, midi in notes:
                    self.assertIn(midi % 12, v2.PENT_PCS, "pentatonic")
                    self.assertIn(midi % 12, v2.CHORDS[chord]["pcs"], "a tone of the chord")
                    self.assertTrue(score.FIGURE_REGISTER[0] <= midi <= score.FIGURE_REGISTER[1])
                    self.assertLessEqual(slot, 7, "inside the bar")
                    self.assertNotIn((bar, slot), score.BUSY_SLOTS, "the swell's bells keep their slot")
                slots = [s for s, _ in notes]
                self.assertEqual(slots, list(range(slots[0], slots[0] + len(slots))))
        self.assertGreaterEqual(total, 12, "the performances answer with figures")

    def test_a_second_hit_sits_inside_its_bar_on_a_free_slot(self) -> None:
        for p in score.PERFORMANCES:
            for eighth, chance in p.keys.pickups:
                self.assertIn(eighth, (3, 5), p.index)
                self.assertTrue(0 < chance <= 1)
        # Where a performance keeps off the swell's bells, nothing it plays
        # after the downbeat lands on a slot a busy bell sounds on.
        for p in score.PERFORMANCES:
            if not p.keys.avoid_busy_bells:
                continue
            for event in self.scores[p.index].events:
                if event["voice"] != "keys":
                    continue
                bar = bar_of(event["t"])
                inside = event["t"] - bar * score.BAR
                if inside < 0.1:
                    continue  # the bar's chord on its beat
                slot = min(range(8), key=lambda e: abs(score.pos(0.0, e) - inside))
                self.assertNotIn(
                    (bar, slot), score.BUSY_SLOTS,
                    f"performance {p.index}: a keys note on a busy bell's slot, bar {bar}",
                )

    def test_the_brushes_keep_the_backbeat_in_every_performance(self) -> None:
        # The thump on beats 1 and 3 and the rim on 2 and 4 are the sketch's
        # identity, and the bass lands against them: a performance may thin
        # or add to them, never move them.
        for p in score.PERFORMANCES:
            b = p.brushes
            self.assertIn(b.ghost_slot, (5, 7))
            self.assertIn(b.rim_ghost_slot, (5,))
            self.assertGreaterEqual(b.two_keep, 0.85)
            self.assertGreaterEqual(b.rim_keep, 0.8)
            self.assertIn(b.accent, ("beats", "offbeats", "flat"))
            self.assertLessEqual(b.shaker_skip, 0.2)
            if b.arc is not None:
                self.assertEqual(len(b.arc), 16)
                self.assertTrue(all(0.8 <= x <= 1.2 for x in b.arc))

    def test_slow_bells_are_gentle_chord_aware_and_clear_of_the_end(self) -> None:
        for p in score.PERFORMANCES:
            bars = [bar for bar, *_ in p.bells.placements]
            self.assertGreaterEqual(len(p.bells.placements), 5)
            self.assertLessEqual(len(p.bells.placements), 7)
            self.assertEqual(bars, sorted(bars))
            for a, b in zip(bars, bars[1:]):
                self.assertGreaterEqual(b - a, 1)
            for bar, eighth, midi, vel in p.bells.placements:
                self.assertLessEqual(bar, 14, "none late enough to ring into the next pass")
                self.assertIn(eighth, (2, 5, 1), "off the bass's slots")
                self.assertIn(midi, (81, 83, 86), "A5, B5 or D6 only, as the sketch's")
                self.assertIn(midi, score.BELL_POOL[score.CHORD_BARS[bar]])
                self.assertTrue(0.5 <= vel <= 0.65)
        placements = {p.bells.placements for p in score.PERFORMANCES}
        self.assertEqual(len(placements), 6)

    # ------------------------------------------- the bass, which they all share

    def test_every_performance_is_built_on_the_same_bass(self) -> None:
        want = self.manifest["stems"]["bass"]["int16_sha256"]
        for pf in self.performances:
            self.assertEqual(pf["stems"]["bass"], want, pf["performance"].index)
        for rec in self.manifest["performances"]:
            self.assertEqual(rec["stems"]["bass"], want, rec["index"])

    def test_the_bass_in_each_shipped_bed_is_the_bass_each_swell_is_cut_from(self) -> None:
        """For every performance and every strong beat: the bass in the shipped
        Evening bed over the two bars from that beat is the sketch's bass stem,
        in the amount the bed mixes it, and the shipped swell cut at that beat
        holds the very same bass in the amount the swell mixes it. The Between
        beds have none (the swell brings it).

        Each shipped file is decoded, everything the bed holds besides the bass
        is taken away (the recipe's own mix of the keys and bells), and what is
        left is regressed on the bass stem over the two bars from the beat."""
        bass = self.scaled_folded["bass"]
        n = round(score.SWELL_HOLD_BARS * score.BAR * score.SR)
        held = slice(round(score.SWELL_PREROLL_S * score.SR), round(score.SWELL_PREROLL_S * score.SR) + n)
        for k in range(score.SWELL_COUNT):
            decoded = score.decode_m4a(OUT / f"swell_{k:02d}.m4a")
            start = round(2 * k * score.BEAT * score.SR)
            ref = bass[(start + np.arange(n)) % score.N]
            got = coefficient(decoded[held], ref)
            want = score.SWELL_GAIN * 10 ** (self.swells[k]["trim_db"] / 20)
            self.assertAlmostEqual(got / want, 1.0, delta=0.08, msg=f"swell {k} bass")
        for pf in self.performances:
            index = pf["performance"].index
            want = score.EVENING_GAINS["bass"] * pf["beds"]["evening"]["gain"]
            evening = fold_decoded(score.decode_m4a(OUT / score.bed_name("evening", index)))
            evening -= pf["beds"]["evening"]["circular_without_bass"].astype(np.float64)
            between = fold_decoded(score.decode_m4a(OUT / score.bed_name("between", index)))
            between -= pf["beds"]["between"]["circular_without_bass"].astype(np.float64)
            for k in range(score.SWELL_COUNT):
                start = round(2 * k * score.BEAT * score.SR)
                idx = (start + np.arange(n)) % score.N
                ref = bass[idx]
                self.assertAlmostEqual(
                    coefficient(evening[idx], ref) / want, 1.0, delta=0.03,
                    msg=f"performance {index}, strong beat {k}: the Evening bed's bass",
                )
                self.assertLess(
                    abs(coefficient(between[idx], ref) / want), 0.03,
                    f"performance {index}, strong beat {k}: the Between bed has no bass of its own",
                )

    def test_the_basss_note_at_every_strong_beat_belongs_to_the_chord(self) -> None:
        # The bass stem plays each bar's root; the swell cut at a strong beat
        # carries it, and every performance's keys play that bar's chord.
        for k in range(score.SWELL_COUNT):
            bar = (2 * k) // 4
            chord = score.CHORD_BARS[bar]
            root = int(v2.CHORDS[chord]["bass"])
            self.assertIn(root % 12, v2.CHORDS[chord]["pcs"], f"strong beat {k}, {chord}")
        for index, sc in self.scores.items():
            for bar in range(score.BARS):
                voiced = [e for e in sc.events if e["voice"] == "keys" and bar_of(e["t"]) == bar]
                self.assertTrue(voiced, f"performance {index}, bar {bar} is silent")

    # ------------------------------------------------------- manifest and files

    def test_the_manifest_matches_the_files_on_disk(self) -> None:
        records = self.manifest["records"]
        self.assertEqual(len(records), 44)
        for rel, record in records.items():
            data = (ROOT / rel).read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record["sha256"], rel)
            self.assertEqual(len(data), record["bytes"], rel)
        self.assertEqual(self.manifest["total_bytes"], sum(r["bytes"] for r in records.values()))
        extra = sum(
            r["bytes"]
            for rel, r in records.items()
            if "bed_" in rel and not rel.endswith("_0.m4a")
        )
        self.assertLess(extra, 8_000_000, "what the extra performances add")

    def test_performance_zero_is_byte_for_byte_the_bed_that_was_shipped(self) -> None:
        # The beds first shipped in e8567e6 (bed_between.m4a, bed_evening.m4a)
        # are performance 0 under their new names.
        shipped = {
            "bed_between_0.m4a": "e0fc8d169d602d7a9346b4217028edb30c78bf4313c771d0308c9e41850a0cc6",
            "bed_evening_0.m4a": "9c562f27712bb0a0371c174c8ab8ea7553e6e979120ed67bc099ebc682c4be92",
        }
        records = self.manifest["records"]
        for name, sha in shipped.items():
            self.assertEqual(records[f"assets/music/class_day/{name}"]["sha256"], sha, name)
        # And so are the thirty-two swells: none had to change.
        lines = "".join(
            f"swell_{k:02d} {records[f'assets/music/class_day/swell_{k:02d}.m4a']['sha256']}\n"
            for k in range(32)
        )
        self.assertEqual(
            hashlib.sha256(lines.encode()).hexdigest(),
            "e6d02ef330f774cd2d2d49c33f3524b3d9d43a1a652d4cfb9dc83457cdcb3c0e",
        )

    def test_the_shipped_files_are_this_recipes_output(self) -> None:
        # Decoded, each shipped file must still be its master (AAC is lossy, so
        # by correlation and level, not by bytes).
        self.assertEqual(score.check(SKETCH if SKETCH.exists() else None, self.made), 0)


if __name__ == "__main__":
    unittest.main()
