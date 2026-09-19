#!/usr/bin/env python3
"""Draws the built-in goblin characters as 16x16 pixel-art sprite sheets: the goblin workers, and the human girl
the goblins look after as their princess (the "queen" role in the app).

    python3 tools/make_goblin.py            # writes Resources/Characters/goblin/*
    python3 tools/make_goblin.py --preview /path/preview.png   # also writes a zoomed contact sheet

Only the standard library is needed. The output is the same character format that users' own characters use:
manifest.json + one PNG sprite sheet per role (worker / queen), frames of 16x16 laid out left to right, top to bottom.
Sheet layout: 4 columns (walk phase 0..3) x 3 rows (facing down, up, side). "Side" faces right; the app mirrors it for left.
"""
import json
import os
import struct
import sys
import zlib

SIZE = 16

# --- palettes ---------------------------------------------------------------------------------------------------
COMMON = {
    "O": (31, 43, 20),      # outline
    "y": (245, 216, 66),    # eye
    "e": (21, 21, 21),      # pupil
    "t": (243, 237, 208),   # tusk
    "k": (122, 42, 42),     # mouth
    "r": (217, 139, 150),   # inner ear
    "b": (154, 99, 47),     # cloth
    "B": (100, 61, 26),     # dark cloth / hair
}
WORKER = dict(COMMON, g=(109, 179, 63), G=(76, 134, 44), h=(154, 212, 98))
GIRL = {
    "O": (86, 52, 58),        # outline (warm brown, softer than the goblin's)
    "H": (240, 200, 100),     # hair
    "h": (255, 232, 150),     # hair highlight
    "J": (204, 150, 62),      # hair shade
    "s": (252, 222, 200),     # skin
    "S": (232, 184, 160),     # skin shade
    "L": (50, 40, 70),        # lashes
    "i": (84, 140, 220),      # iris
    "w": (255, 255, 255),
    "p": (248, 160, 165),     # blush
    "m": (214, 96, 110),      # mouth
    "D": (96, 138, 214),      # dress
    "d": (66, 100, 178),      # dress shade
    "W": (250, 250, 250),     # collar, trim
    "R": (224, 64, 88),       # ribbon
    "K": (120, 74, 50),       # shoes
    "c": (244, 200, 70),      # tiara
}


class Canvas:
    def __init__(self):
        self.px = [[None] * SIZE for _ in range(SIZE)]

    def put(self, x, y, col):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.px[y][x] = col

    def rect(self, x0, y0, x1, y1, col):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, col)

    def cells(self, pts, col):
        for x, y in pts:
            self.put(x, y, col)

    def outline(self):
        """One-pixel dark outline around everything drawn so far."""
        edge = []
        for y in range(SIZE):
            for x in range(SIZE):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < SIZE and 0 <= ny < SIZE and self.px[ny][nx] is not None:
                            edge.append((x, y))
                            break
        for x, y in edge:
            self.px[y][x] = "O"


def mirror(pts):
    return [(SIZE - 1 - x, y) for x, y in pts]


# --- the goblin -------------------------------------------------------------------------------------------------
# Ears are offsets from the top-left corner of the head box, so the same pair hangs correctly on a small head
# or a big one. The second entry is where the pink inner ear goes.
EARS = {
    "wide":  ([(-3, 0), (-2, 1), (-1, 1), (-2, 2), (-1, 2), (-1, 3)], (-2, 2)),          # the common goblin
    "long":  ([(-1, -2), (-1, -1), (-1, 0), (-1, 1), (-1, 2), (-2, 2)], (-1, 1)),        # tall, always listening
    "stub":  ([(-1, 1), (-2, 2), (-1, 2)], (-1, 2)),                                     # chewed down to nubs
    "droop": ([(-1, 1), (-1, 2), (-1, 3), (-1, 4)], (-1, 2)),                            # old and hanging
}


