/**
 * What lives in a cell of the big world that no player holds: monster lairs, beasts, barbarians, dark creatures and enemy
 * towns. Some live alone, some in groups (a group is where a party matters). It is worked out from the world's seed and the
 * cell, so the same cell always holds the same thing and nothing has to be stored until someone changes it (clears it,
 * takes it). The real map decides the flavour: beasts in parks and woods, barbarians and towns among buildings, and so on.
 */
import type { CellId } from "./grid.ts";
import { between, pickWeighted, seeded, type Random } from "./random.ts";

/** What the real map (OpenStreetMap) says a cell mostly is. Unknown cells count as open land. */
export type Terrain = "forest" | "park" | "water" | "urban" | "open" | "road";

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
  /** 狂化 (battle.ts): goes berserk when badly hurt — a 初期魔王, a beast of little wit grown big and wild. */
  rage?: number;
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
  /** 1 新手, 2 中級, 3 高級: only tiers up to OPEN_TIERS turn up (the world opens up bit by bit, as in RO or MapleStory). */
  tier: 1 | 2 | 3;
  /**
   * 初期魔王 (server/WORLD.md §21): a big one of its kind (`leader`, always there, first) with a few of its kind round it.
   * Turns up only now and then, in cells that would otherwise be empty (see lairAt), so the lairs already there stay put.
   */
  boss?: boolean;
  leader?: string;
}

/**
 * The tiers of lairs out in the world now. For a start (2026-09-28) only the beginners' ones: lots of different small
 * monsters of low levels everywhere; the tougher ones (the dark crypts, trolls, golems, enemy towns…) come later.
 */
export const OPEN_TIERS = 1;

