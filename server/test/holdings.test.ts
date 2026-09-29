import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { buildingsFor, cellAt, cellBonus, CELL_BUILDING_COSTS, CELL_BUILDINGS, standInLandmark, neighbors, type CellDetail, type CellView, type ExpeditionReport, type WorldMe } from "@goblincamp/shared/world";
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
async function settle(auth: Record<string, string>, count = 20, not: string[] = [], pick?: (c: CellView) => boolean) {
  const home = (await me(auth)).homeCell!;
  const cells = (await map(auth)).filter((c) => !c.owner && !c.boss && c.cell !== home && !not.includes(c.cell) && (!pick || pick(c)));
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

describe("a building on a cell", () => {
  it("is picked by the ground, built, raised a level at a time, adds to every yield, and can be taken down", async () => {
    const a = await ready();
    const cell = await settle(a, 20);
    let d = (await detail(a, cell)).body;
    expect(d.building).toBeNull();
    expect(d.canBuild).toHaveLength(2);
    expect(d.nextCost).toEqual({ scrap_wood: 20, log: 20 });
    const maker = CELL_BUILDINGS.find((r) => r.terrain === d.terrain && r.makes)!;
    const other = d.canBuild.find((k) => k.kind !== maker.kind)!.kind;
    const elsewhere = CELL_BUILDINGS.find((r) => r.terrain !== d.terrain)!.kind;

    await database.sql`update camps set materials = '{}'::jsonb`;
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: maker.kind }, a)).body.error).toBe("cannot_afford");
    await give("a@example.com", { scrap_wood: 500, scrap_iron: 200, scrap_rag: 100, log: 500, stone: 200, crystal_shard: 3 });
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: elsewhere }, a)).status).toBe(400);
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: maker.kind }, a)).status).toBe(200);
    d = (await detail(a, cell)).body;
    expect(d.building).toEqual(expect.objectContaining({ kind: maker.kind, level: 1, working: 0 }));
    expect(Date.parse(d.building!.busyUntil!) - t.now().getTime()).toBe(HOUR);
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: maker.kind }, a)).body.error).toBe("busy");
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: other }, a)).body.error).toBe("exists");
    // others see it on the map
    expect((await map(a)).find((c) => c.cell === cell)!.building).toEqual({ kind: maker.kind, level: 1, busy: true });

    t.advance(HOUR + MIN);
    d = (await detail(a, cell)).body;
    expect(d.building!.working).toBe(1);
    expect(d.nextCost).toEqual(CELL_BUILDING_COSTS[1]);
    const [id, n] = Object.entries(maker.makes!).find(([, v]) => v[0] > 0)!;
    expect(d.bonus.makes[id]).toBe(n[0]);
    // the next yields bring what it makes
    t.advance(3 * HOUR);
    d = (await detail(a, cell)).body;
    expect(d.history.find((h) => h.kind === "yield")!.loot![id]).toBeGreaterThanOrEqual(n[0]);
    expect(d.history.some((h) => h.kind === "built")).toBe(true);

    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: maker.kind }, a)).status).toBe(200);
    expect((await detail(a, cell)).body.building).toEqual(expect.objectContaining({ level: 2, working: 1 }));
    expect((await t.call("POST", `/world/cells/${cell}/demolish`, {}, a)).status).toBe(200);
    expect((await detail(a, cell)).body.building).toBeNull();
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: other }, a)).status).toBe(200);
  });

  it("is not for the camp's own cell, and goes when the cell is given up", async () => {
    const a = await ready();
    const w = await me(a);
    const home = (await detail(a, w.homeCell!)).body;
    expect(home.canBuild).toEqual([]);
    await give("a@example.com", { scrap_wood: 100, log: 100 });
    expect((await t.call("POST", `/world/cells/${w.homeCell}/build`, { kind: buildingsFor(home.terrain)[0]!.kind }, a)).body.error).toBe("camp_cell");
    const cell = await settle(a, 20);
    const kind = (await detail(a, cell)).body.canBuild[0]!.kind;
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind }, a)).status).toBe(200);
    await t.call("POST", `/world/cells/${cell}/recall`, {}, a);
    expect((await map(a)).find((c) => c.cell === cell)!.building).toBeNull();
  });

  it("lets bigger parties set out from barracks, and parties walk faster from a dock or an inn", async () => {
    const a = await ready();
    // (whatever ground the cell has, give it the building to test: the rules only look at what is there)
    const cell = await settle(a, 25);
    const walk = async () => {
      const res = await t.call("POST", "/world/expeditions", { from: cell, to: (await me(a)).homeCell, count: 3 }, a);
      expect(res.body).toEqual(expect.objectContaining({ kind: "move" }));
      const minutes = (Date.parse(res.body.arriveAt) - Date.parse(res.body.setOutAt)) / MIN;
      t.advance(minutes * MIN + 1000);
      await t.call("POST", "/world/expeditions", { from: "home", to: cell, count: 3 }, a).then((r) => t.advance(Date.parse(r.body.arriveAt) - t.now().getTime() + 1000));
      return minutes;
    };
    const plain = await walk();
    await database.sql`update world_cells set building = ${JSON.stringify({ kind: "dock", level: 3 })}::jsonb where cell = ${cell}`;
    const fast = await walk();
    expect(fast).toBeLessThan(plain); // (about 0.65 of it: who walks differs a little)
    const cap = (await me(a)).partyCap;
    await database.sql`update world_cells set building = ${JSON.stringify({ kind: "barracks", level: 3 })}::jsonb where cell = ${cell}`;
    expect((await me(a)).cells.find((c) => c.cell === cell)!.party).toBe(4);
    // (enough living there to send that many and still hold it)
    const more = await t.call("POST", "/world/expeditions", { from: "home", to: cell, count: 20 }, a);
    t.advance(Date.parse(more.body.arriveAt) - t.now().getTime() + 1000);
    const lair = (await map(a)).find((c) => c.lair && !c.owner)!;
    expect((await t.call("POST", "/world/expeditions", { from: cell, to: lair.cell, count: cap + 4 }, a)).status).toBe(201);
  });
});

