import { describe, expect, it } from "vitest";
import { guildDecorFits, guildDecorKind, guildFurnishing, keepInside, shiftHall, starterDecor } from "./guild-decor.ts";
import { guildLevel } from "./guild.ts";
import { ACTIVITY_SECONDS, DEFAULT_HALL_AREA, hallAreaPaint, hallAreaProblem, hallInteract, hallLayout, hallPose, hallRoute, hallStep, hallWalkable, WALL_ROWS, type HallMember, type Point } from "./guild-hall.ts";

const starter = () => hallLayout(DEFAULT_HALL_AREA, guildFurnishing(starterDecor()));

/** Every point of a walk is somewhere feet may be (checked every twentieth of each straight piece). */
function walkedClear(hall: ReturnType<typeof hallLayout>, from: Point, route: Point[]) {
  let at = from;
  for (const p of route.slice(0, -1)) {
    for (let i = 1; i <= 20; i++) expect(hallWalkable(hall, { x: at.x + ((p.x - at.x) * i) / 20, y: at.y + ((p.y - at.y) * i) / 20 })).toBe(true);
    at = p;
  }
}

describe("guild hall", () => {
  it("the starter set fits a new hall: five desks, water, a bench to sit on, every piece where it may stand", () => {
    const hall = starter();
    expect(hall.desks).toHaveLength(5);
    expect(hall.drinks).toHaveLength(1);
    expect(hall.seats.length).toBeGreaterThanOrEqual(1);
    for (const d of starterDecor()) expect(guildDecorFits(DEFAULT_HALL_AREA, guildDecorKind(d.kind)!, d.x, d.y)).toBe(true);
  });

  it("finds a way round the desks, and onto a seat inside a desk's place", () => {
    const hall = starter();
    const behind = hall.desks[0]!;
    const below = { x: behind.x, y: behind.y + 3 };
    const route = hallRoute(hall, below, behind);
    expect(route.at(-1)).toEqual(behind);
    walkedClear(hall, below, route);
    // from one desk to another and back out into the room
    const there = hallRoute(hall, hall.desks[0]!, hall.desks[4]!);
    expect(there.at(-1)).toEqual(hall.desks[4]);
  });

  it("cannot walk into a desk or the wall, slides along them, and sits, drinks or waves", () => {
    const hall = starter();
    const desk = hall.solids[0]!;
    expect(hallWalkable(hall, { x: (desk.x0 + desk.x1) / 2, y: (desk.y0 + desk.y1) / 2 })).toBe(false);
    expect(hallWalkable(hall, { x: 10, y: 1 })).toBe(false);
    const above = { x: (desk.x0 + desk.x1) / 2, y: desk.y0 - 0.3 };
    expect(hallStep(hall, above, 0, 0.7)).toEqual(above);
    expect(hallStep(hall, above, 0.2, 0.7)).toEqual({ x: above.x + 0.2, y: above.y });
    expect(hallInteract(hall, above)).toEqual({ anim: "sit", at: hall.desks[0] });
    const water = hall.drinks[0]!;
    expect(hallInteract(hall, { x: water.x + 0.3, y: water.y + 0.4 }).anim).toBe("drink");
    expect(hallInteract(hall, { x: hall.width / 2, y: hall.height - 4 }).anim).toBe("wave");
  });

  it("types when focusing, dozes when away, stands by the wall with no desk, is gone when offline, moves smoothly when there", () => {
    const hall = starter();
    const me: HallMember = { id: "a", presence: "online", seat: 0 };
    const friend: HallMember = { id: "b", presence: "focus", seat: 1 };
    const everyone = [me, friend];
    const t0 = Date.parse("2026-10-08T09:00:00Z");
    expect(hallPose(hall, friend, everyone, t0)).toMatchObject({ ...hall.desks[1], anim: "type" });
    expect(hallPose(hall, { ...friend, presence: "away" }, everyone, t0)).toMatchObject({ anim: "doze" });
    expect(hallPose(hall, { ...friend, seat: 9 }, everyone, t0)).toMatchObject({ anim: "idle" }); // (only five desks)
    expect(hallPose(hall, { ...friend, presence: "offline" }, everyone, t0)).toBeNull();
    // the same moment is the same everywhere, with or without the kept ways; over a while they go places, never jumping
    const ways = new Map<string, Point[]>();
    expect(hallPose(hall, me, everyone, t0, ways)).toEqual(hallPose(hall, me, everyone, t0));
    const anims = new Set<string>();
    let last = hallPose(hall, me, everyone, t0, ways)!;
    for (let s = 0.1; s < ACTIVITY_SECONDS * 30; s += 0.1) {
      const now = hallPose(hall, me, everyone, t0 + s * 1000, ways)!;
      anims.add(now.anim);
      expect(Math.hypot(now.x - last.x, now.y - last.y)).toBeLessThan(0.5);
      last = now;
    }
    expect([...anims]).toEqual(expect.arrayContaining(["walk", "sit", "drink", "chat"]));
  });

  it("an empty hall still works: everyone idles about", () => {
    const hall = hallLayout(DEFAULT_HALL_AREA);
    const me: HallMember = { id: "a", presence: "online", seat: 0 };
    for (let s = 0; s < 300; s += 7) expect(hallPose(hall, me, [me], s * 1000)!.anim).toMatch(/idle|walk/);
    expect(hallPose(hall, { ...me, presence: "focus" }, [me], 0)).toMatchObject({ anim: "idle" });
  });
});

