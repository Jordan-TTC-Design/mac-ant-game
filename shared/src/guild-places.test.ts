import { describe, expect, it } from "vitest";
import { GUILD_DECOR, guildDecorChange, guildDecorTile, hallPlotsProblem, hallWallAt, hallWallsProblem, keepTileKeys, shiftTileKeys, type GuildDecorPlaced } from "./guild-decor.ts";
import { avatarOutfitProblem, avatarProblem, defaultAvatar } from "./guild.ts";
import { DEFAULT_HALL_AREA, hallAreaHas, hallAreaPaint } from "./guild-hall.ts";
import { FREE_OUTFITS, GUILD_OUTFITS, outfitBuyProblem } from "./guild-outfits.ts";

const A = DEFAULT_HALL_AREA; // (floor x 0…31, y 2…19; the wall stands over y 2)
const floorKind = GUILD_DECOR.find((k) => k.level === 1 && !k.wall && !k.race && k.size === 1)!;
const wallKind = GUILD_DECOR.find((k) => k.level === 1 && k.wall && !k.race)!;
const put = (uid: string, x: number, y: number, kind = floorKind.id): GuildDecorPlaced => ({ uid: `${uid}xxxx`, kind, x, y });
const ME = "00000000-0000-4000-8000-000000000001";
const AMY = "00000000-0000-4000-8000-000000000002";
const names = new Map([[ME, "我"], [AMY, "阿米"]]);

describe("the wall brushed a segment at a time", () => {
  it("goes only where there is wall, in styles the guild may use", () => {
    expect(hallWallAt(A, 5, 2)).toBe(true);
    expect(hallWallAt(A, 5, 3)).toBe(false);
    expect(hallWallsProblem({ "5,2": "wood" }, A, new Set())).toBeNull();
    expect(hallWallsProblem({ "5,3": "wood" }, A, new Set())).toContain("沒有牆");
    expect(hallWallsProblem({ "5,2": "nope" }, A, new Set())).toBe("沒有這種牆壁。");
    expect(hallWallsProblem({ "5,2": "elf_vines" }, A, new Set(["goblin"]))).toContain("種族");
    expect(hallWallsProblem({ "5,2": "elf_vines" }, A, new Set(["goblin"]), { "6,2": "elf_vines" })).toBeNull(); // (already up: stays)
  });
});

describe("the members' own places", () => {
  const plots = { "5,6": AMY, "6,6": AMY, "9,6": ME };
  const places = { me: ME, area: A, plots, names };

  it("are on the floor and go to members", () => {
    expect(hallPlotsProblem(plots, A, new Set([ME, AMY]))).toBeNull();
    expect(hallPlotsProblem({ "5,1": AMY }, A, new Set([AMY]))).toContain("外面");
    expect(hallPlotsProblem(plots, A, new Set([ME]))).toContain("成員");
  });

  it("a piece belongs to the tile under its feet, a wall piece to the floor at the foot of its wall", () => {
    expect(guildDecorTile(A, put("a", 5.5, 7))).toBe("5,6");
    expect(guildDecorTile(A, put("a", 5.5, 6.5))).toBe("5,6");
    expect(guildDecorTile(A, put("w", 5.5, 2, wallKind.id))).toBe("5,2");
  });

  it("keep a member out of someone else's, but not out of their own or the leader out of any", () => {
    const amys = put("amy", 5.5, 7);
    expect(guildDecorChange([], [put("n", 5.5, 7)], "member", places)).toContain("阿米的位置");
    expect(guildDecorChange([amys], [], "member", places)).toContain("阿米的位置");
    expect(guildDecorChange([amys], [{ ...amys, x: 12 }], "member", places)).toContain("阿米的位置"); // (moved out of it)
    expect(guildDecorChange([put("b", 12, 7)], [put("b", 5.5, 7)], "member", places)).toContain("阿米的位置"); // (moved into it)
    expect(guildDecorChange([amys], [{ ...amys, flip: true }], "member", places)).toContain("阿米的位置");
    expect(guildDecorChange([], [put("n", 9.5, 7)], "member", places)).toEqual({ added: 1, moved: 0, removed: 0 }); // (mine)
    expect(guildDecorChange([], [put("n", 20, 7)], "member", places)).toEqual({ added: 1, moved: 0, removed: 0 }); // (nobody's)
    expect(guildDecorChange([amys], [], "officer", places)).toEqual({ added: 0, moved: 0, removed: 1 });
    expect(guildDecorChange([amys], [], "member", { ...places, names: new Map([[ME, "我"]]) })).toEqual({ added: 0, moved: 0, removed: 1 }); // (she left)
  });

  it("move with the hall when it grows up or to the left, and the ones off it are dropped", () => {
    const grown = hallAreaPaint(A, 5, 1, true)!; // (a tile up: everything moves down one)
    expect(shiftTileKeys(plots, grown.dx, grown.dy)).toEqual({ "5,7": AMY, "6,7": AMY, "9,7": ME });
    expect(keepTileKeys({ "5,6": AMY, "40,6": AMY }, (x, y) => hallAreaHas(A, x, y))).toEqual({ "5,6": AMY });
  });
});

