<script setup lang="ts">
import { RACE_RANGE, residentAsFighter, type CampView } from "@goblincamp/shared/camp";
import { combatPower, residentFighter, travelMinutes, type CellView, type WorldMe } from "@goblincamp/shared/world";
import { api } from "~/utils/api";

// Sending a party (the big world): where from, who goes (the strongest few in one go, or one by one from the list), how
// strong they are against what waits there, and how long the walk is. The server checks it all again.
const props = defineProps<{
  target: CellView;
  /** attack: a lair, a great monster or another camp's cell; settle: move onto a free cell; move: more to a cell of ours. */
  kind: "attack" | "settle" | "move";
  me: WorldMe;
  race: string;
}>();
const emit = defineEmits<{ close: []; sent: [party: number[], settle: boolean, from: string] }>();

type Resident = CampView["residents"][number];
const camp = ref<CampView | null>(null);
const names = ref<ArtNames>({ races: {}, materials: {} });
onMounted(async () => {
  [camp.value, names.value] = await Promise.all([api<CampView>("GET", "camp"), loadArtNames()]);
});

const min = computed(() => props.me.rules.garrisonMin);
/** Where a party may set out from: the camp, or a held cell with more living there than it needs (not the target). */
const starts = computed(() => [
  { id: "home", label: `營地（在家 ${props.me.atHome} 隻）` },
  ...props.me.cells.filter((c) => c.garrison > min.value && c.cell !== props.target.cell).map((c) => ({ id: c.cell, label: `領地（住 ${c.garrison} 隻）` })),
]);
const from = ref("home");
const place = computed(() => (from.value === "home" ? "home" : `cell:${from.value}`));
const keep = computed(() => (from.value === "home" ? 2 : min.value));

const traits = computed(() => ({ id: props.race, ranged: RACE_RANGE[props.race] ?? 0 }));
const fighter = (r: Resident) => residentFighter(residentAsFighter(props.race, { id: r.id, breed: r.breed, gear: r.gear as never }, r.name ?? ""), "attack", traits.value);
const power = (r: Resident) => Math.round(combatPower([fighter(r)]));
/** Everyone at the starting place, strongest first. */
const available = computed(() =>
  (camp.value?.residents ?? [])
    .filter((r) => r.place === place.value)
    .map((r) => ({ r, power: power(r), gear: Object.keys(r.gear ?? {}).length }))
    .sort((a, b) => b.power - a.power || a.r.id - b.r.id),
);
const most = computed(() => Math.max(0, Math.min(60, available.value.length - keep.value, props.kind === "attack" ? 60 : props.me.rules.cellCapacity)));

// the party: picked one by one (ticks); starts as the best 10 for the job (the strongest to fight, plain ones to settle)
const picked = ref(new Set<number>());
const order = computed(() => (props.kind === "attack" ? available.value : [...available.value].reverse()));
function pickTop(n: number) {
  picked.value = new Set(order.value.slice(0, Math.min(n, most.value)).map((a) => a.r.id));
}
watch([available, most], () => pickTop(10), { immediate: true });
const party = computed(() => available.value.filter((a) => picked.value.has(a.r.id)));
function toggle(id: number) {
  const next = new Set(picked.value);
  if (next.has(id)) next.delete(id);
  else if (next.size < most.value) next.add(id);
  picked.value = next;
}

const ourPower = computed(() => Math.round(combatPower(party.value.map((a) => fighter(a.r)))));
const theirPower = computed(() => props.target.lair?.power ?? null);
const odds = computed(() => (theirPower.value ? ourPower.value / (ourPower.value + theirPower.value) : null));
const minutes = computed(() => {
  const start = from.value === "home" ? props.me.homeCell : from.value;
  if (!start || party.value.length === 0) return null;
  const slowest = Math.min(...party.value.map((a) => fighter(a.r).speed));
  return travelMinutes(start, props.target.cell, slowest);
});
const settle = ref(props.kind !== "move");
const title = computed(() => ({ attack: props.target.boss ? "出征打世界魔王" : "出征", settle: "派人去佔領", move: "派人去駐守" })[props.kind]);
const go = computed(() => ({ attack: "出發攻擊", settle: "出發佔領", move: "出發" })[props.kind]);
const ok = computed(() => party.value.length > 0 && (props.kind !== "settle" || party.value.length >= min.value));

