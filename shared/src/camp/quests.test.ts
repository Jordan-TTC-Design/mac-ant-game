import { describe, expect, it } from "vitest";
import { ITEMS, MATERIALS } from "../world/index.ts";
import { gearRule } from "./gear.ts";
import { DECOR_KINDS } from "./decor-catalog.ts";
import { QUESTS, questRule, questShown } from "./quests.ts";

describe("任務", () => {
  it("are eighty-six (thirty early ones, fifty harder, six of focus and the ranch), each with a reward that exists and a chain that holds together", () => {
    expect(QUESTS).toHaveLength(86);
    expect(new Set(QUESTS.map((q) => q.id)).size).toBe(86);
    for (const q of QUESTS) {
      const r = q.reward;
      expect(Object.keys(r.materials ?? {}).length + (r.gear?.length ?? 0) + (r.residents ?? 0) + Object.keys(r.decor ?? {}).length, q.id).toBeGreaterThan(0);
      for (const [race, id] of Object.entries(r.decor ?? {})) expect(DECOR_KINDS.find((k) => k.id === id && k.race === race && k.limited === "quest"), `${q.id}: ${id}`).toBeDefined();
      for (const id of Object.keys(r.materials ?? {})) expect(MATERIALS[id], `${q.id}: ${id}`).toBeDefined();
      for (const id of r.gear ?? []) expect(gearRule(id), `${q.id}: ${id}`).toBeDefined();
      if (q.after) expect(questRule(q.after), `${q.id} after ${q.after}`).toBeDefined();
    }
    for (const i of ITEMS) if (i.unlock) expect(questRule(i.unlock), `${i.id} opens with ${i.unlock}`).toBeDefined();
  });

  it("shows a chain's next only once the one before was claimed", () => {
    const next = questRule("lumber_2")!;
    expect(questShown(next, {})).toBe(false);
    expect(questShown(next, { site_1: "2026-10-01T00:00:00Z" })).toBe(true);
    expect(questShown(questRule("site_1")!, {})).toBe(true);
  });
});
