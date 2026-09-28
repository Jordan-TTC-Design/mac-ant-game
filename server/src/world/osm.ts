/**
 * What each cell of the big world really is, from OpenStreetMap (server/WORLD.md §17): the same vector tiles the phone's
 * map is drawn from (OpenFreeMap's, OpenMapTiles' layers), read here once per cell and kept in `world_terrain`.
 *
 * A cell is looked at in seven spots (its middle and six around it): each spot is water, woods, park, built-up or open
 * land (in that order: a pond in a park is water), and the cell is what most of its spots are. A cell of built-up or open
 * land with a big road running near its middle is "road" (the robbers' and the orcs' ground). If the tiles cannot be had,
 * the seed's stand-in terrain is used for now and the cell is looked at again later.
 */
import { gunzipSync } from "node:zlib";
import { VectorTile, type VectorTileFeature } from "@mapbox/vector-tile";
import { PbfReader } from "pbf";
import { inArray } from "drizzle-orm";
import { cellCenter, HEX_RADIUS, terrainAt, WORLD_SEED, type Terrain } from "@goblincamp/shared/world";
import type { Db } from "../auth/session.ts";
import { worldTerrain } from "../db/schema.ts";

const Z = 14;
const TILEJSON = "https://tiles.openfreemap.org/planet";
/** The spots looked at, as shares of the cell's radius (HEX_RADIUS). */
const SPOTS: [number, number][] = [[0, 0], ...Array.from({ length: 6 }, (_, k) => [Math.cos((k * Math.PI) / 3) * 0.55, Math.sin((k * Math.PI) / 3) * 0.55] as [number, number])];
/** A big road this close to a cell's middle makes it a roadside cell. */
const ROAD_METERS = 45;
/** House numbers and places (shops, schools, bus stops…) within a cell that make it built-up land: in much of Taiwan the
 * buildings themselves are not drawn in OpenStreetMap, but the addresses and places are. */
const DENSE = 5;
const PRIORITY: Terrain[] = ["water", "forest", "park", "urban", "open"];

type Point = { x: number; y: number };
interface Area {
  kind: Terrain;
  box: number[];
  rings: Point[][];
}

/** One tile read into what matters here: the areas by kind, and the big roads. */
export interface ReadTile {
  z: number;
  x: number;
  y: number;
  extent: number;
  areas: Area[];
  roads: { box: number[]; lines: Point[][] }[];
  /** Addresses and places (points), for how built-up a cell is. */
  spots: Point[];
}

function tileOf(lat: number, lng: number): { x: number; y: number; fx: number; fy: number } {
  const n = 2 ** Z;
  const fx = ((lng + 180) / 360) * n;
  const r = (lat * Math.PI) / 180;
  const fy = ((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2) * n;
  return { x: Math.floor(fx), y: Math.floor(fy), fx, fy };
}

const AREA_CLASSES: { layer: string; kind: Terrain; classes?: string[] }[] = [
  { layer: "water", kind: "water" },
  { layer: "landcover", kind: "forest", classes: ["wood", "forest"] },
  { layer: "park", kind: "park" },
  { layer: "landcover", kind: "park", classes: ["grass", "wetland"] },
  { layer: "building", kind: "urban" },
  { layer: "landuse", kind: "urban", classes: ["residential", "commercial", "industrial", "retail", "railway"] },
];
const BIG_ROADS = ["motorway", "trunk", "primary"];

/** Reads a vector tile (the raw protocol buffer). */
export function readTile(data: Uint8Array, z: number, x: number, y: number): ReadTile {
  const tile = new VectorTile(new PbfReader(data));
  const areas: Area[] = [];
  const roads: ReadTile["roads"] = [];
  let extent = 4096;
  for (const want of AREA_CLASSES) {
    const layer = tile.layers[want.layer];
    if (!layer) continue;
    extent = layer.extent;
    for (let i = 0; i < layer.length; i++) {
      const f: VectorTileFeature = layer.feature(i);
      if (f.type !== 3) continue;
      if (want.classes && !want.classes.includes(String(f.properties.class))) continue;
      areas.push({ kind: want.kind, box: f.bbox(), rings: f.loadGeometry() });
    }
  }
  const t = tile.layers.transportation;
  if (t) {
    for (let i = 0; i < t.length; i++) {
      const f = t.feature(i);
      if (f.type !== 2 || !BIG_ROADS.includes(String(f.properties.class))) continue;
      roads.push({ box: f.bbox(), lines: f.loadGeometry() });
    }
  }
  const spots: Point[] = [];
  for (const name of ["housenumber", "poi"]) {
    const layer = tile.layers[name];
    if (!layer) continue;
    for (let i = 0; i < layer.length; i++) {
      const f = layer.feature(i);
      if (f.type === 1) for (const ring of f.loadGeometry()) spots.push(...ring);
    }
  }
  return { z, x, y, extent, areas, roads, spots };
}

function inside(p: Point, rings: Point[][]): boolean {
  // even-odd over every ring (holes cut out)
  let hit = false;
  for (const ring of rings) {
    for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      const a = ring[i]!, b = ring[j]!;
      if (a.y > p.y !== b.y > p.y && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x) hit = !hit;
    }
  }
  return hit;
}

