/**
 * What a cell of the big world mostly is (WORLD.md §2). The real answer will come from OpenStreetMap (parks → park, woods →
 * forest, rivers and lakes → water, dense buildings → urban); until that data is in, a stand-in made from the world's seed
 * gives every cell a terrain that comes in patches (a wood a few cells across, a lake, a built-up stretch), so the map and
 * the lairs already feel like places. Only this file changes when the real map comes in.
 */
import type { Terrain } from "./contents.ts";
import { parseCell, type CellId } from "./grid.ts";
import { hashString } from "./random.ts";

/** A smooth value in 0…1 that changes over about `scale` cells (value noise: random corners, blended). */
function noise(seed: number, layer: string, row: number, col: number, scale: number): number {
  const corner = (r: number, c: number) => (hashString(`${seed}|${layer}|${r}|${c}`) % 10_000) / 10_000;
  const x = col / scale;
  const y = row / scale;
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const smooth = (t: number) => t * t * (3 - 2 * t);
  const sx = smooth(x - x0);
  const sy = smooth(y - y0);
  const top = corner(y0, x0) * (1 - sx) + corner(y0, x0 + 1) * sx;
  const bottom = corner(y0 + 1, x0) * (1 - sx) + corner(y0 + 1, x0 + 1) * sx;
  return top * (1 - sy) + bottom * sy;
}

/** The terrain of a cell (the stand-in until OpenStreetMap: the same seed and cell always give the same answer). */
export function terrainAt(worldSeed: number, cell: CellId): Terrain {
  const { row, col } = parseCell(cell);
  // two scales mixed, so patches have ragged edges
  const field = (layer: string) => 0.7 * noise(worldSeed, layer, row, col, 7) + 0.3 * noise(worldSeed, `${layer}-fine`, row, col, 2.5);
  if (field("water") > 0.74) return "water";
  if (field("town") > 0.64) return "urban";
  const green = field("green");
  if (green > 0.6) return "forest";
  if (green > 0.47) return "park";
  return "open";
}

/** Terrain names for people. */
export const TERRAIN_NAMES: Record<Terrain, string> = { forest: "森林", park: "公園", water: "水邊", urban: "市區", open: "空地", road: "大路邊" };
