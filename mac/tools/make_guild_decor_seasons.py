"""The guild's holiday decorations (GUILD.md §4.2, 節日限定): pieces put down only while their season is on (shared/src/guild-seasons.ts).
Drawn like the rest (make_guild_decor.py: 16-px tiles, the avatar is 32 x 40) and registered with the same `item`, so one run of

    python3 mac/tools/make_guild_decor.py

draws them, writes their strips to mac/Resources/Guild/decor, lists them in mac/tools/guild_decor_catalog.json (with their `season`)
and makes one overview per holiday, docs/images/guild/decor_holiday_<season>_overview.png, for the user to look at first.

First batch: 春節 and 中秋; second: 元宵, 端午, 國慶, 跨年, 聖誕.
"""
import make_guild_decor as gd
from make_guild_decor import P, R, circle, blob, flame, item, rug_base

# colours for the holidays (the festival red is brighter than the guild's red)
NEW = {
    "lred": (208, 48, 48), "lred_d": (150, 28, 38), "lred_l": (244, 104, 84),
    "pomelo": (214, 222, 112), "pomelo_d": (160, 178, 70), "pomelo_l": (242, 246, 168),
    "hv_moon": (255, 246, 196), "hv_moon_d": (232, 214, 140), "hv_moon_x": (200, 178, 104),
    "coal": (70, 42, 42), "meat": (192, 104, 72), "meat_d": (140, 70, 52),
    "smoke": (214, 214, 222), "smoke_d": (170, 170, 186),
    "hv_night": (40, 52, 110), "hv_night_d": (28, 36, 84),
    "orangeish": (244, 160, 50),
    "snow": (240, 246, 255), "snow_d": (190, 210, 236), "xgreen": (36, 116, 64), "xgreen_d": (22, 82, 46), "xgreen_l": (80, 164, 90),
    "ginger": (176, 112, 62), "ginger_d": (130, 78, 44), "icing": (252, 246, 238),
    "zong": (112, 164, 82), "zong_d": (70, 120, 56),
    "nd_blue": (26, 56, 152), "nd_red": (208, 40, 54), "nd_blue_d": (16, 36, 110),
    "sparkle": (255, 252, 210), "lotus": (248, 176, 200), "lotus_d": (222, 120, 160),
}
assert not set(NEW) & set(P), f"a colour name is already taken: {sorted(set(NEW) & set(P))}"   # (it would repaint the old pieces)
P.update(NEW)

C3, C4, C5, C6, C7, C8, C9, C10, C12, C13 = "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "戶外", "會動的"
SPRING, AUTUMN = "spring_festival", "mid_autumn"
LANTERN, DRAGON, NATIONAL, NEWYEAR, XMAS = "lantern", "dragon_boat", "national", "new_year", "christmas"
C1, C2 = "辦公桌椅", "櫃子收納"
C11 = "門窗與隔間"

# a few strokes that read as writing, 5 x 5 (for the couplets and the 福)
GLYPHS = [
    ["#####", "..#..", "#####", ".#.#.", "#...#"],
    ["..#..", "#####", "#.#.#", "#####", "..#.."],
    ["#.#.#", "#####", "..#..", "#####", "#...#"],
    ["#####", "#...#", "#####", "..#..", "#.#.#"],
    ["#.#..", "#####", "#.#.#", "#.#.#", "#...#"],
    [".###.", "#.#.#", ".###.", "#.#.#", "..#.."],
]


def glyph(c, x, y, k, n):
    for j, row in enumerate(GLYPHS[n % len(GLYPHS)]):
        for i, ch in enumerate(row):
            if ch == "#":
                c.put(x + i, y + j, k)


# ===========================================================================================================================
# 春節
# ===========================================================================================================================
@item("cny_lantern_string", "紅燈籠串", C4, 2, 40, 20, 2, 2, ceiling=True, season=SPRING, note="掛在天花板的四個紅燈籠")
def _(c, f):
    R(c, 1, 0, 38, 1, "gold_d"); R(c, 1, 0, 38, 0, "gold")
    for n, cx in enumerate((5, 15, 25, 35)):
        sway = 1 if (f + n) % 2 else 0
        R(c, cx, 2, cx, 3, "gold_d")
        R(c, cx - 2, 4, cx + 2, 4, "gold")
        circle(c, cx, 9, 4.5, "lred_d", 5)
        circle(c, cx - 0.5, 8.5, 3.8, "lred", 4.3)
        R(c, cx, 5, cx, 13, "lred_d")
        c.put(cx - 2, 7, "lred_l"); c.put(cx - 2, 8, "lred_l")
        if f:
            R(c, cx - 1, 7, cx + 1, 10, "f2")
        R(c, cx - 2, 14, cx + 2, 14, "gold")
        R(c, cx + sway, 15, cx + sway, 18, "gold"); c.put(cx + sway - 1, 19, "gold_d"); c.put(cx + sway + 1, 19, "gold_d")


@item("cny_big_lantern", "大紅燈籠", C4, 1, 16, 32, 2, 2, season=SPRING, note="立在地上的大燈籠")
def _(c, f):
    R(c, 7, 0, 8, 1, "gold"); R(c, 4, 2, 11, 3, "gold"); R(c, 4, 3, 11, 3, "gold_d")
    circle(c, 7.5, 11, 7.5, "lred_d", 8.5)
    circle(c, 7, 10.5, 6.6, "lred", 7.6)
    for x in (4, 7, 10):
        R(c, x, 5, x, 17, "lred_d")
    c.put(4, 7, "lred_l"); c.put(4, 8, "lred_l")
    if f:
        R(c, 5, 8, 10, 13, "f2"); R(c, 6, 9, 9, 12, "f1")
    R(c, 4, 19, 11, 20, "gold"); R(c, 4, 20, 11, 20, "gold_d")
    R(c, 7, 21, 8, 25, "gold"); c.put(6, 26, "gold_d"); c.put(9, 26, "gold_d")
    R(c, 6, 26, 9, 28, "wood_d"); R(c, 3, 29, 12, 31, "wood_x"); R(c, 3, 29, 12, 29, "wood_d")


@item("cny_couplets", "春聯", C5, 2, 32, 32, wall=True, season=SPRING, note="上下聯加橫批，金字")
def _(c, f):
    R(c, 8, 1, 23, 8, "lred"); R(c, 8, 1, 23, 1, "lred_l"); R(c, 8, 8, 23, 8, "lred_d")
    for i, x in enumerate((9, 14, 19)):
        glyph(c, x, 3, "gold", i)
    for x0, seed in ((2, 0), (22, 3)):
        R(c, x0, 10, x0 + 7, 31, "lred"); R(c, x0, 10, x0 + 7, 10, "lred_l"); R(c, x0 + 7, 11, x0 + 7, 31, "lred_d")
        for i in range(3):
            glyph(c, x0 + 1, 12 + i * 7, "gold", seed + i)


@item("cny_fu", "倒福", C5, 1, 16, 16, wall=True, season=SPRING, note="倒過來貼的福字")
def _(c, f):
    for y in range(15):
        half = min(y, 14 - y) + 1
        R(c, 8 - half, y, 7 + half, y, "lred")
        c.put(8 - half, y, "gold"); c.put(7 + half, y, "gold")
    R(c, 7, 0, 8, 0, "gold"); R(c, 7, 14, 8, 14, "gold")
    for j, row in enumerate(reversed(GLYPHS[0])):          # (upside down)
        for i, ch in enumerate(row):
            if ch == "#":
                c.put(5 + i, 5 + j, "gold")


@item("cny_firecrackers", "鞭炮串", C5, 1, 12, 28, 3, 5, wall=True, season=SPRING, note="最下面那顆在冒火花")
def _(c, f):
    R(c, 4, 0, 7, 1, "gold"); R(c, 5, 2, 6, 2, "brown")
    for n in range(5):
        y = 3 + n * 4
        R(c, 2, y, 9, y + 2, "lred"); R(c, 9, y, 9, y + 2, "lred_d"); R(c, 2, y, 9, y, "lred_l")
        R(c, 2, y + 1, 9, y + 1, "gold_d" if n % 2 else "lred")
    sparks = [[(5, 24), (7, 25), (4, 26), (8, 23)], [(6, 24), (3, 25), (8, 26), (5, 27)], [(4, 24), (7, 24), (6, 26), (9, 25)]][f]
    for x, y in sparks:
        c.put(x, y, "f1"); c.put(x, y + 1, "f2") if y < 27 else None
    c.put(6, 23, "f4")


@item("cny_mandarin_tree", "金桔盆栽", C7, 2, 22, 34, season=SPRING, note="結滿金桔、掛著紅包與金元寶的過年盆栽")
def _(c, f):
    blob(c, 11, 12, 9.5, "green", "green_d", "green_l", 11)
    for x, y in ((6, 8), (14, 6), (9, 14), (15, 12), (5, 15), (12, 19), (11, 9)):
        R(c, x, y, x + 1, y + 1, "orangeish"); c.put(x, y, "f1")
    R(c, 10, 22, 11, 26, "wood_d")
    R(c, 5, 26, 16, 33, "lred"); R(c, 5, 26, 16, 27, "gold"); R(c, 16, 28, 16, 33, "lred_d"); R(c, 6, 33, 15, 33, "lred_d")
    R(c, 8, 29, 13, 31, "gold_d"); R(c, 9, 29, 12, 30, "gold")
    R(c, 3, 9, 4, 12, "lred"); c.put(3, 9, "gold")                                   # a red envelope hung on a branch
    R(c, 17, 14, 18, 17, "lred"); c.put(18, 14, "gold")


