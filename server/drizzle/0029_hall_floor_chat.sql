CREATE TABLE "guild_chat" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"user_id" uuid,
	"text" text NOT NULL,
	"at" timestamp (3) with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "floor_changed" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD COLUMN "floor_before" jsonb;--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "floor" jsonb DEFAULT '{"base":"oak","tiles":{}}'::jsonb NOT NULL;--> statement-breakpoint
ALTER TABLE "guilds" ADD COLUMN "wall" text DEFAULT 'stone' NOT NULL;--> statement-breakpoint
ALTER TABLE "guild_chat" ADD CONSTRAINT "guild_chat_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_chat" ADD CONSTRAINT "guild_chat_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "guild_chat_guild_idx" ON "guild_chat" USING btree ("guild_id","at");