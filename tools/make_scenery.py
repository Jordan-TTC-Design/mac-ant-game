#!/usr/bin/env python3
"""Draws the scenery the goblins walk in front of: a forest edge and a meadow strip (tileable sideways), and a grass
ground tile for the map window. Output: Resources/Scenery/*.png. Run: python3 tools/make_scenery.py"""
import os
import random
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Scenery")
W = 128

GRASS = [(58, 116, 62), (48, 100, 54), (74, 138, 74), (66, 128, 68)]
DARK = (24, 62, 44)
PINE = [(30, 76, 56), (38, 92, 64), (24, 60, 44)]
LEAF = [(41, 107, 51), (69, 158, 69), (107, 194, 92)]
TRUNK = (107, 69, 36)
BUSH = [(34, 92, 48), (52, 122, 62)]
FLOWERS = [(240, 220, 90), (240, 120, 150), (250, 250, 250), (150, 160, 240)]


def px(img, x, y, c):
    if 0 <= y < img.height:
        img.putpixel((x % img.width, y), c + (255,) if len(c) == 3 else c)


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(img, xx, yy, c)


def pine(img, cx, base, height, rnd):
    """A pointy pine: stacked triangles."""
    layers = max(3, height // 9)
    for i in range(layers):
        top = base - height + i * (height - 6) // layers
        half = 3 + i * 2
        col = PINE[i % len(PINE)]
        for row in range(half + 4):
            w = min(half, 1 + row * half // (half + 3))
            rect(img, cx - w, top + row, 2 * w + 1, 1, col)
    rect(img, cx - 1, base - 5, 3, 6, TRUNK)


def round_tree(img, cx, base, height, rnd):
    """The game's own round-canopy tree, bigger."""
    r = height // 3
    trunk_h = height // 3
    rect(img, cx - 2, base - trunk_h, 4, trunk_h + 1, TRUNK)
    rect(img, cx - 1, base - trunk_h, 1, trunk_h, (140, 96, 54))
    cy = base - trunk_h - r + 2
    for dy in range(-r, r + 1):
        for dx in range(-r - 2, r + 3):
            if (dx / (r + 2)) ** 2 + (dy / r) ** 2 <= 1:
                shade = 0 if dy > r // 3 else (2 if (dy < -r // 3 and dx < 0) else 1)
                px(img, cx + dx, cy + dy, LEAF[shade])
    for _ in range(4):  # fruit
        px(img, cx + rnd.randint(-r, r), cy + rnd.randint(-r // 2, r // 2), (230, 46, 41))


def bush(img, cx, base, rnd):
    w = rnd.randint(6, 10)
    for dx in range(-w, w + 1):
        h = int((1 - (dx / (w + 1)) ** 2) * (w * 0.7))
        for dy in range(h):
            px(img, cx + dx, base - dy, BUSH[1] if dy > h * 0.5 else BUSH[0])
    if rnd.random() < 0.6:
        px(img, cx + rnd.randint(-w // 2, w // 2), base - rnd.randint(1, w // 2), (220, 60, 90))


def mushroom(img, cx, base):
    rect(img, cx, base - 2, 1, 3, (240, 236, 220))
    rect(img, cx - 1, base - 4, 3, 2, (200, 50, 50))
    px(img, cx, base - 4, (250, 250, 250))


def ground(img, top, rnd, flowers=True, blades=True):
    """The grass floor from row `top` to the bottom edge, with a wavy top edge and specks."""
    for x in range(img.width):
        edge = top + rnd.randint(-1, 1)
        for y in range(edge, img.height):
            px(img, x, y, GRASS[0])
    for _ in range(img.width * (img.height - top) // 6):
        px(img, rnd.randrange(img.width), rnd.randrange(top, img.height), rnd.choice(GRASS))
    if blades:
        for x in range(0, img.width, 2):
            if rnd.random() < 0.6:
                h = rnd.randint(1, 3)
                for k in range(h):
                    px(img, x, top - k, GRASS[2] if k else GRASS[1])
    if flowers:
        for _ in range(img.width // 8):
            x, y = rnd.randrange(img.width), rnd.randrange(top + 2, img.height - 1)
            px(img, x, y, rnd.choice(FLOWERS))


def forest(h=64):
    """A forest edge along the bottom of the screen: `h` pixels tall (the ground takes the bottom 12), tileable sideways."""
    rnd = random.Random(21)
    img = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    k = h / 64.0
    base = h - 14  # where the trees stand; the grass floor begins a little below
    for cx in range(-6, W + 6, 15):  # far pines, darker
        pine(img, cx + rnd.randint(-3, 3), base - 4, max(14, int(rnd.randint(34, 46) * k)), rnd)
    for cx in range(-10, W + 10, 34):
        round_tree(img, cx + rnd.randint(-4, 4), base + 2, max(16, int(rnd.randint(40, 52) * k)), rnd)
    ground(img, h - 12, rnd)
    for cx in range(4, W, 21):
        bush(img, cx + rnd.randint(-3, 3), h - 9, rnd)
    for cx in (30, 88):
        mushroom(img, cx, h - 4)
    return img


def forest_side(width, right=True, height=128):
    """A forest edge down the side of the screen. The whole strip is grass (so the trees stand on the ground instead of hanging in
    the air over the desktop) with upright trees planted on it, each with a little shadow at its foot; the trees higher up are further
    away. Tileable vertically. For `right` the outer (screen edge) side is on the right."""
    rnd = random.Random(33)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    # the ground: grass everywhere, with a ragged inner edge
    for y in range(height):
        edge = rnd.randint(0, 3)
        for x in range(edge, width):
            px(img, x, y, GRASS[0] if x > edge + 1 else GRASS[1])
    for _ in range(width * height // 5):
        px(img, rnd.randrange(1, width), rnd.randrange(height), rnd.choice(GRASS))
    for _ in range(width * height // 60):
        px(img, rnd.randrange(3, width), rnd.randrange(height), rnd.choice(FLOWERS))
    # trees stand on this ground: a shadow and a foot of grass, then the tree, from the far (top) to the near (bottom) one
    slots = list(range(10, height, 30))
    layers = [(base + rnd.randint(-3, 3), rnd.choice(["round", "round", "pine"]), rnd.randint(width // 3, max(width // 3 + 1, width - width // 3))) for base in slots]
    layers.sort()
    tall = max(22, min(40, int(width * 0.8)))
    for base, kind, cx in layers:
        for dy in (-height, 0, height):  # wrap around vertically so the tile repeats
            tmp = Image.new("RGBA", (width, height * 3), (0, 0, 0, 0))
            for ex in range(-6, 7):  # the shadow under it
                px(tmp, cx + ex, base + height + 9, (24, 62, 44, 255))
                if abs(ex) < 5:
                    px(tmp, cx + ex, base + height + 10, (24, 62, 44, 255))
            if kind == "pine":
                pine(tmp, cx, base + height + 9, tall, rnd)
            else:
                round_tree(tmp, cx, base + height + 9, tall, rnd)
            crop = tmp.crop((0, height - dy, width, 2 * height - dy))
            img.alpha_composite(crop)
    for y in (18, 66, 108):
        mushroom_v(img, rnd.randint(4, width - 4), y)
    if not right:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    return img


def mushroom_v(img, x, y):
    rect(img, x - 1, y, 3, 2, (200, 50, 50))
    px(img, x, y, (250, 250, 250))
    rect(img, x - 1, y + 2, 3, 1, (240, 236, 220))


def meadow():
    rnd = random.Random(5)
    img = Image.new("RGBA", (W, 24), (0, 0, 0, 0))
    ground(img, 10, rnd, flowers=True)
    for cx in range(6, W, 23):
        bush(img, cx + rnd.randint(-3, 3), 14, rnd)
    for x in range(0, W, 3):  # taller tufts
        if rnd.random() < 0.5:
            for k in range(rnd.randint(3, 6)):
                px(img, x, 9 - k, GRASS[2])
    return img


def ground_tile():
    rnd = random.Random(9)
    img = Image.new("RGBA", (32, 32), GRASS[0] + (255,))
    for _ in range(90):
        px(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(GRASS))
    for _ in range(3):
        px(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(FLOWERS))
    for _ in range(2):
        x, y = rnd.randrange(2, 30), rnd.randrange(2, 30)
        px(img, x, y, (150, 150, 150)); px(img, x + 1, y, (120, 120, 120)); px(img, x, y + 1, (120, 120, 120))
    return img


def save(name, img):
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))
    print("wrote", name, img.size)


if __name__ == "__main__":
    for h in (30, 42, 54, 64):  # strip heights in points (one art pixel is one point)
        save(f"forest-{h}.png", forest(h))
        save(f"forest-{h}_right.png", forest_side(h, right=True))
        save(f"forest-{h}_left.png", forest_side(h, right=False))
    m = meadow()
    save("meadow.png", m)
    save("meadow_right.png", m.transpose(Image.ROTATE_90))  # the meadow is flat grass, so turning it is fine
    save("meadow_left.png", m.transpose(Image.ROTATE_270))
    save("ground.png", ground_tile())
