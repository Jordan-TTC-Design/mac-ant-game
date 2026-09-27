#!/usr/bin/env python3
"""Draws the elves (a playable race, see RACES.md) as 16x16 pixel-art sprite sheets, in the same style and layout as the
goblins: five breeds, three children of the elves and their fox princess, and the fox princess herself (the "queen" role).

    python3 tools/make_elf.py                         # writes Resources/Characters/elf/*
    python3 tools/make_elf.py --preview /path/p.png   # also writes a zoomed contact sheet

The bodies, walk cycles and the princess's poses are the goblin script's own (tools/make_goblin.py); only the colours, the
hair, the clothes and the ears differ. The fox princess wears a two-piece hide outfit (a short hide top that covers her chest,
a hide skirt to mid-thigh), fox ears and a tail: tribal, never a bikini.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_goblin as mg  # noqa: E402

SIZE = mg.SIZE

# --- the elves ---------------------------------------------------------------------------------------------------
# Their own chibi body, not the goblins': a round face with green eyes and a blush, long ears sweeping out and up, a slim body in
# a belted tunic and boots. Each breed has its own hair and clothes.
Canvas = mg.Canvas
ELF = {
    "O": (58, 42, 38),                                     # outline: warm dark brown
    "g": (250, 226, 204), "G": (226, 192, 166),            # skin and its shade
    "y": (255, 255, 255), "e": (52, 140, 86), "L": (60, 44, 44),   # eye white, green iris, lashes
    "r": (240, 168, 170), "p": (248, 170, 170), "k": (200, 108, 108),  # inner ear, blush, mouth
    "N": (150, 100, 52), "n": (116, 74, 38),               # brown hair
    "b": (92, 150, 80), "B": (62, 106, 56),                # green cloth
    "K": (96, 70, 46),                                     # boots, belt
    "S": (184, 194, 176), "s": (150, 160, 144),            # grey-green hair (the antlered one)
    "M": (178, 196, 230), "m": (140, 158, 200),            # silver-blue hair
    "P": (150, 190, 230), "Y": (246, 206, 80), "W": (250, 250, 244),   # pale blue robe, gold, white
    "V": (128, 88, 52), "v": (96, 64, 38),                 # bark
    "l": (80, 150, 64), "E": (120, 190, 90),               # leaves
    "F": (236, 140, 60), "f": (190, 96, 40), "X": (252, 244, 232),   # fox fur and its white tip
}


def legs(c, view, phase, boot="K", leg="B", wide=False):
    if view == "side":
        if phase in (0, 2):
            c.rect(6, 12, 6, 13, leg); c.put(6, 14, boot); c.put(5, 14, boot)
            c.rect(9, 12, 9, 13, leg); c.put(9, 14, boot); c.put(10, 14, boot)
        else:
            lift = (1, 0) if phase == 3 else (0, 1)
            c.rect(7, 12, 7, 13 - lift[0], leg); c.put(7, 14 - lift[0], boot)
            c.rect(8, 12, 8, 13 - lift[1], leg); c.put(8, 14 - lift[1], boot); c.put(9, 14 - lift[1], boot)
        return
    for x, lift in ((6, 1 if phase == 1 else 0), (9, 1 if phase == 3 else 0)):
        w = 2 if wide else 1
        xx = x - (w - 1) if x == 6 else x
        c.rect(xx, 12, xx + w - 1, 13 - lift, leg)
        c.rect(xx, 14 - lift, xx + w - 1, 14 - lift, boot)


def body(c, view, phase, cloth="b", shade="B", wide=False, robe=None, sleeve=None):
    """Tunic (or a robe to the ground), belt and arms. `sleeve` colours the arms; bare arms are skin."""
    x0, x1 = (5, 10) if wide else (6, 9)
    if view == "side":
        x0, x1 = 6, 9
    if robe:
        for y in range(9, 15):
            spread = (y - 9) // 2
            c.rect(x0 - spread, y, x1 + spread, y, robe[0])
        c.rect(x0, 11, x1, 11, robe[1])
    else:
        c.rect(x0, 9, x1, 12, cloth)
        c.rect(x0, 11, x1, 11, "K")                                         # belt
        c.rect(x1, 9, x1, 12, shade)
    arm = sleeve or "g"
    swing = {0: 0, 1: -1, 2: 0, 3: 1}[phase]
    if view == "side":
        ax = {0: 8, 1: 9, 2: 8, 3: 6}[phase]
        c.rect(ax, 9, ax, 11, arm); c.put(ax, 12 if phase in (0, 2) else 11, "g")
        return
    for x, s in ((x0 - 1, swing), (x1 + 1, -swing)):
        c.rect(x, 9 + s, x, 11 + s, arm)
        c.put(x, 12 + s, "g")                                              # the hand


def head(c, view, hair="N", hair_dark="n", style="short", ears=True):
    """A round face (rows 2-8) with hair on top; ears sweep out and up from row 5."""
    c.rect(5, 2, 10, 2, "g"); c.rect(4, 3, 11, 7, "g"); c.rect(5, 8, 10, 8, "g")
    if view == "side":
        c.rect(5, 2, 10, 2, "g"); c.rect(5, 3, 11, 7, "g"); c.rect(6, 8, 10, 8, "g")
    # ears
    if ears:
        if view == "side":
            c.cells([(5, 5), (5, 6), (4, 4), (4, 5), (3, 3), (3, 4), (2, 2)], "g"); c.put(4, 5, "r")
        else:
            left = [(3, 4), (3, 5), (3, 6), (2, 4), (2, 5), (1, 3), (1, 4), (0, 2)]          # wide at the head, pointed at the tip
            c.cells(left + [(15 - x, y) for x, y in left], "g")
            c.cells([(2, 5), (13, 5)], "r")
    # hair
    if view == "back":
        c.rect(5, 1, 10, 1, hair); c.rect(4, 2, 11, 8, hair); c.rect(4, 7, 11, 8, hair_dark)
        if style == "long":
            c.rect(4, 9, 11, 11, hair); c.rect(4, 11, 11, 11, hair_dark)
        return
    if view == "side":
        c.rect(5, 1, 10, 1, hair); c.rect(4, 2, 11, 2, hair); c.rect(4, 3, 7, 3, hair)
        c.rect(4, 3, 5, 7, hair)                                            # hair behind the ear
        if style == "long":
            c.rect(3, 4, 5, 11, hair); c.rect(3, 10, 5, 11, hair_dark)
        c.rect(9, 4, 9, 5, "L"); c.put(9, 5, "e")                             # the eye
        c.put(10, 7, "p"); c.put(11, 6, "g")
        return
    c.rect(5, 1, 10, 1, hair); c.rect(4, 2, 11, 2, hair)
    c.cells([(4, 3), (5, 3), (10, 3), (11, 3), (4, 4), (11, 4)], hair)        # a parted fringe
    c.put(7, 2, hair_dark)
    if style == "long":
        c.rect(3, 5, 3, 10, hair); c.rect(12, 5, 12, 10, hair)
        c.cells([(3, 10), (12, 10)], hair_dark)
    c.cells([(6, 4), (9, 4)], "L")                                            # lashes
    c.cells([(6, 5), (9, 5)], "e")                                            # green eyes
    c.cells([(5, 5), (10, 5)], "y")                                           # a little white beside them
    c.cells([(5, 6), (10, 6)], "p")                                           # blush
    c.put(7, 7, "k"); c.put(8, 7, "k")                                        # a small smile


def elf(view, phase, *, hair="N", hair_dark="n", style="short", cloth="b", shade="B", wide=False, robe=None, sleeve=None,
        extra=None, behind=None, after=None):
    c = Canvas()
    if behind:
        behind(c, view, phase)
    if not robe:
        legs(c, view, phase, wide=wide)
    body(c, view, phase, cloth, shade, wide, robe, sleeve)
    head(c, view, hair, hair_dark, style)
    if extra:
        extra(c, view, phase)
    c.outline()
    if after:
        after(c, view, phase)
    return c


def hood(c, view, phase):
    """A green hood and cape; the bow shows over a shoulder."""
    if view == "back":
        c.rect(4, 1, 11, 10, "B"); c.rect(5, 9, 10, 12, "B")
        c.cells([(5 + k, 9 + k) for k in range(5)], "V")                    # the bow across the back
    elif view == "side":
        c.rect(5, 1, 10, 2, "B"); c.rect(3, 3, 5, 11, "B")
        c.cells([(2, 8), (2, 9), (2, 10)], "V")
    else:
        c.rect(4, 1, 11, 2, "B"); c.cells([(4, 3), (11, 3), (3, 4), (12, 4)], "B")
        c.cells([(12, 8), (13, 7)], "V")


def bark(c, view, phase):
    """Bark armour on the shoulders and a crown of leaves."""
    c.rect(4, 0, 11, 1, "l"); c.cells([(5, 0), (8, 0), (10, 0)], "E")
    if view != "side":
        c.rect(3, 9, 5, 9, "V"); c.rect(10, 9, 12, 9, "V")
        c.cells([(7, 10), (8, 12), (6, 12)], "v")


def antlers(c, view, phase):
    c.cells([(5, 0), (4, 0), (4, -1), (10, 0), (11, 0), (11, -1)], "V")
    c.cells([(3, 1), (12, 1)], "V")
    if view == "front":
        c.rect(12, 6, 12, 14, "V"); c.put(12, 5, "E")                        # a staff with a leaf


def circlet(c, view, phase):
    c.rect(5, 2, 10, 2, "Y")
    if view == "front":
        c.put(7, 2, "W"); c.put(8, 2, "W")                                     # the moon on it


def shimmer(c, view, phase):
    for x, y in ((1, 1), (14, 2), (0, 10), (15, 9)):
        if (x + phase) % 2 == 0:
            c.put(x, y, "W")


def fox_ears(small):
    def draw(c, view, phase):
        pts = [(5, 0), (5, 1), (6, 1)] if small else [(4, 0), (5, 0), (4, 1), (5, 1), (6, 1)]
        right = [(15 - x, y) for x, y in pts]
        c.cells(pts + ([] if view == "side" else right), "F")
        if not small and view == "front":
            c.cells([(5, 1), (10, 1)], "p")
    return draw


def fox_tail(c, view, phase):
    if view == "front":
        c.cells([(11, 11), (12, 12), (13, 12), (13, 13)], "F"); c.put(13, 14, "X")
    elif view == "back":
        c.rect(7, 11, 8, 13, "F"); c.cells([(9, 13), (9, 14)], "F"); c.put(9, 15, "X")
    else:
        c.cells([(5, 11), (4, 12), (3, 12), (3, 13)], "F"); c.put(3, 14, "X")


def both(*fns):
    def draw(c, view, phase):
        for fn in fns:
            fn(c, view, phase)
    return draw


# id, name, weight, boost, blurb, stats, sheet, drawer, palette
BREEDS = [
    ("common", "林民", 100, 0, "住在森林裡的精靈，會採集、會射箭，活得比哥布林久得多。",
     {"lifespan": 2.0, "might": 1.3, "health": 3.5}, "worker.png", lambda v, p: elf(v, p), ELF),
    ("scout", "綠斗篷", 10, 1.0, "披著綠斗篷、背著弓，腳步輕、眼睛利，遠遠就看得到獵物。",
     {"speed": 1.3, "sense": 1.4, "rest": 0.8, "lifespan": 1.8, "might": 1.2, "health": 2.5}, "scout.png",
     lambda v, p: elf(v, p, cloth="B", shade="B", sleeve="B", extra=hood), ELF),
    ("brute", "樹皮精靈", 8, 1.0, "高大、穿著樹皮盔甲，走得慢，一次搬兩份，站在最前面。",
     {"speed": 0.8, "sense": 0.9, "carry": 2, "rest": 1.2, "lifespan": 2.5, "might": 1.8, "health": 6}, "brute.png",
     lambda v, p: elf(v, p, cloth="V", shade="v", wide=True, extra=bark), ELF),
    ("sage", "鹿角精靈", 5, 1.5, "頂著小鹿角、留著長髮，懂得草藥，也很會叫同伴來幫忙。",
     {"speed": 0.95, "sense": 1.3, "recruit": 3, "lifespan": 2.3, "might": 1.0}, "sage.png",
     lambda v, p: elf(v, p, hair="S", hair_dark="s", style="long", robe=("l", "V"), sleeve="l", extra=antlers), ELF),
    ("golden", "銀月精靈", 1, 3.0, "罕見的銀月精靈，銀髮上戴著月亮頭環，每一方面都好一點。",
     {"speed": 1.1, "sense": 1.2, "recruit": 1, "rest": 0.9, "lifespan": 4.0, "might": 1.5, "health": 5}, "golden.png",
     lambda v, p: elf(v, p, hair="M", hair_dark="m", style="long", robe=("P", "W"), sleeve="P", extra=circlet, after=shimmer), ELF),
    # The children of a silvermoon elf and the fox princess. Never born by chance: weight 0.
    ("half_gob", "獸血・偏精靈", 0, 0, "銀月精靈與狐族公主的孩子，偏向精靈：一撮紅髮，箭射得更準。",
     {"speed": 1.05, "sense": 1.3, "lifespan": 2.8, "might": 1.4, "health": 4, "recruit": 1}, "half_gob.png",
     lambda v, p: elf(v, p, extra=lambda c, vv, pp: c.cells([(6, 1), (7, 1), (6, 2)], "F")), ELF),
    ("half_mix", "獸血・各半", 0, 0, "銀月精靈與狐族公主的孩子，精靈與狐族各半：紅髮、一對小狐耳，什麼都好一點。",
     {"speed": 1.1, "sense": 1.25, "lifespan": 3.0, "might": 1.5, "health": 4.5, "recruit": 1}, "half_mix.png",
     lambda v, p: elf(v, p, hair="F", hair_dark="f", extra=fox_ears(True)), ELF),
    ("half_hum", "獸血・偏獸", 0, 0, "銀月精靈與狐族公主的孩子，偏向狐族：狐耳、狐尾、毛皮背心。力氣大又耐打，是近戰的精靈。",
     {"speed": 1.05, "sense": 1.1, "carry": 2, "lifespan": 3.0, "might": 2.0, "health": 7}, "half_hum.png",
     lambda v, p: elf(v, p, hair="F", hair_dark="f", cloth="V", shade="v", wide=True, behind=fox_tail, extra=fox_ears(False)), ELF),
]


def breed_sheet(draw, pal):
    """4 phases x (front, back, side), the goblins' layout."""
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


