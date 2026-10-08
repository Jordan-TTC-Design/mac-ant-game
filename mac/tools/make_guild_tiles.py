#!/usr/bin/env python3
"""The race floor and wall styles of the guild hall (GUILD.md §4.3), next to the shared ones make_avatars.py draws.

    python3 mac/tools/make_guild_tiles.py
        -> mac/Resources/Guild/floors/<id>.png, walls/<id>.png, walls/<id>_corner.png, walls/<id>_side.png
        -> merges them into mac/Resources/Guild/manifest.json: floors, walls, names {floors: {id: 名稱}, walls: {...}}
           (by kind, since the shared floor and wall are both called "stone"), race {style id: race}
        -> docs/images/guild/floors_walls_overview.png

Floors are 16 x 16 and tile seamlessly (every pattern wraps round the tile). Walls are 16 x 32: a 4-px cap seen from
above, the face, a dark baseboard; plus a corner piece and a 16 x 16 side cap, like the shared walls.
make_avatars.py rewrites the manifest from scratch, so run this script after it.
"""
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
GROOT = os.path.join(REPO, "mac", "Resources", "Guild")
DOC = os.path.join(REPO, "docs", "images", "guild", "floors_walls_overview.png")
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
T = 16

P = {
    "mud": (128, 92, 60), "mud_d": (100, 70, 44), "mud_l": (152, 114, 78), "dirt": (110, 80, 52),
    "straw": (226, 196, 110), "straw_d": (186, 152, 72), "pebble": (150, 146, 140), "bone": (232, 226, 206), "bone_d": (190, 182, 160),
    "flag": (138, 134, 128), "flag_l": (164, 160, 152), "flag_d": (108, 104, 100), "gap": (70, 56, 42),
    "moss": (86, 140, 70), "moss_d": (62, 110, 56), "moss_l": (122, 176, 92), "flower": (240, 236, 250), "flower2": (240, 170, 190),
    "root": (182, 132, 84), "root_l": (210, 164, 112), "root_d": (140, 96, 58), "root_x": (112, 74, 44),
    "black": (58, 54, 70), "black_l": (80, 76, 96), "black_d": (40, 36, 50), "black_x": (30, 26, 38), "sheen": (104, 92, 136),
    "grout": (44, 38, 50), "bone2": (212, 204, 182),
    "hide": (196, 150, 104), "hide_l": (224, 190, 146), "hide_d": (150, 108, 70), "pole": (110, 76, 46), "pole_d": (80, 54, 32),
    "pole_l": (146, 104, 66), "stitch": (214, 184, 110), "ochre": (200, 110, 50),
    "bark": (120, 86, 56), "bark_d": (90, 62, 40), "bark_l": (150, 112, 74), "vine": (70, 140, 70), "vine_d": (44, 100, 56),
    "leaf": (110, 180, 90), "leaf_l": (160, 214, 120),
    "glass": (84, 60, 120), "glass_l": (130, 104, 176), "moon": (210, 220, 250), "base": (34, 30, 40),
}


class Tile:
    """A wrapping canvas: anything drawn past an edge comes back on the other side, so the tile is seamless."""

    def __init__(self, w=T, h=T, fill=None, wrap=True):
        self.w, self.h, self.wrap = w, h, wrap
        self.px = [[fill] * w for _ in range(h)]

    def put(self, x, y, k):
        x, y = int(math.floor(x)), int(math.floor(y))
        if self.wrap:
            self.px[y % self.h][x % self.w] = k
        elif 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = k

    def rect(self, x0, y0, x1, y1, k):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, k)

    def get(self, x, y):
        return self.px[y % self.h][x % self.w]

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                k = self.px[y][x]
                if k:
                    img.putpixel((x, y), P[k] + (255,))
        return img


