/**
 * The guild merchant (GUILD.md §5.3, 2026-10-17): once a week he comes to a guild's hall for two days with a few of the
 * merchant-only decorations and clothes. A member buys a decoration with their own contribution and then the whole guild
 * may put it down; clothes are the buyer's own. When he comes and what he carries follow from the guild's id and the week,
 * so the server, the Mac and the phone all work it out the same.
 */
import { z } from "zod";
import { GUILD_DECOR, type GuildDecorKind } from "./guild-decor-catalog.ts";
import { hallHash } from "./guild-hall.ts";
import { GUILD_OUTFITS } from "./guild-outfits.ts";

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
/** Taiwan's clock: his days run midnight to midnight there. */
const TAIPEI = 8 * HOUR;
/** He stays this many days. */
export const MERCHANT_DAYS = 2;
/** What he brings each visit. */
export const MERCHANT_DECOR = 6;
export const MERCHANT_OUTFITS = 2;

export const MERCHANT_KINDS: readonly GuildDecorKind[] = GUILD_DECOR.filter((k) => k.merchant);

/** What a merchant decoration costs: by how much room it takes. */
export function merchantDecorPrice(kind: Pick<GuildDecorKind, "size">): number {
  return kind.size >= 4 ? 1200 : kind.size >= 2 ? 600 : 300;
}

export interface MerchantView {
  /** Whether he is in the hall now. */
  here: boolean;
  /** This visit (or the next, when he is not here): when he comes and goes. */
  from: string;
  until: string;
  /** What he has on him (empty when not here). */
  decor: { kind: string; price: number }[];
  outfits: string[];
}

/** A deterministic shuffle's first `n`, from `seed`. */
function pick<T>(list: readonly T[], n: number, ...seed: (string | number)[]): T[] {
  return list
    .map((v, i) => ({ v, r: hallHash(...seed, i) }))
    .sort((a, b) => a.r - b.r)
    .slice(0, n)
    .map((x) => x.v);
}

/** The visit of the week (Monday start, Taiwan) holding `at`: he comes on one of Monday–Friday. */
function visitOfWeek(guildId: string, at: number): { from: number; until: number; week: number } {
  const local = at + TAIPEI;
  const day = Math.floor(local / DAY);
  const monday = day - ((day + 3) % 7); // (day 0, 1970-01-01, was a Thursday)
  const from = (monday + Math.floor(hallHash(guildId, "merchant", monday) * 5)) * DAY - TAIPEI;
  return { from, until: from + MERCHANT_DAYS * DAY, week: monday };
}

/** Where the guild merchant is at `at`: here with his goods, or when he comes next. */
export function merchantVisit(guildId: string, at: Date): MerchantView {
  const t = at.getTime();
  let v = visitOfWeek(guildId, t);
  if (t >= v.until) v = visitOfWeek(guildId, (v.week + 7) * DAY - TAIPEI); // (gone for this week: next week's)
  const here = t >= v.from && t < v.until;
  return {
    here,
    from: new Date(v.from).toISOString(),
    until: new Date(v.until).toISOString(),
    decor: here ? pick(MERCHANT_KINDS, MERCHANT_DECOR, guildId, "decor", v.week).map((k) => ({ kind: k.id, price: merchantDecorPrice(k) })) : [],
    outfits: here ? pick(GUILD_OUTFITS.filter((o) => o.merchant), MERCHANT_OUTFITS, guildId, "outfits", v.week).map((o) => o.id) : [],
  };
}

export const merchantBuyInput = z.object({ kind: z.string().max(40) });

/** Why the guild can't buy this from him now (null: it can). `unlocked`: the merchant pieces the guild has already. */
export function merchantBuyProblem(kind: string, visit: MerchantView, unlocked: readonly string[], points: number): string | null {
  if (!visit.here) return "公會商人現在不在。";
  const item = visit.decor.find((d) => d.kind === kind);
  if (!item) return "商人這次沒有帶這件。";
  if (unlocked.includes(kind)) return "公會已經有這件了。";
  if (points < item.price) return `貢獻不夠（要 ${item.price}，還有 ${points}）。捐東西給公會可以累積貢獻。`;
  return null;
}
