<script setup lang="ts">
import { raceRules } from "@goblincamp/shared/camp";
import { materialName as sharedMaterialName } from "@goblincamp/shared/world";
import { noteTime } from "~/utils/time";
import { ApiError, api } from "~/utils/api";

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
    default: return "在 Mac 上玩；這裡可以看、蓋場地";
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
// 聖光模式 (server/CAMP.md §7)
const sanctuaryBusy = ref(false);
const sanctuaryProblem = ref("");
const sanctuaryCanOn = computed(() => !!view.value?.sanctuary?.since || !view.value?.sanctuary?.canTurnOnAt || Date.parse(view.value.sanctuary.canTurnOnAt) <= now.value);
async function toggleSanctuary() {
  const on = !view.value?.sanctuary?.since;
  if (on && !confirm("開啟聖光模式？\n\n不會有魔獸來襲，別人也打不了你；營地 120 隻以上時生得慢一半。關掉之後要 12 小時才能再開。")) return;
  sanctuaryBusy.value = true;
  sanctuaryProblem.value = "";
  try {
    await api("POST", "camp/sanctuary", { on });
    await camp.refresh();
  } catch (e) {
    sanctuaryProblem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    sanctuaryBusy.value = false;
  }
}
// the camp's sites (server/FARM.md §11): build, raise, take down
const production = computed(() => view.value?.production ?? null);
const perHourText = (n: number) => (n >= 10 ? Math.round(n) : Math.round(n * 10) / 10);
const makesText = (makes: Record<string, number>) =>
  Object.entries(makes).map(([id, n]) => (n < 0.1 && (id === "crystal_shard") ? `${materialName(id)} ${Math.round(n * 100)}%` : `${materialName(id)} ${perHourText(n)}`)).join("、");
