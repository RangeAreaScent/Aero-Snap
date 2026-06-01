# TCDS Curation Plan — v1 Ship Target

**Status (2026-06-01):** 62 of 200 entries curated (`tcds_seed.jsonl`).
Batch 2 added 19 high-confidence commodity GA + retired-transport
entries — see the `// === Batch 2: ...` separator in the seed file.
Each batch-2 entry should be re-verified against the actual FAA DRS
PDF before App Store submission.

The pipeline now fails the build if two seed rows share the same
`tcds_number` (caught at `extract_tcds.py` time, before SQLite
silently dedups). Curators get a clear "duplicate at line N and M"
error instead of a "row count is off by one" mystery.

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
| GA single-engine | 80 | 25 | Cessna 150/152/170/172/175/180/182/185/195/206/210, Piper J-3/PA-22/PA-24/PA-28/PA-32, Beech Bonanza/Sundowner, Mooney M20, Cirrus SR20/22, Grumman AA-1/5. Still needed: Diamond DA20/40, Maule M-7, Aviat Husky, American Champion 7-/8-series, Cessna L-19/305, Pilatus PC-12 |
| GA twin / light turbine | 30 | 9 | Cessna 310/337/Caravan 208, Piper PA-23 Aztec/PA-31/PA-34/PA-44/PA-46, Beech Baron 55 / Duchess 76 / 1900. Still needed: Beech King Air 90/200/350, Cessna 340/414/421/425/441, Piper Cheyenne PA-42, Mitsubishi MU-2 |
| Commercial transport | 20 | 12 | Boeing 717/737 all gens/747 all gens/757/767/777/787, DC-9/MD-80/MD-90, Airbus A310/A318-321/A330/A350/A380, Embraer ERJ-170/190, Bombardier CRJ. Still needed: Boeing 707/720, DC-10/MD-11 (collided with 757 TCDS A22WE on first attempt — confirm exact number before re-adding), A220, Q400, ATR 42/72, Phenom 100/300 |
| Rotorcraft | 15 | 4 | Bell 47/206/407, Robinson R22/R44. Still needed: Bell 412/505/429, Robinson R66, Eurocopter / Airbus AS350/355, EC130/135, Sikorsky S-76, Schweizer 300 |
| Piston engines | 30 | 1 | Continental O-200. Still needed: Lycoming O-235/O-320/O-360/IO-360/IO-540/IO-720, Continental O-300/IO-360/IO-470/IO-520/IO-550/TSIO-520, Rotax 912/914/915 |
| Turbine engines | 10 | 4 | CFM56, LEAP-1A, JT9D, GEnx. Still needed: P&W PT6A series, JT8D, PW100, PW1000G, GE CF6, CF34, GE9X, RR Trent series |
| Propellers | 15 | 0 | All needed: Hartzell HC-A2X / HC-C2YK / HC-E3Y / Top-Prop, McCauley A/B/C/1A/2A/3A, Sensenich M/W series, MT-Propeller |

Totals: 200 target, 62 in hand — 138 to research.

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