describe("landmarks", () => {
  it("show on the map, and whoever holds one gets what it gives", async () => {
    const a = await ready();
    const cells = await map(a);
    const marked = cells.filter((c) => c.landmark);
    expect(marked.length).toBeGreaterThan(0);
    for (const c of marked) expect(c.landmark).toEqual(standInLandmark(c.cell));
    const cell = await settle(a, 20, [], (c) => !!c.landmark);
    const d = (await detail(a, cell)).body;
    expect(d.landmark).toEqual(expect.objectContaining(standInLandmark(cell)!));
    expect(d.landmark!.blurb.length).toBeGreaterThan(0);
    expect(d.bonus).toEqual(cellBonus("goblin", null, t.now().getTime(), { landmark: standInLandmark(cell) }));
  });
});

describe("cells held side by side", () => {
  /** The lairs on these cells were just beaten (so they are free to settle, and none comes back for a while). */
  async function clear(cells: string[]) {
    const at = t.now().toISOString();
    for (const c of cells) await database.sql`insert into world_cells (cell, cleared_at) values (${c}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
  }

  it("each held neighbour adds to the yield; a town needs four joined together", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const around = neighbors(home);
    await clear(around);
    const first = await settle(a, 20, [], (c) => c.cell === around[0]);
    let d = (await detail(a, first)).body;
    expect(d.neighbours).toBeGreaterThanOrEqual(1); // (the camp's own cell)
    expect(d.region).toBe(2);
    expect(d.bonus.yieldBoost).toBeCloseTo(0.1 * Math.min(3, d.neighbours));

    await give("a@example.com", { scrap_wood: 500, scrap_iron: 200, scrap_rag: 100, crystal_shard: 5 });
    expect((await t.call("POST", `/world/cells/${first}/town`, undefined, a)).body.error).toBe("too_few");
    await settle(a, 20, [], (c) => c.cell === around[1]);
    await settle(a, 20, [], (c) => c.cell === around[2]);
    d = (await detail(a, first)).body;
    expect(d.region).toBe(4);
    expect((await me(a)).cells.find((c) => c.cell === first)!.region).toBe(4);
    expect((await t.call("POST", `/world/cells/${first}/town`, undefined, a)).status).toBe(200);
  });

  it("send help when a cell is attacked: the camp next to it lends its strongest", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    await clear(neighbors(home));
    const cell = await settle(a, 10, [], (c) => neighbors(home).includes(c.cell));
    const garrison = (await detail(a, cell)).body.garrison;
    // someone else opens the big world a little way off and attacks it
    const b = await account("b@example.com");
    t.advance(16 * HOUR);
    const far = neighbors(neighbors(neighbors(home)[3]!)[3]!)[3]!;
    await clear([far]);
    expect((await t.call("POST", "/world/open", { cell: far }, b)).status).toBe(201);
    await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = 'b@example.com')`;
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 25 }, b);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, b)).body as ExpeditionReport;
    const defending = report.fighters.filter((f) => f.side === "defend").length;
    expect(defending).toBe(garrison + 5);
  });
});
