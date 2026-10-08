<script setup lang="ts">
import { guildDecorKind, hallLayout, hallPose, type GuildDecorPlaced, type GuildMemberView, type HallMember, type HallPose, type Presence } from "@goblincamp/shared";
import { loadImage, type AvatarManifest } from "~/composables/useAvatarArt";

/**
 * The guild hall (GUILD.md §3–4): the floor, walls and furniture, and every member who is in, doing what shared/src/guild-hall.ts
 * says they are doing now (the avatars' art: useAvatarArt), among the decorations the members put down. While decorating, a
 * piece is picked by tapping it and moved by dragging it.
 */
const props = defineProps<{ level: number; members: GuildMemberView[]; me?: string; decor: GuildDecorPlaced[]; editing?: boolean; selected?: string | null }>();
const emit = defineEmits<{ select: [uid: string | null]; move: [uid: string, x: number, y: number] }>();

interface HallManifest {
  tile: number;
  floors: Record<string, string>;
  walls: Record<string, { file: string; [k: string]: unknown }>;
  furniture: Record<string, { file: string; w: number; h: number; frames?: number; fps?: number; anchor: { x: number; y: number }; flat?: boolean }>;
}

const art = useAvatarArt();
const box = ref<HTMLDivElement>();
const canvas = ref<HTMLCanvasElement>();
const problem = ref("");
let avatarsInfo: AvatarManifest | null = null;
let hallInfo: HallManifest | null = null;
/** Short one-off anims from news (someone arriving waves, a focus round ending stretches): member → anim, until when. */
const moments = new Map<string, { anim: string; until: number; from: number }>();
const loaded = new Map<string, HTMLImageElement>();
async function preload(path: string) {
  loaded.set(path, await loadImage(path));
}

/** A decoration's art, loaded the first time it is needed (null until then). */
function decorImage(file: string): HTMLImageElement | null {
  const path = `/guild-hall/${file}`;
  const img = loaded.get(path);
  if (!img && !asked.has(path)) {
    asked.add(path);
    void preload(path).catch(() => {});
  }
  return img ?? null;
}
const asked = new Set<string>();

// decorating: tap a piece to pick it, drag to move it (in tiles, snapped to the art's pixels by the page)
let dragging: { uid: string; dx: number; dy: number } | null = null;
function tilesAt(e: PointerEvent): { x: number; y: number } {
  const r = canvas.value!.getBoundingClientRect();
  return { x: ((e.clientX - r.left) / r.width) * layout.value.width, y: ((e.clientY - r.top) / r.height) * layout.value.height };
}
function pieceAt(p: { x: number; y: number }): GuildDecorPlaced | null {
  // (the one drawn last, nearest the front, first)
  const order = [...props.decor].sort((a, b) => {
    const [ka, kb] = [guildDecorKind(a.kind), guildDecorKind(b.kind)];
    const ya = ka?.ceiling ? 1e3 : ka?.flat ? -1 : a.y;
    const yb = kb?.ceiling ? 1e3 : kb?.flat ? -1 : b.y;
    return yb - ya;
  });
  return (
    order.find((d) => {
      const k = guildDecorKind(d.kind);
      if (!k) return false;
      const half = k.w / 32;
      return p.x >= d.x - half && p.x <= d.x + half && p.y >= d.y - k.h / 16 && p.y <= d.y;
    }) ?? null
  );
}
function down(e: PointerEvent) {
  if (!props.editing) return;
  const p = tilesAt(e);
  const d = pieceAt(p);
  emit("select", d?.uid ?? null);
  if (d) {
    dragging = { uid: d.uid, dx: d.x - p.x, dy: d.y - p.y };
    canvas.value!.setPointerCapture(e.pointerId);
  }
}
function moveTo(e: PointerEvent) {
  if (!dragging) return;
  const p = tilesAt(e);
  emit("move", dragging.uid, p.x + dragging.dx, p.y + dragging.dy);
}
function up() {
  dragging = null;
}

const layout = computed(() => hallLayout(props.level));
const seatOrder = computed(() => [...props.members].sort((a, b) => a.joinedAt.localeCompare(b.joinedAt)));
const hallMembers = computed<HallMember[]>(() => seatOrder.value.map((m, i) => ({ id: m.id, presence: m.presence, seat: i })));

