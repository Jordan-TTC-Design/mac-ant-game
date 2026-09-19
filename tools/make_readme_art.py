#!/usr/bin/env python3
"""Draws the pictures used in README.md (docs/images/*.png) from the game's own sprite sheets.
Run:  python3 tools/make_readme_art.py [name ...]   (no name = all)"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixelart import *  # noqa: E402,F401

OUT = os.path.join(ROOT, "docs", "images")
GOLD, DARK = (255, 216, 92, 255), (64, 34, 12, 255)
WHITE = (255, 255, 255, 255)


def night_sky(art, horizon):
    dither_gradient(art, None, None, 0, horizon, (12, 14, 42), (120, 66, 112), steps=10)
    rnd = random.Random(7)
    for _ in range(90):
        x, y = rnd.randrange(art.w), rnd.randrange(int(horizon * 0.8))
        art.dot(x, y, rnd.choice([(255, 255, 255, 255), (255, 240, 170, 255), (170, 190, 255, 255)]))


def moon(art, cx, cy, r=9):
    for dy in range(-r - 3, r + 4):
        for dx in range(-r - 3, r + 4):
            d = math.hypot(dx, dy)
            if d <= r:
                art.dot(cx + dx, cy + dy, (250, 244, 210, 255))
            elif d <= r + 2 and (dx + dy) % 2 == 0:
                art.dot(cx + dx, cy + dy, (176, 150, 170, 255))
    for dx, dy, rr in [(-3, -2, 2), (3, 3, 2), (2, -4, 1)]:
        for yy in range(-rr, rr + 1):
            for xx in range(-rr, rr + 1):
                if math.hypot(xx, yy) <= rr:
                    art.dot(cx + dx + xx, cy + dy + yy, (222, 214, 178, 255))


def hills(art, base, amp, color, seed, step=1, period=60):
    rnd = random.Random(seed)
    ph = [rnd.random() * 6.28 for _ in range(3)]
    for x in range(0, art.w, step):
        h = amp * (0.5 + 0.28 * math.sin(x / period + ph[0]) + 0.16 * math.sin(x / (period / 2.3) + ph[1]) + 0.06 * math.sin(x / 9 + ph[2]))
        art.rect(x, int(base - h), step, art.h - int(base - h), color)


def grass(art, y0, seed=3):
    art.rect(0, y0, art.w, art.h - y0, (58, 116, 62, 255))
    rnd = random.Random(seed)
    for _ in range(int(art.w * (art.h - y0) / 14)):
        x, y = rnd.randrange(art.w), rnd.randrange(y0, art.h)
        art.dot(x, y, rnd.choice([(48, 100, 54, 255), (74, 138, 74, 255), (66, 128, 68, 255)]))
        if rnd.random() < 0.25:
            art.dot(x, y - 1, (74, 138, 74, 255))
    for x in range(0, art.w, 2):  # a darker line where the hills meet the grass
        art.dot(x, y0, (44, 92, 52, 255))


def path(art, x0, y0, x1, y1, width=10):
    color, edge = (150, 112, 70, 255), (120, 86, 52, 255)
    steps = max(abs(x1 - x0), abs(y1 - y0))
    rnd = random.Random(5)
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t + math.sin(t * 6) * 3
        y = y0 + (y1 - y0) * t
        w = width * (0.5 + t * 0.9)
        art.rect(int(x - w / 2), int(y), int(w), 2, color)
        art.dot(int(x - w / 2), int(y), edge); art.dot(int(x + w / 2) - 1, int(y), edge)
        if rnd.random() < 0.3:
            art.dot(int(x + rnd.randrange(-int(w / 2), int(w / 2))), int(y), (128, 94, 58, 255))


def campfire(art, x, y, frame=0):
    art.rect(x - 5, y - 1, 10, 2, (90, 60, 34, 255))
    art.rect(x - 4, y - 2, 8, 1, (120, 80, 44, 255))
    flame = [(0, 0, 2, 3, (255, 210, 80, 255)), (-2, 1, 2, 3, (240, 120, 30, 255)), (2, 1, 2, 3, (240, 120, 30, 255)),
             (-1, 2, 3, 5, (250, 160, 40, 255)), (0, 4, 1, 5, (255, 240, 150, 255))]
    for dx, dy, w, h, c in flame:
        art.rect(x + dx - w // 2, y - 2 - dy - h, w, h, c)
    for i in range(14):  # glow, dithered
        rr = 6 + i
        for a in range(0, 360, 12):
            gx, gy = x + int(math.cos(math.radians(a)) * rr), y - 6 + int(math.sin(math.radians(a)) * rr * 0.6)
            if (gx + gy) % 3 == 0 and i > 6:
                art.dot(gx, gy, (255, 170, 80, 255))


def cover():
    W, H, S = 400, 160, 4
    a = Art(W, H, S)
    horizon = 104
    night_sky(a, horizon)
    moon(a, 190, 24)
    hills(a, 112, 34, (52, 44, 96, 255), 1, step=1, period=55)
    hills(a, 114, 20, (36, 62, 84, 255), 2, step=1, period=38)
    grass(a, horizon + 6)
    path(a, 214, 112, 226, 160, 12)

    # title
    a.text("哥布林營地", 14, 8, size=26, color=GOLD, outline=DARK)
    a.text("GoblinCamp", 16, 40, size=15, color=WHITE, outline=DARK, font=FONT_LATIN)
    a.text("住在 Mac 選單列的哥布林桌面小遊戲", 16, 60, size=12, color=(236, 226, 255, 255), outline=(20, 16, 50, 255))
    a.text("番茄鐘・Claude 通知・點陣風", 16, 76, size=12, color=(255, 232, 170, 255), outline=(20, 16, 50, 255))

    # top right: the pomodoro goblin holding the clock, and a popup goblin saying something
    lcd_clock(a, 340, 14, "24:59")
    a.shadow(363, 58)
    a.sprite(goblin("worker", "down"), 363, 58)
    bubble(a, 222, 30, ["搞定啦！嘻嘻嘻！"], accent=(64, 166, 77, 255), tail_x=262, title="哥布林", size=12)
    a.shadow(266, 90)
    a.sprite(goblin("scout", "down", 0), 266, 90)

    # back: trees and the camp with its fire
    tree(a, 34, 116, fruit=6, unit=2)
    tree(a, 118, 108, fruit=4, unit=2)
    tree(a, 384, 118, fruit=5, unit=2)
    a.shadow(214, 118, 40)
    a.sprite(camp("cave", 3), 214, 118, scale=1)
    campfire(a, 158, 124)

    # the princess in every outfit
    xs = [250 + i * 20 for i in range(7)]
    for i, (sheet, _) in enumerate(OUTFITS):
        a.shadow(xs[i], 138, 12)
        a.sprite(princess(sheet, step=[0, 1, 0, 3, 0, 1, 2][i] % 4), xs[i], 138)
    # front: five kinds of goblin
    order = ["worker", "scout", "brute", "sage", "golden"]
    for i, b in enumerate(order):
        x = 44 + i * 26
        a.shadow(x, 152)
        a.sprite(goblin(b, "down", i % 4), x, 152)
    # animals
    for i, k in enumerate(["chicken", "sheep", "pig"]):
        x = 268 + i * 34
        a.shadow(x, 154, 14)
        a.sprite(animal(k, i % 2), x, 154)
    # a goblin walking beside the path, one going the other way
    a.shadow(190, 142); a.sprite(goblin("common" if False else "worker", "side", 1), 190, 142)
    a.shadow(238, 150); a.sprite(flip(goblin("brute", "side", 2)), 238, 150)
    a.save(os.path.join(OUT, "cover.png"))


def panel(art, x, y, w, h, fill=(30, 26, 52, 255), edge=(92, 78, 150, 255)):
    art.rect(x, y, w, h, edge)
    art.rect(x + 1, y + 1, w - 2, h - 2, fill)
    art.rect(x, y, 1, 1, (0, 0, 0, 0)); art.rect(x + w - 1, y, 1, 1, (0, 0, 0, 0))


def bar(art, x, y, w, value, color, back=(60, 54, 92, 255)):
    art.rect(x, y, w, 3, back)
    art.rect(x, y, max(1, int(w * min(1.0, value))), 3, color)


def backdrop(art, seed=1):
    dither_gradient(art, None, None, 0, art.h, (22, 20, 56), (74, 46, 96), steps=8)
    rnd = random.Random(seed)
    for _ in range(art.w * art.h // 260):
        art.dot(rnd.randrange(art.w), rnd.randrange(art.h // 2), rnd.choice([WHITE, (255, 240, 170, 255), (170, 190, 255, 255)]))


def characters():
    import json
    manifest = json.load(open(os.path.join(RES, "Characters", "goblin", "manifest.json")))
    stats = {b["sheet"].replace(".png", ""): b["stats"] for b in manifest["breeds"]}
    blurbs = {"worker": ["最普通的", "什麼都會一點"], "scout": ["腿快眼尖", "但比較短命"], "brute": ["身強體壯", "一次搬兩份"],
              "sage": ["很會找食物", "叫來更多同伴"], "golden": ["罕見金皮", "壽命是兩倍"]}
    W, H = 400, 148
    a = Art(W, H, 4)
    backdrop(a, 4)
    a.text("五個品種", 12, 6, size=14, color=GOLD, outline=DARK)
    a.text("搬回的食物越多，越容易出稀有品種", 96, 9, size=12, color=(220, 210, 255, 255))
    for k, (txt, col) in enumerate([("速度", (110, 200, 255, 255)), ("力量", (255, 130, 110, 255)), ("壽命", (140, 230, 130, 255))]):
        a.rect(288 + k * 38, 11, 6, 3, col)
        a.text(txt, 296 + k * 38, 8, size=12, color=(220, 210, 255, 255))
    cw = 76
    for i, b in enumerate(BREEDS):
        x = 8 + i * (cw + 4)
        panel(a, x, 26, cw, 118)
        a.shadow(x + cw // 2, 66, 26)
        a.sprite(goblin(b, "down", 0), x + cw // 2, 64, scale=2)
        a.text(BREED_NAMES[b], x + cw // 2, 68, size=12, color=WHITE, anchor="c")
        for j, line in enumerate(blurbs[b]):
            a.text(line, x + cw // 2, 82 + j * 12, size=12, color=(190, 180, 230, 255), anchor="c")
        st = stats[b]
        # tiny bars: speed, strength, lifespan
        for j, (label, key, base, color) in enumerate([("速", "speed", 1.0, (110, 200, 255, 255)), ("力", "might", 1.0, (255, 130, 110, 255)), ("壽", "lifespan", 1.0, (140, 230, 130, 255))]):
            v = st.get(key, base) / 2.0
            bar(a, x + 8, 112 + j * 8, cw - 16, v, color)
    a.save(os.path.join(OUT, "characters.png"))


def princess_img():
    W, H = 400, 168
    a = Art(W, H, 4)
    backdrop(a, 6)
    a.text("公主的七套衣服", 12, 6, size=14, color=GOLD, outline=DARK)
    a.text("每套的帽子、袖子、裙長都不同", 128, 9, size=12, color=(220, 210, 255, 255))
    step = W // 7
    for i, (sheet, name) in enumerate(OUTFITS):
        x = i * step + step // 2
        panel(a, i * step + 3, 24, step - 6, 52)
        a.shadow(x, 58, 20)
        a.sprite(princess(sheet), x, 56, scale=2)
        a.text(name, x, 60, size=12, color=WHITE, anchor="c")
    a.text("還有她的日常：", 12, 84, size=12, color=GOLD, outline=DARK)
    poses = [("tea", "喝茶"), ("exercise", "運動"), ("read", "看書"), ("water", "澆花"), ("comb", "梳頭"),
             ("sing", "唱歌"), ("dance", "跳舞"), ("wave", "揮手"), ("yawn", "哈欠"), ("think", "發呆")]
    ps = W // 10
    for i, (pose, name) in enumerate(poses):
        x = i * ps + ps // 2
        panel(a, i * ps + 2, 98, ps - 4, 64)
        a.shadow(x, 132, 22)
        a.sprite(princess("queen", pose=pose, step=1), x, 130, scale=2)
        a.text(name, x, 143, size=12, color=(230, 224, 255, 255), anchor="c")
    a.save(os.path.join(OUT, "princess.png"))


def camps_img():
    W, H = 400, 152
    a = Art(W, H, 4)
    grass(a, 0, seed=11)
    a.text("四種營地，隨哥布林變多分三個階段長大", 10, 5, size=14, color=WHITE, outline=(24, 60, 30, 255))
    names = [("mound", "土堆洞穴"), ("cave", "岩洞"), ("stump", "樹洞"), ("tent", "營帳")]
    for r, (kind, label) in enumerate(names):
        y = 56 + r * 24
        a.text(label, 8, y - 14, size=12, color=WHITE, outline=(24, 60, 30, 255))
        for st in (1, 2, 3):
            x = 140 + (st - 1) * 110
            a.shadow(x, y + 6, 26 + st * 6, alpha=50)
            a.sprite(camp(kind, st), x, y + 6)
        if r == 0:
            for st, txt in zip((1, 2, 3), ("0 隻", "30 隻以上", "90 隻以上")):
                a.text(txt, 140 + (st - 1) * 110, 24, size=12, color=GOLD, outline=DARK, anchor="c")
    a.save(os.path.join(OUT, "camps.png"))


def wildlife_img():
    W, H = 400, 128
    a = Art(W, H, 4)
    dither_gradient(a, None, None, 0, 34, (110, 176, 226), (196, 226, 240), steps=5)
    grass(a, 32, seed=9)
    for x0, w in [(30, 26), (170, 30), (300, 24)][:0]:  # clouds
        a.rect(x0, 10, w, 5, WHITE); a.rect(x0 + 4, 7, w - 10, 4, WHITE); a.rect(x0 + 2, 14, w - 6, 2, (236, 244, 250, 255))
    # 1: a fruit tree with goblins picking
    tree(a, 40, 92, fruit=6, unit=3)
    a.shadow(40, 92, 30, alpha=40)
    for i, (dx, dy, b) in enumerate([(-22, 100, "scout"), (24, 102, "worker"), (2, 106, "sage")]):
        a.shadow(40 + dx, dy); a.sprite(goblin(b, "down", i), 40 + dx, dy)
    carrying = goblin("worker", "side", 1)
    a.sprite(carrying, 68, 112)
    a.rect(66, 96, 3, 3, (230, 46, 41, 255))
    # 2: hunting a pig
    a.shadow(200, 96, 20); a.sprite(animal("pig", 0), 200, 96, scale=2)
    for i, (dx, dy, b, side) in enumerate([(-30, 88, "brute", "side"), (-24, 108, "worker", "side"), (34, 86, "scout", "flip"), (30, 108, "worker", "flip")]):
        g = goblin(b, "side", i % 4)
        a.shadow(200 + dx, dy)
        a.sprite(flip(g) if side == "flip" else g, 200 + dx, dy)
    for k in range(4):  # a little burst where it was hit
        a.rect(196 + [-3, 4, -2, 5][k], 72 + [1, 0, -3, -2][k], 2, 2, (255, 214, 60, 255))
    hurt = goblin("worker", "down", 0)
    a.shadow(240, 118); a.sprite(hurt, 240, 118)
    a.rect(238, 98, 5, 5, WHITE); a.rect(240, 98, 1, 5, (216, 26, 26, 255)); a.rect(238, 100, 5, 1, (216, 26, 26, 255))
    # 3: meat hauled home
    a.sprite(camp("mound", 2), 350, 100)
    a.rect(300, 110, 10, 6, (199, 82, 61, 255)); a.rect(310, 111, 3, 4, (245, 238, 214, 255))
    for i, x in enumerate([322, 338]):
        a.shadow(x, 118 + i * 4); a.sprite(flip(goblin("worker", "side", i + 1)), x, 118 + i * 4)
        a.rect(x - 2, 100 + i * 4, 4, 3, (199, 82, 61, 255))
    for x, t in [(76, "① 碰到才發現果樹"), (200, "② 圍捕，豬會反擊"), (326, "③ 搬肉回營地")]:
        a.text(t, x, 6, size=14, color=WHITE, outline=(24, 60, 30, 255), anchor="c")
    a.save(os.path.join(OUT, "wildlife.png"))


def monitor(a, x, y, w, h, fill, header=(228, 228, 232, 255)):
    a.rect(x, y, w, h, (46, 46, 54, 255))
    a.rect(x + 2, y + 2, w - 4, h - 8, fill)
    a.rect(x + 2, y + 2, w - 4, 3, header)  # menu bar
    a.rect(x + w // 2 - 8, y + h - 5, 16, 5, (46, 46, 54, 255))  # foot
    a.rect(x + w // 2 - 12, y + h, 24, 2, (70, 70, 80, 255))
    return x + 2, y + 5, w - 4, h - 13


def modes_img():
    W, H = 400, 168
    a = Art(W, H, 4)
    backdrop(a, 8)
    a.text("四種狀態，一個快捷鍵切換", 10, 5, size=14, color=GOLD, outline=DARK)
    pw = 96
    specs = [("全開", "Ctrl+Opt+1", ["哥布林在畫面", "上活動"], "all"), ("工作模式", "Ctrl+Opt+2", ["營地藏起來，", "背景繼續長大"], "work"),
             ("節能模式", "Ctrl+Opt+3", ["營地藏起來，", "完全暫停"], "saver"), ("專注模式", "Ctrl+Opt+4", ["全部靜音暫停", "開會簡報用"], "focus")]
    for i, (name, key, lines, kind) in enumerate(specs):
        x = 6 + i * (pw + 4)
        panel(a, x, 24, pw, 140)
        fill = {"all": (58, 116, 62, 255), "work": (232, 236, 244, 255), "saver": (232, 236, 244, 255), "focus": (28, 28, 44, 255)}[kind]
        sx, sy, sw, sh = monitor(a, x + 8, 30, pw - 16, 62, fill, header=(210, 210, 216, 255) if kind != "focus" else (60, 60, 76, 255))
        if kind == "all":
            for gx, gy, b in [(sx + 14, sy + 38, "worker"), (sx + 34, sy + 30, "scout"), (sx + 52, sy + 42, "brute"), (sx + 28, sy + 50, "sage")]:
                a.sprite(goblin(b, "down", 1), gx, gy)
            a.sprite(camp("mound", 1), sx + 60, sy + 26)
            a.sprite(goblin("worker", "down", 0), sx + sw - 12, sy + 26)
            lcd_clock(a, sx + sw - 25, sy + 3, "24:59") if False else None
            a.rect(sx + sw - 12, sy + 2, 10, 5, (30, 30, 30, 255)); a.rect(sx + sw - 11, sy + 3, 8, 3, (189, 214, 158, 255))
        elif kind in ("work", "saver"):
            for r in range(5):  # a window with lines of code
                a.rect(sx + 8, sy + 10 + r * 6, [40, 30, 46, 22, 36][r], 2, [(90, 120, 220, 255), (220, 120, 90, 255), (90, 170, 110, 255), (170, 130, 210, 255), (120, 130, 150, 255)][r])
            a.rect(sx + sw - 13, sy + 2, 11, 6, (30, 30, 30, 255)); a.rect(sx + sw - 12, sy + 3, 9, 4, (189, 214, 158, 255))
            a.sprite(goblin("worker", "down", 0), sx + sw - 8, sy + 15)
            # a hint of the hidden camp: a dashed ghost
            for gx in range(sx + 6, sx + 26, 3):
                a.dot(gx, sy + sh - 12, (150, 160, 180, 255)); a.dot(gx, sy + sh - 2, (150, 160, 180, 255))
            a.text("在背景跑" if kind == "work" else "暫停", sx + 6, sy + sh - 10, size=8, color=(120, 130, 150, 255)) if False else None
            if kind == "work":
                # circular arrows: it keeps running
                for k in range(8):
                    ang = k * math.pi / 4
                    a.dot(sx + 16 + int(math.cos(ang) * 4), sy + sh - 6 + int(math.sin(ang) * 4), (90, 140, 240, 255))
            else:
                a.rect(sx + 13, sy + sh - 10, 2, 8, (90, 90, 110, 255)); a.rect(sx + 17, sy + sh - 10, 2, 8, (90, 90, 110, 255))  # pause
        else:
            moon(a, sx + sw // 2, sy + 22, 6)
            a.text("z z z", sx + sw // 2 + 8, sy + 8, size=9, color=(150, 150, 190, 255)) if False else None
            a.dot(sx + sw - 5, sy - 3, (255, 120, 120, 255))
        a.text(name, x + pw // 2, 100, size=14, color=WHITE, outline=DARK, anchor="c")
        a.text(key, x + pw // 2, 118, size=10, color=(190, 180, 240, 255), anchor="c", font=FONT_LATIN)
        for j, line in enumerate(lines):
            a.text(line, x + pw // 2, 130 + j * 13, size=12, color=(226, 220, 255, 255), anchor="c")
    a.save(os.path.join(OUT, "modes.png"))


def desktop(a, x, y, w, h):
    """A little desktop: wallpaper, menu bar, and a window of code."""
    dither_gradient(a, None, None, y, y + h, (86, 120, 196), (170, 150, 214), steps=6) if False else None
    a.rect(x, y, w, h, (110, 132, 200, 255))
    for i in range(6):
        a.rect(x, y + i * h // 6, w, h // 6, [(96, 120, 196, 255), (112, 128, 200, 255), (128, 134, 204, 255), (146, 140, 208, 255), (162, 146, 210, 255), (178, 154, 210, 255)][i])
    a.rect(x, y, w, 5, (238, 238, 242, 255))
    a.rect(x + 4, y + 1, 3, 3, (60, 60, 70, 255))
    for k in range(4):
        a.rect(x + 12 + k * 9, y + 2, 6, 1, (120, 120, 130, 255))
    a.sprite(goblin("worker", "down", 0).crop((0, 0, 16, 16)), x + w - 34, y + 5, bottom_center=False)
    a.rect(x + 14, y + 12, w - 60, h - 22, (250, 250, 252, 255))
    a.rect(x + 14, y + 12, w - 60, 5, (226, 226, 232, 255))
    for k in range(3):
        a.rect(x + 17 + k * 6, y + 13, 3, 3, [(240, 96, 88, 255), (244, 190, 80, 255), (96, 200, 100, 255)][k])
    for r in range(8):
        a.rect(x + 20 + (r % 3) * 6, y + 22 + r * 7, [50, 36, 60, 28, 46, 32, 54, 24][r], 2, [(90, 120, 220, 255), (220, 120, 90, 255), (90, 170, 110, 255), (170, 130, 210, 255)][r % 4])


def pomodoro_img():
    W, H = 400, 158
    a = Art(W, H, 4)
    backdrop(a, 12)
    a.text("番茄鐘：右上角的哥布林舉著時鐘倒數", 10, 5, size=14, color=GOLD, outline=DARK)
    dx, dy, dw, dh = 8, 26, 232, 118
    desktop(a, dx, dy, dw, dh)
    lcd_clock(a, dx + dw - 58, dy + 8, "12:34")
    a.shadow(dx + dw - 34, dy + 54); a.sprite(goblin("worker", "down", 0), dx + dw - 34, dy + 54)
    rows = [(26, "專注中：綠色", "12:34", {}), (68, "最後一分鐘：紅色", "00:42", {"alarm": True}), (110, "時間到後休息：藍色", "04:10", {"rest": True, "label": "休息"})]
    for y, label, t, kw in rows:
        a.text(label, 252, y, size=12, color=WHITE)
        lcd_clock(a, 252, y + 16, t, **kw)
    a.save(os.path.join(OUT, "pomodoro.png"))


def notify_img():
    W, H = 400, 150
    a = Art(W, H, 4)
    backdrop(a, 13)
    a.text("Claude 需要你、或做完了，哥布林會跳出來說話", 10, 5, size=14, color=GOLD, outline=DARK)
    a.rect(8, 26, 176, 118, (24, 24, 30, 255)); a.rect(8, 26, 176, 6, (62, 62, 72, 255))
    for k in range(3):
        a.rect(12 + k * 6, 28, 3, 3, [(240, 96, 88, 255), (244, 190, 80, 255), (96, 200, 100, 255)][k])
    lines = [(0, 60, (120, 200, 140, 255)), (1, 90, (200, 200, 210, 255)), (2, 70, (200, 200, 210, 255)), (3, 110, (200, 160, 100, 255)),
             (4, 50, (200, 200, 210, 255)), (6, 30, (120, 200, 140, 255))]
    for r, w, c in lines:
        a.rect(16, 38 + r * 9, w, 2, c)
    a.rect(16, 38 + 6 * 9 + 4, 4, 4, (240, 240, 240, 255))
    a.text("Claude Code", 16, 124, size=12, color=(150, 150, 170, 255), font=FONT_LATIN)
    bubble(a, 200, 28, ["那個…Claude 在等你確認喔。"], accent=(242, 140, 26, 255), tail_x=372, title="公主", size=12)
    a.shadow(376, 82, 16); a.sprite(princess("queen"), 376, 80)
    bubble(a, 200, 88, ["完成。哼。"], accent=(64, 166, 77, 255), tail_x=250, title="壯碩哥布林", size=12)
    a.shadow(254, 144, 16); a.sprite(goblin("brute", "down", 0), 254, 146)
    a.text("橘框：需要你決定", 290, 116, size=12, color=(255, 190, 110, 255))
    a.text("綠框：工作完成", 290, 132, size=12, color=(150, 230, 150, 255))
    a.save(os.path.join(OUT, "notify.png"))


def ask_img():
    W, H = 400, 132
    a = Art(W, H, 4)
    backdrop(a, 21)
    a.text("直接在泡泡上回答，或是自己去看", 10, 5, size=14, color=GOLD, outline=DARK)
    green, red, grey, ink = (51, 153, 71, 255), (199, 56, 51, 255), (230, 230, 230, 255), (30, 30, 30, 255)

    def button(x, y, label, fill, text):
        w = 12 * len(label) + 10
        a.rect(x, y, w, 15, (0, 0, 0, 70)); a.rect(x + 1, y + 1, w - 2, 13, fill)
        a.text(label, x + 5, y + 1, size=12, color=text)
        return w

    # 1: asking permission
    w, h = bubble(a, 8, 26, ["可以執行這個指令嗎？"], accent=(242, 140, 26, 255), tail_x=60, width=184, title="公主", size=12,
                  foot="執行：git push origin main", extra=20)
    x, y = 14, 26 + h - 22
    for label, fill, text in (("允許", green, WHITE), ("拒絕", red, WHITE), ("自己去看", grey, ink)):
        x += button(x, y, label, fill, text) + 4
    a.shadow(64, 108, 16); a.sprite(princess("queen"), 64, 106)
    # 2: replying
    bx = 208
    w, h = bubble(a, bx, 26, ["工作做完了！快來看！"], accent=(64, 166, 77, 255), tail_x=bx + 60, width=184, title="哥布林", size=12, extra=38)
    a.rect(bx + 6, 26 + h - 40, w - 12, 15, (190, 190, 190, 255)); a.rect(bx + 7, 26 + h - 39, w - 14, 13, WHITE)
    a.text("回覆 Claude…", bx + 10, 26 + h - 39, size=12, color=(150, 150, 150, 255))
    x, y = bx + 6, 26 + h - 22
    for label, fill, text in (("送出", green, WHITE), ("自己去看", grey, ink), ("不用了", grey, ink)):
        x += button(x, y, label, fill, text) + 4
    a.shadow(bx + 64, 124, 16); a.sprite(goblin("worker", "down", 0), bx + 64, 126)
    a.save(os.path.join(OUT, "ask.png"))


ALL = {"ask": ask_img, "cover": cover, "characters": characters, "princess": princess_img, "camps": camps_img, "wildlife": wildlife_img,
       "modes": modes_img, "pomodoro": pomodoro_img, "notify": notify_img}


if __name__ == "__main__":
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()