def place(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


class Build:
    """One breed's proportions. Every goblin stands on row `foot` and is centred on x=7/8, so a breed is
    described by the rows its head fills, how wide its head, chest and legs are, and where its hips sit.
    Face, arms, legs and loincloth all follow from those numbers, which keeps the breeds walking in step
    while their silhouettes stay clearly apart."""

    def __init__(self, head=(2, 7), head_w=8, chest=6, hip=11, foot=14, leg=2, arm=1, ear="wide"):
        self.y0, self.y1 = head
        self.hx = (8 - head_w // 2, 7 + head_w // 2)
        self.tx = (8 - chest // 2, 7 + chest // 2)
        waist = min(chest, 6)                                     # however broad the chest, the hips stay narrow
        self.lx = (8 - waist // 2, 7 + waist // 2)
        self.shoulder = self.y1 + 1
        self.hip, self.foot, self.leg, self.arm = hip, foot, leg, arm
        self.ear, self.inner = EARS[ear]
        self.beady = head_w < 8                                   # a narrow head has no room for whites of the eyes
        self.brow, self.eye, self.nose, self.mouth = (self.y1 - n for n in (4, 3, 2, 1))

    def edge(self, y):
        """Where the chest ends on row `y`. Broad shoulders narrow down to the hips, and the arms hang off
        whatever edge they find there, so they never float away from a tapered body."""
        span = max(1, self.hip - self.shoulder)
        t = min(max(y - self.shoulder, 0), span) / span
        return (round(self.tx[0] + (self.lx[0] - self.tx[0]) * t),
                round(self.tx[1] + (self.lx[1] - self.tx[1]) * t))

    @property
    def sx(self):
        """The head seen from the side: a pixel further forward, since the ear stays behind."""
        return (self.hx[0] + 1, self.hx[1])

    @property
    def stx(self):
        """The chest seen from the side: shallower than it is wide, and never more than six pixels deep."""
        w = min(self.tx[1] - self.tx[0] - 1, 6)
        return (8 - (w + 1) // 2, 7 + (w + 1) // 2)


def legs_front(c, b, phase):
    x0, x1 = b.lx
    for x, lift in ((x0, 1 if phase == 1 else 0), (x1 - b.leg + 1, 1 if phase == 3 else 0)):
        c.rect(x, b.hip + 1, x + b.leg - 1, b.foot - lift, "g")


def arms_front(c, b, phase):
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    for side, lift in ((-1, swing), (1, -swing)):
        for y in range(b.shoulder + 1 + lift, b.hip + lift + 1):
            left, right = b.edge(y)
            x = left - 1 if side < 0 else right + 1
            far = x + side * (b.arm - 1)
            c.rect(min(x, far), y, max(x, far), y, "g")
            if b.arm > 1:
                c.put(x, y, "G")                                          # a seam, so thick arms still read


def body_front(c, b):
    x0, x1 = b.tx
    p0, p1 = b.lx
    for y in range(b.shoulder, b.hip + 1):                        # the chest tapers down to the hips
        left, right = b.edge(y)
        c.rect(left, y, right, y, "g")
    c.rect(x0 + 1, b.shoulder, x1 - 1, b.shoulder, "G")           # shadow under the chin
    c.rect(p0, b.hip - 1, p1, b.hip + 1, "b")                     # loincloth
    c.rect(p0, b.hip - 1, p1, b.hip - 1, "B")                     # belt
    c.cells([(p0, b.hip + 1), (p1, b.hip + 1)], None)             # tapered hem


def head_front(c, b):
    x0, x1 = b.hx
    for y in range(b.y0, b.y1 + 1):
        inset = 1 if y in (b.y0, b.y1) else 0
        c.rect(x0 + inset, y, x1 - inset, y, "g")
    ear = place(b.ear, x0, b.y0)
    c.cells(ear + mirror(ear), "g")


def face_front(c, b):
    x0, x1 = b.hx
    c.cells([(x0 + 1, b.y0), (x0 + 2, b.y0), (x0, b.y0 + 1), (x0, b.y0 + 2)], "h")
    c.cells([(x0 + 1, b.brow), (x0 + 2, b.brow), (x1 - 2, b.brow), (x1 - 1, b.brow)], "G")
    c.cells([(x0 + 1, b.eye), (x1 - 1, b.eye)], "y")
    if not b.beady:
        c.cells([(x0 + 2, b.eye), (x1 - 2, b.eye)], "e")
    c.cells([(7, b.nose), (8, b.nose)], "G")
    c.cells([(7, b.mouth), (8, b.mouth)], "k")
    c.cells([(6, b.mouth), (9, b.mouth)], "t")                    # tusks
    ix, iy = b.inner
    c.cells(mirror([(x0 + ix, b.y0 + iy)]) + [(x0 + ix, b.y0 + iy)], "r")


def goblin_front(phase, look):
    b = look.build
    c = Canvas()
    legs_front(c, b, phase)
    body_front(c, b)
    arms_front(c, b, phase)
    head_front(c, b)
    look.pre(c, "front", phase)
    c.outline()
    face_front(c, b)
    look.post(c, "front", phase)
    return c


def goblin_back(phase, look):
    b = look.build
    c = Canvas()
    legs_front(c, b, phase)
    body_front(c, b)
    arms_front(c, b, phase)
    head_front(c, b)
    x0, x1 = b.hx
    c.rect(x0 + 1, b.y0, x1 - 1, b.y0, look.hair)                 # hair on the crown
    c.rect(x0 + 2, b.y0 + 1, x1 - 2, b.y0 + 1, look.hair)
    c.rect(x0 + 1, b.y1 - 1, x1 - 1, b.y1, "G")                   # the back of the head, in shade
    look.pre(c, "back", phase)
    c.outline()
    ix, iy = b.inner
    c.cells(mirror([(x0 + ix, b.y0 + iy)]) + [(x0 + ix, b.y0 + iy)], "r")
    look.post(c, "back", phase)
    return c


def legs_side(c, b, phase):
    y0, y1, w = b.hip + 1, b.foot, b.leg
    if phase in (0, 2):                                           # mid-stride: the legs are apart
        (back, front), lift = ((6, 5 + w), (11 - w, 10)), (0, 0)
    else:                                                         # passing: one leg lifts past the other
        (back, front), lift = ((7, 6 + w), (10 - w, 9)), ((1, 0) if phase == 3 else (0, 1))
    c.rect(back[0], y0, back[1], y1 - lift[0], "G")               # far leg, in shade
    c.rect(front[0], y0, front[1], y1 - lift[1], "g")


def body_side(c, b, phase):
    x0, x1 = b.stx
    c.rect(x0, b.shoulder, x1, b.hip, "g")
    c.rect(x0, b.shoulder, x1, b.shoulder, "G")
    c.rect(x0, b.hip - 1, x1, b.hip + 1, "b")
    c.rect(x0, b.hip - 1, x1, b.hip - 1, "B")
    c.cells([(x0, b.hip + 1), (x1, b.hip + 1)], None)
    arm_x = {0: x1 - 1, 1: x1, 2: x1 - 1, 3: x0 + 1}[phase]       # the near arm swings
    c.rect(arm_x, b.shoulder + 1, arm_x, b.hip - (0 if phase in (0, 2) else 1), "G")


def head_side(c, b):
    x0, x1 = b.sx
    for y in range(b.y0, b.y1 + 1):
        c.rect(x0 + (1 if y == b.y1 else 0), y, x1 - (1 if y in (b.y0, b.y1) else 0), y, "g")
    c.cells([(x1 + 1, b.eye), (x1 + 1, b.nose), (x1 + 2, b.nose)], "g")     # big pointed nose
    c.cells(place(b.ear, x0, b.y0), "g")                                     # ear swept back


def face_side(c, b):
    x0, x1 = b.sx
    c.cells([(x0 + 1, b.y0), (x0 + 2, b.y0), (x0, b.y0 + 1)], "h")
    c.cells([(x1 - 2, b.brow), (x1 - 1, b.brow)], "G")
    c.put(x1 - 2, b.eye, "y")
    c.put(x1 - 1, b.eye, "e")
    c.cells([(x1 - 2, b.mouth), (x1, b.mouth)], "k")
    c.put(x1 - 1, b.mouth, "t")
    ix, iy = b.inner
    c.put(x0 + ix, b.y0 + iy, "r")


def goblin_side(phase, look):
    b = look.build
    c = Canvas()
    legs_side(c, b, phase)
    body_side(c, b, phase)
    head_side(c, b)
    look.pre(c, "side", phase)
    c.outline()
    face_side(c, b)
    look.post(c, "side", phase)
    return c


# --- icon: the goblin's face -------------------------------------------------------------------------------------
def goblin_face():
    """A close-up of the head, used for the menu bar icon and the app icon."""
    c = Canvas()
    for y, (x0, x1) in {3: (6, 9), 4: (5, 10), 5: (4, 11), 6: (4, 11), 7: (4, 11), 8: (4, 11), 9: (4, 11), 10: (4, 11),
                        11: (5, 10), 12: (6, 9)}.items():
        c.rect(x0, y, x1, y, "g")
    ear = [(1, 2), (1, 3), (2, 3), (1, 4), (2, 4), (3, 4), (4, 4), (2, 5), (3, 5), (3, 6)]
    c.cells(ear + mirror(ear), "g")
    c.outline()
    c.cells([(6, 3), (7, 3), (5, 4)], "h")
    c.cells([(2, 4), (13, 4), (2, 3), (13, 3)], "r")                          # inner ears
    c.cells([(4, 5), (5, 5), (6, 6), (11, 5), (10, 5), (9, 6)], "G")          # angry brows
    c.cells([(5, 7), (5, 8), (10, 7), (10, 8)], "y")
    c.cells([(6, 7), (6, 8), (9, 7), (9, 8)], "e")
    c.cells([(7, 8), (8, 8), (7, 9), (8, 9)], "G")                            # nose
    c.cells([(6, 10), (7, 10), (8, 10), (9, 10)], "k")
    c.cells([(5, 9), (5, 10), (10, 9), (10, 10)], "t")                        # tusks
    return c


# --- the human girl ---------------------------------------------------------------------------------------------
# She is drawn once per outfit: the same hair and face, different clothes. An outfit says what she wears on top
# (`sleeves`), below (`bottom`: dress, gown, skirt, shorts, pants, coat) and on her head (`hat`), plus its colours.
# Q/q = top and its shade, D/d = skirt or trousers and their shade, K = shoes, U/u = hat, A = accent, T = tights.
GIRL.update({"Q": (96, 138, 214), "q": (66, 100, 178), "T": (76, 60, 84), "U": (232, 200, 130), "u": (196, 160, 90),
             "A": (224, 64, 88), "V": (196, 116, 52), "C": (150, 160, 172), "X": (110, 182, 240), "a": (170, 40, 60)})

OUTFITS = [
    dict(id="dress", name="洋裝", bottom="dress", sleeves="puff", hat="tiara",
         pal={}),
    dict(id="gown", name="長裙禮服", bottom="gown", sleeves="puff", hat="tiara",
         pal={"Q": (214, 120, 170), "q": (170, 84, 132), "D": (214, 120, 170), "d": (170, 84, 132), "W": (255, 240, 250),
              "R": (255, 214, 120)}),
    dict(id="skirt", name="短裙上衣", bottom="skirt", sleeves="puff", hat="tiara",
         pal={"Q": (255, 240, 240), "q": (226, 196, 204), "D": (90, 160, 110), "d": (60, 120, 80), "R": (224, 64, 88)}),
    dict(id="sport", name="運動裝", bottom="shorts", sleeves="none", hat="band",
         pal={"Q": (240, 110, 90), "q": (200, 80, 70), "D": (70, 110, 190), "d": (48, 78, 150), "K": (246, 246, 246),
              "A": (255, 255, 255)}),
    dict(id="sunny", name="草帽洋裝", bottom="dress", sleeves="none", hat="straw",
         pal={"Q": (250, 214, 90), "q": (220, 170, 50), "D": (250, 214, 90), "d": (220, 170, 50), "W": (255, 246, 214),
              "R": (224, 64, 88), "A": (224, 64, 88)}),
    dict(id="winter", name="冬季外套", bottom="coat", sleeves="long", hat="beret",
         pal={"Q": (190, 50, 60), "q": (140, 34, 46), "D": (190, 50, 60), "d": (140, 34, 46), "U": (190, 50, 60),
              "u": (140, 34, 46), "A": (80, 130, 200), "K": (94, 62, 46)}),
    dict(id="pajamas", name="睡衣", bottom="pants", sleeves="long", hat="cap",
         pal={"Q": (250, 200, 215), "q": (222, 164, 184), "D": (250, 200, 215), "d": (222, 164, 184), "U": (140, 170, 230),
              "u": (104, 132, 196), "K": (240, 170, 190)}),
]


def girl_lower(c, phase, o, apart=False):
    """Skirt, trousers or coat hem, the legs that show below, and the shoes."""
    kind = o["bottom"]
    left = (6, 7) if phase == 1 else (5, 6)
    right = (8, 9) if phase == 3 else (9, 10)
    if kind == "gown":                                    # reaches the floor: no legs or shoes to see
        c.rect(4, 12, 11, 12, "D")
        c.rect(3, 13, 12, 13, "D")
        c.rect(3, 14, 12, 14, "W")
        c.cells([(4, 12), (11, 12), (3, 13), (12, 13)], "d")
        return
    if kind == "dress":
        c.rect(4, 12, 11, 12, "D")                        # flares out to a white hem
        c.rect(3, 13, 12, 13, "W")
        c.cells([(4, 12), (11, 12), (5, 13), (10, 13)], "d")
    elif kind == "skirt":                                 # short: legs show
        c.rect(4, 12, 11, 12, "D")
        c.cells([(4, 12), (11, 12)], "d")
        c.cells([(6, 13), (9, 13)], "s")
    elif kind == "shorts":
        c.rect(5, 12, 10, 12, "D")
        c.cells([(5, 12), (10, 12)], "d")
        c.cells([(6, 13), (9, 13)], "s")
    elif kind == "pants":
        c.rect(5, 12, 10, 12, "D")
        c.rect(5, 13, 6, 13, "D")
        c.rect(9, 13, 10, 13, "D")
    elif kind == "coat":
        c.cells([(6, 13), (9, 13)], "T")                  # tights
    if apart:
        left, right = (3, 4), (11, 12)
    c.rect(left[0], 14, left[1], 14, "K")
    c.rect(right[0], 14, right[1], 14, "K")


def girl_upper(c, phase, o, back, arms=True):
    kind = o["bottom"]
    coat = kind == "coat"
    c.rect(4 if coat else 5, 10, 11 if coat else 10, 12 if coat else 11, "Q")
    if back:
        if kind in ("dress", "gown"):
            c.cells([(6, 10), (7, 10), (8, 10), (9, 10), (7, 11), (8, 11)], "R")    # a big bow at the back
    elif coat:
        c.cells([(7, 11), (7, 12), (8, 10)], "W")                                    # buttons
        c.rect(5, 10, 10, 10, "A")                                                   # scarf
        c.cells([(5, 11), (5, 12)], "A")
    elif kind in ("dress", "gown"):
        c.cells([(7, 10), (8, 10)], "W")                                             # collar
        c.cells([(7, 11), (8, 11)], "R")                                             # a small bow at the waist
    elif kind == "pants":
        c.cells([(7, 10), (7, 11)], "W")                                             # pyjama buttons
    elif o["sleeves"] == "none":
        c.cells([(7, 10), (8, 10)], "s")                                             # the neck of a tank top
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    for x, sign in (((3 if coat else 4), 1), ((12 if coat else 11), -1)) if arms else ():
        dy = sign * swing if swing else 0
        if o["sleeves"] == "puff":
            c.put(x, 10 + dy, "Q")
            c.put(x, 11 + dy, "s")
        elif o["sleeves"] == "none":
            c.put(x, 10 + dy, "s")
            c.put(x, 11 + dy, "s")
        else:                                                                        # long sleeves, small hand
            c.put(x, 10 + dy, "Q")
            c.put(x, 11 + dy, "Q")
            c.put(x, 12 + dy, "s")


def girl_head_top(c, o, side=False):
    """Hair on top, then whatever she wears on it."""
    hat = o["hat"]
    c.rect(4, 2, 11, 3, "H")
    c.cells([(6, 3), (7, 3)], "h")
    x0, x1 = (5, 10) if side else (4, 11)
    if hat == "tiara":
        c.rect(6, 2, 9, 2, "c")
        c.cells([(7, 1), (8, 1)], "c")
    elif hat == "straw":
        c.rect(2, 3, 13, 3, "U")                            # a wide brim
        c.rect(x0, 2, x1, 2, "A")                           # ribbon
        c.rect(x0 + 1, 1, x1 - 1, 1, "U")
        c.cells([(2, 3), (13, 3)], "u")
    elif hat == "beret":
        c.rect(3, 2, 12, 2, "U")
        c.rect(5, 1, 10, 1, "U")
        c.cells([(3, 2), (4, 2)], "u")
    elif hat == "cap":                                      # a night cap with a bobble
        c.rect(4, 2, 11, 2, "U")
        c.rect(5, 1, 9, 1, "U")
        c.cells([(12, 2), (12, 3), (12, 4)], "U")
        c.put(12, 5, "W")
    elif hat == "band":                                     # a sweatband
        c.rect(4, 3, 11, 3, "A")


def girl_front(phase, o, arms=True, mouth="smile", eyes="open", extra=None, apart=False):
    c = Canvas()
    girl_lower(c, phase, o, apart=apart)
    girl_upper(c, phase, o, back=False, arms=arms)
    c.rect(3, 4, 4, 9, "H")                                 # shoulder-length hair on both sides
    c.rect(11, 4, 12, 9, "H")
    girl_head_top(c, o)
    c.rect(5, 4, 10, 8, "s")                                # face
    c.rect(6, 9, 9, 9, "s")
    c.cells([(5, 4), (6, 4), (9, 4), (10, 4), (5, 5), (10, 5)], "H")     # bangs
    c.cells([(7, 4), (8, 4)], "s")
    c.cells([(3, 9), (12, 9)], "J")
    if extra:
        extra(c)                                            # arms and things she holds, in front of the hair
    c.outline()
    if eyes == "open":
        c.cells([(5, 6), (6, 6), (9, 6), (10, 6)], "L")                  # eyes
        c.cells([(5, 7), (10, 7)], "i")
        c.cells([(6, 7), (9, 7)], "w")
    else:                                                   # looking down, or closed
        c.cells([(5, 7), (6, 7), (9, 7), (10, 7)], "L")
    c.cells([(5, 8), (10, 8)], "p")
    if mouth == "open":
        c.cells([(7, 8), (8, 8), (7, 9), (8, 9)], "m")
    elif mouth == "wide":
        c.cells([(7, 8), (8, 8), (6, 9), (7, 9), (8, 9), (9, 9)], "m")
    elif mouth != "hidden":
        c.cells([(7, 8), (8, 8)], "m")
    return c


def girl_back(phase, o):
    c = Canvas()
    girl_lower(c, phase, o)
    girl_upper(c, phase, o, back=True)
    c.rect(3, 4, 12, 9, "H")                                # hair covers the whole back of the head
    c.rect(4, 8, 11, 9, "J")
    girl_head_top(c, o)
    c.cells([(7, 5), (8, 5), (6, 6), (9, 6)], "h")
    c.outline()
    return c


def girl_side(phase, o):
    c = Canvas()
    kind = o["bottom"]
    # skirt or trousers and legs
    if kind == "gown":
        c.rect(5, 12, 10, 12, "D")
        c.rect(4, 13, 11, 13, "D")
        c.rect(4, 14, 11, 14, "W")
    else:
        if kind == "dress":
            c.rect(5, 12, 10, 12, "D")
            c.rect(4, 13, 11, 13, "W")
            c.cells([(5, 12), (10, 12)], "d")
        elif kind == "skirt":
            c.rect(5, 12, 10, 12, "D")
            c.cells([(7, 13), (9, 13)], "s")
        elif kind == "shorts":
            c.rect(6, 12, 9, 12, "D")
            c.cells([(7, 13), (9, 13)], "s")
        elif kind == "pants":
            c.rect(6, 12, 9, 12, "D")
            c.cells([(7, 13), (9, 13)], "D")
        elif kind == "coat":
            c.rect(5, 12, 10, 12, "Q")
            c.cells([(7, 13), (9, 13)], "T")
        if phase in (0, 2):                                 # shoes
            c.rect(6, 14, 7, 14, "K")
            c.rect(9, 14, 10, 14, "K")
        else:
            c.rect(7, 14, 9, 14, "K")
    # top
    coat = kind == "coat"
    c.rect(5 if coat else 6, 10, 10 if coat else 9, 12 if coat else 11, "Q")
    if coat:
        c.rect(5, 10, 10, 10, "A")                          # scarf
    elif kind in ("dress", "gown"):
        c.put(6, 11, "R")
    arm_x, y0 = {0: (8, 10), 1: (9, 10), 2: (8, 10), 3: (7, 10)}[phase]
    if o["sleeves"] == "puff":
        c.put(arm_x, y0, "Q")
        c.put(arm_x, y0 + 1, "s")
    elif o["sleeves"] == "none":
        c.put(arm_x, y0, "s")
        c.put(arm_x, y0 + 1, "s")
    else:
        c.put(arm_x, y0, "Q")
        c.put(arm_x, y0 + 1, "Q")
        c.put(arm_x, y0 + 2, "s")
    # hair flowing behind, fringe in front
    c.rect(4, 3, 8, 10, "H")
    c.rect(5, 2, 10, 2, "H")
    c.rect(4, 9, 6, 10, "J")
    c.rect(5, 3, 11, 3, "H")
    c.rect(9, 4, 11, 4, "H")
    # face in profile
    c.rect(9, 5, 11, 8, "s")
    c.rect(9, 9, 10, 9, "s")
    c.put(12, 6, "s")                                       # nose
    girl_head_top(c, o, side=True)
    c.outline()
    c.put(10, 6, "L")
    c.put(10, 7, "i")
    c.put(11, 8, "m")
    c.put(10, 8, "p")
    return c


# --- poses -----------------------------------------------------------------------------------------------------------
# Front-facing action frames, four per row, added below the walking rows of every outfit's sheet. Arms and the things
# she holds are drawn before the outline so they become part of her silhouette.
def _sleeve_key(o):
    return "s" if o["sleeves"] == "none" else "Q"


def arm(c, o, pts):
    """An arm along `pts` (shoulder first, hand last): sleeve colour, then bare hand."""
    for x, y in pts[:-1]:
        c.put(x, y, _sleeve_key(o))
    c.put(pts[-1][0], pts[-1][1], "s")


def _down(c, o):
    arm(c, o, [(4, 10), (4, 11)])
    arm(c, o, [(11, 10), (11, 11)])


def pose_tea(f, o):
    hands = [(12, 11), (11, 10), (10, 9), (11, 10)][f]
    cup = [(12, 9), (11, 8), (9, 7), (11, 8)][f]

    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        arm(c, o, [(11, 10), hands])
        x, y = cup
        c.cells([(x, y), (x + 1, y)], "V")                  # the tea
        c.cells([(x, y + 1), (x + 1, y + 1)], "W")          # the cup
        c.put(x + 2, y + 1, "W")                            # its handle
    return girl_front(0, o, arms=False, mouth="hidden" if f == 2 else "smile", extra=extra)


def pose_exercise(f, o):
    up = f in (1, 3)

    def extra(c):
        if not up:
            _down(c, o)
        elif f == 1:
            arm(c, o, [(4, 10), (3, 9), (2, 8)])
            arm(c, o, [(11, 10), (12, 9), (13, 8)])
        else:
            arm(c, o, [(4, 10), (3, 9), (3, 7)])
            arm(c, o, [(11, 10), (12, 9), (12, 7)])
    return girl_front(0, o, arms=False, mouth="open" if up else "smile", extra=extra, apart=up)


def pose_read(f, o):
    def extra(c):
        c.rect(5, 10, 10, 12, "W")                          # an open book held at her chest
        c.rect(5, 10, 5, 12, "A")
        c.rect(10, 10, 10, 12, "A")
        c.rect(7, 10, 8, 12, "a")
        c.cells([(6, 11), (9, 11)], "L")
        if f in (1, 3):
            c.cells([(9, 9), (10, 9)], "W")                 # a page turning
        c.put(4, 12, "s")
        c.put(11, 12, "s")
    return girl_front(0, o, arms=False, eyes="down", extra=extra)


def pose_water(f, o):
    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        arm(c, o, [(11, 10), (11, 11)])
        c.rect(11, 10, 13, 12, "C")                         # the watering can
        c.put(10, 10, "C")
        spout_y = [10, 10, 11, 10][f]
        c.cells([(14, spout_y), (14, spout_y - 1)] if f == 0 else [(14, spout_y), (14, spout_y - (0 if f == 2 else 1))], "C")
        if f in (1, 2, 3):
            c.cells([(14, 12), (14, 14)] if f == 2 else [(14, 12)], "X")                     # drops
    return girl_front(0, o, arms=False, extra=extra)


def pose_comb(f, o):
    y = 6 if f in (0, 2) else 5

    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        arm(c, o, [(11, 10), (12, 8), (12, y)])
        c.cells([(13, y - 1), (13, y), (13, y + 1)], "A")   # the comb
    return girl_front(0, o, arms=False, extra=extra)


def pose_sing(f, o):
    def extra(c):
        arm(c, o, [(4, 10), (5, 11), (6, 11), (7, 11)])
        arm(c, o, [(11, 10), (10, 11), (9, 11), (8, 11)])
    return girl_front(0, o, arms=False, mouth=["smile", "open", "wide", "open"][f], extra=extra)


def pose_dance(f, o):
    def extra(c):
        if f == 0:
            arm(c, o, [(4, 10), (3, 8), (3, 6)])
            arm(c, o, [(11, 10), (12, 11)])
        elif f == 2:
            arm(c, o, [(4, 10), (3, 11)])
            arm(c, o, [(11, 10), (12, 8), (12, 6)])
        else:
            arm(c, o, [(4, 10), (3, 11)])
            arm(c, o, [(11, 10), (12, 11)])
    return girl_front(0, o, arms=False, mouth="open", extra=extra, apart=f in (1, 3))


def pose_wave(f, o):
    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        arm(c, o, [(11, 10), (12, 8), (13 if f in (0, 2) else 12, 6)])
    return girl_front(0, o, arms=False, mouth="open", extra=extra)


def pose_yawn(f, o):
    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        if f == 0:
            arm(c, o, [(11, 10), (11, 9), (10, 8)])         # a hand over the mouth
        else:
            arm(c, o, [(11, 10), (12, 8), (12, 6)])
    return girl_front(0, o, arms=False, mouth="wide", eyes="down", extra=extra)


def pose_think(f, o):
    def extra(c):
        arm(c, o, [(4, 10), (4, 11)])
        arm(c, o, [(11, 10), (11, 9), (9, 9)])              # a finger at the chin
    return girl_front(0, o, arms=False, extra=extra, mouth="hidden")


# name, drawing function, number of distinct frames
POSES = [("tea", pose_tea, 4), ("exercise", pose_exercise, 4), ("read", pose_read, 4), ("water", pose_water, 4),
         ("comb", pose_comb, 4), ("sing", pose_sing, 4), ("dance", pose_dance, 4), ("wave", pose_wave, 4),
         ("yawn", pose_yawn, 2), ("think", pose_think, 2)]


def face_image():
    canvas = goblin_face()
    return [[(WORKER[canvas.px[y][x]] + (255,)) if canvas.px[y][x] else (0, 0, 0, 0) for x in range(SIZE)] for y in range(SIZE)]


# --- breeds -----------------------------------------------------------------------------------------------------
class Look:
    """A breed's look: the body it is drawn on, its own skin colours, the colour of its hair, and accessories
    drawn either before the outline (so they become part of the silhouette) or after it (details on top)."""

    def __init__(self, palette=None, build=None, hair="B", pre=None, post=None):
        self.palette = dict(WORKER, R=(176, 52, 56), r2=(126, 34, 42), P=(60, 84, 176),
                            W=(244, 244, 236), S=(196, 198, 190), **(palette or {}))
        self.build = build or Build()
        self.hair = hair
        self._pre, self._post = pre, post

    def pre(self, c, view, phase):
        if self._pre:
            self._pre(c, view, phase)

    def post(self, c, view, phase):
        if self._post:
            self._post(c, view, phase)


def scout_pre(c, view, phase):
    """A red headband and a topknot on a small, light goblin: head low, ears high, legs like sticks."""
    if view == "side":
        c.rect(6, 4, 10, 4, "R")
        c.cells([(4, 3), (5, 3), (6, 3)], "B")                    # the topknot streams back
    else:
        c.rect(5, 4, 10, 4, "R")
        c.cells([(7, 3), (8, 3)], "B")
    if view == "back":
        c.rect(7, 9, 8, 10, "B")                                  # the tail of it, down the neck


def brute_pre(c, view, phase):
    """A mohawk and strapped shoulder pads: a small head sunk into a chest twice the usual width."""
    if view == "side":
        c.rect(6, 2, 9, 2, "B")
        c.rect(5, 8, 6, 8, "B")
    else:
        c.cells([(7, 1), (8, 1), (7, 2), (8, 2)], "B")
        c.rect(3, 8, 4, 8, "B")
        c.rect(11, 8, 12, 8, "B")


def brute_post(c, view, phase):
    """Tusks that reach up past the nose."""
    if view == "side":
        c.put(9, 5, "t")
    elif view == "front":
        c.cells([(6, 5), (9, 5)], "t")


def sage_pre(c, view, phase):
    """A pointed hat and a beard down to the belly on a stooped little body: the hat gives back the height
    the short legs take away."""
    c.rect(4 if view == "side" else 3, 2, 11 if view == "side" else 12, 2, "P")
    c.rect(6, 1, 9, 1, "P")
    c.cells([(7, 0), (8, 0)], "P")
    if view == "back":
        c.rect(5, 3, 10, 8, "W")                                  # long white hair over the back of the head
        c.rect(5, 7, 10, 8, "S")
    elif view == "side":
        c.rect(9, 8, 11, 9, "W")
        c.cells([(9, 10), (10, 10), (11, 9)], "S")
    else:
        c.rect(6, 8, 9, 9, "W")
        c.cells([(7, 10), (8, 10)], "W")
        c.cells([(6, 9), (9, 9), (7, 11)], "S")


def sage_post(c, view, phase):
    c.put(7, 1, "y")                                              # a star on the hat
    c.put(8, 1, "y")


def golden_pre(c, view, phase):
    """A circlet, pale hair to the shoulders and a cape: the plain goblin's build, carried like royalty."""
    band = (6, 10) if view == "side" else (5, 10)
    c.rect(band[0], 1, band[1], 1, "W")
    c.cells([(band[0], 0), (7, 0), (8, 0), (band[1], 0)], "W")       # three points
    if view == "back":
        c.rect(4, 3, 11, 8, "W")                                  # hair over the whole back of the head
        c.rect(4, 7, 11, 8, "S")
    else:
        near, far = (5, 5) if view == "side" else (3, 12)
        c.rect(near, 6, near, 8, "W")                             # hair falling past the ears
        c.rect(far, 6, far, 8, "W")
    robe = (6, 9) if view == "side" else (5, 10)                  # a robe to the floor, not a loincloth
    c.rect(robe[0], 9, robe[1], 11, "R")
    c.rect(robe[0] - 1, 12, robe[1] + 1, 12, "R")
    c.rect(robe[0] - 2, 13, robe[1] + 2, 13, "W")
    c.cells([(robe[0] - 1, 13), (robe[1] + 1, 13)], "S")


def golden_post(c, view, phase):
    for x, y in ((1, 1), (14, 2), (0, 9), (15, 8)):
        c.put(x, y, "W")


BREEDS = [
    # id, name, weight, boost, blurb, stats, sheet, look
    ("common", "平民", 100, 0, "最普通的哥布林，什麼都會一點。", {}, "worker.png", Look()),
    ("scout", "敏捷", 10, 1.0, "瘦小、腿快、眼尖，但一次只拿得動一份，也比較短命。",
     {"speed": 1.35, "sense": 1.3, "rest": 0.8, "lifespan": 0.8}, "scout.png",
     Look({"g": (150, 196, 84), "G": (112, 160, 58), "h": (190, 226, 120)},
          build=Build(head=(4, 8), head_w=6, chest=4, hip=11, leg=1, ear="long"), pre=scout_pre)),
    ("brute", "壯碩", 8, 1.0, "身強體壯，走得慢，一次搬兩份，活得也久。",
     {"speed": 0.8, "sense": 0.9, "carry": 2, "rest": 1.2, "lifespan": 1.25}, "brute.png",
     Look({"g": (96, 140, 52), "G": (66, 104, 36), "h": (130, 172, 80)},
          build=Build(head=(3, 7), head_w=6, chest=8, hip=11, leg=2, arm=2, ear="stub"),
          pre=brute_pre, post=brute_post)),
    ("sage", "聰明", 5, 1.5, "愛動腦筋，很會找食物，也很會叫同伴來幫忙。",
     {"speed": 0.95, "sense": 1.25, "recruit": 3, "lifespan": 1.15}, "sage.png",
     Look({"g": (86, 168, 138), "G": (56, 124, 100), "h": (130, 205, 176)},
          build=Build(head=(3, 8), chest=6, hip=12, ear="droop"), hair="W",
          pre=sage_pre, post=sage_post)),
    ("golden", "金皮", 1, 3.0, "罕見的金皮哥布林，每一方面都好一點，壽命是兩倍。",
     {"speed": 1.1, "sense": 1.1, "recruit": 1, "rest": 0.9, "lifespan": 2.0}, "golden.png",
     Look({"g": (238, 196, 60), "G": (200, 150, 30), "h": (255, 232, 120)}, hair="W",
          pre=golden_pre, post=golden_post)),
]


def build_sheet(queen, look=None, outfit=None):
    outfit = outfit or OUTFITS[0]
    pal = dict(GIRL, **outfit["pal"]) if queen else (look.palette if look else WORKER)
    rows = [girl_front, girl_back, girl_side] if queen else [goblin_front, goblin_back, goblin_side]
    pose_rows = len(POSES) if queen else 0
    w, h = 4 * SIZE, (len(rows) + pose_rows) * SIZE
    img = [[(0, 0, 0, 0)] * w for _ in range(h)]
    if queen:
        for r, (_name, draw, count) in enumerate(POSES):
            for f in range(count):
                canvas = draw(f, outfit)
                for y in range(SIZE):
                    for x in range(SIZE):
                        key = canvas.px[y][x]
                        if key is not None:
                            img[(len(rows) + r) * SIZE + y][f * SIZE + x] = pal[key] + (255,)
    for r, draw in enumerate(rows):
        for phase in range(4):
            canvas = draw(phase, outfit) if queen else draw(phase, look or Look())
            for y in range(SIZE):
                for x in range(SIZE):
                    key = canvas.px[y][x]
                    if key is not None:
                        img[r * SIZE + y][phase * SIZE + x] = pal[key] + (255,)
    return img


# --- PNG output (no dependencies) --------------------------------------------------------------------------------
def write_png(path, img):
    h, w = len(img), len(img[0])
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in img)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def preview(path, zoom=8):
    """Contact sheet: every breed (front, back, side, mirrored side, walk phases 0 and 1) plus the girl."""
    sheets = [build_sheet(False, b[7]) for b in BREEDS] + [build_sheet(True, outfit=o) for o in OUTFITS]
    gap = 1
    cols = 4 * 3 + 2 * gap
    w = cols * SIZE * zoom
    h = len(sheets) * SIZE * zoom
    bg = (222, 222, 222, 255)
    out = [[bg] * w for _ in range(h)]

    def blit(sheet, sx, sy, dx, dy, flip=False):
        for y in range(SIZE):
            for x in range(SIZE):
                px = sheet[sy + y][sx + (SIZE - 1 - x if flip else x)]
                if px[3]:
                    for oy in range(zoom):
                        for ox in range(zoom):
                            out[(dy + y) * zoom + oy][(dx + x) * zoom + ox] = px

    for r, sheet in enumerate(sheets):
        col = 0
        for view in range(3):                       # down, up, side: phases 0 and 1
            for phase in (0, 1):
                blit(sheet, phase * SIZE, view * SIZE, col * SIZE, r * SIZE)
                col += 1
        for phase in (0, 1):                        # side, mirrored
            blit(sheet, phase * SIZE, 2 * SIZE, (col) * SIZE, r * SIZE, flip=True)
            col += 1
    write_png(path, out)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Characters", "goblin")
    os.makedirs(root, exist_ok=True)
    for _id, _name, _w, _b, _blurb, _stats, sheet, look in BREEDS:
        write_png(os.path.join(root, sheet), build_sheet(False, look))
    for o in OUTFITS:
        write_png(os.path.join(root, "queen.png" if o["id"] == "dress" else f"queen_{o['id']}.png"), build_sheet(True, outfit=o))
    write_png(os.path.join(root, "icon.png"), face_image())
    walk = {"down": [0, 1, 2, 3], "up": [4, 5, 6, 7], "side": [8, 9, 10, 11]}
    manifest = {
        "id": "goblin",
        "name": "哥布林",
        "noun": "哥布林",
        "emoji": "👺",
        "icon": "icon.png",
        "nestName": "營地",
        "frame": SIZE,
        "defaultMaxCount": 150,
        "worker": {"sheet": "worker.png", "pixelScale": 1.5, "walk": walk},
        "breeds": [{"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet}
                   for i, n, w, b, blurb, stats, sheet, _ in BREEDS],
        "queen": {"sheet": "queen.png", "pixelScale": 2.0, "walk": walk,
                  "poses": {name: [(3 + r) * 4 + f for f in range(count)] for r, (name, _d, count) in enumerate(POSES)},
                  "outfits": [{"id": o["id"], "name": o["name"], "sheet": "queen.png" if o["id"] == "dress" else f"queen_{o['id']}.png"}
                              for o in OUTFITS]},
    }
    with open(os.path.join(root, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("wrote", os.path.normpath(root))


if __name__ == "__main__":
    main()