// someone coming in waves; a focus round ending (focus → there) stretches
const was = new Map<string, Presence>();
watch(
  () => props.members.map((m) => [m.id, m.presence] as const),
  (now) => {
    const t = Date.now();
    for (const [id, p] of now) {
      const before = was.get(id);
      if (before && before !== p && p === "online") moments.set(id, { anim: before === "focus" ? "stretch" : "wave", from: t, until: t + 3500 });
      was.set(id, p);
    }
  },
  { immediate: true },
);

let raf = 0;
let scale = 2;
function fit() {
  if (!box.value || !canvas.value || !hallInfo) return;
  const tile = hallInfo.tile;
  const w = layout.value.width * tile;
  const h = layout.value.height * tile;
  const dpr = window.devicePixelRatio || 1;
  scale = Math.max(2, Math.ceil((box.value.clientWidth * dpr) / w)); // (drawn a little big and shrunk to fit: names stay sharp)
  canvas.value.width = w * scale;
  canvas.value.height = h * scale;
  canvas.value.style.aspectRatio = `${w} / ${h}`;
}

function draw() {
  raf = requestAnimationFrame(draw);
  const c = canvas.value;
  const m = avatarsInfo;
  const hall = hallInfo;
  if (!c || !m || !hall) return;
  const g = c.getContext("2d")!;
  g.imageSmoothingEnabled = false;
  const T = hall.tile * scale;
  const L = layout.value;
  const now = Date.now();
  g.clearRect(0, 0, c.width, c.height);

  // floor, then the wall along the top
  const floor = loaded.get(`/guild-hall/${hall.floors[L.floor] ?? Object.values(hall.floors)[0]}`);
  if (floor) for (let y = 2; y < L.height; y++) for (let x = 0; x < L.width; x++) g.drawImage(floor, x * T, y * T, T, T);
  const wallInfo = hall.walls[L.wall] ?? Object.values(hall.walls)[0];
  const wall = wallInfo && loaded.get(`/guild-hall/${wallInfo.file}`);
  if (wall) for (let x = 0; x * T < c.width; x += wall.width / hall.tile) g.drawImage(wall, x * T, 0, wall.width * scale, wall.height * scale);

  // furniture and avatars, back to front by where their feet are
  const items: { y: number; paint: () => void }[] = [];
  for (const p of L.pieces) {
    const f = hall.furniture[p.id];
    const img = f && loaded.get(`/guild-hall/${f.file}`);
    if (!f || !img) continue;
    const frames = f.frames ?? 1;
    const frame = frames > 1 ? Math.floor((now / 1000) * (f.fps ?? 4)) % frames : 0;
    // (flat pieces, like the rug, lie under everything)
    items.push({ y: f.flat ? -1 : p.y, paint: () => g.drawImage(img, frame * f.w, 0, f.w, f.h, p.x * T - f.anchor.x * scale, p.y * T - f.anchor.y * scale, f.w * scale, f.h * scale) });
  }
  const overhead: (() => void)[] = [];
  for (const d of props.decor) {
    const k = guildDecorKind(d.kind);
    const img = k && decorImage(k.file);
    if (!k || !img) continue;
    const frame = k.frames > 1 ? Math.floor((now / 1000) * (k.fps || 3)) % k.frames : 0;
    const chosen = props.editing && props.selected === d.uid;
    const paint = () => {
      const left = d.x * T - (k.w / 2) * scale;
      const top = d.y * T - k.h * scale;
      g.save();
      if (d.flip) {
        g.translate(d.x * T, 0);
        g.scale(-1, 1);
        g.translate(-d.x * T, 0);
      }
      g.drawImage(img, frame * k.w, 0, k.w, k.h, left, top, k.w * scale, k.h * scale);
      g.restore();
      if (chosen || (props.editing && d.locked)) {
        g.strokeStyle = chosen ? "#ffe066" : "rgba(255,255,255,0.6)";
        g.lineWidth = Math.max(1, scale / 2);
        g.setLineDash(chosen ? [] : [scale * 2, scale * 2]);
        g.strokeRect(left, top, k.w * scale, k.h * scale);
        g.setLineDash([]);
      }
      if (props.editing && d.locked) {
        g.font = `${6 * scale}px system-ui`;
        g.textAlign = "left";
        g.textBaseline = "top";
        g.fillText("🔒", left, top);
      }
    };
    if (k.ceiling) overhead.push(paint);
    else items.push({ y: k.flat ? -1 : k.wall ? -0.5 + d.y / 100 : d.y, paint });
  }
  const names: (() => void)[] = [];
  const present = hallMembers.value.filter((x) => x.presence !== "offline");
  for (const hm of hallMembers.value) {
    const member = seatOrder.value[hm.seat]!;
    let pose: HallPose | null = hallPose(L, hm, present, now);
    if (!pose) continue;
    const moment = moments.get(hm.id);
    if (moment && moment.until > now && pose.anim !== "walk") pose = { ...pose, anim: moment.anim as HallPose["anim"], dir: "front", t: (now - moment.from) / 1000 };
    const look = art.strip(m, member.avatar);
    const frame = art.frameOf(m, pose.anim, pose.dir, pose.t);
    // (a sitting avatar's feet go on the seat point; its sitting frames lift it onto the seat by themselves)
    const fx = pose.x * T;
    const fy = pose.y * T;
    const name = member.name;
    const mine = member.id === props.me;
    names.push(() => {
      g.font = `600 ${Math.max(9, 4 * scale)}px system-ui, sans-serif`;
      g.textAlign = "center";
      g.textBaseline = "top";
      // (at a desk: under the desk's front edge)
      const atDesk = L.seats.some((st) => Math.abs(st.x - pose!.x) < 0.01 && Math.abs(st.y - pose!.y) < 0.01);
      const ty = Math.min((pose!.y + (atDesk ? 0.3 : 0)) * T + 1.5 * scale, c.height - Math.max(9, 4 * scale) - 2 * scale);
      const w = g.measureText(name).width + 3 * scale;
      g.fillStyle = mine ? "rgba(232,197,71,0.9)" : "rgba(0,0,0,0.55)";
      g.fillRect(fx - w / 2, ty - 0.5 * scale, w, Math.max(9, 4 * scale) + scale);
      g.fillStyle = mine ? "#2b1d00" : "#fff";
      g.fillText(name, fx, ty);
    });
    items.push({
      y: pose.y,
      paint: () => {
        if (look) {
          g.save();
          if (pose!.flip) {
            g.translate(fx, 0);
            g.scale(-1, 1);
            g.translate(-fx, 0);
          }
          g.drawImage(look, frame * m.frameW, 0, m.frameW, m.frameH, fx - m.anchor.x * scale, fy - m.anchor.y * scale, m.frameW * scale, m.frameH * scale);
          g.restore();
        }
      },
    });
  }
  items.sort((a, b) => a.y - b.y);
  for (const it of items) it.paint();
  for (const paint of overhead) paint();
  // the names last, so no desk hides them
  for (const paint of names) paint();
}

