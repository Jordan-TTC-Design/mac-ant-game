import type { Context, MiddlewareHandler } from "hono";
import { deleteCookie, getCookie, setCookie } from "hono/cookie";
import { and, eq, gt, isNull } from "drizzle-orm";
import type { AppDeps, AppEnv } from "../app.ts";
import { devices, sessions, users } from "../db/schema.ts";
import { apiError } from "../http.ts";
import { hashSecret, newToken } from "../lib/tokens.ts";

export const SESSION_DAYS = 90;
export const SESSION_COOKIE = "gc_session";
const DAY = 86_400_000;

export interface CurrentSession {
  id: string;
  deviceId: string | null;
  user: { id: string; email: string; displayName: string; friendCode: string };
  /** Signed in with the cookie (a phone) rather than a Bearer token (a Mac). */
  viaCookie: boolean;
}

export type Tx = Parameters<Parameters<AppDeps["database"]["db"]["transaction"]>[0]>[0];
/** The database, or a transaction on it. */
export type Db = AppDeps["database"]["db"] | Tx;

/** A new session: the token goes to the device once; only its hash is kept. */
export async function createSession(db: Db, userId: string, deviceId: string, now: Date) {
  const token = newToken("gcs");
  const expiresAt = new Date(now.getTime() + SESSION_DAYS * DAY);
  await db.insert(sessions).values({ userId, deviceId, tokenHash: hashSecret(token), createdAt: now, lastSeenAt: now, expiresAt });
  return { token, expiresAt };
}

export function setSessionCookie(c: Context, token: string, expiresAt: Date, appUrl: string) {
  setCookie(c, SESSION_COOKIE, token, {
    httpOnly: true,
    secure: appUrl.startsWith("https://") || appUrl.startsWith("http://localhost"),
    sameSite: "Lax",
    path: "/api",
    expires: expiresAt,
  });
}

export function clearSessionCookie(c: Context) {
  deleteCookie(c, SESSION_COOKIE, { path: "/api" });
}

/**
 * Lets the request through only with a live session (Bearer token or cookie), and puts it in `c.get("session")`.
 * A session in use is kept alive for another 90 days (written at most once an hour).
 */
export function requireAuth(deps: AppDeps): MiddlewareHandler<AppEnv> {
  const now = deps.now ?? (() => new Date());
  const appOrigin = new URL(deps.config.APP_URL).origin;
  return async (c, next) => {
    const bearer = c.req.header("authorization")?.match(/^Bearer\s+(\S+)$/i)?.[1];
    const cookie = bearer ? undefined : getCookie(c, SESSION_COOKIE);
    const token = bearer ?? cookie;
    if (!token) return apiError(c, 401, "unauthorized", "請先登入。");
    // a cookie is sent by the browser on its own, so a change made with it must come from our own page
    if (cookie && !["GET", "HEAD"].includes(c.req.method)) {
      const origin = c.req.header("origin");
      if (origin && origin !== appOrigin) return apiError(c, 403, "forbidden", "這個請求不是從哥布林營地的網頁送出的。");
    }
    const at = now();
    const { db } = deps.database;
    const [row] = await db
      .select({ session: sessions, user: users })
      .from(sessions)
      .innerJoin(users, eq(users.id, sessions.userId))
      .where(and(eq(sessions.tokenHash, hashSecret(token)), isNull(sessions.revokedAt), gt(sessions.expiresAt, at), isNull(users.deletingAt)))
      .limit(1);
    if (!row) {
      if (cookie) clearSessionCookie(c);
      return apiError(c, 401, "unauthorized", "登入已經過期，請重新登入。");
    }
    if (at.getTime() - row.session.lastSeenAt.getTime() > 3_600_000) {
      await db.update(sessions).set({ lastSeenAt: at, expiresAt: new Date(at.getTime() + SESSION_DAYS * DAY) }).where(eq(sessions.id, row.session.id));
      if (row.session.deviceId) await db.update(devices).set({ lastSeenAt: at }).where(eq(devices.id, row.session.deviceId));
    }
    const { id, email, displayName, friendCode } = row.user;
    c.set("session", { id: row.session.id, deviceId: row.session.deviceId, user: { id, email, displayName, friendCode }, viaCookie: !!cookie });
    await next();
  };
}
