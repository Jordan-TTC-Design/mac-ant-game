import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { buildingsFor, cellAt, cellBonus, marketQuote, CELL_BUILDING_COSTS, CELL_BUILDINGS, standInLandmark, neighbors, type CellDetail, type CellView, type ExpeditionReport, type TerritoryList, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { usePlaceSource } from "../src/world/search.ts";
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

  it("are all listed at a glance: the camp's own first, then the others with what is on them", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const cell = await settle(a, 20);
    await give("a@example.com", { scrap_wood: 20, log: 20 });
    const kind = (await detail(a, cell)).body.canBuild[0]!.kind;
    await t.call("POST", `/world/cells/${cell}/build`, { kind }, a);
    const res = await t.call("GET", "/world/territory", undefined, a);
    expect(res.status).toBe(200);
    const list = res.body as TerritoryList;
    expect(list.items.map((i) => i.cell)).toEqual([home, cell]);
    expect(list.items[0]).toEqual(expect.objectContaining({ home: true, building: null }));
    expect(list.items[1]).toEqual(expect.objectContaining({ home: false, nest: "none", building: expect.objectContaining({ kind, level: 1, busy: true }) }));
    expect(list.items[1]!.garrison).toBe((await detail(a, cell)).body.garrison);
    expect(list.residents).toBe(list.items[0]!.garrison + list.items[1]!.garrison);
    expect((await t.call("GET", "/world/territory", undefined, await account("b@example.com"))).body.items).toEqual([]);
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
    // its terrain's two, then its 細分地形's (if any) and the three of anywhere (details.ts)
    expect(d.canBuild.slice(0, 2).map((b) => b.kind)).toEqual(CELL_BUILDINGS.filter((r) => r.terrain === d.terrain && !r.only).map((r) => r.kind));
    expect(d.canBuild).toHaveLength(2 + (d.detail ? 2 : 0) + 3);
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

describe("parties from a held cell", () => {
  it("walk back to the cell they set out from (home when it is gone or full)", async () => {
    const a = await ready();
    const cell = await settle(a, 25);
    const lair = (await map(a)).filter((c) => c.lair && !c.owner).sort((x, y) => x.lair!.power - y.lair!.power)[0]!;
    const before = (await detail(a, cell)).body.garrison;
    const res = await t.call("POST", "/world/expeditions", { from: cell, to: lair.cell, count: 10 }, a);
    expect(res.status).toBe(201);
    t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);
    const w = await me(a);
    const fallen = w.recent[0]!.outcome!.fallen;
    const c = await camp(a);
    expect(c.residents.filter((r) => r.place === `cell:${cell}`).length).toBe(before - fallen);
    expect(c.residents.some((r) => r.place.startsWith("exp:"))).toBe(false);
  });
});

describe("searching for a place", () => {
  it("finds it by name (台 or 臺), one per cell, with how far it is; and says so when the search cannot be reached", async () => {
    const a = await ready();
    const asked: string[] = [];
    const ARTS = { name: "國立台灣藝術大學", where: "板橋區・新北市", lat: 25.0060215, lng: 121.4490451 };
    usePlaceSource(async (q, _near, country) => {
      asked.push(`${q}@${country ?? "*"}`);
      return q === "臺藝大" && country === "tw" ? [ARTS, { ...ARTS, name: "同一格的門口", lat: ARTS.lat + 0.00001 }] : [];
    });
    const res = await t.call("GET", `/world/search?q=${encodeURIComponent("台藝大")}&lat=${DAAN.lat}&lng=${DAAN.lng}`, undefined, a);
    expect(res.status).toBe(200);
    expect(asked).toEqual(["台藝大@tw", "臺藝大@tw"]);
    const places = res.body.places as { name: string; cell: string; km: number }[];
    expect(places).toEqual([expect.objectContaining({ name: "國立台灣藝術大學", cell: cellAt(ARTS) })]);
    expect(places[0]!.km).toBeGreaterThan(8);
    expect(places[0]!.km).toBeLessThan(10);
    // (nothing in Taiwan: anywhere)
    asked.length = 0;
    expect((await t.call("GET", `/world/search?q=${encodeURIComponent("Eiffel")}`, undefined, a)).body.places).toEqual([]);
    expect(asked).toEqual(["Eiffel@tw", "Eiffel@*"]);
    expect((await t.call("GET", "/world/search?q=", undefined, a)).status).toBe(400);
    usePlaceSource(async () => null);
    expect((await t.call("GET", `/world/search?q=${encodeURIComponent("台北車站")}`, undefined, a)).status).toBe(503);
  });
});

describe("landmarks", () => {
  it("can be looked for around a point: the nearest first, with who holds each", async () => {
    const a = await ready();
    const res = await t.call("GET", `/world/landmarks?lat=${DAAN.lat}&lng=${DAAN.lng}`, undefined, a);
    expect(res.status).toBe(200);
    const list = res.body.landmarks as { cell: string; kind: string; km: number; owner: unknown }[];
    expect(list.length).toBeGreaterThan(0);
    for (const l of list) expect(standInLandmark(l.cell)).toEqual(expect.objectContaining({ kind: l.kind }));
    expect(list.map((l) => l.km)).toEqual([...list.map((l) => l.km)].sort((x, y) => x - y));
    expect(list.every((l) => l.km <= 3.1)).toBe(true);
    expect((await t.call("GET", `/world/landmarks?lat=${DAAN.lat}&lng=${DAAN.lng}&radius=9000`, undefined, a)).status).toBe(400);
    // one taken shows its holder
    const cell = await settle(a, 20, [], (c) => !!c.landmark);
    const again = (await t.call("GET", `/world/landmarks?lat=${DAAN.lat}&lng=${DAAN.lng}`, undefined, a)).body.landmarks as { cell: string; owner: { name: string } | null }[];
    expect(again.find((l) => l.cell === cell)!.owner?.name).toBe("咕嚕");
  });

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

  it("every town lets each cell of its region house half as many more (stacking, 4 at most), one town per 4 cells", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const ring = neighbors(home);
    const outer = neighbors(ring[0]!).find((c) => c !== home && !ring.includes(c))!;
    await clear([...ring, outer]);
    for (const c of ring.slice(0, 3)) await settle(a, 20, [], (x) => x.cell === c);
    await give("a@example.com", { scrap_wood: 1000, scrap_iron: 500, scrap_rag: 300, crystal_shard: 10 });
    const [first, second, third] = ring as [string, string, string];

    // before: a goblin cell houses 50, a town 100
    expect((await detail(a, second)).body.capacity).toBe(50);
    expect((await t.call("POST", `/world/cells/${first}/town`, undefined, a)).status).toBe(200);
    let d = (await detail(a, second)).body;
    expect(d.capacity).toBe(75); // +25 from the town
    expect(d).toMatchObject({ regionTowns: 1, townRoom: 25 });
    expect((await detail(a, first)).body.capacity).toBe(100); // (a town gets no room from itself)
    const list = (await t.call("GET", "/world/territory", undefined, a)).body as TerritoryList;
    expect(list.items.find((i) => i.cell === second)).toMatchObject({ capacity: 75, townRoom: 25 });

    // a second town needs 8 cells in the region
    const refused = await t.call("POST", `/world/cells/${third}/town`, undefined, a);
    expect(refused.body.error).toBe("too_few");
    expect(refused.body.message).toContain("8");
    for (const c of [...ring.slice(3), outer]) await settle(a, 20, [], (x) => x.cell === c);
    expect((await me(a)).cells.find((c) => c.cell === third)).toMatchObject({ region: 8, regionTowns: 1 });
    expect((await t.call("POST", `/world/cells/${third}/town`, undefined, a)).status).toBe(200);
    expect((await detail(a, second)).body.capacity).toBe(100); // two towns: +50
    expect((await detail(a, first)).body.capacity).toBe(125); // a town: 100, and +25 from the other one
  });

  /** Waits until every party on the road has arrived (and whatever they set off in turn). */
  async function arriveAll(auth: Record<string, string>) {
    for (let k = 0; k < 4; k++) {
      const walking = (await me(auth)).walking;
      if (!walking.length) return;
      t.advance(Math.max(...walking.map((w) => Date.parse(w.arriveAt))) - t.now().getTime() + 1000);
    }
  }
  const cellOf = async (auth: Record<string, string>, cell: string) => (await me(auth)).cells.find((c) => c.cell === cell);

  it("recall walks: fills the cell it goes to, the rest camp beside it and move in as room frees up", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const [bCell, aCell] = neighbors(home) as [string, string];
    await clear([bCell, aCell]);
    await settle(a, 25, [], (c) => c.cell === bCell);
    const more = await t.call("POST", "/world/expeditions", { from: "home", to: bCell, count: 20 }, a);
    expect(more.status).toBe(201);
    await settle(a, 20, [], (c) => c.cell === aCell);
    await arriveAll(a);
    expect((await cellOf(a, bCell))!.garrison).toBe(45);

    // all 20 go: the cell is given up at once, and they are on the road (not there yet)
    const res = await t.call("POST", `/world/cells/${aCell}/recall`, { to: bCell }, a);
    expect(res.status).toBe(200);
    let w = res.body as WorldMe;
    expect(w.cells.some((c) => c.cell === aCell)).toBe(false);
    expect(w.walking).toEqual([expect.objectContaining({ kind: "recall", from: aCell, to: bCell, party: 20 })]);
    expect((await cellOf(a, bCell))!.garrison).toBe(45);

    await arriveAll(a);
    let b = (await cellOf(a, bCell))!;
    expect(b).toMatchObject({ garrison: 50, capacity: 50, camping: 15 }); // (no other cell has room)
    expect((await detail(a, bCell)).body.camping).toBe(15);

    // ten walk home from it: the campers move in
    expect((await t.call("POST", `/world/cells/${bCell}/recall`, { to: "home", count: 10 }, a)).status).toBe(200);
    b = (await cellOf(a, bCell))!;
    expect(b).toMatchObject({ garrison: 50, camping: 5 });
    // and the campers can be sent off too
    expect((await t.call("POST", `/world/cells/${bCell}/recall`, { to: "home", campers: true }, a)).status).toBe(200);
    w = await me(a);
    expect(w.cells.find((c) => c.cell === bCell)).toMatchObject({ garrison: 50, camping: 0 });
    expect(w.walking.filter((x) => x.kind === "recall").map((x) => x.party).sort()).toEqual([10, 5]);
  });

  it("recall: those who do not fit walk on to the nearest cell with room", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const [bCell, aCell, cCell] = neighbors(home) as [string, string, string];
    await clear([bCell, aCell, cCell]);
    await settle(a, 25, [], (c) => c.cell === bCell);
    await t.call("POST", "/world/expeditions", { from: "home", to: bCell, count: 20 }, a);
    await settle(a, 20, [], (c) => c.cell === aCell);
    await settle(a, 10, [], (c) => c.cell === cCell);
    await arriveAll(a);

    expect((await t.call("POST", `/world/cells/${aCell}/recall`, { to: bCell }, a)).status).toBe(200);
    const first = (await me(a)).walking[0]!;
    t.advance(Date.parse(first.arriveAt) - t.now().getTime() + 1000);
    const w = await me(a);
    expect(w.cells.find((c) => c.cell === bCell)).toMatchObject({ garrison: 50, camping: 0 });
    expect(w.walking).toEqual([expect.objectContaining({ kind: "reroute", from: bCell, to: cCell, party: 15 })]);
    await arriveAll(a);
    expect((await cellOf(a, cCell))!.garrison).toBe(25);
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

describe("keeping many cells", () => {
  it("the first three besides the camp are free (more with the race level); the rest eat rations every yield, and go hungry without", async () => {
    const a = await ready();
    await database.sql`update world_players set xp = 200`; // (race level 3: no more free cells than the three yet, freeCellsFor)
    const home = (await me(a)).homeCell!;
    const around = neighbors(home);
    const at = t.now().toISOString();
    for (const c of around) await database.sql`insert into world_cells (cell, cleared_at) values (${c}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
    const cells: string[] = [];
    for (let i = 0; i < 4; i++) {
      cells.push(await settle(a, 6, [], (c) => c.cell === around[i]));
      t.advance(MIN); // (held one after another: the last is the one that pays)
    }
    let w = await me(a);
    expect(w.upkeep).toEqual(expect.objectContaining({ paying: 1, perYield: 1, freeCells: 3 }));
    expect(w.cells.filter((c) => c.upkeep).map((c) => c.cell)).toEqual([cells[3]]);
    expect((await detail(a, cells[3]!)).body.upkeep.pays).toBe(true);
    expect((await detail(a, cells[0]!)).body.upkeep.pays).toBe(false);

    // no rations: the fourth goes hungry at its next yield (the others give nothing this time, so none of their food comes in first)
    await database.sql`update camps set materials = '{}'::jsonb`;
    const later = new Date(t.now().getTime() + 24 * HOUR).toISOString();
    await database.sql`update world_cells set yielded_to = ${later}::timestamptz where cell in ${database.sql([home, cells[0]!, cells[1]!, cells[2]!])}`;
    t.advance(6 * HOUR); // (a ration every other yield)
    const hungry = (await detail(a, cells[3]!)).body.history.find((h) => h.kind === "yield");
    expect(hungry?.hungry).toBe(true);

    // with rations: one is eaten every yield
    await database.sql`update camps set materials = '{"ration_fish": 5}'::jsonb`;
    t.advance(6 * HOUR);
    w = await me(a);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, a)).body.events as { data: { upkeep?: Record<string, number>; hungry?: string[] } }[];
    expect(events.filter((e) => e.data.upkeep).at(-1)!.data.upkeep).toEqual({ ration_fish: 1 });
    expect((await detail(a, cells[3]!)).body.history.find((h) => h.kind === "yield")?.hungry).toBeUndefined();
  });
});

describe("friends guarding each other's cells", () => {
  async function friends(x: Record<string, string>, y: Record<string, string>) {
    const code = async (auth: Record<string, string>) => (await t.call("GET", "/auth/me", undefined, auth)).body.user.friendCode as string;
    await t.call("POST", "/friends/asks", { code: await code(y) }, x);
    await t.call("POST", "/friends/asks", { code: await code(x) }, y);
  }
  /** Opens the big world for a camp made earlier (so it has grown with the others) a few cells from `from`. */
  async function nearby(auth: Record<string, string>, email: string, from: string) {
    let cell = from;
    for (let i = 0; i < 3; i++) cell = neighbors(cell)[3]!;
    const at = t.now().toISOString();
    await database.sql`insert into world_cells (cell, cleared_at) values (${cell}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
    expect((await t.call("POST", "/world/open", { cell }, auth)).status).toBe(201);
    await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = ${email})`;
    return auth;
  }
  const arrive = async (res: { body: { arriveAt: string } }) => t.advance(Date.parse(res.body.arriveAt) - t.now().getTime() + 1000);

  it("only friends may send guests; they stay, show on the map and the cell's page, and walk home when told", async () => {
    const early = await account("b@example.com");
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const cell = await settle(a, 15, [], (c) => !neighbors(home).includes(c.cell));
    const b = await nearby(early, "b@example.com", home);
    expect((await t.call("POST", "/world/expeditions", { to: cell, count: 5, guard: true }, b)).body.error).toBe("not_friend");
    await friends(a, b);
    expect((await t.call("POST", "/world/expeditions", { to: cell, count: 25, guard: true }, b)).body.error).toBe("too_many");
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 8, guard: true }, b);
    expect(res.status).toBe(201);
    expect(res.body.kind).toBe("guard");
    await arrive(res);
    expect((await me(b)).recent[0]!.outcome?.cell).toBe("guarding");
    expect((await me(b)).guarding).toEqual([{ cell, holder: "咕嚕", count: 8 }]);
    expect((await map(a)).find((c) => c.cell === cell)!.guests).toBe(8);
    const d = (await detail(a, cell)).body;
    expect(d.guests).toEqual([expect.objectContaining({ count: 8 })]);
    expect(d.history.some((h) => h.kind === "guests")).toBe(true);
    // a guest cannot turn on the cell it guards
    expect((await t.call("POST", "/world/expeditions", { to: cell, count: 5 }, b)).body.error).toBe("guarding");

    // the holder sends them home
    expect((await t.call("POST", `/world/cells/${cell}/unguard`, {}, a)).status).toBe(200);
    expect((await me(b)).guarding).toEqual([]);
    expect((await camp(b)).residents.filter((r) => r.place.startsWith("guard:"))).toHaveLength(0);
    expect((await t.call("POST", `/world/cells/${cell}/unguard`, {}, b)).body.error).toBe("none");
  });

  it("fight beside the holder when another camp attacks; the fallen are buried in their own camp, their gear comes home", async () => {
    const c = await account("c@example.com"); // (they grow while a does)
    const early = await account("b@example.com");
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const cell = await settle(a, 6, [], (c) => !neighbors(home).includes(c.cell));
    const garrison = (await detail(a, cell)).body.garrison;
    const b = await nearby(early, "b@example.com", home);
    await friends(a, b);
    await arrive(await t.call("POST", "/world/expeditions", { to: cell, count: 10, guard: true }, b));
    expect((await me(b)).guarding).toEqual([expect.objectContaining({ cell, count: 10 })]);
    // someone strong attacks
    let far = home;
    for (let i = 0; i < 3; i++) far = neighbors(far)[0]!;
    const at = t.now().toISOString();
    await database.sql`insert into world_cells (cell, cleared_at) values (${far}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
    await t.call("POST", "/world/open", { cell: far }, c);
    await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = 'c@example.com')`;
    const res = await t.call("POST", "/world/expeditions", { to: cell, count: 25 }, c);
    expect(res.status).toBe(201);
    await arrive(res);
    const report = (await t.call("GET", `/world/expeditions/${res.body.id}`, undefined, c)).body as ExpeditionReport;
    const defending = report.fighters.filter((f) => f.side === "defend");
    expect(defending.filter((f) => f.id.startsWith("g"))).toHaveLength(10);
    expect(defending).toHaveLength(garrison + 10);
    const fellGuests = report.fallen.defend.filter((id) => id.startsWith("g")).length;
    const bCamp = await camp(b);
    expect(bCamp.residents.filter((r) => r.place.startsWith("guard:")).length + fellGuests).toBeLessThanOrEqual(10);
    if (report.outcome!.won) expect(bCamp.residents.filter((r) => r.place.startsWith("guard:"))).toHaveLength(0); // (the cell is lost: survivors went home)
    const events = (await t.call("GET", "/camp/events?since=0", undefined, b)).body.events as { data: { guardFell?: { fallen: number } } }[];
    expect(events.filter((e) => e.data.guardFell).reduce((n, e) => n + e.data.guardFell!.fallen, 0)).toBe(fellGuests);
    const left = await database.sql`select count(*)::int as n from camp_residents where place like 'fell:%' and gear is not null`;
    expect(left[0]!.n).toBe(0); // (their gear came home when b's camp was worked out)
  });
});

describe("gear for residents away from home", () => {
  const cmd = (auth: Record<string, string>, command: Record<string, unknown>) => t.call("POST", "/camp/commands", command, auth);
  /** A camp with one settled cell; everyone at home already holds a long sword (so a bone knife is wanted only away). */
  async function away(email = "a@example.com") {
    const a = await ready(email);
    const cell = await settle(a, 20);
    await database.sql`update camp_residents set gear = '{"weapon": {"id": "long_sword", "left": 200}}'::jsonb where place = 'home' and user_id = (select id from users where email = ${email})`;
    await give(email, { rat_fang: 40, rat_tail: 10 });
    return { a, cell };
  }

  it("names the places, and makes a piece for one living on a held cell", async () => {
    const { a, cell } = await away();
    const c = await camp(a);
    expect(c.places?.[`cell:${cell}`]).toEqual({ label: "領地 1", town: false });
    const there = c.residents.find((r) => r.place === `cell:${cell}`)!;
    const res = await cmd(a, { kind: "craft", gear: "bone_knife", to: there.id });
    expect(res.status).toBe(200);
    expect((res.body.camp as CampView).residents.find((r) => r.id === there.id)!.gear!.weapon).toMatchObject({ id: "bone_knife", pinned: true });
    // taken off there, and mended there
    expect((await cmd(a, { kind: "unequip", resident: there.id, slot: "weapon" })).status).toBe(200);
    expect((await cmd(a, { kind: "equip", resident: there.id, stock: 0, gear: "bone_knife" })).status).toBe(200);
    await database.sql`update camp_residents set gear = '{"weapon": {"id": "bone_knife", "left": 10, "pinned": true}}'::jsonb where id = ${there.id}`;
    const mended = await cmd(a, { kind: "repair", resident: there.id, slot: "weapon" });
    expect(mended.status).toBe(200);
    expect((mended.body.camp as CampView).residents.find((r) => r.id === there.id)!.gear!.weapon!.left).toBe(120);
  });

  it("hands out to the towns always, to the other cells with the far switch on", async () => {
    const { a, cell } = await away();
    expect((await cmd(a, { kind: "craft", gear: "bone_knife" })).body.error).toBe("nobody_needs"); // (a plain cell: not reached)
    await database.sql`update world_cells set town = true where cell = ${cell}`;
    let res = await cmd(a, { kind: "craft", gear: "bone_knife" });
    expect(res.status).toBe(200);
    expect((res.body.camp as CampView).residents.find((r) => r.id === res.body.resident)!.place).toBe(`cell:${cell}`);
    await database.sql`update world_cells set town = false where cell = ${cell}`;
    res = await cmd(a, { kind: "auto-gear-far", on: true });
    expect((res.body.camp as CampView).autoGearFar).toBe(true);
    res = await cmd(a, { kind: "craft", gear: "bone_knife" });
    expect(res.status).toBe(200);
    expect((res.body.camp as CampView).residents.find((r) => r.id === res.body.resident)!.place).toBe(`cell:${cell}`);
  });

  it("hands the store out to a town as time goes by", async () => {
    const { a, cell } = await away();
    await database.sql`update world_cells set town = true where cell = ${cell}`;
    await database.sql`update camps set armory = '[{"id": "bone_knife", "left": 120}]'::jsonb`;
    t.advance(MIN); // (a short while: the camp's own deaths and raids may put more into the store meanwhile)
    const c = await camp(a);
    expect(c.armory.some((x) => x.id === "bone_knife")).toBe(false);
    expect(c.residents.filter((r) => r.place === `cell:${cell}` && r.gear?.weapon?.id === "bone_knife")).toHaveLength(1);
  });

  it("shows on the map where a camp's home stands", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const cells = await map(a);
    expect(cells.find((c) => c.cell === home)!.home).toBe(true);
    expect(cells.filter((c) => c.home)).toHaveLength(1);
  });
});

describe("a town's market", () => {
  it("swaps materials at a loss, a few times a day for each town", async () => {
    const a = await ready();
    const cell = await settle(a, 20);
    const trade = (body: Record<string, unknown>) => t.call("POST", `/world/cells/${cell}/market`, body, a);
    expect((await trade({ give: "log", count: 10, get: "stone" })).body.error).toBe("not_town"); // (a plain cell has none)
    await database.sql`update world_cells set town = true where cell = ${cell}`;
    await give("a@example.com", { rat_fang: 100 });
    expect((await detail(a, cell)).body.market).toEqual({ left: 3 });
    const before = (await camp(a)).materials;
    const res = await trade({ give: "rat_fang", count: 10, get: "crystal_shard" });
    expect(res.status).toBe(200);
    const after = (await camp(a)).materials;
    expect(after.rat_fang).toBe(before.rat_fang! - 10);
    expect((after.crystal_shard ?? 0) - (before.crystal_shard ?? 0)).toBe(marketQuote("rat_fang", 10, "crystal_shard"));
    expect(marketQuote("rat_fang", 10, "crystal_shard")).toBe(4); // (10 × 4 × 0.6 ÷ 5)
    // the economy dashboard's flow: what went out and what came in
    const flows = await database.sql`select data from camp_events where kind = 'flow' and data ->> 'source' = 'world-market'`;
    expect(flows.at(-1)!.data).toEqual({ source: "world-market", delta: { rat_fang: -10, crystal_shard: 4 } });
    expect((await trade({ give: "rat_fang", count: 1, get: "crystal_shard" })).body.error).toBe("invalid_input"); // (too few for one)
    await trade({ give: "rat_fang", count: 10, get: "scrap_iron" });
    await trade({ give: "rat_fang", count: 10, get: "scrap_iron" });
    expect((await detail(a, cell)).body.market).toEqual({ left: 0 });
    expect((await trade({ give: "rat_fang", count: 10, get: "scrap_iron" })).body.error).toBe("market_closed");
    t.advance(24 * HOUR); // (a new day)
    expect((await detail(a, cell)).body.market).toEqual({ left: 3 });
  });

  it("gives a town's defenders walls and its parties a head start", () => {
    const at = Date.now();
    expect(cellBonus("goblin", null, at, { town: true })).toMatchObject({ fort: 0.2, travel: 0.75 });
  });
});

describe("auto staffing", () => {
  it("keeps a held cell at the number set: the camp sends more, and calls the rest home", async () => {
    const a = await ready();
    const cell = await settle(a, 10);
    const target = (n: number | null) => t.call("POST", `/world/cells/${cell}/target`, { target: n }, a);
    expect((await target(2)).body.error).toBe("invalid_input"); // (fewer than a cell must keep)
    expect((await target(999)).body.error).toBe("invalid_input"); // (more than it houses)
    expect((await t.call("POST", `/world/cells/${(await me(a)).homeCell}/target`, { target: 10 }, a)).body.error).toBe("camp_cell");

    let res = await target(20);
    expect(res.status).toBe(200);
    let w = res.body as WorldMe;
    const going = w.walking.filter((x) => x.to === cell);
    expect(going).toHaveLength(1);
    expect(going[0]).toMatchObject({ kind: "move", party: 10 });
    expect((await me(a)).walking.filter((x) => x.to === cell)).toHaveLength(1); // (looking again sends nobody more)
    expect((await detail(a, cell)).body.target).toBe(20);
    t.advance(Date.parse(going[0]!.arriveAt) - t.now().getTime() + 1000);
    expect((await me(a)).cells.find((c) => c.cell === cell)!.garrison).toBe(20);

    res = await target(12);
    w = res.body as WorldMe;
    const back = w.walking.filter((x) => x.from === cell);
    expect(back).toHaveLength(1);
    expect(back[0]).toMatchObject({ kind: "recall", party: 8 });
    expect(w.cells.find((c) => c.cell === cell)!.garrison).toBe(12);
    const log = (await detail(a, cell)).body.history.filter((h) => h.kind === "staffed");
    expect(log.map((h) => [h.residents, h.back])).toEqual([[0, 8], [10, 0]]);

    // off: nothing moves any more
    await target(null);
    await database.sql`update camp_residents set died_at = now() where place = ${`cell:${cell}`} and id in (select id from camp_residents where place = ${`cell:${cell}`} limit 3)`;
    expect((await me(a)).walking.filter((x) => x.to === cell)).toHaveLength(0);
  });
});

describe("cells without upkeep grow with the race level", () => {
  it("frees one more cell every four levels", async () => {
    const a = await ready(); // (race level 20)
    expect((await me(a)).upkeep).toEqual(expect.objectContaining({ freeCells: 3 + 5 }));
    await database.sql`update world_players set xp = 200`; // (level 3)
    expect((await me(a)).upkeep).toEqual(expect.objectContaining({ freeCells: 3 }));
  });
});

describe("buildings' level 4", () => {
  it("opens at race level 10", async () => {
    const a = await ready(); // (race level 20)
    const cell = await settle(a, 10);
    const kind = buildingsFor((await detail(a, cell)).body.terrain)[0]!.kind;
    await database.sql`update world_cells set building = ${JSON.stringify({ kind, level: 3 })}::jsonb where cell = ${cell}`;
    await give("a@example.com", { scrap_wood: 500, scrap_iron: 500, scrap_rag: 500, log: 500, stone: 500, crystal_shard: 50, amber: 50 });
    await database.sql`update world_players set xp = 200`; // (level 3)
    expect((await detail(a, cell)).body.nextNeedsLevel).toBe(10);
    const refused = await t.call("POST", `/world/cells/${cell}/build`, { kind }, a);
    expect(refused.body.message).toContain("種族等級 10");
    await database.sql`update world_players set xp = 18050`;
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind }, a)).status).toBe(200);
    expect((await detail(a, cell)).body.building!.level).toBe(4);
  });
});

describe("聖樹 (精靈森林's top talent)", () => {
  it("an elf with the talent plants one on park or forest: the cell holds harder, its region more so and yields more", async () => {
    const e = await account("e@example.com", "elf");
    t.advance(40 * HOUR);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, e);
    await database.sql`update world_players set xp = 18050 where user_id = (select id from users where email = 'e@example.com')`;
    const grove = { "e_grove.bloom": 3, "e_grove.bark": 2, "e_grove.cradle": 3, "e_grove.canopy": 3, "e_grove.harvest": 2, "e_grove.roots": 3, "e_grove.sacred": 1 };
    expect((await t.call("POST", "/world/talents", { picks: grove }, e)).body.message ?? "").toBe("");
    const green = (c: CellView) => c.terrain === "park" || c.terrain === "forest";
    const cell = await settle(e, 15, [], green);
    await give("e@example.com", { scrap_wood: 500, log: 500 });
    const before = (await detail(e, cell)).body;
    expect(before.canBuild.map((k) => k.kind)).toContain("sacred");
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: "sacred" }, e)).status).toBe(200);
    t.advance(2 * HOUR); // (built)
    const after = (await detail(e, cell)).body;
    expect(after.building!.kind).toBe("sacred");
    expect(after.bonus.fort).toBeCloseTo(before.bonus.fort + 0.2 + 0.1);
    expect(after.bonus.yieldBoost).toBeCloseTo(before.bonus.yieldBoost + 0.15);
  });

  it("is an elf's only, with the talent", async () => {
    const a = await ready();
    const cell = await settle(a, 15, [], (c) => c.terrain === "park" || c.terrain === "forest");
    expect((await detail(a, cell)).body.canBuild.map((k) => k.kind)).not.toContain("sacred");
    await give("a@example.com", { scrap_wood: 500, log: 500 });
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: "sacred" }, a)).status).toBe(403);
  });
});

describe("拼裝改造 (哥布林工匠's top talent)", () => {
  it("refines a piece into a ★ one for all it was made from; it stays ★ wherever it goes", async () => {
    const a = await ready();
    const [r] = await database.sql`select id from camp_residents where place = 'home' and user_id = (select id from users where email = 'a@example.com') limit 1`;
    await database.sql`update camp_residents set gear = '{"weapon": {"id": "bone_knife", "left": 50}}'::jsonb where id = ${r!.id} and user_id = (select id from users where email = 'a@example.com')`;
    await give("a@example.com", { rat_fang: 10, rat_tail: 5 });
    const cmd = (c: Record<string, unknown>) => t.call("POST", "/camp/commands", c, a);
    expect((await cmd({ kind: "refine", resident: r!.id, slot: "weapon" })).body.error).toBe("not_allowed");
    await database.sql`update world_players set talents = '{"g_tinker.refine": 1}'::jsonb`;
    expect((await camp(a)).canRefine).toBe(true);
    let res = await cmd({ kind: "refine", resident: r!.id, slot: "weapon" });
    expect(res.status).toBe(200);
    let c = res.body.camp as CampView;
    expect(c.residents.find((x) => x.id === r!.id)!.gear!.weapon).toMatchObject({ id: "bone_knife", left: 120, refined: true });
    expect(c.materials).toMatchObject({ rat_fang: 6, rat_tail: 4 }); // (a bone knife: 4 fangs, 1 tail)
    expect((await cmd({ kind: "refine", resident: r!.id, slot: "weapon" })).body.error).toBe("not_allowed"); // (once)
    res = await cmd({ kind: "unequip", resident: r!.id, slot: "weapon" });
    c = res.body.camp as CampView;
    expect(c.armory.find((x) => x.id === "bone_knife")).toMatchObject({ refined: true, held: true });
  });
});

describe("monsters raiding held cells", () => {
  it("kill a few of a garrison as the days go by, and the cell's history says so", async () => {
    const a = await ready();
    await database.sql`update world_players set xp = 120050`; // (Lv50: raids come often)
    const cell = await settle(a, 25);
    const before = (await database.sql`select count(*)::int n from camp_residents where place = ${`cell:${cell}`} and died_at is null`)[0]!.n as number;
    t.advance(2 * 24 * HOUR);
    const d = (await t.call("GET", `/world/cells/${cell}`, undefined, a)).body as CellDetail;
    const raids = d.history.filter((h) => h.kind === "raided");
    expect(raids.length).toBeGreaterThan(0);
    const fell = raids.reduce((n, h) => n + (h.fallen ?? 0), 0);
    expect(fell).toBeGreaterThan(0);
    expect(fell).toBeLessThan(before / 2); // (a few, not the lot)
    expect(d.garrison).toBeGreaterThan(0);
  });
});

describe("細分地形 on the map and on a held cell (WORLD.md §29)", () => {
  it("cells carry their detail, the same on the map, the cell's page and the territory list; it adds to the yields", async () => {
    const a = await ready();
    const around = await map(a);
    const withDetail = around.filter((c) => c.detail);
    expect(withDetail.length).toBeGreaterThan(around.length / 10); // (the stand-in gives a quarter of the cells one)
    const cell = await settle(a, 20, [], (c) => !!c.detail && !c.lair);
    const detail = around.find((c) => c.cell === cell)!.detail!;
    expect(((await t.call("GET", `/world/cells/${cell}`, undefined, a)).body as CellDetail).detail).toBe(detail);
    expect(((await t.call("GET", "/world/territory", undefined, a)).body as TerritoryList).items.find((c) => c.cell === cell)!.detail).toBe(detail);
    // a day of yields: what the detail adds shows up (its first yield is a sure one: DETAIL_YIELD chance 1, or close)
    t.advance(24 * HOUR);
    const d = (await t.call("GET", `/world/cells/${cell}`, undefined, a)).body as CellDetail;
    const got = d.history.filter((h) => h.kind === "yield").flatMap((h) => Object.keys(h.loot ?? {}));
    const { DETAIL_YIELD } = await import("@goblincamp/shared/world");
    expect(DETAIL_YIELD[detail].some((y) => got.includes(y.id))).toBe(true);
  });

  it("offers its 細分地形's buildings and those of anywhere; a 哨站 keeps wild monsters away", async () => {
    const a = await ready();
    const cell = await settle(a, 20, [], (c) => !!c.detail && !c.lair);
    const detail = (await map(a)).find((c) => c.cell === cell)!.detail!;
    const { detailBuildingsFor, cellBonus } = await import("@goblincamp/shared/world");
    const offered = ((await t.call("GET", `/world/cells/${cell}`, undefined, a)).body as CellDetail).canBuild.map((b) => b.kind);
    for (const r of detailBuildingsFor(detail)) expect(offered).toContain(r.kind);
    await give("a@example.com", { scrap_wood: 100, log: 100 });
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: "outpost" }, a)).status).toBe(200);
    expect(((await t.call("GET", `/world/cells/${cell}`, undefined, a)).body as CellDetail).building?.name).toBe("哨站");
    // (a 細分地形 building of another kind of ground cannot go here)
    const other = (await import("@goblincamp/shared/world")).DETAIL_BUILDINGS.find((r) => r.detail !== "any" && r.detail !== detail)!;
    expect((await t.call("POST", `/world/cells/${cell}/build`, { kind: other.kind }, a)).status).toBeGreaterThanOrEqual(400);
    expect(cellBonus("goblin", { kind: "outpost", level: 1 }, 0).wild).toBeCloseTo(0.2);
  });
});
