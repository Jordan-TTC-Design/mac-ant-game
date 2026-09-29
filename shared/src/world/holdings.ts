/**
 * What a held cell can be made into (server/WORLD.md §20): one building on each cell, picked by its ground (two to choose
 * from on each), raised level by level. Each building does one thing: gives more every yield, keeps the cell better
 * defended, makes the walk from it shorter, lets more live there, or lets bigger parties set out from it. The camp's own
 * cell has none (the camp has its sites: shared/src/camp/sites.ts).
 */
import type { Terrain } from "./contents.ts";

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
}

export function cellBonus(race: string, building: CellBuilding | null | undefined, now: number): CellBonus {
  const out: CellBonus = { makes: {}, finds: {}, fort: 0, travel: 1, room: 0, party: 0 };
  const level = workingLevel(building, now);
  const rule = building ? RULES.get(building.kind) : undefined;
  if (!rule || level < 1) return out;
  const k = (Math.min(CELL_BUILDING_MAX, level) - 1) as 0 | 1 | 2;
  for (const [id, v] of Object.entries(rule.races?.[race]?.makes ?? rule.makes ?? {})) if (v[k]) out.makes[id] = v[k];
  for (const [id, v] of Object.entries(rule.finds ?? {})) out.finds[id] = v[k];
  if (rule.fort) out.fort = rule.fort[k];
  if (rule.travel) out.travel = rule.travel[k];
  if (rule.room) out.room = rule.room[k];
  if (rule.party) out.party = rule.party[k];
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
