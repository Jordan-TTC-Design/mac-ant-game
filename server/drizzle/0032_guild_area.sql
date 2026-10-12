ALTER TABLE "guild_decor_log" ADD COLUMN "area_changed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "area_before" jsonb;--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "area" jsonb;