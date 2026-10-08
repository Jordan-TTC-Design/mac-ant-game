#!/usr/bin/env python3
"""PREVIEW ONLY: the six guild avatars (角色, GUILD.md section 2) - goblin, elf, undead x male, female.

Same chibi pixel style as the camp residents (mac/tools/make_goblin.py, make_elf.py, make_undead.py): one dark outline, a
big round head, one shade and one light per colour - but on a 24x30 grid instead of 16x16, so faces and hair read.

For each avatar: front idle, two front walk frames, two side walk frames, back, and sitting at a desk with a crystal-ball
computer (from the side, and from the front as seen in the top-down hall).

    python3 make_avatars_preview.py            # writes avatars_preview.png into docs/images/guild/
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelart import Art, FONT_CJK  # noqa: E402
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "images", "guild", "avatars_preview.png")
W, H = 24, 30


class C:
    def __init__(self, w=W, h=H):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def put(self, x, y, k):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = k

    def rect(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, k)

    def cells(self, pts, k):
        for x, y in pts:
            self.put(x, y, k)

    def clear(self, pts):
        for x, y in pts:
            if 0 <= x < self.w and 0 <= y < self.h:
                self.px[y][x] = None

    def outline(self):
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx] is not None:
                            edge.append((x, y))
                            break
        for x, y in edge:
            self.px[y][x] = "O"
        return self

    def image(self, pal):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                k = self.px[y][x]
                if k is not None:
                    img.putpixel((x, y), tuple(pal[k]) + (255,))
        return img


def mx(x):
    return W - 1 - x


# --- palettes ----------------------------------------------------------------------------------------------------------
GOB_SKIN = {"O": (31, 43, 20), "s": (109, 179, 63), "S": (76, 134, 44), "x": (154, 212, 98), "r": (217, 139, 150),
            "i": (245, 216, 66), "I": (196, 150, 30), "L": (21, 21, 21), "w": (255, 255, 240), "t": (243, 237, 208),
            "m": (122, 42, 42), "p": (214, 150, 110)}
ELF_SKIN = {"O": (58, 42, 38), "s": (250, 226, 204), "S": (226, 192, 166), "x": (255, 240, 226), "r": (240, 168, 170),
            "i": (52, 140, 86), "I": (30, 96, 58), "L": (60, 44, 44), "w": (255, 255, 255), "m": (200, 108, 108),
            "p": (248, 170, 170)}

PALS = {
    "gob_m": dict(GOB_SKIN, H=(70, 46, 32), J=(46, 30, 22), h=(112, 78, 52),
                  T=(154, 99, 47), U=(118, 72, 32), u=(196, 150, 90), k=(92, 56, 24), A=(232, 196, 80),
                  P=(94, 84, 70), Q=(70, 62, 52), K=(84, 56, 34)),
    "gob_f": dict(GOB_SKIN, H=(214, 96, 52), J=(168, 62, 36), h=(246, 144, 88),
                  T=(198, 92, 98), U=(156, 62, 72), u=(250, 242, 222), k=(150, 60, 70), A=(250, 212, 90), a=(255, 255, 255),
                  P=(198, 92, 98), Q=(156, 62, 72), K=(110, 70, 44)),
    "elf_m": dict(ELF_SKIN, H=(150, 100, 52), J=(112, 70, 36), h=(196, 146, 84),
                  T=(92, 150, 80), U=(62, 106, 56), u=(240, 232, 200), C=(46, 88, 76), c=(32, 64, 56), k=(96, 70, 46),
                  A=(246, 206, 80), P=(214, 196, 150), Q=(178, 158, 116), K=(110, 76, 48)),
    "elf_f": dict(ELF_SKIN, H=(242, 230, 172), J=(206, 186, 118), h=(255, 252, 224),
                  T=(140, 196, 164), U=(100, 156, 126), u=(250, 248, 236), k=(232, 150, 170), A=(248, 160, 184),
                  a=(255, 255, 255), l=(90, 160, 80), K=(150, 110, 70), P=(140, 196, 164), Q=(100, 156, 126)),
    "und_m": {"O": (34, 30, 46), "s": (240, 236, 222), "S": (196, 190, 172), "x": (255, 252, 244), "d": (40, 34, 54),
              "e": (120, 240, 220), "p": (255, 190, 200), "C": (98, 84, 148), "c": (66, 56, 108), "v": (132, 120, 184),
              "T": (70, 128, 138), "U": (50, 98, 108), "u": (200, 190, 230), "k": (60, 46, 40), "A": (120, 236, 214),
              "K": (74, 60, 66), "P": (240, 236, 222), "Q": (196, 190, 172)},
    "und_f": {"O": (62, 58, 104), "s": (232, 242, 252), "S": (196, 212, 238), "x": (255, 255, 255), "r": (210, 200, 240),
              "H": (128, 214, 214), "J": (84, 166, 186), "h": (200, 250, 246), "i": (80, 196, 214), "I": (48, 128, 168),
              "L": (54, 52, 96), "w": (255, 255, 255), "m": (204, 112, 146), "p": (250, 184, 206),
              "T": (178, 160, 228), "U": (138, 120, 198), "u": (248, 246, 255), "k": (120, 236, 214), "A": (120, 236, 214),
              "Q": (152, 236, 222), "q": (104, 194, 196), "Z": (224, 255, 248), "K": (138, 120, 198), "P": (178, 160, 228)},
}

SWING = {0: 0, 1: -1, 2: 0, 3: 1}

HEAD = {0: (8, 15), 1: (7, 16), 10: (7, 16), 11: (8, 15)}            # row offset from the top of the head -> span


def head_shape(c, oy, key="s"):
    for r in range(12):
        x0, x1 = HEAD.get(r, (6, 17))
        c.rect(x0, oy + 3 + r, x1, oy + 3 + r, key)
    c.rect(17, oy + 6, 17, oy + 12, "S")                                # shade on the right cheek
    c.cells([(8, oy + 4), (7, oy + 5)], "x")


# --- ears ---------------------------------------------------------------------------------------------------------------
def ears(c, a, view, oy):
    kind = a["ears"]
    if kind == "goblin":
        left = [(3, 7), (4, 7), (5, 7), (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), (2, 9), (3, 9), (4, 9), (5, 9), (4, 10), (5, 10)]
        inner = [(3, 8), (4, 8), (4, 9)]
    elif kind == "elf":                                                  # short, pointing out and a little down
        left = [(4, 7), (5, 7), (2, 8), (3, 8), (4, 8), (5, 8), (0, 9), (1, 9), (2, 9), (3, 9), (4, 9), (5, 9), (4, 10), (5, 10)]
        inner = [(3, 8), (4, 8), (2, 9)]
    else:
        return
    left = [(x, y + oy) for x, y in left]
    inner = [(x, y + oy) for x, y in inner]
    if view == "side":                                                   # one ear, pointing back from mid-head
        pts = [(x + 2, y) for x, y in left]
        c.cells(pts, "s")
        c.cells([(x + 2, y) for x, y in inner], "r")
        return
    c.cells(left + [(mx(x), y) for x, y in left], "s")
    c.cells(inner + [(mx(x), y) for x, y in inner], "r" if view == "front" else "S")
    if a.get("earring"):
        c.put(4, oy + 11, "A")


# --- faces --------------------------------------------------------------------------------------------------------------
def eyes_front(c, oy, girl=False, look="open"):
    for x0 in (8, 14):
        if look == "down":
            c.rect(x0, oy + 10, x0 + 1, oy + 10, "L")
            continue
        c.rect(x0, oy + 8, x0 + 1, oy + 8, "L")
        c.rect(x0, oy + 9, x0 + 1, oy + 10, "i")
        c.rect(x0, oy + 10, x0 + 1, oy + 10, "I")
        c.put(x0, oy + 9, "w")
    if girl:
        c.cells([(7, oy + 8), (16, oy + 8)], "L")


def face_front(c, a, oy, look="open"):
    race = a["race"]
    if race == "skeleton":
        for x0 in (8, 14):
            c.rect(x0, oy + 8, x0 + 1, oy + 10, "d")
            c.put(x0 + (1 if x0 == 8 else 0), oy + 9, "e" if look == "open" else "d")
        c.cells([(11, oy + 11), (12, oy + 11)], "d")
        c.rect(9, oy + 13, 14, oy + 13, "S")
        c.cells([(10, oy + 13), (12, oy + 13)], "s")
        c.cells([(7, oy + 11), (16, oy + 11)], "p")
        return
    eyes_front(c, oy, a["girl"], look)
    c.cells([(7, oy + 11), (16, oy + 11)], "p")
    if race == "goblin":
        c.cells([(11, oy + 11), (12, oy + 11)], "S")                      # a small round nose
        if a["girl"]:
            c.cells([(11, oy + 12), (12, oy + 12)], "m")
            c.put(12, oy + 13, "t")                                       # one tiny fang
        else:
            c.cells([(11, oy + 12), (12, oy + 12)], "m")
            c.cells([(10, oy + 12), (13, oy + 12)], "t")                  # little tusks
            c.cells([(8, oy + 7), (9, oy + 7), (14, oy + 7), (15, oy + 7)], "S")   # brows
    else:
        c.cells([(11, oy + 12), (12, oy + 12)], "m")


def face_side(c, a, oy, look="open"):
    race = a["race"]
    if race == "skeleton":
        c.rect(14, oy + 8, 15, oy + 10, "d")
        c.put(15, oy + 9, "e" if look == "open" else "d")
        c.put(17, oy + 11, "d")
        c.rect(13, oy + 13, 17, oy + 13, "S")
        c.cells([(14, oy + 13), (16, oy + 13)], "s")
        c.put(13, oy + 11, "p")
        return
    if look == "down":
        c.rect(14, oy + 10, 15, oy + 10, "L")
    else:
        c.rect(14, oy + 8, 15, oy + 8, "L")
        c.rect(14, oy + 9, 15, oy + 10, "i")
        c.rect(14, oy + 10, 15, oy + 10, "I")
        c.put(15, oy + 9, "w")
        if a["girl"]:
            c.put(16, oy + 8, "L")
    c.put(13, oy + 11, "p")
    c.put(16, oy + 12, "m")
    if race == "goblin":
        c.cells([(18, oy + 10), (18, oy + 11)], "s")                       # the nose, a bump in profile
        c.put(18, oy + 11, "S")
        if not a["girl"]:
            c.put(17, oy + 12, "t")
            c.cells([(14, oy + 7), (15, oy + 7)], "S")


# --- hair, hood ---------------------------------------------------------------------------------------------------------
def hair_behind(c, a, view, oy, sit=False):
    st = a["hair"]
    if st == "long" or st == "wavy":
        bottom = oy + (20 if st == "long" else 19)
        if view == "front":
            c.rect(4, oy + 9, 6, bottom, "H"); c.rect(17, oy + 9, 19, bottom, "H")
            c.cells([(4, bottom), (19, bottom), (4, bottom - 1), (19, bottom - 1)], "J")
            if st == "wavy":
                c.cells([(3, oy + 12), (3, oy + 13), (20, oy + 12), (20, oy + 13), (3, oy + 17), (20, oy + 17)], "H")
        elif view == "side":
            c.rect(5, oy + 6, 9, bottom, "H"); c.rect(5, bottom - 1, 9, bottom, "J")
            if st == "wavy":
                c.cells([(4, oy + 12), (4, oy + 13), (4, oy + 17)], "H")
    if st == "pigtails":
        if view == "front":
            for x in (5, 18):
                for y in range(oy + 11, oy + 19):
                    c.rect(x - 1, y, x, y, "H" if (y - oy) % 2 else "J")
                c.rect(x - 1, oy + 19, x, oy + 19, "A")
                c.rect(x - 1, oy + 20, x, oy + 21, "H")
        elif view == "side":
            for y in range(oy + 11, oy + 19):
                c.rect(6, y, 7, y, "H" if (y - oy) % 2 else "J")
            c.rect(6, oy + 19, 7, oy + 19, "A"); c.rect(6, oy + 20, 7, oy + 21, "H")
    if st == "hood":
        pass
    if a.get("cape") and not sit:
        if view in ("front", "back"):
            c.rect(6, oy + 15, 17, oy + 22, "C"); c.rect(6, oy + 22, 17, oy + 22, "c")
        else:
            c.rect(6, oy + 15, 10, oy + 22, "C"); c.rect(6, oy + 22, 10, oy + 22, "c")


def hair_front(c, a, oy):
    st = a["hair"]
    y = oy
    if st == "tuft":
        c.cells([(10, y + 1), (13, y + 1), (11, y + 2), (12, y + 0)], "H")
        c.rect(9, y + 2, 14, y + 2, "H"); c.rect(8, y + 3, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 4, "H")
        c.cells([(7, y + 5), (8, y + 5), (10, y + 5), (11, y + 5), (14, y + 5), (15, y + 5), (16, y + 5), (7, y + 6), (15, y + 6)], "H")
        c.cells([(9, y + 3), (10, y + 2), (12, y + 1)], "h")
        c.cells([(11, y + 4), (12, y + 4)], "J")
    elif st == "pigtails":
        c.rect(8, y + 2, 15, y + 2, "H"); c.rect(6, y + 3, 17, y + 4, "H")
        c.rect(6, y + 5, 9, y + 5, "H"); c.rect(13, y + 5, 17, y + 5, "H")
        c.cells([(6, y + 6), (7, y + 6), (16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (8, y + 6), (14, y + 6)], "H")
        c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
        c.cells([(11, y + 5), (12, y + 5)], None)
        c.cells([(11, y + 4), (12, y + 4)], "J")
        c.cells([(14, y + 2), (15, y + 2), (15, y + 3), (16, y + 1)], "a")   # a white flower
        c.put(15, y + 2, "A")
    elif st == "short":
        c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
        c.rect(6, y + 6, 11, y + 6, "H"); c.cells([(16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (6, y + 8), (12, y + 6)], "H")
        c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (11, y + 4)], "h")
        c.cells([(14, y + 5), (15, y + 5)], "J")
        c.cells([(10, y + 1), (11, y + 1)], "H")                           # a cowlick
    elif st in ("long", "wavy"):
        c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
        c.rect(6, y + 6, 10, y + 6, "H"); c.rect(13, y + 6, 17, y + 6, "H")
        c.cells([(6, y + 7), (6, y + 8), (6, y + 9), (17, y + 7), (17, y + 8), (17, y + 9), (7, y + 7), (16, y + 7)], "H")
        c.cells([(11, y + 5), (12, y + 5)], "J")                           # the parting
        c.cells([(8, y + 3), (9, y + 3), (7, y + 4)], "h")
        if st == "long":                                                   # a crown of flowers and leaves
            for i, x in enumerate(range(7, 17)):
                c.put(x, y + 3, "l" if i % 3 == 1 else ("A" if i % 3 == 0 else "a"))
            c.cells([(6, y + 4), (17, y + 4)], "l")
        else:                                                              # a little soul-flame hair clip
            c.cells([(15, y + 3), (16, y + 3), (16, y + 2), (15, y + 4)], "A")
            c.put(16, y + 1, "Z")
    elif st == "hood":
        hood(c, oy, "front")


def hood(c, oy, view):
    rows = {1: (9, 14), 2: (7, 16), 3: (6, 17), 13: (6, 17), 14: (7, 16), 15: (8, 15)}
    for r in range(1, 16):
        x0, x1 = rows.get(r, (5, 18))
        if view == "side":
            x0, x1 = rows.get(r, (5, 18))
            x1 = min(x1, 16 if r > 4 else x1)
        c.rect(x0, oy + r, x1, oy + r, "C")
    c.cells([(10, oy + 1), (9, oy + 2), (8, oy + 3), (7, oy + 4)], "v")
    c.rect(18, oy + 4, 18, oy + 12, "c"); c.put(17, oy + 13, "c")
    if view == "front":
        for r in range(5, 15):                                             # the skull looks out of the hood
            x0, x1 = (8, 15) if r in (5, 14) else (7, 16)
            c.rect(x0, oy + r, x1, oy + r, "s")
        c.rect(8, oy + 5, 15, oy + 5, "c")                                 # shadow under the brim
        c.cells([(7, oy + 6), (16, oy + 6)], "c")
        c.put(16, oy + 7, "S")
        c.rect(16, oy + 8, 16, oy + 13, "S")
    elif view == "side":
        for r in range(5, 15):
            x0 = 11 if r in (5, 14) else 10
            c.rect(x0, oy + r, 17, oy + r, "s")
        c.rect(10, oy + 5, 16, oy + 5, "c")
        c.put(10, oy + 6, "c")
    c.cells([(11, oy + 15), (12, oy + 15)], "A")                          # the clasp


def hair_side(c, a, oy):
    st = a["hair"]
    y = oy
    if st == "hood":
        hood(c, oy, "side")
        return
    if st == "tuft":
        c.cells([(11, y + 0), (10, y + 1), (12, y + 1), (8, y + 1)], "H")
        c.rect(8, y + 2, 14, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 16, y + 4, "H")
        c.rect(6, y + 5, 10, y + 6, "H"); c.cells([(15, y + 5), (16, y + 5), (13, y + 5)], "H")
        c.cells([(9, y + 2), (10, y + 3)], "h")
        return
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 11, y + 10, "H")                                      # hair over the back of the head
    c.cells([(16, y + 6), (17, y + 6), (17, y + 7), (13, y + 6)], "H")     # the fringe in front
    c.rect(6, y + 10, 11, y + 10, "J")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
    if st == "short":
        c.cells([(10, y + 1), (11, y + 1)], "H")
        c.rect(6, y + 10, 11, y + 10, None)
        c.rect(6, y + 10, 8, y + 10, "J")
    if st == "pigtails":
        c.cells([(13, y + 2), (14, y + 2), (14, y + 1)], "a"); c.put(13, y + 1, "A")
    if st == "long":
        for i, x in enumerate(range(8, 17)):
            c.put(x, y + 3, "l" if i % 3 == 1 else ("A" if i % 3 == 0 else "a"))
    if st == "wavy":
        c.cells([(15, y + 3), (16, y + 3), (16, y + 2)], "A"); c.put(16, y + 1, "Z")


def hair_back(c, a, oy):
    st = a["hair"]
    y = oy
    if st == "hood":
        rows = {1: (9, 14), 2: (7, 16), 3: (6, 17), 13: (6, 17), 14: (7, 16), 15: (7, 16)}
        for r in range(1, 16):
            x0, x1 = rows.get(r, (5, 18))
            c.rect(x0, y + r, x1, y + r, "C")
        c.rect(18, y + 4, 18, y + 12, "c")
        c.rect(7, y + 15, 16, y + 15, "c")
        c.cells([(11, y + 0), (12, y + 0), (12, y - 1)], "C")
        c.cells([(10, y + 2), (9, y + 3), (8, y + 4)], "v")
        return
    if st == "tuft":
        c.cells([(10, y + 1), (13, y + 1), (12, y + 0)], "H")
        c.rect(9, y + 2, 14, y + 2, "H"); c.rect(8, y + 3, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 7, "H")
        c.rect(8, y + 8, 15, y + 8, "H"); c.rect(9, y + 9, 14, y + 9, "J")
        c.cells([(9, y + 3), (10, y + 2)], "h")
        return
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 13, "H")
    c.rect(7, y + 14, 16, y + 14, "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (8, y + 5)], "h")
    if st == "short":
        c.rect(6, y + 12, 17, y + 14, None)
        head_shape_rows(c, y, range(9, 12), "s")
        c.rect(6, y + 11, 17, y + 11, "J")
    elif st == "pigtails":
        c.rect(6, y + 12, 17, y + 13, "J")
        for x in (5, 18):
            for yy in range(y + 11, y + 19):
                c.rect(x - 1, yy, x, yy, "H" if (yy - y) % 2 else "J")
            c.rect(x - 1, y + 19, x, y + 19, "A"); c.rect(x - 1, y + 20, x, y + 21, "H")
        c.cells([(15, y + 2), (16, y + 2), (16, y + 1)], "a")
    else:
        bottom = y + (20 if st == "long" else 19)
        c.rect(6, y + 14, 17, bottom, "H")
        c.rect(6, bottom - 1, 17, bottom, "J")
        c.rect(9, y + 14, 9, bottom - 2, "J"); c.rect(14, y + 14, 14, bottom - 2, "J")      # strands
        if st == "wavy":
            c.clear([(6, bottom), (9, bottom), (12, bottom), (15, bottom)])
            c.cells([(5, y + 12), (5, y + 13), (18, y + 12), (18, y + 13), (5, y + 17), (18, y + 17)], "H")   # waves
            c.cells([(8, y + 7), (9, y + 7), (10, y + 8), (13, y + 6), (14, y + 6), (15, y + 7),
                     (7, y + 15), (8, y + 16), (15, y + 15), (16, y + 16)], "h")
            c.rect(9, y + 14, 9, bottom - 2, "H"); c.rect(14, y + 14, 14, bottom - 2, "H")
            c.rect(8, y + 11, 10, y + 13, "T"); c.rect(13, y + 11, 15, y + 13, "T")       # a lavender bow
            c.cells([(9, y + 12), (14, y + 12), (11, y + 12), (12, y + 12)], "U")
            c.cells([(10, y + 14), (13, y + 14), (10, y + 15), (13, y + 15)], "T")
        if st == "long":
            for i, x in enumerate(range(6, 18)):
                c.put(x, y + 4, "l" if i % 3 == 1 else ("A" if i % 3 == 0 else "a"))
            c.rect(10, y + 12, 13, y + 12, "k")                            # a ribbon tying it
        else:
            c.cells([(6, y + 3), (7, y + 3), (6, y + 2)], "A")


def head_shape_rows(c, oy, rs, key):
    for r in rs:
        x0, x1 = HEAD.get(r, (6, 17))
        c.rect(x0, oy + 3 + r, x1, oy + 3 + r, key)


# --- bodies -------------------------------------------------------------------------------------------------------------
def torso_front(c, a, oy, back=False):
    c.rect(8, oy + 15, 15, oy + 21, "T")
    c.rect(15, oy + 15, 15, oy + 21, "U")
    if a["race"] == "skeleton":
        c.rect(6, oy + 15, 17, oy + 16, "C"); c.rect(7, oy + 17, 16, oy + 17, "C")    # a hooded capelet
        c.rect(7, oy + 17, 16, oy + 17, "c"); c.cells([(6, oy + 16), (17, oy + 16)], "c")
        if not back:
            c.cells([(11, oy + 15), (12, oy + 15)], "A")
        c.rect(8, oy + 20, 15, oy + 20, "k" if back else "k")
        if not back:
            c.cells([(10, oy + 20), (11, oy + 20), (12, oy + 20), (13, oy + 20)], "k")
            c.cells([(11, oy + 20), (12, oy + 20)], "A")
        return
    if not back:
        if a["outfit"] == "dress":
            c.rect(10, oy + 15, 13, oy + 15, "u")                          # a white collar
            c.rect(10, oy + 17, 13, oy + 21, "u") if a["race"] == "goblin" else None   # the apron
            c.cells([(10, oy + 16), (13, oy + 16)], "u") if a["race"] == "goblin" else None
        elif a["outfit"] == "gown":
            c.cells([(10, oy + 15), (11, oy + 16), (12, oy + 16), (13, oy + 15)], "u")
        elif a["outfit"] == "spirit":
            c.rect(9, oy + 15, 14, oy + 15, "u"); c.cells([(11, oy + 16), (12, oy + 16)], "u")
        else:
            c.cells([(10, oy + 15), (11, oy + 16), (12, oy + 16), (13, oy + 15)], "u")   # a v-neck
            if a.get("patch"):
                c.rect(9, oy + 17, 10, oy + 18, "u")
    belt = a.get("belt", 20)
    if belt:
        c.rect(8, oy + belt, 15, oy + belt, "k")
        if not back and a.get("buckle"):
            c.put(11, oy + belt, "A")
    if a.get("cape") and not back:
        c.cells([(8, oy + 15), (15, oy + 15)], "C")
        c.cells([(9, oy + 15), (14, oy + 15)], "A")


def arms_front(c, a, oy, phase, rest=None):
    sw = SWING[phase]
    sleeve = a.get("sleeve", "short")
    for x0, s in ((6, sw), (16, -sw)):
        top, bottom = oy + 16 + s, oy + 20 + s
        for y in range(top, bottom + 1):
            long = sleeve == "long" or (y - top) < 2
            c.rect(x0, y, x0 + 1, y, a.get("sleeve_col", "T") if long else "s")
        c.rect(x0, bottom + 1, x0 + 1, bottom + 1, "s")
        if sleeve == "long":
            c.rect(x0, bottom, x0 + 1, bottom, "u" if a.get("cuff") else a.get("sleeve_col", "T"))
    c.cells([(6, oy + 15), (17, oy + 15)], a.get("sleeve_col", "T"))


def legs_front(c, a, oy, phase, back=False):
    o = a["outfit"]
    left_lift = 1 if phase == 1 else 0
    right_lift = 1 if phase == 3 else 0
    if o == "spirit":
        sway = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
        c.rect(8, oy + 21, 15, oy + 21, "T"); c.rect(7, oy + 22, 16, oy + 22, "T"); c.rect(6, oy + 23, 17, oy + 23, "T")
        c.rect(6, oy + 23, 17, oy + 23, "u")
        c.cells([(6, oy + 23), (9, oy + 23), (12, oy + 23), (15, oy + 23)], "U")
        c.rect(8, oy + 24, 15, oy + 24, "Q")
        c.rect(9 + sway, oy + 25, 14 + sway, oy + 25, "Q")
        c.rect(10 + sway, oy + 26, 13 + sway, oy + 26, "q")
        c.rect(11 + 2 * sway, oy + 27, 12 + 2 * sway, oy + 27, "q")
        c.cells([(9, oy + 24), (10 + sway, oy + 25)], "Z")
        return
    if o in ("dress", "gown"):
        if o == "dress":
            c.rect(8, oy + 21, 15, oy + 21, "T"); c.rect(7, oy + 22, 16, oy + 23, "T")
            c.rect(16, oy + 22, 16, oy + 23, "U")
            c.rect(7, oy + 23, 16, oy + 23, "U")
            for x, lift in ((9, left_lift), (13, right_lift)):
                c.rect(x, oy + 24, x + 1, oy + 25 - lift, "s")
                c.rect(x - (1 if x == 9 else 0), oy + 26 - lift, x + 1 + (1 if x == 13 else 0), oy + 26 - lift, "K")
            if not back:
                c.rect(10, oy + 21, 13, oy + 22, "u")
        else:
            c.rect(8, oy + 21, 15, oy + 21, "T"); c.rect(7, oy + 22, 16, oy + 23, "T"); c.rect(6, oy + 24, 17, oy + 25, "T")
            c.rect(16, oy + 22, 16, oy + 23, "U"); c.rect(17, oy + 24, 17, oy + 25, "U")
            c.rect(6, oy + 25, 17, oy + 25, "u")
            if phase in (0, 2):
                c.rect(8, oy + 26, 10, oy + 26, "K"); c.rect(13, oy + 26, 15, oy + 26, "K")
            elif phase == 1:
                c.rect(13, oy + 26, 15, oy + 26, "K")
            else:
                c.rect(8, oy + 26, 10, oy + 26, "K")
        return
    # tunic hem, then trousers (or bare bones) and shoes
    c.rect(8, oy + 21, 15, oy + 22, "T"); c.rect(15, oy + 21, 15, oy + 22, "U")
    for x, lift in ((9, left_lift), (13, right_lift)):
        if a["race"] == "skeleton":
            xx = 10 if x == 9 else 13
            c.rect(xx, oy + 23, xx, oy + 25 - lift, "P")
            c.put(xx, oy + 24 - lift, "Q")
        else:
            c.rect(x, oy + 23, x + 1, oy + 25 - lift, "P")
            c.put(x + 1, oy + 23, "Q")
        c.rect(x - (1 if x == 9 else 0), oy + 26 - lift, x + 1 + (1 if x == 13 else 0), oy + 26 - lift, "K")


def legs_side(c, a, phase, oy=0):
    o = a["outfit"]
    if o == "spirit":
        sway = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
        c.rect(9, oy + 21, 14, oy + 21, "T"); c.rect(8, oy + 22, 15, oy + 23, "T"); c.rect(8, oy + 23, 15, oy + 23, "u")
        c.rect(9, oy + 24, 14, oy + 24, "Q"); c.rect(8, oy + 25, 12, oy + 25, "Q"); c.rect(6, oy + 26 + (sway > 0), 9, oy + 26 + (sway > 0), "q")
        c.rect(4, oy + 25 + (sway < 0), 6, oy + 25 + (sway < 0), "q")
        c.put(10, oy + 24, "Z")
        return
    if phase in (0, 2):
        back, front = (9, 26), (13, 26)
    elif phase == 1:
        back, front = (10, 26), (12, 25)
    else:
        back, front = (10, 25), (12, 26)
    if o in ("dress",):
        for (x, foot), shade in ((back, True), (front, False)):
            c.rect(x, oy + 24, x + 1, oy + foot - 1, "S" if shade else "s")
            c.rect(x, oy + foot, x + 2, oy + foot, "K")
        c.rect(9, oy + 21, 14, oy + 21, "T"); c.rect(8, oy + 22, 15, oy + 23, "T"); c.rect(8, oy + 23, 15, oy + 23, "U")
        c.cells([(15, oy + 21), (15, oy + 22)], "u")
        return
    if o == "gown":
        c.rect(9, oy + 21, 14, oy + 21, "T"); c.rect(8, oy + 22, 15, oy + 23, "T"); c.rect(7, oy + 24, 16, oy + 25, "T")
        c.rect(7, oy + 25, 16, oy + 25, "u"); c.rect(7, oy + 22, 8, oy + 25, "U")
        fx = {0: 13, 1: 14, 2: 13, 3: 11}[phase]
        c.rect(fx, oy + 26, fx + 2, oy + 26, "K")
        return
    skel = a["race"] == "skeleton"
    for (x, foot), shade in ((back, True), (front, False)):
        if skel:
            c.rect(x + 1, oy + 23, x + 1, oy + foot - 1, "Q" if shade else "P")
        else:
            c.rect(x, oy + 23, x + 1, oy + foot - 1, "Q" if shade else "P")
        c.rect(x, oy + foot, x + 2, oy + foot, "K")
    c.rect(9, oy + 21, 14, oy + 22, "T")


def torso_side(c, a, oy):
    c.rect(9, oy + 15, 14, oy + 21, "T")
    c.rect(9, oy + 15, 9, oy + 21, "U")
    if a["outfit"] in ("tunic",) and a["race"] != "skeleton":
        c.cells([(14, oy + 15), (14, oy + 16)], "u")
    if a["outfit"] == "dress" and a["race"] == "goblin":
        c.rect(14, oy + 17, 14, oy + 21, "u")
    if a["outfit"] == "spirit":
        c.rect(12, oy + 15, 14, oy + 15, "u")
    belt = a.get("belt", 20)
    if belt:
        c.rect(9, oy + belt, 14, oy + belt, "k")
    if a["race"] == "skeleton":
        c.rect(7, oy + 15, 13, oy + 16, "C"); c.rect(8, oy + 17, 12, oy + 17, "c")
    if a.get("cape"):
        c.rect(9, oy + 15, 10, oy + 16, "C"); c.put(13, oy + 15, "A")


def arm_side(c, a, oy, phase):
    sc = a.get("sleeve_col", "T")
    long = a.get("sleeve", "short") == "long"
    if phase in (0, 2):
        pts = [(11, 16), (12, 16), (11, 17), (12, 17), (11, 18), (12, 18), (11, 19), (12, 19), (11, 20), (12, 20)]
        hand = [(11, 21), (12, 21)]
    elif phase == 1:
        pts = [(11, 16), (12, 16), (12, 17), (13, 17), (13, 18), (14, 18), (14, 19), (15, 19)]
        hand = [(15, 20), (16, 20), (16, 19)]
    else:
        pts = [(11, 16), (12, 16), (10, 17), (11, 17), (9, 18), (10, 18), (8, 19), (9, 19)]
        hand = [(7, 20), (8, 20), (7, 19)]
    for i, (x, y) in enumerate(pts):
        c.put(x, oy + y, sc if (long or i < 4) else "s")
    c.cells([(x, oy + y) for x, y in hand], "s")


# --- whole poses --------------------------------------------------------------------------------------------------------
def front(a, phase=0, oy=0):
    c = C()
    hair_behind(c, a, "front", oy)
    legs_front(c, a, oy, phase)
    torso_front(c, a, oy)
    arms_front(c, a, oy, phase)
    ears(c, a, "front", oy)
    head_shape(c, oy)
    face_front(c, a, oy)
    hair_front(c, a, oy)
    if a["hair"] == "hood":
        face_front(c, a, oy)                                               # the skull looks out of the hood
    return c.outline()


def back(a, phase=0):
    c = C()
    legs_front(c, a, 0, phase, back=True)
    torso_front(c, a, 0, back=True)
    if a.get("cape"):
        c.rect(7, 15, 16, 22, "C"); c.rect(7, 22, 16, 22, "c"); c.rect(16, 15, 16, 21, "c")
    arms_front(c, a, 0, phase)
    ears(c, a, "back", 0)
    head_shape(c, 0)
    hair_back(c, a, 0)
    return c.outline()


def side(a, phase=0):
    bob = 1 if (a["outfit"] == "spirit" and phase in (1, 2)) else 0
    oy = -bob
    c = C()
    hair_behind(c, a, "side", oy)
    legs_side(c, a, phase, oy)
    torso_side(c, a, oy)
    ears(c, a, "side", oy)
    head_shape(c, oy)
    c.rect(17, oy + 6, 17, oy + 12, "s")
    c.rect(6, oy + 6, 6, oy + 12, "S")
    face_side(c, a, oy)
    hair_side(c, a, oy)
    ears(c, a, "side", oy)
    if a["hair"] == "hood":
        face_side(c, a, oy)
    arm_side(c, a, oy, phase)
    return c.outline()


def front_walk(a, phase):
    bob = 1 if (a["outfit"] == "spirit" and phase in (1, 2)) else 0
    return front(a, phase, -bob)


# --- furniture ----------------------------------------------------------------------------------------------------------
FURN = {"O": (60, 40, 30), "W": (176, 118, 66), "w": (140, 90, 48), "V": (206, 150, 92), "B": (210, 170, 70),
        "b": (160, 120, 44), "G": (150, 230, 240), "g": (96, 170, 210), "Z": (240, 255, 255), "R": (120, 220, 200),
        "r": (60, 120, 150), "N": (100, 74, 120), "n": (70, 52, 90), "P": (250, 240, 214), "p": (210, 196, 160),
        "K": (54, 46, 60), "k": (90, 220, 200),
        "F": (176, 72, 92), "f": (132, 50, 70), "L": (214, 112, 130)}       # armchair fabric


def stool(c, x0, y0):
    c.rect(x0, y0, x0 + 6, y0, "V"); c.rect(x0, y0 + 1, x0 + 6, y0 + 1, "W")
    c.rect(x0 + 1, y0 + 2, x0 + 1, y0 + 5, "w"); c.rect(x0 + 5, y0 + 2, x0 + 5, y0 + 5, "w")
    c.rect(x0 + 1, y0 + 4, x0 + 5, y0 + 4, "w")


def crystal_ball(c, cx, top, lit=True):
    """A crystal ball on a brass stand: a glowing 'screen' with lines of runes, the guild's take on a computer."""
    rows = {0: (-2, 2), 1: (-3, 3), 2: (-4, 4), 3: (-4, 4), 4: (-4, 4), 5: (-3, 3), 6: (-2, 2)}
    for r, (a, b) in rows.items():
        c.rect(cx + a, top + r, cx + b, top + r, "G")
    for r, (a, b) in {3: (-3, 3), 4: (-3, 3), 5: (-2, 2)}.items():
        c.rect(cx + a, top + r, cx + b, top + r, "g")
    c.cells([(cx - 2, top + 1), (cx - 1, top + 1), (cx - 3, top + 2)], "Z")
    if lit:                                                                # runes on the glass, like text on a screen
        c.rect(cx - 1, top + 2, cx + 2, top + 2, "r")
        c.rect(cx - 2, top + 3, cx + 1, top + 3, "R")
        c.rect(cx - 1, top + 4, cx + 2, top + 4, "r")
    c.rect(cx - 2, top + 7, cx + 2, top + 7, "B"); c.rect(cx - 3, top + 8, cx + 3, top + 8, "b")
    c.cells([(cx - 2, top + 8)], "B")


