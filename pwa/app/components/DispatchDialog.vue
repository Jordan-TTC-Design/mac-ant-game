<script setup lang="ts">
import { RACE_RANGE, residentAsFighter, type CampView } from "@goblincamp/shared/camp";
import {
  BOOST_FOODS,
  BOOST_ITEMS,
  lairEntry,
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
  walkMinutes,
  GUESTS_MAX,
  WORLD_SEED,
  type CellView,
  type Fighter,
  type RoutePreview,
  type WorldMe,
} from "@goblincamp/shared/world";
import { api } from "~/utils/api";
import type { LastAttack } from "~/utils/again";

// Sending a party (the big world): where from, who goes (the strongest few in one go, or one by one from the list), how
// strong they are against what waits there, and how long the walk is. The server checks it all again.
const props = defineProps<{
  target: CellView;
  /** attack: a lair, a great monster or another camp's cell; settle: move onto a free cell; move: more to a cell of ours. */
  kind: "attack" | "settle" | "move" | "guard";
  me: WorldMe;
  race: string;
  /** Where it sets out from, when picked on the map first ("home" or a held cell). */
  start?: string;
  /** 再派一次: the last attack on this cell, to start from (those still there; the strongest fill in for the fallen). */
  again?: LastAttack | null;
}>();
const emit = defineEmits<{ close: []; sent: [party: number[], settle: boolean, from: string, supplies: Record<string, number>]; route: [way: RoutePreview | null] }>();

type Resident = CampView["residents"][number];
const camp = ref<CampView | null>(null);
const names = ref<ArtNames>({ races: {}, materials: {} });
onMounted(async () => {
  [camp.value, names.value] = await Promise.all([api<CampView>("GET", "camp"), loadArtNames()]);
});

const min = computed(() => props.me.rules.garrisonMin);
/** Where a party may set out from: the camp, or a held cell with more living there than it needs (not the target). */
const starts = computed(() => [
  { id: "home", label: "營地", n: props.me.atHome },
  // (not the camp's own cell: everybody at home is there already)
  ...props.me.cells.filter((c) => c.garrison > min.value && c.cell !== props.target.cell && c.cell !== props.me.homeCell).map((c) => ({ id: c.cell, label: "領地", n: c.garrison })),
]);
const firstStart = props.again?.from ?? props.start;
const from = ref(firstStart && starts.value.some((o) => o.id === firstStart) ? firstStart : "home");
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
/** What each place could send: as many of its strongest as may go from there, and their strength (no food counted). */
const startPower = computed(() => {
  const out = new Map<string, { n: number; power: number }>();
  if (!camp.value) return out;
  for (const o of starts.value) {
    const at = o.id === "home" ? "home" : `cell:${o.id}`;
    const fighters = camp.value.residents.filter((r) => r.place === at).map((r) => ({ f: fighter(r), p: power(r) }));
    const bonus = props.me.cells.find((c) => c.cell === (o.id === "home" ? props.me.homeCell : o.id))?.party ?? 0;
    const n = Math.max(0, Math.min(60, fighters.length - (o.id === "home" ? 2 : min.value), capped.value ? (props.me.partyCap ?? 60) + bonus : 60));
    const best = fighters.sort((a, b) => b.p - a.p).slice(0, n).map((x) => x.f);
    out.set(o.id, { n, power: Math.round(combatPower(best)) });
  }
  return out;
});
/** A lair lets in only so many (world/expedition.ts lairEntry); a great monster and another camp's cell do not. */
const entry = computed(() => (props.target.lair && !props.target.boss && !props.target.owner ? lairEntry(props.target.lair.count, props.target.lair.boss) : null));
const most = computed(() =>
  Math.max(
    0,
    Math.min(
      60,
      available.value.length - keep.value,
      capped.value ? cap.value + extra.value : props.kind === "guard" ? GUESTS_MAX - (props.target.guests ?? 0) : props.me.rules.cellCapacity,
      entry.value ?? 60,
    ),
  ),
);


