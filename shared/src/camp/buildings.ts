/**
 * 營地建設 (ECONOMY.md §1.3, 2026-10-17): six great works besides the sites, three levels each, on no plot of their own. They
 * take mostly logs and stones (the camp's piles have nowhere else to go once the sites are up) and, higher up, the later
 * monsters' materials. One is built at a time; the 巧手 talent builds them sooner too.
 */
import { FARM_KEEP } from "./production.ts";

export type CampBuildingId = "wall" | "warehouse" | "clinic" | "training" | "banquet" | "watchtower";
export const CAMP_BUILDING_MAX = 3;

export interface CampBuildingRule {
  id: CampBuildingId;
  name: string;
  /** What each level gives, for the devices to show. */
  effect: string;
  /** Raising it to level 1, 2, 3: materials and hours. */
  costs: readonly [Record<string, number>, Record<string, number>, Record<string, number>];
  hours: readonly [number, number, number];
}

export const CAMP_BUILDINGS: readonly CampBuildingRule[] = [
  {
    id: "wall", name: "城牆", effect: "突襲的魔獸攻擊 −5%",
    costs: [{ log: 500, stone: 800 }, { log: 2000, stone: 3000, wolf_pelt: 20 }, { log: 6000, stone: 9000, iron_plate: 10 }],
    hours: [4, 12, 24],
  },
  {
    id: "warehouse", name: "大倉庫", effect: "糧食存得比較多",
    costs: [{ log: 400, stone: 200 }, { log: 1500, stone: 800, spider_silk: 20 }, { log: 5000, stone: 2500, dark_silk: 10 }],
    hours: [4, 12, 24],
  },
  {
    id: "clinic", name: "醫館", effect: "居民回血 +20%",
    costs: [{ log: 300, stone: 300, frog_skin: 20 }, { log: 1200, stone: 1200, troll_moss: 10 }, { log: 4000, stone: 4000, banshee_tear: 5 }],
    hours: [4, 12, 24],
  },
  {
    id: "training", name: "訓練場", effect: "居民打突襲時血量 +5%",
    costs: [{ log: 600, stone: 400 }, { log: 2500, stone: 1500, boar_tusk: 20 }, { log: 8000, stone: 5000, bear_claw: 10 }],
    hours: [4, 12, 24],
  },
  {
    id: "banquet", name: "宴會廳", effect: "來訪者多 10%；2 級起流浪商人多帶一樣",
    costs: [{ log: 500, stone: 300, food_honey: 20 }, { log: 2000, stone: 1200, royal_jelly: 5 }, { log: 6000, stone: 4000, naga_pearl: 5 }],
    hours: [4, 12, 24],
  },
  {
    id: "watchtower", name: "瞭望塔", effect: "等級王來的那次突襲，大家攻擊 +10%",
    costs: [{ log: 400, stone: 600 }, { log: 1600, stone: 2400, stone_wing: 10 }, { log: 5000, stone: 7000, wyvern_wing: 5 }],
    hours: [4, 12, 24],
  },
];
const BY_ID = new Map(CAMP_BUILDINGS.map((b) => [b.id, b]));

export function campBuilding(id: string): CampBuildingRule | undefined {
  return BY_ID.get(id as CampBuildingId);
}

/** A camp's buildings as the books keep them: id → level (0: the first being built) and when the one going up is done. */
export type CampBuildings = Partial<Record<CampBuildingId, { level: number; busyUntil?: string | null }>>;

export function buildingLevel(buildings: CampBuildings | null | undefined, id: CampBuildingId): number {
  return buildings?.[id]?.level ?? 0;
}

/** Most of each food the store keeps, by the 大倉庫's level. */
export const FOOD_KEEP_BY_WAREHOUSE = [FARM_KEEP, 40, 80, 150] as const;

/** What the camp's buildings do now (levels as built; one going up counts at its old level). */
export function buildingEffects(buildings: CampBuildings | null | undefined) {
  const lv = (id: CampBuildingId) => buildingLevel(buildings, id);
  return {
    /** Raiding monsters' attack × (1 − this). */
    raidMonsterAttack: 0.05 * lv("wall"),
    foodKeep: FOOD_KEEP_BY_WAREHOUSE[lv("warehouse")]!,
    /** Residents heal × (1 + this) (the Mac's). */
    heal: 0.2 * lv("clinic"),
    /** Defenders' hit points in a raid × (1 + this). */
    raidDefenderHp: 0.05 * lv("training"),
    /** Added to the chance a visitor comes (visitors.ts). */
    visitorChance: 0.1 * lv("banquet"),
    /** The wandering merchant brings one more swap (merchant.ts, as 精打細算 does). */
    merchantMore: lv("banquet") >= 2,
    /** Everyone's attack in a raid with a level boss × (1 + this). */
    bossAttack: 0.1 * lv("watchtower"),
  };
}

/** What raising a building from its level costs and takes (0: building it); null at the top. `build`: the 巧手 talent. */
export function buildingNext(id: CampBuildingId, level: number, build = 0): { cost: Record<string, number>; hours: number } | null {
  const rule = BY_ID.get(id);
  if (!rule || level >= CAMP_BUILDING_MAX) return null;
  return { cost: rule.costs[level]!, hours: rule.hours[level]! * (1 - Math.min(0.5, build)) };
}
