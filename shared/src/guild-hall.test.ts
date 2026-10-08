import { describe, expect, it } from "vitest";
import { guildFurnishing, starterDecor } from "./guild-decor.ts";
import { GUILD_LEVELS } from "./guild.ts";
import { ACTIVITY_SECONDS, hallInteract, hallLayout, hallPose, hallRoute, hallStep, hallWalkable, WALL_ROWS, type HallMember, type Point } from "./guild-hall.ts";

const starter = (level = 1) => hallLayout(level, guildFurnishing(starterDecor(level)));

/** Every point of a walk is somewhere feet may be (checked every twentieth of each straight piece). */
function walkedClear(hall: ReturnType<typeof hallLayout>, from: Point, route: Point[]) {
  let at = from;
  for (const p of route.slice(0, -1)) {
    for (let i = 1; i <= 20; i++) expect(hallWalkable(hall, { x: at.x + ((p.x - at.x) * i) / 20, y: at.y + ((p.y - at.y) * i) / 20 })).toBe(true);
    at = p;
  }
}

describe("guild hall", () => {
  it("the starter set fits every level: five desks, water, a bench to sit on, all below the wall", () => {
    for (const { level, width, height } of GUILD_LEVELS) {
      const hall = starter(level);
      expect(hall.desks).toHaveLength(5);
      expect(hall.drinks).toHaveLength(1);
      expect(hall.seats.length).toBeGreaterThanOrEqual(1);
      for (const d of starterDecor(level)) {
        expect(d.x).toBeGreaterThan(0);
        expect(d.x).toBeLessThan(width);
        expect(d.y).toBeGreaterThanOrEqual(WALL_ROWS);
        expect(d.y).toBeLessThanOrEqual(height);
      }
    }
  });

  it("finds a way round the desks, and onto a seat inside a desk's place", () => {
    const hall = starter(1);
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
    const hall = starter(1);
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
    const hall = starter(1);
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
    const hall = hallLayout(1);
    const me: HallMember = { id: "a", presence: "online", seat: 0 };
    for (let s = 0; s < 300; s += 7) expect(hallPose(hall, me, [me], s * 1000)!.anim).toMatch(/idle|walk/);
    expect(hallPose(hall, { ...me, presence: "focus" }, [me], 0)).toMatchObject({ anim: "idle" });
  });
});

describe("finding a way round", () => {
  it("walks round a wall of pieces through the gap, never through it", () => {
    const fence = { x0: 0, y0: 12.4, x1: 27, y1: 13 };
    const hall = { ...hallLayout(1), solids: [fence] };
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
