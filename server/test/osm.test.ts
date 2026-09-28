import { readFileSync } from "node:fs";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { cellAt, cellsWithin } from "@goblincamp/shared/world";
import type { Database } from "../src/db/client.ts";
import { cellTerrain, gunzipTile, readTile, terrainsFor, useTileSource } from "../src/world/osm.ts";
import { emptyTables, openTestDatabase } from "./helpers.ts";

// 大安森林公園 and the streets around it, as OpenFreeMap had them (zoom 14, tile 13723/7014; © OpenStreetMap contributors)
const saved = gunzipTile(readFileSync(new URL("./fixtures/daan-14-13723-7014.pbf.gz", import.meta.url)));
const PARK = { lat: 25.0302, lng: 121.5357 };

describe("the real map's terrain (OpenStreetMap)", () => {
  it("sees the park's woods, the built-up streets around it, and the big roads", () => {
    const tile = readTile(saved, 14, 13723, 7014);
    expect(cellTerrain(tile, cellAt(PARK))).toBe("forest");
    const around: Record<string, number> = {};
    for (const c of cellsWithin(PARK, 900)) around[cellTerrain(tile, c)] = (around[cellTerrain(tile, c)] ?? 0) + 1;
    expect(around.urban).toBeGreaterThan(around.open ?? 0); // (a city: addresses and shops everywhere)
    expect(around.road ?? 0).toBeGreaterThan(0);
    expect(around.forest ?? 0).toBeGreaterThan(0);
  });

  describe("kept in the database", () => {
    let database: Database;
    let asked = 0;
    beforeAll(async () => {
      database = await openTestDatabase();
      process.env.WORLD_TERRAIN = "osm";
      useTileSource(async (_z, x, y) => {
        asked++;
        return x === 13723 && y === 7014 ? saved : null;
      });
    });
    beforeEach(async () => {
      await emptyTables(database);
      await database.sql`truncate world_terrain`;
      asked = 0;
    });
    afterAll(async () => {
      process.env.WORLD_TERRAIN = "seed";
      await database?.close();
    });

    it("works a cell out once and keeps it; a cell whose tile cannot be had gets the stand-in, not kept", async () => {
      const park = cellAt(PARK);
      const far = cellAt({ lat: 25.2, lng: 121.7 });
      const first = await terrainsFor(database.db, [park, far]);
      expect(first.get(park)).toBe("forest");
      expect(first.get(far)).toBeDefined();
      const rows = await database.sql<{ cell: string }[]>`select cell from world_terrain`;
      expect(rows.map((r) => r.cell)).toEqual([park]);
      const before = asked;
      expect((await terrainsFor(database.db, [park])).get(park)).toBe("forest");
      expect(asked).toBe(before); // (from the table, no tile needed)
    });
  });
});