def desk_front(w=40, h=31, lit=False):
    """The desk from the front (as in the top-down hall): the avatar sits behind it."""
    c = C(w, h)
    c.rect(1, 20, 38, 21, "V"); c.rect(1, 22, 38, 27, "W")
    c.rect(1, 22, 38, 22, "w"); c.rect(2, 24, 37, 24, "w")
    c.rect(4, 25, 7, 25, "B"); c.rect(32, 25, 35, 25, "B")                 # drawer handles
    c.rect(2, 28, 3, 29, "w"); c.rect(36, 28, 37, 29, "w")
    crystal_ball(c, 33, 11, lit=lit)
    c.rect(12, 19, 21, 19, "K"); c.cells([(13, 19), (15, 19), (17, 19), (19, 19)], "k")   # the rune board
    c.rect(4, 17, 6, 19, "P"); c.put(7, 18, "P"); c.rect(4, 17, 6, 17, "p")              # a mug
    c.outline()
    return c



# --- the generic sitting pose (works on any chair; the chair is a separate layer) -----------------------------------------
SIT_DROP = 2                  # the upper body sits this much lower than standing
SEAT = 24                     # every seat's top is at row oy + SEAT; feet stay on the floor (row oy + 26)


def sit_legs_front(c, a, oy, swing=0):
    """Seen from the front: the lap (thighs foreshortened), knees, short shins, feet a little apart.
    swing 1 / 2 kicks the left / right foot forward (it shows a row higher)."""
    u = oy + SIT_DROP
    o = a["outfit"]
    lap0, lap1 = u + 21, u + 22                                         # rows oy+23, oy+24
    if o == "spirit":
        c.rect(8, lap0, 15, lap0, "T"); c.rect(6, lap1, 17, lap1, "u")
        c.cells([(6, lap1), (9, lap1), (12, lap1), (15, lap1)], "U")
        side = -1 if swing == 1 else 1                                  # the tail curls over the seat edge, toward us
        c.rect(9, oy + 25, 14, oy + 25, "Q")
        if side > 0:
            c.rect(11, oy + 26, 15, oy + 26, "q"); c.put(16, oy + 25, "q"); c.put(17, oy + 24, "Z")
        else:
            c.rect(8, oy + 26, 12, oy + 26, "q"); c.put(7, oy + 25, "q"); c.put(6, oy + 24, "Z")
        c.put(10, oy + 25, "Z")
        return
    feet = []
    for x, kick in ((8, swing == 1), (14, swing == 2)):
        foot = oy + 26 - (1 if kick else 0)
        feet.append((x, foot))
    if o == "gown":
        c.rect(7, lap0, 16, lap0, "T"); c.rect(6, lap1, 17, oy + 25, "T")
        c.rect(17, lap1, 17, oy + 25, "U"); c.rect(6, oy + 25, 17, oy + 25, "u")
        for x, foot in feet:
            if foot == oy + 26:
                c.rect(x, foot, x + 1, foot, "K")
            else:
                c.rect(x, oy + 25, x + 1, oy + 25, "K")
        return
    if o == "dress":
        c.rect(7, lap0, 16, lap1, "T"); c.rect(7, lap1, 16, lap1, "U")
        c.rect(10, lap0, 13, lap0, "u")
        shin = "s"
    else:
        c.rect(8, lap0, 15, lap0, "T"); c.rect(15, lap0, 15, lap0, "U")          # the tunic hem over the lap
        if a["race"] == "skeleton":
            c.cells([(9, lap1), (10, lap1), (13, lap1), (14, lap1)], "P")      # knobbly knees
            c.cells([(10, lap1), (13, lap1)], "Q")
        else:
            c.rect(7, lap1, 16, lap1, "P"); c.rect(11, lap1, 12, lap1, "Q")     # knees, a shadow between
        shin = "P"
    for x, foot in feet:
        if a["race"] == "skeleton":
            sx = x + 1 if x == 8 else x
            c.rect(sx, oy + 25, sx, foot - 1, "P")
        else:
            c.rect(x, oy + 25, x + 1, foot - 1, shin)
        c.rect(x - (1 if x == 8 else 0), foot, x + 1 + (1 if x == 14 else 0), foot, "K")


