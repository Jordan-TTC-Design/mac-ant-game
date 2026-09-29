/**
 * What a held cell can be made into (server/WORLD.md §20): one building on each cell, picked by its ground (two to choose
 * from on each), raised level by level. Each building does one thing: gives more every yield, keeps the cell better
 * defended, makes the walk from it shorter, lets more live there, or lets bigger parties set out from it. The camp's own
 * cell has none (the camp has its sites: shared/src/camp/sites.ts).
 */
import type { Terrain } from "./contents.ts";
import { neighbors } from "./grid.ts";
import { hashString } from "./random.ts";
import { RATIONS } from "./supplies.ts";

export type CellBuildingKind =
  | "sawmill"
  | "lodge"
  | "orchard"
  | "campfire"
  | "fishery"
  | "dock"
  | "workshop"
  | "watchtower"
  | "field"
  | "barracks"
  | "inn"
  | "tollgate";

/** A building as `world_cells.building` keeps it. `level` is what it is being raised to while `busyUntil` (ISO) is ahead. */
export interface CellBuilding {
  kind: CellBuildingKind;
  level: number;
  busyUntil?: string | null;
}

type ByLevel = readonly [number, number, number];

export interface CellBuildingRule {
  kind: CellBuildingKind;
  terrain: Terrain;
  name: string;
  /** One line for the phone: what it does. */
  blurb: string;
  /** Material id → how many more every yield (YIELD_HOURS), at levels 1, 2, 3. */
  makes?: Record<string, ByLevel>;
  /** Material id → the chance every yield of finding one. */
  finds?: Record<string, ByLevel>;
  /** The garrison's hit points +share when the cell is fought over. */
  fort?: ByLevel;
  /** Parties setting out from the cell walk this share of the time. */
  travel?: ByLevel;
  /** More may live on the cell. */
  room?: ByLevel;
  /** Parties setting out from the cell may be this many bigger. */
  party?: ByLevel;
  /** A race's own version where it differs (elves eat no meat; the undead do not fish). */
  races?: Record<string, { name?: string; blurb?: string; makes?: Record<string, ByLevel> }>;
}

const lv = (a: number, b: number, c: number): ByLevel => [a, b, c];

export const CELL_BUILDINGS: readonly CellBuildingRule[] = [
  { kind: "sawmill", terrain: "forest", name: "伐木營地", blurb: "每次產出多給木材和木片", makes: { log: lv(3, 6, 10), scrap_wood: lv(2, 4, 6) } },
  {
    kind: "lodge",
    terrain: "forest",
    name: "獵人小屋",
    blurb: "每次產出多給烤肉和兔毛",
    makes: { food_meat: lv(1, 1, 2), rabbit_fur: lv(1, 1, 2) },
    races: { elf: { name: "射手小屋", blurb: "每次產出多給羽毛和兔毛", makes: { feather: lv(1, 2, 3), rabbit_fur: lv(1, 1, 2) } } },
  },
  { kind: "orchard", terrain: "park", name: "採集園", blurb: "每次產出多給莓果乾和蜂蜜", makes: { ration_berry: lv(1, 2, 3), food_honey: lv(0, 1, 1) } },
  { kind: "campfire", terrain: "park", name: "營火廣場", blurb: "這一格可以多住一些", room: lv(5, 10, 15) },
  {
    kind: "fishery",
    terrain: "water",
    name: "漁場",
    blurb: "每次產出多給魚乾和蛙皮",
    makes: { ration_fish: lv(1, 2, 3), frog_skin: lv(1, 1, 2) },
    races: { undead: { name: "醃肉棚", blurb: "每次產出多給肉乾和蛙皮", makes: { ration_jerky: lv(1, 2, 3), frog_skin: lv(1, 1, 2) } } },
  },
  { kind: "dock", terrain: "water", name: "碼頭", blurb: "從這一格出發的隊伍走得比較快", travel: lv(0.85, 0.75, 0.65) },
  { kind: "workshop", terrain: "urban", name: "工坊", blurb: "每次產出多給廢鐵，偶爾有碎晶", makes: { scrap_iron: lv(2, 3, 5) }, finds: { crystal_shard: lv(0.05, 0.08, 0.12) } },
  { kind: "watchtower", terrain: "urban", name: "瞭望塔", blurb: "守這一格的居民血量變多", fort: lv(0.15, 0.25, 0.35) },
  { kind: "field", terrain: "open", name: "田", blurb: "每次產出多給胡蘿蔔和麵包", makes: { food_carrot: lv(1, 2, 3), ration_bread: lv(0, 1, 1) } },
  { kind: "barracks", terrain: "open", name: "營舍", blurb: "從這一格出發的隊伍可以多帶幾隻", party: lv(2, 3, 4) },
  { kind: "inn", terrain: "road", name: "驛站", blurb: "從這一格出發的隊伍走得比較快", travel: lv(0.85, 0.75, 0.65) },
  { kind: "tollgate", terrain: "road", name: "關卡", blurb: "每次產出多給銅幣和肉乾", makes: { stolen_coin: lv(1, 1, 2), ration_jerky: lv(1, 1, 2) } },
];
const RULES = new Map(CELL_BUILDINGS.map((r) => [r.kind, r]));

