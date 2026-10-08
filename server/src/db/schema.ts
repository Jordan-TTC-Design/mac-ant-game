import type { CampFocus, Ranch, Site } from "@goblincamp/shared/camp";
import type { CellBuilding, FightBoosts } from "@goblincamp/shared/world";
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
  /** user, or admin (後台). The first admin comes from ADMIN_EMAILS or `make admin email=…`; the rest are made in 後台. */
  role: text("role", { enum: ["user", "admin"] }).notNull().default("user"),
  /** An admin stopped this account: it is signed out everywhere and cannot sign in until it is let back in. */
  disabledAt: timestamp("disabled_at", { withTimezone: true }),
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
    /** verify / reset: links in mails; handoff: a Mac opening the web page signed in (a few minutes, once). */
    purpose: text("purpose", { enum: ["verify", "reset", "handoff"] }).notNull(),
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
    /** todo or memo (shared/src/notes.ts). */
    kind: text("kind").notNull().default("todo"),
    /** On the Mac's desktop, or in the notes wall only. */
    desk: boolean("desk").notNull().default(true),
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
  /** 聖光模式 on since then (null: off): no raids, nobody attacks it, births at half speed above 120 (server/CAMP.md §7). */
  sanctuarySince: timestamp("sanctuary_since", { withTimezone: true, precision: 3 }),
  /** When it was last turned off (it may be turned on again SANCTUARY_REST_HOURS later). */
  sanctuaryOffAt: timestamp("sanctuary_off_at", { withTimezone: true, precision: 3 }),
  nextSlot: integer("next_slot").notNull(),
  nextId: integer("next_id").notNull(),
  peak: integer("peak").notNull(),
  /** Grows with every change to the books; devices compare it with theirs. */
  version: bigint("version", { mode: "number" }).notNull().default(1),
  /** The next monster raid to look at (shared/src/camp/raids.ts). */
  nextRaid: integer("next_raid").notNull().default(0),
  materials: jsonb("materials").$type<Record<string, number>>().notNull().default({}),
  larder: jsonb("larder").$type<Record<string, number>>().notNull().default({}),
  /** Gear in the camp's store: [{ id, left, held? }] (left = wear left; held = taken off by hand, not handed out). */
  armory: jsonb("armory").$type<{ id: string; left: number; held?: boolean }[]>().notNull().default([]),
  /** Whether the store is handed out by itself (shared/src/camp/gear.ts `redistribute`); off: only by hand. */
  autoGear: boolean("auto_gear").notNull().default(true),
  /** 任務 claimed (shared/src/camp/quests.ts): quest id → when (ISO). */
  quests: jsonb("quests").$type<Record<string, string>>().notNull().default({}),
  /** Decorations the player put down in the camp window (shared/src/camp/decor.ts): kind, offset from the land's anchor, turned. */
  decor: jsonb("decor").$type<{ kind: string; x: number; y: number; flip?: boolean }[]>().notNull().default([]),
  /** The ranch: the animals kept in the pens the player fenced, and when a Mac last reported (shared/src/camp/ranch.ts). */
  ranch: jsonb("ranch").$type<Ranch>().notNull().default({ animals: [] }),
  /** The pomodoro's focus rounds that ran to the end, per day (shared/src/camp/focus.ts); null until the first. */
  focus: jsonb("focus").$type<CampFocus>(),
  /** Food boosts still running and food cooldowns: food id → the time it ends (ISO). */
  boosts: jsonb("boosts").$type<Record<string, string>>().notNull().default({}),
  foodCooldowns: jsonb("food_cooldowns").$type<Record<string, string>>().notNull().default({}),
  princessName: text("princess_name").notNull().default(""),
  /** The princess's story as the Mac keeps it (RomanceState); the server stores it as it is for now. */
  romance: jsonb("romance"),
  kills: jsonb("kills").$type<Record<string, number>>().notNull().default({}),
  delivered: integer("delivered").notNull().default(0),
  /** The camp's sites (shared/src/camp/sites.ts): the farm first; a site with `busyUntil` is being built or raised. */
  sites: jsonb("sites").$type<Site[]>().notNull().default([{ id: 1, kind: "farm", level: 1 }]),
  /** What the sites make is worked out by the hour up to here; the fractions left over wait in the carry. */
  producedTo: timestamp("produced_to", { withTimezone: true, precision: 3 }).notNull().defaultNow(),
  productionCarry: jsonb("production_carry").$type<Record<string, number>>().notNull().default({}),
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
    /** What it wears: slot → { id, left, pinned? } (pinned = put on by hand, the handing out leaves it be). */
    gear: jsonb("gear").$type<Record<string, { id: string; left: number; pinned?: boolean }>>(),
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