// the party: picked one by one (ticks); starts as the best 10 for the job (the strongest to fight, plain ones to settle)
const picked = ref(new Set<number>());
const order = computed(() => (props.kind === "attack" || props.kind === "guard" ? available.value : [...available.value].reverse()));
function pickTop(n: number) {
  picked.value = new Set(order.value.slice(0, Math.min(n, most.value)).map((a) => a.r.id));
}
let repeat = props.again ?? null;
watch(
  [available, most],
  () => {
    pickTop(capped.value ? most.value : 10);
    if (!repeat || !camp.value) return;
    // the same ones as last time where they are still here, the strongest of the rest for those who are not, as many as fit
    const want = Math.min(repeat.party.length, most.value);
    const same = order.value.filter((a) => repeat!.party.includes(a.r.id)).slice(0, want);
    const others = order.value.filter((a) => !repeat!.party.includes(a.r.id)).slice(0, want - same.length);
    picked.value = new Set([...same, ...others].map((a) => a.r.id));
    for (const [id, n] of Object.entries(repeat.supplies)) supplies[id] = Math.min(n, store.value[id] ?? 0);
    if (props.kind === "attack") settle.value = repeat.settle;
    repeat = null;
  },
  { immediate: true },
);
const party = computed(() => available.value.filter((a) => picked.value.has(a.r.id)));
/** The whole list folds away (it is long): the quick picks above it are what is mostly used. */
const showRoster = ref(false);
const showBoosts = ref(false);
const boostsTaken = computed(() => Object.keys({ ...BOOST_FOODS, ...BOOST_ITEMS }).filter((id) => supplies[id]).length);
function toggle(id: number) {
  const next = new Set(picked.value);
  if (next.has(id)) next.delete(id);
  else if (next.size < most.value) next.add(id);
  picked.value = next;
}

// against another camp: the server knows who would stand up to the party (the strongest, as many as the cell has room for)
const scouted = ref<{ win: number; fallen: number; killed: number; facing: number; total: number } | null>(null);
let scouting: ReturnType<typeof setTimeout> | undefined;
watch(
  () => [props.kind, props.target.owner?.id, party.value.map((a) => a.r.id).join(","), JSON.stringify(supplies), from.value],
  () => {
    clearTimeout(scouting);
    scouted.value = null;
    if (props.kind !== "attack" || !props.target.owner || party.value.length === 0) return;
    scouting = setTimeout(async () => {
      try {
        scouted.value = await api("POST", "world/expeditions/estimate", {
          from: from.value,
          to: props.target.cell,
          residents: party.value.map((a) => a.r.id),
          supplies: Object.fromEntries(Object.entries(supplies).filter(([, n]) => n > 0)),
        });
      } catch {
        // (no guess: the button still works)
      }
    }, 400);
  },
  { immediate: true },
);

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
// the way there: round other camps' built-up land (the server knows whose is where); no way round, no going
const way = ref<RoutePreview | null>(null);
const wayProblem = ref("");
watch(
  from,
  async () => {
    way.value = null;
    wayProblem.value = "";
    try {
      way.value = await api<RoutePreview>("POST", "world/expeditions/route", { from: from.value, to: props.target.cell });
    } catch (e) {
      wayProblem.value = e instanceof Error ? e.message : String(e);
    }
    emit("route", way.value); // (the map draws it)
  },
  { immediate: true },
);
const noWay = computed(() => !!way.value && way.value.waypoints.length === 0);
const minutesFor = (meters: number) => {
  const slowest = Math.min(...party.value.map((a) => fighter(a.r).speed));
  return Math.max(1, Math.round(walkMinutes(meters, slowest) * (fromCell.value?.travel ?? 1)));
};
const minutes = computed(() => (way.value && !noWay.value && party.value.length ? minutesFor(way.value.meters) : null));
/** How much longer the way round is than straight there. */
const detour = computed(() => (way.value && !noWay.value && party.value.length && way.value.waypoints.length > 2 ? minutes.value! - minutesFor(way.value.straight) : 0));

