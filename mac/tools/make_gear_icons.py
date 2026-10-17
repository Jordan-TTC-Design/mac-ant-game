#!/usr/bin/env python3
"""Draws an icon (16x16 pixel art) for every piece of gear the workshop makes, into one sheet.

    python3 tools/make_gear_icons.py                    # writes Resources/Gear/icons.png and icons.json
    python3 tools/make_gear_icons.py --preview out.png  # also a zoomed contact sheet: every look, then every piece

The workshop, the roster and the phone show these beside each piece's name, so 93 recipes are not a wall of words. Each
piece's look and colour come from Sources/GoblinCamp/Equipment.swift (`look: .longSword, color: rgb(…)`), the same as
the camp draws it on a goblin (AntView.drawGear): one drawing per look, coloured per piece, so a new piece needs no new
drawing. icons.json maps each gear id to its place in the sheet (8 across).

In the drawings "c" is the piece's colour, "d" a darker and "l" a lighter shade of it; the other letters are fixed
(a wooden grip, a gold guard, a bowstring…); "." is empty. A dark outline goes round everything.
"""
import json
import os
import re
import sys

from make_goblin import Canvas, SIZE, write_png

COLS = 8
FIXED = {
    "b": (120, 80, 44), "B": (78, 50, 28),  # wooden grip
    "g": (222, 178, 64),  # guard, pommel, clasp
    "s": (236, 230, 210),  # bowstring, fletching
    "i": (176, 182, 194), "I": (112, 118, 132),  # iron (arrowhead, shield boss, bands)
    "w": (255, 255, 250),  # a glint
    "o": (120, 214, 250),  # a staff's gem
}


def sym(rows):
    """A drawing given as its left half, mirrored."""
    assert len(rows) == SIZE and all(len(r) == 8 for r in rows), rows
    return [r + r[::-1] for r in rows]


def blank():
    return [["."] * SIZE for _ in range(SIZE)]


def put(g, x, y, ch):
    if 0 < x < SIZE - 1 and 0 < y < SIZE - 1:  # (the edge is kept free for the outline)
        g[y][x] = ch


def blade(g, x, y, n, wide=False):
    """A blade from (x, y) up and to the right, `n` long: a light edge, the colour, a darker back when wide."""
    for i in range(n):
        if wide:
            put(g, x + i + 1, y - i + 1, "d")
        put(g, x + i, y - i, "l")
        put(g, x + i + 1, y - i, "c")
    put(g, x + n, y - n, "l")


def guard(g, x, y, r):
    """A cross-guard through (x, y), square to the blade."""
    for k in range(-r, r + 1):
        put(g, x + k, y + k, "g")


def grip(g, x, y, n, pommel=True):
    """A grip from (x, y) down and to the left."""
    for i in range(n):
        put(g, x - i, y + i, "b")
        put(g, x - i + 1, y + i, "B")
    if pommel:
        put(g, x - n, y + n, "g")


def sword(n, wide=False, r=1, hilt=3):
    g = blank()
    bx, by = 6, 9  # where the blade leaves the guard
    blade(g, bx, by, n, wide)
    guard(g, bx - 1, by + 1, r)
    grip(g, bx - 2, by + 2, hilt)
    return ["".join(row) for row in g]


def twin():
    a = sword(6)
    b = [row[::-1] for row in a]
    return ["".join(x if x != "." else y for x, y in zip(ra, rb)) for ra, rb in zip(a, b)]


def spear():
    g = blank()
    for i in range(9):  # the shaft
        put(g, 2 + i, 14 - i, "b")
        put(g, 3 + i, 14 - i, "B")
    blade(g, 11, 4, 2, wide=True)
    guard(g, 10, 5, 1)
    return ["".join(row) for row in g]


def bow():
    g = blank()
    arc = {1: 5, 2: 6, 3: 7, 4: 8, 5: 8, 6: 9, 7: 9, 8: 9, 9: 9, 10: 8, 11: 8, 12: 7, 13: 6, 14: 5}
    for y, x in arc.items():
        put(g, x, y, "c")
        put(g, x - 1, y, "l" if 3 < y < 12 else "c")
    for y in range(2, 14):  # the string
        put(g, 4, y, "s")
    for x in range(2, 13):  # an arrow across
        put(g, x, 8, "b")
    put(g, 13, 8, "i"), put(g, 12, 7, "i"), put(g, 12, 9, "i")
    put(g, 2, 7, "s"), put(g, 2, 9, "s"), put(g, 3, 7, "s"), put(g, 3, 9, "s")
    return ["".join(row) for row in g]


