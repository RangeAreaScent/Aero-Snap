"""
size_projection.py — Project full-corpus (23k AD) bundle size under
various body-cutoff strategies.

Approach:
  - Measure current per-AD body size distribution from the PoC corpus.
  - Compute SQLite overhead factor empirically (DB size / raw text).
  - Extrapolate to ~23,000 ADs assuming uniform distribution per year
    (FAA averages ~720 ADs/yr since 1994).
  - For each strategy (no cutoff / 15-yr / 10-yr / 7-yr / 5-yr), apply
    the rule and project the resulting bundle size including FAR
    (1,022 sections ≈ 6 MB), TCDS (~5,000 rows assumed ≈ 10 MB),
    applicability matrix (~50,000 rows ≈ 5 MB), FTS5 indexes (~30%
    of indexable text).

Run after building data/aero_snap_v1.sqlite:
    python3 size_projection.py
"""

from __future__ import annotations

import json
import os
import sqlite3
import statistics
from pathlib import Path

AD_JSONL = "data/ad_scale1k.jsonl"
CURRENT_DB = "data/aero_snap_v1.sqlite"

# Assumptions for full-corpus extrapolation
TOTAL_ADS_FULL = 23000        # FAA estimate since 1994
YEARS_COVERED = 32            # 1994 → 2025
CURRENT_YEAR = 2026

# Other tables (rough projections; refined when extractors land)
FAR_BYTES = 6 * 1024 * 1024            # already measured
TCDS_ASSUMED_BYTES = 10 * 1024 * 1024  # spec §3-1 estimate
AC_ASSUMED_BYTES = 1 * 1024 * 1024     # metadata only
APPL_ASSUMED_BYTES = 5 * 1024 * 1024   # ~50k rows × ~100 bytes
FIXED_OVERHEAD = FAR_BYTES + TCDS_ASSUMED_BYTES + AC_ASSUMED_BYTES + APPL_ASSUMED_BYTES


def measure_current() -> tuple[int, int, list[int], int]:
    """Return (db_bytes, sum_ad_body_chars, per-ad body lens, total ad count)."""
    db_sz = os.path.getsize(CURRENT_DB)
    ads = [json.loads(line) for line in Path(AD_JSONL).read_text(encoding="utf-8").splitlines() if line.strip()]
    lens = [len(r.get("body") or "") for r in ads]
    return db_sz, sum(lens), lens, len(ads)


def main() -> int:
    db_bytes, body_sum, body_lens, n_ads = measure_current()
    print(f"=== Measured (n={n_ads} ADs) ===\n")
    print(f"  SQLite size:         {db_bytes/1024/1024:>7.2f} MB")
    print(f"  Sum AD body chars:   {body_sum:>10,}")
    print(f"  Median body chars:   {int(statistics.median(body_lens)):>10,}")
    print(f"  Mean body chars:     {int(statistics.mean(body_lens)):>10,}")

    # Empirically: how much SQLite overhead per char of AD body?
    # (DB contains FAR + applicability + indexes too, but body dominates.)
    far_count = 1022
    far_avg_chars = 4500  # estimate
    far_body_chars = far_count * far_avg_chars
    appl_bytes = 1806 * 200  # rough
    bytes_per_char = db_bytes / (body_sum + far_body_chars + appl_bytes)
    print(f"  Estimated bytes-per-char (incl. FTS): {bytes_per_char:.2f}x")

    median_body = statistics.median(body_lens)
    mean_body = statistics.mean(body_lens)
    print(f"\n=== Full-corpus projection (target: {TOTAL_ADS_FULL} ADs over {YEARS_COVERED} years) ===\n")

    strategies = [
        ("(no cutoff) full body for every AD",         None),
        ("body cutoff: 15 years old (keep 2011+)",      15),
        ("body cutoff: 10 years old (keep 2016+)",      10),
        ("body cutoff: 7 years old  (keep 2019+)",      7),
        ("body cutoff: 5 years old  (keep 2021+)",      5),
    ]
    ads_per_year = TOTAL_ADS_FULL / YEARS_COVERED
    summary_only_chars = 800  # title + summary + URLs + ata only

    print(f"  {'Strategy':<46} {'kept':>6} {'cut':>6} {'AD MB':>7} "
          f"{'Total MB':>10} {'Target':>8}")
    print(f"  {'-'*46} {'-'*6} {'-'*6} {'-'*7} {'-'*10} {'-'*8}")

    target = "115–130 MB"
    for label, cutoff in strategies:
        if cutoff is None:
            ads_with_body = TOTAL_ADS_FULL
            ads_cut = 0
        else:
            years_kept = cutoff
            ads_with_body = int(ads_per_year * years_kept)
            ads_with_body = min(ads_with_body, TOTAL_ADS_FULL)
            ads_cut = TOTAL_ADS_FULL - ads_with_body

        text_bytes = (
            ads_with_body * mean_body +
            ads_cut * summary_only_chars
        )
        # Apply SQLite + FTS overhead, then add fixed-table overhead.
        ad_table_bytes = text_bytes * bytes_per_char
        total_bytes = ad_table_bytes + FIXED_OVERHEAD
        verdict = "✓ in target" if 115 <= total_bytes / 1024 / 1024 <= 130 else (
            "✓ under target" if total_bytes / 1024 / 1024 < 115 else "✗ over")
        print(f"  {label:<46} {ads_with_body:>6,} {ads_cut:>6,} "
              f"{ad_table_bytes/1024/1024:>6.0f}M "
              f"{total_bytes/1024/1024:>8.0f} MB  {verdict}")

    print(f"\n  Fixed overhead (FAR + TCDS + AC + applicability + indexes): "
          f"{FIXED_OVERHEAD/1024/1024:.0f} MB")
    print(f"  Spec §3-1 target: {target}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
