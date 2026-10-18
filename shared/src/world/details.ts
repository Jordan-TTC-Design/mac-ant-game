/**
 * 細分地形 (server/WORLD.md §29, 2026-10-17): on top of a cell's terrain (the six kinds lairs follow, which stay as they are),
 * what more the map says it is — a mountain, a river, farmland, a cemetery… From the same OpenMapTiles tiles
 * (server/src/world/osm.ts), kept per cell in `world_details` (none: nothing more to it). What each one does (yields, the
 * races at home there, its breeds, its buildings) is added step by step (§29.5).
 */
import { hashString } from "./random.ts";

export type TerrainDetail =
  | "mountain"
  | "river"
  | "farmland"
  | "cemetery"
  | "wetland"
  | "campus"
  | "industrial"
  | "sand"
  | "coast"
  | "hotspring"
  | "temple"
  | "hospital"
  | "military"
  | "railway";

export const TERRAIN_DETAILS: readonly TerrainDetail[] = [
  "mountain", "river", "farmland", "cemetery", "wetland", "campus", "industrial", "sand", "coast", "hotspring", "temple", "hospital", "military", "railway",
];

export const DETAIL_NAMES: Record<TerrainDetail, { name: string; icon: string }> = {
  mountain: { name: "山地", icon: "⛰️" },
  river: { name: "河川", icon: "🏞️" },
  farmland: { name: "農田", icon: "🌾" },
  cemetery: { name: "墓地", icon: "🪦" },
  wetland: { name: "濕地", icon: "🪷" },
  campus: { name: "校園", icon: "🏫" },
  industrial: { name: "工業區", icon: "🏭" },
  sand: { name: "沙灘", icon: "🏖️" },
  coast: { name: "海岸", icon: "🌊" },
  hotspring: { name: "溫泉", icon: "♨️" },
  temple: { name: "廟宇區", icon: "⛩️" },
  hospital: { name: "醫院", icon: "🏥" },
  military: { name: "軍事區", icon: "🪖" },
  railway: { name: "鐵道", icon: "🚆" },
};

export function isTerrainDetail(s: string | null | undefined): s is TerrainDetail {
  return !!s && (TERRAIN_DETAILS as readonly string[]).includes(s);
}

/** The share of cells the seed's stand-in gives a detail (no real map: tests, or a server without the internet). */
export const STAND_IN_DETAIL_SHARE = 0.25;

/** A cell's detail when the real map cannot be had: a quarter of the cells, every kind about as often. */
export function standInDetail(cell: string): TerrainDetail | null {
  const h = hashString(`${cell}|detail`) / 4294967296;
  if (h >= STAND_IN_DETAIL_SHARE) return null;
  return TERRAIN_DETAILS[Math.floor((h / STAND_IN_DETAIL_SHARE) * TERRAIN_DETAILS.length)]!;
}

// ── What each detail does (WORLD.md §29.2) ─────────────────────────────────────────────────────────────────────────

type Yield = { id: string; min: number; max: number; chance: number };

