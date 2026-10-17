/**
 * Special residents and the visitors who would like to move in (DESKTOP.md §10.0, 2026-10-17). Twice a day someone may come
 * to the camp's gate — a resident of a rarer breed, or (from the race level that opens it) one of the six specials — and
 * waits two hours. Taking them in costs a welcome present of materials; a full camp first sends someone away. When they come
 * and who they are follow from the camp's seed and the day, so the server keeps only the answers.
 */
import { hashString, randomFrom } from "../world/random.ts";
import { taipeiDay } from "./merchant.ts";
import { TERRAIN_BREEDS, terrainBreedDetail } from "../world/details.ts";

const HOUR = 3_600_000;

/** The six specials: the race level that opens each, and what it does while at home. */
export type SpecialRole = "healer" | "champion" | "artisan" | "beastmaster" | "bard" | "sentinel";
export interface SpecialResident {
  id: SpecialRole;
  /** The race level (big world) from which they may come. */
  level: number;
  names: Record<string, string>;
  /** What they do, for the devices to show. */
  effect: string;
}
export const SPECIAL_RESIDENTS: readonly SpecialResident[] = [
  { id: "healer", level: 8, names: { goblin: "巫醫", elf: "德魯伊", undead: "死靈醫者" }, effect: "身邊的居民回血快一半" },
  { id: "champion", level: 10, names: { goblin: "勇者", elf: "遊俠隊長", undead: "骷髏騎士" }, effect: "打突襲時大家攻擊 +10%" },
  { id: "artisan", level: 12, names: { goblin: "工匠", elf: "月工匠", undead: "骨匠" }, effect: "工地產量 +10%" },
  { id: "beastmaster", level: 14, names: { goblin: "馴獸師", elf: "馴鹿人", undead: "亡獸師" }, effect: "牧場產出 +15%" },
  { id: "bard", level: 16, names: { goblin: "鼓手", elf: "吟遊詩人", undead: "哀歌者" }, effect: "出生快 10%" },
  { id: "sentinel", level: 20, names: { goblin: "哨兵", elf: "守林人", undead: "守墓人" }, effect: "突襲的魔獸血少 10%" },
];
const SPECIAL_BY_ID = new Map(SPECIAL_RESIDENTS.map((s) => [s.id, s]));

export function specialResident(breed: string): SpecialResident | undefined {
  return SPECIAL_BY_ID.get(breed as SpecialRole);
}

/** The breeds' names by race (RACES.md), for messages; the specials' are in SPECIAL_RESIDENTS. */
const BREED_NAMES: Record<string, Record<string, string>> = {
  goblin: { common: "平民", scout: "敏捷", brute: "壯碩", sage: "聰明", golden: "金皮" },
  elf: { common: "林民", scout: "綠斗篷", brute: "樹皮", sage: "鹿角", golden: "銀月" },
  undead: { common: "骷髏", scout: "幽影", brute: "巨骨", sage: "鬼火", golden: "黑曜骨" },
};

/** A breed's name for this race ("居民" for one not known here). */
export function breedName(race: string, breed: string): string {
  const detail = terrainBreedDetail(breed);
  if (detail) return TERRAIN_BREEDS[detail].names[race] ?? "居民";
  return specialResident(breed)?.names[race] ?? BREED_NAMES[race]?.[breed] ?? "居民";
}

/** A special lives this many times a plain resident (the undead don't age anyway). */
export const SPECIAL_LIFESPAN = 3;

/** What the camp's specials at home add up to (each counts once, however many). */
export function specialEffects(breeds: Iterable<string>): { raidAttack: number; raidWeaken: number; siteYield: number; births: number } {
  const has = new Set(breeds);
  return {
    raidAttack: has.has("champion") ? 0.1 : 0,
    raidWeaken: has.has("sentinel") ? 0.1 : 0,
    siteYield: has.has("artisan") ? 0.1 : 0,
    births: has.has("bard") ? 0.1 : 0,
  };
}

/** A visitor at the gate. */
export interface CampVisitor {
  /** "<day>#<slot>": answered once. */
  id: string;
  breed: string;
  special: boolean;
  arrives: string;
  leaves: string;
  /** The welcome present they ask for (materials). */
  fee: Record<string, number>;
}