function distanceToSegment(p: Point, a: Point, b: Point): number {
  const dx = b.x - a.x, dy = b.y - a.y;
  const len = dx * dx + dy * dy;
  const t = len === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len));
  return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}

/** What a cell is, from the tile its middle is in (spots that fall in a neighbouring tile count as what is nearest). */
export function cellTerrain(tile: ReadTile, cell: string): Terrain {
  const c = cellCenter(cell);
  const mLat = 110_574, mLng = 111_320 * Math.cos((c.lat * Math.PI) / 180);
  const toTile = (lat: number, lng: number): Point => {
    const t = tileOf(lat, lng);
    return { x: (t.fx - tile.x) * tile.extent, y: (t.fy - tile.y) * tile.extent };
  };
  const votes = new Map<Terrain, number>();
  for (const [sx, sy] of SPOTS) {
    const p = toTile(c.lat + (sy * HEX_RADIUS) / mLat, c.lng + (sx * HEX_RADIUS) / mLng);
    let kind: Terrain = "open";
    for (const area of tile.areas) {
      if (PRIORITY.indexOf(area.kind) >= PRIORITY.indexOf(kind)) continue; // (only something more telling can change it)
      const [x0, y0, x1, y1] = area.box as [number, number, number, number];
      if (p.x < x0 || p.x > x1 || p.y < y0 || p.y > y1) continue;
      if (inside(p, area.rings)) kind = area.kind;
    }
    votes.set(kind, (votes.get(kind) ?? 0) + 1);
  }
  const middle = toTile(c.lat, c.lng);
  const metersPerUnit = (40_075_016 * Math.cos((c.lat * Math.PI) / 180)) / 2 ** Z / tile.extent;
  // spots on no mapped area are built-up land if the cell is full of addresses and places, else open land
  const r = HEX_RADIUS / metersPerUnit;
  let dense = 0;
  for (const p of tile.spots) if (Math.abs(p.x - middle.x) < r && Math.abs(p.y - middle.y) < r && Math.hypot(p.x - middle.x, p.y - middle.y) < r) dense++;
  if (dense >= DENSE && votes.has("open")) {
    votes.set("urban", (votes.get("urban") ?? 0) + votes.get("open")!);
    votes.delete("open");
  }
  const most = [...votes].sort((a, b) => b[1] - a[1] || PRIORITY.indexOf(a[0]) - PRIORITY.indexOf(b[0]))[0]![0];
  if (most !== "urban" && most !== "open") return most;
  // a big road near the middle?
  const reach = ROAD_METERS / metersPerUnit;
  for (const road of tile.roads) {
    const [x0, y0, x1, y1] = road.box as [number, number, number, number];
    if (middle.x < x0 - reach || middle.x > x1 + reach || middle.y < y0 - reach || middle.y > y1 + reach) continue;
    for (const line of road.lines) {
      for (let i = 1; i < line.length; i++) if (distanceToSegment(middle, line[i - 1]!, line[i]!) <= reach) return "road";
    }
  }
  return most;
}

