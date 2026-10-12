/**
 * Holiday decorations (GUILD.md §4.2, 節日限定): a piece of a season can be put down while the season is on, from some days before
 * the holiday to a few after. What is already in the hall stays (and can be moved or taken away) when the season is over; it just
 * cannot be put down again until the next one. The days are Taiwan's (Asia/Taipei), and the lunar holidays move every year, so
 * they are worked out from the lunar calendar. Only the server works them out (platforms' lunar calendars differ by a day in
 * some years): it checks what is put down, and sends every season's days with the guild (`guildSeasonViews`) for the Mac and
 * the phones to show.
 */

export interface GuildSeason {
  id: string;
  name: string;
  /** The holiday itself: a lunar month and day (not a leap month), or a month and day of the year. */
  lunar?: readonly [number, number];
  solar?: readonly [number, number];
  /** Days of the season before and after the holiday's day. */
  before: number;
  after: number;
}

export const GUILD_SEASONS: readonly GuildSeason[] = [
  { id: "spring_festival", name: "春節", lunar: [1, 1], before: 10, after: 5 },
  { id: "lantern", name: "元宵", lunar: [1, 15], before: 4, after: 3 },
  { id: "dragon_boat", name: "端午", lunar: [5, 5], before: 10, after: 4 },
  { id: "mid_autumn", name: "中秋", lunar: [8, 15], before: 10, after: 4 },
  { id: "national", name: "國慶", solar: [10, 10], before: 7, after: 3 },
  { id: "new_year", name: "跨年", solar: [12, 31], before: 9, after: 4 },
  { id: "christmas", name: "聖誕", solar: [12, 25], before: 14, after: 1 },
];

const BY_ID = new Map(GUILD_SEASONS.map((s) => [s.id, s]));
export function guildSeason(id: string): GuildSeason | undefined {
  return BY_ID.get(id);
}

const TAIPEI = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Taipei", year: "numeric", month: "2-digit", day: "2-digit" });
/** The day it is in Taiwan, as "yyyy-mm-dd". */
export function taipeiDay(at: Date): string {
  return TAIPEI.format(at);
}

const pad = (n: number) => String(n).padStart(2, "0");
const ymd = (ms: number) => {
  const d = new Date(ms);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
};
const DAY = 86_400_000;
const dayMs = (day: string) => {
  const [y, m, d] = day.split("-").map(Number) as [number, number, number];
  return Date.UTC(y, m - 1, d);
};

const LUNAR = new Intl.DateTimeFormat("en-u-ca-chinese", { timeZone: "Asia/Taipei", month: "numeric", day: "numeric" });
const lunarYears = new Map<number, Map<string, string>>();
/** The days of a year that are a lunar month's day (a leap month's not counted): "month-day" → "yyyy-mm-dd". */
function lunarDays(year: number): Map<string, string> {
  let table = lunarYears.get(year);
  if (!table) {
    table = new Map();
    const start = Date.UTC(year, 0, 1, 4); // (noon in Taiwan)
    for (let i = 0; i < 366; i++) {
      const at = start + i * DAY;
      if (new Date(at).getUTCFullYear() !== year) break;
      const parts = LUNAR.formatToParts(new Date(at));
      const month = parts.find((p) => p.type === "month")?.value ?? "";
      const day = parts.find((p) => p.type === "day")?.value ?? "";
      if (/^\d+$/.test(month) && !table.has(`${month}-${day}`)) table.set(`${month}-${day}`, ymd(at));
    }
    lunarYears.set(year, table);
  }
  return table;
}

/** The holiday's day in this year ("yyyy-mm-dd"), or null if there is none. */
export function seasonDay(season: GuildSeason, year: number): string | null {
  if (season.solar) return `${year}-${pad(season.solar[0])}-${pad(season.solar[1])}`;
  if (season.lunar) return lunarDays(year).get(`${season.lunar[0]}-${season.lunar[1]}`) ?? null;
  return null;
}

/** The season around the holiday of this year: its first and last day. */
export function seasonWindow(season: GuildSeason, year: number): { from: string; to: string } | null {
  const day = seasonDay(season, year);
  if (!day) return null;
  return { from: ymd(dayMs(day) - season.before * DAY), to: ymd(dayMs(day) + season.after * DAY) };
}

/** Whether the season is on `today` ("yyyy-mm-dd"). */
export function seasonOpen(season: GuildSeason, today: string): boolean {
  const year = Number(today.slice(0, 4));
  for (const y of [year - 1, year, year + 1]) {
    const w = seasonWindow(season, y);
    if (w && today >= w.from && today <= w.to) return true;
  }
  return false;
}

/** The season that is on now, or the next one to come (to say when a closed piece comes back). */
export function seasonNear(season: GuildSeason, today: string): { from: string; to: string; on: boolean } {
  const year = Number(today.slice(0, 4));
  for (const y of [year - 1, year, year + 1, year + 2]) {
    const w = seasonWindow(season, y);
    if (w && w.to >= today) return { ...w, on: w.from <= today };
  }
  return { from: today, to: today, on: false };
}

/** "2/7～2/22". */
export function seasonRange(w: { from: string; to: string }): string {
  const md = (d: string) => `${Number(d.slice(5, 7))}/${Number(d.slice(8, 10))}`;
  return `${md(w.from)}～${md(w.to)}`;
}

/** What the guild's answer says about each season: when it is on (or next on), and whether it is on today. */
export interface GuildSeasonView {
  id: string;
  name: string;
  from: string;
  to: string;
  on: boolean;
}

export function guildSeasonViews(today: string): GuildSeasonView[] {
  return GUILD_SEASONS.map((s) => ({ id: s.id, name: s.name, ...seasonNear(s, today) }));
}
