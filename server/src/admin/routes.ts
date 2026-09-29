import { and, count, desc, eq, gt, isNotNull, isNull, lte, max, sql } from "drizzle-orm";
import { Hono } from "hono";
import { z } from "zod";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { adminLog, campResidents, camps, devices, expeditions, invites, notes, sessions, users, worldCells, worldPlayers } from "../db/schema.ts";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { Readable } from "node:stream";
import { BackupError, KEEP_AUTO_DAYS, MANUAL_MAX, nextSlot } from "../backup.ts";
import { apiError, readJson } from "../http.ts";
import { hashSecret, newInviteCode, normalizeCode } from "../lib/tokens.ts";

const inviteInput = z.object({ count: z.number().int().min(1).max(50).default(1), days: z.number().int().min(1).max(90).default(14) });

const roleInput = z.object({ role: z.enum(["user", "admin"]) });
const deleteInput = z.object({ confirm: z.string().max(200) });

/**
 * 後台 (server/DESIGN.md §12): who runs the server sees how it is used, hands out invite codes, and looks after the accounts
 * (stop one, let it back in, sign it out everywhere, confirm its address, make it an admin, delete it). Admins are accounts
 * whose role is admin; an address in ADMIN_EMAILS becomes one the first time it comes here (the very first admin), and
 * `make admin email=…` does the same on the server. Everything done here goes into the admin log.
 */
