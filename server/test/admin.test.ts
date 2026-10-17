import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
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

let macs = 0;
const passwords = new Map<string, string>();
async function account(email: string) {
  const password = await signUp(t, email);
  passwords.set(email, password);
  return bearer((await logIn(t, email, password, mac(++macs))).body.token);
}

describe("後台", () => {
  it("is only for the addresses in ADMIN_EMAILS (any case)", async () => {
    const boss = await account("boss@example.com");
    const other = await account("a@example.com");
    const second = await account("admin2@example.com");
    expect((await t.call("GET", "/admin", undefined, boss)).status).toBe(200);
    expect((await t.call("GET", "/admin", undefined, second)).status).toBe(200);
    expect((await t.call("GET", "/admin/overview", undefined, other)).status).toBe(403);
    expect((await t.call("POST", "/admin/invites", { count: 3 }, other)).status).toBe(403);
    expect((await t.call("GET", "/admin")).status).toBe(401);
  });

  it("makes invite codes that work for signing up, and shows who used them", async () => {
    const boss = await account("boss@example.com");
    const res = await t.call("POST", "/admin/invites", { count: 2, days: 7 }, boss);
    expect(res.status).toBe(201);
    expect(res.body.codes).toHaveLength(2);
    // somebody signs up with one
    const reg = await t.call("POST", "/auth/register", { email: "new@example.com", password: "a-long-password-1", displayName: "新人", inviteCode: res.body.codes[0] });
    expect(reg.status).toBe(202);
    const list = (await t.call("GET", "/admin/invites", undefined, boss)).body.invites as { state: string; usedBy: string | null }[];
    expect(list.filter((i) => i.state === "used").map((i) => i.usedBy)).toContain("new@example.com");
    expect(list.filter((i) => i.state === "free").length).toBeGreaterThanOrEqual(1);
    // the codes themselves are never shown again
    expect(JSON.stringify(list)).not.toContain(res.body.codes[1]);
    t.advance(8 * 86_400_000);
    const later = (await t.call("GET", "/admin/overview", undefined, boss)).body;
    expect(later.invites.expired).toBeGreaterThanOrEqual(1);
  });

  it("shows how the server is used: people, camps, the big world", async () => {
    const boss = await account("boss@example.com");
    const a = await account("a@example.com");
    await t.call("POST", "/camp/start", { race: "elf" }, a);
    const o = (await t.call("GET", "/admin/overview", undefined, boss)).body;
    expect(o.users.all).toBe(2);
    expect(o.devices.macs).toBe(2);
    expect(o.camps).toEqual({ elf: 1 });
    expect(o.residents).toBe(2);
    const users = (await t.call("GET", "/admin/users", undefined, boss)).body.users as { email: string; camp: { race: string; population: number } | null }[];
    expect(users.find((u) => u.email === "a@example.com")?.camp).toEqual(expect.objectContaining({ race: "elf", population: 2 }));
    expect(users.find((u) => u.email === "boss@example.com")?.camp).toBeNull();
  });
});

