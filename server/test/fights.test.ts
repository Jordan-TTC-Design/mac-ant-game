import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { cellAt, lairEntry, neighbors, pvpFront, type CellView, type ExpeditionReport, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

// How fights are sized (server/WORLD.md §22): a cell only lets so many defenders stand up to a party, a lair only lets so
// many in, fighters keep at the foe they hit, and a party can ask first how it would likely fare.
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
async function account(email: string) {
  const password = await signUp(t, email);
  const auth = bearer((await logIn(t, email, password, mac(++macs))).body.token);
  await t.call("POST", "/camp/start", { race: "goblin" }, auth);
  return auth;
}
const me = async (auth: Record<string, string>) => (await t.call("GET", "/world", undefined, auth)).body as WorldMe;
const camp = async (auth: Record<string, string>) => (await t.call("GET", "/camp", undefined, auth)).body as CampView;
const map = async (auth: Record<string, string>) => (await t.call("GET", `/world/cells?lat=${DAAN.lat}&lng=${DAAN.lng}&radius=1000`, undefined, auth)).body as CellView[];
async function clear(cells: string[]) {
  const at = t.now().toISOString();
  for (const c of cells) await database.sql`insert into world_cells (cell, cleared_at) values (${c}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
}
/** Two camps grown together, in the big world a few cells apart; the first a veteran (big parties). */
async function twoCamps() {
  const a = await account("a@example.com");
  const b = await account("b@example.com");
  t.advance(16 * HOUR);
  const home = cellAt(DAAN);
  let far = home;
  for (let i = 0; i < 4; i++) far = neighbors(far)[0]!;
  await clear([home, far]);
  await t.call("POST", "/world/open", { cell: home }, a);
  await t.call("POST", "/world/open", { cell: far }, b);
  await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = 'a@example.com')`;
  return { a, b, home, far };
}
/** Every one of this camp at home carries the first tier's best. */
async function arm(email: string) {
  const gear = JSON.stringify({ weapon: { id: "great_sword", left: 240 }, chest: { id: "iron_plate", left: 36 }, head: { id: "iron_helm", left: 30 } });
  await database.sql`update camp_residents set gear = ${gear}::jsonb where user_id = (select id from users where email = ${email}) and place = 'home'`;
}
const arrive = async (res: { body: { arriveAt: string } }) => t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);

describe("a camp's cell against a party", () => {
  it("lets only so many of its defenders stand up at once — the strongest — and a beaten party still fells some", async () => {
    const { a, b, far } = await twoCamps();
    const theirs = (await me(b)).atHome;
    expect(theirs).toBeGreaterThan(pvpFront(6));
    const guess = await t.call("POST", "/world/expeditions/estimate", { to: far, count: 6 }, a);
    expect(guess.status).toBe(200);
    expect(guess.body).toEqual(expect.objectContaining({ facing: pvpFront(6), total: theirs }));
    const res = await t.call("POST", "/world/expeditions", { to: far, count: 6 }, a);
    expect(res.status).toBe(201);
    await arrive(res);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, a)).body as ExpeditionReport;
    expect(report.fighters.filter((f) => f.side === "defend")).toHaveLength(pvpFront(6));
    // (they keep at the one they hit: even a beaten party fells some, as a rule)
    expect(guess.body.killed).toBeGreaterThan(0);
  });

  it("overrun, the rest of a held cell's garrison flees home", async () => {
    const { a, b, far } = await twoCamps();
    await clear(neighbors(far));
    // b settles 30 next to its camp; a comes with a few of its best
    const cell = neighbors(far)[3]!;
    const settle = await t.call("POST", "/world/expeditions", { to: cell, count: 6, settle: true }, b);
    expect(settle.status).toBe(201);
    await arrive(settle);
    await arrive(await t.call("POST", "/world/expeditions", { to: cell, count: 24 }, b)); // (moving in is not limited)
    expect((await me(b)).cells.map((c) => c.cell)).toContain(cell);
    await arm("a@example.com");
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 8 }, a);
    await arrive(res);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, a)).body as ExpeditionReport;
    expect(report.fighters.filter((f) => f.side === "defend").length).toBeLessThanOrEqual(pvpFront(8));
    if (report.outcome!.won) {
      expect((await camp(b)).residents.some((r) => r.place === `cell:${cell}`)).toBe(false);
      expect((await me(b)).cells.map((c) => c.cell)).not.toContain(cell);
    }
  });
});

describe("a lair", () => {
  it("lets in only so many: a count is cut to it, a list longer than it is refused; the estimate says so", async () => {
    const a = await account("a@example.com");
    t.advance(16 * HOUR);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    await database.sql`update world_players set xp = 18050`;
    const lair = (await map(a)).filter((c) => c.lair && !c.owner && !c.boss).sort((x, y) => x.lair!.count - y.lair!.count)[0]!;
    const entry = lairEntry(lair.lair!.count, lair.lair!.boss);
    const guess = (await t.call("POST", "/world/expeditions/estimate", { to: lair.cell, count: 25 }, a)).body;
    expect(guess.entry).toBe(entry);
    expect(guess.facing).toBe(lair.lair!.count);
    const home = (await camp(a)).residents.filter((r) => r.place === "home").map((r) => r.id);
    const tooMany = await t.call("POST", "/world/expeditions", { to: lair.cell, residents: home.slice(0, entry + 1) }, a);
    expect(tooMany.status).toBe(409);
    expect(tooMany.body.message).toContain(String(entry));
    const res = await t.call("POST", "/world/expeditions", { to: lair.cell, count: 25 }, a);
    expect(res.status).toBe(201);
    expect(res.body.party).toBe(entry);
  });
});
