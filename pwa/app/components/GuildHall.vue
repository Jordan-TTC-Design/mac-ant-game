<script setup lang="ts">
import { guildDecorKind, guildDecorSeats, hallLayout, hallPose, WALL_ROWS, type GuildDecorPlaced, type GuildMove, type HallFloor, type GuildMemberView, type HallMember, type HallPose, type Presence } from "@goblincamp/shared";
import { loadImage, type AvatarManifest } from "~/composables/useAvatarArt";

/**
 * The guild hall (GUILD.md §3–4): the floor, walls and furniture, and every member who is in, doing what shared/src/guild-hall.ts
 * says they are doing now (the avatars' art: useAvatarArt), among the decorations the members put down. While decorating, a
 * piece is picked by tapping it and moved by dragging it.
 */
const props = defineProps<{
  level: number;
  members: GuildMemberView[];
  me?: string;
  decor: GuildDecorPlaced[];
  floor: HallFloor;
  wall: string;
  editing?: boolean;
  /** Laying floor tiles: a tap or a drag paints the tiles under it. */
  painting?: boolean;
  selected?: string | null;
  /** Avatars walked by hand (GUILD.md §3.1), this one's and others': where they are and what they are doing. */
  hand?: Record<string, GuildMove & { since?: number }>;
  /** What each member said last, shown over their head until `until` (ms). */
  bubbles?: Record<string, { text: string; until: number }>;
  /** Where the camera keeps to (this one's avatar), when the hall is bigger than the view. */
  follow?: { x: number; y: number } | null;
  /** Fill the box it is in (the Mac's whole window), tiles sized to it, instead of a 16-tile-wide strip. */
  fill?: boolean;
}>();
const emit = defineEmits<{ select: [uid: string | null]; move: [uid: string, x: number, y: number]; paint: [x: number, y: number]; walkTo: [x: number, y: number] }>();

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

// The camera (GUILD.md §3.1): a phone sees about 16 × 10 tiles, a wide window up to 28 across; a bigger hall scrolls,
// keeping to this one's avatar, and dragging the empty floor looks round (until the avatar moves again).
const VIEW_NARROW = 16;
const VIEW_WIDE = 28;
/** Filling a window: a tile is this many points across (between the camp's goblins and the avatars drawn big). */
const FILL_TILE = 24;
const view = reactive({ cols: 16, rows: 10 });
const cam = { x: 0, y: 0 };
let lookingUntil = 0;
let lookedFrom: { x: number; y: number } | null = null;
function clampCam() {
  // (a view bigger than the hall keeps the hall in its middle)
  const L = layout.value;
  cam.x = view.cols >= L.width ? (L.width - view.cols) / 2 : Math.min(Math.max(0, cam.x), L.width - view.cols);
  cam.y = view.rows >= L.height ? (L.height - view.rows) / 2 : Math.min(Math.max(0, cam.y), L.height - view.rows);
}

