/**
 * The guild hall (GUILD.md §3, §4): what each member's avatar is doing at a moment, worked out from the time, the members
 * and what stands in the hall, so every Mac and phone looking at it sees the same thing without the server sending
 * positions: someone focusing types at their desk, someone away dozes on it, someone there wanders (a drink at the water
 * elemental, a sit on a bench or a sofa, a chat at a friend's desk, a stretch), someone offline is not there.
 *
 * Everything in the hall is a decoration the members put down (a new guild gets a starter set: shared/src/guild-decor.ts
 * starterDecor), so the desks, the water and the seats are wherever the members put them: `hallFurnishing` works out from
 * the pieces where one works, drinks and sits, and what is in the way. Nobody walks through anything: every way is found
 * round it (`hallRoute`).
 *
 * Positions are in tiles from the hall's top left; an avatar's or a piece's position is where its feet (bottom middle) are.
 * The floor is the tiles the leader and officers drew (HallArea); a wall WALL_ROWS high stands over every top edge of it.
 */
import { guildLevel, type Presence } from "./guild.ts";

export const WALL_ROWS = 2;
/** Walking speed, tiles a second. */
export const WALK_SPEED = 1.6;
/** Someone there does one thing (walking to it included) for this long. */
export const ACTIVITY_SECONDS = 24;

export type HallAnim = "idle" | "walk" | "sit" | "type" | "doze" | "drink" | "wave" | "stretch" | "chat" | "cheer";
export type HallDir = "front" | "back" | "side";

export interface Point {
  x: number;
  y: number;
}

/** Somewhere feet cannot go (tiles). */
export interface Rect {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}

/** What the pieces in the hall make of it: where one works (a desk's sitter, in the hall's order), sits, drinks, cannot go. */
export interface HallFurnishing {
  desks: Point[];
  seats: Point[];
  drinks: Point[];
  solids: Rect[];
}

// ── The hall's shape (GUILD.md §4.1) ─────────────────────────────────────────────────────────────────────────────────────

/**
 * Which tiles are floor: a line for each row from y = WALL_ROWS down, "#" floor and "." not. It is kept tight (its first and
 * last lines and its first column have floor, no line ends in "."), and its floor is all one piece. The guild's level says
 * how many tiles it may have (guildLevel().tiles); where they go is the leader's and officers' to draw.
 */
export type HallArea = string[];
/** However many tiles a level allows, the hall fits in this (floor tiles are keyed "x,y" with two digits at most). */
export const HALL_AREA_MAX_WIDTH = 96;
export const HALL_AREA_MAX_HEIGHT = 64;
/** A new guild's hall (and every hall from before the shape could be drawn): 32 × 18 tiles of floor under the wall. */
export const DEFAULT_HALL_AREA: HallArea = Array.from({ length: 18 }, () => "#".repeat(32));

/** Whether tile (x, y) (whole numbers) is floor. */
export function hallAreaHas(area: HallArea, x: number, y: number): boolean {
  return x >= 0 && area[y - WALL_ROWS]?.[x] === "#";
}

/** How many floor tiles. */
export function hallAreaTiles(area: HallArea): number {
  let n = 0;
  for (const row of area) for (const ch of row) if (ch === "#") n++;
  return n;
}

/** The size the area spans, the wall over its top row included. */
export function hallAreaSize(area: HallArea): { width: number; height: number } {
  return { width: Math.max(0, ...area.map((r) => r.length)), height: WALL_ROWS + area.length };
}

/**
 * The area with tile (x, y) made floor (`on`) or not, kept tight: when that grows it up or to the left, or takes away its
 * top row or first column, everything moves by (dx, dy) tiles to stay where it was (the caller moves the pieces and the
 * floor tiles by it, shared/src/guild-decor.ts shiftHall). Null: nothing would be left.
 */
