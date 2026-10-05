/**
 * The way a party walks (decided 2026-10-02): straight there, unless another camp's built-up land is in the way. A cell
 * of someone else's with a nest, a building or a town on it, or their camp's own cell, cannot be walked through: the party
 * goes round it (a longer walk), and if there is no way round, it cannot go until that cell is taken. Bare held cells, a
 * friend's land and lairs do not stand in the way. The server decides which cells block (world/service.ts routeFor).
 *
 * A route is a list of cells to walk between in straight lines (the first is where it sets out, the last where it goes);
 * a party walks it at the usual pace (territory.ts walkMinutes).
 */
import { cellAt, cellCenter, cellDistance, HEX_RADIUS, neighbors, type CellId, type LatLng } from "./grid.ts";

const METERS_PER_DEGREE = 111_320;
/** Past the cells in the way, the detour is looked for from this far before them to this far after them. */
const DETOUR_MARGIN_METERS = 800;
/** The detour search gives up after this many cells (about a 20 km wide area): no way round. */
const MAX_SEARCH_CELLS = 40_000;

export interface Route {
  /** The cells walked between in straight lines, from where it sets out to where it goes (just those two when nothing is in the way). */
  waypoints: CellId[];
  /** The walk's length, in metres. */
  meters: number;
  /** The straight line's length (meters − straight is the detour). */
  straight: number;
}

interface Blocker {
  cell: CellId;
  at: LatLng;
}

/** Where along a→b (0…1) the line passes within a cell's corner of `p`, or null when it keeps clear of it. */
function passes(a: LatLng, b: LatLng, p: LatLng): number | null {
  // (a flat map scaled at p's latitude: the walk is a straight line in latitude and longitude, so it stays straight here)
  const kx = Math.cos((p.lat * Math.PI) / 180) * METERS_PER_DEGREE;
  const ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * METERS_PER_DEGREE;
  const bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * METERS_PER_DEGREE;
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, -(ax * dx + ay * dy) / len2));
  const x = ax + dx * t, y = ay + dy * t;
  return x * x + y * y < HEX_RADIUS * HEX_RADIUS ? t : null;
}

/** Where along a→b the first and last cells in the way are (0…1), or null when the line is clear. */
function hits(a: LatLng, b: LatLng, blockers: Blocker[]): { first: number; last: number } | null {
  let first = Infinity, last = -Infinity;
  for (const k of blockers) {
    const t = passes(a, b, k.at);
    if (t === null) continue;
    first = Math.min(first, t);
    last = Math.max(last, t);
  }
  return first === Infinity ? null : { first, last };
}

const lerp = (a: LatLng, b: LatLng, t: number): LatLng => ({ lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t });

/** The shortest way between two cells over cells not in `blocked` (A*), or null when there is none near enough. */
function search(from: CellId, to: CellId, blocked: ReadonlySet<CellId>): CellId[] | null {
  const guess = (c: CellId) => cellDistance(c, to) * 1.001; // (a hair over: of the many equal ways, the one heading there)
  const cost = new Map<CellId, number>([[from, 0]]);
  const came = new Map<CellId, CellId>();
  // a binary heap of [estimate, cell]
  const heap: [number, CellId][] = [[guess(from), from]];
  const push = (item: [number, CellId]) => {
    heap.push(item);
    let i = heap.length - 1;
    while (i > 0) {
      const up = (i - 1) >> 1;
      if (heap[up]![0] <= heap[i]![0]) break;
      [heap[up], heap[i]] = [heap[i]!, heap[up]!];
      i = up;
    }
  };
  const pop = (): [number, CellId] => {
    const top = heap[0]!;
    const end = heap.pop()!;
    if (heap.length) {
      heap[0] = end;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        if (l < heap.length && heap[l]![0] < heap[m]![0]) m = l;
        if (r < heap.length && heap[r]![0] < heap[m]![0]) m = r;
        if (m === i) break;
        [heap[m], heap[i]] = [heap[i]!, heap[m]!];
        i = m;
      }
    }
    return top;
  };
  const done = new Set<CellId>();
  while (heap.length) {
    const [, cell] = pop();
    if (cell === to) {
      const path = [to];
      while (path[0] !== from) path.unshift(came.get(path[0]!)!);
      return path;
    }
    if (done.has(cell)) continue;
    done.add(cell);
    if (done.size > MAX_SEARCH_CELLS) return null;
    const here = cost.get(cell)!;
    for (const next of neighbors(cell)) {
      if (done.has(next) || (blocked.has(next) && next !== to)) continue;
      const c = here + cellDistance(cell, next);
      if (c >= (cost.get(next) ?? Infinity)) continue;
      cost.set(next, c);
      came.set(next, cell);
      push([c + guess(next), next]);
    }
  }
  return null;
}