def voronoi(seeds, w=T, h=T):
    """Cell index and whether it is on a border, on a torus (so the cells wrap)."""
    cell = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            best, bi = 1e9, 0
            for i, (sx, sy) in enumerate(seeds):
                dx = min(abs(x - sx), w - abs(x - sx))
                dy = min(abs(y - sy), h - abs(y - sy))
                d = dx * dx + dy * dy * 1.15
                if d < best:
                    best, bi = d, i
            cell[y][x] = bi
    edge = [[cell[y][x] != cell[y][(x + 1) % w] or cell[y][x] != cell[(y + 1) % h][x] for x in range(w)] for y in range(h)]
    return cell, edge


# --- floors -------------------------------------------------------------------------------------------------------------------
def goblin_mud():
    t = Tile(fill="mud")
    rng = random.Random(3)
    for _ in range(22):
        t.put(rng.randrange(16), rng.randrange(16), rng.choice(["mud_d", "mud_l", "dirt"]))
    for x, y in ((3, 4), (11, 10), (13, 2)):                                # packed clods with a light top
        t.rect(x, y, x + 2, y + 1, "mud_d"); t.put(x, y, "mud_l")
    t.put(7, 12, "pebble"); t.put(8, 12, "flag_d"); t.put(1, 9, "pebble")
    for i in range(4):                                                      # a few bits of straw trodden in
        t.put(9 + i, 6 + (i % 2), "straw")
    return t


def goblin_flagstone():
    seeds = [(3, 3), (11, 2), (6, 10), (14, 11), (1, 13)]
    cell, edge = voronoi(seeds)
    shades = ["flag", "flag_l", "flag_d", "flag", "flag_l"]
    t = Tile()
    for y in range(T):
        for x in range(T):
            t.put(x, y, "gap" if edge[y][x] else shades[cell[y][x]])
    for i, (sx, sy) in enumerate(seeds):                                    # a light chip on each stone
        if not edge[sy - 1][sx - 1]:
            t.put(sx - 1, sy - 1, "flag_l" if shades[i] != "flag_l" else "flag")
    for x, y in ((9, 6), (10, 6), (2, 8), (13, 15)):                        # moss in the cracks
        if edge[y % T][x % T]:
            t.put(x, y, "moss")
    t.put(12, 6, "bone"); t.put(13, 6, "bone"); t.put(12, 5, "bone_d")      # a small bone
    return t


def elf_moss():
    t = Tile(fill="moss")
    rng = random.Random(8)
    for _ in range(26):
        t.put(rng.randrange(16), rng.randrange(16), rng.choice(["moss_d", "moss_l", "moss_d"]))
    for x, y in ((4, 3), (12, 9), (7, 13)):                                 # soft tufts
        t.put(x, y, "moss_l"); t.put(x + 1, y, "moss_l"); t.put(x, y + 1, "moss_d")
    t.put(10, 3, "flower"); t.put(2, 11, "flower2"); t.put(14, 14, "flower")
    return t


def elf_roots():
    t = Tile(fill="root")
    for k, (phase, amp, row) in enumerate(((0, 1.5, 2), (2, 1.2, 7), (4, 1.6, 12))):
        for x in range(16):
            y = row + amp * math.sin(2 * math.pi * x / 16 + phase)
            t.put(x, y, "root_d"); t.put(x, y + 1, "root_l") if k != 1 else t.put(x, y - 1, "root_l")
    for dy in range(-1, 2):                                                 # a knot
        for dx in range(-2, 3):
            if abs(dx) + abs(dy) * 2 <= 2:
                t.put(9 + dx, 9 + dy, "root_x" if (dx, dy) == (0, 0) else "root_d")
    t.put(4, 5, "root_x"); t.put(13, 14, "root_x")
    return t


