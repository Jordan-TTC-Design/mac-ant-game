import { describe, expect, it } from "vitest";
import { cellsWithin } from "./grid.ts";
import { LAIRS, lairAt } from "./contents.ts";
import { buildingSlots, DETAIL_BUILDINGS, DETAIL_LAIRS, DETAIL_RACES, DETAIL_YIELD, detailBuildingsFor, detailEffects, detailHome, hubForRace, hubName, HUBS, standInDetail, TERRAIN_DETAILS } from "./details.ts";
import { CELL_BUILDINGS } from "./holdings.ts";
import { MATERIALS } from "./drops.ts";
import { seeded } from "./random.ts";
import { cellYield } from "./territory.ts";

describe("細分地形 (WORLD.md §29)", () => {
  it("has fourteen kinds, each yielding known materials and at home for some race", () => {
    expect(TERRAIN_DETAILS).toHaveLength(14);
    for (const d of TERRAIN_DETAILS) {
      expect(DETAIL_YIELD[d].length, d).toBeGreaterThan(0);
      for (const y of DETAIL_YIELD[d]) expect(MATERIALS[y.id], `${d}: ${y.id}`).toBeDefined();
      expect(DETAIL_RACES[d].length).toBeGreaterThan(0);
    }
    expect(detailHome("cemetery", "undead")).toBe(true);
    expect(detailHome("cemetery", "elf")).toBe(false);
    expect(detailHome(null, "elf")).toBe(false);
  });

  it("gives the stand-in a detail on about a quarter of the cells, all kinds", () => {
    const cells = cellsWithin({ lat: 25.03, lng: 121.53 }, 4000);
    const got = cells.map(standInDetail);
    const share = got.filter(Boolean).length / cells.length;
    expect(share).toBeGreaterThan(0.18);
    expect(share).toBeLessThan(0.32);
    expect(new Set(got.filter(Boolean)).size).toBe(14);
  });

  it("adds its yields on top of the terrain's, which stay as they were; farmland's food twice", () => {
    const plain = cellYield("goblin", "open", 20, 10, seeded(1, "y"));
    const withDetail = cellYield("goblin", "open", 20, 10, seeded(1, "y"), false, 0, "mountain");
    for (const [id, n] of Object.entries(plain)) expect(withDetail[id] ?? 0).toBeGreaterThanOrEqual(n);
    expect(withDetail.stone ?? 0).toBeGreaterThan(0);
    const farm = cellYield("goblin", "open", 20, 10, seeded(2, "y"), false, 0, "farmland");
    expect((farm.food_carrot ?? 0) + (farm.ration_bread ?? 0)).toBeGreaterThan(0);
    expect(detailEffects("farmland").food).toBe(2);
    expect(detailEffects(null)).toMatchObject({ travel: 1, food: 1, heal: 0 });
  });

  it("leans the mid lairs of its empty cells to its own kinds, and leaves the rest of the map as it was", () => {
    for (const ids of Object.values(DETAIL_LAIRS)) for (const id of ids) expect(LAIRS.find((l) => l.id === id), id).toBeDefined();
    const cells = cellsWithin({ lat: 25.03, lng: 121.53 }, 6000);
    let leaned = 0, mids = 0;
    for (const c of cells) {
      const before = lairAt(7, c, "forest");
      const after = lairAt(7, c, "forest", "mountain");
      if (!before?.minRaceLevel) expect(after).toEqual(before); // (ordinary lairs, strays and empty cells: unchanged)
      else {
        mids++;
        if (DETAIL_LAIRS.mountain!.includes(after!.kind)) leaned++;
      }
    }
    expect(mids).toBeGreaterThan(10);
    expect(leaned / mids).toBeGreaterThan(0.3); // (some of a mountain's kinds do not live in woods)
  });

  it("offers two buildings of its own on every 細分地形 and three anywhere, none sharing a kind with the terrains' (§29.3)", () => {
    expect(DETAIL_BUILDINGS).toHaveLength(31);
    const kinds = [...CELL_BUILDINGS.map((r) => r.kind as string), ...DETAIL_BUILDINGS.map((r) => r.kind)];
    expect(new Set(kinds).size).toBe(kinds.length);
    for (const d of TERRAIN_DETAILS) expect(DETAIL_BUILDINGS.filter((r) => r.detail === d), d).toHaveLength(2);
    expect(detailBuildingsFor("campus").map((r) => r.kind)).toEqual(["academy", "library", "storehouse", "outpost", "altar"]);
    expect(detailBuildingsFor(null)).toHaveLength(3);
    for (const r of DETAIL_BUILDINGS) for (const id of [...Object.keys(r.makes ?? {}), ...Object.keys(r.finds ?? {})]) expect(MATERIALS[id], `${r.kind}: ${id}`).toBeDefined();
    expect(buildingSlots(false)).toBe(1);
    expect(buildingSlots(true)).toBe(2);
  });

  it("has three hubs beside the town, the undead's sanctuary a 墓城 strong for them (§29.4)", () => {
    expect(HUBS.map((h) => h.kind)).toEqual(["town", "fortress", "workstead", "sanctuary"]);
    expect(HUBS.filter((h) => h.kind !== "town").every((h) => h.births < 1)).toBe(true);
    expect(hubName("sanctuary", "undead")).toBe("墓城");
    expect(hubName("sanctuary", "elf")).toBe("聖地");
    expect(hubForRace("sanctuary", "undead")).toMatchObject({ vsUndead: 0, undeadDefend: 0.2 });
    expect(hubForRace("sanctuary", "goblin").vsUndead).toBeGreaterThan(0);
    for (const id of Object.keys(HUBS.find((h) => h.kind === "workstead")!.yield!)) expect(MATERIALS[id]).toBeDefined();
  });
});
