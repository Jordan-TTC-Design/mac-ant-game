#!/usr/bin/env python3
"""Draws the camp's buildings (營地建設, ECONOMY.md §1.3; shared/src/camp/buildings.ts) for each race: the warehouse, clinic,
training ground, banquet hall and watchtower at levels 1–3 (each a little bigger and finer than the last), and the wall as
pieces the Mac lays round the camp: a stretch of it (wall_<level>.png) and, from level 2, a tower to stand between stretches
(wall_<level>_tower.png). Output: Resources/Buildings/<race>/<id>_<level>.png and Resources/Buildings/manifest.json.
Run: python3 tools/make_buildings.py [--sheet out.png]

Same look as the terrain and the decorations (make_terrain.py, make_decor.py): one art pixel is two points on screen, a dark
outline, light from the top left; every sprite stands on its bottom-centre pixel."""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_terrain as T  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Buildings")
new, put, rect, outline, shade = T.new, T.put, T.rect, T.outline, T.shade

# each race's stuff: wood, its light, stone (dark, mid, light), roof, cloth, accent, outline
PAL = {
    "goblin": dict(wood=(110, 74, 40), wood_l=(150, 104, 60), wood_d=(78, 50, 28), stone=[(96, 98, 104), (128, 130, 136), (160, 162, 168)],
                   roof=(150, 112, 70), roof_l=(184, 142, 92), cloth=(170, 122, 74), cloth_l=(200, 156, 104), accent=(196, 64, 48),
                   metal=(120, 120, 128), ink=(40, 28, 20), banner=(160, 46, 40)),
    "elf": dict(wood=(170, 132, 84), wood_l=(206, 170, 116), wood_d=(124, 92, 56), stone=[(176, 178, 170), (210, 212, 204), (236, 236, 228)],
                roof=(64, 128, 78), roof_l=(102, 168, 102), cloth=(232, 226, 200), cloth_l=(248, 244, 226), accent=(232, 196, 82),
                metal=(196, 200, 210), ink=(30, 56, 40), banner=(70, 140, 96)),
    "undead": dict(wood=(74, 64, 70), wood_l=(102, 90, 98), wood_d=(52, 44, 50), stone=[(56, 54, 66), (82, 80, 96), (112, 110, 128)],
                   roof=(70, 52, 92), roof_l=(100, 78, 128), cloth=(90, 70, 110), cloth_l=(122, 100, 146), accent=(130, 250, 220),
                   metal=(96, 100, 112), ink=(20, 18, 26), banner=(92, 54, 120)),
}
BONE = (236, 230, 210)
LEVELS = (1, 2, 3)