# --- the fox princess --------------------------------------------------------------------------------------------
FOX = dict(mg.GIRL, H=(236, 132, 56), h=(255, 186, 110), J=(186, 90, 38), i=(214, 150, 40), X=(252, 244, 232),
           Z=(250, 196, 188))

OUTFITS = [
    dict(id="hide", name="兩截式獸皮", bottom="skirt", sleeves="puff", hat="fox", midriff=True, hem=True,
         pal={"Q": (176, 120, 72), "q": (140, 90, 52), "D": (160, 108, 64), "d": (118, 78, 44), "W": (246, 232, 206),
              "K": (120, 80, 50), "R": (240, 236, 220)}),
    dict(id="winter", name="毛皮斗篷", bottom="coat", sleeves="long", hat="fox",
         pal={"Q": (150, 104, 70), "q": (112, 76, 50), "D": (150, 104, 70), "d": (112, 76, 50), "A": (246, 232, 206),
              "W": (246, 232, 206), "K": (96, 64, 40), "T": (90, 70, 60)}),
    dict(id="maternity1", name="孕婦裝（初期）", bottom="dress", sleeves="puff", hat="fox", belly=1,
         pal={"Q": (214, 180, 132), "q": (176, 140, 96), "D": (214, 180, 132), "d": (176, 140, 96), "R": (236, 132, 56),
              "W": (246, 232, 206)}),
    dict(id="maternity2", name="孕婦裝（後期）", bottom="dress", sleeves="puff", hat="fox", belly=2,
         pal={"Q": (214, 180, 132), "q": (176, 140, 96), "D": (214, 180, 132), "d": (176, 140, 96), "R": (236, 132, 56),
              "W": (246, 232, 206)}),
    dict(id="pajamas", name="睡衣", bottom="pants", sleeves="long", hat="fox",
         pal={"Q": (236, 226, 190), "q": (206, 192, 150), "D": (236, 226, 190), "d": (206, 192, 150), "K": (236, 200, 160),
              "W": (255, 255, 255)}),
]

