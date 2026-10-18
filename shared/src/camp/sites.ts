/**
 * The camp's sites (server/FARM.md §11): a few plots of ground, each with a site on it — the farm, a lumber camp, a quarry,
 * a mine, traps… — raised level by level. A site works only with hands: every level needs WORKERS_PER_LEVEL residents at
 * home; when there are too few, every site slows down alike. Worked out by the server by the hour, like births.
 */
import { seeded } from "../world/random.ts";
import { campStage } from "./races.ts";
import { FARM_KEEP, FARM_LEVELS, FARM_MAX, farmName, farmPartName, farmPerHour } from "./production.ts";

export type SiteKind = "farm" | "lumber" | "quarry" | "mine" | "traps" | "fishery" | "hunter" | "scrapyard" | "grove" | "soulwell" | "huntground";

/** A site as the books keep it. `level` 0: still being built. `busyUntil`: being built or raised a level, done then (ISO). */
export interface Site {
  id: number;
  kind: SiteKind;
  level: number;
  busyUntil?: string | null;
}

/** Plots of ground by the camp's look (1, 2, 3); one more for every RACE_LEVELS_PER_SLOT levels of the race (big world). */
export const SLOTS_BY_STAGE = [2, 4, 6] as const;
export const RACE_LEVELS_PER_SLOT = 5;
export const WORKERS_PER_LEVEL = 10;
/** What the camp picks up with no site at all, per hour (so a new camp can build its first). */
export const GATHERING: Record<string, number> = { log: 2, stone: 1 };
/** Hours to build a site (level 1), and to raise it to level 2, 3, 4 and 5. */
export const SITE_HOURS = [1, 4, 12, 24, 48] as const;
/** The race level (big world) from which a site (not the farm) may be raised to level 4, and to level 5 (DESKTOP.md §10.0). */
export const SITE_LEVEL_4_AT = 10;
export const SITE_LEVEL_5_AT = 20;
/** Levels 4 and 5 make this many times level 3, and cost this many times raising it to 3, with crystal shards on top. */
const HIGH_LEVELS = [
  { makes: 1.5, cost: 2, crystal_shard: 3 },
  { makes: 2, cost: 4, crystal_shard: 10 },
] as const;
/** A site taken down gives back this share of all it cost. */
export const DEMOLISH_REFUND = 0.5;

interface Version {
  name: string;
  /** Material id → how many an hour at levels 1, 2, 3 (with every hand). */
  makes: Record<string, readonly [number, number, number]>;
  /** Material id → the chance an hour of finding one, at levels 1, 2, 3. */
  finds?: Record<string, readonly [number, number, number]>;
}

export interface SiteRule {
  kind: SiteKind;
  /** Races that may build it (all when left out). */
  only?: readonly string[];
  /** The goblins' version; a race's own name and makes where they differ. */
  base: Version;
  races?: Record<string, Partial<Version>>;
  /** Cost of building it (level 1), and of raising it to 2 and 3. */
  costs: readonly [Record<string, number>, Record<string, number>, Record<string, number>];
}

const lv = (a: number, b: number, c: number) => [a, b, c] as const;
const scaled = (m: Record<string, readonly [number, number, number]>, k: number) =>
  Object.fromEntries(Object.entries(m).map(([id, v]) => [id, lv(v[0] * k, v[1] * k, v[2] * k)]));

const LUMBER = { log: lv(2, 4, 7) };
const QUARRY = { stone: lv(1, 2, 3.5) };
const ORE = { scrap_iron: lv(0.3, 0.6, 1) };
const SCRAPS = { scrap_rag: lv(1, 2, 3), scrap_wood: lv(1, 2, 3) };

