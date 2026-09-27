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
# Fair skin, long ears that point up, eyes with whites and green irises, no tusks, a tunic instead of a loincloth.
ELF = dict(mg.COMMON,
           O=(62, 46, 40),                                  # outline: warm dark brown
           g=(246, 224, 200), G=(222, 190, 162), h=(255, 240, 222),   # skin
           y=(255, 255, 255), e=(52, 140, 86),              # eye white, green iris
           t=(246, 224, 200),                               # "tusks" painted as skin: elves have none
           k=(200, 112, 112), r=(236, 170, 170),
           b=(92, 150, 80), B=(62, 106, 56),                # tunic
           N=(150, 100, 52), n=(116, 74, 38),               # hair
           R=(176, 52, 56), P=(96, 150, 200), W=(244, 244, 236), S=(196, 198, 190),
           V=(128, 88, 52), v=(96, 64, 38),                 # bark, wood
           L=(120, 190, 90), l=(80, 150, 64),               # leaves
           F=(236, 140, 60), f=(190, 96, 40), X=(250, 240, 226),   # fox fur and its white
           Y=(246, 206, 80))                                # gold


def look(pal=None, build=None, hair="N", pre=None, post=None):
    lk = mg.Look(build=build, hair=hair, pre=pre, post=post)
    lk.palette = dict(ELF, **(pal or {}))
    return lk


def tunic(c, b, view, col="b", shade="B"):
    """A tunic over the chest down to the hips (the goblin's body is drawn bare)."""
    if view == "side":
        x0, x1 = b.stx
        c.rect(x0, b.shoulder, x1, b.hip + 1, col)
        c.rect(x0, b.hip - 1, x1, b.hip - 1, shade)                 # belt
        return
    for y in range(b.shoulder, b.hip + 2):
        left, right = b.edge(min(y, b.hip))
        c.rect(left, y, right, y, col)
    p0, p1 = b.lx
    c.rect(p0, b.hip - 1, p1, b.hip - 1, shade)


def hair_front(c, b, col="N", long=False):
    x0, x1 = b.hx
    c.rect(x0 + 1, b.y0 - 1, x1 - 1, b.y0 - 1, col)                  # on top of the head
    c.rect(x0, b.y0, x1, b.y0, col)
    c.cells([(x0, b.y0 + 1), (x1, b.y0 + 1), (x0 + 1, b.y0 + 1), (x1 - 1, b.y0 + 1)], col)   # a parted fringe
    if long:
        c.rect(x0 - 1, b.y0 + 1, x0 - 1, b.y1 + 2, col)
        c.rect(x1 + 1, b.y0 + 1, x1 + 1, b.y1 + 2, col)


def hair_back(c, b, col="N", long=False):
    x0, x1 = b.hx
    c.rect(x0 + 1, b.y0 - 1, x1 - 1, b.y0 - 1, col)
    c.rect(x0, b.y0, x1, b.y1 - (0 if long else 2), col)
    if long:
        c.rect(x0, b.y1 + 1, x1, b.y1 + 3, col)


def hair_side(c, b, col="N", long=False):
    x0, x1 = b.sx
    c.rect(x0, b.y0 - 1, x1 - 1, b.y0 - 1, col)
    c.rect(x0 - 1, b.y0, x1, b.y0, col)
    c.rect(x0 - 1, b.y0 + 1, x0 + 1, b.y1 - (0 if long else 2), col)  # falling behind the ear
    if long:
        c.rect(x0 - 1, b.y1 + 1, x0 + 1, b.y1 + 3, col)


def hair(c, b, view, col="N", long=False):
    {"front": hair_front, "back": hair_back, "side": hair_side}[view](c, b, col, long)


def common_pre(c, view, phase, b=None):
    b = b or COMMON_BUILD
    tunic(c, b, view)
    hair(c, b, view)


