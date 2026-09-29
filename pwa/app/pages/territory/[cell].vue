<script setup lang="ts">
import { materialName, TERRAIN_NAMES, type CellDetail, type CellHappening } from "@goblincamp/shared/world";
import type { CampResidentView } from "@goblincamp/shared/camp";
import { ApiError, api } from "~/utils/api";
import { noteTime } from "~/utils/time";

// 領地 from inside (server/WORLD.md §20): a small camp of its own with the residents who live there wandering about, how it
// grows, what the ground gives, and what happened there. The residents come from the camp's books (place `cell:<id>`).
const ok = await useSignedIn();
const { user } = useAccount();
const route = useRoute();
const cellId = computed(() => String(route.params.cell));
const camp = useCamp();
const names = ref<ArtNames>({ races: {}, materials: {} });
const d = ref<CellDetail | null>(null);
const problem = ref("");
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;

async function load() {
  try {
    d.value = await api<CellDetail>("GET", `world/cells/${cellId.value}`);
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
const onChanged = () => void load();
onMounted(async () => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  window.addEventListener("gc:camp-changed", onChanged);
  names.value = await loadArtNames();
  await load();
});
onUnmounted(() => {
  clearInterval(clock);
  window.removeEventListener("gc:camp-changed", onChanged);
  camp.close();
});
if (ok && user.value) void camp.open(user.value.id);

const view = computed(() => camp.state.saved?.view ?? null);
const race = computed(() => view.value?.race ?? "goblin");
const art = computed(() => names.value.races[race.value]);
const living = computed(() => (view.value?.residents ?? []).filter((r) => r.place === `cell:${cellId.value}`));
const nameOf = (r: CampResidentView) => r.name || residentNameFromSeed(race.value, r.seed, r.legacySeed);
const breedName = (b: string) => art.value?.breeds[b] ?? b;
const strongest = computed(() => living.value.map((r) => ({ r, power: residentPower(race.value, r) })).sort((a, b) => b.power - a.power));
const shown = ref(20);
const breeds = computed(() => {
  const counts = new Map<string, number>();
  for (const r of living.value) counts.set(r.breed, (counts.get(r.breed) ?? 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1]);
});

/** "3 分 05 秒後", "2 小時 10 分後", or "快了". */
function until(iso: string | null) {
  if (!iso) return "";
  const left = Math.max(0, Math.round((Date.parse(iso) - now.value) / 1000));
  if (left === 0) return "快了";
  if (left >= 3600) return `${Math.floor(left / 3600)} 小時 ${Math.floor((left % 3600) / 60)} 分後`;
  return `${Math.floor(left / 60)} 分 ${String(left % 60).padStart(2, "0")} 秒後`;
}
// when something is due, ask again (the server works it out)
watch(
  () => [until(d.value?.nextBirthAt ?? null), until(d.value?.nextYieldAt ?? null), until(d.value?.nestReadyAt ?? null)],
  (texts) => {
    if (texts.includes("快了")) setTimeout(() => void camp.refresh().then(load), 3000);
  },
);

const lootText = (loot: Record<string, number> = {}) => Object.entries(loot).sort((a, b) => b[1] - a[1]).map(([id, n]) => `${materialName(id)} ${n}`).join("、");
function happening(h: CellHappening): string {
  switch (h.kind) {
    case "yield": return `產出了 ${lootText(h.loot)}`;
    case "lairBack": return h.held ? `${h.name}回來搶地盤，守住了（倒下 ${h.fallen}、打倒 ${h.killed}）${lootText(h.loot) ? `，撿到 ${lootText(h.loot)}` : ""}` : `${h.name}回來搶地盤，沒守住（倒下 ${h.fallen}）`;
    case "attacked": return h.held ? `${h.by}來打，守住了（倒下 ${h.fallen}）` : `${h.by}來打，被搶走了（倒下 ${h.fallen}）`;
    case "settled": return h.killed ? `打下這一格，住了進來（倒下 ${h.fallen}）` : "有居民搬進來了";
    case "nest": return "開始蓋繁殖巢";
    case "town": return "蓋成了城鎮";
    case "recalled": return `${h.residents} 隻走回營地`;
  }
}
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink :to="`/world?cell=${cellId}`" class="icon-btn">← 地圖</NuxtLink>
      <div style="flex: 1">
        <h1>{{ d?.town ? "城鎮" : "領地" }}</h1>
        <div v-if="d" class="sub">{{ TERRAIN_NAMES[d.terrain] }}・{{ d.heldSince ? `${noteTime(d.heldSince)}佔下` : "" }}</div>
      </div>
    </header>

    <div v-if="!d" class="panel">{{ problem || "讀取中…" }}</div>
    <div v-else-if="d.home" class="panel">
      <p>這一格就是營地本身，在家的居民都住在這裡。</p>
      <NuxtLink to="/camp" class="btn primary">看營地</NuxtLink>
    </div>
    <template v-else>
      <CampScene :race="race" :stage="d.town ? 3 : 1" :residents="living" :sheets="art?.sheets ?? {}" :princess="false" />

      <section class="panel grid">
        <div><b>{{ d.garrison }}</b><small>住在這裡（最多 {{ d.capacity }}）</small></div>
        <div><b :class="{ warn: d.garrison < d.garrisonMin + 2 }">{{ d.garrisonMin }}</b><small>至少要留幾隻</small></div>
        <div>
          <b>{{ { none: "沒有", building: "蓋到一半", ready: "有" }[d.nest] }}</b>
          <small>繁殖巢</small>
        </div>
      </section>

      <section class="panel">
        <h2>怎麼長大</h2>
        <p v-if="d.nest === 'none'" class="muted">還沒有繁殖巢，這一格不會自己生居民；到地圖上點這一格可以蓋。</p>
        <p v-else-if="d.nest === 'building'">繁殖巢 {{ until(d.nestReadyAt) }}蓋好，之後每 {{ d.birthMinutes }} 分鐘生一隻。</p>
        <p v-else-if="d.nextBirthAt">每 {{ d.birthMinutes }} 分鐘生一隻・下一隻 <b>{{ until(d.nextBirthAt) }}</b></p>
        <p v-else class="muted">住滿了，要等有居民離開或老死才會再生。</p>
        <p>下次產出 <b>{{ until(d.nextYieldAt) }}</b>：{{ d.yields.map((id) => materialName(id)).join("、") }}</p>
        <p class="muted small">住越多產越多，住滿是兩倍{{ d.town ? "；城鎮再兩倍" : "" }}。至少要住 {{ d.garrisonMin }} 隻才有產出。</p>
      </section>

      <section class="panel">
        <h2>住在這裡的 <small>{{ living.length }} 隻</small></h2>
        <p v-if="breeds.length" class="muted small">{{ breeds.map(([b, n]) => `${breedName(b)} ${n}`).join("・") }}</p>
        <ul class="list">
          <li v-for="{ r, power } in strongest.slice(0, shown)" :key="r.id" class="row">
            <span class="icon pixel" :style="{ backgroundImage: `url(/sprites/${race}/${art?.sheets[r.breed] ?? 'worker'}.png)` }" />
            <span class="grow"><b>{{ nameOf(r) }}</b> <small>{{ breedName(r.breed) }}</small></span>
            <small>裝備 {{ Object.keys(r.gear ?? {}).length }}</small>
            <b class="power">{{ power }}</b>
          </li>
        </ul>
        <button v-if="strongest.length > shown" class="more" @click="shown += 50">再多列一些（還有 {{ strongest.length - shown }} 隻）</button>
      </section>

      <section class="panel">
        <h2>最近發生的事</h2>
        <p v-if="!d.history.length" class="muted">還沒有。</p>
        <p v-for="(h, k) in d.history" :key="k" class="event">
          <span class="muted">{{ noteTime(h.at) }}</span>
          <NuxtLink v-if="h.expedition" :to="`/expedition/${h.expedition}`">{{ happening(h) }}</NuxtLink>
          <span v-else>{{ happening(h) }}</span>
        </p>
      </section>

      <NuxtLink :to="`/world?cell=${cellId}`" class="wide-link">在地圖上派人、撤回、蓋巢穴 ›</NuxtLink>
    </template>
  </main>
</template>

<style scoped>
h2 { font-size: 15px; margin: 0 0 8px; }
h2 small { font-size: 12px; font-weight: 500; color: var(--muted); }
p { margin: 6px 0; }
.muted { color: var(--muted); }
.small { font-size: 12px; }
.grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; text-align: center; }
.grid b { display: block; font-size: 20px; }
.grid small { font-size: 11px; color: var(--muted); }
.warn { color: #b3412c; }
.list { list-style: none; margin: 8px 0 0; padding: 0; display: grid; gap: 4px; }
.row { display: flex; align-items: center; gap: 10px; padding: 4px 2px; border-top: 1px solid var(--line); }
.row:first-child { border-top: 0; }
.row small { color: var(--muted); font-size: 12px; white-space: nowrap; }
.grow { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.power { min-width: 2.2em; text-align: right; }
.icon { flex: none; width: 32px; height: 32px; background-size: 128px 96px; background-position: 0 0; }
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 10px 0 0; cursor: pointer; }
.event { font-size: 14px; display: flex; gap: 8px; }
.event .muted { flex: none; font-size: 12px; }
.wide-link { display: block; margin-top: 12px; padding: 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.12); color: #fff; text-decoration: none; font-weight: 700; text-align: center; }
</style>
