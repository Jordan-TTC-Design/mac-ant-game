/**
 * Decorating the guild hall (GUILD.md §4.2): every member may put down any decoration the guild has unlocked (by its level,
 * and a race's set by having a member of that race), as many of a kind as they like, as long as the room lasts. The leader
 * and officers may lock a piece so only they can move it; every change is logged, and the leader can go back to before one.
 */
import { z } from "zod";
import { GUILD_DECOR, type GuildDecorKind } from "./guild-decor-catalog.ts";
import { guildLevel, type GuildRole } from "./guild.ts";
import { DEFAULT_HALL_AREA, HALL_AREA_MAX_HEIGHT, HALL_AREA_MAX_WIDTH, hallAreaHas, hallAreaSize, hallFurnishing, WALL_ROWS, type HallArea, type HallFurnishing } from "./guild-hall.ts";
import { guildSeason, seasonOpen, taipeiDay } from "./guild-seasons.ts";

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
export function hallFloorProblem(floor: HallFloor, area: HallArea, races: ReadonlySet<string>, before: HallFloor = DEFAULT_HALL_FLOOR): string | null {
  const had = new Set([before.base, ...Object.values(before.tiles)]);
  for (const id of new Set([floor.base, ...Object.values(floor.tiles)])) {
    const style = HALL_FLOORS.find((f) => f.id === id);
    if (!style) return "沒有這種地板。";
    if (!had.has(id) && !hallStyleOpen(style, races)) return "這種地板要公會裡有這個種族的成員才能用。";
  }
  for (const key of Object.keys(floor.tiles)) {
    const [x, y] = key.split(",").map(Number) as [number, number];
    if (!hallAreaHas(area, x, y)) return "地板鋪到據點外面了。";
  }
  return null;
}

/** Tiles keyed "x,y" (floor tiles, wall segments, plots): two digits each at most (HALL_AREA_MAX_WIDTH, HALL_AREA_MAX_HEIGHT). */
const tileKey = z.string().regex(/^\d{1,2},\d{1,2}$/);
const keyXY = (key: string) => key.split(",").map(Number) as [number, number];

/**
 * The wall brushed segment by segment (GUILD.md §4.3, 2026-10-17): "x,y" of the floor tile whose top edge grows that column
 * of wall → its style. The rest are the guild's `wall`.
 */
export const hallWallsSchema = z.record(tileKey, z.string().max(30));
export type HallWalls = z.infer<typeof hallWallsSchema>;

/** Whether floor tile (x, y) has wall over it (it is floor and the tile above is not). */
export function hallWallAt(area: HallArea, x: number, y: number): boolean {
  return hallAreaHas(area, x, y) && !hallAreaHas(area, x, y - 1);
}

/** Why these wall segments cannot be the hall's (null: they can). A style already up stays even if its race left. */
export function hallWallsProblem(walls: HallWalls, area: HallArea, races: ReadonlySet<string>, before: HallWalls = {}, base?: string): string | null {
  const had = new Set([...Object.values(before), ...(base ? [base] : [])]);
  for (const id of new Set(Object.values(walls))) {
    const style = HALL_WALLS.find((w) => w.id === id);
    if (!style) return "沒有這種牆壁。";
    if (!had.has(id) && !hallStyleOpen(style, races)) return "這種牆壁要公會裡有這個種族的成員才能用。";
  }
  for (const key of Object.keys(walls)) if (!hallWallAt(area, ...keyXY(key))) return "牆壁刷到沒有牆的地方了。";
  return null;
}

/** How many wall segments differ (for the log). */
export function hallWallsChanged(a: HallWalls, b: HallWalls): number {
  let n = 0;
  for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) if (a[key] !== b[key]) n++;
  return n;
}

/**
 * The members' own places (GUILD.md §4, 2026-10-17: the leader or an officer gives each member some floor): "x,y" → the
 * member's id. Inside one only that member, the leader and the officers touch the pieces.
 */
export const hallPlotsSchema = z.record(tileKey, z.uuid());
export type HallPlots = z.infer<typeof hallPlotsSchema>;

/** Why these plots cannot be the hall's (null: they can): each on the floor, each a member's. */
export function hallPlotsProblem(plots: HallPlots, area: HallArea, members: ReadonlySet<string>): string | null {
  for (const [key, who] of Object.entries(plots)) {
    if (!hallAreaHas(area, ...keyXY(key))) return "分到的位置在據點外面。";
    if (!members.has(who)) return "只能分給公會的成員。";
  }
  return null;
}

/** The tile a piece belongs to (for the plots): the one under its feet; a wall piece's, the floor tile at the foot of its wall. */
export function guildDecorTile(area: HallArea, d: Pick<GuildDecorPlaced, "kind" | "x" | "y">): string {
  const x = Math.floor(d.x);
  if (BY_ID.get(d.kind)?.wall) {
    for (let r = Math.ceil(d.y); r <= Math.ceil(d.y) + WALL_ROWS; r++) if (hallWallAt(area, x, r)) return `${x},${r}`;
  }
  return `${x},${Math.floor(d.y - 1e-6)}`;
}