/** Visits a day, the hours they may come in (Taipei), and how long they wait. */
export const VISIT_SLOTS = 2;
const VISIT_FROM_HOUR = 10;
const VISIT_TO_HOUR = 20;
export const VISIT_HOURS = 2;
/** The chance a slot brings someone (the 好客 talent adds to it), and that it is a special when one is open and missing. */
const VISIT_CHANCE = 0.7;
const SPECIAL_CHANCE = 0.25;
const PLAIN_BREEDS: readonly [string, number][] = [["scout", 40], ["brute", 35], ["sage", 20], ["golden", 5]];

const FEES: Record<string, Record<string, number>> = {
  scout: { log: 30, stone: 15 },
  brute: { log: 30, stone: 15 },
  sage: { log: 40, stone: 30, ration_jerky: 5 },
  golden: { log: 120, stone: 80, crystal_shard: 2 },
  special: { log: 200, stone: 150, crystal_shard: 6, ration_jerky: 10 },
};

/** A visitor's welcome present, less the 好客 talent's share (`host`, 0…1). */
export function visitorFee(breed: string, host = 0): Record<string, number> {
  const base = FEES[specialResident(breed) ? "special" : breed] ?? FEES.scout!;
  return Object.fromEntries(Object.entries(base).map(([id, n]) => [id, Math.max(1, Math.round(n * (1 - Math.min(0.9, host))))]));
}

/**
 * Who is at the gate at `at` (null: nobody): `raceLevel` opens the specials, `have` are the breeds already at home (a special
 * comes only when the camp has none of it), `host` the 好客 talent.
 */
export function visitorAt(campSeed: number, at: Date, raceLevel: number, have: ReadonlySet<string>, host = 0, more = 0): CampVisitor | null {
  const day = taipeiDay(at);
  const midnight = Date.parse(`${day}T00:00:00+08:00`);
  for (let slot = 0; slot < VISIT_SLOTS; slot++) {
    const r = randomFrom(hashString(`${campSeed}|visitor|${day}|${slot}`));
    const span = (VISIT_TO_HOUR - VISIT_FROM_HOUR) / VISIT_SLOTS;
    const arrives = midnight + (VISIT_FROM_HOUR + span * slot + r() * (span - VISIT_HOURS)) * HOUR;
    const leaves = arrives + VISIT_HOURS * HOUR;
    const comes = r() < Math.min(1, VISIT_CHANCE + host + more); // (`more`: the 宴會廳)
    if (!comes || at.getTime() < arrives || at.getTime() >= leaves) continue;
    const open = SPECIAL_RESIDENTS.filter((s) => s.level <= raceLevel && !have.has(s.id));
    let breed: string;
    if (open.length && r() < SPECIAL_CHANCE) breed = open[Math.floor(r() * open.length)]!.id;
    else {
      let roll = r() * PLAIN_BREEDS.reduce((n, [, w]) => n + w, 0);
      breed = PLAIN_BREEDS.find(([, w]) => (roll -= w) < 0)?.[0] ?? "scout";
    }
    return { id: `${day}#${slot}`, breed, special: !!specialResident(breed), arrives: new Date(arrives).toISOString(), leaves: new Date(leaves).toISOString(), fee: visitorFee(breed, host) };
  }
  return null;
}

/** What reaching race level `level` opens in the camp (DESKTOP.md §10.0), for the 🎉 line. */
export function levelOpens(level: number): string[] {
  const out: string[] = [];
  const tier = [6, 12, 18].indexOf(level);
  if (tier >= 0) out.push(`第 ${tier + 2} 階的魔獸開始來襲`);
  if (level % 10 === 0) out.push("等級王要來了");
  if (level === 10) out.push("工地可以升到 4 級、商人每天多來一次");
  if (level === 20) out.push("工地可以升到 5 級");
  if (level === 15) out.push("商人會帶稀有貨");
  if (level === 25) out.push("商人會帶傳說貨");
  for (const s of SPECIAL_RESIDENTS) if (s.level === level) out.push(`${s.names.goblin}這類特殊居民可能來訪`);
  if (level % 3 === 0 && level <= 24) out.push("新一批營地裝飾");
  return out;
}
