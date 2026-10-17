/**
 * Monster raids on the home camp (server/CAMP.md §11): when they come and what comes. Only the server uses this (a Mac
 * that is offline sees no raids; the fight itself is worked out with the big world's battle rules and played back).
 */
import { hashString, randomFrom } from "../world/random.ts";
import { taipeiDay } from "./merchant.ts";
import { raceRules } from "./races.ts";

const MINUTE = 60_000;

/** How a monster fights in a raid (the big world's battle rules; shared/src/world/contents.ts FOES has the same shape). */
export interface CampFoe {
  name: string;
  hp: number;
  attack: number;
  range: number;
  speed: number;
  row: "front" | "back";
  night?: number;
  heal?: number;
}

export interface CampMonster extends Partial<CampFoe> {
  id: string;
  /** Its strength among the first four (1, 2: from 60 residents), else its tier. */
  level: number;
  /** Tier 1–4 and the race level (big world) it starts coming at (DESKTOP.md §10.0). */
  tier: 1 | 2 | 3 | 4;
  from: number;
}

const m = (id: string, tier: 2 | 3 | 4, from: number, name: string, hp: number, attack: number, speed: number, extra: Partial<CampFoe> = {}): CampMonster =>
  ({ id, level: tier, tier, from, name, hp, attack, speed, range: 0, row: "front", ...extra });

/**
 * The camp's monsters, weakest first (mac/Resources/Animals: the hostile ones). The first four fight as the big world's FOES;
 * the others have their own numbers here. More of them come as the race grows: tier 2 from race level 6, 3 from 12, 4 from 18.
 */
export const CAMP_MONSTERS: readonly CampMonster[] = [
  { id: "slime", level: 1, tier: 1, from: 1 },
  { id: "giant_rat", level: 1, tier: 1, from: 1 },
  { id: "bat", level: 2, tier: 1, from: 1 },
  { id: "frog", level: 2, tier: 1, from: 1 },
  { id: "horn_beetle", level: 1, tier: 1, from: 1, name: "角甲蟲", hp: 16, attack: 4, range: 0, speed: 0.8, row: "front" },
  { id: "grass_snake", level: 2, tier: 1, from: 1, name: "草蛇", hp: 12, attack: 5, range: 0, speed: 1.2, row: "front" },
  m("wolf", 2, 6, "野狼", 24, 6, 1.4),
  m("wild_boar", 2, 6, "山豬", 36, 7, 1.1),
  m("cave_spider", 2, 6, "洞穴蜘蛛", 22, 6, 1.3),
  m("mushroom_imp", 2, 6, "蘑菇小妖", 26, 5, 0.9, { range: 20, row: "back" }),
  m("raven", 2, 6, "烏鴉群", 18, 6, 1.7),
  m("mud_crab", 2, 6, "泥蟹", 40, 6, 0.7),
  m("bandit", 3, 12, "山賊", 48, 9, 1.2),
  m("bog_troll", 3, 12, "沼澤巨魔", 80, 11, 0.7, { heal: 3 }),
  m("gargoyle", 3, 12, "石像鬼", 60, 9, 1.1, { night: 1.4 }),
  m("fire_salamander", 3, 12, "火蠑螈", 50, 11, 1.0, { range: 15, row: "back" }),
  m("giant_hornet", 3, 12, "巨型虎頭蜂", 40, 12, 1.7),
  m("shadow_wisp", 3, 12, "暗影鬼火", 42, 10, 1.4, { range: 25, row: "back", night: 1.5 }),
  m("ogre", 4, 18, "食人魔", 150, 16, 0.7),
  m("wyvern", 4, 18, "雙足飛龍", 120, 17, 1.5),
  m("iron_golem", 4, 18, "鐵甲魔像", 180, 14, 0.5),
  m("banshee", 4, 18, "女妖", 100, 15, 1.2, { range: 30, row: "back", night: 1.4 }),
  m("dire_bear", 4, 18, "恐熊", 160, 16, 0.9),
  m("basilisk", 4, 18, "蛇蜥", 130, 18, 0.8),
];
const MONSTER_BY_ID = new Map(CAMP_MONSTERS.map((x) => [x.id, x]));

