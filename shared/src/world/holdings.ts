/**
 * What a held cell can be made into (server/WORLD.md §20): one building on each cell, picked by its ground (two to choose
 * from on each), raised level by level. Each building does one thing: gives more every yield, keeps the cell better
 * defended, makes the walk from it shorter, lets more live there, or lets bigger parties set out from it. The camp's own
 * cell has none (the camp has its sites: shared/src/camp/sites.ts).
 */
import { raceRules } from "../camp/races.ts";
import { donationPoints } from "../guild.ts";
import { MATERIALS } from "./drops.ts";
import type { Terrain } from "./contents.ts";
import { neighbors } from "./grid.ts";
import { hashString, type Random } from "./random.ts";
import { detailBuilding, detailBuildingsFor, hubRule, type DetailBuildingRule, type HubKind, type TerrainDetail } from "./details.ts";
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
  | "tollgate"
  | "sacred";

/** A building as `world_cells.building` keeps it. `level` is what it is being raised to while `busyUntil` (ISO) is ahead. */
export interface CellBuilding {
  /** A CellBuildingKind, or a 細分地形 building's (details.ts DETAIL_BUILDINGS). */
  kind: CellBuildingKind | (string & {});
  level: number;
  busyUntil?: string | null;
}

type ByLevel = readonly [number, number, number, number];

export interface CellBuildingRule {
  kind: CellBuildingKind;
  terrain: Terrain;
  /** Grounds it may stand on besides `terrain`. */
  alsoOn?: readonly Terrain[];
  /** Only for this race, with this talent (talents.ts TALENT_ABILITIES): not among the two every ground offers. */
  only?: { race: string; ability: string };
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

/** By level 1…3, and level 4 (race level CELL_BUILDING_TOP_RACE_LEVEL) going on as from 2 to 3. */
const lv = (a: number, b: number, c: number): ByLevel => [a, b, c, Math.round((c + (c - b)) * 1000) / 1000];

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
  {
    kind: "sacred",
    terrain: "forest",
    alsoOn: ["park"],
    only: { race: "elf", ability: "sacredTree" },
    name: "聖樹",
    blurb: "同一區的領地產出 +15%、守軍血量 +10%；這一格守得更牢、住得更多（一區一棵）",
    fort: lv(0.2, 0.3, 0.4),
    room: lv(5, 10, 15),
  },
];
const RULES = new Map(CELL_BUILDINGS.map((r) => [r.kind, r]));

export function cellBuildingRule(kind: string): CellBuildingRule | undefined {
  return RULES.get(kind as CellBuildingKind);
}

/** The two a cell of this ground may have. */
export function buildingsFor(terrain: Terrain): CellBuildingRule[] {
  return CELL_BUILDINGS.filter((r) => r.terrain === terrain && !r.only);
}

/** What a held cell may have built on it: its terrain's two, and its 細分地形's two and the three of anywhere (details.ts). */
export function buildingKindsFor(terrain: Terrain, detail: TerrainDetail | null | undefined): string[] {
  return [...buildingsFor(terrain).map((r) => r.kind), ...detailBuildingsFor(detail).map((r) => r.kind)];
}

/** The buildings only some may put on this ground (聖樹: elves with the talent, on park or forest). */
export function specialBuildingsFor(terrain: Terrain, race: string, abilities: Partial<Record<string, number>>): CellBuildingRule[] {
  return CELL_BUILDINGS.filter((r) => r.only && r.only.race === race && (abilities[r.only.ability] ?? 0) > 0 && (r.terrain === terrain || r.alsoOn?.includes(terrain)));
}

/** 聖樹: every held cell of its region yields this share more, and its defenders have this share more hit points. */
export const SACRED_YIELD = 0.15;
export const SACRED_FORT = 0.1;

