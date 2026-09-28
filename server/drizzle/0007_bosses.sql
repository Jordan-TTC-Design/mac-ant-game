CREATE TABLE "world_bosses" (
	"key" text PRIMARY KEY NOT NULL,
	"kind" text NOT NULL,
	"cell" text NOT NULL,
	"hp" integer NOT NULL,
	"max_hp" integer NOT NULL,
	"ends_at" timestamp (3) with time zone NOT NULL,
	"damage" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"defeated_at" timestamp (3) with time zone,
	"defeated_by" uuid
);
--> statement-breakpoint
CREATE TABLE "world_rewards" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"created_at" timestamp (3) with time zone NOT NULL,
	"data" jsonb NOT NULL,
	"claimed_at" timestamp (3) with time zone
);
--> statement-breakpoint
ALTER TABLE "world_bosses" ADD CONSTRAINT "world_bosses_defeated_by_users_id_fk" FOREIGN KEY ("defeated_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "world_rewards" ADD CONSTRAINT "world_rewards_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "world_rewards_open_idx" ON "world_rewards" USING btree ("user_id") WHERE claimed_at is null;