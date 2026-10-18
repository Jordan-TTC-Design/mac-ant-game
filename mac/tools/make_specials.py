#!/usr/bin/env python3
"""The special residents (2026-10-17, the camp × race level plan): six roles for every race, each unlocked at a race level and
only ever arriving as a visitor who asks to move in. They are drawn on the race's own plain body (make_goblin / make_elf /
make_undead / make_beast) with the role's gear laid over it, plus a twinkle round them so they stand out from the common breeds:

    healer       a staff with a glowing orb, a crown of herbs
    champion     a sword and a shield, a cape
    artisan      a hammer, a leather apron, a headband
    beastmaster  a coiled whip and a little pet at their feet
    bard         a drum (goblins, beastfolk) or a lute
    sentinel     a spear and a helmet

The race generators call `special_breeds(race)` and write the sheets and the manifest entries with their own breeds.
    python3 tools/make_specials.py --preview /path/preview.png   # a contact sheet of all twenty-four next to the common ones
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_goblin as mg  # noqa: E402

SIZE = mg.SIZE

# The gear's colours (keys of their own, so they never clash with a race's palette).
GEAR = {
    "i_wood": (176, 122, 66), "i_wood2": (126, 84, 44),
    "i_steel": (206, 214, 224), "i_steel2": (138, 148, 162),
    "i_gold": (244, 200, 72), "i_gold2": (196, 148, 40),
    "i_red": (196, 50, 56), "i_red2": (140, 30, 40),
    "i_green": (120, 220, 120), "i_glow": (200, 255, 200),
    "i_leather": (150, 96, 56), "i_leather2": (112, 70, 40),
    "i_white": (246, 242, 230),
    "i_blue": (70, 110, 190), "i_blue2": (48, 78, 150),
    "i_spark": (255, 244, 170),
}

ROLES = ["healer", "champion", "artisan", "beastmaster", "bard", "sentinel"]

# id → (name per race, blurb per race, stats per race); stats follow each race's own scale (elves live twice as long,
# the undead never age).
NAMES = {
    "goblin": {"healer": "巫醫", "champion": "勇者", "artisan": "工匠", "beastmaster": "馴獸師", "bard": "鼓手", "sentinel": "哨兵"},
    "elf": {"healer": "德魯伊", "champion": "遊俠隊長", "artisan": "月工匠", "beastmaster": "馴鹿人", "bard": "吟遊詩人", "sentinel": "守林人"},
    "undead": {"healer": "死靈醫者", "champion": "骷髏騎士", "artisan": "骨匠", "beastmaster": "亡獸師", "bard": "哀歌者", "sentinel": "守墓人"},
    "beast": {"healer": "薩滿", "champion": "狼騎士", "artisan": "骨雕匠", "beastmaster": "馴獸人", "bard": "鼓手", "sentinel": "守崖人"},
}
WHAT = {
    "healer": "拄著發光的法杖，附近的同伴傷好得快。",
    "champion": "提劍持盾、披著斗篷，突襲時站在最前面，大家的攻擊都強一點。",
    "artisan": "圍著皮圍裙、拿著鐵鎚，有他在，工地做得多一點。",
    "beastmaster": "腰上掛著鞭子，身邊跟著一隻小寵物，牧場的動物都聽他的。",
    "bard": "走到哪裡都在唱、在敲，營地熱熱鬧鬧，小孩生得快一點。",
    "sentinel": "戴著頭盔、扛著長矛守在營地邊，魔獸一靠近就被他戳一下。",
}
LEVEL = {"healer": 8, "champion": 10, "artisan": 12, "beastmaster": 14, "bard": 16, "sentinel": 20}
STATS = {
    "healer": {"speed": 1.0, "sense": 1.2, "rest": 0.9, "might": 1.0, "health": 4},
    "champion": {"speed": 1.05, "sense": 1.1, "rest": 0.9, "might": 2.0, "health": 7},
    "artisan": {"speed": 0.95, "carry": 2, "rest": 1.0, "might": 1.3, "health": 5},
    "beastmaster": {"speed": 1.1, "sense": 1.3, "rest": 0.9, "might": 1.3, "health": 4},
    "bard": {"speed": 1.05, "sense": 1.1, "recruit": 3, "might": 1.0, "health": 4},
    "sentinel": {"speed": 0.95, "sense": 1.5, "rest": 0.9, "might": 1.6, "health": 7},
}
# A special lives three times as long as the race's plain resident (the undead never age: their number is not used).
LIFESPAN = {"goblin": 3.0, "elf": 6.0, "undead": 50.0, "beast": 4.5}


# --- where the hands are, per race ------------------------------------------------------------------------------
# Front view: the columns of the left and right arms and the row of the hands; side view: the hand's column by walk phase.
HANDS = {
    "goblin": {"L": 4, "R": 11, "y": 11, "side": {0: 9, 1: 10, 2: 9, 3: 6}, "head": (2, 7), "chest": (5, 10), "hip": 11},
    "elf": {"L": 5, "R": 10, "y": 12, "side": {0: 8, 1: 9, 2: 8, 3: 6}, "head": (1, 8), "chest": (6, 9), "hip": 11},
    "undead": {"L": 4, "R": 11, "y": 11, "side": {0: 8, 1: 9, 2: 8, 3: 6}, "head": (1, 7), "chest": (5, 10), "hip": 12},
    "beast": {"L": 3, "R": 12, "y": 11, "side": {0: 9, 1: 10, 2: 9, 3: 8}, "head": (1, 6), "chest": (4, 11), "hip": 10},
}
DRUMMERS = ("goblin", "beast")                               # the bard drums; the others play a lute
SWING = {0: 0, 1: -1, 2: 0, 3: 1}


class Gear:
    """The gear of one frame, on two layers: in front of the body, and behind it (only where the body is not)."""

    def __init__(self):
        self.front, self.back, self.loose = mg.Canvas(), mg.Canvas(), []

    def onto(self, body):
        for layer, over in ((self.back, False), (self.front, True)):
            layer.outline()
            for y in range(SIZE):
                for x in range(SIZE):
                    key = layer.px[y][x]
                    if key is None:
                        continue
                    if body.px[y][x] is None or (over and key != "O"):
                        body.px[y][x] = key
        for x, y, key in self.loose:                         # twinkles: on the empty air only, no outline
            if 0 <= x < SIZE and 0 <= y < SIZE and body.px[y][x] is None:
                body.px[y][x] = key
        return body


def mirrored(canvas):
    out = mg.Canvas()
    for y in range(SIZE):
        for x in range(SIZE):
            out.px[y][SIZE - 1 - x] = canvas.px[y][x]
    return out


# --- the gear ---------------------------------------------------------------------------------------------------
def staff(c, x, y):
    c.rect(x, 3, x, 14, "i_wood")
    c.rect(x, 3, x, 4, "i_wood2")
    c.rect(x - 1, 1, x, 2, "i_green")
    c.put(x - 1, 1, "i_glow")


def spear(c, x, y):
    c.rect(x, 2, x, 14, "i_wood")
    c.put(x, 0, "i_steel")
    c.rect(x - 1, 1, x + 1, 1, "i_steel")
    c.put(x + 1, 1, "i_steel2")
    c.put(x, 3, "i_red")                                     # a tassel under the head


def sword(c, x, y):
    c.rect(x, y - 6, x, y - 2, "i_steel")
    c.put(x, y - 7, "i_steel2")
    c.rect(x - 1, y - 1, x + 1, y - 1, "i_gold")
    c.put(x, y, "i_wood2")


def shield(c, x, y):
    c.rect(x - 2, y - 4, x, y - 1, "i_red")
    c.rect(x - 2, y - 4, x, y - 4, "i_gold")
    c.put(x - 1, y - 2, "i_gold")
    c.put(x - 1, y - 1, "i_red2")


def hammer(c, x, y):
    c.rect(x, y - 3, x, y + 1, "i_wood")
    c.rect(x - 1, y - 5, x + 1, y - 4, "i_steel")
    c.put(x + 1, y - 4, "i_steel2")


def whip(c, x, y):
    c.cells([(x, y - 1), (x, y), (x + 1, y + 1), (x + 1, y + 2), (x, y + 3)], "i_leather2")
    c.put(x, y - 2, "i_wood")


def drum_sticks(c, x, y):
    c.cells([(x, y - 1), (x + 1, y - 2)], "i_wood")


def lute(c, x, y):
    c.rect(x - 1, y - 1, x + 1, y + 1, "i_wood")
    c.put(x, y, "i_wood2")                                   # the sound hole
    c.cells([(x + 1, y - 2), (x + 2, y - 3), (x + 2, y - 4)], "i_wood2")    # the neck


def pet(c, phase, kind):
    """A little pet at the feet, bottom left: a pup (goblins), a fawn (elves), a bone pup (the undead) or a wolf cub (beastfolk)."""
    body, shade = {"goblin": ("i_steel2", "i_wood2"), "elf": ("i_leather", "i_white"), "undead": ("i_white", "i_steel2"),
                   "beast": ("i_steel2", "i_white")}[kind]
    c.rect(0, 12, 2, 13, body)
    c.put(3, 11, body)
    c.put(3, 12, body)
    c.put(3, 10, shade)                                      # an ear
    c.cells([(0, 14), (2, 14)], shade)                       # feet
    c.put(-1 + (phase % 2), 11, shade) if phase % 2 else c.put(0, 11, shade)   # the tail wags


# --- one role on one race ---------------------------------------------------------------------------------------
def gear(race, role, view, phase):
    h = HANDS[race]
    g = Gear()
    r_dy, l_dy = -SWING[phase], SWING[phase]
    if view == "side":
        x = h["side"][phase] + 1
        held = {"healer": staff, "champion": sword, "artisan": hammer, "beastmaster": whip, "bard": lute if race not in DRUMMERS else drum_sticks,
                "sentinel": spear}[role]
        target = g.back if held in (staff, spear) else g.front                # long poles stand behind the head
        held(target, x, h["y"])
        if role == "bard" and race in DRUMMERS:
            g.front.rect(8, h["hip"] - 2, 10, h["hip"], "i_red")              # the drum, seen from the side
            g.front.rect(8, h["hip"] - 2, 10, h["hip"] - 2, "i_white")
        if role == "champion":
            g.back.rect(3, 8, 5, 13, "i_red")                                 # the cape, behind
        if role == "beastmaster":
            pet(g.back, phase, race)
    else:
        layer = mg.Canvas()                                                   # drawn as from the front, mirrored for the back
        held = {"healer": staff, "champion": sword, "artisan": hammer, "beastmaster": whip, "bard": lute if race not in DRUMMERS else drum_sticks,
                "sentinel": spear}[role]
        held(layer, h["R"] + (2 if held in (staff, spear) else 1), h["y"] + r_dy)   # (a pole a pixel clear of the arm, so it reads)
        if role == "champion":
            shield(layer, h["L"], h["y"] + l_dy)
        if role == "bard" and race in DRUMMERS:
            drum_sticks(layer, h["L"] - 2, h["y"] + l_dy)
        if view == "front":
            g.front = layer
            x0, x1 = h["chest"]
            if role == "artisan":                                             # the apron over the chest and the loins
                g.front.rect(x0 + 1, 9, x1 - 1, h["hip"] + 1, "i_leather")
                g.front.rect(x0 + 1, 9, x1 - 1, 9, "i_leather2")
            if role == "bard" and race in DRUMMERS:
                g.front.rect(x0 + 1, h["hip"] - 2, x1 - 1, h["hip"], "i_red")
                g.front.rect(x0 + 1, h["hip"] - 2, x1 - 1, h["hip"] - 2, "i_white")
            if role == "champion":
                g.back.cells([(x0 - 1, 9), (x1 + 1, 9), (x0 - 2, 10), (x1 + 2, 10), (x0 - 2, 11), (x1 + 2, 11),
                              (x0 - 2, 12), (x1 + 2, 12)], "i_red")           # the cape's edges either side
            g.front.put(x0 + 1, 10, "i_gold")                                 # a badge on the chest
        else:
            g.back = mirrored(layer)
            if role == "champion":
                x0, x1 = h["chest"]
                g.front.rect(x0 - 1, 9, x1 + 1, 13, "i_red")                  # the cape over the back
                g.front.rect(x0 - 1, 13, x1 + 1, 13, "i_red2")
        if role == "beastmaster":
            pet(g.front if view == "front" else g.back, phase, race)
    # on the head
    y0, y1 = h["head"]
    if role == "sentinel":                                                    # a helmet: a cap of steel, a crest
        g.front.rect(4 if view != "side" else 5, y0 - 1, 11 if view != "side" else 10, y0, "i_steel")
        g.front.rect(4 if view != "side" else 5, y0, 11 if view != "side" else 10, y0, "i_steel2")
        g.front.put(7 if view != "side" else 6, y0 - 2, "i_red")
    elif role == "healer":                                                    # herbs round the head
        for x in ((5, 7, 9, 11) if view != "side" else (5, 7, 9)):
            g.front.put(x, y0 - 1, "i_green")
    elif role == "artisan":                                                   # a headband
        g.front.rect(4 if view != "side" else 5, y0 + 2, 11 if view != "side" else 10, y0 + 2, "i_blue")
    # the twinkle that marks a special
    spots = [(1, 2), (14, 4)] if phase in (0, 2) else [(2, 1), (13, 3)]
    g.loose += [(x, y, "i_spark") for x, y in spots]
    return g


# --- the bodies -------------------------------------------------------------------------------------------------
GOBLIN_CLOTH = {"healer": ((70, 150, 140), (44, 110, 104)), "champion": ((176, 52, 56), (126, 34, 42)),
                "artisan": ((150, 96, 56), (100, 61, 26)), "beastmaster": ((128, 112, 96), (90, 76, 64)),
                "bard": ((226, 132, 48), (170, 92, 30)), "sentinel": ((60, 84, 140), (40, 58, 104))}
ELF_CLOTH = {"healer": ((110, 170, 90), (76, 128, 62)), "champion": ((60, 110, 70), (40, 80, 50)),
             "artisan": ((150, 160, 200), (110, 120, 168)), "beastmaster": ((150, 110, 70), (112, 80, 50)),
             "bard": ((200, 120, 170), (160, 84, 132)), "sentinel": ((80, 110, 90), (56, 80, 64))}
UNDEAD_CLOTH = {"healer": ((92, 80, 140), (66, 56, 108)), "champion": ((150, 40, 56), (110, 28, 44)),
                "artisan": ((110, 90, 70), (80, 64, 50)), "beastmaster": ((70, 110, 100), (50, 80, 74)),
                "bard": ((120, 100, 160), (90, 72, 128)), "sentinel": ((60, 64, 84), (40, 44, 60))}


def goblin_body(role):
    cloth, shade = GOBLIN_CLOTH[role]
    look = mg.Look({"b": cloth, "B": shade})
    draws = {"front": mg.goblin_front, "back": mg.goblin_back, "side": mg.goblin_side}
    return (lambda view, phase: draws[view](phase, look)), dict(look.palette)


def elf_body(role):
    import make_elf as me
    cloth, shade = ELF_CLOTH[role]
    pal = dict(me.ELF, c1=cloth, c2=shade)
    hair = {"healer": ("S", "s"), "champion": ("N", "n"), "artisan": ("M", "m"), "beastmaster": ("N", "n"), "bard": ("F", "f"),
            "sentinel": ("N", "n")}[role]
    return (lambda view, phase: me.elf(view, phase, hair=hair[0], hair_dark=hair[1], style="long" if role in ("healer", "bard") else "short",
                                       cloth="c1", shade="c2")), pal


def undead_body(role):
    import make_undead as mu
    cloth, shade = UNDEAD_CLOTH[role]
    pal = dict(mu.BASE, c1=cloth, c2=shade)

    def draw(view, phase):
        c = mu.skeleton(view, phase, big=role in ("champion", "sentinel"))
        x0, x1 = (6, 9) if view == "side" else (5, 10)                         # a tabard over the ribs, in the role's colour
        for y in range(9, 13):
            for x in range(x0, x1 + 1):
                if c.px[y][x] not in (None, "O"):
                    c.px[y][x] = "c1" if x < x1 else "c2"
        return c
    return draw, pal


BEAST_CLOTH = {"healer": ((150, 104, 64), (112, 76, 46)), "champion": ((178, 54, 48), (130, 36, 34)),
               "artisan": ((150, 104, 64), (112, 76, 46)), "beastmaster": ((120, 96, 70), (88, 70, 52)),
               "bard": ((200, 120, 60), (150, 86, 40)), "sentinel": ((96, 90, 84), (70, 64, 60))}


def beast_body(role):
    """The beastfolk's calm warrior body (make_beast): the old silver fox for the shaman, a red fox for the drummer, wolves
    for the rest (big for the wolf rider and the cliff guard)."""
    import make_beast as mb
    cloth, shade = BEAST_CLOTH[role]
    fur = {"healer": "silver", "bard": "fox"}.get(role, "wolf")
    pal = dict(mb.palette(fur), c1=cloth, c2=shade)
    fox = fur in ("silver", "fox")
    build = "big" if role in ("champion", "sentinel") else "lean" if fox else "norm"
    return (lambda view, phase: mb.warrior(view, phase, lambda c, v: mb.w_head(c, v, ears="fox" if fox else "wolf"), build=build,
                                           top="robe" if role == "healer" else "bare", cloth="c1",
                                           behind=mb.w_tail("fox" if fox else "wolf"))), pal


BODIES = {"goblin": goblin_body, "elf": elf_body, "undead": undead_body, "beast": beast_body}


def special_sheet(race, role):
    draw, pal = BODIES[race](role)
    pal = dict(pal, **GEAR)
    img = [[(0, 0, 0, 0)] * (4 * SIZE) for _ in range(3 * SIZE)]
    for r, view in enumerate(("front", "back", "side")):
        for phase in range(4):
            canvas = gear(race, role, view, phase).onto(draw(view, phase))
            for y in range(SIZE):
                for x in range(SIZE):
                    key = canvas.px[y][x]
                    if key is not None:
                        img[r * SIZE + y][phase * SIZE + x] = pal[key] + (255,)
    return img


def special_breeds(race):
    """The race's six specials, as (id, name, weight, boost, blurb, stats, sheet file, image, race level): never born by chance."""
    out = []
    for role in ROLES:
        stats = dict(STATS[role], lifespan=LIFESPAN[race])
        blurb = f"特殊居民（種族 {LEVEL[role]} 級）。{WHAT[role]}只會自己來營地拜訪、問能不能住下來，營地裡最多一位。"
        out.append((role, NAMES[race][role], 0, 2.0, blurb, stats, f"{role}.png", special_sheet(race, role), LEVEL[role]))
    return out


