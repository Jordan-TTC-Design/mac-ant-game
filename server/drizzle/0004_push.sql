ALTER TABLE "notes" ADD COLUMN "pushed_for" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "notes_remind_idx" ON "notes" USING btree ("remind_at");