/** What a held cell's detail adds to each of its yields (on top of its terrain's: territory.ts cellYield). */
export const DETAIL_YIELD: Record<TerrainDetail, Yield[]> = {
  mountain: [{ id: "stone", min: 2, max: 4, chance: 1 }, { id: "scrap_iron", min: 1, max: 2, chance: 0.5 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.06 }],
  river: [{ id: "ration_fish", min: 1, max: 2, chance: 0.8 }, { id: "snake_scale", min: 1, max: 1, chance: 0.3 }, { id: "river_pearl", min: 1, max: 1, chance: 0.05 }],
  farmland: [{ id: "food_carrot", min: 1, max: 2, chance: 0.8 }, { id: "ration_bread", min: 1, max: 1, chance: 0.6 }],
  cemetery: [{ id: "bone_shard", min: 1, max: 2, chance: 0.8 }, { id: "ectoplasm", min: 1, max: 1, chance: 0.3 }, { id: "night_dust", min: 1, max: 1, chance: 0.15 }],
  wetland: [{ id: "frog_skin", min: 1, max: 2, chance: 0.8 }, { id: "slime_goo", min: 1, max: 2, chance: 0.5 }, { id: "snake_skin", min: 1, max: 1, chance: 0.3 }],
  campus: [{ id: "scrap_wood", min: 1, max: 2, chance: 0.8 }, { id: "shiny_bead", min: 1, max: 1, chance: 0.15 }, { id: "shaman_charm", min: 1, max: 1, chance: 0.08 }],
  industrial: [{ id: "scrap_iron", min: 2, max: 3, chance: 1 }, { id: "leather_strap", min: 1, max: 1, chance: 0.4 }, { id: "scrap_wood", min: 1, max: 2, chance: 0.5 }],
  sand: [{ id: "crab_shell", min: 1, max: 2, chance: 0.6 }, { id: "snail_shell", min: 1, max: 2, chance: 0.5 }, { id: "river_pearl", min: 1, max: 1, chance: 0.06 }],
  coast: [{ id: "ration_fish", min: 1, max: 2, chance: 0.8 }, { id: "crab_claw", min: 1, max: 1, chance: 0.4 }, { id: "naga_pearl", min: 1, max: 1, chance: 0.02 }],
  hotspring: [{ id: "crystal_shard", min: 1, max: 1, chance: 0.1 }, { id: "amber", min: 1, max: 1, chance: 0.06 }],
  temple: [{ id: "shaman_charm", min: 1, max: 1, chance: 0.2 }, { id: "beeswax", min: 1, max: 2, chance: 0.5 }],
  hospital: [{ id: "item_bandage", min: 1, max: 1, chance: 0.5 }],
  military: [{ id: "guard_plate", min: 1, max: 1, chance: 0.3 }, { id: "steel_bolt", min: 1, max: 2, chance: 0.4 }],
  railway: [{ id: "scrap_iron", min: 1, max: 2, chance: 1 }],
};

/** The races at home on a detail: their garrison there hits harder (DETAIL_HOME_ATTACK). */
export const DETAIL_RACES: Record<TerrainDetail, readonly string[]> = {
  // (the beasts, RACES_BEAST.md §6: dry red-rock valleys — the mountains and the sands)
  mountain: ["goblin", "beast"], river: ["elf"], farmland: ["elf"], cemetery: ["undead"], wetland: ["elf"], campus: ["goblin", "elf", "undead", "beast"],
  industrial: ["goblin"], sand: ["elf", "beast"], coast: ["elf"], hotspring: ["goblin", "elf", "undead", "beast"], temple: ["goblin", "elf"],
  hospital: ["goblin", "elf", "undead", "beast"], military: ["goblin", "elf", "undead", "beast"], railway: ["goblin", "elf", "undead", "beast"],
};
export const DETAIL_HOME_ATTACK = 0.1;

export function detailHome(detail: TerrainDetail | null | undefined, race: string): boolean {
  return !!detail && DETAIL_RACES[detail].includes(race);
}

/**
 * A detail's own ways (0 / 1: none). Fights at a cell: `defendHp`, `defendAttack` its defenders' (+ share), `attackAttack`
 * its attackers' (− share), `vsUndead` its defenders' against undead attackers, `undeadDefend` undead defenders' there,
 * `undeadNight` undead's at night, `loot` what beating it gives (+ share). Holding it: `heal` its garrison heals faster
 * (× 1 + this), `xp` fights set out from it give more, `travel` parties from it walk faster (× this, under 1), `market` its
 * town's market gives better, `food` its yields of food × this.
 */
