#!/usr/bin/env python3
"""Draws the camp monsters that come with the race level (2026-10-17: 20 more in tiers 1–4, and the level bosses) the same
way make_monsters.py draws the first four: one folder per monster in Resources/Animals with walk.png and manifest.json.

    python3 tools/make_monsters_more.py                    # writes Resources/Animals/<id>/*
    python3 tools/make_monsters_more.py --preview out.png  # also writes a zoomed contact sheet

The ordinary ones are 16×16 like the first four; the bosses are 32×32 (`frame` 32, `boss` true). Every sheet is the walk
frames first (`walkFrames`), then the wind-up and the strike, for `attackStyle` slam or bite (Animal.swift). They face right.
`level` is the tier (the race level they start coming at is in shared/src/camp/raids.ts). Bosses have `minAnts` out of
reach, so the Mac never picks one as an ordinary visitor: the server sends them.
"""
import json
import math
import os
import sys

from make_goblin import write_png

INK = (30, 24, 28)


class C:
    """A canvas `n` pixels square that holds colours directly."""

    def __init__(self, n=16):
        self.n = n
        self.px = [[None] * n for _ in range(n)]

    def put(self, x, y, col):
        x, y = int(x), int(y)
        if 0 <= x < self.n and 0 <= y < self.n:
            self.px[y][x] = col

    def rect(self, x0, y0, x1, y1, col):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, col)

    def cells(self, pts, col):
        for x, y in pts:
            self.put(x, y, col)

    def ellipse(self, cx, cy, rx, ry, col):
        for y in range(self.n):
            for x in range(self.n):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.px[y][x] = col

    def line(self, x0, y0, x1, y1, col):
        steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(steps + 1):
            t = i / steps
            self.put(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), col)

    def shade(self, base, dark, test):
        """Repaints `base` pixels where test(x, y) with `dark` (the shadow side)."""
        for y in range(self.n):
            for x in range(self.n):
                if self.px[y][x] == base and test(x, y):
                    self.px[y][x] = dark

    def outline(self, col=INK):
        edge = []
        for y in range(self.n):
            for x in range(self.n):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.n and 0 <= ny < self.n and self.px[ny][nx] is not None and self.px[ny][nx] != col:
                            edge.append((x, y))
                            break
        for x, y in edge:
            self.px[y][x] = col
        return self


EYE_R, EYE_Y, WHITE, BLACK, TOOTH = (220, 40, 52), (250, 220, 80), (250, 250, 246), (20, 20, 24), (246, 240, 220)


# ── tier 1 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
def horn_beetle(f):
    """0-1 scuttle; 2 wind-up (reared back); 3 the ram (lunged, horn low)."""
    c = C()
    dx = {2: -1, 3: 1}.get(f, 0)
    shell, dark, hi = (52, 66, 120), (32, 40, 80), (120, 150, 220)
    c.ellipse(7 + dx, 9.5 - (1 if f == 2 else 0), 5, 3.4, shell)
    c.shade(shell, dark, lambda x, y: y >= 10)
    c.line(7 + dx, 6.5, 7 + dx, 12, dark)                          # the split of the wing case
    c.cells([(5 + dx, 7), (6 + dx, 7)], hi)
    hx = 12 + dx
    c.ellipse(hx, 10 - (1 if f == 2 else 0), 1.8, 1.6, dark)       # head
    tip = (hx + 3, 6) if f != 3 else (15, 9)
    c.line(hx + 1, 9 - (1 if f == 2 else 0), tip[0], tip[1], (214, 190, 140))   # the horn
    c.put(tip[0], tip[1], (246, 232, 196))
    c.put(hx + 1, 9 - (1 if f == 2 else 0), EYE_R)
    for i, x in enumerate((4, 7, 10)):
        off = (1 if (i + f) % 2 else -1) if f < 2 else 0
        c.line(x + dx, 12, x + dx + off, 14, BLACK)
    return c.outline()


def grass_snake(f):
    """0-1 slither (the wave moves); 2 coiled with head raised back; 3 the strike (stretched, mouth open)."""
    c = C()
    body, belly = (96, 170, 70), (200, 220, 120)
    if f < 2:
        for x in range(1, 13):
            y = 12 + round(math.sin((x + f * 2) * 0.9) * 1.2)
            c.rect(x, y - 1, x, y, body)
            c.put(x, y + 1, belly)
        hx, hy = 13, 11
    elif f == 2:
        c.ellipse(6, 12, 4, 2, body); c.ellipse(6, 12, 2, 1, belly)
        c.line(8, 11, 9, 7, body); c.line(9, 11, 10, 7, body)
        hx, hy = 9, 6
    else:
        c.line(1, 13, 13, 10, body); c.line(1, 12, 13, 9, body); c.line(2, 14, 12, 11, belly)
        hx, hy = 13, 9
    c.ellipse(hx + 0.5, hy + 0.5, 1.8, 1.4, body)
    c.put(hx + 1, hy, BLACK)
    if f == 3:
        c.cells([(hx + 2, hy + 1), (hx + 3, hy + 1)], (200, 40, 60)); c.put(hx + 2, hy + 2, TOOTH)
    else:
        c.cells([(hx + 2, hy + 1), (hx + 3, hy + 2)], (220, 60, 80))
    return c.outline()


