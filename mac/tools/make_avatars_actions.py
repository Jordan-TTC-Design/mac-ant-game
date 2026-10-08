#!/usr/bin/env python3
"""PREVIEW ONLY: basic actions for the six guild avatars (角色), built on make_avatars_preview.py's bodies.

Ten actions, 2-4 frames each, shared by all six avatars: idle, wave, typing (focus), dozing on the desk (away), drinking at the
water-elemental dispenser, stretch, sitting on a bench, chatting, cheering, and a high-five between two avatars.

    python3 make_avatars_actions.py          # writes avatars_actions_preview.png into docs/images/guild/
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_avatars_preview as pv  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "images", "guild", "avatars_actions_preview.png")
W = pv.W
PAD = 6                       # room above the head for jumping, raised arms, z's and bubbles
FH = pv.H + PAD               # figure canvas height; feet stand on row 26 + PAD
AV = {a["id"]: a for a in pv.AVATARS}

PROPS = dict(pv.FURN, **{
    "X": (255, 255, 255), "x": (200, 210, 230),                         # bubble, its shade
    "D": (60, 50, 70),                                                  # dots, icon ink
    "H": (238, 90, 110), "h": (255, 160, 170),                          # heart
    "Y": (250, 214, 90), "y": (200, 150, 40),                           # gold, sparkle
    "A": (100, 168, 240), "a": (170, 222, 255), "E": (60, 108, 190),    # water elemental
    "S": (120, 120, 132), "s": (160, 160, 172),                         # stone
    "Q": (232, 220, 190), "q": (200, 184, 150),                         # sand (hourglass)
    "z": (150, 200, 255),
})
GLOW = dict(PROPS, G=(200, 255, 250), g=(120, 230, 230), R=(255, 255, 255), r=(110, 220, 210))
DIM = dict(PROPS, G=(130, 170, 190), g=(90, 120, 150), Z=(190, 210, 220))


# --- pieces ---------------------------------------------------------------------------------------------------------------
def sleeve_paint(c, a, pts, hand):
    sc = a.get("sleeve_col", "T")
    long = a.get("sleeve", "short") == "long"
    for i, (x, y) in enumerate(pts):
        c.put(x, y, sc if (long or i < 4) else "s")
    if long and a.get("cuff") and pts:
        c.cells(pts[-2:], "u")
    c.cells(hand, "s")


def arm_up(c, a, oy, side, high=False):
    """An arm thrown up in a V. side -1 is the viewer's left arm."""
    pts = [(6, 15), (7, 15), (5, 14), (6, 14)] + [(x, y) for y in range(7, 14) for x in (4, 5)]
    hand = [(4, 5), (5, 5), (4, 6), (5, 6)]
    if high:                                                            # hands clasped above the head
        pts = [(6, 15), (7, 15), (5, 14), (6, 14)] + [(x, y) for y in range(6, 14) for x in (4, 5)] + \
              [(5, 5), (6, 5), (6, 4), (7, 4), (7, 3), (8, 3), (8, 2), (9, 2)]
        hand = [(10, 0), (11, 0), (10, 1), (11, 1), (9, 1)]
    if side > 0:
        pts = [(pv.mx(x), y) for x, y in pts]
        hand = [(pv.mx(x), y) for x, y in hand]
    sleeve_paint(c, a, [(x, y + oy) for x, y in pts], [(x, y + oy) for x, y in hand])


def arm_hang(c, a, oy, side, phase=0):
    sw = {0: 0, 1: -1, 2: 0, 3: 1}[phase] * (1 if side < 0 else -1)
    x0 = 6 if side < 0 else 16
    pts = []
    for y in range(oy + 16 + sw, oy + 21 + sw):
        pts += [(x0, y), (x0 + 1, y)]
    sleeve_paint(c, a, pts, [(x0, oy + 21 + sw), (x0 + 1, oy + 21 + sw)])


def arm_wave(c, a, oy, f):
    pts = [(16, 15), (17, 15), (17, 14), (18, 14), (18, 13), (19, 13)]
    if f == 0:
        pts += [(18, 12), (19, 12)]
        hand = [(18, 10), (19, 10), (18, 11), (19, 11)]
    else:
        pts += [(19, 12), (20, 12)]
        hand = [(20, 10), (21, 10), (20, 11), (21, 11), (21, 9)]
    sleeve_paint(c, a, [(x, y + oy) for x, y in pts], [(x, y + oy) for x, y in hand])


