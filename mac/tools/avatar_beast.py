"""The beastfolk's guild avatars (獸人, RACES_BEAST.md §7: 「頭像要有獸人的身體、頭髮（耳朵、尾巴）和衣服」).

Wolf-folk on the avatars' 24-wide rig (make_avatars_preview.py draws the approved bodies with these, make_avatars.py cuts
them into layers): pointed ears on top of the head, a light muzzle with a dark nose, a bushy tail, fur pauldrons and a bone
necklace over hide clothes. Rugged, not cute: the fur is recoloured like a skin (KEY_SKIN: shade, fur, the light muzzle),
the mane like hair. Every style below is `fn(view, layer, c, y)` like make_avatars.STYLE (y: the head's base row; the head
spans rows y + 3 … y + 14, x 6 … 17; side views face right).

Keys used: s S x fur (base, shade, light), H J h mane, r inner ear, n nose; in the hair layers W w bone, d dark, E war paint,
G scar, V hide band, k cord, a white.
"""

# --- body parts ----------------------------------------------------------------------------------------------------------
EAR_L = [(6, -2), (6, -1), (7, -1), (6, 0), (7, 0), (8, 0), (6, 1), (7, 1), (8, 1), (9, 1), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2)]
EAR_IN = [(7, 0), (7, 1), (8, 1)]
EAR_SIDE = [(9, -2), (9, -1), (10, -1), (9, 0), (10, 0), (11, 0), (8, 1), (9, 1), (10, 1), (11, 1), (8, 2), (9, 2), (10, 2), (11, 2), (12, 2)]
EAR_SIDE_IN = [(10, 0), (10, 1), (11, 1)]


def ear_points(view, y):
    if view == "side":
        return [(x, y + r) for x, r in EAR_SIDE]
    return [(x, y + r) for x, r in EAR_L] + [(23 - x, y + r) for x, r in EAR_L]


def ears(c, view, y):
    """Two pointed wolf ears on top of the head (one from the side), dark inside; seen from behind, the fur's shade."""
    if view == "side":
        c.cells([(x, y + r) for x, r in EAR_SIDE], "s")
        c.cells([(x, y + r) for x, r in EAR_SIDE_IN], "x")
        c.cells([(11, y + 2), (8, y + 2)], "S")
        return
    c.cells([(x, y + r) for x, r in EAR_L], "s")
    c.cells([(23 - x, y + r) for x, r in EAR_L], "s")
    if view == "front":
        c.cells([(x, y + r) for x, r in EAR_IN] + [(23 - x, y + r) for x, r in EAR_IN], "x")   # pale fur inside
        c.cells([(8, y + 2), (15, y + 2)], "r")
        c.cells([(17, y - 2), (17, y - 1), (17, y + 0), (17, y + 1)], "S")
    else:
        c.cells([(17, y - 1), (16, y + 0), (16, y + 1), (6, y - 1), (7, y + 0)], "S")


def muzzle(c, view, y):
    """The light muzzle and the dark nose (front), or the snout sticking out (side, facing right)."""
    if view == "front":
        c.rect(10, y + 10, 13, y + 10, "x"); c.rect(9, y + 11, 14, y + 12, "x"); c.rect(10, y + 13, 13, y + 13, "x")
        c.cells([(11, y + 10), (12, y + 10)], "n")
    elif view == "side":
        c.rect(16, y + 10, 19, y + 10, "x"); c.rect(16, y + 11, 19, y + 11, "x"); c.rect(16, y + 12, 18, y + 12, "x")
        c.put(17, y + 13, "x")
        c.cells([(19, y + 9), (20, y + 10), (19, y + 10)], "n")


def fang(c, view, y):
    """「嘴閉著露一顆牙」: one fang over the lip."""
    if view == "front":
        c.put(13, y + 13, "t")
    elif view == "side":
        c.put(18, y + 13, "t")


