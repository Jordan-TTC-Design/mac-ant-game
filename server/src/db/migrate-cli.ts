import { loadConfig } from "../config.ts";
import { createDatabase } from "./client.ts";
import { runMigrations } from "./migrate.ts";

const database = createDatabase(loadConfig().DATABASE_URL);
await runMigrations(database);
await database.close();
console.log("migrations done");
