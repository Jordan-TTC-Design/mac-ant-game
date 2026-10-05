/**
 * The decorations a player puts down in the camp window themselves (DESKTOP.md §5). Each race has its own fifty
 * (decor-catalog.ts, generated from the Mac's drawings), all free for now; how many fit is the camp's decoration room, by
 * its look (stage). Where they stand is the Mac's business (offsets from its land's anchor); the server only keeps the list.
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
/** However much room there is, no more than this many things (the camp window has to draw them), fences apart. */
export const DECOR_MAX_ITEMS = 120;
/** Fence pieces (category "fence") take no room; this many at most. A closed ring of them is a pen (ranch.ts). */
export const DECOR_MAX_FENCES = 80;
/** How far from the anchor a decoration may stand (the land is 2200 × 1500 points round it). */
export const DECOR_REACH = 1200;

const BY_ID = new Map(DECOR_KINDS.map((k) => [k.id, k]));

export function decorKind(id: string): DecorKind | undefined {
  return BY_ID.get(id);
}

export function decorRoomUsed(items: readonly DecorPlaced[]): number {
  return items.reduce((sum, d) => sum + (BY_ID.get(d.kind)?.size ?? 0), 0);
}

/** Why this list cannot be the camp's (null: it can). */
export function decorProblem(items: readonly DecorPlaced[], race: string, stage: 1 | 2 | 3, earned: ReadonlySet<string> = new Set()): string | null {
  const fences = items.filter((d) => BY_ID.get(d.kind)?.category === "fence").length;
  if (items.length - fences > DECOR_MAX_ITEMS) return `最多放 ${DECOR_MAX_ITEMS} 樣。`;
  if (fences > DECOR_MAX_FENCES) return `柵欄最多 ${DECOR_MAX_FENCES} 段。`;
  for (const d of items) {
    const kind = BY_ID.get(d.kind);
    if (!kind) return "沒有這種裝飾。";
    if (kind.race !== race) return `${kind.name}不是這個種族的裝飾。`;
    if (kind.limited && !earned.has(kind.id)) return `${kind.name}是任務獎勵，還沒拿到。`;
    if (!Number.isFinite(d.x) || !Number.isFinite(d.y) || Math.abs(d.x) > DECOR_REACH || Math.abs(d.y) > DECOR_REACH) return "裝飾放得太遠了。";
  }
  const used = decorRoomUsed(items);
  if (used > DECOR_ROOM[stage]) return `裝飾點數不夠（${used}／${DECOR_ROOM[stage]}）。`;
  return null;
}
