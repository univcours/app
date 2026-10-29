-- Additive migration: one login may have access to several official agencies.
-- Existing agency credentials are copied without altering their hashes or historical data.
CREATE TABLE IF NOT EXISTS controle_auth_users (
  username_key TEXT PRIMARY KEY NOT NULL,
  username TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  password_iterations INTEGER NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  credential_version INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS controle_auth_agencies (
  agency_key TEXT PRIMARY KEY NOT NULL,
  agency TEXT NOT NULL,
  username_key TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);
--> statement-breakpoint
CREATE INDEX IF NOT EXISTS controle_auth_agencies_user ON controle_auth_agencies (username_key,active);
--> statement-breakpoint
INSERT OR IGNORE INTO controle_auth_users (username_key,username,password_hash,salt,password_iterations,active,credential_version,updated_at)
 SELECT username_key,username,password_hash,salt,password_iterations,active,credential_version,updated_at FROM controle_agency_accounts;
--> statement-breakpoint
INSERT OR IGNORE INTO controle_auth_agencies (agency_key,agency,username_key,active,updated_at)
 SELECT agency_key,agency,username_key,active,updated_at FROM controle_agency_accounts;
--> statement-breakpoint
ALTER TABLE controle_access_log ADD COLUMN login_username TEXT;
