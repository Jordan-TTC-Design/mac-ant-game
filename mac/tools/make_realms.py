#!/usr/bin/env python3
"""Draws the two race terrains (RACES.md): the elves' ancient forest (精靈古林) and the undead graveyard (死靈墓地), in the same
style as tools/make_terrain.py (one art pixel = two points, a dark outline, light from the top left, every sprite standing on
its bottom-centre pixel).

    python3 tools/make_realms.py --preview /path/prefix    # writes prefix-elfwood.png and prefix-graveyard.png (sample scenes)
    python3 tools/make_realms.py --write                   # also writes the sprites to Resources/Terrain

The scenes are only a picture of what a camp in that terrain would look like (terraces, giant trees, the soul tower…); the game
lays out its own scenes (Terrain.swift) once these terrains are wired in.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_terrain as mt  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

put, rect, blob, outline, new = mt.put, mt.rect, mt.blob, mt.outline, mt.new
RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources")

# --- the ancient forest -------------------------------------------------------------------------------------------
EW_OUT = (16, 42, 36)
EW_GROUND = [(50, 100, 70), (42, 88, 60), (62, 116, 78), (84, 108, 60)]
EW_LEAF = [(22, 70, 54), (34, 96, 68), (62, 138, 88)]
EW_LEAF_GOLD = [(150, 96, 30), (206, 150, 46), (246, 206, 90)]     # autumn
EW_BARK = (100, 72, 50)
EW_BARK_LIGHT = (140, 106, 70)
EW_MOSS = (86, 150, 84)
GLOW = (150, 230, 240)


def ew_ground(rnd):
    img = Image.new("RGBA", (32, 32), EW_GROUND[0] + (255,))
    for _ in range(100):
        put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(EW_GROUND))
    for _ in range(10):                                                    # leaf litter
        put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice([(150, 116, 56), (124, 96, 44), (176, 140, 70)]))
    for _ in range(3):                                                     # tiny white flowers
        put(img, rnd.randrange(32), rnd.randrange(32), (240, 244, 236))
    return img


def ancient_tree(rnd, height, leaf=EW_LEAF):
    """A tall old tree: a thick trunk flaring into roots, and a wide, layered crown."""
    w = height * 4 // 5 + 10
    img = new(w, height + 3)
    cx, base = w // 2, height
    th = height * 2 // 5
    for y in range(base - th, base + 1):
        flare = max(0, 3 - (base - y)) if y > base - 3 else 0
        rect(img, cx - 2 - flare, y, 5 + 2 * flare, 1, EW_BARK)
        put(img, cx - 1 - flare, y, EW_BARK_LIGHT)
    for k in range(3):                                                     # moss patches on the trunk
        put(img, cx + rnd.randint(-2, 2), base - rnd.randint(2, th - 2), EW_MOSS)
    r = (height - th) // 2 + 2
    blob(img, cx, base - th - r + 4, r + 4, r, leaf, rnd)
    for _ in range(5):
        blob(img, cx + rnd.randint(-r, r), base - th - r + rnd.randint(-3, 6), rnd.randint(3, 5), rnd.randint(3, 4), leaf, rnd)
    outline(img, EW_OUT)
    return img


def giant_tree(rnd, leaf=EW_LEAF):
    """A giant: bigger than the camp. A trunk ten pixels wide, roots across the ground, a crown that shades a whole patch."""
    w, h = 110, 120
    img = new(w, h)
    cx, base = w // 2, h - 4
    # roots spreading along the ground
    for side in (-1, 1):
        for k in range(3):
            length = rnd.randint(14, 24)
            y = base - k
            for i in range(length):
                x = cx + side * (6 + i)
                yy = y + (i // 6)
                rect(img, x, yy, 1, 2 if i < length - 4 else 1, EW_BARK)
    for y in range(base - 52, base + 1):
        half = 5 + max(0, (y - (base - 10))) // 2
        rect(img, cx - half, y, half * 2 + 1, 1, EW_BARK)
        put(img, cx - half + 1, y, EW_BARK_LIGHT)
        put(img, cx - half + 2, y, EW_BARK_LIGHT)
        if y % 7 == 0:
            put(img, cx + rnd.randint(-3, 3), y, (78, 54, 36))            # bark grain
    for _ in range(8):
        put(img, cx + rnd.randint(-5, 5), base - rnd.randint(4, 48), EW_MOSS)
    rect(img, cx - 2, base - 22, 4, 5, (50, 34, 24))                       # a hollow in the trunk
    blob(img, cx, base - 78, 46, 30, leaf, rnd)
    for _ in range(9):
        blob(img, cx + rnd.randint(-40, 40), base - 78 + rnd.randint(-22, 18), rnd.randint(8, 13), rnd.randint(6, 9), leaf, rnd)
    outline(img, EW_OUT)
    return img


def blossom_bush(rnd):
    img = new(22, 12)
    blob(img, 11, 6, 9, 5, EW_LEAF, rnd)
    for _ in range(10):
        put(img, 11 + rnd.randint(-8, 8), 6 + rnd.randint(-4, 3), (250, 244, 250) if rnd.random() < 0.7 else (246, 196, 214))
    outline(img, EW_OUT)
    return img


def berry_bush(rnd):
    img = new(20, 12)
    blob(img, 10, 6, 8, 5, EW_LEAF, rnd)
    for _ in range(7):
        put(img, 10 + rnd.randint(-7, 7), 6 + rnd.randint(-3, 3), (90, 96, 210))
    outline(img, EW_OUT)
    return img


def mushroom_ring(rnd):
    """A ring of pale mushrooms that glow a little at night."""
    img = new(30, 16)
    for k in range(9):
        a = k / 9 * 2 * math.pi
        x, y = 15 + int(11 * math.cos(a)), 8 + int(5 * math.sin(a))
        put(img, x, y + 1, (236, 228, 214))
        rect(img, x - 1, y - 1, 3, 1, (190, 226, 236))
        put(img, x, y - 2, (220, 244, 250))
    outline(img, EW_OUT)
    return img


def lantern_post(rnd):
    img = new(9, 22)
    rect(img, 4, 6, 1, 16, EW_BARK)
    rect(img, 4, 5, 4, 1, EW_BARK)
    rect(img, 6, 6, 3, 4, (250, 214, 110))
    put(img, 7, 7, (255, 248, 210))
    rect(img, 6, 10, 3, 1, (120, 80, 40))
    outline(img, EW_OUT)
    return img


def moss_rock(rnd, size):
    img = mt.rock("forest", rnd, size)
    return img


# --- the graveyard -----------------------------------------------------------------------------------------------------
GY_OUT = (24, 24, 32)
GY_GROUND = [(70, 72, 74), (60, 62, 66), (84, 84, 82), (78, 70, 60)]
GY_STONE = [(96, 100, 110), (132, 138, 146), (70, 72, 82)]
GY_BARK = (78, 70, 66)
SOUL = [(120, 230, 210), (190, 255, 240), (70, 170, 170)]


def gy_ground(rnd):
    img = Image.new("RGBA", (32, 32), GY_GROUND[0] + (255,))
    for _ in range(110):
        put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(GY_GROUND))
    for _ in range(6):                                                     # dead grass
        x, y = rnd.randrange(1, 31), rnd.randrange(1, 31)
        put(img, x, y, (112, 104, 76)); put(img, x, y - 1, (96, 90, 66))
    for _ in range(2):
        put(img, rnd.randrange(32), rnd.randrange(32), (220, 214, 196))    # a bit of bone
    return img


def dead_tree(rnd, height):
    w = height * 2 // 3 + 10
    img = new(w, height + 2)
    cx, base = w // 2, height
    x = cx
    for y in range(base, base - height * 3 // 4, -1):
        if y % 4 == 0:
            x += rnd.choice((0, 1, -1))
        rect(img, x - 1, y, 3 if y > base - height // 3 else 2, 1, GY_BARK)
    top = base - height * 3 // 4
    for side in (-1, 1):
        for start in (top + 2, top + height // 5):
            bx, by = x, start
            for k in range(rnd.randint(5, 9)):
                bx += side
                by -= 1 if k % 2 == 0 else 0
                put(img, bx, by, GY_BARK)
                if k == 4:                                                 # a twig
                    put(img, bx, by - 1, GY_BARK); put(img, bx, by - 2, GY_BARK)
    outline(img, GY_OUT)
    return img


def gravestone(rnd, kind):
    if kind == 0:                                                          # rounded headstone
        img = new(12, 16)
        rect(img, 2, 4, 8, 11, GY_STONE[1])
        rect(img, 3, 2, 6, 2, GY_STONE[1])
        rect(img, 8, 4, 2, 11, GY_STONE[2])
        rect(img, 4, 7, 4, 1, GY_STONE[2]); rect(img, 4, 9, 4, 1, GY_STONE[2])
        put(img, 3, 12, mt.MOSS)
    elif kind == 1:                                                        # a leaning wooden cross
        img = new(12, 18)
        for y in range(3, 17):
            put(img, 5 + (y < 8), y, (110, 84, 60)); put(img, 6 + (y < 8), y, (90, 66, 46))
        rect(img, 2, 6, 9, 2, (110, 84, 60))
    else:                                                                  # a stone coffin
        img = new(24, 12)
        rect(img, 2, 3, 20, 7, GY_STONE[1])
        rect(img, 2, 8, 20, 2, GY_STONE[2])
        rect(img, 10, 4, 4, 1, GY_STONE[0]); rect(img, 11, 3, 2, 3, GY_STONE[0])
    outline(img, GY_OUT)
    return img


def soul_tower(rnd, stage=3):
    """The undead camp: a narrow stone tower with the soul fire burning on top (taller at each stage)."""
    h = {1: 36, 2: 48, 3: 62}[stage]
    img = new(34, h + 16)
    cx, base = 17, h + 14
    for y in range(base - h, base + 1):
        half = 6 + (base - y < 6) * 2
        rect(img, cx - half, y, half * 2 + 1, 1, GY_STONE[1] if (y // 4) % 2 else (122, 128, 136))
        put(img, cx + half, y, GY_STONE[2]); put(img, cx + half - 1, y, GY_STONE[2])
    for y in range(base - h + 6, base - 4, 12):                            # glowing windows
        rect(img, cx - 1, y, 3, 4, SOUL[0])
        put(img, cx, y + 1, SOUL[1])
    rect(img, cx - 3, base - 5, 7, 6, (30, 30, 40))                        # the doorway
    rect(img, cx - 8, base - h - 2, 17, 3, GY_STONE[2])                    # the brazier on top
    for k, (dx, dy) in enumerate([(0, -4), (-2, -3), (2, -3), (-1, -6), (1, -7), (0, -9), (-3, -1), (3, -1)]):
        put(img, cx + dx, base - h - 2 + dy, SOUL[1] if k in (0, 3, 5) else SOUL[0])
    outline(img, GY_OUT)
    return img


def tower_camp(stage):
    """The soul tower as a camp look (the size of the other camps): a stone tower, glowing windows, the soul fire on top, a door."""
    w, h = {1: (24, 26), 2: (28, 32), 3: (32, 40)}[stage]
    img = new(w, h)
    cx, base = w // 2, h - 2
    body_top = 7
    for y in range(body_top, base + 1):
        half = (w // 2 - 5) + (2 if base - y < 3 else 0)
        rect(img, cx - half, y, half * 2, 1, GY_STONE[1] if (y // 3) % 2 else (122, 128, 136))
        put(img, cx + half - 1, y, GY_STONE[2]); put(img, cx + half - 2, y, GY_STONE[2])
    for y in range(body_top + 3, base - 6, 7):
        rect(img, cx - 1, y, 2, 3, SOUL[0])
        put(img, cx - 1, y, SOUL[1])
    rect(img, cx - 2, base - 4, 4, 5, (30, 30, 40))                        # the door
    rect(img, cx - (w // 2 - 3), body_top - 1, (w // 2 - 3) * 2, 2, GY_STONE[2])   # the brazier
    for k, (dx, dy) in enumerate([(0, -2), (-1, -3), (1, -3), (0, -5), (-2, -2), (2, -2), (0, -6)]):
        put(img, cx - 1 + dx, body_top - 1 + dy, SOUL[1] if k in (0, 3, 6) else SOUL[0])
    if stage >= 2:                                                         # bones heaped at its foot
        for x in (cx - half - 2, cx + half + 1):
            rect(img, x, base - 1, 2, 1, mt.BONE)
    if stage == 3:
        put(img, 1, base - 8, SOUL[0]); put(img, w - 2, base - 12, SOUL[0])   # souls circling it
    outline(img, GY_OUT)
    return img


def wisp(rnd):
    img = new(7, 9)
    rect(img, 2, 2, 3, 4, SOUL[0]); put(img, 3, 1, SOUL[0]); put(img, 3, 3, SOUL[1])
    put(img, 3, 6, SOUL[2]); put(img, 2, 7, SOUL[2])
    return img


def bone_pile(rnd):
    img = new(20, 10)
    for k in range(7):
        x, y = rnd.randint(3, 15), rnd.randint(3, 6)
        rect(img, x, y, 4, 1, mt.BONE); put(img, x, y + 1, mt.BONE_SHADE)
    rect(img, 8, 2, 3, 3, mt.BONE)                                         # a skull on top
    put(img, 8, 3, (40, 36, 36)); put(img, 10, 3, (40, 36, 36))
    outline(img, GY_OUT)
    return img


# --- sample scenes ------------------------------------------------------------------------------------------------------
def tile(scene, ground):
    for y in range(0, scene.height, 32):
        for x in range(0, scene.width, 32):
            scene.alpha_composite(ground, (x, y))


def stand(scene, sprite, x, y):
    """Place a sprite by its foot (bottom-centre)."""
    scene.alpha_composite(sprite, (x - sprite.width // 2, y - sprite.height + 1))


def terrace(scene, rnd, edge_y, top_col, face, lip, steps_at):
    """A raised shelf across the scene: its top from the top of the picture down to a wavy edge, then a cliff face with a shadow
    below; stone steps cut into it at `steps_at`."""
    px = scene.load()
    ys = []
    y = edge_y
    for x in range(scene.width):
        if x % 6 == 0:
            y = max(edge_y - 6, min(edge_y + 6, y + rnd.choice((-1, 0, 0, 1))))
        ys.append(y)
    for x in range(scene.width):
        for yy in range(0, ys[x]):
            r, g, b, a = px[x, yy]
            px[x, yy] = tuple(min(255, int(c * 1.12 + 6)) for c in (r, g, b)) + (255,)   # the shelf is in the sun
        px[x, ys[x]] = lip + (255,)
        for k in range(1, 9):
            px[x, ys[x] + k] = (face[0] if k < 5 else face[1]) + (255,) if (x + k) % 7 else face[2] + (255,)
        for k in range(9, 12):                                             # its shadow on the ground below
            r, g, b, a = px[x, min(scene.height - 1, ys[x] + k)]
            px[x, min(scene.height - 1, ys[x] + k)] = (int(r * 0.78), int(g * 0.78), int(b * 0.8), 255)
    for sx in steps_at:                                                    # stone steps
        top = ys[sx]
        for k in range(4):
            rect(scene, sx - 5, top + 1 + k * 2, 11, 2, (150, 150, 146) if k % 2 == 0 else (124, 124, 120))
        rect(scene, sx - 6, top + 1, 1, 9, (90, 90, 88)); rect(scene, sx + 6, top + 1, 1, 9, (90, 90, 88))
    return ys


def pond(scene, cx, cy, rx, ry, water, rim, rnd):
    draw = ImageDraw.Draw(scene)
    draw.ellipse([cx - rx - 2, cy - ry - 2, cx + rx + 2, cy + ry + 2], fill=rim)
    draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=water[0])
    draw.ellipse([cx - rx + 3, cy - ry + 2, cx + rx - 3, cy + ry - 2], fill=water[1])
    for _ in range(6):
        a = rnd.random() * 2 * math.pi
        rect(scene, int(cx + (rx + 2) * math.cos(a)), int(cy + (ry + 2) * math.sin(a)), 3, 2, (140, 146, 150))


def camp_image(kind):
    return Image.open(os.path.join(RES, "Camps", kind, "stage3.png")).convert("RGBA")


def elfwood_scene(night=False):
    rnd = random.Random(7)
    W, H = 320, 200
    scene = Image.new("RGBA", (W, H))
    tile(scene, ew_ground(random.Random(3)))
    edge = terrace(scene, rnd, 62, None, [(120, 92, 60), (96, 72, 48), (80, 60, 40)], (96, 150, 90), steps_at=[140])
    items = []
    # the shelf behind the camp: giant trees and a thick wall of ancient ones
    items.append((giant_tree(random.Random(11)), 70, 58))
    items.append((giant_tree(random.Random(12)), 250, 52))
    for x in range(8, W, 22):
        if abs(x - 70) > 40 and abs(x - 250) > 40:
            items.append((ancient_tree(rnd, rnd.randint(40, 54)), x + rnd.randint(-4, 4), rnd.randint(28, 50)))
    # the lower ground: the camp in a clearing, the moon pool, bushes, a ring of mushrooms, lanterns
    pond(scene, 236, 150, 26, 12, [(96, 150, 200), (150, 200, 232)], (70, 110, 80), rnd)
    items.append((camp_image("stump"), 140, 128))
    items.append((mushroom_ring(rnd), 70, 160))
    items.append((lantern_post(rnd), 112, 118)); items.append((lantern_post(rnd), 172, 122))
    # the forest closes in all round the clearing (twice as thick as an ordinary forest)
    for x, y in [(30, 110), (290, 110), (20, 190), (300, 188), (180, 196), (96, 192), (8, 150), (312, 150), (54, 196), (140, 198),
                 (226, 198), (262, 198), (34, 86), (286, 84), (300, 128)]:
        items.append((ancient_tree(rnd, rnd.randint(38, 50)), x, y))
    for x, y in [(60, 120), (200, 110), (270, 180), (40, 150)]:
        items.append((blossom_bush(rnd) if rnd.random() < 0.5 else berry_bush(rnd), x, y))
    items.append((moss_rock(rnd, 9), 210, 176))
    for sprite, x, y in sorted(items, key=lambda t: t[2]):
        stand(scene, sprite, x, y)
    if night:
        scene = nightfall(scene, (40, 50, 90), 0.5)
        light = Image.new("RGBA", scene.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(light)
        for x, y in [(115, 108), (175, 112)]:                             # lantern light
            d.ellipse([x - 10, y - 8, x + 10, y + 8], fill=(250, 214, 110, 46))
            d.ellipse([x - 5, y - 4, x + 5, y + 4], fill=(250, 214, 110, 60))
        for k in range(9):                                                 # the mushroom ring glows
            a = k / 9 * 2 * math.pi
            x, y = 70 + int(11 * math.cos(a)), 152 + int(5 * math.sin(a))
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=GLOW + (90,))
        scene = Image.alpha_composite(scene, light)
        for _ in range(45):                                                # fireflies
            put(scene, rnd.randrange(W), rnd.randrange(H), (230, 250, 150))
    return scene


def nightfall(scene, tint, amount):
    over = Image.new("RGBA", scene.size, tint + (int(255 * amount),))
    return Image.alpha_composite(scene, over)


def graveyard_scene():
    rnd = random.Random(5)
    W, H = 320, 200
    scene = Image.new("RGBA", (W, H))
    tile(scene, gy_ground(random.Random(9)))
    pond(scene, 60, 150, 22, 10, [(44, 68, 54), (58, 88, 66)], (60, 56, 50), rnd)
    items = [(soul_tower(rnd), 160, 118)]
    for x, y in [(20, 60), (80, 40), (250, 50), (300, 90), (30, 120), (290, 170), (110, 186), (220, 192)]:
        items.append((dead_tree(rnd, rnd.randint(34, 48)), x, y))
    for k in range(18):
        x, y = rnd.randint(90, 300), rnd.randint(60, 190)
        if abs(x - 160) < 28 and 90 < y < 130:
            continue
        items.append((gravestone(rnd, rnd.choice((0, 0, 1, 2))), x, y))
    for x, y in [(200, 140), (100, 110), (250, 120)]:
        items.append((bone_pile(rnd), x, y))
    for sprite, x, y in sorted(items, key=lambda t: t[2]):
        stand(scene, sprite, x, y)
    scene = nightfall(scene, (30, 30, 60), 0.28)
    fog = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(fog)
    for k in range(7):                                                     # low wisps of fog, in soft lumps
        cx, cy = rnd.randint(0, W), rnd.randint(50, 195)
        for j in range(6):
            x = cx + j * 9 + rnd.randint(-3, 3)
            d.ellipse([x - 10, cy - 3 + rnd.randint(-1, 1), x + 10, cy + 3], fill=(214, 222, 236, 22))
    scene = Image.alpha_composite(scene, fog)
    light = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(light)
    d.ellipse([130, 30, 190, 70], fill=SOUL[0] + (30,))                    # the soul fire lights the tower top
    d.ellipse([145, 40, 175, 60], fill=SOUL[0] + (40,))
    scene = Image.alpha_composite(scene, light)
    for _ in range(14):                                                    # wandering souls
        stand(scene, wisp(rnd), rnd.randint(10, W - 10), rnd.randint(20, H - 10))
    return scene


def register_palettes():
    """Teach tools/make_terrain.py the two new terrains' colours, so its tents, rocks, logs, stumps, plots, saplings… come out in them."""
    mt.OUTLINE.update(elfwood=EW_OUT, graveyard=GY_OUT)
    mt.GROUND.update(elfwood=EW_GROUND, graveyard=GY_GROUND)
    mt.LEAF.update(elfwood=EW_LEAF, graveyard=[(70, 80, 64), (90, 100, 78), (110, 118, 92)])
    mt.TRUNK.update(elfwood=EW_BARK, graveyard=GY_BARK)
    mt.STONE.update(elfwood=mt.STONE["forest"], graveyard=GY_STONE)
    mt.HIDE.update(elfwood=(150, 120, 80), graveyard=(96, 88, 84))
    mt.SOIL.update(elfwood=mt.SOIL["forest"], graveyard=[(84, 76, 70), (70, 64, 58), (100, 92, 84)])


