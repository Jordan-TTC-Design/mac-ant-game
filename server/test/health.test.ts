import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { healthSchema } from "@goblincamp/shared";
import { createApp } from "../src/app.ts";
import { createDatabase, type Database } from "../src/db/client.ts";
import { runMigrations } from "../src/db/migrate.ts";

// The test database from compose.dev.yml (`pnpm db:up`); never the development one.
const url = process.env.TEST_DATABASE_URL ?? "postgres://goblin:goblin@localhost:5433/goblin_test";
let database: Database;

beforeAll(async () => {
  database = createDatabase(url);
  await runMigrations(database);
});

afterAll(async () => {
  await database?.close();
});

describe("GET /api/health", () => {
  it("says ok when the database answers", async () => {
    const res = await createApp({ pingDatabase: database.ping }).request("/api/health");
    expect(res.status).toBe(200);
    expect(healthSchema.parse(await res.json())).toEqual({ ok: true, db: "ok", apiVersion: 1 });
  });

  it("says the database is down (503) when it does not answer", async () => {
    const res = await createApp({ pingDatabase: async () => false }).request("/api/health");
    expect(res.status).toBe(503);
    expect(await res.json()).toMatchObject({ ok: false, db: "down" });
  });
});

describe("migrations", () => {
  it("made the users table with a case-insensitive email", async () => {
    const [row] = await database.sql<{ type: string }[]>`
      select udt_name as type from information_schema.columns where table_name = 'users' and column_name = 'email'`;
    expect(row?.type).toBe("citext");
  });
});
