ALTER TABLE "notes" ADD COLUMN "kind" text DEFAULT 'todo' NOT NULL;--> statement-breakpoint
ALTER TABLE "notes" ADD COLUMN "desk" boolean DEFAULT true NOT NULL;