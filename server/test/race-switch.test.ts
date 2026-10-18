import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import { cellAt, cellDistance, cellsWithin, cellCenter, neighbors, type RaceSwitchView, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
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

const camp = async (auth: Record<string, string>) => (await t.call("GET", "/camp", undefined, auth)).body as CampView;
const me = async (auth: Record<string, string>) => (await t.call("GET", "/world", undefined, auth)).body as WorldMe;
const view = async (auth: Record<string, string>) => (await t.call("GET", "/world/race", undefined, auth)).body as RaceSwitchView;
const userOf = async (email: string) => ((await database.sql`select id from users where email = ${email}`) as unknown as { id: string }[])[0]!.id;
const rich = { log: 20000, stone: 20000, crystal_shard: 100, amber: 30, token_elf: 5, token_undead: 10 };

/** A goblin camp in the big world at race level 20, with two cells in its ring and six beyond it, ten residents on each. */
async function veteran(email: string) {
  const password = await signUp(t, email);
  const auth = bearer((await logIn(t, email, password, mac(1))).body.token);
  await t.call("POST", "/camp/start", { race: "goblin" }, auth);
  t.advance(16 * HOUR);
  const home = cellAt(DAAN);
  expect((await t.call("POST", "/world/open", { cell: home }, auth)).status).toBe(201);
  const user = await userOf(email);
  await database.sql`update world_players set xp = 18050, talents = '{"g_raid.sharp": 1}'::jsonb where user_id = ${user}`;
  const ring = neighbors(home).slice(0, 2);
  const far = cellsWithin(cellCenter(home), 1500).filter((c) => cellDistance(c, home) >= 3).slice(0, 6);
  const ids = ((await database.sql`select id from camp_residents where user_id = ${user} and died_at is null and place = 'home' order by id`) as unknown as { id: number }[]).map((r) => r.id);
  expect(ids.length).toBeGreaterThan(100);
  const at = new Date(t.now().getTime() - 3 * HOUR).toISOString();
  const now = t.now().toISOString();
  for (const [i, cell] of [...ring, ...far].entries()) {
    await database.sql`insert into world_cells (cell, owner, held_since, nest_started_at, yielded_to, cleared_at) values (${cell}, ${user}, ${at}, ${at}, ${now}, ${at})
      on conflict (cell) do update set owner = excluded.owner, held_since = excluded.held_since, nest_started_at = excluded.nest_started_at, yielded_to = excluded.yielded_to`;
    const ten = ids.slice(i * 10, i * 10 + 10);
    await database.sql`update camp_residents set place = ${`cell:${cell}`} where user_id = ${user} and id in ${database.sql(ten)}`;
  }
  return { auth, user, home, ring, far };
}

describe("換族", () => {
  it("shows what it costs and takes, and waits for the materials and 信物", async () => {
    const { auth } = await veteran("a@example.com");
    const v = await view(auth);
    expect(v).toMatchObject({ race: "goblin", level: 20, first: true, levelAfter: 16, farCells: 6, cellsLost: 1, readyAt: null, talentPoints: 1 });
    expect(v.options.map((o) => o.race)).toEqual(["elf", "undead", "beast"]);
    const elf = v.options.find((o) => o.race === "elf")!;
    expect(elf.price).toContainEqual({ id: "log", name: "木材", need: 5000, have: expect.any(Number) });
    expect(elf.price).toContainEqual({ id: "token_elf", name: "古樹之種", need: 5, have: 0 });
    expect(elf.problem).toMatch(/不夠/);
    expect((await t.call("POST", "/world/race", { race: "elf" }, auth)).status).toBe(409);
    expect((await t.call("POST", "/world/race", { race: "orc" }, auth)).status).toBe(400);
  });

  it("switches: the far land, the residents, the level and talents shrink; the ring stays; then waits 14 days", async () => {
    const { auth, user, home, ring, far } = await veteran("a@example.com");
    await database.sql`update camps set materials = ${JSON.stringify(rich)}::jsonb, princess_name = 'Mira' where user_id = ${user}`;
    const before = await camp(auth);
    const alive = before.residents.length;
    const res = await t.call("POST", "/world/race", { race: "elf" }, auth);
    expect(res.status).toBe(200);
    expect(res.body.switched).toMatchObject({ from: "goblin", to: "elf", levelFrom: 20, levelTo: 16 });
    const after = await camp(auth);
    expect(after.race).toBe("elf");
    expect(after.princessName).toBe("");
    // a quarter of every place goes (each cell 10 → 8; home a quarter), their gear to the store
    expect(after.residents.length).toBeLessThan(alive);
    expect(after.residents.length).toBeGreaterThanOrEqual(Math.floor(alive * 0.75) - 2);
    expect(after.residents.every((r) => r.diesAt !== null)).toBe(true); // (elves age)
    // the price is paid (half, the first time)
    expect(after.materials.log).toBe(15000);
    expect(after.materials.token_elf ?? 0).toBe(0);
    // the ring stays, one far cell of six is given up
    const w = res.body.me as WorldMe;
    const held = w.cells.map((c) => c.cell);
    expect(held).toContain(home);
    for (const c of ring) expect(held).toContain(c);
    expect(far.filter((c) => !held.includes(c))).toHaveLength(1);
    expect(w.level).toBe(16);
    expect(w.talents?.picks).toEqual({});
    for (const c of held) if (c !== home) expect(after.residents.filter((r) => r.place === `cell:${c}`).length).toBeGreaterThanOrEqual(3); // (elves keep 3)

    // no burst of births at the new pace
    t.advance(HOUR);
    expect((await camp(auth)).residents.length - after.residents.length).toBeLessThan(15);

    // the next one waits 14 days, and then costs the full price and takes twice as much
    let again = await t.call("POST", "/world/race", { race: "undead" }, auth);
    expect(again.status).toBe(409);
    expect(again.body.message).toMatch(/14 天/);
    t.advance(14 * DAY);
    const v = await view(auth);
    expect(v).toMatchObject({ race: "elf", first: false });
    expect(v.levelAfter).toBe(v.level - Math.floor((v.level * 2) / 5));
    again = await t.call("POST", "/world/race", { race: "undead" }, auth);
    expect(again.status).toBe(200);
    const undead = await camp(auth);
    expect(undead.race).toBe("undead");
    expect(undead.residents.every((r) => r.diesAt === null)).toBe(true);
  });

  it("waits for parties on the road", async () => {
    const { auth, user, home } = await veteran("a@example.com");
    await database.sql`update camps set materials = ${JSON.stringify(rich)}::jsonb where user_id = ${user}`;
    await database.sql`insert into expeditions (user_id, kind, from_place, to_cell, party, set_out_at, arrive_at) values (${user}, 'move', 'home', ${home}, '[]', ${t.now().toISOString()}, ${new Date(t.now().getTime() + HOUR).toISOString()})`;
    const res = await t.call("POST", "/world/race", { race: "beast" }, auth);
    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/路上/);
  });
});
