"""
extract_ad.py — Airworthiness Directives extractor.

Source:
  - Federal Register API: https://www.federalregister.gov/api/v1/documents.json
  - Filter: agency=federal-aviation-administration, type=RULE, term=airworthiness directive
  - Full body via raw_text_url (HTML-wrapped <pre>) or body_html_url
  - Public domain.

Scope (spec §2-1): all ADs since 1994. PoC mode pulls N most-recent.
We do NOT bundle PDFs — pdf_url is stored as a link the app dereferences online.

Header pattern in every AD (verified across multiple 2026 ADs):
    [Docket No. FAA-2025-3993; Project Identifier MCAI-2025-00630-A;
     Amendment 39-23358; AD 2026-10-18]

Body has labeled regulatory sections (a)..(z):
    (a) Effective Date
    (b) Affected ADs            — supersedes chain
    (c) Applicability           — ★ feeds AD↔Model matrix
    (d) Subject                 — JASC/ATA code
    (e) Unsafe Condition
    (f) Compliance              — compliance_time string
    (g) Required Actions
    ...

Output JSONL row (matches schema.sql `airworthiness_directives` columns,
plus underscore-prefixed intermediate fields for downstream stages):
    {
      "ad_number":           "2026-10-18",
      "ad_year":             2026,
      "title":               "Airworthiness Directives; Embraer S.A. Airplanes",
      "effective_date":      "2026-07-06",
      "federal_register_id": "2026-10854",
      "cfr_amendment":       "39-23358",
      "summary":             "...FR abstract verbatim...",
      "body":                "...cleaned plaintext...",
      "compliance_time":     "Within 60 days...",
      "is_emergency":        0,
      "supersedes":          null,
      "superseded_by":       null,
      "ata_chapter":         "27",
      "pdf_url":             "https://www.federalregister.gov/.../pdf",
      "fr_url":              "https://www.federalregister.gov/documents/...",
      "_applicability_text": "This AD applies to Embraer S.A. Model EMB-505..."
    }

Underscore-prefixed fields are picked up by build_ad_applicability.py
and stripped by build_db.py.

Usage:
    python3 extract_ad.py --limit 10 --out data/ad_poc.jsonl
    python3 extract_ad.py --since 2026-01-01 --out data/ad_2026-05-30.jsonl
"""

from __future__ import annotations

import argparse
import html
import json
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
import urllib.error
from html.parser import HTMLParser
from pathlib import Path

try:
    import certifi
    _SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    _SSL_CTX = ssl.create_default_context()

FR_API = "https://www.federalregister.gov/api/v1/documents.json"
UA = "AeroSnap-DataPipeline/0.1 (+https://github.com/RangeAreaScent)"

# [Amendment 39-23358; AD 2026-10-18] — allow revision suffix like "2010-26-05R1"
AD_HEADER_RE = re.compile(
    r"\[Docket\s+No\.?:?\s*([\w\-]+);?[^\]]*?"
    r"Amendment\s+(\d+-\d+)\s*;\s*"
    r"AD\s+(\d{4}-\d{2}-\d{2}(?:R\d+)?)\s*\]",
    re.IGNORECASE,
)

# Labeled section heads:  (c) Applicability
SECTION_RE = re.compile(r"^\(([a-z])\)\s+([A-Z][^\n]{0,80})$", re.MULTILINE)

# JASC code in (d) Subject (first 2 digits map to ATA chapter)
JASC_RE = re.compile(r"\bJASC\)?\s+Code\s+(\d{2,4})", re.IGNORECASE)
# Match both "ATA Code 27" and "Air Transport Association (ATA) of America Code 27"
ATA_RE = re.compile(
    r"(?:\bATA\b|Air\s+Transport\s+Association)[^\n]{0,60}?Code\s+(\d{2,4})",
    re.IGNORECASE,
)

