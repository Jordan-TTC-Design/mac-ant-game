// The Mac keeps its own copy of the gear list (Equipment.swift, with how each piece is drawn) and of the materials' names
// (Materials.swift and the Animals manifests). The server checks crafting against this package's list, so the two must
// say the same thing: every piece with the same slot and cost, every material with the same name.
import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { GEAR } from "./gear.ts";
import { unopenedGear } from "../world/availability.ts";

const mac = new URL("../../../mac/", import.meta.url);
const read = (path: string) => readFileSync(new URL(path, mac), "utf8");

describe("the Mac's copies", () => {
  it("has the same gear (slot and cost)", () => {
    const swift = read("Sources/GoblinCamp/Equipment.swift");
    const pieces = new Map<string, { slot: string; cost: Record<string, number> }>();
    for (const m of swift.matchAll(/Gear\(id: "(\w+)", name: "[^"]+", slot: \.(\w+),.*?cost: \[(.*?)\]/g)) {
      const cost = Object.fromEntries([...m[3]!.matchAll(/\("(\w+)", (\d+)\)/g)].map((c) => [c[1]!, Number(c[2])]));
      pieces.set(m[1]!, { slot: m[2]!, cost });
    }
    for (const g of GEAR) expect(pieces.get(g.id), g.id).toEqual({ slot: g.slot, cost: g.cost });
    expect(pieces.size).toBe(GEAR.length);
  });

  it("has the same numbers for every piece (might, health, block, speed, reach, two hands, durability)", () => {
    const swift = read("Sources/GoblinCamp/Equipment.swift");
    const durable = Object.fromEntries([...swift.matchAll(/"(\w+)": (\d+)/g)].map((m) => [m[1]!, Number(m[2])]));
    for (const m of swift.matchAll(/Gear\(id: "(\w+)", name: "[^"]+", slot: \.(\w+),(.*?)cost: \[/g)) {
      const g = GEAR.find((x) => x.id === m[1]);
      if (!g) continue;
      const stat = (k: string) => Number(m[3]!.match(new RegExp(`${k}: (-?[\\d.]+)`))?.[1] ?? 0);
      const got = { might: stat("might"), health: stat("health"), block: stat("block"), speed: stat("speed"), reach: stat("reach"), two: m[3]!.includes("grip: .two"), durability: durable[g.id] ?? (g.slot === "weapon" ? 120 : 20) };
      const want = { might: g.might ?? 0, health: g.health ?? 0, block: g.block ?? 0, speed: g.speed ?? 0, reach: g.reach ?? 0, two: !!g.twoHanded, durability: g.durability };
      expect(got, g.id).toEqual(want);
    }
  });

  it("marks the same pieces 未開放 (their materials cannot be had yet)", () => {
    const swift = read("Sources/GoblinCamp/Equipment.swift");
    const list = swift.match(/static let unopened: Set<String> = \[([^\]]*)\]/)?.[1] ?? "";
    expect([...list.matchAll(/"(\w+)"/g)].map((m) => m[1]).sort()).toEqual(unopenedGear().sort());
  });

  it("names every material the same", () => {
    const names = new Map<string, string>();
    for (const m of read("Sources/GoblinCamp/Materials.swift").matchAll(/DropSpec\(id: "(\w+)", name: "([^"]+)"/g)) names.set(m[1]!, m[2]!);
    for (const dir of readdirSync(new URL("Resources/Animals/", mac))) {
      try {
        const manifest = JSON.parse(read(`Resources/Animals/${dir}/manifest.json`)) as { drops?: { id: string; name: string }[] };
        for (const d of manifest.drops ?? []) names.set(d.id, d.name);
      } catch {
        // (not an animal folder)
      }
    }
    for (const [id, m] of Object.entries(MATERIALS)) expect(names.get(id), id).toBe(m.name);
  });

  it("can make every piece from materials that exist", () => {
    for (const g of GEAR) for (const id of Object.keys(g.cost)) expect(MATERIALS[id], `${g.id} needs ${id}`).toBeDefined();
  });
});