def staff():
    g = blank()
    for i in range(9):
        put(g, 3 + i, 14 - i, "c")
        put(g, 4 + i, 14 - i, "d")
    for x, y in ((11, 2), (12, 2), (10, 3), (11, 3), (12, 3), (13, 3), (10, 4), (11, 4), (12, 4), (13, 4), (11, 5), (12, 5)):
        put(g, x, y, "o")
    put(g, 11, 3, "w")
    for x, y in ((9, 5), (10, 6), (13, 2), (14, 5)):  # prongs holding the gem
        put(g, x, y, "d")
    return ["".join(row) for row in g]


LOOKS = {
    "knife": sword(4, hilt=2),
    "dagger": sword(6, r=1),
    "shortSword": sword(6, wide=True, r=2),
    "longSword": sword(8, wide=True, r=2),
    "greatSword": sword(9, wide=True, r=3, hilt=4),
    "twinBlades": twin(),
    "spear": spear(),
    "bow": bow(),
    "staff": staff(),
    "roundShield": sym([
        "........",
        "........",
        ".....ddd",
        "...ddccc",
        "..dccccc",
        "..dccccc",
        ".dcccccl",
        ".dccccli",
        ".dccccli",
        ".dcccccl",
        "..dccccc",
        "..dccccc",
        "...ddccc",
        ".....ddd",
        "........",
        "........",
    ]),
    "woodShield": sym([
        "........",
        "........",
        "..IIIIII",
        "..cccdcc",
        "..cccdcc",
        "..IIIIII",
        "..cccdcc",
        "..cccdcc",
        "..cccdcc",
        "...ccdcc",
        "...ccdcc",
        "....cdcc",
        ".....dcc",
        "......cc",
        "........",
        "........",
    ]),
    "cap": sym([
        "........",
        "........",
        "........",
        "........",
        "........",
        "......ll",
        "....llcc",
        "...lcccc",
        "..lccccc",
        "..cccccc",
        ".ccccccc",
        ".ddddddd",
        "........",
        "........",
        "........",
        "........",
    ]),
    "helm": sym([
        "........",
        "......dd",
        "......ll",
        "....llcc",
        "...lcccc",
        "..lccccc",
        "..cccccc",
        "..cccccc",
        "..cccccc",
        "..cc....",
        "..ccccdc",
        "..ccccdc",
        "..dcccdc",
        "...dddd.",
        "........",
        "........",
    ]),
    "tunic": sym([
        "........",
        "........",
        "........",
        "...cccc.",
        "..ccccc.",
        ".cccccc.",
        ".ccccccc",
        ".dcccccc",
        "..cccccc",
        "..cccccc",
        "..cccccc",
        "..cccccc",
        "..dddddd",
        "........",
        "........",
        "........",
    ]),
    "plate": sym([
        "........",
        "........",
        "........",
        "..lll...",
        ".llllcc.",
        ".dllcccc",
        ".d.ccccc",
        "...clccc",
        "...cclcc",
        "...ccccc",
        "...cwccc",
        "...ccccc",
        "...ddddd",
        "........",
        "........",
        "........",
    ]),
    "cloak": sym([
        "........",
        "........",
        "....cccc",
        "...ccccg",
        "..cccccd",
        "..ccccd.",
        "..cccdc.",
        "..ccdcc.",
        ".cccdcc.",
        ".ccdccc.",
        ".ccdccc.",
        ".cdcccc.",
        ".cdcccc.",
        ".ddddd..",
        "........",
        "........",
    ]),
    "pants": sym([
        "........",
        "........",
        "........",
        "........",
        "..dddddd",
        "..cccccc",
        "..cccccc",
        "..cccccc",
        "..ccccc.",
        "..cccc..",
        "..cccc..",
        "..cccc..",
        "..cccc..",
        "..dddd..",
        "........",
        "........",
    ]),
    "boots": sym([
        "........",
        "........",
        "........",
        "........",
        "...llll.",
        "...cccc.",
        "...cccc.",
        "...cccc.",
        "...cccc.",
        "...cccc.",
        "..ccccc.",
        ".cccccc.",
        ".cccccc.",
        ".dddddd.",
        "........",
        "........",
    ]),
    "gloves": sym([
        "........",
        "........",
        "........",
        "...cdcd.",
        "...cdcd.",
        "..ccdcd.",
        "..ccccc.",
        ".lccccc.",
        ".lccccc.",
        "..lcccc.",
        "..ccccc.",
        "..ccccc.",
        "..ddddd.",
        "..ddddd.",
        "........",
        "........",
    ]),
    "gauntlet": sym([
        "........",
        "........",
        "........",
        "...lcc..",
        "..lcdcd.",
        "..lcdcd.",
        "..lcccc.",
        ".llcccc.",
        ".lccccc.",
        "..ccccc.",
        "..ccccc.",
        ".dddddd.",
        ".dddddd.",
        ".lllll..",
        "........",
        "........",
    ]),
}


