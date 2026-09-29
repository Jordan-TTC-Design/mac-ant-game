/**
 * The workshop's gear and how the camp hands it out (the Mac's Equipment.swift and Colony's craft / neediest /
 * redistributeArmory / repair / wear). A piece goes to whoever needs it most, what it replaces goes to the store, and the
 * store is handed out again whenever someone is born, dies or a piece is made — except what the player placed by hand: a
 * piece put on a resident by hand is `pinned` (never taken off or replaced by the handing out), a piece taken off by hand is
 * `held` in the store (never handed out). The handing out can be turned off for a camp.
 */
import { BREED_STATS } from "./combat.ts";

export type GearSlot = "weapon" | "shield" | "head" | "chest" | "legs" | "feet" | "hands";
export const GEAR_SLOTS: readonly GearSlot[] = ["weapon", "shield", "head", "chest", "legs", "feet", "hands"];

export interface GearRule {
  id: string;
  name: string;
  slot: GearSlot;
  twoHanded?: boolean;
  might?: number;
  health?: number;
  block?: number;
  speed?: number;
  reach?: number;
  cost: Record<string, number>;
  /** Wear before it breaks (a weapon loses 1 per blow, the rest 1 per hit taken; a shield 2 for a blow it turns aside). */
  durability: number;
}

const g = (id: string, name: string, slot: GearSlot, durability: number, cost: Record<string, number>, stats: Partial<GearRule> = {}): GearRule => ({ id, name, slot, durability, cost, ...stats });