/** The raid numbers of a camp monster of its own (null: one of the first four, which fight as the big world's FOES). */
export function campFoe(id: string): CampFoe | null {
  const x = MONSTER_BY_ID.get(id);
  return x?.name ? { name: x.name, hp: x.hp!, attack: x.attack!, range: x.range ?? 0, speed: x.speed!, row: x.row ?? "front", night: x.night, heal: x.heal } : null;
}

/** A monster's kind of: 精英 (tougher), 毒, 火, 冰 (each hits harder its own way; the Mac tints them). */
export type MonsterVariant = "elite" | "poison" | "fire" | "ice";
export const MONSTER_VARIANTS: Record<MonsterVariant, { name: string; hp: number; attack: number }> = {
  elite: { name: "精英", hp: 1.6, attack: 1.6 },
  poison: { name: "毒", hp: 1.1, attack: 1.25 },
  fire: { name: "火", hp: 1, attack: 1.35 },
  ice: { name: "冰", hp: 1.25, attack: 1.15 },
};
/** The chance a raiding monster is a variant: more the higher the race level. */
export function variantChance(raceLevel: number): number {
  return Math.min(0.3, 0.05 + 0.01 * Math.max(0, raceLevel));
}

/** The level bosses (DESKTOP.md §10.0): one at every ten race levels, coming with each raid until the camp beats it. */
export interface CampBoss extends CampFoe {
  id: string;
  level: number;
}
const BOSSES: readonly Omit<CampBoss, "level">[] = [
  { id: "slime_king", name: "史萊姆王", hp: 420, attack: 17, range: 0, speed: 0.5, row: "front", heal: 10 },
  { id: "troll_chief", name: "巨魔酋長", hp: 900, attack: 26, range: 0, speed: 0.7, row: "front", heal: 8 },
  { id: "elder_wyvern", name: "遠古飛龍", hp: 1600, attack: 38, range: 20, speed: 1.2, row: "front" },
];
export const BOSS_EVERY = 10;

/** The boss of race level `level` (10, 20, 30, …; past 30 the elder wyvern again, half as strong again each time). */
export function campBoss(level: number): CampBoss {
  const k = Math.max(1, Math.floor(level / BOSS_EVERY));
  const base = BOSSES[Math.min(k, BOSSES.length) - 1]!;
  const more = 1.5 ** Math.max(0, k - BOSSES.length);
  return { ...base, level, hp: Math.round(base.hp * more), attack: Math.round(base.attack * more) };
}

/**
 * How strong the camp is for its raids (2026-10-17: a race level alone wiped out camps whose gear had not caught up): the
 * race level, but no more than its residents' gear stands for — 1.5 levels for each point of their average gearPower
 * (the pieces they wear, added up). Bare residents meet the first tier only; a camp in full first-tier gear the third.
 */
export function raidRaceLevel(raceLevel: number, averageGear: number): number {
  return Math.max(1, Math.min(raceLevel, 1 + Math.floor(Math.max(0, averageGear) * 1.5)));
}

/** At most this share of the residents at home fall in one raid (at least one may); the rest come out of it hurt. */
export const RAID_MAX_FALLEN = 0.05;
/** A raid the monsters win carries off this share of these. */
export const RAID_PLUNDER = 0.05;
export const RAID_PLUNDERED = ["log", "stone", "scrap_iron"] as const;

/** The boss a raid brings now: the lowest of the ten-levels reached not yet beaten (null: none). */
export function bossDue(raceLevel: number, beaten: readonly number[]): number | null {
  for (let level = BOSS_EVERY; level <= raceLevel; level += BOSS_EVERY) if (!beaten.includes(level)) return level;
  return null;
}

