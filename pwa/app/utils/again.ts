/**
 * 再派一次: the last attack sent to each cell, kept on this phone (who went, from where, the food), so a second wave
 * is one tap. Nothing here is checked: the dispatch dialog takes what still fits.
 */
export interface LastAttack {
  from: string;
  party: number[];
  supplies: Record<string, number>;
  settle: boolean;
}

const key = (cell: string) => `goblincamp.again.${cell}`;

export function loadLastAttack(cell: string): LastAttack | null {
  try {
    const text = localStorage.getItem(key(cell));
    return text ? (JSON.parse(text) as LastAttack) : null;
  } catch {
    return null;
  }
}

export function saveLastAttack(cell: string, last: LastAttack) {
  try {
    localStorage.setItem(key(cell), JSON.stringify(last));
  } catch {
    // (it just will not be offered)
  }
}
