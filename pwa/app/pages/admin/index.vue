<script setup lang="ts">
import type { AdminOverview, AdminStats } from "@goblincamp/shared";
import { api } from "~/utils/api";
import { RACES, errText } from "~/utils/admin";

// 後台 › 總覽: how the server is used now, and day by day.
const overview = ref<AdminOverview | null>(null);
const stats = ref<AdminStats | null>(null);
const span = ref<30 | 90>(30);
const problem = ref("");

async function load() {
  try {
    [overview.value, stats.value] = await Promise.all([api<AdminOverview>("GET", "admin/overview"), api<AdminStats>("GET", `admin/stats?days=${span.value}`)]);
  } catch (e) {
    problem.value = errText(e);
  }
}
onMounted(load);
watch(span, load);

const days = computed(() => stats.value?.days ?? []);
const today = computed(() => days.value.at(-1));
const yesterday = computed(() => days.value.at(-2));
const diff = (a = 0, b = 0) => (a === b ? "" : a > b ? `+${a - b}` : `${a - b}`);

// the chart: two lines (who came, who signed up) over the days
const W = 600;
const H = 140;
const top = computed(() => Math.max(1, ...days.value.map((d) => Math.max(d.active, d.signups))));
const x = (i: number) => (days.value.length < 2 ? 0 : (i / (days.value.length - 1)) * W);
const y = (n: number) => H - 4 - (n / top.value) * (H - 12);
const path = (key: "active" | "signups") => days.value.map((d, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(d[key]).toFixed(1)}`).join("");
const hover = ref<number | null>(null);
function onMove(e: PointerEvent) {
  const box = (e.currentTarget as SVGElement).getBoundingClientRect();
  const i = Math.round(((e.clientX - box.left) / box.width) * (days.value.length - 1));
  hover.value = Math.min(days.value.length - 1, Math.max(0, i));
}
const shown = computed(() => (hover.value === null ? today.value : days.value[hover.value]));
</script>

<template>
  <div>
    <div v-if="problem" class="panel status error">{{ problem }}</div>
    <template v-if="overview">
      <NuxtLink v-if="overview.feedbackOpen" to="/feedback" class="panel waiting">
        <b>📮 {{ overview.feedbackOpen }} 則回報還沒處理</b>
        <span>›</span>
      </NuxtLink>

      <section class="panel">
        <div class="stats">
          <div><b>{{ overview.users.all }}</b><small>帳號（{{ overview.users.verified }} 已驗證）</small></div>
          <div><b>{{ overview.users.active1 }}</b><small>24 小時內有用</small></div>
          <div><b>{{ overview.users.active7 }}</b><small>7 天內有用</small></div>
          <div><b>{{ overview.devices.macs }}</b><small>Mac</small></div>
          <div><b>{{ overview.devices.phones }}</b><small>手機</small></div>
          <div><b>{{ overview.notes }}</b><small>便利貼</small></div>
          <div><b>{{ overview.residents }}</b><small>活著的居民</small></div>
          <div><b>{{ overview.world.open }}</b><small>開了大世界</small></div>
          <div><b>{{ overview.world.heldCells }}</b><small>被佔的格子</small></div>
          <div><b>{{ overview.world.walking }}</b><small>路上的隊伍</small></div>
          <div><b>{{ overview.world.fought }}</b><small>打過的仗</small></div>
          <div><b>{{ overview.invites.free }}</b><small>可用的邀請碼</small></div>
        </div>
        <p v-if="Object.keys(overview.camps).length" class="small">營地：<span v-for="(n, race) in overview.camps" :key="race">{{ RACES[race] ?? race }} {{ n }}　</span></p>
      </section>

      <section v-if="stats" class="panel">
        <div class="chart-head">
          <h2>每天</h2>
          <div class="chips">
            <button :class="{ on: span === 30 }" @click="span = 30">30 天</button>
            <button :class="{ on: span === 90 }" @click="span = 90">90 天</button>
          </div>
        </div>
        <p v-if="shown" class="small">
          <b>{{ shown.day }}</b>　
          <span class="key active">●</span> 來的人 {{ shown.active }}<template v-if="shown === today">（較前一天 {{ diff(today?.active, yesterday?.active) || "持平" }}）</template>　
          <span class="key signups">●</span> 註冊 {{ shown.signups }}
        </p>
        <svg :viewBox="`0 0 ${W} ${H}`" class="chart" preserveAspectRatio="none" role="img" aria-label="每天來的人與註冊數" @pointermove="onMove" @pointerleave="hover = null">
          <line v-for="k in 3" :key="k" x1="0" :x2="W" :y1="y((top * k) / 3)" :y2="y((top * k) / 3)" class="grid" />
          <path :d="path('active')" class="line active" />
          <path :d="path('signups')" class="line signups" />
          <line v-if="hover !== null" :x1="x(hover)" :x2="x(hover)" y1="0" :y2="H" class="cursor" />
        </svg>
        <p class="small muted axis"><span>{{ days[0]?.day }}</span><span>最多 {{ top }}</span><span>{{ today?.day }}</span></p>
        <p class="small muted">「來的人」：那一天（台灣時間）用過 Mac 或手機的帳號數，從這次更新開始記。</p>
      </section>
    </template>
    <div v-else-if="!problem" class="panel">讀取中…</div>
  </div>
</template>

<style scoped>
.waiting { display: flex; justify-content: space-between; align-items: center; text-decoration: none; background: #fff6d6; margin-bottom: 12px; }
.chart-head { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.chart-head h2 { margin: 0; }
.chart { width: 100%; height: 140px; display: block; touch-action: none; }
.grid { stroke: var(--line); stroke-width: 1; vector-effect: non-scaling-stroke; }
.line { fill: none; stroke-width: 2; vector-effect: non-scaling-stroke; stroke-linejoin: round; }
.line.active, .key.active { stroke: var(--green); color: var(--green); }
.line.signups, .key.signups { stroke: var(--amber); color: var(--amber); }
.cursor { stroke: var(--muted); stroke-dasharray: 3 3; vector-effect: non-scaling-stroke; }
.axis { display: flex; justify-content: space-between; }
</style>
