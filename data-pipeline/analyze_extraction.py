"""
analyze_extraction.py — Coverage + quality stats for AD extraction at scale.

Reads ad_*.jsonl + ad_applicability_*.jsonl and prints a quality report:
  - Headers parsed cleanly (% with AD number + Amendment ID)
  - ATA chapter coverage (% non-null)
  - Applicability clause length distribution
  - Manufacturer hit rate (% non-UNKNOWN)
  - Models per AD distribution
  - Supersede chain density

Usage:
    python3 analyze_extraction.py \\
        --ad data/ad_scale1k.jsonl \\
        --applicability data/ad_applicability_scale1k.jsonl
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import Counter
from pathlib import Path


def load(p: Path) -> list[dict]:
    if not p.exists():
        print(f"[analyze] missing: {p}", file=sys.stderr)
        return []
    return [json.loads(line) for line in p.read_text(encoding="utf-8").splitlines() if line.strip()]


def pct(n: int, total: int) -> str:
    return f"{(100*n/total):5.1f}%" if total else "  n/a"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    ap.add_argument("--ad", required=True)
    ap.add_argument("--applicability", required=True)
    args = ap.parse_args()

    ads = load(Path(args.ad))
    appl = load(Path(args.applicability))
    if not ads:
        print("[analyze] no ADs", file=sys.stderr)
        return 1

    n = len(ads)
    print(f"\n=== AD extraction quality ({n} ADs) ===\n")

    # Header / field coverage
    with_ata = sum(1 for r in ads if r.get("ata_chapter"))
    with_cfra = sum(1 for r in ads if r.get("cfr_amendment"))
    with_effdate = sum(1 for r in ads if r.get("effective_date"))
    with_appl = sum(1 for r in ads if (r.get("_applicability_text") or "").strip())
    with_supersedes = sum(1 for r in ads if r.get("supersedes"))
    superseded_by_count = sum(1 for r in ads if r.get("superseded_by"))
    emergency = sum(1 for r in ads if r.get("is_emergency"))

    print(f"  AD number captured (100%? must be): {pct(n, n)}  ({n})")
    print(f"  cfr_amendment captured:             {pct(with_cfra, n)}")
    print(f"  effective_date captured:            {pct(with_effdate, n)}")
    print(f"  ata_chapter captured:               {pct(with_ata, n)}")
    print(f"  applicability text captured:        {pct(with_appl, n)}")
    print(f"  supersedes another AD:              {pct(with_supersedes, n)}")
    print(f"  superseded_by (chain resolved):     {pct(superseded_by_count, n)}")
    print(f"  emergency AD (EAD):                 {pct(emergency, n)}")

    # Body length distribution
    body_lens = [len(r.get("body", "")) for r in ads if r.get("body")]
    if body_lens:
        print(f"\n  body length (chars):")
        print(f"    min={min(body_lens):,}  median={int(statistics.median(body_lens)):,}  "
              f"mean={int(statistics.mean(body_lens)):,}  max={max(body_lens):,}")

    appl_lens = [len(r.get("_applicability_text") or "") for r in ads]
    if appl_lens:
        nz = [x for x in appl_lens if x > 0]
        print(f"  applicability clause (chars): zero={appl_lens.count(0)} "
              f"median={int(statistics.median(nz)) if nz else 0}")

    # ATA chapter distribution
    ata_dist = Counter(r.get("ata_chapter") for r in ads if r.get("ata_chapter"))
    if ata_dist:
        print(f"\n  top ATA chapters: {ata_dist.most_common(10)}")

    # Applicability matrix stats
    print(f"\n=== Applicability matrix ({len(appl)} rows) ===\n")
    rows_per_ad = Counter(r["ad_number"] for r in appl)
    ads_with_rows = len(rows_per_ad)
    print(f"  ADs with ≥1 matrix row: {pct(ads_with_rows, n)}")
    if ads_with_rows:
        counts = sorted(rows_per_ad.values())
        print(f"  rows per AD: min=1  median={statistics.median(counts):.0f}  "
              f"mean={statistics.mean(counts):.1f}  max={max(counts)}")

    mfg_counts = Counter(r["manufacturer"] for r in appl)
    print(f"\n  top manufacturers: {mfg_counts.most_common(15)}")
    unknown_mfg = mfg_counts.get("UNKNOWN", 0)
    print(f"  UNKNOWN manufacturer rows:          {pct(unknown_mfg, len(appl))}")

    pt_counts = Counter(r["part_type"] for r in appl)
    print(f"  part_type breakdown: {dict(pt_counts)}")

    serial = sum(1 for r in appl if r.get("serial_range_start"))
    print(f"  rows with serial range:              {pct(serial, len(appl))}")

    # ADs that yielded ZERO rows from applicability (regex gap)
    no_match_ads = [a for a in ads if a["ad_number"] not in rows_per_ad
                    and (a.get("_applicability_text") or "").strip()]
    print(f"\n  ADs with applicability text but ZERO matrix rows: {len(no_match_ads)}")
    for a in no_match_ads[:5]:
        print(f"    {a['ad_number']}  {a['title'][:60]}")
        print(f"      appl: {(a['_applicability_text'] or '')[:140]}")
    if len(no_match_ads) > 5:
        print(f"    ...and {len(no_match_ads) - 5} more")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