export const GEAR: readonly GearRule[] = [
  // T−1: only wood and stone, which the camp makes by itself (camp/production.ts); weaker than anything else
  g("wood_club", "木棍", "weapon", 60, { log: 3 }, { might: 0.5 }),
  g("stone_axe", "石斧", "weapon", 80, { log: 2, stone: 3 }, { might: 0.6 }),
  g("stone_spear", "石矛", "weapon", 80, { log: 3, stone: 2 }, { might: 0.5, reach: 8, twoHanded: true }),
  g("bark_buckler", "木製小圓盾", "shield", 12, { log: 4 }, { block: 0.08 }),
  g("bark_vest", "樹皮護甲", "chest", 12, { log: 5 }, { health: 0.6 }),
  g("stone_cap", "石片盔", "head", 10, { stone: 3 }, { health: 0.3 }),
  g("bone_knife", "骨刀", "weapon", 120, { rat_fang: 4, rat_tail: 1 }, { might: 1 }),
  g("short_sword", "短劍", "weapon", 160, { scrap_iron: 3, scrap_wood: 1, rat_pelt: 1 }, { might: 1.2 }),
  g("claw_dagger", "利爪匕首", "weapon", 150, { sharp_claw: 2, rat_fang: 4, rat_pelt: 1 }, { might: 1.5 }),
  g("long_sword", "長劍", "weapon", 200, { scrap_iron: 6, rat_pelt: 2, scrap_wood: 1, crude_blade: 1 }, { might: 1.7 }),
  g("crystal_blade", "晶刃", "weapon", 120, { scrap_iron: 5, crystal_shard: 2, rat_pelt: 1, orc_tusk: 2, crude_blade: 1 }, { might: 2.5 }),
  g("twin_blades", "雙刀", "weapon", 180, { scrap_iron: 5, rat_fang: 4, rat_pelt: 2, crude_blade: 2 }, { might: 2.1, twoHanded: true }),
  g("great_sword", "雙手劍", "weapon", 240, { scrap_iron: 9, rat_fang: 4, rat_pelt: 3, crude_blade: 2, orc_tusk: 2 }, { might: 2.8, twoHanded: true }),
  g("spear", "長槍", "weapon", 160, { scrap_wood: 5, scrap_iron: 3, rat_fang: 2, orc_tusk: 1 }, { might: 2, reach: 12, twoHanded: true }),
  g("bow", "弓箭", "weapon", 140, { scrap_wood: 5, rat_tail: 3, rat_fang: 2, squirrel_tail: 2 }, { might: 1.6, reach: 42, twoHanded: true }),
  g("core_staff", "核心法杖", "weapon", 260, { slime_core: 2, slime_goo: 4, shiny_bead: 1, shiny_trinket: 1 }, { might: 2.2, reach: 28 }),
  g("night_dagger", "夜刃匕首", "weapon", 120, { bat_fang: 4, night_dust: 1, scrap_iron: 3, black_feather: 3 }, { might: 1.9, speed: 0.04 }),
  g("wood_shield", "木盾", "shield", 18, { scrap_wood: 6, rat_pelt: 1 }, { block: 0.15 }),
  g("goo_shield", "黏液盾", "shield", 24, { slime_goo: 6, elastic_gel: 2 }, { block: 0.25 }),
  g("cloth_cap", "布帽", "head", 10, { scrap_rag: 3 }, { health: 0.4 }),
  g("leather_cap", "皮帽", "head", 16, { rat_pelt: 2, scrap_rag: 1 }, { health: 0.7 }),
  g("iron_helm", "鐵盔", "head", 30, { scrap_iron: 5, rat_pelt: 1 }, { health: 1.1 }),
  g("cloth_armor", "布甲", "chest", 12, { scrap_rag: 6 }, { health: 0.9 }),
  g("leather_armor", "皮甲", "chest", 20, { rat_pelt: 5, scrap_rag: 2 }, { health: 1.5 }),
  g("iron_plate", "鐵甲", "chest", 36, { scrap_iron: 10, rat_pelt: 2, leather_strap: 2 }, { health: 2.2, speed: -0.04 }),
  g("gold_cloak", "金毛披風", "chest", 30, { golden_fur: 1, rat_pelt: 4, rat_tail: 2 }, { health: 2 }),
  g("bat_cloak", "蝙蝠翼披風", "chest", 20, { bat_wing: 5, rat_pelt: 2, scrap_rag: 2 }, { health: 1.7, speed: 0.03 }),
  g("cloth_pants", "布褲", "legs", 10, { scrap_rag: 4 }, { health: 0.4 }),
  g("leather_pants", "皮褲", "legs", 16, { rat_pelt: 3, scrap_rag: 1 }, { health: 0.8 }),
  g("cloth_shoes", "布鞋", "feet", 10, { scrap_rag: 3 }, { speed: 0.05 }),
  g("leather_boots", "皮靴", "feet", 16, { rat_pelt: 3, rat_tail: 1 }, { health: 0.3, speed: 0.08 }),
  g("frog_boots", "蛙皮靴", "feet", 20, { frog_skin: 3, frog_leg: 1 }, { health: 0.3, speed: 0.12 }),
  g("pelt_wraps", "鼠皮護腕", "hands", 14, { rat_pelt: 3, rat_fang: 1 }, { health: 0.5 }),
  g("iron_gauntlets", "鐵手甲", "hands", 26, { scrap_iron: 4, rat_pelt: 1 }, { might: 0.4, health: 0.4 }),
  // 2026-09-29: from what camp raids leave that nothing used (夜之心、黏舌、金蛙眼) or little (凝膠、核心、蛙腿)
  g("tongue_whip", "黏舌鞭", "weapon", 130, { sticky_tongue: 3, frog_leg: 2 }, { might: 1.5, reach: 14 }),
  g("frog_crown", "金蛙頭冠", "head", 20, { golden_frog_eye: 1, frog_skin: 3 }, { health: 1.0, speed: 0.05 }),
  g("night_pants", "夜行褲", "legs", 18, { night_heart: 1, bat_wing: 3 }, { health: 1.0, speed: 0.04 }),
  g("gel_greaves", "黏液護腿", "legs", 16, { elastic_gel: 3, slime_goo: 3 }, { health: 1.1 }),
  g("core_gloves", "核心手套", "hands", 20, { slime_core: 1, elastic_gel: 2 }, { might: 0.3, health: 0.6 }),
  // 2026-09-28: made from what the big world's foes drop (world/drops.ts); the Mac's Equipment.swift has the same list
  g("wolf_fang_spear", "狼牙槍", "weapon", 170, { wolf_fang: 4, scrap_wood: 4, leather_strap: 1 }, { might: 2.3, reach: 12, twoHanded: true }),
  g("venom_dagger", "毒牙匕首", "weapon", 140, { venom_sac: 2, bat_fang: 2, scrap_iron: 2 }, { might: 2.2, speed: 0.03 }),
  g("silk_bow", "蛛絲弓", "weapon", 170, { spider_silk: 4, scrap_wood: 5, feather: 3 }, { might: 2.0, reach: 46, twoHanded: true }),
  g("heartwood_staff", "樹心法杖", "weapon", 300, { heartwood: 1, ancient_bark: 3, amber: 1 }, { might: 2.8, reach: 30 }),
  g("troll_greatsword", "巨魔牙大劍", "weapon", 260, { troll_tooth: 2, scrap_iron: 8, troll_hide: 1 }, { might: 3.4, twoHanded: true }),
  g("cursed_blade", "詛咒之劍", "weapon", 220, { cursed_steel: 3, bone_shard: 4, ectoplasm: 1 }, { might: 3.0 }),
  g("knife_pair", "飛刀雙刃", "weapon", 170, { throwing_knife: 4, leather_strap: 2 }, { might: 2.4, speed: 0.04, twoHanded: true }),
  g("crab_shield", "蟹殼盾", "shield", 30, { crab_shell: 3, crab_claw: 1 }, { block: 0.3 }),
  g("kappa_shield", "河童甲盾", "shield", 28, { kappa_shell: 2, snake_scale: 2 }, { block: 0.28 }),
  g("gargoyle_shield", "石像盾", "shield", 40, { gargoyle_stone: 4, scrap_iron: 3 }, { block: 0.38, speed: -0.03 }),
  g("alpha_helm", "狼王頭盔", "head", 28, { alpha_mane: 1, wolf_pelt: 2, scrap_iron: 2 }, { health: 1.3, might: 0.2 }),
  g("mushroom_hat", "蘑菇帽", "head", 18, { mushroom_cap: 3, glow_spore: 1 }, { health: 0.9 }),
  g("rat_crown_hat", "鼠王冠", "head", 24, { rat_crown: 1, golden_fur: 1 }, { health: 0.6, might: 0.3 }),
  g("wolf_cloak", "狼皮披風", "chest", 24, { wolf_pelt: 4, leather_strap: 1 }, { health: 1.9, speed: 0.03 }),
  g("bear_armor", "熊皮甲", "chest", 32, { bear_pelt: 3, leather_strap: 2 }, { health: 2.6 }),
  g("bark_armor", "古樹皮甲", "chest", 40, { ancient_bark: 5, amber: 1 }, { health: 2.8, speed: -0.03 }),
  g("silk_robe", "女王絲袍", "chest", 22, { queen_silk: 2, spider_silk: 4 }, { health: 2.0, speed: 0.05 }),
  g("troll_armor", "巨魔皮甲", "chest", 44, { troll_hide: 3, leather_strap: 2 }, { health: 3.2, speed: -0.04 }),
  g("boar_leggings", "野豬皮褲", "legs", 20, { boar_hide: 3, leather_strap: 1 }, { health: 1.0 }),
  g("scale_pants", "蛇鱗褲", "legs", 22, { snake_scale: 4, scrap_rag: 2 }, { health: 1.1, speed: 0.02 }),
  g("tusk_boots", "獠牙靴", "feet", 20, { boar_tusk: 2, boar_hide: 2 }, { health: 0.5, speed: 0.09 }),
  g("naiad_slippers", "水妖鞋", "feet", 18, { naiad_tear: 1, frog_skin: 2 }, { speed: 0.15 }),
  g("bear_claws", "熊爪拳套", "hands", 30, { bear_claw: 2, bear_pelt: 1 }, { might: 0.8, health: 0.3 }),
  g("golem_gauntlets", "巨人拳甲", "hands", 40, { golem_core: 1, gargoyle_stone: 2, scrap_iron: 3 }, { might: 0.9, health: 0.6, speed: -0.02 }),
  // for beginners: from the small monsters of the world's first lairs (2026-09-28)
  g("slingshot", "橡實彈弓", "weapon", 100, { acorn: 5, scrap_wood: 2 }, { might: 1.4, reach: 30, twoHanded: true }),
  g("rabbit_cap", "兔毛帽", "head", 14, { rabbit_fur: 3 }, { health: 0.8 }),
  g("fox_cap", "狐尾帽", "head", 18, { fox_tail: 1, rabbit_fur: 2 }, { health: 0.9, speed: 0.03 }),
  g("snail_shield", "蝸牛殼盾", "shield", 20, { snail_shell: 3 }, { block: 0.2 }),
  g("beetle_armor", "甲蟲甲", "chest", 24, { beetle_shell: 4, silk_thread: 1 }, { health: 1.8 }),
  g("feather_cloak", "黑羽披風", "chest", 18, { black_feather: 5, silk_thread: 1 }, { health: 1.3, speed: 0.05 }),
  g("spine_gloves", "刺蝟手套", "hands", 16, { hedgehog_spine: 3, rabbit_fur: 1 }, { might: 0.5, health: 0.3 }),
  g("goose_boots", "鵝毛鞋", "feet", 14, { goose_feather: 3, scrap_rag: 1 }, { health: 0.2, speed: 0.1 }),
  // made from what the first lairs drop that nothing else used (BALANCE.md §5)
  g("tusk_axe", "獠牙戰斧", "weapon", 180, { orc_tusk: 3, scrap_wood: 2, leather_strap: 1 }, { might: 2.4, twoHanded: true }),
  g("stinger_rapier", "蜂針細劍", "weapon", 130, { bee_stinger: 4, scrap_iron: 2 }, { might: 1.8, speed: 0.03 }),
  g("coin_mail", "銅錢甲", "chest", 30, { stolen_coin: 6, leather_strap: 1 }, { health: 2.0 }),
  g("horn_helm", "獨角仙盔", "head", 26, { beetle_horn: 1, beetle_shell: 2 }, { might: 0.2, health: 1.2 }),
  g("squirrel_hat", "松鼠尾帽", "head", 16, { squirrel_tail: 2, scrap_rag: 1 }, { health: 0.8, speed: 0.04 }),
  g("pearl_shield", "珍珠貝盾", "shield", 24, { river_pearl: 1, snail_shell: 2 }, { block: 0.22 }),
  g("lucky_boots", "兔腳靴", "feet", 18, { rabbit_foot: 1, rabbit_fur: 2 }, { health: 0.2, speed: 0.12 }),
  // 中等 (2026-09-29): from what the 初期魔王 leave (world/contents.ts); a step above the first lairs' gear
  g("dire_fang_blade", "巨狼牙刀", "weapon", 200, { dire_fang: 2, scrap_iron: 5, leather_strap: 1 }, { might: 2.6 }),
  g("echo_bow", "回音弓", "weapon", 170, { echo_fang: 2, giant_bat_wing: 1, scrap_wood: 5 }, { might: 2.2, reach: 46, twoHanded: true }),
  g("tusk_maul", "野豬王戰鎚", "weapon", 220, { lord_tusk: 2, scrap_iron: 6, thick_hide: 1 }, { might: 3.0, speed: -0.03, twoHanded: true }),
  g("royal_gel_shield", "王者凝膠盾", "shield", 30, { royal_gel: 3, slime_goo: 4 }, { block: 0.32 }),
  g("crown_helm", "王冠頭盔", "head", 26, { slime_crown: 1, royal_gel: 1 }, { might: 0.2, health: 1.4 }),
  g("dire_pelt_armor", "巨狼皮甲", "chest", 30, { dire_pelt: 3, leather_strap: 1 }, { health: 2.3, speed: 0.02 }),
  g("thick_hide_greaves", "厚皮護腿", "legs", 24, { thick_hide: 3, leather_strap: 1 }, { health: 1.4 }),
  g("bat_lord_boots", "蝠翼靴", "feet", 22, { giant_bat_wing: 2, frog_skin: 2 }, { health: 0.3, speed: 0.14 }),
  g("toad_gloves", "蛙王手套", "hands", 24, { toad_skin: 2, toad_gem: 1 }, { might: 0.5, health: 0.6 }),
  g("commander_bracer", "隊長臂章", "hands", 26, { captain_badge: 1, leather_strap: 2 }, { might: 0.6, health: 0.4 }),
  // legendary: from the world's great monsters (world/bosses.ts)
  g("dragon_scale_armor", "龍鱗甲", "chest", 60, { dragon_scale: 4, leather_strap: 2 }, { health: 4.0 }),
  g("lich_staff", "巫妖法杖", "weapon", 320, { soul_gem: 2, cursed_steel: 2 }, { might: 3.6, reach: 34 }),
  g("giant_hammer", "巨人戰鎚", "weapon", 300, { giant_bone: 3, scrap_iron: 6 }, { might: 4.2, speed: -0.05, twoHanded: true }),
  g("hydra_bow", "九頭蛇弓", "weapon", 220, { hydra_fang: 2, spider_silk: 3, scrap_wood: 4 }, { might: 2.8, reach: 50, twoHanded: true }),
  g("minotaur_helm", "牛角盔", "head", 40, { minotaur_horn: 2, scrap_iron: 3 }, { health: 1.8, might: 0.4 }),
];

