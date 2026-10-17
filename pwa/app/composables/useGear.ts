import {
  enhanceCost,
  ENHANCE_MAX,
  GEAR,
  GEAR_SLOTS,
  gearMax,
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
export { enhanceCost, ENHANCE_MAX, GEAR, GEAR_SLOTS, gearMax, gearRule, repairCost };

const unopened = new Set(unopenedGear());
const TIER_TAGS: Record<number, string> = { 2: "T2", 3: "T3", 4: "T4", 5: "傳說" };
/** T−1 (only the camp's own wood and stone), 未開放 (its materials cannot be had yet), the later tiers (ECONOMY.md §1.1), or nothing. */
export function gearTier(rule: GearRule): string {
  if (unopened.has(rule.id)) return "未開放";
  if (Object.keys(rule.cost).every((id) => id === "log" || id === "stone")) return "T−1";
  return rule.tier ? (TIER_TAGS[rule.tier] ?? "") : "";
}

/** A piece's name as shown: ★ refined, and its 強化 +N. */
export const pieceLabel = (item: { id: string; refined?: boolean; plus?: number }) =>
  `${item.refined ? "★ " : ""}${GEAR.find((g) => g.id === item.id)?.name ?? item.id}${item.plus ? ` +${item.plus}` : ""}`;

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

export const durabilityText = (item: { id: string; left: number; plus?: number }) => `${Math.round((item.left / gearMax(item)) * 100)}%`;

export function residentPower(race: string, r: CampResidentView): number {
  const f = residentFighter(residentAsFighter(race, { id: r.id, breed: r.breed, gear: r.gear as never }), "attack", { id: race, ranged: RACE_RANGE[race] ?? 0 });
  return Math.round(combatPower([f]));
}

/** Everyone who can be handed gear: at home, on a held cell, guarding a friend's (not those on the road). */
export const gearHolders = (view: CampView) => view.residents.filter((r) => r.place === "home" || view.places?.[r.place]);

/** Where a resident is, as the workshop says it: 主營, 城鎮 1, 領地 2, 幫某某守. */
export const placeLabel = (view: CampView, r: CampResidentView) => (r.place === "home" ? "主營" : (view.places?.[r.place]?.label ?? "外面"));

/** Whether the handing out reaches a resident: home and the towns, every held cell with the far switch (as the server). */
export function reached(view: CampView, r: CampResidentView): boolean {
  if (r.place === "home") return true;
  const place = view.places?.[r.place];
  return !!place && r.place.startsWith("cell:") && (place.town || !!view.autoGearFar);
}

/** Who the handing out would give a new `gear` to (null: nobody needs it, or the switch is off). */
export function autoPick(view: CampView, gear: string): CampResidentView | null {
  if (view.autoGear === false) return null;
  const pool = view.residents.filter((r) => reached(view, r));
  const who = neediest(view.race, pool.map((r) => ({ id: r.id, breed: r.breed, gear: (r.gear ?? {}) as never })), { id: gear, left: gearRule(gear)?.durability ?? 1 });
  return who ? (pool.find((r) => r.id === who.id) ?? null) : null;
}

/**
 * How many would take a new `gear` over what they wear there now, among those the handing out reaches (none with the
 * switch off): worse there, a hand free for a shield, and not something put on by hand (as neediest).
 */
export function upgradeCount(view: CampView, gear: string): number {
  if (view.autoGear === false) return 0;
  const rule = gearRule(gear);
  if (!rule) return 0;
  const power = gearPower({ id: gear, left: rule.durability });
  return view.residents.filter((r) => {
    if (!reached(view, r)) return false;
    const now = r.gear?.[rule.slot];
    if (now?.pinned || gearPower(now) >= power) return false;
    if (rule.slot === "shield" && gearRule(r.gear?.weapon?.id ?? "")?.twoHanded) return false;
    if (rule.twoHanded && r.gear?.shield?.pinned) return false;
    return true;
  }).length;
}

/** How many of something the stored materials make. */
export const affordableCount = (view: CampView, cost: Record<string, number>) => Math.min(...Object.entries(cost).map(([id, n]) => Math.floor((view.materials[id] ?? 0) / Math.max(1, n))));

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
    const where = who && who.place !== "home" ? `（${placeLabel(view!, who)}）` : "";
    return who ? `${out.message}交給${who.name || residentNameFromSeed(view!.race, who.seed, who.legacySeed)}${where}。` : out.message;
  } catch (e) {
    await useCamp().refresh();
    throw new Error(e instanceof ApiError ? e.message : String(e));
  }
}