/** A camp's standing in the big world (server/WORLD.md §15). A camp that never opened it has no row. */
export const worldPlayers = pgTable("world_players", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  open: boolean("open").notNull().default(true),
  /** Where the camp stands on the map (picked when opening; everybody at home lives there); expeditions from home start here. */
  homeCell: text("home_cell").notNull(),
  openedAt: timestamp("opened_at", { withTimezone: true, precision: 3 }).notNull(),
  /** When the camp last moved to another cell (it may once every HOME_MOVE_DAYS). */
  homeMovedAt: timestamp("home_moved_at", { withTimezone: true, precision: 3 }),
  /** Turtling after a defeat (shared/src/world/territory.ts). */
  shieldedSince: timestamp("shielded_since", { withTimezone: true, precision: 3 }),
  lastShieldEnded: timestamp("last_shield_ended", { withTimezone: true, precision: 3 }),
  xp: integer("xp").notNull().default(0),
  /** Held cells earn experience by the day; days are counted from here. */
  xpCountedTo: timestamp("xp_counted_to", { withTimezone: true, precision: 3 }).notNull(),
});

/** Cells someone changed: held, or a lair cleared. A cell nobody touched is worked out from the seed (contents.ts). */
export const worldCells = pgTable(
  "world_cells",
  {
    cell: text("cell").primaryKey(),
    owner: uuid("owner").references(() => users.id, { onDelete: "set null" }),
    heldSince: timestamp("held_since", { withTimezone: true, precision: 3 }),
    /** A nest being built or built (it raises residents once NEST_BUILD_HOURS have passed). */
    nestStartedAt: timestamp("nest_started_at", { withTimezone: true, precision: 3 }),
    /** The nest's next birth slot (camp/population.ts). */
    nextSlot: integer("next_slot").notNull().default(0),
    advancedTo: timestamp("advanced_to", { withTimezone: true, precision: 3 }),
    town: boolean("town").notNull().default(false),
    /** What the ground yields has been taken up to here (shared/src/world/territory.ts cellYield). */
    yieldedTo: timestamp("yielded_to", { withTimezone: true, precision: 3 }),
    /** The lair that was here was beaten at this time (it comes back after its respawn hours). */
    clearedAt: timestamp("cleared_at", { withTimezone: true, precision: 3 }),
    /** A lair that beat a party off, still hurt (shared/src/world/battle.ts LairWounds). */
    lairWounds: jsonb("lair_wounds").$type<{ hp: number[]; at: number }>(),
    /** What the holder built on it (shared/src/world/holdings.ts); gone when the cell changes hands. */
    building: jsonb("building").$type<CellBuilding>(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).notNull().defaultNow(),
  },
  (t) => [index("world_cells_owner_idx").on(t.owner)],
);

/** A party on its way, and what happened when it got there. Its residents live at place `exp:<id>` while it walks. */
export const expeditions = pgTable(
  "expeditions",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    kind: text("kind", { enum: ["attack", "move", "guard", "recall", "reroute"] }).notNull(),
    /** "home" or a cell id. */
    fromPlace: text("from_place").notNull(),
    toCell: text("to_cell").notNull(),
    party: jsonb("party").$type<number[]>().notNull(),
    settle: boolean("settle").notNull().default(false),
    /** The food boosts the party carries (shared/src/world/supplies.ts). */
    boosts: jsonb("boosts").$type<FightBoosts>(),
    /** The cells it walks between round other camps' land (shared/src/world/route.ts); null: straight there. */
    route: jsonb("route").$type<string[]>(),
    setOutAt: timestamp("set_out_at", { withTimezone: true, precision: 3 }).notNull(),
    arriveAt: timestamp("arrive_at", { withTimezone: true, precision: 3 }).notNull(),
    status: text("status", { enum: ["walking", "done"] }).notNull().default("walking"),
    /** The player whose cell it met (when it was someone's). */
    defender: uuid("defender").references(() => users.id, { onDelete: "set null" }),
    /** The report (shared/src/world/api.ts ExpeditionReport, without the ids the row already has). */
    result: jsonb("result"),
  },
  (t) => [index("expeditions_walking_idx").on(t.arriveAt).where(sql`status = 'walking'`), index("expeditions_user_idx").on(t.userId, t.setOutAt), index("expeditions_defender_idx").on(t.defender)],
);

