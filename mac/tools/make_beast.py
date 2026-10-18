#!/usr/bin/env python3
"""Draws the beastfolk (獸人, the fourth race, see RACES_BEAST.md) as 16x16 pixel-art sprite sheets, in the goblins' layout
(4 walk phases x front, back, side). One tribe, three peoples: wolves, foxes and a minotaur. Not cute animals but warriors
(the user: 「有點像動物不像獸人，獸人要生猛一點」): a small head on broad shoulders with fur pauldrons, heavy brows over glowing
eyes, fangs, war paint, thick arms and legs, and each one armed.

  灰狼 (common), 赤狐 (scout), 牛頭人 (brute), 銀狐 (sage), 白狼王 (golden, the chief).
  森之子 — the children of the white wolf king and the elf princess (three leanings: beast, half, elf).
Calm, day to day; fierce only on full-moon nights (`frenzy_sheet`): the wolves and foxes drop to all fours and run, the
minotaur charges head down, the white wolf king draws his bone sword, and the silver fox's staff burns.
Their princess is an elf princess (the same girl as the undead's), here in a hide-and-fur tribal dress.

    python3 tools/make_beast.py --preview /path/p.png      # a contact sheet only
    python3 tools/make_beast.py --write                    # also writes Resources/Characters/beast/*
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_goblin as mg  # noqa: E402
import make_elf as me  # noqa: E402  (the elf head and body, for the children)

SIZE = mg.SIZE
Canvas = mg.Canvas

BASE = {
    "O": (46, 34, 30),                                                  # outline
    "e": (36, 26, 26), "k": (40, 30, 30), "p": (240, 160, 160), "r": (226, 150, 150),   # eye, nose, blush, inner ear
    "y": (255, 214, 80),                                                # glowing eyes (full moon)
    "q": (220, 96, 110),                                                # tongue
    "V": (150, 104, 64), "v": (112, 76, 46),                            # hide
    "b": (240, 232, 210), "c": (252, 246, 236),                         # bone, cream
    "R": (178, 54, 48), "Rd": (130, 36, 34),                            # red cloth
    "U": (78, 110, 160), "u": (56, 82, 126),                            # blue robe
    "Y": (240, 200, 90),                                                # gold
    "G": (96, 156, 84),                                                 # leaf, feather
    "I": (196, 202, 212), "i": (128, 136, 150),                         # iron and its shade
    "x": (236, 64, 48),                                                 # a bull's angry red eye
}
# fur: main, shade, light (muzzle, belly)
FUR = {
    "wolf": ((150, 152, 164), (112, 114, 128), (222, 222, 228)),
    "fox": ((232, 128, 54), (184, 88, 36), (252, 244, 232)),
    "silver": ((200, 204, 218), (138, 144, 166), (250, 250, 252)),
    "bull": ((140, 92, 58), (104, 66, 40), (200, 156, 112)),
    "white": ((244, 244, 250), (176, 182, 204), (255, 255, 255)),
}
HORN = ((236, 224, 196), (190, 176, 150))


def palette(fur, **more):
    f, s, l = FUR[fur]
    return dict(BASE, F=f, f=s, L=l, H=HORN[0], h=HORN[1], **more)


# --- the upright body -------------------------------------------------------------------------------------------------
def legs(c, view, phase, wide=False, foot="f", leg="F"):
    if view == "side":
        if phase in (0, 2):
            c.rect(6, 12, 6, 13, leg); c.cells([(6, 14), (5, 14)], foot)
            c.rect(9, 12, 9, 13, leg); c.cells([(9, 14), (10, 14)], foot)
        else:
            lift = (1, 0) if phase == 3 else (0, 1)
            c.rect(7, 12, 7, 13 - lift[0], leg); c.put(7, 14 - lift[0], foot)
            c.rect(8, 12, 8, 13 - lift[1], leg); c.cells([(8, 14 - lift[1]), (9, 14 - lift[1])], foot)
        return
    for x, lift in ((6, 1 if phase == 1 else 0), (9, 1 if phase == 3 else 0)):
        w = 2 if wide else 1
        xx = x - (w - 1) if x == 6 else x
        c.rect(xx, 12, xx + w - 1, 13 - lift, leg)
        c.rect(xx, 14 - lift, xx + w - 1, 14 - lift, foot)


def torso(c, view, phase, cloth="V", shade="v", wide=False, robe=None, bare=False):
    """A hide vest (or a robe to the ground, or a bare furry chest with a loincloth) and furry arms."""
    x0, x1 = (5, 10) if wide else (6, 9)
    if view == "side":
        x0, x1 = (5, 10) if wide else (6, 9)
    if robe:
        for y in range(9, 15):
            spread = (y - 9) // 2
            c.rect(x0 - spread, y, x1 + spread, y, robe[0])
        c.rect(x0, 11, x1, 11, robe[1])
    elif bare:
        c.rect(x0, 9, x1, 11, "F")
        if view == "front":
            c.rect(x0 + 1, 9, x1 - 1, 10, "L")                              # a pale chest
        c.rect(x0, 11, x1, 12, cloth); c.rect(x0, 11, x1, 11, "v")         # loincloth and its belt
    else:
        c.rect(x0, 9, x1, 12, cloth)
        c.rect(x0, 11, x1, 11, "v")
        c.rect(x1, 9, x1, 12, shade)
        if view == "front":
            c.cells([(7, 9), (8, 9)], "L")                                  # fur at the collar
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    if view == "side":
        ax = {0: 8, 1: 9, 2: 8, 3: 6}[phase]
        c.rect(ax, 9, ax, 11, "F"); c.put(ax, 12 if phase in (0, 2) else 11, "f")
        return
    for x, s in ((x0 - 1, swing), (x1 + 1, -swing)):
        c.rect(x, 9 + s, x, 11 + s, "F")
        c.put(x, 12 + s, "f")                                               # the paw


def canine_head(c, view, ears="wolf", cheeks=False):
    """A round furry head (rows 2-8) with two pointed ears; a light muzzle and a dark nose in front."""
    if view == "side":
        c.rect(5, 2, 10, 2, "F"); c.rect(4, 3, 10, 7, "F"); c.rect(5, 8, 10, 8, "F")
        c.rect(11, 5, 12, 7, "L"); c.put(12, 5, "k")                        # the snout and its nose
        c.rect(4, 3, 4, 7, "f")
        c.rect(9, 4, 9, 4, "e")
        c.put(10, 8, "L")
        if ears == "fox":
            c.cells([(6, 0), (6, 1), (7, 1), (5, 1), (6, -1)], "F"); c.put(6, 1, "r")
        else:
            c.cells([(6, 0), (6, 1), (7, 1)], "F")
        if cheeks:
            c.cells([(3, 6), (3, 7)], "L")
        return
    c.rect(5, 2, 10, 2, "F"); c.rect(4, 3, 11, 7, "F"); c.rect(5, 8, 10, 8, "F")
    if ears == "fox":                                                       # big ears, pink inside
        left = [(3, 0), (4, 0), (3, 1), (4, 1), (5, 1), (3, -1)]
    else:
        left = [(4, 0), (4, 1), (5, 1)]
    c.cells(left + [(15 - x, y) for x, y in left], "F")
    if view == "back":
        c.rect(4, 6, 11, 8, "f")
        return
    c.cells([(4, 1), (11, 1)] if ears == "fox" else [(4, 1), (11, 1)], "r")
    c.rect(6, 6, 9, 8, "L"); c.cells([(5, 7), (10, 7)], "L")               # muzzle
    c.cells([(7, 6), (8, 6)], "k")                                          # nose
    c.cells([(5, 4), (10, 4)], "e"); c.cells([(5, 5), (10, 5)], "e")        # eyes
    c.cells([(4, 6), (11, 6)], "p")
    if cheeks:                                                              # fluffy cheeks past the face
        c.cells([(3, 6), (3, 7), (12, 6), (12, 7), (2, 7), (13, 7)], "L")


def bull_head(c, view):
    """A wide head with a broad pale muzzle, a gold nose ring and two horns curving up."""
    c.rect(4, 2, 11, 2, "F"); c.rect(3, 3, 12, 7, "F"); c.rect(4, 8, 11, 8, "F")
    horn = [(2, 3), (1, 3), (1, 2), (1, 1), (2, 0)]
    if view == "side":
        c.rect(4, 2, 10, 2, "F"); c.rect(4, 3, 10, 8, "F")
        c.rect(10, 5, 12, 8, "L"); c.put(12, 6, "k"); c.put(12, 8, "Y")
        c.put(8, 4, "e")
        c.cells([(6, 2), (6, 1), (7, 0), (8, 0)], "H"); c.put(8, 0, "h")
        c.cells([(4, 4), (3, 4)], "F")                                      # an ear
        return
    c.cells(horn + [(15 - x, y) for x, y in horn], "H")
    c.cells([(2, 0), (13, 0)], "h")
    c.cells([(2, 5), (13, 5)], "F")                                         # ears out to the side
    if view == "back":
        c.rect(3, 6, 12, 8, "f")
        return
    c.rect(5, 6, 10, 8, "L")
    c.cells([(6, 7), (9, 7)], "k")                                          # nostrils
    c.cells([(7, 8), (8, 8)], "Y")                                          # nose ring
    c.cells([(5, 4), (10, 4)], "e")
    c.cells([(6, 2), (7, 2), (8, 2), (9, 2)], "f")                          # a dark tuft on the brow


def tail(kind):
    def draw(c, view, phase):
        wag = 1 if phase in (1, 3) else 0
        if kind == "bull":
            if view == "back":
                c.rect(8, 11, 8, 13, "F"); c.put(8, 14, "f")
            elif view == "side":
                c.cells([(5, 11), (4, 12), (4, 13)], "F"); c.put(3, 13, "f")
            return
        tip = "L" if kind == "fox" else "f"
        if view == "front":
            c.cells([(11, 11), (12, 11 - wag), (13, 11 - wag), (13, 12 - wag)], "F"); c.put(13, 10 - wag, tip)
        elif view == "back":
            c.rect(7, 11, 8, 13, "F"); c.cells([(9, 12), (9, 13)], "F"); c.cells([(8, 14), (9, 14)], tip)
        else:
            c.cells([(5, 10), (4, 10 - wag), (3, 10 - wag), (2, 9 - wag), (3, 11 - wag)], "F"); c.put(2, 8 - wag, tip)
            if kind == "fox":
                c.cells([(2, 10 - wag), (4, 11 - wag)], "F")
    return draw


def beast(view, phase, head, *, wide=False, robe=None, bare=False, cloth="V", shade="v", behind=None, extra=None):
    c = Canvas()
    if behind:
        behind(c, view, phase)
    if not robe:
        legs(c, view, phase, wide=wide)
    torso(c, view, phase, cloth, shade, wide, robe, bare)
    head(c, view)
    if extra:
        extra(c, view, phase)
    c.outline()
    return c


# --- the children of the white wolf king and the elf princess ------------------------------------------------------------
KID = dict(me.ELF, A=FUR["white"][0], a=FUR["white"][1], Z=(236, 226, 170), z=(196, 182, 120), Rd=(130, 36, 34),
           R=(178, 54, 48), H=HORN[0], e=(214, 160, 40))                     # amber wolf's eyes, from their father


def wolf_ears_on(c, view, small=False):
    pts = [(4, 0), (4, 1), (5, 1)] if not small else [(5, 1), (5, 0)]
    if view == "side":
        c.cells([(6, 0), (6, 1), (7, 1)], "A")
    else:
        c.cells(pts + [(15 - x, y) for x, y in pts], "A")
        if view == "front" and not small:
            c.cells([(4, 1), (11, 1)], "r")


def white_tail(c, view, phase):
    wag = 1 if phase in (1, 3) else 0
    if view == "front":
        c.cells([(11, 11), (12, 11 - wag), (13, 11 - wag), (13, 12 - wag)], "A"); c.put(13, 10 - wag, "a")
    elif view == "back":
        c.rect(7, 11, 8, 13, "A"); c.cells([(9, 12), (9, 13), (8, 14), (9, 14)], "A")
    else:
        c.cells([(5, 10), (4, 10 - wag), (3, 10 - wag), (2, 9 - wag)], "A"); c.put(2, 8 - wag, "a")


def kid_beast(view, phase):
    """偏獸: a white wolf pup, standing like his father, with a leaf tucked behind one ear (from his mother)."""
    c = beast(view, phase, lambda cc, v: canine_head(cc, v), behind=tail("wolf"), cloth="l", shade="B",
              extra=lambda cc, v, p: cc.cells([(11, 1), (12, 2)] if v != "side" else [(7, 0)], "E"))
    return c


def kid_half(view, phase):
    """各半: a child with an elf's face and silver-gold hair, white wolf ears and a wolf tail."""
    c = Canvas()
    white_tail(c, view, phase)
    me.legs(c, view, phase)
    me.body(c, view, phase, cloth="V", shade="v")
    me.head(c, view, hair="A", hair_dark="a", ears=False)
    wolf_ears_on(c, view)
    fur_cuffs(c, view, phase)
    c.outline()
    return c


