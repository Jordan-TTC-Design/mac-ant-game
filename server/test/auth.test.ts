import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Database } from "../src/db/client.ts";
import { APP_URL, bearer, emptyTables, logIn, mac, openTestDatabase, phone, signUp, testApp, type TestApp } from "./helpers.ts";

const DAY = 86_400_000;
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

describe("註冊與邀請碼", () => {
  it("goes all the way: invite → register → confirm the address → log in", async () => {
    const code = await t.invite();
    const reg = await t.call("POST", "/auth/register", { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕", inviteCode: code });
    expect(reg.status).toBe(202);
    expect(t.mailer.last("a@example.com")?.subject).toContain("確認你的信箱");
    expect(t.mailer.last("a@example.com")?.text).toContain(`${APP_URL}/verify-email?token=`);

    const early = await t.call("POST", "/auth/login", { email: "a@example.com", password: "correct horse battery", device: mac() });
    expect(early.status).toBe(403);
    expect(early.body.error).toBe("email_not_verified");

    expect((await t.call("POST", "/auth/verify-email", { token: t.tokenFromMail("a@example.com") })).status).toBe(200);
    const login = await logIn(t, "a@example.com", "correct horse battery");
    expect(login.body.token).toMatch(/^gcs_/);
    expect(login.body.user).toMatchObject({ email: "a@example.com", displayName: "咕嚕" });
    expect(login.body.user.friendCode).toMatch(/^GOB-[23456789A-HJKMNP-TV-Z]{6}$/);

    const me = await t.call("GET", "/auth/me", undefined, bearer(login.body.token));
    expect(me.status).toBe(200);
    expect(me.body.user.email).toBe("a@example.com");
  });

  it("refuses a wrong, used or expired invite", async () => {
    const body = { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕" };
    expect((await t.call("POST", "/auth/register", { ...body, inviteCode: "GOBLIN-XXXX-XXXX" })).body.error).toBe("invite_invalid");

    const code = await t.invite();
    expect((await t.call("POST", "/auth/register", { ...body, inviteCode: code })).status).toBe(202);
    const again = await t.call("POST", "/auth/register", { ...body, email: "b@example.com", inviteCode: code });
    expect(again.status).toBe(400);
    expect(again.body.error).toBe("invite_invalid");

    const old = await t.invite(14);
    t.advance(15 * DAY);
    expect((await t.call("POST", "/auth/register", { ...body, email: "c@example.com", inviteCode: old })).body.error).toBe("invite_invalid");
    expect(t.mailer.last("b@example.com")).toBeUndefined();
  });

  it("takes the invite typed loosely (lower case, spaces)", async () => {
    const code = await t.invite();
    const loose = code.toLowerCase().replaceAll("-", " ");
    const res = await t.call("POST", "/auth/register", { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕", inviteCode: loose });
    expect(res.status).toBe(202);
  });

  it("does not tell that an address is taken, and does not use up the invite", async () => {
    await signUp(t, "a@example.com");
    const code = await t.invite();
    const res = await t.call("POST", "/auth/register", { email: "A@Example.com", password: "another password!", displayName: "別人", inviteCode: code });
    expect(res.status).toBe(202); // the same answer as a new account
    expect(t.mailer.last("a@example.com")?.subject).toContain("有人想用你的信箱註冊");
    // the invite still works for someone else
    const other = await t.call("POST", "/auth/register", { email: "b@example.com", password: "correct horse battery", displayName: "B", inviteCode: code });
    expect(other.status).toBe(202);
  });

  it("sends a fresh link when an unconfirmed address registers again, and the old link stops working", async () => {
    const body = { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕" };
    await t.call("POST", "/auth/register", { ...body, inviteCode: await t.invite() });
    const first = t.tokenFromMail("a@example.com");
    await t.call("POST", "/auth/register", { ...body, inviteCode: await t.invite() });
    const second = t.tokenFromMail("a@example.com");
    expect(second).not.toBe(first);
    expect((await t.call("POST", "/auth/verify-email", { token: first })).status).toBe(400);
    expect((await t.call("POST", "/auth/verify-email", { token: second })).status).toBe(200);
  });

  it("checks the fields", async () => {
    const res = await t.call("POST", "/auth/register", { email: "not-an-email", password: "short", displayName: "", inviteCode: "GOBLIN-AAAA-AAAA" });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe("invalid_input");
    expect(Object.keys(res.body.fields)).toEqual(expect.arrayContaining(["email", "password", "displayName"]));

    const form = await t.app.request("/api/auth/register", { method: "POST", body: "email=a@example.com", headers: { "content-type": "application/x-www-form-urlencoded" } });
    expect(form.status).toBe(415);
  });
});

describe("確認信箱", () => {
  it("links expire after 24 hours and work once", async () => {
    await t.call("POST", "/auth/register", { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕", inviteCode: await t.invite() });
    const token = t.tokenFromMail("a@example.com");
    t.advance(25 * 3_600_000);
    expect((await t.call("POST", "/auth/verify-email", { token })).body.error).toBe("token_invalid");

    await t.call("POST", "/auth/resend-verification", { email: "a@example.com" });
    const fresh = t.tokenFromMail("a@example.com");
    expect((await t.call("POST", "/auth/verify-email", { token: fresh })).status).toBe(200);
    expect((await t.call("POST", "/auth/verify-email", { token: fresh })).status).toBe(400);
  });

  it("answers the same for an address that has no account", async () => {
    const res = await t.call("POST", "/auth/resend-verification", { email: "nobody@example.com" });
    expect(res.status).toBe(202);
    expect(t.mailer.sent).toHaveLength(0);
  });
});

describe("登入", () => {
  it("gives the same answer for a wrong password and an unknown address", async () => {
    await signUp(t, "a@example.com");
    const wrong = await t.call("POST", "/auth/login", { email: "a@example.com", password: "wrong password", device: mac() });
    const unknown = await t.call("POST", "/auth/login", { email: "nobody@example.com", password: "wrong password", device: mac() });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body).toEqual(unknown.body);
  });

  it("does not care about upper and lower case in the address", async () => {
    const password = await signUp(t, "Mixed.Case@Example.com");
    const res = await logIn(t, "mixed.case@example.com", password);
    expect(res.body.user.email).toBe("Mixed.Case@Example.com");
  });

  it("gives a phone an HttpOnly cookie instead of a token", async () => {
    const password = await signUp(t, "a@example.com");
    const res = await logIn(t, "a@example.com", password, phone);
    expect(res.body.token).toBeUndefined();
    const cookie = res.headers.get("set-cookie") ?? "";
    expect(cookie).toMatch(/^gc_session=gcs_/);
    expect(cookie).toContain("HttpOnly");
    expect(cookie).toContain("SameSite=Lax");
    expect(cookie).toContain("Path=/api");
    const session = cookie.split(";")[0]!;
    expect((await t.call("GET", "/auth/me", undefined, { cookie: session })).status).toBe(200);
  });

  it("stops after 5 tries a minute for one address", async () => {
    await signUp(t, "a@example.com");
    for (let i = 0; i < 5; i++) {
      expect((await t.call("POST", "/auth/login", { email: "a@example.com", password: "wrong password", device: mac() })).status).toBe(401);
    }
    const blocked = await t.call("POST", "/auth/login", { email: "a@example.com", password: "correct horse battery", device: mac() });
    expect(blocked.status).toBe(429);
    expect(blocked.body.error).toBe("rate_limited");
    expect(Number(blocked.headers.get("retry-after"))).toBeGreaterThan(0);
    t.advance(61_000);
    expect((await t.call("POST", "/auth/login", { email: "a@example.com", password: "correct horse battery", device: mac() })).status).toBe(200);
  });
});

describe("登入中的裝置", () => {
  it("lists them, and signing one out ends only that one", async () => {
    const password = await signUp(t, "a@example.com");
    const onMac = (await logIn(t, "a@example.com", password, mac(1))).body.token;
    const onMac2 = (await logIn(t, "a@example.com", password, mac(2))).body.token;

    const list = await t.call("GET", "/auth/sessions", undefined, bearer(onMac));
    expect(list.body.sessions).toHaveLength(2);
    const other = list.body.sessions.find((s: { current: boolean }) => !s.current);
    expect(other.device).toMatchObject({ kind: "mac", name: "Mac 2" });

    expect((await t.call("DELETE", `/auth/sessions/${other.id}`, undefined, bearer(onMac))).status).toBe(204);
    expect((await t.call("GET", "/auth/me", undefined, bearer(onMac2))).status).toBe(401);
    expect((await t.call("GET", "/auth/me", undefined, bearer(onMac))).status).toBe(200);
  });

  it("cannot sign out someone else's session", async () => {
    const pa = await signUp(t, "a@example.com");
    const pb = await signUp(t, "b@example.com");
    const a = (await logIn(t, "a@example.com", pa, mac(1))).body.token;
    const b = (await logIn(t, "b@example.com", pb, mac(2))).body.token;
    const bSession = (await t.call("GET", "/auth/me", undefined, bearer(b))).body.sessionId;
    expect((await t.call("DELETE", `/auth/sessions/${bSession}`, undefined, bearer(a))).status).toBe(404);
    expect((await t.call("GET", "/auth/me", undefined, bearer(b))).status).toBe(200);
  });

  it("logging in again on the same device replaces its old session", async () => {
    const password = await signUp(t, "a@example.com");
    const first = (await logIn(t, "a@example.com", password)).body.token;
    const second = (await logIn(t, "a@example.com", password)).body.token;
    expect((await t.call("GET", "/auth/me", undefined, bearer(first))).status).toBe(401);
    expect((await t.call("GET", "/auth/me", undefined, bearer(second))).status).toBe(200);
  });

  it("logout ends the session", async () => {
    const password = await signUp(t, "a@example.com");
    const token = (await logIn(t, "a@example.com", password)).body.token;
    expect((await t.call("POST", "/auth/logout", undefined, bearer(token))).status).toBe(204);
    expect((await t.call("GET", "/auth/me", undefined, bearer(token))).status).toBe(401);
  });

  it("expires after 90 days without use, and stays alive while it is used", async () => {
    const password = await signUp(t, "a@example.com");
    const used = (await logIn(t, "a@example.com", password, mac(1))).body.token;
    const idle = (await logIn(t, "a@example.com", password, mac(2))).body.token;
    t.advance(60 * DAY);
    expect((await t.call("GET", "/auth/me", undefined, bearer(used))).status).toBe(200);
    t.advance(60 * DAY);
    expect((await t.call("GET", "/auth/me", undefined, bearer(used))).status).toBe(200);
    expect((await t.call("GET", "/auth/me", undefined, bearer(idle))).status).toBe(401);
  });

  it("a cookie request that changes something must come from our own page", async () => {
    const password = await signUp(t, "a@example.com");
    const cookie = (await logIn(t, "a@example.com", password, phone)).headers.get("set-cookie")!.split(";")[0]!;
    const evil = await t.call("POST", "/auth/logout", undefined, { cookie, origin: "https://evil.example" });
    expect(evil.status).toBe(403);
    expect((await t.call("GET", "/auth/me", undefined, { cookie })).status).toBe(200);
    expect((await t.call("POST", "/auth/logout", undefined, { cookie, origin: APP_URL })).status).toBe(204);
  });

  it("refuses requests without a session", async () => {
    expect((await t.call("GET", "/auth/me")).status).toBe(401);
    expect((await t.call("GET", "/auth/me", undefined, bearer("gcs_made-up"))).status).toBe(401);
  });
});

describe("忘記密碼", () => {
  it("sets a new password and signs every device out", async () => {
    const password = await signUp(t, "a@example.com");
    const token = (await logIn(t, "a@example.com", password)).body.token;

    expect((await t.call("POST", "/auth/forgot-password", { email: "a@example.com" })).status).toBe(202);
    expect(t.mailer.last("a@example.com")?.text).toContain(`${APP_URL}/reset-password?token=`);
    const reset = t.tokenFromMail("a@example.com");
    expect((await t.call("POST", "/auth/reset-password", { token: reset, password: "a brand new password" })).status).toBe(200);

    expect((await t.call("GET", "/auth/me", undefined, bearer(token))).status).toBe(401);
    expect((await t.call("POST", "/auth/login", { email: "a@example.com", password, device: mac() })).status).toBe(401);
    await logIn(t, "a@example.com", "a brand new password");
    expect((await t.call("POST", "/auth/reset-password", { token: reset, password: "yet another password" })).status).toBe(400);
  });

  it("links expire after an hour", async () => {
    await signUp(t, "a@example.com");
    await t.call("POST", "/auth/forgot-password", { email: "a@example.com" });
    const reset = t.tokenFromMail("a@example.com");
    t.advance(61 * 60_000);
    expect((await t.call("POST", "/auth/reset-password", { token: reset, password: "a brand new password" })).body.error).toBe("token_invalid");
  });

  it("answers the same for an unknown address, and sends nothing", async () => {
    const res = await t.call("POST", "/auth/forgot-password", { email: "nobody@example.com" });
    expect(res.status).toBe(202);
    expect(t.mailer.sent).toHaveLength(0);
  });

  it("also confirms an address that was never confirmed (the link reached the mailbox)", async () => {
    await t.call("POST", "/auth/register", { email: "a@example.com", password: "correct horse battery", displayName: "咕嚕", inviteCode: await t.invite() });
    await t.call("POST", "/auth/forgot-password", { email: "a@example.com" });
    await t.call("POST", "/auth/reset-password", { token: t.tokenFromMail("a@example.com"), password: "a brand new password" });
    await logIn(t, "a@example.com", "a brand new password");
  });
});

describe("a Mac opening the web page signed in (handoff)", () => {
  it("gives a one-time link that signs a browser in and goes to the page", async () => {
    const password = await signUp(t, "h@example.com");
    const onMac = bearer((await logIn(t, "h@example.com", password, mac(7))).body.token);
    const webDevice = "0f0e0d0c-0b0a-4908-8706-050403020100";
    const res = await t.call("POST", "/auth/handoff", { webDevice, to: "/world" }, onMac);
    expect(res.status).toBe(200);
    const url = new URL(res.body.url);
    const open = await t.app.request(url.pathname + url.search);
    expect(open.status).toBe(302);
    expect(open.headers.get("location")).toBe(`${APP_URL}/world`);
    const cookie = open.headers.get("set-cookie")!.split(";")[0]!;
    const me = await t.call("GET", "/auth/me", undefined, { cookie });
    expect(me.body.user.email).toBe("h@example.com");
    // once only, and only with the device it was made for
    const again = await t.app.request(url.pathname + url.search);
    expect(again.headers.get("location")).toContain("/login");
    const other = await t.call("POST", "/auth/handoff", { webDevice, to: "/world" }, onMac);
    const wrong = new URL(other.body.url);
    wrong.searchParams.set("device", "11111111-2222-4333-8444-555555555555");
    expect((await t.app.request(wrong.pathname + wrong.search)).headers.get("location")).toContain("/login");
    // not from a web page's cookie, and not to another site
    expect((await t.call("POST", "/auth/handoff", { webDevice, to: "/world" }, { cookie, origin: APP_URL })).status).toBe(403);
    expect((await t.call("POST", "/auth/handoff", { webDevice, to: "//evil.example" }, onMac)).status).toBe(400);
  });
});

describe("signing out every other device", () => {
  it("ends every sign-in but this one", async () => {
    const password = await signUp(t, "o@example.com");
    const one = bearer((await logIn(t, "o@example.com", password, mac(1))).body.token);
    const two = bearer((await logIn(t, "o@example.com", password, mac(2))).body.token);
    const three = bearer((await logIn(t, "o@example.com", password, mac(3))).body.token);
    const res = await t.call("DELETE", "/auth/sessions", undefined, one);
    expect(res.body.signedOut).toBe(2);
    expect((await t.call("GET", "/auth/me", undefined, one)).status).toBe(200);
    expect((await t.call("GET", "/auth/me", undefined, two)).status).toBe(401);
    expect((await t.call("GET", "/auth/me", undefined, three)).status).toBe(401);
  });
});
