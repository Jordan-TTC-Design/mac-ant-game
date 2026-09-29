import { describe, expect, it } from "vitest";
import { FARM_KEEP, farmCrops } from "./production.ts";
import { buildableKinds, campPerHour, produce, siteName, siteNext, sitePerHour, siteSpent, slotsFor, staffing, type Site } from "./sites.ts";
import { MATERIALS } from "../world/drops.ts";
import { unopenedGear } from "../world/availability.ts";

const HOUR = 3_600_000;
const T0 = Date.UTC(2026, 8, 29);
const farm = (level = 1): Site => ({ id: 1, kind: "farm", level });

describe("the camp's sites", () => {
  it("has plots by the camp's look, one more every five race levels", () => {
    expect([slotsFor("goblin", 10), slotsFor("goblin", 50), slotsFor("goblin", 150)]).toEqual([2, 4, 6]);
    expect([slotsFor("elf", 30), slotsFor("elf", 90)]).toEqual([4, 6]);
    expect([slotsFor("goblin", 150, 4), slotsFor("goblin", 150, 5), slotsFor("goblin", 150, 10)]).toEqual([6, 7, 8]);
  });

  it("gives every race the same shared kinds in its own version (odds and ends too), and one of its own", () => {
    const shared = ["lumber", "quarry", "mine", "traps", "fishery", "hunter"];
    expect(buildableKinds("goblin")).toEqual([...shared, "scrapyard"]);
    expect(buildableKinds("elf")).toEqual([...shared, "scrapyard", "grove"]);
    expect(buildableKinds("undead")).toEqual([...shared, "scrapyard", "soulwell"]);
    expect(siteName("elf", "scrapyard")).toBe("拾荒棚");
    expect(sitePerHour("elf", { kind: "scrapyard", level: 1 }).makes.scrap_rag).toBeCloseTo(0.7);
    expect(siteName("undead", "fishery")).toBe("醃肉窖");
    expect(Object.keys(sitePerHour("undead", { kind: "fishery", level: 1 }).makes)).toEqual(["ration_jerky"]);
    expect(siteName("elf", "hunter")).toBe("射手小屋");
    expect(sitePerHour("elf", { kind: "hunter", level: 1 }).makes.food_meat).toBeUndefined();
    expect(sitePerHour("elf", { kind: "hunter", level: 1 }).makes.rabbit_fur).toBeGreaterThan(0);
    expect(siteName("undead", "farm")).toBe("墓園");
  });

  it("needs ten hands a level; with too few, every site slows alike", () => {
    const sites: Site[] = [farm(2), { id: 2, kind: "lumber", level: 3 }, { id: 3, kind: "quarry", level: 0, busyUntil: "x" }];
    expect(staffing(sites, 100)).toEqual({ need: 50, share: 1 });
    expect(staffing(sites, 25)).toEqual({ need: 50, share: 0.5 });
    expect(campPerHour("goblin", sites, 0.5).log).toBeCloseTo(2 + 7 * 0.5); // (the gathering does not need hands)
  });

  it("follows each race's knack", () => {
    expect(sitePerHour("elf", { kind: "lumber", level: 1 }).makes.log).toBeCloseTo(1.4);
    expect(sitePerHour("undead", { kind: "quarry", level: 2 }).makes.stone).toBeCloseTo(3);
  });

  it("costs something to build and raise, and knows what it cost", () => {
    expect(siteNext("lumber", 0)).toMatchObject({ cost: { log: 10 }, hours: 1 });
    expect(siteNext("lumber", 3)).toBeNull();
    expect(siteNext("farm", 1)?.cost).toEqual({ log: 60, stone: 30 });
    expect(siteSpent("lumber", 2)).toEqual({ log: 70, stone: 20 });
  });

  it("adds up by the hour, the same all at once or bit by bit", () => {
    const sites: Site[] = [farm(2), { id: 2, kind: "lumber", level: 1 }, { id: 3, kind: "mine", level: 2 }];
    const base = { race: "goblin", seed: 7, sites, store: {} as Record<string, number> };
    const workers = (at: number) => 10 + Math.floor((at - T0) / HOUR); // (the camp grows)
    const once = produce({ ...base, workers, from: T0, to: T0 + 30 * HOUR + 1234, carry: {} });
    expect(once.to).toBe(T0 + 30 * HOUR);
    let carry: Record<string, number> = {};
    let from = T0;
    const sum: Record<string, number> = {};
    for (let h = 1; h <= 30; h++) {
      const step = produce({ ...base, workers, from, to: T0 + h * HOUR + 500, carry });
      for (const [id, n] of Object.entries(step.got)) sum[id] = (sum[id] ?? 0) + n;
      carry = step.carry;
      from = step.to;
    }
    expect(sum).toEqual(once.got);
    expect(once.got.ration_bread).toBeGreaterThan(0);
    expect(once.got.scrap_iron).toBeGreaterThan(0);
  });

  it("gathers a little with no site at all", () => {
    expect(produce({ race: "goblin", seed: 1, sites: [], workers: 0, from: T0, to: T0 + 10 * HOUR, carry: {}, store: {} }).got).toEqual({ log: 20, stone: 10 });
  });

  it("turns up crystal now and then in a mine", () => {
    const got = produce({ race: "goblin", seed: 3, sites: [{ id: 2, kind: "mine", level: 3 }], workers: 30, from: T0, to: T0 + 1000 * HOUR, carry: {}, store: {} }).got;
    expect(got.crystal_shard).toBeGreaterThan(40);
    expect(got.crystal_shard).toBeLessThan(110);
  });

  it("stops growing a food while the store holds FARM_KEEP of it", () => {
    const run = (have: number) => produce({ race: "goblin", seed: 1, sites: [farm()], workers: 10, from: T0, to: T0 + 300 * HOUR, carry: {}, store: { food_carrot: have } }).got;
    expect(run(FARM_KEEP - 2).food_carrot).toBe(2);
    expect(run(FARM_KEEP).food_carrot).toBeUndefined();
    expect(farmCrops("elf", 2).map((c) => c.food)).toEqual(["food_carrot", "ration_berry"]);
  });

  it("makes only materials that exist, and opens the T−1 gear", () => {
    for (const race of ["goblin", "elf", "undead"]) {
      for (const kind of buildableKinds(race)) {
        const { makes, finds } = sitePerHour(race, { kind, level: 3 });
        for (const id of [...Object.keys(makes), ...Object.keys(finds)]) expect(MATERIALS[id], `${kind} makes ${id}`).toBeDefined();
        for (let l = 0; l < 3; l++) for (const id of Object.keys(siteNext(kind, l)!.cost)) expect(MATERIALS[id], `${kind} needs ${id}`).toBeDefined();
      }
    }
    for (const id of ["wood_club", "stone_axe", "stone_spear", "bark_buckler", "bark_vest", "stone_cap"]) expect(unopenedGear()).not.toContain(id);
  });
});
