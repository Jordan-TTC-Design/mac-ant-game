import { describe, expect, it } from "vitest";
import { GUILD_SEASONS, guildSeason, seasonDay, seasonNear, seasonOpen, seasonRange, seasonWindow, taipeiDay } from "./guild-seasons.ts";

const s = (id: string) => guildSeason(id)!;

describe("節日限定的日子", () => {
  it("works the lunar holidays out for each year", () => {
    // (years whose new moon is minutes from midnight are left out: calendars differ by a day there, and a season is two weeks)
    expect([2026, 2028].map((y) => seasonDay(s("spring_festival"), y))).toEqual(["2026-02-17", "2028-01-26"]);
    expect(seasonDay(s("lantern"), 2026)).toBe("2026-03-03");
    expect(seasonDay(s("dragon_boat"), 2026)).toBe("2026-06-19");
    expect([2026, 2028].map((y) => seasonDay(s("mid_autumn"), y))).toEqual(["2026-09-25", "2028-10-03"]);
    expect(seasonDay(s("national"), 2026)).toBe("2026-10-10");
  });

  it("is on from some days before the day to a few after, and off outside", () => {
    expect(seasonWindow(s("mid_autumn"), 2026)).toEqual({ from: "2026-09-15", to: "2026-09-29" });
    expect(seasonOpen(s("mid_autumn"), "2026-09-14")).toBe(false);
    expect(seasonOpen(s("mid_autumn"), "2026-09-15")).toBe(true);
    expect(seasonOpen(s("mid_autumn"), "2026-09-29")).toBe(true);
    expect(seasonOpen(s("mid_autumn"), "2026-09-30")).toBe(false);
  });

  it("runs over the new year (跨年, 春節 in January)", () => {
    expect(seasonOpen(s("new_year"), "2026-12-22")).toBe(true);
    expect(seasonOpen(s("new_year"), "2027-01-04")).toBe(true);
    expect(seasonOpen(s("new_year"), "2027-01-05")).toBe(false);
    // (春節 2028 is on January 26: its season starts on the 16th)
    expect(seasonOpen(s("spring_festival"), "2028-01-16")).toBe(true);
    expect(seasonOpen(s("spring_festival"), "2028-01-15")).toBe(false);
  });

  it("says when a season is on or when it is next", () => {
    expect(seasonNear(s("mid_autumn"), "2026-09-20")).toEqual({ from: "2026-09-15", to: "2026-09-29", on: true });
    expect(seasonNear(s("national"), "2026-10-20")).toEqual({ from: "2027-10-03", to: "2027-10-13", on: false });
    expect(seasonRange({ from: "2027-10-03", to: "2027-10-13" })).toBe("10/3～10/13");
  });

  it("takes the day in Taiwan", () => {
    expect(taipeiDay(new Date("2026-09-24T17:00:00Z"))).toBe("2026-09-25"); // (01:00 there)
    expect(taipeiDay(new Date("2026-09-25T15:59:00Z"))).toBe("2026-09-25");
  });

  it("has unique seasons, each with a day", () => {
    expect(new Set(GUILD_SEASONS.map((x) => x.id)).size).toBe(GUILD_SEASONS.length);
    for (const season of GUILD_SEASONS) for (const y of [2026, 2027, 2028, 2029, 2030]) expect(seasonDay(season, y), `${season.id} ${y}`).toBeTruthy();
  });
});
