<script setup lang="ts">
import { materialName, TERRAIN_NAMES } from "@goblincamp/shared/world";
import { outcomeText, placeText, wentWell } from "~/utils/worldText";
import { noteTime } from "~/utils/time";

// 大世界・戰報 (pwa/UI.md §4.3): the parties on the road, what happened in the big world lately, and the reports — what
// used to sit under the map.
const ok = await useSignedIn();
const world = useWorld();
const s = world.state;
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  clock = setInterval(() => (now.value = Date.now()), 1000);
  void world.open();
});
onUnmounted(() => {
  clearInterval(clock);
  world.close();
});
const lootText = (loot: Record<string, number>) => Object.entries(loot).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([id, n]) => `${materialName(id)} ${n}`).join("、");
const left = (iso: string) => {
  const sec = Math.max(0, Math.round((Date.parse(iso) - now.value) / 1000));
  return sec === 0 ? "到了，結算中…" : `${Math.floor(sec / 60)} 分 ${String(sec % 60).padStart(2, "0")} 秒後到`;
};
const cellName = (id: string) => {
  if (id === "home") return "營地";
  const c = s.cells.find((x) => x.cell === id);
  return c ? (c.owner ? `${c.owner.name}的領地` : c.lair ? c.lair.name : TERRAIN_NAMES[c.terrain]) : "遠方";
};
</script>

<template>
  <main v-if="ok" class="page">
    <WorldHead title="戰報" sub="在路上的隊伍、最近的事、每一場的結果" />
    <div v-if="!s.me" class="panel">{{ s.problem || "讀取中…" }}</div>
    <template v-else>
      <section v-if="s.me.incoming?.length" class="panel incoming">
        <h2>⚠️ 敵軍來襲</h2>
        <NuxtLink v-for="w in s.me.incoming" :key="w.id" :to="`/world?cell=${w.to}`" class="line">
          <b>{{ w.by.name }}</b> 派了 {{ w.party }} 隻 → 你的{{ w.where.kind === "home" ? "營地" : w.where.label }}<br />
          <small>{{ left(w.arriveAt) }}・點一下看那一格</small>
        </NuxtLink>
      </section>

      <section class="panel">
        <h2>在路上 <small>{{ s.me.walking.length }}</small></h2>
        <p v-if="!s.me.walking.length" class="muted">現在沒有隊伍在路上。</p>
        <p v-for="w in s.me.walking" :key="w.id" class="line">
          {{ w.party }} 隻 → {{ cellName(w.to) }}{{ { move: "（搬家）", guard: "（幫守）", recall: "（撤回）", reroute: "（找有空位的領地）", retreat: "（撤退）" }[w.kind as string] ?? "" }}<br />
          <small>{{ left(w.arriveAt) }}</small>
        </p>
      </section>

      <section class="panel">
        <h2>戰報</h2>
        <p v-if="!s.me.recent.length" class="muted">還沒有打過仗。</p>
        <NuxtLink v-for="r in s.me.recent" :key="r.id" :to="`/expedition/${r.id}`" class="report">
          <span :class="wentWell(r) ? 'won' : 'lost'">{{ outcomeText(r) }}</span>
          <span class="grow">{{ r.defending ? `${r.by ?? "有人"}來打${placeText(r) ? `：${placeText(r)}` : ""}` : r.outcome?.against }}</span>
          <small>{{ noteTime(r.arriveAt) }}</small>
        </NuxtLink>
      </section>

      <section v-if="s.me.happenings?.length" class="panel">
        <h2>最近的事</h2>
        <p v-for="(h, k) in s.me.happenings.slice(0, 12)" :key="k" class="line">
          <template v-if="h.lairBack">
            <span :class="h.lairBack.held ? 'won' : 'lost'">{{ h.lairBack.held ? "守住了" : "被搶回去了" }}</span>
            {{ h.lairBack.name }}（{{ h.lairBack.level }} 級）回來搶領地{{ h.lairBack.fallen ? `，倒下 ${h.lairBack.fallen} 隻` : "" }}{{ h.lairBack.held && Object.keys(h.lairBack.loot).length ? `，撿到 ${lootText(h.lairBack.loot)}` : "" }}
          </template>
          <template v-else-if="h.bossReward">
            <span class="won">世界魔王{{ h.bossReward.name }}倒下了</span>：出了 {{ Math.round(h.bossReward.share * 100) }}% 的力，分到 {{ lootText(h.bossReward.loot) }}，經驗 +{{ h.bossReward.xp }}
          </template>
          <template v-else-if="h.yields">領地送來了 {{ lootText(h.yields) }}</template>
          <br /><small>{{ noteTime(h.at) }}</small>
        </p>
      </section>
    </template>
  </main>
</template>

<style scoped>
h2 small { color: var(--muted); font-size: 13px; }
.muted { color: var(--muted); }
.line { display: block; margin: 0; padding: 10px 0; border-top: 1px solid var(--line); color: inherit; text-decoration: none; }
.line:first-of-type { border-top: 0; }
.line small { color: var(--muted); }
.incoming { background: #ffe1dc; }
.report { display: flex; align-items: center; gap: 10px; min-height: 48px; padding: 8px 0; border-top: 1px solid var(--line); color: inherit; text-decoration: none; }
.report .grow { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.report small { color: var(--muted); white-space: nowrap; }
.won { color: var(--green); font-weight: 800; white-space: nowrap; }
.lost { color: var(--red); font-weight: 800; white-space: nowrap; }
</style>
