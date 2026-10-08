import { Hono } from "hono";
import { and, asc, desc, eq, gt, inArray, isNull, lt, sql } from "drizzle-orm";
import {
  avatarProblem,
  avatarSchema,
  DEFAULT_BADGE,
  defaultAvatar,
  GUILD_INVITE_DAYS,
  GUILD_PENDING_INVITES_MAX,
  GUILD_DECOR_LOG_DAYS,
  GUILD_REJOIN_HOURS,
  guildDecorChange,
  guildDecorInput,
  guildDecorProblem,
  guildDecorRestoreInput,
  guildCreateInput,
  guildInviteInput,
  guildLevel,
  guildRoleInput,
  guildUpdateInput,
  presenceInput,
  presenceNow,
  type Avatar,
  type GuildDecorLogEntry,
  type GuildResponse,
  type GuildRole,
  type SocialPush,
} from "@goblincamp/shared";
import { focusToday } from "@goblincamp/shared/camp";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import type { Database } from "../db/client.ts";
import { apiError, readJson } from "../http.ts";
import { pushToPhones } from "../push/phones.ts";
import { avatars, camps, guildDecorLog, guildInvites, guildMembers, guilds, users } from "../db/schema.ts";

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
const isUuid = (s: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
const RANK: Record<GuildRole, number> = { leader: 0, officer: 1, member: 2 };

type Db = Database["db"];
type Tx = Parameters<Parameters<Db["transaction"]>[0]>[0];

/** The account's avatar for its camp's race: the saved one if it is of that race, else the race's default. */
function avatarFor(saved: Avatar | null | undefined, race: string): { avatar: Avatar; chosen: boolean } {
  if (saved && saved.race === race && !avatarProblem(saved)) return { avatar: saved, chosen: true };
  return { avatar: defaultAvatar(race, saved?.sex ?? "m"), chosen: false };
}

/**
 * The guild left without a leader (theirs left, or their account went): the officer who joined first leads, else the member
 * who joined first. No one left: the guild is broken up.
 */
async function settleLeader(tx: Tx | Db, guildId: string) {
  const rest = await tx.select().from(guildMembers).where(eq(guildMembers.guildId, guildId)).orderBy(asc(guildMembers.joinedAt));
  if (rest.length === 0) {
    await tx.delete(guilds).where(eq(guilds.id, guildId));
    return;
  }
  if (rest.some((m) => m.role === "leader")) return;
  const next = [...rest].sort((a, b) => RANK[a.role] - RANK[b.role] || a.joinedAt.getTime() - b.joinedAt.getTime())[0]!;
  await tx.update(guildMembers).set({ role: "leader" }).where(eq(guildMembers.userId, next.userId));
}

/** 公會 (GUILD.md): founding, invitations, members and their roles, the badge, avatars and who is at their computer. */
export function guildRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  async function membership(userId: string) {
    const [row] = await db.select().from(guildMembers).where(eq(guildMembers.userId, userId));
    return row ?? null;
  }
  async function memberIds(guildId: string) {
    return (await db.select({ id: guildMembers.userId }).from(guildMembers).where(eq(guildMembers.guildId, guildId))).map((r) => r.id);
  }
  /** Tells every member (and anyone else named) to fetch the guild again. */
  async function tell(guildId: string | null, ...others: string[]) {
    const ids = new Set([...(guildId ? await memberIds(guildId) : []), ...others]);
    for (const id of ids) deps.hub.notify(id, { type: "guild.changed" });
  }
  /** Until when the account may not join or found a guild (null: it may). */
  async function waitUntil(userId: string, at: Date): Promise<Date | null> {
    const [row] = await db.select({ left: avatars.leftGuildAt }).from(avatars).where(eq(avatars.userId, userId));
    const until = row?.left ? new Date(row.left.getTime() + GUILD_REJOIN_HOURS * HOUR) : null;
    return until && until > at ? until : null;
  }
  async function noteLeft(tx: Tx, userId: string, at: Date) {
    await tx
      .insert(avatars)
      .values({ userId, leftGuildAt: at, updatedAt: at })
      .onConflictDoUpdate({ target: avatars.userId, set: { leftGuildAt: at } });
  }
  async function raceOf(userId: string) {
    const [row] = await db.select({ race: camps.race }).from(camps).where(eq(camps.userId, userId));
    return row?.race ?? "goblin";
  }

  async function view(userId: string): Promise<GuildResponse> {
    const at = now();
    const [mine] = await db
      .select({ avatar: avatars.avatar, race: camps.race })
      .from(users)
      .leftJoin(avatars, eq(avatars.userId, users.id))
      .leftJoin(camps, eq(camps.userId, users.id))
      .where(eq(users.id, userId));
    const own = avatarFor(mine?.avatar, mine?.race ?? "goblin");
    const wait = await waitUntil(userId, at);
    let me = await membership(userId);
    if (me) {
      // (a leader whose account went away leaves the guild leaderless until someone looks)
      const [lead] = await db.select().from(guildMembers).where(and(eq(guildMembers.guildId, me.guildId), eq(guildMembers.role, "leader")));
      if (!lead) {
        await db.transaction((tx) => settleLeader(tx, me!.guildId));
        me = await membership(userId);
      }
    }
    if (!me) {
      const rows = await db
        .select({ guildId: guildInvites.guildId, at: guildInvites.at, name: guilds.name, badge: guilds.badge, by: users.displayName })
        .from(guildInvites)
        .innerJoin(guilds, eq(guilds.id, guildInvites.guildId))
        .leftJoin(users, eq(users.id, guildInvites.invitedBy))
        .where(and(eq(guildInvites.userId, userId), gt(guildInvites.at, new Date(at.getTime() - GUILD_INVITE_DAYS * DAY))));
      const counts = new Map(
        rows.length
          ? (
              await db
                .select({ g: guildMembers.guildId, n: sql<number>`count(*)::int` })
                .from(guildMembers)
                .where(inArray(guildMembers.guildId, rows.map((r) => r.guildId)))
                .groupBy(guildMembers.guildId)
            ).map((r) => [r.g, r.n])
          : [],
      );
      return {
        guild: null,
        invites: rows.map((r) => ({ guildId: r.guildId, name: r.name, badge: r.badge, members: counts.get(r.guildId) ?? 0, by: r.by ?? "", at: r.at.toISOString() })),
        waitUntil: wait?.toISOString() ?? null,
        avatar: own.avatar,
        avatarChosen: own.chosen,
      };
    }
    const [guild] = await db.select().from(guilds).where(eq(guilds.id, me.guildId));
    const members = await db
      .select({ m: guildMembers, name: users.displayName, race: camps.race, focus: camps.focus, avatar: avatars.avatar })
      .from(guildMembers)
      .innerJoin(users, eq(users.id, guildMembers.userId))
      .leftJoin(camps, eq(camps.userId, guildMembers.userId))
      .leftJoin(avatars, eq(avatars.userId, guildMembers.userId))
      .where(eq(guildMembers.guildId, me.guildId));
    const invited =
      me.role === "member"
        ? []
        : await db
            .select({ id: users.id, name: users.displayName, race: camps.race, at: guildInvites.at })
            .from(guildInvites)
            .innerJoin(users, eq(users.id, guildInvites.userId))
            .leftJoin(camps, eq(camps.userId, users.id))
            .where(and(eq(guildInvites.guildId, me.guildId), gt(guildInvites.at, new Date(at.getTime() - GUILD_INVITE_DAYS * DAY))));
    return {
      guild: {
        id: guild!.id,
        name: guild!.name,
        badge: guild!.badge,
        level: guild!.level,
        rules: guildLevel(guild!.level),
        createdAt: guild!.createdAt.toISOString(),
        members: members
          .map((r) => ({
            id: r.m.userId,
            name: r.name,
            race: r.race ?? "goblin",
            role: r.m.role,
            joinedAt: r.m.joinedAt.toISOString(),
            avatar: avatarFor(r.avatar, r.race ?? "goblin").avatar,
            presence: presenceNow(r.m.presence, r.m.presenceAt, at),
            seenAt: r.m.presenceAt?.toISOString() ?? null,
            focusToday: focusToday(r.focus, at),
          }))
          .sort((a, b) => RANK[a.role] - RANK[b.role] || a.joinedAt.localeCompare(b.joinedAt)),
        invited: invited.map((r) => ({ id: r.id, name: r.name, race: r.race ?? "goblin", at: r.at.toISOString() })),
        decor: guild!.decor,
        decorVersion: guild!.decorVersion,
        races: [...new Set(members.map((r) => r.race ?? "goblin"))].sort(),
      },
      invites: [],
      waitUntil: wait?.toISOString() ?? null,
      avatar: own.avatar,
      avatarChosen: own.chosen,
    };
  }

  app.get("/", async (c) => c.json(await view(c.get("session").user.id)));

  /** Founds a guild; the founder leads it. */
  app.post("/", async (c) => {
    const body = await readJson(c, guildCreateInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    if (await membership(me.id)) return apiError(c, 409, "conflict", "你已經在一個公會裡了。");
    const wait = await waitUntil(me.id, at);
    if (wait) return apiError(c, 409, "conflict", `離開公會後要等 ${GUILD_REJOIN_HOURS} 小時才能再加入或建立公會。`);
    const [taken] = await db.select({ id: guilds.id }).from(guilds).where(sql`${guilds.name} = ${body.data.name}`);
    if (taken) return apiError(c, 409, "conflict", "這個公會名字已經有人用了。", { fields: { name: "這個公會名字已經有人用了。" } });
    const guildId = await db.transaction(async (tx) => {
      const [g] = await tx.insert(guilds).values({ name: body.data.name, badge: body.data.badge ?? DEFAULT_BADGE, createdAt: at }).returning();
      await tx.insert(guildMembers).values({ userId: me.id, guildId: g!.id, role: "leader", joinedAt: at });
      await tx.delete(guildInvites).where(eq(guildInvites.userId, me.id));
      return g!.id;
    });
    await tell(guildId);
    return c.json(await view(me.id), 201);
  });

  /** Renames the guild or puts a new badge on it (the leader). */
  app.patch("/", async (c) => {
    const body = await readJson(c, guildUpdateInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    if (mine.role !== "leader") return apiError(c, 403, "forbidden", "只有會長可以改公會的名字和徽章。");
    if (body.data.name) {
      const [taken] = await db.select({ id: guilds.id }).from(guilds).where(sql`${guilds.name} = ${body.data.name} and ${guilds.id} <> ${mine.guildId}`);
      if (taken) return apiError(c, 409, "conflict", "這個公會名字已經有人用了。", { fields: { name: "這個公會名字已經有人用了。" } });
    }
    const set = { ...(body.data.name ? { name: body.data.name } : {}), ...(body.data.badge ? { badge: body.data.badge } : {}) };
    if (Object.keys(set).length) await db.update(guilds).set(set).where(eq(guilds.id, mine.guildId));
    await tell(mine.guildId);
    return c.json(await view(me.id));
  });

  /** Invites someone (by friend code or who they are): the leader and officers. */
  app.post("/invites", async (c) => {
    const body = await readJson(c, guildInviteInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    if (mine.role === "member") return apiError(c, 403, "forbidden", "只有會長和幹部可以邀請。");
    const [other] = body.data.code
      ? await db.select({ id: users.id }).from(users).where(and(sql`upper(${users.friendCode}) = ${body.data.code.toUpperCase()}`, isNull(users.deletingAt), isNull(users.disabledAt)))
      : await db.select({ id: users.id }).from(users).where(and(eq(users.id, body.data.userId!), isNull(users.deletingAt), isNull(users.disabledAt)));
    if (!other) return apiError(c, 404, "not_found", "找不到這個好友代碼。");
    if (other.id === me.id) return apiError(c, 400, "invalid_input", "這是你自己的代碼。");
    if (await membership(other.id)) return apiError(c, 409, "conflict", "對方已經在一個公會裡了。");
    const [guild] = await db.select().from(guilds).where(eq(guilds.id, mine.guildId));
    if ((await memberIds(mine.guildId)).length >= guildLevel(guild!.level).members) {
      return apiError(c, 409, "conflict", `公會已經滿了（${guildLevel(guild!.level).members} 人），升級後可以收更多人。`);
    }
    const fresh = new Date(at.getTime() - GUILD_INVITE_DAYS * DAY);
    await db.delete(guildInvites).where(lt(guildInvites.at, fresh));
    const [{ n }] = (await db.select({ n: sql<number>`count(*)::int` }).from(guildInvites).where(eq(guildInvites.guildId, mine.guildId))) as [{ n: number }];
    if (n >= GUILD_PENDING_INVITES_MAX) return apiError(c, 409, "conflict", `同時最多等 ${GUILD_PENDING_INVITES_MAX} 個人回覆。`);
    await db
      .insert(guildInvites)
      .values({ guildId: mine.guildId, userId: other.id, invitedBy: me.id, at })
      .onConflictDoUpdate({ target: [guildInvites.guildId, guildInvites.userId], set: { invitedBy: me.id, at } });
    await tell(mine.guildId, other.id);
    const push: SocialPush = { type: "social", title: "公會邀請", body: `${me.displayName} 邀請你加入「${guild!.name}」`, url: "/guild", tag: `guild-${mine.guildId}` };
    await pushToPhones(deps, other.id, push);
    return c.json(await view(me.id), 201);
  });

  /** Takes an invitation back (the leader and officers). */
  app.delete("/invites/:userId", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("userId");
    const mine = await membership(me.id);
    if (!mine || !isUuid(id)) return apiError(c, 404, "not_found", "沒有這個邀請。");
    if (mine.role === "member") return apiError(c, 403, "forbidden", "只有會長和幹部可以收回邀請。");
    await db.delete(guildInvites).where(and(eq(guildInvites.guildId, mine.guildId), eq(guildInvites.userId, id)));
    await tell(mine.guildId, id);
    return c.body(null, 204);
  });

  /** Yes to an invitation: joins that guild (the others the account had go away). */
  app.post("/join/:guildId", async (c) => {
    const me = c.get("session").user;
    const guildId = c.req.param("guildId");
    const at = now();
    if (!isUuid(guildId)) return apiError(c, 404, "not_found", "沒有這個邀請。");
    if (await membership(me.id)) return apiError(c, 409, "conflict", "你已經在一個公會裡了。");
    const wait = await waitUntil(me.id, at);
    if (wait) return apiError(c, 409, "conflict", `離開公會後要等 ${GUILD_REJOIN_HOURS} 小時才能再加入或建立公會。`);
    const result = await db.transaction(async (tx) => {
      const [guild] = await tx.select().from(guilds).where(eq(guilds.id, guildId)).for("update");
      const [invite] = await tx.select().from(guildInvites).where(and(eq(guildInvites.guildId, guildId), eq(guildInvites.userId, me.id)));
      if (!guild || !invite || invite.at.getTime() < at.getTime() - GUILD_INVITE_DAYS * DAY) return "gone" as const;
      const [{ n }] = (await tx.select({ n: sql<number>`count(*)::int` }).from(guildMembers).where(eq(guildMembers.guildId, guildId))) as [{ n: number }];
      if (n >= guildLevel(guild.level).members) return "full" as const;
      await tx.insert(guildMembers).values({ userId: me.id, guildId, role: "member", joinedAt: at });
      await tx.delete(guildInvites).where(eq(guildInvites.userId, me.id));
      return "joined" as const;
    });
    if (result === "gone") return apiError(c, 404, "not_found", "這個邀請已經沒有了。");
    if (result === "full") return apiError(c, 409, "conflict", "這個公會已經滿了。");
    await tell(guildId, me.id);
    return c.json(await view(me.id));
  });

  /** No to an invitation. */
  app.delete("/join/:guildId", async (c) => {
    const me = c.get("session").user;
    const guildId = c.req.param("guildId");
    if (!isUuid(guildId)) return apiError(c, 404, "not_found", "沒有這個邀請。");
    await db.delete(guildInvites).where(and(eq(guildInvites.guildId, guildId), eq(guildInvites.userId, me.id)));
    await tell(guildId, me.id);
    return c.body(null, 204);
  });

  /** Leaves the guild (a leader's place goes to the next in line; the last one out breaks it up). */
  app.post("/leave", async (c) => {
    const me = c.get("session").user;
    const at = now();
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    await db.transaction(async (tx) => {
      await tx.select().from(guilds).where(eq(guilds.id, mine.guildId)).for("update");
      await tx.delete(guildMembers).where(eq(guildMembers.userId, me.id));
      await noteLeft(tx, me.id, at);
      await settleLeader(tx, mine.guildId);
    });
    await tell(mine.guildId, me.id);
    return c.json(await view(me.id));
  });

  /** Sends a member away: the leader anyone, an officer only members. */
  app.delete("/members/:id", async (c) => {
    const me = c.get("session").user;
    const id = c.req.param("id");
    const mine = await membership(me.id);
    const them = isUuid(id) ? await membership(id) : null;
    if (!mine || !them || them.guildId !== mine.guildId || id === me.id) return apiError(c, 404, "not_found", "公會裡沒有這個人。");
    if (RANK[mine.role] >= RANK[them.role]) return apiError(c, 403, "forbidden", "你不能請這個人離開。");
    // (no wait for them: they did not choose to go)
    await db.delete(guildMembers).where(eq(guildMembers.userId, id));
    await tell(mine.guildId, id);
    return c.json(await view(me.id));
  });

  /** The leader makes a member an officer or a member again, or hands over the lead (and becomes an officer). */
  app.put("/members/:id/role", async (c) => {
    const body = await readJson(c, guildRoleInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const id = c.req.param("id");
    const mine = await membership(me.id);
    const them = isUuid(id) ? await membership(id) : null;
    if (!mine || !them || them.guildId !== mine.guildId) return apiError(c, 404, "not_found", "公會裡沒有這個人。");
    if (mine.role !== "leader") return apiError(c, 403, "forbidden", "只有會長可以改職位。");
    if (id === me.id) return apiError(c, 400, "invalid_input", "要換會長，請把會長交給別人。");
    await db.transaction(async (tx) => {
      if (body.data.role === "leader") await tx.update(guildMembers).set({ role: "officer" }).where(eq(guildMembers.userId, me.id));
      await tx.update(guildMembers).set({ role: body.data.role }).where(eq(guildMembers.userId, id));
    });
    await tell(mine.guildId);
    return c.json(await view(me.id));
  });

  /** Saves this account's avatar (its race must be the camp's). */
  app.put("/avatar", async (c) => {
    const body = await readJson(c, avatarSchema);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    const race = await raceOf(me.id);
    if (body.data.race !== race) return apiError(c, 400, "invalid_input", "分身的種族要和營地一樣。", { fields: { race: "分身的種族要和營地一樣。" } });
    const problem = avatarProblem(body.data);
    if (problem) return apiError(c, 400, "invalid_input", problem);
    await db
      .insert(avatars)
      .values({ userId: me.id, avatar: body.data, updatedAt: at })
      .onConflictDoUpdate({ target: avatars.userId, set: { avatar: body.data, updatedAt: at } });
    const mine = await membership(me.id);
    await tell(mine?.guildId ?? null, me.id);
    return c.json(await view(me.id));
  });

  /** The Mac says whether its person is focusing, there, away or gone (when it changes, and every PRESENCE_HEARTBEAT_SECONDS). */
  app.put("/presence", async (c) => {
    const body = await readJson(c, presenceInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    const mine = await membership(me.id);
    if (!mine) return c.body(null, 204);
    const was = presenceNow(mine.presence, mine.presenceAt, at);
    await db.update(guildMembers).set({ presence: body.data.state, presenceAt: at }).where(eq(guildMembers.userId, me.id));
    if (was !== body.data.state) {
      for (const id of await memberIds(mine.guildId)) deps.hub.notify(id, { type: "guild.presence", userId: me.id, state: body.data.state, at: at.toISOString() });
    }
    return c.body(null, 204);
  });

  /** Puts down, moves or takes away decorations: the whole list, made from version `version` (GUILD.md §4.2). */
  app.put("/decor", async (c) => {
    const body = await readJson(c, guildDecorInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    const result = await db.transaction(async (tx) => {
      const [guild] = await tx.select().from(guilds).where(eq(guilds.id, mine.guildId)).for("update");
      if (guild!.decorVersion !== body.data.version) return { error: 409 as const, message: "別人剛改過裝飾，請重新整理後再試一次。" };
      const races = new Set(
        (await tx.select({ race: camps.race }).from(guildMembers).leftJoin(camps, eq(camps.userId, guildMembers.userId)).where(eq(guildMembers.guildId, mine.guildId))).map((r) => r.race ?? "goblin"),
      );
      const problem = guildDecorProblem(body.data.items, guild!.level, races, guild!.decor);
      if (problem) return { error: 400 as const, message: problem };
      const change = guildDecorChange(guild!.decor, body.data.items, mine.role);
      if (typeof change === "string") return { error: 403 as const, message: change };
      if (!change.added && !change.moved && !change.removed) return { ok: true };
      await tx.update(guilds).set({ decor: body.data.items, decorVersion: guild!.decorVersion + 1 }).where(eq(guilds.id, mine.guildId));
      await tx.insert(guildDecorLog).values({ guildId: mine.guildId, userId: me.id, at, ...change, before: guild!.decor });
      await tx.delete(guildDecorLog).where(and(eq(guildDecorLog.guildId, mine.guildId), lt(guildDecorLog.at, new Date(at.getTime() - GUILD_DECOR_LOG_DAYS * DAY))));
      return { ok: true };
    });
    if (result.error) return apiError(c, result.error, ({ 400: "invalid_input", 403: "forbidden", 409: "conflict" } as const)[result.error], result.message);
    await tell(mine.guildId);
    return c.json(await view(me.id));
  });

  /** The decorations' log, newest first (everyone sees who did what). */
  app.get("/decor/log", async (c) => {
    const me = c.get("session").user;
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    const rows = await db
      .select({ l: guildDecorLog, name: users.displayName })
      .from(guildDecorLog)
      .leftJoin(users, eq(users.id, guildDecorLog.userId))
      .where(eq(guildDecorLog.guildId, mine.guildId))
      .orderBy(desc(guildDecorLog.at))
      .limit(100);
    const entries: GuildDecorLogEntry[] = rows.map((r) => ({ id: r.l.id, by: r.name ?? "", at: r.l.at.toISOString(), added: r.l.added, moved: r.l.moved, removed: r.l.removed, restored: r.l.restored }));
    return c.json({ entries });
  });

  /** The leader puts the decorations back as they were before change `logId` (that going-back is logged too, so it can be undone). */
  app.post("/decor/restore", async (c) => {
    const body = await readJson(c, guildDecorRestoreInput);
    if ("response" in body) return body.response;
    const me = c.get("session").user;
    const at = now();
    const mine = await membership(me.id);
    if (!mine) return apiError(c, 404, "not_found", "你還沒有加入公會。");
    if (mine.role !== "leader") return apiError(c, 403, "forbidden", "只有會長可以還原裝飾。");
    const done = await db.transaction(async (tx) => {
      const [guild] = await tx.select().from(guilds).where(eq(guilds.id, mine.guildId)).for("update");
      const [entry] = await tx.select().from(guildDecorLog).where(and(eq(guildDecorLog.id, body.data.logId), eq(guildDecorLog.guildId, mine.guildId)));
      if (!entry) return false;
      const was = new Set(guild!.decor.map((d) => d.uid));
      const back = new Set(entry.before.map((d) => d.uid));
      await tx.update(guilds).set({ decor: entry.before, decorVersion: guild!.decorVersion + 1 }).where(eq(guilds.id, mine.guildId));
      await tx.insert(guildDecorLog).values({
        guildId: mine.guildId,
        userId: me.id,
        at,
        added: entry.before.filter((d) => !was.has(d.uid)).length,
        moved: 0,
        removed: guild!.decor.filter((d) => !back.has(d.uid)).length,
        restored: true,
        before: guild!.decor,
      });
      return true;
    });
    if (!done) return apiError(c, 404, "not_found", "這筆紀錄已經沒有了。");
    await tell(mine.guildId);
    return c.json(await view(me.id));
  });

  return app;
}