def arm_mug(c, a, oy, raised):
    """The viewer's right arm, bent, holding a mug at the chest or up at the mouth."""
    if raised:
        pts = [(16, 15), (17, 15), (17, 16), (17, 17), (16, 16), (16, 17), (15, 16)]
        hand = [(15, 14), (15, 15), (14, 15)]
    else:
        pts = [(16, 15), (17, 15), (17, 16), (17, 17), (17, 18), (16, 18)]
        hand = [(15, 18), (15, 17)]
    sleeve_paint(c, a, [(x, y + oy) for x, y in pts], [(x, y + oy) for x, y in hand])


def mug(c, x, y):
    """A little white mug, top-left at (x, y): 3 wide, 3 tall, with a handle on the right."""
    c.rect(x, y, x + 2, y + 2, "P"); c.rect(x, y, x + 2, y, "p"); c.put(x + 3, y + 1, "P")
    c.put(x + 1, y, "a")                                                  # water in it


def mouth(c, a, oy, kind, head_dy=0):
    y = oy + head_dy
    if kind is None:
        return
    if a["race"] == "skeleton":
        if kind in ("open", "talk", "yawn"):
            c.rect(10, y + 13, 13, y + 13, "d")
            c.rect(9, y + 14, 14, y + 14, "S") if kind == "yawn" else c.cells([(10, y + 14), (13, y + 14)], "S")
        return
    if kind == "open":
        c.rect(11, y + 12, 12, y + 13, "m")
    elif kind == "talk":
        c.cells([(11, y + 12), (12, y + 12), (11, y + 13), (12, y + 13)], "m")
        c.cells([(11, y + 13), (12, y + 13)], "p")
    elif kind == "yawn":
        c.rect(10, y + 12, 13, y + 13, "m"); c.rect(11, y + 11, 12, y + 11, "m")
    elif kind == "smile":
        c.cells([(10, y + 12), (11, y + 13), (12, y + 13), (13, y + 12)], "m")


def happy_eyes(c, a, oy):
    """^ ^ eyes (closed, smiling)."""
    if a["race"] == "skeleton":
        for x0 in (8, 14):
            c.rect(x0, oy + 8, x0 + 1, oy + 10, "s")
            c.cells([(x0, oy + 10), (x0 + 1, oy + 9), (x0 + 2, oy + 10)], "d") if x0 == 8 else \
                c.cells([(x0 - 1, oy + 10), (x0, oy + 9), (x0 + 1, oy + 10)], "d")
        return
    for x0 in (8, 14):
        c.rect(x0, oy + 8, x0 + 1, oy + 10, "s")
        c.cells([(x0, oy + 9), (x0 + 1, oy + 9)], "L"); c.cells([(x0 - 1 if x0 == 8 else x0 + 2, oy + 10)], "L")
        c.put(x0 + 2 if x0 == 8 else x0 - 1, oy + 10, "L")


