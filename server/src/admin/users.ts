import { and, count, desc, eq, gt, ilike, inArray, isNotNull, isNull, max, or, sql, type AnyColumn, type SQL } from "drizzle-orm";
import type { Hono } from "hono";
import { z } from "zod";
import {
  ADMIN_USER_SORTS,
  ADMIN_USER_STATUSES,
  displayNameSchema,
  emailSchema,
  type AdminUserDetail,
  type AdminUserPage,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import {
  adminLog,
  blocks,
  campEvents,
  campResidents,
  camps,
  devices,
  emailTokens,
  expeditions,
  feedback,
  friendships,
  guildMembers,
  guilds,
  notes,
  sessions,
  users,
  worldCells,
  worldPlayers,
} from "../db/schema.ts";
import { apiError, readJson } from "../http.ts";
import { hashSecret, newToken } from "../lib/tokens.ts";
import { adminResetMail, verifyMail } from "../mail/templates.ts";

/** How long the link in a mail an admin asked for works (longer than the 1 hour of 「忘記密碼」: nobody asked for it just now). */
const ADMIN_RESET_HOURS = 24;
const VERIFY_HOURS = 24;
const PAGE = 50;

const listQuery = z.object({
  q: z.string().trim().max(100).default(""),
  status: z.enum(ADMIN_USER_STATUSES).default("all"),
  sort: z.enum(ADMIN_USER_SORTS).default("created"),
  cursor: z.coerce.number().int().min(0).default(0),
  limit: z.coerce.number().int().min(1).max(200).default(PAGE),
});
const roleInput = z.object({ role: z.enum(["user", "admin"]) });
const deleteInput = z.object({ confirm: z.string().max(200) });
const nameInput = z.object({ displayName: displayNameSchema });
const emailInput = z.object({ email: emailSchema });

export type AdminLog = (adminId: string, targetId: string | null, action: string, detail?: object) => Promise<unknown>;

/** 後台's accounts: find them, look at one, and look after it. */
export function adminUserRoutes(app: Hono<AppEnv>, deps: AppDeps, log: AdminLog) {
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());

  /**
   * Accounts, a page at a time: `q` finds an address, a name or a friend code (any part of it); `status` keeps only
   * admins, the stopped, those being deleted or the unconfirmed; newest first, or the most lately seen first.
   */
  app.get("/users", async (c) => {
    const query = listQuery.safeParse(c.req.query());
    if (!query.success) return apiError(c, 400, "invalid_input", "搜尋條件不對。");
    const { q, status, sort, cursor, limit } = query.data;
    const lastSeen = sql<Date | null>`(select max(${devices.lastSeenAt}) from ${devices} where ${devices.userId} = ${users.id})`;
    const where: SQL[] = [];
    if (q) {
      const like = `%${q.replace(/[\\%_]/g, (ch) => `\\${ch}`)}%`;
      where.push(or(ilike(users.email, like), ilike(users.displayName, like), ilike(users.friendCode, like))!);
    }
    if (status === "admin") where.push(eq(users.role, "admin"));
    if (status === "disabled") where.push(isNotNull(users.disabledAt));
    if (status === "deleting") where.push(isNotNull(users.deletingAt));
    if (status === "unverified") where.push(isNull(users.emailVerifiedAt));
    const filter = where.length ? and(...where) : undefined;
    const [{ total }] = (await db.select({ total: count() }).from(users).where(filter)) as [{ total: number }];
    const rows = await db
      .select({
        id: users.id,
        email: users.email,
        name: users.displayName,
        friendCode: users.friendCode,
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
      .where(filter)
      .orderBy(...(sort === "lastSeen" ? [sql`${lastSeen} desc nulls last`, desc(users.createdAt)] : [desc(users.createdAt)]), users.id)
      .offset(cursor)
      .limit(limit);
    const ids = rows.map((r) => r.id);
    const inIds = (col: AnyColumn) => (ids.length ? inArray(col, ids) : sql`false`);
    const seen = new Map(
      (await db.select({ userId: devices.userId, last: max(devices.lastSeenAt), n: count() }).from(devices).where(inIds(devices.userId)).groupBy(devices.userId)).map((r) => [r.userId, r]),
    );
    const alive = new Map(
      (
        await db
          .select({ userId: campResidents.userId, n: count() })
          .from(campResidents)
          .where(and(inIds(campResidents.userId), isNull(campResidents.diedAt)))
          .groupBy(campResidents.userId)
      ).map((r) => [r.userId, r.n]),
    );
    const cells = new Map((await db.select({ owner: worldCells.owner, n: count() }).from(worldCells).where(inIds(worldCells.owner)).groupBy(worldCells.owner)).map((r) => [r.owner, r.n]));
    const body: AdminUserPage = {
      total,
      next: cursor + rows.length < total ? String(cursor + rows.length) : null,
      users: rows.map((r) => ({
        id: r.id,
        email: r.email,
        name: r.name,
        friendCode: r.friendCode,
        createdAt: r.createdAt.toISOString(),
        verified: !!r.verified,
        deleting: !!r.deleting,
        role: r.role,
        disabled: !!r.disabled,
        camp: r.race ? { race: r.race, population: alive.get(r.id) ?? 0, peak: r.peak ?? 0, cells: cells.get(r.id) ?? 0 } : null,
        devices: seen.get(r.id)?.n ?? 0,
        lastSeenAt: seen.get(r.id)?.last?.toISOString() ?? null,
      })),
    };
    return c.json(body);
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
  const one = async (q: Promise<{ n: number }[]>) => (await q)[0]?.n ?? 0;

  /** One account: its devices and sign-ins, its camp, big world, guild and friends, and what admins did to it. */
  app.get("/users/:id", async (c) => {
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    const at = now();
    const devs = await db.select().from(devices).where(eq(devices.userId, u.id)).orderBy(desc(devices.lastSeenAt));
    const live = await db
      .select({ deviceId: sessions.deviceId, n: count() })
      .from(sessions)
      .where(and(eq(sessions.userId, u.id), isNull(sessions.revokedAt), gt(sessions.expiresAt, at)))
      .groupBy(sessions.deviceId);
    const signedIn = new Map(live.map((l) => [l.deviceId, l.n]));
    const [camp] = await db.select().from(camps).where(eq(camps.userId, u.id));
    const [world] = await db.select().from(worldPlayers).where(eq(worldPlayers.userId, u.id));
    const [guild] = await db
      .select({ id: guilds.id, name: guilds.name, level: guilds.level, role: guildMembers.role })
      .from(guildMembers)
      .innerJoin(guilds, eq(guilds.id, guildMembers.guildId))
      .where(eq(guildMembers.userId, u.id));
    const [alive, cells, walking, friends, blocked, notesLive, reports] = await Promise.all([
      one(db.select({ n: count() }).from(campResidents).where(and(eq(campResidents.userId, u.id), isNull(campResidents.diedAt)))),
      one(db.select({ n: count() }).from(worldCells).where(eq(worldCells.owner, u.id))),
      one(db.select({ n: count() }).from(expeditions).where(and(eq(expeditions.userId, u.id), eq(expeditions.status, "walking")))),
      one(db.select({ n: count() }).from(friendships).where(and(or(eq(friendships.userA, u.id), eq(friendships.userB, u.id)), isNotNull(friendships.acceptedAt)))),
      one(db.select({ n: count() }).from(blocks).where(eq(blocks.userId, u.id))),
      one(db.select({ n: count() }).from(notes).where(and(eq(notes.userId, u.id), eq(notes.deleted, false)))),
      one(db.select({ n: count() }).from(feedback).where(eq(feedback.userId, u.id))),
    ]);
    const events = await db.select({ at: campEvents.at, kind: campEvents.kind }).from(campEvents).where(eq(campEvents.userId, u.id)).orderBy(desc(campEvents.seq)).limit(20);
    const history = await db
      .select({ at: adminLog.at, action: adminLog.action, detail: adminLog.detail, admin: users.displayName })
      .from(adminLog)
      .leftJoin(users, eq(users.id, adminLog.adminId))
      .where(eq(adminLog.targetId, u.id))
      .orderBy(desc(adminLog.at))
      .limit(20);
    const body: AdminUserDetail = {
      id: u.id,
      email: u.email,
      name: u.displayName,
      friendCode: u.friendCode,
      role: u.role,
      verified: !!u.emailVerifiedAt,
      verifiedAt: u.emailVerifiedAt?.toISOString() ?? null,
      disabled: !!u.disabledAt,
      deletingAt: u.deletingAt?.toISOString() ?? null,
      createdAt: u.createdAt.toISOString(),
      devices: devs.map((d) => ({ id: d.id, kind: d.kind, name: d.name, lastSeenAt: d.lastSeenAt.toISOString(), signedIn: (signedIn.get(d.id) ?? 0) > 0, push: !!d.pushSubscription })),
      camp: camp ? { race: camp.race, population: alive, peak: camp.peak, startedAt: camp.startedAt.toISOString() } : null,
      world: world ? { xp: world.xp, cells, walking, homeCell: world.homeCell } : null,
      guild: guild ?? null,
      friends,
      blocked,
      notes: notesLive,
      feedback: reports,
      events: events.map((e) => ({ at: e.at.toISOString(), kind: e.kind })),
      history: history.map((h) => ({ at: h.at.toISOString(), action: h.action, admin: h.admin, detail: (h.detail as Record<string, unknown> | null) ?? null })),
    };
    return c.json(body);
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

  /** Mails the person a link to set a password of their own (the same link as 「忘記密碼」, 24 hours); nothing changes until they use it. */
  app.post("/users/:id/send-reset", async (c) => {
    const me = c.get("session").user;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (u.deletingAt) return apiError(c, 409, "conflict", "這個帳號正在等著被刪除，請先復原。");
    const token = await newLink(u.id, "reset", ADMIN_RESET_HOURS);
    try {
      await deps.mailer.send(adminResetMail(u.email, `${deps.config.APP_URL}/reset-password?token=${encodeURIComponent(token)}`, ADMIN_RESET_HOURS));
    } catch (err) {
      return apiError(c, 503, "unavailable", `信寄不出去：${err instanceof Error ? err.message : String(err)}`);
    }
    await log(me.id, u.id, "send-reset");
    return c.json({ ok: true });
  });

  /** A new mail link (an older one of the same kind stops working: only the newest mail counts). */
  async function newLink(userId: string, purpose: "verify" | "reset", hours: number) {
    const at = now();
    await db.update(emailTokens).set({ usedAt: at }).where(and(eq(emailTokens.userId, userId), eq(emailTokens.purpose, purpose), isNull(emailTokens.usedAt)));
    const token = newToken("gce");
    await db.insert(emailTokens).values({ userId, purpose, tokenHash: hashSecret(token), createdAt: at, expiresAt: new Date(at.getTime() + hours * 3_600_000) });
    return token;
  }

  /** A new name (one that is rude or pretends to be someone, say). */
  app.post("/users/:id/name", async (c) => {
    const me = c.get("session").user;
    const body = await readJson(c, nameInput);
    if ("response" in body) return body.response;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    if (body.data.displayName === u.displayName) return c.json({ ok: true });
    await db.update(users).set({ displayName: body.data.displayName }).where(eq(users.id, u.id));
    await log(me.id, u.id, "name", { from: u.displayName, to: body.data.displayName });
    return c.json({ ok: true });
  });

  /** A new address (the person lost the old one): it is unconfirmed until they open the mail sent to it. */
  app.post("/users/:id/email", async (c) => {
    const me = c.get("session").user;
    const body = await readJson(c, emailInput);
    if ("response" in body) return body.response;
    const u = await target(c.req.param("id"));
    if (!u) return apiError(c, 404, "not_found", "沒有這個帳號。");
    const email = body.data.email;
    if (email.toLowerCase() === u.email.toLowerCase()) return apiError(c, 400, "invalid_input", "跟原本的信箱一樣。");
    const [taken] = await db.select({ id: users.id }).from(users).where(eq(users.email, email));
    if (taken) return apiError(c, 409, "conflict", "這個信箱已經有別的帳號在用。");
    await db.update(users).set({ email, emailVerifiedAt: null }).where(eq(users.id, u.id));
    await log(me.id, u.id, "email", { from: u.email, to: email });
    const token = await newLink(u.id, "verify", VERIFY_HOURS);
    try {
      await deps.mailer.send(verifyMail(email, u.displayName, `${deps.config.APP_URL}/verify-email?token=${encodeURIComponent(token)}`));
    } catch (err) {
      return c.json({ ok: true, warning: `信箱改好了，但確認信寄不出去：${err instanceof Error ? err.message : String(err)}` });
    }
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
}
