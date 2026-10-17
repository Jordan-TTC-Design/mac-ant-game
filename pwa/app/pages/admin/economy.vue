<script setup lang="ts">
import type { EconomyReport } from "@goblincamp/shared/camp";
import { api } from "~/utils/api";
import { RACES, errText } from "~/utils/admin";

// 後台 › 經濟: what the camps hold, where materials come from and go, and how the race-level content is going.
const report = ref<EconomyReport | null>(null);
const span = ref<1 | 7 | 30>(7);
const problem = ref("");
const showAll = ref(false);

async function load() {
  problem.value = "";
  try {
    report.value = await api<EconomyReport>("GET", `admin/economy?days=${span.value}`);
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);
watch(span, load);

const n = (v: number) => Math.round(v).toLocaleString("zh-TW");
const pct = (a: number, b: number) => (b ? `${Math.round((a / b) * 100)}%` : "—");

// flows: the biggest source sets the bars' length
const flowTop = computed(() => Math.max(1, ...(report.value?.flows ?? []).map((f) => Math.max(f.in, f.out))));
const totalIn = computed(() => (report.value?.flows ?? []).reduce((s, f) => s + f.in, 0));
const totalOut = computed(() => (report.value?.flows ?? []).reduce((s, f) => s + f.out, 0));
const materials = computed(() => (showAll.value ? report.value?.materials : report.value?.materials.slice(0, 25)) ?? []);

// the chart: in and out day by day
const W = 600;
const H = 140;
const days = computed(() => report.value?.daily ?? []);
const top = computed(() => Math.max(1, ...days.value.map((d) => Math.max(d.in, d.out))));
const x = (i: number) => (days.value.length < 2 ? W / 2 : (i / (days.value.length - 1)) * W);
const y = (v: number) => H - 4 - (v / top.value) * (H - 12);
const path = (key: "in" | "out") => days.value.map((d, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(d[key]).toFixed(1)}`).join("");

const levels = computed(() => Object.entries(report.value?.players.byLevel ?? {}).sort(([a], [b]) => Number(a) - Number(b)));
const levelTop = computed(() => Math.max(1, ...levels.value.map(([, v]) => v)));
const VARIANTS: Record<string, string> = { plain: "一般", elite: "精英", poison: "毒", fire: "火", ice: "冰" };
</script>

<template>
  <div>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <section class="panel">
      <div class="chart-head">
        <h2>經濟</h2>
        <div class="chips">
          <button :class="{ on: span === 1 }" @click="span = 1">1 天</button>
          <button :class="{ on: span === 7 }" @click="span = 7">7 天</button>
          <button :class="{ on: span === 30 }" @click="span = 30">30 天</button>
        </div>
      </div>
      <template v-if="report">
        <div class="stats">
          <div><b>{{ report.players.camps }}</b><small>營地</small></div>
          <div><b>{{ report.players.active }}</b><small>{{ span }} 天內有動靜</small></div>
          <div><b>{{ n(totalIn) }}</b><small>進來的素材</small></div>
          <div><b>{{ n(totalOut) }}</b><small>花掉的素材</small></div>
          <div><b>{{ pct(totalOut, totalIn) }}</b><small>花掉／進來</small></div>
          <div><b>{{ n(report.contribution.left) }}</b><small>大家手上的貢獻</small></div>
        </div>
        <p class="small">
          營地：<span v-for="(v, race) in report.players.byRace" :key="race">{{ RACES[race] ?? race }} {{ v }}　</span>
          階段：<span v-for="(v, stage) in report.players.byStage" :key="stage">{{ stage }} 階 {{ v }}　</span>
        </p>
        <p class="small muted">素材從哪來、花去哪，是這次更新之後才開始記（營地的事件留 30 天）。「花掉／進來」越低，素材越容易越堆越多。</p>
      </template>
      <p v-else-if="!problem">讀取中…</p>
    </section>

    <template v-if="report">
      <section class="panel">
        <h2>每天進出</h2>
        <p class="small"><span class="key in">●</span> 進來　<span class="key out">●</span> 花掉</p>
        <svg v-if="days.length" :viewBox="`0 0 ${W} ${H}`" class="chart" preserveAspectRatio="none" role="img" aria-label="每天進來與花掉的素材">
          <line v-for="k in 3" :key="k" x1="0" :x2="W" :y1="y((top * k) / 3)" :y2="y((top * k) / 3)" class="grid" />
          <path :d="path('in')" class="line in" />
          <path :d="path('out')" class="line out" />
        </svg>
        <p v-if="days.length" class="small muted axis"><span>{{ days[0]?.day }}</span><span>最多 {{ n(top) }}</span><span>{{ days.at(-1)?.day }}</span></p>
        <p v-else class="small muted">還沒有紀錄。</p>
      </section>

      <div class="two">
        <section class="panel">
          <h2>從哪來、花去哪</h2>
          <div class="list">
            <div v-for="f in report.flows" :key="f.source">
              <div class="flow-head"><b>{{ f.name }}</b><span class="small">+{{ n(f.in) }}　−{{ n(f.out) }}</span></div>
              <div class="bars">
                <span class="bar in" :style="{ width: `${(f.in / flowTop) * 100}%` }" />
                <span class="bar out" :style="{ width: `${(f.out / flowTop) * 100}%` }" />
              </div>
              <p class="small muted">{{ f.top.map((m) => `${m.name} ${m.net > 0 ? "+" : ""}${n(m.net)}`).join("、") }}</p>
            </div>
            <p v-if="!report.flows.length" class="small muted">這段時間沒有紀錄。</p>
          </div>
        </section>

        <section class="panel">
          <h2>種族等級</h2>
          <div class="levels">
            <div v-for="[lv, v] in levels" :key="lv" class="lv">
              <span class="small">{{ lv }}</span>
              <span class="bar in" :style="{ width: `${(v / levelTop) * 100}%` }" />
              <span class="small">{{ v }}</span>
            </div>
          </div>
          <h2>最富有的營地</h2>
          <div class="list">
            <div v-for="r in report.richest" :key="r.name" class="row">
              <span>{{ r.name }}<span class="tag">{{ RACES[r.race] ?? r.race }} Lv{{ r.level }}</span></span>
              <b>{{ n(r.total) }}</b>
            </div>
          </div>
        </section>
      </div>

      <section class="panel">
        <h2>素材</h2>
        <table>
          <thead>
            <tr><th>素材</th><th>全部營地</th><th class="wide-only">有的營地</th><th>中位數</th><th class="wide-only">前 10%</th><th>進來</th><th>花掉</th></tr>
          </thead>
          <tbody>
            <tr v-for="m in materials" :key="m.id">
              <td>{{ m.name }}</td>
              <td>{{ n(m.total) }}</td>
              <td class="wide-only">{{ m.holders }}</td>
              <td>{{ n(m.median) }}</td>
              <td class="wide-only">{{ n(m.p90) }}</td>
              <td class="in-text">{{ m.in ? `+${n(m.in)}` : "" }}</td>
              <td class="out-text">{{ m.out ? `−${n(m.out)}` : "" }}</td>
            </tr>
          </tbody>
        </table>
        <button v-if="report.materials.length > 25" class="btn small" @click="showAll = !showAll">{{ showAll ? "只看前 25 種" : `全部 ${report.materials.length} 種` }}</button>
      </section>

      <div class="two">
        <section class="panel">
          <h2>突襲與等級王</h2>
          <div class="stats">
            <div><b>{{ report.raids.count }}</b><small>突襲</small></div>
            <div><b>{{ pct(report.raids.won, report.raids.count) }}</b><small>打退</small></div>
            <div><b>{{ report.raids.fallen }}</b><small>倒下的居民</small></div>
          </div>
          <p class="small">
            魔獸：<span v-for="(v, k) in report.raids.variants" :key="k">{{ VARIANTS[k] ?? k }} {{ v }}　</span>
          </p>
          <div class="list">
            <div v-for="b in report.raids.bosses" :key="b.level" class="row">
              <span>{{ b.level }} 級的等級王</span>
              <span>來了 {{ b.came }} 次・打倒 {{ b.beaten }}</span>
            </div>
            <p v-if="!report.raids.bosses.length" class="small muted">這段時間沒有等級王來。</p>
          </div>
        </section>

        <section class="panel">
          <h2>商人、來訪、公會</h2>
          <div class="list">
            <div class="row"><span>流浪商人來了</span><b>{{ report.merchant.visits }}</b></div>
            <div class="row"><span>跟商人交易</span><b>{{ report.merchant.trades }}</b></div>
            <div class="row"><span>公會商人賣出的裝飾（全部）</span><b>{{ report.merchant.guildBuys }}</b></div>
            <div class="row"><span>來訪者住進來</span><b>{{ report.visitors.accepted }}<span v-if="report.visitors.specials" class="tag gold">特殊 {{ report.visitors.specials }}</span></b></div>
            <div class="row"><span>來訪者被拒絕</span><b>{{ report.visitors.declined }}</b></div>
            <div class="row"><span>請居民離開</span><b>{{ report.visitors.dismissed }}</b></div>
            <div class="row"><span>捐給公會的貢獻（{{ span }} 天／全部）</span><b>{{ n(report.contribution.givenWindow) }}／{{ n(report.contribution.givenAll) }}</b></div>
            <div class="row"><span>花掉的貢獻（衣服、公會商人）</span><b>{{ n(report.contribution.spentAll) }}</b></div>
            <div class="row"><span>公會</span><b>{{ report.contribution.guilds }}</b></div>
          </div>
          <p class="small">公會等級：<span v-for="(v, lv) in report.contribution.guildLevels" :key="lv">{{ lv }} 級 {{ v }}　</span></p>
        </section>
      </div>
    </template>
  </div>
</template>

<style scoped>
.chart-head { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.chart-head h2 { margin: 0; }
.chart { width: 100%; height: 140px; display: block; }
.grid { stroke: var(--line); stroke-width: 1; vector-effect: non-scaling-stroke; }
.line { fill: none; stroke-width: 2; vector-effect: non-scaling-stroke; stroke-linejoin: round; }
.line.in, .key.in { stroke: var(--green); color: var(--green); }
.line.out, .key.out { stroke: var(--amber); color: var(--amber); }
.axis { display: flex; justify-content: space-between; }
.flow-head, .row { display: flex; justify-content: space-between; align-items: baseline; gap: 8px; }
.bars { display: flex; flex-direction: column; gap: 2px; margin: 4px 0; }
.bar { display: block; height: 6px; border-radius: 3px; min-width: 1px; }
.bar.in { background: var(--green); }
.bar.out { background: var(--amber); }
.levels { display: grid; gap: 3px; margin-bottom: 12px; }
.lv { display: grid; grid-template-columns: 2.5em 1fr 2.5em; align-items: center; gap: 6px; }
.in-text { color: var(--green); }
.out-text { color: var(--amber); }
h2 + .levels, .levels + h2 { margin-top: 8px; }
</style>