@item("cny_envelopes", "紅包盤", C3, 1, 16, 12, season=SPRING, note="一盤紅包")
def _(c, f):
    R(c, 1, 8, 14, 10, "gold_d"); R(c, 2, 7, 13, 7, "gold"); R(c, 1, 8, 14, 8, "gold")
    R(c, 3, 2, 7, 7, "lred"); R(c, 3, 2, 7, 2, "lred_l"); R(c, 7, 3, 7, 7, "lred_d"); c.put(5, 4, "gold"); c.put(5, 5, "gold")
    R(c, 7, 1, 11, 6, "lred_d"); R(c, 7, 1, 11, 1, "lred"); c.put(9, 3, "gold"); c.put(9, 4, "gold")
    R(c, 10, 3, 13, 7, "lred"); R(c, 13, 4, 13, 7, "lred_d"); c.put(11, 5, "gold")


@item("cny_feast", "團圓年菜桌", C10, 4, 48, 30, 2, 2, season=SPRING, note="火鍋冒著煙、一桌子年菜")
def _(c, f):
    R(c, 2, 12, 45, 15, "lred_l"); R(c, 2, 12, 45, 12, "lred")                       # the cloth, the top
    R(c, 2, 16, 45, 24, "lred"); R(c, 2, 16, 45, 16, "lred_d"); R(c, 45, 17, 45, 24, "lred_d")
    for x in range(3, 45, 4):
        R(c, x, 25, x, 27, "gold")
    R(c, 4, 24, 43, 24, "gold_d")
    R(c, 4, 28, 6, 29, "wood_d"); R(c, 41, 28, 43, 29, "wood_d")
    # the hot pot in the middle, with steam
    circle(c, 23.5, 10, 7, "iron_d", 3.4); circle(c, 23.5, 9, 6, "iron", 2.8); R(c, 19, 9, 28, 10, "f2" if f else "lred")
    for x, y in (([21, 4], [24, 2], [27, 5]) if f else ([22, 3], [25, 5], [27, 2])):
        c.put(x, y, "smoke"); c.put(x, y + 1, "smoke_d")
    # a fish, dumplings, oranges, cups
    R(c, 4, 9, 14, 12, "cloth"); R(c, 6, 8, 12, 10, "orange"); c.put(12, 9, "brown"); c.put(7, 9, "white")
    R(c, 33, 9, 43, 12, "cloth"); [circle(c, x, 9, 1.8, "white") for x in (35, 38, 41)]
    for x in (16, 30):
        circle(c, x, 10, 2, "orangeish")
    R(c, 18, 12, 19, 12, "gold"); R(c, 30, 12, 31, 12, "gold")


@item("cny_lion_head", "舞獅頭", C8, 2, 24, 30, 3, 2, season=SPRING, note="會眨眼的舞獅頭")
def _(c, f):
    R(c, 7, 26, 16, 29, "wood_d"); R(c, 7, 26, 16, 26, "wood"); R(c, 5, 29, 18, 29, "wood_x")
    for x in range(2, 22, 2):                                                          # the white mane
        c.put(x, 2 + (x % 3), "white"); c.put(x, 3 + (x % 3), "cloth")
    circle(c, 11.5, 13, 10.5, "lred_d", 10.5)
    circle(c, 11.5, 12.5, 9.6, "lred", 9.6)
    R(c, 10, 1, 13, 4, "gold"); R(c, 11, 0, 12, 0, "gold_l")                            # the horn
    circle(c, 3, 8, 2.2, "lred_d"); circle(c, 20, 8, 2.2, "lred_d")                     # ears
    for ex in (6.5, 16.5):
        if f == 2:
            R(c, int(ex) - 2, 9, int(ex) + 2, 9, "black")
        else:
            circle(c, ex, 9.5, 2.6 if f == 0 else 1.6, "white", 2.6 if f == 0 else 1.4)
            c.put(int(ex), 10, "black"); c.put(int(ex) + 1, 10, "black")
    R(c, 10, 14, 13, 15, "gold_d")                                                     # nose
    R(c, 6, 18, 17, 21, "black"); R(c, 7, 18, 16, 19, "white")                          # the mouth, the teeth
    for x in range(7, 17, 3):
        c.put(x, 20, "white")
    R(c, 8, 22, 15, 23, "lred_l")


@item("cny_coin_rug", "金錢地毯", C6, 4, 40, 32, flat=True, season=SPRING, note="紅底、金色的古錢")
def _(c, f):
    rug_base(c, 40, 32, "lred", "gold", "lred_d")
    for cx in range(9, 36, 7):
        for cy in range(8, 28, 8):
            circle(c, cx, cy, 2.6, "gold"); R(c, cx - 1, cy - 1, cx, cy, "lred_d")


# ===========================================================================================================================
# 中秋
# ===========================================================================================================================
@item("ma_mooncakes", "月餅禮盒", C3, 1, 16, 12, season=AUTUMN, note="打開的月餅禮盒")
def _(c, f):
    R(c, 1, 5, 14, 11, "lred"); R(c, 1, 5, 14, 5, "gold"); R(c, 14, 6, 14, 11, "lred_d"); R(c, 1, 10, 14, 10, "gold_d")
    R(c, 2, 2, 13, 4, "wood_l")
    for x in (4, 8, 12):
        circle(c, x, 3.2, 2.2, "wood", 1.6); c.put(x, 3, "gold")
    R(c, 3, 7, 5, 8, "gold"); R(c, 10, 7, 12, 8, "gold")


@item("ma_pomelos", "柚子", C10, 1, 16, 16, season=AUTUMN, note="還有一頂柚子皮帽")
def _(c, f):
    circle(c, 5.5, 11, 4.6, "pomelo_d", 4.2); circle(c, 5, 10.5, 4, "pomelo", 3.7); c.put(3, 9, "pomelo_l"); c.put(4, 9, "pomelo_l")
    circle(c, 11, 12, 3.8, "pomelo_d", 3.5); circle(c, 10.6, 11.6, 3.2, "pomelo", 3); c.put(9, 10, "pomelo_l")
    # the peel hat on top: a dome with a hole
    circle(c, 8, 4, 3.4, "yellow", 2.6); R(c, 5, 5, 11, 6, "yellow"); R(c, 6, 6, 10, 6, "pomelo_d"); R(c, 7, 4, 8, 5, "pomelo_d")
    c.put(6, 2, "pomelo_l")


@item("ma_bbq", "中秋烤肉架", C12, 2, 26, 26, 3, 5, season=AUTUMN, note="冒著煙的烤肉架")
def _(c, f):
    R(c, 3, 14, 22, 15, "iron_l"); R(c, 3, 15, 22, 15, "iron")
    R(c, 3, 16, 22, 20, "iron_d"); R(c, 4, 17, 21, 19, "coal")
    for x in range(5, 21, 3):
        c.put(x + (f % 2), 18, "f3"); c.put(x + 1, 17, "f2" if (x + f) % 2 else "f3")
    for x in (4, 21):
        R(c, x, 21, x, 25, "iron_d")
    R(c, 4, 25, 5, 25, "iron"); R(c, 20, 25, 21, 25, "iron")
    for x0 in (5, 11, 17):                                                             # skewers of meat and corn
        R(c, x0, 12, x0 + 3, 13, "meat"); R(c, x0, 12, x0 + 3, 12, "meat_d"); R(c, x0 + 1, 13, x0 + 2, 13, "yellow")
    R(c, 3, 11, 22, 11, "wood")
    smoke = [[(8, 8), (9, 6), (15, 7)], [(9, 7), (10, 4), (16, 5)], [(8, 6), (11, 3), (15, 4)]][f]
    for x, y in smoke:
        c.put(x, y, "smoke"); c.put(x + 1, y - 1, "smoke_d")


@item("ma_big_moon", "大圓月", C5, 2, 32, 32, 2, 1, wall=True, season=AUTUMN, note="掛在牆上的滿月，月亮上有玉兔")
def _(c, f):
    if f:
        circle(c, 15.5, 15.5, 15.5, "f4")
    circle(c, 15.5, 15.5, 14, "hv_moon_d"); circle(c, 15, 15, 13, "hv_moon")
    for x, y in ((9, 9), (22, 11), (10, 22), (23, 21), (17, 6)):
        circle(c, x, y, 1.4, "hv_moon_d")
    R(c, 13, 9, 14, 14, "hv_moon_x"); R(c, 17, 10, 18, 14, "hv_moon_x")                      # the rabbit's ears
    R(c, 12, 14, 19, 22, "hv_moon_x"); R(c, 11, 18, 12, 22, "hv_moon_x"); R(c, 19, 20, 22, 21, "hv_moon_x")


