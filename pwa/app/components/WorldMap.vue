<script setup lang="ts">
import { Map as MapLibre, Marker, setWorkerUrl, type GeoJSONSource } from "maplibre-gl";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url";
import type { FeatureCollection } from "geojson";
import "maplibre-gl/dist/maplibre-gl.css";
import { alongRoute, cellAt, HEX_RADIUS, landmarkRule, type CellView } from "@goblincamp/shared/world";

// The big world on the real map (OpenStreetMap, in the game's colours: utils/mapStyle.ts), drawn at a low resolution and
// scaled up with sharp pixels. Only the cell picked and the held ones are outlined (yours yellow, others' red); each lair
// shows its strongest monster and level, each held cell its race and how many live there; a camp's home and its towns
// stand as a building (a camp, a castle) flying the race's flag.
// Drag and pinch to look around; tap a cell.
const props = defineProps<{
  cells: CellView[];
  center: { lat: number; lng: number };
  mine: string | null;
  selected: string | null;
  walkingTo: string[];
  /** Parties on the road (the cell centres it walks between, round other camps' land, and when): a dashed line with the party moving along it. */
  parties?: { id: string; path: { lat: number; lng: number }[]; setOutAt: string; arriveAt: string; race: string; hostile?: boolean }[];
  /** Cells to mark ⚔️: attacked lately, or about to be. */
  alerts?: string[];
  /** The race whose face is on the "back to my camp" button (none: no camp yet, no button). */
  home?: string | null;
  /** The way a party would walk to the cell picked (before it is sent): a yellow dotted line. */
  plan?: { lat: number; lng: number }[] | null;
}>();
const emit = defineEmits<{ select: [cell: string]; pan: [center: { lat: number; lng: number }]; home: [] }>();

// (MapLibre does the tiles' work in a worker of its own, a separate file the bundler has to be told about: bundled whole,
// since the file in the package imports a second one next to it that a plain copy would leave behind)
setWorkerUrl(workerUrl);

/** How coarse the map's pixels are: it is drawn at this share of the screen's resolution and scaled up. */
const PIXEL_RATIO = 0.5;
const R = HEX_RADIUS; // a pointy-top hexagon, CELL_METERS wide (shared/src/world/grid.ts)
/** Outlines are drawn a little inside the cell, so two outlined neighbours sit side by side instead of overlapping. */
const DRAWN = 0.9;

const box = ref<HTMLDivElement>();
let map: MapLibre | null = null;
let ready = false;
/** The icon over each cell that has one, and what it showed (only the ones that change are made again). */
const markers = new Map<string, { key: string; marker: Marker }>();
const partyMarkers = new Map<string, Marker>();
const foeSheet = useFoeSheet();

function hexRing(lat: number, lng: number): [number, number][] {
  const mLat = 110_574, mLng = 111_320 * Math.cos((lat * Math.PI) / 180);
  const ring: [number, number][] = [];
  for (let k = 0; k <= 6; k++) {
    const a = ((60 * k + 30) * Math.PI) / 180;
    ring.push([lng + (R * DRAWN * Math.cos(a)) / mLng, lat - (R * DRAWN * Math.sin(a)) / mLat]);
  }
  return ring;
}

function cellsGeoJson(): FeatureCollection {
  return {
    type: "FeatureCollection",
    features: props.cells.map((c) => ({
      type: "Feature",
      // (the cell picked and those walked to are feature states: picking one does not send every cell again)
      properties: {
        cell: c.cell,
        state: c.owner ? (c.owner.id === props.mine ? "mine" : "theirs") : c.boss ? "boss" : "free",
        blocks: !!c.blocks,
      },
      geometry: { type: "Polygon", coordinates: [hexRing(c.lat, c.lng)] },
    })),
  };
}

function partiesGeoJson(): FeatureCollection {
  return {
    type: "FeatureCollection",
    features: (props.parties ?? []).map((p) => ({
      type: "Feature",
      properties: { id: p.id, hostile: !!p.hostile },
      geometry: { type: "LineString", coordinates: p.path.map((q) => [q.lng, q.lat]) },
    })),
  };
}

