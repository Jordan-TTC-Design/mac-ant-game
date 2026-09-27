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
      goblin(999, 10, { breed: "brute", gear: { weapon: "bone_knife", shield: { id: "wood_shield", left: 7 }, head: "made_up_hat" } }),
      goblin(1000, 20, { breed: "made_up" }),
    ];
    const res = await t.call("POST", "/camp/migrate", {
      race: "goblin",
      save: {
        goblins,
        princessName: "艾莉雅",
        materials: { slime_goo: 999, rat_fang: 12, nothing: 0 },
        larder: { fish: 40 },
        armoryItems: Array.from({ length: 15 }, () => ({ id: "bone_knife", left: 90 })),
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
    // the store keeps 10 knives; the camp then hands them out to those with no weapon (so the store may be empty again)
    expect(camp.armory.length + camp.residents.filter((r) => r.gear?.weapon?.id === "bone_knife").length).toBe(11);
    expect(camp).toMatchObject({ princessName: "艾莉雅", romance: { stage: "dating", affection: 40 }, delivered: 5000 });
    const brute = camp.residents.find((r) => r.id === 999)!;
    // wear points as the Mac saved them (a plain id is a new piece); gear the workshop does not know is dropped
    expect(brute).toMatchObject({ breed: "brute", name: "咕嚕999", legacySeed: "18000000000000000999", gear: { weapon: { id: "bone_knife", left: 120 }, shield: { id: "wood_shield", left: 7 } } });
    expect(brute.gear!.head).toBeUndefined();
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

describe("commands", () => {
  async function campWith(materials: Record<string, number>, race = "goblin", n = 6) {
    const me = await account();
    const goblins = Array.from({ length: n }, (_, i) => ({ id: i + 1, breed: i === 0 ? "brute" : "common", age: 100, seed: String(i + 1) }));
    await t.call("POST", "/camp/migrate", { race, save: { goblins, materials } }, me);
    return me;
  }
  const cmd = (auth: Record<string, string>, command: Record<string, unknown>) => t.call("POST", "/camp/commands", command, auth);

  it("crafts a piece for whoever needs it most, and spends the materials", async () => {
    const me = await campWith({ rat_fang: 10, rat_tail: 3 });
    const res = await cmd(me, { kind: "craft", gear: "bone_knife" });
    expect(res.status).toBe(200);
    const camp = res.body.camp as CampView;
    expect(camp.materials).toEqual({ rat_fang: 6, rat_tail: 2 });
    const armed = camp.residents.filter((r) => r.gear?.weapon);
    expect(armed.map((r) => r.id)).toEqual([1]); // the brute: the strongest of those with no weapon
    expect(armed[0]!.gear!.weapon).toEqual({ id: "bone_knife", left: 120 });
  });

  it("refuses what the camp cannot afford, or what nobody needs", async () => {
    const me = await campWith({ rat_fang: 4, rat_tail: 1, scrap_rag: 100 }, "goblin", 1);
    expect((await cmd(me, { kind: "craft", gear: "long_sword" })).body.error).toBe("not_enough");
    expect((await cmd(me, { kind: "craft", gear: "gold_crown" })).body.error).toBe("unknown_gear");
    expect((await cmd(me, { kind: "craft", gear: "cloth_cap" })).status).toBe(200);
    const again = await cmd(me, { kind: "craft", gear: "cloth_cap" }); // the only resident already has one as good
    expect(again.status).toBe(409);
    expect(again.body.error).toBe("nobody_needs");
    expect(again.body.camp.materials.scrap_rag).toBe(97); // nothing spent
  });

  it("mends a worn piece for a third of its materials", async () => {
    const me = await account();
    await t.call("POST", "/camp/migrate", {
      race: "goblin",
      save: { goblins: [{ id: 1, breed: "common", age: 100, seed: "1", gear: { weapon: { id: "long_sword", left: 30 } } }], materials: { scrap_iron: 2, rat_pelt: 1, scrap_wood: 1 } },
    }, me);
    const res = await cmd(me, { kind: "repair", resident: 1, slot: "weapon" });
    expect(res.status).toBe(200);
    expect(res.body.camp.residents[0].gear.weapon).toEqual({ id: "long_sword", left: 200 });
    expect(res.body.camp.materials).toEqual({}); // 6 iron → 2, 2 pelts → 1, 1 wood → 1
    expect((await cmd(me, { kind: "repair", resident: 1, slot: "shield" })).body.error).toBe("not_found");
  });

  it("puts food down with a cooldown, and only what the race can use", async () => {
    const me = await campWith({});
    const put = await cmd(me, { kind: "food", food: "meat" });
    expect(put.status).toBe(200);
    const camp = put.body.camp as CampView;
    expect(Date.parse(camp.boosts.meat!) - t.now().getTime()).toBe(48 * 60_000);
    expect(Date.parse(camp.foodCooldowns.meat!) - t.now().getTime()).toBe(20 * 60_000);
    expect((await cmd(me, { kind: "food", food: "meat" })).body.error).toBe("cooling_down");
    t.advance(21 * 60_000);
    const again = await cmd(me, { kind: "food", food: "meat" });
    expect(Date.parse(again.body.camp.boosts.meat) - t.now().getTime()).toBe(60 * 60_000); // up to an hour
    expect((await cmd(me, { kind: "food", food: "soul_blue" })).body.error).toBe("not_allowed");
  });

  it("gives the undead souls instead of food", async () => {
    const me = await campWith({}, "undead");
    expect((await cmd(me, { kind: "food", food: "soul_blue" })).status).toBe(200);
    expect((await cmd(me, { kind: "food", food: "meat" })).body.error).toBe("not_allowed");
  });

  it("lets the princess's child join the camp, not too often", async () => {
    const me = await campWith({});
    const born = await cmd(me, { kind: "princess-child", breed: "half_hum", parents: "艾莉雅 × 咕嚕" });
    expect(born.status).toBe(200);
    const child = (born.body.camp as CampView).residents.find((r) => r.id === born.body.resident)!;
    expect(child).toMatchObject({ breed: "half_hum", parents: "艾莉雅 × 咕嚕" });
    expect((await cmd(me, { kind: "princess-child", breed: "half_gob" })).body.error).toBe("too_soon");
    t.advance(5 * HOUR);
    expect((await cmd(me, { kind: "princess-child", breed: "half_gob" })).status).toBe(200);
  });

  it("does a command sent twice (same requestId) only once", async () => {
    const me = await campWith({ rat_fang: 10, rat_tail: 3 });
    const requestId = "11111111-2222-4333-8444-555555555555";
    const first = await cmd(me, { kind: "craft", gear: "bone_knife", requestId });
    const again = await cmd(me, { kind: "craft", gear: "bone_knife", requestId });
    expect(again.status).toBe(200);
    expect(again.body.message).toBe(first.body.message);
    expect(again.body.camp.materials).toEqual({ rat_fang: 6, rat_tail: 2 }); // spent once
    expect((await cmd(me, { kind: "craft", gear: "bone_knife", requestId: "11111111-2222-4333-8444-555555555556" })).body.camp.materials).toEqual({ rat_fang: 2, rat_tail: 1 });
  });

  it("names the princess and keeps her story", async () => {
    const me = await campWith({});
    expect((await cmd(me, { kind: "princess-name", name: "艾莉雅" })).body.camp.princessName).toBe("艾莉雅");
    expect((await cmd(me, { kind: "princess-name", name: "一個很長很長的名字喔" })).status).toBe(400);
    expect((await cmd(me, { kind: "story", romance: { stage: "married" } })).body.camp.romance).toEqual({ stage: "married" });
  });

  it("hands a fallen or old resident's gear back to the store, and on to the next", async () => {
    const me = await account();
    await t.call("POST", "/camp/migrate", {
      race: "goblin",
      save: { goblins: [{ id: 1, breed: "common", age: 47 * 3600, seed: "1", gear: { weapon: "long_sword" } }, { id: 2, breed: "common", age: 10, seed: "2" }] },
    }, me);
    t.advance(2 * 3600_000); // the old one dies; the sword goes to someone else
    const camp = await view(me);
    expect(camp.residents.some((r) => r.id === 1)).toBe(false);
    expect(camp.residents.filter((r) => r.gear?.weapon?.id === "long_sword")).toHaveLength(1);
  });

  it("wears gear down in raids", async () => {
    const me = await account();
    const goblins = Array.from({ length: 12 }, (_, i) => ({ id: i + 1, breed: "common", age: 10, seed: String(i + 1), gear: { weapon: "bone_knife", chest: "cloth_armor" } }));
    await t.call("POST", "/camp/migrate", { race: "goblin", save: { goblins } }, me);
    t.advance(10 * 3600_000);
    const camp = await view(me);
    const events = (await t.call("GET", "/camp/events?since=0", undefined, me)).body.events as { kind: string; data: { wear?: Record<string, unknown>; broken?: unknown[] } }[];
    const raids = events.filter((e) => e.kind === "raid");
    expect(raids.length).toBeGreaterThan(0);
    const worn = camp.residents.filter((r) => r.gear?.weapon && r.gear.weapon.left < 120);
    const brokeSomething = raids.some((e) => (e.data.broken ?? []).length > 0);
    expect(worn.length > 0 || brokeSomething).toBe(true);
  });
});

