# The undead's decorations a race level unlocks (DESKTOP.md §5.5): five every three levels, from 3 to 24, the later the
# grander. Run inside make_decor.py's namespace (its helpers, GRAVE, SOUL, DARKWOOD, VIOLET, tombstone…), so no imports.
# One a tier does something (fn "lv_…", Decor.swift); the other four are for looks.

U_IRON = [(52, 52, 62), (80, 80, 94), (110, 110, 124)]
OBSIDIAN = [(30, 26, 40), (50, 44, 66), (76, 68, 98)]
U_GOLD = (200, 160, 70)
BLOOD = (150, 30, 50)


def skull(img, x, y, c=None, eyes=INK):
    """A small skull, its middle at (x, y): five wide, four tall."""
    c = c or BONE
    disk(img, x, y, 2, c); rect(img, x - 1, y + 2, 3, 1, c)
    put(img, x - 1, y, eyes); put(img, x + 1, y, eyes)


def candle(img, x, y, h, f, k=0):
    rect(img, x, y, 1, h, (236, 230, 210)); put(img, x, y + h - 1, (200, 190, 170))
    put(img, x, y - 1 - (k + f) % 2, SOUL); put(img, x, y - 1, (220, 255, 240))


# ==== level 3 =======================================================================================================
@item("u_lv3_candles", U, "燭光小墳", "scene", 1, frames=2, level=3)
def u_lv3_candles(f):
    img = new(18, 16)
    disk(img, 9, 13, 8, (90, 74, 56), 3); disk(img, 9, 12, 6, (110, 90, 66), 2)
    tombstone(img, 6, 2, w=6, h=9, cross=True)
    for k, (x, h) in enumerate(((2, 4), (4, 3), (14, 4), (16, 2))):
        candle(img, x, 13 - h, h, f, k)
    return finish(img, (20, 18, 26))


@item("u_lv3_restslab", U, "安息石床", "furniture", 2, frames=2, fn="lv_rest", level=3)
def u_lv3_restslab(f):
    """A stone slab with a skull pillow and a soft soul glow: lying on it mends."""
    img = new(26, 16)
    rect(img, 1, 6, 24, 5, GRAVE[1]); rect(img, 1, 6, 24, 1, GRAVE[2]); rect(img, 1, 10, 24, 1, GRAVE[0])
    rect(img, 3, 11, 3, 5, GRAVE[0]); rect(img, 20, 11, 3, 5, GRAVE[0])
    rect(img, 7, 5, 16, 1, (90, 70, 110)); rect(img, 7, 4, 16, 1, (120, 96, 150))   # a violet shroud
    skull(img, 4, 3)
    for k in range(3):                                                              # the mending glow rises
        put(img, 10 + k * 5, 2 - (k + f) % 2, SOUL)
        put(img, 12 + k * 4, 0 + (k + f) % 2, (200, 255, 244))
    return finish(img, (20, 18, 26))


@item("u_lv3_lantern", U, "鬼火提燈", "sign", 1, frames=2, level=3)
def u_lv3_lantern(f):
    img = new(14, 26)
    rect(img, 3, 4, 2, 22, DARKWOOD); rect(img, 3, 4, 8, 1, DARKWOOD)
    line(img, 10, 5, 10, 8, U_IRON[1])
    sway = f
    rect(img, 8 + sway, 9, 5, 7, U_IRON[0]); rect(img, 9 + sway, 10, 3, 5, SOUL); put(img, 10 + sway, 11, (220, 255, 244))
    rect(img, 8 + sway, 8, 5, 1, U_IRON[2]); rect(img, 8 + sway, 16, 5, 1, U_IRON[2])
    rect(img, 1, 24, 6, 2, (90, 74, 56))
    return finish(img, (20, 18, 26))


@item("u_lv3_wreath", U, "黑玫瑰花圈", "flower", 1, level=3)
def u_lv3_wreath(f):
    img = new(16, 18)
    rect(img, 7, 10, 2, 8, DARKWOOD)                                                 # a stand
    rect(img, 4, 16, 8, 2, DARKWOOD)
    for a in range(0, 360, 30):                                                     # the ring of leaves
        x = round(8 + 5 * math.cos(math.radians(a))); y = round(7 + 5 * math.sin(math.radians(a)))
        disk(img, x, y, 1, (50, 80, 54))
    for a in range(15, 360, 72):                                                    # black roses on it
        x = round(8 + 5 * math.cos(math.radians(a))); y = round(7 + 5 * math.sin(math.radians(a)))
        disk(img, x, y, 1, (40, 30, 44)); put(img, x, y, (90, 40, 70))
    rect(img, 6, 11, 4, 2, VIOLET)                                                  # a ribbon
    return finish(img, (20, 18, 26))


@item("u_lv3_digger", U, "掘墓人小屋", "building", 4, frames=2, level=3)
def u_lv3_digger(f):
    img = hut(28, 16, (96, 84, 80), (56, 46, 54), roof_h=12, chimney=True, smoke=True, frame=f)
    w = img.width
    for k in range(3):                                                              # spades leant on the wall
        rect(img, 4 + k * 3, img.height - 12, 1, 10, WOOD); rect(img, 3 + k * 3, img.height - 3, 3, 2, (150, 150, 160))
    tombstone(img, w - 9, img.height - 9, w=6, h=8)
    return finish(img, (24, 20, 30))


