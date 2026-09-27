import { Hono } from "hono";
import { createNodeWebSocket } from "@hono/node-ws";
import { API_VERSION, type Health, type ServerEvent } from "@goblincamp/shared";
import { authRoutes } from "./auth/routes.ts";
import { requireAuth, type CurrentSession } from "./auth/session.ts";
import type { Config } from "./config.ts";
import type { Database } from "./db/client.ts";
import { apiError } from "./http.ts";
import type { RateLimiter } from "./lib/rate-limit.ts";
import type { Mailer } from "./mail/mailer.ts";
import { noteRoutes } from "./notes/routes.ts";
import { pushRoutes } from "./push/routes.ts";
import { NoPushSender, type PushSender } from "./push/sender.ts";
import { Hub, type Socket } from "./realtime/hub.ts";

export interface AppDeps {
  database: Database;
  mailer: Mailer;
  config: Pick<Config, "APP_URL" | "TRUST_PROXY">;
  hub: Hub;
  /** Web Push to phones (no keys set: nothing is pushed). */
  push: PushSender;
  /** The clock (tests move it forward). */
  now?: () => Date;
  limiter?: RateLimiter;
}

export type AppEnv = { Variables: { session: CurrentSession } };

/**
 * The HTTP API. `app.request()` works without a network (tests); `injectWebSocket` must be given the real server for /api/ws.
 */
export function createApp(options: Omit<AppDeps, "hub" | "push"> & { hub?: Hub; push?: PushSender }) {
  const deps: AppDeps = { ...options, hub: options.hub ?? new Hub(), push: options.push ?? new NoPushSender() };
  const root = new Hono<AppEnv>();
  const { upgradeWebSocket, injectWebSocket } = createNodeWebSocket({ app: root });
  const app = root.basePath("/api");

  app.get("/health", async (c) => {
    const dbUp = await deps.database.ping();
    const body: Health = { ok: dbUp, db: dbUp ? "ok" : "down", apiVersion: API_VERSION };
    return c.json(body, dbUp ? 200 : 503);
  });

  app.route("/auth", authRoutes(deps));
  app.route("/notes", noteRoutes(deps));
  app.route("/push", pushRoutes(deps));

  // Signed-in devices keep this open and are told when something changed (then they fetch it).
  const appOrigin = new URL(deps.config.APP_URL).origin;
  app.get(
    "/ws",
    requireAuth(deps),
    async (c, next) => {
      // a browser sends its cookie with a WebSocket from any site, so it must come from our own page
      const origin = c.req.header("origin");
      if (c.get("session").viaCookie && origin !== appOrigin) return apiError(c, 403, "forbidden", "這個連線不是從哥布林營地的網頁來的。");
      await next();
    },
    upgradeWebSocket((c) => {
      const session = c.get("session");
      let socket: Socket | undefined;
      return {
        onOpen(_event, ws) {
          socket = { send: (data) => ws.send(data), close: (code, reason) => ws.close(code, reason) };
          deps.hub.add(session.user.id, session.id, socket);
          const hello: ServerEvent = { type: "hello", userId: session.user.id };
          ws.send(JSON.stringify(hello));
        },
        onClose() {
          if (socket) deps.hub.remove(session.user.id, socket);
        },
      };
    }),
  );

  root.onError((err, c) => {
    console.error(err);
    return c.json({ error: "internal", message: "伺服器出了點問題，請稍後再試。" }, 500);
  });

  return Object.assign(root, { deps, injectWebSocket });
}