TAIL = {   # rows (relative to the body's base row oy) -> (x0, x1); the last rows are the light tip
    "front": [(15, 19, 20), (16, 18, 21), (17, 18, 21), (18, 18, 21), (19, 17, 20), (20, 17, 19), (21, 16, 18)],
    "side": [(16, 2, 4), (17, 2, 5), (18, 3, 6), (19, 4, 7), (20, 5, 8), (21, 6, 8)],
    "back": [(19, 11, 12), (20, 10, 13), (21, 10, 13), (22, 10, 13), (23, 10, 13), (24, 11, 12)],
    "sit_side": [(21, 4, 8), (22, 2, 8), (23, 3, 7)],
}
TIP = {"front": 2, "side": 2, "back": 2, "sit_side": 0}


def tail(c, view, oy, phase=0, sit=False):
    """The bushy tail: up behind the right hip (front), out behind (side), hanging over the clothes (back)."""
    key = "sit_side" if (sit and view == "side") else view
    rows = TAIL[key]
    dy = 2 if (sit and view == "front") else 0
    wag = {1: -1, 3: 1}.get(phase, 0) if view == "back" else 0
    for i, (r, x0, x1) in enumerate(rows):
        yy = oy + r + dy
        c.rect(x0 + wag, yy, x1 + wag, yy, "s")
        if view == "front":
            c.put(x1 + wag, yy, "S")
        elif view == "back":
            c.put(x1 + wag, yy, "S")
    if key == "sit_side":
        c.cells([(2, oy + 22), (3, oy + 22), (3, oy + 23)], "x")
        c.rect(4, oy + 23, 7, oy + 23, "S")
        return
    tip = TIP[key]
    if view == "back":
        for r, x0, x1 in rows[-tip:]:
            c.rect(x0 + wag, oy + r, x1 + wag, oy + r, "x")
    else:
        for r, x0, x1 in rows[:tip]:
            c.rect(x0, oy + r + dy, x1, oy + r + dy, "x")
        if view == "side":
            for r, x0, x1 in rows[2:]:
                c.put(x0, oy + r, "S")


def pelt(c, a, view, u):
    """Fur pauldrons on the shoulders (F, f) and a bone necklace (u bone, k cord) over the default hide clothes."""
    if view == "side":
        c.rect(10, u + 15, 13, u + 16, "F"); c.cells([(11, u + 14), (12, u + 14)], "F")
        c.cells([(10, u + 17), (12, u + 17), (13, u + 16)], "f")
        return
    for side in (0, 1):
        pts = [(5, 15), (6, 15), (7, 15), (8, 15), (5, 16), (6, 16), (7, 16), (6, 14), (7, 14)]
        shade = [(5, 17), (7, 17), (8, 16)]
        if side:
            pts = [(23 - x, y) for x, y in pts]
            shade = [(23 - x, y) for x, y in shade]
        c.cells([(x, u + y) for x, y in pts], "F")
        c.cells([(x, u + y) for x, y in shade], "f")
    if view == "front":
        c.cells([(9, u + 15), (10, u + 16), (13, u + 16), (14, u + 15)], "k")
        c.cells([(11, u + 16), (12, u + 16)], "u")                     # two fangs on the cord
        c.cells([(11, u + 17), (12, u + 17)], "u")


# --- hair ------------------------------------------------------------------------------------------------------------------
def _put(c, pts, k):
    c.cells(pts, k)


def tuft(c, y, big=False):
    """The fur on the forehead between the ears, a little ragged."""
    c.cells([(11, y + 1), (12, y + 0), (13, y + 1)] if big else [(11, y + 1), (12, y + 1)], "H")
    c.rect(10, y + 2, 13, y + 2, "H"); c.rect(8, y + 3, 15, y + 3, "H"); c.rect(7, y + 4, 16, y + 4, "H")
    c.cells([(7, y + 5), (8, y + 5), (10, y + 5), (11, y + 5), (13, y + 5), (15, y + 5), (16, y + 5), (8, y + 6), (11, y + 6), (15, y + 6)], "H")
    c.cells([(9, y + 3), (10, y + 3), (11, y + 2)], "h")
    c.cells([(12, y + 4), (14, y + 4), (16, y + 5)], "J")