/** Tile keys moved by (dx, dy) (the hall's shape grew up or to the left: hallAreaPaint), the ones pushed off dropped. */
export function shiftTileKeys<T>(map: Readonly<Record<string, T>>, dx: number, dy: number): Record<string, T> {
  if (!dx && !dy) return { ...map };
  const out: Record<string, T> = {};
  for (const [key, v] of Object.entries(map)) {
    const [x, y] = keyXY(key);
    if (x + dx >= 0 && y + dy >= 0) out[`${x + dx},${y + dy}`] = v;
  }
  return out;
}

/** The keys still good after the hall's shape changed (`ok`: hallAreaHas for plots, hallWallAt for walls). */
export function keepTileKeys<T>(map: Readonly<Record<string, T>>, ok: (x: number, y: number) => boolean): Record<string, T> {
  return Object.fromEntries(Object.entries(map).filter(([key]) => ok(...keyXY(key))));
}

/** How many of the hall's tiles differ between two floors (for the log). */
export function hallFloorChanged(a: HallFloor, b: HallFloor, area: HallArea): number {
  const { width, height } = hallAreaSize(area);
  let n = 0;
  for (let y = WALL_ROWS; y < height; y++) for (let x = 0; x < width; x++) if ((a.tiles[`${x},${y}`] ?? a.base) !== (b.tiles[`${x},${y}`] ?? b.base)) n++;
  return n;
}

const HALL_AREA_LINE_MAX = HALL_AREA_MAX_WIDTH;
const HALL_AREA_LINES_MAX = HALL_AREA_MAX_HEIGHT - WALL_ROWS;

export const hallWallInput = z.object({ wall: z.string().max(30) });

export const guildDecorInput = z.object({
  /** The version this list was made from (someone else saved in between: refused, fetch and try again). */
  version: z.number().int().min(0),
  items: z.array(guildDecorPlacedSchema).max(GUILD_DECOR_MAX_ITEMS),
  /** The floor too, when it was changed. */
  floor: hallFloorSchema.optional(),
  /** The hall's shape too, when it was drawn anew (the leader and officers; shared/src/guild-hall.ts HallArea). */
  area: z.array(z.string().max(HALL_AREA_LINE_MAX)).max(HALL_AREA_LINES_MAX).optional(),
  /** The wall segments brushed, and the members' places, when changed (the leader and officers). */
  walls: hallWallsSchema.optional(),
  plots: hallPlotsSchema.optional(),
});
export const guildDecorRestoreInput = z.object({ logId: z.uuid() });

export function guildDecorRoomUsed(items: readonly GuildDecorPlaced[]): number {
  return items.reduce((sum, d) => sum + (BY_ID.get(d.kind)?.size ?? 0), 0);
}

/** Whether the guild may put this kind down (`today`: "yyyy-mm-dd" in Taiwan): its level is reached, a race's piece needs a member
 *  of that race, and a holiday piece needs its season to be on. */
export function guildDecorUnlocked(kind: Pick<GuildDecorKind, "level" | "race" | "season">, level: number, races: ReadonlySet<string>, today: string = taipeiDay(new Date())): boolean {
  if (kind.level > level || (kind.race && !races.has(kind.race))) return false;
  const season = kind.season ? guildSeason(kind.season) : undefined;
  return !season || seasonOpen(season, today);
}

/** Rounds a position to the art's pixels. */
export const snapDecor = (v: number) => Math.round(v / GUILD_DECOR_STEP) * GUILD_DECOR_STEP;

/**
 * Whether a piece of this kind may stand with its feet at (x, y) in this hall: one on the floor stands on floor all along
 * its bottom; one for the wall hangs on the wall over a top edge of the floor (its bottom no higher than the wall's top and
 * no lower than the floor).
 */
export function guildDecorFits(area: HallArea, kind: { w: number; wall: boolean }, x: number, y: number): boolean {
  const eps = 1e-6;
  const half = kind.w / 32;
  const [c0, c1] = [Math.floor(x - half + eps), Math.floor(x + half - eps)];
  const every = (ok: (c: number) => boolean) => {
    for (let c = c0; c <= c1; c++) if (!ok(c)) return false;
    return true;
  };
  if (kind.wall) {
    return [Math.ceil(y), Math.ceil(y) + 1].some((r) => y >= r - 1 && y <= r && every((c) => hallAreaHas(area, c, r) && !hallAreaHas(area, c, r - 1)));
  }
  const r = Math.floor(y - eps);
  return every((c) => hallAreaHas(area, c, r));
}

