"""Guild level 6 unlocks: the training ground (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 6
add_colors({"sand": (226, 200, 150), "sand_d": (190, 162, 112), "sand_l": (244, 226, 184), "arena": (150, 60, 50), "arena_d": (110, 40, 36), "horse": (150, 100, 60), "horse_d": (110, 70, 40), "horse_l": (190, 140, 90),
            "hawk": (150, 110, 70), "hawk_d": (100, 70, 44), })


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_commander_desk", "指揮官桌", C1, 2, 38, 28, level=LV, note="攤著戰術圖的粗木桌")
def _(c, f):
    table(c, 1, 9, 36, 27, "dark", depth=3)
    R(c, 3, 14, 12, 25, "dark_d"); R(c, 24, 14, 34, 25, "dark_d"); drawers(c, 4, 15, 11, 24, 2, "dark", "iron_l")
    R(c, 6, 4, 18, 8, "parch"); R(c, 7, 5, 12, 5, "red"); R(c, 13, 6, 17, 6, "ink"); R(c, 22, 3, 26, 8, "steel"); R(c, 23, 2, 25, 3, "steel_l"); R(c, 29, 5, 33, 8, "wood")


@item("l6_training_bench", "訓練場長椅", C1, 2, 36, 20, level=LV, seat=True)
def _(c, f):
    h = 20
    sy = h - 1 - SEAT_UP
    R(c, 2, sy - 1, 33, sy + 2, "wood_l"); R(c, 2, sy - 1, 33, sy - 1, "straw"); R(c, 2, sy + 2, 33, sy + 2, "wood_d")
    legs(c, (4, 5, 30, 31), sy + 3, h - 1, "wood_x"); R(c, 3, 8, 3, sy - 2, "wood_d"); R(c, 32, 8, 32, sy - 2, "wood_d")
    R(c, 3, 8, 32, 9, "wood")


@item("l6_barrel_stool", "桶凳", C1, 1, 16, 16, level=LV, seat=True)
def _(c, f):
    h = 16
    sy = h - 1 - SEAT_UP
    R(c, 2, sy, 13, h - 2, "wood"); R(c, 2, sy, 13, sy, "wood_l"); R(c, 13, sy + 1, 13, h - 2, "wood_d")
    R(c, 2, sy + 2, 13, sy + 2, "iron_d"); R(c, 2, h - 3, 13, h - 3, "iron_d"); R(c, 3, h - 1, 12, h - 1, "wood_x")
    for x in (5, 8, 11):
        R(c, x, sy + 1, x, h - 2, "wood_d")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_weapon_locker", "武器櫃", C2, 2, 30, 40, level=LV)
def _(c, f):
    box(c, 1, 1, 28, 38, "iron_d", "iron", "black")
    R(c, 3, 3, 26, 20, "black")
    for x in (6, 11, 16, 21):
        R(c, x, 4, x, 18, "steel_l"); R(c, x - 1, 4, x + 1, 5, "wood_d")
    R(c, 3, 22, 26, 36, "iron"); R(c, 3, 22, 26, 22, "iron_l"); R(c, 7, 27, 22, 29, "iron_d"); circle(c, 14.5, 32, 1.4, "gold_d")
    R(c, 1, 39, 28, 39, "iron_d")


@item("l6_shield_rack", "盾牌架", C2, 2, 36, 30, level=LV)
def _(c, f):
    R(c, 1, 24, 34, 27, "wood_d"); R(c, 1, 24, 34, 24, "wood"); R(c, 3, 27, 4, 28, "wood_x"); R(c, 31, 27, 32, 28, "wood_x")
    for n, x in enumerate((3, 12, 21, 30 - 3)):
        k, kd = [("red", "red_d"), ("blue", "blue_d"), ("gold", "gold_d"), ("green", "green_d")][n]
        circle(c, x + 3, 13, 6, kd, 8); circle(c, x + 3, 13, 5, k, 7); R(c, x + 3, 5, x + 3, 21, kd); circle(c, x + 3, 13, 1.6, "steel_l")


@item("l6_spear_rack", "長槍架", C2, 2, 32, 40, level=LV)
def _(c, f):
    R(c, 2, 34, 29, 37, "wood_d"); R(c, 2, 34, 29, 34, "wood"); R(c, 4, 37, 6, 38, "wood_x"); R(c, 25, 37, 27, 38, "wood_x")
    for n, x in enumerate(range(5, 28, 4)):
        R(c, x, 8 - (n % 2) * 2, x, 34, "wood_l"); R(c, x + 1, 9 - (n % 2) * 2, x + 1, 34, "wood")
        R(c, x - 1, 4 - (n % 2) * 2, x + 2, 8 - (n % 2) * 2, "steel"); c.put(x, 3 - (n % 2) * 2, "steel_l")
    R(c, 2, 20, 29, 21, "wood_d")


@item("l6_armor_stands", "盔甲展示組", C2, 4, 46, 44, level=LV)
def _(c, f):
    for x0 in (3, 17, 31):
        R(c, x0 + 4, 4, x0 + 9, 11, "steel"); R(c, x0 + 4, 4, x0 + 9, 4, "steel_l"); R(c, x0 + 4, 8, x0 + 9, 8, "black"); R(c, x0 + 6, 1, x0 + 7, 4, "red")
        R(c, x0 + 1, 12, x0 + 12, 26, "steel"); R(c, x0 + 12, 13, x0 + 12, 26, "steel_d"); R(c, x0 + 1, 12, x0 + 12, 13, "steel_l")
        R(c, x0 + 3, 27, x0 + 5, 36, "steel_d"); R(c, x0 + 8, 27, x0 + 10, 36, "steel"); R(c, x0 + 6, 13, x0 + 7, 36, "wood_d")
        R(c, x0 + 1, 37, x0 + 12, 39, "wood_d"); R(c, x0 - 1, 14, x0, 24, "steel_d"); R(c, x0 + 13, 14, x0 + 14, 24, "steel_d")
    R(c, 1, 40, 44, 42, "wood_x")


@item("l6_arrow_barrel", "箭矢桶", C2, 1, 18, 24, level=LV)
def _(c, f):
    R(c, 3, 10, 14, 21, "wood"); R(c, 3, 10, 14, 10, "wood_l"); R(c, 14, 11, 14, 21, "wood_d"); R(c, 3, 13, 14, 13, "iron_d"); R(c, 3, 18, 14, 18, "iron_d"); R(c, 4, 22, 13, 22, "wood_x")
    for x, h in ((5, 8), (8, 10), (11, 7), (13, 9)):
        R(c, x, 10 - h, x, 10, "wood_l"); R(c, x - 1, 10 - h, x + 1, 11 - h, "red_l" if x % 2 else "white")


@item("l6_first_aid", "急救箱", C2, 1, 18, 16, level=LV)
def _(c, f):
    box(c, 2, 4, 15, 13, "cloth", "white", "cloth_d"); R(c, 7, 6, 10, 11, "red"); R(c, 6, 8, 11, 9, "red")
    R(c, 6, 1, 11, 3, "cloth_d"); R(c, 7, 2, 10, 2, "wood"); R(c, 3, 14, 14, 14, "cloth_d")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_whetstone", "磨刀石", C3, 1, 16, 12, level=LV)
def _(c, f):
    R(c, 2, 6, 13, 9, "stone_d"); R(c, 2, 6, 13, 6, "stone_l"); R(c, 3, 9, 12, 10, "wood_d"); R(c, 4, 2, 11, 3, "steel_l"); R(c, 3, 3, 12, 5, "steel"); c.cells([(13, 3), (14, 2)], "f1")


@item("l6_score_marker", "計分牌", C3, 1, 18, 16, level=LV)
def _(c, f):
    R(c, 2, 2, 15, 11, "wood"); R(c, 2, 2, 15, 2, "wood_l"); R(c, 3, 3, 14, 10, "board"); R(c, 7, 3, 7, 10, "chalk")
    for x in (4, 5, 9, 10, 12):
        R(c, x, 5, x, 8, "chalk")
    R(c, 7, 12, 9, 14, "wood_d"); R(c, 4, 14, 12, 15, "wood_x")


@item("l6_battle_potions", "戰鬥藥水組", C3, 1, 20, 16, level=LV)
def _(c, f):
    for x, k in ((3, "red_l"), (8, "blue_l"), (13, "green_l")):
        R(c, x, 5, x + 3, 12, "glass"); R(c, x + 1, 6, x + 2, 12, k); R(c, x + 1, 2, x + 2, 4, "wood_d"); c.put(x + 1, 7, "white")
    R(c, 2, 13, 17, 14, "leather_d"); R(c, 2, 13, 17, 13, "leather")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_war_brazier", "戰火盆", C4, 2, 24, 32, 3, 6, level=LV)
def _(c, f):
    for r in range(7):
        R(c, 3 + r // 2, 12 + r, 20 - r // 2, 12 + r, "iron_d" if r else "iron_l")
    R(c, 10, 19, 13, 27, "iron_d"); R(c, 6, 27, 17, 29, "iron_d"); R(c, 5, 29, 18, 31, "iron_d")
    for x, h in ((7, 8), (11, 12), (15, 9)):
        flame(c, x, 11, h + (f % 2), f + x, 1)
    R(c, 5, 11, 18, 12, "coal")


@item("l6_wall_torch", "牆上火把", C4, 1, 12, 28, 3, 6, level=LV, wall=True)
def _(c, f):
    R(c, 5, 12, 6, 24, "wood_d"); R(c, 5, 12, 5, 24, "wood"); R(c, 3, 10, 8, 13, "iron"); R(c, 4, 22, 7, 24, "iron_d")
    flame(c, 5, 9, 7 + f % 2, f, 1)


@item("l6_beacon", "烽火台", C4, 2, 26, 48, 3, 6, level=LV)
def _(c, f):
    R(c, 6, 18, 19, 42, "stone"); R(c, 6, 18, 19, 18, "stone_l"); R(c, 19, 19, 19, 42, "stone_d")
    for y in range(22, 42, 5):
        R(c, 6, y, 19, y, "stone_d")
    R(c, 4, 42, 21, 46, "stone_d"); R(c, 4, 42, 21, 42, "stone")
    R(c, 3, 14, 22, 18, "iron_d"); R(c, 3, 14, 22, 14, "iron"); R(c, 6, 12, 19, 13, "coal")
    for x, h in ((8, 9), (12, 14), (16, 10)):
        flame(c, x, 12, h + (f % 2), f + x, 1)


@item("l6_banner_lights", "戰旗燈", C4, 2, 32, 22, 2, 3, level=LV, ceiling=True)
def _(c, f):
    R(c, 1, 1, 30, 2, "iron_d")
    for n, x in enumerate((4, 14, 24)):
        R(c, x, 3, x + 5, 15, ["red", "blue", "gold"][n]); R(c, x, 3, x + 5, 3, "iron")
        for r in range(4):
            R(c, x + r // 2, 16 + r, x + 5 - r // 2, 16 + r, ["red", "blue", "gold"][n])
        R(c, x + 2, 6, x + 3, 9, "white"); c.put(x + 2, 20, "f1" if (n + f) % 2 else "f2")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_crossed_axes", "交叉雙斧", C5, 1, 26, 22, level=LV, wall=True)
def _(c, f):
    for i in range(18):
        c.put(4 + i, 3 + i, "wood_d"); c.put(5 + i, 3 + i, "wood"); c.put(21 - i, 3 + i, "wood_d"); c.put(20 - i, 3 + i, "wood")
    R(c, 2, 2, 9, 8, "steel"); R(c, 2, 2, 9, 2, "steel_l"); R(c, 17, 2, 24, 8, "steel"); R(c, 17, 2, 24, 2, "steel_l")
    R(c, 11, 8, 14, 13, "gold_d"); circle(c, 12.5, 10, 2.4, "gold")


@item("l6_war_banner", "戰旗", C5, 2, 22, 42, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 20, 2, "wood"); R(c, 3, 3, 18, 30, "arena"); R(c, 3, 3, 3, 30, "arena_d"); R(c, 18, 3, 18, 30, "arena_d")
    for r in range(8):
        R(c, 3 + r, 31 + r, 10, 31 + r, "arena"); R(c, 11, 31 + r, 18 - r, 31 + r, "arena")
    R(c, 7, 8, 14, 20, "gold_d"); R(c, 8, 9, 13, 19, "arena_d"); R(c, 9, 10, 12, 18, "gold") if False else R(c, 10, 10, 11, 18, "gold"); R(c, 8, 13, 13, 14, "gold")


@item("l6_scoreboard", "大計分板", C5, 2, 38, 24, level=LV, wall=True)
def _(c, f):
    frame_border(c, 1, 1, 36, 21, "wood")
    R(c, 3, 3, 34, 19, "board"); R(c, 18, 3, 19, 19, "chalk"); R(c, 3, 8, 34, 8, "chalk")
    for x in (5, 7, 9, 12):
        R(c, x, 11, x, 16, "chalk")
    for x in (22, 24, 26, 28, 30, 32):
        R(c, x, 11, x, 16, "chalk") if x < 29 else None
    R(c, 6, 4, 15, 6, "red_l"); R(c, 22, 4, 31, 6, "blue_l")


@item("l6_beast_head", "魔獸頭顱標本", C5, 2, 30, 26, level=LV, wall=True)
def _(c, f):
    R(c, 3, 2, 26, 22, "wood_d"); R(c, 3, 2, 26, 2, "wood")
    circle(c, 14.5, 12, 8, "hide", 7); circle(c, 14.2, 11.6, 7, "hide_d" if False else "hide", 6.2)
    R(c, 4, 4, 7, 9, "hide_d"); R(c, 22, 4, 25, 9, "hide_d")
    R(c, 3, 1, 5, 6, "cloth"); R(c, 24, 1, 26, 6, "cloth")
    c.cells([(10, 10), (19, 10)], "black"); R(c, 12, 15, 17, 18, "hide_d"); R(c, 13, 17, 14, 19, "white"); R(c, 16, 17, 17, 19, "white")


@item("l6_battle_map", "戰術沙圖", C5, 2, 36, 26, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 34, 24, "wood_d"); R(c, 3, 3, 32, 22, "parch")
    R(c, 6, 6, 14, 12, "grass"); R(c, 20, 10, 29, 18, "grass_d"); R(c, 12, 14, 18, 20, "water_l")
    for x, y, k in ((9, 9, "red"), (11, 8, "red"), (24, 13, "blue"), (26, 15, "blue")):
        R(c, x, y, x + 1, y + 2, k)
    for i in range(10):
        c.put(14 + i, 12 + (i // 3), "ink")
    R(c, 28, 5, 30, 5, "ink"); R(c, 29, 4, 29, 7, "ink")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_sand_pit", "沙地", C6, 4, 48, 32, level=LV, flat=True)
def _(c, f):
    R(c, 1, 1, 46, 30, "sand_d"); R(c, 2, 2, 45, 29, "sand")
    import random
    rng = random.Random(5)
    for _ in range(70):
        c.put(rng.randrange(3, 44), rng.randrange(3, 28), "sand_l" if rng.random() < 0.6 else "sand_d")
    for x in range(1, 47, 3):
        c.put(x, 0, "wood_d"); c.put(x, 31, "wood_d")


@item("l6_arena_mat", "擂台墊", C6, 4, 46, 32, level=LV, flat=True)
def _(c, f):
    R(c, 1, 1, 44, 30, "arena_d"); R(c, 2, 2, 43, 29, "arena"); circle(c, 22.5, 15.5, 11, "white", 9); circle(c, 22.5, 15.5, 9.6, "arena", 8); R(c, 22, 6, 23, 25, "white") if False else None
    circle(c, 22.5, 15.5, 3, "gold", 2.4)
    for x in range(2, 44, 4):
        R(c, x, 2, x + 1, 2, "white"); R(c, x, 29, x + 1, 29, "white")


@item("l6_target_rug", "靶心地毯", C6, 2, 36, 28, level=LV, flat=True)
def _(c, f):
    circle(c, 17.5, 13.5, 17, "white", 13); circle(c, 17.5, 13.5, 14, "red", 11); circle(c, 17.5, 13.5, 11, "white", 8.6); circle(c, 17.5, 13.5, 8, "blue", 6.2); circle(c, 17.5, 13.5, 5, "white", 3.8); circle(c, 17.5, 13.5, 2.6, "red", 2)


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_dead_tree", "枯樹", C7, 2, 30, 46, level=LV)
def _(c, f):
    R(c, 13, 16, 17, 42, "wood_d"); R(c, 13, 16, 14, 42, "wood"); R(c, 10, 40, 14, 44, "wood_d"); R(c, 16, 40, 20, 44, "wood_d")
    for (x0, y0, x1, y1) in ((13, 22, 4, 12), (17, 18, 26, 8), (15, 14, 15, 3), (14, 28, 6, 22), (17, 26, 24, 20)):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            c.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), "wood_d")
    R(c, 1, 44, 28, 45, "dirt")


@item("l6_thorn_bush", "荊棘叢", C7, 1, 24, 20, level=LV)
def _(c, f):
    blob(c, 11.5, 11, 8.6, "green_d", "pine_d" if "pine_d" in P else "green_d", "green", 7)
    for x, y in ((4, 8), (9, 4), (14, 6), (18, 10), (6, 14), (12, 15), (17, 14)):
        c.put(x, y, "steel_l"); c.put(x, y - 1, "steel_l")
    for x, y in ((8, 9), (15, 11)):
        c.put(x, y, "red_l")
    R(c, 2, 17, 21, 18, "dirt")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_champion_statue", "冠軍像", C8, 2, 28, 48, level=LV)
def _(c, f):
    plinth(c, 4, 23, 38, 47)
    circle(c, 13.5, 9, 4, "bronze_l"); R(c, 8, 13, 19, 28, "bronze"); R(c, 19, 13, 19, 28, "bronze_d")
    R(c, 20, 3, 23, 12, "bronze_l"); circle(c, 21.5, 3, 3, "gold_l"); R(c, 4, 14, 7, 24, "bronze_d")
    R(c, 9, 29, 12, 37, "bronze"); R(c, 15, 29, 18, 37, "bronze_d"); R(c, 9, 41, 18, 43, "gold")


@item("l6_beast_trophy", "魔獸標本", C8, 2, 36, 34, level=LV)
def _(c, f):
    plinth(c, 3, 32, 26, 33)
    circle(c, 17.5, 16, 10, "hide", 9); R(c, 6, 14, 29, 24, "hide"); R(c, 29, 15, 29, 24, "hide_d")
    circle(c, 28, 11, 4, "hide", 4); R(c, 31, 11, 34, 12, "hide_d"); c.put(28, 9, "black"); R(c, 26, 5, 27, 8, "cloth"); R(c, 30, 5, 31, 8, "cloth")
    R(c, 8, 24, 10, 26, "hide_d"); R(c, 24, 24, 26, 26, "hide_d")
    for x in (10, 15, 20):
        R(c, x, 12, x, 16, "hide_d")


@item("l6_broken_sword", "斷劍紀念碑", C8, 2, 24, 40, level=LV)
def _(c, f):
    plinth(c, 3, 20, 30, 39)
    R(c, 10, 10, 13, 29, "stone_d"); R(c, 11, 11, 12, 29, "steel_l")
    R(c, 7, 29, 16, 30, "gold_d"); R(c, 10, 31, 13, 34, "wood_d")
    R(c, 11, 7, 12, 10, "steel"); c.cells([(10, 6), (13, 5)], "steel_l")
    R(c, 14, 31, 19, 32, "steel") if False else R(c, 15, 32, 19, 33, "steel_d")


@item("l6_golem_statue", "巨大魔像雕像", C8, 4, 38, 50, level=LV)
def _(c, f):
    plinth(c, 3, 34, 42, 49)
    R(c, 10, 5, 27, 18, "stone"); R(c, 10, 5, 27, 5, "stone_l"); R(c, 27, 6, 27, 18, "stone_d"); R(c, 13, 9, 15, 11, "rune"); R(c, 22, 9, 24, 11, "rune"); R(c, 15, 14, 22, 15, "stone_x")
    R(c, 6, 19, 31, 34, "stone"); R(c, 31, 20, 31, 34, "stone_d"); R(c, 6, 19, 31, 20, "stone_l")
    R(c, 2, 20, 6, 36, "stone_d"); R(c, 31, 20, 35, 36, "stone"); R(c, 10, 35, 15, 41, "stone_d"); R(c, 22, 35, 27, 41, "stone")
    circle(c, 18.5, 26, 3, "rune_d", 3); circle(c, 18.5, 26, 1.6, "rune", 1.6)


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_boxing_ring", "拳擊擂台", C9, 4, 54, 38, level=LV)
def _(c, f):
    R(c, 3, 22, 50, 30, "arena"); R(c, 3, 22, 50, 23, "white"); R(c, 50, 24, 50, 30, "arena_d"); R(c, 2, 31, 51, 36, "wood_d"); R(c, 2, 31, 51, 31, "wood")
    for x in (3, 49):
        R(c, x, 5, x + 1, 30, "steel"); R(c, x, 5, x, 30, "steel_l")
    for y, k in ((9, "red"), (15, "white"), (21, "blue")):
        R(c, 4, y, 49, y, k); R(c, 4, y + 1, 49, y + 1, k + "_d" if k + "_d" in P else k)
    R(c, 14, 32, 17, 35, "wood_x"); R(c, 36, 32, 39, 35, "wood_x")


@item("l6_punching_bag", "沙袋", C9, 1, 16, 36, 2, 2, level=LV)
def _(c, f):
    R(c, 7, 0, 8, 3, "iron_d"); R(c, 3, 0, 12, 1, "iron")
    dx = [0, 1][f]
    R(c, 7, 3, 8 + dx, 5, "rope")
    R(c, 4 + dx, 6, 11 + dx, 28, "leather"); R(c, 4 + dx, 6, 11 + dx, 6, "leather_l"); R(c, 11 + dx, 7, 11 + dx, 28, "leather_d")
    R(c, 4 + dx, 12, 11 + dx, 12, "rope"); R(c, 4 + dx, 22, 11 + dx, 22, "rope"); R(c, 5 + dx, 29, 10 + dx, 30, "leather_d")


@item("l6_archery_range", "弓箭靶場", C9, 2, 38, 36, level=LV)
def _(c, f):
    circle(c, 28, 14, 11, "wood_d", 11); circle(c, 28, 14, 10, "hay", 10); circle(c, 28, 14, 8, "white", 8); circle(c, 28, 14, 6, "red", 6); circle(c, 28, 14, 4, "white", 4); circle(c, 28, 14, 2, "red", 2)
    R(c, 25, 25, 26, 33, "wood_d"); R(c, 30, 25, 31, 33, "wood_d"); R(c, 22, 33, 34, 34, "wood_x")
    R(c, 28, 12, 33, 12, "wood_l"); R(c, 33, 11, 35, 13, "white"); R(c, 26, 16, 31, 16, "wood_l")
    R(c, 3, 22, 4, 32, "wood_d"); R(c, 2, 20, 9, 21, "wood"); R(c, 5, 22, 9, 22, "iron_d")
    R(c, 4, 22, 4, 28, "wood_l"); circle(c, 4, 26, 5, "wood", 7) if False else None


@item("l6_dumbbells", "鐵啞鈴組", C9, 1, 26, 16, level=LV)
def _(c, f):
    for y, w in ((11, 8), (6, 6)):
        R(c, 13 - w // 2 - 2, y - 2, 13 + w // 2 + 2, y + 2, "iron_d") if False else None
        R(c, 4, y, 21, y + 1, "iron_l")
        for x in (3, 5, 20, 22):
            R(c, x, y - 2, x, y + 3, "iron_d"); R(c, x + 1, y - 2, x + 1, y + 3, "iron")
    R(c, 2, 14, 23, 15, "wood_d")


@item("l6_obstacle_wall", "攀爬牆", C9, 4, 42, 46, level=LV)
def _(c, f):
    R(c, 3, 3, 38, 41, "wood"); R(c, 3, 3, 38, 4, "wood_l"); R(c, 38, 4, 38, 41, "wood_d")
    for x in range(5, 38, 5):
        R(c, x, 4, x, 40, "wood_d")
    for x, y, k in ((8, 34, "red"), (14, 28, "blue"), (22, 31, "gold"), (28, 22, "green"), (12, 16, "red_l"), (20, 10, "blue_l"), (30, 8, "gold")):
        circle(c, x, y, 1.8, k); c.put(x - 1, y - 1, "white")
    R(c, 1, 41, 40, 44, "wood_d"); R(c, 1, 41, 40, 41, "wood"); R(c, 17, 1, 24, 2, "rope")


@item("l6_horse_dummy", "騎術木馬", C9, 2, 30, 34, level=LV)
def _(c, f):
    R(c, 7, 12, 20, 21, "wood"); R(c, 7, 12, 20, 12, "wood_l"); R(c, 20, 13, 20, 21, "wood_d")
    R(c, 20, 6, 24, 14, "wood"); R(c, 21, 3, 27, 7, "wood"); c.put(25, 4, "black"); R(c, 22, 1, 23, 3, "wood_d")
    legs(c, (9, 11, 17, 19), 22, 31, "wood_d"); R(c, 8, 32, 12, 32, "wood_x"); R(c, 16, 32, 20, 32, "wood_x")
    R(c, 10, 9, 17, 11, "leather"); R(c, 10, 9, 17, 9, "leather_l"); R(c, 4, 12, 7, 16, "wood_d")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_water_trough", "水槽", C10, 2, 32, 20, level=LV)
def _(c, f):
    R(c, 2, 6, 29, 16, "wood"); R(c, 2, 6, 29, 6, "wood_l"); R(c, 29, 7, 29, 16, "wood_d")
    R(c, 4, 7, 27, 12, "water"); R(c, 4, 7, 27, 7, "water_l"); R(c, 2, 11, 29, 11, "iron_d") if False else None
    R(c, 2, 13, 29, 13, "iron_d"); R(c, 4, 17, 6, 19, "wood_x"); R(c, 25, 17, 27, 19, "wood_x")


@item("l6_ration_cart", "補給車", C10, 2, 34, 30, level=LV)
def _(c, f):
    R(c, 3, 8, 28, 21, "wood"); R(c, 3, 8, 28, 8, "wood_l"); R(c, 28, 9, 28, 21, "wood_d")
    for x in range(5, 28, 5):
        R(c, x, 9, x, 20, "wood_d")
    R(c, 6, 2, 12, 7, "wood_d"); R(c, 14, 4, 21, 7, "straw"); R(c, 23, 3, 27, 7, "red_d")
    circle(c, 8, 25, 4.4, "wood_d", 4.4); circle(c, 8, 25, 3, "wood", 3); circle(c, 23, 25, 4.4, "wood_d", 4.4); circle(c, 23, 25, 3, "wood", 3)
    R(c, 28, 14, 33, 15, "wood_d")


@item("l6_energy_barrel", "能量飲料桶", C10, 1, 18, 24, level=LV)
def _(c, f):
    R(c, 3, 8, 13, 20, "wood"); R(c, 3, 8, 13, 8, "wood_l"); R(c, 13, 9, 13, 20, "wood_d"); R(c, 3, 11, 13, 11, "iron_d"); R(c, 3, 17, 13, 17, "iron_d"); R(c, 7, 13, 9, 15, "gold_d")
    R(c, 14, 14, 16, 15, "iron_l"); R(c, 15, 15, 16, 18, "iron_d"); R(c, 13, 20, 17, 22, "glass_d"); R(c, 14, 20, 16, 22, "red_l")
    R(c, 4, 21, 12, 22, "wood_x")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_portcullis", "鐵閘門", C11, 4, 46, 48, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 44, 8, "stone"); R(c, 1, 1, 44, 1, "stone_l"); R(c, 1, 8, 44, 8, "stone_d")
    for x0 in (1, 38):
        R(c, x0, 9, x0 + 6, 46, "stone"); R(c, x0, 9, x0, 46, "stone_l"); R(c, x0 + 6, 10, x0 + 6, 46, "stone_d")
    R(c, 8, 9, 37, 46, "black")
    for x in range(10, 37, 5):
        R(c, x, 9, x + 1, 40, "iron"); R(c, x, 9, x, 40, "iron_l"); c.put(x, 41, "iron_l"); c.put(x + 1, 41, "iron_l")
    for y in (14, 24, 34):
        R(c, 8, y, 37, y + 1, "iron_d")


@item("l6_palisade", "木柵牆", C11, 2, 42, 36, level=LV)
def _(c, f):
    for x in range(1, 41, 4):
        h = 26 + ((x // 4) % 3) * 2
        R(c, x, 32 - h, x + 3, 33, "wood"); R(c, x, 32 - h, x, 33, "wood_l"); R(c, x + 3, 33 - h, x + 3, 33, "wood_d")
        c.put(x + 1, 31 - h, "wood_l"); c.put(x + 2, 31 - h, "wood_l")
    R(c, 1, 14, 40, 15, "rope"); R(c, 1, 26, 40, 27, "rope"); R(c, 0, 34, 41, 35, "dirt")


@item("l6_arena_gate", "競技場拱門", C11, 4, 48, 46, level=LV)
def _(c, f):
    R(c, 2, 14, 12, 44, "stone"); R(c, 2, 14, 2, 44, "stone_l"); R(c, 12, 15, 12, 44, "stone_d"); R(c, 35, 14, 45, 44, "stone"); R(c, 35, 14, 35, 44, "stone_l"); R(c, 45, 15, 45, 44, "stone_d")
    for y in range(20, 44, 6):
        R(c, 2, y, 12, y, "stone_d"); R(c, 35, y, 45, y, "stone_d")
    for r in range(13):
        half = int(round(math.sqrt(max(0, 13 ** 2 - r ** 2))))
        R(c, 24 - half, 14 - r, 23 + half, 14 - r, "stone" if r % 3 else "stone_l")
    for r in range(11):
        half = int(round(math.sqrt(max(0, 11 ** 2 - r ** 2))))
        R(c, 24 - half, 14 - r, 23 + half, 14 - r, None) if False else None
    R(c, 13, 14, 34, 44, "black"); circle(c, 24, 14, 11, "black", 11) if False else None
    R(c, 14, 8, 33, 13, "black")
    R(c, 20, 1, 27, 4, "gold"); R(c, 18, 4, 29, 5, "gold_d")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_dummy_row", "木人樁組", C12, 2, 40, 34, level=LV)
def _(c, f):
    for x0 in (3, 15, 27):
        R(c, x0 + 4, 12, x0 + 5, 29, "wood_d"); R(c, x0, 29, x0 + 9, 31, "wood")
        circle(c, x0 + 4.5, 7, 4.2, "straw"); R(c, x0 + 1, 12, x0 + 8, 21, "straw"); R(c, x0 - 2, 14, x0 + 11, 15, "wood_d")
        c.cells([(x0 + 3, 6), (x0 + 6, 6)], "black"); R(c, x0 + 3, 16, x0 + 6, 19, "red"); c.put(x0 + 4, 17, "white")
        for y in (13, 18):
            R(c, x0 + 1, y, x0 + 8, y, "straw_d")


@item("l6_straw_targets", "草靶", C12, 2, 32, 38, level=LV)
def _(c, f):
    for x0, y0 in ((2, 4), (16, 12)):
        circle(c, x0 + 6, y0 + 6, 7, "hay", 7); circle(c, x0 + 6, y0 + 6, 5, "white", 5); circle(c, x0 + 6, y0 + 6, 3, "red", 3); c.put(x0 + 6, y0 + 6, "gold")
        R(c, x0 + 3, y0 + 13, x0 + 4, y0 + 21, "wood_d"); R(c, x0 + 8, y0 + 13, x0 + 9, y0 + 21, "wood_d"); R(c, x0 + 1, y0 + 22, x0 + 11, y0 + 23, "wood_x")
        R(c, x0 + 7, y0 + 5, x0 + 11, y0 + 5, "wood_l"); R(c, x0 + 11, y0 + 4, x0 + 12, y0 + 6, "white")
    R(c, 0, 34, 31, 35, "dirt")


@item("l6_watchtower", "瞭望塔", C12, 4, 36, 56, level=LV)
def _(c, f):
    for x in (6, 28):
        R(c, x, 20, x + 2, 52, "wood_d"); R(c, x, 20, x, 52, "wood")
    for y in range(26, 50, 8):
        for i in range(10):
            c.put(8 + i * 2, y + i // 2 * 0, "wood_d")
        R(c, 8, y, 27, y, "wood_d")
    R(c, 5, 17, 31, 21, "wood"); R(c, 5, 17, 31, 17, "wood_l"); R(c, 5, 9, 31, 16, "wood_d"); R(c, 7, 11, 29, 15, "black")
    for r in range(8):
        R(c, 4 + r, 1 + r, 31 - r, 1 + r, "red_d" if r % 2 else "red")
    R(c, 17, 21, 19, 52, "wood") if False else R(c, 16, 22, 20, 50, "wood_x")
    R(c, 3, 52, 33, 54, "stone_d")


@item("l6_spar_fence", "練習圍欄", C12, 2, 42, 20, level=LV)
def _(c, f):
    R(c, 1, 5, 40, 6, "wood_l"); R(c, 1, 12, 40, 13, "wood_l"); R(c, 1, 5, 40, 5, "wood")
    for x in range(2, 40, 8):
        R(c, x, 2, x + 2, 18, "wood"); R(c, x, 2, x, 18, "wood_l"); R(c, x + 2, 3, x + 2, 18, "wood_d")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l6_war_horse", "戰馬", C13, 2, 40, 36, 4, 3, level=LV)
def _(c, f):
    R(c, 8, 12, 28, 24, "horse"); R(c, 8, 12, 28, 12, "horse_l"); R(c, 28, 13, 28, 24, "horse_d")
    circle(c, 29, 12, 3.6, "horse", 3.6)
    R(c, 28, 4, 32, 11, "horse"); R(c, 31, 2, 36, 8, "horse"); R(c, 36, 5, 37, 8, "horse_d"); c.put(34, 4, "black"); R(c, 29, 1, 30, 3, "horse_d")
    R(c, 25, 3, 27, 12, "black")
    legs_y = [0, 1, 0, -1][f]
    for x, dy in ((10, 0), (14, legs_y), (23, -legs_y), (26, 0)):
        R(c, x, 25, x + 1, 33 + dy, "horse_d"); R(c, x, 33 + dy, x + 1, 34 + dy, "black")
    R(c, 3, 13, 7, 14, "black"); R(c, 2, 14, 5, 22 - f % 2, "black")
    R(c, 14, 10, 21, 12, "leather"); R(c, 14, 10, 21, 10, "leather_l")


@item("l6_hawk", "獵鷹", C13, 1, 22, 30, 3, 3, level=LV)
def _(c, f):
    R(c, 2, 24, 18, 25, "wood"); R(c, 9, 25, 10, 28, "wood_d"); R(c, 5, 28, 14, 29, "wood_x")
    circle(c, 9, 15, 6, "hawk", 7); circle(c, 8.6, 14.6, 5, "hawk_d", 6); R(c, 6, 12, 11, 18, "cloth")
    circle(c, 13, 7, 3.2, "hawk", 3.2); R(c, 15, 7, 17, 8, "gold"); R(c, 16, 8, 16, 9, "gold_d"); c.put(13, 6, "black"); R(c, 11, 4, 14, 4, "hawk_d")
    wing = [[(2, 12), (1, 15), (2, 19)], [(1, 10), (0, 13), (1, 18)], [(2, 13), (1, 16), (2, 20)]][f]
    c.cells(wing, "hawk_d"); R(c, 7, 21, 8, 24, "gold_d"); R(c, 11, 21, 12, 24, "gold_d")


@item("l6_war_dog", "戰犬", C13, 1, 28, 20, 4, 4, level=LV)
def _(c, f):
    R(c, 6, 7, 20, 14, "hide_d"); R(c, 6, 7, 20, 7, "hide"); circle(c, 22, 7, 3.4, "hide", 3.2); R(c, 24, 7, 27, 9, "hide_d"); c.put(23, 6, "black"); R(c, 21, 2, 22, 5, "hide_d")
    R(c, 18, 10, 22, 11, "iron_d"); c.put(20, 11, "gold")
    for x, dy in ((7, 0), (10, [0, 1, 0, -1][f]), (16, [0, -1, 0, 1][f]), (19, 0)):
        R(c, x, 15, x + 1, 18 + dy, "hide_d")
    tail = [(4, 6), (3, 5), (2, 4)] if f % 2 else [(4, 7), (3, 7), (2, 6)]
    c.cells(tail, "hide_d")


@item("l6_training_golem", "訓練魔偶", C13, 2, 28, 40, 3, 3, level=LV, note="站在場中被人揍的魔偶")
def _(c, f):
    R(c, 8, 4, 19, 14, "stone"); R(c, 8, 4, 19, 4, "stone_l"); R(c, 19, 5, 19, 14, "stone_d"); R(c, 11, 8, 12, 9, "rune"); R(c, 15, 8, 16, 9, "rune")
    R(c, 6, 15, 21, 28, "stone_d"); R(c, 6, 15, 21, 15, "stone"); R(c, 21, 16, 21, 28, "stone_x")
    R(c, 11, 18, 16, 24, "red_d" if "red_d" in P else "red"); circle(c, 13.5, 21, 2.4, "white", 2.4); circle(c, 13.5, 21, 1.2, "red", 1.2)
    sh = [0, 1, 0][f]
    R(c, 2 + sh, 16, 5 + sh, 24, "stone"); R(c, 22 - sh, 16, 25 - sh, 24, "stone")
    R(c, 8, 29, 12, 37, "stone_x"); R(c, 15, 29, 19, 37, "stone_d"); R(c, 7, 38, 20, 39, "stone_x")
    if f == 1:
        c.cells([(1, 14), (26, 14), (0, 18), (27, 18)], "f1")
