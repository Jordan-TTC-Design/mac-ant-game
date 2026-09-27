import { GEAR } from "@goblincamp/shared/camp";
import { FOES } from "@goblincamp/shared/world";

/** The names the Mac shows, written by scripts/copy-sprites.mjs from the Mac's manifests (public/sprites/names.json). */
export interface ArtNames {
  races: Record<string, { name: string; nest: string; breeds: Record<string, string>; sheets: Record<string, string> }>;
  materials: Record<string, string>;
}

let loading: Promise<ArtNames> | null = null;
export function loadArtNames(): Promise<ArtNames> {
  loading ??= fetch("/sprites/names.json")
    .then((r) => r.json() as Promise<ArtNames>)
    .catch(() => {
      loading = null;
      return { races: {}, materials: {} };
    });
  return loading;
}

/** Each race's camp look on the phone (the Mac lets the player pick; these are the ones that fit the race). */
export const CAMP_LOOK: Record<string, string> = { goblin: "mound", elf: "stump", undead: "soultower" };

/** The Mac's Food.swift names. */
export const FOOD_NAMES: Record<string, string> = {
  water: "💧 清水",
  honey: "🍯 蜂蜜",
  bread: "🍞 麵包",
  meat: "🍖 烤肉",
  cheese: "🧀 起司",
  carrot: "🥕 胡蘿蔔",
  mushroom: "🍄 蘑菇",
  berries: "🫐 野莓",
  fish: "🐟 烤魚",
  cake: "🍰 蜂蜜蛋糕",
  soul_blue: "🔵 藍魂",
  soul_green: "🟢 綠魂",
  soul_purple: "🟣 紫魂",
};

export const gearName = (id: string) => GEAR.find((g) => g.id === id)?.name ?? id;
export const monsterName = (id: string) => FOES[id]?.name ?? id;