/** A foe's icon as a small element (from the foes' sheet), `size` points square. */
function foeElement(id: string, size: number): HTMLElement {
  const el = document.createElement("span");
  const s = foeSheet.value;
  const at = iconAt(s, id);
  if (s && at) {
    Object.assign(el.style, {
      display: "block",
      width: `${size}px`,
      height: `${size}px`,
      backgroundImage: "url(/world/foes.png)",
      backgroundSize: `${s.cols * size}px ${at.rows * size}px`,
      backgroundPosition: `-${at.col * size}px -${at.row * size}px`,
      imageRendering: "pixelated",
    });
  }
  return el;
}

function label(text: string, cls = ""): HTMLElement {
  const el = document.createElement("span");
  el.className = `map-label ${cls}`;
  el.textContent = text;
  return el;
}

/** Each race's flag, and the walls and roof its buildings are made of. */
const RACE_LOOK: Record<string, { flag: string; wall: string; roof: string; stone: string }> = {
  goblin: { flag: "#5fb030", wall: "#8a5a32", roof: "#5e7a2a", stone: "#9a8a70" },
  elf: { flag: "#3aa0e0", wall: "#e8dcc0", roof: "#3f8f5a", stone: "#e6e0d0" },
  undead: { flag: "#9a50d0", wall: "#4a4458", roof: "#2a2638", stone: "#5a5468" },
};

/**
 * A camp's home (a hut) or a town (a castle) in pixels, 24 by 24 (the flag above), with a flag in the race's colour bearing its face on
 * top (the flag sways: .map-flag). Outlined by drawing each part a pixel bigger in black first.
 */
/** What a camp's home looks like by its race level (2026-10-17): a hut, a stockade (Lv5), a stone keep (Lv10), a citadel (Lv20). */
const homeTier = (level = 1) => (level >= 20 ? 3 : level >= 10 ? 2 : level >= 5 ? 1 : 0);

function buildingSvg(kind: "home" | "town", race: string, level = 1): string {
  const look = RACE_LOOK[race] ?? RACE_LOOK.goblin!;
  const ink = "#1f1f1f";
  const box = (x: number, y: number, w: number, h: number, fill: string) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${fill}"/>`;
  const castle: [number, number, number, number, string][] = [
    [2, 9, 6, 14, look.stone], [16, 9, 6, 14, look.stone], [7, 13, 10, 10, look.stone], // towers and the wall
    [2, 7, 2, 2, look.stone], [6, 7, 2, 2, look.stone], [16, 7, 2, 2, look.stone], [20, 7, 2, 2, look.stone], // merlons
    [8, 11, 2, 2, look.stone], [14, 11, 2, 2, look.stone],
  ];
  const tier = kind === "home" ? homeTier(level) : -1;
  const parts: [number, number, number, number, string][] =
    kind === "town" ? castle
    : tier === 3 ? [...castle.filter(([, y]) => y !== 11), [9, 6, 6, 17, look.stone], [9, 4, 2, 2, look.stone], [13, 4, 2, 2, look.stone]] // a tall keep between the towers
    : tier === 2 ? [[6, 10, 12, 13, look.stone], [6, 8, 2, 2, look.stone], [10, 8, 4, 2, look.stone], [16, 8, 2, 2, look.stone]] // a square keep
    : [[5, 16, 14, 7, look.wall]];
  const outline = parts.map(([x, y, w, h]) => box(x - 1, y - 1, w + 2, h + 2, ink)).join("");
  const body = parts.map(([x, y, w, h, fill]) => box(x, y, w, h, fill)).join("");
  const stakes = [1, 4, 7, 15, 18, 21].map((x) => box(x - 1, 18, 3, 6, ink) + box(x, 19, 1, 5, look.wall)).join(""); // (a stockade)
  const details =
    kind === "town" ? box(10, 17, 4, 6, ink) + box(11, 16, 2, 1, ink) + box(4, 12, 2, 2, ink) + box(18, 12, 2, 2, ink)
    : tier === 3 ? box(10, 17, 4, 6, ink) + box(11, 16, 2, 1, ink) + box(4, 12, 2, 2, ink) + box(18, 12, 2, 2, ink) + box(11, 10, 2, 3, ink)
    : tier === 2 ? box(10, 17, 4, 6, ink) + box(11, 16, 2, 1, ink) + box(8, 12, 2, 2, ink) + box(14, 12, 2, 2, ink)
    : `<polygon points="2,17 12,7 22,17" fill="${ink}"/><polygon points="4,16 12,8.5 20,16" fill="${look.roof}"/>` + box(10, 18, 4, 5, ink) + (tier === 1 ? stakes : "");
  const top = kind === "town" ? 11 : tier === 3 ? 4 : tier === 2 ? 8 : 8; // where the pole meets the building
  // a star on the flag for every five levels (up to four)
  const stars = kind === "home" ? Array.from({ length: Math.min(4, Math.floor(level / 5)) }, (_, i) => box(19, -5 + i * 1.25, 1, 1, "#ffe27a")).join("") : "";
  const flag = // (on a pole above the building: drawn from y −6)
    box(11, -6, 1, top + 6, ink) +
    `<g class="map-flag">${box(12, -6, 9, 7, ink)}${box(12, -5, 8, 5, look.flag)}` +
    `<image href="/sprites/${race}/icon.png" x="13" y="-5" width="5" height="5" style="image-rendering:pixelated"/>${stars}</g>`;
  return `<svg viewBox="0 -6 24 30" width="40" height="50" shape-rendering="crispEdges" xmlns="http://www.w3.org/2000/svg">${outline}${body}${details}${flag}</svg>`;
}

