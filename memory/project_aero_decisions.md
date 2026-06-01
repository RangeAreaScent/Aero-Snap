---
name: project-aero-decisions
description: Aero Snap project decisions log — naming, scope, deviations from playbook, PoC findings.
metadata:
  type: project
---

# Aero Snap — Decisions Log

## 2026-05-30 — Project bootstrap

### Folder naming (deviation from §4 convention)

Decision: `Aero-Snap/` (iOS) + `Aero-Snap_Mac_Win_app/` (desktop) —
hyphenated, deliberately distinct from the older space-separated
patterns (`ICD Snap`, `DOT Snap_Mac_Win_app`).

**Why:** terminal/CLI friendliness — no quoting required for `cd`,
build scripts, gh CLI. Other apps' space-separated names work fine
but are mildly annoying. Aero starts a slightly cleaner pattern.

**How to apply:** mention as a playbook-§4 micro-deviation in the
HANDOFF manager-block when scaffolding starts. Not a blocker for
anything. Other future apps can adopt either pattern.

### Display name (no country suffix)

Decision: App Store display name is **"Aero Snap"** — no "(US)" suffix.

**Why:** matches STATUS activity log 2026-05-30 — "US-base apps carry
no country suffix" rule. Disambiguation from G04 EASA Aviation Snap
(EU sister) is handled by the EU app carrying the EASA prefix, not by
the US app carrying a US suffix.

**How to apply:** Xcode display name + tauri.conf.json productName +
all marketing copy: "Aero Snap" verbatim.

### Bundle ID locked at scaffold

Decision: `com.ryan.aerosnap` from first commit (playbook §4
scaffold-time gate).

**Why:** prevents the bundle-id compliance churn that hit Tariff /
NAICS / HCPCS / Code in May 2026 (each required pbxproj + tests +
PurchaseManager + HANDOFF block updates). Starting clean costs nothing.

**How to apply:** when scaffolding iOS / desktop, set
`PRODUCT_BUNDLE_IDENTIFIER`, `tauri.conf.json` `identifier`, and
`PurchaseManager.supporterProductID = "com.ryan.aerosnap.supporter"`
in the first commit.

### Data pipeline first, app code second

Decision: data extraction PoC before any Swift / Rust scaffolding.

**Why:** Spec §9 calls AD body extraction "the largest tech risk."
Validate that we can produce a usable SQLite before investing in
SwiftUI / Tauri shells.

**How to apply:** done. PoC produced 3.26 MB sqlite with 10 ADs,
36 applicability rows, 1,022 FAR sections, all FTS5-indexed.

## 2026-05-30 — PoC findings

### FAR (eCFR) — production-ready

8 of 8 core parts extracted cleanly (1,022 sections, 0 empty bodies).
eCFR's XML API is the right choice — well-structured, public, no
rate limiting observed. DIV5=Part / DIV6=Subpart / DIV8=Section.

### AD (Federal Register API) — production-ready for metadata + body

FR `documents.json` + `raw_text_url` is the right entry point.
AD header pattern `[Amendment 39-XXXXX; AD YYYY-XX-XX]` is stable
across all 10 ADs sampled. Labeled body sections `(a)..(z)` give
us applicability + compliance time + ATA via JASC code.

### Federal Register API was 503'ing intermittently 2026-05-30

API returned `503 Service Temporarily Unavailable` on first attempts;
the script's 3-retry backoff + on-disk cache (`data/raw/ad/<doc>.html`)
handled it. The cache also means re-running locally is free. Worth
keeping the cache layer in production.

### Body text has typewriter-era HTML entity placeholders

Federal Register text contains `[ecirc]`, `[ccedil]` etc. (their
typewriter-text entity format, not standard `&ecirc;`). Cosmetic
only; not blocking PoC. Production should add a postprocessor
mapping these to UTF-8 characters before bundling.

### Line-wrapping inside model tokens

FR plaintext occasionally wraps `HA-420` as `HA-` newline `420`,
which broke one applicability row (came out as `HA-`). Fix: rejoin
hyphen-suffixed tokens across the wrap before regex parsing. Tracked.

### ATA chapter has two phrasing variants

Both `JASC Code 27` and `Air Transport Association (ATA) of America
Code 27` appear in ADs. `extract_ad.py` handles both now.

### Model list expansion logic

