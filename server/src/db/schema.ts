import { customType, pgTable, text, timestamp, uuid } from "drizzle-orm/pg-core";

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