// after a win: stay and hold the cell, or come home (remembered, apart for lairs and other camps' cells)
const settleKey = `goblincamp.settle.${props.target.owner ? "camp" : "lair"}`;
function rememberedSettle(): boolean {
  try {
    const v = localStorage.getItem(settleKey);
    if (v !== null) return v === "1";
  } catch {
    // (no storage: the default)
  }
  return true;
}
const settle = ref(props.kind === "attack" ? rememberedSettle() : props.kind === "settle");
function chooseSettle(v: boolean) {
  settle.value = v;
  try {
    localStorage.setItem(settleKey, v ? "1" : "0");
  } catch {
    // (it just will not be remembered)
  }
}
const title = computed(() => ({ attack: props.target.boss ? "出征打世界魔王" : "出征", settle: "派人去佔領", move: "派人去駐守", guard: `派兵幫${props.target.owner?.name ?? "好友"}守` })[props.kind]);
const go = computed(() => ({ attack: "出發攻擊", settle: "出發佔領", move: "出發", guard: "出發幫守" })[props.kind]);
const ok = computed(() => party.value.length > 0 && (props.kind !== "settle" || party.value.length >= min.value) && !!way.value && !noWay.value);

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
        <div v-if="starts.length > 1" class="field">
          <span>從哪裡出發</span>
          <div class="starts">
            <button v-for="o in starts" :key="o.id" class="start" :class="{ on: from === o.id }" @click="from = o.id">
              <b>{{ o.label }}</b>
              <small>{{ o.id === "home" ? "在家" : "住" }} {{ o.n }} 隻</small>
              <small v-if="startPower.get(o.id)">最強 {{ startPower.get(o.id)!.n }} 隻・戰力 <b>{{ startPower.get(o.id)!.power }}</b></small>
            </button>
          </div>
        </div>

        <div v-if="!camp" class="muted">讀取居民中…</div>
        <template v-else>
          <div class="compare">
            <div><small>我方戰力</small><b>{{ ourPower }}</b></div>
            <div v-if="theirPower !== null"><small>對方戰力</small><b>{{ theirPower }}</b></div>
            <div v-else-if="target.owner"><small>對方守軍</small><b>{{ target.garrison }} 隻</b></div>
            <div v-if="minutes !== null"><small>{{ detour ? `繞路 +${detour} 分` : "走過去" }}</small><b>{{ minutes }} 分</b></div>
          </div>
          <p v-if="noWay" class="warn">{{ way?.blockedBy?.name ?? "別人" }}的領地（有巢穴、建築或城鎮）擋在路上，繞不過去：先把擋路的那一格打下來，或從別的地方出發。</p>
          <p v-else-if="wayProblem" class="warn">{{ wayProblem }}</p>
          <div v-if="scouted" class="odds"><i :style="{ width: `${scouted.win * 100}%` }" /></div>
          <p v-if="scouted" class="muted small">
            對方會有 <b>{{ scouted.facing }}</b> 隻迎戰（最強的先上；全部 {{ scouted.total }} 隻，一格的地方有限，最多是你的 1.5 倍）。
            勝率約 <b>{{ Math.round(scouted.win * 100) }}%</b>・我方平均倒下 {{ scouted.fallen.toFixed(1) }}・打倒對方 {{ scouted.killed.toFixed(1) }} 隻
            {{ scouted.win >= 0.8 ? "（應該打得贏）" : scouted.win >= 0.45 ? "（有點冒險）" : "（很難打贏）" }}
          </p>
          <p v-else-if="target.owner && kind === 'attack' && party.length" class="muted small">估算中…</p>
          <div v-if="odds !== null && !target.owner" class="odds"><i :style="{ width: `${odds * 100}%` }" /></div>
          <p v-if="guess" class="muted small">
            勝率約 <b>{{ Math.round(guess.win * 100) }}%</b>・平均倒下 {{ guess.fallen.toFixed(1) }} 隻・打倒 {{ guess.killed.toFixed(1) }} 隻
            {{ guess.win >= 0.8 ? "（應該打得贏）" : guess.win >= 0.45 ? "（有點冒險）" : "（很難打贏）" }}
          </p>
          <p v-if="entry !== null" class="muted small">這個巢穴很小，一次最多只能進去 {{ entry }} 隻：靠裝備、道具和糧食取勝，不是人多。</p>
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
            <button class="fold" @click="showBoosts = !showBoosts">
              加成食物{{ boostsTaken ? `（帶了 ${boostsTaken} 樣）` : "" }} <span>{{ showBoosts ? "▴" : "▾" }}</span>
            </button>
            <div v-if="showBoosts" class="boosts">
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
            <button class="chip" :class="{ on: showRoster }" @click="showRoster = !showRoster">{{ showRoster ? "收起名單" : "逐隻挑選" }}</button>
            <button class="chip" @click="pickTop(capped ? most : 10)">{{ kind === "attack" || kind === "guard" ? `最強 ${capped ? most : 10} 隻` : `一般的 ${capped ? most : 10} 隻` }}</button>
            <button class="chip" @click="pickTop(most)">全部</button>
            <button class="chip" @click="picked = new Set()">清空</button>
          </div>
          <ul v-if="showRoster" class="roster">
            <li v-for="a in available" :key="a.r.id" :class="{ on: picked.has(a.r.id) }" @click="toggle(a.r.id)">
              <span class="box">{{ picked.has(a.r.id) ? "✓" : "" }}</span>
              <span class="face pixel" :style="{ backgroundImage: `url(${sheet(a.r.breed)})` }" />
              <span class="who">{{ a.r.name || residentNameFromSeed(race, a.r.seed, a.r.legacySeed) }}<small>{{ breedName(a.r.breed) }}{{ a.gear ? `・裝備 ${a.gear} 件` : "" }}</small></span>
              <span class="pw"><small>戰力</small>{{ a.power }}</span>
            </li>
          </ul>

          <div v-if="kind === 'attack' && !target.boss" class="after">
            <span>打贏後</span>
            <div class="seg">
              <button :class="{ on: settle }" @click="chooseSettle(true)">留下來佔領</button>
              <button :class="{ on: !settle }" @click="chooseSettle(false)">直接回家</button>
            </div>
            <small class="muted">{{ settle ? `活下來的至少 ${min} 隻才佔得住` : "撿了戰利品就回來" }}・下次會記得</small>
          </div>
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
.fold { display: flex; justify-content: space-between; width: 100%; margin-top: 8px; padding: 6px 0 0; border: 0; border-top: 1px dashed rgba(0, 0, 0, 0.15); background: none; font: inherit; font-weight: 600; cursor: pointer; text-align: left; }
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
.quick { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.quick .chip.on { background: #1f1f1f; color: #fff; }
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
.starts { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 6px; }
.start { display: grid; gap: 1px; text-align: left; border: 2px solid rgba(0, 0, 0, 0.12); border-radius: 10px; padding: 6px 9px; background: #fff; color: var(--ink); font: inherit; cursor: pointer; }
.start small { font-size: 11px; color: var(--muted); }
.start.on { border-color: #2f7a3a; background: #e3f3dc; }
.after { display: grid; gap: 4px; margin: 10px 0 0; font-size: 14px; font-weight: 600; }
.after small { font-size: 12px; font-weight: 400; }
.seg { display: flex; border: 2px solid #1f1f1f; border-radius: 10px; overflow: hidden; }
.seg button { flex: 1; border: 0; padding: 9px 6px; background: #fff; font: inherit; font-weight: 700; cursor: pointer; }
.seg button + button { border-left: 2px solid #1f1f1f; }
.seg button.on { background: var(--green); color: #fff; }
.warn { color: var(--red); font-size: 13px; font-weight: 600; }
</style>