/** The building's name and what it does for this race. */
export function cellBuildingName(kind: string, race: string): string {
  const rule = RULES.get(kind as CellBuildingKind);
  return rule?.races?.[race]?.name ?? rule?.name ?? detailBuilding(kind)?.name ?? kind;
}
export function cellBuildingBlurb(kind: string, race: string): string {
  const rule = RULES.get(kind as CellBuildingKind);
  return rule?.races?.[race]?.blurb ?? rule?.blurb ?? detailBuilding(kind)?.blurb ?? "";
}

export const CELL_BUILDING_MAX = 3;
/** Level 4 (2026-10-17): open once the race level reaches CELL_BUILDING_TOP_RACE_LEVEL. */
export const CELL_BUILDING_TOP = 4;
export const CELL_BUILDING_TOP_RACE_LEVEL = 10;
/** The highest level a building can be raised to at a race level. */
export const buildingTopFor = (raceLevel: number) => (raceLevel >= CELL_BUILDING_TOP_RACE_LEVEL ? CELL_BUILDING_TOP : CELL_BUILDING_MAX);
/** Hours to build (level 1) and to raise it to level 2 and 3. */
export const CELL_BUILDING_HOURS = [1, 4, 12, 24] as const;
/** What building it (level 1) and raising it cost; the same for every kind. */
export const CELL_BUILDING_COSTS: readonly Record<string, number>[] = [
  { scrap_wood: 20, log: 20 },
  { scrap_wood: 50, scrap_iron: 20, log: 60, stone: 20 },
  { scrap_wood: 100, scrap_iron: 50, scrap_rag: 30, log: 150, stone: 80, crystal_shard: 1 },
  { scrap_wood: 200, scrap_iron: 100, scrap_rag: 60, log: 300, stone: 160, crystal_shard: 5, amber: 2 },
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
/** Auto staffing (2026-10-17) keeps at least this many at home (the camp's sites need hands). */
export const STAFF_HOME_KEEP = 30;

/** Within one's own connected region (2026-10-17), residents moving between its cells walk this share of the time. */
export const REGION_TRAVEL = 0.25;

/** Whether `a` and `b` are both held and joined by held cells (one region: connectedCells). */
export function sameRegion(a: string, b: string, held: ReadonlySet<string>): boolean {
  return held.has(a) && held.has(b) && connectedCells(a, held).includes(b);
}

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

// --- towns and the cells joined to them (2026-09-30) ---

/** Every town in a region adds this share of a cell's room (cellCapacity) to every cell of the region, the town cells too. */
export const TOWN_ROOM_SHARE = 0.5;
/** At most this many towns of a region count for it (more may stand; they only help their own cell). */
export const TOWN_ROOM_MAX = 4;
/** A region may have one town for every this many cells in it. */
export const TOWN_CELLS_EACH = 4;

/** The towns in `cell`'s region (itself included) among `towns`. */
export function regionTowns(cell: string, held: ReadonlySet<string>, towns: ReadonlySet<string>): number {
  return connectedCells(cell, held).filter((c) => towns.has(c)).length;
}

/** The other towns of a region that count for `cell` (a town cell counts itself among the TOWN_ROOM_MAX, but gets its own room otherwise). */
export function townsJoined(inRegion: number, isTown: boolean): number {
  return Math.max(0, Math.min(TOWN_ROOM_MAX, inRegion) - (isTown ? 1 : 0));
}

/** The room `joined` towns add to one cell. */
export function townRoom(cellCap: number, joined: number): number {
  return Math.round(cellCap * TOWN_ROOM_SHARE * Math.min(TOWN_ROOM_MAX, Math.max(0, joined)));
}

/** Whether a region of `region` cells that already has `towns` towns may have one more. */
export function regionHasRoomForTown(region: number, towns: number): boolean {
  return region >= TOWN_CELLS_EACH * (towns + 1);
}

/** How many of the cells next to `cell` are held. */
export function heldNeighbours(cell: string, held: ReadonlySet<string>): number {
  return neighbors(cell).filter((n) => held.has(n)).length;
}

// --- keeping many cells ------------------------------------------------------------------------------------------

/**
 * Holding many cells costs food (server/WORLD.md §20): the camp's own cell and the first UPKEEP_FREE_CELLS others (the
 * longest held) are free; every other one eats one of the camp's rations every UPKEEP_EVERY yields (every 6 hours; at
 * every yield was too much: only a cell by water fed itself, balance:territory). A cell that goes
 * hungry is not lost: its yield that time is HUNGRY_YIELD of what it would be.
 */
export const UPKEEP_FREE_CELLS = 3;
/** The race level adds cells without upkeep (2026-10-17): one more every this many levels. */
export const UPKEEP_FREE_PER_LEVELS = 4;
export const freeCellsFor = (level: number) => UPKEEP_FREE_CELLS + Math.floor(Math.max(0, level) / UPKEEP_FREE_PER_LEVELS);
export const UPKEEP_RATIONS = 1;
export const UPKEEP_EVERY = 2;

/** How many rations a paying cell owes for `times` yields after the `done` it has had since it was taken. */
export function upkeepDue(done: number, times: number): number {
  return (Math.floor((done + times) / UPKEEP_EVERY) - Math.floor(done / UPKEEP_EVERY)) * UPKEEP_RATIONS;
}
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

// --- friends guarding ---------------------------------------------------------------------------------------------

/**
 * Friends may send residents to guard each other's cells (server/WORLD.md §20): they live there as guests (place
 * `guard:<cell>`), fight beside the holder's when a lair comes back or another camp attacks, and walk home when either
 * side says so or the cell is lost. At most GUESTS_MAX guests on a cell, from all friends together.
 */
export const GUESTS_MAX = 20;

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
  /** The pairings (REGION_COMBOS) its building is part of in its region, by name. */
  combos?: string[];
  /** A 細分地形 building's own ways (details.ts DetailBuildingRule): wild monsters raid it this share less often; its garrison heals this share faster; fights set out from it give this share more experience; the 聰明 / terrain breed is born there this many times as often; gear of parties from it wears this share less. */
  wild?: number;
  heal?: number;
  fightXp?: number;
  sage?: number;
  breed?: number;
  wear?: number;
}

