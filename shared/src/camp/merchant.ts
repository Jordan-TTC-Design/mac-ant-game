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

export interface MerchantOffer {
  /** What the camp hands over, and what it gets. */
  give: Record<string, number>;
  get: Record<string, number>;
  /** Today's bargain (cheaper than usual). */
  sale?: boolean;
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

export const MERCHANT_NAMES: Record<string, string> = { goblin: "狗頭人行商", elf: "松鼠商隊", undead: "冥河擺渡人" };

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
};

/** What this visit's merchant brings: four to six swaps, at most one a bargain (40% off what it asks). */
export function merchantStock(visit: string, race: string): MerchantOffer[] {
  const r = seeded(visit, "stock");
  const pool = [...(OWN_DEALS[race] ?? OWN_DEALS.goblin!), ...COMMON_DEALS];
  const count = between(r, 4, 6);
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
