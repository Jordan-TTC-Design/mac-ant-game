import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { ChatResponse, ClaudeResponse, FriendsResponse, PomodoroResponse, ServerEvent } from "@goblincamp/shared";
import type { Database } from "../src/db/client.ts";
import { tellPomodoros } from "../src/pomodoro/routes.ts";
import { clearOld } from "../src/maintenance.ts";
import { APP_URL, bearer, emptyTables, logIn, mac, openTestDatabase, phone, signUp, testApp, type TestApp } from "./helpers.ts";

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

let macs = 0;
/** A person with a Mac and a phone (subscribed to pushes), and what their devices hear over the WebSocket. */
async function person(email: string) {
  const password = await signUp(t, email);
  const signedIn = (await logIn(t, email, password, mac(++macs))).body;
  const onMac = bearer(signedIn.token);
  const cookie = (await logIn(t, email, password, { ...phone, id: `00000000-0000-4000-9000-${String(macs).padStart(12, "0")}` })).headers.get("set-cookie")!.split(";")[0]!;
  const onPhone = { cookie, origin: APP_URL };
  await t.call("POST", "/push/subscribe", { endpoint: `https://push.example/${email}`, keys: { p256dh: "k", auth: "a" } }, onPhone);
  const heard: ServerEvent[] = [];
  t.app.deps.hub.add(signedIn.user.id, "test", { send: (d: string) => heard.push(JSON.parse(d)), close: () => {} });
  return { id: signedIn.user.id as string, code: signedIn.user.friendCode as string, onMac, onPhone, heard };
}
const pushesTo = (email: string) => t.push.sent.filter((p) => p.endpoint.endsWith(email)).map((p) => p.payload as { title: string; body: string; url: string });

describe("好友與訊息", () => {
  it("asks by code, says yes, writes; only friends can write; unread and read", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    // not friends yet
    expect((await t.call("POST", `/friends/${b.id}/messages`, { text: "嗨" }, a.onPhone)).status).toBe(403);
    expect((await t.call("POST", "/friends/asks", { code: "GOB-NOPE12" }, a.onPhone)).status).toBe(404);
    expect((await t.call("POST", "/friends/asks", { code: a.code }, a.onPhone)).status).toBe(400);

    expect((await t.call("POST", "/friends/asks", { code: b.code.toLowerCase() }, a.onPhone)).body.status).toBe("asked");
    expect(pushesTo("b@example.com").at(-1)!.title).toBe("有人想加你好友");
    expect(b.heard.some((e) => e.type === "friends.changed")).toBe(true);
    let fb = (await t.call("GET", "/friends", undefined, b.onPhone)).body as FriendsResponse;
    expect(fb.incoming.map((p) => p.id)).toEqual([a.id]);
    expect(((await t.call("GET", "/friends", undefined, a.onPhone)).body as FriendsResponse).outgoing.map((p) => p.id)).toEqual([b.id]);

    expect((await t.call("POST", `/friends/${a.id}/accept`, {}, b.onPhone)).body.status).toBe("friends");
    const sent = await t.call("POST", `/friends/${b.id}/messages`, { text: "  下午一起打魔王？  " }, a.onPhone);
    expect(sent.status).toBe(201);
    expect(sent.body.text).toBe("下午一起打魔王？");
    expect(pushesTo("b@example.com").at(-1)).toMatchObject({ body: "下午一起打魔王？", url: `/friends/${a.id}` });
    fb = (await t.call("GET", "/friends", undefined, b.onPhone)).body as FriendsResponse;
    expect(fb.friends[0]).toMatchObject({ id: a.id, unread: 1, last: { text: "下午一起打魔王？", mine: false } });

    const chat = (await t.call("GET", `/friends/${a.id}/messages`, undefined, b.onPhone)).body as ChatResponse;
    expect(chat.messages.map((m) => [m.mine, m.text])).toEqual([[false, "下午一起打魔王？"]]);
    expect(((await t.call("GET", "/friends", undefined, b.onPhone)).body as FriendsResponse).friends[0]!.unread).toBe(0);
    expect(((await t.call("GET", `/friends/${b.id}/messages`, undefined, a.onPhone)).body as ChatResponse).messages[0]!.read).toBe(true);
    expect((await t.call("POST", `/friends/${a.id}/messages`, { text: "x".repeat(201) }, b.onPhone)).status).toBe(400);
  });

  it("asking back is a yes; asking by who they are (from the map); unfriend and block", async () => {
    const a = await person("a@example.com");
    const b = await person("b@example.com");
    await t.call("POST", "/friends/asks", { userId: b.id }, a.onPhone);
    expect((await t.call("POST", "/friends/asks", { code: a.code }, b.onPhone)).body.status).toBe("friends");
    expect(((await t.call("GET", "/friends", undefined, a.onPhone)).body as FriendsResponse).friends).toHaveLength(1);

    expect((await t.call("POST", `/friends/${a.id}/block`, {}, b.onPhone)).status).toBe(204);
    expect(((await t.call("GET", "/friends", undefined, a.onPhone)).body as FriendsResponse).friends).toHaveLength(0);
    expect((await t.call("POST", `/friends/${b.id}/messages`, { text: "?" }, a.onPhone)).status).toBe(403);
    // a blocked one's asks look sent, but never arrive
    const before = pushesTo("b@example.com").length;
    expect((await t.call("POST", "/friends/asks", { code: b.code }, a.onPhone)).body.status).toBe("asked");
    expect(((await t.call("GET", "/friends", undefined, b.onPhone)).body as FriendsResponse).incoming).toHaveLength(0);
    expect(pushesTo("b@example.com")).toHaveLength(before);
  });
});