def tuft_side(c, y, back_to=9):
    c.cells([(12, y + 1), (13, y + 2), (11, y + 1)], "H")
    c.rect(8, y + 3, 16, y + 3, "H"); c.rect(10, y + 2, 14, y + 2, "H"); c.rect(6, y + 4, 16, y + 4, "H")
    c.rect(6, y + 5, 10, y + back_to, "H"); c.cells([(15, y + 5), (16, y + 5), (13, y + 5), (16, y + 6)], "H")
    c.rect(6, y + back_to, 9, y + back_to, "J")
    c.cells([(11, y + 2), (10, y + 3), (8, y + 4)], "h")


def back_head(c, y, bottom=12):
    """The back of the head covered in mane."""
    c.rect(9, y + 2, 14, y + 2, "H"); c.rect(7, y + 3, 16, y + 3, "H"); c.rect(6, y + 4, 17, y + bottom, "H")
    c.cells([(9, y + 3), (10, y + 3), (8, y + 4), (8, y + 5)], "h")
    c.rect(6, y + bottom, 17, y + bottom, "J")


def jagged(c, y_bottom, x0, x1, k="J", step=2):
    """A ragged lower edge: every other column a pixel longer."""
    for x in range(x0, x1 + 1):
        if (x - x0) % step == 0:
            c.put(x, y_bottom + 1, k)


def mane_front_back(c, y, bottom=16, wide=0):
    """The mane behind the head, seen from the front: framing the face down past the chin."""
    for r in range(4, bottom + 1):
        x0 = 4 - wide if r >= 7 else 5
        x1 = 19 + wide if r >= 7 else 18
        if r >= bottom - 2:
            x0 += 1; x1 -= 1
        c.rect(x0, y + r, x1, y + r, "H")
    c.rect(4 - wide, y + 8, 4 - wide, y + bottom - 2, "J"); c.rect(19 + wide, y + 6, 19 + wide, y + bottom - 2, "J")
    for x in range(5 - wide, 19 + wide, 2):
        c.put(x, y + bottom + 1, "J")
    c.cells([(5, y + 6), (5, y + 7), (6, y + 5)], "h")


def mane_side_back(c, y, bottom=16):
    for r in range(4, bottom + 1):
        x0 = 3 if r >= 7 else 5
        c.rect(x0, y + r, 9, y + r, "H")
    c.rect(3, y + 7, 3, y + bottom, "J"); c.rect(4, y + bottom, 9, y + bottom, "J")
    for x in (4, 6, 8):
        c.put(x, y + bottom + 1, "J")
    c.cells([(5, y + 5), (4, y + 7)], "h")


def mane_back(c, y, bottom=16):
    back_head(c, y, 13)
    for r in range(13, bottom + 1):
        x0, x1 = (5, 18) if r < bottom - 1 else (6, 17)
        c.rect(x0, y + r, x1, y + r, "H")
    c.rect(5, y + 8, 5, y + bottom - 2, "H"); c.rect(18, y + 8, 18, y + bottom - 2, "H")
    for x in range(6, 18, 2):
        c.put(x, y + bottom + 1, "J")
    c.rect(9, y + 13, 9, y + bottom - 1, "J"); c.rect(14, y + 13, 14, y + bottom - 1, "J")
    c.rect(6, y + bottom, 17, y + bottom, "J")


def mane(view, layer, c, y, bottom=14, wide=0):
    if view == "front":
        if layer == "back":
            mane_front_back(c, y, bottom, wide)
        else:
            tuft(c, y, big=True)
    elif view == "side":
        if layer == "back":
            mane_side_back(c, y, bottom)
        else:
            tuft_side(c, y)
    elif layer == "front":
        mane_back(c, y, bottom)


def long_mane(view, layer, c, y):
    mane(view, layer, c, y, bottom=21)
    if layer == "back" and view == "front":
        c.rect(6, y + 15, 6, y + 20, "J"); c.rect(17, y + 15, 17, y + 20, "J")
    if view == "back" and layer == "front":
        c.rect(11, y + 14, 11, y + 20, "J")


