#!/usr/bin/env python3
"""Production art for the guild avatars (GUILD.md §2): layered sprite strips the game composes at runtime.

    python3 mac/tools/make_avatars.py        # writes mac/Resources/Avatars/** and mac/Resources/Avatars/manifest.json

Every layer option is one horizontal PNG strip of the same N frames (FW x FH each), in the same order. The renderer draws
frame i of each layer, in LAYER_ORDER, at the same spot, swapping the key colours (skin, hair, eye flame), then adds the
one-pixel outline around the result and finally draws fx (see the manifest's "render" notes).

The bodies, clothes, faces and the default hairstyles are the approved art from make_avatars_preview.py (cut into layers);
the default combination of each race and sex reproduces those designs exactly (self-checked at the end).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_avatars_preview as pv  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "Resources", "Avatars"))
FW, FH = 32, 40
DX = 4                        # the 24-px-wide rig sits at x = 4 of the frame
OY = 10                       # rig baseline: head top at OY + 3, feet on row OY + 26
ANCHOR = (16, OY + 27)        # feet point: the floor line under the feet, centred
SEAT_Y = ANCHOR[1] - (OY + pv.SEAT)   # the seat top is this many px above the anchor in sitting frames
RW = pv.W                     # rig width (24)
LAYER_ORDER = ["hair_back", "body", "bottom", "top", "shoes", "brows", "eyes", "mouth", "hair_front", "hat", "fx"]

# --- key colours (exact RGB the renderer swaps) ----------------------------------------------------------------------------
KEY_SKIN = {"S": (160, 0, 160), "s": (255, 0, 255), "x": (255, 128, 255)}     # shadow, base, highlight
KEY_HAIR = {"J": (0, 160, 0), "H": (0, 255, 0), "h": (128, 255, 128)}
KEY_FLAME = {"e": (255, 0, 0)}
ALL_KEYS = set(KEY_SKIN.values()) | set(KEY_HAIR.values()) | set(KEY_FLAME.values())


def hexc(c):
    return "#%02x%02x%02x" % tuple(c)


# --- bodies ----------------------------------------------------------------------------------------------------------------
BODIES = {  # body key -> (approved avatar id, race for skins, outline)
    "goblin_m": "gob_m", "goblin_f": "gob_f", "elf_m": "elf_m", "elf_f": "elf_f", "undead_m": "und_m", "undead_f": "und_f"}
AVB = {a["id"]: a for a in pv.AVATARS}
BODY_TYPE = {"goblin_m": "goblin_m", "goblin_f": "goblin_f", "elf_m": "elf", "elf_f": "elf", "undead_m": "skeleton",
             "undead_f": "spirit"}
OUTLINE = {"goblin_m": (31, 43, 20), "goblin_f": (31, 43, 20), "elf_m": (58, 42, 38), "elf_f": (58, 42, 38),
           "undead_m": (34, 30, 46), "undead_f": (62, 58, 104)}
FACES = {"round": {0: (8, 15), 1: (7, 16), 10: (7, 16), 11: (8, 15)},
         "pointed": {0: (8, 15), 1: (7, 16), 9: (7, 16), 10: (8, 15), 11: (9, 14)},
         "square": {0: (7, 16), 11: (7, 16)}}


def tone(s, S=None, x=None):
    S = S or tuple(int(c * 0.74) for c in s)
    x = x or tuple(min(255, int(c + (255 - c) * 0.45)) for c in s)
    return [S, s, x]


SKINS = {
    "goblin": {"light": tone((136, 200, 88)), "grass": tone((109, 179, 63), (76, 134, 44), (154, 212, 98)),
               "moss": tone((86, 150, 62)), "deep": tone((64, 118, 56))},
    "elf": {"fair": tone((250, 226, 204), (226, 192, 166), (255, 240, 226)), "warm": tone((240, 208, 178)),
            "tan": tone((220, 176, 134)), "bronze": tone((186, 136, 98))},
    "bone": {"bone": tone((240, 236, 222), (196, 190, 172), (255, 252, 244)), "ivory": tone((232, 218, 186)),
             "ash": tone((206, 204, 200)), "slate": tone((166, 168, 174))},
    "spirit": {"pale_blue": tone((232, 242, 252), (196, 212, 238), (255, 255, 255)), "ice": tone((214, 238, 248)),
               "pale_violet": tone((234, 226, 252)), "lavender": tone((210, 198, 244))},
}
SKIN_SET = {"goblin_m": "goblin", "goblin_f": "goblin", "elf_m": "elf", "elf_f": "elf", "undead_m": "bone", "undead_f": "spirit"}
HAIR_COLORS = {  # id -> [shadow, base, highlight]
    "black": [(34, 30, 42), (54, 48, 62), (96, 90, 108)], "darkbrown": [(46, 30, 22), (70, 46, 32), (112, 78, 52)],
    "chestnut": [(112, 70, 36), (150, 100, 52), (196, 146, 84)], "orange": [(168, 62, 36), (214, 96, 52), (246, 144, 88)],
    "yellow": [(176, 108, 38), (222, 150, 58), (248, 194, 112)], "blonde": [(206, 186, 118), (242, 230, 172), (255, 252, 224)],
    "silver": [(176, 180, 198), (222, 226, 234), (252, 253, 255)], "pink": [(198, 104, 140), (240, 150, 180), (255, 198, 216)],
    "lavender": [(134, 110, 188), (176, 150, 222), (216, 198, 246)], "mint": [(84, 166, 186), (128, 214, 214), (200, 250, 246)],
    "navy": [(48, 66, 128), (70, 98, 172), (112, 142, 212)], "forest": [(48, 96, 58), (72, 132, 82), (112, 172, 112)],
}
FLAMES = {"cyan": (120, 240, 220), "violet": (200, 140, 255), "green": (150, 240, 110), "orange": (255, 170, 80)}

HAIRS = {
    "goblin_m": ["tuft", "mohawk", "topknot", "bald_ring", "dreads", "wild", "bun", "spikes"],
    "goblin_f": ["braids", "bun", "dreads", "wild", "tuft", "pigtails", "mohawk", "bob"],
    "elf_m": ["neat", "long", "halfup", "ponytail", "side_braid", "waves", "messy", "braided_crown"],
    "elf_f": ["long_wreath", "braided_crown", "side_braid", "waves", "long", "ponytail", "halfup", "wreath_updo"],
    "undead_m": ["hood", "bare", "crack", "horns", "long_horns", "ragged_hood", "bone_crown", "candle"],
    "undead_f": ["drift", "flame", "mist", "wisp_twins", "glass_short", "long_wave", "side_wisp", "flame_crown"],
}
EYES = ["round", "narrow", "sparkle", "dot", "sleepy", "sharp", "lashes", "wide"]
BROWS = ["thin", "thick", "faint", "none"]
MOUTHS = ["line", "smile", "smirk", "open", "pout", "cat"]
SKULL_MOUTHS = ["teeth", "grin", "gap", "jaw", "fang", "stitch"]

# fixed (non-key) colours used by hair accents, hats and fx
ACCENT = {"A": (250, 212, 90), "a": (255, 255, 255), "l": (90, 160, 80), "k": (232, 150, 170), "Z": (224, 255, 248),
          "f": (120, 236, 214), "T": (178, 160, 228), "U": (138, 120, 198), "n": (150, 140, 120), "N": (206, 198, 176),
          "C": (98, 84, 148), "c": (66, 56, 108), "v": (132, 120, 184), "d": (40, 34, 54), "W": (238, 228, 200),
          "w": (200, 186, 150), "F": (255, 170, 60), "R": (255, 236, 140), "b": (120, 90, 60)}
HAT = {"F": (70, 110, 170), "f": (48, 78, 130), "L": (110, 150, 210), "B": (232, 196, 80), "X": (255, 255, 255),
       "x": (210, 200, 190), "R": (220, 70, 80), "O": (40, 34, 50)}
FX = dict(pv.FURN, **{"X": (255, 255, 255), "x": (200, 210, 230), "D": (60, 50, 70), "H": (238, 90, 110),
                      "h": (255, 160, 170), "Y": (250, 214, 90), "y": (200, 150, 40), "a": (170, 222, 255),
                      "Q": (232, 220, 190), "z": (150, 200, 255), "O": (60, 40, 30)})


# --- frames ----------------------------------------------------------------------------------------------------------------
def F(view, **kw):
    d = dict(view=view, phase=0, dy=0, up=0, hd=0, sit=False, swing=0, eye="open", mouth="closed", arms="hang",
             legs="stand", fx=None, bob=0)
    d.update(kw)
    return d


FRAMES, ANIMS = [], {}


def anim(name, view, frames, fps, loop):
    idx = []
    for fr in frames:
        idx.append(len(FRAMES))
        FRAMES.append(dict(fr, anim=name))
    ANIMS.setdefault(name, {})[view] = {"frames": idx, "fps": fps, "loop": loop}


for v in ("front", "back", "side"):                                     # idle: breathe, blink (no blink from behind)
    anim("idle", v, [F(v), F(v, up=-1, bob=-1), F(v, up=-1, bob=-1, eye="closed" if v != "back" else "open"), F(v)], 3, True)
for v in ("front", "back", "side"):
    anim("walk", v, [F(v, phase=p, bob=-1 if p in (1, 2) else 0) for p in range(4)], 8, True)
anim("sit", "front", [F("front", sit=True, swing=1), F("front", sit=True, swing=2)], 2, True)
anim("sit", "side", [F("side", sit=True, swing=0), F("side", sit=True, swing=1)], 2, True)
anim("type", "front", [F("front", sit=True, arms="type%d" % i, fx="hourglass%d" % (i % 2)) for i in range(4)], 6, True)
anim("doze", "front", [F("front", sit=True, up=-(2 + i % 2), eye="closed", arms="fold", fx="z%d" % i) for i in range(3)], 2, True)
anim("drink", "front", [F("front", arms="mug", fx="mug"), F("front", arms="mug_up", eye="closed", fx="mug_up"),
                        F("front", arms="mug", eye="happy", mouth="happy", fx="mug")], 3, False)
anim("wave", "front", [F("front", arms="wave0", mouth="happy"), F("front", arms="wave1", eye="happy", mouth="open"),
                       F("front", arms="wave0", mouth="happy")], 6, False)
anim("stretch", "front", [F("front"), F("front", arms="up", eye="closed", mouth="open"),
                          F("front", up=1, arms="up_high", eye="closed", mouth="open"), F("front", eye="happy", mouth="happy")], 3, False)
anim("chat", "front", [F("front", mouth="open", fx="bubble0"), F("front", hd=1, eye="happy", mouth="happy", fx="bubble1"),
                       F("front", mouth="open", fx="bubble2")], 3, True)
anim("cheer", "front", [F("front", up=-1, eye="happy", mouth="happy"),
                        F("front", dy=-4, arms="up", legs="jump", eye="happy", mouth="open", fx="stars0"),
                        F("front", dy=-2, arms="up_high", legs="jump", eye="happy", mouth="open", fx="stars1"),
                        F("front", eye="happy", mouth="happy")], 6, False)
anim("highfive", "side", [F("side", phase=1, arms="hf_reach"), F("side", arms="hf", eye="happy", mouth="open", fx="spark0"),
                          F("side", arms="hf", eye="happy", mouth="open", fx="spark1"), F("side", eye="happy", mouth="happy")], 6, False)
N = len(FRAMES)
HIGHFIVE_GAP = 17            # anchors this far apart (left one mirrored to face right) and the hands meet


def heads(fr):
    """Where the head base row (the rig's `oy` for the head) is in this frame, and the upper-body base."""
    oy = OY + fr["dy"]
    u = oy + (pv.SIT_DROP if fr["sit"] else 0) - fr["up"]
    return oy, u, u + fr["hd"]


# --- small drawing helpers -------------------------------------------------------------------------------------------------
def C(w=RW):
    return pv.C(w, FH)


def paint_arm(c, a, pts, hand, sleeve_col=None):
    sc = sleeve_col or a.get("sleeve_col", "T")
    long = a.get("sleeve", "short") == "long"
    for i, (x, y) in enumerate(pts):
        c.put(x, y, sc if (long or i < 4) else "s")
    if long and a.get("cuff") and pts:
        c.cells(pts[-2:], "u")
    c.cells(hand, "s")


def arm_pose(c, a, mode, u, fr):
    """Draws the custom arm poses (front view unless noted); returns True if it drew one."""
    m = lambda pts: [(x, y + u) for x, y in pts]  # noqa: E731
    if mode in ("up", "up_high"):
        for side in (-1, 1):
            if mode == "up":
                pts = [(6, 15), (7, 15), (5, 14), (6, 14)] + [(x, y) for y in range(13, 6, -1) for x in (4, 5)]
                hand = [(4, 5), (5, 5), (4, 6), (5, 6)]
            else:
                pts = [(6, 15), (7, 15), (5, 14), (6, 14)] + [(x, y) for y in range(13, 5, -1) for x in (4, 5)] + \
                      [(5, 5), (6, 5), (6, 4), (7, 4), (7, 3), (8, 3), (8, 2), (9, 2)]
                hand = [(10, 0), (11, 0), (10, 1), (11, 1), (9, 1)]
            if side > 0:
                pts = [(RW - 1 - x, y) for x, y in pts]
                hand = [(RW - 1 - x, y) for x, y in hand]
            paint_arm(c, a, m(pts), m(hand))
        return True
    if mode.startswith("wave"):
        f = int(mode[-1])
        pts = [(16, 15), (17, 15), (17, 14), (18, 14), (18, 13), (19, 13)]
        if f == 0:
            pts += [(18, 12), (19, 12)]; hand = [(18, 10), (19, 10), (18, 11), (19, 11)]
        else:
            pts += [(19, 12), (20, 12)]; hand = [(20, 10), (21, 10), (20, 11), (21, 11), (21, 9)]
        paint_arm(c, a, m(pts), m(hand))
        return True
    if mode in ("mug", "mug_up"):
        if mode == "mug_up":
            pts = [(16, 15), (17, 15), (17, 16), (17, 17), (16, 16), (16, 17), (15, 16)]; hand = [(15, 14), (15, 15), (14, 15)]
        else:
            pts = [(16, 15), (17, 15), (17, 16), (17, 17), (17, 18), (16, 18)]; hand = [(15, 18), (15, 17)]
        paint_arm(c, a, m(pts), m(hand))
        return True
    if mode.startswith("type"):
        lift = [(0, 1), (1, 0), (0, 0), (1, 1)][int(mode[-1])]
        sc = a.get("sleeve_col", "T")
        long = a.get("sleeve") == "long"
        for x0, l in ((6, lift[0]), (16, lift[1])):
            c.rect(x0, u + 15, x0 + 1, u + 16, sc)
            fx0 = (x0 + 1, x0 + 2) if x0 == 6 else (x0 - 1, x0)
            c.rect(fx0[0], u + 17 - l, fx0[1], u + 17 - l, sc if long else "s")
            hx = (8, 9) if x0 == 6 else (14, 15)
            c.cells([(hx[0], u + 18 - l), (hx[1], u + 18 - l)], "s")
        return True
    if mode == "fold":
        sc = a.get("sleeve_col", "T")
        long = a.get("sleeve") == "long"
        y = OY + pv.SIT_DROP + 17
        c.rect(4, y, 19, y + 1, sc)
        c.rect(8, y, 15, y, "s" if not long else sc)
        c.rect(4, y, 5, y + 1, sc); c.rect(18, y, 19, y + 1, sc)
        return True
    if mode in ("hf", "hf_reach"):                                      # side view, facing right
        if mode == "hf":
            pts = [(11, 16), (12, 16), (12, 15), (13, 15), (14, 15), (15, 14), (16, 14), (17, 13), (18, 13), (18, 14)]
            hand = [(19, 11), (20, 11), (19, 12), (20, 12), (19, 13), (20, 13), (20, 10)]
        else:
            pts = [(11, 16), (12, 16), (12, 15), (13, 15), (14, 14), (15, 14), (15, 13), (16, 13)]
            hand = [(17, 11), (18, 11), (17, 12), (18, 12), (18, 10)]
        paint_arm(c, a, m(pts), m(hand))
        return True
    return False


SKIN_K = ("s", "S", "x")


def split(tmp, L, rule):
    for y in range(FH):
        for x in range(RW):
            k = tmp.px[y][x]
            if k is not None:
                L[rule(k)].put(x, y, k)


def lower_rule_for(a):
    def rule(k):
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
    return rule


def upper_rule(k):
    return "body" if k in SKIN_K else "top"


def head_shape(c, y, face):
    rows = FACES[face]
    for r in range(12):
        x0, x1 = rows.get(r, (6, 17))
        c.rect(x0, y + 3 + r, x1, y + 3 + r, "s")
    for r in range(3, 10):
        c.put(rows.get(r, (6, 17))[1], y + 3 + r, "S")
    c.cells([(8, y + 4), (7, y + 5)], "x")


def jump_legs(t, a, oy):
    pv.legs_front(t, a, oy, 0)
    if a["outfit"] == "spirit":
        return
    t.rect(6, oy + 24, 17, oy + 27, None)
    for x in (9, 13):
        if a["race"] == "skeleton":
            t.put(10 if x == 9 else 13, oy + 23, "P")
        else:
            t.rect(x, oy + 23, x + 1, oy + 23, "P" if a["outfit"] == "tunic" else "s")
        t.rect(x, oy + 24, x + 1, oy + 24, "K")
    if a["outfit"] == "gown":
        t.rect(6, oy + 24, 17, oy + 24, "u"); t.rect(9, oy + 25, 10, oy + 25, "K"); t.rect(13, oy + 25, 14, oy + 25, "K")


# --- body + clothes per frame -----------------------------------------------------------------------------------------------
def body_layers(bk, face, fr):
    a = AVB[BODIES[bk]]
    race = a["race"]
    plain = dict(a, cape=False)
    view = fr["view"]
    oy, u, hy = heads(fr)
    L = {n: C() for n in ("body", "bottom", "top", "shoes")}
    b = L["body"]
    arm_mask = set()
    raised = fr["arms"] in ("up", "up_high", "wave0", "wave1", "mug_up", "hf", "hf_reach")
    if view == "front":
        pv.ears(b, {"ears": a["ears"]}, "front", hy)
        head_shape(b, hy, face)
        if race == "goblin":
            b.cells([(11, hy + 11), (12, hy + 11)], "S")
            if a["girl"]:
                b.put(12, hy + 13, "t")
            else:
                b.cells([(10, hy + 12), (13, hy + 12)], "t")
        if race == "skeleton":
            b.cells([(11, hy + 11), (12, hy + 11)], "d")
        b.cells([(7, hy + 11), (16, hy + 11)], "p")
        if race not in ("skeleton", "ghost"):
            b.rect(8, u + 15, 15, u + 22, "s")
        # legs and the clothes below the waist
        t = C()
        if fr["sit"]:
            pv.sit_legs_front(t, a, oy, fr["swing"])
        elif fr["legs"] == "jump":
            jump_legs(t, a, oy)
        else:
            pv.legs_front(t, a, oy, fr["phase"])
            if race not in ("skeleton", "ghost"):
                for x, lift in ((9, 1 if fr["phase"] == 1 else 0), (13, 1 if fr["phase"] == 3 else 0)):
                    b.rect(x, oy + 23, x + 1, oy + 26 - lift, "s")
        split(t, L, lower_rule_for(a))
        t = C()
        pv.torso_front(t, plain, u)
        split(t, L, upper_rule)
        # arms
        t = C()
        if fr["arms"] == "hang":
            pv.arms_front(t, plain, u, fr["phase"])
        elif fr["arms"] in ("wave0", "wave1", "mug", "mug_up"):
            sw = 0
            for y in range(u + 16 + sw, u + 21 + sw):
                pass
            t2 = C()
            pv.arms_front(t2, plain, u, 0)
            for y in range(FH):                                          # keep only the viewer's left arm hanging
                for x in range(0, 9):
                    if t2.px[y][x] is not None:
                        t.put(x, y, t2.px[y][x])
            arm_pose(t, a, fr["arms"], u, fr)
        else:
            arm_pose(t, a, fr["arms"], u, fr)
        for y in range(FH):
            for x in range(RW):
                if t.px[y][x] is not None:
                    arm_mask.add((x, y))
        split(t, L, upper_rule)
        if a.get("cape"):                                                # the cape hangs behind: only what shows
            cape = C()
            cape.rect(6, u + 15, 17, u + 22, "C"); cape.rect(6, u + 22, 17, u + 22, "c")
            for y in range(FH):
                for x in range(RW):
                    if cape.px[y][x] and all(L[n].px[y][x] is None for n in L):
                        L["top"].put(x, y, cape.px[y][x])
            L["top"].cells([(8, u + 15), (15, u + 15)], "C"); L["top"].cells([(9, u + 15), (14, u + 15)], "A")
    elif view == "back":
        pv.ears(b, {"ears": a["ears"]}, "back", hy)
        head_shape(b, hy, face)
        b.rect(17, hy + 6, 17, hy + 12, "s") if False else None
        t = C()
        pv.legs_front(t, a, oy, fr["phase"], back=True)
        if race not in ("skeleton", "ghost"):
            for x, lift in ((9, 1 if fr["phase"] == 1 else 0), (13, 1 if fr["phase"] == 3 else 0)):
                b.rect(x, oy + 23, x + 1, oy + 26 - lift, "s")
            b.rect(8, u + 15, 15, u + 22, "s")
        split(t, L, lower_rule_for(a))
        t = C()
        pv.torso_front(t, plain, u, back=True)
        split(t, L, upper_rule)
        t = C()
        pv.arms_front(t, plain, u, fr["phase"])
        for y in range(FH):
            for x in range(RW):
                if t.px[y][x] is not None:
                    arm_mask.add((x, y))
        if a.get("cape"):                                                # over the back, under the arms
            cape = C()
            cape.rect(7, u + 15, 16, u + 22, "C"); cape.rect(7, u + 22, 16, u + 22, "c"); cape.rect(16, u + 15, 16, u + 21, "c")
            for y in range(FH):
                for x in range(RW):
                    if cape.px[y][x] and (x, y) not in arm_mask:
                        L["top"].put(x, y, cape.px[y][x])
        split(t, L, upper_rule)
    else:                                                                # side, facing right (mirrored to the left later)
        head_shape(b, hy, face)
        b.rect(17, hy + 6, 17, hy + 12, "s")
        b.rect(6, hy + 6, 6, hy + 12, "S")
        pv.ears(b, {"ears": a["ears"]}, "side", hy)
        if race == "goblin":
            b.cells([(18, hy + 10), (18, hy + 11)], "s"); b.put(18, hy + 11, "S")
            if not a["girl"]:
                b.put(17, hy + 12, "t")
        if race == "skeleton":
            b.put(17, hy + 11, "d")
        b.put(13, hy + 11, "p")
        t = C()
        if fr["sit"]:
            if a.get("cape"):
                pass
            pv.sit_legs_side(t, a, oy, fr["swing"])
        else:
            pv.legs_side(t, a, fr["phase"], oy)
        split(t, L, lower_rule_for(a))
        t = C()
        pv.torso_side(t, plain, u)
        split(t, L, upper_rule)
        t = C()
        if fr["arms"] in ("hf", "hf_reach"):
            arm_pose(t, a, fr["arms"], u, fr)
        elif fr["sit"]:
            pts = [(11, 16), (12, 16), (11, 17), (12, 17), (12, 18), (13, 18), (13, 19), (14, 19)]
            paint_arm(t, a, [(x, u + y) for x, y in pts], [(15, u + 19), (15, u + 20), (14, u + 20)])
        else:
            pv.arm_side(t, a, u, fr["phase"])
        for y in range(FH):
            for x in range(RW):
                if t.px[y][x] is not None:
                    arm_mask.add((x, y))
        split(t, L, upper_rule)
        if a.get("cape"):
            cape = C()
            if fr["sit"]:
                cape.rect(6, u + 15, 10, u + 20, "C"); cape.rect(6, u + 20, 10, u + 20, "c")
            else:
                cape.rect(6, u + 15, 10, u + 22, "C"); cape.rect(6, u + 22, 10, u + 22, "c")
            for y in range(FH):
                for x in range(RW):
                    if cape.px[y][x] and all(L[n].px[y][x] is None for n in L):
                        L["top"].put(x, y, cape.px[y][x])
            L["top"].cells([(9, u + 15), (10, u + 15), (9, u + 16), (10, u + 16)], "C"); L["top"].put(13, u + 15, "A")
    for (x, y) in arm_mask:                                              # hands and forearms in front of the clothes
        k = b.px[y][x]
        if k in SKIN_K and (L["top"].px[y][x] is not None or L["bottom"].px[y][x] is not None):
            L["top"].put(x, y, k)
    if raised:                                                           # a dark line where a raised arm crosses the body
        ring = set()
        for (x, y) in arm_mask:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in arm_mask and 0 <= p[0] < RW and 0 <= p[1] < FH:
                    ring.add(p)
        for (x, y) in ring:
            if b.px[y][x] is not None or L["top"].px[y][x] is not None:
                L["top"].put(x, y, "O")
    return L


# --- hairstyles --------------------------------------------------------------------------------------------------------------
# A style is drawn per view into a back canvas (under the body) and a front canvas (over the face). `y` is the head base.
def fake(h):
    return {"hair": h}


def long_front(c, y):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 10, y + 6, "H"); c.rect(13, y + 6, 17, y + 6, "H")
    c.cells([(6, y + 7), (6, y + 8), (6, y + 9), (17, y + 7), (17, y + 8), (17, y + 9), (7, y + 7), (16, y + 7)], "H")
    c.cells([(11, y + 5), (12, y + 5)], "J")
    c.cells([(8, y + 3), (9, y + 3), (7, y + 4)], "h")