def figure(a, phase=0, oy=PAD, up=0, head_dy=0, look="open", mouth_kind=None, arms="hang", arm_f=0, legs="stand",
           seat_y=None, legs_phase=None, sit=False, swing=0):
    """The front view, with the pieces an action needs: `up` lifts the upper body (breathing), head_dy nods the head,
    `arms` picks a pose, `legs` is 'stand', 'jump' (tucked), 'bench' (dangling) or 'none'."""
    c = pv.C(W, FH)
    u = oy - up + (pv.SIT_DROP if sit else 0)
    ghost = a["outfit"] == "spirit"
    pv.hair_behind(c, a, "front", u + head_dy)
    lp = phase if legs_phase is None else legs_phase
    if sit:
        pv.sit_legs_front(c, a, oy, swing)
    elif legs == "stand" or (ghost and legs != "bench"):
        pv.legs_front(c, a, oy, lp)
    elif legs == "bench":
        bench_legs(c, a, u, lp)
    elif legs == "jump":
        pv.legs_front(c, a, oy, 0)
        if not ghost:                                                  # knees tucked: a shorter leg, feet together
            c.rect(6, oy + 24, 17, oy + 27, None)
            for x in (9, 13):
                if a["race"] == "skeleton":
                    xx = 10 if x == 9 else 13
                    c.put(xx, oy + 23, "P")
                else:
                    c.rect(x, oy + 23, x + 1, oy + 23, "P" if a["outfit"] == "tunic" else "s")
                c.rect(x, oy + 24, x + 1, oy + 24, "K")
            if a["outfit"] == "gown":
                c.rect(6, oy + 24, 17, oy + 24, "u"); c.rect(9, oy + 25, 10, oy + 25, "K"); c.rect(13, oy + 25, 14, oy + 25, "K")
    pv.torso_front(c, a, u)
    if arms == "hang":
        pv.arms_front(c, a, u, phase)
    pv.ears(c, a, "front", u + head_dy)
    pv.head_shape(c, u + head_dy)
    hy = u + head_dy
    if look == "happy":
        pv.face_front(c, a, hy, "open")
        happy_eyes(c, a, hy)
    else:
        pv.face_front(c, a, hy, look)
    pv.hair_front(c, a, hy)
    if a["hair"] == "hood":
        pv.face_front(c, a, hy, "open" if look == "open" else "down")
        if look == "happy":
            happy_eyes(c, a, hy)
    mouth(c, a, u, mouth_kind, head_dy)
    if arms in ("wave", "mug", "mug_up"):
        arm_hang(c, a, u, -1)
    c.outline()
    ca = pv.C(W, FH)                                                   # moving arms get their own outline, so they read
    if arms == "up":                                                   # against the head and ears
        arm_up(ca, a, u, -1); arm_up(ca, a, u, 1)
    elif arms == "up_high":
        arm_up(ca, a, u, -1, True); arm_up(ca, a, u, 1, True)
    elif arms == "wave":
        arm_wave(ca, a, u, arm_f)
    elif arms in ("mug", "mug_up"):
        arm_mug(ca, a, u, arms == "mug_up")
    return overlay(c, ca.outline())


def overlay(c, top):
    for y in range(c.h):
        for x in range(c.w):
            if top.px[y][x] is not None:
                c.px[y][x] = top.px[y][x]
    return c


def bench_legs(c, a, u, phase):
    """Sitting, seen from the front: a short lap on the seat, shins hanging and swinging."""
    o = a["outfit"]
    lap = "T" if o in ("dress", "gown", "spirit") else "P"
    c.rect(7, u + 22, 16, u + 23, lap)
    if o == "gown":
        c.rect(7, u + 22, 16, u + 25, "T"); c.rect(7, u + 25, 16, u + 25, "u")
    if o == "dress":
        c.rect(7, u + 23, 16, u + 23, "U")
    if o == "spirit":
        c.rect(7, u + 23, 16, u + 23, "u")
        sway = 1 if phase == 1 else -1 if phase == 3 else 0
        c.rect(9, u + 24, 14, u + 24, "Q"); c.rect(10 + sway, u + 25, 13 + sway, u + 25, "Q")
        c.rect(11 + sway, u + 26, 12 + sway, u + 26, "q"); c.put(11 + 2 * sway, u + 27, "q")
        c.put(10, u + 24, "Z")
        return
    top = u + (26 if o == "gown" else 24)
    for x, swing in ((9, phase == 1), (13, phase == 3)):
        bottom = top + (1 if swing else 2)
        if a["race"] == "skeleton":
            xx = 10 if x == 9 else 13
            c.rect(xx, top, xx, bottom, "P")
        elif o != "gown":
            c.rect(x, top, x + 1, bottom, "s" if o == "dress" else "P")
        c.rect(x - (1 if x == 9 else 0), bottom + 1, x + 1 + (1 if x == 13 else 0), bottom + 1, "K")
        if swing:
            c.rect(x - (1 if x == 9 else 0), bottom + 2, x + 1 + (1 if x == 13 else 0), bottom + 2, "K")   # toe toward us


def place(img, w, h, dx=0, dy=0, base=None):
    out = base or Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(img, (dx, dy)) if dx >= 0 and dy >= 0 else out.paste(img, (dx, dy), img)
    return out