def wild_mane(view, layer, c, y):
    mane(view, layer, c, y, bottom=15, wide=1)
    if view == "front":
        if layer == "back":
            c.cells([(2, y + 7), (2, y + 11), (21, y + 8), (21, y + 12), (3, y + 15), (20, y + 15), (4, y + 4), (19, y + 4)], "H")
        else:
            c.cells([(9, y + 1), (14, y + 1), (12, y - 1), (10, y + 0), (13, y + 0)], "H"); c.put(12, y - 1, "h")
    elif view == "side":
        if layer == "back":
            c.cells([(1, y + 9), (1, y + 13), (2, y + 6), (2, y + 16)], "H")
        else:
            c.cells([(10, y + 0), (12, y - 1), (13, y + 0), (8, y + 1)], "H")
    elif layer == "front":
        c.cells([(4, y + 7), (4, y + 11), (19, y + 8), (19, y + 12), (12, y + 0), (10, y + 1), (14, y + 1)], "H")


def crest(view, layer, c, y):
    """A stiff crest of mane from the brow to the nape, the sides cropped close."""
    if layer != "front":
        return
    if view == "front":
        c.rect(10, y - 2, 13, y + 4, "H"); c.cells([(10, y - 3), (12, y - 3), (11, y - 2)], "H")
        c.rect(13, y - 1, 13, y + 4, "J"); c.cells([(10, y - 1), (10, y + 0), (11, y - 2)], "h")
        c.cells([(11, y + 5), (12, y + 5)], "H")
    elif view == "side":
        for x, top in ((6, 6), (7, 3), (8, 1), (9, -1), (10, -2), (11, -3), (12, -2), (13, -1), (14, 0), (15, 2)):
            c.rect(x, y + top, x, y + top + 2, "H")
        c.cells([(9, y - 1), (11, y - 3), (8, y + 1)], "h")
        c.rect(5, y + 7, 6, y + 12, "H"); c.cells([(5, y + 12), (6, y + 12)], "J")
    else:
        c.rect(10, y - 2, 13, y + 13, "H"); c.rect(13, y - 1, 13, y + 13, "J"); c.cells([(10, y - 1), (10, y + 1)], "h")
        c.cells([(11, y - 3), (13, y - 3)], "H")


def shaggy_fur(view, layer, c, y):
    """Short shaggy fur all over the crown and a small ruff at the cheeks."""
    if view == "front":
        if layer == "back":
            c.cells([(5, y + 12), (5, y + 13), (18, y + 12), (18, y + 13), (4, y + 13), (19, y + 13), (6, y + 14), (17, y + 14)], "H")
            c.cells([(4, y + 13), (19, y + 13)], "J")
        else:
            tuft(c, y)
            c.cells([(6, y + 4), (6, y + 5), (6, y + 6), (17, y + 4), (17, y + 5), (17, y + 6), (5, y + 6), (18, y + 6), (9, y + 6), (13, y + 6), (12, y + 5)], "H")
            c.cells([(6, y + 7), (17, y + 7)], "J")
    elif view == "side":
        if layer == "back":
            c.cells([(5, y + 12), (4, y + 13), (5, y + 13), (5, y + 14)], "H")
        else:
            tuft_side(c, y, 11)
            c.cells([(5, y + 6), (5, y + 8), (5, y + 10), (14, y + 2)], "H")
    elif layer == "front":
        back_head(c, y, 12)
        c.cells([(5, y + 6), (5, y + 9), (18, y + 7), (18, y + 10), (7, y + 13), (10, y + 13), (13, y + 13), (16, y + 13)], "H")


def war_paint(view, layer, c, y):
    """A ruffled tuft, and red war paint: three claw marks down each cheek and a stripe down the brow."""
    shaggy_fur(view, layer, c, y)
    if layer != "front":
        return
    if view == "front":
        for x0 in (6, 15):
            c.cells([(x0, y + 10), (x0 + 1, y + 11), (x0 + 2, y + 12)] if x0 == 6 else [(x0 + 2, y + 10), (x0 + 1, y + 11), (x0, y + 12)], "E")
            c.cells([(x0, y + 12), (x0 + 1, y + 13)] if x0 == 6 else [(x0 + 2, y + 12), (x0 + 1, y + 13)], "E")
        c.cells([(11, y + 6), (12, y + 6), (11, y + 7), (12, y + 7)], "E")
    elif view == "side":
        c.cells([(12, y + 10), (13, y + 11), (14, y + 12), (11, y + 12), (12, y + 13)], "E")
        c.cells([(16, y + 6), (16, y + 7)], "E")


