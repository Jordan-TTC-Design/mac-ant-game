/**
 * 種族天賦 (2026-10-17, server/WORLD.md): each race's four trees of talents (three for the big world, one for the camp), bought with the points its race level gives
 * (one a level past the first), like an old talent tree: a tree's rows open as points are spent in it and the race level
 * grows, a talent takes up to a few ranks, some need the one above them first. Points spent stay (a talent is not taken back)
 * until the whole tree is reset, for crystal shards and amber that cost more every time.
 *
 * Every talent adds to one effect (TalentEffect); talentBonus adds them up, and the server uses the sums where the big world
 * works (server/src/world/service.ts).
 */

/** What a talent adds to, a share (0.04 = 4%) or a count a rank. */
export type TalentEffect =
  | "travel" // parties walk this share quicker
  | "regionTravel" // moving within one's own joined cells: this share quicker again
  | "attack" // parties hit this share harder (every fight)
  | "pvpAttack" // … and this share more against other camps
  | "lairAttack" // … and this share more against lairs and great monsters
  | "hp" // parties' hit points +share
  | "fort" // the defenders of a held cell: hit points +share
  | "homeFort" // the defenders of the home camp: hit points +share
  | "yield" // held cells yield this share more
  | "nest" // nests raise residents this share quicker
  | "room" // each held cell houses this many more
  | "party" // this many more go in a party
  | "reinforce" // this many more come to help from each held cell next door
  | "upkeep" // upkeep this share less
  | "freeCells" // this many more cells without upkeep
  | "wear" // gear wears this share less
  | "market" // a town's market gives this share more
  | "loot" // beaten lairs drop this share more
  | "xp" // race experience this share more
  | "intel" // see what an attacking party is made of
  // each big-world tree's top talent opens something new rather than adding to a number (2026-10-17: TALENT_ABILITIES)
  | "plunder" // 劫掠: a party may raid another camp's cell, take from its store and leave
  | "tunnels" // 地道: all one's own cells count as joined for walking, and parties pass under others' walls
  | "refine" // 拼裝改造: the workshop refines a piece into a better ★ one; a broken piece gives all its materials back
  | "ambush" // 伏擊: parties passing by one's cells are shot at first
  | "sacredTree" // 聖樹: an elves-only building on park or forest
  | "moonGate" // 月光傳送: once a day, a party moves between one's towns at once
  | "raiseDead" // 戰場復甦: some of the fallen rise and join after a won fight
  | "nightRaid" // 夜襲: parties setting out at night walk quicker and are not seen coming
  | "blight" // 腐化大地: others' cells next to one's own yield less, and lairs next to them are weaker
  // the camp tree (its effects are the camp's: server/src/camp, shared/src/camp, the Mac's camp)
  | "campYield" // the camp's sites make this share more
  | "campBirths" // the camp raises residents this share quicker
  | "campGuard" // residents hit this share harder against monster raids on the camp
  | "campRanch" // the ranch gives this share more
  | "campBuild" // sites build this share quicker
  | "campLife" // residents live this share longer
  | "campHost" // visitors who want to move in ask this share less
  | "campTrade" // the camp merchant brings this many more offers
  | "campHeart"; // raids and level bosses drop this share more

export interface Talent {
  id: string;
  name: string;
  tree: string;
  /** Row (0 at the top) and column (0…2) in its tree. */
  row: number;
  col: number;
  ranks: number;
  effect: TalentEffect;
  /** What one rank adds. */
  per: number;
  /** The talent above it that must be at full rank first. */
  requires?: string;
}

export interface TalentTree {
  id: string;
  race: string;
  name: string;
  icon: string;
  blurb: string;
}

/** Points spent in a tree to open each next row; and the race level each row needs (the rows open slowly). */
export const TALENT_ROW_POINTS = 4;
export const TALENT_ROW_LEVELS = [2, 5, 10, 15, 20] as const;

/** The points a race level gives: one for every level past the first. */
export const talentPoints = (level: number) => Math.max(0, Math.floor(level) - 1);

