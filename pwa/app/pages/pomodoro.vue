<script setup lang="ts">
import { DEFAULT_POMODORO, pomodoroPartName, type PomodoroPlan } from "@goblincamp/shared";
import { ApiError } from "~/utils/api";

// 番茄鐘, shared with the Mac: started here, the goblin with the clock walks in on the Mac too (and the other way round).
// The phone cannot count while the app is closed, so the server tells it when a part is over (a push).
const ok = await useSignedIn();
const live = useLive();
const { race, ensure } = useRace();
void ensure();
const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  clock = setInterval(() => (now.value = Date.now()), 250);
});
onUnmounted(() => clearInterval(clock));

const run = computed(() => live.pomodoroNow(now.value));
const PRESETS: { name: string; plan: PomodoroPlan }[] = [
  { name: "經典 25 分", plan: DEFAULT_POMODORO },
  { name: "長專注 50 分", plan: { focusMinutes: 50, restMinutes: 10, rounds: 2, longRestMinutes: 20 } },
  { name: "快速 15 分", plan: { focusMinutes: 15, restMinutes: 3, rounds: 1, longRestMinutes: 0 } },
];
/** The plan to start with: the last one used on this phone. */
const plan = reactive<PomodoroPlan>({ ...DEFAULT_POMODORO });
onMounted(() => {
  try {
    const saved = JSON.parse(localStorage.getItem("gc-pomodoro-plan") ?? "null") as PomodoroPlan | null;
    if (saved) Object.assign(plan, saved);
  } catch {
    // (none kept)
  }
});
const custom = ref(false);
const busy = ref(false);
const problem = ref("");

async function act(action: Parameters<typeof live.pomodoro>[0]) {
  busy.value = true;
  problem.value = "";
  try {
    await live.pomodoro(action);
  } catch (e) {
    problem.value = e instanceof ApiError ? e.message : String(e);
  } finally {
    busy.value = false;
  }
}
function start(p: PomodoroPlan) {
  Object.assign(plan, p);
  try {
    localStorage.setItem("gc-pomodoro-plan", JSON.stringify(p));
  } catch {
    // (private mode)
  }
  void act({ action: "start", plan: { ...p } });
}
const clockText = computed(() => {
  const s = Math.ceil((run.value?.left ?? 0) / 1000);
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
});
const share = computed(() => (run.value ? 1 - run.value.left / (run.value.part.seconds * 1000) : 0));
const partName = computed(() => (run.value ? pomodoroPartName(run.value.part, run.value.state.plan.rounds) : ""));
const isRest = computed(() => !!run.value && run.value.part.phase !== "focus");
const planText = (p: PomodoroPlan) =>
  `專注 ${p.focusMinutes} 分・休息 ${p.restMinutes} 分${p.rounds > 1 ? `・${p.rounds} 輪${p.longRestMinutes ? `・長休息 ${p.longRestMinutes} 分` : ""}` : ""}`;
</script>

