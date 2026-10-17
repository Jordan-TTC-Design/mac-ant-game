<script setup lang="ts">
// The head of 夥伴's pages (pwa/UI.md §4.4): its title, and the sub-tabs 好友・公會・排行 with what waits in each.
defineProps<{ sub?: string }>();
const nav = useNav();
const items = computed(() => [
  { to: "/friends", label: "好友", count: nav.unread.value + nav.friendAsks.value || undefined },
  { to: "/guild", label: "公會", count: nav.guildInvites.value || undefined },
  { to: "/leaderboard", label: "排行" },
]);
</script>

<template>
  <AppHeader title="夥伴" :sub="sub ?? '好友・公會・排行'">
    <template v-if="$slots.actions" #actions><slot name="actions" /></template>
  </AppHeader>
  <SubTabs :items="items" />
</template>