def shade(rgb, k):
    return tuple(max(0, min(255, round(v * k))) for v in rgb)


def tint(rgb, k):
    return tuple(round(v + (255 - v) * k) for v in rgb)


def icon(look, rgb):
    """The pixels of `look` in colour `rgb`."""
    c = Canvas()
    for y, row in enumerate(LOOKS[look]):
        for x, ch in enumerate(row):
            if ch != ".":
                c.put(x, y, ch)
    c.outline()
    pal = dict(FIXED, c=rgb, d=shade(rgb, 0.62), l=tint(rgb, 0.45), O=(34, 28, 34))
    return [[pal[ch] + (255,) if ch is not None else (0, 0, 0, 0) for ch in row] for row in c.px]


def pieces():
    """Every piece in Equipment.swift: (id, look, colour), in the order there."""
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "..", "Sources", "GoblinCamp", "Equipment.swift"), encoding="utf-8") as f:
        text = f.read()
    out = []
    for chunk in text.split('Gear(id: "')[1:]:
        gid = chunk[: chunk.index('"')]
        m = re.search(r"look: \.(\w+), color: rgb\((\d+), (\d+), (\d+)\)", chunk)
        if not m:
            continue
        assert m.group(1) in LOOKS, f"{gid}: no drawing for look .{m.group(1)}"
        out.append((gid, m.group(1), tuple(int(m.group(k)) for k in (2, 3, 4))))
    return out


def sheet(entries):
    rows = (len(entries) + COLS - 1) // COLS
    img = [[(0, 0, 0, 0)] * (COLS * SIZE) for _ in range(rows * SIZE)]
    for n, (_, look, rgb) in enumerate(entries):
        px = icon(look, rgb)
        ox, oy = (n % COLS) * SIZE, (n // COLS) * SIZE
        for y in range(SIZE):
            for x in range(SIZE):
                img[oy + y][ox + x] = px[y][x]
    return img


def preview(path, img, zoom=6):
    h, w = len(img), len(img[0])
    out = [[(214, 218, 200, 255)] * (w * zoom) for _ in range(h * zoom)]
    for y in range(h):
        for x in range(w):
            px = img[y][x]
            if px[3]:
                for dy in range(zoom):
                    for dx in range(zoom):
                        out[y * zoom + dy][x * zoom + dx] = px
    write_png(path, out)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Gear")
    os.makedirs(root, exist_ok=True)
    entries = pieces()
    img = sheet(entries)
    write_png(os.path.join(root, "icons.png"), img)
    with open(os.path.join(root, "icons.json"), "w", encoding="utf-8") as f:
        json.dump({"size": SIZE, "cols": COLS, "icons": {gid: n for n, (gid, _, _) in enumerate(entries)}}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if "--preview" in sys.argv:
        # every look in a plain grey first (a row and a bit), then every piece as it is
        looks = [(name, name, (150, 150, 160)) for name in LOOKS]
        preview(sys.argv[sys.argv.index("--preview") + 1], sheet(looks + entries))
    print("wrote", os.path.normpath(root), len(entries), "icons")


if __name__ == "__main__":
    main()
