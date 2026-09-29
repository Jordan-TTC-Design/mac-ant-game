<script setup lang="ts">
import { RACE_RANGE, residentAsFighter, type CampView } from "@goblincamp/shared/camp";
import {
  BOOST_FOODS,
  BOOST_ITEMS,
  bossFighters,
  bossKind,
  boostCost,
  combatPower,
  estimateBattle,
  lairAt,
  lairFighters,
  planSupplies,
  RATIONS,
  RATIONS_PER_EXTRA,
  residentFighter,
  travelMinutes,
  GUESTS_MAX,
  WORLD_SEED,
  type CellView,
  type Fighter,
  type WorldMe,
} from "@goblincamp/shared/world";
import { api } from "~/utils/api";

// Sending a party (the big world): where from, who goes (the strongest few in one go, or one by one from the list), how
// strong they are against what waits there, and how long the walk is. The server checks it all again.
const props = defineProps<{
  target: CellView;
  /** attack: a lair, a great monster or another camp's cell; settle: move onto a free cell; move: more to a cell of ours. */
  kind: "attack" | "settle" | "move" | "guard";
  me: WorldMe;
  race: string;
}>();
const emit = defineEmits<{ close: []; sent: [party: number[], settle: boolean, from: string, supplies: Record<string, number>] }>();

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
  // (not the camp's own cell: everybody at home is there already)
  ...props.me.cells.filter((c) => c.garrison > min.value && c.cell !== props.target.cell && c.cell !== props.me.homeCell).map((c) => ({ id: c.cell, label: `領地（住 ${c.garrison} 隻）` })),
]);
const from = ref("home");
const place = computed(() => (from.value === "home" ? "home" : `cell:${from.value}`));
const keep = computed(() => (from.value === "home" ? 2 : min.value));

// food taken along (a fighting party only): rations let more go, boost foods make everyone stronger
const capped = computed(() => props.kind !== "move" && props.kind !== "guard");
const supplies = reactive<Record<string, number>>({});
const store = computed(() => props.me.food ?? {});
const rationsHeld = computed(() => Object.keys(RATIONS).reduce((n, id) => n + (store.value[id] ?? 0), 0));
const rationsTaken = computed(() => Object.keys(RATIONS).reduce((n, id) => n + (supplies[id] ?? 0), 0));
/** The cell it sets out from (its building: barracks let more go, a dock or an inn shortens the walk). */
const fromCell = computed(() => props.me.cells.find((c) => c.cell === (from.value === "home" ? props.me.homeCell : from.value)));
const cap = computed(() => (props.me.partyCap ?? 60) + (fromCell.value?.party ?? 0));
/** Rations to take: as many as it takes for the extra ones, from whichever kinds there are. */
function setExtra(n: number) {
  let need = n * RATIONS_PER_EXTRA;
  for (const id of Object.keys(RATIONS)) {
    const take = Math.min(store.value[id] ?? 0, need);
    supplies[id] = take;
    need -= take;
  }
}
const extra = computed(() => Math.min(Math.floor(cap.value / 2), Math.floor(rationsTaken.value / RATIONS_PER_EXTRA)));
const extraCanTake = computed(() => Math.min(Math.floor(cap.value / 2), Math.floor(rationsHeld.value / RATIONS_PER_EXTRA)));
const levelOf = (xp: number) => Math.floor(Math.sqrt(Math.max(0, xp) / 50)) + 1;
function toggleBoost(id: string) {
  supplies[id] = supplies[id] ? 0 : 1;
}

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
const most = computed(() =>
  Math.max(
    0,
    Math.min(
      60,
      available.value.length - keep.value,
      capped.value ? cap.value + extra.value : props.kind === "guard" ? GUESTS_MAX - (props.target.guests ?? 0) : props.me.rules.cellCapacity,
    ),
  ),
);

// the party: picked one by one (ticks); starts as the best 10 for the job (the strongest to fight, plain ones to settle)
const picked = ref(new Set<number>());
const order = computed(() => (props.kind === "attack" || props.kind === "guard" ? available.value : [...available.value].reverse()));
function pickTop(n: number) {
  picked.value = new Set(order.value.slice(0, Math.min(n, most.value)).map((a) => a.r.id));
}
watch([available, most], () => pickTop(capped.value ? most.value : 10), { immediate: true });
const party = computed(() => available.value.filter((a) => picked.value.has(a.r.id)));
function toggle(id: number) {
  const next = new Set(picked.value);
  if (next.has(id)) next.delete(id);
  else if (next.size < most.value) next.add(id);
  picked.value = next;
}

