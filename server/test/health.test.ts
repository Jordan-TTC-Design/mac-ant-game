import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { healthSchema } from "@goblincamp/shared";
import type { Database } from "../src/db/client.ts";
import { openTestDatabase, testApp } from "./helpers.ts";

let database: Database;
beforeAll(async () => {
  database = await openTestDatabase();
});
afterAll(async () => {
  await database?.close();
});

describe("GET /api/health", () => {
  it("says ok when the database answers", async () => {
    const res = await testApp(database).call("GET", "/health");
    expect(res.status).toBe(200);
    expect(healthSchema.parse(res.body)).toEqual({ ok: true, db: "ok", apiVersion: 1 });
  });

  it("says the database is down (503) when it does not answer", async () => {
    const res = await testApp({ ...database, ping: async () => false }).call("GET", "/health");
    expect(res.status).toBe(503);
    expect(res.body).toMatchObject({ ok: false, db: "down" });
  });
});

describe("migrations", () => {
  it("made the users table with a case-insensitive email", async () => {
    const [row] = await database.sql<{ type: string }[]>`
      select udt_name as type from information_schema.columns where table_name = 'users' and column_name = 'email'`;
    expect(row?.type).toBe("citext");
  });
});