/** Why this list cannot be the hall's (null: it can). A piece already there stays even if its race left or its season is over (it just can't be added again). */
export function guildDecorProblem(items: readonly GuildDecorPlaced[], level: number, area: HallArea, races: ReadonlySet<string>, before: readonly GuildDecorPlaced[] = [], today: string = taipeiDay(new Date())): string | null {
  if (items.length > GUILD_DECOR_MAX_ITEMS) return `最多放 ${GUILD_DECOR_MAX_ITEMS} 件。`;
  const { room } = guildLevel(level);
  const had = new Map(before.map((d) => [d.uid, d.kind]));
  const uids = new Set<string>();
  for (const d of items) {
    if (uids.has(d.uid)) return "同一件裝飾出現兩次。";
    uids.add(d.uid);
    const kind = BY_ID.get(d.kind);
    if (!kind) return "沒有這種裝飾。";
    if (had.get(d.uid) !== d.kind && !guildDecorUnlocked(kind, level, races, today)) {
      if (kind.level > level) return `${kind.name}要公會 ${kind.level} 級才能用。`;
      if (kind.race && !races.has(kind.race)) return `${kind.name}要公會裡有這個種族的成員才能用。`;
      return `${kind.name}是${guildSeason(kind.season ?? "")?.name ?? "節日"}限定，節日期間才能擺新的。`;
    }
    if (!guildDecorFits(area, kind, d.x, d.y)) return kind.wall ? `${kind.name}要掛在牆上。` : `${kind.name}要整個放在據點的地板上。`;
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
export function starterDecor(): GuildDecorPlaced[] {
  const { width, height } = hallAreaSize(DEFAULT_HALL_AREA);
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

/** Everything in the hall moved by (dx, dy) tiles (its shape grew up or to the left, or lost its top or left: hallAreaPaint). */
export function shiftHall(decor: readonly GuildDecorPlaced[], floor: HallFloor, dx: number, dy: number): { decor: GuildDecorPlaced[]; floor: HallFloor } {
  if (!dx && !dy) return { decor: [...decor], floor };
  const tiles: Record<string, string> = {};
  for (const [key, id] of Object.entries(floor.tiles)) {
    const [x, y] = key.split(",").map(Number) as [number, number];
    if (x + dx >= 0 && y + dy >= 0) tiles[`${x + dx},${y + dy}`] = id;
  }
  return { decor: decor.map((d) => ({ ...d, x: d.x + dx, y: d.y + dy })), floor: { base: floor.base, tiles } };
}

/** What still fits after the hall's shape changed: the pieces and floor tiles left outside it are taken away. */
export function keepInside(area: HallArea, decor: readonly GuildDecorPlaced[], floor: HallFloor): { decor: GuildDecorPlaced[]; floor: HallFloor; dropped: number } {
  const kept = decor.filter((d) => {
    const k = BY_ID.get(d.kind);
    return !k || guildDecorFits(area, k, d.x, d.y);
  });
  const tiles = Object.fromEntries(Object.entries(floor.tiles).filter(([key]) => {
    const [x, y] = key.split(",").map(Number) as [number, number];
    return hallAreaHas(area, x, y);
  }));
  return { decor: kept, floor: { base: floor.base, tiles }, dropped: decor.length - kept.length };
}

export interface GuildDecorChange {
  added: number;
  moved: number;
  removed: number;
}

/** Whose place a member may not touch (the plots, with who they are), for guildDecorChange. */
export interface GuildDecorPlaces {
  me: string;
  area: HallArea;
  plots: HallPlots;
  /** Member id → name (a plot of someone not in here is nobody's). */
  names: ReadonlyMap<string, string>;
}

/**
 * What changed from `before` to `after`; or why this member may not make that change (a locked piece, locking at all, or a
 * piece in someone else's place: `places`, where it was or where it went).
 */
export function guildDecorChange(before: readonly GuildDecorPlaced[], after: readonly GuildDecorPlaced[], role: GuildRole, places?: GuildDecorPlaces): GuildDecorChange | string {
  const was = new Map(before.map((d) => [d.uid, d]));
  const now = new Map(after.map((d) => [d.uid, d]));
  const boss = role !== "member";
  const change: GuildDecorChange = { added: 0, moved: 0, removed: 0 };
  const theirs = (d: GuildDecorPlaced) => {
    if (boss || !places) return null;
    const who = places.plots[guildDecorTile(places.area, d)];
    return who && who !== places.me && places.names.has(who) ? `這裡是${places.names.get(who)}的位置，只有他自己和會長、幹部能動。` : null;
  };
  for (const d of after) {
    const old = was.get(d.uid);
    if (!old) {
      if (d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
      const why = theirs(d);
      if (why) return why;
      change.added++;
      continue;
    }
    const same = old.kind === d.kind && old.x === d.x && old.y === d.y && !!old.flip === !!d.flip;
    if (!!old.locked !== !!d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
    if (!same && old.locked && !boss) return `${guildDecorKind(old.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能動。`;
    if (!same) {
      const why = theirs(old) ?? theirs(d);
      if (why) return why;
    }
    if (!same || !!old.locked !== !!d.locked) change.moved++; // (locking or unlocking counts as a change too)
  }
  for (const d of before) {
    if (now.has(d.uid)) continue;
    if (d.locked && !boss) return `${guildDecorKind(d.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能收掉。`;
    const why = theirs(d);
    if (why) return why;
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
  /** The hall's shape was drawn anew. */
  area: boolean;
  /** Wall segments brushed, and whether the members' places were changed (older entries: 0, false). */
  walls: number;
  plots: boolean;
}
