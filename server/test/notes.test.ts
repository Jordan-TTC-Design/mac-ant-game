import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { serve } from "@hono/node-server";
import type { AddressInfo } from "node:net";
import WebSocket from "ws";
import type { NoteFields, PushResult } from "@goblincamp/shared";
import type { Database } from "../src/db/client.ts";
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

const ids = { a: "aaaaaaaa-0000-4000-8000-000000000001", b: "aaaaaaaa-0000-4000-8000-000000000002" };

function fields(over: Partial<NoteFields> = {}): NoteFields {
  return { text: "買咖啡豆", color: "yellow", breed: "common", goblinName: "咔噗", dueAt: null, remindAt: null, remindFired: false, done: false, deleted: false, kind: "todo", desk: true, ...over };
}

/** Signs up and logs in two Macs of the same person. */
async function twoMacs(email = "a@example.com") {
  const password = await signUp(t, email);
  const one = bearer((await logIn(t, email, password, mac(1))).body.token);
  const two = bearer((await logIn(t, email, password, mac(2))).body.token);
  return { one, two };
}

async function push(auth: Record<string, string>, ...changes: { id: string; baseSeq: number; fields: Partial<NoteFields>; createdAt?: string }[]) {
  const res = await t.call("POST", "/notes/push", { changes }, auth);
  expect(res.status).toBe(200);
  return res.body.results as PushResult[];
}

describe("同步", () => {
  it("a note written on one Mac shows up on the other", async () => {
    const { one, two } = await twoMacs();
    const [made] = await push(one, { id: ids.a, baseSeq: 0, fields: fields(), createdAt: "2026-10-01T08:00:00+08:00" });
    expect(made).toMatchObject({ status: "applied", note: { id: ids.a, text: "買咖啡豆", createdAt: "2026-10-01T00:00:00.000Z" } });

    const pulled = await t.call("GET", "/notes/changes?since=0", undefined, two);
    expect(pulled.body.notes).toHaveLength(1);
    expect(pulled.body.seq).toBe(made!.note!.seq);
    expect((await t.call("GET", `/notes/changes?since=${pulled.body.seq}`, undefined, two)).body.notes).toHaveLength(0);
  });

  it("keeps a memo as a memo off the desktop, and takes a note from a Mac that knows nothing of kinds as a todo", async () => {
    const { one, two } = await twoMacs();
    const [memo] = await push(one, { id: ids.a, baseSeq: 0, fields: fields({ text: "後台 https://example.com", kind: "memo", desk: false }) });
    expect(memo!.note).toMatchObject({ kind: "memo", desk: false });
    // (a Mac 0.9 sends every field it knows, and nothing else)
    const { kind: _k, desk: _d, ...old } = fields({ text: "舊的 Mac 寫的" });
    const [plain] = await push(two, { id: ids.b, baseSeq: 0, fields: old });
    expect(plain!.status).toBe("applied");
    expect(plain!.note).toMatchObject({ kind: "todo", desk: true });
  });

  it("keeps times exactly (any time zone in, UTC out)", async () => {
    const { one } = await twoMacs();
    const [r] = await push(one, { id: ids.a, baseSeq: 0, fields: fields({ dueAt: "2026-10-03T18:00:00+08:00", remindAt: "2026-10-03T09:30:00Z" }) });
    expect(r!.note).toMatchObject({ dueAt: "2026-10-03T10:00:00.000Z", remindAt: "2026-10-03T09:30:00.000Z" });
  });

  it("a new note must come with every field", async () => {
    const { one } = await twoMacs();
    const [r] = await push(one, { id: ids.a, baseSeq: 0, fields: { text: "only words" } });
    expect(r).toMatchObject({ status: "rejected", reason: "incomplete" });
  });

  it("changes to different fields on two Macs are both kept", async () => {
    const { one, two } = await twoMacs();
    const base = (await push(one, { id: ids.a, baseSeq: 0, fields: fields() }))[0]!.note!.seq;
    expect((await push(one, { id: ids.a, baseSeq: base, fields: { color: "pink" } }))[0]!.status).toBe("applied");
    const [r] = await push(two, { id: ids.a, baseSeq: base, fields: { done: true } });
    expect(r).toMatchObject({ status: "merged", note: { color: "pink", done: true } });
  });

  it("when both change the words, the first stays and the second becomes a copy", async () => {
    const { one, two } = await twoMacs();
    const base = (await push(one, { id: ids.a, baseSeq: 0, fields: fields({ text: "原本" }) }))[0]!.note!.seq;
    await push(one, { id: ids.a, baseSeq: base, fields: { text: "Mac 1 改的" } });
    const [r] = await push(two, { id: ids.a, baseSeq: base, fields: { text: "Mac 2 改的", color: "blue" } });
    expect(r!.status).toBe("conflict_copy");
    expect(r!.note).toMatchObject({ text: "Mac 1 改的", color: "blue" }); // (the colour is not a conflict)
    expect(r!.copy).toMatchObject({ text: "（衝突副本）\nMac 2 改的", color: "blue", deleted: false });
    const all = (await t.call("GET", "/notes/changes?since=0", undefined, one)).body.notes;
    expect(all.map((n: { text: string }) => n.text).sort()).toEqual(["Mac 1 改的", "（衝突副本）\nMac 2 改的"].sort());
  });

  it("the same words from both is not a conflict", async () => {
    const { one, two } = await twoMacs();
    const base = (await push(one, { id: ids.a, baseSeq: 0, fields: fields() }))[0]!.note!.seq;
    await push(one, { id: ids.a, baseSeq: base, fields: { text: "一樣" } });
    const [r] = await push(two, { id: ids.a, baseSeq: base, fields: { text: "一樣" } });
    expect(r!.status).toBe("applied");
    expect(r!.copy).toBeUndefined();
  });

  it("a delete loses to a change made on the other Mac", async () => {
    const { one, two } = await twoMacs();
    const base = (await push(one, { id: ids.a, baseSeq: 0, fields: fields() }))[0]!.note!.seq;
    await push(one, { id: ids.a, baseSeq: base, fields: { done: true } });
    const [r] = await push(two, { id: ids.a, baseSeq: base, fields: { deleted: true } });
    expect(r).toMatchObject({ status: "delete_refused", note: { deleted: false, text: "買咖啡豆", done: true } });
  });

  it("a note deleted on one Mac and changed on the other comes back", async () => {
    const { one, two } = await twoMacs();
    const base = (await push(one, { id: ids.a, baseSeq: 0, fields: fields() }))[0]!.note!.seq;
    const [gone] = await push(one, { id: ids.a, baseSeq: base, fields: { deleted: true } });
    expect(gone!.note).toMatchObject({ deleted: true, text: "" }); // the words go with the delete
    const [r] = await push(two, { id: ids.a, baseSeq: base, fields: { text: "還要做", color: "green" } });
    expect(r!.note).toMatchObject({ deleted: false, color: "green" });
  });

  it("nobody can see or touch another person's notes", async () => {
    const { one } = await twoMacs("a@example.com");
    await push(one, { id: ids.a, baseSeq: 0, fields: fields({ text: "A 的秘密" }) });
    const pb = await signUp(t, "b@example.com");
    const other = bearer((await logIn(t, "b@example.com", pb, mac(3))).body.token);
    expect((await t.call("GET", "/notes/changes?since=0", undefined, other)).body.notes).toHaveLength(0);
    const [r] = await push(other, { id: ids.a, baseSeq: 0, fields: fields({ text: "B 蓋掉" }) });
    expect(r).toMatchObject({ status: "rejected", reason: "id_taken" });
    expect(r!.note).toBeUndefined();
    const mine = (await t.call("GET", "/notes/changes?since=0", undefined, one)).body.notes;
    expect(mine[0].text).toBe("A 的秘密");
  });

  it("stops at 500 notes", async () => {
    const { one } = await twoMacs();
    for (let batch = 0; batch < 5; batch++) {
      const changes = Array.from({ length: 100 }, (_, i) => ({
        id: `bbbbbbbb-0000-4000-8000-${String(batch * 100 + i).padStart(12, "0")}`,
        baseSeq: 0,
        fields: fields(),
      }));
      expect((await push(one, ...changes)).every((r) => r.status === "applied")).toBe(true);
    }
    const [r] = await push(one, { id: ids.b, baseSeq: 0, fields: fields() });
    expect(r).toMatchObject({ status: "rejected", reason: "limit" });
    const page = await t.call("GET", "/notes/changes?since=0", undefined, one);
    expect(page.body.notes).toHaveLength(500);
    expect(page.body.more).toBe(false);
  });

  it("needs a signed-in device", async () => {
    expect((await t.call("GET", "/notes/changes?since=0")).status).toBe(401);
    expect((await t.call("POST", "/notes/push", { changes: [] })).status).toBe(401);
  });
});

