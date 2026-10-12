"""Guild level 5 unlocks: the banquet hall (GUILD.md §4.1) — 50 pieces. Run make_guild_decor.py."""
from guild_decor_kit import *  # noqa: F401,F403
import math

C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13 = "辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"
LV = 5
add_colors({"banq_cloth": (244, 238, 224), "banq_cloth_d": (206, 196, 176), "wine": (130, 30, 60), "wine_d": (88, 18, 42), "ice_sw": (200, 236, 252), "ice_sw_d": (140, 196, 232), "choco": (96, 56, 40), "choco_l": (140, 88, 60), "cake": (252, 240, 228), "cake_d": (226, 206, 190), "peacock": (40, 140, 160), "peacock_d": (24, 96, 120)})


# ── 辦公桌椅 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_banquet_table", "宴會長桌", C1, 4, 52, 32, level=LV, note="鋪著白桌巾的宴會長桌")
def _(c, f):
    R(c, 1, 9, 50, 15, "banq_cloth"); R(c, 1, 9, 50, 9, "white"); R(c, 50, 10, 50, 15, "banq_cloth_d")
    R(c, 2, 16, 49, 29, "banq_cloth"); R(c, 2, 16, 49, 16, "banq_cloth_d")
    for x in range(3, 49, 4):
        R(c, x, 17, x, 28, "banq_cloth_d")
    R(c, 2, 28, 49, 29, "gold_d") if False else R(c, 2, 29, 49, 30, "gold_d")
    for x in (6, 17, 28, 39):
        circle(c, x + 1, 11, 2.2, "white", 1.4); circle(c, x + 1, 11, 1.4, "silver", 0.9)
    R(c, 22, 3, 26, 8, "silver"); R(c, 23, 1, 25, 3, "f2"); c.put(24, 0, "f1"); R(c, 23, 8, 25, 9, "silver_d")


@item("l5_banquet_chair", "宴會椅", C1, 1, 18, 30, level=LV, seat=True)
def _(c, f):
    h = 30
    sy = h - 1 - SEAT_UP
    R(c, 3, 1, 14, 15, "wine"); R(c, 3, 1, 14, 1, "gold"); R(c, 3, 1, 3, 15, "gold_d"); R(c, 14, 1, 14, 15, "gold_d"); R(c, 6, 4, 11, 12, "wine_d"); c.put(8, 8, "gold"); c.put(9, 8, "gold")
    R(c, 2, sy, 15, sy + 2, "wine"); R(c, 2, sy, 15, sy, "velvet_l"); R(c, 2, sy + 3, 15, sy + 3, "gold_d")
    legs(c, (3, 14), sy + 4, h - 2, "gold_d"); R(c, 2, h - 1, 4, h - 1, "gold_d"); R(c, 13, h - 1, 15, h - 1, "gold_d"); R(c, 3, 16, 3, sy, "gold_d"); R(c, 14, 16, 14, sy, "gold_d")


@item("l5_vip_seat", "貴賓座椅", C1, 2, 28, 40, level=LV, seat=True)
def _(c, f):
    h = 40
    sy = h - 1 - SEAT_UP
    for r in range(18):
        half = 7 + min(r, 5)
        R(c, 14 - half, 2 + r, 13 + half, 2 + r, "gold" if r < 2 else "wine")
    R(c, 4, 2, 23, 3, "gold_l"); R(c, 4, 4, 5, sy, "gold_d"); R(c, 22, 4, 23, sy, "gold_d"); R(c, 8, 7, 19, 16, "wine_d"); circle(c, 13.5, 11, 2.8, "gold"); R(c, 13, 9, 14, 13, "wine")
    for x0 in (1, 23):
        R(c, x0, 18, x0 + 3, h - 2, "wine"); R(c, x0, 18, x0 + 3, 18, "gold")
    R(c, 5, sy, 22, sy, "velvet_l"); R(c, 5, sy + 1, 22, h - 2, "wine"); R(c, 1, h - 1, 26, h - 1, "gold_d")


# ── 櫃子收納 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_wine_rack", "酒窖架", C2, 2, 32, 40, level=LV)
def _(c, f):
    box(c, 1, 1, 30, 38, "wood_x", "wood", "wood_x")
    for r in range(6):
        for col in range(4):
            x, y = 3 + col * 7, 3 + r * 6
            circle(c, x + 2, y + 2, 2.4, "wood_d", 2.4); circle(c, x + 2, y + 2, 1.6, ["wine", "green_d", "gold_d", "wine_d"][(r + col) % 4], 1.6); c.put(x + 1, y + 1, "white") if (r + col) % 3 == 0 else None
    R(c, 0, 39, 31, 39, "wood_x")


@item("l5_silver_cabinet", "銀器櫃", C2, 2, 30, 40, level=LV)
def _(c, f):
    frame_border(c, 1, 1, 28, 38, "dark")
    R(c, 3, 3, 26, 22, "glass"); R(c, 3, 3, 5, 22, "white"); R(c, 3, 12, 26, 13, "dark")
    for x in (7, 13, 19):
        R(c, x, 6, x + 3, 11, "silver"); R(c, x + 1, 4, x + 2, 5, "silver_d"); R(c, x, 15, x + 4, 21, "silver"); R(c, x, 15, x + 4, 15, "white")
    drawers(c, 3, 24, 26, 36, 2, "dark", "gold")


