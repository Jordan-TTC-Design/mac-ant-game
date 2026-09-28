CREATE TABLE "world_terrain" (
	"cell" text PRIMARY KEY NOT NULL,
	"terrain" text NOT NULL,
	"source" text DEFAULT 'osm' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
