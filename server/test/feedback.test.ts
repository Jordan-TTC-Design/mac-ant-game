import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Database } from "../src/db/client.ts";
import { APP_URL, bearer, emptyTables, logIn, mac, openTestDatabase, signUp, testApp, type TestApp } from "./helpers.ts";

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
async function account(email: string) {
  const password = await signUp(t, email);
  return bearer((await logIn(t, email, password, mac(++macs))).body.token);
}

describe("回報", () => {
  it("is sent by anyone and seen by everyone, with where it stands", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    const sent = await t.call("POST", "/feedback", { kind: "bug", title: "營地畫面閃爍", body: "打開營地就一直閃", device: "iPhone" }, a);
    expect(sent.status).toBe(201);
    const list = (await t.call("GET", "/feedback", undefined, b)).body;
    expect(list.admin).toBe(false);
    expect(list.items).toEqual([expect.objectContaining({ kind: "bug", title: "營地畫面閃爍", status: "open", mine: false, replies: 0 })]);
    expect(list.counts.open).toBe(1);
    const mine = (await t.call("GET", "/feedback?mine=1", undefined, a)).body.items;
    expect(mine[0].mine).toBe(true);
    expect((await t.call("GET", "/feedback?mine=1", undefined, b)).body.items).toEqual([]);
    // what it was sent from is only for the author and admins
    expect((await t.call("GET", `/feedback/${sent.body.id}`, undefined, b)).body.device).toBeNull();
    expect((await t.call("GET", `/feedback/${sent.body.id}`, undefined, a)).body.device).toBe("iPhone");
  });

  it("checks what is sent", async () => {
    const a = await account("a@example.com");
    expect((await t.call("POST", "/feedback", { kind: "rant", title: "hello" }, a)).status).toBe(400);
    expect((await t.call("POST", "/feedback", { kind: "idea", title: " " }, a)).status).toBe(400);
    expect((await t.call("POST", "/feedback", { kind: "idea", title: "ok" })).status).toBe(401);
  });

  it("lets admins move it along and answer; the author hears about it and can answer back", async () => {
    const boss = await account("boss@example.com");
    const a = await account("a@example.com");
    const other = await account("b@example.com");
    const id = (await t.call("POST", "/feedback", { kind: "balance", title: "精靈太強" }, a)).body.id;
    expect((await t.call("GET", "/feedback", undefined, boss)).body.admin).toBe(true);

    expect((await t.call("POST", `/feedback/${id}/status`, { status: "done" }, a)).status).toBe(403);
    const moved = await t.call("POST", `/feedback/${id}/status`, { status: "next", note: "下個版本調整精靈弓手" }, boss);
    expect(moved.status).toBe(200);
    expect(moved.body.status).toBe("next");
    expect(moved.body.admin).toBe(true);
    expect(moved.body.thread).toEqual([expect.objectContaining({ admin: true, status: "next", body: "下個版本調整精靈弓手" })]);

    // only the author and admins write under it
    expect((await t.call("POST", `/feedback/${id}/replies`, { body: "+1" }, other)).status).toBe(403);
    const back = await t.call("POST", `/feedback/${id}/replies`, { body: "謝謝！" }, a);
    expect(back.status).toBe(201);
    expect(back.body.thread.map((r: { admin: boolean; body: string }) => [r.admin, r.body])).toEqual([[true, "下個版本調整精靈弓手"], [false, "謝謝！"]]);

    await t.call("POST", `/feedback/${id}/status`, { status: "done" }, boss);
    const list = (await t.call("GET", "/feedback?status=done", undefined, other)).body;
    expect(list.items).toEqual([expect.objectContaining({ id, status: "done", replies: 2 })]);
    expect(list.counts).toEqual(expect.objectContaining({ done: 1, open: 0, next: 0 }));
  });

  it("pushes to the author's phone when an admin answers, and to admins when a report comes in", async () => {
    const bossPw = await signUp(t, "boss@example.com");
    const phoneA = { id: "00000000-0000-4000-8000-0000000000a1", kind: "pwa" as const, name: "iPhone" };
    const phoneB = { id: "00000000-0000-4000-8000-0000000000b1", kind: "pwa" as const, name: "iPhone" };
    const bossLogin = await logIn(t, "boss@example.com", bossPw, phoneB);
    const bossCookie = { cookie: (bossLogin.headers.get("set-cookie") ?? "").split(";")[0]!, origin: APP_URL };
    const aPw = await signUp(t, "a@example.com");
    const aLogin = await logIn(t, "a@example.com", aPw, phoneA);
    const aCookie = { cookie: (aLogin.headers.get("set-cookie") ?? "").split(";")[0]!, origin: APP_URL };
    const sub = (n: string) => ({ endpoint: `https://push.example/${n}`, keys: { p256dh: "k", auth: "a" } });
    expect((await t.call("POST", "/push/subscribe", sub("boss"), bossCookie)).status).toBeLessThan(300);
    expect((await t.call("POST", "/push/subscribe", sub("a"), aCookie)).status).toBeLessThan(300);

    const id = (await t.call("POST", "/feedback", { kind: "idea", title: "加夜間模式" }, aCookie)).body.id;
    expect(t.push.sent.map((p) => p.endpoint)).toEqual(["https://push.example/boss"]);
    await t.call("POST", `/feedback/${id}/status`, { status: "working" }, bossCookie);
    expect(t.push.sent.at(-1)).toEqual({ endpoint: "https://push.example/a", payload: expect.objectContaining({ url: `/feedback/${id}`, title: "你的回報：處理中" }) });
  });

  it("can be taken back by its author until an admin picks it up; admins remove any", async () => {
    const boss = await account("boss@example.com");
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    const one = (await t.call("POST", "/feedback", { kind: "bug", title: "重複的" }, a)).body.id;
    const two = (await t.call("POST", "/feedback", { kind: "bug", title: "真的 bug" }, a)).body.id;
    expect((await t.call("DELETE", `/feedback/${one}`, undefined, b)).status).toBe(403);
    expect((await t.call("DELETE", `/feedback/${one}`, undefined, a)).status).toBe(204);
    await t.call("POST", `/feedback/${two}/status`, { status: "accepted" }, boss);
    expect((await t.call("DELETE", `/feedback/${two}`, undefined, a)).status).toBe(403);
    expect((await t.call("DELETE", `/feedback/${two}`, undefined, boss)).status).toBe(204);
    expect((await t.call("GET", `/feedback/${two}`, undefined, a)).status).toBe(404);
  });

  it("takes a +1 from others (once each, not the author's own) and can list the most wanted first", async () => {
    const a = await account("a@example.com");
    const b = await account("b@example.com");
    const c = await account("c@example.com");
    const quiet = (await t.call("POST", "/feedback", { kind: "idea", title: "少人要的" }, a)).body.id;
    const wanted = (await t.call("POST", "/feedback", { kind: "bug", title: "很多人遇到" }, a)).body.id;
    t.advance(1000);
    await t.call("POST", `/feedback/${quiet}/replies`, { body: "補充" }, a); // (now the newest activity)
    expect((await t.call("PUT", `/feedback/${wanted}/vote`, undefined, a)).status).toBe(409);
    expect((await t.call("PUT", `/feedback/${wanted}/vote`, undefined, b)).body).toEqual(expect.objectContaining({ votes: 1, voted: true }));
    expect((await t.call("PUT", `/feedback/${wanted}/vote`, undefined, b)).body.votes).toBe(1);
    await t.call("PUT", `/feedback/${wanted}/vote`, undefined, c);
    const newest = (await t.call("GET", "/feedback", undefined, c)).body.items;
    expect(newest.map((i: { id: string }) => i.id)).toEqual([quiet, wanted]);
    const most = (await t.call("GET", "/feedback?sort=votes", undefined, c)).body.items;
    expect(most[0]).toEqual(expect.objectContaining({ id: wanted, votes: 2, voted: true }));
    expect(most[1]).toEqual(expect.objectContaining({ id: quiet, votes: 0, voted: false }));
    expect((await t.call("DELETE", `/feedback/${wanted}/vote`, undefined, b)).body).toEqual(expect.objectContaining({ votes: 1, voted: false }));
  });

  it("keeps someone from flooding it", async () => {
    const a = await account("a@example.com");
    for (let i = 0; i < 10; i++) expect((await t.call("POST", "/feedback", { kind: "idea", title: `點子 ${i}` }, a)).status).toBe(201);
    expect((await t.call("POST", "/feedback", { kind: "idea", title: "再一個" }, a)).status).toBe(429);
    t.advance(3_700_000);
    expect((await t.call("POST", "/feedback", { kind: "idea", title: "再一個" }, a)).status).toBe(201);
  });
});
