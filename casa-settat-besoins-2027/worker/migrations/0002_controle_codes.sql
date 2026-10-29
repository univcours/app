CREATE TABLE IF NOT EXISTS controle_codes (
  id TEXT PRIMARY KEY NOT NULL,
  module TEXT NOT NULL,
  agency TEXT NOT NULL,
  agency_key TEXT NOT NULL,
  barcode TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'EN_ATTENTE',
  observation TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  file_name TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  reviewed_at TEXT,
  reviewer_session TEXT
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS controle_module_agency_barcode ON controle_codes (module, agency_key, barcode);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS controle_module_agency_active ON controle_codes (module, agency_key, active);
