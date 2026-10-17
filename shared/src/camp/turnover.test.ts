import { describe, expect, it } from "vitest";
import { turnover, TURNOVER_MAX_SHARE, TURNOVER_SLOWER, turnoverShare, type Population } from "./population.ts";
import { raidCrowd } from "./raids.ts";
import { raceRules } from "./races.ts";

const T0 = Date.parse("2026-10-17T00:00:00Z");
const DAY = 86_400_000;
const place = { race: "elf", key: "home", startedAt: T0, birthMinutes: raceRules("elf").homeBirthMinutes, cap: 100 };
const full = (n = 100): Population => ({
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
    expect(pop.residents.filter((r) => r.diedAt === null)).toHaveLength(100); // (still full, not more)
    // (a twentieth of the births or so: rolls every TURNOVER_SLOWER slots, most of them common)
    expect(born.length).toBeLessThan((2 * DAY) / (place.birthMinutes * 60_000 * TURNOVER_SLOWER));
  });

  it("not for a camp that is not full, nor on days it was not open on a Mac", () => {
    expect(turnover(place, full(99), 7, T0, T0 + 2 * DAY).born).toHaveLength(0);
    expect(turnover(place, full(), 7, T0, T0 + 2 * DAY, () => false).born).toHaveLength(0);
    const firstDayOnly = turnover(place, full(), 7, T0, T0 + 2 * DAY, (at) => at < T0 + DAY);
    expect(firstDayOnly.born.every((b) => b.bornAt < T0 + DAY)).toBe(true);
  });
});

describe("each breed has its share", () => {
  it("never turns a camp past a breed's share, however long it runs: commons stay most of it", () => {
    const pop = full();
    turnover(place, pop, 3, T0, T0 + 120 * DAY); // (a long time: the undead, who never die of age, would end up all rare breeds)
    const alive = pop.residents.filter((r) => r.diedAt === null);
    for (const breed of Object.keys(TURNOVER_MAX_SHARE)) expect(alive.filter((r) => r.breed === breed).length, breed).toBeLessThanOrEqual(alive.length * turnoverShare("elf", breed));
    expect(alive.filter((r) => r.breed === "common").length).toBeGreaterThanOrEqual(alive.length * 0.69);
  });

  it("lets goblins have the most rare ones and the undead the fewest", () => {
    const most = (race: string) => Object.keys(TURNOVER_MAX_SHARE).reduce((n, b) => n + turnoverShare(race, b), 0);
    expect(most("goblin")).toBeGreaterThan(most("elf"));
    expect(most("elf")).toBeGreaterThan(most("undead"));
    expect(most("undead")).toBeLessThan(0.2);
    const pop = full();
    turnover({ ...place, race: "undead" }, pop, 3, T0, T0 + 120 * DAY);
    const alive = pop.residents.filter((r) => r.diedAt === null);
    expect(alive.filter((r) => r.breed === "common").length).toBeGreaterThanOrEqual(alive.length * 0.81);
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
