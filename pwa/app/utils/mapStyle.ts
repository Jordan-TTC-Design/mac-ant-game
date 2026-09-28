import type { StyleSpecification } from "maplibre-gl";

/**
 * The big world's map: the real map (OpenStreetMap, as OpenFreeMap's vector tiles, free and without a key) drawn in the
 * game's colours, with no labels: sandy open land, the camp's greens for grass, parks and woods, its blue for water,
 * grey-brown for built-up land and buildings, pale roads. The page draws it at a low resolution and scales it up with
 * sharp pixels, so it looks like the rest of the game.
 */
export const OSM_ATTRIBUTION = '<a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> © <a href="https://www.openmaptiles.org/" target="_blank">OpenMapTiles</a> Data from <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a>';

export const MAP_COLORS = {
  open: "#cdbf8a",
  urban: "#b3a58c",
  grass: "#8cc063",
  park: "#79b957",
  wood: "#3f7d3a",
  water: "#4a8ec2",
  building: "#a89b88",
  buildingEdge: "#8c7f6e",
  road: "#f1e6c6",
  roadEdge: "#8a7a5a",
};

const roadWidth = (base: number) => ["interpolate", ["exponential", 1.6], ["zoom"], 12, base * 0.4, 15, base * 1.6, 17, base * 4] as unknown as number;

export function gameMapStyle(): StyleSpecification {
  const c = MAP_COLORS;
  const byClass = (classes: string[]) => ["in", ["get", "class"], ["literal", classes]] as unknown as boolean;
  const major = byClass(["motorway", "trunk", "primary"]);
  const middle = byClass(["secondary", "tertiary"]);
  const minor = byClass(["minor", "service", "residential", "living_street", "unclassified"]);
  return {
    version: 8,
    sources: {
      osm: { type: "vector", url: "https://tiles.openfreemap.org/planet", attribution: OSM_ATTRIBUTION },
    },
    layers: [
      { id: "ground", type: "background", paint: { "background-color": c.open } },
      {
        id: "built-up",
        type: "fill",
        source: "osm",
        "source-layer": "landuse",
        filter: byClass(["residential", "commercial", "industrial", "retail", "railway", "hospital", "school", "university", "college", "stadium"]),
        paint: { "fill-color": c.urban },
      },
      { id: "grass", type: "fill", source: "osm", "source-layer": "landcover", filter: byClass(["grass", "farmland", "wetland"]), paint: { "fill-color": c.grass } },
      { id: "wood", type: "fill", source: "osm", "source-layer": "landcover", filter: byClass(["wood", "forest"]), paint: { "fill-color": c.wood } },
      { id: "park", type: "fill", source: "osm", "source-layer": "park", paint: { "fill-color": c.park } },
      { id: "water", type: "fill", source: "osm", "source-layer": "water", paint: { "fill-color": c.water } },
      {
        id: "river",
        type: "line",
        source: "osm",
        "source-layer": "waterway",
        paint: { "line-color": c.water, "line-width": ["interpolate", ["linear"], ["zoom"], 12, 1, 16, 5] },
      },
      {
        id: "building",
        type: "fill",
        source: "osm",
        "source-layer": "building",
        minzoom: 13,
        paint: { "fill-color": c.building, "fill-outline-color": c.buildingEdge },
      },
      { id: "path", type: "line", source: "osm", "source-layer": "transportation", filter: byClass(["path", "track"]), paint: { "line-color": c.road, "line-width": 1, "line-dasharray": [2, 2] } },
      { id: "minor-edge", type: "line", source: "osm", "source-layer": "transportation", filter: minor, minzoom: 13, paint: { "line-color": c.roadEdge, "line-width": roadWidth(1.6) } },
      { id: "minor", type: "line", source: "osm", "source-layer": "transportation", filter: minor, minzoom: 13, paint: { "line-color": c.road, "line-width": roadWidth(1) } },
      { id: "middle-edge", type: "line", source: "osm", "source-layer": "transportation", filter: middle, paint: { "line-color": c.roadEdge, "line-width": roadWidth(2.6) } },
      { id: "middle", type: "line", source: "osm", "source-layer": "transportation", filter: middle, paint: { "line-color": c.road, "line-width": roadWidth(1.8) } },
      { id: "major-edge", type: "line", source: "osm", "source-layer": "transportation", filter: major, paint: { "line-color": c.roadEdge, "line-width": roadWidth(3.6) } },
      { id: "major", type: "line", source: "osm", "source-layer": "transportation", filter: major, paint: { "line-color": "#f8e8a8", "line-width": roadWidth(2.6) } },
    ],
  };
}
