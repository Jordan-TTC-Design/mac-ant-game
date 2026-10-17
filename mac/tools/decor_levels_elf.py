# The elves' decorations a race level unlocks (DESKTOP.md §5.5): five every three levels, from 3 to 24, the later ones grander.
# Run inside make_decor.py's namespace (its helpers and colours), so these land in the same catalogue. One a tier does something
# (fn "lv_…": Decor.swift), the rest are for looks.
E_GOLD = (236, 200, 90)
E_GOLD_LIGHT = (252, 232, 150)
LILAC = [(130, 100, 170), (170, 136, 210), (206, 180, 236)]
GLOW = (190, 250, 220)
STAR = (255, 250, 200)
CRYSTAL = [(110, 170, 220), (160, 214, 246), (220, 244, 255)]


# ---- level 3 -------------------------------------------------------------------------------------------------------
@item("e_lv3_dewbed", E, "露珠葉床", "furniture", 1, fn="lv_rest", level=3)
def e_lv3_dewbed(f):
    img = new(20, 12)
    for x in range(1, 19):                                                  # a curled leaf, a bed for one
        h = 2 + int(3 * math.sin(math.pi * (x - 1) / 17))
        rect(img, x, 9 - h, 1, h + 1, ELEAF[1] if x % 4 else ELEAF[0])
        put(img, x, 9 - h, ELEAF[2])
    line(img, 2, 8, 17, 7, ELEAF[0])
    rect(img, 3, 4, 5, 3, (240, 236, 226)); rect(img, 3, 4, 5, 1, (252, 250, 244))  # a pillow of down
    for (x, y) in ((11, 5), (15, 6)):                                       # dew
        put(img, x, y, (200, 236, 255)); put(img, x, y - 1, (250, 255, 255))
    rect(img, 3, 10, 2, 2, BARK); rect(img, 15, 10, 2, 2, BARK)
    return finish(img, (30, 60, 40))


@item("e_lv3_mosslantern", E, "苔燈", "sign", 1, frames=2, level=3)
def e_lv3_mosslantern(f):
    img = new(12, 22)
    rect(img, 5, 8, 2, 14, BARK); rect(img, 5, 8, 1, 14, shade(BARK, 1.25))
    rect(img, 3, 20, 6, 2, (90, 140, 80))                                   # moss at its foot
    rect(img, 2, 2, 8, 2, (80, 130, 70)); put(img, 1, 3, (80, 130, 70)); put(img, 10, 3, (80, 130, 70))
    rect(img, 3, 4, 6, 4, GLOW if f == 0 else (220, 255, 236))
    put(img, 4, 5, (255, 255, 255))
    rect(img, 4, 0, 4, 2, (100, 160, 90))
    return finish(img, (30, 50, 40))


@item("e_lv3_acornstool", E, "橡實凳", "furniture", 1, level=3)
def e_lv3_acornstool(f):
    img = new(14, 14)
    disk(img, 7, 4, 6, (120, 84, 50), 3); rect(img, 1, 4, 13, 2, (100, 70, 40))   # the cap is the seat
    for x in range(2, 13, 2):
        put(img, x, 2 + x % 2, (150, 110, 70))
    disk(img, 7, 9, 4, (190, 140, 80), 4); put(img, 5, 8, (220, 170, 110)); put(img, 5, 9, (220, 170, 110))
    put(img, 7, 0, (90, 60, 30))
    return finish(img, (50, 30, 20))