def fur_cuffs(c, view, phase):
    """White wolf fur at the wrists and shins, and a little fang over the lip."""
    if view == "side":
        c.cells([(6, 13), (8, 13)], "A")
        return
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    c.cells([(5, 11 + swing), (10, 11 - swing), (6, 13), (9, 13)], "A")
    if view == "front":
        c.put(8, 8, "W")


def kid_elf(view, phase):
    """偏精靈: mostly elf (long ears, a bow) but plainly the wolf king's child: a white wolf-fur hood with ears, his amber
    eyes, a fang, fur at the wrists and shins, and a white wolf's tail."""
    c = Canvas()
    white_tail(c, view, phase)
    me.legs(c, view, phase)
    me.body(c, view, phase, cloth="b", shade="B")
    me.head(c, view, hair="Z", hair_dark="z")
    if view == "back":
        c.rect(4, 1, 11, 7, "A"); c.rect(5, 8, 10, 9, "a"); c.cells([(5 + k, 9 + k) for k in range(4)], "V")
    elif view == "side":
        c.rect(5, 1, 10, 2, "A"); c.rect(3, 3, 5, 9, "A"); c.cells([(6, 0), (6, -1)], "A")
    else:
        c.rect(4, 1, 11, 2, "A"); c.cells([(4, 3), (11, 3)], "A")
        c.cells([(4, 0), (11, 0)], "A")                                     # the hood's little wolf ears
        c.cells([(12, 8), (13, 7)], "V")
    fur_cuffs(c, view, phase)
    c.outline()
    return c


