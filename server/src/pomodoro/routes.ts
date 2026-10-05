import { Hono } from "hono";
import { eq } from "drizzle-orm";
import {
  pomodoroActionInput,
  pomodoroApply,
  pomodoroAt,
  pomodoroPartName,
  pomodoroSegments,
  type PomodoroResponse,
  type PomodoroState,
  type SocialPush,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { readJson } from "../http.ts";
import { pushToPhones } from "../push/phones.ts";
import { pomodoros } from "../db/schema.ts";
import { focusPartsDone, recordFocus } from "../camp/focus.ts";

type Db = AppDeps["database"]["db"];

/** The run as it is now (a run whose time is up is gone). */
async function current(db: Db, userId: string, now: Date): Promise<PomodoroState | null> {
  const [row] = await db.select().from(pomodoros).where(eq(pomodoros.userId, userId));
  return pomodoroAt(row?.state ?? null, now.getTime()).state;
}

/** 番茄鐘 shared by an account's Mac and phones (server/DESIGN.md §14). */
export function pomodoroRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  app.get("/", async (c) => {
    const at = now();
    const body: PomodoroResponse = { state: await current(db, c.get("session").user.id, at), serverTime: at.getTime() };
    return c.json(body);
  });

  /** start (with a plan), pause, resume, skip, stop: from whichever device; the others hear of it at once. */
  app.post("/", async (c) => {
    const body = await readJson(c, pomodoroActionInput);
    if ("response" in body) return body.response;
    const session = c.get("session");
    const userId = session.user.id;
    const at = now();
    const next = await db.transaction(async (tx) => {
      const [row] = await tx.select().from(pomodoros).where(eq(pomodoros.userId, userId)).for("update");
      const moved = pomodoroAt(row?.state ?? null, at.getTime());
      const before = moved.state;
      // (focus parts that ended by themselves before this action: the camp counts them, shared/src/camp/focus.ts)
      const campVersion = row ? await recordFocus(tx, userId, focusPartsDone(row.state, moved.began, moved.endedAt)) : null;
      const after = pomodoroApply(before, body.data, at.getTime(), session.viaCookie ? "phone" : "mac");
      if (!after) {
        if (row) await tx.delete(pomodoros).where(eq(pomodoros.userId, userId));
        return { state: null, version: (before?.version ?? row?.state.version ?? 0) + 1, campVersion };
      }
      if (after !== before) {
        // (the part it is in now has been told: pushes are for the parts that begin from here on)
        await tx
          .insert(pomodoros)
          .values({ userId, state: after, toldIndex: after.index, updatedAt: at })
          .onConflictDoUpdate({ target: pomodoros.userId, set: { state: after, toldIndex: after.index, updatedAt: at } });
      }
      return { state: after, version: after.version, campVersion };
    });
    deps.hub.notify(userId, { type: "pomodoro.changed", version: next.version });
    if (next.campVersion !== null) deps.hub.notify(userId, { type: "camp.changed", version: next.campVersion });
    const out: PomodoroResponse = { state: next.state, serverTime: at.getTime() };
    return c.json(out);
  });

  return app;
}

/**
 * Tells the phones when a part begins or the run ends (a phone's page cannot count while it is closed), and the devices
 * over the WebSocket. Returns how many runs moved on.
 */
export async function tellPomodoros(deps: Pick<AppDeps, "database" | "push" | "hub">, now: Date): Promise<number> {
  const { db } = deps.database;
  const rows = await db.select().from(pomodoros);
  let moved = 0;
  for (const seen of rows) {
    const glance = pomodoroAt(seen.state, now.getTime());
    if (glance.began.length === 0 && glance.endedAt === null) continue;
    // (again under a lock: a device's action may have moved the run on meanwhile, and its focus parts must be counted once)
    const out = await db.transaction(async (tx) => {
      const [row] = await tx.select().from(pomodoros).where(eq(pomodoros.userId, seen.userId)).for("update");
      if (!row) return null;
      const { state, began, endedAt } = pomodoroAt(row.state, now.getTime());
      if (began.length === 0 && endedAt === null) return null;
      const campVersion = await recordFocus(tx, row.userId, focusPartsDone(row.state, began, endedAt));
      if (endedAt !== null) await tx.delete(pomodoros).where(eq(pomodoros.userId, row.userId));
      else if (state) await tx.update(pomodoros).set({ state, toldIndex: state.index, updatedAt: now }).where(eq(pomodoros.userId, row.userId));
      return { row, state, endedAt, campVersion };
    });
    if (!out) continue;
    const { row, state, endedAt, campVersion } = out;
    moved++;
    const segments = pomodoroSegments(row.state.plan);
    let push: SocialPush | null = null;
    if (endedAt !== null) {
      push = { type: "social", title: "🍅 番茄鐘結束了", body: "這一組都做完了，辛苦了！", url: "/pomodoro", tag: "pomodoro" };
    } else if (state) {
      const part = segments[state.index]!;
      const minutes = Math.round(part.seconds / 60);
      push =
        part.phase === "focus"
          ? { type: "social", title: "🍅 休息結束", body: `${pomodoroPartName(part, row.state.plan.rounds)}開始，${minutes} 分鐘`, url: "/pomodoro", tag: "pomodoro" }
          : { type: "social", title: "🍅 專注時間到了", body: `${part.phase === "longRest" ? "長休息" : "休息"} ${minutes} 分鐘，起來動一動`, url: "/pomodoro", tag: "pomodoro" };
    }
    deps.hub.notify(row.userId, { type: "pomodoro.changed", version: state?.version ?? row.state.version });
    if (campVersion !== null) deps.hub.notify(row.userId, { type: "camp.changed", version: campVersion });
    if (push) await pushToPhones(deps, row.userId, push);
  }
  return moved;
}

/** Runs `tellPomodoros` every 5 seconds; returns a function that stops it. */
export function startPomodoroLoop(deps: Pick<AppDeps, "database" | "push" | "hub">, everyMs = 5_000): () => void {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      await tellPomodoros(deps, new Date());
    } catch (err) {
      console.error("pomodoro:", err);
    } finally {
      running = false;
    }
  }, everyMs);
  return () => clearInterval(timer);
}
