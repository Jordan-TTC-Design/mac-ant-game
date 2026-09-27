CREATE SEQUENCE "public"."camp_event_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "camp_events" (
	"seq" bigint PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"at" timestamp (3) with time zone NOT NULL,
	"kind" text NOT NULL,
	"data" jsonb NOT NULL
);
--> statement-breakpoint
CREATE TABLE "camp_residents" (
	"user_id" uuid NOT NULL,
	"id" integer NOT NULL,
	"breed" text NOT NULL,
	"seed" bigint NOT NULL,
	"legacy_seed" text,
	"name" text,
	"parents" text,
	"born_at" timestamp (3) with time zone NOT NULL,
	"dies_at" timestamp (3) with time zone,
	"died_at" timestamp (3) with time zone,
	"gear" jsonb,
	"place" text DEFAULT 'home' NOT NULL,
	CONSTRAINT "camp_residents_user_id_id_pk" PRIMARY KEY("user_id","id")
);
--> statement-breakpoint
CREATE TABLE "camps" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"race" text NOT NULL,
	"seed" bigint NOT NULL,
	"started_at" timestamp (3) with time zone NOT NULL,
	"advanced_to" timestamp (3) with time zone NOT NULL,
	"next_slot" integer NOT NULL,
	"next_id" integer NOT NULL,
	"peak" integer NOT NULL,
	"version" bigint DEFAULT 1 NOT NULL,
	"next_raid" integer DEFAULT 0 NOT NULL,
	"materials" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"larder" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"armory" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"boosts" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"food_cooldowns" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"princess_name" text DEFAULT '' NOT NULL,
	"romance" jsonb,
	"kills" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"delivered" integer DEFAULT 0 NOT NULL,
	"migrated_from" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "camp_events" ADD CONSTRAINT "camp_events_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "camp_residents" ADD CONSTRAINT "camp_residents_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "camps" ADD CONSTRAINT "camps_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "camp_events_user_seq_idx" ON "camp_events" USING btree ("user_id","seq");--> statement-breakpoint
CREATE INDEX "camp_residents_alive_idx" ON "camp_residents" USING btree ("user_id") WHERE died_at is null;