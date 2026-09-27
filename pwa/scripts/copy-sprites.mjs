// Copies the goblin sprite sheets from the Mac app, so the phone shows the very same goblins (public/sprites is not in git).
import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const from = join(here, "../../mac/Resources/Characters/goblin");
const to = join(here, "../public/sprites");
mkdirSync(to, { recursive: true });
for (const name of ["worker", "scout", "brute", "sage", "golden", "icon"]) copyFileSync(join(from, `${name}.png`), join(to, `${name}.png`));
console.log("sprites copied");
