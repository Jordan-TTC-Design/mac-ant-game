import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { GEAR, GEAR_SLOTS, gearPower, type CampView } from "@goblincamp/shared/camp";
import { bossIn, bossWindow, cellAt, LAIRS, lairEntry, cellCenter, cellsWithin, neighbors, regionOf, WORLD_SEED, type CellView, type ExpeditionReport, type RoutePreview, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { APP_URL, bearer, emptyTables, logIn, mac, openTestDatabase, phone, signUp, testApp, type TestApp } from "./helpers.ts";

const MIN = 60_000;
const HOUR = 60 * MIN;
const DAAN = { lat: 25.0302, lng: 121.5357 };
const XINYI = { lat: 25.0336, lng: 121.5647 }; // about 3 km east
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
/** A camp high enough in the big world (race level 20) to send big parties: these tests are about what happens, not balance. */
async function veteran(email: string) {
  await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = ${email})`;
}
/** A camp at race level 50: the great monsters let it in (bosses.ts BOSS_MIN_RACE_LEVEL). */
async function legend(email: string) {
  await database.sql`update world_players set xp = 120050 where user_id = (select id from users where email = ${email})`;
}
const me = async (auth: Record<string, string>) => (await t.call("GET", "/world", undefined, auth)).body as WorldMe;
const camp = async (auth: Record<string, string>) => (await t.call("GET", "/camp", undefined, auth)).body as CampView;
const map = async (auth: Record<string, string>, at = DAAN, radius = 1200) =>
  (await t.call("GET", `/world/cells?lat=${at.lat}&lng=${at.lng}&radius=${radius}`, undefined, auth)).body as CellView[];
const home = (c: CampView) => c.residents.filter((r) => r.place === "home").length;

/** Waits (on the test clock) until a camp has had its third look (goblins: 150). */
async function grow(auth: Record<string, string>) {
  t.advance(16 * HOUR);
  const c = await camp(auth);
  expect(c.peak).toBeGreaterThanOrEqual(150);
}

describe("opening the big world", () => {
  it("waits for the camp's third look, then puts the camp on the cell picked (nobody is sent)", async () => {
    const a = await account("a@example.com");
    const first = cellAt(DAAN);
    let res = await t.call("POST", "/world/open", { cell: first }, a);
    expect(res.status).toBe(403);
    expect(res.body.error).toBe("too_small");
    expect((await me(a)).canOpen).toBe(false);

    await grow(a);
    const before = home(await camp(a));
    res = await t.call("POST", "/world/open", { cell: first, settlers: 10 }, a); // (what an older phone sends: not used)
    expect(res.status).toBe(201);
    const w = res.body as WorldMe;
    expect(w.open).toBe(true);
    expect(w.homeCell).toBe(first);
    expect(w.homeMoveAt).toBeNull();
    // the camp stands there: everybody at home lives on it; its nest is the camp's own
    expect(w.cells).toEqual([expect.objectContaining({ cell: first, nest: "ready" })]);
    const after = await camp(a);
    expect(after.residents.filter((r) => r.place === `cell:${first}`)).toHaveLength(0);
    expect(home(after)).toBeGreaterThanOrEqual(before);
    expect(w.cells[0]!.garrison).toBe(w.atHome);
    expect((await map(a)).find((c) => c.cell === first)!.garrison).toBe(w.atHome);
    expect((await t.call("POST", "/world/open", {}, a)).status).toBe(409); // already open

    // a day on: still the camp's, no births of its own on top of the camp's
    t.advance(24 * HOUR);
    const later = await me(a);
    expect(later.cells.map((c) => c.cell)).toEqual([first]);
    expect((await camp(a)).residents.filter((r) => r.place === `cell:${first}`)).toHaveLength(0);
    // it cannot be given up
    expect((await t.call("POST", `/world/cells/${first}/recall`, {}, a)).body.error).toBe("camp_cell");
  });

  it("moves the camp once a week", async () => {
    const a = await account("a@example.com");
    await grow(a);
    const first = cellAt(DAAN);
    await t.call("POST", "/world/open", { cell: first }, a);
    const target = (await map(a)).find((c) => !c.owner && !c.boss && c.cell !== first)!.cell;
    let res = await t.call("POST", `/world/cells/${target}/home`, {}, a);
    expect(res.status).toBe(200);
    const w = res.body as WorldMe;
    expect(w.homeCell).toBe(target);
    expect(w.cells.map((c) => c.cell)).toEqual([target]); // (the old spot is nobody's now)
    expect(Date.parse(w.homeMoveAt!) - t.now().getTime()).toBe(7 * 24 * HOUR);
    expect((await map(a)).find((c) => c.cell === target)!.lair).toBeNull(); // (a lair there was driven off)

    res = await t.call("POST", `/world/cells/${first}/home`, {}, a);
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("too_soon");
    t.advance(7 * 24 * HOUR);
    expect((await t.call("POST", `/world/cells/${first}/home`, {}, a)).status).toBe(200);
  });

  it("yields what the ground gives every three hours to the camp's store", async () => {
    const a = await account("a@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN), settlers: 20 }, a);
    const next = (await me(a)).cells[0]!.nextYieldAt;
    expect(Date.parse(next) - t.now().getTime()).toBe(3 * HOUR);
    t.advance(7 * HOUR);
    await me(a);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, a)).body.events as { kind: string; data: { yields?: Record<string, number> } }[];
    const yields = events.find((e) => e.data.yields)?.data.yields;
    expect(yields).toBeDefined();
    expect(Object.values(yields!).reduce((x, y) => x + y, 0)).toBeGreaterThan(0);
    // two yields were taken (7 hours), the next one is due at 9 hours after it was settled
    expect(Date.parse((await me(a)).cells[0]!.nextYieldAt) - (t.now().getTime() - 7 * HOUR)).toBe(9 * HOUR);
  });

  it("shows the map: whose cells, lairs with their strength, terrain", async () => {
    const a = await account("a@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN), settlers: 8 }, a);
    const cells = await map(a);
    expect(cells.length).toBeGreaterThan(30);
    const mine = cells.find((c) => c.cell === cellAt(DAAN))!;
    expect(mine.owner?.race).toBe("goblin");
    expect(mine.garrison).toBeGreaterThanOrEqual(8); // (its nest may have raised one meanwhile)
    expect(mine.lair).toBeNull();
    const lairs = cells.filter((c) => c.lair);
    expect(lairs.length).toBeGreaterThan(5);
    for (const c of lairs) {
      expect(c.lair!.power).toBeGreaterThan(0);
      expect(Object.values(c.lair!.foes).reduce((a, b) => a + b, 0)).toBe(c.lair!.count);
    }
    expect(new Set(cells.map((c) => c.terrain)).size).toBeGreaterThan(1);
    expect((await t.call("GET", "/world/cells?lat=25&lng=121&radius=9000", undefined, a)).status).toBe(400);
  });
});

describe("expeditions", () => {
  async function ready() {
    const a = await account("a@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN), settlers: 8 }, a);
    await veteran("a@example.com");
    return a;
  }
  /** The weakest lair near home. */
  async function weakLair(auth: Record<string, string>) {
    const lairs = (await map(auth, DAAN, 1000)).filter((c) => c.lair && c.cell !== cellAt(DAAN));
    return lairs.sort((x, y) => x.lair!.power - y.lair!.power)[0]!;
  }

  it("walk there, fight the lair, bring the loot home and clear it", async () => {
    const a = await ready();
    const target = await weakLair(a);
    const materialsBefore = (await camp(a)).materials;
    const res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 25 }, a);
    expect(res.status).toBe(201);
    expect(res.body.kind).toBe("attack");
    const minutes = (Date.parse(res.body.arriveAt) - Date.parse(res.body.setOutAt)) / MIN;
    expect(minutes).toBeGreaterThanOrEqual(3);
    expect(minutes).toBeLessThan(30);
    // on the road: not at home (as many as the lair holds: lairEntry)
    const entry = lairEntry(target.lair!.count, target.lair!.boss);
    expect(res.body.party).toBe(Math.min(25, entry));
    const walking = await camp(a);
    expect(walking.residents.filter((r) => r.place === `exp:${res.body.id}`)).toHaveLength(Math.min(25, entry));
    expect((await me(a)).walking).toHaveLength(1);

    t.advance(minutes * MIN + 1000);
    const w = await me(a);
    expect(w.walking).toHaveLength(0);
    const done = w.recent[0]!;
    expect(done.outcome?.won).toBe(true);
    expect(done.outcome?.cell).toBe("cleared");
    expect(w.xp).toBeGreaterThan(0);
    // the loot is in the books, the party is home, the lair is gone for a while
    const after = await camp(a);
    const gained = Object.values(done.outcome!.loot).reduce((x, y) => x + y, 0);
    expect(Object.values(after.materials).reduce((x, y) => x + y, 0)).toBeGreaterThanOrEqual(Object.values(materialsBefore).reduce((x, y) => x + y, 0) + gained - 0);
    expect(after.residents.some((r) => r.place.startsWith("exp:"))).toBe(false);
    const cleared = (await map(a, DAAN, 1000)).find((c) => c.cell === target.cell)!;
    expect(cleared.lair).toBeNull();
    expect(cleared.lairBackAt).not.toBeNull();

    // the report has the whole fight to play back
    const report = (await t.call("GET", `/world/expeditions/${done.id}`, undefined, a)).body as ExpeditionReport;
    expect(report.events.length).toBeGreaterThan(0);
    expect(report.fighters.filter((f) => f.side === "attack")).toHaveLength(Math.min(25, entry));
    expect(report.lair?.name).toBe(target.lair!.name);
  });

  it("settle a free cell, move more in, build a nest that raises residents, and give it up", async () => {
    const a = await ready();
    const target = await weakLair(a);
    let res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 25, settle: true }, a);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    let w = await me(a);
    expect(w.recent[0]!.outcome?.cell).toBe("settled");
    const held = w.cells.find((c) => c.cell === target.cell)!;
    expect(held.garrison).toBeGreaterThanOrEqual(5);

    // more move in from home (no fight: it is ours)
    res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 3 }, a);
    expect(res.body.kind).toBe("move");
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    w = await me(a);
    expect(w.cells.find((c) => c.cell === target.cell)!.garrison).toBe(held.garrison + 3);

    // a nest: materials from the home raids pay for it; two hours to build, then a resident every 15 minutes
    const c = await camp(a);
    const enough = (c.materials.scrap_wood ?? 0) >= 30 && (c.materials.scrap_iron ?? 0) >= 10 && (c.materials.scrap_rag ?? 0) >= 10;
    res = await t.call("POST", `/world/cells/${target.cell}/nest`, undefined, a);
    if (!enough) {
      expect(res.status).toBe(409);
      expect(res.body.error).toBe("cannot_afford");
      return;
    }
    expect(res.status).toBe(200);
    expect((await t.call("POST", `/world/cells/${target.cell}/nest`, undefined, a)).status).toBe(409);
    const before = (await me(a)).cells.find((x) => x.cell === target.cell)!;
    expect(before.nest).toBe("building");
    t.advance(2 * HOUR + 61 * MIN);
    const grown = (await me(a)).cells.find((x) => x.cell === target.cell)!;
    expect(grown.nest).toBe("ready");
    expect(grown.garrison).toBeGreaterThanOrEqual(before.garrison + 3);
    const born = (await camp(a)).residents.filter((r) => r.place === `cell:${target.cell}`);
    expect(born.length).toBe(grown.garrison);

    // everyone walks home: the cell is free again
    res = await t.call("POST", `/world/cells/${target.cell}/recall`, {}, a);
    expect(res.status).toBe(200);
    expect((res.body as WorldMe).cells.some((x) => x.cell === target.cell)).toBe(false);
  });

  it("tell the phone when they arrive (a push that opens the report)", async () => {
    const password = await signUp(t, "p@example.com");
    const onMac = bearer((await logIn(t, "p@example.com", password, mac(++macs))).body.token);
    await t.call("POST", "/camp/start", { race: "goblin" }, onMac);
    const cookie = (await logIn(t, "p@example.com", password, phone)).headers.get("set-cookie")!.split(";")[0]!;
    expect((await t.call("POST", "/push/subscribe", { endpoint: "https://push.example/p", keys: { p256dh: "BPkey", auth: "authkey" } }, { cookie, origin: APP_URL })).status).toBe(204);
    await grow(onMac);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN), settlers: 8 }, onMac);
    await veteran("p@example.com");
    const target = await weakLair(onMac);
    const res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 25 }, onMac);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    await me(onMac);
    const push = t.push.sent.find((p) => (p.payload as { type: string }).type === "world")?.payload as { title: string; body: string; url: string };
    expect(push.title).toBe("出征的隊伍到了");
    expect(push.body).toContain(target.lair!.name);
    expect(push.url).toBe(`/expedition/${res.body.id}`);
  });

  it("see the lair come back for a settled cell when its time is up: held, it is beaten again; lost, the cell is its again", async () => {
    const a = await ready();
    const target = await weakLair(a);
    const res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 12, settle: true }, a);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).cells.map((c) => c.cell)).toContain(target.cell);
    // a day later (every lair is back within 24 hours; the camp's own first cell is spared)
    t.advance(25 * HOUR);
    const w = await me(a);
    const back = w.happenings.filter((h) => h.lairBack?.cell === target.cell);
    expect(back.length).toBeGreaterThan(0);
    const last = back[0]!.lairBack!;
    expect(last.name).toBe(target.lair!.name);
    if (last.held) {
      expect(w.cells.map((c) => c.cell)).toContain(target.cell);
      expect(last.killed).toBeGreaterThan(0);
    } else {
      expect(w.cells.map((c) => c.cell)).not.toContain(target.cell);
      expect((await map(a, cellCenter(target.cell), 300)).find((c) => c.cell === target.cell)!.lair).not.toBeNull();
    }
    expect(w.happenings.some((h) => h.lairBack?.cell === cellAt(DAAN))).toBe(false);
  });

  it("refuse what cannot be: too big a party, leaving a cell unguarded, someone else's cell as a start", async () => {
    const a = await ready();
    const target = await weakLair(a);
    expect((await t.call("POST", "/world/expeditions", { to: target.cell, count: 61 }, a)).status).toBe(400);
    // the first cell has 8: sending 5 would leave 3, fewer than the 5 that hold it
    const res = await t.call("POST", "/world/expeditions", { from: cellAt(DAAN), to: target.cell, count: 5 }, a);
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("too_few");
    expect((await t.call("POST", "/world/expeditions", { from: neighbors(cellAt(DAAN))[0], to: target.cell, count: 3 }, a)).status).toBe(403);
    expect((await t.call("POST", "/world/expeditions", { to: target.cell, residents: [999_999] }, a)).status).toBe(409);
  });
});

describe("camps against camps", () => {
  it("fight over a cell; the loser turtles and cannot be attacked until it opens again", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    const aCell = cellAt(DAAN);
    const bCell = cellAt(XINYI);
    await t.call("POST", "/world/open", { cell: aCell }, a);
    await t.call("POST", "/world/open", { cell: bCell }, b);
    await veteran("a@example.com");
    await veteran("b@example.com");
    // a holds a second cell with 5 (a free one nearby)
    const free = (await map(a, cellCenter(aCell), 800)).find((c) => !c.owner && !c.lair && !c.boss && c.cell !== bCell)!.cell;
    let res = await t.call("POST", "/world/expeditions", { to: free, count: 5, settle: true }, a);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).cells.map((c) => c.cell).sort()).toEqual([aCell, free].sort());

    // b attacks that cell (5 defenders) with its 40 strongest
    res = await t.call("POST", "/world/expeditions", { to: free, count: 25, settle: true }, b);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const wb = await me(b);
    const fight = wb.recent[0]!;
    expect(fight.outcome?.won).toBe(true);
    expect(fight.outcome?.cell).toBe("taken");
    expect(wb.cells.map((c) => c.cell)).toContain(free);
    // a hears of it, lost that cell and its garrison (not its camp), and turtles
    const wa = await me(a);
    expect(wa.cells.map((c) => c.cell)).toEqual([aCell]);
    expect(wa.shielded).toBe(true);
    expect(wa.open).toBe(false);
    expect(wa.recent[0]!.defending).toBe(true);
    expect((await camp(a)).residents.some((r) => r.place.startsWith("cell:"))).toBe(false);
    // a turtling camp cannot send parties, and is not attacked
    expect((await t.call("POST", "/world/expeditions", { to: bCell, count: 5 }, a)).status).toBe(403);

    // a opens again, retakes nothing yet; the leaderboard has both
    expect((await t.call("POST", "/world/open", {}, a)).status).toBe(201);
    expect((await me(a)).shielded).toBe(false);
    const board = (await t.call("GET", "/world/leaderboard", undefined, a)).body as { all: { name: string; rank: number; cells: number }[] };
    expect(board.all).toHaveLength(2);
    expect(board.all.find((e) => e.cells === 2)).toBeDefined();
  });

  it("a camp is defended by everybody at home and cannot be taken", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    const aCell = cellAt(DAAN);
    await t.call("POST", "/world/open", { cell: aCell }, a);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    await veteran("b@example.com");
    const res = await t.call("POST", "/world/expeditions", { to: aCell, count: 20, settle: true }, b);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, b)).body as ExpeditionReport;
    expect(report.outcome!.against).toContain("營地");
    expect(report.outcome!.where?.kind).toBe("home");
    expect(report.fighters.filter((f) => f.side === "defend").length).toBeGreaterThan(20); // (the whole camp)
    expect((await me(a)).cells.map((c) => c.cell)).toEqual([aCell]);
  });

  it("a camp is helped by its held cells next to it", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    const aCell = cellAt(DAAN);
    await t.call("POST", "/world/open", { cell: aCell }, a);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    await veteran("a@example.com");
    await veteran("b@example.com");
    const next = (await map(a, cellCenter(aCell), 400)).find((c) => neighbors(aCell).includes(c.cell) && !c.owner && !c.lair && !c.boss)!.cell;
    const res = await t.call("POST", "/world/expeditions", { to: next, count: 12, settle: true }, a);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const wa = await me(a);
    expect(wa.cells.find((c) => c.cell === next)?.garrison).toBe(12);
    const odds = (await t.call("POST", "/world/expeditions/estimate", { to: aCell, count: 10 }, b)).body as { total: number };
    expect(odds.total).toBe(wa.atHome + 5); // (everybody at home, and five from the cell next door: it keeps the rest)
  });

  it("moves residents between its own joined cells quickly", async () => {
    const a = await account("a@example.com");
    await grow(a);
    const aCell = cellAt(DAAN);
    await t.call("POST", "/world/open", { cell: aCell }, a);
    await veteran("a@example.com");
    const next = (await map(a, cellCenter(aCell), 400)).find((c) => neighbors(aCell).includes(c.cell) && !c.owner && !c.lair && !c.boss)!.cell;
    const first = await t.call("POST", "/world/expeditions", { to: next, count: 10, settle: true }, a); // (not ours yet: a normal walk)
    const slow = Date.parse(first.body.arriveAt) - Date.parse(first.body.setOutAt);
    t.advance(slow + 1000);
    expect((await me(a)).cells.map((c) => c.cell)).toContain(next);
    const second = await t.call("POST", "/world/expeditions", { to: next, count: 10 }, a); // (ours now, and joined to the camp)
    expect(second.status).toBe(201);
    const quick = Date.parse(second.body.arriveAt) - Date.parse(second.body.setOutAt);
    expect(quick).toBeLessThanOrEqual(Math.max(60_000, slow * 0.4));
  });

  it("parties go round other camps' built-up land, and cannot go where it walls them out (not a friend's)", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    const c = await account("c@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    await t.call("POST", "/world/open", { cell: cellAt({ lat: 25.045, lng: 121.55 }) }, c);
    await veteran("b@example.com");
    // a free cell 1 km west of b, walled in all round by two rings of a's town cells
    const target = cellAt({ lat: 25.0336, lng: 121.555 });
    const ring = new Set(neighbors(target));
    for (const n of [...ring]) for (const m of neighbors(n)) if (m !== target) ring.add(m);
    const id = async (email: string) => (await database.sql`select id from users where email = ${email}`)[0]!.id as string;
    const aId = await id("a@example.com");
    for (const cell of ring) await database.sql`insert into world_cells (cell, owner, town) values (${cell}, ${aId}, true) on conflict (cell) do update set owner = ${aId}, town = true`;
    const route = async (auth: Record<string, string>) => (await t.call("POST", "/world/expeditions/route", { to: target }, auth)).body as RoutePreview;

    // the map shows b the wall (and not a, whose land it is)
    expect((await map(b, cellCenter(target), 600)).filter((c) => c.blocks).length).toBe(ring.size);
    expect((await map(a, cellCenter(target), 600)).some((c) => c.blocks)).toBe(false);
    // b cannot get there: told whose land is in the way
    const shut = await route(b);
    expect(shut.waypoints).toEqual([]);
    expect(shut.blockedBy?.name).toBeTruthy();
    const refused = await t.call("POST", "/world/expeditions", { to: target, count: 5, settle: true }, b);
    expect(refused.status).toBe(409);
    expect(refused.body.error).toBe("no_way");
    // a's own land does not stand in a's way, nor a friend's in the friend's
    expect((await route(a)).waypoints.length).toBeGreaterThanOrEqual(2);
    const cId = await id("c@example.com");
    const [x, y] = aId < cId ? [aId, cId] : [cId, aId];
    await database.sql`insert into friendships (user_a, user_b, asked_by, created_at, accepted_at) values (${x}, ${y}, ${aId}, now(), now())`;
    expect((await route(c)).waypoints.length).toBeGreaterThanOrEqual(2);

    // the northern side opened (bare cells: walked over): b goes round, longer than straight, and the party walks that way
    for (const cell of ring) if (cellCenter(cell).lat > cellCenter(target).lat + 0.0002) await database.sql`update world_cells set town = false where cell = ${cell}`;
    const round = await route(b);
    expect(round.waypoints.length).toBeGreaterThan(2);
    expect(round.meters).toBeGreaterThan(round.straight);
    const sent = await t.call("POST", "/world/expeditions", { to: target, count: 5, settle: true }, b);
    expect(sent.status).toBe(201);
    expect(sent.body.route).toEqual(round.waypoints);
    expect((await me(b)).walking[0]!.route).toEqual(round.waypoints);
  });

  it("a new world gives the cells up", async () => {
    const a = await account("a@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN), settlers: 5 }, a);
    await t.call("POST", "/camp/new-world", { race: "elf" }, a);
    const w = await me(a);
    expect(w.open).toBe(false);
    expect(w.cells).toHaveLength(0);
    const cell = (await map(a, cellCenter(cellAt(DAAN)), 300)).find((c) => c.cell === cellAt(DAAN))!;
    expect(cell.owner).toBeNull();
  });
});

describe("the world's great monsters (世界魔王)", () => {
  // (off for a start: this turns them on for these tests)
  beforeAll(() => void (process.env.WORLD_BOSSES = "on"));
  afterAll(() => void delete process.env.WORLD_BOSSES);
  /** A boss standing near 大安 right now, and a free cell beside it for a camp. */
  function bossNear(): { cell: string; name: string; beside: string } {
    const now = t.now().getTime();
    const regions = [...new Set(cellsWithin(DAAN, 20_000).map(regionOf))];
    for (const r of regions) {
      const b = bossIn(WORLD_SEED, r, bossWindow(now));
      if (b) return { cell: b.cell, name: b.name, beside: neighbors(b.cell)[0]! };
    }
    throw new Error("no boss near");
  }

  it("let in only camps at race level 50", async () => {
    const a = await account("a@example.com");
    await grow(a);
    const boss = bossNear();
    await t.call("POST", "/world/open", { cell: boss.beside, settlers: 5 }, a);
    await veteran("a@example.com"); // (level 20)
    const res = await t.call("POST", "/world/expeditions", { to: boss.cell, count: 10 }, a);
    expect(res.body.error).toBe("level");
    expect(res.body.message).toContain("50");
    await legend("a@example.com");
    expect((await t.call("POST", "/world/expeditions", { to: boss.cell, count: 10 }, a)).status).toBe(201);
  });

  it("keep their wounds between parties, and share the spoils with everyone who hurt them", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    const boss = bossNear();
    await t.call("POST", "/world/open", { cell: boss.beside, settlers: 5 }, a);
    await t.call("POST", "/world/open", { cell: neighbors(boss.cell)[3]!, settlers: 5 }, b);
    await legend("a@example.com"); // (the great monsters wait for race level 50)
    await legend("b@example.com");
    const seen = (await map(a, cellCenter(boss.cell), 300)).find((c) => c.cell === boss.cell)!;
    expect(seen.boss?.name).toBe(boss.name);
    expect(seen.boss?.hp).toBe(seen.boss?.maxHp);
    expect(seen.lair).toBeNull();

    // a's party gets its onslaught in: it hurts it, and does not beat it
    let res = await t.call("POST", "/world/expeditions", { to: boss.cell, count: 25 }, a);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const first = (await me(a)).recent[0]!;
    expect(first.outcome?.cell).toBe("held");
    expect(first.outcome?.damage).toBeGreaterThan(0);
    const hurt = (await map(a, cellCenter(boss.cell), 300)).find((c) => c.cell === boss.cell)!.boss!;
    expect(hurt.hp).toBe(hurt.maxHp - first.outcome!.damage!);
    expect(hurt.fighters[0]?.damage).toBe(first.outcome!.damage);

    // b finishes it off (worn down to almost nothing meanwhile)
    await database.sql`update world_bosses set hp = 5`;
    const xpA = (await me(a)).xp;
    res = await t.call("POST", "/world/expeditions", { to: boss.cell, count: 20 }, b);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const last = (await me(b)).recent[0]!;
    expect(last.outcome?.won).toBe(true);
    expect(last.outcome?.cell).toBe("cleared");
    const report = (await t.call("GET", `/world/expeditions/${last.id}`, undefined, b)).body as ExpeditionReport;
    expect(report.boss?.defeated).toBe(true);
    expect(report.fighters.find((f) => f.id === "boss")?.hp).toBe(5);
    // both get their share (a did far more)
    const wa = await me(a);
    expect(wa.xp).toBeGreaterThan(xpA);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, a)).body.events as { kind: string; data: { bossReward?: { loot: Record<string, number> } } }[];
    const reward = events.find((e) => e.data.bossReward)?.data.bossReward;
    expect(reward).toBeDefined();
    const campA = await camp(a);
    for (const [mat, n] of Object.entries(reward!.loot)) expect(campA.materials[mat] ?? 0).toBeGreaterThanOrEqual(n);
    expect((await me(b)).xp).toBeGreaterThan(0);
    // and it is gone from the map
    expect((await map(a, cellCenter(boss.cell), 300)).find((c) => c.cell === boss.cell)!.boss).toBeNull();
  });
});

describe("出征的人數、糧食與巢穴的傷（WORLD.md §19）", () => {
  async function fresh(email = "a@example.com") {
    const a = await account(email);
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    return a;
  }
  const strongest = async (a: Record<string, string>) =>
    // (an ordinary lair: not the mid ones behind a race level, WORLD.md §26)
    (await map(a, DAAN, 1500)).filter((c) => c.lair && !c.boss && c.cell !== cellAt(DAAN) && LAIRS.find((k) => k.id === c.lair!.kind)?.tier === 1).sort((x, y) => y.lair!.power - x.lair!.power)[0]!;

  it("a party is small at first; rations let more go and are eaten; boost food too; the farm grows food", async () => {
    const a = await fresh();
    let w = await me(a);
    expect(w.partyCap).toBe(6); // (goblins at level 1)
    expect(w.food.ration_bread).toBe(5); // (given on opening)
    const target = (await map(a, DAAN, 1500)).find((c) => c.lair && c.cell !== cellAt(DAAN))!;
    let res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 7 }, a);
    expect(res.status).toBe(409);
    expect(res.body.message).toContain("乾糧");
    res = await t.call("POST", "/world/expeditions", { to: target.cell, count: 8, supplies: { ration_bread: 4 } }, a);
    expect(res.status).toBe(201);
    w = await me(a);
    expect(w.food.ration_bread).toBe(1);
    // honey that is not in the store
    expect((await t.call("POST", "/world/expeditions", { to: target.cell, count: 3, supplies: { food_honey: 1 } }, a)).status).toBe(409);
    // no more free bread: a new camp's farm grows carrots (one every 3 hours), bread only from level 2
    t.advance(30 * HOUR);
    const food = (await me(a)).food;
    expect(food.ration_bread).toBe(1);
    expect(food.food_carrot).toBeGreaterThanOrEqual(Math.min(20, (w.food.food_carrot ?? 0) + 10));
  });

  it("a lair that beats a party keeps its wounds, heals them, and a second wave meets it weaker", async () => {
    const a = await fresh();
    const lair = await strongest(a);
    const res = await t.call("POST", "/world/expeditions", { to: lair.cell, count: 6 }, a);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, a)).body as ExpeditionReport;
    expect(report.outcome?.won).toBe(false); // (six plain goblins against the strongest lair around)
    const hurt = (await map(a, DAAN, 1500)).find((c) => c.cell === lair.cell)!;
    expect(hurt.lairWounds).toBeTruthy();
    expect(hurt.lairWounds!.hpShare).toBeLessThan(1);
    expect(hurt.lair!.power).toBeLessThan(lair.lair!.power);
    // healed again in a while
    t.advance(3 * HOUR);
    const whole = (await map(a, DAAN, 1500)).find((c) => c.cell === lair.cell)!;
    expect(whole.lairWounds).toBeNull();
    expect(whole.lair!.power).toBe(lair.lair!.power);
  });
});

describe("聖光模式（CAMP.md §7）", () => {
  it("no raids, nobody attacks it, births at half speed above 120; off any time, on again 12 hours after", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    await veteran("b@example.com");
    const before = await camp(a);
    const other = await camp(b);
    expect(before.residents.length).toBeGreaterThanOrEqual(120);
    const on = await t.call("POST", "/camp/sanctuary", { on: true }, a);
    expect(on.status).toBe(200);
    expect((on.body as CampView).sanctuary.since).not.toBeNull();
    const raidsBefore = ((await t.call("GET", "/camp/raids?limit=50", undefined, a)).body.raids as unknown[]).length;

    // six hours: no raid; about half the births of a camp without it
    t.advance(6 * HOUR);
    const after = await camp(a);
    const otherAfter = await camp(b);
    expect(((await t.call("GET", "/camp/raids?limit=50", undefined, a)).body.raids as unknown[]).length).toBe(raidsBefore);
    const born = after.nextId - before.nextId;
    const bornElsewhere = otherAfter.nextId - other.nextId;
    expect(born).toBeGreaterThan(0);
    expect(born).toBeLessThan(bornElsewhere * 0.65);

    // nobody attacks it, and it attacks nobody
    const res = await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 5 }, b);
    expect(res.status).toBe(409);
    expect(res.body.error).toBe("target_sanctuary");

    // off, and not on again for 12 hours
    expect(((await t.call("POST", "/camp/sanctuary", { on: false }, a)).body as CampView).sanctuary.since).toBeNull();
    expect((await t.call("POST", "/camp/sanctuary", { on: true }, a)).status).toBe(409);
    t.advance(12 * HOUR + 1000);
    expect((await t.call("POST", "/camp/sanctuary", { on: true }, a)).status).toBe(200);
  });
});

describe("a garrison overrun falls back", () => {
  /** b's residents all in the best gear there is (a one-handed weapon and a shield), so a small party of b's wins. */
  async function arm(email: string) {
    const best = (slot: string) => GEAR.filter((g) => g.slot === slot && !g.twoHanded).sort((x, y) => gearPower({ id: y.id, left: y.durability }) - gearPower({ id: x.id, left: x.durability }))[0]!;
    const gear = Object.fromEntries(GEAR_SLOTS.map((slot) => [slot, { id: best(slot).id, left: best(slot).durability }]));
    await database.sql`update camp_residents set gear = ${JSON.stringify(gear)}::jsonb where user_id = (select id from users where email = ${email})`;
  }
  /** a at Daan with `cells` settled cells (`count` each), b at Xinyi armed; returns a's cells, nearest first. */
  async function setUp(cells: number[]) {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    await grow(b);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    await veteran("a@example.com");
    await veteran("b@example.com");
    const taken: string[] = [];
    for (const count of cells) {
      // (a free cell with free cells round it, so there is somewhere to fall back to)
      const free = (await map(a, DAAN, 900)).find((c) => !c.owner && !c.lair && !c.boss && c.cell !== cellAt(DAAN) && !taken.some((x) => neighbors(x).includes(c.cell)) && !neighbors(cellAt(DAAN)).includes(c.cell))!.cell;
      const res = await t.call("POST", "/world/expeditions", { to: free, count, settle: true }, a);
      expect(res.status).toBe(201);
      t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
      expect((await me(a)).cells.map((c) => c.cell)).toContain(free); // (looking settles the party's arrival)
      taken.push(free);
    }
    await arm("b@example.com");
    return { a, b, cells: taken };
  }
  async function overrun(b: Record<string, string>, cell: string) {
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 6 }, b);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const fight = (await me(b)).recent[0]!;
    expect(fight.outcome?.won).toBe(true);
  }

  it("walks to the camp's nearest held cell with room", async () => {
    const { a, b, cells } = await setUp([25, 5]);
    await overrun(b, cells[0]!);
    const wa = await me(a);
    expect(wa.cells.map((c) => c.cell)).not.toContain(cells[0]);
    const going = wa.walking.find((w) => w.from === cells[0])!;
    expect(going.kind).toBe("recall");
    expect(going.to).toBe(cells[1]);
    // the report says where it was, and where they went
    const report = wa.recent.find((r) => r.defending)!;
    expect(report.by).toBeTruthy();
    expect(report.outcome?.where).toMatchObject({ kind: "cell", label: "領地 1" });
    expect(report.outcome?.fled).toMatchObject({ how: "cell", label: "領地 2", count: going.party });
    const full = (await t.call("GET", `/world/expeditions/${report.id}`, undefined, a)).body as ExpeditionReport;
    expect(full.to).toBe(cells[0]);
    expect(full.outcome?.where?.label).toBe("領地 1");
    expect(going.party).toBeGreaterThanOrEqual(16); // (nine stood up to six; the rest fled)
    expect((await camp(a)).residents.some((r) => r.place === `cell:${cells[0]}`)).toBe(false);
    t.advance(Date.parse(going.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).cells.find((c) => c.cell === cells[1])!.garrison).toBe(5 + going.party);
  });

  it("with no held cell to go to, settles a free cell beside it", async () => {
    const { a, b, cells } = await setUp([25]);
    await overrun(b, cells[0]!);
    const going = (await me(a)).walking.find((w) => w.from === cells[0])!;
    expect(going.kind).toBe("retreat");
    expect(neighbors(cells[0]!)).toContain(going.to);
    t.advance(Date.parse(going.arriveAt) - t.now().getTime() + 1000);
    const wa = await me(a);
    expect(wa.cells.find((c) => c.cell === going.to)?.garrison).toBe(going.party);
    expect(wa.recent.find((r) => r.id === going.id)?.outcome?.cell).toBe("settled");
  });

  it("turtles at most a day after losing, then is in the world again by itself", async () => {
    const { a, b, cells } = await setUp([25]);
    await overrun(b, cells[0]!);
    let wa = await me(a);
    expect(wa.shielded).toBe(true);
    expect(Date.parse(wa.shieldEndsAt!) - t.now().getTime()).toBeGreaterThan(23 * HOUR);
    // b cannot attack a turtling camp
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 6 }, b)).body.error).toBe("target_shielded");
    t.advance(24 * HOUR);
    wa = await me(a);
    expect(wa.shielded).toBe(false);
    expect(wa.open).toBe(true);
    expect(wa.shieldEndsAt).toBeNull();
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 6 }, b)).status).toBe(201);
  });

  it("is warned the moment a party sets out against it", async () => {
    const { a, b, cells } = await setUp([25]);
    const res = await t.call("POST", "/world/expeditions", { to: cells[0], count: 6 }, b);
    expect(res.status).toBe(201);
    const coming = (await me(a)).incoming!;
    expect(coming).toHaveLength(1);
    expect(coming[0]).toMatchObject({ id: res.body.id, to: cells[0], party: 6, where: { kind: "cell", label: "領地 1" }, arriveAt: res.body.arriveAt });
    expect(coming[0]!.by.name).toBeTruthy();
    const events = (await t.call("GET", "/camp/events?since=0", undefined, a)).body.events as { kind: string; data: { incoming?: boolean; where?: string } }[];
    expect(events.some((e) => e.kind === "expedition" && e.data.incoming && e.data.where === "領地 1")).toBe(true);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).incoming).toHaveLength(0); // (it got there)
  });

  it("wears the fighters' gear down, at half a raid's rate", async () => {
    const { b, cells } = await setUp([25]);
    const full = new Map(GEAR.map((g) => [g.id, g.durability]));
    await overrun(b, cells[0]!);
    const worn = (await camp(b)).residents.flatMap((r) => Object.values(r.gear ?? {})).filter((g) => g.left < full.get(g.id)!);
    expect(worn.length).toBeGreaterThan(0);
    // (half a point a blow or a hit: a short fight takes only a little off)
    expect(worn.every((g) => g.left > full.get(g.id)! - 20)).toBe(true);
  });

  it("too few to hold a cell, walks home", async () => {
    const { a, b, cells } = await setUp([12]);
    const atHome = (await me(a)).atHome;
    await overrun(b, cells[0]!);
    const going = (await me(a)).walking.find((w) => w.from === cells[0])!;
    expect(going.kind).toBe("recall");
    expect(going.to).toBe(cellAt(DAAN));
    expect(going.party).toBeLessThan(5);
    t.advance(Date.parse(going.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).atHome).toBeGreaterThanOrEqual(atHome + going.party);
  });
});

describe("種族天賦", () => {
  async function opened(email = "a@example.com") {
    const a = await account(email);
    await grow(a);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, a);
    await veteran(email); // (race level 20: 19 points)
    return a;
  }
  const learn = (auth: Record<string, string>, picks: Record<string, number>) => t.call("POST", "/world/talents", { picks }, auth);

  it("buys talents with the race level's points, takes none back, and resets for more and more", async () => {
    const a = await opened();
    let w = await me(a);
    expect(w.talents).toMatchObject({ points: 19, picks: {}, resets: 0, resetCost: { crystal_shard: 15, amber: 4 } });
    expect((await learn(a, { "e_ranger.swift": 1 })).body.error).toBe("not_allowed"); // (an elf's: a goblin camp)
    let res = await learn(a, { "g_raid.sharp": 3, "g_raid.greed": 1, "g_raid.warband": 3 });
    expect(res.status).toBe(200);
    w = res.body as WorldMe;
    expect(w.talents!.picks).toEqual({ "g_raid.sharp": 3, "g_raid.greed": 1, "g_raid.warband": 3 });
    expect(w.partyCap).toBe((await me(a)).partyCap); // (the answer is the new standing)
    expect((await learn(a, { "g_raid.sharp": 2, "g_raid.greed": 1, "g_raid.warband": 3 })).body.message).toContain("重置");
    // reset: costs crystal shards and amber, more the next time
    expect((await t.call("POST", "/world/talents/reset", {}, a)).body.error).toBe("cannot_afford");
    await database.sql`update camps set materials = materials || '{"crystal_shard": 100, "amber": 100}'::jsonb`;
    res = await t.call("POST", "/world/talents/reset", {}, a);
    expect(res.status).toBe(200);
    w = res.body as WorldMe;
    expect(w.talents).toMatchObject({ picks: {}, resets: 1, resetCost: { crystal_shard: 30, amber: 8 } });
    expect((await camp(a)).materials).toMatchObject({ crystal_shard: 85, amber: 96 });
  });

  it("works where the big world works: more go, they walk quicker, more cells eat nothing", async () => {
    const a = await opened();
    const before = await me(a);
    expect(before.freeCells).toBe(3 + 5); // (3, and one every 4 levels: level 20)
    const raid = { "g_raid.sharp": 3, "g_raid.greed": 1, "g_raid.warband": 3 };
    const horde = { "g_horde.breed": 3, "g_horde.crowd": 1, "g_horde.share": 3 };
    expect((await learn(a, { ...raid, ...horde })).status).toBe(200);
    expect((await me(a)).partyCap).toBe(Math.min(30, before.partyCap + 3));
    // 到處都是 (row 2, needs 分著吃 maxed): two more cells without upkeep
    expect((await learn(a, { ...raid, ...horde, "g_horde.callout": 3, "g_horde.sprawl": 2 })).status).toBe(200);
    expect((await me(a)).freeCells).toBe(3 + 5 + 2);
  });

  it("lets an elf's 遊俠 walk quicker, and an undead camp's 低語 see what is coming", async () => {
    const e = await account("e@example.com", "elf");
    t.advance(40 * HOUR); // (elves come slower: enough to open the big world)
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, e);
    await veteran("e@example.com");
    const target = (await map(e, DAAN, 900)).find((c) => !c.owner && !c.lair && !c.boss && c.cell !== cellAt(DAAN))!.cell;
    const slow = await t.call("POST", "/world/expeditions/route", { to: target }, e);
    expect(slow.status).toBe(200);
    const plain = await t.call("POST", "/world/expeditions", { to: target, count: 5 }, e);
    const plainMinutes = Date.parse(plain.body.arriveAt) - Date.parse(plain.body.setOutAt);
    t.advance(plainMinutes + 1000);
    await me(e);
    // every 遊俠 talent for walking, then 鷹眼 at the top
    const res = await t.call("POST", "/world/talents", { picks: { "e_ranger.swift": 3, "e_ranger.aim": 1, "e_ranger.paths": 3, "e_ranger.hunter": 3, "e_ranger.wind": 2, "e_ranger.trophy": 1, "e_ranger.volley": 3 } }, e);
    expect(res.body.message ?? "").toBe("");
    const quick = await t.call("POST", "/world/expeditions", { to: target, count: 5 }, e);
    const quickMinutes = Date.parse(quick.body.arriveAt) - Date.parse(quick.body.setOutAt);
    expect(quickMinutes).toBeLessThan(plainMinutes); // (−12%)

    // an undead camp with 低語 (恐懼, row 4): a goblin camp sets out against it, and it sees what the party is made of
    const u = await account("u@example.com", "undead");
    t.advance(30 * HOUR);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, u);
    await veteran("u@example.com");
    const dread = { "u_dread.terror": 3, "u_dread.shroud": 1, "u_dread.siege": 3, "u_dread.haunt": 3, "u_dread.despair": 2, "u_dread.whispers": 1 };
    expect((await t.call("POST", "/world/talents", { picks: dread }, u)).body.message ?? "").toBe("");
    const g = await account("g@example.com");
    await grow(g);
    await t.call("POST", "/world/open", { cell: cellAt({ lat: 25.04, lng: 121.56 }) }, g);
    await veteran("g@example.com");
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(XINYI), count: 6 }, g)).status).toBe(201);
    const coming = (await me(u)).incoming![0]!;
    expect(Object.values(coming.breeds ?? {}).reduce((n, k) => n + k, 0)).toBe(6);
  });
});

describe("天賦樹頂端的新能力", () => {
  /** A camp of `race` at `at`, race level 20, with these talents. */
  async function withTalents(email: string, race: string, at: { lat: number; lng: number }, picks: Record<string, number>) {
    const a = await account(email, race);
    t.advance(40 * HOUR);
    expect((await t.call("POST", "/world/open", { cell: cellAt(at) }, a)).status).toBe(201);
    await veteran(email);
    const res = await t.call("POST", "/world/talents", { picks }, a);
    expect(res.body.message ?? "").toBe("");
    return a;
  }
  const id = async (email: string) => (await database.sql`select id from users where email = ${email}`)[0]!.id as string;
  const HORDE = { "g_horde.breed": 3, "g_horde.crowd": 2, "g_horde.callout": 3, "g_horde.share": 3, "g_horde.swarm": 2, "g_horde.warren": 3, "g_horde.tunnels": 1 };
  const ELDER = { "e_elder.lore": 3, "e_elder.trade": 2, "e_elder.frugal": 3, "e_elder.ward": 3, "e_elder.stewards": 2, "e_elder.council": 3, "e_elder.moongate": 1 };
  const DREAD = { "u_dread.terror": 3, "u_dread.shroud": 3, "u_dread.siege": 3, "u_dread.haunt": 3, "u_dread.despair": 2, "u_dread.crypts": 1, "u_dread.whispers": 1, "u_dread.nightraid": 1 };
  const CRYPT = { "u_crypt.fasting": 3, "u_crypt.salvage": 2, "u_crypt.ossuary": 3, "u_crypt.embalm": 3, "u_crypt.necropolis": 2, "u_crypt.tomes": 3, "u_crypt.blight": 1 };

  it("地道: others' walls are none to it, but a town's", async () => {
    const b = await account("b@example.com");
    await grow(b);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    const a = await withTalents("a@example.com", "goblin", DAAN, {});
    const wall = neighbors(neighbors(cellAt(DAAN))[0]!)[0]!;
    const town = neighbors(neighbors(cellAt(DAAN))[3]!)[3]!;
    await database.sql`insert into world_cells (cell, owner, nest_started_at) values (${wall}, ${await id("b@example.com")}, now()) on conflict (cell) do update set owner = excluded.owner, nest_started_at = now()`;
    await database.sql`insert into world_cells (cell, owner, town) values (${town}, ${await id("b@example.com")}, true) on conflict (cell) do update set owner = excluded.owner, town = true`;
    expect((await map(a, cellCenter(wall), 300)).find((c) => c.cell === wall)!.blocks).toBe(true);
    expect((await t.call("POST", "/world/talents", { picks: HORDE }, a)).status).toBe(200);
    expect((await map(a, cellCenter(wall), 300)).find((c) => c.cell === wall)!.blocks).toBeFalsy();
    expect((await map(a, cellCenter(town), 300)).find((c) => c.cell === town)!.blocks).toBe(true); // (反制)
  });

  it("月光傳送: once a day, a party moves between its towns at once", async () => {
    const e = await withTalents("e@example.com", "elf", DAAN, ELDER);
    const me_ = await id("e@example.com");
    const [x, y] = [neighbors(neighbors(cellAt(DAAN))[2]!)[2]!, neighbors(neighbors(cellAt(DAAN))[5]!)[5]!];
    for (const c of [x, y]) await database.sql`insert into world_cells (cell, owner, town, held_since) values (${c}, ${me_}, true, now()) on conflict (cell) do update set owner = excluded.owner, town = true`;
    await database.sql`update camp_residents set place = ${`cell:${x}`} where user_id = ${me_} and id in (select id from camp_residents where user_id = ${me_} and place = 'home' limit 20)`;
    await database.sql`update camp_residents set place = ${`cell:${y}`} where user_id = ${me_} and id in (select id from camp_residents where user_id = ${me_} and place = 'home' limit 6)`; // (a cell nobody lives on is given up)
    expect((await me(e)).moonGatesLeft).toBe(1);
    const first = await t.call("POST", "/world/expeditions", { from: x, to: y, count: 5 }, e);
    expect(first.status).toBe(201);
    expect(Date.parse(first.body.arriveAt) - Date.parse(first.body.setOutAt)).toBe(MIN);
    expect((await me(e)).moonGatesLeft).toBe(0);
    const second = await t.call("POST", "/world/expeditions", { from: x, to: y, count: 5 }, e);
    expect(Date.parse(second.body.arriveAt) - Date.parse(second.body.setOutAt)).toBeGreaterThan(MIN);
  });

  it("夜襲: setting out at night, the camp it goes for is not warned", async () => {
    const g = await account("g@example.com");
    await grow(g);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, g);
    const u = await withTalents("u@example.com", "undead", XINYI, DREAD);
    // to 22:00 where the undead camp stands (Taipei: UTC+8, by the longitude)
    const now = t.now();
    const local = (now.getUTCHours() + 8 + 24) % 24;
    t.advance((((22 - local + 24) % 24) * 60 - now.getUTCMinutes()) * MIN);
    const res = await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 6 }, u);
    expect(res.status).toBe(201);
    expect((await me(g)).incoming).toHaveLength(0);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, g)).body.events as { data: { incoming?: boolean } }[];
    expect(events.some((e) => e.data.incoming)).toBe(false);
    // 反制: a 瞭望塔 in the region attacked sees the next one coming
    const tower = neighbors(cellAt(DAAN))[0]!;
    await database.sql`insert into world_cells (cell, owner, held_since, building) values (${tower}, ${await id("g@example.com")}, now(), '{"kind": "watchtower", "level": 1}'::jsonb) on conflict (cell) do update set owner = excluded.owner, building = excluded.building`;
    await database.sql`update camp_residents set place = ${`cell:${tower}`} where user_id = ${await id("g@example.com")} and id in (select id from camp_residents where user_id = ${await id("g@example.com")} and place = 'home' limit 3)`;
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 6 }, u)).status).toBe(201);
    expect((await me(g)).incoming).toHaveLength(1);
  });

  const RANGER = { "e_ranger.swift": 3, "e_ranger.aim": 1, "e_ranger.paths": 3, "e_ranger.hunter": 3, "e_ranger.wind": 2, "e_ranger.trophy": 1, "e_ranger.volley": 3, "e_ranger.ambush": 1 };
  const LEGION = { "u_legion.rise": 3, "u_legion.bones": 2, "u_legion.march": 3, "u_legion.graves": 3, "u_legion.horde": 2, "u_legion.tide": 3, "u_legion.raise": 1 };
  const RAID = { "g_raid.sharp": 3, "g_raid.greed": 3, "g_raid.warband": 3, "g_raid.ambush": 2, "g_raid.pillage": 2, "g_raid.warpaint": 3, "g_raid.plunder": 1 };

  it("伏擊: a party walking past its cells is shot at first", async () => {
    const e = await withTalents("e@example.com", "elf", DAAN, RANGER);
    expect(e).toBeTruthy();
    const g = await account("g@example.com");
    await grow(g);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, g);
    await veteran("g@example.com");
    const res = await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 20 }, g);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, g)).body as ExpeditionReport;
    expect(report.outcome!.ambushed![0]!.fallen).toBeGreaterThan(0);
    expect(report.party - report.outcome!.ambushed![0]!.fallen).toBeGreaterThan(0); // (somebody always gets there)
  });

  it("伏擊 shows on the map, and those with a shield are not shot (反制)", async () => {
    await withTalents("e@example.com", "elf", DAAN, RANGER);
    const g = await account("g@example.com");
    await grow(g);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, g);
    await veteran("g@example.com");
    const around = await map(g, DAAN, 300);
    expect(around.find((c) => c.cell === neighbors(cellAt(DAAN))[0])!.threats).toContain("ambush");
    await database.sql`update camp_residents set gear = '{"shield": {"id": "wood_shield", "left": 18}}'::jsonb where user_id = ${await id("g@example.com")}`;
    const res = await t.call("POST", "/world/expeditions", { to: cellAt(DAAN), count: 20 }, g);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, g)).body as ExpeditionReport;
    expect(report.outcome!.ambushed ?? []).toHaveLength(0);
  });

  it("戰場復甦: some of the fallen of a won fight rise and join", async () => {
    const u = await withTalents("u@example.com", "undead", DAAN, LEGION);
    const lair = (await map(u, DAAN, 1000)).filter((c) => c.lair && !c.lair.boss && !c.lair.minRaceLevel && c.cell !== cellAt(DAAN)).sort((x, y) => x.lair!.power - y.lair!.power)[0]!;
    const res = await t.call("POST", "/world/expeditions", { to: lair.cell, count: 25 }, u);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, u)).body as ExpeditionReport;
    expect(report.outcome!.won).toBe(true);
    expect(report.outcome!.raised).toBeGreaterThan(0);
    // (those who rose were born the moment the party got there; the camp's own births and deaths go on meanwhile)
    const risen = (await camp(u)).residents.filter((r) => Date.parse(r.bornAt) === Date.parse(report.arriveAt));
    expect(risen.length).toBeGreaterThanOrEqual(report.outcome!.raised!);
  });

  it("劫掠: takes from the store and leaves; the cell stays, nobody turtles", async () => {
    const b = await account("b@example.com");
    await grow(b);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    const g = await withTalents("g@example.com", "goblin", DAAN, RAID);
    const cell = neighbors(neighbors(cellAt(XINYI))[3]!)[3]!;
    const bId = await id("b@example.com");
    await database.sql`insert into world_cells (cell, owner, held_since) values (${cell}, ${bId}, now()) on conflict (cell) do update set owner = excluded.owner`;
    await database.sql`update camp_residents set place = ${`cell:${cell}`} where user_id = ${bId} and id in (select id from camp_residents where user_id = ${bId} and place = 'home' limit 5)`;
    await database.sql`update camps set materials = '{"rat_fang": 100, "log": 1000}'::jsonb where user_id = ${bId}`;
    expect((await t.call("POST", "/world/expeditions", { to: cell, count: 5, plunder: true }, b)).status).toBeGreaterThanOrEqual(400); // (not one's own)
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 25, plunder: true }, g);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, g)).body as ExpeditionReport;
    expect(report.outcome!.cell).toBe("plundered");
    // (8% of each, up to 10 of each and 60 in all: the camp's store grew a little on the way from its raids and sites)
    expect(report.outcome!.loot.log).toBe(10);
    expect(report.outcome!.loot.rat_fang).toBeGreaterThanOrEqual(8);
    expect(Object.values(report.outcome!.loot).reduce((a, b) => a + b, 0)).toBeLessThanOrEqual(60);
    expect((await camp(g)).materials.log).toBeGreaterThanOrEqual(10);
    expect((await me(g)).cells.map((c) => c.cell)).not.toContain(cell); // (it takes and leaves: the cell is not the raider's)
    expect((await me(b)).shielded).toBe(false); // (a raid is no defeat)
    // not again for 6 hours, by anybody (its camp itself, now: the cell was left with nobody)
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(XINYI), count: 5, plunder: true }, g)).body.error).toBe("plundered_lately");
    t.advance(6 * HOUR);
    expect((await t.call("POST", "/world/expeditions", { to: cellAt(XINYI), count: 5, plunder: true }, g)).status).toBe(201);
  });

  it("劫掠 a town takes half as much; 戰場復甦 does not raise the fallen of a cell with a 營火廣場 (反制)", async () => {
    const b = await account("b@example.com");
    await grow(b);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    const bId = await id("b@example.com");
    const g = await withTalents("g@example.com", "goblin", DAAN, RAID);
    const u = await withTalents("u@example.com", "undead", { lat: DAAN.lat + 0.004, lng: DAAN.lng }, LEGION);
    const town = neighbors(neighbors(cellAt(XINYI))[3]!)[3]!;
    const fire = (await map(b, XINYI, 400)).find((c) => !c.owner && !c.lair && !c.boss && c.cell !== town && !neighbors(cellAt(XINYI)).includes(c.cell) && c.cell !== cellAt(XINYI))!.cell; // (no lair under it)
    await database.sql`insert into world_cells (cell, owner, held_since, town) values (${town}, ${bId}, now(), true) on conflict (cell) do update set owner = excluded.owner, town = true`;
    await database.sql`insert into world_cells (cell, owner, held_since, building) values (${fire}, ${bId}, now(), '{"kind": "campfire", "level": 1}'::jsonb) on conflict (cell) do update set owner = excluded.owner, building = excluded.building`;
    for (const c of [town, fire]) await database.sql`update camp_residents set place = ${`cell:${c}`} where user_id = ${bId} and id in (select id from camp_residents where user_id = ${bId} and place = 'home' limit 4)`;
    await database.sql`update camps set materials = '{"log": 1000}'::jsonb where user_id = ${bId}`;
    const home = (await camp(g)).residents.filter((r) => r.place === "home").length;
    const raid = await t.call("POST", "/world/expeditions", { to: town, count: Math.min(25, home - 2), plunder: true }, g);
    const take = await t.call("POST", "/world/expeditions", { to: fire, count: 25 }, u);
    expect([raid.status, raid.body.message, take.status]).toEqual([201, undefined, 201]);
    t.advance(Math.max(Date.parse(raid.body.arriveAt), Date.parse(take.body.arriveAt)) - t.now().getTime() + 1000);
    const raided = (await t.call("GET", `/world/expeditions/${raid.body.id}`, undefined, g)).body as ExpeditionReport;
    expect(raided.outcome!.cell).toBe("plundered");
    expect(raided.outcome!.loot.log).toBe(5);
    const taken = (await t.call("GET", `/world/expeditions/${take.body.id}`, undefined, u)).body as ExpeditionReport;
    expect(taken.outcome!.won).toBe(true);
    expect(taken.outcome!.raised ?? 0).toBe(0);
  });

  it("腐化大地: others' cells next to its own yield less", async () => {
    const u = await withTalents("u@example.com", "undead", DAAN, CRYPT);
    expect(u).toBeTruthy();
    const b = await account("b@example.com");
    await grow(b);
    await t.call("POST", "/world/open", { cell: cellAt(XINYI) }, b);
    const next = neighbors(cellAt(DAAN))[1]!;
    await database.sql`insert into world_cells (cell, owner, held_since) values (${next}, ${await id("b@example.com")}, now()) on conflict (cell) do update set owner = excluded.owner`;
    const far = neighbors(cellAt(XINYI))[1]!;
    await database.sql`insert into world_cells (cell, owner, held_since) values (${far}, ${await id("b@example.com")}, now()) on conflict (cell) do update set owner = excluded.owner`;
    for (const c of [next, far]) await database.sql`update camp_residents set place = ${`cell:${c}`} where user_id = ${await id("b@example.com")} and id in (select id from camp_residents where user_id = ${await id("b@example.com")} and place = 'home' limit 6)`;
    expect((await t.call("GET", `/world/cells/${next}`, undefined, b)).body.blighted).toBe(true);
    expect((await t.call("GET", `/world/cells/${far}`, undefined, b)).body.blighted).toBeFalsy();
    expect((await map(b, DAAN, 300)).find((c) => c.cell === neighbors(cellAt(DAAN))[2])!.threats).toContain("blight");
    // 反制: a 聖樹 in the region, or a town, is not blighted
    await database.sql`update world_cells set building = '{"kind": "sacred", "level": 1}'::jsonb where cell = ${next}`;
    expect((await t.call("GET", `/world/cells/${next}`, undefined, b)).body.blighted).toBeFalsy();
    await database.sql`update world_cells set building = null, town = true where cell = ${next}`;
    expect((await t.call("GET", `/world/cells/${next}`, undefined, b)).body.blighted).toBeFalsy();
  });
});
