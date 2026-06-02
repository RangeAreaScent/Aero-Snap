# Aero Snap iOS — Handoff

<!-- snap-series:manager-block:start -->
- **App:** Aero Snap
- **Platform:** iOS
- **Wave:** 3
- **Stage:** 1 scaffold
- **Last updated:** 2026-05-31
- **Repo:** github.com/RangeAreaScent/Aero-Snap (public, switch to private at release stabilization)
- **Latest release:** none
- **Latest CI:** n/a (no CI)
- **Bundle id:** com.ryan.aerosnap (locked at scaffold per §4)
- **Dataset:** FAA AD + 14 CFR + TCDS + AC, ~115–130 MB target at full 23k scale. **PoC SQLite 13.94 MB** bundled in app (985 ADs + 1,022 FAR sections + 1,806 applicability rows + 43 TCDS seed + 779 ACs) built 2026-05-31, license: public domain. Production build will be `build_db.py --body-cutoff-years 15`
- **Deviations from playbook:**
  - Folder naming hyphenated (`Aero-Snap/` not `Aero Snap/`) for CLI friendliness — see [[project-aero-decisions]]
  - 5th tab `Aircraft` (TCDS + N-Number) + 6th tab `FAR` (14 CFR browser) — per spec §5, justified by maintenance workflow priority
  - 5 search modes (AD#, Make/Model, ATA chapter, 14 CFR citation, full-text) vs default 1
  - Collections rebranded `My Aircraft` (N-Number-keyed folders) per spec §4-3
  - No GRDB dependency — uses stdlib SQLite3 (ICD/Tariff use GRDB, Aero deliberately keeps iOS+desktop ports dependency-symmetric)
  - XcodeGen-managed project (`project.yml`), generated via `xcodegen generate`
- **Active blockers:**
  - PurchaseManager stubbed — StoreKit product registration + receipt validation pending (deferred ~2026-06-30 with signing/store block)
  - TCDS at 43/200 curated (decision 2026-06-01: ship v1 with Option B per [[project-aero-decisions]] §"TCDS strategy"). Curation plan + workflow in `data-pipeline/TCDS_CURATION_PLAN.md`; full DRS scrape (Option A) deferred — research notes in `data-pipeline/DRS_RESEARCH.md`
  - Apple Developer cert (series-wide, deferred ~2026-06-30)
- **Resolved blockers:**
  - ✅ **Bundle size risk** — decided 2026-05-31: 15-year body cutoff projects to 117 MB at full 23k scale, dead center of spec §3-1 target 115–130 MB. Implementation: `build_db.py --body-cutoff-years 15`. Rationale + measurement in [[project-aero-decisions]] §"Bundle size risk — DECIDED"
  - ✅ **Theme system** — done 2026-06-01: 7 themes (system/light/dark + 4 premium) ported from ICDSnap with full palettes, ThemeManager + ThemedListModifier wired into all views, PremiumUnlockSheet shown when locked theme tapped
  - ✅ **Onboarding polish** — done 2026-06-01: ScrollView + GeometryReader for small-screen safety, hero icon swap (UIImage.appIcon when installed → airplane SF fallback), 4 circle-bg feature rows, audience-targeted footer
- **Next 3 steps:**
  1. `xcodegen generate` → open in Xcode 16 → build for iPhone 17 simulator → smoke-test 5 search modes against the bundled 985-AD SQLite
  2. Port the shared shell from ICD Snap iOS: full ThemeManager + COLORWAYS hex + 7 themes + SettingsView complete + Onboarding polish (playbook §5 ADAPTATION_GUIDE steps 3 + 8)
  3. Tackle TCDS full scrape (reverse-engineer DRS auth) OR commit to growing the curated seed list to ~200 entries for v1
- **Report-back trigger:** any commit on main, any tag push, any new blocker, any SPEC change, any data-pipeline milestone, first successful Xcode build
<!-- snap-series:manager-block:end -->

## Overview

Aero Snap is the iOS side of the FAA Airworthiness Directives + 14 CFR
+ TCDS reference. See `SPEC.md` at this project root for the as-built
domain spec.

The desktop sibling lives at `../Aero-Snap_Mac_Win_app/` (currently
empty — desktop scaffold scheduled after data pipeline is at full
scale).

## How to build (next session)

```bash
brew install xcodegen           # if not already installed
cd "Aero-Snap/"
xcodegen generate               # produces AeroSnap.xcodeproj
open AeroSnap.xcodeproj         # Xcode 16+
# Set scheme destination to iPhone 17 simulator (Cmd-Shift-,)
# Run (Cmd-R) — should launch with onboarding then 6 tabs
```

Bundled SQLite is at `AeroSnap/Resources/aero_snap_v1.sqlite` (86 MB,
**dataset_version=v1** as of 2026-06-01, **9,408 unique ADs** (deduped
from 9,691 jsonl rows — Federal Register API returned 271 dup AD
numbers; build_db.py now logs the drop) + 9,814 applicability rows +
1,022 FAR + 63 TCDS + 779 AC, 4,007 ADs with body dropped by the
15-yr cutoff (some of those drops were on dup rows that were
themselves discarded, so ~5,567 ADs ship with body text in the
end). Gitignored — regenerate locally via the data pipeline.
Federal Register's modern AD corpus capped out at ~9.4k unique
records (not 23k as originally feared), so this *is* the full
ship-scale corpus. Query timing on the bundled SQLite is excellent:
AD#/ATA/FTS lookups <0.1 ms median, Make/Model JOIN ~8 ms median.
Rebuild with:

```bash
cd data-pipeline
python3 extract_ad.py --limit 23000 --out data/ad_full.jsonl
python3 build_ad_applicability.py --ad data/ad_full.jsonl --out data/ad_appl_full.jsonl
python3 build_db.py --body-cutoff-years 15 --dataset-version v1 \
    -o data/aero_snap_v1.sqlite \
    --ad data/ad_full23k.jsonl --far data/far_2026-05-30.jsonl \
    --tcds data/tcds_2026-05-31.jsonl --ac data/ac_2026-05-31.jsonl \
    --applicability data/ad_applicability_full23k.jsonl
cp data/aero_snap_v1.sqlite ../AeroSnap/Resources/
```

## What's built (2026-05-31)

- `data-pipeline/` — Python pipeline producing the bundled SQLite
  - `schema.sql` — SPEC §3 verbatim + FTS5 (ad/far/tcds) + indexes
  - `extract_far.py` — eCFR XML API → JSONL. **1,022 sections shipped.**
  - `extract_ad.py` — Federal Register API → JSONL. **1,000 ADs at scale (985 parsed, 98.5%).**
  - `build_ad_applicability.py` — regex parser, ~60-entry manufacturer
    whitelist, model-list expansion. **1,806 rows from 985 ADs, 2.5% UNKNOWN.**
  - `build_db.py` — JSONL → SQLite + FTS5 + meta table
  - `analyze_extraction.py` — coverage / quality reporter
  - `extract_tcds.py`, `extract_ac.py` — stub only
  - Cache layer: `data/raw/` for FR + eCFR responses (re-runs are free)

PoC SQLite at `data-pipeline/data/aero_snap_v1.sqlite` (13.73 MB,
985 ADs + 1,806 applicability rows + 1,022 FAR sections).
Smoke-tested with 7 real queries:
- "ADs applying to Boeing 737-800" → 8 hits, date-sorted, with ATA chapter
- AD supersede chain (2026-10-06 → supersedes 2020-24-08) — works
- FTS5 multi-word: `corrosion`, `fan AND blade` — both work
- ATA chapter 72 grouped by manufacturer/model → engines correctly inventoried
- § 91.417 (maintenance records) citation lookup → returns clean body
- Date-range + manufacturer-family filter (A320 family since 2026-05) — works

## Decisions log

See `memory/project_aero_decisions.md`.

## iOS scaffold (Stage 0 → 1, 2026-05-31)

- `project.yml` — XcodeGen manifest, bundle id `com.ryan.aerosnap`
  locked, iOS 26.5 deployment target, Swift 6.0
- `AeroSnap/AeroSnapApp.swift` — entry point with SwiftData container
  (FavoriteAD / AircraftCollection / AircraftCollectionItem / ADNote)
- `AeroSnap/ContentView.swift` — 6-tab structure
  (Search / **Aircraft** / **FAR** / Favorites / **My Aircraft** /
  Settings), domain extensions per spec §5
- `AeroSnap/Data/Models/AeroEntities.swift` — 5 domain types
  (ADSummary, ADDetail, ADApplicability, FARSection, TCDSummary, ACEntry)
- `AeroSnap/Data/Repository/AeroRepository.swift` — actor wrapping
  stdlib SQLite3, 5 search modes + detail loaders + cross-table
  applicability JOIN
- `AeroSnap/ViewModels/SearchViewModel.swift` — 5 search modes per
  spec §4-1, debounced query, heterogeneous SearchHit (AD/FAR)
- `AeroSnap/Views/`
  - `Search/{SearchView, ADRow, ADDetailView}.swift` — segmented mode
    picker, AD detail with applicability matrix display, body-dropped
    notice for 15-yr cutoff cases, FAR detail with copy-citation toolbar
  - `Aircraft/AircraftView.swift` — TCDS catalog + category filter +
    "ADs for this aircraft" cross-link (spec §4-2 workflow)
  - `FAR/FARView.swift` — 8-part 14 CFR browser with friendly labels
  - `Favorites/FavoritesView.swift` — backed by SwiftData FavoriteAD
  - `Collections/AircraftCollectionsView.swift` — N-Number-keyed
    folders with auto-matched ADs (spec §4-3)
  - `Settings/SettingsView.swift` — data version display + premium row
  - `Onboarding/OnboardingView.swift`
- `AeroSnap/Managers/` — FavoriteManager, AircraftCollectionManager,
  ThemeManager (stub), PurchaseManager (stub, supporterProductID
  `com.ryan.aerosnap.supporter` locked)
- `AeroSnap/Extensions/Haptics.swift`
- `AeroSnap/Resources/aero_snap_v1.sqlite` — bundled
- `AeroSnap/Assets.xcassets` — AppIcon + AccentColor placeholders
- `AeroSnapTests/AeroSnapTests.swift` — 4 smoke tests using
  Swift Testing (`@Test`, `@Suite`), targets iPhone 17 simulator

## What's NOT built yet (next 1-2 sessions)

<!-- App icon: shipped 2026-06-01 (primary 1024×1024 capsule-airplane on system blue + 4 alternates per premium theme — SkyBlue/PeachPink/DeepCharcoal/Blueberry — all generated by tools/make_app_icon.py with parallel preview imagesets for the in-app picker. AppIconManager handles UIApplication.setAlternateIconName wiring, picker UI at Settings → Appearance → App Icon.) -->
- Full PurchaseManager StoreKit integration (App Store Connect product
  registration deferred ~2026-06-30 with signing/store block)
<!-- SwiftData VersionedSchema: shipped 2026-06-01 (AeroSnapSchemaV1 + AeroSnapMigrationPlan in Data/SwiftData/SchemaMigration.swift; wipe fallback replaced with fatalError so migration bugs can't slip past testflight) -->
<!-- PDF + CSV export: shipped 2026-06-01 (Exporter.swift, ShareLink menu in Favorites + Folder collection detail) -->
<!-- Privacy Policy: shipped 2026-06-01 (PRIVACY.md in repo + index.html pushed to Snap_Series/aerosnap/privacy/ → rangeareascent.github.io/Snap_Series/aerosnap/privacy/) -->
<!-- ADNote UI: shipped 2026-06-01 (ADNoteManager + NoteEditorSheet + yellow note card in ADDetailView) -->
<!-- TCDS strategy: decided 2026-06-01 (Option B — 200-entry curation in tcds_seed.jsonl, see TCDS_CURATION_PLAN.md). Full corpus = v2 backlog (DRS_RESEARCH.md). -->
- AD body for older ADs in the 15-yr cutoff zone — full extract pending
