import { Hono } from "hono";
import { eq } from "drizzle-orm";
import { pushSubscriptionSchema } from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { devices } from "../db/schema.ts";
import { apiError, readJson } from "../http.ts";

/** 手機推播：the public key, and a phone telling the server where to push to. */
export function pushRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;

  app.get("/key", (c) => c.json({ publicKey: deps.push.publicKey }));

  app.post("/subscribe", requireAuth(deps), async (c) => {
    const session = c.get("session");
    if (!session.deviceId) return apiError(c, 400, "invalid_input", "這個登入沒有裝置資料，請重新登入。");
    const body = await readJson(c, pushSubscriptionSchema);
    if ("response" in body) return body.response;
    const [device] = await db.select({ kind: devices.kind }).from(devices).where(eq(devices.id, session.deviceId));
    if (device?.kind !== "pwa") return apiError(c, 400, "invalid_input", "只有手機網頁可以訂閱推播。");
    await db.update(devices).set({ pushSubscription: body.data }).where(eq(devices.id, session.deviceId));
    return c.body(null, 204);
  });

  app.delete("/subscribe", requireAuth(deps), async (c) => {
    const deviceId = c.get("session").deviceId;
    if (deviceId) await db.update(devices).set({ pushSubscription: null }).where(eq(devices.id, deviceId));
    return c.body(null, 204);
  });

  return app;
}