export function cellBuildingRule(kind: string): CellBuildingRule | undefined {
  return RULES.get(kind as CellBuildingKind);
}

/** The two a cell of this ground may have. */
export function buildingsFor(terrain: Terrain): CellBuildingRule[] {
  return CELL_BUILDINGS.filter((r) => r.terrain === terrain);
}

/** The building's name and what it does for this race. */
export function cellBuildingName(kind: string, race: string): string {
  const rule = RULES.get(kind as CellBuildingKind);
  return rule?.races?.[race]?.name ?? rule?.name ?? kind;
}
export function cellBuildingBlurb(kind: string, race: string): string {
  const rule = RULES.get(kind as CellBuildingKind);
  return rule?.races?.[race]?.blurb ?? rule?.blurb ?? "";
}

export const CELL_BUILDING_MAX = 3;
/** Hours to build (level 1) and to raise it to level 2 and 3. */
export const CELL_BUILDING_HOURS = [1, 4, 12] as const;
/** What building it (level 1) and raising it cost; the same for every kind. */
export const CELL_BUILDING_COSTS: readonly Record<string, number>[] = [
  { scrap_wood: 20, log: 20 },
  { scrap_wood: 50, scrap_iron: 20, log: 60, stone: 20 },
  { scrap_wood: 100, scrap_iron: 50, scrap_rag: 30, log: 150, stone: 80, crystal_shard: 1 },
];

/** The level that works now (while it is being raised, the one before; 0 while it is first being built). */
export function workingLevel(b: CellBuilding | null | undefined, now: number): number {
  if (!b) return 0;
  const busy = b.busyUntil ? Date.parse(b.busyUntil) > now : false;
  return busy ? b.level - 1 : b.level;
}

// --- landmarks ----------------------------------------------------------------------------------------------------

/**
 * Real places on the map (OpenStreetMap, server/src/world/osm.ts) that make a cell worth more to whoever holds it: one per
 * cell at most, the most telling kind first (the order below).
 */
export type LandmarkKind = "station" | "temple" | "university" | "museum" | "stadium" | "market";
export interface Landmark {
  kind: LandmarkKind;
  name: string;
}
export interface LandmarkRule {
  kind: LandmarkKind;
  name: string;
  icon: string;
  blurb: string;
}
export const LANDMARKS: readonly LandmarkRule[] = [
  { kind: "station", name: "車站", icon: "🚉", blurb: "從這裡出發走路時間 −30%" },
  { kind: "temple", name: "廟宇", icon: "⛩️", blurb: "守這一格血量 +20%，旁邊自己的格子 +10%" },
  { kind: "university", name: "大學", icon: "🎓", blurb: "佔著每天多 20 經驗值" },
  { kind: "museum", name: "古蹟・博物館", icon: "🏛️", blurb: "每次產出有機會挖到碎晶、琥珀" },
  { kind: "stadium", name: "體育場", icon: "🏟️", blurb: "從這裡出發的隊伍可以多 3 隻" },
  { kind: "market", name: "市場", icon: "🧺", blurb: "每次產出多給乾糧麵包和起司" },
];
const LANDMARK_RULES = new Map(LANDMARKS.map((l) => [l.kind, l]));
export function landmarkRule(kind: string): LandmarkRule | undefined {
  return LANDMARK_RULES.get(kind as LandmarkKind);
}
/** A temple's help to the held cells next to it. */
export const TEMPLE_AURA = 0.1;
/** Experience a day for holding a university (on top of every cell's XP.cellDay). */
export const UNIVERSITY_XP = 20;

/**
 * The stand-in for a server without the real map (tests, WORLD_TERRAIN=seed): about one cell in twenty is a landmark,
 * the same every time.
 */
export function standInLandmark(cell: string): Landmark | null {
  const h = hashString(`${cell}|landmark`);
  if (h % 100 >= 5) return null;
  const rule = LANDMARKS[Math.floor(h / 100) % LANDMARKS.length]!;
  return { kind: rule.kind, name: rule.name };
}

// --- cells held side by side ---------------------------------------------------------------------------------------

/** Every held cell next to it adds this share to what the ground yields (up to NEIGHBOUR_YIELD_MAX of them). */
export const NEIGHBOUR_YIELD = 0.1;
export const NEIGHBOUR_YIELD_MAX = 3;
/** When a cell is fought over, each held cell next to it sends up to this many to help (those it can spare). */
export const REINFORCE_PER_CELL = 5;

/** The held cells joined to `cell` through held cells next to each other (itself included; empty if it is not held). */
export function connectedCells(cell: string, held: ReadonlySet<string>): string[] {
  if (!held.has(cell)) return [];
  const seen = new Set([cell]);
  const queue = [cell];
  while (queue.length) {
    for (const n of neighbors(queue.shift()!)) {
      if (held.has(n) && !seen.has(n)) {
        seen.add(n);
        queue.push(n);
      }
    }
  }
  return [...seen];
}

