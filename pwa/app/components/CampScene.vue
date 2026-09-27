<script setup lang="ts">
// A small camp for the phone: the race's camp look for its stage, and some of the residents (every rare breed first)
// wandering about it with the Mac's own sprite sheets (16×16 frames: row 1 facing you, row 2 away, row 3 facing right).
// Only for looking at: who is where is made up here; the numbers are the server's.
const props = defineProps<{ race: string; stage: number; residents: { id: number; breed: string }[]; sheets: Record<string, string>; princess: boolean }>();

const SCALE = 3;
/** The residents are drawn a little smaller than the camp, so a few dozen fit around it. */
const WALKER_SCALE = 2;
const MAX_WALKERS = 24;
const look = computed(() => `/camps/${CAMP_LOOK[props.race] ?? "mound"}/stage${props.stage}.png`);
const campSize = ref({ w: 40, h: 24 });
function measure(event: Event) {
  const img = event.target as HTMLImageElement;
  campSize.value = { w: img.naturalWidth, h: img.naturalHeight };
}

interface Walker {
  key: string;
  sheet: string;
  /** Where it is and where it is going, in % of the scene. */
  x: number;
  y: number;
  tx: number;
  ty: number;
  speed: number;
  rest: number;
  row: number;
  col: number;
  flip: boolean;
}

/** Who shows: one of every breed there is, then the rest by a fixed pick, up to MAX_WALKERS. */
function pickShown(): { key: string; sheet: string; speed: number }[] {
  const seen = new Set<string>();
  const first: typeof props.residents = [];
  const rest: typeof props.residents = [];
  for (const r of props.residents) {
    if (seen.has(r.breed)) rest.push(r);
    else first.push(r);
    seen.add(r.breed);
  }
  const chosen = [...first, ...rest.sort((a, b) => ((a.id * 2654435761) % 997) - ((b.id * 2654435761) % 997))].slice(0, MAX_WALKERS);
  const shown = chosen.map((r) => ({ key: String(r.id), sheet: `${props.race}/${props.sheets[r.breed] ?? "worker"}`, speed: r.breed === "scout" ? 0.55 : r.breed === "brute" ? 0.3 : 0.4 }));
  if (props.princess) shown.unshift({ key: "princess", sheet: `${props.race}/queen`, speed: 0.3 });
  return shown;
}

const walkers = ref<Walker[]>([]);
const around = () => ({ x: 5 + Math.random() * 90, y: 34 + Math.random() * 62 });
function cast() {
  const kept = new Map(walkers.value.map((w) => [w.key, w]));
  walkers.value = pickShown().map((s) => {
    const old = kept.get(s.key);
    if (old) return { ...old, sheet: s.sheet };
    const at = around();
    return { key: s.key, sheet: s.sheet, x: at.x, y: at.y, tx: at.x, ty: at.y, speed: s.speed, rest: Math.floor(Math.random() * 30), row: 0, col: 0, flip: false };
  });
}
watch(() => [props.residents, props.princess, props.race], cast, { immediate: true });

let tick = 0;
function step() {
  tick++;
  for (const w of walkers.value) {
    if (w.rest > 0) {
      w.rest--;
      w.col = 0;
      if (w.rest === 0) {
        const to = around();
        w.tx = to.x;
        w.ty = to.y;
      }
      continue;
    }
    const dx = w.tx - w.x;
    const dy = (w.ty - w.y) * 1.6; // (the scene is wider than tall: move by what it looks like)
    const d = Math.hypot(dx, dy);
    if (d < w.speed) {
      w.rest = 15 + Math.floor(Math.random() * 60);
      w.row = 0;
      continue;
    }
    w.x += (dx / d) * w.speed;
    w.y += (dy / d / 1.6) * w.speed;
    if (Math.abs(dx) > Math.abs(dy)) {
      w.row = 2;
      w.flip = dx < 0;
    } else {
      w.row = dy > 0 ? 0 : 1;
      w.flip = false;
    }
    if (tick % 2 === 0) w.col = (w.col + 1) % 4;
  }
}
let timer: ReturnType<typeof setInterval> | undefined;
onMounted(() => (timer = setInterval(step, 90)));
onUnmounted(() => clearInterval(timer));

const size = 16 * WALKER_SCALE;
function spriteStyle(w: Walker) {
  const princess = w.key === "princess";
  const s = princess ? size * 1.25 : size;
  return {
    left: `${w.x}%`,
    top: `${w.y}%`,
    width: `${s}px`,
    height: `${s}px`,
    zIndex: Math.round(w.y * 10),
    backgroundImage: `url(/sprites/${w.sheet}.png)`,
    backgroundSize: `${4 * s}px ${princess ? 14 * s : 3 * s}px`,
    backgroundPosition: `-${w.col * s}px -${w.row * s}px`,
    transform: `translate(-50%, -100%) scaleX(${w.flip ? -1 : 1})`,
  };
}
</script>

<template>
  <div class="scene" :class="race">
    <img
      :src="look"
      class="camp pixel"
      alt=""
      :style="{ width: `${campSize.w * SCALE}px`, height: `${campSize.h * SCALE}px` }"
      @load="measure"
    />
    <div v-for="w in walkers" :key="w.key" class="walker pixel" :style="spriteStyle(w)" />
  </div>
</template>

<style scoped>
.scene {
  position: relative; height: 280px; border-radius: 14px; overflow: hidden; border: 3px solid #1f1f1f; box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.35);
  background: linear-gradient(#8fce6a 0 26%, #6fb04e 26%);
}
.scene.elf { background: linear-gradient(#7fbf78 0 26%, #4f9a55 26%); }
.scene.undead { background: linear-gradient(#5a5670 0 26%, #45495a 26%); }
.camp { position: absolute; left: 50%; top: 34%; transform: translate(-50%, -50%); image-rendering: pixelated; z-index: 400; }
.walker { position: absolute; background-repeat: no-repeat; image-rendering: pixelated; }
</style>
