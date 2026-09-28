import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Database } from "../src/db/client.ts";
import { clearOld } from "../src/maintenance.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

const DAY = 86_400_000;
let database: Database;
let t: TestApp;
beforeAll(async () => {
  database = await openTestDatabase();
});
beforeEach(async () => {
  await emptyTables(database);
  t = testApp(database);
});
afterAll(async () => {
  await database?.close();
});

describe("clearing old records", () => {
  it("drops camp events after 30 days, ended sign-ins after 30, used links after 7, and deleted accounts after 30", async () => {
    const password = await signUp(t, "a@example.com");
    const auth = bearer((await logIn(t, "a@example.com", password, mac(1))).body.token);
    await t.call("POST", "/camp/start", { race: "goblin" }, auth);
    // a second sign-in that is signed out
    const other = bearer((await logIn(t, "a@example.com", password, mac(2))).body.token);
    await t.call("POST", "/auth/logout", undefined, other);
    const events = async () => (await database.sql<{ n: number }[]>`select count(*)::int as n from camp_events`)[0]!.n;
    const sessions = async () => (await database.sql<{ n: number }[]>`select count(*)::int as n from sessions`)[0]!.n;
    const links = async () => (await database.sql<{ n: number }[]>`select count(*)::int as n from email_tokens`)[0]!.n;
    expect(await events()).toBeGreaterThan(0);
    expect(await links()).toBeGreaterThan(0); // (the confirm mail's link, used)

    let cleared = await clearOld(t.app.deps, new Date(t.now().getTime() + 8 * DAY));
    expect(cleared.links).toBeGreaterThan(0);
    expect(await events()).toBeGreaterThan(0); // (not yet)
    expect(await sessions()).toBe(2);

    cleared = await clearOld(t.app.deps, new Date(t.now().getTime() + 31 * DAY));
    expect(cleared.events).toBeGreaterThan(0);
    expect(await events()).toBe(0);
    expect(await sessions()).toBe(1); // the signed-out one went; the live one stays

    // an account asked to be deleted goes 30 days later, with its camp
    await database.sql`update users set deleting_at = ${new Date(t.now().getTime() - 31 * DAY).toISOString()}::timestamptz`;
    cleared = await clearOld(t.app.deps, t.now());
    expect(cleared.accounts).toBe(1);
    expect((await database.sql<{ n: number }[]>`select count(*)::int as n from camps`)[0]!.n).toBe(0);
  });
});