def sit_front_body(a, oy=0, swing=0, look="open", arms=True, h=H):
    c = C(W, h)
    u = oy + SIT_DROP
    hair_behind(c, a, "front", u)
    sit_legs_front(c, a, oy, swing)
    torso_front(c, a, u)
    if arms:
        arms_front(c, a, u, 0)                                          # hands resting on the lap
    ears(c, a, "front", u)
    head_shape(c, u)
    face_front(c, a, u, look)
    hair_front(c, a, u)
    if a["hair"] == "hood":
        face_front(c, a, u, look)
    return c


def sit_legs_side(c, a, oy, swing=0):
    """From the side, facing right: an L - thighs level on the seat, shins straight down (swing 1 kicks them forward)."""
    u = oy + SIT_DROP
    o = a["outfit"]
    t0, t1 = u + 20, u + 21                                             # thigh rows oy+22, oy+23
    if swing:
        shin = [(18, oy + 24), (19, oy + 24), (19, oy + 25), (20, oy + 25)]
        shoe = [(20, oy + 26), (21, oy + 26), (22, oy + 26), (21, oy + 25)]
    else:
        shin = [(17, oy + 24), (18, oy + 24), (17, oy + 25), (18, oy + 25)]
        shoe = [(17, oy + 26), (18, oy + 26), (19, oy + 26), (20, oy + 26)]
    if o == "spirit":
        c.rect(9, t0, 18, t1, "T"); c.rect(9, t1, 18, t1, "u")
        tip = (21, oy + 24) if swing else (20, oy + 26)
        c.cells([(17, oy + 24), (18, oy + 24), (18, oy + 25), (19, oy + 25)], "Q")
        c.cells([(20, oy + 25), tip], "q"); c.put(17, oy + 24, "Z")
        return
    if o == "gown":
        c.rect(9, t0 - 1, 19, t1, "T"); c.rect(16, oy + 24, 20, oy + 25, "T"); c.rect(16, oy + 25, 20, oy + 25, "u")
        c.rect(9, t1, 15, t1, "U")
        c.cells([(x + 2, y) for x, y in shoe if y == oy + 26][:3], "K")
        return
    if o == "dress":
        c.rect(9, t0 - 1, 19, t1, "T"); c.rect(9, t1, 19, t1, "U")
        c.cells(shin, "s"); c.cells(shoe, "K")
        return
    if a["race"] == "skeleton":
        c.rect(9, t0, 13, t1, "T")
        c.rect(13, t1, 18, t1, "P"); c.put(18, t0, "Q")
        if not swing:
            c.rect(18, oy + 24, 18, oy + 25, "P")
        else:
            c.cells([(19, oy + 24), (20, oy + 25)], "P")
        c.cells(shoe, "K")
        return
    c.rect(9, t0, 13, t1, "T")
    c.rect(13, t0, 18, t1, "P"); c.rect(13, t1, 18, t1, "Q")
    c.cells(shin, "P"); c.cells(shoe, "K")