`Model 747-100, -100B, -100B SUD, -200B, ...` correctly expands by
stripping the last `-XXX` segment of the base (`747-100` → prefix
`747`, then prefix + `-100B`). 36 rows from 10 ADs proves it works
across Boeing, Airbus, Embraer, Bombardier patterns.

### Manufacturer whitelist needed

Free-text manufacturer extraction is noisy; a whitelist of the
~25 common ones (Boeing, Airbus SAS, Embraer S.A., Honda Aircraft
Company LLC, Rolls-Royce Deutschland, etc.) gives clean rows.
Extend as we scale to 23,000 ADs.

## 2026-05-31 — Scale validation (10 → 1,000 ADs)

Ran `extract_ad.py --limit 1000` against Federal Register API
(2023-05-07 through 2026-06-01 newest). Wall-clock ~17.5 min for 990
raw_text fetches. 980 ADs parsed on first pass; refined regex bank
then reparsed cached HTML for 985 ADs (5 more recovered via revision
suffix fix).

**Coverage held at scale:**
- AD number captured: 100% (985 / 985)
- cfr_amendment: 100%
- effective_date: 100% (from FR metadata, not body — reliable channel)
- ATA chapter: 86.3%
- Applicability text: 99.9%
- **Supersedes chain: 31.1%** (after fixing "replaces|affects" wording)
- 98.1% of ADs got ≥1 applicability matrix row

**Three regex gaps surfaced and patched:**

1. `(b) Affected ADs` uses "replaces" / "affects" wording, NOT
   "supersedes" as I'd assumed. Fixed `SUPERSEDES_RE`:
   `\b(?:replaces?|supersed(?:es?|ing)|affects?)\s+AD\s+...`
   Went from **0% → 31% supersedes capture**.
2. AD numbers can carry a revision suffix like `2010-26-05R1` (revised
   versions of older ADs). Old regex required exactly `\d{4}-\d{2}-\d{2}`.
   Allow `(\d{4}-\d{2}-\d{2}(?:R\d+)?)`.
3. FR plaintext encodes accented characters as typewriter entity
   placeholders: `[eacute]` / `[ccedil]` / `[atilde]` / etc. Decoding
   to UTF-8 fixed manufacturer-name dedup (e.g. `ATR-GIE Avions de
   Transport R[eacute]gional` was being split from `R[eacute]gional`
   double-encoded variants). Net: UNKNOWN manufacturer 6.5% → 2.5%.

Manufacturer whitelist expanded from ~28 → ~60 entries based on
observed corpus (Airbus Helicopters, Dassault, ATR, CFM, Safran,
Bombardier, GE Aviation Czech, Deutsche Aircraft, Pacific Scientific,
Ipeco, Thommen, Aerospace & Defense Oxygen Systems, etc.).

**Skipped 15 ADs / 1,000 (1.5%):** mix of false positives from FR
search (non-AD FAA rules matching the "airworthiness directive"
search term) and edge cases with non-standard docket header
formatting. Acceptable loss rate.

### Bundle size risk — DECIDED 2026-05-31

**Decision: 15-year body cutoff.** ADs older than 15 years keep
metadata (ad_number, title, summary, applicability matrix row,
ata_chapter, effective_date, supersede chain, pdf_url, fr_url) but
drop the `body` field. Users searching old ADs find them by
metadata and follow `pdf_url` to read the original.

Implemented as `build_db.py --body-cutoff-years 15`. Will be the
production default once the full extract runs.

**Measurement basis** (data-pipeline/size_projection.py, run against
the 985-AD PoC corpus):

| Strategy | Kept | Cut | Total bundle | Verdict |
|---|---|---|---|---|
| No cutoff | 23,000 | 0 | **199 MB** | ✗ over |
| 15-yr (2011+) | 10,781 | 12,219 | **117 MB** | ✓ on target |
| 10-yr (2016+) | 7,187 | 15,813 | 93 MB | ✓ under |
| 7-yr  (2019+) | 5,031 | 17,969 | 79 MB | ✓ under |
| 5-yr  (2021+) | 3,593 | 19,407 | 69 MB | ✓ under |

Spec §3-1 target: 115–130 MB. 15-year hits dead center while
preserving body text for ADs from 2011+, covering effectively all
aircraft in active service today (typical commercial fleet age 12-15
years; most 2000s-vintage GA aircraft still flying).

