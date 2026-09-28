// The Mac keeps its own copy of the gear list (Equipment.swift, with how each piece is drawn) and of the materials' names
// (Materials.swift and the Animals manifests). The server checks crafting against this package's list, so the two must
// say the same thing: every piece with the same slot and cost, every material with the same name.
import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { MATERIALS } from "../world/drops.ts";
import { GEAR } from "./gear.ts";

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
