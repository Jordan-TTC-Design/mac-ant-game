<script setup lang="ts">
// A small camp for the phone, drawn with the Mac's own pieces: the race's ground (a meadow, the elves' ancient forest, the
// undead's graveyard), a line of trees behind, the camp look for its stage with the race's things round it (fire, tents,
// lanterns, graves…), grass and stones about, and some of the residents (every rare breed first) wandering among them with
// the Mac's sprite sheets (16×16 frames: row 1 facing you, row 2 away, row 3 facing right).
// Only for looking at: who is where is made up here (the same every visit for a camp); the numbers are the server's.
const props = defineProps<{ race: string; stage: number; residents: { id: number; breed: string }[]; sheets: Record<string, string>; princess: boolean }>();

const SCALE = 3;
/** The residents and the scenery are drawn a little smaller than the camp, so a few dozen fit around it. */
const WALKER_SCALE = 2;
const PIECE_SCALE = 2;
const MAX_WALKERS = 24;
/** Where the camp stands (its foot), in % of the scene. */
const CAMP_X = 50;
const CAMP_Y = 50;
const look = computed(() => `/camps/${CAMP_LOOK[props.race] ?? "mound"}/stage${props.stage}.png`);
const campSize = ref({ w: 40, h: 24 });
function measure(event: Event) {
  const img = event.target as HTMLImageElement;
  campSize.value = { w: img.naturalWidth, h: img.naturalHeight };
}

// MARK: The scenery

const BIOME: Record<string, string> = { goblin: "meadow", elf: "elfwood", undead: "graveyard" };
const biome = computed(() => BIOME[props.race] ?? "meadow");
/** Each piece's size in pixels (written by scripts/copy-sprites.mjs). */
const pieces = ref<Record<string, [number, number]>>({});
onMounted(async () => {
  try {
    pieces.value = await (await fetch("/terrain/pieces.json")).json();
  } catch {
    // (no scenery, just the ground colour)
  }
});

interface Piece {
  key: string;
  name: string;
  x: number;
  y: number;
  flip: boolean;
  scale: number;
}

/** A little random-number maker that gives the same numbers for the same camp, so the scene does not change each visit. */
function seeded(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** The variants of a piece there are for this biome ("tree-meadow-0", "tree-meadow-1"… or just "firepit-meadow"). */
function variants(kind: string, b = biome.value): string[] {
  const all = pieces.value;
  const plain = `${kind}-${b}`;
  const found = Object.keys(all).filter((n) => n.startsWith(`${plain}-`) && /-\d+$/.test(n));
  if (found.length) return found.sort();
  if (all[plain]) return [plain];
  return all[kind] ? [kind] : [];
}

const scenery = computed<Piece[]>(() => {
  if (!Object.keys(pieces.value).length) return [];
  const rand = seeded([...props.race].reduce((h, c) => h * 31 + c.charCodeAt(0), 7) + props.stage * 101);
  const pick = <T,>(list: T[]) => list[Math.floor(rand() * list.length)]!;
  const out: Piece[] = [];
  let n = 0;
  const put = (kind: string, x: number, y: number, scale = PIECE_SCALE) => {
    const list = variants(kind);
    if (!list.length) return;
    out.push({ key: `${kind}-${n++}`, name: pick(list), x, y, flip: rand() < 0.5, scale });
  };

  // the trees behind the clearing: a far row cut off by the top, a near row in front of it
  for (let x = -4; x < 106; x += 9 + rand() * 7) put("tree", x, 14 + rand() * 6);
  for (let x = -2; x < 104; x += 11 + rand() * 9) {
    if (Math.abs(x - CAMP_X) < 12) continue; // (the camp stands in front of this gap)
    put(rand() < 0.35 ? "young" : "tree", x, 27 + rand() * 7);
  }
  if (biome.value === "elfwood") put("giant", rand() < 0.5 ? 6 : 94, 40); // one of the forest's great trees at the edge
  // the edges, lower down: the clearing's frame
  for (const side of [0, 1]) for (let y = 55; y < 110; y += 20 + rand() * 12) put(rand() < 0.5 ? "young" : "bush", side ? 97 + rand() * 4 : -1 - rand() * 4, y);

  // the race's things round the camp
  const stage = props.stage;
  if (props.race === "goblin") {
    put("firepit", 50, 70);
    put("firewood", 60, 72);
    put("rack", 29, 56);
    put("totem", 66, 52);
    if (stage >= 2) put("tent", 24, 70);
    if (stage >= 3) put("tent", 78, 66);
    put("spears", 36, 50);
    put("skull", 71, 80);
    put("log", 41, 82);
  } else if (props.race === "elf") {
    put("firepit", 50, 70);
    put("lantern", 36, 52);
    put("lantern", 64, 52);
    put("mushrooms", 22, 60);
    put("blossom", 76, 60);
    put("berries", 72, 84);
    put("log", 40, 80);
    if (stage >= 2) put("tent", 25, 76);
    if (stage >= 3) put("menhir", 82, 74);
  } else {
    put("grave", 26, 56);
    put("grave", 33, 64);
    put("grave", 70, 58);
    put("grave", 77, 66);
    if (stage >= 2) put("grave", 22, 78);
    if (stage >= 3) put("grave", 80, 82);
    put("bonepile", 57, 74);
    put("wisp", 40, 60);
    put("wisp", 63, 86);
    put("menhir", 66, 48);
    put("skull", 44, 84);
  }

  // grass, flowers and stones about (not in front of the camp, not on the fire)
  const small = ["tuft", "tuft", "sprout", "fern", "rock", "bush", "sapling", ...(props.race === "elf" ? ["blossom", "mushrooms"] : ["bones"])];
  for (let i = 0; i < 26; i++) {
    const x = 3 + rand() * 94;
    const y = 42 + rand() * 58;
    if (Math.abs(x - CAMP_X) < 14 && y < CAMP_Y + 26) continue;
    if (out.some((p) => Math.abs(p.x - x) < 5 && Math.abs(p.y - y) < 4)) continue;
    put(pick(small), x, y);
  }
  return out;
});

function pieceStyle(p: Piece) {
  const [w, h] = pieces.value[p.name] ?? [16, 16];
  return {
    left: `${p.x}%`,
    top: `${p.y}%`,
    width: `${w * p.scale}px`,
    height: `${h * p.scale}px`,
    zIndex: Math.round(p.y * 10),
    transform: `translate(-50%, -100%) scaleX(${p.flip ? -1 : 1})`,
  };
}

// MARK: The residents

interface Walker {
  key: string;
  sheet: string;
  /** Where its feet are and where it is going, in % of the scene. */
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
/** Somewhere in the clearing (below the trees, not inside the camp). */
function around() {
  for (;;) {
    const at = { x: 6 + Math.random() * 88, y: 44 + Math.random() * 53 };
    if (!(Math.abs(at.x - CAMP_X) < 12 && at.y < CAMP_Y + 3)) return at;
  }
}
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
    zIndex: Math.round(w.y * 10) + 1,
    backgroundImage: `url(/sprites/${w.sheet}.png)`,
    backgroundSize: `${4 * s}px ${princess ? 14 * s : 3 * s}px`,
    backgroundPosition: `-${w.col * s}px -${w.row * s}px`,
    transform: `translate(-50%, -100%) scaleX(${w.flip ? -1 : 1})`,
  };
}
</script>