/** A great monster of the world (shared/src/world/bosses.ts) that somebody has seen or fought: its wounds and who dealt them. */
export const worldBosses = pgTable("world_bosses", {
  /** `<region>@<window>`: one per region per 12 hours. */
  key: text("key").primaryKey(),
  kind: text("kind").notNull(),
  cell: text("cell").notNull(),
  hp: integer("hp").notNull(),
  maxHp: integer("max_hp").notNull(),
  endsAt: timestamp("ends_at", { withTimezone: true, precision: 3 }).notNull(),
  /** Camp → damage dealt. */
  damage: jsonb("damage").$type<Record<string, number>>().notNull().default({}),
  defeatedAt: timestamp("defeated_at", { withTimezone: true, precision: 3 }),
  defeatedBy: uuid("defeated_by").references(() => users.id, { onDelete: "set null" }),
});

/** Spoils waiting for a camp (a boss it helped beat); taken into its books the next time the camp is worked out. */
export const worldRewards = pgTable(
  "world_rewards",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true, precision: 3 }).notNull(),
    data: jsonb("data").$type<{ boss: string; name: string; loot: Record<string, number>; xp: number; share: number }>().notNull(),
    claimedAt: timestamp("claimed_at", { withTimezone: true, precision: 3 }),
  },
  (t) => [index("world_rewards_open_idx").on(t.userId).where(sql`claimed_at is null`)],
);

/** What each cell of the big world really is (OpenStreetMap, world/osm.ts), worked out once. */
export const worldTerrain = pgTable("world_terrain", {
  cell: text("cell").primaryKey(),
  terrain: text("terrain").notNull(),
  source: text("source").notNull().default("osm"),
  createdAt: timestamp("created_at", { withTimezone: true }).notNull().defaultNow(),
});

/** What admins did in 後台 (who, to whom, what). */
export const adminLog = pgTable(
  "admin_log",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    at: timestamp("at", { withTimezone: true }).notNull().defaultNow(),
    adminId: uuid("admin_id").references(() => users.id, { onDelete: "set null" }),
    targetId: uuid("target_id").references(() => users.id, { onDelete: "set null" }),
    action: text("action").notNull(),
    detail: jsonb("detail"),
  },
  (t) => [index("admin_log_at_idx").on(t.at)],
);

/**
 * Friends (server/DESIGN.md §7): one row per pair, the smaller id first. An ask is a row with no `acceptedAt`; a yes fills
 * it in; no, unfriending or blocking removes the row.
 */
export const friendships = pgTable(
  "friendships",
  {
    userA: uuid("user_a").notNull().references(() => users.id, { onDelete: "cascade" }),
    userB: uuid("user_b").notNull().references(() => users.id, { onDelete: "cascade" }),
    askedBy: uuid("asked_by").notNull().references(() => users.id, { onDelete: "cascade" }),
    createdAt: timestamp("created_at", { withTimezone: true, precision: 3 }).notNull(),
    acceptedAt: timestamp("accepted_at", { withTimezone: true, precision: 3 }),
  },
  (t) => [primaryKey({ columns: [t.userA, t.userB] }), index("friendships_b_idx").on(t.userB)],
);

