-- Aero Snap — bundled SQLite schema.
-- Mirrors 11_Aero_Snap_Spec.md §3 verbatim. build_db.py applies this.

PRAGMA journal_mode = OFF;
PRAGMA synchronous  = OFF;
PRAGMA temp_store   = MEMORY;
PRAGMA page_size    = 4096;

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Airworthiness Directives
CREATE TABLE IF NOT EXISTS airworthiness_directives (
    ad_number           TEXT PRIMARY KEY,    -- "2024-17-05"
    ad_year             INTEGER NOT NULL,
    title               TEXT NOT NULL,
    effective_date      TEXT NOT NULL,       -- ISO 8601
    federal_register_id TEXT,
    cfr_amendment       TEXT,                -- "39-22456"
    summary             TEXT NOT NULL,
    body                TEXT NOT NULL,
    compliance_time     TEXT,
    is_emergency        INTEGER DEFAULT 0,   -- EAD flag
    supersedes          TEXT,
    superseded_by       TEXT,
    ata_chapter         TEXT,                -- "32" landing gear etc.
    pdf_url             TEXT,
    fr_url              TEXT
);

-- Type Certificate Data Sheets
CREATE TABLE IF NOT EXISTS type_certificates (
    tcds_number         TEXT PRIMARY KEY,    -- "3A12", "E-25"
    category            TEXT,                -- Aircraft / Engine / Propeller
    manufacturer        TEXT NOT NULL,
    models              TEXT NOT NULL,       -- CSV
    issue_date          TEXT,
    last_revision       TEXT,
    specifications      TEXT,                -- JSON blob
    pdf_url             TEXT
);

-- AD ↔ Model applicability (★ proprietary value-add)
CREATE TABLE IF NOT EXISTS ad_applicability (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    ad_number           TEXT NOT NULL,
    manufacturer        TEXT NOT NULL,
    model               TEXT NOT NULL,
    model_series        TEXT,
    serial_range_start  TEXT,
    serial_range_end    TEXT,
    part_type           TEXT,                -- Airframe / Engine / Propeller / Appliance
    notes               TEXT,
    FOREIGN KEY(ad_number) REFERENCES airworthiness_directives(ad_number)
);
CREATE INDEX IF NOT EXISTS idx_applicability_model
    ON ad_applicability(manufacturer, model);
CREATE INDEX IF NOT EXISTS idx_applicability_ad
    ON ad_applicability(ad_number);

-- 14 CFR (FAR) sections
CREATE TABLE IF NOT EXISTS far_sections (
    id              TEXT PRIMARY KEY,        -- "14-cfr-43.13"
    part_number     TEXT NOT NULL,           -- "43"
    section_number  TEXT NOT NULL,           -- "43.13"
    subpart         TEXT,
    heading         TEXT NOT NULL,
    body            TEXT NOT NULL,
    citation        TEXT NOT NULL,           -- "14 CFR § 43.13"
    last_amended    TEXT
);
CREATE INDEX IF NOT EXISTS idx_far_part ON far_sections(part_number);
CREATE INDEX IF NOT EXISTS idx_ad_ata ON airworthiness_directives(ata_chapter);
CREATE INDEX IF NOT EXISTS idx_ad_effective ON airworthiness_directives(effective_date DESC);

-- Advisory Circulars (metadata only)
CREATE TABLE IF NOT EXISTS advisory_circulars (
    ac_number       TEXT PRIMARY KEY,        -- "AC 43.13-1B"
    title           TEXT NOT NULL,
    issue_date      TEXT,
    related_far     TEXT,
    pdf_url         TEXT NOT NULL
);

-- FTS5 search
CREATE VIRTUAL TABLE IF NOT EXISTS ad_fts USING fts5(
    ad_number, title, summary, body, ata_chapter,
    content='airworthiness_directives', content_rowid='rowid',
    tokenize='porter'
);

CREATE VIRTUAL TABLE IF NOT EXISTS far_fts USING fts5(
    id, citation, heading, body,
    content='far_sections', content_rowid='rowid',
    tokenize='porter'
);

CREATE VIRTUAL TABLE IF NOT EXISTS tcds_fts USING fts5(
    tcds_number, manufacturer, models,
    content='type_certificates', content_rowid='rowid',
    tokenize='porter'
);
