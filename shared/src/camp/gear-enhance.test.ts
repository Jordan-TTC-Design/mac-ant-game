import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { ITEMS } from "../world/supplies.ts";
import { enhanceCost, ENHANCE_MAX, GEAR, gearBonus, gearMax, gearOwnMaterial, gearPower, gearRule, REFINE_BONUS } from "./gear.ts";
import { SITE_RULES } from "./sites.ts";

describe("gear for every material (ECONOMY.md §1.1)", () => {
  it("leaves no material without a use (food and items are eaten and used, 換族的信物 spent on switching, not made into gear)", () => {
    const used = new Set([...GEAR.flatMap((g) => Object.keys(g.cost)), ...ITEMS.flatMap((i) => Object.keys(i.cost)), ...SITE_RULES.flatMap((s) => s.costs.flatMap((c) => Object.keys(c)))]);
    const idle = Object.keys(MATERIALS).filter((id) => !used.has(id) && !/^(ration_|food_|item_|token_)/.test(id));
    expect(idle).toEqual([]);
    for (const g of GEAR) for (const id of Object.keys(g.cost)) expect(MATERIALS[id], `${g.id} needs ${id}`).toBeDefined();
    expect(new Set(GEAR.map((g) => g.id)).size).toBe(GEAR.length);
  });

  it("grows stronger tier by tier, the world bosses' legendary at the top", () => {
    const best = (tier: number | undefined) => Math.max(...GEAR.filter((g) => g.tier === tier && g.slot === "weapon").map((g) => g.might ?? 0));
    expect(best(2)).toBeLessThan(best(3));
    expect(best(3)).toBeLessThan(best(4));
    expect(best(4)).toBeLessThan(best(5));
    expect(gearRule("dragon_heart_blade")!.might).toBe(best(5));
  });
});

describe("強化 (ECONOMY.md §1.2)", () => {
  it("costs twice as much each +, and from +3 the piece's own material, crystal shards and amber", () => {
    const sword = { id: "long_sword", left: 200 };
    expect(enhanceCost(sword)).toEqual({ log: 20, stone: 10 });
    expect(enhanceCost({ ...sword, plus: 1 })).toEqual({ log: 40, stone: 20 });
    expect(enhanceCost({ ...sword, plus: 2 })).toEqual({ log: 80, stone: 40, [gearOwnMaterial(gearRule("long_sword")!)]: 2 });
    expect(enhanceCost({ ...sword, plus: 4 })).toMatchObject({ log: 320, stone: 160, crystal_shard: 5, amber: 2 });
    expect(enhanceCost({ ...sword, plus: ENHANCE_MAX })).toBeNull();
    expect(enhanceCost({ id: "elder_scale_armor" })).toEqual({ log: 150, stone: 80, scrap_iron: 20 });
    expect(gearOwnMaterial(gearRule("long_sword")!)).toBe("rat_pelt");
  });

  it("makes a piece stronger and last longer, on top of ★ refined", () => {
    expect(gearBonus({ plus: 5 })).toBeCloseTo(1.3);
    expect(gearBonus({ refined: true, plus: 5 })).toBeCloseTo(REFINE_BONUS * 1.3);
    expect(gearMax({ id: "long_sword", plus: 5 })).toBe(300);
    expect(gearPower({ id: "long_sword", left: 300, plus: 5 })).toBeGreaterThan(gearPower({ id: "long_sword", left: 200 }));
  });
});
