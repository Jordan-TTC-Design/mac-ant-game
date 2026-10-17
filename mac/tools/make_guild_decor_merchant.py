"""The guild merchant's wares (GUILD.md, 2026-10-17): 60 rare, far-travelled pieces only he sells — far-east screens and
lanterns, desert rugs and a hookah, crystal lamps, a dragon egg, a ship in a bottle, an automaton… A member buys one with their
contribution and then the whole guild may put it down. Also the merchant himself (merchant.png, listed in the hall's manifest).
Run make_guild_decor.py (it imports this file, renders everything and calls write_merchant)."""
import json
import math
import os

from guild_decor_kit import *  # noqa: F401,F403
from guild_decor_kit import add_colors, drawers, legs, cushion, chair_back
import make_guild_decor as gd

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
M = dict(merchant=True)

add_colors({
    "m_jade": (96, 178, 140), "m_jade_d": (60, 132, 104), "m_jade_l": (160, 220, 186),
    "m_lacq": (178, 40, 36), "m_lacq_d": (124, 24, 26), "m_lacq_l": (220, 82, 70),
    "m_sand": (226, 196, 142), "m_sand_d": (190, 152, 100), "m_sand_l": (244, 222, 178),
    "m_brass": (206, 160, 64), "m_brass_d": (150, 108, 40), "m_brass_l": (240, 208, 120),
    "m_porc": (232, 238, 242), "m_porc_d": (184, 196, 210), "m_porc_b": (60, 96, 176),
    "m_silk": (224, 120, 160), "m_silk_d": (176, 80, 122), "m_silk_l": (248, 176, 204),
    "m_night": (36, 42, 92), "m_night_d": (24, 28, 64), "m_star": (255, 246, 190),
    "m_teal": (40, 140, 150), "m_teal_d": (24, 100, 112), "m_teal_l": (110, 200, 204),
    "m_rattan": (214, 170, 100), "m_rattan_d": (170, 126, 64),
    "m_tiger": (232, 140, 44), "m_tiger_d": (60, 40, 30),
    "m_koi": (248, 120, 60), "m_pond": (60, 120, 150), "m_pond_d": (40, 90, 120), "m_pond_l": (110, 170, 196),
    "m_phx": (244, 96, 40), "m_phx_l": (255, 200, 80), "m_phx_d": (190, 50, 30),
    "m_cloud": (240, 236, 250), "m_ember": (255, 120, 90),
})


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_lacquer_desk", "朱漆矮書桌", C1, 2, 36, 22, note="遠東來的朱漆書桌，桌腳雕成雲朵，角色可以坐在後面", **M)
def _(c, f):
    table(c, 1, 6, 34, 21, wood="m_lacq", depth=3)
    R(c, 4, 12, 31, 13, "m_lacq_d")
    for x in (3, 32):
        R(c, x - 1, 18, x + 1, 19, "gold"); c.put(x, 20, "gold_d")
    R(c, 7, 3, 12, 5, "paper"); R(c, 8, 4, 11, 4, "ink"); R(c, 24, 2, 25, 5, "black"); R(c, 27, 4, 30, 5, "m_porc")
    c.put(28, 3, "m_porc_b")


@item("m_silk_cushion", "絲綢坐墊", C1, 1, 20, 12, seat=True, note="金線繡的絲綢坐墊，四角有流蘇", **M)
def _(c, f):
    sy = 12 - 1 - SEAT_UP
    cushion(c, 2, sy - 3, 17, 10, "m_silk", "m_silk_l", "m_silk_d")
    R(c, 6, sy - 1, 13, sy - 1, "gold"); c.put(9, sy, "gold"); c.put(10, sy, "gold")
    for x in (1, 18):
        c.put(x, sy - 3, "gold"); c.put(x, 10, "gold")


@item("m_peacock_chair", "藤編孔雀椅", C1, 2, 28, 36, seat=True, note="椅背像孔雀開屏的藤椅", **M)
def _(c, f):
    h = 36
    sy = h - 1 - SEAT_UP
    circle(c, 13.5, 14, 13, "m_rattan_d", 13)
    circle(c, 13.5, 14, 12, "m_rattan", 12)
    for a in range(9):                                                    # the fan of plumes, each with its eye
        ang = math.pi * (0.05 + 0.9 * a / 8)
        for t in range(3, 12):
            c.put(13.5 - math.cos(ang) * t, 14 - math.sin(ang) * t, "m_rattan_d")
        ex, ey = 13.5 - math.cos(ang) * 9.5, 14 - math.sin(ang) * 9.5
        circle(c, ex, ey, 1.6, "m_teal"); c.put(ex, ey, "m_porc_b")
    R(c, 6, sy - 2, 21, sy + 1, "m_rattan"); R(c, 6, sy - 2, 21, sy - 2, "m_sand_l")
    cushion(c, 7, sy - 4, 20, sy - 1, "m_teal", "m_teal_l", "m_teal_d")
    R(c, 9, sy + 2, 18, h - 2, "m_rattan_d")
    for y in range(sy + 2, h - 1, 2):
        R(c, 9, y, 18, y, "m_rattan")
    R(c, 7, h - 1, 20, h - 1, "m_rattan_d")


@item("m_saddle_stool", "駱駝鞍凳", C1, 1, 20, 20, seat=True, note="沙漠商隊的駱駝鞍改成的凳子", **M)
def _(c, f):
    h = 20
    sy = h - 1 - SEAT_UP
    R(c, 3, sy - 3, 16, sy, "leather"); R(c, 3, sy - 3, 16, sy - 3, "leather_l")
    R(c, 2, sy - 6, 4, sy - 1, "m_brass"); R(c, 15, sy - 6, 17, sy - 1, "m_brass"); c.put(3, sy - 7, "m_brass_l"); c.put(16, sy - 7, "m_brass_l")
    R(c, 6, sy - 2, 13, sy - 2, "m_lacq"); R(c, 6, sy - 1, 13, sy - 1, "m_sand")
    R(c, 4, sy + 1, 5, h - 1, "wood_d"); R(c, 14, sy + 1, 15, h - 1, "wood_d"); R(c, 4, h - 4, 15, h - 4, "wood")


@item("m_jade_throne", "翡翠寶座", C1, 4, 36, 42, seat=True, note="整塊翡翠雕出的寶座，椅背是一條盤龍", **M)
def _(c, f):
    h = 42
    sy = h - 1 - SEAT_UP
    box(c, 5, 3, 30, sy, "m_jade", "m_jade_l", "m_jade_d")
    R(c, 8, 6, 27, sy - 3, "m_jade_d")
    for i in range(24):                                                   # the coiled dragon on the back
        x = 9 + i * 0.75
        y = 14 + math.sin(i / 3.2) * 5
        R(c, x, y, x + 1, y + 1, "gold")
    circle(c, 25, 10, 2.5, "gold"); c.put(26, 9, "m_lacq")
    R(c, 1, sy - 9, 6, h - 2, "m_jade"); R(c, 29, sy - 9, 34, h - 2, "m_jade"); R(c, 1, sy - 9, 6, sy - 9, "m_jade_l"); R(c, 29, sy - 9, 34, sy - 9, "m_jade_l")
    cushion(c, 7, sy - 2, 28, sy + 1, "m_lacq", "m_lacq_l", "m_lacq_d")
    R(c, 7, sy + 2, 28, h - 2, "m_jade_d"); R(c, 0, h - 1, 35, h - 1, "m_jade_d")
    c.put(3, sy - 10, "gold"); c.put(31, sy - 10, "gold")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_spice_chest", "香料箱", C2, 1, 22, 20, 2, 2, note="打開會飄出香氣的香料箱，裡面分成好幾格", **M)