def undead_blackstone():
    t = Tile(fill="black")
    for x0 in (0, 8):
        for y0 in (0, 8):
            t.rect(x0, y0, x0 + 7, y0, "black_l"); t.rect(x0, y0, x0, y0 + 7, "black_l")
            t.rect(x0, y0 + 7, x0 + 7, y0 + 7, "black_x"); t.rect(x0 + 7, y0, x0 + 7, y0 + 7, "black_x")
    t.put(3, 3, "sheen"); t.put(4, 2, "sheen"); t.put(11, 12, "sheen")      # a faint violet sheen
    for x, y in ((10, 2), (11, 3), (11, 4), (12, 5)):                       # a crack
        t.put(x, y, "black_d")
    t.put(4, 12, "black_d"); t.put(5, 13, "black_d")
    return t


def undead_bone():
    seeds = [(2, 2), (7, 1), (12, 3), (4, 7), (10, 7), (15, 8), (1, 12), (6, 13), (12, 13)]
    cell, edge = voronoi(seeds)
    shade = ["bone", "bone2", "bone_d", "bone2", "bone", "bone_d", "bone", "bone2", "bone"]
    t = Tile()
    for y in range(T):
        for x in range(T):
            t.put(x, y, "grout" if edge[y][x] else shade[cell[y][x]])
    for sx, sy in seeds[::3]:
        if not edge[sy][sx]:
            t.put(sx, sy, "black_l")                                        # a few dark chips
    return t


# --- walls ---------------------------------------------------------------------------------------------------------------------
def wall_base():
    return Tile(16, 32, wrap=False)


def goblin_hide():
    w = wall_base()
    w.rect(0, 0, 15, 3, "pole_l"); w.rect(0, 3, 15, 3, "pole")             # a crude log along the top
    for x in (3, 9, 13):
        w.put(x, 1, "pole")
    w.rect(1, 4, 15, 28, "hide")                                           # a stretched hide, sagging a little
    for x in range(1, 16):
        sag = int(1.5 * math.sin(math.pi * (x - 1) / 15))
        w.put(x, 4 + sag, "hide_l"); w.put(x, 28 - sag, "hide_d")
    w.rect(0, 2, 1, 31, "pole"); w.rect(0, 2, 0, 31, "pole_d")            # a pole at the tile edge (shared with the next)
    for y in range(6, 28, 3):                                               # stitches lacing it to the pole
        w.put(2, y, "stitch")
    w.put(7, 12, "hide_d"); w.put(11, 18, "hide_d"); w.put(6, 22, "hide_d")
    w.rect(8, 9, 9, 11, "ochre"); w.put(10, 10, "ochre"); w.put(7, 10, "ochre")   # a painted mark
    w.rect(0, 29, 15, 31, "dirt"); w.rect(0, 29, 15, 29, "mud_d")
    side = Tile(16, 16, fill="pole_l", wrap=False)
    for y in (0, 5, 10, 15):
        side.rect(0, y, 15, y, "pole")
    side.put(6, 3, "pole_d"); side.put(11, 8, "pole_d")
    return w, side, ("pole", "pole_d", "pole_l")


def elf_vines():
    w = wall_base()
    w.rect(0, 0, 15, 3, "leaf"); w.rect(0, 3, 15, 3, "vine")
    for x in (1, 5, 9, 13):
        w.put(x, 0, "leaf_l"); w.put(x + 2, 2, "vine_d")
    w.rect(0, 4, 15, 28, "bark")
    for x in (2, 7, 12):
        w.rect(x, 4, x, 28, "bark_d")
    w.put(5, 10, "bark_l"); w.put(10, 20, "bark_l"); w.put(14, 14, "bark_l")
    for y in range(4, 29):                                                  # a vine winding down, wrapping left-right
        x = 8 + 6 * math.sin(2 * math.pi * (y - 4) / 25)
        w.put(x % 16, y, "vine"); w.put((x + 1) % 16, y, "vine_d")
        if y % 5 == 0:
            w.put((x - 1) % 16, y, "leaf"); w.put((x - 2) % 16, y - 1, "leaf_l")
    w.put(4, 16, "flower2"); w.put(12, 25, "flower")
    w.rect(0, 29, 15, 31, "moss_d"); w.rect(0, 29, 15, 29, "moss")
    side = Tile(16, 16, fill="leaf", wrap=False)
    for x, y in ((2, 3), (7, 9), (12, 4), (4, 13), (13, 12)):
        side.put(x, y, "leaf_l"); side.put(x + 1, y + 1, "vine_d")
    return w, side, ("bark", "bark_d", "bark_l")


