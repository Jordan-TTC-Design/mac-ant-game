/**
 * How many may go on one expedition, and the food carried along (server/WORLD.md §19). A party is small at first (by race,
 * growing with the race's level); rations taken along let more go, and a few foods make the whole party stronger. Food
 * is gathered: the held cells give it by their ground, beaten foes drop it, and the camp's farm grows it (camp/production.ts).
 */
import { foodScale } from "../camp/food.ts";
import type { FightBoosts } from "./battle.ts";

/** How many may go at race level 1; one more for every level after. */
export const PARTY_BASE: Record<string, number> = { goblin: 6, undead: 5, elf: 4 };
export const PARTY_MAX = 30;

export function partyCap(race: string, level: number): number {
  return Math.min(PARTY_MAX, (PARTY_BASE[race] ?? 6) + Math.max(0, level - 1));
}

/** Rations: every RATIONS_PER_EXTRA taken lets one more go (up to half the cap again). */
export const RATIONS_PER_EXTRA = 2;
export const RATIONS: Record<string, string> = { ration_bread: "乾糧麵包", ration_fish: "魚乾", ration_berry: "莓果乾", ration_jerky: "肉乾" };

/** Foods that make the whole party stronger; one for every five who go. */
export const BOOST_FOODS: Record<string, { name: string; boost: keyof FightBoosts; food: string; what: string }> = {
  food_meat: { name: "烤肉", boost: "meat", food: "meat", what: "攻擊 +20%" },
  food_cheese: { name: "起司", boost: "cheese", food: "cheese", what: "受到的傷害 −20%" },
  food_carrot: { name: "胡蘿蔔", boost: "carrot", food: "carrot", what: "走路快 15%，先出手" },
  food_honey: { name: "蜂蜜", boost: "honey", food: "honey", what: "血量 +20%" },
};

/**
 * 道具 (2026-09-29): made in the workshop, mostly from what camp raids leave (camp/gear.ts has the gear); kept in the store
 * like food and taken along the same way, one for every five who go. `unlock`: a quest (camp/quests.ts) opens the recipe.
 */
export interface ItemRule {
  id: string;
  name: string;
  cost: Record<string, number>;
  boost: keyof FightBoosts;
  what: string;
  unlock?: string;
}
export const ITEMS: readonly ItemRule[] = [
  { id: "item_bandage", name: "草藥繃帶", cost: { scrap_rag: 2, frog_leg: 1 }, boost: "bandage", what: "受到的傷害 −10%" },
  { id: "item_tonic", name: "蜂王漿", cost: { royal_jelly: 1, food_honey: 1 }, boost: "tonic", what: "攻擊 +10%、血量 +10%" },
  { id: "item_sticky", name: "黏黏彈", cost: { sticky_tongue: 2, slime_goo: 2 }, boost: "sticky", what: "敵人慢 25%（我方先出手）", unlock: "raids_100" },
  { id: "item_charm", name: "幸運符", cost: { golden_frog_eye: 1, shiny_bead: 1 }, boost: "luck", what: "打贏巢穴的掉落 +50%", unlock: "lairs_10" },
  { id: "item_lantern", name: "夜光燈籠", cost: { night_heart: 1, bat_wing: 2, scrap_iron: 1 }, boost: "lantern", what: "晚上打黑暗生物，牠們不會變強", unlock: "boss_1" },
];
const ITEM_BY_ID = new Map(ITEMS.map((i) => [i.id, i]));
export function itemRule(id: string): ItemRule | undefined {
  return ITEM_BY_ID.get(id);
}
/** The items as the boosts a party can take along (with the foods: planSupplies). */
export const BOOST_ITEMS: Record<string, { name: string; boost: keyof FightBoosts; what: string }> = Object.fromEntries(ITEMS.map((i) => [i.id, { name: i.name, boost: i.boost, what: i.what }]));

export const FOOD_NAMES: Record<string, string> = {
  ...RATIONS,
  ...Object.fromEntries(Object.entries(BOOST_FOODS).map(([id, f]) => [id, f.name])),
  ...Object.fromEntries(ITEMS.map((i) => [i.id, i.name])),
};
export const isFood = (id: string) => id in FOOD_NAMES;

/** How many of a boost food a party of `size` needs. */
export const boostCost = (size: number) => Math.max(1, Math.ceil(size / 5));

/** What a camp is given when it first opens the big world. */
export const OPENING_FOOD: Record<string, number> = { ration_bread: 5 };

export interface SuppliesPlan {
  /** Who may go without rations, and with the rations taken. */
  cap: number;
  extra: number;
  most: number;
  /** What is taken from the store. */
  spent: Record<string, number>;
  boosts: FightBoosts;
  /** Why it cannot go as asked (null: it can). */
  problem: string | null;
}

/**
 * What taking `supplies` (food id → how many) along with a party of `size` means: how many may go, what is eaten, and
 * the boosts (a race's taste counts: elves get nothing from meat). `store` is what the camp has.
 */
export function planSupplies(race: string, level: number, size: number, supplies: Record<string, number>, store: Record<string, number>, bonus = 0): SuppliesPlan {
  const cap = partyCap(race, level) + bonus;
  const spent: Record<string, number> = {};
  const boosts: FightBoosts = {};
  let problem: string | null = null;
  const rations = Object.entries(supplies).filter(([id, n]) => id in RATIONS && n > 0);
  const extra = Math.min(
    Math.floor(cap / 2),
    Math.floor(rations.reduce((sum, [, n]) => sum + n, 0) / RATIONS_PER_EXTRA),
  );
  // only the rations needed are eaten
  let need = Math.max(0, Math.min(extra, size - cap)) * RATIONS_PER_EXTRA;
  for (const [id, n] of rations) {
    const take = Math.min(n, need);
    if (take > 0) spent[id] = take;
    need -= take;
  }
  for (const [id, food] of Object.entries(BOOST_FOODS)) {
    if (!supplies[id]) continue;
    spent[id] = boostCost(size);
    boosts[food.boost] = foodScale(race, food.food);
  }
  for (const [id, item] of Object.entries(BOOST_ITEMS)) {
    if (!supplies[id]) continue;
    spent[id] = boostCost(size);
    boosts[item.boost] = 1;
  }
  for (const [id, n] of Object.entries(spent)) {
    if ((store[id] ?? 0) < n) problem = `${FOOD_NAMES[id] ?? id}不夠（要 ${n}，倉庫有 ${store[id] ?? 0}）。`;
  }
  if (size > cap + extra) problem = extra < Math.floor(cap / 2) ? `一次最多派 ${cap + extra} 隻；多帶乾糧可以多派。` : `一次最多派 ${cap + extra} 隻（升級後可以派更多）。`;
  return { cap, extra, most: cap + extra, spent, boosts, problem };
}