def _(c, f):
    box(c, 2, 8, 19, 18, "wood", "wood_l", "wood_d")
    R(c, 2, 12, 19, 12, "m_brass"); c.put(10, 13, "m_brass_l"); c.put(11, 13, "m_brass_l")
    if f:
        R(c, 2, 2, 19, 5, "wood_d"); R(c, 3, 6, 18, 8, "black")
        for x, k in ((4, "orange"), (8, "m_lacq"), (12, "yellow"), (16, "green")):
            R(c, x, 7, x + 2, 8, k)
        c.put(6, 1, "m_sand_l"); c.put(13, 0, "m_sand_l")
    else:
        R(c, 2, 5, 19, 8, "wood"); R(c, 2, 5, 19, 5, "wood_l")
    R(c, 1, 19, 20, 19, "wood_x")


@item("m_lacquer_cabinet", "朱漆描金櫃", C2, 2, 26, 36, note="朱漆底、描著金色花鳥的高櫃", **M)
def _(c, f):
    box(c, 2, 2, 23, 33, "m_lacq", "m_lacq_l", "m_lacq_d")
    R(c, 12, 4, 13, 31, "m_lacq_d")
    for x0 in (4, 15):
        R(c, x0, 5, x0 + 6, 30, "m_lacq")
        R(c, x0 + 1, 8, x0 + 5, 8, "gold"); circle(c, x0 + 3, 14, 2, "gold"); c.put(x0 + 3, 14, "m_lacq")
        R(c, x0 + 1, 20, x0 + 2, 26, "gold_d"); R(c, x0 + 4, 22, x0 + 5, 27, "gold_d")
    c.put(11, 17, "gold_l"); c.put(14, 17, "gold_l")
    R(c, 3, 34, 5, 35, "black"); R(c, 20, 34, 22, 35, "black")


@item("m_curio_shelf", "奇珍陳列架", C2, 2, 32, 38, note="一格一格放著貝殼、獸牙、小雕像的陳列架", **M)
def _(c, f):
    box(c, 1, 1, 30, 37, "dark", "dark_l", "dark_d")
    cells = [(3, 3, 12, 11), (14, 3, 28, 11), (3, 13, 17, 22), (19, 13, 28, 22), (3, 24, 10, 34), (12, 24, 28, 34)]
    for x0, y0, x1, y1 in cells:
        R(c, x0, y0, x1, y1, "dark_d")
    circle(c, 7.5, 9, 3, "m_silk_l", 2); c.put(7, 8, "white")                # a shell
    R(c, 17, 7, 18, 10, "cloth"); R(c, 21, 5, 23, 10, "m_jade"); c.put(22, 4, "m_jade_l")
    circle(c, 25.5, 9, 1.8, "m_porc"); R(c, 6, 18, 14, 21, "m_brass"); c.put(10, 17, "m_brass_l")
    R(c, 22, 15, 25, 21, "glass"); c.put(23, 16, "glow"); R(c, 5, 29, 8, 33, "m_teal"); circle(c, 20, 30, 3.5, "m_lacq", 3); c.put(19, 29, "m_lacq_l")


@item("m_chained_trunk", "鎖鍊寶箱", C2, 2, 30, 24, 2, 2, note="被鐵鍊捆住的舊寶箱，縫隙偶爾閃一下", **M)
def _(c, f):
    box(c, 2, 10, 27, 22, "wood", "wood_l", "wood_d")
    R(c, 2, 4, 27, 10, "wood_d"); R(c, 3, 3, 26, 3, "wood"); R(c, 2, 10, 27, 10, "black")
    for x in (7, 22):
        R(c, x, 3, x + 1, 22, "iron"); R(c, x, 3, x, 22, "iron_l")
    R(c, 2, 15, 27, 16, "iron"); R(c, 12, 12, 17, 18, "iron_d"); R(c, 13, 13, 16, 17, "gold"); c.put(14, 15, "black")
    if f:
        R(c, 10, 10, 19, 10, "gold_l"); c.put(25, 9, "glow")
    R(c, 1, 23, 28, 23, "wood_x")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_ship_bottle", "瓶中船", C3, 1, 22, 14, note="橫躺的玻璃瓶裡有一艘小帆船", **M)
def _(c, f):
    circle(c, 10, 7, 8, "glass", 5); circle(c, 10.5, 7.5, 7, "glass_d", 4)
    R(c, 17, 5, 20, 8, "glass"); R(c, 20, 5, 21, 8, "wood")
    R(c, 5, 9, 15, 10, "wood"); R(c, 6, 11, 14, 11, "wood_d"); R(c, 9, 3, 9, 8, "wood_d")
    R(c, 6, 4, 8, 8, "cloth"); R(c, 10, 3, 13, 8, "cloth"); c.put(9, 2, "m_lacq")
    c.put(5, 4, "glow"); R(c, 3, 12, 17, 12, "m_porc_b")


@item("m_celadon_tea", "青瓷茶具", C3, 1, 22, 14, 2, 2, note="一壺兩杯的青瓷茶具，冒著熱氣", **M)
def _(c, f):
    R(c, 1, 11, 20, 12, "wood"); R(c, 1, 13, 20, 13, "wood_d")
    circle(c, 8, 7, 4, "m_jade_l", 3.5); circle(c, 8.5, 7.5, 3, "m_jade", 2.5); R(c, 7, 2, 9, 3, "m_jade_d")
    R(c, 12, 6, 14, 6, "m_jade_l"); c.put(15, 5, "m_jade_l"); R(c, 2, 6, 3, 9, "m_jade_d")
    for x in (15, 18):
        R(c, x, 8, x + 2, 10, "m_jade_l"); R(c, x, 8, x + 2, 8, "white")
    for i, y in enumerate((1, 0)):
        c.put(16 + (i + f) % 2, y + 5 - 4, "white")
    c.put(8 + f, 0, "white")


@item("m_golden_hourglass", "黃金沙漏", C3, 1, 14, 22, 3, 2, note="金沙一直往下流的沙漏", **M)
def _(c, f):
    R(c, 1, 1, 12, 2, "m_brass"); R(c, 1, 19, 12, 20, "m_brass"); R(c, 1, 3, 1, 18, "m_brass_d"); R(c, 12, 3, 12, 18, "m_brass_d")
    for y in range(3, 19):
        half = 1 + abs(y - 10.5) * 0.55
        R(c, 6.5 - half, y, 6.5 + half, y, "glass")
    top = 4 + f
    for y in range(top, 9):
        half = abs(y - 10.5) * 0.55
        R(c, 6.5 - half, y, 6.5 + half, y, "gold")
    for y in range(17 - f, 19):
        half = abs(y - 10.5) * 0.55
        R(c, 6.5 - half, y, 6.5 + half, y, "gold")
    R(c, 6, 9, 6, 16, "gold_l")
    R(c, 0, 21, 13, 21, "m_brass_d")


@item("m_music_box", "八音盒", C3, 1, 16, 20, 4, 3, note="打開的八音盒，小舞者會轉圈", **M)
def _(c, f):
    box(c, 1, 12, 14, 19, "m_lacq", "m_lacq_l", "m_lacq_d"); R(c, 1, 6, 14, 8, "m_lacq_d"); R(c, 2, 9, 13, 11, "m_silk_d")
    R(c, 3, 15, 12, 15, "gold")
    turn = [0, 1, 0, -1][f]
    R(c, 7, 6, 8, 10, "m_porc"); circle(c, 7.5, 4, 1.5, "skin")
    R(c, 7 - 2 - turn, 6, 8 + 2 - turn, 7, "m_silk_l")
    c.put(5 + f % 2 * 6, 2, "m_star")


