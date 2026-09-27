import { Hono } from "hono";
import { API_VERSION, type Health } from "@goblincamp/shared";
import { authRoutes } from "./auth/routes.ts";
import type { CurrentSession } from "./auth/session.ts";
import type { Config } from "./config.ts";
import type { Database } from "./db/client.ts";
import type { RateLimiter } from "./lib/rate-limit.ts";
import type { Mailer } from "./mail/mailer.ts";

export interface AppDeps {
  database: Database;
  mailer: Mailer;
  config: Pick<Config, "APP_URL" | "TRUST_PROXY">;
  /** The clock (tests move it forward). */
  now?: () => Date;
  limiter?: RateLimiter;
}

export type AppEnv = { Variables: { session: CurrentSession } };

/** The HTTP API, without the network part, so tests can call it directly. */
export function createApp(deps: AppDeps) {
  const app = new Hono<AppEnv>().basePath("/api");

  app.get("/health", async (c) => {
    const dbUp = await deps.database.ping();
    const body: Health = { ok: dbUp, db: dbUp ? "ok" : "down", apiVersion: API_VERSION };
    return c.json(body, dbUp ? 200 : 503);
  });

  app.route("/auth", authRoutes(deps));

  app.onError((err, c) => {
    console.error(err);
    return c.json({ error: "internal", message: "伺服器出了點問題，請稍後再試。" }, 500);
  });

  return app;
}