def short_front(c, y, cowlick=True):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 11, y + 6, "H"); c.cells([(16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (6, y + 8), (12, y + 6)], "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (11, y + 4)], "h")
    c.cells([(14, y + 5), (15, y + 5)], "J")
    if cowlick:
        c.cells([(10, y + 1), (11, y + 1)], "H")


def bangs_front(c, y):
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(6, y + 3, 17, y + 4, "H")
    c.rect(6, y + 5, 9, y + 5, "H"); c.rect(13, y + 5, 17, y + 5, "H")
    c.cells([(6, y + 6), (7, y + 6), (16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7), (8, y + 6), (14, y + 6)], "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
    c.cells([(11, y + 4), (12, y + 4)], "J")
    c.cells([(11, y + 5), (12, y + 5)], "D")


def side_cap(c, y, back_to=10, cowlick=False):
    """A full head of hair in profile (facing right): top, the back of the head, a little fringe in front."""
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
    c.rect(6, y + 6, 11, y + back_to, "H")
    c.cells([(16, y + 6), (17, y + 6), (17, y + 7), (13, y + 6)], "H")
    c.rect(6, y + back_to, 11, y + back_to, "J")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
    if cowlick:
        c.cells([(10, y + 1), (11, y + 1)], "H")


def back_cap(c, y, bottom=14):
    """The back of a full head of hair."""
    c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + min(bottom, 13), "H")
    if bottom >= 14:
        c.rect(7, y + 14, 16, y + 14, "H")
    c.rect(7 if bottom >= 14 else 6, y + bottom, 16 if bottom >= 14 else 17, y + bottom, "J")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (8, y + 5)], "h")


