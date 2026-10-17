<script setup lang="ts">
// A piece's 16×16 icon (mac/tools/make_gear_icons.py), scaled up sharp, framed in its rank's colour (gearRank).
const props = withDefaults(defineProps<{ id: string; size?: number }>(), { size: 28 });
const sheet = useGearSheet();
const style = computed(() => {
  const s = sheet.value;
  const n = s?.icons[props.id];
  const color = GEAR_RANK_COLORS[gearRank(props.id)];
  const box = { width: `${props.size}px`, height: `${props.size}px`, borderColor: color, background: `${color}29` };
  if (!s || n === undefined) return { box, art: null };
  const inner = Math.round(props.size * 0.8);
  const rows = Math.ceil(Object.keys(s.icons).length / s.cols);
  return {
    box,
    art: {
      width: `${inner}px`,
      height: `${inner}px`,
      backgroundSize: `${s.cols * inner}px ${rows * inner}px`,
      backgroundPosition: `-${(n % s.cols) * inner}px -${Math.floor(n / s.cols) * inner}px`,
    },
  };
});
</script>

<template>
  <span class="gear-icon" :style="style.box" aria-hidden="true"><i v-if="style.art" :style="style.art" /></span>
</template>

<style scoped>
.gear-icon { display: inline-grid; place-items: center; flex: none; border: 1px solid; border-radius: 22%; box-sizing: border-box; vertical-align: middle; }
.gear-icon i { display: block; background-image: url(/gear/icons.png); image-rendering: pixelated; }
</style>
