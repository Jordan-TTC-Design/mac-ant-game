<script setup lang="ts">
import { raceRules } from "@goblincamp/shared/camp";
import { treesFor, type RaceSwitchView, type WorldMe } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

// 種族 (RACES.md) and 換族 (RACES_SWITCH.md): each race told in full (race-info.ts), then what switching to it would take, said plainly first, then one card for each race the camp could become
// with its price (materials by the race level, and five of that race's 信物). Switching asks once more, with the race's
// name typed in. The Mac opens this page from its menu's 「種族：…」.
const ok = await useSignedIn();
const world = useWorld();
const { set: setRace } = useRace();
const { ask } = useConfirm();
const NAMES: Record<string, string> = { goblin: "哥布林", elf: "精靈", undead: "死靈", beast: "獸人" };
const TOKEN_FROM: Record<string, string> = { goblin: "野蠻人營地、盜賊窩、強獸人軍團", elf: "古樹林", undead: "黑暗墓穴", beast: "洞穴熊" };

const view = ref<RaceSwitchView | null>(null);
// the race being read about (the camp's own until another is picked)
const sel = ref("");
const shown = computed(() => sel.value || view.value?.race || "goblin");
const info = computed(() => RACE_INFO[shown.value]);
const rules = computed(() => raceRules(shown.value));
const trees = computed(() => treesFor(shown.value));
const option = computed(() => view.value?.options.find((o) => o.race === shown.value));
const problem = ref("");
const message = ref("");
const busy = ref(false);
// a pixel picture at `times` its size, but never wider than its room (max-width in the style)
function grow(e: Event, times: number) {
  const img = e.target as HTMLImageElement;
  img.style.width = `${img.naturalWidth * times}px`;
}
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
    <WorldHead title="種族" :sub="view ? `現在：${NAMES[view.race] ?? view.race} Lv${view.level}` : undefined" />
    <ConfirmDialog />

    <nav class="picks">
      <button v-for="r in RACE_ORDER" :key="r" class="pill" :class="{ on: shown === r }" @click="sel = r">
        <img :src="`/sprites/${r}/icon.png`" class="pixel ico" alt="">{{ NAMES[r] }}<i v-if="view?.race === r">目前</i>
      </button>
    </nav>

    <section v-if="info" class="panel intro">
      <header class="who">
        <GoblinSprite :race="info.id" breed="golden" :scale="4" />
        <div>
          <h2>{{ info.name }}<span v-if="view?.race === info.id" class="now">目前的種族</span></h2>
          <p class="tag">{{ info.tagline }}</p>
        </div>
      </header>
      <p class="suits"><b>適合</b>{{ info.suits }}</p>
      <dl class="traits">
        <template v-for="[k, v] in info.traits" :key="k">
          <dt>{{ k }}</dt>
          <dd>{{ v }}</dd>
        </template>
        <dt>規模</dt>
        <dd>
          營地升到 {{ rules.stage2 }} 隻長成第二階段、{{ rules.stage3 }} 隻第三階段（開啟大世界）；每塊領地最多 {{ rules.cellCap }} 隻，城鎮最多 {{ rules.townCap }} 隻。
        </dd>
      </dl>

      <h3>居民品種</h3>
      <ul class="breeds">
        <li v-for="b in info.breeds" :key="b.id">
          <GoblinSprite :race="info.id" :breed="b.id" :scale="3" />
          <div>
            <b>{{ b.name }}</b><span class="role">{{ b.role }}</span>
            <p>{{ b.blurb }}</p>
          </div>
        </li>
      </ul>

      <h3>營地</h3>
      <div class="camps">
        <figure v-for="n in 3" :key="n">
          <img :src="`/camps/${info.campId}/stage${n}.png`" class="pixel" alt="" @load="grow($event, 2.5)">
          <figcaption>{{ ["剛落腳", `${rules.stage2} 隻以上`, `${rules.stage3} 隻以上`][n - 1] }}</figcaption>
        </figure>
      </div>
      <p class="line">{{ info.camp }}</p>

      <h3>場地</h3>
      <div class="land" :style="{ backgroundImage: `url(/terrain/${info.ground}.png)` }">
        <img v-for="(p, i) in info.props" :key="i" :src="`/terrain/${p}.png`" class="pixel" alt="" @load="grow($event, 2)">
      </div>
      <p class="line">{{ info.land }}</p>

      <h3>公主</h3>
      <div class="princess">
        <span class="queen pixel" :style="{ backgroundImage: `url(/sprites/${info.id}/queen.png)` }" />
        <p class="line">{{ info.princess }}</p>
      </div>

      <h3>天賦</h3>
      <ul class="trees">
        <li v-for="t in trees" :key="t.id"><b>{{ t.icon }} {{ t.name }}</b> {{ t.blurb }}</li>
      </ul>
      <p class="muted small">天賦樹每個種族不一樣；換族會全部重置，點數退回。</p>
    </section>

    <div v-if="!view" class="panel">{{ problem || "讀取中…" }}</div>
    <template v-else>
      <section v-if="shown !== view.race && option" class="panel option">
        <h3>換成{{ NAMES[shown] }}</h3>
        <ul class="price">
          <li v-for="p in option.price" :key="p.id" :class="{ short: p.have < p.need }">
            {{ p.name }} <b>{{ p.have.toLocaleString() }} / {{ p.need.toLocaleString() }}</b>
          </li>
        </ul>
        <p class="muted small">信物從{{ TOKEN_FROM[shown] }}掉（種族 10 級以上打贏才會掉，每次大約 1/4）。</p>
        <p v-if="option.problem && !(view.level < view.minLevel) && !waiting && !view.travelling" class="warn">{{ option.problem }}</p>
        <button class="btn danger" :disabled="busy || !!option.problem" @click="choose(shown)">換成{{ NAMES[shown] }}…</button>
      </section>

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
.picks { display: flex; gap: 6px; margin-bottom: 4px; overflow-x: auto; }
.pill { flex: none; min-height: 38px; padding: 8px 14px; border: 0; border-radius: 999px; background: rgba(255, 255, 255, 0.1); color: #dfe8d8; font-size: 14px; font-weight: 700; }
.pill.on { background: var(--card); color: var(--ink); }
.pill i { font-style: normal; margin-left: 6px; padding: 0 6px; border-radius: 9px; background: var(--green); color: #fff; font-size: 11px; }
.who { display: flex; align-items: center; gap: 12px; }
.who h2 { display: flex; align-items: center; gap: 8px; margin: 0; }
.now { font-size: 12px; padding: 1px 8px; border-radius: 9px; background: var(--green); color: #fff; font-weight: 600; }
.tag { margin: 4px 0 0; color: var(--muted); }
.suits { margin: 10px 0 0; }
.suits b { margin-right: 8px; }
.intro h3 { margin: 16px 0 6px; }
.traits { margin: 8px 0 0; display: grid; grid-template-columns: 4.5em minmax(0, 1fr); gap: 6px 8px; line-height: 1.55; }
.traits dt { font-weight: 700; }
.traits dd { margin: 0; }
.breeds, .trees { margin: 0; padding: 0; list-style: none; }
.breeds li { display: flex; gap: 10px; align-items: center; padding: 6px 0; border-top: 1px solid rgba(0, 0, 0, 0.06); }
.breeds li > :first-child { flex: none; width: 56px; display: flex; justify-content: center; }
.breeds p { margin: 2px 0 0; font-size: 13px; line-height: 1.5; }
.role { margin-left: 8px; font-size: 12px; color: var(--muted); }
.trees li { line-height: 1.7; }
.ico { width: 20px; height: 20px; margin-right: 6px; vertical-align: -5px; }
.camps { overflow: hidden; display: flex; gap: 8px; align-items: flex-end; justify-content: space-around; padding: 10px 4px 6px; border-radius: 12px; background: rgba(0, 0, 0, 0.05); }
.camps figure { flex: 0 1 auto; min-width: 0; margin: 0; text-align: center; }
.camps img { display: block; max-width: 100%; height: auto; margin: 0 auto 4px; }
.camps figcaption { font-size: 12px; color: var(--muted); }
.line { margin: 8px 0 0; line-height: 1.55; }
.land { display: flex; align-items: flex-end; justify-content: space-around; gap: 4px; height: 130px; padding: 0 6px 14px; border-radius: 12px; overflow: hidden; background-size: 96px; image-rendering: pixelated; }
.land img { flex: 0 1 auto; min-width: 0; max-width: 100%; height: auto; }
.princess { display: flex; gap: 12px; align-items: center; }
.princess .line { margin: 0; }
.queen { flex: none; width: 64px; height: 64px; background-size: 256px 896px; background-position: 0 0; }
</style>