/** What a cell's icon shows, as a key: the icon is made again only when this changes. */
function markerKey(c: CellView): string {
  return JSON.stringify([
    c.owner && [c.owner.id === props.mine, c.owner.race, c.garrison, c.town, c.home, c.nest, c.home ? homeTier(c.owner.level) : 0, c.home ? Math.min(4, Math.floor((c.owner.level ?? 1) / 5)) : 0],
    c.boss && [c.boss.kind, Math.round((100 * c.boss.hp) / c.boss.maxHp)],
    c.lair && [c.lair.kind, c.lair.level, c.lair.boss, leaderOf(c.lair.foes)],
    c.landmark?.kind,
    !!foeSheet.value,
    props.alerts?.includes(c.cell),
  ]);
}

/** A cell's icon (null: nothing to show there). */
function cellMarker(c: CellView): HTMLElement | null {
  const el = document.createElement("div");
  el.className = "map-cell";
  if (c.owner && (c.home || c.town)) {
    const building = document.createElement("span");
    building.className = "map-building";
    building.innerHTML = buildingSvg(c.home ? "home" : "town", c.owner.race, c.owner.level);
    el.append(building, label(`${c.garrison}${c.home ? " 營地" : " 城"}`, c.owner.id === props.mine ? "mine" : "theirs"));
  } else if (c.owner) {
    const face = document.createElement("img");
    face.src = `/sprites/${c.owner.race}/icon.png`;
    face.className = "map-face";
    el.append(face, label(`${c.garrison}${c.town ? " 城" : c.nest !== "none" ? " 巢" : ""}`, c.owner.id === props.mine ? "mine" : "theirs"));
  } else if (c.boss) {
    const hp = document.createElement("span");
    hp.className = "map-hp";
    hp.innerHTML = `<i style="width:${Math.max(0, (100 * c.boss.hp) / c.boss.maxHp)}%"></i>`;
    el.append(foeElement(c.boss.kind, 36), hp);
  } else if (c.lair) {
    const icon = c.lair.kind === "enemy_town" ? "enemy_town" : leaderOf(c.lair.foes);
    el.append(foeElement(icon, c.lair.boss ? 30 : 22), label(`${c.lair.boss ? "👑 " : ""}Lv${c.lair.level}`, c.lair.boss ? "boss" : ""));
  } else if (!c.landmark && !props.alerts?.includes(c.cell)) {
    return null;
  }
  // attacked lately, or a party on its way to attack it
  if (props.alerts?.includes(c.cell)) {
    const alert = document.createElement("span");
    alert.className = el.childElementCount ? "map-alert corner" : "map-alert";
    alert.textContent = "⚔️";
    el.append(alert);
  }
  // a real place standing in it (a station, a temple…): a small mark in the corner
  if (c.landmark) {
    const mark = document.createElement("span");
    mark.className = el.childElementCount ? "map-landmark corner" : "map-landmark";
    mark.textContent = landmarkRule(c.landmark.kind)?.icon ?? "📍";
    el.append(mark);
  }
  return el;
}

