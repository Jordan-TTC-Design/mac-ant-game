/**
 * The camps' material flows for the economy dashboard (shared/src/camp/economy.ts): every change to a camp's materials is
 * written down as a "flow" event — where it came from or went, and how much of what. Not shown in the camp's feed.
 */
import { materialDelta } from "@goblincamp/shared/camp";
import type { Tx } from "../auth/session.ts";
import { addEvent } from "./service.ts";

/** Writes down what `source` added (positive) or took (negative); nothing when nothing moved. */
export async function recordFlow(tx: Tx, userId: string, at: Date, source: string, delta: Record<string, number>): Promise<void> {
  const moved = Object.fromEntries(Object.entries(delta).filter(([, n]) => n && Number.isFinite(n)));
  if (Object.keys(moved).length) await addEvent(tx, userId, at, "flow", { source, delta: moved });
}

/** The same, from the materials before and after. */
export async function recordChange(tx: Tx, userId: string, at: Date, source: string, before: Record<string, number>, after: Record<string, number>): Promise<void> {
  await recordFlow(tx, userId, at, source, materialDelta(before, after));
}
