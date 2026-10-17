import type { Hono } from "hono";
import type { AppDeps, AppEnv } from "../app.ts";
import { economyReport } from "../camp/economy.ts";
import { apiError } from "../http.ts";
import type { AdminLog } from "./users.ts";

/** 後台 › 經濟 (shared/src/camp/economy.ts): the camps' materials and how they flow, over the last `days` (1–30). */
export function adminEconomyRoutes(app: Hono<AppEnv>, deps: AppDeps, _log: AdminLog) {
  const now = deps.now ?? (() => new Date());
  app.get("/economy", async (c) => {
    const days = Number(c.req.query("days") ?? "7");
    if (!Number.isInteger(days) || days < 1 || days > 30) return apiError(c, 400, "invalid_input", "days 要是 1 到 30。");
    return c.json(await economyReport(deps.database.db, now(), days));
  });
}