def scout_pre(c, view, phase):
    """A ranger: a green hood and cape, and a bow across the back."""
    b = SCOUT_BUILD
    tunic(c, b, view, "B", "n")
    x0, x1 = b.hx if view != "side" else b.sx
    c.rect(x0, b.y0 - 1, x1, b.y0, "B")                              # the hood
    if view == "back":
        c.rect(x0, b.y0 + 1, x1, b.y1, "B")
        c.cells([(x0 + 1 + k, b.shoulder + k) for k in range(5)], "V")   # the bow across the back
    elif view == "side":
        c.rect(x0 - 1, b.y0, x0, b.y1 + 1, "B")
        c.cells([(x0 - 2, b.shoulder), (x0 - 2, b.shoulder + 1), (x0 - 2, b.shoulder + 2)], "V")
    else:
        c.cells([(x0, b.y0 + 1), (x1, b.y0 + 1)], "B")
        c.put(x1 + 1, b.shoulder - 1, "V")                            # the tip of the bow over a shoulder


def brute_pre(c, view, phase):
    """A tree guard: bark armour on a broad chest, a crown of leaves."""
    b = BRUTE_BUILD
    tunic(c, b, view, "V", "v")
    x0, x1 = b.hx if view != "side" else b.sx
    c.rect(x0, b.y0 - 1, x1, b.y0 - 1, "L")
    c.cells([(x0 + 1, b.y0 - 2), (x1 - 1, b.y0 - 2), ((x0 + x1) // 2, b.y0 - 2)], "l")
    if view == "front":
        tx0, tx1 = b.tx
        c.cells([(tx0 + 1, b.shoulder + 1), (tx1 - 1, b.shoulder + 2), (tx0 + 2, b.shoulder + 3)], "v")   # bark grain
        c.cells([(tx0, b.shoulder), (tx1, b.shoulder)], "L")          # moss on the shoulders


def sage_pre(c, view, phase):
    """A druid: long white hair, a robe to the ground and small antlers."""
    b = SAGE_BUILD
    x0, x1 = b.hx if view != "side" else b.sx
    hair(c, b, view, "S", long=True)
    c.cells([(x0, b.y0 - 2), (x0 - 1, b.y0 - 3), (x1, b.y0 - 2), (x1 + 1, b.y0 - 3)], "V")   # antlers
    robe = (6, 9) if view == "side" else (5, 10)
    c.rect(robe[0], b.shoulder, robe[1], b.foot - 1, "l")
    c.rect(robe[0] - 1, b.foot - 1, robe[1] + 1, b.foot - 1, "E" if False else "l")
    c.rect(robe[0], b.hip - 1, robe[1], b.hip - 1, "V")


def sage_post(c, view, phase):
    if view == "front":
        c.put(12, 6, "L")                                             # a leaf on the staff


def golden_pre(c, view, phase):
    """A silvermoon elf: long silver hair, a circlet with a moon, a pale blue robe."""
    b = COMMON_BUILD
    hair(c, b, view, "S", long=True)
    x0, x1 = b.hx if view != "side" else b.sx
    c.rect(x0 + 1, b.y0, x1 - 1, b.y0, "Y")                          # the circlet
    robe = (6, 9) if view == "side" else (5, 10)
    c.rect(robe[0], b.shoulder, robe[1], 12, "P")
    c.rect(robe[0] - 1, 13, robe[1] + 1, 13, "W")


def golden_post(c, view, phase):
    b = COMMON_BUILD
    if view == "front":
        c.put(7, b.y0, "W")                                           # the moon on the circlet
        c.put(8, b.y0, "W")
    for x, y in ((1, 2), (14, 3), (0, 10), (15, 9)):
        c.put(x, y, "W")                                              # a shimmer about them


def fox_child_pre(level):
    """A child of an elf and the fox princess: 0 leans elf (a streak of red hair), 1 in between (red hair, little fox ears),
    2 leans fox: the strong one, who fights up close (fox ears, a fur vest, a tail)."""
    def pre(c, view, phase):
        b = CHILD_BUILDS[level]
        tunic(c, b, view, "b" if level < 2 else "V", "B" if level < 2 else "v")   # the strong one wears a fur-edged hide vest
        hair(c, b, view, "N" if level == 0 else "F")
        x0, x1 = b.hx if view != "side" else b.sx
        if level == 0:
            c.put(x0 + 2, b.y0, "F")
            c.put(x0 + 3, b.y0, "F")
            return
        # fox ears on top of the head
        for ex in ((x0 + 1, x1 - 1) if view != "side" else (x0 + 1,)):
            c.cells([(ex, b.y0 - 2), (ex, b.y0 - 1)], "F")
        if level == 2:
            if view == "front":
                c.cells([(b.tx[1] + 2, b.hip), (b.tx[1] + 3, b.hip + 1), (b.tx[1] + 3, b.hip + 2)], "F")   # the tail, peeking out
                c.put(b.tx[1] + 3, b.hip + 3, "X")
            elif view == "back":
                c.rect(7, b.hip + 1, 8, b.foot - 1, "F")
                c.cells([(7, b.foot - 1), (8, b.foot - 1)], "X")
            else:
                c.cells([(b.stx[0] - 1, b.hip), (b.stx[0] - 2, b.hip + 1), (b.stx[0] - 3, b.hip + 2)], "F")
                c.put(b.stx[0] - 3, b.hip + 3, "X")
    return pre


COMMON_BUILD = mg.Build(head=(3, 8), head_w=8, chest=5, hip=11, ear="long")
SCOUT_BUILD = mg.Build(head=(3, 8), head_w=6, chest=4, hip=11, leg=1, ear="long")
BRUTE_BUILD = mg.Build(head=(3, 7), head_w=6, chest=8, hip=11, leg=2, arm=2, ear="long")
SAGE_BUILD = mg.Build(head=(3, 8), chest=6, hip=12, ear="long")
CHILD_BUILDS = [mg.Build(head=(3, 8), head_w=8, chest=5, hip=11, ear="long"),
                mg.Build(head=(3, 8), head_w=8, chest=5, hip=11, ear="stub"),
                mg.Build(head=(3, 8), head_w=8, chest=7, hip=11, arm=2, ear="stub")]

BREEDS = [
    # id, name, weight, boost, blurb, stats, sheet, look
    ("common", "林民", 100, 0, "住在森林裡的精靈，會採集、會射箭，活得比哥布林久得多。",
     {"lifespan": 2.0, "might": 1.3, "health": 3.5}, "worker.png",
     look(build=COMMON_BUILD, pre=common_pre)),
    ("scout", "遊俠", 10, 1.0, "披著綠斗篷的弓手，腳步輕、眼睛利，遠遠就看得到獵物。",
     {"speed": 1.3, "sense": 1.4, "rest": 0.8, "lifespan": 1.8, "might": 1.2, "health": 2.5}, "scout.png",
     look(build=SCOUT_BUILD, pre=scout_pre)),
    ("brute", "樹衛", 8, 1.0, "穿著樹皮盔甲的守衛，走得慢，一次搬兩份，站在最前面。",
     {"speed": 0.8, "sense": 0.9, "carry": 2, "rest": 1.2, "lifespan": 2.5, "might": 1.8, "health": 6}, "brute.png",
     look({"g": (236, 210, 184), "G": (208, 176, 148)}, build=BRUTE_BUILD, pre=brute_pre)),
    ("sage", "德魯伊", 5, 1.5, "頂著小鹿角的德魯伊，懂得草藥，也很會叫同伴來幫忙。",
     {"speed": 0.95, "sense": 1.3, "recruit": 3, "lifespan": 2.3, "might": 1.0}, "sage.png",
     look({"S": (178, 186, 170)}, build=SAGE_BUILD, hair="S", pre=sage_pre, post=sage_post)),
    ("golden", "銀月精靈", 1, 3.0, "罕見的銀月精靈，銀髮上戴著月亮頭環，每一方面都好一點。",
     {"speed": 1.1, "sense": 1.2, "recruit": 1, "rest": 0.9, "lifespan": 4.0, "might": 1.5, "health": 5}, "golden.png",
     look({"g": (250, 236, 222), "G": (226, 206, 190), "S": (170, 186, 222)}, build=COMMON_BUILD, hair="S",
          pre=golden_pre, post=golden_post)),
    # The children of a silvermoon elf and the fox princess. Never born by chance: weight 0.
    ("half_gob", "獸血・偏精靈", 0, 0, "銀月精靈與狐族公主的孩子，偏向精靈：一撮紅髮，箭射得更準。",
     {"speed": 1.05, "sense": 1.3, "lifespan": 2.8, "might": 1.4, "health": 4, "recruit": 1}, "half_gob.png",
     look(build=CHILD_BUILDS[0], pre=fox_child_pre(0))),
    ("half_mix", "獸血・各半", 0, 0, "銀月精靈與狐族公主的孩子，精靈與狐族各半：紅髮、一對小狐耳，什麼都好一點。",
     {"speed": 1.1, "sense": 1.25, "lifespan": 3.0, "might": 1.5, "health": 4.5, "recruit": 1}, "half_mix.png",
     look({"g": (244, 216, 186)}, build=CHILD_BUILDS[1], pre=fox_child_pre(1))),
    ("half_hum", "獸血・偏獸", 0, 0, "銀月精靈與狐族公主的孩子，偏向狐族：狐耳、狐尾、毛皮背心。力氣大又耐打，是近戰的精靈。",
     {"speed": 1.05, "sense": 1.1, "carry": 2, "lifespan": 3.0, "might": 2.0, "health": 7}, "half_hum.png",
     look({"g": (240, 206, 170), "G": (214, 176, 140)}, build=CHILD_BUILDS[2], pre=fox_child_pre(2))),
]


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
    c = mg.Canvas()
    for y, (x0, x1) in {3: (6, 9), 4: (5, 10), 5: (4, 11), 6: (4, 11), 7: (4, 11), 8: (4, 11), 9: (4, 11), 10: (4, 11),
                        11: (5, 10), 12: (6, 9)}.items():
        c.rect(x0, y, x1, y, "g")
    ear = [(1, 1), (1, 2), (2, 2), (2, 3), (3, 3), (3, 4), (3, 5)]
    c.cells(ear + mg.mirror(ear), "g")
    c.rect(5, 2, 10, 2, "N")
    c.rect(4, 3, 11, 4, "N")
    c.cells([(4, 5), (11, 5)], "N")
    c.outline()
    c.cells([(2, 3), (13, 3)], "r")
    c.cells([(5, 7), (10, 7)], "y")
    c.cells([(6, 7), (9, 7)], "e")
    c.cells([(5, 6), (6, 6), (9, 6), (10, 6)], "O")                   # lashes
    c.cells([(7, 10), (8, 10)], "k")
    c.cells([(5, 9), (10, 9)], "r")                                   # blush
    return [[(ELF[c.px[y][x]] + (255,)) if c.px[y][x] else (0, 0, 0, 0) for x in range(SIZE)] for y in range(SIZE)]


def preview(path, zoom=8):
    """Contact sheet: every breed (front, back, side x2 phases) then every outfit of the princess, plus a row of her poses."""
    sheets = [mg.build_sheet(False, b[7]) for b in BREEDS] + [princess_sheet(o) for o in OUTFITS]
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
    for _id, _name, _w, _b, _blurb, _stats, sheet, lk in BREEDS:
        mg.write_png(os.path.join(root, sheet), mg.build_sheet(False, lk))
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
        },
        "worker": {"sheet": "worker.png", "pixelScale": 1.5, "walk": walk},
        "breeds": [{"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet}
                   for i, n, w, b, blurb, stats, sheet, _ in BREEDS],
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
