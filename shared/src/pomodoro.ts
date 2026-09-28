/**
 * The pomodoro timer one account shares between its Mac and its phone (server/DESIGN.md §14). The server keeps one state;
 * every device works out where it is now from it with the same rules (the order of the parts is the Mac's Pomodoro.swift:
 * focus, rest, focus, rest… and after the last focus a long rest when there are several rounds and one is set, else the
 * usual rest, else the end).
 */
import { z } from "zod";

export const pomodoroPlanSchema = z.object({
  focusMinutes: z.number().min(1).max(180),
  restMinutes: z.number().min(0).max(60),
  rounds: z.number().int().min(1).max(12),
  longRestMinutes: z.number().min(0).max(90),
});
export type PomodoroPlan = z.infer<typeof pomodoroPlanSchema>;

/** The usual one: 25 minutes, 5 of rest, four rounds, a long rest of 15. */
export const DEFAULT_POMODORO: PomodoroPlan = { focusMinutes: 25, restMinutes: 5, rounds: 4, longRestMinutes: 15 };

export type PomodoroPhase = "focus" | "rest" | "longRest";
export interface PomodoroSegment {
  phase: PomodoroPhase;
  /** 1-based. */
  round: number;
  seconds: number;
}

/** Every part of a run, in order. */
export function pomodoroSegments(plan: PomodoroPlan): PomodoroSegment[] {
  const out: PomodoroSegment[] = [];
  const focus = plan.focusMinutes * 60, rest = plan.restMinutes * 60, longRest = plan.longRestMinutes * 60;
  for (let round = 1; round <= plan.rounds; round++) {
    out.push({ phase: "focus", round, seconds: focus });
    if (round < plan.rounds) {
      if (rest > 0) out.push({ phase: "rest", round, seconds: rest });
    } else if (plan.rounds > 1 && longRest > 0) {
      out.push({ phase: "longRest", round, seconds: longRest });
    } else if (rest > 0) {
      out.push({ phase: "rest", round, seconds: rest });
    }
  }
  return out;
}

/** What the server keeps (times in ms since 1970). */
export interface PomodoroState {
  plan: PomodoroPlan;
  /** Which part (pomodoroSegments) it is in. */
  index: number;
  /** When the part ends, while running; null while paused. */
  endsAt: number | null;
  /** What was left of the part when it was paused; null while running. */
  pausedLeft: number | null;
  startedAt: number;
  /** Which kind of device made the last change ("mac" or "phone"). */
  by: "mac" | "phone";
  /** Goes up with every change (devices ignore what they already have). */
  version: number;
}

export interface PomodoroNow {
  /** The state moved on to `now` (null: the run is over). */
  state: PomodoroState | null;
  /** Parts that began between the state given and `now` (their index, and when), for telling people. */
  began: { index: number; at: number }[];
  /** It ended between the state given and `now`, at this time. */
  endedAt: number | null;
}

/** Moves a state on to `now`: the parts whose time is up are over. */
export function pomodoroAt(state: PomodoroState | null, now: number): PomodoroNow {
  if (!state) return { state: null, began: [], endedAt: null };
  const segments = pomodoroSegments(state.plan);
  const s = { ...state };
  const began: { index: number; at: number }[] = [];
  while (s.endsAt !== null && now >= s.endsAt) {
    const at = s.endsAt;
    s.index += 1;
    if (s.index >= segments.length) return { state: null, began, endedAt: at };
    s.endsAt = at + segments[s.index]!.seconds * 1000;
    began.push({ index: s.index, at });
  }
  return { state: s, began, endedAt: null };
}

export const pomodoroActionInput = z.discriminatedUnion("action", [
  z.object({ action: z.literal("start"), plan: pomodoroPlanSchema }),
  z.object({ action: z.enum(["pause", "resume", "skip", "stop"]) }),
]);
export type PomodoroAction = z.infer<typeof pomodoroActionInput>;

/** What an action does to the state (null: no run). Pausing a paused run, and the like, change nothing. */
export function pomodoroApply(current: PomodoroState | null, action: PomodoroAction, now: number, by: "mac" | "phone"): PomodoroState | null {
  const version = (current?.version ?? 0) + 1;
  if (action.action === "start") {
    const first = pomodoroSegments(action.plan)[0]!;
    return { plan: action.plan, index: 0, endsAt: now + first.seconds * 1000, pausedLeft: null, startedAt: now, by, version };
  }
  const moved = pomodoroAt(current, now).state;
  if (!moved) return null;
  switch (action.action) {
    case "stop":
      return null;
    case "pause":
      return moved.endsAt === null ? moved : { ...moved, endsAt: null, pausedLeft: Math.max(0, moved.endsAt - now), by, version };
    case "resume":
      return moved.pausedLeft === null ? moved : { ...moved, endsAt: now + moved.pausedLeft, pausedLeft: null, by, version };
    case "skip": {
      // on to the next part, running (the last part skipped: the run is over)
      const segments = pomodoroSegments(moved.plan);
      const index = moved.index + 1;
      if (index >= segments.length) return null;
      return { ...moved, index, endsAt: now + segments[index]!.seconds * 1000, pausedLeft: null, by, version };
    }
  }
}

/** `GET /api/pomodoro` and every change: the run (null: none) and the server's clock, so a device with a wrong clock still counts right. */
export interface PomodoroResponse {
  state: PomodoroState | null;
  serverTime: number;
}

/** Words for a part, e.g. 「專注 2/4」「休息」「長休息」. */
export function pomodoroPartName(segment: PomodoroSegment, rounds: number): string {
  if (segment.phase === "focus") return rounds > 1 ? `專注 ${segment.round}/${rounds}` : "專注";
  return segment.phase === "longRest" ? "長休息" : "休息";
}
