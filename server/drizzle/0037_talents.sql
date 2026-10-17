ALTER TABLE "world_players" ADD COLUMN "talents" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "world_players" ADD COLUMN "talent_resets" integer DEFAULT 0 NOT NULL;