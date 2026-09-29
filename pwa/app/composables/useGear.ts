import {
  GEAR,
  GEAR_SLOTS,
  gearPower,
  gearRule,
  neediest,
  RACE_RANGE,
  repairCost,
  residentAsFighter,
  type CampResidentView,
  type CampView,
  type GearRule,
  type GearSlot,
} from "@goblincamp/shared/camp";
import { combatPower, residentFighter, unopenedGear } from "@goblincamp/shared/world";
import { ApiError, api } from "~/utils/api";

/**
 * The workshop and the roster's gear on the phone (the same rules as the server and the Mac: shared/src/camp/gear.ts).
 * A piece given by hand is pinned there; one taken off by hand is held in the store; the rest is handed out by itself
 * while the camp's switch is on.
 */
export const SLOT_LABELS: Record<GearSlot, string> = { weapon: "武器", shield: "盾牌", head: "帽子", chest: "胸甲", legs: "褲子", feet: "鞋子", hands: "手甲" };
export { GEAR, GEAR_SLOTS, gearRule, repairCost };

const unopened = new Set(unopenedGear());
/** T−1 (only the camp's own wood and stone), 未開放 (its materials cannot be had yet), or nothing. */
export function gearTier(rule: GearRule): string {
  if (unopened.has(rule.id)) return "未開放";
  if (Object.keys(rule.cost).every((id) => id === "log" || id === "stone")) return "T−1";
  return "";
}

const clean = (v: number) => (v === Math.round(v) ? String(v) : v.toFixed(1));
/** The Mac's Gear.effectText. */
export function effectText(rule: GearRule): string {
  const parts: string[] = [];
  if (rule.might) parts.push(`出手 +${clean(rule.might)}`);
  if (rule.health) parts.push(`多撐 ${clean(rule.health)} 下`);
  if (rule.block) parts.push(`${Math.round(rule.block * 100)}% 擋掉攻擊`);
  if (rule.speed && rule.speed > 0) parts.push(`走路快 ${Math.round(rule.speed * 100)}%`);
  if (rule.speed && rule.speed < 0) parts.push(`走路慢 ${Math.round(-rule.speed * 100)}%`);
  if (rule.reach) parts.push("打得更遠");
  if (rule.twoHanded) parts.push("雙手");
  return parts.join("，");
}

export const durabilityText = (item: { id: string; left: number }) => `${Math.round((item.left / (gearRule(item.id)?.durability ?? 1)) * 100)}%`;

export function residentPower(race: string, r: CampResidentView): number {
  const f = residentFighter(residentAsFighter(race, { id: r.id, breed: r.breed, gear: r.gear as never }), "attack", { id: race, ranged: RACE_RANGE[race] ?? 0 });
  return Math.round(combatPower([f]));
}

/** Who the handing out would give a new `gear` to (null: nobody needs it, or the switch is off). */
export function autoPick(view: CampView, gear: string): CampResidentView | null {
  if (view.autoGear === false) return null;
  const home = view.residents.filter((r) => r.place === "home");
  const who = neediest(view.race, home.map((r) => ({ id: r.id, breed: r.breed, gear: (r.gear ?? {}) as never })), { id: gear, left: gearRule(gear)?.durability ?? 1 });
  return who ? (home.find((r) => r.id === who.id) ?? null) : null;
}

/** A piece's worth for sorting (the same as the handing out uses). */
export const pieceWorth = (item: { id: string; left: number }) => gearPower(item);

/**
 * Sends one camp command; the camp is fetched again. Returns the server's line, with who got the piece (the server knows
 * residents by number: their names come from their seeds), or throws its reason.
 */
export async function gearCommand(command: Record<string, unknown>): Promise<string> {
  try {
    const out = await api<{ message: string; resident: number | null }>("POST", "camp/commands", { ...command, requestId: crypto.randomUUID() });
    await useCamp().refresh();
    const view = useCamp().state.saved?.view;
    const who = out.resident !== null && command.kind === "craft" ? view?.residents.find((r) => r.id === out.resident) : undefined;
    return who ? `${out.message}交給${who.name || residentNameFromSeed(view!.race, who.seed, who.legacySeed)}。` : out.message;
  } catch (e) {
    await useCamp().refresh();
    throw new Error(e instanceof ApiError ? e.message : String(e));
  }
}