def sides(c, y, top, bottom, x_in=(4, 6), x_out=(17, 19)):
    c.rect(x_in[0], y + top, x_in[1], y + bottom, "H"); c.rect(x_out[0], y + top, x_out[1], y + bottom, "H")
    c.cells([(x_in[0], y + bottom), (x_out[1], y + bottom), (x_in[0], y + bottom - 1), (x_out[1], y + bottom - 1)], "J")


def behind_side(c, y, bottom, wavy=False):
    c.rect(5, y + 6, 9, y + bottom, "H"); c.rect(5, y + bottom - 1, 9, y + bottom, "J")
    if wavy:
        c.cells([(4, y + 12), (4, y + 13), (4, y + 17)], "H")


def down_back(c, y, bottom, wavy=False):
    """Long hair falling over the back (back view)."""
    c.rect(6, y + 14, 17, y + bottom, "H"); c.rect(6, y + bottom - 1, 17, y + bottom, "J")
    c.rect(9, y + 14, 9, y + bottom - 2, "J"); c.rect(14, y + 14, 14, y + bottom - 2, "J")
    if wavy:
        c.clear([(6, y + bottom), (9, y + bottom), (12, y + bottom), (15, y + bottom)])
        for yy in range(y + 12, y + bottom, 4):
            c.cells([(5, yy), (18, yy + 2)], "H")


def braid(c, x0, x1, y0, y1, tie="k"):
    for yy in range(y0, y1 + 1):
        c.rect(x0, yy, x1, yy, "H" if (yy - y0) % 2 == 0 else "J")
        if (yy - y0) % 2 == 0:
            c.put(x0, yy, "h")
    c.rect(x0, y1 + 1, x1, y1 + 1, tie)
    c.rect(x0, y1 + 2, x1, y1 + 2, "H")


def wreath(c, y, x0=7, x1=16, row=3):
    for i, x in enumerate(range(x0, x1 + 1)):
        c.put(x, y + row, "l" if i % 3 == 1 else ("A" if i % 3 == 0 else "a"))


# goblin pieces
def mohawk(view, c, y):
    if view == "front":
        c.rect(10, y - 1, 13, y + 4, "H"); c.cells([(11, y - 2), (13, y - 2), (10, y - 2)], "H")
        c.rect(13, y, 13, y + 4, "J"); c.cells([(10, y), (10, y + 1), (11, y - 1)], "h")
        c.rect(10, y + 5, 13, y + 5, "H")
    elif view == "side":
        for x, top in ((6, 4), (7, 2), (8, 0), (9, -1), (10, -1), (11, -2), (12, -1), (13, 0), (14, 1), (15, 2), (16, 4)):
            c.rect(x, y + top, x, y + top + 2, "H")
        c.cells([(9, y - 1), (11, y - 2), (8, y)], "h"); c.rect(6, y + 5, 7, y + 9, "H")
    else:
        c.rect(10, y - 1, 13, y + 10, "H"); c.cells([(11, y - 2), (13, y - 2)], "H"); c.rect(13, y, 13, y + 10, "J")
        c.cells([(10, y), (10, y + 2)], "h")


def topknot(view, c, y):
    if view == "side":
        c.rect(8, y + 2, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 4, "H"); c.rect(6, y + 5, 10, y + 8, "H")
        c.cells([(15, y + 5), (16, y + 5)], "H")
        c.rect(9, y - 1, 12, y + 1, "H"); c.rect(10, y - 3, 11, y - 2, "H"); c.put(10, y - 4, "H")
        c.rect(9, y + 1, 12, y + 1, "A"); c.cells([(9, y - 1), (10, y - 3)], "h")
        return
    if view == "back":
        back_cap(c, y, 11)
    else:
        c.rect(8, y + 2, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 4, "H")
        c.cells([(7, y + 5), (8, y + 5), (15, y + 5), (16, y + 5), (11, y + 5), (12, y + 5)], "H")
    c.rect(10, y - 1, 13, y + 1, "H"); c.rect(11, y - 3, 12, y - 2, "H"); c.put(12, y - 4, "H")
    c.rect(10, y + 1, 13, y + 1, "A")
    c.cells([(10, y - 1), (11, y - 3), (9, y + 3)], "h"); c.rect(13, y - 1, 13, y, "J")


def rings(view, c, y):
    if view == "front":
        c.cells([(4, y + 11), (19, y + 11), (3, y + 11), (20, y + 11), (2, y + 8), (21, y + 8)], "A")
    elif view == "side":
        c.cells([(6, y + 11), (5, y + 11), (4, y + 8)], "A")
    else:
        c.cells([(4, y + 11), (19, y + 11), (3, y + 11), (20, y + 11)], "A")


def bun_top(view, c, y):
    if view == "side":
        c.rect(8, y - 1, 11, y + 1, "H"); c.rect(9, y - 2, 10, y - 2, "H"); c.cells([(8, y - 1), (9, y - 2)], "h")
        c.rect(8, y + 2, 11, y + 2, "A")
        return
    c.rect(10, y - 1, 13, y + 1, "H"); c.rect(11, y - 2, 12, y - 2, "H")
    c.cells([(10, y - 1), (11, y - 2)], "h"); c.rect(13, y, 13, y + 1, "J")
    c.rect(10, y + 2, 13, y + 2, "A")


def dread_locks(view, c, y, front_locks=True):
    if view == "front":
        for x in (4, 6, 17, 19):
            for yy in range(y + 8, y + 19):
                c.put(x, yy, "H" if (yy + x) % 3 else "J")
            c.put(x, y + 19, "A")
        c.rect(5, y + 8, 5, y + 15, "J"); c.rect(18, y + 8, 18, y + 15, "J")
    elif view == "side":
        for x in (4, 6, 8):
            for yy in range(y + 8, y + 19):
                c.put(x, yy, "H" if (yy + x) % 3 else "J")
            c.put(x, y + 19, "A")
        c.rect(5, y + 8, 5, y + 15, "J"); c.rect(7, y + 8, 7, y + 16, "H")
    else:
        for x in range(5, 19, 2):
            for yy in range(y + 10, y + 19):
                c.put(x, yy, "H" if (yy + x) % 3 else "J")
            c.put(x, y + 19, "A")
            c.rect(x + 1, y + 10, x + 1, y + 14, "J")


def dread_front_locks(c, y):
    for x in (7, 16):
        for yy in range(y + 6, y + 11):
            c.put(x, yy, "H" if yy % 2 else "J")
        c.put(x, y + 11, "A")


def mane(view, layer, c, y):
    if view == "front":
        if layer == "back":
            for yy in range(y + 2, y + 17):
                w = 8 if yy < y + 14 else 7 - (yy - y - 14)
                x0, x1 = 12 - w - 1, 11 + w + 1
                c.rect(max(2, x0 - (1 if yy % 3 == 0 else 0)), yy, min(21, x1 + (1 if yy % 3 == 1 else 0)), yy, "H")
            for x in range(4, 20, 3):
                c.put(x, y + 16 + (x % 2), "J")
        else:
            c.rect(7, y + 2, 16, y + 2, "H"); c.rect(5, y + 3, 18, y + 5, "H")
            c.cells([(6, y + 1), (8, y + 0), (8, y + 1), (11, y + 1), (12, y + 0), (15, y + 1), (15, y + 0), (17, y + 1)], "H")
            c.cells([(5, y + 6), (6, y + 6), (8, y + 6), (9, y + 7), (14, y + 6), (15, y + 7), (17, y + 6), (18, y + 6),
                     (5, y + 7), (18, y + 7), (11, y + 6)], "H")
            c.cells([(8, y + 3), (9, y + 2), (12, y + 1), (7, y + 4)], "h"); c.cells([(13, y + 4), (16, y + 5)], "J")
    elif view == "side":
        if layer == "back":
            for yy in range(y + 2, y + 17):
                x0 = 2 + (1 if yy % 3 == 0 else 0) + max(0, yy - y - 13)
                c.rect(x0, yy, 10, yy, "H")
            for yy in range(y + 4, y + 16, 3):
                c.put(3, yy, "J")
        else:
            side_cap(c, y, 11)
            c.cells([(7, y + 1), (9, y + 0), (9, y + 1), (12, y + 1), (12, y + 0), (15, y + 1), (17, y + 4), (18, y + 5)], "H")
    else:
        if layer == "front":
            back_cap(c, y, 14)
            for yy in range(y + 2, y + 18):
                w = 8 if yy < y + 15 else 7 - (yy - y - 15)
                c.rect(max(3, 4 - (1 if yy % 3 == 0 else 0)), yy, min(20, 19 + (1 if yy % 3 == 1 else 0)), yy, "H") \
                    if yy > y + 3 else None
            c.cells([(6, y + 1), (8, y + 0), (11, y + 1), (12, y + 0), (15, y + 1), (17, y + 1)], "H")
            for x in range(5, 19, 3):
                c.put(x, y + 17, "J")


def spikes(view, c, y):
    if view == "side":
        side_cap(c, y, 8)
        for x, top in ((7, 1), (9, 0), (11, -1), (13, 0), (15, 1), (6, 3)):
            c.rect(x, y + top, x, y + 2, "H"); c.put(x + 1, y + top + 1, "H")
        return
    if view == "back":
        back_cap(c, y, 11)
    else:
        c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 4, "H")
        c.cells([(7, y + 5), (9, y + 5), (10, y + 6), (12, y + 5), (13, y + 6), (15, y + 5), (16, y + 5), (16, y + 6)], "H")
        c.cells([(8, y + 3), (9, y + 3)], "h"); c.cells([(12, y + 4), (13, y + 4)], "J")
    for x, top in ((7, 1), (9, -1), (11, 0), (12, -2), (14, 0), (16, 1)):
        c.rect(x, y + top, x, y + 2, "H")
    c.cells([(9, y - 1), (12, y - 2)], "h")


def loose_tails(view, c, y):
    """Two loose pigtails (not braided), tied high with ribbons."""
    if view == "front":
        for side in (-1, 1):
            f = (lambda x: x) if side < 0 else (lambda x: 23 - x)
            for yy, (a0, a1) in zip(range(y + 7, y + 18), [(4, 5), (3, 5), (3, 5), (2, 5), (2, 5), (2, 5), (2, 4), (2, 4), (3, 4),
                                                           (3, 4), (3, 3)]):
                c.rect(min(f(a0), f(a1)), yy, max(f(a0), f(a1)), yy, "H")
            c.cells([(f(3), y + 10), (f(3), y + 13)], "J"); c.put(f(4), y + 9, "h")
            c.cells([(f(5), y + 6), (f(5), y + 7)], "A")
    elif view == "side":
        for yy, (a0, a1) in zip(range(y + 6, y + 17), [(5, 7), (4, 7), (3, 6), (3, 6), (2, 5), (2, 5), (2, 5), (2, 4), (3, 4),
                                                       (3, 4), (3, 3)]):
            c.rect(a0, yy, a1, yy, "H")
        c.cells([(7, y + 5), (8, y + 5)], "A"); c.put(3, y + 10, "J")
    else:
        for side in (-1, 1):
            f = (lambda x: x) if side < 0 else (lambda x: 23 - x)
            for yy, (a0, a1) in zip(range(y + 7, y + 18), [(4, 6), (3, 6), (3, 5), (2, 5), (2, 5), (2, 5), (2, 4), (2, 4), (3, 4),
                                                           (3, 4), (3, 3)]):
                c.rect(min(f(a0), f(a1)), yy, max(f(a0), f(a1)), yy, "H")
            c.cells([(f(5), y + 6), (f(6), y + 6), (f(6), y + 7)], "A")


def bob(view, layer, c, y):
    if view == "front":
        if layer == "front":
            bangs_front(c, y)
            c.rect(5, y + 6, 6, y + 12, "H"); c.rect(17, y + 6, 18, y + 12, "H")
            c.cells([(5, y + 12), (18, y + 12)], "J"); c.cells([(7, y + 8), (16, y + 8)], "H")
    elif view == "side":
        if layer == "front":
            side_cap(c, y, 12)
            c.rect(5, y + 6, 5, y + 12, "H"); c.rect(5, y + 12, 11, y + 12, "J")
    else:
        if layer == "front":
            back_cap(c, y, 13)
            c.rect(5, y + 6, 5, y + 13, "H"); c.rect(18, y + 6, 18, y + 13, "H"); c.rect(5, y + 13, 18, y + 13, "J")


def ponytail(view, layer, c, y, cowlick=False):
    if view == "front":
        if layer == "back":
            c.rect(11, y - 1, 14, y + 1, "H"); c.rect(11, y + 1, 14, y + 1, "k")
            c.cells([(15, y - 1), (16, y - 1), (16, y), (17, y), (18, y + 1), (18, y + 2)], "H")
            c.rect(18, y + 3, 20, y + 13, "H"); c.rect(19, y + 14, 20, y + 15, "H"); c.put(20, y + 16, "J")
            c.rect(20, y + 4, 20, y + 13, "J"); c.cells([(18, y + 5), (18, y + 9)], "h")
        else:
            short_front(c, y, cowlick)
    elif view == "side":
        if layer == "back":
            c.cells([(5, y + 3), (4, y + 4), (3, y + 5)], "H"); c.rect(2, y + 6, 4, y + 15, "H"); c.rect(3, y + 16, 4, y + 17, "H")
            c.rect(2, y + 7, 2, y + 15, "J")
        else:
            side_cap(c, y, 9, cowlick)
            c.rect(5, y + 3, 6, y + 4, "k")
    else:
        if layer == "front":
            back_cap(c, y, 11)
            c.rect(10, y + 4, 13, y + 5, "k")
            c.rect(10, y + 6, 13, y + 17, "H"); c.rect(11, y + 18, 12, y + 19, "H"); c.rect(13, y + 6, 13, y + 17, "J")
            c.cells([(10, y + 8), (10, y + 12)], "h")


