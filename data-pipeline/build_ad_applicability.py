"""
build_ad_applicability.py — AD ↔ Aircraft Model matrix.

★ Aero Snap's largest proprietary value-add (spec §2-4, §4-2).
FAA does NOT publish AD applicability as structured data. We parse the
free-text "(c) Applicability" clause that extract_ad.py captured into
`_applicability_text` and emit one row per (AD, manufacturer, model).

PoC strategy — regex bank for the common templates we observed across
10 real 2026 ADs:

  Pattern A: explicit serial range
      "Model HA-420 airplanes, serial numbers 42000012 through 42000230"
  Pattern B: model list, no serial constraint
      "Model 747-100, -100B, -100B SUD, -200B, ... and 747SR series airplanes"
  Pattern C: "all <Manufacturer> Model <X>" — covers all serial numbers
  Pattern D: part-based (e.g. Goodrich seats, engine model)
      "Goodrich cabin attendant seats, part numbers ..."
      "Rolls-Royce ... Model RB211 Trent 768-60, 772-60, and 772B-60 engines"

We extract the COARSE (manufacturer, model) pair. Serial ranges and
part numbers are stored as `notes` when present; the fine-grained
applicability decision still requires reading the AD body.

Known manufacturers (seeded from observed ADs; extend as we scale):
  Airbus, Airbus SAS, Boeing, Bombardier, Embraer, Goodrich,
  Honda Aircraft Company, Rolls-Royce, Cessna, Beechcraft, Piper,
  General Electric, Pratt & Whitney, Lycoming, Continental, Garmin.

Part_type inferred from AD's ATA chapter:
  21-50 → Airframe  (cabin/structures/landing gear/flight controls)
  71-80 → Engine
  60-65 → Propeller / rotors
  default → Appliance

Usage:
    python3 build_ad_applicability.py --ad data/ad_poc.jsonl \\
        --out data/ad_applicability_poc.jsonl \\
        --review data/ad_applicability_review.tsv
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MANUFACTURERS = [
    # Order matters — longer / more specific first. Multi-word vendors before
    # bare names so "The Boeing Company" wins over "Boeing".

    # Airframers (airplanes)
    "The Boeing Company",
    "Airbus Canada Limited Partnership",
    "Airbus Helicopters",
    "Airbus SAS",
    "Airbus",
    "Boeing",
    "Embraer S.A.",
    "Embraer",
    "Bombardier, Inc.",
    "Bombardier",
    "Honda Aircraft Company LLC",
    "Honda Aircraft Company",
    "Cessna Aircraft Company",
    "Cessna",
    "Beechcraft",
    "Piper Aircraft, Inc.",
    "Piper",
    "Textron Aviation",
    "Baykar Piaggio Aerospace S.p.A.",
    "Piaggio Aerospace",
    "Dassault Aviation",
    "Gulfstream Aerospace LP",
    "Gulfstream Aerospace",
    "Deutsche Aircraft GmbH",
    "Fiberglas-Technik Rudolf Lindner GmbH & Co. KG",
    "ATR-GIE Avions de Transport Régional",  # post-entity-decode form
    "ATR",

    # Engines
    "Rolls-Royce Deutschland Ltd & Co KG",
    "Rolls-Royce plc",
    "Rolls-Royce",
    "General Electric Company",
    "General Electric",
    "GE Aviation Czech s.r.o.",
    "CFM International, S.A.",
    "CFM International",
    "Pratt & Whitney Canada Corp.",
    "Pratt & Whitney",
    "Safran Helicopter Engines, S.A.",
    "Safran Helicopter Engines",
    "Lycoming Engines",
    "Lycoming",
    "Continental Aerospace Technologies",
    "Continental",

    # Helicopters / rotorcraft
    "Bell Textron",
    "Sikorsky",
    "Leonardo S.p.A.",
    "Leonardo",
    "Robinson Helicopter Company",
    "MD Helicopters",

    # Components / appliances
    "Goodrich",
    "Garmin",
    "Honeywell",
    "Collins Aerospace",
    "Pacific Scientific Company",
    "Pacific Scientific",
    "Ipeco Holdings Limited",
    "Ipeco",
    "Thommen Aircraft Equipment AG",
    "Thommen",
    "Aerospace & Defense Oxygen Systems SaS",
    "Cameron Balloons Ltd.",
    "Cameron Balloons",
]

# "Model <token>" capture — model token can have hyphens, digits, letters,
# slashes. Stop at comma, semicolon, period, parenthesis, or " airplanes".
MODEL_TOKEN = r"[A-Z0-9][A-Za-z0-9\-/.]*"
MODEL_RE = re.compile(
    rf"\bModel\s+(?P<model>{MODEL_TOKEN}(?:\s+(?:series|airplanes|helicopters))?)",
)

# Comma-separated model list: "Model 747-100, -100B, -100B SUD, -200B, ..."
# We treat each comma-led "-XXX" fragment as a sibling sharing the base.
MODEL_LIST_RE = re.compile(
    rf"\bModel\s+({MODEL_TOKEN})((?:\s*,\s*-{MODEL_TOKEN}|\s+and\s+-{MODEL_TOKEN})+)",
)

SERIAL_RANGE_RE = re.compile(
    r"serial numbers?\s+([A-Z0-9\-]+)\s+(?:through|to|-)\s+([A-Z0-9\-]+)",
    re.IGNORECASE,
)

PART_NUMBERS_RE = re.compile(r"part numbers?\s+([A-Z0-9\-,\s]+)", re.IGNORECASE)

ALL_SERIALS_RE = re.compile(
    r"\ball\s+(?:serial numbers|serials|S/Ns)\b", re.IGNORECASE,
)


def _normalize(s: str) -> str:
    """Collapse double-hyphens (FR artifact "ATR--GIE" → "ATR-GIE")."""
    return re.sub(r"--+", "-", s)


def find_manufacturer(text: str) -> str | None:
    normalized = _normalize(text)
    for m in MANUFACTURERS:
        if re.search(rf"\b{re.escape(m)}\b", normalized):
            return m
    # Fallback: look at "applies to <X> Model" — capture the bit before "Model"
    fb = re.search(r"applies to\s+(?:all\s+|certain\s+|the\s+(?:following\s+)?)?(.+?)\s+Model\b",
                   normalized, re.IGNORECASE)
    if fb:
        cand = fb.group(1).strip(" ,;.")
        cand = re.sub(r"\s+", " ", cand)
        # Trim parenthetical type-cert-history clauses
        cand = re.sub(r"\s*\([^)]*previously held by[^)]*\)\s*", " ", cand,
                      flags=re.IGNORECASE).strip()
        if 2 <= len(cand) <= 80:
            return cand
    return None


_TRAILING_NOISE = re.compile(r"\s+(?:series|airplanes|helicopters|engines|aircraft)$",
                             re.IGNORECASE)


def _strip_noise(s: str) -> str:
    return _TRAILING_NOISE.sub("", s).strip()


def expand_model_list(base: str, tail: str) -> list[str]:
    """Given base='747-100' and tail=', -100B, -100B SUD, and -200B',
       yield ['747-100', '747-100B', '747-100B SUD', '747-200B'].

       Prefix = base with its last '-XXX' segment stripped. Siblings
       beginning with '-' get glued to that prefix; bare tokens are
       treated as full standalone models.
    """
    base_clean = _strip_noise(base)
    out = [base_clean]
    prefix_m = re.match(r"^(.+)-[^-\s]+$", base_clean)
    prefix = prefix_m.group(1) if prefix_m else base_clean
    for p in re.split(r"\s*(?:,|\band\b)\s*", tail):
        p = _strip_noise(p.strip())
        if not p:
            continue
        out.append(f"{prefix}{p}" if p.startswith("-") else p)
    # Dedup preserving order
    seen = set()
    uniq = []
    for m in out:
        if m and m not in seen:
            seen.add(m)
            uniq.append(m)
    return uniq


def infer_part_type(ata: str | None, applicability: str) -> str:
    text_lower = applicability.lower()
    if "engine" in text_lower:
        return "Engine"
    if "propeller" in text_lower or "rotor" in text_lower:
        return "Propeller"
    if "seat" in text_lower or "appliance" in text_lower:
        return "Appliance"
    if not ata:
        return "Airframe"
    try:
        a = int(ata)
    except ValueError:
        return "Airframe"
    if 71 <= a <= 80:
        return "Engine"
    if 60 <= a <= 65:
        return "Propeller"
    return "Airframe"


def extract_rows(ad: dict) -> list[dict]:
    ad_num = ad["ad_number"]
    text = ad.get("_applicability_text", "") or ""
    if not text:
        return []

    manufacturer = find_manufacturer(text) or "UNKNOWN"

    # Try the comma-list pattern first to expand model siblings.
    models: list[str] = []
    list_m = MODEL_LIST_RE.search(text)
    if list_m:
        base = list_m.group(1)
        tail = list_m.group(2)
        models = expand_model_list(base, tail)
    else:
        for m in MODEL_RE.finditer(text):
            tok = m.group("model").strip()
            tok = re.sub(r"\s+(?:series|airplanes|helicopters)$", "", tok).strip()
            if tok and tok not in models:
                models.append(tok)

    if not models:
        # No model — bail with a single UNKNOWN row so the AD still surfaces.
        models = ["UNKNOWN"]

    serial_start = None
    serial_end = None
    sm = SERIAL_RANGE_RE.search(text)
    if sm:
        serial_start, serial_end = sm.group(1), sm.group(2)

    notes_bits: list[str] = []
    if ALL_SERIALS_RE.search(text):
        notes_bits.append("All serial numbers")
    pm = PART_NUMBERS_RE.search(text)
    if pm:
        notes_bits.append(f"Part numbers: {pm.group(1).strip()[:120]}")

    part_type = infer_part_type(ad.get("ata_chapter"), text)

    rows = []
    for model in models:
        rows.append({
            "ad_number": ad_num,
            "manufacturer": manufacturer,
            "model": model,
            "model_series": None,
            "serial_range_start": serial_start,
            "serial_range_end": serial_end,
            "part_type": part_type,
            "notes": "; ".join(notes_bits) or None,
        })
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--ad", required=True, help="Input AD JSONL")
    parser.add_argument("--out", required=True, help="Output JSONL path")
    parser.add_argument("--review", default=None,
                        help="TSV report of low-confidence rows for manual QA")
    args = parser.parse_args()

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    ad_rows = [json.loads(l) for l in Path(args.ad).read_text(encoding="utf-8").splitlines() if l.strip()]
    review_rows: list[dict] = []
    out_rows: list[dict] = []

    for ad in ad_rows:
        rows = extract_rows(ad)
        out_rows.extend(rows)
        for r in rows:
            if r["manufacturer"] == "UNKNOWN" or r["model"] == "UNKNOWN":
                review_rows.append({"ad_number": ad["ad_number"],
                                    "applicability": ad.get("_applicability_text", "")[:300]})

    with out_path.open("w", encoding="utf-8") as f:
        for r in out_rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")

    print(f"[applicability] {len(ad_rows)} ADs → {len(out_rows)} rows "
          f"({len(review_rows)} need manual review)", file=sys.stderr)

    if args.review and review_rows:
        with Path(args.review).open("w", encoding="utf-8") as f:
            f.write("ad_number\tapplicability\n")
            for r in review_rows:
                appl = r["applicability"].replace("\t", " ").replace("\n", " ")
                f.write(f"{r['ad_number']}\t{appl}\n")
        print(f"[applicability] review TSV → {args.review}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
