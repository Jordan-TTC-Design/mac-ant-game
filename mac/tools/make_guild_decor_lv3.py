"""Guild level 3 unlocks: the meeting room (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 3
add_colors({"board_w": (242, 246, 250), "board_w_d": (200, 208, 220), "marker_r": (210, 60, 60), "marker_b": (60, 90, 190), "navy_cloth": (44, 62, 112), "navy_cloth_d": (30, 44, 84), "navy_cloth_l": (84, 108, 170)})


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_conference_table", "長會議桌", C1, 4, 50, 30, level=LV, note="可以圍坐十幾個人的長桌")
def _(c, f):
    R(c, 1, 8, 48, 14, "dark_l"); R(c, 1, 8, 48, 8, "wood_l"); R(c, 48, 9, 48, 14, "dark")
    R(c, 2, 15, 47, 24, "dark"); R(c, 2, 15, 47, 15, "dark_d")
    for x in (4, 13, 22, 31, 40):
        R(c, x, 17, x + 4, 23, "dark_d")
    legs(c, (3, 46), 25, 29, "wood_x"); R(c, 1, 29, 4, 29, "wood_x"); R(c, 45, 29, 48, 29, "wood_x")
    for x in (6, 17, 28, 38):
        R(c, x, 4, x + 4, 7, "paper"); R(c, x + 1, 5, x + 3, 5, "ink")
    R(c, 22, 2, 25, 6, "glass_d"); R(c, 23, 3, 24, 6, "glass")


@item("l3_conference_chair", "會議椅", C1, 1, 16, 28, level=LV, seat=True)
def _(c, f):
    h = 28
    sy = h - 1 - SEAT_UP
    chair_back(c, 3, 2, 12, 14, "navy_cloth", "navy_cloth_l", "navy_cloth_d", False)
    R(c, 7, 15, 8, sy - 1, "iron_d")
    cushion(c, 2, sy - 2, 13, sy + 1, "navy_cloth", "navy_cloth_l", "navy_cloth_d")
    R(c, 7, sy + 2, 8, h - 4, "iron_l"); R(c, 2, h - 3, 13, h - 3, "iron_d"); R(c, 1, h - 2, 3, h - 1, "iron_d"); R(c, 12, h - 2, 14, h - 1, "iron_d")


@item("l3_round_table", "圓形議事桌", C1, 4, 46, 32, level=LV, note="大家平起平坐的圓桌")
def _(c, f):
    circle(c, 22.5, 12, 21, "dark_d", 8.4); circle(c, 22.5, 11, 20, "dark_l", 7.6); circle(c, 22.5, 11, 15, "dark", 5.6)
    circle(c, 22.5, 11, 5, "gold_d", 2.4); circle(c, 22.5, 10.6, 4, "gold", 2)
    R(c, 18, 19, 27, 28, "dark_d"); R(c, 19, 19, 26, 27, "dark"); R(c, 12, 29, 33, 31, "dark_d")
    for x in (10, 18, 28, 35):
        R(c, x, 6, x + 2, 8, "paper")


@item("l3_chairman_chair", "主席大椅", C1, 2, 26, 36, level=LV, seat=True, note="高背、鑲金的主席椅")
def _(c, f):
    h = 36
    sy = h - 1 - SEAT_UP
    R(c, 4, 1, 21, sy, "velvet"); R(c, 4, 1, 21, 1, "gold"); R(c, 4, 1, 4, sy, "gold_d"); R(c, 21, 1, 21, sy, "gold_d")
    R(c, 7, 4, 18, 14, "velvet_d"); R(c, 8, 5, 17, 13, "velvet_l"); circle(c, 12.5, 9, 2.4, "gold")
    for x in (4, 21):
        circle(c, x, 0, 1.4, "gold_l")
    for x0 in (1, 21):
        R(c, x0, 14, x0 + 3, h - 2, "velvet"); R(c, x0, 14, x0 + 3, 14, "gold")
    R(c, 5, sy, 20, sy, "velvet_l"); R(c, 5, sy + 1, 20, h - 2, "velvet"); R(c, 1, h - 1, 24, h - 1, "gold_d")


@item("l3_secretary_desk", "秘書桌", C1, 2, 36, 26, level=LV, note="桌上有墨水、公文與一枝羽毛筆")
def _(c, f):
    table(c, 1, 8, 34, 25, "wood", depth=3)
    R(c, 3, 13, 13, 23, "wood"); R(c, 3, 13, 13, 13, "wood_d"); drawers(c, 4, 14, 12, 22, 3, "wood")
    R(c, 18, 14, 31, 22, "wood_x")
    R(c, 5, 4, 12, 7, "paper"); R(c, 6, 5, 11, 5, "ink"); R(c, 22, 2, 23, 6, "white"); R(c, 26, 4, 30, 7, "black"); R(c, 27, 3, 29, 4, "blue_l")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_document_shelf", "文件架", C2, 2, 32, 38, level=LV)
def _(c, f):
    box(c, 1, 1, 30, 36, "steel", "steel_l", "steel_d")
    for i, y in enumerate((3, 12, 21, 30)):
        R(c, 3, y, 28, y + 6, "steel_d"); R(c, 3, y + 7, 28, y + 7, "steel_l")
        for x in range(4, 28, 3):
            R(c, x, y + 1 + (x % 2), x + 1, y + 6, ["red", "blue", "green", "paper"][(x // 3 + i) % 4])
    R(c, 2, 37, 6, 37, "iron_d"); R(c, 25, 37, 29, 37, "iron_d")


@item("l3_projector_cabinet", "水晶投影櫃", C2, 2, 30, 32, level=LV, note="裡面放著開會用的大水晶")
def _(c, f):
    box(c, 1, 8, 28, 31, "dark", "dark_l", "dark_d")
    R(c, 3, 10, 26, 20, "black"); R(c, 4, 11, 25, 19, "iron_d")
    circle(c, 14.5, 15, 4, "glass_d"); circle(c, 14.5, 15, 3, "glass"); c.put(13, 14, "white")
    drawers(c, 3, 22, 26, 30, 2, "dark", "gold")
    R(c, 12, 4, 17, 7, "iron"); circle(c, 14.5, 3, 2, "glass"); R(c, 13, 6, 16, 7, "iron_d")


@item("l3_display_case", "展示櫃", C2, 2, 28, 36, level=LV)
def _(c, f):
    frame_border(c, 1, 1, 26, 34, "wood")
    R(c, 3, 3, 24, 32, "glass"); R(c, 3, 3, 5, 32, "white")
    for y in (13, 23):
        R(c, 3, y, 24, y + 1, "wood")
    R(c, 6, 8, 9, 12, "gold"); R(c, 6, 8, 9, 8, "gold_l"); R(c, 13, 6, 20, 12, "red_d"); R(c, 14, 7, 19, 7, "gold")
    circle(c, 8, 18, 2, "glass_d"); R(c, 14, 15, 20, 22, "purple"); R(c, 15, 16, 19, 17, "purple_l")
    R(c, 6, 27, 11, 32, "steel"); R(c, 14, 27, 21, 32, "bronze")


@item("l3_coat_rack", "衣帽架", C2, 1, 18, 36, level=LV)
def _(c, f):
    R(c, 8, 3, 9, 32, "wood_d"); R(c, 8, 3, 8, 32, "wood")
    for y, dx in ((6, -1), (10, 1), (14, -1)):
        R(c, 8 + dx * 3, y, 8 + dx * 6, y, "wood_d"); c.put(8 + dx * 6, y - 1, "gold")
    R(c, 2, 8, 6, 20, "navy_cloth"); R(c, 2, 8, 6, 8, "navy_cloth_l"); R(c, 11, 12, 15, 24, "leather"); R(c, 11, 12, 15, 12, "leather_l")
    R(c, 5, 32, 12, 34, "wood_x"); R(c, 2, 34, 15, 35, "wood_d")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_name_plate", "名牌", C3, 1, 14, 10, level=LV)
def _(c, f):
    R(c, 1, 3, 12, 7, "gold_d"); R(c, 1, 3, 12, 3, "gold"); R(c, 2, 4, 11, 6, "wood_x")
    for x in (3, 5, 7, 9):
        c.put(x, 5, "gold_l")
    R(c, 2, 8, 11, 8, "wood_d")


@item("l3_crystal_pointer", "水晶指揮棒", C3, 1, 14, 16, level=LV)
def _(c, f):
    for i in range(10):
        c.put(2 + i, 12 - i, "wood_d"); c.put(3 + i, 12 - i, "wood")
    circle(c, 12, 3, 2.4, "glass_d"); circle(c, 12, 3, 1.6, "glass"); c.put(11, 2, "white")
    R(c, 1, 13, 4, 14, "gold")


@item("l3_minutes_book", "會議記錄本", C3, 1, 16, 12, level=LV)
def _(c, f):
    R(c, 2, 4, 13, 9, "navy_cloth"); R(c, 2, 4, 13, 4, "navy_cloth_l"); R(c, 13, 5, 13, 9, "navy_cloth_d"); R(c, 3, 10, 12, 10, "paper_d")
    R(c, 5, 5, 10, 8, "gold_d"); R(c, 6, 6, 9, 7, "gold"); R(c, 11, 1, 12, 5, "white"); c.put(11, 1, "red_l")


@item("l3_water_set", "水壺與杯", C3, 1, 18, 14, level=LV)
def _(c, f):
    R(c, 3, 3, 8, 11, "glass_d"); R(c, 4, 4, 7, 11, "water"); R(c, 4, 4, 7, 4, "water_l"); R(c, 4, 1, 7, 2, "glass"); R(c, 8, 5, 10, 6, "glass_d")
    for x in (11, 15):
        R(c, x, 8, x + 2, 11, "glass_d"); R(c, x + 1, 9, x + 1, 11, "water")
    R(c, 2, 12, 16, 12, "wood_d")


@item("l3_timer_hourglass", "計時沙漏", C3, 1, 14, 18, 2, 2, level=LV, note="一小時一小時地流")
def _(c, f):
    R(c, 2, 1, 11, 2, "wood"); R(c, 2, 15, 11, 16, "wood"); R(c, 3, 2, 3, 15, "wood_d"); R(c, 10, 2, 10, 15, "wood_d")
    for r in range(6):
        R(c, 4 + r // 2, 3 + r, 9 - r // 2, 3 + r, "glass"); R(c, 4 + (5 - r) // 2, 9 + r, 9 - (5 - r) // 2, 9 + r, "glass")
    R(c, 5, 3 + (1 if f else 0), 8, 5, "f1"); R(c, 6, 13 - (1 if f else 0), 7, 14, "f1"); R(c, 6, 8, 7, 9, "f1")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_projector_crystal", "投影水晶燈", C4, 1, 18, 28, 3, 3, level=LV, note="把光投到牆上的水晶")
def _(c, f):
    R(c, 5, 22, 12, 24, "iron_d"); R(c, 6, 20, 11, 21, "iron"); R(c, 8, 15, 9, 20, "iron_d")
    circle(c, 8.5, 10, 5.4, "purple_d", 5.4); circle(c, 8.5, 10, 4.4, "purple", 4.4); circle(c, 8.5, 10, 2.6, "glass", 2.6); c.put(6, 7, "white")
    for i in range(3):
        c.put(13 + i + f, 7 - i, "f1"); c.put(14 + i + f, 8 - i, "f4")
    R(c, 3, 25, 14, 26, "iron_d")


@item("l3_meeting_chandelier", "會議吊燈", C4, 4, 46, 24, 2, 3, level=LV, ceiling=True)
def _(c, f):
    R(c, 22, 0, 23, 5, "iron_d"); R(c, 4, 6, 41, 8, "iron"); R(c, 4, 6, 41, 6, "iron_l")
    for x in (6, 14, 22, 30, 38):
        R(c, x, 3, x + 1, 6, "cloth"); flame(c, x, 2, 3, f + x, 0)
        R(c, x, 9, x, 13, "iron_d")
        circle(c, x, 15, 2.4, "glass_d"); circle(c, x, 15, 1.6, "glass")
    R(c, 20, 9, 25, 11, "gold"); R(c, 21, 12, 24, 20, "gold_d"); circle(c, 22.5, 21, 2, "gold_l")


@item("l3_wall_lamps", "對稱壁燈", C4, 1, 24, 18, 2, 3, level=LV, wall=True)
def _(c, f):
    R(c, 11, 3, 12, 9, "iron_d")
    for x0 in (2, 16):
        R(c, x0 + 1, 8, x0 + 5, 12, "iron"); R(c, x0 + 1, 8, x0 + 5, 8, "iron_l"); R(c, x0 + 2, 5, x0 + 4, 7, "cloth"); flame(c, x0 + 3, 4, 3, f + x0, 0)
        R(c, x0 + 3, 13, x0 + 3, 15, "iron_d")
    R(c, 5, 9, 18, 10, "iron")


@item("l3_floor_lamp", "落地燈", C4, 1, 16, 40, 2, 3, level=LV)
def _(c, f):
    for r in range(8):
        R(c, 3 + r // 2, 2 + r, 12 - r // 2, 2 + r, "cloth" if r % 2 else "paper")
    R(c, 3, 9, 12, 9, "cloth_d"); R(c, 4, 10, 11, 12, "f1" if f else "f2")
    R(c, 7, 11, 8, 35, "bronze_d"); R(c, 7, 11, 7, 35, "bronze"); R(c, 4, 36, 11, 38, "bronze"); R(c, 4, 36, 11, 36, "bronze_l"); R(c, 3, 39, 12, 39, "bronze_d")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_whiteboard", "大白板", C5, 2, 36, 26, level=LV, wall=True)
def _(c, f):
    frame_border(c, 1, 1, 34, 22, "steel")
    R(c, 3, 3, 32, 20, "board_w"); R(c, 3, 20, 32, 20, "board_w_d")
    R(c, 5, 5, 16, 5, "marker_b"); R(c, 5, 8, 12, 8, "marker_b"); R(c, 5, 11, 18, 11, "marker_b")
    R(c, 21, 5, 29, 5, "marker_r"); R(c, 22, 6, 22, 13, "marker_r"); R(c, 26, 7, 26, 13, "marker_r"); R(c, 21, 15, 29, 15, "marker_r")
    R(c, 6, 21, 10, 22, "marker_r"); R(c, 12, 21, 15, 22, "marker_b"); R(c, 24, 21, 31, 22, "steel_d")


@item("l3_big_map", "大幅地圖", C5, 4, 50, 30, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 48, 28, "wood_d"); R(c, 3, 3, 46, 26, "parch")
    for x, y, w, h, k in ((6, 6, 12, 9, "grass"), (22, 5, 14, 10, "grass_d"), (30, 15, 12, 8, "grass"), (8, 17, 14, 7, "sand" if False else "straw")):
        R(c, x, y, x + w, y + h, k); R(c, x, y, x + w, y, k + "_d" if k + "_d" in P else k)
    R(c, 18, 10, 24, 12, "water_l"); R(c, 22, 15, 29, 17, "water_l")
    c.cells([(10, 9), (26, 8), (34, 18), (13, 20)], "red"); c.cells([(11, 9), (27, 8), (35, 18), (14, 20)], "red_d")
    for i in range(6):
        c.put(12 + i * 4, 14 + (i % 2) * 5, "ink")
    R(c, 40, 5, 44, 5, "ink"); R(c, 42, 3, 42, 8, "ink")


@item("l3_org_chart", "組織圖", C5, 2, 34, 26, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 32, 24, "wood"); R(c, 3, 3, 30, 22, "parch")
    R(c, 12, 5, 21, 8, "gold"); R(c, 12, 5, 21, 5, "gold_l")
    R(c, 16, 9, 17, 11, "ink"); R(c, 6, 11, 27, 11, "ink")
    for x in (6, 16, 26):
        R(c, x, 11, x, 13, "ink"); R(c, x - 3, 14, x + 4, 17, "blue"); R(c, x - 3, 14, x + 4, 14, "blue_l")
    for x in (3, 9, 13, 19, 23, 29):
        R(c, x, 19, x + 1, 21, "wood_d")


@item("l3_charter", "公會憲章", C5, 2, 28, 32, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 26, 2, "wood_l"); R(c, 3, 3, 24, 28, "parch"); R(c, 3, 3, 24, 3, "parch_d"); R(c, 24, 4, 24, 28, "parch_d")
    R(c, 1, 29, 26, 30, "wood_l"); R(c, 0, 0, 1, 31, "wood_d") if False else None
    for y in range(6, 22, 3):
        R(c, 6, y, 21 - (y % 5), y, "ink")
    R(c, 14, 22, 21, 22, "ink"); circle(c, 8, 25, 2.2, "red_d"); circle(c, 8, 25, 1.4, "red")
    R(c, 5, 0, 22, 0, "rope")


@item("l3_big_clock", "大時鐘", C5, 1, 22, 22, 2, 1, level=LV, wall=True)
def _(c, f):
    circle(c, 10.5, 10.5, 10, "wood_d"); circle(c, 10.5, 10.5, 8.6, "paper"); circle(c, 10.5, 10.5, 8.2, "cloth")
    for i in range(12):
        a = i * math.pi / 6
        c.put(round(10 + math.cos(a) * 7), round(10 + math.sin(a) * 7), "ink")
    for r in range(5):
        c.put(10, 10 - r, "ink")
    for r in range(7):
        c.put(10 + (r if f == 0 else 0), 10 + (0 if f == 0 else -r), "ink")
    c.put(10, 10, "red")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_long_rug", "長會議地毯", C6, 4, 50, 28, level=LV, flat=True)
def _(c, f):
    rug_base(c, 50, 28, "navy_cloth", "gold", "navy_cloth_d")
    for x in range(6, 46, 8):
        c.cells([(x, 13), (x + 1, 12), (x + 2, 13), (x + 1, 14), (x + 1, 13)], "gold")
    R(c, 4, 6, 45, 6, "navy_cloth_l"); R(c, 4, 21, 45, 21, "navy_cloth_l")


@item("l3_round_council_rug", "議事圓毯", C6, 4, 44, 32, level=LV, flat=True)
def _(c, f):
    circle(c, 21.5, 15.5, 21, "gold_d", 15); circle(c, 21.5, 15.5, 19.6, "velvet", 13.8); circle(c, 21.5, 15.5, 13, "velvet_d", 9.4)
    circle(c, 21.5, 15.5, 11, "velvet", 7.8); circle(c, 21.5, 15.5, 4.4, "gold", 3.2); circle(c, 21.5, 15.5, 2.6, "velvet_d", 1.8)
    for i in range(12):
        a = i * math.pi / 6
        c.put(round(21 + math.cos(a) * 16), round(15 + math.sin(a) * 11), "gold")


@item("l3_blue_rug", "藍色菱格地毯", C6, 2, 34, 26, level=LV, flat=True)
def _(c, f):
    rug_base(c, 34, 26, "navy_cloth", "cloth", None, True)
    for i in range(3):
        R(c, 8 + i * 5, 7 + i * 3, 25 - i * 5, 18 - i * 3, "navy_cloth_l" if i % 2 == 0 else "cloth")
    R(c, 14, 11, 19, 14, "gold")


@item("l3_entry_mat", "入口地墊", C6, 1, 26, 14, level=LV, flat=True)
def _(c, f):
    R(c, 1, 1, 24, 12, "brown"); R(c, 2, 2, 23, 11, "straw_d")
    for x in range(3, 23, 2):
        R(c, x, 3, x, 10, "straw")
    R(c, 7, 5, 18, 8, "red_d"); R(c, 8, 6, 17, 7, "gold")


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_big_potted", "室內大盆栽", C7, 2, 26, 42, level=LV)
def _(c, f):
    blob(c, 13, 14, 12, "green", "green_d", "green_l", 13)
    for x, y, w in ((5, 20, 3), (20, 22, 3), (13, 26, 3)):
        blob(c, x, y, w, "green", "green_d", "green_l")
    R(c, 12, 26, 13, 32, "wood_d")
    R(c, 6, 33, 19, 40, "stone_l"); R(c, 6, 33, 19, 34, "stone"); R(c, 19, 35, 19, 40, "stone_d"); R(c, 7, 40, 18, 41, "stone_d")


@item("l3_dracaena", "龍血樹", C7, 2, 22, 42, level=LV)
def _(c, f):
    R(c, 10, 14, 11, 33, "wood_d"); R(c, 10, 14, 10, 33, "wood")
    for dx, dy, l in ((-1, 0, 8), (1, 0, 8), (-1, -3, 7), (1, -3, 7), (0, -5, 5)):
        for i in range(l):
            c.put(10 + dx * (i + 1) * 1 if False else 10 + dx * (i + 1), 14 + dy + (i // 2), "green" if i % 2 else "green_d")
    circle(c, 10.5, 12, 6, "green_d", 5); circle(c, 10.2, 11.6, 5, "green", 4.4); c.cells([(7, 8), (13, 9), (10, 6)], "green_l")
    R(c, 5, 34, 16, 40, "pot"); R(c, 5, 34, 16, 35, "pot_d"); R(c, 16, 36, 16, 40, "pot_d")


@item("l3_desk_greens", "桌面小盆栽組", C7, 1, 20, 14, level=LV)
def _(c, f):
    for x, h in ((3, 6), (9, 8), (15, 5)):
        pot(c, x + 1, 12, 5, 4, "pot"); R(c, x, 12 - 4 - h, x + 2, 12 - 4, "green"); R(c, x + 1, 12 - 4 - h - 1, x + 1, 12 - 4 - h, "green_l")
    R(c, 1, 13, 18, 13, "wood_d")


@item("l3_hanging_plant", "吊蘭", C7, 1, 18, 26, level=LV, ceiling=True)
def _(c, f):
    R(c, 8, 0, 9, 6, "rope")
    R(c, 3, 6, 14, 11, "pot"); R(c, 3, 6, 14, 7, "pot_d"); R(c, 13, 8, 14, 11, "pot_d")
    for i, (x, l) in enumerate(((3, 12), (5, 16), (8, 18), (11, 15), (14, 11))):
        R(c, x, 11, x, 11 + l, "green"); R(c, x + 1, 12, x + 1, 11 + l - 3, "green_d"); c.put(x, 12 + l, "green_l")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_big_trophy", "冠軍大獎盃", C8, 2, 24, 36, level=LV)
def _(c, f):
    plinth(c, 3, 20, 28, 35)
    R(c, 8, 18, 15, 27, "gold"); R(c, 10, 14, 13, 18, "gold_d")
    for r in range(11):
        R(c, 5 + r // 3, 3 + r, 18 - r // 3, 3 + r, "gold" if r % 2 == 0 else "gold_d")
    R(c, 18, 5, 21, 6, "gold"); R(c, 20, 6, 21, 11, "gold"); R(c, 2, 5, 5, 6, "gold"); R(c, 2, 6, 3, 11, "gold")
    c.cells([(8, 5), (8, 6), (9, 7)], "gold_l"); R(c, 9, 30, 14, 32, "gold_l")


@item("l3_hero_bust", "英雄半身像", C8, 1, 20, 32, level=LV)
def _(c, f):
    plinth(c, 3, 16, 22, 31)
    circle(c, 9.5, 9, 4.8, "bronze_l", 5.6); R(c, 5, 4, 14, 6, "bronze_d"); c.cells([(7, 9), (12, 9)], "bronze_d"); R(c, 8, 12, 11, 13, "bronze_d")
    R(c, 4, 15, 15, 21, "bronze"); R(c, 15, 16, 15, 21, "bronze_d"); R(c, 6, 15, 13, 16, "bronze_l")
    R(c, 6, 26, 13, 27, "gold")


@item("l3_dragon_slayer", "屠龍者雕像", C8, 4, 40, 48, level=LV)
def _(c, f):
    plinth(c, 3, 36, 38, 47)
    R(c, 24, 20, 36, 37, "green_d"); circle(c, 31, 20, 6, "green_d", 5); R(c, 28, 17, 30, 18, "gold"); R(c, 34, 24, 38, 28, "green")   # the dragon beaten down
    circle(c, 13, 9, 4, "stone_l"); R(c, 9, 14, 17, 32, "stone"); R(c, 17, 14, 17, 32, "stone_d")
    R(c, 18, 4, 19, 28, "steel_l"); R(c, 16, 28, 21, 29, "gold"); R(c, 6, 15, 8, 26, "stone_d")
    R(c, 10, 33, 12, 37, "stone_d"); R(c, 14, 33, 16, 37, "stone")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_vote_box", "投票箱", C9, 1, 16, 22, level=LV)
def _(c, f):
    box(c, 2, 6, 13, 19, "wood", "wood_l", "wood_d"); R(c, 4, 4, 11, 5, "wood_x"); R(c, 5, 4, 10, 4, "black")
    R(c, 4, 9, 11, 14, "paper"); R(c, 5, 10, 10, 10, "ink"); R(c, 5, 12, 9, 12, "ink"); R(c, 6, 1, 8, 3, "paper"); R(c, 3, 20, 12, 21, "wood_x")


@item("l3_lounge_couch", "討論沙發", C9, 4, 46, 28, level=LV, seat=True)
def _(c, f):
    h = 28
    sy = h - 1 - SEAT_UP
    R(c, 6, 3, 39, sy, "navy_cloth"); R(c, 6, 3, 39, 3, "navy_cloth_l"); R(c, 22, 5, 23, sy - 2, "navy_cloth_d"); R(c, 14, 5, 14, sy - 2, "navy_cloth_d"); R(c, 31, 5, 31, sy - 2, "navy_cloth_d")
    for x0 in (1, 40):
        R(c, x0, 11, x0 + 4, h - 2, "navy_cloth"); R(c, x0, 11, x0 + 4, 11, "navy_cloth_l")
    R(c, 6, sy, 39, sy, "navy_cloth_l"); R(c, 6, sy + 1, 39, h - 2, "navy_cloth"); R(c, 1, h - 1, 44, h - 1, "wood_d")
    c.cells([(10, 8), (35, 8)], "gold")


@item("l3_war_table", "戰棋沙盤", C9, 2, 36, 28, level=LV, note="擺著小旗和小兵的戰棋沙盤")
def _(c, f):
    table(c, 1, 9, 34, 27, "dark", depth=4)
    R(c, 3, 9, 32, 14, "grass"); R(c, 3, 9, 32, 9, "grass_d"); R(c, 32, 10, 32, 14, "grass_d")
    R(c, 8, 11, 14, 13, "water"); R(c, 20, 10, 26, 12, "stone")
    for x, y, k in ((6, 6, "red"), (11, 7, "red"), (24, 6, "blue"), (28, 7, "blue")):
        R(c, x, y, x + 1, y + 3, k); c.put(x, y - 1, "skin")
    R(c, 16, 3, 16, 9, "wood_d"); R(c, 17, 3, 20, 5, "lred" if False else "red")


@item("l3_jukebox", "魔法點唱機", C9, 2, 26, 34, 3, 3, level=LV)
def _(c, f):
    R(c, 3, 8, 22, 31, "velvet"); R(c, 3, 8, 22, 8, "velvet_l"); circle(c, 12.5, 9, 9.4, "velvet", 7); R(c, 3, 8, 3, 31, "gold_d"); R(c, 22, 8, 22, 31, "gold_d")
    R(c, 6, 11, 19, 21, "black"); circle(c, 12.5, 14, 5, "rune_d", 3.2)
    for i in range(6):
        c.put(7 + i * 2, 20, ["rune", "f1", "pink", "blue_l", "green_l", "f2"][(i + f) % 6])
    R(c, 6, 24, 19, 28, "gold_d"); R(c, 8, 25, 17, 27, "gold")
    for x, y in (([22, 4], [24, 2]) if f == 1 else ([23, 3], [21, 1]) if f == 2 else ([24, 4], [22, 2])):
        c.put(x, y, "f1"); c.put(x, y + 1, "f1")
    R(c, 3, 32, 22, 33, "wood_x")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_tea_trolley", "茶水推車", C10, 2, 30, 28, level=LV)
def _(c, f):
    R(c, 2, 8, 27, 9, "steel"); R(c, 2, 18, 27, 19, "steel"); legs(c, (3, 26), 10, 23, "steel_d")
    R(c, 2, 8, 27, 8, "steel_l")
    R(c, 5, 3, 10, 7, "teal"); R(c, 10, 4, 12, 5, "teal"); R(c, 6, 2, 9, 2, "teal_d"); R(c, 15, 5, 17, 7, "cloth"); R(c, 19, 5, 21, 7, "cloth"); R(c, 22, 4, 26, 7, "wood")
    R(c, 5, 13, 24, 17, "cloth_d"); R(c, 7, 14, 12, 16, "straw"); R(c, 15, 14, 22, 16, "pink")
    circle(c, 6, 25, 2.4, "iron_d"); circle(c, 23, 25, 2.4, "iron_d"); R(c, 26, 3, 27, 18, "steel_d")


@item("l3_big_cooler", "大飲水機", C10, 1, 20, 34, 3, 3, level=LV)
def _(c, f):
    box(c, 3, 12, 16, 31, "steel", "steel_l", "steel_d")
    circle(c, 9.5, 8, 6, "glass_d", 7); circle(c, 9.5, 8, 5, "water", 6); R(c, 5, 5, 6, 7, "water_l")
    R(c, 7, 17, 12, 19, "black"); R(c, 7, 20, 8, 21, "blue"); R(c, 11, 20, 12, 21, "red")
    R(c, 6, 24, 13, 27, "steel_d"); R(c, 4, 32, 15, 33, "steel_d")
    for x, y in [[(8, 3), (11, 1)], [(10, 2), (7, 4)], [(9, 4), (12, 3)]][f]:
        c.put(x, y, "water_l")


@item("l3_snack_stand", "點心架", C10, 2, 26, 32, level=LV)
def _(c, f):
    R(c, 12, 2, 13, 28, "wood_d")
    for y, w in ((6, 9), (14, 11), (22, 12)):
        R(c, 12 - w, y, 13 + w, y + 1, "cloth"); R(c, 12 - w, y, 13 + w, y, "white")
    for x, k in ((5, "pink"), (9, "straw"), (15, "red_l"), (19, "straw_d")):
        circle(c, x, 3, 2, k)
    for x, k in ((3, "straw"), (8, "pink"), (14, "gold"), (19, "straw"), (22, "red_l")):
        circle(c, x, 11, 2, k)
    for x, k in ((2, "straw_d"), (8, "straw"), (14, "pink"), (20, "gold")):
        R(c, x, 17, x + 3, 21, k)
    R(c, 6, 28, 19, 30, "wood"); R(c, 6, 28, 19, 28, "wood_l"); R(c, 4, 30, 21, 31, "wood_d")


@item("l3_coffee_bar", "咖啡吧台", C10, 2, 34, 30, level=LV)
def _(c, f):
    R(c, 1, 12, 32, 15, "wood_l"); R(c, 1, 12, 32, 12, "straw"); R(c, 2, 16, 31, 28, "dark"); R(c, 2, 16, 31, 16, "dark_d")
    for x in range(4, 30, 6):
        R(c, x, 18, x + 4, 26, "dark_d")
    R(c, 3, 3, 12, 11, "steel"); R(c, 3, 3, 12, 3, "steel_l"); R(c, 5, 5, 10, 7, "black"); R(c, 7, 8, 8, 11, "brown")
    R(c, 17, 7, 20, 11, "cloth"); R(c, 21, 8, 22, 9, "cloth"); R(c, 25, 7, 28, 11, "cloth"); R(c, 17, 7, 20, 7, "brown")
    R(c, 1, 29, 32, 29, "wood_x")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_glass_partition", "玻璃隔間", C11, 2, 38, 36, level=LV)
def _(c, f):
    for x0 in (1, 14, 27):
        frame_border(c, x0, 3, x0 + 10, 31, "steel")
        R(c, x0 + 2, 5, x0 + 8, 29, "glass"); R(c, x0 + 2, 5, x0 + 3, 29, "white"); R(c, x0 + 7, 8, x0 + 8, 12, "white")
    R(c, 1, 32, 36, 34, "steel_d"); R(c, 1, 32, 36, 32, "steel")


@item("l3_council_door", "議事廳大門", C11, 4, 44, 48, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 42, 46, "stone"); R(c, 1, 1, 42, 3, "stone_l"); R(c, 3, 5, 40, 46, "dark_d")
    for r in range(8):
        R(c, 5 + r, 4 - r // 2, 38 - r, 5, "stone") if False else None
    R(c, 5, 7, 20, 46, "dark"); R(c, 23, 7, 38, 46, "dark")
    for x0 in (6, 24):
        for y0 in (9, 28):
            R(c, x0, y0, x0 + 12, y0 + 15, "dark_l"); R(c, x0 + 1, y0 + 1, x0 + 11, y0 + 14, "dark")
    R(c, 21, 7, 22, 46, "iron_d"); circle(c, 18, 28, 1.8, "gold"); circle(c, 25, 28, 1.8, "gold")
    R(c, 14, 1, 29, 5, "gold"); R(c, 19, 2, 24, 4, "velvet")


@item("l3_heavy_curtain", "厚重窗簾", C11, 2, 36, 38, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 34, 3, "gold_d"); R(c, 1, 1, 34, 1, "gold")
    R(c, 5, 4, 30, 28, "sky"); R(c, 5, 4, 30, 8, "sky_d"); R(c, 5, 22, 30, 28, "grass")
    for x0, x1 in ((1, 8), (27, 34)):
        R(c, x0, 4, x1, 36, "velvet")
        for x in range(x0 + 1, x1, 2):
            R(c, x, 5, x, 35, "velvet_d")
        R(c, x0, 4, x1, 4, "velvet_l")
    R(c, 8, 20, 9, 21, "gold"); R(c, 26, 20, 27, 21, "gold")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_balcony_chairs", "陽台椅組", C12, 2, 34, 24, level=LV)
def _(c, f):
    for x0 in (2, 22):
        R(c, x0, 6, x0 + 9, 14, "wood"); R(c, x0, 6, x0 + 9, 6, "wood_l"); [R(c, x, 7, x, 13, "wood_d") for x in (x0 + 2, x0 + 5, x0 + 8)]
        R(c, x0, 14, x0 + 9, 15, "wood_l"); legs(c, (x0 + 1, x0 + 8), 16, 21); R(c, x0 - 1, 21, x0 + 10, 21, "wood_x")
    R(c, 13, 13, 20, 14, "wood_l"); R(c, 14, 15, 14, 21, "wood_d"); R(c, 19, 15, 19, 21, "wood_d"); circle(c, 16.5, 11, 1.6, "teal_l")


@item("l3_balustrade", "石欄杆", C12, 2, 40, 22, level=LV)
def _(c, f):
    R(c, 1, 3, 38, 5, "stone_l"); R(c, 1, 3, 38, 3, "marble"); R(c, 1, 18, 38, 20, "stone"); R(c, 1, 20, 38, 20, "stone_d")
    for x in range(3, 37, 5):
        R(c, x, 6, x + 2, 17, "stone"); R(c, x, 6, x, 17, "stone_l"); R(c, x + 2, 6, x + 2, 17, "stone_d"); R(c, x + 1, 9, x + 1, 13, "stone_l")
    for x in (1, 36):
        R(c, x, 0, x + 2, 20, "stone"); R(c, x, 0, x + 2, 1, "stone_l")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l3_pigeon", "信鴿", C13, 1, 18, 20, 3, 3, level=LV, note="腳上綁著小信筒的信鴿")
def _(c, f):
    circle(c, 8, 12, 5, "cloth_d", 4); circle(c, 7.6, 11.6, 4.2, "cloth", 3.4); R(c, 3, 11, 6, 15, "stone_l")
    circle(c, 13, 6, 2.8, "cloth", 2.8); R(c, 15, 6, 16, 7, "orange"); c.put(13, 5, "black"); R(c, 11, 8, 14, 9, "green_l")
    wing = [(2, 9), (1, 7)] if f == 1 else [(2, 11), (1, 12)]
    c.cells(wing, "stone_l"); R(c, 7, 17, 7, 18, "pink"); R(c, 10, 17, 10, 18, "pink"); R(c, 7, 16, 8, 16, "red_d")


@item("l3_clerk_golem", "書記小魔偶", C13, 1, 20, 26, 3, 3, level=LV, note="拿著羽毛筆抄寫的小魔偶")
def _(c, f):
    R(c, 5, 6, 14, 14, "stone"); R(c, 5, 6, 14, 6, "stone_l"); R(c, 14, 7, 14, 14, "stone_d")
    R(c, 7, 9, 8, 10, "rune"); R(c, 11, 9, 12, 10, "rune"); R(c, 8, 12, 11, 12, "stone_x")
    R(c, 4, 15, 15, 22, "stone_d"); R(c, 4, 15, 15, 15, "stone"); R(c, 7, 17, 12, 20, "parch")
    R(c, 6, 23, 8, 25, "stone_x"); R(c, 11, 23, 13, 25, "stone_x")
    x = 16 + (1 if f == 1 else 0)
    R(c, 14, 17, x + 1, 18, "stone"); R(c, x, 12, x, 18, "white"); c.put(x, 11, "red_l"); R(c, 9, 21, 12, 21, "ink") if f else None


@item("l3_flying_papers", "飛舞的文件", C13, 1, 22, 24, 4, 4, level=LV, note="自己飄來飄去的紙張")
def _(c, f):
    pts = [[(3, 14), (9, 8), (15, 13)], [(4, 12), (10, 6), (16, 12)], [(5, 10), (11, 5), (15, 10)], [(4, 12), (10, 7), (14, 14)]][f]
    for n, (x, y) in enumerate(pts):
        R(c, x, y, x + 5, y + 6, "paper"); R(c, x, y, x + 5, y, "white"); R(c, x + 5, y + 1, x + 5, y + 6, "paper_d")
        R(c, x + 1, y + 2, x + 4, y + 2, "ink"); R(c, x + 1, y + 4, x + 3, y + 4, "ink")
    c.cells([(2, 20), (18, 19), (11, 21)], "f1" if f % 2 else "f4")
