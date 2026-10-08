"""Shared bits for the guild's level-unlocked decorations (make_guild_decor_lv2.py … lv7.py): colours that cannot repaint the old pieces,
and a few shapes the pieces are made of."""
import make_guild_decor as gd
from make_guild_decor import P, R, circle, blob, flame, item, rug_base, table, box, pot, frame_border, shelf_books, crystal, plinth, seat_info, SEAT_UP  # noqa: F401


def add_colors(new):
    """Adds colours; a name that is already there must have the same value (else it would repaint pieces drawn before)."""
    for k, v in new.items():
        assert k not in P or P[k] == v, f"colour {k} is taken: {P[k]} vs {v}"
        P[k] = v


add_colors({
    "leather": (150, 88, 52), "leather_d": (110, 62, 38), "leather_l": (188, 120, 76),
    "lamp_green": (60, 130, 90), "lamp_green_d": (38, 92, 64),
    "parch": (236, 222, 184), "parch_d": (200, 182, 140),
    "steel": (168, 176, 190), "steel_d": (118, 126, 142), "steel_l": (214, 220, 232),
    "velvet": (130, 40, 70), "velvet_d": (90, 26, 52), "velvet_l": (176, 72, 104),
    "sky": (150, 200, 240), "sky_d": (110, 160, 214), "grass": (96, 170, 84), "grass_d": (62, 130, 62), "dirt": (140, 100, 64),
    "bronze": (190, 130, 70), "bronze_d": (140, 90, 46), "bronze_l": (226, 168, 100),
})


def drawers(c, x0, y0, x1, y1, rows, wood="wood", knob="gold"):
    """A front of drawers: `rows` of them, each with a knob."""
    h = (y1 - y0 + 1) // rows
    for r in range(rows):
        top = y0 + r * h
        R(c, x0, top, x1, top + h - 1, wood); R(c, x0, top, x1, top, wood + "_l"); R(c, x0, top + h - 1, x1, top + h - 1, wood + "_d")
        c.put((x0 + x1) // 2, top + h // 2, knob); c.put((x0 + x1) // 2 + 1, top + h // 2, knob)


def legs(c, xs, y0, y1, k="wood_d"):
    for x in xs:
        R(c, x, y0, x, y1, k)


def cushion(c, x0, y0, x1, y1, k, kl, kd):
    R(c, x0, y0, x1, y1, k); R(c, x0, y0, x1, y0, kl); R(c, x1, y0 + 1, x1, y1, kd); R(c, x0, y1, x1, y1, kd)


def chair_back(c, x0, y0, x1, y1, k, kl, kd, studs=True):
    cushion(c, x0, y0, x1, y1, k, kl, kd)
    if studs:
        for x in range(x0 + 2, x1 - 1, 3):
            c.put(x, y0 + 2, "gold")
