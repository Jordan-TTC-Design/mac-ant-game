<script setup lang="ts">
import { Map as MapLibre, Marker, setWorkerUrl, type GeoJSONSource } from "maplibre-gl";
import workerUrl from "maplibre-gl/dist/maplibre-gl-worker.mjs?worker&url";
import type { FeatureCollection } from "geojson";
import "maplibre-gl/dist/maplibre-gl.css";
import { cellAt, HEX_RADIUS, type CellView } from "@goblincamp/shared/world";

// The big world on the real map (OpenStreetMap, in the game's colours: utils/mapStyle.ts), drawn at a low resolution and
// scaled up with sharp pixels. Only the cell picked and the held ones are outlined (yours yellow, others' red); each lair
// shows its strongest monster and level, each held cell its race and how many live there.
// Drag and pinch to look around; tap a cell.
const props = defineProps<{
  cells: CellView[];
  center: { lat: number; lng: number };
  mine: string | null;
  selected: string | null;
  walkingTo: string[];
  /** Parties on the road (from and to as cell centres, and when): drawn as a dashed line with the party moving along it. */
  parties?: { id: string; from: { lat: number; lng: number }; to: { lat: number; lng: number }; setOutAt: string; arriveAt: string; race: string }[];
  /** The race whose face is on the "back to my camp" button (none: no camp yet, no button). */
  home?: string | null;
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
const markers: Marker[] = [];
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
      properties: {
        cell: c.cell,
        state: c.owner ? (c.owner.id === props.mine ? "mine" : "theirs") : c.boss ? "boss" : "free",
        selected: c.cell === props.selected,
        target: props.walkingTo.includes(c.cell),
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
      properties: { id: p.id },
      geometry: { type: "LineString", coordinates: [[p.from.lng, p.from.lat], [p.to.lng, p.to.lat]] },
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

/** The icons over the cells (redrawn when the cells change: a hundred or so at a time). */
function drawMarkers() {
  if (!map) return;
  for (const m of markers) m.remove();
  markers.length = 0;
  for (const c of props.cells) {
    const el = document.createElement("div");
    el.className = "map-cell";
    if (c.owner) {
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
      el.append(foeElement(icon, 22), label(`Lv${c.lair.level}`));
    } else {
      continue;
    }
    markers.push(new Marker({ element: el, anchor: "center" }).setLngLat([c.lng, c.lat]).addTo(map));
  }
}

function refresh() {
  if (!map || !ready) return;
  (map.getSource("cells") as GeoJSONSource | undefined)?.setData(cellsGeoJson());
  (map.getSource("parties") as GeoJSONSource | undefined)?.setData(partiesGeoJson());
  drawMarkers();
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
    const at: [number, number] = [p.from.lng + (p.to.lng - p.from.lng) * k, p.from.lat + (p.to.lat - p.from.lat) * k];
    const known = partyMarkers.get(p.id);
    if (known) {
      known.setLngLat(at);
      continue;
    }
    const face = document.createElement("img");
    face.src = `/sprites/${p.race}/icon.png`;
    face.className = "map-face party";
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
defineExpose({ placesNear });

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
    m.addSource("cells", { type: "geojson", data: cellsGeoJson() });
    m.addSource("parties", { type: "geojson", data: partiesGeoJson() });
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
      filter: ["any", ["get", "selected"], ["!=", ["get", "state"], "free"]],
      paint: {
        "line-color": ["case", ["get", "selected"], "#ffffff", ["match", ["get", "state"], "mine", "#ffd84a", "theirs", "#e04a3a", "#ff3a2a"]],
        "line-width": ["case", ["get", "selected"], 3, 2.5],
      },
    });
    m.addLayer({ id: "cell-target", type: "line", source: "cells", filter: ["get", "target"], paint: { "line-color": "#ffffff", "line-width": 2, "line-dasharray": [2, 1.5] } });
    m.addLayer({ id: "party-road", type: "line", source: "parties", paint: { "line-color": "#ffffff", "line-width": 3, "line-dasharray": [2, 1.5], "line-opacity": 0.9 } });
    ready = true;
    refresh();
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

watch(() => [props.cells, props.selected, props.mine, props.walkingTo, props.parties, foeSheet.value], refresh);
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
.map :deep(.map-face) { width: 22px; height: 22px; image-rendering: pixelated; pointer-events: none; }
.map :deep(.map-face.party) { width: 22px; height: 22px; filter: drop-shadow(0 0 2px #fff); }
.map :deep(.map-label) { margin-top: -2px; font-size: 10px; font-weight: 800; color: #fff; text-shadow: 0 0 2px #000, 0 0 2px #000; line-height: 1; }
.map :deep(.map-label.mine) { color: #ffe27a; }
.map :deep(.map-label.theirs) { color: #ff9a8a; }
.map :deep(.map-hp) { display: block; width: 44px; height: 6px; margin-top: 1px; background: rgba(0, 0, 0, 0.55); border-radius: 3px; overflow: hidden; }
.map :deep(.map-hp i) { display: block; height: 100%; background: #ff4a3a; }
</style>
