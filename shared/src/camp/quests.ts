/**
 * 任務 (server/CAMP.md §20): small goals for a camp's first days, each with a reward — materials, gear, new residents, or
 * the recipe of a 道具 (world/supplies.ts ITEMS). Progress is worked out from what the camp already is (the server's
 * `questMetrics`): nothing is counted twice and nothing has to be recorded but which rewards were taken.
 */

/** What the quests look at (the server works it out from the camp, its world and its friends). */
export interface QuestMetrics {
  /** The most the camp has ever had. */
  peak: number;
  /** Sites built (not the farm), each kind's level, the farm's level. */
  sites: number;
  siteLevels: Record<string, number>;
  farm: number;
  /** At home: how many hold a weapon, how many wear three pieces or more; every piece there is (worn or in the store). */
  armed: number;
  wellGeared: number;
  gearOwned: number;
  /** Owns a piece of the middle gear (made of what the 初期魔王 leave). */
  middleGear: boolean;
  /** Foes beaten, by kind (camp raids and the big world). */
  kills: Record<string, number>;
  raidKills: number;
  bossKills: number;
  worldOpen: boolean;
  /** Lairs beaten in the big world. */
  lairsWon: number;
  /** Held cells (the camp's own among them), nests built, buildings, landmarks held, the biggest region. */
  cells: number;
  nests: number;
  buildings: number;
  landmarks: number;
  region: number;
  raceLevel: number;
  friends: number;
  /** Has residents guarding a friend's cell now. */
  guarding: boolean;
}

export interface QuestReward {
  materials?: Record<string, number>;
  /** Gear ids: each goes into the store (and is handed out as usual). */
  gear?: string[];
  /** New residents born at home. */
  residents?: number;
}

export interface Quest {
  id: string;
  chapter: "營地" | "大世界" | "夥伴";
  title: string;
  text: string;
  /** How far along: [have, need]. */
  goal: (m: QuestMetrics) => [number, number];
  reward: QuestReward;
  /** Shown once this one's reward is taken (a chain); the first of each chain is always shown. */
  after?: string;
}

const n = (have: number, need: number): [number, number] => [Math.min(have, need), need];
const yes = (v: boolean): [number, number] => [v ? 1 : 0, 1];

