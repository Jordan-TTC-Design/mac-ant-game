import { Hono } from "hono";
import { API_VERSION, type Health } from "@goblincamp/shared";

export interface AppDeps {
  /** Whether the database answers. */
  pingDatabase: () => Promise<boolean>;
}

/** The HTTP API, without the network part, so tests can call it directly. */
export function createApp(deps: AppDeps) {
  const app = new Hono().basePath("/api");

  app.get("/health", async (c) => {
    const dbUp = await deps.pingDatabase();
    const body: Health = { ok: dbUp, db: dbUp ? "ok" : "down", apiVersion: API_VERSION };
    return c.json(body, dbUp ? 200 : 503);
  });

  return app;
}