def sit_side_body(a, oy=0, swing=0, arm="lap", look="open", h=H, w=W):
    c = C(w, h)
    u = oy + SIT_DROP
    hair_behind(c, a, "side", u, sit=True)
    if a.get("cape"):
        c.rect(6, u + 15, 10, u + 20, "C"); c.rect(6, u + 20, 10, u + 20, "c")
    torso_side(c, a, u)
    sit_legs_side(c, a, oy, swing)
    head_shape(c, u)
    c.rect(17, u + 6, 17, u + 12, "s")
    c.rect(6, u + 6, 6, u + 12, "S")
    face_side(c, a, u, look)
    hair_side(c, a, u)
    ears(c, a, "side", u)
    if a["hair"] == "hood":
        face_side(c, a, u, look)
    sc = a.get("sleeve_col", "T")
    long = a.get("sleeve", "short") == "long"
    if arm == "desk":                                                   # reaching forward to the rune board
        pts = [(11, 16), (12, 16), (12, 17), (13, 17), (14, 17), (15, 17), (16, 17), (17, 17), (18, 17), (19, 17)]
        hand = [(20, 17), (21, 17), (21, 16)]
    else:                                                               # resting on the thigh
        pts = [(11, 16), (12, 16), (11, 17), (12, 17), (12, 18), (13, 18), (13, 19), (14, 19)]
        hand = [(15, 19), (15, 20), (14, 20)]
    for i, (x, y) in enumerate(pts):
        c.put(x, u + y, sc if (long or i < 4) else "s")
    c.cells([(x, u + y) for x, y in hand], "s")
    return c