/** What beating a boss brings (DESKTOP.md §10.0): rare materials, more for the later ones. */
export function bossLoot(level: number): Record<string, number> {
  const k = Math.max(1, Math.floor(level / BOSS_EVERY));
  const own: Record<string, Record<string, number>> = {
    slime_king: { royal_gel: 3, slime_crown: 1 },
    troll_chief: { chief_tusk: 2, war_totem: 1 },
    elder_wyvern: { elder_scale: 3, dragon_heart: 1 },
  };
  return { crystal_shard: 6 * k, amber: 3 * k, leather_strap: 4 * k, scrap_iron: 20 * k, ...own[campBoss(level).id] };
}

/** No raids on a camp smaller than this (the first monsters wait until there is someone to fight them). */
export const RAID_MIN_RESIDENTS = 10;

export interface RaidPlan {
  /** Which raid of the camp (0, 1, 2…). */
  index: number;
  at: number;
  monsters: { id: string; count: number; variant?: MonsterVariant }[];
  /** A level boss with them (the race level it belongs to). */
  boss?: number;
}

/** When raid number `index` comes: every `raidEveryMinutes`, give or take 30%. */
export function raidTime(race: string, campSeed: number, startedAt: number, index: number): number {
  const every = raceRules(race).raidEveryMinutes * MINUTE;
  const random = randomFrom(hashString(`${campSeed}|raid-time|${index}`));
  return startedAt + (index + 1) * every + Math.floor((random() * 0.6 - 0.3) * every);
}

/** The first raid that comes after `time`. */
export function nextRaidIndex(race: string, campSeed: number, startedAt: number, time: number): number {
  const every = raceRules(race).raidEveryMinutes * MINUTE;
  let index = Math.max(0, Math.floor((time - startedAt) / every) - 2);
  while (raidTime(race, campSeed, startedAt, index) <= time) index++;
  return index;
}

/**
 * What comes on raid `index`, for a camp with `residents` living at home then (null when the camp is too small and it
 * passes by). A bigger camp draws bigger raids, and from 60 residents the stronger monsters come too; a higher race level
 * (big world) brings more of them, of later tiers, more often variants, and the level boss not yet beaten (`beaten`).
 */
export function planRaid(race: string, campSeed: number, startedAt: number, index: number, residents: number, raceLevel = 1, beaten: readonly number[] = []): RaidPlan | null {
  if (residents < RAID_MIN_RESIDENTS) return null;
  const random = randomFrom(hashString(`${campSeed}|raid|${index}`));
  const kinds = CAMP_MONSTERS.filter((x) => x.from <= raceLevel && (x.tier > 1 || x.level <= (residents >= 60 ? 2 : 1)));
  const total = Math.min(raceLevel > 1 ? 16 : 12, 2 + Math.floor(residents / 30) + Math.floor(Math.max(0, raceLevel) / 6) + Math.floor(random() * 3));
  const counts = new Map<string, number>();
  // (the variants from a draw of their own, so the kinds and counts stay as they were for a camp of race level 1)
  const odd = randomFrom(hashString(`${campSeed}|raid-variant|${index}`));
  const variants = Object.keys(MONSTER_VARIANTS) as MonsterVariant[];
  for (let i = 0; i < total; i++) {
    const kind = kinds[Math.floor(random() * kinds.length)]!;
    const variant = raceLevel > 1 && odd() < variantChance(raceLevel) ? variants[Math.floor(odd() * variants.length)]! : "";
    const key = `${kind.id}|${variant}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  // (the boss comes with the first raid of each day (Taipei) until beaten, not with every raid)
  const at = raidTime(race, campSeed, startedAt, index);
  const firstToday = index === 0 || taipeiDay(new Date(at)) !== taipeiDay(new Date(raidTime(race, campSeed, startedAt, index - 1)));
  const boss = firstToday ? bossDue(raceLevel, beaten) : null;
  return {
    index,
    at,
    monsters: [...counts].map(([key, count]) => {
      const [id, variant] = key.split("|") as [string, MonsterVariant | ""];
      return variant ? { id, count, variant } : { id, count };
    }),
    ...(boss ? { boss } : {}),
  };
}
