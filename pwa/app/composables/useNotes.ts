import { get, set } from "idb-keyval";
import { NOTE_COLORS, type ChangesResponse, type Note, type NoteField, type NoteFields, type PushResult } from "@goblincamp/shared";
import { ApiError, api } from "~/utils/api";
import { residentName } from "~/utils/names";

/**
 * The notes on this phone and keeping them the same as the server's — the same rules as the Mac (mac/Sources/GoblinCamp/Sync.swift):
 * changes are kept here first (IndexedDB, so the app works offline) with the fields that changed, sent a second later,
 * and what changed elsewhere is fetched when the server says so over the WebSocket.
 */
type LocalNote = NoteFields & { id: string; createdAt: string; updatedAt: string };
interface Meta {
  /** The server's number for the note (0 = the server has never seen it). */
  seq: number;
  /** Fields changed here and not sent yet. */
  dirty: NoteField[];
}
interface Saved {
  userId: string;
  lastSeq: number;
  notes: Record<string, LocalNote>;
  meta: Record<string, Meta>;
}

const FIELDS: NoteField[] = ["text", "color", "breed", "goblinName", "dueAt", "remindAt", "remindFired", "done", "deleted", "kind", "desk"];
const KEY = "gc-notes-v1";
/** Plain residents mostly, now and then a rarer one (as on the Mac). */
const BREEDS = ["common", "common", "common", "scout", "brute", "sage", "golden"];

export type SyncStatus = "idle" | "syncing" | "synced" | "offline" | "signed-out" | "problem";

const state = reactive<{ loaded: boolean; saved: Saved | null; status: SyncStatus; problem: string; syncedAt: number; now: number }>({
  loaded: false,
  saved: null,
  status: "idle",
  problem: "",
  syncedAt: 0,
  now: Date.now(),
});
let debounce: ReturnType<typeof setTimeout> | undefined;
let running = false;
let again = false;
let socket: WebSocket | null = null;
let reconnectDelay = 5000;
let clock: ReturnType<typeof setInterval> | undefined;
let onSignedOut: (() => void) | null = null;

function persist() {
  if (state.saved) void set(KEY, JSON.parse(JSON.stringify(state.saved)));
}

function sameValue(a: unknown, b: unknown) {
  return a === b || (typeof a === "string" && typeof b === "string" && !Number.isNaN(Date.parse(a)) && Date.parse(a) === Date.parse(b) && a.includes("T"));
}

/** Takes the server's note, keeping fields changed here that are not sent yet. */
function applyRemote(remote: Note) {
  const saved = state.saved!;
  const local = saved.notes[remote.id];
  const meta = saved.meta[remote.id] ?? { seq: 0, dirty: [] };
  if (!local) {
    if (remote.deleted) return;
    const { seq: _seq, ...fields } = remote;
    saved.notes[remote.id] = fields;
  } else {
    for (const f of FIELDS) if (!meta.dirty.includes(f)) (local as Record<string, unknown>)[f] = remote[f];
    local.updatedAt = remote.updatedAt;
    if (local.deleted && meta.dirty.length === 0) delete saved.notes[remote.id];
  }
  saved.meta[remote.id] = { seq: Math.max(meta.seq, remote.seq), dirty: meta.dirty };
  // a reminder answered elsewhere: its notification on this phone goes too
  if (!remote.remindAt || remote.deleted) void closeNotification(remote.id);
}

async function closeNotification(noteId: string) {
  if (!("serviceWorker" in navigator)) return;
  const registration = await navigator.serviceWorker.getRegistration();
  for (const n of (await registration?.getNotifications({ tag: noteId })) ?? []) n.close();
}