export const FOES: Record<string, FoeTemplate> = {
  slime: { id: "slime", name: "史萊姆", hp: 18, attack: 3, range: 0, speed: 0.6, row: "front" },
  // the camp's own monsters (raids on the home camp, server/CAMP.md §3.2), scaled from the Mac's numbers against the slime's
  giant_rat: { id: "giant_rat", name: "巨鼠", hp: 12, attack: 5, range: 0, speed: 1.3, row: "front" },
  bat: { id: "bat", name: "蝙蝠", hp: 9, attack: 4, range: 0, speed: 1.6, row: "front" },
  frog: { id: "frog", name: "巨蛙", hp: 16, attack: 4, range: 0, speed: 0.7, row: "front" },
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
  // 2026-09-28: every kind of place has its own (forest spiders and old trees, water folk, the town's underside, bees in the open)
  giant_spider: { id: "giant_spider", name: "巨蜘蛛", hp: 20, attack: 6, range: 0, speed: 1.3, row: "front" },
  spider_queen: { id: "spider_queen", name: "蜘蛛女王", hp: 60, attack: 8, range: 25, speed: 0.9, row: "back" },
  treant: { id: "treant", name: "樹精", hp: 120, attack: 10, range: 0, speed: 0.4, row: "front" },
  mushroom_folk: { id: "mushroom_folk", name: "蘑菇人", hp: 24, attack: 4, range: 0, speed: 0.7, row: "front" },
  spore_mother: { id: "spore_mother", name: "孢子母", hp: 30, attack: 2, range: 25, speed: 0.6, row: "back", heal: 7 },
  kappa: { id: "kappa", name: "河童", hp: 30, attack: 7, range: 0, speed: 1.0, row: "front" },
  water_snake: { id: "water_snake", name: "水蛇", hp: 16, attack: 6, range: 0, speed: 1.6, row: "front" },
  naiad: { id: "naiad", name: "水妖", hp: 22, attack: 5, range: 35, speed: 1.0, row: "back", heal: 5 },
  giant_crab: { id: "giant_crab", name: "巨蟹", hp: 55, attack: 7, range: 0, speed: 0.6, row: "front" },
  rat_king: { id: "rat_king", name: "鼠王", hp: 45, attack: 8, range: 0, speed: 1.1, row: "front" },
  bandit: { id: "bandit", name: "盜賊", hp: 26, attack: 7, range: 0, speed: 1.2, row: "front" },
  knife_thrower: { id: "knife_thrower", name: "飛刀手", hp: 18, attack: 7, range: 35, speed: 1.1, row: "back" },
  bandit_boss: { id: "bandit_boss", name: "盜賊頭目", hp: 70, attack: 11, range: 0, speed: 1.0, row: "front" },
  gargoyle: { id: "gargoyle", name: "石像鬼", hp: 45, attack: 8, range: 0, speed: 1.1, row: "front", night: 1.4 },
  killer_bee: { id: "killer_bee", name: "殺人蜂", hp: 7, attack: 4, range: 0, speed: 1.8, row: "front" },
  queen_bee: { id: "queen_bee", name: "蜂后", hp: 40, attack: 5, range: 20, speed: 0.8, row: "back", heal: 4 },
  stone_golem: { id: "stone_golem", name: "石像巨人", hp: 180, attack: 16, range: 0, speed: 0.5, row: "front" },
  vampire_bat: { id: "vampire_bat", name: "吸血蝙蝠", hp: 20, attack: 7, range: 0, speed: 1.7, row: "front", night: 1.5 },
  // 2026-09-28: the beginners' crowd (small, weak, many kinds), as a world starts in RO or MapleStory
  rabbit: { id: "rabbit", name: "野兔", hp: 10, attack: 2, range: 0, speed: 1.4, row: "front" },
  snail: { id: "snail", name: "蝸牛", hp: 14, attack: 2, range: 0, speed: 0.4, row: "front" },
  caterpillar: { id: "caterpillar", name: "毛毛蟲", hp: 12, attack: 2, range: 0, speed: 0.5, row: "front" },
  beetle: { id: "beetle", name: "甲蟲", hp: 16, attack: 3, range: 0, speed: 0.8, row: "front" },
  crow: { id: "crow", name: "烏鴉", hp: 8, attack: 3, range: 0, speed: 1.6, row: "front" },
  pigeon: { id: "pigeon", name: "野鴿", hp: 6, attack: 1, range: 0, speed: 1.5, row: "front" },
  squirrel: { id: "squirrel", name: "松鼠", hp: 8, attack: 2, range: 0, speed: 1.7, row: "front" },
  hedgehog: { id: "hedgehog", name: "刺蝟", hp: 14, attack: 3, range: 0, speed: 0.7, row: "front" },
  goose: { id: "goose", name: "野鵝", hp: 14, attack: 3, range: 0, speed: 1.0, row: "front" },
  fox: { id: "fox", name: "狐狸", hp: 14, attack: 4, range: 0, speed: 1.4, row: "front" },
  // by the roads: people who rob travellers, and the orcs' patrols
  robber: { id: "robber", name: "攔路強盜", hp: 16, attack: 4, range: 0, speed: 1.1, row: "front" },
  orc_grunt: { id: "orc_grunt", name: "強獸人步兵", hp: 30, attack: 6, range: 0, speed: 0.9, row: "front" },
  orc_archer: { id: "orc_archer", name: "強獸人弓手", hp: 20, attack: 5, range: 35, speed: 0.9, row: "back" },
  orc_chief: { id: "orc_chief", name: "強獸人隊長", hp: 80, attack: 12, range: 0, speed: 1.0, row: "front" },
  // the world's great monsters (bosses.ts): their wounds stay between fights, so it takes several full parties (one of 60
  // does about 6000 in the BOSS_ROUNDS it gets)
  ancient_dragon: { id: "ancient_dragon", name: "古龍", hp: 9000, attack: 26, range: 30, speed: 0.9, row: "front" },
  lich_king: { id: "lich_king", name: "巫妖王", hp: 7000, attack: 20, range: 40, speed: 0.8, row: "back", heal: 60, night: 1.3 },
  hill_giant: { id: "hill_giant", name: "山丘巨人", hp: 11000, attack: 28, range: 0, speed: 0.5, row: "front" },
  hydra: { id: "hydra", name: "九頭蛇", hp: 8500, attack: 16, range: 0, speed: 1.2, row: "front" },
  minotaur: { id: "minotaur", name: "牛頭人", hp: 7500, attack: 30, range: 0, speed: 1.0, row: "front" },
  drake: { id: "drake", name: "小飛龍", hp: 60, attack: 10, range: 0, speed: 1.4, row: "front" },
  // 初期魔王 (2026-09-29): one big one of a beginners' kind, leading a few of its kind; a party of the first gear and a
  // second wave (its wounds stay) can take it, and it leaves what the middle gear is made of (camp/gear.ts). A beast of
  // little wit grown this big has gone wild: hurt badly, it goes berserk (狂化, battle.ts)
  giant_bat: { id: "giant_bat", name: "嗜血巨蝠", hp: 230, attack: 13, range: 0, speed: 1.8, row: "front", night: 1.4, rage: 0.5 },
  dire_wolf: { id: "dire_wolf", name: "狂暴巨狼", hp: 220, attack: 14, range: 0, speed: 1.5, row: "front", rage: 0.5 },
  slime_king: { id: "slime_king", name: "狂化史萊姆王", hp: 420, attack: 17, range: 0, speed: 0.5, row: "front", heal: 10, rage: 0.5 },
  boar_lord: { id: "boar_lord", name: "暴怒野豬王", hp: 230, attack: 15, range: 0, speed: 1.0, row: "front", rage: 0.5 },
  toad_king: { id: "toad_king", name: "狂化蛙王", hp: 300, attack: 13, range: 20, speed: 0.8, row: "back", rage: 0.5 },
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
    loot: [...SCRAP, { id: "crystal_shard", min: 1, max: 1, chance: 0.05 }], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "wolf_den", name: "野狼窩", faction: "beast", group: [3, 5],
    members: [{ foe: "wolf", weight: 6 }, { foe: "alpha_wolf", weight: 1 }],
    terrain: { forest: 4, park: 3, open: 1 },
    loot: [{ id: "scrap_rag", min: 2, max: 4, chance: 0.8 }], respawnHours: 8, levels: [1, 3], tier: 1,
  },
  {
    id: "bear_cave", name: "洞穴熊", faction: "beast", group: [1, 1],
    members: [{ foe: "bear", weight: 1 }],
    terrain: { forest: 2, park: 1 },
    loot: [{ id: "scrap_rag", min: 3, max: 5, chance: 1 }], respawnHours: 12, levels: [2, 5], tier: 2,
  },
  {
    id: "boar_thicket", name: "野豬林", faction: "beast", group: [2, 4],
    members: [{ foe: "boar", weight: 1 }],
    terrain: { forest: 2, park: 2, open: 2 },
    loot: [{ id: "scrap_rag", min: 1, max: 3, chance: 0.8 }], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "barbarian_camp", name: "野蠻人營地", faction: "barbarian", group: [4, 8],
    members: [{ foe: "barbarian", weight: 5 }, { foe: "barbarian_archer", weight: 3 }, { foe: "shaman", weight: 1 }],
    terrain: { open: 3, urban: 3, park: 1 },
    loot: [...SCRAP, { id: "scrap_iron", min: 2, max: 5, chance: 0.8 }], respawnHours: 12, levels: [2, 6], tier: 2,
  },
  {
    id: "crypt", name: "黑暗墓穴", faction: "dark", group: [3, 7],
    members: [{ foe: "skeleton", weight: 5 }, { foe: "wraith", weight: 2 }, { foe: "bone_knight", weight: 1 }],
    terrain: { urban: 2, open: 1, park: 1, forest: 1 },
    loot: [{ id: "scrap_iron", min: 1, max: 3, chance: 0.7 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.15 }],
    respawnHours: 12, levels: [3, 7], tier: 3,
  },
  {
    id: "troll_bridge", name: "巨魔橋", faction: "monster", group: [1, 1],
    members: [{ foe: "troll", weight: 1 }],
    terrain: { water: 3 },
    loot: [{ id: "scrap_iron", min: 3, max: 6, chance: 1 }, { id: "crystal_shard", min: 1, max: 2, chance: 0.3 }],
    respawnHours: 24, levels: [4, 8], tier: 3,
  },
  {
    id: "enemy_town", name: "敵人城鎮", faction: "town", group: [8, 14],
    members: [{ foe: "guard", weight: 5 }, { foe: "crossbow", weight: 3 }, { foe: "captain", weight: 1 }],
    terrain: { urban: 1 },
    loot: [...SCRAP.map((s) => ({ ...s, min: s.min * 3, max: s.max * 3, chance: 1 })), { id: "crystal_shard", min: 1, max: 3, chance: 0.5 }],
    respawnHours: 48, levels: [5, 10], tier: 3,
  },
  // 2026-09-28: more lairs, so each kind of place has its own
  {
    id: "spider_nest", name: "蜘蛛巢", faction: "beast", group: [3, 6],
    members: [{ foe: "giant_spider", weight: 6 }, { foe: "spider_queen", weight: 1 }],
    terrain: { forest: 3, park: 1 },
    loot: [...SCRAP], respawnHours: 8, levels: [1, 5], tier: 2,
  },
  {
    id: "treant_grove", name: "古樹林", faction: "monster", group: [1, 2],
    members: [{ foe: "treant", weight: 1 }],
    terrain: { forest: 2 },
    loot: [{ id: "scrap_wood", min: 4, max: 8, chance: 1 }], respawnHours: 16, levels: [3, 7], tier: 2,
  },
  {
    id: "mushroom_ring", name: "蘑菇圈", faction: "monster", group: [3, 6],
    members: [{ foe: "mushroom_folk", weight: 4 }, { foe: "spore_mother", weight: 1 }],
    terrain: { forest: 2, park: 2 },
    loot: [...SCRAP], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "kappa_pond", name: "河童池", faction: "monster", group: [2, 5],
    members: [{ foe: "kappa", weight: 3 }, { foe: "water_snake", weight: 3 }, { foe: "naiad", weight: 1 }],
    terrain: { water: 3, park: 1 },
    loot: [...SCRAP], respawnHours: 8, levels: [2, 6], tier: 2,
  },
  {
    id: "crab_shore", name: "巨蟹灘", faction: "beast", group: [2, 4],
    members: [{ foe: "giant_crab", weight: 1 }],
    terrain: { water: 2 },
    loot: [{ id: "scrap_iron", min: 1, max: 3, chance: 0.6 }], respawnHours: 8, levels: [2, 5], tier: 2,
  },
  {
    id: "frog_marsh", name: "巨蛙沼澤", faction: "beast", group: [3, 6],
    members: [{ foe: "frog", weight: 4 }, { foe: "water_snake", weight: 1 }],
    terrain: { water: 2, park: 1 },
    loot: [...SCRAP], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "sewer_warren", name: "下水道鼠窩", faction: "beast", group: [4, 8],
    members: [{ foe: "giant_rat", weight: 8 }, { foe: "rat_king", weight: 1 }],
    terrain: { urban: 3 },
    loot: [...SCRAP], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "bandit_hideout", name: "盜賊窩", faction: "barbarian", group: [3, 7],
    members: [{ foe: "bandit", weight: 4 }, { foe: "knife_thrower", weight: 2 }, { foe: "bandit_boss", weight: 1 }],
    terrain: { urban: 2, open: 1 },
    loot: [...SCRAP, { id: "scrap_iron", min: 1, max: 4, chance: 0.7 }], respawnHours: 12, levels: [2, 6], tier: 2,
  },
  {
    id: "gargoyle_roost", name: "石像鬼塔", faction: "dark", group: [2, 4],
    members: [{ foe: "gargoyle", weight: 1 }],
    terrain: { urban: 1 },
    loot: [{ id: "crystal_shard", min: 1, max: 1, chance: 0.35 }], respawnHours: 16, levels: [3, 7], tier: 3,
  },
  {
    id: "bat_cave", name: "蝙蝠洞", faction: "dark", group: [4, 8],
    members: [{ foe: "bat", weight: 5 }, { foe: "vampire_bat", weight: 2 }],
    terrain: { forest: 1, urban: 1, open: 1 },
    loot: [...SCRAP], respawnHours: 8, levels: [1, 5], tier: 2,
  },
  {
    id: "bee_hive", name: "殺人蜂巢", faction: "beast", group: [5, 9],
    members: [{ foe: "killer_bee", weight: 8 }, { foe: "queen_bee", weight: 1 }],
    terrain: { open: 2, park: 2, forest: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 2, chance: 0.5 }], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  {
    id: "golem_ruins", name: "石像遺跡", faction: "monster", group: [1, 1],
    members: [{ foe: "stone_golem", weight: 1 }],
    terrain: { open: 1, urban: 1 },
    loot: [{ id: "scrap_iron", min: 3, max: 6, chance: 1 }, { id: "crystal_shard", min: 1, max: 2, chance: 0.5 }], respawnHours: 24, levels: [5, 9], tier: 3,
  },
  // the beginners' lairs (2026-09-28)
  {
    id: "rabbit_warren", name: "野兔窩", faction: "beast", group: [3, 6],
    members: [{ foe: "rabbit", weight: 1 }],
    terrain: { park: 3, open: 3, forest: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 2, chance: 0.5 }], respawnHours: 4, levels: [1, 2], tier: 1,
  },
  {
    id: "snail_patch", name: "蝸牛草叢", faction: "beast", group: [3, 6],
    members: [{ foe: "snail", weight: 3 }, { foe: "caterpillar", weight: 2 }],
    terrain: { park: 2, forest: 2, water: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 2, chance: 0.4 }], respawnHours: 4, levels: [1, 2], tier: 1,
  },
  {
    id: "beetle_log", name: "甲蟲朽木", faction: "beast", group: [2, 5],
    members: [{ foe: "beetle", weight: 3 }, { foe: "caterpillar", weight: 1 }],
    terrain: { forest: 3, park: 1 },
    loot: [{ id: "scrap_wood", min: 1, max: 3, chance: 0.8 }], respawnHours: 5, levels: [1, 3], tier: 1,
  },
  {
    id: "crow_roost", name: "烏鴉樹", faction: "beast", group: [3, 7],
    members: [{ foe: "crow", weight: 2 }, { foe: "pigeon", weight: 3 }],
    terrain: { urban: 3, park: 2, open: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 2, chance: 0.5 }, { id: "scrap_iron", min: 1, max: 1, chance: 0.3 }], respawnHours: 4, levels: [1, 3], tier: 1,
  },
  {
    id: "squirrel_grove", name: "松鼠林", faction: "beast", group: [3, 6],
    members: [{ foe: "squirrel", weight: 3 }, { foe: "hedgehog", weight: 1 }],
    terrain: { park: 3, forest: 2 },
    loot: [{ id: "scrap_wood", min: 1, max: 2, chance: 0.6 }], respawnHours: 4, levels: [1, 3], tier: 1,
  },
  {
    id: "goose_pond", name: "野鵝池", faction: "beast", group: [2, 5],
    members: [{ foe: "goose", weight: 1 }],
    terrain: { water: 3, park: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 2, chance: 0.5 }], respawnHours: 5, levels: [1, 3], tier: 1,
  },
  {
    id: "fox_den", name: "狐狸洞", faction: "beast", group: [1, 3],
    members: [{ foe: "fox", weight: 1 }],
    terrain: { forest: 2, open: 1, park: 1 },
    loot: [{ id: "scrap_rag", min: 1, max: 3, chance: 0.7 }], respawnHours: 6, levels: [1, 3], tier: 1,
  },
  // by the big roads (the real map's, OpenStreetMap)
  {
    id: "highway_robbers", name: "攔路強盜", faction: "barbarian", group: [2, 5],
    members: [{ foe: "robber", weight: 4 }, { foe: "bandit", weight: 1 }],
    terrain: { road: 3 },
    loot: [{ id: "scrap_rag", min: 1, max: 3, chance: 0.7 }, { id: "stolen_coin", min: 1, max: 2, chance: 0.5 }], respawnHours: 5, levels: [1, 3], tier: 1,
  },
  {
    id: "orc_patrol", name: "強獸人巡邏隊", faction: "barbarian", group: [3, 5],
    members: [{ foe: "orc_grunt", weight: 3 }, { foe: "orc_archer", weight: 1 }],
    terrain: { road: 2, open: 1 },
    loot: [...SCRAP], respawnHours: 6, levels: [2, 3], tier: 1,
  },
  {
    id: "orc_warband", name: "強獸人軍團", faction: "barbarian", group: [8, 14],
    members: [{ foe: "orc_grunt", weight: 6 }, { foe: "orc_archer", weight: 3 }, { foe: "orc_chief", weight: 1 }],
    terrain: { road: 1, open: 1 },
    loot: [...SCRAP.map((x) => ({ ...x, min: x.min * 2, max: x.max * 2 }))], respawnHours: 12, levels: [3, 7], tier: 2,
  },
  // 初期魔王 (2026-09-29): rare, in cells that would otherwise be empty (lairAt); their loot is the camp's odds and ends,
  // what they are after is what the big ones drop (world/drops.ts)
  {
    id: "giant_bat_roost", name: "巨大蝙蝠洞", faction: "dark", group: [3, 5], boss: true, leader: "giant_bat",
    members: [{ foe: "bat", weight: 1 }],
    terrain: { urban: 2, forest: 1, open: 1 },
    loot: [...SCRAP, { id: "crystal_shard", min: 1, max: 1, chance: 0.3 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
  {
    id: "dire_wolf_den", name: "巨狼巢", faction: "beast", group: [3, 4], boss: true, leader: "dire_wolf",
    members: [{ foe: "wolf", weight: 1 }],
    terrain: { forest: 3, park: 2 },
    loot: [{ id: "scrap_rag", min: 2, max: 4, chance: 1 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.3 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
  {
    id: "slime_king_pool", name: "史萊姆王池", faction: "monster", group: [4, 6], boss: true, leader: "slime_king",
    members: [{ foe: "big_slime", weight: 2 }, { foe: "slime", weight: 1 }],
    terrain: { park: 2, water: 2, open: 1 },
    loot: [...SCRAP, { id: "crystal_shard", min: 1, max: 2, chance: 0.3 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
  {
    id: "boar_lord_thicket", name: "野豬王林", faction: "beast", group: [2, 3], boss: true, leader: "boar_lord",
    members: [{ foe: "boar", weight: 1 }],
    terrain: { forest: 2, open: 2 },
    loot: [{ id: "scrap_rag", min: 2, max: 4, chance: 1 }, { id: "crystal_shard", min: 1, max: 1, chance: 0.3 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
  {
    id: "toad_king_marsh", name: "蛙王沼澤", faction: "beast", group: [3, 5], boss: true, leader: "toad_king",
    members: [{ foe: "frog", weight: 3 }, { foe: "water_snake", weight: 1 }],
    terrain: { water: 3 },
    loot: [...SCRAP, { id: "crystal_shard", min: 1, max: 1, chance: 0.3 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
  {
    id: "robber_chief_camp", name: "強盜頭目營", faction: "barbarian", group: [4, 6], boss: true, leader: "bandit_boss",
    members: [{ foe: "bandit", weight: 2 }, { foe: "robber", weight: 1 }],
    terrain: { road: 3, urban: 1 },
    loot: [...SCRAP, { id: "stolen_coin", min: 2, max: 4, chance: 1 }], respawnHours: 24, levels: [2, 4], tier: 1,
  },
];

/**
 * 中級的巢穴 that stray into the beginners' world (2026-09-29): now and then, in a cell that would otherwise be empty, one of
 * these at low levels, so what the next tier's gear is made of can be had a little before that tier opens.
 */
export const STRAY_LAIRS: { kind: string; levels: [number, number] }[] = [
  { kind: "spider_nest", levels: [1, 2] },
  { kind: "bat_cave", levels: [1, 2] },
  { kind: "kappa_pond", levels: [1, 2] },
  { kind: "crab_shore", levels: [1, 2] },
  { kind: "bear_cave", levels: [1, 2] },
  { kind: "bandit_hideout", levels: [1, 2] },
];
/** Of the cells that would be empty: how many hold a 初期魔王, and how many a stray lair of the next tier. */
export const BOSS_LAIR_CHANCE = 0.02;
export const STRAY_LAIR_CHANCE = 0.06;

/** Every kind that may turn up on this ground now: the usual ones, the 初期魔王 and the strays. */
export function lairKindsFor(terrain: Terrain): { usual: string[]; rare: string[] } {
  const here = (l: LairKind) => (l.terrain[terrain] ?? 0) > 0;
  return {
    usual: LAIRS.filter((l) => l.tier <= OPEN_TIERS && !l.boss && here(l)).map((l) => l.id),
    rare: [...LAIRS.filter((l) => l.tier <= OPEN_TIERS && l.boss && here(l)), ...STRAY_LAIRS.map((s) => LAIRS.find((l) => l.id === s.kind)!).filter(here)].map((l) => l.id),
  };
}

/** How likely a free cell is to hold anything at all, by terrain. */
const OCCUPIED: Record<Terrain, number> = { forest: 0.45, park: 0.4, water: 0.2, urban: 0.35, open: 0.3, road: 0.4 };

export interface Lair {
  cell: CellId;
  kind: string;
  name: string;
  faction: Faction;
  level: number;
  /** The foes, in order; the battle scales each by `level`. */
  foes: string[];
  /** A 初期魔王's lair (its leader first in `foes`). */
  boss?: boolean;
}

/** What is in a free cell (nil = nothing). The same seed and cell always give the same answer. */
export function lairAt(worldSeed: number, cell: CellId, terrain: Terrain = "open"): Lair | null {
  const random = seeded(worldSeed, cell, "lair");
  if (random() >= OCCUPIED[terrain]) return rareLairAt(worldSeed, cell, terrain);
  const candidates = LAIRS.filter((l) => l.tier <= OPEN_TIERS && !l.boss && (l.terrain[terrain] ?? 0) > 0);
  if (candidates.length === 0) return null;
  const kind = pickWeighted(random, candidates, (l) => l.terrain[terrain] ?? 0);
  return makeLair(cell, kind, kind.levels, random);
}

/**
 * What a cell that would be empty may hold now and then: a 初期魔王 or a stray lair of the next tier (their own random
 * numbers, so the ordinary lairs are where they always were).
 */
function rareLairAt(worldSeed: number, cell: CellId, terrain: Terrain): Lair | null {
  const random = seeded(worldSeed, cell, "rare-lair");
  const roll = random();
  if (roll < BOSS_LAIR_CHANCE) {
    const bosses = LAIRS.filter((l) => l.tier <= OPEN_TIERS && l.boss && (l.terrain[terrain] ?? 0) > 0);
    if (bosses.length === 0) return null;
    const kind = pickWeighted(random, bosses, (l) => l.terrain[terrain] ?? 0);
    return makeLair(cell, kind, kind.levels, random);
  }
  if (roll < BOSS_LAIR_CHANCE + STRAY_LAIR_CHANCE) {
    const strays = STRAY_LAIRS.map((s) => ({ kind: LAIRS.find((l) => l.id === s.kind)!, levels: s.levels })).filter((s) => (s.kind.terrain[terrain] ?? 0) > 0);
    if (strays.length === 0) return null;
    const pick = pickWeighted(random, strays, (s) => s.kind.terrain[terrain] ?? 0);
    return makeLair(cell, pick.kind, pick.levels, random);
  }
  return null;
}

function makeLair(cell: CellId, kind: LairKind, levels: [number, number], random: Random): Lair {
  // low levels are common, high ones rare
  const [lo, hi] = levels;
  const level = lo + Math.floor((hi - lo + 1) * random() ** 2);
  const count = between(random, kind.group[0], kind.group[1]);
  const foes = Array.from({ length: kind.leader ? count - 1 : count }, () => pickWeighted(random, kind.members, (m) => m.weight).foe);
  return { cell, kind: kind.id, name: kind.name, faction: kind.faction, level, foes: kind.leader ? [kind.leader, ...foes] : foes, ...(kind.boss ? { boss: true } : {}) };
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
