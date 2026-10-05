import { Hono } from "hono";
import { campCommand, feedEntries, migrateInput, RACE_NOUNS, sanctuaryInput, SANCTUARY_REST_HOURS, startCampInput, type CampEvent, type FeedResponse } from "@goblincamp/shared/camp";
import { and, desc, eq, lt } from "drizzle-orm";
import { campEvents, camps } from "../db/schema.ts";
import { advanceWorld } from "../world/service.ts";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { apiError, readJson } from "../http.ts";
import { runCommand } from "./commands.ts";
import { questList } from "./quests.ts";
import { advanceCamp, campView, eventsSince, lockCamp, migrateCamp, recentRaids, startCamp } from "./service.ts";

/** 營地：the account's one camp, kept by the server (server/CAMP.md). */
export function campRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  /** The books as they are now (births and deaths worked out up to this moment first). */
  app.get("/", async (c) => {
    const userId = c.get("session").user.id;
    const result = await db.transaction(async (tx) => {
      const camp = await lockCamp(tx, userId);
      if (!camp) return null;
      const changed = await advanceCamp(tx, camp, now());
      return { view: await campView(tx, camp), changed };
    });
    if (!result) return apiError(c, 404, "not_found", "這個帳號還沒有營地。");
    if (result.changed) deps.hub.notify(userId, { type: "camp.changed", version: result.view.version });
    return c.json(result.view);
  });

  /** 任務: where each stands, and which rewards were taken (camp/quests.ts). */
  app.get("/quests", async (c) => {
    const userId = c.get("session").user.id;
    const quests = await db.transaction(async (tx) => {
      const camp = await lockCamp(tx, userId);
      if (!camp) return null;
      await advanceWorld(tx, camp, now());
      return questList(tx, camp);
    });
    if (!quests) return apiError(c, 404, "not_found", "這個帳號還沒有營地。");
    return c.json({ quests });
  });

  app.get("/events", async (c) => {
    const since = Number(c.req.query("since") ?? "0");
    if (!Number.isSafeInteger(since) || since < 0) return apiError(c, 400, "invalid_input", "since 要是 0 以上的整數。");
    const events = await db.transaction((tx) => eventsSince(tx, c.get("session").user.id, since));
    return c.json({ events, seq: events.at(-1)?.seq ?? since });
  });

  /** 動態: what happened at the camp, a line each, newest first (shared/src/camp/feed.ts); older with `?before=<seq>`. */
  app.get("/feed", async (c) => {
    const before = Number(c.req.query("before") ?? "0");
    const limit = Number(c.req.query("limit") ?? "40");
    if (!Number.isSafeInteger(before) || before < 0 || !Number.isSafeInteger(limit) || limit < 1 || limit > 100) {
      return apiError(c, 400, "invalid_input", "before 要是 0 以上的整數，limit 是 1 到 100。");
    }
    const userId = c.get("session").user.id;
    const out = await db.transaction(async (tx) => {
      const [camp] = await tx.select({ race: camps.race }).from(camps).where(eq(camps.userId, userId));
      // (more events than lines: some make none, and a run of births makes one)
      const rows = await tx
        .select({ seq: campEvents.seq, at: campEvents.at, kind: campEvents.kind, data: campEvents.data })
        .from(campEvents)
        .where(and(eq(campEvents.userId, userId), before ? lt(campEvents.seq, before) : undefined))
        .orderBy(desc(campEvents.seq))
        .limit(limit * 5);
      const events = rows.map((r) => ({ seq: r.seq, at: r.at.toISOString(), kind: r.kind as CampEvent["kind"], data: r.data }));
      const entries = feedEntries(events, RACE_NOUNS[camp?.race ?? ""] ?? "居民");
      return { entries: entries.slice(0, limit), more: entries.length > limit || rows.length === limit * 5 } satisfies FeedResponse;
    });
    return c.json(out);
  });

  /** The latest monster raids, newest first, as a short report (who came, who fell, what was left). */
  app.get("/raids", async (c) => {
    const limit = Number(c.req.query("limit") ?? "10");
    if (!Number.isSafeInteger(limit) || limit < 1 || limit > 50) return apiError(c, 400, "invalid_input", "limit 要是 1 到 50。");
    return c.json({ raids: await db.transaction((tx) => recentRaids(tx, c.get("session").user.id, limit)) });
  });

  /** A new camp for an account that has none. */
  app.post("/start", async (c) => {
    const body = await readJson(c, startCampInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const camp = await db.transaction((tx) => startCamp(tx, userId, body.data.race, now()));
    if (camp === "exists") return apiError(c, 409, "conflict", "這個帳號已經有營地了。");
    deps.hub.notify(userId, { type: "camp.changed", version: camp.version });
    return c.json(await db.transaction((tx) => campView(tx, camp)), 201);
  });

  /** 開新世界：the old camp goes and a new one starts. */
  app.post("/new-world", async (c) => {
    const body = await readJson(c, startCampInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const camp = await db.transaction((tx) => startCamp(tx, userId, body.data.race, now(), true));
    if (camp === "exists") return apiError(c, 409, "conflict", "這個帳號已經有營地了。");
    deps.hub.notify(userId, { type: "camp.changed", version: camp.version });
    return c.json(await db.transaction((tx) => campView(tx, camp)), 201);
  });

  /** A Mac moving its old camp in (the first time it signs in). */
  app.post("/migrate", async (c) => {
    const body = await readJson(c, migrateInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const camp = await db.transaction((tx) => migrateCamp(tx, userId, body.data, now()));
    if (camp === "exists") return apiError(c, 409, "conflict", "這個帳號已經有營地了，要換成這台的請再確認一次。");
    deps.hub.notify(userId, { type: "camp.changed", version: camp.version });
    return c.json(await db.transaction((tx) => campView(tx, camp)), 201);
  });

  /** One thing the player does (craft, repair, food, the princess's name, her story), checked against the books. */
  /**
   * 聖光模式 on or off (server/CAMP.md §7): no raids, nobody may attack the camp or its cells (and it attacks nobody),
   * births at half speed while it has 120 or more. Off at any time; on again SANCTUARY_REST_HOURS after it was turned off.
   */
  app.post("/sanctuary", async (c) => {
    const body = await readJson(c, sanctuaryInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const at = now();
    const out = await db.transaction(async (tx) => {
      const camp = await lockCamp(tx, userId);
      if (!camp) return { problem: apiError(c, 404, "not_found", "這個帳號還沒有營地。") };
      // (everything up to now under the old rules first)
      await advanceWorld(tx, camp, at);
      if (body.data.on && !camp.sanctuarySince) {
        const until = camp.sanctuaryOffAt ? camp.sanctuaryOffAt.getTime() + SANCTUARY_REST_HOURS * 3_600_000 : 0;
        if (until > at.getTime()) {
          const hours = Math.ceil((until - at.getTime()) / 3_600_000);
          return { problem: apiError(c, 409, "conflict", `聖光模式關掉後要 ${SANCTUARY_REST_HOURS} 小時才能再開（還要 ${hours} 小時）。`) };
        }
        camp.sanctuarySince = at;
      } else if (!body.data.on && camp.sanctuarySince) {
        camp.sanctuarySince = null;
        camp.sanctuaryOffAt = at;
      }
      camp.version += 1;
      await tx.update(camps).set({ sanctuarySince: camp.sanctuarySince, sanctuaryOffAt: camp.sanctuaryOffAt, version: camp.version }).where(eq(camps.userId, userId));
      return { view: await campView(tx, camp) };
    });
    if ("problem" in out) return out.problem!;
    deps.hub.notify(userId, { type: "camp.changed", version: out.view.version });
    return c.json(out.view);
  });

  app.post("/commands", async (c) => {
    const body = await readJson(c, campCommand);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const out = await db.transaction(async (tx) => {
      const camp = await lockCamp(tx, userId);
      if (!camp) return null;
      await advanceCamp(tx, camp, now());
      const result = await runCommand(tx, camp, body.data, now());
      return { result, view: await campView(tx, camp) };
    });
    if (!out) return apiError(c, 404, "not_found", "這個帳號還沒有營地。");
    if (!out.result.ok) return c.json({ error: out.result.code, message: out.result.message, camp: out.view }, 409);
    deps.hub.notify(userId, { type: "camp.changed", version: out.view.version });
    return c.json({ message: out.result.message, resident: out.result.resident ?? null, camp: out.view });
  });

  return app;
}
