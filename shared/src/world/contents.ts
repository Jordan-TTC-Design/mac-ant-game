/**
 * What lives in a cell of the big world that no player holds: monster lairs, beasts, barbarians, dark creatures and enemy
 * towns. Some live alone, some in groups (a group is where a party matters). It is worked out from the world's seed and the
 * cell, so the same cell always holds the same thing and nothing has to be stored until someone changes it (clears it,
 * takes it). The real map decides the flavour: beasts in parks and woods, barbarians and towns among buildings, and so on.
 */
import type { CellId } from "./grid.ts";
import { between, pickWeighted, seeded, type Random } from "./random.ts";

/** What the real map (OpenStreetMap) says a cell mostly is. Unknown cells count as open land. */
export type Terrain = "forest" | "park" | "water" | "urban" | "open";

export type Faction = "monster" | "beast" | "barbarian" | "dark" | "town";

/** One kind of foe as it fights (see battle.ts): per level 1. */
export interface FoeTemplate {
  id: string;
  name: string;
  hp: number;
  attack: number;
  /** 0 = fights up close; more = shoots from that far back. */
  range: number;
  speed: number;
  /** Stands in the front row (takes the blows) or the back. */
  row: "front" | "back";
  /** Heals its side each round instead of attacking. */
  heal?: number;
  /** Stronger at night (the dark ones): attack × this at night. */
  night?: number;
}

export interface LairKind {
  id: string;
  name: string;
  faction: Faction;
  /** Alone (1) or a group of this many. */
  group: [number, number];
  /** The foes a group is made of, with how often each appears in it. */
  members: { foe: string; weight: number }[];
  /** How often it turns up, by terrain (0 = never there). */
  terrain: Partial<Record<Terrain, number>>;
  /** What clearing it drops (material ids the camp already knows), per level. */
  loot: { id: string; min: number; max: number; chance: number }[];
  /** Hours before a cleared lair is back. */
  respawnHours: number;
  /** Levels it comes in. */
  levels: [number, number];
}

export const FOES: Record<string, FoeTemplate> = {
  slime: { id: "slime", name: "史萊姆", hp: 18, attack: 3, range: 0, speed: 0.6, row: "front" },
  big_slime: { id: "big_slime", name: "大史萊姆", hp: 45, attack: 5, range: 0, speed: 0.4, row: "front" },
  wolf: { id: "wolf", name: "野狼", hp: 22, attack: 6, range: 0, speed: 1.4, row: "front" },
  alpha_wolf: { id: "alpha_wolf", name: "狼王", hp: 50, attack: 9, range: 0, speed: 1.3, row: "front" },
  bear: { id: "bear", name: "洞穴熊", hp: 90, attack: 12, range: 0, speed: 0.8, row: "front" },
  boar: { id: "boar", name: "野豬", hp: 35, attack: 7, range: 0, speed: 1.1, row: "front" },
  barbarian: { id: "barbarian", name: "野蠻人", hp: 30, attack: 7, range: 0, speed: 1.0, row: "front" },
  barbarian_archer: { id: "barbarian_archer", name: "野蠻人弓手", hp: 20, attack: 6, range: 40, speed: 1.0, row: "back" },
  shaman: { id: "shaman", name: "薩滿", hp: 22, attack: 2, range: 30, speed: 0.9, row: "back", heal: 6 },
  skeleton: { id: "skeleton", name: "骷髏兵", hp: 26, attack: 6, range: 0, speed: 0.9, row: "front", night: 1.3 },
  wraith: { id: "wraith", name: "怨靈", hp: 18, attack: 8, range: 30, speed: 1.3, row: "back", night: 1.5 },
  bone_knight: { id: "bone_knight", name: "骸骨騎士", hp: 70, attack: 11, range: 0, speed: 0.9, row: "front", night: 1.3 },
  troll: { id: "troll", name: "巨魔", hp: 140, attack: 15, range: 0, speed: 0.6, row: "front" },
  guard: { id: "guard", name: "城鎮守衛", hp: 40, attack: 8, range: 0, speed: 1.0, row: "front" },
  crossbow: { id: "crossbow", name: "弩手", hp: 24, attack: 9, range: 50, speed: 0.9, row: "back" },
  captain: { id: "captain", name: "守備隊長", hp: 80, attack: 12, range: 0, speed: 1.0, row: "front" },
};

const SCRAP = [
  { id: "scrap_rag", min: 1, max: 3, chance: 0.6 },
  { id: "scrap_wood", min: 1, max: 4, chance: 0.6 },
  { id: "scrap_iron", min: 1, max: 3, chance: 0.5 },
];

