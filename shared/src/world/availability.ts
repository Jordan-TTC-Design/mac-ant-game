/**
 * Which materials can be had now, and so which gear can be made (BALANCE.md §4): what the camp's sites make, what camp raids drop, what held cells
 * yield, what the open tiers' foes and lairs leave, and the great monsters' spoils while they are out. A piece whose cost
 * needs anything else shows as 未開放 in the workshop (the Mac keeps the list: Equipment.swift `Gears.unopened`, checked
 * against this by mac-sync.test.ts).
 */
import { MONSTER_DROPS, SCRAP_DROPS } from "../camp/combat.ts";
import { GEAR } from "../camp/gear.ts";
import { GATHERING, SITE_RULES } from "../camp/sites.ts";
import { CAMP_MONSTERS } from "../camp/raids.ts";
import { BOSSES, BOSSES_BY_DEFAULT } from "./bosses.ts";
import { LAIRS, OPEN_TIERS } from "./contents.ts";
import { FOE_DROPS } from "./drops.ts";
import { TERRAIN_YIELD } from "./territory.ts";

export function openMaterials(bosses = BOSSES_BY_DEFAULT): Set<string> {
  const out = new Set<string>();
  for (const d of SCRAP_DROPS) out.add(d.id);
  for (const id of Object.keys(GATHERING)) out.add(id);
  for (const rule of SITE_RULES) for (const v of [rule.base, ...Object.values(rule.races ?? {})]) for (const id of [...Object.keys(v.makes ?? {}), ...Object.keys(v.finds ?? {})]) out.add(id);
  for (const m of CAMP_MONSTERS) for (const d of MONSTER_DROPS[m.id] ?? []) out.add(d.id);
  for (const list of Object.values(TERRAIN_YIELD)) for (const y of list) out.add(y.id);
  for (const lair of LAIRS.filter((l) => l.tier <= OPEN_TIERS)) {
    for (const d of lair.loot) out.add(d.id);
    for (const m of lair.members) for (const d of FOE_DROPS[m.foe] ?? []) out.add(d.id);
  }
  if (bosses) for (const kind of BOSSES) for (const d of kind.drops) out.add(d.id);
  return out;
}

/** The gear that cannot be made yet (something it needs comes only from places not open). */
export function unopenedGear(bosses = BOSSES_BY_DEFAULT): string[] {
  const open = openMaterials(bosses);
  return GEAR.filter((g) => Object.keys(g.cost).some((id) => !open.has(id))).map((g) => g.id);
}
