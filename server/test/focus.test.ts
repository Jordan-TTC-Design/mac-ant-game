import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { FOCUS_RARE_ROUNDS, RARE_VISIT_SUFFIX, type CampView } from "@goblincamp/shared/camp";
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

/** Someone with a camp, signed in on a Mac. */
async function player() {
  const password = await signUp(t, "a@example.com");
  const me = bearer((await logIn(t, "a@example.com", password, mac(1))).body.token);
  expect((await t.call("POST", "/camp/start", { race: "goblin" }, me)).status).toBe(201);
  return me;
}

const view = async (me: Record<string, string>) => (await t.call("GET", "/camp", undefined, me)).body as CampView;
const focusEvents = async (me: Record<string, string>) =>
  ((await t.call("GET", "/camp/events?since=0", undefined, me)).body.events as { kind: string; data: { rounds: number; minutes: number } }[]).filter((e) => e.kind === "focus");
/** A quick run: focus 10 minutes, rest 2, `rounds` rounds, no long rest. */
const plan = (rounds: number) => ({ action: "start", plan: { focusMinutes: 10, restMinutes: 2, rounds, longRestMinutes: 0 } });

describe("專注", () => {
  it("counts a focus part that runs to its end, from the loop, once", async () => {
    const me = await player();
    expect((await t.call("POST", "/pomodoro", plan(2), me)).status).toBe(200);
    t.advance(10 * MIN + 1000);
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(1);
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(0); // (told already: not counted again)
    const v = await view(me);
    expect(v.focus).toMatchObject({ today: { rounds: 1, minutes: 10 }, rounds: 1, minutes: 10, bestDay: 1, next: { perk: "merchant", rounds: 2 } });
    expect(await focusEvents(me)).toMatchObject([{ data: { rounds: 1, minutes: 10 } }]);
  });

  it("does not count a skipped focus part, but does count one that ended before someone pressed a button", async () => {
    const me = await player();
    await t.call("POST", "/pomodoro", plan(3), me);
    t.advance(3 * MIN);
    await t.call("POST", "/pomodoro", { action: "skip" }, me); // focus 1 skipped: now resting
    expect((await view(me)).focus?.rounds ?? 0).toBe(0);
    t.advance(2 * MIN + 1000); // rest over by itself, focus 2 began
    t.advance(10 * MIN); // focus 2 over by itself, rest began (nobody looked)
    await t.call("POST", "/pomodoro", { action: "pause" }, me); // the Mac pauses: the server moves on first
    expect((await view(me)).focus).toMatchObject({ today: { rounds: 1 }, rounds: 1 });
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(0);
    expect((await view(me)).focus?.rounds).toBe(1);
  });

  it("counts the last focus part when a run ends on it, and every part missed while nobody was there", async () => {
    const me = await player();
    await t.call("POST", "/pomodoro", { action: "start", plan: { focusMinutes: 5, restMinutes: 0, rounds: 3, longRestMinutes: 0 } }, me);
    t.advance(15 * MIN + 1000);
    await tellPomodoros(t.app.deps, t.now());
    expect((await view(me)).focus).toMatchObject({ today: { rounds: 3, minutes: 15 }, perks: { merchant: true, ranch: false, rare: false } });
    expect((await focusEvents(me)).map((e) => e.data.rounds)).toEqual([1, 2, 3]);
    expect((await t.call("GET", "/pomodoro", undefined, me)).body.state).toBeNull();
  });

  it("brings the merchant once more after three rounds, and something rare after six", async () => {
    const me = await player();
    const arrive = () => t.call("POST", "/camp/commands", { kind: "merchant-arrive" }, me);
    for (let k = 0; k < 3; k++) {
      expect((await arrive()).status).toBe(200);
      t.advance(61 * MIN);
    }
    expect((await arrive()).status).toBe(409); // three a day
    await t.call("POST", "/pomodoro", { action: "start", plan: { focusMinutes: 5, restMinutes: 0, rounds: FOCUS_RARE_ROUNDS, longRestMinutes: 0 } }, me);
    t.advance(15 * MIN + 1000);
    await tellPomodoros(t.app.deps, t.now());
    const fourth = await arrive(); // three rounds done: one more today
    expect(fourth.status).toBe(200);
    expect(fourth.body.camp.merchant.id.endsWith(RARE_VISIT_SUFFIX)).toBe(false);
    expect(fourth.body.camp.merchant.stock.some((o: { rare?: boolean }) => o.rare)).toBe(false);
    t.advance(15 * MIN);
    await tellPomodoros(t.app.deps, t.now());
    expect((await view(me)).focus?.perks).toEqual({ merchant: true, ranch: true, rare: true });
    t.advance(61 * MIN);
    expect((await arrive()).status).toBe(409); // (still four a day)
  });

  it("puts a rare find in the stock of a visit on a day of six rounds", async () => {
    const me = await player();
    await t.call("POST", "/pomodoro", { action: "start", plan: { focusMinutes: 5, restMinutes: 0, rounds: FOCUS_RARE_ROUNDS, longRestMinutes: 0 } }, me);
    t.advance(30 * MIN + 1000);
    await tellPomodoros(t.app.deps, t.now());
    const came = await t.call("POST", "/camp/commands", { kind: "merchant-arrive" }, me);
    expect(came.status).toBe(200);
    const visit = (came.body.camp as CampView).merchant!;
    expect(visit.id.endsWith(RARE_VISIT_SUFFIX)).toBe(true);
    expect(visit.stock.at(-1)).toMatchObject({ rare: true });
  });

  it("earns a limited decoration with a day of four rounds: refused before, put down after the quest's reward is taken", async () => {
    const me = await player();
    const put = (kind: string) => t.call("POST", "/camp/commands", { kind: "decor-set", items: [{ kind, x: 10, y: 0 }] }, me);
    const refused = await put("g_tomatotower");
    expect(refused.status).toBe(409);
    expect(refused.body.message).toContain("任務獎勵");
    await t.call("POST", "/pomodoro", { action: "start", plan: { focusMinutes: 5, restMinutes: 0, rounds: 4, longRestMinutes: 0 } }, me);
    t.advance(20 * MIN + 1000);
    await tellPomodoros(t.app.deps, t.now());
    const claim = (quest: string) => t.call("POST", "/camp/commands", { kind: "quest-claim", quest }, me);
    expect((await claim("focus_day4")).status).toBe(409); // (the first of the chain first)
    expect((await claim("focus_1")).status).toBe(200);
    const day4 = await claim("focus_day4");
    expect(day4.status).toBe(200);
    expect(day4.body.message).toContain("番茄鐘塔");
    expect(day4.body.camp.decorEarned).toEqual(["g_tomatotower"]);
    expect((await put("g_tomatotower")).status).toBe(200);
    expect((await put("e_moondial")).status).toBe(409); // (another race's)
    expect((await put("g_goldthrone")).status).toBe(409); // (not earned yet)
  });
});