/** How many of the cells next to `cell` are held. */
export function heldNeighbours(cell: string, held: ReadonlySet<string>): number {
  return neighbors(cell).filter((n) => held.has(n)).length;
}

// --- keeping many cells ------------------------------------------------------------------------------------------

/**
 * Holding many cells costs food (server/WORLD.md §20): the camp's own cell and the first UPKEEP_FREE_CELLS others (the
 * longest held) are free; every other one eats UPKEEP_RATIONS of the camp's rations at every yield. A cell that goes
 * hungry is not lost: its yield that time is HUNGRY_YIELD of what it would be.
 */
export const UPKEEP_FREE_CELLS = 3;
export const UPKEEP_RATIONS = 1;
export const HUNGRY_YIELD = 0.5;

/** Eats `need` rations from the store (the kind there is most of first): what was eaten, and how many. */
export function eatRations(store: Record<string, number>, need: number): { eaten: Record<string, number>; paid: number } {
  const eaten: Record<string, number> = {};
  let paid = 0;
  const left = { ...store };
  while (paid < need) {
    const most = Object.keys(RATIONS).sort((a, b) => (left[b] ?? 0) - (left[a] ?? 0))[0]!;
    if ((left[most] ?? 0) <= 0) break;
    left[most]! -= 1;
    eaten[most] = (eaten[most] ?? 0) + 1;
    paid++;
  }
  return { eaten, paid };
}

/** A yield scaled for how well the cell was fed (share 0…1 of the rations it needed). */
export function fedYield(got: Record<string, number>, fed: number): Record<string, number> {
  if (fed >= 1) return got;
  const k = HUNGRY_YIELD + (1 - HUNGRY_YIELD) * fed;
  return Object.fromEntries(Object.entries(got).map(([id, n]) => [id, Math.floor(n * k)]).filter(([, n]) => (n as number) > 0));
}

// --- what a cell gets ---------------------------------------------------------------------------------------------

/** What a held cell gets from what is on it. */
export interface CellBonus {
  /** More every yield (whole numbers). */
  makes: Record<string, number>;
  /** Chances every yield. */
  finds: Record<string, number>;
  fort: number;
  /** Walking time from it (1: as usual). */
  travel: number;
  room: number;
  party: number;
  /** Experience a day for holding it, beyond every cell's own. */
  xp: number;
  /** The ground yields this share more (held cells next to it). */
  yieldBoost: number;
}

/** Besides its building: the landmark on the cell, and whether a temple of the same holder stands next to it. */
export interface CellSurroundings {
  landmark?: Landmark | null;
  templeNear?: boolean;
  /** How many held cells are next to it. */
  neighbours?: number;
}

export function cellBonus(race: string, building: CellBuilding | null | undefined, now: number, around: CellSurroundings = {}): CellBonus {
  const out: CellBonus = { makes: {}, finds: {}, fort: 0, travel: 1, room: 0, party: 0, xp: 0, yieldBoost: NEIGHBOUR_YIELD * Math.min(NEIGHBOUR_YIELD_MAX, around.neighbours ?? 0) };
  switch (around.landmark?.kind) {
    case "station": out.travel *= 0.7; break;
    case "temple": out.fort += 0.2; break;
    case "university": out.xp += UNIVERSITY_XP; break;
    case "museum": out.finds = { crystal_shard: 0.15, amber: 0.15 }; break;
    case "stadium": out.party += 3; break;
    case "market": out.makes = { ration_bread: 1, food_cheese: 1 }; break;
  }
  if (around.templeNear && around.landmark?.kind !== "temple") out.fort += TEMPLE_AURA;
  const level = workingLevel(building, now);
  const rule = building ? RULES.get(building.kind) : undefined;
  if (!rule || level < 1) return out;
  const k = (Math.min(CELL_BUILDING_MAX, level) - 1) as 0 | 1 | 2;
  for (const [id, v] of Object.entries(rule.races?.[race]?.makes ?? rule.makes ?? {})) if (v[k]) out.makes[id] = (out.makes[id] ?? 0) + v[k];
  for (const [id, v] of Object.entries(rule.finds ?? {})) out.finds[id] = Math.min(1, (out.finds[id] ?? 0) + v[k]);
  if (rule.fort) out.fort += rule.fort[k];
  if (rule.travel) out.travel *= rule.travel[k];
  if (rule.room) out.room += rule.room[k];
  if (rule.party) out.party += rule.party[k];
  return out;
}

/**
 * What the building adds to `times` yields: its makes in full every time, its finds rolled each time (a garrison below the
 * minimum works nothing, as with the ground's own yield).
 */
export function buildingYield(bonus: CellBonus, times: number, random: () => number): Record<string, number> {
  const out: Record<string, number> = {};
  for (let t = 0; t < times; t++) {
    for (const [id, n] of Object.entries(bonus.makes)) out[id] = (out[id] ?? 0) + n;
    for (const [id, p] of Object.entries(bonus.finds)) if (random() < p) out[id] = (out[id] ?? 0) + 1;
  }
  return out;
}
