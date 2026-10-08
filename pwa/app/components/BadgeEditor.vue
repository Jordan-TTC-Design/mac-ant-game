<script setup lang="ts">
import { BADGE_PALETTE, BADGE_SIZE } from "@goblincamp/shared";

// The leader draws the guild's badge (GUILD.md §5.4): 16 × 16, the heraldic palette, pencil, eraser, fill, and a mirror
// that draws both halves at once.
const props = defineProps<{ modelValue: string }>();
const emit = defineEmits<{ "update:modelValue": [string] }>();
const tool = ref<"pen" | "erase" | "fill">("pen");
const color = ref(2);
const mirror = ref(true);
const history: string[] = [];
let drawing = false;

// (a working copy, so strokes faster than the page redraws all land)
const pixels = ref<number[]>([]);
watch(
  () => props.modelValue,
  (v) => {
    if (v !== encode(pixels.value)) pixels.value = v.split("").map((c) => parseInt(c, 16));
  },
  { immediate: true },
);
function encode(p: number[]) {
  return p.map((c) => c.toString(16)).join("");
}
function set(next: number[]) {
  pixels.value = next;
  emit("update:modelValue", encode(next));
}
function paint(i: number) {
  const next = [...pixels.value];
  const x = i % BADGE_SIZE;
  const y = Math.floor(i / BADGE_SIZE);
  if (tool.value === "fill") {
    const from = next[i]!;
    const to = color.value;
    if (from === to) return;
    const stack = [[x, y]];
    while (stack.length) {
      const [px, py] = stack.pop()!;
      if (px! < 0 || py! < 0 || px! >= BADGE_SIZE || py! >= BADGE_SIZE) continue;
      const j = py! * BADGE_SIZE + px!;
      if (next[j] !== from) continue;
      next[j] = to;
      stack.push([px! + 1, py!], [px! - 1, py!], [px!, py! + 1], [px!, py! - 1]);
    }
  } else {
    const c = tool.value === "erase" ? 0 : color.value;
    next[i] = c;
    if (mirror.value) next[y * BADGE_SIZE + (BADGE_SIZE - 1 - x)] = c;
  }
  set(next);
}
function down(i: number) {
  history.push(encode(pixels.value));
  if (history.length > 50) history.shift();
  drawing = tool.value !== "fill";
  paint(i);
}
function over(e: PointerEvent) {
  if (!drawing) return;
  const el = document.elementFromPoint(e.clientX, e.clientY) as HTMLElement | null;
  const i = el?.dataset.i;
  if (i !== undefined && pixels.value[+i] !== (tool.value === "erase" ? 0 : color.value)) paint(+i);
}
function undo() {
  const last = history.pop();
  if (last) set(last.split("").map((c) => parseInt(c, 16)));
}
function clear() {
  history.push(encode(pixels.value));
  set(new Array(BADGE_SIZE * BADGE_SIZE).fill(0));
}
</script>

<template>
  <div class="editor">
    <div class="grid" @pointermove="over" @pointerup="drawing = false" @pointerleave="drawing = false">
      <button
        v-for="(c, i) in pixels"
        :key="i"
        type="button"
        class="px"
        :data-i="i"
        :style="{ background: c ? BADGE_PALETTE[c] : undefined }"
        :aria-label="`第 ${Math.floor(i / BADGE_SIZE) + 1} 列第 ${(i % BADGE_SIZE) + 1} 格`"
        @pointerdown.prevent="down(i)"
      />
    </div>
    <div class="palette">
      <button
        v-for="(hex, c) in BADGE_PALETTE.slice(1)"
        :key="c"
        type="button"
        class="swatch"
        :class="{ on: color === c + 1 && tool !== 'erase' }"
        :style="{ background: hex }"
        :aria-label="`顏色 ${c + 1}`"
        @click="(color = c + 1), tool === 'erase' && (tool = 'pen')"
      />
    </div>
    <div class="tools">
      <button type="button" class="btn" :class="{ primary: tool === 'pen' }" @click="tool = 'pen'">✏️ 畫筆</button>
      <button type="button" class="btn" :class="{ primary: tool === 'fill' }" @click="tool = 'fill'">🪣 填滿</button>
      <button type="button" class="btn" :class="{ primary: tool === 'erase' }" @click="tool = 'erase'">🧽 橡皮擦</button>
      <label class="mirror"><input v-model="mirror" type="checkbox" /> 左右對稱</label>
      <button type="button" class="btn" @click="undo">↩︎ 復原</button>
      <button type="button" class="btn" @click="clear">清空</button>
    </div>
  </div>
</template>

<style scoped>
.editor { display: grid; gap: 10px; }
.grid {
  display: grid; grid-template-columns: repeat(16, 1fr); width: min(100%, 352px); aspect-ratio: 1; touch-action: none;
  background: repeating-conic-gradient(#e9e2cf 0 25%, #f7f2e4 0 50%) 0 0 / 12.5% 12.5%; border: 3px solid #1f1f1f;
}
.px { border: 0; padding: 0; margin: 0; background: transparent; outline: 1px solid rgba(0, 0, 0, 0.06); }
.palette { display: grid; grid-template-columns: repeat(8, 1fr); gap: 6px; width: min(100%, 352px); }
.swatch { aspect-ratio: 1; border: 2px solid #1f1f1f; border-radius: 6px; padding: 0; }
.swatch.on { outline: 3px solid #fff3c4; outline-offset: 1px; }
.tools { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
.mirror { display: flex; align-items: center; gap: 4px; color: inherit; font-size: 14px; }
</style>
