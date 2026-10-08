/**
 * Decorating the guild hall (GUILD.md §4.2): every member may put down any decoration the guild has unlocked (by its level,
 * and a race's set by having a member of that race), as many of a kind as they like, as long as the room lasts. The leader
 * and officers may lock a piece so only they can move it; every change is logged, and the leader can go back to before one.
 */
import { z } from "zod";
import { GUILD_DECOR, type GuildDecorKind } from "./guild-decor-catalog.ts";
import { guildLevel, type GuildRole } from "./guild.ts";
import { hallFurnishing, WALL_ROWS, type HallFurnishing } from "./guild-hall.ts";

export { GUILD_DECOR, type GuildDecorKind };

/** However much room there is, no more than this many pieces (the hall has to draw them). */
export const GUILD_DECOR_MAX_ITEMS = 1000;
/** Changes kept in the log (and how far back the leader can go). */
export const GUILD_DECOR_LOG_DAYS = 7;
/** Positions are kept to a sixteenth of a tile (one pixel of the art). */
export const GUILD_DECOR_STEP = 1 / 16;

/** The categories, in the order the catalog's tabs show them. */
export const GUILD_DECOR_CATEGORIES = ["辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"] as const;

const BY_ID = new Map(GUILD_DECOR.map((k) => [k.id, k]));
export function guildDecorKind(id: string): GuildDecorKind | undefined {
  return BY_ID.get(id);
}

/** One piece put down: an id of its own (so it can be moved and locked), which kind, where its feet are (tiles), turned, locked. */
export const guildDecorPlacedSchema = z.object({
  uid: z.string().regex(/^[A-Za-z0-9_-]{4,24}$/),
  kind: z.string().max(40),
  x: z.number().finite(),
  y: z.number().finite(),
  flip: z.boolean().optional(),
  locked: z.boolean().optional(),
});
export type GuildDecorPlaced = z.infer<typeof guildDecorPlacedSchema>;

// ── Floors and walls (GUILD.md §4.3) ──────────────────────────────────────────────────────────────────────────────────

/** The floor styles (mac/Resources/Guild/manifest.json `floors`): the race's ones need a member of that race. */
export const HALL_FLOORS: readonly { id: string; name: string; race: string | null }[] = [
  { id: "oak", name: "橡木地板", race: null },
  { id: "stone", name: "石磚", race: null },
  { id: "carpet", name: "紅地毯", race: null },
  { id: "marble", name: "棋盤格大理石", race: null },
  { id: "plain_wood", name: "素木地板", race: null },
  { id: "plain_stone", name: "素石地", race: null },
  { id: "plain_plaster", name: "灰泥地", race: null },
  { id: "goblin_mud", name: "夯土地", race: "goblin" },
  { id: "goblin_flagstone", name: "粗石板", race: "goblin" },
  { id: "elf_moss", name: "苔蘚地", race: "elf" },
  { id: "elf_roots", name: "樹根木紋", race: "elf" },
  { id: "undead_blackstone", name: "黑石磚", race: "undead" },
  { id: "undead_bone", name: "骨片馬賽克", race: "undead" },
];
export const HALL_WALLS: readonly { id: string; name: string; race: string | null }[] = [
  { id: "stone", name: "灰石牆", race: null },
  { id: "wood", name: "木板牆", race: null },
  { id: "plain_plaster", name: "白灰泥牆", race: null },
  { id: "plain_wood", name: "素木牆", race: null },
  { id: "plain_stone", name: "素石牆", race: null },
  { id: "goblin_hide", name: "獸皮帳幕牆", race: "goblin" },
  { id: "elf_vines", name: "活藤樹牆", race: "elf" },
  { id: "undead_gothic", name: "哥德拱窗黑石牆", race: "undead" },
];
export const hallStyleOpen = (s: { race: string | null }, races: ReadonlySet<string>) => !s.race || races.has(s.race);

/** The hall's floor: one style for all of it, and tiles laid with another ("x,y" → style; y below the wall). */
export const hallFloorSchema = z.object({
  base: z.string().max(30),
  tiles: z.record(z.string().regex(/^\d{1,2},\d{1,2}$/), z.string().max(30)),
});
export type HallFloor = z.infer<typeof hallFloorSchema>;
export const DEFAULT_HALL_FLOOR: HallFloor = { base: "oak", tiles: {} };

