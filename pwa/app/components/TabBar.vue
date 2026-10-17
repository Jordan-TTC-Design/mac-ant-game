<script setup lang="ts">
import { pomodoroPartName } from "@goblincamp/shared";

// The row of tabs along the bottom (pwa/UI.md §2): the phone app's five big parts, one tap away, a red dot where something
// waits. A tab goes back to the page last seen in it; tapping the tab you are in goes to its first page. While a pomodoro
// runs, a strip above the tabs counts it down on every page but its own (and 今天, which shows it big).
const route = useRoute();
const nav = useNav();
const live = useLive();
const here = computed(() => tabOf(route.path));
watch(
  () => route.fullPath,
  (p) => {
    const t = tabOf(route.path);
    if (t) nav.lastIn[t] = p;
  },
  { immediate: true },
);
const target = (t: (typeof TABS)[number]) => (here.value === t.id ? t.to : (nav.lastIn[t.id] ?? t.to));
const dot = (t: (typeof TABS)[number]) => {
  const b = nav.badges.value[t.id];
  return b === "!" ? "!" : b ? (b > 9 ? "9+" : String(b)) : "";
};

const now = ref(Date.now());
let clock: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  nav.start();
  clock = setInterval(() => (now.value = Date.now()), 1000);
});
onUnmounted(() => clearInterval(clock));
const run = computed(() => live.pomodoroNow(now.value));
const strip = computed(() => run.value && route.path !== "/pomodoro" && route.path !== "/");
// (pages leave room for the strip too)
watchEffect(() => document.documentElement.classList.toggle("focus-strip-on", !!strip.value));
onUnmounted(() => document.documentElement.classList.remove("focus-strip-on"));
const clockText = computed(() => {
  const s = Math.ceil((run.value?.left ?? 0) / 1000);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
});
</script>

<template>
  <NuxtLink v-if="strip && run" to="/pomodoro" class="focus-strip" :class="{ paused: run.paused }">
    <span>🍅</span>
    <span class="what">{{ pomodoroPartName(run.part, run.state.plan.rounds) }}{{ run.paused ? "・暫停" : "" }}</span>
    <b class="time">{{ clockText }}</b>
    <span>›</span>
  </NuxtLink>
  <nav class="tabbar">
    <NuxtLink v-for="t in TABS" :key="t.id" :to="target(t)" class="tab" :class="{ on: here === t.id }">
      <span class="icon">{{ t.icon }}<i v-if="dot(t)" class="dot" :class="{ urgent: dot(t) === '!' }">{{ dot(t) }}</i></span>
      <span class="label">{{ t.label }}</span>
    </NuxtLink>
  </nav>
</template>

<style scoped>
.tabbar {
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 20; display: flex; justify-content: center;
  padding: 6px 8px calc(env(safe-area-inset-bottom) + 6px); background: var(--bg); border-top: 1px solid rgba(255, 255, 255, 0.18);
  /* (the page's own green, the same as the strip an iPhone home-screen app may leave under it, so the two read as one) */
  /* (no backdrop-filter: on iPhone it made the fixed bar lag and redraw oddly while scrolling) */
}
.tab { flex: 1; max-width: 110px; display: grid; justify-items: center; gap: 1px; padding: 4px 0; border-radius: 10px; color: #c9d6c0; text-decoration: none; }
.tab.on { color: #fff; background: rgba(255, 255, 255, 0.12); }
.icon { position: relative; font-size: 21px; line-height: 1.1; }
.label { font-size: 11px; font-weight: 700; }
.dot {
  position: absolute; top: -4px; right: -12px; min-width: 17px; height: 17px; padding: 0 4px; border-radius: 9px; background: #e2553f;
  color: #fff; font-size: 10px; font-style: normal; font-weight: 800; line-height: 17px; text-align: center;
}
.dot.urgent { background: #ffcf3f; color: #2b1d00; box-shadow: 0 0 0 2px #e2553f; }
.focus-strip {
  position: fixed; left: 12px; right: 12px; bottom: calc(var(--tabbar-h) + 8px); z-index: 19; max-width: 536px; margin: 0 auto;
  display: flex; align-items: center; gap: 8px; padding: 9px 14px; border-radius: 12px; border: 2px solid #1f1f1f;
  background: #fde7df; color: #8a3b22; font-weight: 800; font-size: 14px; text-decoration: none; box-shadow: 0 2px 0 rgba(0, 0, 0, 0.3);
}
.focus-strip.paused { background: #f1eee4; color: #555; }
.focus-strip .what { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.focus-strip .time { font-family: ui-monospace, Menlo, monospace; font-size: 16px; font-variant-numeric: tabular-nums; }
</style>
