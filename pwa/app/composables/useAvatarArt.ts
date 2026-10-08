import type { Avatar } from "@goblincamp/shared";

/**
 * The guild avatars' art (mac/tools/make_avatars.py → public/avatars): its manifest, and each look put together from its
 * layers into one strip of frames, its key colours swapped for its own skin, hair and eye flame. Shared by the hall and the
 * avatar maker; every look is made once and kept.
 */
export interface AvatarManifest {
  frameW: number;
  frameH: number;
  anchor: { x: number; y: number };
  seatY: number;
  frames: number;
  layers: string[];
  anims: Record<string, Record<string, { frames: number[]; fps: number; loop: boolean }>>;
  files: Record<string, Record<string, string> | string>;
  /** The one outline drawn round the whole figure once its layers are on, by body (race_sex). */
  outline: Record<string, string>;
  /** Moves every layer of a body up or down in some frames (the spirit's float), by body. */
  frameOffset?: Record<string, number[]>;
  bodyType: Record<string, string>;
  recolor: Record<string, { keys: string[]; options: Record<string, string[]> }>;
}

let manifest: Promise<AvatarManifest> | null = null;
const images = new Map<string, Promise<HTMLImageElement>>();
const strips = new Map<string, ImageBitmap | null>(); // look → its composed frames (null: still being made)

export function loadImage(path: string): Promise<HTMLImageElement> {
  let p = images.get(path);
  if (!p) {
    p = new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = () => reject(new Error(path));
      img.src = path;
    });
    images.set(path, p);
  }
  return p;
}

const hex = (h: string) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)] as const;

/** The look's frames as a bitmap (drawn every frame, so it must not live on a canvas that is read from: that one stays on the CPU). */
async function compose(m: AvatarManifest, a: Avatar): Promise<ImageBitmap> {
  return createImageBitmap(await layered(m, a));
}

async function layered(m: AvatarManifest, a: Avatar): Promise<HTMLCanvasElement> {
  const who = `${a.race}_${a.sex}`;
  const type = m.bodyType[who] ?? a.race;
  const files = m.files as Record<string, Record<string, string>>;
  const pick: Record<string, string | undefined> = {
    hair_back: files.hair_back?.[`${who}_${a.hair}`],
    body: files.body?.[`${who}_${a.face}`],
    bottom: files.bottom?.[`${who}_default`],
    top: files.top?.[`${who}_default`],
    shoes: files.shoes?.[`${who}_default`],
    brows: files.brows?.[`${type}_${a.brows}`],
    eyes: files.eyes?.[`${type}_${a.eyes}`],
    mouth: files.mouth?.[`${type}_${a.mouth}`],
    hair_front: files.hair_front?.[`${who}_${a.hair}`],
    fx: typeof m.files.fx === "string" ? m.files.fx : undefined,
  };
  const out = document.createElement("canvas");
  out.width = m.frameW * m.frames;
  out.height = m.frameH;
  const g = out.getContext("2d", { willReadFrequently: true })!;
  for (const layer of m.layers) {
    const file = pick[layer];
    if (!file || layer === "fx") continue;
    try {
      g.drawImage(await loadImage(`/avatars/${file}`), 0, 0);
    } catch {
      // (a missing layer is left out rather than losing the avatar)
    }
  }
  const swaps: [readonly number[], readonly number[]][] = [];
  const add = (channel: string, option: string | undefined) => {
    const r = m.recolor[channel];
    const to = option ? r?.options[option] : undefined;
    if (r && to) r.keys.forEach((k, i) => to[i] && swaps.push([hex(k), hex(to[i]!)]));
  };
  add("skin", `${who}_${a.skin}`);
  add("hair", a.hairColor);
  add("flame", a.flame);
  if (swaps.length) {
    const data = g.getImageData(0, 0, out.width, out.height);
    const px = data.data;
    for (let i = 0; i < px.length; i += 4) {
      if (!px[i + 3]) continue;
      for (const [from, to] of swaps) {
        if (px[i] === from[0] && px[i + 1] === from[1] && px[i + 2] === from[2]) {
          px[i] = to[0]!;
          px[i + 1] = to[1]!;
          px[i + 2] = to[2]!;
          break;
        }
      }
    }
    g.putImageData(data, 0, 0);
  }
  outline(g, out.width, out.height, m.outline[who]);
  if (pick.fx) {
    try {
      g.drawImage(await loadImage(`/avatars/${pick.fx}`), 0, 0);
    } catch {
      // (no effects then)
    }
  }
  const offsets = m.frameOffset?.[who];
  if (!offsets?.some((d) => d)) return out;
  const moved = document.createElement("canvas");
  moved.width = out.width;
  moved.height = out.height;
  const mg = moved.getContext("2d")!;
  for (let f = 0; f < m.frames; f++) mg.drawImage(out, f * m.frameW, 0, m.frameW, m.frameH, f * m.frameW, offsets[f] ?? 0, m.frameW, m.frameH);
  return moved;
}

/** Every see-through pixel next to (above, below, left, right of) a drawn one becomes the outline colour. */
function outline(g: CanvasRenderingContext2D, w: number, h: number, colour: string | undefined) {
  if (!colour) return;
  const [r, gr, b] = hex(colour);
  const data = g.getImageData(0, 0, w, h);
  const px = data.data;
  const solid = (x: number, y: number) => x >= 0 && y >= 0 && x < w && y < h && px[(y * w + x) * 4 + 3]! > 0;
  const edge: number[] = [];
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (solid(x, y)) continue;
      if (solid(x - 1, y) || solid(x + 1, y) || solid(x, y - 1) || solid(x, y + 1)) edge.push((y * w + x) * 4);
    }
  }
  for (const i of edge) {
    px[i] = r;
    px[i + 1] = gr;
    px[i + 2] = b;
    px[i + 3] = 255;
  }
  g.putImageData(data, 0, 0);
}

export function useAvatarArt() {
  function load(): Promise<AvatarManifest> {
    manifest ??= fetch("/avatars/manifest.json").then((r) => (r.ok ? r.json() : Promise.reject(new Error("avatars"))));
    manifest.catch(() => (manifest = null));
    return manifest;
  }
  /** The look's frames, or null while they are being made (ask again on the next frame). */
  function strip(m: AvatarManifest, a: Avatar): ImageBitmap | null {
    const key = JSON.stringify(a);
    if (!strips.has(key)) {
      strips.set(key, null);
      compose(m, a).then(
        (c) => strips.set(key, c),
        () => strips.delete(key),
      );
    }
    return strips.get(key) ?? null;
  }
  /** Which frame of the strip `anim` facing `dir` shows `t` seconds in. */
  function frameOf(m: AvatarManifest, anim: string, dir: string, t: number): number {
    const a = m.anims[anim]?.[dir] ?? m.anims[anim]?.front ?? m.anims.idle!.front!;
    const step = Math.floor(t * a.fps);
    return a.frames[a.loop ? step % a.frames.length : Math.min(step, a.frames.length - 1)]!;
  }
  return { load, strip, frameOf };
}
