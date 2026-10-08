// Writes src/guild-hall-fixtures.json from the current rules (see src/guild-hall-fixtures.ts).
import { writeFileSync } from "node:fs";
import { buildGuildHallFixtures } from "../src/guild-hall-fixtures.ts";

const file = new URL("../src/guild-hall-fixtures.json", import.meta.url);
writeFileSync(file, JSON.stringify(buildGuildHallFixtures(), null, 2) + "\n");
console.log("wrote", file.pathname);
