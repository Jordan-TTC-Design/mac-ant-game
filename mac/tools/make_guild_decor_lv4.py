"""Guild level 4 unlocks: the courtyard (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 4
add_colors({"sakura": (250, 196, 214), "sakura_d": (226, 140, 172), "sakura_l": (255, 228, 236), "pine": (40, 110, 70), "pine_d": (26, 78, 52), "pine_l": (70, 150, 90),
            "lavender": (160, 120, 210), "lavender_d": (116, 80, 170), "pumpkin": (240, 140, 40), "pumpkin_d": (196, 100, 30), "wicker": (200, 160, 96), "wicker_d": (150, 112, 62),
            "hay": (230, 200, 110), "koi": (244, 120, 60), "pond": (80, 150, 190), "pond_d": (56, 112, 156), "pond_l": (140, 200, 224), "shed": (150, 100, 70), "shed_d": (110, 70, 50)})


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_garden_table", "庭院圓桌", C1, 2, 30, 24, level=LV)
def _(c, f):
    circle(c, 14.5, 8, 13, "iron_d", 5); circle(c, 14.5, 7, 12, "iron_l", 4.4); circle(c, 14.5, 7, 9, "iron", 3.2)
    for x in range(8, 22, 3):
        c.put(x, 7, "iron_l")
    R(c, 13, 12, 16, 21, "iron_d"); R(c, 13, 12, 13, 21, "iron"); R(c, 8, 22, 21, 22, "iron_d"); R(c, 6, 23, 23, 23, "iron_d")
    R(c, 11, 3, 14, 6, "cloth"); R(c, 17, 4, 19, 6, "teal")


@item("l4_garden_chair", "庭院鐵椅", C1, 1, 18, 26, level=LV, seat=True)
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    R(c, 3, 2, 14, 12, "iron_d")
    for x in range(4, 14, 2):
        R(c, x, 3, x, 11, "iron_l")
    R(c, 3, 2, 14, 2, "iron"); R(c, 3, sy, 14, sy + 1, "iron_l"); R(c, 3, sy, 14, sy, "iron")
    for x in (4, 8, 12):
        c.put(x, sy + 1, "iron_d")
    legs(c, (4, 13), sy + 2, h - 2, "iron_d"); R(c, 3, h - 1, 5, h - 1, "iron_d"); R(c, 12, h - 1, 14, h - 1, "iron_d"); R(c, 3, 12, 3, sy, "iron_d"); R(c, 14, 12, 14, sy, "iron_d")


@item("l4_wicker_chair", "藤編椅", C1, 2, 26, 28, level=LV, seat=True)
def _(c, f):
    h = 28
    sy = h - 1 - SEAT_UP
    circle(c, 12.5, 11, 10, "wicker_d", 11); circle(c, 12.5, 11, 8.6, "wicker", 9.6)
    for y in range(4, 18, 2):
        R(c, 5, y, 20, y, "wicker_d")
    R(c, 3, sy - 3, 22, sy, "red_l" if False else "lred" if False else "velvet_l"); R(c, 3, sy - 3, 22, sy - 3, "pink")
    R(c, 2, sy + 1, 23, sy + 1, "wicker"); R(c, 3, sy + 2, 22, h - 3, "wicker_d")
    for x in range(4, 22, 3):
        R(c, x, sy + 2, x, h - 3, "wicker")
    R(c, 3, h - 2, 5, h - 1, "wicker_d"); R(c, 20, h - 2, 22, h - 1, "wicker_d")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_garden_shed", "園藝工具小屋", C2, 4, 40, 42, level=LV, note="可以收一堆園藝工具的小木屋")
def _(c, f):
    R(c, 3, 14, 36, 40, "shed"); R(c, 36, 15, 36, 40, "shed_d")
    for x in range(5, 36, 4):
        R(c, x, 15, x, 39, "shed_d")
    for r in range(11):
        R(c, 19 - 3 - r * 2 + 3, 3 + r, 20 + 3 + r * 2 - 3, 3 + r, "red_d" if r % 2 else "lred_d" if False else "red") if False else R(c, 19 - r * 2 // 1 - 1 if r < 8 else 2, 3 + r, 20 + r * 2 + 0 if r < 8 else 37, 3 + r, "red_d" if r % 2 else "red")
    R(c, 14, 24, 25, 40, "shed_d"); R(c, 15, 25, 24, 39, "wood"); circle(c, 23, 32, 1, "gold")
    R(c, 6, 20, 11, 25, "glass_d"); R(c, 7, 21, 10, 24, "glass"); R(c, 28, 20, 33, 25, "glass_d"); R(c, 29, 21, 32, 24, "glass")
    R(c, 1, 39, 38, 41, "stone_d")


@item("l4_seed_cabinet", "種子櫃", C2, 2, 26, 30, level=LV)
def _(c, f):
    box(c, 1, 1, 24, 28, "wood", "wood_l", "wood_d")
    for r in range(4):
        for col in range(3):
            x, y = 3 + col * 7, 3 + r * 6
            R(c, x, y, x + 5, y + 4, "wood_x"); R(c, x, y, x + 5, y, "wood_l")
            R(c, x + 1, y + 1, x + 4, y + 3, ["green_l", "red_l", "f1", "pink", "lavender", "green"][(r + col * 2) % 6])
    R(c, 0, 29, 25, 29, "wood_x")


@item("l4_wheelbarrow", "獨輪手推車", C2, 2, 32, 22, level=LV)
def _(c, f):
    for r in range(7):
        R(c, 6 + r // 3, 5 + r, 22 - r // 3, 5 + r, "iron_d" if r == 0 else "iron")
    R(c, 7, 5, 21, 6, "dirt"); R(c, 8, 4, 20, 4, "brown"); blob(c, 12, 4, 3, "green", "green_d", "green_l"); blob(c, 17, 5, 2.4, "green", "green_d", "green_l")
    R(c, 21, 10, 29, 11, "wood_d"); R(c, 20, 11, 29, 11, "wood"); circle(c, 6, 15, 4, "iron_d", 4); circle(c, 6, 15, 2.8, "wood", 2.8); c.put(6, 15, "iron_l")
    R(c, 15, 12, 16, 19, "wood_d"); R(c, 22, 12, 23, 19, "wood_d")


@item("l4_firewood", "柴堆", C2, 2, 28, 24, level=LV)
def _(c, f):
    for row, (y, n) in enumerate(((17, 6), (11, 5), (5, 4))):
        for i in range(n):
            x = 3 + i * 4 + (2 if row % 2 else 0)
            R(c, x, y, x + 3, y + 5, "wood_d"); circle(c, x + 1.5, y + 2.5, 2.4, "wood_l", 2.4); circle(c, x + 1.5, y + 2.5, 1, "wood", 1)
    R(c, 1, 22, 26, 23, "wood_x")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_watering_can", "澆水壺", C3, 1, 20, 16, level=LV)
def _(c, f):
    R(c, 3, 5, 11, 13, "steel"); R(c, 3, 5, 11, 5, "steel_l"); R(c, 11, 6, 11, 13, "steel_d"); R(c, 3, 14, 11, 14, "steel_d")
    R(c, 12, 9, 17, 10, "steel"); R(c, 16, 6, 18, 9, "steel_d"); R(c, 17, 6, 18, 6, "steel_l"); c.cells([(19, 6), (19, 8)], "water_l")
    R(c, 3, 2, 10, 3, "steel_d"); R(c, 3, 3, 4, 5, "steel_d"); R(c, 9, 3, 10, 5, "steel_d")


@item("l4_trowel", "園藝鏟", C3, 1, 14, 14, level=LV)
def _(c, f):
    for i in range(7):
        R(c, 2 + i, 10 - i, 3 + i, 10 - i, "steel_d")
    R(c, 1, 9, 5, 12, "steel"); R(c, 1, 9, 3, 9, "steel_l"); R(c, 9, 2, 11, 4, "wood"); R(c, 10, 1, 12, 2, "wood_d"); R(c, 6, 5, 8, 7, "steel_d")


@item("l4_birdhouse", "小鳥屋", C3, 1, 16, 20, level=LV)
def _(c, f):
    R(c, 3, 8, 12, 17, "wood"); R(c, 12, 9, 12, 17, "wood_d"); circle(c, 7.5, 12, 1.8, "black")
    for r in range(6):
        R(c, 1 + r, 3 + r, 14 - r, 3 + r, "red_d" if r % 2 else "red") if False else R(c, 7 - r // 1 - 1 if r < 5 else 1, 2 + r, 8 + r if r < 5 else 14, 2 + r, "red" if r % 2 else "red_d")
    R(c, 6, 18, 9, 18, "wood_d"); R(c, 4, 17, 11, 17, "wood_l")
    R(c, 6, 14, 9, 14, "wood_d"); c.put(13, 8, "f1")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_ornate_lamp_post", "花園路燈", C4, 2, 18, 48, 2, 2, level=LV)
def _(c, f):
    R(c, 8, 12, 9, 42, "iron_d"); R(c, 8, 12, 8, 42, "iron"); R(c, 5, 42, 12, 44, "iron_d"); R(c, 4, 44, 13, 46, "iron_d"); R(c, 4, 44, 13, 44, "iron")
    for dx in (-3, 3):
        R(c, 8 + dx, 18, 8 + dx, 22, "iron_d"); R(c, 8 + dx // 3 * 1, 16, 8 + dx, 16, "iron_d")
    R(c, 5, 5, 12, 12, "glass"); R(c, 5, 5, 12, 5, "iron"); R(c, 6, 6, 11, 11, "f1" if f else "f2"); R(c, 7, 7, 10, 10, "f4")
    R(c, 7, 1, 10, 4, "iron"); c.cells([(8, 0), (9, 0)], "iron_l"); R(c, 4, 12, 13, 13, "iron")


@item("l4_ground_lantern", "地燈", C4, 1, 14, 18, 2, 2, level=LV)
def _(c, f):
    R(c, 3, 3, 10, 14, "stone"); R(c, 3, 3, 10, 3, "stone_l"); R(c, 10, 4, 10, 14, "stone_d")
    R(c, 4, 6, 9, 11, "black"); R(c, 5, 7, 8, 10, "f1" if f else "f2"); R(c, 6, 8, 7, 9, "f4")
    R(c, 2, 1, 11, 2, "stone_d"); R(c, 2, 15, 11, 16, "stone_d")


@item("l4_stone_lantern", "石燈籠", C4, 1, 16, 26, 2, 2, level=LV)
def _(c, f):
    R(c, 4, 22, 11, 24, "stone_d"); R(c, 6, 15, 9, 21, "stone"); R(c, 3, 11, 12, 14, "stone"); R(c, 3, 11, 12, 11, "stone_l")
    R(c, 4, 7, 11, 10, "stone_d"); R(c, 5, 8, 10, 9, "f1" if f else "f2")
    for r in range(5):
        R(c, 1 + r, 2 + r, 14 - r, 2 + r, "stone_l" if r == 0 else "stone")
    R(c, 7, 0, 8, 1, "stone_d")


@item("l4_torch_post", "火把柱", C4, 1, 14, 38, 3, 6, level=LV)
def _(c, f):
    R(c, 6, 14, 8, 34, "wood"); R(c, 6, 14, 6, 34, "wood_l"); R(c, 8, 15, 8, 34, "wood_d")
    R(c, 3, 33, 11, 36, "stone_d"); R(c, 3, 33, 11, 33, "stone")
    R(c, 4, 10, 10, 13, "iron"); R(c, 5, 8, 9, 9, "iron_d")
    flame(c, 7, 7, 6 + f % 2, f, 2)


@item("l4_jar_lights", "螢火蟲燈串", C4, 2, 38, 22, 3, 3, level=LV, ceiling=True, note="一串掛起來的玻璃罐，裡面有螢火蟲")
def _(c, f):
    R(c, 0, 1, 37, 1, "rope")
    for n, x in enumerate((4, 13, 22, 31)):
        R(c, x + 2, 2, x + 2, 5, "rope"); R(c, x, 6, x + 4, 7, "wood"); R(c, x, 8, x + 4, 16, "glass_d"); R(c, x + 1, 9, x + 3, 15, "glass"); R(c, x, 17, x + 4, 17, "glass_d")
        for k, (dx, dy) in enumerate(((1, 11), (3, 13), (2, 9))):
            if (k + f + n) % 3 != 0:
                c.put(x + dx, dy, "f1"); c.put(x + dx, dy - 1, "f4")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_wall_trellis", "牆上花格架", C5, 2, 30, 32, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 28, 30, "wood_d")
    for x in range(3, 28, 5):
        R(c, x, 2, x, 29, "wood")
    for y in range(4, 29, 5):
        R(c, 2, y, 27, y, "wood")
    for n, (x, y) in enumerate(((6, 7), (13, 4), (21, 9), (9, 15), (17, 18), (24, 14), (6, 24), (14, 26), (22, 25))):
        circle(c, x, y, 2.2, "green" if n % 2 else "green_d"); c.put(x, y, ["pink", "f1", "sakura", "red_l"][n % 4])


@item("l4_hanging_basket", "吊籃花", C5, 1, 22, 24, level=LV, wall=True)
def _(c, f):
    R(c, 10, 0, 11, 5, "iron_d"); R(c, 5, 5, 16, 6, "iron"); R(c, 6, 7, 15, 13, "wicker"); R(c, 6, 7, 15, 7, "wicker_d")
    for x in range(7, 15, 2):
        R(c, x, 8, x, 13, "wicker_d")
    for x, k in ((5, "pink"), (9, "f1"), (13, "red_l"), (16, "lavender")):
        circle(c, x, 5, 2, k); R(c, x - 1, 6, x + 1, 7, "green")
    R(c, 3, 8, 5, 14, "green"); R(c, 16, 8, 18, 15, "green"); R(c, 9, 14, 12, 18, "green_d")


@item("l4_wall_sundial", "牆上日晷", C5, 1, 22, 22, level=LV, wall=True)
def _(c, f):
    circle(c, 10.5, 10.5, 10, "stone_d"); circle(c, 10.5, 10.5, 9, "stone_l")
    for i in range(9):
        a = math.pi + i * math.pi / 8
        c.put(round(10 + math.cos(a) * 7), round(11 + math.sin(a) * -7 + 5), "ink")
    R(c, 10, 6, 11, 14, "gold_d"); c.cells([(11, 7), (12, 8), (12, 9)], "gold"); R(c, 6, 15, 15, 16, "stone_d")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_grass_mat", "草地墊", C6, 4, 46, 30, level=LV, flat=True)
def _(c, f):
    R(c, 1, 1, 44, 28, "grass_d"); R(c, 2, 2, 43, 27, "grass")
    import random
    rng = random.Random(7)
    for _ in range(60):
        x, y = rng.randrange(3, 42), rng.randrange(3, 26)
        c.put(x, y, "green_l"); c.put(x, y + 1, "grass_d")
    for x, y, k in ((8, 8, "pink"), (30, 18, "f1"), (38, 7, "white"), (14, 22, "pink")):
        c.put(x, y, k)
    for x in range(2, 44, 2):
        c.put(x, 0, "grass_d"); c.put(x, 29, "grass_d")


@item("l4_flower_carpet", "花毯", C6, 2, 36, 28, level=LV, flat=True)
def _(c, f):
    rug_base(c, 36, 28, "cloth", "green_d", "green", True)
    for cx, cy, k in ((10, 9, "red_l"), (18, 14, "f1"), (26, 9, "pink"), (12, 19, "lavender"), (25, 19, "red_l")):
        c.cells([(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)], k); c.put(cx, cy, "f1" if k != "f1" else "orange")


@item("l4_pebble_path", "卵石步道", C6, 2, 34, 18, level=LV, flat=True)
def _(c, f):
    import random
    rng = random.Random(3)
    R(c, 1, 3, 32, 14, "dirt")
    for x in range(2, 31, 4):
        for y in range(4, 13, 4):
            ox, oy = rng.randrange(-1, 2), rng.randrange(-1, 2)
            circle(c, x + 1 + ox, y + 1 + oy, 1.8, "stone_l" if (x + y) % 3 else "stone", 1.5)


@item("l4_lily_pond_mat", "睡蓮池墊", C6, 2, 34, 24, 2, 2, level=LV, flat=True)
def _(c, f):
    circle(c, 16.5, 11.5, 16, "stone_d", 11); circle(c, 16.5, 11.5, 14.6, "pond", 9.8); circle(c, 16.5, 11.5, 11, "pond_d", 7)
    for x, y in ((10, 9), (21, 13), (15, 15)):
        circle(c, x, y, 2.4, "green", 2); R(c, x, y, x + 1, y, "pond_d"); c.put(x + 1, y - 1, "pink" if f else "white")
    c.cells([(8, 13 + f), (23, 8 - f)], "pond_l")


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_oak_tree", "橡樹", C7, 4, 46, 56, level=LV)
def _(c, f):
    R(c, 20, 30, 26, 52, "wood_d"); R(c, 20, 30, 22, 52, "wood"); R(c, 16, 48, 20, 54, "wood_d"); R(c, 26, 48, 30, 54, "wood_d")
    blob(c, 23, 16, 20, "green", "green_d", "green_l", 15); blob(c, 10, 24, 9, "green", "green_d", "green_l", 7); blob(c, 36, 24, 9, "green", "green_d", "green_l", 7)
    for x, y in ((12, 10), (30, 8), (22, 4), (36, 16), (8, 20)):
        c.cells([(x, y), (x + 1, y + 1)], "green_l")
    for x, y in ((14, 18), (28, 20), (22, 24)):
        c.put(x, y, "red_l")


@item("l4_cherry_tree", "櫻花樹", C7, 4, 46, 54, level=LV)
def _(c, f):
    R(c, 21, 28, 25, 50, "wood_d"); R(c, 21, 28, 22, 50, "brown"); R(c, 18, 46, 21, 52, "wood_d"); R(c, 25, 46, 28, 52, "wood_d")
    blob(c, 23, 15, 20, "sakura", "sakura_d", "sakura_l", 14); blob(c, 9, 22, 8, "sakura", "sakura_d", "sakura_l", 6); blob(c, 37, 22, 8, "sakura", "sakura_d", "sakura_l", 6)
    for x, y in ((14, 8), (30, 6), (22, 3), (38, 16), (6, 18), (20, 22), (28, 20)):
        c.put(x, y, "white"); c.put(x + 1, y + 1, "sakura_l")
    for x, y in ((12, 44), (30, 46), (22, 50), (36, 42)):
        c.put(x, y, "sakura")


@item("l4_pine_tree", "松樹", C7, 2, 30, 52, level=LV)
def _(c, f):
    R(c, 13, 40, 16, 50, "wood_d"); R(c, 13, 40, 13, 50, "wood")
    for n, (y0, hw) in enumerate(((2, 5), (11, 8), (21, 11), (31, 13))):
        for r in range(11):
            half = max(1, (hw * (r + 2)) // 12)
            R(c, 14 - half, y0 + r, 15 + half, y0 + r, "pine" if (r + n) % 3 else "pine_l"); c.put(15 + half, y0 + r, "pine_d")
    R(c, 11, 49, 18, 51, "dirt")


@item("l4_round_hedge", "球形灌木", C7, 1, 20, 22, level=LV)
def _(c, f):
    blob(c, 9.5, 10, 8.4, "green", "green_d", "green_l", 8)
    for x, y in ((6, 6), (12, 8), (8, 13), (13, 12)):
        c.put(x, y, "green_l")
    R(c, 5, 18, 14, 19, "pot"); R(c, 6, 19, 13, 20, "pot_d")


@item("l4_flower_patch", "花圃", C7, 2, 36, 20, level=LV)
def _(c, f):
    R(c, 1, 11, 34, 17, "dirt"); R(c, 1, 11, 34, 11, "brown"); R(c, 1, 17, 34, 18, "wood_d")
    for n, x in enumerate(range(3, 33, 4)):
        h = 4 + (n * 3) % 5
        R(c, x, 11 - h, x, 11, "green_d"); circle(c, x, 10 - h, 1.8, ["red_l", "f1", "pink", "lavender", "white", "orange"][n % 6]); c.put(x, 10 - h, "f1")
        R(c, x + 1, 9, x + 2, 10, "green")


@item("l4_lavender", "薰衣草叢", C7, 1, 24, 26, level=LV)
def _(c, f):
    for n, x in enumerate(range(3, 22, 3)):
        h = 10 + (n * 5) % 7
        R(c, x, 22 - h, x, 22, "green_d")
        for y in range(22 - h, 22 - h + 6):
            c.put(x - (y % 2), y, "lavender"); c.put(x + 1, y, "lavender_d")
    R(c, 2, 22, 22, 24, "dirt"); R(c, 2, 24, 22, 24, "brown")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_stone_angel", "石天使像", C8, 2, 24, 42, level=LV)
def _(c, f):
    plinth(c, 4, 19, 33, 41)
    circle(c, 11.5, 9, 3.6, "marble"); R(c, 8, 13, 15, 29, "marble"); R(c, 15, 13, 15, 29, "marble_d")
    for r in range(10):
        R(c, 1 + r // 3, 10 + r, 7, 10 + r, "marble_d"); R(c, 16, 10 + r, 22 - r // 3, 10 + r, "marble_d")
    R(c, 6, 14, 8, 22, "marble"); R(c, 9, 29, 14, 32, "marble_d"); c.cells([(10, 8), (13, 8)], "marble_x"); R(c, 9, 4, 14, 4, "gold")


@item("l4_gnome", "園丁地精", C8, 1, 16, 24, level=LV)
def _(c, f):
    R(c, 3, 12, 12, 21, "blue"); R(c, 12, 13, 12, 21, "blue_d"); R(c, 4, 11, 11, 12, "red")
    circle(c, 7.5, 9, 3, "skin"); R(c, 4, 10, 11, 14, "white"); c.cells([(6, 8), (9, 8)], "black")
    for r in range(8):
        R(c, 7 - r // 3, 8 - r, 8 + r // 3, 8 - r, "red" if r < 7 else "red_l")
    R(c, 4, 21, 6, 23, "brown"); R(c, 9, 21, 11, 23, "brown"); R(c, 1, 14, 3, 15, "wood_d"); R(c, 0, 12, 3, 13, "steel")


@item("l4_sundial_stand", "日晷", C8, 2, 26, 30, level=LV)
def _(c, f):
    R(c, 9, 14, 16, 26, "stone"); R(c, 9, 14, 9, 26, "stone_l"); R(c, 16, 15, 16, 26, "stone_d"); R(c, 6, 26, 19, 28, "stone_d")
    circle(c, 12.5, 11, 11, "stone_d", 5.4); circle(c, 12.5, 10.4, 10, "stone_l", 4.8)
    for i in range(7):
        a = math.pi + i * math.pi / 6
        c.put(round(12 + math.cos(a) * 8), round(11 + math.sin(a) * -3.4 + 2), "ink")
    R(c, 12, 4, 13, 10, "gold_d"); c.cells([(13, 5), (14, 6), (14, 7)], "gold")


@item("l4_fairy_statue", "花仙子像", C8, 2, 24, 40, level=LV)
def _(c, f):
    plinth(c, 4, 19, 33, 39)
    circle(c, 11.5, 11, 3.2, "marble"); R(c, 9, 14, 14, 25, "marble"); R(c, 14, 15, 14, 25, "marble_d")
    for r in range(8):
        R(c, 2 + r // 2, 8 + r, 8, 8 + r, "marble_d"); R(c, 15, 8 + r, 21 - r // 2, 8 + r, "marble_d")
    R(c, 9, 26, 14, 31, "marble_d"); circle(c, 20, 16, 2.4, "sakura"); c.put(20, 16, "f1"); R(c, 9, 7, 14, 8, "sakura_d")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_hammock", "樹蔭吊床", C9, 4, 48, 34, level=LV)
def _(c, f):
    for x in (4, 41):
        R(c, x, 4, x + 2, 32, "wood_d"); R(c, x, 4, x, 32, "wood"); R(c, x - 2, 32, x + 4, 33, "wood_x")
    for i in range(36):
        y = 11 + int(round(8 * math.sin(i / 35 * math.pi)))
        R(c, 6 + i, y, 6 + i, y + 3, "red" if (i // 3) % 2 else "cloth"); c.put(6 + i, y + 4, "red_d")
    R(c, 3, 9, 6, 11, "rope"); R(c, 41, 9, 45, 11, "rope")
    R(c, 14, 14, 24, 16, "pink") if False else R(c, 16, 15, 24, 17, "white")


@item("l4_swing", "鞦韆", C9, 2, 32, 40, 2, 2, level=LV)
def _(c, f):
    R(c, 3, 3, 4, 38, "wood_d"); R(c, 27, 3, 28, 38, "wood_d"); R(c, 3, 3, 28, 4, "wood"); R(c, 1, 38, 6, 39, "wood_x"); R(c, 25, 38, 30, 39, "wood_x")
    dx = [-2, 2][f]
    for x in (11, 20):
        R(c, x + dx, 5, x + dx // 1, 5, "rope")
        for y in range(5, 28):
            c.put(x + int(round(dx * (y - 5) / 22)), y, "rope")
    R(c, 9 + dx * 1, 28, 22 + dx, 30, "wood"); R(c, 9 + dx, 28, 22 + dx, 28, "wood_l")


@item("l4_croquet", "槌球組", C9, 2, 32, 20, level=LV)
def _(c, f):
    for x, k in ((4, "red"), (11, "blue"), (18, "f1")):
        circle(c, x + 2, 14, 2.6, k, 2.4); c.put(x + 1, 13, "white")
    R(c, 21, 6, 22, 15, "wood"); R(c, 20, 6, 23, 8, "red_d"); R(c, 26, 4, 27, 15, "wood"); R(c, 25, 4, 28, 6, "blue_d")
    for x in (3, 9, 15):
        R(c, x, 3, x, 8, "iron_l"); R(c, x + 3, 3, x + 3, 8, "iron_l"); R(c, x, 3, x + 3, 3, "iron")
    R(c, 1, 17, 30, 18, "grass_d")


@item("l4_picnic_set", "野餐墊", C9, 2, 36, 26, level=LV, flat=True, note="鋪好的野餐墊，上面有一籃點心")
def _(c, f):
    R(c, 1, 3, 34, 22, "red"); 
    for x in range(1, 35, 4):
        R(c, x, 3, x + 1, 22, "white")
    for y in range(3, 23, 4):
        R(c, 1, y, 34, y + 1, "white") if False else None
    R(c, 7, 8, 16, 15, "wicker"); R(c, 7, 8, 16, 8, "wicker_d"); R(c, 9, 4, 14, 7, "wicker_d"); R(c, 8, 9, 15, 14, "wicker")
    R(c, 20, 9, 29, 14, "cloth"); circle(c, 22, 10, 2, "red_l"); circle(c, 26, 11, 2, "f1"); R(c, 3, 3, 3, 3, "red_d")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_stone_grill", "庭院石烤爐", C10, 2, 28, 28, 3, 5, level=LV)
def _(c, f):
    R(c, 3, 12, 24, 25, "stone"); R(c, 3, 12, 24, 12, "stone_l"); R(c, 24, 13, 24, 25, "stone_d"); R(c, 2, 25, 25, 26, "stone_d")
    R(c, 6, 15, 21, 21, "black"); R(c, 7, 17, 20, 20, "coal")
    for x in range(8, 20, 3):
        c.put(x + f % 2, 19, "f3"); c.put(x + 1, 18, "f2" if (x + f) % 2 else "f3")
    for x in range(5, 23, 3):
        R(c, x, 14, x, 14, "iron")
    R(c, 5, 13, 22, 13, "iron_d"); R(c, 8, 11, 13, 12, "meat"); R(c, 15, 11, 19, 12, "meat_d")
    R(c, 17, 0, 21, 11, "stone_d"); R(c, 17, 0, 21, 0, "stone"); R(c, 18, 1, 20, 11, "stone")
    for x, y in [[(19, -1)], [(20, -1)], [(18, -1)]][f]:
        pass
    for x, y in [[(19, 0)], [(20, 0)], [(18, 0)]][f]:
        c.put(x, y, "smoke")


@item("l4_lemonade_stand", "檸檬水攤", C10, 4, 40, 38, level=LV)
def _(c, f):
    for r in range(8):
        R(c, 2, 2 + r, 37, 2 + r, "white" if (r // 2) % 2 else "yellow") if False else None
    for x in range(2, 38, 4):
        R(c, x, 2, x + 1, 9, "yellow"); R(c, x + 2, 2, x + 3, 9, "white")
    for x in range(2, 38, 4):
        c.put(x + 1, 10, "yellow"); c.put(x + 2, 10, "white")
    R(c, 2, 1, 37, 1, "wood")
    R(c, 3, 11, 4, 36, "wood_d"); R(c, 35, 11, 36, 36, "wood_d")
    R(c, 3, 22, 36, 24, "wood_l"); R(c, 3, 25, 36, 34, "wood"); R(c, 3, 25, 36, 25, "wood_d")
    R(c, 8, 12, 15, 21, "glass"); R(c, 9, 14, 14, 21, "f1"); R(c, 8, 12, 15, 12, "glass_d"); circle(c, 12, 13, 1.4, "yellow")
    for x in (21, 26, 31):
        R(c, x, 17, x + 2, 21, "glass_d"); R(c, x + 1, 18, x + 1, 21, "f1")
    R(c, 14, 28, 24, 32, "cloth"); R(c, 15, 29, 23, 31, "red_l"); R(c, 1, 36, 38, 37, "wood_x")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_garden_gate", "花園柵門", C11, 2, 34, 32, level=LV)
def _(c, f):
    for x0 in (3, 18):
        R(c, x0, 6, x0 + 11, 28, "iron_d")
        for x in range(x0 + 1, x0 + 11, 3):
            R(c, x, 6, x, 28, "iron"); c.put(x, 5, "iron_l")
        R(c, x0, 12, x0 + 11, 12, "iron"); R(c, x0, 22, x0 + 11, 22, "iron")
    for x in (1, 30):
        R(c, x, 2, x + 2, 30, "stone"); R(c, x, 2, x + 2, 3, "stone_l"); R(c, x + 2, 4, x + 2, 30, "stone_d"); circle(c, x + 1, 1, 1.4, "stone_l")
    R(c, 14, 15, 16, 17, "gold_d")
    blob(c, 8, 4, 3, "green", "green_d", "green_l")


@item("l4_wood_fence", "木籬笆", C11, 2, 40, 24, level=LV)
def _(c, f):
    R(c, 1, 8, 38, 9, "wood_l"); R(c, 1, 17, 38, 18, "wood_l"); R(c, 1, 9, 38, 9, "wood")
    for x in range(2, 38, 5):
        R(c, x, 3, x + 3, 22, "wood"); R(c, x, 3, x, 22, "wood_l"); R(c, x + 3, 4, x + 3, 22, "wood_d")
        c.cells([(x + 1, 2), (x + 2, 2)], "wood_l"); c.put(x + 1, 12, "wood_x")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_gazebo", "涼亭", C12, 4, 50, 48, level=LV)
def _(c, f):
    for x in (5, 40):
        R(c, x, 14, x + 3, 44, "wood"); R(c, x, 14, x, 44, "wood_l"); R(c, x + 3, 15, x + 3, 44, "wood_d"); R(c, x - 1, 44, x + 4, 46, "stone_d")
    for r in range(13):
        R(c, 24 - 4 - r * 2 // 1 + 4 if r > 10 else 24 - 2 - r * 2, 2 + r, 25 + 2 + r * 2 if r <= 10 else 46, 2 + r, "red_d" if r % 2 else "red")
    R(c, 2, 13, 47, 15, "wood_d"); R(c, 2, 13, 47, 13, "wood_l")
    R(c, 11, 18, 38, 20, "wood_l")
    for x in range(12, 38, 3):
        R(c, x, 21, x, 30, "wood_d")
    R(c, 11, 31, 38, 32, "wood"); R(c, 4, 46, 45, 47, "stone")
    R(c, 23, 0, 26, 2, "gold")


@item("l4_stone_bridge", "拱形小石橋", C12, 4, 48, 28, level=LV)
def _(c, f):
    for x in range(2, 46):
        t = (x - 24) / 22.0
        top = 6 + int(round(9 * t * t))
        R(c, x, top, x, 24, "stone")
        c.put(x, top, "stone_l")
    circle(c, 24, 25, 11, "pond", 11) if False else None
    for x in range(10, 38):
        t = (x - 24) / 14.0
        bot = 24 - int(round(11 * math.sqrt(max(0, 1 - t * t))))
        R(c, x, bot, x, 24, "pond_d")
    R(c, 2, 4, 45, 5, "stone_l"); R(c, 2, 3, 45, 3, "stone"); R(c, 3, 4, 3, 7, "stone_d"); R(c, 44, 4, 44, 7, "stone_d")
    R(c, 1, 25, 46, 26, "stone_d")


@item("l4_koi_pond", "錦鯉池", C12, 4, 46, 30, 3, 3, level=LV, flat=True)
def _(c, f):
    circle(c, 22.5, 14.5, 22, "stone_d", 14); circle(c, 22.5, 14.5, 20.6, "pond", 12.8); circle(c, 22.5, 14.5, 17, "pond_d", 10)
    for n, (x, y, k) in enumerate(((12, 13, "koi"), (26, 17, "white"), (31, 11, "orange"))):
        dx = (f + n) % 3 - 1
        R(c, x + dx, y, x + dx + 4, y + 1, k); c.put(x + dx + 5, y, k); c.put(x + dx - 1, y - 1 + (f % 2), k)
    c.cells([(18, 20), (30, 22), (8, 16)], "pond_l")
    circle(c, 21, 10, 2.6, "green", 2); c.put(21, 9, "pink")


@item("l4_windmill", "小風車", C12, 2, 30, 48, 4, 4, level=LV)
def _(c, f):
    R(c, 11, 18, 18, 44, "stone_l"); R(c, 11, 18, 18, 18, "stone"); R(c, 18, 19, 18, 44, "stone_d"); R(c, 9, 44, 20, 46, "stone_d")
    for r in range(8):
        R(c, 10 - r // 2 + 1, 12 + r // 1, 19 + r // 2 - 1, 12 + r // 1, "red_d" if r % 2 else "red") if False else R(c, 9 + r // 3, 12 - 0 + r // 2, 20 - r // 3, 12 + r // 2, "red")
    R(c, 13, 28, 16, 44, "wood_d"); R(c, 13, 24, 16, 26, "glass_d")
    ang = f * math.pi / 8
    for i in range(4):
        a = ang + i * math.pi / 2
        for r in range(1, 12):
            x, y = round(14.5 + math.cos(a) * r), round(14 + math.sin(a) * r)
            c.put(x, y, "wood_l"); c.put(x + 1, y, "wood")
            if r > 5:
                c.put(round(14.5 + math.cos(a + 0.18) * r), round(14 + math.sin(a + 0.18) * r), "cloth")
    circle(c, 14.5, 14, 1.8, "wood_d")


@item("l4_scarecrow", "稻草人", C12, 1, 22, 38, 2, 2, level=LV)
def _(c, f):
    R(c, 10, 14, 11, 35, "wood_d"); R(c, 3, 16, 18, 17, "wood")
    R(c, 7, 17, 14, 28, "blue"); R(c, 14, 18, 14, 28, "blue_d"); R(c, 6, 21, 15, 22, "red")
    circle(c, 10.5, 9, 4, "hay", 4); c.cells([(9, 8), (12, 8)], "black"); R(c, 9, 11, 12, 11, "brown")
    R(c, 5, 4, 16, 5, "wood_d"); R(c, 7, 1, 14, 4, "wood")
    sway = f
    R(c, 1 + sway, 17, 4, 19, "hay"); R(c, 17, 17, 20 - sway, 19, "hay"); R(c, 8, 29, 8 - sway, 33, "hay"); R(c, 13, 29, 13 + sway, 33, "hay")


@item("l4_beehive", "蜂箱", C12, 1, 20, 24, 3, 3, level=LV)
def _(c, f):
    for r in range(3):
        R(c, 3, 8 + r * 4, 14, 11 + r * 4, "hay" if r % 2 else "wood_l"); R(c, 14, 9 + r * 4, 14, 11 + r * 4, "wood_d")
    R(c, 2, 5, 15, 7, "wood_d"); R(c, 2, 5, 15, 5, "wood"); R(c, 6, 18, 11, 19, "black")
    R(c, 3, 20, 14, 22, "wood_x"); R(c, 4, 22, 5, 23, "wood_d"); R(c, 12, 22, 13, 23, "wood_d")
    for k, (x, y) in enumerate(([(17, 8), (18, 13), (1, 11)], [(18, 9), (17, 14), (2, 12)], [(17, 10), (19, 12), (1, 9)])[f]):
        c.put(x, y, "f1"); c.put(x + 1, y, "black") if x < 18 else None


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l4_butterflies", "蝴蝶群", C13, 1, 22, 20, 4, 5, level=LV)
def _(c, f):
    for n, (x, y, k, kd) in enumerate(((5, 12, "pink", "pink_d"), (13, 6, "f1", "gold_d"), (17, 14, "blue_l", "blue_d"))):
        yy = y + [0, -1, 0, 1][(f + n) % 4]
        up = (f + n) % 2 == 0
        R(c, x - (3 if up else 2), yy - (2 if up else 1), x - 1, yy + (1 if up else 0), k); R(c, x + 1, yy - (2 if up else 1), x + (3 if up else 2), yy + (1 if up else 0), k)
        R(c, x, yy - 1, x, yy + 2, "black"); c.put(x - 1, yy - 3, "black"); c.put(x + 1, yy - 3, "black")
        c.put(x - 2, yy, kd); c.put(x + 2, yy, kd)


@item("l4_ducks", "小鴨", C13, 1, 24, 16, 4, 4, level=LV)
def _(c, f):
    for n, x in enumerate((4, 14)):
        b = (f + n) % 2
        circle(c, x + 3, 10 - b, 3.4, "f1", 3); circle(c, x + 6, 6 - b, 2.2, "f1", 2.2); R(c, x + 8, 6 - b, x + 9, 7 - b, "orange"); c.put(x + 6, 5 - b, "black")
        R(c, x, 11 - b, x + 2, 12 - b, "f1")
        R(c, x + 2, 13, x + 2, 14, "orange"); R(c, x + 5, 13, x + 5, 14, "orange")
    c.cells([(1, 14), (23, 14)], "water_l") if f % 2 else None


@item("l4_rabbit", "兔子", C13, 1, 18, 16, 4, 3, level=LV)
def _(c, f):
    h = [0, 1, 0, 0][f]
    circle(c, 8, 10 - h, 5, "fur_l", 4); circle(c, 8, 11 - h, 3.6, "white", 2.8)
    circle(c, 12, 6 - h, 3, "fur_l", 3); R(c, 11, 0 - h + 1, 12, 4 - h, "fur_l"); R(c, 13, 1 - h + (f == 2), 14, 4 - h, "fur_l"); R(c, 12, 1 - h + 1, 12, 3 - h, "pink")
    c.put(13, 6 - h, "black"); c.put(14, 8 - h, "pink")
    c.cells([(3, 9 - h), (2, 8 - h)], "white"); R(c, 5, 14, 7, 14, "fur_d"); R(c, 10, 14, 12, 14, "fur_d")


@item("l4_hedgehog", "刺蝟", C13, 1, 18, 14, 3, 3, level=LV)
def _(c, f):
    circle(c, 8, 7, 6, "brown", 4.4)
    for i in range(8):
        R(c, 3 + i, 1 + (i % 2) + (f == 1 and i % 3 == 0), 3 + i, 3, "wood_d")
    circle(c, 13, 9, 3, "fur", 2.4); R(c, 15, 9, 16, 10, "black"); c.put(13, 8, "black")
    R(c, 6, 12, 7, 12, "fur_d"); R(c, 11, 12, 12, 12, "fur_d")
