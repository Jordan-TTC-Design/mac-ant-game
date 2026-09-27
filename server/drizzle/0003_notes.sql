CREATE SEQUENCE "public"."note_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
CREATE TABLE "notes" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"text" text NOT NULL,
	"color" text NOT NULL,
	"breed" text NOT NULL,
	"goblin_name" text NOT NULL,
	"due_at" timestamp with time zone,
	"remind_at" timestamp with time zone,
	"remind_fired" boolean DEFAULT false NOT NULL,
	"done" boolean DEFAULT false NOT NULL,
	"deleted" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	"seq" bigint NOT NULL,
	"field_seqs" jsonb DEFAULT '{}'::jsonb NOT NULL
);
--> statement-breakpoint
ALTER TABLE "notes" ADD CONSTRAINT "notes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "notes_user_seq_idx" ON "notes" USING btree ("user_id","seq");