# ── tier 2 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
def quadruped(c, f, fur, dark, x0=2, top=7, length=9, height=4, leg=3, head=(12, 7), headr=(2.4, 2.1)):
    """A four-legged body with a head, its legs moving with the frame (2: crouched, 3: lunged forward)."""
    dx = {2: -1, 3: 1}.get(f, 0)
    dy = 1 if f == 2 else 0
    c.ellipse(x0 + length / 2 + dx, top + height / 2 + dy, length / 2, height / 2, fur)
    c.shade(fur, dark, lambda x, y: y >= top + height - 1 + dy)
    hx, hy = min(head[0] + dx, 16 - headr[0] - 1.6), head[1] + dy
    c.ellipse(hx, hy, *headr, fur)
    legs = ((x0 + 1, x0 + length - 2), (x0 + 2, x0 + length - 1))[f % 2] if f < 2 else ((x0, x0 + length - 3) if f == 2 else (x0 + 2, x0 + length))
    for x in legs:
        c.rect(x + dx, top + height - 1 + dy, x + dx, top + height + leg - 1, dark)
        c.rect(x + dx + 1, top + height - 1 + dy, x + dx + 1, top + height + leg - 2, fur)
    return hx, hy


def wolf(f):
    c = C()
    fur, dark, light = (128, 132, 140), (82, 86, 96), (196, 198, 204)
    hx, hy = quadruped(c, f, fur, dark, top=6, length=9, height=4, leg=4, head=(12, 6))
    c.cells([(int(hx) - 1, int(hy) - 3), (int(hx) - 1, int(hy) - 2), (int(hx), int(hy) - 2)], dark)   # pointed ear
    c.cells([(int(hx) + 2, int(hy)), (int(hx) + 3, int(hy)), (int(hx) + 2, int(hy) + 1)], light)       # muzzle
    c.put(int(hx) + 3, int(hy) - 1 + (0 if f != 3 else 1), BLACK)                                      # nose
    c.put(int(hx), int(hy) - 1, EYE_Y)
    if f == 3:
        c.cells([(int(hx) + 2, int(hy) + 2), (int(hx) + 3, int(hy) + 2)], (120, 20, 30)); c.put(int(hx) + 2, int(hy) + 3, TOOTH)
    tail = [(1, 7), (0, 6), (0, 5)] if f % 2 == 0 else [(1, 8), (0, 8), (0, 9)]
    c.cells(tail, fur)
    c.cells([(3, 10), (4, 10), (6, 10)], light)
    return c.outline()


def wild_boar(f):
    c = C()
    fur, dark, mane = (120, 78, 52), (78, 50, 34), (60, 38, 26)
    dx = {2: -1, 3: 1}.get(f, 0)
    hx, hy = quadruped(c, f, fur, dark, x0=1, top=6, length=11, height=5, leg=3, head=(12.5, 8), headr=(2.6, 2.3))
    for x in range(3, 10):
        c.put(x + dx, 5 + (x % 2) + (1 if f == 2 else 0), mane)          # the bristles along the back
    c.rect(int(hx) + 2, int(hy), int(hx) + 3, int(hy) + 1, (200, 150, 140))   # snout
    c.put(int(hx) + 3, int(hy), dark)
    c.cells([(int(hx) + 1, int(hy) + 2), (int(hx) + 2, int(hy) + 1)], TOOTH)   # tusk
    if f == 3:
        c.put(int(hx) + 2, int(hy) - 1, TOOTH)
    c.put(int(hx), int(hy) - 1, BLACK)
    c.cells([(int(hx) - 1, int(hy) - 3), (int(hx) - 1, int(hy) - 2)], dark)
    return c.outline()


def cave_spider(f):
    c = C()
    body, dark, mark = (70, 46, 90), (40, 26, 56), (180, 60, 160)
    lift = {2: -1, 3: 1}.get(f, 0)
    c.ellipse(6, 9 + lift * 0.5, 4, 3.2, body)                       # abdomen
    c.ellipse(10.5 + (1 if f == 3 else 0), 9.5 + lift * 0.5, 2.3, 2, dark)   # head
    c.cells([(5, 8), (6, 8), (6, 9)], mark)
    hx = 11 + (1 if f == 3 else 0)
    c.cells([(hx, 9), (hx + 1, 9)], EYE_R); c.put(hx + 1, 8, EYE_R)
    for i in range(4):
        x = 5 + i * 2
        up = (i + f) % 2 if f < 2 else (1 if f == 2 else 0)
        c.line(x, 10, x - 2 + i, 12 - up, (120, 90, 140)); c.line(x - 2 + i, 12 - up, x - 3 + i, 14, (120, 90, 140))
    if f == 3:
        c.cells([(hx + 2, 10), (hx + 2, 11)], TOOTH)
    return c.outline()


def mushroom_imp(f):
    """0-3 hop like the slime; 4 wind-up (cap pulled down); 5 the slam (squashed, spores puff)."""
    c = C()
    cap, capd, spot, stem = (210, 60, 52), (150, 36, 36), (250, 240, 230), (236, 222, 196)
    h = (0, -2, -2, 0, 1, 2)[f]
    c.rect(6, 9 - h, 10, 13, stem)                                   # body
    c.ellipse(8, 7 - h, 5.2 + (1 if f == 5 else 0), 3.2 - (0.6 if f == 5 else 0), cap)
    c.shade(cap, capd, lambda x, y: y >= 8 - h)
    for x, y in ((6, 5), (9, 4), (11, 6)):
        c.put(x, y - h, spot)
    c.cells([(7, 10 - h), (9, 10 - h)], BLACK)
    c.put(8, 12 - h, (150, 80, 70))
    legs = ((6, 14), (10, 14)) if f not in (1, 2) else ((5, 14), (11, 14))
    c.cells(legs, stem)
    if f == 5:
        c.cells([(2, 11), (14, 10), (3, 8), (13, 13)], (230, 220, 150))
    return c.outline()


