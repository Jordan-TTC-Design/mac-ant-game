/**
 * Decorating the guild hall (GUILD.md §4.2): every member may put down any decoration the guild has unlocked (by its level,
 * and a race's set by having a member of that race), as many of a kind as they like, as long as the room lasts. The leader
 * and officers may lock a piece so only they can move it; every change is logged, and the leader can go back to before one.
 */
import { z } from "zod";
import { GUILD_DECOR, type GuildDecorKind } from "./guild-decor-catalog.ts";
import { guildLevel, type GuildRole } from "./guild.ts";
import { WALL_ROWS } from "./guild-hall.ts";

export { GUILD_DECOR, type GuildDecorKind };

/** However much room there is, no more than this many pieces (the hall has to draw them). */
export const GUILD_DECOR_MAX_ITEMS = 300;
/** Changes kept in the log (and how far back the leader can go). */
export const GUILD_DECOR_LOG_DAYS = 7;
/** Positions are kept to a sixteenth of a tile (one pixel of the art). */
export const GUILD_DECOR_STEP = 1 / 16;

/** The categories, in the order the catalog's tabs show them. */
export const GUILD_DECOR_CATEGORIES = ["辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"] as const;

const BY_ID = new Map(GUILD_DECOR.map((k) => [k.id, k]));
export function guildDecorKind(id: string): GuildDecorKind | undefined {
  return BY_ID.get(id);
}

/** One piece put down: an id of its own (so it can be moved and locked), which kind, where its feet are (tiles), turned, locked. */
export const guildDecorPlacedSchema = z.object({
  uid: z.string().regex(/^[A-Za-z0-9_-]{4,24}$/),
  kind: z.string().max(40),
  x: z.number().finite(),
  y: z.number().finite(),
  flip: z.boolean().optional(),
  locked: z.boolean().optional(),
});
export type GuildDecorPlaced = z.infer<typeof guildDecorPlacedSchema>;

export const guildDecorInput = z.object({
  /** The version this list was made from (someone else saved in between: refused, fetch and try again). */
  version: z.number().int().min(0),
  items: z.array(guildDecorPlacedSchema).max(GUILD_DECOR_MAX_ITEMS),
});
export const guildDecorRestoreInput = z.object({ logId: z.uuid() });

export function guildDecorRoomUsed(items: readonly GuildDecorPlaced[]): number {
  return items.reduce((sum, d) => sum + (BY_ID.get(d.kind)?.size ?? 0), 0);
}

/** Whether the guild may use this kind: its level is reached, and a race's piece needs a member of that race. */
export function guildDecorUnlocked(kind: GuildDecorKind, level: number, races: ReadonlySet<string>): boolean {
  return kind.level <= level && (!kind.race || races.has(kind.race));
}

/** Rounds a position to the art's pixels. */
export const snapDecor = (v: number) => Math.round(v / GUILD_DECOR_STEP) * GUILD_DECOR_STEP;

/** Why this list cannot be the hall's (null: it can). A piece already there stays even if its race left (it just can't be added again). */
export function guildDecorProblem(items: readonly GuildDecorPlaced[], level: number, races: ReadonlySet<string>, before: readonly GuildDecorPlaced[] = []): string | null {
  if (items.length > GUILD_DECOR_MAX_ITEMS) return `最多放 ${GUILD_DECOR_MAX_ITEMS} 件。`;
  const { width, height, room } = guildLevel(level);
  const had = new Map(before.map((d) => [d.uid, d.kind]));
  const uids = new Set<string>();
  for (const d of items) {
    if (uids.has(d.uid)) return "同一件裝飾出現兩次。";
    uids.add(d.uid);
    const kind = BY_ID.get(d.kind);
    if (!kind) return "沒有這種裝飾。";
    if (had.get(d.uid) !== d.kind && !guildDecorUnlocked(kind, level, races)) {
      return kind.level > level ? `${kind.name}要公會 ${kind.level} 級才能用。` : `${kind.name}要公會裡有這個種族的成員才能用。`;
    }
    const half = kind.w / 32;
    if (d.x - half < 0 || d.x + half > width) return `${kind.name}超出據點了。`;
    if (kind.wall ? d.y < 1 || d.y > WALL_ROWS + 0.01 : d.y <= WALL_ROWS || d.y > height) return kind.wall ? `${kind.name}要掛在牆上。` : `${kind.name}要放在地板上。`;
  }
  const used = guildDecorRoomUsed(items);
  if (used > room) return `裝飾點數不夠（${used}／${room}），公會升級後會有更多。`;
  return null;
}

export interface GuildDecorChange {
  added: number;
  moved: number;
  removed: number;
}

/** What changed from `before` to `after`; or why this member may not make that change (a locked piece, or locking at all). */
export function guildDecorChange(before: readonly GuildDecorPlaced[], after: readonly GuildDecorPlaced[], role: GuildRole): GuildDecorChange | string {
  const was = new Map(before.map((d) => [d.uid, d]));
  const now = new Map(after.map((d) => [d.uid, d]));
  const boss = role !== "member";
  const change: GuildDecorChange = { added: 0, moved: 0, removed: 0 };
  for (const d of after) {
    const old = was.get(d.uid);
    if (!old) {
      if (d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
      change.added++;
      continue;
    }
    const same = old.kind === d.kind && old.x === d.x && old.y === d.y && !!old.flip === !!d.flip;
    if (!!old.locked !== !!d.locked && !boss) return "只有會長和幹部可以鎖定裝飾。";
    if (!same && old.locked && !boss) return `${guildDecorKind(old.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能動。`;
    if (!same || !!old.locked !== !!d.locked) change.moved++; // (locking or unlocking counts as a change too)
  }
  for (const d of before) {
    if (now.has(d.uid)) continue;
    if (d.locked && !boss) return `${guildDecorKind(d.kind)?.name ?? "這件裝飾"}被鎖住了，只有會長和幹部能收掉。`;
    change.removed++;
  }
  return change;
}

/** A new piece's own id. */
export function newDecorUid(): string {
  const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let s = "";
  for (let i = 0; i < 10; i++) s += abc[Math.floor(Math.random() * abc.length)];
  return s;
}

/** One line of the log. */
export interface GuildDecorLogEntry {
  id: string;
  by: string;
  at: string;
  added: number;
  moved: number;
  removed: number;
  /** A going-back by the leader (to the list before entry `restored`). */
  restored: boolean;
}
