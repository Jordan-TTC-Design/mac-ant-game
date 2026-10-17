/**
 * The avatars' clothes (GUILD.md §2, 2026-10-17): a top, a bottom, shoes and a hat, the same for every race. Bought with the
 * account's own contribution (the points of what it gave its guilds, less what it spent); the free ones everyone has. The
 * pictures are mac/tools/make_avatars.py's (manifest `files`: `<race>_<sex>_<id>` for clothes, `<id>` for hats); a body
 * that cannot wear one simply has no picture of it.
 */
import { z } from "zod";

export type OutfitSlot = "top" | "bottom" | "shoes" | "hat";
export const OUTFIT_SLOTS: readonly OutfitSlot[] = ["top", "bottom", "shoes", "hat"];
export const OUTFIT_SLOT_NAMES: Record<OutfitSlot, string> = { top: "上衣", bottom: "下身", shoes: "鞋子", hat: "帽子" };

export interface GuildOutfit {
  id: string;
  slot: OutfitSlot;
  name: string;
  /** Contribution it costs (0: free, everyone has it). */
  price: number;
}

export const GUILD_OUTFITS: readonly GuildOutfit[] = [
  { id: "linen_shirt", slot: "top", name: "亞麻上衣", price: 0 },
  { id: "leather_vest", slot: "top", name: "皮背心", price: 300 },
  { id: "knight_tabard", slot: "top", name: "騎士罩袍", price: 800 },
  { id: "mage_robe", slot: "top", name: "法師長袍", price: 1200 },
  { id: "noble_doublet", slot: "top", name: "貴族短上衣", price: 2000 },
  { id: "work_trousers", slot: "bottom", name: "工作褲", price: 0 },
  { id: "leather_pants", slot: "bottom", name: "皮褲", price: 400 },
  { id: "plaid_kilt", slot: "bottom", name: "格子裙", price: 600 },
  { id: "silk_skirt", slot: "bottom", name: "絲綢長裙", price: 1000 },
  { id: "sandals", slot: "shoes", name: "草鞋", price: 0 },
  { id: "leather_boots", slot: "shoes", name: "皮靴", price: 300 },
  { id: "pointy_slippers", slot: "shoes", name: "尖頭軟鞋", price: 500 },
  { id: "iron_greaves", slot: "shoes", name: "鐵護脛", price: 900 },
  { id: "straw_hat", slot: "hat", name: "草帽", price: 0 },
  { id: "flower_crown", slot: "hat", name: "花冠", price: 400 },
  { id: "feather_cap", slot: "hat", name: "羽毛帽", price: 600 },
  { id: "iron_helm", slot: "hat", name: "鐵頭盔", price: 1000 },
  { id: "wizard_hat", slot: "hat", name: "巫師帽", price: 1500 },
];

const BY_ID = new Map(GUILD_OUTFITS.map((o) => [o.id, o]));

export function guildOutfit(id: string): GuildOutfit | undefined {
  return BY_ID.get(id);
}

/** The free ones, which everyone has. */
export const FREE_OUTFITS: readonly string[] = GUILD_OUTFITS.filter((o) => o.price === 0).map((o) => o.id);

/** What an account has to dress in: the clothes it owns (the free ones too) and the contribution it has left. */
export interface GuildWardrobe {
  owned: string[];
  /** Contribution left to spend (all it ever gave, less `spent`). */
  points: number;
  spent: number;
}

export const outfitBuyInput = z.object({ id: z.string().max(40) });

/** Why this can't be bought (null: it can). */
export function outfitBuyProblem(id: string, wardrobe: GuildWardrobe): { code: "unknown" | "owned" | "not_enough"; message: string } | null {
  const o = BY_ID.get(id);
  if (!o) return { code: "unknown", message: "沒有這件衣服。" };
  if (wardrobe.owned.includes(id)) return { code: "owned", message: `已經有${o.name}了。` };
  if (wardrobe.points < o.price) return { code: "not_enough", message: `貢獻不夠（要 ${o.price}，還有 ${wardrobe.points}）。捐東西給公會可以累積貢獻。` };
  return null;
}
