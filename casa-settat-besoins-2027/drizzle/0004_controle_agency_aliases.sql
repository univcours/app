CREATE TABLE IF NOT EXISTS controle_agency_aliases (
  alias_key TEXT PRIMARY KEY NOT NULL,
  agency TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS controle_agency_aliases_agency_idx ON controle_agency_aliases (agency);
