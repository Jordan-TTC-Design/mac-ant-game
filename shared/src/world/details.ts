/**
 * 細分地形 (server/WORLD.md §29, 2026-10-17): on top of a cell's terrain (the six kinds lairs follow, which stay as they are),
 * what more the map says it is — a mountain, a river, farmland, a cemetery… From the same OpenMapTiles tiles
 * (server/src/world/osm.ts), kept per cell in `world_details` (none: nothing more to it). What each one does (yields, the
 * races at home there, its breeds, its buildings) is added step by step (§29.5).
 */
import { hashString } from "./random.ts";

export type TerrainDetail =
  | "mountain"
  | "river"
  | "farmland"
  | "cemetery"
  | "wetland"
  | "campus"
  | "industrial"
  | "sand"
  | "coast"
  | "hotspring"
  | "temple"
  | "hospital"
  | "military"
  | "railway";

export const TERRAIN_DETAILS: readonly TerrainDetail[] = [
  "mountain", "river", "farmland", "cemetery", "wetland", "campus", "industrial", "sand", "coast", "hotspring", "temple", "hospital", "military", "railway",
];

export const DETAIL_NAMES: Record<TerrainDetail, { name: string; icon: string }> = {
  mountain: { name: "山地", icon: "⛰️" },
  river: { name: "河川", icon: "🏞️" },
  farmland: { name: "農田", icon: "🌾" },
  cemetery: { name: "墓地", icon: "🪦" },
  wetland: { name: "濕地", icon: "🪷" },
  campus: { name: "校園", icon: "🏫" },
  industrial: { name: "工業區", icon: "🏭" },
  sand: { name: "沙灘", icon: "🏖️" },
  coast: { name: "海岸", icon: "🌊" },
  hotspring: { name: "溫泉", icon: "♨️" },
  temple: { name: "廟宇區", icon: "⛩️" },
  hospital: { name: "醫院", icon: "🏥" },
  military: { name: "軍事區", icon: "🪖" },
  railway: { name: "鐵道", icon: "🚆" },
};

export function isTerrainDetail(s: string | null | undefined): s is TerrainDetail {
  return !!s && (TERRAIN_DETAILS as readonly string[]).includes(s);
}

/** The share of cells the seed's stand-in gives a detail (no real map: tests, or a server without the internet). */
export const STAND_IN_DETAIL_SHARE = 0.25;

/** A cell's detail when the real map cannot be had: a quarter of the cells, every kind about as often. */
export function standInDetail(cell: string): TerrainDetail | null {
  const h = hashString(`${cell}|detail`) / 4294967296;
  if (h >= STAND_IN_DETAIL_SHARE) return null;
  return TERRAIN_DETAILS[Math.floor((h / STAND_IN_DETAIL_SHARE) * TERRAIN_DETAILS.length)]!;
}