const breedName = (b: string) => names.value.races[props.race]?.breeds[b] ?? b;
const sheet = (b: string) => `/sprites/${props.race}/${names.value.races[props.race]?.sheets[b] ?? "worker"}.png`;
</script>

<template>
  <div class="veil" @click.self="emit('close')">
    <div class="dialog" role="dialog" :aria-label="title">
      <header>
        <h2>{{ title }}</h2>
        <button class="x" aria-label="關閉" @click="emit('close')">✕</button>
      </header>

      <div class="body">
        <label v-if="starts.length > 1" class="field">
          <span>從哪裡出發</span>
          <select v-model="from">
            <option v-for="o in starts" :key="o.id" :value="o.id">{{ o.label }}</option>
          </select>
        </label>

        <div v-if="!camp" class="muted">讀取居民中…</div>
        <template v-else>
          <div class="compare">
            <div><small>我方戰力</small><b>{{ ourPower }}</b></div>
            <div v-if="theirPower !== null"><small>對方戰力</small><b>{{ theirPower }}</b></div>
            <div v-else-if="target.owner"><small>對方守軍</small><b>{{ target.garrison }} 隻</b></div>
            <div v-if="minutes !== null"><small>走過去</small><b>{{ minutes }} 分</b></div>
          </div>
          <div v-if="odds !== null" class="odds"><i :style="{ width: `${odds * 100}%` }" /></div>
          <p v-if="odds !== null" class="muted small">{{ odds > 0.65 ? "應該打得贏" : odds > 0.45 ? "差不多，有點冒險" : "看起來打不過，多派一點" }}</p>

          <div class="pickbar">
            <b>已選 {{ party.length }} 隻</b>
            <small class="muted">最多 {{ most }}（{{ from === "home" ? "營地至少留 2 隻" : `那一格至少留 ${min} 隻` }}）</small>
          </div>
          <div class="quick">
            <button class="chip" @click="pickTop(10)">{{ kind === "attack" ? "最強 10 隻" : "一般的 10 隻" }}</button>
            <button class="chip" @click="pickTop(most)">全部</button>
            <button class="chip" @click="picked = new Set()">清空</button>
          </div>
          <ul class="roster">
            <li v-for="a in available" :key="a.r.id" :class="{ on: picked.has(a.r.id) }" @click="toggle(a.r.id)">
              <span class="box">{{ picked.has(a.r.id) ? "✓" : "" }}</span>
              <span class="face pixel" :style="{ backgroundImage: `url(${sheet(a.r.breed)})` }" />
              <span class="who">{{ a.r.name || residentNameFromSeed(race, a.r.seed, a.r.legacySeed) }}<small>{{ breedName(a.r.breed) }}{{ a.gear ? `・裝備 ${a.gear} 件` : "" }}</small></span>
              <span class="pw"><small>戰力</small>{{ a.power }}</span>
            </li>
          </ul>

          <label v-if="kind === 'attack' && !target.boss" class="check"><input v-model="settle" type="checkbox" /> 打贏就留下來佔領（活下來的至少 {{ min }} 隻）</label>
          <p v-if="kind === 'settle' && party.length < min" class="warn">至少要 {{ min }} 隻才守得住一格。</p>
        </template>
      </div>

      <footer>
        <button class="btn" @click="emit('close')">取消</button>
        <button class="btn primary" :disabled="!ok" @click="emit('sent', party.map((a) => a.r.id), kind === 'move' ? false : kind === 'settle' ? true : settle, from)">{{ go }}（{{ party.length }} 隻）</button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.veil { position: fixed; inset: 0; z-index: 50; background: rgba(10, 16, 8, 0.55); display: flex; align-items: flex-end; justify-content: center; }
