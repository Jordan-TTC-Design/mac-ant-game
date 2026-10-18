#!/usr/bin/env python3
"""The terrain breeds (2026-10-17, WORLD.md §29): one resident per terrain detail per race, 14 × 4 = 56 of them. A camp's
residents on the big world can be born of the land they hold: a goblin from a mountain cell grows stony skin, an elf from a
river cell has wet, blue-green hair. They are never drawn by the normal birth roll (weight 0); the server picks them.

They are drawn on the race's own plain body (make_goblin / make_elf / make_undead / make_beast), with the land's colours, clothes and a
small prop laid over it; for the undead some are bones and some are ghosts (make_undead's skeleton / ghost / wisp).

The race generators call `write(race, root)` and add `manifest_entries(race)` to their breeds, like make_specials.
    python3 tools/make_terrain_breeds.py --preview /path/preview.png   # common + the 14, front and side, every race
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_goblin as mg  # noqa: E402
import make_specials as ms  # noqa: E402

SIZE = mg.SIZE

DETAILS = ["mountain", "river", "farmland", "cemetery", "wetland", "campus", "industrial", "sand", "coast", "hotspring",
           "temple", "hospital", "military", "railway"]
PLACE = {"mountain": "山地", "river": "河川", "farmland": "農田", "cemetery": "墓地", "wetland": "濕地", "campus": "校園",
         "industrial": "工業區", "sand": "沙灘", "coast": "海岸", "hotspring": "溫泉", "temple": "廟宇區", "hospital": "醫院",
         "military": "軍事區", "railway": "鐵道"}
NAMES = {
    "goblin": {"mountain": "岩膚", "river": "泳河", "farmland": "田耕", "cemetery": "掘墓", "wetland": "泥沼", "campus": "書蟲",
               "industrial": "鐵手", "sand": "沙行", "coast": "潮汐", "hotspring": "泡湯", "temple": "拜拜", "hospital": "白衣",
               "military": "鐵衛", "railway": "疾行"},
    "elf": {"mountain": "山風", "river": "溪語", "farmland": "穀穗", "cemetery": "守靈", "wetland": "蘆影", "campus": "學士",
            "industrial": "鋼弦", "sand": "浪蹄", "coast": "海歌", "hotspring": "溫泉", "temple": "祈福", "hospital": "醫葉",
            "military": "衛兵", "railway": "風行"},
    "undead": {"mountain": "石棺", "river": "溺魂", "farmland": "稻草", "cemetery": "夜哭", "wetland": "沼魂", "campus": "書靈",
               "industrial": "鐵骨", "sand": "沙骸", "coast": "沉船", "hotspring": "蒸骨", "temple": "背誓", "hospital": "縫屍",
               "military": "骨衛", "railway": "幽軌"},
    "beast": {"mountain": "岩鬃", "river": "浪鬃", "farmland": "穗尾", "cemetery": "夜嚎", "wetland": "泥爪", "campus": "書狐",
              "industrial": "鐵爪", "sand": "沙狐", "coast": "海狼", "hotspring": "湯狐", "temple": "祭牙", "hospital": "白爪",
              "military": "戰牙", "railway": "疾風"},
}
# What it looks like, per race (the first half of the blurb).
LOOKS = {
    "goblin": {"mountain": "皮膚灰得像石頭，扛著十字鎬", "river": "青綠色的皮膚總是濕濕的，手裡抓著一條魚",
               "farmland": "戴著草帽、扛著鋤頭", "cemetery": "披著黑兜帽、拿著鏟子", "wetland": "滿身泥巴，頭上頂著一朵睡蓮",
               "campus": "戴著眼鏡和方帽，抱著一本書", "industrial": "一隻手臂包著鐵、臉上沾著煤灰，拿著扳手",
               "sand": "曬成沙色的皮膚，掛著貝殼項鍊", "coast": "穿著水手條紋衫、扛著船錨",
               "hotspring": "頭上頂著毛巾、臉紅通通，冒著熱氣", "temple": "披著紅布、掛著念珠，手上拿著香",
               "hospital": "穿著白袍，胸前一個紅十字", "military": "戴著鋼盔、穿著卡其衣，扛著長矛",
               "railway": "戴著列車長帽、提著提燈，跑起來一陣風"},
    "elf": {"mountain": "披著灰藍斗篷、肩上捲著登山繩", "river": "一頭濕漉漉的青綠長髮，手拿蘆葦",
            "farmland": "麥穗色的長髮，抱著一束麥子", "cemetery": "披著深色兜帽、提著一盞燈", "wetland": "蘆葦色的衣服，髮上別著睡蓮",
            "campus": "戴著眼鏡和方帽、穿著學袍，抱著書", "industrial": "戴著護目鏡、一隻鐵手套，拿著扳手",
            "sand": "曬成小麥色、沙金色的頭髮，掛著貝殼項鍊", "coast": "海藍色的長髮、條紋上衣，拿著海螺",
            "hotspring": "頭頂毛巾、穿著浴衣，臉紅通通", "temple": "穿著紅金的袍子，手上掛著念珠",
            "hospital": "穿著白袍、胸前紅十字，拿著一片藥葉", "military": "戴著頭盔、穿著卡其衣，拿著長矛",
            "railway": "戴著列車長帽、穿著深藍外套，走路帶風"},
    "undead": {"mountain": "石頭色的大骨架，扛著十字鎬", "river": "青綠色的溺水幽魂，身上掛著水草",
               "farmland": "戴草帽、塞滿稻草的骷髏，拿著乾草叉", "cemetery": "黑黑的小幽魂，提著燈一路哭",
               "wetland": "泥綠色的沼澤幽魂，頂著睡蓮、纏著蘆葦", "campus": "戴眼鏡和方帽的書頁色靈火，抱著書",
               "industrial": "鐵灰色的骨頭，拿著扳手", "sand": "沙色的骨頭、包著頭巾，掛著貝殼項鍊",
               "coast": "從沉船爬上來的骷髏，穿條紋衫、披著海草、扛著船錨", "hotspring": "泡得粉粉的骨頭頂著毛巾，一直冒蒸氣",
               "temple": "穿著紅袍、額頭貼著一張破符", "hospital": "滿身縫線、纏著繃帶的骷髏",
               "military": "戴鋼盔的大骨架，扛著長矛", "railway": "戴著列車長帽的藍色幽魂，提著燈飄得飛快"},
    "beast": {"mountain": "一身石灰色的硬毛，扛著十字鎬", "river": "毛色青灰、總是濕淋淋的狼，手拿蘆葦",
              "farmland": "麥穗色的毛、戴著草帽，抱著一束麥子", "cemetery": "全身黑毛的狼，提著一盞燈，夜裡會嚎",
              "wetland": "滿身泥巴、爪子沾著泥，頭上頂著睡蓮", "campus": "戴著眼鏡和方帽的狐狸，抱著一本書",
              "industrial": "一隻爪子包著鐵、毛上沾著煤灰，拿著扳手", "sand": "沙色的狐狸，包著頭巾、掛著貝殼項鍊",
              "coast": "海灰色的狼，戴著水手帽，拿著海螺", "hotspring": "泡得毛蓬蓬的狐狸，頭頂毛巾、一直冒熱氣",
              "temple": "披著紅布、掛著念珠的狼，牙上綁著紅繩", "hospital": "一身白毛、戴著護士帽，拿著一片藥葉",
              "military": "戴著鋼盔的大塊頭狼，扛著長矛", "railway": "戴著列車長帽的藍灰色狼，提著燈跑得最快"},
}
# What it is better at, and the stat that says so (one thing each, a little better than the race's common resident).
GOOD = {"mountain": "比較耐打", "river": "走得快一點", "farmland": "一次搬兩份", "cemetery": "眼睛比較尖",
        "wetland": "不太需要休息", "campus": "很會叫同伴來幫忙", "industrial": "力氣大一點", "sand": "走得快一點",
        "coast": "看得比較遠", "hotspring": "休息得少一點", "temple": "活得久一點", "hospital": "比較耐打",
        "military": "打得比較痛", "railway": "跑得最快"}
COMMON_STATS = {"goblin": {}, "elf": {"lifespan": 2.0, "might": 1.3, "health": 3.5}, "undead": {"lifespan": 50.0, "might": 1.1, "health": 3},
                "beast": {"lifespan": 1.5, "might": 1.2, "health": 3.5}}


def terrain_stats(race, detail):
    s = dict(COMMON_STATS[race])
    might, health, life = s.get("might", 1.0), s.get("health", 3.0), s.get("lifespan", 1.0)
    if detail == "mountain":
        s["health"] = health + 2
    elif detail == "river":
        s["speed"] = 1.15
    elif detail == "farmland":
        s["carry"] = 2
    elif detail == "cemetery":
        s["sense"] = 1.25
    elif detail == "wetland":
        s["rest"] = 0.85
    elif detail == "campus":
        s["recruit"] = 2
    elif detail == "industrial":
        s["might"] = round(might + 0.3, 2)
    elif detail == "sand":
        s["speed"] = 1.1
    elif detail == "coast":
        s["sense"] = 1.2
    elif detail == "hotspring":
        s["rest"] = 0.8
    elif detail == "temple":
        if race == "undead":                                   # the undead never age: the broken vow makes them hit harder
            s["might"] = round(might + 0.2, 2)
        else:
            s["lifespan"] = round(life * 1.3, 2)
    elif detail == "hospital":
        s["health"] = health + 1.5
    elif detail == "military":
        s["might"] = round(might + 0.25, 2)
    elif detail == "railway":
        s["speed"] = 1.2
    return s


def blurb(race, detail):
    good = GOOD[detail]
    if race == "undead" and detail == "temple":
        good = "打得比較痛"
    return f"{PLACE[detail]}的居民。{LOOKS[race][detail]}，{good}。不會在營地自己生出來，只從大世界的{PLACE[detail]}領地來。"


# --- colours of the land (keys of their own, never a race's) -------------------------------------------------------
T = {
    "t_stone": (156, 156, 150), "t_stone2": (112, 112, 108),
    "t_rope": (206, 170, 108), "t_rope2": (156, 120, 70),
    "t_wood": (176, 122, 66), "t_wood2": (126, 84, 44),
    "t_steel": (210, 218, 228), "t_steel2": (140, 150, 164), "t_iron": (104, 110, 124), "t_iron2": (72, 76, 90),
    "t_straw": (240, 210, 112), "t_straw2": (196, 158, 70), "t_wheat": (246, 196, 72),
    "t_red": (210, 50, 54), "t_red2": (148, 30, 40), "t_gold": (246, 202, 72),
    "t_white": (248, 246, 238), "t_white2": (204, 206, 204),
    "t_blue": (62, 100, 176), "t_blue2": (40, 66, 132), "t_navy": (46, 56, 100), "t_navy2": (28, 32, 62),
    "t_reed": (112, 150, 66), "t_reed2": (132, 90, 52),
    "t_lily": (250, 166, 196), "t_pad": (86, 164, 84),
    "t_fish": (156, 196, 216), "t_fish2": (96, 136, 170),
    "t_shell": (252, 226, 206), "t_shell2": (230, 140, 130),
    "t_steam": (232, 238, 244), "t_drop": (130, 200, 240),
    "t_khaki": (176, 154, 96), "t_khaki2": (132, 114, 66), "t_olive": (104, 118, 64), "t_olive2": (74, 86, 44),
    "t_glass": (36, 36, 48), "t_book": (150, 56, 60), "t_page": (248, 242, 222),
    "t_lamp": (255, 216, 110), "t_lamp2": (255, 150, 60),
    "t_smoke": (206, 204, 214), "t_soot": (62, 58, 58),
    "t_bead": (126, 74, 50), "t_paper": (242, 212, 96), "t_stitch": (58, 36, 50), "t_leaf": (96, 188, 92),
    "t_speed": (226, 240, 255), "t_tear": (150, 214, 252), "t_mud": (122, 92, 58), "t_mud2": (92, 68, 42),
    "t_weed": (60, 130, 80), "t_kelp": (128, 180, 70), "t_pink": (244, 150, 160), "t_wrap": (90, 168, 176), "t_wrap2": (60, 128, 140),
}

SWING = ms.SWING
HANDS = ms.HANDS


def paint(c, x0, y0, x1, y1, key, only=None):
    """Recolour what is already drawn in a box (never the outline), optionally only the pixels of the keys in `only`."""
    for y in range(max(0, y0), min(SIZE - 1, y1) + 1):
        for x in range(max(0, x0), min(SIZE - 1, x1) + 1):
            k = c.px[y][x]
            if k is not None and k != "O" and (only is None or k in only):
                c.px[y][x] = key


def dab(c, pts, key, only=None):
    for x, y in pts:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            k = c.px[y][x]
            if k is not None and k != "O" and (only is None or k in only):
                c.px[y][x] = key


# --- props, held at a hand (x, y) -------------------------------------------------------------------------------
def pick(c, x, y):
    c.rect(x, y - 4, x, y + 1, "t_wood")
    c.rect(x - 2, y - 5, x + 2, y - 5, "t_iron")
    c.cells([(x - 2, y - 4), (x + 2, y - 4)], "t_iron2")


def hoe(c, x, y):
    c.rect(x, y - 6, x, y + 1, "t_wood")
    c.rect(x - 2, y - 6, x - 1, y - 6, "t_steel2")
    c.put(x - 2, y - 5, "t_steel2")


def pitchfork(c, x, y):
    c.rect(x, y - 4, x, y + 2, "t_wood")
    c.rect(x - 1, y - 5, x + 1, y - 5, "t_steel2")
    c.cells([(x - 1, y - 6), (x, y - 6), (x + 1, y - 6), (x - 1, y - 7), (x + 1, y - 7)], "t_steel2")


def shovel(c, x, y):
    c.rect(x, y - 5, x, y, "t_wood")
    c.rect(x - 1, y - 5, x + 1, y - 5, "t_wood2")
    c.rect(x - 1, y + 1, x + 1, y + 3, "t_steel2")
    c.put(x, y + 3, "t_iron")


def lantern(c, x, y):
    c.put(x, y + 1, "t_iron2")
    c.rect(x - 1, y + 2, x + 1, y + 2, "t_iron2")
    c.rect(x - 1, y + 3, x + 1, y + 3, "t_lamp")
    c.put(x, y + 3, "t_lamp2")


def fish(c, x, y):
    c.rect(x, y + 1, x + 1, y + 3, "t_fish")
    c.put(x + 1, y + 1, "t_glass")                             # its eye
    c.cells([(x - 1, y), (x + 1, y)], "t_fish2")               # the tail, in the hand
    c.put(x, y + 3, "t_fish2")


def reed(c, x, y):
    c.rect(x, y - 5, x, y + 2, "t_reed")
    c.rect(x, y - 8, x, y - 6, "t_reed2")
    c.put(x - 1, y - 3, "t_reed")


def sheaf(c, x, y):
    c.rect(x - 1, y - 3, x + 1, y + 1, "t_straw2")
    c.cells([(x - 1, y - 5), (x - 1, y - 4), (x, y - 6), (x, y - 5), (x, y - 4), (x + 1, y - 5), (x + 1, y - 4)], "t_wheat")
    c.rect(x - 1, y - 1, x + 1, y - 1, "t_red")                # the tie


def book(c, x, y):
    c.rect(x - 1, y - 2, x + 1, y, "t_book")
    c.rect(x, y - 2, x + 1, y - 1, "t_page")


def wrench(c, x, y):
    c.rect(x, y - 3, x, y + 1, "t_steel2")
    c.cells([(x - 1, y - 4), (x + 1, y - 4), (x - 1, y - 5), (x + 1, y - 5)], "t_steel")


def anchor(c, x, y):
    c.rect(x, y - 3, x, y + 2, "t_iron")
    c.put(x, y - 4, "t_iron2")
    c.rect(x - 1, y - 2, x + 1, y - 2, "t_iron")
    c.cells([(x - 2, y + 1), (x - 1, y + 2), (x + 1, y + 2), (x + 2, y + 1)], "t_iron")


def spear(c, x, y):
    c.rect(x, 2, x, 14, "t_wood2")
    c.put(x, 0, "t_steel")
    c.rect(x - 1, 1, x + 1, 1, "t_steel")
    c.put(x + 1, 1, "t_steel2")
    c.put(x, 3, "t_olive")


def incense(c, x, y):
    c.rect(x, y - 3, x, y, "t_red2")
    c.put(x, y - 4, "t_lamp2")


def beads(c, x, y):
    c.cells([(x, y + 1), (x - 1, y + 2), (x + 1, y + 2), (x, y + 3)], "t_bead")
    c.put(x, y + 4, "t_red")


def conch(c, x, y):
    c.rect(x, y - 2, x + 1, y, "t_shell")
    c.cells([(x + 1, y - 2), (x, y)], "t_shell2")
    c.put(x + 2, y - 3, "t_shell")


def leaf(c, x, y):
    c.cells([(x, y), (x, y - 1), (x + 1, y - 2), (x, y - 2), (x + 1, y - 3), (x, y - 3), (x + 1, y - 4)], "t_leaf")
    c.put(x, y - 1, "t_reed")


def bucket(c, x, y):
    c.put(x, y + 1, "t_wood2")
    c.rect(x - 1, y + 2, x + 1, y + 3, "t_wood")
    c.rect(x - 1, y + 2, x + 1, y + 2, "t_wood2")


POLES = (hoe, pitchfork, spear, reed)                          # long ones stand behind the body in the side view


def held(g, race, view, phase, item, dx=None):
    """An item in the right hand (the near hand in the side view), like make_specials."""
    h = HANDS[race]
    if view == "side":
        x = h["side"][phase] + 1
        item(g.back if item in POLES else g.front, x, h["y"])
        return
    layer = mg.Canvas()
    item(layer, h["R"] + (dx if dx is not None else (2 if item in POLES else 1)), h["y"] - SWING[phase])
    if view == "front":
        for y in range(SIZE):
            for x in range(SIZE):
                if layer.px[y][x] is not None:
                    g.front.px[y][x] = layer.px[y][x]
    else:
        m = ms.mirrored(layer)
        for y in range(SIZE):
            for x in range(SIZE):
                if m.px[y][x] is not None:
                    g.back.px[y][x] = m.px[y][x]


def held_at(g, view, item, front_xy, side_xy, pole=False):
    """An item at given points (bodies without hands: the ghosts)."""
    if view == "side":
        item(g.back if pole else g.front, *side_xy)
        return
    layer = mg.Canvas()
    item(layer, *front_xy)
    if view == "back":
        layer = ms.mirrored(layer)
        target = g.back
    else:
        target = g.front
    for y in range(SIZE):
        for x in range(SIZE):
            if layer.px[y][x] is not None:
                target.px[y][x] = layer.px[y][x]


# --- things worn on the head: (x0, x1) the head's columns, `top` its first row ----------------------------------------
def straw_hat(c, x0, x1, top, view):
    c.rect(x0 - 2, top, x1 + 2, top, "t_straw")
    c.cells([(x0 - 2, top), (x1 + 2, top)], "t_straw2")
    c.rect(x0 + 1, top - 2, x1 - 1, top - 1, "t_straw")
    c.rect(x0 + 1, top - 1, x1 - 1, top - 1, "t_red")


def mortarboard(c, x0, x1, top, view):
    c.rect(x0 + 1, top - 1, x1 - 1, top, "t_glass")
    c.rect(x0 - 1, top - 2, x1 + 1, top - 2, "t_glass")
    if view != "back":
        c.cells([(x1 + 1, top - 1), (x1 + 1, top), (x1 + 1, top + 1)], "t_gold")


def conductor_cap(c, x0, x1, top, view):
    c.rect(x0, top - 2, x1, top, "t_navy")
    c.rect(x0, top, x1, top, "t_navy2")
    if view == "front":
        c.put((x0 + x1) // 2, top - 1, "t_gold")
        c.put((x0 + x1) // 2 + 1, top - 1, "t_gold")
    elif view == "side":
        c.cells([(x1 + 1, top), (x1 + 2, top)], "t_navy2")     # the peak
        c.put(x1 - 1, top - 1, "t_gold")


def helmet(c, x0, x1, top, view):
    c.rect(x0 + 1, top - 2, x1 - 1, top - 2, "t_olive")
    c.rect(x0, top - 1, x1, top, "t_olive")
    c.rect(x0 - 1, top + 1, x1 + 1, top + 1, "t_olive2")
    c.put(x0 + 2, top - 1, "t_khaki")                          # a glint


def towel(c, x0, x1, top, view):
    c.rect(x0 + 1, top - 1, x1 - 1, top, "t_white")
    c.rect(x0 + 1, top, x1 - 1, top, "t_blue")
    c.cells([((x0 + x1) // 2, top - 2), ((x0 + x1) // 2 + 1, top - 2)], "t_white")      # the knot


def sailor_cap(c, x0, x1, top, view):
    c.rect(x0 + 1, top - 1, x1 - 1, top, "t_white")
    c.rect(x0 + 1, top, x1 - 1, top, "t_blue")
    if view != "front":
        c.cells([(x0, top + 1), (x0 - 1, top + 2)], "t_blue")  # the ribbon tails


def nurse_cap(c, x0, x1, top, view):
    c.rect(x0 + 2, top - 2, x1 - 2, top, "t_white")
    if view == "front":
        mx = (x0 + x1) // 2
        c.cells([(mx, top - 2), (mx, top - 1), (mx + 1, top - 1), (mx - 1, top - 1), (mx, top)], "t_red")
    else:
        c.put((x0 + x1) // 2, top - 1, "t_red")


def headwrap(c, x0, x1, top, view):
    c.rect(x0, top - 1, x1, top, "t_wrap")
    c.rect(x0, top, x1, top, "t_wrap2")
    if view != "front":
        c.cells([(x0 - 1, top + 1), (x0 - 1, top + 2), (x0 - 2, top + 3)], "t_wrap")


def lily(c, x0, x1, top, view):
    if view == "side":
        c.cells([(x0 + 2, top - 1), (x0 + 3, top - 1)], "t_lily"); c.put(x0 + 2, top, "t_pad")
    else:
        c.cells([(x0, top - 1), (x0 + 1, top - 1), (x0 + 1, top - 2)], "t_lily"); c.cells([(x0 + 2, top), (x0 + 2, top - 1)], "t_pad")


def goggles(c, x0, x1, top, view):
    if view == "front":
        c.rect(x0, top + 1, x1, top + 1, "t_soot")
        c.cells([(x0 + 1, top + 1), (x0 + 2, top + 1), (x1 - 2, top + 1), (x1 - 1, top + 1)], "t_drop")
    elif view == "side":
        c.rect(x0, top + 1, x1, top + 1, "t_soot"); c.cells([(x1 - 2, top + 1), (x1 - 1, top + 1)], "t_drop")
    else:
        c.rect(x0, top + 1, x1, top + 1, "t_soot")


HATS = {"farmland": straw_hat, "campus": mortarboard, "railway": conductor_cap, "military": helmet, "hotspring": towel,
        "coast": sailor_cap, "hospital": nurse_cap, "sand": headwrap, "wetland": lily}


def steam(g, phase, xs=(3, 12)):
    up = phase % 2
    g.loose += [(xs[0], 2 - up, "t_steam"), (xs[0] - 1, 1 - up + 2, "t_steam"), (xs[1], 1 + up, "t_steam"), (xs[1] + 1, 3 + up, "t_steam")]


def speed_lines(g, view, phase):
    if view == "side":
        off = phase % 2
        g.loose += [(0 + off, 7, "t_speed"), (1 + off, 7, "t_speed"), (1 - off, 10, "t_speed"), (2 - off, 10, "t_speed"),
                    (0 + off, 13, "t_speed"), (1 + off, 13, "t_speed")]
    else:
        g.loose += [(0, 8 + phase % 2, "t_speed"), (15, 9 - phase % 2, "t_speed"), (0, 12, "t_speed"), (15, 12, "t_speed")]


def drips(g, phase):
    g.loose += [(2 + phase % 2, 9 + phase, "t_drop"), (13 - phase % 2, 12 - phase, "t_drop")]


# --- the goblin ---------------------------------------------------------------------------------------------------
# Default build: head rows 2-7 (cols 4-11, side 5-11), eyes row 4, shoulders row 8, chest cols 5-10, belt row 10,
# loincloth rows 10-12, arms cols 4 and 11 (rows 9-11, swinging), legs rows 12-14.
GOB_SKIN = {
    "mountain": ((140, 158, 124), (104, 118, 92), (172, 186, 156)),
    "river": ((80, 172, 150), (54, 132, 116), (130, 212, 192)),
    "cemetery": ((128, 162, 112), (94, 124, 82), (160, 192, 140)),
    "wetland": ((132, 140, 70), (100, 104, 48), (164, 172, 100)),
    "sand": ((196, 176, 104), (160, 138, 74), (224, 206, 142)),
    "hotspring": ((140, 190, 92), (104, 150, 66), (184, 224, 136)),
}
GOB_CLOTH = {
    "mountain": ((120, 110, 100), (84, 76, 70)), "river": ((60, 110, 170), (40, 80, 130)), "farmland": ((150, 110, 60), (104, 72, 36)),
    "cemetery": ((70, 62, 84), (46, 40, 58)), "wetland": ((122, 92, 58), (92, 68, 42)), "campus": ((70, 90, 140), (48, 62, 104)),
    "industrial": ((80, 78, 84), (54, 52, 58)), "sand": ((236, 220, 170), (196, 176, 120)), "coast": ((40, 66, 132), (28, 44, 96)),
    "hotspring": ((248, 246, 238), (190, 200, 214)), "temple": ((210, 50, 54), (148, 30, 40)), "hospital": ((240, 240, 236), (196, 198, 196)),
    "military": ((132, 114, 66), (96, 82, 44)), "railway": ((46, 56, 100), (28, 32, 62)),
}


def goblin_design(detail):
    pal = {}
    if detail in GOB_SKIN:
        g_, G_, h_ = GOB_SKIN[detail]
        pal.update(g=g_, G=G_, h=h_)
    b_, B_ = GOB_CLOTH[detail]
    pal.update(b=b_, B=B_)
    look = mg.Look(pal)
    draws = {"front": mg.goblin_front, "back": mg.goblin_back, "side": mg.goblin_side}

    def draw(view, phase):
        c = draws[view](phase, look)
        side = view == "side"
        cx0, cx1 = (5, 10) if side else (4, 11)                                   # chest (with the arms when facing)
        if detail == "mountain":                                                  # stone patches on the skin
            dab(c, [(5, 3), (6, 3), (10, 6), (6, 9), (7, 9), (9, 10), (4, 10), (12, 13)] if not side else [(6, 3), (7, 3), (7, 9), (8, 9), (6, 13)],
                "t_stone", only=("g", "G", "h"))
            dab(c, [(5, 4), (7, 10)] if not side else [(7, 4), (8, 10)], "t_stone2", only=("g", "G", "h"))
        elif detail == "cemetery":                                                # a dark cloak
            paint(c, cx0, 8, cx1, 9, "b"); paint(c, cx0, 9, cx1, 9, "B")
        elif detail == "wetland":                                                 # mud to the knees
            paint(c, 0, 13, 15, 14, "t_mud", only=("g", "G")); dab(c, [(6, 9), (9, 10)] if not side else [(7, 9)], "t_mud", only=("g", "G"))
        elif detail == "campus":                                                  # a scholar's shirt and glasses
            paint(c, cx0, 8, cx1, 9, "b", only=("g", "G"))
            if view == "front":
                c.cells([(5, 3), (6, 3), (9, 3), (10, 3), (4, 4), (7, 4), (8, 4), (11, 4)], "t_glass")
            elif side:
                c.cells([(9, 3), (10, 3), (8, 4), (11, 4)], "t_glass")
        elif detail == "industrial":                                              # overalls, an iron arm and soot
            paint(c, cx0, 8, cx1, 9, "b", only=("g", "G"))
            if view == "front":
                paint(c, 11, 8, 12, 13, "t_iron", only=("g", "G")); dab(c, [(11, 9), (11, 11)], "t_iron2")
                dab(c, [(5, 6), (6, 6), (10, 3)], "t_soot", only=("g", "G", "h"))
            elif view == "back":
                paint(c, 3, 8, 4, 13, "t_iron", only=("g", "G"))
            else:
                ax = {0: 9, 1: 10, 2: 9, 3: 6}[phase]
                paint(c, ax, 8, ax, 12, "t_iron", only=("g", "G")); dab(c, [(10, 6), (9, 3)], "t_soot", only=("g", "G", "h"))
        elif detail == "sand":                                                    # a shell necklace
            if view == "front":
                dab(c, [(6, 8), (7, 9), (8, 9), (9, 8)], "t_shell"); dab(c, [(7, 9)], "t_shell2")
            elif view == "side":
                dab(c, [(9, 8), (10, 9)], "t_shell")
        elif detail == "coast":                                                   # sailor stripes
            paint(c, cx0, 8, cx1, 9, "t_white", only=("g", "G")); paint(c, cx0, 9, cx1, 9, "t_blue")
            if view == "front":
                dab(c, [(7, 8), (8, 8)], "t_blue")
        elif detail == "hotspring":                                               # rosy cheeks
            if view == "front":
                dab(c, [(5, 5), (10, 5), (5, 6), (10, 6)], "t_pink")
            elif view == "side":
                dab(c, [(9, 5), (9, 6)], "t_pink")
        elif detail == "temple":                                                  # a red sash and prayer beads
            paint(c, cx0, 8, cx1, 8, "t_red", only=("g", "G"))
            if view == "front":
                dab(c, [(5, 9), (6, 10), (7, 10), (8, 10), (9, 10), (10, 9)], "t_bead")
            elif view == "side":
                dab(c, [(9, 9), (10, 10)], "t_bead")
        elif detail == "hospital":                                                # a white coat, a red cross
            paint(c, cx0, 8, cx1, 13, "t_white", only=("g", "G", "b", "B"))
            paint(c, 0, 12, 15, 14, "g", only=("t_white",))                       # (legs stay legs)
            if view == "front":
                dab(c, [(6, 10), (8, 9), (7, 10), (8, 10), (9, 10), (8, 11)], "t_white2", only=("t_white",))
                dab(c, [(8, 9), (7, 10), (8, 10), (9, 10), (8, 11)], "t_red")
            elif view == "back":
                dab(c, [(7, 9), (8, 9), (7, 10), (8, 10)], "t_white2")
        elif detail == "military":
            paint(c, cx0, 8, cx1, 9, "b", only=("g", "G"))
        elif detail == "railway":                                                 # a navy vest with gold buttons
            paint(c, cx0, 8, cx1, 9, "b", only=("g", "G"))
            if view == "front":
                dab(c, [(7, 8), (7, 9)], "t_gold")
        return c

    def gear(view, phase):
        g = ms.Gear()
        side = view == "side"
        x0, x1 = (5, 11) if side else (4, 11)
        top = 2
        if detail in HATS and detail != "sand":
            HATS[detail](g.front, x0, x1, top, view)
        item = {"mountain": pick, "river": fish, "farmland": hoe, "cemetery": shovel, "wetland": reed, "campus": book,
                "industrial": wrench, "sand": None, "coast": anchor, "hotspring": bucket, "temple": incense, "hospital": None,
                "military": spear, "railway": lantern}[detail]
        if item:
            held(g, "goblin", view, phase, item)
        if detail == "cemetery":                                                  # the hood
            if view == "back":
                g.front.rect(4, 1, 11, 7, "b"); g.front.rect(4, 7, 11, 7, "B")
            elif side:
                g.front.rect(5, 1, 10, 1, "b"); g.front.rect(4, 2, 7, 7, "b"); g.front.rect(4, 7, 7, 7, "B")
            else:
                g.front.rect(5, 1, 10, 1, "b"); g.front.cells([(4, 2), (11, 2), (4, 3), (11, 3), (3, 3), (12, 3), (3, 4), (12, 4), (4, 2), (11, 2)], "b")
                g.front.rect(5, 2, 10, 2, "b")
        if detail == "river":                                                     # wet hair stuck to the head
            if side:
                g.front.cells([(6, 2), (7, 2), (8, 2), (6, 3), (5, 3)], "t_blue2")
            else:
                g.front.cells([(6, 2), (7, 2), (8, 2), (9, 2), (6, 3), (9, 3)] if view == "front" else [(5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2), (6, 3), (7, 3), (8, 3), (9, 3)], "t_blue2")
            drips(g, phase)
        if detail == "hotspring":
            steam(g, phase)
        if detail == "temple":
            if view == "front":
                x = HANDS["goblin"]["R"] + 1
                g.loose += [(x, 3 - SWING[phase] - phase % 2, "t_smoke"), (x + 1, 2 - SWING[phase], "t_smoke")]
            elif side:
                x = HANDS["goblin"]["side"][phase] + 1
                g.loose += [(x + 1, 5, "t_smoke"), (x, 4 - phase % 2, "t_smoke")]
        if detail == "railway":
            speed_lines(g, view, phase)
        if detail == "mountain" and not side:                                     # a coil of rope over the shoulder
            (g.front if view == "front" else g.back).cells([(3, 8), (2, 9), (2, 10), (3, 11)], "t_rope")
        if detail == "industrial":
            goggles(g.front, x0, x1, top - 1, view)
        if detail == "sand" and view != "back":                                   # a little spade
            held(g, "goblin", view, phase, shovel)
        return g

    return draw, gear, dict(look.palette, **T)


# --- the elf ------------------------------------------------------------------------------------------------------
# Head rows 1-8 (hair on rows 1-2), cols 4-11; eyes row 5 (cols 6, 9); body cols 6-9 rows 9-12; arms cols 5 and 10.
def elf_design(detail):
    import make_elf as me
    pal = dict(me.ELF)
    kw = {}
    cloth = {
        "mountain": ((120, 136, 156), (88, 102, 124)), "river": ((70, 150, 150), (48, 112, 116)), "farmland": ((112, 146, 70), (82, 110, 50)),
        "cemetery": ((62, 56, 80), (42, 38, 56)), "wetland": ((134, 102, 64), (100, 74, 44)), "campus": ((54, 60, 96), (36, 40, 70)),
        "industrial": ((96, 92, 96), (66, 62, 66)), "sand": ((244, 232, 196), (210, 194, 150)), "coast": ((246, 246, 240), (60, 100, 176)),
        "hotspring": ((160, 196, 236), (120, 156, 206)), "temple": ((206, 52, 58), (150, 34, 42)), "hospital": ((248, 248, 244), (206, 208, 206)),
        "military": ((176, 154, 96), (132, 114, 66)), "railway": ((46, 56, 100), (28, 32, 62)),
    }[detail]
    pal.update(c1=cloth[0], c2=cloth[1])
    hair = {"river": ((80, 184, 184), (54, 140, 146)), "farmland": ((240, 196, 90), (200, 150, 56)), "cemetery": ((40, 36, 52), (24, 22, 34)),
            "wetland": ((96, 134, 72), (68, 100, 50)), "sand": ((236, 206, 130), (200, 166, 92)), "coast": ((70, 120, 200), (46, 86, 160)),
            "mountain": ((170, 176, 186), (130, 136, 148)), "temple": ((30, 28, 34), (18, 16, 22)), "hospital": ((150, 100, 52), (116, 74, 38)),
            "industrial": ((70, 60, 56), (48, 40, 38)), "campus": ((90, 60, 40), (64, 42, 28)), "hotspring": ((150, 100, 52), (116, 74, 38)),
            "military": ((116, 74, 38), (90, 56, 28)), "railway": ((178, 196, 230), (140, 158, 200))}.get(detail)
    if hair:
        pal.update(h1=hair[0], h2=hair[1])
        kw.update(hair="h1", hair_dark="h2")
    if detail == "sand":
        pal.update(g=(232, 196, 156), G=(204, 162, 124))
    if detail == "hotspring":
        pal.update(p=(244, 120, 130))
    if detail == "cemetery":
        pal.update(g=(236, 226, 228), G=(206, 194, 200))
    kw["style"] = "long" if detail in ("river", "coast", "temple", "wetland", "sand") else "short"
    kw.update(cloth="c1", shade="c2")
    if detail in ("campus", "hotspring", "temple", "hospital"):
        kw["robe"] = ("c1", "c2" if detail != "hospital" else "t_red")
        kw["sleeve"] = "c1"
    if detail == "cemetery":
        kw.update(sleeve="c1")
    if detail == "industrial":
        kw.update(wide=True)

    def draw(view, phase):
        c = me.elf(view, phase, **kw)
        side = view == "side"
        if detail == "coast":                                                     # stripes on the white tunic
            paint(c, 5, 10, 10, 10, "t_blue", only=("c1", "c2")); paint(c, 5, 12, 10, 12, "t_blue", only=("c1", "c2"))
        elif detail == "sand" and view == "front":
            dab(c, [(6, 9), (7, 10), (8, 10), (9, 9)], "t_shell"); dab(c, [(8, 10)], "t_shell2")
        elif detail == "sand" and side:
            dab(c, [(8, 9), (9, 10)], "t_shell")
        elif detail == "hospital" and view == "front":
            dab(c, [(7, 9), (6, 10), (7, 10), (8, 10), (7, 11)], "t_red")
        elif detail == "hospital" and view == "back":
            dab(c, [(7, 9), (6, 10), (7, 10), (8, 10), (7, 11)], "t_red")
        elif detail == "temple" and view == "front":
            dab(c, [(7, 9), (8, 9), (7, 10), (8, 10)], "t_gold", only=("c1",))
        elif detail == "industrial":                                              # a steel gauntlet, soot on the cheek
            if view == "front":
                paint(c, 11, 9, 11, 14, "t_iron", only=("g", "c1", "c2")); dab(c, [(9, 6), (10, 7)], "t_soot", only=("g", "p"))
            elif view == "back":
                paint(c, 4, 9, 4, 14, "t_iron", only=("g", "c1", "c2"))
            else:
                ax = {0: 8, 1: 9, 2: 8, 3: 6}[phase]
                paint(c, ax, 9, ax, 12, "t_iron", only=("g",)); dab(c, [(10, 6)], "t_soot", only=("g", "p"))
        elif detail == "military" and view == "front":
            dab(c, [(6, 9)], "t_gold")
        elif detail == "campus" and view == "front":                              # glasses
            c.cells([(4, 5), (7, 5), (8, 5), (11, 5), (5, 6), (6, 6), (9, 6), (10, 6)], "t_glass")
        elif detail == "campus" and side:
            c.cells([(8, 4), (8, 5), (10, 4), (10, 5), (9, 6)], "t_glass")
        elif detail == "railway" and view == "front":
            dab(c, [(7, 9), (7, 10), (8, 12)], "t_gold", only=("c1", "c2"))
        elif detail == "wetland":
            paint(c, 0, 13, 15, 14, "t_mud", only=("K",))
        elif detail == "mountain" and view == "front":                            # the rope across the chest
            dab(c, [(6, 9), (7, 10), (8, 11), (9, 12)], "t_rope")
        elif detail == "hotspring" and view == "front":
            dab(c, [(7, 9), (8, 10)], "c2", only=("c1",))                         # the yukata's crossed collar
        return c

    def gear(view, phase):
        g = ms.Gear()
        side = view == "side"
        top = 1
        x0, x1 = 4, 11
        if detail in HATS and detail != "sand":
            HATS[detail](g.front, x0, x1, top, view)
        item = {"mountain": None, "river": reed, "farmland": sheaf, "cemetery": lantern, "wetland": reed, "campus": book,
                "industrial": wrench, "sand": None, "coast": conch, "hotspring": None, "temple": beads, "hospital": leaf,
                "military": spear, "railway": lantern}[detail]
        if item:
            held(g, "elf", view, phase, item)
        if detail == "industrial":
            goggles(g.front, 4, 11, 2, view)
        if detail == "cemetery":                                                  # a dark hood over the hair
            if view == "back":
                g.front.rect(4, 0, 11, 9, "c2")
            elif side:
                g.front.rect(5, 0, 10, 1, "c2"); g.front.rect(3, 2, 5, 10, "c2")
            else:
                g.front.rect(5, 0, 10, 0, "c2"); g.front.rect(4, 1, 11, 2, "c2"); g.front.cells([(3, 3), (12, 3), (3, 4), (12, 4)], "c2")
        if detail == "mountain":                                                  # a rope coil, the mountain wind
            if view == "front":
                g.front.cells([(4, 9), (3, 10), (3, 11), (4, 12)], "t_rope2")
            elif view == "back":
                g.front.cells([(6, 9), (7, 9), (8, 9), (9, 9), (6, 10), (9, 10), (6, 11), (7, 11), (8, 11), (9, 11)], "t_rope")
            else:
                g.back.cells([(4, 9), (3, 10), (3, 11), (4, 12), (5, 12)], "t_rope")
            g.loose += [(0 + phase % 2, 3, "t_speed"), (1 + phase % 2, 3, "t_speed"), (14 - phase % 2, 7, "t_speed"), (15 - phase % 2, 7, "t_speed")]
        if detail == "river":
            drips(g, phase)
        if detail == "farmland":                                                  # a band of wheat ears in the hair
            g.front.cells([(5, 0), (7, 0), (9, 0)] if view != "side" else [(6, 0), (8, 0)], "t_wheat")
        if detail == "wetland":
            lily(g.front, x0, x1, top + 1, view)
        if detail == "sand":                                                      # a shell in the hair
            g.front.cells([(4, 1), (5, 0)] if view == "front" else ([(10, 0), (11, 1)] if view == "back" else [(5, 0), (6, 0)]), "t_shell2")
        if detail == "coast":                                                     # seaweed in the hair
            g.front.cells([(11, 1), (12, 2), (12, 3)] if view == "front" else ([(4, 1), (3, 2), (3, 3)] if view == "back" else [(4, 2), (3, 3), (3, 4)]), "t_weed")
        if detail == "hotspring":
            steam(g, phase)
        if detail == "temple":                                                    # a red ribbon in the hair
            g.front.cells([(10, 1), (11, 0), (12, 1)] if view == "front" else ([(5, 1), (4, 0), (3, 1)] if view == "back" else [(5, 1), (4, 0), (4, 2)]), "t_red")
        if detail == "railway":
            speed_lines(g, view, phase)
        return g

    return draw, gear, dict(pal, **T)


# --- the undead ---------------------------------------------------------------------------------------------------
# Skeleton: skull rows 1-7 (cols 4-11, side 5-11), sockets rows 4-5, ribs cols 5-10 rows 9-12, arms cols 4 and 11.
# Ghost (幽影): top row 2 (+1 when it bobs), body cols 4-11 down to the hem; eyes 4-6 rows below the top.
UNDEAD_KIND = {"river": "ghost", "cemetery": "ghost", "wetland": "ghost", "railway": "ghost", "campus": "wisp"}
UNDEAD_BIG = ("mountain", "military")


def undead_design(detail):
    import make_undead as mu
    pal = dict(mu.BASE)
    bones = {"mountain": ((172, 170, 160), (128, 126, 118), (206, 204, 194)), "industrial": ((150, 158, 172), (104, 110, 126), (196, 202, 214)),
             "sand": ((228, 202, 150), (188, 160, 110), (246, 228, 188)), "hotspring": ((252, 214, 206), (222, 172, 166), (255, 236, 230)),
             "coast": ((218, 222, 206), (170, 178, 160), (240, 244, 230))}.get(detail)
    if bones:
        pal.update(w=bones[0], s=bones[1], h=bones[2])
    soul = {"river": ((80, 166, 170), (52, 124, 132), (136, 206, 210)), "cemetery": ((70, 62, 92), (48, 42, 66), (104, 96, 128)),
            "wetland": ((112, 122, 70), (82, 90, 50), (146, 156, 100)), "railway": ((96, 120, 186), (66, 86, 146), (140, 164, 220))}.get(detail)
    if soul:
        pal.update(V=soul[0], v=soul[1], u=soul[2])
    if detail == "cemetery":
        pal.update(e=(150, 214, 252))
    if detail == "campus":                                                        # a parchment-coloured flame
        pal.update(Q=(240, 206, 120), q=(196, 156, 74), Z=(255, 246, 214), d=(70, 50, 40))
    tabard = {"farmland": ((150, 110, 60), (104, 72, 36)), "coast": ((248, 246, 238), (60, 100, 176)), "temple": ((196, 40, 48), (140, 26, 36)),
              "military": ((176, 154, 96), (132, 114, 66)), "sand": ((236, 220, 170), (196, 176, 120))}.get(detail)
    if tabard:
        pal.update(c1=tabard[0], c2=tabard[1])
    kind = UNDEAD_KIND.get(detail, "skel")

    def draw(view, phase):
        side = view == "side"
        if kind == "ghost":
            c = mu.ghost(view, phase)
        elif kind == "wisp":
            c = mu.wisp(view, phase)
        else:
            c = mu.skeleton(view, phase, big=detail in UNDEAD_BIG)
            if tabard:
                x0, x1 = (6, 9) if side else (5, 10)
                for y in range(9, 13):
                    for x in range(x0, x1 + 1):
                        if c.px[y][x] not in (None, "O"):
                            c.px[y][x] = "c1" if x < x1 else "c2"
                if detail == "coast":
                    paint(c, x0, 10, x1, 10, "t_blue"); paint(c, x0, 12, x1, 12, "t_blue")
                if detail == "temple" and view == "front":
                    dab(c, [(7, 10), (8, 10)], "t_gold")
                if detail == "farmland":                                          # a patch, and straw poking out
                    dab(c, [(6, 10)] if not side else [(7, 10)], "t_straw2")
            if detail == "hospital":                                              # stitches across the skull, a bandaged arm
                if view == "front":
                    dab(c, [(5, 2), (6, 3), (7, 2), (8, 3), (9, 2), (10, 3)], "t_stitch")
                    paint(c, 4, 9, 4, 13, "t_white", only=("w", "s"))
                    dab(c, [(5, 9), (6, 10), (9, 11), (10, 9)], "t_stitch", only=("w", "s"))
                    dab(c, [(10, 11)], "t_red", only=("w", "s"))
                elif view == "back":
                    dab(c, [(6, 2), (7, 3), (8, 2), (9, 3), (10, 4)], "t_stitch")
                    paint(c, 11, 9, 11, 13, "t_white", only=("w", "s"))
                else:
                    dab(c, [(6, 2), (7, 3), (8, 2), (9, 3)], "t_stitch")
                    ax = {0: 8, 1: 9, 2: 8, 3: 6}[phase]
                    paint(c, ax, 9, ax, 12, "t_white", only=("w", "s"))
            if detail == "industrial":                                            # rust spots
                dab(c, [(5, 6), (10, 9), (7, 11)] if not side else [(7, 6), (8, 11)], "t_reed2", only=("w", "s", "h"))
            if detail == "hotspring" and view == "front":
                dab(c, [(4, 6), (11, 6)], "t_pink")
        return c

    def gear(view, phase):
        g = ms.Gear()
        side = view == "side"
        bob = 1 if phase in (1, 2) else 0
        if kind == "ghost":
            top, x0, x1 = 2 + bob, 5, 10
        elif kind == "wisp":
            top, x0, x1 = 3, 5, 10
        elif detail in UNDEAD_BIG:
            top, x0, x1 = 1, (4 if side else 3), 12
        else:
            top, x0, x1 = 1, (5 if side else 4), 11
        if detail in HATS and detail != "wetland":
            HATS[detail](g.front, x0, x1, top, view)
        if kind == "skel":
            item = {"mountain": pick, "farmland": pitchfork, "industrial": wrench, "sand": None, "coast": anchor, "hotspring": bucket,
                    "temple": None, "hospital": None, "military": spear}[detail]
            if item:
                held(g, "undead", view, phase, item)
        else:
            fy = 9 + (bob if kind == "ghost" else 0)
            item = {"river": None, "cemetery": lantern, "wetland": reed, "railway": lantern, "campus": book}[detail]
            if item:
                held_at(g, view, item, (13, fy if item is not book else fy + 2), (12, fy if item is not book else fy + 2), pole=item is reed)
        if detail == "river":                                                     # seaweed hanging off it, dripping
            if side:
                pts = [(6, top), (5, top + 1), (5, top + 2), (4, top + 3), (4, top + 4), (5, top + 5)]
            else:
                pts = [(6, top), (5, top + 1), (4, top + 2), (4, top + 3), (5, top + 4), (4, top + 5), (9, top), (10, top + 1), (11, top + 2), (11, top + 3), (12, top + 4)]
                if view == "back":
                    pts = [(15 - x, y) for x, y in pts]
            g.front.cells(pts, "t_kelp")
            drips(g, phase)
        if detail == "cemetery" and view != "back":                               # tears
            tx = (6, 10) if view == "front" else (10, 10)
            g.loose += [(tx[0] - 1, top + 7 + phase % 2, "t_tear")]
            g.front.cells([(tx[0], top + 7), (tx[1], top + 7)] if view == "front" else [(10, top + 7)], "t_tear")
        if detail == "wetland":
            lily(g.front, x0, x1, top, view)
            g.loose += [(3, 13 - phase % 2, "t_mud"), (12, 14 - (phase + 1) % 2, "t_mud")]
        if detail == "campus" and view != "back":                                 # glasses
            if view == "front":
                g.front.cells([(4, 6), (5, 6), (6, 6), (8, 6), (9, 6), (10, 6), (4, 7), (6, 7), (7, 7), (8, 7), (10, 7)], "t_wood2")
            else:
                g.front.cells([(5, 6), (6, 6), (7, 6), (5, 7), (7, 7), (8, 7)], "t_wood2")
        if detail == "railway":
            speed_lines(g, view, phase)
        if detail == "hotspring":
            steam(g, phase, (2, 13))
        if detail == "coast":                                                     # seaweed over the skull
            g.front.cells([(9, 1), (10, 2), (10, 3)] if view == "front" else ([(5, 1), (5, 2), (5, 3)] if view == "back" else [(7, 0), (6, 1), (6, 2)]), "t_weed")
        if detail == "sand" and view != "back":
            if view == "front":
                g.front.cells([(5, 8), (6, 9), (9, 9), (10, 8)], "t_shell"); g.front.put(8, 9, "t_shell2"); g.front.put(7, 9, "t_shell")
            else:
                g.front.cells([(9, 8), (10, 9)], "t_shell")
        if detail == "temple" and view != "back":                                 # a torn yellow talisman on the brow
            if view == "front":
                g.front.rect(7, 0, 8, 4, "t_paper"); g.front.cells([(7, 1), (8, 2), (7, 3)], "t_red"); g.front.put(8, 4, None)
                g.front.put(9, 3, "t_paper")                                       # the torn-off corner, falling
            else:
                g.front.rect(11, 1, 12, 4, "t_paper"); g.front.cells([(12, 2), (12, 3)], "t_red"); g.front.put(12, 4, None)
        if detail == "temple":                                                    # broken prayer beads, scattered
            g.loose += [(2, 14, "t_bead"), (13, 14, "t_bead"), (1, 13, "t_red")]
        if detail == "farmland" and view != "back":                               # straw at the wrists and the neck
            if view == "front":
                g.front.cells([(3, 12 + SWING[phase]), (12, 12 - SWING[phase])], "t_straw")
            else:
                g.front.cells([(10, 8)], "t_straw")
        return g

    return draw, gear, dict(pal, **T)


# --- the beastfolk -------------------------------------------------------------------------------------------------------
# make_beast's calm warrior body: head rows 1-6 (cols 4-11, side 4-13 with the snout), shoulders row 7, fists row 11.
# The land shows in the fur's colour, the loincloth and what they carry; the wet, clever or warm ones are foxes.
BEAST_FOX = ("river", "campus", "sand", "hotspring")


def beast_design(detail):
    import make_beast as mb
    fur = {
        "mountain": ((150, 150, 146), (110, 110, 106), (196, 196, 190)), "river": ((110, 150, 156), (80, 112, 120), (200, 226, 230)),
        "farmland": ((214, 176, 104), (170, 132, 70), (246, 226, 170)), "cemetery": ((60, 56, 66), (40, 36, 46), (120, 116, 128)),
        "wetland": ((120, 100, 70), (90, 72, 50), (170, 150, 116)), "campus": ((176, 110, 60), (136, 80, 40), (240, 220, 196)),
        "industrial": ((112, 108, 108), (78, 74, 74), (170, 166, 166)), "sand": ((226, 192, 136), (190, 154, 100), (250, 236, 206)),
        "coast": ((126, 140, 160), (92, 104, 124), (210, 220, 232)), "hotspring": ((236, 160, 120), (200, 120, 90), (255, 230, 214)),
        "temple": ((130, 84, 62), (96, 60, 44), (204, 170, 146)), "hospital": ((240, 240, 244), (196, 200, 212), (255, 255, 255)),
        "military": ((140, 128, 100), (104, 94, 70), (196, 184, 156)), "railway": ((100, 112, 140), (72, 82, 108), (180, 190, 214)),
    }[detail]
    cloth = {
        "mountain": ((120, 136, 156), (88, 102, 124)), "river": ((70, 150, 150), (48, 112, 116)), "farmland": ((112, 146, 70), (82, 110, 50)),
        "cemetery": ((62, 56, 80), (42, 38, 56)), "wetland": ((134, 102, 64), (100, 74, 44)), "campus": ((54, 60, 96), (36, 40, 70)),
        "industrial": ((96, 92, 96), (66, 62, 66)), "sand": ((244, 232, 196), (210, 194, 150)), "coast": ((246, 246, 240), (60, 100, 176)),
        "hotspring": ((160, 196, 236), (120, 156, 206)), "temple": ((206, 52, 58), (150, 34, 42)), "hospital": ((248, 248, 244), (206, 208, 206)),
        "military": ((176, 154, 96), (132, 114, 66)), "railway": ((46, 56, 100), (28, 32, 62)),
    }[detail]
    pal = dict(mb.BASE, F=fur[0], f=fur[1], L=fur[2], H=mb.HORN[0], h=mb.HORN[1], c1=cloth[0], c2=cloth[1])
    fox = detail in BEAST_FOX
    build = "big" if detail in ("mountain", "military") else "lean" if fox else "norm"
    top = "robe" if detail in ("campus", "hotspring", "temple", "hospital") else "bare"

    def draw(view, phase):
        c = mb.warrior(view, phase, lambda cc, v: mb.w_head(cc, v, ears="fox" if fox else "wolf", paint=detail not in ("hospital", "campus")),
                       build=build, top=top, cloth="c1", behind=mb.w_tail("fox" if fox else "wolf"))
        if detail == "hospital" and view != "side":
            dab(c, [(7, 9), (6, 10), (7, 10), (8, 10), (7, 11)], "t_red")
        elif detail == "campus" and view == "front":                              # glasses
            c.cells([(4, 3), (5, 3), (6, 3), (9, 3), (10, 3), (11, 3)], "t_glass")
        elif detail == "campus" and view == "side":
            c.cells([(7, 3), (8, 3), (9, 3)], "t_glass")
        elif detail == "industrial" and view == "front":                          # a steel-wrapped paw, soot
            paint(c, 12, 8, 13, 11, "t_iron", only=("F", "f")); dab(c, [(10, 5), (11, 5)], "t_soot", only=("F", "L"))
        elif detail == "sand" and view == "front":
            dab(c, [(6, 8), (7, 9), (8, 9), (9, 8)], "t_shell"); dab(c, [(8, 9)], "t_shell2")
        elif detail == "coast" and view != "side":                                # a striped sash
            dab(c, [(5, 8), (6, 9), (7, 10)], "t_blue")
        elif detail == "mountain" and view == "front":                            # the rope across the chest
            dab(c, [(5, 8), (6, 9), (7, 10), (8, 10)], "t_rope")
        elif detail == "wetland":
            paint(c, 0, 13, 15, 14, "t_mud", only=("f", "F"))
        elif detail == "temple" and view == "front":
            dab(c, [(6, 6), (9, 6)], "t_red", only=("b",))                       # red cord tied round the fangs
        return c

    def gear(view, phase):
        g = ms.Gear()
        side = view == "side"
        x0, x1, top = 4, 11, 1
        if detail in HATS:
            HATS[detail](g.front, x0, x1, top, view)
        item = {"mountain": pick, "river": reed, "farmland": sheaf, "cemetery": lantern, "wetland": None, "campus": book,
                "industrial": wrench, "sand": None, "coast": conch, "hotspring": None, "temple": beads, "hospital": leaf,
                "military": spear, "railway": lantern}[detail]
        if item:
            held(g, "beast", view, phase, item)
        if detail == "industrial":
            goggles(g.front, 4, 11, 1, view)
        if detail == "river":
            drips(g, phase)
        if detail == "hotspring":
            steam(g, phase)
        if detail == "railway":
            speed_lines(g, view, phase)
        if detail == "cemetery" and not side:                                      # a howl: two notes in the air
            g.loose += [(1, 1 + phase % 2, "t_tear"), (14, 2 - phase % 2, "t_tear")]
        return g

    return draw, gear, dict(pal, **T)


DESIGNS = {"goblin": goblin_design, "elf": elf_design, "undead": undead_design, "beast": beast_design}


def terrain_sheet(race, detail):
    draw, gear, pal = DESIGNS[race](detail)
    img = [[(0, 0, 0, 0)] * (4 * SIZE) for _ in range(3 * SIZE)]
    for r, view in enumerate(("front", "back", "side")):
        for phase in range(4):
            canvas = gear(view, phase).onto(draw(view, phase))
            for y in range(SIZE):
                for x in range(SIZE):
                    key = canvas.px[y][x]
                    if key is not None:
                        img[r * SIZE + y][phase * SIZE + x] = pal[key] + (255,)
    return img


def terrain_breeds(race):
    """The race's fourteen terrain breeds, as (id, name, stats, blurb, sheet file, image, detail): never born by chance."""
    return [(f"d_{d}", NAMES[race][d], terrain_stats(race, d), blurb(race, d), f"d_{d}.png", terrain_sheet(race, d), d) for d in DETAILS]