def undead_gothic():
    w = wall_base()
    w.rect(0, 0, 15, 3, "black_l"); w.rect(0, 3, 15, 3, "black_d")
    w.rect(0, 4, 15, 28, "black")
    for r, y in enumerate(range(4, 28, 4)):                                # black bricks
        w.rect(0, y + 3, 15, y + 3, "black_d")
        off = 0 if r % 2 == 0 else 4
        w.rect(off, y, off, y + 2, "black_d"); w.rect(off + 8, y, off + 8, y + 2, "black_d")
    for y in range(8, 27):                                                  # an arched window in the middle: frame...
        half = 3 if y > 11 else [0, 1, 2, 3][y - 8]
        w.rect(8 - half - 1, y, 7 + half + 1, y, "black_x")
    for y in range(9, 26):                                                  # ...then the violet glass inside it
        half = 3 if y > 12 else [0, 1, 2, 3][y - 9]
        w.rect(8 - half, y, 7 + half, y, "glass")
    w.rect(7, 10, 8, 26, "black_x"); w.rect(5, 18, 10, 18, "black_x")
    w.put(6, 13, "moon"); w.put(5, 14, "glass_l"); w.put(9, 21, "glass_l")
    w.rect(4, 26, 11, 26, "black_l")                                        # the sill
    w.rect(0, 29, 15, 31, "base"); w.rect(0, 29, 15, 29, "black_x")
    side = Tile(16, 16, fill="black_l", wrap=False)
    side.rect(0, 0, 0, 15, "black_d"); side.rect(15, 0, 15, 15, "black_d"); side.rect(0, 8, 15, 8, "black_d")
    side.put(5, 4, "sheen")
    return w, side, ("black_l", "black_x", "black")


def corner_of(face, pillar):
    """The end of a run: the face with a pillar on its right, like the shared walls' corner piece."""
    k, dark, light = pillar
    c = Tile(16, 32, wrap=False)
    for y in range(32):
        for x in range(16):
            c.px[y][x] = face.px[y][x]
    c.rect(10, 0, 15, 31, k); c.rect(10, 0, 10, 31, dark); c.rect(15, 0, 15, 31, dark)
    c.rect(11, 0, 14, 3, light); c.rect(10, 29, 15, 31, face.px[30][0])
    return c


FLOORS = [("goblin_mud", "夯土地", "goblin", goblin_mud), ("goblin_flagstone", "粗石板", "goblin", goblin_flagstone),
          ("elf_moss", "苔蘚地", "elf", elf_moss), ("elf_roots", "樹根木紋", "elf", elf_roots),
          ("undead_blackstone", "黑石磚", "undead", undead_blackstone), ("undead_bone", "骨片馬賽克", "undead", undead_bone)]
WALLS = [("goblin_hide", "獸皮帳幕牆", "goblin", goblin_hide), ("elf_vines", "活藤樹牆", "elf", elf_vines),
         ("undead_gothic", "哥德拱窗黑石牆", "undead", undead_gothic)]
SHARED_NAMES = {"floors": {"oak": "橡木地板", "stone": "石磚", "carpet": "紅地毯", "marble": "棋盤格大理石"},
                "walls": {"stone": "灰石牆", "wood": "木板牆"}}


