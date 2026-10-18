/**
 * What the camp fights with and what monsters leave behind (the Mac's character manifests and mac/Resources/Animals,
 * mac/Sources/GoblinCamp/Materials.swift). Only the server fights (raids and the big world); the Mac plays the result.
 */
import { GEAR_ATTACK_PER_MIGHT, GEAR_HP_PER_HEALTH, type Resident as Fighter } from "../world/battle.ts";
import { TERRAIN_BREEDS } from "../world/details.ts";
import { gearBonus, gearMax, gearRule, type GearItem, type GearSlot } from "./gear.ts";

/** A breed's fighting stats, per race (might and health as multiples of a plain goblin; speed ×). Missing = 1 / 3 / 1. */
const PLAIN_STATS: Record<string, Record<string, { might?: number; health?: number; speed?: number }>> = {
  goblin: {
    common: {},
    scout: { speed: 1.35, might: 0.6, health: 2 },
    brute: { speed: 0.8, might: 1.6, health: 5 },
    sage: { speed: 0.95, might: 0.8 },
    golden: { speed: 1.1, might: 1.2, health: 4 },
    half_gob: { speed: 1, might: 1.15, health: 4 },
    half_mix: { speed: 1.05, might: 1, health: 3.5 },
    half_hum: { speed: 1, might: 0.9, health: 3 },
  },
  elf: {
    common: { might: 1.3, health: 3.5 },
    scout: { speed: 1.3, might: 1.2, health: 2.5 },
    brute: { speed: 0.8, might: 1.8, health: 6 },
    sage: { speed: 0.95, might: 1 },
    golden: { speed: 1.1, might: 1.5, health: 5 },
    half_gob: { speed: 1.05, might: 1.4, health: 4 },
    half_mix: { speed: 1.1, might: 1.5, health: 4.5 },
    half_hum: { speed: 1.05, might: 2, health: 7 },
  },
  undead: {
    common: { might: 1.1, health: 3 },
    scout: { speed: 1.4, might: 0.8, health: 2 },
    brute: { speed: 0.8, might: 1.7, health: 6 },
    sage: { speed: 1, might: 0.9, health: 2.5 },
    golden: { speed: 1.1, might: 1.5, health: 5 },
    half_gob: { speed: 1, might: 1.5, health: 5 },
    half_mix: { speed: 1.1, might: 1.4, health: 4 },
    half_hum: { speed: 1.2, might: 1.2, health: 3.5 },
  },
  // (mac/tools/make_beast.py BREEDS)
  beast: {
    common: { might: 1.2, health: 3.5 },
    scout: { speed: 1.4, might: 1, health: 2.5 },
    brute: { speed: 0.75, might: 2, health: 7 },
    sage: { speed: 0.95, might: 1, health: 3 },
    golden: { speed: 1.15, might: 1.7, health: 6 },
    half_gob: { speed: 1.1, might: 1.9, health: 6.5 },
    half_mix: { speed: 1.15, might: 1.6, health: 5 },
    half_hum: { speed: 1.1, might: 1.4, health: 4 },
  },
};

/** With each race's 14 terrain breeds (world/details.ts TERRAIN_BREEDS): its common's stats, × theirs. */
export const BREED_STATS: Record<string, Record<string, { might?: number; health?: number; speed?: number }>> = Object.fromEntries(
  Object.entries(PLAIN_STATS).map(([race, breeds]) => {
    const common = { might: 1, health: 3, speed: 1, ...breeds.common };
    const terrain = Object.entries(TERRAIN_BREEDS).map(([d, t]) => [
      `d_${d}`,
      { might: common.might * (t.stats.might ?? 1), health: common.health * (t.stats.health ?? 1), speed: common.speed * (t.stats.speed ?? 1) },
    ]);
    return [race, { ...breeds, ...Object.fromEntries(terrain) }];
  }),
);

/** How a race fights as a whole (elves shoot from the back). */
export const RACE_RANGE: Record<string, number> = { goblin: 0, elf: 34, undead: 0, beast: 0 };

/**
 * A resident as a fighter for the battle rules (world/battle.ts), with what it wears: weapon and gauntlets add to its
 * blows, armour to its health, the shield turns blows aside, reach and speed carry over. A worn-out piece (under a
 * quarter) works at half strength, as on the Mac.
 */
export function residentAsFighter(
  race: string,
  resident: { id: number; breed: string; gear?: Partial<Record<GearSlot, GearItem>> | null },
  name = "",
): Fighter {
  const stats = BREED_STATS[race]?.[resident.breed] ?? {};
  let might = 0, health = 0, block = 0, speed = 0, reach = 0;
  for (const item of Object.values(resident.gear ?? {})) {
    const rule = item && gearRule(item.id);
    if (!rule || !item) continue;
    const k = (item.left / gearMax(item) < 0.25 ? 0.5 : 1) * gearBonus(item); // (★ refined, +強化: stronger)
    might += (rule.might ?? 0) * k;
    health += (rule.health ?? 0) * k;
    block += (rule.block ?? 0) * k;
    speed += (rule.speed ?? 0) * k;
    reach = Math.max(reach, rule.reach ?? 0);
  }
  return {
    id: String(resident.id),
    name,
    breed: resident.breed,
    might: stats.might ?? 1,
    health: stats.health ?? 3,
    gearHp: health * GEAR_HP_PER_HEALTH,
    speed: (stats.speed ?? 1) * (1 + speed),
    gearAttack: might * GEAR_ATTACK_PER_MIGHT,
    gearReach: reach,
    gearGuard: block,
  };
}

