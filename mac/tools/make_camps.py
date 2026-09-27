#!/usr/bin/env python3
"""Draws the built-in goblin camps as pixel art: four looks, each in three growth stages.

    python3 tools/make_camps.py                      # writes Resources/Camps/<id>/*
    python3 tools/make_camps.py --preview out.png    # also writes a zoomed contact sheet

Each camp is a folder with manifest.json and one PNG per growth stage. `entrance` is the spot (in art pixels, from the
top-left of the stage image) where the hole / tent flap is: the point that sits on the camp's position on screen, where
the girl crawls out and the goblins go in to rest. A stage is used once the camp holds at least `minCount` goblins.
Only the standard library is needed.
"""
import json
import math
import os
import sys

from make_goblin import write_png

# --- palettes: light to dark ---------------------------------------------------------------------------------------
DIRT = [(204, 160, 110), (176, 130, 84), (146, 104, 64), (112, 78, 48)]
STONE = [(190, 192, 196), (152, 156, 164), (118, 122, 134), (88, 92, 104)]
BARK = [(170, 118, 72), (140, 94, 56), (110, 72, 42), (82, 52, 32)]
WOOD_TOP = [(226, 190, 132), (204, 164, 106), (176, 136, 84)]
HIDE = [(214, 176, 120), (188, 146, 92), (158, 116, 72), (128, 90, 56)]
HIDE2 = [(196, 120, 96), (170, 92, 74), (140, 70, 58), (110, 54, 46)]
RED = [(232, 90, 84), (200, 60, 60), (160, 40, 48)]
CLOTH = [(226, 78, 72), (188, 52, 56), (150, 38, 46)]
DARK = (24, 18, 22)
HOLE = (20, 12, 16)
OUTLINE = (44, 28, 24)
BONE = (240, 234, 214)
FLAME = [(255, 244, 150), (255, 190, 60), (240, 110, 36)]
GRASS = [(120, 176, 74), (86, 140, 56)]


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def paint(self, mask, ramp, outline=OUTLINE, light=1.0, dither=0.22):
        """Fill a shape with a ramp lit from the top-left (light -> dark), with a dithered edge between tones, and a
        one-pixel outline around it (later shapes cover earlier ones, so overlapping shapes stay separate)."""
        if not mask:
            return
        xs = [p[0] for p in mask]
        ys = [p[1] for p in mask]
        cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        rx, ry = max(1, (max(xs) - min(xs)) / 2), max(1, (max(ys) - min(ys)) / 2)
        if outline:
            for x, y in mask:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) not in mask:
                        self.put(x + dx, y + dy, outline)
        for x, y in mask:
            b = 0.5 - 0.5 * ((x - cx) / rx * 0.55 + (y - cy) / ry * 0.85) * light
            b += ((hash_xy(x, y) % 100) / 100 - 0.5) * dither
            i = min(len(ramp) - 1, max(0, int(b * len(ramp))))
            self.put(x, y, ramp[len(ramp) - 1 - i])   # brighter b -> earlier (lighter) entry

    def solid(self, mask, color, outline=None):
        if outline:
            for x, y in mask:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if (x + dx, y + dy) not in mask:
                        self.put(x + dx, y + dy, outline)
        for x, y in mask:
            self.put(x, y, color)

    def image(self):
        img = [[(0, 0, 0, 0)] * self.w for _ in range(self.h)]
        for (x, y), c in self.px.items():
            img[y][x] = tuple(c) + (255,)
        return img


def hash_xy(x, y):
    n = (x * 73856093) ^ (y * 19349663)
    n = (n ^ (n >> 13)) * 1274126177
    return (n ^ (n >> 16)) & 0x7FFFFFFF


# --- shapes (masks) ----------------------------------------------------------------------------------------------------
def ellipse(cx, cy, rx, ry, below=None, above=None):
    m = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1 and (below is None or y <= below) and (above is None or y >= above):
                m.add((x, y))
    return m


def rect(x0, y0, x1, y1):
    return {(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)}