def raven(f):
    c = C()
    body, dark, beak = (40, 40, 52), (24, 24, 34), (60, 60, 70)
    c.ellipse(7, 8, 3.4, 2.6, body)
    c.ellipse(10.5 + (1 if f == 3 else 0), 6.8 + (1 if f == 3 else 0), 2, 1.8, body)
    wing = {0: -4, 1: 2, 2: -5, 3: 0}[f]
    for k in range(6):
        x = 5 + k
        y = 8 + wing * (1 - k / 6)
        c.line(x, 8, x - 1, int(y), dark)
    bx = 12 + (1 if f == 3 else 0)
    c.cells([(bx, 7 + (1 if f == 3 else 0)), (bx + 1, 7 + (1 if f == 3 else 0))], beak)
    if f == 3:
        c.put(bx + 2, 8, beak)
    c.put(bx - 1, 6 + (1 if f == 3 else 0), EYE_R)
    c.cells([(3, 8), (2, 9), (2, 7)], dark)                          # tail
    c.cells([(6, 11), (8, 11)], beak)                                # feet tucked
    return c.outline()


def mud_crab(f):
    c = C()
    shell, dark, claw = (190, 100, 56), (130, 64, 36), (220, 120, 70)
    up = {2: 2, 3: -1}.get(f, f)
    c.ellipse(8, 10, 5, 3, shell)
    c.shade(shell, dark, lambda x, y: y >= 11)
    for x in (6, 10):
        c.put(x, 6, BLACK); c.put(x, 7, dark)                        # eyes on stalks
    for side in (-1, 1):
        cx = 8 + side * 6
        cy = 6 - up + (2 if f == 3 else 0)
        c.line(8 + side * 4, 9, cx, cy + 2, dark)
        c.ellipse(cx + 0.5, cy + 0.5, 1.6, 1.4, claw)
        c.put(cx + side, cy - (1 if f != 3 else 0), dark)
    for i, x in enumerate((5, 7, 9, 11)):
        c.line(x, 12, x + (1 if (i + f) % 2 else -1), 14, dark)
    return c.outline()