# "Affected ADs" section — supersedes a previous AD number.
# FAA wording is usually "replaces" or "affects" (rarely literal "supersedes").
SUPERSEDES_RE = re.compile(
    r"\b(?:replaces?|supersed(?:es?|ing)|affects?)\s+AD\s+(\d{4}-\d{2}-\d{2}(?:R\d+)?)",
    re.IGNORECASE,
)

# FR plaintext uses typewriter entity placeholders: [eacute], [ccedil], etc.
# Decode the common ones so manufacturer names dedup correctly.
_FR_ENTITIES = {
    "[eacute]": "é", "[Eacute]": "É",
    "[egrave]": "è", "[Egrave]": "È",
    "[ecirc]":  "ê", "[Ecirc]":  "Ê",
    "[ccedil]": "ç", "[Ccedil]": "Ç",
    "[atilde]": "ã", "[Atilde]": "Ã",
    "[ntilde]": "ñ", "[Ntilde]": "Ñ",
    "[ouml]":   "ö", "[Ouml]":   "Ö",
    "[uuml]":   "ü", "[Uuml]":   "Ü",
    "[auml]":   "ä", "[Auml]":   "Ä",
    "[aacute]": "á", "[Aacute]": "Á",
    "[iacute]": "í", "[Iacute]": "Í",
    "[oacute]": "ó", "[Oacute]": "Ó",
    "[uacute]": "ú", "[Uacute]": "Ú",
    "[ucirc]":  "û", "[Ucirc]":  "Û",
    "[icirc]":  "î", "[Icirc]":  "Î",
    "[ocirc]":  "ô", "[Ocirc]":  "Ô",
    "[acirc]":  "â", "[Acirc]":  "Â",
}


def decode_fr_entities(s: str) -> str:
    for k, v in _FR_ENTITIES.items():
        if k in s:
            s = s.replace(k, v)
    return s


class _StripPre(HTMLParser):
    """Strip HTML, keeping <pre> block plaintext + decoding entities."""
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._in_pre = False
        self._buf: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag == "pre":
            self._in_pre = True

    def handle_endtag(self, tag):
        if tag == "pre":
            self._in_pre = False

    def handle_data(self, data):
        if self._in_pre:
            self._buf.append(data)

    def get(self) -> str:
        return "".join(self._buf)


def strip_html(s: str) -> str:
    p = _StripPre()
    p.feed(s)
    out = p.get()
    if not out:
        # Fallback: regex-strip when there's no <pre>
        out = re.sub(r"<[^>]+>", "", s)
        out = html.unescape(out)
    # Rejoin hyphen-wrapped tokens like "HA-\n 420" → "HA-420"
    # (FR plaintext wraps mid-token; breaks model regex if left as-is.)
    out = re.sub(r"-\s*\n\s+(?=[A-Z0-9])", "-", out)
    # Decode FR typewriter entity placeholders ([eacute] → é etc.)
    out = decode_fr_entities(out)
    return out


class NotFound(Exception):
    """Permanent 404 — caller should skip the AD, not retry the whole run."""


def http_get(url: str, retries: int = 3, accept: str = "application/json") -> bytes:
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": UA, "Accept": accept})
            with urllib.request.urlopen(req, timeout=60, context=_SSL_CTX) as resp:
                return resp.read()
        except urllib.error.HTTPError as e:
            # 404 = the resource was renamed/withdrawn (common for old
            # AD raw_text_urls). Don't retry; let the caller skip.
            if e.code == 404:
                raise NotFound(url) from e
            # 5xx and other transient — retry with backoff.
            if attempt == retries - 1:
                raise
            sleep_s = 2 ** attempt
            print(f"[extract_ad] {url} failed (HTTP {e.code}); retry in {sleep_s}s",
                  file=sys.stderr)
            time.sleep(sleep_s)
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == retries - 1:
                raise
            sleep_s = 2 ** attempt
            print(f"[extract_ad] {url} failed ({e}); retry in {sleep_s}s",
                  file=sys.stderr)
            time.sleep(sleep_s)
    raise RuntimeError("unreachable")


_FR_PAGE_SIZE = 500  # FR allows up to 1000; 500 is a polite middle ground.