export const QUESTS: readonly Quest[] = [
  // 營地
  { id: "site_1", chapter: "營地", title: "第一座場地", text: "在營地蓋好一個場地（田地不算）。", goal: (m) => n(m.sites, 1), reward: { materials: { log: 20, stone: 10 } } },
  { id: "lumber_2", chapter: "營地", title: "伐木工", text: "把伐木場升到 2 級。", goal: (m) => n(m.siteLevels.lumber ?? 0, 2), reward: { materials: { stone: 30, scrap_wood: 10 } }, after: "site_1" },
  { id: "farm_2", chapter: "營地", title: "小農夫", text: "把田地升到 2 級。", goal: (m) => n(m.farm, 2), reward: { materials: { food_carrot: 5, ration_bread: 5 } } },
  { id: "sites_4", chapter: "營地", title: "四座場地", text: "營地蓋好四個場地。", goal: (m) => n(m.sites, 4), reward: { materials: { scrap_rag: 20, scrap_wood: 20 } }, after: "lumber_2" },
  { id: "armed_1", chapter: "營地", title: "第一把武器", text: "讓一隻居民拿著武器。", goal: (m) => n(m.armed, 1), reward: { gear: ["wood_club", "wood_club"] } },
  { id: "armed_10", chapter: "營地", title: "武裝起來", text: "十隻在家的居民拿著武器。", goal: (m) => n(m.armed, 10), reward: { gear: ["bone_knife"], materials: { rat_pelt: 4 } }, after: "armed_1" },
  { id: "geared_5", chapter: "營地", title: "全副武裝", text: "五隻在家的居民各穿三件以上的裝備。", goal: (m) => n(m.wellGeared, 5), reward: { materials: { leather_strap: 2, rat_pelt: 5 } }, after: "armed_10" },
  { id: "gear_20", chapter: "營地", title: "工坊常客", text: "身上加倉庫一共有二十件裝備。", goal: (m) => n(m.gearOwned, 20), reward: { gear: ["leather_armor"] }, after: "geared_5" },
  { id: "raids_20", chapter: "營地", title: "擊退魔獸", text: "打倒二十隻來營地搗亂的魔獸。", goal: (m) => n(m.raidKills, 20), reward: { materials: { rat_fang: 6, rat_pelt: 3 } } },
  { id: "raids_100", chapter: "營地", title: "營地守衛", text: "打倒一百隻來營地搗亂的魔獸。解鎖道具「黏黏彈」。", goal: (m) => n(m.raidKills, 100), reward: { residents: 3, materials: { sticky_tongue: 2 } }, after: "raids_20" },
  { id: "pop_60", chapter: "營地", title: "人丁興旺", text: "營地曾經有六十隻居民。", goal: (m) => n(m.peak, 60), reward: { residents: 3 } },
  { id: "pop_120", chapter: "營地", title: "小聚落", text: "營地曾經有一百二十隻居民。", goal: (m) => n(m.peak, 120), reward: { residents: 5, materials: { ration_bread: 10 } }, after: "pop_60" },
  // 大世界
  { id: "world_open", chapter: "大世界", title: "走出營地", text: "開啟大世界，把營地放在地圖上。", goal: (m) => yes(m.worldOpen), reward: { materials: { ration_bread: 5, food_meat: 3 } } },
  { id: "lairs_1", chapter: "大世界", title: "第一場勝利", text: "出征打贏一個巢穴。", goal: (m) => n(m.lairsWon, 1), reward: { materials: { food_meat: 3, scrap_iron: 5 } }, after: "world_open" },
  { id: "lairs_5", chapter: "大世界", title: "巢穴獵人", text: "打贏五個巢穴。", goal: (m) => n(m.lairsWon, 5), reward: { gear: ["slingshot"] }, after: "lairs_1" },
  { id: "lairs_10", chapter: "大世界", title: "巢穴剋星", text: "打贏十個巢穴。解鎖道具「幸運符」。", goal: (m) => n(m.lairsWon, 10), reward: { materials: { golden_frog_eye: 1, shiny_bead: 1 } }, after: "lairs_5" },
  { id: "cells_2", chapter: "大世界", title: "第一格領地", text: "派人佔下營地以外的一格。", goal: (m) => n(m.cells - 1, 1), reward: { materials: { scrap_wood: 30, scrap_iron: 10, scrap_rag: 10 } }, after: "world_open" },
  { id: "nest_1", chapter: "大世界", title: "開枝散葉", text: "在領地蓋好一個繁殖巢。", goal: (m) => n(m.nests, 1), reward: { residents: 3 }, after: "cells_2" },
  { id: "cells_4", chapter: "大世界", title: "四格領地", text: "營地以外佔著四格。", goal: (m) => n(m.cells - 1, 4), reward: { materials: { ration_fish: 10 } }, after: "cells_2" },
  { id: "building_1", chapter: "大世界", title: "領地建築", text: "在領地蓋一個建築。", goal: (m) => n(m.buildings, 1), reward: { materials: { log: 30, stone: 10 } }, after: "cells_2" },
  { id: "landmark_1", chapter: "大世界", title: "地標主人", text: "佔下一個有地標的格子（車站、廟宇、大學…）。", goal: (m) => n(m.landmarks, 1), reward: { materials: { crystal_shard: 2 } }, after: "cells_2" },
  { id: "region_3", chapter: "大世界", title: "連成一片", text: "三格自己的格子連在一起（營地也算）。", goal: (m) => n(m.region, 3), reward: { materials: { food_cheese: 3 } }, after: "cells_4" },
  { id: "level_3", chapter: "大世界", title: "小有名氣", text: "種族等級到 3 級。", goal: (m) => n(m.raceLevel, 3), reward: { materials: { ration_jerky: 8 } }, after: "world_open" },
  { id: "level_5", chapter: "大世界", title: "遠近馳名", text: "種族等級到 5 級。", goal: (m) => n(m.raceLevel, 5), reward: { residents: 5 }, after: "level_3" },
  { id: "wolves_10", chapter: "大世界", title: "獵狼", text: "打倒十隻狼（野狼、狼王、巨狼都算）。", goal: (m) => n((m.kills.wolf ?? 0) + (m.kills.alpha_wolf ?? 0) + (m.kills.dire_wolf ?? 0), 10), reward: { materials: { leather_strap: 3 } }, after: "lairs_1" },
  { id: "boss_1", chapter: "大世界", title: "魔王殺手", text: "打倒一隻初期魔王（地圖上的 👑）。解鎖道具「夜光燈籠」。", goal: (m) => n(m.bossKills, 1), reward: { materials: { night_heart: 1, bat_wing: 2 } }, after: "lairs_5" },
  { id: "boss_3", chapter: "大世界", title: "魔王獵人", text: "打倒三隻初期魔王。", goal: (m) => n(m.bossKills, 3), reward: { gear: ["dire_pelt_armor"] }, after: "boss_1" },
  // 夥伴
  { id: "friend_1", chapter: "夥伴", title: "交個朋友", text: "加一位好友。", goal: (m) => n(m.friends, 1), reward: { materials: { food_honey: 2 } } },
  { id: "guard_1", chapter: "夥伴", title: "並肩作戰", text: "派居民去好友的格子幫忙守。", goal: (m) => yes(m.guarding), reward: { materials: { food_cheese: 2 } }, after: "friend_1" },
  { id: "middle_gear", chapter: "夥伴", title: "中等裝備", text: "擁有一件用初期魔王的材料做的中等裝備。", goal: (m) => yes(m.middleGear), reward: { residents: 5, materials: { item_tonic: 2 } }, after: "boss_1" },
];

const BY_ID = new Map(QUESTS.map((q) => [q.id, q]));
export function questRule(id: string): Quest | undefined {
  return BY_ID.get(id);
}

/** Whether a quest shows yet: the first of a chain always, the rest once the one before was claimed. */
export function questShown(q: Quest, claimed: Record<string, unknown>): boolean {
  return !q.after || q.after in claimed;
}