@item("l5_pantry_shelf", "食品儲藏架", C2, 2, 32, 36, level=LV)
def _(c, f):
    box(c, 1, 1, 30, 34, "wood", "wood_l", "wood_d")
    for i, y in enumerate((3, 12, 21)):
        R(c, 3, y, 28, y + 7, "wood_x"); R(c, 2, y + 8, 29, y + 8, "wood_l")
    for x, k in ((4, "red"), (9, "pomelo"), (14, "orange"), (19, "green"), (24, "red_l")):
        R(c, x, 4, x + 3, 9, "glass_d"); R(c, x + 1, 5, x + 2, 9, k); R(c, x, 3, x + 3, 3, "wood_d")
    for x in (5, 12, 19):
        R(c, x, 14, x + 5, 19, "straw"); R(c, x, 14, x + 5, 14, "straw_d")
    R(c, 4, 23, 12, 28, "cloth"); circle(c, 20, 25, 3, "wood"); R(c, 24, 23, 27, 28, "iron_l")


@item("l5_buffet_cabinet", "自助餐檯", C2, 4, 50, 34, level=LV)
def _(c, f):
    R(c, 1, 12, 48, 16, "dark_l"); R(c, 1, 12, 48, 12, "wood_l")
    R(c, 2, 17, 47, 31, "dark"); R(c, 2, 17, 47, 17, "dark_d")
    for x in range(4, 46, 8):
        R(c, x, 19, x + 6, 29, "dark_d"); R(c, x, 19, x + 6, 19, "dark_l"); c.put(x + 3, 24, "gold")
    for x, k in ((4, "straw"), (13, "red_l"), (22, "pink"), (31, "green_l"), (40, "gold")):
        R(c, x, 7, x + 6, 11, "silver"); R(c, x, 7, x + 6, 7, "white"); R(c, x + 1, 5, x + 5, 6, k)
    R(c, 1, 32, 48, 33, "wood_x")


# ── 桌上小物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_candle_set", "桌上燭台組", C3, 1, 20, 22, 3, 5, level=LV)
def _(c, f):
    for x, h in ((3, 10), (9, 14), (15, 10)):
        R(c, x, 20 - h, x + 1, 17, "cloth"); R(c, x - 1, 18, x + 2, 19, "silver"); R(c, x, 20, x + 1, 20, "silver_d")
        flame(c, x, 20 - h - 1, 3, f + x, 0)
    R(c, 3, 17, 16, 17, "silver"); R(c, 8, 18, 10, 20, "silver_d")


@item("l5_roast_platter", "銀盤烤雞", C3, 1, 20, 16, level=LV)
def _(c, f):
    R(c, 1, 11, 18, 13, "silver"); R(c, 1, 11, 18, 11, "white"); R(c, 3, 13, 16, 14, "silver_d")
    circle(c, 9.5, 8, 5, "orange", 3.6); circle(c, 9.2, 7.6, 4.2, "straw", 3); R(c, 4, 9, 6, 11, "orange"); R(c, 13, 9, 15, 11, "orange"); c.put(8, 6, "straw_d")
    for x in (3, 15):
        circle(c, x, 10, 1.4, "green")


@item("l5_wine_set", "酒瓶與酒杯", C3, 1, 20, 16, level=LV)
def _(c, f):
    R(c, 3, 5, 6, 13, "wine_d"); R(c, 3, 5, 6, 5, "wine"); R(c, 4, 1, 5, 4, "wine_d"); R(c, 4, 0, 5, 1, "gold_d")
    for x in (10, 14):
        R(c, x, 4, x + 3, 7, "glass"); R(c, x + 1, 5, x + 2, 7, "wine"); R(c, x + 1, 8, x + 2, 11, "glass_d"); R(c, x - 1, 12, x + 4, 12, "glass_d")
    R(c, 2, 13, 17, 13, "wood_d")


@item("l5_centerpiece", "桌中花飾", C3, 1, 16, 20, level=LV)
def _(c, f):
    R(c, 6, 14, 9, 17, "silver"); R(c, 4, 17, 11, 18, "silver_d"); R(c, 3, 10, 12, 13, "silver"); R(c, 3, 10, 12, 10, "white")
    for x, y, k in ((4, 7, "red_l"), (8, 4, "pink"), (11, 7, "f1"), (6, 9, "white"), (10, 10, "red_l")):
        circle(c, x, y, 2.2, k); c.put(x, y, "f1" if k != "f1" else "orange")
    R(c, 7, 8, 8, 10, "green_d")


# ── 燈具 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_grand_chandelier", "水晶大吊燈", C4, 4, 50, 36, 3, 4, level=LV, ceiling=True)
def _(c, f):
    R(c, 24, 0, 25, 7, "gold_d")
    for k, (y, hw) in enumerate(((8, 22), (15, 16), (21, 9))):
        R(c, 24 - hw, y, 25 + hw, y + 1, "gold"); R(c, 24 - hw, y, 25 + hw, y, "gold_l")
    for x in range(4, 46, 6):
        R(c, x, 4, x + 1, 8, "cloth"); flame(c, x, 3, 3, f + x, 0)
    for x in range(5, 45, 4):
        R(c, x, 10, x, 12 + (x % 3), "glass_d"); c.put(x, 13 + (x % 3), "glass")
        c.put(x, 12, "glass_d")
    for x in range(14, 36, 3):
        c.put(x, 17, "glass_d"); c.put(x, 18 + (x % 2), "glass")
    R(c, 22, 22, 27, 24, "gold"); R(c, 23, 25, 26, 28, "glass"); R(c, 24, 29, 25, 32, "glass_d"); circle(c, 24.5, 33, 1.6, "glass")
    for x, y in [[(8, 13), (40, 14)], [(16, 12), (34, 16)], [(12, 15), (38, 12)]][f % 3]:
        c.put(x, y, "white")


