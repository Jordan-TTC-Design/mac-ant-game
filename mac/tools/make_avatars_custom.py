#!/usr/bin/env python3
"""PREVIEW ONLY: the guild avatar's character creator (捏臉, GUILD.md section 2), drawn as separate layers.

Layers, composited bottom to top (each is its own grid with its own palette, so a part can be swapped or recoloured alone):

    back_hair, cape_back                  long hair / tails / buns behind the head, the back panel of a cape
    body                                  skin: face shape, ears, nose, blush, arms, legs (spirit tail, skeleton bones)
    bottom, top, shoes                    clothes (the approved default outfits, cut out of make_avatars_preview's art)
    brows, eyes, mouth                    each with open / closed / happy states (blink and happy faces keep working)
    front_hair                            fringe and top; a flattened copy (nothing above the hat brim) under headwear
    headwear, cape_front, held            hat, cape clasp, a held mug

The single dark outline is drawn once around the finished composite, like the rest of the game's sprites.
A default spec reproduces the approved six avatars pixel for pixel (checked in main()).

    python3 make_avatars_custom.py          # writes avatars_custom_preview.png into docs/images/guild/
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_avatars_preview as pv  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "images", "guild", "avatars_custom_preview.png")
W = pv.W
OY = 4                          # head top is row OY + 3; room above for topknots, flame hair and hats
HH = pv.H + OY                  # 34 rows; feet on row OY + 26
LAYERS = ["back_hair", "cape_back", "body", "bottom", "top", "shoes", "brows", "eyes", "mouth",
          "front_hair", "headwear", "cape_front", "held"]
BASE = {("goblin", "m"): "gob_m", ("goblin", "f"): "gob_f", ("elf", "m"): "elf_m", ("elf", "f"): "elf_f",
        ("bone", "m"): "und_m", ("spirit", "f"): "und_f"}
AVB = {a["id"]: a for a in pv.AVATARS}


# --- colours ------------------------------------------------------------------------------------------------------------
def tone(s, S=None, x=None):
    """A skin tone: base, shade, light (shade and light derived when not given)."""
    S = S or tuple(int(c * 0.74) for c in s)
    x = x or tuple(min(255, int(c + (255 - c) * 0.45)) for c in s)
    return {"s": s, "S": S, "x": x}


SKINS = {
    "goblin": [("淺綠", tone((136, 200, 88))), ("草綠", tone((109, 179, 63), (76, 134, 44), (154, 212, 98))),
               ("苔綠", tone((86, 150, 62))), ("深綠", tone((64, 118, 56)))],
    "elf": [("白皙", tone((250, 226, 204), (226, 192, 166), (255, 240, 226))), ("暖膚", tone((240, 208, 178))),
            ("小麥", tone((220, 176, 134))), ("古銅", tone((186, 136, 98)))],
    "bone": [("骨白", tone((240, 236, 222), (196, 190, 172), (255, 252, 244))), ("象牙", tone((232, 218, 186))),
             ("灰骨", tone((206, 204, 200))), ("石灰", tone((166, 168, 174)))],
    "spirit": [("淡藍", tone((232, 242, 252), (196, 212, 238), (255, 255, 255))), ("冰藍", tone((214, 238, 248))),
               ("淡紫", tone((234, 226, 252))), ("薰衣草", tone((210, 198, 244)))],
}
DEFAULT_SKIN = {"goblin": 1, "elf": 0, "bone": 0, "spirit": 0}

HAIR_COLOURS = [  # name, H, J (shade), h (light)
    ("黑", (54, 48, 62), (34, 30, 42), (96, 90, 108)),
    ("深棕", (70, 46, 32), (46, 30, 22), (112, 78, 52)),
    ("栗色", (150, 100, 52), (112, 70, 36), (196, 146, 84)),
    ("橘紅", (214, 96, 52), (168, 62, 36), (246, 144, 88)),
    ("薑黃", (222, 150, 58), (176, 108, 38), (248, 194, 112)),
    ("淡金", (242, 230, 172), (206, 186, 118), (255, 252, 224)),
    ("銀白", (222, 226, 234), (176, 180, 198), (252, 253, 255)),
    ("粉紅", (240, 150, 180), (198, 104, 140), (255, 198, 216)),
    ("薰衣草", (176, 150, 222), (134, 110, 188), (216, 198, 246)),
    ("薄荷", (128, 214, 214), (84, 166, 186), (200, 250, 246)),
    ("深藍", (70, 98, 172), (48, 66, 128), (112, 142, 212)),
    ("森綠", (72, 132, 82), (48, 96, 58), (112, 172, 112)),
]
HC = {n: (H, J, h) for n, H, J, h in HAIR_COLOURS}
FLAMES = [("青", (120, 240, 220)), ("紫", (200, 140, 255)), ("綠", (150, 240, 110)), ("橘", (255, 170, 80))]
OUTLINE = {"goblin": (31, 43, 20), "elf": (58, 42, 38), "bone": (34, 30, 46), "spirit": (62, 58, 104)}
ACCENTS = {"A": (250, 212, 90), "a": (255, 255, 255), "l": (90, 160, 80), "k": (232, 150, 170), "Z": (224, 255, 248),
           "f": (120, 236, 214), "T": (178, 160, 228), "U": (138, 120, 198), "n": (150, 140, 120), "N": (206, 198, 176),
           "C": (98, 84, 148), "c": (66, 56, 108), "v": (132, 120, 184), "d": (40, 34, 54), "b": (170, 120, 60)}
HAT = {"F": (70, 110, 170), "f": (48, 78, 130), "L": (110, 150, 210), "B": (232, 196, 80), "X": (255, 255, 255),
       "x": (210, 200, 190), "R": (220, 70, 80)}
HELD = {"P": (250, 240, 214), "p": (210, 196, 160), "a": (150, 110, 70)}
CAPES = {"綠": ((46, 88, 76), (32, 64, 56)), "紅": ((170, 60, 70), (124, 40, 52)), "藍": ((60, 84, 150), (40, 58, 110)),
         "紫": ((110, 80, 150), (80, 56, 112))}


# --- face shapes --------------------------------------------------------------------------------------------------------
FACES = {"round": ("圓臉", {0: (8, 15), 1: (7, 16), 10: (7, 16), 11: (8, 15)}),
         "pointed": ("尖臉", {0: (8, 15), 1: (7, 16), 9: (7, 16), 10: (8, 15), 11: (9, 14)}),
         "square": ("方臉", {0: (7, 16), 11: (7, 16)})}


def head(c, y, face):
    rows = FACES[face][1]
    for r in range(12):
        x0, x1 = rows.get(r, (6, 17))
        c.rect(x0, y + 3 + r, x1, y + 3 + r, "s")
    for r in range(3, 10):                                               # shade down the right cheek
        c.put(rows.get(r, (6, 17))[1], y + 3 + r, "S")
    c.cells([(8, y + 4), (7, y + 5)], "x")


# --- eyes, brows, mouths (each: open / closed / happy) -----------------------------------------------------------------
EYES = {"round": "圓亮眼", "narrow": "細長眼", "big": "大閃眼", "dot": "豆豆眼"}
BROWS = {"none": "無眉", "soft": "淡眉", "thin": "細眉", "thick": "粗眉"}
MOUTHS = {"smile": "一字嘴", "u": "微笑嘴", "smirk": "歪嘴笑"}
BONE_MOUTHS = {"teeth": "一排牙", "grin": "咧嘴", "gap": "缺牙"}


def eyes(c, y, style, state, girl, race):
    if race == "bone":
        for x0 in (8, 14):
            if state == "happy":
                c.cells([(x0, y + 9), (x0 + 1, y + 9), (x0 - 1 if x0 == 8 else x0 + 2, y + 10)], "d")
                c.put(x0 + 2 if x0 == 8 else x0 - 1, y + 10, "d")
                continue
            c.rect(x0, y + 8, x0 + 1, y + 10, "d")
            if state == "open":
                c.put(x0 + (1 if x0 == 8 else 0), y + 9, "e")
        return
    for x0 in (8, 14):
        out = x0 - 1 if x0 == 8 else x0 + 2                              # the outer corner
        inn = x0 + 2 if x0 == 8 else x0 - 1
        if state == "closed":
            c.rect(x0, y + 10, x0 + 1, y + 10, "L")
            if girl:
                c.put(out, y + 10, "L")
            continue
        if state == "happy":
            c.cells([(x0, y + 9), (x0 + 1, y + 9), (out, y + 10), (inn, y + 10)], "L")
            continue
        if style == "round":
            c.rect(x0, y + 8, x0 + 1, y + 8, "L")
            c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I"); c.put(x0, y + 9, "w")
            if girl:
                c.put(out, y + 8, "L")
        elif style == "narrow":
            c.rect(x0, y + 9, x0 + 1, y + 9, "L"); c.put(out, y + 9, "L")
            c.rect(x0, y + 10, x0 + 1, y + 10, "i"); c.put(inn if x0 == 8 else x0, y + 10, "I") if False else None
            c.put(x0 + (1 if x0 == 8 else 0), y + 10, "I")
        elif style == "big":
            c.rect(x0, y + 8, x0 + 1, y + 8, "L"); c.put(out, y + 8, "L"); c.put(out, y + 7, "L") if girl else None
            c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I")
            c.put(x0, y + 9, "w"); c.put(x0 + 1, y + 10, "w")
        elif style == "dot":
            dx = x0 + 1 if x0 == 8 else x0
            c.rect(dx, y + 9, dx, y + 10, "L")
            if girl:
                c.put(out if x0 == 8 else x0 + 1, y + 8, "L") if False else None


def brows(c, y, style, state):
    dy = -1 if state == "happy" else 0
    if style == "soft":
        c.cells([(8, y + 7 + dy), (9, y + 7 + dy), (14, y + 7 + dy), (15, y + 7 + dy)], "S")
    elif style == "thin":
        c.cells([(8, y + 7 + dy), (9, y + 6 + dy), (14, y + 6 + dy), (15, y + 7 + dy)], "J")
    elif style == "thick":
        c.rect(7, y + 7 + dy, 9, y + 7 + dy, "J"); c.rect(14, y + 7 + dy, 16, y + 7 + dy, "J")
        c.cells([(9, y + 6 + dy), (14, y + 6 + dy)], "J")


def mouth(c, y, style, state, race, girl):
    if race == "bone":
        if state == "open":
            c.rect(10, y + 12, 13, y + 12, "d")
        if style == "grin":
            c.rect(8, y + 13, 15, y + 13, "S"); c.cells([(9, y + 13), (11, y + 13), (13, y + 13)], "s")
            c.cells([(8, y + 12), (15, y + 12)], "S")
        else:
            c.rect(9, y + 13, 14, y + 13, "S"); c.cells([(10, y + 13), (12, y + 13)], "s")
            if style == "gap":
                c.put(11, y + 13, "d")
        if state == "happy":
            c.cells([(8, y + 12), (15, y + 12)], "S")
        return
    if state == "open":
        c.rect(11, y + 12, 12, y + 13, "m")
    elif state == "happy" or style == "u":
        pts = [(10, y + 12), (11, y + 13), (12, y + 13), (13, y + 12)]
        if state == "happy" and style == "u":
            pts += [(9, y + 11), (14, y + 11)]
        if style == "smirk" and state == "happy":
            pts = [(10, y + 12), (11, y + 13), (12, y + 13), (13, y + 12), (14, y + 11)]
        c.cells(pts, "m")
    elif style == "smirk":
        c.cells([(11, y + 12), (12, y + 12), (13, y + 11)], "m")
    else:
        c.cells([(11, y + 12), (12, y + 12)], "m")
    if race == "goblin":                                                 # race trait: tusks (a single fang for girls)
        if girl:
            c.put(12, y + 13, "t")
        else:
            c.cells([(10, y + 12), (13, y + 12)], "t")


# --- hairstyles: back(c, y) and front(c, y) ------------------------------------------------------------------------------
def fake(h):
    return {"hair": h}


def pv_back(h):
    return lambda c, y: pv.hair_behind(c, fake(h), "front", y)


def pv_front(h):
    return lambda c, y: pv.hair_front(c, fake(h), y)


def none(c, y):
    pass


def long_front(c, y):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 10, y + 6, "H"); c.rect(13, y + 6, 17, y + 6, "H")
    c.cells([(6, y + 7), (6, y + 8), (6, y + 9), (17, y + 7), (17, y + 8), (17, y + 9), (7, y + 7), (16, y + 7)], "H")
    c.cells([(11, y + 5), (12, y + 5)], "J")
    c.cells([(8, y + 3), (9, y + 3), (7, y + 4)], "h")


def pigtails_front(c, y):
    pv.hair_front(c, fake("pigtails"), y)
    c.cells([(11, y + 5), (12, y + 5)], "D")


def cap_front(c, y):
    """The goblin girls' cap of hair with bangs (the twin braids' top, without the flower)."""
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(6, y + 3, 17, y + 4, "H")
    c.rect(6, y + 5, 9, y + 5, "H"); c.rect(13, y + 5, 17, y + 5, "H")
    c.cells([(6, y + 6), (7, y + 6), (16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (8, y + 6), (14, y + 6)], "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
    c.cells([(11, y + 4), (12, y + 4)], "J")


def short_front(c, y, cowlick=True):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 11, y + 6, "H"); c.cells([(16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (6, y + 8), (12, y + 6)], "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (11, y + 4)], "h")
    c.cells([(14, y + 5), (15, y + 5)], "J")
    if cowlick:
        c.cells([(10, y + 1), (11, y + 1)], "H")


def braid(c, x0, x1, y0, y1, tie="k"):
    for yy in range(y0, y1 + 1):
        c.rect(x0, yy, x1, yy, "H" if (yy - y0) % 2 == 0 else "J")
        if (yy - y0) % 2 == 0:
            c.put(x0, yy, "h")
    c.rect(x0, y1 + 1, x1, y1 + 1, tie)
    c.rect(x0, y1 + 2, x1, y1 + 2, "H")


def sides(c, y, top, bottom, x_in=(4, 6), x_out=(17, 19)):
    c.rect(x_in[0], y + top, x_in[1], y + bottom, "H"); c.rect(x_out[0], y + top, x_out[1], y + bottom, "H")
    c.cells([(x_in[0], y + bottom), (x_out[1], y + bottom), (x_in[0], y + bottom - 1), (x_out[1], y + bottom - 1)], "J")


# goblin
def mohawk_front(c, y):
    c.rect(10, y - 1, 13, y + 4, "H"); c.cells([(11, y - 2), (13, y - 2), (10, y - 2)], "H")
    c.rect(13, y, 13, y + 4, "J"); c.cells([(10, y), (10, y + 1), (11, y - 1)], "h")
    c.cells([(10, y + 5), (11, y + 5), (12, y + 5), (13, y + 5)], "H")


def topknot_front(c, y):
    c.rect(8, y + 2, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 4, "H")
    c.cells([(7, y + 5), (8, y + 5), (15, y + 5), (16, y + 5), (11, y + 5), (12, y + 5)], "H")
    c.rect(10, y - 1, 13, y + 1, "H"); c.rect(11, y - 3, 12, y - 2, "H"); c.put(12, y - 4, "H")
    c.rect(10, y + 1, 13, y + 1, "A")
    c.cells([(10, y - 1), (11, y - 3), (9, y + 3)], "h"); c.rect(13, y - 1, 13, y, "J")


def bald_front(c, y):
    c.cells([(4, y + 11), (19, y + 11), (3, y + 11), (20, y + 11)], "A")   # gold hoops in both ears
    c.cells([(2, y + 8), (21, y + 8)], "A")


def tuft_front(c, y):
    pv.hair_front(c, fake("tuft"), y)
    c.put(4, y + 11, "A")                                                # the default earring


def bun_front(c, y):
    cap_front(c, y)
    c.rect(10, y - 1, 13, y + 1, "H"); c.rect(11, y - 2, 12, y - 2, "H")
    c.cells([(10, y - 1), (11, y - 2)], "h"); c.rect(13, y, 13, y + 1, "J")
    c.rect(10, y + 2, 13, y + 2, "A")


def dreads_back(c, y):
    for x in (4, 6, 17, 19):
        for yy in range(y + 8, y + 19):
            c.put(x, yy, "H" if (yy + x) % 3 else "J")
        c.put(x, y + 19, "A")
    c.rect(5, y + 8, 5, y + 15, "J"); c.rect(18, y + 8, 18, y + 15, "J")


def dreads_front(c, y):
    cap_front(c, y)
    for x in (7, 16):
        for yy in range(y + 6, y + 11):
            c.put(x, yy, "H" if yy % 2 else "J")
        c.put(x, y + 11, "A")


def mane_back(c, y):
    for yy in range(y + 2, y + 17):
        w = 8 if yy < y + 14 else 7 - (yy - y - 14)
        x0, x1 = 12 - w - 1, 11 + w + 1
        c.rect(max(2, x0 - (1 if yy % 3 == 0 else 0)), yy, min(21, x1 + (1 if yy % 3 == 1 else 0)), yy, "H")
    for x in range(4, 20, 3):
        c.put(x, y + 16 + (x % 2), "J")


def mane_front(c, y):
    c.rect(7, y + 2, 16, y + 2, "H"); c.rect(5, y + 3, 18, y + 5, "H")
    c.cells([(6, y + 1), (8, y + 0), (8, y + 1), (11, y + 1), (12, y + 0), (15, y + 1), (15, y + 0), (17, y + 1)], "H")
    c.cells([(5, y + 6), (6, y + 6), (8, y + 6), (9, y + 7), (14, y + 6), (15, y + 7), (17, y + 6), (18, y + 6), (5, y + 7),
             (18, y + 7), (11, y + 6)], "H")
    c.cells([(8, y + 3), (9, y + 2), (12, y + 1), (7, y + 4)], "h"); c.cells([(13, y + 4), (16, y + 5)], "J")


# elf
def long_back_m(c, y):
    sides(c, y, 9, 18)


def halfup_back(c, y):
    sides(c, y, 9, 16)
    c.rect(10, y - 1, 13, y + 1, "H"); c.rect(10, y + 1, 13, y + 1, "k"); c.put(10, y - 1, "h")


def ponytail_back(c, y):
    c.rect(11, y - 1, 14, y + 1, "H"); c.rect(11, y + 1, 14, y + 1, "k")
    c.cells([(15, y - 1), (16, y - 1), (16, y), (17, y), (18, y + 1), (18, y + 2)], "H")
    c.rect(18, y + 3, 20, y + 13, "H"); c.rect(19, y + 14, 20, y + 15, "H"); c.put(20, y + 16, "J")
    c.rect(20, y + 4, 20, y + 13, "J"); c.cells([(18, y + 5), (18, y + 9)], "h")


def crownbraid_front(c, y):
    long_front(c, y)
    c.clear([(6, y + 8), (6, y + 9), (17, y + 8), (17, y + 9)])
    for i, x in enumerate(range(6, 18)):                                 # a braid wound round like a crown
        c.put(x, y + 3, "H" if i % 2 else "J")
        c.put(x, y + 4, "J" if i % 2 else "h")
    c.cells([(5, y + 4), (18, y + 4)], "J")
    c.cells([(8, y + 2), (15, y + 2)], "a")


def crownbraid_back(c, y):
    c.rect(5, y + 7, 6, y + 11, "H"); c.rect(17, y + 7, 18, y + 11, "H")


def sidebraid_front(c, y):
    long_front(c, y)
    braid(c, 5, 7, y + 9, y + 20)


def sidebraid_back(c, y):
    c.rect(17, y + 8, 19, y + 13, "H"); c.rect(17, y + 13, 19, y + 13, "J")


def waves_back(c, y):
    sides(c, y, 9, 22, (3, 6), (17, 20))
    for yy in range(y + 10, y + 22, 4):
        c.cells([(2, yy), (21, yy + 2)], "H")
        c.cells([(5, yy + 1), (18, yy + 3)], "h")


def waves_front(c, y):
    long_front(c, y)
    c.cells([(16, y + 2), (17, y + 3), (16, y + 3)], "k")


# spirit
def flame_front(c, y):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.cells([(6, y + 6), (7, y + 6), (10, y + 6), (13, y + 6), (16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7)], "H")
    for x, top in ((7, 0), (9, -2), (11, -1), (12, -3), (14, -1), (16, 0)):    # tongues of soul fire
        c.rect(x, y + top, x, y + 2, "H"); c.put(x, y + top, "Z")
    c.cells([(10, y + 1), (13, y + 1), (8, y + 1), (15, y + 1)], "H")
    c.cells([(9, y + 1), (12, y - 1), (11, y + 2), (12, y + 2)], "h"); c.cells([(8, y + 4), (9, y + 3)], "h")


def flame_back(c, y):
    c.rect(5, y + 7, 6, y + 12, "H"); c.rect(17, y + 7, 18, y + 12, "H")
    c.cells([(5, y + 13), (18, y + 13)], "Z")


def misty_back(c, y):
    sides(c, y, 8, 21)
    for yy in range(y + 17, y + 23):                                     # fading into mist at the ends
        for x in list(range(3, 7)) + list(range(17, 21)):
            if (x + yy) % 2 == 0:
                c.put(x, yy, "Z" if yy < y + 21 else None)
            elif yy > y + 20:
                c.put(x, yy, None)


def wisps_back(c, y):
    for side in (-1, 1):
        pts = [(5, y + 6), (4, y + 7), (4, y + 8), (3, y + 9), (3, y + 10), (3, y + 11), (2, y + 12), (2, y + 13), (3, y + 14)]
        for x, yy in pts:
            xx = x if side < 0 else 23 - x
            c.put(xx, yy, "H"); c.put(xx + (1 if side < 0 else -1), yy, "H")
        tip = [(1, y + 15), (2, y + 15), (3, y + 15), (4, y + 15), (2, y + 16), (3, y + 16), (2, y + 17), (3, y + 14), (1, y + 14)]
        c.cells([(x if side < 0 else 23 - x, yy) for x, yy in tip], "f")
        c.put(3 if side < 0 else 20, y + 16, "Z")
    c.cells([(5, y + 5), (18, y + 5)], "f")                               # soul-flame ties


# bone (no hair: the hair slot holds a hood, a crack, horns, or nothing)
def hood_front(c, y):
    t = pv.C(W, HH)
    pv.hood(t, y, "front")
    for yy in range(HH):
        for x in range(W):
            k = t.px[yy][x]
            if k in ("C", "c", "v", "A") or (k == "S" and x == 16 and yy != y + 11):
                c.put(x, yy, k)


def crack_front(c, y):
    c.cells([(13, y + 3), (13, y + 4), (14, y + 5), (14, y + 6), (15, y + 7)], "d"); c.put(12, y + 5, "d")


def horns_front(c, y):
    for side in (-1, 1):
        f = (lambda x: x) if side < 0 else (lambda x: 23 - x)
        c.cells([(f(8), y + 2), (f(9), y + 2), (f(7), y + 1), (f(8), y + 1), (f(6), y + 0), (f(7), y + 0), (f(6), y - 1)], "N")
        c.cells([(f(9), y + 2), (f(8), y + 1), (f(7), y + 0)], "n")


HAIR = {
    ("goblin", "m"): [("tuft", "亂翹一撮", none, tuft_front), ("mohawk", "莫霍克", none, mohawk_front),
                      ("topknot", "沖天辮", none, topknot_front), ("bald", "光頭加耳環", none, bald_front)],
    ("goblin", "f"): [("pigtails", "雙麻花", pv_back("pigtails"), pigtails_front), ("bun", "頭頂小髻", none, bun_front),
                      ("dreads", "髒辮", dreads_back, dreads_front), ("mane", "狂野亂髮", mane_back, mane_front)],
    ("elf", "m"): [("short", "短俐落", none, pv_front("short")), ("longm", "長直髮", long_back_m, long_front),
                   ("halfup", "半紮", halfup_back, lambda c, y: short_front(c, y, False)),
                   ("ponytail", "長馬尾", ponytail_back, lambda c, y: short_front(c, y, False))],
    ("elf", "f"): [("long", "長直髮・花冠", pv_back("long"), pv_front("long")), ("crown", "編髮頭冠", crownbraid_back, crownbraid_front),
                   ("sidebraid", "側編辮", sidebraid_back, sidebraid_front), ("waves", "及腰波浪", waves_back, waves_front)],
    ("bone", "m"): [("hood", "兜帽", none, hood_front), ("bare", "光頭骨", none, none), ("crack", "頭骨裂痕", none, crack_front),
                    ("horns", "小角", none, horns_front)],
    ("spirit", "f"): [("wavy", "飄散的靈髮", pv_back("wavy"), pv_front("wavy")), ("flame", "火焰髮", flame_back, flame_front),
                      ("misty", "霧狀長髮", misty_back, long_front), ("wisps", "雙馬尾鬼火", wisps_back, long_front)],
}
DEFAULT_HAIR_COLOUR = {"gob_m": "深棕", "gob_f": "橘紅", "elf_m": "栗色", "elf_f": "淡金", "und_m": None, "und_f": "薄荷"}


def default_spec(race, sex):
    base = BASE[(race, sex)]
    a = AVB[base]
    return dict(race=race, sex=sex, face="round", eyes="round", mouth="teeth" if race == "bone" else "smile",
                brows="soft" if base == "gob_m" else "none", hair=HAIR[(race, sex)][0][0],
                colour=DEFAULT_HAIR_COLOUR[base], skin=DEFAULT_SKIN[race], flame="青",
                cape="綠" if a.get("cape") else None, hat=False, held=False)


# --- building -----------------------------------------------------------------------------------------------------------
def palettes(sp):
    base = BASE[(sp["race"], sp["sex"])]
    clothes = pv.PALS[base]
    sk = SKINS[sp["race"]][sp["skin"]][1]
    O = OUTLINE[sp["race"]]
    body = dict(clothes, **sk, O=O)
    hair = dict(ACCENTS, **sk, O=O)
    hair.update({k: clothes[k] for k in "Aalk" if k in clothes})        # ribbons, flowers, clasps match the outfit
    hair["D"] = O                                                        # a dark parting line
    if base == "und_f":
        hair.update(A=(120, 236, 214), Z=(224, 255, 248), T=clothes["T"], U=clothes["U"])
    if sp.get("colour"):
        H, J, h = HC[sp["colour"]]
        hair.update(H=H, J=J, h=h)
    face = dict(clothes, **sk, O=O)
    face["e"] = dict(FLAMES)[sp.get("flame", "青")]
    if sp.get("colour"):
        face["J"] = HC[sp["colour"]][1]
    else:
        face["J"] = sk["S"]
    cape = dict(O=O, A=(246, 206, 80))
    if sp.get("cape"):
        cape["C"], cape["c"] = CAPES[sp["cape"]]
    return {"back_hair": hair, "cape_back": cape, "body": body, "bottom": clothes, "top": clothes, "shoes": clothes,
            "brows": face, "eyes": face, "mouth": face, "front_hair": hair, "headwear": HAT, "cape_front": cape, "held": HELD}


def split_into(tmp, L, base, rule):
    a = AVB[base]
    for y in range(tmp.h):
        for x in range(tmp.w):
            k = tmp.px[y][x]
            if k is None:
                continue
            L[rule(k, a)].put(x, y, k)


def lower_rule(k, a):
    if k == "K":
        return "shoes"
    if k in ("s", "S"):
        return "body"
    if a["race"] == "skeleton" and k in ("P", "Q"):
        return "body"
    if a["outfit"] == "spirit" and k in ("Q", "q", "Z"):
        return "body"
    if a["outfit"] == "tunic" and k in ("T", "U", "u", "C", "c"):
        return "top"
    return "bottom"


def upper_rule(k, a):
    return "body" if k in ("s", "S", "x") else "top"


def build_layers(sp, phase=0, eye="open", mouth_state="closed", sit=False, swing=0, flatten=None, bob=None):
    """Returns {layer: canvas}. `flatten` swaps in the flattened front/back hair (automatic when wearing a hat)."""
    race, sex = sp["race"], sp["sex"]
    base = BASE[(race, sex)]
    a = AVB[base]
    girl = sex == "f"
    if bob is None:
        bob = 1 if (a["outfit"] == "spirit" and phase in (1, 2) and not sit) else 0
    oy = OY - bob
    u = oy + (pv.SIT_DROP if sit else 0)
    L = {n: pv.C(W, HH) for n in LAYERS}
    style = {s[0]: s for s in HAIR[(race, sex)]}[sp["hair"]]
    flat = sp.get("hat") if flatten is None else flatten
    # back hair, cape back
    style[2](L["back_hair"], u)
    if sp.get("cape"):
        L["cape_back"].rect(6, u + 15, 17, u + 22, "C"); L["cape_back"].rect(6, u + 22, 17, u + 22, "c")
    # body: skin under everything
    b = L["body"]
    pv.ears(b, {"ears": a["ears"]}, "front", u)
    head(b, u, sp["face"])
    if race == "goblin":
        b.cells([(11, u + 11), (12, u + 11)], "S")
    if race == "bone":
        b.cells([(11, u + 11), (12, u + 11)], "d")
    b.cells([(7, u + 11), (16, u + 11)], "p")
    sw = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    for x0, s in ((6, sw), (16, -sw)):
        b.rect(x0, u + 16 + s, x0 + 1, u + 21 + s, "s")
    if race not in ("bone", "spirit"):
        b.rect(8, u + 15, 15, u + 22, "s")
        if not sit:
            for x, lift in ((9, 1 if phase == 1 else 0), (13, 1 if phase == 3 else 0)):
                b.rect(x, oy + 23, x + 1, oy + 26 - lift, "s")
    # clothes (and the visible bits of legs / tail) from the approved art, cut into layers
    t = pv.C(W, HH)
    if sit:
        pv.sit_legs_front(t, a, oy, swing)
    else:
        pv.legs_front(t, a, oy, phase)
    split_into(t, L, base, lower_rule)
    t = pv.C(W, HH)
    plain = dict(a, cape=False)
    pv.torso_front(t, plain, u)
    pv.arms_front(t, plain, u, phase)
    split_into(t, L, base, upper_rule)
    # face parts
    brows(L["brows"], u, sp["brows"], eye)
    eyes(L["eyes"], u, sp["eyes"], eye, girl, race)
    mouth(L["mouth"], u, sp["mouth"], mouth_state, race, girl)
    # front hair
    style[3](L["front_hair"], u)
    if flat:                                                             # flattened: nothing above the hat brim
        for yy in range(0, u + 6):
            for x in range(W):
                if L["front_hair"].px[yy][x] not in (None,) and yy < u + 6:
                    L["front_hair"].px[yy][x] = None
        for yy in range(0, u + 5):
            L["back_hair"].px[yy] = [None] * W
    if sp.get("hat"):
        hat(L["headwear"], u)
    if sp.get("cape"):
        L["cape_front"].cells([(8, u + 15), (15, u + 15)], "C"); L["cape_front"].cells([(9, u + 15), (14, u + 15)], "A")
    if sp.get("held"):
        h = L["held"]
        hy = u + 19 + (-sw if not sit else 0)
        h.rect(17, hy, 19, hy + 2, "P"); h.rect(17, hy, 19, hy, "p"); h.put(20, hy + 1, "P"); h.put(18, hy, "a")
    return L


def hat(c, y):
    """A feathered cap. Its brim is at row y + 5; the front hair under it is the flattened version."""
    c.rect(9, y + 1, 14, y + 1, "F"); c.rect(7, y + 2, 16, y + 4, "F")
    c.rect(15, y + 2, 16, y + 4, "f"); c.cells([(9, y + 2), (10, y + 2), (8, y + 3)], "L")
    c.rect(7, y + 4, 16, y + 4, "B")
    c.rect(5, y + 5, 18, y + 5, "F"); c.rect(5, y + 5, 18, y + 5, "f") if False else None
    c.cells([(5, y + 5), (18, y + 5)], "f")
    c.cells([(17, y + 3), (18, y + 2), (18, y + 1), (19, y + 0), (19, y - 1), (20, y - 2), (18, y + 0), (17, y + 2)], "X")
    c.cells([(18, y + 1), (19, y - 1)], "x"); c.put(16, y + 3, "R")


def composite(sp, L):
    pals = palettes(sp)
    grid = [[None] * W for _ in range(HH)]
    for name in LAYERS:
        c = L[name]
        for y in range(HH):
            for x in range(W):
                k = c.px[y][x]
                if k is not None:
                    grid[y][x] = (name, k)
    # one outline round the whole figure
    edge = []
    for y in range(HH):
        for x in range(W):
            if grid[y][x] is None:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < HH and grid[ny][nx] is not None:
                        edge.append((x, y))
                        break
    img = Image.new("RGBA", (W, HH), (0, 0, 0, 0))
    O = OUTLINE[sp["race"]]
    for y in range(HH):
        for x in range(W):
            g = grid[y][x]
            if g is not None:
                img.putpixel((x, y), tuple(pals[g[0]][g[1]]) + (255,))
    for x, y in edge:
        img.putpixel((x, y), O + (255,))
    return img


def render(sp, **kw):
    return composite(sp, build_layers(sp, **kw))


# --- the sheet ----------------------------------------------------------------------------------------------------------
def check_defaults():
    """The default combination must equal the approved front sprite."""
    bad = []
    for (race, sex), base in BASE.items():
        a = AVB[base]
        want = pv.front(a).image(pv.PALS[base])
        got = render(default_spec(race, sex)).crop((0, OY, W, OY + pv.H))
        diff = sum(1 for y in range(pv.H) for x in range(W) if want.getpixel((x, y)) != got.getpixel((x, y)))
        bad.append((base, diff))
    return bad


def head_crop(img):
    return img.crop((0, 0, W, OY + 20))


def face_crop(img):
    """Head only, shown at twice the size so the face parts can be compared."""
    return img.crop((1, OY - 1, W - 1, OY + 17))


RACE_SECTIONS = [
    ("哥布林", [("goblin", "m"), ("goblin", "f")]),
    ("精靈", [("elf", "m"), ("elf", "f")]),
    ("死靈", [("bone", "m"), ("spirit", "f")]),
]
SEXNAME = {("goblin", "m"): "男", ("goblin", "f"): "女", ("elf", "m"): "男", ("elf", "f"): "女",
           ("bone", "m"): "骨系・男", ("spirit", "f"): "魂系・女"}


def rows_for(race_name, kinds, rng):
    rows = []
    # 1. hairstyles
    items = []
    for rk in kinds:
        for hid, hname, _b, _f in HAIR[rk]:
            sp = default_spec(*rk)
            sp["hair"] = hid
            items.append((f"{SEXNAME[rk]}\n{hname}", render(sp)))
    rows.append(("髮型" if kinds[0][0] != "bone" else "髮型／頭部", items))
    # 2. face parts on one base
    items = []
    rk = kinds[0] if kinds[0][0] != "bone" else kinds[0]
    if rk[0] == "bone":
        for fid, (fname, _r) in FACES.items():
            sp = default_spec(*rk); sp["face"] = fid; sp["hair"] = "bare"
            items.append((fname, head_crop(render(sp))))
        for fname, _c in FLAMES:
            sp = default_spec(*rk); sp["flame"] = fname; sp["hair"] = "bare"
            items.append((f"眼火・{fname}", head_crop(render(sp))))
        for mid, mname in BONE_MOUTHS.items():
            sp = default_spec(*rk); sp["mouth"] = mid; sp["hair"] = "bare"
            items.append((mname, head_crop(render(sp))))
        rk2 = kinds[1]
        for eid, ename in EYES.items():
            sp = default_spec(*rk2); sp["eyes"] = eid
            items.append((f"魂・{ename}", head_crop(render(sp))))
    else:
        for fid, (fname, _r) in FACES.items():
            sp = default_spec(*rk); sp["face"] = fid
            items.append((fname, head_crop(render(sp))))
        for eid, ename in EYES.items():
            sp = default_spec(*rk); sp["eyes"] = eid
            items.append((ename, head_crop(render(sp))))
        for mid, mname in MOUTHS.items():
            sp = default_spec(*rk); sp["mouth"] = mid
            items.append((mname, head_crop(render(sp))))
        for bid in ("thin", "thick"):
            sp = default_spec(*rk); sp["brows"] = bid
            items.append((BROWS[bid], head_crop(render(sp))))
    rows.append(("五官・臉型", items))
    # 3. skin tones and hair colours
    items = []
    for rk in kinds:
        tones = SKINS[rk[0]]
        for i, (tname, _t) in enumerate(tones):
            sp = default_spec(*rk); sp["skin"] = i
            if rk[0] == "bone":
                sp["hair"] = "bare"
            items.append((tname, render(sp)))
        if rk[0] == "bone":
            continue
    ck = kinds[1] if kinds[0][0] == "bone" else kinds[1]
    for cname, *_ in HAIR_COLOURS:
        sp = default_spec(*ck); sp["colour"] = cname
        items.append((cname, head_crop(render(sp))))
    rows.append(("膚色・髮色", items))
    # 4. random combinations
    items = []
    for i in range(6):
        rk = kinds[i % 2]
        sp = default_spec(*rk)
        sp["hair"] = rng.choice(HAIR[rk])[0]
        sp["skin"] = rng.randrange(4)
        sp["face"] = rng.choice(list(FACES))
        if rk[0] == "bone":
            sp["mouth"] = rng.choice(list(BONE_MOUTHS)); sp["flame"] = rng.choice(FLAMES)[0]
        else:
            sp["eyes"] = rng.choice(list(EYES)); sp["mouth"] = rng.choice(list(MOUTHS))
            sp["brows"] = rng.choice(list(BROWS)); sp["colour"] = rng.choice(HAIR_COLOURS)[0]
        if rng.random() < 0.35:
            sp["cape"] = rng.choice(list(CAPES))
        if rng.random() < 0.3:
            sp["held"] = True
        items.append((f"組合 {i + 1}", render(sp)))
    rows.append(("隨機組合", items))
    return rows


def motion_rows():
    a = default_spec("goblin", "f")
    a.update(hair="bun", colour="粉紅", skin=2, face="pointed", eyes="big", mouth="u", brows="thin", held=True)
    items = [("正常", render(a)), ("眨眼", render(a, eye="closed")), ("笑眼", render(a, eye="happy", mouth_state="happy")),
             ("說話", render(a, mouth_state="open")), ("走路 1", render(a, phase=1)), ("走路 2", render(a, phase=3)),
             ("坐著", render(a, sit=True)), ("坐著・晃腳", render(a, sit=True, swing=2, eye="happy"))]
    s = default_spec("spirit", "f")
    s.update(hair="flame", colour="薰衣草", skin=3, eyes="narrow")
    items += [("魂・飄", render(s, phase=1)), ("魂・眨眼", render(s, eye="closed")), ("魂・坐著", render(s, sit=True, swing=1))]
    e = default_spec("elf", "m")
    e.update(hair="ponytail", colour="銀白", skin=2, brows="thick")
    g = default_spec("goblin", "m")
    g.update(hair="topknot", colour="森綠")
    hats = [("沒戴帽", render(g)), ("沒壓扁(穿出)", render(dict(g, hat=True), flatten=False)), ("壓扁前髮", render(dict(g, hat=True))),
            ("沒戴帽", render(e)), ("沒壓扁(穿出)", render(dict(e, hat=True), flatten=False)), ("壓扁前髮", render(dict(e, hat=True))),
            ("帽子・眨眼", render(dict(e, hat=True), eye="closed")), ("帽子・走路", render(dict(e, hat=True), phase=1)),
            ("帽子・坐著", render(dict(e, hat=True), sit=True))]
    return [("動作測試", items), ("戴帽子", hats)]


def main():
    bad = check_defaults()
    print("default vs approved (differing pixels):", bad)
    rng = random.Random(8)
    sections = [(name, rows_for(name, kinds, rng)) for name, kinds in RACE_SECTIONS]
    sections.append(("圖層測試", motion_rows()))
    label_w, gap = 70, 4
    row_h = HH + 16
    sec_h = 14
    width = 0
    for _n, rows in sections:
        for _l, items in rows:
            k = 2 if _l == "五官・臉型" else 1
            width = max(width, label_w + sum((W - 2 if k == 2 else i.width) * k + gap for _, i in items))
    width += 6
    height = 24 + sum(sec_h + row_h * len(rows) for _n, rows in sections) + 4
    art = pv.Art(width, height, scale=4, color=(228, 198, 152, 255))
    pv.wood_floor(art)
    pv.ptext(art, "公會角色 捏臉預覽：分圖層組合（後髮→身體臉型→衣服→眉眼嘴→前髮→頭飾披風手持）；選項先少、之後再加",
             6, 4, 32, (70, 44, 24, 255), stroke=(250, 236, 210, 255))
    y = 24
    for name, rows in sections:
        art.rect(2, y + 2, width - 4, 1, (150, 110, 70, 255))
        pv.ptext(art, f"【{name}】", 4, y + 4, 34, (60, 30, 14, 255), stroke=(250, 236, 210, 255))
        y += sec_h
        for label, items in rows:
            pv.ptext(art, label, 6, y + 12, 26, (60, 36, 20, 255), stroke=(250, 236, 210, 255))
            x = label_w
            big = label == "五官・臉型"
            for cap, img in items:
                if big:
                    img = face_crop(img)
                    art.sprite(img, x, y + HH - img.height * 2, scale=2, bottom_center=False)
                    pv.ptext(art, cap, x + img.width, y + HH + 1, 16, (80, 52, 30, 255), anchor="c")
                    x += img.width * 2 + gap
                    continue
                art.sprite(img, x, y + (HH - img.height), bottom_center=False)
                for i, line in enumerate(cap.split("\n")):
                    pv.ptext(art, line, x + img.width / 2, y + HH + 1 + i * 5, 16, (80, 52, 30, 255), anchor="c")
                x += img.width + gap
            y += row_h
    art.save(OUT)


if __name__ == "__main__":
    main()