@item("ma_jade_rabbit", "玉兔搗藥", C13, 1, 18, 20, 4, 3, season=AUTUMN, note="拿著杵搗藥的小白兔")
def _(c, f):
    up = [0, 2, 4, 2][f]
    R(c, 3, 15, 12, 18, "stone"); R(c, 2, 14, 13, 14, "stone_l"); R(c, 3, 18, 12, 18, "stone_d")      # the mortar
    R(c, 11, 3 + up, 12, 12 + up, "wood"); R(c, 10, 2 + up, 13, 3 + up, "wood_l")                      # the pestle
    R(c, 3, 1, 4, 6, "white"); R(c, 4, 2, 4, 5, "pink"); R(c, 6, 0, 7, 5, "white"); R(c, 7, 1, 7, 4, "pink")   # ears
    circle(c, 5.5, 8.5, 3.6, "white", 3.2); circle(c, 5, 13, 3.2, "white", 2.5)                       # head, body
    c.put(4, 8, "black"); c.put(7, 8, "black"); c.put(5, 10, "pink")
    R(c, 7, 11, 10, 12, "white")                                                                       # the arm to the pestle
    if f == 2:
        c.put(1, 13, "hv_moon_d"); c.put(15, 12, "hv_moon_d"); c.put(14, 14, "f1")


@item("ma_rabbit_lantern", "兔子燈", C4, 1, 16, 20, 2, 2, season=AUTUMN, note="拖著小輪子的紙兔子燈")
def _(c, f):
    R(c, 4, 0, 5, 6, "white"); R(c, 5, 1, 5, 5, "pink"); R(c, 8, 1, 9, 7, "white"); R(c, 9, 2, 9, 6, "pink")
    circle(c, 7, 12, 6, "cloth_d", 5); circle(c, 6.5, 11.5, 5.4, "white", 4.6)
    R(c, 12, 11, 14, 13, "white")                                                                      # the tail
    if f:
        R(c, 4, 9, 9, 13, "f1"); R(c, 5, 10, 8, 12, "f4")
    c.put(4, 10, "black"); c.put(8, 10, "black"); c.put(6, 12, "pink")
    R(c, 3, 17, 5, 19, "wood"); R(c, 9, 17, 11, 19, "wood"); c.put(4, 18, "wood_x"); c.put(10, 18, "wood_x")


@item("ma_osmanthus", "桂花樹", C7, 2, 28, 40, season=AUTUMN, note="開滿細碎金色桂花")
def _(c, f):
    R(c, 12, 22, 15, 32, "wood_d"); R(c, 12, 22, 12, 32, "wood"); R(c, 10, 30, 12, 33, "wood_d"); R(c, 15, 30, 17, 33, "wood_d")
    blob(c, 14, 12, 13, "green", "green_d", "green_l", 11)
    for x, y in ((6, 8), (11, 4), (18, 5), (22, 10), (8, 14), (14, 10), (20, 15), (5, 12), (16, 18), (11, 17), (23, 13)):
        c.put(x, y, "f1"); c.put(x + 1, y, "gold")
    R(c, 6, 32, 21, 39, "pot"); R(c, 6, 32, 21, 33, "pot_d"); R(c, 21, 34, 21, 39, "pot_d"); R(c, 7, 39, 20, 39, "pot_d")
    R(c, 9, 35, 18, 36, "gold_d")
    for x, y in ((3, 30), (24, 35), (8, 38)):                                                          # fallen blossoms
        c.put(x, y, "f1")


@item("ma_tea_table", "賞月茶几", C9, 2, 28, 22, season=AUTUMN, note="茶、月餅和柚子")
def _(c, f):
    R(c, 1, 11, 26, 13, "wood_l"); R(c, 1, 14, 26, 15, "wood"); R(c, 1, 15, 26, 15, "wood_d")
    for x in (3, 23):
        R(c, x, 16, x + 1, 21, "wood_d")
    R(c, 5, 5, 10, 9, "teal"); R(c, 5, 5, 10, 5, "teal_l"); R(c, 10, 6, 10, 9, "teal_d"); R(c, 11, 6, 13, 7, "teal"); R(c, 6, 3, 9, 4, "teal_d")   # the teapot
    R(c, 13, 9, 15, 10, "cloth"); R(c, 17, 9, 19, 10, "cloth")                                                                                # cups
    R(c, 19, 9, 25, 10, "cloth_d"); circle(c, 21, 8, 1.6, "wood"); circle(c, 24, 8, 1.6, "wood")                                              # mooncakes on a plate
    circle(c, 14, 7, 1.2, "pomelo")


@item("ma_lantern_string", "中秋燈籠串", C4, 2, 40, 20, 2, 2, ceiling=True, season=AUTUMN, note="橘、黃、粉紅的圓紙燈籠")
def _(c, f):
    R(c, 1, 0, 38, 1, "brown"); R(c, 1, 0, 38, 0, "wood_l")
    for n, cx in enumerate((5, 15, 25, 35)):
        body, dark = [("orangeish", "orange"), ("yellow", "gold_d"), ("pink", "pink_d"), ("orangeish", "orange")][n]
        R(c, cx, 2, cx, 4, "brown")
        circle(c, cx, 10, 4.6, dark, 4.6); circle(c, cx - 0.4, 9.6, 3.9, body, 3.9)
        R(c, cx - 3, 10, cx + 3, 10, dark); c.put(cx - 2, 7, "white")
        if (f + n) % 2:
            R(c, cx - 1, 8, cx + 1, 11, "f4")
        R(c, cx - 1, 15, cx + 1, 15, "gold"); R(c, cx, 16, cx, 19, "gold")


@item("ma_moon_rug", "月圓地毯", C6, 4, 40, 32, 2, 2, flat=True, season=AUTUMN, note="深藍的夜空、一輪滿月")
def _(c, f):
    rug_base(c, 40, 32, "hv_night", "gold", "hv_night_d", False)
    circle(c, 19.5, 15.5, 10, "hv_moon_d", 10); circle(c, 19, 15, 9, "hv_moon", 9)
    for x, y in ((15, 12), (23, 18), (17, 19)):
        circle(c, x, y, 1.2, "hv_moon_d")
    for i, (x, y) in enumerate(((7, 7), (32, 8), (6, 24), (33, 23), (11, 27), (28, 5), (4, 15), (35, 15))):
        c.put(x, y, "f4" if (i + f) % 2 else "f1")


# ===========================================================================================================================
# 元宵
# ===========================================================================================================================
@item("lt_sky_lantern", "天燈", C4, 1, 16, 28, 3, 3, ceiling=True, season=LANTERN, note="飄在半空的天燈，火光閃閃")
def _(c, f):
    R(c, 3, 2, 12, 17, "lred_d"); R(c, 4, 2, 11, 17, "lred"); R(c, 2, 4, 2, 15, "lred_d"); R(c, 13, 4, 13, 15, "lred_d")
    R(c, 5, 0, 10, 1, "lred_d"); R(c, 3, 17, 12, 18, "paper_d")
    for x in (5, 8, 10):
        R(c, x, 3, x, 15, "lred_l")
    R(c, 6, 5, 9, 9, "paper"); glyph(c, 5, 6, "ink", 2)
    R(c, 6, 19, 9, 19, "iron_d")
    flame(c, 7, 24, 4 + f % 2, f, 1)
    R(c, 6, 20, 9, 20, "iron"); R(c, 7, 21, 8, 23, "wood")


@item("lt_riddle_wall", "燈謎牆", C5, 2, 32, 24, wall=True, season=LANTERN, note="掛滿紅紙條的燈謎")
def _(c, f):
    R(c, 1, 0, 30, 1, "wood"); R(c, 1, 0, 30, 0, "wood_l")
    for n, x in enumerate(range(3, 29, 5)):
        R(c, x, 2, x, 4, "gold_d")
        R(c, x - 1, 5, x + 2, 20 - (n % 3) * 2, "lred" if n % 2 == 0 else "paper")
        R(c, x + 2, 6, x + 2, 20 - (n % 3) * 2, "lred_d" if n % 2 == 0 else "paper_d")
        for j in range(3):
            c.put(x, 7 + j * 4, "gold" if n % 2 == 0 else "ink"); c.put(x + 1, 8 + j * 4, "gold" if n % 2 == 0 else "ink")


@item("lt_tangyuan", "湯圓", C10, 1, 16, 14, 2, 2, season=LANTERN, note="冒著熱氣的湯圓")
def _(c, f):
    R(c, 2, 7, 13, 11, "white"); R(c, 2, 7, 13, 7, "snow_d"); R(c, 13, 8, 13, 11, "snow_d")
    R(c, 3, 12, 12, 13, "blue_d"); R(c, 4, 11, 11, 11, "blue")
    R(c, 2, 9, 13, 9, "blue"); c.cells([(4, 10), (7, 10), (10, 10)], "blue_l")
    R(c, 3, 5, 12, 6, "orange")
    for x, k in ((5, "white"), (8, "pink"), (11, "white")):
        circle(c, x, 5, 1.9, k, 1.7); c.put(x - 1, 4, "snow")
    for x, y in (([5, 1], [9, 0]) if f else ([6, 0], [10, 1])):
        c.put(x, y, "smoke"); c.put(x, y + 1, "smoke_d")


