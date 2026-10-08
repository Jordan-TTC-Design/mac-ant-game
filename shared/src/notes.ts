import { z } from "zod";

export const NOTE_COLORS = ["yellow", "pink", "blue", "green", "purple"] as const;
export const MAX_NOTES_PER_USER = 500;
export const MAX_CHANGES_PER_PUSH = 100;

const isoDate = z.iso.datetime({ offset: true });

/** What a device may change on a note. A push sends only the fields it changed since it last synced. */
export const noteFieldsSchema = z.object({
  text: z.string().max(5000),
  color: z.enum(NOTE_COLORS),
  /** The goblin living on it (a breed id) and its name. */
  breed: z.string().min(1).max(20),
  goblinName: z.string().max(30),
  /** The target time. */
  dueAt: isoDate.nullable(),
  /** When the goblin jumps out to remind you; cleared when someone says 知道了. */
  remindAt: isoDate.nullable(),
  /** The reminder has been shown and nobody said 知道了 yet. */
  remindFired: z.boolean(),
  done: z.boolean(),
  /** A deleted note stays as a mark (with its words gone) so every device learns it was deleted. */
  deleted: z.boolean(),
  /**
   * 待辦 (todo: reminders and a target time) or 備忘 (memo: something kept at hand, a link or a command; no times).
   * Optional for devices from before it (Mac 0.9): a note without it is a todo.
   */
  kind: z.enum(["todo", "memo"]).default("todo"),
  /** On the Mac's desktop (true) or kept in the notes wall only (false). Optional as `kind`. */
  desk: z.boolean().default(true),
});
export type NoteFields = z.infer<typeof noteFieldsSchema>;
export type NoteField = keyof NoteFields;

export const noteChangeSchema = z.object({
  id: z.uuid(),
  /** The server's `seq` for this note when the device last saw it; 0 for a note the server has never seen. */
  baseSeq: z.number().int().min(0),
  fields: noteFieldsSchema.partial(),
  /** Only for a new note: when it was written. */
  createdAt: isoDate.optional(),
});
export type NoteChange = z.infer<typeof noteChangeSchema>;

export const pushInput = z.object({ changes: z.array(noteChangeSchema).min(1).max(MAX_CHANGES_PER_PUSH) });

/** A note as the server has it. */
export interface Note extends NoteFields {
  id: string;
  createdAt: string;
  updatedAt: string;
  /** Grows with every change on the server; devices remember the highest one they have seen. */
  seq: number;
}

export type PushStatus =
  /** Taken as it was. */
  | "applied"
  /** Someone else changed other fields meanwhile; both changes are kept. */
  | "merged"
  /** Both changed the words: the server's stay, and the device's words became a new note (`copy`). */
  | "conflict_copy"
  /** A delete that lost to a change made elsewhere: the note stays. */
  | "delete_refused"
  /** Not taken (`reason` says why). */
  | "rejected";

export interface PushResult {
  id: string;
  status: PushStatus;
  /** The note as it is now (absent only when rejected before it existed). */
  note?: Note;
  copy?: Note;
  reason?: "not_found" | "id_taken" | "limit" | "incomplete";
}

export interface ChangesResponse {
  notes: Note[];
  /** Ask again with `since` = this. */
  seq: number;
  /** More changes are waiting (ask again right away). */
  more: boolean;
}

/** What the server says over the WebSocket (`/api/ws`). */
export type ServerEvent =
  | { type: "notes.changed"; seq: number }
  | { type: "camp.changed"; version: number }
  | { type: "hello"; userId: string }
  /** Friends or messages changed (a message came, an ask, a yes). */
  | { type: "friends.changed"; from?: string }
  /** The guild (its members, invitations, badge…) or an invitation to one changed: fetch it. */
  | { type: "guild.changed" }
  /** A guild member's Mac said how they are (GUILD.md §3). */
  | { type: "guild.presence"; userId: string; state: "focus" | "online" | "away" | "offline"; at: string }
  /** A guild member is walking their avatar by hand (GUILD.md §3.1): where it is now; and when they stopped. */
  | ({ type: "guild.move"; userId: string } & import("./guild.ts").GuildMove)
  | { type: "guild.release"; userId: string }
  /** Something said in the guild hall. */
  | ({ type: "guild.say" } & import("./guild.ts").GuildChatLine)
  /** The shared pomodoro changed (fetch it, unless this version is already here). */
  | { type: "pomodoro.changed"; version: number }
  /** A Claude question came, was answered or went away. */
  | { type: "claude.changed" }
  /** The answer to a question the Mac `device` is waiting on. */
  | { type: "claude.answer"; id: string; device: string; action: "allow" | "deny" | "reply" | "dismiss"; text?: string };

/** A phone's Web Push subscription, as the browser gives it (`PushSubscription.toJSON()`). */
export const pushSubscriptionSchema = z.object({
  endpoint: z.url().max(1000),
  expirationTime: z.number().nullable().optional(),
  keys: z.object({ p256dh: z.string().min(1).max(200), auth: z.string().min(1).max(100) }),
});
export type PushSubscriptionJSON = z.infer<typeof pushSubscriptionSchema>;

/** What a reminder push carries to the phone's service worker. */
/** A push about the big world (a party arrived, a cell was attacked, a great monster fell): tapping it opens `url`. */
export interface WorldPush {
  type: "world";
  title: string;
  body: string;
  url: string;
  /** A later push with the same tag replaces this one. */
  tag: string;
}

export interface ReminderPush {
  type: "reminder";
  noteId: string;
  /** 「咔噗・壯碩哥布林」-ish: who is reminding. */
  title: string;
  /** The first lines of the note. */
  body: string;
}