def manifest_entries(race):
    return [{"id": i, "name": n, "weight": w, "boost": b, "blurb": blurb, "stats": stats, "sheet": sheet, "special": True, "level": lv}
            for i, n, w, b, blurb, stats, sheet, _img, lv in special_breeds(race)]


def write(race, root):
    for _id, _n, _w, _b, _blurb, _stats, sheet, img, _lv in special_breeds(race):
        mg.write_png(os.path.join(root, sheet), img)


def preview(path, zoom=6):
    """Every race: its common resident, then the six specials, each front/back/side in phases 0 and 1."""
    import make_elf as me
    import make_undead as mu
    import make_beast as mb
    commons = {"goblin": mg.build_sheet(False, mg.BREEDS[0][7]), "elf": me.breed_sheet(me.BREEDS[0][7], me.BREEDS[0][8]),
               "undead": mu.breed_sheet(mu.BREEDS[0][7], mu.BREEDS[0][8]), "beast": mb.breed_sheet(mb.BREEDS[0][7], mb.BREEDS[0][8])}
    rows = []
    for race in ("goblin", "elf", "undead", "beast"):
        rows.append(commons[race])
        rows += [special_sheet(race, role) for role in ROLES]
    cols = 6
    w, h = cols * SIZE * zoom, len(rows) * SIZE * zoom
    bg = (110, 150, 96, 255)
    out = [[bg] * w for _ in range(h)]
    for r, sheet in enumerate(rows):
        col = 0
        for view in range(3):
            for phase in (0, 1):
                for y in range(SIZE):
                    for x in range(SIZE):
                        px = sheet[view * SIZE + y][phase * SIZE + x]
                        if px[3]:
                            for oy in range(zoom):
                                for ox in range(zoom):
                                    out[(r * SIZE + y) * zoom + oy][(col * SIZE + x) * zoom + ox] = px
                col += 1
    mg.write_png(path, out)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