export const SITE_RULES: readonly SiteRule[] = [
  {
    kind: "lumber",
    base: { name: "伐木場", makes: LUMBER },
    races: { elf: { name: "撿柴林", makes: scaled(LUMBER, 0.7) }, undead: { makes: scaled(LUMBER, 0.8) } },
    costs: [{ log: 10 }, { log: 60, stone: 20 }, { log: 150, stone: 80, leather_strap: 1 }],
  },
  {
    kind: "quarry",
    base: { name: "採石場", makes: QUARRY },
    races: { undead: { makes: scaled(QUARRY, 1.5) } },
    costs: [{ log: 20 }, { log: 60, stone: 40 }, { log: 150, stone: 100, leather_strap: 1 }],
  },
  {
    kind: "mine",
    base: { name: "礦坑", makes: ORE, finds: { crystal_shard: lv(0.02, 0.04, 0.07) } },
    races: { undead: { makes: scaled(ORE, 1.5) } },
    costs: [{ log: 60, stone: 40 }, { log: 120, stone: 100, scrap_iron: 10 }, { log: 250, stone: 200, crude_blade: 2 }],
  },
  {
    kind: "traps",
    base: { name: "陷阱場", makes: { rat_fang: lv(0.3, 0.6, 1), rat_pelt: lv(0.15, 0.3, 0.5), rat_tail: lv(0.1, 0.2, 0.3) } },
    costs: [{ log: 40, stone: 10 }, { log: 100, stone: 30, rat_pelt: 3 }, { log: 200, stone: 80, leather_strap: 2 }],
  },
  {
    kind: "fishery",
    base: { name: "漁場", makes: { ration_fish: lv(0.33, 0.5, 0.75) } },
    races: { undead: { name: "醃肉窖", makes: { ration_jerky: lv(0.33, 0.5, 0.75) } } }, // (the undead do not fish)
    costs: [{ log: 50 }, { log: 100, stone: 30 }, { log: 200, stone: 80, leather_strap: 2 }],
  },
  {
    kind: "hunter",
    base: { name: "獵人小屋", makes: { food_meat: lv(0.2, 0.35, 0.5), rabbit_fur: lv(0.15, 0.3, 0.45) } },
    races: {
      elf: { name: "射手小屋", makes: { feather: lv(0.2, 0.35, 0.5), rabbit_fur: lv(0.15, 0.3, 0.45) } }, // (elves eat no meat)
      beast: { name: "獵手小屋", makes: { food_meat: lv(0.3, 0.5, 0.75), rabbit_fur: lv(0.15, 0.3, 0.45) } }, // (beasts hunt keenly)
    },
    costs: [{ log: 40, stone: 10 }, { log: 100, stone: 40, fox_tail: 2 }, { log: 200, stone: 100, orc_tusk: 2 }],
  },
  {
    // every race may pick odds and ends up (2026-09-29: elves and the undead had no rags or chips but the raids'); goblins best
    kind: "scrapyard",
    base: { name: "廢料場", makes: SCRAPS },
    races: {
      elf: { name: "拾荒棚", makes: scaled(SCRAPS, 0.7) },
      undead: { name: "拾骨場", makes: scaled(SCRAPS, 0.7) },
      beast: { name: "拾荒坡", makes: scaled(SCRAPS, 0.7) },
    },
    costs: [{ log: 40, stone: 20 }, { log: 100, stone: 50 }, { log: 200, stone: 120, leather_strap: 2 }],
  },
  {
    kind: "grove",
    only: ["elf"],
    base: { name: "採集林", makes: { ration_berry: lv(0.5, 0.8, 1.2), food_honey: lv(0.25, 0.4, 0.6) } },
    costs: [{ log: 40, stone: 20 }, { log: 100, stone: 50 }, { log: 200, stone: 120, leather_strap: 2 }],
  },
  {
    kind: "soulwell",
    only: ["undead"],
    base: { name: "魂井", makes: { night_dust: lv(0.1, 0.2, 0.3) }, finds: { crystal_shard: lv(0.03, 0.05, 0.08) } },
    costs: [{ log: 40, stone: 20 }, { log: 100, stone: 50 }, { log: 200, stone: 120, leather_strap: 2 }],
  },
  {
    // the beasts' own (RACES_BEAST.md §6): more hunting, more meat, and a pelt or a tail now and then
    kind: "huntground",
    only: ["beast"],
    base: { name: "狩獵場", makes: { food_meat: lv(0.4, 0.7, 1.05), rabbit_fur: lv(0.1, 0.2, 0.3) }, finds: { fox_tail: lv(0.03, 0.05, 0.08) } },
    costs: [{ log: 40, stone: 20 }, { log: 100, stone: 50 }, { log: 200, stone: 120, leather_strap: 2 }],
  },
];
const RULES = new Map(SITE_RULES.map((r) => [r.kind, r]));

