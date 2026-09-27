#!/usr/bin/env python3
"""Draws the undead (a playable race, see RACES.md) as 16x16 pixel-art sprite sheets, in the goblins' layout (4 walk phases x
front, back, side) but with bodies of their own: round chibi skulls and bones, and soft round spirits. Nothing here borrows the
goblin's face, so none of them has its long nose.

Two kinds, named for what they are (no trades yet):
  骨系 (bone): 骷髏, 巨骨, 黑曜骨 — grown from bones brought to the soul tower; sturdy.
  魂系 (soul): 幽影, 鬼火 — grown from wandering souls the soul fire draws in; quick and clever.
  靈裔 — born in the soul fire from the bond between an obsidian bone and the elf princess (three leanings).
Their princess is an elf princess (the goblins' girl with long elf ears, silver-gold hair and a green dress).

    python3 tools/make_undead.py --preview /path/p.png      # a contact sheet only
    python3 tools/make_undead.py --write                    # also writes Resources/Characters/undead/*
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_goblin as mg  # noqa: E402

SIZE = mg.SIZE
Canvas = mg.Canvas

BASE = {
    "O": (34, 30, 46),                                     # outline
    "w": (240, 236, 222), "s": (196, 190, 172), "h": (255, 252, 244),   # bone, its shade, its light
    "d": (40, 34, 54),                                     # sockets
    "e": (120, 240, 220),                                  # a glowing eye
    "R": (150, 40, 56), "r": (110, 28, 44),                # cape
    "y": (240, 200, 90),                                   # gold
    "V": (92, 80, 140), "v": (66, 56, 108), "u": (124, 112, 176),        # shadow cloth: mid, dark, light
    "Q": (120, 236, 214), "q": (70, 176, 172), "Z": (210, 255, 246),     # soul light
    "k": (60, 150, 150), "p": (255, 190, 200),             # a small mouth, a blush
}


def legs_front(c, phase, x_left=6, x_right=9, top=12, foot=14, width=1, col="w"):
    """Thin bone legs: one lifts a row on phases 1 and 3."""
    for x, lift in ((x_left, 1 if phase == 1 else 0), (x_right, 1 if phase == 3 else 0)):
        c.rect(x - (width - 1), top, x, foot - 1 - lift, col)
        c.rect(x - width, foot - lift, x, foot - lift, col)               # the foot, turned out


def legs_side(c, phase, top=12, foot=14, col="w", far="s"):
    if phase in (0, 2):
        c.rect(6, top, 6, foot, far); c.put(5, foot, far)
        c.rect(9, top, 9, foot, col); c.put(10, foot, col)
    else:
        lift = (1, 0) if phase == 3 else (0, 1)
        c.rect(7, top, 7, foot - lift[0], far)
        c.rect(8, top, 8, foot - lift[1], col); c.put(9, foot - lift[1], col)


def arms_front(c, phase, y0=9, y1=11, left=4, right=11, col="w", width=1):
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    for x, s in ((left, swing), (right, -swing)):
        for k in range(width):
            xx = x - k if x == left else x + k
            c.rect(xx, y0 + s, xx, y1 + s, col)


def skull_front(c, x0=4, x1=11, y0=1, y1=7, eyes=True):
    """A round skull: big dark sockets with a glowing dot, a little nose hole, a row of teeth."""
    c.rect(x0 + 1, y0, x1 - 1, y0, "w")
    c.rect(x0, y0 + 1, x1, y1 - 1, "w")
    c.rect(x0 + 1, y1, x1 - 1, y1, "w")
    c.rect(x1, y0 + 1, x1, y1 - 1, "s")                                     # shade on the right
    c.cells([(x0 + 1, y0 + 1), (x0 + 2, y0 + 1)], "h")                      # light on the crown
    if eyes:
        ly, lx, rx = y0 + 3, x0 + 1, x1 - 2
        c.rect(lx, ly, lx + 1, ly + 1, "d")
        c.rect(rx, ly, rx + 1, ly + 1, "d")
        c.put(lx + 1, ly + 1, "e")
        c.put(rx, ly + 1, "e")
        mid = (x0 + x1) // 2
        c.put(mid, ly + 2, "d")
        c.put(mid + 1, ly + 2, "d")
        for x in range(x0 + 2, x1 - 1, 2):                                   # teeth
            c.put(x, y1, "s")


def skull_back(c, x0=4, x1=11, y0=1, y1=7):
    c.rect(x0 + 1, y0, x1 - 1, y0, "w")
    c.rect(x0, y0 + 1, x1, y1 - 1, "w")
    c.rect(x0 + 1, y1, x1 - 1, y1, "s")
    c.rect(x0, y1 - 2, x1, y1 - 1, "s")
    c.cells([(x0 + 2, y0 + 1), (x0 + 3, y0 + 1)], "h")


def skull_side(c, x0=5, x1=11, y0=1, y1=7):
    """In profile, facing right: round at the back, flat in front, one socket, the jaw."""
    c.rect(x0 + 1, y0, x1 - 1, y0, "w")
    c.rect(x0, y0 + 1, x1, y1 - 1, "w")
    c.rect(x0 + 2, y1, x1, y1, "w")
    c.rect(x0, y0 + 2, x0, y1 - 2, "s")
    c.rect(x1 - 2, y0 + 3, x1 - 1, y0 + 4, "d")
    c.put(x1 - 1, y0 + 4, "e")
    c.put(x1, y0 + 5, "d")                                                   # the nose hole, at the front
    for x in range(x0 + 3, x1 + 1, 2):
        c.put(x, y1, "s")
    c.cells([(x0 + 2, y0 + 1), (x0 + 3, y0 + 1)], "h")


def ribs_front(c, x0=5, x1=10, y0=9, y1=11):
    for y in range(y0, y1 + 1):
        if (y - y0) % 2 == 0:
            c.rect(x0, y, x1, y, "w")
        else:
            c.cells([(x0, y), (x1, y)], "s")
    c.rect(7, y0, 8, y1 + 1, "w")                                            # breastbone and spine
    c.rect(6, y1 + 1, 9, y1 + 1, "s")                                        # hips


def skeleton(view, phase, big=False, crown=False, cape=False):
    c = Canvas()
    if big:
        sx0, sx1, sy0, sy1 = 3, 12, 1, 7
    else:
        sx0, sx1, sy0, sy1 = 4, 11, 1, 7
    if cape:                                                                 # the cape first, behind everything
        if view == "back":
            c.rect(4, 8, 11, 13, "R"); c.rect(4, 13, 11, 13, "r")
        elif view == "side":
            c.rect(3, 8, 5, 13, "R"); c.rect(3, 13, 5, 13, "r")
        else:
            c.cells([(4, 8), (11, 8), (3, 9), (12, 9), (3, 10), (12, 10), (3, 11), (12, 11), (3, 12), (12, 12)], "R")
    if view == "side":
        legs_side(c, phase)
        c.rect(6, 9, 9, 9, "w"); c.cells([(6, 10), (9, 10)], "s"); c.rect(6, 11, 9, 11, "w")
        c.rect(7, 8, 7, 12, "w")
        arm = {0: 8, 1: 9, 2: 8, 3: 6}[phase]
        c.rect(arm, 9, arm, 11 if phase in (0, 2) else 10, "w")
        skull_side(c, 5 if not big else 4, 11 if not big else 12, sy0, sy1)
        if big:
            c.cells([(5, 0), (4, 0), (4, 1)], "h")                           # a horn, swept back
    else:
        wide = 2 if big else 1
        legs_front(c, phase, 6 if not big else 6, 9 if not big else 10, width=wide)
        ribs_front(c, 5 if not big else 4, 10 if not big else 11)
        arms_front(c, phase, left=4 if not big else 2, right=11 if not big else 13, width=wide)
        c.rect(7, 8, 8, 8, "s")                                              # the neck
        if view == "front":
            skull_front(c, sx0, sx1, sy0, sy1)
        else:
            skull_back(c, sx0, sx1, sy0, sy1)
        if big:                                                              # horns
            c.cells([(sx0, 0), (sx0 - 1, 0), (sx0 - 1, 1)], "h")
            c.cells([(sx1, 0), (sx1 + 1, 0), (sx1 + 1, 1)], "h")
            c.cells([(3, 8), (12, 8), (2, 8), (13, 8)], "s")                 # shoulder plates
    if crown:
        for x in (5, 7, 8, 10):
            c.put(x, 0, "y")
    c.outline()
    return c


def ghost(view, phase):
    """幽影: a round little ghost, a sheet with a round top, two big glowing eyes, a hem that ripples as it floats."""
    c = Canvas()
    bob = 1 if phase in (1, 2) else 0                                         # it bobs as it goes
    top = 2 + bob
    c.rect(6, top, 9, top, "V")
    c.rect(5, top + 1, 10, top + 1, "V")
    c.rect(4, top + 2, 11, top + 10, "V")
    for x in range(4, 12):                                                    # the rippling hem
        if (x + phase) % 3 != 0:
            c.put(x, top + 11, "V")
    c.rect(11, top + 3, 11, top + 10, "v")                                    # shade on the right
    c.cells([(6, top + 1), (5, top + 2), (5, top + 3)], "u")                 # light on the top left
    if view == "front":
        c.rect(5, top + 4, 6, top + 6, "d"); c.rect(9, top + 4, 10, top + 6, "d")
        c.put(6, top + 5, "e"); c.put(10, top + 5, "e")
        c.put(6, top + 4, "Z"); c.put(10, top + 4, "Z")                       # a glint in each eye
        c.cells([(7, top + 8), (8, top + 8)], "d")                           # a small round mouth
    elif view == "side":
        c.rect(9, top + 4, 10, top + 6, "d"); c.put(10, top + 5, "e"); c.put(10, top + 4, "Z")
        c.put(3, top + 9, "V"); c.put(2, top + 10, "V")                        # a trailing wisp behind
    c.outline()
    return c


def wisp(view, phase):
    """鬼火: a round flame with a cute face; its tip flickers."""
    c = Canvas()
    tips = [[(7, 1), (8, 2)], [(8, 1), (7, 2)], [(7, 0), (7, 1), (8, 2)], [(8, 0), (8, 1), (7, 2)]][phase]
    c.cells(tips, "Q")
    rows = {3: (6, 9), 4: (5, 10), 5: (4, 11), 6: (4, 11), 7: (3, 12), 8: (3, 12), 9: (3, 12), 10: (4, 11), 11: (4, 11), 12: (5, 10), 13: (6, 9)}
    for y, (a, b) in rows.items():
        c.rect(a, y, b, y, "Q")
    for y, (a, b) in {5: (6, 9), 6: (5, 10), 7: (5, 10), 8: (5, 10), 9: (5, 10), 10: (6, 9), 11: (6, 9)}.items():
        c.rect(a, y, b, y, "Z")                                                # the bright heart of it
    c.cells([(4, 12), (11, 12), (3, 10)], "q")
    if view != "back":
        off = 1 if view == "side" else 0
        c.rect(5 + off, 7, 5 + off, 8, "d"); c.rect(9 + off, 7, 9 + off, 8, "d")
        c.cells([(4 + off, 9), (10 + off, 9)], "p")                          # blush
        c.put(7 + off, 10, "k")
    c.outline()
    return c


def spirit(view, phase, level):
    """靈裔: a small glowing child-spirit with a round face and big eyes; 0 has a little bone mask on its brow (leans bone),
    2 floats with a ring of light over its head (leans soul)."""
    c = Canvas()
    floating = level == 2
    bob = (1 if phase in (1, 2) else 0) if floating else 0
    if floating:
        for i, y in enumerate(range(11 + bob, 15)):
            half = 2 - i // 2
            c.rect(8 - half - 1, y, 7 + half + 1, y, "q")
    else:
        legs_front(c, phase, 6, 9, top=12, foot=14, col="q") if view != "side" else legs_side(c, phase, col="q", far="k")
    c.rect(5, 9 + bob, 10, 11 + bob, "Q")                                    # a little robe of light
    c.cells([(4, 10 + bob), (11, 10 + bob)], "Q")
    head_y = 2 + bob
    c.rect(5, head_y, 10, head_y, "Z")
    c.rect(4, head_y + 1, 11, head_y + 5, "Z")
    c.rect(5, head_y + 6, 10, head_y + 6, "Z")
    c.rect(5, head_y, 10, head_y, "Q")                                       # glowing hair, round on top
    c.rect(4, head_y + 1, 11, head_y + 1, "Q")
    c.cells([(4, head_y + 2), (11, head_y + 2), (7, head_y - 1)], "Q")       # and a little tuft
    if view == "front":
        c.rect(5, head_y + 2, 6, head_y + 4, "d"); c.rect(9, head_y + 2, 10, head_y + 4, "d")   # big open eyes
        c.put(5, head_y + 2, "h"); c.put(9, head_y + 2, "h")                 # a glint in each
        c.cells([(4, head_y + 5), (11, head_y + 5)], "p")
        c.put(7, head_y + 5, "k"); c.put(8, head_y + 5, "k")
        if level == 0:
            c.rect(5, head_y + 1, 10, head_y + 1, "s")                        # the bone mask on its brow
    elif view == "side":
        c.rect(9, head_y + 2, 10, head_y + 4, "d"); c.put(9, head_y + 2, "h")
        c.put(11, head_y + 5, "p")
        if level == 0:
            c.rect(7, head_y + 1, 11, head_y + 1, "w")
    else:
        c.rect(4, head_y + 2, 11, head_y + 5, "Q")
    if floating:
        c.cells([(5, head_y - 2), (6, head_y - 2), (9, head_y - 2), (10, head_y - 2), (7, head_y - 2), (8, head_y - 2)], "y")
    c.outline()
    return c


def obsidian_palette():
    return dict(BASE, w=(76, 70, 100), s=(52, 46, 72), h=(132, 122, 164), e=(200, 150, 255))


# id, name, weight, boost, blurb, stats, sheet, drawer, palette
BREEDS = [
    ("common", "骷髏", 100, 0, "骨系。圓圓的骷髏頭加一副細骨頭，不會老，也不吃東西。",
     {"lifespan": 50.0, "might": 1.1, "health": 3}, "worker.png", lambda v, p: skeleton(v, p), BASE),
    ("scout", "幽影", 10, 1.0, "魂系。圓圓的小幽靈，飄著走，很快，遠遠就看得到東西。",
     {"speed": 1.4, "sense": 1.4, "lifespan": 50.0, "might": 0.8, "health": 2}, "scout.png", ghost, BASE),
    ("brute", "巨骨", 8, 1.0, "骨系。大一號的骷髏，頭上長角，一次搬兩份，站在最前面。",
     {"speed": 0.8, "carry": 2, "lifespan": 50.0, "might": 1.7, "health": 6}, "brute.png", lambda v, p: skeleton(v, p, big=True), BASE),
    ("sage", "鬼火", 5, 1.5, "魂系。一團圓圓的靈火，會補血，也讓魂塔收集得快一點。",
     {"speed": 1.0, "sense": 1.3, "recruit": 3, "lifespan": 50.0, "might": 0.9, "health": 2.5}, "sage.png", wisp, BASE),
    ("golden", "黑曜骨", 1, 3.0, "骨系。罕見的黑色發亮的骷髏，戴著金骨冠、披著暗紅斗篷，每一方面都好一點。",
     {"speed": 1.1, "sense": 1.1, "recruit": 1, "lifespan": 50.0, "might": 1.5, "health": 5}, "golden.png",
     lambda v, p: skeleton(v, p, crown=True, cape=True), obsidian_palette()),
    ("half_gob", "靈裔・偏骨", 0, 0, "黑曜骨與精靈公主靈魂交流，從靈魂之火裡誕生：額頭上一小片骨面具，耐打。",
     {"speed": 1.0, "sense": 1.2, "lifespan": 50.0, "might": 1.5, "health": 5, "recruit": 1}, "half_gob.png",
     lambda v, p: spirit(v, p, 0), BASE),
    ("half_mix", "靈裔", 0, 0, "黑曜骨與精靈公主靈魂交流，從靈魂之火裡誕生：淡淡發光的孩子，聰明又有力。",
     {"speed": 1.1, "sense": 1.3, "lifespan": 50.0, "might": 1.4, "health": 4, "recruit": 2}, "half_mix.png",
     lambda v, p: spirit(v, p, 1), BASE),
    ("half_hum", "靈裔・偏魂", 0, 0, "黑曜骨與精靈公主靈魂交流，從靈魂之火裡誕生：飄著走、頭上有一圈光，最聰明。",
     {"speed": 1.2, "sense": 1.5, "lifespan": 50.0, "might": 1.2, "health": 3.5, "recruit": 3}, "half_hum.png",
     lambda v, p: spirit(v, p, 2), BASE),
]


def breed_sheet(draw, pal):
    """4 phases x (front, back, side), the same layout as the goblins' sheets."""
    img = [[(0, 0, 0, 0)] * (4 * SIZE) for _ in range(3 * SIZE)]
    for r, view in enumerate(("front", "back", "side")):
        for phase in range(4):
            canvas = draw(view, phase)
            for y in range(SIZE):
                for x in range(SIZE):
                    key = canvas.px[y][x]
                    if key is not None:
                        img[r * SIZE + y][phase * SIZE + x] = pal[key] + (255,)
    return img