def full_set(biome):
    """Everything a terrain needs under its own name (the game looks sprites up as kind-biome[-n])."""
    register_palettes()
    rnd = random.Random(sum(map(ord, biome)))
    out = {}
    for i, size in enumerate((6, 9, 13)):
        out[f"rock-{biome}-{i}"] = mt.rock(biome, rnd, size)
    for i, size in enumerate((5, 8)):
        out[f"bush-{biome}-{i}"] = mt.bush(biome, rnd, size) if biome != "elfwood" else (blossom_bush(rnd) if i == 0 else berry_bush(rnd))
    out[f"log-{biome}"] = mt.log(biome, rnd)
    crnd = random.Random(sum(map(ord, biome)) * 7 + 1)
    for name, fn in (("tent", mt.tent), ("totem", mt.totem), ("skull", mt.skull_stake), ("rack", mt.drying_rack),
                     ("firewood", mt.firewood), ("stump", mt.stump), ("tuft", mt.tuft), ("spears", mt.spears),
                     ("menhir", mt.menhir), ("firepit", mt.firepit)):
        out[f"{name}-{biome}"] = fn(biome, crnd)
    out[f"bones-{biome}-0"] = mt.bones(biome, crnd, 0)
    out[f"bones-{biome}-1"] = mt.bones(biome, crnd, 1)
    out[f"fern-{biome}-0"] = mt.fern(biome, crnd, 7)
    out[f"fern-{biome}-1"] = mt.fern(biome, crnd, 10)
    grnd = random.Random(sum(map(ord, biome)) * 13 + 5)
    for v in (0, 1):
        out[f"sprout-{biome}-{v}"] = mt.sprout(biome, grnd, v)
        out[f"sapling-{biome}-{v}"] = mt.sapling(biome, grnd, v) if biome != "graveyard" else dead_tree(grnd, 16)
        out[f"young-{biome}-{v}"] = ancient_tree(grnd, 28) if biome == "elfwood" else dead_tree(grnd, 26)
    out[f"plot-{biome}"] = mt.plot(biome, random.Random(sum(map(ord, biome)) + 77))
    if biome == "elfwood":                                                 # its tents are grown over with moss, its stones mossy
        pass
    if biome == "graveyard":                                               # gravestones stand in for the menhir, bones for the skull stake
        out["menhir-graveyard"] = gravestone(crnd, 0)
    return out


