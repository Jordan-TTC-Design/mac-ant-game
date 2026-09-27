<script setup lang="ts">
// One goblin from the Mac's own sprite sheets (16×16 frames: row 1 facing you, row 2 away, row 3 sideways), moving about
// the way it does on a Mac note: idling, nervous near the target time, trembling when late, jumping with a bell when
// a reminder rings, hopping when done.
const props = withDefaults(defineProps<{ breed?: string; mood?: "idle" | "soon" | "late" | "ringing" | "done"; scale?: number }>(), {
  breed: "common",
  mood: "idle",
  scale: 3,
});

const sheets: Record<string, string> = { common: "worker", scout: "scout", brute: "brute", sage: "sage", golden: "golden" };
const tick = ref(Math.floor(Math.random() * 100));
let timer: ReturnType<typeof setInterval> | undefined;
onMounted(() => (timer = setInterval(() => tick.value++, 160)));
onUnmounted(() => clearInterval(timer));

const frame = computed(() => {
  const t = tick.value;
  let row = 0; // 0 down, 1 up, 2 side
  let col = 0;
  let flip = false;
  let dy = 0;
  let dx = 0;
  switch (props.mood) {
    case "done":
      dy = [0, 3, 5, 3][t % 4]!;
      break;
    case "ringing":
      dy = [0, 4, 0, 4][t % 4]!;
      row = 2;
      flip = t % 4 < 2;
      break;
    case "late":
      dx = t % 2 === 0 ? -1 : 1;
      row = 2;
      flip = Math.floor(t / 5) % 2 === 0;
      break;
    case "soon":
      row = 2;
      flip = Math.floor(t / 8) % 2 === 0;
      dy = t % 4 === 0 ? 1 : 0;
      break;
    default: {
      // a slow loop: look around, walk on the spot, look back at you
      const phase = Math.floor(t / 12) % 4;
      if (phase === 1) {
        row = 2;
        col = t % 4;
      } else if (phase === 2) {
        row = 2;
        flip = true;
      }
    }
  }
  return { row, col, flip, dx, dy };
});

const size = computed(() => 16 * props.scale);
const style = computed(() => ({
  width: `${size.value}px`,
  height: `${size.value}px`,
  backgroundImage: `url(/sprites/${sheets[props.breed] ?? "worker"}.png)`,
  backgroundSize: `${64 * props.scale}px ${48 * props.scale}px`,
  backgroundPosition: `-${frame.value.col * size.value}px -${frame.value.row * size.value}px`,
  transform: `translate(${frame.value.dx}px, ${-frame.value.dy}px) scaleX(${frame.value.flip ? -1 : 1})`,
}));
const mark = computed(() => (props.mood === "late" ? "!!" : props.mood === "soon" && tick.value % 4 < 2 ? "!" : ""));
</script>

<template>
  <div class="goblin" :style="{ width: `${size}px`, height: `${size + 14}px` }">
    <span v-if="mark" class="mark" :class="mood">{{ mark }}</span>
    <!-- a pixel bell, shaking -->
    <svg v-if="mood === 'ringing'" class="bell" :style="{ transform: `translateX(-50%) rotate(${tick % 2 ? 12 : -12}deg)` }" viewBox="0 0 8 8" width="16" height="16" shape-rendering="crispEdges">
      <rect x="3" y="0" width="2" height="1" fill="#8a5a1a" />
      <rect x="2" y="1" width="4" height="4" fill="#f2b81a" />
      <rect x="1" y="5" width="6" height="1" fill="#f2b81a" />
      <rect x="3" y="6" width="2" height="1" fill="#8a5a1a" />
    </svg>
    <div class="sprite pixel" :style="style" />
  </div>
</template>

<style scoped>
.goblin { position: relative; display: flex; align-items: flex-end; justify-content: center; flex: none; }
.sprite { background-repeat: no-repeat; image-rendering: pixelated; }
.mark { position: absolute; top: -2px; left: 50%; transform: translateX(-50%); font-weight: 900; font-size: 13px; line-height: 1; }
.mark.late { color: var(--red); }
.mark.soon { color: var(--amber); }
.bell { position: absolute; top: -6px; left: 50%; }
</style>
