import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { MONSTER_DROPS } from "./combat.ts";
import { bossDue, bossLoot, campBoss, campFoe, CAMP_MONSTERS, planRaid, variantChance } from "./raids.ts";

const T0 = Date.parse("2026-10-17T00:00:00Z");
const kinds = (plans: ReturnType<typeof planRaid>[]) => new Set(plans.flatMap((p) => p?.monsters.map((m) => m.id) ?? []));

describe("camp raids by race level (DESKTOP.md §10.0)", () => {
  it("has 24 monsters in four tiers of six, each fighting with numbers and dropping known materials", () => {
    expect(CAMP_MONSTERS).toHaveLength(24);
    for (const [tier, from] of [[1, 1], [2, 6], [3, 12], [4, 18]] as const) {
      const of = CAMP_MONSTERS.filter((m) => m.tier === tier);
      expect(of, `tier ${tier}`).toHaveLength(6);
      expect(of.every((m) => m.from === from)).toBe(true);
    }
    for (const m of CAMP_MONSTERS.slice(4)) expect(campFoe(m.id), m.id).not.toBeNull();
    for (const m of CAMP_MONSTERS) for (const d of MONSTER_DROPS[m.id] ?? []) expect(MATERIALS[d.id], `${m.id} drops ${d.id}`).toBeDefined();
    for (const level of [10, 20, 30]) for (const id of Object.keys(bossLoot(level))) expect(MATERIALS[id], `boss ${level}: ${id}`).toBeDefined();
  });

  it("brings later tiers, more monsters and variants as the race grows", () => {
    const at = (level: number) => Array.from({ length: 40 }, (_, i) => planRaid("goblin", 7, T0, i, 200, level));
    expect([...kinds(at(1))].every((id) => CAMP_MONSTERS.find((m) => m.id === id)!.tier === 1)).toBe(true);
    expect([...kinds(at(12))].some((id) => CAMP_MONSTERS.find((m) => m.id === id)!.tier === 3)).toBe(true);
    expect([...kinds(at(18))].some((id) => CAMP_MONSTERS.find((m) => m.id === id)!.tier === 4)).toBe(true);
    const count = (plans: ReturnType<typeof at>) => plans.reduce((n, p) => n + p!.monsters.reduce((k, m) => k + m.count, 0), 0);
    expect(count(at(18))).toBeGreaterThan(count(at(1)));
    expect(at(1).every((p) => p!.monsters.every((m) => !m.variant))).toBe(true); // (a camp that never went out sees none)
    expect(at(18).some((p) => p!.monsters.some((m) => m.variant))).toBe(true);
    expect(variantChance(100)).toBe(0.3);
  });

  it("a race level of 1 plans the raids as before", () => {
    const old = planRaid("goblin", 4, T0, 3, 250)!;
    expect(planRaid("goblin", 4, T0, 3, 250, 1, [])).toEqual(old);
    expect(old.monsters.every((m) => ["slime", "giant_rat", "bat", "frog", "horn_beetle", "grass_snake"].includes(m.id))).toBe(true);
  });

  it("sends the level boss until it is beaten, the lowest first", () => {
    expect(bossDue(9, [])).toBeNull();
    expect(bossDue(23, [])).toBe(10);
    expect(bossDue(23, [10])).toBe(20);
    expect(bossDue(23, [10, 20])).toBeNull();
    expect(planRaid("elf", 1, T0, 0, 50, 10)!.boss).toBe(10);
    expect(planRaid("elf", 1, T0, 0, 50, 10, [10])!.boss).toBeUndefined();
    expect(campBoss(10).id).toBe("slime_king");
    expect(campBoss(20).id).toBe("troll_chief");
    expect(campBoss(40).hp).toBeGreaterThan(campBoss(30).hp);
  });
});
