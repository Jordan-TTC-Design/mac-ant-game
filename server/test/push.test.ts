import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { NoteFields } from "@goblincamp/shared";
import { loadConfig } from "../src/config.ts";
import type { Database } from "../src/db/client.ts";
import { pushDueReminders } from "../src/push/reminders.ts";
import { APP_URL, bearer, emptyTables, logIn, mac, openTestDatabase, phone, signUp, testApp, type TestApp } from "./helpers.ts";

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

const NOTE = "cccccccc-0000-4000-8000-000000000001";
const subscription = (endpoint = "https://push.example/abc") => ({ endpoint, keys: { p256dh: "BPkey", auth: "authkey" } });
const MIN = 60_000;

function fields(over: Partial<NoteFields> = {}): NoteFields {
  return { text: "打電話給廠商\n記得問報價", color: "yellow", breed: "brute", goblinName: "咕嚕", dueAt: null, remindAt: null, remindFired: false, done: false, deleted: false, kind: "todo", desk: true, ...over };
}

/** A person with a Mac and a phone that subscribed to pushes. */
async function setUp() {
  const password = await signUp(t, "a@example.com");
  const onMac = bearer((await logIn(t, "a@example.com", password, mac(1))).body.token);
  const cookie = (await logIn(t, "a@example.com", password, phone)).headers.get("set-cookie")!.split(";")[0]!;
  const onPhone = { cookie, origin: APP_URL };
  expect((await t.call("POST", "/push/subscribe", subscription(), onPhone)).status).toBe(204);
  return { onMac, onPhone };
}

async function remindIn(auth: Record<string, string>, minutes: number, baseSeq = 0, over: Partial<NoteFields> = {}) {
  const at = new Date(t.now().getTime() + minutes * MIN).toISOString();
  const res = await t.call("POST", "/notes/push", { changes: [{ id: NOTE, baseSeq, fields: baseSeq ? { remindAt: at, ...over } : fields({ remindAt: at, ...over }) }] }, auth);
  return res.body.results[0].note.seq as number;
}

const run = () => pushDueReminders(t.app.deps, t.now());

describe("提醒推播", () => {
  it("pushes a due reminder to the phone once, and again after a snooze", async () => {
    const { onMac } = await setUp();
    const seq = await remindIn(onMac, 10);
    expect(await run()).toBe(0); // not yet
    t.advance(11 * MIN);
    expect(await run()).toBe(1);
    expect(t.push.sent).toHaveLength(1);
    expect(t.push.sent[0]!.payload).toEqual({ type: "reminder", noteId: NOTE, title: "咕嚕・壯碩哥布林", body: "打電話給廠商\n記得問報價" });
    expect(await run()).toBe(0); // (only once)

    await remindIn(onMac, 10, seq); // 10 分鐘後
    t.advance(11 * MIN);
    expect(await run()).toBe(1);
    expect(t.push.sent).toHaveLength(2);
  });

  it("names who is on the note by the account's race", async () => {
    const { onMac } = await setUp();
    await t.call("POST", "/camp/start", { race: "elf" }, onMac);
    await remindIn(onMac, 1);
    t.advance(2 * MIN);
    expect(await run()).toBe(1);
    expect(t.push.sent[0]!.payload.title).toBe("咕嚕・樹皮精靈");
  });

  it("does not push a deleted note, an answered reminder, or one a day old", async () => {
    const { onMac } = await setUp();
    const seq = await remindIn(onMac, 5);
    await t.call("POST", "/notes/push", { changes: [{ id: NOTE, baseSeq: seq, fields: { remindAt: null } }] }, onMac); // 知道了 before it was due
    t.advance(6 * MIN);
    expect(await run()).toBe(0);

    await remindIn(onMac, -25 * 60, (await t.call("GET", "/notes/changes?since=0", undefined, onMac)).body.seq); // (the server was down all day)
    expect(await run()).toBe(0);
    expect(t.push.sent).toHaveLength(0);
  });

  it("forgets a phone the push service says is gone", async () => {
    const { onMac, onPhone } = await setUp();
    t.push.gone.add("https://push.example/abc");
    await remindIn(onMac, 1);
    t.advance(2 * MIN);
    await run();
    const [row] = await database.sql<{ push_subscription: unknown }[]>`select push_subscription from devices where kind = 'pwa'`;
    expect(row?.push_subscription).toBeNull();
    expect((await t.call("POST", "/push/subscribe", subscription("https://push.example/new"), onPhone)).status).toBe(204);
  });

  it("only a phone can subscribe, and it can stop", async () => {
    const { onMac, onPhone } = await setUp();
    expect((await t.call("POST", "/push/subscribe", subscription(), onMac)).status).toBe(400);
    expect((await t.call("POST", "/push/subscribe", { endpoint: "not a url", keys: {} }, onPhone)).status).toBe(400);
    expect((await t.call("DELETE", "/push/subscribe", undefined, onPhone)).status).toBe(204);
    await remindIn(onMac, 1);
    t.advance(2 * MIN);
    expect(await run()).toBe(1); // due, but nobody to push to
    expect(t.push.sent).toHaveLength(0);
  });

  it("tells the phone the public key", async () => {
    expect((await t.call("GET", "/push/key")).body).toEqual({ publicKey: "test-public-key" });
  });
});

describe("設定", () => {
  it("treats empty VAPID keys as not set", () => {
    const config = loadConfig({ DATABASE_URL: "postgres://x@localhost/y", VAPID_PUBLIC_KEY: "", VAPID_PRIVATE_KEY: "" });
    expect(config.VAPID_PUBLIC_KEY).toBeUndefined();
  });
});
