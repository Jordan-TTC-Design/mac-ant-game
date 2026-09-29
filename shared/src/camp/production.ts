/**
 * The farm (server/FARM.md §3.3): one per camp, raised level by level, each level adding a crop that grows food for
 * expeditions. It is one of the camp's sites (sites.ts), which work the hours out.
 */

/** A food stops growing while the store holds this many of it (the farm's, and the other sites' foods). */
export const FARM_KEEP = 20;

export interface Crop {
  /** The food it gives (a material id, the ones expeditions take along: world/supplies.ts). */
  food: string;
  /** One every this many hours. */
  hours: number;
}

export interface FarmLevel {
  level: number;
  /** What going up to this level costs, and how long it takes (level 1 is where every camp starts). */
  cost: Record<string, number>;
  hours: number;
  /** The crop this level adds (null: level 5, which makes every crop grow half as fast again). */
  crop: Crop | null;
}

export const FARM_LEVELS: readonly FarmLevel[] = [
  { level: 1, cost: {}, hours: 0, crop: { food: "food_carrot", hours: 3 } },
  { level: 2, cost: { log: 60, stone: 30 }, hours: 2, crop: { food: "ration_bread", hours: 2 } },
  { level: 3, cost: { log: 150, stone: 80 }, hours: 6, crop: { food: "food_honey", hours: 4 } },
  { level: 4, cost: { log: 300, stone: 160, leather_strap: 2 }, hours: 12, crop: { food: "food_cheese", hours: 4 } },
  { level: 5, cost: { log: 600, stone: 300, orc_tusk: 2 }, hours: 24, crop: null },
];
export const FARM_MAX = FARM_LEVELS.length;
/** Level 5: every crop ×1.5. */
export const HARVEST_BOOST = 1.5;

/** The same numbers for every race; the names (and one crop) differ. */
const FARM_LOOKS: Record<string, { farm: string; parts: [string, string, string, string, string]; level2?: string }> = {
  goblin: { farm: "田地", parts: ["菜園", "麥田", "蜂箱", "羊圈", "豐收"] },
  elf: { farm: "田地", parts: ["菜園", "果園", "蜂箱", "羊圈", "豐收"], level2: "ration_berry" },
  undead: { farm: "墓園", parts: ["墓園菜圃", "骨粉田", "夜蜂箱", "骷髏羊圈", "豐收"], level2: "ration_jerky" },
};
const looks = (race: string) => FARM_LOOKS[race] ?? FARM_LOOKS.goblin!;

/** What the farm is called for a race (田地; the undead's 墓園), and what each level adds. */
export function farmName(race: string): string {
  return looks(race).farm;
}
export function farmPartName(race: string, level: number): string {
  return looks(race).parts[level - 1] ?? "";
}

/** The crops a race's farm grows at `level` (elves grow berries, the undead jerky, where goblins grow bread). */
export function farmCrops(race: string, level: number): Crop[] {
  const out: Crop[] = [];
  for (const l of FARM_LEVELS) {
    if (l.level > level || !l.crop) continue;
    out.push(l.level === 2 && looks(race).level2 ? { ...l.crop, food: looks(race).level2! } : l.crop);
  }
  return out;
}

/** What going up from `level` costs and takes (null: already at the top). */
export function nextFarmLevel(level: number): FarmLevel | null {
  return FARM_LEVELS[level] ?? null;
}

/** The farm's food per hour at `level` (level 5: every crop ×1.5). */
export function farmPerHour(race: string, level: number): Record<string, number> {
  const out: Record<string, number> = {};
  const boost = level >= FARM_MAX ? HARVEST_BOOST : 1;
  for (const crop of farmCrops(race, level)) out[crop.food] = (out[crop.food] ?? 0) + boost / crop.hours;
  return out;
}
