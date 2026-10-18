import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { DECOR_KINDS, DECOR_LEVEL_STEP, DECOR_MAX_FENCES, DECOR_MAX_ITEMS, DECOR_ROOM, DECOR_ROOM_PER_LEVEL, decorLimits, decorProblem, decorRace, decorRoom, decorRoomUsed } from "./decor.ts";

const mac = new URL("../../../mac/Resources/Decor/", import.meta.url);

describe("decorations", () => {
  it("are fifty free, three quest rewards and a fence for each race, every one drawn (each frame) on the Mac, the same as its catalogue", () => {
    for (const [race, n] of [["goblin", 50], ["elf", 51], ["undead", 51]] as const) { // (the elves' eagle perch, the undead's soul lamp)
      expect(DECOR_KINDS.filter((k) => k.race === race && k.category !== "fence" && !k.limited && !k.level)).toHaveLength(n);
      expect(DECOR_KINDS.filter((k) => k.race === race && k.limited === "quest")).toHaveLength(3);
      expect(DECOR_KINDS.filter((k) => k.race === race && k.category === "fence")).toHaveLength(1);
    }
    expect(new Set(DECOR_KINDS.map((k) => k.id)).size).toBe(164 + 3 * 40);
    const catalog = JSON.parse(readFileSync(new URL("catalog.json", mac), "utf8"));
    expect(catalog).toEqual(DECOR_KINDS);
    for (const k of DECOR_KINDS) {
      expect(k.category === "fence" ? [0] : [1, 2, 4]).toContain(k.size);
      for (let f = 0; f < k.frames; f++) expect(() => readFileSync(new URL(k.id + (f ? `-${f}` : "") + ".png", mac)), k.id).not.toThrow();
    }
  });

  it("fit in the camp's room, and only the camp's own race's", () => {
    const big = DECOR_KINDS.find((k) => k.race === "goblin" && k.size === 4)!;
    const five = Array.from({ length: 5 }, (_, i) => ({ kind: big.id, x: i * 50, y: 0 }));
    expect(decorRoomUsed(five)).toBe(20);
    expect(decorProblem(five, "goblin", 1)).toBeNull();
    expect(decorProblem([...five, { kind: big.id, x: 0, y: 40 }], "goblin", 1)).toContain("點數不夠");
    expect(decorProblem([...five, { kind: big.id, x: 0, y: 40 }], "goblin", 2)).toBeNull();
    expect(decorProblem(five, "elf", 3)).toContain("不是這個種族");
    expect(decorProblem([{ kind: "nope", x: 0, y: 0 }], "goblin", 3)).toBe("沒有這種裝飾。");
    expect(decorProblem([{ kind: big.id, x: 5000, y: 0 }], "goblin", 3)).toContain("太遠");
    expect(decorProblem([{ kind: "g_trophy", x: 0, y: 0 }], "goblin", 3)).toContain("任務獎勵"); // (a quest's: earned first)
    expect(decorProblem([{ kind: "g_trophy", x: 0, y: 0 }], "goblin", 3, new Set(["g_trophy"]))).toBeNull();
    expect(DECOR_ROOM[3]).toBeGreaterThan(DECOR_ROOM[2]);
    const ring = Array.from({ length: 80 }, (_, i) => ({ kind: "g_fence", x: (i % 20) * 20, y: Math.floor(i / 20) * 20 })); // (fences take no room, up to eighty)
    expect(decorProblem([...five, ...ring], "goblin", 1)).toBeNull();
    expect(decorProblem([...ring, { kind: "g_fence", x: 0, y: 200 }], "goblin", 1)).toContain("柵欄最多");
  });

  it("open five more a race every three race levels, one of them doing something", () => {
    const fns = ["lv_rest", "lv_whet", "lv_nursery", "lv_might", "lv_ward", "lv_birth", "lv_hold", "lv_crown"];
    for (const race of ["goblin", "elf", "undead", "beast"]) {
      fns.forEach((fn, i) => {
        const tier = DECOR_KINDS.filter((k) => k.race === decorRace(race) && k.level === (i + 1) * DECOR_LEVEL_STEP);
        expect(tier, `${race} ${(i + 1) * DECOR_LEVEL_STEP}`).toHaveLength(5);
        expect(tier.filter((k) => k.fn).map((k) => k.fn)).toEqual([fn]);
        for (const k of tier) expect(k.limited).toBeNull();
      });
      expect(DECOR_KINDS.filter((k) => k.race === decorRace(race) && k.level)).toHaveLength(40);
    }
    const crown = DECOR_KINDS.find((k) => k.race === "goblin" && k.fn === "lv_crown")!;
    expect(decorProblem([{ kind: crown.id, x: 0, y: 0 }], "goblin", 3, new Set(), 23)).toContain("要種族等級 24 級");
    expect(decorProblem([{ kind: crown.id, x: 0, y: 0 }], "goblin", 3, new Set(), 24)).toBeNull();
  });

  it("let more things be put down every three race levels, up to level 24", () => {
    expect(decorLimits(2)).toEqual({ items: DECOR_MAX_ITEMS, fences: DECOR_MAX_FENCES });
    expect(decorLimits(18)).toEqual({ items: DECOR_MAX_ITEMS + 60, fences: DECOR_MAX_FENCES + 60 });
    expect(decorLimits(99)).toEqual(decorLimits(24));
    const ring = Array.from({ length: 90 }, (_, i) => ({ kind: "g_fence", x: (i % 20) * 20, y: Math.floor(i / 20) * 20 }));
    expect(decorProblem(ring, "goblin", 1, new Set(), 2)).toContain("柵欄最多 80");
    expect(decorProblem(ring, "goblin", 1, new Set(), 3)).toBeNull();
  });

  it("have more room the higher the player's race level", () => {
    expect(decorRoom(1)).toBe(DECOR_ROOM[1]);
    expect(decorRoom(1, 0)).toBe(DECOR_ROOM[1]); // (never less than the look's)
    expect(decorRoom(2, 3)).toBe(DECOR_ROOM[2] + 2 * DECOR_ROOM_PER_LEVEL);
    const big = DECOR_KINDS.find((k) => k.race === "goblin" && k.size === 4)!;
    const six = Array.from({ length: 6 }, (_, i) => ({ kind: big.id, x: i * 50, y: 0 })); // (24: four past a small camp's 20)
    expect(decorProblem(six, "goblin", 1)).toContain("點數不夠（24／20）");
    expect(decorProblem(six, "goblin", 1, new Set(), 2)).toBeNull();
  });
});
