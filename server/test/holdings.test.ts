import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { cellAt, type CellDetail, type CellView, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

// 領地 from inside, and what can be done with one (server/WORLD.md §20).
const MIN = 60_000;
const HOUR = 60 * MIN;
const DAAN = { lat: 25.0302, lng: 121.5357 };
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

let macs = 0;
async function account(email: string, race = "goblin") {
  const password = await signUp(t, email);
  const auth = bearer((await logIn(t, email, password, mac(++macs))).body.token);
  await t.call("POST", "/camp/start", { race }, auth);
  return auth;
}
const me = async (auth: Record<string, string>) => (await t.call("GET", "/world", undefined, auth)).body as WorldMe;
const camp = async (auth: Record<string, string>) => (await t.call("GET", "/camp", undefined, auth)).body as CampView;
const map = async (auth: Record<string, string>, at = DAAN, radius = 1000) =>
  (await t.call("GET", `/world/cells?lat=${at.lat}&lng=${at.lng}&radius=${radius}`, undefined, auth)).body as CellView[];
const detail = async (auth: Record<string, string>, cell: string) => (await t.call("GET", `/world/cells/${cell}`, undefined, auth)) as { status: number; body: CellDetail };
/** Puts materials in a camp's store (these tests are about what a cell does, not about earning them). */
async function give(email: string, materials: Record<string, number>) {
  await database.sql`update camps set materials = materials || ${JSON.stringify(materials)}::jsonb where user_id = (select id from users where email = ${email})`;
}

/** A camp in the big world at Daan, strong enough to send big parties. */
async function ready(email = "a@example.com", at = DAAN) {
  const a = await account(email);
  t.advance(16 * HOUR);
  await t.call("POST", "/world/open", { cell: cellAt(at) }, a);
  await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = ${email})`;
  return a;
}
/** Sends `count` to settle the nearest free or lair cell (lairs weakest first) and waits for them to get there. */
async function settle(auth: Record<string, string>, count = 20, not: string[] = []) {
  const home = (await me(auth)).homeCell!;
  const cells = (await map(auth)).filter((c) => !c.owner && !c.boss && c.cell !== home && !not.includes(c.cell));
  const target = cells.filter((c) => !c.lair)[0] ?? cells.sort((x, y) => x.lair!.power - y.lair!.power)[0]!;
  const res = await t.call("POST", "/world/expeditions", { to: target.cell, count, settle: true }, auth);
  expect(res.status).toBe(201);
  t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
  expect((await me(auth)).cells.map((c) => c.cell)).toContain(target.cell);
  return target.cell;
}

describe("a cell from inside", () => {
  it("shows who lives there, how its nest grows it, what it gives and what happened there", async () => {
    const a = await ready();
    const cell = await settle(a);
    let d = await detail(a, cell);
    expect(d.status).toBe(200);
    expect(d.body).toEqual(expect.objectContaining({ cell, home: false, nest: "none", nextBirthAt: null, capacity: 50, garrisonMin: 5 }));
    expect(d.body.garrison).toBe((await camp(a)).residents.filter((r) => r.place === `cell:${cell}`).length);
    expect(d.body.yields.length).toBeGreaterThan(0);
    expect(d.body.history[0]).toEqual(expect.objectContaining({ kind: "settled" }));

    await give("a@example.com", { scrap_wood: 30, scrap_iron: 10, scrap_rag: 10 });
    expect((await t.call("POST", `/world/cells/${cell}/nest`, undefined, a)).status).toBe(200);
    d = await detail(a, cell);
    expect(d.body.nest).toBe("building");
    expect(Date.parse(d.body.nestReadyAt!) - t.now().getTime()).toBe(2 * HOUR);
    expect(d.body.nextBirthAt).toBe(d.body.nestReadyAt);

    t.advance(3 * HOUR + MIN);
    d = await detail(a, cell);
    expect(d.body.nest).toBe("ready");
    expect(d.body.birthMinutes).toBe(15);
    expect(Date.parse(d.body.nextBirthAt!)).toBeGreaterThanOrEqual(t.now().getTime());
    expect(d.body.history.map((h) => h.kind)).toEqual(expect.arrayContaining(["yield", "nest", "settled"]));
    expect(d.body.history.find((h) => h.kind === "yield")!.loot).toBeDefined();
  });

  it("is only for one's own cells; the camp's own cell says so", async () => {
    const a = await ready();
    const b = await account("b@example.com");
    const w = await me(a);
    expect((await detail(a, w.homeCell!)).body.home).toBe(true);
    expect((await detail(b, w.homeCell!)).status).toBe(403);
    expect((await detail(a, "nope")).status).toBe(404);
  });
});
