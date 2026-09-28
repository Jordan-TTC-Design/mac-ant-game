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
async function loadCells(center = state.center) {
  if (!center) return;
  state.center = center;
  state.cells = await api<CellView[]>("GET", `world/cells?lat=${center.lat.toFixed(6)}&lng=${center.lng.toFixed(6)}&radius=1800`);
}
/** The next refresh puts the map back on the camp (opening the page starts there, not where it was dragged last time). */
let backHome = true;
async function refresh() {
  state.loading = true;
  try {
    await loadMe();
    // (no camp in the world yet: start looking from 大安森林公園)
    if (backHome && state.me?.home) state.center = state.me.home;
    else if (!state.center) state.center = state.me?.home ?? { lat: 25.0302, lng: 121.5357 };
    backHome = false;
    await loadCells();
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
    moveTo: (center: { lat: number; lng: number }) => loadCells(center).catch(() => {}),
    /** The first time: where the camp stands (nobody is sent; the whole camp is there). */
    openWorld: (cell?: string) => act(() => api("POST", "world/open", cell ? { cell } : {})),
    /** The camp moves to another cell (once a week). */
    moveHome: (cell: string) => act(() => api("POST", `world/cells/${cell}/home`, {})),
    /** A party: named residents, or a count (the server picks the strongest). */
    send: (to: string, party: number | number[], settle: boolean, from = "home", supplies: Record<string, number> = {}) =>
      act(() =>
        api<ExpeditionSummary>("POST", "world/expeditions", {
          from,
          to,
          settle,
          ...(Array.isArray(party) ? { residents: party } : { count: party }),
          ...(Object.values(supplies).some((n) => n > 0) ? { supplies } : {}),
        }),
      ),
    nest: (cell: string) => act(() => api("POST", `world/cells/${cell}/nest`)),
    town: (cell: string) => act(() => api("POST", `world/cells/${cell}/town`)),
    recall: (cell: string) => act(() => api("POST", `world/cells/${cell}/recall`, {})),
  };
}
