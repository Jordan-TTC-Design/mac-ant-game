import { Hono } from "hono";
import { and, desc, eq, gte, inArray, isNull, lt, or, sql } from "drizzle-orm";
import {
  friendAskInput,
  messageInput,
  MESSAGES_PER_DAY,
  PENDING_ASKS_MAX,
  type ChatResponse,
  type FriendsResponse,
  type Person,
  type SocialPush,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { apiError, readJson } from "../http.ts";
import { pushToPhones } from "../push/phones.ts";
import { blocks, camps, friendships, messages, users } from "../db/schema.ts";

const DAY = 86_400_000;
/** The pair's row key: the smaller id first. */
const pair = (a: string, b: string) => (a < b ? { userA: a, userB: b } : { userA: b, userB: a });
const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);

/** 好友與訊息 (server/DESIGN.md §7). */
export function friendRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  async function people(ids: string[]): Promise<Map<string, Person>> {
    if (ids.length === 0) return new Map();
    const rows = await db
      .select({ id: users.id, name: users.displayName, race: camps.race })
      .from(users)
      .leftJoin(camps, eq(camps.userId, users.id))
      .where(and(inArray(users.id, ids), isNull(users.deletingAt), isNull(users.disabledAt)));
    return new Map(rows.map((r) => [r.id, { id: r.id, name: r.name, race: r.race ?? "goblin" }]));
  }

  async function rowWith(me: string, other: string) {
    const [row] = await db.select().from(friendships).where(and(eq(friendships.userA, pair(me, other).userA), eq(friendships.userB, pair(me, other).userB)));
    return row ?? null;
  }
  async function blocked(by: string, whom: string) {
    const [row] = await db.select().from(blocks).where(and(eq(blocks.userId, by), eq(blocks.blockedId, whom)));
    return !!row;
  }
  const tell = (userId: string, from?: string) => deps.hub.notify(userId, { type: "friends.changed", ...(from ? { from } : {}) });

  app.get("/", async (c) => {
    const me = c.get("session").user;
    const rows = await db.select().from(friendships).where(or(eq(friendships.userA, me.id), eq(friendships.userB, me.id)));
    const otherOf = (r: (typeof rows)[number]) => (r.userA === me.id ? r.userB : r.userA);
    const who = await people(rows.map(otherOf));
    const accepted = rows.filter((r) => r.acceptedAt);
    // unread counts and the last message of each friend, in two queries
    const unread = new Map(
      (
        await db
          .select({ from: messages.fromUser, n: sql<number>`count(*)::int` })
          .from(messages)
          .where(and(eq(messages.toUser, me.id), isNull(messages.readAt)))
          .groupBy(messages.fromUser)
      ).map((u) => [u.from, u.n]),
    );
    const lastRows = accepted.length
      ? ((await db.execute(sql`
          select distinct on (other) other, text, at, mine from (
            select case when from_user = ${me.id} then to_user else from_user end as other, text, at, from_user = ${me.id} as mine
            from messages where from_user = ${me.id} or to_user = ${me.id}
          ) m order by other, at desc`)) as unknown as { other: string; text: string; at: Date | string; mine: boolean }[])
      : [];
    const last = new Map(lastRows.map((l) => [l.other, { text: l.text, at: new Date(l.at).toISOString(), mine: l.mine }]));
    const body: FriendsResponse = {
      code: me.friendCode,
      friends: accepted
        .flatMap((r) => {
          const p = who.get(otherOf(r));
          return p ? [{ ...p, since: r.acceptedAt!.toISOString(), unread: unread.get(p.id) ?? 0, last: last.get(p.id) ?? null }] : [];
        })
        .sort((a, b) => (b.last?.at ?? b.since).localeCompare(a.last?.at ?? a.since)),
      incoming: rows.filter((r) => !r.acceptedAt && r.askedBy !== me.id).flatMap((r) => (who.get(otherOf(r)) ? [{ ...who.get(otherOf(r))!, at: r.createdAt.toISOString() }] : [])),
      outgoing: rows.filter((r) => !r.acceptedAt && r.askedBy === me.id).flatMap((r) => (who.get(otherOf(r)) ? [{ ...who.get(otherOf(r))!, at: r.createdAt.toISOString() }] : [])),
    };
    return c.json(body);
  });

  /** Asks to be friends (by friend code, or by who they are); if they had asked this account already, that is a yes. */
  app.post("/asks", async (c) => {
    const body = await readJson(c, friendAskInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const [other] = body.data.code
      ? await db.select({ id: users.id, name: users.displayName }).from(users).where(and(sql`upper(${users.friendCode}) = ${body.data.code.toUpperCase()}`, isNull(users.deletingAt), isNull(users.disabledAt)))
      : await db.select({ id: users.id, name: users.displayName }).from(users).where(and(eq(users.id, body.data.userId!), isNull(users.deletingAt), isNull(users.disabledAt)));
    if (!other) return apiError(c, 404, "not_found", "找不到這個好友代碼。");
    if (other.id === me.id) return apiError(c, 400, "invalid_input", "這是你自己的代碼。");
    const row = await rowWith(me.id, other.id);
    if (row?.acceptedAt) return c.json({ status: "friends" });
    const at = now();
    if (row && row.askedBy !== me.id) {
      await db.update(friendships).set({ acceptedAt: at }).where(and(eq(friendships.userA, row.userA), eq(friendships.userB, row.userB)));
      tell(other.id);
      tell(me.id);
      return c.json({ status: "friends" });
    }
    if (row) return c.json({ status: "asked" });
    const [{ n }] = (await db.select({ n: sql<number>`count(*)::int` }).from(friendships).where(and(eq(friendships.askedBy, me.id), isNull(friendships.acceptedAt)))) as [{ n: number }];
    if (n >= PENDING_ASKS_MAX) return apiError(c, 409, "conflict", `同時最多等 ${PENDING_ASKS_MAX} 個人回覆。`);
    // (someone who blocked this account never sees the ask; it looks sent)
    if (!(await blocked(other.id, me.id))) {
      await db.insert(friendships).values({ ...pair(me.id, other.id), askedBy: me.id, createdAt: at }).onConflictDoNothing();
      tell(other.id);
      const push: SocialPush = { type: "social", title: "有人想加你好友", body: `${me.displayName} 想加你好友`, url: "/friends", tag: `ask-${me.id}` };
      await pushToPhones(deps, other.id, push);
    }
    return c.json({ status: "asked" }, 201);
  });

  /** Yes to an ask. */
  app.post("/:id/accept", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!isUuid(id)) return apiError(c, 404, "not_found", "沒有這個邀請。");
    const row = await rowWith(me.id, id);
    if (!row || row.acceptedAt || row.askedBy === me.id) return apiError(c, 404, "not_found", "沒有這個邀請。");
    await db.update(friendships).set({ acceptedAt: now() }).where(and(eq(friendships.userA, row.userA), eq(friendships.userB, row.userB)));
    tell(id);
    tell(me.id);
    await pushToPhones(deps, id, { type: "social", title: "成為好友了", body: `${me.displayName} 答應了，可以傳訊息了`, url: `/friends/${me.id}`, tag: `ask-${me.id}` } satisfies SocialPush);
    return c.json({ status: "friends" });
  });

  /** No to an ask, taking an ask back, or no longer friends. */
  app.delete("/:id", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!isUuid(id)) return apiError(c, 404, "not_found", "沒有這個人。");
    const p = pair(me.id, id);
    await db.delete(friendships).where(and(eq(friendships.userA, p.userA), eq(friendships.userB, p.userB)));
    tell(id);
    tell(me.id);
    return c.body(null, 204);
  });

  /** Blocks someone: no longer friends, and their asks and messages are dropped from now on. */
  app.post("/:id/block", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!isUuid(id) || id === me.id) return apiError(c, 404, "not_found", "沒有這個人。");
    const p = pair(me.id, id);
    await db.delete(friendships).where(and(eq(friendships.userA, p.userA), eq(friendships.userB, p.userB)));
    await db.insert(blocks).values({ userId: me.id, blockedId: id, at: now() }).onConflictDoNothing();
    tell(me.id);
    return c.body(null, 204);
  });

  /** The conversation with a friend, newest last (50 at a time; `before` = an ISO time for older ones). Marks theirs read. */
  app.get("/:id/messages", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!isUuid(id)) return apiError(c, 404, "not_found", "沒有這個好友。");
    const row = await rowWith(me.id, id);
    const friend = (await people([id])).get(id);
    if (!row?.acceptedAt || !friend) return apiError(c, 404, "not_found", "沒有這個好友。");
    const before = c.req.query("before");
    const between = or(and(eq(messages.fromUser, me.id), eq(messages.toUser, id)), and(eq(messages.fromUser, id), eq(messages.toUser, me.id)));
    const rows = await db
      .select()
      .from(messages)
      .where(before && !Number.isNaN(Date.parse(before)) ? and(between, lt(messages.at, new Date(before))) : between)
      .orderBy(desc(messages.at))
      .limit(51);
    const unread = rows.some((m) => m.toUser === me.id && !m.readAt);
    if (unread) {
      await db.update(messages).set({ readAt: now() }).where(and(eq(messages.fromUser, id), eq(messages.toUser, me.id), isNull(messages.readAt)));
      tell(id); // (their 已讀)
      tell(me.id);
    }
    const body: ChatResponse = {
      friend,
      messages: rows
        .slice(0, 50)
        .reverse()
        .map((m) => ({ id: m.id, mine: m.fromUser === me.id, text: m.text, at: m.at.toISOString(), read: m.toUser === me.id || !!m.readAt })),
      more: rows.length > 50,
    };
    return c.json(body);
  });

  app.post("/:id/messages", async (c) => {
    const body = await readJson(c, messageInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const id = c.req.param("id");
    if (!isUuid(id)) return apiError(c, 404, "not_found", "沒有這個好友。");
    const row = await rowWith(me.id, id);
    if (!row?.acceptedAt) return apiError(c, 403, "forbidden", "要先成為好友才能傳訊息。");
    const at = now();
    const [{ n }] = (await db
      .select({ n: sql<number>`count(*)::int` })
      .from(messages)
      .where(and(eq(messages.fromUser, me.id), gte(messages.at, new Date(at.getTime() - DAY))))) as [{ n: number }];
    if (n >= MESSAGES_PER_DAY) return apiError(c, 429, "rate_limited", `一天最多傳 ${MESSAGES_PER_DAY} 則。`);
    const [msg] = await db.insert(messages).values({ fromUser: me.id, toUser: id, text: body.data.text, at }).returning();
    tell(me.id);
    if (!(await blocked(id, me.id))) {
      tell(id, me.id);
      await pushToPhones(deps, id, { type: "social", title: me.displayName, body: body.data.text.slice(0, 120), url: `/friends/${me.id}`, tag: `chat-${me.id}` } satisfies SocialPush);
    }
    return c.json({ id: msg!.id, mine: true, text: msg!.text, at: msg!.at.toISOString(), read: false }, 201);
  });

  return app;
}
