import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { CampView } from "@goblincamp/shared/camp";
import type { Database } from "../src/db/client.ts";
import { economyReport } from "../src/camp/economy.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

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

describe("the economy dashboard", () => {
  it("writes down every change to a camp's materials, and adds them up by source and material", async () => {
    const password = await signUp(t, "a@example.com");
    const me = bearer((await logIn(t, "a@example.com", password, mac(1))).body.token);
    await t.call("POST", "/camp/start", { race: "goblin" }, me);
    await database.sql`update camps set materials = '{"log": 100, "stone": 50}'`;
    // spending: a lumber camp costs 10 logs
    const built = await t.call("POST", "/camp/commands", { kind: "site-build", site: "lumber" }, me);
    expect(built.status).toBe(200);
    // time goes by: the sites gather
    t.advance(5 * 3_600_000);
    const camp = (await t.call("GET", "/camp", undefined, me)).body as CampView;

    const report = await economyReport(database.db, t.now(), 7);
    expect(report.players).toMatchObject({ camps: 1, active: 1, byRace: { goblin: 1 } });
    const build = report.flows.find((f) => f.source === "site-build")!;
    expect(build).toMatchObject({ name: "蓋工地", in: 0, out: 10 });
    const made = report.flows.find((f) => f.source === "production")!;
    expect(made.in).toBeGreaterThan(0);
    const log = report.materials.find((m) => m.id === "log")!;
    expect(log.total).toBe(camp.materials.log);
    expect(log.out).toBe(10);
    expect(log.holders).toBe(1);
    expect(report.daily.reduce((n, d) => n + d.out, 0)).toBe(10);
    // the camp's own feed and events leave the flows out
    const events = (await t.call("GET", "/camp/events?since=0", undefined, me)).body.events as { kind: string }[];
    expect(events.some((e) => e.kind === "flow")).toBe(false);
  });
});
