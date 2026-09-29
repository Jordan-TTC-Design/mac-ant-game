import { and, asc, count, desc, eq, inArray, ne, sql, type SQL } from "drizzle-orm";
import { Hono } from "hono";
import {
  FEEDBACK_KIND_LABEL,
  FEEDBACK_KINDS,
  FEEDBACK_STATUS_LABEL,
  FEEDBACK_STATUSES,
  feedbackInputSchema,
  feedbackReplyInputSchema,
  feedbackStatusInputSchema,
  type FeedbackDetail,
  type FeedbackKind,
  type FeedbackList,
  type FeedbackStatus,
  type FeedbackSummary,
  type SocialPush,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { feedback, feedbackReplies, feedbackVotes, users } from "../db/schema.ts";
import { apiError, readJson } from "../http.ts";
import { RateLimiter } from "../lib/rate-limit.ts";
import { pushToPhones } from "../push/phones.ts";

const GONE = "已刪除的帳號";

/**
 * 回報 (shared/src/feedback.ts): everyone signed in sends reports and sees them all; admins (as in 後台, including the
 * addresses in ADMIN_EMAILS) set their status and answer. Whoever did not make a change hears about it on their phones:
 * the author when an admin answers or moves it along, the admins when a report comes in or its author writes more.
 */
export function feedbackRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  const limiter = deps.limiter ?? new RateLimiter();
  const bootstrap = new Set((deps.config.ADMIN_EMAILS ?? "").split(",").map((e) => e.trim().toLowerCase()).filter(Boolean));
  app.use("*", requireAuth(deps));

  async function isAdmin(me: { id: string; email: string }) {
    if (bootstrap.has(me.email.toLowerCase())) return true;
    const [row] = await db.select({ role: users.role }).from(users).where(eq(users.id, me.id));
    return row?.role === "admin";
  }
  async function admins() {
    const rows = await db.select({ id: users.id, email: users.email, role: users.role }).from(users);
    return rows.filter((u) => u.role === "admin" || bootstrap.has(u.email.toLowerCase())).map((u) => u.id);
  }
  const tell = (userIds: (string | null)[], exceptId: string, push: SocialPush) =>
    Promise.all(userIds.filter((id): id is string => !!id && id !== exceptId).map((id) => pushToPhones(deps, id, push)));

  const votes = sql<number>`(select count(*)::int from ${feedbackVotes} where ${feedbackVotes.feedbackId} = ${feedback.id})`;
  const summaryColumns = (meId: string) => ({
    id: feedback.id,
    userId: feedback.userId,
    kind: feedback.kind,
    title: feedback.title,
    status: feedback.status,
    author: users.displayName,
    createdAt: feedback.createdAt,
    updatedAt: feedback.updatedAt,
    votes,
    voted: sql<boolean>`exists (select 1 from ${feedbackVotes} where ${feedbackVotes.feedbackId} = ${feedback.id} and ${feedbackVotes.userId} = ${meId})`,
  });
  type SummaryRow = {
    id: string;
    userId: string | null;
    kind: FeedbackKind;
    title: string;
    status: FeedbackStatus;
    author: string | null;
    createdAt: Date;
    updatedAt: Date;
    votes: number;
    voted: boolean;
  };
  const summary = (r: SummaryRow, meId: string, replies: number): FeedbackSummary => ({
    id: r.id,
    kind: r.kind,
    title: r.title,
    status: r.status,
    author: r.author ?? GONE,
    mine: r.userId === meId,
    replies,
    votes: r.votes,
    voted: r.voted,
    createdAt: r.createdAt.toISOString(),
    updatedAt: r.updatedAt.toISOString(),
  });

  /**
   * Everything, newest activity first (`?sort=votes`: the most +1s first); `?status=`, `?kind=` and `?mine=1` narrow it
   * down (the counts ignore `status`).
   */
  app.get("/", async (c) => {
    const me = c.get("session").user;
    const kind = c.req.query("kind");
    const status = c.req.query("status");
    const where: SQL[] = [];
    if (kind && (FEEDBACK_KINDS as readonly string[]).includes(kind)) where.push(eq(feedback.kind, kind as FeedbackKind));
    if (c.req.query("mine") === "1") where.push(eq(feedback.userId, me.id));
    const tally = await db.select({ status: feedback.status, n: count() }).from(feedback).where(and(...where)).groupBy(feedback.status);
    if (status && (FEEDBACK_STATUSES as readonly string[]).includes(status)) where.push(eq(feedback.status, status as FeedbackStatus));
    const rows = await db
      .select(summaryColumns(me.id))
      .from(feedback)
      .leftJoin(users, eq(users.id, feedback.userId))
      .where(and(...where))
      .orderBy(...(c.req.query("sort") === "votes" ? [desc(votes), desc(feedback.updatedAt)] : [desc(feedback.updatedAt)]))
      .limit(300);
    const replies = rows.length
      ? new Map(
          (
            await db
              .select({ id: feedbackReplies.feedbackId, n: count() })
              .from(feedbackReplies)
              .where(and(inArray(feedbackReplies.feedbackId, rows.map((r) => r.id)), ne(feedbackReplies.body, "")))
              .groupBy(feedbackReplies.feedbackId)
          ).map((r) => [r.id, r.n]),
        )
      : new Map<string, number>();
    const counts = Object.fromEntries(FEEDBACK_STATUSES.map((s) => [s, 0])) as Record<FeedbackStatus, number>;
    for (const t of tally) counts[t.status] = t.n;
    const body: FeedbackList = { items: rows.map((r) => summary(r, me.id, replies.get(r.id) ?? 0)), counts, admin: await isAdmin(me) };
    return c.json(body);
  });

  app.post("/", async (c) => {
    const me = c.get("session").user;
    const wait = Math.max(limiter.hit(`feedback:${me.id}`, 10, 3600), limiter.hit(`feedback-day:${me.id}`, 30, 86_400));
    if (wait) return apiError(c, 429, "rate_limited", "回報得太頻繁了，請晚點再送。", { retryAfter: wait });
    const input = await readJson(c, feedbackInputSchema);
    if ("response" in input) return input.response;
    const at = now();
    const [row] = await db
      .insert(feedback)
      .values({ userId: me.id, kind: input.data.kind, title: input.data.title, body: input.data.body, device: input.data.device ?? null, createdAt: at, updatedAt: at })
      .returning({ id: feedback.id });
    await tell(await admins(), me.id, {
      type: "social",
      title: `新的回報：${FEEDBACK_KIND_LABEL[input.data.kind]}`,
      body: `${me.displayName}：${input.data.title}`,
      url: `/feedback/${row!.id}`,
      tag: `feedback-${row!.id}`,
    });
    return c.json({ id: row!.id }, 201);
  });

  async function find(id: string, meId: string) {
    if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
    const [row] = await db
      .select({ ...summaryColumns(meId), body: feedback.body, device: feedback.device })
      .from(feedback)
      .leftJoin(users, eq(users.id, feedback.userId))
      .where(eq(feedback.id, id));
    return row ?? null;
  }

  async function detail(id: string, me: { id: string; email: string }): Promise<FeedbackDetail | null> {
    const row = await find(id, me.id);
    if (!row) return null;
    const thread = await db
      .select({ id: feedbackReplies.id, author: users.displayName, admin: feedbackReplies.admin, body: feedbackReplies.body, status: feedbackReplies.status, at: feedbackReplies.at })
      .from(feedbackReplies)
      .leftJoin(users, eq(users.id, feedbackReplies.userId))
      .where(eq(feedbackReplies.feedbackId, id))
      .orderBy(asc(feedbackReplies.at));
    const mine = row.userId === me.id;
    const admin = await isAdmin(me);
    return {
      ...summary(row, me.id, thread.filter((t) => t.body).length),
      body: row.body,
      device: mine || admin ? row.device : null,
      thread: thread.map((t) => ({ ...t, author: t.author ?? GONE, at: t.at.toISOString() })),
      admin,
    };
  }

  app.get("/:id", async (c) => {
    const d = await detail(c.req.param("id"), c.get("session").user);
    return d ? c.json(d) : apiError(c, 404, "not_found", "找不到這則回報。");
  });

  /** The author or an admin writes under it. */
  app.post("/:id/replies", async (c) => {
    const me = c.get("session").user;
    const row = await find(c.req.param("id"), me.id);
    if (!row) return apiError(c, 404, "not_found", "找不到這則回報。");
    const admin = await isAdmin(me);
    if (row.userId !== me.id && !admin) return apiError(c, 403, "forbidden", "只有回報的人和管理員能回覆。");
    if (limiter.hit(`feedback-reply:${me.id}`, 30, 3600)) return apiError(c, 429, "rate_limited", "回覆得太頻繁了，請晚點再試。");
    const input = await readJson(c, feedbackReplyInputSchema);
    if ("response" in input) return input.response;
    const at = now();
    await db.insert(feedbackReplies).values({ feedbackId: row.id, userId: me.id, admin, body: input.data.body, at });
    await db.update(feedback).set({ updatedAt: at }).where(eq(feedback.id, row.id));
    const push: SocialPush = { type: "social", title: `回報「${row.title}」有新回覆`, body: `${me.displayName}：${input.data.body.slice(0, 80)}`, url: `/feedback/${row.id}`, tag: `feedback-${row.id}` };
    await tell(admin ? [row.userId] : await admins(), me.id, push);
    return c.json(await detail(row.id, me), 201);
  });

  /** An admin moves it along (and may say why in the same step). */
  app.post("/:id/status", async (c) => {
    const me = c.get("session").user;
    if (!(await isAdmin(me))) return apiError(c, 403, "forbidden", "只有管理員能改狀態。");
    const row = await find(c.req.param("id"), me.id);
    if (!row) return apiError(c, 404, "not_found", "找不到這則回報。");
    const input = await readJson(c, feedbackStatusInputSchema);
    if ("response" in input) return input.response;
    const { status, note = "" } = input.data;
    if (status === row.status && !note) return c.json(await detail(row.id, me));
    const at = now();
    await db.insert(feedbackReplies).values({ feedbackId: row.id, userId: me.id, admin: true, body: note, status: status === row.status ? null : status, at });
    await db.update(feedback).set({ status, updatedAt: at }).where(eq(feedback.id, row.id));
    await tell([row.userId], me.id, {
      type: "social",
      title: `你的回報：${FEEDBACK_STATUS_LABEL[status]}`,
      body: note ? `「${row.title}」— ${note.slice(0, 80)}` : `「${row.title}」`,
      url: `/feedback/${row.id}`,
      tag: `feedback-${row.id}`,
    });
    return c.json(await detail(row.id, me));
  });

  /** 我也遇到 / 我也想要 (taking it back: DELETE). Not on one's own. */
  app.put("/:id/vote", async (c) => {
    const me = c.get("session").user;
    const row = await find(c.req.param("id"), me.id);
    if (!row) return apiError(c, 404, "not_found", "找不到這則回報。");
    if (row.userId === me.id) return apiError(c, 409, "conflict", "不能幫自己的回報 +1。");
    await db.insert(feedbackVotes).values({ feedbackId: row.id, userId: me.id, at: now() }).onConflictDoNothing();
    return c.json(await detail(row.id, me));
  });

  app.delete("/:id/vote", async (c) => {
    const me = c.get("session").user;
    const row = await find(c.req.param("id"), me.id);
    if (!row) return apiError(c, 404, "not_found", "找不到這則回報。");
    await db.delete(feedbackVotes).where(and(eq(feedbackVotes.feedbackId, row.id), eq(feedbackVotes.userId, me.id)));
    return c.json(await detail(row.id, me));
  });

  /** The author takes it back while nobody has looked at it yet; an admin removes it any time (spam, duplicates). */
  app.delete("/:id", async (c) => {
    const me = c.get("session").user;
    const row = await find(c.req.param("id"), me.id);
    if (!row) return apiError(c, 404, "not_found", "找不到這則回報。");
    const admin = await isAdmin(me);
    if (!admin && !(row.userId === me.id && row.status === "open")) return apiError(c, 403, "forbidden", "已經在處理的回報不能刪除。");
    await db.delete(feedback).where(eq(feedback.id, row.id));
    return c.body(null, 204);
  });

  return app;
}
