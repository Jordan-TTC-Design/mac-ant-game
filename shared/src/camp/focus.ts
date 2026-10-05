/**
 * Focus (server/CAMP.md §22): the pomodoro's focus parts that ran to the end (a skipped one does not count), from the Mac or
 * the phone, counted per day (Taipei). A day with more of them is a better day at the camp: the merchant comes once more,
 * the ranch breeds faster, and the merchant brings something rare. The server counts them as the parts end
 * (server/src/pomodoro/routes.ts); the camp's books keep the count.
 */
import { MERCHANT_VISITS_PER_DAY, taipeiDay } from "./merchant.ts";

/** Focus rounds in a day for each good thing (and what it does). */
export const FOCUS_MERCHANT_ROUNDS = 3; // the merchant comes once more that day
export const FOCUS_RANCH_ROUNDS = 4; // the ranch breeds this much faster that day
export const FOCUS_RANCH_SPEED = 1.5;
export const FOCUS_RARE_ROUNDS = 6; // the merchant's visits bring one rare thing
/** Days kept (for the phone's week, and a quest's "a day with…"). */
export const FOCUS_DAYS_KEPT = 14;

export interface FocusDay {
  rounds: number;
  minutes: number;
}

/** What the books keep. */
export interface CampFocus {
  /** yyyy-mm-dd (Taipei) → that day's. The last FOCUS_DAYS_KEPT days. */
  days: Record<string, FocusDay>;
  /** Since the camp began. */
  rounds: number;
  minutes: number;
  /** The most rounds in one day. */
  bestDay: number;
}

/** What the camp's view shows (CampView.focus). */
export interface FocusView {
  today: FocusDay;
  rounds: number;
  minutes: number;
  bestDay: number;
  /** Today's good things, as they are now. */
  perks: { merchant: boolean; ranch: boolean; rare: boolean };
  /** The next good thing today, and how many more rounds it takes (null: all of them already). */
  next: { perk: "merchant" | "ranch" | "rare"; rounds: number } | null;
}

/** One focus part done (at `at`, `minutes` long). */
export function addFocus(focus: CampFocus | null | undefined, at: Date, minutes: number): CampFocus {
  const day = taipeiDay(at);
  const days = { ...(focus?.days ?? {}) };
  const was = days[day] ?? { rounds: 0, minutes: 0 };
  days[day] = { rounds: was.rounds + 1, minutes: Math.round(was.minutes + minutes) };
  for (const old of Object.keys(days).sort().slice(0, -FOCUS_DAYS_KEPT)) delete days[old];
  return {
    days,
    rounds: (focus?.rounds ?? 0) + 1,
    minutes: Math.round((focus?.minutes ?? 0) + minutes),
    bestDay: Math.max(focus?.bestDay ?? 0, days[day].rounds),
  };
}

/** Rounds done today (Taipei). */
export function focusToday(focus: CampFocus | null | undefined, now: Date): number {
  return focus?.days[taipeiDay(now)]?.rounds ?? 0;
}

export function focusView(focus: CampFocus | null | undefined, now: Date): FocusView {
  const today = focus?.days[taipeiDay(now)] ?? { rounds: 0, minutes: 0 };
  const perks = { merchant: today.rounds >= FOCUS_MERCHANT_ROUNDS, ranch: today.rounds >= FOCUS_RANCH_ROUNDS, rare: today.rounds >= FOCUS_RARE_ROUNDS };
  const steps = [
    { perk: "merchant" as const, at: FOCUS_MERCHANT_ROUNDS },
    { perk: "ranch" as const, at: FOCUS_RANCH_ROUNDS },
    { perk: "rare" as const, at: FOCUS_RARE_ROUNDS },
  ];
  const next = steps.find((s) => today.rounds < s.at);
  return {
    today,
    rounds: focus?.rounds ?? 0,
    minutes: focus?.minutes ?? 0,
    bestDay: focus?.bestDay ?? 0,
    perks,
    next: next ? { perk: next.perk, rounds: next.at - today.rounds } : null,
  };
}

/** A line for the camp when a round is done: what it brought, or how far the next good thing is. */
export function focusLine(rounds: number): string {
  if (rounds === FOCUS_MERCHANT_ROUNDS) return `今天專注第 ${rounds} 輪！商人聽說了，等一下會來一趟。`;
  if (rounds === FOCUS_RANCH_ROUNDS) return `今天專注第 ${rounds} 輪！牧場今天生得比較快。`;
  if (rounds === FOCUS_RARE_ROUNDS) return `今天專注第 ${rounds} 輪！商人今天會帶稀有的東西來。`;
  const next = [FOCUS_MERCHANT_ROUNDS, FOCUS_RANCH_ROUNDS, FOCUS_RARE_ROUNDS].find((n) => n > rounds);
  return next ? `今天專注第 ${rounds} 輪，再 ${next - rounds} 輪營地有好事。` : `今天專注第 ${rounds} 輪，辛苦了！`;
}

/** The merchant's visits allowed today: the usual, and one more after FOCUS_MERCHANT_ROUNDS. */
export function merchantVisitsToday(focus: CampFocus | null | undefined, now: Date): number {
  return MERCHANT_VISITS_PER_DAY + (focusToday(focus, now) >= FOCUS_MERCHANT_ROUNDS ? 1 : 0);
}