def line(img, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        put(img, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def stones(img, x, y, w, h, p):
    """A wall of stones in courses (light top-left)."""
    s = p["stone"]
    rect(img, x, y, w, h, s[1])
    for row, yy in enumerate(range(y, y + h, 3)):
        off = 0 if row % 2 else 2
        for xx in range(x - off, x + w, 5):
            for k in range(4):
                put(img, xx + k, yy, s[2] if k == 0 else s[1]) if x <= xx + k < x + w else None
            put(img, xx + 4, yy, s[0]) if x <= xx + 4 < x + w else None
            for k in range(1, 3):
                put(img, xx + 4, yy + k, s[0]) if x <= xx + 4 < x + w and yy + k < y + h else None
        if yy + 2 < y + h:
            rect(img, x, yy + 2, w, 1, s[0])


def planks(img, x, y, w, h, p, vertical=True):
    rect(img, x, y, w, h, p["wood"])
    if vertical:
        for xx in range(x, x + w, 3):
            rect(img, xx, y, 1, h, p["wood_l"])
            if xx + 2 < x + w:
                rect(img, xx + 2, y, 1, h, p["wood_d"])
    else:
        for yy in range(y, y + h, 3):
            rect(img, x, yy, w, 1, p["wood_l"])


def roof(img, cx, top, half, height, p, style):
    """A pitched roof (goblin: hide thatch; elf: leaves; undead: a steep slate)."""
    for i in range(height):
        span = half * (i + 1) // height
        for dx in range(-span, span + 1):
            c = p["roof_l"] if dx < -span // 3 else p["roof"]
            if style == "undead" and (dx + i) % 4 == 0:
                c = shade(p["roof"], 0.8)
            if style == "elf" and (dx * 3 + i) % 5 == 0:
                c = shade(p["roof_l"], 1.1)
            put(img, cx + dx, top + i, c)
    if style == "goblin":
        for dx in range(-half, half + 1, 3):
            put(img, cx + dx, top + height, p["roof_l"])  # fringe of the thatch


def door(img, x, y, w, h, p):
    rect(img, x, y, w, h, p["wood_d"])
    rect(img, x, y, w, 1, p["wood"])
    put(img, x + w - 2, y + h // 2, p["metal"])


def window(img, x, y, p, lit=True):
    rect(img, x, y, 3, 3, p["wood_d"])
    put(img, x + 1, y + 1, (250, 220, 120) if lit else p["stone"][0])


def flag(img, x, y, p, h=8):
    rect(img, x, y, 1, h, p["wood_d"])
    rect(img, x + 1, y, 4, 3, p["banner"])
    put(img, x + 5, y + 1, p["banner"])


def finish(img, p):
    outline(img, p["ink"])
    return img


def house(race, w, h, roof_h, p):
    """A walled house with a roof: the body of most buildings."""
    img = new(w + 2, h + roof_h + 2)
    cx = (w + 2) // 2
    body_top = roof_h + 1
    if race == "undead":
        stones(img, 1, body_top, w, h, p)
    elif race == "elf":
        rect(img, 1, body_top, w, h, p["cloth"])
        for xx in range(1, w + 1, 6):
            rect(img, xx, body_top, 2, h, p["wood"])  # timber frame on white walls
    else:
        planks(img, 1, body_top, w, h, p)
    roof(img, cx, 1, w // 2 + 2, roof_h + 1, p, race)
    return img, cx, body_top


# ---- the buildings ---------------------------------------------------------------------------------------------------
def warehouse(race, level, p):
    w, h, rh = [22, 28, 34][level - 1], [12, 14, 16][level - 1], [8, 10, 12][level - 1]
    img, cx, top = house(race, w, h, rh, p)
    door(img, cx - 3, top + h - 8, 6, 8, p)
    line(img, cx - 3, top + h - 8, cx + 2, top + h - 1, p["wood_l"])  # the barn door's brace
    for k in range(level):  # crates and sacks out front, more for a bigger store
        x = 2 + k * 5
        rect(img, x, top + h - 4, 4, 4, p["wood_l"])
        rect(img, x, top + h - 4, 4, 1, p["wood_d"])
        put(img, w - 2 - k * 4, top + h - 2, p["cloth_l"])
        rect(img, w - 3 - k * 4, top + h - 3, 3, 3, p["cloth"])
    if level >= 2:
        window(img, 3, top + 3, p)
        window(img, w - 4, top + 3, p)
    if level == 3:  # a silo on the side
        big = new(img.width + 10, img.height)
        big.alpha_composite(img, (0, 0))
        sx = img.width
        rect(big, sx, 8, 8, img.height - 8, p["stone"][1] if race != "goblin" else p["wood"])
        for yy in range(9, img.height, 3):
            rect(big, sx, yy, 8, 1, p["stone"][0] if race != "goblin" else p["wood_d"])
        for i in range(5):
            rect(big, sx + 4 - i, 3 + i, 1 + 2 * i, 1, p["roof"])
        img = big
    return finish(img, p)


def clinic(race, level, p):
    w, h, rh = [18, 24, 30][level - 1], [10, 12, 14][level - 1], [9, 11, 13][level - 1]
    img, cx, top = house(race, w, h, rh, p)
    door(img, cx - 2, top + h - 7, 5, 7, p)
    # the sign of healing: a red cross (goblin), a green leaf-cross (elf), a soul flame (undead)
    mark = {"goblin": (200, 50, 50), "elf": (90, 170, 90), "undead": p["accent"]}[race]
    rect(img, cx - 1, top - 6, 3, 7, (240, 240, 230))
    rect(img, cx - 3, top - 4, 7, 3, (240, 240, 230))
    rect(img, cx, top - 5, 1, 5, mark)
    rect(img, cx - 2, top - 3, 5, 1, mark)
    for k in range(level):  # herb pots and beds out front
        x = 2 + k * 4
        rect(img, x, top + h - 3, 3, 3, p["wood_d"])
        put(img, x + 1, top + h - 4, (80, 160, 70))
        put(img, x, top + h - 5, (100, 190, 80))
    if level >= 2:
        window(img, w - 5, top + 3, p)
    if level == 3:  # a cot and a lantern
        rect(img, w - 8, top + h - 3, 7, 2, p["cloth_l"])
        put(img, 3, top + 2, (250, 220, 120))
    return finish(img, p)


def training(race, level, p):
    w = [26, 34, 42][level - 1]
    img = new(w + 2, 26)
    base = 25
    # a fenced yard
    for x in range(1, w + 1, 4):
        rect(img, x, base - 7, 1, 7, p["wood"])
    rect(img, 1, base - 6, w, 1, p["wood_l"])
    rect(img, 1, base - 3, w, 1, p["wood_l"])
    def dummy(x):
        rect(img, x, base - 16, 1, 16, p["wood_d"])
        rect(img, x - 3, base - 13, 7, 1, p["wood_d"])
        rect(img, x - 2, base - 15, 5, 8, p["cloth"])
        rect(img, x - 1, base - 18, 3, 3, p["cloth_l"])
        put(img, x - 1, base - 12, p["accent"])
    dummy(7)
    if level >= 2:  # an archery target
        x = w - 7
        rect(img, x, base - 10, 1, 10, p["wood_d"])
        for r, c in ((4, (240, 236, 220)), (3, (200, 60, 50)), (1, (240, 236, 220))):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r:
                        put(img, x + dx, base - 15 + dy, c)
        put(img, x, base - 15, (240, 200, 60))
    if level >= 2:  # a weapon rack
        x = w // 2
        rect(img, x - 4, base - 10, 9, 1, p["wood_d"])
        for k in range(3):
            rect(img, x - 3 + k * 3, base - 14, 1, 10, p["metal"])
    if level == 3:  # banners on the corners and a second dummy
        flag(img, 2, base - 18, p, 12)
        flag(img, w - 4, base - 18, p, 12)
        dummy(w // 2 + 8)
    return finish(img, p)


def banquet(race, level, p):
    w = [26, 34, 42][level - 1]
    h = [14, 16, 18][level - 1]
    img = new(w + 2, h + 16)
    base = img.height - 1
    # an awning on posts (level 1), a hall (2, 3)
    if level == 1:
        for x in (2, w - 1):
            rect(img, x, base - 12, 1, 12, p["wood_d"])
        for i in range(5):
            rect(img, 1 + i, base - 16 + i, w - 2 * i, 1, p["cloth"] if i % 2 else p["cloth_l"])
        for x in range(2, w, 4):
            rect(img, x, base - 12, 2, 2, p["accent"])  # the awning's stripes
    else:
        hall, cx, top = house(race, w, h - 4, 10 + level, p)
        img = new(hall.width, hall.height + 2)
        img.alpha_composite(hall, (0, 0))
        base = img.height - 1
        door(img, cx - 3, base - 8, 7, 8, p)
        for x in range(4, w - 2, 7):
            window(img, x, base - 12, p)
    # the long table with food on it
    tx0, tx1 = 4, img.width - 5
    rect(img, tx0, base - 4, tx1 - tx0, 2, p["wood_l"])
    rect(img, tx0 + 1, base - 2, 1, 2, p["wood_d"])
    rect(img, tx1 - 2, base - 2, 1, 2, p["wood_d"])
    for x in range(tx0 + 2, tx1 - 1, 4):
        put(img, x, base - 5, (210, 120, 60))
        put(img, x + 1, base - 5, (240, 220, 120))
    if level == 3:
        flag(img, 1, base - 30, p, 14)
        flag(img, img.width - 6, base - 30, p, 14)
    return finish(img, p)


def watchtower(race, level, p):
    h = [28, 36, 44][level - 1]
    w = [14, 16, 20][level - 1]
    img = new(w + 8, h + 12)
    cx = img.width // 2
    base = img.height - 1
    if level == 3 or race == "undead":  # a stone tower
        stones(img, cx - w // 2 + 2, base - h + 8, w - 4, h - 8, p)
    else:  # a wooden frame: legs and braces
        for x in (cx - w // 2 + 2, cx + w // 2 - 3):
            rect(img, x, base - h + 8, 2, h - 8, p["wood"])
        for yy in range(base - h + 12, base, 7):
            line(img, cx - w // 2 + 3, yy, cx + w // 2 - 3, yy + 5, p["wood_d"])
            line(img, cx + w // 2 - 3, yy, cx - w // 2 + 3, yy + 5, p["wood_d"])
    # the lookout platform and its roof
    rect(img, cx - w // 2, base - h + 6, w, 3, p["wood_l"])
    rect(img, cx - w // 2, base - h + 3, 1, 3, p["wood"])
    rect(img, cx + w // 2 - 1, base - h + 3, 1, 3, p["wood"])
    if level >= 2:
        roof(img, cx, base - h - 4, w // 2 + 1, 7, p, race)
    if level == 3:  # a fire to see by and a flag
        put(img, cx, base - h + 4, (250, 180, 60))
        put(img, cx, base - h + 3, (250, 230, 120))
        flag(img, cx, base - h - 12, p, 8)
    elif level == 2:
        flag(img, cx, base - h - 11, p, 7)
    return finish(img, p)


def wall(race, level, p):
    """A stretch of wall 16 art pixels long (the Mac repeats it round the camp): a palisade, a stone wall, a fortified one."""
    h = [10, 12, 15][level - 1]
    img = new(16, h + 2)
    base = img.height - 1
    if level == 1 or race == "goblin" and level == 2:
        for x in range(0, 16, 3):
            rect(img, x, base - h + 2, 2, h - 2, p["wood"])
            put(img, x, base - h + 2, p["wood_l"])
            put(img, x + 1, base - h + 1, p["wood_l"])  # sharpened tops
        rect(img, 0, base - h // 2, 16, 1, p["wood_d"])
        if level == 2:
            stones(img, 0, base - 3, 16, 4, p)
    else:
        stones(img, 0, base - h + 3, 16, h - 3, p)
        for x in range(0, 16, 4):  # battlements
            rect(img, x, base - h + 1, 2, 2, p["stone"][2])
        if race == "undead":
            put(img, 7, base - h // 2, p["accent"])
        if race == "elf":
            for x in range(1, 16, 5):
                put(img, x, base - 2, (90, 160, 90))
                put(img, x + 1, base - 3, (110, 180, 100))  # ivy
    return finish(img, p)


def wall_tower(race, level, p):
    h = [0, 18, 24][level - 1]
    img = new(12, h + 4)
    base = img.height - 1
    stones(img, 1, base - h + 5, 10, h - 5, p)
    for x in range(1, 11, 3):
        rect(img, x, base - h + 3, 2, 2, p["stone"][2])
    window(img, 4, base - h + 9, p, lit=level == 3)
    if level == 3:
        flag(img, 5, base - h - 4, p, 7)
    return finish(img, p)


DRAW = {"warehouse": warehouse, "clinic": clinic, "training": training, "banquet": banquet, "watchtower": watchtower}


def make_all():
    manifest = {"note": "art pixels; each sprite stands on its bottom-centre pixel; one art pixel is two points", "races": {}}
    for race, p in PAL.items():
        folder = os.path.join(OUT, race)
        os.makedirs(folder, exist_ok=True)
        entry = {}
        for bid, fn in DRAW.items():
            for lv in LEVELS:
                img = fn(race, lv, p)
                name = f"{bid}_{lv}.png"
                img.save(os.path.join(folder, name))
                entry[f"{bid}_{lv}"] = {"file": f"{race}/{name}", "w": img.width, "h": img.height}
        for lv in LEVELS:
            img = wall(race, lv, p)
            img.save(os.path.join(folder, f"wall_{lv}.png"))
            entry[f"wall_{lv}"] = {"file": f"{race}/wall_{lv}.png", "w": img.width, "h": img.height}
            if lv >= 2:
                t = wall_tower(race, lv, p)
                t.save(os.path.join(folder, f"wall_{lv}_tower.png"))
                entry[f"wall_{lv}_tower"] = {"file": f"{race}/wall_{lv}_tower.png", "w": t.width, "h": t.height}
        manifest["races"][race] = entry
    with open(os.path.join(OUT, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=1)
    return manifest


def sheet(path, scale=3):
    rows = []
    for race in PAL:
        row = [Image.open(os.path.join(OUT, race, f"{b}_{lv}.png")) for b in [*DRAW, "wall"] for lv in LEVELS]
        row += [Image.open(os.path.join(OUT, race, f"wall_{lv}_tower.png")) for lv in (2, 3)]
        rows.append(row)
    cell_h = max(im.height for r in rows for im in r) * scale + 8
    width = max(sum(im.width * scale + 8 for im in r) for r in rows) + 8
    out = Image.new("RGBA", (width, cell_h * len(rows)), (74, 128, 70, 255))
    for ri, row in enumerate(rows):
        x = 8
        for im in row:
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            out.alpha_composite(big, (x, ri * cell_h + cell_h - 4 - big.height))
            x += big.width + 8
    out.save(path)


if __name__ == "__main__":
    make_all()
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])
    print("wrote", OUT)
