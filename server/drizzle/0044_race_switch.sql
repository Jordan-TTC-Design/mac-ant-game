ALTER TABLE "world_players" ADD COLUMN "race_switched_at" timestamp (3) with time zone;--> statement-breakpoint
ALTER TABLE "world_players" ADD COLUMN "race_switches" integer DEFAULT 0 NOT NULL;