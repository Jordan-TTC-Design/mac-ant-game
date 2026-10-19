<script setup lang="ts">
import {
  cannotLearn,
  materialName,
  pointsIn,
  pointsSpent,
  rowOpen,
  TALENT_ROW_LEVELS,
  TALENT_ROW_POINTS,
  talentBonus,
  talentRule,
  talentsIn,
  talentText,
  treesFor,
  type Talent,
  type TalentEffect,
  type TalentPicks,
  type WorldMe,
} from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 種族天賦 (shared/src/world/talents.ts): the race's four trees side by side (one at a time on a phone), like an old talent
// tree. Tapping a talent puts a point in it for now (tap ↩︎ to take it back); 確定 buys them all; 重置 takes every talent back
// for crystal shards and amber. The camp's tree works in the camp, the others in the big world.
const ok = await useSignedIn();
const world = useWorld();
const s = world.state;
const { race, noun } = useRace();
onMounted(() => void world.open());
onUnmounted(() => world.close());

const me = computed<WorldMe | null>(() => s.me);
const level = computed(() => me.value?.level ?? 1);
const bought = computed<TalentPicks>(() => me.value?.talents?.picks ?? {});
/** Points put in for now, on top of what is bought (not sent until 確定). */
const planned = ref<TalentPicks>({});
const picks = computed<TalentPicks>(() => {
  const out = { ...bought.value };
  for (const [id, r] of Object.entries(planned.value)) out[id] = (out[id] ?? 0) + r;
  return out;
});
const points = computed(() => me.value?.talents?.points ?? 0);
const left = computed(() => points.value - pointsSpent(picks.value));
const trees = computed(() => treesFor(race.value));
const tab = ref(0);
const chosen = ref<string | null>(null);
const chosenRule = computed(() => (chosen.value ? talentRule(chosen.value) : undefined));
watch(trees, () => (chosen.value = null));

const rank = (id: string) => picks.value[id] ?? 0;
const why = (id: string) => cannotLearn(race.value, level.value, picks.value, id);
const open = (tree: string, row: number) => rowOpen(picks.value, tree, row, level.value);
/** A talent's look: maxed, some ranks, can take one now, or not yet. */
function state(x: Talent): "max" | "some" | "can" | "locked" {
  if (rank(x.id) >= x.ranks) return "max";
  if (rank(x.id) > 0) return "some";
  return why(x.id) ? "locked" : "can";
}
function add(x: Talent) {
  chosen.value = x.id;
  if (why(x.id)) return;
  planned.value = { ...planned.value, [x.id]: (planned.value[x.id] ?? 0) + 1 };
}
/** Takes back the last point put in for now (only those not bought yet), lowest row first so nothing is left hanging. */
function undo(x: Talent) {
  const now = planned.value[x.id] ?? 0;
  if (!now) return;
  const next = { ...planned.value, [x.id]: now - 1 };
  if (!next[x.id]) delete next[x.id];
  // whatever no longer stands without it comes off too
  const keep: TalentPicks = {};
  const base = { ...bought.value };
  for (const id of Object.keys(next).sort((a, b) => (talentRule(a)?.row ?? 0) - (talentRule(b)?.row ?? 0))) {
    for (let k = 0; k < next[id]!; k++) {
      if (cannotLearn(race.value, level.value, base, id)) break;
      base[id] = (base[id] ?? 0) + 1;
      keep[id] = (keep[id] ?? 0) + 1;
    }
  }
  planned.value = keep;
}

/** What all the talents (bought and planned) add up to, in words, by tree. */
const summary = computed(() => {
  const bonus = talentBonus(picks.value);
  const sample = new Map<TalentEffect, Talent>();
  for (const t of trees.value.flatMap((x) => talentsIn(x.id))) if (!sample.has(t.effect)) sample.set(t.effect, t);
  return [...sample.entries()].filter(([e]) => bonus[e]).map(([e, t]) => talentText({ ...t, per: bonus[e], effect: e }, 1));
});

