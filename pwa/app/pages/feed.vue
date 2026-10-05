<script setup lang="ts">
import { FOCUS_MERCHANT_ROUNDS, FOCUS_RANCH_ROUNDS, FOCUS_RARE_ROUNDS, type FeedEntry, type FeedResponse } from "@goblincamp/shared/camp";
import { materialName } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 動態: what happened at the camp, newest first (shared/src/camp/feed.ts), and today at a glance (focus, the merchant).
// On the phone it is a page of the camp; in the Mac's main window, a page of its own.
const ok = await useSignedIn();
const mac = inMacApp();
const { user } = useAccount();
const camp = useCamp();
const view = computed(() => camp.state.saved?.view ?? null);
const entries = ref<FeedEntry[] | null>(null);
const more = ref(false);
const problem = ref("");
const loadingMore = ref(false);

async function load() {
  try {
    const res = await api<FeedResponse>("GET", "camp/feed?limit=40");
    entries.value = res.entries;
    more.value = res.more;
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
async function loadMore() {
  const last = entries.value?.at(-1);
  if (!last) return;
  loadingMore.value = true;
  try {
    const res = await api<FeedResponse>("GET", `camp/feed?limit=40&before=${last.seq}`);
    entries.value = [...(entries.value ?? []), ...res.entries];
    more.value = res.more;
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    loadingMore.value = false;
  }
}
const onChanged = () => void load();
onMounted(() => {
  window.addEventListener("gc:camp-changed", onChanged);
  void load();
});
onUnmounted(() => {
  window.removeEventListener("gc:camp-changed", onChanged);
  camp.close();
});
if (ok && user.value) void camp.open(user.value.id);

const SORTS: { id: FeedEntry["sort"] | ""; name: string }[] = [
  { id: "", name: "全部" },
  { id: "focus", name: "🍅 專注" },
  { id: "merchant", name: "🛒 商人" },
  { id: "ranch", name: "🐑 牧場" },
  { id: "raid", name: "⚔️ 魔獸" },
  { id: "quest", name: "🎁 任務" },
  { id: "camp", name: "🏕️ 營地" },
  { id: "world", name: "🌍 大世界" },
];
const sort = ref<FeedEntry["sort"] | "">("");
/** By day (today, yesterday, then the date), newest first. */
const days = computed(() => {
  const out: { day: string; entries: FeedEntry[] }[] = [];
  for (const e of entries.value ?? []) {
    if (sort.value && e.sort !== sort.value) continue;
    const day = dayName(e.at);
    if (out.at(-1)?.day !== day) out.push({ day, entries: [] });
    out.at(-1)!.entries.push(e);
  }
  return out;
});
function dayName(iso: string): string {
  const d = new Date(iso), now = new Date();
  const start = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
  const ago = Math.round((start(now) - start(d)) / 86_400_000);
  return ago === 0 ? "今天" : ago === 1 ? "昨天" : `${d.getMonth() + 1} 月 ${d.getDate()} 日`;
}
const clock = (iso: string) => new Date(iso).toLocaleTimeString("zh-TW", { hour: "2-digit", minute: "2-digit", hour12: false });

// today at a glance
const focus = computed(() => view.value?.focus ?? null);
const STEPS = [
  { at: FOCUS_MERCHANT_ROUNDS, text: "商人多來一次" },
  { at: FOCUS_RANCH_ROUNDS, text: "牧場生得快" },
  { at: FOCUS_RARE_ROUNDS, text: "商人帶稀有貨" },
];
const merchant = computed(() => {
  const m = view.value?.merchant;
  return m && Date.parse(m.leavesAt) > Date.now() ? m : null;
});
const swap = (items: Record<string, number>) => Object.entries(items).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");
</script>

<template>
  <main v-if="ok" class="page feed">
    <header class="topbar">
      <NuxtLink v-if="!mac" to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1">
        <h1>動態</h1>
        <div class="sub">營地發生的事，最新的在最上面</div>
      </div>
    </header>

    <aside class="today">
      <section class="panel">
        <h2>今天的專注</h2>
        <p v-if="!focus" class="muted">讀取中…</p>
        <template v-else>
          <p class="big">🍅 {{ focus.today.rounds }} 輪<small>・{{ focus.today.minutes }} 分鐘</small></p>
          <ol class="steps">
            <li v-for="s in STEPS" :key="s.at" :class="{ done: focus.today.rounds >= s.at }">
              <span>{{ focus.today.rounds >= s.at ? "✅" : `${s.at} 輪` }}</span>{{ s.text }}
            </li>
          </ol>
          <p class="muted small">一共 {{ focus.rounds }} 輪・最多一天 {{ focus.bestDay }} 輪。用 Mac 或手機的番茄鐘專注完一輪就算（跳過的不算）。</p>
        </template>
      </section>
      <section v-if="merchant" class="panel">
        <h2>🛒 {{ merchant.merchant }}在營地</h2>
        <p class="muted small">{{ clock(merchant.leavesAt) }} 離開・在 Mac 的營地點牠就能交易</p>
        <ul class="stock">
          <li v-for="(o, k) in merchant.stock" :key="k" :class="{ bought: merchant.bought.includes(k), rare: o.rare }">
            <b v-if="o.rare">稀有</b><b v-else-if="o.sale">特價</b>{{ swap(o.give) }} → {{ swap(o.get) }}
          </li>
        </ul>
      </section>
    </aside>

    <section class="list">
      <nav class="sorts">
        <button v-for="s in SORTS" :key="s.id" :class="{ on: sort === s.id }" @click="sort = s.id">{{ s.name }}</button>
      </nav>
      <p v-if="problem" class="panel warn">{{ problem }}</p>
      <div v-if="!entries" class="panel">讀取中…</div>
      <p v-else-if="!days.length" class="panel muted">還沒有{{ sort ? "這類的" : "" }}動態。</p>
      <div v-for="d in days" :key="d.day" class="day">
        <h3>{{ d.day }}</h3>
        <div class="panel lines">
          <p v-for="e in d.entries" :key="e.seq" class="line">
            <span class="icon">{{ e.icon }}</span>
            <span class="text">{{ e.text }}</span>
            <small>{{ clock(e.at) }}</small>
          </p>
        </div>
      </div>
      <button v-if="more && !sort" class="btn more" :disabled="loadingMore" @click="loadMore">{{ loadingMore ? "讀取中…" : "更早的" }}</button>
    </section>
  </main>
</template>

<style scoped>
h2 { font-size: 16px; margin: 0 0 8px; }
.today .panel { padding: 16px; }
.big { margin: 0 0 8px; font-size: 26px; font-weight: 800; }
.big small { font-size: 14px; color: var(--muted); font-weight: 600; }
.steps { list-style: none; padding: 0; margin: 0 0 8px; display: grid; gap: 4px; }
.steps li { display: flex; gap: 8px; align-items: baseline; font-size: 14px; color: var(--muted); }
.steps li span { min-width: 42px; font-weight: 700; }
.steps li.done { color: var(--ink); font-weight: 700; }
.muted { color: var(--muted); }
.small { font-size: 12px; line-height: 1.6; }
.stock { list-style: none; padding: 0; margin: 8px 0 0; display: grid; gap: 6px; font-size: 13px; }
.stock li b { margin-right: 6px; font-size: 11px; color: #fff; background: var(--amber); border-radius: 6px; padding: 1px 6px; }
.stock li.rare b { background: #8a4fd8; }
.stock li.bought { opacity: 0.45; text-decoration: line-through; }
.sorts { display: flex; gap: 6px; overflow-x: auto; margin: 0 0 10px; padding-bottom: 2px; }
.sorts button { flex: none; border: 0; border-radius: 999px; padding: 6px 12px; background: rgba(255, 255, 255, 0.16); color: #fff; font-weight: 700; font-size: 13px; cursor: pointer; }
.sorts button.on { background: var(--paper-yellow); color: var(--ink); }
.day h3 { margin: 14px 2px 6px; font-size: 13px; color: #e4eedd; }
.lines { padding: 6px 14px; }
.line { display: flex; gap: 10px; align-items: baseline; margin: 0; padding: 8px 0; border-top: 1px solid var(--line); line-height: 1.5; font-size: 14px; }
.line:first-child { border-top: 0; }
.line .icon { flex: none; width: 22px; text-align: center; }
.line .text { flex: 1; min-width: 0; }
.line small { flex: none; color: var(--muted); font-size: 12px; }
.warn { color: #b3412c; }
.more { width: 100%; margin-top: 12px; }
.today { display: grid; gap: 12px; margin-bottom: 4px; }

/* a wide window: the lines on the left, today on the right (and it stays there) */
@media (min-width: 900px) {
  .page.feed { max-width: 1040px; display: grid; grid-template-columns: minmax(0, 1fr) 320px; grid-template-areas: "head head" "list today"; column-gap: 20px; align-items: start; }
  .page.feed > .topbar { grid-area: head; }
  .list { grid-area: list; }
  .today { grid-area: today; position: sticky; top: 12px; }
}
</style>
