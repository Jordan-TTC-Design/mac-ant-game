import { describe, expect, it } from "vitest";
import { fightBoosts } from "../camp/food.ts";
import { combatPower, residentFighter, simulateBattle, type Fighter } from "./battle.ts";
import { BEAST_MOON, isFullMoonNight, lunarDay, moonDay, moonFrenzy, nextFullMoon, taipeiNight } from "./moon.ts";

const tw = (s: string) => new Date(`${s}+08:00`);

describe("the full moon (RACES_BEAST.md §4)", () => {
  it("reads the lunar day in Taiwan", () => {
    expect(lunarDay(tw("2026-10-23T12:00:00"))).toBe(14);
    expect(lunarDay(tw("2026-10-25T12:00:00"))).toBe(16);
    expect(lunarDay(tw("2026-10-26T12:00:00"))).toBe(17);
  });

  it("is a full-moon night on the evenings of the lunar 14th to 16th", () => {
    for (const d of ["2026-10-23", "2026-10-24", "2026-10-25", "2026-11-22", "2026-11-23", "2026-11-24", "2026-12-22", "2026-12-23", "2026-12-24"]) {
      expect(isFullMoonNight(tw(`${d}T22:00:00`)), d).toBe(true);
    }
    expect(isFullMoonNight(tw("2026-10-26T22:00:00"))).toBe(false);
    expect(isFullMoonNight(tw("2026-10-22T22:00:00"))).toBe(false);
  });

  it("counts the small hours as the night before, and the day not at all", () => {
    expect(moonDay(tw("2026-10-25T03:00:00"))).toBe(15);
    expect(isFullMoonNight(tw("2026-10-25T03:00:00"))).toBe(true); // (still the night of the 24th)
    expect(isFullMoonNight(tw("2026-10-26T03:00:00"))).toBe(true); // (the night of the 25th, the 16th)
    expect(isFullMoonNight(tw("2026-10-27T03:00:00"))).toBe(false);
    expect(isFullMoonNight(tw("2026-10-23T12:00:00"))).toBe(false); // (day)
    expect(isFullMoonNight(tw("2026-10-23T19:59:00"))).toBe(false);
    expect(isFullMoonNight(tw("2026-10-23T20:00:00"))).toBe(true);
    expect(isFullMoonNight(tw("2026-10-24T05:59:00"))).toBe(true);
    expect(isFullMoonNight(tw("2026-10-24T06:00:00"))).toBe(false);
  });

  it("night is 20:00 to 6:00 in Taiwan whatever the server's clock", () => {
    expect(taipeiNight(new Date("2026-10-23T12:00:00Z"))).toBe(true); // (20:00 in Taiwan)
    expect(taipeiNight(new Date("2026-10-23T11:59:00Z"))).toBe(false);
    expect(taipeiNight(new Date("2026-10-23T22:00:00Z"))).toBe(false); // (6:00 the next morning)
  });

  it("frenzies only the beastfolk", () => {
    const at = tw("2026-10-24T22:00:00");
    expect(moonFrenzy("beast", at)).toBe(1);
    expect(moonFrenzy("beast", at.getTime())).toBe(1);
    expect(moonFrenzy("undead", at)).toBe(0);
    expect(moonFrenzy("beast", tw("2026-10-24T12:00:00"))).toBe(0);
  });

  it("finds the full moon going on or the next one", () => {
    expect(nextFullMoon(tw("2026-10-18T12:00:00"))).toEqual({ from: tw("2026-10-23T20:00:00"), to: tw("2026-10-24T06:00:00") });
    expect(nextFullMoon(tw("2026-10-25T03:00:00"))).toEqual({ from: tw("2026-10-24T20:00:00"), to: tw("2026-10-25T06:00:00") });
    expect(nextFullMoon(tw("2026-10-26T12:00:00")).from).toEqual(tw("2026-11-22T20:00:00"));
  });
});

describe("the beastfolk's frenzy in the big world's fights", () => {
  const full = tw("2026-10-24T22:00:00").getTime();
  const day = tw("2026-10-24T12:00:00").getTime();
  const wolf = { id: "1", name: "灰牙", breed: "common", might: 1, health: 1, speed: 1 };
  const beasts = { id: "beast", ranged: 0 };

  it("is on in a beast camp's fight boosts at the moment asked about only", () => {
    expect(fightBoosts("beast", {}, full).frenzy).toBe(1);
    expect(fightBoosts("beast", {}, day).frenzy).toBeUndefined();
    expect(fightBoosts("undead", {}, full).frenzy).toBeUndefined();
  });

  it("hits harder, moves quicker, and is hurt more", () => {
    const calm = residentFighter(wolf, "attack", beasts, fightBoosts("beast", {}, day));
    const wild = residentFighter(wolf, "attack", beasts, fightBoosts("beast", {}, full));
    expect(wild.attack).toBeCloseTo(calm.attack * BEAST_MOON.might);
    expect(wild.speed).toBeCloseTo(calm.speed * BEAST_MOON.speed);
    expect(wild.hp).toBe(calm.hp);
    expect(calm.frailty).toBeUndefined();
    expect(wild.frailty).toBeCloseTo(BEAST_MOON.hurt);
    // (stronger all told, by less than the attack alone: √(1.4 × quicker ÷ 1.25), about 1.08)
    const ratio = combatPower(Array(50).fill(wild)) / combatPower(Array(50).fill(calm));
    expect(ratio).toBeGreaterThan(1.05);
    expect(ratio).toBeLessThan(1.12);
  });

  it("takes a quarter more from every hit", () => {
    const dummy = (frailty?: number): Fighter => ({ id: "d", name: "d", side: "defend", row: "front", hp: 10_000, maxHp: 10_000, attack: 0, range: 0, speed: 0.1, heal: 0, guard: 0, lead: 0, night: 1, ...(frailty ? { frailty } : {}) });
    const hitter: Fighter = { id: "a", name: "a", side: "attack", row: "front", hp: 100, maxHp: 100, attack: 100, range: 0, speed: 1, heal: 0, guard: 0, lead: 0, night: 1 };
    const taken = (f?: number) => simulateBattle([hitter], [dummy(f)], { seed: 3, maxRounds: 20 }).events.filter((e) => e.kind === "hit").reduce((n, e) => n + (e.amount ?? 0), 0);
    expect(taken(BEAST_MOON.hurt) / taken()).toBeCloseTo(BEAST_MOON.hurt, 2);
  });
});
