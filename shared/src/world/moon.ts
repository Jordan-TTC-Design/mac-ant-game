/**
 * The full moon (RACES_BEAST.md §4): the beastfolk go into a frenzy on the nights of the 14th, 15th and 16th of the lunar
 * month, worked out from the calendar in Taiwan's time (Asia/Taipei), as the Mac's `Colony.fullMoonNight` does: night is
 * 20:00 to 6:00, and a night belongs to the evening it began on (the date 6 hours earlier). Nothing is stored; the Mac, the
 * server and the phones all work it out the same way. The server's answer is the one that counts in fights.
 */

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
/** Taiwan's clock: UTC+8 all year (no summer time). */
const TAIPEI = 8 * HOUR;
/** Night in Taiwan: from this hour to NIGHT_ENDS (the Mac's Colony.isNight). */
export const NIGHT_STARTS = 20;
export const NIGHT_ENDS = 6;
/** The lunar days whose nights are full-moon nights (農曆十四到十六). */
export const FULL_MOON_DAYS: readonly number[] = [14, 15, 16];

/** The beastfolk on a full-moon night (the Mac's manifest `rules.moon`): attack ×, speed ×, hits taken ×. */
export const BEAST_MOON = { might: 1.4, speed: 1.15, hurt: 1.25 } as const;

const LUNAR_DAY = new Intl.DateTimeFormat("zh-TW-u-ca-chinese", { timeZone: "Asia/Taipei", day: "numeric" });
const NUMERALS: Record<string, number> = { 一: 1, 二: 2, 三: 3, 四: 4, 五: 5, 六: 6, 七: 7, 八: 8, 九: 9, 十: 10 };

/** "14" / "14日" / "十四" / "初四" / "廿三" → the number (NaN if it is none of these). */
function parseLunarDay(text: string): number {
  const digits = /\d+/.exec(text);
  if (digits) return Number(digits[0]);
  const s = text.replace(/[初日號号]/g, "").replace(/^廿/, "二十").replace(/^卅/, "三十");
  if (!s) return NaN;
  if (s === "十") return 10;
  const ten = s.indexOf("十");
  if (ten < 0) return s.length === 1 ? (NUMERALS[s] ?? NaN) : NaN;
  const tens = ten === 0 ? 1 : (NUMERALS[s.slice(0, ten)] ?? NaN);
  const ones = ten === s.length - 1 ? 0 : (NUMERALS[s.slice(ten + 1)] ?? NaN);
  return tens * 10 + ones;
}

/** The day of the lunar month (1…30) it is in Taiwan at `at`. */
export function lunarDay(at: Date): number {
  const parts = LUNAR_DAY.formatToParts(at);
  const day = parts.find((p) => p.type === "day")?.value;
  return parseLunarDay(day ?? LUNAR_DAY.format(at));
}

/** The hour in Taiwan (0…23.99). */
function taipeiHour(at: Date): number {
  return ((((at.getTime() + TAIPEI) % DAY) + DAY) % DAY) / HOUR;
}

/** Night in Taiwan (20:00 to 6:00). */
export function taipeiNight(at: Date): boolean {
  const h = taipeiHour(at);
  return h >= NIGHT_STARTS || h < NIGHT_ENDS;
}

/** The lunar day of the evening the night (or day) at `at` belongs to: the lunar day 6 hours earlier. */
export function moonDay(at: Date): number {
  return lunarDay(new Date(at.getTime() - NIGHT_ENDS * HOUR));
}

/** Whether `at` is a full-moon night: night in Taiwan, of an evening on the lunar 14th, 15th or 16th. */
export function isFullMoonNight(at: Date): boolean {
  return taipeiNight(at) && FULL_MOON_DAYS.includes(moonDay(at));
}

/** The beastfolk's frenzy at `at` (1 on a full-moon night, else 0): FightBoosts.frenzy. Other races: 0. */
export function moonFrenzy(race: string, at: Date | number): number {
  return race === "beast" && isFullMoonNight(typeof at === "number" ? new Date(at) : at) ? 1 : 0;
}

/**
 * The full-moon night going on at `at`, or the next one: when it starts and ends (20:00 to 6:00 in Taiwan). For saying
 * "tonight is a full moon" or "the next full moon is …".
 */
export function nextFullMoon(at: Date): { from: Date; to: Date } {
  // (the evening of the day the moment belongs to, 20:00 in Taiwan)
  const local = at.getTime() + TAIPEI - NIGHT_ENDS * HOUR;
  const evening = Math.floor(local / DAY) * DAY + NIGHT_STARTS * HOUR - TAIPEI;
  for (let i = 0; i < 40; i++) {
    const from = evening + i * DAY;
    const to = from + (24 - NIGHT_STARTS + NIGHT_ENDS) * HOUR;
    if (to > at.getTime() && FULL_MOON_DAYS.includes(lunarDay(new Date(from)))) return { from: new Date(from), to: new Date(to) };
  }
  throw new Error("no full moon within 40 days");
}
