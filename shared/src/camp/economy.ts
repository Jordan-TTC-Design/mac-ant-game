/**
 * The economy dashboard (admin): how the camps' materials and the guilds' contribution come in, pile up and go out, and how
 * the race-level content is going (raids, bosses, merchants, visitors). Every change to a camp's materials is written down
 * as a "flow" camp event (its source and what came in or went out), kept as long as the camp's events (30 days).
 */

/** Where a camp's materials came from or went: a camp command's kind, or one of these. */
export type FlowSource = string;
export const FLOW_SOURCE_NAMES: Record<string, string> = {
  production: "工地產出",
  raid: "突襲掉落",
  "raid-plunder": "突襲打輸被搶",
  salvage: "壞裝備拆回",
  world: "大世界",
  "world-loot": "大世界戰利品",
  "world-yield": "領地產出",
  "world-upkeep": "領地維持（糧食）",
  "world-supplies": "出征帶的補給",
  "world-market": "城鎮市場",
  "world-boss": "世界王分到的",
  "world-plundered": "被別人搶走",
  "world-salvage": "大世界壞裝備拆回",
  "world-open": "開大世界送的糧食",
  "world-build": "大世界蓋建築",
  "world-talents": "天賦洗點",
  "merchant-arrive": "商人見面禮",
  "merchant-trade": "商人交易",
  craft: "工坊製作",
  repair: "修理",
  refine: "拼裝改造",
  enhance: "裝備強化",
  "building-build": "營地建設",
  "site-build": "蓋工地",
  "site-upgrade": "升工地",
  "farm-upgrade": "升農田",
  "site-demolish": "拆工地退回",
  "quest-claim": "任務獎勵",
  "ranch-sync": "牧場",
  "guild-donate": "捐給公會",
  "visitor-accept": "來訪見面禮",
  food: "吃掉的食物",
};

export function flowSourceName(source: string): string {
  return FLOW_SOURCE_NAMES[source] ?? source;
}

/** What changed from `before` to `after` (id → +in / −out; the unchanged left out). */
export function materialDelta(before: Readonly<Record<string, number>>, after: Readonly<Record<string, number>>): Record<string, number> {
  const out: Record<string, number> = {};
  for (const id of new Set([...Object.keys(before), ...Object.keys(after)])) {
    const d = (after[id] ?? 0) - (before[id] ?? 0);
    if (d) out[id] = d;
  }
  return out;
}

export interface EconomyFlowRow {
  source: string;
  name: string;
  /** Materials in (positive) and out (positive, what was spent), over the window. */
  in: number;
  out: number;
  /** The materials most moved by it (id → net). */
  top: { id: string; name: string; net: number }[];
}

export interface EconomyMaterialRow {
  id: string;
  name: string;
  /** Held by all camps now; the median and the 90th percentile of one camp's (of those with any). */
  total: number;
  holders: number;
  median: number;
  p90: number;
  /** Over the window: came in, went out. */
  in: number;
  out: number;
}

/** `GET /api/admin/economy?days=N`. */
export interface EconomyReport {
  days: number;
  at: string;
  players: {
    camps: number;
    /** Camps whose books moved in the window. */
    active: number;
    byRace: Record<string, number>;
    /** Race level (big world) → camps; level 1 includes those who never opened it. */
    byLevel: Record<string, number>;
    byStage: Record<string, number>;
  };
  /** Materials: totals and spread now, and the window's flows. */
  materials: EconomyMaterialRow[];
  /** By source over the window. */
  flows: EconomyFlowRow[];
  /** Day by day (Taipei), all materials together: in and out. */
  daily: { day: string; in: number; out: number }[];
  /** The richest camps by everything they hold. */
  richest: { name: string; race: string; level: number; total: number }[];
  raids: {
    count: number;
    won: number;
    fallen: number;
    /** Monsters by variant (plain included). */
    variants: Record<string, number>;
    /** Level bosses: came / beaten, by their level. */
    bosses: { level: number; came: number; beaten: number }[];
  };
  merchant: { visits: number; trades: number; guildBuys: number };
  visitors: { accepted: number; declined: number; dismissed: number; specials: number };
  contribution: {
    /** Given to guilds over the window, and all time; spent (clothes, the guild merchant) all time; left, all players. */
    givenWindow: number;
    givenAll: number;
    spentAll: number;
    left: number;
    guilds: number;
    guildLevels: Record<string, number>;
  };
}
