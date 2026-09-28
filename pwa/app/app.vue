<script setup lang="ts">
// The tabs along the bottom show on the main pages (not on a note being written, the big world's map with its cards, or
// before signing in).
const route = useRoute();
const { user } = useAccount();
const TABBED = ["/", "/notes", "/pomodoro", "/camp", "/friends", "/settings", "/claude"];
const tabbed = computed(() => !!user.value && (TABBED.includes(route.path.replace(/\/$/, "") || "/") || route.path.startsWith("/friends/")));
</script>

<template>
  <NuxtPage />
  <TabBar v-if="tabbed" />
</template>
