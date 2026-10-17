import { GEAR, gearPower } from "@goblincamp/shared/camp";

/** Where each piece's icon is in /gear/icons.png (mac/tools/make_gear_icons.py writes both). */
export interface GearSheet {
  size: number;
  cols: number;
  icons: Record<string, number>;
}

const sheet = ref<GearSheet | null>(null);
let loading: Promise<void> | null = null;

/** The sheet's index (fetched once; null until it is here). */
export function useGearSheet() {
  loading ??= fetch("/gear/icons.json")
    .then((r) => r.json() as Promise<GearSheet>)
    .then((s) => void (sheet.value = s))
    .catch(() => void (loading = null));
  return sheet;
}

/** The frame's colours, the weakest quarter of a slot's pieces to the strongest (as the Mac's GearIcons). */
export const GEAR_RANK_COLORS = ["#999999", "#4dab45", "#3d80db", "#a14fdb"];

/** 0…3: which quarter of the pieces for its slot this one is in, by power when new. */
export function gearRank(id: string): number {
  const rule = GEAR.find((g) => g.id === id);
  if (!rule) return 0;
  const power = (g: typeof rule) => gearPower({ id: g.id, left: g.durability });
  const slot = GEAR.filter((g) => g.slot === rule.slot).map(power);
  return Math.min(3, Math.floor((slot.filter((p) => p < power(rule)).length * 4) / Math.max(1, slot.length)));
}
