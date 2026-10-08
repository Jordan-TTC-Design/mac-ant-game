import { eq } from "drizzle-orm";
import { guildClientMessage, GUILD_MOVE_MS } from "@goblincamp/shared";
import type { AppDeps } from "../app.ts";
import { guildMembers } from "../db/schema.ts";

/** Whom to pass a member's moves to: their guild's members, looked up at most this often. */
const CACHE_MS = 30_000;

/**
 * What pages send up the WebSocket about the guild hall (GUILD.md §3.1): someone walking their avatar by hand. Nothing is
 * kept: each move is passed straight on to the other members (a page that opens later sees them at the next heartbeat).
 */
export function guildLive(deps: AppDeps) {
  const now = deps.now ?? (() => new Date());
  const guildOf = new Map<string, { members: string[]; at: number }>();
  const lastMove = new Map<string, number>();

  async function members(userId: string): Promise<string[]> {
    const t = now().getTime();
    const hit = guildOf.get(userId);
    if (hit && t - hit.at < CACHE_MS) return hit.members;
    const [mine] = await deps.database.db.select({ guildId: guildMembers.guildId }).from(guildMembers).where(eq(guildMembers.userId, userId));
    const list = mine ? (await deps.database.db.select({ id: guildMembers.userId }).from(guildMembers).where(eq(guildMembers.guildId, mine.guildId))).map((r) => r.id) : [];
    guildOf.set(userId, { members: list, at: t });
    return list;
  }

  return {
    /** A message from `userId`'s page; anything not understood is dropped. */
    async receive(userId: string, raw: string) {
      let parsed;
      try {
        parsed = guildClientMessage.safeParse(JSON.parse(raw));
      } catch {
        return;
      }
      if (!parsed.success) return;
      const msg = parsed.data;
      if (msg.type === "guild.move") {
        // (faster than a page should send: dropped)
        const t = now().getTime();
        if (t - (lastMove.get(userId) ?? 0) < GUILD_MOVE_MS / 2) return;
        lastMove.set(userId, t);
      }
      const others = (await members(userId)).filter((id) => id !== userId);
      const event = msg.type === "guild.move" ? { ...msg, userId } : { type: "guild.release" as const, userId };
      for (const id of others) deps.hub.notify(id, event);
    },
    /** Forget who is in which guild (someone joined or left). */
    forget() {
      guildOf.clear();
    },
  };
}