@item("m_dragon_egg", "龍蛋座", C3, 1, 16, 24, 2, 2, note="黃銅托座上的龍蛋，裡面隱隱發光", **M)
def _(c, f):
    R(c, 3, 19, 12, 20, "m_brass"); R(c, 5, 21, 10, 21, "m_brass_d"); R(c, 2, 22, 13, 23, "m_brass_d")
    R(c, 4, 16, 4, 18, "m_brass"); R(c, 11, 16, 11, 18, "m_brass")
    circle(c, 7.5, 10, 5, "purple_d", 7.5); circle(c, 7, 9.5, 4, "purple", 6.5)
    for x, y in ((5, 6), (9, 9), (6, 13), (10, 14)):
        c.put(x, y, "purple_l")
    if f:
        R(c, 7, 8, 8, 12, "m_ember"); c.put(7, 10, "f1")
    c.put(5, 4, "white")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_paper_lantern", "紅紙燈籠", C4, 1, 16, 28, 2, 2, ceiling=True, note="垂下來的紅紙燈籠，底下有金流蘇", **M)
def _(c, f):
    R(c, 7, 0, 8, 5, "black")
    sway = f
    R(c, 4 + sway, 6, 11 + sway, 7, "black")
    circle(c, 7.5 + sway, 13, 6, "m_lacq", 6); circle(c, 7 + sway, 12.5, 4.5, "m_lacq_l", 5)
    for y in (9, 13, 17):
        R(c, 3 + sway, y, 12 + sway, y, "m_lacq_d")
    R(c, 6 + sway, 11, 9 + sway, 14, "f1")
    R(c, 4 + sway, 19, 11 + sway, 20, "black")
    for x in range(5, 11, 2):
        R(c, x + sway, 21, x + sway, 25, "gold")


@item("m_crystal_lamp", "魔法水晶燈", C4, 1, 16, 28, 3, 3, note="會慢慢變色的水晶燈", **M)
def _(c, f):
    plinth(c, 4, 11, 22, 26)
    R(c, 6, 16, 9, 21, "m_brass"); R(c, 6, 16, 6, 21, "m_brass_l")
    glow = ["glass", "m_silk_l", "rune"][f]
    for y in range(2, 16):
        half = int(4 - abs(y - 9) * 0.55)
        if half >= 0:
            R(c, 7.5 - half, y, 7.5 + half, y, glow)
    R(c, 7, 3, 7, 14, "glow"); c.put(4, 8, "glow")


@item("m_brass_lantern", "鏤空銅燈", C4, 1, 16, 26, 2, 3, note="沙漠城市的鏤空銅燈，牆上投出星星", **M)
def _(c, f):
    R(c, 7, 0, 8, 2, "m_brass_d"); circle(c, 7.5, 3, 2, "m_brass")
    for y in range(5, 20):
        half = int(5 - abs(y - 12) * 0.35)
        R(c, 7.5 - half, y, 7.5 + half, y, "m_brass" if (y + f) % 3 else "m_brass_d")
    for x, y in ((5, 9), (9, 11), (6, 14), (10, 15), (7, 17)):
        c.put(x + (f if y % 2 else 0), y, "f1")
    R(c, 4, 20, 11, 21, "m_brass_d"); R(c, 5, 22, 10, 25, "m_brass"); R(c, 3, 25, 12, 25, "m_brass_d")


@item("m_star_chandelier", "星辰吊燈", C4, 4, 48, 32, 3, 3, ceiling=True, note="一圈一圈的銅環掛著會閃的星星", **M)
def _(c, f):
    R(c, 23, 0, 24, 6, "m_brass_d")
    for r, y in ((20, 12), (13, 18), (6, 23)):
        R(c, 23.5 - r, y, 24.5 + r, y + 1, "m_brass"); R(c, 23.5 - r, y, 24.5 + r, y, "m_brass_l")
        for k, x in enumerate(range(int(24 - r), int(25 + r), 5)):
            star = "m_star" if (k + f) % 3 else "white"
            c.put(x, y + 3, "m_brass_d"); c.put(x, y + 4, star); c.put(x - 1, y + 5, star); c.put(x + 1, y + 5, star); c.put(x, y + 6, star)
    for x in (4, 43):
        R(c, x, 7, x, 11, "m_brass_d")
    circle(c, 24, 28, 2.5, "glass"); c.put(24, 28, "glow" if f != 1 else "m_star")


@item("m_firefly_jar", "螢火蟲罐燈", C4, 1, 14, 20, 3, 3, note="裝著一群螢火蟲的玻璃罐", **M)
def _(c, f):
    R(c, 3, 1, 10, 3, "cloth"); R(c, 2, 4, 11, 4, "straw_d")
    R(c, 2, 5, 11, 18, "glass"); R(c, 3, 6, 10, 17, "glass_d"); R(c, 2, 19, 11, 19, "glass")
    pts = [((4, 8), (8, 12), (6, 15), (9, 7)), ((5, 10), (9, 9), (4, 14), (7, 16)), ((7, 7), (5, 12), (9, 14), (6, 9))][f]
    for x, y in pts:
        c.put(x, y, "f1"); c.put(x + 1, y, "yellow")
    c.put(3, 6, "glow")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_ink_scroll", "山水捲軸", C5, 1, 16, 32, wall=True, note="水墨山水的掛軸", **M)
def _(c, f):
    R(c, 1, 1, 14, 2, "wood_d"); R(c, 7, 0, 8, 0, "black")
    R(c, 2, 3, 13, 28, "paper"); R(c, 2, 3, 2, 28, "paper_d")
    for i in range(6):
        R(c, 3 + i, 18 - i * 2, 4 + i, 22, "iron_d" if i % 2 else "iron")
    for i in range(4):
        R(c, 9 + i, 20 - i, 10 + i, 22, "iron_l")
    R(c, 3, 23, 12, 23, "m_porc_b"); c.put(11, 6, "m_lacq"); c.put(11, 7, "m_lacq")
    R(c, 1, 29, 14, 30, "wood_d")


