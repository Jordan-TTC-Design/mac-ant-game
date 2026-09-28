<script setup lang="ts">
import { raceRules } from "@goblincamp/shared/camp";
import { materialName as sharedMaterialName } from "@goblincamp/shared/world";
import { noteTime } from "~/utils/time";

const ok = await useSignedIn();
const { user } = useAccount();
const camp = useCamp();
const names = ref<ArtNames>({ races: {}, materials: {} });
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;

onMounted(async () => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  names.value = await loadArtNames();
});
onUnmounted(() => {
  clearInterval(clock);
  camp.close();
});
if (ok && user.value) void camp.open(user.value.id);

const view = computed(() => camp.state.saved?.view ?? null);
const raids = computed(() => camp.state.saved?.raids ?? []);
const race = computed(() => names.value.races[view.value?.race ?? "goblin"]);
const rules = computed(() => raceRules(view.value?.race ?? "goblin"));
const home = computed(() => view.value?.residents.filter((r) => r.place === "home") ?? []);
const breedName = (breed: string) => race.value?.breeds[breed] ?? breed;
const materialName = (id: string) => names.value.materials[id] ?? sharedMaterialName(id);

const statusLine = computed(() => {
  switch (camp.state.status) {
    case "loading": return "讀取中…";
    case "offline": return `離線中：這是 ${noteTime(new Date(camp.state.saved?.fetchedAt ?? 0).toISOString())} 的樣子`;
    case "problem": return `出了問題：${camp.state.problem}`;
    default: return "在 Mac 上玩，這裡只能看";
  }
});

/** Births come every few minutes on fixed slots (shared/src/camp/population.ts); none while the camp is full. */
const nextBirth = computed(() => {
  const v = view.value;
  if (!v) return "";
  if (home.value.length >= rules.value.homeCap) return "滿了，要等有人離開";
  const at = Date.parse(v.startedAt) + v.nextSlot * rules.value.homeBirthMinutes * 60_000;
  const left = Math.max(0, Math.round((at - now.value) / 1000));
  if (left === 0) return "快了";
  return `${Math.floor(left / 60)} 分 ${String(left % 60).padStart(2, "0")} 秒後`;
});
// when the next one is due, ask (the server works the birth out)
watch(nextBirth, (text) => {
  if (text === "快了" && camp.state.status === "ok") setTimeout(() => void camp.refresh(), 3000);
});

const breeds = computed(() => {
  const counts = new Map<string, number>();
  for (const r of home.value) counts.set(r.breed, (counts.get(r.breed) ?? 0) + 1);
  return [...counts].sort((a, b) => b[1] - a[1]).map(([breed, count]) => ({ breed, count, sheet: race.value?.sheets[breed] ?? "worker" }));
});

interface Romance { stage?: string; partnerName?: string; children?: number; pregnancy?: number | null }
const princess = computed(() => {
  const r = (view.value?.romance ?? null) as Romance | null;
  const stage = { courting: "有人在追求她", dating: "在交往中", married: "已經結婚" }[r?.stage ?? ""] ?? "單身";
  const parts = [r?.partnerName && r.stage !== "single" ? `${stage}（${r.partnerName}）` : stage];
  if (r?.pregnancy != null) parts.push("懷孕中");
  if (r?.children) parts.push(`有 ${r.children} 個孩子`);
  return parts.join("・");
});

