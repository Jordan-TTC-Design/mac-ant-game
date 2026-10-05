<script setup lang="ts">
// 撤回 (server/WORLD.md §24): residents on a held cell (or camping beside it) walk to the camp or to another held cell.
// Those who do not fit walk on to the nearest cell with room, else camp beside it. A sheet from the bottom of the screen.
import { TERRAIN_NAMES, travelMinutes, type TerritoryItem, type TerritoryList } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

const props = defineProps<{ from: string; title: string; available: number; keep: number; campers?: boolean }>();
const emit = defineEmits<{ close: []; done: [message: string] }>();

const cells = ref<TerritoryItem[] | null>(null);
const problem = ref("");
const busy = ref(false);
const to = ref("home");
const count = ref(props.available);
onMounted(async () => {
  try {
    cells.value = (await api<TerritoryList>("GET", "world/territory")).items;
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
});
const home = computed(() => cells.value?.find((c) => c.home) ?? null);
const nameOf = (c: TerritoryItem) => c.landmark?.label ?? TERRAIN_NAMES[c.terrain] ?? "領地";
const minutes = (cell: string) => travelMinutes(props.from, cell);
const choices = computed(() =>
  (cells.value ?? [])
    .filter((c) => !c.home && c.cell !== props.from)
    .map((c) => ({ c, free: Math.max(0, c.capacity - c.garrison), min: minutes(c.cell) }))
    .sort((a, b) => a.min - b.min),
);
const n = computed(() => Math.max(1, Math.min(props.available, Math.round(count.value || 0))));
/** Everyone goes (the cell is given up), or too few would be left to hold it. */
const givesUp = computed(() => !props.campers && props.available - n.value < props.keep);
const going = computed(() => (givesUp.value ? props.available : n.value));
const target = computed(() => choices.value.find((x) => x.c.cell === to.value) ?? null);

async function go() {
  busy.value = true;
  problem.value = "";
  try {
    await api("POST", `world/cells/${props.from}/recall`, { to: to.value, ...(going.value < props.available ? { count: going.value } : {}), ...(props.campers ? { campers: true } : {}) });
    const where = to.value === "home" ? "營地" : target.value ? nameOf(target.value.c) : "那一格";
    emit("done", `${going.value} 隻出發去${where}了（約 ${to.value === "home" ? (home.value ? minutes(home.value.cell) : "?") : target.value?.min} 分鐘）。`);
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="sheet-back" @click.self="emit('close')">
    <div class="sheet">
      <header>
        <b>{{ title }}</b>
        <button class="x" @click="emit('close')">✕</button>
      </header>
      <p v-if="!cells" class="muted">{{ problem || "讀取中…" }}</p>
      <template v-else>
        <h3>去哪裡</h3>
        <div class="list">
          <label class="where" :class="{ on: to === 'home' }">
            <input v-model="to" type="radio" value="home" />
            <span class="line"><b>🏕️ 營地</b><span class="grow" /><small>約 {{ home ? minutes(home.cell) : "?" }} 分鐘</small></span>
            <small class="muted">一定住得下</small>
          </label>
          <label v-for="x in choices" :key="x.c.cell" class="where" :class="{ on: to === x.c.cell }">
            <input v-model="to" type="radio" :value="x.c.cell" />
            <span class="line"><b>{{ nameOf(x.c) }}</b><span class="grow" /><small>約 {{ x.min }} 分鐘</small></span>
            <small :class="x.free ? 'muted' : 'warn'">住 {{ x.c.garrison }}／{{ x.c.capacity }}・{{ x.free ? `還能住 ${x.free} 隻` : "滿了" }}{{ x.c.camping ? `・外面扎營 ${x.c.camping} 隻` : "" }}</small>
          </label>
        </div>

        <h3>幾隻（{{ campers ? "外面扎營的" : "住在這裡的" }}共 {{ available }} 隻）</h3>
        <div class="count">
          <input v-model.number="count" type="number" min="1" :max="available" />
          <button class="btn" @click="count = available">全部</button>
        </div>
        <p v-if="givesUp" class="warn small">{{ n < available ? `這一格至少要留 ${keep} 隻，所以會全部 ${available} 隻都撤走。` : "" }}全部撤走，這一格就放掉了（出發時就不是你的了）。</p>
        <p v-if="to !== 'home' && target && going > target.free" class="muted small">
          住不下的 {{ going - target.free }} 隻會自動走去最近還有空位的領地；都滿了就在那一格旁邊扎營，有空位時自動住進去（扎營的也會幫忙守）。
        </p>
        <p v-if="problem" class="warn small">{{ problem }}</p>
        <button class="btn primary wide" :disabled="busy" @click="go">出發（{{ going }} 隻）</button>
      </template>
    </div>
  </div>
</template>

<style scoped>
.sheet-back { position: fixed; inset: 0; z-index: 50; background: rgba(0, 0, 0, 0.45); display: flex; align-items: flex-end; justify-content: center; }
.sheet { width: 100%; max-width: 560px; max-height: 85vh; overflow-y: auto; background: var(--card); border-radius: 16px 16px 0 0; padding: 12px 14px calc(env(safe-area-inset-bottom) + 12px); }
header { display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
header b { flex: 1; font-size: 16px; }
.x { border: 0; background: none; font-size: 18px; cursor: pointer; padding: 4px 8px; }
h3 { font-size: 13px; margin: 12px 0 6px; color: var(--muted); }
.list { display: grid; gap: 6px; max-height: 40vh; overflow-y: auto; }
.where { display: grid; gap: 2px; border: 1px solid var(--line); background: #fff; border-radius: 10px; padding: 8px 10px; cursor: pointer; }
.where.on { border-color: var(--green); background: #eef6e6; }
.where input { display: none; }
.line { display: flex; align-items: center; gap: 6px; }
.grow { flex: 1; }
.count { display: flex; gap: 8px; align-items: center; }
.count input { width: 100px; border: 1px solid var(--line); border-radius: 8px; padding: 8px; font-size: 16px; }
.wide { width: 100%; margin-top: 12px; }
.muted { color: var(--muted); }
.warn { color: var(--red); }
.small { font-size: 13px; margin: 6px 0 0; }
</style>
