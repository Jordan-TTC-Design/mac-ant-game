/**
 * The economy dashboard's numbers (admin; shared/src/camp/economy.ts EconomyReport): what the camps hold now, the material
 * flows of the last days (the "flow" camp events: flows.ts), raids and level bosses, the merchants, visitors, and the
 * guilds' contribution. Read straight from the tables; fine for the few hundred camps there are.
 */
import { and, eq, gte, inArray, sql } from "drizzle-orm";
import { campStage, flowSourceName, taipeiDay, type EconomyReport } from "@goblincamp/shared/camp";
import { materialName, raceLevel } from "@goblincamp/shared/world";
import type { Database } from "../db/client.ts";
import { avatars, campEvents, camps, guildDonations, guilds, users, worldPlayers } from "../db/schema.ts";

const DAY = 86_400_000;
const TOP = 6;

const sum = (m: Record<string, number>) => Object.values(m).reduce((n, v) => n + v, 0);
const add = (m: Record<string, number>, id: string, n: number) => (m[id] = (m[id] ?? 0) + n);
function quantile(sorted: number[], q: number): number {
  if (!sorted.length) return 0;
  return sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))]!;
}

export async function economyReport(db: Database["db"], now: Date, days: number): Promise<EconomyReport> {
  const since = new Date(now.getTime() - days * DAY);
  const campRows = await db
    .select({ userId: camps.userId, race: camps.race, peak: camps.peak, materials: camps.materials, advancedTo: camps.advancedTo, name: users.displayName, xp: worldPlayers.xp })
    .from(camps)
    .innerJoin(users, eq(users.id, camps.userId))
    .leftJoin(worldPlayers, eq(worldPlayers.userId, camps.userId));

  // ── players
  const byRace: Record<string, number> = {}, byLevel: Record<string, number> = {}, byStage: Record<string, number> = {};
  for (const c of campRows) {
    add(byRace, c.race, 1);
    add(byLevel, String(raceLevel(c.xp ?? 0)), 1);
    add(byStage, String(campStage(c.race, c.peak)), 1);
  }

  // ── stock now
  const held = new Map<string, number[]>();
  for (const c of campRows) for (const [id, n] of Object.entries(c.materials)) if (n > 0) (held.get(id) ?? held.set(id, []).get(id)!).push(n);

  // ── the window's events: flows, raids, commands
  const events = await db
    .select({ userId: campEvents.userId, at: campEvents.at, kind: campEvents.kind, data: campEvents.data })
    .from(campEvents)
    .where(and(gte(campEvents.at, since), inArray(campEvents.kind, ["flow", "raid", "command"])));
  const active = new Set<string>();
  const flowIn: Record<string, Record<string, number>> = {}, flowOut: Record<string, Record<string, number>> = {};
  const matIn: Record<string, number> = {}, matOut: Record<string, number> = {};
  const daily: Record<string, { in: number; out: number }> = {};
  const raids = { count: 0, won: 0, fallen: 0, variants: {} as Record<string, number>, bosses: new Map<number, { came: number; beaten: number }>() };
  const merchant = { visits: 0, trades: 0 };
  const visitors = { accepted: 0, declined: 0, dismissed: 0, specials: 0 };
  for (const e of events) {
    active.add(e.userId);
    const d = e.data as Record<string, any>;
    if (e.kind === "flow") {
      const day = daily[taipeiDay(e.at)] ??= { in: 0, out: 0 };
      for (const [id, n] of Object.entries(d.delta as Record<string, number>)) {
        if (n > 0) {
          add((flowIn[d.source] ??= {}), id, n);
          add(matIn, id, n);
          day.in += n;
        } else {
          add((flowOut[d.source] ??= {}), id, -n);
          add(matOut, id, -n);
          day.out -= n;
        }
      }
    } else if (e.kind === "raid") {
      raids.count++;
      if (d.winner === "camp") raids.won++;
      raids.fallen += (d.fallen ?? []).length;
      for (const m of d.monsters ?? []) add(raids.variants, m.variant ?? "plain", m.count);
      if (d.boss) {
        const b = raids.bosses.get(d.boss) ?? { came: 0, beaten: 0 };
        b.came++;
        if (d.bossBeaten) b.beaten++;
        raids.bosses.set(d.boss, b);
      }
    } else {
      const kind = d.command?.kind;
      if (kind === "merchant-arrive" && d.visit) merchant.visits++;
      else if (kind === "merchant-trade") merchant.trades++;
      else if (kind === "visitor-accept" && d.answer === "yes") {
        visitors.accepted++;
        if (["healer", "champion", "artisan", "beastmaster", "bard", "sentinel"].includes(d.visitor)) visitors.specials++;
      } else if (kind === "visitor-decline") visitors.declined++;
      else if (kind === "resident-dismiss") visitors.dismissed++;
    }
  }

  const ids = new Set([...held.keys(), ...Object.keys(matIn), ...Object.keys(matOut)]);
  const materials = [...ids]
    .map((id) => {
      const list = (held.get(id) ?? []).sort((a, b) => a - b);
      return { id, name: materialName(id), total: sum(Object.fromEntries(list.map((n, i) => [i, n]))), holders: list.length, median: quantile(list, 0.5), p90: quantile(list, 0.9), in: matIn[id] ?? 0, out: matOut[id] ?? 0 };
    })
    .sort((a, b) => b.total + b.in - (a.total + a.in));

  const sources = new Set([...Object.keys(flowIn), ...Object.keys(flowOut)]);
  const flows = [...sources]
    .map((source) => {
      const net: Record<string, number> = {};
      for (const [id, n] of Object.entries(flowIn[source] ?? {})) add(net, id, n);
      for (const [id, n] of Object.entries(flowOut[source] ?? {})) add(net, id, -n);
      const top = Object.entries(net).sort((a, b) => Math.abs(b[1]) - Math.abs(a[1])).slice(0, TOP).map(([id, n]) => ({ id, name: materialName(id), net: n }));
      return { source, name: flowSourceName(source), in: sum(flowIn[source] ?? {}), out: sum(flowOut[source] ?? {}), top };
    })
    .sort((a, b) => b.in + b.out - (a.in + a.out));

  // ── guilds and contribution
  const [given] = await db.select({ all: sql<number>`coalesce(sum(${guildDonations.points}), 0)::int`, window: sql<number>`coalesce(sum(${guildDonations.points}) filter (where ${guildDonations.at} >= ${since.toISOString()}::timestamptz), 0)::int` }).from(guildDonations);
  const [spent] = await db.select({ all: sql<number>`coalesce(sum(${avatars.spent}), 0)::int` }).from(avatars);
  const guildRows = await db.select({ level: guilds.level, unlocked: guilds.unlocked }).from(guilds);
  const guildLevels: Record<string, number> = {};
  for (const g of guildRows) add(guildLevels, String(g.level), 1);

  return {
    days,
    at: now.toISOString(),
    players: { camps: campRows.length, active: active.size, byRace, byLevel, byStage },
    materials,
    flows,
    daily: Object.entries(daily).sort(([a], [b]) => a.localeCompare(b)).map(([day, v]) => ({ day, ...v })),
    richest: campRows
      .map((c) => ({ name: c.name, race: c.race, level: raceLevel(c.xp ?? 0), total: sum(c.materials) }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 10),
    raids: { count: raids.count, won: raids.won, fallen: raids.fallen, variants: raids.variants, bosses: [...raids.bosses].sort(([a], [b]) => a - b).map(([level, v]) => ({ level, ...v })) },
    merchant: { ...merchant, guildBuys: guildRows.reduce((n, g) => n + g.unlocked.length, 0) },
    visitors,
    contribution: { givenWindow: given!.window, givenAll: given!.all, spentAll: spent!.all, left: given!.all - spent!.all, guilds: guildRows.length, guildLevels },
  };
}
