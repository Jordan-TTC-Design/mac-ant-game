"""Guild level 2 unlocks: the workshop and the study (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 2


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_writing_desk", "抽屜書桌", C1, 2, 36, 24, level=LV, note="兩側都有抽屜的書桌，角色可以坐在後面")
def _(c, f):
    table(c, 1, 6, 34, 23, depth=3)
    drawers(c, 3, 11, 10, 21, 3, "wood"); drawers(c, 25, 11, 32, 21, 3, "wood")
    R(c, 12, 13, 23, 22, "wood_x")
    R(c, 6, 3, 11, 5, "paper"); R(c, 7, 4, 10, 4, "ink"); R(c, 20, 2, 21, 5, "white"); R(c, 22, 3, 25, 5, "blue")


@item("l2_tall_stool", "抄寫員高腳凳", C1, 1, 14, 26, level=LV, seat=True, note="抄寫員坐的高腳凳")
def _(c, f):
    sy = 26 - 1 - SEAT_UP
    R(c, 2, sy, 11, sy + 1, "leather"); R(c, 2, sy, 11, sy, "leather_l"); R(c, 11, sy + 1, 11, sy + 1, "leather_d")
    R(c, 3, sy + 2, 3, 25, "wood_d"); R(c, 10, sy + 2, 10, 25, "wood_d"); R(c, 4, 17, 9, 17, "wood")
    R(c, 2, 25, 11, 25, "wood_x")


@item("l2_leather_chair", "皮革扶手椅", C1, 2, 26, 26, level=LV, seat=True)
def _(c, f):
    h = 26
    sy = h - 1 - SEAT_UP
    chair_back(c, 5, 2, 20, sy, "leather", "leather_l", "leather_d")
    for x0 in (1, 21):
        R(c, x0, 10, x0 + 3, h - 2, "leather"); R(c, x0, 10, x0 + 3, 10, "leather_l"); R(c, x0 + (3 if x0 < 20 else 0), 11, x0 + (3 if x0 < 20 else 0), h - 2, "leather_d")
    R(c, 5, sy, 20, sy, "leather_l"); R(c, 5, sy + 1, 20, h - 2, "leather"); R(c, 1, h - 1, 24, h - 1, "wood_d")


@item("l2_cushion_bench", "軟墊長椅", C1, 2, 34, 18, level=LV, seat=True)
def _(c, f):
    h = 18
    sy = h - 1 - SEAT_UP
    cushion(c, 2, sy - 2, 31, sy + 1, "velvet", "velvet_l", "velvet_d")
    R(c, 2, sy + 2, 31, h - 4, "wood"); R(c, 2, sy + 2, 31, sy + 2, "wood_l")
    legs(c, (3, 4, 29, 30), h - 3, h - 1)
    for x in range(6, 30, 5):
        c.put(x, sy - 1, "gold")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_map_chest", "地圖櫃", C2, 2, 32, 26, level=LV, note="一抽抽的大圖櫃，上面插著地圖筒")
def _(c, f):
    box(c, 1, 9, 30, 25, "wood", "wood_l", "wood_d")
    drawers(c, 3, 11, 28, 24, 4, "wood", "bronze_l")
    for x, k in ((5, "parch"), (9, "parch_d"), (13, "paper")):
        R(c, x, 1, x + 2, 8, k); R(c, x, 1, x + 2, 1, "red"); R(c, x + 2, 2, x + 2, 8, "parch_d")
    R(c, 20, 5, 28, 8, "parch"); R(c, 21, 6, 27, 6, "ink")


@item("l2_herb_cabinet", "藥草櫃", C2, 2, 24, 38, level=LV, note="一格一格小抽屜，貼著藥草名")
def _(c, f):
    box(c, 1, 1, 22, 37, "wood", "wood_l", "wood_d")
    for r in range(6):
        for col in range(3):
            x, y = 3 + col * 6, 3 + r * 6
            R(c, x, y, x + 4, y + 4, "wood_x"); R(c, x, y, x + 4, y, "wood_l"); c.put(x + 2, y + 2, "gold")
            R(c, x + 1, y + 3, x + 3, y + 3, "parch")
    R(c, 0, 37, 23, 37, "wood_x")


@item("l2_filing_cabinet", "檔案櫃", C2, 1, 18, 30, level=LV)
def _(c, f):
    box(c, 1, 1, 16, 28, "steel", "steel_l", "steel_d")
    for r in range(3):
        y = 3 + r * 8
        R(c, 3, y, 14, y + 6, "steel_d"); R(c, 3, y, 14, y, "steel_l"); R(c, 6, y + 2, 11, y + 3, "iron_d"); R(c, 7, y + 4, 10, y + 5, "paper")
    R(c, 2, 29, 5, 29, "iron_d"); R(c, 12, 29, 15, 29, "iron_d")


@item("l2_corner_shelf", "轉角書架", C2, 2, 28, 38, level=LV)
def _(c, f):
    box(c, 1, 1, 26, 37, "wood", "wood_l", "wood_d")
    for i, y in enumerate((3, 11, 19, 27)):
        R(c, 3, y, 24, y + 6, "wood_x"); shelf_books(c, 3, 24, y + 6, 6, i + 2); R(c, 2, y + 7, 25, y + 7, "wood_l")
    R(c, 9, 29, 11, 33, "gold"); R(c, 17, 20, 19, 24, "glass_d")


@item("l2_tool_wall", "工具牆架", C2, 2, 32, 22, level=LV, wall=True, note="牆上掛滿錘子鉗子")
def _(c, f):
    R(c, 1, 1, 30, 20, "wood_x"); R(c, 1, 1, 30, 1, "wood_l"); R(c, 1, 9, 30, 9, "wood"); R(c, 1, 17, 30, 17, "wood")
    for x, h in ((4, 6), (8, 5), (12, 6)):
        R(c, x, 2, x, 2 + h, "wood_l"); R(c, x - 1, 2 + h, x + 1, 3 + h, "steel")
    R(c, 17, 3, 18, 8, "steel_l"); R(c, 16, 3, 19, 4, "steel"); R(c, 22, 2, 28, 4, "steel_d"); R(c, 24, 5, 26, 8, "wood")
    for x in range(4, 28, 5):
        R(c, x, 11, x + 1, 15, "steel_d"); c.put(x, 11, "steel_l")
    R(c, 3, 18, 28, 19, "wood_d")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_magnifier", "放大鏡", C3, 1, 14, 12, level=LV)
def _(c, f):
    circle(c, 5, 5, 4.2, "wood_d", 4.2); circle(c, 5, 5, 3.2, "glass", 3.2); c.put(3, 3, "white"); c.put(4, 3, "white")
    R(c, 8, 8, 10, 10, "wood_d"); R(c, 9, 9, 11, 11, "wood")


@item("l2_pen_holder", "羽毛筆筒", C3, 1, 12, 16, level=LV)
def _(c, f):
    R(c, 3, 8, 8, 14, "wood"); R(c, 3, 8, 8, 8, "wood_l"); R(c, 8, 9, 8, 14, "wood_d"); R(c, 3, 15, 8, 15, "wood_x")
    for x, h, k in ((4, 7, "white"), (6, 5, "red_l"), (7, 8, "blue_l")):
        R(c, x, 8 - h, x, 7, k); c.put(x + 1, 8 - h + 1, "cloth_d")


@item("l2_seal", "火漆印章", C3, 1, 14, 10, level=LV)
def _(c, f):
    circle(c, 4, 6, 3, "red_d", 2.4); circle(c, 4, 6, 2, "red", 1.6); c.put(4, 6, "red_l")
    R(c, 8, 3, 9, 7, "wood"); R(c, 7, 7, 10, 8, "gold"); R(c, 8, 1, 9, 2, "wood_l")


@item("l2_ink_set", "墨水組", C3, 1, 18, 12, level=LV)
def _(c, f):
    R(c, 1, 8, 16, 10, "wood"); R(c, 1, 8, 16, 8, "wood_l")
    for x, k in ((3, "black"), (8, "blue"), (13, "red")):
        R(c, x, 3, x + 3, 7, "glass_d"); R(c, x + 1, 4, x + 2, 7, k); R(c, x + 1, 1, x + 2, 2, "wood_d")


@item("l2_paper_tray", "公文盤", C3, 1, 18, 14, level=LV)
def _(c, f):
    for y, k in ((9, "steel"), (5, "steel_d")):
        R(c, 2, y, 15, y + 2, k); R(c, 2, y, 15, y, "steel_l")
    for x, y in ((4, 7), (9, 3)):
        R(c, x, y, x + 7, y + 1, "paper"); R(c, x + 1, y, x + 5, y, "white")
    R(c, 3, 12, 14, 12, "steel_d")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_reading_lamp", "閱讀燈", C4, 1, 16, 28, 2, 2, level=LV, note="綠色燈罩的書桌燈")
def _(c, f):
    for r in range(7):
        R(c, 2 + r // 2, 1 + r, 13 - r // 2, 1 + r, "lamp_green" if r else "lamp_green_d")
    R(c, 3, 8, 12, 8, "lamp_green_d")
    R(c, 4, 9, 11, 12, "f1" if f else "f2")
    R(c, 7, 9, 8, 23, "bronze_d"); R(c, 7, 9, 7, 23, "bronze")
    R(c, 4, 24, 11, 26, "bronze"); R(c, 4, 24, 11, 24, "bronze_l"); R(c, 3, 27, 12, 27, "bronze_d")


@item("l2_oil_lamp", "油燈", C4, 1, 12, 16, 2, 3, level=LV)
def _(c, f):
    R(c, 3, 7, 8, 13, "glass_d"); R(c, 4, 8, 7, 12, "f2" if f else "f3"); R(c, 3, 6, 8, 6, "bronze"); R(c, 4, 5, 7, 5, "bronze_d")
    flame(c, 5, 4, 3, f, 0)
    R(c, 2, 13, 9, 14, "bronze"); R(c, 3, 15, 8, 15, "bronze_d"); R(c, 9, 8, 10, 11, "bronze_d")


@item("l2_study_chandelier", "書房吊燈", C4, 2, 30, 22, 2, 3, level=LV, ceiling=True)
def _(c, f):
    R(c, 14, 0, 15, 6, "bronze_d")
    R(c, 3, 8, 26, 9, "bronze"); R(c, 3, 8, 26, 8, "bronze_l")
    R(c, 14, 6, 15, 12, "bronze")
    for x in (4, 10, 19, 25):
        R(c, x, 5, x + 1, 8, "cloth"); flame(c, x, 4, 3, f + x, 0)
    for x in (6, 22):
        R(c, x, 10, x, 14, "bronze_d")
    circle(c, 14.5, 15, 3, "glass_d"); circle(c, 14.5, 15, 2, "glass"); c.put(14, 14, "white")


@item("l2_stained_lamp", "彩繪玻璃燈", C4, 1, 16, 24, 2, 2, level=LV, note="一片片彩色玻璃拼成的桌燈")
def _(c, f):
    cols = ["lred_l" if False else "red_l", "blue_l", "green_l", "f1"]
    for r in range(9):
        half = 2 + (r * 3) // 4
        for x in range(8 - half, 9 + half):
            c.put(x, 2 + r, cols[(x + r) % 4] if f == 0 else cols[(x + r + 1) % 4])
    R(c, 3, 11, 12, 11, "bronze_d"); R(c, 7, 12, 8, 19, "bronze"); R(c, 4, 20, 11, 22, "bronze_d"); R(c, 4, 20, 11, 20, "bronze")
    R(c, 6, 0, 9, 1, "bronze")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_star_chart", "星象圖", C5, 2, 34, 26, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 32, 24, "wood"); R(c, 3, 3, 30, 22, "hv_night_d" if "hv_night_d" in P else "iron_d")
    circle(c, 16.5, 12.5, 8.6, "iron_d", 8.6); circle(c, 16.5, 12.5, 8, "blue_d", 8)
    for x, y in ((12, 7), (19, 9), (15, 14), (21, 16), (10, 17), (17, 5)):
        c.put(x, y, "f1")
    c.cells([(12, 7), (13, 8), (14, 9), (15, 10), (15, 14), (17, 15)], "gold_d")
    for x, y in ((5, 5), (28, 6), (6, 20), (27, 19), (24, 4)):
        c.put(x, y, "white")


@item("l2_herbarium", "植物標本框", C5, 1, 22, 24, level=LV, wall=True)
def _(c, f):
    frame_border(c, 1, 1, 20, 22, "wood")
    R(c, 3, 3, 18, 20, "parch")
    R(c, 10, 8, 10, 19, "green_d"); blob(c, 10, 8, 3.2, "green", "green_d", "green_l", 3); R(c, 6, 13, 9, 14, "green"); R(c, 11, 11, 15, 12, "green")
    c.put(10, 5, "red_l"); R(c, 6, 18, 14, 18, "parch_d"); R(c, 7, 19, 12, 19, "ink")


@item("l2_sea_chart", "航海圖", C5, 2, 34, 24, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 32, 22, "parch"); R(c, 1, 1, 32, 1, "parch_d"); R(c, 1, 22, 32, 22, "parch_d"); R(c, 1, 2, 1, 21, "parch_d"); R(c, 32, 2, 32, 21, "parch_d")
    for x, y, w, h in ((4, 4, 8, 6), (16, 9, 10, 7), (22, 3, 7, 4)):
        R(c, x, y, x + w, y + h, "grass_d"); R(c, x + 1, y + 1, x + w - 1, y + h - 1, "grass")
    c.cells([(8, 15), (12, 17), (16, 19), (20, 18)], "red"); R(c, 5, 18, 7, 20, "ink"); R(c, 26, 14, 30, 14, "ink"); R(c, 28, 12, 28, 16, "ink")
    for x in range(3, 31, 4):
        c.put(x, 21, "water_d")


@item("l2_family_crest", "家族紋章", C5, 1, 20, 24, level=LV, wall=True)
def _(c, f):
    R(c, 3, 2, 16, 16, "blue_d"); R(c, 3, 2, 16, 2, "gold")
    for r in range(6):
        R(c, 3 + r, 17 + r, 16 - r, 17 + r, "blue_d")
    R(c, 4, 3, 15, 15, "blue"); R(c, 9, 3, 10, 21, "gold"); R(c, 4, 8, 15, 9, "gold")
    circle(c, 6.5, 6, 1.6, "white"); circle(c, 12.5, 12, 1.6, "white")
    R(c, 8, 0, 11, 1, "gold_d")


@item("l2_wall_bookshelf", "壁掛小書架", C5, 1, 26, 16, level=LV, wall=True)
def _(c, f):
    R(c, 1, 2, 24, 3, "wood"); R(c, 1, 2, 24, 2, "wood_l")
    shelf_books(c, 2, 23, 1, 9, 5)
    R(c, 1, 13, 24, 14, "wood"); R(c, 1, 14, 24, 14, "wood_d")
    R(c, 3, 3, 3, 12, "wood_d") if False else None
    shelf_books(c, 2, 23, 12, 8, 1)
    R(c, 1, 8, 24, 9, "wood")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_study_rug", "書房大地毯", C6, 4, 44, 30, level=LV, flat=True, note="深紅底、金邊的大地毯")
def _(c, f):
    rug_base(c, 44, 30, "velvet", "gold", "velvet_d")
    R(c, 8, 7, 35, 22, "velvet_d"); R(c, 9, 8, 34, 21, "velvet")
    for x in range(12, 33, 5):
        c.cells([(x, 15), (x - 1, 14), (x + 1, 14), (x, 13), (x, 17), (x - 1, 16), (x + 1, 16)], "gold")


@item("l2_bear_rug", "熊皮地毯", C6, 2, 38, 26, level=LV, flat=True)
def _(c, f):
    circle(c, 18.5, 13, 14, "brown", 9); circle(c, 18.5, 12.5, 12.5, "dark", 8)
    circle(c, 18.5, 5, 5, "brown", 4); R(c, 14, 1, 15, 3, "brown"); R(c, 22, 1, 23, 3, "brown"); c.cells([(16, 4), (21, 4)], "black"); R(c, 18, 6, 19, 7, "black")
    for x0, y0 in ((4, 14), (31, 14), (7, 22), (28, 22)):
        circle(c, x0, y0, 2.6, "brown", 2.2)


@item("l2_geo_rug", "幾何地毯", C6, 2, 34, 26, level=LV, flat=True)
def _(c, f):
    rug_base(c, 34, 26, "cloth", "blue_d", "blue", True)
    for i in range(4):
        R(c, 8 + i * 4, 6 + i * 2, 25 - i * 4, 19 - i * 2, "blue_l" if i % 2 else "red")
    R(c, 14, 11, 19, 14, "gold")


@item("l2_round_study_rug", "小圓地毯", C6, 2, 30, 22, level=LV, flat=True)
def _(c, f):
    circle(c, 14.5, 10.5, 14, "leather_d", 10); circle(c, 14.5, 10.5, 12.6, "leather", 8.8); circle(c, 14.5, 10.5, 8, "cloth", 5.6)
    circle(c, 14.5, 10.5, 5, "leather_l", 3.4); circle(c, 14.5, 10.5, 2, "gold", 1.4)


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_window_planter", "窗邊花箱", C7, 1, 26, 18, level=LV)
def _(c, f):
    R(c, 1, 9, 24, 15, "wood"); R(c, 1, 9, 24, 9, "wood_l"); R(c, 24, 10, 24, 15, "wood_d"); R(c, 2, 16, 23, 16, "wood_x")
    for x, k in ((4, "red_l"), (8, "pink"), (12, "f1"), (16, "red_l"), (20, "pink")):
        R(c, x, 5, x, 9, "green_d"); circle(c, x, 4, 1.6, k); R(c, x - 2, 7, x + 2, 8, "green")


@item("l2_orchid", "蘭花", C7, 1, 14, 28, level=LV)
def _(c, f):
    pot(c, 7, 27, 8, 6, "pot")
    for dx, h in ((-1, 14), (0, 18), (1, 12)):
        R(c, 7 + dx, 27 - 6 - h, 7 + dx, 20, "green_d")
    for x, y in ((4, 6), (8, 3), (10, 8), (5, 11), (9, 13)):
        circle(c, x, y, 1.8, "pink" if x % 2 else "white"); c.put(x, y, "f1")
    R(c, 3, 18, 6, 19, "green"); R(c, 8, 17, 11, 18, "green")


@item("l2_ivy_trellis", "常春藤架", C7, 2, 22, 36, level=LV)
def _(c, f):
    for x in (3, 18):
        R(c, x, 2, x + 1, 33, "wood_d")
    for y in range(6, 32, 6):
        R(c, 3, y, 19, y, "wood")
    for x in (7, 11, 15):
        R(c, x, 2, x, 33, "wood")
    for n, (x, y) in enumerate(((4, 5), (9, 9), (14, 6), (6, 15), (12, 17), (16, 13), (5, 23), (10, 26), (15, 22), (9, 3), (12, 30))):
        circle(c, x, y, 2.2, "green" if n % 2 else "green_d"); c.put(x - 1, y - 1, "green_l")
    R(c, 1, 33, 20, 35, "pot"); R(c, 1, 33, 20, 33, "pot_d")


@item("l2_bamboo_pots", "竹筒小景", C7, 1, 20, 24, level=LV)
def _(c, f):
    for x, h in ((4, 14), (9, 19), (14, 11)):
        R(c, x, 22 - h, x + 2, 22, "green"); R(c, x + 2, 23 - h, x + 2, 22, "green_d")
        for y in range(22 - h + 3, 22, 4):
            R(c, x, y, x + 2, y, "green_d")
        R(c, x - 1, 22 - h - 1, x + 3, 22 - h, "green_l")
    R(c, 2, 20, 17, 22, "wood"); R(c, 2, 20, 17, 20, "wood_l"); R(c, 3, 23, 16, 23, "wood_x")
    for x in (6, 12):
        c.put(x, 19, "stone_l"); c.put(x + 1, 19, "stone")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_scholar_bust", "學者胸像", C8, 1, 18, 30, level=LV)
def _(c, f):
    plinth(c, 3, 14, 20, 29)
    circle(c, 8.5, 9, 4.6, "marble", 5.4); R(c, 5, 5, 12, 6, "marble_d"); R(c, 6, 8, 7, 8, "marble_x"); R(c, 10, 8, 11, 8, "marble_x")
    R(c, 7, 13, 10, 14, "marble_d"); R(c, 4, 15, 13, 19, "marble"); R(c, 13, 16, 13, 19, "marble_d"); c.put(8, 11, "marble_x")
    R(c, 5, 25, 12, 26, "gold")


@item("l2_alchemist_statue", "煉金術士雕像", C8, 2, 26, 46, level=LV)
def _(c, f):
    plinth(c, 4, 21, 36, 45)
    circle(c, 12.5, 9, 4, "stone_l"); R(c, 8, 4, 17, 6, "stone_d"); R(c, 7, 13, 18, 31, "stone"); R(c, 18, 13, 18, 31, "stone_d")
    R(c, 5, 15, 7, 24, "stone_d"); R(c, 18, 15, 22, 17, "stone"); R(c, 21, 8, 22, 17, "stone_l")
    circle(c, 21.5, 7, 2.6, "glass_d"); circle(c, 21.5, 7, 1.8, "glass")                          # a flask raised
    R(c, 9, 32, 16, 35, "stone_d"); R(c, 7, 40, 18, 41, "gold")


@item("l2_globe_sculpture", "星球儀雕塑", C8, 2, 24, 36, 2, 2, level=LV, note="環繞著金屬圈的小行星")
def _(c, f):
    R(c, 10, 26, 13, 30, "bronze"); R(c, 6, 31, 17, 34, "bronze_d"); R(c, 6, 31, 17, 31, "bronze")
    circle(c, 11.5, 15, 8, "blue_d", 8); circle(c, 11, 14.5, 7, "blue", 7); R(c, 7, 11, 11, 14, "grass"); R(c, 12, 16, 16, 19, "grass")
    for i in range(24):
        a = i * math.pi / 12
        x, y = 11.5 + math.cos(a) * 11, 15 + math.sin(a) * 4.5 * (1 if f == 0 else -1) * 1.0 + math.sin(a) * 1.5
        c.put(round(x), round(y), "gold")
    c.put(18 if f else 4, 12 if f else 18, "gold_l")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_dice_table", "骰子桌", C9, 2, 32, 24, level=LV)
def _(c, f):
    table(c, 1, 8, 30, 23, "dark", depth=4)
    R(c, 3, 9, 28, 13, "green"); R(c, 3, 9, 28, 9, "green_l"); R(c, 28, 10, 28, 13, "green_d")
    R(c, 8, 10, 10, 12, "white"); c.put(9, 11, "black"); R(c, 16, 11, 18, 13, "white"); c.cells([(16, 11), (18, 13), (17, 12)], "black"); R(c, 22, 10, 23, 11, "gold")
    R(c, 24, 4, 27, 7, "wood"); R(c, 5, 5, 8, 7, "glass_d")


@item("l2_harp", "豎琴", C9, 2, 24, 40, level=LV)
def _(c, f):
    R(c, 3, 2, 5, 34, "wood_l"); R(c, 3, 2, 5, 34, "wood"); R(c, 4, 2, 5, 34, "wood_l")
    for i in range(10):
        R(c, 5 + i // 2, 2 + i, 6 + i // 2, 3 + i, "wood")
    R(c, 14, 14, 15, 34, "wood_d"); R(c, 5, 34, 17, 36, "wood_d"); R(c, 3, 36, 19, 38, "wood_x")
    for i in range(8):
        R(c, 7 + i, 8 + i * 3, 7 + i, 33, "cloth" if i % 2 else "gold_l")
    R(c, 3, 2, 14, 3, "gold_d")


@item("l2_gramophone", "留聲機", C9, 1, 20, 26, 2, 3, level=LV, note="轉著唱片，冒出音符")
def _(c, f):
    box(c, 2, 14, 14, 23, "wood", "wood_l", "wood_d"); R(c, 4, 16, 12, 17, "black"); R(c, 5, 19, 11, 21, "wood_x")
    R(c, 3, 12, 13, 13, "iron_d"); R(c, 5, 12, 11, 12, "black"); c.put(8 if not f else 9, 12, "white")
    R(c, 9, 4, 10, 11, "gold_d")
    for r in range(8):
        R(c, 8 - r // 2, 2 + r // 2 - 0, 13 + r, 3 + r // 2, "gold") if False else None
    circle(c, 14.5, 5, 4.4, "gold", 4.4); circle(c, 14.5, 5, 3, "gold_d", 3); circle(c, 14.5, 5, 1.2, "black", 1.2)
    R(c, 3, 24, 5, 25, "wood_x"); R(c, 11, 24, 13, 25, "wood_x")
    for x, y in (([17, 1], [18, 3]) if f else ([16, 2], [18, 0])):
        c.put(x, y, "f1"); c.put(x, y + 1, "f1")


@item("l2_rocking_chair", "搖椅", C9, 2, 26, 28, level=LV, seat=True)
def _(c, f):
    h = 28
    sy = h - 1 - SEAT_UP
    R(c, 7, 2, 18, 3, "wood_d"); R(c, 7, 2, 18, 2, "wood")
    for x in (8, 11, 14, 17):
        R(c, x, 4, x, sy - 1, "wood_l")
    R(c, 6, 3, 7, sy, "wood_d"); R(c, 18, 3, 19, sy, "wood_d")
    R(c, 5, sy, 20, sy + 1, "leather"); R(c, 5, sy, 20, sy, "leather_l"); R(c, 5, sy + 1, 20, sy + 1, "leather_d")
    for x0 in (3, 20):
        R(c, x0, sy - 8, x0 + 2, sy - 7, "wood"); R(c, x0 + (0 if x0 < 10 else 2), sy - 8, x0 + (0 if x0 < 10 else 2), sy, "wood_d")
    R(c, 6, sy + 2, 6, h - 3, "wood_x"); R(c, 19, sy + 2, 19, h - 3, "wood_x")
    R(c, 3, h - 3, 22, h - 2, "wood_d"); c.cells([(2, h - 4), (23, h - 4)], "wood_d"); R(c, 1, h - 5, 1, h - 4, "wood_d"); R(c, 24, h - 5, 24, h - 4, "wood_d")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_tea_stove", "茶爐", C10, 1, 22, 26, 3, 4, level=LV, note="咕嘟咕嘟的茶壺")
def _(c, f):
    box(c, 2, 13, 19, 23, "iron", "iron_l", "iron_d"); R(c, 5, 16, 16, 21, "black"); R(c, 6, 18, 15, 20, "f3"); R(c, 8, 19, 13, 20, "f2" if f % 2 else "f1")
    R(c, 5, 6, 15, 12, "bronze"); R(c, 5, 6, 15, 6, "bronze_l"); R(c, 15, 7, 15, 12, "bronze_d"); R(c, 7, 4, 13, 5, "bronze_d"); R(c, 9, 3, 11, 3, "bronze_l")
    R(c, 16, 8, 19, 9, "bronze"); R(c, 17, 7, 19, 7, "bronze_d"); R(c, 2, 9, 4, 11, "bronze_d")
    for x, y in [[(20, 4), (18, 1)], [(19, 3), (20, 0)], [(18, 4), (19, 1)]][f]:
        c.put(x, y, "smoke"); c.put(x, y + 1, "smoke_d")
    R(c, 3, 24, 5, 25, "iron_d"); R(c, 16, 24, 18, 25, "iron_d")


@item("l2_mini_bar", "小吧台", C10, 2, 38, 30, level=LV)
def _(c, f):
    R(c, 1, 13, 36, 16, "dark_l"); R(c, 1, 13, 36, 13, "wood_l")
    R(c, 2, 17, 35, 28, "dark"); R(c, 2, 17, 35, 17, "dark_d")
    for x in range(4, 34, 6):
        R(c, x, 19, x + 4, 26, "dark_d"); R(c, x, 19, x + 4, 19, "dark_l")
    for x, k in ((5, "red_l"), (9, "blue_l"), (13, "green_l"), (26, "f1")):
        R(c, x, 8, x + 2, 12, "glass_d"); R(c, x + 1, 9, x + 1, 12, k); R(c, x + 1, 6, x + 1, 7, "wood_d")
    R(c, 20, 10, 23, 12, "glass"); R(c, 29, 9, 33, 12, "steel"); R(c, 29, 9, 33, 9, "steel_l")
    R(c, 1, 29, 36, 29, "wood_x")


@item("l2_coffee_machine", "咖啡機", C10, 1, 18, 26, 3, 3, level=LV)
def _(c, f):
    box(c, 2, 4, 15, 22, "steel", "steel_l", "steel_d"); R(c, 4, 6, 13, 10, "black"); R(c, 5, 7, 12, 9, "teal_l" if f == 1 else "teal")
    R(c, 6, 13, 11, 14, "iron_d"); R(c, 8, 15, 9, 16 + (f % 3 != 0), "brown")
    R(c, 5, 17, 12, 22, "cloth"); R(c, 5, 17, 12, 17, "white"); R(c, 6, 18, 11, 19, "brown")
    R(c, 3, 23, 14, 24, "steel_d"); c.cells([(12, 12), (12, 11)], "lred_l" if False else "red_l")


@item("l2_baker_table", "麵包桌", C10, 2, 36, 26, level=LV)
def _(c, f):
    table(c, 1, 11, 34, 25, "wood", depth=3)
    R(c, 3, 8, 12, 10, "cloth"); circle(c, 5, 8, 2.4, "straw"); circle(c, 9, 8, 2.4, "straw_d")
    R(c, 15, 7, 24, 10, "wood_l"); R(c, 16, 6, 23, 7, "straw"); R(c, 16, 4, 22, 5, "straw_d")
    R(c, 27, 6, 32, 10, "cloth"); R(c, 28, 7, 31, 9, "pink"); R(c, 29, 5, 30, 6, "red")
    R(c, 3, 15, 12, 20, "wood_x"); R(c, 22, 15, 32, 20, "wood_x")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_double_door", "雙開木門", C11, 2, 36, 44, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 34, 42, "wood_d"); R(c, 3, 3, 16, 42, "wood"); R(c, 19, 3, 32, 42, "wood")
    for x0 in (4, 20):
        R(c, x0, 6, x0 + 11, 20, "wood_l"); R(c, x0 + 1, 7, x0 + 10, 19, "wood"); R(c, x0, 24, x0 + 11, 38, "wood_l"); R(c, x0 + 1, 25, x0 + 10, 37, "wood")
    R(c, 17, 3, 18, 42, "iron_d"); circle(c, 14.5, 24, 1.4, "gold"); circle(c, 21.5, 24, 1.4, "gold")
    R(c, 0, 0, 35, 2, "wood_x")


@item("l2_mountain_screen", "山水屏風", C11, 2, 38, 34, level=LV)
def _(c, f):
    for n, x0 in enumerate((1, 13, 25)):
        R(c, x0, 3, x0 + 11, 31, "wood_d"); R(c, x0 + 1, 4, x0 + 10, 30, "parch")
        R(c, x0 + 1, 4, x0 + 10, 4, "wood")
        c.cells([(x0 + 3, 20), (x0 + 4, 18), (x0 + 5, 16), (x0 + 6, 14), (x0 + 7, 16), (x0 + 8, 19)], "ink")
        R(c, x0 + 2, 22, x0 + 9, 24, "water_l"); R(c, x0 + 6, 8, x0 + 8, 10, "red_l")
    R(c, 1, 32, 36, 33, "wood_x")


@item("l2_bay_window", "凸窗", C11, 2, 36, 34, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 34, 32, "wood_d"); R(c, 3, 3, 32, 28, "sky")
    R(c, 3, 3, 32, 8, "sky_d"); R(c, 6, 10, 12, 12, "white"); R(c, 22, 6, 29, 8, "white")
    R(c, 3, 22, 32, 28, "grass"); R(c, 3, 22, 32, 22, "grass_d")
    R(c, 11, 3, 12, 28, "wood"); R(c, 23, 3, 24, 28, "wood"); R(c, 3, 15, 32, 15, "wood")
    R(c, 1, 29, 34, 31, "wood_l"); R(c, 1, 31, 34, 32, "wood_d")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_garden_arbor", "玫瑰花架", C12, 2, 32, 38, level=LV)
def _(c, f):
    for x in (3, 27):
        R(c, x, 8, x + 1, 36, "wood_d"); R(c, x + 1, 9, x + 1, 36, "wood")
    for i in range(14):
        h = int(round(math.sin(i / 13 * math.pi) * 7))
        R(c, 3 + i * 2, 8 - h, 4 + i * 2, 9 - h, "wood")
    for n, (x, y) in enumerate(((5, 12), (8, 5), (14, 2), (20, 3), (26, 6), (28, 14), (4, 22), (28, 24), (12, 4), (23, 8))):
        circle(c, x, y, 2, "green" if n % 3 else "green_d"); c.put(x, y, "red_l" if n % 2 else "pink")
    R(c, 1, 36, 6, 37, "stone_d"); R(c, 25, 36, 30, 37, "stone_d")


@item("l2_mailbox", "郵筒", C12, 1, 16, 28, level=LV)
def _(c, f):
    R(c, 7, 14, 8, 26, "wood_d"); R(c, 3, 26, 12, 27, "stone_d")
    circle(c, 7.5, 9, 6, "blue_d", 5.4); R(c, 2, 9, 13, 15, "blue_d"); R(c, 3, 9, 12, 14, "blue")
    R(c, 4, 11, 11, 12, "black"); R(c, 6, 6, 9, 7, "gold"); R(c, 12, 5, 14, 9, "red"); c.put(14, 4, "red_l")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l2_bookworm", "書蟲", C13, 1, 16, 12, 3, 3, level=LV, note="在書上蠕動的綠色小蟲")
def _(c, f):
    R(c, 1, 7, 14, 10, "red_d"); R(c, 1, 7, 14, 7, "red"); R(c, 2, 8, 13, 9, "paper")
    for i in range(5):
        y = 5 - (1 if (i + f) % 2 else 0)
        circle(c, 3 + i * 2, y, 1.6, "green" if i else "green_l")
    c.cells([(10, 3), (11, 3)], "black") if False else None
    c.put(11, 4, "black"); R(c, 12, 2, 12, 3, "green_d")


@item("l2_ink_slime", "墨水史萊姆", C13, 1, 18, 16, 4, 3, level=LV)
def _(c, f):
    sq = [0, 1, 0, -1][f]
    circle(c, 8.5, 10 - sq / 2, 7 + sq * 0.5, "black", 5.4 - sq * 0.5); circle(c, 8.2, 9.6, 6, "iron_d", 4.4 - sq * 0.4)
    c.cells([(5, 7), (6, 7)], "iron_l"); c.cells([(6, 10), (11, 10)], "white"); c.put(6, 11, "black")
    R(c, 14, 13, 16, 14, "black"); c.put(16 + (1 if f == 2 else 0), 12, "black")


@item("l2_raven", "渡鴉", C13, 1, 18, 28, 3, 2, level=LV)
def _(c, f):
    R(c, 3, 22, 14, 23, "wood"); R(c, 8, 23, 9, 26, "wood_d"); R(c, 4, 26, 13, 27, "wood_x")
    circle(c, 8, 15, 5.5, "black", 6); circle(c, 7.6, 14.6, 4.6, "iron_d", 5.2)
    circle(c, 11.5, 8, 3.2, "black", 3.2); R(c, 13, 8, 15, 9, "gold_d"); c.put(12, 7, "white")
    R(c, 3, 17, 6, 21, "black"); R(c, 6, 20, 6, 21, "black")
    c.put(9 if f == 1 else 5, 14, "iron_l")
    R(c, 7, 20, 7, 21, "gold_d"); R(c, 10, 20, 10, 21, "gold_d")
