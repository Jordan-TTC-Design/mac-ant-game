import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { DECOR_KINDS, DECOR_ROOM, decorProblem, decorRoomUsed } from "./decor.ts";

const mac = new URL("../../../mac/Resources/Decor/", import.meta.url);

describe("decorations", () => {
  it("are fifty for each race, every one drawn (each frame) on the Mac, the same as its catalogue", () => {
    for (const race of ["goblin", "elf", "undead"]) expect(DECOR_KINDS.filter((k) => k.race === race)).toHaveLength(50);
    expect(new Set(DECOR_KINDS.map((k) => k.id)).size).toBe(150);
    const catalog = JSON.parse(readFileSync(new URL("catalog.json", mac), "utf8"));
    expect(catalog).toEqual(DECOR_KINDS);
    for (const k of DECOR_KINDS) {
      expect([1, 2, 4]).toContain(k.size);
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
    expect(DECOR_ROOM[3]).toBeGreaterThan(DECOR_ROOM[2]);
  });
});