/** What the food does (and what it costs) for this party. */
const plan = computed(() => planSupplies(props.race, levelOf(props.me.xp), party.value.length, supplies, store.value, fromCell.value?.party ?? 0));
const armed = computed(() => party.value.map((a) => residentFighter(residentAsFighter(props.race, { id: a.r.id, breed: a.r.breed, gear: a.r.gear as never }), "attack", traits.value, plan.value.boosts)));
const ourPower = computed(() => Math.round(combatPower(armed.value)));
/** What waits there as the rules have it (a lair as it stands now: its wounds are shared by the map). */
const foes = computed<Fighter[] | null>(() => {
  const t = props.target;
  if (t.boss) {
    const kind = bossKind(t.boss.kind);
    return kind ? bossFighters(kind, t.boss.hp).map((f) => ({ ...f, side: "defend" as const })) : null;
  }
  if (!t.lair) return null;
  const lair = lairAt(WORLD_SEED, t.cell, t.terrain);
  if (!lair) return null;
  let list = lairFighters(lair);
  if (t.lairWounds) {
    const share = t.lairWounds.hpShare / Math.max(0.01, t.lairWounds.standing / t.lairWounds.total);
    list = list.slice(0, t.lairWounds.standing).map((f) => ({ ...f, hp: Math.max(1, Math.round(f.maxHp * Math.min(1, share))) }));
  }
  return list;
});
const theirPower = computed(() => props.target.lair?.power ?? null);
/** Fought out 40 times with different luck: how often it is won, and how many fall. */
const guess = computed(() => (foes.value && armed.value.length && !props.target.boss ? estimateBattle(armed.value, foes.value, 40) : null));
const odds = computed(() => guess.value?.win ?? (theirPower.value ? ourPower.value / (ourPower.value + theirPower.value) : null));
/** What would help, when it looks bad. */
const hints = computed(() => {
  if (!guess.value || guess.value.win >= 0.6) return [];
  const out: string[] = [];
  const bare = party.value.filter((a) => !a.gear).length;
  if (bare > 0) out.push(`${bare} 隻沒穿裝備：去工坊做武器和護甲，戰力會高很多`);
  if (extra.value < extraCanTake.value) out.push(`帶乾糧可以多派（每 ${RATIONS_PER_EXTRA} 份多 1 隻，最多多 ${Math.floor(cap.value / 2)} 隻）`);
  const unused = Object.entries({ ...BOOST_FOODS, ...BOOST_ITEMS }).filter(([id]) => !supplies[id] && (store.value[id] ?? 0) >= boostCost(party.value.length));
  if (unused.length) out.push(`帶${unused.map(([, f]) => f.name).join("、")}可以加成`);
  out.push("打輸了巢穴會留傷，趁牠還沒回血派第二波");
  return out;
});
const minutes = computed(() => {
  const start = from.value === "home" ? props.me.homeCell : from.value;
  if (!start || party.value.length === 0) return null;
  const slowest = Math.min(...party.value.map((a) => fighter(a.r).speed));
  return Math.max(1, Math.round(travelMinutes(start, props.target.cell, slowest) * (fromCell.value?.travel ?? 1)));
});
const settle = ref(props.kind !== "move" && props.kind !== "guard");
const title = computed(() => ({ attack: props.target.boss ? "出征打世界魔王" : "出征", settle: "派人去佔領", move: "派人去駐守", guard: `派兵幫${props.target.owner?.name ?? "好友"}守` })[props.kind]);
const go = computed(() => ({ attack: "出發攻擊", settle: "出發佔領", move: "出發", guard: "出發幫守" })[props.kind]);
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
          <p v-if="guess" class="muted small">
            勝率約 <b>{{ Math.round(guess.win * 100) }}%</b>・平均倒下 {{ guess.fallen.toFixed(1) }} 隻
            {{ guess.win >= 0.8 ? "（應該打得贏）" : guess.win >= 0.45 ? "（有點冒險）" : "（很難打贏）" }}
          </p>
          <p v-else-if="odds !== null" class="muted small">{{ odds > 0.65 ? "應該打得贏" : odds > 0.45 ? "差不多，有點冒險" : "看起來打不過" }}</p>
          <p v-if="target.lairWounds" class="muted small">巢穴受傷中：剩 {{ target.lairWounds.standing }}/{{ target.lairWounds.total }} 隻、{{ Math.round(target.lairWounds.hpShare * 100) }}% 血</p>
          <ul v-if="hints.length" class="hints">
            <li v-for="h in hints" :key="h">{{ h }}</li>
          </ul>

          <section v-if="capped" class="food">
            <div class="food-head">
              <b>帶食物</b>
              <small class="muted">一隊最多 {{ cap }} 隻（Lv{{ levelOf(me.xp) }}）{{ extra ? `＋乾糧 ${extra} 隻` : "" }}</small>
            </div>
            <div class="food-row">
              <span>乾糧 <small class="muted">倉庫 {{ rationsHeld }} 份・每 {{ RATIONS_PER_EXTRA }} 份多派 1 隻</small></span>
              <span class="stepper">
                <button class="chip" :disabled="extra <= 0" @click="setExtra(extra - 1)">−</button>
                <b>+{{ extra }} 隻</b>
                <button class="chip" :disabled="extra >= extraCanTake" @click="setExtra(extra + 1)">＋</button>
              </span>
            </div>
            <div class="boosts">
              <button
                v-for="(f, id) in { ...BOOST_FOODS, ...Object.fromEntries(Object.entries(BOOST_ITEMS).filter(([k]) => (store[k] ?? 0) > 0 || supplies[k])) }"
                :key="id"
                class="boost"
                :class="{ on: supplies[id] }"
                :disabled="!supplies[id] && (store[id] ?? 0) < boostCost(Math.max(1, party.length))"
                @click="toggleBoost(String(id))"
              >
                <b>{{ f.name }} <small>×{{ boostCost(Math.max(1, party.length)) }}</small></b>
                <small>{{ f.what }}・有 {{ store[id] ?? 0 }}</small>
              </button>
            </div>
            <p v-if="plan.problem && party.length" class="warn">{{ plan.problem }}</p>
          </section>

          <div class="pickbar">
            <b>已選 {{ party.length }} 隻</b>
            <small class="muted">最多 {{ most }}（{{ from === "home" ? "營地至少留 2 隻" : `那一格至少留 ${min} 隻` }}）</small>
          </div>
          <div class="quick">
            <button class="chip" @click="pickTop(capped ? most : 10)">{{ kind === "attack" || kind === "guard" ? `最強 ${capped ? most : 10} 隻` : `一般的 ${capped ? most : 10} 隻` }}</button>
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
          <p v-if="kind === 'guard'" class="muted small">牠們會住在那裡，巢穴回來搶、有人來打時一起守；戰死的裝備會回你的倉庫。你或對方隨時可以叫牠們回來。一格最多 {{ GUESTS_MAX }} 隻好友的居民（現在有 {{ target.guests ?? 0 }} 隻）。</p>
        </template>
      </div>

      <footer>
        <button class="btn" @click="emit('close')">取消</button>
        <button
          class="btn primary"
          :disabled="!ok || (capped && !!plan.problem)"
          @click="emit('sent', party.map((a) => a.r.id), kind === 'move' ? false : kind === 'settle' ? true : settle, from, capped ? plan.spent : {})"
        >{{ go }}（{{ party.length }} 隻）</button>
      </footer>
    </div>
  </div>
</template>

<style scoped>
.hints { margin: 4px 0 8px; padding-left: 18px; font-size: 13px; color: #8a4b00; line-height: 1.5; }
.food { border: 2px solid rgba(0, 0, 0, 0.1); border-radius: 12px; padding: 10px 12px; margin: 10px 0; background: #fbf7ea; }
.food-head { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; flex-wrap: wrap; }
.food-row { display: flex; justify-content: space-between; align-items: center; gap: 8px; margin-top: 8px; flex-wrap: wrap; }
.stepper { display: inline-flex; align-items: center; gap: 8px; }
.stepper .chip { min-width: 36px; }
.boosts { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-top: 8px; }
.boost { display: grid; gap: 1px; text-align: left; border: 2px solid rgba(0, 0, 0, 0.12); border-radius: 10px; padding: 6px 8px; background: #fff; cursor: pointer; }
.boost small { color: #666; font-size: 11px; }
.boost.on { border-color: #2f7a3a; background: #e3f3dc; }
.boost:disabled { opacity: 0.45; cursor: default; }
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