def scene(layers, w, h):
    """layers: (canvas, palette, dx, dy), back to front."""
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for canvas, pal, dx, dy in layers:
        img = canvas.image(pal)
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        layer.paste(img, (dx, dy), img)
        out.alpha_composite(layer)
    return out


def zz(c, x, y, big=False):
    if big:
        c.rect(x, y, x + 3, y, "z"); c.put(x + 2, y + 1, "z"); c.put(x + 1, y + 2, "z"); c.rect(x, y + 3, x + 3, y + 3, "z")
    else:
        c.rect(x, y, x + 2, y, "z"); c.put(x + 1, y + 1, "z"); c.rect(x, y + 2, x + 2, y + 2, "z")


def bubble(c, x, y, icon, f=0):
    """A small speech bubble, top-left at (x, y), 11x8, tail at the bottom left."""
    c.rect(x + 1, y, x + 9, y, "X"); c.rect(x, y + 1, x + 10, y + 5, "X"); c.rect(x + 1, y + 6, x + 9, y + 6, "X")
    c.rect(x + 1, y + 6, x + 9, y + 6, "x")
    c.cells([(x + 1, y + 7), (x + 2, y + 7), (x + 1, y + 8)], "X")
    if icon == "dots":
        for i in range(f + 1):
            c.put(x + 3 + 2 * i, y + 3, "D")
    elif icon == "heart":
        c.cells([(x + 3, y + 2), (x + 4, y + 2), (x + 6, y + 2), (x + 7, y + 2)], "H")
        c.rect(x + 3, y + 3, x + 7, y + 3, "H"); c.rect(x + 4, y + 4, x + 6, y + 4, "H"); c.put(x + 5, y + 5, "H")
        c.put(x + 3, y + 2, "h")
    elif icon == "note":
        c.rect(x + 6, y + 1, x + 6, y + 4, "D"); c.rect(x + 4, y + 4, x + 5, y + 5, "D"); c.put(x + 7, y + 1, "D"); c.put(x + 8, y + 2, "D")
    elif icon == "tea":
        c.rect(x + 3, y + 3, x + 6, y + 5, "W"); c.put(x + 7, y + 4, "W"); c.cells([(x + 4, y + 1), (x + 5, y + 2)], "s")


def hourglass(c, x, y):
    c.rect(x, y, x + 4, y, "y"); c.rect(x, y + 6, x + 4, y + 6, "y")
    c.cells([(x + 1, y + 1), (x + 3, y + 1), (x + 1, y + 5), (x + 3, y + 5)], "a")
    c.put(x + 2, y + 1, "Q"); c.put(x + 2, y + 2, "Q"); c.put(x + 2, y + 3, "a"); c.rect(x + 1, y + 4, x + 3, y + 5, "Q")
    c.put(x + 2, y + 4, "Q")


def sparkle(c, x, y, big=False):
    c.put(x, y, "X")
    c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "Y")
    if big:
        c.cells([(x - 2, y), (x + 2, y), (x, y - 2), (x, y + 2)], "Y")
        c.cells([(x - 2, y - 2), (x + 2, y - 2), (x - 2, y + 2), (x + 2, y + 2)], "y")


def dispenser(c, x, y):
    """The water-elemental dispenser: a round water spirit with a cute face sitting in a stone basin on a wooden stand,
    a brass tap on its side. (x, y) is the top-left of the water orb."""
    rows = {0: (3, 6), 1: (1, 8), 2: (0, 9), 3: (0, 9), 4: (0, 9), 5: (0, 9), 6: (1, 8), 7: (2, 7)}
    for r, (a, b) in rows.items():
        c.rect(x + a, y + r, x + b, y + r, "A")
    c.cells([(x + 2, y + 1), (x + 1, y + 2), (x + 1, y + 3), (x + 4, y + 0)], "a")
    c.rect(x + 7, y + 2, x + 8, y + 6, "E")
    c.cells([(x + 5, y - 1), (x + 4, y - 2)], "a")                         # a little curl of water on top
    c.cells([(x + 3, y + 4), (x + 6, y + 4)], "D")                         # its eyes
    c.cells([(x + 4, y + 5), (x + 5, y + 5)], "D")
    c.cells([(x + 2, y + 5), (x + 7, y + 5)], "h")
    c.rect(x - 1, y + 7, x + 10, y + 9, "S"); c.rect(x - 1, y + 7, x + 10, y + 7, "s")   # stone basin
    c.rect(x + 10, y + 8, x + 11, y + 8, "B"); c.put(x + 11, y + 9, "B")                 # tap
    c.rect(x, y + 10, x + 9, y + 10, "V"); c.rect(x + 1, y + 11, x + 8, y + 18, "W")   # wooden stand
    c.rect(x + 1, y + 14, x + 8, y + 14, "w"); c.rect(x + 4, y + 12, x + 5, y + 12, "B")


