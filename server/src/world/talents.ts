import { eq } from "drizzle-orm";
import { talentBonus, type TalentEffect, type TalentPicks } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { worldPlayers } from "../db/schema.ts";

/**
 * A camp's 種族天賦 (shared/src/world/talents.ts), as its world_players row keeps them: talent id → ranks. A camp that never
 * opened the big world has none. The camp's code reads its own tree's effects here too (talentBonus(...).campYield…).
 */
export async function talentsOf(tx: Tx, userId: string): Promise<TalentPicks> {
  const [row] = await tx.select({ talents: worldPlayers.talents }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  return row?.talents ?? {};
}

/** A camp's talents added up by effect (a missing effect: 0). */
export async function talentBonusOf(tx: Tx, userId: string): Promise<Record<TalentEffect, number>> {
  return talentBonus(await talentsOf(tx, userId));
}

/** One effect of a camp's talents (0 when it has none). */
export const talentEffect = (bonus: Partial<Record<TalentEffect, number>>, effect: TalentEffect) => bonus[effect] ?? 0;
