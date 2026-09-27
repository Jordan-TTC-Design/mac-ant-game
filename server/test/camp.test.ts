import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { advance, startHome, type CampView } from "@goblincamp/shared/camp";
import type { Database } from "../src/db/client.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

const HOUR = 3_600_000;
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

async function account(email = "a@example.com") {
  const password = await signUp(t, email);
  return bearer((await logIn(t, email, password, mac(email === "a@example.com" ? 1 : 2))).body.token);
}

/** Who fell in raids so far (the shared birth-and-death rules know nothing of raids: those are the server's). */
async function raidFallen(auth: Record<string, string>): Promise<Set<number>> {
  const events = (await t.call("GET", "/camp/events?since=0", undefined, auth)).body.events as { kind: string; data: { fallen?: number[] } }[];
  return new Set(events.filter((e) => e.kind === "raid").flatMap((e) => e.data.fallen ?? []));
}

async function view(auth: Record<string, string>): Promise<CampView> {
  const res = await t.call("GET", "/camp", undefined, auth);
  expect(res.status).toBe(200);
  return res.body;
}

describe("a new camp", () => {
  it("starts with the two who carry the princess in, once per account", async () => {
    const me = await account();
    expect((await t.call("GET", "/camp", undefined, me)).status).toBe(404);
    const made = await t.call("POST", "/camp/start", { race: "goblin" }, me);
    expect(made.status).toBe(201);
    expect(made.body).toMatchObject({ race: "goblin", stage: 1, peak: 2, nextId: 3, nextSlot: 1 });
    expect(made.body.residents).toHaveLength(2);
    expect((await t.call("POST", "/camp/start", { race: "elf" }, me)).status).toBe(409);
    expect((await t.call("POST", "/camp/start", { race: "orc" }, me)).status).toBe(400);
  });

  it("grows one goblin every 5 minutes, exactly as the shared rules (and an offline Mac) work it out", async () => {
    const me = await account();
    const start = (await t.call("POST", "/camp/start", { race: "goblin" }, me)).body as CampView;
    t.advance(3 * HOUR);
    const now = await view(me);
    expect(now.version).toBeGreaterThan(start.version);

    const { place, population } = startHome("goblin", start.seed, Date.parse(start.startedAt));
    advance(place, population, start.seed, Date.parse(start.startedAt) + 3 * HOUR);
    expect(population.residents).toHaveLength(2 + 36);
    const fallen = await raidFallen(me);
    const expected = population.residents.filter((r) => !fallen.has(r.id)).map((r) => [r.id, r.breed, r.seed]);
    expect(now.residents.map((r) => [r.id, r.breed, r.seed])).toEqual(expected);
  });

  it("gives the same camp whether it is looked at often or once", async () => {
    const often = await account("a@example.com");
    await t.call("POST", "/camp/start", { race: "goblin" }, often);
    for (let i = 0; i < 12; i++) {
      t.advance(HOUR);
      await view(often);
    }
    const a = await view(often);
    // the same camp worked out in one go, raids and all (the server's own code, from scratch)
    const once = await account("b@example.com");
    const seedRow = await database.sql<{ seed: number; started_at: Date }[]>`select seed, started_at from camps where user_id = (select id from users where email = 'a@example.com')`;
    await database.sql`insert into camps (user_id, race, seed, started_at, advanced_to, next_slot, next_id, peak)
      select id, 'goblin', ${seedRow[0]!.seed}, ${seedRow[0]!.started_at}, ${seedRow[0]!.started_at}, 1, 3, 2 from users where email = 'b@example.com'`;
    await database.sql`insert into camp_residents (user_id, id, breed, seed, born_at, dies_at)
      select (select id from users where email = 'b@example.com'), id, breed, seed, born_at, dies_at from camp_residents
      where user_id = (select id from users where email = 'a@example.com') and id <= 2`;
    const b = await view(once);
    expect(b.residents.map((r) => [r.id, r.breed])).toEqual(a.residents.map((r) => [r.id, r.breed]));
    expect(b.materials).toEqual(a.materials);
    expect(b.peak).toBe(a.peak);
  });

  it("fills to the race's cap, reaches the third look, and loses the old to age", async () => {
    const me = await account();
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    t.advance(30 * HOUR);
    const full = await view(me);
    // full is 300; a raid or an old one dying can leave it a few short until the next birth slots
    expect(full.residents.length).toBeGreaterThan(285);
    expect(full.residents.length).toBeLessThanOrEqual(300);
    expect(full.peak).toBeGreaterThan(285);
    expect(full.stage).toBe(3);
    t.advance(30 * HOUR);
    const later = await view(me);
    // the dead are replaced on the next 5-minute birth slots, so a full camp can be a few short at any moment
    expect(later.residents.length).toBeGreaterThan(280);
    expect(later.residents.length).toBeLessThanOrEqual(300);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, me)).body.events;
    const died = events.filter((e: { kind: string }) => e.kind === "population").flatMap((e: { data: { died: unknown[] } }) => e.data.died);
    expect(died.length).toBeGreaterThan(0);
  });

  it("follows each race's pace", async () => {
    const elf = await account("a@example.com");
    await t.call("POST", "/camp/start", { race: "elf" }, elf);
    const undead = await account("b@example.com");
    await t.call("POST", "/camp/start", { race: "undead" }, undead);
    t.advance(2 * HOUR);
    expect((await view(elf)).residents).toHaveLength(2 + 12);
    expect((await view(undead)).residents).toHaveLength(2 + 16);
  });

  it("keeps each account's camp to itself", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    await t.call("POST", "/camp/start", { race: "goblin" }, a);
    expect((await t.call("GET", "/camp", undefined, b)).status).toBe(404);
    expect((await t.call("GET", "/camp/events?since=0", undefined, b)).body.events).toHaveLength(0);
  });

  it("starts over with 開新世界", async () => {
    const me = await account();
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    t.advance(5 * HOUR);
    await view(me);
    const fresh = await t.call("POST", "/camp/new-world", { race: "elf" }, me);
    expect(fresh.status).toBe(201);
    expect(fresh.body).toMatchObject({ race: "elf", peak: 2 });
    expect(fresh.body.residents).toHaveLength(2);
  });

  it("needs a signed-in device", async () => {
    expect((await t.call("GET", "/camp")).status).toBe(401);
  });
});