def halfup(view, layer, c, y, cowlick=False):
    if view == "front":
        if layer == "back":
            sides(c, y, 9, 16)
            c.rect(10, y - 1, 13, y + 1, "H"); c.rect(10, y + 1, 13, y + 1, "k"); c.put(10, y - 1, "h")
        else:
            short_front(c, y, cowlick)
    elif view == "side":
        if layer == "back":
            behind_side(c, y, 16)
        else:
            side_cap(c, y, 10, cowlick)
            c.rect(5, y + 2, 7, y + 4, "H"); c.rect(5, y + 4, 7, y + 4, "k")
    else:
        if layer == "front":
            back_cap(c, y, 14); down_back(c, y, 16)
            c.rect(10, y + 3, 13, y + 5, "H"); c.rect(10, y + 6, 13, y + 6, "k"); c.put(10, y + 3, "h")


def long_style(view, layer, c, y, bottom=18, wavy=False, front=long_front, accent=None, crown=False):
    if view == "front":
        if layer == "back":
            if wavy:
                sides(c, y, 9, bottom, (3, 6), (17, 20))
                for yy in range(y + 10, y + bottom, 4):
                    c.cells([(2, yy), (21, yy + 2)], "H"); c.cells([(5, yy + 1), (18, yy + 3)], "h")
            else:
                sides(c, y, 9, bottom)
        else:
            front(c, y)
            if crown:
                wreath(c, y); c.cells([(6, y + 4), (17, y + 4)], "l")
            if accent:
                c.cells([(16, y + 2), (17, y + 3), (16, y + 3)], accent)
    elif view == "side":
        if layer == "back":
            behind_side(c, y, bottom, wavy)
        else:
            side_cap(c, y, 10)
            if crown:
                wreath(c, y, 8, 16)
            if accent:
                c.cells([(15, y + 3), (16, y + 3), (16, y + 2)], accent)
    else:
        if layer == "front":
            back_cap(c, y, 14); down_back(c, y, bottom, wavy)
            if crown:
                wreath(c, y, 6, 17, 4)
            if accent:
                c.cells([(6, y + 3), (7, y + 3), (6, y + 2)], accent)


def side_braid(view, layer, c, y):
    if view == "front":
        if layer == "back":
            c.rect(17, y + 8, 19, y + 13, "H"); c.rect(17, y + 13, 19, y + 13, "J")
        else:
            long_front(c, y); braid(c, 5, 7, y + 9, y + 20)
    elif view == "side":
        if layer == "back":
            braid(c, 8, 9, y + 10, y + 19)
        else:
            side_cap(c, y, 11)
    else:
        if layer == "back":
            braid(c, 16, 18, y + 9, y + 20)
        else:
            back_cap(c, y, 14)
            c.rect(6, y + 12, 8, y + 14, "H")


def braided_crown(view, layer, c, y):
    if view == "front":
        if layer == "back":
            c.rect(5, y + 7, 6, y + 11, "H"); c.rect(17, y + 7, 18, y + 11, "H")
        else:
            long_front(c, y)
            c.clear([(6, y + 8), (6, y + 9), (17, y + 8), (17, y + 9)])
            for i, x in enumerate(range(6, 18)):
                c.put(x, y + 3, "H" if i % 2 else "J"); c.put(x, y + 4, "J" if i % 2 else "h")
            c.cells([(5, y + 4), (18, y + 4)], "J"); c.cells([(8, y + 2), (15, y + 2)], "a")
    elif view == "side":
        if layer == "front":
            side_cap(c, y, 11)
            for i, x in enumerate(range(6, 17)):
                c.put(x, y + 3, "H" if i % 2 else "J"); c.put(x, y + 4, "J" if i % 2 else "h")
            c.put(15, y + 2, "a")
    else:
        if layer == "front":
            back_cap(c, y, 12)
            for i, x in enumerate(range(6, 18)):
                c.put(x, y + 4, "H" if i % 2 else "J"); c.put(x, y + 5, "J" if i % 2 else "h")


def messy(view, c, y):
    if view == "front":
        short_front(c, y, False)
        c.cells([(5, y + 4), (5, y + 6), (18, y + 5), (18, y + 7), (9, y + 1), (12, y + 1), (13, y + 0), (8, y + 1),
                 (15, y + 1), (16, y + 2), (14, y + 7), (9, y + 7)], "H")
        c.cells([(13, y + 0), (9, y + 1)], "h")
    elif view == "side":
        side_cap(c, y, 10)
        c.cells([(5, y + 5), (5, y + 8), (4, y + 7), (9, y + 1), (12, y + 1), (12, y + 0), (15, y + 1), (18, y + 6)], "H")
    else:
        back_cap(c, y, 12)
        c.cells([(5, y + 5), (5, y + 9), (18, y + 6), (18, y + 10), (9, y + 1), (12, y + 1), (13, y + 0), (8, y + 13),
                 (11, y + 13), (15, y + 13)], "H")


def updo(view, layer, c, y):
    """A wreath over an updo: the bun sits at the back of the head."""
    if view == "front":
        if layer == "back":
            c.rect(9, y - 1, 14, y + 2, "H"); c.rect(10, y - 2, 13, y - 2, "H"); c.cells([(10, y - 1), (9, y)], "h")
        else:
            long_front(c, y); c.clear([(6, y + 8), (6, y + 9), (17, y + 8), (17, y + 9)])
            wreath(c, y); c.cells([(6, y + 4), (17, y + 4)], "l")
    elif view == "side":
        if layer == "front":
            side_cap(c, y, 10); wreath(c, y, 8, 16)
            c.rect(4, y + 2, 7, y + 6, "H"); c.rect(5, y + 1, 6, y + 1, "H"); c.cells([(5, y + 2), (4, y + 3)], "h")
    else:
        if layer == "front":
            back_cap(c, y, 12)
            c.rect(9, y + 3, 14, y + 8, "H"); c.rect(10, y + 2, 13, y + 9, "H"); c.cells([(10, y + 3), (9, y + 4)], "h")
            c.rect(9, y + 8, 14, y + 8, "J"); wreath(c, y, 6, 17, 4)


# bone pieces
def hood(view, c, y, ragged=False):
    t = pv.C(RW, FH)
    if view == "back":
        pv.hair_back(t, fake("hood"), y)
    else:
        pv.hood(t, y, view)
    for yy in range(FH):
        for x in range(RW):
            k = t.px[yy][x]
            if k in ("C", "c", "v", "A") or (view == "front" and k == "S" and x == 16 and yy != y + 11):
                c.put(x, yy, k)
            elif k == "s" and view == "side" and (x, yy) not in HEAD_SIDE(y) and yy != y + 13:
                c.put(x, yy, k)
    if ragged:                                                           # torn edges, a patch
        for x in range(5, 19, 3):
            c.put(x, y + 15 if view != "side" else y + 14, None)
        c.clear([(5, y + 12), (18, y + 10), (5, y + 8)])
        c.cells([(7, y + 2), (8, y + 2), (7, y + 3)], "w") if view != "side" else c.cells([(8, y + 2), (9, y + 2)], "w")
        c.cells([(6, y + 9), (6, y + 10)], "c") if view != "front" else None


def HEAD_SIDE(y):
    t = C()
    head_shape(t, y, "round")
    t.rect(17, y + 6, 17, y + 12, "s")
    return {(x, yy) for yy in range(FH) for x in range(RW) if t.px[yy][x] is not None}


def crack(view, c, y):
    if view == "front":
        c.cells([(13, y + 3), (13, y + 4), (14, y + 5), (14, y + 6), (15, y + 7), (12, y + 5)], "d")
    elif view == "side":
        c.cells([(10, y + 3), (10, y + 4), (11, y + 5), (11, y + 6), (12, y + 7)], "d")
    else:
        c.cells([(10, y + 3), (10, y + 4), (9, y + 5), (9, y + 6), (8, y + 7), (11, y + 5)], "d")


def horns(view, c, y, long=False):
    pts = [(8, 2), (9, 2), (7, 1), (8, 1), (6, 0), (7, 0), (6, -1)]
    dark = [(9, 2), (8, 1), (7, 0)]
    if long:
        pts = [(8, 2), (9, 2), (7, 1), (8, 1), (6, 0), (7, 0), (5, -1), (6, -1), (5, -2), (4, -3), (5, -3), (4, -4), (5, -5)]
        dark = [(9, 2), (8, 1), (7, 0), (6, -1), (5, -2)]
    sides_ = (-1, 1) if view in ("front", "back") else (-1,)
    for side in sides_:
        if view == "side":
            f = lambda x: x + 3  # noqa: E731
        else:
            f = (lambda x: x) if side < 0 else (lambda x: 23 - x)
        c.cells([(f(x), y + yy) for x, yy in pts], "N")
        c.cells([(f(x), y + yy) for x, yy in dark], "n")


def bone_crown(view, c, y):
    x0, x1 = (7, 16) if view != "side" else (7, 15)
    c.rect(x0, y + 3, x1, y + 3, "N"); c.rect(x0, y + 4, x1, y + 4, "n")
    for x in range(x0, x1 + 1, 3):
        c.rect(x, y + 1, x, y + 2, "N"); c.put(x, y + 0, "W")
    c.cells([(x0 + 4, y + 3), (x0 + 5, y + 3)], "f") if view == "front" else None


def candle(view, c, y):
    cx = 11 if view != "side" else 10
    c.rect(cx - 2, y + 2, cx + 3, y + 2, "n")                             # a little dish of wax
    c.rect(cx, y - 2, cx + 1, y + 1, "W"); c.put(cx + 1, y - 1, "w"); c.put(cx, y + 1, "w")
    c.put(cx - 1, y + 1, "W"); c.put(cx + 2, y + 0, "W")                  # drips
    c.put(cx, y - 3, "b"); c.cells([(cx, y - 5), (cx, y - 4), (cx + 1, y - 4)], "F"); c.put(cx, y - 6, "R")


# spirit pieces
def flame_hair(view, layer, c, y, crown_only=False):
    tongues = ((7, 0), (9, -2), (11, -1), (12, -3), (14, -1), (16, 0))
    if view == "front":
        if layer == "back":
            c.rect(5, y + 7, 6, y + 12, "H"); c.rect(17, y + 7, 18, y + 12, "H"); c.cells([(5, y + 13), (18, y + 13)], "Z")
        else:
            c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + 5, "H")
            c.cells([(6, y + 6), (7, y + 6), (10, y + 6), (13, y + 6), (16, y + 6), (17, y + 6), (6, y + 7), (17, y + 7)], "H")
            for x, top in tongues:
                c.rect(x, y + top, x, y + 2, "H"); c.put(x, y + top, "Z")
            c.cells([(10, y + 1), (13, y + 1), (8, y + 1), (15, y + 1)], "H")
            c.cells([(9, y + 1), (12, y - 1), (11, y + 2), (12, y + 2)], "h"); c.cells([(8, y + 4), (9, y + 3)], "h")
    elif view == "side":
        if layer == "front":
            side_cap(c, y, 9)
            for x, top in ((7, 1), (9, -1), (11, -2), (13, -1), (15, 0)):
                c.rect(x, y + top, x, y + 2, "H"); c.put(x, y + top, "Z")
            c.rect(5, y + 7, 6, y + 12, "H"); c.put(5, y + 13, "Z")
    else:
        if layer == "front":
            back_cap(c, y, 12)
            for x, top in tongues:
                c.rect(x, y + top, x, y + 2, "H"); c.put(x, y + top, "Z")
            c.rect(5, y + 7, 6, y + 12, "H"); c.rect(17, y + 7, 18, y + 12, "H"); c.cells([(5, y + 13), (18, y + 13)], "Z")


def misty(c, y, x_ranges, top, bottom):
    for yy in range(y + top, y + bottom + 1):
        for x in x_ranges:
            if (x + yy) % 2 == 0:
                c.put(x, yy, "Z" if yy < y + bottom else None)
            elif yy >= y + bottom:
                c.put(x, yy, None)


def mist(view, layer, c, y):
    if view == "front":
        if layer == "back":
            sides(c, y, 8, 21); misty(c, y, list(range(3, 7)) + list(range(17, 21)), 17, 22)
        else:
            long_front(c, y)
    elif view == "side":
        if layer == "back":
            behind_side(c, y, 21); misty(c, y, range(4, 10), 17, 22)
        else:
            side_cap(c, y, 10)
    else:
        if layer == "front":
            back_cap(c, y, 14); down_back(c, y, 21); misty(c, y, range(6, 18), 17, 22)


def wisp_tail(c, y, side, x_shift=0):
    pts = [(5, 6), (4, 7), (4, 8), (3, 9), (3, 10), (3, 11), (2, 12), (2, 13), (3, 14)]
    f = (lambda x: x + x_shift) if side < 0 else (lambda x: 23 - x)
    for x, yy in pts:
        c.put(f(x), y + yy, "H"); c.put(f(x) + (1 if side < 0 else -1), y + yy, "H")
    tip = [(1, 15), (2, 15), (3, 15), (4, 15), (2, 16), (3, 16), (2, 17), (3, 14), (1, 14)]
    c.cells([(f(x), y + yy) for x, yy in tip], "f")
    c.put(f(3), y + 16, "Z"); c.put(f(5), y + 5, "f")