# ==== level 6 =======================================================================================================
@item("u_lv6_grindwheel", U, "骨磨輪", "furniture", 2, frames=2, fn="lv_whet", level=6)
def u_lv6_grindwheel(f):
    """A grinding wheel of bone, turned by a skeleton arm: the gear keeps its edge."""
    img = new(24, 22)
    rect(img, 3, 12, 2, 10, DARKWOOD); rect(img, 19, 12, 2, 10, DARKWOOD); rect(img, 2, 19, 20, 2, DARKWOOD)
    disk(img, 12, 11, 7, GRAVE[1]); disk(img, 12, 11, 5, GRAVE[2]); disk(img, 12, 11, 1, U_IRON[0])
    for a in range(0, 360, 90):                                                     # its spokes turn
        a2 = a + (45 if f else 0)
        put(img, round(12 + 4 * math.cos(math.radians(a2))), round(11 + 4 * math.sin(math.radians(a2))), GRAVE[0])
    rect(img, 4, 11, 8, 1, BONE)                                                    # the axle and its bony crank
    hx, hy = (12 + (5 if f else -5)), (5 if f else 17)
    line(img, 12, 11, hx, hy, BONE); disk(img, hx, hy, 1, BONE_SHADE)
    if f:
        put(img, 20, 6, (255, 230, 150)); put(img, 21, 5, (255, 200, 100))         # sparks
    return finish(img, (20, 18, 26))


@item("u_lv6_ossuary", U, "骸骨堂", "building", 4, level=6)
def u_lv6_ossuary(f):
    img = new(36, 36)
    rect(img, 4, 12, 28, 24, GRAVE[1]); rect(img, 4, 12, 3, 24, GRAVE[2])
    rect(img, 2, 9, 32, 3, GRAVE[0]); rect(img, 6, 6, 24, 3, GRAVE[1]); rect(img, 12, 3, 12, 3, GRAVE[2])
    skull(img, 18, 3)
    for y in (15, 21, 27):                                                          # rows of skulls in the walls
        for x in range(8, 30, 5):
            if not (14 <= x <= 22 and y >= 21):
                skull(img, x, y, c=BONE_SHADE)
    rect(img, 15, 23, 7, 13, (24, 20, 30)); disk(img, 18, 23, 3, (24, 20, 30))
    return finish(img, (30, 28, 36))


@item("u_lv6_ravenbranch", U, "烏鴉枯枝", "tree", 2, frames=2, level=6)
def u_lv6_ravenbranch(f):
    img = new(24, 36)
    rect(img, 11, 12, 3, 24, DARKWOOD); put(img, 10, 35, DARKWOOD); put(img, 14, 35, DARKWOOD)
    line(img, 12, 18, 3, 9, DARKWOOD); line(img, 12, 14, 21, 6, DARKWOOD); line(img, 12, 12, 10, 2, DARKWOOD)
    line(img, 6, 12, 4, 15, DARKWOOD); line(img, 18, 9, 21, 12, DARKWOOD)
    bird(4, 7)(img, f); bird(20, 4)(img, f + 1)
    return finish(img, (20, 18, 26))


