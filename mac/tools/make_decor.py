#!/usr/bin/env python3
"""Draws the camp decorations players put down themselves (DESKTOP.md §5): fifty for each race. Output: Resources/Decor/<id>.png
(and <id>-1.png for the second frame of the ones that move) plus Resources/Decor/catalog.json, which the Mac reads and
shared/src/camp/decor.ts must match (a test checks). Run: python3 tools/make_decor.py [--sheet out-prefix]

Same look as the terrain (make_terrain.py): one art pixel is two points on screen, a dark outline, light from the top left.
Every sprite stands on its bottom-centre pixel. Sizes: small (1 point of the camp's decoration room), medium (2), large (4)."""
import json
import math
import os
import random
import sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_terrain as T  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Decor")

new, put, rect, outline, blob, shade = T.new, T.put, T.rect, T.outline, T.blob, T.shade
WOOD, WOOD_LIGHT = T.WOOD, T.WOOD_LIGHT
WOOD_DARK = (78, 50, 28)
BONE = (236, 230, 210)
BONE_SHADE = (196, 188, 164)
STONE = [(108, 112, 120), (146, 150, 158), (176, 180, 188)]
INK = (40, 28, 20)


# ---- drawing helpers ---------------------------------------------------------------------------------------------
def line(img, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for k in range(n + 1):
        put(img, round(x0 + (x1 - x0) * k / n), round(y0 + (y1 - y0) * k / n), c)


def disk(img, cx, cy, r, c, ry=None):
    ry = r if ry is None else ry
    for dy in range(-ry, ry + 1):
        for dx in range(-r, r + 1):
            if (dx / (r + 0.4)) ** 2 + (dy / (ry + 0.4)) ** 2 <= 1:
                put(img, cx + dx, cy + dy, c)


def ring(img, cx, cy, r, c, ry=None):
    ry = r if ry is None else ry
    for a in range(0, 360, 4):
        put(img, round(cx + r * math.cos(math.radians(a))), round(cy + ry * math.sin(math.radians(a))), c)


def finish(img, col=INK):
    outline(img, col)
    return img


def tri_roof(img, cx, top, half, height, c, light=None):
    for y in range(height):
        h = int(half * (y + 1) / height)
        rect(img, cx - h, top + y, 2 * h + 1, 1, c if (y % 3) else shade(c, 0.85))
        if light:
            put(img, cx - h, top + y, light)


def hut(w, h, wall, roof, roof_h=None, door=True, window=True, chimney=False, frame=0, smoke=False, roof_style="tri", extra_h=6):
    """A small building seen from the front: walls, a roof (triangle, flat or round), a door and a window."""
    roof_h = roof_h or h // 2
    W, H = w + 4, h + roof_h + extra_h
    img = new(W, H)
    cx = W // 2
    base = H - 1
    rect(img, 2, base - h + 1, w, h, wall)
    for y in range(base - h + 1, base + 1, 3):
        rect(img, 2, y, w, 1, shade(wall, 0.88))
    if roof_style == "tri":
        tri_roof(img, cx, base - h - roof_h + 1, w // 2 + 2, roof_h, roof, shade(roof, 1.2))
    elif roof_style == "round":
        for y in range(roof_h):
            half = int((w // 2 + 2) * math.sqrt(1 - ((roof_h - y) / (roof_h + 0.5)) ** 2))
            rect(img, cx - half, base - h - roof_h + 1 + y, 2 * half + 1, 1, roof if y % 3 else shade(roof, 0.86))
    else:
        rect(img, 1, base - h - 2, w + 2, 3, roof)
    if door:
        rect(img, cx - 2, base - 5, 4, 6, (52, 34, 24))
        put(img, cx + 1, base - 2, (220, 190, 90))
    if window:
        for wx in (4, w - 3):
            if wx + 3 < w + 2 and abs(wx - cx) > 3:
                rect(img, wx, base - h + 3, 3, 3, (250, 210, 110) if frame % 2 == 0 else (240, 190, 90))
                put(img, wx + 1, base - h + 4, shade(wall, 0.6))
    if chimney:
        rect(img, cx + w // 4, base - h - roof_h + 2, 3, roof_h // 2 + 2, (120, 110, 104))
        if smoke:
            for k in range(3):
                put(img, cx + w // 4 + 1 + (k + frame) % 2, base - h - roof_h - 1 - k * 2, (200, 200, 200, 180))
    return img


def post_fence(img, x0, y0, w, post, rail, step=7, h=7):
    for x in range(x0, x0 + w, step):
        rect(img, x, y0, 2, h, post)
    rect(img, x0, y0 + 1, w, 1, rail)
    rect(img, x0, y0 + h - 3, w, 1, rail)


def pen(w, h, post, rail, animals, frame, ground=None):
    """A fenced pen from the front: the back fence, what is inside, the low front fence."""
    img = new(w, h)
    if ground:
        rect(img, 1, 6, w - 2, h - 8, ground)
    post_fence(img, 0, 2, w, post, rail)
    for draw in animals:
        draw(img, frame)
    post_fence(img, 0, h - 7, w, post, rail, h=6)
    return finish(img, (60, 40, 22))


# ---- animals ------------------------------------------------------------------------------------------------------
def sheep(cx, cy, flip=1, wool=((206, 206, 196), (236, 236, 228), (252, 252, 248)), face=(40, 36, 40), bob=True):
    def draw(img, frame):
        y = cy - (1 if bob and frame % 2 else 0)
        rect(img, cx - 3, y + 3, 1, 3, face); rect(img, cx + 2, y + 3, 1, 3, face)
        blob(img, cx, y, 5, 3, list(wool), random.Random(cx))
        hx = cx + 6 * flip
        rect(img, hx - 1, y - 3 + (frame % 2), 3, 3, face)
    return draw


def pig(cx, cy, flip=1):
    pink = [(214, 130, 140), (236, 160, 168), (248, 190, 196)]

    def draw(img, frame):
        rect(img, cx - 3, cy + 2, 1, 2, pink[0]); rect(img, cx + 2, cy + 2, 1, 2, pink[0])
        blob(img, cx, cy, 5, 3, pink, random.Random(cx))
        hx = cx + 5 * flip
        rect(img, hx, cy - 1 + frame % 2, 2, 2, pink[0])
        put(img, hx + (1 if flip > 0 else 0), cy - 2, (30, 20, 20))
        put(img, cx - 5 * flip, cy - 2 - frame % 2, pink[0])  # the curly tail
    return draw


def cow(cx, cy, flip=1, colors=((236, 236, 230), (60, 50, 46))):
    def draw(img, frame):
        white, spot = colors
        rect(img, cx - 6, cy - 3, 12, 6, white)
        rect(img, cx - 3, cy - 2, 3, 3, spot); rect(img, cx + 2, cy, 2, 2, spot)
        for lx in (-5, -3, 3, 5):
            rect(img, cx + lx, cy + 3, 1, 3, shade(white, 0.7))
        hx = cx + 7 * flip
        rect(img, hx - 1, cy - 5 + frame % 2, 4, 4, white)
        rect(img, hx - 1, cy - 2 + frame % 2, 4, 1, (230, 170, 170))
        put(img, hx - 1, cy - 6, (220, 210, 180)); put(img, hx + 2, cy - 6, (220, 210, 180))
    return draw


def chicken(cx, cy, flip=1):
    def draw(img, frame):
        disk(img, cx, cy, 2, (246, 244, 236))
        put(img, cx + 2 * flip, cy - 2 - frame % 2, (246, 244, 236)); put(img, cx + 2 * flip, cy - 3 - frame % 2, (220, 50, 50))
        put(img, cx + 3 * flip, cy - 2 - frame % 2, (240, 180, 60))
        put(img, cx - 1, cy + 3, (240, 180, 60)); put(img, cx + 1, cy + 3, (240, 180, 60))
    return draw


def dog(cx, cy, flip=1, fur=((120, 100, 86), (150, 130, 110)), bony=False):
    def draw(img, frame):
        c, light = fur
        if bony:
            rect(img, cx - 4, cy - 1, 8, 1, BONE)
            for k in range(-3, 4, 2):
                rect(img, cx + k, cy, 1, 2, BONE_SHADE)
        else:
            rect(img, cx - 4, cy - 2, 8, 4, c); rect(img, cx - 3, cy - 2, 6, 1, light)
        for lx in (-3, 3):
            rect(img, cx + lx, cy + 2, 1, 3 - (frame % 2 if lx < 0 else 0), BONE if bony else c)
        hx = cx + 5 * flip
        rect(img, hx - 1, cy - 5, 3, 3, BONE if bony else c)
        put(img, hx - 1, cy - 6, BONE if bony else c)
        put(img, hx + flip, cy - 4, (20, 20, 20) if not bony else (120, 255, 220))
        put(img, cx - 5 * flip, cy - 3 - frame % 2, BONE if bony else c)
    return draw


def bird(cx, cy, body=(40, 40, 50), beak=(230, 170, 50), frame_wing=True):
    def draw(img, frame):
        rect(img, cx - 2, cy - 1, 4, 3, body)
        put(img, cx + 2, cy - 2, body); put(img, cx + 3, cy - 2, beak)
        put(img, cx + 2, cy - 3, (240, 240, 240))
        if frame_wing and frame % 2:
            rect(img, cx - 3, cy - 3, 3, 1, body)
        put(img, cx - 1, cy + 2, beak); put(img, cx + 1, cy + 2, beak)
    return draw


def bat(cx, cy):
    def draw(img, frame):
        c = (60, 50, 80)
        rect(img, cx - 1, cy - 1, 3, 3, c)
        if frame % 2:
            line(img, cx - 1, cy, cx - 5, cy - 2, c); line(img, cx + 1, cy, cx + 5, cy - 2, c)
        else:
            line(img, cx - 1, cy, cx - 5, cy + 1, c); line(img, cx + 1, cy, cx + 5, cy + 1, c)
        put(img, cx - 1, cy - 2, c); put(img, cx + 1, cy - 2, c)
        put(img, cx, cy, (240, 80, 80))
    return draw


# ---- trees and plants ---------------------------------------------------------------------------------------------
def leafy(w, h, trunk, leaves, rnd, trunk_h=None, dots=None, frame=0, shape="round"):
    img = new(w, h)
    cx = w // 2
    trunk_h = trunk_h or h // 3
    rect(img, cx - 1, h - trunk_h, 3, trunk_h, trunk)
    put(img, cx - 2, h - 1, trunk); put(img, cx + 2, h - 1, trunk)
    if shape == "round":
        blob(img, cx, (h - trunk_h) // 2 + 1, w // 2 - 1, (h - trunk_h) // 2, leaves, rnd)
    elif shape == "tall":
        for k in range(3):
            blob(img, cx, 4 + k * (h - trunk_h - 6) // 3, w // 2 - 2 - k, (h - trunk_h) // 5 + 1, leaves, rnd)
    elif shape == "droop":
        blob(img, cx, (h - trunk_h) // 2, w // 2 - 1, (h - trunk_h) // 2 - 1, leaves, rnd)
        for x in range(2, w - 2, 2):
            for y in range(h // 2, h - 4 - (x % 3)):
                put(img, x + (frame if y % 4 == 0 else 0), y, leaves[(x // 2) % 2])
    for (dx, dy, c) in (dots or []):
        put(img, cx + dx, dy, c)
    return img


def flowers(w, h, petal, center, rnd, n=6, stem=(60, 120, 60), tall=3):
    img = new(w, h)
    for k in range(n):
        x = 2 + rnd.randrange(w - 4)
        y = h - 1 - rnd.randrange(3)
        rect(img, x, y - tall, 1, tall + 1, stem)
        put(img, x - 1, y - tall, petal); put(img, x + 1, y - tall, petal); put(img, x, y - tall - 1, petal); put(img, x, y - tall + 1, petal)
        put(img, x, y - tall, center)
    return img


def chomper(w, h, head, frame, teeth=(250, 250, 240), stem=(70, 130, 60), inside=(200, 40, 60)):
    """A carnivorous plant: a stem and a big head that opens (frame 0) and snaps shut (frame 1)."""
    img = new(w, h)
    cx = w // 2
    for y in range(h // 2, h):
        put(img, cx + int(1.5 * math.sin(y / 2)), y, stem); put(img, cx + 1 + int(1.5 * math.sin(y / 2)), y, stem)
    rect(img, cx - 6, h - 4, 4, 2, stem); rect(img, cx + 3, h - 5, 4, 2, stem)
    top = 2
    hw = w // 2 - 2
    if frame % 2 == 0:
        disk(img, cx, top + 4, hw, head, 3)
        disk(img, cx, top + 10, hw, head, 3)
        rect(img, cx - hw + 2, top + 6, 2 * hw - 3, 3, inside)
        for x in range(cx - hw + 2, cx + hw - 1, 2):
            put(img, x, top + 6, teeth); put(img, x + 1, top + 8, teeth)
    else:
        disk(img, cx, top + 7, hw, head, 5)
        for x in range(cx - hw + 1, cx + hw, 2):
            put(img, x, top + 7, teeth)
    for k in range(-hw + 2, hw - 1, 3):
        put(img, cx + k, top + 3, shade(head, 1.25))
    return img


# ---- the catalogue -------------------------------------------------------------------------------------------------
CATALOG = []  # (id, race, name, category, size, frames, fn, blocks, draw)

CATEGORIES = {"building": "建築", "pen": "圍欄", "furniture": "家具", "scene": "場景", "tree": "樹", "sign": "路牌", "bone": "骨頭",
              "flower": "花", "plant": "巨型魔植", "creature": "活物"}


def item(id, race, name, cat, size, frames=1, fn=None, blocks=None):
    def wrap(draw):
        CATALOG.append(dict(id=id, race=race, name=name, category=cat, size=size, frames=frames, fn=fn,
                            blocks=(size >= 2 and cat in ("building", "pen", "scene")) if blocks is None else blocks, draw=draw))
        return draw
    return wrap


# ==== goblins (50) ==================================================================================================
G = "goblin"
R = lambda k: random.Random(k)  # noqa: E731


@item("g_tent", G, "破帳篷", "building", 2)
def g_tent(f):
    img = T.tent("meadow", R(1))
    for (x, y) in ((8, 20), (24, 26), (14, 30)):  # patches
        rect(img, x, y, 3, 3, (130, 150, 90))
    return img


@item("g_watchtower", G, "木頭瞭望台", "building", 2, frames=2, fn="watch")
def g_watchtower(f):
    img = new(24, 46)
    for x in (4, 18):
        rect(img, x, 14, 2, 32, WOOD)
    for y in range(18, 44, 7):
        line(img, 5, y, 19, y + 6, WOOD_LIGHT)
    rect(img, 1, 11, 22, 4, WOOD_LIGHT)
    rect(img, 1, 14, 22, 1, WOOD_DARK)
    tri_roof(img, 12, 1, 11, 7, (150, 60, 40))
    rect(img, 9, 7, 6, 4, (90, 150, 60))  # the lookout
    put(img, 11 + f, 8, (20, 20, 20)); put(img, 13 + f, 8, (20, 20, 20))
    return finish(img)


@item("g_hut", G, "哥布林小屋", "building", 4, frames=2)
def g_hut(f):
    img = hut(30, 18, (150, 110, 70), (110, 90, 50), roof_h=14, chimney=True, smoke=True, frame=f)
    return finish(img)


@item("g_outhouse", G, "茅廁", "building", 1, frames=2)
def g_outhouse(f):
    img = new(14, 22)
    rect(img, 2, 6, 10, 16, (140, 100, 60))
    rect(img, 1, 4, 12, 3, (110, 74, 40))
    if f == 0:
        rect(img, 4, 9, 6, 13, (100, 66, 36))
    else:
        rect(img, 4, 9, 6, 13, (30, 20, 16)); rect(img, 9, 9, 2, 13, (120, 80, 44))
    put(img, 6, 11, (240, 220, 90)); put(img, 7, 11, (240, 220, 90))  # the moon cut-out
    return finish(img)


@item("g_smithy", G, "鐵匠棚", "building", 4, frames=2, fn="smithy")
def g_smithy(f):
    img = new(40, 30)
    for x in (2, 36):
        rect(img, x, 8, 2, 22, WOOD)
    rect(img, 0, 5, 40, 4, (120, 110, 100))
    rect(img, 6, 18, 12, 10, (110, 100, 96))  # the forge
    rect(img, 8, 20, 8, 4, (240, 120 + 40 * f, 40))
    rect(img, 24, 22, 8, 3, (70, 70, 80)); rect(img, 26, 25, 4, 5, (60, 60, 70))  # anvil
    rect(img, 28, 14 + 2 * f, 1, 6, WOOD); rect(img, 26, 13 + 2 * f, 5, 2, (90, 90, 100))  # hammer
    return finish(img)


@item("g_storehouse", G, "戰利品倉庫", "building", 4)
def g_storehouse(f):
    img = hut(32, 16, (120, 90, 60), (90, 70, 46), roof_h=10, window=False)
    for (x, c) in ((4, (240, 200, 60)), (7, (200, 200, 220)), (30, (220, 60, 60))):
        rect(img, x, 23, 2, 2, c)
    rect(img, 26, 22, 4, 4, (150, 100, 50))
    return finish(img)


@item("g_totem", G, "圖騰柱", "building", 2, fn="totem")
def g_totem(f):
    return T.totem("meadow", R(2))


@item("g_tavern", G, "酒館棚", "building", 4, frames=2, fn="tavern")
def g_tavern(f):
    img = hut(32, 16, (160, 120, 80), (130, 60, 40), roof_h=10, frame=f)
    rect(img, 30, 4, 1, 6, WOOD)
    rect(img, 27 + f, 9, 6, 4, (200, 160, 60))  # the swinging sign: a mug
    put(img, 29 + f, 10, (250, 250, 240))
    for x in (6, 10):
        rect(img, x, 25, 3, 4, (130, 80, 40))
    return finish(img)


@item("g_pigpen", G, "豬圈", "pen", 4, frames=2, fn="pigs")
def g_pigpen(f):
    return pen(40, 24, WOOD, WOOD_LIGHT, [pig(12, 14), pig(28, 15, -1)], f, ground=(110, 84, 50))


@item("g_sheeppen", G, "羊圈", "pen", 4, frames=2, fn="sheep")
def g_sheeppen(f):
    return pen(40, 24, WOOD, WOOD_LIGHT, [sheep(12, 13), sheep(27, 14, -1)], f)


@item("g_cowpen", G, "牛欄", "pen", 4, frames=2, fn="cows")
def g_cowpen(f):
    return pen(44, 26, WOOD, WOOD_LIGHT, [cow(15, 15), cow(31, 16, -1, ((140, 90, 60), (90, 60, 40)))], f)


@item("g_coop", G, "雞籠", "pen", 2, frames=2, fn="eggs")
def g_coop(f):
    img = new(28, 22)
    rect(img, 2, 4, 12, 12, (150, 110, 70)); tri_roof(img, 8, 0, 7, 5, (160, 70, 50))
    rect(img, 6, 10, 4, 6, (40, 30, 20))
    post_fence(img, 14, 10, 14, WOOD, WOOD_LIGHT, step=5, h=6)
    chicken(19, 17)(img, f); chicken(24, 18, -1)(img, f + 1)
    return finish(img)


@item("g_kennel", G, "狼犬窩", "pen", 2, frames=2, fn="wolfdog")
def g_kennel(f):
    img = new(30, 20)
    rect(img, 2, 6, 12, 12, (130, 90, 56)); tri_roof(img, 8, 1, 7, 6, (100, 70, 40))
    disk(img, 8, 14, 3, (40, 28, 20))
    dog(22, 14, -1)(img, f)
    rect(img, 15, 18, 4, 1, (200, 200, 200))  # a bowl
    return finish(img)


@item("g_lizardpit", G, "蜥蜴坑", "pen", 2, frames=2)
def g_lizardpit(f):
    img = new(30, 18)
    disk(img, 15, 11, 13, (110, 84, 52), 6); disk(img, 15, 11, 11, (90, 66, 40), 4)
    for (x, y, d) in ((10, 11, 1), (20, 12, -1)):
        rect(img, x - 3, y, 6, 2, (90, 160, 70))
        put(img, x + 3 * d, y - 1 + f, (90, 160, 70)); put(img, x - 4 * d, y + 1, (90, 160, 70))
        put(img, x + 3 * d, y - 1 + f - 0, (90, 160, 70))
        put(img, x - 1, y + 2, (70, 130, 60)); put(img, x + 2, y + 2, (70, 130, 60))
    return finish(img)


@item("g_stumpset", G, "樹墩桌椅", "furniture", 2)
def g_stumpset(f):
    img = new(26, 14)
    for (x, w, h) in ((2, 5, 5), (10, 8, 8), (20, 5, 5)):
        rect(img, x, 14 - h, w, h, WOOD); rect(img, x, 14 - h, w, 1, (190, 150, 100)); rect(img, x + 1, 14 - h, w - 2, 1, (210, 170, 120))
    rect(img, 12, 5, 2, 1, (220, 220, 200))  # a cup
    return finish(img)


@item("g_strawbed", G, "草蓆床", "furniture", 1, fn="bed")
def g_strawbed(f):
    img = new(18, 8)
    rect(img, 1, 3, 16, 4, (210, 180, 90))
    for x in range(2, 16, 3):
        put(img, x, 3, (240, 210, 120)); put(img, x + 1, 6, (170, 140, 60))
    rect(img, 1, 2, 5, 3, (200, 190, 170))  # pillow
    return finish(img)


@item("g_cauldron", G, "大鍋", "furniture", 2, frames=2, fn="cook")
def g_cauldron(f):
    img = new(20, 20)
    disk(img, 10, 13, 7, (50, 50, 56), 5)
    rect(img, 3, 9, 14, 2, (70, 70, 76))
    rect(img, 4, 9, 12, 1, (120, 170, 80))
    for k in range(3):
        put(img, 6 + k * 3 + f, 7 - (k + f) % 2, (160, 200, 110))
    rect(img, 6, 18, 2, 2, (240, 120, 40)); rect(img, 12, 18, 2, 2, (240, 120 + 50 * f, 40))
    return finish(img)


@item("g_hammock", G, "吊床", "furniture", 2, frames=2)
def g_hammock(f):
    img = new(30, 18)
    for x in (1, 27):
        rect(img, x, 2, 2, 16, WOOD)
    sag = 3 + f
    for x in range(3, 27):
        y = 6 + int(sag * math.sin(math.pi * (x - 3) / 24))
        put(img, x, y, (200, 170, 120)); put(img, x, y + 1, (170, 140, 90))
    return finish(img)


@item("g_sofa", G, "撿來的破沙發", "furniture", 2)
def g_sofa(f):
    img = new(24, 14)
    rect(img, 2, 2, 20, 6, (150, 60, 60)); rect(img, 1, 6, 22, 6, (170, 70, 70))
    rect(img, 1, 5, 3, 7, (130, 50, 50)); rect(img, 20, 5, 3, 7, (130, 50, 50))
    rect(img, 8, 7, 3, 2, (230, 220, 180))  # stuffing poking out
    rect(img, 15, 3, 2, 2, (100, 140, 180))  # a patch
    return finish(img)


@item("g_barrels", G, "酒桶堆", "furniture", 1)
def g_barrels(f):
    img = new(18, 16)
    for (x, y) in ((1, 7), (9, 7), (5, 0)):
        rect(img, x, y, 8, 8, (140, 90, 50)); rect(img, x, y + 2, 8, 1, (80, 70, 70)); rect(img, x, y + 5, 8, 1, (80, 70, 70))
        rect(img, x + 1, y, 6, 1, (170, 120, 70))
    return finish(img)


@item("g_drum", G, "戰鼓", "furniture", 1, frames=2, fn="drum")
def g_drum(f):
    img = new(16, 16)
    rect(img, 2, 5, 12, 10, (160, 60, 40))
    for x in range(2, 14, 3):
        line(img, x, 5, x + 2, 14, (230, 210, 170))
    disk(img, 8, 5, 6, (230, 210, 170), 2)
    if f:
        rect(img, 10, 0, 1, 4, WOOD); rect(img, 9, 0, 3, 1, (200, 200, 200))
    return finish(img)


@item("g_chest", G, "寶箱", "furniture", 1, frames=2)
def g_chest(f):
    img = new(16, 14)
    rect(img, 1, 6, 14, 8, (130, 80, 40)); rect(img, 1, 9, 14, 1, (220, 180, 60))
    if f:
        rect(img, 1, 1, 14, 4, (150, 96, 50)); rect(img, 3, 5, 10, 2, (250, 220, 80)); put(img, 6, 4, (250, 250, 200))
    else:
        rect(img, 1, 3, 14, 4, (150, 96, 50))
    rect(img, 7, 8, 2, 3, (240, 200, 70))
    return finish(img)


@item("g_whetstone", G, "磨刀石", "furniture", 1, fn="whet")
def g_whetstone(f):
    img = new(16, 14)
    rect(img, 3, 8, 2, 6, WOOD); rect(img, 11, 8, 2, 6, WOOD)
    disk(img, 8, 6, 5, (150, 150, 156)); disk(img, 8, 6, 2, (110, 110, 116))
    rect(img, 12, 2, 1, 5, (200, 200, 210)); rect(img, 12, 7, 1, 2, WOOD)
    return finish(img)


@item("g_campfire", G, "營火圈", "scene", 2, frames=2)
def g_campfire(f):
    img = T.firepit("meadow", R(3))
    w = img.width
    rect(img, w // 2 - 2, 2, 4, 5, (240, 130, 40)); rect(img, w // 2 - 1, 1 - f + 1, 2, 3, (255, 220, 90))
    return img


@item("g_mud", G, "泥巴坑", "scene", 2, frames=2)
def g_mud(f):
    img = new(30, 14)
    disk(img, 15, 8, 13, (100, 72, 44), 5); disk(img, 15, 8, 10, (84, 58, 34), 3)
    put(img, 9 + f * 3, 7, (130, 100, 70)); put(img, 20 - f * 2, 9, (130, 100, 70))
    return finish(img, (60, 40, 22))


@item("g_junkpile", G, "垃圾山", "scene", 4, frames=2)
def g_junkpile(f):
    img = new(36, 22)
    blob(img, 18, 15, 16, 7, [(100, 90, 80), (130, 116, 100), (160, 146, 126)], R(4))
    for (x, y, c) in ((10, 10, (180, 180, 190)), (20, 9, (200, 80, 60)), (26, 12, (90, 140, 200)), (15, 14, (230, 210, 120))):
        rect(img, x, y, 3, 2, c)
    rect(img, 22, 4, 1, 6, WOOD)
    for k in range(3):  # flies
        put(img, 12 + k * 6 + f, 3 + (k + f) % 2 * 2, (20, 20, 20))
    return finish(img)


@item("g_range", G, "靶場", "scene", 2)
def g_range(f):
    img = new(26, 24)
    for (x, s) in ((6, 5), (19, 4)):
        rect(img, x, 14, 1, 10, WOOD)
        disk(img, x, 10, s, (240, 230, 210)); disk(img, x, 10, s - 2, (210, 60, 50)); put(img, x, 10, (240, 230, 210))
    rect(img, 8, 9, 4, 1, WOOD); put(img, 12, 9, (220, 220, 220))  # an arrow stuck in
    return finish(img)


@item("g_ring", G, "角力場", "scene", 4)
def g_ring(f):
    img = new(44, 22)
    disk(img, 22, 12, 20, (150, 120, 80), 9); disk(img, 22, 12, 17, (180, 150, 100), 7)
    for a in range(0, 360, 30):
        x = round(22 + 20 * math.cos(math.radians(a))); y = round(12 + 9 * math.sin(math.radians(a)))
        rect(img, x, y - 3, 1, 3, WOOD)
    return finish(img, (70, 50, 30))


@item("g_well", G, "水井", "scene", 1, fn="well")
def g_well(f):
    img = new(18, 22)
    rect(img, 2, 12, 14, 10, STONE[1]); rect(img, 2, 12, 14, 2, STONE[2])
    for x in range(3, 15, 4):
        rect(img, x, 15, 2, 1, STONE[0]); rect(img, x + 2, 18, 2, 1, STONE[0])
    rect(img, 3, 3, 1, 9, WOOD); rect(img, 14, 3, 1, 9, WOOD); rect(img, 2, 2, 14, 2, (150, 60, 40))
    rect(img, 8, 5, 1, 4, (200, 190, 160)); rect(img, 7, 9, 3, 3, (120, 90, 50))
    return finish(img)


@item("g_crooked", G, "歪脖子樹", "tree", 2)
def g_crooked(f):
    img = new(26, 36)
    for y in range(16, 36):
        x = 12 + int(4 * math.sin((36 - y) / 6))
        rect(img, x, y, 3, 1, T.TRUNK["meadow"])
    blob(img, 8, 10, 7, 6, T.LEAF["meadow"], R(5))
    blob(img, 18, 14, 5, 4, T.LEAF["meadow"], R(6))
    return finish(img, T.OUTLINE["meadow"])


@item("g_bonetree", G, "枯樹掛骨頭", "tree", 2, frames=2)
def g_bonetree(f):
    img = T.dead_tree("meadow", R(7), 34)
    w = img.width
    for (x, y) in ((w // 2 - 6, 12), (w // 2 + 5, 9)):
        line(img, x, y, x, y + 4, (200, 190, 160))
        rect(img, x - 1 + f, y + 5, 3, 2, BONE)
    return img


@item("g_appletree", G, "蘋果樹", "tree", 2, frames=2, fn="apples")
def g_appletree(f):
    img = leafy(26, 34, T.TRUNK["meadow"], T.LEAF["meadow"], R(8), dots=[(-6, 8, (220, 40, 40)), (4, 6, (220, 40, 40)), (-2, 14, (220, 40, 40)), (7, 13, (220, 40, 40))])
    if f:
        put(img, 18, 31, (220, 40, 40))
    return finish(img, T.OUTLINE["meadow"])


@item("g_shroomtree", G, "蘑菇樹", "tree", 4)
def g_shroomtree(f):
    img = new(34, 36)
    rect(img, 14, 14, 6, 22, (230, 220, 200)); rect(img, 14, 14, 2, 22, (250, 245, 235))
    disk(img, 17, 10, 15, (200, 50, 50), 8); rect(img, 3, 11, 29, 3, (170, 40, 40))
    for (x, y) in ((10, 6), (20, 4), (26, 9), (14, 9)):
        disk(img, x, y, 1, (250, 245, 235))
    return finish(img)


@item("g_bamboo", G, "竹叢", "tree", 2, frames=2)
def g_bamboo(f):
    img = new(20, 36)
    for (x, h) in ((4, 30), (9, 34), (14, 28)):
        for y in range(36 - h, 36):
            put(img, x + (f if y < 12 else 0), y, (110, 170, 80) if y % 7 else (70, 120, 50))
            put(img, x + 1 + (f if y < 12 else 0), y, (140, 200, 100) if y % 7 else (70, 120, 50))
        for y in range(36 - h, 36 - h + 8, 3):
            line(img, x + 1, y, x + 5, y - 2, (90, 160, 70))
    return finish(img, (40, 70, 30))


@item("g_sign_noway", G, "「此路不通」路牌", "sign", 1)
def g_sign_noway(f):
    img = new(18, 20)
    rect(img, 8, 8, 2, 12, WOOD)
    rect(img, 1, 3, 16, 6, (190, 150, 100)); rect(img, 15, 4, 2, 4, (190, 150, 100)); put(img, 17, 5, (190, 150, 100)); put(img, 17, 6, (190, 150, 100))
    line(img, 4, 4, 10, 7, (180, 40, 40)); line(img, 4, 7, 10, 4, (180, 40, 40))
    return finish(img)


@item("g_sign_skull", G, "骷髏警告牌", "sign", 1)
def g_sign_skull(f):
    img = new(16, 22)
    rect(img, 7, 10, 2, 12, WOOD)
    rect(img, 2, 2, 12, 9, (170, 130, 80))
    disk(img, 8, 6, 3, BONE); put(img, 7, 6, INK); put(img, 9, 6, INK); rect(img, 7, 8, 3, 1, BONE)
    line(img, 3, 10, 13, 3, (180, 40, 40))
    return finish(img)


@item("g_board", G, "懸賞布告欄", "sign", 1)
def g_board(f):
    img = new(20, 22)
    rect(img, 2, 6, 2, 16, WOOD); rect(img, 16, 6, 2, 16, WOOD)
    rect(img, 1, 3, 18, 12, (150, 110, 70))
    for (x, y, c) in ((3, 5, (240, 230, 200)), (10, 6, (240, 230, 200)), (5, 10, (230, 210, 170))):
        rect(img, x, y, 6, 4, c); rect(img, x + 1, y + 1, 4, 1, (100, 80, 70))
    return finish(img)


@item("g_banner", G, "營地大旗", "sign", 2, frames=2)
def g_banner(f):
    img = new(20, 36)
    rect(img, 3, 0, 2, 36, WOOD)
    for y in range(2, 14):
        w = 13 - (y - 2) // 4
        for x in range(5, 5 + w):
            put(img, x, y + (1 if (x + f * 2) % 6 < 3 and x > 8 else 0), (60, 120, 50) if y % 5 else (40, 90, 40))
    disk(img, 10, 7, 2, BONE)
    return finish(img)


@item("g_skull_big", G, "巨獸頭骨", "bone", 4)
def g_skull_big(f):
    img = new(36, 22)
    disk(img, 18, 11, 13, BONE, 8)
    disk(img, 12, 10, 3, (60, 50, 40)); disk(img, 24, 10, 3, (60, 50, 40))
    rect(img, 13, 17, 10, 3, BONE_SHADE)
    for x in range(13, 23, 2):
        rect(img, x, 19, 1, 3, BONE)
    for (x, d) in ((4, -1), (31, 1)):  # horns
        for k in range(7):
            put(img, x + d * (k // 2), 6 - k, BONE_SHADE); put(img, x + 1 + d * (k // 2), 6 - k, BONE)
    return finish(img)


@item("g_bonefence", G, "骨頭圍籬", "bone", 1)
def g_bonefence(f):
    img = new(20, 12)
    for x in range(1, 19, 4):
        rect(img, x, 2, 2, 10, BONE); rect(img, x - 1, 1, 4, 2, BONE)
    rect(img, 0, 5, 20, 1, (150, 110, 70))
    return finish(img)


@item("g_ribarch", G, "肋骨拱門", "bone", 4, blocks=False)
def g_ribarch(f):
    img = new(34, 34)
    for k in range(4):
        r = 15 - k * 2
        for a in range(180, 361, 3):
            x = round(17 + r * math.cos(math.radians(a))); y = round(32 + (r + 14) * math.sin(math.radians(a)) * 0.95)
            put(img, x, y, BONE if k % 2 == 0 else BONE_SHADE)
    return finish(img)


@item("g_daisies", G, "野菊叢", "flower", 1)
def g_daisies(f):
    return finish(flowers(16, 10, (250, 250, 240), (240, 200, 60), R(9)), (40, 80, 40))


@item("g_stinkflower", G, "臭臭花", "flower", 1, frames=2)
def g_stinkflower(f):
    img = flowers(16, 14, (150, 90, 160), (90, 60, 40), R(10), n=3, tall=4)
    for k in range(3):
        put(img, 4 + k * 4 + f, 2 - (k + f) % 2, (140, 200, 90))
    return finish(img, (40, 60, 40))


@item("g_toadstools", G, "毒菇叢", "flower", 1)
def g_toadstools(f):
    img = new(16, 10)
    for (x, h, c) in ((3, 4, (190, 60, 160)), (8, 6, (200, 50, 50)), (12, 3, (190, 60, 160))):
        rect(img, x, 10 - h, 1, h, (230, 220, 200)); disk(img, x, 10 - h, 2, c, 1); put(img, x, 9 - h, (250, 250, 250))
    return finish(img)


@item("g_thistle", G, "薊花", "flower", 1)
def g_thistle(f):
    return finish(flowers(16, 12, (170, 90, 200), (120, 60, 160), R(11), n=4, stem=(90, 130, 80), tall=5), (40, 60, 40))


@item("g_maneater", G, "食人花", "plant", 2, frames=2, fn="bite")
def g_maneater(f):
    return finish(chomper(22, 30, (60, 150, 60), f))


@item("g_pitcher", G, "巨型豬籠草", "plant", 2)
def g_pitcher(f):
    img = new(22, 30)
    for (x, h) in ((7, 22), (15, 16)):
        rect(img, x - 3, 30 - h, 6, h, (120, 170, 70)); rect(img, x - 2, 30 - h + 3, 4, h - 4, (150, 190, 80))
        rect(img, x - 4, 30 - h - 1, 8, 2, (180, 60, 70)); rect(img, x - 3, 30 - h - 4, 7, 3, (130, 180, 80))
    return finish(img)


@item("g_flyvine", G, "捕蠅藤", "plant", 2, frames=2)
def g_flyvine(f):
    img = new(22, 28)
    for y in range(28):
        x = 11 + int(5 * math.sin(y / 3 + f))
        put(img, x, y, (70, 120, 60)); put(img, x + 1, y, (90, 150, 70))
        if y % 6 == 2:
            disk(img, x + 3, y, 2, (100, 170, 70), 1); put(img, x + 3, y, (200, 60, 60))
    return finish(img)


@item("g_crowperch", G, "烏鴉棲架", "creature", 1, frames=2)
def g_crowperch(f):
    img = new(16, 24)
    rect(img, 7, 8, 2, 16, WOOD); rect(img, 3, 8, 10, 1, WOOD)
    bird(6, 6)(img, f)
    return finish(img)


@item("g_frogpuddle", G, "青蛙水坑", "creature", 1, frames=2)
def g_frogpuddle(f):
    img = new(20, 12)
    disk(img, 10, 8, 8, (80, 130, 160), 3)
    y = 6 - 3 * f
    rect(img, 8, y, 4, 2, (90, 170, 60)); put(img, 8, y - 1, (90, 170, 60)); put(img, 11, y - 1, (90, 170, 60))
    return finish(img, (40, 60, 50))


# ==== elves (50) ====================================================================================================
E = "elf"
BARK = (110, 84, 60)
SILVER = (206, 214, 222)
ELEAF = [(40, 110, 70), (70, 150, 90), (120, 196, 120)]
MOON = (220, 236, 255)
PETAL = (246, 190, 210)


@item("e_treehouse", E, "樹屋", "building", 4, frames=2)
def e_treehouse(f):
    img = new(36, 48)
    rect(img, 15, 20, 6, 28, BARK); rect(img, 15, 20, 2, 28, shade(BARK, 1.2))
    blob(img, 18, 10, 16, 10, ELEAF, R(20))
    rect(img, 8, 20, 20, 10, (170, 130, 90)); tri_roof(img, 18, 13, 11, 7, (110, 70, 50))
    rect(img, 12, 23, 3, 3, (250, 220, 120) if f == 0 else (255, 235, 150)); rect(img, 21, 23, 3, 3, (250, 220, 120))
    rect(img, 17, 25, 3, 5, (60, 40, 26))
    for y in range(30, 47, 3):  # the ladder
        rect(img, 24, y, 4, 1, WOOD_LIGHT)
    rect(img, 24, 30, 1, 17, WOOD); rect(img, 27, 30, 1, 17, WOOD)
    return finish(img, (30, 50, 30))


@item("e_moonpavilion", E, "月光亭", "building", 4, fn="moonrest")
def e_moonpavilion(f):
    img = new(36, 32)
    for x in (4, 30):
        rect(img, x, 12, 2, 18, SILVER)
    rect(img, 2, 28, 32, 3, (190, 196, 206))
    for y in range(10):
        half = 3 + y * 13 // 9
        rect(img, 18 - half, 2 + y, 2 * half, 1, (90, 110, 160) if y % 3 else (70, 90, 140))
    disk(img, 18, 1, 1, (240, 230, 160))
    disk(img, 18, 20, 3, MOON); disk(img, 19, 19, 3, (0, 0, 0, 0))
    return finish(img, (40, 50, 70))


@item("e_gazebo", E, "花瓣涼亭", "building", 2, frames=2)
def e_gazebo(f):
    img = new(28, 30)
    for x in (3, 23):
        rect(img, x, 10, 2, 20, (240, 236, 226))
    disk(img, 14, 7, 13, PETAL, 5); disk(img, 14, 6, 9, (252, 216, 228), 3)
    for k in range(4):
        put(img, 4 + k * 6 + f, 14 + (k * 5 + f * 3) % 10, PETAL)
    return finish(img, (90, 60, 80))


@item("e_shroomhouse", E, "蘑菇小屋", "building", 2)
def e_shroomhouse(f):
    img = new(26, 28)
    rect(img, 6, 13, 14, 15, (240, 230, 210)); rect(img, 11, 19, 4, 9, (110, 80, 60)); rect(img, 7, 16, 3, 3, (250, 220, 120))
    disk(img, 13, 9, 12, (90, 140, 200), 7); rect(img, 1, 10, 25, 3, (70, 120, 180))
    for (x, y) in ((7, 5), (16, 3), (20, 8)):
        disk(img, x, y, 1, (240, 246, 255))
    return finish(img)


@item("e_vinearch", E, "藤蔓拱門", "building", 2, blocks=False)
def e_vinearch(f):
    img = new(26, 30)
    for a in range(180, 361, 2):
        x = round(13 + 11 * math.cos(math.radians(a))); y = round(29 + 26 * math.sin(math.radians(a)))
        put(img, x, y, (70, 130, 70)); put(img, x + 1, y, (100, 160, 90))
        if a % 20 == 0:
            put(img, x - 1, y, PETAL)
    return finish(img, (30, 60, 40))


@item("e_observatory", E, "星象台", "building", 4, frames=2, fn="forecast")
def e_observatory(f):
    img = new(30, 40)
    rect(img, 7, 16, 16, 24, (200, 200, 210)); rect(img, 7, 16, 3, 24, (226, 226, 236))
    for y in range(8):
        half = int(9 * math.sqrt(1 - ((8 - y) / 8.5) ** 2))
        rect(img, 15 - half, 8 + y, 2 * half + 1, 1, (80, 100, 150))
    line(img, 16, 10, 24 - f * 2, 2 + f, (190, 170, 120)); rect(img, 23 - f * 2, 1 + f, 3, 2, (190, 170, 120))
    rect(img, 13, 32, 4, 8, (70, 70, 90))
    for (x, y) in ((3, 4), (27, 9), (6, 12)):
        put(img, x, y, (255, 250, 200))
    return finish(img, (40, 44, 60))


@item("e_shrine", E, "精靈神龕", "building", 2, frames=2, fn="heal")
def e_shrine(f):
    img = new(22, 28)
    rect(img, 4, 18, 14, 10, (190, 196, 200)); rect(img, 6, 10, 10, 8, (210, 216, 220)); tri_roof(img, 11, 3, 7, 7, (90, 150, 110))
    disk(img, 11, 14, 2, (170, 240, 190))
    for k in range(3):
        put(img, 5 + k * 6, 6 + (k + f) % 3 * 3, (220, 255, 220))
    return finish(img, (50, 60, 60))


@item("e_library", E, "樹根圖書館", "building", 4)
def e_library(f):
    img = new(40, 34)
    blob(img, 20, 22, 18, 11, [(90, 66, 46), (116, 86, 60), (140, 108, 76)], R(21))
    for (x, w) in ((8, 6), (26, 6)):
        rect(img, x, 18, w, 8, (60, 44, 30))
        for k in range(w):
            rect(img, x + k, 19 + (k % 2), 1, 6, [(180, 60, 60), (60, 100, 170), (200, 170, 70), (80, 150, 90)][k % 4])
    rect(img, 17, 22, 6, 10, (50, 36, 24))
    blob(img, 20, 6, 12, 5, ELEAF, R(22))
    return finish(img, (40, 30, 20))


@item("e_deerpark", E, "鹿園", "pen", 4, frames=2, fn="antlers")
def e_deerpark(f):
    def deer(cx, cy, flip):
        def draw(img, frame):
            c = (170, 120, 80)
            rect(img, cx - 4, cy - 2, 8, 4, c); rect(img, cx - 3, cy, 2, 1, (240, 230, 220))
            for lx in (-3, 3):
                rect(img, cx + lx, cy + 2, 1, 4, shade(c, 0.7))
            hx = cx + 5 * flip
            rect(img, hx - 1, cy - 6 + frame % 2, 3, 4, c)
            line(img, hx - 1, cy - 7, hx - 3, cy - 10, (220, 200, 160)); line(img, hx + 1, cy - 7, hx + 3, cy - 10, (220, 200, 160))
        return draw
    return pen(42, 28, (180, 160, 120), (210, 190, 150), [deer(14, 17, 1), deer(30, 18, -1)], f)


@item("e_rabbits", E, "兔籠", "pen", 2, frames=2, fn="fur")
def e_rabbits(f):
    def rabbit(cx, cy):
        def draw(img, frame):
            y = cy - (2 if (frame + cx) % 2 else 0)
            disk(img, cx, y, 2, (240, 236, 230)); rect(img, cx + 1, y - 4, 1, 3, (240, 236, 230)); rect(img, cx + 2, y - 4, 1, 3, (230, 200, 200))
            put(img, cx + 2, y - 1, (30, 20, 20))
        return draw
    return pen(28, 22, (180, 160, 120), (210, 190, 150), [rabbit(9, 13), rabbit(18, 14)], f, ground=(120, 170, 90))


@item("e_beegarden", E, "蜂箱園", "pen", 2, frames=2, fn="honey")
def e_beegarden(f):
    img = new(28, 22)
    for x in (4, 16):
        hive = T.beehive(R(23 + x))
        img.alpha_composite(hive.crop((0, 0, min(hive.width, 12), hive.height)), (x, 22 - hive.height))
    for k in range(5):
        put(img, 3 + k * 5 + f * 2, 2 + (k * 3 + f) % 6, (240, 200, 40))
    return img


@item("e_sheep", E, "白羊花籬", "pen", 4, frames=2, fn="sheep")
def e_sheep(f):
    img = pen(40, 24, (110, 150, 90), (140, 180, 110), [sheep(12, 13), sheep(27, 14, -1)], f)
    for x in range(2, 38, 5):
        put(img, x, 18, PETAL); put(img, x + 2, 19, (250, 240, 150))
    return img


@item("e_cows", E, "花環牛欄", "pen", 4, frames=2, fn="cows")
def e_cows(f):
    img = pen(44, 26, (110, 150, 90), (140, 180, 110), [cow(15, 15, 1, ((240, 220, 180), (200, 150, 90))), cow(31, 16, -1)], f)
    for x in range(1, 43, 4):
        put(img, x, 3, PETAL)
    return img


@item("e_swanpond", E, "天鵝池", "pen", 4, frames=2)
def e_swanpond(f):
    img = new(40, 20)
    disk(img, 20, 12, 18, (80, 140, 190), 7); disk(img, 20, 12, 15, (100, 160, 210), 5)
    for (x, d) in ((14 + f, 1), (26 - f, -1)):
        disk(img, x, 12, 3, (250, 250, 250), 2); rect(img, x + 3 * d, 7, 1, 5, (250, 250, 250)); put(img, x + 3 * d + d, 7, (240, 140, 40))
    return finish(img, (40, 70, 90))


@item("e_teatable", E, "樹墩茶几", "furniture", 1)
def e_teatable(f):
    img = new(16, 12)
    rect(img, 4, 5, 8, 7, BARK); rect(img, 2, 4, 12, 2, (190, 150, 110))
    rect(img, 4, 2, 3, 2, (240, 240, 240)); rect(img, 9, 2, 2, 2, (200, 230, 240))
    return finish(img)


@item("e_leafhammock", E, "葉片吊床", "furniture", 2, frames=2)
def e_leafhammock(f):
    img = g_hammock(f)
    for x in range(4, 26, 2):
        y = 6 + int((3 + f) * math.sin(math.pi * (x - 3) / 24))
        put(img, x, y + 1, (90, 170, 90))
    return img


@item("e_harp", E, "豎琴", "furniture", 1, frames=2, fn="music")
def e_harp(f):
    img = new(16, 22)
    for y in range(4, 22):
        put(img, 3 + (22 - y) // 5, y, (220, 180, 80))
    line(img, 4, 4, 13, 6, (220, 180, 80)); rect(img, 12, 6, 2, 16, (200, 160, 70))
    for x in range(5, 12, 2):
        line(img, x, 6, x, 20, (240, 240, 220))
    if f:
        put(img, 14, 1, (250, 250, 250)); put(img, 15, 0, (250, 250, 250))
    return finish(img, (80, 60, 30))


@item("e_spinner", E, "紡紗車", "furniture", 1, frames=2)
def e_spinner(f):
    img = new(18, 18)
    ring(img, 8, 7, 6, (150, 110, 70)); put(img, 8, 7, WOOD)
    for a in range(0 + f * 30, 360, 60):
        line(img, 8, 7, round(8 + 6 * math.cos(math.radians(a))), round(7 + 6 * math.sin(math.radians(a))), WOOD_LIGHT)
    rect(img, 4, 14, 12, 2, WOOD); rect(img, 14, 8, 2, 8, WOOD); rect(img, 13, 5, 4, 3, (240, 230, 210))
    return finish(img)


@item("e_swing", E, "花環鞦韆", "furniture", 2, frames=2)
def e_swing(f):
    img = new(24, 28)
    rect(img, 2, 0, 20, 2, BARK)
    sx = 8 + (3 if f else -1)
    line(img, 8, 2, sx, 20, (220, 210, 180)); line(img, 16, 2, sx + 8, 20, (220, 210, 180))
    rect(img, sx - 1, 20, 10, 2, WOOD_LIGHT)
    for k in range(4):
        put(img, 8 + k * 2, 2, PETAL)
    return finish(img)


@item("e_bench", E, "藤編長椅", "furniture", 2)
def e_bench(f):
    img = new(24, 12)
    rect(img, 1, 1, 22, 4, (190, 160, 110)); rect(img, 1, 6, 22, 3, (200, 170, 120))
    for x in range(2, 22, 2):
        put(img, x, 2 + x % 2, (150, 120, 80)); put(img, x, 7, (160, 130, 90))
    rect(img, 2, 9, 2, 3, BARK); rect(img, 20, 9, 2, 3, BARK)
    return finish(img)


@item("e_crystallamp", E, "水晶燈台", "furniture", 1, frames=2)
def e_crystallamp(f):
    img = new(12, 22)
    rect(img, 5, 8, 2, 14, SILVER)
    for y in range(6):
        h = 3 - abs(y - 3)
        rect(img, 6 - h, 1 + y, 2 * h + 1, 1, (150, 230, 250) if f == 0 else (190, 245, 255))
    return finish(img, (40, 60, 80))


@item("e_bookshelf", E, "書架", "furniture", 1)
def e_bookshelf(f):
    img = new(14, 20)
    rect(img, 1, 0, 12, 20, BARK)
    for y in (2, 8, 14):
        for x in range(2, 12):
            rect(img, x, y, 1, 5, [(180, 60, 60), (60, 100, 170), (200, 170, 70), (80, 150, 90), (150, 90, 160)][(x + y) % 5])
    return finish(img)


@item("e_moonpool", E, "月光池", "scene", 4, frames=2)
def e_moonpool(f):
    img = new(40, 20)
    disk(img, 20, 11, 18, (190, 196, 206), 8); disk(img, 20, 11, 16, (60, 90, 150), 6)
    disk(img, 20, 11, 4, MOON, 2)
    for k in range(4):
        put(img, 10 + k * 7, 9 + (k + f) % 2 * 3, (230, 240, 255))
    return finish(img, (40, 50, 70))


@item("e_mosspath", E, "苔石小徑", "scene", 2, blocks=False)
def e_mosspath(f):
    img = new(30, 12)
    for (x, y) in ((3, 6), (10, 4), (17, 7), (24, 5)):
        disk(img, x, y, 3, STONE[1], 2); put(img, x - 1, y - 1, (90, 150, 80)); put(img, x + 1, y, (90, 150, 80))
    return finish(img, (50, 60, 50))


@item("e_meditstone", E, "冥想石台", "scene", 2, fn="meditate")
def e_meditstone(f):
    img = new(26, 12)
    rect(img, 2, 5, 22, 6, STONE[1]); rect(img, 2, 5, 22, 2, STONE[2]); rect(img, 2, 10, 22, 1, STONE[0])
    for (x, y) in ((6, 4), (18, 3)):
        put(img, x, y, (90, 160, 90))
    return finish(img)


@item("e_target", E, "射箭靶", "scene", 2, fn="archery")
def e_target(f):
    img = new(16, 24)
    rect(img, 4, 12, 1, 12, WOOD); rect(img, 11, 12, 1, 12, WOOD)
    disk(img, 8, 9, 6, (230, 220, 190)); disk(img, 8, 9, 4, (70, 140, 90)); disk(img, 8, 9, 2, (220, 190, 70))
    line(img, 1, 6, 7, 9, (180, 150, 110)); put(img, 1, 5, (240, 240, 240))
    return finish(img)


@item("e_waterfall", E, "小瀑布", "scene", 4, frames=2)
def e_waterfall(f):
    img = new(32, 36)
    blob(img, 8, 16, 7, 15, STONE, R(24)); blob(img, 24, 16, 7, 15, STONE, R(25))
    for y in range(4, 30):
        for x in range(13, 19):
            put(img, x, y, (140, 200, 240) if (y + x + f * 2) % 4 else (230, 245, 255))
    disk(img, 16, 31, 12, (90, 150, 200), 4)
    for k in range(3):
        put(img, 10 + k * 6, 30 - (k + f) % 2, (240, 250, 255))
    return finish(img, (40, 60, 70))


@item("e_flowerbed", E, "花圃", "scene", 2)
def e_flowerbed(f):
    img = new(28, 14)
    rect(img, 1, 6, 26, 8, (110, 80, 50)); rect(img, 1, 6, 26, 1, (140, 110, 70))
    fl = flowers(28, 10, PETAL, (250, 230, 120), R(26), n=8)
    img.alpha_composite(fl, (0, 0))
    return finish(img)


@item("e_silvertree", E, "銀葉樹", "tree", 2, frames=2)
def e_silvertree(f):
    img = leafy(26, 36, (200, 200, 210), [(150, 170, 190), (196, 210, 224), (236, 244, 252)], R(27))
    put(img, 6 + f * 8, 8 + f * 4, (255, 255, 255))
    return finish(img, (60, 70, 90))


@item("e_cherry", E, "櫻花樹", "tree", 4, frames=2)
def e_cherry(f):
    img = leafy(34, 40, (110, 70, 60), [(220, 140, 170), (246, 180, 200), (255, 220, 230)], R(28))
    for k in range(4):
        put(img, 4 + k * 8 + f, 30 + (k + f) % 3 * 3, PETAL)
    return finish(img, (90, 50, 60))


@item("e_lanterntree", E, "燈籠樹", "tree", 2, frames=2)
def e_lanterntree(f):
    glow = (250, 230, 140) if f == 0 else (255, 245, 180)
    img = leafy(26, 36, BARK, ELEAF, R(29), dots=[(-6, 10, glow), (5, 7, glow), (0, 15, glow), (7, 14, glow)])
    return finish(img, (30, 50, 30))


@item("e_willow", E, "垂柳", "tree", 4, frames=2)
def e_willow(f):
    return finish(leafy(34, 40, BARK, [(70, 130, 70), (100, 160, 90), (140, 196, 120)], R(30), shape="droop", frame=f), (30, 50, 30))


@item("e_heartoak", E, "古樹之心", "tree", 4, fn="growth")
def e_heartoak(f):
    img = new(40, 48)
    rect(img, 15, 24, 10, 24, (100, 74, 50)); rect(img, 15, 24, 3, 24, (130, 100, 70))
    for (x, d) in ((14, -1), (25, 1)):
        for k in range(6):
            put(img, x + d * k, 47 - k // 2, (100, 74, 50))
    blob(img, 20, 13, 19, 12, [(30, 90, 50), (50, 120, 70), (90, 170, 100)], R(31))
    disk(img, 20, 34, 2, (200, 255, 200))
    return finish(img, (30, 40, 30))


@item("e_leafsign", E, "葉形路牌", "sign", 1)
def e_leafsign(f):
    img = new(16, 20)
    rect(img, 7, 8, 2, 12, BARK)
    disk(img, 8, 5, 7, (90, 160, 90), 4); line(img, 2, 5, 14, 5, (60, 120, 70))
    return finish(img)


@item("e_runestone", E, "精靈文石碑", "sign", 2, frames=2)
def e_runestone(f):
    img = new(16, 26)
    rect(img, 2, 4, 12, 22, STONE[1]); rect(img, 3, 2, 10, 2, STONE[1]); rect(img, 2, 4, 2, 22, STONE[2])
    glow = (150, 240, 220) if f == 0 else (200, 255, 240)
    for (x, y) in ((6, 7), (9, 10), (6, 14), (9, 18)):
        rect(img, x, y, 2, 2, glow)
    return finish(img)


@item("e_vinelamp", E, "藤蔓燈柱", "sign", 1, frames=2)
def e_vinelamp(f):
    img = new(12, 26)
    rect(img, 5, 4, 2, 22, (90, 110, 90))
    for y in range(6, 24, 4):
        put(img, 4, y, (90, 160, 90)); put(img, 7, y + 2, (90, 160, 90))
    rect(img, 3, 0, 6, 5, (230, 250, 200) if f == 0 else (250, 255, 230))
    return finish(img)


@item("e_chimes", E, "風鈴", "sign", 1, frames=2)
def e_chimes(f):
    img = new(14, 22)
    rect(img, 6, 0, 1, 22, BARK); rect(img, 2, 2, 10, 1, BARK)
    for (x, l) in ((3, 6), (6, 8), (9, 5), (11, 7)):
        rect(img, x + (f if x % 2 else -f), 3, 1, l, (200, 220, 230))
    return finish(img)


@item("e_antlers", E, "鹿角掛飾", "bone", 1)
def e_antlers(f):
    img = new(18, 16)
    rect(img, 8, 6, 2, 10, BARK)
    for d in (-1, 1):
        line(img, 9, 6, 9 + d * 7, 0, (220, 200, 160)); line(img, 9 + d * 3, 4, 9 + d * 4, 0, (220, 200, 160))
    return finish(img)


@item("e_fossil", E, "古龍化石", "bone", 4)
def e_fossil(f):
    img = new(44, 22)
    for x in range(4, 40):
        y = 14 - int(5 * math.sin((x - 4) / 11))
        put(img, x, y, BONE)
        if x % 3 == 0 and 10 < x < 34:
            rect(img, x, y + 1, 1, 5, BONE_SHADE)
    disk(img, 39, 9, 3, BONE); put(img, 40, 8, INK)
    rect(img, 0, 18, 44, 4, (150, 130, 100))
    return finish(img)


@item("e_bonevase", E, "白骨花瓶", "bone", 1)
def e_bonevase(f):
    img = new(12, 18)
    disk(img, 6, 13, 4, BONE, 4); rect(img, 4, 6, 4, 4, BONE)
    img.alpha_composite(flowers(12, 8, PETAL, (250, 230, 120), R(32), n=3, tall=2), (0, 0))
    return finish(img)


@item("e_moonflower", E, "月光花", "flower", 1, frames=2)
def e_moonflower(f):
    return finish(flowers(16, 12, MOON if f else (180, 190, 220), (250, 250, 200), R(33), n=4, tall=4), (40, 60, 70))


@item("e_lilyvalley", E, "鈴蘭", "flower", 1)
def e_lilyvalley(f):
    img = new(16, 12)
    for x in (4, 9, 13):
        line(img, x, 12, x - 2, 3, (70, 130, 70))
        for k in range(3):
            put(img, x - 2 + k, 4 + k * 2, (250, 250, 250))
    return finish(img, (40, 60, 40))


@item("e_bluerose", E, "藍玫瑰", "flower", 1)
def e_bluerose(f):
    return finish(flowers(16, 12, (70, 110, 220), (40, 70, 170), R(34), n=4, tall=4), (30, 40, 70))


@item("e_sunflower", E, "向日葵", "flower", 1, frames=2)
def e_sunflower(f):
    img = new(14, 22)
    rect(img, 6, 8, 2, 14, (80, 140, 60)); rect(img, 3, 14, 3, 2, (90, 160, 70))
    disk(img, 7 + f, 5, 4, (250, 200, 40)); disk(img, 7 + f, 5, 2, (120, 80, 40))
    return finish(img)


@item("e_treant", E, "樹人", "plant", 4, frames=2, fn="guard", blocks=False)
def e_treant(f):
    img = new(30, 40)
    rect(img, 10, 14, 10, 20, (110, 84, 60)); rect(img, 10, 14, 3, 20, (140, 110, 80))
    rect(img, 10 + f, 34, 3, 6, (110, 84, 60)); rect(img, 17 - f, 34, 3, 6, (110, 84, 60))
    line(img, 10, 18, 3, 12 + f * 2, (110, 84, 60)); line(img, 19, 18, 27, 12 + (1 - f) * 2, (110, 84, 60))
    blob(img, 15, 9, 12, 8, ELEAF, R(35))
    rect(img, 12, 20, 2, 2, (250, 230, 120)); rect(img, 16, 20, 2, 2, (250, 230, 120)); rect(img, 13, 25, 4, 1, (60, 40, 30))
    return finish(img, (30, 40, 30))


@item("e_buglotus", E, "巨型捕蟲蓮", "plant", 2, frames=2)
def e_buglotus(f):
    return finish(chomper(24, 26, (220, 120, 180), f, inside=(250, 220, 100), teeth=(250, 230, 240)))


@item("e_singingflower", E, "會唱歌的花", "plant", 2, frames=2, fn="lullaby")
def e_singingflower(f):
    img = new(22, 30)
    rect(img, 10, 14, 2, 16, (80, 140, 60)); rect(img, 6, 22, 4, 2, (90, 160, 70)); rect(img, 12, 19, 4, 2, (90, 160, 70))
    for a in range(0, 360, 45):
        disk(img, round(11 + 6 * math.cos(math.radians(a + f * 20))), round(8 + 6 * math.sin(math.radians(a + f * 20))), 2, (250, 170, 60))
    disk(img, 11, 8, 3, (250, 230, 140)); rect(img, 10, 8 + f, 3, 2, (150, 60, 60))
    put(img, 18 + f, 1, (255, 255, 255)); put(img, 19 + f, 0, (255, 255, 255))
    return finish(img)


@item("e_butterflies", E, "蝴蝶花叢", "creature", 1, frames=2)
def e_butterflies(f):
    img = T.bush("forest", R(36), 6)
    for (x, y, c) in ((3, 2, (250, 160, 60)), (10, 1, (130, 170, 250))):
        put(img, x + f, y, c); put(img, x + 2 + f, y, c); put(img, x + 1 + f, y + 1, (40, 30, 30))
    return img


@item("e_fireflies", E, "螢火蟲草", "creature", 1, frames=2)
def e_fireflies(f):
    img = new(16, 16)
    for (x, h) in ((3, 8), (7, 11), (11, 7)):
        line(img, x, 15, x + 1, 15 - h, (80, 140, 70))
    for k in range(4):
        put(img, 2 + k * 4, 2 + (k * 3 + f * 2) % 7, (230, 255, 120))
    return finish(img, (30, 50, 30))


@item("e_squirreltree", E, "松鼠樹", "creature", 2, frames=2)
def e_squirreltree(f):
    img = leafy(24, 34, BARK, ELEAF, R(37))
    y = 16 + f * 8
    rect(img, 13, y, 3, 3, (196, 112, 52)); rect(img, 15, y - 3, 2, 4, (196, 112, 52)); put(img, 13, y, (30, 20, 20))
    return finish(img, (30, 50, 30))


# ==== the undead (50) ===============================================================================================
U = "undead"
GRAVE = [(84, 86, 98), (120, 122, 136), (150, 152, 166)]
SOUL = (130, 250, 220)
DARKWOOD = (70, 56, 50)
VIOLET = (110, 80, 150)


def tombstone(img, x, y, w=6, h=8, cross=False):
    rect(img, x, y + 2, w, h - 2, GRAVE[1]); rect(img, x + 1, y + 1, w - 2, 1, GRAVE[1]); rect(img, x + 2, y, w - 4, 1, GRAVE[1])
    rect(img, x, y + 2, 1, h - 2, GRAVE[2])
    if cross:
        rect(img, x + w // 2, y + 2, 1, 4, GRAVE[0]); rect(img, x + w // 2 - 1, y + 3, 3, 1, GRAVE[0])


@item("u_chapel", U, "小禮拜堂廢墟", "building", 4)
def u_chapel(f):
    img = new(36, 40)
    rect(img, 4, 16, 28, 24, GRAVE[1]); rect(img, 4, 16, 3, 24, GRAVE[2])
    tri_roof(img, 18, 2, 15, 14, (70, 60, 80))
    rect(img, 22, 4, 8, 8, (0, 0, 0, 0))  # the roof fell in there
    rect(img, 15, 26, 6, 14, (30, 26, 34)); disk(img, 18, 26, 3, (30, 26, 34))
    rect(img, 9, 22, 3, 6, (160, 120, 200)); rect(img, 25, 22, 3, 6, (160, 120, 200))
    for k in range(5):
        put(img, 6 + k * 6, 39 - (k % 2), (80, 120, 70))
    return finish(img, (30, 28, 36))


@item("u_crypt", U, "地下墓穴入口", "building", 2, frames=2, fn="door")
def u_crypt(f):
    img = new(28, 22)
    rect(img, 2, 6, 24, 16, GRAVE[1]); tri_roof(img, 14, 0, 13, 6, GRAVE[0])
    rect(img, 9, 10, 10, 12, (20, 18, 26))
    for k in range(3):
        put(img, 10 + k * 3 + f, 9 - (k + f) % 2, (200, 210, 220, 160))
    return finish(img, (30, 28, 36))


@item("u_bonetower", U, "骨塔", "building", 2)
def u_bonetower(f):
    img = new(18, 40)
    for y in range(6, 40):
        w = 4 + (40 - y) // 8
        rect(img, 9 - w // 2 + (y % 3) - 1, y, 2, 1, BONE); rect(img, 9 + w // 2 - (y % 3), y, 2, 1, BONE_SHADE)
        if y % 4 == 0:
            rect(img, 9 - w // 2, y, w + 1, 1, BONE)
    disk(img, 9, 4, 3, BONE); put(img, 8, 4, INK); put(img, 10, 4, INK)
    return finish(img)


@item("u_belltower", U, "鐘樓", "building", 4, frames=2, fn="bell")
def u_belltower(f):
    img = new(22, 48)
    rect(img, 4, 14, 14, 34, GRAVE[1]); rect(img, 4, 14, 3, 34, GRAVE[2])
    tri_roof(img, 11, 1, 8, 9, (60, 50, 70))
    rect(img, 6, 12, 10, 8, (24, 20, 30))
    disk(img, 11 + (1 if f else -1), 16, 3, (190, 150, 60), 3)
    rect(img, 9, 38, 4, 10, (24, 20, 30))
    return finish(img, (30, 28, 36))


@item("u_throne", U, "骨頭王座", "building", 2)
def u_throne(f):
    img = new(22, 30)
    rect(img, 4, 2, 14, 22, BONE_SHADE); rect(img, 6, 4, 10, 18, BONE)
    for (x, y) in ((4, 1), (11, 0), (17, 1)):
        disk(img, x, y + 2, 2, BONE); put(img, x - 1, y + 2, INK); put(img, x + 1, y + 2, INK)
    rect(img, 2, 18, 18, 4, BONE_SHADE); rect(img, 4, 22, 2, 8, BONE); rect(img, 16, 22, 2, 8, BONE)
    rect(img, 6, 16, 10, 3, (120, 30, 50))
    return finish(img)


@item("u_hauntedhouse", U, "鬼屋", "building", 4, frames=2)
def u_hauntedhouse(f):
    img = hut(30, 20, (80, 72, 86), (50, 44, 60), roof_h=14, window=False)
    for (x, lit) in ((7, f == 0), (24, f == 1)):
        rect(img, x, 22, 4, 4, (220, 240, 160) if lit else (40, 36, 50))
        if lit:
            rect(img, x + 1, 23, 2, 3, (60, 60, 80))
    line(img, 5, 20, 12, 15, (60, 54, 66))
    return finish(img, (24, 20, 30))


@item("u_coffinstore", U, "靈柩倉庫", "building", 4)
def u_coffinstore(f):
    img = hut(32, 14, (90, 70, 60), (60, 50, 50), roof_h=10, window=False, door=False)
    for x in (4, 13, 22):
        rect(img, x, 20, 7, 10, DARKWOOD); rect(img, x + 1, 20, 5, 1, (110, 90, 80)); rect(img, x + 3, 23, 1, 4, (200, 190, 160))
    return finish(img, (30, 24, 24))


@item("u_alchemy", U, "鍊金台", "building", 2, frames=2, fn="dust")
def u_alchemy(f):
    img = new(26, 20)
    rect(img, 2, 10, 22, 3, DARKWOOD); rect(img, 3, 13, 2, 7, DARKWOOD); rect(img, 21, 13, 2, 7, DARKWOOD)
    for (x, c) in ((5, (120, 240, 140)), (11, (200, 100, 240)), (17, (120, 200, 250))):
        rect(img, x, 5, 3, 5, c); rect(img, x + 1, 3, 1, 2, (220, 220, 230))
        put(img, x + 1, 1 - f + 1, c)
    return finish(img)


@item("u_horses", U, "骷髏馬廄", "pen", 4, frames=2)
def u_horses(f):
    def horse(cx, cy, flip):
        def draw(img, frame):
            rect(img, cx - 6, cy - 2, 12, 1, BONE)
            for k in range(-5, 6, 2):
                rect(img, cx + k, cy - 1, 1, 3, BONE_SHADE)
            for lx in (-5, -3, 3, 5):
                rect(img, cx + lx, cy + 2, 1, 5 - (frame % 2 if lx == -3 else 0), BONE)
            hx = cx + 7 * flip
            line(img, cx + 5 * flip, cy - 2, hx, cy - 7, BONE)
            rect(img, hx - (2 if flip > 0 else 0), cy - 8, 4, 3, BONE); put(img, hx, cy - 7, SOUL)
        return draw
    return pen(44, 28, DARKWOOD, (100, 84, 76), [horse(15, 16, 1), horse(31, 17, -1)], f)


@item("u_bonedogs", U, "骨犬窩", "pen", 2, frames=2, fn="bonedog")
def u_bonedogs(f):
    img = new(30, 20)
    rect(img, 2, 6, 12, 12, DARKWOOD); tri_roof(img, 8, 1, 7, 6, (60, 50, 50))
    disk(img, 8, 14, 3, (20, 16, 20))
    dog(22, 14, -1, bony=True)(img, f)
    return finish(img)


@item("u_ghostsheep", U, "幽靈羊圈", "pen", 4, frames=2, fn="sheep")
def u_ghostsheep(f):
    pale = ((180, 230, 220), (210, 245, 240), (240, 255, 252))
    return pen(40, 24, DARKWOOD, (100, 84, 76), [sheep(12, 13, wool=pale, face=(90, 160, 150)), sheep(27, 14, -1, wool=pale, face=(90, 160, 150))], f)


@item("u_bonecows", U, "骨牛欄", "pen", 4, frames=2)
def u_bonecows(f):
    return pen(44, 26, DARKWOOD, (100, 84, 76), [cow(15, 15, 1, (BONE, (150, 140, 120))), cow(31, 16, -1, (BONE, (150, 140, 120)))], f)


@item("u_batcave", U, "蝙蝠洞", "pen", 2, frames=2, fn="dust")
def u_batcave(f):
    img = new(30, 24)
    blob(img, 15, 15, 14, 9, GRAVE, R(40))
    disk(img, 15, 18, 6, (16, 12, 20), 5)
    bat(8 + f * 4, 4)(img, f); bat(22 - f * 3, 2 + f)(img, f + 1)
    return finish(img, (24, 20, 30))


@item("u_crowtower", U, "烏鴉塔", "pen", 2, frames=2)
def u_crowtower(f):
    img = new(18, 36)
    rect(img, 6, 8, 6, 28, DARKWOOD); rect(img, 3, 6, 12, 3, (60, 50, 50))
    for y in (14, 22):
        rect(img, 8, y, 2, 3, (16, 12, 16))
    bird(9, 3)(img, f)
    return finish(img)


@item("u_coffinbed", U, "棺材床", "furniture", 1, frames=2, fn="graverest")
def u_coffinbed(f):
    img = new(20, 10)
    rect(img, 1, 3, 18, 6, DARKWOOD); rect(img, 3, 2, 14, 1, DARKWOOD)
    if f:
        rect(img, 1, 0, 9, 2, (90, 72, 64)); rect(img, 3, 4, 3, 2, BONE)
    else:
        rect(img, 1, 2, 18, 2, (90, 72, 64)); rect(img, 9, 3, 1, 3, (200, 190, 160))
    return finish(img)


@item("u_candelabra", U, "燭台", "furniture", 1, frames=2)
def u_candelabra(f):
    img = new(14, 20)
    rect(img, 6, 6, 2, 14, (150, 130, 80)); rect(img, 2, 10, 10, 1, (150, 130, 80)); rect(img, 4, 18, 6, 2, (150, 130, 80))
    for x in (2, 6, 11):
        rect(img, x, 5 + (x == 6) * 0, 1, 5 if x != 6 else 1, (240, 236, 220))
        put(img, x, 3 + (x + f) % 2, (250, 200, 80))
    return finish(img)


@item("u_bonechair", U, "骨椅", "furniture", 1)
def u_bonechair(f):
    img = new(14, 18)
    rect(img, 2, 1, 10, 10, BONE_SHADE); rect(img, 3, 2, 8, 8, BONE)
    put(img, 5, 4, INK); put(img, 8, 4, INK)
    rect(img, 1, 10, 12, 2, BONE); rect(img, 2, 12, 1, 6, BONE); rect(img, 11, 12, 1, 6, BONE)
    return finish(img)


@item("u_organ", U, "破管風琴", "furniture", 2)
def u_organ(f):
    img = new(28, 30)
    for k in range(9):
        h = 12 + abs(4 - k) * 2
        rect(img, 2 + k * 3, 30 - 12 - h, 2, h, (170, 150, 110) if k % 2 else (140, 120, 90))
    rect(img, 1, 18, 26, 12, DARKWOOD); rect(img, 3, 21, 22, 2, BONE)
    put(img, 14, 6, (0, 0, 0, 0))
    return finish(img)


@item("u_soulpot", U, "煉魂鍋", "furniture", 2, frames=2, fn="souls")
def u_soulpot(f):
    img = g_cauldron(f)
    for x in range(4, 16):
        put(img, x, 9, (90, 240, 160))
    for k in range(3):
        put(img, 6 + k * 3 + f, 6 - (k + f) % 2, SOUL)
    return img


@item("u_mirror", U, "碎鏡子", "furniture", 1, frames=2)
def u_mirror(f):
    img = new(14, 22)
    rect(img, 2, 1, 10, 18, (110, 90, 60)); rect(img, 3, 2, 8, 16, (150, 170, 190))
    line(img, 4, 4, 9, 14, (220, 230, 240)); line(img, 9, 5, 5, 11, (220, 230, 240))
    if f:
        disk(img, 7, 9, 2, (220, 240, 240, 200)); put(img, 6, 9, INK); put(img, 8, 9, INK)
    rect(img, 5, 19, 4, 3, (110, 90, 60))
    return finish(img)


@item("u_rocker", U, "自己會搖的搖椅", "furniture", 1, frames=2)
def u_rocker(f):
    img = new(16, 18)
    lean = 1 if f else -1
    rect(img, 4 + lean, 1, 2, 11, DARKWOOD); rect(img, 4, 10, 9, 2, DARKWOOD); rect(img, 11, 7, 2, 5, DARKWOOD)
    for x in range(1, 15):
        put(img, x, 15 + ((x - 8) ** 2) // 18 * (1 if lean > 0 else 1) - (1 if (x < 8) == (lean > 0) else 0), DARKWOOD)
    return finish(img)


@item("u_graves", U, "墓碑群", "scene", 2)
def u_graves(f):
    img = new(30, 16)
    tombstone(img, 2, 4, cross=True); tombstone(img, 12, 2, w=7, h=10); tombstone(img, 22, 5, cross=True)
    rect(img, 0, 13, 30, 3, (90, 74, 56))
    return finish(img, (30, 28, 36))


@item("u_bonepath", U, "骨頭小徑", "scene", 2, blocks=False)
def u_bonepath(f):
    img = new(30, 10)
    for (x, y) in ((3, 4), (11, 6), (19, 3), (26, 6)):
        rect(img, x - 2, y, 5, 1, BONE); rect(img, x - 3, y - 1, 1, 3, BONE_SHADE); rect(img, x + 3, y - 1, 1, 3, BONE_SHADE)
    return finish(img)


@item("u_bog", U, "毒沼", "scene", 4, frames=2, fn="slow", blocks=False)
def u_bog(f):
    img = new(38, 16)
    disk(img, 19, 9, 17, (70, 110, 60), 6); disk(img, 19, 9, 14, (90, 140, 60), 4)
    for (x, y) in ((10, 8), (22, 10), (28, 7)):
        disk(img, x + f, y - f, 1, (170, 220, 90))
    return finish(img, (30, 40, 26))


@item("u_soulfire", U, "靈魂篝火", "scene", 2, frames=2, fn="nightmight")
def u_soulfire(f):
    img = T.firepit("swamp", R(41))
    w = img.width
    rect(img, w // 2 - 2, 2, 4, 5, (80, 200, 240)); rect(img, w // 2 - 1, 2 - f + 1, 2, 3, (200, 250, 255))
    return img


@item("u_opengrave", U, "打開的墓穴", "scene", 2)
def u_opengrave(f):
    img = new(24, 18)
    tombstone(img, 9, 0, cross=True)
    rect(img, 3, 9, 18, 7, (40, 30, 26)); rect(img, 3, 9, 18, 1, (100, 80, 60))
    rect(img, 0, 12, 3, 5, (110, 86, 64)); rect(img, 21, 11, 3, 6, (110, 86, 64))
    rect(img, 22, 5, 1, 7, WOOD); rect(img, 21, 11, 3, 2, (150, 150, 160))  # a spade
    return finish(img, (30, 28, 36))


@item("u_sarcophagus", U, "石棺", "scene", 2)
def u_sarcophagus(f):
    img = new(28, 14)
    rect(img, 2, 4, 24, 10, GRAVE[1]); rect(img, 1, 2, 26, 3, GRAVE[2])
    rect(img, 10, 6, 8, 5, GRAVE[0]); disk(img, 14, 8, 2, BONE)
    return finish(img, (30, 28, 36))


@item("u_deadtree", U, "枯樹", "tree", 2)
def u_deadtree(f):
    return T.dead_tree("swamp", R(42), 34)


@item("u_lanterntree", U, "吊燈枯樹", "tree", 2, frames=2)
def u_lanterntree(f):
    img = T.dead_tree("forest", R(43), 34)
    w = img.width
    for (x, y) in ((w // 2 - 7, 10), (w // 2 + 6, 7)):
        line(img, x, y, x, y + 3, (60, 60, 60))
        rect(img, x - 1 + f, y + 4, 3, 4, (60, 50, 50)); put(img, x + f, y + 5, SOUL)
    return img


@item("u_blackwillow", U, "黑柳", "tree", 4, frames=2)
def u_blackwillow(f):
    return finish(leafy(34, 40, (50, 44, 50), [(36, 40, 56), (54, 58, 80), (80, 84, 110)], R(44), shape="droop", frame=f), (16, 14, 20))


@item("u_bonetree", U, "骨枝樹", "tree", 2)
def u_bonetree(f):
    img = new(26, 36)
    rect(img, 12, 14, 3, 22, BONE_SHADE); rect(img, 12, 14, 1, 22, BONE)
    for (d, y, l) in ((-1, 16, 8), (1, 12, 9), (-1, 8, 6), (1, 20, 6)):
        line(img, 13, y, 13 + d * l, y - l // 2, BONE)
        disk(img, 13 + d * l, y - l // 2, 1, BONE)
    disk(img, 13, 10, 3, BONE); put(img, 12, 10, INK); put(img, 14, 10, INK)
    return finish(img)


@item("u_pumpkinvine", U, "南瓜藤", "tree", 2, frames=2)
def u_pumpkinvine(f):
    img = new(30, 16)
    for x in range(1, 29):
        put(img, x, 8 + int(2 * math.sin(x / 3)), (70, 120, 60))
    for (x, y) in ((6, 10), (17, 11), (25, 9)):
        disk(img, x, y, 3, (230, 120, 30), 2)
        put(img, x - 1, y, (250, 220, 80) if (x + f) % 2 else (180, 80, 20)); put(img, x + 1, y, (250, 220, 80) if (x + f) % 2 else (180, 80, 20))
        rect(img, x - 1, y + 1, 3, 1, (250, 220, 80) if (x + f) % 2 else (180, 80, 20))
    return finish(img, (40, 30, 20))


@item("u_gate", U, "墓園鐵門", "sign", 2, blocks=False)
def u_gate(f):
    img = new(30, 26)
    for x in (1, 27):
        rect(img, x, 4, 2, 22, GRAVE[1])
    for x in range(4, 27, 3):
        rect(img, x, 8, 1, 18, (50, 50, 60)); put(img, x, 7, (80, 80, 90))
    for a in range(180, 361, 6):
        put(img, round(15 + 11 * math.cos(math.radians(a))), round(10 + 6 * math.sin(math.radians(a))), (50, 50, 60))
    return finish(img, (24, 20, 30))


@item("u_keepout", U, "「生者止步」牌", "sign", 1)
def u_keepout(f):
    img = new(18, 20)
    rect(img, 8, 9, 2, 11, DARKWOOD)
    rect(img, 1, 2, 16, 8, (120, 100, 80))
    for (x, y) in ((3, 4), (6, 5), (9, 4), (12, 5)):
        rect(img, x, y, 2, 3, (170, 40, 50))
    return finish(img)


@item("u_wisplamp", U, "鬼火燈籠", "sign", 1, frames=2)
def u_wisplamp(f):
    img = new(12, 24)
    rect(img, 5, 6, 2, 18, (60, 60, 70)); rect(img, 3, 4, 6, 2, (60, 60, 70))
    disk(img, 6, 2 + f, 2, SOUL)
    return finish(img)


@item("u_rustfence", U, "生鏽鐵柵", "sign", 1)
def u_rustfence(f):
    img = new(20, 14)
    for x in range(1, 19, 3):
        rect(img, x, 2, 1, 12, (120, 70, 50)); put(img, x, 1, (150, 90, 60))
    rect(img, 0, 5, 20, 1, (110, 64, 44)); rect(img, 0, 10, 20, 1, (110, 64, 44))
    return finish(img)


@item("u_dragonbones", U, "龍骨", "bone", 4)
def u_dragonbones(f):
    img = e_fossil(f)
    for x in range(14, 30, 4):
        line(img, x, 12, x - 3, 4, BONE_SHADE)
    return img


@item("u_bonepile", U, "骨堆", "bone", 2)
def u_bonepile(f):
    return T.bones("swamp", R(45), 0)


@item("u_skullpyramid", U, "骷髏金字塔", "bone", 2)
def u_skullpyramid(f):
    img = new(26, 20)
    for (row, n) in enumerate((4, 3, 2, 1)):
        for k in range(n):
            x = 4 + row * 3 + k * 6; y = 16 - row * 5
            disk(img, x + 1, y, 2, BONE); put(img, x, y, INK); put(img, x + 2, y, INK)
    return finish(img)


@item("u_redspider", U, "彼岸花", "flower", 1)
def u_redspider(f):
    img = new(16, 14)
    for x in (4, 10):
        rect(img, x, 6, 1, 8, (70, 120, 60))
        for a in range(0, 360, 45):
            line(img, x, 5, round(x + 4 * math.cos(math.radians(a))), round(5 + 3 * math.sin(math.radians(a)) - 1), (220, 40, 50))
    return finish(img, (60, 20, 24))


@item("u_blackrose", U, "黑玫瑰", "flower", 1)
def u_blackrose(f):
    return finish(flowers(16, 12, (50, 40, 56), (110, 30, 50), R(46), n=4, tall=4), (20, 16, 24))


@item("u_ghostlantern", U, "鬼燈籠草", "flower", 1, frames=2)
def u_ghostlantern(f):
    img = new(16, 14)
    for x in (4, 11):
        line(img, x, 14, x, 6, (70, 110, 60))
        disk(img, x + 1, 5, 2, (230, 110, 40) if f == 0 else (250, 150, 60), 3)
    return finish(img, (40, 30, 20))


@item("u_palelily", U, "蒼白百合", "flower", 1)
def u_palelily(f):
    return finish(flowers(16, 12, (236, 236, 244), (200, 210, 230), R(47), n=4, tall=5), (50, 50, 60))


@item("u_skullflower", U, "骨顱花", "plant", 2, frames=2, fn="bite")
def u_skullflower(f):
    return finish(chomper(22, 30, BONE, f, teeth=(60, 40, 40), stem=(60, 90, 60), inside=(40, 20, 30)))


@item("u_soulvine", U, "吸魂藤", "plant", 2, frames=2, fn="soulharvest")
def u_soulvine(f):
    img = g_flyvine(f)
    for y in range(4, 28, 6):
        put(img, 11 + int(5 * math.sin(y / 3 + f)) - 2, y, SOUL)
    return img


@item("u_glowshroom", U, "巨型夜光菇", "plant", 4, frames=2)
def u_glowshroom(f):
    img = new(34, 36)
    glow = (120, 230, 250) if f == 0 else (170, 245, 255)
    rect(img, 14, 14, 6, 22, (200, 210, 230))
    disk(img, 17, 10, 15, (60, 90, 150), 8); rect(img, 3, 11, 29, 3, (40, 70, 120))
    for (x, y) in ((10, 6), (20, 4), (26, 9), (14, 9)):
        disk(img, x, y, 1, glow)
    return finish(img, (20, 24, 40))


@item("u_ghost", U, "鬼魂", "creature", 1, frames=2, blocks=False)
def u_ghost(f):
    img = new(14, 18)
    y0 = f
    disk(img, 7, 5 + y0, 5, (220, 240, 245, 220))
    rect(img, 2, 5 + y0, 11, 8, (220, 240, 245, 220))
    for x in range(2, 13, 3):
        put(img, x + f, 13 + y0, (220, 240, 245, 220))
    put(img, 5, 5 + y0, INK); put(img, 9, 5 + y0, INK); rect(img, 6, 8 + y0, 3, 2, INK)
    return img


@item("u_bats", U, "蝙蝠群", "creature", 1, frames=2, blocks=False)
def u_bats(f):
    img = new(22, 16)
    for (x, y) in ((5, 4), (14, 2), (10, 10)):
        bat(x + f * 2, y + (f if x > 8 else -f) + 1)(img, f + x)
    return img


@item("u_crows", U, "烏鴉", "creature", 1, frames=2, blocks=False)
def u_crows(f):
    img = new(18, 10)
    bird(5, 6)(img, f); bird(13, 7, frame_wing=False)(img, 0)
    return finish(img, (10, 10, 14))


@item("u_crawlinghand", U, "會爬的手", "creature", 1, frames=2, blocks=False)
def u_crawlinghand(f):
    img = new(14, 8)
    rect(img, 3, 3, 6, 3, (190, 200, 170))
    for (k, x) in enumerate((2, 5, 8, 10)):
        put(img, x + (f if k % 2 else 0), 6 + (k + f) % 2, (190, 200, 170)); put(img, x, 2, (170, 180, 150))
    rect(img, 9, 4, 4, 2, (150, 150, 130))
    return finish(img, (50, 60, 40))


# ==== output ========================================================================================================
def render_all():
    os.makedirs(OUT, exist_ok=True)
    catalog = []
    for c in CATALOG:
        for f in range(c["frames"]):
            img = c["draw"](f)
            img.save(os.path.join(OUT, c["id"] + ("" if f == 0 else "-%d" % f) + ".png"))
        catalog.append({k: c[k] for k in ("id", "race", "name", "category", "size", "frames", "fn", "blocks")})
    with open(os.path.join(OUT, "catalog.json"), "w") as fh:
        json.dump(catalog, fh, ensure_ascii=False, indent=1)
    # the server's copy (what may be put down, and how much room it takes): generated, so the two never differ
    shared = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "shared", "src", "camp", "decor-catalog.ts")
    with open(shared, "w") as fh:
        fh.write("// Generated by mac/tools/make_decor.py from its drawings: do not edit by hand (run the tool again).\n")
        fh.write("export interface DecorKind { id: string; race: string; name: string; category: string; size: number; frames: number; fn: string | null; blocks: boolean }\n\n")
        fh.write("export const DECOR_KINDS: readonly DecorKind[] = [\n")
        for c in catalog:
            fh.write("  %s,\n" % json.dumps(c, ensure_ascii=False))
        fh.write("];\n")
    return catalog


def sheet(race, path, scale=3, cols=10):
    """One picture of a race's decorations on grass, with their names: for looking them over."""
    items = [c for c in CATALOG if c["race"] == race]
    cell_w, cell_h = 52 * scale, 62 * scale
    rows = (len(items) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell_w, rows * cell_h), (74, 128, 70, 255))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(T.__dict__.get("FONT", "/System/Library/Fonts/Hiragino Sans GB.ttc"), 9 * scale // 2 + 4) if False else ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 15)
    for k, c in enumerate(items):
        x0, y0 = (k % cols) * cell_w, (k // cols) * cell_h
        d.rectangle([x0, y0, x0 + cell_w - 1, y0 + cell_h - 1], outline=(60, 108, 58))
        for f in range(c["frames"]):
            spr = c["draw"](f)
            big = spr.resize((spr.width * scale, spr.height * scale), Image.NEAREST)
            px = x0 + cell_w // 2 - big.width // 2 + (f - (c["frames"] - 1) / 2) * 0
            if c["frames"] > 1:
                big = spr.resize((spr.width * scale * 2 // 3 + 1, spr.height * scale * 2 // 3 + 1), Image.NEAREST) if spr.width * scale > cell_w / 2 else big
                px = x0 + (cell_w // 4 if f == 0 else 3 * cell_w // 4) - big.width // 2
            py = y0 + cell_h - 24 - big.height
            img.alpha_composite(big, (int(px), max(y0, int(py))))
        tag = "%s%s%s" % (c["name"], "（%d）" % c["size"], " ★" if c["fn"] else "")
        d.text((x0 + 4, y0 + cell_h - 20), tag, font=font, fill=(255, 255, 255))
    img.save(path)


if __name__ == "__main__":
    cat = render_all()
    print("%d decorations (%s)" % (len(cat), ", ".join("%s %d" % (r, sum(1 for c in cat if c["race"] == r)) for r in ("goblin", "elf", "undead"))))
    if "--sheet" in sys.argv:
        prefix = sys.argv[sys.argv.index("--sheet") + 1]
        for race in ("goblin", "elf", "undead"):
            if any(c["race"] == race for c in CATALOG):
                sheet(race, "%s-%s.png" % (prefix, race))
