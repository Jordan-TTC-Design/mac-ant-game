CREATE TABLE "expeditions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"from_place" text NOT NULL,
	"to_cell" text NOT NULL,
	"party" jsonb NOT NULL,
	"settle" boolean DEFAULT false NOT NULL,
	"set_out_at" timestamp (3) with time zone NOT NULL,
	"arrive_at" timestamp (3) with time zone NOT NULL,
	"status" text DEFAULT 'walking' NOT NULL,
	"defender" uuid,
	"result" jsonb
);
--> statement-breakpoint
CREATE TABLE "world_cells" (
	"cell" text PRIMARY KEY NOT NULL,
	"owner" uuid,
	"held_since" timestamp (3) with time zone,
	"nest_started_at" timestamp (3) with time zone,
	"next_slot" integer DEFAULT 0 NOT NULL,
	"advanced_to" timestamp (3) with time zone,
	"town" boolean DEFAULT false NOT NULL,
	"cleared_at" timestamp (3) with time zone,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "world_players" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"open" boolean DEFAULT true NOT NULL,
	"home_cell" text NOT NULL,
	"opened_at" timestamp (3) with time zone NOT NULL,
	"shielded_since" timestamp (3) with time zone,
	"last_shield_ended" timestamp (3) with time zone,
	"xp" integer DEFAULT 0 NOT NULL,
	"xp_counted_to" timestamp (3) with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "expeditions" ADD CONSTRAINT "expeditions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expeditions" ADD CONSTRAINT "expeditions_defender_users_id_fk" FOREIGN KEY ("defender") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "world_cells" ADD CONSTRAINT "world_cells_owner_users_id_fk" FOREIGN KEY ("owner") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "world_players" ADD CONSTRAINT "world_players_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "expeditions_walking_idx" ON "expeditions" USING btree ("arrive_at") WHERE status = 'walking';--> statement-breakpoint
CREATE INDEX "expeditions_user_idx" ON "expeditions" USING btree ("user_id","set_out_at");--> statement-breakpoint
CREATE INDEX "expeditions_defender_idx" ON "expeditions" USING btree ("defender");--> statement-breakpoint
CREATE INDEX "world_cells_owner_idx" ON "world_cells" USING btree ("owner");