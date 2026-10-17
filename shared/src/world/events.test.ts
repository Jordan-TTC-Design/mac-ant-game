import { describe, expect, it } from "vitest";
import { cellsWithin } from "./grid.ts";
import { meteorAt, METEOR_CHANCE, METEOR_HOURS, seasonAt, seasonEndsAt } from "./events.ts";

describe("world events", () => {
  it("meteors fall now and then on cells, the same for everybody, and are gone after their hours", () => {
    const at = Date.parse("2026-09-01T10:00:00Z"); // (no season)
    const cells = cellsWithin({ lat: 25.04, lng: 121.53 }, 6000);
    const lying = cells.map((c) => meteorAt(1, c, at)).filter((m) => m !== null);
    // one block of 13 × 13 cells has one about METEOR_CHANCE of the time
    expect(lying.length).toBeGreaterThan(0);
    expect(lying.length).toBeLessThan((cells.length / 169) * METEOR_CHANCE * 3);
    const m = lying[0]!;
    expect(meteorAt(1, m.cell, at)).toEqual(m);
    expect(m.endsAt - m.startsAt).toBe(METEOR_HOURS * 3_600_000);
    expect(meteorAt(1, m.cell, m.endsAt)?.key).not.toBe(m.key);
    expect(m.loot.crystal_shard).toBeGreaterThanOrEqual(2);
  });

  it("seasons by Taipei's calendar", () => {
    expect(seasonAt(new Date("2026-10-31T12:00:00+08:00"))?.id).toBe("halloween");
    expect(seasonAt(new Date("2026-10-14T23:59:00+08:00"))).toBeNull();
    expect(seasonAt(new Date("2026-10-14T16:30:00Z"))?.id).toBe("halloween"); // (00:30 the 15th in Taipei)
    expect(seasonAt(new Date("2026-12-25T12:00:00+08:00"))?.id).toBe("winter");
    expect(seasonAt(new Date("2027-01-03T12:00:00+08:00"))?.id).toBe("newyear");
    const h = seasonAt(new Date("2026-10-20T12:00:00+08:00"))!;
    expect(seasonEndsAt(h, new Date("2026-10-20T12:00:00+08:00")).toISOString()).toBe(new Date("2026-11-03T00:00:00+08:00").toISOString());
  });
});