def wisps(view, layer, c, y, both=True):
    if view == "front":
        if layer == "back":
            if both:
                wisp_tail(c, y, -1)
            wisp_tail(c, y, 1)
        else:
            long_front(c, y)
    elif view == "side":
        if layer == "back":
            wisp_tail(c, y, -1, 2)
        else:
            side_cap(c, y, 10)
    else:
        if layer == "front":
            back_cap(c, y, 13)
            if both:
                wisp_tail(c, y, 1)
            wisp_tail(c, y, -1)


def glass(view, layer, c, y):
    """Glass-short: a short, see-through-looking crop (glints in a checker)."""
    if layer != "front":
        return
    if view == "front":
        long_front(c, y); c.clear([(6, y + 8), (6, y + 9), (17, y + 8), (17, y + 9)])
        c.rect(5, y + 6, 5, y + 10, "H"); c.rect(18, y + 6, 18, y + 10, "H")
    elif view == "side":
        side_cap(c, y, 10)
    else:
        back_cap(c, y, 12)
    for yy in range(FH):
        for x in range(RW):
            if c.px[yy][x] == "H" and (x + yy) % 3 == 0:
                c.px[yy][x] = "h"


def flame_crown(view, layer, c, y):
    long_style(view, layer, c, y, 18)
    if layer == "front":
        xs = (8, 10, 13, 15) if view != "side" else (8, 10, 12, 14)
        for i, x in enumerate(xs):
            top = -1 if i in (1, 2) else 0
            c.rect(x, y + top, x, y + 2, "f"); c.put(x, y + top - 1, "Z")
        c.rect(xs[0], y + 2, xs[-1], y + 2, "f")


def pv_style(name):
    """The approved default styles: exactly the preview's art in every view."""
    def draw(view, layer, c, y):
        a = fake(name)
        t = pv.C(RW, FH)
        if view == "front":
            if layer == "back":
                pv.hair_behind(t, a, "front", y)
            else:
                pv.hair_front(t, a, y)
                if name == "pigtails":
                    t.cells([(11, y + 5), (12, y + 5)], "D")
        elif view == "side":
            if layer == "back":
                pv.hair_behind(t, a, "side", y)
            else:
                pv.hair_side(t, a, y)
        else:
            if layer == "front":
                pv.hair_back(t, a, y)
        for yy in range(FH):
            for x in range(RW):
                k = t.px[yy][x]
                if k is not None and k not in ("s",):
                    c.put(x, yy, k)
        if name == "short" and view == "back" and layer == "front":
            c.rect(6, y + 12, 17, y + 14, None)
            c.put(17, y + 12, "s")
        if name == "short" and view == "side" and layer == "front":
            c.rect(9, y + 10, 11, y + 10, "D")
        if name == "wavy" and view == "back" and layer == "front":
            c.cells([(9, y + 19), (12, y + 19), (15, y + 19)], "D")
    return draw


def simple(fn):
    """A style drawn only in the front layer (front/side/back views)."""
    return lambda view, layer, c, y: fn(view, c, y) if layer == "front" else None


def gob_front_cap(view, c, y):
    if view == "front":
        bangs_front(c, y)
    elif view == "side":
        side_cap(c, y, 9)
    else:
        back_cap(c, y, 12)


def combine(*parts):
    def draw(view, layer, c, y):
        for p in parts:
            p(view, layer, c, y)
    return draw


def front_only(fn, layer_name="front"):
    return lambda view, layer, c, y: fn(view, c, y) if layer == layer_name else None


def tuft_m(view, layer, c, y):
    pv_style("tuft")(view, layer, c, y)
    if layer == "front":
        if view in ("front", "back"):
            c.put(4, y + 11, "A")


STYLE = {
    # goblins (men and women share a head)
    ("goblin", "tuft"): tuft_m,
    ("goblin", "tuft_f"): pv_style("tuft"),
    ("goblin", "mohawk"): simple(mohawk),
    ("goblin", "topknot"): simple(topknot),
    ("goblin", "bald_ring"): simple(rings),
    ("goblin", "dreads"): combine(lambda v, l, c, y: dread_locks(v, c, y) if (l == "back") == (v != "back") else None,
                                  front_only(gob_front_cap),
                                  lambda v, l, c, y: dread_front_locks(c, y) if (v == "front" and l == "front") else None),
    ("goblin", "wild"): lambda v, l, c, y: mane(v, l, c, y),
    ("goblin", "bun"): combine(front_only(gob_front_cap), front_only(bun_top)),
    ("goblin", "spikes"): simple(spikes),
    ("goblin", "braids"): pv_style("pigtails"),
    ("goblin", "pigtails"): combine(lambda v, l, c, y: loose_tails(v, c, y) if (l == "back") == (v != "back") else None,
                                    front_only(gob_front_cap)),
    ("goblin", "bob"): bob,
    # elves
    ("elf", "neat"): pv_style("short"),
    ("elf", "long"): lambda v, l, c, y: long_style(v, l, c, y, 18),
    ("elf", "halfup"): halfup,
    ("elf", "ponytail"): ponytail,
    ("elf", "side_braid"): side_braid,
    ("elf", "waves"): lambda v, l, c, y: long_style(v, l, c, y, 22, wavy=True, accent="k"),
    ("elf", "messy"): simple(messy),
    ("elf", "braided_crown"): braided_crown,
    ("elf", "long_wreath"): pv_style("long"),
    ("elf", "wreath_updo"): updo,
    # undead men: what is on the skull
    ("bone", "hood"): simple(hood),
    ("bone", "bare"): lambda v, l, c, y: None,
    ("bone", "crack"): simple(crack),
    ("bone", "horns"): simple(horns),
    ("bone", "long_horns"): simple(lambda v, c, y: horns(v, c, y, True)),
    ("bone", "ragged_hood"): simple(lambda v, c, y: hood(v, c, y, True)),
    ("bone", "bone_crown"): simple(bone_crown),
    ("bone", "candle"): simple(candle),
    # spirits
    ("spirit", "drift"): pv_style("wavy"),
    ("spirit", "flame"): flame_hair,
    ("spirit", "mist"): mist,
    ("spirit", "wisp_twins"): wisps,
    ("spirit", "glass_short"): glass,
    ("spirit", "long_wave"): lambda v, l, c, y: long_style(v, l, c, y, 22, wavy=True, accent="f"),
    ("spirit", "side_wisp"): lambda v, l, c, y: wisps(v, l, c, y, both=False),
    ("spirit", "flame_crown"): flame_crown,
}
HAIR_GROUP = {"goblin_m": "goblin", "goblin_f": "goblin", "elf_m": "elf", "elf_f": "elf", "undead_m": "bone", "undead_f": "spirit"}


def style_fn(bk, hair):
    g = HAIR_GROUP[bk]
    if g == "goblin" and hair == "tuft" and bk == "goblin_f":
        return STYLE[(g, "tuft_f")]
    return STYLE[(g, hair)]


def ear_mask(bk, fr):
    """Where the body's ear is in a side frame (side hair leaves it showing, like the approved art)."""
    a = AVB[BODIES[bk]]
    t = C()
    _oy, _u, hy = heads(fr)
    pv.ears(t, {"ears": a["ears"]}, "side", hy)
    return {(x, y) for y in range(FH) for x in range(RW) if t.px[y][x] is not None}


def hair_layers(bk, hair, fr):
    fn = style_fn(bk, hair)
    view = fr["view"]
    _oy, _u, hy = heads(fr)
    back, front = C(), C()
    fn(view, "back", back, hy)
    fn(view, "front", front, hy)
    if view == "side":
        for (x, y) in ear_mask(bk, fr):
            if front.px[y][x] in ("H", "J", "h"):
                front.px[y][x] = None
    flat_f, flat_b = C(), C()
    for y in range(FH):
        for x in range(RW):
            if y >= hy + 6:
                flat_f.px[y][x] = front.px[y][x]
            if y >= hy + 5:
                flat_b.px[y][x] = back.px[y][x]
    return back, front, flat_f, flat_b


# --- faces ------------------------------------------------------------------------------------------------------------------
def eyes_layer(bt, style, fr):
    c = C()
    view = fr["view"]
    if view == "back":
        return c
    _oy, _u, y = heads(fr)
    state = fr["eye"]
    if bt == "skeleton":
        cols = (8, 14) if view == "front" else (14,)
        for x0 in cols:
            left = view == "front" and x0 == 8
            gx = x0 + 1 if left else (x0 if view == "front" else x0 + 1)
            if state == "happy":
                o = x0 - 1 if left else x0 + 2
                i = x0 + 2 if left else x0 - 1
                c.cells([(x0, y + 9), (x0 + 1, y + 9), (o, y + 10), (i, y + 10)], "d")
                continue
            shape = {"round": [(0, 8), (1, 8), (0, 9), (1, 9), (0, 10), (1, 10)], "lashes": None,
                     "narrow": [(0, 9), (1, 9), (0, 10), (1, 10)], "sleepy": [(0, 9), (1, 9), (0, 10), (1, 10)],
                     "sparkle": [(0, 8), (1, 8), (0, 9), (1, 9), (0, 10), (1, 10)], "dot": [(1 if left else 0, 9), (1 if left else 0, 10)],
                     "sharp": [(1 if left else 0, 8), (0, 9), (1, 9), (0, 10), (1, 10)],
                     "wide": [(0, 8), (1, 8), (0, 9), (1, 9), (0, 10), (1, 10), (-1 if left else 2, 9), (-1 if left else 2, 10)]}
            pts = shape.get(style) or shape["round"]
            c.cells([(x0 + dx, y + dy) for dx, dy in pts], "d")
            if style == "sleepy":
                c.rect(x0, y + 8, x0 + 1, y + 8, "S")
            if state == "open":
                gy = y + 9 if style not in ("narrow", "sleepy") else y + 10
                if style == "dot":
                    c.put(x0 + (1 if left else 0), y + 9, "e")
                else:
                    c.put(gx, gy, "e")
                    if style == "sparkle":
                        c.put(gx, gy + 1, "e")
        return c
    girl_flick = style == "lashes"
    cols = [(8, True), (14, False)] if view == "front" else [(14, False)]
    for x0, left in cols:
        out = x0 - 1 if left else x0 + 2
        inn = x0 + 2 if left else x0 - 1
        glint_x = x0 if view == "front" else x0 + 1
        if state == "closed":
            c.rect(x0, y + 10, x0 + 1, y + 10, "L")
            if style in ("lashes", "sharp"):
                c.put(out, y + 10, "L")
            continue
        if state == "happy":
            c.cells([(x0, y + 9), (x0 + 1, y + 9), (out, y + 10), (inn, y + 10)], "L")
            continue
        if style in ("round", "lashes"):
            c.rect(x0, y + 8, x0 + 1, y + 8, "L")
            c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I"); c.put(glint_x, y + 9, "w")
            if girl_flick:
                c.put(out, y + 8, "L")
        elif style == "narrow":
            c.rect(x0, y + 9, x0 + 1, y + 9, "L"); c.put(out, y + 9, "L")
            c.rect(x0, y + 10, x0 + 1, y + 10, "i"); c.put(x0 + (1 if left else 0), y + 10, "I")
        elif style == "sparkle":
            c.rect(x0, y + 8, x0 + 1, y + 8, "L"); c.put(out, y + 8, "L")
            c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I")
            c.put(glint_x, y + 9, "w"); c.put(x0 + 1 if glint_x == x0 else x0, y + 10, "w")
        elif style == "dot":
            dx = x0 + 1 if left else x0
            c.rect(dx, y + 9, dx, y + 10, "L")
        elif style == "sleepy":
            c.rect(x0, y + 8, x0 + 1, y + 8, "S")                          # a heavy lid
            c.rect(x0, y + 9, x0 + 1, y + 9, "L")
            c.rect(x0, y + 10, x0 + 1, y + 10, "i"); c.put(x0 + (1 if left else 0), y + 10, "I")
        elif style == "sharp":
            c.cells([(out, y + 8), (x0 if left else x0 + 1, y + 8), (x0 + 1 if left else x0, y + 9)], "L")
            c.put(x0 if left else x0 + 1, y + 9, "i")
            c.rect(x0, y + 10, x0 + 1, y + 10, "I")
        elif style == "wide":
            c.rect(x0, y + 8, x0 + 1, y + 8, "L")
            c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.put(glint_x, y + 9, "w")
            c.cells([(out, y + 9), (out, y + 10)], "w")
    return c


def brows_layer(bt, style, fr):
    c = C()
    if fr["view"] == "back" or bt == "skeleton" or style == "none":
        return c
    _oy, _u, y = heads(fr)
    dy = -1 if fr["eye"] == "happy" else 0
    if fr["view"] == "front":
        if style == "faint":
            c.cells([(8, y + 7 + dy), (9, y + 7 + dy), (14, y + 7 + dy), (15, y + 7 + dy)], "S")
        elif style == "thin":
            c.cells([(8, y + 7 + dy), (9, y + 6 + dy), (14, y + 6 + dy), (15, y + 7 + dy)], "J")
        elif style == "thick":
            c.rect(7, y + 7 + dy, 9, y + 7 + dy, "J"); c.rect(14, y + 7 + dy, 16, y + 7 + dy, "J")
            c.cells([(9, y + 6 + dy), (14, y + 6 + dy)], "J")
    else:
        if style == "faint":
            c.cells([(14, y + 7 + dy), (15, y + 7 + dy)], "S")
        elif style == "thin":
            c.cells([(14, y + 6 + dy), (15, y + 7 + dy)], "J")
        elif style == "thick":
            c.rect(13, y + 7 + dy, 16, y + 7 + dy, "J"); c.put(14, y + 6 + dy, "J")
    return c