/** What resetting costs the n-th time (0: the first): more each time. */
export function talentResetCost(resets: number): Record<string, number> {
  const k = Math.min(resets, 9) + 1;
  return { crystal_shard: 15 * k, amber: 4 * k };
}

const t = (tree: string, row: number, col: number, id: string, name: string, effect: TalentEffect, per: number, ranks = 3, requires?: string): Talent => ({
  id: `${tree}.${id}`,
  name,
  tree,
  row,
  col,
  ranks,
  effect,
  per,
  ...(requires ? { requires: `${tree}.${requires}` } : {}),
});

export const TALENT_TREES: readonly TalentTree[] = [
  { id: "g_raid", race: "goblin", name: "掠奪", icon: "🗡️", blurb: "打得兇、搶得多：出征與打劫" },
  { id: "g_horde", race: "goblin", name: "群聚", icon: "🏕️", blurb: "生得多、住得擠、人海戰術" },
  { id: "g_tinker", race: "goblin", name: "工匠", icon: "🔧", blurb: "會修會換、精打細算" },
  { id: "e_ranger", race: "elf", name: "遊俠", icon: "🏹", blurb: "走得快、看得遠、打獵精準" },
  { id: "e_grove", race: "elf", name: "森林", icon: "🌳", blurb: "土地豐饒、生命綿長" },
  { id: "e_elder", race: "elf", name: "長老", icon: "📜", blurb: "智慧治理：經驗、貿易、守護家園" },
  { id: "u_legion", race: "undead", name: "亡軍", icon: "💀", blurb: "數量壓倒一切、不怕死" },
  { id: "u_dread", race: "undead", name: "恐懼", icon: "🦇", blurb: "讓活人害怕：攻城與守城" },
  { id: "u_crypt", race: "undead", name: "墓園", icon: "⚰️", blurb: "不吃不喝、物盡其用" },
  // the camp's own tree, the same for every race under its own name (its effects are worked by the camp)
  { id: "g_camp", race: "goblin", name: "營火", icon: "🔥", blurb: "營地：產出、生養、守營" },
  { id: "e_camp", race: "elf", name: "家園", icon: "🏡", blurb: "營地：產出、生養、守營" },
  { id: "u_camp", race: "undead", name: "墓地", icon: "🪦", blurb: "營地：產出、生養、守營" },
];

/** The camp tree's talents, the same in each race's camp tree (ids `<tree>.camp_…`). */
const campTree = (tree: string) => [
  t(tree, 0, 0, "camp_yield", "豐收", "campYield", 0.03),
  t(tree, 0, 2, "camp_births", "多產", "campBirths", 0.03),
  t(tree, 1, 0, "camp_guard", "守營", "campGuard", 0.04),
  t(tree, 1, 2, "camp_ranch", "牧人", "campRanch", 0.05),
  t(tree, 2, 0, "camp_build", "巧手", "campBuild", 0.1, 2),
  t(tree, 2, 2, "camp_life", "長壽", "campLife", 0.05),
  t(tree, 3, 0, "camp_host", "好客", "campHost", 0.15, 2),
  t(tree, 3, 2, "camp_trade", "精打細算", "campTrade", 1, 1),
  t(tree, 4, 1, "camp_heart", "營地之心", "campHeart", 0.5, 1, "camp_guard"),
];