const costText = (cost: Record<string, number>) => Object.entries(cost).map(([id, n]) => `${materialName(id)} ×${n}`).join("、");
const affordable = (cost: Record<string, number>) => Object.entries(cost).every(([id, n]) => (view.value?.materials[id] ?? 0) >= n);
const leftText = (until: string) => {
  const minutes = Math.max(0, Math.ceil((Date.parse(until) - now.value) / 60_000));
  return minutes >= 60 ? `${Math.floor(minutes / 60)} 小時 ${minutes % 60} 分` : `${minutes} 分鐘`;
};
// when a site is done, ask (the server works it out)
watch(() => production.value?.busy && Date.parse(production.value.busy.until) <= now.value, (done) => {
  if (done && camp.state.status === "ok") setTimeout(() => void camp.refresh(), 3000);
});
const freePlots = computed(() => Math.max(0, (production.value?.slots ?? 0) - (production.value?.used ?? 0)));
const picking = ref(false);
const openSite = ref<number | null>(null);
const siteBusy = ref(false);
const siteProblem = ref("");
async function siteCommand(question: string, command: Record<string, unknown>) {
  if (!confirm(question)) return;
  siteBusy.value = true;
  siteProblem.value = "";
  try {
    await api("POST", "camp/commands", { ...command, requestId: crypto.randomUUID() });
    await camp.refresh();
    picking.value = false;
  } catch (e) {
    siteProblem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    siteBusy.value = false;
  }
}
const showAllRaids = ref(false);
const openRaid = ref<number | null>(null);
const monsters = (list: { id: string; count: number }[]) => list.map((m) => `${monsterName(m.id)} ×${m.count}`).join("、");
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/" class="icon-btn">← 首頁</NuxtLink>
      <div style="flex: 1">
        <h1>{{ view ? `${race?.name ?? ""}${race?.nest ?? "營地"}` : "營地" }}</h1>
        <div class="sub">{{ statusLine }}</div>
      </div>
      <nav class="world-links">
        <NuxtLink to="/world" class="icon-btn" aria-label="大世界" title="大世界">🗺️</NuxtLink>
        <NuxtLink to="/territory" class="icon-btn" aria-label="領地列表" title="領地列表">🏰</NuxtLink>
      </nav>
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

      <section v-if="production" class="panel production">
        <h2>場地 <small>空地 {{ production.used }}/{{ production.slots }}・人手 {{ production.workers }}/{{ production.need }}</small></h2>
        <p v-if="production.share < 1" class="warn small">人手不夠：每個場地只有 {{ Math.round(production.share * 100) }}% 的速度。營地的居民越多，養得起越多場地（每一級要 10 隻）。</p>
        <p v-if="production.busy" class="upgrading">🔨 正在蓋{{ production.sites.find((x) => x.id === production!.busy!.site)?.name }}，還要 {{ leftText(production.busy.until) }}</p>
        <ul class="sites">
          <li v-for="site in production.sites" :key="site.id" :class="{ open: openSite === site.id }">
            <button class="site-row" @click="openSite = openSite === site.id ? null : site.id">
              <b>{{ site.name }}</b>
              <small>{{ site.level === 0 ? "蓋的中" : `Lv${site.level}` }}{{ site.parts ? `・${site.parts.at(-1)}` : "" }}</small>
              <span class="grow makes">{{ site.level === 0 ? "" : `每小時 ${makesText(site.makes)}` }}</span>
            </button>
            <div v-if="openSite === site.id" class="site-more">
              <p v-if="site.parts" class="muted small">{{ site.parts.join("、") }}</p>
              <template v-if="site.next && !site.busyUntil">
                <p class="small">升到 Lv{{ site.next.level }}：每小時 {{ makesText(site.next.makes) }}</p>
                <ul class="chips">
                  <li v-for="[id, n] in Object.entries(site.next.cost)" :key="id" :class="{ short: (view.materials[id] ?? 0) < n }">{{ materialName(id) }} {{ view.materials[id] ?? 0 }}/{{ n }}</li>
                  <li>⏱ {{ site.next.hours }} 小時</li>
                </ul>
              </template>
              <p v-else-if="!site.next" class="muted small">已經是最高級了。</p>
              <div class="actions">
                <button v-if="site.next && !site.busyUntil" class="btn primary" :disabled="siteBusy || !!production.busy || !affordable(site.next.cost)"
                  @click="siteCommand(`升級${site.name}到 Lv${site.next.level}？\n\n要 ${costText(site.next.cost)}，${site.next.hours} 小時後完成。`, { kind: 'site-upgrade', site: site.id })">升級</button>
                <button v-if="site.refund" class="btn" :disabled="siteBusy"
                  @click="siteCommand(`拆掉${site.name}？\n\n空地馬上空出來，拿回 ${costText(site.refund) || '（沒有）'}。`, { kind: 'site-demolish', site: site.id })">拆掉</button>
              </div>
            </div>
          </li>
          <li v-for="n in freePlots" :key="`free-${n}`">
            <button class="site-row free" @click="picking = !picking"><b>空地</b><span class="grow makes">可以蓋一個場地</span></button>
          </li>
        </ul>
        <div v-if="picking && freePlots > 0" class="pick">
          <p v-if="production.busy" class="muted small">一次只能蓋一個，等現在的蓋好。</p>
          <button v-for="b in production.buildable" :key="b.kind" class="build" :disabled="siteBusy || !!production.busy || !affordable(b.cost)"
            @click="siteCommand(`蓋${b.name}？\n\n要 ${costText(b.cost)}，${b.hours} 小時後完成。`, { kind: 'site-build', site: b.kind })">
            <b>{{ b.name }}</b>
            <small>每小時 {{ makesText(b.makes) }}</small>
            <small :class="{ short: !affordable(b.cost) }">{{ costText(b.cost) }}</small>
          </button>
        </div>
        <p class="muted small">沒有場地也會撿一點木材、石頭。空地隨營地長大變多（2／4／6 格），大世界的種族每 5 級再多 1 格。</p>
        <p v-if="siteProblem" class="warn">{{ siteProblem }}</p>
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

      <section class="panel sanctuary" :class="{ on: !!view.sanctuary?.since }">
        <div class="row">
          <div class="grow">
            <h2>✨ 聖光模式 <small>{{ view.sanctuary?.since ? "開啟中" : "關閉" }}</small></h2>
            <p class="muted small">
              沒空玩的時候用：不會有魔獸來襲，大世界裡別人也打不了你（你也不能打別人，打怪可以）。代價是營地 120 隻以上時生得慢一半。關掉之後要 12 小時才能再開。
            </p>
          </div>
          <button class="btn" :class="{ primary: !view.sanctuary?.since }" :disabled="sanctuaryBusy || !sanctuaryCanOn" @click="toggleSanctuary">
            {{ view.sanctuary?.since ? "關掉" : "開啟" }}
          </button>
        </div>
        <p v-if="!view.sanctuary?.since && !sanctuaryCanOn" class="muted small">{{ noteTime(view.sanctuary!.canTurnOnAt!) }} 之後才能再開。</p>
        <p v-if="sanctuaryProblem" class="warn">{{ sanctuaryProblem }}</p>
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

      <nav class="shortcuts">
        <NuxtLink to="/workshop" class="btn">🔨 工坊（做裝備、現有裝備、修理）</NuxtLink>
        <NuxtLink to="/roster" class="btn">📜 名冊（換裝備）</NuxtLink>
      </nav>

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
.sanctuary .row { display: flex; gap: 12px; align-items: flex-start; }
.sanctuary .grow { flex: 1; min-width: 0; }
.sanctuary h2 small { font-size: 12px; color: #888; margin-left: 6px; }
.sanctuary.on { background: #fff8dc; border: 2px solid #e8c54a; }
.sanctuary .warn { color: #b3412c; }
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
.small { font-size: 13px; }
.shortcuts { display: grid; gap: 8px; margin-top: 14px; }
.shortcuts .btn { text-align: center; text-decoration: none; }
.sites { list-style: none; margin: 8px 0 0; padding: 0; display: grid; gap: 6px; }
.site-row { width: 100%; display: flex; align-items: baseline; gap: 8px; border: 1px solid var(--line); background: #faf8f0; border-radius: 10px; padding: 9px 10px; text-align: left; cursor: pointer; font: inherit; color: inherit; }
.site-row small { color: var(--muted); font-size: 12px; white-space: nowrap; }
.site-row .makes { min-width: 0; font-size: 13px; color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: right; }
.site-row.free { border-style: dashed; background: none; }
.open .site-row { border-color: var(--green); }
.site-more { padding: 6px 4px 4px; }
.actions { display: flex; gap: 8px; margin-top: 8px; }
.pick { display: grid; gap: 6px; margin-top: 8px; }
.build { display: grid; gap: 2px; text-align: left; border: 1px solid var(--line); background: #fff; border-radius: 10px; padding: 8px 10px; font: inherit; color: inherit; cursor: pointer; }
.build:disabled { opacity: 0.55; cursor: default; }
.build small { color: var(--muted); font-size: 12px; }
.short { color: var(--red) !important; }
.chips li.short { color: var(--red); }
.upgrading { margin-top: 10px; font-weight: 600; }
.production .warn { color: #b3412c; }
.production .chips { margin-top: 6px; }
.world-links { display: flex; gap: 6px; }
.world-links .icon-btn { padding: 6px 10px; font-size: 18px; line-height: 1.2; }
</style>
