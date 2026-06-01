"""
extract_tcds.py — Type Certificate Data Sheets.

Source strategy (decided 2026-06-01 — see memory/project_aero_decisions.md
§ "TCDS strategy — DECIDED"):

  * Option B for v1: hand-curated seed in `tcds_seed.jsonl`. Target
    ~200 entries covering the top GA / commercial / rotorcraft /
    engine / propeller TCDS — see `TCDS_CURATION_PLAN.md` for the
    category breakdown and progress tracker.
  * Option A for v2 backlog: full DRS scrape (~3,000+ TCDS). Blocked
    by the Angular SPA + auth-gated `/drs-api/*` endpoints — research
    notes in `DRS_RESEARCH.md`.

The seed file is plain JSONL so it's edit-friendly for curators who
aren't familiar with Python. Each line is one TCDS entry; this
script just reshapes them into the `type_certificates` row format
the SQLite builder ingests.

Usage:
    python3 extract_tcds.py --out data/tcds_2026-05-31.jsonl
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# DRS document URL pattern — landing page is publicly readable (the
# API behind it isn't). Users tap through from the app to the PDF.
DRS_DOC_URL = "https://drs.faa.gov/browse/TCDSMODEL/doctypeDetails"

SEED_PATH = Path(__file__).resolve().parent / "tcds_seed.jsonl"


def load_seed(path: Path) -> list[dict]:
    if not path.exists():
        print(f"[extract_tcds] ERROR: seed file not found at {path}",
              file=sys.stderr)
        sys.exit(1)
    out: list[dict] = []
    with path.open("r", encoding="utf-8") as f:
        for lineno, line in enumerate(f, start=1):
            line = line.strip()
            if not line or line.startswith("//"):
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"[extract_tcds] ERROR: {path}:{lineno}: {e}",
                      file=sys.stderr)
                sys.exit(1)
    return out


def to_row(entry: dict) -> dict:
    return {
        "tcds_number": entry["tcds_number"],
        "category": entry["category"],
        "manufacturer": entry["manufacturer"],
        "models": entry["models"],
        "issue_date": entry.get("issue_date"),
        "last_revision": entry.get("last_revision"),
        "specifications": json.dumps(entry.get("specifications") or {},
                                     ensure_ascii=False),
        "pdf_url": f"{DRS_DOC_URL}/{entry['tcds_number']}",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--seed", default=str(SEED_PATH),
                        help=f"Seed JSONL path (default: {SEED_PATH.name})")
    parser.add_argument("--category",
                        choices=["Aircraft", "Engine", "Propeller", "all"],
                        default="all")
    args = parser.parse_args()

    seed = load_seed(Path(args.seed))
    rows = [to_row(e) for e in seed
            if args.category == "all" or e["category"] == args.category]

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[extract_tcds] DONE: {len(rows)} TCDS (seed) → {out_path}",
          file=sys.stderr)
    coverage = f"{len(seed)}/200 curated"
    print(f"[extract_tcds] curation progress: {coverage}. "
          f"See TCDS_CURATION_PLAN.md to extend.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