export function hallAreaPaint(area: HallArea, x: number, y: number, on: boolean): { area: HallArea; dx: number; dy: number } | null {
  const tiles = new Set<string>();
  area.forEach((row, i) => [...row].forEach((ch, c) => ch === "#" && tiles.add(`${c},${i + WALL_ROWS}`)));
  if (on) tiles.add(`${x},${y}`);
  else tiles.delete(`${x},${y}`);
  if (!tiles.size) return null;
  const points = [...tiles].map((k) => k.split(",").map(Number) as [number, number]);
  const minX = Math.min(...points.map((p) => p[0]));
  const minY = Math.min(...points.map((p) => p[1]));
  const maxY = Math.max(...points.map((p) => p[1]));
  const dx = minX ? -minX : 0;
  const dy = WALL_ROWS - minY;
  const rows = Array.from({ length: maxY - minY + 1 }, () => [] as string[]);
  for (const [px, py] of points) rows[py - minY]![px + dx] = "#";
  return { area: rows.map((r) => Array.from(r, (ch) => ch ?? ".").join("")), dx, dy };
}

/** Why this cannot be the hall's floor at this level (null: it can). */
export function hallAreaProblem(area: unknown, level: number): string | null {
  if (!Array.isArray(area) || !area.length || area.some((r) => typeof r !== "string" || !/^([#.]*#)?$/.test(r))) return "據點範圍的格式不對。";
  const rows = area as HallArea;
  if (!rows[0] || !rows.at(-1)) return "據點範圍的格式不對。";
  const { width, height } = hallAreaSize(rows);
  if (width > HALL_AREA_MAX_WIDTH || height > HALL_AREA_MAX_HEIGHT) return `據點最寬 ${HALL_AREA_MAX_WIDTH} 格、最高 ${HALL_AREA_MAX_HEIGHT - WALL_ROWS} 格。`;
  if (!rows.some((r) => r[0] === "#")) return "據點範圍的格式不對。";
  const n = hallAreaTiles(rows);
  const most = guildLevel(level).tiles;
  if (n > most) return `據點最多 ${most} 格（現在 ${n} 格），公會升級後可以更大。`;
  // all one piece: everyone can walk everywhere
  const first = rows.findIndex((r) => r.includes("#"));
  const seen = new Set<string>([`${rows[first]!.indexOf("#")},${first + WALL_ROWS}`]);
  const queue = [...seen];
  while (queue.length) {
    const [x, y] = queue.pop()!.split(",").map(Number) as [number, number];
    for (const [nx, ny] of [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]] as const) {
      const key = `${nx},${ny}`;
      if (!seen.has(key) && hallAreaHas(rows, nx, ny)) {
        seen.add(key);
        queue.push(key);
      }
    }
  }
  if (seen.size !== n) return "據點的地板要連在一起，大家才走得過去。";
  return null;
}

export interface HallLayout extends HallFurnishing {
  width: number;
  height: number;
  area: HallArea;
  /** Every floor tile's top left, row by row (where someone with nothing to do may stand). */
  floorTiles: Point[];
  /** The floor, `width` × `height`, row by row: 1 floor (looked up for every step of every way, so not from `area`). */
  cells: Uint8Array;
}

export function hallLayout(area: HallArea | null = DEFAULT_HALL_AREA, furnishing: HallFurnishing = { desks: [], seats: [], drinks: [], solids: [] }): HallLayout {
  const shape = area ?? DEFAULT_HALL_AREA;
  const { width, height } = hallAreaSize(shape);
  const floorTiles: Point[] = [];
  const cells = new Uint8Array(width * height);
  shape.forEach((row, i) =>
    [...row].forEach((ch, x) => {
      if (ch !== "#") return;
      floorTiles.push({ x, y: i + WALL_ROWS });
      cells[(i + WALL_ROWS) * width + x] = 1;
    }),
  );
  return { width, height, area: shape, floorTiles, cells, ...furnishing };
}

/** What a piece is, as far as the hall's life goes (its art's size in pixels, and what it is for). */
export interface HallPieceSpec {
  w: number;
  h: number;
  flat: boolean;
  wall: boolean;
  ceiling: boolean;
  /** One of the little living things (they are not in the way). */
  living: boolean;
  /** Where a sitter's feet go on it (sprite pixels), for things to sit on. */
  seat: { x: number; y: number } | null;
  /** A desk: one works sitting behind it. A water source: one drinks beside it. */
  desk: boolean;
  drink: boolean;
}

/** From a desk's floor point to where its sitter's feet go, and from a water source to where a drinker stands (tiles). */
const DESK_SEAT = { x: -3 / 16, y: -4 / 16 };
const DRINK_AT = 1.1;

/** Where one works, sits and drinks among these pieces, and what of them is in the way, in their order. */
export function hallFurnishing(pieces: readonly { x: number; y: number; flip?: boolean; spec: HallPieceSpec }[]): HallFurnishing {
  const out: HallFurnishing = { desks: [], seats: [], drinks: [], solids: [] };
  for (const { x, y, flip, spec } of pieces) {
    if (spec.desk) out.desks.push({ x: x + (flip ? -DESK_SEAT.x : DESK_SEAT.x), y: y + DESK_SEAT.y });
    if (spec.seat) {
      const dx = (spec.seat.x - spec.w / 2) / 16;
      out.seats.push({ x: x + (flip ? -dx : dx), y: y + (spec.seat.y - spec.h) / 16 });
    }
    if (spec.drink) out.drinks.push({ x: x + (flip ? -DRINK_AT : DRINK_AT), y });
    if (spec.flat || spec.wall || spec.ceiling || spec.living) continue;
    const half = Math.max(0.2, (spec.w / 2 - 2) / 16);
    out.solids.push({ x0: x - half, y0: y - Math.min(spec.h, 10) / 16, x1: x + half, y1: y });
  }
  return out;
}

/** What an avatar is doing right now. */
export interface HallPose extends Point {
  anim: HallAnim;
  dir: HallDir;
  /** Mirror the side frames (they face left as drawn). */
  flip: boolean;
  /** Seconds since this anim began (for its frames). */
  t: number;
}

export interface HallMember {
  id: string;
  presence: Presence;
  /** Their place in the desk order (by when they joined): the desk they work at, if there are that many. */
  seat: number;
}

/** A number from 0 to 1 for these words (FNV-1a, then mixed so that "a|1" and "a|2" land far apart), the same everywhere. */
export function hallHash(...parts: (string | number)[]): number {
  let h = 0x811c9dc5;
  for (const ch of parts.join("|")) {
    h ^= ch.codePointAt(0)!;
    h = Math.imul(h, 0x01000193);
  }
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return (h >>> 0) / 0x100000000;
}

// ── Where feet may go ─────────────────────────────────────────────────────────────────────────────────────────────────

/** Whether feet may stand at `p`: on the floor (0.4 of a tile from its sides, half a tile from a wall), and in nothing. */
export function hallWalkable(L: HallLayout, p: Point): boolean {
  // (outside the hall, or not a number: no floor)
  const on = (x: number, y: number) => x >= 0 && y >= 0 && x < L.width && y < L.height && L.cells[Math.floor(y) * L.width + Math.floor(x)] === 1;
  const [left, right, top, bottom] = [p.x - 0.4, p.x + 0.4, p.y - 0.5, p.y + 0.099];
  if (!on(left, top) || !on(right, top) || !on(left, bottom) || !on(right, bottom)) return false;
  return !L.solids.some((r) => p.x > r.x0 && p.x < r.x1 && p.y > r.y0 && p.y < r.y1);
}

/** A step from `p` by (dx, dy), sliding along whatever is in the way. */
export function hallStep(L: HallLayout, p: Point, dx: number, dy: number): Point {
  const both = { x: p.x + dx, y: p.y + dy };
  if (hallWalkable(L, both)) return both;
  const sideways = { x: p.x + dx, y: p.y };
  if (dx && hallWalkable(L, sideways)) return sideways;
  const upDown = { x: p.x, y: p.y + dy };
  if (dy && hallWalkable(L, upDown)) return upDown;
  return p;
}

/** What pressing A does near `p`: sit at a desk or on a seat within reach (snapping onto it), drink beside water, or wave. */
export function hallInteract(L: HallLayout, p: Point): { anim: HallAnim; at: Point } {
  let near: { s: Point; d: number } | null = null;
  for (const s of [...L.desks, ...L.seats]) {
    const d = Math.hypot(s.x - p.x, s.y - p.y);
    if (!near || d < near.d) near = { s, d };
  }
  if (near && near.d < 1.3) return { anim: "sit", at: near.s };
  for (const w of L.drinks) if (Math.hypot(w.x - p.x, w.y - p.y) < 1.2) return { anim: "drink", at: w };
  return { anim: "wave", at: p };
}

/**
 * A way from `from` to `to` round whatever is in the way: a breadth-first search over half-tile steps (starting even from
 * inside a piece, like a seat), shortened wherever a straight line is clear. Where `to` cannot be reached (inside a desk, a
 * sofa) it goes to the nearest place that can, then the last step onto it. The points after `from`.
 */
export function hallRoute(L: HallLayout, from: Point, to: Point): Point[] {
  const step = 0.5;
  const cols = Math.ceil(L.width / step);
  const rows = Math.ceil(L.height / step);
  const cell = (p: Point) => Math.min(rows - 1, Math.max(0, Math.floor(p.y / step))) * cols + Math.min(cols - 1, Math.max(0, Math.floor(p.x / step)));
  const centre = (k: number) => ({ x: ((k % cols) + 0.5) * step, y: (Math.floor(k / cols) + 0.5) * step });
  const start = cell(from);
  const goal = cell(to);
  const came = new Map<number, number>([[start, -1]]);
  const queue = [start];
  let reached = false;
  for (let i = 0; i < queue.length; i++) {
    const at = queue[i]!;
    if (at === goal) {
      reached = true;
      break;
    }
    const c = at % cols;
    const r = Math.floor(at / cols);
    for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]] as const) {
      const nc = c + dc;
      const nr = r + dr;
      if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
      const key = nr * cols + nc;
      if (came.has(key) || !hallWalkable(L, centre(key))) continue;
      came.set(key, at);
      queue.push(key);
    }
  }
  let end = goal;
  if (!reached) {
    // (the reachable place nearest `to`, the first of equals in the search's order)
    let best = Infinity;
    for (const k of queue) {
      const c = centre(k);
      const d = Math.hypot(c.x - to.x, c.y - to.y);
      if (d < best) {
        best = d;
        end = k;
      }
    }
  }
  const cells: Point[] = [];
  for (let k = end; k !== -1; k = came.get(k)!) cells.unshift(centre(k));
  cells.shift(); // (the cell one starts in: one starts at `from` itself)
  if (reached && cells.length) cells[cells.length - 1] = to;
  else cells.push(to);
  // straight lines wherever nothing is in between
  const clear = (a: Point, b: Point) => {
    const n = Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / 0.2);
    for (let i = 1; i < n; i++) if (!hallWalkable(L, { x: a.x + ((b.x - a.x) * i) / n, y: a.y + ((b.y - a.y) * i) / n })) return false;
    return true;
  };
  const out: Point[] = [];
  let a = from;
  let i = 0;
  while (i < cells.length) {
    let j = cells.length - 1;
    while (j > i && !clear(a, cells[j]!)) j--;
    out.push(cells[j]!);
    a = cells[j]!;
    i = j + 1;
  }
  return out;
}