def bench(c, x, y, w):
    """A wooden bench from the front: backrest rows y..y+3, seat at y+8."""
    c.rect(x, y, x + w - 1, y + 1, "V"); c.rect(x, y + 2, x + w - 1, y + 2, "w")
    c.rect(x, y + 4, x + w - 1, y + 5, "W")
    c.rect(x + 1, y + 1, x + 1, y + 8, "w"); c.rect(x + w - 2, y + 1, x + w - 2, y + 8, "w")
    c.rect(x - 1, y + 8, x + w, y + 9, "V"); c.rect(x - 1, y + 10, x + w, y + 10, "W")
    c.rect(x, y + 11, x + 1, y + 15, "w"); c.rect(x + w - 2, y + 11, x + w - 1, y + 15, "w")


# --- desk scenes (front, behind the desk) --------------------------------------------------------------------------------
DW, DH = 40, 31


def desk_scene(a, f, mode):
    """mode 'type': hands tapping, ball glowing, an hourglass overhead. mode 'doze': head down on folded arms, z's."""
    pal = pv.PALS[a["pal"]]
    oy = 1 + PAD
    H2 = DH + PAD
    if mode == "type":
        body = figure(a, 0, oy=oy - pv.SIT_DROP, look="open", sit=True)
    else:
        body = figure(a, 0, oy=oy - pv.SIT_DROP, up=-(2 + (f % 2)), look="down", sit=True)
    ch = pv.C(DW, H2)
    for y in range(FH):
        for x in range(W):
            if body.px[y][x] is not None:
                ch.px[y][x + 5] = body.px[y][x]
    arms = pv.C(DW, H2)
    sc = a.get("sleeve_col", "T")
    long = a.get("sleeve") == "long"
    if mode == "type":
        lift = [(0, 1), (1, 0), (0, 0), (1, 1)][f]
        for x0, l in ((11, lift[0]), (21, lift[1])):
            arms.rect(x0, oy + 15, x0 + 1, oy + 16, sc)
            fx = (x0 + 1, x0 + 2) if x0 == 11 else (x0 - 1, x0)
            arms.rect(fx[0], oy + 17 - l, fx[1], oy + 17 - l, sc if long else "s")
            hx = (13, 14) if x0 == 11 else (19, 20)
            arms.cells([(hx[0], oy + 18 - l), (hx[1], oy + 18 - l)], "s")
        # the hands are part of the body outline, the desk goes in front
    else:                                                               # folded arms on the desk, the head resting on them
        y = oy + 17
        arms.rect(9, y, 24, y + 1, sc)
        arms.rect(13, y, 20, y, "s" if not long else sc)                 # hands tucked under the chin
        arms.rect(9, y, 10, y + 1, sc); arms.rect(23, y, 24, y + 1, sc)
    arms.outline()
    props = pv.C(DW, H2)
    if mode == "type":
        hourglass(props, 15, 0)
        if f % 2:
            props.put(17, 3, "Q")                                        # sand trickling
        ball_pal = GLOW if f % 2 == 0 else PROPS
    else:
        zz(props, 23, PAD + 6 - f * 2, big=(f == 2))
        if f >= 1:
            zz(props, 27, PAD + 1 - (f - 1) * 2)
        ball_pal = DIM
    props.outline()
    desk = pv.desk_front(DW, DH, lit=(mode == "type"))
    desk_big = pv.C(DW, H2)
    for y in range(DH):
        desk_big.px[y + PAD] = desk.px[y]
    if mode == "type" and f % 2 == 1:                                      # the runes scroll on the glass
        for y in range(H2):
            for x in range(DW):
                k = desk_big.px[y][x]
                if k == "r":
                    desk_big.px[y][x] = "R"
                elif k == "R":
                    desk_big.px[y][x] = "r"
    if mode == "type":                                                  # hands on the rune board, in front of the desk edge
        return scene([(ch, pal, 0, 0), (desk_big, ball_pal, 0, 0), (arms, pal, 0, 0), (props, PROPS, 0, 0)], DW, H2)
    return scene([(ch, pal, 0, 0), (arms, pal, 0, 0), (desk_big, ball_pal, 0, 0), (props, PROPS, 0, 0)], DW, H2)


