<script setup lang="ts">
// The pages of one big part side by side (pwa/UI.md §3): a row of pills under the head that stays at the top while the page
// scrolls and slides sideways when it does not fit; the one you are on is scrolled into sight. A count shows what waits.
const props = defineProps<{ items: { to: string; label: string; count?: number | string }[] }>();
const route = useRoute();
const row = ref<HTMLElement | null>(null);
// (the item whose path the page is, or is under — the longest such, so /camp/build lights 建設, not 總覽 too)
const lit = computed(() =>
  props.items
    .filter((i) => route.path === i.to || route.path.startsWith(`${i.to}/`))
    .sort((a, b) => b.to.length - a.to.length)[0]?.to,
);
const on = (to: string) => lit.value === to;
onMounted(() => {
  const el = row.value?.querySelector<HTMLElement>(".on");
  el?.scrollIntoView({ block: "nearest", inline: "center" });
});
</script>

<template>
  <nav ref="row" class="sub-tabs">
    <NuxtLink v-for="i in items" :key="i.to" :to="i.to" replace class="pill" :class="{ on: on(i.to) }">
      {{ i.label }}<i v-if="i.count">{{ i.count }}</i>
    </NuxtLink>
  </nav>
</template>

<style scoped>
.sub-tabs {
  position: sticky; top: 0; z-index: 10; display: flex; gap: 5px; overflow-x: auto; scrollbar-width: none;
  margin: -4px -16px 12px; padding: 6px 16px 8px; background: var(--bg);
  /* (a row wider than the screen fades at its right edge: there is more to slide to) */
  mask-image: linear-gradient(to right, #000 calc(100% - 28px), transparent);
}
.sub-tabs::-webkit-scrollbar { display: none; }
.pill {
  flex: none; display: inline-flex; align-items: center; gap: 4px; min-height: 38px; padding: 8px 12px; border-radius: 999px;
  background: rgba(255, 255, 255, 0.1); color: #dfe8d8; font-size: 14px; font-weight: 700; text-decoration: none; white-space: nowrap;
}
.pill.on { background: var(--card); color: var(--ink); }
.pill i { font-style: normal; padding: 0 6px; border-radius: 9px; background: #e2553f; color: #fff; font-size: 11px; line-height: 17px; }
</style>
