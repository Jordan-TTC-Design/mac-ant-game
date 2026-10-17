import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { buildingEffects, buildingNext, CAMP_BUILDINGS, FOOD_KEEP_BY_WAREHOUSE } from "./buildings.ts";
import { FARM_KEEP } from "./production.ts";

describe("營地建設 (ECONOMY.md §1.3)", () => {
  it("has six, three levels each, costing mostly logs and stones and known materials", () => {
    expect(CAMP_BUILDINGS.map((b) => b.id)).toEqual(["wall", "warehouse", "clinic", "training", "banquet", "watchtower"]);
    for (const b of CAMP_BUILDINGS) for (const c of b.costs) {
      for (const id of Object.keys(c)) expect(MATERIALS[id], `${b.id}: ${id}`).toBeDefined();
      expect((c.log ?? 0) + (c.stone ?? 0)).toBeGreaterThan(Object.entries(c).filter(([id]) => id !== "log" && id !== "stone").reduce((n, [, v]) => n + v, 0));
    }
  });

  it("does nothing unbuilt, and more each level", () => {
    const none = buildingEffects({});
    expect(none).toMatchObject({ raidMonsterAttack: 0, foodKeep: FARM_KEEP, heal: 0, raidDefenderHp: 0, visitorChance: 0, merchantMore: false, bossAttack: 0 });
    const all = buildingEffects({ wall: { level: 3 }, warehouse: { level: 2 }, banquet: { level: 2 }, watchtower: { level: 1, busyUntil: "2099-01-01T00:00:00Z" } });
    expect(all.raidMonsterAttack).toBeCloseTo(0.15);
    expect(all.foodKeep).toBe(FOOD_KEEP_BY_WAREHOUSE[2]);
    expect(all.merchantMore).toBe(true);
    expect(all.bossAttack).toBeCloseTo(0.1); // (the second level going up: still the first's)
  });

  it("takes longer each level, sooner with the 巧手 talent, and stops at 3", () => {
    expect(buildingNext("wall", 0)).toEqual({ cost: { log: 500, stone: 800 }, hours: 4 });
    expect(buildingNext("wall", 2, 0.2)!.hours).toBeCloseTo(24 * 0.8);
    expect(buildingNext("wall", 3)).toBeNull();
  });
});
