CREATE TABLE IF NOT EXISTS controle_acces (
  module TEXT NOT NULL,
  agency TEXT NOT NULL,
  agency_key TEXT NOT NULL,
  first_access_at TEXT NOT NULL,
  last_access_at TEXT NOT NULL,
  access_count INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (module, agency_key)
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS controle_acces_module_last ON controle_acces (module, last_access_at);