export interface DetailEffects {
  defendHp: number;
  defendAttack: number;
  attackAttack: number;
  vsUndead: number;
  undeadDefend: number;
  undeadNight: number;
  loot: number;
  heal: number;
  xp: number;
  travel: number;
  market: number;
  food: number;
}
const NONE: DetailEffects = { defendHp: 0, defendAttack: 0, attackAttack: 0, vsUndead: 0, undeadDefend: 0, undeadNight: 0, loot: 0, heal: 0, xp: 0, travel: 1, market: 0, food: 1 };
const EFFECTS: Partial<Record<TerrainDetail, Partial<DetailEffects>>> = {
  mountain: { defendHp: 0.1 },
  river: { attackAttack: 0.1 },
  farmland: { food: 2 },
  cemetery: { undeadNight: 0.15 },
  wetland: { attackAttack: 0.1 },
  campus: { xp: 0.1 },
  industrial: { defendAttack: 0.05 },
  sand: { travel: 0.85 },
  coast: { market: 0.15 },
  hotspring: { heal: 0.5 },
  temple: { vsUndead: 0.15, undeadDefend: -0.1 },
  hospital: { heal: 1 },
  military: { defendAttack: 0.15, loot: 0.25 },
  railway: { travel: 0.8 },
};

export function detailEffects(detail: TerrainDetail | null | undefined): DetailEffects {
  return detail ? { ...NONE, ...EFFECTS[detail] } : NONE;
}

/** The mid lairs (world/contents.ts) a detail's empty cells lean to: picked this many times as often there. */
export const DETAIL_LAIRS: Partial<Record<TerrainDetail, readonly string[]>> = {
  mountain: ["wyvern_nest", "ogre_camp", "harpy_cliff", "golem_ruins", "troll_bridge"],
  river: ["lizardfolk_village", "naga_temple", "troll_bridge"],
  wetland: ["lizardfolk_village", "naga_temple"],
  coast: ["naga_temple", "naga_queen_temple"],
  sand: ["naga_temple", "giant_ant_hill"],
  cemetery: ["haunted_manor", "crypt", "vampire_count_castle"],
  temple: ["haunted_manor", "elemental_rift"],
  farmland: ["giant_ant_hill", "werewolf_lair"],
  military: ["dark_elf_outpost", "enemy_town", "ogre_king_hall"],
  industrial: ["elemental_rift", "golem_ruins"],
  hotspring: ["elemental_rift", "flame_lord_rift"],
  railway: ["dark_elf_outpost", "harpy_cliff"],
};
export const DETAIL_LAIR_WEIGHT = 4;

// ── More buildings for held cells (WORLD.md §29.3) ─────────────────────────────────────────────────────────────────

/** By level 1…3, and level 4 going on as from 2 to 3 (as holdings.ts CELL_BUILDINGS; the same costs, CELL_BUILDING_COSTS). */
type ByLevel = readonly [number, number, number, number];
const lv = (a: number, b: number, c: number): ByLevel => [a, b, c, Math.round((c + (c - b)) * 1000) / 1000];

/**
 * A building a 細分地形 (or any cell: "any") offers, besides the two of its terrain. The same shape as holdings.ts
 * CellBuildingRule (makes, finds, fort, travel, room, party), and some ways of its own: `wild` wild monsters raid the cell
 * this share less often (holdings.ts cell raids), `heal` its garrison heals this share faster, `xp` fights set out from it
 * give this share more, `sage` / `breed` the 聰明 breed / its 細分地形's breed are born there this many times as often,
 * `wear` the gear of parties setting out from it wears this share less.
 */
export interface DetailBuildingRule {
  kind: string;
  detail: TerrainDetail | "any";
  name: string;
  blurb: string;
  makes?: Record<string, ByLevel>;
  finds?: Record<string, ByLevel>;
  fort?: ByLevel;
  travel?: ByLevel;
  room?: ByLevel;
  party?: ByLevel;
  wild?: ByLevel;
  heal?: ByLevel;
  xp?: ByLevel;
  sage?: ByLevel;
  breed?: ByLevel;
  wear?: ByLevel;
}

const b = (kind: string, detail: TerrainDetail | "any", name: string, blurb: string, ways: Omit<DetailBuildingRule, "kind" | "detail" | "name" | "blurb">): DetailBuildingRule => ({ kind, detail, name, blurb, ...ways });