@item("m_flying_carpet", "飛毯掛毯", C5, 2, 36, 24, 2, 2, wall=True, note="傳說會飛的地毯，掛在牆上還會微微飄", **M)
def _(c, f):
    for x in range(1, 35):
        dy = int(round(math.sin(x / 5 + f * 1.5)))
        R(c, x, 3 + dy, x, 20 + dy, "m_teal")
        if x in (1, 2, 33, 34):
            R(c, x, 3 + dy, x, 20 + dy, "gold")
        else:
            c.put(x, 4 + dy, "gold"); c.put(x, 19 + dy, "gold")
            if 8 < x < 28:
                y = 11 + dy + (1 if (x // 3) % 2 else -1)
                c.put(x, y, "m_lacq"); c.put(x, y + 1, "m_lacq_d")
    for x in range(2, 35, 3):
        c.put(x, 21 + int(round(math.sin(x / 5 + f * 1.5))), "gold_d")
    R(c, 3, 1, 32, 1, "m_brass_d")


@item("m_tribal_mask", "異國面具", C5, 1, 18, 22, wall=True, note="遠方部族的彩繪木面具", **M)
def _(c, f):
    circle(c, 8.5, 10, 7, "wood", 9); circle(c, 8, 9.5, 6, "wood_l", 8)
    R(c, 4, 7, 7, 9, "black"); R(c, 10, 7, 13, 9, "black"); c.put(5, 8, "f1"); c.put(12, 8, "f1")
    R(c, 3, 11, 5, 12, "m_lacq"); R(c, 12, 11, 14, 12, "m_lacq"); R(c, 6, 15, 11, 16, "white"); R(c, 7, 16, 10, 16, "black")
    R(c, 8, 1, 9, 3, "m_teal"); c.put(5, 2, "m_teal"); c.put(12, 2, "m_teal")
    for x in (2, 15):
        R(c, x, 18, x, 21, "m_sand_d")


@item("m_old_world_map", "古世界地圖", C5, 2, 38, 26, wall=True, note="畫著海怪的古老世界地圖", **M)
def _(c, f):
    R(c, 1, 2, 36, 23, "parch"); R(c, 1, 2, 36, 2, "parch_d"); R(c, 36, 3, 36, 23, "parch_d")
    R(c, 0, 1, 1, 24, "wood_d"); R(c, 36, 1, 37, 24, "wood_d")
    for cx, cy, r, ry in ((10, 9, 5, 3), (24, 14, 6, 4), (15, 18, 3, 2)):
        circle(c, cx, cy, r, "green_l", ry); circle(c, cx + 0.5, cy + 0.5, r - 1.5, "m_sand", ry - 1)
    for x in (30, 31, 32):
        c.put(x, 6 + (x % 2), "blue"); c.put(x + 1, 7, "blue_d")
    c.put(31, 5, "m_lacq")                                                   # the sea serpent's eye
    circle(c, 5, 19, 2.5, "m_brass"); c.put(5, 17, "m_lacq"); c.put(5, 21, "black")
    R(c, 18, 6, 18, 6, "m_lacq"); R(c, 17, 7, 19, 7, "m_lacq")


@item("m_cuckoo_clock", "布穀鳥鐘", C5, 1, 20, 30, 2, 1, wall=True, note="整點會有小鳥探出頭的木雕鐘", **M)
def _(c, f):
    for i in range(6):
        R(c, 9 - i * 1.5, 1 + i, 10 + i * 1.5, 1 + i, "wood_d")
    box(c, 2, 7, 17, 20, "wood", "wood_l", "wood_d")
    circle(c, 9.5, 14, 4, "paper"); c.put(9, 12, "black"); c.put(9, 13, "black"); c.put(10, 14, "black"); c.put(11, 14, "black")
    R(c, 8, 8, 11, 9, "black")
    if f:
        R(c, 8, 8, 11, 9, "yellow"); c.put(12, 9, "orange"); c.put(9, 8, "black")
    R(c, 6, 21, 6, 26, "m_brass_d"); R(c, 13, 21, 13, 28, "m_brass_d")
    R(c, 5, 26, 7, 28, "m_brass"); R(c, 12, 28, 14, 29, "m_brass")
    for x in (3, 16):
        c.put(x, 8, "green_d"); c.put(x, 9, "green")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_desert_rug", "沙漠紋地毯", C6, 2, 40, 26, flat=True, note="沙丘與綠洲紋樣的長地毯", **M)
def _(c, f):
    rug_base(c, 40, 26, "m_sand", "m_lacq_d", "m_lacq")
    for i in range(5):
        x0 = 7 + i * 6
        for d in range(3):
            c.put(x0 + d, 10 - d, "m_lacq_d"); c.put(x0 + 5 - d, 10 - d, "m_lacq_d")
            c.put(x0 + d, 15 + d, "m_teal"); c.put(x0 + 5 - d, 15 + d, "m_teal")
    R(c, 18, 12, 21, 13, "m_teal")


@item("m_tiger_rug", "虎皮地毯", C6, 2, 40, 26, flat=True, note="(仿的) 虎皮地毯，頭還瞪著人", **M)
def _(c, f):
    circle(c, 20, 14, 12, "m_tiger", 8)
    for x in (4, 34):
        R(c, x, 6, x + 2, 8, "m_tiger"); R(c, x, 19, x + 2, 21, "m_tiger")
    R(c, 32, 13, 38, 14, "m_tiger"); c.put(38, 12, "m_tiger_d")
    for x in range(12, 30, 4):
        R(c, x, 8, x, 11, "m_tiger_d"); R(c, x + 1, 16, x + 1, 19, "m_tiger_d")
    circle(c, 6, 13.5, 4, "m_tiger", 4); c.put(4, 10, "m_tiger"); c.put(8, 10, "m_tiger")
    c.put(4, 12, "black"); c.put(7, 12, "black"); R(c, 4, 15, 7, 15, "white"); c.put(5, 15, "black")


@item("m_mosaic_rug", "星芒馬賽克地毯", C6, 4, 56, 36, flat=True, note="一塊一塊拼出星芒的大地毯", **M)
def _(c, f):
    rug_base(c, 56, 36, "m_night", "m_brass", "m_night_d")
    for r in range(11):
        k = "m_teal" if r % 2 else "m_teal_l"
        R(c, 28 - r * 2, 18 - r // 2, 27 + r * 2, 18 - r // 2, k if r > 2 else "m_star")
        R(c, 28 - r * 2, 17 + r // 2, 27 + r * 2, 17 + r // 2, k if r > 2 else "m_star")
    for x, y in ((8, 8), (47, 8), (8, 27), (47, 27)):
        R(c, x - 1, y, x + 1, y, "m_star"); R(c, x, y - 1, x, y + 1, "m_star")


@item("m_tatami", "榻榻米", C6, 2, 34, 26, flat=True, note="遠東來的草蓆，邊上鑲了黑布", **M)
def _(c, f):
    R(c, 1, 1, 32, 24, "straw"); R(c, 1, 1, 32, 2, "black"); R(c, 1, 23, 32, 24, "black")
    for y in range(4, 22, 2):
        R(c, 2, y, 31, y, "straw_d")
    R(c, 16, 3, 17, 22, "straw_d")


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_pine_bonsai", "松樹盆景", C7, 1, 22, 22, note="修剪了上百年的小松樹", **M)
def _(c, f):
    R(c, 3, 17, 18, 20, "m_porc_b"); R(c, 3, 17, 18, 17, "m_porc"); R(c, 5, 21, 6, 21, "m_porc_b"); R(c, 15, 21, 16, 21, "m_porc_b")
    for i in range(8):
        R(c, 10 - i * 0.6, 16 - i, 11 - i * 0.6, 16 - i, "wood_d")
    R(c, 6, 9, 14, 9, "wood_d")
    blob(c, 5, 7, 3.5, "green_d", "green_d", "green", 2); blob(c, 14, 7, 4, "green", "green_d", "green_l", 2.2); blob(c, 9, 3, 3, "green", "green_d", "green_l", 2)


@item("m_lotus_bowl", "蓮花缸", C7, 2, 28, 20, 2, 2, note="陶缸裡開著蓮花，偶爾有小魚翻身", **M)
def _(c, f):
    circle(c, 13.5, 13, 12, "pot_d", 6); circle(c, 13.5, 12, 11, "pot", 5)
    circle(c, 13.5, 10, 10, "m_pond", 3); circle(c, 13.5, 10, 8, "m_pond_l", 2)
    circle(c, 7, 10, 3, "green", 1.5); circle(c, 20, 11, 3.5, "green_d", 1.6)
    for x, y in ((12, 5), (11, 6), (13, 6), (12, 7)):
        c.put(x, y, "m_silk_l")
    c.put(12, 6, "yellow"); R(c, 12, 8, 12, 9, "green_d")
    if f:
        c.put(17, 9, "m_koi"); c.put(18, 9, "m_koi")
    R(c, 6, 19, 21, 19, "pot_d")


@item("m_lucky_bamboo", "富貴竹", C7, 1, 14, 32, note="青瓷盆裡的幾節富貴竹", **M)
def _(c, f):
    R(c, 2, 25, 11, 30, "m_porc"); R(c, 2, 25, 11, 25, "white"); R(c, 11, 26, 11, 30, "m_porc_d"); R(c, 4, 27, 9, 27, "m_porc_b")
    for x, top in ((4, 4), (7, 1), (9, 8)):
        R(c, x, top, x, 24, "green");
        for y in range(top + 4, 24, 5):
            c.put(x, y, "green_d")
        c.put(x + 1, top + 2, "green_l"); c.put(x - 1, top + 6, "green_l")
    R(c, 2, 31, 11, 31, "m_porc_d")


@item("m_crystal_bloom", "水晶花", C7, 1, 16, 22, 2, 2, note="長在花盆裡的水晶，會一閃一閃", **M)
def _(c, f):
    pot(c, 8, 21, 10, 5, "pot")
    for x, top, k in ((5, 6, "glass"), (8, 2, "m_silk_l"), (11, 7, "glass")):
        for y in range(top, 16):
            half = min(y - top, 2) // 1
            R(c, x - half * 0.5, y, x + half * 0.5, y, k)
        c.put(x, top + 2, "glow")
    if f:
        c.put(3, 4, "m_star"); c.put(13, 3, "m_star")


@item("m_date_palm", "椰棗盆栽", C7, 2, 30, 42, note="沙漠綠洲來的椰棗樹，掛著一串串果子", **M)
def _(c, f):
    R(c, 9, 34, 20, 40, "pot"); R(c, 8, 33, 21, 34, "pot_d"); R(c, 20, 35, 20, 40, "pot_d")
    for y in range(12, 34):
        R(c, 14 + (y % 4 == 0), y, 15 + (y % 4 == 0), y, "wood" if y % 3 else "wood_d")
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        for t in range(12):
            x = 14.5 + math.cos(a) * t * 1.1
            y = 11 + math.sin(a) * t * 0.6 + (t * t) * 0.05
            c.put(x, y, "green" if t % 3 else "green_d")
    for x in (11, 13, 17, 19):
        c.put(x, 14, "m_brass_d"); c.put(x, 15, "brown")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_jade_dragon", "玉龍雕像", C8, 2, 30, 32, note="盤在雲上的玉雕小龍", **M)
def _(c, f):
    plinth(c, 5, 24, 26, 31)
    for i in range(30):
        t = i / 29
        x = 6 + t * 18 + math.sin(t * 9) * 2
        y = 22 - t * 14 + math.cos(t * 7) * 3
        R(c, x, y, x + 2, y + 2, "m_jade" if i % 4 else "m_jade_d")
    circle(c, 25, 7, 3.5, "m_jade_l", 3); c.put(26, 6, "black"); R(c, 27, 8, 29, 8, "m_jade_d")
    c.put(23, 3, "m_jade_l"); c.put(25, 3, "m_jade_l")
    for x in range(7, 24, 4):
        circle(c, x, 24, 2, "m_cloud", 1.2)


@item("m_little_sphinx", "人面獅身像", C8, 2, 34, 26, note="從沙漠運來的小獅身人面像", **M)
def _(c, f):
    R(c, 2, 21, 31, 25, "m_sand_d"); R(c, 2, 21, 31, 21, "m_sand")
    R(c, 6, 13, 26, 20, "m_sand"); R(c, 6, 13, 26, 13, "m_sand_l"); R(c, 26, 14, 26, 20, "m_sand_d")
    R(c, 26, 17, 31, 20, "m_sand"); R(c, 4, 15, 6, 20, "m_sand_d")
    R(c, 21, 3, 29, 12, "m_sand"); R(c, 20, 4, 21, 14, "m_teal"); R(c, 29, 4, 30, 14, "m_teal")
    for y in range(4, 14, 2):
        R(c, 20, y, 21, y, "m_brass"); R(c, 29, y, 30, y, "m_brass")
    c.put(23, 7, "black"); c.put(27, 7, "black"); R(c, 24, 10, 26, 10, "m_sand_d"); R(c, 22, 2, 28, 3, "m_teal")


@item("m_automaton", "發條機械人", C8, 2, 20, 38, 3, 3, note="背上有發條、會點頭的黃銅機械人", **M)
def _(c, f):
    nod = [0, 1, 0][f]
    R(c, 6, 32, 9, 36, "m_brass_d"); R(c, 11, 32, 14, 36, "m_brass_d"); R(c, 5, 37, 15, 37, "m_brass_d")
    box(c, 4, 16, 15, 31, "m_brass", "m_brass_l", "m_brass_d")
    circle(c, 9.5, 23, 3, "m_brass_d"); circle(c, 9.5, 23, 1.5, "gold_l")
    R(c, 1, 17, 3, 27, "m_brass_d"); R(c, 16, 17, 18, 27, "m_brass_d")
    box(c, 5, 5 + nod, 14, 14 + nod, "m_brass", "m_brass_l", "m_brass_d")
    R(c, 7, 8 + nod, 8, 9 + nod, "rune"); R(c, 11, 8 + nod, 12, 9 + nod, "rune"); R(c, 8, 12 + nod, 11, 12 + nod, "m_brass_d")
    R(c, 9, 1 + nod, 10, 4 + nod, "iron"); c.put(9 + f % 2, 0 + nod, "m_lacq")
    R(c, 16, 19, 18, 19, "iron_l"); R(c, 17, 18 - (f == 1), 17, 20 + (f == 1), "iron_l")       # the key, turning


@item("m_orrery", "星象儀", C8, 1, 20, 28, 3, 2, note="行星繞著太陽轉的黃銅星象儀", **M)
def _(c, f):
    R(c, 9, 17, 10, 24, "m_brass_d"); R(c, 4, 25, 15, 27, "m_brass"); R(c, 4, 25, 15, 25, "m_brass_l")
    for a in range(0, 360, 12):
        r = math.radians(a)
        c.put(9.5 + math.cos(r) * 8, 10 + math.sin(r) * 3, "m_brass_d")
    circle(c, 9.5, 10, 2.5, "f1"); c.put(9, 9, "f4")
    for k, (rad, col) in enumerate(((8, "blue_l"), (5, "m_lacq_l"))):
        a = math.radians(f * 120 + k * 150)
        c.put(9.5 + math.cos(a) * rad, 10 + math.sin(a) * rad * 0.38, col); c.put(10.5 + math.cos(a) * rad, 10 + math.sin(a) * rad * 0.38, col)


@item("m_meteor_shard", "隕石碎片", C8, 1, 20, 20, 2, 2, note="天上掉下來的石頭，裂縫裡還在發光", **M)
def _(c, f):
    plinth(c, 4, 15, 15, 19)
    circle(c, 10, 9, 6.5, "black", 5.5); circle(c, 9.5, 8.5, 5.5, "iron_d", 4.5)
    for x, y in ((7, 6), (11, 9), (8, 11), (12, 6)):
        c.put(x, y, "m_teal_l" if f else "m_teal")
    R(c, 9, 7, 10, 10, "m_teal_l" if f else "m_teal"); c.put(6, 5, "iron_l")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_go_board", "圍棋桌", C9, 2, 30, 22, note="下到一半的棋局", **M)
def _(c, f):
    box(c, 3, 3, 26, 14, "wood_l", "m_sand_l", "wood")
    for x in range(5, 26, 3):
        R(c, x, 4, x, 13, "wood_d")
    for y in range(5, 14, 3):
        R(c, 4, y, 25, y, "wood_d")
    for x, y, k in ((8, 5, "black"), (11, 8, "white"), (14, 8, "black"), (17, 11, "white"), (20, 5, "black"), (14, 11, "white")):
        c.put(x, y, k)
    R(c, 3, 15, 26, 17, "wood"); R(c, 3, 17, 26, 17, "wood_d")
    legs(c, (5, 24), 18, 21, "wood_d")
    circle(c, 1.5, 19, 1.5, "black"); circle(c, 28, 19, 1.5, "m_porc")


@item("m_hookah", "水煙壺", C9, 1, 16, 28, 4, 3, note="冒著甜甜煙圈的水煙壺", **M)
def _(c, f):
    circle(c, 7.5, 22, 5, "glass_d", 4.5); circle(c, 7, 21.5, 4, "m_teal", 3.5); R(c, 3, 26, 12, 27, "m_brass_d")
    R(c, 7, 9, 8, 17, "m_brass"); R(c, 7, 9, 7, 17, "m_brass_l"); R(c, 5, 8, 10, 9, "m_brass_d"); R(c, 6, 6, 9, 7, "m_lacq")
    for t in range(6):
        c.put(10 + t * 0.6, 18 + t, "m_silk_d")
    for k in range(3):
        y = 4 - k * 2 - (f % 2)
        if y >= 0:
            c.put(8 + ((f + k) % 3) - 1, y, "white")
    c.put(5 + f, 1, "m_cloud")


@item("m_sitar", "西塔琴", C9, 1, 14, 34, note="斜靠著的長頸弦琴", **M)
def _(c, f):
    for y in range(2, 22):
        x = 5 + (y - 2) * 0.12
        R(c, x, y, x + 1, y, "wood_d")
    for y in range(4, 20, 3):
        c.put(7, y, "m_brass_l")
    circle(c, 7.5, 27, 5, "wood_l", 5); circle(c, 8, 27.5, 4, "wood", 4); circle(c, 8, 26, 1.5, "black")
    circle(c, 5, 5, 2, "wood", 1.6)
    for y in range(3, 27, 2):
        c.put(6 + (y - 2) * 0.1, y, "paper_d")
    R(c, 3, 32, 12, 33, "wood_x")


@item("m_brass_telescope", "黃銅望遠鏡", C9, 1, 24, 32, note="三腳架上的黃銅望遠鏡，指向窗外", **M)
def _(c, f):
    for x0, x1 in ((11, 5), (12, 12), (13, 19)):
        for t in range(13):
            c.put(x0 + (x1 - x0) * t / 12, 18 + t, "wood_d")
    for t in range(18):
        x = 3 + t
        y = 16 - t * 0.6
        R(c, x, y - (1 if t > 8 else 0), x, y + 1 + (1 if t < 6 else 0), "m_brass" if t % 6 else "m_brass_d")
    c.put(3, 16, "m_brass_l"); c.put(20, 6, "glass"); R(c, 11, 11, 13, 12, "m_brass_d")


@item("m_magic_aquarium", "魔法水族箱", C9, 2, 32, 28, 3, 3, note="游著發光小魚和小海馬的水族箱", **M)
def _(c, f):
    R(c, 3, 19, 28, 27, "dark"); R(c, 3, 19, 28, 19, "dark_l"); R(c, 28, 20, 28, 27, "dark_d")
    R(c, 2, 2, 29, 18, "m_brass_d"); R(c, 3, 3, 28, 17, "m_pond"); R(c, 3, 3, 28, 5, "m_pond_l")
    for x in range(4, 28, 3):
        R(c, x, 15, x + 1, 17, "m_sand")
    R(c, 7, 9, 7, 16, "green"); R(c, 22, 8, 22, 16, "green_d"); c.put(6, 11, "green"); c.put(23, 10, "green")
    for k, (x, y, col) in enumerate(((10, 8, "m_koi"), (17, 12, "m_star"), (24, 6, "m_silk_l"))):
        xx = 4 + (x - 4 + f * (3 if k % 2 else -3)) % 23
        c.put(xx, y, col); c.put(xx + 1, y, col); c.put(xx + (2 if k % 2 == 0 else -1), y, col)
    c.put(14, 4 + f, "white"); c.put(15, 2 + f, "white")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_samovar", "茶炊", C10, 1, 18, 30, 2, 2, note="北方來的大茶炊，一直有熱茶喝", **M)
def _(c, f):
    R(c, 4, 26, 13, 29, "m_brass_d"); R(c, 6, 24, 11, 25, "m_brass")
    for y in range(9, 24):
        half = int(5 - abs(y - 16) * 0.25)
        R(c, 8.5 - half, y, 8.5 + half, y, "m_brass" if y % 4 else "m_brass_l")
    R(c, 2, 13, 3, 14, "black"); R(c, 14, 13, 15, 14, "black")
    R(c, 13, 19, 16, 20, "m_brass_d"); c.put(16, 21, "m_brass_d")
    R(c, 6, 6, 11, 8, "m_brass_d"); circle(c, 8.5, 4, 2.5, "m_porc"); c.put(8, 3, "m_porc_b")
    c.put(8 + f, 0, "white"); c.put(9 - f, 1, "m_cloud")


@item("m_spice_rack", "香料罐架", C10, 1, 22, 24, note="一排排五顏六色的香料罐", **M)
def _(c, f):
    box(c, 1, 2, 20, 22, "wood", "wood_l", "wood_d")
    cols = ["orange", "m_lacq", "yellow", "green", "m_sand_d", "brown", "m_silk_d", "f2"]
    for r, y in enumerate((4, 12)):
        R(c, 3, y + 6, 18, y + 6, "wood_x")
        for k, x in enumerate(range(3, 18, 4)):
            R(c, x, y, x + 2, y + 5, "glass"); R(c, x, y + 2, x + 2, y + 5, cols[(k + r * 4) % 8]); R(c, x, y - 1, x + 2, y - 1, "m_brass")
    R(c, 0, 23, 21, 23, "wood_x")


@item("m_tea_cart", "茶點推車", C10, 2, 32, 26, note="放滿異國點心的推車", **M)
def _(c, f):
    R(c, 3, 8, 28, 10, "m_brass"); R(c, 3, 8, 28, 8, "m_brass_l"); R(c, 3, 17, 28, 18, "m_brass"); R(c, 4, 11, 4, 19, "m_brass_d"); R(c, 27, 11, 27, 19, "m_brass_d")
    R(c, 28, 4, 30, 9, "m_brass_d")
    circle(c, 7, 23, 2.5, "black"); circle(c, 24, 23, 2.5, "black"); c.put(7, 23, "m_brass"); c.put(24, 23, "m_brass")
    circle(c, 9, 6, 3, "m_porc", 2); c.put(9, 3, "m_porc_b")
    for x, k in ((15, "pink"), (18, "yellow"), (21, "green_l"), (24, "m_silk_l")):
        circle(c, x, 6, 1.4, k)
    R(c, 7, 14, 12, 16, "m_porc"); R(c, 16, 13, 24, 16, "m_lacq"); c.put(18, 12, "gold"); c.put(22, 12, "gold")


@item("m_wine_amphora", "雙耳酒甕", C10, 1, 16, 26, note="南方海島運來的陶酒甕", **M)
def _(c, f):
    for y in range(3, 24):
        half = int(5.5 - abs(y - 13) * 0.32) if y > 6 else 2
        R(c, 7.5 - half, y, 7.5 + half, y, "pot" if y % 5 else "pot_d")
    R(c, 5, 1, 10, 2, "pot_d"); R(c, 2, 5, 3, 10, "pot_d"); R(c, 12, 5, 13, 10, "pot_d")
    R(c, 4, 13, 11, 13, "black"); c.put(6, 12, "black"); c.put(9, 12, "black")
    R(c, 5, 24, 10, 25, "pot_d")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_bird_screen", "花鳥屏風", C11, 2, 38, 32, note="四扇的花鳥屏風，可以隔出一個小角落", **M)
def _(c, f):
    for k in range(4):
        x0 = 1 + k * 9
        R(c, x0, 2, x0 + 8, 29, "m_lacq_d"); R(c, x0 + 1, 3, x0 + 7, 27, "paper")
        R(c, x0, 30, x0 + 1, 31, "m_lacq_d"); R(c, x0 + 7, 30, x0 + 8, 31, "m_lacq_d")
    for x in range(3, 34):
        y = 20 - int(math.sin(x / 6) * 4)
        c.put(x, y, "wood_d")
    for x, y in ((6, 15), (12, 12), (20, 19), (28, 14), (33, 17)):
        c.put(x, y, "m_silk"); c.put(x + 1, y, "m_silk_l"); c.put(x, y - 1, "m_silk_l")
    R(c, 21, 7, 24, 8, "m_teal"); c.put(25, 7, "orange"); c.put(20, 8, "m_teal_d")       # the bird


@item("m_moon_gate", "月洞門", C11, 4, 44, 46, note="中間是一個大圓洞的白牆門", **M)
def _(c, f):
    R(c, 1, 4, 42, 44, "marble"); R(c, 1, 4, 42, 5, "marble_x"); R(c, 0, 1, 43, 3, "m_porc_b"); R(c, 0, 1, 43, 1, "blue_l")
    for y in range(8, 45):
        dy = (y - 24) / 17
        if abs(dy) <= 1:
            half = int(15 * math.sqrt(1 - dy * dy))
            for x in range(int(21.5 - half), int(22.5 + half) + 1):
                c.px[y][x] = None
            c.put(21.5 - half - 1, y, "marble_d"); c.put(22.5 + half + 1, y, "marble_d")
    R(c, 0, 44, 43, 45, "stone_d")


@item("m_bead_curtain", "珠簾", C11, 1, 20, 32, 2, 2, note="一串串彩珠垂成的門簾，走過會晃", **M)
def _(c, f):
    R(c, 1, 1, 18, 2, "wood_d")
    cols = ["m_lacq", "gold", "m_teal", "m_silk"]
    for k, x in enumerate(range(3, 18, 3)):
        sway = (1 if (k + f) % 2 else 0) if f else 0
        for y in range(3, 30):
            xx = x + (sway if y > 15 else 0)
            c.put(xx, y, cols[(k + y // 3) % 4] if y % 3 == 0 else "gold_d")


@item("m_lattice_window", "雕花窗", C11, 2, 30, 26, wall=True, note="木格子雕成雲紋的圓窗", **M)
def _(c, f):
    circle(c, 14.5, 13, 12, "m_lacq_d", 11.5); circle(c, 14.5, 13, 10, "sky", 9.5)
    for x in range(5, 25, 4):
        R(c, x, 3, x, 23, "m_lacq")
    for y in range(4, 24, 4):
        R(c, 3, y, 26, y, "m_lacq")
    for y in range(2, 25):
        for x in range(1, 29):
            if ((x - 14.5) / 12.3) ** 2 + ((y - 13) / 11.8) ** 2 > 1:
                c.px[y][x] = None
    for a in range(0, 360, 6):
        r = math.radians(a)
        c.put(14.5 + math.cos(r) * 12, 13 + math.sin(r) * 11.5, "m_lacq_d")


@item("m_stained_arch", "彩玻拱窗", C11, 2, 26, 32, 2, 2, wall=True, note="陽光照進來會變色的彩繪玻璃窗", **M)
def _(c, f):
    R(c, 2, 12, 23, 30, "stone_d"); circle(c, 12.5, 12, 10.5, "stone_d", 10)
    R(c, 4, 12, 21, 28, "blue"); circle(c, 12.5, 12, 8.5, "blue", 8)
    pal = [("m_lacq_l", "yellow", "m_teal_l"), ("yellow", "m_teal_l", "m_lacq_l")][f]
    for k, (x0, y0, x1, y1) in enumerate(((5, 14, 11, 20), (14, 14, 20, 20), (5, 22, 11, 27), (14, 22, 20, 27), (9, 5, 16, 11))):
        R(c, x0, y0, x1, y1, pal[k % 3])
    R(c, 12, 4, 13, 28, "black"); R(c, 4, 21, 21, 21, "black"); R(c, 4, 13, 21, 13, "black")
    R(c, 1, 30, 24, 31, "stone")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_stone_lantern", "石燈籠", C12, 1, 18, 30, 2, 2, note="庭院裡的石燈籠，晚上會點燈", **M)
def _(c, f):
    R(c, 3, 27, 14, 29, "stone_d"); R(c, 7, 19, 10, 26, "stone"); R(c, 7, 19, 7, 26, "stone_l")
    R(c, 3, 16, 14, 18, "stone"); R(c, 3, 16, 14, 16, "stone_l")
    R(c, 4, 9, 13, 15, "stone"); R(c, 6, 10, 11, 14, "black"); flame(c, 8, 14, 4, f, 1)
    for i in range(5):
        R(c, 1 + i, 8 - i, 16 - i, 8 - i, "stone_d" if i == 0 else "stone")
    R(c, 8, 1, 9, 3, "stone_l")


@item("m_koi_pond", "錦鯉池", C12, 4, 48, 30, 3, 3, flat=True, note="石頭圍起來的小池，錦鯉繞著游", **M)
def _(c, f):
    circle(c, 23.5, 15, 22, "stone", 13.5); circle(c, 23.5, 15, 19.5, "m_pond_d", 11.5); circle(c, 23.5, 14.5, 18, "m_pond", 10.5)
    for a in range(0, 360, 30):
        r = math.radians(a)
        circle(c, 23.5 + math.cos(r) * 21, 15 + math.sin(r) * 12.8, 1.5, "stone_l" if a % 60 else "stone_d")
    circle(c, 11, 10, 3, "green", 1.6); circle(c, 33, 19, 3.5, "green_d", 1.8)
    for k in range(3):
        a = math.radians(f * 40 + k * 120)
        x, y = 23.5 + math.cos(a) * 11, 15 + math.sin(a) * 6
        col = ["m_koi", "white", "gold"][k]
        R(c, x - 1, y, x + 1, y, col); c.put(x + (2 if math.sin(a) < 0 else -2), y, "m_koi")
    c.put(28, 9, "m_pond_l"); c.put(16, 20, "m_pond_l")


@item("m_torii", "小鳥居", C12, 4, 48, 44, note="遠東神社的朱紅鳥居", **M)
def _(c, f):
    for x in (9, 36):
        R(c, x, 8, x + 3, 42, "m_lacq"); R(c, x, 8, x, 42, "m_lacq_l"); R(c, x - 1, 40, x + 4, 43, "black")
    R(c, 1, 3, 46, 6, "m_lacq"); R(c, 0, 1, 47, 3, "black"); R(c, 3, 13, 44, 15, "m_lacq"); R(c, 3, 13, 44, 13, "m_lacq_l")
    R(c, 21, 6, 26, 13, "m_lacq_d"); R(c, 22, 8, 25, 11, "gold")
    c.put(0, 0, "black"); c.put(47, 0, "black")


@item("m_caravan_tent", "商隊帳篷", C12, 4, 50, 42, 2, 2, note="沙漠商隊的條紋大帳篷", **M)
def _(c, f):
    for y in range(4, 34):
        half = int((y - 4) * 0.82)
        for x in range(int(24.5 - half), int(25.5 + half) + 1):
            c.put(x, y, "m_lacq" if ((x - 25) // 4) % 2 else "m_sand")
    R(c, 3, 34, 46, 40, "m_sand_d"); R(c, 3, 34, 46, 34, "m_sand")
    for x in range(3, 47, 4):
        R(c, x, 34, x + 1, 40, "m_lacq_d")
    for y in range(26, 41):
        half = int((y - 26) * 0.45) + 1
        R(c, 25 - half, y, 25 + half, y, "black")
    R(c, 24, 0, 25, 4, "wood_d"); R(c, 26, 0, 30, 2 + f, "m_teal")
    R(c, 0, 41, 49, 41, "m_sand_d")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("m_phoenix", "鳳凰棲木", C13, 2, 24, 38, 3, 3, note="站在棲木上的小鳳凰，尾羽像火焰一樣搖", **M)
def _(c, f):
    R(c, 11, 18, 12, 35, "m_brass_d"); R(c, 5, 35, 18, 37, "m_brass"); R(c, 4, 17, 19, 18, "m_brass")
    circle(c, 11.5, 11, 4.5, "m_phx", 5); circle(c, 11, 10.5, 3.5, "m_phx_l", 4)
    circle(c, 14, 5, 2.5, "m_phx"); c.put(15, 4, "black"); R(c, 16, 5, 17, 5, "gold"); c.put(13, 2, "m_phx_l"); c.put(15, 1, "m_phx_l")
    for k in range(4):
        sway = [0, 1, 0][f] * (k % 2 * 2 - 1)
        for t in range(8 + k):
            c.put(9 - k - t * 0.5 + sway * (t > 3), 14 + t, ["m_phx_d", "m_phx", "f2", "f1"][(t + k + f) % 4])
    R(c, 8, 9 - f, 10, 13 - f, "m_phx_d")


@item("m_jade_dragonling", "小翠龍", C13, 1, 22, 18, 3, 3, note="翡翠色的小龍，會拍翅膀跳一跳", **M)
def _(c, f):
    hop = [0, 2, 0][f]
    circle(c, 10, 12 - hop, 4.5, "m_jade", 3.5); circle(c, 10, 12.5 - hop, 3, "m_jade_l", 2)
    circle(c, 15.5, 8 - hop, 2.8, "m_jade"); c.put(16, 7 - hop, "black"); c.put(18, 9 - hop, "m_jade_d"); c.put(15, 5 - hop, "m_jade_l")
    wing = [5, 3, 5][f]
    R(c, 8, wing - hop, 11, 9 - hop, "m_jade_d"); c.put(7, wing + 1 - hop, "m_jade_d")
    for t in range(6):
        c.put(5 - t * 0.7, 13 - hop + (t // 2), "m_jade_d")
    R(c, 8, 16 - hop, 8, 17 - hop if hop else 17, "m_jade_d"); R(c, 12, 16 - hop, 12, 17, "m_jade_d")


@item("m_lucky_cat", "招財貓", C13, 1, 14, 18, 2, 2, note="一直招手的招財貓", **M)
def _(c, f):
    box(c, 3, 9, 11, 16, "white", None, "m_porc_d"); R(c, 2, 17, 12, 17, "m_lacq")
    circle(c, 7, 6, 4, "white", 3.5); c.put(4, 2, "white"); c.put(10, 2, "white"); c.put(4, 3, "m_silk_l"); c.put(10, 3, "m_silk_l")
    c.put(5, 6, "black"); c.put(9, 6, "black"); c.put(7, 7, "m_silk"); R(c, 5, 10, 9, 10, "m_lacq"); c.put(7, 11, "gold")
    if f:
        R(c, 11, 3, 12, 7, "white"); c.put(12, 2, "white")
    else:
        R(c, 11, 5, 12, 9, "white"); c.put(12, 4, "white")


@item("m_fennec", "沙漠小狐", C13, 1, 20, 16, 3, 3, note="大耳朵的沙漠小狐，尾巴甩來甩去", **M)
def _(c, f):
    circle(c, 10, 11, 4.5, "m_sand", 3); circle(c, 10, 12, 3, "m_sand_l", 1.8)
    circle(c, 14.5, 7, 2.8, "m_sand"); c.put(15, 6, "black"); c.put(17, 8, "black")
    R(c, 12, 1, 13, 5, "m_sand"); R(c, 16, 1, 17, 5, "m_sand"); c.put(12, 3, "m_silk_l"); c.put(17, 3, "m_silk_l")
    tail = [0, -1, 1][f]
    for t in range(5):
        c.put(5 - t, 10 + tail * (t // 2) - t // 3, "m_sand_d" if t < 4 else "white")
    R(c, 8, 14, 8, 15, "m_sand_d"); R(c, 12, 14, 12, 15, "m_sand_d")


# ── the merchant himself ──────────────────────────────────────────────────────────────────────────────────────────────────
MERCHANT_W, MERCHANT_H, MERCHANT_FRAMES, MERCHANT_FPS = 44, 42, 4, 3
GROOT = os.path.join(gd.REPO, "mac", "Resources", "Guild")


def draw_merchant(c, f):
    """A hooded travelling trader beside his little cart: the lantern sways, he nods, a coin glints on the counter."""
    # the cart: an awning, a counter of wares, two wheels
    for x in range(20, 43):
        R(c, x, 4, x, 7, "m_lacq" if (x // 3) % 2 else "m_sand_l")
        c.put(x, 8 if (x // 3) % 2 else 7, "m_lacq_d")
    R(c, 21, 8, 21, 26, "wood_d"); R(c, 41, 8, 41, 26, "wood_d")
    box(c, 20, 22, 42, 33, "wood", "wood_l", "wood_d")
    R(c, 22, 18, 25, 21, "m_jade"); circle(c, 29, 19, 2.5, "m_porc"); c.put(29, 18, "m_porc_b"); R(c, 33, 16, 35, 21, "glass"); c.put(34, 17, "glow")
    R(c, 37, 19, 40, 21, "m_lacq"); c.put(38, 18, "gold")
    if f == 2:
        c.put(31, 21, "gold_l")
    circle(c, 25, 37, 4, "wood_d"); circle(c, 25, 37, 2, "wood"); circle(c, 38, 37, 4, "wood_d"); circle(c, 38, 37, 2, "wood")
    sway = [0, 1, 0, -1][f]
    R(c, 31, 8, 31, 10, "m_brass_d"); R(c, 30 + sway, 11, 32 + sway, 14, "m_brass"); c.put(31 + sway, 12, "f1"); c.put(31 + sway, 13, "f2")
    # the trader: a deep purple hood, a scarf, a pack on his back
    nod = 1 if f in (1, 2) else 0
    R(c, 6, 40, 9, 41, "black"); R(c, 12, 40, 15, 41, "black")
    for y in range(18, 40):
        half = int(4 + (y - 18) * 0.22)
        R(c, 10.5 - half, y, 10.5 + half, y, "purple_d" if y % 7 else "purple")
    R(c, 6, 26, 15, 27, "m_brass"); c.put(10, 27, "gold_l")
    R(c, 1, 20, 4, 32, "leather"); R(c, 1, 20, 4, 20, "leather_l"); R(c, 2, 23, 3, 23, "leather_d")
    circle(c, 10.5, 12 + nod, 6, "purple", 6.5); circle(c, 11, 13 + nod, 4, "black", 4)
    c.put(9, 13 + nod, "f1"); c.put(12, 13 + nod, "f1")
    R(c, 6, 17 + nod, 15, 18 + nod, "m_teal"); R(c, 13, 19, 14, 22, "m_teal")
    R(c, 15, 24, 18, 25, "purple"); circle(c, 19, 24.5, 1.5, "skin")


def write_merchant():
    """Draws merchant.png (one strip of frames) and puts its entry in the hall's manifest (the other keys stay as they are)."""
    frames = []
    for f in range(MERCHANT_FRAMES):
        c = gd.Canvas(MERCHANT_W, MERCHANT_H)
        draw_merchant(c, f)
        c.outline()
        frames.append(c)
    from PIL import Image
    strip = Image.new("RGBA", (MERCHANT_W * MERCHANT_FRAMES, MERCHANT_H), (0, 0, 0, 0))
    for i, c in enumerate(frames):
        for y in range(MERCHANT_H):
            for x in range(MERCHANT_W):
                k = c.px[y][x]
                if k is not None:
                    strip.putpixel((i * MERCHANT_W + x, y), tuple(gd.P[k]) + (255,))
    strip.save(os.path.join(GROOT, "merchant.png"), optimize=True)
    mpath = os.path.join(GROOT, "manifest.json")
    man = json.load(open(mpath, encoding="utf-8"))
    man["merchant"] = {"file": "merchant.png", "w": MERCHANT_W, "h": MERCHANT_H, "frames": MERCHANT_FRAMES, "fps": MERCHANT_FPS,
                       "anchorX": MERCHANT_W // 2, "anchorY": MERCHANT_H - 1}
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(man, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    return strip
