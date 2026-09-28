import { Hono } from "hono";
import { and, asc, count, eq, gt, sql } from "drizzle-orm";
import {
  MAX_NOTES_PER_USER,
  noteFieldsSchema,
  pushInput,
  type ChangesResponse,
  type Note,
  type NoteChange,
  type NoteField,
  type NoteFields,
  type PushResult,
} from "@goblincamp/shared";
import type { AppDeps, AppEnv } from "../app.ts";
import { requireAuth, type Tx } from "../auth/session.ts";
import { notes } from "../db/schema.ts";
import { apiError, readJson } from "../http.ts";

type Row = typeof notes.$inferSelect;
const PAGE = 500;
const FIELDS = Object.keys(noteFieldsSchema.shape) as NoteField[];
const DATE_FIELDS = new Set<NoteField>(["dueAt", "remindAt"]);

export function toNote(row: Row): Note {
  return {
    id: row.id,
    text: row.text,
    color: row.color as Note["color"],
    breed: row.breed,
    goblinName: row.goblinName,
    dueAt: row.dueAt?.toISOString() ?? null,
    remindAt: row.remindAt?.toISOString() ?? null,
    remindFired: row.remindFired,
    done: row.done,
    deleted: row.deleted,
    kind: row.kind as Note["kind"],
    desk: row.desk,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
    seq: row.seq,
  };
}

/** A field as the database column wants it (dates as Date). */
function column(field: NoteField, value: unknown): unknown {
  return DATE_FIELDS.has(field) ? (value === null ? null : new Date(value as string)) : value;
}

/** Whether a field sent by a device is what the server has already. */
function same(field: NoteField, row: Row, value: unknown): boolean {
  const current = row[field as keyof Row];
  if (DATE_FIELDS.has(field)) return ((current as Date | null)?.getTime() ?? null) === (value === null ? null : new Date(value as string).getTime());
  return current === value;
}

async function nextSeq(tx: Tx): Promise<number> {
  const rows = await tx.execute<{ seq: string }>(sql`select nextval('note_seq') as seq`);
  return Number(rows[0]!.seq);
}

/**
 * Takes one change from a device. The rules (DESIGN.md §5):
 * nobody else changed the note since the device saw it → take it; someone changed other fields → keep both;
 * both changed the words → the server's words stay and the device's become a copy; a delete loses to a change made elsewhere.
 */
async function applyChange(tx: Tx, userId: string, change: NoteChange, at: Date): Promise<PushResult> {
  const [row] = await tx.select().from(notes).where(eq(notes.id, change.id)).for("update");

  if (!row) {
    const full = noteFieldsSchema.safeParse(change.fields);
    if (!full.success) return { id: change.id, status: "rejected", reason: change.baseSeq > 0 ? "not_found" : "incomplete" };
    const [{ n } = { n: 0 }] = await tx.select({ n: count() }).from(notes).where(eq(notes.userId, userId));
    if (n >= MAX_NOTES_PER_USER) return { id: change.id, status: "rejected", reason: "limit" };
    return { id: change.id, status: "applied", note: toNote(await insertNote(tx, userId, change.id, full.data, change.createdAt ? new Date(change.createdAt) : at, at)) };
  }
  if (row.userId !== userId) return { id: change.id, status: "rejected", reason: "id_taken" };

  // only what really differs from the server counts
  const incoming = Object.entries(change.fields).filter(([f, v]) => v !== undefined && !same(f as NoteField, row, v)) as [NoteField, unknown][];
  if (incoming.length === 0) return { id: change.id, status: "applied", note: toNote(row) };

  const fields = new Map(incoming);
  const changedElsewhere = (f: NoteField) => (row.fieldSeqs[f] ?? row.seq) > change.baseSeq;
  let status: PushResult["status"] = "applied";
  let copy: Note | undefined;

  if (row.seq > change.baseSeq) {
    status = "merged";
    // a delete loses to a change made on another device meanwhile
    if (fields.get("deleted") === true && FIELDS.some((f) => f !== "deleted" && changedElsewhere(f))) {
      fields.delete("deleted");
      status = "delete_refused";
    }
    // deleted elsewhere, changed here: the change wins and the note comes back
    if (row.deleted && changedElsewhere("deleted") && fields.get("deleted") !== true) fields.set("deleted", false);
    // both changed the words: the server's stay, this device's become a copy
    if (fields.has("text") && changedElsewhere("text")) {
      const mine: NoteFields = { ...rowFields(row), ...Object.fromEntries(fields), text: `（衝突副本）\n${fields.get("text") as string}`, deleted: false } as NoteFields;
      copy = toNote(await insertNote(tx, userId, crypto.randomUUID(), mine, at, at));
      fields.delete("text");
      status = "conflict_copy";
    }
  }
  if (fields.get("deleted") === true) fields.set("text", ""); // the words go; the mark stays

  if (fields.size === 0) return { id: change.id, status, note: toNote(row), copy };
  const seq = await nextSeq(tx);
  const set: Record<string, unknown> = { seq, updatedAt: at, fieldSeqs: { ...row.fieldSeqs } };
  for (const [f, v] of fields) {
    set[f] = column(f, v);
    (set.fieldSeqs as Record<string, number>)[f] = seq;
  }
  const [updated] = await tx.update(notes).set(set).where(eq(notes.id, row.id)).returning();
  return { id: change.id, status, note: toNote(updated!), copy };
}

