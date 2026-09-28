import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { bossIn, bossWindow, cellAt, cellCenter, cellsWithin, neighbors, regionOf, WORLD_SEED, type CellView, type ExpeditionReport, type WorldMe } from "@goblincamp/shared/world";
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
    // on the road: not at home
    const walking = await camp(a);
    expect(walking.residents.filter((r) => r.place === `exp:${res.body.id}`)).toHaveLength(25);
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
    expect(report.fighters.filter((f) => f.side === "attack")).toHaveLength(25);
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
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, b)).body as { fighters: { side: string }[]; outcome: { against: string } };
    expect(report.outcome.against).toContain("營地");
    expect(report.fighters.filter((f) => f.side === "defend").length).toBeGreaterThan(20); // (the whole camp)
    expect((await me(a)).cells.map((c) => c.cell)).toEqual([aCell]);
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

  it("keep their wounds between parties, and share the spoils with everyone who hurt them", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await grow(a);
    const boss = bossNear();
    await t.call("POST", "/world/open", { cell: boss.beside, settlers: 5 }, a);
    await t.call("POST", "/world/open", { cell: neighbors(boss.cell)[3]!, settlers: 5 }, b);
    await veteran("a@example.com");
    await veteran("b@example.com");
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
    (await map(a, DAAN, 1500)).filter((c) => c.lair && !c.boss && c.cell !== cellAt(DAAN)).sort((x, y) => y.lair!.power - x.lair!.power)[0]!;

  it("a party is small at first; rations let more go and are eaten; boost food too; the camp bakes bread", async () => {
    const a = await fresh();
    let w = await me(a);
    expect(w.partyCap).toBe(6); // (goblins at level 1)
    expect(w.food).toEqual({ ration_bread: 5 }); // (given on opening)
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
    // bread: a loaf every 2 hours, up to 10
    t.advance(30 * HOUR);
    expect((await me(a)).food.ration_bread).toBe(10);
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
