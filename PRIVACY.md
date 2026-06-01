# Privacy Policy — Aero Snap

_Last updated: 2026-06-01_

Aero Snap is designed to be **fully offline and tracking-free**. This page exists because the App Store and the Apple Developer guidelines require every app to publish a privacy policy, even one as minimal as this.

## TL;DR

- Aero Snap **does not collect, transmit, or store any personal information** on any server.
- Aero Snap **does not use analytics, advertising, tracking, or third-party SDKs** of any kind.
- Aero Snap **does not require an account** and never asks for one.
- All your data — favorites, aircraft collections, notes — stays on your device.

## What runs on your device

The app uses local storage on your device for:

| Stored | Purpose | Where |
|---|---|---|
| **Favorited ADs** | Quick access to Airworthiness Directives you mark with a star | SwiftData |
| **My Aircraft (collections)** | Per-tail-number folders that auto-match applicable ADs | SwiftData |
| **Per-AD notes** | Your free-text annotations on a given AD | SwiftData |
| **Per-aircraft compliance status** | Optional checkmark + date on each AD in a folder, plus free-text shop notes | SwiftData |
| **App preferences** | Theme, copy format, Bluebook citation style, haptic toggle | `UserDefaults` |

This data is **never** sent off the device. There is no sync, no cloud backup managed by the app, and no telemetry.

## What does NOT happen

- ❌ No analytics framework (no Google Analytics, no Mixpanel, no Firebase, no App Analytics opt-ins, no Plausible, nothing)
- ❌ No advertising SDKs
- ❌ No tracking identifiers (IDFA, ad ID, etc.) requested or used
- ❌ No crash-reporting SDK that uploads data (we rely on Apple's anonymous opt-in crash reports only, which Apple — not us — manages)
- ❌ No remote configuration, A/B testing, or feature flags
- ❌ No third-party fonts, web requests, or content-delivery calls
- ❌ No network access requested outside of the optional in-app purchase flow (Apple StoreKit) and the user-initiated "Open on Federal Register" / "Official PDF" / DRS TCDS links — those open in Safari and are governed by Safari's privacy settings, not ours

## In-app purchase (optional supporter unlock)

If you choose to support the app with the optional one-time purchase ("Buy me a coffee" / Supporter), iOS uses Apple StoreKit. Apple receives the standard purchase transaction; we receive only a confirmation that the purchase happened. We never see your Apple ID, payment method, or billing address.

The purchase is entirely optional. The core app — search, favorites, aircraft collections, notes, 14 CFR browser, TCDS catalog, PDF/CSV export — is fully free with no time limits or feature locks. The only thing the purchase unlocks is the premium theme set.

## Data you export

The PDF and CSV export features write files to your device's temp directory and hand them to the system share sheet. From there, **you** decide who sees the file (Mail, AirDrop, your filesystem, your shop's fleet-management software). Aero Snap does not upload exports anywhere.

## Bundled dataset attribution

Aero Snap bundles a snapshot of the following US federal aviation data for offline lookup:

- **FAA Airworthiness Directives** — extracted from the Federal Register API
- **14 CFR (Federal Aviation Regulations)** — extracted from the eCFR XML API
- **Type Certificate Data Sheets** (curated subset) — extracted from FAA TCDS PDFs
- **Advisory Circulars** — index of FAA AC documents

All four datasets are works of the United States Federal Government and are in the **public domain** under 17 U.S.C. § 105. No license restrictions apply to their inclusion in this app. The "Open on Federal Register" and "Official PDF" links inside the app point at the authoritative federal source for each document; the bundled snapshot is provided for fast offline lookup, not as a substitute for the controlled document.

## Children's privacy

Aero Snap is designed for A&P mechanics, IAs, aircraft owners, and aviation maintenance professionals. It is not directed at children under 13 and does not knowingly collect any information from children.

## Changes to this policy

If this policy is ever updated, the "Last updated" date at the top of this page will change. Because the app collects nothing, material changes are extremely unlikely.

## Contact

Questions or concerns: **dui0828@gmail.com**

---

_This policy is intentionally short because the app does very little that's privacy-relevant. If you have any questions about what specifically the app does or doesn't do on your device, you can inspect the source code at https://github.com/RangeAreaScent/Aero-Snap or open an issue there._
