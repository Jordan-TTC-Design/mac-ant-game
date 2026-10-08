/**
 * The guild hall (GUILD.md §3, §4): where things stand in it, and what each member's avatar is doing at a moment. Worked
 * out from the time and the members alone, so every Mac and phone looking at the hall sees the same thing without the
 * server sending positions: someone focusing types at their desk, someone away dozes on it, someone there wanders (a drink
 * at the water elemental, a sit on the bench, a chat at a friend's desk, a stretch), someone offline is not there.
 *
 * Positions are in tiles from the hall's top left; an avatar's or a piece's position is where its feet (bottom middle) are.
 * The top WALL_ROWS rows are the wall.
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

export interface HallPiece extends Point {
  /** The furniture id in mac/Resources/Guild/manifest.json. */
  id: string;
  flip?: boolean;
}

export interface HallLayout {
  width: number;
  height: number;
  floor: string;
  wall: string;
  pieces: HallPiece[];
  /** Where each desk's sitter is, in seat order (members get them by when they joined). */
  seats: Point[];
  /** Where to stand for a drink, the bench's seats, and the rows free of desks to walk along. */
  drink: Point;
  bench: Point[];
  aisles: number[];
}

/** Desks in rows: the first desk row's y, then every DESK_ROW_STEP tiles; columns from x = 3, every 3 tiles. */
const FIRST_DESK_ROW = WALL_ROWS + 2.5;
const DESK_ROW_STEP = 2.5;
/** Where the sitter's feet go from the desk's floor point (mac/Resources/Guild/manifest.json: desk seat − anchor, in tiles). */
const DESK_SEAT = { x: -3 / 16, y: -4 / 16 };
/** The water elemental's `use` point from its floor point (where a drinker stands). */
const DRINK_AT = { x: 18 / 16, y: 0 };