def poly(points):
    points = [(float(x), float(y)) for x, y in points]
    ys = [p[1] for p in points]
    m = set()
    for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
        xs = []
        for i in range(len(points)):
            (x0, y0), (x1, y1) = points[i], points[(i + 1) % len(points)]
            if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                xs.append(x0 + (y + 0.5 - y0) * (x1 - x0) / (y1 - y0))
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            for x in range(int(math.floor(a + 0.5)), int(math.floor(b + 0.5))):
                m.add((x, y))
    return m


SIZES = [(32, 20), (40, 24), (48, 28)]      # art pixels per growth stage
MIN_COUNT = [0, 30, 90]


# --- props ---------------------------------------------------------------------------------------------------------------
def torch(g, x, y):
    g.solid(rect(x, y - 6, x, y), BARK[1], OUTLINE)
    g.solid({(x, y - 8), (x - 1, y - 7), (x + 1, y - 7), (x, y - 7), (x, y - 9)}, FLAME[1], None)
    g.put(x, y - 8, FLAME[0])
    g.put(x, y - 7, FLAME[0])


def skull_pole(g, x, y):
    g.solid(rect(x, y - 6, x, y), BARK[2], OUTLINE)
    g.solid(rect(x - 2, y - 10, x + 2, y - 7), BONE, OUTLINE)
    g.put(x - 1, y - 9, DARK)
    g.put(x + 1, y - 9, DARK)
    g.put(x, y - 8, (200, 194, 174))


def flag_pole(g, x, y):
    g.solid(rect(x, y - 10, x, y), BARK[2], OUTLINE)
    g.solid(poly([(x + 1, y - 10), (x + 6, y - 8), (x + 1, y - 5)]), CLOTH[1], OUTLINE)


def mushroom(g, x, y, big=False):
    r = 3 if big else 2
    g.solid(rect(x, y - 2, x, y), (236, 226, 204), OUTLINE)
    g.paint(ellipse(x + 0.5, y - 3, r, r * 0.7, below=y - 2), RED, outline=OUTLINE)
    g.put(x - 1, y - 4, (255, 255, 255))
    if big:
        g.put(x + 1, y - 3, (255, 255, 255))


def stakes(g, xs, base):
    for x in xs:
        g.solid(poly([(x - 1, base), (x + 1, base), (x + 1, base - 6), (x, base - 8), (x - 1, base - 6)]), BARK[1], OUTLINE)


