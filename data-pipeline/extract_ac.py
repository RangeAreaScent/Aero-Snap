"""
extract_ac.py — Advisory Circulars metadata extractor.

Source:
  - FAA AC index: https://www.faa.gov/regulations_policies/advisory_circulars
  - Master list at parentTopicID=0 returns all ~780 active+cancelled ACs
    on a single page (~1.4 MB HTML).
  - Public domain.

Scope (spec §2-6): metadata only. ~780 ACs. PDFs are heavy
(drawings/tables) and stay online — pdf_url links out.

Page structure (verified 2026-05-31):
  Each AC is a <tr> with 5 <td>s:
    [0] AC number ("20-68B", "150/5320-12C")
    [1] <a>title</a><div class="small lineClamp"><p>abstract</p></div>
    [2] Status ("Active" / "Cancelled")
    [3] Originating office ("AFS-360", "AIR-120")
    [4] Issue date (YYYY-MM-DD)
  documentID is embedded in the cell-1 <a href>.

Output JSONL row (matches schema.sql `advisory_circulars`):
    {
      "ac_number":    "AC 43.13-1B",
      "title":        "Acceptable Methods, Techniques, and Practices...",
      "issue_date":   "1998-09-08",
      "related_far":  "14 CFR Part 43",   -- inferred from title/abstract
      "pdf_url":      "https://www.faa.gov/.../documentID/22027"
    }

Bonus fields (underscore-prefixed; build_db.py strips):
    "_abstract", "_status", "_office", "_doc_id"

Usage:
    python3 extract_ac.py --out data/ac_2026-05-31.jsonl
"""

from __future__ import annotations

import argparse
import html
import json
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

try:
    import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _SSL_CTX = ssl.create_default_context()

AC_INDEX_URL = ("https://www.faa.gov/regulations_policies/advisory_circulars/"
                "index.cfm/go/document.list/parentTopicID/0")
DOC_URL = ("https://www.faa.gov/regulations_policies/advisory_circulars/"
           "index.cfm/go/document.information/documentID/")
UA = "AeroSnap-DataPipeline/0.1"

ROW_RE = re.compile(r"<tr[^>]*>(.{50,2500}?)</tr>", re.DOTALL)
CELL_RE = re.compile(r"<td[^>]*>(.*?)</td>", re.DOTALL)
DOC_ID_RE = re.compile(r"documentID/(\d+)")
A_TEXT_RE = re.compile(r"<a[^>]*documentID/\d+[^>]*>(.*?)</a>", re.DOTALL)
ABSTRACT_RE = re.compile(r'<div\s+class="small\s+lineClamp">\s*<p>(.*?)</p>',
                         re.DOTALL | re.IGNORECASE)

# Inferred-FAR detection in title/abstract: "Part 43", "Part 91", etc.
FAR_REF_RE = re.compile(r"\b(?:14\s+CFR\s+)?Part\s+(\d{1,3}[A-Z]?)\b")


def _clean(s: str) -> str:
    s = re.sub(r"<[^>]+>", " ", s)
    s = html.unescape(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def http_get(url: str, retries: int = 3) -> bytes:
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60, context=_SSL_CTX) as resp:
                return resp.read()
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == retries - 1:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("unreachable")


def parse_row(raw_tr: str) -> dict | None:
    if "documentID" not in raw_tr:
        return None
    cells = CELL_RE.findall(raw_tr)
    if len(cells) < 5:
        return None
    doc_id_m = DOC_ID_RE.search(raw_tr)
    if not doc_id_m:
        return None
    doc_id = doc_id_m.group(1)

    ac_number_raw = _clean(cells[0])
    if not ac_number_raw:
        return None
    # Most AC numbers in the FAA list lack the "AC " prefix — add it.
    ac_number = ac_number_raw if ac_number_raw.startswith("AC ") else f"AC {ac_number_raw}"

    # Title is inside <a>, abstract in <div class="small lineClamp">.
    a_m = A_TEXT_RE.search(cells[1])
    title = _clean(a_m.group(1)) if a_m else _clean(cells[1])
    abstract_m = ABSTRACT_RE.search(cells[1])
    abstract = _clean(abstract_m.group(1)) if abstract_m else ""

    status = _clean(cells[2])
    office = _clean(cells[3])
    issue_date = _clean(cells[4])
    # Normalize date — page is already ISO most of the time.
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", issue_date):
        issue_date = issue_date or None

    # Infer related FAR Part from title + abstract (best-effort).
    related = None
    pool = f"{title} {abstract}"
    fm = FAR_REF_RE.search(pool)
    if fm:
        related = f"14 CFR Part {fm.group(1)}"

    return {
        "ac_number": ac_number,
        "title": title or "(untitled)",
        "issue_date": issue_date,
        "related_far": related,
        "pdf_url": DOC_URL + doc_id,
        "_abstract": abstract,
        "_status": status or None,
        "_office": office or None,
        "_doc_id": doc_id,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--cache-dir", default="data/raw/ac",
                        help="Where to cache the FAA index page")
    parser.add_argument("--cache-name", default="ac_index_parentTopicID-0.html")
    args = parser.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / args.cache_name

    if cache_file.exists():
        raw = cache_file.read_text(encoding="utf-8", errors="replace")
        src = "cache"
    else:
        print("[extract_ac] fetching FAA AC master list...", file=sys.stderr)
        raw = http_get(AC_INDEX_URL).decode("utf-8", errors="replace")
        cache_file.write_text(raw, encoding="utf-8")
        src = "network"

    rows = ROW_RE.findall(raw)
    out_rows: list[dict] = []
    seen = set()
    for tr in rows:
        row = parse_row(tr)
        if not row:
            continue
        if row["ac_number"] in seen:
            continue
        seen.add(row["ac_number"])
        out_rows.append(row)

    with out_path.open("w", encoding="utf-8") as f:
        for r in out_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    related_count = sum(1 for r in out_rows if r["related_far"])
    print(f"[extract_ac] DONE: {len(out_rows)} ACs → {out_path} "
          f"({src}; {related_count} with FAR Part inferred)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
