import type { ExpeditionSummary } from "@goblincamp/shared/world";

/** A report's headline, from this camp's side (it may have been the one attacked). */
export function outcomeText(r: Pick<ExpeditionSummary, "outcome" | "defending">): string {
  const o = r.outcome;
  if (!o) return "在路上";
  const what = o.where?.kind === "home" ? "營地" : o.where?.kind === "town" ? "城鎮" : "領地";
  if (r.defending) return o.won ? (o.cell === "plundered" ? `${what}被劫掠了` : o.where?.kind === "home" ? "營地被打敗了" : `${what}被搶走了`) : `守住了${what}`;
  const fought = o.killed > 0 || o.fallen > 0;
  switch (o.cell) {
    case "cleared": return o.where?.kind === "home" ? "打贏了，對方營地被打敗" : o.where ? `打贏了，對方的${what}沒了` : "打贏了，巢穴清掉了";
    case "taken": return "打贏了，搶下這一格";
    case "settled": return fought ? "打贏了，佔領下來" : "住下了";
    case "held": return o.damage ? `打了 ${o.damage} 點傷害` : "沒打下來";
    case "camping": return "到了，有些在旁邊扎營";
    case "plundered": return "劫掠成功，搶了就走";
    default: return "回來了";
  }
}

/**
 * Where it was fought, from this camp's side: 「你的城鎮 2」 when it was attacked, 「某某的領地」 when it attacked; with the real
 * place standing there (大安森林公園). Null for a report without it (a lair, or one from before reports said where).
 */
export function placeText(r: Pick<ExpeditionSummary, "outcome" | "defending">, defender?: string | null): string | null {
  const w = r.outcome?.where;
  if (!w) return null;
  const what = w.kind === "home" ? "營地" : w.kind === "town" ? "城鎮" : "領地";
  const whose = r.defending ? `你的${w.kind === "home" ? "營地" : w.label}` : `${defender ?? "對方"}的${what}`;
  return w.landmark ? `${whose}・${w.landmark}` : whose;
}

/** Where a beaten garrison fell back to, as a line (null: nobody did). */
export function fledText(r: Pick<ExpeditionSummary, "outcome">): string | null {
  const f = r.outcome?.fled;
  if (!f) return null;
  return `${f.count} 隻撤退，${f.how === "home" ? "走回營地" : f.how === "free" ? "走去旁邊的空地住下" : `走去${f.label}`}`;
}

/** Whether it went well for this camp. */
export const wentWell = (r: Pick<ExpeditionSummary, "outcome" | "defending">) => (r.defending ? !r.outcome?.won : !!r.outcome?.won || !!r.outcome?.damage);
