<script setup lang="ts">
import { BADGE_PALETTE, BADGE_SIZE } from "@goblincamp/shared";

// A guild's badge (16 × 16 pixels, shared/src/guild.ts), drawn as crisp squares at any size.
const props = defineProps<{ badge: string; size?: number }>();
const cells = computed(() => {
  const out: { x: number; y: number; fill: string }[] = [];
  for (let i = 0; i < props.badge.length; i++) {
    const c = parseInt(props.badge[i]!, 16);
    if (c > 0) out.push({ x: i % BADGE_SIZE, y: Math.floor(i / BADGE_SIZE), fill: BADGE_PALETTE[c]! });
  }
  return out;
});
</script>

<template>
  <svg :width="size ?? 48" :height="size ?? 48" :viewBox="`0 0 ${BADGE_SIZE} ${BADGE_SIZE}`" shape-rendering="crispEdges" aria-hidden="true">
    <rect v-for="c in cells" :key="`${c.x}-${c.y}`" :x="c.x" :y="c.y" width="1.02" height="1.02" :fill="c.fill" />
  </svg>
</template>
