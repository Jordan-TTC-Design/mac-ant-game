import { eq } from "drizzle-orm";
import { talentBonus, type TalentEffect, type TalentPicks } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { worldPlayers } from "../db/schema.ts";

/**
 * A camp's 種族天賦 (shared/src/world/talents.ts), as its world_players row keeps them: talent id → ranks. A camp that never
 * opened the big world has none. The camp's code reads its own tree's effects here too (talentBonus(...).campYield…).
 */
export async function talentsOf(tx: Tx, userId: string): Promise<TalentPicks> {
  // (read once a transaction: a battle asks for the same camp's talents several times)
  const seen = known.get(tx) ?? new Map<string, TalentPicks>();
  known.set(tx, seen);
  const hit = seen.get(userId);
  if (hit) return hit;
  const [row] = await tx.select({ talents: worldPlayers.talents }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  const picks = row?.talents ?? {};
  seen.set(userId, picks);
  return picks;
}

/** The talents read in each transaction (gone with it). */
const known = new WeakMap<Tx, Map<string, TalentPicks>>();

/** A camp's talents changed in this transaction (bought, reset): read them afresh. */
export function forgetTalents(tx: Tx, userId: string): void {
  known.get(tx)?.delete(userId);
}

/** A camp's talents added up by effect (a missing effect: 0). */
export async function talentBonusOf(tx: Tx, userId: string): Promise<Record<TalentEffect, number>> {
  return talentBonus(await talentsOf(tx, userId));
}

/** One effect of a camp's talents (0 when it has none). */
export const talentEffect = (bonus: Partial<Record<TalentEffect, number>>, effect: TalentEffect) => bonus[effect] ?? 0;
