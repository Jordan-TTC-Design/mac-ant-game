import { describe, expect, it } from "vitest";
import { GUILD_LEVELS } from "./guild.ts";
import { ACTIVITY_SECONDS, hallLayout, hallPath, hallPose, WALL_ROWS, type HallMember } from "./guild-hall.ts";

describe("guild hall", () => {
  it("has a desk for everyone at every level, all inside the hall below the wall", () => {
    for (const { level, members, width, height } of GUILD_LEVELS) {
      const hall = hallLayout(level);
      expect(hall.seats.length).toBe(members); // (one desk each, the rest of the floor free)
      for (const p of hall.pieces) {
        expect(p.x).toBeGreaterThan(0);
        expect(p.x).toBeLessThan(width);
        expect(p.y).toBeGreaterThan(WALL_ROWS - 1);
        expect(p.y).toBeLessThanOrEqual(height);
      }
    }
  });

  it("walks along aisles, never across a desk row", () => {
    const hall = hallLayout(3);
    const deskRows = [...new Set(hall.pieces.filter((p) => p.id === "desk").map((p) => p.y))];
    const path = hallPath(hall, hall.seats[0]!, hall.seats.at(-1)!);
    for (let i = 1; i < path.length; i++) {
      const [a, b] = [path[i - 1]!, path[i]!];
      expect(a.x === b.x || a.y === b.y).toBe(true); // straight lines only
      if (a.x !== b.x) expect(deskRows.some((y) => Math.abs(y - a.y) < 0.4)).toBe(false); // sideways only off the desk rows
      // up or down only at the edges or at a desk's own column
      if (a.y !== b.y) expect(a.x <= 1.5 || a.x >= hall.width - 1.5 || hall.seats.some((s) => s.x === a.x) || a.x === hall.drink.x).toBe(true);
    }
  });

  it("types when focusing, dozes when away, is gone when offline, and moves smoothly when there", () => {
    const hall = hallLayout(1);
    const me: HallMember = { id: "a", presence: "online", seat: 0 };
    const friend: HallMember = { id: "b", presence: "focus", seat: 1 };
    const everyone = [me, friend];
    const t0 = Date.parse("2026-10-08T09:00:00Z");
    expect(hallPose(hall, friend, everyone, t0)).toMatchObject({ ...hall.seats[1], anim: "type" });
    expect(hallPose(hall, { ...friend, presence: "away" }, everyone, t0)).toMatchObject({ anim: "doze" });
    expect(hallPose(hall, { ...friend, presence: "offline" }, everyone, t0)).toBeNull();
    // the same moment is the same everywhere; over a few minutes they go places, never jumping
    expect(hallPose(hall, me, everyone, t0)).toEqual(hallPose(hall, me, everyone, t0));
    const anims = new Set<string>();
    let last = hallPose(hall, me, everyone, t0)!;
    for (let s = 0.1; s < ACTIVITY_SECONDS * 30; s += 0.1) {
      const now = hallPose(hall, me, everyone, t0 + s * 1000)!;
      anims.add(now.anim);
      expect(Math.hypot(now.x - last.x, now.y - last.y)).toBeLessThan(0.5);
      last = now;
    }
    expect([...anims]).toEqual(expect.arrayContaining(["walk", "sit", "drink", "chat"]));
  });
});

describe("walking by hand", () => {
  it("cannot walk into a desk or the wall, slides along them, and sits when near a seat", async () => {
    const { hallStep, hallWalkable, hallInteract } = await import("./guild-hall.ts");
    const hall = hallLayout(1);
    const desk = hall.pieces.find((p) => p.id === "desk")!;
    expect(hallWalkable(hall, { x: desk.x, y: desk.y - 0.3 })).toBe(false);
    expect(hallWalkable(hall, { x: desk.x, y: 1 })).toBe(false);
    // walking down into a desk from the aisle above stops; walking diagonally slides sideways
    const above = { x: desk.x, y: desk.y - 1.25 };
    expect(hallStep(hall, above, 0, 0.7)).toEqual(above);
    expect(hallStep(hall, above, 0.2, 0.7)).toEqual({ x: desk.x + 0.2, y: above.y });
    expect(hallInteract(hall, above)).toEqual({ anim: "sit", at: hall.seats[0] });
    expect(hallInteract(hall, { x: hall.drink.x - 0.3, y: hall.drink.y + 0.4 }).anim).toBe("drink");
    expect(hallInteract(hall, { x: hall.width / 2, y: hall.height - 2 }).anim).toBe("wave");
  });
});