_view = ["front"]
_original_squash = mg.squash


def _fox_squash(c, o):
    """Everything the fox princess has that the human one has not, drawn just before she is squashed to her proportions
    and outlined (so it becomes part of her silhouette): ears, tail, the bare waist of the two-piece, the longer hem."""
    if o.get("hat") == "fox":
        view = _view[0]
        # ears: two points above the hair, the pink showing from the front
        if view == "side":
            c.cells([(6, 0), (5, 1), (6, 1)], "H")
        else:
            for x, inner in ((4, 5), (11, 10)):
                c.cells([(x, 0), (x, 1), (inner, 1)], "H")
            if view == "front":
                c.cells([(5, 1), (10, 1)], "Z")
        # the tail, low behind her, with a white tip
        if view == "front":
            c.cells([(12, 11), (13, 11), (13, 13), (12, 13)], "H")
            c.put(13, 14, "X")
        elif view == "back":
            c.cells([(7, 11), (8, 11), (7, 13), (8, 13), (9, 13), (8, 14), (9, 14)], "H")
            c.put(9, 15, "X")
            c.cells([(5, 4), (6, 5), (9, 5), (10, 4), (7, 6), (8, 6)], "h")   # light in her hair
            c.rect(6, 7, 9, 7, "A")                                   # a braid tie
        else:
            c.cells([(4, 11), (3, 11), (3, 13), (2, 13)], "H")
            c.put(2, 14, "X")
    if o.get("midriff"):                                              # the hide top stops above the waist
        for x in range(4, 12):
            if c.px[10][x] == "Q":
                c.px[10][x] = "s"
        c.cells([(4, 8), (11, 8)], "W")                               # fur edging at the shoulders
    if o.get("hem"):                                                  # the skirt reaches to mid-thigh, with a ragged hem
        view = _view[0]
        xs = range(6, 10) if view == "side" else range(4, 12)
        for x in xs:
            c.put(x, 13, "D" if x % 2 == 0 else "d")
        if view == "front":
            c.put(7, 11, "R")                                         # a bone bead on the belt
    return _original_squash(c, o)