export const TALENTS: readonly Talent[] = [
  // 哥布林・掠奪
  t("g_raid", 0, 0, "sharp", "磨利的刀", "attack", 0.03),
  t("g_raid", 0, 2, "greed", "貪心", "loot", 0.08),
  t("g_raid", 1, 0, "warband", "大隊人馬", "party", 1),
  t("g_raid", 1, 2, "ambush", "埋伏", "lairAttack", 0.04),
  t("g_raid", 2, 0, "pillage", "洗劫", "pvpAttack", 0.05, 2, "warband"),
  t("g_raid", 2, 2, "hoard", "藏寶窟", "loot", 0.12, 2, "ambush"),
  t("g_raid", 3, 1, "warpaint", "戰紋", "hp", 0.04),
  t("g_raid", 4, 1, "plunder", "劫掠", "plunder", 1, 1, "warpaint"),
  // 哥布林・群聚
  t("g_horde", 0, 0, "breed", "多子多孫", "nest", 0.06),
  t("g_horde", 0, 2, "crowd", "擠一擠", "room", 2),
  t("g_horde", 1, 0, "callout", "一呼百應", "reinforce", 1),
  t("g_horde", 1, 2, "share", "分著吃", "upkeep", 0.12),
  t("g_horde", 2, 0, "swarm", "蜂擁", "party", 1, 2, "callout"),
  t("g_horde", 2, 2, "sprawl", "到處都是", "freeCells", 1, 2, "share"),
  t("g_horde", 3, 1, "warren", "地道", "regionTravel", 0.1),
  t("g_horde", 4, 1, "tunnels", "地道", "tunnels", 1, 1, "warren"),
  // 哥布林・工匠
  t("g_tinker", 0, 0, "patch", "縫縫補補", "wear", 0.08),
  t("g_tinker", 0, 2, "haggle", "討價還價", "market", 0.03),
  t("g_tinker", 1, 0, "scrap", "撿破爛", "yield", 0.05),
  t("g_tinker", 1, 2, "traps", "陷阱", "fort", 0.04),
  t("g_tinker", 2, 0, "rivets", "鉚釘甲", "hp", 0.04, 2, "scrap"),
  t("g_tinker", 2, 2, "spikes", "尖刺圍欄", "homeFort", 0.06, 2, "traps"),
  t("g_tinker", 3, 1, "blueprints", "設計圖", "xp", 0.06),
  t("g_tinker", 4, 1, "refine", "拼裝改造", "refine", 1, 1, "blueprints"),
  // 精靈・遊俠
  t("e_ranger", 0, 0, "swift", "輕盈", "travel", 0.04),
  t("e_ranger", 0, 2, "aim", "瞄準", "attack", 0.03),
  t("e_ranger", 1, 0, "paths", "林間小徑", "regionTravel", 0.1),
  t("e_ranger", 1, 2, "hunter", "獵手", "lairAttack", 0.05),
  t("e_ranger", 2, 0, "wind", "疾風", "travel", 0.05, 2, "paths"),
  t("e_ranger", 2, 2, "trophy", "戰利品", "loot", 0.1, 2, "hunter"),
  t("e_ranger", 3, 1, "volley", "齊射", "pvpAttack", 0.05),
  t("e_ranger", 4, 1, "ambush", "伏擊", "ambush", 1, 1, "volley"),
  // 精靈・森林
  t("e_grove", 0, 0, "bloom", "繁花", "yield", 0.05),
  t("e_grove", 0, 2, "bark", "樹皮", "hp", 0.03),
  t("e_grove", 1, 0, "cradle", "搖籃", "nest", 0.06),
  t("e_grove", 1, 2, "canopy", "樹冠", "room", 2),
  t("e_grove", 2, 0, "harvest", "豐收", "yield", 0.08, 2, "cradle"),
  t("e_grove", 2, 2, "thorns", "荊棘", "fort", 0.05, 2, "canopy"),
  t("e_grove", 3, 1, "roots", "根系", "reinforce", 1),
  t("e_grove", 4, 1, "sacred", "聖樹", "sacredTree", 1, 1, "roots"),
  // 精靈・長老
  t("e_elder", 0, 0, "lore", "博學", "xp", 0.05),
  t("e_elder", 0, 2, "trade", "通商", "market", 0.03),
  t("e_elder", 1, 0, "frugal", "簡樸", "upkeep", 0.12),
  t("e_elder", 1, 2, "ward", "結界", "homeFort", 0.05),
  t("e_elder", 2, 0, "stewards", "管家", "freeCells", 1, 2, "frugal"),
  t("e_elder", 2, 2, "mending", "修復術", "wear", 0.1, 2, "ward"),
  t("e_elder", 3, 1, "council", "議會", "party", 1),
  t("e_elder", 4, 1, "moongate", "月光傳送", "moonGate", 1, 1, "council"),
  // 死靈・亡軍
  t("u_legion", 0, 0, "rise", "起身", "nest", 0.06),
  t("u_legion", 0, 2, "bones", "硬骨", "hp", 0.03),
  t("u_legion", 1, 0, "march", "死亡行軍", "party", 1),
  t("u_legion", 1, 2, "graves", "亂葬崗", "room", 2),
  t("u_legion", 2, 0, "horde", "屍潮", "reinforce", 1, 2, "march"),
  t("u_legion", 2, 2, "tireless", "不知疲倦", "travel", 0.05, 2, "graves"),
  t("u_legion", 3, 1, "tide", "亡者之潮", "party", 1),
  t("u_legion", 4, 1, "raise", "戰場復甦", "raiseDead", 1, 1, "tide"),
  // 死靈・恐懼
  t("u_dread", 0, 0, "terror", "驚嚇", "pvpAttack", 0.04),
  t("u_dread", 0, 2, "shroud", "陰影", "fort", 0.04),
  t("u_dread", 1, 0, "siege", "攻城", "attack", 0.03),
  t("u_dread", 1, 2, "haunt", "鬧鬼", "homeFort", 0.05),
  t("u_dread", 2, 0, "despair", "絕望", "pvpAttack", 0.06, 2, "siege"),
  t("u_dread", 2, 2, "crypts", "地下墓穴", "fort", 0.06, 2, "haunt"),
  t("u_dread", 3, 1, "whispers", "低語", "intel", 1, 1),
  t("u_dread", 4, 1, "nightraid", "夜襲", "nightRaid", 1, 1, "whispers"),
  // 死靈・墓園
  t("u_crypt", 0, 0, "fasting", "不吃不喝", "upkeep", 0.12),
  t("u_crypt", 0, 2, "salvage", "拆屍取材", "loot", 0.08),
  t("u_crypt", 1, 0, "ossuary", "骨堂", "freeCells", 1),
  t("u_crypt", 1, 2, "embalm", "防腐", "wear", 0.08),
  t("u_crypt", 2, 0, "necropolis", "死城", "yield", 0.06, 2, "ossuary"),
  t("u_crypt", 2, 2, "reliquary", "聖物匣", "market", 0.04, 2, "embalm"),
  t("u_crypt", 3, 1, "tomes", "禁書", "xp", 0.06),
  t("u_crypt", 4, 1, "blight", "腐化大地", "blight", 1, 1, "tomes"),
  ...campTree("g_camp"),
  ...campTree("e_camp"),
  ...campTree("u_camp"),
];