<template>
  <main v-if="ok" class="page">
    <header class="topbar">
      <div style="flex: 1">
        <h1>番茄鐘</h1>
        <div class="sub">和 Mac 同步：這裡開始，Mac 上也會開始</div>
      </div>
    </header>

    <section class="timer" :class="{ rest: isRest, idle: !run }">
      <img :src="`/sprites/${race}/icon.png`" class="pixel goblin" alt="" />
      <template v-if="run">
        <div class="part">{{ partName }}{{ run.paused ? "・暫停中" : "" }}</div>
        <div class="clock">{{ clockText }}</div>
        <div class="bar"><i :style="{ width: `${Math.round(share * 100)}%` }" /></div>
        <div class="steps">
          <i v-for="(s, k) in run.segments" :key="k" :class="[s.phase, { done: k < run.state.index, now: k === run.state.index }]" />
        </div>
        <p class="by">{{ run.state.by === "mac" ? "從 Mac 開始的" : "從手機開始的" }}・{{ planText(run.state.plan) }}</p>
        <div class="buttons">
          <button v-if="run.paused" class="btn primary" :disabled="busy" @click="act({ action: 'resume' })">繼續</button>
          <button v-else class="btn" :disabled="busy" @click="act({ action: 'pause' })">暫停</button>
          <button class="btn" :disabled="busy" @click="act({ action: 'skip' })">跳過這一段</button>
          <button class="btn" :disabled="busy" @click="act({ action: 'stop' })">結束</button>
        </div>
      </template>
      <template v-else>
        <div class="clock">{{ String(plan.focusMinutes).padStart(2, "0") }}:00</div>
        <p class="by">{{ live.state.pomodoroLoaded ? "沒有在跑。挑一個開始吧。" : "讀取中…" }}</p>
      </template>
    </section>
    <p v-if="problem" class="problem">{{ problem }}</p>

    <template v-if="!run && live.state.pomodoroLoaded">
      <section class="panel">
        <h2>開始</h2>
        <button v-for="p in PRESETS" :key="p.name" class="preset" :disabled="busy" @click="start(p.plan)">
          <b>{{ p.name }}</b><small>{{ planText(p.plan) }}</small>
        </button>
        <button class="preset" @click="custom = !custom"><b>自訂</b><small>{{ planText(plan) }}</small></button>
        <div v-if="custom" class="custom">
          <label>專注 <input v-model.number="plan.focusMinutes" type="number" min="1" max="180" /> 分</label>
          <label>休息 <input v-model.number="plan.restMinutes" type="number" min="0" max="60" /> 分</label>
          <label>輪數 <input v-model.number="plan.rounds" type="number" min="1" max="12" /></label>
          <label>長休息 <input v-model.number="plan.longRestMinutes" type="number" min="0" max="90" /> 分</label>
          <button class="btn primary wide" :disabled="busy" @click="start({ ...plan })">開始</button>
        </div>
      </section>
      <p class="hint">每一段結束時手機會收到通知（要先在「設定」開啟通知）。專注時，Mac 上的哥布林會舉著時鐘站在右上角。</p>
    </template>
  </main>
</template>

<style scoped>
.timer {
  background: #fffdf6; border: 3px solid #1f1f1f; border-radius: 18px; box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.35); padding: 18px 16px 16px;
  display: grid; justify-items: center; gap: 8px; text-align: center;
}
.timer.rest { background: #e3f3dc; }
.goblin { width: 56px; height: 56px; image-rendering: pixelated; }
.part { font-weight: 800; color: #b3412c; font-size: 16px; }
.rest .part { color: #2f7a3a; }
.clock { font-size: 64px; font-weight: 900; font-variant-numeric: tabular-nums; letter-spacing: 2px; line-height: 1; font-family: ui-monospace, Menlo, monospace; }
.idle .clock { color: #999; }
.bar { width: 100%; height: 10px; border-radius: 5px; background: #eee; overflow: hidden; border: 2px solid #1f1f1f; }
.bar i { display: block; height: 100%; background: #e2553f; transition: width 0.25s linear; }
.rest .bar i { background: #4f9a55; }
.steps { display: flex; gap: 4px; }
.steps i { width: 16px; height: 8px; border-radius: 3px; background: #f1c4b8; }
.steps i.rest, .steps i.longRest { width: 8px; background: #c6e3bf; }
.steps i.done { opacity: 0.35; }
.steps i.now { outline: 2px solid #1f1f1f; }
.by { color: #666; font-size: 12px; margin: 2px 0; }
.buttons { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
.preset { display: grid; width: 100%; text-align: left; gap: 2px; border: 2px solid rgba(0, 0, 0, 0.12); background: #fff; border-radius: 12px; padding: 10px 12px; margin-top: 8px; cursor: pointer; }
.preset small { color: #666; }
.custom { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 10px; }
.custom label { display: flex; align-items: center; gap: 6px; font-size: 14px; }
.custom input { width: 64px; border: 1px solid var(--line); border-radius: 8px; padding: 6px 8px; font-size: 16px; }
.custom .wide { grid-column: 1 / -1; }
.hint { color: #c9d6c0; font-size: 12px; margin: 10px 2px; line-height: 1.6; }
.problem { color: #ffd1c7; }
</style>