def scar_paint(view, layer, c, y):
    """A shaggy mane, an old scar down over the left eye, and white paint dots on the cheeks."""
    mane(view, layer, c, y, bottom=14)
    if layer != "front":
        return
    if view == "front":
        c.cells([(9, y + 6), (9, y + 7), (8, y + 8), (8, y + 9), (8, y + 10), (7, y + 11)], "G")
        c.cells([(16, y + 11), (15, y + 12), (17, y + 12)], "a")
    elif view == "side":
        c.cells([(12, y + 11), (11, y + 12), (13, y + 12)], "a")


def horns(c, view, y):
    if view == "side":
        c.cells([(9, y + 4), (10, y + 4), (10, y + 3), (11, y + 3), (11, y + 2), (12, y + 2), (12, y + 1), (13, y + 1), (13, y + 0)], "W")
        c.cells([(10, y + 4), (11, y + 3), (12, y + 2)], "w"); c.put(14, y - 1, "w")
        return
    for side in (0, 1):
        pts = [(6, y + 5), (5, y + 5), (5, y + 4), (4, y + 4), (4, y + 3), (3, y + 3), (3, y + 2), (3, y + 1), (4, y + 0)]
        shade = [(5, y + 5), (4, y + 4), (3, y + 3)]
        tip = [(4, y - 1)]
        if side:
            pts, shade, tip = ([(23 - x, yy) for x, yy in p] for p in (pts, shade, tip))
        c.cells(pts, "W"); c.cells(shade, "w"); c.cells(tip, "w")


def bull_horns(view, layer, c, y):
    """A short ragged mane and a pair of horns curving up from the sides of the head (the bulls' blood)."""
    shaggy_fur(view, layer, c, y)
    if layer == "front":
        horns(c, view, y)


def skull_cap(view, layer, c, y):
    """The skull of a great wolf worn as a helm, its pelt hanging down behind."""
    if view == "front":
        if layer == "back":
            mane_front_back(c, y, 15)
            return
        c.rect(8, y + 0, 15, y + 0, "W"); c.rect(7, y + 1, 16, y + 4, "W"); c.rect(6, y + 3, 17, y + 5, "W")
        c.cells([(6, y - 1), (7, y - 1), (6, y + 0), (17, y - 1), (16, y - 1), (17, y + 0), (7, y + 0), (16, y + 0)], "W")
        c.cells([(8, y + 3), (9, y + 3), (14, y + 3), (15, y + 3), (9, y + 4), (14, y + 4)], "d")       # eye holes
        c.rect(10, y + 4, 13, y + 6, "W"); c.cells([(11, y + 6), (12, y + 6)], "d")                       # the snout, its nose
        c.cells([(10, y + 7), (13, y + 7)], "W")                                                          # fangs
        c.cells([(16, y + 1), (16, y + 2), (17, y + 3), (17, y + 4), (13, y + 5)], "w")
        c.cells([(6, y + 6), (6, y + 7), (17, y + 6), (17, y + 7), (5, y + 6), (18, y + 6)], "H")        # pelt at the sides
    elif view == "side":
        if layer == "back":
            mane_side_back(c, y, 15)
            return
        c.rect(7, y + 0, 14, y + 0, "W"); c.rect(6, y + 1, 16, y + 4, "W"); c.rect(14, y + 3, 19, y + 5, "W")
        c.cells([(8, y - 1), (9, y - 2), (9, y - 1)], "W")
        c.cells([(13, y + 2), (14, y + 2)], "d"); c.put(20, y + 4, "d")
        c.cells([(15, y + 6), (18, y + 6)], "W")
        c.rect(6, y + 5, 7, y + 9, "H"); c.cells([(6, y + 1), (6, y + 2), (7, y + 4), (14, y + 5), (19, y + 5)], "w")
    elif layer == "front":
        mane_back(c, y, 15)
        c.rect(8, y + 0, 15, y + 0, "W"); c.rect(7, y + 1, 16, y + 4, "W"); c.rect(6, y + 3, 17, y + 4, "w")
        c.cells([(6, y - 1), (7, y - 1), (6, y + 0), (17, y - 1), (16, y - 1), (17, y + 0)], "W")