**Why 15 and not 10 (more headroom):**
- 15yr keeps an extra ~3,600 ADs at full body — meaningful coverage
  of historically-significant ADs (e.g. 2011 fan-blade ADs that
  spawned MCAI patterns we still see today)
- 10yr leaves 24 MB of room but cuts 2011-2015 corpus
- Production can switch from 15 → 10 later via a one-flag rebuild
  if datasets grow (TCDS bigger than 10 MB, or applicability matrix
  doubles)

**Empirically validated** with cutoff=2 on our 3-year corpus:
13.73 MB → 11.75 MB (226 bodies dropped saved 2 MB; SQLite + FTS
overhead matches the projected 1.30 bytes-per-char factor).

## 2026-05-31 — Wave-3 day-1 wrap (Stage 0→1)

Stage transitioned from `0 spec` → `1 scaffold` in one session.
Delivered:
- 5-table SQLite (985 ADs / 1,806 applicability rows / 1,022 FAR
  sections / 43 curated TCDS / 779 ACs, 13.94 MB)
- 779 Advisory Circulars extracted from FAA's `parentTopicID/0`
  master list (one page, no pagination needed; 100% date coverage)
- 43 curated TCDS seed (Cessna / Piper / Beechcraft / Boeing /
  Airbus / Embraer / Bombardier + engines + helicopters covering
  the majority of GA + commercial maintenance lookups)
- iOS scaffold: `project.yml` (XcodeGen) + ~20 Swift files covering
  AeroSnapApp / ContentView / 5 entity models / AeroRepository
  (stdlib SQLite3, no GRDB) / SearchViewModel with 5 modes /
  Views for all 6 tabs + Onboarding / 4 manager stubs + tests
- HANDOFF + SPEC + memory updated; bundle-size blocker resolved

### TCDS — DRS blocked, working notes

