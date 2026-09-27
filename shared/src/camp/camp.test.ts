import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { advance, aliveAt, campStage, fall, nextRaidIndex, planRaid, raidTime, RACE_RULES, residentFor, startHome } from "./index.ts";
import { buildFixtures, FIXTURE_SEED, FIXTURE_START } from "./fixtures.ts";

const HOUR = 3_600_000;
const T0 = FIXTURE_START;

describe("births and deaths", () => {
  it("is the same every time it is worked out, all at once or bit by bit", () => {
    const once = startHome("goblin", 7, T0);
    advance(once.place, once.population, 7, T0 + 50 * HOUR);
    const steps = startHome("goblin", 7, T0);
    for (let h = 1; h <= 50; h++) advance(steps.place, steps.population, 7, T0 + h * HOUR);
    expect(steps.population).toEqual(once.population);
  });

  it("gives goblins one every 5 minutes: the third look (150, the big world) in about 12.5 hours", () => {
    const { place, population } = startHome("goblin", 1, T0);
    advance(place, population, 1, T0 + 12 * HOUR);
    expect(aliveAt(population).length).toBe(2 + 12 * 12); // 144 births in 12 hours
    advance(place, population, 1, T0 + 12.5 * HOUR);
    expect(campStage("goblin", population.peak)).toBe(3);
  });

  it("gives elves one every 10 minutes and the undead one every 7.5", () => {
    for (const [race, perHour] of [["elf", 6], ["undead", 8]] as const) {
      const { place, population } = startHome(race, 1, T0);
      advance(place, population, 1, T0 + 10 * HOUR);
      expect(aliveAt(population).length).toBe(2 + 10 * perHour);
    }
  });

  it("never goes over the cap, and fills again after deaths", () => {
    for (const race of ["goblin", "elf", "undead"] as const) {
      const { place, population } = startHome(race, 3, T0);
      for (let h = 1; h <= 24 * 10; h += 5) {
        advance(place, population, 3, T0 + h * HOUR);
        expect(aliveAt(population).length).toBeLessThanOrEqual(RACE_RULES[race].homeCap);
      }
      expect(population.peak).toBe(RACE_RULES[race].homeCap);
    }
  });

  it("lets goblins die of age after about two days (breeds live longer or shorter), and never the undead", () => {
    const goblins = startHome("goblin", 5, T0);
    // the shortest-lived (scouts, 0.8 × 48 hours, give or take 10%) go from about 34.5 hours on
    const g = advance(goblins.place, goblins.population, 5, T0 + 30 * HOUR);
    expect(g.died).toHaveLength(0);
    const later = advance(goblins.place, goblins.population, 5, T0 + 60 * HOUR);
    expect(later.died.length).toBeGreaterThan(0);
    for (const r of goblins.population.residents) if (r.breed === "common") {
      const hours = (r.diesAt! - r.bornAt) / HOUR;
      expect(hours).toBeGreaterThanOrEqual(48 * 0.9);
      expect(hours).toBeLessThanOrEqual(48 * 1.1);
    }
    const undead = startHome("undead", 5, T0);
    expect(advance(undead.place, undead.population, 5, T0 + 24 * 30 * HOUR).died).toHaveLength(0);
  });

  it("frees places when residents fall in battle", () => {
    const { place, population } = startHome("goblin", 9, T0);
    advance(place, population, 9, T0 + 40 * HOUR); // full (300)
    expect(aliveAt(population).length).toBe(300);
    expect(fall(population, [10, 11, 12], T0 + 40 * HOUR).map((r) => r.id)).toEqual([10, 11, 12]);
    const next = advance(place, population, 9, T0 + 40 * HOUR + 15 * 60_000);
    expect(next.born).toHaveLength(3);
    expect(aliveAt(population).length).toBe(300);
  });

  it("works out a month away quickly", () => {
    const started = performance.now();
    const { place, population } = startHome("goblin", 11, T0);
    advance(place, population, 11, T0 + 24 * 30 * HOUR);
    expect(performance.now() - started).toBeLessThan(2000);
    expect(aliveAt(population).length).toBeGreaterThan(250);
  });

  it("picks mostly plain residents and now and then a rare one", () => {
    const place = startHome("goblin", 1, T0).place;
    const counts: Record<string, number> = {};
    for (let slot = 0; slot < 5000; slot++) {
      const r = residentFor(place, 1, slot, slot, T0);
      counts[r.breed] = (counts[r.breed] ?? 0) + 1;
    }
    expect(counts.common! / 5000).toBeGreaterThan(0.75);
    expect(counts.golden).toBeGreaterThan(10);
  });

  it("gives a nest in the big world its own residents", () => {
    const home = residentFor({ race: "goblin", key: "home", startedAt: T0, birthMinutes: 5, cap: 300 }, 1, 0, 1, T0);
    const nest = residentFor({ race: "goblin", key: "cell:1:2", startedAt: T0, birthMinutes: 15, cap: 50 }, 1, 0, 1, T0);
    expect(nest.seed).not.toBe(home.seed);
  });
});

describe("the looks of the camp", () => {
  it("follows each race's numbers", () => {
    expect([campStage("goblin", 49), campStage("goblin", 50), campStage("goblin", 150)]).toEqual([1, 2, 3]);
    expect([campStage("elf", 29), campStage("elf", 30), campStage("elf", 90)]).toEqual([1, 2, 3]);
    expect([campStage("undead", 39), campStage("undead", 40), campStage("undead", 120)]).toEqual([1, 2, 3]);
  });
});

describe("raids", () => {
  it("come about every 90 minutes for goblins, give or take", () => {
    const times = Array.from({ length: 20 }, (_, i) => raidTime("goblin", 4, T0, i));
    for (let i = 1; i < times.length; i++) {
      const gap = (times[i]! - times[i - 1]!) / 60_000;
      expect(gap).toBeGreaterThan(30);
      expect(gap).toBeLessThan(150);
    }
    expect(nextRaidIndex("goblin", 4, T0, times[5]!)).toBe(6);
  });

  it("skip a small camp, and grow with the camp", () => {
    expect(planRaid("goblin", 4, T0, 0, 5)).toBeNull();
    const small = planRaid("goblin", 4, T0, 0, 20)!;
    const big = planRaid("goblin", 4, T0, 0, 250)!;
    const size = (p: typeof small) => p.monsters.reduce((n, m) => n + m.count, 0);
    expect(size(big)).toBeGreaterThan(size(small));
    expect(small.monsters.every((m) => ["slime", "giant_rat"].includes(m.id))).toBe(true);
  });
});

describe("fixtures.json (what the Mac's Swift copy must match)", () => {
  it("matches the rules as they are now", () => {
    const saved = JSON.parse(readFileSync(new URL("./fixtures.json", import.meta.url), "utf8"));
    expect(saved).toEqual(JSON.parse(JSON.stringify(buildFixtures())));
    expect(saved.seed).toBe(FIXTURE_SEED);
  });
});