export const DETAIL_BUILDINGS: readonly DetailBuildingRule[] = [
  b("mine", "mountain", "礦坑", "每次產出多給石頭和廢鐵，偶爾碎晶", { makes: { stone: lv(3, 6, 10), scrap_iron: lv(1, 2, 3) }, finds: { crystal_shard: lv(0.05, 0.08, 0.12) } }),
  b("hillfort", "mountain", "山寨", "守這一格的居民血量變多", { fort: lv(0.2, 0.3, 0.4) }),
  b("watermill", "river", "水車", "每次產出多給乾糧麵包", { makes: { ration_bread: lv(1, 2, 3) } }),
  b("ferry", "river", "渡口", "從這一格出發的隊伍走得比較快", { travel: lv(0.85, 0.75, 0.65) }),
  b("farmstead", "farmland", "農莊", "每次產出多給胡蘿蔔和麵包", { makes: { food_carrot: lv(2, 4, 6), ration_bread: lv(1, 2, 3) } }),
  b("granary", "farmland", "穀倉", "這一格可以多住一些", { room: lv(5, 10, 15) }),
  b("ossuary", "cemetery", "靈堂", "每次產出多給骨片和靈質", { makes: { bone_shard: lv(2, 3, 5), ectoplasm: lv(0, 1, 1) } }),
  b("bonetower", "cemetery", "骨塔", "守這一格的居民血量變多", { fort: lv(0.15, 0.25, 0.35) }),
  b("frogpond", "wetland", "蛙池", "每次產出多給蛙皮和黏液", { makes: { frog_skin: lv(1, 2, 3), slime_goo: lv(1, 2, 3) } }),
  b("reedmaze", "wetland", "蘆葦迷陣", "野生魔獸比較少來打這一格", { wild: lv(0.3, 0.5, 0.7) }),
  b("academy", "campus", "學院", "從這一格出發打仗，經驗變多", { xp: lv(0.1, 0.2, 0.3) }),
  b("library", "campus", "圖書館", "這一格生出聰明種的機會變大", { sage: lv(2, 3, 4) }),
  b("foundry", "industrial", "鍛造廠", "每次產出多給廢鐵和皮革條", { makes: { scrap_iron: lv(3, 5, 8), leather_strap: lv(0, 1, 1) } }),
  b("repairshop", "industrial", "修理廠", "從這一格出發的隊伍，裝備磨損變少", { wear: lv(0.2, 0.35, 0.5) }),
  b("shellhut", "sand", "拾貝屋", "每次產出多給蟹殼，偶爾珍珠", { makes: { crab_shell: lv(1, 2, 3) }, finds: { river_pearl: lv(0.05, 0.08, 0.12) } }),
  b("sandfort", "sand", "沙堡哨", "守這一格的居民血量變多", { fort: lv(0.15, 0.25, 0.35) }),
  b("harbour", "coast", "漁港", "每次產出多給魚乾和蟹螯", { makes: { ration_fish: lv(2, 3, 5), crab_claw: lv(0, 1, 1) } }),
  b("lighthouse", "coast", "燈塔", "從這一格出發的隊伍走得比較快", { travel: lv(0.85, 0.75, 0.65) }),
  b("bathhouse", "hotspring", "溫泉旅館", "守這一格的居民回血更快", { heal: lv(0.5, 1, 1.5) }),
  b("geotherm", "hotspring", "地熱工坊", "偶爾給碎晶和琥珀", { finds: { crystal_shard: lv(0.1, 0.15, 0.22), amber: lv(0.05, 0.08, 0.12) } }),
  b("shrine", "temple", "香火廟", "野生魔獸比較少來打這一格", { wild: lv(0.3, 0.5, 0.7) }),
  b("blessing", "temple", "祈福台", "這一格生出地形稀有種的機會變大", { breed: lv(2, 3, 4) }),
  b("fieldhospital", "hospital", "野戰醫院", "守這一格的居民回血更快", { heal: lv(0.5, 1, 1.5) }),
  b("pharmacy", "hospital", "藥房", "每次產出多給草藥繃帶", { makes: { item_bandage: lv(1, 1, 2) } }),
  b("stronghold", "military", "要塞堡壘", "守這一格的居民血量變多很多", { fort: lv(0.3, 0.45, 0.6) }),
  b("armory", "military", "軍械庫", "每次產出多給鐵甲片和鋼弩箭", { makes: { guard_plate: lv(0, 1, 1), steel_bolt: lv(1, 2, 3) } }),
  b("station", "railway", "車站", "從這一格出發的隊伍走得快很多", { travel: lv(0.8, 0.7, 0.6) }),
  b("freightyard", "railway", "貨運站", "從這一格出發的隊伍可以多帶幾隻", { party: lv(2, 3, 4) }),
  // anywhere
  b("storehouse", "any", "倉庫", "這一格可以多住一些", { room: lv(3, 6, 10) }),
  b("outpost", "any", "哨站", "野生魔獸比較少來打這一格", { wild: lv(0.2, 0.35, 0.5) }),
  b("altar", "any", "祭壇", "這一格生出地形稀有種的機會變大", { breed: lv(1.5, 2, 2.5) }),
];

