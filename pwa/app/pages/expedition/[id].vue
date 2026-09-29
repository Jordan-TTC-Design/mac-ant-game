<script setup lang="ts">
import { materialName, type ExpeditionReport } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";
import { noteTime } from "~/utils/time";

// One expedition's report, and its fight played back blow by blow (the server fought it; this only replays the record).
const ok = await useSignedIn();
const route = useRoute();
const report = ref<ExpeditionReport | null>(null);
const problem = ref("");
const names = ref<ArtNames>({ races: {}, materials: {} });

const hp = reactive<Record<string, number>>({});
const step = ref(0);
const playing = ref(false);
const log = ref<string[]>([]);
let timer: ReturnType<typeof setInterval> | undefined;

onMounted(async () => {
  names.value = await loadArtNames();
  try {
    report.value = await api<ExpeditionReport>("GET", `world/expeditions/${route.params.id}`);
    reset();
    if (report.value.events?.length) play();
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
});
onUnmounted(() => clearInterval(timer));

const byId = computed(() => new Map((report.value?.fighters ?? []).map((f) => [f.id, f])));
const side = (s: "attack" | "defend") => (report.value?.fighters ?? []).filter((f) => f.side === s);
const who = (id: string) => {
  const f = byId.value.get(id);
  if (!f) return id;
  return f.name || (f.breed ? (names.value.races[f.race ?? "goblin"]?.breeds[f.breed] ?? f.breed) : "？");
};

function reset() {
  clearInterval(timer);
  playing.value = false;
  step.value = 0;
  log.value = [];
  for (const f of report.value?.fighters ?? []) hp[f.id] = f.hp;
}
function advance() {
  const e = report.value?.events[step.value];
  if (!e) {
    clearInterval(timer);
    playing.value = false;
    return;
  }
  step.value++;
  const a = who(e.actor);
  const t = who(e.target);
  if (e.kind === "hit") {
    hp[e.target] = Math.max(0, (hp[e.target] ?? 0) - (e.amount ?? 0));
    log.value.unshift(`${a} 打了 ${t}（${Math.round(e.amount ?? 0)}）`);
  } else if (e.kind === "heal") {
    const max = byId.value.get(e.target)?.hp ?? 0;
    hp[e.target] = Math.min(max, (hp[e.target] ?? 0) + (e.amount ?? 0));
    log.value.unshift(`${a} 幫 ${t} 補血（${Math.round(e.amount ?? 0)}）`);
  } else if (e.kind === "miss") {
    log.value.unshift(`${a} 沒打中 ${t}`);
  } else if (e.kind === "down") {
    hp[e.target] = 0;
    log.value.unshift(`${t} 倒下了`);
  } else if (e.kind === "rage") {
    log.value.unshift(`🩸 ${a} 狂化了！眼睛發紅，攻擊變得更兇猛`);
  }
  if (log.value.length > 6) log.value.length = 6;
}
function play() {
  if (playing.value) {
    clearInterval(timer);
    playing.value = false;
    return;
  }
  if (step.value >= (report.value?.events.length ?? 0)) reset();
  playing.value = true;
  timer = setInterval(advance, 180);
}
function skip() {
  clearInterval(timer);
  playing.value = false;
  while (step.value < (report.value?.events.length ?? 0)) advance();
}

const sheet = (f: { race?: string; breed?: string }) => `/sprites/${f.race ?? "goblin"}/${names.value.races[f.race ?? "goblin"]?.sheets[f.breed ?? "common"] ?? "worker"}.png`;
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <NuxtLink to="/world" class="icon-btn">← 大世界</NuxtLink>
      <h1>戰報</h1>
    </header>
    <div v-if="!report" class="panel">{{ problem || "讀取中…" }}</div>
    <template v-else>
      <section class="panel">
        <h2>
          <span :class="wentWell(report) ? 'won' : 'lost'">{{ outcomeText(report) }}</span>
        </h2>
        <p>{{ report.attacker?.name }} 派了 {{ report.party }} 隻 → {{ report.outcome?.against }}<br /><small class="muted">{{ noteTime(report.arriveAt) }} 到達</small></p>
        <template v-if="report.boss">
          <p>對{{ report.boss.name }}造成 <b>{{ report.outcome?.damage ?? report.boss.hpBefore - report.boss.hpAfter }}</b> 點傷害（{{ report.boss.hpBefore }} → {{ report.boss.hpAfter }} / {{ report.boss.maxHp }}）{{ report.boss.defeated ? "，打倒了！大家分到的東西會在下次打開營地時收進倉庫。" : "" }}</p>
        </template>
        <p v-if="report.outcome">倒下：我方 {{ report.defending ? report.outcome.killed : report.outcome.fallen }}・對方 {{ report.defending ? report.outcome.fallen : report.outcome.killed }}{{ report.outcome.xp ? `・經驗 +${report.outcome.xp}` : "" }}</p>
        <p v-if="report.outcome && Object.keys(report.outcome.loot).length" class="loot">
          撿到：<span v-for="(n, id) in report.outcome.loot" :key="id" class="chip">{{ materialName(String(id)) }} ×{{ n }}</span>
        </p>
      </section>

      <section v-if="report.events?.length" class="panel battle">
        <div class="sides">
          <div v-for="s in (['attack', 'defend'] as const)" :key="s" class="side">
            <h3>{{ s === "attack" ? report.attacker?.name : report.defender?.name ?? report.lair?.name }}</h3>
            <div v-for="f in side(s)" :key="f.id" class="fighter" :class="{ down: (hp[f.id] ?? 0) <= 0 }">
              <FoeIcon v-if="f.foe" :id="f.foe" :size="24" />
              <span v-else class="face pixel" :style="{ backgroundImage: `url(${sheet(f)})` }" />
              <span class="bar"><i :style="{ width: `${Math.max(0, ((hp[f.id] ?? 0) / f.hp) * 100)}%` }" /></span>
            </div>
          </div>
        </div>
        <ul class="log">
          <li v-for="(line, i) in log" :key="i + line" :style="{ opacity: 1 - i * 0.14 }">{{ line }}</li>
        </ul>
        <div class="controls">
          <button class="btn primary" @click="play">{{ playing ? "暫停" : step >= report.events.length ? "重播" : "播放" }}</button>
          <button class="btn" @click="skip">直接看結果</button>
          <small class="muted">{{ step }} / {{ report.events.length }}</small>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
section { margin-top: 14px; }
h2 { font-size: 18px; margin: 0 0 6px; }
h3 { font-size: 13px; margin: 0 0 6px; text-align: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
p { margin: 6px 0; line-height: 1.55; }
.muted { color: var(--muted); }
.won { color: var(--green); }
.lost { color: var(--red); }
.loot { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.chip { background: #f1eee2; border-radius: 8px; padding: 3px 8px; font-size: 13px; }
.sides { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.side { min-width: 0; }
.fighter { display: flex; align-items: center; gap: 6px; margin: 3px 0; transition: opacity 0.3s; }
.fighter.down { opacity: 0.3; }
.face { flex: none; width: 24px; height: 24px; background-size: 96px 72px; background-position: 0 0; image-rendering: pixelated; }
.bar { flex: 1; height: 8px; background: #e3ddd0; border-radius: 4px; overflow: hidden; }
.bar i { display: block; height: 100%; background: var(--green); transition: width 0.15s; }
.side:last-child .bar i { background: var(--red); }
.log { list-style: none; margin: 12px 0 8px; padding: 10px; background: #1f2a1c; color: #e8f0e0; border-radius: 10px; font-size: 13px; min-height: 120px; }
.controls { display: flex; align-items: center; gap: 8px; }
</style>
