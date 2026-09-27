/**
 * The leaderboard (WORLD.md §7): for now it goes by population, fighting strength and race level.
 *
 * Race level: a race grows by what its camp does in the big world. Experience comes from clearing lairs (more for higher
 * levels), winning against other players, holding cells day after day, and building towns; the level rises with the square
 * root of it, so the first levels come quickly and the later ones slowly.
 */

export const XP = {
  /** Per level of the lair cleared. */
  lairClearedPerLevel: 20,
  playerWin: 60,
  /** Per held cell, per day. */
  cellDay: 10,
  townBuilt: 200,
} as const;

/** Level 1 at 0 experience, level 2 at 50, 3 at 200, 4 at 450… */
export function raceLevel(xp: number): number {
  return Math.floor(Math.sqrt(Math.max(0, xp) / 50)) + 1;
}

export function xpForLevel(level: number): number {
  return 50 * (level - 1) ** 2;
}

export interface LeaderboardEntry {
  player: string;
  name: string;
  race: string;
  /** Residents in the camp and on every held cell. */
  population: number;
  /** combatPower() of all of them. */
  power: number;
  xp: number;
  cells: number;
}

/** One number to rank by: every resident counts, strength counts, and each race level is worth a good deal. */
export function score(entry: LeaderboardEntry): number {
  return entry.population * 10 + entry.power + (raceLevel(entry.xp) - 1) * 150;
}

export interface RankedEntry extends LeaderboardEntry {
  rank: number;
  level: number;
  score: number;
}

/** Highest score first; a tie goes to the larger population, then the name. Equal scores share a rank. */
export function rank(entries: LeaderboardEntry[]): RankedEntry[] {
  const scored = entries.map((e) => ({ ...e, level: raceLevel(e.xp), score: score(e) }));
  scored.sort((a, b) => b.score - a.score || b.population - a.population || a.name.localeCompare(b.name));
  let last: number | null = null;
  let lastRank = 0;
  return scored.map((e, i) => {
    const r = e.score === last ? lastRank : i + 1;
    last = e.score;
    lastRank = r;
    return { ...e, rank: r };
  });
}

/** Separate boards per race (so a slow-growing race is not always at the bottom). */
export function rankByRace(entries: LeaderboardEntry[]): Record<string, RankedEntry[]> {
  const out: Record<string, RankedEntry[]> = {};
  for (const race of new Set(entries.map((e) => e.race))) out[race] = rank(entries.filter((e) => e.race === race));
  return out;
}
