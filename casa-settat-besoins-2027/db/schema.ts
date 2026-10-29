import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";

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
