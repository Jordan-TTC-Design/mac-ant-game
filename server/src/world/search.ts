/**
 * 搜尋地點: a name (台藝大, 大安森林公園, 台北車站…) looked up on OpenStreetMap's Nominatim, so the map can go anywhere and
 * not only to the landmarks around where it is looking. Places near the point the map is on are favoured.
 *
 * Nominatim asks for at most one question a second and a name for who is asking: answers are kept a while, and questions
 * wait their turn.
 */
import { cellAt, metersBetween, type LatLng, type PlaceFound } from "@goblincamp/shared/world";

const NOMINATIM = "https://nominatim.openstreetmap.org/search";
const SHOWN = 8;
/** How far around the map's point a place counts as near (it is looked at first). */
const NEAR_DEGREES = 0.3;
/** Where the players are: looked in first. */
const HOME_COUNTRY = "tw";

export interface RawPlace {
  name: string;
  /** The rest of the address, the most telling part first. */
  where: string;
  lat: number;
  lng: number;
}
/** `country`: only places in it (a country code), or anywhere (null). */
type PlaceSource = (q: string, near: LatLng | null, country: string | null) => Promise<RawPlace[] | null>;

let last = 0;
async function nominatim(q: string, near: LatLng | null, country: string | null): Promise<RawPlace[] | null> {
  const params = new URLSearchParams({ q, format: "jsonv2", limit: String(SHOWN), "accept-language": "zh-TW" });
  if (country) params.set("countrycodes", country);
  if (near) {
    params.set("viewbox", [near.lng - NEAR_DEGREES, near.lat + NEAR_DEGREES, near.lng + NEAR_DEGREES, near.lat - NEAR_DEGREES].join(","));
    params.set("bounded", "0");
  }
  // (one question a second at most)
  const wait = last + 1100 - Date.now();
  last = Math.max(Date.now(), last + 1100);
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  try {
    const res = await fetch(`${NOMINATIM}?${params}`, { signal: AbortSignal.timeout(8000), headers: { "user-agent": "GoblinCamp world server" } });
    if (!res.ok) return null;
    const rows = (await res.json()) as { name?: string; display_name: string; lat: string; lon: string }[];
    return rows.map((r) => {
      const parts = r.display_name.split(", ");
      const name = r.name?.trim() || parts[0]!;
      // (the address without the name itself, the post code or the country, the nearest parts first)
      const where = parts.filter((p, i) => !(i === 0 && p === name) && !/^\d+$/.test(p) && p !== "臺灣" && p !== "台灣").slice(0, 4).join("・");
      return { name, where, lat: Number(r.lat), lng: Number(r.lon) };
    });
  } catch {
    return null;
  }
}

let source: PlaceSource = nominatim;
/** Tests: answer from somewhere else. */
export function usePlaceSource(s: PlaceSource) {
  source = s;
  cache.clear();
}

/** Answers kept a while (the same name is often asked again). */
const cache = new Map<string, { at: number; places: RawPlace[] }>();
const KEEP_MS = 6 * 3600_000;

async function ask(q: string, near: LatLng | null, country: string | null): Promise<RawPlace[] | null> {
  // (near only matters roughly: kept by a tenth of a degree)
  const key = `${q}|${country ?? ""}|${near ? `${near.lat.toFixed(1)},${near.lng.toFixed(1)}` : ""}`;
  const kept = cache.get(key);
  if (kept && Date.now() - kept.at < KEEP_MS) return kept.places;
  const places = await source(q, near, country);
  if (places) {
    cache.set(key, { at: Date.now(), places });
    if (cache.size > 500) cache.delete(cache.keys().next().value!);
  }
  return places;
}

/** 台 and 臺 are the same character to people, not to the map: the other spelling, if the name has either. */
function otherSpelling(q: string): string | null {
  if (q.includes("台")) return q.replaceAll("台", "臺");
  if (q.includes("臺")) return q.replaceAll("臺", "台");
  return null;
}

/**
 * The places called `q`, as the map's search ranks them (places near `near` favoured); null: the search could not be
 * reached. Taiwan is looked in first (there the search also matches short names like 台藝大, which anywhere else it only
 * takes word by word), then, if nothing is found, anywhere.
 */
export async function searchPlaces(q: string, near: LatLng | null): Promise<PlaceFound[] | null> {
  const other = otherSpelling(q);
  let places: RawPlace[] | null = null;
  for (const country of [HOME_COUNTRY, null]) {
    places = await ask(q, near, country);
    if (other && (!places || places.length < 3)) {
      const more = await ask(other, near, country);
      if (more) places = [...(places ?? []), ...more];
    }
    if (!places || places.length) break;
  }
  if (!places) return null;
  const seen = new Set<string>();
  const out: PlaceFound[] = [];
  for (const p of places) {
    const cell = cellAt(p);
    if (seen.has(cell)) continue;
    seen.add(cell);
    out.push({ ...p, cell, km: near ? Math.round(metersBetween(near, p) / 100) / 10 : null });
  }
  return out.slice(0, SHOWN);
}