# --- full moon: on all fours --------------------------------------------------------------------------------------------
# A sleek wolf (or fox) at a flat-out gallop, not a pet: a lean body, a ruff of fur standing up at the shoulders, the head
# low and forward, glowing eyes under a scowl, the jaws open on the fangs. Drawn pixel by pixel, without the legs.
# Keys as everywhere: F fur, f shade, L light, k dark, y glowing eye, b fang, q mouth.
RUN_SIDE = [                       # rows 3-10, facing right
    "..........F.F...",
    ".........fFFF...",
    "......f.ffFFyFF.",
    "ff..fffFfFFFFFFk",
    ".fFFFFFFFfFFLqb.",
    "..FFFFFFFFFFLL..",
    "...FFFFFFFFL....",
    "....LLL..LL.....",
]
RUN_FRONT = [                      # rows 1-10, coming at you
    "....F......F....",
    "....FF....FF....",
    "...fFFFFFFFFf...",
    "..fFkyFFFFykFf..",
    "..fFFFFLLFFFFf..",
    "..ffFFLkkLFFff..",
    "...ffFbqqbFff...",
    "...fFFFLLFFFf...",
    "....FFLLLLFF....",
    "....FFFFFFFF....",
]
RUN_BACK = [                       # rows 1-10, running away: ears, the ruff, the back, the tail held up
    "....F......F....",
    "....FF....FF....",
    "...fFFFFFFFFf...",
    "..fFFFFFFFFFFf..",
    "..ffFFFFFFFFff..",
    "...fFFFFFFFFf...",
    "....FFFFFFFF....",
    "....FFFFFFFF....",
    "....fFFffFFf....",
    "....FF.FF.FF....",
]
# Side legs: per row from the shoulder (or hip) down, how far the leg is pushed forward.
FRONT = {0: [0, 1, 2, 3], 1: [0, 0, 0, 0], 2: [0, -1, -2], 3: [0, 0, 1, 1]}
BACK = {0: [0, -1, -2, -3], 1: [0, 0, 1, 1], 2: [0, 1, 2], 3: [0, 0, 0, 0]}


def stamp(c, rows, top):
    for y, row in enumerate(rows, start=top):
        for x, key in enumerate(row):
            if key != ".":
                c.put(x, y, key)


def run_leg(c, x, top, steps, col):
    for k, dx in enumerate(steps):
        c.put(x + dx, top + k, col)
    c.cells([(x + steps[-1], top + len(steps) - 1), (x + steps[-1] + 1, top + len(steps) - 1)], "f")   # the paw


def on_all_fours(view, phase, ears="wolf"):
    c = Canvas()
    fox = ears == "fox"
    if view == "side":
        far = (phase + 2) % 4
        run_leg(c, 9, 11, FRONT[far], "f"); run_leg(c, 4, 11, BACK[far], "f")       # far legs, in shade, out of step
        stamp(c, RUN_SIDE, 3)
        wag = [0, 1, 0, -1][phase]                                          # the tail streams out behind
        c.put(0, 5 + wag, "L" if fox else "F")
        if fox:
            c.cells([(10, 2), (12, 2), (1, 5), (0, 7)], "F"); c.cells([(0, 6), (1, 6)], "F")
        run_leg(c, 10, 11, FRONT[phase], "F"); run_leg(c, 5, 11, BACK[phase], "F")
        if phase % 2:
            c.put(15, 8, "c")                                               # a fleck of froth
    elif view == "front":
        stamp(c, RUN_FRONT, 1)
        if fox:
            c.cells([(3, 0), (12, 0), (3, 1), (12, 1)], "F"); c.rect(6, 8, 9, 10, "L")   # bigger ears, a white bib
        for x, lifted in ((5, phase == 1), (10, phase == 3)):              # the front legs, pounding
            c.rect(x, 11, x, 13 - lifted, "F"); c.cells([(x - 1, 14 - lifted), (x, 14 - lifted)], "f")
        for x in (7, 8):                                                    # a hind leg glimpsed behind
            if (x == 7) == (phase in (0, 1)):
                c.rect(x, 11, x, 12, "f")
    else:
        stamp(c, RUN_BACK, 1)
        wag = [0, 1, 0, -1][phase]
        c.cells([(7 + wag, 2), (8 + wag, 2), (7 + wag, 3), (8 + wag, 4)], "F")   # the tail, up and lashing
        c.put(7 + wag, 1, "L" if fox else "f")
        if fox:
            c.cells([(3, 0), (12, 0), (3, 1), (12, 1), (6 + wag, 3), (9 + wag, 3)], "F")
        for x, lifted in ((5, phase == 3), (10, phase == 1)):
            c.rect(x, 11, x, 13 - lifted, "F"); c.cells([(x, 14 - lifted), (x + 1, 14 - lifted)], "f")
    c.outline()
    return c


