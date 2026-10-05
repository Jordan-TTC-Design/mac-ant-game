import { eq, sql } from "drizzle-orm";
import { addFocus, focusToday, type CampFocus } from "@goblincamp/shared/camp";
import { pomodoroSegments, type PomodoroState } from "@goblincamp/shared";
import type { Tx } from "../auth/session.ts";
import { camps } from "../db/schema.ts";
import { addEvent, lockCamp } from "./service.ts";

/** A focus part that ran to its end: when, and how long it was. */
export interface FocusDone {
  at: number;
  minutes: number;
}

/**
 * The focus parts of a run that ended by themselves while it moved on from `state` (what `pomodoroAt` reports: the parts
 * that `began`, each ending the one before it, and the run's end). A part skipped or stopped never gets here.
 */
export function focusPartsDone(state: PomodoroState, began: { index: number; at: number }[], endedAt: number | null): FocusDone[] {
  const parts = pomodoroSegments(state.plan);
  const done: FocusDone[] = [];
  for (const b of began) {
    const ended = parts[b.index - 1];
    if (ended?.phase === "focus") done.push({ at: b.at, minutes: ended.seconds / 60 });
  }
  const last = parts[parts.length - 1];
  if (endedAt !== null && last?.phase === "focus") done.push({ at: endedAt, minutes: last.seconds / 60 });
  return done;
}

/**
 * Puts focus parts done into the camp's books (shared/src/camp/focus.ts), one `focus` event each (with the day's count, for
 * the camp and the phone to tell). Returns the camp's new version, or null (no camp, or nothing done).
 */
export async function recordFocus(tx: Tx, userId: string, done: FocusDone[]): Promise<number | null> {
  if (done.length === 0) return null;
  const camp = await lockCamp(tx, userId);
  if (!camp) return null;
  let focus: CampFocus | null = camp.focus;
  for (const part of done) {
    const at = new Date(part.at);
    focus = addFocus(focus, at, part.minutes);
    await addEvent(tx, userId, at, "focus", { rounds: focusToday(focus, at), minutes: Math.round(part.minutes) });
  }
  const [row] = await tx.update(camps).set({ focus, version: sql`${camps.version} + 1` }).where(eq(camps.userId, userId)).returning({ version: camps.version });
  return row?.version ?? null;
}