/** Besides its building: the landmark on the cell, and whether a temple of the same holder stands next to it. */
export interface CellSurroundings {
  landmark?: Landmark | null;
  templeNear?: boolean;
  /** How many held cells are next to it. */
  neighbours?: number;
  /** The towns of its region that add to its room (townsJoined). */
  townsJoined?: number;
  /** It is a town itself (TOWN_TRAVEL, TOWN_FORT). */
  town?: boolean;
  /** The kinds of building working in its region (for REGION_COMBOS). */
  regionKinds?: readonly string[];
  /** It is a hub other than a town itself (details.ts HUBS: fortress, workstead, sanctuary). */
  hub?: HubKind | null;
  /** The hubs other than towns of its region, this one among them (their region-wide ways). */
  regionHubs?: readonly HubKind[];
}

/**
 * Two buildings that work well together in one region (2026-10-17): with both standing (built, anywhere in the joined
 * cells), each does a little more — what it makes +1 each, what it finds +3%, its fort +10%, its room +5, its party +1, its
 * walking time −10%.
 */
export const REGION_COMBOS: readonly { kinds: readonly [CellBuildingKind, CellBuildingKind]; name: string; blurb: string }[] = [
  { kinds: ["sawmill", "workshop"], name: "木工坊", blurb: "伐木營地 + 工坊" },
  { kinds: ["orchard", "lodge"], name: "林間補給", blurb: "採集園 + 獵人小屋" },
  { kinds: ["field", "barracks"], name: "屯田", blurb: "田 + 營舍" },
  { kinds: ["fishery", "tollgate"], name: "河岸市集", blurb: "漁場 + 關卡" },
  { kinds: ["watchtower", "campfire"], name: "守備營", blurb: "瞭望塔 + 營火廣場" },
  { kinds: ["dock", "inn"], name: "水陸驛道", blurb: "碼頭 + 驛站" },
];

