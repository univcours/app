-- Additive migration: named consultations, while preserving existing aggregate counters.
CREATE TABLE IF NOT EXISTS controle_access_log (
  id TEXT PRIMARY KEY NOT NULL,
  module TEXT NOT NULL,
  agency TEXT NOT NULL,
  agency_key TEXT NOT NULL,
  agent_name TEXT NOT NULL,
  session_hash TEXT NOT NULL,
  viewed_at TEXT NOT NULL,
  code_count INTEGER NOT NULL DEFAULT 0
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS controle_access_log_module_agency_date ON controle_access_log (module,agency_key,viewed_at);
--> statement-breakpoint
ALTER TABLE controle_codes ADD COLUMN last_reviewer_name TEXT;
