/**
 * What each foe leaves when it falls (besides what its lair keeps: contents.ts `loot`), and one list of every material the
 * camp can hold, with the name and colour people see (the Mac's Animals manifests and Materials.swift, and the big world's
 * own). A rare drop is a real find: the workshop's better gear is made from them (camp/gear.ts).
 */
import { MONSTER_DROPS, type DropRule } from "../camp/combat.ts";
import type { Lair } from "./contents.ts";
import { between, seeded } from "./random.ts";

export interface MaterialInfo {
  name: string;
  /** `#rrggbb`, the little gem's colour on the Mac. */
  color: string;
}

/** Every material there is. The camp's own (from its home raids and odd finds) first, then the big world's. */
export const MATERIALS: Record<string, MaterialInfo> = {
  // odds and ends (Materials.swift)
  scrap_rag: { name: "碎布", color: "#d8c8a8" },
  scrap_wood: { name: "木片", color: "#a8743c" },
  scrap_iron: { name: "廢鐵", color: "#8a929e" },
  crystal_shard: { name: "碎晶", color: "#6ad8f0" },
  // the home camp's monsters (mac/Resources/Animals)
  slime_goo: { name: "黏液", color: "#68d078" },
  slime_core: { name: "史萊姆核心", color: "#3aa0d8" },
  elastic_gel: { name: "彈性凝膠", color: "#a8e8c0" },
  shiny_bead: { name: "閃亮黏珠", color: "#f0d040" },
  rat_fang: { name: "鼠牙", color: "#f0ead8" },
  rat_pelt: { name: "鼠皮", color: "#8a7a6a" },
  rat_tail: { name: "鼠尾", color: "#d89a9a" },
  sharp_claw: { name: "斷爪", color: "#c8c0b0" },
  golden_fur: { name: "金毛", color: "#f0c040" },
  bat_wing: { name: "蝙蝠翼", color: "#5a4a7a" },
  bat_fang: { name: "蝙蝠牙", color: "#e8e0f0" },
  night_dust: { name: "夜光粉", color: "#8a8af0" },
  night_heart: { name: "夜之心", color: "#6a3ad8" },
  frog_skin: { name: "蛙皮", color: "#6ab04a" },
  frog_leg: { name: "蛙腿", color: "#c8a878" },
  sticky_tongue: { name: "黏舌", color: "#e87a9a" },
  golden_frog_eye: { name: "金蛙眼", color: "#f0d020" },
  // the big world's (2026-09-28)
  wolf_pelt: { name: "狼皮", color: "#8a8a92" },
  wolf_fang: { name: "狼牙", color: "#f0ece0" },
  alpha_mane: { name: "狼王鬃毛", color: "#c0c8d8" },
  bear_pelt: { name: "熊皮", color: "#6a4a2a" },
  bear_claw: { name: "熊爪", color: "#3a3a3a" },
  boar_tusk: { name: "野豬獠牙", color: "#f0e0c0" },
  boar_hide: { name: "野豬皮", color: "#9a6a4a" },
  war_paint: { name: "戰紋顏料", color: "#c83a2a" },
  feather: { name: "羽毛", color: "#e8e8f0" },
  shaman_charm: { name: "薩滿護符", color: "#3ac8a8" },
  bone_shard: { name: "碎骨", color: "#e8e0c8" },
  ectoplasm: { name: "靈質", color: "#9af0e0" },
  cursed_steel: { name: "詛咒鋼", color: "#4a3a5a" },
  troll_hide: { name: "巨魔皮", color: "#5a7a4a" },
  troll_tooth: { name: "巨魔牙", color: "#e0d8a0" },
  guard_plate: { name: "鐵甲片", color: "#a0a8b0" },
  steel_bolt: { name: "鋼弩箭", color: "#707880" },
  captain_badge: { name: "隊長徽章", color: "#e0b030" },
  spider_silk: { name: "蜘蛛絲", color: "#f4f4f8" },
  venom_sac: { name: "毒囊", color: "#8ad040" },
  queen_silk: { name: "女王絲", color: "#e0d0ff" },
  ancient_bark: { name: "古樹皮", color: "#6a5030" },
  amber: { name: "琥珀", color: "#f0a020" },
  heartwood: { name: "樹心", color: "#c89040" },
  mushroom_cap: { name: "蘑菇傘", color: "#d85a4a" },
  glow_spore: { name: "螢光孢子", color: "#b0f070" },
  kappa_shell: { name: "河童甲", color: "#4a8a5a" },
  river_pearl: { name: "河珍珠", color: "#f0f0ff" },
  snake_scale: { name: "蛇鱗", color: "#3a9a8a" },
  naiad_tear: { name: "水妖之淚", color: "#6ad0ff" },
  crab_shell: { name: "蟹殼", color: "#d8603a" },
  crab_claw: { name: "蟹螯", color: "#e87a4a" },
  rat_crown: { name: "鼠王冠", color: "#d8b040" },
  stolen_coin: { name: "贓物銅幣", color: "#c89a3a" },
  leather_strap: { name: "皮帶", color: "#7a5030" },
  throwing_knife: { name: "飛刀", color: "#b8c0c8" },
  gargoyle_stone: { name: "石像鬼石", color: "#6a6a78" },
  bee_stinger: { name: "蜂針", color: "#2a2a2a" },
  beeswax: { name: "蜂蠟", color: "#f0d070" },
  royal_jelly: { name: "蜂王乳", color: "#fff0b0" },
  golem_core: { name: "巨人核心", color: "#40e0f0" },
  vampire_fang: { name: "吸血牙", color: "#c82a3a" },
  // the beginners' crowd (2026-09-28)
  rabbit_fur: { name: "兔毛", color: "#f0e8e0" },
  rabbit_foot: { name: "幸運兔腳", color: "#f8d0d8" },
  snail_shell: { name: "蝸牛殼", color: "#c89a6a" },
  silk_thread: { name: "絲線", color: "#f4f0d8" },
  beetle_shell: { name: "甲蟲殼", color: "#3a5a8a" },
  beetle_horn: { name: "獨角仙角", color: "#6a3a2a" },
  black_feather: { name: "黑羽毛", color: "#2a2a3a" },
  shiny_trinket: { name: "亮晶晶的小東西", color: "#f0e070" },
  acorn: { name: "橡實", color: "#a8703a" },
  squirrel_tail: { name: "松鼠尾巴", color: "#c8784a" },
  hedgehog_spine: { name: "刺蝟刺", color: "#8a7060" },
  goose_feather: { name: "鵝毛", color: "#f8f8f8" },
  fox_tail: { name: "狐狸尾巴", color: "#e8803a" },
  orc_tusk: { name: "強獸人獠牙", color: "#e8e0c0" },
  crude_blade: { name: "粗鐵刀刃", color: "#7a7a80" },
  war_banner: { name: "軍團旗幟", color: "#a02a2a" },
  // what the world's great monsters leave (bosses.ts)
  dragon_scale: { name: "龍鱗", color: "#c83a2a" },
  dragon_heart: { name: "龍心", color: "#ff5a3a" },
  soul_gem: { name: "靈魂寶石", color: "#8a5aff" },
  lich_crown: { name: "巫妖冠", color: "#5a3a8a" },
  giant_bone: { name: "巨人骨", color: "#e0d8c0" },
  giant_heart: { name: "巨人之心", color: "#c8a060" },
  hydra_fang: { name: "九頭蛇牙", color: "#9af06a" },
  hydra_blood: { name: "九頭蛇血", color: "#3ac84a" },
  minotaur_horn: { name: "牛頭人角", color: "#a07850" },
  labyrinth_key: { name: "迷宮鑰匙", color: "#e0c040" },
};

