#!/usr/bin/env python3
"""The guild's shared decorations (公會共用, GUILD.md §5.2): 160 items, drawn at the hall's scale (16-px tiles, the avatar is
32 x 40). Medieval fantasy first; modern things get a fantasy twist; a few plain modern easter eggs.

    python3 mac/tools/make_guild_decor.py
        -> mac/Resources/Guild/decor/<id>.png      (one horizontal strip per item, `frames` frames of w x h)
        -> mac/tools/guild_decor_catalog.json       (id, name, category, size, w, h, frames, fps, wall/flat/seat, note)
        -> docs/images/guild/decor_shared_overview_N.png   (the overview for the user)

Sizes are room points: small 1, middle 2, big 4. Seats put their seat top 3 px above the floor line, like the avatars'
generic sitting pose (Avatars manifest seatY), so any avatar can sit on any of them.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_avatars_preview as pv  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
OUTDIR = os.path.join(REPO, "mac", "Resources", "Guild", "decor")
CATALOG = os.path.join(HERE, "guild_decor_catalog.json")
DOCS = os.path.join(REPO, "docs", "images", "guild")
OAK = os.path.join(REPO, "mac", "Resources", "Guild", "floors", "oak.png")
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
SEAT_UP = 3                   # seat top this many px above the floor line (= the avatar's seatY)

P = {
    "O": (52, 36, 28),
    "wood": (176, 118, 66), "wood_d": (140, 90, 48), "wood_l": (206, 150, 92), "wood_x": (112, 70, 38),
    "dark": (110, 72, 48), "dark_d": (80, 52, 36), "dark_l": (140, 96, 64),
    "stone": (150, 150, 158), "stone_d": (118, 118, 128), "stone_l": (184, 184, 190), "stone_x": (92, 92, 104),
    "iron": (90, 94, 108), "iron_d": (62, 64, 78), "iron_l": (150, 156, 170),
    "gold": (232, 190, 80), "gold_d": (184, 140, 50), "gold_l": (255, 232, 150),
    "red": (176, 60, 70), "red_d": (130, 40, 52), "red_l": (214, 100, 110),
    "blue": (70, 110, 170), "blue_d": (48, 78, 130), "blue_l": (120, 160, 214),
    "green": (70, 140, 70), "green_d": (44, 100, 56), "green_l": (110, 180, 90),
    "purple": (120, 80, 160), "purple_d": (84, 54, 120), "purple_l": (170, 130, 210),
    "cloth": (230, 220, 190), "cloth_d": (196, 184, 150),
    "paper": (244, 234, 206), "paper_d": (210, 196, 160), "ink": (50, 40, 50),
    "glass": (150, 230, 240), "glass_d": (96, 170, 210), "glow": (240, 255, 255), "rune": (120, 220, 200), "rune_d": (60, 120, 150),
    "f1": (255, 236, 140), "f2": (255, 170, 60), "f3": (230, 90, 40), "f4": (255, 250, 220),
    "water": (100, 168, 240), "water_l": (170, 222, 255), "water_d": (60, 108, 190),
    "ice": (210, 244, 255), "ice_d": (140, 200, 240),
    "pot": (196, 110, 70), "pot_d": (150, 78, 50),
    "black": (40, 34, 54), "white": (255, 255, 255), "pink": (240, 150, 180), "pink_d": (200, 104, 140),
    "orange": (240, 150, 60), "yellow": (250, 214, 90), "brown": (120, 80, 50),
    "fur": (210, 180, 140), "fur_d": (160, 128, 96), "fur_l": (236, 214, 180),
    "marble": (236, 232, 226), "marble_d": (196, 194, 200), "marble_x": (170, 168, 178),
    "board": (60, 84, 72), "board_d": (44, 62, 54), "chalk": (232, 240, 232),
    "mac": (222, 224, 230), "mac_d": (172, 176, 186), "screen": (40, 60, 90), "screen_l": (90, 150, 210),
    "teal": (70, 160, 160), "teal_d": (44, 116, 120), "teal_l": (120, 210, 200),
    "skin": (250, 218, 190), "straw": (226, 196, 110), "straw_d": (186, 152, 72),
    "slime": (120, 210, 120), "slime_d": (70, 160, 90), "slime_l": (190, 250, 180),
}


class Canvas(pv.C):
    """pv.C that accepts float coordinates (rounded down)."""

    def put(self, x, y, k):
        super().put(int(math.floor(x)), int(math.floor(y)), k)

    def rect(self, x0, y0, x1, y1, k):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                super().put(x, y, k)


class Item:
    def __init__(self, id, name, cat, size, w, h, frames=1, fps=0, wall=False, flat=False, seat=None, note="", draw=None,
                 race=None, ceiling=False):
        self.__dict__.update(locals())
        del self.__dict__["self"]


ITEMS = []
RACE = [None]                 # the race set being defined (None: shared)


def item(id, name, cat, size, w, h, frames=1, fps=None, wall=False, flat=False, seat=False, note="", ceiling=False):
    def deco(fn):
        ITEMS.append(Item(id, name, cat, size, w, h, frames, fps if fps is not None else (0 if frames == 1 else 4), wall, flat,
                          seat, note, fn, RACE[0], ceiling))
        return fn
    return deco


# --- drawing helpers -------------------------------------------------------------------------------------------------------
def R(c, x0, y0, x1, y1, k):
    c.rect(x0, y0, x1, y1, k)


def box(c, x0, y0, x1, y1, base, light=None, shade=None):
    """A solid block: light top row, shaded right column."""
    R(c, x0, y0, x1, y1, base)
    if light:
        R(c, x0, y0, x1, y0, light)
    if shade:
        R(c, x1, y0 + 1, x1, y1, shade)


def table(c, x0, top, x1, floor, wood="wood", legs=(None,), depth=3):
    """A table seen from the front 3/4: a top surface `depth` rows deep, a front edge, four legs down to `floor`."""
    R(c, x0, top, x1, top + depth - 1, wood + "_l")
    R(c, x0, top + depth, x1, top + depth + 1, wood)
    R(c, x0, top + depth + 1, x1, top + depth + 1, wood + "_d")
    for x in (x0 + 1, x1 - 1):
        R(c, x, top + depth + 2, x, floor, wood + "_d")


def circle(c, cx, cy, r, k, ry=None):
    ry = ry or r
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if ((x - cx) / (r + 0.3)) ** 2 + ((y - cy) / (ry + 0.3)) ** 2 <= 1:
                c.put(x, y, k)


def blob(c, cx, cy, r, base="green", dark="green_d", light="green_l", ry=None):
    """Foliage: a round clump with a dark lower edge and light flecks on top."""
    ry = ry or r
    circle(c, cx, cy, r, dark, ry)
    circle(c, cx - 0.5, cy - 0.7, r - 0.6, base, ry - 0.7)
    for dx, dy in ((-r * 0.4, -ry * 0.5), (r * 0.2, -ry * 0.7), (-r * 0.7, -ry * 0.1)):
        c.put(int(cx + dx), int(cy + dy), light)


def pot(c, cx, bottom, w=8, h=6, k="pot"):
    x0, x1 = cx - w // 2, cx + w // 2 - 1
    R(c, x0 - 1, bottom - h, x1 + 1, bottom - h + 1, k + "_d")
    R(c, x0, bottom - h + 2, x1, bottom, k)
    R(c, x1, bottom - h + 2, x1, bottom, k + "_d")
    R(c, x0 + 1, bottom, x1 - 1, bottom, k + "_d")


def flame(c, cx, base, h, f, wide=1):
    """A small flickering flame standing on row `base`."""
    sway = [0, 1, 0, -1][f % 4]
    for i in range(h):
        y = base - i
        w = wide if i < h - 2 else 0
        x = cx + (sway if i > h // 2 else 0)
        R(c, x - w, y, x + w, y, "f3" if i == h - 1 else ("f2" if i > h // 3 else "f1"))
    c.put(cx, base, "f4")


def frame_border(c, x0, y0, x1, y1, k="wood"):
    R(c, x0, y0, x1, y1, k)
    R(c, x0, y0, x1, y0, k + "_l"); R(c, x1, y0, x1, y1, k + "_d"); R(c, x0, y1, x1, y1, k + "_d")


def shelf_books(c, x0, x1, y_bottom, h, seed=0):
    cols = ["red", "blue", "green", "purple", "gold", "teal", "brown"]
    x, i = x0, seed
    while x <= x1:
        w = 1 + (i % 2)
        hh = h - (i * 7 % 3)
        R(c, x, y_bottom - hh + 1, min(x1, x + w - 1), y_bottom, cols[i % len(cols)])
        c.put(x, y_bottom - hh + 2, "paper") if hh > 3 else None
        x += w + (1 if i % 5 == 4 else 0)
        i += 3


def crystal(c, cx, cy, r, f=0):
    circle(c, cx, cy, r, "glass")
    circle(c, cx + 0.6, cy + 0.6, r - 1.2, "glass_d")
    c.put(cx - r // 2, cy - r // 2, "glow")
    if f % 2:
        circle(c, cx, cy, max(1, r - 2.5), "rune")


def seat_info(w, h, x=None):
    return {"x": x if x is not None else w // 2, "y": h, "behind": True, "facing": "front"}


# ===========================================================================================================================
# 辦公桌椅
# ===========================================================================================================================
C1 = "辦公桌椅"


@item("crystal_desk", "水晶球辦公桌", C1, 4, 40, 24, 2, 3, note="水晶球螢幕＋符文鍵盤；分身坐在後面")
def _(c, f):
    table(c, 1, 11, 38, 23, depth=2)
    R(c, 1, 14, 38, 20, "wood"); R(c, 1, 14, 38, 14, "wood_d"); R(c, 4, 17, 7, 17, "gold"); R(c, 32, 17, 35, 17, "gold")
    R(c, 12, 10, 21, 10, "black"); [c.put(x, 10, "rune" if (x + f) % 2 else "rune_d") for x in range(13, 21, 2)]
    crystal(c, 31, 5, 4, f); R(c, 28, 9, 34, 10, "gold"); R(c, 27, 10, 35, 10, "gold_d")
    R(c, 4, 8, 6, 10, "paper"); c.put(7, 9, "paper")


@item("oak_desk", "橡木辦公桌", C1, 2, 32, 20)
def _(c, f):
    table(c, 1, 6, 30, 19, depth=3)
    R(c, 3, 11, 12, 17, "wood"); R(c, 3, 11, 12, 11, "wood_d"); R(c, 7, 14, 8, 14, "gold")
    R(c, 18, 3, 23, 5, "paper"); R(c, 19, 4, 22, 4, "ink"); R(c, 25, 2, 26, 5, "white")


@item("corner_desk", "轉角大桌", C1, 4, 48, 28)
def _(c, f):
    R(c, 1, 4, 14, 14, "wood_l"); table(c, 1, 14, 46, 27, depth=3)
    R(c, 1, 4, 1, 16, "wood_d"); R(c, 14, 4, 14, 13, "wood_d")
    R(c, 34, 19, 44, 25, "wood"); R(c, 34, 19, 44, 19, "wood_d"); R(c, 38, 22, 40, 22, "gold")
    R(c, 4, 7, 9, 10, "paper"); R(c, 22, 11, 27, 15, "paper"); c.put(30, 13, "red")


@item("standing_desk", "站立書桌", C1, 2, 28, 26)
def _(c, f):
    R(c, 2, 4, 25, 7, "wood_l"); R(c, 2, 8, 25, 9, "wood"); R(c, 2, 9, 25, 9, "wood_d")
    R(c, 4, 10, 5, 25, "wood_d"); R(c, 22, 10, 23, 25, "wood_d"); R(c, 4, 19, 23, 20, "wood")
    R(c, 9, 2, 17, 6, "paper"); R(c, 10, 3, 16, 3, "ink"); R(c, 10, 5, 14, 5, "ink")


@item("map_table", "地圖桌", C1, 4, 40, 24)
def _(c, f):
    table(c, 1, 6, 38, 23, depth=5)
    R(c, 4, 6, 35, 10, "paper"); R(c, 4, 10, 35, 10, "paper_d")
    for x, y in ((8, 7), (9, 8), (10, 8), (14, 7), (20, 9), (21, 8), (27, 7), (28, 8)):
        c.put(x, y, "green")
    R(c, 16, 8, 18, 9, "water"); c.put(24, 7, "red"); c.put(25, 9, "red"); c.put(31, 8, "ink"); c.put(12, 9, "brown")


@item("meeting_table", "圓桌會議桌", C1, 4, 48, 28)
def _(c, f):
    circle(c, 23.5, 12, 22, "wood_d", 9); circle(c, 23.5, 11, 21, "wood_l", 8)
    R(c, 3, 13, 44, 16, "wood"); circle(c, 23.5, 11, 21, "wood_l", 8)
    R(c, 21, 17, 26, 27, "wood_d"); R(c, 16, 26, 31, 27, "wood_d")
    circle(c, 23.5, 11, 5, "gold", 3); circle(c, 23.5, 11, 3, "gold_l", 2)
    for x in (9, 15, 32, 38):
        R(c, x, 9, x + 2, 11, "paper")


@item("office_stool", "圓凳", C1, 1, 16, 8, seat=True, note="座面高度和分身坐姿一致")
def _(c, f):
    h = 8
    R(c, 1, h - 1 - SEAT_UP, 14, h - 1 - SEAT_UP, "wood_l"); R(c, 1, h - SEAT_UP, 14, h - SEAT_UP + 1, "wood")
    R(c, 2, h - 2, 2, h - 1, "wood_d"); R(c, 13, h - 2, 13, h - 1, "wood_d")
    R(c, 2, 0, 13, h - 2 - SEAT_UP, "red"); R(c, 2, 0, 13, 0, "red_l")       # a little cushion


@item("high_chair", "高背木椅", C1, 1, 16, 26, seat=True)
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    R(c, 2, 1, 13, sy - 1, "wood"); R(c, 2, 1, 13, 1, "wood_l"); R(c, 3, 3, 12, sy - 2, "red"); R(c, 3, 3, 12, 3, "red_l")
    c.cells([(7, 0), (8, 0)], "gold")
    R(c, 1, sy, 14, sy, "wood_l"); R(c, 1, sy + 1, 14, sy + 2, "wood")
    R(c, 2, sy + 3, 2, h - 1, "wood_d"); R(c, 13, sy + 3, 13, h - 1, "wood_d")


@item("swivel_chair", "旋轉椅", C1, 1, 16, 24, seat=True, note="有輪子的辦公椅，木頭版")
def _(c, f):
    h = 24
    sy = h - 1 - SEAT_UP
    R(c, 3, 2, 12, sy - 2, "blue"); R(c, 3, 2, 12, 2, "blue_l"); R(c, 12, 3, 12, sy - 2, "blue_d")
    R(c, 7, sy - 1, 8, sy - 1, "iron")
    R(c, 1, sy, 14, sy, "blue_l"); R(c, 1, sy + 1, 14, sy + 1, "blue")
    R(c, 7, sy + 2, 8, h - 2, "iron"); R(c, 3, h - 2, 12, h - 2, "iron"); c.cells([(3, h - 1), (12, h - 1), (7, h - 1)], "black")


@item("long_bench", "長凳", C1, 2, 32, 14, seat=True)
def _(c, f):
    h = 14
    sy = h - 1 - SEAT_UP
    R(c, 1, 1, 30, 2, "wood_l"); R(c, 1, 4, 30, 5, "wood"); R(c, 2, 1, 2, sy, "wood_d"); R(c, 29, 1, 29, sy, "wood_d")
    R(c, 0, sy, 31, sy, "wood_l"); R(c, 0, sy + 1, 31, sy + 1, "wood")
    R(c, 1, sy + 2, 2, h - 1, "wood_d"); R(c, 29, sy + 2, 30, h - 1, "wood_d")


@item("lectern", "講台", C1, 1, 16, 26)
def _(c, f):
    R(c, 1, 4, 14, 8, "wood_l"); R(c, 1, 8, 14, 9, "wood_d")
    R(c, 4, 10, 11, 23, "wood"); R(c, 11, 10, 11, 23, "wood_d"); R(c, 2, 23, 13, 25, "wood_d")
    R(c, 3, 2, 12, 5, "paper"); R(c, 7, 2, 8, 5, "paper_d"); c.put(4, 3, "ink"); c.put(10, 4, "ink")
    R(c, 6, 14, 9, 17, "gold")


@item("guildmaster_desk", "會長大桌", C1, 4, 48, 30, note="會長專用，刻著公會徽章")
def _(c, f):
    table(c, 1, 9, 46, 29, wood="dark", depth=4)
    R(c, 1, 15, 46, 27, "dark"); R(c, 1, 15, 46, 15, "dark_d")
    R(c, 18, 17, 29, 26, "gold_d"); R(c, 19, 18, 28, 25, "red"); R(c, 22, 19, 25, 24, "gold")
    R(c, 3, 6, 9, 10, "paper"); R(c, 38, 4, 41, 10, "gold"); c.put(39, 3, "gold_l")
    R(c, 12, 7, 14, 10, "ink"); c.put(13, 5, "white"); c.put(14, 4, "white")


@item("drafting_table", "繪圖桌", C1, 2, 26, 26)
def _(c, f):
    for i in range(8):
        R(c, 2 + i // 3, 4 + i, 23, 4 + i, "wood_l" if i < 7 else "wood_d")
    R(c, 5, 5, 20, 10, "paper"); R(c, 7, 7, 15, 7, "blue"); R(c, 8, 9, 18, 9, "blue"); c.put(17, 6, "red")
    R(c, 5, 12, 6, 25, "wood_d"); R(c, 19, 12, 20, 25, "wood_d"); R(c, 5, 20, 20, 20, "wood")


# ===========================================================================================================================
# 櫃子收納
# ===========================================================================================================================
C2 = "櫃子收納"


@item("bookshelf_tall", "高書櫃", C2, 2, 32, 40)
def _(c, f):
    box(c, 1, 1, 30, 39, "wood", "wood_l", "wood_d")
    for i, y in enumerate((4, 13, 22, 31)):
        R(c, 3, y, 28, y + 7, "wood_x"); shelf_books(c, 3, 28, y + 7, 7, i); R(c, 2, y + 8, 29, y + 8, "wood_l")


@item("bookshelf_low", "矮書櫃", C2, 2, 32, 20)
def _(c, f):
    box(c, 1, 1, 30, 19, "wood", "wood_l", "wood_d")
    R(c, 3, 3, 28, 9, "wood_x"); shelf_books(c, 3, 28, 9, 6, 1); R(c, 2, 10, 29, 10, "wood_l")
    R(c, 3, 11, 28, 17, "wood_x"); shelf_books(c, 3, 18, 17, 6, 4); R(c, 21, 14, 26, 17, "gold"); R(c, 22, 13, 25, 13, "gold_l")


@item("scroll_rack", "卷軸架", C2, 2, 32, 32)
def _(c, f):
    box(c, 1, 1, 30, 31, "wood", "wood_l", "wood_d")
    for row in range(4):
        for col in range(5):
            x, y = 4 + col * 5, 4 + row * 7
            R(c, x - 1, y - 1, x + 3, y + 4, "wood_x"); circle(c, x + 1, y + 1.5, 1.6, "paper"); c.put(x + 1, y + 2, "paper_d")
            c.put(x + 1, y + 1, ["red", "blue", "gold", "green"][(row + col) % 4]) if (row * col) % 3 == 0 else None


@item("drawer_cabinet", "文件抽屜櫃", C2, 1, 16, 26)
def _(c, f):
    box(c, 1, 1, 14, 25, "wood", "wood_l", "wood_d")
    for y in (4, 11, 18):
        R(c, 3, y, 12, y + 5, "wood_l"); R(c, 3, y + 5, 12, y + 5, "wood_d"); R(c, 6, y + 2, 9, y + 2, "gold")
        R(c, 5, y + 1, 10, y + 1, "paper") if y == 11 else None


@item("treasure_chest", "寶箱", C2, 1, 18, 16)
def _(c, f):
    R(c, 1, 2, 16, 6, "wood_l"); R(c, 2, 1, 15, 1, "wood_l"); R(c, 1, 6, 16, 6, "wood_d")
    box(c, 1, 7, 16, 15, "wood", None, "wood_d")
    for x in (3, 14):
        R(c, x, 1, x, 15, "gold_d")
    R(c, 7, 6, 10, 9, "gold"); c.put(8, 8, "black")


@item("wardrobe", "衣櫃", C2, 2, 26, 40)
def _(c, f):
    box(c, 1, 2, 24, 39, "wood", "wood_l", "wood_d")
    R(c, 0, 1, 25, 3, "wood_l"); R(c, 12, 4, 13, 36, "wood_d")
    R(c, 3, 5, 11, 35, "wood"); R(c, 14, 5, 22, 35, "wood")
    R(c, 4, 6, 10, 34, "wood_l"); R(c, 15, 6, 21, 34, "wood_l"); R(c, 5, 7, 9, 33, "wood"); R(c, 16, 7, 20, 33, "wood")
    c.cells([(10, 20), (15, 20)], "gold"); R(c, 2, 37, 23, 39, "wood_d")


@item("trophy_cabinet", "獎盃櫃", C2, 2, 32, 36)
def _(c, f):
    box(c, 1, 1, 30, 35, "dark", "dark_l", "dark_d")
    for y in (4, 15, 26):
        R(c, 3, y, 28, y + 8, "glass_d"); R(c, 3, y, 28, y, "glass"); R(c, 2, y + 9, 29, y + 9, "dark_l")
    for x, y in ((6, 12), (14, 12), (22, 12), (8, 23), (19, 23), (12, 34)):
        R(c, x, y - 1, x + 3, y, "gold_d"); R(c, x, y - 5, x + 3, y - 3, "gold"); c.put(x + 1, y - 2, "gold"); c.put(x, y - 5, "gold_l")
    circle(c, 25, 21, 2, "white"); circle(c, 25, 21, 1, "blue")


@item("potion_shelf", "藥水架", C2, 2, 32, 28, 2, 2)
def _(c, f):
    box(c, 1, 1, 30, 27, "wood", "wood_l", "wood_d")
    for row, y in enumerate((9, 18, 26)):
        R(c, 3, y - 7, 28, y - 1, "wood_x"); R(c, 2, y, 29, y, "wood_l")
        for i, x in enumerate(range(4, 27, 5)):
            col = ["red", "blue", "green", "purple", "pink", "teal"][(i + row * 2) % 6]
            R(c, x, y - 4, x + 2, y - 1, col); c.put(x + 1, y - 5, "cloth"); c.put(x + 1, y - 6, "brown")
            if (i + row + f) % 3 == 0:
                c.put(x, y - 3, "white")


@item("crate_stack", "木箱堆", C2, 1, 18, 22)
def _(c, f):
    for x0, y0, s in ((1, 10, 11), (6, 1, 9)):
        box(c, x0, y0, x0 + s, y0 + s, "wood", "wood_l", "wood_d")
        R(c, x0 + 1, y0 + 1, x0 + s - 1, y0 + 1, "wood_d"); R(c, x0 + 1, y0 + s - 1, x0 + s - 1, y0 + s - 1, "wood_d")
        for i in range(1, s - 1):
            c.put(x0 + i, y0 + i, "wood_d")
    R(c, 13, 13, 16, 21, "wood"); R(c, 13, 13, 16, 13, "wood_l")


@item("barrel", "酒桶", C2, 1, 16, 18)
def _(c, f):
    for y in range(1, 17):
        bulge = 1 if 4 <= y <= 13 else 0
        R(c, 2 - bulge, y, 13 + bulge, y, "wood")
    R(c, 3, 1, 12, 2, "wood_l"); R(c, 13, 3, 14, 15, "wood_d")
    for y in (3, 9, 15):
        R(c, 1 if y == 9 else 2, y, 14 if y == 9 else 13, y, "iron")
    for x in (5, 9):
        R(c, x, 3, x, 15, "wood_d")


@item("armor_stand", "盔甲架", C2, 2, 22, 38)
def _(c, f):
    R(c, 10, 30, 11, 35, "wood_d"); R(c, 5, 35, 16, 37, "wood")
    R(c, 7, 2, 14, 9, "iron_l"); R(c, 8, 5, 13, 5, "black"); R(c, 10, 6, 11, 8, "black"); R(c, 13, 3, 14, 9, "iron")
    R(c, 10, 0, 11, 1, "red")
    R(c, 3, 11, 18, 14, "iron_l"); R(c, 5, 15, 16, 25, "iron"); R(c, 7, 16, 14, 23, "iron_l"); R(c, 10, 16, 11, 23, "red")
    R(c, 6, 26, 15, 29, "iron"); R(c, 6, 26, 15, 26, "gold")


@item("weapon_rack", "兵器架", C2, 2, 32, 30, note="都是練習用的鈍器")
def _(c, f):
    R(c, 2, 26, 29, 29, "wood"); R(c, 2, 26, 29, 26, "wood_l"); R(c, 2, 4, 29, 6, "wood_l"); R(c, 2, 6, 29, 7, "wood_d")
    R(c, 3, 4, 3, 26, "wood_d"); R(c, 28, 4, 28, 26, "wood_d")
    for x, top, k in ((7, 1, "iron_l"), (12, 3, "wood_d"), (17, 0, "iron_l"), (22, 2, "wood_d")):
        R(c, x, top, x, 25, k)
    R(c, 6, 1, 8, 2, "iron"); R(c, 15, 0, 19, 1, "iron_l"); R(c, 16, 2, 18, 3, "iron")
    R(c, 11, 3, 13, 5, "iron"); R(c, 21, 2, 23, 3, "gold"); R(c, 6, 9, 8, 9, "gold"); R(c, 16, 9, 18, 9, "gold")


@item("pigeon_post", "信鴿籠", C2, 1, 16, 26, 2, 2, note="代替信箱：信鴿把信送進來")
def _(c, f):
    R(c, 7, 14, 8, 23, "wood_d"); R(c, 4, 23, 11, 25, "wood")
    R(c, 2, 2, 13, 13, "wood_x"); R(c, 1, 1, 14, 2, "wood_l"); R(c, 1, 13, 14, 14, "wood")
    for x in (3, 6, 9, 12):
        R(c, x, 3, x, 12, "wood_l")
    R(c, 4, 8, 9, 11, "white"); R(c, 9 if f == 0 else 8, 7, 10 if f == 0 else 9, 8, "white"); c.put(10 if f == 0 else 9, 7, "black")
    c.put(11 if f == 0 else 10, 8, "orange"); R(c, 5, 11, 8, 11, "stone_l"); R(c, 3, 10, 5, 12, "paper")


# ===========================================================================================================================
# 桌上小物
# ===========================================================================================================================
C3 = "桌上小物"


@item("rune_keyboard", "符文鍵盤", C3, 1, 18, 8, 2, 3)
def _(c, f):
    R(c, 1, 2, 16, 6, "black"); R(c, 1, 2, 16, 2, "iron")
    for i, x in enumerate(range(2, 16, 2)):
        for y in (3, 5):
            c.put(x, y, "rune" if (i + y + f) % 3 else "glow")
    R(c, 6, 5, 11, 5, "rune_d")


@item("crystal_monitor", "水晶球螢幕", C3, 1, 14, 16, 2, 3, note="電腦：水晶球裡顯示符文")
def _(c, f):
    crystal(c, 6.5, 6, 5.4, 0)
    if f:
        R(c, 4, 4, 9, 4, "rune"); R(c, 3, 6, 8, 6, "glow"); R(c, 4, 8, 9, 8, "rune")
    else:
        R(c, 4, 5, 8, 5, "rune"); R(c, 5, 7, 10, 7, "rune")
    R(c, 4, 12, 9, 12, "gold"); R(c, 2, 13, 11, 14, "gold_d"); R(c, 3, 13, 10, 13, "gold")


@item("magic_printer", "魔導印表機", C3, 2, 24, 22, 3, 4, note="印表機：吐出羊皮紙")
def _(c, f):
    box(c, 2, 8, 21, 20, "iron", "iron_l", "iron_d"); R(c, 4, 6, 19, 8, "iron_d"); R(c, 6, 11, 17, 12, "black")
    c.put(18, 15, "rune" if f % 2 else "rune_d"); c.put(16, 15, "f2")
    R(c, 7, 2, 16, 6, "paper"); R(c, 8, 3, 14, 3, "ink")
    out = [0, 3, 6][f]
    R(c, 7, 12, 16, 12 + out, "paper") if out else None
    if out:
        R(c, 8, 13, 14, 13, "ink"); R(c, 8, 13 + out - 1, 12, 13 + out - 1, "ink") if out > 3 else None


@item("quill_ink", "羽毛筆墨水", C3, 1, 12, 14)
def _(c, f):
    R(c, 2, 9, 8, 13, "ink"); R(c, 3, 8, 7, 8, "iron"); c.put(3, 10, "blue")
    for i in range(8):
        R(c, 5 + i // 2, 8 - i, 6 + i // 2, 8 - i, "white" if i > 1 else "cloth_d")
    R(c, 9, 1, 10, 3, "white"); c.put(11, 0, "white")


@item("book_stack", "書堆", C3, 1, 16, 14)
def _(c, f):
    for i, (x0, x1, k) in enumerate(((1, 14, "red"), (2, 12, "blue"), (1, 13, "green"), (3, 11, "purple"))):
        y = 11 - i * 3
        R(c, x0, y, x1, y + 2, k); R(c, x0, y, x0, y + 2, k + "_d"); R(c, x0 + 1, y + 1, x1, y + 1, "paper")
    R(c, 5, 0, 8, 1, "gold")


@item("desk_candle", "桌上蠟燭", C3, 1, 10, 16, 3, 6)
def _(c, f):
    R(c, 1, 13, 8, 15, "gold_d"); R(c, 2, 13, 7, 13, "gold"); R(c, 3, 6, 6, 12, "cloth"); R(c, 6, 7, 6, 12, "cloth_d")
    c.put(3, 7, "white"); c.put(2, 9, "cloth"); flame(c, 4, 5, 5, f)


@item("hourglass", "沙漏", C3, 1, 10, 14, 2, 1)
def _(c, f):
    R(c, 1, 0, 8, 1, "wood"); R(c, 1, 12, 8, 13, "wood"); R(c, 1, 2, 1, 11, "wood_d"); R(c, 8, 2, 8, 11, "wood_d")
    for i, (a, b) in enumerate(((2, 7), (3, 6), (4, 5), (4, 5), (3, 6), (2, 7))):
        R(c, a, 2 + i * 2, b, 3 + i * 2, "glass")
    R(c, 3, 3 + f, 6, 5, "straw"); R(c, 3, 9 - f, 6, 11, "straw"); c.put(4, 7, "straw")


@item("globe", "地球儀", C3, 1, 16, 18)
def _(c, f):
    circle(c, 7.5, 7, 6, "water"); circle(c, 8.3, 7.8, 5, "water_d")
    for x, y in ((5, 4), (6, 4), (6, 5), (9, 7), (10, 6), (10, 8), (5, 9), (6, 10)):
        c.put(x, y, "green")
    c.put(5, 3, "water_l")
    for i in range(9):
        c.put(int(7.5 + 7 * math.cos(math.pi * (0.3 + i / 9))), int(7 - 7 * math.sin(math.pi * (0.3 + i / 9))), "gold")
    R(c, 7, 14, 8, 15, "gold_d"); R(c, 4, 16, 11, 17, "wood")


@item("coffee_mug", "咖啡杯", C3, 1, 10, 10)
def _(c, f):
    R(c, 1, 2, 6, 8, "white"); R(c, 1, 2, 6, 2, "cloth_d"); R(c, 2, 3, 5, 3, "brown"); R(c, 7, 4, 8, 6, "white"); c.put(7, 5, None)
    R(c, 6, 3, 6, 8, "cloth_d"); c.put(3, 0, "cloth_d"); c.put(4, 1, "cloth_d"); c.put(3, 6, "red")


@item("potion_bottle", "藥水瓶", C3, 1, 10, 14, 2, 3)
def _(c, f):
    circle(c, 4.5, 9, 4, "glass_d"); circle(c, 4.5, 9.6, 3.3, "purple"); R(c, 3, 2, 6, 5, "glass")
    R(c, 3, 1, 6, 2, "brown"); c.put(3, 8, "white")
    c.put(5, 10 - f * 2, "purple_l"); c.put(3 + f, 11, "purple_l")


@item("scroll_pile", "卷軸堆", C3, 1, 16, 12)
def _(c, f):
    for x0, y0, k in ((1, 6, "paper"), (5, 7, "paper"), (3, 2, "paper")):
        R(c, x0, y0, x0 + 9, y0 + 3, k); R(c, x0, y0 + 3, x0 + 9, y0 + 3, "paper_d")
        R(c, x0, y0, x0, y0 + 3, "wood_d"); R(c, x0 + 9, y0, x0 + 9, y0 + 3, "wood_d")
    R(c, 7, 2, 7, 5, "red"); R(c, 11, 7, 11, 10, "gold")


@item("plain_mac", "普通的 Mac", C3, 2, 22, 22, note="原汁原味的現代彩蛋")
def _(c, f):
    box(c, 1, 0, 20, 14, "mac", "white", "mac_d"); R(c, 3, 2, 18, 11, "screen"); R(c, 3, 2, 18, 2, "screen_l")
    R(c, 5, 5, 9, 8, "screen_l"); R(c, 11, 5, 16, 5, "screen_l"); R(c, 11, 7, 15, 7, "screen_l")
    R(c, 8, 15, 13, 17, "mac_d"); R(c, 5, 18, 16, 19, "mac"); R(c, 2, 20, 19, 21, "mac_d"); c.put(10, 13, "mac_d")


@item("succulent", "小多肉", C3, 1, 10, 12)
def _(c, f):
    pot(c, 5, 11, 6, 4)
    for x, y in ((4, 4), (6, 4), (3, 5), (7, 5), (5, 3), (5, 5)):
        c.put(x, y, "teal"); c.put(x, y + 1, "teal_d")
    c.put(5, 2, "teal_l"); c.put(5, 3, "pink")


# ===========================================================================================================================
# 燈具
# ===========================================================================================================================
C4 = "燈具"


@item("everburning_torch", "永燃火把", C4, 1, 10, 22, 3, 6, wall=True, note="電燈：永遠不會熄的火把")
def _(c, f):
    R(c, 3, 10, 6, 11, "iron"); R(c, 4, 12, 5, 20, "wood_d"); R(c, 2, 9, 7, 9, "iron_l"); R(c, 3, 21, 6, 21, "iron")
    flame(c, 4, 8, 7, f, 2); c.put(4, 7, "f4")


@item("light_orb", "浮空光球", C4, 1, 12, 24, 4, 4, note="電燈：飄在空中的光球（底下一圈淡淡的光）")
def _(c, f):
    y = 6 + [0, 1, 2, 1][f]
    circle(c, 5.5, y, 4, "f1"); circle(c, 5.5, y, 2.5, "f4"); c.put(4, y - 2, "white")
    for i, (x, dy) in enumerate(((1, -4), (10, -1), (2, 4), (9, 5))):
        if (i + f) % 2 == 0:
            c.put(x, y + dy, "f1")

def _(c, f):
    y = 6 + [0, 1, 2, 1][f]
    circle(c, 5.5, y, 4, "f1"); circle(c, 5.5, y, 2.5, "f4"); c.put(4, y - 2, "white")
    for i, (x, dy) in enumerate(((1, -4), (10, -1), (2, 4), (9, 5))):
        if (i + f) % 2 == 0:
            c.put(x, y + dy, "f1")
    circle(c, 5.5, 22, 3, "stone_d", 1)                                    # its shadow on the floor (soft)


@item("candelabra", "燭台", C4, 1, 16, 22, 3, 6)
def _(c, f):
    R(c, 7, 9, 8, 19, "gold"); R(c, 4, 19, 11, 21, "gold_d"); R(c, 5, 19, 10, 19, "gold")
    R(c, 2, 11, 13, 11, "gold"); R(c, 2, 9, 2, 10, "gold"); R(c, 13, 9, 13, 10, "gold")
    for x in (2, 7, 13):
        R(c, x, 5 if x == 7 else 6, x, 8, "cloth"); flame(c, x, 4 if x == 7 else 5, 3, f + x, 0)


@item("chandelier", "吊燈", C4, 4, 40, 24, 3, 6, ceiling=True, note="掛在天花板：畫在其他東西上面")
def _(c, f):
    R(c, 19, 0, 20, 6, "iron"); circle(c, 19.5, 14, 17, "iron_d", 4); circle(c, 19.5, 13, 17, "iron", 3)
    R(c, 3, 13, 36, 14, "iron_l")
    for x in range(4, 37, 8):
        R(c, x, 8, x + 1, 12, "cloth"); flame(c, x, 7, 4, f + x // 8, 0)
    R(c, 17, 17, 22, 18, "gold"); R(c, 19, 19, 20, 21, "gold")


@item("lantern", "提燈", C4, 1, 12, 18, 2, 3)
def _(c, f):
    R(c, 4, 0, 7, 1, "iron"); R(c, 2, 2, 9, 3, "iron"); R(c, 2, 13, 9, 15, "iron")
    R(c, 3, 4, 8, 12, "f1" if f == 0 else "f2"); R(c, 2, 4, 2, 12, "iron"); R(c, 9, 4, 9, 12, "iron")
    R(c, 5, 6, 6, 10, "f4"); c.put(5, 16, "iron"); R(c, 4, 16, 7, 17, "iron_d")


@item("brazier", "火盆", C4, 2, 18, 22, 3, 6)
def _(c, f):
    R(c, 2, 10, 15, 12, "iron"); R(c, 3, 13, 14, 14, "iron_d"); R(c, 2, 10, 15, 10, "iron_l")
    for x in (4, 13):
        R(c, x, 15, x, 21, "iron_d")
    R(c, 6, 18, 11, 18, "iron_d")
    for x, h in ((6, 5), (9, 8), (12, 6)):
        flame(c, x, 9, h + (f % 2), f + x, 1)


@item("crystal_lamp", "水晶檯燈", C4, 1, 12, 18, 2, 2)
def _(c, f):
    for i, (a, b) in enumerate(((5, 6), (4, 7), (3, 8), (3, 8), (4, 7), (5, 6))):
        R(c, a, 2 + i, b, 2 + i, "purple_l" if f else "purple")
    c.put(5, 3, "white"); R(c, 5, 8, 6, 13, "gold"); R(c, 2, 14, 9, 16, "gold_d"); R(c, 3, 14, 8, 14, "gold")
    if f:
        c.cells([(1, 3), (10, 5), (2, 7)], "purple_l")


@item("wall_sconce", "壁燈", C4, 1, 12, 16, 3, 6, wall=True)
def _(c, f):
    R(c, 3, 10, 8, 13, "iron"); R(c, 5, 14, 6, 15, "iron_d"); R(c, 2, 10, 9, 10, "iron_l")
    R(c, 4, 6, 7, 9, "cloth"); flame(c, 5, 5, 4, f, 0)


@item("mushroom_lamp", "蘑菇燈", C4, 1, 14, 16, 2, 2)
def _(c, f):
    circle(c, 6.5, 5, 6, "red", 4); R(c, 1, 6, 12, 7, "cloth_d")
    for x, y in ((4, 3), (8, 2), (10, 5), (3, 6)):
        c.put(x, y, "white")
    R(c, 5, 8, 8, 14, "cloth"); R(c, 8, 8, 8, 14, "cloth_d"); R(c, 3, 14, 10, 15, "green")
    if f:
        R(c, 2, 7, 11, 7, "f1")


@item("star_lantern", "星星燈", C4, 1, 14, 18, 2, 2, ceiling=True, note="掛在天花板的星星紙燈")
def _(c, f):
    R(c, 6, 0, 7, 3, "iron")
    pts = [(6, 4), (7, 4), (5, 6), (8, 6), (1, 7), (12, 7), (2, 8), (11, 8), (4, 10), (9, 10), (3, 12), (10, 12), (2, 14), (11, 14)]
    for y in range(4, 15):
        span = {4: (6, 7), 5: (5, 8), 6: (5, 8), 7: (1, 12), 8: (2, 11), 9: (3, 10), 10: (4, 9), 11: (3, 10), 12: (3, 10),
                13: (2, 11), 14: (2, 4)}[y]
        R(c, span[0], y, span[1], y, "yellow" if f else "f1")
    R(c, 9, 14, 11, 14, "yellow" if f else "f1"); R(c, 5, 8, 8, 10, "f4")


@item("firefly_jar", "螢火蟲罐", C4, 1, 10, 14, 3, 4)
def _(c, f):
    R(c, 1, 3, 8, 13, "glass_d"); R(c, 2, 4, 7, 12, "glass"); R(c, 2, 1, 7, 2, "wood"); R(c, 1, 13, 8, 13, "glass_d")
    pts = [[(3, 6), (6, 9), (4, 11)], [(5, 5), (3, 9), (6, 11)], [(4, 7), (6, 6), (3, 10)]][f]
    for x, y in pts:
        c.put(x, y, "f1"); c.put(x, y - 1, "yellow")


@item("moon_lamp", "月亮燈", C4, 1, 16, 18, 2, 2)
def _(c, f):
    circle(c, 7.5, 7, 6, "f1" if f else "cloth"); circle(c, 10, 5.5, 5, None)
    for x, y in ((4, 5), (5, 9)):
        c.put(x, y, "cloth_d")
    R(c, 7, 13, 8, 15, "wood_d"); R(c, 4, 16, 11, 17, "wood")


# ===========================================================================================================================
# 牆上掛飾 (all on the back wall)
# ===========================================================================================================================
C5 = "牆上掛飾"


@item("guild_banner", "公會旗幟", C5, 1, 16, 32, wall=True, note="會長畫的徽章可以印在上面")
def _(c, f):
    R(c, 1, 1, 14, 1, "gold_d"); c.cells([(0, 1), (15, 1)], "gold")
    R(c, 2, 2, 13, 24, "red"); R(c, 2, 2, 2, 24, "red_d"); R(c, 13, 2, 13, 24, "red_d")
    for i in range(4):
        R(c, 2 + i, 25 + i, 7, 25 + i, "red"); R(c, 8, 25 + i, 13 - i, 25 + i, "red")
    R(c, 4, 6, 11, 17, "gold"); R(c, 5, 7, 10, 16, "red_d"); R(c, 6, 9, 9, 14, "gold"); R(c, 7, 10, 8, 13, "red")


@item("tapestry", "掛毯", C5, 2, 32, 32, wall=True)
def _(c, f):
    R(c, 0, 0, 31, 1, "wood"); R(c, 2, 2, 29, 28, "blue"); R(c, 2, 2, 29, 3, "gold"); R(c, 2, 27, 29, 28, "gold")
    R(c, 4, 5, 27, 25, "blue_d")
    for x, y in ((8, 20), (9, 19), (10, 18), (11, 17), (12, 16), (13, 15), (14, 14), (15, 13), (16, 12), (17, 12)):
        c.put(x, y, "white")
    R(c, 16, 9, 22, 12, "green"); R(c, 22, 10, 25, 11, "green"); c.put(24, 9, "f2"); c.put(20, 8, "green")   # a knight and a dragon
    R(c, 7, 17, 9, 22, "iron_l"); R(c, 7, 16, 9, 16, "iron")
    for x in range(3, 29, 3):
        c.put(x, 29, "gold"); c.put(x, 30, "gold_d")


@item("world_map", "世界地圖", C5, 2, 32, 24, wall=True)
def _(c, f):
    frame_border(c, 0, 0, 31, 23); R(c, 2, 2, 29, 21, "paper")
    for pts, k in (([(4, 5), (12, 5), (13, 9), (10, 12), (5, 11)], "green"), ([(16, 8), (25, 6), (27, 13), (20, 17), (17, 14)], "green")):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        R(c, min(xs), min(ys), max(xs), max(ys), k)
    R(c, 6, 7, 9, 9, "green_d"); R(c, 21, 9, 24, 12, "brown"); c.put(22, 10, "white")
    R(c, 2, 14, 15, 21, "water_l"); R(c, 26, 16, 29, 21, "water_l"); c.put(11, 7, "red"); c.put(19, 12, "red")
    c.cells([(27, 3), (28, 4), (26, 4), (27, 5)], "ink")


@item("magic_chalkboard", "魔法黑板", C5, 2, 32, 24, 3, 3, wall=True, note="白板：粉筆自己寫字")
def _(c, f):
    frame_border(c, 0, 0, 31, 21); R(c, 2, 2, 29, 19, "board"); R(c, 2, 20, 29, 21, "wood_l")
    lines = [(4, 4, 18), (4, 8, 24), (4, 12, 14 + f * 4)]
    for x0, y, x1 in lines[:2 + (1 if f else 0)]:
        for x in range(x0, x1, 2):
            c.put(x, y, "chalk"); c.put(x + 1, y + (x // 2) % 2, "chalk")
    cx = [18, 24, 18 + f * 4][f]
    R(c, cx, 13 - (0 if f else 9), cx + 1, 14 - (0 if f else 9), "white")
    c.cells([(cx + 2, 11 - (0 if f else 9))], "f1")
    R(c, 22, 20, 25, 20, "white")


@item("scrying_mirror", "占卜鏡", C5, 2, 28, 26, 3, 3, wall=True, note="電視：鏡子裡播著遠方的畫面")
def _(c, f):
    circle(c, 13.5, 12, 12.5, "gold_d", 12); circle(c, 13.5, 12, 11.5, "gold", 11); circle(c, 13.5, 12, 10, "purple_d", 9.5)
    scene = [((6, 14, 21, 18), "green"), ((9, 12, 18, 14), "green_l"), ((8, 6, 12, 9), "f1")][f]
    if f == 0:
        R(c, 6, 14, 21, 17, "green"); R(c, 13, 8, 16, 13, "stone_l"); R(c, 14, 6, 15, 7, "red")
    elif f == 1:
        R(c, 6, 13, 21, 17, "water"); R(c, 10, 10, 14, 12, "wood"); R(c, 12, 6, 12, 9, "white")
    else:
        circle(c, 13.5, 11, 4, "f1"); c.cells([(6, 6), (20, 7), (8, 16), (19, 15)], "white")
    c.put(8, 5, "white"); R(c, 12, 0, 15, 1, "gold_l"); R(c, 11, 23, 16, 25, "gold_d")


@item("notice_board", "公告欄", C5, 2, 28, 24, wall=True)
def _(c, f):
    frame_border(c, 0, 0, 27, 23); R(c, 2, 2, 25, 21, "fur_d")
    for x0, y0, w, h, k in ((4, 4, 7, 8, "paper"), (13, 3, 9, 6, "cloth"), (14, 12, 8, 7, "paper"), (5, 14, 6, 6, "pink")):
        R(c, x0, y0, x0 + w, y0 + h, k); c.put(x0 + w // 2, y0, "red")
        for yy in range(y0 + 2, y0 + h, 2):
            R(c, x0 + 1, yy, x0 + w - 2, yy, "ink") if k != "pink" else None


@item("portrait", "會長肖像", C5, 1, 18, 22, wall=True, note="放上會長的分身模樣（之後可換）")
def _(c, f):
    frame_border(c, 0, 0, 17, 21, "gold"); R(c, 2, 2, 15, 19, "blue_d")
    circle(c, 8.5, 9, 4, "skin"); R(c, 4, 4, 13, 6, "brown"); c.put(7, 9, "ink"); c.put(10, 9, "ink")
    R(c, 4, 14, 13, 19, "red"); R(c, 8, 14, 9, 19, "gold")


@item("shield_crest", "盾徽", C5, 1, 16, 20, wall=True)
def _(c, f):
    for y in range(1, 19):
        w = 6 if y < 11 else 6 - (y - 10) * 0.8
        R(c, int(7.5 - w), y, int(7.5 + w), y, "blue")
    R(c, 7, 1, 8, 17, "gold"); R(c, 1, 7, 14, 8, "gold"); R(c, 1, 1, 14, 1, "iron_l")
    circle(c, 7.5, 7.5, 2, "red")


@item("crossed_swords", "交叉雙劍", C5, 1, 22, 20, wall=True)
def _(c, f):
    for i in range(14):                                                   # two blades crossing in the middle
        c.put(2 + i, 1 + i, "iron_l"); c.put(3 + i, 1 + i, "iron")
        c.put(19 - i, 1 + i, "iron_l"); c.put(18 - i, 1 + i, "iron")
    R(c, 13, 14, 18, 15, "gold"); R(c, 3, 14, 8, 15, "gold")              # cross-guards
    R(c, 16, 16, 17, 18, "brown"); R(c, 4, 16, 5, 18, "brown"); c.cells([(17, 19), (4, 19)], "gold")
    circle(c, 10.5, 8, 2.2, "red"); c.put(10, 7, "red_l")


@item("wall_clock", "掛鐘", C5, 1, 16, 24, 2, 1, wall=True)
def _(c, f):
    circle(c, 7.5, 6, 6, "wood"); circle(c, 7.5, 6, 4.5, "paper"); R(c, 7, 3, 7, 6, "ink"); R(c, 8, 6, 9, 6, "ink")
    R(c, 5, 12, 10, 23, "wood"); R(c, 6, 13, 9, 22, "wood_x")
    px = 6 if f == 0 else 9
    R(c, 7, 13, 8, 18, "gold_d") if False else None
    c.put(7, 14, "gold"); c.put(7 + (px - 7.5 > 0), 17, "gold"); circle(c, px, 20, 1, "gold")


@item("deer_trophy", "鹿頭標本", C5, 1, 20, 18, wall=True, note="木雕的，不是真的")
def _(c, f):
    R(c, 6, 13, 13, 17, "wood"); R(c, 5, 13, 14, 13, "wood_l")
    R(c, 7, 5, 12, 12, "fur"); R(c, 8, 10, 11, 13, "fur_d"); c.put(8, 7, "black"); c.put(11, 7, "black"); R(c, 9, 12, 10, 12, "black")
    for side in (-1, 1):
        f_ = (lambda x: x) if side < 0 else (lambda x: 19 - x)
        c.cells([(f_(6), 4), (f_(5), 3), (f_(4), 2), (f_(4), 1), (f_(3), 0), (f_(6), 2), (f_(7), 1), (f_(2), 2)], "wood_l")


@item("calendar", "月曆", C5, 1, 14, 18, wall=True)
def _(c, f):
    R(c, 1, 2, 12, 16, "paper"); R(c, 1, 2, 12, 5, "red"); c.cells([(4, 1), (9, 1)], "iron")
    for y in range(7, 16, 2):
        for x in range(2, 12, 2):
            c.put(x, y, "ink")
    c.put(8, 11, "red"); R(c, 1, 16, 12, 16, "paper_d")


@item("landscape_painting", "風景畫", C5, 1, 22, 18, wall=True)
def _(c, f):
    frame_border(c, 0, 0, 21, 17, "gold"); R(c, 2, 2, 19, 9, "blue_l"); R(c, 2, 10, 19, 15, "green")
    for x, y in ((6, 5), (7, 4), (8, 5), (9, 6), (5, 6)):
        c.put(x, y, "stone"); R(c, x, y + 1, x, 9, "stone")
    circle(c, 15, 5, 2, "f1"); R(c, 11, 12, 19, 13, "water"); c.put(4, 12, "green_d")


# ===========================================================================================================================
# 地毯 (flat)
# ===========================================================================================================================
C6 = "地毯"


def rug_base(c, w, h, base, border, inner=None, fringe=True):
    R(c, 1, 1, w - 2, h - 2, border); R(c, 3, 3, w - 4, h - 4, base)
    if inner:
        R(c, 4, 4, w - 5, h - 5, inner); R(c, 5, 5, w - 6, h - 6, base)
    if fringe:
        for x in range(2, w - 2, 3):
            c.put(x, 0, border); c.put(x, h - 1, border)


@item("red_rug", "紅地毯", C6, 4, 48, 32, flat=True)
def _(c, f):
    rug_base(c, 48, 32, "red", "gold", "red_d")
    for r in range(6):
        R(c, 18 + r, 16 - r, 29 - r, 16 - r, "gold" if r % 2 else "gold_d"); R(c, 18 + r, 16 + r, 29 - r, 16 + r, "gold" if r % 2 else "gold_d")


@item("round_rug", "圓地毯", C6, 2, 32, 24, flat=True)
def _(c, f):
    circle(c, 15.5, 11.5, 15, "blue_d", 11); circle(c, 15.5, 11.5, 13.5, "blue", 9.5); circle(c, 15.5, 11.5, 9, "cloth", 6)
    circle(c, 15.5, 11.5, 7.5, "blue_l", 5); circle(c, 15.5, 11.5, 3, "gold", 2)


@item("runner_rug", "走道長地毯", C6, 2, 16, 48, flat=True)
def _(c, f):
    rug_base(c, 16, 48, "red", "gold", None, False)
    for y in range(6, 44, 8):
        c.cells([(7, y), (8, y), (6, y + 1), (9, y + 1), (7, y + 2), (8, y + 2)], "gold")


@item("star_rug", "星空地毯", C6, 4, 48, 32, 2, 2, flat=True)
def _(c, f):
    rug_base(c, 48, 32, "purple_d", "purple_l", None, False)
    import random
    rng = random.Random(4)
    for i in range(26):
        x, y = rng.randrange(4, 44), rng.randrange(4, 28)
        c.put(x, y, "white" if (i + f) % 3 else "yellow")
    circle(c, 32, 11, 4, "f1"); circle(c, 34, 10, 3.5, "purple_d")


@item("fur_rug", "毛皮地毯", C6, 2, 32, 20, flat=True)
def _(c, f):
    circle(c, 15.5, 10, 13, "fur_d", 8); circle(c, 15.5, 9.5, 12, "fur", 7)
    for x in range(4, 28, 3):
        c.put(x, 2 + (x % 2), "fur_l"); c.put(x + 1, 16 - (x % 2), "fur_d")
    c.cells([(2, 4), (1, 5), (29, 4), (30, 5), (2, 15), (1, 16), (29, 15), (30, 16)], "fur_d")


@item("woven_mat", "編織草蓆", C6, 2, 32, 20, flat=True)
def _(c, f):
    R(c, 1, 1, 30, 18, "straw")
    for y in range(1, 19):
        for x in range(1, 31):
            if (x // 2 + y) % 3 == 0:
                c.put(x, y, "straw_d")
    R(c, 1, 1, 30, 1, "brown"); R(c, 1, 18, 30, 18, "brown")


@item("rune_circle_rug", "符文法陣地毯", C6, 4, 40, 32, 3, 3, flat=True)
def _(c, f):
    circle(c, 19.5, 15.5, 19, "black", 15); circle(c, 19.5, 15.5, 17.5, "purple_d", 13.5)
    k = ["rune_d", "rune", "glow"][f]
    for a in range(0, 360, 6):
        c.put(int(19.5 + 16 * math.cos(math.radians(a))), int(15.5 + 12 * math.sin(math.radians(a))), k)
        c.put(int(19.5 + 10 * math.cos(math.radians(a))), int(15.5 + 7.5 * math.sin(math.radians(a))), "rune_d" if f != 1 else "rune")
    for i in range(5):
        a1, a2 = math.radians(-90 + i * 144), math.radians(-90 + (i + 1) * 144)
        for t in range(12):
            tt = t / 11
            c.put(int(19.5 + 10 * ((1 - tt) * math.cos(a1) + tt * math.cos(a2))),
                  int(15.5 + 7.5 * ((1 - tt) * math.sin(a1) + tt * math.sin(a2))), k)


@item("checker_rug", "格子地毯", C6, 2, 32, 24, flat=True)
def _(c, f):
    R(c, 1, 1, 30, 22, "green_d")
    for y in range(3, 21, 3):
        for x in range(3, 29, 3):
            R(c, x, y, x + 2, y + 2, "green" if (x + y) % 2 else "cloth")


@item("welcome_mat", "門口腳踏墊", C6, 1, 16, 10, flat=True)
def _(c, f):
    R(c, 0, 0, 15, 9, "brown"); R(c, 1, 1, 14, 8, "straw")
    R(c, 3, 3, 4, 6, "brown"); R(c, 6, 3, 7, 6, "brown"); R(c, 9, 3, 12, 3, "brown"); R(c, 9, 5, 12, 6, "brown")


@item("emblem_rug", "徽章地毯", C6, 4, 40, 32, flat=True, note="中間是公會徽章的位置")
def _(c, f):
    rug_base(c, 40, 32, "blue_d", "gold", "blue")
    for y in range(7, 26):
        w = 7 if y < 17 else 7 - (y - 16) * 0.8
        R(c, int(19.5 - w), y, int(19.5 + w), y, "red")
    R(c, 12, 7, 27, 7, "gold"); R(c, 19, 9, 20, 22, "gold"); R(c, 14, 13, 25, 14, "gold")


# ===========================================================================================================================
# 植物
# ===========================================================================================================================
C7 = "植物"


@item("potted_fern", "蕨類盆栽", C7, 1, 16, 24)
def _(c, f):
    pot(c, 8, 23, 9, 7)
    for x, y0, h in ((7, 3, 13), (5, 6, 10), (10, 5, 11), (3, 9, 6), (12, 8, 7)):
        R(c, x, y0, x, y0 + h - 1, "green_d")
    for (x, y) in ((6, 3), (7, 2), (8, 3), (4, 6), (5, 5), (10, 4), (11, 5), (9, 4), (2, 9), (3, 8), (12, 8), (13, 9),
                   (6, 8), (9, 9), (4, 11), (11, 11), (7, 7), (8, 11)):
        R(c, x - 1, y, x + 1, y, "green"); c.put(x, y - 1, "green_l")


@item("potted_tree", "大盆樹", C7, 2, 26, 38)
def _(c, f):
    pot(c, 13, 37, 12, 9); R(c, 12, 18, 13, 28, "wood_d"); c.put(11, 22, "wood_d"); c.put(14, 20, "wood_d")
    blob(c, 13, 11, 10, ry=9); blob(c, 7, 15, 5); blob(c, 19, 15, 5)


@item("cactus", "仙人掌", C7, 1, 14, 20)
def _(c, f):
    pot(c, 7, 19, 8, 5)
    R(c, 5, 3, 8, 14, "green"); R(c, 8, 4, 8, 14, "green_d"); R(c, 6, 2, 7, 2, "green")
    R(c, 2, 7, 3, 10, "green"); R(c, 2, 10, 5, 11, "green"); R(c, 10, 5, 11, 8, "green"); R(c, 8, 8, 11, 9, "green_d")
    c.put(6, 1, "pink"); c.cells([(5, 6), (7, 9), (6, 12)], "green_l")


@item("flower_pot", "花盆", C7, 1, 14, 18)
def _(c, f):
    pot(c, 7, 17, 8, 6)
    for x, y, k in ((4, 4, "red"), (7, 2, "yellow"), (10, 5, "pink"), (6, 6, "purple_l")):
        R(c, x, y + 2, x, 11, "green_d"); c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], k); c.put(x, y, "yellow")
    c.cells([(5, 9), (9, 8), (3, 10)], "green")


@item("hanging_ivy", "吊盆藤蔓", C7, 1, 16, 26, wall=True)
def _(c, f):
    R(c, 7, 0, 8, 3, "iron"); pot(c, 8, 9, 10, 5)
    for x, top, h in ((3, 9, 14), (6, 9, 10), (10, 9, 16), (13, 9, 9)):
        for y in range(top, top + h):
            c.put(x + (y // 3) % 2, y, "green" if y % 3 else "green_l")
    c.cells([(2, 12), (12, 15), (5, 17)], "green_d")


@item("bonsai", "盆景", C7, 1, 18, 16)
def _(c, f):
    R(c, 2, 12, 15, 15, "blue"); R(c, 2, 12, 15, 12, "blue_l")
    R(c, 8, 7, 9, 11, "wood_d"); R(c, 6, 9, 8, 9, "wood_d"); R(c, 10, 6, 12, 6, "wood_d")
    blob(c, 5, 6, 3, ry=2); blob(c, 11, 4, 4, ry=3); blob(c, 14, 7, 2, ry=1.5)


@item("sunflower", "向日葵", C7, 1, 14, 26)
def _(c, f):
    pot(c, 7, 25, 8, 5); R(c, 6, 10, 7, 20, "green_d"); R(c, 3, 14, 5, 15, "green"); R(c, 8, 16, 10, 17, "green")
    circle(c, 6.5, 6, 5.5, "yellow"); circle(c, 6.5, 6, 2.6, "brown"); c.cells([(5, 5), (7, 7)], "dark_d")


@item("herb_planter", "香草盆", C7, 2, 30, 16)
def _(c, f):
    R(c, 1, 8, 28, 15, "wood"); R(c, 1, 8, 28, 9, "wood_l"); R(c, 28, 9, 28, 15, "wood_d")
    for i, x in enumerate(range(3, 27, 4)):
        k = ["green", "green_l", "teal", "green", "purple_l", "green_l"][i]
        R(c, x, 4, x + 2, 7, k); c.put(x + 1, 3, k); c.put(x, 5, "green_d")
    R(c, 3, 11, 27, 11, "wood_d")


@item("glow_mushrooms", "發光蘑菇", C7, 1, 16, 16, 2, 2)
def _(c, f):
    R(c, 1, 12, 14, 15, "brown"); R(c, 1, 12, 14, 12, "dark_l")
    for x, y, r in ((5, 6, 3), (11, 8, 2.5), (8, 10, 1.6)):
        circle(c, x, y, r, "teal_l" if f else "teal", r * 0.7); R(c, int(x), int(y + 1), int(x), 11, "cloth")
        c.put(int(x - 1), int(y - 1), "glow")
    if f:
        c.cells([(2, 3), (14, 4), (9, 2)], "teal_l")


@item("bamboo", "竹子", C7, 1, 14, 32)
def _(c, f):
    pot(c, 7, 31, 10, 6, "stone")
    for x, top in ((4, 2), (7, 6), (10, 0)):
        R(c, x, top, x, 25, "green_l"); [c.put(x, y, "green_d") for y in range(top + 4, 25, 5)]
    for x, y in ((5, 4), (2, 8), (8, 8), (11, 3), (12, 9), (6, 13)):
        R(c, x, y, x + 2, y, "green")


@item("rose_bush", "玫瑰叢", C7, 2, 26, 20)
def _(c, f):
    blob(c, 8, 11, 7, ry=6); blob(c, 17, 11, 7, ry=6); blob(c, 12.5, 8, 6, ry=5)
    for x, y in ((6, 8), (11, 5), (16, 8), (20, 12), (9, 13), (14, 11), (4, 13)):
        c.cells([(x, y), (x + 1, y)], "red"); c.put(x, y - 1, "red_l")
    R(c, 3, 18, 22, 19, "brown")


@item("crystal_flower", "水晶花", C7, 1, 12, 18, 2, 2)
def _(c, f):
    pot(c, 6, 17, 8, 5)
    R(c, 5, 7, 6, 12, "green_d"); c.put(3, 10, "green"); c.put(8, 9, "green")
    for x, y in ((5, 2), (4, 3), (6, 3), (3, 4), (7, 4), (5, 5)):
        c.put(x, y, "ice" if (x + y + f) % 2 else "ice_d")
    c.put(5, 4, "glow" if f else "white")


# ===========================================================================================================================
# 雕像與紀念物
# ===========================================================================================================================
C8 = "雕像與紀念物"


def plinth(c, x0, x1, top, bottom):
    R(c, x0, top, x1, bottom, "stone"); R(c, x0, top, x1, top, "stone_l"); R(c, x1, top + 1, x1, bottom, "stone_d")
    R(c, x0 - 1, bottom - 1, x1 + 1, bottom, "stone_d")


@item("hero_statue", "英雄雕像", C8, 4, 26, 46)
def _(c, f):
    plinth(c, 4, 21, 36, 45)
    circle(c, 12.5, 7, 4, "stone_l"); R(c, 9, 12, 16, 24, "stone"); R(c, 16, 12, 16, 24, "stone_d")
    R(c, 7, 12, 8, 20, "stone"); R(c, 17, 4, 18, 18, "stone_l"); R(c, 15, 10, 20, 11, "stone")      # sword raised
    R(c, 10, 25, 11, 35, "stone"); R(c, 14, 25, 15, 35, "stone_d"); R(c, 5, 13, 7, 26, "stone_d")   # cape
    R(c, 8, 39, 17, 41, "gold")


@item("dragon_statue", "龍雕像", C8, 4, 42, 38)
def _(c, f):
    plinth(c, 4, 37, 30, 37)
    R(c, 12, 16, 30, 28, "stone"); R(c, 12, 26, 30, 28, "stone_d")
    R(c, 26, 8, 30, 16, "stone"); R(c, 28, 4, 35, 9, "stone_l"); c.put(33, 6, "red"); R(c, 35, 7, 37, 8, "stone")
    c.cells([(29, 3), (30, 2), (32, 3), (33, 2)], "stone_d")
    for i in range(10):
        R(c, 14 - i, 6 + i, 16 - i // 2, 6 + i, "stone_l")                                        # a wing
    R(c, 6, 24, 12, 26, "stone"); R(c, 3, 22, 6, 23, "stone"); R(c, 14, 28, 16, 29, "stone_d"); R(c, 26, 28, 28, 29, "stone_d")


@item("guildmaster_statue", "會長雕像", C8, 4, 26, 46, note="會長本人的雕像（金色）")
def _(c, f):
    plinth(c, 4, 21, 36, 45)
    circle(c, 12.5, 8, 5, "gold"); R(c, 8, 3, 17, 5, "gold_l"); c.cells([(9, 2), (12, 1), (16, 2)], "gold_l")   # a crown
    R(c, 8, 14, 17, 34, "gold"); R(c, 17, 14, 17, 34, "gold_d"); R(c, 6, 15, 7, 25, "gold_d"); R(c, 18, 15, 19, 25, "gold_d")
    R(c, 11, 18, 14, 22, "gold_l"); R(c, 8, 39, 17, 41, "red")


@item("marble_bust", "大理石半身像", C8, 1, 16, 26)
def _(c, f):
    R(c, 3, 18, 12, 25, "marble_d"); R(c, 3, 18, 12, 18, "marble")
    circle(c, 7.5, 7, 4.5, "marble"); R(c, 4, 12, 11, 17, "marble"); R(c, 11, 12, 11, 17, "marble_d")
    c.cells([(6, 6), (9, 6)], "marble_x"); c.put(8, 8, "marble_x"); R(c, 4, 2, 11, 3, "marble_x")


@item("trophy_cup", "獎盃", C8, 1, 14, 18)
def _(c, f):
    R(c, 3, 2, 10, 8, "gold"); R(c, 3, 2, 10, 2, "gold_l"); R(c, 10, 3, 10, 8, "gold_d")
    R(c, 1, 3, 2, 6, "gold_d"); R(c, 11, 3, 12, 6, "gold_d"); R(c, 5, 9, 8, 11, "gold"); R(c, 6, 12, 7, 13, "gold_d")
    R(c, 3, 14, 10, 17, "wood"); R(c, 3, 14, 10, 14, "wood_l"); c.put(5, 4, "gold_l")


@item("monster_skull", "魔獸頭骨", C8, 2, 26, 20, note="大世界打倒的第一隻魔獸")
def _(c, f):
    R(c, 3, 15, 22, 19, "wood"); R(c, 3, 15, 22, 15, "wood_l")
    circle(c, 12.5, 8, 8, "marble", 6); R(c, 7, 11, 18, 14, "marble"); R(c, 6, 3, 8, 4, "marble_d")
    c.cells([(3, 2), (4, 1), (2, 3), (21, 2), (22, 1), (23, 3), (5, 3), (20, 3)], "cloth_d")
    R(c, 8, 7, 10, 9, "black"); R(c, 15, 7, 17, 9, "black"); c.cells([(9, 12), (11, 13), (13, 12), (15, 13)], "marble_x")


@item("golden_egg", "金蛋", C8, 1, 14, 18, 2, 2)
def _(c, f):
    R(c, 2, 13, 11, 17, "red"); R(c, 2, 13, 11, 13, "red_l")
    circle(c, 6.5, 7, 4.5, "gold", 6); circle(c, 7.5, 8, 3, "gold_d", 4.5); c.put(5, 4, "gold_l")
    if f:
        c.cells([(1, 2), (12, 4), (11, 10)], "gold_l"); c.put(5, 3, "white")


@item("obelisk", "符文方尖碑", C8, 2, 18, 38, 2, 2)
def _(c, f):
    plinth(c, 3, 14, 31, 37)
    for y in range(3, 31):
        w = 3 + (y - 3) // 9
        R(c, 8 - w, y, 9 + w, y, "stone"); c.put(9 + w, y, "stone_d")
    R(c, 7, 0, 10, 2, "stone_l")
    for y in (8, 14, 20, 26):
        c.put(8, y, "rune" if f else "rune_d"); c.put(9, y + 2, "rune" if f else "rune_d")


@item("founder_plaque", "創會紀念碑", C8, 2, 26, 26)
def _(c, f):
    R(c, 2, 4, 23, 24, "stone"); R(c, 4, 2, 21, 4, "stone"); R(c, 2, 4, 23, 4, "stone_l"); R(c, 23, 5, 23, 24, "stone_d")
    R(c, 5, 7, 20, 20, "stone_d")
    for y in (9, 12, 15, 18):
        R(c, 7, y, 18 - (y % 5), y, "gold")
    R(c, 0, 24, 25, 25, "stone_d")


@item("crystal_cluster", "水晶簇", C8, 1, 16, 18, 2, 2)
def _(c, f):
    R(c, 1, 14, 14, 17, "stone_d"); R(c, 1, 14, 14, 14, "stone")
    for x, top, w in ((3, 6, 2), (6, 1, 3), (10, 4, 2), (12, 9, 1)):
        R(c, x, top, x + w, 13, "purple_l" if f else "purple"); c.put(x + w // 2, top - 1, "purple_l"); R(c, x + w, top, x + w, 13, "purple_d")
    c.put(7, 4, "white")


@item("knight_armor", "騎士全身甲", C8, 2, 22, 40)
def _(c, f):
    R(c, 4, 36, 17, 39, "wood_d")
    R(c, 7, 1, 14, 9, "iron_l"); R(c, 8, 5, 13, 5, "black"); R(c, 10, 0, 11, 0, "gold"); R(c, 14, 2, 14, 9, "iron")
    R(c, 3, 10, 18, 13, "iron_l"); R(c, 5, 14, 16, 24, "iron_l"); R(c, 16, 14, 16, 24, "iron"); R(c, 10, 15, 11, 23, "gold")
    R(c, 2, 14, 4, 24, "iron"); R(c, 17, 14, 19, 24, "iron")
    R(c, 6, 25, 9, 35, "iron_l"); R(c, 12, 25, 15, 35, "iron"); R(c, 5, 34, 9, 35, "iron_d"); R(c, 12, 34, 16, 35, "iron_d")


@item("sword_in_stone", "石中劍", C8, 2, 22, 26)
def _(c, f):
    circle(c, 10.5, 20, 10, "stone_d", 5); circle(c, 10.5, 19, 9, "stone", 4); c.put(6, 17, "stone_l")
    R(c, 10, 6, 11, 17, "iron_l"); R(c, 11, 7, 11, 17, "iron"); R(c, 6, 4, 15, 5, "gold"); R(c, 10, 0, 11, 3, "brown"); c.put(10, 0, "gold")


# ===========================================================================================================================
# 休閒娛樂
# ===========================================================================================================================
C9 = "休閒娛樂"


@item("game_console", "遊戲機", C9, 1, 18, 12, note="原汁原味的現代彩蛋")
def _(c, f):
    box(c, 2, 2, 15, 7, "white", "white", "mac_d"); R(c, 3, 3, 9, 3, "mac_d"); c.put(13, 4, "rune"); c.put(13, 6, "red")
    R(c, 2, 9, 7, 11, "black"); c.put(3, 10, "iron_l"); c.put(6, 10, "red"); R(c, 8, 8, 9, 8, "black"); R(c, 10, 7, 11, 7, "black")


@item("beanbag", "懶骨頭", C9, 2, 24, 16, seat=True, note="原汁原味的現代彩蛋")
def _(c, f):
    circle(c, 11.5, 8, 11, "orange", 7); circle(c, 11.5, 10, 9, (240, 150, 60) and "orange", 5)
    R(c, 2, 12, 21, 12, "f2"); c.cells([(6, 5), (15, 4), (10, 7)], "f1"); R(c, 4, 14, 19, 15, "f3")


@item("chess_table", "西洋棋桌", C9, 2, 24, 22)
def _(c, f):
    table(c, 2, 8, 21, 21, depth=4)
    for y in range(8, 12):
        for x in range(6, 18):
            if (x + y) % 2:
                c.put(x, y, "dark_d")
    for x, y, k in ((7, 6), (9, 5), (15, 6), (12, 7)) and ((7, 6, "white"), (9, 5, "white"), (15, 6, "black"), (12, 7, "black")):
        R(c, x, y, x, y + 2, k); c.put(x, y - 1, k)


@item("dartboard", "飛鏢靶", C9, 1, 16, 18, wall=True)
def _(c, f):
    circle(c, 7.5, 8, 7, "black"); circle(c, 7.5, 8, 5.5, "cloth"); circle(c, 7.5, 8, 4, "red"); circle(c, 7.5, 8, 2.5, "cloth")
    circle(c, 7.5, 8, 1, "green"); R(c, 10, 5, 13, 5, "wood"); c.put(13, 4, "red"); c.put(9, 5, "iron_l")


@item("lute_stand", "魯特琴架", C9, 1, 16, 26)
def _(c, f):
    R(c, 3, 20, 12, 25, "wood_d"); R(c, 3, 20, 12, 20, "wood")
    circle(c, 7, 15, 4.5, "wood_l", 4); circle(c, 7, 15, 1.2, "black"); R(c, 6, 2, 7, 11, "dark"); R(c, 5, 0, 8, 2, "dark_d")
    for x in (6, 7):
        R(c, x, 3, x, 16, "cloth")


@item("sofa", "雙人沙發", C9, 4, 40, 24, seat=True)
def _(c, f):
    h = 24
    sy = h - 1 - SEAT_UP
    R(c, 6, 2, 33, sy, "red"); R(c, 6, 2, 33, 2, "red_l"); R(c, 19, 4, 20, sy - 2, "red_d")
    for x0 in (1, 34):
        R(c, x0, 9, x0 + 4, h - 2, "red"); R(c, x0, 9, x0 + 4, 9, "red_l"); R(c, x0 + (4 if x0 < 20 else 0), 10, x0 + (4 if x0 < 20 else 0), h - 2, "red_d")
    R(c, 6, sy, 33, sy, "red_l"); R(c, 6, sy + 1, 33, h - 2, "red"); R(c, 1, h - 1, 38, h - 1, "wood_d")


@item("armchair", "扶手椅", C9, 2, 26, 24, seat=True)
def _(c, f):
    h = 24
    sy = h - 1 - SEAT_UP
    R(c, 5, 2, 20, sy, "green"); R(c, 6, 1, 19, 1, "green"); R(c, 6, 2, 19, 2, "green_l")
    c.cells([(9, 6), (16, 6), (12, 10)], "green_d")
    for x0 in (1, 21):
        R(c, x0, 9, x0 + 3, h - 2, "green"); R(c, x0, 9, x0 + 3, 9, "green_l")
    R(c, 5, sy, 20, sy, "green_l"); R(c, 5, sy + 1, 20, h - 2, "green"); R(c, 1, h - 1, 24, h - 1, "wood_d")


@item("card_table", "撲克牌桌", C9, 2, 28, 22)
def _(c, f):
    table(c, 2, 8, 25, 21, depth=4); R(c, 4, 8, 23, 11, "green")
    for x, y, k in ((7, 9, "paper"), (11, 8, "paper"), (17, 9, "paper")):
        R(c, x, y, x + 2, y + 2, k); c.put(x + 1, y + 1, "red")
    R(c, 20, 9, 21, 10, "gold"); R(c, 20, 8, 21, 8, "gold_l")


@item("illusion_crystal", "幻象水晶投影機", C9, 2, 24, 30, 3, 3, note="投影機：水晶投出幻象")
def _(c, f):
    R(c, 8, 24, 15, 29, "wood"); R(c, 8, 24, 15, 24, "wood_l"); crystal(c, 11.5, 20, 3.5, 1)
    for y in range(3, 17):                                                # a cone of pale light
        w = (17 - y) // 2 + 2
        for x in range(12 - w, 12 + w):
            if (x + y) % 2 == 0:
                c.put(x, y, "glass")
    shape = [  # a castle, a dragon, a star
        [(7, 8, 16, 13), (7, 6, 8, 7), (11, 5, 12, 7), (15, 6, 16, 7)],
        [(8, 8, 15, 10), (14, 5, 16, 8), (6, 6, 9, 8), (16, 5, 17, 6)],
        [(11, 3, 12, 13), (7, 7, 16, 8), (9, 5, 14, 11)],
    ][f]
    for x0, y0, x1, y1 in shape:
        R(c, x0, y0, x1, y1, "glow")
    if f == 0:
        R(c, 11, 10, 12, 13, "glass")

def _(c, f):
    R(c, 7, 24, 14, 29, "wood"); R(c, 7, 24, 14, 24, "wood_l"); crystal(c, 10.5, 20, 3.5, 1)
    shapes = [[(10, 4), (11, 4), (9, 5), (12, 5), (8, 6), (13, 6), (8, 7), (13, 7), (9, 8), (12, 8), (10, 9), (11, 9)],
              [(6, 6), (7, 5), (8, 6), (9, 5), (10, 6), (11, 5), (12, 6), (13, 5), (14, 6), (15, 5)],
              [(10, 3), (9, 5), (11, 5), (10, 7), (8, 9), (12, 9), (10, 11)]][f]
    for y in range(4, 16):
        w = (y - 2) // 3
        for x in range(10 - w, 11 + w + 1):
            if (x + y) % 3 == 0:
                c.put(x, y + 1, "glass")
    c.cells(shapes, "glow")


@item("pillow_pile", "抱枕堆", C9, 1, 22, 12, seat=True)
def _(c, f):
    circle(c, 6, 7, 5, "pink", 4); circle(c, 15, 7, 5, "purple_l", 4); circle(c, 10.5, 5, 4, "yellow", 3)
    c.cells([(6, 7), (15, 7), (10, 5)], "white"); R(c, 1, 10, 20, 11, "purple")


@item("music_box", "音樂盒", C9, 1, 16, 18, 2, 2)
def _(c, f):
    box(c, 2, 10, 13, 17, "wood", "wood_l", "wood_d"); R(c, 2, 6, 13, 9, "wood_l"); R(c, 2, 9, 13, 9, "gold")
    R(c, 7, 12, 8, 14, "gold"); R(c, 14, 13, 15, 13, "gold")
    nx = 4 if f == 0 else 10
    R(c, nx, 1, nx, 4, "ink"); c.put(nx - 1, 4, "ink"); c.put(nx + 1, 1, "ink")


@item("rocking_horse", "搖搖木馬", C9, 2, 26, 22, 2, 3)
def _(c, f):
    tilt = 1 if f else 0
    for x in range(2, 24):
        y = 19 + int(((x - 12.5) / 11) ** 2 * 2.5)
        c.put(x, y, "red"); c.put(x, y + 1, "red_d")
    R(c, 6, 13 - tilt, 7, 18, "wood_d"); R(c, 18, 13 + tilt, 19, 18, "wood_d")
    R(c, 5, 9, 19, 13, "wood"); R(c, 5, 9, 19, 9, "wood_l"); R(c, 17, 3, 22, 9, "wood"); R(c, 22, 6, 24, 8, "wood")
    c.put(20, 5, "black"); R(c, 16, 2, 18, 8, "red"); R(c, 2, 9, 5, 10, "red")


# ===========================================================================================================================
# 廚房飲料
# ===========================================================================================================================
C10 = "廚房飲料"


@item("water_cooler", "水元素飲水機", C10, 1, 16, 24, 3, 3, note="飲水機：桶子裡泡著一隻小水精靈")
def _(c, f):
    bob = 1 if f == 1 else 0
    circle(c, 7.5, 6 + bob, 5, "water"); circle(c, 8, 7 + bob, 3.5, "water_d"); circle(c, 7.5, 6 + bob, 3.6, "water")
    c.put(5, 3 + bob, "water_l"); c.put(6, 2 + bob, "water_l")
    if f == 2:
        c.cells([(5, 6), (6, 6), (9, 6), (10, 6)], "black")
    else:
        c.cells([(6, 6 + bob), (9, 6 + bob)], "black")
    c.cells([(7, 8 + bob), (8, 8 + bob)], "black"); c.cells([(4, 8 + bob), (11, 8 + bob)], "pink")
    R(c, 2, 11, 13, 13, "stone"); R(c, 2, 11, 13, 11, "stone_l"); R(c, 13, 12, 14, 12, "gold"); c.put(14, 13, "gold")
    c.put(14, 15, "water_l") if f == 0 else None
    R(c, 3, 14, 12, 23, "wood"); R(c, 3, 18, 12, 18, "wood_d")


@item("portal_coffee", "傳送門咖啡機", C10, 2, 22, 28, 4, 6, note="咖啡機：從小傳送門倒出咖啡")
def _(c, f):
    box(c, 1, 2, 20, 27, "iron", "iron_l", "iron_d"); R(c, 3, 25, 18, 26, "iron_d")
    circle(c, 10.5, 9, 6, "gold_d"); circle(c, 10.5, 9, 5, "purple_d")
    for i in range(6):
        a = math.radians(f * 30 + i * 60)
        c.put(10.5 + 3.4 * math.cos(a), 9 + 3.4 * math.sin(a), "purple_l" if i % 2 else "glow")
    circle(c, 10.5, 9, 1.5, "purple")
    R(c, 10, 14, 11, 19, "brown") if f % 2 == 0 else R(c, 10, 15, 10, 19, "brown")
    R(c, 7, 19, 13, 24, "white"); R(c, 14, 20, 15, 22, "white"); R(c, 8, 19, 12, 19, "brown"); R(c, 13, 20, 13, 24, "cloth_d")
    c.put(3, 4, "rune"); c.put(18, 4, "f2"); c.put(5 + f % 2, 0, "cloth_d"); c.put(6, 1, "cloth_d")

def _(c, f):
    box(c, 2, 12, 19, 27, "iron", "iron_l", "iron_d"); R(c, 6, 21, 15, 22, "iron_d")
    circle(c, 10.5, 6, 6, "purple_d", 5)
    for i in range(4):
        a = math.radians(f * 90 + i * 90)
        c.put(int(10.5 + 3.5 * math.cos(a)), int(6 + 3 * math.sin(a)), "purple_l")
    circle(c, 10.5, 6, 2, "purple"); R(c, 10, 10, 11, 18, "brown") if f % 2 == 0 else R(c, 10, 11, 10, 18, "brown")
    R(c, 8, 18, 13, 21, "white"); R(c, 13, 19, 14, 20, "white"); R(c, 9, 18, 12, 18, "brown")
    c.put(4, 15, "rune"); c.put(17, 15, "f2")


@item("ale_barrel", "麥酒桶", C10, 2, 26, 22)
def _(c, f):
    R(c, 2, 19, 23, 21, "wood_d")
    circle(c, 12.5, 10, 10, "wood", 8)
    for x in (6, 12, 18):
        R(c, x, 3, x, 17, "wood_d")
    R(c, 3, 6, 22, 6, "iron"); R(c, 3, 14, 22, 14, "iron"); circle(c, 12.5, 10, 2.5, "wood_l")
    R(c, 12, 10, 13, 13, "gold"); R(c, 11, 13, 14, 13, "gold_d"); c.put(13, 15, "yellow")


@item("kitchen_counter", "廚房流理台", C10, 4, 48, 26)
def _(c, f):
    R(c, 1, 8, 46, 11, "stone_l"); R(c, 1, 11, 46, 25, "wood"); R(c, 1, 11, 46, 12, "wood_d")
    for x in (2, 17, 32):
        R(c, x + 1, 14, x + 13, 23, "wood_l"); R(c, x + 6, 18, x + 8, 18, "gold")
    R(c, 6, 4, 12, 8, "iron"); R(c, 7, 2, 11, 3, "iron_l"); R(c, 22, 6, 28, 8, "wood_d"); R(c, 24, 5, 27, 5, "red")
    R(c, 36, 3, 37, 8, "green"); R(c, 40, 5, 42, 8, "paper"); R(c, 1, 25, 46, 25, "wood_d")


@item("cauldron", "大鍋", C10, 2, 24, 22, 3, 4)
def _(c, f):
    circle(c, 11.5, 13, 10, "iron_d", 7); circle(c, 11.5, 12, 9.5, "iron", 6); R(c, 2, 7, 21, 8, "iron_l")
    R(c, 3, 8, 20, 9, "green"); R(c, 4, 19, 6, 21, "iron_d"); R(c, 17, 19, 19, 21, "iron_d")
    for i, x in enumerate((6, 11, 16)):
        if (i + f) % 3:
            circle(c, x, 7 - (i + f) % 3, 1.2, "green_l")
    flame(c, 8, 21, 2, f, 1); flame(c, 15, 21, 2, f + 1, 1)


@item("bread_basket", "麵包籃", C10, 1, 16, 12)
def _(c, f):
    R(c, 1, 6, 14, 11, "straw"); R(c, 1, 6, 14, 6, "straw_d")
    for x in range(2, 14, 3):
        R(c, x, 7, x, 10, "straw_d")
    circle(c, 5, 4, 3, "orange", 2); circle(c, 10.5, 4, 3.5, "wood_l", 2.4); c.cells([(4, 3), (10, 3), (12, 4)], "f1")


@item("fruit_bowl", "水果盤", C10, 1, 16, 12)
def _(c, f):
    R(c, 1, 7, 14, 9, "cloth"); R(c, 3, 10, 12, 11, "cloth_d")
    circle(c, 5, 5, 2.5, "red"); circle(c, 10, 5, 2.5, "green_l"); circle(c, 7.5, 3, 2.5, "orange"); c.put(7, 0, "green")
    c.cells([(4, 4), (9, 4), (6, 2)], "white")


@item("tea_set", "茶具組", C10, 1, 18, 12)
def _(c, f):
    R(c, 0, 9, 17, 11, "wood_l")
    circle(c, 6, 5, 4, "white", 3); R(c, 10, 4, 11, 5, "white"); R(c, 1, 3, 2, 6, "white"); R(c, 5, 0, 7, 1, "blue")
    c.cells([(4, 5), (6, 6), (8, 5)], "blue"); R(c, 13, 6, 16, 8, "white"); R(c, 13, 6, 16, 6, "brown")


@item("dining_table", "長餐桌", C10, 4, 48, 26)
def _(c, f):
    table(c, 1, 8, 46, 25, depth=5); R(c, 3, 9, 44, 11, "cloth"); R(c, 3, 12, 44, 12, "cloth_d")
    for x in (8, 18, 28, 38):
        circle(c, x, 10, 2, "white", 1.2)
    R(c, 22, 4, 25, 9, "gold"); flame(c, 23, 3, 3, f, 0); R(c, 12, 7, 14, 9, "red"); R(c, 33, 7, 35, 9, "orange")


@item("wine_rack", "酒架", C10, 2, 26, 30)
def _(c, f):
    box(c, 1, 1, 24, 29, "wood", "wood_l", "wood_d")
    for row in range(5):
        for col in range(4):
            x, y = 3 + col * 5, 3 + row * 5
            R(c, x, y, x + 3, y + 3, "wood_x")
            circle(c, x + 1.5, y + 1.5, 1.3, ["red_d", "green_d", "purple_d", "red_d"][(row + col) % 4])


@item("spice_shelf", "香料架", C10, 1, 18, 18, wall=True)
def _(c, f):
    R(c, 0, 8, 17, 9, "wood"); R(c, 0, 16, 17, 17, "wood"); R(c, 1, 8, 1, 17, "wood_d"); R(c, 16, 8, 16, 17, "wood_d")
    for i, x in enumerate(range(2, 15, 3)):
        R(c, x, 4, x + 1, 7, ["red", "yellow", "green", "brown", "orange"][i]); R(c, x, 3, x + 1, 3, "wood_d")
        R(c, x, 12, x + 1, 15, ["glass", "pink", "teal", "straw", "purple_l"][i]); R(c, x, 11, x + 1, 11, "cloth")


@item("snack_cart", "點心推車", C10, 2, 26, 22)
def _(c, f):
    R(c, 2, 8, 23, 10, "wood_l"); R(c, 2, 15, 23, 16, "wood"); R(c, 3, 10, 3, 18, "iron"); R(c, 22, 10, 22, 18, "iron")
    circle(c, 4, 19, 2, "black"); circle(c, 21, 19, 2, "black"); R(c, 22, 4, 25, 5, "iron"); R(c, 23, 5, 23, 8, "iron")
    circle(c, 7, 6, 2, "pink"); circle(c, 12, 6, 2.5, "wood_l", 2); R(c, 16, 4, 20, 7, "white"); R(c, 16, 4, 20, 4, "red")
    R(c, 6, 13, 10, 14, "yellow"); R(c, 13, 12, 18, 14, "orange")


@item("stone_oven", "石窯烤爐", C10, 4, 34, 34, 3, 6)
def _(c, f):
    circle(c, 16.5, 16, 15, "stone_d", 14); circle(c, 16.5, 15, 14, "stone", 13)
    R(c, 2, 16, 31, 33, "stone"); R(c, 31, 17, 31, 33, "stone_d")
    for r, y in enumerate(range(6, 33, 5)):
        for x in range(3 + (r % 2) * 3, 31, 6):
            c.put(x, y, "stone_d")
    circle(c, 16.5, 22, 7, "black", 6); R(c, 9, 22, 24, 30, "black")
    for x, h in ((12, 4), (16, 6), (20, 5)):
        flame(c, x, 29, h + (f % 2), f + x, 1)
    R(c, 3, 31, 30, 33, "stone_x"); R(c, 13, 0, 18, 3, "stone_x")


# ===========================================================================================================================
# 門窗與隔間
# ===========================================================================================================================
C11 = "門窗與隔間"


@item("wooden_door", "木門", C11, 2, 26, 40, wall=True)
def _(c, f):
    R(c, 1, 4, 24, 39, "stone"); circle(c, 12.5, 9, 11.5, "stone", 8); circle(c, 12.5, 10, 9.5, "wood", 7)
    R(c, 3, 10, 22, 39, "wood")
    for x in (7, 12, 17):
        R(c, x, 4, x, 39, "wood_d")
    R(c, 3, 16, 22, 17, "iron"); R(c, 3, 30, 22, 31, "iron"); circle(c, 18, 24, 1.2, "gold")


@item("arched_window", "拱窗", C11, 2, 24, 32, wall=True)
def _(c, f):
    circle(c, 11.5, 11, 11, "stone_l", 10); R(c, 0, 11, 23, 31, "stone_l")
    circle(c, 11.5, 11, 9, "blue_l", 8); R(c, 2, 11, 21, 28, "blue_l"); R(c, 11, 3, 12, 28, "stone"); R(c, 2, 16, 21, 16, "stone")
    c.cells([(5, 8), (6, 9), (16, 20), (17, 21)], "white"); R(c, 0, 29, 23, 31, "stone")


@item("stained_glass", "彩繪玻璃窗", C11, 2, 24, 32, wall=True)
def _(c, f):
    circle(c, 11.5, 11, 11, "stone", 10); R(c, 0, 11, 23, 31, "stone")
    circle(c, 11.5, 11, 9, "iron_d", 8); R(c, 2, 11, 21, 29, "iron_d")
    cols = ["red", "blue", "gold", "green", "purple_l", "blue_l"]
    for y in range(3, 29):
        for x in range(2, 22):
            if c.px[y][x] == "iron_d" and not (x % 5 == 1 or y % 6 == 2):
                c.put(x, y, cols[(x // 5 + y // 6) % 6])
    circle(c, 11.5, 13, 3, "gold"); c.put(11, 13, "white")


@item("folding_screen", "屏風", C11, 2, 32, 30)
def _(c, f):
    for i, x0 in enumerate((1, 11, 21)):
        y_off = 0 if i % 2 == 0 else 2
        R(c, x0, 2 + y_off, x0 + 9, 27 + y_off, "wood_d"); R(c, x0 + 1, 3 + y_off, x0 + 8, 26 + y_off, "cloth")
        R(c, x0 + 2, 8 + y_off, x0 + 7, 8 + y_off, "green"); c.put(x0 + 4, 6 + y_off, "pink"); c.put(x0 + 6, 12 + y_off, "pink")
        R(c, x0 + 1, 20 + y_off, x0 + 8, 21 + y_off, "blue_l")


@item("low_partition", "矮隔板", C11, 2, 32, 20)
def _(c, f):
    R(c, 1, 3, 30, 17, "wood"); R(c, 0, 2, 31, 3, "wood_l"); R(c, 1, 17, 30, 19, "wood_d")
    for x in (8, 16, 24):
        R(c, x, 4, x, 16, "wood_d")
    R(c, 3, 6, 6, 10, "paper"); R(c, 18, 7, 22, 11, "pink"); c.put(4, 6, "red"); c.put(20, 7, "red")


@item("bead_curtain", "珠簾", C11, 1, 18, 34, 2, 2, wall=True)
def _(c, f):
    R(c, 0, 0, 17, 1, "wood"); R(c, 0, 0, 17, 0, "wood_l")
    for i, x in enumerate(range(2, 17, 3)):
        sway = 1 if (f and i % 2) else 0
        for y in range(2, 32):
            xx = x + (sway if y > 18 else 0)
            c.put(xx, y, "brown" if y % 3 else ["red", "gold", "teal"][(i + y // 3) % 3])

def _(c, f):
    R(c, 0, 0, 17, 1, "wood")
    for i, x in enumerate(range(1, 17, 2)):
        sway = (1 if (f and i % 2) else 0)
        for y in range(2, 32):
            if y % 2 == 0:
                c.put(x + (sway if y > 16 else 0), y, ["red", "gold", "teal", "purple_l"][(i + y // 2) % 4])


@item("portal_door", "傳送門", C11, 4, 34, 42, 4, 6, note="走進去會到據點的另一頭（之後再做）")
def _(c, f):
    circle(c, 16.5, 16, 15.5, "stone_d", 15); R(c, 1, 16, 32, 41, "stone_d")
    circle(c, 16.5, 16, 14, "stone", 14); R(c, 3, 16, 30, 40, "stone")
    circle(c, 16.5, 17, 11, "purple_d", 11); R(c, 6, 17, 27, 38, "purple_d")
    for i in range(18):
        a = math.radians(f * 20 + i * 40)
        r = 2 + i * 0.5
        c.put(int(16.5 + r * math.cos(a)), int(24 + r * 1.1 * math.sin(a)), "purple_l" if i % 3 else "glow")
    for y in (4, 10, 22, 34):
        c.put(4, y, "rune"); c.put(29, y, "rune")
    R(c, 0, 40, 33, 41, "stone_x")


@item("iron_gate", "鐵柵門", C11, 2, 32, 32)
def _(c, f):
    R(c, 0, 0, 31, 2, "iron"); R(c, 0, 29, 31, 31, "iron_d")
    for x in range(2, 31, 4):
        R(c, x, 0, x, 29, "iron_l"); c.put(x, 0, "iron_d"); c.put(x, -1, None)
    R(c, 0, 14, 31, 15, "iron"); R(c, 15, 12, 16, 17, "gold")


@item("rope_barrier", "紅絨繩欄杆", C11, 2, 34, 20)
def _(c, f):
    for x in (2, 16, 30):
        R(c, x, 4, x + 1, 17, "gold"); R(c, x - 1, 17, x + 2, 19, "gold_d"); R(c, x - 1, 2, x + 2, 3, "gold_l")
    for x0 in (3, 17):
        for i in range(13):
            c.put(x0 + i, 6 + int(3 * math.sin(math.pi * i / 12)), "red"); c.put(x0 + i, 7 + int(3 * math.sin(math.pi * i / 12)), "red_d")


@item("stone_arch", "石拱門", C11, 4, 42, 42)
def _(c, f):
    R(c, 1, 12, 7, 41, "stone"); R(c, 34, 12, 40, 41, "stone"); circle(c, 20.5, 14, 20, "stone", 14)
    circle(c, 20.5, 15, 13, None, 13); R(c, 8, 15, 33, 41, None)
    for x0 in (1, 34):
        for y in range(16, 41, 5):
            R(c, x0, y, x0 + 6, y, "stone_d")
    R(c, 19, 0, 22, 3, "stone_l"); c.put(20, 1, "gold"); R(c, 7, 12, 7, 41, "stone_d"); R(c, 40, 12, 40, 41, "stone_d")
    R(c, 0, 40, 8, 41, "stone_x"); R(c, 33, 40, 41, 41, "stone_x")


@item("round_window", "圓窗", C11, 1, 20, 20, wall=True)
def _(c, f):
    circle(c, 9.5, 9.5, 9.5, "wood"); circle(c, 9.5, 9.5, 7.5, "blue_l"); R(c, 9, 2, 10, 17, "wood"); R(c, 2, 9, 17, 10, "wood")
    c.cells([(5, 5), (6, 6), (13, 13)], "white")


@item("curtains", "窗簾", C11, 2, 34, 34, wall=True)
def _(c, f):
    R(c, 0, 0, 33, 1, "gold_d")
    R(c, 7, 2, 26, 30, "blue_l"); R(c, 16, 2, 17, 30, "stone_l"); R(c, 7, 15, 26, 15, "stone_l")
    for x0, x1 in ((1, 9), (24, 32)):
        R(c, x0, 2, x1, 33, "red")
        for x in range(x0 + 1, x1, 2):
            R(c, x, 2, x, 33, "red_d")
    R(c, 1, 18, 9, 19, "gold"); R(c, 24, 18, 32, 19, "gold")


# ===========================================================================================================================
# 戶外
# ===========================================================================================================================
C12 = "戶外"


@item("fountain", "噴泉", C12, 4, 42, 36, 3, 4)
def _(c, f):
    circle(c, 20.5, 26, 20, "stone_d", 9); circle(c, 20.5, 25, 19, "stone", 8); circle(c, 20.5, 25, 16, "water", 6)
    circle(c, 20.5, 25, 14, "water_d", 4.5); circle(c, 20.5, 25, 12, "water", 3.5)
    R(c, 19, 10, 22, 24, "stone"); R(c, 22, 10, 22, 24, "stone_d"); circle(c, 20.5, 10, 6, "stone", 2); circle(c, 20.5, 9.5, 4.5, "water", 1.3)
    for i, (dx, top) in enumerate(((-4, 3), (0, 0), (4, 3))):
        for y in range(top + (f + i) % 2, 9):
            c.put(20 + dx + (1 if dx > 0 and y > 5 else (-1 if dx < 0 and y > 5 else 0)), y, "water_l")
    for x in range(9 + f * 3, 33, 9):
        c.put(x, 26, "water_l")


@item("garden_bench", "庭院長椅", C12, 2, 32, 20, seat=True)
def _(c, f):
    h = 20
    sy = h - 1 - SEAT_UP
    for y in (2, 5, 8):
        R(c, 2, y, 29, y + 1, "wood_l" if y == 2 else "wood")
    R(c, 1, 2, 2, h - 1, "iron"); R(c, 29, 2, 30, h - 1, "iron")
    R(c, 0, sy, 31, sy, "wood_l"); R(c, 0, sy + 1, 31, sy + 1, "wood"); R(c, 1, 11, 30, 12, "iron_d")


@item("lamp_post", "庭院燈柱", C12, 1, 14, 42, 2, 2)
def _(c, f):
    R(c, 6, 12, 7, 38, "iron"); R(c, 4, 38, 9, 41, "iron_d"); R(c, 3, 2, 10, 3, "iron"); R(c, 5, 0, 8, 1, "iron")
    R(c, 3, 4, 10, 10, "f1" if f else "f2"); R(c, 3, 4, 3, 10, "iron"); R(c, 10, 4, 10, 10, "iron"); R(c, 3, 11, 10, 11, "iron")
    R(c, 5, 6, 8, 8, "f4")


@item("well", "水井", C12, 2, 28, 34)
def _(c, f):
    R(c, 3, 2, 24, 4, "red"); R(c, 1, 4, 26, 6, "red_d"); R(c, 4, 6, 5, 22, "wood_d"); R(c, 22, 6, 23, 22, "wood_d")
    R(c, 6, 9, 21, 9, "wood"); R(c, 13, 9, 14, 14, "brown"); R(c, 11, 14, 16, 18, "wood")
    circle(c, 13.5, 24, 12, "stone_d", 4); R(c, 2, 24, 25, 33, "stone"); circle(c, 13.5, 23, 11, "stone_l", 3); circle(c, 13.5, 23, 9, "water_d", 2)
    for r, y in enumerate(range(27, 33, 3)):
        for x in range(3 + (r % 2) * 3, 25, 6):
            c.put(x, y, "stone_d")


@item("courtyard_tree", "大樹", C12, 4, 42, 50)
def _(c, f):
    R(c, 18, 28, 23, 47, "wood_d"); R(c, 16, 46, 25, 49, "wood_x"); c.put(17, 33, "wood_x"); R(c, 22, 30, 23, 44, "wood_x")
    blob(c, 20.5, 16, 16, ry=13); blob(c, 9, 22, 8, ry=6); blob(c, 32, 22, 8, ry=6); blob(c, 20, 8, 10, ry=7)
    for x, y in ((14, 14), (26, 18), (19, 24), (30, 11)):
        c.put(x, y, "red")


@item("flower_bed", "花圃", C12, 2, 34, 16)
def _(c, f):
    R(c, 1, 6, 32, 15, "wood"); R(c, 1, 6, 32, 6, "wood_l"); R(c, 3, 7, 30, 13, "brown")
    for i, x in enumerate(range(4, 30, 3)):
        k = ["red", "yellow", "pink", "purple_l", "white"][i % 5]
        y = 4 + i % 2
        R(c, x, y + 2, x, 10, "green_d"); c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], k); c.put(x, y, "yellow")


@item("hedge", "樹籬", C12, 2, 34, 22)
def _(c, f):
    R(c, 1, 4, 32, 19, "green_d"); R(c, 1, 3, 32, 16, "green")
    for x in range(2, 32, 4):
        circle(c, x, 4, 2, "green")
        c.put(x, 3, "green_l"); c.put(x + 2, 9, "green_l"); c.put(x + 1, 13, "green_d")
    R(c, 1, 20, 32, 21, "brown")


@item("stone_path", "石板路", C12, 1, 16, 16, flat=True)
def _(c, f):
    for x0, y0, w, h in ((1, 1, 6, 5), (9, 0, 6, 6), (0, 8, 7, 7), (9, 8, 6, 7)):
        R(c, x0, y0, x0 + w, y0 + h, "stone"); R(c, x0, y0, x0 + w, y0, "stone_l"); R(c, x0 + w, y0 + 1, x0 + w, y0 + h, "stone_d")


@item("pond", "小池塘", C12, 4, 42, 30, 3, 3, flat=True)
def _(c, f):
    circle(c, 20.5, 15, 20, "stone_d", 14); circle(c, 20.5, 15, 18, "water", 12.5); circle(c, 21.5, 16.5, 15, "water_d", 9)
    circle(c, 20.5, 14.5, 13, "water", 8)
    for x, y in ((12, 10), (28, 18), (19, 21)):
        R(c, x + (f if x < 20 else -f), y, x + 3 + (f if x < 20 else -f), y, "water_l")
    circle(c, 9, 18, 3, "green", 2); c.put(9, 17, "pink"); circle(c, 31, 9, 2.5, "green", 1.6)
    c.cells([(4, 6), (5, 5), (36, 22), (37, 21)], "green_l")


@item("training_dummy", "練習木人", C12, 1, 18, 32)
def _(c, f):
    R(c, 8, 12, 9, 29, "wood_d"); R(c, 4, 29, 13, 31, "wood")
    circle(c, 8.5, 6, 4.5, "straw"); R(c, 5, 10, 12, 20, "straw"); R(c, 1, 12, 16, 13, "wood_d")
    c.cells([(7, 5), (10, 5)], "black"); R(c, 7, 14, 10, 17, "red"); c.put(8, 15, "white")
    for y in (11, 16, 19):
        R(c, 5, y, 12, y, "straw_d")


@item("picnic_table", "野餐桌", C12, 4, 42, 26)
def _(c, f):
    R(c, 2, 2, 39, 3, "wood"); table(c, 4, 6, 37, 18, depth=4)
    R(c, 6, 7, 35, 9, "red"); [R(c, x, 7, x + 1, 9, "white") for x in range(6, 35, 4)]
    R(c, 2, 20, 39, 21, "wood_l"); R(c, 2, 22, 39, 22, "wood"); R(c, 4, 23, 5, 25, "wood_d"); R(c, 36, 23, 37, 25, "wood_d")
    R(c, 12, 4, 15, 7, "straw"); circle(c, 26, 5, 2, "red")


@item("signpost", "路標", C12, 1, 22, 30)
def _(c, f):
    R(c, 10, 4, 11, 29, "wood_d"); R(c, 8, 28, 13, 29, "wood_x")
    for y, x0, x1, tip in ((5, 2, 18, 20), (12, 3, 19, 1)):
        R(c, x0, y, x1, y + 4, "wood_l"); R(c, x0, y + 4, x1, y + 4, "wood")
        for yy in range(y, y + 5):
            c.put(tip, yy, "wood_l") if abs(yy - (y + 2)) < 2 else None
        R(c, x0 + 2, y + 2, x1 - 3, y + 2, "ink")


@item("hay_bale", "稻草捆", C12, 1, 18, 14)
def _(c, f):
    box(c, 1, 2, 16, 13, "straw", "f1", "straw_d")
    for y in range(4, 13, 2):
        R(c, 2, y, 15, y, "straw_d") if y % 4 == 0 else None
    R(c, 5, 2, 5, 13, "brown"); R(c, 12, 2, 12, 13, "brown"); c.cells([(3, 1), (9, 0), (14, 1)], "straw")


# ===========================================================================================================================
# 會動的
# ===========================================================================================================================
C13 = "會動的"


@item("cat", "貓咪", C13, 1, 18, 16, 4, 3, note="會打呵欠、甩尾巴的貓")
def _(c, f):
    circle(c, 8, 11, 6, "orange", 4); circle(c, 8, 12, 4, "fur_l", 2.5)
    circle(c, 13, 6, 3.5, "orange", 3); c.cells([(11, 2), (11, 3), (15, 2), (15, 3)], "orange"); c.cells([(11, 3), (15, 3)], "pink")
    if f == 2:
        R(c, 12, 6, 14, 6, "black"); R(c, 13, 7, 13, 8, "red")
    else:
        c.cells([(12, 6), (14, 6)], "black"); c.put(13, 7, "pink")
    tail = [[(2, 9), (1, 8), (1, 7)], [(2, 9), (1, 9), (0, 8)], [(2, 9), (1, 8), (1, 7)], [(2, 10), (1, 10), (0, 11)]][f]
    c.cells(tail, "orange"); c.cells([(5, 9), (7, 8)], "f2"); R(c, 4, 15, 12, 15, "orange")


@item("owl_perch", "貓頭鷹棲木", C13, 1, 16, 26, 3, 2)
def _(c, f):
    R(c, 7, 14, 8, 23, "wood_d"); R(c, 3, 23, 12, 25, "wood"); R(c, 2, 13, 13, 14, "wood")
    circle(c, 7.5, 7, 5, "brown", 6); circle(c, 7.5, 9, 3, "fur_l", 3)
    blink = f == 1
    for x in (5, 10):
        circle(c, x, 5, 1.5, "white") if not blink else R(c, x - 1, 5, x + 1, 5, "black")
        c.put(x, 5, "black") if not blink else None
    c.put(7, 7, "orange"); c.put(8, 7, "orange"); c.cells([(3, 1), (12, 1)], "brown")
    if f == 2:
        c.cells([(1, 8), (14, 8)], "brown")


@item("goldfish_bowl", "金魚缸", C13, 1, 16, 16, 3, 3)
def _(c, f):
    circle(c, 7.5, 8, 7, "glass_d", 6.5); circle(c, 7.5, 8.5, 6, "water_l", 5.5); R(c, 3, 2, 12, 3, "glass")
    x = [4, 7, 9][f]
    R(c, x, 8, x + 2, 9, "orange"); c.put(x + (3 if f < 2 else -1), 8 + (f % 2), "orange"); c.put(x + (2 if f < 2 else 0), 8, "black")
    c.put(10, 5 - f % 2, "white"); R(c, 3, 13, 12, 15, "stone")


def spirit(c, f, body, light, dark, extra):
    y = [0, 1, 2, 1][f]
    circle(c, 6.5, 6 + y, 5, body); circle(c, 7.3, 7 + y, 3.5, dark); circle(c, 6.5, 6 + y, 3.8, body)
    c.put(5, 3 + y, light); c.put(4, 4 + y, light)
    c.cells([(5, 6 + y), (8, 6 + y)], "black"); c.cells([(6, 8 + y), (7, 8 + y)], "black"); c.cells([(3, 8 + y), (10, 8 + y)], "pink")
    extra(c, y)
    circle(c, 6.5, 15, 3, "stone_d", 0.6) if False else None


@item("fire_spirit", "火元素精靈", C13, 1, 14, 18, 4, 6)
def _(c, f):
    spirit(c, f, "f2", "f1", "f3", lambda c, y: [c.put(x, y + top, "f1") for x, top in ((4, 0), (6, -1), (8, 0))] and
           c.cells([(5, y - 1 + f % 2), (7, y - 2 + (f + 1) % 2)], "f3"))


@item("water_spirit", "水元素精靈", C13, 1, 14, 18, 4, 4)
def _(c, f):
    spirit(c, f, "water", "water_l", "water_d", lambda c, y: c.cells([(6, y), (7, y - 1)], "water_l"))


@item("wind_spirit", "風元素精靈", C13, 1, 14, 18, 4, 6)
def _(c, f):
    spirit(c, f, "teal_l", "white", "teal", lambda c, y: c.cells([(0 + f % 2, 5 + y), (1 + f % 2, 4 + y), (12 - f % 2, 9 + y),
                                                                   (13 - f % 2, 8 + y)], "teal_l"))


@item("earth_spirit", "土元素精靈", C13, 1, 14, 18, 4, 3)
def _(c, f):
    spirit(c, f, "brown", "fur_l", "dark_d", lambda c, y: c.cells([(5, y + 1), (6, y), (7, y), (6, y - 1)], "green"))


@item("ice_stone", "冰元素石", C13, 1, 16, 20, 3, 3, note="冷氣：冰元素石吹出涼風")
def _(c, f):
    for y in range(2, 15):
        w = 5 - abs(y - 8) // 2
        R(c, 7 - w, y, 8 + w, y, "ice"); c.put(8 + w, y, "ice_d")
    c.cells([(6, 5), (6, 6), (5, 9)], "white"); R(c, 3, 15, 12, 19, "stone"); R(c, 3, 15, 12, 15, "stone_l")
    for i in range(3):
        x = 1 + ((f + i) % 3) * 5
        c.put(x, 2 + i * 4, "ice_d"); c.put(x + 1, 1 + i * 4, "ice")


@item("slime", "小史萊姆", C13, 1, 16, 14, 4, 4)
def _(c, f):
    h = [5, 4, 5, 6][f]
    circle(c, 7.5, 13 - h, 6 + (1 if f == 1 else 0), "slime", h)
    R(c, 1, 12, 14, 13, "slime_d"); c.put(5, 13 - h - h // 2, "slime_l"); c.put(4, 12 - h, "slime_l")
    c.cells([(6, 11 - h // 2), (9, 11 - h // 2)], "black")


@item("puppy", "小狗", C13, 1, 20, 16, 4, 4)
def _(c, f):
    R(c, 3, 7, 13, 12, "fur"); R(c, 3, 12, 13, 12, "fur_d")
    for i, x in enumerate((4, 7, 10, 12)):
        R(c, x, 13, x, 15 - (1 if (i + f) % 2 and f % 2 else 0), "fur_d")
    circle(c, 15, 6, 3.5, "fur", 3); R(c, 17, 7, 19, 8, "fur"); c.put(19, 7, "black"); c.put(15, 5, "black")
    R(c, 12, 2, 13, 6, "fur_d"); c.put(17, 9, "pink") if f % 2 else None
    tail = [(2, 6), (1, 5)] if f % 2 else [(2, 6), (1, 7)]
    c.cells(tail, "fur")


@item("hamster_wheel", "倉鼠滾輪", C13, 1, 18, 18, 4, 8)
def _(c, f):
    R(c, 2, 14, 15, 17, "wood"); R(c, 2, 14, 15, 14, "wood_l")
    circle(c, 8.5, 7.5, 7, "iron_l"); circle(c, 8.5, 7.5, 5.8, None)
    for i in range(4):
        a = math.radians(f * 22 + i * 45)
        for r in range(1, 6):
            c.put(int(8.5 + r * math.cos(a)), int(7.5 + r * math.sin(a)), "iron") if r % 2 else None
    circle(c, 8.5, 11, 2.2, "fur_l", 1.6); c.put(10, 10, "black"); c.put(7, 13 - f % 2, "fur_d")


@item("electric_fan", "電風扇", C13, 1, 16, 26, 3, 8, note="原汁原味的現代彩蛋")
def _(c, f):
    circle(c, 7.5, 7, 6.5, "iron_l"); circle(c, 7.5, 7, 5.5, None)
    for i in range(3):
        a = math.radians(f * 40 + i * 120)
        for r in range(1, 6):
            c.put(int(7.5 + r * math.cos(a)), int(7 + r * math.sin(a)), "blue_l")
            c.put(int(7.5 + r * math.cos(a + 0.4)), int(7 + r * math.sin(a + 0.4)), "blue_l") if r > 2 else None
    circle(c, 7.5, 7, 1.3, "white"); R(c, 7, 14, 8, 23, "iron"); R(c, 3, 23, 12, 25, "white"); c.put(10, 24, "rune")


# ===========================================================================================================================
# Race sets (GUILD.md §5.1): unlocked when the guild has a member of that race. 40 each, over the same categories.
# ===========================================================================================================================
P.update({
    "rust": (166, 92, 52), "rust_d": (120, 62, 36), "rust_l": (204, 130, 80),
    "brass": (200, 160, 70), "brass_d": (150, 112, 44), "brass_l": (236, 204, 120),
    "patch": (130, 150, 90), "patch_d": (96, 112, 64), "steam": (232, 234, 238), "steam_d": (196, 200, 210),
    "gob": (109, 179, 63), "gob_d": (76, 134, 44),
    "moon": (222, 232, 255), "moon_d": (170, 186, 230), "silver": (212, 216, 228), "silver_d": (160, 166, 184),
    "birch": (236, 228, 210), "birch_d": (190, 180, 160), "leaf": (120, 190, 110), "leaf_d": (70, 140, 80), "leaf_l": (170, 220, 140),
    "bone": (240, 236, 222), "bone_d": (196, 190, 172), "bone_x": (150, 144, 128),
    "night": (60, 48, 84), "night_d": (40, 30, 58), "night_l": (96, 80, 128),
    "wisp": (120, 240, 220), "wisp_d": (60, 170, 170), "wisp_l": (210, 255, 248), "web": (214, 214, 226),
    "toxic": (130, 220, 90), "toxic_d": (80, 160, 60),
})


def gear(c, cx, cy, r, f=0, k="brass"):
    circle(c, cx, cy, r, k)
    for i in range(8):
        a = math.radians(f * 22.5 + i * 45)
        c.put(cx + (r + 1) * math.cos(a), cy + (r + 1) * math.sin(a), k)
    circle(c, cx, cy, max(1, r - 2), k + "_d")
    c.put(cx, cy, "black")


def puff(c, x, y, f, n=3, k="steam"):
    """Steam or smoke rising from (x, y), drifting with the frame."""
    for i in range(n):
        yy = y - i * 3 - (f % 2)
        circle(c, x + ((i + f) % 3) - 1, yy, 1.4 + i * 0.4, k if i < n - 1 else k + "_d")


def wisp_flame(c, cx, base, f, k="wisp"):
    sway = [0, 1, 0, -1][f % 4]
    for i, w in enumerate((2, 2, 1, 1, 0)):
        R(c, cx - w + (sway if i > 2 else 0), base - i, cx + w + (sway if i > 2 else 0), base - i, k if i < 3 else k + "_l")
    c.put(cx, base - 1, "wisp_l")


# ------------------------------------------------------------------------------------------------------------------- goblin
# Savage and primitive (user, 2026-10-08): bone, hide, fur, mud, crude logs, rope, sticks, rocks, teeth, feathers, stolen junk
# lashed together, totems, fire pits. Nothing engineered: no gears, steam, rivets or machines.
RACE[0] = "goblin"
P.update({"hide": (196, 150, 104), "hide_d": (150, 108, 70), "hide_l": (224, 190, 146), "mud": (128, 92, 60), "mud_d": (96, 66, 42),
          "rope": (214, 184, 110), "char": (50, 44, 44), "feather": (200, 70, 60), "feather2": (70, 150, 160), "ochre": (200, 110, 50)})


def lash(c, x, y):
    """A rope lashing where two sticks cross."""
    c.cells([(x, y), (x + 1, y + 1), (x - 1, y + 1), (x, y + 2)], "rope")


def stick(c, x0, y0, x1, y1, k="wood_d"):
    n = int(round(max(abs(x1 - x0), abs(y1 - y0), 1)))
    for i in range(n + 1):
        c.put(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, k)


def hide_patch(c, x0, y0, x1, y1):
    """A stretched hide with ragged corners."""
    R(c, x0, y0, x1, y1, "hide"); R(c, x0, y0, x1, y0, "hide_l"); R(c, x1, y0 + 1, x1, y1, "hide_d")
    c.clear([(x0, y0), (x1, y0), (x0, y1), (x1, y1)])
    for x in range(x0 + 2, x1 - 1, 4):
        c.put(x, y1 + 1, "hide_d")


def skull(c, cx, cy, k="bone", horns=False):
    circle(c, cx, cy, 3, k); R(c, cx - 2, cy + 2, cx + 2, cy + 3, k)
    c.cells([(cx - 1, cy), (cx + 1, cy)], "black"); c.cells([(cx - 1, cy + 3), (cx + 1, cy + 3)], "bone_d")
    if horns:
        c.cells([(cx - 3, cy - 2), (cx - 4, cy - 3), (cx - 4, cy - 4), (cx + 3, cy - 2), (cx + 4, cy - 3), (cx + 4, cy - 4)], "bone_d")


def feathers(c, x, y):
    c.cells([(x, y), (x, y + 1), (x - 1, y + 2)], "feather"); c.cells([(x + 1, y + 1), (x + 2, y + 2), (x + 2, y + 3)], "feather2")


@item("gob_log_desk", "原木粗桌", C1, 4, 44, 24, note="一根劈開的大原木架在石頭上")
def _(c, f):
    R(c, 1, 8, 42, 12, "wood"); R(c, 1, 8, 42, 9, "wood_l"); R(c, 1, 12, 42, 13, "wood_d")
    for x in range(4, 41, 7):
        c.put(x, 10, "wood_d"); c.put(x + 3, 11, "wood_d")
    circle(c, 1.5, 10.5, 2.5, "wood_d"); circle(c, 1.5, 10.5, 1.2, "wood_l")            # the cut end, rings showing
    for cx in (6, 37):
        circle(c, cx, 19, 5, "stone", 4); c.put(cx - 2, 17, "stone_l"); R(c, cx - 4, 22, cx + 4, 23, "stone_d")
    R(c, 14, 4, 20, 7, "hide"); R(c, 15, 5, 19, 5, "char"); skull(c, 30, 4); R(c, 24, 5, 25, 7, "bone")


@item("gob_stump_stool", "樹樁凳", C1, 1, 16, 10, seat=True)
def _(c, f):
    h = 10
    sy = h - 1 - SEAT_UP
    circle(c, 7.5, sy - 0.5, 7, "wood_l", 1.5); c.cells([(5, sy - 1), (9, sy)], "wood")
    R(c, 1, sy + 1, 14, h - 1, "wood"); R(c, 1, sy + 1, 1, h - 1, "wood_d"); R(c, 14, sy + 1, 14, h - 1, "wood_d")
    c.cells([(5, sy + 2), (10, sy + 3)], "wood_d"); c.cells([(0, h - 1), (15, h - 1)], "wood_d")


@item("gob_hide_chair", "獸皮椅", C1, 2, 22, 26, seat=True, note="樹枝綁成架子，繃上一張獸皮")
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    stick(c, 3, 1, 4, h - 1); stick(c, 18, 1, 17, h - 1)
    hide_patch(c, 5, 2, 16, sy - 2); c.cells([(8, 7), (12, 10), (9, 13)], "hide_d")
    lash(c, 4, 2); lash(c, 17, 2)
    R(c, 2, sy, 19, sy, "fur_l"); R(c, 2, sy + 1, 19, sy + 1, "fur"); lash(c, 4, sy - 1); lash(c, 17, sy - 1)
    feathers(c, 2, 0)


@item("gob_bone_rack", "獸骨衣帽架", C2, 1, 18, 34)
def _(c, f):
    R(c, 8, 4, 9, 30, "bone"); R(c, 9, 4, 9, 30, "bone_d"); circle(c, 8.5, 32, 5, "stone", 2)
    for y, side in ((7, -1), (11, 1), (16, -1)):
        x = 8 if side < 0 else 9
        R(c, min(x, x + side * 5), y, max(x, x + side * 5), y, "bone"); c.put(x + side * 5, y - 1, "bone")
    skull(c, 8, 2)
    hide_patch(c, 11, 12, 16, 21)


@item("gob_loot_pile", "戰利品堆", C2, 1, 20, 18, note="偷來的東西堆成一堆")
def _(c, f):
    circle(c, 6, 11, 5.5, "hide", 6); R(c, 3, 4, 8, 6, "rope"); c.cells([(5, 9), (7, 12)], "hide_d")       # a sack
    R(c, 11, 10, 18, 17, "iron_l"); circle(c, 14.5, 10, 4, "iron_l", 3); R(c, 11, 11, 18, 11, "iron"); c.put(13, 9, "iron")  # a dented helmet
    c.cells([(15, 8), (16, 9)], "iron_d")
    R(c, 2, 15, 11, 17, "gold_d"); c.cells([(4, 14), (8, 14), (6, 13)], "gold"); R(c, 17, 3, 18, 13, "wood_d"); c.put(17, 2, "iron_l")


@item("gob_stick_shelf", "樹枝架", C2, 2, 30, 34, note="樹枝用繩子綁成的架子")
def _(c, f):
    for x in (2, 27):
        stick(c, x, 0, x + (1 if x < 10 else -1), 33)
    for y in (10, 21, 32):
        stick(c, 1, y, 28, y - 1, "wood"); lash(c, 2, y - 1); lash(c, 27, y - 2)
    skull(c, 9, 5); R(c, 16, 4, 21, 8, "mud"); R(c, 16, 4, 21, 4, "mud_d")         # a clay pot
    circle(c, 8, 17, 3, "stone", 2); circle(c, 13, 18, 2, "stone_d", 1.5); R(c, 19, 14, 25, 19, "hide"); feathers(c, 22, 12)
    c.cells([(6, 29), (7, 28), (9, 29), (11, 28)], "bone"); R(c, 15, 26, 22, 30, "fur")


@item("gob_crystal_log", "木頭水晶電腦", C3, 1, 16, 18, 2, 2, note="電腦：一塊水晶塞在挖空的木頭裡")
def _(c, f):
    R(c, 1, 10, 14, 17, "wood"); R(c, 1, 10, 14, 10, "wood_l"); R(c, 14, 11, 14, 17, "wood_d"); circle(c, 1, 13.5, 2, "wood_d")
    c.cells([(4, 13), (8, 15), (11, 12)], "wood_d")
    for y in range(1, 11):
        w = min(3, y // 2, (11 - y) // 2 + 1)
        R(c, 7.5 - w, y, 7.5 + w, y, "teal_l" if f else "teal")
    c.put(6, 3, "white"); c.cells([(7, 5), (8, 7)], "glow" if f else "teal_l")


@item("gob_tooth_counter", "牙齒算盤", C3, 1, 18, 14, note="一串串牙齒，用來數東西")
def _(c, f):
    stick(c, 1, 1, 1, 13); stick(c, 16, 1, 16, 13); stick(c, 1, 1, 16, 1, "wood"); stick(c, 1, 13, 16, 13, "wood")
    for i, y in enumerate((4, 7, 10)):
        stick(c, 2, y, 15, y, "rope")
        for x in range(3 + i, 13, 3):
            c.put(x, y, "bone"); c.put(x, y + 1, "bone_d")


@item("gob_horn_cup", "牛角杯", C3, 1, 14, 14)
def _(c, f):
    for i in range(10):
        R(c, 2 + i, 3 + i // 3, 2 + i, 9 - i // 4, "bone" if i < 8 else "bone_d")
    R(c, 2, 3, 3, 9, "bone_d"); R(c, 3, 4, 3, 8, "brown"); c.cells([(11, 7), (12, 8), (12, 9)], "bone_d")
    R(c, 1, 11, 12, 13, "wood_d")


@item("gob_torch_stake", "火把樁", C4, 1, 12, 26, 3, 6)
def _(c, f):
    stick(c, 5, 8, 6, 25, "wood_d"); stick(c, 6, 8, 7, 25, "wood")
    R(c, 3, 8, 9, 10, "hide"); lash(c, 6, 10); flame(c, 6, 7, 7, f, 2)
    circle(c, 6, 25, 3, "stone", 1)


@item("gob_antler_chandelier", "鹿角吊燈", C4, 4, 40, 24, 3, 6, ceiling=True, note="用繩子吊著的鹿角，插滿蠟燭")
def _(c, f):
    stick(c, 10, 0, 18, 8, "rope"); stick(c, 29, 0, 21, 8, "rope")
    R(c, 6, 10, 33, 12, "bone"); R(c, 6, 12, 33, 12, "bone_d")
    for x0, d in ((6, -1), (33, 1)):
        for i in range(5):
            c.put(x0 + d * i // 2, 10 - i, "bone")
    for x in (8, 14, 19, 25, 31):
        R(c, x, 7, x + 1, 9, "cloth"); flame(c, x, 6, 3, f + x, 0)
        c.put(x, 13, "cloth"); c.put(x + 1, 14, "cloth")                        # wax drips
    skull(c, 19, 16)


@item("gob_fire_bowl", "石頭火坑", C4, 2, 24, 20, 3, 6)
def _(c, f):
    for i, (x, y) in enumerate(((3, 16), (7, 18), (12, 18), (17, 18), (21, 16), (4, 12), (20, 12))):
        circle(c, x, y, 2.5, "stone" if i % 2 else "stone_d"); c.put(x - 1, y - 1, "stone_l")
    R(c, 6, 13, 18, 16, "char"); R(c, 7, 13, 17, 13, "wood_d")
    for x, h in ((8, 6), (12, 9), (16, 7)):
        flame(c, x, 13, h + f % 2, f + x, 1)


@item("gob_hide_board", "獸皮塗鴉板", C5, 2, 30, 26, wall=True, note="白板：樹枝繃一張獸皮，用木炭亂畫")
def _(c, f):
    stick(c, 1, 0, 2, 25); stick(c, 28, 0, 27, 25); stick(c, 0, 2, 29, 2, "wood"); stick(c, 0, 22, 29, 21, "wood")
    hide_patch(c, 4, 4, 25, 20)
    for x0, y0 in ((4, 4), (25, 4), (4, 20), (25, 20)):
        lash(c, 2 if x0 < 10 else 27, y0 - 1)
    circle(c, 9, 10, 2.5, "char", 2); c.cells([(6, 10), (12, 10), (8, 13), (10, 13)], "char")     # a goblin doodle
    stick(c, 14, 7, 22, 7, "char"); stick(c, 14, 11, 20, 12, "char"); c.cells([(15, 15), (17, 16), (19, 15), (21, 16)], "char")
    R(c, 7, 16, 8, 18, "ochre"); c.put(22, 9, "ochre")


@item("gob_antler_skull", "鹿角頭骨", C5, 1, 22, 18, wall=True, note="戰利品：鹿角頭骨（老早就是骨頭了）")
def _(c, f):
    R(c, 7, 13, 14, 17, "wood"); R(c, 7, 13, 14, 13, "wood_l")
    circle(c, 10.5, 8, 3.5, "bone"); R(c, 8, 10, 13, 13, "bone"); c.cells([(9, 8), (12, 8)], "black"); c.cells([(10, 12), (11, 12)], "bone_d")
    for side in (-1, 1):
        g = (lambda x: x) if side < 0 else (lambda x: 21 - x)
        c.cells([(g(7), 5), (g(6), 4), (g(5), 3), (g(4), 2), (g(3), 1), (g(5), 1), (g(5), 0), (g(2), 3), (g(1), 2), (g(7), 2), (g(8), 1)], "bone_d")
    feathers(c, 15, 12)


@item("gob_handprint_hide", "手印獸皮", C5, 2, 30, 30, wall=True, note="洞穴壁畫風：手印、獵物、火")
def _(c, f):
    hide_patch(c, 2, 2, 27, 26); c.cells([(1, 3), (28, 3), (1, 25), (28, 25)], "hide_d")
    for x, y, k in ((6, 6, "ochre"), (20, 15, "red_d")):                          # handprints
        R(c, x, y + 3, x + 3, y + 6, k)
        for i in range(4):
            R(c, x + i, y + (0 if i in (1, 2) else 1), x + i, y + 2, k)
        R(c, x - 1, y + 4, x - 1, y + 5, k)
    R(c, 13, 8, 19, 10, "char"); c.cells([(13, 11), (15, 11), (17, 11), (19, 11), (20, 7), (21, 6)], "char")   # a deer
    c.cells([(6, 19), (7, 18), (8, 19), (9, 20), (10, 19)], "char"); R(c, 7, 20, 9, 22, "char")              # a stick goblin
    flame(c, 15, 23, 4, 0, 1) if False else c.cells([(15, 21), (14, 22), (16, 22), (15, 23)], "ochre")


@item("gob_hide_rug", "獸皮地毯", C6, 4, 40, 28, flat=True, note="大毛皮，邊邊還有爪子")
def _(c, f):
    circle(c, 19.5, 14, 16, "fur_d", 10); circle(c, 19.5, 13.5, 15, "brown", 9)
    for x, y in ((3, 4), (2, 5), (36, 4), (37, 5), (3, 23), (2, 22), (36, 23), (37, 22)):
        c.put(x, y, "brown")
    for x, y in ((2, 4), (37, 4), (2, 23), (37, 23)):
        c.put(x, y + (1 if y < 10 else -1), "bone")
    circle(c, 19.5, 3, 4, "brown", 3); c.cells([(18, 3), (21, 3)], "black"); c.cells([(15, 1), (24, 1)], "fur_d")
    for x in range(8, 32, 4):
        c.put(x, 14, "fur_d"); c.put(x + 2, 10, "fur_d")


@item("gob_straw_nest", "稻草窩", C6, 2, 34, 20, flat=True, note="稻草加獸皮的床，睡起來扎扎的")
def _(c, f):
    circle(c, 16.5, 10, 16, "straw_d", 9); circle(c, 16.5, 9.5, 15, "straw", 8)
    for x in range(3, 31, 2):
        c.put(x, 3 + (x * 7) % 5, "straw_d"); c.put(x + 1, 14 - (x * 3) % 4, "f1")
    hide_patch(c, 12, 6, 24, 13); circle(c, 8, 9, 3, "fur", 2)


@item("gob_feather_mat", "羽毛墊", C6, 1, 18, 12, flat=True)
def _(c, f):
    circle(c, 8.5, 6, 8, "hide", 5); circle(c, 8.5, 6, 6.5, "hide_l", 3.8)
    for i, x in enumerate(range(3, 15, 2)):
        stick(c, x, 3, x + 1, 9, "feather" if i % 2 else "feather2")


@item("gob_mushroom_patch", "野蘑菇叢", C7, 1, 16, 14)
def _(c, f):
    R(c, 1, 11, 14, 13, "mud"); R(c, 1, 11, 14, 11, "mud_d")
    for x, y, r, k in ((4, 6, 3, "red"), (10, 5, 3.5, "brown"), (7, 9, 2, "fur"), (13, 9, 1.6, "red")):
        circle(c, x, y, r, k, r * 0.65); R(c, int(x), int(y + 1), int(x), 10, "cloth")
    c.cells([(3, 5), (5, 4), (12, 9)], "white")


@item("gob_helmet_planter", "頭盔盆栽", C7, 1, 16, 18, note="撿來的凹頭盔裝土種草")
def _(c, f):
    circle(c, 7.5, 13, 6.5, "iron_l", 4); R(c, 1, 13, 14, 17, "iron_l"); R(c, 1, 13, 14, 13, "iron"); R(c, 14, 14, 14, 17, "iron")
    c.cells([(4, 15), (5, 16)], "iron_d"); R(c, 3, 10, 12, 11, "mud")
    for x, top in ((4, 4), (6, 2), (8, 5), (10, 3), (11, 6)):
        stick(c, x, top, x, 10, "green" if x % 2 else "green_d")
    c.cells([(6, 1), (10, 2)], "yellow")


@item("gob_thorn_bush", "荊棘叢", C7, 2, 26, 20)
def _(c, f):
    blob(c, 8, 12, 7, "green_d", "black", "green", 6); blob(c, 17, 12, 7, "green_d", "black", "green", 6)
    for x, y in ((2, 8), (5, 5), (12, 6), (20, 5), (24, 9), (14, 4), (9, 16), (19, 16)):
        c.put(x, y, "bone_d")
    c.cells([(10, 9), (16, 11), (7, 13)], "red"); R(c, 3, 18, 22, 19, "mud")


@item("gob_king_idol", "哥布林王木雕", C8, 4, 26, 42, note="歪歪扭扭的哥布林王木頭像")
def _(c, f):
    R(c, 7, 12, 18, 41, "wood"); R(c, 7, 12, 7, 41, "wood_l"); R(c, 18, 12, 18, 41, "wood_d")
    circle(c, 12.5, 11, 7, "wood"); c.cells([(3, 9), (4, 10), (5, 10), (22, 9), (21, 10), (20, 10)], "wood")    # big ears
    c.cells([(9, 10), (16, 10)], "black"); R(c, 10, 14, 15, 15, "wood_d"); c.cells([(10, 14), (15, 14)], "bone")  # tusks
    R(c, 8, 2, 17, 5, "gold_d"); c.cells([(8, 1), (11, 0), (14, 0), (17, 1)], "gold")                       # a crude crown
    R(c, 9, 21, 16, 22, "ochre"); R(c, 10, 26, 15, 27, "ochre"); feathers(c, 6, 2); feathers(c, 18, 2)
    for x, y in ((3, 39), (7, 41), (18, 41), (22, 39)):
        circle(c, x, y, 2, "stone")


@item("gob_totem", "部落圖騰柱", C8, 2, 22, 42)
def _(c, f):
    R(c, 6, 4, 15, 41, "wood"); R(c, 15, 4, 15, 41, "wood_d")
    for y0, k in ((5, "ochre"), (17, "red_d"), (29, "teal")):                   # three stacked faces
        R(c, 6, y0, 15, y0, "wood_d"); c.cells([(8, y0 + 3), (13, y0 + 3)], "black"); R(c, 9, y0 + 7, 12, y0 + 8, k)
        c.cells([(7, y0 + 5), (14, y0 + 5)], k)
    R(c, 1, 16, 5, 18, "wood"); R(c, 16, 16, 20, 18, "wood"); c.cells([(0, 15), (21, 15)], "wood_l")             # wings
    feathers(c, 8, 0); feathers(c, 12, 0)


@item("gob_skull_pile", "頭骨堆", C8, 2, 26, 18, note="大世界撿來的老骨頭")
def _(c, f):
    for x, y in ((6, 12), (13, 12), (20, 12), (9, 7), (17, 7), (13, 3)):
        skull(c, x, y)
    R(c, 2, 16, 23, 17, "mud")


@item("gob_war_drum", "獸皮戰鼓", C9, 2, 24, 24, 2, 3)
def _(c, f):
    circle(c, 11.5, 7, 9, "hide_l", 3); R(c, 2, 7, 21, 20, "wood"); circle(c, 11.5, 20, 9.5, "wood_d", 2.5); circle(c, 11.5, 7, 9, "hide_l", 3)
    for x in range(3, 21, 3):
        stick(c, x, 9, x + 1, 19, "rope")
    c.cells([(7, 13), (15, 14)], "bone"); stick(c, 18, 0 + f, 22, 3 + f, "bone"); circle(c, 18, 0 + f, 1, "fur")
    if f:
        c.cells([(5, 2), (4, 1), (17, 3)], "white")


@item("gob_wheel_table", "破車輪賭桌", C9, 2, 30, 22, note="偷來的車輪放在樹樁上")
def _(c, f):
    R(c, 11, 11, 18, 21, "wood"); R(c, 11, 11, 11, 21, "wood_d")
    circle(c, 14.5, 7, 14, "wood_d", 5); circle(c, 14.5, 6.5, 12.5, "wood", 4)
    for a in range(0, 360, 45):
        stick(c, 14.5, 6.5, 14.5 + 11 * math.cos(math.radians(a)), 6.5 + 3.5 * math.sin(math.radians(a)), "wood_d")
    circle(c, 14.5, 6.5, 2, "iron"); c.cells([(3, 4), (26, 9)], None)                     # a chunk broken off
    R(c, 7, 4, 9, 6, "bone"); c.put(8, 5, "black"); R(c, 19, 5, 21, 7, "bone"); c.cells([(19, 5), (21, 7)], "black")


@item("gob_rope_hammock", "破網吊床", C9, 2, 36, 22, seat=True)
def _(c, f):
    stick(c, 1, 2, 2, 21); stick(c, 34, 2, 33, 21)
    for x in range(3, 33):
        y = 10 + int(4 * math.sin(math.pi * (x - 3) / 29))
        c.put(x, y, "rope"); c.put(x, y + 1, "straw")
        if x % 3 == 0:
            stick(c, x, 4 + int(2 * math.sin(math.pi * (x - 3) / 29)), x, y, "rope")
    stick(c, 3, 4, 32, 4, "rope"); c.put(17, 15, None); c.put(18, 15, None); hide_patch(c, 12, 9, 20, 12)


@item("gob_waterskin", "獸皮水袋架", C10, 1, 16, 26, 2, 2, note="飲水機：三腳架掛一個獸皮水袋")
def _(c, f):
    stick(c, 7, 0, 1, 25); stick(c, 8, 0, 14, 25); stick(c, 7, 0, 8, 25, "wood"); lash(c, 7, 0)
    stick(c, 7, 3, 7, 6, "rope"); circle(c, 7.5, 11, 4.5, "hide", 5); c.put(5, 8, "hide_l"); R(c, 7, 16, 8, 17, "hide_d")
    if f:
        c.put(7, 19, "water_l"); c.put(7, 21, "water")
    R(c, 4, 22, 11, 24, "mud"); R(c, 5, 22, 10, 22, "water")


@item("gob_spit_roast", "烤肉架", C10, 4, 40, 26, 3, 6, note="架在火上慢慢轉的烤肉")
def _(c, f):
    for x in (4, 35):
        stick(c, x - 3, 25, x, 6); stick(c, x + 3, 25, x, 6); lash(c, x, 5)
    stick(c, 2, 7, 38, 7, "wood_d"); R(c, 37, 5, 38, 9, "wood")
    rot = f % 2
    circle(c, 19.5, 10, 7, "brown", 3.5); circle(c, 19.5, 9.5 - rot * 0.3, 6, "ochre", 2.5); c.cells([(15, 8), (22, 9 - rot)], "f1")
    for i, (x, y) in enumerate(((10, 23), (14, 25), (25, 25), (29, 23))):
        circle(c, x, y, 2, "stone")
    R(c, 13, 21, 26, 22, "wood_d")
    for x, h in ((15, 5), (19, 7), (24, 5)):
        flame(c, x, 20, h + f % 2, f + x, 1)


@item("gob_stew_pot", "大雜燴鍋", C10, 2, 26, 24, 3, 4, note="石頭上架一口大陶鍋，裡面有什麼不要問")
def _(c, f):
    for x, y in ((4, 21), (9, 22), (16, 22), (21, 21)):
        circle(c, x, y, 2.4, "stone")
    flame(c, 9, 20, 3, f, 1); flame(c, 16, 20, 3, f + 1, 1)
    circle(c, 12.5, 12, 9, "mud_d", 6); circle(c, 12.5, 11, 8.5, "mud", 5.5); R(c, 4, 6, 21, 7, "mud_d")
    R(c, 5, 7, 20, 8, "ochre"); c.cells([(8, 7), (15, 6)], "bone"); c.put(11, 7, "green"); stick(c, 18, 0, 15, 8, "wood_d")
    for i, x in enumerate((8, 13, 17)):
        if (i + f) % 3:
            circle(c, x, 5 - (i + f) % 3, 1, "ochre")


@item("gob_stick_fence", "歪木柵欄", C11, 2, 34, 22)
def _(c, f):
    for i, x in enumerate(range(2, 33, 5)):
        top = 2 + (i * 7) % 4
        tilt = (i % 3) - 1
        stick(c, x, top, x + tilt, 21); stick(c, x + 1, top, x + 1 + tilt, 21, "wood"); c.put(x, top - 1, "wood_d")
    stick(c, 0, 8, 33, 10, "wood"); stick(c, 0, 15, 33, 14, "wood"); lash(c, 7, 8); lash(c, 22, 9); skull(c, 17, 4)


@item("gob_hide_curtain", "獸皮門簾", C11, 2, 26, 36, wall=True)
def _(c, f):
    stick(c, 0, 2, 25, 2, "wood"); circle(c, 1, 2, 1.5, "wood_d")
    hide_patch(c, 2, 3, 11, 33); hide_patch(c, 14, 3, 23, 33)
    for y in range(6, 32, 5):
        c.put(5, y, "hide_d"); c.put(18, y + 2, "hide_d")
    c.cells([(12, 33), (13, 34)], "hide_d"); feathers(c, 3, 3); skull(c, 18, 9)


@item("gob_rock_door", "石塊洞口", C11, 4, 42, 42, wall=True, note="用大石頭堆成的洞口")
def _(c, f):
    for x, y, r in ((5, 36, 5), (5, 26, 5), (6, 16, 5), (10, 7, 5), (20, 4, 5), (31, 7, 5), (36, 16, 5), (37, 26, 5), (37, 36, 5)):
        circle(c, x, y, r, "stone"); c.put(x - 2, y - 2, "stone_l"); circle(c, x + 1.5, y + 1.5, r - 3, "stone_d") if r > 3 else None
    circle(c, 21, 26, 14, "black", 17); R(c, 9, 26, 33, 41, "black")
    R(c, 12, 30, 30, 41, "night_d"); c.cells([(17, 6), (25, 6)], "bone"); skull(c, 21, 3)


@item("gob_campfire", "營火", C12, 2, 24, 20, 3, 6)
def _(c, f):
    for x, y in ((3, 16), (7, 18), (13, 18), (18, 17), (20, 14), (2, 13)):
        circle(c, x, y, 2, "stone")
    R(c, 6, 14, 17, 15, "wood_d"); R(c, 8, 12, 15, 13, "wood")
    for x, h in ((9, 6), (12, 9), (15, 5)):
        flame(c, x, 12, h + f % 2, f + x, 1)
    stick(c, 20, 2, 21, 13); stick(c, 3, 3, 20, 3, "wood_d"); lash(c, 20, 2); circle(c, 11, 6, 2, "brown")


@item("gob_mud_hut", "泥巴小屋", C12, 4, 42, 38)
def _(c, f):
    circle(c, 20.5, 24, 19, "mud_d", 14); circle(c, 20.5, 23, 18, "mud", 13); R(c, 2, 24, 39, 37, "mud")
    for i in range(18):
        x = 20.5 + 18 * math.cos(math.pi * (1 - i / 17))
        stick(c, x, 23 - 13 * math.sin(math.pi * i / 17) - 1, 20.5, 2, "straw_d")    # straw thatch
    circle(c, 20.5, 12, 18, "straw", 9); R(c, 3, 12, 38, 14, "straw_d")
    circle(c, 20.5, 30, 6, "black", 7); R(c, 15, 30, 26, 37, "black"); hide_patch(c, 15, 25, 18, 36)
    c.cells([(8, 20), (9, 21), (33, 22), (32, 26)], "mud_d"); skull(c, 20, 18); stick(c, 2, 37, 39, 37, "mud_d")


@item("gob_bat_branch", "蝙蝠枯枝", C12, 1, 22, 24, 3, 3, note="一根枯枝，倒掛著幾隻蝙蝠")
def _(c, f):
    stick(c, 3, 23, 5, 4); stick(c, 4, 23, 6, 4, "wood"); stick(c, 5, 5, 20, 3, "wood_d"); stick(c, 9, 4, 12, 0, "wood_d")
    for i, x in enumerate((9, 14, 18)):
        y = 5
        if (i + f) % 3 == 2:
            c.cells([(x - 2, y + 2), (x - 1, y + 3), (x, y + 3), (x + 1, y + 3), (x + 2, y + 2)], "black")   # wings open
        R(c, x - 1, y + 1, x + 2, y + 5, "night"); c.cells([(x - 1, y + 2), (x + 2, y + 2)], "night_l")
        c.cells([(x, y + 4), (x + 1, y + 4)], "f2"); c.cells([(x - 1, y + 6), (x + 2, y + 6)], "night")   # ears (upside down)
    circle(c, 4.5, 23, 3, "stone", 1)


@item("gob_rat", "老鼠", C13, 1, 16, 10, 4, 6)
def _(c, f):
    R(c, 4, 4, 11, 8, "stone_d"); R(c, 4, 4, 11, 4, "stone"); R(c, 11, 5, 13, 7, "stone_d"); c.put(13, 6, "pink"); c.put(12, 5, "black")
    c.cells([(10, 3), (11, 3)], "pink")
    for i, x in enumerate((5, 8, 10)):
        c.put(x + (1 if (i + f) % 2 else 0), 9, "stone_x")
    tail = [(3, 6), (2, 5), (1, 6)] if f % 2 else [(3, 6), (2, 7), (1, 6)]
    c.cells(tail, "pink")


@item("gob_pet_toad", "寵物蟾蜍", C13, 1, 16, 12, 3, 3)
def _(c, f):
    h = [0, 1, 0][f]
    circle(c, 7.5, 7 - h, 5.5, "patch", 3.5); circle(c, 7.5, 8 - h, 3.5, "straw", 2)
    circle(c, 5, 3 - h, 1.4, "patch"); circle(c, 10, 3 - h, 1.4, "patch"); c.cells([(5, 3 - h), (10, 3 - h)], "black")
    R(c, 6, 6 - h, 9, 6 - h, "patch_d"); R(c, 1, 10, 4, 11, "patch_d"); R(c, 11, 10, 14, 11, "patch_d")
    c.cells([(4, 6 - h), (11, 7 - h)], "patch_d")
    if f == 2:
        R(c, 8, 6, 12, 6, "pink")


@item("gob_wolf_pup", "癩皮小狼", C13, 2, 22, 18, 4, 4, note="毛掉了幾塊，但很黏人")
def _(c, f):
    R(c, 4, 8, 15, 13, "stone"); R(c, 4, 13, 15, 13, "stone_d"); c.cells([(7, 9), (11, 11)], "pink")          # bald patches
    for i, x in enumerate((5, 8, 12, 14)):
        R(c, x, 14, x, 17 - (1 if (i + f) % 2 and f % 2 else 0), "stone_d")
    circle(c, 17, 7, 3.5, "stone", 3); R(c, 19, 8, 21, 9, "stone"); c.put(21, 8, "black"); c.put(17, 6, "black")
    c.cells([(15, 2), (15, 3), (16, 3), (19, 2), (19, 3), (18, 3)], "stone"); c.put(19, 10, "pink") if f % 2 else None
    tail = [(3, 7), (2, 6), (1, 5)] if f % 2 else [(3, 8), (2, 8), (1, 9)]
    c.cells(tail, "stone")


@item("gob_lizard_cage", "籠中蜥蜴", C13, 1, 18, 20, 3, 3, note="樹枝編的籠子關著一隻蜥蜴")
def _(c, f):
    R(c, 1, 17, 16, 19, "wood"); stick(c, 1, 3, 16, 3, "wood")
    for x in range(1, 17, 3):
        stick(c, x, 3, x, 17, "wood_d")
    lash(c, 1, 2); lash(c, 16, 2); stick(c, 8, 0, 8, 3, "rope")
    x = [4, 7, 5][f]
    R(c, x, 13, x + 5, 15, "green"); c.put(x + 6, 14, "green"); c.put(x + 5, 13, "black"); c.cells([(x - 1, 15), (x - 2, 16)], "green_d")
    c.cells([(x + 1, 16), (x + 4, 16)], "green_d"); c.put(x + 7, 14, "pink") if f == 2 else None


# --------------------------------------------------------------------------------------------------------------------- elf
RACE[0] = "elf"


@item("elf_root_desk", "樹根書桌", C1, 4, 44, 28, note="長在地上的樹根長成的桌子")
def _(c, f):
    R(c, 2, 8, 41, 11, "birch"); R(c, 2, 12, 41, 14, "birch_d"); R(c, 2, 8, 41, 8, "white")
    for x0 in (4, 36):
        for y in range(15, 27):
            c.put(x0 + (y % 3) - 1, y, "wood"); c.put(x0 + (y % 3), y, "wood_d")
        c.cells([(x0 - 2, 26), (x0 - 3, 27), (x0 + 3, 26), (x0 + 4, 27)], "wood_d")
    for x in range(6, 40, 6):
        c.put(x, 13, "leaf")
    crystal(c, 33, 4, 3.5, 1); R(c, 31, 7, 35, 7, "silver"); R(c, 8, 5, 13, 7, "paper"); c.cells([(17, 6), (18, 5), (19, 6)], "leaf")


@item("elf_leaf_chair", "葉片椅", C1, 1, 16, 26, seat=True)
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    for y in range(1, sy):
        w = min(6, 1 + y // 2, (sy - y) + 2)
        R(c, 7.5 - w, y, 7.5 + w, y, "leaf"); c.put(7, y, "leaf_d")
    R(c, 1, sy, 14, sy, "leaf_l"); R(c, 1, sy + 1, 14, sy + 1, "leaf"); R(c, 3, sy + 2, 3, h - 1, "birch_d"); R(c, 12, sy + 2, 12, h - 1, "birch_d")


@item("elf_bloom_chair", "會開花的盆栽椅", C1, 2, 24, 26, 2, 1, seat=True)
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    blob(c, 11.5, 8, 9, "leaf", "leaf_d", "leaf_l", 7)
    for x, y in ((6, 5), (12, 3), (17, 7), (9, 10), (15, 11)):
        c.cells([(x, y)], "pink" if f else "leaf_l"); c.put(x + 1, y, "white" if f else "leaf")
    R(c, 3, sy, 20, sy, "leaf_l"); R(c, 3, sy + 1, 20, h - 2, "pot"); R(c, 20, sy + 1, 20, h - 2, "pot_d"); R(c, 3, h - 1, 20, h - 1, "pot_d")


@item("elf_living_bookcase", "活樹書櫃", C2, 2, 32, 42)
def _(c, f):
    R(c, 1, 6, 30, 41, "wood"); R(c, 1, 6, 4, 41, "wood_d"); R(c, 27, 6, 30, 41, "wood_d")
    blob(c, 8, 5, 6, "leaf", "leaf_d", "leaf_l", 4); blob(c, 23, 5, 6, "leaf", "leaf_d", "leaf_l", 4); blob(c, 15.5, 3, 6, "leaf", "leaf_d", "leaf_l", 3)
    for i, y in enumerate((12, 21, 30)):
        R(c, 5, y, 26, y + 7, "wood_x"); shelf_books(c, 5, 26, y + 7, 7, i + 2); R(c, 4, y + 8, 27, y + 8, "wood_l")
    c.cells([(3, 15), (2, 22), (29, 18), (28, 33)], "leaf")


@item("elf_vine_chest", "藤蔓寶箱", C2, 1, 18, 16)
def _(c, f):
    R(c, 1, 2, 16, 6, "birch"); R(c, 1, 6, 16, 6, "birch_d"); box(c, 1, 7, 16, 15, "birch", None, "birch_d")
    for x in range(1, 17):
        c.put(x, 4 + int(1.5 * math.sin(x)), "leaf_d")
    c.cells([(4, 3), (9, 5), (13, 3)], "leaf"); R(c, 7, 7, 10, 9, "silver"); c.put(8, 8, "night")


@item("elf_seed_cabinet", "種子抽屜櫃", C2, 1, 16, 26)
def _(c, f):
    box(c, 1, 1, 14, 25, "birch", "white", "birch_d")
    for row in range(4):
        for col in range(2):
            x, y = 3 + col * 6, 3 + row * 5
            R(c, x, y, x + 4, y + 3, "birch_d"); c.put(x + 2, y + 1, ["leaf", "pink", "gold", "brown"][(row + col) % 4])
    R(c, 2, 24, 13, 25, "wood")


@item("elf_moon_monitor", "月光水晶螢幕", C3, 1, 14, 18, 2, 2, note="精靈的電腦：月光水晶")
def _(c, f):
    for y in range(1, 13):
        w = min(4, y // 2 + 1, (13 - y) // 2 + 1)
        R(c, 6.5 - w, y, 6.5 + w, y, "moon" if f else "moon_d")
    R(c, 5, 5, 8, 5, "white"); R(c, 4, 7, 9, 7, "white" if f else "moon"); c.put(5, 2, "white")
    R(c, 3, 13, 10, 14, "silver"); R(c, 2, 15, 11, 16, "silver_d"); c.cells([(2, 13), (11, 13)], "leaf")


@item("elf_leaf_quill", "葉片羽毛筆", C3, 1, 14, 14)
def _(c, f):
    R(c, 2, 9, 8, 13, "silver"); R(c, 3, 8, 7, 8, "silver_d"); c.put(4, 10, "moon")
    for i in range(8):
        R(c, 5 + i // 2, 8 - i, 7 + i // 2, 8 - i, "leaf" if i > 1 else "leaf_d")
    c.put(10, 1, "leaf_l"); c.put(11, 0, "leaf")


@item("elf_dew_vial", "露珠瓶", C3, 1, 12, 14, 2, 2)
def _(c, f):
    circle(c, 5.5, 9, 4, "glass"); circle(c, 6, 9.5, 3, "water_l"); R(c, 4, 2, 7, 5, "glass"); R(c, 3, 1, 8, 2, "leaf")
    c.put(4, 7, "white"); c.put(6, 10 - f, "glow")


@item("elf_moon_lamp", "月光檯燈", C4, 1, 14, 20, 2, 2)
def _(c, f):
    circle(c, 6.5, 6, 5, "moon" if f else "moon_d"); circle(c, 8.5, 5, 4, None); c.put(4, 4, "white")
    R(c, 6, 11, 7, 17, "silver"); R(c, 3, 17, 10, 19, "silver_d"); c.cells([(4, 14), (5, 13), (9, 15)], "leaf")
    if f:
        c.cells([(1, 2), (11, 9), (2, 10)], "moon")


@item("elf_firefly_chandelier", "螢火蟲吊燈", C4, 2, 28, 24, 3, 4, ceiling=True)
def _(c, f):
    R(c, 13, 0, 14, 4, "wood_d")
    for i in range(14):
        c.put(3 + i * 23 / 13, 6 + int(3 * math.sin(math.pi * i / 13)), "wood")
    blob(c, 13.5, 6, 6, "leaf", "leaf_d", "leaf_l", 3)
    for i, (x, y) in enumerate(((4, 12), (9, 16), (14, 13), (19, 17), (24, 12), (12, 20), (17, 9))):
        if (i + f) % 3:
            c.put(x, y + (f + i) % 2, "f1"); c.put(x, y - 1 + (f + i) % 2, "yellow")


@item("elf_bud_lamp", "花苞燈", C4, 1, 12, 22, 2, 2)
def _(c, f):
    R(c, 5, 9, 6, 20, "leaf_d"); R(c, 2, 13, 4, 14, "leaf"); R(c, 7, 15, 9, 16, "leaf"); R(c, 3, 20, 8, 21, "birch_d")
    for y in range(1, 9):
        w = min(3, y // 2 + 1, (9 - y))
        R(c, 5.5 - w, y, 5.5 + w, y, "f1" if f else "pink")
    c.put(5, 4, "f4" if f else "white")


@item("elf_silver_tapestry", "銀葉掛毯", C5, 2, 30, 32, wall=True)
def _(c, f):
    R(c, 0, 0, 29, 1, "birch_d"); R(c, 2, 2, 27, 28, "leaf_d"); R(c, 2, 2, 27, 3, "silver"); R(c, 2, 27, 27, 28, "silver")
    for x, y in ((9, 8), (19, 10), (12, 16), (21, 20), (7, 22)):
        for i in range(4):
            c.put(x + i, y - i // 2, "silver"); c.put(x + i, y + 1 - i // 2, "silver_d")
    circle(c, 15, 14, 3, "moon"); circle(c, 16.5, 13.5, 2.5, "leaf_d")
    for x in range(3, 27, 3):
        c.put(x, 29, "silver")


@item("elf_wreath", "花環", C5, 1, 20, 20, wall=True)
def _(c, f):
    for a in range(0, 360, 12):
        x, y = 9.5 + 7 * math.cos(math.radians(a)), 9.5 + 7 * math.sin(math.radians(a))
        circle(c, x, y, 1.4, "leaf")
    for a in range(0, 360, 60):
        c.put(9.5 + 7 * math.cos(math.radians(a)), 9.5 + 7 * math.sin(math.radians(a)), "pink")
    R(c, 8, 16, 11, 19, "silver")


@item("elf_moon_mirror", "月鏡", C5, 2, 24, 28, 2, 2, wall=True)
def _(c, f):
    circle(c, 11.5, 13, 11, "silver", 13); circle(c, 11.5, 13, 9, "night", 11)
    circle(c, 11.5, 11, 4, "moon" if f else "moon_d"); circle(c, 13, 10, 3.5, "night")
    c.cells([(6, 7), (17, 16), (8, 19), (16, 5)], "white" if f else "moon_d")
    c.cells([(1, 6), (2, 5), (22, 6), (21, 5), (1, 20), (22, 20)], "leaf")


@item("elf_moss_rug", "苔蘚地毯", C6, 4, 44, 30, flat=True)
def _(c, f):
    circle(c, 21.5, 15, 21, "leaf_d", 14); circle(c, 21.5, 14.5, 19.5, "green", 12.5)
    import random
    rng = random.Random(9)
    for _ in range(60):
        x, y = rng.randrange(4, 40), rng.randrange(4, 26)
        if c.px[y][x] == "green":
            c.put(x, y, rng.choice(["leaf", "leaf_l", "green_d"]))
    c.cells([(12, 9), (30, 18), (20, 21)], "pink"); c.cells([(13, 9), (31, 18)], "white")


@item("elf_leaf_rug", "落葉地毯", C6, 2, 34, 22, flat=True)
def _(c, f):
    for i, (x, y, k) in enumerate(((7, 6, "orange"), (16, 5, "gold"), (25, 7, "red_l"), (10, 14, "gold"), (20, 15, "orange"),
                                   (28, 15, "leaf"), (4, 13, "red_l"), (15, 10, "leaf"))):
        circle(c, x, y, 4, k, 3); R(c, x - 3, y, x + 3, y, "brown")


@item("elf_petal_mat", "花瓣地墊", C6, 1, 18, 12, flat=True)
def _(c, f):
    circle(c, 8.5, 5.5, 8, "white", 5); circle(c, 8.5, 5.5, 6, "pink", 3.5)
    c.cells([(3, 3), (14, 7), (8, 1), (6, 9)], "pink_d"); c.put(8, 5, "yellow")


@item("elf_silverleaf_tree", "銀葉樹", C7, 2, 26, 40)
def _(c, f):
    R(c, 6, 33, 19, 39, "silver_d"); R(c, 5, 32, 20, 33, "silver")
    R(c, 12, 18, 13, 32, "birch"); c.cells([(11, 22), (14, 25)], "birch_d")
    blob(c, 13, 10, 10, "silver", "silver_d", "white", 9); blob(c, 6, 15, 4, "silver", "silver_d", "white"); blob(c, 20, 15, 4, "silver", "silver_d", "white")
    c.cells([(9, 7), (16, 12), (12, 4)], "moon")


@item("elf_moonflower", "月光花", C7, 1, 14, 22, 2, 2)
def _(c, f):
    pot(c, 7, 21, 8, 5, "stone"); R(c, 6, 8, 7, 15, "leaf_d"); R(c, 3, 11, 5, 12, "leaf"); R(c, 8, 13, 10, 14, "leaf")
    for (x, y) in ((6, 3), (4, 5), (8, 5), (6, 7), (5, 4), (7, 4), (5, 6), (7, 6)):
        c.put(x, y, "moon" if f else "moon_d")
    c.put(6, 5, "f1" if f else "yellow")


@item("elf_hanging_fern", "吊掛蕨", C7, 1, 16, 26, wall=True)
def _(c, f):
    R(c, 7, 0, 8, 2, "silver"); circle(c, 7.5, 6, 5, "birch", 3); R(c, 3, 6, 12, 7, "birch_d")
    for x, top, h in ((3, 8, 14), (6, 8, 17), (9, 8, 12), (12, 8, 15)):
        for y in range(top, top + h):
            c.put(x + (y // 4) % 2, y, "leaf" if y % 3 else "leaf_l"); c.put(x - 1 + (y // 4) % 2, y, "leaf_d") if y % 4 == 0 else None


@item("elf_moon_goddess", "月神雕像", C8, 4, 26, 46)
def _(c, f):
    R(c, 3, 38, 22, 45, "marble"); R(c, 3, 38, 22, 38, "white"); R(c, 22, 39, 22, 45, "marble_d")
    circle(c, 12.5, 8, 4, "marble"); R(c, 8, 4, 17, 13, "marble_d"); circle(c, 12.5, 8, 3.4, "marble")
    for y in range(13, 38):
        w = 3 + (y - 13) // 4
        R(c, 12.5 - w, y, 12.5 + w, y, "marble"); c.put(12.5 + w, y, "marble_d")
    R(c, 17, 9, 19, 16, "marble"); circle(c, 20, 6, 3, "moon"); circle(c, 21.5, 5, 2.5, None)
    c.cells([(10, 20), (11, 26), (14, 30), (13, 22)], "marble_d")


@item("elf_white_stag", "白鹿雕像", C8, 4, 38, 38)
def _(c, f):
    R(c, 4, 31, 33, 37, "marble"); R(c, 4, 31, 33, 31, "white")
    R(c, 9, 15, 26, 22, "marble"); R(c, 9, 21, 26, 22, "marble_d")
    for x in (10, 14, 21, 25):
        R(c, x, 23, x + 1, 30, "marble")
    R(c, 25, 7, 29, 15, "marble"); R(c, 27, 5, 32, 9, "marble"); c.put(31, 7, "night"); c.put(29, 6, "night")
    for (x, y) in ((27, 4), (26, 2), (25, 0), (28, 2), (30, 3), (31, 1), (32, 0), (29, 0)):
        c.put(x, y, "silver_d")
    R(c, 7, 14, 9, 16, "marble")


@item("elf_crystal_sapling", "水晶小樹", C8, 1, 16, 20, 2, 2)
def _(c, f):
    R(c, 3, 16, 12, 19, "marble_d"); R(c, 7, 9, 8, 15, "silver_d")
    for (x, y) in ((7, 2), (5, 4), (9, 3), (4, 7), (10, 6), (7, 6), (6, 9), (9, 9)):
        R(c, x, y, x + 1, y + 1, "ice" if (x + y + f) % 2 else "moon_d")
    c.put(8, 4, "glow" if f else "white")


@item("elf_harp", "豎琴", C9, 2, 22, 32)
def _(c, f):
    R(c, 3, 2, 5, 29, "gold"); R(c, 3, 2, 19, 4, "gold"); R(c, 17, 4, 19, 8, "gold")
    for i in range(14):
        c.put(18 - i // 3, 8 + i, "gold_d"); c.put(19 - i // 3, 8 + i, "gold")
    for x in range(6, 17, 2):
        R(c, x, 5, x, 26 - (x - 6), "silver")
    R(c, 2, 29, 16, 31, "wood_d"); c.cells([(4, 9), (4, 17), (4, 24)], "leaf"); c.put(18, 3, "pink")


@item("elf_vine_swing", "藤蔓鞦韆", C9, 2, 26, 34, 2, 2)
def _(c, f):
    R(c, 0, 0, 25, 2, "wood"); blob(c, 5, 2, 4, "leaf", "leaf_d", "leaf_l", 2); blob(c, 20, 2, 4, "leaf", "leaf_d", "leaf_l", 2)
    sw = f
    for x in (5, 20):
        for y in range(3, 28):
            c.put(x + (sw if y > 15 else 0), y, "leaf_d")
        c.cells([(x - 1, 10), (x + 1, 18)], "pink")
    R(c, 3 + sw, 28, 22 + sw, 29, "birch"); R(c, 3 + sw, 30, 22 + sw, 30, "birch_d")


@item("elf_tea_blanket", "林間茶席", C9, 2, 34, 20)
def _(c, f):
    R(c, 1, 8, 32, 19, "cloth"); R(c, 1, 8, 32, 8, "white")
    for x in range(1, 33, 4):
        R(c, x, 9, x + 1, 19, "leaf_l")
    R(c, 6, 5, 12, 9, "white"); R(c, 12, 6, 13, 7, "white"); R(c, 7, 4, 10, 4, "leaf"); R(c, 17, 7, 20, 9, "white"); R(c, 23, 7, 26, 9, "white")
    circle(c, 29, 7, 2, "red")


@item("elf_spring_basin", "清泉飲水台", C10, 2, 24, 30, 3, 4)
def _(c, f):
    R(c, 6, 18, 17, 29, "marble"); R(c, 6, 18, 17, 18, "white"); R(c, 17, 19, 17, 29, "marble_d")
    circle(c, 11.5, 17, 9, "marble_d", 3); circle(c, 11.5, 16, 8, "water", 2)
    R(c, 9, 2, 14, 12, "marble"); R(c, 10, 1, 13, 1, "white"); c.cells([(11, 5), (12, 5)], "leaf")
    for y in range(9 + f % 2, 16, 2):
        c.put(11, y, "water_l")
    R(c, 10, 8, 13, 8, "marble_d"); c.cells([(4 + f * 3, 16)], "water_l")


@item("elf_honey_shelf", "蜂蜜罐架", C10, 1, 18, 22)
def _(c, f):
    R(c, 1, 10, 16, 11, "birch"); R(c, 1, 20, 16, 21, "birch"); R(c, 1, 10, 1, 21, "birch_d"); R(c, 16, 10, 16, 21, "birch_d")
    for x in (3, 9):
        R(c, x, 4, x + 5, 9, "gold"); R(c, x, 3, x + 5, 3, "cloth"); c.put(x + 1, 5, "gold_l")
        R(c, x, 14, x + 5, 19, "gold_d"); R(c, x, 13, x + 5, 13, "leaf"); c.put(x + 1, 15, "gold")


@item("elf_fruit_table", "果實長桌", C10, 4, 42, 26)
def _(c, f):
    table(c, 1, 9, 40, 25, wood="wood", depth=4); R(c, 3, 9, 38, 12, "leaf_d")
    for i, (x, k) in enumerate(((6, "red"), (11, "purple"), (16, "orange"), (22, "green_l"), (28, "red"), (34, "gold"))):
        circle(c, x, 8, 2.4, k); c.put(x - 1, 7, "white")
    c.cells([(10, 5), (11, 4), (12, 5)], "purple"); R(c, 19, 3, 25, 7, "birch")


@item("elf_flower_arch", "花藤拱門", C11, 4, 42, 44)
def _(c, f):
    for x0 in (2, 35):
        R(c, x0, 14, x0 + 4, 43, "birch"); R(c, x0 + 4, 14, x0 + 4, 43, "birch_d")
    for a in range(0, 181, 4):
        x, y = 20.5 + 17 * math.cos(math.radians(a)), 16 - 14 * math.sin(math.radians(a))
        circle(c, x, y, 2, "birch")
    for a in range(0, 181, 10):
        x, y = 20.5 + 17 * math.cos(math.radians(a)), 16 - 14 * math.sin(math.radians(a))
        circle(c, x, y, 2.4, "leaf"); c.put(x, y, ["pink", "white", "purple_l"][a // 10 % 3])
    for y in range(18, 42, 5):
        c.cells([(2, y), (6, y + 2), (35, y + 1), (39, y + 3)], "leaf"); c.put(3, y + 1, "pink")


@item("elf_silverleaf_screen", "銀葉屏風", C11, 2, 32, 30)
def _(c, f):
    for i, x0 in enumerate((1, 11, 21)):
        yo = 0 if i % 2 == 0 else 2
        R(c, x0, 2 + yo, x0 + 9, 27 + yo, "silver_d"); R(c, x0 + 1, 3 + yo, x0 + 8, 26 + yo, "moon")
        for j in range(4):
            y = 7 + j * 5 + yo
            c.cells([(x0 + 3, y), (x0 + 4, y - 1), (x0 + 5, y - 1), (x0 + 6, y)], "silver_d")
        R(c, x0 + 4, 4 + yo, x0 + 4, 25 + yo, "silver")


@item("elf_leaf_window", "葉形窗", C11, 1, 18, 24, wall=True)
def _(c, f):
    for y in range(1, 23):
        w = min(7, y // 1.5, (23 - y) / 1.5)
        R(c, 8.5 - w, y, 8.5 + w, y, "wood")
        R(c, 8.5 - w + 1.5, y, 8.5 + w - 1.5, y, "blue_l") if w > 2 else None
    R(c, 8, 2, 9, 21, "wood"); c.cells([(5, 8), (6, 7), (11, 14)], "white")
    for y in range(6, 18, 4):
        c.put(7, y, "wood_d"); c.put(10, y + 1, "wood_d")


@item("elf_moon_pool", "月光池", C12, 4, 42, 30, 3, 3, flat=True)
def _(c, f):
    circle(c, 20.5, 15, 20, "marble_d", 14); circle(c, 20.5, 15, 18, "night", 12.5); circle(c, 20.5, 14.5, 16, "night_l", 10.5)
    circle(c, 20.5, 14, 4, "moon"); circle(c, 22, 13, 3.5, "night_l")
    for i, (x, y) in enumerate(((10, 10), (30, 18), (15, 20), (28, 9))):
        c.put(x + (f if i % 2 else -f), y, "moon")
    circle(c, 8, 18, 2.5, "leaf", 1.6); c.put(8, 17, "white"); circle(c, 33, 10, 2, "leaf", 1.4)


@item("elf_mushroom_ring", "蘑菇圈", C12, 2, 34, 18)
def _(c, f):
    for a in range(0, 360, 36):
        x, y = 16.5 + 13 * math.cos(math.radians(a)), 9 + 5 * math.sin(math.radians(a))
        circle(c, x, y - 1, 2.2, "red" if a % 72 else "cloth", 1.4); R(c, int(x), int(y), int(x), int(y) + 1, "cloth")
        c.put(int(x) - 1, int(y) - 2, "white")
    c.cells([(14, 8), (18, 10), (16, 6)], "leaf_l")


@item("elf_stone_lantern", "石燈籠", C12, 1, 16, 28, 2, 2)
def _(c, f):
    R(c, 5, 18, 10, 25, "stone"); R(c, 3, 25, 12, 27, "stone_d"); R(c, 2, 4, 13, 6, "stone"); R(c, 4, 2, 11, 3, "stone_l"); R(c, 7, 0, 8, 1, "stone")
    R(c, 4, 7, 11, 15, "stone"); R(c, 6, 9, 9, 13, "moon" if f else "f1"); R(c, 3, 16, 12, 17, "stone_l")
    c.cells([(4, 20), (11, 22), (5, 24)], "leaf")


P.update({"panther": (34, 30, 44), "panther_l": (70, 78, 104), "eye_g": (170, 236, 190)})


@item("elf_panther", "黑豹", C13, 2, 26, 18, 4, 3, note="精靈的優雅夥伴：會甩尾巴、眨眼")
def _(c, f):
    R(c, 6, 9, 19, 13, "panther"); R(c, 7, 8, 18, 8, "panther"); R(c, 8, 8, 16, 8, "panther_l")      # sleek body, moonlit back
    c.cells([(9, 9), (12, 9), (15, 9)], "panther_l")
    for x in (7, 10, 16, 18):
        R(c, x, 14, x, 16, "panther"); c.put(x, 17, "panther")
    circle(c, 21, 7, 3.6, "panther", 3.2); R(c, 22, 9, 24, 10, "panther")
    c.cells([(19, 3), (19, 4), (23, 3), (23, 4)], "panther"); c.cells([(19, 4), (23, 4)], "panther_l")
    if f == 2:
        R(c, 19, 7, 20, 7, "eye_g"); R(c, 22, 7, 23, 7, "eye_g")
    else:
        c.cells([(20, 6), (20, 7), (22, 6), (22, 7)], "eye_g"); c.cells([(20, 7), (22, 7)], "black")
    c.put(24, 9, "pink"); c.put(21, 5, "panther_l")
    tails = [[(5, 10), (4, 9), (3, 8), (3, 7), (2, 6)], [(5, 10), (4, 10), (3, 9), (2, 9), (1, 8)],
             [(5, 10), (4, 9), (3, 8), (3, 7), (2, 6)], [(5, 11), (4, 11), (3, 11), (2, 10), (1, 10)]]
    c.cells(tails[f], "panther"); c.put(*tails[f][-1], "panther_l")
    c.put(17, 12, "leaf_l"); c.put(18, 12, "silver")                          # a little silver-leaf collar charm


@item("elf_butterflies", "蝴蝶群", C13, 1, 18, 18, 4, 6)
def _(c, f):
    for i, (x, y, k) in enumerate(((4, 5, "pink"), (12, 3, "moon_d"), (9, 12, "gold"))):
        yy = y + [0, 1, 2, 1][(f + i) % 4]
        wing = (f + i) % 2
        c.put(x, yy, "black")
        c.cells([(x - 1, yy - wing), (x + 1, yy - wing), (x - 2 + wing, yy), (x + 2 - wing, yy)], k)


@item("elf_flower_fairy", "小花仙", C13, 1, 14, 18, 4, 4)
def _(c, f):
    y = [0, 1, 2, 1][f]
    circle(c, 6.5, 6 + y, 3, "skin"); R(c, 3, 3 + y, 10, 4 + y, "pink"); c.cells([(5, 6 + y), (8, 6 + y)], "black")
    R(c, 5, 9 + y, 8, 13 + y, "leaf"); R(c, 4, 13 + y, 9, 13 + y, "leaf_d")
    wing = f % 2
    c.cells([(1, 7 + y - wing), (2, 8 + y), (1, 9 + y), (12, 7 + y - wing), (11, 8 + y), (12, 9 + y)], "moon")
    c.put(6, 2 + y, "yellow")


@item("elf_white_owl", "白貓頭鷹", C13, 1, 16, 20, 3, 2)
def _(c, f):
    R(c, 2, 16, 13, 17, "birch_d"); R(c, 2, 16, 13, 16, "birch")
    circle(c, 7.5, 9, 5, "white", 6); circle(c, 7.5, 11, 3, "moon", 3)
    for x in (5, 10):
        if f == 1:
            R(c, x - 1, 7, x + 1, 7, "black")
        else:
            circle(c, x, 7, 1.5, "gold"); c.put(x, 7, "black")
    c.put(7, 9, "orange"); c.cells([(3, 2), (12, 2)], "white")
    if f == 2:
        c.cells([(1, 10), (14, 10), (1, 11), (14, 11)], "moon_d")


# ------------------------------------------------------------------------------------------------------------------ undead
RACE[0] = "undead"


@item("und_coffin_desk", "棺材辦公桌", C1, 4, 44, 26)
def _(c, f):
    R(c, 1, 8, 42, 11, "night_l"); R(c, 1, 12, 42, 24, "night"); R(c, 1, 12, 42, 12, "night_d")
    for x0 in (3, 30):
        R(c, x0, 14, x0 + 10, 23, "night_d"); R(c, x0 + 4, 16, x0 + 6, 21, "bone"); R(c, x0 + 3, 17, x0 + 7, 17, "bone")
    R(c, 1, 24, 42, 25, "black")
    circle(c, 22, 4, 3, "bone"); c.cells([(21, 4), (23, 4)], "black"); R(c, 30, 5, 31, 8, "cloth"); flame(c, 30, 4, 3, f, 0) if False else wisp_flame(c, 30, 4, 0)
    R(c, 8, 5, 14, 8, "paper"); R(c, 9, 6, 13, 6, "ink")


@item("und_bone_throne", "骨頭王座", C1, 2, 24, 36, seat=True)
def _(c, f):
    h = 36
    sy = h - 1 - SEAT_UP
    R(c, 4, 4, 19, sy, "night"); R(c, 6, 6, 17, sy - 2, "purple_d")
    for x in range(4, 20, 3):
        R(c, x, 0 + (x % 2), x + 1, 6, "bone"); c.put(x, 0 + (x % 2), "bone_d")
    circle(c, 11.5, 3, 3, "bone"); c.cells([(10, 3), (13, 3)], "black")
    for x0 in (1, 20):
        R(c, x0, 20, x0 + 2, h - 1, "bone"); circle(c, x0 + 1, 19, 2, "bone")
    R(c, 4, sy, 19, sy, "purple_l"); R(c, 4, sy + 1, 19, h - 1, "night")


@item("und_gargoyle_stool", "石像鬼凳", C1, 1, 18, 14, seat=True)
def _(c, f):
    h = 14
    sy = h - 1 - SEAT_UP
    R(c, 1, sy, 16, sy, "purple_l"); R(c, 1, sy + 1, 16, sy + 1, "purple")
    R(c, 3, 2, 14, sy - 1, "stone"); c.cells([(5, 5), (12, 5)], "wisp"); R(c, 7, 8, 10, 8, "stone_x")
    c.cells([(3, 1), (2, 0), (14, 1), (15, 0)], "stone_d"); R(c, 3, sy + 2, 4, h - 1, "stone_d"); R(c, 13, sy + 2, 14, h - 1, "stone_d")


@item("und_coffin_bookcase", "棺材書櫃", C2, 2, 26, 44)
def _(c, f):
    for y in range(1, 43):
        w = 8 + min(y, 10) // 3 - max(0, y - 12) // 10
        R(c, 12.5 - w, y, 12.5 + w, y, "night")
    for i, y in enumerate((8, 17, 26, 35)):
        R(c, 6, y, 19, y + 6, "night_d"); shelf_books(c, 6, 19, y + 6, 6, i + 5); R(c, 5, y + 7, 20, y + 7, "night_l")
    R(c, 11, 2, 14, 6, "bone"); R(c, 9, 3, 16, 4, "bone")


@item("und_urn_shelf", "骨灰罈架", C2, 2, 30, 30)
def _(c, f):
    box(c, 1, 1, 28, 29, "night", "night_l", "night_d")
    for row, y in enumerate((12, 26)):
        R(c, 3, y - 9, 26, y - 1, "night_d"); R(c, 2, y, 27, y, "night_l")
        for i, x in enumerate((5, 12, 19)):
            k = ["bone", "stone_l", "purple_l"][(i + row) % 3]
            circle(c, x + 2, y - 4, 2.6, k, 3.4); R(c, x + 1, y - 9, x + 3, y - 8, k + "_d" if k + "_d" in P else "stone_d")


@item("und_skull_rack", "骷髏衣帽架", C2, 1, 18, 36)
def _(c, f):
    R(c, 8, 8, 9, 31, "bone"); R(c, 9, 8, 9, 31, "bone_d"); R(c, 4, 31, 13, 35, "night")
    for y in range(12, 30, 3):
        R(c, 6, y, 11, y, "bone_d")                                         # a spine of ribs
    R(c, 2, 9, 15, 10, "bone"); circle(c, 8.5, 4, 4, "bone"); R(c, 6, 3, 7, 5, "black"); R(c, 10, 3, 11, 5, "black")
    c.cells([(7, 7), (9, 7)], "bone_d"); R(c, 12, 11, 16, 20, "purple_d"); R(c, 12, 11, 16, 11, "purple")


@item("und_skull_candle", "頭骨蠟燭", C3, 1, 14, 18, 3, 6)
def _(c, f):
    circle(c, 6.5, 12, 5, "bone", 4); R(c, 4, 11, 5, 13, "black"); R(c, 8, 11, 9, 13, "black"); R(c, 4, 16, 9, 17, "bone_d")
    R(c, 5, 4, 8, 8, "cloth"); c.cells([(4, 8), (9, 9), (4, 9)], "cloth"); wisp_flame(c, 6, 3, f)


@item("und_soul_jar", "魂魄瓶", C3, 1, 12, 16, 3, 4)
def _(c, f):
    R(c, 1, 3, 10, 15, "glass_d"); R(c, 2, 4, 9, 14, "night"); R(c, 2, 1, 9, 2, "bone")
    y = [0, 1, 2][f]
    circle(c, 5.5, 8 + y, 2, "wisp"); c.put(5, 7 + y, "wisp_l"); c.cells([(4, 11 + y), (6, 12)], "wisp_d")


@item("und_bone_quill", "骨頭羽毛筆", C3, 1, 14, 14)
def _(c, f):
    R(c, 2, 9, 8, 13, "black"); R(c, 3, 8, 7, 8, "bone_d"); c.put(4, 10, "purple")
    for i in range(9):
        c.put(5 + i // 2, 8 - i, "bone"); c.put(6 + i // 2, 8 - i, "bone_d")
    c.cells([(9, 0), (10, 0), (10, 1)], "bone")


@item("und_wisp_chandelier", "鬼火吊燈", C4, 4, 40, 26, 3, 4, ceiling=True)
def _(c, f):
    R(c, 19, 0, 20, 5, "iron_d"); circle(c, 19.5, 12, 17, "bone_d", 3); circle(c, 19.5, 11, 17, "bone", 2)
    for x in (5, 13, 26, 34):
        circle(c, x, 14, 1.6, "bone"); wisp_flame(c, x, 9, f + x)
    circle(c, 19.5, 15, 3, "bone"); c.cells([(18, 15), (21, 15)], "black"); R(c, 18, 18, 21, 18, "bone_d")


@item("und_black_candelabra", "黑燭台", C4, 1, 16, 24, 3, 6)
def _(c, f):
    R(c, 7, 10, 8, 21, "black"); R(c, 4, 21, 11, 23, "night"); R(c, 2, 12, 13, 12, "black"); R(c, 2, 10, 2, 11, "black"); R(c, 13, 10, 13, 11, "black")
    for x in (2, 7, 13):
        R(c, x, 6 if x == 7 else 7, x, 9, "night_l"); wisp_flame(c, x, 5 if x == 7 else 6, f + x, "purple_l") if False else flame(c, x, 5 if x == 7 else 6, 3, f + x, 0)


@item("und_wisp_lantern", "鬼火提燈", C4, 1, 12, 18, 3, 4)
def _(c, f):
    R(c, 4, 0, 7, 1, "iron_d"); R(c, 2, 2, 9, 3, "iron_d"); R(c, 2, 13, 9, 15, "iron_d")
    R(c, 3, 4, 8, 12, "night"); R(c, 2, 4, 2, 12, "iron_d"); R(c, 9, 4, 9, 12, "iron_d"); wisp_flame(c, 5, 11, f)
    R(c, 4, 16, 7, 17, "iron_d")


@item("und_tombstone_board", "墓碑白板", C5, 2, 26, 32, wall=True, note="寫完的計畫就埋在這裡")
def _(c, f):
    circle(c, 12.5, 11, 11.5, "stone", 10); R(c, 1, 11, 24, 31, "stone"); R(c, 24, 11, 24, 31, "stone_d")
    circle(c, 12.5, 12, 9, "board_d", 8); R(c, 4, 12, 21, 27, "board_d")
    R(c, 10, 5, 15, 6, "stone_l"); R(c, 6, 13, 17, 13, "chalk"); R(c, 6, 16, 19, 16, "chalk"); R(c, 6, 19, 14, 19, "chalk")
    c.cells([(6, 22), (7, 23), (8, 22), (9, 23)], "chalk"); R(c, 1, 29, 24, 31, "stone_x")


@item("und_raven_portrait", "烏鴉肖像", C5, 1, 18, 22, wall=True)
def _(c, f):
    frame_border(c, 0, 0, 17, 21, "night"); R(c, 2, 2, 15, 19, "purple_d")
    circle(c, 8, 11, 4, "black", 5); circle(c, 10, 6, 2.5, "black"); c.put(11, 5, "wisp"); R(c, 13, 6, 14, 6, "gold_d")
    R(c, 4, 15, 6, 17, "black"); c.cells([(0, 0), (17, 0), (0, 21), (17, 21)], "bone")


@item("und_bat_banner", "蝙蝠旗", C5, 1, 16, 32, wall=True)
def _(c, f):
    R(c, 1, 1, 14, 1, "iron_d"); R(c, 2, 2, 13, 25, "night"); R(c, 2, 2, 2, 25, "night_d"); R(c, 13, 2, 13, 25, "night_d")
    for i in range(4):
        R(c, 2 + i, 25 + i, 7, 25 + i, "night"); R(c, 8, 25 + i, 13 - i, 25 + i, "night")
    R(c, 6, 10, 9, 13, "purple_l"); c.cells([(4, 9), (5, 10), (3, 10), (10, 10), (11, 9), (12, 10), (4, 11), (11, 11)], "purple_l")
    c.cells([(7, 11), (8, 11)], "wisp")


@item("und_web_rug", "蜘蛛網地毯", C6, 4, 40, 30, flat=True)
def _(c, f):
    R(c, 1, 1, 38, 28, "night_d"); R(c, 2, 2, 37, 27, "night")
    for a in range(0, 360, 45):
        for r in range(1, 18):
            c.put(19.5 + r * math.cos(math.radians(a)), 14.5 + r * 0.75 * math.sin(math.radians(a)), "web")
    for r in (5, 10, 15):
        for a in range(0, 360, 6):
            c.put(19.5 + r * math.cos(math.radians(a)), 14.5 + r * 0.75 * math.sin(math.radians(a)), "web")
    circle(c, 27, 10, 1.6, "black"); c.cells([(25, 9), (29, 9), (25, 11), (29, 11)], "black")


@item("und_violet_circle", "紫色法陣地毯", C6, 2, 32, 24, 2, 2, flat=True)
def _(c, f):
    circle(c, 15.5, 11.5, 15, "black", 11); circle(c, 15.5, 11.5, 13.5, "night", 9.8)
    for a in range(0, 360, 8):
        c.put(15.5 + 12 * math.cos(math.radians(a)), 11.5 + 8.5 * math.sin(math.radians(a)), "purple_l" if f else "purple")
    for i in range(3):
        a1, a2 = math.radians(-90 + i * 120), math.radians(-90 + (i + 1) * 120)
        for t in range(10):
            tt = t / 9
            c.put(15.5 + 8 * ((1 - tt) * math.cos(a1) + tt * math.cos(a2)), 11.5 + 6 * ((1 - tt) * math.sin(a1) + tt * math.sin(a2)),
                  "wisp" if f else "wisp_d")
    circle(c, 15.5, 11.5, 1.5, "bone")


@item("und_bone_mat", "骨頭腳踏墊", C6, 1, 18, 12, flat=True)
def _(c, f):
    R(c, 0, 0, 17, 11, "night_d"); R(c, 1, 1, 16, 10, "purple_d")
    R(c, 4, 5, 13, 6, "bone"); c.cells([(3, 4), (3, 7), (14, 4), (14, 7), (2, 5), (2, 6), (15, 5), (15, 6)], "bone")


@item("und_ghost_plant", "會飄的鬼魂盆栽", C7, 1, 16, 26, 3, 3)
def _(c, f):
    pot(c, 8, 25, 10, 6, "stone"); R(c, 7, 14, 8, 19, "night_l")
    y = [0, 1, 2][f]
    for x, yy in ((5, 8), (10, 6), (8, 11)):
        circle(c, x, yy + y, 2.5, "wisp_l", 2); c.put(x, yy + 2 + y, "wisp"); c.cells([(x - 1, yy + y), (x + 1, yy + y)], "night")
    c.cells([(6, 13), (9, 12)], "night_l")


@item("und_dead_tree", "枯樹盆", C7, 2, 26, 38)
def _(c, f):
    pot(c, 13, 37, 12, 8, "stone")
    R(c, 12, 12, 14, 29, "night_l"); R(c, 14, 12, 14, 29, "night")
    for x0, y0, dx in ((12, 18, -1), (14, 15, 1), (12, 13, -1), (14, 20, 1)):
        for i in range(7):
            c.put(x0 + dx * i, y0 - i // 2 - (i // 4), "night_l")
    for x, y in ((5, 14), (21, 11), (7, 10), (19, 17)):
        c.put(x, y, "night_l"); c.put(x, y - 1, "night")
    c.put(18, 8, "black"); c.cells([(17, 8), (19, 8)], "black")


@item("und_black_rose", "黑玫瑰", C7, 1, 14, 20)
def _(c, f):
    pot(c, 7, 19, 8, 5, "night"); R(c, 6, 7, 7, 13, "green_d"); R(c, 3, 10, 5, 11, "green_d"); R(c, 8, 11, 10, 12, "green_d")
    circle(c, 6.5, 4, 3.5, "black", 3); c.cells([(5, 3), (7, 4), (6, 5)], "purple_d"); c.put(5, 2, "night_l")


@item("und_reaper_statue", "死神雕像", C8, 4, 28, 46)
def _(c, f):
    R(c, 4, 38, 23, 45, "stone"); R(c, 4, 38, 23, 38, "stone_l"); R(c, 23, 39, 23, 45, "stone_d")
    for y in range(4, 38):
        w = 3 + (y - 4) // 4
        R(c, 12.5 - w, y, 12.5 + w, y, "stone_x"); c.put(12.5 + w, y, "black")
    circle(c, 12.5, 7, 3, "black"); c.cells([(11, 7), (14, 7)], "wisp")
    R(c, 21, 2, 22, 37, "night_l"); R(c, 13, 2, 22, 3, "iron_l"); c.cells([(12, 4), (13, 4)], "iron_l")


@item("und_gargoyle", "石像鬼", C8, 2, 26, 30)
def _(c, f):
    R(c, 5, 24, 20, 29, "stone"); R(c, 5, 24, 20, 24, "stone_l")
    R(c, 9, 12, 16, 23, "stone"); circle(c, 12.5, 9, 4, "stone"); c.cells([(11, 8), (14, 8)], "wisp"); R(c, 11, 11, 14, 11, "stone_x")
    c.cells([(9, 5), (8, 4), (16, 5), (17, 4)], "stone_d")
    for i in range(8):
        R(c, 8 - i, 10 + i // 2, 8 - i // 2, 10 + i // 2, "stone_d"); R(c, 17 + i // 2, 10 + i // 2, 17 + i, 10 + i // 2, "stone_d")


@item("und_tombstone", "墓碑", C8, 1, 16, 20)
def _(c, f):
    circle(c, 7.5, 7, 6.5, "stone", 6); R(c, 1, 7, 14, 17, "stone"); R(c, 14, 7, 14, 17, "stone_d")
    R(c, 7, 4, 8, 11, "stone_x"); R(c, 5, 6, 10, 7, "stone_x"); R(c, 0, 17, 15, 19, "green_d"); c.cells([(2, 16), (12, 16)], "green")


@item("und_pipe_organ", "管風琴", C9, 4, 38, 42)
def _(c, f):
    R(c, 3, 24, 34, 41, "night"); R(c, 3, 24, 34, 25, "night_l"); R(c, 6, 28, 31, 30, "bone"); [c.put(x, 29, "black") for x in range(7, 31, 2)]
    for i, x in enumerate(range(4, 34, 3)):
        top = 2 + abs(i - 5) * 3
        R(c, x, top, x + 1, 23, "brass" if i % 2 else "brass_l"); c.put(x, top, "brass_d"); R(c, x, 20, x + 1, 20, "black")
    circle(c, 18.5, 12, 2, "bone"); c.cells([(18, 12)], "black")


@item("und_skull_chess", "骷髏棋盤", C9, 2, 24, 22)
def _(c, f):
    table(c, 2, 8, 21, 21, wood="dark", depth=4)
    for y in range(8, 12):
        for x in range(6, 18):
            if (x + y) % 2:
                c.put(x, y, "night_d")
    for x, k in ((7, "bone"), (10, "bone"), (14, "night"), (16, "night")):
        circle(c, x, 6, 1.4, k); R(c, x, 7, x, 8, k)


@item("und_coffin_sofa", "棺材沙發", C9, 2, 36, 22, seat=True)
def _(c, f):
    h = 22
    sy = h - 1 - SEAT_UP
    for x in range(2, 34):
        top = 2 + abs(x - 9) // 3 if x < 18 else 2 + abs(x - 26) // 3
        R(c, x, top, x, sy, "night")
    R(c, 4, 6, 31, sy - 1, "purple_d"); c.cells([(10, 10), (17, 10), (24, 10)], "purple")
    R(c, 2, sy, 33, sy, "purple"); R(c, 2, sy + 1, 33, h - 1, "night"); R(c, 2, h - 1, 33, h - 1, "black")


@item("und_toxic_cauldron", "綠色魔藥鍋", C10, 2, 24, 22, 3, 4)
def _(c, f):
    circle(c, 11.5, 13, 10, "black", 7); circle(c, 11.5, 12, 9.5, "night", 6); R(c, 2, 7, 21, 8, "night_l")
    R(c, 3, 8, 20, 9, "toxic"); R(c, 4, 19, 6, 21, "black"); R(c, 17, 19, 19, 21, "black")
    for i, x in enumerate((6, 11, 16)):
        if (i + f) % 3:
            circle(c, x, 7 - (i + f) % 3, 1.2, "toxic")
    c.put(10, 5, "bone"); c.put(9, 4, "bone")


@item("und_bone_teaset", "骨瓷茶具", C10, 1, 18, 12)
def _(c, f):
    R(c, 0, 9, 17, 11, "night_l")
    circle(c, 6, 5, 4, "bone", 3); R(c, 10, 4, 11, 5, "bone"); R(c, 1, 3, 2, 6, "bone"); R(c, 5, 0, 7, 1, "bone_d")
    c.cells([(4, 5), (8, 5)], "black"); R(c, 13, 6, 16, 8, "bone"); R(c, 13, 6, 16, 6, "purple")


@item("und_nightshade_cask", "夜影酒桶", C10, 2, 26, 22)
def _(c, f):
    R(c, 1, 18, 24, 21, "black")
    circle(c, 12.5, 10, 10, "night", 8); R(c, 3, 6, 22, 6, "iron_d"); R(c, 3, 14, 22, 14, "iron_d"); circle(c, 12.5, 10, 2.5, "night_l")
    R(c, 12, 10, 13, 13, "bone"); c.put(13, 15, "purple_l"); circle(c, 6, 10, 1.4, "bone"); c.cells([(5, 10)], "black")


@item("und_crypt_door", "墓穴門", C11, 2, 28, 42, wall=True)
def _(c, f):
    R(c, 1, 6, 26, 41, "stone"); circle(c, 13.5, 10, 12.5, "stone", 9)
    circle(c, 13.5, 12, 9, "night", 8); R(c, 5, 12, 22, 41, "night")
    R(c, 13, 6, 14, 41, "black"); c.cells([(10, 24), (17, 24)], "iron_l")
    circle(c, 13.5, 3, 2.5, "bone"); c.cells([(12, 3), (15, 3)], "black"); R(c, 0, 40, 27, 41, "stone_x")


@item("und_gothic_window", "哥德尖窗", C11, 2, 22, 36, wall=True)
def _(c, f):
    for y in range(0, 36):
        w = min(10, y * 0.9)
        R(c, 10.5 - w, y, 10.5 + w, y, "stone")
    for y in range(4, 33):                                                # glass inside the pointed arch
        w = min(10, (y - 2) * 0.9) - 2
        if w > 0:
            R(c, 10.5 - w, y, 10.5 + w, y, "purple_d" if (y // 5) % 2 else "night_l")
    R(c, 10, 3, 11, 33, "stone"); R(c, 2, 18, 19, 18, "stone")
    circle(c, 10.5, 10, 2, "stone"); c.put(10, 10, "wisp"); circle(c, 15, 26, 2, "moon_d") if False else None
    R(c, 0, 33, 21, 35, "stone_d")


@item("und_spike_fence", "尖刺鐵欄", C11, 2, 32, 26)
def _(c, f):
    R(c, 0, 8, 31, 9, "black"); R(c, 0, 20, 31, 21, "black"); R(c, 0, 23, 31, 25, "stone_d")
    for x in range(2, 31, 4):
        R(c, x, 3, x, 23, "iron_d"); c.cells([(x, 1), (x - 1, 2), (x + 1, 2)], "iron_l")
    circle(c, 15.5, 14.5, 2.5, "bone"); c.cells([(14, 14), (17, 14)], "black")


@item("und_little_graveyard", "小墓園", C12, 4, 42, 30)
def _(c, f):
    R(c, 1, 22, 40, 29, "green_d"); R(c, 1, 22, 40, 23, "green")
    for x, h in ((5, 14), (17, 17), (30, 13)):
        circle(c, x + 3, 22 - h + 3, 3.5, "stone", 3); R(c, x, 22 - h + 3, x + 6, 23, "stone"); R(c, x + 6, 22 - h + 3, x + 6, 23, "stone_d")
        R(c, x + 3, 22 - h + 1, x + 3, 22 - h + 6, "stone_x")
    R(c, 25, 4, 26, 22, "night_l"); c.cells([(24, 6), (23, 5), (27, 8), (28, 7)], "night_l")
    R(c, 1, 26, 40, 26, "black")


@item("und_wisp_lamppost", "鬼火燈柱", C12, 1, 14, 42, 3, 4)
def _(c, f):
    R(c, 6, 12, 7, 38, "black"); R(c, 4, 38, 9, 41, "night"); R(c, 3, 2, 10, 3, "black"); R(c, 5, 0, 8, 1, "black")
    R(c, 3, 4, 10, 10, "night"); R(c, 3, 4, 3, 10, "black"); R(c, 10, 4, 10, 10, "black"); R(c, 3, 11, 10, 11, "black")
    wisp_flame(c, 6, 9, f); c.cells([(1, 14), (12, 16)], "bone") if False else None


@item("und_soul_fountain", "魂泉", C12, 4, 42, 34, 3, 4)
def _(c, f):
    circle(c, 20.5, 25, 20, "stone_x", 8); circle(c, 20.5, 24, 19, "stone", 7); circle(c, 20.5, 24, 16, "wisp_d", 5); circle(c, 20.5, 24, 13, "wisp", 3.5)
    R(c, 18, 9, 23, 23, "stone"); R(c, 23, 9, 23, 23, "stone_d"); circle(c, 20.5, 7, 4, "bone"); c.cells([(19, 7), (22, 7)], "black")
    for i, (dx, top) in enumerate(((-4, 3), (4, 3))):
        for y in range(top + (f + i) % 2, 10):
            c.put(20 + dx, y + 2, "wisp_l")
    for x in range(9 + f * 3, 33, 9):
        c.put(x, 24, "wisp_l")


@item("und_bat", "倒掛蝙蝠", C13, 1, 14, 16, 4, 4, ceiling=True)
def _(c, f):
    R(c, 6, 0, 7, 1, "iron_d")
    if f < 2:
        R(c, 5, 2, 8, 9, "black"); c.cells([(5, 8), (8, 8)], "wisp"); R(c, 4, 3, 4, 8, "night"); R(c, 9, 3, 9, 8, "night")
        c.cells([(5, 10), (8, 10)], "black") if f else None
    else:
        y = 6 if f == 2 else 8
        circle(c, 6.5, y, 2, "black"); c.cells([(5, y), (8, y)], "wisp")
        wing = [(1, y - 2), (2, y - 1), (3, y), (4, y), (12, y - 2), (11, y - 1), (10, y), (9, y)] if f == 2 else \
               [(1, y + 1), (2, y + 1), (3, y), (4, y), (12, y + 1), (11, y + 1), (10, y), (9, y)]
        c.cells(wing, "black")


@item("und_will_o_wisp", "鬼火", C13, 1, 12, 16, 4, 4)
def _(c, f):
    y = [0, 1, 2, 1][f]
    circle(c, 5.5, 9 + y, 3.5, "wisp"); circle(c, 5.5, 10 + y, 2, "wisp_l")
    for i in range(3):
        c.put(5 + [0, 1, 0, -1][(f + i) % 4], 5 - i + y, "wisp")
    c.cells([(4, 9 + y), (7, 9 + y)], "night")


@item("und_black_cat", "黑貓", C13, 1, 18, 16, 4, 3)
def _(c, f):
    circle(c, 8, 11, 6, "black", 4); circle(c, 13, 6, 3.5, "black", 3); c.cells([(11, 2), (11, 3), (15, 2), (15, 3)], "black")
    if f == 2:
        R(c, 12, 6, 14, 6, "wisp_d")
    else:
        c.cells([(12, 6), (14, 6)], "wisp")
    tail = [[(2, 9), (1, 8), (1, 7)], [(2, 9), (1, 9), (0, 8)], [(2, 9), (1, 8), (1, 7)], [(2, 10), (1, 10), (0, 11)]][f]
    c.cells(tail, "black"); R(c, 4, 15, 12, 15, "black"); c.put(13, 8, "purple_l")


@item("und_little_ghost", "小幽靈", C13, 1, 14, 18, 4, 4)
def _(c, f):
    y = [0, 1, 2, 1][f]
    circle(c, 6.5, 6 + y, 5, "white", 4.5); R(c, 2, 6 + y, 11, 13 + y, "white")
    for x in range(2, 12):
        if (x + f) % 3 != 0:
            c.put(x, 14 + y, "white")
    R(c, 11, 7 + y, 11, 13 + y, "web"); c.cells([(5, 6 + y), (8, 6 + y)], "night"); c.cells([(6, 9 + y), (7, 9 + y)], "night")
    c.cells([(3, 8 + y), (10, 8 + y)], "pink")


RACE[0] = None


# ===========================================================================================================================
# output
# ===========================================================================================================================
CATS = [C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13]
SIZE_NAME = {1: "小", 2: "中", 4: "大"}


def render(it):
    frames = []
    for f in range(it.frames):
        c = Canvas(it.w, it.h)
        it.draw(c, f)
        c.outline()
        img = Image.new("RGBA", (it.w, it.h), (0, 0, 0, 0))
        for y in range(it.h):
            for x in range(it.w):
                k = c.px[y][x]
                if k is not None:
                    img.putpixel((x, y), tuple(P[k]) + (255,))
        frames.append(img)
    strip = Image.new("RGBA", (it.w * it.frames, it.h), (0, 0, 0, 0))
    for i, im in enumerate(frames):
        strip.alpha_composite(im, (i * it.w, 0))
    return strip, frames


def overview(rendered, scale=3, width=1900, title=None, max_h=2400):
    """Grouped by category; every item at x3 (animated ones show all frames) with its name and size under it."""
    oak = Image.open(OAK).convert("RGBA")
    font = lambda s: ImageFont.truetype(FONT, s)  # noqa: E731
    pages, page, y, d = [], None, 0, None
    pad, label_h, head_h = 14, 34, 46

    def new_page():
        img = Image.new("RGBA", (width, max_h), (0, 0, 0, 255))
        t = oak.resize((oak.width * scale, oak.height * scale), Image.NEAREST)
        for yy in range(0, img.height, t.height):
            for xx in range(0, width, t.width):
                img.alpha_composite(t, (xx, yy))
        return img

    def flush():
        if page is not None:
            pages.append(page.crop((0, 0, width, y + 10)))

    page = new_page(); d = ImageDraw.Draw(page)
    d.text((16, 12), title or f"公會共用裝飾 總覽（{len(rendered)} 樣；×{scale}；小=1 點、中=2 點、大=4 點）", font=font(30), fill=(50, 30, 15),
           stroke_width=3, stroke_fill=(250, 236, 210))
    y = 60
    for cat in CATS:
        items = [(it, fr) for it, fr in rendered if it.cat == cat]
        rows, row, rx = [], [], 16
        for it, fr in items:
            w = max(it.w * scale * len(fr) + (len(fr) - 1) * 6, 90)
            if rx + w > width - 16:
                rows.append(row); row, rx = [], 16
            row.append((it, fr, w)); rx += w + pad
        rows.append(row)
        need = head_h + sum(max(it.h * scale for it, _, _ in r) + label_h + pad for r in rows)
        if y + need > max_h - 20:
            flush(); page = new_page(); d = ImageDraw.Draw(page); y = 16
        d.rectangle([10, y + 4, width - 10, y + 6], fill=(120, 80, 40))
        d.text((16, y + 10), f"{cat}（{len(items)}）", font=font(28), fill=(50, 30, 15), stroke_width=3, stroke_fill=(250, 236, 210))
        y += head_h
        for r in rows:
            rh = max(it.h * scale for it, _, _ in r)
            x = 16
            for it, fr, w in r:
                fx = x + (w - (it.w * scale * len(fr) + (len(fr) - 1) * 6)) // 2
                for im in fr:
                    big = im.resize((it.w * scale, it.h * scale), Image.NEAREST)
                    page.alpha_composite(big, (fx, y + rh - big.height))
                    fx += big.width + 6
                tag = f"{SIZE_NAME[it.size]}·{it.size}" + (f"·{it.frames}格" if it.frames > 1 else "") + ("·牆" if it.wall else "") + \
                      ("·可坐" if it.seat else "") + ("·天花板" if it.ceiling else "")
                d.text((x + w // 2, y + rh + 3), it.name, font=font(17), fill=(40, 24, 12), anchor="ma", stroke_width=2,
                       stroke_fill=(250, 236, 210))
                d.text((x + w // 2, y + rh + 21), tag, font=font(13), fill=(90, 60, 34), anchor="ma", stroke_width=2,
                       stroke_fill=(250, 236, 210))
                x += w + pad
            y += rh + label_h + pad
    flush()
    return pages


def overview_compact(rendered, title, scale=3, width=1900):
    """For the race sets (few items per category): category groups flow side by side, each with its label above."""
    oak = Image.open(OAK).convert("RGBA")
    font = lambda s: ImageFont.truetype(FONT, s)  # noqa: E731
    gap, label_h, head_h, pad = 14, 34, 40, 30
    groups = []
    for cat in CATS:
        items = [(it, fr) for it, fr in rendered if it.cat == cat]
        if not items:
            continue
        cells = []
        for it, fr in items:
            w = max(it.w * scale * len(fr) + (len(fr) - 1) * 6, 90)
            cells.append((it, fr, w))
        gw = max(sum(w for *_, w in cells) + gap * (len(cells) - 1), 200)
        gh = max(it.h * scale for it, _, _ in cells)
        groups.append((cat, cells, gw, gh))
    rows, row, x = [], [], 16
    for g in groups:
        if x + g[2] > width - 16 and row:
            rows.append(row); row, x = [], 16
        row.append(g); x += g[2] + pad
    rows.append(row)
    height = 70 + sum(head_h + max(g[3] for g in r) + label_h + 24 for r in rows)
    img = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    t = oak.resize((oak.width * scale, oak.height * scale), Image.NEAREST)
    for yy in range(0, height, t.height):
        for xx in range(0, width, t.width):
            img.alpha_composite(t, (xx, yy))
    d = ImageDraw.Draw(img)
    d.text((16, 12), title, font=font(30), fill=(50, 30, 15), stroke_width=3, stroke_fill=(250, 236, 210))
    y = 64
    for r in rows:
        rh = max(g[3] for g in r)
        x = 16
        for cat, cells, gw, gh in r:
            d.rectangle([x, y + 34, x + gw, y + 35], fill=(120, 80, 40))
            d.text((x, y + 2), f"{cat}（{len(cells)}）", font=font(24), fill=(50, 30, 15), stroke_width=3, stroke_fill=(250, 236, 210))
            cx = x
            for it, fr, w in cells:
                fx = cx + (w - (it.w * scale * len(fr) + (len(fr) - 1) * 6)) // 2
                for im in fr:
                    big = im.resize((it.w * scale, it.h * scale), Image.NEAREST)
                    img.alpha_composite(big, (fx, y + head_h + rh - big.height))
                    fx += big.width + 6
                tag = f"{SIZE_NAME[it.size]}·{it.size}" + (f"·{it.frames}格" if it.frames > 1 else "") + ("·牆" if it.wall else "") + \
                      ("·可坐" if it.seat else "") + ("·天花板" if it.ceiling else "")
                d.text((cx + w // 2, y + head_h + rh + 3), it.name, font=font(17), fill=(40, 24, 12), anchor="ma", stroke_width=2,
                       stroke_fill=(250, 236, 210))
                d.text((cx + w // 2, y + head_h + rh + 21), tag, font=font(13), fill=(90, 60, 34), anchor="ma", stroke_width=2,
                       stroke_fill=(250, 236, 210))
                cx += w + gap
            x += gw + pad
        y += head_h + rh + label_h + 24
    return img


def main():
    ids = [it.id for it in ITEMS]
    assert len(ids) == len(set(ids)), "duplicate ids"
    os.makedirs(OUTDIR, exist_ok=True)
    for old in os.listdir(OUTDIR):                                       # strips of items that were dropped
        if old.endswith(".png") and old[:-4] not in set(ids):
            os.remove(os.path.join(OUTDIR, old))
    rendered, catalog = [], []
    for it in ITEMS:
        strip, frames = render(it)
        strip.save(os.path.join(OUTDIR, f"{it.id}.png"), optimize=True)
        rendered.append((it, frames))
        e = {"id": it.id, "name": it.name, "category": it.cat, "size": it.size, "w": it.w, "h": it.h, "frames": it.frames}
        if it.frames > 1:
            e["fps"] = it.fps
        if it.wall:
            e["wall"] = True
        if it.flat:
            e["flat"] = True
        if it.seat:
            e["seat"] = seat_info(it.w, it.h)
        if it.ceiling:
            e["ceiling"] = True
        if it.race:
            e["race"] = it.race
        e["file"] = f"decor/{it.id}.png"
        e["note"] = it.note
        catalog.append(e)
    with open(CATALOG, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=1)
        f.write("\n")
    os.makedirs(DOCS, exist_ok=True)
    for old in os.listdir(DOCS):
        if old.startswith("decor_shared_overview"):
            os.remove(os.path.join(DOCS, old))
    shared = [(it, fr) for it, fr in rendered if it.race is None]
    pages = overview(shared)
    for i, p in enumerate(pages):
        p.save(os.path.join(DOCS, f"decor_shared_overview_{i + 1}.png"))
    names = {"goblin": "哥布林", "elf": "精靈", "undead": "死靈"}
    for race, rname in names.items():
        mine = [(it, fr) for it, fr in rendered if it.race == race]
        img = overview_compact(mine, f"{rname}套組 總覽（{len(mine)} 樣；×3；公會裡有{rname}就解鎖）")
        for old in os.listdir(DOCS):
            if old.startswith(f"decor_{race}_overview"):
                os.remove(os.path.join(DOCS, old))
        img.save(os.path.join(DOCS, f"decor_{race}_overview.png"))
    for race in (None, "goblin", "elf", "undead"):
        its = [it for it in ITEMS if it.race == race]
        print(race or "shared", len(its), {c: sum(1 for it in its if it.cat == c) for c in CATS})


if __name__ == "__main__":
    main()