@item("l5_wall_torches", "壁燭台", C4, 1, 18, 26, 3, 5, level=LV, wall=True)
def _(c, f):
    R(c, 7, 12, 10, 24, "gold_d"); R(c, 7, 12, 7, 24, "gold"); R(c, 3, 10, 14, 12, "gold"); R(c, 3, 10, 14, 10, "gold_l")
    for x in (4, 12):
        R(c, x, 5, x + 1, 9, "cloth"); flame(c, x, 4, 3, f + x, 0)
    R(c, 8, 7, 9, 10, "cloth"); flame(c, 8, 6, 3, f + 1, 0)
    R(c, 6, 24, 11, 25, "gold_d")


@item("l5_standing_candelabra", "落地燭臺", C4, 2, 22, 42, 3, 5, level=LV)
def _(c, f):
    R(c, 10, 14, 11, 36, "gold_d"); R(c, 10, 14, 10, 36, "gold"); R(c, 6, 36, 15, 38, "gold_d"); R(c, 4, 38, 17, 40, "gold_d"); R(c, 4, 38, 17, 38, "gold")
    R(c, 2, 12, 19, 13, "gold"); R(c, 2, 10, 2, 12, "gold"); R(c, 19, 10, 19, 12, "gold"); R(c, 10, 8, 11, 12, "gold")
    for x in (2, 6, 10, 15, 19):
        R(c, x, 6 if x not in (10, 11) else 4, x, 9, "cloth"); flame(c, x, 5 if x not in (10, 11) else 3, 3, f + x, 0)


@item("l5_festive_lights", "宴會燈串", C4, 2, 44, 18, 2, 3, level=LV, ceiling=True)
def _(c, f):
    for x in range(0, 44):
        R(c, x, 1 + int(round(3 * math.sin(x / 7.0))) + 2, x, 1 + int(round(3 * math.sin(x / 7.0))) + 2, "gold_d")
    for n, x in enumerate(range(3, 42, 5)):
        y = 3 + int(round(3 * math.sin(x / 7.0))) + 2
        circle(c, x, y + 3, 2.4, "f1" if (n + f) % 2 else "f2"); c.put(x, y + 2, "f4")


@item("l5_glass_pendant", "彩玻吊燈", C4, 1, 18, 32, 2, 2, level=LV, ceiling=True)
def _(c, f):
    R(c, 8, 0, 9, 8, "gold_d")
    cols = ["red_l", "blue_l", "green_l", "f1"]
    for r in range(10):
        half = 1 + (r * 7) // 9
        for x in range(9 - half, 9 + half):
            c.put(x, 9 + r, cols[(x + r + f) % 4])
    R(c, 3, 19, 14, 20, "gold_d"); R(c, 6, 21, 11, 24, "f1" if f else "f2"); R(c, 8, 25, 9, 30, "gold")


# ── 牆上掛飾 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_great_tapestry", "巨幅掛毯", C5, 4, 46, 44, level=LV, wall=True)
def _(c, f):
    R(c, 1, 0, 44, 2, "gold_d"); R(c, 1, 0, 44, 0, "gold"); R(c, 3, 3, 42, 40, "wine"); R(c, 3, 3, 42, 5, "gold"); R(c, 3, 38, 42, 40, "gold")
    R(c, 6, 8, 39, 35, "wine_d")
    circle(c, 22.5, 20, 9, "gold_d", 9); circle(c, 22.5, 20, 7.6, "blue_d", 7.6)
    for i in range(8):
        a = i * math.pi / 4
        c.put(round(22 + math.cos(a) * 11), round(20 + math.sin(a) * 11), "gold")
    R(c, 20, 14, 25, 26, "f1"); R(c, 18, 18, 27, 20, "f1"); R(c, 21, 15, 24, 25, "f2")
    for x in range(4, 42, 3):
        c.put(x, 41, "gold"); c.put(x, 42, "gold_d")


@item("l5_portrait_row", "歷代會長像", C5, 4, 52, 30, level=LV, wall=True)
def _(c, f):
    for n, x0 in enumerate((2, 19, 36)):
        frame_border(c, x0, 2, x0 + 13, 26, "gold")
        R(c, x0 + 2, 4, x0 + 11, 24, ["blue_d", "green_d", "velvet_d"][n])
        circle(c, x0 + 6.5, 12, 3.6, "skin"); R(c, x0 + 4, 8, x0 + 9, 9, ["brown", "black", "straw_d"][n]); R(c, x0 + 3, 16, x0 + 10, 24, ["red", "blue", "gold_d"][n])
        c.cells([(x0 + 5, 12), (x0 + 8, 12)], "black")
        R(c, x0 + 4, 27, x0 + 9, 28, "gold_d")


