import { Hono } from "hono";
import { migrateInput, startCampInput } from "@goblincamp/shared/camp";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { apiError, readJson } from "../http.ts";
import { advanceCamp, campView, eventsSince, lockCamp, migrateCamp, startCamp } from "./service.ts";

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

  app.get("/events", async (c) => {
    const since = Number(c.req.query("since") ?? "0");
    if (!Number.isSafeInteger(since) || since < 0) return apiError(c, 400, "invalid_input", "since 要是 0 以上的整數。");
    const events = await db.transaction((tx) => eventsSince(tx, c.get("session").user.id, since));
    return c.json({ events, seq: events.at(-1)?.seq ?? since });
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

  return app;
}