const BY_ID = new Map(GEAR.map((x) => [x.id, x]));
export function gearRule(id: string): GearRule | undefined {
  return BY_ID.get(id);
}

/** A piece as it exists: which, and how much wear it has left (in the rule's durability units). */
export interface GearItem {
  id: string;
  left: number;
  /** On a resident: put there by hand (the handing out leaves it be). */
  pinned?: boolean;
  /** In the store: taken off by hand (the handing out leaves it be). */
  held?: boolean;
}

/** One number to tell which of two pieces for the same slot is better (a worn-out one, under a quarter, counts half). */
export function gearPower(item: GearItem | undefined): number {
  const rule = item && gearRule(item.id);
  if (!rule || !item) return 0;
  const power = (rule.might ?? 0) + (rule.health ?? 0) + (rule.block ?? 0) * 5 + (rule.speed ?? 0) * 6 + (rule.reach ?? 0) / 40;
  return item.left / rule.durability < 0.25 ? power / 2 : power;
}

/** What mending costs: a third of what it was made from (rounded up, at least one of each). */
export function repairCost(rule: GearRule): Record<string, number> {
  return Object.fromEntries(Object.entries(rule.cost).map(([id, n]) => [id, Math.max(1, Math.ceil(n / 3))]));
}

export function canAfford(have: Record<string, number>, cost: Record<string, number>): boolean {
  return Object.entries(cost).every(([id, n]) => (have[id] ?? 0) >= n);
}

