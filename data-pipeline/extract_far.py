"""
extract_far.py — 14 CFR (Federal Aviation Regulations) extractor.

Source: eCFR API — https://www.ecfr.gov/api/versioner/v1/full/{date}/title-14.xml
License: Public domain.

Scope (spec §2-3): core maintenance / certification parts only:
    Part 39  — Airworthiness Directives procedural
    Part 43  — Maintenance, Preventive Maintenance, Rebuilding, Alteration
    Part 65  — Airmen Other Than Flight Crew (A&P, IA certification)
    Part 91  — General Operating and Flight Rules
    Part 121 — Air Carriers (Scheduled)
    Part 135 — Commuter and On-Demand
    Part 145 — Repair Stations
    Part 147 — Aviation Maintenance Technician Schools

XML structure (verified 2026-05-30 against eCFR snapshot 2026-01-01):
    DIV5  = PART       (root of the per-part XML)
    DIV6  = SUBPART    (present in Parts 91/121/135/145; absent in 43/39/65/147)
    DIV8  = SECTION    (the leaves we ship as rows)
        attrib N = "43.13"
        HEAD     = "§ 43.13 Performance rules (general)."
        body text in P / P2 / FP / FP-DASH / PSPACE / I / E etc.

Output JSONL row (matches schema.sql `far_sections`):
    {
      "id":             "14-cfr-43.13",
      "part_number":    "43",
      "section_number": "43.13",
      "subpart":        null,
      "heading":        "Performance rules (general).",
      "body":           "...plaintext...",
      "citation":       "14 CFR § 43.13",
      "last_amended":   null
    }

Usage:
    python3 extract_far.py --out data/far_2026-05-30.jsonl
    python3 extract_far.py --parts 43 --out data/far_part43.jsonl
"""

from __future__ import annotations

import argparse
import json
import re
import ssl
import sys
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path

try:
    import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _SSL_CTX = ssl.create_default_context()

CORE_PARTS = ["39", "43", "65", "91", "121", "135", "145", "147"]
API_URL = "https://www.ecfr.gov/api/versioner/v1/full/{date}/title-14.xml?part={part}"

# Tags whose text content is NOT body — headers, citations, edit notes.
SKIP_TAGS = {"HEAD", "AUTH", "SOURCE", "EDNOTE", "CITA", "SECAUTH", "HED"}

# Strip "§ 43.13 " from "§ 43.13 Performance rules (general)."
HEADING_RE = re.compile(r"^\s*§+\s*[\d.\-A-Za-z]+\s+")


def fetch(date: str, part: str, retries: int = 3) -> bytes:
    url = API_URL.format(date=date, part=part)
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "AeroSnap-DataPipeline/0.1"})
            with urllib.request.urlopen(req, timeout=60, context=_SSL_CTX) as resp:
                return resp.read()
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == retries - 1:
                raise
            sleep_s = 2 ** attempt
            print(f"[extract_far] {url} failed ({e}); retry in {sleep_s}s",
                  file=sys.stderr)
            time.sleep(sleep_s)
    raise RuntimeError("unreachable")


def text_of(el: ET.Element) -> str:
    """Recursive plain-text concat, skipping SKIP_TAGS subtrees."""
    if el.tag in SKIP_TAGS:
        return ""
    parts: list[str] = []
    if el.text:
        parts.append(el.text)
    for child in el:
        parts.append(text_of(child))
        if child.tail:
            parts.append(child.tail)
    return "".join(parts)


def clean_body(s: str) -> str:
    # Collapse runs of whitespace, preserve paragraph breaks via \n\n.
    paragraphs = [re.sub(r"\s+", " ", p).strip() for p in re.split(r"\n\s*\n", s)]
    return "\n\n".join(p for p in paragraphs if p)


def extract_section(div8: ET.Element, part_number: str,
                    subpart: str | None) -> dict | None:
    section_number = div8.attrib.get("N", "").strip()
    if not section_number:
        return None
    head_el = div8.find("HEAD")
    raw_heading = (head_el.text or "").strip() if head_el is not None else ""
    heading = HEADING_RE.sub("", raw_heading).rstrip(". ").strip()
    if not heading:
        heading = raw_heading.strip()

    body_parts: list[str] = []
    for child in div8:
        if child.tag in SKIP_TAGS:
            continue
        body_parts.append(text_of(child))
    body = clean_body("\n\n".join(body_parts))

    if not body and "[Reserved]" in raw_heading:
        body = "[Reserved]"

    return {
        "id": f"14-cfr-{section_number}",
        "part_number": part_number,
        "section_number": section_number,
        "subpart": subpart,
        "heading": heading,
        "body": body,
        "citation": f"14 CFR § {section_number}",
        "last_amended": None,
    }


def extract_part(xml_bytes: bytes, part_number: str):
    root = ET.fromstring(xml_bytes)
    # root is DIV5 for the part
    if root.tag != "DIV5":
        # Some responses wrap; find DIV5 child
        d5 = root.find(".//DIV5")
        if d5 is None:
            return
        root = d5

    subparts = root.findall("DIV6")
    if subparts:
        for sp in subparts:
            sp_letter = sp.attrib.get("N")
            for sec in sp.findall(".//DIV8"):
                row = extract_section(sec, part_number, sp_letter)
                if row:
                    yield row
    else:
        for sec in root.findall(".//DIV8"):
            row = extract_section(sec, part_number, None)
            if row:
                yield row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--date", default="2026-01-01",
                        help="eCFR snapshot date (YYYY-MM-DD)")
    parser.add_argument("--parts", nargs="+", default=CORE_PARTS,
                        help="14 CFR parts to extract")
    parser.add_argument("--cache-dir", default="data/raw/far",
                        help="Where to cache raw XML responses")
    args = parser.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    with out_path.open("w", encoding="utf-8") as f:
        for part in args.parts:
            cache_file = cache_dir / f"title-14_part-{part}_{args.date}.xml"
            if cache_file.exists():
                xml_bytes = cache_file.read_bytes()
                src = "cache"
            else:
                print(f"[extract_far] fetching Part {part}...", file=sys.stderr)
                xml_bytes = fetch(args.date, part)
                cache_file.write_bytes(xml_bytes)
                src = "network"
            count = 0
            for row in extract_part(xml_bytes, part):
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                count += 1
            total += count
            print(f"[extract_far] Part {part}: {count} sections ({src})",
                  file=sys.stderr)

    print(f"[extract_far] DONE: {total} sections → {out_path}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