export function hallLayout(level: number, floor = "oak", wall = "stone"): HallLayout {
  const { width, height, members } = guildLevel(level);
  const pieces: HallPiece[] = [];
  const seats: Point[] = [];
  const rows: number[] = [];
  // one desk per member the guild can have, row by row from the top; the rest of the floor is left for decorating
  const perRow = Math.floor((width - 4 - 3) / 3) + 1;
  for (let y = FIRST_DESK_ROW; y <= height - 3 && rows.length * perRow < members; y += DESK_ROW_STEP) rows.push(y);
  for (const y of rows) {
    for (let x = 3; x <= width - 4 && seats.length < members; x += 3) {
      const seat = { x: x + DESK_SEAT.x, y: y + DESK_SEAT.y };
      pieces.push({ id: "desk", x, y });
      pieces.push({ id: "stool", x: seat.x, y: seat.y - 0.01 }); // (just behind its sitter)
      seats.push(seat);
    }
  }
  const aisles = [rows[0]! - DESK_ROW_STEP / 2, ...rows.map((y) => y + DESK_ROW_STEP / 2)];
  const bottom = height - 0.9;
  const bench: Point[] = [
    { x: 2.5, y: bottom },
    { x: 3.5, y: bottom },
  ];
  pieces.push(
    { id: "fireplace", x: width / 2, y: WALL_ROWS + 0.2 },
    { id: "banner", x: 3, y: WALL_ROWS - 0.2 },
    { id: "banner", x: width - 3, y: WALL_ROWS - 0.2 },
    { id: "bookshelf", x: 1.2, y: WALL_ROWS + 0.4 },
    { id: "water_dispenser", x: width - 2.8, y: WALL_ROWS + 0.6 },
    { id: "bench", x: 3, y: bottom },
    { id: "plant", x: 0.8, y: bottom },
    { id: "plant", x: width - 0.8, y: bottom },
    { id: "rug", x: width / 2, y: height - 1.2 },
  );
  const drink = { x: width - 2.8 + DRINK_AT.x, y: WALL_ROWS + 0.6 + DRINK_AT.y };
  return { width, height, floor, wall, pieces, seats, drink, bench, aisles };
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
  /** Their place in the seat order. */
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

interface Doing extends Point {
  anim: HallAnim;
  dir: HallDir;
}

/** What someone who is there chooses to do in their `k`th activity. */
function activity(layout: HallLayout, m: HallMember, k: number, present: HallMember[]): Doing {
  const seat = layout.seats[m.seat % layout.seats.length]!;
  const roll = hallHash(m.id, k);
  const others = present.filter((o) => o.id !== m.id);
  if (roll < 0.3) return { ...seat, anim: "sit", dir: "front" };
  if (roll < 0.45) return { ...layout.drink, anim: "drink", dir: "front" };
  if (roll < 0.6) return { ...layout.bench[Math.floor(hallHash(m.id, k, "bench") * layout.bench.length)]!, anim: "sit", dir: "front" };
  if (roll < 0.8 && others.length) {
    const friend = others[Math.floor(hallHash(m.id, k, "who") * others.length)]!;
    const at = layout.seats[friend.seat % layout.seats.length]!;
    return { x: at.x + 1.1, y: at.y, anim: "chat", dir: "side" };
  }
  if (roll < 0.88) return { x: seat.x - 1.1, y: seat.y, anim: "stretch", dir: "front" };
  const aisle = layout.aisles[Math.floor(hallHash(m.id, k, "aisle") * layout.aisles.length)]!;
  return { x: 1.5 + hallHash(m.id, k, "x") * (layout.width - 3), y: aisle, anim: "idle", dir: "front" };
}

/** The way from `a` to `b`: to the nearest aisle, along it, then to `b` (so nobody walks through a desk). */
export function hallPath(layout: HallLayout, a: Point, b: Point): Point[] {
  if (Math.abs(a.y - b.y) < 0.01) return [a, b];
  const nearest = (y: number) => layout.aisles.reduce((best, x) => (Math.abs(x - y) < Math.abs(best - y) ? x : best));
  const ay = nearest(a.y);
  const by = nearest(b.y);
  const pts: Point[] = [a, { x: a.x, y: ay }];
  if (ay !== by) {
    // (between aisles, cross at the hall's left or right edge, whichever is nearer, where there are no desks)
    const side = (a.x + b.x) / 2 < layout.width / 2 ? 1.5 : layout.width - 1.5;
    pts.push({ x: side, y: ay }, { x: side, y: by });
  }
  pts.push({ x: b.x, y: by }, b);
  return pts.filter((p, i) => i === 0 || Math.hypot(p.x - pts[i - 1]!.x, p.y - pts[i - 1]!.y) > 0.01);
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
 * visiting a friend's desk).
 */
export function hallPose(layout: HallLayout, m: HallMember, present: HallMember[], now: number): HallPose | null {
  if (m.presence === "offline") return null;
  const seat = layout.seats[m.seat % layout.seats.length]!;
  const secs = now / 1000;
  if (m.presence === "focus") return { ...seat, anim: "type", dir: "front", flip: false, t: secs };
  if (m.presence === "away") return { ...seat, anim: "doze", dir: "front", flip: false, t: secs };
  const shifted = secs + hallHash(m.id, "offset") * ACTIVITY_SECONDS;
  const k = Math.floor(shifted / ACTIVITY_SECONDS);
  const into = shifted - k * ACTIVITY_SECONDS;
  const from = activity(layout, m, k - 1, present);
  const to = activity(layout, m, k, present);
  const path = hallPath(layout, from, to);
  const walk = length(path) / WALK_SPEED;
  if (into < walk) {
    const { at, dir, flip } = along(path, into * WALK_SPEED);
    return { ...at, anim: "walk", dir, flip, t: into };
  }
  return { x: to.x, y: to.y, anim: to.anim, dir: to.dir, flip: false, t: into - walk };
}

// ── Walking by hand (GUILD.md §3.1) ───────────────────────────────────────────────────────────────────────────────────

interface Rect {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}

/** Where feet cannot go: the desks (and what stands along the back wall is out of reach anyway, below the wall's edge). */
export function hallSolids(layout: HallLayout): Rect[] {
  return layout.pieces.filter((p) => p.id === "desk").map((p) => ({ x0: p.x - 1.25, y0: p.y - 0.6, x1: p.x + 1.25, y1: p.y }));
}

/** Whether feet may stand at `p`. */
export function hallWalkable(layout: HallLayout, p: Point, solids: Rect[] = hallSolids(layout)): boolean {
  if (p.x < 0.4 || p.x > layout.width - 0.4 || p.y < WALL_ROWS + 0.5 || p.y > layout.height - 0.1) return false;
  return !solids.some((r) => p.x > r.x0 && p.x < r.x1 && p.y > r.y0 && p.y < r.y1);
}

/** A step from `p` by (dx, dy), sliding along whatever is in the way. */
export function hallStep(layout: HallLayout, p: Point, dx: number, dy: number, solids: Rect[] = hallSolids(layout)): Point {
  const both = { x: p.x + dx, y: p.y + dy };
  if (hallWalkable(layout, both, solids)) return both;
  const sideways = { x: p.x + dx, y: p.y };
  if (dx && hallWalkable(layout, sideways, solids)) return sideways;
  const upDown = { x: p.x, y: p.y + dy };
  if (dy && hallWalkable(layout, upDown, solids)) return upDown;
  return p;
}

/** What pressing A does near `p`: sit on a seat within reach (snapping onto it), drink at the water elemental, or wave. */
export function hallInteract(layout: HallLayout, p: Point, extraSeats: Point[] = []): { anim: HallAnim; at: Point } {
  const seats = [...layout.seats, ...layout.bench, ...extraSeats];
  const near = seats.map((s) => ({ s, d: Math.hypot(s.x - p.x, s.y - p.y) })).sort((a, b) => a.d - b.d)[0];
  if (near && near.d < 1.3) return { anim: "sit", at: near.s };
  if (Math.hypot(layout.drink.x - p.x, layout.drink.y - p.y) < 1.2) return { anim: "drink", at: layout.drink };
  return { anim: "wave", at: p };
}
