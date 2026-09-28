ALTER TABLE "camps" ADD COLUMN "sanctuary_since" timestamp (3) with time zone;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "sanctuary_off_at" timestamp (3) with time zone;--> statement-breakpoint
ALTER TABLE "expeditions" ADD COLUMN "boosts" jsonb;--> statement-breakpoint
ALTER TABLE "world_cells" ADD COLUMN "lair_wounds" jsonb;--> statement-breakpoint
ALTER TABLE "world_players" ADD COLUMN "baked_to" timestamp (3) with time zone;