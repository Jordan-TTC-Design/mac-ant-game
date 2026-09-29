import { describe, expect, it } from "vitest";
import { FARM_KEEP, farmCrops, nextFarmLevel, produce, productionPerHour, WORKERS_MAX } from "./production.ts";
import { MATERIALS } from "../world/drops.ts";
import { unopenedGear } from "../world/availability.ts";

const HOUR = 3_600_000;
const T0 = Date.UTC(2026, 8, 29);

describe("what the camp makes", () => {
  it("fells and digs more with more at home, up to WORKERS_MAX", () => {
    const small = productionPerHour("goblin", 0, 1);
    const big = productionPerHour("goblin", WORKERS_MAX, 1);
    expect(small.log).toBe(1);
    expect(big.log).toBeCloseTo(5);
    expect(big.stone).toBeCloseTo(2.5);
    expect(productionPerHour("goblin", 500, 1)).toEqual(big);
  });

  it("follows each race's knack (elves pick up branches, the undead love to dig)", () => {
    const g = productionPerHour("goblin", 30, 1), e = productionPerHour("elf", 30, 1), u = productionPerHour("undead", 30, 1);
    expect(e.log).toBeCloseTo(g.log! * 0.7);
    expect(u.log).toBeCloseTo(g.log! * 0.8);
    expect(u.stone).toBeCloseTo(g.stone! * 1.5);
  });

  it("grows a crop more at every farm level; each race its own at level 2; level 5 ×1.5", () => {
    expect(farmCrops("goblin", 1).map((c) => c.food)).toEqual(["food_carrot"]);
    expect(farmCrops("goblin", 4).map((c) => c.food)).toEqual(["food_carrot", "ration_bread", "food_honey", "food_cheese"]);
    expect(farmCrops("elf", 2).map((c) => c.food)).toEqual(["food_carrot", "ration_berry"]);
    expect(farmCrops("undead", 2).map((c) => c.food)).toEqual(["food_carrot", "ration_jerky"]);
    expect(productionPerHour("goblin", 0, 2).ration_bread).toBeCloseTo(0.5);
    expect(productionPerHour("goblin", 0, 5).ration_bread).toBeCloseTo(0.75);
    expect(nextFarmLevel(1)?.cost).toEqual({ log: 60, stone: 30 });
    expect(nextFarmLevel(5)).toBeNull();
  });

  it("adds up by the hour, carrying the fractions, the same all at once or bit by bit", () => {
    const base = { race: "goblin", seed: 7, workers: 20, farmLevel: 2, store: {} as Record<string, number> };
    const once = produce({ ...base, from: T0, to: T0 + 30 * HOUR + 1234, carry: {} });
    expect(once.to).toBe(T0 + 30 * HOUR);
    let carry: Record<string, number> = {};
    let from = T0;
    const sum: Record<string, number> = {};
    for (let h = 1; h <= 30; h++) {
      const step = produce({ ...base, from, to: T0 + h * HOUR + 500, carry });
      for (const [id, n] of Object.entries(step.got)) sum[id] = (sum[id] ?? 0) + n;
      carry = step.carry;
      from = step.to;
    }
    expect(sum).toEqual(once.got);
    expect(once.got.log).toBe(70); // 30 × (1 + 20 ÷ 15)
    expect(once.got.ration_bread).toBe(15);
    expect(once.got.food_carrot).toBe(10);
  });

  it("turns up scrap iron now and then, crystal rarely", () => {
    const got = produce({ race: "goblin", seed: 3, workers: 60, farmLevel: 1, from: T0, to: T0 + 1000 * HOUR, carry: {}, store: {} }).got;
    expect(got.scrap_iron).toBeGreaterThan(150);
    expect(got.scrap_iron).toBeLessThan(250);
    expect(got.crystal_shard).toBeGreaterThan(5);
    expect(got.crystal_shard).toBeLessThan(40);
  });

  it("stops growing a food while the store holds FARM_KEEP of it (wood and stone go on)", () => {
    const got = produce({ race: "goblin", seed: 1, workers: 0, farmLevel: 1, from: T0, to: T0 + 300 * HOUR, carry: {}, store: { food_carrot: FARM_KEEP - 2 } }).got;
    expect(got.food_carrot).toBe(2);
    expect(produce({ race: "goblin", seed: 1, workers: 0, farmLevel: 1, from: T0, to: T0 + 30 * HOUR, carry: {}, store: { food_carrot: FARM_KEEP } }).got.food_carrot).toBeUndefined();
    expect(got.log).toBe(300);
  });

  it("names wood and stone, and the gear made of them can be made now", () => {
    expect(MATERIALS.log?.name).toBe("木材");
    expect(MATERIALS.stone?.name).toBe("石頭");
    for (const id of ["wood_club", "stone_axe", "stone_spear", "bark_buckler", "bark_vest", "stone_cap"]) expect(unopenedGear()).not.toContain(id);
  });
});