def _fr_search_url(per_page: int, page: int, since: str | None) -> str:
    params = {
        "conditions[agencies][]": "federal-aviation-administration",
        "conditions[type][]": "RULE",
        "conditions[term]": "airworthiness directive",
        "per_page": str(per_page),
        "page": str(page),
        "order": "newest",
        "fields[]": [
            "document_number", "title", "publication_date", "effective_on",
            "html_url", "raw_text_url", "pdf_url", "abstract",
        ],
    }
    if since:
        params["conditions[publication_date][gte]"] = since
    qs_pairs: list[tuple[str, str]] = []
    for k, v in params.items():
        if isinstance(v, list):
            for item in v:
                qs_pairs.append((k, item))
        else:
            qs_pairs.append((k, v))
    return FR_API + "?" + urllib.parse.urlencode(qs_pairs)


def fr_search(limit: int, since: str | None = None) -> list[dict]:
    """Paginate FR until we have `limit` results or the result set runs out."""
    per_page = min(_FR_PAGE_SIZE, limit)
    out: list[dict] = []
    page = 1
    while len(out) < limit:
        url = _fr_search_url(per_page, page, since)
        raw = http_get(url)
        data = json.loads(raw)
        results = data.get("results", [])
        if not results:
            break
        out.extend(results)
        total_pages = data.get("total_pages", 1)
        print(f"[extract_ad] page {page}/{total_pages}: +{len(results)} "
              f"(running total {len(out)})", file=sys.stderr)
        if page >= total_pages:
            break
        page += 1
        time.sleep(0.5)  # be polite to FR
    return out[:limit]


def split_sections(body: str) -> dict[str, str]:
    """Return {letter: (heading, text)}."""
    matches = list(SECTION_RE.finditer(body))
    out: dict[str, tuple[str, str]] = {}
    for i, m in enumerate(matches):
        letter = m.group(1).lower()
        heading = m.group(2).strip()
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(body)
        text = body[start:end].strip()
        out[letter] = (heading, text)
    return {k: v[1] for k, v in out.items()}  # we only need the text bodies


def clean_text(s: str) -> str:
    s = re.sub(r"\[\[Page \d+\]\]", "", s)
    s = re.sub(r"-{3,}", "", s)
    # collapse whitespace inside paragraphs, preserve blank-line breaks
    paragraphs = [re.sub(r"\s+", " ", p).strip() for p in re.split(r"\n\s*\n", s)]
    return "\n\n".join(p for p in paragraphs if p)


def parse_ad(meta: dict, raw_text: str) -> dict | None:
    plain = strip_html(raw_text)
    header_m = AD_HEADER_RE.search(plain)
    if not header_m:
        print(f"[extract_ad] WARN: no AD header in {meta.get('document_number')}",
              file=sys.stderr)
        return None
    docket = header_m.group(1)
    cfr_amendment = header_m.group(2)
    ad_number = header_m.group(3)
    ad_year = int(ad_number.split("-")[0])

    # Body starts at the first labeled section header "(a) Effective Date"
    # to skip preamble, comment-response, and economic-analysis chaff.
    sec_match = re.search(r"\(a\)\s+Effective Date", plain)
    if sec_match:
        body_raw = plain[sec_match.start():]
        # End at "Issued in ..." signature line common to all ADs.
        sig_m = re.search(r"\n\s*Issued\s+(?:on|in)\s+", body_raw)
        if sig_m:
            body_raw = body_raw[:sig_m.start()]
    else:
        body_raw = plain

    body = clean_text(body_raw)
    sections = split_sections(body)

    applicability_text = sections.get("c", "")
    compliance_time = sections.get("f", "") or sections.get("g", "")
    subject_text = sections.get("d", "")

    ata = None
    jm = JASC_RE.search(subject_text)
    if jm:
        ata = jm.group(1)[:2]
    else:
        am = ATA_RE.search(subject_text)
        if am:
            ata = am.group(1)[:2]

    sup_m = SUPERSEDES_RE.search(sections.get("b", ""))
    supersedes = sup_m.group(1) if sup_m else None

    title = meta.get("title", "")
    is_emergency = 1 if re.search(r"emergency", title, re.IGNORECASE) else 0

    return {
        "ad_number": ad_number,
        "ad_year": ad_year,
        "title": title,
        "effective_date": meta.get("effective_on") or meta.get("publication_date"),
        "federal_register_id": meta.get("document_number"),
        "cfr_amendment": cfr_amendment,
        "summary": (meta.get("abstract") or "").strip(),
        "body": body,
        "compliance_time": compliance_time[:500] if compliance_time else None,
        "is_emergency": is_emergency,
        "supersedes": supersedes,
        "superseded_by": None,  # filled in a post-pass after all ADs loaded
        "ata_chapter": ata,
        "pdf_url": meta.get("pdf_url"),
        "fr_url": meta.get("html_url"),
        "_applicability_text": applicability_text,
        "_docket": docket,
    }