// ── What each one is doing ────────────────────────────────────────────────────────────────────────────────────────────

interface Doing extends Point {
  anim: HallAnim;
  dir: HallDir;
}

/** Somewhere free to stand on the floor, picked by these words (a few tries; else the middle of the first floor tile). */
export function hallFreeSpot(L: HallLayout, ...parts: (string | number)[]): Point {
  const n = L.floorTiles.length;
  for (let i = 0; i < 8 && n; i++) {
    const t = L.floorTiles[Math.floor(hallHash(...parts, "t", i) * n)]!;
    const p = { x: t.x + 0.1 + hallHash(...parts, "x", i) * 0.8, y: t.y + 0.5 + hallHash(...parts, "y", i) * 0.4 };
    if (hallWalkable(L, p)) return p;
  }
  const t = L.floorTiles[0] ?? { x: 0, y: WALL_ROWS };
  return { x: t.x + 0.5, y: t.y + 0.5 };
}

/** What someone who is there chooses to do in their `k`th activity. */
function activity(L: HallLayout, m: HallMember, k: number, present: HallMember[]): Doing {
  const desk = L.desks[m.seat];
  const roll = hallHash(m.id, k);
  const others = present.filter((o) => o.id !== m.id);
  const idle = (): Doing => ({ ...hallFreeSpot(L, m.id, k), anim: "idle", dir: "front" });
  if (roll < 0.3) return desk ? { ...desk, anim: "sit", dir: "front" } : idle();
  if (roll < 0.45) return L.drinks.length ? { ...L.drinks[Math.floor(hallHash(m.id, k, "drink") * L.drinks.length)]!, anim: "drink", dir: "front" } : idle();
  if (roll < 0.6) return L.seats.length ? { ...L.seats[Math.floor(hallHash(m.id, k, "bench") * L.seats.length)]!, anim: "sit", dir: "front" } : idle();
  if (roll < 0.8 && others.length) {
    const friend = others[Math.floor(hallHash(m.id, k, "who") * others.length)]!;
    const at = L.desks[friend.seat];
    return at ? { x: at.x + 1.1, y: at.y, anim: "chat", dir: "side" } : idle();
  }
  if (roll < 0.88) return desk ? { x: desk.x - 1.1, y: desk.y, anim: "stretch", dir: "front" } : idle();
  return idle();
}

