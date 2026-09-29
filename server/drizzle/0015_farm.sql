ALTER TABLE "camps" ADD COLUMN "farm_level" integer DEFAULT 1 NOT NULL;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "farm_upgrade_until" timestamp (3) with time zone;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "produced_to" timestamp (3) with time zone DEFAULT now() NOT NULL;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "production_carry" jsonb DEFAULT '{}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "world_players" DROP COLUMN "baked_to";