export function materialName(id: string): string {
  return MATERIALS[id]?.name ?? id;
}

const d = (id: string, chance: number, min = 1, max = min): DropRule => ({ id, chance, min, max });

/** What each foe of the big world may leave (the camp's own monsters use camp/combat.ts MONSTER_DROPS). */
export const FOE_DROPS: Record<string, DropRule[]> = {
  big_slime: [d("slime_goo", 1, 2, 4), d("slime_core", 0.6), d("elastic_gel", 0.4, 1, 2), d("shiny_bead", 0.1)],
  wolf: [d("wolf_pelt", 0.6), d("wolf_fang", 0.5, 1, 2)],
  alpha_wolf: [d("wolf_pelt", 1, 1, 2), d("alpha_mane", 0.5)],
  bear: [d("bear_pelt", 1, 1, 2), d("bear_claw", 0.8, 1, 2)],
  boar: [d("boar_hide", 0.6), d("boar_tusk", 0.45)],
  barbarian: [d("war_paint", 0.35), d("leather_strap", 0.4)],
  barbarian_archer: [d("feather", 0.6, 1, 3)],
  shaman: [d("shaman_charm", 0.4), d("feather", 0.3)],
  skeleton: [d("bone_shard", 0.7, 1, 2)],
  wraith: [d("ectoplasm", 0.55)],
  bone_knight: [d("cursed_steel", 0.5), d("bone_shard", 1, 2, 3)],
  troll: [d("troll_hide", 1, 1, 2), d("troll_tooth", 0.5)],
  guard: [d("guard_plate", 0.45)],
  crossbow: [d("steel_bolt", 0.6, 1, 3)],
  captain: [d("captain_badge", 0.6), d("guard_plate", 1, 1, 2)],
  giant_spider: [d("spider_silk", 0.65, 1, 2), d("venom_sac", 0.25)],
  spider_queen: [d("queen_silk", 0.7), d("venom_sac", 0.8, 1, 2)],
  treant: [d("ancient_bark", 1, 2, 3), d("amber", 0.35), d("heartwood", 0.12)],
  mushroom_folk: [d("mushroom_cap", 0.6)],
  spore_mother: [d("glow_spore", 0.7, 1, 2)],
  kappa: [d("kappa_shell", 0.45), d("river_pearl", 0.06)],
  water_snake: [d("snake_scale", 0.6, 1, 2)],
  naiad: [d("naiad_tear", 0.4), d("river_pearl", 0.15)],
  giant_crab: [d("crab_shell", 0.8), d("crab_claw", 0.5)],
  rat_king: [d("rat_crown", 0.4), d("golden_fur", 0.3)],
  bandit: [d("stolen_coin", 0.6, 1, 3), d("leather_strap", 0.35)],
  knife_thrower: [d("throwing_knife", 0.55, 1, 2)],
  bandit_boss: [d("stolen_coin", 1, 3, 6), d("captain_badge", 0.25)],
  gargoyle: [d("gargoyle_stone", 0.6)],
  killer_bee: [d("bee_stinger", 0.4), d("beeswax", 0.25)],
  queen_bee: [d("royal_jelly", 0.8), d("beeswax", 1, 2, 3)],
  stone_golem: [d("golem_core", 0.6), d("gargoyle_stone", 1, 1, 3)],
  vampire_bat: [d("vampire_fang", 0.4), d("bat_wing", 0.6)],
  drake: [d("dragon_scale", 0.3)],
  rabbit: [d("rabbit_fur", 0.6), d("rabbit_foot", 0.05)],
  snail: [d("snail_shell", 0.55), d("slime_goo", 0.3)],
  caterpillar: [d("silk_thread", 0.5)],
  beetle: [d("beetle_shell", 0.5), d("beetle_horn", 0.08)],
  crow: [d("black_feather", 0.6, 1, 2), d("shiny_trinket", 0.08)],
  pigeon: [d("feather", 0.5)],
  squirrel: [d("acorn", 0.7, 1, 3), d("squirrel_tail", 0.2)],
  hedgehog: [d("hedgehog_spine", 0.55, 1, 2)],
  goose: [d("goose_feather", 0.6, 1, 2)],
  fox: [d("fox_tail", 0.35), d("rabbit_fur", 0.2)],
  robber: [d("stolen_coin", 0.5, 1, 2), d("leather_strap", 0.3)],
  orc_grunt: [d("orc_tusk", 0.45), d("crude_blade", 0.3)],
  orc_archer: [d("feather", 0.5, 1, 2), d("orc_tusk", 0.25)],
  orc_chief: [d("war_banner", 0.5), d("orc_tusk", 1, 1, 2), d("crude_blade", 0.6)],
};

/** The drops of one foe kind (the big world's, or the camp's own monsters'). */
export function dropsOf(foe: string): DropRule[] {
  return FOE_DROPS[foe] ?? MONSTER_DROPS[foe] ?? [];
}

/**
 * What the beaten foes of a lair leave (fighter ids `<cell>#<n>`, n = the foe's place in `lair.foes`). A higher level makes
 * every drop a little likelier. Seeded by the expedition, so the report can be worked out again.
 */
export function lairDrops(lair: Lair, fallen: readonly string[], expeditionId: string): Record<string, number> {
  const roll = seeded(expeditionId, "foe-drops");
  const boost = 1 + 0.06 * (lair.level - 1);
  const out: Record<string, number> = {};
  for (const id of fallen) {
    const foe = lair.foes[Number(id.split("#")[1])];
    if (!foe) continue;
    for (const drop of dropsOf(foe)) {
      if (roll() >= Math.min(1, drop.chance * boost)) continue;
      out[drop.id] = (out[drop.id] ?? 0) + between(roll, drop.min, drop.max);
    }
  }
  return out;
}