const BY_ID = new Map(TALENTS.map((x) => [x.id, x]));
export const talentRule = (id: string) => BY_ID.get(id);
export const treesFor = (race: string) => TALENT_TREES.filter((x) => x.race === race);
export const talentsIn = (tree: string) => TALENTS.filter((x) => x.tree === tree);

/** The new things the big-world trees' top talents open (an effect of 1 when bought), and their numbers. */
export const TALENT_ABILITIES = {
  /** 劫掠: a won raid takes this share of each material the camp raided has (up to RAID_CAP of each), and leaves. */
  raidShare: 0.08,
  raidCap: 30,
  /** 伏擊: each of one's cells next to a party's way shoots this share of it down (at most AMBUSH_MAX in all). */
  ambushPerCell: 0.04,
  ambushMax: 0.25,
  /** 月光傳送: moves between one's towns this many times a day. */
  moonGatesPerDay: 1,
  /** 戰場復甦: this share of all who fell in a won fight rise as new residents of the camp (at most RAISE_MAX). */
  raiseShare: 0.2,
  raiseMax: 10,
  /** 夜襲: walking time at night. */
  nightTravel: 0.75,
  /** 腐化大地: others' cells next to one's own yield this share less; lairs next to one's own have this share less hit points. */
  blightYield: 0.25,
  blightLair: 0.2,
} as const;
/** Whether a camp's talents open an ability (a top talent). */
export const hasAbility = (bonus: Partial<Record<TalentEffect, number>> | null | undefined, effect: TalentEffect) => (bonus?.[effect] ?? 0) > 0;

