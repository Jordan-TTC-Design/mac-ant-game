ALTER TABLE "camps" ADD COLUMN "sites" jsonb DEFAULT '[{"id":1,"kind":"farm","level":1}]'::jsonb NOT NULL;--> statement-breakpoint
-- the camps that were there before sites: the farm keeps its level (and an upgrade under way), and a lumber camp and a quarry at level 2 come in place of the felling and digging they had (server/FARM.md §11.6)
UPDATE "camps" SET "sites" = jsonb_build_array(
  jsonb_build_object('id', 1, 'kind', 'farm', 'level', "farm_level") || CASE WHEN "farm_upgrade_until" IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('busyUntil', to_jsonb("farm_upgrade_until")) END,
  jsonb_build_object('id', 2, 'kind', 'lumber', 'level', 2),
  jsonb_build_object('id', 3, 'kind', 'quarry', 'level', 2)
);
