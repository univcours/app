import { integer, primaryKey, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

export const submissions = sqliteTable("submissions", {
  id: text("id").primaryKey(),
  agency: text("agency").notNull(),
  agencyKey: text("agency_key").notNull(),
  sessionHash: text("session_hash").notNull(),
  payload: text("payload").notNull(),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
}, (table) => [uniqueIndex("submissions_agency_unique").on(table.agencyKey)]);

export const loginAttempts = sqliteTable("login_attempts", {
  key: text("key").primaryKey(),
  attempts: integer("attempts").notNull(),
  expiresAt: integer("expires_at").notNull(),
});

export const countSubmissions = sqliteTable("count_submissions", {
  id: text("id").primaryKey(),
  agency: text("agency").notNull(),
  agencyKey: text("agency_key").notNull(),
  month: text("month").notNull(),
  sessionHash: text("session_hash").notNull(),
  payload: text("payload").notNull(),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
}, (table) => [uniqueIndex("count_agency_month_unique").on(table.agencyKey, table.month)]);

export const controleCodes = sqliteTable("controle_codes", {
  id: text("id").primaryKey(),
  module: text("module").notNull(),
  agency: text("agency").notNull(),
  agencyKey: text("agency_key").notNull(),
  barcode: text("barcode").notNull(),
  status: text("status").notNull().default("EN_ATTENTE"),
  observation: text("observation").notNull().default(""),
  active: integer("active").notNull().default(1),
  fileName: text("file_name").notNull().default(""),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
  reviewedAt: text("reviewed_at"),
  reviewerSession: text("reviewer_session"),
  reimportCount: integer("reimport_count").notNull().default(0),
}, (table) => [
  uniqueIndex("controle_module_agency_barcode").on(table.module, table.agencyKey, table.barcode),
]);

export const controleAcces = sqliteTable("controle_acces", {
  module: text("module").notNull(),
  agency: text("agency").notNull(),
  agencyKey: text("agency_key").notNull(),
  firstAccessAt: text("first_access_at").notNull(),
  lastAccessAt: text("last_access_at").notNull(),
  accessCount: integer("access_count").notNull().default(1),
}, (table) => [primaryKey({columns:[table.module, table.agencyKey]})]);

export const controleAgencyAliases = sqliteTable("controle_agency_aliases", {
  aliasKey: text("alias_key").primaryKey(),
  agency: text("agency").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const controleAgencies = sqliteTable("controle_agencies", {
  agencyKey: text("agency_key").primaryKey(),
  name: text("name").notNull(),
  createdAt: text("created_at").notNull(),
});