def bone_crown(view, layer, c, y):
    """A ruff of mane under a band of fangs and small bones standing up round the head."""
    shaggy_fur(view, layer, c, y)
    if layer != "front":
        return
    if view == "side":
        c.rect(6, y + 4, 16, y + 4, "k")
        for x in (7, 10, 13, 16):
            c.cells([(x, y + 2), (x, y + 3)], "W"); c.put(x, y + 1, "w")
        return
    c.rect(6, y + 4, 17, y + 4, "k")
    for i, x in enumerate((7, 9, 11, 12, 14, 16)):
        h = 3 if x in (11, 12) else 2
        c.rect(x, y + 4 - h, x, y + 3, "W"); c.put(x, y + 4 - h - (1 if x in (11, 12) else 0), "w")


def feathers(view, layer, c, y):
    """The mane with two eagle feathers tied in behind the right ear."""
    mane(view, layer, c, y, bottom=15)
    if layer != "front":
        return
    fx = [(18, 0), (19, -1), (19, -2), (20, -3), (20, -4)] if view != "side" else [(6, 1), (5, 0), (5, -1), (4, -2), (4, -3)]
    gx = [(17, -1), (17, -2), (17, -3), (18, -4)] if view != "side" else [(7, 0), (7, -1), (7, -2), (6, -3)]
    if view == "back":
        fx = [(23 - x, r) for x, r in fx]; gx = [(23 - x, r) for x, r in gx]
    for pts in (fx, gx):
        c.cells([(x, y + r) for x, r in pts], "W")
        x, r = pts[-1]
        c.put(x, y + r, "d")
        x, r = pts[0]
        c.put(x, y + r + 1, "k")


def topknot(view, layer, c, y):
    """The mane gathered in a knot on the crown, a bone pin through it."""
    if layer != "front":
        return
    if view == "front":
        tuft(c, y)
        c.rect(10, y - 2, 13, y + 1, "H"); c.rect(11, y - 3, 12, y - 3, "H"); c.cells([(10, y - 2), (11, y - 3)], "h")
        c.rect(13, y - 2, 13, y + 1, "J")
        c.rect(8, y - 1, 15, y - 1, "W"); c.put(15, y - 1, "w")
    elif view == "side":
        tuft_side(c, y)
        c.rect(8, y - 2, 11, y + 1, "H"); c.rect(9, y - 3, 10, y - 3, "H"); c.cells([(8, y - 2), (9, y - 3)], "h")
        c.rect(6, y - 1, 13, y - 1, "W")
    else:
        back_head(c, y, 11)
        c.rect(10, y - 2, 13, y + 1, "H"); c.rect(11, y - 3, 12, y - 3, "H"); c.rect(10, y - 2, 10, y + 1, "J")
        c.rect(8, y - 1, 15, y - 1, "W"); c.put(8, y - 1, "w")


def beaded_braid(c, x0, x1, y0, y1):
    for yy in range(y0, y1 + 1):
        c.rect(x0, yy, x1, yy, "H")
        c.put(x1 if (yy - y0) % 2 else x0, yy, "J")
    c.rect(x0, y0 + 4, x1, y0 + 4, "W")
    if y1 - y0 > 8:
        c.rect(x0, y1 - 1, x1, y1 - 1, "W")
    c.rect(x0, y1 + 1, x1, y1 + 1, "k")
    c.cells([(x0, y1 + 2)], "H")


def braided_mane(view, layer, c, y):
    """The mane, two braids strung with bone beads hanging in front of the shoulders."""
    mane(view, layer, c, y, bottom=14)
    if layer != "front":
        return
    if view == "front":
        beaded_braid(c, 5, 6, y + 9, y + 17); beaded_braid(c, 17, 18, y + 9, y + 17)
    elif view == "side":
        beaded_braid(c, 8, 9, y + 9, y + 17)
    else:
        beaded_braid(c, 6, 7, y + 13, y + 18); beaded_braid(c, 16, 17, y + 13, y + 18)


