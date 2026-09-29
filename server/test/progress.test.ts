import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { QUESTS, type CampView, type QuestView } from "@goblincamp/shared/camp";
import { cellAt, type CellView, type WorldMe } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

// 道具 and 任務: what a camp works towards in its first days (server/CAMP.md §20).
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
async function account(email = `p${macs}@example.com`) {
  const password = await signUp(t, email);
  return bearer((await logIn(t, email, password, mac(++macs))).body.token);
}
async function campWith(materials: Record<string, number>, n = 6, race = "goblin") {
  const me = await account();
  const goblins = Array.from({ length: n }, (_, i) => ({ id: i + 1, breed: "common", age: 100, seed: String(i + 1) }));
  await t.call("POST", "/camp/migrate", { race, save: { goblins, materials, peak: n } }, me);
  return me;
}
const cmd = (auth: Record<string, string>, command: Record<string, unknown>) => t.call("POST", "/camp/commands", command, auth);
const camp = async (auth: Record<string, string>) => (await t.call("GET", "/camp", undefined, auth)).body as CampView;

describe("道具", () => {
  it("are made in the workshop into the store; some wait for their quest", async () => {
    const me = await campWith({ scrap_rag: 4, frog_leg: 2, golden_frog_eye: 1, shiny_bead: 1 });
    const res = await cmd(me, { kind: "craft", gear: "item_bandage" });
    expect(res.status).toBe(200);
    expect((res.body.camp as CampView).materials).toEqual(expect.objectContaining({ item_bandage: 1, scrap_rag: 2, frog_leg: 1 }));
    // 幸運符 opens with the quest for ten lairs
    const locked = await cmd(me, { kind: "craft", gear: "item_charm" });
    expect(locked.status).toBe(409);
    expect(locked.body.message).toContain("任務");
    expect((await camp(me)).questsDone).toEqual([]);
  });

  it("are taken along on an expedition like boost food, and used up", async () => {
    const me = await account();
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    t.advance(16 * HOUR);
    await t.call("POST", "/world/open", { cell: cellAt(DAAN) }, me);
    await database.sql`update camps set materials = materials || '{"item_tonic": 3}'::jsonb`;
    const lair = ((await t.call("GET", `/world/cells?lat=${DAAN.lat}&lng=${DAAN.lng}&radius=800`, undefined, me)).body as CellView[]).find((c) => c.lair && !c.owner)!;
    const w = (await t.call("GET", "/world", undefined, me)).body as WorldMe;
    expect(w.food.item_tonic).toBe(3);
    const res = await t.call("POST", "/world/expeditions", { to: lair.cell, count: 5, supplies: { item_tonic: 1 } }, me);
    expect(res.status).toBe(201);
    expect((await camp(me)).materials.item_tonic).toBe(2);
  });
});

describe("任務", () => {
  const quests = async (auth: Record<string, string>) => (await t.call("GET", "/camp/quests", undefined, auth)).body.quests as QuestView[];

  it("shows each chain's first, and the next once the one before was claimed", async () => {
    const me = await campWith({}, 6);
    const list = await quests(me);
    const ids = list.map((q) => q.id);
    expect(ids).toContain("site_1");
    expect(ids).toContain("pop_60");
    expect(ids).not.toContain("lumber_2");
    expect(ids).not.toContain("pop_120");
    expect(QUESTS).toHaveLength(30);
    expect(list.find((q) => q.id === "pop_60")).toEqual(expect.objectContaining({ have: 6, need: 60, done: false, claimed: false }));
  });

  it("pays a finished one once: new residents, and the next of its chain shows", async () => {
    const me = await campWith({}, 60);
    expect((await cmd(me, { kind: "quest-claim", quest: "site_1" })).body.error).toBe("not_allowed"); // (not done)
    const before = (await camp(me)).residents.length;
    const res = await cmd(me, { kind: "quest-claim", quest: "pop_60" });
    expect(res.status).toBe(200);
    expect((res.body.camp as CampView).residents.length).toBe(before + 3);
    expect((res.body.camp as CampView).questsDone).toEqual(["pop_60"]);
    expect((await cmd(me, { kind: "quest-claim", quest: "pop_60" })).body.error).toBe("not_allowed"); // (once)
    const list = await quests(me);
    expect(list.find((q) => q.id === "pop_60")!.claimed).toBe(true);
    expect(list.map((q) => q.id)).toContain("pop_120");
    expect((await cmd(me, { kind: "quest-claim", quest: "pop_120" })).body.error).toBe("not_allowed");
  });

  it("gives gear into the store, handed out as usual", async () => {
    const me = await campWith({ rat_fang: 4, rat_tail: 1 }, 6);
    await cmd(me, { kind: "craft", gear: "bone_knife" });
    const res = await cmd(me, { kind: "quest-claim", quest: "armed_1" });
    expect(res.status).toBe(200);
    const c = res.body.camp as CampView;
    const clubs = c.residents.filter((r) => r.gear?.weapon?.id === "wood_club").length + c.armory.filter((g) => g.id === "wood_club").length;
    expect(clubs).toBe(2);
  });

  it("opens a 道具's recipe", async () => {
    const me = await campWith({ sticky_tongue: 2, slime_goo: 2 }, 6);
    expect((await cmd(me, { kind: "craft", gear: "item_sticky" })).status).toBe(409);
    await database.sql`update camps set kills = '{"giant_rat": 80, "slime": 30}'::jsonb`;
    expect((await quests(me)).find((q) => q.id === "raids_20")!.done).toBe(true);
    expect((await cmd(me, { kind: "quest-claim", quest: "raids_20" })).status).toBe(200);
    const next = (await quests(me)).find((q) => q.id === "raids_100")!;
    expect(next).toEqual(expect.objectContaining({ done: true, unlocks: "item_sticky" }));
    expect((await cmd(me, { kind: "quest-claim", quest: "raids_100" })).status).toBe(200);
    const made = await cmd(me, { kind: "craft", gear: "item_sticky" });
    expect(made.status).toBe(200);
    expect((made.body.camp as CampView).materials.item_sticky).toBe(1);
  });
});
