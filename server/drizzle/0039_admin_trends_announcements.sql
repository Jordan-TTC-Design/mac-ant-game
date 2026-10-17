CREATE TABLE "announcements" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"title" text NOT NULL,
	"body" text DEFAULT '' NOT NULL,
	"url" text,
	"audience" text NOT NULL,
	"at" timestamp (3) with time zone NOT NULL,
	"ends_at" timestamp (3) with time zone,
	"created_by" uuid,
	"pushed" integer
);
--> statement-breakpoint
CREATE TABLE "daily_active" (
	"day" text NOT NULL,
	"user_id" uuid NOT NULL,
	CONSTRAINT "daily_active_day_user_id_pk" PRIMARY KEY("day","user_id")
);
--> statement-breakpoint
ALTER TABLE "announcements" ADD CONSTRAINT "announcements_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_active" ADD CONSTRAINT "daily_active_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "announcements_at_idx" ON "announcements" USING btree ("at");