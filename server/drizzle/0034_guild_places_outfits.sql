ALTER TABLE "avatars" ADD COLUMN "outfits" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "avatars" ADD COLUMN "spent" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "walls_changed" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "walls_before" jsonb;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "plots_changed" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "plots_before" jsonb;--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "walls" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "plots" jsonb DEFAULT '{}'::jsonb NOT NULL;