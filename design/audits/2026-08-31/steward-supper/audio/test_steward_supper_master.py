"""Numeric-limit and decode tests for steward-supper-music-v1.

Checks the master WAV against its stated contract and proves the bundled
AAC actually decodes to the same music at the same length and level.

    python test_steward_supper_master.py
"""
from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import json
import math
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import author_steward_supper_music as recipe  # noqa: E402

STUDY = HERE / "steward-supper-music-v1"
MASTER = STUDY / "master" / "steward-supper-theme-master.wav"
DECODED = STUDY / "evidence" / "decoded-room-theme.wav"
M4A = recipe.WORKTREE / "assets" / "music" / "room-theme.m4a"

RESULTS: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str) -> None:
    RESULTS.append((name, bool(ok), detail))


def main() -> int:
    audio, rate = sf.read(MASTER, dtype="float64")
    info = sf.info(MASTER)

    check("master_sample_rate_48k", rate == 48_000, f"rate={rate}")
    check("master_mono", audio.ndim == 1, f"ndim={audio.ndim}")
    check("master_subtype_pcm24", info.subtype == "PCM_24", info.subtype)
    check(
        "master_exact_loop_frames",
        len(audio) == recipe.LOOP_FRAMES,
        f"frames={len(audio)} expected={recipe.LOOP_FRAMES} ({len(audio)/rate:.4f} s)",
    )
    check("master_no_nan_inf", bool(np.all(np.isfinite(audio))), "finite")
    peak = float(np.max(np.abs(audio)))
    check("master_peak_below_-6dbfs", peak < 10 ** (-6 / 20), f"peak={peak:.5f} ({20*math.log10(peak):.2f} dBFS)")
    tp = recipe.true_peak_dbtp(audio)
    check("master_true_peak_below_-3dbtp", tp < -3.0, f"{tp:.2f} dBTP")
    dc = float(np.mean(audio))
    check("master_dc_below_1e-4", abs(dc) < 1e-4, f"dc={dc:.2e}")
    lufs = recipe.integrated_lufs(audio)
    check(
        "master_lufs_within_0p5_of_target",
        abs(lufs - recipe.TARGET_LUFS) <= 0.5,
        f"{lufs:.2f} LUFS vs {recipe.TARGET_LUFS}",
    )
    seam = recipe.seam_metrics(audio)
    check(
        "loop_seam_step_below_body_p999",
        seam["seam_first_difference"] <= seam["body_first_difference_p999"],
        f"seam={seam['seam_first_difference']:.5f} body_p999={seam['body_first_difference_p999']:.5f}",
    )
    check(
        "loop_seam_level_continuous_within_3db",
        abs(seam["rms_50ms_before_seam_dbfs"] - seam["rms_50ms_after_seam_dbfs"]) < 3.0,
        f"{seam['rms_50ms_before_seam_dbfs']:.1f} -> {seam['rms_50ms_after_seam_dbfs']:.1f} dBFS",
    )

    # ── the bundled AAC actually decodes ────────────────────────────────
    check("m4a_exists", M4A.exists(), str(M4A))
    size_mb = M4A.stat().st_size / 1e6
    check("m4a_bundle_size_under_2mb", size_mb < 2.0, f"{size_mb:.2f} MB")

    dec, dec_rate = sf.read(DECODED, dtype="float64")
    if dec.ndim > 1:
        dec = dec.mean(axis=1)
    check("decoded_sample_rate_48k", dec_rate == 48_000, f"rate={dec_rate}")
    drift = abs(len(dec) - recipe.LOOP_FRAMES)
    check(
        "decoded_length_within_50ms_of_master",
        drift <= round(0.050 * 48_000),
        f"decoded={len(dec)} master={recipe.LOOP_FRAMES} drift={drift/48_000*1000:.1f} ms",
    )
    dec_lufs = recipe.integrated_lufs(dec)
    check(
        "decoded_lufs_within_1db_of_master",
        abs(dec_lufs - lufs) <= 1.0,
        f"decoded={dec_lufs:.2f} master={lufs:.2f}",
    )
    n = min(len(dec), len(audio), 48_000 * 30)
    a, b = audio[:n], dec[:n]
    corr = float(np.dot(a, b) / max(np.sqrt(np.dot(a, a) * np.dot(b, b)), 1e-12))
    check("decoded_correlates_with_master", corr > 0.90, f"corr={corr:.4f} over first 30 s")
    dec_seam = recipe.seam_metrics(dec)
    check(
        "decoded_loop_seam_step_sane",
        dec_seam["seam_first_difference"] <= 2 * dec_seam["body_first_difference_p999"],
        f"seam={dec_seam['seam_first_difference']:.5f} body_p999={dec_seam['body_first_difference_p999']:.5f}",
    )

    # ── report ──────────────────────────────────────────────────────────
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"{'PASS' if ok else 'FAIL'}  {name}: {detail}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")

    (STUDY / "test-results.json").write_text(
        json.dumps(
            [{"check": n, "pass": ok, "detail": d} for n, ok, d in RESULTS],
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