export function adminRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  const bootstrap = new Set((deps.config.ADMIN_EMAILS ?? "").split(",").map((e) => e.trim().toLowerCase()).filter(Boolean));
  app.use("*", requireAuth(deps));
  app.use("*", async (c, next) => {
    const me = c.get("session").user;
    const [row] = await db.select({ role: users.role }).from(users).where(eq(users.id, me.id));
    if (row?.role !== "admin") {
      if (!bootstrap.has(me.email.toLowerCase())) return apiError(c, 403, "forbidden", "只有管理員能看後台。");
      await db.update(users).set({ role: "admin" }).where(eq(users.id, me.id));
      await db.insert(adminLog).values({ adminId: me.id, targetId: me.id, action: "role", detail: { role: "admin", by: "ADMIN_EMAILS" } });
    }
    await next();
  });
  const log = (adminId: string, targetId: string | null, action: string, detail: object = {}) => db.insert(adminLog).values({ adminId, targetId, action, detail });

  /** Whether this account is an admin (the page asks before showing its link). */
  app.get("/", (c) => c.json({ admin: true }));

  app.get("/overview", async (c) => {
    const at = now();
    const day = new Date(at.getTime() - 86_400_000);
    const week = new Date(at.getTime() - 7 * 86_400_000);
    const one = async (q: Promise<{ n: number }[]>) => (await q)[0]?.n ?? 0;
    const [usersAll, verified, active1, active7, macs, phones, notesLive, residents, worldOpen, held, walking, fought, invitesFree, invitesUsed, invitesExpired] = await Promise.all([
      one(db.select({ n: count() }).from(users)),
      one(db.select({ n: count() }).from(users).where(isNotNull(users.emailVerifiedAt))),
      one(db.select({ n: sql<number>`count(distinct ${devices.userId})::int` }).from(devices).where(gt(devices.lastSeenAt, day))),
      one(db.select({ n: sql<number>`count(distinct ${devices.userId})::int` }).from(devices).where(gt(devices.lastSeenAt, week))),
      one(db.select({ n: count() }).from(devices).where(eq(devices.kind, "mac"))),
      one(db.select({ n: count() }).from(devices).where(eq(devices.kind, "pwa"))),
      one(db.select({ n: count() }).from(notes).where(eq(notes.deleted, false))),
      one(db.select({ n: count() }).from(campResidents).where(isNull(campResidents.diedAt))),
      one(db.select({ n: count() }).from(worldPlayers).where(eq(worldPlayers.open, true))),
      one(db.select({ n: count() }).from(worldCells).where(isNotNull(worldCells.owner))),
      one(db.select({ n: count() }).from(expeditions).where(eq(expeditions.status, "walking"))),
      one(db.select({ n: count() }).from(expeditions).where(eq(expeditions.status, "done"))),
      one(db.select({ n: count() }).from(invites).where(and(isNull(invites.usedAt), gt(invites.expiresAt, at)))),
      one(db.select({ n: count() }).from(invites).where(isNotNull(invites.usedAt))),
      one(db.select({ n: count() }).from(invites).where(and(isNull(invites.usedAt), lte(invites.expiresAt, at)))),
    ]);
    const races = await db.select({ race: camps.race, n: count() }).from(camps).groupBy(camps.race);
    return c.json({
      users: { all: usersAll, verified, active1, active7 },
      devices: { macs, phones },
      notes: notesLive,
      camps: Object.fromEntries(races.map((r) => [r.race, r.n])),
      residents,
      world: { open: worldOpen, heldCells: held, walking, fought },
      invites: { free: invitesFree, used: invitesUsed, expired: invitesExpired },
    });
  });

  /** Everyone, newest first: their camp, devices and when they were last seen. */
  app.get("/users", async (c) => {
    const rows = await db
      .select({
        id: users.id,
        email: users.email,
        name: users.displayName,
        createdAt: users.createdAt,
        verified: users.emailVerifiedAt,
        deleting: users.deletingAt,
        role: users.role,
        disabled: users.disabledAt,
        race: camps.race,
        peak: camps.peak,
      })
      .from(users)
      .leftJoin(camps, eq(camps.userId, users.id))
      .orderBy(desc(users.createdAt))
      .limit(500);
    const seen = new Map(
      (await db.select({ userId: devices.userId, last: max(devices.lastSeenAt), n: count() }).from(devices).groupBy(devices.userId)).map((r) => [r.userId, r]),
    );
    const alive = new Map(
      (await db.select({ userId: campResidents.userId, n: count() }).from(campResidents).where(isNull(campResidents.diedAt)).groupBy(campResidents.userId)).map((r) => [r.userId, r.n]),
    );
    const cells = new Map(
      (await db.select({ owner: worldCells.owner, n: count() }).from(worldCells).where(isNotNull(worldCells.owner)).groupBy(worldCells.owner)).map((r) => [r.owner, r.n]),
    );
    return c.json({
      users: rows.map((r) => ({
        id: r.id,
        email: r.email,
        name: r.name,
        createdAt: r.createdAt.toISOString(),
        verified: !!r.verified,
        deleting: !!r.deleting,
        role: r.role,
        disabled: !!r.disabled,
        camp: r.race ? { race: r.race, population: alive.get(r.id) ?? 0, peak: r.peak ?? 0, cells: cells.get(r.id) ?? 0 } : null,
        devices: seen.get(r.id)?.n ?? 0,
        lastSeenAt: seen.get(r.id)?.last?.toISOString() ?? null,
      })),
    });
  });

  /** Invite codes made here (shown once, only their hashes are kept), and how the ones made so far were used. */
  app.post("/invites", async (c) => {
    const body = await readJson(c, inviteInput);
    if ("response" in body) return body.response;
    const expiresAt = new Date(now().getTime() + body.data.days * 86_400_000);
    const codes = Array.from({ length: body.data.count }, newInviteCode);
    await db.insert(invites).values(codes.map((code) => ({ codeHash: hashSecret(normalizeCode(code)), createdBy: c.get("session").user.id, expiresAt })));
    await log(c.get("session").user.id, null, "invites", { count: codes.length, days: body.data.days });
    return c.json({ codes, expiresAt: expiresAt.toISOString() }, 201);
  });

  app.get("/invites", async (c) => {
    const at = now();
    const rows = await db
      .select({ createdAt: invites.createdAt, expiresAt: invites.expiresAt, usedAt: invites.usedAt, usedBy: users.email })
      .from(invites)
      .leftJoin(users, eq(users.id, invites.usedBy))
      .orderBy(desc(invites.createdAt))
      .limit(200);
    return c.json({
      invites: rows.map((r) => ({
        createdAt: r.createdAt.toISOString(),
        expiresAt: r.expiresAt.toISOString(),
        usedAt: r.usedAt?.toISOString() ?? null,
        usedBy: r.usedBy ?? null,
        state: r.usedAt ? "used" : r.expiresAt <= at ? "expired" : "free",
      })),
    });
  });

  // ── one account ─────────────────────────────────────────
  const target = async (id: string) => {
    if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
    const [row] = await db.select().from(users).where(eq(users.id, id));
    return row ?? null;
  };
  const signOutEverywhere = async (id: string) => {
    await db.update(sessions).set({ revokedAt: now() }).where(and(eq(sessions.userId, id), isNull(sessions.revokedAt)));
    deps.hub.close(id);
  };

  /** One account: its devices and sign-ins, its camp, and what admins did to it. */
  app.get("/users/:id", async (c) => {
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    const devs = await db.select().from(devices).where(eq(devices.userId, u.id)).orderBy(desc(devices.lastSeenAt));
    const live = await db
      .select({ deviceId: sessions.deviceId, n: count() })
      .from(sessions)
      .where(and(eq(sessions.userId, u.id), isNull(sessions.revokedAt), gt(sessions.expiresAt, now())))
      .groupBy(sessions.deviceId);
    const signedIn = new Map(live.map((l) => [l.deviceId, l.n]));
    const [camp] = await db.select().from(camps).where(eq(camps.userId, u.id));
    const [{ alive }] = (await db.select({ alive: count() }).from(campResidents).where(and(eq(campResidents.userId, u.id), isNull(campResidents.diedAt)))) as [{ alive: number }];
    const history = await db.select().from(adminLog).where(eq(adminLog.targetId, u.id)).orderBy(desc(adminLog.at)).limit(20);
    return c.json({
      id: u.id,
      email: u.email,
      name: u.displayName,
      role: u.role,
      verified: !!u.emailVerifiedAt,
      disabled: !!u.disabledAt,
      deletingAt: u.deletingAt?.toISOString() ?? null,
      createdAt: u.createdAt.toISOString(),
      devices: devs.map((d) => ({ id: d.id, kind: d.kind, name: d.name, lastSeenAt: d.lastSeenAt.toISOString(), signedIn: (signedIn.get(d.id) ?? 0) > 0 })),
      camp: camp ? { race: camp.race, population: alive, peak: camp.peak, startedAt: camp.startedAt.toISOString() } : null,
      history: history.map((h) => ({ at: h.at.toISOString(), action: h.action, detail: h.detail })),
    });
  });

  app.post("/users/:id/disable", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (u.id === me.id) return apiError(c, 409, "conflict", "不能停用自己。");
    await db.update(users).set({ disabledAt: now() }).where(eq(users.id, u.id));
    await signOutEverywhere(u.id);
    await log(me.id, u.id, "disable");
    return c.json({ ok: true });
  });

  app.post("/users/:id/enable", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    await db.update(users).set({ disabledAt: null }).where(eq(users.id, u.id));
    await log(me.id, u.id, "enable");
    return c.json({ ok: true });
  });

  app.post("/users/:id/sign-out", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (u.id === me.id) return apiError(c, 409, "conflict", "要登出自己的其他裝置，請到「設定」。");
    await signOutEverywhere(u.id);
    await log(me.id, u.id, "sign-out");
    return c.json({ ok: true });
  });

  app.post("/users/:id/verify", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    await db.update(users).set({ emailVerifiedAt: u.emailVerifiedAt ?? now() }).where(eq(users.id, u.id));
    await log(me.id, u.id, "verify");
    return c.json({ ok: true });
  });

  app.post("/users/:id/role", async (c) => {
    const me = c.get("session").user;
    const body = await readJson(c, roleInput);
    if ("response" in body) return body.response;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (u.id === me.id && body.data.role !== "admin") return apiError(c, 409, "conflict", "不能拿掉自己的管理員（請另一位管理員做）。");
    await db.update(users).set({ role: body.data.role }).where(eq(users.id, u.id));
    await log(me.id, u.id, "role", { role: body.data.role });
    return c.json({ ok: true });
  });

  /** Deleting: the account is signed out and goes in 30 days (maintenance.ts); until then it can be brought back. */
  app.post("/users/:id/delete", async (c) => {
    const me = c.get("session").user;
    const body = await readJson(c, deleteInput);
    if ("response" in body) return body.response;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (u.id === me.id) return apiError(c, 409, "conflict", "不能刪除自己。");
    if (body.data.confirm.trim().toLowerCase() !== u.email.toLowerCase()) return apiError(c, 400, "invalid_input", "要輸入這個帳號的信箱才能刪除。");
    await db.update(users).set({ deletingAt: now() }).where(eq(users.id, u.id));
    await signOutEverywhere(u.id);
    await log(me.id, u.id, "delete");
    return c.json({ ok: true });
  });

  app.post("/users/:id/restore", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    await db.update(users).set({ deletingAt: null }).where(eq(users.id, u.id));
    await log(me.id, u.id, "restore");
    return c.json({ ok: true });
  });

  // --- database backups (backup.ts) ---

  /** The backups there are (auto and manual, newest first), the latest failures, and when the next auto one is due. */
  app.get("/backups", async (c) => {
    const b = deps.backups;
    if (!b) return c.json({ enabled: false });
    const [auto, manual, failures] = await Promise.all([b.files("auto"), b.files("manual"), b.failures()]);
    return c.json({ enabled: true, running: b.running, next: nextSlot(now()).toISOString(), keepDays: KEEP_AUTO_DAYS, manualMax: MANUAL_MAX, auto, manual, failures: failures.slice(0, 5) });
  });

  /** A manual backup, now (answers when it is done). */
  app.post("/backups", async (c) => {
    const me = c.get("session").user;
    if (!deps.backups) return apiError(c, 503, "unavailable", "伺服器沒有設定備份資料夾（BACKUP_DIR）。");
    try {
      const made = await deps.backups.make("manual");
      await log(me.id, null, "backup", { name: made.name });
      return c.json(made, 201);
    } catch (err) {
      if (err instanceof BackupError) return apiError(c, 409, "conflict", err.message);
      return apiError(c, 500, "backup_failed", `備份失敗：${err instanceof Error ? err.message : String(err)}`);
    }
  });

  app.get("/backups/:kind/:name", async (c) => {
    const me = c.get("session").user;
    const { kind, name } = c.req.param();
    const file = deps.backups?.file(kind, name);
    const size = file ? await stat(file).then((s) => s.size).catch(() => null) : null;
    if (!file || size === null) return apiError(c, 404, "not_found", "沒有這份備份。");
    await log(me.id, null, "backup-download", { kind, name });
    return c.body(Readable.toWeb(createReadStream(file)) as ReadableStream, 200, {
      "content-type": "application/gzip",
      "content-length": String(size),
      "content-disposition": `attachment; filename="${name}"`,
    });
  });

  app.delete("/backups/:kind/:name", async (c) => {
    const me = c.get("session").user;
    const { kind, name } = c.req.param();
    if (!deps.backups) return apiError(c, 404, "not_found", "沒有這份備份。");
    try {
      await deps.backups.remove(kind, name);
    } catch (err) {
      if (err instanceof BackupError) return apiError(c, 404, "not_found", err.message);
      throw err;
    }
    await log(me.id, null, "backup-delete", { kind, name });
    return c.json({ ok: true });
  });

  /** What admins did lately. */
  app.get("/log", async (c) => {
    const rows = await db
      .select({ at: adminLog.at, action: adminLog.action, detail: adminLog.detail, admin: sql<string | null>`(select display_name from users where id = ${adminLog.adminId})`, target: sql<string | null>`(select email from users where id = ${adminLog.targetId})` })
      .from(adminLog)
      .orderBy(desc(adminLog.at))
      .limit(100);
    return c.json({ log: rows.map((r) => ({ ...r, at: r.at.toISOString() })) });
  });

  return app;
}