# --- side view with a raised arm (the high-five) ------------------------------------------------------------------------
def side_figure(a, arm, look="open", mouth_kind=None, phase=0):
    c = pv.C(W + 6, FH)
    oy = PAD - (1 if a["outfit"] == "spirit" and phase else 0)
    pv.hair_behind(c, a, "side", oy)
    pv.legs_side(c, a, phase, oy)
    pv.torso_side(c, a, oy)
    pv.head_shape(c, oy)
    c.rect(17, oy + 6, 17, oy + 12, "s")
    c.rect(6, oy + 6, 6, oy + 12, "S")
    pv.face_side(c, a, oy, "open" if look == "open" else "down")
    pv.hair_side(c, a, oy)
    pv.ears(c, a, "side", oy)
    if a["hair"] == "hood":
        pv.face_side(c, a, oy, "open")
    if look == "happy" and a["race"] != "skeleton":
        c.rect(14, oy + 8, 15, oy + 10, "s"); c.cells([(14, oy + 9), (15, oy + 9), (16, oy + 10)], "L")
    if mouth_kind == "open" and a["race"] != "skeleton":
        c.cells([(16, oy + 12), (16, oy + 13)], "m")
    if arm == "up":                                                   # reaching forward and up, palm out
        pts = [(11, 16), (12, 16), (12, 15), (13, 15), (14, 15), (15, 14), (16, 14), (17, 13), (18, 13), (18, 14)]
        hand = [(19, 11), (20, 11), (19, 12), (20, 12), (19, 13), (20, 13), (20, 10)]
        c.outline()
        ca = pv.C(W + 6, FH)
        sleeve_paint(ca, a, [(x, y + oy) for x, y in pts], [(x, y + oy) for x, y in hand])
        return overlay(c, ca.outline())
    pv.arm_side(c, a, oy, phase)
    return c.outline()


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


def high_five(f):
    """Goblin boy (left, facing right) and elf girl (right, facing left): run up, slap, sparkle, grin."""
    g, e = AV["gob_m"], AV["elf_f"]
    w, h = 42, FH
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xa = 1
    xb = xa + [15, 11, 11, 13][f]                                       # flipped, her hand is at x 9-10 of her canvas
    arm = ["up", "up", "up", "down"][f]
    look = ["open", "happy", "happy", "happy"][f]
    a_img = side_figure(g, arm, look, "open" if f else None, phase=1 if f == 0 else 0).image(pv.PALS["gob_m"])
    b_img = flip(side_figure(e, arm, look, "open" if f else None, phase=1 if f == 0 else 0).image(pv.PALS["elf_f"]))
    out.alpha_composite(a_img, (xa, 0)); out.alpha_composite(b_img, (xb, 0))
    if f in (1, 2):
        sp = pv.C(w, h)
        hx = xa + 20
        sparkle(sp, hx, PAD + 8, big=(f == 1))
        if f == 2:
            sparkle(sp, hx - 3, PAD + 4); sparkle(sp, hx + 4, PAD + 5)
        sp.outline()
        out.alpha_composite(sp.image(PROPS))
    return out


# --- each action: list of (avatar id, [frame images]) --------------------------------------------------------------------
def act_idle(a):
    ghost = a["outfit"] == "spirit"
    pal = pv.PALS[a["pal"]]
    if ghost:
        frames = [figure(a, 0), figure(a, 1, oy=PAD - 1), figure(a, 2, oy=PAD - 1, look="down"), figure(a, 3)]
    else:
        frames = [figure(a, 0), figure(a, 0, up=-1), figure(a, 0, look="down"), figure(a, 0)]
    return [f.image(pal) for f in frames]