def mouth_layer(bt, style, fr):
    c = C()
    view = fr["view"]
    if view == "back":
        return c
    _oy, _u, y = heads(fr)
    state = fr["mouth"]
    if bt == "skeleton":
        if view == "front":
            if style == "jaw" or state == "open":
                c.rect(10, y + 12, 13, y + 12, "d") if state == "open" else None
            if style == "grin":
                c.rect(8, y + 13, 15, y + 13, "S"); c.cells([(9, y + 13), (11, y + 13), (13, y + 13)], "s")
                c.cells([(8, y + 12), (15, y + 12)], "S")
            elif style == "jaw":
                c.rect(10, y + 13, 13, y + 13, "d"); c.rect(9, y + 14, 14, y + 14, "S"); c.cells([(10, y + 14), (12, y + 14)], "s")
            elif style == "stitch":
                c.rect(9, y + 13, 14, y + 13, "d"); c.cells([(10, y + 12), (10, y + 14), (13, y + 12), (13, y + 14)], "S")
            else:
                c.rect(9, y + 13, 14, y + 13, "S"); c.cells([(10, y + 13), (12, y + 13)], "s")
                if style == "gap":
                    c.put(11, y + 13, "d")
                if style == "fang":
                    c.cells([(10, y + 14), (13, y + 14)], "s")
            if state == "happy":
                c.cells([(8, y + 12), (15, y + 12)], "S")
        else:
            if state == "open":
                c.rect(14, y + 12, 17, y + 12, "d")
            if style == "stitch":
                c.rect(13, y + 13, 17, y + 13, "d"); c.cells([(14, y + 12), (16, y + 14)], "S")
            elif style == "jaw":
                c.rect(14, y + 13, 17, y + 13, "d"); c.rect(13, y + 14, 17, y + 14, "S"); c.put(15, y + 14, "s")
            else:
                c.rect(13, y + 13, 17, y + 13, "S"); c.cells([(14, y + 13), (16, y + 13)], "s")
                if style == "gap":
                    c.put(15, y + 13, "d")
                if style == "fang":
                    c.put(16, y + 14, "s")
                if style == "grin":
                    c.put(13, y + 12, "S")
        return c
    if view == "front":
        if state == "open":
            if style == "open":
                c.rect(10, y + 12, 13, y + 13, "m"); c.cells([(11, y + 13), (12, y + 13)], "p")
            else:
                c.rect(11, y + 12, 12, y + 13, "m")
        elif state == "happy":
            pts = [(10, y + 12), (11, y + 13), (12, y + 13), (13, y + 12)]
            if style == "smile":
                pts += [(9, y + 11), (14, y + 11)]
            elif style == "smirk":
                pts += [(14, y + 11)]
            elif style == "cat":
                pts = [(9, y + 12), (10, y + 13), (11, y + 12), (12, y + 12), (13, y + 13), (14, y + 12)]
            elif style == "open":
                pts = [(10, y + 12), (11, y + 12), (12, y + 12), (13, y + 12), (11, y + 13), (12, y + 13)]
            c.cells(pts, "m")
        else:
            if style == "line":
                c.cells([(11, y + 12), (12, y + 12)], "m")
            elif style == "smile":
                c.cells([(10, y + 12), (11, y + 13), (12, y + 13), (13, y + 12)], "m")
            elif style == "smirk":
                c.cells([(11, y + 12), (12, y + 12), (13, y + 11)], "m")
            elif style == "open":
                c.rect(11, y + 12, 12, y + 13, "m")
            elif style == "pout":
                c.cells([(11, y + 12), (12, y + 12)], "m"); c.cells([(11, y + 13), (12, y + 13)], "p")
            elif style == "cat":
                c.cells([(10, y + 13), (11, y + 12), (12, y + 12), (13, y + 13)], "m")
        if bt == "goblin_m":                                             # tusks stay in front of the lips
            c.cells([(10, y + 12), (13, y + 12)], "t")
        elif bt == "goblin_f" and not (state == "open"):
            c.put(12, y + 13, "t")
    else:
        if state == "open" or style == "open":
            c.cells([(16, y + 12), (16, y + 13)], "m")
        elif state == "happy" or style in ("smile", "cat"):
            c.cells([(16, y + 12), (15, y + 13)], "m")
        elif style == "pout":
            c.cells([(16, y + 12)], "m"); c.put(16, y + 13, "p")
        else:
            c.put(16, y + 12, "m")
        if bt == "goblin_m":
            c.put(17, y + 12, "t")
    return c


# --- hat and fx -------------------------------------------------------------------------------------------------------------
def hat_layer(fr):
    c = C()
    _oy, _u, y = heads(fr)
    view = fr["view"]
    if view == "front":
        c.rect(9, y + 1, 14, y + 1, "F"); c.rect(7, y + 2, 16, y + 4, "F")
        c.rect(15, y + 2, 16, y + 4, "f"); c.cells([(9, y + 2), (10, y + 2), (8, y + 3)], "L")
        c.rect(7, y + 4, 16, y + 4, "B")
        c.rect(5, y + 5, 18, y + 5, "F"); c.cells([(5, y + 5), (18, y + 5)], "f")
        c.cells([(17, y + 3), (18, y + 2), (18, y + 1), (19, y + 0), (19, y - 1), (20, y - 2), (18, y + 0), (17, y + 2)], "X")
        c.cells([(18, y + 1), (19, y - 1)], "x"); c.put(16, y + 3, "R")
    elif view == "back":
        c.rect(9, y + 1, 14, y + 1, "F"); c.rect(7, y + 2, 16, y + 4, "F"); c.rect(7, y + 2, 8, y + 4, "f")
        c.rect(7, y + 4, 16, y + 4, "B"); c.rect(5, y + 5, 18, y + 5, "f")
        c.cells([(6, y + 3), (5, y + 2), (5, y + 1), (4, y + 0), (4, y - 1), (3, y - 2), (5, y + 0), (6, y + 2)], "X")
        c.cells([(5, y + 1), (4, y - 1)], "x")
    else:                                                                # facing right: the brim reaches forward
        c.rect(9, y + 1, 14, y + 1, "F"); c.rect(7, y + 2, 15, y + 4, "F"); c.rect(7, y + 2, 8, y + 4, "f")
        c.cells([(10, y + 2), (11, y + 2)], "L")
        c.rect(7, y + 4, 15, y + 4, "B")
        c.rect(5, y + 5, 19, y + 5, "F"); c.put(19, y + 5, "f")
        c.cells([(7, y + 3), (6, y + 2), (5, y + 1), (5, y + 0), (4, y - 1), (4, y - 2), (6, y + 1)], "X")
        c.cells([(5, y + 1), (4, y - 1)], "x"); c.put(8, y + 3, "R")
    return c


def fx_layer(fr):
    """Effects that belong to the avatar, drawn in rig coordinates on a frame-wide canvas (x offset DX)."""
    c = pv.C(FW, FH)
    k = fr.get("fx")
    if not k:
        return c
    oy, u, y = heads(fr)
    X = lambda x: x + DX  # noqa: E731
    if k.startswith("hourglass"):
        x0, y0 = X(10), y - 6
        c.rect(x0, y0, x0 + 4, y0, "y"); c.rect(x0, y0 + 6, x0 + 4, y0 + 6, "y")
        c.cells([(x0 + 1, y0 + 1), (x0 + 3, y0 + 1), (x0 + 1, y0 + 5), (x0 + 3, y0 + 5)], "a")
        c.put(x0 + 2, y0 + 1, "Q"); c.put(x0 + 2, y0 + 2, "Q"); c.put(x0 + 2, y0 + 3, "a")
        c.rect(x0 + 1, y0 + 4, x0 + 3, y0 + 5, "Q")
        if k.endswith("1"):
            c.put(x0 + 2, y0 + 3, "Q")
    elif k.startswith("z"):
        f = int(k[1:])
        zz(c, X(18), y + 5 - f * 2, big=(f == 2))
        if f >= 1:
            zz(c, X(22), y - (f - 1) * 2)
    elif k in ("mug", "mug_up"):
        mx, my = X(12), u + (12 if k == "mug_up" else 16)
        c.rect(mx, my, mx + 2, my + 2, "P"); c.rect(mx, my, mx + 2, my, "p"); c.put(mx + 3, my + 1, "P"); c.put(mx + 1, my, "a")
    elif k.startswith("bubble"):
        f = int(k[-1])
        bx, by = X(16), oy - 6
        c.rect(bx + 1, by, bx + 9, by, "X"); c.rect(bx, by + 1, bx + 10, by + 5, "X"); c.rect(bx + 1, by + 6, bx + 9, by + 6, "x")
        c.cells([(bx + 1, by + 7), (bx + 2, by + 7), (bx + 1, by + 8)], "X")
        for i in range(f + 1):
            c.put(bx + 3 + 2 * i, by + 3, "D")
    elif k.startswith("spark"):
        sparkle(c, X(20), u + 9 - (1 if k.endswith("1") else 0), big=k.endswith("0"))
        if k.endswith("1"):
            sparkle(c, X(17), u + 5); sparkle(c, X(23), u + 6)
    elif k.startswith("stars"):
        for sx, sy in ((2, 4), (21, 2)) if k.endswith("0") else ((1, 2), (22, 5), (12, -3)):
            sparkle(c, X(sx), y + sy)
    return c.outline()


def zz(c, x, y, big=False):
    if big:
        c.rect(x, y, x + 3, y, "z"); c.put(x + 2, y + 1, "z"); c.put(x + 1, y + 2, "z"); c.rect(x, y + 3, x + 3, y + 3, "z")
    else:
        c.rect(x, y, x + 2, y, "z"); c.put(x + 1, y + 1, "z"); c.rect(x, y + 2, x + 2, y + 2, "z")


def sparkle(c, x, y, big=False):
    c.put(x, y, "X")
    c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "Y")
    if big:
        c.cells([(x - 2, y), (x + 2, y), (x, y - 2), (x, y + 2)], "Y")
        c.cells([(x - 2, y - 2), (x + 2, y - 2), (x - 2, y + 2), (x + 2, y + 2)], "y")


# --- palettes per layer (key colours for skin / hair / flame) ----------------------------------------------------------------
def base_pal(bk):
    return dict(pv.PALS[BODIES[bk]])


def layer_pal(layer, bk):
    p = base_pal(bk)
    O = OUTLINE[bk]
    if layer == "body":
        p.update(KEY_SKIN); p["O"] = O
    elif layer in ("bottom", "top", "shoes"):
        p.update(KEY_SKIN); p["O"] = O
    elif layer in ("hair_back", "hair_front"):
        q = dict(ACCENT)
        q.update({k: p[k] for k in "Aalk" if k in p})
        if bk == "undead_f":
            q.update(A=(120, 236, 214), T=p["T"], U=p["U"])
        q.update(KEY_HAIR); q.update(KEY_SKIN); q["D"] = O
        p = q
    elif layer in ("eyes", "mouth", "brows"):
        p.update(KEY_SKIN); p.update(KEY_HAIR); p.update(KEY_FLAME)
        p["d"] = (40, 34, 54)
    return p


def to_img(c, pal, mirror=False, x_off=DX):
    img = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    for y in range(c.h):
        for x in range(c.w):
            k = c.px[y][x]
            if k is not None:
                X = x + x_off
                if mirror:
                    X = FW - 1 - X
                if 0 <= X < FW:
                    img.putpixel((X, y), tuple(pal[k]) + (255,))
    return img


def strip(frame_canvases, pal, x_off=DX):
    """frame_canvases: list of canvases (one per frame); returns the strip image, or None if everything is empty."""
    out = Image.new("RGBA", (FW * N, FH), (0, 0, 0, 0))
    empty = True
    for i, c in enumerate(frame_canvases):
        if c is None:
            continue
        if any(k is not None for row in c.px for k in row):
            empty = False
        out.paste(to_img(c, pal, FRAMES[i]["view"] == "side", x_off), (i * FW, 0))
    return None if empty else out


# --- writing -------------------------------------------------------------------------------------------------------------------
def check_fixed_colours():
    """No fixed colour may equal a key colour (the renderer would recolour it)."""
    pals = [layer_pal(l, bk) for l in ("body", "top", "hair_front", "eyes") for bk in BODIES] + [HAT, FX]
    for p in pals:
        for k, v in p.items():
            if k in KEY_SKIN or k in KEY_HAIR or k in KEY_FLAME:
                continue
            assert tuple(v) not in ALL_KEYS, (k, v)



# ===========================================================================================================================
# 3. The hall: floor and wall tiles, furniture (mac/Resources/Guild)
# ===========================================================================================================================
GROOT = os.path.normpath(os.path.join(HERE, "..", "Resources", "Guild"))
TILE = 16
GP = dict(pv.FURN, **{
    "O": (52, 36, 28),
    # wood
    "W": (176, 118, 66), "w": (140, 90, 48), "V": (206, 150, 92), "v": (112, 70, 38),
    # stone
    "S": (150, 150, 158), "s": (118, 118, 128), "T": (184, 184, 190), "t": (92, 92, 104), "M": (72, 72, 84),
    # fabric
    "F": (176, 72, 92), "f": (132, 50, 70), "L": (214, 112, 130),
    "E": (150, 40, 52), "e": (112, 26, 40), "Y": (232, 190, 80), "y": (184, 140, 50),
    # marble
    "m": (236, 232, 226), "n": (196, 194, 200), "N": (170, 168, 178),
    # plants, water, fire, books
    "l": (70, 140, 70), "j": (110, 180, 90), "J": (44, 100, 56), "c": (196, 110, 70), "C": (150, 78, 50),
    "A": (100, 168, 240), "a": (170, 222, 255), "I": (60, 108, 190), "D": (40, 34, 54), "h": (255, 160, 170),
    "1": (255, 220, 120), "2": (255, 160, 60), "3": (230, 90, 40), "4": (255, 250, 220),
    "5": (120, 60, 140), "6": (60, 110, 160), "7": (180, 70, 60), "8": (70, 130, 80), "9": (210, 170, 80),
})
GLOW_D = dict(GP, G=(200, 255, 250), g=(120, 230, 230), R=(255, 255, 255), r=(110, 220, 210))


