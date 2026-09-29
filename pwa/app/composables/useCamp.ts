import { get, set } from "idb-keyval";
import type { CampView, RaidReport } from "@goblincamp/shared/camp";
import { ApiError, api } from "~/utils/api";

/**
 * The account's camp as the server keeps it, to look at (the camp is played on the Mac; the phone only turns 聖光模式 and
 * raises the farm).
 * Fetched when the page opens, when the server says the camp changed (over the notes' WebSocket), and every minute while
 * the page is in sight (births come every few minutes and asking works them out). The last one is kept for offline.
 */
interface Saved {
  userId: string;
  view: CampView;
  raids: RaidReport[];
  fetchedAt: number;
}
export type CampStatus = "loading" | "ok" | "offline" | "none" | "problem";

const KEY = "gc-camp-v1";
const state = reactive<{ saved: Saved | null; status: CampStatus; problem: string }>({ saved: null, status: "loading", problem: "" });
let userId = "";
let timer: ReturnType<typeof setInterval> | undefined;
let running: Promise<void> | null = null;

async function fetchNow() {
  if (running) return running;
  running = (async () => {
    try {
      const [view, { raids }] = await Promise.all([api<CampView>("GET", "camp"), api<{ raids: RaidReport[] }>("GET", "camp/raids?limit=10")]);
      state.saved = { userId, view, raids, fetchedAt: Date.now() };
      useRace().set(view.race);
      state.status = "ok";
      void set(KEY, JSON.parse(JSON.stringify(state.saved)));
    } catch (e) {
      if (e instanceof ApiError && e.status === 404) {
        state.saved = null;
        state.status = "none";
      } else if (e instanceof ApiError && e.offline) {
        state.status = "offline";
      } else {
        state.status = "problem";
        state.problem = e instanceof Error ? e.message : String(e);
      }
    } finally {
      running = null;
    }
  })();
  return running;
}

const onChanged = () => void fetchNow();
const onVisible = () => {
  if (document.visibilityState === "visible") void fetchNow();
};

export function useCamp() {
  /** Shows what was kept at once, then asks the server; keeps asking while the page is open. */
  async function open(forUser: string) {
    if (userId !== forUser) {
      userId = forUser;
      const kept = (await get<Saved>(KEY)) ?? null;
      state.saved = kept && kept.userId === forUser ? kept : null;
      state.status = "loading";
    }
    window.addEventListener("gc:camp-changed", onChanged);
    document.addEventListener("visibilitychange", onVisible);
    clearInterval(timer);
    timer = setInterval(() => {
      if (document.visibilityState === "visible") void fetchNow();
    }, 60_000);
    await fetchNow();
  }

  function close() {
    window.removeEventListener("gc:camp-changed", onChanged);
    document.removeEventListener("visibilitychange", onVisible);
    clearInterval(timer);
  }

  return { state, open, close, refresh: fetchNow };
}
