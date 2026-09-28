import { describe, expect, it } from "vitest";
import { pomodoroApply, pomodoroAt, pomodoroSegments, type PomodoroPlan } from "./pomodoro.ts";

const MIN = 60_000;
const plan: PomodoroPlan = { focusMinutes: 25, restMinutes: 5, rounds: 3, longRestMinutes: 15 };

describe("pomodoro", () => {
  it("orders the parts like the Mac: focus, rest… and a long rest after the last focus", () => {
    expect(pomodoroSegments(plan).map((s) => `${s.phase}${s.round}`)).toEqual(["focus1", "rest1", "focus2", "rest2", "focus3", "longRest3"]);
    expect(pomodoroSegments({ ...plan, rounds: 1 }).map((s) => s.phase)).toEqual(["focus", "rest"]);
    expect(pomodoroSegments({ ...plan, rounds: 2, restMinutes: 0, longRestMinutes: 0 }).map((s) => s.phase)).toEqual(["focus", "focus"]);
  });

  it("moves on with the clock, and ends", () => {
    const start = pomodoroApply(null, { action: "start", plan }, 0, "phone")!;
    expect(start.endsAt).toBe(25 * MIN);
    const later = pomodoroAt(start, 31 * MIN);
    expect(later.state!.index).toBe(2); // (rest 1 is over too: focus 2)
    expect(later.began.map((b) => b.index)).toEqual([1, 2]);
    expect(later.state!.endsAt).toBe(55 * MIN);
    const total = (25 * 3 + 5 * 2 + 15) * MIN;
    const end = pomodoroAt(start, total + 1);
    expect(end.state).toBeNull();
    expect(end.endedAt).toBe(total);
  });

  it("pauses, resumes, skips and stops", () => {
    const start = pomodoroApply(null, { action: "start", plan }, 0, "mac")!;
    const paused = pomodoroApply(start, { action: "pause" }, 10 * MIN, "phone")!;
    expect(paused.pausedLeft).toBe(15 * MIN);
    expect(pomodoroAt(paused, 999 * MIN).state).toEqual(paused); // (paused: time does not pass)
    const resumed = pomodoroApply(paused, { action: "resume" }, 100 * MIN, "mac")!;
    expect(resumed.endsAt).toBe(115 * MIN);
    const skipped = pomodoroApply(resumed, { action: "skip" }, 101 * MIN, "mac")!;
    expect(skipped.index).toBe(1);
    expect(skipped.endsAt).toBe(106 * MIN);
    expect(skipped.version).toBe(start.version + 3);
    expect(pomodoroApply(skipped, { action: "stop" }, 102 * MIN, "phone")).toBeNull();
  });
});