# ── tier 3 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
def humanoid(c, f, skin, cloth, dark, head=(8, 5), hr=2.4, width=4, top=7, legs=14):
    """A small upright figure: head, a body, two legs that step (2: wound up, 3: struck)."""
    hx, hy = head
    c.rect(hx - width // 2, top, hx + width // 2 - (0 if width % 2 else 1), top + 4, cloth)
    c.ellipse(hx + 0.5, hy + 0.5, hr, hr, skin)
    step = (1, -1)[f % 2] if f < 2 else 0
    c.rect(hx - 2, top + 5, hx - 1, legs - (1 if step > 0 else 0), dark)
    c.rect(hx, top + 5, hx + 1, legs - (1 if step < 0 else 0), dark)
    return hx, hy


def bandit(f):
    c = C()
    skin, cloth, dark, mask, club = (210, 160, 120), (110, 70, 50), (60, 44, 40), (60, 60, 70), (130, 96, 60)
    hx, hy = humanoid(c, f, skin, cloth, dark, head=(7, 5), width=5)
    c.rect(hx - 2, hy - 2, hx + 2, hy - 1, mask)                     # hood
    c.rect(hx - 1, hy + 1, hx + 2, hy + 1, mask)                     # face cloth
    c.put(hx + 1, hy, BLACK)
    if f == 2:
        c.line(hx + 2, 8, hx + 1, 2, club); c.rect(hx, 1, hx + 1, 3, club)   # club raised
    elif f == 3:
        c.line(hx + 2, 9, hx + 7, 10, club); c.rect(hx + 6, 9, hx + 8, 11, club)   # brought down
    else:
        c.line(hx + 3, 9, hx + 5, 6, club); c.put(hx + 5, 5, club)
    c.rect(hx - 2, 9, hx + 2, 9, (170, 140, 60))                     # belt
    return c.outline()


def bog_troll(f):
    c = C()
    skin, dark, moss = (110, 130, 80), (70, 86, 52), (60, 100, 50)
    lean = {2: -1, 3: 1}.get(f, 0)
    c.ellipse(7 + lean, 8, 5, 4.5, skin)                             # hunched body
    c.ellipse(11 + lean * 2, 5 + (1 if f == 3 else 0), 2.6, 2.3, skin)
    c.shade(skin, dark, lambda x, y: y >= 11)
    hx, hy = 11 + lean * 2, 5 + (1 if f == 3 else 0)
    c.put(hx + 1, hy - 1, EYE_Y)
    c.cells([(hx + 1, hy + 1), (hx + 2, hy + 1)], dark); c.put(hx + 1, hy + 2, TOOTH)
    for x in range(3, 10, 2):
        c.put(x + lean, 4 + (x % 3), moss)                           # moss on the back
    step = (0, 1)[f % 2] if f < 2 else 0
    c.rect(4 + step, 12, 6 + step, 14, dark); c.rect(8 - step, 12, 10 - step, 14, dark)
    arm = {2: (13, 3), 3: (15, 11)}.get(f, (13, 12))
    c.line(10 + lean, 8, arm[0], arm[1], skin); c.ellipse(arm[0] + 0.5, arm[1] + 0.5, 1.4, 1.4, dark)
    return c.outline()


def gargoyle(f):
    c = C()
    stone, dark, light = (130, 130, 136), (86, 86, 94), (176, 176, 182)
    c.ellipse(8, 9, 3, 3.4, stone)
    c.ellipse(8.5, 5, 2.2, 2, stone)
    c.cells([(7, 2), (6, 2), (10, 2), (11, 2)], dark)                 # horns
    c.cells([(7, 5), (10, 5)], EYE_R)
    wing = {0: -3, 1: 2, 2: -4, 3: 1}[f]
    for side in (-1, 1):
        for k in range(1, 6):
            x = 8 + side * (2 + k)
            y = 8 + wing * (k / 5)
            c.rect(x, int(min(y, 9)), x, int(max(y, 9)) + (1 if k < 3 else 0), dark if k % 2 else stone)
    c.cells([(7, 12), (9, 12), (7, 13), (9, 13)], dark)
    if f == 3:
        c.cells([(8, 7), (9, 7)], BLACK); c.put(8, 8, TOOTH)
    c.put(7, 9, light)
    return c.outline()


def fire_salamander(f):
    c = C()
    skin, dark, flame, core = (220, 90, 40), (160, 50, 30), (250, 170, 50), (255, 236, 120)
    dx = {2: -1, 3: 1}.get(f, 0)
    c.ellipse(7 + dx, 11, 5, 1.8, skin)
    c.ellipse(12 + dx * 2, 10.5, 2.2, 1.6, skin)
    c.shade(skin, dark, lambda x, y: y >= 12)
    c.cells([(13 + dx * 2, 10)], BLACK)
    for x in range(3, 11, 2):
        h = 2 + ((x + f) % 3)
        c.line(x + dx, 9, x + dx, 9 - h, flame); c.put(x + dx, 9 - h + 1, core)   # flames along the back
    c.line(2 + dx, 11, 0, 9 + (f % 2), skin)                         # tail
    c.put(0, 8 + (f % 2), flame)
    for i, x in enumerate((4, 8, 10)):
        c.put(x + dx + ((i + f) % 2), 13, dark)
    if f == 3:
        c.cells([(15, 10), (15, 11), (14, 9)], flame)                # a puff of fire
    return c.outline()


def giant_hornet(f):
    c = C()
    yel, blk, wing = (240, 200, 50), (36, 30, 26), (210, 230, 246)
    lunge = 1 if f == 3 else 0
    c.ellipse(5 + lunge, 9, 3.4, 2.4, yel)
    for x in (4, 6):
        c.rect(x + lunge, 7, x + lunge, 11, blk)                      # stripes
    c.ellipse(9.5 + lunge, 8.5, 1.8, 1.8, blk)
    c.ellipse(12 + lunge, 8, 1.8, 1.6, yel)
    c.put(13 + lunge, 7, EYE_R)
    up = (0, 3, -1, 2)[f]
    c.ellipse(8 + lunge, 5 + up * 0.3, 2.4, 1.4 + (0.6 if f % 2 == 0 else 0), wing)
    sting = (1, 10) if f != 2 else (0, 12)
    c.line(2 + lunge, 10, sting[0] + lunge, sting[1], blk)
    if f == 3:
        c.cells([(14, 9), (15, 9)], blk)
    return c.outline()


def shadow_wisp(f):
    c = C()
    deep, mid, glow = (50, 30, 80), (100, 60, 150), (200, 160, 250)
    sway = (0, 1, -1, 1)[f]
    c.ellipse(8, 8, 4 + (1 if f == 3 else 0), 4.4, mid)
    c.ellipse(8, 9, 2.6, 2.6, deep)
    for i in range(3):
        c.line(6 + i * 2, 11, 5 + i * 2 + sway, 14, mid)            # trailing tails
    c.line(8, 3, 8 + sway, 1, glow)                                  # the flame's tip
    c.cells([(7, 8), (9, 8)], glow)
    if f >= 2:
        c.cells([(6, 7), (10, 7)], glow)
    if f == 3:
        c.cells([(7, 10), (8, 10), (9, 10)], BLACK)
    return c.outline((20, 10, 34))


# ── tier 4 ───────────────────────────────────────────────────────────────────────────────────────────────────────────────
def ogre(f):
    c = C()
    skin, dark, cloth, club = (200, 170, 120), (150, 120, 84), (110, 80, 60), (110, 80, 50)
    c.ellipse(7, 8, 5.4, 4.6, skin)                                  # a big belly
    c.rect(3, 9, 11, 11, cloth)
    c.ellipse(7.5, 3.4, 2.4, 2.2, skin)
    c.put(8, 3, BLACK); c.put(6, 3, BLACK)
    c.cells([(6, 5), (9, 5)], TOOTH)
    step = (0, 1)[f % 2] if f < 2 else 0
    c.rect(4 + step, 12, 6 + step, 14, dark); c.rect(8 - step, 12, 10 - step, 14, dark)
    if f == 2:
        c.line(12, 6, 13, 0, club); c.rect(12, 0, 14, 2, club)
    elif f == 3:
        c.line(12, 8, 15, 13, club); c.rect(14, 12, 15, 14, club)
    else:
        c.line(12, 8, 14, 12, club); c.rect(13, 12, 15, 13, club)
    return c.outline()


def wyvern(f):
    c = C()
    scale, dark, belly, wingc = (70, 140, 120), (40, 90, 80), (200, 210, 150), (50, 110, 100)
    c.ellipse(7, 9, 3.6, 2.6, scale)
    c.line(9, 8, 12, 5 + (1 if f == 3 else 0), scale)                # neck
    c.ellipse(13, 5 + (1 if f == 3 else 0), 1.8, 1.4, scale)
    c.put(13, 4 + (1 if f == 3 else 0), EYE_Y)
    c.line(4, 10, 0, 8 + (f % 2), dark)                              # tail
    c.put(7, 10, belly); c.put(8, 10, belly)
    wing = {0: -5, 1: 1, 2: -6, 3: -1}[f]
    for k in range(6):
        x = 5 + k
        c.line(x, 8, x - 2, int(8 + wing * (1 - k / 6)), wingc)
    c.cells([(6, 12), (9, 12), (6, 13), (9, 13)], dark)               # two legs
    if f == 3:
        c.cells([(15, 6), (15, 7)], (220, 60, 50)); c.put(14, 7, TOOTH)
    return c.outline()


def iron_golem(f):
    c = C()
    iron, dark, light, glow = (130, 136, 148), (80, 84, 96), (190, 196, 206), (90, 220, 250)
    lean = {2: -1, 3: 1}.get(f, 0)
    c.rect(3 + lean, 5, 12 + lean, 11, iron)
    c.rect(5 + lean, 1, 10 + lean, 5, iron)
    c.shade(iron, dark, lambda x, y: y >= 10 or x >= 11 + lean)
    c.rect(3 + lean, 5, 12 + lean, 5, light)
    c.cells([(6 + lean, 3), (9 + lean, 3)], glow)
    c.cells([(5 + lean, 8), (10 + lean, 8), (7 + lean, 7), (8 + lean, 7)], dark)   # rivets
    step = (0, 1)[f % 2] if f < 2 else 0
    c.rect(4 + step, 12, 6 + step, 14, dark); c.rect(9 - step, 12, 11 - step, 14, dark)
    fist = {2: (14, 2), 3: (15, 12)}.get(f, (14, 10))
    c.line(12 + lean, 6, fist[0], fist[1], iron); c.rect(fist[0] - 1, fist[1] - 1, fist[0], fist[1], dark)
    return c.outline()


def banshee(f):
    c = C()
    pale, mid, hair, dark = (220, 230, 240), (170, 190, 210), (200, 210, 230), (90, 100, 130)
    sway = (0, 1, -1, 1)[f]
    c.ellipse(8, 9, 3.4 + (1 if f == 3 else 0), 4, mid)
    c.ellipse(8, 4.5, 2.2, 2.2, pale)
    c.rect(5, 3, 5, 9, hair); c.rect(11, 3, 11, 9, hair)               # long hair
    c.rect(6, 2, 10, 2, hair)
    for i in range(3):
        c.line(6 + i * 2, 12, 5 + i * 2 + sway, 15, mid)
    c.cells([(7, 4), (9, 4)], BLACK)
    if f >= 2:
        c.rect(7, 6, 9, 7 if f == 3 else 6, dark)                    # the scream
    if f == 3:
        for x, y in ((13, 4), (14, 6), (13, 8), (2, 5), (1, 7)):
            c.put(x, y, pale)
    return c.outline((60, 70, 100))


def dire_bear(f):
    c = C()
    fur, dark, light = (90, 62, 44), (58, 40, 30), (140, 104, 76)
    rear = f == 2
    if rear:
        c.ellipse(7, 7, 4, 5.4, fur); c.ellipse(9, 3, 2.4, 2.2, fur)
        hx, hy = 9, 3
        c.line(10, 6, 13, 2, fur); c.line(5, 6, 3, 3, fur)
        c.rect(5, 12, 6, 14, dark); c.rect(8, 12, 9, 14, dark)
    else:
        hx, hy = quadruped(c, f, fur, dark, x0=1, top=5, length=11, height=6, leg=3, head=(12.5, 7), headr=(2.6, 2.4))
    c.cells([(int(hx) - 1, int(hy) - 3), (int(hx) + 1, int(hy) - 3)], dark)   # round ears
    c.cells([(int(hx) + 2, int(hy)), (int(hx) + 3, int(hy))], light); c.put(int(hx) + 3, int(hy) - 1, BLACK)
    c.put(int(hx), int(hy) - 1, EYE_R)
    if f == 3:
        c.cells([(int(hx) + 2, int(hy) + 2), (int(hx) + 3, int(hy) + 2)], (120, 20, 30)); c.put(int(hx) + 2, int(hy) + 3, TOOTH)
    return c.outline()


def basilisk(f):
    c = C()
    scale, dark, gold, crest = (90, 140, 60), (56, 92, 40), (220, 190, 60), (200, 60, 50)
    dx = {2: -1, 3: 1}.get(f, 0)
    c.ellipse(7 + dx, 10.5, 6, 2.2, scale)
    c.shade(scale, dark, lambda x, y: y >= 12)
    for x in range(3, 11, 2):
        c.put(x + dx, 9, gold)                                       # gold diamonds on the back
    hx = 13 + dx * 2
    c.ellipse(hx, 9 - (1 if f == 2 else 0), 2, 1.6, scale)
    c.cells([(hx - 1, 7 - (1 if f == 2 else 0)), (hx, 6 - (1 if f == 2 else 0)), (hx + 1, 7 - (1 if f == 2 else 0))], crest)
    c.put(hx + 1, 9 - (1 if f == 2 else 0), EYE_Y)
    for i, x in enumerate((3, 6, 9)):
        c.put(x + dx + ((i + f) % 2), 13, dark); c.put(x + dx + ((i + f) % 2), 14, dark)
    c.line(1 + dx, 11, 0, 9 + (f % 2), scale)
    if f == 3:
        c.cells([(15, 9), (15, 10)], (230, 240, 120)); c.put(14, 11, TOOTH)   # its stare
    return c.outline()


# ── bosses (32×32) ───────────────────────────────────────────────────────────────────────────────────────────────────────
def crown(c, x, y, w=6):
    gold, gem = (250, 210, 60), (220, 50, 80)
    c.rect(x, y + 2, x + w, y + 3, gold)
    for k in range(0, w + 1, 2):
        c.put(x + k, y + 1, gold); c.put(x + k, y, gold)
    c.put(x + w // 2, y + 2, gem)


def slime_king(f):
    """0-3 the hop; 4 the wind-up; 5 the slam."""
    c = C(32)
    body, dark, hi = (90, 200, 120), (50, 140, 80), (210, 250, 220)
    rx, ry = ((12.4, 6.4), (8.6, 10.8), (9.2, 10.0), (11.2, 7.6), (7.6, 11.6), (14.4, 5.2))[f]
    c.ellipse(16, 27.5 - ry, rx, ry, body)
    c.shade(body, dark, lambda x, y: y >= 26 or x >= 16 + rx - 2.5)
    top = int(27.5 - 2 * ry)
    c.cells([(11, top + 4), (12, top + 3), (11, top + 5), (12, top + 4)], hi)
    crown(c, 12, top - 3, 8)
    ey = int(27.5 - ry) - 1
    for x in (12, 20):
        c.rect(x, ey, x + 1, ey + 1, WHITE); c.rect(x, ey + 1, x + 1, ey + 2, BLACK)
    if f >= 4:
        c.cells([(11, ey - 1), (12, ey - 1), (20, ey - 1), (21, ey - 1)], (30, 90, 60))
    if f == 5:
        c.rect(14, ey + 4, 18, ey + 6, (30, 90, 60))
    else:
        c.rect(15, ey + 5, 17, ey + 5, (30, 90, 60))
    return c.outline()


def troll_chief(f):
    c = C(32)
    skin, dark, fur, bone, club = (120, 140, 86), (78, 94, 56), (120, 90, 60), (236, 228, 204), (110, 80, 50)
    lean = {2: -2, 3: 2}.get(f, 0)
    c.ellipse(14 + lean, 17, 9, 8, skin)                             # the bulk
    c.rect(7 + lean, 18, 21 + lean, 22, fur)                         # a fur kilt
    c.ellipse(21 + lean * 2, 9 + (2 if f == 3 else 0), 4.4, 4, skin)
    c.shade(skin, dark, lambda x, y: y >= 22)
    hx, hy = 21 + lean * 2, 9 + (2 if f == 3 else 0)
    c.ellipse(hx, hy - 4, 3.6, 2.2, bone)                            # a skull headdress
    c.cells([(hx - 2, hy - 5), (hx + 1, hy - 5)], BLACK)
    c.cells([(hx - 4, hy - 6), (hx - 5, hy - 8), (hx + 4, hy - 6), (hx + 5, hy - 8)], bone)   # horns
    c.cells([(hx + 1, hy), (hx + 2, hy)], EYE_Y)
    c.rect(hx, hy + 2, hx + 3, hy + 2, dark); c.cells([(hx, hy + 3), (hx + 3, hy + 3)], TOOTH)
    step = (0, 2)[f % 2] if f < 2 else 0
    c.rect(9 + step, 24, 12 + step, 29, dark); c.rect(16 - step, 24, 19 - step, 29, dark)
    if f == 2:
        c.line(24, 14, 26, 1, club); c.ellipse(26.5, 2.5, 2.6, 2.6, club)
    elif f == 3:
        c.line(24, 16, 30, 26, club); c.ellipse(29.5, 26.5, 2.4, 2.6, club)
    else:
        c.line(24, 16, 28, 24, club); c.ellipse(28.5, 25.5, 2.4, 2.4, club)
    return c.outline()


def elder_wyvern(f):
    c = C(32)
    scale, dark, belly, wingc, horn = (150, 40, 40), (96, 22, 30), (230, 180, 110), (110, 30, 40), (236, 222, 190)
    c.ellipse(14, 19, 7.6, 5.4, scale)
    c.line(19, 16, 25, 9 + (2 if f == 3 else 0), scale); c.line(20, 17, 26, 10 + (2 if f == 3 else 0), scale)
    hy = 9 + (2 if f == 3 else 0)
    c.ellipse(26.5, hy, 3.4, 2.6, scale)
    c.cells([(25, hy - 3), (24, hy - 4), (27, hy - 3), (27, hy - 4)], horn)
    c.put(27, hy - 1, EYE_Y)
    c.rect(11, 21, 17, 22, belly)
    c.line(7, 20, 1, 16 + (f % 2) * 2, dark); c.line(1, 16 + (f % 2) * 2, 0, 14, dark)   # tail
    wing = {0: -11, 1: 2, 2: -13, 3: -3}[f]
    for k in range(12):
        x = 9 + k
        c.line(x, 16, x - 4, int(16 + wing * (1 - k / 12)), wingc)
    c.shade(scale, dark, lambda x, y: y >= 23)
    c.rect(11, 24, 12, 28, dark); c.rect(17, 24, 18, 28, dark)
    if f == 3:
        for i in range(4):
            c.put(29 + (i % 3), hy + 1 + i, (250, 160, 50))         # fire
    return c.outline()


def drops(*ds):
    return [{"id": i, "name": n, "chance": ch, "min": lo, "max": hi, "color": col} for i, n, ch, lo, hi, col in ds]


SHARP_CLAW = ("sharp_claw", "斷爪", 0.15, 1, 1, "#8a8a96")
SHINY_BEAD = ("shiny_bead", "閃亮黏珠", 0.04, 1, 1, "#f0d040")
NIGHT_HEART = ("night_heart", "夜之心", 0.04, 1, 1, "#d040a0")
GOLDEN_FUR = ("golden_fur", "金毛", 0.05, 1, 1, "#f0c040")


def m(level, hp, speed, damage, radius, attack, style, walk, pack, after, ants, ds, **more):
    out = {"hp": hp, "speed": speed, "meat": 0, "aggressive": True, "weight": 2 if level > 1 else 3, "radius": radius, "pixelScale": 1.5,
           "hostile": True, "level": level, "appearsAfter": after, "minAnts": ants, "damage": damage, "attackEvery": attack,
           "hops": walk == 4, "walkFrames": walk, "attackStyle": style, "splits": 0, "pack": pack, "drops": ds}
    out.update(more)
    return out


MONSTERS = [
    # id, name, draw, frames, manifest
    ("horn_beetle", "角甲蟲", horn_beetle, 4, m(1, 55, 18, 1, 7, 2.2, "slam", 2, [1, 2], 60, 30, drops(
        ("beetle_shell", "甲蟲殼", 0.75, 1, 2, "#34427a"), ("beetle_horn", "獨角仙角", 0.35, 1, 1, "#5a4632"), SHARP_CLAW, SHINY_BEAD))),
    ("grass_snake", "草蛇", grass_snake, 4, m(1, 35, 30, 1, 6, 1.5, "bite", 2, [1, 3], 45, 30, drops(
        ("snake_skin", "蛇皮", 0.75, 1, 2, "#60aa46"), ("snake_fang", "蛇牙", 0.35, 1, 1, "#f6f0dc"), SHARP_CLAW, SHINY_BEAD))),
    ("wolf", "野狼", wolf, 4, m(2, 80, 42, 2, 8, 1.4, "bite", 2, [2, 4], 120, 60, drops(
        ("wolf_pelt", "狼皮", 0.70, 1, 2, "#80848c"), ("wolf_fang", "狼牙", 0.40, 1, 1, "#f4efdc"), SHARP_CLAW, GOLDEN_FUR))),
    ("wild_boar", "山豬", wild_boar, 4, m(2, 110, 26, 2, 9, 2.0, "slam", 2, [1, 2], 120, 60, drops(
        ("boar_hide", "野豬皮", 0.70, 1, 2, "#784e34"), ("boar_tusk", "野豬獠牙", 0.40, 1, 1, "#f6f0dc"), SHARP_CLAW, GOLDEN_FUR))),
    ("cave_spider", "洞穴蜘蛛", cave_spider, 4, m(2, 70, 36, 2, 8, 1.5, "bite", 2, [2, 3], 120, 60, drops(
        ("spider_silk", "蜘蛛絲", 0.75, 1, 3, "#e8e4f0"), ("venom_sac", "毒囊", 0.35, 1, 1, "#b43ca0"), SHARP_CLAW, NIGHT_HEART), nightOnly=False)),
    ("mushroom_imp", "蘑菇小妖", mushroom_imp, 6, m(2, 90, 16, 2, 8, 2.2, "slam", 4, [1, 3], 120, 60, drops(
        ("spore_cap", "孢子傘", 0.75, 1, 2, "#d23c34"), ("glow_spore", "螢光孢子", 0.35, 1, 1, "#e6dc96"), SHINY_BEAD))),
    ("raven", "烏鴉群", raven, 4, m(2, 60, 44, 2, 7, 1.4, "bite", 2, [3, 5], 120, 60, drops(
        ("black_feather", "黑羽毛", 0.80, 1, 3, "#282834"), ("raven_eye", "鴉眼", 0.25, 1, 1, "#dc2834"), SHINY_BEAD), flies=True)),
    ("mud_crab", "泥蟹", mud_crab, 4, m(2, 100, 18, 2, 9, 1.8, "bite", 2, [1, 3], 120, 60, drops(
        ("crab_shell", "蟹殼", 0.75, 1, 2, "#be6438"), ("crab_claw", "蟹螯", 0.40, 1, 1, "#dc7846"), SHARP_CLAW), needsWater=True)),
    ("bandit", "山賊", bandit, 4, m(3, 160, 32, 3, 8, 1.6, "slam", 2, [2, 4], 180, 90, drops(
        ("stolen_coin", "贓物銅幣", 0.70, 1, 3, "#c8a040"), ("bandit_mask", "山賊面巾", 0.30, 1, 1, "#3c3c46"), GOLDEN_FUR))),
    ("bog_troll", "沼澤巨魔", bog_troll, 4, m(3, 220, 18, 3, 10, 2.4, "slam", 2, [1, 1], 180, 90, drops(
        ("troll_moss", "巨魔苔", 0.70, 1, 2, "#3c6432"), ("troll_tooth", "巨魔牙", 0.35, 1, 1, "#f6f0dc"), NIGHT_HEART))),
    ("gargoyle", "石像鬼", gargoyle, 4, m(3, 200, 30, 3, 8, 1.8, "bite", 2, [1, 2], 180, 90, drops(
        ("stone_wing", "石翼片", 0.70, 1, 2, "#828288"), ("gargoyle_eye", "石像鬼之眼", 0.25, 1, 1, "#dc2834"), NIGHT_HEART), flies=True)),
    ("fire_salamander", "火蠑螈", fire_salamander, 4, m(3, 150, 28, 3, 8, 1.6, "bite", 2, [1, 2], 180, 90, drops(
        ("salamander_scale", "火蠑螈鱗", 0.70, 1, 2, "#dc5a28"), ("ember_gland", "火腺", 0.30, 1, 1, "#faaa32"), SHINY_BEAD))),
    ("giant_hornet", "巨型虎頭蜂", giant_hornet, 4, m(3, 140, 46, 3, 7, 1.3, "bite", 2, [2, 3], 180, 90, drops(
        ("hornet_stinger", "蜂針", 0.70, 1, 2, "#241e1a"), ("royal_jelly", "蜂王乳", 0.25, 1, 1, "#f0c832"), SHINY_BEAD), flies=True)),
    ("shadow_wisp", "暗影鬼火", shadow_wisp, 4, m(3, 140, 34, 3, 7, 1.8, "slam", 2, [1, 3], 180, 90, drops(
        ("shadow_essence", "暗影精華", 0.65, 1, 2, "#643c96"), ("wisp_flame", "鬼火芯", 0.30, 1, 1, "#c8a0fa"), NIGHT_HEART), flies=True, nightOnly=True)),
    ("ogre", "食人魔", ogre, 4, m(4, 380, 20, 4, 11, 2.4, "slam", 2, [1, 1], 240, 120, drops(
        ("ogre_hide", "食人魔皮", 0.70, 1, 2, "#c8aa78"), ("ogre_club", "食人魔棒", 0.25, 1, 1, "#6e5032"), GOLDEN_FUR))),
    ("wyvern", "雙足飛龍", wyvern, 4, m(4, 300, 40, 4, 10, 1.6, "bite", 2, [1, 2], 240, 120, drops(
        ("wyvern_scale", "飛龍鱗", 0.70, 1, 2, "#468c78"), ("wyvern_wing", "飛龍翼膜", 0.30, 1, 1, "#326e64"), NIGHT_HEART), flies=True)),
    ("iron_golem", "鐵甲魔像", iron_golem, 4, m(4, 400, 14, 4, 11, 2.6, "slam", 2, [1, 1], 240, 120, drops(
        ("iron_plate", "魔像鐵板", 0.75, 1, 2, "#828894"), ("golem_core", "巨人核心", 0.25, 1, 1, "#5adcfa"), SHINY_BEAD))),
    ("banshee", "女妖", banshee, 4, m(4, 260, 36, 4, 8, 2.0, "slam", 2, [1, 2], 240, 120, drops(
        ("ghost_veil", "幽魂面紗", 0.65, 1, 2, "#dce6f0"), ("banshee_tear", "女妖之淚", 0.25, 1, 1, "#aac8f0"), NIGHT_HEART), flies=True, nightOnly=True)),
    ("dire_bear", "恐熊", dire_bear, 4, m(4, 360, 30, 4, 11, 2.0, "slam", 2, [1, 1], 240, 120, drops(
        ("bear_pelt", "熊皮", 0.70, 1, 2, "#5a3e2c"), ("bear_claw", "熊爪", 0.35, 1, 1, "#e6dcc8"), GOLDEN_FUR))),
    ("basilisk", "蛇蜥", basilisk, 4, m(4, 320, 24, 4, 10, 1.8, "bite", 2, [1, 1], 240, 120, drops(
        ("basilisk_scale", "蛇蜥鱗", 0.70, 1, 2, "#5a8c3c"), ("basilisk_eye", "石化之眼", 0.25, 1, 1, "#dcbe3c"), NIGHT_HEART))),
]

# Level bosses: never picked on their own (minAnts out of reach); the server sends them at race level 10, 20, 30…
BOSSES = [
    ("slime_king", "史萊姆王", slime_king, 6, m(2, 880, 14, 3, 18, 2.6, "slam", 4, [1, 1], 0, 10 ** 9, drops(
        ("royal_gel", "王者凝膠", 1.0, 2, 4, "#5ac878"), ("slime_crown", "史萊姆王冠", 0.5, 1, 1, "#fad23c"), SHINY_BEAD), boss=True, frame=32, splits=4)),
    ("troll_chief", "巨魔酋長", troll_chief, 4, m(4, 1760, 16, 5, 20, 2.6, "slam", 2, [1, 1], 0, 10 ** 9, drops(
        ("chief_tusk", "酋長獠牙", 1.0, 1, 3, "#ece4cc"), ("war_totem", "戰圖騰", 0.5, 1, 1, "#78563a"), NIGHT_HEART), boss=True, frame=32)),
    ("elder_wyvern", "遠古飛龍", elder_wyvern, 4, m(4, 3040, 30, 7, 22, 2.2, "bite", 2, [1, 1], 0, 10 ** 9, drops(
        ("elder_scale", "遠古龍鱗", 1.0, 2, 4, "#962828"), ("dragon_heart", "龍心", 0.5, 1, 1, "#fa5a3c"), GOLDEN_FUR), boss=True, frame=32, flies=True)),
]


def sheet(draw, frames):
    first = draw(0)
    n = first.n
    img = [[(0, 0, 0, 0)] * (frames * n) for _ in range(n)]
    for f in range(frames):
        canvas = first if f == 0 else draw(f)
        for y in range(n):
            for x in range(n):
                col = canvas.px[y][x]
                if col is not None:
                    img[y][f * n + x] = col + (255,)
    return img


def preview(path, zoom=3):
    """Each monster on a row of its own: walk frames, then wind-up and strike, at `zoom` × its game size (×1.5)."""
    rows = [(mid, sheet(draw, frames)) for mid, _, draw, frames, _ in MONSTERS + BOSSES]
    cell = 32 * 2  # (a 16-pixel monster shown at 2×zoom per pixel; a boss at 1×… so both read at the size they're drawn)
    width = max(len(sh[0]) * (zoom * 2 if len(sh) == 16 else zoom) for _, sh in rows) + 8
    height = sum(len(sh) * (zoom * 2 if len(sh) == 16 else zoom) + 6 for _, sh in rows)
    img = [[(214, 218, 200, 255)] * width for _ in range(height)]
    y0 = 0
    for _, sh in rows:
        z = zoom * 2 if len(sh) == 16 else zoom
        for y in range(len(sh)):
            for x in range(len(sh[0])):
                px = sh[y][x]
                if px[3]:
                    for dy in range(z):
                        for dx in range(z):
                            img[y0 + y * z + dy][4 + x * z + dx] = px
        y0 += len(sh) * z + 6
    del cell
    write_png(path, img)


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "Animals")
    for mid, name, draw, frames, extra in MONSTERS + BOSSES:
        assert len(extra["drops"]) >= 3, mid
        assert frames == extra["walkFrames"] + 2, mid
        folder = os.path.join(root, mid)
        os.makedirs(folder, exist_ok=True)
        write_png(os.path.join(folder, "walk.png"), sheet(draw, frames))
        manifest = {"id": mid, "name": name, "frame": extra.pop("frame", 16), "sheet": "walk.png"}
        manifest.update(extra)
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    print("wrote", len(MONSTERS), "monsters and", len(BOSSES), "bosses to", os.path.normpath(root))


if __name__ == "__main__":
    main()
