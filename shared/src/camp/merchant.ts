/**
 * The wandering merchant (DESKTOP.md §2): comes to a camp that is on a Mac's screen a few times a day, brings a present, and
 * stays a quarter of an hour with a few things to swap for the camp's materials. Each race has its own merchant (a kobold
 * peddler, a squirrel caravan, the ferryman). Everything follows from the visit's id, so the server only keeps events.
 */
import { seeded, type Random } from "../world/random.ts";

/** How long a visit lasts. */
export const MERCHANT_STAY_MINUTES = 15;
/** At most this many visits a day (Taipei time): one or two, and one more on a holiday. */
export const MERCHANT_VISITS_PER_DAY = 3;
/** And not two closer together than this. */
export const MERCHANT_GAP_MINUTES = 60;
/** The race level (big world) from which he comes once more a day, brings a rare swap, and one rarer still (DESKTOP.md §10.0). */
export const MERCHANT_MORE_VISITS_AT = 10;
export const MERCHANT_RARE_AT = 15;
export const MERCHANT_LEGEND_AT = 25;

export interface MerchantOffer {
  /** What the camp hands over, and what it gets. */
  give: Record<string, number>;
  get: Record<string, number>;
  /** Today's bargain (cheaper than usual). */
  sale?: boolean;
  /** A rare find (a day of much focus). */
  rare?: boolean;
}

export interface MerchantVisit {
  id: string;
  /** Who comes (by the camp's race). */
  merchant: string;
  arrivedAt: string;
  leavesAt: string;
  gift: Record<string, number>;
  stock: MerchantOffer[];
  /** The offers already taken (each one once). */
  bought: number[];
}

export const MERCHANT_NAMES: Record<string, string> = { goblin: "狗頭人行商", elf: "松鼠商隊", undead: "冥河擺渡人", beast: "荒野禿鷹商人" };

export function merchantName(race: string): string {
  return MERCHANT_NAMES[race] ?? MERCHANT_NAMES.goblin!;
}

const between = (r: Random, min: number, max: number) => min + Math.floor(r() * (max - min + 1));

/** The present on arrival: plain building stuff, more for a bigger camp, now and then something less common. */
export function merchantGift(visit: string, stage: number): Record<string, number> {
  const r = seeded(visit, "gift");
  const scale = stage >= 3 ? 1.5 : 1;
  const gift: Record<string, number> = stage <= 1
    ? { log: between(r, 10, 20), stone: between(r, 5, 10) }
    : { log: Math.round(between(r, 20, 40) * scale), stone: Math.round(between(r, 10, 20) * scale) };
  if (stage >= 2) {
    const odd = ["scrap_rag", "scrap_wood", "scrap_iron", "rat_pelt", "feather"][between(r, 0, 4)]!;
    gift[odd] = (gift[odd] ?? 0) + between(r, 2, 4);
  }
  if (stage >= 3 && r() < 0.2) gift.crystal_shard = (gift.crystal_shard ?? 0) + 1;
  return gift;
}

/** One swap the merchant may bring: what it costs, what it gives, and how much it fancies bringing it. */
interface Deal { give: Record<string, number>; get: Record<string, number>; weight: number }

/** Every merchant's: plain stuff for odds and ends and rarer finds. */
const COMMON_DEALS: Deal[] = [
  { give: { log: 80 }, get: { crystal_shard: 1 }, weight: 2 },
  { give: { stone: 60 }, get: { scrap_iron: 6 }, weight: 2 },
  { give: { log: 30 }, get: { ration_bread: 3 }, weight: 2 },
  { give: { rat_pelt: 6 }, get: { leather_strap: 1 }, weight: 1.5 },
  { give: { scrap_rag: 10 }, get: { spider_silk: 2 }, weight: 1 },
  { give: { rat_fang: 8 }, get: { wolf_fang: 2 }, weight: 1 },
  { give: { slime_goo: 8 }, get: { elastic_gel: 2 }, weight: 1 },
  { give: { log: 40, stone: 20 }, get: { amber: 1 }, weight: 1 },
  { give: { scrap_iron: 12 }, get: { guard_plate: 1 }, weight: 0.8 },
  { give: { feather: 6 }, get: { food_honey: 3 }, weight: 1 },
];

