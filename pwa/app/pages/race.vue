<script setup lang="ts">
import type { RaceSwitchView, WorldMe } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 換族 (RACES_SWITCH.md): what switching would take, said plainly first, then one card for each race the camp could become
// with its price (materials by the race level, and five of that race's 信物). Switching asks once more, with the race's
// name typed in. The Mac opens this page from its menu's 「種族：…」.
const ok = await useSignedIn();
const world = useWorld();
const { set: setRace } = useRace();
const { ask } = useConfirm();
const NAMES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈", beast: "獸人" };
const TOKEN_FROM: Record<string, string> = { goblin: "野蠻人營地、盜賊窩、強獸人軍團", elf: "古樹林", undead: "黑暗墓穴", beast: "洞穴熊" };

const view = ref<RaceSwitchView | null>(null);
const problem = ref("");
const message = ref("");
const busy = ref(false);
async function load() {
  try {
    view.value = await api<RaceSwitchView>("GET", "world/race");
    problem.value = "";
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  }
}
onMounted(load);

const waiting = computed(() => (view.value?.readyAt && Date.parse(view.value.readyAt) > Date.now() ? new Date(view.value.readyAt) : null));
const dateText = (d: Date) => d.toLocaleString("zh-TW", { month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" });

async function choose(race: string) {
  const v = view.value;
  if (!v) return;
  const name = NAMES[race] ?? race;
  const yes = await ask({
    title: `換成${name}？`,
    body: [
      `種族等級 Lv${v.level} → Lv${v.levelAfter}`,
      `居民大約 ${v.residents} → ${v.residentsAfter} 隻（隨機走掉，身上的裝備收回倉庫）`,
      v.cellsLost ? `主營周圍以外的 ${v.farCells} 塊領地，隨機丟掉 ${v.cellsLost} 塊` : "領地都保得住",
      "天賦全部重置、點數退回；公主換成新種族的首領，故事從頭開始",
      `之後 ${v.cooldownDays} 天不能再換。換回以前的種族也一樣從頭算。`,
    ].join("\n"),
    yes: `換成${name}`,
    danger: true,
    typed: name,
  });
  if (!yes) return;
  busy.value = true;
  problem.value = "";
  try {
    const out = await api<{ switched: { to: string; levelTo: number; left: number; cellsLost: string[] }; me: WorldMe }>("POST", "world/race", { race });
    setRace(out.switched.to);
    world.state.me = out.me;
    message.value = `營地變成${name}了：種族 Lv${out.switched.levelTo}，走掉了 ${out.switched.left} 隻${out.switched.cellsLost.length ? `，放掉了 ${out.switched.cellsLost.length} 塊領地` : ""}。`;
    await load();
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <main v-if="ok" class="page race">
    <WorldHead title="換族" :sub="view ? `現在：${NAMES[view.race] ?? view.race} Lv${view.level}` : undefined" />
    <ConfirmDialog />
    <div v-if="!view" class="panel">{{ problem || "讀取中…" }}</div>
    <template v-else>
      <section class="panel">
        <h2>換族會怎樣</h2>
        <p v-if="view.first" class="first">第一次換族比較輕：素材只要一半，損失也減半。</p>
        <ul class="loss">
          <li><b>等級</b> Lv{{ view.level }} → Lv{{ view.levelAfter }}</li>
          <li><b>居民</b> 大約 {{ view.residents }} → {{ view.residentsAfter }} 隻（營地和每塊領地分開算，隨機走掉）</li>
          <li><b>領地</b> 主營那格和旁邊 6 格保住；其他 {{ view.farCells }} 塊隨機丟 {{ view.cellsLost }} 塊（城鎮也可能丟）</li>
          <li><b>天賦</b> 全部重置，{{ view.talentPoints }} 點退回（新種族的天賦樹從頭點）</li>
          <li><b>公主</b> 換成新種族的首領，感情線從頭開始</li>
          <li><b>留著</b> 建築、場地等級、倉庫和素材（扣掉費用）</li>
        </ul>
        <p class="muted small">種族 {{ view.minLevel }} 級以上才能換；換完 {{ view.cooldownDays }} 天才能再換。換回以前玩過的種族也一樣從頭算。</p>
        <p v-if="view.level < view.minLevel" class="warn">現在 {{ view.level }} 級，還要升到 {{ view.minLevel }} 級。</p>
        <p v-if="waiting" class="warn">上次換族之後要等到 {{ dateText(waiting) }} 才能再換。</p>
        <p v-if="view.travelling" class="warn">還有 {{ view.travelling }} 支隊伍在路上：等它們到了，或先撤回再換。</p>
      </section>

      <section v-for="o in view.options" :key="o.race" class="panel option">
        <h3>換成{{ NAMES[o.race] ?? o.race }}</h3>
        <ul class="price">
          <li v-for="p in o.price" :key="p.id" :class="{ short: p.have < p.need }">
            {{ p.name }} <b>{{ p.have.toLocaleString() }} / {{ p.need.toLocaleString() }}</b>
          </li>
        </ul>
        <p class="muted small">信物從{{ TOKEN_FROM[o.race] }}掉（種族 10 級以上打贏才會掉，每次大約 1/4）。</p>
        <p v-if="o.problem && !(view.level < view.minLevel) && !waiting && !view.travelling" class="warn">{{ o.problem }}</p>
        <button class="btn danger" :disabled="busy || !!o.problem" @click="choose(o.race)">換成{{ NAMES[o.race] ?? o.race }}…</button>
      </section>
      <p v-if="message" class="ok">{{ message }}</p>
      <p v-if="problem" class="warn">{{ problem }}</p>
    </template>
  </main>
</template>

<style scoped>
section { margin-top: 12px; }
h2, h3 { margin: 0 0 8px; font-size: 17px; }
.first { background: #eef7e8; border-radius: 10px; padding: 6px 10px; margin: 0 0 8px; font-weight: 600; }
.loss, .price { margin: 0; padding-left: 18px; line-height: 1.7; }
.loss b { display: inline-block; min-width: 3em; }
.price li.short b { color: #b3412c; }
.option .btn { margin-top: 8px; }
.ok { color: var(--green); font-weight: 600; margin: 12px 4px; }
.warn { color: #b3412c; margin: 6px 0 0; }
.small { font-size: 12px; }
.muted { color: var(--muted); }
</style>