describe("moving an old camp in", () => {
  const goblin = (id: number, age: number, extra: Record<string, unknown> = {}) => ({ id, breed: "common", age, seed: String(18_000_000_000_000_000_000n + BigInt(id)), name: `咕嚕${id}`, ...extra });

  it("keeps who lived there (names, gear, the story) within the caps", async () => {
    const me = await account();
    const goblins = [
      ...Array.from({ length: 350 }, (_, i) => goblin(i + 1, 1000 + i * 100)),
      goblin(999, 10, { breed: "brute", gear: { weapon: "bone_knife", shield: { id: "wood_shield", left: 0.4 } } }),
      goblin(1000, 20, { breed: "made_up" }),
    ];
    const res = await t.call("POST", "/camp/migrate", {
      race: "goblin",
      save: {
        goblins,
        princessName: "艾莉雅",
        materials: { slime_goo: 999, rat_fang: 12, nothing: 0 },
        larder: { fish: 40 },
        armoryItems: Array.from({ length: 15 }, () => ({ id: "bone_knife", left: 0.8 })),
        peak: 900,
        romance: { stage: "dating", affection: 40 },
        delivered: 5000,
      },
    }, me);
    expect(res.status).toBe(201);
    const camp = res.body as CampView;
    expect(camp.residents).toHaveLength(300); // the goblin cap; the oldest went
    expect(camp.residents.some((r) => r.id === 350)).toBe(false);
    expect(camp.peak).toBe(300); // not the 900 the save said
    expect(camp.stage).toBe(3);
    expect(camp.materials).toEqual({ slime_goo: 200, rat_fang: 12 });
    expect(camp.larder).toEqual({ fish: 16 });
    expect(camp.armory).toHaveLength(10);
    expect(camp).toMatchObject({ princessName: "艾莉雅", romance: { stage: "dating", affection: 40 }, delivered: 5000 });
    const brute = camp.residents.find((r) => r.id === 999)!;
    expect(brute).toMatchObject({ breed: "brute", name: "咕嚕999", legacySeed: "18000000000000000999", gear: { weapon: { id: "bone_knife", left: 1 }, shield: { id: "wood_shield", left: 0.4 } } });
    expect(camp.residents.find((r) => r.id === 1000)!.breed).toBe("common"); // (a breed the race does not have)
    expect(camp.nextId).toBe(1001);
  });

  it("asks before replacing the account's camp (a second Mac)", async () => {
    const me = await account();
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    const save = { goblins: [goblin(1, 100)] };
    expect((await t.call("POST", "/camp/migrate", { race: "goblin", save }, me)).status).toBe(409);
    const replaced = await t.call("POST", "/camp/migrate", { race: "goblin", replace: true, save }, me);
    expect(replaced.status).toBe(201);
    expect(replaced.body.residents).toHaveLength(1);
  });

  it("goes on growing from where the old camp was", async () => {
    const me = await account();
    await t.call("POST", "/camp/migrate", { race: "goblin", save: { goblins: [goblin(1, 100), goblin(2, 100)] } }, me);
    t.advance(HOUR);
    const camp = await view(me);
    expect(camp.residents).toHaveLength(2 + 12);
    expect(camp.residents.at(-1)!.id).toBe(14);
  });
});