export function spend(have: Record<string, number>, cost: Record<string, number>): void {
  for (const [id, n] of Object.entries(cost)) {
    have[id] = (have[id] ?? 0) - n;
    if (have[id]! <= 0) delete have[id];
  }
}

/** A resident as the workshop sees it. */
export interface Wearer {
  id: number;
  breed: string;
  gear: Partial<Record<GearSlot, GearItem>>;
}

/**
 * Who gains most from `item`: whoever's piece in that slot is worst (nothing at all first); among equals the strong get
 * weapons, the sturdy shields, the rest the average. Nobody who already has something at least as good; no shield for a
 * two-handed weapon. Null when nobody needs it.
 */
export function neediest(race: string, wearers: readonly Wearer[], item: GearItem): Wearer | null {
  const rule = gearRule(item.id);
  if (!rule) return null;
  const power = gearPower(item);
  const stats = (w: Wearer) => BREED_STATS[race]?.[w.breed] ?? {};
  const fit = (w: Wearer) => {
    const might = stats(w).might ?? 1, health = stats(w).health ?? 3;
    return rule.slot === "weapon" ? might : rule.slot === "shield" ? health : health * 0.5 + might * 0.5;
  };
  let best: Wearer | null = null;
  for (const w of wearers) {
    const now = gearPower(w.gear[rule.slot]);
    if (now >= power) continue;
    if (w.gear[rule.slot]?.pinned || (rule.twoHanded && w.gear.shield?.pinned)) continue; // (what the player placed stays)
    if (rule.slot === "shield" && gearRule(w.gear.weapon?.id ?? "")?.twoHanded) continue;
    if (!best) { best = w; continue; }
    const bestNow = gearPower(best.gear[rule.slot]);
    if (now < bestNow || (now === bestNow && (fit(w) > fit(best) || (fit(w) === fit(best) && w.id < best.id)))) best = w;
  }
  return best;
}

