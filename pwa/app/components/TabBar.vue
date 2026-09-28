<script setup lang="ts">
// The row of tabs along the bottom of the main pages: the phone app's big parts, one tap away. A dot on a tab when
// something waits there (unread messages, Claude asking).
const route = useRoute();
const { badges } = useLive();
const TABS = [
  { to: "/", label: "首頁", icon: "🏕️" },
  { to: "/notes", label: "便利貼", icon: "📝" },
  { to: "/pomodoro", label: "番茄鐘", icon: "🍅" },
  { to: "/camp", label: "營地", icon: "🛖" },
  { to: "/friends", label: "好友", icon: "💬" },
];
const on = (to: string) => (to === "/" ? route.path === "/" : route.path === to || route.path.startsWith(`${to}/`));
</script>

<template>
  <nav class="tabbar">
    <NuxtLink v-for="t in TABS" :key="t.to" :to="t.to" class="tab" :class="{ on: on(t.to) }">
      <span class="icon">{{ t.icon }}<i v-if="badges[t.to]" class="dot">{{ badges[t.to]! > 9 ? "9+" : badges[t.to] }}</i></span>
      <span class="label">{{ t.label }}</span>
    </NuxtLink>
  </nav>
</template>

<style scoped>
.tabbar {
  position: fixed; left: 0; right: 0; bottom: 0; z-index: 20; display: flex; justify-content: center;
  padding: 6px 8px calc(env(safe-area-inset-bottom) + 6px); background: rgba(24, 38, 22, 0.96); border-top: 2px solid #1f1f1f;
  backdrop-filter: blur(6px);
}
.tab { flex: 1; max-width: 110px; display: grid; justify-items: center; gap: 1px; padding: 4px 0; border-radius: 10px; color: #c9d6c0; text-decoration: none; }
.tab.on { color: #fff; background: rgba(255, 255, 255, 0.12); }
.icon { position: relative; font-size: 21px; line-height: 1.1; }
.label { font-size: 11px; font-weight: 700; }
.dot {
  position: absolute; top: -4px; right: -12px; min-width: 17px; height: 17px; padding: 0 4px; border-radius: 9px; background: #e2553f;
  color: #fff; font-size: 10px; font-style: normal; font-weight: 800; line-height: 17px; text-align: center;
}
</style>
