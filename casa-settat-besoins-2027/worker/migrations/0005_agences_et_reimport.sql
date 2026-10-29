-- Additive only: preserve existing agency lists, barcode records and reviews.
CREATE TABLE IF NOT EXISTS controle_agencies (
  agency_key TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);
--> statement-breakpoint
ALTER TABLE controle_codes ADD COLUMN reimport_count INTEGER NOT NULL DEFAULT 0;
