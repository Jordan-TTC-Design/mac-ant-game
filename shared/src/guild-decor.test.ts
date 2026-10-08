import { describe, expect, it } from "vitest";
import { GUILD_DECOR, GUILD_DECOR_CATEGORIES, guildDecorChange, guildDecorProblem, guildDecorRoomUsed, guildDecorUnlocked, type GuildDecorPlaced } from "./guild-decor.ts";
import { guildLevel } from "./guild.ts";
import { guildSeason } from "./guild-seasons.ts";

const floorKind = GUILD_DECOR.find((k) => k.level === 1 && !k.wall && !k.race && k.size === 1)!;
const wallKind = GUILD_DECOR.find((k) => k.level === 1 && k.wall && !k.race)!;
const none = new Set<string>();
const put = (uid: string, kind = floorKind.id, x = 5, y = 6, extra: Partial<GuildDecorPlaced> = {}): GuildDecorPlaced => ({ uid: `${uid}xxxx`, kind, x, y, ...extra });

describe("guild decorations", () => {
  it("every piece has art, a known category and an unlock level", () => {
    expect(GUILD_DECOR.length).toBeGreaterThanOrEqual(160);
    expect(new Set(GUILD_DECOR.map((k) => k.id)).size).toBe(GUILD_DECOR.length);
    for (const k of GUILD_DECOR) {
      expect(GUILD_DECOR_CATEGORIES).toContain(k.category);
      expect([1, 2, 4]).toContain(k.size);
      expect(k.level).toBeGreaterThanOrEqual(1);
      expect(k.level).toBeLessThanOrEqual(7);
    }
    // the first sets (and the race sets) are open from level 1; every guild level from 2 to 7 then unlocks its own 50 shared pieces
    expect(GUILD_DECOR.filter((k) => !k.race && k.level === 1 && !k.season).length).toBeGreaterThanOrEqual(160);
    expect(GUILD_DECOR.filter((k) => k.race).every((k) => k.level === 1)).toBe(true);
    for (let level = 2; level <= 7; level++) {
      const mine = GUILD_DECOR.filter((k) => k.level === level);
      expect(mine.length, `level ${level}`).toBe(50);
      expect(mine.every((k) => !k.race && !k.season)).toBe(true);
      expect(new Set(mine.map((k) => k.category)).size, `level ${level} categories`).toBeGreaterThanOrEqual(12);
    }
    // holiday pieces can be put down by any guild
    expect(GUILD_DECOR.filter((k) => k.season).every((k) => k.level === 1 && !k.race)).toBe(true);
  });

  it("checks unlocks, where things stand, and the room", () => {
    expect(guildDecorProblem([put("a"), put("b"), put("w", wallKind.id, 8, 1.8)], 1, none)).toBeNull();
    expect(guildDecorProblem([put("a", "no_such_thing")], 1, none)).toMatch(/沒有/);
    expect(guildDecorProblem([put("a", floorKind.id, 5, 1.5)], 1, none)).toMatch(/地板/);
    expect(guildDecorProblem([put("w", wallKind.id, 8, 6)], 1, none)).toMatch(/牆/);
    expect(guildDecorProblem([put("a", floorKind.id, 99, 6)], 1, none)).toMatch(/超出/);
    expect(guildDecorProblem([put("a"), put("a")], 1, none)).toMatch(/兩次/);
    const many = Array.from({ length: guildLevel(1).room + 1 }, (_, i) => put(`p${i}`));
    expect(guildDecorRoomUsed(many)).toBe(guildLevel(1).room + 1);
    expect(guildDecorProblem(many, 1, none)).toMatch(/點數/);
    expect(guildDecorProblem(many, 2, none)).toBeNull();
    // a later piece needs its level; a race's set needs a member of that race
    expect(guildDecorUnlocked({ ...floorKind, level: 3 }, 2, none)).toBe(false);
    expect(guildDecorUnlocked({ ...floorKind, level: 3 }, 3, none)).toBe(true);
    const raceKind = { ...floorKind, race: "elf" };
    expect(guildDecorUnlocked(raceKind, 7, none)).toBe(false);
    expect(guildDecorUnlocked(raceKind, 1, new Set(["elf"]))).toBe(true);
  });

  it("a holiday piece is put down only while its season is on, and what is already there stays", () => {
    const lantern = { level: 1, race: null, season: "mid_autumn" };
    expect(guildDecorUnlocked(lantern, 1, none, "2026-09-20")).toBe(true);
    expect(guildDecorUnlocked(lantern, 1, none, "2026-10-20")).toBe(false);
    expect(guildDecorUnlocked({ ...lantern, level: 3 }, 1, none, "2026-09-20")).toBe(false); // (the level still counts)
    expect(guildDecorUnlocked({ level: 1, race: null, season: null }, 1, none, "2026-10-20")).toBe(true);
    // every piece in the catalog names a season that exists, or none
    for (const k of GUILD_DECOR) expect(k.season === null || guildSeason(k.season) !== undefined, k.id).toBe(true);
    // the check of a whole list: a seasonal piece that was there before is fine after its season, a new one is not
    const seasonal = GUILD_DECOR.find((k) => k.season !== null);
    if (seasonal) {
      const piece = put("s", seasonal.id);
      const off = "2026-01-01"; // (no season of ours is on, whichever it is: pick a day when it is not)
      const day = ["2026-03-20", "2026-05-01", "2026-07-20", "2026-08-10", "2026-11-05"].find((d) => !guildDecorUnlocked(seasonal, 7, new Set(["goblin", "elf", "undead"]), d)) ?? off;
      const races = new Set(["goblin", "elf", "undead"]);
      expect(guildDecorProblem([piece], 7, races, [], day)).toMatch(/限定/);
      expect(guildDecorProblem([piece], 7, races, [piece], day)).toBeNull();
    }
  });

  it("only the leader and officers lock, and a locked piece is theirs to move", () => {
    const before = [put("a"), put("b", floorKind.id, 7, 6, { locked: true })];
    expect(guildDecorChange(before, [...before, put("c")], "member")).toEqual({ added: 1, moved: 0, removed: 0 });
    expect(guildDecorChange(before, [{ ...before[0]!, x: 6 }, before[1]!], "member")).toEqual({ added: 0, moved: 1, removed: 0 });
    expect(guildDecorChange(before, [before[0]!, { ...before[1]!, x: 8 }], "member")).toMatch(/鎖住/);
    expect(guildDecorChange(before, [before[0]!], "member")).toMatch(/鎖住/);
    expect(guildDecorChange(before, [{ ...before[0]!, locked: true }, before[1]!], "member")).toMatch(/鎖定/);
    expect(guildDecorChange(before, [before[0]!, { ...before[1]!, x: 8, locked: false }], "officer")).toEqual({ added: 0, moved: 1, removed: 0 });
    expect(guildDecorChange(before, [], "leader")).toEqual({ added: 0, moved: 0, removed: 2 });
  });
});
