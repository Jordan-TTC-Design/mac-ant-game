/**
 * Monster raids on the home camp (server/CAMP.md §11): when they come and what comes. Only the server uses this (a Mac
 * that is offline sees no raids; the fight itself is worked out with the big world's battle rules and played back).
 */
import { hashString, randomFrom } from "../world/random.ts";
import { raceRules } from "./races.ts";

const MINUTE = 60_000;

/** The camp's monsters, weakest first (mac/Resources/Animals: the hostile ones and their levels). */
export const CAMP_MONSTERS = [
  { id: "slime", level: 1 },
  { id: "giant_rat", level: 1 },
  { id: "bat", level: 2 },
  { id: "frog", level: 2 },
] as const;

/** No raids on a camp smaller than this (the first monsters wait until there is someone to fight them). */
export const RAID_MIN_RESIDENTS = 10;

export interface RaidPlan {
  /** Which raid of the camp (0, 1, 2…). */
  index: number;
  at: number;
  monsters: { id: string; count: number }[];
}

/** When raid number `index` comes: every `raidEveryMinutes`, give or take 30%. */
export function raidTime(race: string, campSeed: number, startedAt: number, index: number): number {
  const every = raceRules(race).raidEveryMinutes * MINUTE;
  const random = randomFrom(hashString(`${campSeed}|raid-time|${index}`));
  return startedAt + (index + 1) * every + Math.floor((random() * 0.6 - 0.3) * every);
}

/** The first raid that comes after `time`. */
export function nextRaidIndex(race: string, campSeed: number, startedAt: number, time: number): number {
  const every = raceRules(race).raidEveryMinutes * MINUTE;
  let index = Math.max(0, Math.floor((time - startedAt) / every) - 2);
  while (raidTime(race, campSeed, startedAt, index) <= time) index++;
  return index;
}

/**
 * What comes on raid `index`, for a camp with `residents` living at home then (null when the camp is too small and it
 * passes by). A bigger camp draws bigger raids, and from 60 residents the stronger monsters come too.
 */
export function planRaid(race: string, campSeed: number, startedAt: number, index: number, residents: number): RaidPlan | null {
  if (residents < RAID_MIN_RESIDENTS) return null;
  const random = randomFrom(hashString(`${campSeed}|raid|${index}`));
  const kinds = CAMP_MONSTERS.filter((m) => m.level <= (residents >= 60 ? 2 : 1));
  const total = Math.min(12, 2 + Math.floor(residents / 30) + Math.floor(random() * 3));
  const counts = new Map<string, number>();
  for (let i = 0; i < total; i++) {
    const kind = kinds[Math.floor(random() * kinds.length)]!;
    counts.set(kind.id, (counts.get(kind.id) ?? 0) + 1);
  }
  return { index, at: raidTime(race, campSeed, startedAt, index), monsters: [...counts].map(([id, count]) => ({ id, count })) };
}
