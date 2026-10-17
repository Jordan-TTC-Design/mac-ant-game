// Writes mac/Resources/World/names.json from the big world's rules (the Mac's own 大世界 page reads it: the names, icons and
// a few numbers it shows, so they are never typed twice). `world-names.test.ts` fails when the file is out of date.
import { writeFileSync } from "node:fs";
import { worldNames } from "./world-names.ts";

const file = new URL("../../mac/Resources/World/names.json", import.meta.url);
writeFileSync(file, JSON.stringify(worldNames(), null, 1) + "\n");
console.log("wrote", file.pathname);
