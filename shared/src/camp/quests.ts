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
  // (2026-09-30, for the second batch of quests)
  /** Sites at their top level (3). */
  sitesTop: number;
  /** Everybody alive, at home, on held cells, on the road; and how many the home camp may hold (by race). */
  population: number;
  homeCap: number;
  /** Towns held; buildings on held cells at their top level (3). */
  towns: number;
  buildingsTop: number;
  /** Other camps' cells won in a fight. */
  pvpWins: number;
  /** How many different kinds of 初期魔王 beaten; how many different pieces of middle gear owned. */
  bossKinds: number;
  middleGearKinds: number;
  // (2026-10-05: focus and the ranch)
  /** The pomodoro's focus rounds done in all, and the most in one day (focus.ts). */
  focusRounds: number;
  focusBestDay: number;
  /** Animals kept in the ranch now (ranch.ts). */
  ranchAnimals: number;
}

export interface QuestReward {
  materials?: Record<string, number>;
  /** Gear ids: each goes into the store (and is handed out as usual). */
  gear?: string[];
  /** New residents born at home. */
  residents?: number;
  /** A limited decoration (decor-catalog.ts `limited: "quest"`), the camp's race's: race → decoration id. */
  decor?: Record<string, string>;
}

export interface Quest {
  id: string;
  chapter: "營地" | "大世界" | "夥伴" | "專注";
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