/** Talent id → ranks bought. */
export type TalentPicks = Record<string, number>;

const spentIn = (picks: TalentPicks, tree: string, belowRow = Infinity) =>
  Object.entries(picks).reduce((n, [id, r]) => {
    const rule = BY_ID.get(id);
    return rule && rule.tree === tree && rule.row < belowRow ? n + r : n;
  }, 0);

/** Points spent in all, and in one tree. */
export const pointsSpent = (picks: TalentPicks) => Object.values(picks).reduce((n, r) => n + r, 0);
export const pointsIn = (picks: TalentPicks, tree: string) => spentIn(picks, tree);

/** Whether a talent's row is open: enough points in its tree above it, and the race level. */
export function rowOpen(picks: TalentPicks, tree: string, row: number, level: number): boolean {
  return level >= (TALENT_ROW_LEVELS[row] ?? Infinity) && spentIn(picks, tree, row) >= row * TALENT_ROW_POINTS;
}

/** Why one more rank of `id` cannot be bought now (null: it can). */
export function cannotLearn(race: string, level: number, picks: TalentPicks, id: string): string | null {
  const rule = BY_ID.get(id);
  if (!rule || !treesFor(race).some((x) => x.id === rule.tree)) return "沒有這個天賦。";
  if ((picks[id] ?? 0) >= rule.ranks) return "已經點滿了。";
  if (pointsSpent(picks) >= talentPoints(level)) return "沒有天賦點了（每升一級多一點）。";
  if (level < (TALENT_ROW_LEVELS[rule.row] ?? Infinity)) return `種族等級 ${TALENT_ROW_LEVELS[rule.row]} 才開放這一排。`;
  if (spentIn(picks, rule.tree, rule.row) < rule.row * TALENT_ROW_POINTS) return `這棵樹上面要先點 ${rule.row * TALENT_ROW_POINTS} 點。`;
  if (rule.requires && (picks[rule.requires] ?? 0) < (BY_ID.get(rule.requires)?.ranks ?? 0)) return `要先點滿「${BY_ID.get(rule.requires)?.name}」。`;
  return null;
}

/**
 * Whether `next` can follow `now` (nothing taken back: points stay until a reset), every rank bought in an order the rules
 * allow, within the points of `level`. Returns why not (null: fine).
 */
export function talentProblem(race: string, level: number, now: TalentPicks, next: TalentPicks): string | null {
  for (const [id, r] of Object.entries(now)) if ((next[id] ?? 0) < r) return "點過的天賦不能拿回來，要重置整棵樹。";
  // buy the new ranks one at a time, top rows first (a later row may rest on an earlier one)
  const buying = Object.entries(next)
    .flatMap(([id, r]) => Array.from({ length: Math.max(0, r - (now[id] ?? 0)) }, () => id))
    .sort((a, b) => (BY_ID.get(a)?.row ?? 0) - (BY_ID.get(b)?.row ?? 0));
  const picks = { ...now };
  for (const id of buying) {
    const why = cannotLearn(race, level, picks, id);
    if (why) return `${BY_ID.get(id)?.name ?? id}：${why}`;
    picks[id] = (picks[id] ?? 0) + 1;
  }
  return null;
}

/** All talents bought, added up by effect (missing: 0). */
export function talentBonus(picks: TalentPicks | null | undefined): Record<TalentEffect, number> {
  const out = {} as Record<TalentEffect, number>;
  for (const [id, r] of Object.entries(picks ?? {})) {
    const rule = BY_ID.get(id);
    if (rule) out[rule.effect] = (out[rule.effect] ?? 0) + rule.per * Math.min(r, rule.ranks);
  }
  return out;
}

/** What talents add to a party's fight: against other camps, or against lairs and great monsters. */
export function talentFight(bonus: Partial<Record<TalentEffect, number>>, against: "player" | "lair"): { power: number; vigor: number } {
  return { power: (bonus.attack ?? 0) + ((against === "player" ? bonus.pvpAttack : bonus.lairAttack) ?? 0), vigor: bonus.hp ?? 0 };
}