describe("後台: looking after accounts", () => {
  async function setUp() {
    const boss = await account("boss@example.com");
    await t.call("GET", "/admin", undefined, boss); // (becomes an admin: ADMIN_EMAILS)
    const password = await signUp(t, "a@example.com");
    const a = bearer((await logIn(t, "a@example.com", password, mac(++macs))).body.token);
    const users = (await t.call("GET", "/admin/users", undefined, boss)).body.users as { id: string; email: string; role: string }[];
    return { boss, a, password, aId: users.find((u) => u.email === "a@example.com")!.id, bossId: users.find((u) => u.email === "boss@example.com")!.id };
  }

  it("stops an account (signed out everywhere, cannot sign in) and lets it back in", async () => {
    const { boss, a, password, aId } = await setUp();
    expect((await t.call("POST", `/admin/users/${aId}/disable`, undefined, boss)).status).toBe(200);
    expect((await t.call("GET", "/auth/me", undefined, a)).status).toBe(401);
    const login = await t.call("POST", "/auth/login", { email: "a@example.com", password, device: mac(++macs) });
    expect(login.status).toBe(403);
    expect((await t.call("POST", `/admin/users/${aId}/enable`, undefined, boss)).status).toBe(200);
    expect((await logIn(t, "a@example.com", password, mac(++macs))).status).toBe(200);
  });

  it("makes admins (by an admin only), and never lets one drop or stop themselves", async () => {
    const { boss, a, aId, bossId } = await setUp();
    expect((await t.call("GET", "/admin", undefined, a)).status).toBe(403);
    expect((await t.call("POST", `/admin/users/${aId}/role`, { role: "admin" }, a)).status).toBe(403);
    expect((await t.call("POST", `/admin/users/${aId}/role`, { role: "admin" }, boss)).status).toBe(200);
    expect((await t.call("GET", "/admin", undefined, a)).status).toBe(200);
    expect((await t.call("POST", `/admin/users/${bossId}/role`, { role: "user" }, boss)).status).toBe(409);
    expect((await t.call("POST", `/admin/users/${bossId}/disable`, undefined, boss)).status).toBe(409);
  });

  it("deletes an account only with its address typed, in 30 days, and can bring it back meanwhile; all of it is logged", async () => {
    const { boss, a, aId } = await setUp();
    expect((await t.call("POST", `/admin/users/${aId}/delete`, { confirm: "wrong@example.com" }, boss)).status).toBe(400);
    expect((await t.call("POST", `/admin/users/${aId}/delete`, { confirm: "A@example.com" }, boss)).status).toBe(200);
    expect((await t.call("GET", "/auth/me", undefined, a)).status).toBe(401);
    const detail = (await t.call("GET", `/admin/users/${aId}`, undefined, boss)).body;
    expect(detail.deletingAt).not.toBeNull();
    expect((await t.call("POST", `/admin/users/${aId}/restore`, undefined, boss)).status).toBe(200);
    const log = (await t.call("GET", "/admin/log", undefined, boss)).body.log as { action: string; target: string | null }[];
    expect(log.map((l) => l.action)).toEqual(expect.arrayContaining(["delete", "restore", "role"]));
    expect(log.find((l) => l.action === "delete")?.target).toBe("a@example.com");
  });
});

describe("後台: database backups", () => {
  it("lists, makes, downloads and deletes backups (admins only), and logs it", async () => {
    const { mkdtemp, rm, writeFile } = await import("node:fs/promises");
    const { tmpdir } = await import("node:os");
    const { join } = await import("node:path");
    const { Backups } = await import("../src/backup.ts");
    const dir = await mkdtemp(join(tmpdir(), "goblin-admin-backups-"));
    try {
      t = testApp(database, { backups: new Backups(dir, (out) => writeFile(out, "-- dump\n"), () => t.now()) });
      const boss = await account("boss@example.com");
      const other = await account("a@example.com");
      expect((await t.call("GET", "/admin/backups", undefined, other)).status).toBe(403);
      expect((await t.call("POST", "/admin/backups", undefined, other)).status).toBe(403);

      const empty = (await t.call("GET", "/admin/backups", undefined, boss)).body;
      expect(empty).toMatchObject({ enabled: true, running: null, auto: [], manual: [], failures: [], next: "2026-10-01T17:30:00.000Z" });
      const made = await t.call("POST", "/admin/backups", undefined, boss);
      expect(made.status).toBe(201);
      expect(made.body.name).toBe("goblin-20261001-170000.sql.gz");
      expect((await t.call("GET", "/admin/backups", undefined, boss)).body.manual).toHaveLength(1);

      const file = await t.app.request(`/api/admin/backups/manual/${made.body.name}`, { headers: boss });
      expect(file.status).toBe(200);
      expect(file.headers.get("content-disposition")).toContain(made.body.name);
      expect(await file.text()).toBe("-- dump\n");
      expect((await t.app.request(`/api/admin/backups/manual/${made.body.name}`, { headers: other })).status).toBe(403);
      expect((await t.app.request("/api/admin/backups/manual/..%2Ffailures.json", { headers: boss })).status).toBe(404);

      expect((await t.call("DELETE", `/admin/backups/manual/${made.body.name}`, undefined, boss)).status).toBe(200);
      expect((await t.call("DELETE", `/admin/backups/manual/${made.body.name}`, undefined, boss)).status).toBe(404);
      const log = (await t.call("GET", "/admin/log", undefined, boss)).body.log as { action: string }[];
      expect(log.map((l) => l.action)).toEqual(expect.arrayContaining(["backup", "backup-download", "backup-delete"]));
    } finally {
      await rm(dir, { recursive: true, force: true });
    }
  });

  it("says so when the server has no backup folder", async () => {
    const boss = await account("boss@example.com");
    expect((await t.call("GET", "/admin/backups", undefined, boss)).body).toEqual({ enabled: false });
    expect((await t.call("POST", "/admin/backups", undefined, boss)).status).toBe(503);
  });
});