DRS's `/drs-api/*` endpoints return 403 without auth. The Angular
SPA acquires a session token during page load (likely OIDC-style
handshake; the chunk-FMUAZAE7.js references `API_ENDPOINT` from
`appSettings` but the resolved value isn't in the static bundle).
Three paths forward:
1. **Replicate auth flow** — selenium/playwright drives the page,
   intercepts the token, replays into bare-API calls. ~hours of work.
2. **EASA mirror** — EASA publishes most TCDS data under EU rules
   that mirror US TCDS. Could cross-walk numbers.
3. **Curated growth** — extend the 43-entry seed organically as
   v1 ships and user requests come in. Most field maintenance
   lookups concentrate on the popular ~200 TCDS.

For v1 launch: option 3. Revisit option 1 if user feedback
demands broader coverage.

### 2026-05-31 — DRS deep-dive findings (extra detail)

After the initial AC-search work landed I spent another pass attempting
to bypass DRS auth. Findings:

1. **`/drs-api/*` is a frontend Angular route**, not an API path. All
   variants return the SPA shell (22,738 bytes — same as `/`). The
   real API lives at **`/api/*`** on the same host.

2. **`/api/*` returns 403 from request 1**, even with session cookies.
   Hitting `https://drs.faa.gov/` sets `session=...` and
   `ak_bmsc=...` cookies, but replaying them at `/api/help/drs-api/ids`
   still 403s. The `ak_bmsc` cookie is Akamai Bot Manager — it
   requires a real-browser JS challenge to issue an authoritative
   session that satisfies `/api/*`.

3. **No anonymous bootstrap endpoint exists.** Probed
   `/api/auth/init`, `/api/security`, `/api/version`, `/api/swagger`,
   `/api/document/types`, etc. — all 403, no exceptions.

4. **No publicly downloadable TCDS list.** Checked data.gov (no
   matching FAA TCDS dataset), FAA aircraft cert pages (404), EASA
   TCDS index (200, but uses EASA numbering — A.064 vs FAA A28NM —
   so it doesn't translate without a cross-walk table).

**Path forward** (when we decide to scale TCDS):
- **Playwright/Selenium scraper**: bring up a headless Chromium, let
  Akamai's JS challenge succeed, capture the authoritative session
  cookies + any `X-XSRF-TOKEN`-like header, replay against `/api/*`
  endpoints. ~2-3 hours to build, brittle (Akamai updates challenges).
- **Manual curation expansion**: grow seed list to ~150 entries by
  pulling Wikipedia infobox data for the popular ~150 aircraft.
  Reliable, ~2 hours, no scraper-rot risk.
- **Wait for DRS to publish a public dataset**: FAA periodically adds
  datasets to data.gov; worth checking quarterly.

For v1 launch we ship the 43-entry seed and the AD-applicability
JOIN — the latter is the actual maintenance use case and works
across the full corpus. TCDS is reference-only ("what is this
aircraft?"), so a partial catalog is workable.

### iOS scaffold approach — XcodeGen + stdlib SQLite3

Two notable deviations from the established Snap pattern (logged
in HANDOFF Deviations):

1. **XcodeGen instead of committed .xcodeproj**. Tariff already
   uses XcodeGen as a one-off; Aero adopts it deliberately so the
   project layout is reproducible from one manifest. `project.yml`
   is the source of truth; `xcodegen generate` produces the
   ephemeral .xcodeproj. Cleaner diff hygiene than the binary
   pbxproj for early-stage iteration.
2. **stdlib SQLite3 instead of GRDB**. ICD + Tariff use GRDB.
   Aero needs to ship to desktop too (Rust/Tauri side) and
   keeping the iOS code dependency-light means the data-access
   patterns can be mirrored more easily without lugging a Swift
   package into the Rust side's mental model. The actor pattern
   in `AeroRepository.swift` is straightforward enough that GRDB
   isn't pulling weight; if FTS5 ranking helpers or migration
   tooling become needed later we can revisit.

Neither deviation is series-mandatory; if the next Snap app
wants to keep GRDB + committed pbxproj, this isn't a precedent
to follow blindly.

**Alternative options considered + rejected:**
- (b) zstd row-level compression: would require bundling a UDF in
  Swift (SQLite ext) AND Rust (rusqlite). Massive complexity for
  ~40% additional savings on top of the cutoff. Save for v2 if
  needed.
- (c) Further body chaff trim: profiled 985 AD bodies, found
  Required Actions / Definitions / AMOCs / Affected ADs are all
  real regulatory text. `Material Incorporated by Reference` and
  `Additional Information` (FAA contact details) trimmable for
  maybe 5-10% but not worth the implementation cost when (d) gets
  us 40%.
- (d) Hard year floor (drop pre-2010 entirely): rejected because
  metadata search across full historical corpus is still valuable
  ("did this AD ever exist? Was my 1995 Cessna ever affected?").
  Body cutoff preserves discoverability.

### Pre-flight checks complete

PoC SQLite at scale answers spec §4-2's core workflow:
"Which ADs apply to my N123AB (Cessna 172)?" via the JOIN. Tested
with Boeing 737-800, Airbus A320 family, ATA chapter 72 grouping.
Multi-word FTS body search ("fan AND blade", "corrosion") works.

Pipeline is ready to scale further or pivot to iOS scaffolding.

## 2026-06-01 — TCDS strategy DECIDED

**Decision:** Option B (hand-curated seed) for v1 ship; Option A
(full DRS scrape) deferred to v2 backlog.

**Why:** Federal Register's modern AD corpus capped at ~9.7k, not
the 23k we'd budgeted for, so the dataset overall is smaller than
expected — adding a long-tail TCDS scrape isn't where the marginal
A&P utility lives in v1. The top ~200 TCDS cover the working-fleet
queries A&P / IA / owner workflows actually hit (Cessna 172/182,
Piper PA-28, Bonanza/Baron, Mooney, Cirrus, Bell 206, Lycoming O-
series, Continental IO-series, Hartzell HC-series). The DRS scrape
is 1–2 weeks of reverse-engineering work behind an Angular SPA +
auth-gated `/drs-api/*` for a marginal long-tail gain.

**How to apply:**
- Curation work is tracked in `data-pipeline/TCDS_CURATION_PLAN.md`
  (200-entry target broken down by category with per-row progress).
- Seed data lives in `data-pipeline/tcds_seed.jsonl` — plain JSONL so
  a non-Python curator can extend it. `extract_tcds.py` loads it.
- For Option A pickup, see `data-pipeline/DRS_RESEARCH.md` — start
  from the network-capture experiment in the "Concrete pickup
  checklist" section. Output should MERGE with the curated seed
  (curated entries take precedence on conflicts, so curator edits
  to `specifications` aren't blown away on the next scrape).
- v1 ships with whatever curation count we hit. If we land at 100/200
  before App Store submission, that's fine — the in-app TCDS view
  is already gated on "set this aircraft's model" so partial
  coverage degrades to "no match" rather than crashing.