export interface DropRule {
  id: string;
  chance: number;
  min: number;
  max: number;
}

/** What each camp monster may drop when it falls. */
export const MONSTER_DROPS: Record<string, DropRule[]> = {
  slime: [
    { id: "slime_goo", chance: 0.85, min: 1, max: 3 },
    { id: "slime_core", chance: 0.3, min: 1, max: 1 },
    { id: "elastic_gel", chance: 0.22, min: 1, max: 2 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  giant_rat: [
    { id: "rat_fang", chance: 0.75, min: 1, max: 2 },
    { id: "rat_pelt", chance: 0.5, min: 1, max: 1 },
    { id: "rat_tail", chance: 0.3, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.03, min: 1, max: 1 },
  ],
  bat: [
    { id: "bat_wing", chance: 0.65, min: 1, max: 2 },
    { id: "bat_fang", chance: 0.4, min: 1, max: 1 },
    { id: "night_dust", chance: 0.2, min: 1, max: 1 },
    { id: "night_heart", chance: 0.03, min: 1, max: 1 },
  ],
  frog: [
    { id: "frog_skin", chance: 0.7, min: 1, max: 2 },
    { id: "frog_leg", chance: 0.45, min: 1, max: 2 },
    { id: "sticky_tongue", chance: 0.25, min: 1, max: 1 },
    { id: "golden_frog_eye", chance: 0.03, min: 1, max: 1 },
  ],
  // the later tiers (DESKTOP.md §10.0): from their Mac manifests (mac/tools/make_monsters_more.py)
  horn_beetle: [
    { id: "beetle_shell", chance: 0.75, min: 1, max: 2 },
    { id: "beetle_horn", chance: 0.35, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  grass_snake: [
    { id: "snake_skin", chance: 0.75, min: 1, max: 2 },
    { id: "snake_fang", chance: 0.35, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  wolf: [
    { id: "wolf_pelt", chance: 0.7, min: 1, max: 2 },
    { id: "wolf_fang", chance: 0.4, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.05, min: 1, max: 1 },
  ],
  wild_boar: [
    { id: "boar_hide", chance: 0.7, min: 1, max: 2 },
    { id: "boar_tusk", chance: 0.4, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.05, min: 1, max: 1 },
  ],
  cave_spider: [
    { id: "spider_silk", chance: 0.75, min: 1, max: 3 },
    { id: "venom_sac", chance: 0.35, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  mushroom_imp: [
    { id: "spore_cap", chance: 0.75, min: 1, max: 2 },
    { id: "glow_spore", chance: 0.35, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  raven: [
    { id: "black_feather", chance: 0.8, min: 1, max: 3 },
    { id: "raven_eye", chance: 0.25, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  mud_crab: [
    { id: "crab_shell", chance: 0.75, min: 1, max: 2 },
    { id: "crab_claw", chance: 0.4, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
  ],
  bandit: [
    { id: "stolen_coin", chance: 0.7, min: 1, max: 3 },
    { id: "bandit_mask", chance: 0.3, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.05, min: 1, max: 1 },
  ],
  bog_troll: [
    { id: "troll_moss", chance: 0.7, min: 1, max: 2 },
    { id: "troll_tooth", chance: 0.35, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  gargoyle: [
    { id: "stone_wing", chance: 0.7, min: 1, max: 2 },
    { id: "gargoyle_eye", chance: 0.25, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  fire_salamander: [
    { id: "salamander_scale", chance: 0.7, min: 1, max: 2 },
    { id: "ember_gland", chance: 0.3, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  giant_hornet: [
    { id: "hornet_stinger", chance: 0.7, min: 1, max: 2 },
    { id: "royal_jelly", chance: 0.25, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  shadow_wisp: [
    { id: "shadow_essence", chance: 0.65, min: 1, max: 2 },
    { id: "wisp_flame", chance: 0.3, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  ogre: [
    { id: "ogre_hide", chance: 0.7, min: 1, max: 2 },
    { id: "ogre_club", chance: 0.25, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.05, min: 1, max: 1 },
  ],
  wyvern: [
    { id: "wyvern_scale", chance: 0.7, min: 1, max: 2 },
    { id: "wyvern_wing", chance: 0.3, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  iron_golem: [
    { id: "iron_plate", chance: 0.75, min: 1, max: 2 },
    { id: "golem_core", chance: 0.25, min: 1, max: 1 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  banshee: [
    { id: "ghost_veil", chance: 0.65, min: 1, max: 2 },
    { id: "banshee_tear", chance: 0.25, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
  dire_bear: [
    { id: "bear_pelt", chance: 0.7, min: 1, max: 2 },
    { id: "bear_claw", chance: 0.35, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.05, min: 1, max: 1 },
  ],
  basilisk: [
    { id: "basilisk_scale", chance: 0.7, min: 1, max: 2 },
    { id: "basilisk_eye", chance: 0.25, min: 1, max: 1 },
    { id: "night_heart", chance: 0.04, min: 1, max: 1 },
  ],
};

/** Odds and ends any monster may leave besides its own drops. */
export const SCRAP_DROPS: DropRule[] = [
  { id: "scrap_rag", chance: 0.55, min: 1, max: 2 },
  { id: "scrap_wood", chance: 0.5, min: 1, max: 3 },
  { id: "scrap_iron", chance: 0.45, min: 1, max: 2 },
];
