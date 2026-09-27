// Copies the Mac app's art (every race's sprite sheets, the camp looks) and writes the names the phone shows
// (breeds, materials), so the phone shows the very same camp. public/sprites and public/camps are not in git.
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const resources = join(here, "../../mac/Resources");
const sprites = join(here, "../public/sprites");
const camps = join(here, "../public/camps");
const readJson = (path) => JSON.parse(readFileSync(path, "utf8"));

const names = { races: {}, materials: {} };
for (const race of ["goblin", "elf", "undead"]) {
  const from = join(resources, "Characters", race);
  const to = join(sprites, race);
  mkdirSync(to, { recursive: true });
  for (const file of readdirSync(from)) if (file.endsWith(".png")) copyFileSync(join(from, file), join(to, file));
  const manifest = readJson(join(from, "manifest.json"));
  names.races[race] = {
    name: manifest.name,
    nest: manifest.nestName,
    breeds: Object.fromEntries(manifest.breeds.map((b) => [b.id, b.name])),
    sheets: Object.fromEntries(manifest.breeds.map((b) => [b.id, b.sheet.replace(/\.png$/, "")])),
  };
}
// the goblin sheets stay where the notes' goblins look for them
for (const name of ["worker", "scout", "brute", "sage", "golden", "icon"]) copyFileSync(join(sprites, "goblin", `${name}.png`), join(sprites, `${name}.png`));

for (const id of readdirSync(join(resources, "Camps"))) {
  const from = join(resources, "Camps", id);
  if (!existsSync(join(from, "manifest.json"))) continue;
  mkdirSync(join(camps, id), { recursive: true });
  for (const file of readdirSync(from)) copyFileSync(join(from, file), join(camps, id, file));
}

// what monsters leave (mac/Resources/Animals) and the odds and ends in mac/Sources/GoblinCamp/Materials.swift
Object.assign(names.materials, { scrap_rag: "碎布", scrap_wood: "木片", scrap_iron: "廢鐵", crystal_shard: "碎晶" });
for (const id of readdirSync(join(resources, "Animals"))) {
  const path = join(resources, "Animals", id, "manifest.json");
  if (!existsSync(path)) continue;
  for (const drop of readJson(path).drops ?? []) names.materials[drop.id] ??= drop.name;
}
writeFileSync(join(sprites, "names.json"), JSON.stringify(names));
console.log("sprites copied");