export function siteRule(kind: string): SiteRule | undefined {
  return RULES.get(kind as SiteKind);
}

/** The kinds a race may build (the farm comes with every camp and is not built). */
export function buildableKinds(race: string): SiteKind[] {
  return SITE_RULES.filter((r) => !r.only || r.only.includes(race)).map((r) => r.kind);
}

function version(race: string, kind: SiteKind): Version {
  const rule = RULES.get(kind)!;
  return { ...rule.base, ...(rule.races?.[race] ?? {}) };
}

export function siteName(race: string, kind: SiteKind): string {
  return kind === "farm" ? farmName(race) : version(race, kind).name;
}

/** How high a site may go: 3 (the farm FARM_MAX), and 4 and 5 from race levels SITE_LEVEL_4_AT and SITE_LEVEL_5_AT. */
export function siteMaxLevel(kind: SiteKind, raceLevel = 1): number {
  if (kind === "farm") return FARM_MAX;
  return 3 + (raceLevel >= SITE_LEVEL_4_AT ? 1 : 0) + (raceLevel >= SITE_LEVEL_5_AT ? 1 : 0);
}

/** What raising a site from `level` costs and takes (0: building it), whether or not the race level allows it yet. */
function siteStep(kind: SiteKind, level: number): { cost: Record<string, number>; hours: number } | null {
  if (kind === "farm") {
    const next = FARM_LEVELS[level];
    return next ? { cost: next.cost, hours: next.hours } : null;
  }
  const costs = RULES.get(kind)!.costs;
  if (level < 3) return { cost: costs[level]!, hours: SITE_HOURS[level]! };
  const high = HIGH_LEVELS[level - 3];
  if (!high) return null;
  const cost = Object.fromEntries(Object.entries(costs[2]).map(([id, n]) => [id, n * high.cost]));
  cost.crystal_shard = (cost.crystal_shard ?? 0) + high.crystal_shard;
  return { cost, hours: SITE_HOURS[level]! };
}

/** What raising a site from `level` costs and takes (0: building it); null at the top (for this race level). */
export function siteNext(kind: SiteKind, level: number, raceLevel = 1): { cost: Record<string, number>; hours: number; name: string } | null {
  if (level >= siteMaxLevel(kind, raceLevel)) return null;
  const step = siteStep(kind, level);
  return step && { ...step, name: "" };
}

/** Everything a site has cost up to `level` (for giving half back when it is taken down). */
export function siteSpent(kind: SiteKind, level: number): Record<string, number> {
  const out: Record<string, number> = {};
  for (let l = 0; l < level; l++) for (const [id, n] of Object.entries(siteStep(kind, l)?.cost ?? {})) out[id] = (out[id] ?? 0) + n;
  return out;
}

/** Plots of ground a camp has (its look from the most it has ever had, and its race's level in the big world). */
export function slotsFor(race: string, peak: number, raceLevel = 1): number {
  return SLOTS_BY_STAGE[campStage(race, peak) - 1]! + Math.floor(Math.max(0, raceLevel) / RACE_LEVELS_PER_SLOT);
}

/** Hands the sites need (every built level), and the share of it they get from `workers` at home (0…1). */
export function staffing(sites: readonly Site[], workers: number): { need: number; share: number } {
  const need = sites.reduce((n, s) => n + s.level * WORKERS_PER_LEVEL, 0);
  return { need, share: need === 0 ? 1 : Math.min(1, Math.max(0, workers) / need) };
}

/** What one site makes an hour with every hand (the finds: their chance an hour). */
export function sitePerHour(race: string, site: Pick<Site, "kind" | "level">): { makes: Record<string, number>; finds: Record<string, number> } {
  if (site.level <= 0) return { makes: {}, finds: {} };
  if (site.kind === "farm") return { makes: farmPerHour(race, site.level), finds: {} };
  const v = version(race, site.kind);
  // (levels 4 and 5: level 3's, times HIGH_LEVELS)
  const times = site.level > 3 ? (HIGH_LEVELS[site.level - 4]?.makes ?? HIGH_LEVELS[1].makes) : 1;
  const pick = (m: Record<string, readonly number[]> | undefined) => Object.fromEntries(Object.entries(m ?? {}).map(([id, n]) => [id, n[Math.min(site.level, 3) - 1]! * times]));
  return { makes: pick(v.makes), finds: pick(v.finds) };
}