@item("l5_gilded_mirror", "鍍金大鏡", C5, 2, 28, 38, level=LV, wall=True)
def _(c, f):
    circle(c, 13.5, 16, 12, "gold_d", 15); circle(c, 13.5, 16, 10.8, "gold", 13.8)
    circle(c, 13.5, 16, 9, "glass", 12); circle(c, 13.5, 16, 8.4, "white", 11.4)
    R(c, 7, 8, 9, 12, "glass"); R(c, 10, 7, 11, 9, "glass"); c.cells([(18, 24), (17, 25), (16, 26)], "glass_d")
    R(c, 11, 31, 16, 34, "gold"); R(c, 9, 34, 18, 36, "gold_d"); R(c, 11, 0, 16, 2, "gold_l")


@item("l5_banner_set", "宴會旗組", C5, 2, 36, 36, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 34, 2, "gold_d")
    for n, x0 in enumerate((3, 14, 25)):
        R(c, x0, 3, x0 + 7, 24, ["red", "blue", "xgreen" if "xgreen" in P else "green"][n])
        for r in range(5):
            R(c, x0 + r, 25 + r, x0 + 3, 25 + r, ["red", "blue", "green"][n]); R(c, x0 + 4, 25 + r, x0 + 7 - r, 25 + r, ["red", "blue", "green"][n])
        R(c, x0, 3, x0 + 7, 3, "gold"); circle(c, x0 + 3.5, 12, 2.4, "gold"); c.put(x0 + 3, 11, "gold_l")


# ── 地毯 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_red_carpet", "貴賓紅毯", C6, 4, 24, 58, level=LV, flat=True)
def _(c, f):
    rug_base(c, 24, 58, "wine", "gold", "wine_d", True)
    for y in range(8, 52, 10):
        c.cells([(11, y), (12, y), (10, y + 1), (13, y + 1), (11, y + 2), (12, y + 2)], "gold")
    R(c, 6, 5, 17, 5, "gold_d"); R(c, 6, 52, 17, 52, "gold_d")


@item("l5_ballroom_rug", "舞廳大地毯", C6, 4, 52, 36, level=LV, flat=True)
def _(c, f):
    rug_base(c, 52, 36, "navy_cloth" if "navy_cloth" in P else "blue_d", "gold", None, True)
    circle(c, 25.5, 17.5, 14, "gold_d", 11); circle(c, 25.5, 17.5, 12.6, "blue" if "blue" in P else "blue_d", 9.8); circle(c, 25.5, 17.5, 7, "cloth", 5)
    for i in range(8):
        a = i * math.pi / 4
        c.put(round(25 + math.cos(a) * 9), round(17 + math.sin(a) * 7), "gold")
    circle(c, 25.5, 17.5, 2.8, "gold", 2)


@item("l5_gold_rug", "金紋地毯", C6, 2, 36, 28, level=LV, flat=True)
def _(c, f):
    rug_base(c, 36, 28, "wine", "gold", "gold_d", False)
    for i in range(3):
        R(c, 8 + i * 4, 7 + i * 3, 27 - i * 4, 20 - i * 3, "gold" if i % 2 == 0 else "wine_d")
    R(c, 15, 12, 20, 15, "gold_l")


# ── 植物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_palm", "棕櫚盆栽", C7, 2, 30, 46, level=LV)
def _(c, f):
    R(c, 13, 16, 15, 38, "wood_d"); R(c, 13, 16, 13, 38, "wood")
    for dx, dy, l in ((-1, 0, 11), (1, 0, 11), (-1, -3, 9), (1, -3, 9), (0, -5, 6)):
        for i in range(1, l):
            c.put(14 + dx * i, 14 + dy + int(i * i / 14), "green" if i % 2 else "green_d"); c.put(14 + dx * i, 15 + dy + int(i * i / 14), "green_d")
    blob(c, 14.5, 12, 3.4, "green", "green_d", "green_l")
    R(c, 7, 38, 21, 44, "pot"); R(c, 7, 38, 21, 39, "pot_d"); R(c, 21, 40, 21, 44, "pot_d"); R(c, 9, 41, 19, 42, "gold_d")


@item("l5_flower_stand", "花架", C7, 2, 24, 40, level=LV)
def _(c, f):
    R(c, 10, 6, 11, 34, "wood_d"); R(c, 3, 32, 18, 34, "wood")
    for y, w in ((8, 6), (18, 8), (28, 9)):
        R(c, 10 - w, y, 11 + w, y + 2, "wood_l"); R(c, 10 - w, y, 11 + w, y, "wood")
        for x in range(10 - w + 1, 11 + w, 4):
            circle(c, x, y - 2, 2.2, ["red_l", "pink", "f1", "lavender", "white"][(x + y) % 5]); c.put(x, y - 2, "f1")
            R(c, x, y - 1, x, y, "green_d")


@item("l5_topiary", "造型灌木", C7, 1, 20, 34, level=LV)
def _(c, f):
    R(c, 9, 20, 10, 28, "wood_d")
    blob(c, 9.5, 8, 6.4, "green", "green_d", "green_l", 6); blob(c, 9.5, 17, 4.6, "green", "green_d", "green_l", 4)
    R(c, 4, 28, 15, 32, "stone_l"); R(c, 4, 28, 15, 28, "stone"); R(c, 15, 29, 15, 32, "stone_d")


