import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { merchantGift, merchantStock, merchantVisit, taipeiDay } from "./merchant.ts";

describe("the merchant's rules", () => {
  it("only ever asks for and gives materials that exist", () => {
    for (const race of ["goblin", "elf", "undead"]) {
      for (let k = 0; k < 300; k++) {
        for (const offer of merchantStock(`v${k}`, race)) {
          for (const id of [...Object.keys(offer.give), ...Object.keys(offer.get)]) expect(MATERIALS[id], id).toBeDefined();
          for (const n of [...Object.values(offer.give), ...Object.values(offer.get)]) expect(n).toBeGreaterThan(0);
        }
        for (const id of Object.keys(merchantGift(`v${k}`, 3))) expect(MATERIALS[id], id).toBeDefined();
      }
    }
  });

  it("brings four to six different offers, the same for the same visit, a bargain now and then", () => {
    let sales = 0;
    for (let k = 0; k < 400; k++) {
      const stock = merchantStock(`v${k}`, "elf");
      expect(stock.length).toBeGreaterThanOrEqual(4);
      expect(stock.length).toBeLessThanOrEqual(6);
      expect(new Set(stock.map((o) => JSON.stringify(o.get))).size).toBe(stock.length);
      expect(merchantStock(`v${k}`, "elf")).toEqual(stock);
      sales += stock.filter((o) => o.sale).length;
    }
    expect(sales).toBeGreaterThan(30);
    expect(sales).toBeLessThan(100);
  });

  it("gives a bigger present to a bigger camp", () => {
    const total = (stage: number) => Array.from({ length: 50 }, (_, k) => Object.values(merchantGift(`g${k}`, stage)).reduce((a, b) => a + b, 0)).reduce((a, b) => a + b, 0);
    expect(total(2)).toBeGreaterThan(total(1));
    expect(total(3)).toBeGreaterThan(total(2));
  });

  it("stays fifteen minutes; days are counted in Taipei", () => {
    const v = merchantVisit("x", "goblin", 1, new Date("2026-10-02T15:50:00Z"));
    expect(v.leavesAt).toBe("2026-10-02T16:05:00.000Z");
    expect(taipeiDay(new Date("2026-10-02T15:59:00Z"))).toBe("2026-10-02");
    expect(taipeiDay(new Date("2026-10-02T16:00:00Z"))).toBe("2026-10-03");
  });
});
