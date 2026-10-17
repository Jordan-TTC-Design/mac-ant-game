import { and, count, desc, eq, gt, isNotNull, isNull, lte, or } from "drizzle-orm";
import { Hono } from "hono";
import {
  ANNOUNCE_PUSH_EVERY_MS,
  announceInput,
  type AdminAnnouncement,
  type AdminAnnouncementList,
  type Announcement,
  type AnnouncementsResponse,
  type AnnounceAudience,
  type AnnounceAudienceCount,
  type SocialPush,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { announcements, devices, users } from "../db/schema.ts";
import { apiError, readJson } from "../http.ts";
import { pushToPhones } from "../push/phones.ts";
import type { AdminLog } from "./users.ts";

/** Accounts an announcement is for: everyone who can sign in, or only the admins. */
function audienceOf(audience: AnnounceAudience) {
  const live = and(isNull(users.deletingAt), isNull(users.disabledAt));
  return audience === "admins" ? and(live, eq(users.role, "admin")) : live;
}

/** 後台's 公告: put one up (and maybe push it), list them, take one down, and count who would get one. */
export function adminAnnouncementRoutes(app: Hono<AppEnv>, deps: AppDeps, log: AdminLog) {
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  let lastPush = 0;

  app.get("/announcements/audience", async (c) => {
    const audience: AnnounceAudience = c.req.query("audience") === "admins" ? "admins" : "all";
    const [[people], [phones]] = await Promise.all([
      db.select({ n: count() }).from(users).where(audienceOf(audience)),
      db
        .select({ n: count() })
        .from(devices)
        .innerJoin(users, eq(users.id, devices.userId))
        .where(and(audienceOf(audience), eq(devices.kind, "pwa"), isNotNull(devices.pushSubscription))),
    ]);
    const body: AnnounceAudienceCount = { users: people?.n ?? 0, phones: phones?.n ?? 0 };
    return c.json(body);
  });

  app.get("/announcements", async (c) => {
    const at = now();
    const rows = await db
      .select({ a: announcements, by: users.displayName })
      .from(announcements)
      .leftJoin(users, eq(users.id, announcements.createdBy))
      .orderBy(desc(announcements.at))
      .limit(100);
    const body: AdminAnnouncementList = {
      announcements: rows.map(({ a, by }): AdminAnnouncement => ({
        id: a.id,
        title: a.title,
        body: a.body,
        url: a.url,
        at: a.at.toISOString(),
        audience: a.audience,
        endsAt: a.endsAt?.toISOString() ?? null,
        over: !!a.endsAt && a.endsAt <= at,
        by,
        pushed: a.pushed,
      })),
    };
    return c.json(body);
  });

  /** Puts one up: it shows at once; with `push`, every phone of the audience that takes pushes gets it too (in the background). */
  app.post("/announcements", async (c) => {
    const me = c.get("session").user;
    const body = await readJson(c, announceInput);
    if ("response" in body) return body.response;
    const at = now();
    const input = body.data;
    if (input.endsAt && new Date(input.endsAt) <= at) return apiError(c, 400, "invalid_input", "結束時間要在現在之後。");
    if (input.push && at.getTime() - lastPush < ANNOUNCE_PUSH_EVERY_MS) return apiError(c, 429, "rate_limited", "剛剛才推播過，請等一分鐘再推。");
    if (input.push) lastPush = at.getTime();
    const [row] = await db
      .insert(announcements)
      .values({ title: input.title, body: input.body, url: input.url, audience: input.audience, at, endsAt: input.endsAt ? new Date(input.endsAt) : null, createdBy: me.id, pushed: input.push ? 0 : null })
      .returning();
    await log(me.id, null, "announce", { title: input.title, audience: input.audience, push: input.push });
    deps.hub.notifyAll({ type: "announcements.changed" });
    if (input.push) void pushAll(row!.id, input.audience, { type: "social", title: input.title, body: input.body.slice(0, 120), url: input.url ?? "/", tag: `announce-${row!.id}` });
    return c.json({ id: row!.id }, 201);
  });

  async function pushAll(id: string, audience: AnnounceAudience, payload: SocialPush) {
    try {
      const people = await db.selectDistinct({ id: users.id }).from(users).innerJoin(devices, eq(devices.userId, users.id)).where(and(audienceOf(audience), eq(devices.kind, "pwa"), isNotNull(devices.pushSubscription)));
      let sent = 0;
      for (const p of people) sent += await pushToPhones(deps, p.id, payload);
      await db.update(announcements).set({ pushed: sent }).where(eq(announcements.id, id));
    } catch (err) {
      console.error("announcement push:", err);
    }
  }

  /** Takes one down now (it stays in the list, marked as over). */
  app.delete("/announcements/:id", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!/^[0-9a-f-]{36}$/i.test(id)) return apiError(c, 404, "not_found", "沒有這則公告。");
    const at = now();
    const [row] = await db
      .update(announcements)
      .set({ endsAt: at })
      .where(and(eq(announcements.id, id), or(isNull(announcements.endsAt), gt(announcements.endsAt, at))))
      .returning({ title: announcements.title });
    if (!row) return apiError(c, 404, "not_found", "沒有這則公告，或已經下架了。");
    await log(me.id, null, "announce-end", { title: row.title });
    deps.hub.notifyAll({ type: "announcements.changed" });
    return c.json({ ok: true });
  });
}

/** `GET /api/announcements`: what is up for this account now, newest first (the page remembers which were closed). */
export function announcementRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));
  app.get("/", async (c) => {
    const me = c.get("session").user;
    const at = now();
    const rows = await db
      .select()
      .from(announcements)
      .where(
        and(
          lte(announcements.at, at),
          or(isNull(announcements.endsAt), gt(announcements.endsAt, at)),
          me.role === "admin" ? undefined : eq(announcements.audience, "all"),
        ),
      )
      .orderBy(desc(announcements.at))
      .limit(5);
    const body: AnnouncementsResponse = {
      announcements: rows.map((a): Announcement => ({ id: a.id, title: a.title, body: a.body, url: a.url, at: a.at.toISOString() })),
    };
    return c.json(body);
  });
  return app;
}
