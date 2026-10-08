CREATE TABLE "avatars" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"avatar" jsonb,
	"left_guild_at" timestamp (3) with time zone,
	"updated_at" timestamp (3) with time zone NOT NULL
);
--> statement-breakpoint
CREATE TABLE "guild_decor_log" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"guild_id" uuid NOT NULL,
	"user_id" uuid,
	"at" timestamp (3) with time zone NOT NULL,
	"added" integer NOT NULL,
	"moved" integer NOT NULL,
	"removed" integer NOT NULL,
	"restored" boolean DEFAULT false NOT NULL,
	"before" jsonb NOT NULL
);
--> statement-breakpoint
CREATE TABLE "guild_invites" (
	"guild_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"invited_by" uuid,
	"at" timestamp (3) with time zone NOT NULL,
	CONSTRAINT "guild_invites_guild_id_user_id_pk" PRIMARY KEY("guild_id","user_id")
);
--> statement-breakpoint
CREATE TABLE "guild_members" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"guild_id" uuid NOT NULL,
	"role" text NOT NULL,
	"joined_at" timestamp (3) with time zone NOT NULL,
	"presence" text,
	"presence_at" timestamp (3) with time zone
);
--> statement-breakpoint
CREATE TABLE "guilds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" "citext" NOT NULL,
	"badge" text NOT NULL,
	"level" integer DEFAULT 1 NOT NULL,
	"decor" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"decor_version" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp (3) with time zone NOT NULL,
	CONSTRAINT "guilds_name_unique" UNIQUE("name")
);
--> statement-breakpoint
ALTER TABLE "avatars" ADD CONSTRAINT "avatars_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD CONSTRAINT "guild_decor_log_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_decor_log" ADD CONSTRAINT "guild_decor_log_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_invites" ADD CONSTRAINT "guild_invites_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_invites" ADD CONSTRAINT "guild_invites_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_invites" ADD CONSTRAINT "guild_invites_invited_by_users_id_fk" FOREIGN KEY ("invited_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_members" ADD CONSTRAINT "guild_members_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "guild_members" ADD CONSTRAINT "guild_members_guild_id_guilds_id_fk" FOREIGN KEY ("guild_id") REFERENCES "public"."guilds"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "guild_decor_log_guild_idx" ON "guild_decor_log" USING btree ("guild_id","at");--> statement-breakpoint
CREATE INDEX "guild_invites_user_idx" ON "guild_invites" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "guild_members_guild_idx" ON "guild_members" USING btree ("guild_id");