@item("e_lv3_fern", E, "捲捲蕨", "flower", 1, level=3)
def e_lv3_fern(f):
    img = new(16, 14)
    for (x0, lean, n) in ((3, -1, 9), (8, 0, 12), (12, 1, 9)):
        for k in range(n):
            x = x0 + lean * k // 3; y = 13 - k
            put(img, x, y, ELEAF[0])
            if k % 2 and k < n - 2:
                put(img, x - 1, y, ELEAF[1]); put(img, x + 1, y, ELEAF[2])
        ring(img, x0 + lean * n // 3 + lean, 13 - n, 1, ELEAF[1])           # the curled tip
    return finish(img, (30, 60, 40))


@item("e_lv3_fairyring", E, "精靈蘑菇圈", "scene", 2, frames=2, blocks=False, level=3)
def e_lv3_fairyring(f):
    img = new(30, 14)
    for k in range(9):                                                      # little mushrooms round an oval
        a = math.radians(k * 40 + 10)
        x = round(15 + 12 * math.cos(a)); y = round(8 + 4 * math.sin(a))
        rect(img, x, y, 1, 2, (240, 236, 220))
        rect(img, x - 1, y - 1, 3, 1, (220, 90, 90) if k % 3 else (240, 190, 90)); put(img, x, y - 2, (220, 90, 90) if k % 3 else (240, 190, 90))
    for k in range(3):                                                      # sparks dancing in the middle
        put(img, 10 + k * 5, 6 + (k + f) % 2 * 2, STAR if (k + f) % 2 else GLOW)
    return finish(img, (50, 40, 40))


# ---- level 6 -------------------------------------------------------------------------------------------------------
@item("e_lv6_silverforge", E, "銀葉鍛台", "furniture", 2, frames=2, fn="lv_whet", level=6)
def e_lv6_silverforge(f):
    img = new(24, 18)
    rect(img, 3, 12, 18, 6, STONE[0]); rect(img, 3, 12, 18, 2, STONE[1])    # a stone base
    rect(img, 6, 6, 12, 4, SILVER); rect(img, 6, 6, 12, 1, (240, 244, 250)); rect(img, 4, 7, 2, 2, SILVER)  # the anvil
    rect(img, 9, 10, 6, 2, (170, 178, 188))
    for (x, y) in ((8, 4), (12, 3), (16, 4)):                              # silver leaves cooling on it
        put(img, x, y, (226, 234, 242)); put(img, x + 1, y + 1, SILVER)
    line(img, 18, 2, 22, 6, BARK); rect(img, 16, 1, 3, 2, (150, 156, 166))   # a hammer
    if f:
        put(img, 11, 2, E_GOLD_LIGHT); put(img, 14, 1, STAR); put(img, 9, 1, E_GOLD)
    return finish(img, (40, 48, 60))


@item("e_lv6_birdbath", E, "石雕鳥浴", "scene", 1, frames=2, level=6)
def e_lv6_birdbath(f):
    img = new(16, 20)
    rect(img, 6, 9, 4, 9, STONE[1]); rect(img, 6, 9, 1, 9, STONE[2]); rect(img, 4, 18, 8, 2, STONE[0])
    disk(img, 8, 8, 7, STONE[1], 2); rect(img, 2, 7, 13, 2, (110, 170, 220))
    put(img, 4, 7, (220, 240, 255))
    bird(5 + f * 5, 4, body=(110, 150, 210), beak=(240, 180, 60))(img, f)  # a bluebird bathing
    return finish(img, (40, 50, 60))


@item("e_lv6_reedgate", E, "蘆葦門", "building", 2, blocks=False, level=6)
def e_lv6_reedgate(f):
    img = new(26, 30)
    for x in (2, 4, 20, 22):                                                # two bundles of reeds
        rect(img, x, 6, 2, 24, (190, 170, 110)); rect(img, x, 6, 1, 24, (214, 196, 140))
        rect(img, x, 3, 2, 3, (130, 100, 60))
    rect(img, 2, 12, 4, 1, (120, 140, 70)); rect(img, 20, 12, 4, 1, (120, 140, 70))
    for x in range(5, 21):                                                  # a woven lintel, bowed
        y = 6 - int(3 * math.sin(math.pi * (x - 5) / 15))
        rect(img, x, y, 1, 2, (170, 150, 96) if x % 2 else (200, 180, 120))
    for x in (9, 13, 17):
        put(img, x, 7, PETAL); put(img, x, 8, (120, 170, 90))
    return finish(img, (60, 50, 30))


@item("e_lv6_topiary", E, "樹籬小鹿", "tree", 2, level=6)
def e_lv6_topiary(f):
    img = new(26, 28)
    rnd = R(3006)
    blob(img, 12, 15, 8, 5, ELEAF, rnd)                                     # the body
    for x in (6, 10, 15, 18):                                               # legs
        rect(img, x, 19, 2, 6, ELEAF[0]); put(img, x, 19, ELEAF[1])
    blob(img, 20, 8, 3, 4, ELEAF, rnd); blob(img, 22, 4, 3, 2, ELEAF, rnd)  # neck and head
    line(img, 21, 2, 19, 0, BARK); line(img, 23, 2, 25, 0, BARK)            # twig antlers
    put(img, 4, 12, ELEAF[2])
    rect(img, 4, 25, 18, 3, (150, 110, 80)); rect(img, 4, 25, 18, 1, (180, 140, 100))  # its tub
    return finish(img, (30, 60, 40))


@item("e_lv6_stargazer", E, "觀星躺椅", "furniture", 2, level=6)
def e_lv6_stargazer(f):
    img = new(26, 16)
    for x in range(2, 24):                                                  # a long woven chair leaning back
        y = 8 if x > 9 else 8 - (10 - x)
        rect(img, x, y, 1, 3, (200, 176, 124) if x % 2 else (176, 150, 100))
    rect(img, 3, 11, 2, 5, BARK); rect(img, 21, 11, 2, 5, BARK); rect(img, 12, 11, 2, 4, BARK)
    rect(img, 12, 6, 9, 2, (150, 170, 220)); rect(img, 12, 6, 9, 1, (180, 196, 236))   # a blue blanket
    put(img, 5, 0, STAR); put(img, 19, 1, STAR); put(img, 24, 3, STAR)
    return finish(img)


# ---- level 9 -------------------------------------------------------------------------------------------------------
@item("e_lv9_budcradle", E, "花苞搖籃", "furniture", 2, frames=2, fn="lv_nursery", level=9)
def e_lv9_budcradle(f):
    """A flower bud hung from a bent stalk, a little one asleep in it, rocking."""
    img = new(26, 30)
    stalk = (70, 130, 70)
    rect(img, 4, 6, 2, 24, stalk); rect(img, 4, 6, 1, 24, (100, 160, 90)); rect(img, 1, 28, 8, 2, stalk)
    for x in range(5, 17):                                                  # the stalk bends over
        put(img, x, 6 - int(4 * math.sin(math.pi * (x - 5) / 22)), stalk)
    blob(img, 8, 22, 3, 2, ELEAF, R(3009)); blob(img, 2, 16, 2, 2, ELEAF, R(3109))
    sway = 1 if f else -1
    line(img, 16, 4, 16 + sway, 9, (200, 190, 150))
    for y in range(10, 24):                                                 # the bud, open at the top
        half = int(8 * math.sin(math.pi * (y - 8) / 18))
        rect(img, 16 + sway - half, y, 2 * half + 1, 1, PETAL if y % 3 else (230, 160, 186))
    for dx in (-7, -3, 1, 5):                                               # petal tips
        put(img, 16 + sway + dx, 10, (252, 226, 236)); put(img, 16 + sway + dx + 1, 9, PETAL)
    rect(img, 11 + sway, 11, 11, 3, (252, 230, 240))
    disk(img, 16 + sway, 11, 2, (240, 200, 160))                            # a sleeping little one
    put(img, 15 + sway, 11, (90, 60, 50)); put(img, 17 + sway, 11, (90, 60, 50))
    rect(img, 15 + sway, 22, 3, 2, (90, 150, 80))                           # the green cup underneath
    put(img, 21 + f, 3, (255, 255, 255)); put(img, 23 + f, 1, (255, 255, 255))   # z z
    return finish(img, (90, 50, 70))


@item("e_lv9_owlhollow", E, "貓頭鷹樹洞", "creature", 2, frames=2, level=9)
def e_lv9_owlhollow(f):
    img = new(20, 32)
    rect(img, 5, 6, 10, 26, BARK); rect(img, 5, 6, 3, 26, shade(BARK, 1.2)); rect(img, 3, 30, 14, 2, BARK)
    blob(img, 10, 4, 9, 4, ELEAF, R(3009))
    disk(img, 10, 15, 3, (40, 26, 18), 4)                                   # the hollow
    disk(img, 10, 16, 2, (170, 140, 100), 2)                                # the owl
    if f:
        rect(img, 9, 15, 1, 1, (60, 40, 20)); rect(img, 11, 15, 1, 1, (60, 40, 20))   # blinking
    else:
        put(img, 9, 15, (250, 220, 90)); put(img, 11, 15, (250, 220, 90))
    put(img, 10, 17, (230, 170, 60)); put(img, 8, 13, (150, 120, 84)); put(img, 12, 13, (150, 120, 84))
    return finish(img, (30, 40, 30))


@item("e_lv9_mapletable", E, "楓葉長桌", "furniture", 2, level=9)
def e_lv9_mapletable(f):
    img = new(28, 14)
    rect(img, 2, 4, 24, 3, (200, 110, 60)); rect(img, 2, 4, 24, 1, (230, 150, 80))   # a top of pressed maple
    for x in range(4, 25, 5):
        put(img, x, 5, (240, 180, 90))
    rect(img, 4, 7, 2, 7, BARK); rect(img, 22, 7, 2, 7, BARK)
    rect(img, 7, 1, 3, 3, (240, 240, 240)); rect(img, 14, 2, 4, 2, (200, 110, 60)); rect(img, 20, 1, 2, 3, (190, 220, 240))
    put(img, 15, 1, (230, 60, 60)); put(img, 16, 1, (230, 200, 70))         # fruit in a bowl
    return finish(img)


@item("e_lv9_glasstulips", E, "水晶鬱金香", "flower", 1, frames=2, level=9)
def e_lv9_glasstulips(f):
    img = new(16, 16)
    for (x, h, c) in ((3, 9, CRYSTAL), (8, 12, LILAC), (12, 8, CRYSTAL)):
        rect(img, x, 16 - h + 3, 1, h - 3, (80, 150, 90))
        top = 16 - h
        rect(img, x - 1, top, 3, 3, c[1]); put(img, x - 1, top - 1, c[1]); put(img, x + 1, top - 1, c[1])
        put(img, x - 1, top, c[2] if f == 0 else c[1]); put(img, x, top + 1, c[2] if f else c[0])
    rect(img, 1, 14, 14, 2, (90, 140, 80))
    return finish(img, (40, 50, 70))


@item("e_lv9_petalcottage", E, "花頂小屋", "building", 4, level=9)
def e_lv9_petalcottage(f):
    img = hut(30, 16, (240, 232, 214), PETAL, roof_h=12, roof_style="round", chimney=False)
    for (x, y) in ((8, 9), (14, 6), (22, 8), (18, 11), (11, 13)):          # petals on the roof
        put(img, x, y, (252, 226, 236)); put(img, x + 1, y, (230, 150, 180))
    for x in (4, 30):                                                       # pots by the door
        rect(img, x - 1, 32, 3, 2, (190, 110, 80)); put(img, x, 31, (240, 200, 60))
    rect(img, 15, 20, 4, 3, (250, 220, 120))
    return finish(img, (90, 60, 70))


# ---- level 12 ------------------------------------------------------------------------------------------------------
@item("e_lv12_bowrack", E, "銀弓架", "furniture", 2, fn="lv_might", level=12)
def e_lv12_bowrack(f):
    img = new(24, 26)
    rect(img, 2, 2, 2, 24, BARK); rect(img, 20, 2, 2, 24, BARK); rect(img, 1, 1, 22, 2, BARK); rect(img, 1, 23, 22, 2, shade(BARK, 0.85))
    for (x, c) in ((7, SILVER), (12, E_GOLD), (17, SILVER)):                   # three bows hung up
        for y in range(4, 22):
            put(img, x - int(3 * math.sin(math.pi * (y - 4) / 17)), y, c)
        line(img, x, 4, x, 21, (240, 240, 230))
    for y in (8, 14, 20):                                                   # and a quiver of arrows
        put(img, 21, y, (240, 240, 240))
    return finish(img, (40, 40, 40))


@item("e_lv12_banner", E, "精靈戰旗", "sign", 2, frames=2, level=12)
def e_lv12_banner(f):
    img = new(20, 36)
    rect(img, 4, 2, 2, 34, SILVER); rect(img, 4, 2, 1, 34, (240, 244, 250)); disk(img, 5, 1, 1, E_GOLD)
    for y in range(4, 24):                                                  # a long green banner rippling
        w = 13 - (y - 4) // 4
        off = int(1.5 * math.sin(y / 3 + f * 2))
        rect(img, 6, y, max(2, w + off), 1, (60, 130, 80) if y % 5 else (50, 110, 70))
    for (x, y) in ((10, 9), (9, 11), (11, 11), (10, 13)):                    # a silver leaf on it
        put(img, x, y, SILVER)
    rect(img, 2, 34, 6, 2, STONE[1])
    return finish(img, (30, 50, 40))


@item("e_lv12_rainbowbridge", E, "彩虹小橋", "scene", 4, frames=2, blocks=False, level=12)
def e_lv12_rainbowbridge(f):
    img = new(40, 22)
    disk(img, 20, 18, 19, (90, 150, 200), 3); disk(img, 20, 18, 16, (110, 170, 220), 2)   # the stream under it
    cols = [(230, 90, 90), (240, 170, 70), (240, 230, 90), (110, 200, 110), (100, 150, 230), (160, 110, 210)]
    for k, c in enumerate(cols):                                            # the bridge itself, a rainbow
        for x in range(3, 37):
            y = 16 - int(11 * math.sin(math.pi * (x - 3) / 33)) + k
            put(img, x, y, c if (x + f) % 7 else shade(c, 1.3))
    put(img, 20 + f * 4, 18, (240, 250, 255)); put(img, 10 - f * 2, 19, (240, 250, 255))
    return finish(img, (50, 50, 70))


@item("e_lv12_wisteria", E, "紫藤樹", "tree", 4, frames=2, level=12)
def e_lv12_wisteria(f):
    img = new(36, 44)
    rect(img, 16, 18, 4, 26, BARK); rect(img, 16, 18, 1, 26, shade(BARK, 1.25))
    line(img, 17, 22, 9, 15, BARK); line(img, 19, 20, 27, 14, BARK)
    blob(img, 18, 10, 16, 8, ELEAF, R(3012))
    rnd = R(3112)
    for x in range(3, 34, 3):                                               # hanging chains of flowers
        n = 6 + rnd.randrange(10)
        for k in range(n):
            put(img, x + (f if k > 3 and k % 2 else 0), 13 + k, LILAC[(k + x) % 3])
    return finish(img, (40, 40, 50))


@item("e_lv12_foxden", E, "白狐窩", "creature", 1, frames=2, level=12)
def e_lv12_foxden(f):
    img = new(20, 14)
    blob(img, 10, 9, 9, 5, [(90, 76, 60), (120, 100, 78), (150, 128, 100)], R(3212))   # a mound
    disk(img, 10, 10, 4, (40, 30, 24), 3)
    fox = (246, 246, 250)
    rect(img, 7, 9, 6, 3, fox); rect(img, 12 + f, 6, 3, 3, fox)             # a white fox peeping out
    put(img, 12 + f, 5, fox); put(img, 14 + f, 5, fox); put(img, 13 + f, 7, (40, 40, 60))
    put(img, 6, 8 - f, fox); put(img, 5, 7 - f, (220, 220, 230))            # its tail flicks
    return finish(img, (40, 30, 24))


# ---- level 15 ------------------------------------------------------------------------------------------------------
@item("e_lv15_whitestag", E, "白鹿守衛", "creature", 2, frames=2, fn="lv_ward", blocks=False, level=15)
def e_lv15_whitestag(f):
    img = new(26, 30)
    white, light = (236, 238, 244), (252, 252, 255)
    rect(img, 5, 14, 14, 6, white); rect(img, 5, 14, 14, 1, light)         # the body
    for (x, lift) in ((6, f), (9, 0), (15, 0), (18, f)):                    # legs, one pair stamping
        rect(img, x, 20, 1, 8 - lift, white); put(img, x, 27 - lift, (120, 110, 100))
    rect(img, 17, 8, 3, 7, white); rect(img, 18, 5, 5, 4, white); put(img, 23, 7, (60, 60, 70))   # neck and head
    put(img, 20, 6, (70, 140, 230))                                         # a blue eye
    for (x0, d) in ((19, -1), (22, 1)):                                     # silver antlers
        line(img, x0, 4, x0 + 2 * d, 0, SILVER); put(img, x0 + d, 2, SILVER); put(img, x0 + 3 * d, 1, SILVER)
    put(img, 4, 14 - f, light)
    for (x, y) in ((2, 10), (12, 8), (24, 13)):                             # a glow round it
        put(img, x, y - f, GLOW)
    return finish(img, (50, 60, 80))


@item("e_lv15_moonwell", E, "月之井", "scene", 2, frames=2, level=15)
def e_lv15_moonwell(f):
    img = new(22, 26)
    for x in (3, 17):
        rect(img, x, 6, 2, 12, SILVER)
    for y in range(6):                                                      # a crescent roof
        half = 3 + y * 7 // 5
        rect(img, 11 - half, y + 2, 2 * half + 1, 1, (90, 110, 160) if y % 2 else (110, 130, 180))
    disk(img, 11, 0, 1, MOON)
    rect(img, 2, 17, 18, 8, STONE[1]); rect(img, 2, 17, 18, 2, STONE[2]); rect(img, 2, 24, 18, 1, STONE[0])
    rect(img, 4, 18, 14, 1, MOON if f == 0 else (180, 210, 255))            # its water shines
    for k in range(2):
        put(img, 7 + k * 8, 13 - (k + f) % 2 * 3, (230, 240, 255))
    return finish(img, (40, 50, 70))


@item("e_lv15_crystalspire", E, "水晶尖塔", "building", 2, frames=2, level=15)
def e_lv15_crystalspire(f):
    img = new(22, 40)
    rect(img, 4, 34, 14, 6, STONE[1]); rect(img, 4, 34, 14, 2, STONE[2])
    for y in range(34):                                                     # one tall crystal and two small
        half = max(0, (y - 2) * 5 // 32)
        rect(img, 11 - half, y, 2 * half + 1, 1, CRYSTAL[1])
        put(img, 11 - half, y, CRYSTAL[2]); put(img, 11 + half, y, CRYSTAL[0])
    for (cx, top) in ((6, 22), (16, 25)):
        for y in range(top, 34):
            half = (y - top) * 2 // 10
            rect(img, cx - half, y, 2 * half + 1, 1, CRYSTAL[0] if y % 3 else CRYSTAL[1])
    put(img, 11, 1, STAR if f else CRYSTAL[2])
    for (x, y) in ((3, 8), (19, 14), (2, 20)):
        put(img, x, y + f, STAR if f else (210, 240, 255))
    return finish(img, (40, 60, 90))


@item("e_lv15_aurorafern", E, "極光蕨", "plant", 2, frames=2, level=15)
def e_lv15_aurorafern(f):
    img = new(26, 26)
    cols = [(110, 220, 190), (130, 180, 240), (190, 140, 230), (240, 160, 210)]
    for k, (x0, d) in enumerate(((4, -1), (9, 0), (13, 0), (17, 0), (22, 1))):
        n = 16 + (k % 2) * 6
        for j in range(n):
            x = x0 + d * j // 4 + (1 if f and j > n - 5 else 0); y = 25 - j
            c = cols[(j // 4 + k + f) % 4]
            put(img, x, y, c)
            if j % 2 and j < n - 3:
                put(img, x - 1, y, shade(c, 0.85)); put(img, x + 1, y, shade(c, 1.15))
    return finish(img, (40, 40, 70))


@item("e_lv15_scrollstand", E, "古卷台", "furniture", 1, level=15)
def e_lv15_scrollstand(f):
    img = new(16, 20)
    rect(img, 7, 9, 2, 9, BARK); rect(img, 4, 18, 8, 2, BARK)
    line(img, 2, 9, 13, 5, (150, 110, 70)); line(img, 2, 10, 13, 6, (130, 90, 56))   # a sloping lectern
    rect(img, 3, 3, 10, 5, (244, 234, 206))                                 # an open scroll
    rect(img, 2, 3, 1, 5, (190, 150, 90)); rect(img, 13, 3, 1, 5, (190, 150, 90))
    for x in range(4, 12, 2):
        put(img, x, 5, (110, 120, 150)); put(img, x + 1, 6, (110, 120, 150))
    return finish(img)


# ---- level 18 ------------------------------------------------------------------------------------------------------
@item("e_lv18_lifebloom", E, "生命之花", "plant", 2, frames=2, fn="lv_birth", level=18)
def e_lv18_lifebloom(f):
    img = new(26, 30)
    for y in range(14, 30):
        put(img, 13 + int(1.5 * math.sin(y / 2.5)), y, (70, 140, 70)); put(img, 14 + int(1.5 * math.sin(y / 2.5)), y, (90, 160, 80))
    blob(img, 6, 24, 5, 2, ELEAF, R(3018)); blob(img, 20, 22, 5, 2, ELEAF, R(3118))
    open_ = 8 if f else 7
    for a in range(0, 360, 45):                                             # a great white-gold flower
        x = round(13 + open_ * math.cos(math.radians(a))); y = round(9 + (open_ - 2) * math.sin(math.radians(a)))
        disk(img, x, y, 2, (252, 246, 236))
        put(img, x, y, (246, 220, 170))
    disk(img, 13, 9, 3, E_GOLD); disk(img, 12, 8, 1, E_GOLD_LIGHT)
    for (x, y) in ((3, 4), (23, 6), (6, 16), (21, 15)):                     # motes of life
        put(img, x, y - f, GLOW)
    return finish(img, (60, 60, 40))


@item("e_lv18_amphitheater", E, "林間劇場", "scene", 4, level=18)
def e_lv18_amphitheater(f):
    img = new(44, 26)
    for k in range(4):                                                      # mossy stone tiers in a half ring
        disk(img, 22, 18, 20 - k * 4, STONE[1] if k % 2 else STONE[2], 7 - k)
        for x in range(4 + k * 4, 41 - k * 4, 4):
            put(img, x, 18 - (7 - k) + 1, (100, 160, 90))
    disk(img, 22, 20, 7, (190, 160, 110), 3); disk(img, 22, 19, 6, (210, 180, 130), 2)   # the stage
    for x in (6, 38):                                                       # two little trees as wings
        rect(img, x, 10, 1, 8, BARK); blob(img, x, 7, 3, 4, ELEAF, R(3218 + x))
    rect(img, 21, 14, 2, 4, (240, 220, 160))                                # a harper on stage
    disk(img, 22, 13, 1, (240, 210, 170))
    return finish(img, (40, 50, 40))


@item("e_lv18_peacock", E, "白孔雀", "creature", 2, frames=2, level=18)
def e_lv18_peacock(f):
    img = new(28, 28)
    white = (244, 244, 250)
    spread = 12 if f else 9
    for a in range(200, 341, 10):                                           # its tail fanned (or folding)
        for r in range(2, spread):
            x = round(14 + r * math.cos(math.radians(a))); y = round(18 + r * math.sin(math.radians(a)))
            put(img, x, y, white if r % 4 else (220, 230, 246))
        x = round(14 + spread * math.cos(math.radians(a))); y = round(18 + spread * math.sin(math.radians(a)))
        put(img, x, y, (120, 200, 210))
    disk(img, 14, 19, 3, white, 4)
    rect(img, 15, 11, 2, 7, white); rect(img, 15, 10, 3, 2, white); put(img, 18, 11, E_GOLD); put(img, 16, 10, (60, 60, 80))
    put(img, 15, 8, (200, 220, 240)); put(img, 16, 8, (200, 220, 240))     # its crest
    rect(img, 13, 23, 1, 4, (220, 180, 120)); rect(img, 15, 23, 1, 4, (220, 180, 120))
    return finish(img, (60, 70, 90))


@item("e_lv18_goldenapple", E, "金蘋果樹", "tree", 2, frames=2, level=18)
def e_lv18_goldenapple(f):
    img = leafy(26, 34, BARK, ELEAF, R(3318), trunk_h=11)
    for (x, y) in ((6, 9), (12, 6), (18, 10), (9, 15), (16, 17), (21, 14)):
        disk(img, x, y, 1, E_GOLD); put(img, x - 1, y - 1, E_GOLD_LIGHT)
    if f:
        put(img, 5, 6, STAR); put(img, 20, 4, STAR)
    else:
        put(img, 14, 3, STAR)
    return finish(img, (40, 50, 30))


@item("e_lv18_dreamcatcher", E, "星辰捕夢網", "sign", 1, frames=2, level=18)
def e_lv18_dreamcatcher(f):
    img = new(16, 26)
    rect(img, 7, 0, 1, 4, (200, 190, 160))
    ring(img, 7, 9, 5, (220, 190, 120))
    for a in range(0, 360, 60):
        line(img, 7, 9, round(7 + 4 * math.cos(math.radians(a + f * 30))), round(9 + 4 * math.sin(math.radians(a + f * 30))), (210, 220, 236))
    put(img, 7, 9, STAR)
    for (x, n) in ((3, 8), (7, 11), (11, 8)):                               # feathers and stars hanging
        rect(img, x, 15, 1, n, (220, 210, 190))
        put(img, x + (f if x != 7 else 0), 15 + n, (250, 250, 255)); put(img, x, 15 + n - 1, (200, 210, 240))
    return finish(img, (50, 40, 50))


# ---- level 21 ------------------------------------------------------------------------------------------------------
@item("e_lv21_thornsnare", E, "荊棘藤網", "plant", 2, frames=2, fn="lv_hold", blocks=False, level=21)
def e_lv21_thornsnare(f):
    img = new(30, 18)
    rect(img, 2, 15, 26, 3, (90, 76, 56))
    vine, thorn = (70, 120, 60), (220, 210, 170)
    for k in range(5):                                                      # vines lying in wait, curling up
        x0 = 3 + k * 6
        reach = 9 + (4 if f else 0) - (k % 2) * 3
        for j in range(reach):
            x = x0 + round(2.5 * math.sin(j / 2 + k)); y = 15 - j
            put(img, x, y, vine); put(img, x + 1, y, (90, 150, 70))
            if j % 3 == 2:
                put(img, x - 1, y, thorn)
        put(img, x0 + round(2.5 * math.sin(reach / 2 + k)), 15 - reach, (200, 80, 120))   # a red bud at each tip
    return finish(img, (30, 50, 30))


@item("e_lv21_moongate", E, "水晶月門", "building", 4, frames=2, blocks=False, level=21)
def e_lv21_moongate(f):
    img = new(38, 44)
    for a in range(0, 360, 2):                                              # a ring of crystal standing upright
        for r in (16, 17, 18):
            x = round(19 + r * math.cos(math.radians(a))); y = round(21 + r * math.sin(math.radians(a)))
            put(img, x, y, CRYSTAL[2] if r == 16 else CRYSTAL[1] if r == 17 else CRYSTAL[0])
    for a in range(0, 360, 30):
        x = round(19 + 19 * math.cos(math.radians(a))); y = round(21 + 19 * math.sin(math.radians(a)))
        put(img, x, y, STAR)
    for y in range(6, 37):                                                  # moonlight shimmering in it
        for x in range(4, 35):
            if (x - 19) ** 2 + (y - 21) ** 2 < 15 ** 2 and (x * 3 + y * 5 + f * 7) % 13 == 0:
                put(img, x, y, (210, 226, 255, 200))
    disk(img, 19, 21, 4, MOON); disk(img, 21 - f, 20, 3, (0, 0, 0, 0))
    rect(img, 8, 39, 22, 5, STONE[1]); rect(img, 8, 39, 22, 2, STONE[2])
    return finish(img, (40, 50, 80))


@item("e_lv21_phoenixperch", E, "鳳凰棲木", "creature", 2, frames=2, level=21)
def e_lv21_phoenixperch(f):
    img = new(24, 38)
    rect(img, 11, 12, 2, 26, SILVER); rect(img, 7, 36, 10, 2, STONE[1]); rect(img, 4, 12, 16, 2, SILVER)
    fire = [(230, 80, 40), (246, 150, 50), (252, 220, 110)]
    disk(img, 12, 8, 3, fire[1], 3); put(img, 14, 5, fire[2]); put(img, 15, 6, E_GOLD)   # the phoenix, sat
    put(img, 13, 6, (40, 30, 30))
    for k in range(5):                                                      # its tail, flames that flicker
        line(img, 10, 9, 3 + k, 14 + k * 4 - f * 2, fire[(k + f) % 3])
    for d in (-1, 1):
        line(img, 12, 8, 12 + d * (6 + f * 2), 3 - f * 2, fire[0])
    put(img, 5 + f, 2, fire[2]); put(img, 19 - f, 1, fire[2])
    return finish(img, (60, 30, 20))


@item("e_lv21_sapling", E, "世界樹幼苗", "tree", 2, frames=2, level=21)
def e_lv21_sapling(f):
    img = new(26, 34)
    rect(img, 4, 29, 18, 5, (190, 196, 206)); rect(img, 4, 29, 18, 1, (226, 230, 236))   # a silver ring of stone
    for y in range(12, 30):
        put(img, 13 + (y % 5 == 0), y, BARK); put(img, 12, y, shade(BARK, 1.25))
    for (x1, y1) in ((6, 16), (20, 14), (8, 9), (18, 7)):
        line(img, 13, 20 if y1 > 12 else 14, x1, y1, BARK)
    blob(img, 13, 8, 10, 6, [(50, 140, 120), (80, 190, 150), (160, 240, 200)], R(3021))
    for (x, y) in ((6, 6), (13, 3), (19, 8), (10, 11)):                     # glowing leaves
        put(img, x, y, GLOW if (x + f) % 2 else (255, 255, 230))
    for k in range(3):
        put(img, 5 + k * 8, 26 - (k + f) % 2 * 4, GLOW)
    return finish(img, (30, 60, 50))


@item("e_lv21_stardust", E, "星砂泉", "scene", 2, frames=2, level=21)
def e_lv21_stardust(f):
    img = new(26, 24)
    disk(img, 13, 18, 12, STONE[1], 5); disk(img, 13, 18, 10, (40, 50, 110), 4)   # dark water full of stars
    for (x, y) in ((7, 18), (11, 16), (16, 19), (19, 17), (13, 20)):
        put(img, x + ((x + f) % 2), y, STAR)
    rect(img, 12, 6, 3, 10, SILVER); rect(img, 9, 5, 9, 2, SILVER)
    for k in range(6):                                                      # star sand rising and falling back
        put(img, 13 + (k - 3) * 2 + (f if k % 2 else -f), 4 - abs(k - 3) + (k + f) % 2, STAR if k % 2 else (200, 220, 255))
    return finish(img, (30, 40, 70))


# ---- level 24 ------------------------------------------------------------------------------------------------------
@item("e_lv24_kingstree", E, "精靈王之樹", "building", 4, frames=2, fn="lv_crown", level=24)
def e_lv24_kingstree(f):
    img = new(44, 48)
    rect(img, 17, 18, 10, 30, BARK); rect(img, 17, 18, 3, 30, shade(BARK, 1.25))   # a great trunk
    for (x, d) in ((17, -1), (26, 1)):                                      # roots
        line(img, x, 44, x + d * 8, 47, BARK); line(img, x, 42, x + d * 5, 47, shade(BARK, 0.85))
    blob(img, 22, 11, 20, 10, [(40, 120, 80), (70, 170, 110), (140, 220, 160)], R(3024))
    for (x, y) in ((10, 8), (20, 4), (31, 7), (14, 14), (28, 14)):          # golden leaves
        put(img, x, y, E_GOLD_LIGHT); put(img, x + 1, y, E_GOLD)
    for k in range(5):                                                      # a golden crown resting on the canopy
        rect(img, 15 + k * 3, 1 + (k % 2) * 2, 2, 4 - (k % 2) * 2, E_GOLD)
    rect(img, 15, 4, 14, 2, E_GOLD); put(img, 22, 4, (230, 80, 120)); put(img, 18, 4, CRYSTAL[1]); put(img, 26, 4, CRYSTAL[1])
    rect(img, 18, 30, 8, 10, (60, 40, 28))                                  # a throne in the hollow
    rect(img, 19, 36, 6, 4, (130, 60, 80)); rect(img, 19, 31, 6, 2, E_GOLD)
    for (x, y) in ((4, 24), (40, 22), (8, 32), (36, 34), (22, 0)):          # light falling round it
        put(img, x, y - f, STAR if (x + f) % 2 else GLOW)
    return finish(img, (30, 50, 40))


@item("e_lv24_unicorn", E, "獨角獸林地", "creature", 4, frames=2, level=24)
def e_lv24_unicorn(f):
    img = new(40, 32)
    disk(img, 20, 27, 19, (110, 170, 100), 4)                               # a glade of soft grass
    for (x, c) in ((5, PETAL), (34, LILAC[2]), (12, (250, 240, 150)), (28, PETAL)):
        put(img, x, 28, c)
    white = (250, 250, 255)
    rect(img, 12, 15, 14, 6, white)                                         # the unicorn
    for (x, lift) in ((13, f), (16, 0), (22, 0), (25, f)):
        rect(img, x, 21, 1, 6 - lift, white); put(img, x, 26 - lift, (200, 190, 220))
    rect(img, 23, 9, 3, 7, white); rect(img, 24, 6, 6, 4, white); put(img, 29, 8, (220, 200, 220))
    put(img, 26, 7, (80, 90, 160))
    line(img, 27, 5, 31, 0, E_GOLD); put(img, 28, 4, E_GOLD_LIGHT)              # its horn
    for y in range(6, 15):                                                  # a mane of rainbow
        put(img, 22, y, [(240, 160, 200), (180, 160, 240), (160, 220, 240)][(y + f) % 3])
    for y in range(15, 22):
        put(img, 11 - (1 if f else 0), y, [(240, 160, 200), (180, 160, 240), (160, 220, 240)][y % 3])
    for (x, y) in ((6, 6), (34, 3), (3, 16)):
        put(img, x, y + f, STAR)
    return finish(img, (60, 60, 90))


@item("e_lv24_jadedragon", E, "翡翠幼龍", "creature", 2, frames=2, level=24)
def e_lv24_jadedragon(f):
    img = new(28, 26)
    jade = [(40, 130, 100), (70, 180, 140), (140, 230, 190)]
    blob(img, 13, 18, 7, 4, jade, R(3124))                                  # curled up on a stone
    for x in range(4, 9):
        put(img, x, 21 - (x - 4) // 2, jade[0])
    rect(img, 18, 10, 3, 7, jade[1]); blob(img, 21, 8, 4, 3, jade, R(3224))
    put(img, 22, 7, E_GOLD); put(img, 25, 9, (30, 60, 50))
    put(img, 19, 4, E_GOLD_LIGHT); put(img, 22, 4, E_GOLD_LIGHT)                # little horns
    wing = 6 if f else 3                                                    # wings stretching
    for k in range(wing):
        line(img, 12, 15, 8 - k, 15 - wing - k // 2, (110, 210, 170))
    rect(img, 4, 22, 20, 4, STONE[1]); rect(img, 4, 22, 20, 1, STONE[2])
    if f:
        put(img, 27, 6, (200, 255, 220)); put(img, 26, 5, (200, 255, 220))
    return finish(img, (20, 50, 40))


@item("e_lv24_orrery", E, "天體儀", "furniture", 2, frames=2, level=24)
def e_lv24_orrery(f):
    img = new(24, 28)
    rect(img, 11, 18, 2, 8, E_GOLD); rect(img, 6, 26, 12, 2, (150, 120, 60))
    disk(img, 12, 11, 2, (250, 220, 120)); put(img, 11, 10, STAR)           # the sun in the middle
    ring(img, 12, 11, 6, E_GOLD, 3); ring(img, 12, 11, 10, (190, 170, 110), 5)
    a1, a2 = math.radians(30 + f * 70), math.radians(200 + f * 40)
    disk(img, round(12 + 6 * math.cos(a1)), round(11 + 3 * math.sin(a1)), 1, (100, 160, 230))
    disk(img, round(12 + 10 * math.cos(a2)), round(11 + 5 * math.sin(a2)), 1, (220, 120, 90))
    put(img, round(12 + 10 * math.cos(a2 + 1.2)), round(11 + 5 * math.sin(a2 + 1.2)), MOON)
    return finish(img, (60, 50, 30))


@item("e_lv24_starlily", E, "星辰百合", "flower", 1, frames=2, level=24)
def e_lv24_starlily(f):
    img = new(16, 20)
    for (x, h) in ((4, 12), (11, 15)):
        rect(img, x, 20 - h + 3, 1, h - 3, (70, 140, 90))
        top = 20 - h
        for (dx, dy) in ((-2, 0), (2, 0), (0, -2), (-1, 1), (1, 1)):         # star-shaped petals
            put(img, x + dx, top + dy, (230, 236, 255)); put(img, x + dx // 2, top + dy // 2, (250, 250, 255))
        put(img, x, top, E_GOLD if f else STAR)
    rect(img, 6, 14, 3, 1, ELEAF[1]); rect(img, 9, 11, 2, 1, ELEAF[1])
    if f:
        put(img, 1, 3, STAR); put(img, 14, 1, STAR)
    return finish(img, (50, 50, 80))