def gimg(c, pal=GP):
    img = Image.new("RGBA", (c.w, c.h), (0, 0, 0, 0))
    for y in range(c.h):
        for x in range(c.w):
            k = c.px[y][x]
            if k is not None:
                img.putpixel((x, y), tuple(pal[k]) + (255,))
    return img


def bbox(cs):
    xs, ys = [], []
    for c in cs:
        for y in range(c.h):
            for x in range(c.w):
                if c.px[y][x] is not None:
                    xs.append(x); ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def floors():
    out = {}
    c = pv.C(TILE, TILE)                                                 # oak planks, joints staggered
    for r, y in enumerate(range(0, TILE, 4)):
        c.rect(0, y, 15, y + 3, ["W", "V", "W", "w"][r] if False else "W")
        c.rect(0, y + 3, 15, y + 3, "w")
        c.put((r * 5 + 3) % 16, y, "w"); c.put((r * 5 + 3) % 16, y + 1, "w"); c.put((r * 5 + 3) % 16, y + 2, "w")
        c.put((r * 7 + 9) % 16, y + 1, "V"); c.put((r * 7 + 10) % 16, y + 1, "V")
    out["oak"] = c
    c = pv.C(TILE, TILE)                                                 # stone tiles
    c.rect(0, 0, 15, 15, "S")
    c.rect(0, 7, 15, 7, "t"); c.rect(7, 0, 7, 15, "t"); c.rect(0, 15, 15, 15, "t"); c.rect(15, 0, 15, 15, "t")
    for x0, y0 in ((0, 0), (8, 0), (0, 8), (8, 8)):
        c.rect(x0, y0, x0 + 6, y0, "T"); c.rect(x0, y0, x0, y0 + 6, "T")
    c.cells([(3, 3), (11, 12), (12, 4), (4, 11)], "s")
    out["stone"] = c
    c = pv.C(TILE, TILE)                                                 # red carpet with a small gold motif
    c.rect(0, 0, 15, 15, "E")
    for x0, y0 in ((4, 4), (12, 12)):
        c.cells([(x0, y0 - 1), (x0 - 1, y0), (x0 + 1, y0), (x0, y0 + 1)], "y"); c.put(x0, y0, "Y")
    c.cells([(12, 4), (4, 12)], "e")
    out["carpet"] = c
    c = pv.C(TILE, TILE)                                                 # checker marble
    for x0 in (0, 8):
        for y0 in (0, 8):
            c.rect(x0, y0, x0 + 7, y0 + 7, "m" if (x0 + y0) % 16 == 0 else "N")
    c.cells([(1, 2), (2, 3), (3, 3), (4, 5)], "n"); c.cells([(9, 10), (10, 11), (12, 12), (13, 14)], "n")
    c.cells([(10, 1), (11, 2), (12, 2)], "n"); c.cells([(2, 9), (3, 10), (5, 11)], "n")
    out["marble"] = c
    return out


def walls():
    """Wall pieces seen from the 3/4 top-down view: 16 x 32 (top cap 4 px, face, baseboard), tileable left-right."""
    out = {}
    for wid in ("stone", "wood"):
        c = pv.C(TILE, 2 * TILE)
        cap, cap2 = ("T", "S") if wid == "stone" else ("V", "W")
        c.rect(0, 0, 15, 3, cap); c.rect(0, 3, 15, 3, cap2)
        if wid == "stone":
            c.rect(0, 4, 15, 28, "S")
            for r, y in enumerate(range(4, 28, 5)):
                c.rect(0, y + 4, 15, y + 4, "t")
                off = 0 if r % 2 == 0 else 8
                c.rect(off % 16, y, off % 16, y + 3, "t"); c.rect((off + 8) % 16, y, (off + 8) % 16, y + 3, "t")
                c.put((off + 2) % 16, y + 1, "T"); c.put((off + 11) % 16, y + 2, "s")
        else:
            c.rect(0, 4, 15, 28, "W")
            for x in (0, 4, 8, 12):
                c.rect(x, 4, x, 28, "w")
            c.cells([(2, 9), (6, 17), (10, 12), (14, 22)], "v"); c.rect(0, 15, 15, 15, "v")
        c.rect(0, 29, 15, 31, "M"); c.rect(0, 29, 15, 29, "t")              # baseboard / shadow
        corner = pv.C(TILE, 2 * TILE)
        for y in range(32):
            for x in range(16):
                corner.px[y][x] = c.px[y][x]
        corner.rect(10, 0, 15, 31, "T" if wid == "stone" else "V")         # a pillar where the wall turns
        corner.rect(10, 0, 10, 31, "t" if wid == "stone" else "v"); corner.rect(15, 0, 15, 31, "s" if wid == "stone" else "w")
        corner.rect(10, 0, 15, 3, cap2); corner.rect(10, 29, 15, 31, "M")
        side = pv.C(TILE, TILE)                                            # the top of a side wall (left/right walls)
        side.rect(0, 0, 15, 15, cap); side.rect(0, 0, 0, 15, cap2); side.rect(15, 0, 15, 15, cap2)
        side.cells([(5, 4), (9, 11)], cap2)
        out[wid] = (c, corner, side)
    return out


def frame_canvas():
    return pv.C(FW + 8, FH)


def seat_sprite(kind, view):
    """Chairs drawn in the avatar frame's coordinates (anchor (16, 37)) so the seat point is exact. Side chairs face left."""
    c = pv.C(FW, FH)
    sy, floor = OY + pv.SEAT, OY + 26
    X = lambda x: x + DX  # noqa: E731   rig x -> frame x
    if view == "front":
        if kind == "stool":
            c.rect(8, sy, 23, sy, "V"); c.rect(8, sy + 1, 23, sy + 1, "W")
            c.rect(9, sy + 2, 9, floor, "w"); c.rect(22, sy + 2, 22, floor, "w")
        elif kind == "bench":
            c.rect(2, OY + 15, 29, OY + 16, "V"); c.rect(2, OY + 18, 29, OY + 19, "W")
            c.rect(3, OY + 15, 3, sy, "w"); c.rect(28, OY + 15, 28, sy, "w")
            c.rect(1, sy, 30, sy, "V"); c.rect(1, sy + 1, 30, sy + 1, "W")
            c.rect(2, sy + 2, 3, floor, "w"); c.rect(28, sy + 2, 29, floor, "w")
        else:
            c.rect(6, OY + 12, 25, sy, "F"); c.rect(7, OY + 11, 24, OY + 11, "F"); c.rect(7, OY + 12, 24, OY + 12, "L")
            c.cells([(10, OY + 15), (15, OY + 15), (16, OY + 15), (21, OY + 15), (12, OY + 19), (19, OY + 19)], "f")
            for x0 in (2, 26):
                c.rect(x0, OY + 18, x0 + 3, floor - 1, "F"); c.rect(x0, OY + 18, x0 + 3, OY + 18, "L")
                c.rect(x0 + (3 if x0 < 16 else 0), OY + 19, x0 + (3 if x0 < 16 else 0), floor - 1, "f")
            c.rect(6, sy, 25, sy, "L"); c.rect(6, sy + 1, 25, sy + 1, "F")
            c.rect(2, floor, 29, floor, "w"); c.cells([(3, floor), (28, floor)], "v")
    else:                                                                # drawn facing right, mirrored below
        if kind == "stool":
            c.rect(X(6), sy, X(16), sy, "V"); c.rect(X(6), sy + 1, X(16), sy + 1, "W")
            c.rect(X(7), sy + 2, X(7), floor, "w"); c.rect(X(15), sy + 2, X(15), floor, "w")
        elif kind == "bench":
            c.rect(X(5), OY + 15, X(6), sy, "w")
            c.rect(X(4), OY + 15, X(7), OY + 16, "V"); c.rect(X(4), OY + 18, X(7), OY + 19, "W")
            c.rect(X(4), sy, X(17), sy, "V"); c.rect(X(4), sy + 1, X(17), sy + 1, "W")
            c.rect(X(5), sy + 2, X(5), floor, "w"); c.rect(X(16), sy + 2, X(16), floor, "w")
        else:
            c.rect(X(1), OY + 12, X(6), floor - 1, "F"); c.rect(X(2), OY + 11, X(5), OY + 11, "F")
            c.rect(X(2), OY + 12, X(4), OY + 12, "L"); c.rect(X(6), OY + 13, X(6), floor - 1, "f")
            c.rect(X(6), OY + 18, X(17), OY + 19, "F"); c.rect(X(6), OY + 18, X(17), OY + 18, "L")
            c.rect(X(17), OY + 19, X(17), floor - 1, "f")
            c.rect(X(6), sy, X(17), sy, "L"); c.rect(X(6), sy + 1, X(17), floor - 1, "F")
            c.rect(X(1), floor, X(18), floor, "w"); c.cells([(X(2), floor), (X(17), floor)], "v")
        m = pv.C(FW, FH)
        for y in range(FH):
            for x in range(FW):
                m.px[y][FW - 1 - x] = c.px[y][x]
        c = m
    c.outline()
    x0, y0, x1, y1 = bbox([c])
    y1 = max(y1, ANCHOR[1])
    crop = pv.C(x1 - x0, y1 - y0)
    for y in range(y0, y1):
        for x in range(x0, x1):
            crop.px[y - y0][x - x0] = c.px[y][x] if y < FH else None
    return crop, (ANCHOR[0] - x0, ANCHOR[1] - y0)


def desk_frames():
    frames = []
    for f in range(2):
        d = pv.desk_front(40, 31, lit=True)
        if f == 1:
            for y in range(31):
                for x in range(40):
                    k = d.px[y][x]
                    d.px[y][x] = {"r": "R", "R": "r"}.get(k, k)
        crop = pv.C(40, 22)
        for y in range(22):
            crop.px[y] = d.px[y + 9][:]
        frames.append((crop, GLOW_D if f == 0 else GP))
    # the avatar sitting behind it: frame anchor (16, 37) <-> desk_front (17, 26) (the rune board under the hands)
    return frames, (17, 26 - 9), (20, 30 - 9)


def dispenser_frames():
    out = []
    for f in range(3):
        c = pv.C(16, 24)
        x, y = 3, 3
        rows = {0: (3, 6), 1: (1, 8), 2: (0, 9), 3: (0, 9), 4: (0, 9), 5: (0, 9), 6: (1, 8), 7: (2, 7)}
        bob = 1 if f == 1 else 0
        for r, (a, b) in rows.items():
            c.rect(x + a, y + r + bob, x + b, y + r + bob, "A")
        c.cells([(x + 2, y + 1 + bob), (x + 1, y + 2 + bob), (x + 1, y + 3 + bob), (x + 4, y + bob)], "a")
        c.rect(x + 7, y + 2 + bob, x + 8, y + 6 + bob, "I")
        curl = [[(x + 5, y - 1), (x + 4, y - 2)], [(x + 5, y), (x + 6, y - 1)], [(x + 4, y - 1), (x + 3, y - 2)]][f]
        c.cells([(px, py + bob) for px, py in curl], "a")
        if f == 2:
            c.cells([(x + 3, y + 4), (x + 4, y + 4), (x + 6, y + 4), (x + 7, y + 4)], "D")   # a happy squint
        else:
            c.cells([(x + 3, y + 4 + bob), (x + 6, y + 4 + bob)], "D")
        c.cells([(x + 4, y + 5 + bob), (x + 5, y + 5 + bob)], "D")
        c.cells([(x + 2, y + 5 + bob), (x + 7, y + 5 + bob)], "h")
        c.rect(x - 1, y + 7, x + 10, y + 9, "S"); c.rect(x - 1, y + 7, x + 10, y + 7, "T")
        c.rect(x + 10, y + 8, x + 11, y + 8, "B"); c.put(x + 11, y + 9, "B")
        if f == 0:
            c.put(x + 11, y + 11, "a")
        c.rect(x, y + 10, x + 9, y + 10, "V"); c.rect(x + 1, y + 11, x + 8, y + 19, "W")
        c.rect(x + 1, y + 15, x + 8, y + 15, "w"); c.rect(x + 4, y + 12, x + 5, y + 12, "B")
        c.outline()
        out.append(c)
    return out, (8, 23)


def rug():
    c = pv.C(48, 32)
    c.rect(1, 1, 46, 30, "E"); c.rect(1, 1, 46, 1, "Y"); c.rect(1, 30, 46, 30, "Y"); c.rect(1, 1, 1, 30, "Y"); c.rect(46, 1, 46, 30, "Y")
    c.rect(3, 3, 44, 28, "e"); c.rect(4, 4, 43, 27, "E")
    for x0, y0 in ((24, 16),):
        for r in range(6):
            c.rect(x0 - 6 + r, y0 - r, x0 + 5 - r, y0 - r, "y" if r % 2 else "Y")
            c.rect(x0 - 6 + r, y0 + r, x0 + 5 - r, y0 + r, "y" if r % 2 else "Y")
    for x in range(2, 46, 3):
        c.put(x, 0, "y"); c.put(x, 31, "y")                                # fringe
    return c


def plant():
    c = pv.C(16, 24)
    c.rect(4, 16, 11, 22, "c"); c.rect(3, 15, 12, 16, "C"); c.rect(5, 22, 10, 22, "C"); c.rect(10, 17, 10, 21, "C")
    for x, y0, h in ((7, 3, 13), (5, 6, 10), (10, 5, 11), (3, 9, 6), (12, 8, 7)):
        c.rect(x, y0, x, y0 + h - 1, "J")
    for (x, y) in ((6, 3), (7, 2), (8, 3), (4, 6), (5, 5), (10, 4), (11, 5), (9, 4), (2, 9), (3, 8), (12, 8), (13, 9),
                   (6, 8), (9, 9), (4, 11), (11, 11), (7, 7), (8, 11)):
        c.rect(x - 1, y, x + 1, y, "l"); c.put(x, y - 1, "j")
    c.outline()
    return c