// --- getting tiles -----------------------------------------------------------------------------------------------

type TileSource = (z: number, x: number, y: number) => Promise<Uint8Array | null>;

let tileUrl: { template: string; at: number } | null = null;
async function fetchTile(z: number, x: number, y: number): Promise<Uint8Array | null> {
  try {
    if (!tileUrl || Date.now() - tileUrl.at > 86_400_000) {
      const tj = (await (await fetch(TILEJSON, { signal: AbortSignal.timeout(5000) })).json()) as { tiles: string[] };
      tileUrl = { template: tj.tiles[0]!, at: Date.now() };
    }
    const url = tileUrl.template.replace("{z}", String(z)).replace("{x}", String(x)).replace("{y}", String(y));
    const res = await fetch(url, { signal: AbortSignal.timeout(8000), headers: { "user-agent": "GoblinCamp world server" } });
    if (!res.ok) return null;
    const data = new Uint8Array(await res.arrayBuffer());
    return data[0] === 0x1f && data[1] === 0x8b ? new Uint8Array(gunzipSync(data)) : data;
  } catch {
    return null;
  }
}

let source: TileSource = fetchTile;
/** Tests: read tiles from somewhere else (a saved one), or not at all. */
export function useTileSource(s: TileSource) {
  source = s;
}

/** Read tiles kept a little while (a map page asks for a few neighbouring tiles at once). */
const readCache = new Map<string, ReadTile | null>();
async function tileAt(x: number, y: number): Promise<ReadTile | null> {
  const key = `${x}/${y}`;
  if (readCache.has(key)) return readCache.get(key)!;
  const data = await source(Z, x, y);
  const read = data ? readTile(data, Z, x, y) : null;
  readCache.set(key, read);
  if (readCache.size > 24) readCache.delete(readCache.keys().next().value!);
  if (!read) setTimeout(() => readCache.delete(key), 60_000); // (try again in a minute)
  return read;
}

/** Whether the real map is used (WORLD_TERRAIN=seed keeps the seed's stand-in: tests, or a server without the internet). */
const useOsm = () => (process.env.WORLD_TERRAIN ?? "osm") !== "seed";

/**
 * What these cells are: kept ones from the table, the rest worked out from the tiles (and kept). A cell whose tile could
 * not be had gets the stand-in for now (not kept, so it is looked at again).
 */
export async function terrainsFor(db: Db, cells: string[]): Promise<Map<string, Terrain>> {
  const out = new Map<string, Terrain>();
  if (cells.length === 0) return out;
  if (!useOsm()) {
    for (const c of cells) out.set(c, terrainAt(WORLD_SEED, c));
    return out;
  }
  const unique = [...new Set(cells)];
  for (const row of await db.select().from(worldTerrain).where(inArray(worldTerrain.cell, unique))) out.set(row.cell, row.terrain as Terrain);
  const missing = unique.filter((c) => !out.has(c));
  const byTile = new Map<string, string[]>();
  for (const c of missing) {
    const at = cellCenter(c);
    const t = tileOf(at.lat, at.lng);
    byTile.set(`${t.x}/${t.y}`, [...(byTile.get(`${t.x}/${t.y}`) ?? []), c]);
  }
  const found: { cell: string; terrain: Terrain }[] = [];
  for (const [key, list] of byTile) {
    const [x, y] = key.split("/").map(Number) as [number, number];
    const tile = await tileAt(x, y);
    for (const c of list) {
      if (tile) {
        const terrain = cellTerrain(tile, c);
        out.set(c, terrain);
        found.push({ cell: c, terrain });
      } else {
        out.set(c, terrainAt(WORLD_SEED, c));
      }
    }
  }
  if (found.length) await db.insert(worldTerrain).values(found.map((f) => ({ cell: f.cell, terrain: f.terrain, source: "osm" }))).onConflictDoNothing();
  return out;
}

export async function terrainOf(db: Db, cell: string): Promise<Terrain> {
  return (await terrainsFor(db, [cell])).get(cell)!;
}

/** (tests) a saved tile, gzipped */
export function gunzipTile(data: Uint8Array): Uint8Array {
  return new Uint8Array(gunzipSync(data));
}
