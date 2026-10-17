<script setup lang="ts">
// The head of 大世界's pages (pwa/UI.md §4.3): its title, one line on how the race stands, and the sub-tabs
// 地圖・領地・天賦・戰報 with what waits in each (an attack on the way, talent points to spend).
defineProps<{ title?: string; sub?: string }>();
const nav = useNav();
const mac = inMacApp();
const items = computed(() => [
  { to: "/world", label: "地圖", count: nav.incoming.value.length ? "!" : undefined },
  { to: "/territory", label: "領地" },
  { to: "/talents", label: "天賦", count: nav.talentPoints.value || undefined },
  { to: "/expedition", label: "戰報" },
]);
</script>

<template>
  <AppHeader :title="title ?? '大世界'" :sub="sub">
    <template v-if="$slots.actions" #actions><slot name="actions" /></template>
  </AppHeader>
  <!-- (in the Mac app these pages are opened one by one from its own window: no tabs) -->
  <SubTabs v-if="!mac" :items="items" />
</template>
