# Aero Snap — Data Pipeline

Builds the bundled SQLite shipped by both iOS (`Aero-Snap/`) and desktop
(`Aero-Snap_Mac_Win_app/`). Target size: ~115–130 MB (spec §3-1).

## Data sources (spec §2)

| Source | Coverage | License | Status |
|---|---|---|---|
| **FAA Airworthiness Directives (AD)** | ~23,000 since 1994, metadata + cleaned body text | Public domain | `extract_ad.py` (PoC needed) |
| **Type Certificate Data Sheets (TCDS)** | ~5,000 models, metadata + spec summary | Public domain | `extract_tcds.py` |
| **14 CFR (FAR)** — Parts 39/43/65/91/121/135/145/147 | ~10–15 MB | Public domain (eCFR) | `extract_far.py` |
| **AD ↔ Model applicability matrix** | ~50,000 rows | Derived — regex + manual verify | `build_ad_applicability.py` (★ value-add) |
| **Advisory Circulars (AC)** — metadata only | ~1,500 | Public domain | `extract_ac.py` |

Excluded by design: Aircraft Registration Master File (60 MB, daily
churn, PII), AD PDFs (linked online), AC bodies (PDFs only),
pre-1994 historical ADs, Service Difficulty Reports.

## Pipeline order

```
extract_ad.py        → data/ad_<date>.jsonl
extract_far.py       → data/far_<date>.jsonl
extract_tcds.py      → data/tcds_<date>.jsonl
extract_ac.py        → data/ac_<date>.jsonl
build_ad_applicability.py  (reads ad_*.jsonl)  → data/ad_applicability_<date>.jsonl
build_db.py          (reads all of the above)  → data/aero_snap_v1.sqlite
```

## Usage

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

python3 extract_ad.py     --out data/ad_2026-05-30.jsonl
python3 extract_far.py    --out data/far_2026-05-30.jsonl
python3 extract_tcds.py   --out data/tcds_2026-05-30.jsonl
python3 extract_ac.py     --out data/ac_2026-05-30.jsonl
python3 build_ad_applicability.py --ad data/ad_2026-05-30.jsonl --out data/ad_applicability_2026-05-30.jsonl
python3 build_db.py
```

## Update cadence

Quarterly (spec §11). Not weekly. Pro tier gets in-app sync + push for
new ADs affecting collection models.

## Schema

`schema.sql` mirrors spec §3 verbatim. `build_db.py` reads it.