/** Fewer turns: from each point, straight on to the farthest later one the line to which is clear. */
function straighten(path: CellId[], blockers: Blocker[]): CellId[] {
  const out = [path[0]!];
  let i = 0;
  while (i < path.length - 1) {
    let j = path.length - 1;
    while (j > i + 1 && hits(cellCenter(path[i]!), cellCenter(path[j]!), blockers)) j--;
    out.push(path[j]!);
    i = j;
  }
  return out;
}

/**
 * The way from one cell to another round the cells in `blocked` (where it sets out and where it goes never count as in the
 * way), or null when there is no way round.
 */
export function findRoute(from: CellId, to: CellId, blocked: ReadonlySet<CellId>): Route | null {
  const straight = cellDistance(from, to);
  const a = cellCenter(from), b = cellCenter(to);
  // (only those anywhere near the line matter)
  const reach = (straight / 2 + 25_000) / METERS_PER_DEGREE;
  const mid = lerp(a, b, 0.5);
  const blockers: Blocker[] = [];
  for (const cell of blocked) {
    if (cell === from || cell === to) continue;
    const at = cellCenter(cell);
    if (Math.abs(at.lat - mid.lat) > reach || Math.abs(at.lng - mid.lng) * Math.cos((mid.lat * Math.PI) / 180) > reach) continue;
    blockers.push({ cell, at });
  }
  const inWay = hits(a, b, blockers);
  if (!inWay) return { waypoints: [from, to], meters: straight, straight };

  // look for the way round only about the stretch that is in the way; straight on before and after it
  const margin = DETOUR_MARGIN_METERS / Math.max(1, straight);
  const near = new Set(blockers.map((k) => k.cell));
  let p = cellAt(lerp(a, b, Math.max(0, inWay.first - margin)));
  let q = cellAt(lerp(a, b, Math.min(1, inWay.last + margin)));
  if (near.has(p)) p = from;
  if (near.has(q)) q = to;
  const round = search(p, q, near);
  if (!round) return null;
  const raw = [...(p === from ? [] : [from]), ...round, ...(q === to ? [] : [to])];
  const waypoints = straighten(raw, blockers);
  let meters = 0;
  for (let i = 1; i < waypoints.length; i++) meters += cellDistance(waypoints[i - 1]!, waypoints[i]!);
  return { waypoints, meters, straight };
}

/** The first of the `blocked` cells the straight line from one cell to another runs into (null: none). */
export function inTheWay(from: CellId, to: CellId, blocked: Iterable<CellId>): CellId | null {
  const a = cellCenter(from), b = cellCenter(to);
  let best: { cell: CellId; t: number } | null = null;
  for (const cell of blocked) {
    if (cell === from || cell === to) continue;
    const t = passes(a, b, cellCenter(cell));
    if (t !== null && (!best || t < best.t)) best = { cell, t };
  }
  return best?.cell ?? null;
}

/** Where along a route a party is after `share` (0…1) of its walk. */
export function alongRoute(points: LatLng[], share: number): LatLng {
  if (points.length < 2) return points[0] ?? { lat: 0, lng: 0 };
  const legs = points.slice(1).map((p, i) => Math.hypot(p.lat - points[i]!.lat, (p.lng - points[i]!.lng) * Math.cos((p.lat * Math.PI) / 180)));
  let left = legs.reduce((s, l) => s + l, 0) * Math.max(0, Math.min(1, share));
  for (let i = 0; i < legs.length; i++) {
    if (left <= legs[i]! || i === legs.length - 1) return lerp(points[i]!, points[i + 1]!, legs[i]! ? Math.min(1, left / legs[i]!) : 1);
    left -= legs[i]!;
  }
  return points[points.length - 1]!;
}
