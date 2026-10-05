import { describe, expect, it } from "vitest";
import { cellAt, cellCenter, cellDistance, neighbors } from "./grid.ts";
import { alongRoute, findRoute } from "./route.ts";
import { travelMinutes, walkMinutes } from "./territory.ts";

const here = cellAt({ lat: 25.03, lng: 121.53 });
const there = cellAt({ lat: 25.03, lng: 121.56 }); // about 3 km east

/** A wall of cells across the way, `half` cells either side of the line (north–south, through the middle). */
function wall(half: number): Set<string> {
  const mid = cellAt({ lat: 25.03, lng: 121.545 });
  const out = new Set<string>();
  const { lat, lng } = cellCenter(mid);
  for (let k = -half; k <= half; k++) {
    const c = cellAt({ lat: lat + (k * 174) / 111_320, lng });
    out.add(c);
    for (const n of neighbors(c)) if (Math.abs(cellCenter(n).lng - lng) < 0.0012) out.add(n);
  }
  return out;
}

describe("routes round other camps' land", () => {
  it("walks straight when nothing is in the way", () => {
    const r = findRoute(here, there, new Set([cellAt({ lat: 25.05, lng: 121.545 })]))!;
    expect(r.waypoints).toEqual([here, there]);
    expect(r.meters).toBeCloseTo(cellDistance(here, there));
    expect(walkMinutes(r.meters)).toBe(travelMinutes(here, there));
  });

  it("goes round a wall, a little longer, never through it", () => {
    const blocked = wall(4);
    const r = findRoute(here, there, blocked)!;
    expect(r).not.toBeNull();
    expect(r.meters).toBeGreaterThan(r.straight);
    expect(r.meters).toBeLessThan(r.straight * 1.6);
    // every point along it keeps out of the wall
    const points = r.waypoints.map(cellCenter);
    for (let k = 0; k <= 400; k++) expect(blocked.has(cellAt(alongRoute(points, k / 400)))).toBe(false);
  });

  it("finds no way when the target is walled in all round", () => {
    const ring = new Set(neighbors(there));
    for (const c of [...ring]) for (const n of neighbors(c)) if (n !== there) ring.add(n);
    expect(findRoute(here, there, ring)).toBeNull();
  });

  it("may set out from and go to a blocked cell itself", () => {
    expect(findRoute(here, there, new Set([here, there]))!.waypoints).toEqual([here, there]);
  });
});
