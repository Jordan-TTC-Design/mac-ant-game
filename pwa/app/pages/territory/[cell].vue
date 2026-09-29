<script setup lang="ts">
import { materialName, TERRAIN_NAMES, type CellBonus, type CellDetail, type CellHappening } from "@goblincamp/shared/world";
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

// the building: build one of the two for this ground, raise it, or take it down
const busy = ref(false);
const actProblem = ref("");
const store = computed(() => view.value?.materials ?? {});
const short = (cost: Record<string, number> | null) => Object.entries(cost ?? {}).filter(([id, n]) => (store.value[id] ?? 0) < n);
const costText = (cost: Record<string, number> | null) =>
  Object.entries(cost ?? {}).map(([id, n]) => `${materialName(id)} ${n}${(store.value[id] ?? 0) < n ? `（有 ${store.value[id] ?? 0}）` : ""}`).join("、");
/** Taking a building down is asked again on the page (the Mac's world window shows no browser dialogs). */
const askingDemolish = ref(false);
async function act(path: string, body: unknown) {
  askingDemolish.value = false;
  busy.value = true;
  actProblem.value = "";
  try {
    await api("POST", `world/cells/${cellId.value}/${path}`, body);
    await Promise.all([load(), camp.refresh()]);
  } catch (e) {
    actProblem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
/** What the cell gets now, in words. */
function bonusText(b: CellBonus): string[] {
  const out: string[] = [];
  const makes = Object.entries(b.makes).map(([id, n]) => `${materialName(id)} +${n}`);
  if (makes.length) out.push(`每次產出多 ${makes.join("、")}`);
  for (const [id, p] of Object.entries(b.finds)) out.push(`每次產出 ${Math.round(p * 100)}% 機會多一個${materialName(id)}`);
  if (b.fort) out.push(`守這一格的血量 +${Math.round(b.fort * 100)}%`);
  if (b.travel < 1) out.push(`從這裡出發走路時間 −${Math.round((1 - b.travel) * 100)}%`);
  if (b.room) out.push(`最多可以多住 ${b.room} 隻`);
  if (b.party) out.push(`從這裡出發的隊伍可以多 ${b.party} 隻`);
  if (b.xp) out.push(`每天多 ${b.xp} 經驗值`);
  return out;
}

const lootText = (loot: Record<string, number> = {}) => Object.entries(loot).sort((a, b) => b[1] - a[1]).map(([id, n]) => `${materialName(id)} ${n}`).join("、");
function happening(h: CellHappening): string {
  switch (h.kind) {
    case "yield": return `產出了 ${lootText(h.loot)}`;
    case "lairBack": {
      const help = h.helped ? `，旁邊的格子來了 ${h.helped} 隻幫忙` : "";
      return h.held ? `${h.name}回來搶地盤，守住了（倒下 ${h.fallen}、打倒 ${h.killed}${help}）${lootText(h.loot) ? `，撿到 ${lootText(h.loot)}` : ""}` : `${h.name}回來搶地盤，沒守住（倒下 ${h.fallen}${help}）`;
    }
    case "attacked": return h.held ? `${h.by}來打，守住了（倒下 ${h.fallen}）` : `${h.by}來打，被搶走了（倒下 ${h.fallen}）`;
    case "settled": return h.killed ? `打下這一格，住了進來（倒下 ${h.fallen}）` : "有居民搬進來了";
    case "nest": return "開始蓋繁殖巢";
    case "town": return "蓋成了城鎮";
    case "recalled": return `${h.residents} 隻走回營地`;
    case "built": return h.residents === 1 ? `開始蓋${h.name}` : `${h.name}開始升到 ${h.residents} 級`;
    case "demolished": return `拆掉了${h.name}`;
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

      <section v-if="d.landmark || d.templeNear" class="panel landmark">
        <p v-if="d.landmark"><span class="big">{{ d.landmark.icon }}</span> <b>{{ d.landmark.name }}</b>（{{ d.landmark.label }}）<br /><small>{{ d.landmark.blurb }}</small></p>
        <p v-if="d.templeNear" class="small">⛩️ 旁邊有你的廟宇：守這一格血量 +10%</p>
      </section>

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
        <h2>相連的領地</h2>
        <p>旁邊有 <b>{{ d.neighbours }}</b> 格是你的・這一區連著 <b>{{ d.region }}</b> 格</p>
        <p v-if="d.bonus.yieldBoost" class="good">地形產出 +{{ Math.round(d.bonus.yieldBoost * 100) }}%</p>
        <p class="muted small">
          旁邊每有一格自己的，產出多 10%（最多 30%）；被打時旁邊的格子各派最多 5 隻來幫忙守。
          {{ d.town ? "" : d.region >= 4 ? "這一區夠大，可以蓋城鎮了。" : `城鎮要蓋在 4 格相連的地方（還差 ${4 - d.region} 格）。` }}
        </p>
      </section>

      <section class="panel">
        <h2>建築</h2>
        <template v-if="d.building">
          <p>
            <b>{{ d.building.name }}</b> {{ d.building.working }} 級<span v-if="d.building.busyUntil" class="muted">（{{ d.building.level === 1 ? "蓋好" : `升到 ${d.building.level} 級` }}還要 {{ until(d.building.busyUntil) }}）</span>
          </p>
          <p class="muted small">{{ d.building.blurb }}</p>
          <ul v-if="bonusText(d.bonus).length" class="bonus"><li v-for="line in bonusText(d.bonus)" :key="line">{{ line }}</li></ul>
          <template v-if="d.nextCost && !d.building.busyUntil">
            <p class="small">升到 {{ d.building.level + 1 }} 級（{{ d.nextHours }} 小時）：{{ costText(d.nextCost) }}</p>
          </template>
          <div class="ops">
            <button v-if="d.nextCost" class="btn primary" :disabled="busy || !!d.building.busyUntil || short(d.nextCost).length > 0" @click="act('build', { kind: d.building.kind })">升級</button>
            <button v-if="!askingDemolish" class="btn" :disabled="busy" @click="askingDemolish = true">拆掉</button>
          </div>
          <div v-if="askingDemolish" class="ask">
            <p>拆掉{{ d.building.name }}？花掉的素材不會回來。</p>
            <button class="btn danger" :disabled="busy" @click="act('demolish', {})">確定拆掉</button>
            <button class="btn" @click="askingDemolish = false">再想想</button>
          </div>
        </template>
        <template v-else>
          <p class="muted small">每一格可以蓋一個建築，看地形有兩種可以選。蓋（{{ d.nextHours }} 小時）：{{ costText(d.nextCost) }}</p>
          <div v-for="k in d.canBuild" :key="k.kind" class="choice">
            <div class="grow"><b>{{ k.name }}</b><small class="muted">{{ k.blurb }}</small></div>
            <button class="btn" :disabled="busy || short(d.nextCost).length > 0" @click="act('build', { kind: k.kind })">蓋</button>
          </div>
        </template>
        <p v-if="actProblem" class="status error">{{ actProblem }}</p>
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
.good { color: var(--green); font-weight: 700; }
.landmark p { margin: 0; }
.landmark .big { font-size: 22px; }
.landmark small { color: var(--muted); }
.bonus { margin: 6px 0; padding-left: 18px; font-size: 14px; color: var(--green); }
.ops { display: flex; gap: 8px; margin-top: 8px; }
.ask { margin-top: 8px; padding: 10px; border-radius: 10px; background: #fff6c8; }
.ask p { margin: 0 0 8px; }
.choice { display: flex; align-items: center; gap: 10px; padding: 8px 0; border-top: 1px solid var(--line); }
.choice .grow { display: grid; white-space: normal; }
.choice small { font-size: 12px; }
.event { font-size: 14px; display: flex; gap: 8px; }
.event .muted { flex: none; font-size: 12px; }
.wide-link { display: block; margin-top: 12px; padding: 12px; border-radius: 12px; background: rgba(255, 255, 255, 0.12); color: #fff; text-decoration: none; font-weight: 700; text-align: center; }
</style>