describe("clothes", () => {
  it("are four of each slot or so, the free ones a set to start", () => {
    for (const slot of ["top", "bottom", "shoes", "hat"]) expect(GUILD_OUTFITS.filter((o) => o.slot === slot).length).toBeGreaterThanOrEqual(4);
    expect(new Set(GUILD_OUTFITS.map((o) => o.id)).size).toBe(GUILD_OUTFITS.length);
    expect(FREE_OUTFITS).toEqual(["linen_shirt", "work_trousers", "sandals", "straw_hat"]);
  });

  it("the limited ones: two or three a holiday, six a guild level from 2 to 7, ten from the merchant, each one kind only", () => {
    const limited = GUILD_OUTFITS.filter((o) => o.season || o.level || o.merchant);
    for (const o of limited) expect([o.season, o.level, o.merchant].filter(Boolean), o.id).toHaveLength(1);
    for (const season of ["spring_festival", "lantern", "dragon_boat", "mid_autumn", "national", "new_year", "christmas"]) {
      expect(GUILD_OUTFITS.filter((o) => o.season === season).length, season).toBeGreaterThanOrEqual(2);
      expect(GUILD_OUTFITS.filter((o) => o.season === season).length, season).toBeLessThanOrEqual(3);
    }
    for (let level = 2; level <= 7; level++) expect(GUILD_OUTFITS.filter((o) => o.level === level), `level ${level}`).toHaveLength(6);
    expect(GUILD_OUTFITS.filter((o) => o.merchant)).toHaveLength(10);
  });

  it("are worn in their slot and only when owned", () => {
    const a = defaultAvatar("goblin", "m");
    expect(avatarProblem({ ...a, top: "leather_vest", hat: "wizard_hat" })).toBeNull();
    expect(avatarProblem({ ...a, top: "wizard_hat" })).toBe("沒有這件衣服。");
    expect(avatarOutfitProblem({ ...a, top: "leather_vest" }, FREE_OUTFITS)).toContain("皮背心");
    expect(avatarOutfitProblem({ ...a, top: "linen_shirt", hat: "straw_hat" }, FREE_OUTFITS)).toBeNull();
  });

  it("are bought with contribution left", () => {
    const w = { owned: [...FREE_OUTFITS], points: 500, spent: 0 };
    expect(outfitBuyProblem("leather_vest", w)).toBeNull();
    expect(outfitBuyProblem("wizard_hat", w)?.code).toBe("not_enough");
    expect(outfitBuyProblem("sandals", w)?.code).toBe("owned");
    expect(outfitBuyProblem("nope", w)?.code).toBe("unknown");
  });
});