/** Whom an account blocked: their asks and messages are dropped without them knowing. */
export const blocks = pgTable(
  "blocks",
  {
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    blockedId: uuid("blocked_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.blockedId] })],
);

/** Messages between friends (at most 200 characters; cleared after a while, maintenance.ts). */
export const messages = pgTable(
  "messages",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    fromUser: uuid("from_user").notNull().references(() => users.id, { onDelete: "cascade" }),
    toUser: uuid("to_user").notNull().references(() => users.id, { onDelete: "cascade" }),
    text: text("text").notNull(),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
    readAt: timestamp("read_at", { withTimezone: true, precision: 3 }),
  },
  (t) => [index("messages_pair_idx").on(t.fromUser, t.toUser, t.at), index("messages_unread_idx").on(t.toUser).where(sql`read_at is null`)],
);

/** The pomodoro an account's Mac and phone share (shared/src/pomodoro.ts); no row: none running. */
export const pomodoros = pgTable("pomodoros", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  state: jsonb("state").$type<import("@goblincamp/shared").PomodoroState>().notNull(),
  /** The last part the phones were told about (a push when a part begins). */
  toldIndex: integer("told_index").notNull().default(0),
  updatedAt: timestamp("updated_at", { withTimezone: true, precision: 3 }).notNull(),
});

/** Claude Code's questions sent from a Mac to its person's phones (shared/src/claude.ts); kept a day at most. */
export const claudeAsks = pgTable(
  "claude_asks",
  {
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    id: text("id").notNull(),
    deviceId: uuid("device_id").notNull(),
    kind: text("kind", { enum: ["permission", "reply", "done"] }).notNull(),
    project: text("project").notNull(),
    text: text("text").notNull(),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
    /** Answers are taken until then (null: news, no answer). */
    until: timestamp("until", { withTimezone: true, precision: 3 }),
    answer: jsonb("answer").$type<{ action: "allow" | "deny" | "reply" | "dismiss"; text?: string; by: "mac" | "phone"; at: string }>(),
  },
  (t) => [primaryKey({ columns: [t.userId, t.id] }), index("claude_asks_at_idx").on(t.at)],
);

/**
 * 回報 (shared/src/feedback.ts): a bug, an idea or a balance note someone sent. Everyone signed in sees them all. When the
 * account is deleted its reports stay (the author becomes nobody), since others may be following them.
 */