/** The buildings a cell of this 細分地形 offers besides its terrain's two (holdings.ts buildingsFor): its own two, and the three of anywhere. */
export function detailBuildingsFor(detail: TerrainDetail | null | undefined): DetailBuildingRule[] {
  return DETAIL_BUILDINGS.filter((r) => r.detail === "any" || r.detail === detail);
}

export function detailBuilding(kind: string): DetailBuildingRule | undefined {
  return DETAIL_BUILDINGS.find((r) => r.kind === kind);
}

/** Building places a cell has: one, a town or another hub two. */
export function buildingSlots(hub: boolean): number {
  return hub ? 2 : 1;
}

// ── Hubs beside the town (WORLD.md §29.4) ──────────────────────────────────────────────────────────────────────────

export type HubKind = "town" | "fortress" | "workstead" | "sanctuary";

/**
 * A region's centre: the town as it is, or a fortress, a workshop town or a sanctuary (the undead's: 墓城). They share the
 * towns' places (holdings.ts TOWN_CELLS_EACH: one hub for every so many cells of a region) and their cost (TOWN_COST); a cell
 * is one at most. Numbers: `births` how fast its nest is (× the town's), and what it does — `room` × a cell's, `fort`
 * its garrison's hit points, `wild` wild raids on its whole region (− share), `party` parties from it, `regionYield` every
 * cell of its region's yields (+ share), `yield` its own (material → each yield), `regionHeal` its region's garrisons' heal
 * (+ share), `rise` the share of a won fight's fallen in its region who get up again, `vsUndead` / `undeadDefend` its
 * defenders' against the undead / undead defenders' there.
 */
export interface HubRule {
  kind: HubKind;
  name: string;
  undeadName?: string;
  blurb: string;
  births: number;
  room?: number;
  fort?: number;
  wild?: number;
  party?: number;
  regionYield?: number;
  yield?: Record<string, number>;
  regionHeal?: number;
  rise?: number;
  vsUndead?: number;
  undeadDefend?: number;
}

export const HUBS: readonly HubRule[] = [
  { kind: "town", name: "城鎮", blurb: "住很多、生得跟主營一樣快，有市場", births: 1 },
  { kind: "fortress", name: "要塞", blurb: "守軍多、很耐打；整區被野生魔獸打的機會減半；從這出征可以多帶 3 隻", births: 0.25, room: 1.5, fort: 0.4, wild: 0.5, party: 3 },
  { kind: "workstead", name: "工坊鎮", blurb: "整區的領地產出 +30%，自己也有一大份產出", births: 0.25, regionYield: 0.3, yield: { scrap_iron: 6, log: 8, stone: 6, leather_strap: 1 } },
  { kind: "sanctuary", name: "聖地", undeadName: "墓城", blurb: "整區守軍回血加倍，打贏時倒下的有機會站起來；對死靈特別強（死靈的墓城反過來）", births: 0.5, regionHeal: 1, rise: 0.2, vsUndead: 0.2 },
];