# --- the elf princess -----------------------------------------------------------------------------------------------
ELF_GIRL = dict(mg.GIRL, H=(236, 226, 170), h=(252, 248, 214), J=(196, 182, 120), i=(70, 170, 110), c=(120, 200, 110))

OUTFITS = [
    dict(id="dress", name="森林長裙", bottom="gown", sleeves="puff", hat="tiara", elf=True,
         pal={"Q": (96, 160, 110), "q": (66, 120, 80), "D": (96, 160, 110), "d": (66, 120, 80), "W": (240, 248, 236),
              "R": (236, 226, 170)}),
    dict(id="winter", name="披風", bottom="coat", sleeves="long", hat="tiara", elf=True,
         pal={"Q": (60, 90, 120), "q": (40, 64, 90), "D": (60, 90, 120), "d": (40, 64, 90), "A": (236, 226, 170), "K": (80, 64, 50)}),
    dict(id="pajamas", name="睡衣", bottom="pants", sleeves="long", hat="tiara", elf=True,
         pal={"Q": (220, 236, 226), "q": (190, 212, 200), "D": (220, 236, 226), "d": (190, 212, 200), "K": (200, 226, 210)}),
]

_view = ["front"]
_original_squash = mg.squash


def _elf_squash(c, o):
    """Long elf ears out past her hair, drawn before she is squashed and outlined."""
    if o.get("elf"):
        if _view[0] == "side":
            c.cells([(4, 4), (3, 3), (2, 2)], "s")
        else:
            c.cells([(2, 4), (1, 3), (13, 4), (14, 3)], "s")
    return _original_squash(c, o)


