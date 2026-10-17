// What the Mac's own 大世界 page needs to know from the big world's rules (mac/Resources/World/names.json, written by
// write-world-names.ts): names, icons and a few numbers. The Mac does no fighting or walking sums of its own (the server's
// POST world/expeditions/plan answers those), only shows.
import {
  BOOST_FOODS,
  BOOST_ITEMS,
  BOSS_MIN_RACE_LEVEL,
  CELL_BUILDINGS,
  CELL_METERS,
  DETAIL_BUILDINGS,
  DETAIL_HOME_ATTACK,
  DETAIL_NAMES,
  DETAIL_YIELD,
  FOES,
  GUESTS_MAX,
  HEX_RADIUS,
  HOME_MOVE_DAYS,
  HUBS,
  LANDMARKS,
  MAX_TRAVEL_MINUTES,
  MINUTES_PER_KM,
  MATERIALS,
  RATIONS,
  RATIONS_PER_EXTRA,
  REGION_TRAVEL,
  ROW_METERS,
  SETOUT_MINUTES,
  TALENT_ABILITIES,
  TERRAIN_DETAILS,
  TERRAIN_NAMES,
  TERRAIN_YIELD,
  cellBuildingName,
  detailHome,
  hubName,
  type HubKind,
} from "../src/world/index.ts";

const RACES = ["goblin", "elf", "undead"] as const;
const byRace = (name: (race: string) => string) => Object.fromEntries(RACES.map((r) => [r, name(r)]));

export function worldNames() {
  const kinds = [...new Set([...CELL_BUILDINGS.map((b) => b.kind), ...DETAIL_BUILDINGS.map((b) => b.kind)])].sort();
  return {
    grid: { rowMeters: ROW_METERS, cellMeters: CELL_METERS, hexRadius: HEX_RADIUS },
    /** territory.ts walkMinutes: a plain walk, for the cell card's first guess (the dispatch sheet asks the server). */
    walk: { setOutMinutes: SETOUT_MINUTES, minutesPerKm: MINUTES_PER_KM, maxMinutes: MAX_TRAVEL_MINUTES, regionTravel: REGION_TRAVEL },
    rules: {
      bossMinRaceLevel: BOSS_MIN_RACE_LEVEL,
      guestsMax: GUESTS_MAX,
      homeMoveDays: HOME_MOVE_DAYS,
      rationsPerExtra: RATIONS_PER_EXTRA,
      detailHomeAttack: DETAIL_HOME_ATTACK,
      raidShare: TALENT_ABILITIES.raidShare,
      raidCap: TALENT_ABILITIES.raidCap,
      raidTotal: TALENT_ABILITIES.raidTotal,
    },
    terrains: TERRAIN_NAMES,
    terrainYield: Object.fromEntries(Object.entries(TERRAIN_YIELD).map(([t, ys]) => [t, ys.map((y) => y.id)])),
    details: Object.fromEntries(
      TERRAIN_DETAILS.map((d) => [d, { ...DETAIL_NAMES[d], yields: DETAIL_YIELD[d].map((y) => y.id), home: RACES.filter((r) => detailHome(d, r)) }]),
    ),
    landmarks: LANDMARKS.map((l) => ({ kind: l.kind, name: l.name, icon: l.icon, blurb: l.blurb })),
    hubs: HUBS.map((h) => ({ kind: h.kind, blurb: h.blurb, name: byRace((r) => hubName(h.kind as HubKind, r)) })),
    buildings: Object.fromEntries(kinds.map((k) => [k, byRace((r) => cellBuildingName(k, r))])),
    foes: Object.fromEntries(Object.values(FOES).map((f) => [f.id, { name: f.name, hp: f.hp }])),
    materials: Object.fromEntries(Object.entries(MATERIALS).map(([id, m]) => [id, m.name])),
    rations: Object.keys(RATIONS),
    boosts: [
      ...Object.entries(BOOST_FOODS).map(([id, f]) => ({ id, name: f.name, what: f.what, item: false })),
      ...Object.entries(BOOST_ITEMS).map(([id, f]) => ({ id, name: f.name, what: f.what, item: true })),
    ],
  };
}