describe("finding a way round", () => {
  it("walks round a wall of pieces through the gap, never through it", () => {
    const fence = { x0: 0, y0: 12.4, x1: 27, y1: 13 };
    const hall = { ...hallLayout(DEFAULT_HALL_AREA), solids: [fence] };
    const route = hallRoute(hall, { x: 5, y: 10 }, { x: 5, y: 16 });
    expect(route.at(-1)).toEqual({ x: 5, y: 16 });
    walkedClear(hall, { x: 5, y: 10 }, route);
    expect(Math.max(...route.map((p) => p.x))).toBeGreaterThan(27); // (through the gap)
    // walled in: as near as it gets, then the last step
    const shut = { ...hall, solids: [{ x0: 0, y0: 12.4, x1: 40, y1: 13 }] };
    const stuck = hallRoute(shut, { x: 5, y: 10 }, { x: 5, y: 16 });
    expect(stuck.at(-2)!.y).toBeLessThan(12.4);
  });
});

describe("the hall's shape", () => {
  it("is drawn tile by tile, kept tight, and moves everything when it grows up or to the left", () => {
    const two = hallAreaPaint(["##"], 2, 2, true)!;
    expect(two).toEqual({ area: ["###"], dx: 0, dy: 0 });
    const up = hallAreaPaint(["##"], 0, 1, true)!;
    expect(up).toEqual({ area: ["#", "##"], dx: 0, dy: 1 });
    const left = hallAreaPaint(["##"], -2, 2, true)!;
    expect(left).toEqual({ area: ["#.##"], dx: 2, dy: 0 });
    const lost = hallAreaPaint(["#.##"], 0, 2, false)!;
    expect(lost).toEqual({ area: ["##"], dx: -2, dy: 0 });
    expect(hallAreaPaint(["#"], 0, 2, false)).toBeNull();
    // what was put down moves with it
    const moved = shiftHall([{ uid: "aaaa", kind: "x", x: 1, y: 3 }], { base: "oak", tiles: { "0,2": "stone" } }, 2, 1);
    expect(moved.decor[0]).toMatchObject({ x: 3, y: 4 });
    expect(moved.floor.tiles).toEqual({ "2,3": "stone" });
  });

  it("must be one piece, tight, and no bigger than the level allows", () => {
    expect(hallAreaProblem(DEFAULT_HALL_AREA, 1)).toBeNull();
    expect(hallAreaProblem(["#", "", "#"], 7)).toMatch(/連在一起/);
    expect(hallAreaProblem(["#..#"], 7)).toMatch(/連在一起/);
    expect(hallAreaProblem([".#"], 7)).toMatch(/格式/);
    expect(hallAreaProblem(["#."], 7)).toMatch(/格式/);
    expect(hallAreaProblem([], 7)).toMatch(/格式/);
    expect(hallAreaProblem([...DEFAULT_HALL_AREA, "#"], 1)).toMatch(/最多 576 格/);
    expect(hallAreaProblem([...DEFAULT_HALL_AREA, "#"], 2)).toBeNull();
    expect(hallAreaProblem(["#".repeat(97)], 7)).toMatch(/最寬/);
    expect(guildLevel(1).tiles).toBe(hallAreaTilesOf(DEFAULT_HALL_AREA));
  });

  it("feet stay on the floor of an L-shaped hall, and a way is found round its corner", () => {
    // an L: a 10 × 4 room, and under its left end a 4 × 8 one
    const area = [...Array(4).fill("##########"), ...Array(8).fill("####")];
    const hall = hallLayout(area);
    expect(hall).toMatchObject({ width: 10, height: 14 });
    expect(hallWalkable(hall, { x: 8, y: 4 })).toBe(true);
    expect(hallWalkable(hall, { x: 8, y: 9 })).toBe(false); // (no floor there)
    expect(hallWalkable(hall, { x: 2, y: 12 })).toBe(true);
    expect(hallWalkable(hall, { x: 3.7, y: 12 })).toBe(false); // (too near the side)
    const route = hallRoute(hall, { x: 8, y: 4 }, { x: 2, y: 12 });
    expect(route.at(-1)).toEqual({ x: 2, y: 12 });
    walkedClear(hall, { x: 8, y: 4 }, route);
    // someone idle stands only on the floor
    const me: HallMember = { id: "a", presence: "online", seat: 0 };
    for (let s = 0; s < 600; s += 11) {
      const p = hallPose(hall, me, [me], s * 1000)!;
      expect(hallWalkable(hall, p)).toBe(true);
    }
  });

  it("pieces stand on the floor and hang on a wall over a top edge; what no longer fits is taken away", () => {
    const area = ["####", "####", "########"];
    const desk = { w: 32, wall: false };
    const banner = { w: 16, wall: true };
    expect(guildDecorFits(area, desk, 2, 4)).toBe(true);
    expect(guildDecorFits(area, desk, 6, 4)).toBe(false); // (over no floor)
    expect(guildDecorFits(area, desk, 6, 5)).toBe(true);
    expect(guildDecorFits(area, banner, 1.5, 2)).toBe(true); // (the wall over the top row)
    expect(guildDecorFits(area, banner, 5.5, 4)).toBe(true); // (the wall over the lower part's edge)
    expect(guildDecorFits(area, banner, 1.5, 4)).toBe(false); // (that is floor, not wall)
    const kept = keepInside(["####"], [{ uid: "aaaa", kind: starterDecor()[0]!.kind, x: 2, y: 2.5 }, { uid: "bbbb", kind: starterDecor()[0]!.kind, x: 20, y: 2.5 }], { base: "oak", tiles: { "1,2": "stone", "9,2": "stone" } });
    expect(kept.decor.map((d) => d.uid)).toEqual(["aaaa"]);
    expect(kept.floor.tiles).toEqual({ "1,2": "stone" });
    expect(kept.dropped).toBe(1);
  });
});

const hallAreaTilesOf = (area: string[]) => area.join("").split("").filter((c) => c === "#").length;