/** Why this floor cannot be the hall's (null: it can). A style already down stays even if its race left. */
export function hallFloorProblem(floor: HallFloor, level: number, races: ReadonlySet<string>, before: HallFloor = DEFAULT_HALL_FLOOR): string | null {
  const { width, height } = guildLevel(level);
  const had = new Set([before.base, ...Object.values(before.tiles)]);
  for (const id of new Set([floor.base, ...Object.values(floor.tiles)])) {
    const style = HALL_FLOORS.find((f) => f.id === id);
    if (!style) return "沒有這種地板。";
    if (!had.has(id) && !hallStyleOpen(style, races)) return "這種地板要公會裡有這個種族的成員才能用。";
  }
  for (const key of Object.keys(floor.tiles)) {
    const [x, y] = key.split(",").map(Number) as [number, number];
    if (x >= width || y < WALL_ROWS || y >= height) return "地板鋪到據點外面了。";
  }
  return null;
}

/** How many of the hall's tiles differ between two floors (for the log). */
export function hallFloorChanged(a: HallFloor, b: HallFloor, level: number): number {
  const { width, height } = guildLevel(level);
  let n = 0;
  for (let y = WALL_ROWS; y < height; y++) for (let x = 0; x < width; x++) if ((a.tiles[`${x},${y}`] ?? a.base) !== (b.tiles[`${x},${y}`] ?? b.base)) n++;
  return n;
}

export const hallWallInput = z.object({ wall: z.string().max(30) });

export const guildDecorInput = z.object({
  /** The version this list was made from (someone else saved in between: refused, fetch and try again). */
  version: z.number().int().min(0),
  items: z.array(guildDecorPlacedSchema).max(GUILD_DECOR_MAX_ITEMS),
  /** The floor too, when it was changed. */
  floor: hallFloorSchema.optional(),
});
export const guildDecorRestoreInput = z.object({ logId: z.uuid() });

export function guildDecorRoomUsed(items: readonly GuildDecorPlaced[]): number {
  return items.reduce((sum, d) => sum + (BY_ID.get(d.kind)?.size ?? 0), 0);
}

/** Whether the guild may use this kind: its level is reached, and a race's piece needs a member of that race. */
export function guildDecorUnlocked(kind: GuildDecorKind, level: number, races: ReadonlySet<string>): boolean {
  return kind.level <= level && (!kind.race || races.has(kind.race));
}

/** Rounds a position to the art's pixels. */
export const snapDecor = (v: number) => Math.round(v / GUILD_DECOR_STEP) * GUILD_DECOR_STEP;

/** Why this list cannot be the hall's (null: it can). A piece already there stays even if its race left (it just can't be added again). */
export function guildDecorProblem(items: readonly GuildDecorPlaced[], level: number, races: ReadonlySet<string>, before: readonly GuildDecorPlaced[] = []): string | null {
  if (items.length > GUILD_DECOR_MAX_ITEMS) return `最多放 ${GUILD_DECOR_MAX_ITEMS} 件。`;
  const { width, height, room } = guildLevel(level);
  const had = new Map(before.map((d) => [d.uid, d.kind]));
  const uids = new Set<string>();
  for (const d of items) {
    if (uids.has(d.uid)) return "同一件裝飾出現兩次。";
    uids.add(d.uid);
    const kind = BY_ID.get(d.kind);
    if (!kind) return "沒有這種裝飾。";
    if (had.get(d.uid) !== d.kind && !guildDecorUnlocked(kind, level, races)) {
      return kind.level > level ? `${kind.name}要公會 ${kind.level} 級才能用。` : `${kind.name}要公會裡有這個種族的成員才能用。`;
    }
    const half = kind.w / 32;
    if (d.x - half < 0 || d.x + half > width) return `${kind.name}超出據點了。`;
    if (kind.wall ? d.y < 1 || d.y > WALL_ROWS + 0.01 : d.y <= WALL_ROWS || d.y > height) return kind.wall ? `${kind.name}要掛在牆上。` : `${kind.name}要放在地板上。`;
  }
  const used = guildDecorRoomUsed(items);
  if (used > room) return `裝飾點數不夠（${used}／${room}），公會升級後會有更多。`;
  return null;
}