let resize: ResizeObserver | undefined;
onMounted(async () => {
  try {
    [avatarsInfo, hallInfo] = await Promise.all([
      art.load(),
      fetch("/guild-hall/manifest.json").then((r) => (r.ok ? r.json() : Promise.reject(new Error("hall")))),
    ]);
  } catch {
    problem.value = "據點的圖還沒準備好。";
    return;
  }
  const h = hallInfo!;
  await Promise.allSettled([
    ...Object.values(h.floors).map((f) => preload(`/guild-hall/${f}`)),
    ...Object.values(h.walls).map((w) => preload(`/guild-hall/${w.file}`)),
    ...Object.values(h.furniture).map((f) => preload(`/guild-hall/${f.file}`)),
  ]);
  fit();
  resize = new ResizeObserver(fit);
  if (box.value) resize.observe(box.value);
  draw();
});
watch(() => props.level, fit);
onUnmounted(() => {
  cancelAnimationFrame(raf);
  resize?.disconnect();
});
</script>

<template>
  <div ref="box" class="hall">
    <canvas ref="canvas" class="pixel" :class="{ editing }" role="img" @pointerdown="down" @pointermove="moveTo" @pointerup="up" @pointercancel="up" :aria-label="`公會據點：${members.filter((m) => m.presence !== 'offline').length} 人在裡面`" />
    <p v-if="problem" class="problem">{{ problem }}</p>
  </div>
</template>

<style scoped>
.hall { position: relative; width: 100%; border: 3px solid #1f1f1f; border-radius: 12px; overflow: hidden; background: #2a2018; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35); }
canvas { display: block; width: 100%; image-rendering: pixelated; }
canvas.editing { cursor: grab; touch-action: none; }
.problem { margin: 0; padding: 24px; color: #f4e9cf; text-align: center; }
</style>
