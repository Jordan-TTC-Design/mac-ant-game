import { Hono } from "hono";
import { and, desc, eq, gt, isNull, lt, or } from "drizzle-orm";
import { claudeAnswerInput, claudeAskInput, type ClaudeAsk, type ClaudePush, type ClaudeResponse } from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth } from "../auth/session.ts";
import { apiError, readJson } from "../http.ts";
import { pushToPhones } from "../push/phones.ts";
import { claudeAsks } from "../db/schema.ts";

type Row = typeof claudeAsks.$inferSelect;
const view = (r: Row): ClaudeAsk => ({
  id: r.id,
  kind: r.kind,
  project: r.project,
  text: r.text,
  device: r.deviceId,
  at: r.at.toISOString(),
  until: r.until?.toISOString() ?? null,
  answer: r.answer ?? null,
});

/**
 * Claude Code's questions answered from the phone (server/DESIGN.md §15). A Mac sends a question while its person is away;
 * the phones get a push; the first answer goes back to that Mac over the WebSocket. "Allow" from here is for this once only.
 */
export function claudeRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  app.get("/", async (c) => {
    const userId = c.get("session").user.id;
    const at = now();
    const rows = await db
      .select()
      .from(claudeAsks)
      .where(and(eq(claudeAsks.userId, userId), gt(claudeAsks.at, new Date(at.getTime() - 86_400_000))))
      .orderBy(desc(claudeAsks.at))
      .limit(30);
    const waiting = rows.filter((r) => r.kind !== "done" && !r.answer && r.until && r.until > at);
    const body: ClaudeResponse = { waiting: waiting.map(view), recent: rows.filter((r) => !waiting.includes(r)).slice(0, 10).map(view) };
    return c.json(body);
  });

  /** One question (a Mac that missed the WebSocket looks its answer up here). */
  app.get("/:id", async (c) => {
    const [row] = await db.select().from(claudeAsks).where(and(eq(claudeAsks.userId, c.get("session").user.id), eq(claudeAsks.id, c.req.param("id"))));
    return row ? c.json(view(row)) : apiError(c, 404, "not_found", "沒有這個問題。");
  });

  /** From a Mac: a question to pass on (or news that Claude finished). */
  app.post("/", async (c) => {
    const session = c.get("session");
    if (session.viaCookie || !session.deviceId) return apiError(c, 403, "forbidden", "只有 Mac 能送 Claude 的問題過來。");
    const body = await readJson(c, claudeAskInput);
    if ("response" in body) return body.response;
    const ask = body.data;
    const at = now();
    const until = ask.kind === "done" ? null : new Date(at.getTime() + (ask.waitSeconds ?? 60) * 1000);
    await db
      .insert(claudeAsks)
      .values({ userId: session.user.id, id: ask.id, deviceId: session.deviceId, kind: ask.kind, project: ask.project, text: ask.text, at, until })
      .onConflictDoNothing();
    deps.hub.notify(session.user.id, { type: "claude.changed" });
    const where = ask.project ? `「${ask.project}」` : "";
    const push: ClaudePush =
      ask.kind === "permission"
        ? { type: "claude", title: `Claude 在等你允許${where}`, body: ask.text || "要做一件事，要你點頭", url: "/claude", tag: `claude-${ask.id}`, ask: { id: ask.id, kind: "permission" } }
        : ask.kind === "reply"
          ? { type: "claude", title: `Claude 停下來了${where}`, body: ask.text || "要不要跟它說什麼？", url: "/claude", tag: `claude-${ask.id}` }
          : { type: "claude", title: `Claude 做完了${where}`, body: ask.text || "回電腦看看吧", url: "/claude", tag: `claude-${ask.id}` };
    await pushToPhones(deps, session.user.id, push);
    return c.json(view((await db.select().from(claudeAsks).where(and(eq(claudeAsks.userId, session.user.id), eq(claudeAsks.id, ask.id))))[0]!), 201);
  });

  /** An answer: from a phone (goes to the waiting Mac), or from the Mac itself (answered there, or it stopped waiting). */
  app.post("/:id/answer", async (c) => {
    const session = c.get("session");
    const body = await readJson(c, claudeAnswerInput);
    if ("response" in body) return body.response;
    const id = c.req.param("id");
    const at = now();
    const by = session.viaCookie ? "phone" : "mac";
    if (by === "phone" && body.data.action === "reply" && !body.data.text) return apiError(c, 400, "invalid_input", "回覆要寫點字。");
    const answer = { action: body.data.action, ...(body.data.text ? { text: body.data.text } : {}), by, at: at.toISOString() } as const;
    // only the first answer counts, and only while the Mac still waits (the Mac itself may always close it)
    const [row] = await db
      .update(claudeAsks)
      .set({ answer })
      .where(
        and(
          eq(claudeAsks.userId, session.user.id),
          eq(claudeAsks.id, id),
          isNull(claudeAsks.answer),
          or(eq(claudeAsks.kind, "permission"), eq(claudeAsks.kind, "reply")),
          by === "phone" ? gt(claudeAsks.until, at) : undefined,
        ),
      )
      .returning();
    if (!row) return apiError(c, 409, "conflict", "這個問題已經回答過、或電腦已經不等了。");
    if (by === "phone") deps.hub.notify(session.user.id, { type: "claude.answer", id, device: row.deviceId, action: answer.action, ...(answer.text ? { text: answer.text } : {}) });
    deps.hub.notify(session.user.id, { type: "claude.changed" });
    return c.json(view(row));
  });

  return app;
}

/** Questions and news older than a day go (they say what someone's code does). */
export async function clearClaude(deps: Pick<AppDeps, "database">, now: Date): Promise<number> {
  const rows = await deps.database.db
    .delete(claudeAsks)
    .where(lt(claudeAsks.at, new Date(now.getTime() - 86_400_000)))
    .returning({ id: claudeAsks.id });
  return rows.length;
}
