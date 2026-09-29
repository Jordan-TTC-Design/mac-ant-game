/**
 * Balance report: the 初期魔王 (world/contents.ts, server/WORLD.md §21) at each level against the parties a camp has by then:
 * the camp's own T0 gear, the first lairs' full kit, the first tier's best. Each cell: how often it is won and how many of
 * the party fall on average (60 fights). The aim: a full beginners' kit can take a level 2 with luck, the first tier's
 * best a level 3; a level 4 wants a bigger party or a second wave (its wounds stay).
 *
 *   cd shared && npm run balance:bosses
 */
import { residentAsFighter } from "../../src/camp/combat.ts";
import { RACE_RANGE } from "../../src/camp/index.ts";
import { combatPower, estimateBattle, lairFighters, LAIRS, residentFighter, type Lair } from "../../src/world/index.ts";
const KIT: Record<string, object> = {
  camp: { weapon: { id: "short_sword", left: 160 }, chest: { id: "leather_armor", left: 20 } },
  full: { weapon: { id: "slingshot", left: 100 }, chest: { id: "beetle_armor", left: 24 }, head: { id: "rabbit_cap", left: 14 }, hands: { id: "spine_gloves", left: 16 } },
  orc: { weapon: { id: "great_sword", left: 240 }, chest: { id: "iron_plate", left: 36 }, head: { id: "iron_helm", left: 30 } },
};
const party = (race: string, n: number, kit: string) => Array.from({ length: n }, (_, i) => residentFighter(residentAsFighter(race, { id: i + 1, breed: "common", gear: KIT[kit] as never }), "attack", { id: race, ranged: RACE_RANGE[race] ?? 0 }));
const setups: [string, string, number, string][] = [["哥布林8 T0", "goblin", 8, "camp"], ["哥布林10 新手全套", "goblin", 10, "full"], ["哥布林10 T1上", "goblin", 10, "orc"], ["精靈8 T1上", "elf", 8, "orc"], ["哥布林15 T1上", "goblin", 15, "orc"]];
console.log(`魔王 | 戰力 | ${setups.map((s) => s[0]).join(" | ")}`);
for (const k of LAIRS.filter((l) => l.boss)) for (const level of [2, 3, 4]) {
  const n = Math.round((k.group[0] + k.group[1]) / 2);
  const lair: Lair = { cell: "0:0", kind: k.id, name: k.name, faction: k.faction, level, foes: [k.leader!, ...Array(n - 1).fill(k.members[0]!.foe)], boss: true };
  const foes = lairFighters(lair);
  console.log(`${k.name} L${level} ×${n} | ${Math.round(combatPower(foes))} | ${setups.map(([, r, n2, kit]) => { const e = estimateBattle(party(r, n2, kit), foes, 60); return `${Math.round(e.win * 100)}%/${e.fallen.toFixed(1)}`; }).join(" | ")}`);
}
console.log(setups.map(([n, r, k, kit]) => `${n} ${Math.round(combatPower(party(r, k, kit)))}`).join("、"));
