/**
 * The big world's cells: the real map cut into hexagon-like cells of about 0.035 km² (about 200 m across), so colleagues who
 * all pick spots in one park each get a cell of their own. (2026-09-28: made smaller, so 大安森林公園 (26 ha) holds 7 or 8
 * cells, where the first 350 m ones fitted about 3.)
 *
 * The grid is a "brick" layout, which works like hexagons: rows 174 m apart, cells 201 m wide, every other row shifted half a
 * cell, so each cell touches six others. A row's cells are measured in metres at that row's latitude, so a cell is the same size
 * anywhere on Earth. It needs no library; if the world later moves to H3 (see WORLD.md), only this file changes. Everything else
 * uses cells through `CellId` and the functions here.
 */

/** Row spacing (north–south) and cell width (east–west), in metres. */
export const ROW_METERS = 174;
export const CELL_METERS = 201;
/** The hexagon a cell is drawn as: from its middle to a corner (CELL_METERS = √3 × this, ROW_METERS = 1.5 × this). */
export const HEX_RADIUS = CELL_METERS / Math.sqrt(3);
const METERS_PER_DEGREE = 111_320;
const ROW_DEGREES = ROW_METERS / METERS_PER_DEGREE;

/** A cell, written "row:col" (row counts up from the south pole, col eastward from 180°W). */
export type CellId = string;

export interface LatLng {
  lat: number;
  lng: number;
}

function rowOf(lat: number): number {
  return Math.floor((Math.max(-89.999, Math.min(89.999, lat)) + 90) / ROW_DEGREES);
}

function rowLat(row: number): number {
  return (row + 0.5) * ROW_DEGREES - 90;
}

/** How many degrees of longitude one cell spans in this row. */
function colDegrees(row: number): number {
  const cos = Math.max(0.01, Math.cos((rowLat(row) * Math.PI) / 180));
  return CELL_METERS / (METERS_PER_DEGREE * cos);
}

function shift(row: number): number {
  return row % 2 === 1 ? colDegrees(row) / 2 : 0;
}

export function cellId(row: number, col: number): CellId {
  return `${row}:${col}`;
}

export function parseCell(id: CellId): { row: number; col: number } {
  const [r, c] = id.split(":");
  const row = Number(r), col = Number(c);
  if (!Number.isInteger(row) || !Number.isInteger(col)) throw new Error(`not a cell id: ${id}`);
  return { row, col };
}

export function isCellId(id: string): boolean {
  return /^\d+:-?\d+$/.test(id);
}

/** The cell a point is in. */
export function cellAt(point: LatLng): CellId {
  const row = rowOf(point.lat);
  const lng = ((((point.lng + 180) % 360) + 360) % 360) - shift(row);
  return cellId(row, Math.floor(lng / colDegrees(row)));
}

/** The middle of a cell. */
export function cellCenter(id: CellId): LatLng {
  const { row, col } = parseCell(id);
  const lng = (col + 0.5) * colDegrees(row) + shift(row) - 180;
  return { lat: rowLat(row), lng: ((((lng + 180) % 360) + 360) % 360) - 180 };
}

/** The (usually six) cells that touch this one: two in its row, two above, two below. */
export function neighbors(id: CellId): CellId[] {
  const { row, col } = parseCell(id);
  const center = cellCenter(id);
  const out = new Set<CellId>([cellId(row, col - 1), cellId(row, col + 1)]);
  const quarter = colDegrees(row) / 4;
  for (const dr of [-1, 1]) {
    const lat = rowLat(row + dr);
    for (const dl of [-quarter, quarter]) out.add(cellAt({ lat, lng: center.lng + dl }));
  }
  out.delete(id);
  return [...out];
}

/** Great-circle distance in metres. */
export function metersBetween(a: LatLng, b: LatLng): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad, dLng = (b.lng - a.lng) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function cellDistance(a: CellId, b: CellId): number {
  return metersBetween(cellCenter(a), cellCenter(b));
}

/** Every cell whose middle is within `radius` metres of a point (for "what is around me" on the map). */
export function cellsWithin(point: LatLng, radius: number): CellId[] {
  const out: CellId[] = [];
  const rows = Math.ceil(radius / ROW_METERS) + 1;
  const home = rowOf(point.lat);
  for (let row = home - rows; row <= home + rows; row++) {
    const lat = rowLat(row);
    const span = colDegrees(row);
    const cols = Math.ceil(radius / CELL_METERS) + 1;
    const mid = Math.floor(((((point.lng + 180) % 360) + 360) % 360 - shift(row)) / span);
    for (let col = mid - cols; col <= mid + cols; col++) {
      const id = cellId(row, col);
      if (metersBetween(point, cellCenter(id)) <= radius) out.push(id);
    }
    void lat;
  }
  return out;
}