/** Each merchant's own: what that race likes to have. */
const OWN_DEALS: Record<string, Deal[]> = {
  goblin: [ // the kobold peddler: shiny junk and stolen goods
    { give: { log: 50, scrap_iron: 6 }, get: { stolen_coin: 3 }, weight: 2 },
    { give: { rat_tail: 6, rat_pelt: 4 }, get: { rat_crown: 1 }, weight: 0.6 },
    { give: { stone: 40 }, get: { throwing_knife: 2 }, weight: 1.5 },
    { give: { scrap_wood: 15 }, get: { war_paint: 2 }, weight: 1.2 },
  ],
  elf: [ // the squirrel caravan: things from deep in the forest
    { give: { log: 60 }, get: { heartwood: 1 }, weight: 1.5 },
    { give: { ration_berry: 4 }, get: { glow_spore: 3 }, weight: 1.5 },
    { give: { feather: 8 }, get: { ancient_bark: 2 }, weight: 1.2 },
    { give: { food_honey: 4, log: 20 }, get: { amber: 2 }, weight: 0.8 },
  ],
  undead: [ // the ferryman: what drifts down the river of souls
    { give: { stone: 50 }, get: { ectoplasm: 2 }, weight: 1.5 },
    { give: { bone_shard: 10 }, get: { night_dust: 3 }, weight: 1.5 },
    { give: { night_dust: 6, scrap_iron: 8 }, get: { cursed_steel: 1 }, weight: 1 },
    { give: { night_dust: 10 }, get: { night_heart: 1 }, weight: 0.5 },
  ],
  beast: [ // the vulture of the wilds: what the hunt and the dry valley leave behind
    { give: { food_meat: 6 }, get: { wolf_pelt: 3 }, weight: 1.5 },
    { give: { stone: 40, rabbit_fur: 4 }, get: { boar_tusk: 2 }, weight: 1.5 },
    { give: { food_meat: 8, scrap_iron: 6 }, get: { bear_claw: 1 }, weight: 1 },
    { give: { wolf_pelt: 6, food_meat: 6 }, get: { werewolf_fur: 1 }, weight: 0.5 },
  ],
};

/** A visit on a day of much focus (focus.ts FOCUS_RARE_ROUNDS) has this at the end of its id, and one rare find more. */
export const RARE_VISIT_SUFFIX = "-f";

/**
 * A visit's id ends in its marks, "-" apart: "f" a day of much focus (a rare find), "r1" a race level of MERCHANT_RARE_AT (one
 * more rare find), "r2" of MERCHANT_LEGEND_AT (a legendary one too), "t" the 精打細算 talent (one more ordinary swap).
 */
export function merchantMarks(raceLevel: number, focusRare: boolean, trade: number): string {
  return (focusRare ? RARE_VISIT_SUFFIX : "") + (raceLevel >= MERCHANT_LEGEND_AT ? "-r2" : raceLevel >= MERCHANT_RARE_AT ? "-r1" : "") + (trade > 0 ? "-t" : "");
}
const marked = (visit: string, mark: string) => visit.split("-").slice(2).includes(mark);

/** The legendary finds (a race level of MERCHANT_LEGEND_AT): what only the world bosses drop, for a great deal of the camp's own. */
const LEGEND_DEALS: Deal[] = [
  { give: { crystal_shard: 12, amber: 4, log: 300 }, get: { dragon_scale: 1 }, weight: 1 },
  { give: { crystal_shard: 10, scrap_iron: 60, stone: 300 }, get: { giant_bone: 1 }, weight: 1 },
  { give: { crystal_shard: 12, night_dust: 20 }, get: { soul_gem: 1 }, weight: 1 },
  { give: { crystal_shard: 10, leather_strap: 10, log: 200 }, get: { minotaur_horn: 1 }, weight: 1 },
  { give: { crystal_shard: 12, food_honey: 20, stone: 200 }, get: { hydra_fang: 1 }, weight: 1 },
];