/**
 * The icons over the cells (a few hundred in view): only those whose cell changed are made again, the rest stay where
 * they are (making them all again on every change made each tap on the map stutter).
 */
function drawMarkers() {
  if (!map) return;
  const seen = new Set<string>();
  for (const c of props.cells) {
    const key = markerKey(c);
    const known = markers.get(c.cell);
    seen.add(c.cell);
    if (known?.key === key) continue;
    known?.marker.remove();
    markers.delete(c.cell);
    const el = cellMarker(c);
    if (el) markers.set(c.cell, { key, marker: new Marker({ element: el, anchor: "center" }).setLngLat([c.lng, c.lat]).addTo(map) });
  }
  for (const [cell, { marker }] of markers) {
    if (seen.has(cell)) continue;
    marker.remove();
    markers.delete(cell);
  }
}

function planGeoJson(): FeatureCollection {
  const path = props.plan ?? [];
  return {
    type: "FeatureCollection",
    features: path.length > 1 ? [{ type: "Feature", properties: {}, geometry: { type: "LineString", coordinates: path.map((q) => [q.lng, q.lat]) } }] : [],
  };
}

/** The cells came anew (or whose they are): their shapes and icons. */
function refreshCells() {
  if (!map || !ready) return;
  (map.getSource("cells") as GeoJSONSource | undefined)?.setData(cellsGeoJson());
  drawMarkers();
  marked.clear(); // (the shapes were sent again: mark the picked and walked-to cells afresh)
  markCells();
}

/** Cells drawn as picked or walked to now (feature states), so only what changed is told to the map. */
const marked = new Map<string, { selected: boolean; target: boolean }>();
function markCells() {
  if (!map || !ready) return;
  const want = new Map<string, { selected: boolean; target: boolean }>();
  for (const cell of props.walkingTo) want.set(cell, { selected: false, target: true });
  if (props.selected) want.set(props.selected, { selected: true, target: props.walkingTo.includes(props.selected) });
  for (const cell of marked.keys()) if (!want.has(cell)) map.setFeatureState({ source: "cells", id: cell }, { selected: false, target: false });
  for (const [cell, state] of want) {
    const was = marked.get(cell);
    if (was?.selected !== state.selected || was?.target !== state.target) map.setFeatureState({ source: "cells", id: cell }, state);
  }
  marked.clear();
  for (const [cell, state] of want) marked.set(cell, state);
}

function refreshRoads() {
  if (!map || !ready) return;
  (map.getSource("plan") as GeoJSONSource | undefined)?.setData(planGeoJson());
  (map.getSource("parties") as GeoJSONSource | undefined)?.setData(partiesGeoJson());
  moveParties();
}

/** The parties' little faces, where along the road they are by now. */
function moveParties() {
  if (!map) return;
  const now = Date.now();
  const live = new Set<string>();
  for (const p of props.parties ?? []) {
    live.add(p.id);
    const t0 = Date.parse(p.setOutAt), t1 = Date.parse(p.arriveAt);
    const k = Math.min(1, Math.max(0, (now - t0) / Math.max(1, t1 - t0)));
    const here = alongRoute(p.path, k);
    const at: [number, number] = [here.lng, here.lat];
    const known = partyMarkers.get(p.id);
    if (known) {
      known.setLngLat(at);
      continue;
    }
    const face = document.createElement("img");
    face.src = `/sprites/${p.race}/icon.png`;
    face.className = p.hostile ? "map-face party hostile" : "map-face party";
    partyMarkers.set(p.id, new Marker({ element: face }).setLngLat(at).addTo(map));
  }
  for (const [id, m] of partyMarkers) {
    if (!live.has(id)) {
      m.remove();
      partyMarkers.delete(id);
    }
  }
}