function length(path: Point[]) {
  let d = 0;
  for (let i = 1; i < path.length; i++) d += Math.hypot(path[i]!.x - path[i - 1]!.x, path[i]!.y - path[i - 1]!.y);
  return d;
}

/** Where along `path` one is after walking `d` tiles, and which way they face. */
function along(path: Point[], d: number): { at: Point; dir: HallDir; flip: boolean } {
  for (let i = 1; i < path.length; i++) {
    const [p, q] = [path[i - 1]!, path[i]!];
    const seg = Math.hypot(q.x - p.x, q.y - p.y);
    if (d <= seg || i === path.length - 1) {
      const f = seg ? Math.min(1, d / seg) : 1;
      const dx = q.x - p.x;
      const dy = q.y - p.y;
      const dir: HallDir = Math.abs(dx) >= Math.abs(dy) ? "side" : dy < 0 ? "back" : "front";
      return { at: { x: p.x + dx * f, y: p.y + dy * f }, dir, flip: dx > 0 };
    }
    d -= seg;
  }
  return { at: path.at(-1)!, dir: "front", flip: false };
}

/**
 * What member `m` is doing at `now` (ms): null when offline (not in the hall). `present` is everyone in the hall (for
 * visiting a friend's desk). The ways walked are found anew for each activity; `ways` keeps them (one map per layout: a
 * new one when the hall changes), since this is asked every frame.
 */
