import { describe, expect, it } from "vitest";
import { MERCHANT_DECOR, MERCHANT_KINDS, MERCHANT_OUTFITS, merchantBuyProblem, merchantVisit } from "./guild-merchant.ts";
import { GUILD_OUTFITS, outfitClosed } from "./guild-outfits.ts";

const HOUR = 3_600_000;

describe("the guild merchant", () => {
  it("has sixty pieces of his own, and some clothes", () => {
    expect(MERCHANT_KINDS.length).toBe(60);
    expect(MERCHANT_KINDS.every((k) => k.level === 1 && !k.race && !k.season)).toBe(true);
    expect(GUILD_OUTFITS.filter((o) => o.merchant).length).toBeGreaterThanOrEqual(MERCHANT_OUTFITS);
  });

  it("comes once a week for two days, on a weekday, the same for everyone", () => {
    const start = Date.parse("2026-10-19T00:00:00+08:00"); // (a Monday in Taiwan)
    let hours = 0;
    const visits = new Set<string>();
    for (let h = 0; h < 7 * 24 * 4; h++) {
      const v = merchantVisit("guild-a", new Date(start + h * HOUR));
      if (v.here) hours++;
      visits.add(v.from);
      const from = new Date(v.from);
      expect([1, 2, 3, 4, 5]).toContain(new Date(from.getTime() + 8 * HOUR).getUTCDay()); // (Monday–Friday in Taiwan)
      expect(Date.parse(v.until) - Date.parse(v.from)).toBe(48 * HOUR);
      expect(v.here ? start + h * HOUR >= Date.parse(v.from) : start + h * HOUR < Date.parse(v.from)).toBe(true);
    }
    expect(hours).toBe(4 * 48);
    expect(visits.size).toBe(4 + 1); // (four weeks' visits, and then the fifth one's ahead)
    expect(merchantVisit("guild-a", new Date(start))).toEqual(merchantVisit("guild-a", new Date(start)));
  });

  it("carries a few of his pieces and clothes while here, and sells each to a guild once", () => {
    const start = Date.parse("2026-10-19T00:00:00+08:00");
    const v = merchantVisit("guild-b", new Date(Date.parse(merchantVisit("guild-b", new Date(start)).from) + HOUR));
    expect(v.here).toBe(true);
    expect(v.decor).toHaveLength(MERCHANT_DECOR);
    expect(v.outfits).toHaveLength(MERCHANT_OUTFITS);
    const { kind, price } = v.decor[0]!;
    expect(merchantBuyProblem(kind, v, [], price)).toBeNull();
    expect(merchantBuyProblem(kind, v, [kind], price)).toContain("已經有");
    expect(merchantBuyProblem(kind, v, [], price - 1)).toContain("貢獻不夠");
    expect(merchantBuyProblem(kind, { ...v, here: false }, [], price)).toContain("不在");
    const o = GUILD_OUTFITS.find((x) => x.id === v.outfits[0])!;
    expect(outfitClosed(o, { today: "2026-10-20", guildLevel: 1, merchant: new Set(v.outfits) })).toBeNull();
    expect(outfitClosed(o, { today: "2026-10-20", guildLevel: 1, merchant: new Set() })).toContain("商人");
  });
});

describe("limited clothes", () => {
  it("each is a holiday's, a guild level's or the merchant's", () => {
    for (const o of GUILD_OUTFITS.filter((x) => x.season || x.level || x.merchant)) expect([o.season, o.level, o.merchant].filter(Boolean)).toHaveLength(1);
    for (let level = 2; level <= 7; level++) expect(GUILD_OUTFITS.filter((o) => o.level === level), `level ${level}`).toHaveLength(6);
    const lv = GUILD_OUTFITS.find((o) => o.level === 3)!;
    expect(outfitClosed(lv, { today: "2026-10-20", guildLevel: 2, merchant: new Set() })).toContain("3 級");
    expect(outfitClosed(lv, { today: "2026-10-20", guildLevel: 3, merchant: new Set() })).toBeNull();
    const xmas = GUILD_OUTFITS.find((o) => o.season === "christmas")!;
    expect(outfitClosed(xmas, { today: "2026-10-20", guildLevel: 7, merchant: new Set() })).toContain("聖誕");
    expect(outfitClosed(xmas, { today: "2026-12-20", guildLevel: 0, merchant: new Set() })).toBeNull();
  });
});