def crumbs(g, cx, base, spread, n, ramp):
    for i in range(n):
        h = hash_xy(cx + i * 31, base + i * 17)
        x = cx + (h % (2 * spread + 1)) - spread
        y = base + 1 + (h // 7) % 2
        g.put(x, y, ramp[1])


# --- the four camps ------------------------------------------------------------------------------------------------------
def camp_mound(s):
    w, h = SIZES[s]
    g = Grid(w, h)
    cx, base = w // 2, h - 3
    rx, ry = [11, 14, 17][s], [8, 10, 12][s]
    if s >= 1:
        g.paint(ellipse(cx - rx + 1, base, 6, 4, below=base), DIRT)
    if s >= 2:
        g.paint(ellipse(cx + rx - 1, base, 7, 5, below=base), DIRT)
        stakes(g, [3, w - 4], base)
    g.paint(ellipse(cx, base, rx, ry, below=base), DIRT)
    for i in range(6 + 4 * s):                                   # pebbles and grain in the soil
        hx = hash_xy(i * 13, s * 7 + 5)
        x = cx - rx + 2 + hx % (2 * rx - 3)
        y = base - 2 - (hx // 11) % max(1, ry - 3)
        if (x, y) in g.px and g.px[(x, y)] != OUTLINE:
            g.put(x, y, DIRT[0] if hx % 2 else DIRT[3])
    hole = ellipse(cx, base - 2, 4 + s * 0.8, 2.6 + s * 0.3)
    g.solid({(x, y + 1) for x, y in hole} - hole, (222, 178, 128))   # lit lower lip
    g.solid(hole, HOLE, OUTLINE)
    crumbs(g, cx, base, rx + 2, 5 + 2 * s, DIRT)
    if s >= 2:
        flag_pole(g, w - 8, base - 2)
    return g, (cx, base - 2)


def camp_cave(s):
    w, h = SIZES[s]
    g = Grid(w, h)
    cx, base = w // 2, h - 3
    r = [7, 9, 11][s]
    mouth = ellipse(cx, base - 3, r * 0.55, r * 0.6, below=base)
    if s >= 2:
        g.paint(ellipse(cx - r - 6, base - 1, 5, 4, below=base), STONE)
        g.paint(ellipse(cx + r + 7, base - 1, 6, 5, below=base), STONE)
    g.solid(mouth, HOLE, OUTLINE)
    g.paint(ellipse(cx - r * 0.95, base - r * 0.55, r * 0.55, r * 0.7, below=base), STONE)
    g.paint(ellipse(cx + r * 0.95, base - r * 0.55, r * 0.6, r * 0.75, below=base), STONE)
    g.paint(ellipse(cx, base - r * 1.05, r * 0.95, r * 0.55), STONE)
    if s >= 1:
        g.paint(ellipse(cx - r * 1.5, base - 1, 3.5, 2.5, below=base), STONE)
        torch(g, cx - int(r * 1.15) - 1, base)
    if s >= 2:
        skull_pole(g, cx + int(r * 1.3) + 2, base)
        torch(g, cx + int(r * 1.15) + 6, base)
    crumbs(g, cx, base, r + 4, 5, STONE)
    return g, (cx, base - 3)


def camp_stump(s):
    w, h = SIZES[s]
    g = Grid(w, h)
    cx, base = w // 2, h - 3
    r = [7, 9, 11][s]
    top = base - [9, 12, 15][s]
    # roots, trunk, rings
    for dx in (-r - 1, r - 1):
        g.paint(poly([(cx + dx, base), (cx + dx + 3, base), (cx + dx + 2, base - 3), (cx + dx + 1, base - 3)]), BARK)
    trunk = rect(cx - r, top, cx + r - 1, base) - {(cx - r, base), (cx + r - 1, base)}
    g.paint(trunk, BARK, dither=0.3)
    g.paint(ellipse(cx, top, r, r * 0.42), WOOD_TOP, dither=0.15)
    g.put(cx - 1, top, WOOD_TOP[2])
    g.put(cx + 1, top - 1, WOOD_TOP[2])
    hollow = ellipse(cx, base - 4, r * 0.5, r * 0.62, below=base - 1)
    g.solid(hollow, HOLE, OUTLINE)
    if s >= 1:
        mushroom(g, cx - r - 2, base)
        mushroom(g, cx + r + 2, base, big=True)
    if s >= 2:
        mushroom(g, cx - r - 6, base)
        mushroom(g, cx + r + 6, base)
        g.solid(rect(cx + r + 1, top - 5, cx + r + 1, top + 4), BARK[2], OUTLINE)       # a hanging lantern
        g.solid(rect(cx + r + 2, top + 1, cx + r + 4, top + 4), FLAME[1], OUTLINE)
        g.put(cx + r + 3, top + 2, FLAME[0])
    for x in (cx - r - 3, cx + r + 4):
        g.put(x, base + 1, GRASS[0])
        g.put(x, base, GRASS[1])
    return g, (cx, base - 4)


def tent(g, cx, base, half, height, ramp, flap=True):
    body = poly([(cx - half, base + 1), (cx + half, base + 1), (cx, base - height)])
    g.paint(body, ramp, dither=0.18)
    g.solid({(cx, base - height - 1), (cx, base - height - 2)}, BARK[1], OUTLINE)
    if flap:
        door = poly([(cx - half // 3, base + 1), (cx + half // 3, base + 1), (cx, base - height * 0.55)])
        g.solid(door, HOLE, OUTLINE)
    return cx, base - 3


def campfire(g, x, base):
    for i in range(6):                                               # ring of stones
        ang = i / 6 * 2 * math.pi
        g.put(int(x + 4 * math.cos(ang)), int(base + 1 + 1.6 * math.sin(ang)), STONE[1])
    g.solid(poly([(x - 4, base), (x + 4, base - 2), (x + 4, base - 1), (x - 4, base + 1)]), BARK[2], OUTLINE)
    g.solid(poly([(x - 4, base - 2), (x + 4, base), (x + 4, base + 1), (x - 4, base - 1)]), BARK[1], OUTLINE)
    g.solid(poly([(x - 3, base - 2), (x, base - 9), (x + 3, base - 2)]), FLAME[2], None)
    g.solid(poly([(x - 2, base - 2), (x, base - 7), (x + 2, base - 2)]), FLAME[1], None)
    g.solid(poly([(x - 1, base - 2), (x, base - 5), (x + 1, base - 2)]), FLAME[0], None)


def camp_tent(s):
    w, h = SIZES[s]
    g = Grid(w, h)
    cx, base = w // 2 - 4, h - 3
    if s >= 1:
        tent(g, cx - [0, 12, 14][s], base - 2, 6 + s, 8 + s * 2, HIDE2, flap=False)
    if s >= 2:
        tent(g, cx + 12, base - 2, 6, 11, HIDE2, flap=False)
        g.paint(ellipse(cx - 20 + 2, base - 1, 3, 3.6, below=base), BARK)                    # a barrel
        flag_pole(g, cx + 4, base - 12)
    entrance = tent(g, cx, base, 8 + s, 11 + s * 2, HIDE)
    campfire(g, w - 7 if s < 2 else w - 5, base)
    # mirrored, so the fire is on the left: the girl stands to the right of every camp
    m = Grid(w, h)
    for (x, y), c in g.px.items():
        m.px[(w - 1 - x, y)] = c
    return m, (w - 1 - entrance[0], entrance[1] + 1)


CAMPS = [
    ("mound", "土堆洞穴", "小土堆上有個黑黑的洞口，數量多了會長出更多土堆和一面旗子。", camp_mound),
    ("cave", "岩洞", "灰色的大石頭堆成的洞口，之後會插上火把和骷髏。", camp_cave),
    ("stump", "樹洞", "老樹墩上的洞，旁邊長出一圈蘑菇，還會掛上燈籠。", camp_stump),
    ("tent", "營帳", "獸皮帳篷加一堆營火，人多了再搭第二、第三頂。", camp_tent),
]


def preview(path, zoom=6):
    sheets = []
    for _id, _name, _blurb, draw in CAMPS:
        sheets.append([draw(s)[0].image() for s in range(3)])
    cell_w = max(w for w, _ in SIZES) + 2
    cell_h = max(h for _, h in SIZES) + 2
    W = len(SIZES) * cell_w * zoom
    H = len(CAMPS) * cell_h * zoom
    out = [[(214, 218, 200, 255)] * W for _ in range(H)]
    for r, imgs in enumerate(sheets):
        for c, img in enumerate(imgs):
            oy = r * cell_h + (cell_h - len(img))
            ox = c * cell_w + 1
            for y, row in enumerate(img):
                for x, px in enumerate(row):
                    if px[3]:
                        for dy in range(zoom):
                            for dx in range(zoom):
                                out[(oy + y) * zoom + dy][(ox + x) * zoom + dx] = px
    write_png(path, out)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Camps")
    for cid, name, blurb, draw in CAMPS:
        folder = os.path.join(root, cid)
        os.makedirs(folder, exist_ok=True)
        stages = []
        for s in range(3):
            g, entrance = draw(s)
            sheet = f"stage{s + 1}.png"
            write_png(os.path.join(folder, sheet), g.image())
            stages.append({"sheet": sheet, "minCount": MIN_COUNT[s], "entrance": list(entrance)})
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump({"id": cid, "name": name, "blurb": blurb, "pixelScale": 1.5, "stages": stages}, f, ensure_ascii=False, indent=2)
            f.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("wrote", os.path.normpath(root))


if __name__ == "__main__":
    main()
