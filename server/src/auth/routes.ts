import { Hono, type Context } from "hono";
import { z } from "zod";
import { and, desc, eq, gt, isNull, ne } from "drizzle-orm";
import {
  emailOnlyInput,
  loginInput,
  registerInput,
  resetPasswordInput,
  verifyEmailInput,
  type LoginResult,
  type PublicUser,
  type SessionInfo,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { devices, emailTokens, invites, sessions, users } from "../db/schema.ts";
import { apiError, clientIp, readJson } from "../http.ts";
import { burnPasswordTime, hashPassword, verifyPassword } from "../lib/passwords.ts";
import { RateLimiter } from "../lib/rate-limit.ts";
import { hashSecret, newFriendCode, newToken, normalizeCode } from "../lib/tokens.ts";
import type { Mail } from "../mail/mailer.ts";
import { alreadyRegisteredMail, resetMail, verifyMail } from "../mail/templates.ts";
import { clearSessionCookie, createSession, requireAuth, setSessionCookie, type Db } from "./session.ts";

/** How long a Mac's link into the web page works. */
const HANDOFF_MINUTES = 3;
const handoffInput = z.object({ webDevice: z.uuid(), to: z.string().regex(/^\/[a-z0-9/_-]*$/i).max(80).default("/world") });

const HOUR = 3_600_000;
const VERIFY_HOURS = 24;
const RESET_HOURS = 1;

/** The same answer whether or not the address has an account, so nobody can find out who uses the app. */
const SENT = { ok: true, message: "如果資料正確，我們已經寄了一封信給你，請到信箱查看。" };

function publicUser(u: { id: string; email: string; displayName: string; friendCode: string }): PublicUser {
  return { id: u.id, email: u.email, displayName: u.displayName, friendCode: u.friendCode };
}

/** 註冊、驗證信箱、登入、登出、裝置、忘記密碼。 See server/DESIGN.md §3. */
export function authRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  const limiter = deps.limiter ?? new RateLimiter();
  const auth = requireAuth(deps);
  const link = (path: string, token: string) => `${deps.config.APP_URL}${path}?token=${encodeURIComponent(token)}`;

  /** Sent without waiting, so how long the mail service takes tells nothing about the address. */
  function mail(m: Mail) {
    deps.mailer.send(m).catch((err) => console.error(`mail to ${m.to} failed:`, err));
  }

  /** 0 = go ahead; else the 429 to send back. Every rule given must allow it. */
  function limited(c: Context, rules: [key: string, limit: number, windowSeconds: number][]): Response | null {
    let wait = 0;
    for (const [key, limit, seconds] of rules) wait = Math.max(wait, limiter.hit(key, limit, seconds));
    if (!wait) return null;
    c.header("Retry-After", String(wait));
    return apiError(c, 429, "rate_limited", "嘗試太多次了，請稍後再試。", { retryAfter: wait });
  }

  async function newEmailToken(userId: string, purpose: "verify" | "reset", at: Date, db_: Db = db) {
    // an older link of the same kind stops working: only the newest mail counts
    await db_.update(emailTokens).set({ usedAt: at }).where(and(eq(emailTokens.userId, userId), eq(emailTokens.purpose, purpose), isNull(emailTokens.usedAt)));
    const token = newToken("gce");
    const hours = purpose === "verify" ? VERIFY_HOURS : RESET_HOURS;
    await db_.insert(emailTokens).values({ userId, purpose, tokenHash: hashSecret(token), createdAt: at, expiresAt: new Date(at.getTime() + hours * HOUR) });
    return token;
  }

  // ── 註冊 ──────────────────────────────────────────────
  app.post("/register", async (c) => {
    const ip = clientIp(c, deps.config.TRUST_PROXY);
    const stop = limited(c, [[`register:${ip}`, 10, 3600]]);
    if (stop) return stop;
    const body = await readJson(c, registerInput);
    if ("response" in body) return body.response;
    const { email, password, displayName, inviteCode } = body.data;
    const at = now();

    const outcome = await db.transaction(async (tx) => {
      const [invite] = await tx
        .select()
        .from(invites)
        .where(and(eq(invites.codeHash, hashSecret(normalizeCode(inviteCode))), isNull(invites.usedAt), gt(invites.expiresAt, at)))
        .for("update");
      if (!invite) return { kind: "invite_invalid" as const };
      const [existing] = await tx.select().from(users).where(eq(users.email, email));
      if (existing) return { kind: "exists" as const, user: existing };

      const passwordHash = await hashPassword(password);
      for (let attempt = 0; attempt < 5; attempt++) {
        const [user] = await tx
          .insert(users)
          .values({ email, passwordHash, displayName, friendCode: newFriendCode(), createdAt: at })
          .onConflictDoNothing()
          .returning();
        if (!user) continue; // the friend code was taken (or the address, by someone registering at the same moment: caught next round)
        await tx.update(invites).set({ usedAt: at, usedBy: user.id }).where(eq(invites.codeHash, invite.codeHash));
        const token = await newEmailToken(user.id, "verify", at, tx);
        return { kind: "created" as const, user, token };
      }
      const [raced] = await tx.select().from(users).where(eq(users.email, email));
      if (raced) return { kind: "exists" as const, user: raced };
      throw new Error("could not find a free friend code");
    });

    if (outcome.kind === "invite_invalid") return apiError(c, 400, "invite_invalid", "邀請碼不對、已經用過或過期了。");
    if (outcome.kind === "created") {
      mail(verifyMail(email, displayName, link("/verify-email", outcome.token)));
    } else {
      await burnPasswordTime(password); // (a new account hashes the password; take as long here)
      const user = outcome.user;
      if (user.emailVerifiedAt) {
        mail(alreadyRegisteredMail(user.email, `${deps.config.APP_URL}/login`, `${deps.config.APP_URL}/forgot-password`));
      } else {
        mail(verifyMail(user.email, user.displayName, link("/verify-email", await newEmailToken(user.id, "verify", at))));
      }
    }
    return c.json(SENT, 202);
  });

  // ── 驗證信箱 ──────────────────────────────────────────
  app.post("/verify-email", async (c) => {
    const stop = limited(c, [[`verify:${clientIp(c, deps.config.TRUST_PROXY)}`, 20, 600]]);
    if (stop) return stop;
    const body = await readJson(c, verifyEmailInput);
    if ("response" in body) return body.response;
    const at = now();
    const ok = await db.transaction(async (tx) => {
      const [row] = await tx
        .select()
        .from(emailTokens)
        .where(and(eq(emailTokens.tokenHash, hashSecret(body.data.token)), eq(emailTokens.purpose, "verify"), isNull(emailTokens.usedAt), gt(emailTokens.expiresAt, at)))
        .for("update");
      if (!row) return false;
      await tx.update(emailTokens).set({ usedAt: at }).where(eq(emailTokens.id, row.id));
      await tx.update(users).set({ emailVerifiedAt: at }).where(and(eq(users.id, row.userId), isNull(users.emailVerifiedAt)));
      return true;
    });
    if (!ok) return apiError(c, 400, "token_invalid", "這個連結已經失效了，請重新寄一次確認信。");
    return c.json({ ok: true, message: "信箱確認好了，可以登入了！" });
  });

  app.post("/resend-verification", async (c) => {
    const body = await readJson(c, emailOnlyInput);
    if ("response" in body) return body.response;
    const stop = limited(c, [
      [`resend:${clientIp(c, deps.config.TRUST_PROXY)}`, 10, 3600],
      [`resend:${body.data.email.toLowerCase()}`, 3, 3600],
    ]);
    if (stop) return stop;
    const [user] = await db.select().from(users).where(and(eq(users.email, body.data.email), isNull(users.deletingAt)));
    if (user && !user.emailVerifiedAt) {
      mail(verifyMail(user.email, user.displayName, link("/verify-email", await newEmailToken(user.id, "verify", now()))));
    }
    return c.json(SENT, 202);
  });

  // ── 登入、登出 ────────────────────────────────────────
  app.post("/login", async (c) => {
    const body = await readJson(c, loginInput);
    if ("response" in body) return body.response;
    const { email, password, device } = body.data;
    const ip = clientIp(c, deps.config.TRUST_PROXY);
    const stop = limited(c, [
      [`login:${ip}`, 30, 60],
      [`login:${ip}:${email.toLowerCase()}`, 5, 60],
    ]);
    if (stop) return stop;

    const [user] = await db.select().from(users).where(and(eq(users.email, email), isNull(users.deletingAt)));
    if (!user) {
      await burnPasswordTime(password);
      return apiError(c, 401, "invalid_credentials", "信箱或密碼不對。");
    }
    if (!(await verifyPassword(user.passwordHash, password))) return apiError(c, 401, "invalid_credentials", "信箱或密碼不對。");
    if (!user.emailVerifiedAt) return apiError(c, 403, "email_not_verified", "請先到信箱點確認連結（找不到信可以重寄一次）。");
    if (user.disabledAt) return apiError(c, 403, "forbidden", "這個帳號被管理員停用了，有問題請找管理員。");

    const at = now();
    const session = await db.transaction(async (tx) => {
      // this device is signed in once: whoever was signed in on it before (this account or another) is signed out there
      const replaced = await tx
        .update(sessions)
        .set({ revokedAt: at })
        .where(and(eq(sessions.deviceId, device.id), isNull(sessions.revokedAt)))
        .returning({ id: sessions.id, userId: sessions.userId });
      for (const old of replaced) deps.hub.close(old.userId, old.id);
      await tx
        .insert(devices)
        .values({ id: device.id, userId: user.id, kind: device.kind, name: device.name, createdAt: at, lastSeenAt: at })
        .onConflictDoUpdate({ target: devices.id, set: { userId: user.id, kind: device.kind, name: device.name, lastSeenAt: at } });
      return createSession(tx, user.id, device.id, at);
    });

    const result: LoginResult = { user: publicUser(user), expiresAt: session.expiresAt.toISOString() };
    if (device.kind === "pwa") setSessionCookie(c, session.token, session.expiresAt, deps.config.APP_URL);
    else result.token = session.token;
    return c.json(result);
  });

  /**
   * A signed-in Mac opens the web page (the big world) already signed in: it asks for a one-time link (a few minutes), and
   * opening it gives that browser a session of its own (`webDevice`: the Mac's id for its web window) and goes to `to`.
   */
  app.post("/handoff", auth, async (c) => {
    const me = c.get("session");
    if (me.viaCookie) return apiError(c, 403, "forbidden", "只有 App 可以這樣做。");
    const body = await readJson(c, handoffInput);
    if ("response" in body) return body.response;
    const token = newToken("gch");
    const at = now();
    await db.insert(emailTokens).values({ userId: me.user.id, purpose: "handoff", tokenHash: hashSecret(`${token}|${body.data.webDevice}`), createdAt: at, expiresAt: new Date(at.getTime() + HANDOFF_MINUTES * 60_000) });
    const url = new URL(`/api/auth/handoff/${token}`, deps.config.APP_URL);
    url.searchParams.set("device", body.data.webDevice);
    url.searchParams.set("to", body.data.to);
    return c.json({ url: url.toString() });
  });

  app.get("/handoff/:token", async (c) => {
    const token = c.req.param("token");
    const device = c.req.query("device") ?? "";
    const to = c.req.query("to") ?? "/";
    const target = new URL(to.startsWith("/") && !to.startsWith("//") ? to : "/", deps.config.APP_URL).toString();
    const at = now();
    const [row] = await db
      .update(emailTokens)
      .set({ usedAt: at })
      .where(and(eq(emailTokens.tokenHash, hashSecret(`${token}|${device}`)), eq(emailTokens.purpose, "handoff"), isNull(emailTokens.usedAt), gt(emailTokens.expiresAt, at)))
      .returning({ userId: emailTokens.userId });
    if (!row || !/^[0-9a-f-]{36}$/i.test(device)) return c.redirect(new URL("/login?expired=1", deps.config.APP_URL).toString());
    const session = await db.transaction(async (tx) => {
      await tx.update(sessions).set({ revokedAt: at }).where(and(eq(sessions.deviceId, device), isNull(sessions.revokedAt)));
      await tx
        .insert(devices)
        .values({ id: device, userId: row.userId, kind: "pwa", name: "Mac 的大世界視窗", createdAt: at, lastSeenAt: at })
        .onConflictDoUpdate({ target: devices.id, set: { userId: row.userId, lastSeenAt: at } });
      return createSession(tx, row.userId, device, at);
    });
    setSessionCookie(c, session.token, session.expiresAt, deps.config.APP_URL);
    return c.redirect(target);
  });

  app.post("/logout", auth, async (c) => {
    const me = c.get("session");
    await db.update(sessions).set({ revokedAt: now() }).where(eq(sessions.id, me.id));
    deps.hub.close(me.user.id, me.id);
    clearSessionCookie(c);
    return c.body(null, 204);
  });

  app.get("/me", auth, (c) => {
    const s = c.get("session");
    return c.json({ user: publicUser(s.user), sessionId: s.id, deviceId: s.deviceId });
  });

  // ── 登入中的裝置 ──────────────────────────────────────
  app.get("/sessions", auth, async (c) => {
    const me = c.get("session");
    const rows = await db
      .select({ session: sessions, device: devices })
      .from(sessions)
      .leftJoin(devices, eq(devices.id, sessions.deviceId))
      .where(and(eq(sessions.userId, me.user.id), isNull(sessions.revokedAt), gt(sessions.expiresAt, now())))
      .orderBy(desc(sessions.lastSeenAt));
    const list: SessionInfo[] = rows.map(({ session, device }) => ({
      id: session.id,
      device: device ? { id: device.id, kind: device.kind, name: device.name } : null,
      createdAt: session.createdAt.toISOString(),
      lastSeenAt: session.lastSeenAt.toISOString(),
      current: session.id === me.id,
    }));
    return c.json({ sessions: list });
  });

  /** Signs out every other device of this account (this one stays signed in). */
  app.delete("/sessions", auth, async (c) => {
    const me = c.get("session");
    const done = await db
      .update(sessions)
      .set({ revokedAt: now() })
      .where(and(eq(sessions.userId, me.user.id), ne(sessions.id, me.id), isNull(sessions.revokedAt)))
      .returning({ id: sessions.id });
    for (const d of done) deps.hub.close(me.user.id, d.id);
    return c.json({ signedOut: done.length });
  });

  app.delete("/sessions/:id", auth, async (c) => {
    const me = c.get("session");
    const id = c.req.param("id");
    if (!/^[0-9a-f-]{36}$/i.test(id)) return apiError(c, 404, "not_found", "找不到這個登入。");
    const done = await db
      .update(sessions)
      .set({ revokedAt: now() })
      .where(and(eq(sessions.id, id), eq(sessions.userId, me.user.id), isNull(sessions.revokedAt)))
      .returning({ id: sessions.id });
    if (done.length === 0) return apiError(c, 404, "not_found", "找不到這個登入。");
    deps.hub.close(me.user.id, id);
    if (id === me.id) clearSessionCookie(c);
    return c.body(null, 204);
  });

  // ── 忘記密碼 ──────────────────────────────────────────
  app.post("/forgot-password", async (c) => {
    const body = await readJson(c, emailOnlyInput);
    if ("response" in body) return body.response;
    const stop = limited(c, [
      [`forgot:${clientIp(c, deps.config.TRUST_PROXY)}`, 10, 3600],
      [`forgot:${body.data.email.toLowerCase()}`, 3, 3600],
    ]);
    if (stop) return stop;
    const [user] = await db.select().from(users).where(and(eq(users.email, body.data.email), isNull(users.deletingAt)));
    if (user) mail(resetMail(user.email, link("/reset-password", await newEmailToken(user.id, "reset", now()))));
    return c.json(SENT, 202);
  });

  app.post("/reset-password", async (c) => {
    const stop = limited(c, [[`reset:${clientIp(c, deps.config.TRUST_PROXY)}`, 10, 600]]);
    if (stop) return stop;
    const body = await readJson(c, resetPasswordInput);
    if ("response" in body) return body.response;
    const at = now();
    const passwordHash = await hashPassword(body.data.password);
    const reset = await db.transaction(async (tx) => {
      const [row] = await tx
        .select()
        .from(emailTokens)
        .where(and(eq(emailTokens.tokenHash, hashSecret(body.data.token)), eq(emailTokens.purpose, "reset"), isNull(emailTokens.usedAt), gt(emailTokens.expiresAt, at)))
        .for("update");
      if (!row) return null;
      await tx.update(emailTokens).set({ usedAt: at }).where(eq(emailTokens.id, row.id));
      // the link came to the mailbox, so the address is proven too
      const [user] = await tx.select({ verified: users.emailVerifiedAt }).from(users).where(eq(users.id, row.userId));
      await tx.update(users).set({ passwordHash, emailVerifiedAt: user?.verified ?? at }).where(eq(users.id, row.userId));
      // every device signs in again with the new password
      await tx.update(sessions).set({ revokedAt: at }).where(and(eq(sessions.userId, row.userId), isNull(sessions.revokedAt)));
      return row.userId;
    });
    if (!reset) return apiError(c, 400, "token_invalid", "這個連結已經失效了，請重新申請一次。");
    deps.hub.close(reset);
    return c.json({ ok: true, message: "新密碼設定好了，請重新登入。" });
  });

  return app;
}
