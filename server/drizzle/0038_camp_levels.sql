ALTER TABLE "camps" ADD COLUMN "bosses_beaten" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "celebrated_level" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "camps" ADD COLUMN "visitors" jsonb DEFAULT '{}'::jsonb NOT NULL;