/** The kinds of places worth suggesting as somewhere to start (OpenMapTiles' poi classes), in groups. */
const PLACE_GROUPS: Record<string, "park" | "sight" | "station" | "campus"> = {
  park: "park", garden: "park", zoo: "sight", attraction: "sight", museum: "sight", stadium: "sight", castle: "sight", monument: "sight",
  theatre: "sight", railway: "station", college: "campus",
};
/** How the five suggestions are made up: the nearest of each group in this order (a group with none is skipped). */
const PLACE_ORDER = ["station", "park", "sight", "park", "sight", "campus", "park", "sight"] as const;

/**
 * Named places round a point, within 3 km: the nearest parks, sights, a station and a campus, up to five, read from the map's
 * own tiles once they are there, so where the person is never leaves the phone. Two suggestions are never within 300 m of
 * each other (not five corners of one campus).
 */
async function placesNear(at: { lat: number; lng: number }): Promise<{ name: string; lat: number; lng: number; km: number }[]> {
  const m = map;
  if (!m) return [];
  // (the map settles once its tiles are in; if they never come, give up after 10 s rather than wait for ever)
  if (!m.loaded() || !m.areTilesLoaded()) await new Promise<void>((done) => {
    m.once("idle", () => done());
    setTimeout(done, 10_000);
  });
  const mLng = 111.32 * Math.cos((at.lat * Math.PI) / 180);
  const kmBetween = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => Math.hypot((a.lat - b.lat) * 110.574, (a.lng - b.lng) * mLng);
  type Place = { name: string; lat: number; lng: number; km: number };
  const groups: Record<string, Map<string, Place>> = { park: new Map(), sight: new Map(), station: new Map(), campus: new Map() };
  for (const f of m.querySourceFeatures("osm", { sourceLayer: "poi" })) {
    const group = PLACE_GROUPS[String(f.properties.class)];
    let name = f.properties.name;
    if (!group || typeof name !== "string" || !name.trim() || f.geometry.type !== "Point") continue;
    if (group === "park" && name.length < 3) continue; // ("草地": a lawn, not a place)
    if (group === "station") {
      if (!["station", "subway"].includes(String(f.properties.subclass))) continue;
      if (!/站|Station$/i.test(name)) name += "站"; // (stations are named bare: 中山 → 中山站)
    }
    const [lng, lat] = f.geometry.coordinates as [number, number];
    const km = kmBetween({ lat, lng }, at);
    if (km > 3) continue;
    const had = groups[group]!.get(name);
    if (!had || km < had.km) groups[group]!.set(name, { name, lat, lng, km });
  }
  const queues = Object.fromEntries(Object.entries(groups).map(([g, list]) => [g, [...list.values()].sort((a, b) => a.km - b.km)]));
  const chosen: Place[] = [];
  for (const group of PLACE_ORDER) {
    const queue = queues[group]!;
    while (queue.length) {
      const p = queue.shift()!;
      if (chosen.some((c) => c.name === p.name || kmBetween(c, p) < 0.3)) continue;
      chosen.push(p);
      break;
    }
    if (chosen.length === 5) break;
  }
  return chosen.sort((a, b) => a.km - b.km);
}
/** Where the map is looking right now (the page's center lags a drag by up to 300 m). */
function viewCenter(): { lat: number; lng: number } {
  const c = map?.getCenter();
  return c ? { lat: c.lat, lng: c.lng } : props.center;
}
defineExpose({ placesNear, viewCenter });

