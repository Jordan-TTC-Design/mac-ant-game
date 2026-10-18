CREATE SEQUENCE "public"."camp_resident_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1;--> statement-breakpoint
ALTER TABLE "camp_residents" ADD COLUMN "changed_seq" bigint DEFAULT nextval('camp_resident_seq') NOT NULL;--> statement-breakpoint
CREATE INDEX "camp_residents_changed_idx" ON "camp_residents" USING btree ("user_id","changed_seq");--> statement-breakpoint
-- Every change to a resident gets a new number, whichever code makes it (inserts take the column's default), so
-- `GET /api/camp?residentsSince=` can send only the residents that changed.
CREATE FUNCTION "camp_resident_changed"() RETURNS trigger AS $$
BEGIN
  NEW.changed_seq := nextval('camp_resident_seq');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;--> statement-breakpoint
CREATE TRIGGER "camp_residents_changed" BEFORE UPDATE ON "camp_residents" FOR EACH ROW EXECUTE FUNCTION "camp_resident_changed"();
