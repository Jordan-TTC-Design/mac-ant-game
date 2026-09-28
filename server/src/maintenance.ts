/**
 * Keeping the database from growing for ever (server/DESIGN.md §13): once a few hours, what is no longer needed goes.
 *
 * - camp events after 30 days (what the devices play and the phone lists; nobody scrolls back further);
 * - an expedition's blow-by-blow after 7 days (the report stays: who, where, the outcome), the whole report after 30;
 * - a great monster's spoils already taken, after 30 days;
 * - sign-ins that ended (signed out or expired) after 30 days;
 * - mail links (confirm, reset) and the Mac's one-time web links used or expired, after 7 days;
 * - invite codes that ran out unused, after 30 days;
 * - accounts that asked to be deleted (or an admin deleted), 30 days after (everything of theirs goes with them).
 */
import { and, eq, isNotNull, isNull, lt, or, sql } from "drizzle-orm";
import type { AppDeps } from "./app.ts";
import { campEvents, emailTokens, expeditions, invites, sessions, users, worldRewards } from "./db/schema.ts";

const DAY = 86_400_000;
export const KEEP = { events: 30, replays: 7, reports: 30, rewards: 30, sessions: 30, links: 7, invites: 30, deleting: 30 };

export interface Cleared {
  events: number;
  replays: number;
  reports: number;
  rewards: number;
  sessions: number;
  links: number;
  invites: number;
  accounts: number;
}

export async function clearOld(deps: Pick<AppDeps, "database">, now: Date): Promise<Cleared> {
  const { db } = deps.database;
  const before = (days: number) => new Date(now.getTime() - days * DAY);
  const count = async (q: Promise<unknown[]>) => (await q).length;
  const events = await count(db.delete(campEvents).where(lt(campEvents.at, before(KEEP.events))).returning({ seq: campEvents.seq }));
  const replays = await count(
    db
      .update(expeditions)
      .set({ result: sql`${expeditions.result} - 'events'` })
      .where(and(eq(expeditions.status, "done"), lt(expeditions.arriveAt, before(KEEP.replays)), sql`${expeditions.result} ? 'events'`))
      .returning({ id: expeditions.id }),
  );
  const reports = await count(db.delete(expeditions).where(and(eq(expeditions.status, "done"), lt(expeditions.arriveAt, before(KEEP.reports)))).returning({ id: expeditions.id }));
  const rewards = await count(db.delete(worldRewards).where(and(isNotNull(worldRewards.claimedAt), lt(worldRewards.claimedAt, before(KEEP.rewards)))).returning({ id: worldRewards.id }));
  const sessionsGone = await count(
    db
      .delete(sessions)
      .where(or(lt(sessions.expiresAt, before(KEEP.sessions)), and(isNotNull(sessions.revokedAt), lt(sessions.revokedAt, before(KEEP.sessions)))))
      .returning({ id: sessions.id }),
  );
  const links = await count(
    db
      .delete(emailTokens)
      .where(or(lt(emailTokens.expiresAt, before(KEEP.links)), and(isNotNull(emailTokens.usedAt), lt(emailTokens.usedAt, before(KEEP.links)))))
      .returning({ id: emailTokens.id }),
  );
  const invitesGone = await count(db.delete(invites).where(and(isNull(invites.usedAt), lt(invites.expiresAt, before(KEEP.invites)))).returning({ at: invites.createdAt }));
  const accounts = await count(db.delete(users).where(and(isNotNull(users.deletingAt), lt(users.deletingAt, before(KEEP.deleting)))).returning({ id: users.id }));
  return { events, replays, reports, rewards, sessions: sessionsGone, links, invites: invitesGone, accounts };
}

/** Clears old records a minute after the start and then every six hours; returns a function that stops it. */
export function startMaintenance(deps: Pick<AppDeps, "database">, everyMs = 6 * 3_600_000): () => void {
  const run = async () => {
    try {
      const cleared = await clearOld(deps, new Date());
      const total = Object.values(cleared).reduce((a, b) => a + b, 0);
      if (total) console.log("cleared old records:", cleared);
    } catch (err) {
      console.error("maintenance:", err);
    }
  };
  const first = setTimeout(run, 60_000);
  const timer = setInterval(run, everyMs);
  return () => {
    clearTimeout(first);
    clearInterval(timer);
  };
}
