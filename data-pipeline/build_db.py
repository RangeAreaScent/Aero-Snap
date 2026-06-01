"""
build_db.py — Aero Snap SQLite builder.

Reads the JSONL outputs of the extractors, applies schema.sql, ingests,
populates FTS5, ANALYZE + VACUUM, writes meta. The resulting .sqlite is
the file bundled by both iOS (`Aero-Snap/`) and desktop
(`Aero-Snap_Mac_Win_app/`).

Inputs (any may be absent — extractor still in progress):
    data/ad_<date>.jsonl
    data/far_<date>.jsonl
    data/tcds_<date>.jsonl
    data/ac_<date>.jsonl
    data/ad_applicability_<date>.jsonl

Output:
    data/aero_snap_v1.sqlite      (target ~115–130 MB at full scale)

Usage:
    python3 build_db.py
    python3 build_db.py --ad data/ad_poc.jsonl --far data/far_2026-05-30.jsonl \\
        --applicability data/ad_applicability_poc.jsonl \\
        -o data/aero_snap_poc.sqlite
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

DEFAULT_AD   = "data/ad_2026-05-30.jsonl"
DEFAULT_FAR  = "data/far_2026-05-30.jsonl"
DEFAULT_TCDS = "data/tcds_2026-05-30.jsonl"
DEFAULT_AC   = "data/ac_2026-05-30.jsonl"
DEFAULT_APPL = "data/ad_applicability_2026-05-30.jsonl"
DEFAULT_OUT  = "data/aero_snap_v1.sqlite"
SCHEMA_PATH  = "schema.sql"

# Columns per table (matches schema.sql verbatim). Extra fields with
# leading underscore are intermediate-pipeline-only and stripped here.
COLS = {
    "airworthiness_directives": [
        "ad_number", "ad_year", "title", "effective_date",
        "federal_register_id", "cfr_amendment", "summary", "body",
        "compliance_time", "is_emergency", "supersedes", "superseded_by",
        "ata_chapter", "pdf_url", "fr_url",
    ],
    "type_certificates": [
        "tcds_number", "category", "manufacturer", "models",
        "issue_date", "last_revision", "specifications", "pdf_url",
    ],
    "ad_applicability": [
        "ad_number", "manufacturer", "model", "model_series",
        "serial_range_start", "serial_range_end", "part_type", "notes",
    ],
    "far_sections": [
        "id", "part_number", "section_number", "subpart",
        "heading", "body", "citation", "last_amended",
    ],
    "advisory_circulars": [
        "ac_number", "title", "issue_date", "related_far", "pdf_url",
    ],
}


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        print(f"[build_db] skip {path} (not found)", file=sys.stderr)
        return []
    with path.open("r", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def project(row: dict, cols: list[str]) -> tuple:
    return tuple(row.get(c) for c in cols)


def bulk_insert(conn: sqlite3.Connection, table: str, rows: list[dict]) -> int:
    if not rows:
        return 0
    cols = COLS[table]
    placeholders = ",".join(["?"] * len(cols))
    col_list = ",".join(cols)
    sql = f"INSERT OR REPLACE INTO {table} ({col_list}) VALUES ({placeholders})"
    conn.executemany(sql, (project(r, cols) for r in rows))
    return len(rows)


def apply_body_cutoff(rows: list[dict], cutoff_years: int | None,
                      build_date_iso: str) -> tuple[list[dict], int]:
    """Mitigation for bundle-size risk (see project_aero_decisions.md).

    For ADs older than `cutoff_years` (computed against build_date),
    drop the body but keep summary + URLs. Users searching old ADs
    get the metadata + a pdf_url to read the original online; the
    bulk text bytes go to current-applicable ADs.

    Returns (transformed_rows, count_bodies_dropped).
    """
    if cutoff_years is None or cutoff_years <= 0:
        return rows, 0
    cutoff_year = int(build_date_iso[:4]) - cutoff_years
    out, dropped = [], 0
    for r in rows:
        eff = r.get("effective_date") or ""
        if eff and eff[:4].isdigit() and int(eff[:4]) < cutoff_year:
            # Keep summary; drop body to save bundle bytes.
            r = {**r, "body": ""}
            dropped += 1
        out.append(r)
    return out, dropped


def populate_fts(conn: sqlite3.Connection) -> None:
    # Rebuild each FTS5 index from the content table.
    for fts in ("ad_fts", "far_fts", "tcds_fts"):
        conn.execute(f"INSERT INTO {fts}({fts}) VALUES('rebuild')")


def write_meta(conn: sqlite3.Connection, counts: dict[str, int],
               build_date: str, dataset_version: str) -> None:
    meta_rows = [
        ("schema_version", "1"),
        ("dataset_version", dataset_version),
        ("build_date", build_date),
    ]
    for table, n in counts.items():
        meta_rows.append((f"count_{table}", str(n)))
    conn.executemany(
        "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", meta_rows
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--ad", default=DEFAULT_AD)
    parser.add_argument("--far", default=DEFAULT_FAR)
    parser.add_argument("--tcds", default=DEFAULT_TCDS)
    parser.add_argument("--ac", default=DEFAULT_AC)
    parser.add_argument("--applicability", default=DEFAULT_APPL)
    parser.add_argument("-o", "--out", default=DEFAULT_OUT)
    parser.add_argument("--schema", default=SCHEMA_PATH)
    parser.add_argument("--build-date", default=None,
                        help="Override build date stamp (default: today UTC)")
    parser.add_argument("--body-cutoff-years", type=int, default=None,
                        help="Drop AD body for ADs older than N years "
                             "(summary + URLs retained). Bundle-size mitigation. "
                             "Recommended: 7 (aggressive) or 15 (conservative).")
    parser.add_argument("--dataset-version", default="v1-poc",
                        help="Meta tag for the bundled DB. Use 'v1' for the "
                             "first full-scale ship; 'v1-poc' for early builds.")
    args = parser.parse_args()

    schema_path = Path(args.schema)
    if not schema_path.exists():
        print(f"[build_db] ERROR: schema not found at {schema_path}",
              file=sys.stderr)
        return 1

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()

    build_date = args.build_date or _today_iso()

    conn = sqlite3.connect(out_path)
    try:
        # Apply schema
        conn.executescript(schema_path.read_text(encoding="utf-8"))

        # Load + ingest
        ad_rows   = load_jsonl(Path(args.ad))
        far_rows  = load_jsonl(Path(args.far))
        tcds_rows = load_jsonl(Path(args.tcds))
        ac_rows   = load_jsonl(Path(args.ac))
        appl_rows = load_jsonl(Path(args.applicability))

        ad_rows, body_dropped = apply_body_cutoff(
            ad_rows, args.body_cutoff_years, build_date)
        if body_dropped:
            print(f"[build_db] body dropped for {body_dropped} ADs "
                  f"(cutoff: {args.body_cutoff_years} years)", file=sys.stderr)

        with conn:
            counts = {}
            counts["airworthiness_directives"] = bulk_insert(
                conn, "airworthiness_directives", ad_rows)
            counts["type_certificates"] = bulk_insert(
                conn, "type_certificates", tcds_rows)
            counts["ad_applicability"] = bulk_insert(
                conn, "ad_applicability", appl_rows)
            counts["far_sections"] = bulk_insert(
                conn, "far_sections", far_rows)
            counts["advisory_circulars"] = bulk_insert(
                conn, "advisory_circulars", ac_rows)

            populate_fts(conn)
            counts["_body_dropped"] = body_dropped
            write_meta(conn, counts, build_date, args.dataset_version)

        conn.execute("ANALYZE")
        conn.execute("VACUUM")
    finally:
        conn.close()

    size_mb = out_path.stat().st_size / (1024 * 1024)
    print(f"[build_db] DONE: {out_path}  ({size_mb:.2f} MB)", file=sys.stderr)
    for table, n in counts.items():
        print(f"  {table:<28} {n:>7d}", file=sys.stderr)
    return 0


def _today_iso() -> str:
    # Match CLAUDE.md current-date conventions; build_date is informational.
    import datetime
    return datetime.date.today().isoformat()


if __name__ == "__main__":
    raise SystemExit(main())
