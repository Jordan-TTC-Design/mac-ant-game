/**
 * An expedition (WORLD.md §5): a party leaves its camp or cell, walks to a target cell, fights whatever holds it, and the
 * outcome is settled here: who fell, what it drops, the experience it earns, and what happens to the cell.
 *
 * The server calls `resolveExpedition` when the party arrives (its arrival time comes from `travelMinutes`), stores the result
 * with its seed, and sends it to both sides; the Macs play `battle.events` back.
 */
import { lairFighters, simulateBattle, type BattleResult, type FightBoosts, type Fighter, type RaceTraits, type Resident, residentFighter } from "./battle.ts";
import { lootFor, type Lair } from "./contents.ts";
import { XP } from "./leaderboard.ts";
import { seeded } from "./random.ts";
import { garrisonMin } from "./territory.ts";

export interface Party {
  player: string;
  residents: Resident[];
  race: RaceTraits;
  boosts?: FightBoosts;
}

export type Target =
  | { kind: "lair"; lair: Lair }
  | { kind: "player"; cell: string; defender: Party };

export interface ExpeditionOutcome {
  battle: BattleResult;
  won: boolean;
  /** What the attackers carry home (only if they won a lair). */
  loot: Record<string, number>;
  xp: { attacker: number; defender: number };
  /**
   * What becomes of the cell: a lair cleared (anyone may now settle it), a player's cell taken (its garrison is gone and
   * the survivors may settle it, if enough are left), or nothing.
   */
  cell: "cleared" | "taken" | "held";
  /** The attackers who may stay and settle the cell (at least their race's garrison minimum survived), if it was won. */
  canSettle: boolean;
}

export function resolveExpedition(options: { worldSeed: number; expeditionId: string; party: Party; target: Target; night?: boolean }): ExpeditionOutcome {
  const { party, target } = options;
  const attackers = party.residents.map((r) => residentFighter(r, "attack", party.race, party.boosts));
  const defenders: Fighter[] =
    target.kind === "lair" ? lairFighters(target.lair) : target.defender.residents.map((r) => residentFighter(r, "defend", target.defender.race, target.defender.boosts));
  const seed = seeded(options.worldSeed, options.expeditionId, "battle")() * 2 ** 32;
  const battle = simulateBattle(attackers, defenders, { seed: Math.floor(seed), night: options.night });
  const won = battle.winner === "attack";
  const loot = won && target.kind === "lair" ? lootFor(target.lair, seeded(options.worldSeed, options.expeditionId, "loot")) : {};
  const xp = {
    attacker: won ? (target.kind === "lair" ? XP.lairClearedPerLevel * target.lair.level : XP.playerWin) : 0,
    defender: !won && target.kind === "player" ? XP.playerWin / 2 : 0,
  };
  return {
    battle,
    won,
    loot,
    xp,
    cell: won ? (target.kind === "lair" ? "cleared" : "taken") : "held",
    canSettle: won && battle.standing.attack.length >= garrisonMin(party.race.id ?? "goblin"),
  };
}
