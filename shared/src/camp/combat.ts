/**
 * What the camp fights with and what monsters leave behind (the Mac's character manifests and mac/Resources/Animals,
 * mac/Sources/GoblinCamp/Materials.swift). Only the server fights (raids and the big world); the Mac plays the result.
 */
import type { Resident as Fighter } from "../world/battle.ts";

/** A breed's fighting stats, per race (might and health as multiples of a plain goblin; speed ×). Missing = 1 / 3 / 1. */
export const BREED_STATS: Record<string, Record<string, { might?: number; health?: number; speed?: number }>> = {
  goblin: {
    common: {},
    scout: { speed: 1.35, might: 0.6, health: 2 },
    brute: { speed: 0.8, might: 1.6, health: 5 },
    sage: { speed: 0.95, might: 0.8 },
    golden: { speed: 1.1, might: 1.2, health: 4 },
    half_gob: { speed: 1, might: 1.15, health: 4 },
    half_mix: { speed: 1.05, might: 1, health: 3.5 },
    half_hum: { speed: 1, might: 0.9, health: 3 },
  },
  elf: {
    common: { might: 1.3, health: 3.5 },
    scout: { speed: 1.3, might: 1.2, health: 2.5 },
    brute: { speed: 0.8, might: 1.8, health: 6 },
    sage: { speed: 0.95, might: 1 },
    golden: { speed: 1.1, might: 1.5, health: 5 },
    half_gob: { speed: 1.05, might: 1.4, health: 4 },
    half_mix: { speed: 1.1, might: 1.5, health: 4.5 },
    half_hum: { speed: 1.05, might: 2, health: 7 },
  },
  undead: {
    common: { might: 1.1, health: 3 },
    scout: { speed: 1.4, might: 0.8, health: 2 },
    brute: { speed: 0.8, might: 1.7, health: 6 },
    sage: { speed: 1, might: 0.9, health: 2.5 },
    golden: { speed: 1.1, might: 1.5, health: 5 },
    half_gob: { speed: 1, might: 1.5, health: 5 },
    half_mix: { speed: 1.1, might: 1.4, health: 4 },
    half_hum: { speed: 1.2, might: 1.2, health: 3.5 },
  },
};

/** How a race fights as a whole (elves shoot from the back). */
export const RACE_RANGE: Record<string, number> = { goblin: 0, elf: 34, undead: 0 };

/** A resident as a fighter for the battle rules (world/battle.ts). */
export function residentAsFighter(race: string, resident: { id: number; breed: string }, name = ""): Fighter {
  const stats = BREED_STATS[race]?.[resident.breed] ?? {};
  return { id: String(resident.id), name, breed: resident.breed, might: stats.might ?? 1, health: stats.health ?? 3, speed: stats.speed ?? 1 };
}

export interface DropRule {
  id: string;
  chance: number;
  min: number;
  max: number;
}

/** What each camp monster may drop when it falls. */
export const MONSTER_DROPS: Record<string, DropRule[]> = {
  slime: [
    { id: "slime_goo", chance: 0.85, min: 1, max: 3 },
    { id: "slime_core", chance: 0.3, min: 1, max: 1 },
    { id: "elastic_gel", chance: 0.22, min: 1, max: 2 },
    { id: "shiny_bead", chance: 0.04, min: 1, max: 1 },
  ],
  giant_rat: [
    { id: "rat_fang", chance: 0.75, min: 1, max: 2 },
    { id: "rat_pelt", chance: 0.5, min: 1, max: 1 },
    { id: "rat_tail", chance: 0.3, min: 1, max: 1 },
    { id: "sharp_claw", chance: 0.15, min: 1, max: 1 },
    { id: "golden_fur", chance: 0.03, min: 1, max: 1 },
  ],
  bat: [
    { id: "bat_wing", chance: 0.65, min: 1, max: 2 },
    { id: "bat_fang", chance: 0.4, min: 1, max: 1 },
    { id: "night_dust", chance: 0.2, min: 1, max: 1 },
    { id: "night_heart", chance: 0.03, min: 1, max: 1 },
  ],
  frog: [
    { id: "frog_skin", chance: 0.7, min: 1, max: 2 },
    { id: "frog_leg", chance: 0.45, min: 1, max: 2 },
    { id: "sticky_tongue", chance: 0.25, min: 1, max: 1 },
    { id: "golden_frog_eye", chance: 0.03, min: 1, max: 1 },
  ],
};

/** Odds and ends any monster may leave besides its own drops. */
export const SCRAP_DROPS: DropRule[] = [
  { id: "scrap_rag", chance: 0.55, min: 1, max: 2 },
  { id: "scrap_wood", chance: 0.5, min: 1, max: 3 },
  { id: "scrap_iron", chance: 0.45, min: 1, max: 2 },
];
