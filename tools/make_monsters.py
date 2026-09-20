#!/usr/bin/env python3
"""Draws the monsters (slime, giant rat) as 16x16 pixel art and writes their folders next to the animals.

    python3 tools/make_monsters.py                    # writes Resources/Animals/<id>/*
    python3 tools/make_monsters.py --preview out.png  # also writes a zoomed contact sheet

A monster is an animal folder (see make_animals.py) whose manifest.json has a few extra fields:
  hostile (true), level, damage (health a goblin loses per hit), attackEvery (seconds), hops (moves in hops),
  splits (how many smaller ones it breaks into), pack [min, max] (how many come together), and
  drops: a list of {id, name, chance 0..1, min, max, color "#rrggbb"}. A drop's rarity comes from its chance:
  50% and up is common, 15%-50% uncommon, below that rare. Monsters need at least three drops. `appearsAfter` (minutes of game time) and `minAnts` (goblins the camp has had) say when they may first turn up. `hp` is how much damage it takes (a goblin hits for 1 to 2 about once a second, so 30 is a few seconds for a
squad of eight); each kind has its own.
Each sheet holds the walk frames first (`walkFrames`), then two attack poses: the wind-up and the strike. `attackStyle` (slam, bite)
decides the motion the game gives them. The slime hops (four walk frames); the rat scurries (two).
"""
import json
import os
import sys

from make_goblin import Canvas, SIZE, write_png
from make_animals import ellipse

PAL = {
    "O": (30, 62, 46), "k": (70, 20, 30),
    # slime
    "a": (104, 208, 120), "A": (58, 152, 88), "h": (200, 246, 206), "w": (250, 250, 250), "e": (24, 30, 30), "m": (30, 90, 60),
    # rat
    "R": (52, 40, 40), "f": (150, 132, 122), "F": (108, 92, 84), "s": (196, 178, 164), "q": (232, 150, 164), "d": (204, 40, 52),
    "t": (250, 246, 232),
}


def slime(f):
    """Frames 0-3 are the hop (squash, stretch, stretch, land); 4 is the wind-up of the slam (tall, cross); 5 the slam (flat, mouth open)."""
    c = Canvas()
    # (rx, ry) per frame; the bottom stays on the ground (y = 13)
    rx, ry = ((6.2, 3.2), (4.3, 5.4), (4.6, 5.0), (5.6, 3.8), (3.8, 5.8), (7.2, 2.6))[f]
    ellipse(c, 8, 13.5 - ry, rx, ry, "a")
    # shade along the bottom and the right side, a highlight on the top left
    for y in range(SIZE):
        for x in range(SIZE):
            if c.px[y][x] == "a":
                if y >= 13.5 - 1.2 or x >= 8 + rx - 1.4:
                    c.px[y][x] = "A"
    top = int(13.5 - 2 * ry)
    c.cells([(6, top + 2), (7, top + 1), (6, top + 3)], "h")
    ey = int(13.5 - ry) - 1
    c.cells([(6, ey), (10, ey)], "w")
    c.cells([(6, ey + 1), (10, ey + 1)], "e")
    if f >= 4:                                                                    # angry: slanted brows
        c.cells([(5, ey - 1), (6, ey - 1), (10, ey - 1), (11, ey - 1)], "m")
    if f == 5:
        c.cells([(7, ey + 2), (8, ey + 2), (9, ey + 2), (7, ey + 3), (8, ey + 3), (9, ey + 3)], "m")   # open mouth
    else:
        c.cells([(8, ey + 3), (9, ey + 3)] if f in (0, 3) else [(8, ey + 3)], "m")
    c.outline()
    return c


def rat(f):
    """Frames 0-1 are the scurry; 2 is the wind-up of the bite (crouched, head drawn back); 3 the bite (stretched, jaws open)."""
    c = Canvas()
    crouch = 1 if f == 2 else 0
    reach = 1 if f == 3 else 0
    ellipse(c, 6.8 + reach * 0.3 - (1 if f == 2 else 0), 9.6 + crouch, 4.6 + reach * 0.3, 2.8 - crouch * 0.4, "f")     # body
    hx, hy = 11.8 + reach - (2 if f == 2 else 0), 8.2 + crouch + (1 if f == 2 else 0)
    ellipse(c, hx, hy, 2.3, 2.1, "f")                                # head
    c.cells([(int(hx) + 2, int(hy)), (int(hx) + 2, int(hy) + 1), (int(hx) + 3, int(hy) + 1)], "s")           # snout
    c.put(int(hx) + 3, int(hy) + 1, "q")                             # nose
    ex = int(hx) - 2
    c.cells([(ex, int(hy) - 3), (ex + 1, int(hy) - 3), (ex, int(hy) - 2), (ex + 1, int(hy) - 2), (ex + 1, int(hy) - 4)], "F")   # ear
    c.cells([(ex + 1, int(hy) - 3), (ex + 1, int(hy) - 2)], "q")
    c.put(int(hx), int(hy) - 1, "d")                                 # red eye
    if f == 3:                                                       # jaws wide open: dark mouth and long teeth
        c.cells([(int(hx) + 1, int(hy) + 2), (int(hx) + 2, int(hy) + 2), (int(hx) + 3, int(hy) + 2), (int(hx) + 2, int(hy) + 3), (int(hx) + 3, int(hy) + 3)], "k")
        c.cells([(int(hx) + 1, int(hy) + 3), (int(hx) + 3, int(hy) + 4), (int(hx) + 2, int(hy) + 1)], "t")
    else:
        c.put(int(hx) + 1, int(hy) + 2, "t")                         # a buck tooth
    c.cells([(4, 11 + crouch), (5, 11 + crouch), (9, 11 + crouch)], "F")   # belly shade
    if f == 0:
        tail = [(2, 9), (1, 8), (0, 8), (0, 7)]
    elif f == 1:
        tail = [(2, 9), (1, 10), (0, 10), (0, 11)]
    elif f == 2:
        tail = [(1, 10), (0, 9), (0, 8), (0, 7)]                     # tail up, tense
    else:
        tail = [(1, 9), (0, 9)]
    c.cells(tail, "q")
    legs = (4, 9, 11) if f == 0 else (5, 8, 12) if f == 1 else (3, 6, 9) if f == 2 else (3, 5, 11)
    for x in legs:
        c.rect(x, 12 + crouch, x, 13, "F")
    c.outline()
    return c