describe("番茄鐘（Mac 與手機共用）", () => {
  const plan = { focusMinutes: 25, restMinutes: 5, rounds: 2, longRestMinutes: 15 };

  it("starts on the phone, the Mac hears of it, pushes at each part, ends", async () => {
    const a = await person("a@example.com");
    const started = (await t.call("POST", "/pomodoro", { action: "start", plan }, a.onPhone)).body as PomodoroResponse;
    expect(started.state).toMatchObject({ index: 0, by: "phone", endsAt: t.now().getTime() + 25 * MIN });
    expect(a.heard.some((e) => e.type === "pomodoro.changed")).toBe(true);
    expect(((await t.call("GET", "/pomodoro", undefined, a.onMac)).body as PomodoroResponse).state!.index).toBe(0);

    t.advance(26 * MIN);
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(1);
    expect(pushesTo("a@example.com").at(-1)!.title).toBe("🍅 專注時間到了");
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(0); // (told once)
    // the Mac pauses; time does not pass for the run
    const paused = (await t.call("POST", "/pomodoro", { action: "pause" }, a.onMac)).body as PomodoroResponse;
    expect(paused.state).toMatchObject({ index: 1, by: "mac", endsAt: null, pausedLeft: 4 * MIN });
    t.advance(60 * MIN);
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(0);
    await t.call("POST", "/pomodoro", { action: "resume" }, a.onPhone);
    await t.call("POST", "/pomodoro", { action: "skip" }, a.onPhone); // rest skipped: focus 2
    t.advance(25 * MIN + 15 * MIN + 1000);
    expect(await tellPomodoros(t.app.deps, t.now())).toBe(1);
    expect(pushesTo("a@example.com").at(-1)!.title).toBe("🍅 番茄鐘結束了");
    expect(((await t.call("GET", "/pomodoro", undefined, a.onPhone)).body as PomodoroResponse).state).toBeNull();
    expect((await t.call("POST", "/pomodoro", { action: "start", plan: { ...plan, focusMinutes: 0 } }, a.onPhone)).status).toBe(400);
  });
});

describe("Claude 的問題在手機回答", () => {
  const ask = { id: "11111111-2222-4333-8444-555555555555", kind: "permission", project: "ant", text: "執行：npm test", waitSeconds: 600 };

  it("the Mac passes a question on; the phone answers; the Mac hears the answer once", async () => {
    const a = await person("a@example.com");
    expect((await t.call("POST", "/claude", ask, a.onPhone)).status).toBe(403); // (only a Mac sends questions)
    expect((await t.call("POST", "/claude", ask, a.onMac)).status).toBe(201);
    expect(pushesTo("a@example.com").at(-1)).toMatchObject({ title: "Claude 在等你允許「ant」", body: "執行：npm test", url: "/claude" });
    const list = (await t.call("GET", "/claude", undefined, a.onPhone)).body as ClaudeResponse;
    expect(list.waiting.map((q) => q.id)).toEqual([ask.id]);

    expect((await t.call("POST", `/claude/${ask.id}/answer`, { action: "reply" }, a.onPhone)).status).toBe(400); // (a reply needs words)
    const answered = await t.call("POST", `/claude/${ask.id}/answer`, { action: "allow" }, a.onPhone);
    expect(answered.status).toBe(200);
    expect(a.heard.find((e) => e.type === "claude.answer")).toMatchObject({ id: ask.id, action: "allow" });
    expect((await t.call("POST", `/claude/${ask.id}/answer`, { action: "deny" }, a.onPhone)).status).toBe(409); // (first one counts)
    expect(((await t.call("GET", `/claude/${ask.id}`, undefined, a.onMac)).body as { answer: { by: string } }).answer.by).toBe("phone");
    expect(((await t.call("GET", "/claude", undefined, a.onPhone)).body as ClaudeResponse).waiting).toHaveLength(0);
  });

  it("no answer after the Mac stopped waiting; the Mac may close it; news of a finish; gone after a day", async () => {
    const a = await person("a@example.com");
    await t.call("POST", "/claude", { ...ask, waitSeconds: 60 }, a.onMac);
    t.advance(2 * MIN);
    expect((await t.call("POST", `/claude/${ask.id}/answer`, { action: "allow" }, a.onPhone)).status).toBe(409);
    expect((await t.call("POST", `/claude/${ask.id}/answer`, { action: "dismiss" }, a.onMac)).status).toBe(200);

    await t.call("POST", "/claude", { id: "done-0000-1111", kind: "done", project: "ant", text: "全部測試都過了，可以發佈。" }, a.onMac);
    expect(pushesTo("a@example.com").at(-1)!.title).toBe("Claude 做完了「ant」");
    expect(((await t.call("GET", "/claude", undefined, a.onPhone)).body as ClaudeResponse).recent).toHaveLength(2);
    t.advance(25 * 60 * MIN);
    expect((await clearOld(t.app.deps, t.now())).claude).toBe(2);
  });
});