def seat(kind, view, oy, w, h, cx):
    """A chair layer: its seat top is always at row oy + SEAT. cx is the middle (front) or the hips' x (side)."""
    c = C(w, h)
    sy, floor = oy + SEAT, oy + 26
    if view == "front":
        if kind == "stool":
            c.rect(cx - 7, sy, cx + 7, sy, "V"); c.rect(cx - 7, sy + 1, cx + 7, sy + 1, "W")
            c.rect(cx - 6, sy + 2, cx - 6, floor, "w"); c.rect(cx + 6, sy + 2, cx + 6, floor, "w")
        elif kind == "bench":
            c.rect(cx - 13, oy + 15, cx + 13, oy + 16, "V"); c.rect(cx - 13, oy + 18, cx + 13, oy + 19, "W")
            c.rect(cx - 12, oy + 15, cx - 12, sy, "w"); c.rect(cx + 12, oy + 15, cx + 12, sy, "w")
            c.rect(cx - 14, sy, cx + 14, sy, "V"); c.rect(cx - 14, sy + 1, cx + 14, sy + 1, "W")
            c.rect(cx - 13, sy + 2, cx - 12, floor, "w"); c.rect(cx + 12, sy + 2, cx + 13, floor, "w")
        else:                                                           # armchair / sofa
            c.rect(cx - 10, oy + 12, cx + 10, sy, "F"); c.rect(cx - 9, oy + 11, cx + 9, oy + 11, "F")
            c.rect(cx - 9, oy + 12, cx + 9, oy + 12, "L")
            c.cells([(cx - 5, oy + 15), (cx, oy + 15), (cx + 5, oy + 15), (cx - 3, oy + 19), (cx + 3, oy + 19)], "f")
            for x0 in (cx - 14, cx + 11):                               # round armrests
                c.rect(x0, oy + 18, x0 + 3, floor - 1, "F"); c.rect(x0, oy + 18, x0 + 3, oy + 18, "L")
                c.rect(x0 + (3 if x0 < cx else 0), oy + 19, x0 + (3 if x0 < cx else 0), floor - 1, "f")
            c.rect(cx - 10, sy, cx + 10, sy, "L"); c.rect(cx - 10, sy + 1, cx + 10, sy + 1, "F")
            c.rect(cx - 14, floor, cx + 14, floor, "w")
            c.cells([(cx - 13, floor + 1), (cx + 13, floor + 1)], "w")
    else:
        if kind == "stool":
            c.rect(cx - 4, sy, cx + 5, sy, "V"); c.rect(cx - 4, sy + 1, cx + 5, sy + 1, "W")
            c.rect(cx - 3, sy + 2, cx - 3, floor, "w"); c.rect(cx + 4, sy + 2, cx + 4, floor, "w")
        elif kind == "bench":
            c.rect(cx - 5, oy + 15, cx - 4, sy, "w")                    # the backrest seen edge-on
            c.rect(cx - 6, oy + 15, cx - 3, oy + 16, "V"); c.rect(cx - 6, oy + 18, cx - 3, oy + 19, "W")
            c.rect(cx - 6, sy, cx + 6, sy, "V"); c.rect(cx - 6, sy + 1, cx + 6, sy + 1, "W")
            c.rect(cx - 5, sy + 2, cx - 5, floor, "w"); c.rect(cx + 5, sy + 2, cx + 5, floor, "w")
        else:
            c.rect(cx - 9, oy + 12, cx - 4, floor - 1, "F"); c.rect(cx - 8, oy + 11, cx - 5, oy + 11, "F")
            c.rect(cx - 8, oy + 12, cx - 6, oy + 12, "L"); c.rect(cx - 4, oy + 13, cx - 4, floor - 1, "f")
            c.rect(cx - 4, oy + 18, cx + 5, oy + 19, "F"); c.rect(cx - 4, oy + 18, cx + 5, oy + 18, "L")   # far armrest
            c.rect(cx + 5, oy + 19, cx + 5, floor - 1, "f")
            c.rect(cx - 4, sy, cx + 5, sy, "L"); c.rect(cx - 4, sy + 1, cx + 5, floor - 1, "F")
            c.rect(cx - 9, floor, cx + 6, floor, "w"); c.cells([(cx - 8, floor + 1), (cx + 5, floor + 1)], "w")
    return c.outline()