# The minotaur's charge, side on: a broad man-bull leaning hard into the run, horns lowered and pointed ahead, a red eye under a
# furious brow, the nose ring swinging, the axe swept back over his shoulder. Rows 0-11; the legs pound below.
CHARGE = [
    ".........HH.....",
    "..II....H.HHHHh.",
    ".IIIv...fFFFFHHh",
    "..II.v..fFFFFF..",
    "......vfFFFkxFF.",
    "......fFvFFFFLLL",
    ".....fFFFvFFFLLk",
    "....fFFFFFFFLLY.",
    "....FFFFFFFF..Y.",
    "....FFFFFFFF....",
    ".....vvbvvv.....",
    ".....VVVVVV.....",
]


def charge(phase):
    c = Canvas()
    for x, sgn in ((5, 1), (8, -1)):                                        # thick legs, a long pounding stride
        off = {0: -1, 1: 0, 2: 1, 3: 0}[phase] * sgn
        lift = 1 if (phase == 1 and sgn == 1) or (phase == 3 and sgn == -1) else 0
        c.rect(x + off, 12, x + off + 1, 13 - lift, "F")
        c.rect(x + off, 14 - lift, x + off + 2, 14 - lift, "f")
    stamp(c, CHARGE, 0)
    for i, (x, y) in enumerate(((2, 13), (1, 12), (0, 14), (3, 14))):       # dust kicked up behind
        if (i + phase) % 2 == 0:
            c.put(x, y, "b")
    c.outline()
    return c


FRENZY = [
    ("灰狼", palette("wolf"), lambda v, p: on_all_fours(v, p)),
    ("赤狐", palette("fox"), lambda v, p: on_all_fours(v, p, ears="fox")),
    ("牛頭人", palette("bull"), lambda v, p: charge(p) if v == "side" else
        warrior(v, p, lambda c, vv: w_bull_head(c, vv, fierce=True), build="big", behind=w_tail("bull"), weapon=great_axe)),
    ("白狼王", palette("white"), lambda v, p: warrior(v, p, lambda c, vv: w_head(c, vv, paint=False, mane=True, fierce=True),
                                                   build="big", behind=w_tail("wolf"), weapon=chief_sword)),
    ("銀狐", palette("silver"), lambda v, p: warrior(v, p, lambda c, vv: w_head(c, vv, ears="fox", fierce=True), build="lean",
                                                 top="robe", behind=w_tail("fox"),
                                                 weapon=lambda c, vv, ph: skull_staff(c, vv, ph, glow=True))),
]


# --- the warriors: taller, broad-shouldered, fanged and armed ------------------------------------------------------------
# A smaller head (rows 2-7) on a longer, broader body; heavy brows over glowing eyes, fangs over the lip, war paint on the
# cheeks; thick arms with fists, thick legs. `build` is "lean" (the foxes), "norm" (the wolves) or "big" (minotaur, chief).
SPAN = {"lean": (5, 10), "norm": (4, 11), "big": (3, 12)}            # shoulders; the waist is two narrower


def w_head(c, view, ears="wolf", paint=True, mane=False, fierce=False):
    """Calm by default: steady dark eyes and one fang showing. `fierce` (the full moon): a scowl, glowing eyes, a snarl."""
    if view == "side":                                                     # facing right, the snout pushed forward
        c.rect(5, 1, 9, 1, "F"); c.rect(4, 2, 10, 5, "F"); c.rect(5, 6, 9, 6, "F")
        c.rect(10, 3, 13, 3, "F"); c.rect(10, 4, 13, 4, "L"); c.put(13, 3, "k")
        c.cells([(10, 5), (11, 5)], "L"); c.put(12, 5, "b")                 # the lower jaw, a fang
        if fierce:
            c.cells([(7, 2), (8, 2), (9, 3)], "k"); c.put(8, 3, "y")        # a scowl, a glowing eye
        else:
            c.put(8, 3, "e"); c.put(8, 2, "f")
        if paint:
            c.put(7, 4, "R")
        if ears == "fox":
            c.cells([(5, 0), (6, 0), (4, 0), (5, -1)], "F")
        else:
            c.cells([(5, 0), (4, 0)], "F")
        c.rect(3, 3, 4, 7, "L" if mane else "f")                             # the ruff down the back of the neck
        if mane:
            c.cells([(2, 4), (2, 6), (3, 8)], "L")
        return
    c.rect(5, 1, 10, 1, "F"); c.rect(4, 2, 11, 5, "F"); c.rect(5, 6, 10, 6, "F")
    left = [(3, 0), (4, 0), (3, 1), (2, 0)] if ears == "fox" else [(4, 0), (3, 1), (4, 1)]
    c.cells(left + [(15 - x, y) for x, y in left], "F")
    c.cells([(3, 4), (3, 5), (12, 4), (12, 5), (2, 5), (13, 5)], "F")         # spiky cheek fur
    if mane:
        c.cells([(2, 3), (13, 3), (2, 4), (13, 4), (1, 5), (14, 5), (3, 6), (12, 6), (4, 7), (11, 7)], "L")
    if view == "back":
        c.rect(4, 4, 11, 6, "f")
        return
    c.rect(6, 4, 9, 5, "L")                                                   # the muzzle
    c.cells([(7, 4), (8, 4)], "k")                                            # nose
    c.cells([(7, 7), (8, 7)], "L")                                            # the jaw
    if fierce:
        c.cells([(5, 2), (6, 3), (10, 2), (9, 3)], "k")                       # brows pressed down
        c.cells([(5, 3), (10, 3)], "y")                                       # glowing eyes
        c.cells([(6, 6), (9, 6)], "b"); c.cells([(7, 6), (8, 6)], "k")        # fangs and a snarl
    else:
        c.cells([(5, 2), (10, 2)], "f")                                       # a heavy, level brow
        c.cells([(5, 3), (10, 3)], "e")                                       # steady eyes
        c.cells([(6, 6), (7, 6), (8, 6)], "L"); c.put(9, 6, "b")              # the mouth shut, one fang over the lip
    if paint:
        c.cells([(4, 4), (11, 4)], "R")                                       # war paint


