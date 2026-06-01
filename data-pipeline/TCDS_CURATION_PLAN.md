# TCDS Curation Plan — v1 Ship Target

**Status (2026-06-01):** 43 of 200 entries curated (`tcds_seed.jsonl`).

**Strategy decided:** Option B (hand-curated seed). See
`memory/project_aero_decisions.md` § "TCDS strategy" for the trade-off
analysis and `DRS_RESEARCH.md` for the Option-A backlog (full DRS
scrape, deferred to v2).

## Coverage target — 200 entries by category

The list is sized to cover ~80% of A&P / IA / aircraft-owner TCDS
queries while staying small enough that one curator can finish it in
1–2 focused sessions.

| Category | Target | Have | Examples (representative, not exhaustive) |
|----------|-------:|-----:|-------------------------------------------|
| GA single-engine | 80 | ~15 | Cessna 150/152/172/182/206/210, Piper PA-18/28/32/46, Beech Bonanza/Sundowner, Mooney M20, Cirrus SR20/22, Diamond DA20/40, Grumman AA-1/5, Maule M-7, Aviat Husky, American Champion 7-/8-series |
| GA twin / light turbine | 30 | ~4 | Piper Aztec / Seneca / Navajo / Cheyenne, Beech Baron / King Air 90/200/350, Cessna 310/337/340/414/421/425/441, Mitsubishi MU-2 |
| Commercial transport | 20 | ~3 | Boeing 737-700/800/900/MAX, 757-200/300, 767-300, 777-200/300ER, 787-8/9/10, 747-400, A319/320/321 (neo + ceo), A330-200/300/900, A350-900/1000, ERJ-170/175/190, CRJ-700/900 |
| Rotorcraft | 15 | ~2 | Bell 206/407/412/505/429, Robinson R22/R44/R66, Eurocopter / Airbus AS350/355, EC130/135, Sikorsky S-76, Schweizer 300 |
| Piston engines | 30 | ~10 | Lycoming O-235/O-320/O-360/IO-360/IO-540/IO-720, Continental O-200/O-300/IO-360/IO-470/IO-520/IO-550/TSIO-520, Rotax 912/914/915 |
| Turbine engines | 10 | ~2 | P&W PT6A series, JT8D, JT9D, PW100, PW1000G, GE CF6, CF34, CFM56, GE9X, RR Trent series |
| Propellers | 15 | ~7 | Hartzell HC-A2X / HC-C2YK / HC-E3Y / Top-Prop, McCauley A/B/C/1A/2A/3A, Sensenich M/W series, MT-Propeller |

Totals: 200 target, 43 in hand — 157 to research.

## Curation workflow

For each TCDS:

1. **Look up the official TCDS PDF** on the FAA DRS site:
   `https://drs.faa.gov/browse/TCDSMODEL/doctypeDetails/<TCDS>`
   (e.g. `/3A12` for Cessna 172). Public-domain document — no
   license issues with extracting values.
2. **Read off the header fields:**
   `tcds_number`, `category` (Aircraft / Engine / Propeller),
   `manufacturer` (use the legal name as printed on the TCDS, e.g.
   "Piper Aircraft, Inc."), `models` (CSV of model designations
   from the TCDS face — group variants on one row when they share
   a TCDS, like "172, 172A, 172B, …, 172S").
3. **Optional but valuable:** `issue_date` (ISO 8601),
   `last_revision` (ISO 8601), and `specifications` (free-form
   object — common keys: `engine` / `engine_options`,
   `category` for airworthiness category like Normal/Utility/
   Acrobatic, `seats`, `mtow_lbs`).
4. **Append the JSON to `tcds_seed.jsonl`** (one entry per line —
   no trailing comma, no array wrapper). `extract_tcds.py` reads it
   on the next pipeline run.

## Quality bar

- Manufacturer names must match the legal name on the TCDS face —
  "Cessna Aircraft Company" not "Cessna", "Piper Aircraft, Inc."
  not "Piper" — so the in-app Make/Model search behaves predictably.
- Model strings stay as the TCDS prints them. Don't normalize "172"
  → "C172" or "PA-28-181" → "Archer".
- Skip TCDS where the type is no longer in production AND the
  installed fleet is functionally zero (e.g. pre-WWII oddballs).
  We're optimizing for the working-aircraft long tail, not history.

## Why 200 (not 50, not 3000)

- 50 covers commodity aircraft only and misses the working-fleet
  long tail that A&P shops actually see.
- 3000 = full DRS corpus — blocked by Option A and won't be in v1.
- 200 is the smallest set where every working A&P I've talked to
  reports "yeah, that's the aircraft I'd look up." It also fits in
  a single sit-down curation session if necessary.
