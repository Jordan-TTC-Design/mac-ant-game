import { sql } from "drizzle-orm";
import { bigint, boolean, customType, index, integer, jsonb, pgSequence, pgTable, primaryKey, text, timestamp, uuid } from "drizzle-orm/pg-core";

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

/**
 * The camp's books, one per account (server/CAMP.md §5). Births and deaths are worked out from `seed`, `started_at` and
 * the race's rules (shared/src/camp); `next_slot`, `next_id` and `advanced_to` say how far they have been worked out.
 */
export const camps = pgTable("camps", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  race: text("race").notNull(),
  /** 0 … 2^32 − 1 (the rules' random numbers start from it). */
  seed: bigint("seed", { mode: "number" }).notNull(),
  startedAt: timestamp("started_at", { withTimezone: true, precision: 3 }).notNull(),
  advancedTo: timestamp("advanced_to", { withTimezone: true, precision: 3 }).notNull(),
  nextSlot: integer("next_slot").notNull(),
  nextId: integer("next_id").notNull(),
  peak: integer("peak").notNull(),
  /** Grows with every change to the books; devices compare it with theirs. */
  version: bigint("version", { mode: "number" }).notNull().default(1),
  /** The next monster raid to look at (shared/src/camp/raids.ts). */
  nextRaid: integer("next_raid").notNull().default(0),
  materials: jsonb("materials").$type<Record<string, number>>().notNull().default({}),
  larder: jsonb("larder").$type<Record<string, number>>().notNull().default({}),
  /** Gear in the camp's store: [{ id, left }] (left = wear left, 0…1). */
  armory: jsonb("armory").$type<{ id: string; left: number }[]>().notNull().default([]),
  /** Food boosts still running and food cooldowns: food id → the time it ends (ISO). */
  boosts: jsonb("boosts").$type<Record<string, string>>().notNull().default({}),
  foodCooldowns: jsonb("food_cooldowns").$type<Record<string, string>>().notNull().default({}),
  princessName: text("princess_name").notNull().default(""),
  /** The princess's story as the Mac keeps it (RomanceState); the server stores it as it is for now. */
  romance: jsonb("romance"),
  kills: jsonb("kills").$type<Record<string, number>>().notNull().default({}),
  delivered: integer("delivered").notNull().default(0),
  /** What an old save said when it was moved in (before the caps), for looking into problems. */
  migratedFrom: jsonb("migrated_from"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

/** Everyone who ever lived in a camp (the dead are kept a while for the battle reports). */
export const campResidents = pgTable(
  "camp_residents",
  {
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    id: integer("id").notNull(),
    breed: text("breed").notNull(),
    seed: bigint("seed", { mode: "number" }).notNull(),
    /** A resident moved in from an old save keeps its old 64-bit seed (its looks and name come from it on the Mac). */
    legacySeed: text("legacy_seed"),
    name: text("name"),
    parents: text("parents"),
    bornAt: timestamp("born_at", { withTimezone: true, precision: 3 }).notNull(),
    diesAt: timestamp("dies_at", { withTimezone: true, precision: 3 }),
    diedAt: timestamp("died_at", { withTimezone: true, precision: 3 }),
    /** What it wears: slot → { id, left }. */
    gear: jsonb("gear").$type<Record<string, { id: string; left: number }>>(),
    /** home, or a cell / an expedition in the big world (later). */
    place: text("place").notNull().default("home"),
  },
  (t) => [primaryKey({ columns: [t.userId, t.id] }), index("camp_residents_alive_idx").on(t.userId).where(sql`died_at is null`)],
);

/** Numbers every change to any camp's books. */
export const campEventSeq = pgSequence("camp_event_seq");

/** What happened in a camp, for the devices to play and the phone to show (kept 30 days). */
export const campEvents = pgTable(
  "camp_events",
  {
    seq: bigint("seq", { mode: "number" }).primaryKey(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
    kind: text("kind").notNull(),
    data: jsonb("data").notNull(),
  },
  (t) => [index("camp_events_user_seq_idx").on(t.userId, t.seq)],
);
