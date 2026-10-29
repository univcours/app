CREATE TABLE `count_submissions` (
	`id` text PRIMARY KEY NOT NULL,
	`agency` text NOT NULL,
	`agency_key` text NOT NULL,
	`month` text NOT NULL,
	`session_hash` text NOT NULL,
	`payload` text NOT NULL,
	`created_at` text NOT NULL,
	`updated_at` text NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `count_agency_month_unique` ON `count_submissions` (`agency_key`,`month`);