describe("後台: finding accounts, trends, health, announcements", () => {
  async function boss() {
    const auth = await account("boss@example.com");
    await t.call("GET", "/admin", undefined, auth); // (becomes an admin: ADMIN_EMAILS)
    return auth;
  }

  it("says on /auth/me who may open 後台", async () => {
    const b = await account("boss@example.com");
    const a = await account("a@example.com");
    expect((await t.call("GET", "/auth/me", undefined, b)).body.user.admin).toBe(true); // (ADMIN_EMAILS, before ever opening it)
    expect((await t.call("GET", "/auth/me", undefined, a)).body.user.admin).toBe(false);
  });

  it("finds accounts by any part of the address, name or friend code, by status, a page at a time", async () => {
    const b = await boss();
    for (let i = 0; i < 7; i++) {
      await signUp(t, `p${i}@example.com`);
      t.advance(1000);
    }
    await database.sql`update users set display_name = '小綠 100%' where email = 'p3@example.com'`;
    const page = async (query: string) => (await t.call("GET", `/admin/users?${query}`, undefined, b)).body;
    const first = await page("limit=3");
    expect(first.total).toBe(8);
    expect(first.users.map((u: { email: string }) => u.email)).toEqual(["p6@example.com", "p5@example.com", "p4@example.com"]);
    const second = await page(`limit=3&cursor=${first.next}`);
    expect(second.users.map((u: { email: string }) => u.email)).toEqual(["p3@example.com", "p2@example.com", "p1@example.com"]);
    const last = await page(`limit=3&cursor=${second.next}`);
    expect(last.users).toHaveLength(2);
    expect(last.next).toBeNull();

    expect((await page("q=P5@EXAMPLE")).users.map((u: { email: string }) => u.email)).toEqual(["p5@example.com"]);
    expect((await page(`q=${encodeURIComponent("100%")}`)).users.map((u: { email: string }) => u.email)).toEqual(["p3@example.com"]);
    expect((await page("q=%25")).total).toBe(1); // (a % typed is a %, not "anything")
    const code = (await database.sql<{ c: string }[]>`select friend_code as c from users where email = 'p2@example.com'`)[0]!.c;
    expect((await page(`q=${code.slice(-4)}`)).users[0].email).toBe("p2@example.com");
    expect((await page("status=admin")).users.map((u: { email: string }) => u.email)).toEqual(["boss@example.com"]);
    await database.sql`update users set email_verified_at = null where email = 'p1@example.com'`;
    expect((await page("status=unverified")).users.map((u: { email: string }) => u.email)).toEqual(["p1@example.com"]);
    expect((await t.call("GET", "/admin/users?status=nope", undefined, b)).status).toBe(400);
    // the most lately seen first: only boss has signed in
    expect((await page("sort=lastSeen&limit=1")).users[0].email).toBe("boss@example.com");
  });

  it("shows one account whole, renames it and changes its address (unconfirmed, with a mail); logged", async () => {
    const b = await boss();
    const a = await account("a@example.com");
    await t.call("POST", "/camp/start", { race: "goblin" }, a);
    const aId = (await t.call("GET", "/auth/me", undefined, a)).body.user.id as string;
    let d = (await t.call("GET", `/admin/users/${aId}`, undefined, b)).body;
    expect(d).toMatchObject({ email: "a@example.com", verified: true, camp: { race: "goblin" }, world: null, guild: null, friends: 0, notes: 0 });
    expect(d.events.length).toBeGreaterThan(0);

    expect((await t.call("POST", `/admin/users/${aId}/name`, { displayName: "  " }, b)).status).toBe(400);
    expect((await t.call("POST", `/admin/users/${aId}/name`, { displayName: "改過的名字" }, b)).status).toBe(200);
    await account("taken@example.com");
    expect((await t.call("POST", `/admin/users/${aId}/email`, { email: "Taken@example.com" }, b)).status).toBe(409);
    expect((await t.call("POST", `/admin/users/${aId}/email`, { email: "new@example.com" }, b)).status).toBe(200);
    expect(t.mailer.last("new@example.com")?.subject).toContain("確認你的信箱");
    // the link in it confirms the new address
    expect((await t.call("POST", "/auth/verify-email", { token: t.tokenFromMail("new@example.com") })).status).toBeLessThan(300);
    d = (await t.call("GET", `/admin/users/${aId}`, undefined, b)).body;
    expect(d).toMatchObject({ name: "改過的名字", email: "new@example.com", verified: true });
    expect(d.history.map((h: { action: string }) => h.action)).toEqual(["email", "name"]);
    expect(d.history[0]).toMatchObject({ admin: expect.any(String), detail: { from: "a@example.com", to: "new@example.com" } });

    // the log, one kind of action or one account, a page at a time
    const log = async (query: string) => (await t.call("GET", `/admin/log?${query}`, undefined, b)).body;
    expect((await log("action=name")).log).toHaveLength(1);
    expect((await log(`target=${aId}`)).log.map((l: { action: string }) => l.action)).toEqual(["email", "name"]);
    const one = await log("limit=1");
    expect(one.log).toHaveLength(1);
    expect(one.next).toBe("1");
  });

  it("takes back an unused invite code, and says who made each", async () => {
    const b = await boss();
    const { codes } = (await t.call("POST", "/admin/invites", { count: 1 }, b)).body;
    const [inv] = (await t.call("GET", "/admin/invites", undefined, b)).body.invites;
    expect(inv).toMatchObject({ state: "free", createdBy: expect.any(String) });
    expect((await t.call("POST", `/admin/invites/${inv.id}/revoke`, undefined, b)).status).toBe(200);
    expect((await t.call("POST", `/admin/invites/${inv.id}/revoke`, undefined, b)).status).toBe(409);
    const reg = await t.call("POST", "/auth/register", { email: "late@example.com", password: "a-long-password-1", displayName: "晚到", inviteCode: codes[0] });
    expect(reg.status).toBeGreaterThanOrEqual(400);
  });

  it("logs an admin's status change and deletion of someone's report", async () => {
    const b = await boss();
    const a = await account("a@example.com");
    const made = (await t.call("POST", "/feedback", { kind: "bug", title: "壞掉了", body: "" }, a)).body;
    expect((await t.call("GET", "/admin/overview", undefined, b)).body.feedbackOpen).toBe(1);
    await t.call("POST", `/feedback/${made.id}/status`, { status: "working" }, b);
    await t.call("DELETE", `/feedback/${made.id}`, undefined, b);
    const actions = (await t.call("GET", "/admin/log", undefined, b)).body.log.map((l: { action: string }) => l.action);
    expect(actions.slice(0, 2)).toEqual(["feedback-delete", "feedback-status"]);
  });

  it("counts who came each day (Taiwan time) and who signed up", async () => {
    const b = await boss();
    await account("a@example.com");
    t.advance(86_400_000);
    await t.call("GET", "/auth/me", undefined, b); // (a new day: boss came again)
    const days = (await t.call("GET", "/admin/stats", undefined, b)).body.days as { day: string; active: number; signups: number }[];
    expect(days).toHaveLength(30);
    expect(days.at(-1)).toMatchObject({ day: "2026-10-02", active: 1 });
    expect(days.at(-2)).toMatchObject({ day: "2026-10-01", active: 2, signups: 2 });
    expect((await t.call("GET", "/admin/stats?days=90", undefined, b)).body.days).toHaveLength(90);
  });

  it("says how the server is doing", async () => {
    const b = await boss();
    await signUp(t, "mail@example.com"); // (a mail sent)
    const h = (await t.call("GET", "/admin/health", undefined, b)).body;
    expect(h).toMatchObject({ apiVersion: expect.any(Number), live: { sockets: 0, users: 0 }, maintenance: null, push: { configured: true }, backups: { enabled: false } });
    expect(h.mail.sent).toBeGreaterThan(0);
    expect(h.database.bytes).toBeGreaterThan(0);
    expect(h.database.tables.length).toBeGreaterThan(0);
  });

  it("puts up an announcement (pushed to the phones that take them), shows it to whom it is for, takes it down", async () => {
    const b = await boss();
    const a = await account("a@example.com");
    // a's phone takes pushes
    const phoneLogin = await logIn(t, "a@example.com", passwords.get("a@example.com")!, { ...phone, id: "00000000-0000-4000-9000-000000000001" });
    expect(phoneLogin.status).toBe(200);
    const cookie = { cookie: phoneLogin.headers.get("set-cookie")!.split(";")[0]!, origin: APP_URL };
    await t.call("POST", "/push/subscribe", { endpoint: "https://push.example/a", keys: { p256dh: "k", auth: "a" } }, cookie);

    expect((await t.call("GET", "/admin/announcements/audience?audience=all", undefined, b)).body).toEqual({ users: 2, phones: 1 });
    expect((await t.call("POST", "/admin/announcements", { title: "x" }, a)).status).toBe(403);
    expect((await t.call("POST", "/admin/announcements", { title: "x", url: "https://evil.example" }, b)).status).toBe(400);
    const made = await t.call("POST", "/admin/announcements", { title: "週末維護", body: "週六晚上停機一小時", url: "/settings", push: true }, b);
    expect(made.status).toBe(201);
    await vi.waitFor(() => expect(t.push.sent.some((p) => p.payload.title === "週末維護")).toBe(true));
    expect((await t.call("POST", "/admin/announcements", { title: "又一次", push: true }, b)).status).toBe(429); // (a minute between pushes)
    await t.call("POST", "/admin/announcements", { title: "給管理員", audience: "admins" }, b);

    const seen = async (who: Record<string, string>) => (await t.call("GET", "/announcements", undefined, who)).body.announcements.map((x: { title: string }) => x.title);
    expect(await seen(a)).toEqual(["週末維護"]);
    expect(await seen(b)).toEqual(["給管理員", "週末維護"]);
    await vi.waitFor(async () => {
      const list = (await t.call("GET", "/admin/announcements", undefined, b)).body.announcements;
      expect(list.find((x: { title: string }) => x.title === "週末維護").pushed).toBe(1);
    });

    expect((await t.call("DELETE", `/admin/announcements/${made.body.id}`, undefined, b)).status).toBe(200);
    expect((await t.call("DELETE", `/admin/announcements/${made.body.id}`, undefined, b)).status).toBe(404);
    expect(await seen(a)).toEqual([]);
    const list = (await t.call("GET", "/admin/announcements", undefined, b)).body.announcements;
    expect(list.find((x: { title: string }) => x.title === "週末維護").over).toBe(true);
    // one that ends by itself
    await t.call("POST", "/admin/announcements", { title: "限時", endsAt: new Date(t.now().getTime() + 3_600_000).toISOString() }, b);
    expect(await seen(a)).toEqual(["限時"]);
    t.advance(2 * 3_600_000);
    expect(await seen(a)).toEqual([]);
  });
});
