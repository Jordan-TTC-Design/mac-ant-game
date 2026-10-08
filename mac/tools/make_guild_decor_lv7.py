"""Guild level 7 unlocks: the tower (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 7
add_colors({"tw_arc": (116, 84, 206), "tw_arc_d": (74, 52, 152), "tw_arc_l": (176, 146, 244), "tw_bf": (96, 204, 255), "tw_bf_d": (52, 124, 224), "tw_bf_l": (196, 238, 255),
            "tw_bone": (238, 230, 212), "tw_bone_d": (192, 182, 160), "tw_bone_x": (150, 140, 120), "tw_night": (30, 26, 70), "tw_night_l": (60, 54, 120),
            "tw_dragon": (176, 50, 50), "tw_dragon_d": (120, 30, 40), "tw_dragon_l": (224, 100, 80), "tw_coin": (250, 214, 90), "tw_coin_d": (200, 150, 40)})


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_archmage_desk", "大法師書桌", C1, 2, 40, 30, level=LV, note="堆滿卷軸和水晶的大書桌")
def _(c, f):
    table(c, 1, 11, 38, 29, "dark", depth=3)
    R(c, 3, 16, 14, 27, "dark_d"); R(c, 25, 16, 36, 27, "dark_d"); drawers(c, 4, 17, 13, 26, 2, "dark", "tw_arc_l"); drawers(c, 26, 17, 35, 26, 2, "dark", "tw_arc_l")
    R(c, 5, 6, 13, 10, "parch"); R(c, 6, 7, 12, 7, "ink"); circle(c, 20, 7, 3.4, "glass_d"); circle(c, 20, 7, 2.4, "glass"); c.put(19, 6, "white"); R(c, 18, 9, 22, 10, "gold_d")
    R(c, 27, 3, 28, 9, "white"); R(c, 31, 5, 35, 10, "tw_arc"); R(c, 32, 6, 34, 8, "tw_arc_l")


@item("l7_wizard_chair", "法師高背椅", C1, 2, 28, 44, level=LV, seat=True)
def _(c, f):
    h = 44
    sy = h - 1 - SEAT_UP
    for r in range(24):
        half = 7 + (3 if r < 6 else 0) - (r // 12)
        R(c, 14 - half, 2 + r, 13 + half, 2 + r, "tw_arc_d" if r else "gold")
    R(c, 6, 5, 21, 22, "tw_arc"); R(c, 7, 6, 20, 21, "tw_arc_d"); circle(c, 13.5, 13, 3.4, "gold"); c.cells([(13, 11), (14, 11), (13, 15), (14, 15)], "gold_l")
    for x0 in (2, 22):
        R(c, x0, 24, x0 + 3, h - 2, "tw_arc"); R(c, x0, 24, x0 + 3, 24, "gold")
    R(c, 5, sy, 22, sy, "tw_arc_l"); R(c, 5, sy + 1, 22, h - 2, "tw_arc"); R(c, 1, h - 1, 26, h - 1, "gold_d")


@item("l7_floating_stool", "懸浮凳", C1, 1, 18, 24, 2, 2, level=LV, seat=True, note="會輕輕上下飄的魔法凳")
def _(c, f):
    h = 24
    sy = h - 1 - SEAT_UP - 2 + f
    cushion(c, 2, sy, 15, sy + 3, "tw_arc", "tw_arc_l", "tw_arc_d")
    R(c, 3, sy + 4, 14, sy + 5, "gold_d")
    for x, y in ((4, 22), (13, 21), (8, 23)):
        c.put(x, y - (f if x % 2 else 0), "tw_arc_l")
    R(c, 6, h - 2, 11, h - 2, "tw_night_l")


@item("l7_throne", "公會王座", C1, 4, 40, 54, level=LV, seat=True, note="屬於會長的金色大王座")
def _(c, f):
    h = 54
    sy = h - 1 - SEAT_UP
    for r in range(30):
        half = 10 + (4 if r < 8 else 0) + (2 if r < 3 else 0)
        R(c, 19 - half, 2 + r, 20 + half, 2 + r, "gold" if r < 2 or r % 7 == 0 else "gold_d")
    R(c, 9, 6, 30, 30, "velvet"); R(c, 10, 7, 29, 29, "velvet_d"); circle(c, 19.5, 17, 5, "gold"); circle(c, 19.5, 17, 3, "velvet", 3); c.put(19, 16, "gold_l")
    R(c, 3, 2, 5, 4, "gold_l"); R(c, 34, 2, 36, 4, "gold_l"); R(c, 17, 0, 22, 2, "gold_l")
    for x0 in (2, 34):
        R(c, x0, 26, x0 + 4, h - 2, "gold_d"); R(c, x0, 26, x0 + 4, 26, "gold"); R(c, x0 + 1, 28, x0 + 3, 40, "velvet")
    R(c, 7, sy, 32, sy, "velvet_l"); R(c, 7, sy + 1, 32, h - 2, "velvet"); R(c, 1, h - 1, 38, h - 1, "gold_d"); R(c, 6, h - 4, 33, h - 3, "gold")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_grimoire_shelf", "魔法書牆", C2, 4, 44, 48, 2, 2, level=LV, note="書脊會發光的魔法藏書")
def _(c, f):
    box(c, 1, 1, 42, 46, "dark", "dark_l", "dark_d")
    for i, y in enumerate((4, 15, 26, 37)):
        R(c, 3, y, 40, y + 8, "wood_x"); R(c, 2, y + 9, 41, y + 9, "dark_l")
        x = 3
        n = 0
        while x < 40:
            w = 2 + (n % 3)
            k = ["tw_arc", "tw_arc_d", "red", "blue_d", "green_d", "gold_d"][(n + i) % 6]
            R(c, x, y + 1 + (n % 2), min(x + w - 1, 40), y + 8, k)
            if (n + f) % 7 == 0:
                c.put(x, y + 3, "tw_arc_l")
            x += w; n += 1
    R(c, 0, 47, 43, 47, "wood_x")


@item("l7_potion_cabinet", "大藥劑櫃", C2, 2, 32, 42, 2, 2, level=LV)
def _(c, f):
    frame_border(c, 1, 1, 30, 40, "dark")
    R(c, 3, 3, 28, 38, "black")
    for y in (13, 24, 35):
        R(c, 3, y, 28, y + 1, "dark_l")
    cols = ["red_l", "tw_bf", "green_l", "pink", "f1", "tw_arc_l"]
    for r, y in enumerate((5, 16, 27)):
        for n, x in enumerate(range(4, 27, 5)):
            R(c, x, y + 2, x + 3, y + 7, "glass"); R(c, x + 1, y + 3 + ((n + f) % 2), x + 2, y + 7, cols[(n + r * 2) % 6]); R(c, x + 1, y, x + 2, y + 1, "wood_d")


@item("l7_artifact_case", "神器展示櫃", C2, 2, 30, 38, 2, 2, level=LV)
def _(c, f):
    frame_border(c, 1, 1, 28, 36, "gold")
    R(c, 3, 3, 26, 34, "tw_night"); R(c, 3, 3, 5, 34, "tw_night_l")
    R(c, 6, 26, 23, 33, "tw_arc_d"); R(c, 6, 26, 23, 26, "tw_arc")
    R(c, 13, 8, 14, 22, "steel_l"); R(c, 10, 22, 17, 23, "gold"); R(c, 12, 5, 15, 7, "steel"); c.cells([(12, 4), (15, 4)], "steel_l")
    for x, y in (([8, 9], [20, 14], [9, 18]) if f else ([21, 8], [8, 14], [19, 19])):
        c.put(x, y, "tw_arc_l")


@item("l7_scroll_vault", "卷軸庫", C2, 2, 34, 38, level=LV)
def _(c, f):
    box(c, 1, 1, 32, 36, "dark", "dark_l", "dark_d")
    for r in range(5):
        for col in range(4):
            x, y = 3 + col * 7, 3 + r * 6
            circle(c, x + 2, y + 2, 2.8, "wood_x", 2.8); circle(c, x + 2, y + 2, 2, ["parch", "parch_d", "paper"][(r + col) % 3], 2); c.put(x + 2, y + 2, ["red", "tw_arc", "ink"][(r + col) % 3])
    R(c, 0, 37, 33, 37, "wood_x")


@item("l7_treasure_hoard", "寶藏堆", C2, 4, 44, 28, level=LV, note="金幣、寶石和王冠堆成的小山")
def _(c, f):
    for r in range(18):
        half = 4 + r * 2 if r < 14 else 32
        R(c, 22 - half // 1, 6 + r, 21 + half // 1, 6 + r, "tw_coin" if (r + 1) % 3 else "tw_coin_d")
    import random
    rng = random.Random(9)
    for _ in range(40):
        x, y = rng.randrange(6, 38), rng.randrange(8, 23)
        c.put(x, y, rng.choice(["gold_l", "tw_coin_d", "white"]))
    for x, y, k in ((10, 16, "red_l"), (30, 14, "tw_bf"), (20, 10, "green_l"), (26, 20, "pink")):
        R(c, x, y, x + 1, y + 1, k); c.put(x, y, "white")
    R(c, 18, 2, 25, 6, "gold"); R(c, 18, 2, 25, 2, "gold_l"); c.cells([(19, 1), (21, 0), (24, 1)], "gold_l"); R(c, 20, 4, 23, 5, "red")
    R(c, 1, 25, 42, 26, "tw_coin_d")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_mini_orrery", "迷你天象儀", C3, 1, 22, 22, 3, 3, level=LV)
def _(c, f):
    R(c, 9, 15, 12, 18, "gold_d"); R(c, 5, 18, 16, 20, "gold_d"); R(c, 5, 18, 16, 18, "gold")
    circle(c, 10.5, 9, 3, "f1", 3)
    for k, (r, col) in enumerate(((5, "tw_bf"), (8, "red_l"))):
        a = f * 2 * math.pi / 3 + k * 2.1
        c.put(round(10 + math.cos(a) * r), round(9 + math.sin(a) * r * 0.5), col)
        circle(c, 10.5, 9, r + 0.4, None, r * 0.5) if False else None
    for i in range(16):
        a = i * math.pi / 8
        c.put(round(10 + math.cos(a) * 8), round(9 + math.sin(a) * 4), "gold_d")


@item("l7_crystal_ball", "水晶球", C3, 1, 18, 22, 3, 3, level=LV, note="裡面有霧在飄的水晶球")
def _(c, f):
    R(c, 5, 15, 12, 17, "gold_d"); R(c, 3, 17, 14, 19, "gold_d"); R(c, 3, 17, 14, 17, "gold")
    circle(c, 8.5, 9, 7, "glass_d", 7); circle(c, 8.2, 8.7, 6, "glass", 6)
    for k in range(4):
        c.put(5 + (k * 2 + f) % 7, 8 + (k + f) % 4, "tw_arc_l"); c.put(6 + (k * 3 + f) % 6, 6 + k % 3, "white")
    c.cells([(5, 5), (6, 4)], "white")


@item("l7_rune_stones", "符文石", C3, 1, 20, 14, 2, 2, level=LV)
def _(c, f):
    for x, y, w in ((2, 6, 5), (8, 4, 6), (15, 7, 4)):
        R(c, x, y, x + w, y + 5, "stone_d"); R(c, x, y, x + w, y, "stone"); R(c, x + w, y + 1, x + w, y + 5, "stone_x")
        c.cells([(x + 2, y + 2), (x + 2, y + 3), (x + 3, y + 3)], "tw_bf_l" if f else "tw_bf")
    R(c, 1, 12, 19, 12, "wood_d")


@item("l7_alchemy_set", "煉金器具組", C3, 1, 24, 20, 3, 3, level=LV)
def _(c, f):
    circle(c, 6, 11, 4.4, "glass_d", 4.4); circle(c, 6, 11, 3.4, "glass", 3.4); R(c, 5, 11, 7, 14, ["red_l", "tw_bf", "green_l"][f]); R(c, 5, 3, 7, 6, "glass_d")
    R(c, 12, 4, 14, 16, "glass_d"); R(c, 12, 4, 14, 4, "glass"); R(c, 12, 9, 14, 16, ["tw_bf", "green_l", "pink"][f])
    R(c, 17, 7, 18, 16, "glass_d"); R(c, 19, 6, 19, 8, "glass"); R(c, 17, 11, 18, 16, "f1")
    R(c, 2, 16, 21, 17, "wood_d"); R(c, 3, 17, 20, 17, "wood_x")
    for x, y in [[(5, 2), (14, 2)], [(6, 1), (13, 3)], [(4, 3), (15, 1)]][f]:
        c.put(x, y, "smoke")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_star_lamp", "星辰燈", C4, 1, 18, 32, 4, 3, level=LV)
def _(c, f):
    R(c, 8, 13, 9, 28, "gold_d"); R(c, 5, 28, 12, 30, "gold_d"); R(c, 5, 28, 12, 28, "gold")
    circle(c, 8.5, 8, 6.4, "tw_night", 6.4); circle(c, 8.2, 7.7, 5.6, "tw_night_l", 5.6)
    for k, (x, y) in enumerate(((5, 5), (10, 4), (7, 9), (11, 10), (4, 11))):
        c.put(x, y, "f4" if (k + f) % 2 else "f1")
    R(c, 6, 13, 11, 14, "gold")


@item("l7_floating_candles", "浮空蠟燭", C4, 2, 32, 26, 4, 4, level=LV, ceiling=True, note="飄在半空、不會滴蠟的蠟燭")
def _(c, f):
    for n, (x, y) in enumerate(((4, 6), (11, 14), (18, 4), (25, 12), (8, 20), (22, 20))):
        yy = y + [0, 1, 0, -1][(f + n) % 4]
        R(c, x, yy, x + 2, yy + 5, "cloth"); R(c, x, yy, x + 2, yy, "white"); flame(c, x + 1, yy - 1, 3, f + n, 0)
    for x, y in ((14, 10), (2, 14), (28, 6), (15, 22)):
        c.put(x, y + f % 2, "tw_arc_l")


@item("l7_crystal_chandelier", "魔晶吊燈", C4, 4, 48, 34, 3, 3, level=LV, ceiling=True)
def _(c, f):
    R(c, 23, 0, 24, 6, "gold_d"); R(c, 6, 7, 41, 9, "gold"); R(c, 6, 7, 41, 7, "gold_l")
    for x in range(8, 41, 8):
        R(c, x, 10, x, 14, "gold_d"); circle(c, x, 17, 3, "tw_arc", 3.4); circle(c, x, 17, 2, ["tw_arc_l", "tw_bf_l", "white"][(f + x // 8) % 3], 2.4)
    for x in range(12, 38, 6):
        R(c, x, 10, x, 11 + (x % 3), "glass_d"); c.put(x, 12 + (x % 3), "glass")
    R(c, 21, 10, 26, 12, "gold"); R(c, 22, 13, 25, 22, "tw_arc"); R(c, 23, 23, 24, 28, "tw_arc_l"); circle(c, 23.5, 30, 2.4, ["tw_bf", "tw_arc_l", "white"][f], 2.4)


@item("l7_rune_brazier", "符文火盆", C4, 2, 26, 32, 3, 5, level=LV, note="燒著藍色火焰的符文火盆")
def _(c, f):
    for r in range(7):
        R(c, 4 + r // 2, 14 + r, 21 - r // 2, 14 + r, "stone_d" if r else "stone_l")
    R(c, 11, 21, 14, 28, "stone_d"); R(c, 7, 28, 18, 31, "stone_d")
    R(c, 6, 16, 6, 16, "tw_bf") if False else None
    for x in (8, 12, 16):
        c.put(x, 17, "tw_bf_l")
    for x, h in ((8, 8), (12, 12), (16, 9)):
        for i in range(h + f % 2):
            w = 1 if i < h - 2 else 0
            R(c, x - w, 13 - i, x + w, 13 - i, "tw_bf_d" if i < 3 else ("tw_bf" if i < h - 2 else "tw_bf_l"))


@item("l7_moonbeam_pillar", "月光柱", C4, 1, 16, 42, 3, 3, level=LV)
def _(c, f):
    R(c, 6, 14, 9, 36, "marble"); R(c, 6, 14, 6, 36, "white"); R(c, 9, 15, 9, 36, "marble_d")
    R(c, 3, 36, 12, 40, "marble_d"); R(c, 3, 36, 12, 36, "marble"); R(c, 4, 10, 11, 14, "marble"); R(c, 4, 10, 11, 10, "white")
    circle(c, 7.5, 6, 4, "moon" if "moon" in P else "white", 4); circle(c, 7.5, 6, 2.6, ["white", "f4", "white"][f], 2.6)
    for x, y in ((2, 4), (13, 8), (1, 10)):
        c.put(x, y + f % 2, "tw_arc_l")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_astrolabe", "星盤掛飾", C5, 2, 32, 32, 4, 2, level=LV, wall=True, note="慢慢轉動的黃銅星盤")
def _(c, f):
    circle(c, 15.5, 15.5, 14.5, "gold_d", 14.5); circle(c, 15.5, 15.5, 13.4, "gold", 13.4); circle(c, 15.5, 15.5, 10, "tw_night", 10)
    for i in range(24):
        a = i * math.pi / 12
        c.put(round(15 + math.cos(a) * 12), round(15 + math.sin(a) * 12), "gold_d")
    ang = f * math.pi / 8
    for r in range(1, 10):
        c.put(round(15 + math.cos(ang) * r), round(15 + math.sin(ang) * r), "gold_l"); c.put(round(15 - math.cos(ang) * r), round(15 - math.sin(ang) * r), "gold_l")
    for x, y in ((9, 10), (21, 12), (12, 21), (20, 20)):
        c.put(x, y, "f4")
    circle(c, 15.5, 15.5, 1.8, "gold_l", 1.8)


@item("l7_dragon_banner", "龍旗", C5, 2, 24, 46, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 22, 3, "gold_d"); R(c, 1, 1, 22, 1, "gold"); R(c, 3, 4, 20, 34, "tw_night"); R(c, 3, 4, 20, 4, "gold"); R(c, 3, 4, 3, 34, "tw_night_l"); R(c, 20, 4, 20, 34, "tw_night_l")
    for r in range(10):
        R(c, 3 + r, 35 + r, 11, 35 + r, "tw_night"); R(c, 12, 35 + r, 20 - r, 35 + r, "tw_night")
    for i in range(18):
        x, y = 8 + int(round(5 * math.sin(i / 3.0))), 8 + i
        c.put(x, y, "tw_dragon_l"); c.put(x + 1, y, "tw_dragon")
    circle(c, 13, 8, 3, "tw_dragon_l", 3); c.put(14, 7, "f1"); R(c, 7, 22, 9, 24, "tw_dragon_d")


@item("l7_constellation_map", "星座圖", C5, 4, 50, 32, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 48, 30, "gold_d"); R(c, 3, 3, 46, 28, "tw_night")
    import random
    rng = random.Random(21)
    for _ in range(50):
        c.put(rng.randrange(4, 45), rng.randrange(4, 27), "white" if rng.random() < 0.5 else "tw_arc_l")
    pts = [(8, 20), (14, 14), (20, 16), (26, 9), (33, 12), (40, 7)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            c.put(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), "gold_d")
    for x, y in pts:
        circle(c, x, y, 1.4, "f1", 1.4)
    circle(c, 38, 22, 3, "moon" if "moon" in P else "white", 3)


@item("l7_portal_mirror", "傳送鏡", C5, 2, 30, 42, 3, 3, level=LV, wall=True)
def _(c, f):
    circle(c, 14.5, 18, 13, "tw_arc_d", 17); circle(c, 14.5, 18, 11.8, "tw_arc", 15.6)
    circle(c, 14.5, 18, 9.6, "tw_night", 13)
    for i in range(14):
        a = i * 2 * math.pi / 14 + f * 0.7
        r = 3 + (i % 5)
        c.put(round(14 + math.cos(a) * r), round(18 + math.sin(a) * r * 1.4), "tw_bf_l" if i % 2 else "tw_arc_l")
    R(c, 10, 34, 18, 37, "gold_d"); R(c, 12, 37, 16, 40, "gold")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_summoning_circle", "召喚法陣", C6, 4, 46, 36, 4, 3, level=LV, flat=True)
def _(c, f):
    circle(c, 22.5, 17.5, 21.5, "tw_night", 16); circle(c, 22.5, 17.5, 19.6, "tw_arc_d", 14.2); circle(c, 22.5, 17.5, 17.2, "tw_night", 12.4)
    for i in range(10):
        a = i * math.pi / 5 + f * 0.1
        c.put(round(22 + math.cos(a) * 15), round(17 + math.sin(a) * 11), "tw_bf_l" if (i + f) % 2 else "tw_bf")
    pts = [(22 + math.cos(i * 2 * math.pi / 5 - math.pi / 2) * 12, 17 + math.sin(i * 2 * math.pi / 5 - math.pi / 2) * 9) for i in range(5)]
    for i in range(5):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 2) % 5]
        n = int(max(abs(x1 - x0), abs(y1 - y0)))
        for j in range(n + 1):
            c.put(round(x0 + (x1 - x0) * j / n), round(y0 + (y1 - y0) * j / n), "tw_arc_l" if f % 2 else "tw_arc")
    circle(c, 22.5, 17.5, 2.8, ["tw_bf", "tw_arc_l", "white", "tw_bf_l"][f], 2)


@item("l7_star_carpet", "星辰長地毯", C6, 4, 48, 32, 2, 2, level=LV, flat=True)
def _(c, f):
    rug_base(c, 48, 32, "tw_night", "gold", "tw_night_l", False)
    import random
    rng = random.Random(17)
    for i in range(36):
        x, y = rng.randrange(4, 44), rng.randrange(4, 28)
        c.put(x, y, "f4" if (i + f) % 2 else "f1")
        if i % 6 == 0:
            c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "gold")


@item("l7_dragon_rug", "龍紋地毯", C6, 2, 38, 28, level=LV, flat=True)
def _(c, f):
    rug_base(c, 38, 28, "tw_dragon_d", "gold", "tw_dragon", True)
    for i in range(24):
        a = i / 23 * 2 * math.pi * 1.6
        x, y = 19 + math.cos(a) * (3 + i * 0.5), 14 + math.sin(a) * (2 + i * 0.3)
        c.put(round(x), round(y), "gold" if i % 3 else "gold_l")
    circle(c, 19, 14, 2, "gold_l", 2)


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_world_tree", "世界樹苗", C7, 4, 44, 58, 2, 2, level=LV, note="葉子會發光的世界樹幼苗")
def _(c, f):
    R(c, 19, 28, 25, 54, "wood_d"); R(c, 19, 28, 21, 54, "wood"); R(c, 14, 50, 19, 55, "wood_d"); R(c, 25, 50, 30, 55, "wood_d")
    blob(c, 22, 15, 20, "green", "green_d", "green_l", 14); blob(c, 8, 24, 8, "green", "green_d", "green_l", 6); blob(c, 36, 24, 8, "green", "green_d", "green_l", 6)
    for k, (x, y) in enumerate(((10, 10), (28, 8), (22, 4), (36, 16), (6, 20), (18, 22), (30, 20), (14, 14))):
        c.put(x, y, "tw_bf_l" if (k + f) % 2 else "f4"); c.put(x + 1, y + 1, "f1")
    R(c, 14, 55, 30, 56, "dirt")


@item("l7_glow_vines", "發光藤蔓", C7, 2, 24, 36, 2, 2, level=LV)
def _(c, f):
    for x0 in (6, 12, 18):
        for y in range(2, 32):
            c.put(x0 + int(round(2 * math.sin(y / 4.0 + x0))), y, "green_d"); c.put(x0 + 1 + int(round(2 * math.sin(y / 4.0 + x0))), y, "green")
    for k, (x, y) in enumerate(((5, 8), (14, 12), (20, 6), (9, 20), (18, 24), (13, 30))):
        circle(c, x, y, 1.6, "tw_bf_l" if (k + f) % 2 else "tw_bf", 1.6)
    R(c, 3, 31, 21, 34, "pot"); R(c, 3, 31, 21, 31, "pot_d")


@item("l7_moon_lily", "月光蓮", C7, 1, 20, 24, 3, 3, level=LV)
def _(c, f):
    R(c, 9, 12, 10, 20, "green_d")
    for dx, dy in ((-5, 0), (-3, -3), (3, -3), (5, 0), (0, -4)):
        R(c, 9 + dx - 1, 8 + dy, 10 + dx + 1, 12 + dy // 2, "white" if abs(dx) < 4 else "snow"); c.put(9 + dx, 8 + dy, "tw_bf_l")
    circle(c, 9.5, 10, 2, ["f1", "f4", "tw_bf_l"][f], 2)
    R(c, 3, 18, 8, 19, "green"); R(c, 11, 19, 17, 20, "green"); R(c, 2, 21, 17, 22, "water_l")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_dragon_skeleton", "龍骨標本", C8, 4, 54, 44, level=LV, note="整副巨龍的骨架")
def _(c, f):
    R(c, 4, 38, 49, 42, "stone_d"); R(c, 4, 38, 49, 38, "stone")
    for i in range(24):
        x = 8 + i * 2
        y = 28 + int(round(3 * math.sin(i / 4.0)))
        c.put(x, y, "tw_bone"); c.put(x + 1, y, "tw_bone"); R(c, x, y + 1, x, 36, "tw_bone_d") if i % 2 == 0 else None
    for x in range(10, 44, 4):
        R(c, x, 22 + (x % 3), x + 1, 29, "tw_bone"); R(c, x + 1, 22 + (x % 3), x + 1, 28, "tw_bone_d")
    circle(c, 46, 14, 6, "tw_bone", 5); R(c, 49, 14, 52, 17, "tw_bone"); R(c, 44, 8, 45, 12, "tw_bone_d"); R(c, 47, 7, 48, 11, "tw_bone_d"); c.cells([(46, 12), (47, 12)], "black")
    for x in range(48, 53, 2):
        c.put(x, 17, "white")
    R(c, 44, 18, 47, 28, "tw_bone"); R(c, 10, 30, 20, 37, "tw_bone_d"); R(c, 30, 30, 40, 37, "tw_bone_d")
    for x in range(1, 8):
        c.put(8 - x, 29 + x // 2, "tw_bone")
    R(c, 14, 8, 24, 10, "tw_bone_d"); R(c, 14, 9, 14, 24, "tw_bone"); R(c, 22, 9, 22, 22, "tw_bone"); R(c, 28, 10, 38, 11, "tw_bone_d")


@item("l7_archmage_statue", "大法師像", C8, 2, 28, 50, level=LV)
def _(c, f):
    plinth(c, 4, 23, 42, 49)
    circle(c, 13.5, 11, 4, "marble"); R(c, 6, 5, 21, 8, "marble_d"); R(c, 10, 2, 17, 5, "marble_d")
    R(c, 8, 15, 19, 34, "marble"); R(c, 19, 15, 19, 34, "marble_d"); R(c, 5, 17, 8, 30, "marble_d")
    R(c, 21, 4, 22, 38, "gold_d"); circle(c, 21.5, 3, 3, "tw_arc_l", 3); c.put(21, 2, "white")
    R(c, 9, 35, 18, 41, "marble_d"); c.cells([(12, 10), (15, 10)], "marble_x")


@item("l7_crystal_obelisk", "水晶方尖碑", C8, 2, 22, 48, 3, 3, level=LV)
def _(c, f):
    plinth(c, 3, 18, 38, 47)
    for r in range(34):
        half = 3 + (r * 2) // 12 if r > 4 else 1 + r // 2
        R(c, 10 - half, 3 + r, 11 + half, 3 + r, "tw_arc" if r % 5 else "tw_arc_l")
        c.put(10 - half, 3 + r, "tw_arc_l"); c.put(11 + half, 3 + r, "tw_arc_d")
    for y in (12, 22, 30):
        c.cells([(8, y), (9, y + 1), (12, y)], ["tw_bf", "tw_bf_l", "white"][(f + y) % 3])
    for x, y in (([3, 6], [18, 14]) if f else ([2, 12], [19, 8])):
        c.put(x, y, "tw_arc_l")


@item("l7_golden_dragon", "金龍像", C8, 4, 46, 44, level=LV)
def _(c, f):
    plinth(c, 3, 42, 36, 43)
    R(c, 8, 22, 36, 33, "gold"); R(c, 8, 22, 36, 22, "gold_l"); R(c, 36, 23, 36, 33, "gold_d")
    for i in range(18):
        R(c, 6 - i // 3, 24 + i // 2, 8, 25 + i // 2, "gold_d")
    circle(c, 34, 14, 5, "gold", 5); R(c, 38, 14, 43, 17, "gold"); R(c, 33, 6, 34, 10, "gold_l"); R(c, 36, 5, 37, 9, "gold_l"); c.cells([(35, 13), (36, 13)], "black")
    R(c, 33, 18, 36, 24, "gold"); R(c, 14, 14, 24, 23, "gold_d"); R(c, 18, 9, 28, 14, "gold_d")
    R(c, 12, 34, 16, 39, "gold_d"); R(c, 26, 34, 30, 39, "gold"); R(c, 40, 18, 43, 20, "red_l") if False else None
    for x, y in ((38, 20), (40, 21)):
        c.put(x, y, "f2")


@item("l7_starfall_monument", "隕星紀念碑", C8, 2, 26, 40, 2, 2, level=LV)
def _(c, f):
    plinth(c, 3, 22, 30, 39)
    R(c, 7, 22, 18, 29, "stone"); R(c, 7, 22, 18, 22, "stone_l"); R(c, 18, 23, 18, 29, "stone_d")
    for r in range(11):
        half = 2 + r // 2 if r < 8 else 6 - (r - 8)
        R(c, 12 - half, 12 + r, 13 + half, 12 + r, "tw_arc" if r % 3 else "tw_arc_d")
    circle(c, 12.5, 10, 4, "tw_arc_l", 5)
    for k in range(6):
        c.put(2 + k * 4, 3 + (k * 2 + f) % 5, "f4" if k % 2 else "f1")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_telescope", "大型望遠鏡", C9, 2, 34, 46, level=LV)
def _(c, f):
    for i in range(26):
        c.put(6 + i, 22 - i * 5 // 6 - 2, "gold_d"); c.put(6 + i, 23 - i * 5 // 6 - 2, "gold"); c.put(6 + i, 24 - i * 5 // 6 - 2, "gold_d")
    R(c, 28, 2, 32, 6, "gold_d"); R(c, 28, 2, 32, 2, "gold_l")
    R(c, 15, 26, 18, 38, "iron_d"); R(c, 12, 26, 21, 27, "iron"); R(c, 5, 38, 28, 40, "iron_d")
    R(c, 7, 40, 10, 44, "iron_d"); R(c, 23, 40, 26, 44, "iron_d"); R(c, 15, 38, 18, 44, "iron_d")
    circle(c, 6, 22, 2.2, "glass", 2.2)


@item("l7_orrery_big", "太陽系儀", C9, 4, 46, 42, 4, 3, level=LV, note="行星繞著太陽慢慢轉")
def _(c, f):
    R(c, 20, 30, 25, 38, "gold_d"); R(c, 10, 38, 35, 40, "gold_d"); R(c, 10, 38, 35, 38, "gold")
    circle(c, 22.5, 19, 4, "f1", 4); circle(c, 22.5, 19, 2.6, "f4", 2.6)
    for k, (r, col, sz) in enumerate(((8, "tw_bf", 1.4), (13, "red_l", 1.8), (18, "green_l", 2.2), (21, "pink", 1.6))):
        for i in range(36):
            a = i * 2 * math.pi / 36
            if i % 2 == 0:
                c.put(round(22 + math.cos(a) * r), round(19 + math.sin(a) * r * 0.55), "gold_d")
        a = f * math.pi / 2 * (1 - k * 0.2) + k * 1.7
        circle(c, 22 + math.cos(a) * r, 19 + math.sin(a) * r * 0.55, sz, col, sz)


@item("l7_scrying_pool", "預言水盆", C9, 2, 30, 26, 3, 3, level=LV)
def _(c, f):
    circle(c, 14.5, 12, 13, "stone_d", 8); circle(c, 14.5, 11, 12, "stone_l", 7); circle(c, 14.5, 11, 9.6, "tw_arc_d", 5.8); circle(c, 14.5, 11, 8.4, "tw_night", 4.8)
    for k in range(5):
        c.put(8 + (k * 3 + f * 2) % 14, 9 + (k + f) % 4, ["tw_bf_l", "white", "tw_arc_l"][k % 3])
    R(c, 11, 18, 18, 24, "stone"); R(c, 8, 24, 21, 25, "stone_d")


@item("l7_dragon_nest", "龍蛋巢", C9, 2, 30, 24, 3, 3, level=LV, note="巢裡的龍蛋偶爾會亮一下")
def _(c, f):
    circle(c, 14.5, 17, 13, "wood_d", 6); circle(c, 14.5, 16, 12, "hay", 5.4); circle(c, 14.5, 16, 8, "wood", 3.6)
    for x in range(4, 26, 3):
        R(c, x, 14 + (x % 2), x + 2, 15 + (x % 2), "wood_d")
    circle(c, 14.5, 10, 5.2, "tw_dragon_d", 6.6); circle(c, 14.2, 9.6, 4.4, "tw_dragon", 5.8)
    for x, y in ((12, 7), (15, 9), (11, 12), (16, 13)):
        c.put(x, y, "tw_dragon_l")
    if f == 1:
        circle(c, 14.5, 10, 2.6, "f1", 3.4)
    elif f == 2:
        c.cells([(14, 4), (15, 3), (9, 8), (20, 8)], "f4")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_big_cauldron", "魔法大鍋", C10, 2, 34, 34, 4, 4, level=LV)
def _(c, f):
    circle(c, 16.5, 21, 14, "iron_d", 11); circle(c, 16.5, 20, 13, "iron", 10); R(c, 3, 13, 30, 15, "iron_l")
    R(c, 4, 12, 29, 14, "iron_d"); R(c, 5, 11, 28, 12, ["green_l", "tw_bf", "tw_arc_l", "pink"][f])
    R(c, 3, 11, 3, 24, "iron_d") if False else None
    for x in (7, 14, 22):
        R(c, x, 31, x + 3, 33, "iron_d")
    R(c, 6, 32, 27, 33, ["f3", "f2", "f3", "f2"][f])
    for x, y in [[(10, 6), (20, 3), (15, 8)], [(11, 4), (21, 6), (16, 2)], [(9, 7), (19, 5), (14, 1)], [(12, 5), (22, 2), (17, 7)]][f]:
        circle(c, x, y, 1.6, ["green_l", "tw_bf", "tw_arc_l", "pink"][f], 1.6)


@item("l7_elixir_fountain", "靈藥噴泉", C10, 2, 28, 40, 3, 4, level=LV)
def _(c, f):
    R(c, 3, 32, 24, 38, "stone"); R(c, 3, 32, 24, 32, "stone_l"); R(c, 24, 33, 24, 38, "stone_d"); R(c, 4, 33, 23, 35, "tw_bf")
    R(c, 11, 18, 14, 32, "stone_l"); R(c, 6, 17, 19, 19, "stone"); R(c, 7, 18, 18, 18, "tw_bf_l")
    R(c, 10, 8, 15, 17, "stone"); R(c, 8, 7, 17, 9, "stone_l")
    for x, k in ((10, 0), (13, 1), (16, 2)):
        for y in range(2, 8):
            if (y + f + k) % 3:
                c.put(x, y, "tw_bf_l" if y % 2 else "tw_bf")
    for x in (5, 20):
        c.put(x, 26 + f % 2, "tw_bf")


@item("l7_star_tea", "星光茶席", C10, 2, 34, 26, 2, 2, level=LV)
def _(c, f):
    R(c, 3, 12, 30, 15, "tw_night_l"); R(c, 3, 12, 30, 12, "tw_arc_l"); R(c, 3, 16, 30, 24, "tw_night"); R(c, 3, 16, 30, 16, "tw_night_l")
    for x in range(5, 29, 5):
        c.put(x, 19 + (x // 5) % 2, "f4" if (x // 5 + f) % 2 else "f1")
    R(c, 6, 6, 11, 11, "tw_arc"); R(c, 11, 7, 13, 8, "tw_arc"); R(c, 7, 4, 10, 5, "tw_arc_d")
    for x in (16, 21):
        R(c, x, 8, x + 2, 11, "glass_d"); c.put(x + 1, 9, "f1")
    R(c, 24, 8, 29, 11, "cloth"); circle(c, 26, 8, 1.6, "tw_bf_l"); circle(c, 28, 8, 1.6, "pink")
    c.put(18, 4 - f, "f4")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_tower_window", "塔頂圓窗", C11, 2, 30, 32, level=LV, wall=True)
def _(c, f):
    circle(c, 14.5, 15.5, 14, "stone_d", 14); circle(c, 14.5, 15.5, 12.4, "stone", 12.4); circle(c, 14.5, 15.5, 9.6, "tw_night", 9.6)
    for x, y in ((9, 9), (17, 8), (12, 17), (19, 15), (8, 20)):
        c.put(x, y, "f4")
    circle(c, 17, 11, 2.4, "moon" if "moon" in P else "white", 2.4)
    R(c, 14, 6, 15, 25, "stone_d"); R(c, 5, 15, 24, 16, "stone_d")


@item("l7_portal_gate", "傳送門", C11, 4, 44, 52, 4, 4, level=LV, note="通往不知道哪裡的魔法門")
def _(c, f):
    R(c, 2, 14, 9, 50, "stone"); R(c, 2, 14, 2, 50, "stone_l"); R(c, 9, 15, 9, 50, "stone_d"); R(c, 34, 14, 41, 50, "stone"); R(c, 34, 14, 34, 50, "stone_l"); R(c, 41, 15, 41, 50, "stone_d")
    for r in range(15):
        half = int(round(math.sqrt(max(0, 15 ** 2 - r ** 2))))
        R(c, 22 - half, 14 - r, 21 + half, 14 - r, "stone" if r % 3 else "stone_l")
    R(c, 10, 14, 33, 50, "tw_night"); R(c, 12, 4, 31, 13, "tw_night")
    for i in range(30):
        a = i * 0.45 + f * 1.1
        r = 3 + (i * 0.7) % 9
        c.put(round(21.5 + math.cos(a) * r), round(30 + math.sin(a) * r * 1.5), ["tw_bf_l", "tw_arc_l", "white", "tw_bf"][i % 4])
    for x in (4, 6, 36, 38):
        c.put(x, 22, "tw_bf_l" if (x + f) % 2 else "tw_arc_l"); c.put(x, 32, "tw_arc_l" if (x + f) % 2 else "tw_bf_l")


@item("l7_spiral_stair", "螺旋梯", C11, 4, 38, 56, level=LV)
def _(c, f):
    R(c, 16, 4, 21, 52, "stone_d"); R(c, 16, 4, 16, 52, "stone"); 
    for i in range(10):
        y = 48 - i * 4
        x0 = 8 if i % 2 == 0 else 20
        R(c, x0, y, x0 + 10, y + 2, "stone_l"); R(c, x0, y + 2, x0 + 10, y + 3, "stone_d"); R(c, x0 + 10, y + 1, x0 + 10, y + 3, "stone_x")
    R(c, 6, 52, 32, 54, "stone_d"); R(c, 6, 52, 32, 52, "stone")
    R(c, 9, 4, 28, 6, "wood"); R(c, 17, 1, 20, 4, "gold")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_weathervane", "風向雞", C12, 1, 22, 38, 2, 3, level=LV)
def _(c, f):
    R(c, 10, 14, 11, 34, "iron_d"); R(c, 10, 14, 10, 34, "iron"); R(c, 6, 34, 15, 36, "stone_d")
    R(c, 3, 18, 18, 18, "iron_d"); R(c, 10, 16, 11, 20, "iron"); c.cells([(3, 17), (2, 18), (3, 19)], "iron_l"); c.cells([(18, 17), (19, 18), (18, 19)], "iron_l")
    sh = f
    circle(c, 10.5 + sh, 9, 3.4, "gold", 3.4); R(c, 13 + sh, 9, 16 + sh, 10, "gold_d"); R(c, 6 + sh, 6, 9 + sh, 7, "red_l"); R(c, 6 + sh, 7, 8 + sh, 12, "gold_d"); c.put(11 + sh, 8, "black")
    R(c, 9, 12, 12, 14, "gold_d")


@item("l7_gargoyle", "石像鬼", C12, 1, 22, 30, level=LV)
def _(c, f):
    R(c, 4, 22, 17, 28, "stone_d"); R(c, 4, 22, 17, 22, "stone")
    R(c, 6, 10, 15, 22, "stone"); R(c, 6, 10, 15, 10, "stone_l"); R(c, 15, 11, 15, 22, "stone_d")
    R(c, 7, 4, 14, 10, "stone"); R(c, 6, 1, 8, 4, "stone_d"); R(c, 13, 1, 15, 4, "stone_d"); R(c, 8, 6, 9, 7, "tw_bf"); R(c, 12, 6, 13, 7, "tw_bf"); R(c, 9, 8, 12, 9, "stone_x")
    for r in range(8):
        R(c, 0 + r // 2, 11 + r, 5, 11 + r, "stone_d"); R(c, 16, 11 + r, 20 - r // 2, 11 + r, "stone_d")


@item("l7_rooftop_rail", "屋頂石欄", C12, 2, 42, 22, level=LV)
def _(c, f):
    R(c, 1, 3, 40, 6, "stone"); R(c, 1, 3, 40, 3, "stone_l"); R(c, 1, 18, 40, 20, "stone_d")
    for x in range(1, 40, 6):
        R(c, x, 0, x + 2, 3, "stone_l"); R(c, x, 7, x + 3, 17, "stone")
        R(c, x, 7, x, 17, "stone_l"); R(c, x + 3, 8, x + 3, 17, "stone_d")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l7_baby_dragon", "小龍", C13, 1, 26, 26, 4, 3, level=LV, note="會打噴嚏噴小火花的小龍")
def _(c, f):
    circle(c, 12, 16, 7, "tw_dragon_d", 6); circle(c, 11.6, 15.6, 6, "tw_dragon", 5); R(c, 7, 17, 15, 21, "gold") if False else R(c, 8, 17, 15, 21, "tw_dragon_l")
    circle(c, 19, 9, 4, "tw_dragon", 4); R(c, 21, 9, 24, 11, "tw_dragon_d"); c.put(19, 8, "black"); R(c, 17, 4, 18, 6, "gold"); R(c, 20, 4, 21, 6, "gold")
    wing = [(4, 10), (3, 8)] if f in (1, 2) else [(4, 12), (3, 13)]
    for x, y in wing:
        R(c, x, y, x + 4, y + 2, "tw_dragon_d")
    R(c, 3, 19, 6, 20, "tw_dragon_d"); c.cells([(2, 20 - f % 2), (1, 19)], "tw_dragon_d")
    R(c, 9, 22, 10, 24, "tw_dragon_d"); R(c, 14, 22, 15, 24, "tw_dragon_d")
    if f == 3:
        c.cells([(25, 10), (24, 9), (25, 8)], "f1"); c.put(24, 11, "f2")


@item("l7_phoenix", "鳳凰", C13, 2, 36, 36, 4, 3, level=LV)
def _(c, f):
    up = [0, 2, 4, 2][f]
    circle(c, 18, 20, 6, "tw_dragon_l", 7); circle(c, 17.6, 19.6, 5, "orange", 6); circle(c, 18, 11, 3.6, "tw_dragon_l", 3.6); R(c, 21, 11, 24, 12, "gold"); c.put(19, 10, "black")
    R(c, 17, 5, 18, 8, "f1"); R(c, 19, 4, 20, 7, "f2")
    for i in range(10):
        R(c, 12 - i, 18 - up - i // 3 + i // 2, 12, 20 - up + i // 4, "tw_dragon_l" if i % 2 else "f2")
        R(c, 24, 18 - up - i // 3 + i // 2, 24 + i, 20 - up + i // 4, "tw_dragon_l" if i % 2 else "f2")
    for i in range(12):
        c.put(16 + (i % 3), 26 + i, "f2" if i % 2 else "tw_dragon_l"); c.put(19 + ((i + f) % 3), 26 + i, "f1" if i % 2 else "f3")
    for x, y in ((4, 6), (31, 8), (8, 28)):
        c.put(x, y + f, "f4")


@item("l7_familiar_owl", "使魔貓頭鷹", C13, 1, 18, 28, 3, 2, level=LV)
def _(c, f):
    R(c, 3, 22, 14, 23, "wood"); R(c, 8, 23, 9, 26, "wood_d"); R(c, 4, 26, 13, 27, "wood_x")
    circle(c, 8.5, 14, 6.4, "fur_d", 8); circle(c, 8.2, 14.6, 4.4, "fur_l", 5.6)
    circle(c, 5.6, 9, 2.4, "white", 2.4); circle(c, 11.4, 9, 2.4, "white", 2.4)
    for x in (6, 11):
        c.put(x, 9, "black" if f != 1 else "fur_d"); c.put(x - 1, 9, "tw_arc_l") if f == 2 else None
    R(c, 8, 10, 9, 12, "gold_d"); R(c, 4, 4, 5, 6, "fur_d"); R(c, 12, 4, 13, 6, "fur_d")
    R(c, 7, 21, 7, 22, "gold_d"); R(c, 11, 21, 11, 22, "gold_d"); c.put(8, 4, "tw_arc_l")


@item("l7_star_sprite", "星之精靈", C13, 1, 16, 20, 4, 4, level=LV)
def _(c, f):
    bob = [0, -1, 0, 1][f]
    circle(c, 7.5, 9 + bob, 3.6, "f4", 3.6); circle(c, 7.5, 9 + bob, 2.4, "f1", 2.4)
    c.cells([(6, 8 + bob), (9, 8 + bob)], "black"); c.put(7, 10 + bob, "pink")
    for i in range(5):
        a = i * 2 * math.pi / 5 - math.pi / 2 + f * 0.3
        c.put(round(7 + math.cos(a) * 6), round(9 + bob + math.sin(a) * 6), "f4" if i % 2 else "f1")
    R(c, 3, 14 + bob, 4, 17 + bob, "tw_bf_l"); R(c, 11, 14 + bob, 12, 17 + bob, "tw_bf_l")
    for x, y in [[(1, 4), (13, 16)], [(2, 15), (14, 5)], [(0, 9), (12, 18)], [(13, 12), (3, 3)]][f]:
        c.put(x, y, "tw_arc_l")
