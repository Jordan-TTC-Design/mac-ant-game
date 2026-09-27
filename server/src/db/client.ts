import { drizzle } from "drizzle-orm/postgres-js";
import postgres from "postgres";
import * as schema from "./schema.ts";

export type Database = ReturnType<typeof createDatabase>;

export function createDatabase(url: string) {
  const sql = postgres(url, { max: 10, onnotice: () => {} });
  const db = drizzle(sql, { schema });
  return {
    db,
    sql,
    /** Whether the database answers (for /api/health). */
    async ping(): Promise<boolean> {
      try {
        await sql`select 1`;
        return true;
      } catch {
        return false;
      }
    },
    close: () => sql.end({ timeout: 5 }),
  };
}
