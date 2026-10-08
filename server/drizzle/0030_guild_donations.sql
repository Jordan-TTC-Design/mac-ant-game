CREATE TABLE "guild_donations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"user_id" uuid,
	"materials" jsonb NOT NULL,
	"points" integer NOT NULL,
	"at" timestamp (3) with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "points" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_donations" ADD CONSTRAINT "guild_donations_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_donations" ADD CONSTRAINT "guild_donations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "guild_donations_guild_idx" ON "guild_donations" USING btree ("guild_id","at");