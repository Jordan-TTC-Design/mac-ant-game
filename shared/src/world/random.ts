/**
 * Seeded randomness for the big world. The same inputs always give the same numbers, so what is in a cell, how a battle
 * goes and what it drops can be worked out again from the seed (the server stores seeds, not whole worlds or whole battles).
 */

/** A 32-bit hash of a string (FNV-1a with a final mix, so similar strings give unrelated numbers). */
export function hashString(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b);
  h ^= h >>> 13;
  h = Math.imul(h, 0xc2b2ae35);
  h ^= h >>> 16;
  return h >>> 0;
}

/** A generator of numbers in [0, 1) (mulberry32). */
export type Random = () => number;

export function randomFrom(seed: number): Random {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** A generator seeded from several parts, e.g. `seeded(worldSeed, cellId, "lair")`. */
export function seeded(...parts: (string | number)[]): Random {
  return randomFrom(hashString(parts.join("|")));
}

/** A whole number in [min, max]. */
export function between(random: Random, min: number, max: number): number {
  return min + Math.floor(random() * (max - min + 1));
}

/** One item, picked with the given weights. */
export function pickWeighted<T>(random: Random, items: readonly T[], weight: (item: T) => number): T {
  const total = items.reduce((sum, item) => sum + Math.max(0, weight(item)), 0);
  let roll = random() * total;
  for (const item of items) {
    roll -= Math.max(0, weight(item));
    if (roll < 0) return item;
  }
  const last = items[items.length - 1];
  if (last === undefined) throw new Error("pickWeighted: no items");
  return last;
}