describe("monster raids", () => {
  it("come every hour and a half or so once the camp has ten, and are fought by the server", async () => {
    const me = await account();
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    t.advance(24 * HOUR);
    const camp = await view(me);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, me)).body.events as { kind: string; at: string; data: Record<string, unknown> }[];
    const raids = events.filter((e) => e.kind === "raid");
    expect(raids.length).toBeGreaterThanOrEqual(10);
    expect(raids.length).toBeLessThanOrEqual(22);
    const raid = raids.at(-1)!.data as { monsters: { id: string; count: number }[]; defenders: number[]; fallen: number[]; killed: Record<string, number>; loot: Record<string, number>; winner: string; events: unknown[] };
    expect(raid.defenders.length).toBeGreaterThan(0);
    expect(raid.winner).toBe("camp");
    expect(raid.events.length).toBeGreaterThan(0); // the blows, for the Mac to play
    // what the monsters dropped and how many fell went into the books
    const lootTotal = raids.reduce((n, e) => n + Object.values((e.data as { loot: Record<string, number> }).loot).reduce((a, b) => a + b, 0), 0);
    expect(Object.values(camp.materials).reduce((a, b) => a + b, 0)).toBe(lootTotal);
    const killedTotal = raids.reduce((n, e) => n + Object.values((e.data as { killed: Record<string, number> }).killed).reduce((a, b) => a + b, 0), 0);
    expect(Object.values(camp.kills).reduce((a, b) => a + b, 0)).toBe(killedTotal);
    // and those who fell are gone
    const fallen = await raidFallen(me);
    for (const r of camp.residents) expect(fallen.has(r.id)).toBe(false);
  });

  it("do not come to a camp of fewer than ten", async () => {
    const me = await account();
    await t.call("POST", "/camp/migrate", { race: "goblin", save: { goblins: [{ id: 1, breed: "common", age: 10, seed: "1" }] } }, me);
    t.advance(40 * 60_000); // 40 minutes: 9 residents
    await view(me);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, me)).body.events as { kind: string }[];
    expect(events.filter((e) => e.kind === "raid")).toHaveLength(0);
  });
});

