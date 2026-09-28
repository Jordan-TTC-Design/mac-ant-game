<script setup lang="ts">
// One foe's pixel icon from the big world's sheet (/world/foes.png), `size` points square.
const props = withDefaults(defineProps<{ id: string; size?: number }>(), { size: 24 });
const sheet = useFoeSheet();
const at = computed(() => iconAt(sheet.value, props.id));
const style = computed(() => {
  const a = at.value;
  if (!a || !sheet.value) return {};
  return {
    width: `${props.size}px`,
    height: `${props.size}px`,
    backgroundImage: "url(/world/foes.png)",
    backgroundSize: `${sheet.value.cols * props.size}px ${a.rows * props.size}px`,
    backgroundPosition: `-${a.col * props.size}px -${a.row * props.size}px`,
  };
});
</script>

<template>
  <span class="foe pixel" :style="style" />
</template>

<style scoped>
.foe { display: inline-block; flex: none; background-repeat: no-repeat; image-rendering: pixelated; }
</style>