export const feedback = pgTable(
  "feedback",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    kind: text("kind", { enum: ["bug", "idea", "balance"] }).notNull(),
    title: text("title").notNull(),
    body: text("body").notNull().default(""),
    device: text("device"),
    status: text("status", { enum: ["open", "accepted", "working", "next", "done", "declined"] }).notNull().default("open"),
    createdAt: timestamp("created_at", { withTimezone: true, precision: 3 }).notNull(),
    /** Last time anything happened to it (a reply, a status): the list is ordered by it. */
    updatedAt: timestamp("updated_at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [index("feedback_updated_idx").on(t.updatedAt), index("feedback_user_idx").on(t.userId)],
);

/** The thread under a report: replies, and each status an admin set (`status` filled in, `body` maybe empty). */
export const feedbackReplies = pgTable(
  "feedback_replies",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    feedbackId: uuid("feedback_id").notNull().references(() => feedback.id, { onDelete: "cascade" }),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    admin: boolean("admin").notNull(),
    body: text("body").notNull().default(""),
    status: text("status", { enum: ["open", "accepted", "working", "next", "done", "declined"] }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [index("feedback_replies_feedback_idx").on(t.feedbackId, t.at)],
);

/** 我也遇到 / 我也想要: one per account and report (the author does not vote on their own), so the busiest ones stand out. */
export const feedbackVotes = pgTable(
  "feedback_votes",
  {
    feedbackId: uuid("feedback_id").notNull().references(() => feedback.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [primaryKey({ columns: [t.feedbackId, t.userId] })],
);

/** Which cells hold a real landmark (OpenStreetMap, world/osm.ts), looked at once: a row with no kind means none. */
export const worldLandmarks = pgTable("world_landmarks", {
  cell: text("cell").primaryKey(),
  kind: text("kind"),
  name: text("name"),
});

/** A guild (shared/src/guild.ts, GUILD.md): its name, the badge the leader drew (16×16 hex digits) and its level. */
export const guilds = pgTable("guilds", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: citext("name").notNull().unique(),
  badge: text("badge").notNull(),
  level: integer("level").notNull().default(1),
  /** The decorations put down in the hall (shared/src/guild-decor.ts), and a number that grows with every change to them. */
  decor: jsonb("decor").$type<import("@goblincamp/shared").GuildDecorPlaced[]>().notNull().default([]),
  decorVersion: integer("decor_version").notNull().default(0),
  /** The floor (one style and tiles laid with others) and the wall style (GUILD.md §4.3). */
  floor: jsonb("floor").$type<import("@goblincamp/shared").HallFloor>().notNull().default({ base: "oak", tiles: {} }),
  wall: text("wall").notNull().default("stone"),
  /** Contribution the members gave (camp materials, GUILD.md §4.1); the level follows it. */
  points: integer("points").notNull().default(0),
  createdAt: timestamp("created_at", { withTimezone: true, precision: 3 }).notNull(),
});

/** Every change to a hall's decorations: who, when, how much, and the list as it was before (for going back), GUILD_DECOR_LOG_DAYS. */
export const guildDecorLog = pgTable(
  "guild_decor_log",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    guildId: uuid("guild_id").notNull().references(() => guilds.id, { onDelete: "cascade" }),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
    added: integer("added").notNull(),
    moved: integer("moved").notNull(),
    removed: integer("removed").notNull(),
    restored: boolean("restored").notNull().default(false),
    floorChanged: integer("floor_changed").notNull().default(0),
    before: jsonb("before").$type<import("@goblincamp/shared").GuildDecorPlaced[]>().notNull(),
    floorBefore: jsonb("floor_before").$type<import("@goblincamp/shared").HallFloor>(),
  },
  (t) => [index("guild_decor_log_guild_idx").on(t.guildId, t.at)],
);

/**
 * Who is in which guild: one guild per account (the key), one leader per guild. `presence` is what the member's Mac said
 * last and when (shared/src/guild.ts `presenceNow` turns an old one into offline).
 */
export const guildMembers = pgTable(
  "guild_members",
  {
    userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
    guildId: uuid("guild_id").notNull().references(() => guilds.id, { onDelete: "cascade" }),
    role: text("role", { enum: ["leader", "officer", "member"] }).notNull(),
    joinedAt: timestamp("joined_at", { withTimezone: true, precision: 3 }).notNull(),
    presence: text("presence", { enum: ["focus", "online", "away", "offline"] }),
    presenceAt: timestamp("presence_at", { withTimezone: true, precision: 3 }),
  },
  (t) => [index("guild_members_guild_idx").on(t.guildId)],
);

/** Invitations to a guild, waiting for a yes (GUILD_INVITE_DAYS at most). */
export const guildInvites = pgTable(
  "guild_invites",
  {
    guildId: uuid("guild_id").notNull().references(() => guilds.id, { onDelete: "cascade" }),
    userId: uuid("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
    invitedBy: uuid("invited_by").references(() => users.id, { onDelete: "set null" }),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [primaryKey({ columns: [t.guildId, t.userId] }), index("guild_invites_user_idx").on(t.userId)],
);

/** Each account's guild avatar (shared/src/guild.ts `Avatar`), and when it last left a guild (the wait before the next). */
export const avatars = pgTable("avatars", {
  userId: uuid("user_id").primaryKey().references(() => users.id, { onDelete: "cascade" }),
  avatar: jsonb("avatar").$type<import("@goblincamp/shared").Avatar>(),
  leftGuildAt: timestamp("left_guild_at", { withTimezone: true, precision: 3 }),
  updatedAt: timestamp("updated_at", { withTimezone: true, precision: 3 }).notNull(),
});

/** What was said in a guild hall (GUILD.md §3.1); kept a week. */
export const guildChat = pgTable(
  "guild_chat",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    guildId: uuid("guild_id").notNull().references(() => guilds.id, { onDelete: "cascade" }),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    text: text("text").notNull(),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [index("guild_chat_guild_idx").on(t.guildId, t.at)],
);

/** Gifts to a guild: who gave what, worth how much (the guild's ledger). */
export const guildDonations = pgTable(
  "guild_donations",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    guildId: uuid("guild_id").notNull().references(() => guilds.id, { onDelete: "cascade" }),
    userId: uuid("user_id").references(() => users.id, { onDelete: "set null" }),
    materials: jsonb("materials").$type<Record<string, number>>().notNull(),
    points: integer("points").notNull(),
    at: timestamp("at", { withTimezone: true, precision: 3 }).notNull(),
  },
  (t) => [index("guild_donations_guild_idx").on(t.guildId, t.at)],
);