async function pushAll() {
  const saved = state.saved!;
  for (let round = 0; round < 20; round++) {
    const waiting = Object.entries(saved.meta).filter(([id, m]) => m.dirty.length > 0 && saved.notes[id]).slice(0, 100);
    if (waiting.length === 0) return;
    const sent = waiting.map(([id, m]) => {
      const note = saved.notes[id]!;
      const fields = m.seq === 0 ? FIELDS : m.dirty;
      return { id, baseSeq: m.seq, fields: Object.fromEntries(fields.map((f) => [f, note[f]])) as Partial<NoteFields>, createdAt: m.seq === 0 ? note.createdAt : undefined };
    });
    const { results } = await api<{ results: PushResult[] }>("POST", "notes/push", { changes: sent });
    let stuck = false;
    results.forEach((r, i) => {
      const change = sent[i]!;
      const note = saved.notes[change.id];
      const meta = saved.meta[change.id];
      if (!note || !meta) return;
      if (r.status === "rejected") {
        if (r.reason === "id_taken") {
          // (the id is someone else's): the note takes a new one
          const fresh = crypto.randomUUID();
          saved.notes[fresh] = { ...note, id: fresh };
          saved.meta[fresh] = { seq: 0, dirty: [...FIELDS] };
          delete saved.notes[change.id];
          delete saved.meta[change.id];
        } else if (r.reason === "limit") {
          state.problem = "便利貼超過 500 張，新的沒有同步。";
          stuck = true;
        } else {
          saved.meta[change.id] = { seq: 0, dirty: [...FIELDS] };
        }
        return;
      }
      // what was sent is no longer waiting (unless it changed again meanwhile)
      meta.dirty = meta.dirty.filter((f) => !(f in change.fields) || !sameValue(note[f], change.fields[f]));
      if (note.deleted && meta.dirty.length === 0) {
        delete saved.notes[change.id];
        delete saved.meta[change.id];
      }
      if (r.note) applyRemote(r.note);
      if (r.copy) applyRemote(r.copy);
    });
    persist();
    if (stuck) return;
  }
}

async function pullAll() {
  const saved = state.saved!;
  for (let page = 0; page < 50; page++) {
    const res = await api<ChangesResponse>("GET", `notes/changes?since=${saved.lastSeq}`);
    for (const n of res.notes) applyRemote(n);
    saved.lastSeq = Math.max(saved.lastSeq, res.seq);
    persist();
    if (!res.more) return;
  }
}

async function syncNow(): Promise<void> {
  if (!state.saved) return;
  if (running) {
    again = true;
    return;
  }
  running = true;
  state.status = "syncing";
  try {
    await pushAll();
    await pullAll();
    state.status = state.problem ? "problem" : "synced";
    state.syncedAt = Date.now();
    reconnectDelay = 5000;
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) {
      state.status = "signed-out";
      onSignedOut?.();
    } else if (e instanceof ApiError && e.offline) state.status = "offline";
    else {
      state.status = "problem";
      state.problem = e instanceof Error ? e.message : String(e);
    }
  } finally {
    running = false;
    if (again) {
      again = false;
      void syncNow();
    }
  }
}

function syncSoon() {
  clearTimeout(debounce);
  debounce = setTimeout(() => void syncNow(), 1000);
}

function connect() {
  if (socket || !state.saved) return;
  // (in development Nitro's proxy does not carry WebSockets, so it goes straight to the server; the session cookie goes
  // along, since cookies do not care about the port)
  const base = import.meta.dev ? `ws://${location.hostname}:8787` : location.origin.replace(/^http/, "ws");
  const ws = new WebSocket(`${base}/api/ws`);
  socket = ws;
  ws.onmessage = (event) => {
    const text = String(event.data);
    if (text.includes('"notes.changed"')) void syncNow();
    // the camp page listens for this one (useCamp)
    if (text.includes('"camp.changed"')) window.dispatchEvent(new Event("gc:camp-changed"));
  };
  ws.onclose = async () => {
    if (socket !== ws) return;
    socket = null;
    if (!state.saved) return;
    try {
      await api("GET", "auth/me");
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        state.status = "signed-out";
        onSignedOut?.();
        return;
      }
    }
    const wait = reconnectDelay;
    reconnectDelay = Math.min(reconnectDelay * 2, 120_000);
    setTimeout(() => {
      connect();
      void syncNow();
    }, wait);
  };
}