export const LAIRS: LairKind[] = [
  {
    id: "slime_pit", name: "史萊姆坑", faction: "monster", group: [3, 6],
    members: [{ foe: "slime", weight: 5 }, { foe: "big_slime", weight: 1 }],
    terrain: { park: 3, forest: 2, open: 3, water: 2, urban: 1 },
    loot: [...SCRAP, { id: "crystal_shard", min: 1, max: 1, chance: 0.05 }], respawnHours: 6, levels: [1, 3],
  },
  {
    id: "wolf_den", name: "野狼窩", faction: "beast", group: [3, 5],
    members: [{ foe: "wolf", weight: 6 }, { foe: "alpha_wolf", weight: 1 }],
    terrain: { forest: 4, park: 3, open: 1 },
    loot: [{ id: "scrap_rag", min: 2, max: 4, chance: 0.8 }], respawnHours: 8, levels: [1, 4],
  },
  {
    id: "bear_cave", name: "洞穴熊", faction: "beast", group: [1, 1],
    members: [{ foe: "bear", weight: 1 }],
    terrain: { forest: 2, park: 1 },
    loot: [{ id: "scrap_rag", min: 3, max: 5, chance: 1 }], respawnHours: 12, levels: [2, 5],
  },
  {
    id: "boar_thicket", name: "野豬林", faction: "beast", group: [2, 4],
    members: [{ foe: "boar", weight: 1 }],
    terrain: { forest: 2, park: 2, open: 2 },
    loot: [{ id: "scrap_rag", min: 1, max: 3, chance: 0.8 }], respawnHours: 6, levels: [1, 3],
  },
  {
    id: "barbarian_camp", name: "野蠻人營地", faction: "barbarian", group: [4, 8],
    members: [{ foe: "barbarian", weight: 5 }, { foe: "barbarian_archer", weight: 3 }, { foe: "shaman", weight: 1 }],
    terrain: { open: 3, urban: 3, park: 1 },
    loot: [...SCRAP, { id: "scrap_iron", min: 2, max: 5, chance: 0.8 }], respawnHours: 12, levels: [2, 6],
  },
  {
    id: "crypt", name: "黑暗墓穴", faction: "dark", group: [3, 7],
    members: [{ foe: "skeleton", weight: 5 }, { foe: "wraith", weight: 2 }, { foe: "bone_knight", weight: 1 }],
    terrain: { urban: 2, open: 1, park: 1, forest: 1 },
    loot: [{ id: "scrap_iron", min: 1, max: 3, chance: 0.7 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.15 }],
    respawnHours: 12, levels: [3, 7],
  },
  {
    id: "troll_bridge", name: "巨魔橋", faction: "monster", group: [1, 1],
    members: [{ foe: "troll", weight: 1 }],
    terrain: { water: 3 },
    loot: [{ id: "scrap_iron", min: 3, max: 6, chance: 1 }, { id: "crystal_shard", min: 1, max: 2, chance: 0.3 }],
    respawnHours: 24, levels: [4, 8],
  },
  {
    id: "enemy_town", name: "敵人城鎮", faction: "town", group: [8, 14],
    members: [{ foe: "guard", weight: 5 }, { foe: "crossbow", weight: 3 }, { foe: "captain", weight: 1 }],
    terrain: { urban: 1 },
    loot: [...SCRAP.map((s) => ({ ...s, min: s.min * 3, max: s.max * 3, chance: 1 })), { id: "crystal_shard", min: 1, max: 3, chance: 0.5 }],
    respawnHours: 48, levels: [5, 10],
  },
];

/** How likely a free cell is to hold anything at all, by terrain. */
const OCCUPIED: Record<Terrain, number> = { forest: 0.45, park: 0.4, water: 0.2, urban: 0.35, open: 0.3 };

export interface Lair {
  cell: CellId;
  kind: string;
  name: string;
  faction: Faction;
  level: number;
  /** The foes, in order; the battle scales each by `level`. */
  foes: string[];
}

/** What is in a free cell (nil = nothing). The same seed and cell always give the same answer. */
export function lairAt(worldSeed: number, cell: CellId, terrain: Terrain = "open"): Lair | null {
  const random = seeded(worldSeed, cell, "lair");
  if (random() >= OCCUPIED[terrain]) return null;
  const candidates = LAIRS.filter((l) => (l.terrain[terrain] ?? 0) > 0);
  if (candidates.length === 0) return null;
  const kind = pickWeighted(random, candidates, (l) => l.terrain[terrain] ?? 0);
  // low levels are common, high ones rare
  const [lo, hi] = kind.levels;
  const level = lo + Math.floor((hi - lo + 1) * random() ** 2);
  const count = between(random, kind.group[0], kind.group[1]);
  const foes = Array.from({ length: count }, () => pickWeighted(random, kind.members, (m) => m.weight).foe);
  return { cell, kind: kind.id, name: kind.name, faction: kind.faction, level, foes };
}

/** What clearing a lair drops (for the winner to carry home). */
export function lootFor(lair: Lair, random: Random): Record<string, number> {
  const kind = LAIRS.find((l) => l.id === lair.kind);
  const out: Record<string, number> = {};
  for (const drop of kind?.loot ?? []) {
    if (random() >= drop.chance) continue;
    const count = between(random, drop.min, drop.max) + Math.floor((lair.level - 1) / 2);
    out[drop.id] = (out[drop.id] ?? 0) + count;
  }
  return out;
}

export function respawnHours(lair: Lair): number {
  return LAIRS.find((l) => l.id === lair.kind)?.respawnHours ?? 12;
}