let ticking: ReturnType<typeof setInterval> | undefined;
onMounted(() => {
  const m = new MapLibre({
    container: box.value!,
    style: gameMapStyle(),
    center: [props.center.lng, props.center.lat],
    zoom: 14.2,
    minZoom: 12.5,
    maxZoom: 17.5,
    pixelRatio: PIXEL_RATIO,
    attributionControl: { compact: true },
    dragRotate: false,
    pitchWithRotate: false,
  });
  map = m;
  if (import.meta.dev) (window as unknown as { worldMap: MapLibre }).worldMap = m; // (to look at it from the console)
  m.touchZoomRotate.disableRotation();
  m.on("load", () => {
    m.addSource("cells", { type: "geojson", data: cellsGeoJson(), promoteId: "cell" });
    m.addSource("parties", { type: "geojson", data: partiesGeoJson() });
    m.addSource("plan", { type: "geojson", data: planGeoJson() });
    m.addLayer({
      id: "cell-fill",
      type: "fill",
      source: "cells",
      paint: {
        "fill-color": ["match", ["get", "state"], "mine", "#ffd84a", "theirs", "#e04a3a", "boss", "#ff3a2a", "#000000"],
        "fill-opacity": ["match", ["get", "state"], "mine", 0.14, "theirs", 0.12, "boss", 0.14, 0],
      },
    });
    m.addLayer({
      id: "cell-line",
      type: "line",
      source: "cells",
      // (no outline for free cells: only the one picked, and held ones; the real map shows through clean)
      paint: {
        "line-color": ["case", ["boolean", ["feature-state", "selected"], false], "#ffffff", ["match", ["get", "state"], "mine", "#ffd84a", "theirs", "#e04a3a", "#ff3a2a"]],
        "line-width": ["case", ["boolean", ["feature-state", "selected"], false], 3, 2.5],
        "line-opacity": ["case", ["boolean", ["feature-state", "selected"], false], 1, ["==", ["get", "state"], "free"], 0, 1],
      },
    });
    // someone else's built-up land: parties must walk round it (shared/src/world/route.ts), so it reads as a wall
    m.addLayer({ id: "cell-wall", type: "fill", source: "cells", filter: ["get", "blocks"], paint: { "fill-color": "#7a1a10", "fill-opacity": 0.32 } });
    m.addLayer({ id: "cell-wall-line", type: "line", source: "cells", filter: ["get", "blocks"], paint: { "line-color": "#5a0f08", "line-width": 4 } });
    m.addLayer({
      id: "cell-target",
      type: "line",
      source: "cells",
      paint: { "line-color": "#ffffff", "line-width": 2, "line-dasharray": [2, 1.5], "line-opacity": ["case", ["boolean", ["feature-state", "target"], false], 1, 0] },
    });
    // (parties coming to attack this camp in red)
    m.addLayer({
      id: "party-road",
      type: "line",
      source: "parties",
      paint: { "line-color": ["case", ["get", "hostile"], "#ff3a2a", "#ffffff"], "line-width": ["case", ["get", "hostile"], 4, 3], "line-dasharray": [2, 1.5], "line-opacity": 0.9 },
    });
    m.addLayer({ id: "plan-road", type: "line", source: "plan", layout: { "line-cap": "round" }, paint: { "line-color": "#f3d36b", "line-width": 4, "line-dasharray": [0.1, 2] } });
    ready = true;
    refreshCells();
    refreshRoads();
    // the credits (OpenStreetMap's licence asks for them) start folded into the little (i), so they do not cover the map
    box.value?.querySelector(".maplibregl-ctrl-attrib")?.classList.remove("maplibregl-compact-show");
  });
  m.on("click", (e) => emit("select", cellAt({ lat: e.lngLat.lat, lng: e.lngLat.lng })));
  m.on("moveend", () => {
    const c = m.getCenter();
    if (Math.hypot((c.lat - props.center.lat) * 110_574, (c.lng - props.center.lng) * 100_000) > 300) emit("pan", { lat: c.lat, lng: c.lng });
  });
  ticking = setInterval(moveParties, 1000);
});
onUnmounted(() => {
  clearInterval(ticking);
  map?.remove();
  map = null;
});

