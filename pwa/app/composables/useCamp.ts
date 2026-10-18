import { get, set } from "idb-keyval";
import type { CampView, RaidReport } from "@goblincamp/shared/camp";
import { ApiError, api } from "~/utils/api";

/**
 * The account's camp as the server keeps it, to look at (the camp is played on the Mac; the phone only turns 聖光模式 and
 * builds the camp's sites).
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

/** When the whole list of residents last came: in between, only the residents that changed are asked for (a big camp's whole
 * list is megabytes); every half hour the whole list again, so a change ever missed is put right. */
let wholeAt = 0;

/** The camp with the whole list of residents: `fresh` itself, or (a part) the held list with the changes put in; null when a
 * part came with nothing to put it in. */
function merged(fresh: CampView, held: CampView | undefined): CampView | null {
  if (!fresh.partial) {
    wholeAt = Date.now();
    return fresh;
  }
  if (!held || held.startedAt !== fresh.startedAt) return null;
  const changed = new Set(fresh.residents.map((r) => r.id));
  const gone = new Set(fresh.residentsGone ?? []);
  const residents = [...held.residents.filter((r) => !changed.has(r.id) && !gone.has(r.id)), ...fresh.residents].sort((a, b) => a.id - b.id);
  const { partial: _p, residentsGone: _g, ...rest } = fresh;
  return { ...rest, residents };
}

async function fetchCamp(): Promise<CampView> {
  const held = state.saved?.userId === userId ? state.saved.view : undefined;
  const asked =
    held?.residentsSeq && Date.now() - wholeAt < 30 * 60_000
      ? `camp?residentsSince=${held.residentsSeq}&startedAt=${encodeURIComponent(held.startedAt)}`
      : "camp";
  const view = merged(await api<CampView>("GET", asked), held);
  if (view) return view;
  wholeAt = 0;
  return api<CampView>("GET", "camp");
}

async function fetchNow() {
  if (running) return running;
  running = (async () => {
    try {
      const [view, { raids }] = await Promise.all([fetchCamp(), api<{ raids: RaidReport[] }>("GET", "camp/raids?limit=10")]);
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

/** Asks again only when the camp is newer than the one shown (the whole camp is a big answer; this page's own changes come back in their answers). */
const onChanged = (e: Event) => {
  const version = (e as CustomEvent<{ version?: number }>).detail?.version;
  if (version !== undefined && state.saved && version <= state.saved.view.version) return;
  void fetchNow();
};
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
