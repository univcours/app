-- Additive migration: independent agency credentials and platform maintenance switch.
-- No existing submissions, barcode outcomes or agency mappings are modified.
CREATE TABLE IF NOT EXISTS controle_agency_accounts (
  agency_key TEXT PRIMARY KEY NOT NULL,
  agency TEXT NOT NULL,
  username TEXT NOT NULL,
  username_key TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  password_iterations INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  credential_version INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS controle_agency_accounts_login ON controle_agency_accounts (username_key);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS controle_site_state (
  id INTEGER PRIMARY KEY NOT NULL CHECK (id=1),
  is_open INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
--> statement-breakpoint
INSERT OR IGNORE INTO controle_site_state (id,is_open,updated_at) VALUES (1,1,'2026-10-29T00:00:00.000Z');