/** What the camp makes an hour: the gathering, and every site at `share` of its hands (finds as chances). */
export function campPerHour(race: string, sites: readonly Site[], share: number): Record<string, number> {
  const out: Record<string, number> = { ...GATHERING };
  for (const site of sites) {
    const { makes, finds } = sitePerHour(race, site);
    for (const [id, n] of Object.entries({ ...makes })) out[id] = (out[id] ?? 0) + n * share;
    for (const [id, n] of Object.entries(finds)) out[id] = (out[id] ?? 0) + n * share;
  }
  return out;
}

/** Foods stop at FARM_KEEP in the store (whichever site grows them). */
export const isKeptFood = (id: string) => id.startsWith("ration_") || id.startsWith("food_");

export interface ProduceInput {
  race: string;
  seed: number;
  sites: readonly Site[];
  /** Those at home at a moment (each hour counts those at its end), or one number for the whole stretch. */
  workers: number | ((at: number) => number);
  /** Worked out up to here (a whole number of hours are added to it). */
  from: number;
  to: number;
  /** The fractions left over from before (id → 0…1). */
  carry: Record<string, number>;
  /** What the store has now. */
  store: Record<string, number>;
  /** The sites make this much more (the 豐收 talent, a 工匠 at home: 0.1 is +10%; not what is gathered without them). */
  boost?: number;
  /** Most of each food the store keeps (the 大倉庫: buildings.ts; FARM_KEEP without). */
  foodKeep?: number;
}

export interface ProduceResult {
  got: Record<string, number>;
  carry: Record<string, number>;
  /** How far it has been worked out (`from` + whole hours). */
  to: number;
}

const HOUR = 3_600_000;

/**
 * The whole hours between `from` and `to`, one by one: what the sites make adds up (fractions carried to the next time,
 * so it comes out the same worked out all at once or bit by bit); each site's finds are rolled every hour (seeded by the
 * camp, the hour and the site). Foods stop at FARM_KEEP.
 */
export function produce(input: ProduceInput): ProduceResult {
  const hours = Math.max(0, Math.floor((input.to - input.from) / HOUR));
  const workersAt = typeof input.workers === "number" ? () => input.workers as number : input.workers;
  const carry = { ...input.carry };
  const got: Record<string, number> = {};
  const firstHour = Math.floor(input.from / HOUR);
  for (let h = 0; h < hours; h++) {
    const { share } = staffing(input.sites, workersAt(input.from + (h + 1) * HOUR));
    const rates: Record<string, number> = { ...GATHERING };
    for (const site of input.sites) {
      const { makes, finds } = sitePerHour(input.race, site);
      for (const [id, n] of Object.entries(makes)) rates[id] = (rates[id] ?? 0) + n * share * (1 + (input.boost ?? 0));
      if (Object.keys(finds).length === 0) continue;
      const roll = seeded(input.seed, "find", firstHour + h, site.id);
      for (const [id, chance] of Object.entries(finds)) if (roll() < chance * share) got[id] = (got[id] ?? 0) + 1;
    }
    for (const [id, rate] of Object.entries(rates)) {
      const total = (carry[id] ?? 0) + rate;
      const whole = Math.floor(total + 1e-9);
      carry[id] = Math.max(0, total - whole);
      if (whole === 0) continue;
      if (isKeptFood(id) && (input.store[id] ?? 0) + (got[id] ?? 0) >= (input.foodKeep ?? FARM_KEEP)) continue; // (a full store: what grows past it is lost)
      got[id] = (got[id] ?? 0) + whole;
    }
  }
  for (const [id, n] of Object.entries(carry)) if (n < 1e-9) delete carry[id];
  return { got, carry, to: input.from + hours * HOUR };
}

/** The farm's name and what each of its levels added (for showing it). */
export function farmParts(race: string, level: number): string[] {
  return Array.from({ length: level }, (_, i) => farmPartName(race, i + 1));
}
