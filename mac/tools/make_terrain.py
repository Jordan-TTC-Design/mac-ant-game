#!/usr/bin/env python3
"""Draws the terrain sprites for the camp window's scenes: for each biome (meadow, forest, snow, swamp) a ground tile, a few trees,
rocks, bushes and a fallen log. Output: Resources/Terrain/*.png. Run: python3 tools/make_terrain.py [--preview out.png]

Every sprite stands on its bottom-centre pixel (the foot of the trunk or the rock), so the game can place it by that point.
Ponds, streams, paths, flowers and drifts are drawn by the game itself (Terrain.swift). One art pixel is two points on screen."""
import math
import os
import random
import sys
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Terrain")
BIOMES = ["meadow", "forest", "snow", "swamp"]

OUTLINE = {"meadow": (24, 62, 44), "forest": (16, 44, 34), "snow": (40, 64, 90), "swamp": (30, 40, 30)}
GROUND = {
    "meadow": [(58, 116, 62), (48, 100, 54), (74, 138, 74), (66, 128, 68)],
    "forest": [(40, 86, 56), (34, 74, 48), (52, 102, 64), (72, 84, 50)],
    "snow": [(236, 242, 248), (222, 232, 242), (248, 250, 253), (206, 220, 236)],
    "swamp": [(72, 100, 66), (62, 88, 58), (88, 112, 70), (100, 92, 60)],
}
LEAF = {"meadow": [(41, 107, 51), (69, 158, 69), (107, 194, 92)], "forest": [(28, 80, 48), (40, 104, 60), (64, 134, 74)]}
TRUNK = {"meadow": (107, 69, 36), "forest": (92, 60, 34), "snow": (96, 66, 40), "swamp": (86, 78, 66)}
STONE = {"meadow": [(120, 124, 130), (156, 160, 166), (92, 96, 104)], "forest": [(108, 116, 112), (140, 150, 140), (80, 92, 84)],
         "snow": [(150, 160, 176), (196, 206, 220), (110, 120, 140)], "swamp": [(88, 98, 84), (116, 128, 104), (64, 74, 62)]}
MOSS = (74, 128, 66)
SNOW = [(248, 250, 253), (218, 228, 240)]


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c + (255,) if len(c) == 3 else c)


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            put(img, xx, yy, c)


def outline(img, col):
    edge = []
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and img.getpixel((nx, ny))[3] > 0:
                        edge.append((x, y))
                        break
    for x, y in edge:
        put(img, x, y, col)


def blob(img, cx, cy, rx, ry, colors, rnd, light=(-1, -1)):
    """A lumpy ellipse shaded from a light corner: colors = [dark, mid, light]."""
    for dy in range(-ry - 1, ry + 2):
        for dx in range(-rx - 1, rx + 2):
            d = (dx / (rx + 0.5)) ** 2 + (dy / (ry + 0.5)) ** 2 + rnd.uniform(-0.12, 0.12)
            if d <= 1:
                shade = (dx * light[0] + dy * light[1]) / max(1.0, rx + ry)
                idx = 2 if shade > 0.28 else (0 if shade < -0.22 else 1)
                put(img, cx + dx, cy + dy, colors[idx])