export function hallPose(L: HallLayout, m: HallMember, present: HallMember[], now: number, ways?: Map<string, Point[]>): HallPose | null {
  if (m.presence === "offline") return null;
  const secs = now / 1000;
  const desk = L.desks[m.seat];
  if (m.presence === "focus" || m.presence === "away") {
    // (no desk for them: they stand by the wall)
    if (!desk) return { ...hallFreeSpot(L, m.id, "wall"), anim: "idle", dir: "front", flip: false, t: secs };
    return { ...desk, anim: m.presence === "focus" ? "type" : "doze", dir: "front", flip: false, t: secs };
  }
  const shifted = secs + hallHash(m.id, "offset") * ACTIVITY_SECONDS;
  const k = Math.floor(shifted / ACTIVITY_SECONDS);
  const into = shifted - k * ACTIVITY_SECONDS;
  const from = activity(L, m, k - 1, present);
  const to = activity(L, m, k, present);
  const key = `${m.id}|${k}`;
  let path = ways?.get(key);
  if (!path) {
    path = [from, ...hallRoute(L, from, to)];
    ways?.set(key, path);
  }
  // (a long way in a big hall: a brisker pace, so it is walked in most of the activity's time and nobody jumps)
  const far = length(path);
  const pace = Math.max(WALK_SPEED, far / (ACTIVITY_SECONDS * 0.8));
  const walk = far / pace;
  if (into < walk) {
    const { at, dir, flip } = along(path, into * pace);
    return { ...at, anim: "walk", dir, flip, t: into };
  }
  return { x: to.x, y: to.y, anim: to.anim, dir: to.dir, flip: false, t: into - walk };
}
