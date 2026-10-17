<script setup lang="ts">
// The tabs along the bottom show on every page of the five big parts (pwa/UI.md §2), not on a page that fills the screen
// on its own (a note being written, a chat, the guild hall), nor before signing in or in 後台.
const route = useRoute();
const { user } = useAccount();
// (in the Mac app the window's sidebar does the tab bar's job)
const mac = inMacApp();
if (mac) document.documentElement.classList.add("in-mac");
const tabbed = computed(() => !mac && tabbedPage.value);
const tabbedPage = computed(() => !!user.value && !!tabOf(route.path) && !fullScreen(route.path));
// The page scrolls inside #scroller, never the whole document: on iPhone a scrolling document drags the fixed tab bar along with
// Safari's toolbar and the bounce at either end. A new page starts at its top (what the router does for the document).
useNuxtApp().hook("page:finish", () => document.getElementById("scroller")?.scrollTo(0, 0));
// a new version of the app: look for one now and then, and say when it is there
const update = useAppUpdate();
onMounted(() => update.watch());
</script>

<template>
  <div v-if="update.ready.value" class="update-bar">
    <span>有新版本了</span>
    <button type="button" @click="update.reload()">重新整理</button>
  </div>
  <div id="scroller">
    <NuxtPage />
  </div>
  <TabBar v-if="tabbed" />
</template>

<style>
.update-bar { position: fixed; top: calc(env(safe-area-inset-top) + 8px); left: 50%; transform: translateX(-50%); z-index: 60; display: flex; align-items: center; gap: 10px; padding: 6px 8px 6px 14px; border-radius: 999px; background: #fff3c4; color: #2b1d00; border: 2px solid #1f1f1f; font-size: 14px; font-weight: 700; box-shadow: 0 3px 0 rgba(0, 0, 0, 0.3); }
.update-bar button { border: 0; border-radius: 999px; padding: 6px 14px; background: #3a9a47; color: #fff; font-weight: 700; font-size: 14px; }
</style>