const busy = ref(false);
const message = ref("");
const problem = ref("");
async function confirm() {
  busy.value = true;
  problem.value = "";
  try {
    s.me = await api<WorldMe>("POST", "world/talents", { picks: picks.value });
    planned.value = {};
    message.value = "天賦點好了。";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
const asking = ref(false);
const resetCost = computed(() => me.value?.talents?.resetCost ?? {});
const costText = computed(() => Object.entries(resetCost.value).map(([id, n]) => `${materialName(id)} ×${n}`).join("、"));
async function reset() {
  asking.value = false;
  busy.value = true;
  problem.value = "";
  try {
    s.me = await api<WorldMe>("POST", "world/talents/reset", {});
    planned.value = {};
    message.value = "所有天賦都重置了，點數拿回來了。";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}

/** Lines from a talent down to the one that needs it (column centres, row middles), for each tree's picture. */
const links = (tree: string) =>
  talentsIn(tree).flatMap((x) => {
    const up = x.requires ? talentRule(x.requires) : undefined;
    return up ? [{ id: x.id, x1: up.col, y1: up.row, x2: x.col, y2: x.row, lit: rank(up.id) >= up.ranks }] : [];
  });
const ICON: Record<TalentEffect, string> = {
  travel: "👣", regionTravel: "🛤️", attack: "⚔️", pvpAttack: "🏴", lairAttack: "🐉", hp: "❤️", fort: "🛡️", homeFort: "🏰", yield: "🌾",
  nest: "🥚", room: "🏠", party: "👥", reinforce: "📯", upkeep: "🍞", freeCells: "🗺️", wear: "🔨", market: "⚖️", loot: "💰", xp: "📖",
  intel: "👁️", campYield: "🏗️", campBirths: "👶", campGuard: "🗡️", campRanch: "🐐", campBuild: "⏱️", campLife: "⏳", campHost: "🤝", campTrade: "🧳", campHeart: "💖",
  plunder: "🏴‍☠️", tunnels: "🕳️", refine: "⭐", ambush: "🎯", sacredTree: "🌲", moonGate: "🌙", raiseDead: "🧟", nightRaid: "🌑", blight: "☠️",
};
</script>

<template>
  <main v-if="ok" class="page talents">
    <WorldHead title="種族天賦" :sub="`${noun} Lv${level}・天賦點 ${points - left} / ${points}`" />
    <div v-if="!me" class="panel">{{ s.problem || "讀取中…" }}</div>
    <div v-else-if="!me.open && !me.talents" class="panel">開啟大世界之後，種族等級每升一級就有一個天賦點。</div>
    <template v-else>
      <section class="panel head">
        <div class="pts"><b>{{ left }}</b><small>剩下的點數</small></div>
        <div class="sum">
          <details v-if="summary.length">
            <summary class="muted">目前的天賦加成（{{ summary.length }} 項）</summary>
            <p>{{ summary.join("、") }}</p>
          </details>
          <p v-else class="muted">還沒點。點一個亮著的天賦開始。</p>
        </div>
        <div class="ops">
          <button class="btn primary" :disabled="busy || !Object.keys(planned).length" @click="confirm">確定（{{ pointsSpent(planned) }} 點）</button>
          <button class="btn" :disabled="busy || !Object.keys(planned).length" @click="planned = {}">取消</button>
          <button v-if="!asking" class="btn" :disabled="busy || !Object.keys(bought).length" @click="asking = true">重置…</button>
        </div>
        <div v-if="asking" class="ask">
          <p>把所有天賦拿回來重點？要花 <b>{{ costText }}</b>（每重置一次就更貴）。</p>
          <button class="btn danger" :disabled="busy" @click="reset">確定重置</button>
          <button class="btn" @click="asking = false">再想想</button>
        </div>
        <p v-if="message" class="ok">{{ message }}</p>
        <p v-if="problem" class="warn">{{ problem }}</p>
      </section>

      <nav class="tabs">
        <button v-for="(x, i) in trees" :key="x.id" :class="{ on: tab === i }" @click="tab = i">{{ x.icon }} {{ x.name }} <small>{{ pointsIn(picks, x.id) }}</small></button>
      </nav>

      <div class="trees">
        <section v-for="(x, i) in trees" :key="x.id" class="panel tree" :class="{ shown: tab === i }">
          <h2>{{ x.icon }} {{ x.name }} <small>{{ pointsIn(picks, x.id) }} 點</small></h2>
          <p class="muted small">{{ x.blurb }}</p>
          <div class="grid">
            <svg class="links" viewBox="0 0 3 5" preserveAspectRatio="none" aria-hidden="true">
              <line v-for="l in links(x.id)" :key="l.id" :x1="l.x1 + 0.5" :y1="l.y1 + 0.5" :x2="l.x2 + 0.5" :y2="l.y2 + 0.5" :class="{ lit: l.lit }" vector-effect="non-scaling-stroke" />
            </svg>
            <template v-for="row in 5" :key="row">
              <div v-if="!open(x.id, row - 1)" class="lock" :class="{ mid: !talentsIn(x.id).some((t) => t.row === row - 1 && t.col === 1) }" :style="{ gridRow: row }">
                <small>{{ level < TALENT_ROW_LEVELS[row - 1]! ? `Lv${TALENT_ROW_LEVELS[row - 1]}` : `再點 ${(row - 1) * TALENT_ROW_POINTS - pointsIn(picks, x.id)} 點` }}</small>
              </div>
            </template>
            <button
              v-for="t in talentsIn(x.id)"
              :key="t.id"
              class="node"
              :class="[state(t), { picked: chosen === t.id, planned: planned[t.id], top: t.row === 4 }]"
              :style="{ gridRow: t.row + 1, gridColumn: t.col + 1 }"
              :title="t.name"
              @click="add(t)"
              @contextmenu.prevent="undo(t)"
            >
              <span class="ic">{{ ICON[t.effect] }}</span>
              <span class="rk">{{ rank(t.id) }}/{{ t.ranks }}</span>
            </button>
          </div>
        </section>
      </div>

      <section v-if="chosenRule" class="panel detail">
        <h3>{{ ICON[chosenRule.effect] }} {{ chosenRule.name }} <small>{{ rank(chosenRule.id) }}/{{ chosenRule.ranks }}</small></h3>
        <p v-if="rank(chosenRule.id)">現在：{{ talentText(chosenRule, rank(chosenRule.id)) }}</p>
        <p v-if="rank(chosenRule.id) < chosenRule.ranks">{{ rank(chosenRule.id) ? "下一級" : "點了" }}：{{ talentText(chosenRule, rank(chosenRule.id) + 1) }}</p>
        <p v-if="why(chosenRule.id) && rank(chosenRule.id) < chosenRule.ranks" class="warn">{{ why(chosenRule.id) }}</p>
        <p class="muted small">第 {{ chosenRule.row + 1 }} 排：種族等級 {{ TALENT_ROW_LEVELS[chosenRule.row] }}，這棵樹上面點 {{ chosenRule.row * TALENT_ROW_POINTS }} 點才開。{{ chosenRule.tree.endsWith("_camp") ? "這棵樹的效果在營地。" : "效果在大世界。" }}</p>
        <button v-if="planned[chosenRule.id]" class="btn" @click="undo(chosenRule)">↩︎ 拿回剛點的一點</button>
      </section>
      <p class="muted small hint">點天賦放一點（還沒送出），確定才算數；點過的要重置才能拿回來。電腦上按右鍵也可以拿回剛點的。</p>
      <p class="muted small hint">想玩別的種族？<NuxtLink to="/race">看種族介紹、換族…</NuxtLink>（種族 10 級以上）</p>
    </template>
  </main>
</template>

<style scoped>
section { margin-top: 12px; }
.head { display: grid; grid-template-columns: auto 1fr; gap: 10px 14px; align-items: center; }
.pts { display: grid; justify-items: center; background: #2f4a2a; color: #ffe27a; border-radius: 12px; padding: 8px 14px; }
.pts b { font-size: 28px; line-height: 1; }
.pts small { color: #e8f0e0; font-size: 11px; }
.sum p { margin: 2px 0 0; font-size: 14px; }
.ops { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 6px; }
.ask { grid-column: 1 / -1; background: #fff3f0; border-radius: 10px; padding: 8px 10px; }
.ask p { margin: 0 0 6px; }
.ok { grid-column: 1 / -1; color: var(--green); font-weight: 600; margin: 0; }
.warn { color: #b3412c; margin: 4px 0; }
.tabs { display: flex; gap: 6px; margin-top: 12px; overflow-x: auto; }
.tabs button { flex: 1 1 0; min-width: 0; white-space: nowrap; border: 1px solid var(--line); background: #faf8f0; border-radius: 10px; padding: 8px 2px; font-size: 14px; font: inherit; font-weight: 700; cursor: pointer; color: inherit; }
.tabs button.on { background: var(--green); color: #fff; border-color: var(--green); }
.tabs small { opacity: 0.75; font-weight: 400; }
.trees .tree { display: none; }
.trees .tree.shown { display: block; }
.tree h2 { margin: 0; font-size: 17px; }
.tree h2 small { color: var(--muted); font-weight: 400; font-size: 13px; }
.grid { position: relative; display: grid; grid-template-columns: repeat(3, 1fr); grid-template-rows: repeat(5, 76px); justify-items: center; align-items: center; margin-top: 8px; padding: 4px 0; background: radial-gradient(ellipse at top, #3b5a35, #22371f); border-radius: 14px; }
.links { position: absolute; inset: 4px 0; width: 100%; height: calc(100% - 8px); pointer-events: none; }
.links line { stroke: #6b7a5e; stroke-width: 3; }
.links line.lit { stroke: #ffd84a; }
.lock { grid-column: 1 / -1; width: 100%; height: 100%; display: grid; place-items: center end; padding-right: 8px; box-sizing: border-box; background: rgba(0, 0, 0, 0.35); z-index: 2; pointer-events: none; }
.lock.mid { place-items: center; padding-right: 0; }
.lock small { color: #e8f0e0; background: rgba(0, 0, 0, 0.5); border-radius: 6px; padding: 2px 6px; font-weight: 700; }
.node { position: relative; z-index: 1; width: 54px; height: 54px; border-radius: 12px; border: 3px solid #555; background: #1c2618; display: grid; place-items: center; cursor: pointer; padding: 0; box-shadow: 0 2px 0 rgba(0, 0, 0, 0.4); }
.node .ic { font-size: 24px; filter: grayscale(1) opacity(0.5); }
.node .rk { position: absolute; right: -6px; bottom: -8px; background: #1f1f1f; color: #ccc; font-size: 11px; font-weight: 800; border-radius: 6px; padding: 1px 5px; }
.node.can { border-color: #7fd36b; box-shadow: 0 0 10px #7fd36b88; }
.node.can .ic, .node.some .ic, .node.max .ic { filter: none; }
.node.some { border-color: #7fd36b; }
.node.some .rk { color: #7fd36b; }
.node.max { border-color: #ffd84a; box-shadow: 0 0 12px #ffd84a88; }
.node.max .rk { color: #ffd84a; }
.node.top { width: 62px; height: 62px; border-radius: 50%; }
.node.top .ic { font-size: 28px; }
.node.planned { outline: 2px dashed #fff; outline-offset: 2px; }
.node.picked { transform: scale(1.08); }
.detail h3 { margin: 0 0 6px; }
.detail p { margin: 4px 0; }
.hint { margin: 10px 4px; }
.small { font-size: 12px; }
.muted { color: var(--muted); }
@media (min-width: 900px) {
  .page.talents { max-width: 1180px; }
  .tabs { display: none; }
  .trees { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
  .trees .tree { display: block; }
}
</style>
