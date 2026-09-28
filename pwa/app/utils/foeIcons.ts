import { FOES } from "@goblincamp/shared/world";

/** Where each foe's icon is in /world/foes.png (mac/tools/make_world_foes.py writes both). */
export interface FoeSheet {
  size: number;
  cols: number;
  icons: Record<string, number>;
}

const sheet = ref<FoeSheet | null>(null);
let loading: Promise<void> | null = null;

export function useFoeSheet() {
  loading ??= fetch("/world/foes.json")
    .then((r) => r.json() as Promise<FoeSheet>)
    .then((s) => void (sheet.value = s))
    .catch(() => void (loading = null));
  return sheet;
}

/** The icon's cell in the sheet (column, row), or null for one that has none. */
export function iconAt(s: FoeSheet | null, id: string): { col: number; row: number; rows: number } | null {
  const n = s?.icons[id];
  if (!s || n === undefined) return null;
  return { col: n % s.cols, row: Math.floor(n / s.cols), rows: Math.ceil(Object.keys(s.icons).length / s.cols) };
}

/** The one to show for a group: its strongest member (a lair's leader, say). */
export function leaderOf(foes: Record<string, number>): string {
  return Object.keys(foes).sort((a, b) => (FOES[b]?.hp ?? 0) - (FOES[a]?.hp ?? 0))[0] ?? "slime";
}