/**
 * Puts `item` on `wearer`; what it wore there goes back to `store` (a two-handed weapon also sends the shield back). By
 * hand (`byHand`): the piece is pinned there, and what it sends back is held.
 */
export function give(wearer: Wearer, item: GearItem, store: GearItem[], byHand = false): void {
  const rule = gearRule(item.id)!;
  const back = (piece: GearItem) => store.push(byHand ? { id: piece.id, left: piece.left, held: true } : { id: piece.id, left: piece.left });
  const old = wearer.gear[rule.slot];
  if (old) back(old);
  wearer.gear[rule.slot] = byHand ? { id: item.id, left: item.left, pinned: true } : { id: item.id, left: item.left };
  if (rule.twoHanded && wearer.gear.shield) {
    back(wearer.gear.shield);
    delete wearer.gear.shield;
  }
}

/** Takes the piece in `slot` off `wearer` by hand: it goes to the store, held. Returns it (null: nothing there). */
export function takeOff(wearer: Wearer, slot: GearSlot, store: GearItem[]): GearItem | null {
  const piece = wearer.gear[slot];
  if (!piece) return null;
  delete wearer.gear[slot];
  const held = { id: piece.id, left: piece.left, held: true };
  store.push(held);
  return held;
}

/** Why `item` cannot go on `wearer` by hand (null: it can). */
export function cannotWear(wearer: Wearer, item: GearItem): string | null {
  const rule = gearRule(item.id);
  if (!rule) return "工坊不認得這件。";
  if (rule.slot === "shield" && gearRule(wearer.gear.weapon?.id ?? "")?.twoHanded) return "拿著雙手武器，沒有手拿盾。";
  return null;
}

/**
 * Hands the store on, best pieces first, each to whoever needs it most; what nobody needs stays, and so does what is held.
 * Changes both in place. `auto` false (the camp turned the handing out off): nothing moves.
 */
export function redistribute(race: string, wearers: Wearer[], store: GearItem[], auto = true): void {
  if (!auto) return;
  for (let rounds = 0; rounds < 500; rounds++) {
    const order = store.map((item, i) => ({ item, i })).filter(({ item }) => !item.held).sort((a, b) => gearPower(b.item) - gearPower(a.item));
    const next = order.find(({ item }) => neediest(race, wearers, item));
    if (!next) return;
    store.splice(next.i, 1);
    give(neediest(race, wearers, next.item)!, next.item, store);
  }
}