def act_wave(a):
    pal = pv.PALS[a["pal"]]
    return [figure(a, 0, arms="wave", arm_f=f, mouth_kind="open" if f else "smile", look="open" if f == 0 else "happy").image(pal)
            for f in (0, 1, 0)]


def act_type(a):
    return [desk_scene(a, f, "type") for f in range(4)]


def act_doze(a):
    return [desk_scene(a, f, "doze") for f in range(3)]


def act_drink(a):
    pal = pv.PALS[a["pal"]]
    w = 38
    out = []
    for f in range(3):
        d = pv.C(w, FH)
        dispenser(d, 1, PAD + 8)
        if f == 0:
            d.cells([(12, PAD + 18)], "a")                                   # a drop from the tap
        d.outline()
        body = figure(a, 0, arms="mug_up" if f == 1 else "mug", look="down" if f == 1 else "open",
                      mouth_kind=None if f == 1 else ("smile" if f == 2 else None))
        img = scene([(d, PROPS, 0, 0)], w, FH)
        img.alpha_composite(body.image(pal), (13, 0))
        m = pv.C(w, FH)
        mug(m, 13 + 12, PAD + (12 if f == 1 else 16))
        m.outline()
        img.alpha_composite(m.image(PROPS))
        out.append(img)
    return out


def act_stretch(a):
    pal = pv.PALS[a["pal"]]
    return [figure(a, 0, look="open").image(pal),
            figure(a, 0, arms="up", look="down", mouth_kind="yawn").image(pal),
            figure(a, 0, up=1, arms="up_high", look="down", mouth_kind="yawn").image(pal),
            figure(a, 0, look="happy", mouth_kind="smile").image(pal)]


def act_sit(a):
    """The one sitting body on three different seats (the seat is its own layer, seat top at a fixed height):
    front on a stool, bench and armchair, then the same from the side. Feet swing from frame to frame."""
    pal = pv.PALS[a["pal"]]
    out = []
    for i, (kind, sw) in enumerate((("stool", 0), ("bench", 1), ("sofa", 2))):
        body = pv.sit_front_body(a, PAD, swing=sw, look="down" if i == 2 else "open", h=FH).outline()
        out.append(pv.compose_at([(pv.seat(kind, "front", PAD, 30, FH, 14), PROPS, 0, 0), (body, pal, 3, 0)], 30, FH))
    for kind, sw in (("stool", 0), ("bench", 1), ("sofa", 0)):
        body = pv.sit_side_body(a, PAD, swing=sw, h=FH).outline()
        out.append(pv.compose_at([(pv.seat(kind, "side", PAD, 28, FH, 12), PROPS, 0, 0), (body, pal, 1, 0)], 28, FH))
    return out


def act_chat(a, icon):
    pal = pv.PALS[a["pal"]]
    w = 34
    out = []
    for f in range(3):
        body = figure(a, 0, head_dy=1 if f == 1 else 0, look="happy" if f == 1 else "open",
                      mouth_kind="talk" if f != 1 else "smile")
        img = Image.new("RGBA", (w, FH), (0, 0, 0, 0))
        img.alpha_composite(body.image(pal), (0, 0))
        bc = pv.C(w, FH)
        bubble(bc, 21, 1, "dots" if f < 2 else icon, f)
        bc.outline()
        img.alpha_composite(bc.image(PROPS))
        out.append(img)
    return out


def act_cheer(a):
    pal = pv.PALS[a["pal"]]
    return [figure(a, 0, oy=PAD, up=-1, look="happy", mouth_kind="smile").image(pal),
            figure(a, 0, oy=PAD - 4, arms="up", legs="jump", look="happy", mouth_kind="open").image(pal),
            figure(a, 0, oy=PAD - 2, arms="up_high", legs="jump", look="happy", mouth_kind="open").image(pal),
            figure(a, 0, look="happy", mouth_kind="smile").image(pal)]