/** The pairings `kind` is part of, given the kinds working in its region. */
export function combosFor(kind: string, regionKinds: readonly string[]): typeof REGION_COMBOS {
  return REGION_COMBOS.filter((c) => (c.kinds as readonly string[]).includes(kind) && c.kinds.every((k) => regionKinds.includes(k)));
}

/** A town is a base (2026-10-17): parties setting out from it walk this much of the time, and its walls add this to its defenders' hit points. */
export const TOWN_TRAVEL = 0.75;
export const TOWN_FORT = 0.2;

/** A town's market (2026-10-17): materials swapped for others, at a loss, a few times a day for each town. */
export const MARKET_TRADES_PER_DAY = 3;
/** The share of what is given that comes back in what is wanted (worth for worth). */
export const MARKET_RATE = 0.6;

/** What one of a material is worth at a market: the guild's worth of it (0: not traded there, e.g. the 道具). */
export function marketWorth(id: string): number {
  return id.startsWith("item_") ? 0 : donationPoints(id, (m) => m in MATERIALS);
}

/** How many of `get` come for `count` of `give` at a town's market (0: no trade). */
export function marketQuote(give: string, count: number, get: string, rate = MARKET_RATE): number {
  const a = marketWorth(give), b = marketWorth(get);
  if (!a || !b || give === get || count < 1) return 0;
  return Math.floor((count * a * rate) / b);
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
  out.room += townRoom(raceRules(race).cellCap, around.townsJoined ?? 0);
  if (around.town) {
    out.travel *= TOWN_TRAVEL;
    out.fort += TOWN_FORT;
  }
  // a hub of its own (a fortress: more room, sturdier, bigger parties; a workstead: a big yield of its own), and the hubs
  // of its region (a fortress keeps half the wild raids off the region; a workstead: the region's cells yield more)
  const own = around.hub ? hubRule(around.hub) : undefined;
  if (own?.room) out.room += Math.round(raceRules(race).cellCap * (own.room - 1));
  if (own?.fort) out.fort += own.fort;
  if (own?.party) out.party += own.party;
  for (const [id, n] of Object.entries(own?.yield ?? {})) out.makes[id] = (out.makes[id] ?? 0) + n;
  for (const kind of new Set(around.regionHubs ?? [])) {
    const h = hubRule(kind);
    if (h?.regionYield) out.yieldBoost += h.regionYield;
    if (h?.wild) out.wild = 1 - (1 - (out.wild ?? 0)) * (1 - h.wild);
  }
  // a 聖樹 standing in its region
  if (around.regionKinds?.includes("sacred")) {
    out.yieldBoost += SACRED_YIELD;
    out.fort += SACRED_FORT;
  }
  const level = workingLevel(building, now);
  const rule: (CellBuildingRule & Partial<DetailBuildingRule>) | DetailBuildingRule | undefined = building ? (RULES.get(building.kind as CellBuildingKind) ?? detailBuilding(building.kind)) : undefined;
  if (!rule || level < 1) return out;
  const k = (Math.min(CELL_BUILDING_TOP, level) - 1) as 0 | 1 | 2 | 3;
  const races = "races" in rule ? rule.races : undefined;
  for (const [id, v] of Object.entries(races?.[race]?.makes ?? rule.makes ?? {})) if (v[k]) out.makes[id] = (out.makes[id] ?? 0) + v[k];
  for (const [id, v] of Object.entries(rule.finds ?? {})) out.finds[id] = Math.min(1, (out.finds[id] ?? 0) + v[k]);
  if (rule.fort) out.fort += rule.fort[k];
  if (rule.travel) out.travel *= rule.travel[k];
  if (rule.room) out.room += rule.room[k];
  if (rule.party) out.party += rule.party[k];
  if ("wild" in rule && rule.wild) out.wild = 1 - (1 - (out.wild ?? 0)) * (1 - rule.wild[k]);
  if ("heal" in rule && rule.heal) out.heal = rule.heal[k];
  if ("xp" in rule && rule.xp) out.fightXp = rule.xp[k];
  if ("sage" in rule && rule.sage) out.sage = rule.sage[k];
  if ("breed" in rule && rule.breed) out.breed = rule.breed[k];
  if ("wear" in rule && rule.wear) out.wear = rule.wear[k];
  // paired with its partner in the region (REGION_COMBOS): a little more of what it does
  const combos = combosFor(rule.kind, around.regionKinds ?? []);
  for (const _ of combos) {
    for (const id of Object.keys(races?.[race]?.makes ?? rule.makes ?? {})) out.makes[id] = (out.makes[id] ?? 0) + 1;
    for (const id of Object.keys(rule.finds ?? {})) out.finds[id] = Math.min(1, (out.finds[id] ?? 0) + 0.03);
    if (rule.fort) out.fort += 0.1;
    if (rule.room) out.room += 5;
    if (rule.party) out.party += 1;
    if (rule.travel) out.travel *= 0.9;
  }
  if (combos.length) out.combos = combos.map((c) => c.name);
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

// --- monsters raiding held cells (2026-10-17) -----------------------------------------------------------------------------

/**
 * Wild monsters raid held cells too (not only the camp at home): at each yield (every YIELD_HOURS) a cell may be raided, more
 * likely the higher the race level and the more cells the camp holds, and a raid kills a few of its garrison (at most `share`,
 * less with the cell's fort). Worked out lazily as a cell yields, only for the last `lookback` yields of a cell left alone.
 * The user: 「隨著等級提升或是佔領領地變多，魔獸、敵人來襲數量要變多，殺死一些民眾才能保持平衡，而且也不是都只攻擊主營」.
 */
export const CELL_RAIDS = {
  base: 0.04,
  perLevel: 0.006,
  perCell: 0.01,
  /** Chance at a yield, at most. */
  max: 0.4,
  /** Share of the garrison a raid kills, at most (fort takes off its share of that, up to fortMax). */
  share: 0.05,
  fortMax: 0.6,
  /** Yields looked back over (16 × 3 hours: two days). */
  lookback: 16,
} as const;

/** The chance of a raid on one held cell at a yield. */
export function cellRaidChance(raceLevel: number, cellsHeld: number): number {
  return Math.min(CELL_RAIDS.max, CELL_RAIDS.base + CELL_RAIDS.perLevel * Math.max(0, raceLevel - 1) + CELL_RAIDS.perCell * Math.max(0, cellsHeld - 1));
}

/**
 * How many of a cell's `garrison` monster raids kill over `yields` yields, and how many raids came. A raid's losses are rounded
 * by chance (a garrison of 10 loses 0 or 1); the garrison never falls below one.
 */
export function cellRaidLosses(raceLevel: number, cellsHeld: number, garrison: number, fort: number, yields: number, random: Random, wild = 0): { raids: number; fallen: number } {
  // (`wild`: a 蘆葦迷陣, 香火廟 or 哨站 on it keeps this share of them away)
  const chance = cellRaidChance(raceLevel, cellsHeld) * (1 - Math.min(1, Math.max(0, wild)));
  const share = CELL_RAIDS.share * (1 - Math.min(CELL_RAIDS.fortMax, Math.max(0, fort)));
  let left = garrison;
  let raids = 0;
  for (let k = 0; k < Math.min(yields, CELL_RAIDS.lookback); k++) {
    if (random() >= chance) continue;
    raids++;
    const want = left * share;
    const lost = Math.min(left - 1, Math.floor(want) + (random() < want - Math.floor(want) ? 1 : 0));
    left -= Math.max(0, lost);
  }
  return { raids, fallen: garrison - left };
}
