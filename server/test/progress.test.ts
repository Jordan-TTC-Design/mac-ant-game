import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
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