MONSTERS = [
    # id, name, draw, frames, manifest
    ("slime", "史萊姆", slime, 6, {
        "hp": 60, "speed": 15, "meat": 0, "aggressive": True, "weight": 3, "radius": 7, "pixelScale": 1.5,
        "hostile": True, "level": 1, "appearsAfter": 30, "minAnts": 25, "damage": 1, "attackEvery": 2.4, "hops": True, "walkFrames": 4, "attackStyle": "slam", "splits": 2, "pack": [1, 1],
        "drops": [
            {"id": "slime_goo", "name": "黏液", "chance": 0.85, "min": 1, "max": 3, "color": "#68d078"},
            {"id": "slime_core", "name": "史萊姆核心", "chance": 0.30, "min": 1, "max": 1, "color": "#3aa0d8"},
            {"id": "elastic_gel", "name": "彈性凝膠", "chance": 0.22, "min": 1, "max": 2, "color": "#a8e8c0"},
            {"id": "shiny_bead", "name": "閃亮黏珠", "chance": 0.04, "min": 1, "max": 1, "color": "#f0d040"},
        ]}),
    ("giant_rat", "巨鼠", rat, 4, {
        "hp": 30, "speed": 34, "meat": 0, "aggressive": True, "weight": 3, "radius": 6, "pixelScale": 1.5,
        "hostile": True, "level": 1, "appearsAfter": 75, "minAnts": 40, "damage": 1, "attackEvery": 1.3, "hops": False, "walkFrames": 2, "attackStyle": "bite", "splits": 0, "pack": [2, 3],
        "drops": [
            {"id": "rat_fang", "name": "鼠牙", "chance": 0.75, "min": 1, "max": 2, "color": "#f4efdc"},
            {"id": "rat_pelt", "name": "鼠皮", "chance": 0.50, "min": 1, "max": 1, "color": "#a08c7c"},
            {"id": "rat_tail", "name": "鼠尾", "chance": 0.30, "min": 1, "max": 1, "color": "#e896a4"},
            {"id": "sharp_claw", "name": "斷爪", "chance": 0.15, "min": 1, "max": 1, "color": "#8a8a96"},
            {"id": "golden_fur", "name": "金毛", "chance": 0.03, "min": 1, "max": 1, "color": "#f0c040"},
        ]}),
]


def sheet(draw, frames):
    img = [[(0, 0, 0, 0)] * (frames * SIZE) for _ in range(SIZE)]
    for f in range(frames):
        canvas = draw(f)
        for y in range(SIZE):
            for x in range(SIZE):
                key = canvas.px[y][x]
                if key is not None:
                    img[y][f * SIZE + x] = PAL[key] + (255,)
    return img


def preview(path, zoom=10):
    total = sum(fr for _, _, _, fr, _ in MONSTERS)
    img = [[(214, 218, 200, 255)] * (total * SIZE * zoom) for _ in range(SIZE * zoom)]
    offset = 0
    for _, _, draw, frames, _ in MONSTERS:
        sh = sheet(draw, frames)
        for y in range(SIZE):
            for x in range(frames * SIZE):
                px = sh[y][x]
                if px[3]:
                    for dy in range(zoom):
                        for dx in range(zoom):
                            img[y * zoom + dy][(offset * SIZE + x) * zoom + dx] = px
        offset += frames
    write_png(path, img)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Animals")
    for mid, name, draw, frames, extra in MONSTERS:
        assert len(extra["drops"]) >= 3, mid
        folder = os.path.join(root, mid)
        os.makedirs(folder, exist_ok=True)
        write_png(os.path.join(folder, "walk.png"), sheet(draw, frames))
        manifest = {"id": mid, "name": name, "frame": SIZE, "sheet": "walk.png"}
        manifest.update(extra)
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=2)
            f.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("wrote", os.path.normpath(root))


if __name__ == "__main__":
    main()