@item("lt_lotus_lantern", "蓮花燈", C4, 1, 16, 20, 2, 2, season=LANTERN, note="粉紅蓮花形的紙燈")
def _(c, f):
    R(c, 7, 4, 8, 12, "lotus_d"); R(c, 5, 6, 10, 12, "lotus")
    for dx, h in ((-5, 6), (-3, 8), (3, 8), (5, 6)):
        R(c, 7 + dx - 1, 12 - h, 7 + dx + 1, 12, "lotus" if abs(dx) > 3 else "lotus_d")
    R(c, 6, 5, 9, 12, "lotus"); R(c, 7, 3, 8, 5, "white")
    if f:
        R(c, 6, 8, 9, 11, "f1"); R(c, 7, 9, 8, 10, "f4")
    else:
        R(c, 7, 9, 8, 10, "f2")
    R(c, 2, 13, 13, 14, "green_d"); R(c, 3, 14, 12, 15, "green"); R(c, 1, 15, 14, 16, "water")
    R(c, 6, 17, 9, 18, "wood")


@item("lt_dragon_lantern", "龍燈", C13, 2, 40, 22, 4, 4, season=LANTERN, note="一節一節搖擺的紙龍燈")
def _(c, f):
    for i in range(7):
        x = 5 + i * 5
        y = 11 + int(round(4 * __import__("math").sin((i + f * 1.6) * 0.9)))
        circle(c, x, y, 3.4, "lred_d", 3.6); circle(c, x - 0.3, y - 0.3, 2.8, "lred", 3); R(c, x - 1, y - 1, x + 1, y + 1, "f2")
        R(c, x - 2, y + 3, x + 2, y + 3, "gold_d")
    hy = 11 + int(round(4 * __import__("math").sin(f * 1.6 * 0.9 - 0.9)))
    circle(c, 2.5, hy, 4, "gold", 4); R(c, 0, hy - 1, 2, hy + 1, "white"); c.put(3, hy - 2, "black"); R(c, 1, hy - 5, 2, hy - 4, "gold_d")
    R(c, 35, 12, 38, 14, "lred_d"); c.put(39, 13, "gold")


@item("lt_lantern_tree", "燈籠樹", C7, 2, 28, 38, 2, 2, season=LANTERN, note="樹上掛滿小燈籠")
def _(c, f):
    R(c, 12, 22, 15, 33, "wood_d"); R(c, 12, 22, 12, 33, "wood")
    blob(c, 14, 12, 13, "green", "green_d", "green_l", 11)
    for n, (x, y) in enumerate(((5, 7), (11, 4), (18, 5), (23, 9), (8, 13), (16, 12), (21, 16), (13, 18), (4, 17))):
        R(c, x, y, x + 2, y + 3, "lred_d" if (n + f) % 2 else "lred"); R(c, x + 1, y - 1, x + 1, y - 1, "gold"); c.put(x + 1, y + 4, "gold")
        c.put(x + 1, y + 1, "f2" if (n + f) % 2 else "f1")
    R(c, 7, 33, 20, 37, "pot"); R(c, 7, 33, 20, 34, "pot_d"); R(c, 20, 35, 20, 37, "pot_d")


@item("lt_fish_lantern", "魚燈", C4, 1, 18, 16, 2, 2, ceiling=True, season=LANTERN, note="掛著的魚形紙燈")
def _(c, f):
    R(c, 8, 0, 9, 3, "iron_d")
    circle(c, 8, 9, 6.2, "orangeish", 4.4); circle(c, 7.5, 8.5, 5.2, "orange", 3.6)
    R(c, 13, 5, 16, 13, "orange"); R(c, 15, 4, 16, 6, "orangeish"); R(c, 15, 12, 16, 14, "orangeish")
    c.put(4, 8, "black"); c.put(3, 8, "white")
    for x in (7, 10):
        R(c, x, 6, x, 12, "orangeish")
    if f:
        R(c, 5, 8, 11, 10, "f1")
    R(c, 7, 14, 9, 14, "gold"); R(c, 6, 15, 6, 15, "gold")


@item("lt_lantern_curtain", "燈籠簾", C5, 2, 28, 26, wall=True, season=LANTERN, note="一排排小燈籠垂下來")
def _(c, f):
    R(c, 1, 0, 26, 1, "gold_d")
    for row, ys in enumerate((3, 12)):
        for n, x in enumerate(range(4, 25, 6)):
            xx = x + (3 if row else 0)
            if xx > 25:
                continue
            R(c, xx, ys - 2 if row == 0 else 1, xx, ys, "gold_d")
            R(c, xx - 1, ys + 1, xx + 1, ys + 7, "lred" if (n + row) % 2 == 0 else "orangeish"); R(c, xx - 2, ys + 2, xx - 2, ys + 6, "lred_d" if (n + row) % 2 == 0 else "orange")
            R(c, xx + 2, ys + 2, xx + 2, ys + 6, "lred_d" if (n + row) % 2 == 0 else "orange")
            c.put(xx, ys + 8, "gold")


@item("lt_prize_table", "燈謎獎品桌", C9, 2, 30, 24, season=LANTERN, note="猜中燈謎的獎品都擺在這")
def _(c, f):
    R(c, 1, 9, 28, 13, "lred"); R(c, 1, 9, 28, 9, "lred_l"); R(c, 28, 10, 28, 13, "lred_d")
    R(c, 2, 14, 27, 21, "lred_d"); R(c, 2, 14, 27, 14, "lred")
    for x in range(3, 27, 3):
        c.put(x, 22, "gold")
    R(c, 3, 3, 8, 8, "lotus"); R(c, 4, 2, 7, 3, "lotus_d"); R(c, 10, 4, 15, 8, "f1"); R(c, 10, 4, 15, 4, "gold")
    R(c, 18, 4, 21, 8, "lred_d"); R(c, 18, 3, 21, 3, "gold"); R(c, 23, 5, 26, 8, "paper"); R(c, 24, 6, 25, 7, "ink")


@item("lt_lantern_rug", "花燈地毯", C6, 4, 40, 24, flat=True, season=LANTERN, note="紅底、一盞盞金色花燈")
def _(c, f):
    rug_base(c, 40, 24, "lred", "gold", "lred_d")
    for cx in (10, 20, 30):
        R(c, cx - 2, 7, cx + 2, 14, "gold"); R(c, cx - 1, 8, cx + 1, 13, "f2"); R(c, cx - 1, 5, cx + 1, 6, "gold_d"); R(c, cx, 15, cx, 17, "gold_d")


# ===========================================================================================================================
# 端午
# ===========================================================================================================================
def zongzi(c, x, y, big=1):
    """A pyramid dumpling tied with string."""
    for r in range(5 * big):
        half = (r * 3) // (2 * big) + 1
        R(c, x - half, y + r, x + half, y + r, "zong")
        c.put(x + half, y + r, "zong_d")
    R(c, x - 1, y + 2, x + 1, y + 2, "rope"); R(c, x - 1, y + 4, x + 1, y + 4, "rope")


@item("db_zongzi", "粽子", C10, 1, 18, 16, season=DRAGON, note="一串粽子")
def _(c, f):
    R(c, 8, 0, 9, 3, "rope")
    zongzi(c, 4, 3, 1); zongzi(c, 9, 4, 1); zongzi(c, 14, 3, 1)
    R(c, 1, 12, 16, 14, "wood"); R(c, 1, 12, 16, 12, "wood_l")


@item("db_zongzi_pot", "煮粽鍋", C10, 2, 26, 26, 3, 4, season=DRAGON, note="大鍋煮粽子，冒著熱氣")
def _(c, f):
    R(c, 3, 10, 22, 21, "iron"); R(c, 3, 10, 22, 11, "iron_l"); R(c, 22, 12, 22, 21, "iron_d"); R(c, 4, 21, 21, 22, "iron_d")
    R(c, 1, 12, 2, 14, "iron_d"); R(c, 23, 12, 24, 14, "iron_d")
    for x in (6, 11, 16):
        R(c, x, 8, x + 3, 10, "zong"); R(c, x + 3, 9, x + 3, 10, "zong_d")
    for x in (5, 20):
        R(c, x, 23, x, 25, "iron_d")
    R(c, 7, 23, 18, 24, "f3"); R(c, 9, 23, 16, 23, "f2") if f % 2 else None
    for x, y in [[(8, 5), (14, 3), (19, 6)], [(9, 4), (15, 2), (18, 5)], [(7, 3), (13, 1), (17, 4)]][f]:
        c.put(x, y, "smoke"); c.put(x, y + 1, "smoke_d")


