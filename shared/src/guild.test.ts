import { describe, expect, it } from "vitest";
import { AVATAR_OPTIONS, avatarProblem, BADGE_PALETTE, BADGE_SIZE, badgeSchema, DEFAULT_BADGE, defaultAvatar, GUILD_LEVELS, guildLevel, presenceNow, PRESENCE_TTL_SECONDS, randomAvatar } from "./guild.ts";

describe("guild rules", () => {
  it("levels grow to 30 members", () => {
    expect(GUILD_LEVELS[0]!.members).toBe(5);
    expect(GUILD_LEVELS.at(-1)!.members).toBe(30);
    for (let i = 1; i < GUILD_LEVELS.length; i++) {
      const [a, b] = [GUILD_LEVELS[i - 1]!, GUILD_LEVELS[i]!];
      expect(b.members > a.members && b.width > a.width && b.height > a.height && b.room > a.room).toBe(true);
    }
    expect(guildLevel(0).level).toBe(1);
    expect(guildLevel(99).level).toBe(7);
  });

  it("the default badge is a 16×16 drawing in the palette", () => {
    expect(BADGE_PALETTE).toHaveLength(16);
    expect(DEFAULT_BADGE).toHaveLength(BADGE_SIZE * BADGE_SIZE);
    expect(badgeSchema.safeParse(DEFAULT_BADGE).success).toBe(true);
  });

  it("every race has 8 hairstyles per sex, and its defaults and random avatars are allowed", () => {
    let seed = 1;
    const rand = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
    for (const race of ["goblin", "elf", "undead"] as const) {
      for (const sex of ["m", "f"] as const) {
        expect(new Set(AVATAR_OPTIONS[race].hair[sex]).size).toBe(8);
        expect(avatarProblem(defaultAvatar(race, sex))).toBeNull();
        for (let i = 0; i < 200; i++) expect(avatarProblem(randomAvatar(race, sex, rand))).toBeNull();
      }
    }
    // only the skeleton has an eye flame
    expect(defaultAvatar("undead", "m").flame).toBe("cyan");
    expect(defaultAvatar("goblin", "m").flame).toBeUndefined();
    expect(avatarProblem({ ...defaultAvatar("elf", "m"), hair: "mohawk" })).not.toBeNull();
  });

  it("random keeps the parts asked for", () => {
    const mine = { ...defaultAvatar("elf", "f"), hair: "ponytail", hairColor: "pink" as const };
    for (let i = 0; i < 20; i++) expect(randomAvatar("elf", "f", Math.random, mine, ["hair", "hairColor"])).toMatchObject({ hair: "ponytail", hairColor: "pink" });
  });

  it("a quiet Mac is offline", () => {
    const at = new Date("2026-10-08T00:00:00Z");
    expect(presenceNow("focus", at, new Date(at.getTime() + 1000))).toBe("focus");
    expect(presenceNow("focus", at, new Date(at.getTime() + (PRESENCE_TTL_SECONDS + 1) * 1000))).toBe("offline");
    expect(presenceNow(null, null, at)).toBe("offline");
  });
});