def overview(man):
    S = 3
    font = lambda s: ImageFont.truetype(FONT, s)  # noqa: E731
    floors = list(man["floors"].items())
    walls = list(man["walls"].items())
    cell_w, floor_h, wall_h = 4 * T * S + 40, 3 * T * S + 50, 2 * T * S + 50
    cols = 5
    rows_f = (len(floors) + cols - 1) // cols
    rows_w = (len(walls) + cols - 1) // cols
    W = cols * cell_w + 20
    H = 70 + rows_f * floor_h + 50 + rows_w * wall_h + 20
    img = Image.new("RGBA", (W, H), (236, 222, 196, 255))
    d = ImageDraw.Draw(img)
    d.text((16, 12), "據點地板與牆壁（地板 4×3 格、牆 4 格一段；×3）", font=font(30), fill=(50, 30, 15))
    label = lambda k, kind: man["names"][kind][k] + ("" if k not in man["race"] else f"（{ {'goblin': '哥布林', 'elf': '精靈', 'undead': '死靈'}[man['race'][k]] }）")  # noqa: E731,E501
    y = 64
    for i, (fid, rel) in enumerate(floors):
        x = 16 + (i % cols) * cell_w
        yy = y + (i // cols) * floor_h
        tile = Image.open(os.path.join(GROOT, rel)).convert("RGBA")
        patch = Image.new("RGBA", (4 * T, 3 * T))
        for ty in range(3):
            for tx in range(4):
                patch.alpha_composite(tile, (tx * T, ty * T))
        img.alpha_composite(patch.resize((4 * T * S, 3 * T * S), Image.NEAREST), (x, yy))
        d.text((x + 2 * T * S, yy + 3 * T * S + 6), label(fid, "floors"), font=font(20), fill=(40, 24, 12), anchor="ma")
    y += rows_f * floor_h + 10
    d.text((16, y), "牆壁", font=font(26), fill=(50, 30, 15))
    y += 40
    for i, (wid, spec) in enumerate(walls):
        x = 16 + (i % cols) * cell_w
        yy = y + (i // cols) * wall_h
        face = Image.open(os.path.join(GROOT, spec["file"])).convert("RGBA")
        corner = Image.open(os.path.join(GROOT, spec["corner"])).convert("RGBA")
        run = Image.new("RGBA", (4 * T, 2 * T))
        for k in range(3):
            run.alpha_composite(face, (k * T, 0))
        run.alpha_composite(corner, (3 * T, 0))
        img.alpha_composite(run.resize((4 * T * S, 2 * T * S), Image.NEAREST), (x, yy))
        d.text((x + 2 * T * S, yy + 2 * T * S + 6), label(wid, "walls"), font=font(20), fill=(40, 24, 12), anchor="ma")
    img.save(DOC)


def main():
    mpath = os.path.join(GROOT, "manifest.json")
    man = json.load(open(mpath, encoding="utf-8"))
    names = {"floors": dict(SHARED_NAMES["floors"]), "walls": dict(SHARED_NAMES["walls"])}
    race = {}                                                              # race style id -> race (ids are unique across kinds)
    for fid, name, r, fn in FLOORS:
        rel = f"floors/{fid}.png"
        fn().image().save(os.path.join(GROOT, rel), optimize=True)
        man["floors"][fid] = rel
        names["floors"][fid] = name
        race[fid] = r
    for wid, name, r, fn in WALLS:
        face, side, pillar = fn()
        files = {"file": f"walls/{wid}.png", "corner": f"walls/{wid}_corner.png", "side": f"walls/{wid}_side.png"}
        face.image().save(os.path.join(GROOT, files["file"]), optimize=True)
        corner_of(face, pillar).image().save(os.path.join(GROOT, files["corner"]), optimize=True)
        side.image().save(os.path.join(GROOT, files["side"]), optimize=True)
        man["walls"][wid] = dict(files, w=T, h=2 * T, cap=4)
        names["walls"][wid] = name
        race[wid] = r
    man["names"] = names
    man["race"] = race
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(man, f, ensure_ascii=False, indent=1)
        f.write("\n")
    overview(man)
    print("floors", list(man["floors"]), "walls", list(man["walls"]))


if __name__ == "__main__":
    main()