function rowFields(row: Row): NoteFields {
  const note = toNote(row);
  return Object.fromEntries(FIELDS.map((f) => [f, note[f]])) as NoteFields;
}

async function insertNote(tx: Tx, userId: string, id: string, fields: NoteFields, createdAt: Date, at: Date): Promise<Row> {
  const seq = await nextSeq(tx);
  const values: Record<string, unknown> = { id, userId, createdAt, updatedAt: at, seq, fieldSeqs: Object.fromEntries(FIELDS.map((f) => [f, seq])) };
  for (const f of FIELDS) values[f] = column(f, fields[f]);
  if (fields.deleted) values.text = "";
  const [row] = await tx.insert(notes).values(values as typeof notes.$inferInsert).returning();
  return row!;
}

/** 便利貼同步：拉下別台的變更、推上這台的變更。 */
export function noteRoutes(deps: AppDeps) {
  const app = new Hono<AppEnv>();
  const { db } = deps.database;
  const now = deps.now ?? (() => new Date());
  app.use("*", requireAuth(deps));

  app.get("/changes", async (c) => {
    const since = Number(c.req.query("since") ?? "0");
    if (!Number.isSafeInteger(since) || since < 0) return apiError(c, 400, "invalid_input", "since 要是 0 以上的整數。");
    const rows = await db
      .select()
      .from(notes)
      .where(and(eq(notes.userId, c.get("session").user.id), gt(notes.seq, since)))
      .orderBy(asc(notes.seq))
      .limit(PAGE + 1);
    const page = rows.slice(0, PAGE);
    const body: ChangesResponse = { notes: page.map(toNote), seq: page.at(-1)?.seq ?? since, more: rows.length > PAGE };
    return c.json(body);
  });

  app.post("/push", async (c) => {
    const body = await readJson(c, pushInput);
    if ("response" in body) return body.response;
    const userId = c.get("session").user.id;
    const at = now();
    const results: PushResult[] = [];
    for (const change of body.data.changes) {
      results.push(await db.transaction((tx) => applyChange(tx, userId, change, at)));
    }
    const newest = Math.max(0, ...results.flatMap((r) => [r.note?.seq ?? 0, r.copy?.seq ?? 0]));
    if (results.some((r) => r.status !== "rejected")) deps.hub.notify(userId, { type: "notes.changed", seq: newest });
    return c.json({ results });
  });

  return app;
}
