# Aero Snap — Domain Spec

> Living spec for the iOS + desktop apps. The canonical, authoritative
> early spec lives at
> `../SNAP Series Plan/SNAP series SPEC and guide/11_Aero_Snap_Spec.md` —
> this file is the as-built version that diverges as we learn.
>
> Last updated 2026-05-30 (Stage 0 spec → data-pipeline begun).

## 1. The dataset

| Source | Coverage | License | Status |
|---|---|---|---|
| **FAA Airworthiness Directives** | ADs since 1994 (~23,000) | Public domain (FAA / Federal Register) | PoC working (10 real ADs ingested) |
| **AD ↔ Aircraft Model matrix** | ~50,000 rows (derived) | Derived — regex + manual verify | PoC working (36 rows from 10 ADs) |
| **14 CFR (FAR)** — Parts 39/43/65/91/121/135/145/147 | ~1,022 sections | Public domain (eCFR) | **DONE 2026-05-30** (1,022 / 0 empty bodies) |
| **TCDS** — Type Certificate Data Sheets | ~5,000 models | Public domain (FAA DRS) | Not started |
| **Advisory Circulars** — metadata only | ~1,500 | Public domain | Not started |

**Excluded by design**: Aircraft Registration Master File (60 MB,
daily churn, PII), AD PDFs (linked online), AC bodies (PDF-only),
pre-1994 historical ADs, Service Difficulty Reports.

**Storage**: bundled SQLite (`aero_snap_v1.sqlite`). Target size at full
scale: 115–130 MB. PoC build is 3.26 MB (10 ADs + all 8 FAR parts).
**Update cadence**: quarterly. Spec §11.

## 2. The item shape

Five top-level entities — see `data-pipeline/schema.sql` for the
authoritative DDL. Each entity has a corresponding FTS5 shadow table
for full-text search (ad_fts, far_fts, tcds_fts).

| Entity | Primary key | Searchable on | Detail-screen fields |
|---|---|---|---|
| `airworthiness_directives` | ad_number ("2026-10-18") | ad_number, title, summary, body, ata_chapter | + effective_date, cfr_amendment, compliance_time, supersedes chain, pdf_url, fr_url |
| `ad_applicability` | (synthetic id) | manufacturer, model | + serial_range, part_type, notes |
| `far_sections` | "14-cfr-43.13" | citation, heading, body | + part_number, subpart |
| `type_certificates` | tcds_number | tcds_number, manufacturer, models | + category, specifications JSON |
| `advisory_circulars` | ac_number | (metadata only) | + related_far, pdf_url |

## 3. Abbreviation dictionary

Not yet seeded. Field-vocabulary candidates: A&P, IA, AD, TCDS, FAR,
TCDS, AC, MRO, FBO, ATA chapter, JASC, MEL, HOS, EAD, NPRM, MCAI.

## 4. Identity

- **Display name**: Aero Snap (no country suffix per playbook §4 +
  STATUS activity log 2026-05-30; "(US)" is implicit for the domestic
  series).
- **Tagline**: "A&P mechanics, IAs, MROs — find every AD, FAR, and
  TCDS in seconds. Built for the hangar floor."
- **Bundle id**: `com.ryan.aerosnap` (locked at scaffold per playbook
  §4 scaffold-time gate).
- **Folder naming**: `Aero-Snap/` (iOS) + `Aero-Snap_Mac_Win_app/`
  (desktop). Hyphenated, deliberately distinct from older
  space-separated patterns — see `memory/project_aero_decisions.md`.

## 5. Premium model

Defaults — to revisit before submission.

- iOS premium: 4 standard themes + alternate icons
- Desktop premium: 4 standard themes + unlimited favorites/collections
- Desktop freemium limits: 15 favorites, 10 collections
- Aero-specific Pro: live N-Number lookup, new-AD push for collection
  models, PDF cache for favorited ADs, quarterly auto-sync, iCloud
  collection sync, CSV export
- One-time price: TBD

## 6. Lemon Squeezy / IAP

- Desktop LS product: `Aero Snap Premium` (deferred — full block ~2026-06-30)
- iOS StoreKit product ID: `com.ryan.aerosnap.supporter`
- Pricing parity across platforms: yes

## 7. Per-platform deviations from the template

Domain extensions (per playbook §7 + §12 #2 — shell stays, workflow
surface allowed to grow):

- **5th tab `Aircraft`** — model catalog + TCDS lookup
- **6th tab `FAR`** — 14 CFR Parts 39/43/65/91/121/135/145/147 browser
- **Search modes**: Make/Model + AD number + ATA chapter + 14 CFR
  citation + full-text (5 modes vs the default 1)
- **Collections rebranded `Aircraft`** — N-Number as folder name with
  auto-matched AD list

Each will be logged in HANDOFF manager-block `Deviations` as the apps
scaffold.

## 8. What's explicitly NOT in v1

- iCloud sync (Pro-only on a future version)
- Multi-language UI (English only)
- Widgets / shortcuts
- N-Number direct lookup (Pro online feature only — registry is 60 MB
  daily-changing PII, won't bundle)
- AD original PDFs (linked, not bundled)
- Service Difficulty Reports
- Pre-1994 historical ADs
- ATA 100 chapter classification (ATA holds copyright on the
  hierarchy — we use FAA's free JASC numeric codes verbatim)

## 9. Build status (2026-05-30)

- ✅ Data pipeline scaffold (12 files in `data-pipeline/`)
- ✅ Schema (`schema.sql`) finalized
- ✅ FAR extraction working — 1,022 / 1,022 sections, all 8 parts
- ✅ AD PoC extraction working — 10 ADs from Federal Register API
- ✅ AD applicability matrix PoC — 36 rows, regex bank handles model
  list expansion (e.g. "Model 747-100, -100B, -200F" → 3 rows)
- ✅ build_db.py produces SQLite + FTS5 + meta
- ✅ Smoke-tested: "ADs applying to A330-301", "FTS body search for
  'corrosion'", "§ 43.13 lookup" all return correct results
- ⏸️ TCDS extraction (`extract_tcds.py` stub only)
- ⏸️ AC extraction (`extract_ac.py` stub only)
- ⏸️ Scale AD extraction from 10 → 23,000
- ⏸️ iOS Xcode project + Swift code
- ⏸️ Desktop Tauri project