/** The rare finds: what world bosses and great lairs drop, for a good deal of the camp's own. */
const RARE_DEALS: Record<string, Deal[]> = {
  goblin: [
    { give: { stolen_coin: 4, scrap_iron: 10 }, get: { captain_badge: 1 }, weight: 1 },
    { give: { log: 120, rat_pelt: 6 }, get: { golden_fur: 1 }, weight: 1 },
  ],
  elf: [
    { give: { heartwood: 2, log: 40 }, get: { queen_silk: 1 }, weight: 1 },
    { give: { amber: 2, feather: 6 }, get: { river_pearl: 1 }, weight: 1 },
  ],
  undead: [
    { give: { night_dust: 8, bone_shard: 10 }, get: { night_heart: 1 }, weight: 1 },
    { give: { ectoplasm: 4, stone: 40 }, get: { naiad_tear: 1 }, weight: 1 },
  ],
  beast: [
    { give: { wolf_pelt: 6, food_meat: 10 }, get: { alpha_mane: 1 }, weight: 1 },
    { give: { werewolf_fur: 2, wolf_fang: 6 }, get: { alpha_fang: 1 }, weight: 1 },
  ],
};

/** What this visit's merchant brings: four to six swaps, at most one a bargain (40% off what it asks), and on a day of much
 * focus one rare find last (marked `rare`). */
export function merchantStock(visit: string, race: string): MerchantOffer[] {
  const r = seeded(visit, "stock");
  const pool = [...(OWN_DEALS[race] ?? OWN_DEALS.goblin!), ...COMMON_DEALS];
  const count = between(r, 4, 6) + (marked(visit, "t") ? 1 : 0);
  const picked: MerchantOffer[] = [];
  const left = pool.map((deal) => ({ ...deal }));
  while (picked.length < count && left.length) {
    let roll = r() * left.reduce((sum, d) => sum + d.weight, 0);
    let i = 0;
    for (; i < left.length - 1; i++) {
      roll -= left[i]!.weight;
      if (roll < 0) break;
    }
    const [deal] = left.splice(i, 1);
    picked.push({ give: { ...deal!.give }, get: { ...deal!.get } });
  }
  if (r() < 0.15 && picked.length) {
    const offer = picked[between(r, 0, picked.length - 1)]!;
    for (const id of Object.keys(offer.give)) offer.give[id] = Math.max(1, Math.round(offer.give[id]! * 0.6));
    offer.sale = true;
  }
  // (rare finds: a day of much focus, and a race level of MERCHANT_RARE_AT: each a different one while there are)
  const rare = [...(RARE_DEALS[race] ?? RARE_DEALS.goblin!)];
  const rares = (marked(visit, "f") ? 1 : 0) + (marked(visit, "r1") || marked(visit, "r2") ? 1 : 0);
  for (let n = 0; n < rares && rare.length; n++) {
    const [deal] = rare.splice(between(n ? seeded(visit, "rare", n) : seeded(visit, "rare"), 0, rare.length - 1), 1);
    picked.push({ give: { ...deal!.give }, get: { ...deal!.get }, rare: true });
  }
  if (marked(visit, "r2")) {
    const deal = LEGEND_DEALS[between(seeded(visit, "legend"), 0, LEGEND_DEALS.length - 1)]!;
    picked.push({ give: { ...deal.give }, get: { ...deal.get }, rare: true });
  }
  return picked;
}

/** The whole visit, from its id and when it came. */
export function merchantVisit(visit: string, race: string, stage: number, arrivedAt: Date, bought: number[] = []): MerchantVisit {
  return {
    id: visit,
    merchant: merchantName(race),
    arrivedAt: arrivedAt.toISOString(),
    leavesAt: new Date(arrivedAt.getTime() + MERCHANT_STAY_MINUTES * 60_000).toISOString(),
    gift: merchantGift(visit, stage),
    stock: merchantStock(visit, race),
    bought,
  };
}

/** The day (Taipei) a moment falls on, as yyyy-mm-dd: visits are counted per day there. */
export function taipeiDay(at: Date): string {
  return new Date(at.getTime() + 8 * 3_600_000).toISOString().slice(0, 10);
}

/** Everything any of the merchant's swaps may give (for what can be had: world/availability.ts). */
export function merchantGets(): Set<string> {
  const out = new Set<string>();
  for (const deal of [...Object.values(OWN_DEALS).flat(), ...COMMON_DEALS, ...Object.values(RARE_DEALS).flat(), ...LEGEND_DEALS]) for (const id of Object.keys(deal.get)) out.add(id);
  return out;
}