def resolve_supersede_chain(rows: list[dict]) -> None:
    by_num = {r["ad_number"]: r for r in rows}
    for r in rows:
        if r["supersedes"] and r["supersedes"] in by_num:
            by_num[r["supersedes"]]["superseded_by"] = r["ad_number"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--limit", type=int, default=10,
                        help="Max ADs to fetch (FR per_page; PoC default 10)")
    parser.add_argument("--since", default=None,
                        help="Publication date floor (YYYY-MM-DD)")
    parser.add_argument("--cache-dir", default="data/raw/ad",
                        help="Where to cache FR raw_text responses")
    parser.add_argument("--verbose", action="store_true",
                        help="Print one log line per AD (default: every 50)")
    args = parser.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)

    print(f"[extract_ad] querying FR for up to {args.limit} ADs...", file=sys.stderr)
    metas = fr_search(limit=args.limit, since=args.since)
    print(f"[extract_ad] FR returned {len(metas)} candidates", file=sys.stderr)

    rows: list[dict] = []
    skipped_no_header = 0
    skipped_404 = 0
    network_count = 0
    for i, meta in enumerate(metas, 1):
        doc_num = meta.get("document_number")
        if not doc_num or not meta.get("raw_text_url"):
            continue
        cache_file = cache_dir / f"{doc_num}.html"
        if cache_file.exists():
            raw = cache_file.read_bytes().decode("utf-8", errors="replace")
            src = "cache"
        else:
            try:
                raw_bytes = http_get(meta["raw_text_url"], accept="text/html")
            except NotFound:
                # FR resource gone — log + skip; don't kill the run. Write
                # a sentinel so we don't keep retrying on resume.
                skipped_404 += 1
                print(f"[extract_ad] WARN: 404 for {doc_num}, skipping",
                      file=sys.stderr)
                cache_file.write_text("<!-- 404 -->", encoding="utf-8")
                continue
            raw = raw_bytes.decode("utf-8", errors="replace")
            cache_file.write_text(raw, encoding="utf-8")
            src = "net"
            network_count += 1
            # polite pacing only for network calls
            if network_count % 25 == 0:
                time.sleep(0.5)
        # Skip 404 sentinels saved on prior runs.
        if raw.startswith("<!-- 404 -->"):
            skipped_404 += 1
            continue
        row = parse_ad(meta, raw)
        if row:
            rows.append(row)
            if i % 50 == 0 or args.verbose:
                print(f"[extract_ad] {i:4d}/{len(metas)} AD {row['ad_number']}  "
                      f"ATA={row['ata_chapter'] or '?':>2}  ({src})", file=sys.stderr)
        else:
            skipped_no_header += 1

    resolve_supersede_chain(rows)

    with out_path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[extract_ad] DONE: {len(rows)} ADs → {out_path} "
          f"(skipped {skipped_no_header} w/o header, "
          f"{skipped_404} 404s, "
          f"{network_count} network, "
          f"{len(metas) - network_count - skipped_404} cache)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
