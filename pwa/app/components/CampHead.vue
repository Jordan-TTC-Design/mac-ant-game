<script setup lang="ts">
// The head of 營地's pages (pwa/UI.md §4.2): the camp's name and how it stands, the quests to claim, and the sub-tabs
// 總覽・建設・工坊・名冊・任務・動態.
defineProps<{ title?: string; sub?: string }>();
const nav = useNav();
const mac = inMacApp();
const items = computed(() => [
  { to: "/camp", label: "總覽" },
  { to: "/camp/build", label: "建設" },
  { to: "/workshop", label: "工坊" },
  { to: "/roster", label: "名冊" },
  { to: "/quests", label: "任務", count: nav.questsReady.value || undefined },
  { to: "/feed", label: "動態" },
]);
</script>

<template>
  <AppHeader :title="title ?? '營地'" :sub="sub">
    <template v-if="$slots.actions" #actions><slot name="actions" /></template>
  </AppHeader>
  <!-- (in the Mac app these pages are opened one by one from its own window: no tabs) -->
  <SubTabs v-if="!mac" :items="items" />
</template>