// pointer: a tap walks there (or picks a piece while decorating), a drag on a piece moves it, a drag elsewhere looks round
let dragging: { uid: string; dx: number; dy: number } | null = null;
let press: { cx: number; cy: number; camX: number; camY: number; panning: boolean } | null = null;
function tilesAt(e: PointerEvent): { x: number; y: number } {
  const r = canvas.value!.getBoundingClientRect();
  return { x: cam.x + ((e.clientX - r.left) / r.width) * view.cols, y: cam.y + ((e.clientY - r.top) / r.height) * view.rows };
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
let painting = false;
function paintAt(e: PointerEvent) {
  const p = tilesAt(e);
  const x = Math.floor(p.x);
  const y = Math.floor(p.y);
  if (x >= 0 && x < layout.value.width && y >= WALL_ROWS && y < layout.value.height) emit("paint", x, y);
}
function down(e: PointerEvent) {
  canvas.value!.setPointerCapture(e.pointerId);
  if (props.editing && props.painting) {
    painting = true;
    paintAt(e);
    return;
  }
  if (props.editing) {
    const p = tilesAt(e);
    const d = pieceAt(p);
    emit("select", d?.uid ?? null);
    if (d) {
      dragging = { uid: d.uid, dx: d.x - p.x, dy: d.y - p.y };
      return;
    }
  }
  press = { cx: e.clientX, cy: e.clientY, camX: cam.x, camY: cam.y, panning: false };
}
function moveTo(e: PointerEvent) {
  if (painting) return paintAt(e);
  if (dragging) {
    const p = tilesAt(e);
    emit("move", dragging.uid, p.x + dragging.dx, p.y + dragging.dy);
    return;
  }
  if (!press) return;
  const dx = e.clientX - press.cx;
  const dy = e.clientY - press.cy;
  if (!press.panning && Math.hypot(dx, dy) < 8) return;
  press.panning = true;
  const perTile = canvas.value!.getBoundingClientRect().width / view.cols;
  cam.x = press.camX - dx / perTile;
  cam.y = press.camY - dy / perTile;
  clampCam();
  lookingUntil = Date.now() + 10_000;
  lookedFrom = props.follow ? { ...props.follow } : null;
}
function up(e: PointerEvent) {
  // (not decorating, a tap that did not drag walks this one's avatar there)
  if (press && !press.panning && !props.editing) {
    const p = tilesAt(e);
    emit("walkTo", p.x, p.y);
  }
  press = null;
  dragging = null;
  painting = false;
}

const layout = computed(() => hallLayout(props.level));
/** Seats among the decorations (the wanderers sit on them too). */
const decorSeats = computed(() => guildDecorSeats(props.decor));
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
  const L = layout.value;
  const dpr = window.devicePixelRatio || 1;
  if (props.fill) {
    // FILL_TILE points a tile, in whole pixels of the art; a smaller hall sits in the middle, a bigger one scrolls
    const bw = box.value.clientWidth;
    const bh = box.value.clientHeight;
    const want = FILL_TILE;
    scale = Math.max(2, Math.round((want * dpr) / tile));
    const perTile = (scale * tile) / dpr;
    view.cols = bw / perTile;
    view.rows = bh / perTile;
    clampCam();
    canvas.value.width = Math.round(bw * dpr);
    canvas.value.height = Math.round(bh * dpr);
    canvas.value.style.aspectRatio = "";
    return;
  }
  view.cols = Math.min(L.width, box.value.clientWidth >= 700 ? VIEW_WIDE : VIEW_NARROW);
  view.rows = Math.min(L.height, Math.round((view.cols * 10) / 16));
  clampCam();
  const w = view.cols * tile;
  const h = view.rows * tile;
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
  g.fillStyle = "#1e1912";
  g.fillRect(0, 0, c.width, c.height);
  // the camera keeps to the avatar (unless someone is looking round), easing there
  const f = props.follow;
  if (lookedFrom && f && Math.hypot(f.x - lookedFrom.x, f.y - lookedFrom.y) > 0.3) lookingUntil = 0;
  if (f && now > lookingUntil && !press?.panning && !dragging) {
    const tx = f.x - view.cols / 2;
    const ty = f.y - 1 - view.rows / 2;
    cam.x += (tx - cam.x) * 0.15;
    cam.y += (ty - cam.y) * 0.15;
    clampCam();
  }
  const viewLeft = cam.x * T;
  const viewTop = cam.y * T;
  g.save();
  g.translate(-Math.round(viewLeft), -Math.round(viewTop));

  // floor (its tiles), then the wall along the top
  const fallback = Object.values(hall.floors)[0];
  for (let y = WALL_ROWS; y < L.height; y++) {
    for (let x = 0; x < L.width; x++) {
      const id = props.floor.tiles[`${x},${y}`] ?? props.floor.base;
      const tile = loaded.get(`/guild-hall/${hall.floors[id] ?? fallback}`);
      if (tile) g.drawImage(tile, x * T, y * T, T, T);
    }
  }
  if (props.painting) {
    g.strokeStyle = "rgba(255,255,255,0.18)";
    g.lineWidth = 1;
    for (let x = 0; x <= L.width; x++) g.strokeRect(x * T, WALL_ROWS * T, 0, (L.height - WALL_ROWS) * T);
    for (let y = WALL_ROWS; y <= L.height; y++) g.strokeRect(0, y * T, L.width * T, 0);
  }
  const wallInfo = hall.walls[props.wall] ?? Object.values(hall.walls)[0];
  const wall = wallInfo && loaded.get(`/guild-hall/${wallInfo.file}`);
  if (wall) for (let x = 0; x < L.width; x += wall.width / hall.tile) g.drawImage(wall, x * T, 0, wall.width * scale, wall.height * scale);

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
  const bubbles: (() => void)[] = [];
  for (const hm of hallMembers.value) {
    const member = seatOrder.value[hm.seat]!;
    const handPose = props.hand?.[hm.id];
    let pose: HallPose | null = handPose ? smoothed(hm.id, handPose, now) : hallPose(L, hm, present, now, decorSeats.value);
    if (!handPose) shown.delete(hm.id);
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
    // (off the view: no name or bubble pinned to its edge)
    const seen = fx > viewLeft - 2 * T && fx < viewLeft + c.width + 2 * T && fy > viewTop - T && fy < viewTop + c.height + 3 * T;
    const said = seen ? props.bubbles?.[hm.id] : undefined;
    if (said && said.until > now) {
      bubbles.push(() => {
        g.font = `${Math.max(10, 5 * scale)}px system-ui, sans-serif`;
        g.textAlign = "center";
        g.textBaseline = "middle";
        const text = said.text.length > 24 ? `${said.text.slice(0, 23)}…` : said.text;
        const w = g.measureText(text).width + 6 * scale;
        const h = Math.max(14, 8 * scale);
        const top = Math.max(viewTop + 1, fy - (m.anchor.y + 4) * scale - h);
        const left = Math.min(Math.max(viewLeft + 1, fx - w / 2), viewLeft + c.width - w - 1);
        g.fillStyle = "rgba(255,253,246,0.96)";
        g.strokeStyle = "#1f1f1f";
        g.lineWidth = Math.max(1, scale / 2);
        g.beginPath();
        g.roundRect(left, top, w, h, 3 * scale);
        g.moveTo(fx - 2 * scale, top + h);
        g.lineTo(fx, top + h + 3 * scale);
        g.lineTo(fx + 2 * scale, top + h);
        g.fill();
        g.stroke();
        g.fillStyle = "#1f1f1f";
        g.fillText(text, left + w / 2, top + h / 2);
      });
    }
    if (seen) names.push(() => {
      g.font = `600 ${Math.max(9, 4 * scale)}px system-ui, sans-serif`;
      g.textAlign = "center";
      g.textBaseline = "top";
      // (at a desk: under the desk's front edge)
      const atDesk = L.seats.some((st) => Math.abs(st.x - pose!.x) < 0.01 && Math.abs(st.y - pose!.y) < 0.01);
      const ty = Math.min((pose!.y + (atDesk ? 0.3 : 0)) * T + 1.5 * scale, viewTop + c.height - Math.max(9, 4 * scale) - 2 * scale);
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
  // the names last, so no desk hides them, and what was just said over everything
  for (const paint of names) paint();
  for (const paint of bubbles) paint();
  g.restore();
}

/** A hand-walked avatar eased toward where it was last heard to be (moves come a few times a second). */
const shown = new Map<string, { x: number; y: number; at: number }>();
function smoothed(id: string, to: GuildMove & { since?: number }, now: number): HallPose {
  const was = shown.get(id);
  const far = !was || Math.hypot(was.x - to.x, was.y - to.y) > 3;
  const k = was ? Math.min(1, (now - was.at) / 90) : 1;
  const x = far ? to.x : was!.x + (to.x - was!.x) * k;
  const y = far ? to.y : was!.y + (to.y - was!.y) * k;
  shown.set(id, { x, y, at: now });
  return { x, y, anim: to.anim, dir: to.dir, flip: to.flip, t: (now - (to.since ?? 0)) / 1000 };
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
  <div ref="box" class="hall" :class="{ fill }">
    <canvas ref="canvas" class="pixel" :class="{ editing, fill }" role="img" @pointerdown="down" @pointermove="moveTo" @pointerup="up" @pointercancel="up" :aria-label="`公會據點：${members.filter((m) => m.presence !== 'offline').length} 人在裡面`" />
    <p v-if="problem" class="problem">{{ problem }}</p>
  </div>
</template>

<style scoped>
.hall { position: relative; width: 100%; border: 3px solid #1f1f1f; border-radius: 12px; overflow: hidden; background: #2a2018; box-shadow: 3px 3px 0 rgba(0, 0, 0, 0.35); }
canvas { display: block; width: 100%; image-rendering: pixelated; }
canvas.editing { cursor: grab; touch-action: none; }
.hall.fill { width: 100%; height: 100%; border: 0; border-radius: 0; box-shadow: none; }
canvas.fill { height: 100%; }
.problem { margin: 0; padding: 24px; color: #f4e9cf; text-align: center; }
</style>
