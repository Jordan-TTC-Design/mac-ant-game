#!/usr/bin/env python3
"""Draws the wild animals (chicken, sheep, pig) as 16x16 pixel art with a two-frame walk cycle.

    python3 tools/make_animals.py                    # writes Resources/Animals/<id>/*
    python3 tools/make_animals.py --preview out.png  # also writes a zoomed contact sheet

Each animal is a folder with manifest.json and walk.png (two frames side by side, facing right; the app mirrors it for
left). The manifest also holds what the animal is like in the game: `hp`, `speed` (points per second), `meat` (pieces of
food it leaves), `aggressive` (fights back), `weight` (how often it turns up), `radius` (its size for hitting).
Only the standard library is needed.
"""
import json
import math
import os
import sys

from make_goblin import Canvas, SIZE, write_png


def ellipse(c, cx, cy, rx, ry, col):
    for y in range(SIZE):
        for x in range(SIZE):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c.put(x, y, col)


PAL = {
    "O": (52, 40, 40),
    # sheep
    "W": (250, 250, 246), "w": (222, 224, 226), "k": (60, 52, 56), "K": (86, 76, 80),
    # pig
    "p": (244, 166, 176), "P": (224, 128, 146), "q": (250, 200, 206), "n": (196, 92, 116),
    # chicken
    "c": (250, 248, 240), "C": (226, 220, 206), "r": (222, 52, 60), "y": (244, 176, 40), "Y": (214, 140, 24),
    "e": (24, 24, 28),
}


def sheep(f):
    c = Canvas()
    for cx, cy, rx, ry in ((6, 7.5, 3.4, 3.2), (9.5, 7.5, 3.4, 3.2), (8, 6, 3.6, 3), (8, 9, 4, 2.6)):
        ellipse(c, cx, cy, rx, ry, "W")
    for x, y in ((4, 9), (12, 9), (8, 10), (6, 10), (10, 10)):
        c.put(x, y, "w")                                   # shading under the wool
    for x in ((4, 6, 9, 11) if f == 0 else (5, 7, 8, 10)):  # four dark legs, stepping
        c.rect(x, 11, x, 13, "k")
    ellipse(c, 13.2, 7.4, 2, 2.4, "k")                     # dark face
    c.put(11, 5, "K")
    c.put(12, 4, "K")                                      # ear
    c.outline()
    c.put(14, 7, "W")                                      # a glint in the eye
    return c


def pig(f):
    c = Canvas()
    ellipse(c, 7.5, 8, 5.8, 3.8, "p")
    ellipse(c, 13, 8, 2.6, 3, "p")
    c.rect(14, 8, 15, 10, "q")                             # snout
    c.put(15, 9, "n")
    c.cells([(12, 5), (11, 5), (12, 4)], "P")              # ear
    c.cells([(1, 6), (0, 5), (1, 4)], "P")                 # curly tail
    for x in ((4, 10) if f == 0 else (5, 9)):
        c.rect(x, 11, x, 13, "P")
    for x in ((11, 5) if f == 0 else (10, 6)):
        c.rect(x, 11, x, 13, "P")
    c.outline()
    c.put(13, 6, "e")
    return c


def chicken(f):
    c = Canvas()
    ellipse(c, 8, 9.5, 4.2, 3.6, "c")
    ellipse(c, 12, 5.8, 2.1, 2.2, "c")
    c.cells([(3, 7), (4, 6), (3, 6), (2, 7)], "C")         # tail feathers
    c.cells([(11, 3), (12, 3), (12, 2)], "r")              # comb
    c.cells([(14, 6), (15, 6)], "y")                       # beak
    c.put(12, 8, "r")                                      # wattle
    ly = (7, 10) if f == 0 else (8, 9)
    for x in ly:
        c.rect(x, 12, x, 13, "Y")
        c.put(x + 1, 13, "Y")
    c.outline()
    c.put(12, 5, "e")
    c.cells([(6, 9), (7, 9), (8, 9)], "C")                 # wing
    return c


ANIMALS = [
    # id, name, draw, hp, speed, meat, aggressive, weight, radius
    ("chicken", "雞", chicken, 3, 20, 5, False, 5, 6),
    ("sheep", "羊", sheep, 6, 13, 12, False, 3, 9),
    ("pig", "豬", pig, 9, 15, 16, True, 2, 9),
]


def sheet(draw):
    img = [[(0, 0, 0, 0)] * (2 * SIZE) for _ in range(SIZE)]
    for f in range(2):
        canvas = draw(f)
        for y in range(SIZE):
            for x in range(SIZE):
                key = canvas.px[y][x]
                if key is not None:
                    img[y][f * SIZE + x] = PAL[key] + (255,)
    return img


def preview(path, zoom=10):
    W = len(ANIMALS) * 2 * SIZE * zoom
    img = [[(214, 218, 200, 255)] * W for _ in range(SIZE * zoom)]
    for i, (_, _, draw, *_rest) in enumerate(ANIMALS):
        sh = sheet(draw)
        for y in range(SIZE):
            for x in range(2 * SIZE):
                px = sh[y][x]
                if px[3]:
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[y * zoom + dy][(i * 2 * SIZE + x) * zoom + dx] = px
    write_png(path, img)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Animals")
    for aid, name, draw, hp, speed, meat, aggressive, weight, radius in ANIMALS:
        folder = os.path.join(root, aid)
        os.makedirs(folder, exist_ok=True)
        write_png(os.path.join(folder, "walk.png"), sheet(draw))
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump({"id": aid, "name": name, "frame": SIZE, "pixelScale": 1.5, "sheet": "walk.png", "hp": hp, "speed": speed,
                       "meat": meat, "aggressive": aggressive, "weight": weight, "radius": radius}, f, ensure_ascii=False, indent=2)
            f.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("wrote", os.path.normpath(root))


if __name__ == "__main__":
    main()
