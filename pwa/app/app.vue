<script setup lang="ts">
// The tabs along the bottom show on the main pages (not on a note being written, the big world's map with its cards, or
// before signing in).
const route = useRoute();
const { user } = useAccount();
const TABBED = ["/", "/notes", "/pomodoro", "/camp", "/workshop", "/roster", "/friends", "/settings", "/claude", "/feed"];
// (in the Mac app the window's sidebar does the tab bar's job)
const mac = inMacApp();
if (mac) document.documentElement.classList.add("in-mac");
const tabbed = computed(() => !mac && tabbedPage.value);
const tabbedPage = computed(() => !!user.value && (TABBED.includes(route.path.replace(/\/$/, "") || "/") || route.path.startsWith("/friends/")));
// The page scrolls inside #scroller, never the whole document: on iPhone a scrolling document drags the fixed tab bar along with
// Safari's toolbar and the bounce at either end. A new page starts at its top (what the router does for the document).
useNuxtApp().hook("page:finish", () => document.getElementById("scroller")?.scrollTo(0, 0));
</script>

<template>
  <div id="scroller">
    <NuxtPage />
  </div>
  <TabBar v-if="tabbed" />
</template>