def compose_at(layers, w, h):
    """layers: (canvas, palette, dx, dy), back to front."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for canvas, pal, dx, dy in layers:
        im = canvas.image(pal)
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        layer.paste(im, (dx, dy), im)
        img.alpha_composite(layer)
    return img


def desk_side(w=42, h=31, oy=2):
    """The desk seen from the side, to the right of the sitter: top at elbow height, crystal ball, rune board."""
    c = C(w, h)
    top = oy + 20
    c.rect(22, top, 40, top + 1, "W"); c.rect(22, top, 40, top, "V")
    c.rect(24, top + 2, 25, oy + 26, "w"); c.rect(38, top + 2, 39, oy + 26, "w")
    c.rect(24, oy + 24, 39, oy + 24, "w")
    crystal_ball(c, 33, top - 9)
    c.rect(22, top - 1, 25, top - 1, "K"); c.cells([(23, top - 1), (25, top - 1)], "k")
    c.outline()
    return c


def sit_side(a):
    """At the desk from the side: the generic sitting body on a stool, hands on the rune board."""
    oy = 2
    body = sit_side_body(a, oy, arm="desk", h=31, w=42).outline()
    return [(seat("stool", "side", oy, 42, 31, 11), FURN), (body, PALS[a["pal"]]), (desk_side(42, 31, oy), FURN)]


def sit_front(a):
    """Behind the desk (the top-down hall's view): the generic sitting body, hands forward on the rune board."""
    oy = -1
    body = sit_front_body(a, oy, h=31).outline()
    ch = C(40, 31)
    for y in range(31):
        for x in range(W):
            if body.px[y][x] is not None:
                ch.px[y][x + 5] = body.px[y][x]
    u = oy + SIT_DROP
    c2 = C(40, 31)
    sc = a.get("sleeve_col", "T")
    for x0 in (11, 21):
        c2.rect(x0, u + 16, x0 + 1, u + 17, sc)
        c2.rect(x0 + (1 if x0 == 11 else -1), u + 18, x0 + (2 if x0 == 11 else 0), u + 18, sc if a.get("sleeve") == "long" else "s")
    c2.cells([(13, u + 18), (14, u + 18), (19, u + 18), (20, u + 18)], "s")
    c2.outline()
    return [(ch, PALS[a["pal"]]), (desk_front(), FURN), (c2, PALS[a["pal"]])]


def compose(layers, w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for canvas, pal in layers:
        img.alpha_composite(canvas.image(pal))
    return img


# --- the six avatars -----------------------------------------------------------------------------------------------------
AVATARS = [
    dict(id="gob_m", pal="gob_m", race="goblin", girl=False, ears="goblin", hair="tuft", outfit="tunic", patch=True,
         buckle=True, earring=True,
         name="哥布林・男", note="綠皮大耳、小獠牙，一撮亂翹的黑髮；補丁麻布短袖衣、繩腰帶、短褲布鞋"),
    dict(id="gob_f", pal="gob_f", race="goblin", girl=True, ears="goblin", hair="pigtails", outfit="dress", belt=None,
         name="哥布林・女", note="綠皮大耳、一顆小虎牙，橘紅雙麻花辮綁黃髮帶、白花；玫瑰色洋裝加白圍裙"),
    dict(id="elf_m", pal="elf_m", race="elf", girl=False, ears="elf", hair="short", outfit="tunic", cape=True, buckle=True,
         name="精靈・男", note="短尖耳朝兩側、綠眼，栗色短髮側分；綠色短衫、深綠短披風配金葉扣、米色褲、皮靴"),
    dict(id="elf_f", pal="elf_f", race="elf", girl=True, ears="elf", hair="long", outfit="gown", sleeve="long", cuff=True,
         belt=20, name="精靈・女", note="短尖耳朝兩側、綠眼，淡金長髮戴花冠；薄荷綠長袖長裙、粉色腰帶"),
    dict(id="und_m", pal="und_m", race="skeleton", girl=False, ears=None, hair="hood", outfit="tunic", sleeve="long",
         buckle=True, cuff=True, name="死靈・男（骨系）", note="圓圓的骷髏頭、青色眼火、微微臉紅；紫色連帽小披肩、藍綠長袖衫、魂火腰扣、細骨頭腿"),
    dict(id="und_f", pal="und_f", race="ghost", girl=True, ears=None, hair="wavy", outfit="spirit", belt=20, sleeve="long",
         name="死靈・女（魂系）", note="淡藍發光的靈魂少女，波浪薄荷色長髮、魂火髮夾；薰衣草洋裝，下身化成飄著的靈尾"),
]


def frames(a):
    pal = PALS[a["pal"]]
    out = [("正面", front(a).image(pal)),
           ("走路 1", front_walk(a, 1).image(pal)),
           ("走路 2", front_walk(a, 3).image(pal)),
           ("側面 1", side(a, 1).image(pal)),
           ("側面 2", side(a, 3).image(pal)),
           ("背面", back(a, 0).image(pal)),
           ("坐桌前・側面", compose(sit_side(a), 42, 31)),
           ("坐桌前・正面", compose(sit_front(a), 40, 31))]
    return out


# --- the sheet ----------------------------------------------------------------------------------------------------------
def wood_floor(art):
    planks = [(228, 198, 152), (220, 188, 142), (232, 204, 160), (216, 184, 138)]
    seam, grain = (186, 150, 104), (206, 172, 126)
    ph = 6
    for row in range(art.h // ph + 1):
        y = row * ph
        art.rect(0, y, art.w, ph, planks[row % len(planks)])
        art.rect(0, y + ph - 1, art.w, 1, seam)
        off = (row * 37) % 53
        for x in range(off, art.w, 53):
            art.rect(x, y, 1, ph - 1, seam)
        for k in range(art.w // 9):
            gx = (k * 29 + row * 13) % art.w
            art.rect(gx, y + 1 + (k % 3), 3 + k % 3, 1, grain)


def ptext(art, s, x, y, px, color, anchor="l", stroke=None):
    """Smooth text at the sheet's real resolution (x, y in art pixels), so small Chinese labels stay readable."""
    f = ImageFont.truetype(FONT_CJK, px)
    d = ImageDraw.Draw(art.img)
    a = {"l": "la", "c": "ma", "r": "ra"}[anchor]
    kw = dict(stroke_width=2, stroke_fill=stroke) if stroke else {}
    d.text((x * art.s, y * art.s), s, font=f, fill=color, anchor=a, **kw)


def main():
    S = 4
    hero_scale = 2                                                         # the idle again at x8, to judge the face
    left = 6
    hero_w = W * hero_scale + 6
    row_h = H * hero_scale + 24
    title_h = 22
    widths = [W] * 6 + [42, 40]
    gap = 4
    total_w = left + hero_w + sum(widths) + gap * len(widths) + 4
    total_h = title_h + row_h * len(AVATARS) + 4
    art = Art(total_w, total_h, scale=S, color=(228, 198, 152, 255))
    wood_floor(art)
    ptext(art, "公會角色 預覽：3 種族 × 男女（24×30 點陣，營地居民是 16×16）", 6, 5, 34,
          (70, 44, 24, 255), stroke=(250, 236, 210, 255))
    for r, a in enumerate(AVATARS):
        y0 = title_h + r * row_h
        art.rect(2, y0 - 2, total_w - 4, 1, (186, 150, 104, 255))
        fr = frames(a)
        hero = fr[0][1]
        art.shadow(left + hero_w / 2 - 3, y0 + H * hero_scale - 3, w=16, alpha=50)
        art.sprite(hero, left + (hero_w - 6 - W * hero_scale) / 2, y0, scale=hero_scale, bottom_center=False)
        x = left + hero_w
        for (label, img), w in zip(fr, widths):
            yy = y0 + (H * hero_scale - img.height) - 10
            if label.startswith("坐") is False:
                art.shadow(x + w / 2, yy + 27, w=10, alpha=45)
            art.sprite(img, x, yy, bottom_center=False)
            ptext(art, label, x + w / 2, yy + img.height + 1, 20, (90, 60, 34, 255), anchor="c")
            x += w + gap
        ptext(art, a["name"], left, y0 + H * hero_scale + 4, 30, (60, 36, 20, 255), stroke=(250, 236, 210, 255))
        ptext(art, a["note"], left + 62, y0 + H * hero_scale + 5, 24, (80, 52, 30, 255))
    art.save(OUT)


if __name__ == "__main__":
    main()