def manifest_entries(race):
    return [{"id": i, "name": n, "weight": 0, "boost": 0, "blurb": b, "stats": stats, "sheet": sheet, "terrain": d}
            for i, n, stats, b, sheet, _img, d in terrain_breeds(race)]


def write(race, root):
    for _i, _n, _s, _b, sheet, img, _d in terrain_breeds(race):
        mg.write_png(os.path.join(root, sheet), img)


def preview(path, zoom=3):
    """Each race a row: the common resident, then the fourteen, each front and side (phase 0)."""
    import make_elf as me
    import make_undead as mu
    import make_beast as mb
    commons = {"goblin": mg.build_sheet(False, mg.BREEDS[0][7]), "elf": me.breed_sheet(me.BREEDS[0][7], me.BREEDS[0][8]),
               "undead": mu.breed_sheet(mu.BREEDS[0][7], mu.BREEDS[0][8]), "beast": mb.breed_sheet(mb.BREEDS[0][7], mb.BREEDS[0][8])}
    races = ("goblin", "elf", "undead", "beast")
    cols = 15 * 2
    gap = 4
    cw = SIZE + gap
    w, h = cols * cw * zoom, len(races) * (SIZE + gap) * zoom
    bg = (110, 150, 96, 255)
    out = [[bg] * w for _ in range(h)]
    for r, race in enumerate(races):
        sheets = [commons[race]] + [terrain_sheet(race, d) for d in DETAILS]
        col = 0
        for k, sheet in enumerate(sheets):
            for view in (0, 2):
                for y in range(SIZE):
                    for x in range(SIZE):
                        px = sheet[view * SIZE + y][x]
                        if px[3]:
                            for oy in range(zoom):
                                for ox in range(zoom):
                                    out[(r * (SIZE + gap) + y + gap // 2) * zoom + oy][(col * cw + x + gap // 2) * zoom + ox] = px
                col += 1
    mg.write_png(path, out)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1], zoom=int(sys.argv[sys.argv.index("--zoom") + 1]) if "--zoom" in sys.argv else 3)
