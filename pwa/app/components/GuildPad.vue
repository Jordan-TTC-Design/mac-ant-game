<script setup lang="ts">
import type { Pad } from "~/composables/useHallControl";

// The phone's buttons for walking one's avatar (GUILD.md §3.1), like a Game Boy: the cross to walk, A to sit / drink / wave,
// B to cheer, and 💬 to say something. Held buttons keep walking.
const emit = defineEmits<{ pad: [pad: Pad, down: boolean]; a: []; b: []; talk: [] }>();
const PADS: { pad: Pad; label: string; area: string }[] = [
  { pad: "up", label: "▲", area: "u" },
  { pad: "left", label: "◀", area: "l" },
  { pad: "right", label: "▶", area: "r" },
  { pad: "down", label: "▼", area: "d" },
];
function hold(pad: Pad, e: PointerEvent) {
  (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  emit("pad", pad, true);
}
</script>

<template>
  <div class="pad" aria-label="操作角色">
    <div class="cross">
      <button
        v-for="p in PADS"
        :key="p.pad"
        type="button"
        class="dir"
        :style="{ gridArea: p.area }"
        :aria-label="p.pad"
        @pointerdown.prevent="hold(p.pad, $event)"
        @pointerup="emit('pad', p.pad, false)"
        @pointercancel="emit('pad', p.pad, false)"
        @contextmenu.prevent
      >
        {{ p.label }}
      </button>
      <span class="hub" />
    </div>
    <button type="button" class="talk" aria-label="說話" @click="emit('talk')">💬</button>
    <div class="ab">
      <button type="button" class="round b" aria-label="B：歡呼" @pointerdown.prevent="emit('b')">B</button>
      <button type="button" class="round a" aria-label="A：互動" @pointerdown.prevent="emit('a')">A</button>
    </div>
  </div>
</template>

<style scoped>
.pad { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 12px 14px; margin: 0 0 12px; border-radius: 18px; background: #c9c3b3; border: 3px solid #1f1f1f; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35); user-select: none; -webkit-user-select: none; touch-action: none; }
.cross { display: grid; grid-template: ". u ." 40px "l c r" 40px ". d ." 40px / 40px 40px 40px; }
.dir { border: 0; background: #2b2b2b; color: #bbb; font-size: 14px; padding: 0; }
.dir:active { background: #444; }
.dir:nth-child(1) { border-radius: 6px 6px 0 0; }
.dir:nth-child(2) { border-radius: 6px 0 0 6px; }
.dir:nth-child(3) { border-radius: 0 6px 6px 0; }
.dir:nth-child(4) { border-radius: 0 0 6px 6px; }
.hub { grid-area: c; background: #2b2b2b; }
.talk { width: 48px; height: 48px; border-radius: 50%; border: 3px solid #1f1f1f; background: #fffdf6; font-size: 22px; }
.ab { display: flex; gap: 12px; transform: rotate(-20deg); }
.round { width: 52px; height: 52px; border-radius: 50%; border: 0; background: #9c2a4d; color: #f4e9cf; font-weight: 800; font-size: 18px; box-shadow: 0 3px 0 #5e1830; }
.round:active { transform: translateY(2px); box-shadow: 0 1px 0 #5e1830; }
.b { margin-top: 22px; }
</style>