def _wrap(fn, view):
    def drawn(*args, **kwargs):
        _view[0] = view
        return fn(*args, **kwargs)
    return drawn


mg.squash = _fox_squash
mg.girl_front = _wrap(mg.girl_front, "front")     # (the poses call girl_front through the module, so they get it too)
mg.girl_back = _wrap(mg.girl_back, "back")
mg.girl_side = _wrap(mg.girl_side, "side")


def princess_sheet(outfit):
    saved = dict(mg.GIRL)
    mg.GIRL.clear()
    mg.GIRL.update(FOX)
    try:
        return mg.build_sheet(True, outfit=outfit)
    finally:
        mg.GIRL.clear()
        mg.GIRL.update(saved)


# --- icon: an elf's face ------------------------------------------------------------------------------------------
def elf_face():
    """The menu bar icon: the plain elf, front on."""
    c = elf("front", 0)
    return [[(ELF[c.px[y][x]] + (255,)) if c.px[y][x] else (0, 0, 0, 0) for x in range(SIZE)] for y in range(SIZE)]


def preview(path, zoom=8):
    """Contact sheet: every breed (front, back, side x2 phases) then every outfit of the princess, plus a row of her poses."""
    sheets = [breed_sheet(b[7], b[8]) for b in BREEDS] + [princess_sheet(o) for o in OUTFITS]
    cols = 8
    w = cols * SIZE * zoom
    pose_rows = len(mg.POSES)
    h = (len(sheets) + 3) * SIZE * zoom
    bg = (204, 222, 190, 255)
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
    first = princess_sheet(OUTFITS[0])                                # her poses, in the hide outfit
    k = 0
    for pr in range(pose_rows):
        for f in range(4):
            if k >= 3 * cols:
                break
            blit(first, f * SIZE, (3 + pr) * SIZE, (k % cols) * SIZE, (len(sheets) + k // cols) * SIZE)
            k += 1
    mg.write_png(path, out)


FEATURES = ["生得慢（間隔兩倍），但活得久（大約兩倍）、單隻強",
            "遠遠射箭打獵物，很少被咬到",
            "不砍樹：撿樹枝、採野莓、照顧樹",
            "果實、野莓、蜂蜜、清水的加成 ×1.5；不吃肉，烤肉、烤魚沒有效果",
            "首領是狐族公主；和銀月精靈的孩子有近戰的獸血精靈"]


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Characters", "elf")
    os.makedirs(root, exist_ok=True)
    for _id, _name, _w, _b, _blurb, _stats, sheet, draw, pal in BREEDS:
        mg.write_png(os.path.join(root, sheet), breed_sheet(draw, pal))
    for o in OUTFITS:
        mg.write_png(os.path.join(root, "queen.png" if o["id"] == "hide" else f"queen_{o['id']}.png"), princess_sheet(o))
    mg.write_png(os.path.join(root, "icon.png"), elf_face())
    walk = {"down": [0, 1, 2, 3], "up": [4, 5, 6, 7], "side": [8, 9, 10, 11]}
    manifest = {
        "id": "elf",
        "name": "精靈",
        "noun": "精靈",
        "emoji": "🧝",
        "icon": "icon.png",
        "nestName": "營地",
        "frame": SIZE,
        "defaultMaxCount": 120,
        "tagline": "生得慢、活得久、單隻強，和森林一起生活的弓手。",
        "features": FEATURES,
        "rules": {
            "spawnScale": 2.0,
            "food": {"fruit": 1.5, "berries": 1.5, "honey": 1.5, "water": 1.5, "meat": 0, "fish": 0},
            "fellsTrees": False,
            "ranged": 34,
            "noDecor": ["skull", "spears", "bones-0", "bones-1", "totem"],
            "names": "elf",
            "princessNames": ["琥珀", "紅葉", "小楓", "焰尾", "緋音", "朱鈴", "狐月", "秋露", "楓鈴", "赤瑚", "橘音", "茜"],
            "camp": "stump",
            "biome": "elfwood",
        },
        "worker": {"sheet": "worker.png", "pixelScale": 1.5, "walk": walk},
        "breeds": [{"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet}
                   for i, n, w, b, blurb, stats, sheet, _d, _p in BREEDS],
        "queen": {"sheet": "queen.png", "pixelScale": 2.0, "walk": walk,
                  "poses": {name: [(3 + r) * 4 + f for f in range(count)] for r, (name, _d, count) in enumerate(mg.POSES)},
                  "outfits": [{"id": o["id"], "name": o["name"], "sheet": "queen.png" if o["id"] == "hide" else f"queen_{o['id']}.png"}
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