# ---- trees -----------------------------------------------------------------------------------------------------
def round_tree(biome, rnd, height):
    w = height * 3 // 4 + 6
    img = new(w, height + 2)
    cx, base = w // 2, height
    th = height // 3
    rect(img, cx - 1, base - th, 3, th + 1, TRUNK[biome])
    rect(img, cx - 1, base - th, 1, th, (150, 104, 60))
    cols = LEAF[biome]
    r = (height - th) // 2
    blob(img, cx, base - th - r + 2, r + 2, r, cols, rnd)
    for _ in range(3):
        blob(img, cx + rnd.randint(-r, r), base - th - r + rnd.randint(-2, 4), 3, 3, cols, rnd)
    if biome == "meadow":
        for _ in range(4):
            put(img, cx + rnd.randint(-r, r), base - th - r + rnd.randint(-r // 2, r // 2), (230, 46, 41))
    outline(img, OUTLINE[biome])
    return img


def pine_tree(biome, rnd, height, snowy=False):
    half = height // 3 + 3
    img = new(half * 2 + 3, height + 2)
    cx, base = half + 1, height
    rect(img, cx - 1, base - 4, 3, 5, TRUNK[biome])
    cols = [(24, 66, 48), (32, 84, 58), (44, 108, 70)] if biome != "meadow" else [(30, 76, 56), (38, 92, 64), (24, 60, 44)]
    layers = max(3, height // 8)
    span = base - 4
    for i in range(layers):
        top = 1 + i * (span - 6) // layers
        w = 2 + int((i + 1) * (half - 2) / layers)
        for row in range(w + 3):
            ww = min(w, 1 + row * w // (w + 2))
            for x in range(-ww, ww + 1):
                shade = 2 if x < -ww // 2 else (0 if x > ww // 2 else 1)
                c = cols[shade]
                if snowy and row < 3 + (1 if i % 2 else 0):
                    c = SNOW[0] if x < ww // 2 else SNOW[1]
                put(img, cx + x, top + row, c)
    outline(img, OUTLINE[biome])
    return img


def dead_tree(biome, rnd, height):
    """A bare, twisted tree with moss hanging from its branches (the swamp)."""
    w = height * 2 // 3 + 8
    img = new(w, height + 2)
    cx, base = w // 2, height
    x = cx
    for y in range(base, base - height * 2 // 3, -1):
        x += rnd.choice((0, 0, 0, 1, -1)) if y % 3 == 0 else 0
        rect(img, x - 1, y, 3 if y > base - height // 3 else 2, 1, TRUNK[biome])
    top = base - height * 2 // 3
    for side in (-1, 1):
        bx, by = x, top + rnd.randint(2, 6)
        for k in range(rnd.randint(6, 10)):
            bx += side
            by -= 1 if k % 2 == 0 else 0
            put(img, bx, by, TRUNK[biome])
            if k % 3 == 2:
                for m in range(rnd.randint(2, 5)):
                    put(img, bx, by + 1 + m, MOSS if m % 2 == 0 else (58, 104, 54))
    outline(img, OUTLINE[biome])
    return img


# ---- rocks, bushes, logs ---------------------------------------------------------------------------------------
def rock(biome, rnd, size):
    img = new(size * 2 + 4, size + 5)
    cols = STONE[biome]
    cx, cy = size + 2, size // 2 + 2
    blob(img, cx, cy + 1, size, size // 2 + 1, [cols[2], cols[0], cols[1]], rnd)
    if biome in ("forest", "swamp"):  # moss on the top
        for _ in range(size * 2):
            put(img, cx + rnd.randint(-size + 2, size - 2), cy - rnd.randint(0, size // 2 - 1), MOSS)
    if biome == "snow":
        for dx in range(-size + 2, size - 1):
            put(img, cx + dx, cy - size // 2 + abs(dx) // 3, SNOW[0])
    outline(img, OUTLINE[biome])
    return img


def bush(biome, rnd, size):
    img = new(size * 2 + 4, size + 4)
    cols = LEAF["meadow" if biome != "forest" else "forest"] if biome in ("meadow", "forest") else [(60, 90, 58), (78, 110, 66), (96, 128, 74)]
    if biome == "snow":
        cols = [(40, 84, 60), (54, 106, 74), (70, 128, 88)]
    blob(img, size + 2, size // 2 + 2, size, size // 2 + 1, cols, rnd)
    if biome == "snow":
        for dx in range(-size + 1, size):
            put(img, size + 2 + dx, 1 + abs(dx) // 3, SNOW[0])
    elif biome == "meadow" and rnd.random() < 0.7:
        put(img, size + rnd.randint(0, 4), size // 2 + 1, (220, 60, 90))
    outline(img, OUTLINE[biome])
    return img


def log(biome, rnd):
    img = new(26, 10)
    for x in range(2, 24):
        rect(img, x, 3, 1, 5, TRUNK[biome] if (x // 3) % 2 else (120, 80, 46))
    rect(img, 1, 3, 2, 5, (190, 150, 100))
    put(img, 2, 5, (120, 80, 46))
    if biome in ("forest", "swamp"):
        for x in range(6, 20, 2):
            put(img, x, 3, MOSS)
    if biome == "snow":
        rect(img, 4, 2, 17, 2, SNOW[0])
    outline(img, OUTLINE[biome])
    return img


# ---- ground ----------------------------------------------------------------------------------------------------
def ground_tile(biome, rnd):
    cols = GROUND[biome]
    img = Image.new("RGBA", (32, 32), cols[0] + (255,))
    for _ in range(90):
        put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(cols))
    if biome == "meadow":
        for _ in range(3):
            put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice([(240, 220, 90), (240, 120, 150), (250, 250, 250), (150, 160, 240)]))
        for _ in range(2):
            x, y = rnd.randrange(2, 30), rnd.randrange(2, 30)
            put(img, x, y, (150, 150, 150)); put(img, x + 1, y, (120, 120, 120)); put(img, x, y + 1, (120, 120, 120))
    elif biome == "forest":
        for _ in range(9):  # fallen leaves
            put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice([(150, 110, 50), (120, 88, 40), (168, 130, 60)]))
        for _ in range(2):
            put(img, rnd.randrange(32), rnd.randrange(32), (200, 60, 60))
    elif biome == "snow":
        for _ in range(4):
            x, y = rnd.randrange(2, 30), rnd.randrange(2, 30)
            put(img, x, y, (170, 190, 214)); put(img, x + 1, y, (170, 190, 214))
        for _ in range(2):
            put(img, rnd.randrange(32), rnd.randrange(32), (120, 128, 140))  # a stone peeking out
    elif biome == "swamp":
        for _ in range(7):
            x, y = rnd.randrange(1, 30), rnd.randrange(1, 30)
            put(img, x, y, (44, 62, 48)); put(img, x + 1, y, (44, 62, 48))
        for _ in range(3):
            put(img, rnd.randrange(32), rnd.randrange(32), (110, 140, 90))
    return img


def make_all():
    sprites = {}
    for biome in BIOMES:
        rnd = random.Random(hash(biome) & 0xFFFF)
        sprites[f"ground-{biome}"] = ground_tile(biome, random.Random(len(biome) * 31))
        rnd = random.Random(sum(map(ord, biome)))
        if biome in ("meadow", "forest"):
            sprites[f"tree-{biome}-0"] = round_tree(biome, rnd, 34)
            sprites[f"tree-{biome}-1"] = round_tree(biome, rnd, 40)
            sprites[f"tree-{biome}-2"] = pine_tree(biome, rnd, 44)
            if biome == "forest":
                sprites["tree-forest-3"] = pine_tree(biome, rnd, 52)
        elif biome == "snow":
            sprites["tree-snow-0"] = pine_tree(biome, rnd, 40, snowy=True)
            sprites["tree-snow-1"] = pine_tree(biome, rnd, 50, snowy=True)
            sprites["tree-snow-2"] = pine_tree(biome, rnd, 32, snowy=True)
        else:
            sprites["tree-swamp-0"] = dead_tree(biome, rnd, 40)
            sprites["tree-swamp-1"] = dead_tree(biome, rnd, 34)
            sprites["tree-swamp-2"] = dead_tree(biome, rnd, 46)
        for i, size in enumerate((6, 9, 13)):
            sprites[f"rock-{biome}-{i}"] = rock(biome, rnd, size)
        for i, size in enumerate((5, 8)):
            sprites[f"bush-{biome}-{i}"] = bush(biome, rnd, size)
        sprites[f"log-{biome}"] = log(biome, rnd)
    return sprites


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = make_all()
    sprites.update(make_camp())
    sprites.update(make_growth())
    sprites.update(make_farm())
    sprites.update(make_seasonal())
    for name, img in sprites.items():
        img.save(os.path.join(OUT, name + ".png"))
    print("wrote", len(sprites), "sprites to", os.path.normpath(OUT))
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        zoom = 3
        rows = []
        for biome in BIOMES:
            row = [(n, i) for n, i in sprites.items() if n.split("-")[1] == biome or n == f"log-{biome}"]
            rows.append(row)
        W = max(sum(i.width * zoom + 12 for _, i in r) for r in rows)
        H = sum(max(i.height for _, i in r) * zoom + 16 for r in rows)
        sheet = Image.new("RGBA", (W + 12, H + 12), (60, 90, 60, 255))
        y = 8
        for r in rows:
            x = 8
            rh = max(i.height for _, i in r) * zoom
            for n, i in r:
                if n.startswith("ground"):
                    tile = i.resize((i.width * 2, i.height * 2), Image.NEAREST)
                    sheet.paste(tile, (x, y))
                    x += tile.width + 12
                else:
                    big = i.resize((i.width * zoom, i.height * zoom), Image.NEAREST)
                    sheet.paste(big, (x, y + rh - big.height), big)
                    x += big.width + 12
            y += rh + 16
        sheet.save(path)



# ================================================================================================================
# The primitive camp: what goblins would have around their home (hide tents, a totem, drying racks, bones, a stone fire ring…)
# ================================================================================================================
HIDE = {"meadow": (170, 122, 74), "forest": (150, 108, 66), "snow": (196, 176, 150), "swamp": (128, 110, 70)}
BONE = (238, 232, 214)
BONE_SHADE = (198, 190, 170)
WOOD = (110, 74, 40)
WOOD_LIGHT = (150, 104, 60)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def tent(biome, rnd):
    """A hide tent on crossed poles, with a dark doorway and a rope round the middle."""
    W, H = 36, 32
    img = new(W, H + 6)
    cx = W // 2
    hide = HIDE[biome]
    for y in range(H):
        half = 2 + int(y * (W / 2 - 3) / H)
        for x in range(-half, half + 1):
            seam = (x + 60) % 7 == 0
            panel = 0.86 if (x // 7) % 2 else 1.0
            c = shade(hide, 0.72 if seam else panel * (0.8 + 0.2 * y / H))
            put(img, cx + x, y + 6, c)
    for k in range(6):  # the poles crossing above the top
        put(img, cx - 2 + k // 2, 5 - k, WOOD)
        put(img, cx + 2 - k // 2, 5 - k, WOOD)
        put(img, cx - 1 + k // 2, 5 - k, WOOD_LIGHT)
    put(img, cx - 3, 0, WOOD); put(img, cx + 3, 0, WOOD)
    for y in range(H // 2, H):  # the doorway: a dark triangle, with a flap folded back on one side
        half = 1 + (y - H // 2) * 5 // (H // 2)
        for x in range(-half, half + 1):
            put(img, cx + x, y + 6, (44, 30, 24))
        put(img, cx - half - 1, y + 6, shade(hide, 1.15))
    for x in range(-13, 14):  # a rope
        if abs(x) > 2 + 0:
            half = 2 + int(14 * (W / 2 - 3) / H)
            if abs(x) <= half:
                put(img, cx + x, 20, (198, 172, 120))
    if biome == "snow":
        for y in range(H // 3):
            half = 2 + int(y * (W / 2 - 3) / H)
            for x in range(-half, half + 1):
                put(img, cx + x, y + 6, SNOW[0] if (x + y) % 4 else SNOW[1])
    if biome == "swamp":
        for x in range(-14, 15):
            if rnd.random() < 0.5:
                put(img, cx + x, H + 4, MOSS)
    outline(img, (44, 30, 22))
    return img


def totem(biome, rnd):
    """A carved pole: three faces, one above the other, with feathers."""
    img = new(14, 44)
    cx = 7
    rect(img, cx - 2, 8, 5, 35, (120, 84, 48))
    rect(img, cx - 2, 8, 1, 35, WOOD_LIGHT)
    faces = [((196, 60, 50), 8), ((60, 98, 170), 20), ((228, 214, 180), 32)]
    for col, y in faces:
        rect(img, cx - 3, y - 1, 7, 8, col)
        put(img, cx - 2, y + 1, (30, 24, 24)); put(img, cx + 1, y + 1, (30, 24, 24))    # eyes
        rect(img, cx - 2, y + 4, 5, 2, (30, 24, 24))                                     # mouth
        for t in range(-2, 3, 2):
            put(img, cx + t, y + 4, (250, 246, 236))                                     # teeth
    for i, col in enumerate([(210, 60, 50), (240, 200, 60), (60, 140, 90), (210, 60, 50)]):  # feathers
        for k in range(6):
            put(img, cx - 3 + i * 2 - (1 if i < 2 else 0) * 0, 7 - k - (1 if i in (1, 2) else 0), col)
    outline(img, (40, 28, 20))
    return img


def skull_stake(biome, rnd):
    img = new(12, 24)
    rect(img, 5, 9, 2, 15, WOOD)
    blob(img, 6, 5, 4, 4, [BONE_SHADE, BONE, (252, 250, 240)], rnd)
    rect(img, 4, 8, 5, 2, BONE)
    put(img, 4, 5, (34, 26, 22)); put(img, 5, 5, (34, 26, 22)); put(img, 7, 5, (34, 26, 22)); put(img, 8, 5, (34, 26, 22))
    put(img, 6, 7, (34, 26, 22))
    for k in range(4):
        put(img, 3 - k // 2, 12 + k, (196, 60, 50))                                      # a strip of red cloth
    outline(img, (44, 32, 24))
    return img


def bones(biome, rnd, variant):
    img = new(18, 9)
    def bone(x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            put(img, x0 + (x1 - x0) * i // max(1, n), y0 + (y1 - y0) * i // max(1, n), BONE)
        put(img, x0, y0 - 1, BONE); put(img, x0, y0 + 1, BONE); put(img, x1, y1 - 1, BONE); put(img, x1, y1 + 1, BONE)
    bone(2, 6, 12, 3)
    bone(3, 3, 13, 7)
    if variant:
        blob(img, 14, 4, 2, 2, [BONE_SHADE, BONE, (252, 250, 240)], rnd)
        put(img, 13, 4, (34, 26, 22)); put(img, 15, 4, (34, 26, 22))
    outline(img, (70, 60, 48))
    return img


def drying_rack(biome, rnd):
    img = new(34, 26)
    for x in (4, 29):
        rect(img, x, 6, 2, 19, WOOD)
        put(img, x - 1, 5, WOOD); put(img, x + 2, 5, WOOD)
    rect(img, 3, 6, 29, 2, WOOD_LIGHT)
    pelt = (150, 106, 66)
    rect(img, 8, 8, 8, 10, pelt); rect(img, 8, 8, 8, 1, shade(pelt, 0.7))
    for k in range(4):
        put(img, 9 + k * 2, 18 + k % 2, pelt)
    for i, x in enumerate((19, 22, 25)):                                                 # strips of meat
        rect(img, x, 8, 2, 6 + i % 2 * 2, (176, 70, 60))
        rect(img, x, 8, 1, 6 + i % 2 * 2, (206, 100, 88))
    outline(img, (44, 30, 22))
    return img


def firewood(biome, rnd):
    img = new(20, 12)
    for row, count in enumerate((4, 3, 2)):
        y = 8 - row * 3
        x0 = 2 + row * 2 + (4 - count) * 1
        for i in range(count):
            x = x0 + i * 4
            rect(img, x, y, 4, 3, WOOD if (i + row) % 2 else (128, 88, 50))
            put(img, x, y + 1, (200, 160, 110))
    if biome == "snow":
        rect(img, 4, 1, 12, 2, SNOW[0])
    outline(img, (44, 30, 22))
    return img


def stump(biome, rnd):
    img = new(14, 12)
    rect(img, 2, 4, 10, 7, (104, 70, 40))
    blob(img, 7, 4, 5, 3, [(150, 110, 70), (190, 150, 100), (216, 180, 130)], rnd)
    for r in (1, 2):
        put(img, 7 - r, 4, (150, 110, 70)); put(img, 7 + r, 4, (150, 110, 70))
    if biome == "snow":
        for x in range(4, 11):
            put(img, x, 2, SNOW[0])
    if biome in ("forest", "swamp"):
        for x in (3, 4, 10):
            put(img, x, 9, MOSS)
    outline(img, OUTLINE[biome])
    return img


def fern(biome, rnd, size=8):
    img = new(size * 2 + 3, size + 3)
    cx, base = size + 1, size + 1
    cols = [(38, 96, 52), (58, 128, 66), (84, 158, 84)] if biome != "swamp" else [(60, 96, 56), (80, 120, 66), (104, 144, 78)]
    for k in range(-3, 4):
        ang = k * 0.42
        for t in range(size):
            x = cx + int(math.sin(ang) * t * 1.15)
            y = base - int(math.cos(ang) * t * 0.9) + (t * t) // (size * 3)
            put(img, x, y, cols[1 if t % 3 else 2])
            if t > 2:
                put(img, x + 1, y + 1, cols[0]); put(img, x - 1, y + 1, cols[0])
    if biome == "snow":
        for x in range(cx - 3, cx + 4):
            put(img, x, base - 2, SNOW[0])
    return img


def tuft(biome, rnd):
    img = new(9, 9)
    cols = [(52, 110, 58), (76, 142, 72), (110, 176, 90)] if biome != "swamp" else [(70, 100, 60), (94, 128, 70), (124, 156, 84)]
    if biome == "snow":
        cols = [(90, 130, 90), (120, 158, 110), (150, 186, 130)]
    for x in range(1, 8, 2):
        h = rnd.randint(4, 8)
        for k in range(h):
            put(img, x + (k > h // 2 and (x % 4 == 1)) - 0, 8 - k, cols[min(2, k * 3 // h)])
    return img


def cattail(biome, rnd):
    img = new(11, 22)
    for x, h in ((2, 15), (5, 20), (8, 13)):
        rect(img, x, 22 - h, 1, h, (70, 118, 60))
        rect(img, x - 1, 22 - h - 1, 3, 5, (128, 84, 46))
        put(img, x, 22 - h - 2, (168, 120, 70))
        for k in range(3):
            put(img, x + 1 + k, 20 - k, (86, 140, 70))
    outline(img, OUTLINE[biome])
    return img


def spears(biome, rnd):
    img = new(14, 28)
    for x0, lean in ((3, 1), (8, -1)):
        for k in range(24):
            put(img, x0 + (k * lean) // 8, 27 - k, WOOD if k % 5 else WOOD_LIGHT)
        tx = x0 + (23 * lean) // 8
        for k in range(4):
            put(img, tx, 3 - k + 1, (170, 174, 184)); put(img, tx, 4 - k + 1, (170, 174, 184))
        put(img, tx - 1, 3, (140, 146, 158)); put(img, tx + 1, 3, (140, 146, 158))
        put(img, tx, 0, (210, 214, 224))
        put(img, tx, 5, (196, 60, 50))
    outline(img, (44, 30, 22))
    return img


def menhir(biome, rnd):
    """A tall standing stone with a few scratched marks."""
    img = new(14, 34)
    cols = STONE[biome]
    for y in range(3, 33):
        half = 3 + (y - 3) * 2 // 30 + (1 if y % 7 == 0 else 0)
        for x in range(-half, half + 1):
            put(img, 7 + x, y, cols[1] if x < -half // 3 else (cols[2] if x > half // 2 else cols[0]))
    for x in range(-2, 3):
        put(img, 7 + x, 2, cols[1])
    put(img, 6, 1, cols[1]); put(img, 7, 1, cols[1])
    for (x, y) in ((6, 10), (7, 11), (8, 12), (6, 16), (8, 16), (7, 17)):
        put(img, x, y, shade(cols[2], 0.7))
    if biome in ("forest", "swamp"):
        for y in range(24, 32, 2):
            put(img, 5, y, MOSS); put(img, 9, y + 1, MOSS)
    if biome == "snow":
        for x in range(-2, 3):
            put(img, 7 + x, 3, SNOW[0])
    outline(img, OUTLINE[biome])
    return img


def firepit(biome, rnd):
    """A ring of stones round cold ashes and a few charred logs."""
    img = new(30, 16)
    cx, cy = 15, 8
    blob(img, cx, cy, 11, 5, [(50, 44, 40), (72, 64, 58), (96, 88, 80)], rnd)
    for k in range(14):
        a = k / 14 * 2 * math.pi
        x, y = cx + int(math.cos(a) * 12), cy + int(math.sin(a) * 6)
        rect(img, x - 1, y - 1, 3, 3, STONE[biome][1 if k % 2 else 0])
        put(img, x - 1, y - 1, STONE[biome][2 if k % 3 else 1])
    for (x0, y0, x1, y1) in ((9, 9, 20, 6), (10, 6, 21, 10)):
        n = max(abs(x1 - x0), 1)
        for i in range(n + 1):
            put(img, x0 + (x1 - x0) * i // n, y0 + (y1 - y0) * i // n, (36, 26, 22))
    outline(img, OUTLINE[biome])
    return img


def willow(biome, rnd, height):
    """A swamp tree: a fat crooked trunk, roots in the mud, and a canopy of drooping strands."""
    w = height + 8
    img = new(w, height + 8)
    cx, base = w // 2, height + 6
    for y in range(base, base - height // 2, -1):
        half = 2 + (y - (base - height // 2)) // 6
        rect(img, cx - half + (1 if y % 5 == 0 else 0), y, half * 2 + 1, 1, TRUNK[biome])
        put(img, cx - half, y, (60, 52, 44))
    for dx in (-5, -3, 3, 5):  # roots
        put(img, cx + dx, base + 1, TRUNK[biome]); put(img, cx + dx // 2, base, TRUNK[biome])
    top = base - height // 2
    cols = [(46, 84, 54), (66, 112, 66), (100, 146, 84)]
    blob(img, cx, top - 3, height // 2 + 3, height // 4 + 2, cols, rnd)
    for x in range(cx - height // 2 - 2, cx + height // 2 + 3, 2):  # strands hang from the canopy
        drop = rnd.randint(4, 12)
        for k in range(drop):
            put(img, x, top + 1 + k, cols[1] if k % 2 else cols[0])
    outline(img, OUTLINE[biome])
    return img


def make_camp():
    sprites = {}
    for biome in BIOMES:
        rnd = random.Random(sum(map(ord, biome)) * 7 + 1)
        sprites[f"tent-{biome}"] = tent(biome, rnd)
        sprites[f"totem-{biome}"] = totem(biome, rnd)
        sprites[f"skull-{biome}"] = skull_stake(biome, rnd)
        sprites[f"bones-{biome}-0"] = bones(biome, rnd, 0)
        sprites[f"bones-{biome}-1"] = bones(biome, rnd, 1)
        sprites[f"rack-{biome}"] = drying_rack(biome, rnd)
        sprites[f"firewood-{biome}"] = firewood(biome, rnd)
        sprites[f"stump-{biome}"] = stump(biome, rnd)
        sprites[f"fern-{biome}-0"] = fern(biome, rnd, 7)
        sprites[f"fern-{biome}-1"] = fern(biome, rnd, 10)
        sprites[f"tuft-{biome}"] = tuft(biome, rnd)
        sprites[f"spears-{biome}"] = spears(biome, rnd)
        sprites[f"menhir-{biome}"] = menhir(biome, rnd)
        sprites[f"firepit-{biome}"] = firepit(biome, rnd)
    for i, h in enumerate((30, 40)):
        sprites[f"cattail-swamp-{i}"] = cattail("swamp", random.Random(i + 3))
        sprites[f"tree-swamp-{3 + i}"] = willow("swamp", random.Random(i + 11), h + 6)
    return sprites


# ================================================================================================================
# Trees that grow: a sprout, a sapling and a young tree per biome (the game shows them in turn, then the full tree)
# ================================================================================================================
def sprout(biome, rnd, variant):
    img = new(9, 10)
    leaf = (96, 176, 84) if biome != "swamp" else (120, 160, 84)
    if biome == "snow":
        leaf = (110, 170, 110)
    rect(img, 4, 4, 1, 6, (110, 84, 52))
    for k in range(3):
        put(img, 3 - k, 4 - k // 2, leaf); put(img, 5 + k, 3 - k // 2, leaf)
    put(img, 4, 2, leaf); put(img, 4, 3, leaf)
    outline(img, OUTLINE[biome])
    return img


def sapling(biome, rnd, variant):
    if biome == "snow" or (variant == 1 and biome in ("meadow", "forest")):
        return pine_tree(biome, rnd, 16, snowy=(biome == "snow"))
    if biome == "swamp":
        img = new(12, 18)
        rect(img, 5, 5, 1, 13, TRUNK["swamp"])
        for k in range(4):
            put(img, 6 + k // 2, 6 - k, TRUNK["swamp"]); put(img, 4 - k // 2, 8 - k, TRUNK["swamp"])
        for m in range(4):
            put(img, 8, 5 + m, MOSS)
        outline(img, OUTLINE[biome])
        return img
    img = new(14, 18)
    rect(img, 6, 9, 1, 9, TRUNK[biome])
    cols = LEAF["meadow" if biome != "forest" else "forest"] if biome in ("meadow", "forest") else [(40, 96, 60), (60, 120, 76), (90, 150, 96)]
    blob(img, 6, 6, 5, 5, cols, rnd)
    outline(img, OUTLINE[biome])
    return img


def young(biome, rnd, variant):
    if biome == "swamp":
        return dead_tree(biome, rnd, 26) if variant == 0 else willow(biome, rnd, 22)
    if variant == 1 or biome == "snow":
        return pine_tree(biome, rnd, 28, snowy=(biome == "snow"))
    return round_tree(biome, rnd, 24)


def make_growth():
    sprites = {}
    for biome in BIOMES:
        rnd = random.Random(sum(map(ord, biome)) * 13 + 5)
        for v in (0, 1):
            sprites[f"sprout-{biome}-{v}"] = sprout(biome, rnd, v)
            sprites[f"sapling-{biome}-{v}"] = sapling(biome, rnd, v)
            sprites[f"young-{biome}-{v}"] = young(biome, rnd, v)
    return sprites


# ================================================================================================================
# The farm: a tilled plot (soil in furrows), and three crops (wheat, pumpkin, greens) in three stages: sprout, growing, ripe
# ================================================================================================================
SOIL = {"meadow": [(112, 80, 48), (96, 68, 40), (130, 96, 60)], "forest": [(100, 72, 44), (86, 60, 36), (118, 86, 54)],
        "snow": [(120, 96, 76), (104, 82, 64), (140, 114, 92)], "swamp": [(88, 68, 44), (74, 56, 36), (104, 82, 54)]}


def plot(biome, rnd):
    """A tilled bed: rows of turned earth between low ridges, with a stake at each corner."""
    W, H = 30, 20
    img = new(W, H)
    cols = SOIL[biome]
    for y in range(H):
        for x in range(W):
            if x in (0, W - 1) or y in (0, H - 1):
                put(img, x, y, cols[1])
            else:
                put(img, x, y, cols[0] if (y // 3) % 2 == 0 else cols[2])
                if rnd.random() < 0.08:
                    put(img, x, y, cols[1])
    for x in range(1, W - 1):
        if (x // 5) % 2 == 0:
            put(img, x, 2, cols[2])
    for cx, cy in ((0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)):
        rect(img, cx - (1 if cx else 0), cy - 3, 2, 4, WOOD)
    outline(img, (44, 30, 22))
    return img


def crop(kind, stage, rnd):
    """kind 0 wheat, 1 pumpkin, 2 greens; stage 0 sprout, 1 growing, 2 ripe. Drawn as one clump standing on its bottom centre."""
    img = new(12, 16)
    cx = 6
    if kind == 0:  # wheat: green stalks turning gold with a head of grain
        h = (4, 9, 13)[stage]
        for dx in (-3, -1, 1, 3):
            top = 15 - h + abs(dx) // 2
            for y in range(top, 16):
                put(img, cx + dx, y, (96, 160, 70) if stage < 2 else (196, 164, 70))
            if stage == 2:
                for k in range(3):
                    put(img, cx + dx, top - k, (230, 196, 90)); put(img, cx + dx + (1 if k == 1 else 0), top - k, (230, 196, 90))
    elif kind == 1:  # pumpkin: broad leaves, and a round orange pumpkin when ripe
        leaf = (70, 140, 60)
        for dx in range(-4, 5):
            put(img, cx + dx, 15 - (abs(dx) // 3), leaf)
            if stage >= 1:
                put(img, cx + dx, 14 - (abs(dx) // 2), leaf)
        if stage == 2:
            blob(img, cx, 12, 4, 3, [(196, 92, 20), (238, 132, 28), (250, 168, 60)], rnd)
            put(img, cx, 8, (60, 110, 50)); put(img, cx, 9, (60, 110, 50))
        elif stage == 1:
            blob(img, cx, 13, 2, 2, [(90, 130, 40), (120, 168, 60), (150, 190, 80)], rnd)
    else:  # greens: a leafy rosette with a red root showing when ripe
        h = (3, 6, 9)[stage]
        for k in range(-h // 2, h // 2 + 1):
            put(img, cx + k, 15 - h + abs(k), (84, 168, 84))
            put(img, cx + k, 15 - h + abs(k) + 1, (60, 140, 66))
        for y in range(15 - h + 2, 16):
            put(img, cx, y, (70, 150, 70))
        if stage == 2:
            rect(img, cx - 1, 13, 3, 3, (206, 60, 70)); put(img, cx, 16 - 1, (150, 40, 50))
    outline(img, (30, 60, 36))
    return img


def make_farm():
    sprites = {}
    for biome in BIOMES:
        sprites[f"plot-{biome}"] = plot(biome, random.Random(sum(map(ord, biome)) + 77))
    for kind in range(3):
        for stage in range(3):
            sprites[f"crop-{kind}-{stage}"] = crop(kind, stage, random.Random(kind * 10 + stage))
    return sprites


# ================================================================================================================
# Seasonal things round the camp: a snowman (winter), a hay bale and pumpkins (autumn)
# ================================================================================================================
def snowman(rnd):
    img = new(16, 22)
    blob(img, 8, 14, 5, 5, [(206, 218, 236), (240, 246, 252), (255, 255, 255)], rnd)
    blob(img, 8, 6, 3, 3, [(206, 218, 236), (240, 246, 252), (255, 255, 255)], rnd)
    put(img, 7, 6, (30, 30, 34)); put(img, 9, 6, (30, 30, 34))
    put(img, 8, 5, (236, 120, 40)); put(img, 9, 5, (236, 120, 40))            # carrot nose
    for x in range(5, 12):
        put(img, x, 9, (200, 50, 60))                                        # scarf
    put(img, 5, 10, (200, 50, 60)); put(img, 5, 11, (200, 50, 60))
    for k in range(4):
        put(img, 3 - k, 12 - k // 2, (110, 74, 40)); put(img, 13 + k, 12 - k // 2, (110, 74, 40))   # stick arms
    rect(img, 6, 0, 5, 2, (40, 36, 44)); rect(img, 5, 2, 7, 1, (40, 36, 44))  # a hat
    put(img, 8, 13, (30, 30, 34)); put(img, 8, 15, (30, 30, 34))
    outline(img, (60, 80, 110))
    return img


def hay(rnd):
    img = new(20, 12)
    blob(img, 10, 6, 9, 4, [(170, 132, 50), (222, 186, 84), (244, 216, 122)], rnd)
    for x in range(3, 18, 3):
        put(img, x, 4, (150, 112, 40)); put(img, x + 1, 8, (150, 112, 40))
    rect(img, 4, 5, 12, 1, (150, 100, 44))                                   # a binding
    outline(img, (90, 66, 30))
    return img


def pumpkins(rnd):
    img = new(22, 12)
    for cx, cy, r in ((6, 7, 4), (14, 6, 5), (10, 9, 3)):
        blob(img, cx, cy, r, max(2, r - 1), [(190, 88, 18), (236, 130, 28), (250, 168, 60)], rnd)
        put(img, cx, cy - r + 1, (60, 110, 50))
    outline(img, (90, 44, 20))
    return img


def make_seasonal():
    rnd = random.Random(31)
    return {"snowman": snowman(rnd), "hay": hay(rnd), "pumpkins": pumpkins(rnd)}


if __name__ == "__main__":
    main()