export function useNotes() {
  /** Opens this person's notes (the ones kept on the phone at once, then whatever changed on the server). */
  async function start(userId: string, signedOut: () => void) {
    onSignedOut = signedOut;
    if (!state.loaded || state.saved?.userId !== userId) {
      const kept = (await get<Saved>(KEY)) ?? null;
      state.saved = kept && kept.userId === userId ? kept : { userId, lastSeq: 0, notes: {}, meta: {} };
      state.loaded = true;
      persist();
    }
    if (!clock) {
      clock = setInterval(() => (state.now = Date.now()), 5_000); // (a reminder rings within five seconds)
      // coming back to the app: catch up at once
      document.addEventListener("visibilitychange", () => {
        if (document.visibilityState !== "visible" || !state.saved) return;
        state.now = Date.now();
        void syncNow();
        connect();
      });
    }
    connect();
    void syncNow(); // (the notes kept on the phone show meanwhile)
  }

  /** Signed out: the notes on this phone go (the account keeps them). */
  async function stop() {
    socket?.close();
    socket = null;
    state.saved = null;
    state.loaded = false;
    state.status = "signed-out";
    await set(KEY, null);
  }

  const list = computed(() => {
    const saved = state.saved;
    if (!saved) return [];
    const now = state.now;
    const rank = (n: LocalNote) => (n.done ? 3 : n.remindAt && Date.parse(n.remindAt) <= now ? 0 : n.dueAt ? 1 : 2);
    return Object.values(saved.notes)
      .filter((n) => !n.deleted)
      .sort((a, b) => rank(a) - rank(b) || (a.dueAt && b.dueAt ? Date.parse(a.dueAt) - Date.parse(b.dueAt) : 0) || Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
  });

  function note(id: string): LocalNote | undefined {
    return state.saved?.notes[id];
  }

  function change(id: string, patch: Partial<NoteFields>) {
    const saved = state.saved;
    const n = saved?.notes[id];
    if (!saved || !n) return;
    const meta = (saved.meta[id] ??= { seq: 0, dirty: [] });
    for (const [f, v] of Object.entries(patch) as [NoteField, unknown][]) {
      if (sameValue(n[f], v)) continue;
      (n as Record<string, unknown>)[f] = v;
      if (!meta.dirty.includes(f)) meta.dirty.push(f);
    }
    n.updatedAt = new Date().toISOString();
    persist();
    syncSoon();
  }

  /** A new note not kept anywhere yet (a todo, or a memo: kept off the desktop, no times). */
  function draft(kind: "todo" | "memo" = "todo"): NoteFields {
    const count = Object.values(state.saved?.notes ?? {}).filter((n) => !n.deleted).length;
    return {
      kind,
      desk: kind === "todo",
      text: "",
      color: NOTE_COLORS[count % NOTE_COLORS.length]!,
      breed: BREEDS[Math.floor(Math.random() * BREEDS.length)]!,
      goblinName: residentName(useRace().race.value),
      dueAt: null,
      remindAt: null,
      remindFired: false,
      done: false,
      deleted: false,
    };
  }

  /** Keeps a new note (and sends it). */
  function create(fields: NoteFields): string {
    const saved = state.saved!;
    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    saved.notes[id] = { ...fields, id, createdAt: now, updatedAt: now };
    saved.meta[id] = { seq: 0, dirty: [...FIELDS] };
    persist();
    syncSoon();
    return id;
  }

  const remove = (id: string) => change(id, { deleted: true, text: "" });
  /** 知道了. */
  const acknowledge = (id: string) => {
    change(id, { remindAt: null, remindFired: false });
    void closeNotification(id);
  };

  /** How the goblin on a note feels (the same moods as on the Mac). A reminder that is due rings here too. */
  function mood(n: LocalNote): "idle" | "soon" | "late" | "ringing" | "done" {
    const now = state.now;
    if (n.done) return "done";
    if (n.remindAt && Date.parse(n.remindAt) <= now) return "ringing";
    if (n.dueAt) {
      const left = Date.parse(n.dueAt) - now;
      if (left < 0) return "late";
      if (left < 3_600_000) return "soon";
    }
    return "idle";
  }

  return { state: readonly(state), start, stop, list, note, change, draft, create, remove, acknowledge, mood, syncNow };
}