def sprites():
    rnd = random.Random(1)
    out = {"ground-elfwood": ew_ground(random.Random(3)), "ground-graveyard": gy_ground(random.Random(9))}
    for i, hgt in enumerate((42, 50, 56)):
        out[f"tree-elfwood-{i}"] = ancient_tree(rnd, hgt)
    out["giant-elfwood-0"] = giant_tree(random.Random(11))
    out["giant-elfwood-1"] = giant_tree(random.Random(12))
    out["blossom-elfwood"] = blossom_bush(rnd)
    out["berries-elfwood"] = berry_bush(rnd)
    out["mushrooms-elfwood"] = mushroom_ring(rnd)
    out["lantern-elfwood"] = lantern_post(rnd)
    for i, hgt in enumerate((36, 42, 48)):
        out[f"tree-graveyard-{i}"] = dead_tree(rnd, hgt)
    for i in range(3):
        out[f"grave-graveyard-{i}"] = gravestone(rnd, i)
    out["bonepile-graveyard"] = bone_pile(rnd)
    out["wisp-graveyard"] = wisp(rnd)
    for stage in (1, 2, 3):
        out[f"soultower-{stage}"] = soul_tower(rnd, stage)
    out.update(full_set("elfwood"))
    out.update(full_set("graveyard"))
    return out


