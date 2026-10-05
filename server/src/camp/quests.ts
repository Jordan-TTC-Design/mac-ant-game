import { and, eq, isNotNull, isNull, or, sql } from "drizzle-orm";
import { CAMP_MONSTERS, MIDDLE_GEAR, QUESTS, questShown, raceRules, type QuestMetrics, type QuestView } from "@goblincamp/shared/camp";
import { CELL_BUILDING_MAX, connectedCells, ITEMS, LAIRS, raceLevel } from "@goblincamp/shared/world";
import type { Tx } from "../auth/session.ts";
import { campResidents, expeditions, friendships, worldCells, worldPlayers } from "../db/schema.ts";
import { landmarksFor } from "../world/osm.ts";
import type { CampRow } from "./service.ts";

const BOSSES = new Set(LAIRS.filter((l) => l.boss && l.leader).map((l) => l.leader!));
const RAIDERS = new Set(CAMP_MONSTERS.map((m) => m.id));

/** Everything the quests look at (camp/quests.ts), from the camp as it is now. */
export async function questMetrics(tx: Tx, camp: CampRow): Promise<QuestMetrics> {
  const userId = camp.userId;
  const home = await tx.select({ gear: campResidents.gear }).from(campResidents).where(and(eq(campResidents.userId, userId), eq(campResidents.place, "home"), isNull(campResidents.diedAt)));
  const worn = home.map((r) => Object.values(r.gear ?? {}).filter(Boolean));
  const owned = [...worn.flat().map((g) => g!.id), ...camp.armory.map((g) => g.id)];
  const sites = camp.sites.filter((s) => s.kind !== "farm");
  const siteLevels: Record<string, number> = {};
  for (const s of sites) siteLevels[s.kind] = Math.max(siteLevels[s.kind] ?? 0, s.level);

  const [player] = await tx.select({ xp: worldPlayers.xp, home: worldPlayers.homeCell }).from(worldPlayers).where(eq(worldPlayers.userId, userId));
  const held = await tx.select({ cell: worldCells.cell, nest: worldCells.nestStartedAt, building: worldCells.building, town: worldCells.town }).from(worldCells).where(eq(worldCells.owner, userId));
  const cells = new Set(held.map((c) => c.cell));
  const landmarks = await landmarksFor(tx, [...cells]);
  const [{ won }] = (await tx
    .select({ won: sql<number>`count(*)::int` })
    .from(expeditions)
    .where(and(eq(expeditions.userId, userId), eq(expeditions.status, "done"), sql`${expeditions.result} -> 'lair' is not null and (${expeditions.result} -> 'outcome' ->> 'won')::boolean`))) as [{ won: number }];
  // (other camps' cells won: a fight with a defender that went this camp's way)
  const [{ pvp }] = (await tx
    .select({ pvp: sql<number>`count(*)::int` })
    .from(expeditions)
    .where(and(eq(expeditions.userId, userId), eq(expeditions.status, "done"), isNotNull(expeditions.defender), sql`(${expeditions.result} -> 'outcome' ->> 'won')::boolean`))) as [{ pvp: number }];
  // (everybody alive: at home, on held cells, camping, guarding, on the road)
  const [{ alive }] = (await tx
    .select({ alive: sql<number>`count(*)::int` })
    .from(campResidents)
    .where(and(eq(campResidents.userId, userId), isNull(campResidents.diedAt)))) as [{ alive: number }];
  const [{ friends }] = (await tx
    .select({ friends: sql<number>`count(*)::int` })
    .from(friendships)
    .where(and(or(eq(friendships.userA, userId), eq(friendships.userB, userId)), isNotNull(friendships.acceptedAt)))) as [{ friends: number }];
  const [guard] = await tx
    .select({ id: campResidents.id })
    .from(campResidents)
    .where(and(eq(campResidents.userId, userId), sql`${campResidents.place} like 'guard:%'`, isNull(campResidents.diedAt)))
    .limit(1);
  const kills = camp.kills ?? {};
  const sum = (ids: Set<string>) => Object.entries(kills).reduce((total, [id, k]) => total + (ids.has(id) ? k : 0), 0);
  return {
    peak: camp.peak,
    sites: sites.filter((s) => s.level >= 1).length,
    siteLevels,
    farm: camp.sites.find((s) => s.kind === "farm")?.level ?? 0,
    armed: home.filter((r) => !!r.gear?.weapon).length,
    wellGeared: worn.filter((pieces) => pieces.length >= 3).length,
    gearOwned: owned.length,
    middleGear: owned.some((id) => MIDDLE_GEAR.includes(id)),
    kills,
    raidKills: sum(RAIDERS),
    bossKills: sum(BOSSES),
    worldOpen: !!player,
    lairsWon: won,
    cells: cells.size,
    nests: held.filter((c) => c.nest && c.cell !== player?.home).length,
    buildings: held.filter((c) => c.building).length,
    landmarks: [...cells].filter((c) => landmarks.get(c)).length,
    region: Math.max(0, ...[...cells].map((c) => connectedCells(c, cells).length)),
    raceLevel: raceLevel(player?.xp ?? 0),
    friends,
    guarding: !!guard,
    sitesTop: sites.filter((s) => s.level >= 3).length,
    population: alive,
    homeCap: raceRules(camp.race).homeCap,
    towns: held.filter((c) => c.town).length,
    buildingsTop: held.filter((c) => (c.building?.level ?? 0) >= CELL_BUILDING_MAX).length,
    pvpWins: pvp,
    bossKinds: [...BOSSES].filter((id) => (kills[id] ?? 0) > 0).length,
    middleGearKinds: new Set(owned.filter((id) => MIDDLE_GEAR.includes(id))).size,
    focusRounds: camp.focus?.rounds ?? 0,
    focusBestDay: camp.focus?.bestDay ?? 0,
    ranchAnimals: camp.ranch?.animals.length ?? 0,
  };
}

/** The quests to show: every chain's first, and the next of each once the one before was claimed. */
export async function questList(tx: Tx, camp: CampRow): Promise<QuestView[]> {
  const m = await questMetrics(tx, camp);
  const claimed = camp.quests ?? {};
  return QUESTS.filter((q) => questShown(q, claimed)).map((q) => {
    const [have, need] = q.goal(m);
    const unlocks = ITEMS.find((i) => i.unlock === q.id)?.id;
    return { id: q.id, chapter: q.chapter, title: q.title, text: q.text, have, need, done: have >= need, claimed: q.id in claimed, reward: q.reward, ...(unlocks ? { unlocks } : {}) };
  });
}