@item("u_lv6_urns", U, "骨灰罈", "furniture", 1, level=6)
def u_lv6_urns(f):
    img = new(20, 18)
    rect(img, 1, 15, 18, 3, GRAVE[1]); rect(img, 1, 15, 18, 1, GRAVE[2])               # a stone shelf
    for (cx, h, c) in ((5, 10, (90, 110, 130)), (11, 13, (120, 86, 130)), (16, 8, (140, 120, 96))):
        top = 15 - h
        for y in range(top + 2, 15):                                                    # a round belly, a narrow neck
            half = max(1, round(3 * math.sin(math.pi * (y - top - 1) / (h - 1))) + 1)
            rect(img, cx - half, y, half * 2 + 1, 1, c)
            put(img, cx - half, y, shade(c, 1.25))
        rect(img, cx - 2, top + 1, 5, 1, shade(c, 0.8)); rect(img, cx - 1, top, 3, 1, shade(c, 1.2))   # lip and lid
        rect(img, cx - 2, top + h // 2 + 1, 5, 1, U_GOLD)                                 # a band
    return finish(img, (20, 18, 26))


@item("u_lv6_mosscross", U, "青苔十字架", "sign", 1, level=6)
def u_lv6_mosscross(f):
    img = new(14, 22)
    rect(img, 6, 2, 3, 20, GRAVE[1]); rect(img, 2, 6, 11, 3, GRAVE[1]); rect(img, 6, 2, 1, 20, GRAVE[2])
    for (x, y) in ((6, 3), (2, 7), (8, 13), (7, 17), (11, 7), (6, 20)):
        put(img, x, y, (80, 120, 70)); put(img, x + 1, y, (100, 140, 80))
    rect(img, 3, 20, 9, 2, (90, 74, 56))
    return finish(img, (20, 18, 26))


# ==== level 9 =======================================================================================================
@item("u_lv9_cradle", U, "搖籃棺", "furniture", 2, frames=2, fn="lv_nursery", level=9)
def u_lv9_cradle(f):
    """A little coffin on rockers with a soul mobile above: the young near it grow faster."""
    img = new(22, 24)
    tilt = 1 if f else -1
    rect(img, 4, 13 + (tilt > 0), 14, 5, DARKWOOD); rect(img, 5, 12 + (tilt > 0), 12, 1, (110, 90, 80))
    rect(img, 4, 13 - (tilt < 0), 2, 3, (110, 90, 80))
    rect(img, 9, 14, 4, 2, (130, 110, 150))                                         # a little blanket
    for x in range(2, 21):                                                          # the rocker
        put(img, x, 20 + ((x - 11) ** 2) // 30 - (1 if (x < 11) == (tilt > 0) else 0), DARKWOOD)
    rect(img, 10, 1, 1, 6, U_IRON[1]); rect(img, 5, 3, 11, 1, U_IRON[1])                # the mobile
    for k, x in enumerate((5, 10, 15)):
        put(img, x, 4, U_IRON[1]); disk(img, x + (f if k != 1 else -f), 6 + (k % 2), 1, SOUL)
    return finish(img, (20, 18, 26))


@item("u_lv9_willow", U, "哭泣柳", "tree", 4, frames=2, level=9)
def u_lv9_willow(f):
    img = leafy(34, 40, (70, 60, 66), [(50, 66, 70), (70, 92, 96), (96, 120, 120)], R(901), trunk_h=14, frame=f, shape="droop")
    for (x, y) in ((9, 20), (24, 22), (16, 26)):                                    # tears of soul light
        put(img, x, y + f, SOUL); put(img, x, y + 1 + f, (200, 255, 244))
    rect(img, 15, 30, 1, 2, INK); rect(img, 18, 30, 1, 2, INK)                       # a sad face in the bark
    rect(img, 16, 34, 2, 1, INK)
    return finish(img, (20, 18, 26))


@item("u_lv9_ghostcat", U, "幽靈貓", "creature", 1, frames=2, level=9)
def u_lv9_ghostcat(f):
    img = new(16, 18)
    body, dark = (196, 228, 230), (150, 190, 196)
    y0 = 1 - f                                                                          # it floats up and down
    disk(img, 7, 12 + y0, 4, body, 4); rect(img, 4, 15 + y0, 7, 1, dark)                # sitting body
    disk(img, 7, 6 + y0, 3, body)                                                       # head and ears
    put(img, 4, 2 + y0, body); put(img, 4, 3 + y0, body); put(img, 10, 2 + y0, body); put(img, 10, 3 + y0, body)
    put(img, 6, 6 + y0, SOUL); put(img, 8, 6 + y0, SOUL); put(img, 7, 7 + y0, dark)
    for y in range(9, 15):                                                              # its tail curls up
        put(img, 11 + (14 - y) // 2, y + y0, dark)
    put(img, 13, 8 + y0 + f, dark); put(img, 14, 7 + y0 + f, dark)
    for k in range(3):
        put(img, 4 + k * 3, 17, (180, 220, 220, 110))                                   # a faint wisp below
    return finish(img, (40, 60, 70))


@item("u_lv9_fountain", U, "枯骨噴泉", "scene", 2, frames=2, level=9)
def u_lv9_fountain(f):
    img = new(26, 26)
    disk(img, 13, 21, 12, GRAVE[1], 4); disk(img, 13, 20, 10, (60, 120, 110), 2)
    rect(img, 11, 10, 4, 10, GRAVE[2]); rect(img, 11, 10, 1, 10, GRAVE[1])
    skull(img, 13, 7)
    for k in range(4):                                                              # ghostly water from its jaw
        y = 11 + k * 2
        put(img, 13 - 2 - k + f, y, SOUL); put(img, 13 + 2 + k - f, y, SOUL)
    return finish(img, (20, 18, 26))


@item("u_lv9_moonlily", U, "月影百合", "flower", 1, level=9)
def u_lv9_moonlily(f):
    img = new(18, 18)
    for (x, top, lean) in ((4, 7, -1), (9, 3, 0), (14, 6, 1)):
        line(img, x, 17, x + lean, top + 3, (60, 90, 80))
        put(img, x - 1, 13, (70, 110, 90)); put(img, x + 1, 11, (70, 110, 90))
        cx = x + lean
        rect(img, cx - 1, top, 3, 3, (210, 220, 240)); put(img, cx - 2, top - 1, (190, 200, 230)); put(img, cx + 2, top - 1, (190, 200, 230))
        put(img, cx, top - 1, (230, 236, 250)); put(img, cx, top + 1, SOUL)            # trumpet petals, a glowing heart
    return finish(img, (20, 18, 26))


# ==== level 12 ======================================================================================================
@item("u_lv12_warbanner", U, "骷髏戰旗", "sign", 2, frames=2, fn="lv_might", level=12)
def u_lv12_warbanner(f):
    """A tattered war banner on a bone pole: the camp fights harder."""
    img = new(22, 40)
    rect(img, 3, 2, 2, 38, BONE); rect(img, 4, 2, 1, 38, BONE_SHADE)
    skull(img, 4, 2)
    rect(img, 5, 6, 15, 1, U_IRON[1])
    for y in range(7, 24):                                                          # the cloth ripples
        wave = (1 if (y // 4 + f) % 2 else 0)
        end = 19 - (3 if y > 19 and y % 2 else 0)
        rect(img, 5, y, end - 5 + wave, 1, (60, 40, 80) if y % 5 else (76, 54, 100))
    skull(img, 12 + f, 14, c=SOUL, eyes=(30, 20, 40))                               # its sign, glowing
    rect(img, 1, 37, 6, 3, GRAVE[0])
    return finish(img, (20, 18, 26))


@item("u_lv12_armory", U, "黑鐵武器架", "furniture", 2, level=12)
def u_lv12_armory(f):
    img = new(26, 26)
    rect(img, 2, 6, 2, 20, DARKWOOD); rect(img, 22, 6, 2, 20, DARKWOOD); rect(img, 1, 6, 24, 2, DARKWOOD); rect(img, 1, 20, 24, 2, DARKWOOD)
    rect(img, 6, 1, 1, 22, U_IRON[1]); rect(img, 5, 1, 3, 2, U_IRON[2])                 # a spear
    rect(img, 11, 4, 2, 17, U_IRON[2]); rect(img, 9, 15, 6, 1, U_GOLD); rect(img, 11, 16, 2, 4, DARKWOOD)  # a sword
    rect(img, 17, 4, 1, 18, DARKWOOD); disk(img, 19, 6, 3, U_IRON[1], 2); put(img, 21, 6, U_IRON[2])     # an axe
    return finish(img, (20, 18, 26))


@item("u_lv12_gargoyle", U, "石像鬼", "scene", 2, level=12)
def u_lv12_gargoyle(f):
    img = new(24, 32)
    rect(img, 5, 22, 14, 10, GRAVE[1]); rect(img, 5, 22, 3, 10, GRAVE[2]); rect(img, 3, 20, 18, 2, GRAVE[0])
    disk(img, 12, 15, 5, GRAVE[1], 5)                                               # crouched body
    line(img, 7, 12, 1, 4, GRAVE[0]); line(img, 7, 13, 2, 9, GRAVE[0]); rect(img, 1, 4, 2, 6, GRAVE[0])     # wings
    line(img, 17, 12, 23, 4, GRAVE[0]); line(img, 17, 13, 22, 9, GRAVE[0]); rect(img, 21, 4, 2, 6, GRAVE[0])
    disk(img, 12, 8, 3, GRAVE[2]); put(img, 9, 5, GRAVE[1]); put(img, 15, 5, GRAVE[1])  # head and horns
    put(img, 11, 8, BLOOD); put(img, 13, 8, BLOOD)
    rect(img, 11, 10, 3, 1, INK)
    return finish(img, (20, 18, 26))


@item("u_lv12_bloodrose", U, "血玫瑰叢", "flower", 1, frames=2, level=12)
def u_lv12_bloodrose(f):
    img = new(18, 14)
    blob(img, 9, 9, 7, 4, [(30, 50, 40), (44, 70, 54), (60, 90, 66)], R(1201))
    for k, (x, y) in enumerate(((4, 7), (9, 5), (14, 8), (7, 10), (12, 11))):
        disk(img, x, y, 1, BLOOD); put(img, x, y, (200, 50, 70))
    put(img, 9, 7 + f * 2, (200, 50, 70)); put(img, 9, 8 + f * 3, (150, 30, 50, 180))  # a drop falls
    for (x, y) in ((2, 10), (16, 6)):
        put(img, x, y, BONE_SHADE)
    return finish(img, (20, 18, 26))


@item("u_lv12_mausoleum", U, "家族陵墓", "building", 4, level=12)
def u_lv12_mausoleum(f):
    img = new(38, 36)
    rect(img, 2, 32, 34, 4, GRAVE[0]); rect(img, 4, 30, 30, 2, GRAVE[1])
    rect(img, 6, 14, 26, 16, GRAVE[1]); rect(img, 6, 14, 2, 16, GRAVE[2])
    for x in (8, 14, 22, 28):                                                       # columns
        rect(img, x, 14, 2, 16, GRAVE[2]); put(img, x + 1, 14, GRAVE[0])
    tri_roof(img, 19, 3, 16, 10, GRAVE[0], GRAVE[2]); rect(img, 3, 12, 32, 2, GRAVE[2])
    rect(img, 16, 18, 6, 12, (36, 30, 40)); rect(img, 18, 18, 1, 12, (60, 50, 70))   # a bronze door
    rect(img, 17, 18, 4, 12, (70, 90, 80)); rect(img, 19, 18, 1, 12, (50, 66, 60))
    disk(img, 19, 8, 2, VIOLET)                                                     # a round window
    return finish(img, (30, 28, 36))


# ==== level 15 ======================================================================================================
@item("u_lv15_knight", U, "亡靈騎士", "creature", 2, frames=2, fn="lv_ward", blocks=False, level=15)
def u_lv15_knight(f):
    """A dead knight in black plate on guard: it cuts at monsters that come near."""
    img = new(22, 34)
    rect(img, 7, 24, 3, 10, U_IRON[0]); rect(img, 12, 24, 3, 10, U_IRON[0])             # legs
    rect(img, 6, 13, 10, 12, U_IRON[1]); rect(img, 6, 13, 2, 12, U_IRON[2]); rect(img, 6, 22, 10, 2, U_IRON[0])
    disk(img, 11, 8, 4, U_IRON[1]); rect(img, 8, 8, 7, 1, (20, 18, 26))               # helm with a slit
    put(img, 10, 8, SOUL); put(img, 12, 8, SOUL)
    rect(img, 11, 2, 1, 3, BLOOD)                                                   # a plume
    rect(img, 1, 14, 5, 9, (60, 40, 80)); rect(img, 2, 15, 3, 7, VIOLET)             # shield
    sx = 18 if f == 0 else 19                                                       # the sword, raised or lowered
    if f == 0:
        rect(img, sx, 4, 1, 18, U_IRON[2]); rect(img, sx - 1, 20, 3, 1, U_GOLD)
    else:
        line(img, 16, 18, 21, 2, U_IRON[2]); rect(img, 15, 17, 3, 1, U_GOLD)
    return finish(img, (20, 18, 26))


@item("u_lv15_obelisk", U, "符文方尖碑", "scene", 2, frames=2, level=15)
def u_lv15_obelisk(f):
    img = new(16, 40)
    for y in range(4, 36):
        half = 2 + (y - 4) // 10
        rect(img, 8 - half, y, half * 2, 1, OBSIDIAN[1]); put(img, 8 - half, y, OBSIDIAN[2])
    rect(img, 7, 1, 2, 3, OBSIDIAN[1]); put(img, 7, 1, OBSIDIAN[2])
    for k, y in enumerate((10, 16, 22, 28)):                                        # runes light up in turn
        c = SOUL if (k + f) % 2 == 0 else (60, 120, 110)
        put(img, 7, y, c); put(img, 8, y + 1, c); put(img, 7, y + 2, c)
    rect(img, 2, 36, 12, 4, GRAVE[0])
    return finish(img, (20, 18, 26))


@item("u_lv15_cage", U, "吊籠", "furniture", 1, frames=2, level=15)
def u_lv15_cage(f):
    img = new(16, 28)
    rect(img, 2, 2, 2, 26, DARKWOOD); rect(img, 2, 2, 12, 2, DARKWOOD)
    sway = f
    line(img, 11, 4, 11 + sway, 8, U_IRON[1])
    for x in range(8, 16, 2):
        rect(img, x + sway, 9, 1, 11, U_IRON[1])
    rect(img, 7 + sway, 8, 8, 1, U_IRON[2]); rect(img, 7 + sway, 19, 8, 1, U_IRON[2])
    skull(img, 11 + sway, 16)
    return finish(img, (20, 18, 26))


@item("u_lv15_facetree", U, "鬼面樹", "tree", 4, frames=2, level=15)
def u_lv15_facetree(f):
    img = new(34, 44)
    rect(img, 13, 18, 9, 26, (60, 50, 56)); rect(img, 13, 18, 2, 26, (84, 72, 76))
    for (x0, y0, x1, y1) in ((14, 22, 3, 8), (20, 20, 31, 6), (16, 18, 12, 2), (19, 18, 24, 3), (7, 13, 1, 15), (27, 11, 33, 13)):
        line(img, x0, y0, x1, y1, (60, 50, 56)); line(img, x0 + 1, y0, x1 + 1, y1, (60, 50, 56))
    disk(img, 15, 28, 2, (16, 12, 20)); disk(img, 20, 28, 2, (16, 12, 20))          # the face
    put(img, 15, 28, SOUL if f == 0 else (60, 120, 110)); put(img, 20, 28, SOUL if f == 0 else (60, 120, 110))
    for x in range(14, 22):
        put(img, x, 34 + (x % 2) + (1 if f else 0), (16, 12, 20))
    for x in (11, 23):                                                              # roots
        line(img, 17, 41, x, 43, (60, 50, 56))
    return finish(img, (20, 18, 26))


@item("u_lv15_skullpile", U, "頭骨堆", "bone", 1, level=15)
def u_lv15_skullpile(f):
    img = new(18, 14)
    for (x, y) in ((4, 10), (9, 10), (14, 10), (6, 6), (12, 6), (9, 2)):
        skull(img, x, y, c=BONE if (x + y) % 3 else BONE_SHADE)
    return finish(img, (20, 18, 26))


# ==== level 18 ======================================================================================================
@item("u_lv18_soulwell", U, "靈魂之泉", "scene", 4, frames=2, fn="lv_birth", level=18)
def u_lv18_soulwell(f):
    """A ring of standing stones round a pool of souls: new ones come sooner."""
    img = new(40, 30)
    disk(img, 20, 22, 18, GRAVE[0], 7); disk(img, 20, 22, 15, (40, 90, 90), 5); disk(img, 20, 22, 11, (70, 170, 160), 3)
    disk(img, 20, 22, 6, SOUL, 1)
    for (x, h) in ((4, 12), (12, 16), (28, 16), (36, 12)):                          # standing stones
        rect(img, x - 1, 22 - h, 3, h, GRAVE[1]); put(img, x - 1, 22 - h, GRAVE[2]); put(img, x, 22 - h + 3, SOUL)
    for k in range(4):                                                              # souls rising
        x = 14 + k * 4
        y = 14 - ((k + f) % 2) * 3 - k % 2 * 2
        disk(img, x, y, 1, SOUL); put(img, x, y + 2, (130, 250, 220, 150))
    return finish(img, (20, 18, 26))


@item("u_lv18_spinearch", U, "脊骨拱門", "bone", 4, level=18)
def u_lv18_spinearch(f):
    img = new(40, 36)
    for a in range(180, 361, 9):                                                    # vertebrae in an arch
        x = round(20 + 17 * math.cos(math.radians(a))); y = round(34 + 30 * math.sin(math.radians(a)))
        disk(img, x, y, 2, BONE); put(img, x, y - 1, BONE_SHADE)
        put(img, x + 2, y, BONE_SHADE)
    for a in range(200, 341, 20):                                                   # ribs hanging in
        x = round(20 + 15 * math.cos(math.radians(a))); y = round(34 + 27 * math.sin(math.radians(a)))
        line(img, x, y, x + (2 if x < 20 else -2), y + 5, BONE_SHADE)
    skull(img, 20, 3, c=BONE)
    put(img, 19, 3, SOUL); put(img, 21, 3, SOUL)
    return finish(img, (20, 18, 26))


@item("u_lv18_wraith", U, "遊蕩怨靈", "creature", 1, frames=2, level=18)
def u_lv18_wraith(f):
    img = new(16, 22)
    c = (180, 220, 230, 190)
    disk(img, 8, 6 - f, 4, c)
    for y in range(9 - f, 20):                                                      # a tattered robe
        half = 3 + (y - 9) // 4
        rect(img, 8 - half, y, half * 2 + 1, 1, c)
    for x in range(3, 14, 3):
        put(img, x + f, 20, (0, 0, 0, 0)); put(img, x + f, 19, (0, 0, 0, 0))
    rect(img, 6, 5 - f, 1, 2, (20, 18, 26)); rect(img, 9, 5 - f, 1, 2, (20, 18, 26))
    rect(img, 7, 8 - f, 2, 2, (20, 18, 26))                                         # a wail
    line(img, 4, 11 - f, 1, 8 + f, c); line(img, 12, 11 - f, 15, 8 + f, c)
    return finish(img, (40, 60, 70))


@item("u_lv18_altar", U, "黑曜祭壇", "building", 2, frames=2, level=18)
def u_lv18_altar(f):
    img = new(28, 24)
    rect(img, 2, 14, 24, 10, OBSIDIAN[1]); rect(img, 2, 14, 24, 2, OBSIDIAN[2]); rect(img, 0, 22, 28, 2, OBSIDIAN[0])
    rect(img, 11, 17, 6, 4, OBSIDIAN[0]); put(img, 13, 18, SOUL); put(img, 14, 19, SOUL)
    skull(img, 14, 10)
    for k, x in enumerate((4, 24)):
        candle(img, x, 9, 5, f, k)
    for k in range(3):
        put(img, 11 + k * 3, 5 - (k + f) % 2 * 2, (180, 140, 220))
    return finish(img, (20, 18, 26))


@item("u_lv18_nightshade", U, "巨顛茄", "plant", 2, level=18)
def u_lv18_nightshade(f):
    img = new(24, 32)
    rect(img, 11, 10, 2, 22, (50, 80, 60))
    for (y, d) in ((12, -1), (17, 1), (22, -1), (27, 1)):                           # leaves
        disk(img, 12 + d * 5, y, 4, (50, 90, 64), 2); put(img, 12 + d * 3, y - 1, (70, 120, 80))
    for (x, y) in ((5, 15), (19, 20), (6, 25), (17, 10)):                           # hanging bell flowers
        disk(img, x, y, 2, VIOLET); put(img, x, y + 2, (70, 50, 100)); put(img, x - 1, y - 1, (150, 120, 190))
    disk(img, 12, 6, 3, (30, 24, 34)); put(img, 11, 5, (90, 80, 110))               # a poisonous berry on top
    return finish(img, (20, 18, 26))


# ==== level 21 ======================================================================================================
@item("u_lv21_hands", U, "抓腳亡手", "scene", 2, frames=2, fn="lv_hold", blocks=False, level=21)
def u_lv21_hands(f):
    """A patch of churned earth where bony hands grab at feet: monsters stepping in are held a moment."""
    img = new(30, 16)
    disk(img, 15, 12, 14, (70, 56, 46), 4); disk(img, 15, 12, 11, (90, 72, 56), 2)
    for k, (x, h) in enumerate(((5, 7), (12, 9), (19, 8), (25, 6))):
        up = h - (2 if (k + f) % 2 else 0)
        rect(img, x, 13 - up, 1, up, BONE)                                          # the arm
        for d in (-2, 0, 2):                                                        # fingers, opening and closing
            line(img, x, 13 - up, x + d * (1 if (k + f) % 2 else 0) + (d // 2), 10 - up, BONE)
        put(img, x + 1, 13 - up + 1, BONE_SHADE)
    rect(img, 9, 14, 2, 1, U_IRON[1]); rect(img, 21, 13, 2, 1, U_IRON[1])               # bits of chain
    return finish(img, (20, 18, 26))


@item("u_lv21_lichspire", U, "巫妖尖塔", "building", 4, frames=2, level=21)
def u_lv21_lichspire(f):
    img = new(30, 56)
    for y in range(10, 56):                                                         # a tower that narrows
        half = 5 + (y - 10) // 6
        rect(img, 15 - half, y, half * 2, 1, OBSIDIAN[1] if y % 5 else OBSIDIAN[0]); put(img, 15 - half, y, OBSIDIAN[2])
    tri_roof(img, 15, 0, 7, 12, (60, 40, 90), (100, 70, 140))
    rect(img, 12, 46, 6, 10, (16, 12, 20)); disk(img, 15, 46, 3, (16, 12, 20))
    for (x, y) in ((15, 18), (12, 30), (18, 30)):
        rect(img, x - 1, y, 2, 3, SOUL if (x + y + f) % 2 else (60, 120, 110))
    disk(img, 15, 0, 1, SOUL)
    for k in range(4):                                                              # an orbiting soul
        a = math.radians(k * 90 + f * 45)
        put(img, round(15 + 9 * math.cos(a)), round(8 + 3 * math.sin(a)), (200, 255, 244))
    return finish(img, (20, 18, 26))


@item("u_lv21_web", U, "巨蛛網", "scene", 2, level=21)
def u_lv21_web(f):
    img = new(28, 30)
    rect(img, 1, 0, 2, 30, DARKWOOD); rect(img, 25, 0, 2, 30, DARKWOOD)
    web = (210, 210, 220)
    cx, cy = 14, 13
    for (x, y) in ((3, 1), (25, 1), (3, 25), (25, 25), (14, 0), (3, 13), (25, 13)):
        line(img, cx, cy, x, y, web)
    for r in (4, 8, 11):
        ring(img, cx, cy, r, web, r - 1)
    disk(img, 18, 18, 2, (30, 24, 30)); disk(img, 18, 15, 1, (30, 24, 30)); put(img, 18, 15, BLOOD)
    for (dx, dy) in ((-3, -1), (3, -1), (-3, 1), (3, 1), (-3, 3), (3, 3)):
        put(img, 18 + dx, 17 + dy, (30, 24, 30))
    return finish(img, (20, 18, 26))


@item("u_lv21_soulcrystal", U, "魂晶簇", "plant", 1, frames=2, level=21)
def u_lv21_soulcrystal(f):
    img = new(18, 18)
    for (x, h, w) in ((5, 9, 2), (9, 14, 3), (13, 8, 2)):
        for y in range(18 - h, 17):
            ww = min(w, (y - (18 - h)) // 2 + 1)
            rect(img, x - ww + 1, y, ww * 2 - 1, 1, (90, 200, 190) if y % 3 else (130, 240, 220))
        put(img, x, 18 - h, (220, 255, 244))
    put(img, 8, 6 + f, (220, 255, 244)); put(img, 3 + f * 12, 10, (220, 255, 244))  # a glint
    rect(img, 2, 16, 14, 2, GRAVE[0])
    return finish(img, (20, 18, 26))


@item("u_lv21_chainpillar", U, "鎖鏈石柱", "bone", 1, level=21)
def u_lv21_chainpillar(f):
    img = new(16, 26)
    rect(img, 5, 3, 6, 21, GRAVE[1]); rect(img, 5, 3, 2, 21, GRAVE[2]); rect(img, 4, 1, 8, 2, GRAVE[0]); rect(img, 3, 23, 10, 3, GRAVE[0])
    for k in range(5):                                                              # chains wound round it
        y = 6 + k * 3
        line(img, 3, y, 12, y + 2, U_IRON[1]); put(img, 7, y + 1, U_IRON[2])
    rect(img, 12, 14, 1, 7, U_IRON[1]); disk(img, 12, 22, 1, U_IRON[2])                 # a loose end with a shackle
    return finish(img, (20, 18, 26))


# ==== level 24 ======================================================================================================
@item("u_lv24_necrohall", U, "死靈王殿", "building", 4, frames=2, fn="lv_crown", level=24)
def u_lv24_necrohall(f):
    """The undead's crown: a black palace with three spires and a soul fire on high. It fights and mends the camp."""
    img = new(46, 56)
    rect(img, 2, 52, 42, 4, OBSIDIAN[0]); rect(img, 4, 50, 38, 2, OBSIDIAN[1])
    rect(img, 6, 26, 34, 24, OBSIDIAN[1]); rect(img, 6, 26, 2, 24, OBSIDIAN[2])
    for (cx, top, half) in ((8, 8, 4), (38, 8, 4), (23, 0, 6)):                     # spires
        tri_roof(img, cx, top, half, 10, (60, 40, 90), (100, 70, 140))
        rect(img, cx - half + 1, top + 10, half * 2 - 1, 26 - top - 8, OBSIDIAN[1]); put(img, cx - half + 1, top + 10, OBSIDIAN[2])
        rect(img, cx - 1, top + 14, 2, 3, SOUL if (cx + f) % 2 else (60, 120, 110))
    for x in range(6, 41, 4):                                                       # battlements
        rect(img, x, 24, 2, 2, OBSIDIAN[1])
    rect(img, 18, 36, 10, 14, (16, 12, 20)); disk(img, 23, 36, 5, (16, 12, 20))      # the great door
    skull(img, 23, 31, c=U_GOLD, eyes=SOUL)                                           # a gold skull crest
    for (x, y) in ((11, 32), (35, 32)):
        rect(img, x - 1, y, 3, 5, VIOLET); put(img, x, y + 1, (180, 140, 220))
    disk(img, 23, 0 + f, 1, SOUL); put(img, 23, 2 - f, (200, 255, 244))             # the flame on high
    for k in range(4):
        put(img, 14 + k * 6, 46 - (k + f) % 2, SOUL)
    return finish(img, (20, 18, 26))


@item("u_lv24_bonedragon", U, "骨龍", "creature", 4, frames=2, level=24)
def u_lv24_bonedragon(f):
    img = new(48, 38)
    lift = -3 if f else 0
    spine = lambda x: 22 - round(3 * math.sin((x - 10) / 5))                            # noqa: E731
    for k, tip in enumerate((4, 7, 12)):                                                # a bat-like wing of bone, torn membrane
        tx = 12 + k * 8
        line(img, 23, 17, tx, tip + lift, BONE)
        for y in range(tip + lift + 2, 18):
            put(img, tx + (y - tip - lift) // 3, y, (90, 70, 110))
            put(img, tx + 1 + (y - tip - lift) // 3, y, (110, 86, 130))
    for x in range(10, 36):                                                             # the spine and ribs
        y = spine(x)
        rect(img, x, y, 1, 2, BONE)
        if x % 3 == 0 and 14 <= x <= 32:
            line(img, x, y + 2, x - 1, y + 7, BONE_SHADE)
    for x in (14, 30):                                                                  # legs
        line(img, x, spine(x) + 2, x - 2, 31, BONE); line(img, x - 2, 31, x, 36, BONE); rect(img, x - 1, 37, 4, 1, BONE)
    for x in range(1, 11):                                                              # the tail swishes
        put(img, x, spine(10) + round(2 * math.sin(x / 2 + f * 2)), BONE)
    line(img, 35, spine(35), 40, 13, BONE); line(img, 36, spine(36), 41, 13, BONE)      # neck
    rect(img, 39, 9, 7, 4, BONE); rect(img, 40, 9, 2, 1, BONE_SHADE); put(img, 41, 10, SOUL)  # skull
    rect(img, 43, 13, 4, 1 + f, BONE_SHADE)                                             # its jaw drops
    put(img, 38, 7, BONE_SHADE); put(img, 39, 8, BONE_SHADE)                            # a horn
    if f:
        put(img, 47, 13, SOUL); put(img, 46, 15, (200, 255, 244))                       # a breath of soul
    return finish(img, (20, 18, 26))


@item("u_lv24_gate", U, "亡者之門", "building", 4, frames=2, level=24)
def u_lv24_gate(f):
    img = new(42, 46)
    rect(img, 2, 8, 9, 38, GRAVE[1]); rect(img, 31, 8, 9, 38, GRAVE[1]); rect(img, 2, 8, 2, 38, GRAVE[2]); rect(img, 31, 8, 2, 38, GRAVE[2])
    rect(img, 0, 4, 42, 5, GRAVE[0]); rect(img, 0, 4, 42, 1, GRAVE[2])
    for x in (6, 36):
        skull(img, x, 2)
    for x in range(11, 31):                                                         # the swirling portal
        for y in range(10, 46):
            d = abs(x - 20.5) + abs(y - 28) / 2
            put(img, x, y, (30, 90, 90) if (int(d) + f) % 3 == 0 else (16, 30, 40) if (int(d) + f) % 3 == 1 else (60, 160, 150))
    for k in range(3):
        put(img, 16 + k * 4, 24 + (k + f) % 2 * 4, (220, 255, 244))
    for y in (18, 30):
        rect(img, 4, y, 5, 1, U_IRON[1]); rect(img, 33, y, 5, 1, U_IRON[1])
    return finish(img, (20, 18, 26))


@item("u_lv24_phylactery", U, "命匣", "furniture", 1, frames=2, level=24)
def u_lv24_phylactery(f):
    img = new(14, 22)
    rect(img, 3, 18, 8, 4, OBSIDIAN[1]); rect(img, 5, 14, 4, 4, OBSIDIAN[0])        # a plinth
    rect(img, 3, 6, 8, 8, U_GOLD); rect(img, 4, 7, 6, 6, (160, 120, 50))
    disk(img, 7, 10, 2, SOUL if f == 0 else (200, 255, 244)); put(img, 7, 10, (220, 255, 244))
    rect(img, 6, 3, 2, 3, U_GOLD); disk(img, 7, 2, 1, VIOLET)
    put(img, 2 + f * 10, 4, SOUL)
    return finish(img, (20, 18, 26))


@item("u_lv24_eternalfire", U, "永恆冥火", "scene", 2, frames=2, level=24)
def u_lv24_eternalfire(f):
    img = new(24, 32)
    rect(img, 4, 24, 16, 8, OBSIDIAN[1]); rect(img, 2, 22, 20, 3, OBSIDIAN[2]); rect(img, 6, 28, 12, 1, OBSIDIAN[0])
    skull(img, 12, 27, c=BONE_SHADE, eyes=SOUL)
    for y in range(4, 22):                                                          # a tall cold flame
        half = max(0, (y - 4) * 7 // 18 - (1 if (y + f) % 4 == 0 else 0))
        sway = (1 if (y // 3 + f) % 2 else 0) if y < 14 else 0
        rect(img, 12 - half + sway, y, half * 2 + 1, 1, (60, 160, 200))
        if half > 1:
            rect(img, 12 - half + 2 + sway, y, max(1, half * 2 - 3), 1, SOUL)
        if half > 3:
            rect(img, 12 - 1 + sway, y, 3, 1, (220, 255, 244))
    put(img, 12 + f, 2, SOUL)
    return finish(img, (20, 18, 26))