def w_bull_head(c, view, fierce=False):
    if view == "side":
        c.rect(4, 1, 9, 1, "F"); c.rect(3, 2, 10, 6, "F")
        c.rect(10, 3, 13, 6, "L"); c.put(13, 4, "k"); c.cells([(13, 6), (12, 7)], "Y")
        c.put(7, 2, "k" if fierce else "f"); c.put(9, 3, "x" if fierce else "e")
        c.cells([(5, 1), (5, 0), (6, -1), (7, 0)], "H")
        c.cells([(2, 3), (1, 3)], "F")
        c.rect(2, 5, 3, 8, "f")
        return
    c.rect(4, 1, 11, 1, "F"); c.rect(3, 2, 12, 6, "F"); c.rect(4, 7, 11, 7, "F")
    horn = [(2, 2), (1, 2), (0, 1), (0, 0), (1, 1)]                          # thick horns sweeping out and up
    c.cells(horn + [(15 - x, y) for x, y in horn], "H")
    c.cells([(0, 0), (15, 0)], "h")
    c.cells([(2, 4), (13, 4)], "F")
    if view == "back":
        c.rect(3, 5, 12, 7, "f")
        return
    if fierce:
        c.cells([(4, 2), (5, 3), (11, 2), (10, 3)], "k")                      # a furious brow
        c.cells([(5, 4), (10, 4)], "x")
    else:
        c.cells([(4, 2), (11, 2)], "f")                                       # a heavy brow
        c.cells([(5, 4), (10, 4)], "e")
    c.rect(6, 5, 9, 7, "L")
    c.cells([(6, 6), (9, 6)], "k")
    c.cells([(7, 7), (8, 7), (7, 8), (8, 8)], "Y")                            # a heavy nose ring
    c.cells([(6, 1), (7, 1), (8, 1), (9, 1), (7, 2), (8, 2)], "f")
    c.cells([(3, 5), (12, 5)], "R")


def w_body(c, view, phase, build="norm", top="bare", cloth="V"):
    """Fur pauldrons on broad shoulders, a chest that narrows to the waist (bare and crossed by a hide strap, or a robe),
    a belt, a loincloth, thick arms with fists, thick legs with clawed feet."""
    x0, x1 = SPAN[build]
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    if view == "side":
        for x, sgn in ((6, 1), (8, -1)):                                     # thick legs, a long stride
            off = {0: 0, 1: -1, 2: 0, 3: 1}[phase] * sgn
            lift = 1 if (phase == 1 and sgn == 1) or (phase == 3 and sgn == -1) else 0
            c.rect(x + off, 11, x + off + 1, 13 - lift, "F")
            c.rect(x + off, 14 - lift, x + off + 2, 14 - lift, "f")
        c.rect(5, 7, 9, 10, "F" if top == "bare" else cloth)
        c.rect(4, 7, 6, 8, "f")                                              # the hunched shoulder
        c.rect(5, 10, 9, 10, "v"); c.rect(6, 11, 9, 11, cloth)
        if top == "robe":
            c.rect(5, 8, 9, 14, cloth); c.rect(5, 10, 9, 10, "v")
        ax = {0: 8, 1: 9, 2: 8, 3: 7}[phase]
        c.rect(ax, 8, ax + 1, 10, "F"); c.rect(ax, 11, ax + 1, 11, "f")      # the near arm, a fist
        return
    if top != "robe":
        for x, lift in ((5, 1 if phase == 1 else 0), (9, 1 if phase == 3 else 0)):
            c.rect(x, 11, x + 1, 13 - lift, "F")
            c.rect(x - (1 if x == 5 else 0), 14 - lift, x + 1 + (1 if x == 9 else 0), 14 - lift, "f")
    body = "F" if top == "bare" else cloth
    c.rect(x0, 8, x1, 8, body); c.rect(x0 + 1, 9, x1 - 1, 9, body); c.rect(x0 + 2, 10, x1 - 2, 10, body)
    if top == "bare":
        c.cells([(7, 9), (8, 9)], "f")                                         # the line of the chest
        if view == "front":
            c.cells([(x0 + 1, 8), (x0 + 2, 9), (x0 + 3, 10)], "v")             # a hide strap across it
    if top == "robe":
        for y in range(9, 15):
            spread = (y - 9) // 2
            c.rect(x0 + 1 - spread, y, x1 - 1 + spread, y, cloth)
    c.rect(x0 + 2, 10, x1 - 2, 10, "v"); c.put(7, 10, "b")                     # belt with a bone buckle
    if top != "robe":
        c.rect(6, 11, 9, 11, cloth); c.cells([(7, 12), (8, 12)], cloth)        # loincloth
    c.rect(x0 - 1, 7, x1 + 1, 7, "f")                                          # fur pauldrons
    c.cells([(x0 - 1, 6), (x0, 6), (x1, 6), (x1 + 1, 6)], "f")
    for x, s in ((x0 - 2, swing), (x1 + 1, -swing)):
        c.rect(x, 8 + s, x + 1, 10 + s, "F")
        c.rect(x, 11 + s, x + 1, 11 + s, "f")                                  # fists


def warrior(view, phase, head, *, build="norm", top="bare", cloth="V", behind=None, weapon=None, small=False):
    """`small`: two rows shorter (the foxes): a row out of the chest and one out of the legs."""
    c = Canvas()
    if behind:
        behind(c, view, phase)
    if weapon and view == "back":
        weapon(c, view, phase)
    w_body(c, view, phase, build, top, cloth)
    head(c, view)
    if weapon and view != "back":
        weapon(c, view, phase)
    if small:
        c.px = [[None] * SIZE for _ in range(2)] + [r for y, r in enumerate(c.px) if y not in (9, 12)]
    c.outline()
    return c


