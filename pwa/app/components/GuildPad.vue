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
/* floating over the bottom of the hall, above the tab bar: the cross on the left, A and B on the right, 💬 between; the pad itself
   does not catch touches, only its buttons do, so the hall can still be tapped and dragged round them */
.pad { position: fixed; left: 0; right: 0; bottom: calc(var(--tabbar-h) + 12px); z-index: 2; display: flex; align-items: flex-end; justify-content: space-between; gap: 8px; padding: 0 16px; pointer-events: none; user-select: none; -webkit-user-select: none; -webkit-touch-callout: none; touch-action: none; }
.pad > * { pointer-events: auto; }
.cross { display: grid; grid-template: ". u ." 44px "l c r" 44px ". d ." 44px / 44px 44px 44px; filter: drop-shadow(0 2px 0 rgba(0, 0, 0, 0.35)); }
.dir { border: 0; background: rgba(24, 30, 22, 0.62); color: rgba(255, 255, 255, 0.85); font-size: 15px; padding: 0; touch-action: none; }
.dir:active { background: rgba(232, 197, 71, 0.85); color: #2b1d00; }
.dir:nth-child(1) { border-radius: 10px 10px 0 0; }
.dir:nth-child(2) { border-radius: 10px 0 0 10px; }
.dir:nth-child(3) { border-radius: 0 10px 10px 0; }
.dir:nth-child(4) { border-radius: 0 0 10px 10px; }
.hub { grid-area: c; background: rgba(24, 30, 22, 0.62); }
.talk { width: 46px; height: 46px; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.28); background: rgba(24, 30, 22, 0.62); font-size: 20px; margin-bottom: 8px; }
.ab { display: flex; gap: 12px; transform: rotate(-20deg); margin-bottom: 8px; filter: drop-shadow(0 2px 0 rgba(0, 0, 0, 0.35)); }
.round { width: 56px; height: 56px; border-radius: 50%; border: 2px solid rgba(255, 255, 255, 0.3); background: rgba(156, 42, 77, 0.78); color: #f4e9cf; font-weight: 800; font-size: 18px; touch-action: none; }
.round:active { background: rgba(232, 197, 71, 0.9); color: #2b1d00; transform: translateY(2px); }
.b { margin-top: 24px; }
</style>
