/**
 * World events (server/WORLD.md §30): meteors that fall on empty cells for a while (the first party there takes what fell),
 * and the seasons (Halloween, the winter feast, the new year, the summer festival) that make the big world give more for a few
 * weeks. Like the great monsters (bosses.ts) they come from the world's seed and the time, so nothing has to be kept about
 * where they are; only a meteor taken is written down (the server's world_bosses row of key `meteorKey`).
 */
import { cellId, parseCell, type CellId } from "./grid.ts";
import { between, seeded } from "./random.ts";

/** Meteors: one block of this many cells across (about 2.3 km) may get one every METEOR_HOURS. */
export const METEOR_BLOCK_CELLS = 13;
export const METEOR_HOURS = 4;
export const METEOR_CHANCE = 0.35;

export interface MeteorSighting {
  key: string;
  cell: CellId;
  startsAt: number;
  endsAt: number;
  /** What a party reaching it first takes home. */
  loot: Record<string, number>;
}

const blockOf = (cell: CellId) => {
  const { row, col } = parseCell(cell);
  return `${Math.floor(row / METEOR_BLOCK_CELLS)}:${Math.floor(col / METEOR_BLOCK_CELLS)}`;
};
export const meteorWindow = (at: number) => Math.floor(at / (METEOR_HOURS * 3_600_000));
export const meteorKey = (block: string, window: number) => `meteor:${block}@${window}`;

/** The meteor of a block in a window (or none), more often in a season that brings more. */
export function meteorIn(worldSeed: number, block: string, window: number): MeteorSighting | null {
  const startsAt = window * METEOR_HOURS * 3_600_000;
  const random = seeded(worldSeed, "meteor", block, window);
  if (random() >= METEOR_CHANCE * (seasonAt(new Date(startsAt))?.meteors ?? 1)) return null;
  const [r, c] = block.split(":").map(Number) as [number, number];
  const cell = cellId(r * METEOR_BLOCK_CELLS + between(random, 1, METEOR_BLOCK_CELLS - 2), c * METEOR_BLOCK_CELLS + between(random, 1, METEOR_BLOCK_CELLS - 2));
  const loot: Record<string, number> = { crystal_shard: between(random, 2, 4), amber: between(random, 1, 2), scrap_iron: between(random, 3, 6) };
  return { key: meteorKey(block, window), cell, startsAt, endsAt: startsAt + METEOR_HOURS * 3_600_000, loot };
}

/** The meteor lying in `cell` at `at`, if any (taken or not: the server knows which were taken). */
export function meteorAt(worldSeed: number, cell: CellId, at: number): MeteorSighting | null {
  const m = meteorIn(worldSeed, blockOf(cell), meteorWindow(at));
  return m?.cell === cell ? m : null;
}

/** A season of the year (Taipei's calendar, the same every year), and what it gives in the big world. */
export interface Season {
  id: string;
  name: string;
  icon: string;
  blurb: string;
  /** Month-day, both days included ("10-15"). */
  from: string;
  to: string;
  /** Beaten lairs drop this share more; meteors fall this many times as often. */
  loot: number;
  meteors: number;
}

export const SEASONS: readonly Season[] = [
  { id: "newyear", name: "新年", icon: "🧧", blurb: "新年快樂：打贏巢穴的掉落 +20%", from: "01-01", to: "01-07", loot: 0.2, meteors: 1 },
  { id: "summer", name: "夏日祭", icon: "🎆", blurb: "夏夜流星雨：流星掉得兩倍多", from: "07-20", to: "08-10", loot: 0, meteors: 2 },
  { id: "halloween", name: "萬聖夜", icon: "🎃", blurb: "魔物躁動：打贏巢穴的掉落 +25%，流星多一半", from: "10-15", to: "11-02", loot: 0.25, meteors: 1.5 },
  { id: "winter", name: "冬至祭", icon: "🎄", blurb: "冬夜的星星：流星掉得兩倍多，打贏巢穴的掉落 +10%", from: "12-18", to: "12-31", loot: 0.1, meteors: 2 },
];

/** The season on at `at` (Taipei's day), if any. */
export function seasonAt(at: Date): Season | null {
  const md = new Date(at.getTime() + 8 * 3_600_000).toISOString().slice(5, 10);
  return SEASONS.find((s) => md >= s.from && md <= s.to) ?? null;
}

/** When `season`, on at `at`, ends (the start of the Taipei day after its last). */
export function seasonEndsAt(season: Season, at: Date): Date {
  const year = new Date(at.getTime() + 8 * 3_600_000).getUTCFullYear();
  return new Date(Date.parse(`${year}-${season.to}T00:00:00+08:00`) + 24 * 3_600_000);
}
