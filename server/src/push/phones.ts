import { and, eq, isNotNull } from "drizzle-orm";
import type { ClaudePush, PushSubscriptionJSON, SocialPush } from "@goblincamp/shared";
import type { AppDeps } from "../app.ts";
import { devices } from "../db/schema.ts";

/** Pushes to every phone of an account that takes notifications (a phone the push service says is gone is forgotten). */
export async function pushToPhones(deps: Pick<AppDeps, "database" | "push">, userId: string, payload: SocialPush | ClaudePush | object): Promise<number> {
  const { db } = deps.database;
  const phones = await db
    .select({ id: devices.id, subscription: devices.pushSubscription })
    .from(devices)
    .where(and(eq(devices.userId, userId), eq(devices.kind, "pwa"), isNotNull(devices.pushSubscription)));
  let sent = 0;
  for (const phone of phones) {
    const outcome = await deps.push.send(phone.subscription as PushSubscriptionJSON, payload);
    if (outcome === "gone") await db.update(devices).set({ pushSubscription: null }).where(eq(devices.id, phone.id));
    if (outcome === "sent") sent++;
  }
  return sent;
}
