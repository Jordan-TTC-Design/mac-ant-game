import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { buildingsFor, cellAt, cellBonus, CELL_BUILDING_COSTS, CELL_BUILDINGS, standInLandmark, neighbors, type CellDetail, type CellView, type ExpeditionReport, type TerritoryList, type WorldMe } from "@goblincamp/shared/world";
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
  it("the first three besides the camp are free; the rest eat rations every yield, and go hungry without", async () => {
    const a = await ready();
    const home = (await me(a)).homeCell!;
    const around = neighbors(home);
    const at = t.now().toISOString();
    for (const c of around) await database.sql`insert into world_cells (cell, cleared_at) values (${c}, ${at}::timestamptz) on conflict (cell) do update set cleared_at = ${at}::timestamptz`;
    const cells: string[] = [];
    for (let i = 0; i < 4; i++) {
      cells.push(await settle(a, 10, [], (c) => c.cell === around[i]));
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