/* a sheet from the bottom on a phone, a window in the middle on a wide screen; the title and the buttons always show */
.dialog {
  width: 100%; max-width: 560px; max-height: 90dvh; display: flex; flex-direction: column; background: var(--card);
  border-radius: 18px 18px 0 0; box-shadow: 0 -4px 0 rgba(0, 0, 0, 0.25); animation: rise 0.18s ease-out;
}
@media (min-width: 640px) {
  .veil { align-items: center; }
  .dialog { border-radius: 18px; border: 3px solid #1f1f1f; box-shadow: 5px 5px 0 #1f1f1f; max-height: 86dvh; }
}
@keyframes rise { from { transform: translateY(40px); opacity: 0; } }
header { display: flex; align-items: center; padding: 14px 16px 8px; }
h2 { flex: 1; margin: 0; font-size: 18px; }
.x { border: 0; background: #eee; border-radius: 50%; width: 32px; height: 32px; font-size: 14px; cursor: pointer; }
.body { flex: 1; min-height: 0; overflow-y: auto; padding: 0 16px 8px; }
footer { display: flex; gap: 10px; padding: 10px 16px calc(env(safe-area-inset-bottom) + 12px); border-top: 1px solid var(--line); }
footer .btn { flex: 1; min-height: 46px; }
.field { display: grid; gap: 4px; margin: 4px 0 10px; font-size: 13px; color: var(--muted); }
.field select { border: 1px solid var(--line); border-radius: 9px; padding: 8px 10px; font-size: 16px; background: #fff; color: var(--ink); }
.muted { color: var(--muted); }
.small { font-size: 12px; margin: 4px 0; }
.compare { display: flex; gap: 8px; margin: 2px 0 6px; }
.compare div { flex: 1; background: #f3f0e4; border-radius: 10px; padding: 8px; text-align: center; display: grid; }
.compare small { font-size: 11px; color: var(--muted); }
.compare b { font-size: 18px; }
.odds { height: 8px; border-radius: 4px; background: #e0402f; overflow: hidden; }
.odds i { display: block; height: 100%; background: var(--green); }
.pickbar { display: flex; align-items: baseline; gap: 8px; margin: 12px 0 6px; }
.pickbar small { font-size: 12px; }
.quick { display: flex; gap: 6px; margin-bottom: 8px; }
.chip { border: 1px solid var(--line); background: #fff; border-radius: 999px; padding: 6px 12px; font-size: 13px; font-weight: 600; cursor: pointer; }
.roster { list-style: none; margin: 0 0 8px; padding: 0; border: 1px solid var(--line); border-radius: 10px; }
.roster li { display: flex; align-items: center; gap: 10px; padding: 7px 10px; border-top: 1px solid var(--line); cursor: pointer; user-select: none; }
.roster li:first-child { border-top: 0; }
.roster li.on { background: #eef8e6; }
.box { flex: none; width: 20px; height: 20px; border: 2px solid #9a9a8a; border-radius: 5px; display: grid; place-items: center; font-size: 13px; font-weight: 900; color: #fff; }
.on .box { background: var(--green); border-color: var(--green); }
.face { flex: none; width: 28px; height: 28px; background-size: 112px 84px; background-position: 0 0; image-rendering: pixelated; }
.who { flex: 1; min-width: 0; display: grid; font-weight: 600; }
.who small { font-weight: 400; color: var(--muted); font-size: 11px; }
.pw { display: grid; justify-items: end; font-weight: 700; }
.pw small { font-size: 10px; color: var(--muted); font-weight: 400; }
.check { display: flex; align-items: center; gap: 8px; margin: 10px 0 0; font-size: 14px; }
.check input { width: 20px; height: 20px; }
.warn { color: var(--red); font-size: 13px; font-weight: 600; }
</style>