const sorted = (record: Record<string, number>) => Object.entries(record).filter(([, n]) => n > 0).sort((a, b) => b[1] - a[1]);
const armory = computed(() => {
  const counts: Record<string, number> = {};
  for (const item of view.value?.armory ?? []) counts[item.id] = (counts[item.id] ?? 0) + 1;
  return sorted(counts);
});
const worn = computed(() => home.value.filter((r) => r.gear && Object.keys(r.gear).length > 0).length);
const boosts = computed(() => Object.entries(view.value?.boosts ?? {}).filter(([, until]) => Date.parse(until) > now.value));
const kills = computed(() => sorted(view.value?.kills ?? {}).reduce((n, [, k]) => n + k, 0));
const showAllRaids = ref(false);
const openRaid = ref<number | null>(null);
const monsters = (list: { id: string; count: number }[]) => list.map((m) => `${monsterName(m.id)} ×${m.count}`).join("、");
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 便利貼</NuxtLink>
      <div style="flex: 1">
        <h1>{{ view ? `${race?.name ?? ""}${race?.nest ?? "營地"}` : "營地" }}</h1>
        <div class="sub">{{ statusLine }}</div>
      </div>
      <NuxtLink to="/world" class="icon-btn">大世界</NuxtLink>
    </header>

    <div v-if="!view && camp.state.status === 'none'" class="panel">這個帳號還沒有營地。在 Mac 上登入並選好種族，營地就會出現在這裡。</div>
    <div v-else-if="!view" class="panel">{{ camp.state.status === "loading" ? "讀取中…" : statusLine }}</div>

    <template v-else>
      <CampScene :race="view.race" :stage="view.stage" :residents="home" :sheets="race?.sheets ?? {}" :princess="true" />

      <section class="panel stats">
        <div><b>{{ home.length }}</b><small>人口 / {{ rules.homeCap }}</small></div>
        <div><b>{{ view.stage }}</b><small>階段</small></div>
        <div><b>{{ view.peak }}</b><small>最多時</small></div>
        <div><b>{{ kills }}</b><small>打倒魔獸</small></div>
        <p class="next">下一隻出生：{{ nextBirth }}<br /><small>每 {{ rules.homeBirthMinutes }} 分鐘生一隻，Mac 關著也會長大</small></p>
      </section>

      <section class="panel">
        <h2>品種</h2>
        <ul class="breeds">
          <li v-for="b in breeds" :key="b.breed">
            <span class="icon pixel" :style="{ backgroundImage: `url(/sprites/${view.race}/${b.sheet}.png)` }" />
            <span class="grow">{{ breedName(b.breed) }}</span>
            <b>{{ b.count }}</b>
          </li>
        </ul>
      </section>

      <section class="panel princess">
        <span class="queen pixel" :style="{ backgroundImage: `url(/sprites/${view.race}/queen.png)` }" />
        <div>
          <h2>公主{{ view.princessName ? `・${view.princessName}` : "" }}</h2>
          <p>{{ princess }}</p>
        </div>
      </section>

      <section class="panel">
        <h2>魔獸來襲 <small v-if="raids.length">最近 {{ raids.length }} 次・守住 {{ raids.filter((r) => r.winner === "camp").length }} 次</small></h2>
        <p v-if="raids.length === 0" class="muted">還沒有魔獸來過（營地滿十隻之後，大約每一個半小時來一次）。</p>
        <!-- one line each; tap for the whole of it -->
        <article v-for="r in raids.slice(0, showAllRaids ? raids.length : 3)" :key="r.seq" class="raid" @click="openRaid = openRaid === r.seq ? null : r.seq">
          <header>
            <span :class="r.winner === 'camp' ? 'won' : 'lost'">{{ r.winner === "camp" ? "守住了" : "被突破了" }}</span>
            <span class="gist">{{ r.monsters.reduce((n, m) => n + m.count, 0) }} 隻魔獸{{ r.fallen.length ? `・倒下 ${r.fallen.length}` : "" }}{{ Object.keys(r.loot).length ? `・撿到 ${Object.values(r.loot).reduce((a, b) => a + b, 0)} 個` : "" }}</span>
            <small>{{ noteTime(r.at) }}</small>
          </header>
          <template v-if="openRaid === r.seq">
            <p>{{ monsters(r.monsters) }}，{{ r.defenders }} 隻出去迎戰。</p>
            <p v-if="r.fallen.length" class="lost">陣亡：{{ r.fallen.map((f) => f.name || breedName(f.breed)).join("、") }}</p>
            <p v-if="Object.keys(r.loot).length" class="muted">撿到：{{ sorted(r.loot).map(([id, n]) => `${materialName(id)} ×${n}`).join("、") }}</p>
            <p v-if="r.broken.length" class="muted">打壞了：{{ r.broken.map((b) => gearName(b.gear)).join("、") }}</p>
          </template>
        </article>
        <button v-if="raids.length > 3" class="more" @click="showAllRaids = !showAllRaids">{{ showAllRaids ? "收起" : `看更早的（${raids.length - 3} 次）` }}</button>
      </section>

      <section class="panel">
        <h2>倉庫</h2>
        <h3>素材</h3>
        <p v-if="sorted(view.materials).length === 0" class="muted">還沒有。</p>
        <ul class="chips">
          <li v-for="[id, n] in sorted(view.materials)" :key="id">{{ materialName(id) }} <b>{{ n }}</b></li>
        </ul>
        <h3>裝備</h3>
        <p class="muted">{{ worn }} 隻身上有裝備；倉庫裡還有 {{ view.armory.length }} 件。</p>
        <ul class="chips">
          <li v-for="[id, n] in armory" :key="id">{{ gearName(id) }} <b>{{ n }}</b></li>
        </ul>
        <template v-if="boosts.length">
          <h3>食物加成</h3>
          <ul class="chips">
            <li v-for="[food, until] in boosts" :key="food">{{ FOOD_NAMES[food] ?? food }} <small>到 {{ noteTime(until) }}</small></li>
          </ul>
        </template>
      </section>
    </template>
  </main>
</template>

<style scoped>
section { margin-top: 14px; }
h2 { font-size: 16px; margin: 0 0 10px; }
h3 { font-size: 13px; margin: 14px 0 6px; color: var(--muted); }
p { margin: 4px 0; line-height: 1.55; }
.muted { color: var(--muted); font-size: 14px; }
.stats { display: grid; grid-template-columns: repeat(4, 1fr); gap: 8px; text-align: center; }
.stats b { display: block; font-size: 22px; }
.stats small { font-size: 12px; color: var(--muted); white-space: nowrap; }
@media (max-width: 350px) { .stats small { font-size: 11px; } .stats b { font-size: 19px; } }
.stats .next { grid-column: 1 / -1; margin-top: 6px; font-weight: 600; }
.stats .next small { font-weight: 400; }
.breeds { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
.breeds li { display: flex; align-items: center; gap: 10px; }
.grow { flex: 1; }
.icon { width: 32px; height: 32px; background-size: 128px 96px; background-position: 0 0; }
.princess { display: flex; align-items: center; gap: 14px; }
.queen { flex: none; width: 48px; height: 48px; background-size: 192px 672px; background-position: 0 0; }
.raid { border-top: 1px solid var(--line); padding: 10px 0; }
.raid:first-of-type { border-top: 0; padding-top: 0; }
.raid { cursor: pointer; }
.raid header { display: flex; gap: 8px; align-items: baseline; font-weight: 700; }
.gist { flex: 1; min-width: 0; font-weight: 500; font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
h2 small { font-size: 12px; font-weight: 500; color: var(--muted); margin-left: 6px; }
.more { border: 0; background: none; color: var(--green); font-weight: 700; padding: 8px 0 0; cursor: pointer; }
.raid small { color: var(--muted); font-weight: 400; }
.won { color: var(--green); }
.lost { color: var(--red); }
.chips { list-style: none; margin: 0; padding: 0; display: flex; flex-wrap: wrap; gap: 6px; }
.chips li { background: #f1eee2; border-radius: 8px; padding: 5px 10px; font-size: 14px; }
.icon-btn:disabled { opacity: 0.5; }
</style>
