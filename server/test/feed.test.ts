import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { FeedResponse } from "@goblincamp/shared/camp";
import type { Database } from "../src/db/client.ts";
import { tellPomodoros } from "../src/pomodoro/routes.ts";
import { bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

const MIN = 60_000;
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

describe("動態", () => {
  it("tells what happened, a line each, newest first, births in a run as one, and pages back", async () => {
    const password = await signUp(t, "a@example.com");
    const me = bearer((await logIn(t, "a@example.com", password, mac(1))).body.token);
    await t.call("POST", "/camp/start", { race: "elf" }, me);
    t.advance(31 * MIN); // births at home
    await t.call("GET", "/camp", undefined, me);
    t.advance(31 * MIN);
    await t.call("GET", "/camp", undefined, me);
    await t.call("POST", "/camp/commands", { kind: "merchant-arrive" }, me);
    await t.call("POST", "/camp/commands", { kind: "decor-set", items: [] }, me); // (no line)
    await t.call("POST", "/camp/commands", { kind: "ranch-sync", animals: [{ id: 1, kind: "rabbit", caught: true }], minutes: 0, butchered: [] }, me);
    await t.call("POST", "/camp/commands", { kind: "ranch-sync", animals: [{ id: 1, kind: "rabbit", caught: true }, { id: 2, kind: "rabbit" }], minutes: 0, butchered: [] }, me);
    await t.call("POST", "/pomodoro", { action: "start", plan: { focusMinutes: 25, restMinutes: 5, rounds: 4, longRestMinutes: 15 } }, me);
    t.advance(25 * MIN + 1000);
    await tellPomodoros(t.app.deps, t.now());

    const feed = (await t.call("GET", "/camp/feed", undefined, me)).body as FeedResponse;
    const lines = feed.entries.map((e) => `${e.icon} ${e.text}`);
    expect(lines[0]).toBe("🍅 專注完一輪 25 分鐘（今天第 1 輪）。");
    expect(lines[1]).toBe("🐑 牧場：兔子出生了。");
    expect(lines[2]).toBe("🐑 牧場：抓到兔子。");
    expect(lines[3]).toMatch(/^🛒 松鼠商隊來了/);
    expect(lines.filter((l) => l.startsWith("🐣"))).toHaveLength(1); // (the births in a run: one line)
    expect(lines[4]).toMatch(/^🐣 生了 \d+ 隻精靈。$/);
    expect(lines.at(-1)).toBe("🏕️ 營地開張了！");
    expect(feed.more).toBe(false);

    const first = (await t.call("GET", "/camp/feed?limit=2", undefined, me)).body as FeedResponse;
    expect(first.entries).toHaveLength(2);
    expect(first.more).toBe(true);
    const older = (await t.call("GET", `/camp/feed?limit=2&before=${first.entries[1]!.seq}`, undefined, me)).body as FeedResponse;
    expect(older.entries[0]!.text).toBe("牧場：抓到兔子。");
    expect((await t.call("GET", "/camp/feed?limit=0", undefined, me)).status).toBe(400);
  });
});
