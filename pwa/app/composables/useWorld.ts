import type { CellView, ExpeditionSummary, WorldMe } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

/**
 * The big world as this account sees it (server/WORLD.md §15): its standing, the map around a point, and what it does
 * there. The server fights and keeps the books; this only asks and shows. Refreshed when the camp changes (a party
 * arriving, someone attacking) and every 20 seconds while a party is on the road.
 */
const state = reactive<{ me: WorldMe | null; cells: CellView[]; center: { lat: number; lng: number } | null; loading: boolean; problem: string }>({
  me: null,
  cells: [],
  center: null,
  loading: false,
  problem: "",
});
let timer: ReturnType<typeof setInterval> | undefined;

async function loadMe() {
  state.me = await api<WorldMe>("GET", "world");
}
/** How far round a point one look at the map fetches, and how far the view may move from it before another is needed. */
const FETCH_RADIUS = 1800;
const STILL_COVERED = 900;
/** The last look at the map: where, and when (a fresh one close by needs no other). */
let fetched: { at: number; center: { lat: number; lng: number } } | null = null;
const metersApart = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => Math.hypot((a.lat - b.lat) * 110_574, (a.lng - b.lng) * 111_320 * Math.cos((a.lat * Math.PI) / 180));

/**
 * The map round `center`: fetched, and laid over what is already there (the map never goes blank while the new comes),
 * keeping only what is near enough to be seen again. Unless `fresh`, a recent look close by covers it: nothing is fetched.
 */
async function loadCells(center = state.center, fresh = true) {
  if (!center) return;
  state.center = center;
  if (!fresh && fetched && Date.now() - fetched.at < 60_000 && metersApart(fetched.center, center) < STILL_COVERED) return;
  const got = await api<CellView[]>("GET", `world/cells?lat=${center.lat.toFixed(6)}&lng=${center.lng.toFixed(6)}&radius=${FETCH_RADIUS}`);
  fetched = { at: Date.now(), center };
  const byCell = new Map(state.cells.filter((c) => metersApart(c, center) < FETCH_RADIUS + STILL_COVERED).map((c) => [c.cell, c]));
  for (const c of got) byCell.set(c.cell, c);
  state.cells = [...byCell.values()];
}
/** The next refresh puts the map back on the camp (opening the page starts there, not where it was dragged last time). */
let backHome = true;
async function refresh() {
  state.loading = true;
  try {
    if (!backHome && state.center) {
      await Promise.all([loadMe(), loadCells()]); // (the map stays where it is: both at once)
    } else {
      await loadMe();
      // (no camp in the world yet: start looking from 大安森林公園)
      if (backHome && state.me?.home) state.center = state.me.home;
      else if (!state.center) state.center = state.me?.home ?? { lat: 25.0302, lng: 121.5357 };
      backHome = false;
      await loadCells();
    }
    state.problem = "";
  } catch (e) {
    state.problem = e instanceof ApiError ? e.message : String(e);
  } finally {
    state.loading = false;
  }
}
const onChanged = () => void refresh();

/** Does something and shows the new standing; an error comes back as its sentence. */
async function act(work: () => Promise<unknown>): Promise<string | null> {
  try {
    await work();
    await refresh();
    return null;
  } catch (e) {
    return e instanceof ApiError ? e.message : String(e);
  }
}

export function useWorld() {
  function open() {
    backHome = true;
    window.addEventListener("gc:camp-changed", onChanged);
    clearInterval(timer);
    timer = setInterval(() => {
      if (document.visibilityState === "visible" && state.me?.walking.length) void refresh();
    }, 20_000);
    return refresh();
  }
  function close() {
    window.removeEventListener("gc:camp-changed", onChanged);
    clearInterval(timer);
  }
  return {
    state,
    open,
    close,
    refresh,
    /** The map was dragged (or sent) to `center`: fetched only when it has gone past what was looked at lately. */
    moveTo: (center: { lat: number; lng: number }) => loadCells(center, false).catch(() => {}),
    /** The first time: where the camp stands (nobody is sent; the whole camp is there). */
    openWorld: (cell?: string) => act(() => api("POST", "world/open", cell ? { cell } : {})),
    /** The camp moves to another cell (once a week). */
    moveHome: (cell: string) => act(() => api("POST", `world/cells/${cell}/home`, {})),
    /** A party: named residents, or a count (the server picks the strongest). */
    send: (to: string, party: number | number[], settle: boolean, from = "home", supplies: Record<string, number> = {}, guard = false, plunder = false) =>
      act(() =>
        api<ExpeditionSummary>("POST", "world/expeditions", {
          from,
          to,
          settle,
          ...(guard ? { guard: true } : {}),
          ...(plunder ? { plunder: true } : {}),
          ...(Array.isArray(party) ? { residents: party } : { count: party }),
          ...(Object.values(supplies).some((n) => n > 0) ? { supplies } : {}),
        }),
      ),
    nest: (cell: string) => act(() => api("POST", `world/cells/${cell}/nest`)),
    town: (cell: string) => act(() => api("POST", `world/cells/${cell}/town`)),
    recall: (cell: string) => act(() => api("POST", `world/cells/${cell}/recall`, {})),
    /** Guests walk home: your own from a friend's cell, or (the holder) every friend's from yours. */
    unguard: (cell: string) => act(() => api("POST", `world/cells/${cell}/unguard`, {})),
  };
}