<template>
  <div class="scene" :class="[race, biome]" :style="{ backgroundImage: `url(/terrain/ground-${biome}.png)` }">
    <div class="shade" />
    <img
      v-for="p in scenery"
      :key="p.key"
      :src="`/terrain/${p.name}.png`"
      class="piece pixel"
      alt=""
      :style="pieceStyle(p)"
    />
    <img
      :src="look"
      class="camp pixel"
      alt=""
      :style="{ left: `${CAMP_X}%`, top: `${CAMP_Y}%`, zIndex: CAMP_Y * 10, width: `${campSize.w * SCALE}px`, height: `${campSize.h * SCALE}px` }"
      @load="measure"
    />
    <div v-for="w in walkers" :key="w.key" class="walker pixel" :style="spriteStyle(w)" />
  </div>
</template>

<style scoped>
.scene {
  position: relative; height: 300px; border-radius: 14px; overflow: hidden; border: 3px solid #1f1f1f; box-shadow: 4px 4px 0 rgba(0, 0, 0, 0.35);
  background-color: #6fb04e; background-size: 64px 64px; background-repeat: repeat; image-rendering: pixelated;
}
.scene.elfwood { background-color: #4f9a55; }
.scene.graveyard { background-color: #45495a; }
/* the woods behind are darker, and the scene's edges a little too */
.shade {
  position: absolute; inset: 0; pointer-events: none; z-index: 2000;
  background:
    linear-gradient(rgba(10, 30, 15, 0.45), rgba(10, 30, 15, 0.12) 30%, rgba(0, 0, 0, 0) 42%),
    radial-gradient(ellipse at 50% 62%, rgba(0, 0, 0, 0) 55%, rgba(0, 0, 0, 0.28) 100%);
}
.graveyard .shade {
  background:
    linear-gradient(rgba(20, 16, 40, 0.55), rgba(20, 16, 40, 0.18) 32%, rgba(0, 0, 0, 0) 45%),
    radial-gradient(ellipse at 50% 62%, rgba(0, 0, 0, 0) 50%, rgba(10, 5, 30, 0.4) 100%);
}
.piece, .camp { position: absolute; image-rendering: pixelated; }
.camp { transform: translate(-50%, -100%); }
.walker { position: absolute; background-repeat: no-repeat; image-rendering: pixelated; }
</style>
