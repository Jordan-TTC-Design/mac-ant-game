import { and, desc, eq, gt, sql } from "drizzle-orm";
import { campStage, MERCHANT_STAY_MINUTES, merchantVisit, type MerchantVisit } from "@goblincamp/shared/camp";
import type { Tx } from "../auth/session.ts";
import { campEvents, camps } from "../db/schema.ts";

type CampRow = typeof camps.$inferSelect;

/** The merchant's visits in the last day, newest first (they are the `merchant-arrive` commands' events: shared/src/camp/merchant.ts). */
export async function merchantArrivals(tx: Tx, userId: string, now: Date): Promise<{ visit: string; at: Date }[]> {
  const rows = await tx
    .select({ at: campEvents.at, data: campEvents.data })
    .from(campEvents)
    .where(and(
      eq(campEvents.userId, userId),
      eq(campEvents.kind, "command"),
      gt(campEvents.at, new Date(now.getTime() - 24 * 3_600_000)),
      sql`${campEvents.data}->'command'->>'kind' = 'merchant-arrive'`,
      sql`${campEvents.data}->>'visit' is not null`,
    ))
    .orderBy(desc(campEvents.seq))
    .limit(10);
  return rows.map((r) => ({ visit: (r.data as { visit: string }).visit, at: r.at }));
}

/** The offers of a visit already taken. */
export async function merchantBought(tx: Tx, userId: string, visit: string): Promise<number[]> {
  const rows = await tx
    .select({ data: campEvents.data })
    .from(campEvents)
    .where(and(
      eq(campEvents.userId, userId),
      eq(campEvents.kind, "command"),
      sql`${campEvents.data}->'command'->>'kind' = 'merchant-trade'`,
      sql`${campEvents.data}->'command'->>'visit' = ${visit}`,
    ));
  return rows.map((r) => (r.data as { command: { offer: number } }).command.offer);
}

/** The visit going on now (the merchant is still at the camp), or null. */
export async function merchantNow(tx: Tx, camp: CampRow, now: Date): Promise<MerchantVisit | null> {
  const [latest] = await merchantArrivals(tx, camp.userId, now);
  if (!latest || now.getTime() - latest.at.getTime() >= MERCHANT_STAY_MINUTES * 60_000) return null;
  return merchantVisit(latest.visit, camp.race, campStage(camp.race, camp.peak), latest.at, await merchantBought(tx, camp.userId, latest.visit));
}
