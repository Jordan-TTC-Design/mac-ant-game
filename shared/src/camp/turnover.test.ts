import { describe, expect, it } from "vitest";
import { turnover, TURNOVER_SLOWER, type Population } from "./population.ts";
import { raidCrowd } from "./raids.ts";
import { raceRules } from "./races.ts";

const T0 = Date.parse("2026-10-17T00:00:00Z");
const DAY = 86_400_000;
const place = { race: "elf", key: "home", startedAt: T0, birthMinutes: raceRules("elf").homeBirthMinutes, cap: 20 };
const full = (n = 20): Population => ({
  residents: Array.from({ length: n }, (_, i) => ({ id: i + 1, breed: "common", seed: i, bornAt: T0 + i, diesAt: null, diedAt: null })),
  nextId: n + 1,
  nextSlot: 0,
  peak: n,
});

describe("a full camp turns over (2026-10-17)", () => {
  it("now and then a better newborn takes the oldest common's place, never a common for a common", () => {
    const pop = full();
    const { born, left } = turnover(place, pop, 7, T0, T0 + 2 * DAY);
    expect(born.length).toBeGreaterThan(0);
    expect(born.length).toBe(left.length);
    expect(born.every((b) => b.breed !== "common")).toBe(true);
    expect(left.every((r) => r.breed === "common")).toBe(true);
    expect(left[0]!.id).toBe(1); // (the oldest goes first)
    expect(pop.residents.filter((r) => r.diedAt === null)).toHaveLength(20); // (still full, not more)
    // (a twentieth of the births or so: rolls every TURNOVER_SLOWER slots, most of them common)
    expect(born.length).toBeLessThan((2 * DAY) / (place.birthMinutes * 60_000 * TURNOVER_SLOWER));
  });

  it("not for a camp that is not full, nor on days it was not open on a Mac", () => {
    expect(turnover(place, full(19), 7, T0, T0 + 2 * DAY).born).toHaveLength(0);
    expect(turnover(place, full(), 7, T0, T0 + 2 * DAY, () => false).born).toHaveLength(0);
    const firstDayOnly = turnover(place, full(), 7, T0, T0 + 2 * DAY, (at) => at < T0 + DAY);
    expect(firstDayOnly.born.every((b) => b.bornAt < T0 + DAY)).toBe(true);
  });
});

describe("raids draw more for a crowded camp and many held cells", () => {
  it("adds four from 90% full and one for every three cells, six at most", () => {
    expect(raidCrowd(100, 180, 0)).toBe(0);
    expect(raidCrowd(170, 180, 0)).toBe(4);
    expect(raidCrowd(10, 180, 9)).toBe(3);
    expect(raidCrowd(180, 180, 40)).toBe(10);
  });
});
