import { bigint, boolean, customType, index, jsonb, pgSequence, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

/** Case-insensitive text (PostgreSQL's citext extension), so Me@Mail.com and me@mail.com are the same address. */
const citext = customType<{ data: string }>({ dataType: () => "citext" });

/** See server/DESIGN.md §4. The other tables come with the stages that use them. */
export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  email: citext("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  /** Shown on messengers instead of the address. */
  displayName: text("display_name").notNull(),
  /** Like GOB-7K2Q; what friends type to find each other. */
  friendCode: text("friend_code").notNull().unique(),
  emailVerifiedAt: timestamp("email_verified_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  /** When the account asked to be deleted; everything goes 30 days later. */
  deletingAt: timestamp("deleting_at", { withTimezone: true }),
});

/** bytea: tokens and codes are kept only as SHA-256 hashes. */
const bytea = customType<{ data: Buffer }>({ dataType: () => "bytea" });

/** A Mac or a phone. The id is made by the device, so the same Mac is the same row every time it logs in. */
export const devices = pgTable("devices", {
  id: uuid("id").primaryKey(),
  userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
  kind: text("kind", { enum: ["mac", "pwa"] }).notNull(),
  name: text("name").notNull(),
  /** A phone's Web Push subscription (stage 3). */
  pushSubscription: jsonb("push_subscription"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).notNull().defaultNow(),
});

export const sessions = pgTable(
  "sessions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    deviceId: uuid("device_id").references(() => devices.id, { onDelete: "set null" }),
    tokenHash: bytea("token_hash").notNull().unique(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    lastSeenAt: timestamp("last_seen_at", { withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    revokedAt: timestamp("revoked_at", { withTimezone: true }),
  },
  (t) => [index("sessions_user_idx").on(t.userId)],
);

/** The links in the emails: confirm the address, set a new password. */
export const emailTokens = pgTable(
  "email_tokens",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    purpose: text("purpose", { enum: ["verify", "reset"] }).notNull(),
    tokenHash: bytea("token_hash").notNull().unique(),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
    expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
    usedAt: timestamp("used_at", { withTimezone: true }),
  },
  (t) => [index("email_tokens_user_idx").on(t.userId)],
);

/** Registration needs one of these; each works once. */
export const invites = pgTable("invites", {
  codeHash: bytea("code_hash").primaryKey(),
  /** Who handed it out; null = made by the admin with `pnpm invite create`. */
  createdBy: uuid("created_by").references(() => users.id, { onDelete: "set null" }),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  usedAt: timestamp("used_at", { withTimezone: true }),
  usedBy: uuid("used_by").references(() => users.id, { onDelete: "set null" }),
});

/** Numbers every change to a note; devices ask for "everything after number N". */
export const noteSeq = pgSequence("note_seq");

/** See server/DESIGN.md §5. Where a note sits on a screen is not here: that stays on each Mac. */
export const notes = pgTable(
  "notes",
  {
    /** Made by the device that wrote the note (the id in the Mac's notes.json). */
    id: uuid("id").primaryKey(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    text: text("text").notNull(),
    color: text("color").notNull(),
    breed: text("breed").notNull(),
    goblinName: text("goblin_name").notNull(),
    dueAt: timestamp("due_at", { withTimezone: true }),
    remindAt: timestamp("remind_at", { withTimezone: true }),
    remindFired: boolean("remind_fired").notNull().default(false),
    done: boolean("done").notNull().default(false),
    deleted: boolean("deleted").notNull().default(false),
    createdAt: timestamp("created_at", { withTimezone: true }).notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull(),
    /** The number of the last change. */
    seq: bigint("seq", { mode: "number" }).notNull(),
    /** The number of the last change to each field, to tell a real conflict (both changed the words) from changes to different fields. */
    fieldSeqs: jsonb("field_seqs").$type<Record<string, number>>().notNull().default({}),
    /** The reminder time a phone was last notified for (so each reminder is pushed once, and again after a snooze). */
    pushedFor: timestamp("pushed_for", { withTimezone: true }),
  },
  (t) => [index("notes_user_seq_idx").on(t.userId, t.seq), index("notes_remind_idx").on(t.remindAt)],
);
