import type { ExpeditionSummary } from "@goblincamp/shared/world";

/** A report's headline, from this camp's side (it may have been the one attacked). */
export function outcomeText(r: Pick<ExpeditionSummary, "outcome" | "defending">): string {
  const o = r.outcome;
  if (!o) return "在路上";
  if (r.defending) return o.won ? "領地被搶走了" : "守住了領地";
  const fought = o.killed > 0 || o.fallen > 0;
  switch (o.cell) {
    case "cleared": return "打贏了，巢穴清掉了";
    case "taken": return "打贏了，搶下這一格";
    case "settled": return fought ? "打贏了，佔領下來" : "住下了";
    case "held": return o.damage ? `打了 ${o.damage} 點傷害` : "沒打下來";
    default: return "回來了";
  }
}

/** Whether it went well for this camp. */
export const wentWell = (r: Pick<ExpeditionSummary, "outcome" | "defending">) => (r.defending ? !r.outcome?.won : !!r.outcome?.won || !!r.outcome?.damage);
