/**
 * The avatars' clothes (GUILD.md §2, 2026-10-17): a top, a bottom, shoes and a hat, the same for every race. Bought with the
 * account's own contribution (the points of what it gave its guilds, less what it spent); the free ones everyone has. The
 * pictures are mac/tools/make_avatars.py's (manifest `files`: `<race>_<sex>_<id>` for clothes, `<id>` for hats); a body
 * that cannot wear one simply has no picture of it.
 */
import { z } from "zod";
import { guildSeason, seasonOpen } from "./guild-seasons.ts";

export type OutfitSlot = "top" | "bottom" | "shoes" | "hat";
export const OUTFIT_SLOTS: readonly OutfitSlot[] = ["top", "bottom", "shoes", "hat"];
export const OUTFIT_SLOT_NAMES: Record<OutfitSlot, string> = { top: "上衣", bottom: "下身", shoes: "鞋子", hat: "帽子" };

export interface GuildOutfit {
  id: string;
  slot: OutfitSlot;
  name: string;
  /** Contribution it costs (0: free, everyone has it). */
  price: number;
  /** Only to be had while a holiday is on (shared/src/guild-seasons.ts), from a guild level on, or from the guild merchant when he
   *  carries it (2026-10-17). What is had stays one's own. */
  season?: string;
  level?: number;
  merchant?: boolean;
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
  // the holidays (while the season is on)
  { id: "red_festive_jacket", slot: "top", name: "紅繡花襖", price: 800, season: "spring_festival" },
  { id: "lion_dance_hat", slot: "hat", name: "舞獅帽", price: 900, season: "spring_festival" },
  { id: "embroidered_slippers", slot: "shoes", name: "繡花鞋", price: 400, season: "spring_festival" },
  { id: "lantern_robe", slot: "top", name: "元宵燈籠袍", price: 700, season: "lantern" },
  { id: "lantern_hat", slot: "hat", name: "燈籠帽", price: 600, season: "lantern" },
  { id: "rower_vest", slot: "top", name: "龍舟隊背心", price: 500, season: "dragon_boat" },
  { id: "rice_dumpling_hat", slot: "hat", name: "粽子帽", price: 600, season: "dragon_boat" },
  { id: "rabbit_ear_hood", slot: "hat", name: "玉兔耳帽", price: 700, season: "mid_autumn" },
  { id: "moon_gown", slot: "top", name: "月白長袍", price: 800, season: "mid_autumn" },
  { id: "cloud_shoes", slot: "shoes", name: "雲紋鞋", price: 400, season: "mid_autumn" },
  { id: "flag_cap", slot: "hat", name: "國慶小旗帽", price: 500, season: "national" },
  { id: "parade_jacket", slot: "top", name: "閱兵禮服", price: 800, season: "national" },
  { id: "party_hat", slot: "hat", name: "派對帽", price: 400, season: "new_year" },
  { id: "sequin_jacket", slot: "top", name: "亮片外套", price: 800, season: "new_year" },
  { id: "santa_hat", slot: "hat", name: "聖誕帽", price: 500, season: "christmas" },
  { id: "santa_coat", slot: "top", name: "聖誕紅外套", price: 900, season: "christmas" },
  { id: "jingle_boots", slot: "shoes", name: "鈴鐺靴", price: 500, season: "christmas" },
  // the guild levels: 2 the workshop and study, 3 the meeting room, 4 the courtyard, 5 the banquet hall, 6 the training ground, 7 the tower
  { id: "craftsman_apron", slot: "top", name: "工匠圍裙", price: 600, level: 2 },
  { id: "scholar_vest", slot: "top", name: "書生背心", price: 700, level: 2 },
  { id: "canvas_trousers", slot: "bottom", name: "帆布褲", price: 500, level: 2 },
  { id: "work_clogs", slot: "shoes", name: "木鞋", price: 500, level: 2 },
  { id: "study_slippers", slot: "shoes", name: "書房拖鞋", price: 500, level: 2 },
  { id: "reading_cap", slot: "hat", name: "書生帽", price: 800, level: 2 },
  { id: "council_coat", slot: "top", name: "議事長外套", price: 1000, level: 3 },
  { id: "clerk_shirt", slot: "top", name: "書記襯衫", price: 800, level: 3 },
  { id: "pleated_trousers", slot: "bottom", name: "摺線長褲", price: 700, level: 3 },
  { id: "dark_skirt", slot: "bottom", name: "深色長裙", price: 700, level: 3 },
  { id: "polished_shoes", slot: "shoes", name: "亮皮鞋", price: 650, level: 3 },
  { id: "tricorn_hat", slot: "hat", name: "三角帽", price: 1050, level: 3 },
  { id: "gardener_smock", slot: "top", name: "園丁罩衫", price: 900, level: 4 },
  { id: "hunter_jerkin", slot: "top", name: "獵人短衣", price: 1100, level: 4 },
  { id: "green_breeches", slot: "bottom", name: "綠色馬褲", price: 850, level: 4 },
  { id: "garden_boots", slot: "shoes", name: "雨靴", price: 800, level: 4 },
  { id: "hunter_boots", slot: "shoes", name: "獵人長靴", price: 950, level: 4 },
  { id: "sun_bonnet", slot: "hat", name: "遮陽帽", price: 1000, level: 4 },
  { id: "banquet_gown", slot: "top", name: "宴會禮服", price: 1500, level: 5 },
  { id: "velvet_doublet", slot: "top", name: "絲絨短上衣", price: 1400, level: 5 },
  { id: "satin_skirt", slot: "bottom", name: "緞面長裙", price: 1100, level: 5 },
  { id: "velvet_breeches", slot: "bottom", name: "絲絨馬褲", price: 1000, level: 5 },
  { id: "buckle_shoes", slot: "shoes", name: "金扣鞋", price: 950, level: 5 },
  { id: "jeweled_tiara", slot: "hat", name: "寶石頭冠", price: 1550, level: 5 },
  { id: "chainmail", slot: "top", name: "鎖子甲", price: 1600, level: 6 },
  { id: "padded_gambeson", slot: "top", name: "軟甲", price: 1200, level: 6 },
  { id: "armored_leggings", slot: "bottom", name: "鐵腿甲", price: 1400, level: 6 },
  { id: "war_kilt", slot: "bottom", name: "戰裙", price: 1100, level: 6 },
  { id: "sabatons", slot: "shoes", name: "鐵靴", price: 1300, level: 6 },
  { id: "knight_helm", slot: "hat", name: "騎士頭盔", price: 1800, level: 6 },
  { id: "archmage_robe", slot: "top", name: "大法師長袍", price: 2050, level: 7 },
  { id: "star_mantle", slot: "top", name: "星辰披風", price: 1900, level: 7 },
  { id: "runed_skirt", slot: "bottom", name: "符文長裙", price: 1500, level: 7 },
  { id: "starlit_slippers", slot: "shoes", name: "星光軟鞋", price: 1250, level: 7 },
  { id: "silver_greaves", slot: "shoes", name: "銀護脛", price: 1400, level: 7 },
  { id: "astral_crown", slot: "hat", name: "星辰冠", price: 2050, level: 7 },
  // the guild merchant's, when he carries them
  { id: "silk_kimono", slot: "top", name: "絲綢和服", price: 2500, merchant: true },
  { id: "desert_robe", slot: "top", name: "沙漠長袍", price: 1800, merchant: true },
  { id: "dragon_scale_armor", slot: "top", name: "龍鱗甲", price: 3000, merchant: true },
  { id: "phoenix_coat", slot: "top", name: "鳳凰羽衣", price: 2800, merchant: true },
  { id: "harem_pants", slot: "bottom", name: "燈籠褲", price: 1500, merchant: true },
  { id: "golden_sandals", slot: "shoes", name: "金涼鞋", price: 1600, merchant: true },
  { id: "dragon_boots", slot: "shoes", name: "龍皮靴", price: 2200, merchant: true },
  { id: "golden_crown", slot: "hat", name: "黃金王冠", price: 3000, merchant: true },
  { id: "turban", slot: "hat", name: "纏頭巾", price: 1600, merchant: true },
  { id: "dragon_horn_helm", slot: "hat", name: "龍角盔", price: 2600, merchant: true },
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

/** Where one stands for the limited clothes: the day (Taipei, "yyyy-mm-dd"), one's guild's level (0: in none), and what the guild
 *  merchant has on him now (empty: he is not there). */
export interface OutfitShop {
  today: string;
  guildLevel: number;
  merchant: ReadonlySet<string>;
}

/** Why a limited piece can't be had now (null: it can). */
export function outfitClosed(o: GuildOutfit, shop: OutfitShop): string | null {
  if (o.season) {
    const s = guildSeason(o.season);
    if (!s || !seasonOpen(s, shop.today)) return `${o.name}是${s?.name ?? "節日"}限定，節日期間才換得到。`;
  }
  if (o.level && shop.guildLevel < o.level) return shop.guildLevel ? `${o.name}要公會 ${o.level} 級才換得到。` : `${o.name}要加入公會、公會 ${o.level} 級才換得到。`;
  if (o.merchant && !shop.merchant.has(o.id)) return `${o.name}只有公會商人帶來時才換得到。`;
  return null;
}

/** Why this can't be bought (null: it can). */
export function outfitBuyProblem(id: string, wardrobe: GuildWardrobe, shop?: OutfitShop): { code: "unknown" | "owned" | "not_enough" | "closed"; message: string } | null {
  const o = BY_ID.get(id);
  if (!o) return { code: "unknown", message: "沒有這件衣服。" };
  if (wardrobe.owned.includes(id)) return { code: "owned", message: `已經有${o.name}了。` };
  const closed = shop ? outfitClosed(o, shop) : o.season || o.level || o.merchant ? "現在換不到這件。" : null;
  if (closed) return { code: "closed", message: closed };
  if (wardrobe.points < o.price) return { code: "not_enough", message: `貢獻不夠（要 ${o.price}，還有 ${wardrobe.points}）。捐東西給公會可以累積貢獻。` };
  return null;
}