def _wrap(fn, view):
    def drawn(*args, **kwargs):
        _view[0] = view
        return fn(*args, **kwargs)
    return drawn


mg.squash = _elf_squash
mg.girl_front = _wrap(mg.girl_front, "front")
mg.girl_back = _wrap(mg.girl_back, "back")
mg.girl_side = _wrap(mg.girl_side, "side")


def princess_sheet(outfit):
    saved = dict(mg.GIRL)
    mg.GIRL.clear()
    mg.GIRL.update(ELF_GIRL)
    try:
        return mg.build_sheet(True, outfit=outfit)
    finally:
        mg.GIRL.clear()
        mg.GIRL.update(saved)


def skull_icon():
    c = Canvas()
    skull_front(c, 3, 12, 2, 12)
    c.outline()
    return [[(BASE[c.px[y][x]] + (255,)) if c.px[y][x] else (0, 0, 0, 0) for x in range(SIZE)] for y in range(SIZE)]


def preview(path, zoom=8):
    sheets = [breed_sheet(b[7], b[8]) for b in BREEDS] + [princess_sheet(o) for o in OUTFITS]
    cols = 8
    w, h = cols * SIZE * zoom, (len(sheets) + 3) * SIZE * zoom
    bg = (92, 94, 104, 255)
    out = [[bg] * w for _ in range(h)]

    def blit(sheet, sx, sy, dx, dy, flip=False):
        for y in range(SIZE):
            for x in range(SIZE):
                px = sheet[sy + y][sx + (SIZE - 1 - x if flip else x)]
                if px[3]:
                    for oy in range(zoom):
                        row = out[(dy + y) * zoom + oy]
                        for ox in range(zoom):
                            row[(dx + x) * zoom + ox] = px

    for r, sheet in enumerate(sheets):
        col = 0
        for view in range(3):
            for phase in (0, 1):
                blit(sheet, phase * SIZE, view * SIZE, col * SIZE, r * SIZE)
                col += 1
        for phase in (0, 1):
            blit(sheet, phase * SIZE, 2 * SIZE, col * SIZE, r * SIZE, flip=True)
            col += 1
    first = princess_sheet(OUTFITS[0])
    k = 0
    for pr in range(len(mg.POSES)):
        for f in range(4):
            if k >= 3 * cols:
                break
            blit(first, f * SIZE, (3 + pr) * SIZE, (k % cols) * SIZE, (len(sheets) + k // cols) * SIZE)
            k += 1
    mg.write_png(path, out)


FEATURES = ["不吃東西、不會老死；傷得太重就散架",
            "魂塔的靈魂之火慢慢收集四散的魂魄，長出魂系（幽影、鬼火）",
            "把骨頭搬回魂塔，長出骨系（骷髏、巨骨、黑曜骨）；打倒敵人會掉骨頭、放出魂魄",
            "晚上最強，白天慢一點；加成來自帶顏色的魂魄",
            "首領是精靈公主；和黑曜骨靈魂交流，會在靈魂之火裡誕生靈裔"]


def main():
    if "--write" in sys.argv:
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Characters", "undead")
        os.makedirs(root, exist_ok=True)
        for _id, _name, _w, _b, _blurb, _stats, sheet, draw, pal in BREEDS:
            mg.write_png(os.path.join(root, sheet), breed_sheet(draw, pal))
        for o in OUTFITS:
            mg.write_png(os.path.join(root, "queen.png" if o["id"] == "dress" else f"queen_{o['id']}.png"), princess_sheet(o))
        mg.write_png(os.path.join(root, "icon.png"), skull_icon())
        walk = {"down": [0, 1, 2, 3], "up": [4, 5, 6, 7], "side": [8, 9, 10, 11]}
        manifest = {
            "id": "undead", "name": "死靈", "noun": "死靈", "emoji": "💀", "icon": "icon.png", "nestName": "魂塔", "frame": SIZE,
            "defaultMaxCount": 150,
            "tagline": "不吃東西、不會老死，靠魂魄和骨頭長大，夜晚最強。",
            "features": FEATURES,
            "rules": {"names": "undead", "noDecor": ["tent", "totem", "rack", "spears", "firewood"], "fellsTrees": False,
                      "spawnScale": 1.5, "eats": False, "placeable": ["soul_blue", "soul_green", "soul_purple"],
                      "nightMight": 1.3, "nightSpeed": 1.15, "daySpeed": 0.9,
                      "lineage": {"bone": ["common", "brute", "golden"], "soul": ["scout", "sage"]},
                      "soulBond": True, "camp": "soultower", "biome": "graveyard",
                      "princessNames": ["艾菈瑟", "琉恩", "希兒薇", "月語", "蕾茵", "瑟菈", "伊露", "薇妮", "星歌", "露瑟"]},
            "worker": {"sheet": "worker.png", "pixelScale": 1.5, "walk": walk},
            "breeds": [{"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet}
                       for i, n, w, b, blurb, stats, sheet, _d, _p in BREEDS],
            "queen": {"sheet": "queen.png", "pixelScale": 2.0, "walk": walk,
                      "poses": {name: [(3 + r) * 4 + f for f in range(count)] for r, (name, _dr, count) in enumerate(mg.POSES)},
                      "outfits": [{"id": o["id"], "name": o["name"], "sheet": "queen.png" if o["id"] == "dress" else f"queen_{o['id']}.png"}
                                  for o in OUTFITS]},
        }
        with open(os.path.join(root, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("wrote", os.path.normpath(root))
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