/** What the pieces put down make of the hall: where one works, sits and drinks, and what is in the way (guild-hall.ts). */
export function guildFurnishing(items: readonly GuildDecorPlaced[]): HallFurnishing {
  const pieces = [];
  for (const d of items) {
    const k = BY_ID.get(d.kind);
    if (k) pieces.push({ x: d.x, y: d.y, flip: d.flip, spec: { w: k.w, h: k.h, flat: k.flat, wall: k.wall, ceiling: k.ceiling, living: k.living, seat: k.seat, desk: k.desk, drink: k.drink } });
  }
  return hallFurnishing(pieces);
}

/**
 * What a new guild's hall starts with (what used to be its fixed furniture): a desk for each of the first five members under
 * the wall, the fireplace, two banners, a bookshelf, the water, a bench, two plants and a rug. All of it is ordinary
 * decoration, to move or take away (2026-10-08).
 */
export function starterDecor(level = 1): GuildDecorPlaced[] {
  const { width, height } = guildLevel(level);
  const bottom = height - 0.9;
  const desks = [-6, -3, 0, 3, 6].map((dx, i) => ({ uid: `start_desk${i}`, kind: "guild_desk", x: Math.floor(width / 2) + dx, y: WALL_ROWS + 2.5 }));
  return [
    ...desks,
    { uid: "start_fire", kind: "fireplace", x: width / 2, y: WALL_ROWS + 0.2 },
    { uid: "start_flag1", kind: "guild_banner", x: 3, y: WALL_ROWS },
    { uid: "start_flag2", kind: "guild_banner", x: width - 3, y: WALL_ROWS },
    { uid: "start_books", kind: "bookshelf_tall", x: 1.2, y: WALL_ROWS + 0.4 },
    { uid: "start_water", kind: "water_elemental", x: width - 2.8, y: WALL_ROWS + 0.6 },
    { uid: "start_bench", kind: "long_bench", x: 3, y: bottom },
    { uid: "start_plant1", kind: "potted_fern", x: 0.8, y: bottom },
    { uid: "start_plant2", kind: "potted_fern", x: width - 0.8, y: bottom },
    { uid: "start_rug", kind: "red_rug", x: width / 2, y: height - 1.2 },
  ];
}

export interface GuildDecorChange {
  added: number;
  moved: number;
  removed: number;
}

/** What changed from `before` to `after`; or why this member may not make that change (a locked piece, or locking at all). */
export function guildDecorChange(before: readonly GuildDecorPlaced[], after: readonly GuildDecorPlaced[], role: GuildRole): GuildDecorChange | string {
  const was = new Map(before.map((d) => [d.uid, d]));
  const now = new Map(after.map((d) => [d.uid, d]));
  const boss = role !== "member";
  const change: GuildDecorChange = { added: 0, moved: 0, removed: 0 };
  for (const d of after) {
    const old = was.get(d.uid);
    if (!old) {
      if (d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
      change.added++;
      continue;
    }
    const same = old.kind === d.kind && old.x === d.x && old.y === d.y && !!old.flip === !!d.flip;
    if (!!old.locked !== !!d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
    if (!same && old.locked && !boss) return `${guildDecorKind(old.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能動。`;
    if (!same || !!old.locked !== !!d.locked) change.moved++; // (locking or unlocking counts as a change too)
  }
  for (const d of before) {
    if (now.has(d.uid)) continue;
    if (d.locked && !boss) return `${guildDecorKind(d.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能收掉。`;
    change.removed++;
  }
  return change;
}

/** A new piece's own id. */
export function newDecorUid(): string {
  const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let s = "";
  for (let i = 0; i < 10; i++) s += abc[Math.floor(Math.random() * abc.length)];
  return s;
}

/** One line of the log. */
export interface GuildDecorLogEntry {
  id: string;
  by: string;
  at: string;
  added: number;
  moved: number;
  removed: number;
  /** A going-back by the leader (to the list before entry `restored`). */
  restored: boolean;
  /** Floor tiles changed. */
  floor: number;
}
