/**
 * What the camp makes by itself (server/FARM.md): the residents at home fell trees and dig stone by the hour, now and then
 * turning up scrap iron or a crystal shard, and the farm grows food for expeditions. Worked out by the server from the
 * time, like births (`advanceCamp`), so it goes on while the Mac is closed; the devices only show what the server says.
 */
import { seeded } from "../world/random.ts";

/** Residents at home who work; a bigger camp does not make more past this (its numbers are for expeditions and defence). */
export const WORKERS_MAX = 60;
/** The farm stops growing a food while the store holds this many of it. */
export const FARM_KEEP = 20;
/** Digging turns up, in any hour, one scrap iron at this chance and one crystal shard at that. */
export const DIG_FINDS: Record<string, number> = { scrap_iron: 0.2, crystal_shard: 0.02 };

/** Felling and digging, per hour: base + workers × per (then × the race's knack). */
const WOOD = { id: "log", base: 1, per: 1 / 15 };
const STONE = { id: "stone", base: 0.5, per: 1 / 30 };
const KNACK: Record<string, { log?: number; stone?: number }> = {
  elf: { log: 0.7 }, // (elves pick up fallen branches instead of felling)
  undead: { log: 0.8, stone: 1.5 }, // (the undead love to dig)
};

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

/** How much of each thing the camp makes in an hour (the dig finds as their chance per hour). */
export function productionPerHour(race: string, workers: number, farmLevel: number): Record<string, number> {
  const w = Math.max(0, Math.min(WORKERS_MAX, workers));
  const knack = KNACK[race] ?? {};
  const out: Record<string, number> = {
    log: (WOOD.base + w * WOOD.per) * (knack.log ?? 1),
    stone: (STONE.base + w * STONE.per) * (knack.stone ?? 1),
    ...DIG_FINDS,
  };
  const boost = farmLevel >= FARM_MAX ? HARVEST_BOOST : 1;
  for (const crop of farmCrops(race, farmLevel)) out[crop.food] = (out[crop.food] ?? 0) + boost / crop.hours;
  return out;
}

export interface ProduceInput {
  race: string;
  seed: number;
  /** Those at home at a moment (each hour counts those at its end), or one number for the whole stretch. */
  workers: number | ((at: number) => number);
  farmLevel: number;
  /** Worked out up to here (a whole number of hours are added to it). */
  from: number;
  to: number;
  /** The fractions left over from before (id → 0…1). */
  carry: Record<string, number>;
  /** What the store has now (the farm's foods stop at FARM_KEEP). */
  store: Record<string, number>;
}

export interface ProduceResult {
  got: Record<string, number>;
  carry: Record<string, number>;
  /** How far it has been worked out (`from` + whole hours). */
  to: number;
}

const HOUR = 3_600_000;

/**
 * The whole hours between `from` and `to`, one by one: wood, stone and the farm's food add up (fractions carried to the
 * next time, so it comes out the same worked out all at once or bit by bit), each hour's dig rolls for its finds (seeded
 * by the camp and the hour).
 */
export function produce(input: ProduceInput): ProduceResult {
  const hours = Math.max(0, Math.floor((input.to - input.from) / HOUR));
  const workersAt = typeof input.workers === "number" ? () => input.workers as number : input.workers;
  const foods = new Set(farmCrops(input.race, input.farmLevel).map((c) => c.food));
  const carry = { ...input.carry };
  const got: Record<string, number> = {};
  const firstHour = Math.floor(input.from / HOUR);
  for (let h = 0; h < hours; h++) {
    const perHour = productionPerHour(input.race, workersAt(input.from + (h + 1) * HOUR), input.farmLevel);
    for (const [id, rate] of Object.entries(perHour)) {
      if (id in DIG_FINDS) continue;
      const total = (carry[id] ?? 0) + rate;
      const whole = Math.floor(total + 1e-9);
      carry[id] = Math.max(0, total - whole);
      if (whole === 0) continue;
      if (foods.has(id) && (input.store[id] ?? 0) + (got[id] ?? 0) >= FARM_KEEP) continue; // (a full store: what grows past it is lost)
      got[id] = (got[id] ?? 0) + whole;
    }
    const roll = seeded(input.seed, "dig", firstHour + h);
    for (const [id, chance] of Object.entries(DIG_FINDS)) if (roll() < chance) got[id] = (got[id] ?? 0) + 1;
  }
  for (const [id, n] of Object.entries(carry)) if (n === 0) delete carry[id];
  return { got, carry, to: input.from + hours * HOUR };
}