// each kind of change redraws only its own part (a tap on a cell changes only which one is outlined)
watch(() => [props.cells, props.mine, foeSheet.value, props.alerts], refreshCells);
watch(() => [props.selected, props.walkingTo], markCells);
watch(() => [props.parties, props.plan], refreshRoads);
// the page moves the map (to the camp, to a great monster): fly there if it is not where we are looking already
watch(
  () => props.center,
  (c) => {
    if (!map) return;
    const now = map.getCenter();
    if (Math.hypot((now.lat - c.lat) * 110_574, (now.lng - c.lng) * 100_000) > 150) map.easeTo({ center: [c.lng, c.lat], duration: 600 });
  },
);
</script>

<template>
  <div class="wrap">
    <div ref="box" class="map" />
    <button v-if="home" class="home" aria-label="回到我的營地" title="回到我的營地" @click="emit('home')">
      <img :src="`/sprites/${home}/icon.png`" class="pixel" alt="" />
    </button>
  </div>
</template>

<style scoped>
.wrap { position: relative; }
.home {
  position: absolute; top: 10px; right: 10px; z-index: 2; width: 42px; height: 42px; border-radius: 50%; border: 3px solid #1f1f1f;
  background: var(--card); box-shadow: 2px 2px 0 #1f1f1f; display: grid; place-items: center; cursor: pointer; padding: 0;
}
.home img { width: 26px; height: 26px; }
.map { width: 100%; aspect-ratio: 1 / 1.1; border-radius: 14px; border: 3px solid #1f1f1f; overflow: hidden; background: #cdbf8a; }
.map :deep(canvas) { image-rendering: pixelated; }
.map :deep(.map-cell) { display: grid; justify-items: center; pointer-events: none; }
.map :deep(.map-building) { display: block; width: 40px; height: 50px; margin-top: -10px; filter: drop-shadow(0 1px 0 rgba(0, 0, 0, 0.35)); }
.map :deep(.map-building svg) { display: block; overflow: visible; }
.map :deep(.map-flag) { transform-box: fill-box; transform-origin: left center; animation: map-flag 1.6s ease-in-out infinite alternate; }
@keyframes map-flag { from { transform: skewY(-6deg) scaleX(0.94); } to { transform: skewY(5deg) scaleX(1); } }
@media (prefers-reduced-motion: reduce) { .map :deep(.map-flag) { animation: none; } }
.map :deep(.map-face) { width: 22px; height: 22px; image-rendering: pixelated; pointer-events: none; }
.map :deep(.map-face.party) { width: 22px; height: 22px; filter: drop-shadow(0 0 2px #fff); }
.map :deep(.map-face.party.hostile) { filter: drop-shadow(0 0 2px #ff3a2a) drop-shadow(0 0 2px #ff3a2a); }
.map :deep(.map-alert) { font-size: 15px; line-height: 1; filter: drop-shadow(0 0 2px #fff); animation: map-alert 1s ease-in-out infinite alternate; }
.map :deep(.map-alert.corner) { position: absolute; top: -10px; left: -12px; font-size: 13px; }
@keyframes map-alert { from { transform: scale(1); } to { transform: scale(1.25); } }
@media (prefers-reduced-motion: reduce) { .map :deep(.map-alert) { animation: none; } }
.map :deep(.map-label) { margin-top: -2px; font-size: 10px; font-weight: 800; color: #fff; text-shadow: 0 0 2px #000, 0 0 2px #000; line-height: 1; }
.map :deep(.map-label.mine) { color: #ffe27a; }
.map :deep(.map-label.theirs) { color: #ff9a8a; }
.map :deep(.map-label.boss) { color: #ffd84a; }
.map :deep(.map-landmark) { font-size: 15px; line-height: 1; filter: drop-shadow(0 0 1px #fff); }
/* (the marker itself is absolutely placed by the map, so the corner mark sits against it) */
.map :deep(.map-landmark.corner) { position: absolute; top: -8px; right: -12px; font-size: 12px; }
.map :deep(.map-hp) { display: block; width: 44px; height: 6px; margin-top: 1px; background: rgba(0, 0, 0, 0.55); border-radius: 3px; overflow: hidden; }
.map :deep(.map-hp i) { display: block; height: 100%; background: #ff4a3a; }
</style>