ROWS = [
    ("待機", "呼吸、眨眼", [("gob_m", act_idle), ("elf_f", act_idle), ("und_m", act_idle)]),
    ("揮手", "有人進來時打招呼", [("elf_m", act_wave), ("gob_f", act_wave), ("und_f", act_wave)]),
    ("打字", "專注中：手在符文鍵盤上、水晶球閃、頭上小沙漏", [("gob_m", act_type), ("und_f", act_type), ("elf_m", act_type)]),
    ("趴桌打瞌睡", "離開：趴在桌上、冒 z", [("gob_f", act_doze), ("und_m", act_doze), ("elf_f", act_doze)]),
    ("喝水", "水元素飲水機旁拿杯子喝", [("elf_m", act_drink), ("und_f", act_drink), ("gob_m", act_drink)]),
    ("伸懶腰", "專注一輪結束", [("gob_f", act_stretch), ("und_m", act_stretch), ("elf_f", act_stretch)]),
    ("坐著", "通用坐姿，椅子另一層：凳子、長凳、沙發；正面＋側面，晃腳", [("und_f", act_sit), ("gob_m", act_sit), ("elf_f", act_sit)]),
    ("聊天", "說話、點頭、泡泡", [("elf_m", lambda a: act_chat(a, "note")), ("gob_f", lambda a: act_chat(a, "heart")),
                           ("und_m", lambda a: act_chat(a, "tea"))]),
    ("歡呼", "開心地跳起來", [("und_f", act_cheer), ("gob_m", act_cheer), ("elf_m", act_cheer)]),
    ("擊掌", "兩個角色一起（專注結束時）", [("pair", None)]),
]


def main():
    S = 4
    label_w = 84
    gap, group_gap = 3, 12
    rows = []
    for name, note, groups in ROWS:
        gs = []
        for aid, fn in groups:
            if aid == "pair":
                gs.append(("哥布林・男 ＋ 精靈・女", [high_five(f) for f in range(4)]))
            else:
                gs.append((AV[aid]["name"].split("（")[0], fn(AV[aid])))
        rows.append((name, note, gs))
    width = max(label_w + sum(sum(i.width for i in fr) + gap * (len(fr) - 1) + group_gap for _, fr in gs) for _, _, gs in rows) + 4
    row_h = FH + 14
    title_h = 18
    art = pv.Art(width, title_h + row_h * len(rows) + 4, scale=S, color=(228, 198, 152, 255))
    pv.wood_floor(art)
    pv.ptext(art, "公會角色 動作預覽（每個動作 2–4 格，6 個角色共用；每列示範 2–3 個角色）", 6, 4, 32, (70, 44, 24, 255),
             stroke=(250, 236, 210, 255))
    for r, (name, note, gs) in enumerate(rows):
        y0 = title_h + r * row_h
        art.rect(2, y0 - 1, width - 4, 1, (186, 150, 104, 255))
        pv.ptext(art, f"{r + 1}. {name}", 4, y0 + 10, 30, (60, 36, 20, 255), stroke=(250, 236, 210, 255))
        words, line = [], ""
        for ch in note:                                                     # wrap the note into the label column
            line += ch
            if len(line) >= 10:
                words.append(line); line = ""
        words = [w for w in words]
        for i in range(1, len(words)):                                       # no line starts with punctuation
            while words[i] and words[i][0] in "、：，）":
                words[i - 1] += words[i][0]; words[i] = words[i][1:]
        if line:
            words.append(line)
        for i, ln in enumerate(words):
            pv.ptext(art, ln, 4, y0 + 20 + i * 6, 20, (90, 60, 34, 255))
        x = label_w
        for gname, frames in gs:
            gx = x
            for img in frames:
                art.shadow(x + img.width / 2 if img.width <= W + 2 else x + img.width - W / 2 - 1, y0 + FH - 1, w=10, alpha=40) \
                    if False else None
                art.sprite(img, x, y0, bottom_center=False)
                x += img.width + gap
            pv.ptext(art, gname, (gx + x - gap) / 2, y0 + FH + 1, 20, (90, 60, 34, 255), anchor="c")
            x += group_gap - gap
    art.save(OUT)


if __name__ == "__main__":
    main()
