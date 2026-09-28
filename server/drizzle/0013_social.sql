CREATE TABLE "blocks" (
	"user_id" uuid NOT NULL,
	"blocked_id" uuid NOT NULL,
	"at" timestamp (3) with time zone NOT NULL,
	CONSTRAINT "blocks_user_id_blocked_id_pk" PRIMARY KEY("user_id","blocked_id")
);
--> statement-breakpoint
CREATE TABLE "claude_asks" (
	"user_id" uuid NOT NULL,
	"id" text NOT NULL,
	"device_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"project" text NOT NULL,
	"text" text NOT NULL,
	"at" timestamp (3) with time zone NOT NULL,
	"until" timestamp (3) with time zone,
	"answer" jsonb,
	CONSTRAINT "claude_asks_user_id_id_pk" PRIMARY KEY("user_id","id")
);
--> statement-breakpoint
CREATE TABLE "friendships" (
	"user_a" uuid NOT NULL,
	"user_b" uuid NOT NULL,
	"asked_by" uuid NOT NULL,
	"created_at" timestamp (3) with time zone NOT NULL,
	"accepted_at" timestamp (3) with time zone,
	CONSTRAINT "friendships_user_a_user_b_pk" PRIMARY KEY("user_a","user_b")
);
--> statement-breakpoint
CREATE TABLE "messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"from_user" uuid NOT NULL,
	"to_user" uuid NOT NULL,
	"text" text NOT NULL,
	"at" timestamp (3) with time zone NOT NULL,
	"read_at" timestamp (3) with time zone
);
--> statement-breakpoint
CREATE TABLE "pomodoros" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"state" jsonb NOT NULL,
	"told_index" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp (3) with time zone NOT NULL
);
--> statement-breakpoint
ALTER TABLE "blocks" ADD CONSTRAINT "blocks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "blocks" ADD CONSTRAINT "blocks_blocked_id_users_id_fk" FOREIGN KEY ("blocked_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "claude_asks" ADD CONSTRAINT "claude_asks_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_user_a_users_id_fk" FOREIGN KEY ("user_a") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_user_b_users_id_fk" FOREIGN KEY ("user_b") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_asked_by_users_id_fk" FOREIGN KEY ("asked_by") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messages" ADD CONSTRAINT "messages_from_user_users_id_fk" FOREIGN KEY ("from_user") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "messages" ADD CONSTRAINT "messages_to_user_users_id_fk" FOREIGN KEY ("to_user") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "pomodoros" ADD CONSTRAINT "pomodoros_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "claude_asks_at_idx" ON "claude_asks" USING btree ("at");--> statement-breakpoint
CREATE INDEX "friendships_b_idx" ON "friendships" USING btree ("user_b");--> statement-breakpoint
CREATE INDEX "messages_pair_idx" ON "messages" USING btree ("from_user","to_user","at");--> statement-breakpoint
CREATE INDEX "messages_unread_idx" ON "messages" USING btree ("to_user") WHERE read_at is null;