def main():
    if "--write" in sys.argv:
        for name, img in sprites().items():
            img.save(os.path.join(RES, "Terrain", name + ".png"))
        camp = os.path.join(RES, "Camps", "soultower")
        os.makedirs(camp, exist_ok=True)
        stages = []
        for stage, count in ((1, 0), (2, 30), (3, 90)):
            img = tower_camp(stage)
            img.save(os.path.join(camp, f"stage{stage}.png"))
            stages.append({"sheet": f"stage{stage}.png", "minCount": count, "entrance": [img.width // 2, img.height - 3]})
        import json
        with open(os.path.join(camp, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump({"id": "soultower", "name": "魂塔", "blurb": "石頭砌的細塔，塔頂燒著靈魂之火，窗戶透出青光。", "pixelScale": 1.5,
                       "stages": stages}, f, ensure_ascii=False, indent=2)
            f.write("\n")
    if "--preview" in sys.argv:
        prefix = sys.argv[sys.argv.index("--preview") + 1]
        zoom = 3
        day = elfwood_scene()
        night = elfwood_scene(night=True)
        both = Image.new("RGBA", (day.width * 2 + 6, day.height), (0, 0, 0, 255))
        both.paste(day, (0, 0)); both.paste(night, (day.width + 6, 0))
        both.resize((both.width * zoom, both.height * zoom), Image.NEAREST).save(prefix + "-elfwood.png")
        g = graveyard_scene()
        g.resize((g.width * zoom, g.height * zoom), Image.NEAREST).save(prefix + "-graveyard.png")
        print("wrote", prefix + "-elfwood.png", prefix + "-graveyard.png")


if __name__ == "__main__":
    main()