@item("db_dragon_boat", "龍舟模型", C8, 2, 42, 26, season=DRAGON, note="龍頭龍尾的小龍舟")
def _(c, f):
    for x in range(4, 38):
        R(c, x, 14 + (1 if 8 < x < 32 else 0), x, 17 + (1 if 8 < x < 32 else 0), "lred" if (x // 3) % 2 else "gold")
    R(c, 6, 18, 36, 19, "wood_d"); R(c, 6, 20, 36, 20, "wood_x")
    circle(c, 4, 9, 5, "lred_d", 6); circle(c, 4, 9, 4, "lred", 5); R(c, 0, 8, 3, 9, "gold"); c.put(5, 7, "black"); R(c, 2, 2, 3, 5, "gold"); R(c, 6, 2, 7, 5, "gold")
    R(c, 36, 8, 40, 16, "lred_d"); R(c, 38, 4, 39, 8, "lred"); c.put(40, 4, "gold")
    for x in range(10, 33, 4):
        R(c, x, 10, x + 1, 14, "skin"); R(c, x, 9, x + 1, 9, "black"); R(c, x - 1, 12, x - 1, 17, "wood_l")
    R(c, 20, 4, 21, 14, "wood"); R(c, 22, 4, 28, 8, "lred"); R(c, 22, 4, 28, 4, "gold")


@item("db_mugwort", "艾草菖蒲", C5, 1, 14, 30, wall=True, season=DRAGON, note="端午掛在門口的艾草和菖蒲")
def _(c, f):
    R(c, 6, 0, 7, 2, "rope"); R(c, 5, 3, 8, 4, "lred")
    for dx, h in ((-3, 20), (-1, 24), (1, 26), (3, 18)):
        R(c, 6 + dx, 5, 6 + dx, 5 + h, "green_d"); R(c, 7 + dx, 5, 7 + dx, 5 + h - 2, "green"); c.put(6 + dx, 5 + h + 1, "green_l")
    for y in range(8, 24, 4):
        c.put(2, y, "green_l"); c.put(11, y + 1, "green_l")
    R(c, 5, 5, 8, 6, "rope")


@item("db_sachets", "香包串", C5, 1, 14, 26, wall=True, season=DRAGON, note="五顏六色的小香包")
def _(c, f):
    R(c, 6, 0, 7, 4, "rope")
    for n, (y, k, kd) in enumerate(((5, "lred", "lred_d"), (11, "blue", "blue_d"), (17, "gold", "gold_d"))):
        R(c, 6, y - 1, 7, y, "rope")
        circle(c, 6.5, y + 3, 3.2, kd, 3.4); circle(c, 6.3, y + 2.8, 2.5, k, 2.7); c.put(5, y + 2, "white")
        R(c, 6, y + 6, 7, y + 7, "rope") if n < 2 else None
    R(c, 5, 24, 8, 25, "gold")


@item("db_egg", "立蛋", C3, 1, 14, 14, season=DRAGON, note="端午中午十二點，蛋會立起來")
def _(c, f):
    R(c, 2, 9, 11, 11, "wood"); R(c, 2, 9, 11, 9, "wood_l")
    circle(c, 6.5, 5, 3.4, "white", 4.4); circle(c, 6, 4.5, 2.6, "cloth", 3.6); c.put(5, 3, "white")
    R(c, 12, 4, 12, 4, "f1")


@item("db_drum", "龍舟鼓", C9, 2, 26, 28, 2, 3, season=DRAGON, note="龍舟上的大鼓，咚咚咚")
def _(c, f):
    R(c, 3, 8, 22, 22, "lred"); R(c, 3, 8, 22, 9, "lred_l"); R(c, 22, 10, 22, 22, "lred_d")
    circle(c, 12.5, 8, 10, "cloth", 3.4); circle(c, 12.5, 8, 8.4, "paper", 2.6)
    for x in range(5, 21, 3):
        c.put(x, 12, "gold"); c.put(x, 19, "gold")
    R(c, 3, 23, 22, 24, "wood_d"); R(c, 5, 25, 7, 27, "wood_x"); R(c, 18, 25, 20, 27, "wood_x")
    up = 0 if f == 0 else 3
    R(c, 3, 1 + up, 5, 2 + up, "wood_l"); R(c, 4, 3 + up, 5, 8, "wood"); R(c, 20, 1 + up, 22, 2 + up, "wood_l"); R(c, 20, 3 + up, 21, 8, "wood")


@item("db_paddle_rack", "船槳架", C2, 2, 28, 34, season=DRAGON, note="整排龍舟船槳")
def _(c, f):
    R(c, 2, 28, 25, 31, "wood_d"); R(c, 2, 28, 25, 28, "wood"); R(c, 3, 32, 5, 33, "wood_x"); R(c, 22, 32, 24, 33, "wood_x")
    for n, x in enumerate((6, 11, 16, 21)):
        R(c, x, 2, x + 1, 27, "wood_l"); R(c, x + 1, 3, x + 1, 27, "wood")
        R(c, x - 1, 1, x + 2, 9, "lred" if n % 2 == 0 else "gold"); R(c, x + 2, 2, x + 2, 9, "lred_d" if n % 2 == 0 else "gold_d")


@item("db_river_rug", "河水地毯", C6, 4, 40, 24, 2, 2, flat=True, season=DRAGON, note="藍藍的河水，小小的龍舟")
def _(c, f):
    rug_base(c, 40, 24, "water", "water_d", "water_l", False)
    for n, x in enumerate(range(6, 36, 7)):
        y = 6 + (n % 2) * 8
        R(c, x, y + f, x + 4, y + f, "water_l"); R(c, x + 1, y + 1 + f, x + 3, y + 1 + f, "water_d")
    R(c, 14, 11, 26, 13, "lred"); R(c, 14, 14, 26, 14, "wood_d"); R(c, 12, 10, 14, 12, "gold"); R(c, 26, 10, 28, 13, "lred_d")


@item("db_zongzi_string", "粽串", C5, 1, 16, 28, wall=True, season=DRAGON, note="一大串掛起來的粽子")
def _(c, f):
    R(c, 7, 0, 8, 3, "rope")
    for n, y in enumerate((3, 11, 19)):
        zongzi(c, 4, y, 1); zongzi(c, 11, y + 1, 1)
        R(c, 7, y, 8, y + 1, "rope")


# ===========================================================================================================================
# 國慶
# ===========================================================================================================================
def flag(c, x0, y0, w, h, wave=0):
    """A flag: red field, a blue canton with a white sun."""
    R(c, x0, y0, x0 + w - 1, y0 + h - 1, "nd_red")
    cw, ch = w // 2, h // 2
    R(c, x0, y0, x0 + cw - 1, y0 + ch - 1, "nd_blue")
    sx, sy = x0 + cw // 2, y0 + ch // 2
    circle(c, sx, sy, max(1.5, ch / 3), "white")
    for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0)):
        if ch >= 8:
            c.put(sx + dx * (ch // 5 + 1) // 1, sy + dy * (ch // 5 + 1) // 1, "white")


@item("nd_flag_wall", "國旗", C5, 2, 32, 22, 2, 2, wall=True, season=NATIONAL, note="牆上的國旗")
def _(c, f):
    R(c, 0, 0, 1, 21, "wood_d"); R(c, 0, 0, 1, 0, "gold")
    flag(c, 2, 2 + (f % 2), 28, 16)
    R(c, 2, 18 + (f % 2), 29, 18 + (f % 2), "nd_red")


@item("nd_flagpole", "旗桿", C12, 1, 18, 48, 2, 2, season=NATIONAL, note="立在地上的旗桿，旗子在飄")
def _(c, f):
    R(c, 3, 3, 4, 44, "iron_l"); R(c, 4, 4, 4, 44, "iron"); circle(c, 3.5, 2, 2, "gold")
    R(c, 1, 44, 6, 46, "stone_d"); R(c, 0, 46, 7, 47, "stone")
    flag(c, 5, 5 + (f % 2), 12, 8)
    R(c, 5, 13 + (f % 2), 16, 13 + (f % 2), "nd_red")


@item("nd_fireworks_box", "煙火箱", C12, 2, 26, 30, 4, 5, season=NATIONAL, note="一箱煙火，一升空就綻放")
def _(c, f):
    R(c, 3, 22, 22, 28, "lred_d"); R(c, 3, 22, 22, 23, "lred"); R(c, 22, 24, 22, 28, "lred_d")
    R(c, 6, 25, 19, 26, "gold"); c.cells([(8, 25), (12, 25), (16, 25)], "lred_d")
    for x in (6, 11, 16):
        R(c, x, 17, x + 3, 22, "nd_blue"); R(c, x, 17, x + 3, 18, "white"); R(c, x + 3, 18, x + 3, 22, "nd_blue_d")
    R(c, 4, 29, 21, 29, "wood_x")
    burst = [[(5, 13), (11, 9), (17, 12)], [(8, 8), (13, 5), (19, 9), (4, 11)], [(6, 4), (12, 2), (18, 5), (3, 8), (21, 8)], [(4, 3), (11, 0), (19, 3), (2, 7), (22, 6)]][f]
    cols = ["f1", "nd_red", "white", "f2"]
    for n, (x, y) in enumerate(burst):
        c.put(x, y, cols[n % 4]); c.put(x + 1, y + 1, cols[(n + 1) % 4]); c.put(x - 1, y + 1, "f4") if f > 1 else None


@item("nd_sparklers", "仙女棒", C3, 1, 14, 18, 3, 6, season=NATIONAL, note="手持的仙女棒，火花四濺")
def _(c, f):
    R(c, 6, 8, 6, 17, "iron_l"); R(c, 7, 8, 7, 17, "iron")
    R(c, 4, 12, 4, 17, "iron_l"); R(c, 2, 14, 2, 17, "iron")
    for n, (x, y) in enumerate(((6, 6), (3, 10), (1, 12))):
        sp = [[(0, -2), (-2, 0), (2, 1), (1, -3)], [(-1, -3), (2, -1), (-2, 1), (0, 2)], [(1, -2), (-2, -1), (2, 0), (-1, 2)]][(f + n) % 3]
        c.put(x, y, "f4")
        for dx, dy in sp:
            c.put(x + dx, y + dy, "f1" if (dx + dy) % 2 else "f2")


@item("nd_bunting", "小國旗串", C4, 2, 40, 14, ceiling=True, season=NATIONAL, note="一整串小旗子")
def _(c, f):
    R(c, 0, 1, 39, 1, "rope")
    for n, x in enumerate(range(3, 37, 6)):
        y = 2 + (1 if 8 < x < 30 else 0)
        for r in range(7):
            R(c, x, y + r, x + 4 - r // 2, y + r, "nd_red" if n % 3 == 0 else ("white" if n % 3 == 1 else "nd_blue"))


@item("nd_cake", "國慶蛋糕", C10, 1, 20, 18, 2, 3, season=NATIONAL, note="紅白藍三色蛋糕，蠟燭是小煙火")
def _(c, f):
    R(c, 2, 11, 17, 15, "nd_red"); R(c, 2, 11, 17, 11, "lred_l"); R(c, 17, 12, 17, 15, "lred_d")
    R(c, 3, 7, 16, 10, "icing"); R(c, 3, 7, 16, 7, "white"); R(c, 16, 8, 16, 10, "snow_d")
    for x in range(4, 16, 3):
        R(c, x, 10, x + 1, 11, "icing")
    R(c, 1, 16, 18, 17, "cloth"); R(c, 1, 17, 18, 17, "cloth_d")
    for x in (6, 10, 14):
        R(c, x, 3, x, 6, "nd_blue")
        c.put(x, 2, "f1" if (x + f) % 2 else "f2"); c.put(x + 1, 1, "f4") if f else c.put(x - 1, 1, "f4")


@item("nd_sun_emblem", "青天白日徽", C5, 2, 26, 26, wall=True, season=NATIONAL, note="藍底、十二道光芒的白日")
def _(c, f):
    circle(c, 12.5, 12.5, 12, "nd_blue_d"); circle(c, 12.5, 12.5, 11, "nd_blue")
    import math
    for i in range(12):
        a = i * math.pi / 6
        for r in range(4, 10):
            c.put(round(12 + math.cos(a) * r), round(12 + math.sin(a) * r), "white")
    circle(c, 12.5, 12.5, 3.6, "nd_red"); circle(c, 12.5, 12.5, 2.6, "white")


@item("nd_balloons", "紅藍白氣球", C9, 1, 22, 36, 2, 2, season=NATIONAL, note="三顆隨風搖擺的氣球")
def _(c, f):
    sway = [0, 1][f]
    for n, (x, y, k, kd) in enumerate(((5, 8, "nd_red", "lred_d"), (11, 5, "white", "snow_d"), (17, 8, "nd_blue", "nd_blue_d"))):
        circle(c, x + sway * (n - 1), y, 4.6, kd, 5.6); circle(c, x + sway * (n - 1) - 0.4, y - 0.4, 3.9, k, 4.8)
        c.put(x - 2 + sway * (n - 1), y - 2, "white"); R(c, x - 1 + sway * (n - 1), y + 6, x + sway * (n - 1), y + 6, kd)
        R(c, x + sway * (n - 1) // 2, y + 7, x + sway * (n - 1) // 2, 28 + 0, "snow_d")
    R(c, 8, 28, 13, 31, "wood"); R(c, 8, 28, 13, 28, "wood_l"); R(c, 9, 32, 12, 35, "wood_d")


@item("nd_stage", "慶典舞台", C9, 4, 48, 34, season=NATIONAL, note="紅布幕、藍地板的小舞台")
def _(c, f):
    R(c, 2, 4, 45, 6, "lred_d"); R(c, 2, 4, 45, 4, "lred")
    R(c, 2, 7, 11, 22, "lred"); R(c, 36, 7, 45, 22, "lred")
    for x in (4, 7, 9, 38, 41, 43):
        R(c, x, 7, x, 22, "lred_d")
    R(c, 12, 7, 35, 22, "nd_blue_d"); R(c, 12, 7, 35, 8, "nd_blue")
    circle(c, 23.5, 14, 4.6, "white"); circle(c, 23.5, 14, 3.4, "nd_blue")
    R(c, 2, 23, 45, 28, "nd_blue"); R(c, 2, 23, 45, 24, "white"); R(c, 45, 25, 45, 28, "nd_blue_d"); R(c, 2, 29, 45, 33, "wood_d"); R(c, 2, 29, 45, 29, "wood")
    for x in (10, 38):
        R(c, x, 25, x + 1, 27, "gold")


@item("nd_rug", "紅藍白地毯", C6, 4, 40, 24, flat=True, season=NATIONAL, note="紅、白、藍的條紋地毯")
def _(c, f):
    R(c, 1, 1, 38, 22, "nd_blue_d"); R(c, 2, 2, 37, 7, "nd_red"); R(c, 2, 8, 37, 14, "white"); R(c, 2, 15, 37, 21, "nd_blue")
    for x in range(3, 37, 6):
        R(c, x, 4, x + 1, 5, "white"); R(c, x, 17, x + 1, 18, "white"); c.put(x, 11, "nd_red")
    for x in range(2, 38, 3):
        c.put(x, 0, "gold"); c.put(x, 23, "gold")


# ===========================================================================================================================
# 跨年
# ===========================================================================================================================
@item("ny_countdown", "倒數時鐘", C5, 2, 30, 24, 2, 1, wall=True, season=NEWYEAR, note="掛在牆上的倒數大時鐘")
def _(c, f):
    R(c, 1, 2, 28, 21, "iron_d"); R(c, 1, 2, 28, 3, "iron"); R(c, 28, 4, 28, 21, "black")
    R(c, 3, 5, 26, 18, "black")
    # four big digits, 0 0 : 0 0 (the colon blinks)
    for x0 in (5, 9, 17, 21):
        R(c, x0, 7, x0 + 2, 7, "f2"); R(c, x0, 16, x0 + 2, 16, "f2"); R(c, x0, 8, x0, 15, "f2"); R(c, x0 + 2, 8, x0 + 2, 15, "f2")
    if f:
        c.cells([(14, 9), (14, 14), (15, 9), (15, 14)], "f2")
    R(c, 13, 0, 16, 1, "gold"); R(c, 3, 22, 4, 23, "gold_d"); R(c, 25, 22, 26, 23, "gold_d")


@item("ny_champagne", "香檳塔", C10, 2, 26, 36, 2, 3, season=NEWYEAR, note="一層層疊起來的香檳杯")
def _(c, f):
    R(c, 11, 30, 14, 32, "glass_d"); R(c, 6, 33, 19, 35, "glass"); R(c, 11, 20, 14, 30, "glass_d")
    for y, n in ((7, 1), (13, 2), (19, 3)):
        for i in range(n):
            x = 12 - (n - 1) * 3 + i * 6
            R(c, x - 2, y, x + 2, y + 1, "glass"); R(c, x - 1, y + 2, x + 1, y + 3, "glass_d"); R(c, x, y + 3, x, y + 5, "glass_d")
            R(c, x - 1, y, x + 1, y, "f1")
    for x, y in (([10, 3], [14, 1]) if f else ([12, 2], [8, 4])):
        c.put(x, y, "sparkle"); c.put(x, y - 1, "f4")


@item("ny_party_hats", "派對帽", C3, 1, 18, 14, season=NEWYEAR, note="一疊閃亮派對帽")
def _(c, f):
    for x0, k, kd in ((2, "lred", "lred_d"), (8, "blue", "blue_d"), (12, "gold", "gold_d")):
        for r in range(8):
            half = (8 - r) // 3 + (1 if r > 1 else 0)
            R(c, x0 + 2 - half, 3 + r, x0 + 2 + half, 3 + r, k)
        R(c, x0 + 1, 2, x0 + 3, 2, "sparkle"); c.put(x0 + 4, 10, kd)
        R(c, x0 - 1, 11, x0 + 5, 11, kd)


@item("ny_confetti", "彩帶拉炮", C3, 1, 16, 18, 3, 4, season=NEWYEAR, note="啪！彩帶亂飛")
def _(c, f):
    R(c, 6, 11, 9, 16, "lred"); R(c, 6, 11, 9, 11, "gold"); R(c, 9, 12, 9, 16, "lred_d"); R(c, 7, 17, 8, 17, "gold_d")
    cols = ["lred_l", "f1", "blue_l", "green_l", "pink", "purple_l"]
    pts = [[(3, 6), (7, 3), (11, 5), (5, 9), (12, 8)], [(2, 4), (6, 1), (12, 3), (4, 8), (13, 6)], [(4, 2), (8, 0), (13, 2), (1, 7), (14, 5)]][f]
    for n, (x, y) in enumerate(pts):
        c.put(x, y, cols[(n + f) % 6]); c.put(x + 1, y + 1, cols[(n + f + 2) % 6])


@item("ny_balloon_arch", "氣球拱門", C11, 4, 48, 46, season=NEWYEAR, note="金色和銀色的氣球拱門")
def _(c, f):
    import math
    for i in range(0, 40):
        a = math.pi * i / 39
        x, y = 24 - math.cos(a) * 20, 24 - math.sin(a) * 20
        k, kd = [("gold", "gold_d"), ("snow", "snow_d"), ("pink", "pink_d"), ("snow_d", "stone_d")][i % 4]
        circle(c, x, y, 3.2, kd, 3.4); circle(c, x - 0.4, y - 0.4, 2.6, k, 2.8)
    for x in (4, 43):
        R(c, x - 1, 24, x + 1, 44, "gold"); R(c, x + 1, 25, x + 1, 44, "gold_d")
        R(c, x - 3, 44, x + 3, 45, "iron_d")
    for x, y in ((12, 10), (36, 12), (24, 3)):
        c.put(x, y, "sparkle")


@item("ny_disco_ball", "迪斯可球", C4, 1, 18, 26, 4, 5, ceiling=True, season=NEWYEAR, note="轉啊轉的亮片球")
def _(c, f):
    R(c, 8, 0, 9, 8, "iron_d"); R(c, 7, 8, 10, 9, "iron_l")
    circle(c, 8.5, 16, 7.6, "iron_d", 7.6); circle(c, 8.3, 15.7, 6.8, "mac_d", 6.8)
    for y in range(9, 24):
        for x in range(2, 16):
            if ((x - 8.5) / 7) ** 2 + ((y - 16) / 7) ** 2 <= 1:
                tile = ((x // 2) + (y // 2) + f) % 4
                c.put(x, y, ["mac", "glass", "mac_d", "white"][tile])
    for x in (2, 15):
        for y in range(11, 22, 2):
            c.put(x, y, "iron_d")
    for x, y in [[(0, 12), (17, 18), (8, 25)], [(1, 20), (16, 10), (4, 7)], [(0, 17), (17, 14), (12, 25)], [(2, 8), (15, 22), (9, 6)]][f]:
        c.put(x, y, "sparkle"); c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "f4") if 0 < x < 17 and 0 < y < 25 else None


@item("ny_fireworks_big", "跨年煙火台", C12, 4, 44, 46, 4, 4, season=NEWYEAR, note="倒數結束！一排煙火衝上天")
def _(c, f):
    import math
    R(c, 6, 36, 37, 43, "iron_d"); R(c, 6, 36, 37, 37, "iron_l"); R(c, 37, 38, 37, 43, "black")
    for x in (10, 17, 24, 31):
        R(c, x, 30, x + 3, 36, "lred" if x % 2 else "blue"); R(c, x, 30, x + 3, 31, "gold")
    cols = ["f1", "lred_l", "blue_l", "green_l", "pink", "f4"]
    # (centre x, y, and how big the burst is at this frame: they rise and open)
    shells = [[(10, 25, 0), (22, 19, 0), (33, 24, 0)], [(8, 17, 3), (22, 11, 2), (35, 16, 3)], [(7, 10, 6), (22, 7, 5), (36, 11, 6)], [(6, 9, 8), (22, 6, 7), (37, 10, 8)]][f]
    for n, (x, y, r) in enumerate(shells):
        k = cols[n % 6]
        if r == 0:
            R(c, x, y, x, y + 4, "f4"); c.put(x, y - 1, "f1")
            continue
        for i in range(12):
            a = i * math.pi / 6
            px, py = round(x + math.cos(a) * r), round(y + math.sin(a) * r)
            if 0 <= px < 44 and 0 <= py < 30:
                c.put(px, py, k)
                if r > 4:
                    qx, qy = round(x + math.cos(a) * (r - 2)), round(y + math.sin(a) * (r - 2))
                    c.put(qx, qy, "f4")
        c.put(x, y, "f4")


@item("ny_streamers", "彩帶", C5, 2, 40, 18, wall=True, season=NEWYEAR, note="牆上垂下來的彩色彩帶")
def _(c, f):
    cols = ["lred", "gold", "blue", "green", "pink", "purple_l"]
    for n, x in enumerate(range(1, 39, 3)):
        h = 8 + (n * 5) % 9
        R(c, x, 0, x, h, cols[n % 6]); R(c, x + 1, 1, x + 1, h - 1, cols[(n + 2) % 6])
        c.put(x, h + 1, cols[n % 6])
    R(c, 0, 0, 39, 0, "gold_d")


@item("ny_sign", "新年快樂牌", C5, 2, 32, 22, 2, 2, wall=True, season=NEWYEAR, note="金光閃閃的新年快樂牌")
def _(c, f):
    R(c, 2, 3, 29, 18, "iron_d"); R(c, 2, 3, 29, 4, "iron"); R(c, 3, 5, 28, 17, "black")
    for n, x in enumerate(range(5, 27, 6)):
        glyph(c, x, 8, "gold" if (n + f) % 2 else "f1", n)
    R(c, 3, 1, 5, 2, "gold"); R(c, 26, 1, 28, 2, "gold")
    for x, y in (([4, 6], [27, 15]) if f else ([27, 6], [5, 15])):
        c.put(x, y, "sparkle")


@item("ny_rug", "星河地毯", C6, 4, 40, 32, 2, 2, flat=True, season=NEWYEAR, note="深藍夜空、金色星星")
def _(c, f):
    rug_base(c, 40, 32, "hv_night", "gold", "hv_night_d", False)
    import random
    rng = random.Random(11)
    for i in range(34):
        x, y = rng.randrange(4, 36), rng.randrange(4, 28)
        c.put(x, y, "sparkle" if (i + f) % 2 else "f1")
        if i % 7 == 0:
            c.cells([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "gold")


# ===========================================================================================================================
# 聖誕
# ===========================================================================================================================
@item("xm_tree", "聖誕樹", C7, 4, 32, 54, 2, 2, season=XMAS, note="燈串會閃的大聖誕樹")
def _(c, f):
    for n, (y0, hw) in enumerate(((6, 6), (14, 9), (23, 12), (33, 14))):
        for r in range(11):
            half = max(1, (hw * (r + 3)) // 14)
            R(c, 15 - half, y0 + r, 15 + half, y0 + r, "xgreen" if (r + n) % 3 else "xgreen_l")
            c.put(15 + half, y0 + r, "xgreen_d")
    R(c, 15, 1, 16, 5, "gold"); R(c, 14, 3, 17, 3, "gold"); R(c, 13, 2, 18, 2, "gold_l"); c.put(15, 0, "f4")
    R(c, 13, 44, 18, 50, "wood_d"); R(c, 13, 44, 13, 50, "wood")
    R(c, 7, 50, 24, 53, "lred"); R(c, 7, 50, 24, 50, "lred_l"); R(c, 24, 51, 24, 53, "lred_d"); R(c, 15, 50, 16, 53, "gold")
    lights = [(12, 12), (19, 15), (9, 22), (22, 24), (14, 28), (6, 35), (24, 36), (16, 40), (11, 18), (20, 32)]
    cols = ["lred_l", "f1", "blue_l", "pink"]
    for n, (x, y) in enumerate(lights):
        c.put(x, y, cols[(n + f) % 4]); c.put(x, y + 1, "white") if (n + f) % 2 else None
    for x, y in ((8, 29), (22, 21), (15, 36), (11, 11)):
        circle(c, x, y, 1.4, "gold" if x % 2 else "lred_l")


@item("xm_wreath", "聖誕花環", C5, 1, 22, 24, wall=True, season=XMAS, note="紅蝴蝶結的花環")
def _(c, f):
    circle(c, 10.5, 11.5, 10, "xgreen_d", 10); circle(c, 10.5, 11.5, 7, "xgreen", 7)
    circle(c, 10.5, 11.5, 4.5, "xgreen_d")
    # the middle is left open
    for x in range(7, 15):
        for y in range(8, 16):
            if (x - 10.5) ** 2 + (y - 11.5) ** 2 < 15:
                c.put(x, y, None)
    for x, y in ((4, 6), (16, 5), (3, 14), (17, 15), (10, 2), (9, 20)):
        circle(c, x, y, 1.1, "lred_l")
    R(c, 7, 19, 14, 22, "lred"); R(c, 9, 20, 12, 21, "lred_d"); R(c, 6, 21, 8, 23, "lred_l"); R(c, 13, 21, 15, 23, "lred_l")


@item("xm_stockings", "聖誕襪", C5, 1, 28, 22, wall=True, season=XMAS, note="三隻掛著等禮物的襪子")
def _(c, f):
    R(c, 1, 0, 26, 1, "wood_d")
    for n, x in enumerate((3, 12, 21)):
        k, kd = [("lred", "lred_d"), ("xgreen", "xgreen_d"), ("lred", "lred_d")][n]
        R(c, x, 2, x + 1, 2, "gold_d")
        R(c, x - 1, 3, x + 4, 5, "white"); R(c, x - 1, 3, x + 4, 3, "snow")
        R(c, x, 6, x + 3, 13, k); R(c, x + 3, 6, x + 3, 13, kd)
        R(c, x, 14, x + 6, 17, k); R(c, x + 6, 14, x + 6, 17, kd); R(c, x + 4, 17, x + 6, 18, "white")
        R(c, x + 1, 7, x + 2, 8, "white" if n != 1 else "lred_l")


@item("xm_gifts", "禮物堆", C3, 1, 26, 18, season=XMAS, note="包著緞帶的大小禮物")
def _(c, f):
    R(c, 2, 8, 12, 16, "lred"); R(c, 2, 8, 12, 8, "lred_l"); R(c, 12, 9, 12, 16, "lred_d"); R(c, 6, 8, 8, 16, "gold"); R(c, 2, 11, 12, 12, "gold")
    R(c, 12, 5, 22, 16, "blue"); R(c, 12, 5, 22, 5, "blue_l"); R(c, 22, 6, 22, 16, "blue_d"); R(c, 16, 5, 18, 16, "white"); R(c, 12, 10, 22, 11, "white")
    R(c, 6, 1, 8, 3, "gold"); R(c, 4, 2, 5, 4, "gold_d"); R(c, 9, 2, 10, 4, "gold_d")
    R(c, 15, 1, 19, 4, "lred_l"); R(c, 17, 0, 17, 0, "white")


@item("xm_snowman", "雪人", C12, 2, 20, 34, season=XMAS, note="戴紅圍巾的雪人")
def _(c, f):
    circle(c, 9.5, 25, 8, "snow_d", 7.5); circle(c, 9.2, 24.6, 7.2, "snow", 6.8)
    circle(c, 9.5, 14, 6, "snow_d", 6); circle(c, 9.2, 13.6, 5.2, "snow", 5.2)
    circle(c, 9.5, 5.5, 4.4, "snow_d", 4.4); circle(c, 9.2, 5.2, 3.7, "snow", 3.7)
    R(c, 6, 0, 13, 1, "black"); R(c, 5, 2, 14, 2, "black"); R(c, 7, 0, 12, 1, "black"); R(c, 7, 1, 12, 1, "lred")
    c.put(7, 5, "black"); c.put(12, 5, "black"); R(c, 9, 6, 11, 6, "orange"); c.cells([(7, 8), (8, 9), (11, 9), (12, 8)], "black")
    R(c, 4, 10, 15, 12, "lred"); R(c, 4, 10, 15, 10, "lred_l"); R(c, 13, 13, 15, 17, "lred_d")
    for y in (19, 23, 27):
        c.put(9, y, "black")
    R(c, 0, 17, 3, 17, "wood_d"); R(c, 1, 15, 1, 17, "wood_d"); R(c, 16, 18, 19, 18, "wood_d"); R(c, 18, 16, 18, 18, "wood_d")


@item("xm_candy_canes", "拐杖糖", C3, 1, 14, 18, season=XMAS, note="紅白條紋拐杖糖")
def _(c, f):
    for x0, flip in ((2, 0), (8, 1)):
        for y in range(4, 17):
            c.put(x0 + (3 if flip else 0), y, "lred" if (y // 2) % 2 else "white"); c.put(x0 + 1 + (3 if flip else 0), y, "lred_d" if (y // 2) % 2 else "snow_d")
        for i, (dx, dy) in enumerate(((1, 3), (2, 2), (3, 2), (4, 3))):
            xx = x0 + dx + (3 if flip else 0) - (1 if flip else 0)
            c.put(xx, dy, "lred" if i % 2 == 0 else "white")
    R(c, 1, 17, 12, 17, "wood_d")


@item("xm_gingerbread", "薑餅屋", C8, 2, 28, 26, 2, 2, season=XMAS, note="糖霜屋頂、窗裡有燈的薑餅屋")
def _(c, f):
    R(c, 3, 13, 24, 23, "ginger"); R(c, 24, 14, 24, 23, "ginger_d"); R(c, 3, 23, 24, 24, "ginger_d")
    for r in range(10):
        half = 1 + (r * 12) // 9
        R(c, 14 - half, 3 + r, 13 + half, 3 + r, "icing" if r % 2 else "snow")
        c.put(14 - half, 3 + r, "snow_d"); c.put(13 + half, 3 + r, "snow_d")
    R(c, 11, 16, 16, 23, "wood_d"); R(c, 11, 16, 16, 16, "wood"); c.put(15, 20, "gold")
    R(c, 5, 15, 8, 18, "f1" if f else "f2"); R(c, 19, 15, 22, 18, "f1" if f else "f2"); R(c, 5, 15, 8, 15, "icing"); R(c, 19, 15, 22, 15, "icing")
    for x, y in ((6, 20), (10, 6), (14, 8), (18, 6), (21, 20), (8, 23)):
        c.put(x, y, ["lred", "xgreen", "gold"][x % 3])
    R(c, 18, 0, 20, 5, "ginger_d"); R(c, 18, 0, 20, 0, "icing")


@item("xm_lights", "聖誕燈串", C4, 2, 40, 14, 2, 3, ceiling=True, season=XMAS, note="五顏六色輪流閃的燈串")
def _(c, f):
    cols = ["lred_l", "f1", "blue_l", "green_l"]
    for x in range(0, 40):
        y = 2 + int(round(2 * (1 - abs((x % 10) - 5) / 5.0) * 1.5))
        c.put(x, y, "xgreen_d")
    for n, x in enumerate(range(3, 38, 5)):
        y = 4 + (0 if n % 2 else 1)
        k = cols[(n + f) % 4]
        R(c, x, y, x + 1, y + 1, k); c.put(x, y, "white") if (n + f) % 2 else None
        R(c, x, y + 2, x + 1, y + 3, k if (n + f) % 2 else "xgreen_d")


@item("xm_sleigh", "聖誕雪橇", C12, 4, 46, 28, season=XMAS, note="裝滿禮物的紅色雪橇")
def _(c, f):
    R(c, 2, 24, 43, 25, "gold_d"); R(c, 2, 24, 4, 21, "gold"); R(c, 40, 24, 43, 21, "gold")
    R(c, 6, 25, 6, 26, "gold_d"); R(c, 38, 25, 38, 26, "gold_d")
    R(c, 6, 12, 38, 23, "lred"); R(c, 6, 12, 38, 13, "lred_l"); R(c, 38, 14, 38, 23, "lred_d")
    R(c, 6, 17, 38, 18, "gold")
    for x in (10, 18, 26, 34):
        c.put(x, 15, "gold")
    for x0, k in ((8, "blue"), (15, "xgreen"), (22, "gold")):
        R(c, x0, 5, x0 + 6, 11, k); R(c, x0 + 3, 5, x0 + 3, 11, "white"); R(c, x0, 8, x0 + 6, 8, "white"); R(c, x0 + 2, 3, x0 + 4, 4, "lred")
    R(c, 28, 4, 34, 11, "lred_d"); R(c, 28, 4, 34, 4, "white"); R(c, 28, 8, 34, 8, "gold")
    R(c, 36, 8, 42, 12, "lred"); R(c, 36, 8, 42, 8, "lred_l"); R(c, 41, 9, 42, 12, "lred_d")


@item("xm_cocoa", "熱可可", C10, 1, 14, 14, 2, 2, season=XMAS, note="加了棉花糖的熱可可")
def _(c, f):
    R(c, 2, 5, 10, 11, "cloth"); R(c, 2, 5, 10, 5, "white"); R(c, 10, 6, 10, 11, "cloth_d"); R(c, 3, 11, 9, 12, "cloth_d")
    R(c, 3, 6, 9, 7, "brown"); R(c, 4, 4, 5, 5, "white"); R(c, 7, 4, 8, 5, "white")
    R(c, 11, 6, 12, 9, "cloth"); R(c, 12, 7, 12, 8, "cloth_d")
    for x, y in (([4, 1], [7, 0]) if f else ([5, 0], [8, 1])):
        c.put(x, y, "smoke"); c.put(x, y + 1, "smoke_d")


@item("xm_snow_rug", "雪花地毯", C6, 4, 40, 32, flat=True, season=XMAS, note="紅底、白色雪花")
def _(c, f):
    rug_base(c, 40, 32, "lred", "white", "lred_d")
    for cx, cy in ((12, 11), (28, 11), (20, 21), (8, 22), (32, 22)):
        c.cells([(cx, cy), (cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1), (cx - 2, cy - 2), (cx + 2, cy - 2), (cx - 2, cy + 2), (cx + 2, cy + 2)], "white")
        c.cells([(cx - 3, cy), (cx + 3, cy), (cx, cy - 3), (cx, cy + 3)], "snow_d")
