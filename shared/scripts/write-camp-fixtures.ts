// Writes src/camp/fixtures.json from the current rules (see src/camp/fixtures.ts).
import { writeFileSync } from "node:fs";
import { buildFixtures } from "../src/camp/fixtures.ts";

const file = new URL("../src/camp/fixtures.json", import.meta.url);
writeFileSync(file, JSON.stringify(buildFixtures(), null, 2) + "\n");
console.log("wrote", file.pathname);