def w_tail(kind):
    def draw(c, view, phase):
        wag = 1 if phase in (1, 3) else 0
        tip = "L" if kind == "fox" else "f"
        if kind == "bull":
            if view == "back":
                c.rect(7, 11, 7, 13, "F"); c.put(7, 14, "f")
            elif view == "side":
                c.cells([(4, 10), (3, 11), (3, 12)], "F"); c.put(2, 12, "f")
            return
        if view == "back":
            c.rect(7, 11, 8, 13, "F"); c.cells([(9, 12), (9, 13)], "F"); c.cells([(8, 14), (9, 14)], tip)
        elif view == "side":
            c.cells([(4, 10), (3, 11 - wag), (2, 11 - wag), (1, 10 - wag), (2, 12 - wag)], "F"); c.put(1, 9 - wag, tip)
        else:
            c.cells([(11, 12), (12, 13 - wag), (13, 13 - wag)], "F"); c.put(14, 13 - wag, tip)
    return draw


def scarf(c, view, phase):
    """The red fox's red scarf."""
    if view == "front":
        c.rect(6, 7, 9, 7, "R")
    elif view == "side":
        c.cells([(5, 7), (4, 8), (3, 9)], "R")
    else:
        c.rect(6, 7, 9, 7, "R"); c.cells([(8, 8), (9, 9)], "R")


def great_axe(c, view, phase):
    if view == "front":
        c.rect(14, 3, 14, 13, "v")
        c.rect(15, 3, 15, 7, "I"); c.rect(13, 3, 13, 6, "I"); c.cells([(13, 6), (15, 7)], "i")
        c.cells([(5, 8), (7, 9), (8, 9), (10, 8)], "b")                     # a necklace of tusks
    elif view == "side":
        c.rect(11, 2, 11, 12, "v"); c.rect(12, 1, 13, 4, "I"); c.put(13, 4, "i"); c.rect(10, 1, 10, 3, "I")
    else:
        c.rect(1, 3, 1, 13, "v"); c.rect(0, 3, 0, 7, "I"); c.rect(2, 3, 2, 6, "I")


def skull_staff(c, view, phase, glow=False):
    if view == "front":
        c.rect(13, 3, 13, 14, "v"); c.rect(12, 0, 14, 2, "b"); c.cells([(12, 1), (14, 1)], "e")
        c.cells([(15, 2), (15, 3)], "G"); c.put(11, 2, "R")
        c.cells([(6, 8), (7, 9), (8, 9), (9, 8)], "b")
    elif view == "side":
        c.rect(11, 3, 11, 14, "v"); c.rect(10, 0, 12, 2, "b"); c.put(12, 1, "y" if glow else "e"); c.put(9, 2, "G")
        if glow:                                                             # its eyes burn on the full moon
            c.cells([(13, 0), (13, 2), (9, 0)], "y")
    c.cells([(6, 0), (7, -1)] if view == "side" else [(7, 0), (8, 0), (6, 0)], "G")      # feathers in the fur


def chief(c, view, phase):
    """The white wolf king's crown of bone and gold, red hide cape, and the scar across one eye."""
    if view == "front":
        c.cells([(5, 8), (10, 8)], "R"); c.cells([(7, 8), (8, 8)], "Y")       # the cape's clasp
        c.cells([(5, 1), (6, 4), (6, 5)], "Rd")                               # a scar across one eye
    elif view == "side":
        c.rect(1, 7, 4, 13, "R"); c.rect(1, 13, 4, 13, "Rd")
    else:
        c.rect(3, 7, 12, 13, "R"); c.rect(3, 13, 12, 13, "Rd")
    if view != "side":
        c.cells([(6, 0), (9, 0)], "b"); c.cells([(7, 0), (8, 0)], "Y")


def chief_sword(c, view, phase):
    """On the full moon he draws the great bone sword."""
    chief(c, view, phase)
    if view == "front":
        c.rect(13, 0, 14, 9, "b"); c.rect(14, 1, 14, 9, "c")
        c.rect(12, 10, 15, 10, "Y"); c.rect(13, 11, 14, 11, "v")
    elif view == "side":
        c.rect(10, 0, 11, 8, "b"); c.rect(11, 0, 11, 8, "c"); c.rect(9, 9, 12, 9, "Y")
    else:
        c.rect(1, 0, 2, 9, "b")