/** A talent's effect in words, at `ranks` (whole numbers for counts, percentages for shares). */
export function talentText(rule: Talent, ranks = 1): string {
  const v = rule.per * ranks;
  const pct = `${Math.round(v * 100)}%`;
  switch (rule.effect) {
    case "travel": return `出征走路時間 −${pct}`;
    case "regionTravel": return `在自己相連的格子之間調人，再快 ${pct}`;
    case "attack": return `出征攻擊 +${pct}`;
    case "pvpAttack": return `打其他玩家時攻擊再 +${pct}`;
    case "lairAttack": return `打巢穴和世界魔王時攻擊再 +${pct}`;
    case "hp": return `出征的居民血量 +${pct}`;
    case "fort": return `守領地的居民血量 +${pct}`;
    case "homeFort": return `守主營的居民血量 +${pct}`;
    case "yield": return `領地產出 +${pct}`;
    case "nest": return `領地的巢穴生得快 ${pct}`;
    case "room": return `每塊領地多住 ${v} 隻`;
    case "party": return `出征可以多帶 ${v} 隻`;
    case "reinforce": return `旁邊每塊領地多派 ${v} 隻來幫忙守`;
    case "upkeep": return `維持成本 −${pct}`;
    case "freeCells": return `免維持成本的領地 +${v} 塊`;
    case "wear": return `裝備磨損 −${pct}`;
    case "market": return `城鎮市場換到的多 ${pct}`;
    case "loot": return `打贏巢穴的掉落 +${pct}`;
    case "xp": return `種族經驗 +${pct}`;
    case "intel": return "看得到來襲敵軍的隊伍組成";
    case "plunder": return `新出征方式「劫掠」：打其他玩家的領地，贏了搶走對方倉庫每種素材的 ${Math.round(TALENT_ABILITIES.raidShare * 100)}%（每種最多 ${TALENT_ABILITIES.raidCap}）就走，不佔地`;
    case "tunnels": return "地道：自己所有的領地都算相連（調人只要四分之一時間），隊伍可以從別人的城牆底下鑽過去";
    case "refine": return "工坊多「改造」：把裝備改成 ★ 精良版（更強、更耐用）；壞掉的裝備完整拆回材料";
    case "ambush": return `伏擊：敵人的隊伍經過你領地旁邊，每塊相鄰的領地先射倒 ${Math.round(TALENT_ABILITIES.ambushPerCell * 100)}%（最多 ${Math.round(TALENT_ABILITIES.ambushMax * 100)}%）`;
    case "sacredTree": return "可以在公園、森林的領地種「聖樹」：同一區的領地產出、守軍血量增加，聖樹那格生得快";
    case "moonGate": return `月光傳送：每天 ${TALENT_ABILITIES.moonGatesPerDay} 次，在自己的城鎮之間搬人瞬間到`;
    case "raiseDead": return `戰場復甦：打贏之後，倒下的（雙方）有 ${Math.round(TALENT_ABILITIES.raiseShare * 100)}% 爬起來加入營地（最多 ${TALENT_ABILITIES.raiseMax} 隻）`;
    case "nightRaid": return "夜襲：晚上出發的隊伍走路時間 −25%，而且對方不會收到敵軍來襲預警";
    case "blight": return `腐化大地：你領地旁邊別人的領地產出 −${Math.round(TALENT_ABILITIES.blightYield * 100)}%；打你領地旁邊的巢穴，牠們血量 −${Math.round(TALENT_ABILITIES.blightLair * 100)}%`;
    case "campYield": return `營地場地產出 +${pct}`;
    case "campBirths": return `營地生得快 ${pct}`;
    case "campGuard": return `魔獸來襲時居民攻擊 +${pct}`;
    case "campRanch": return `牧場產出 +${pct}`;
    case "campBuild": return `蓋場地的時間 −${pct}`;
    case "campLife": return `居民壽命 +${pct}`;
    case "campHost": return `想搬進來的訪客開價 −${pct}`;
    case "campTrade": return `營地商人多帶 ${v} 樣貨`;
    case "campHeart": return `魔獸來襲和等級魔王的掉落 +${pct}`;
  }
}
