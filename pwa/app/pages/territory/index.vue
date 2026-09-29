<script setup lang="ts">
import { TERRAIN_NAMES, type TerritoryItem, type TerritoryList } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 領地: every held cell at a glance (how many live there, what is built, a landmark, the region, food); tap one to go in.
const ok = await useSignedIn();
const list = ref<TerritoryList | null>(null);
const problem = ref("");
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;

async function load() {
  try {
    list.value = await api<TerritoryList>("GET", "world/territory");
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? (e.code === "no_camp" ? "還沒有營地。" : e.message) : String(e);
  }
}
const onChanged = () => void load();
onMounted(() => {
  clock = setInterval(() => (now.value = Date.now()), 30_000);
  window.addEventListener("gc:camp-changed", onChanged);
  void load();
});
onUnmounted(() => {
  clearInterval(clock);
  window.removeEventListener("gc:camp-changed", onChanged);
});

const sort = ref<"held" | "garrison" | "region">("held");
const items = computed(() => {
  const all = [...(list.value?.items ?? [])];
  if (sort.value === "garrison") all.sort((a, b) => Number(b.home) - Number(a.home) || b.garrison - a.garrison);
  if (sort.value === "region") all.sort((a, b) => Number(b.home) - Number(a.home) || b.region - a.region || b.garrison - a.garrison);
  return all;
});
const towns = computed(() => items.value.filter((i) => i.town).length);
const built = computed(() => items.value.filter((i) => i.building).length);

const title = (i: TerritoryItem) => (i.home ? "營地" : i.landmark ? i.landmark.name : TERRAIN_NAMES[i.terrain]);
const link = (i: TerritoryItem) => (i.home ? "/camp" : `/territory/${i.cell}`);
function inTime(iso: string) {
  const m = Math.max(0, Math.round((Date.parse(iso) - now.value) / 60_000));
  return m >= 60 ? `${Math.floor(m / 60)} 小時 ${m % 60} 分後` : m > 0 ? `${m} 分後` : "快了";
}
const NEST: Record<TerritoryItem["nest"], string> = { none: "沒有巢", building: "巢蓋到一半", ready: "有巢" };
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/camp" class="icon-btn">← 營地</NuxtLink>
      <div style="flex: 1">
        <h1>領地</h1>
        <div v-if="list" class="sub">
          {{ list.items.length }} 格・住 {{ list.residents }} 隻{{ towns ? `・城鎮 ${towns}` : "" }}{{ built ? `・建築 ${built}` : "" }}
        </div>
      </div>
      <NuxtLink to="/world" class="icon-btn" aria-label="大世界" title="大世界">🗺️</NuxtLink>
    </header>

    <div v-if="!list" class="panel">{{ problem || "讀取中…" }}</div>
    <div v-else-if="!list.items.length" class="panel">
      <p>還沒有領地。到大世界放下營地、出征佔地之後，這裡會列出每一格。</p>
      <NuxtLink to="/world" class="btn primary">去大世界</NuxtLink>
    </div>
    <template v-else>
      <div class="tools">
        <p v-if="list.paying" class="food" :class="{ hungry: list.rations < list.paying }">
          🍞 乾糧 {{ list.rations }}・{{ list.paying }} 格要吃（每 6 小時 {{ list.paying }} 份）
        </p>
        <select v-model="sort" aria-label="排序">
          <option value="held">佔領順序</option>
          <option value="garrison">住的多的先</option>
          <option value="region">大區的先</option>
        </select>
      </div>

      <NuxtLink v-for="i in items" :key="i.cell" :to="link(i)" class="item" :class="{ home: i.home }">
        <span class="badge">
          <span v-if="i.home">🛖</span>
          <span v-else-if="i.landmark">{{ i.landmark.icon }}</span>
          <span v-else class="ground" :class="i.terrain" />
        </span>
        <span class="body">
          <span class="head">
            <b>{{ title(i) }}</b>
            <small v-if="i.landmark && !i.home" class="muted">{{ i.landmark.label }}</small>
            <small v-else-if="!i.home" class="muted">{{ TERRAIN_NAMES[i.terrain] }}</small>
          </span>
          <span class="bar" :aria-label="`住 ${i.garrison} 隻，最多 ${i.capacity}`">
            <i :style="{ width: `${Math.min(100, (100 * i.garrison) / Math.max(1, i.capacity))}%` }" />
          </span>
          <span class="tags">
            <small>👥 {{ i.garrison }}{{ i.home ? "" : `/${i.capacity}` }}</small>
            <small v-if="i.town" class="tag gold">城鎮</small>
            <small v-if="!i.home">{{ NEST[i.nest] }}</small>
            <small v-if="i.building" class="tag">🏗️ {{ i.building.name }} Lv{{ i.building.level }}{{ i.building.busy ? "（蓋中）" : "" }}</small>
            <small v-if="i.region > 1">🔗 連 {{ i.region }} 格</small>
            <small v-if="i.guests" class="tag">🤝 {{ i.guests }}</small>
            <small v-if="i.upkeep" :class="{ warn: list.rations < list.paying }">🍞 吃乾糧</small>
          </span>
          <small class="muted">下次產出 {{ inTime(i.nextYieldAt) }}</small>
        </span>
        <span class="go">›</span>
      </NuxtLink>
    </template>
  </main>
</template>

<style scoped>
.muted { color: var(--muted); }
.tools { display: flex; align-items: center; gap: 8px; margin-bottom: 10px; flex-wrap: wrap; }
.tools select { margin-left: auto; padding: 6px 8px; border-radius: 9px; border: 0; font: inherit; font-size: 14px; }
.food { margin: 0; color: #fff; font-size: 13px; font-weight: 700; }
.food.hungry { color: #ffb3a6; }
.item {
  display: flex; align-items: center; gap: 12px; padding: 12px; margin-bottom: 8px; border-radius: 14px; background: var(--card);
  color: var(--ink); text-decoration: none; box-shadow: 0 2px 0 rgba(0, 0, 0, 0.25);
}
.item.home { border: 2px solid #e0b400; }
.badge { flex: none; width: 40px; height: 40px; display: grid; place-items: center; font-size: 26px; border-radius: 10px; background: #f0efe8; }
.ground { width: 28px; height: 28px; border-radius: 6px; background: #9bbf7a; }
.ground.forest { background: #3f7a3a; }
.ground.park { background: #7fbf5f; }
.ground.water { background: #5f9fd0; }
.ground.urban { background: #a39a8c; }
.ground.open { background: #c9b77a; }
.ground.road { background: #6f6a63; }
.body { flex: 1; min-width: 0; display: grid; gap: 4px; }
.head { display: flex; align-items: baseline; gap: 6px; min-width: 0; }
.head b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.head small { flex: none; font-size: 11px; }
.bar { height: 6px; border-radius: 3px; background: #ece9dc; overflow: hidden; }
.bar i { display: block; height: 100%; background: var(--green); }
.tags { display: flex; flex-wrap: wrap; gap: 4px 8px; font-size: 12px; }
.tag { background: #eef4e8; border-radius: 6px; padding: 0 5px; }
.tag.gold { background: #fff0b8; color: #8a6a00; font-weight: 700; }
.warn { color: #b3412c; font-weight: 700; }
.body > small { font-size: 11px; }
.go { flex: none; font-size: 22px; color: var(--muted); }
</style>