# id, name, weight, boost, blurb, stats, sheet, drawer, palette
BREEDS = [
    ("common", "灰狼", 100, 0, "部落裡最多的狼族，壯、臉上畫著戰紋，空手就很能打，愛吃肉、愛打獵。",
     {"lifespan": 1.5, "might": 1.2, "health": 3.5}, "worker.png",
     lambda v, p: warrior(v, p, w_head, behind=w_tail("wolf")), palette("wolf")),
    ("scout", "赤狐", 10, 1.0, "紅毛狐狸，比狼小一號，圍著紅頭巾，跑得快、鼻子靈，遠遠就聞到獵物。",
     {"speed": 1.4, "sense": 1.4, "rest": 0.8, "lifespan": 1.4, "might": 1.0, "health": 2.5}, "scout.png",
     lambda v, p: warrior(v, p, lambda c, vv: w_head(c, vv, ears="fox"), build="lean", cloth="v", behind=w_tail("fox"),
                          weapon=scarf, small=True), palette("fox")),
    ("brute", "牛頭人", 8, 1.0, "大塊頭，一對粗角、重鼻環、扛著雙刃斧，走得慢，一次搬兩份，站在最前面。",
     {"speed": 0.75, "sense": 0.9, "carry": 2, "rest": 1.2, "lifespan": 1.6, "might": 2.0, "health": 7}, "brute.png",
     lambda v, p: warrior(v, p, w_bull_head, build="big", behind=w_tail("bull"), weapon=great_axe), palette("bull")),
    ("sage", "銀狐", 5, 1.5, "年紀大的銀毛狐狸，拄著骷髏手杖、頭上插羽毛，會補血，也很會叫同伴。",
     {"speed": 0.95, "sense": 1.3, "recruit": 3, "lifespan": 1.8, "might": 1.0, "health": 3}, "sage.png",
     lambda v, p: warrior(v, p, lambda c, vv: w_head(c, vv, ears="fox"), build="lean", top="robe", cloth="V",
                          behind=w_tail("fox"), weapon=skull_staff), palette("silver")),
    ("golden", "白狼王", 1, 3.0, "罕見的白狼，長鬃、骨冠、一眼帶疤、紅色獸皮披風，部落的首領；滿月時才拔出骨製大劍。每一方面都好一點。",
     {"speed": 1.15, "sense": 1.2, "recruit": 1, "lifespan": 2.5, "might": 1.7, "health": 6}, "golden.png",
     lambda v, p: warrior(v, p, lambda c, vv: w_head(c, vv, paint=False, mane=True), build="big", behind=w_tail("wolf"),
                          weapon=chief), palette("white")),
    # The children of the white wolf king and the elf princess. Never born by chance: weight 0.
    ("half_gob", "森之子・偏獸", 0, 0, "白狼王與精靈公主的孩子，偏向狼族：白毛小狼，耳後別著一片葉子，力氣大又耐打。",
     {"speed": 1.1, "sense": 1.2, "carry": 2, "lifespan": 2.0, "might": 1.9, "health": 6.5}, "half_gob.png",
     kid_beast, palette("white", l=KID["l"], B=me.ELF["B"], E=me.ELF["E"])),
    ("half_mix", "森之子", 0, 0, "白狼王與精靈公主的孩子，各半：精靈的臉、白頭髮、琥珀色的狼眼、白狼耳和尾巴，什麼都好一點。",
     {"speed": 1.15, "sense": 1.3, "lifespan": 2.3, "might": 1.6, "health": 5, "recruit": 1}, "half_mix.png",
     kid_half, KID),
    ("half_hum", "森之子・偏精靈", 0, 0, "白狼王與精靈公主的孩子，偏向精靈：長耳朵、背著弓，但戴著有狼耳的白狼毛兜帽，琥珀色的狼眼、一顆小獠牙、白狼尾巴。是獸人裡少數的遠程。",
     {"speed": 1.1, "sense": 1.5, "lifespan": 2.8, "might": 1.4, "health": 4, "recruit": 1}, "half_hum.png",
     kid_elf, KID),
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


def frenzy_sheet(draw, pal):
    """The full-moon look, in the same layout as the walk (4 phases x front, back, side)."""
    return breed_sheet(draw, pal)


# --- the elf princess, in the tribe's clothes ---------------------------------------------------------------------------
ELF_GIRL = dict(mg.GIRL, H=(236, 226, 170), h=(252, 248, 214), J=(196, 182, 120), i=(70, 170, 110), c=(120, 200, 110),
                X=(246, 244, 240), G=(96, 156, 84), b=(240, 232, 210), x=(196, 60, 48))

OUTFITS = [
    dict(id="tribe", name="部落長裙", bottom="gown", sleeves="puff", hat="tiara", elf=True, feather=True, fur=True, fringe=True,
         pal={"Q": (176, 96, 60), "q": (138, 70, 44), "D": (164, 88, 56), "d": (126, 64, 40), "W": (236, 228, 212),
              "X": (190, 176, 150), "R": (64, 168, 160), "K": (110, 76, 48)}),
    dict(id="winter", name="白狼毛斗篷", bottom="coat", sleeves="long", hat="tiara", elf=True, fur=True,
         pal={"Q": (236, 236, 244), "q": (200, 204, 220), "D": (236, 236, 244), "d": (200, 204, 220), "A": (178, 54, 48),
              "W": (255, 255, 255), "K": (110, 76, 48)}),
    dict(id="maternity1", name="孕婦裝（初期）", bottom="dress", sleeves="puff", hat="tiara", elf=True, belly=1,
         pal={"Q": (196, 170, 128), "q": (160, 132, 92), "D": (196, 170, 128), "d": (160, 132, 92), "R": (96, 156, 84),
              "W": (246, 244, 240)}),
    dict(id="maternity2", name="孕婦裝（後期）", bottom="dress", sleeves="puff", hat="tiara", elf=True, belly=2,
         pal={"Q": (196, 170, 128), "q": (160, 132, 92), "D": (196, 170, 128), "d": (160, 132, 92), "R": (96, 156, 84),
              "W": (246, 244, 240)}),
    dict(id="pajamas", name="睡衣", bottom="pants", sleeves="long", hat="tiara", elf=True,
         pal={"Q": (226, 236, 222), "q": (194, 210, 190), "D": (226, 236, 222), "d": (194, 210, 190), "K": (210, 226, 206)}),
]

_view = ["front"]
_original_squash = mg.squash


def _tribe_squash(c, o):
    """Long elf ears out past her hair; in the tribe's dress a feather in her hair, a fur collar and a bead necklace.
    Drawn before she is squashed and outlined, so it becomes part of her silhouette."""
    view = _view[0]
    if o.get("elf"):
        if view == "side":
            c.cells([(4, 4), (3, 3), (2, 2)], "s")
        else:
            c.cells([(2, 4), (1, 3), (13, 4), (14, 3)], "s")
    if o.get("feather"):
        if view == "side":
            c.cells([(4, 1), (3, 0), (3, 1)], "G")
        elif view == "front":
            c.cells([(12, 1), (13, 0), (12, 0)], "G"); c.put(12, 2, "R")
        else:
            c.cells([(3, 1), (2, 0), (3, 0)], "G")
    if o.get("fur"):
        row = 8                                                       # the shoulders
        xs = range(5, 11) if view == "side" else range(4, 12)
        for x in xs:
            if c.px[row][x] is not None:
                c.px[row][x] = "X" if x % 2 else "W"
        if view == "front" and o["id"] == "tribe":
            c.cells([(6, 8), (7, 8), (8, 8), (9, 8)], "b")            # a string of bone beads at the collar
            c.cells([(5, 6), (10, 6)], "x")                           # a stroke of the tribe's red paint on each cheek
    if o.get("fringe"):                                               # the hide skirt ends in a ragged fringe
        for x in range(SIZE):
            if c.px[15][x] is not None:
                c.px[15][x] = "d" if x % 2 else None
    return _original_squash(c, o)


def _wrap(fn, view):
    def drawn(*args, **kwargs):
        _view[0] = view
        return fn(*args, **kwargs)
    return drawn


def princess_sheet(outfit):
    saved = (dict(mg.GIRL), mg.squash, mg.girl_front, mg.girl_back, mg.girl_side)
    mg.GIRL.clear()
    mg.GIRL.update(ELF_GIRL)
    mg.squash = _tribe_squash
    mg.girl_front, mg.girl_back, mg.girl_side = (_wrap(saved[2], "front"), _wrap(saved[3], "back"), _wrap(saved[4], "side"))
    try:
        return mg.build_sheet(True, outfit=outfit)
    finally:
        mg.GIRL.clear()
        mg.GIRL.update(saved[0])
        mg.squash, mg.girl_front, mg.girl_back, mg.girl_side = saved[1:]


def preview(path, zoom=8):
    """Every breed (front, back, side, mirrored side; walk phases 0 and 1), the full-moon run, the princess's outfits,
    then her first few poses."""
    rows = []
    for b in BREEDS:
        sheet = breed_sheet(b[7], b[8])
        cells = []
        for view in range(3):
            for phase in (0, 1):
                cells.append((sheet, phase * SIZE, view * SIZE, False))
        cells += [(sheet, 0, 2 * SIZE, True), (sheet, SIZE, 2 * SIZE, True)]
        rows.append(cells)
    for _name, pal, draw in FRENZY:
        sheet = frenzy_sheet(draw, pal)
        rows.append([(sheet, f * SIZE, 0, False) for f in (0, 1)] + [(sheet, f * SIZE, SIZE, False) for f in (0, 1)] +
                    [(sheet, f * SIZE, 2 * SIZE, False) for f in range(4)])
    for o in OUTFITS:
        sheet = princess_sheet(o)
        rows.append([(sheet, ph * SIZE, v * SIZE, False) for v in range(3) for ph in (0, 1)] +
                    [(sheet, 0, 2 * SIZE, True), (sheet, SIZE, 2 * SIZE, True)])
    first = princess_sheet(OUTFITS[0])
    poses = [(first, f * SIZE, (3 + pr) * SIZE, False) for pr in range(len(mg.POSES)) for f in range(4)]
    for i in range(0, min(len(poses), 16), 8):
        rows.append(poses[i:i + 8])
    cols = 8
    w, h = cols * SIZE * zoom, len(rows) * SIZE * zoom
    out = [[(196, 186, 150, 255)] * w for _ in range(h)]
    for r, cells in enumerate(rows):
        for col, (sheet, sx, sy, flip) in enumerate(cells):
            for y in range(SIZE):
                for x in range(SIZE):
                    px = sheet[sy + y][sx + (SIZE - 1 - x if flip else x)]
                    if px[3]:
                        for oy in range(zoom):
                            row = out[(r * SIZE + y) * zoom + oy]
                            for ox in range(zoom):
                                row[(col * SIZE + x) * zoom + ox] = px
    mg.write_png(path, out)


def beast_icon():
    """The menu bar icon: the grey wolf's head, front on."""
    c = Canvas()
    w_head(c, "front")
    c.outline()
    pal = palette("wolf")
    return [[(pal[c.px[y][x]] + (255,)) if c.px[y][x] else (0, 0, 0, 0) for x in range(SIZE)] for y in range(SIZE)]


# Which breed each full-moon look belongs to (FRENZY is in the order 灰狼, 赤狐, 牛頭人, 白狼王, 銀狐).
FRENZY_BREEDS = ["common", "scout", "brute", "golden", "sage"]

FEATURES = ["吃肉：烤肉、烤魚的加成 ×1.5，果實、野莓、蜂蜜只有一半",
            "愛打獵：看到動物會主動去追，打到的肉直接進食材櫃",
            "滿月的晚上狂暴：灰狼、赤狐四足狂奔，牛頭人低頭衝鋒，白狼王拔出大劍；打得更痛，但也傷得更重",
            "打魔獸時包抄：牛頭人正面擋，狼和狐從旁邊咬，銀狐在後面補血",
            "首領是精靈公主；和白狼王的孩子是森之子"]


def main():
    if "--write" in sys.argv:
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Characters", "beast")
        os.makedirs(root, exist_ok=True)
        for _id, _name, _w, _b, _blurb, _stats, sheet, draw, pal in BREEDS:
            mg.write_png(os.path.join(root, sheet), breed_sheet(draw, pal))
        for breed, (_name, pal, draw) in zip(FRENZY_BREEDS, FRENZY):
            mg.write_png(os.path.join(root, f"frenzy_{breed}.png"), frenzy_sheet(draw, pal))
        import make_specials  # (the special residents, tools/make_specials.py: drawn on these bodies)
        make_specials.write("beast", root)
        import make_terrain_breeds  # (the terrain breeds, tools/make_terrain_breeds.py: one per terrain detail)
        make_terrain_breeds.write("beast", root)
        for o in OUTFITS:
            mg.write_png(os.path.join(root, "queen.png" if o is OUTFITS[0] else f"queen_{o['id']}.png"), princess_sheet(o))
        mg.write_png(os.path.join(root, "icon.png"), beast_icon())
        walk = {"down": [0, 1, 2, 3], "up": [4, 5, 6, 7], "side": [8, 9, 10, 11]}
        frenzy = dict(zip(FRENZY_BREEDS, (f"frenzy_{b}.png" for b in FRENZY_BREEDS)))
        manifest = {
            "id": "beast", "name": "獸人", "noun": "獸人", "emoji": "🐺", "icon": "icon.png", "nestName": "獸穴", "frame": SIZE,
            "defaultMaxCount": 200,
            "tagline": "狼、狐、牛頭人的部落，住在乾燥的紅岩荒谷；吃肉、愛打獵，滿月的晚上狂暴。",
            "features": FEATURES,
            "rules": {"names": "beast", "noDecor": ["tent"], "spawnScale": 1.3,
                      "food": {"meat": 1.5, "fish": 1.5, "fruit": 0.5, "berries": 0.5, "honey": 0.5},
                      "moon": {"might": 1.4, "speed": 1.15, "hurt": 1.25}, "hunts": 1.5, "charge": 1.3, "flank": 1.2,
                      "camp": "den", "biome": "redrock",
                      "princessNames": ["艾琳", "月芽", "希雅", "琳恩", "薇拉", "露米", "雪絲", "菲歐", "星語", "蘿婭"]},
            "worker": {"sheet": "worker.png", "pixelScale": 1.5, "walk": walk},
            "breeds": [dict({"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet},
                            **({"frenzy": frenzy[i]} if i in frenzy else {}))
                       for i, n, w, b, blurb, stats, sheet, _d, _p in BREEDS] + make_specials.manifest_entries("beast")
                   + make_terrain_breeds.manifest_entries("beast"),
            "queen": {"sheet": "queen.png", "pixelScale": 2.0, "walk": walk,
                      "poses": {name: [(3 + r) * 4 + f for f in range(count)] for r, (name, _dr, count) in enumerate(mg.POSES)},
                      "outfits": [{"id": o["id"], "name": o["name"], "sheet": "queen.png" if o is OUTFITS[0] else f"queen_{o['id']}.png"}
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
