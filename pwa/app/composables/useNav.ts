import type { QuestView } from "@goblincamp/shared/camp";
import type { WorldMe } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

/**
 * The phone app's five big parts (pwa/UI.md §2) and what waits in each: which tab a page belongs to, the red dot on each
 * tab, and the "現在可以做" list on 今天 — gathered here from the camp, the big world, the quests, the notes and useLive.
 * The quests and the big world are asked for when the app comes into sight and every few minutes (light calls).
 */
export type TabId = "today" | "notes" | "camp" | "world" | "pals";

export const TABS: { id: TabId; to: string; label: string; icon: string }[] = [
  { id: "today", to: "/", label: "今天", icon: "🏠" },
  { id: "notes", to: "/notes", label: "便利貼", icon: "📝" },
  { id: "camp", to: "/camp", label: "營地", icon: "🛖" },
  { id: "world", to: "/world", label: "大世界", icon: "🗺️" },
  { id: "pals", to: "/friends", label: "夥伴", icon: "👥" },
];

/** The tab a page belongs to (null: none, e.g. signing in or 後台). */
export function tabOf(path: string): TabId | null {
  const p = path.replace(/\/$/, "") || "/";
  const under = (...roots: string[]) => roots.some((r) => p === r || p.startsWith(`${r}/`));
  if (under("/notes", "/note")) return "notes";
  if (under("/camp", "/workshop", "/roster", "/quests", "/feed")) return "camp";
  if (under("/world", "/territory", "/talents", "/expedition")) return "world";
  if (under("/friends", "/guild", "/leaderboard", "/avatar")) return "pals";
  if (p === "/" || under("/pomodoro", "/claude", "/settings", "/feedback")) return "today";
  return null;
}

/** Pages that fill the screen on their own: no tab bar (writing a note, a chat, the guild hall). */
export function fullScreen(path: string): boolean {
  return /^\/note\//.test(path) || /^\/friends\/[^/]+/.test(path) || path.startsWith("/guild/hall");
}

/** Where a tab lands: the page last seen in it (this session), so going back to a tab finds it as it was left. */
const lastIn = reactive<Partial<Record<TabId, string>>>({});

const state = reactive<{ quests: QuestView[] | null; world: WorldMe | null }>({ quests: null, world: null });
let started = false;
let timer: ReturnType<typeof setInterval> | undefined;

async function quietly<T>(work: () => Promise<T>): Promise<T | null> {
  try {
    return await work();
  } catch (e) {
    if (!(e instanceof ApiError)) console.warn(e);
    return null;
  }
}
async function loadQuests() {
  const out = await quietly(() => api<{ quests: QuestView[] }>("GET", "camp/quests"));
  if (out) state.quests = out.quests;
}
async function loadWorld() {
  const out = await quietly(() => api<WorldMe>("GET", "world"));
  if (out) state.world = out;
}
function refresh() {
  if (document.visibilityState !== "visible") return;
  void loadQuests();
  void loadWorld();
}

export function useNav() {
  const live = useLive();
  const camp = useCamp();
  const notes = useNotes();

  function start() {
    if (started) return;
    started = true;
    document.addEventListener("visibilitychange", refresh);
    timer = setInterval(refresh, 180_000);
    refresh();
  }
  function stop() {
    clearInterval(timer);
  }

  const view = computed(() => camp.state.saved?.view ?? null);
  const questsReady = computed(() => state.quests?.filter((q) => q.done && !q.claimed).length ?? 0);
  const visitor = computed(() => {
    const v = view.value?.visitor;
    return v && Date.parse(v.leaves) > Date.now() ? v : null;
  });
  const merchant = computed(() => {
    const m = view.value?.merchant;
    return m && Date.parse(m.leavesAt) > Date.now() ? m : null;
  });
  const incoming = computed(() => state.world?.incoming ?? []);
  const talentPoints = computed(() => {
    const t = state.world?.talents;
    return t ? Math.max(0, t.points - Object.values(t.picks).reduce((a, b) => a + b, 0)) : 0;
  });
  const overdue = computed(() => notes.list.value.filter((n) => n.kind !== "memo" && !n.done && n.dueAt && Date.parse(n.dueAt) < Date.now()).length);
  const unread = computed(() => live.state.friends?.friends.reduce((n, f) => n + f.unread, 0) ?? 0);
  const friendAsks = computed(() => live.state.friends?.incoming.length ?? 0);
  const guildInvites = computed(() => (live.state.guild && !live.state.guild.guild ? live.state.guild.invites.length : 0));

  /** The red dot on each tab: a number, or "!" for something that cannot wait. */
  const badges = computed<Partial<Record<TabId, number | "!">>>(() => ({
    today: live.state.claude?.waiting.length || 0,
    notes: overdue.value,
    camp: questsReady.value + (visitor.value ? 1 : 0),
    world: incoming.value.length ? "!" : talentPoints.value,
    pals: unread.value + friendAsks.value + guildInvites.value,
  }));

  return { state, start, stop, refresh, lastIn, badges, questsReady, visitor, merchant, incoming, talentPoints, overdue, unread, friendAsks, guildInvites, loadQuests, loadWorld };
}

/**
 * A dialog over the page: the tab bar and the pomodoro strip step aside while it is open. (On iPhone everything inside the
 * page's scroller stays under the tab bar whatever its z-index — the scroller is a layer of its own — so a sheet rising from
 * the bottom would have its last buttons hidden.) Counted, for a dialog opened over another.
 */
let modals = 0;
export function useModal(open: Ref<boolean> | (() => boolean) = () => true) {
  let mine = false;
  const set = (on: boolean) => {
    if (on === mine || typeof document === "undefined") return;
    mine = on;
    modals += on ? 1 : -1;
    document.documentElement.classList.toggle("modal-open", modals > 0);
  };
  watch(open, (on) => set(!!on), { immediate: true });
  onUnmounted(() => set(false));
}
