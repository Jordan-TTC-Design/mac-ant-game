import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import type { Database } from "../src/db/client.ts";
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

let macs = 0;
async function account(email: string) {
  const password = await signUp(t, email);
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