  // --- the second batch (2026-09-30): harder, for camps past the first thirty ---
  // 營地
  { id: "sites_6", chapter: "營地", title: "六座場地", text: "營地蓋好六個場地。", goal: (m) => n(m.sites, 6), reward: { residents: 5, materials: { log: 60, stone: 40 } }, after: "sites_4" },
  { id: "site_top_1", chapter: "營地", title: "精益求精", text: "把一個場地升到 3 級。", goal: (m) => n(m.sitesTop, 1), reward: { materials: { crystal_shard: 3, scrap_iron: 20 } }, after: "sites_4" },
  { id: "site_top_3", chapter: "營地", title: "三座滿級", text: "三個場地升到 3 級。", goal: (m) => n(m.sitesTop, 3), reward: { materials: { item_tonic: 3, crystal_shard: 5 } }, after: "site_top_1" },
  { id: "site_top_6", chapter: "營地", title: "場地大師", text: "六個場地都升到 3 級。", goal: (m) => n(m.sitesTop, 6), reward: { residents: 10, gear: ["commander_bracer"] }, after: "site_top_3" },
  { id: "farm_3", chapter: "營地", title: "養蜂人", text: "把田地升到 3 級。", goal: (m) => n(m.farm, 3), reward: { materials: { food_honey: 3, ration_bread: 15 } }, after: "farm_2" },
  { id: "farm_4", chapter: "營地", title: "起司工坊", text: "把田地升到 4 級。", goal: (m) => n(m.farm, 4), reward: { materials: { food_cheese: 5, ration_bread: 20 } }, after: "farm_3" },
  { id: "farm_5", chapter: "營地", title: "大豐收", text: "把田地升到 5 級。", goal: (m) => n(m.farm, 5), reward: { residents: 8, materials: { food_cheese: 10 } }, after: "farm_4" },
  { id: "armed_30", chapter: "營地", title: "三十把刀", text: "三十隻在家的居民拿著武器。", goal: (m) => n(m.armed, 30), reward: { gear: ["short_sword", "short_sword"], materials: { leather_strap: 5 } }, after: "armed_10" },
  { id: "armed_60", chapter: "營地", title: "全營皆兵", text: "六十隻在家的居民拿著武器。", goal: (m) => n(m.armed, 60), reward: { gear: ["long_sword", "spear"], materials: { scrap_iron: 40 } }, after: "armed_30" },
  { id: "geared_20", chapter: "營地", title: "精兵二十", text: "二十隻在家的居民各穿三件以上的裝備。", goal: (m) => n(m.wellGeared, 20), reward: { gear: ["leather_armor", "leather_boots", "leather_cap"] }, after: "geared_5" },
  { id: "geared_50", chapter: "營地", title: "精兵五十", text: "五十隻在家的居民各穿三件以上的裝備。", goal: (m) => n(m.wellGeared, 50), reward: { gear: ["iron_plate", "iron_helm"], materials: { crystal_shard: 5 } }, after: "geared_20" },
  { id: "gear_50", chapter: "營地", title: "堆滿倉庫", text: "身上加倉庫一共有五十件裝備。", goal: (m) => n(m.gearOwned, 50), reward: { materials: { leather_strap: 6, rat_pelt: 10 } }, after: "gear_20" },
  { id: "gear_100", chapter: "營地", title: "百件兵器", text: "身上加倉庫一共有一百件裝備。", goal: (m) => n(m.gearOwned, 100), reward: { gear: ["bat_lord_boots"], materials: { crystal_shard: 4 } }, after: "gear_50" },
  { id: "raids_300", chapter: "營地", title: "銅牆鐵壁", text: "打倒三百隻來營地搗亂的魔獸。", goal: (m) => n(m.raidKills, 300), reward: { residents: 5, materials: { slime_core: 3 } }, after: "raids_100" },
  { id: "raids_1000", chapter: "營地", title: "千魔不侵", text: "打倒一千隻來營地搗亂的魔獸。", goal: (m) => n(m.raidKills, 1000), reward: { residents: 10, materials: { golden_frog_eye: 2, night_heart: 1 } }, after: "raids_300" },
  { id: "home_full", chapter: "營地", title: "滿屋子", text: "營地曾經住滿（哥布林 300、精靈 180、死靈 240）。", goal: (m) => n(m.peak, m.homeCap), reward: { materials: { ration_jerky: 20, food_meat: 20 } }, after: "pop_120" },
  { id: "people_250", chapter: "營地", title: "大家族", text: "營地加上所有領地、路上的，一共有兩百五十隻居民。", goal: (m) => n(m.population, 250), reward: { materials: { crystal_shard: 4, food_cheese: 5 } }, after: "pop_120" },
  { id: "people_400", chapter: "營地", title: "一方之主", text: "營地加上所有領地、路上的，一共有四百隻居民。", goal: (m) => n(m.population, 400), reward: { materials: { crystal_shard: 8, item_tonic: 4 } }, after: "people_250" },
  // 大世界
  { id: "lairs_25", chapter: "大世界", title: "巢穴終結者", text: "打贏二十五個巢穴。", goal: (m) => n(m.lairsWon, 25), reward: { materials: { food_meat: 10, scrap_iron: 20, item_charm: 2 } }, after: "lairs_10" },
  { id: "lairs_50", chapter: "大世界", title: "五十戰", text: "打贏五十個巢穴。", goal: (m) => n(m.lairsWon, 50), reward: { gear: ["echo_bow"], materials: { crystal_shard: 6 } }, after: "lairs_25" },
  { id: "lairs_100", chapter: "大世界", title: "百戰百勝", text: "打贏一百個巢穴。", goal: (m) => n(m.lairsWon, 100), reward: { residents: 10, gear: ["dire_fang_blade"] }, after: "lairs_50" },
  { id: "cells_8", chapter: "大世界", title: "八格領地", text: "營地以外佔著八格。", goal: (m) => n(m.cells - 1, 8), reward: { materials: { ration_fish: 20, scrap_wood: 40 } }, after: "cells_4" },
  { id: "cells_12", chapter: "大世界", title: "十二格領地", text: "營地以外佔著十二格。", goal: (m) => n(m.cells - 1, 12), reward: { materials: { crystal_shard: 5, log: 80 } }, after: "cells_8" },
  { id: "cells_20", chapter: "大世界", title: "二十格領地", text: "營地以外佔著二十格。", goal: (m) => n(m.cells - 1, 20), reward: { residents: 10, materials: { stone: 100 } }, after: "cells_12" },
  { id: "region_4", chapter: "大世界", title: "城鎮的地基", text: "四格自己的格子連在一起（營地也算），就能蓋城鎮了。", goal: (m) => n(m.region, 4), reward: { materials: { scrap_wood: 60, scrap_iron: 30 } }, after: "region_3" },
  { id: "town_1", chapter: "大世界", title: "第一座城鎮", text: "在領地蓋好一座城鎮。", goal: (m) => n(m.towns, 1), reward: { residents: 8, materials: { food_cheese: 5 } }, after: "region_4" },
  { id: "region_8", chapter: "大世界", title: "八格一區", text: "八格自己的格子連在一起：一區可以有兩座城鎮了。", goal: (m) => n(m.region, 8), reward: { materials: { scrap_wood: 120, scrap_iron: 60, scrap_rag: 40 } }, after: "town_1" },
  { id: "town_2", chapter: "大世界", title: "雙城", text: "擁有兩座城鎮。", goal: (m) => n(m.towns, 2), reward: { residents: 10, materials: { crystal_shard: 5 } }, after: "region_8" },
  { id: "town_4", chapter: "大世界", title: "四城之主", text: "擁有四座城鎮。", goal: (m) => n(m.towns, 4), reward: { residents: 15, gear: ["crown_helm"] }, after: "town_2" },
  { id: "nest_3", chapter: "大世界", title: "三個繁殖巢", text: "在領地蓋好三個繁殖巢。", goal: (m) => n(m.nests, 3), reward: { residents: 5 }, after: "nest_1" },
  { id: "nest_6", chapter: "大世界", title: "處處生機", text: "在領地蓋好六個繁殖巢。", goal: (m) => n(m.nests, 6), reward: { residents: 10 }, after: "nest_3" },
  { id: "building_3", chapter: "大世界", title: "三棟建築", text: "領地上一共有三個建築。", goal: (m) => n(m.buildings, 3), reward: { materials: { log: 60, stone: 40 } }, after: "building_1" },
  { id: "building_top_1", chapter: "大世界", title: "高樓", text: "把一個領地建築升到 3 級。", goal: (m) => n(m.buildingsTop, 1), reward: { materials: { crystal_shard: 4 } }, after: "building_3" },
  { id: "building_top_3", chapter: "大世界", title: "建築師", text: "三個領地建築升到 3 級。", goal: (m) => n(m.buildingsTop, 3), reward: { residents: 8, materials: { amber: 2 } }, after: "building_top_1" },
  { id: "landmark_3", chapter: "大世界", title: "地標收藏", text: "佔著三個有地標的格子。", goal: (m) => n(m.landmarks, 3), reward: { materials: { crystal_shard: 4, shiny_bead: 2 } }, after: "landmark_1" },
  { id: "level_8", chapter: "大世界", title: "一方霸主", text: "種族等級到 8 級。", goal: (m) => n(m.raceLevel, 8), reward: { residents: 8 }, after: "level_5" },
  { id: "level_12", chapter: "大世界", title: "威震四方", text: "種族等級到 12 級。", goal: (m) => n(m.raceLevel, 12), reward: { residents: 12, gear: ["royal_gel_shield"] }, after: "level_8" },
  { id: "boss_6", chapter: "大世界", title: "魔王剋星", text: "打倒六隻初期魔王。", goal: (m) => n(m.bossKills, 6), reward: { gear: ["tusk_maul"], materials: { giant_bat_wing: 2 } }, after: "boss_3" },
  { id: "boss_12", chapter: "大世界", title: "屠魔者", text: "打倒十二隻初期魔王。", goal: (m) => n(m.bossKills, 12), reward: { residents: 10, gear: ["thick_hide_greaves", "toad_gloves"] }, after: "boss_6" },
  { id: "boss_all", chapter: "大世界", title: "魔王圖鑑", text: "六種初期魔王各打倒一次（嗜血巨蝠、狂暴巨狼、狂化史萊姆王、暴怒野豬王、狂化蛙王、盜賊頭目）。", goal: (m) => n(m.bossKinds, 6), reward: { materials: { crystal_shard: 8, dire_pelt: 2 } }, after: "boss_3" },
  { id: "bears_5", chapter: "大世界", title: "熊出沒", text: "打倒五隻洞穴熊。", goal: (m) => n(m.kills.bear ?? 0, 5), reward: { materials: { food_honey: 5, bear_pelt: 2 } }, after: "lairs_5" },
  { id: "spiders_10", chapter: "大世界", title: "撥開蛛網", text: "打倒十隻蜘蛛（巨蜘蛛、蜘蛛女王都算）。", goal: (m) => n((m.kills.giant_spider ?? 0) + (m.kills.spider_queen ?? 0), 10), reward: { materials: { venom_sac: 2, silk_thread: 4 } }, after: "lairs_5" },
  { id: "water_15", chapter: "大世界", title: "水邊的麻煩", text: "打倒十五隻水邊的怪物（河童、水蛇、水妖、巨蟹都算）。", goal: (m) => n((m.kills.kappa ?? 0) + (m.kills.water_snake ?? 0) + (m.kills.naiad ?? 0) + (m.kills.giant_crab ?? 0), 15), reward: { materials: { river_pearl: 2, kappa_shell: 2 } }, after: "lairs_5" },
  { id: "bandits_30", chapter: "大世界", title: "剿匪", text: "打倒三十個盜賊（攔路強盜、盜賊、飛刀手、盜賊頭目都算）。", goal: (m) => n((m.kills.robber ?? 0) + (m.kills.bandit ?? 0) + (m.kills.knife_thrower ?? 0) + (m.kills.bandit_boss ?? 0), 30), reward: { materials: { stolen_coin: 5, leather_strap: 4 } }, after: "lairs_5" },
  { id: "orcs_30", chapter: "大世界", title: "強獸人剋星", text: "打倒三十隻強獸人（步兵、弓手、隊長都算）。", goal: (m) => n((m.kills.orc_grunt ?? 0) + (m.kills.orc_archer ?? 0) + (m.kills.orc_chief ?? 0), 30), reward: { materials: { orc_tusk: 4, crude_blade: 3, war_banner: 1 } }, after: "lairs_5" },
  { id: "pvp_1", chapter: "大世界", title: "第一次攻城", text: "出征打贏另一個玩家的領地。", goal: (m) => n(m.pvpWins, 1), reward: { materials: { food_meat: 10, captain_badge: 1 } }, after: "lairs_5" },
  { id: "pvp_5", chapter: "大世界", title: "征服者", text: "打贏其他玩家的領地五次。", goal: (m) => n(m.pvpWins, 5), reward: { residents: 8, materials: { war_banner: 2 } }, after: "pvp_1" },
  // 專注 (focus.ts: the pomodoro's focus rounds that ran to the end, from the Mac or the phone)
  { id: "focus_1", chapter: "專注", title: "第一輪專注", text: "用番茄鐘專注完一輪（跳過的不算）。", goal: (m) => n(m.focusRounds, 1), reward: { materials: { ration_bread: 3, food_honey: 2 } } },
  { id: "focus_day4", chapter: "專注", title: "專心的一天", text: "一天裡專注完四輪。", goal: (m) => n(m.focusBestDay, 4), reward: { decor: { goblin: "g_tomatotower", elf: "e_moondial", undead: "u_hourglass" } }, after: "focus_1" },
  { id: "focus_20", chapter: "專注", title: "二十輪", text: "一共專注完二十輪。", goal: (m) => n(m.focusRounds, 20), reward: { residents: 3, materials: { crystal_shard: 2 } }, after: "focus_1" },
  { id: "focus_day6", chapter: "專注", title: "全神貫注", text: "一天裡專注完六輪。", goal: (m) => n(m.focusBestDay, 6), reward: { decor: { goblin: "g_goldthrone", elf: "e_glowtree", undead: "u_bonethrone" } }, after: "focus_day4" },
  { id: "focus_100", chapter: "專注", title: "百輪老手", text: "一共專注完一百輪。", goal: (m) => n(m.focusRounds, 100), reward: { residents: 8, materials: { crystal_shard: 6, amber: 2 } }, after: "focus_20" },
  { id: "ranch_8", chapter: "營地", title: "牧場主人", text: "牧場裡養著八隻動物。", goal: (m) => n(m.ranchAnimals, 8), reward: { decor: { goblin: "g_trophy", elf: "e_laurelarch", undead: "u_ghostbell" } } },
  // 夥伴
  { id: "friend_3", chapter: "夥伴", title: "三五好友", text: "有三位好友。", goal: (m) => n(m.friends, 3), reward: { materials: { food_honey: 5, food_cheese: 3 } }, after: "friend_1" },
  { id: "friend_5", chapter: "夥伴", title: "朋友遍天下", text: "有五位好友。", goal: (m) => n(m.friends, 5), reward: { residents: 5, materials: { item_tonic: 3 } }, after: "friend_3" },
  { id: "middle_gear_5", chapter: "夥伴", title: "收藏家", text: "擁有五種不同的中等裝備。", goal: (m) => n(m.middleGearKinds, 5), reward: { residents: 8, materials: { crystal_shard: 6 } }, after: "middle_gear" },
];

const BY_ID = new Map(QUESTS.map((q) => [q.id, q]));
export function questRule(id: string): Quest | undefined {
  return BY_ID.get(id);
}

/** Whether a quest shows yet: the first of a chain always, the rest once the one before was claimed. */
export function questShown(q: Quest, claimed: Record<string, unknown>): boolean {
  return !q.after || q.after in claimed;
}

/** The limited decorations a camp has earned: those of the quests whose rewards it took, for its race. */
export function decorEarned(claimed: Record<string, unknown>, race: string): Set<string> {
  const earned = new Set<string>();
  for (const id of Object.keys(claimed)) {
    const kind = BY_ID.get(id)?.reward.decor?.[race];
    if (kind) earned.add(kind);
  }
  return earned;
}