# ── 雕像與紀念物 ──────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_ice_swan", "冰雕天鵝", C8, 2, 28, 36, 2, 2, level=LV)
def _(c, f):
    R(c, 3, 28, 24, 34, "ice_sw_d"); R(c, 3, 28, 24, 28, "ice_sw"); R(c, 24, 29, 24, 34, "ice_sw_d")
    circle(c, 13, 22, 8, "ice_sw", 5); circle(c, 12.6, 21.6, 6.8, "white", 4.4)
    for i in range(8):
        c.put(19 + i // 4, 16 - i, "ice_sw"); c.put(20 + i // 4, 16 - i, "ice_sw_d")
    circle(c, 20, 8, 3, "ice_sw", 3); R(c, 22, 8, 25, 9, "ice_sw_d"); c.put(20, 7, "black")
    R(c, 3, 20, 7, 24, "ice_sw_d")
    for x, y in (([5, 12], [18, 25], [11, 16]) if f else ([8, 14], [22, 22], [14, 26])):
        c.put(x, y, "white")


@item("l5_golden_statue", "金色雕像", C8, 2, 26, 46, level=LV)
def _(c, f):
    plinth(c, 4, 21, 36, 45)
    circle(c, 12.5, 8, 4, "gold_l"); R(c, 8, 12, 17, 26, "gold"); R(c, 17, 12, 17, 26, "gold_d")
    R(c, 17, 4, 20, 14, "gold_l"); circle(c, 19.5, 4, 3, "gold_l"); R(c, 5, 13, 7, 24, "gold_d")
    R(c, 9, 27, 11, 35, "gold"); R(c, 14, 27, 16, 35, "gold_d"); c.cells([(11, 7), (14, 7)], "gold_d"); R(c, 9, 40, 16, 41, "gold")


@item("l5_chocolate_fountain", "巧克力噴泉", C8, 2, 26, 38, 3, 4, level=LV)
def _(c, f):
    R(c, 3, 30, 22, 36, "silver"); R(c, 3, 30, 22, 30, "white"); R(c, 22, 31, 22, 36, "silver_d")
    for y, w in ((8, 5), (16, 8), (24, 11)):
        R(c, 12 - w, y, 13 + w, y + 2, "silver"); R(c, 12 - w, y, 13 + w, y, "white"); R(c, 12 - w + 1, y + 2, 13 + w - 1, y + 5, "choco")
    R(c, 11, 2, 14, 7, "choco_l")
    for k, x in enumerate((6, 12, 19)):
        c.put(x, 10 + (f + k) % 3, "choco_l"); c.put(x, 18 + (f + k) % 3, "choco_l")
    R(c, 4, 31, 21, 34, "choco"); R(c, 4, 31, 21, 31, "choco_l")


@item("l5_knight_pair", "雙騎士盔甲", C8, 2, 36, 44, level=LV)
def _(c, f):
    for x0 in (3, 21):
        R(c, x0 + 3, 5, x0 + 8, 12, "steel"); R(c, x0 + 3, 5, x0 + 8, 5, "steel_l"); R(c, x0 + 3, 8, x0 + 8, 8, "black"); R(c, x0 + 5, 2, x0 + 6, 5, "red")
        R(c, x0, 13, x0 + 11, 28, "steel"); R(c, x0 + 11, 14, x0 + 11, 28, "steel_d"); R(c, x0, 13, x0 + 11, 14, "steel_l")
        R(c, x0 + 2, 29, x0 + 4, 40, "steel_d"); R(c, x0 + 7, 29, x0 + 9, 40, "steel"); R(c, x0 + 1, 40, x0 + 10, 41, "stone_d")
        R(c, x0 - 2, 14, x0 - 1, 24, "steel_d"); R(c, x0 + 12, 14, x0 + 13, 24, "steel_d")
    R(c, 12, 4, 13, 38, "wood_d"); R(c, 11, 2, 14, 4, "steel_l"); R(c, 30, 4, 31, 38, "wood_d"); R(c, 29, 2, 32, 4, "steel_l")


# ── 休閒娛樂 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_stage", "樂隊舞台", C9, 4, 52, 34, level=LV)
def _(c, f):
    R(c, 1, 8, 50, 22, "wood_l"); R(c, 1, 8, 50, 9, "wood"); R(c, 50, 10, 50, 22, "wood_d")
    R(c, 1, 23, 50, 31, "wood_d"); R(c, 1, 23, 50, 23, "wood")
    for x in range(3, 50, 6):
        R(c, x, 25, x + 3, 29, "wood_x")
    R(c, 1, 31, 50, 32, "wood_x")
    R(c, 3, 3, 6, 7, "gold"); R(c, 45, 3, 48, 7, "gold"); R(c, 4, 2, 5, 3, "gold_l"); R(c, 46, 2, 47, 3, "gold_l")
    for x in (14, 25, 36):
        R(c, x, 5, x + 1, 7, "iron_d"); R(c, x - 1, 3, x + 2, 4, "silver")


@item("l5_grand_piano", "三角鋼琴", C9, 4, 48, 36, level=LV)
def _(c, f):
    for r in range(14):
        R(c, 3, 3 + r, 44 - r, 3 + r, "black" if r else "iron_d")
    R(c, 3, 3, 44, 3, "iron"); R(c, 37, 8, 44, 18, "black"); R(c, 44, 3, 44, 14, "iron_d")
    R(c, 3, 17, 40, 19, "iron_d"); R(c, 5, 19, 38, 21, "white")
    for x in range(5, 38, 2):
        c.put(x, 20, "black") if (x // 2) % 7 not in (2, 6) else None
        R(c, x, 20, x, 21, "snow_d")
    R(c, 8, 22, 34, 23, "black")
    legs(c, (6, 36), 24, 32, "iron_d"); R(c, 5, 33, 8, 34, "iron_d"); R(c, 34, 33, 37, 34, "iron_d"); R(c, 20, 22, 22, 32, "iron_d")
    R(c, 14, 6, 20, 7, "iron_l")


@item("l5_cello", "大提琴", C9, 1, 16, 34, level=LV)
def _(c, f):
    circle(c, 8, 14, 6, "wood_d", 6); circle(c, 8, 24, 7.4, "wood_d", 8); circle(c, 8, 14, 5, "wood", 5); circle(c, 8, 24, 6.4, "wood", 7)
    R(c, 3, 19, 12, 21, "wood"); R(c, 7, 5, 8, 31, "iron_d"); R(c, 6, 1, 9, 5, "wood_d"); R(c, 7, 6, 7, 30, "cloth")
    R(c, 6, 26, 9, 27, "black"); R(c, 7, 32, 8, 33, "iron_l")
    for x in (4, 11):
        c.put(x, 22, "black")


@item("l5_dance_floor", "舞池地板", C9, 4, 46, 32, 2, 2, level=LV, flat=True)
def _(c, f):
    R(c, 1, 1, 44, 30, "iron_d")
    for y in range(2, 30, 4):
        for x in range(2, 44, 4):
            k = ["wine", "white", "gold", "blue"][((x // 4) + (y // 4) + f) % 4]
            R(c, x, y, x + 3, y + 3, k)
    R(c, 0, 0, 45, 0, "gold_d"); R(c, 0, 31, 45, 31, "gold_d")


@item("l5_music_stand", "樂譜架", C9, 1, 16, 30, level=LV)
def _(c, f):
    R(c, 7, 12, 8, 26, "iron_d"); R(c, 3, 26, 12, 28, "iron_d"); R(c, 2, 28, 4, 29, "iron_d"); R(c, 11, 28, 13, 29, "iron_d")
    R(c, 2, 3, 13, 11, "iron"); R(c, 2, 3, 13, 3, "iron_l"); R(c, 3, 4, 12, 10, "paper")
    for y in (5, 7, 9):
        R(c, 4, y, 11, y, "ink")
    c.cells([(6, 6), (9, 8)], "black")


# ── 廚房飲料 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_cake_tower", "三層蛋糕", C10, 2, 24, 40, level=LV)
def _(c, f):
    R(c, 4, 33, 19, 36, "silver"); R(c, 4, 33, 19, 33, "white"); R(c, 8, 28, 15, 32, "silver_d")
    for y, w in ((24, 8), (16, 6), (9, 4)):
        R(c, 11 - w, y, 12 + w, y + 6, "cake"); R(c, 11 - w, y, 12 + w, y, "white"); R(c, 12 + w, y + 1, 12 + w, y + 6, "cake_d")
        for x in range(11 - w + 1, 12 + w, 3):
            circle(c, x, y + 2, 1.2, "pink") if False else c.put(x, y + 2, "pink")
        R(c, 11 - w, y + 5, 12 + w, y + 5, "pink")
    R(c, 11, 4, 12, 8, "lred" if "lred" in P else "red"); circle(c, 11.5, 3, 2, "red_l"); c.put(11, 2, "white"); R(c, 10, 5, 13, 5, "xgreen" if "xgreen" in P else "green")


@item("l5_roast_table", "烤全豬餐桌", C10, 4, 50, 32, level=LV)
def _(c, f):
    R(c, 1, 12, 48, 17, "banq_cloth"); R(c, 1, 12, 48, 12, "white"); R(c, 2, 18, 47, 28, "banq_cloth"); R(c, 2, 18, 47, 18, "banq_cloth_d")
    for x in range(3, 47, 4):
        R(c, x, 19, x, 27, "banq_cloth_d")
    R(c, 2, 29, 47, 30, "gold_d")
    R(c, 12, 5, 36, 11, "silver"); R(c, 12, 5, 36, 5, "white")
    circle(c, 24, 6, 9, "orange", 4); circle(c, 23.6, 5.6, 8, "straw_d", 3.4); circle(c, 33, 6, 3, "orange", 3); c.cells([(34, 5), (35, 7)], "black")
    for x in (14, 19, 28):
        circle(c, x, 8, 1.4, "green")
    R(c, 4, 7, 9, 11, "silver"); circle(c, 6.5, 8, 2, "red_l"); R(c, 40, 7, 46, 11, "silver"); circle(c, 43, 8, 2.4, "straw")


@item("l5_barrel_stand", "酒桶架", C10, 2, 32, 30, level=LV)
def _(c, f):
    R(c, 1, 22, 30, 27, "wood_d"); R(c, 1, 22, 30, 22, "wood")
    for x0 in (3, 17):
        circle(c, x0 + 6, 13, 7, "wood_d", 8.4); circle(c, x0 + 6, 13, 6, "wood", 7.4)
        for dx in (-3, 0, 3):
            R(c, x0 + 6 + dx, 6, x0 + 6 + dx, 20, "wood_d")
        R(c, x0, 9, x0 + 12, 9, "iron_d"); R(c, x0, 17, x0 + 12, 17, "iron_d"); R(c, x0 + 5, 14, x0 + 7, 16, "gold_d")
    R(c, 2, 27, 5, 28, "wood_x"); R(c, 26, 27, 29, 28, "wood_x")


@item("l5_punch_bowl", "潘趣酒碗", C10, 1, 22, 20, 2, 2, level=LV)
def _(c, f):
    for r in range(8):
        R(c, 3 + r // 3, 6 + r, 18 - r // 3, 6 + r, "glass" if r else "white")
    R(c, 4, 7, 17, 11, "red_l"); R(c, 4, 7, 17, 7, "pink")
    R(c, 8, 14, 13, 15, "glass_d"); R(c, 6, 16, 15, 17, "glass_d")
    for x, y in (([7, 8], [12, 9]) if f else ([9, 9], [14, 8])):
        circle(c, x, y, 1.2, "orange")
    R(c, 18, 7, 20, 8, "silver"); R(c, 19, 9, 20, 13, "silver")


@item("l5_cheese_table", "起司拼盤桌", C10, 2, 36, 28, level=LV)
def _(c, f):
    table(c, 1, 11, 34, 27, "wood", depth=3)
    R(c, 3, 8, 13, 10, "cloth"); circle(c, 8, 7, 4, "f1", 3); R(c, 5, 6, 6, 7, "orange"); R(c, 9, 8, 10, 9, "orange")
    R(c, 16, 7, 23, 10, "straw"); R(c, 16, 7, 23, 7, "straw_d"); R(c, 17, 5, 22, 6, "f1")
    R(c, 25, 8, 32, 10, "cloth"); [circle(c, x, 7, 1.6, "red_d") for x in (27, 30)]
    R(c, 14, 12, 24, 13, "wood_d")


@item("l5_dessert_cart", "甜點推車", C10, 2, 32, 32, level=LV)
def _(c, f):
    for y in (8, 17, 26):
        R(c, 2, y, 29, y + 1, "silver"); R(c, 2, y, 29, y, "white")
    R(c, 3, 8, 4, 28, "silver_d"); R(c, 27, 8, 28, 28, "silver_d"); R(c, 28, 4, 30, 8, "silver_d")
    for x, k in ((6, "pink"), (12, "cake"), (18, "choco_l"), (24, "red_l")):
        R(c, x, 3, x + 3, 7, k); R(c, x, 3, x + 3, 3, "white")
    for x in (6, 14, 22):
        circle(c, x + 2, 14, 2.4, ["f1", "pink", "choco_l"][(x // 8) % 3])
    R(c, 6, 19, 24, 24, "cloth"); [circle(c, x, 21, 1.4, "red_l") for x in (9, 14, 19)]
    circle(c, 6, 30, 2, "iron_d"); circle(c, 25, 30, 2, "iron_d")


# ── 門窗與隔間 ────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_stage_curtain", "舞台大幕", C11, 4, 52, 46, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 50, 4, "gold_d"); R(c, 1, 1, 50, 1, "gold")
    for x0, x1 in ((1, 14), (37, 50)):
        R(c, x0, 5, x1, 44, "wine")
        for x in range(x0 + 1, x1, 2):
            R(c, x, 6, x, 43, "wine_d")
        R(c, x0, 5, x1, 5, "velvet_l")
    R(c, 14, 5, 36, 36, "wood_x") if False else R(c, 15, 5, 36, 40, "black")
    R(c, 17, 8, 34, 38, "iron_d")
    for x, y in ((20, 12), (27, 20), (31, 10), (23, 30)):
        c.put(x, y, "f1")
    for x in (14, 36):
        R(c, x, 20, x + 1, 21, "gold")


@item("l5_ornate_door", "華麗雙門", C11, 4, 46, 50, level=LV, wall=True)
def _(c, f):
    R(c, 1, 1, 44, 48, "gold_d"); R(c, 3, 3, 42, 48, "wine_d")
    for x0 in (5, 24):
        R(c, x0, 5, x0 + 16, 48, "wood"); R(c, x0, 5, x0 + 16, 5, "wood_l")
        for y0 in (8, 28):
            R(c, x0 + 2, y0, x0 + 14, y0 + 16, "wood_x"); R(c, x0 + 3, y0 + 1, x0 + 13, y0 + 15, "wood_d"); circle(c, x0 + 8, y0 + 8, 2.4, "gold")
    R(c, 22, 5, 23, 48, "gold"); circle(c, 20, 28, 1.6, "gold_l"); circle(c, 26, 28, 1.6, "gold_l")
    for r in range(6):
        R(c, 15 + r, 0 + r // 3, 30 - r, 0, "gold") if False else None
    R(c, 14, 1, 31, 4, "gold"); R(c, 18, 2, 27, 3, "gold_l")


@item("l5_arched_window", "彩窗大拱", C11, 2, 32, 46, level=LV, wall=True)
def _(c, f):
    R(c, 3, 14, 28, 44, "stone"); circle(c, 15.5, 14, 13, "stone", 12)
    cols = ["red_l", "blue_l", "green_l", "f1", "purple_l"]
    for y in range(6, 42):
        half = 11 if y > 14 else int(round(math.sqrt(max(0, 11 ** 2 - (14 - y) ** 2))))
        for x in range(15 - half, 17 + half):
            c.put(x, y, cols[((x // 3) + (y // 3)) % 5])
    R(c, 15, 4, 16, 42, "stone_d"); R(c, 5, 22, 26, 23, "stone_d"); R(c, 5, 32, 26, 33, "stone_d")
    R(c, 2, 42, 29, 45, "stone_l")


# ── 戶外 ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_gold_railing", "金色陽台欄杆", C12, 2, 42, 22, level=LV)
def _(c, f):
    R(c, 1, 3, 40, 5, "gold"); R(c, 1, 3, 40, 3, "gold_l"); R(c, 1, 18, 40, 20, "gold_d")
    for x in range(3, 39, 4):
        R(c, x, 6, x, 17, "gold_d"); circle(c, x, 8, 1.2, "gold") if False else c.put(x, 11, "gold")
    for x in (1, 38):
        R(c, x, 0, x + 2, 20, "gold"); circle(c, x + 1, 0, 1.6, "gold_l")


@item("l5_carriage_lamp", "馬車燈柱", C12, 1, 16, 40, 2, 2, level=LV)
def _(c, f):
    R(c, 7, 14, 8, 36, "iron_d"); R(c, 7, 14, 7, 36, "iron"); R(c, 4, 36, 11, 38, "iron_d")
    R(c, 3, 4, 12, 12, "gold_d"); R(c, 4, 5, 11, 11, "glass"); R(c, 5, 6, 10, 10, "f1" if f else "f2"); R(c, 7, 7, 8, 9, "f4")
    R(c, 3, 3, 12, 3, "gold"); R(c, 6, 1, 9, 2, "gold_d"); R(c, 5, 12, 10, 13, "gold_d")


# ── 會動的 ────────────────────────────────────────────────────────────────────────────────────────────────────────────────
@item("l5_swan", "天鵝", C13, 1, 24, 22, 4, 3, level=LV)
def _(c, f):
    b = [0, 1, 0, -1][f] // 1
    circle(c, 10, 15, 7, "white", 4.4); circle(c, 9.6, 14.6, 6, "snow", 3.6); R(c, 3, 14, 6, 16, "snow_d")
    for i in range(9):
        c.put(16 + i // 5, 14 - i + b, "white"); c.put(17 + i // 5, 14 - i + b, "snow_d")
    circle(c, 18, 4 + b, 2.4, "white", 2.4); R(c, 20, 4 + b, 23, 5 + b, "orange"); c.put(18, 3 + b, "black")
    R(c, 2, 19, 20, 20, "water_l") if f % 2 else R(c, 4, 19, 18, 20, "water_l")


@item("l5_peacock", "孔雀", C13, 2, 34, 34, 4, 3, level=LV)
def _(c, f):
    sp = [0, 1, 2, 1][f]
    for i in range(9):
        a = math.pi * (0.1 + i * 0.1)
        for r in range(8, 15 + (i % 2) + sp // 2):
            x, y = round(14 + math.cos(a) * r), round(17 - math.sin(a) * r)
            c.put(x, y, "peacock" if r < 14 else "xgreen" if "xgreen" in P else "green")
        x, y = round(14 + math.cos(a) * 13), round(17 - math.sin(a) * 13)
        c.put(x, y, "f1"); c.put(x, y + 1, "peacock_d")
    circle(c, 14, 22, 5, "peacock", 5); circle(c, 14, 14, 3, "peacock", 3) if False else None
    circle(c, 21, 15, 2.6, "peacock", 2.6); R(c, 22, 14, 25, 15, "orange") if False else R(c, 23, 15, 25, 15, "gold_d"); c.put(21, 14, "black"); R(c, 20, 11, 22, 12, "peacock_d")
    R(c, 12, 27, 12, 30, "gold_d"); R(c, 16, 27, 16, 30, "gold_d")


@item("l5_butler_golem", "管家魔偶", C13, 1, 22, 32, 3, 3, level=LV, note="端著托盤的管家魔偶")
def _(c, f):
    R(c, 6, 5, 15, 13, "stone"); R(c, 6, 5, 15, 5, "stone_l"); R(c, 15, 6, 15, 13, "stone_d"); R(c, 8, 8, 9, 9, "rune"); R(c, 12, 8, 13, 9, "rune"); R(c, 9, 11, 12, 11, "stone_x")
    R(c, 7, 0, 14, 3, "black"); R(c, 6, 4, 15, 4, "black")
    R(c, 5, 14, 16, 25, "black"); R(c, 5, 14, 16, 14, "iron"); R(c, 9, 14, 12, 20, "white"); R(c, 10, 16, 11, 16, "red")
    R(c, 7, 26, 9, 30, "stone_x"); R(c, 12, 26, 14, 30, "stone_x")
    y = 15 + (f % 2)
    R(c, 16, y, 20, y + 1, "stone_d"); R(c, 16, y - 1, 21, y - 1, "silver"); R(c, 17, y - 4, 19, y - 2, "red_l"); circle(c, 18, y - 5, 1.2, "f1") if f else None


@item("l5_giant_chess", "巨型西洋棋", C9, 2, 34, 26, level=LV, note="小朋友那麼高的棋子")
def _(c, f):
    R(c, 2, 14, 31, 23, "wood_d"); R(c, 2, 14, 31, 14, "wood")
    for y in range(15, 23, 2):
        for x in range(3, 31, 4):
            R(c, x + ((y // 2) % 2) * 2, y, x + 1 + ((y // 2) % 2) * 2, y + 1, "cloth")
    for x, y, k, kd, h in ((6, 14, "snow", "snow_d", 9), (13, 14, "snow", "snow_d", 7), (21, 14, "black", "iron_d", 8), (27, 14, "black", "iron_d", 10)):
        R(c, x - 1, y - h, x + 2, y, k); R(c, x + 2, y - h + 1, x + 2, y, kd); R(c, x, y - h - 2, x + 1, y - h - 1, k)
    R(c, 5, 5, 6, 6, "gold") if False else None