def bead_braids(view, layer, c, y):
    """A ragged fringe and two long braids with bone beads, falling from behind the ears to the chest."""
    if view == "front":
        if layer == "back":
            c.rect(4, y + 6, 6, y + 10, "H"); c.rect(17, y + 6, 19, y + 10, "H")
            return
        tuft(c, y)
        c.cells([(6, y + 5), (6, y + 6), (17, y + 5), (17, y + 6)], "H")
        beaded_braid(c, 4, 5, y + 8, y + 18); beaded_braid(c, 18, 19, y + 8, y + 18)
    elif view == "side":
        if layer == "back":
            beaded_braid(c, 5, 6, y + 9, y + 18)
            return
        tuft_side(c, y, 10)
    elif layer == "front":
        back_head(c, y, 12)
        beaded_braid(c, 5, 6, y + 10, y + 18); beaded_braid(c, 17, 18, y + 10, y + 18)


def high_tail(view, layer, c, y):
    """The mane pulled up into a high tail that falls down the back, tied with a bone ring."""
    if view == "front":
        if layer == "back":
            c.rect(16, y + 2, 18, y + 15, "H"); c.rect(18, y + 4, 18, y + 15, "J"); c.cells([(17, y + 16)], "J")
            return
        tuft(c, y)
        c.cells([(6, y + 5), (17, y + 5), (6, y + 6), (17, y + 6)], "H")
    elif view == "side":
        if layer == "back":
            c.rect(3, y + 4, 6, y + 6, "H"); c.rect(2, y + 7, 5, y + 15, "H"); c.rect(2, y + 7, 2, y + 15, "J")
            c.cells([(3, y + 16), (4, y + 16)], "J")
            return
        tuft_side(c, y, 9)
        c.cells([(6, y + 3), (6, y + 4), (7, y + 3)], "W")
    elif layer == "front":
        back_head(c, y, 12)
        c.rect(10, y + 1, 13, y + 2, "W")
        c.rect(10, y + 3, 13, y + 18, "H"); c.rect(13, y + 3, 13, y + 18, "J"); c.cells([(11, y + 19), (12, y + 19)], "J")
        c.cells([(10, y + 5), (10, y + 9)], "h")


def side_braid(view, layer, c, y):
    """Long mane, braided over the left shoulder with a bone bead and a cord."""
    if view == "front":
        if layer == "back":
            c.rect(17, y + 5, 19, y + 16, "H"); c.rect(19, y + 7, 19, y + 16, "J"); c.cells([(18, y + 17)], "J")
            return
        tuft(c, y)
        c.rect(5, y + 5, 7, y + 8, "H")
        beaded_braid(c, 5, 6, y + 9, y + 19)
    elif view == "side":
        if layer == "back":
            mane_side_back(c, y, 17)
            return
        tuft_side(c, y, 10)
    elif layer == "front":
        mane_back(c, y, 17)


def pigtails(view, layer, c, y):
    """Two bunches low at the sides, tied with bone rings."""
    if view == "front":
        if layer == "back":
            for x in (3, 19):
                c.rect(x, y + 10, x + 1, y + 18, "H"); c.rect(x + (1 if x > 10 else 0), y + 11, x + (1 if x > 10 else 0), y + 18, "J")
                c.rect(x, y + 9, x + 1, y + 9, "W")
            return
        tuft(c, y)
        c.cells([(6, y + 5), (6, y + 6), (17, y + 5), (17, y + 6), (5, y + 8), (18, y + 8)], "H")
    elif view == "side":
        if layer == "back":
            c.rect(4, y + 10, 5, y + 18, "H"); c.rect(4, y + 9, 5, y + 9, "W"); c.rect(4, y + 11, 4, y + 18, "J")
            return
        tuft_side(c, y, 10)
    elif layer == "front":
        back_head(c, y, 12)
        for x in (4, 18):
            c.rect(x, y + 10, x + 1, y + 18, "H"); c.rect(x, y + 9, x + 1, y + 9, "W")


