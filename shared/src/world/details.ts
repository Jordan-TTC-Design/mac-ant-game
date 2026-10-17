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
  mountain: ["goblin"], river: ["elf"], farmland: ["elf"], cemetery: ["undead"], wetland: ["elf"], campus: ["goblin", "elf", "undead"],
  industrial: ["goblin"], sand: ["elf"], coast: ["elf"], hotspring: ["goblin", "elf", "undead"], temple: ["goblin", "elf"],
  hospital: ["goblin", "elf", "undead"], military: ["goblin", "elf", "undead"], railway: ["goblin", "elf", "undead"],
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