def bookshelf():
    c = pv.C(32, 40)
    c.rect(1, 2, 30, 38, "W"); c.rect(1, 1, 30, 2, "V"); c.rect(1, 2, 1, 38, "v"); c.rect(30, 2, 30, 38, "v")
    cols = "56789"
    for s, y in enumerate((5, 15, 25)):
        c.rect(3, y, 28, y + 8, "v")
        x = 3
        i = s
        while x < 27:
            w = 2 + (i % 2)
            h = 6 + (i % 3)
            c.rect(x, y + 9 - h, x + w - 1, y + 8, cols[i % 5]); c.put(x, y + 9 - h + 1, "4")
            x += w + (1 if i % 4 == 0 else 0)
            i += 2
        c.rect(2, y + 9, 29, y + 9, "V")
    c.rect(3, 35, 28, 37, "w")
    c.outline()
    return c


def fireplace_frames():
    out = []
    for f in range(3):
        c = pv.C(48, 40)
        c.rect(2, 4, 45, 38, "S"); c.rect(0, 2, 47, 5, "T"); c.rect(0, 5, 47, 5, "t")       # stone, mantel
        for r, y in enumerate(range(8, 38, 5)):
            c.rect(2, y, 45, y, "t")
            off = 0 if r % 2 == 0 else 5
            for x in range(2 + off, 46, 10):
                c.rect(x, y - 4, x, y - 1, "t")
        c.rect(12, 14, 35, 38, "M"); c.rect(13, 15, 34, 38, "D")                          # the opening
        c.rect(14, 34, 33, 36, "v"); c.rect(16, 33, 31, 33, "w")                          # logs
        flames = [[(16, 26), (19, 20), (22, 24), (24, 17), (27, 23), (30, 21)],
                  [(16, 24), (19, 22), (22, 18), (25, 22), (27, 19), (31, 24)],
                  [(17, 22), (20, 18), (23, 23), (25, 16), (28, 21), (30, 25)]][f]
        for x, top in flames:
            for y in range(top, 33):
                col = "1" if y > 29 else ("2" if y > top + 3 else "3")
                c.rect(x - 1, y, x + 1, y, col)
            c.put(x, top - 1, "3")
        c.rect(18, 29, 29, 32, "1"); c.rect(20, 30, 27, 32, "4")
        c.cells([(8, 1), (9, 0), (38, 1), (39, 0)], "Y")                                  # candles on the mantel
        c.rect(8, 2, 9, 1, "4") if False else None
        c.outline()
        out.append(c)
    return out


def banner():
    c = pv.C(16, 32)
    c.rect(1, 1, 14, 1, "y"); c.cells([(0, 1), (15, 1)], "Y")
    c.rect(2, 2, 13, 25, "E"); c.rect(2, 2, 2, 25, "e"); c.rect(13, 2, 13, 25, "e")
    for i in range(6):                                                    # a swallow-tail end
        c.rect(2 + i, 25 + i, 7 - 0, 25 + i, "E") if i < 4 else None
        c.rect(8, 25 + i, 13 - i, 25 + i, "E") if i < 4 else None
    c.rect(4, 6, 11, 17, "Y"); c.rect(5, 7, 10, 16, "e"); c.rect(6, 9, 9, 14, "Y"); c.rect(7, 10, 8, 13, "E")   # a plain emblem
    c.outline()
    return c


def write_guild():
    os.makedirs(GROOT, exist_ok=True)
    written = []

    def save(img, rel):
        path = os.path.join(GROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
        written.append(path)
        return rel

    def save_strip(frames, rel, pals=None):
        w, h = frames[0].w, frames[0].h
        img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
        for i, c in enumerate(frames):
            img.alpha_composite(gimg(c, pals[i] if pals else GP), (i * w, 0))
        return save(img, rel)

    man = {"tile": TILE, "floors": {}, "walls": {}, "furniture": {},
           "notes": {
               "scale": "Same pixel scale as the avatars (an avatar is about 1.5 x 2 tiles).",
               "anchor": "Each furniture `anchor` is its floor point (sprite px): place it on the floor and y-sort by it.",
               "seat": "`seat` is where a sitting avatar's anchor goes (sprite px). Chairs (behind: true) are drawn BEFORE the "
                       "avatar that sits on them; the desk (behind: false) is drawn AFTER it (the avatar sits behind the desk, "
                       "hands on the rune board, using the type/doze/sit front frames).",
               "side": "*_side chairs face left like the avatar's side frames; mirror both together for right.",
               "flat": "flat: true pieces lie on the floor (draw with the floor, not y-sorted).",
               "wall": "wall: true pieces hang on the back wall (anchor = bottom centre of the sprite).",
               "walls": "A wall piece is 1 tile wide and 2 tiles tall: the top 4 px is the wall's cap seen from above, the rest "
                        "its face. Repeat it along the back wall; `corner` ends a run (mirror it for the other end); `side` "
                        "is the cap of a left/right wall seen from above (repeat it down).",
           }}
    for fid, c in floors().items():
        man["floors"][fid] = save(gimg(c), f"floors/{fid}.png")
    for wid, (face, corner, side) in walls().items():
        man["walls"][wid] = {"file": save(gimg(face), f"walls/{wid}.png"), "corner": save(gimg(corner), f"walls/{wid}_corner.png"),
                             "side": save(gimg(side), f"walls/{wid}_side.png"), "w": TILE, "h": 2 * TILE, "cap": 4}
    fr, seat, anchor = desk_frames()
    man["furniture"]["desk"] = {"file": save_strip([f for f, _ in fr], "furniture/desk.png", [p for _, p in fr]), "w": 40, "h": 22,
                                "frames": 2, "fps": 3, "anchor": {"x": anchor[0], "y": anchor[1]},
                                "seat": {"x": seat[0], "y": seat[1], "behind": False, "facing": "front"},
                                "solid": [3, 1]}
    for kind in ("stool", "bench", "armchair"):
        for view in ("front", "side"):
            c, (sx, sy) = seat_sprite(kind if kind != "armchair" else "sofa", view)
            fid = kind if view == "front" else kind + "_side"
            man["furniture"][fid] = {"file": save(gimg(c), f"furniture/{fid}.png"), "w": c.w, "h": c.h, "frames": 1, "fps": 0,
                                     "anchor": {"x": sx, "y": sy}, "seat": {"x": sx, "y": sy, "behind": True, "facing": view},
                                     "solid": [1 if kind == "stool" else 2, 1]}
    frs, anc = dispenser_frames()
    man["furniture"]["water_dispenser"] = {"file": save_strip(frs, "furniture/water_dispenser.png"), "w": 16, "h": 24, "frames": 3,
                                           "fps": 3, "anchor": {"x": anc[0], "y": anc[1]}, "solid": [1, 1],
                                           "use": {"x": anc[0] + 18, "y": anc[1], "anim": "drink",
                                                   "note": "where a drinking avatar stands (its anchor), facing front"}}
    r = rug()
    man["furniture"]["rug"] = {"file": save(gimg(r), "furniture/rug.png"), "w": 48, "h": 32, "frames": 1, "fps": 0,
                               "anchor": {"x": 24, "y": 32}, "solid": [0, 0], "flat": True}
    p = plant()
    man["furniture"]["plant"] = {"file": save(gimg(p), "furniture/plant.png"), "w": 16, "h": 24, "frames": 1, "fps": 0,
                                 "anchor": {"x": 8, "y": 23}, "solid": [1, 1]}
    b = bookshelf()
    man["furniture"]["bookshelf"] = {"file": save(gimg(b), "furniture/bookshelf.png"), "w": 32, "h": 40, "frames": 1, "fps": 0,
                                     "anchor": {"x": 16, "y": 39}, "solid": [2, 1]}
    fp = fireplace_frames()
    man["furniture"]["fireplace"] = {"file": save_strip(fp, "furniture/fireplace.png"), "w": 48, "h": 40, "frames": 3, "fps": 6,
                                     "anchor": {"x": 24, "y": 39}, "solid": [3, 1]}
    bn = banner()
    man["furniture"]["banner"] = {"file": save(gimg(bn), "furniture/banner.png"), "w": 16, "h": 32, "frames": 1, "fps": 0,
                                  "anchor": {"x": 8, "y": 32}, "solid": [0, 0], "wall": True}
    with open(os.path.join(GROOT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(man, f, ensure_ascii=False, indent=1)
        f.write("\n")
    return written


def main():
    check_fixed_colours()
    files = {k: {} for k in ("body", "hair_front", "hair_front_flat", "hair_back", "hair_back_flat", "eyes", "mouth", "brows",
                             "top", "bottom", "shoes", "hat")}
    written = []

    def save(img, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, optimize=True)
        written.append(path)
        return rel

    for bk in BODIES:
        clothes = {n: [] for n in ("bottom", "top", "shoes")}
        for face in FACES:
            bodies = []
            for fr in FRAMES:
                L = body_layers(bk, face, fr)
                bodies.append(L["body"])
                if face == "round":
                    for n in clothes:
                        clothes[n].append(L[n])
            img = strip(bodies, layer_pal("body", bk))
            files["body"][f"{bk}_{face}"] = save(img, f"body/{bk}_{face}.png")
        for n, cs in clothes.items():
            img = strip(cs, layer_pal(n, bk))
            if img:
                files[n][f"{bk}_default"] = save(img, f"{n}/{bk}_default.png")
        for hair in HAIRS[bk]:
            parts = [hair_layers(bk, hair, fr) for fr in FRAMES]
            for idx, name in enumerate(("hair_back", "hair_front", "hair_front_flat", "hair_back_flat")):
                img = strip([p[idx] for p in parts], layer_pal("hair_front", bk))
                if img:
                    files[name][f"{bk}_{hair}"] = save(img, f"{name}/{bk}_{hair}.png")
    done_bt = set()
    for bk, bt in BODY_TYPE.items():
        if bt in done_bt:
            continue
        done_bt.add(bt)
        pal = layer_pal("eyes", bk)
        for e in EYES:
            img = strip([eyes_layer(bt, e, fr) for fr in FRAMES], pal)
            if img:
                files["eyes"][f"{bt}_{e}"] = save(img, f"eyes/{bt}_{e}.png")
        for m in (SKULL_MOUTHS if bt == "skeleton" else MOUTHS):
            img = strip([mouth_layer(bt, m, fr) for fr in FRAMES], pal)
            if img:
                files["mouth"][f"{bt}_{m}"] = save(img, f"mouth/{bt}_{m}.png")
        for b in BROWS:
            img = strip([brows_layer(bt, b, fr) for fr in FRAMES], pal)
            if img:
                files["brows"][f"{bt}_{b}"] = save(img, f"brows/{bt}_{b}.png")
    files["hat"]["feather_cap"] = save(strip([hat_layer(fr) for fr in FRAMES], HAT), "hat/feather_cap.png")
    fx = strip([fx_layer(fr) for fr in FRAMES], FX, x_off=0)
    files["fx"] = save(fx, "fx.png")

    skin_opts = {}
    for bk, set_ in SKIN_SET.items():
        for sid, cols in SKINS[set_].items():
            skin_opts[f"{bk}_{sid}"] = [hexc(c) for c in cols]
    manifest = {
        "frameW": FW, "frameH": FH, "anchor": {"x": ANCHOR[0], "y": ANCHOR[1]}, "seatY": SEAT_Y, "frames": N,
        "layers": LAYER_ORDER,
        "render": {
            "order": "For frame i draw every layer's frame i in `layers` order at the same spot, after swapping the recolor keys "
                     "(exact RGB). Side frames face LEFT: mirror the whole composite for right.",
            "outline": "After `hat` and before `fx`, add a 1-px outline: every transparent pixel with an opaque 4-neighbour "
                       "becomes outline[bodyType key]. fx strips carry their own outline.",
            "hats": "When a hat is worn use hair_front_flat (and hair_back_flat when present) instead of hair_front/hair_back.",
            "frameOffset": "Add frameOffset[body][i] to y for every layer (and the outline) of that body (the spirit floats).",
            "missing": "A layer whose key is missing from `files` is empty for that option.",
        },
        "outline": {bk: hexc(c) for bk, c in OUTLINE.items()},
        "frameOffset": {"undead_f": [FRAMES[i]["bob"] for i in range(N)]},
        "anims": ANIMS,
        "highfive": {"anchorGap": HIGHFIVE_GAP, "note": "Two avatars facing each other, anchors this many px apart."},
        "files": files,
        "bodyType": BODY_TYPE,
        "recolor": {
            "skin": {"keys": [hexc(KEY_SKIN[k]) for k in ("S", "s", "x")], "options": skin_opts},
            "hair": {"keys": [hexc(KEY_HAIR[k]) for k in ("J", "H", "h")],
                     "options": {k: [hexc(c) for c in v] for k, v in HAIR_COLORS.items()}},
            "flame": {"keys": [hexc(KEY_FLAME["e"])], "options": {k: [hexc(v)] for k, v in FLAMES.items()}},
        },
    }
    with open(os.path.join(ROOT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
        f.write("\n")
    size = sum(os.path.getsize(p) for p in written)
    print(f"avatars: frames {N}, {FW}x{FH}; wrote {len(written)} PNGs, {size / 1024:.0f} KB, + manifest.json")
    g = write_guild()
    print(f"guild: wrote {len(g)} PNGs, {sum(os.path.getsize(p) for p in g) / 1024:.0f} KB, + manifest.json")


if __name__ == "__main__":
    main()