def long_braid(view, layer, c, y):
    """One long braid down the back with bone beads."""
    if view == "front":
        if layer == "front":
            tuft(c, y)
            c.cells([(6, y + 5), (17, y + 5)], "H")
    elif view == "side":
        if layer == "back":
            beaded_braid(c, 4, 5, y + 9, y + 19)
        else:
            tuft_side(c, y, 10)
    elif layer == "front":
        back_head(c, y, 12)
        beaded_braid(c, 11, 12, y + 13, y + 21)


def headband(view, layer, c, y):
    """A shaggy mane under a hide headband painted with a red stripe."""
    mane(view, layer, c, y, bottom=13)
    if layer != "front":
        return
    if view == "side":
        c.rect(6, y + 4, 16, y + 4, "V"); c.rect(6, y + 5, 16, y + 5, "E")
        c.cells([(5, y + 5), (4, y + 6), (4, y + 7), (5, y + 7)], "V")
        return
    c.rect(6, y + 4, 17, y + 4, "V"); c.rect(6, y + 5, 17, y + 5, "E") if view == "front" else c.rect(6, y + 5, 17, y + 5, "V")
    if view == "back":
        c.cells([(11, y + 6), (12, y + 6), (10, y + 7), (13, y + 7), (10, y + 8), (13, y + 9)], "V")


STYLES = {
    "mane": mane, "long_mane": long_mane, "wild_mane": wild_mane, "crest": crest, "shaggy_fur": shaggy_fur,
    "war_paint": war_paint, "scar_paint": scar_paint, "bull_horns": bull_horns, "skull_cap": skull_cap,
    "bone_crown": bone_crown, "feathers": feathers, "topknot": topknot, "braided_mane": braided_mane,
    "bead_braids": bead_braids, "high_tail": high_tail, "side_braid": side_braid, "pigtails": pigtails,
    "long_braid": long_braid, "headband": headband,
}
# what each sex may pick (shared/src/guild.ts AVATAR_OPTIONS.beast must say the same); the first is the default
HAIRS = {
    "m": ["mane", "crest", "war_paint", "bull_horns", "wild_mane", "braided_mane", "long_mane", "topknot", "skull_cap",
          "bone_crown", "shaggy_fur", "scar_paint", "feathers", "headband"],
    "f": ["bead_braids", "long_mane", "high_tail", "war_paint", "side_braid", "feathers", "headband", "shaggy_fur",
          "skull_cap", "pigtails", "long_braid", "bull_horns", "mane", "scar_paint"],
}
NO_EARS = {"skull_cap"}           # a style that covers the ears (the others leave them showing over the hair)

# fur colours: shade, fur, the light muzzle (make_beast.py FUR, and two more)
FUR = {
    "wolf_grey": ((112, 114, 128), (150, 152, 164), (222, 222, 228)),
    "fox_red": ((184, 88, 36), (232, 128, 54), (252, 244, 232)),
    "silver_fur": ((138, 144, 166), (200, 204, 218), (250, 250, 252)),
    "bull_brown": ((104, 66, 40), (140, 92, 58), (214, 176, 132)),
    "snow_white": ((176, 182, 204), (238, 238, 246), (255, 255, 255)),
    "night_black": ((46, 44, 54), (72, 68, 80), (168, 164, 174)),
}
# fixed colours of the bodies (and their default clothes); the hair layers' extra keys
BODY = {"O": (46, 34, 30), "r": (96, 58, 56), "n": (34, 26, 26), "L": (40, 28, 26), "i": (226, 164, 52), "I": (166, 98, 30),
        "w": (255, 255, 240), "m": (92, 38, 38), "p": (222, 112, 122), "t": (252, 248, 236), "F": (214, 204, 186),
        "f": (158, 146, 128), "u": (240, 232, 210), "A": (236, 224, 196), "k": (88, 58, 36), "K": (186, 160, 120)}
PALS = {
    "bst_m": dict(BODY, T=(150, 104, 64), U=(112, 76, 46), P=(98, 72, 50), Q=(74, 54, 38)),
    "bst_f": dict(BODY, T=(176, 122, 76), U=(134, 88, 52), P=(176, 122, 76), Q=(134, 88, 52), k=(150, 52, 44)),
}
HAIR_KEYS = {"E": (182, 52, 44), "G": (206, 132, 124), "V": (150, 104, 64)}