describe("WebSocket", () => {
  /** The app on a real port, since a WebSocket needs a real connection. */
  async function listen(app: TestApp["app"]) {
    const server = serve({ fetch: app.fetch, port: 0 });
    app.injectWebSocket(server);
    await new Promise<void>((resolve) => server.once("listening", () => resolve()));
    return { server, url: `ws://127.0.0.1:${(server.address() as AddressInfo).port}/api/ws` };
  }

  function open(url: string, headers: Record<string, string>) {
    const socket = new WebSocket(url, { headers });
    const messages: unknown[] = [];
    socket.on("message", (data) => messages.push(JSON.parse(String(data))));
    const closed = new Promise<number>((resolve) => socket.on("close", (code) => resolve(code)));
    const opened = new Promise<void>((resolve, reject) => {
      socket.on("open", () => resolve());
      socket.on("unexpected-response", (_req, res) => reject(new Error(`HTTP ${res.statusCode}`)));
      socket.on("error", reject);
    });
    const waitFor = async (n: number) => {
      for (let i = 0; i < 100 && messages.length < n; i++) await new Promise((r) => setTimeout(r, 20));
      return messages;
    };
    return { socket, opened, closed, waitFor };
  }

  it("tells the other Mac right away, and closes when that Mac is signed out", async () => {
    const { one, two } = await twoMacs();
    const { server, url } = await listen(t.app);
    try {
      const listener = open(url, two);
      await listener.opened;
      expect((await listener.waitFor(1))[0]).toMatchObject({ type: "hello" });

      const [made] = await push(one, { id: ids.a, baseSeq: 0, fields: fields() });
      expect((await listener.waitFor(2))[1]).toEqual({ type: "notes.changed", seq: made!.note!.seq });

      await t.call("POST", "/auth/logout", undefined, two);
      expect(await listener.closed).toBe(4001);
    } finally {
      server.close();
    }
  });

  it("refuses a connection without a session, or a phone's cookie from another site", async () => {
    const password = await signUp(t, "a@example.com");
    const cookie = (await logIn(t, "a@example.com", password, phone)).headers.get("set-cookie")!.split(";")[0]!;
    const { server, url } = await listen(t.app);
    try {
      await expect(open(url, {}).opened).rejects.toThrow("HTTP 401");
      await expect(open(url, { cookie, origin: "https://evil.example" }).opened).rejects.toThrow("HTTP 403");
      const ok = open(url, { cookie, origin: APP_URL });
      await ok.opened;
      ok.socket.close();
    } finally {
      server.close();
    }
  });
});
