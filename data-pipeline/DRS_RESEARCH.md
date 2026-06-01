# DRS Scrape — Research Notes (Option A backlog)

**Status:** Deferred to v2 backlog (2026-06-01). See
`memory/project_aero_decisions.md` § "TCDS strategy" for why we chose
Option B (curation) over A for v1.

**Target:** Pull all ~3,000+ Type Certificate Data Sheets from FAA's
Dynamic Regulatory System into a parseable form for the SQLite
`type_certificates` table.

**Reward if solved:** complete TCDS coverage instead of curated 200.
For mechanics with uncommon aircraft (vintage warbirds, experimental
production-cleared types, rare foreign types like Pilatus / Diamond
variants) this is the difference between "found it" and "not in the
app, go to drs.faa.gov in a browser."

## What we know

**Surface:** `https://drs.faa.gov/browse/TCDSMODEL`

- Single-page Angular application — no server-rendered HTML for the
  TCDS list. A `<noscript>` block is the only meaningful payload in
  the initial response, and it just says JavaScript is required.
- The TCDS list is paginated client-side after a JSON fetch.

**Data API:** `https://drs.faa.gov/drs-api/*`

- All data requests go through this base.
  - Suspected endpoints (not confirmed because of auth): a list/search
    endpoint plus a per-document detail endpoint.
- Every request needs a session token in the header. Without it the
  server responds 403 with no further info.
- Token is acquired during the SPA's bootstrap handshake — a few
  XHRs fire in sequence during page load. One of them sets a session
  cookie / pulls back a bearer token. The Angular bundle has the
  exact flow but it's minified.
- Likely-relevant minified bundle: `chunk-FMUAZAE7.js` references
  `API_ENDPOINT` and contains the auth-token plumbing. Reverse
  engineering it is the unblocking workstream.

## What we haven't tried (next-experiment list)

1. **Playwright / Puppeteer headless scrape.** Drives the real
   browser, gets a real token, pages through the UI. Slow (~hours
   for 3k records) but technically straightforward and doesn't
   require any reverse engineering. Best fallback if API reverse
   engineering stalls.
2. **Network capture from a real session.** Open DevTools → Network
   tab → record the bootstrap → inspect the token-acquisition
   request and try replicating it with `requests`. This is the
   "1 hour, might work" path.
3. **EASA TCDS mirror cross-reference.** EASA publishes TCDS in PDF
   form with stable URLs and no auth. For aircraft also EASA-typed
   (most modern transports + a chunk of GA), we can pull EASA data
   first and only fall back to DRS for FAA-only types.
4. **Wikipedia infobox scrape.** Lower-quality but covers a long
   tail. Many Wikipedia pages cite the TCDS number explicitly. Use
   as a secondary signal when DRS is unreachable.

## Recommendation when this thaws

Start with #2 (network capture). If the token flow is a single
request, build a tiny `extract_tcds_drs.py` that:

1. Replays the bootstrap request to mint a session token.
2. Pages the list endpoint to enumerate TCDS numbers.
3. Hits the detail endpoint per TCDS, parses, writes JSONL to the
   same format `tcds_seed.jsonl` already uses.

Output should merge with (not replace) the curated seed — curated
entries can have a `_source: "curated"` field, scraped ones
`_source: "drs"`, and the build step preserves curator-edited
specifications when both sources see the same TCDS number.

If the token flow turns out to be multi-step or rotates per request,
fall back to #1 (Playwright). Slower but unblocked.

## Concrete pickup checklist

- [ ] Open `https://drs.faa.gov/browse/TCDSMODEL` in Chrome with
  DevTools recording.
- [ ] Identify which XHR sets the session token / cookie.
- [ ] Reproduce the token mint with `httpx` / `requests`.
- [ ] Try a list call (no auth, then with token, then with cookie).
- [ ] If list call works: figure out pagination params, write the
  enumerator.
- [ ] If list call doesn't work: spawn a Playwright session and
  capture the data via the rendered DOM.
