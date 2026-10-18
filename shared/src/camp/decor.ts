/**
 * The decorations a player puts down in the camp window themselves (DESKTOP.md §5). Each race has its own fifty
 * (decor-catalog.ts, generated from the Mac's drawings), all free for now; how many fit is the camp's decoration room, by
 * its look (stage) and the player's race level in the big world, which every three levels also opens five more of the race's
 * decorations (their `level`) and room for more things. Where they stand is the Mac's business (offsets from its land's anchor); the server only keeps the list.
 */
import { DECOR_KINDS, type DecorKind } from "./decor-catalog.ts";

export { DECOR_KINDS, type DecorKind };

/** One decoration put down: which, where (points from the camp land's anchor), and turned round or not. */
export interface DecorPlaced {
  kind: string;
  x: number;
  y: number;
  flip?: boolean;
}

/** Decoration room by the camp's look (stage 1–3): a small one takes 1, a middle one 2, a big one 4. */
export const DECOR_ROOM: Record<1 | 2 | 3, number> = { 1: 20, 2: 45, 3: 80 };
/** Each race level past the first (world/leaderboard.ts `raceLevel`) adds this much room, whatever the look. */
export const DECOR_ROOM_PER_LEVEL = 5;
/** However much room there is, no more than this many things (the camp window has to draw them), fences apart. */
export const DECOR_MAX_ITEMS = 120;
/** Fence pieces (category "fence") take no room; this many at most. A closed ring of them is a pen (ranch.ts). */
export const DECOR_MAX_FENCES = 80;
/** Every this many race levels a tier opens: five more decorations a race (the catalogue's `level`), and room for more things. */
export const DECOR_LEVEL_STEP = 3;
/** Each tier opened lets this many more things and this many more fence pieces be put down… */
export const DECOR_MORE_PER_TIER = 10;
/** …up to this many tiers (the last decorations, at level 24): the camp window still has to draw them all. */
export const DECOR_MAX_TIERS = 8;
/** How far from the anchor a decoration may stand (the land is 2200 × 1500 points round it). */
export const DECOR_REACH = 1200;

const BY_ID = new Map(DECOR_KINDS.map((k) => [k.id, k]));

export function decorKind(id: string): DecorKind | undefined {
  return BY_ID.get(id);
}

/** The camp's decoration room: its look's, and more for every race level past the first. */
export function decorRoom(stage: 1 | 2 | 3, raceLevel = 1): number {
  return DECOR_ROOM[stage] + Math.max(0, Math.floor(raceLevel) - 1) * DECOR_ROOM_PER_LEVEL;
}

/** The tiers a race level has opened (0 below level 3). */
export function decorTier(raceLevel: number): number {
  return Math.min(DECOR_MAX_TIERS, Math.max(0, Math.floor(raceLevel / DECOR_LEVEL_STEP)));
}

/** The most things (fences apart) and the most fence pieces, at this race level. */
export function decorLimits(raceLevel = 1): { items: number; fences: number } {
  const more = decorTier(raceLevel) * DECOR_MORE_PER_TIER;
  return { items: DECOR_MAX_ITEMS + more, fences: DECOR_MAX_FENCES + more };
}

export function decorRoomUsed(items: readonly DecorPlaced[]): number {
  return items.reduce((sum, d) => sum + (BY_ID.get(d.kind)?.size ?? 0), 0);
}

/** Why this list cannot be the camp's (null: it can). */
export function decorProblem(items: readonly DecorPlaced[], race: string, stage: 1 | 2 | 3, earned: ReadonlySet<string> = new Set(), raceLevel = 1): string | null {
  const fences = items.filter((d) => BY_ID.get(d.kind)?.category === "fence").length, most = decorLimits(raceLevel);
  if (items.length - fences > most.items) return `最多放 ${most.items} 樣。`;
  if (fences > most.fences) return `柵欄最多 ${most.fences} 段。`;
  for (const d of items) {
    const kind = BY_ID.get(d.kind);
    if (!kind) return "沒有這種裝飾。";
    if (kind.race !== race) return `${kind.name}不是這個種族的裝飾。`;
    if (kind.limited && !earned.has(kind.id)) return `${kind.name}是任務獎勵，還沒拿到。`;
    if (kind.level && raceLevel < kind.level) return `${kind.name}要種族等級 ${kind.level} 級才能放。`;
    if (!Number.isFinite(d.x) || !Number.isFinite(d.y) || Math.abs(d.x) > DECOR_REACH || Math.abs(d.y) > DECOR_REACH) return "裝飾放得太遠了。";
  }
  const used = decorRoomUsed(items), room = decorRoom(stage, raceLevel);
  if (used > room) return `裝飾點數不夠（${used}／${room}）。`;
  return null;
}
