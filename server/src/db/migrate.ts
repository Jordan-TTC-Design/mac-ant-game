import { fileURLToPath } from "node:url";
import { migrate } from "drizzle-orm/postgres-js/migrator";
import type { Database } from "./client.ts";

const folder = fileURLToPath(new URL("../../drizzle", import.meta.url));

/** Brings the database up to the newest schema (the migrations in server/drizzle). Safe to run every start. */
export async function runMigrations(database: Database): Promise<void> {
  await migrate(database.db, { migrationsFolder: folder });
}
