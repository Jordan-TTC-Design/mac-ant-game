/**
 * The ranch (DESKTOP.md §8): the player fences a pen in the camp window, drops the animals that wander in into it, and they
 * breed there. What they give is only earned while the camp is open on a Mac: the Mac says how many minutes it has been open
 * since it last said, and the server (which knows how much real time passed) gives the herd's yield for them.
 */

/** One animal in the pen. `bornAt` is when it was born there, or caught (a caught one is full-grown: see RANCH_GROWN_MINUTES). */
export interface RanchAnimal {
  id: number;
  kind: string;
  bornAt: string;
  /** Caught wild: full-grown from the start. */
  caught?: boolean;
  /** What the player called it. */
  name?: string;
}

export interface Ranch {
  animals: RanchAnimal[];
  /** When the Mac last reported (yields are counted from here). */
  syncedAt?: string;
  /** Fractions of a material not yet a whole one. */
  carry?: Record<string, number>;
}

/** What each kind gives an hour (full-grown, with the camp open), and what butchering one gives. */
export const RANCH_KINDS: Record<string, { name: string; perHour: Record<string, number>; butcher?: Record<string, number> }> = {
  sheep: { name: "羊", perHour: { scrap_rag: 0.4 } },
  chicken: { name: "雞", perHour: { feather: 0.3 } },
  pig: { name: "豬", perHour: {}, butcher: { food_meat: 3 } },
  deer: { name: "鹿", perHour: { bone_shard: 0.25 } }, // (the antlers it sheds)
  rabbit: { name: "兔子", perHour: { rabbit_fur: 0.3 } },
  // the elves' eagle: tamed on a perch, it brings back what it hunts
  eagle: { name: "老鷹", perHour: { feather: 0.2, rabbit_fur: 0.1 } },
  // the undead's bone beasts: put together from bones dug up
  bone_sheep: { name: "骨羊", perHour: { bone_shard: 0.4 } },
  bone_chicken: { name: "骨雞", perHour: { bone_shard: 0.25 } },
  bone_dog: { name: "骨犬", perHour: { bone_shard: 0.3 } },
  // and beasts' souls that drifted in, kept warm in a soul lamp
  soul_beast: { name: "獸魂", perHour: { ectoplasm: 0.3, night_dust: 0.15 } },
};

/** A young one is full-grown after this long (real time). */
export const RANCH_GROWN_MINUTES = 60;
/** The most animals a camp keeps, by its look (stage 1–3). The pens' own room is the Mac's to count. */
export const RANCH_CAP: Record<1 | 2 | 3, number> = { 1: 6, 2: 12, 3: 20 };
/** One report covers at most this many minutes (and never more than the real time since the last one). */
export const RANCH_MAX_MINUTES = 60;

export function ranchGrown(animal: RanchAnimal, now: Date): boolean {
  return animal.caught === true || now.getTime() - Date.parse(animal.bornAt) >= RANCH_GROWN_MINUTES * 60_000;
}

/** Why this herd cannot be the camp's (null: it can). Elves keep no pigs for meat, but may keep them. */
export function ranchProblem(animals: readonly RanchAnimal[], stage: 1 | 2 | 3): string | null {
  if (animals.length > RANCH_CAP[stage]) return `牧場最多養 ${RANCH_CAP[stage]} 隻（營地長大會變多）。`;
  const ids = new Set<number>();
  for (const a of animals) {
    if (!RANCH_KINDS[a.kind]) return "牧場不養這種動物。";
    if (ids.has(a.id)) return "牧場名單裡有重複的。";
    ids.add(a.id);
    if (Number.isNaN(Date.parse(a.bornAt))) return "牧場名單的日期不對。";
  }
  return null;
}

/**
 * What the full-grown ones give for `minutes` of the camp being open: whole materials, and the fractions carried on.
 * `minutes` should already be capped (RANCH_MAX_MINUTES and the real time since the last report).
 */
export function ranchYield(animals: readonly RanchAnimal[], minutes: number, now: Date, carry: Record<string, number> = {}): { gain: Record<string, number>; carry: Record<string, number> } {
  const total: Record<string, number> = { ...carry };
  for (const a of animals) {
    if (!ranchGrown(a, now)) continue;
    for (const [id, perHour] of Object.entries(RANCH_KINDS[a.kind]?.perHour ?? {})) total[id] = (total[id] ?? 0) + (perHour * minutes) / 60;
  }
  const gain: Record<string, number> = {};
  const left: Record<string, number> = {};
  for (const [id, n] of Object.entries(total)) {
    const whole = Math.floor(n + 1e-9);
    if (whole > 0) gain[id] = whole;
    if (n - whole > 1e-9) left[id] = n - whole;
  }
  return { gain, carry: left };
}