export function hubRule(kind: string): HubRule | undefined {
  return HUBS.find((h) => h.kind === kind);
}

/** A hub's name for a race (the undead's sanctuary is a 墓城). */
export function hubName(kind: HubKind, race: string): string {
  const h = hubRule(kind)!;
  return race === "undead" && h.undeadName ? h.undeadName : h.name;
}

/** What a sanctuary does for the undead: its defenders are the strong ones there, not those against the undead. */
export function hubForRace(kind: HubKind, race: string): HubRule {
  const h = hubRule(kind)!;
  return kind === "sanctuary" && race === "undead" ? { ...h, vsUndead: 0, undeadDefend: 0.2 } : h;
}

// ── Terrain breeds (WORLD.md §29.2) ────────────────────────────────────────────────────────────────────────────────

type Stats = { might?: number; health?: number; speed?: number };
/**
 * Each 細分地形's own breed (`d_<detail>`), born now and then in place of a common on a held cell of it (camp/population.ts
 * TERRAIN_BREED_CHANCE): its name by race, and its stats as × the race's common (combat.ts BREED_STATS): a little better in
 * one way fitting the ground.
 */
export const TERRAIN_BREEDS: Record<TerrainDetail, { names: Record<string, string>; stats: Stats }> = {
  mountain: { names: { goblin: "岩膚", elf: "山風", undead: "石棺", beast: "岩鬃" }, stats: { health: 1.4 } },
  river: { names: { goblin: "泳河", elf: "溪語", undead: "溺魂", beast: "浪鬃" }, stats: { speed: 1.2 } },
  farmland: { names: { goblin: "田耕", elf: "穀穗", undead: "稻草", beast: "穗尾" }, stats: { health: 1.25, might: 1.05 } },
  cemetery: { names: { goblin: "掘墓", elf: "守靈", undead: "夜哭", beast: "夜嚎" }, stats: { might: 1.2 } },
  wetland: { names: { goblin: "泥沼", elf: "蘆影", undead: "沼魂", beast: "泥爪" }, stats: { health: 1.2, speed: 1.1 } },
  campus: { names: { goblin: "書蟲", elf: "學士", undead: "書靈", beast: "書狐" }, stats: { might: 1.1, speed: 1.05 } },
  industrial: { names: { goblin: "鐵手", elf: "鋼弦", undead: "鐵骨", beast: "鐵爪" }, stats: { might: 1.25 } },
  sand: { names: { goblin: "沙行", elf: "浪蹄", undead: "沙骸", beast: "沙狐" }, stats: { speed: 1.25 } },
  coast: { names: { goblin: "潮汐", elf: "海歌", undead: "沉船", beast: "海狼" }, stats: { health: 1.2, might: 1.1 } },
  hotspring: { names: { goblin: "泡湯", elf: "溫泉", undead: "蒸骨", beast: "湯狐" }, stats: { health: 1.35 } },
  temple: { names: { goblin: "拜拜", elf: "祈福", undead: "背誓", beast: "祭牙" }, stats: { might: 1.15, health: 1.1 } },
  hospital: { names: { goblin: "白衣", elf: "醫葉", undead: "縫屍", beast: "白爪" }, stats: { health: 1.3, speed: 1.05 } },
  military: { names: { goblin: "鐵衛", elf: "衛兵", undead: "骨衛", beast: "戰牙" }, stats: { might: 1.2, health: 1.2 } },
  railway: { names: { goblin: "疾行", elf: "風行", undead: "幽軌", beast: "疾風" }, stats: { speed: 1.35 } },
};

/** The 細分地形 a breed is the terrain breed of (null: not one). */
export function terrainBreedDetail(breed: string): TerrainDetail | null {
  const d = breed.startsWith("d_") ? breed.slice(2) : "";
  return isTerrainDetail(d) ? d : null;
}
