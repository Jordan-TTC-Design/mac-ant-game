# The goblins' decorations a race level unlocks (DESKTOP.md §5.5): five every three levels, 3 to 24, grander as it goes.
# Run inside make_decor.py's namespace (its helpers, colours and `item`); one of each five does something (fn "lv_*").
GREEN_SKIN = [(70, 130, 50), (96, 160, 66), (130, 190, 90)]
G_IRON = [(70, 70, 80), (110, 110, 122), (160, 160, 172)]
CLOTH_RED = (170, 50, 44)


# ---- level 3 ------------------------------------------------------------------------------------------------------
@item("g_lv3_bathtub", G, "木桶澡盆", "furniture", 1, frames=2, fn="lv_rest", level=3)
def g_lv3_bathtub(f):
    img = new(18, 16)
    rect(img, 2, 7, 14, 9, WOOD); rect(img, 3, 7, 2, 9, WOOD_LIGHT)                         # the tub
    rect(img, 2, 9, 14, 1, G_IRON[0]); rect(img, 2, 13, 14, 1, G_IRON[0])
    rect(img, 3, 6, 12, 2, (110, 170, 210)); rect(img, 4, 6, 4, 1, (170, 210, 240))         # the water
    rect(img, 9, 3, 4, 4, GREEN_SKIN[1]); put(img, 10, 4, INK); put(img, 12, 4, INK)         # a goblin soaking
    put(img, 8, 3, GREEN_SKIN[1]); put(img, 13, 3, GREEN_SKIN[1])                            # its ears
    for k in range(3):                                                                       # steam
        put(img, 4 + k * 3 + f, 2 - (k + f) % 2, (220, 220, 220, 170))
    return finish(img)


@item("g_lv3_banner", G, "破布戰旗", "sign", 1, frames=2, level=3)
def g_lv3_banner(f):
    img = new(14, 28)
    rect(img, 3, 2, 2, 26, WOOD); rect(img, 3, 2, 1, 26, WOOD_LIGHT)
    put(img, 3, 1, BONE); put(img, 4, 0, BONE)                                               # a bone tip
    for y in range(4, 16):                                                                   # the rag, flapping
        w = 8 - (y - 4) // 4 + (f if y % 3 == 0 else 0)
        rect(img, 5, y, w, 1, CLOTH_RED if y % 4 else shade(CLOTH_RED, 0.8))
    rect(img, 7, 8, 3, 3, BONE); put(img, 8, 9, INK)                                         # a skull daubed on
    return finish(img)


@item("g_lv3_mushroomlamp", G, "蘑菇燈", "flower", 1, frames=2, level=3)
def g_lv3_mushroomlamp(f):
    img = new(14, 16)
    glow = (150, 230, 140) if f else (120, 200, 120)
    for (x, top, r) in ((5, 4, 4), (10, 9, 2)):
        rect(img, x - 1, top + 2, 2, 16 - top - 2, (220, 210, 180))                          # the stalks
        disk(img, x, top, r, glow, 2); put(img, x - 1, top - 1, (220, 255, 210))
    put(img, 3, 1 - f + 1, (200, 255, 190)); put(img, 12, 6 + f, (200, 255, 190))          # drifting spores
    return finish(img, (30, 50, 30))


@item("g_lv3_woodpile", G, "柴堆", "scene", 1, level=3)
def g_lv3_woodpile(f):
    img = new(18, 12)
    for (x, y) in ((1, 7), (6, 7), (11, 7), (3, 3), (8, 3), (6, 0)):
        rect(img, x, y, 5, 4, WOOD); disk(img, x + 1, y + 1, 1, (200, 160, 100))             # log ends
        put(img, x + 1, y + 1, (160, 120, 70))
    rect(img, 14, 0, 1, 7, WOOD_DARK); rect(img, 13, 0, 3, 2, G_IRON[2])                      # an axe stuck in
    return finish(img)


@item("g_lv3_scarecrow", G, "稻草哥布林", "scene", 2, frames=2, level=3)
def g_lv3_scarecrow(f):
    img = new(22, 30)
    rect(img, 10, 8, 2, 22, WOOD)
    rect(img, 2, 12, 18, 2, WOOD_LIGHT)                                                       # the arms
    rect(img, 6, 11, 10, 10, (190, 150, 80)); rect(img, 6, 15, 10, 1, (150, 110, 50))       # a straw body in a sack
    disk(img, 11, 6, 4, (210, 180, 100)); put(img, 9, 5, INK); put(img, 13, 5, INK)          # the head
    put(img, 6, 4 - f, (210, 180, 100)); put(img, 16, 4 - f, (210, 180, 100))               # its big ears wag
    rect(img, 9, 8, 5, 1, INK)
    for x in (2, 19):
        put(img, x, 14, (230, 200, 120)); put(img, x, 15, (230, 200, 120))
    bird(17, 10 + f)(img, f)                                                                  # a crow, not scared
    return finish(img)


# ---- level 6 ------------------------------------------------------------------------------------------------------
@item("g_lv6_forge", G, "大熔爐", "building", 4, frames=2, fn="lv_whet", level=6)
def g_lv6_forge(f):
    img = new(38, 36)
    for y in range(8, 34):                                                                   # a stone furnace, wider at the base
        half = 8 + (y - 8) // 4
        rect(img, 19 - half, y, 2 * half, 1, STONE[1] if (y // 3 + y) % 5 else STONE[0])
    rect(img, 15, 2, 8, 7, STONE[0]); rect(img, 15, 2, 2, 7, STONE[2])                     # the chimney
    for k in range(3):
        put(img, 18 + (k + f) % 2, 1 - k, (190, 190, 190, 200))
    rect(img, 13, 22, 12, 9, (60, 30, 20))                                                   # its mouth, glowing
    rect(img, 14, 24, 10, 7, (240, 110 + 40 * f, 30)); rect(img, 16, 26, 6, 4, (255, 210, 90))
    rect(img, 2, 28, 6, 3, G_IRON[0]); rect(img, 3, 31, 4, 3, G_IRON[0]); rect(img, 2, 28, 6, 1, G_IRON[2])  # an anvil
    rect(img, 30, 24, 6, 10, (130, 90, 50)); rect(img, 30, 26, 6, 1, G_IRON[0])               # a water barrel
    rect(img, 31, 22 - f, 1, 3, G_IRON[2])                                                      # a blade cooling
    return finish(img)


@item("g_lv6_weaponrack", G, "兵器架", "furniture", 1, level=6)
def g_lv6_weaponrack(f):
    img = new(18, 22)
    rect(img, 1, 6, 16, 2, WOOD); rect(img, 1, 18, 16, 2, WOOD)
    rect(img, 1, 6, 2, 16, WOOD_DARK); rect(img, 15, 6, 2, 16, WOOD_DARK)
    rect(img, 5, 1, 1, 19, WOOD_LIGHT); rect(img, 4, 0, 3, 3, G_IRON[2])                      # a spear
    rect(img, 9, 3, 1, 17, WOOD_LIGHT); rect(img, 7, 3, 5, 4, G_IRON[1]); rect(img, 7, 3, 2, 4, G_IRON[2])  # an axe
    rect(img, 12, 5, 2, 12, G_IRON[2]); rect(img, 11, 15, 4, 1, WOOD_DARK); rect(img, 12, 16, 2, 4, WOOD)  # a sword
    return finish(img)


@item("g_lv6_goatpen", G, "山羊圈", "pen", 2, frames=2, level=6)
def g_lv6_goatpen(f):
    def goat(cx, cy, flip):
        def draw(img, frame):
            c = (220, 214, 200)
            rect(img, cx - 3, cy - 1, 7, 4, c); rect(img, cx - 3, cy - 1, 7, 1, (240, 236, 226))
            for lx in (-2, 2):
                rect(img, cx + lx, cy + 3, 1, 3, (150, 140, 130))
            hx = cx + 4 * flip
            rect(img, hx, cy - 4 + frame % 2, 2, 3, c)
            put(img, hx - flip, cy - 5 + frame % 2, (120, 100, 80)); put(img, hx + 1, cy - 1 + frame % 2, (200, 200, 190))  # horn, beard
        return draw
    return pen(30, 22, WOOD, WOOD_LIGHT, [goat(10, 13, 1), goat(21, 12, -1)], f, ground=(120, 110, 70))


@item("g_lv6_signpost", G, "指路牌", "sign", 1, level=6)
def g_lv6_signpost(f):
    img = new(20, 26)
    rect(img, 9, 4, 2, 22, WOOD)
    for (y, d, c) in ((5, 1, (200, 170, 110)), (11, -1, (180, 150, 96)), (17, 1, (200, 170, 110))):
        x0 = 10 if d > 0 else 1
        rect(img, x0, y, 9, 4, c)
        put(img, x0 + (9 if d > 0 else -1), y + 1, c); put(img, x0 + (9 if d > 0 else -1), y + 2, c)  # the pointy end
        rect(img, x0 + 2, y + 2, 5, 1, shade(c, 0.6))                                        # scrawled words
    return finish(img)


@item("g_lv6_cart", G, "破板車", "scene", 2, level=6)
def g_lv6_cart(f):
    img = new(28, 18)
    rect(img, 3, 6, 18, 6, WOOD); rect(img, 3, 6, 18, 1, WOOD_LIGHT)
    for x in range(5, 21, 4):
        put(img, x, 9, WOOD_DARK)
    line(img, 21, 9, 27, 7, WOOD_DARK)                                                        # the shafts
    for (x, y, c) in ((6, 3, (150, 150, 160)), (10, 2, (210, 190, 120)), (15, 3, (130, 90, 60))):  # loot piled on
        rect(img, x, y, 4, 3, c)
    for cx in (7, 18):                                                                        # two odd wheels
        ring(img, cx, 13, 4, WOOD_DARK); line(img, cx - 3, 13, cx + 3, 13, WOOD); line(img, cx, 10, cx, 16, WOOD)
    return finish(img)


# ---- level 9 ------------------------------------------------------------------------------------------------------
@item("g_lv9_playpen", G, "小鬼遊樂場", "scene", 2, frames=2, fn="lv_nursery", level=9)
def g_lv9_playpen(f):
    img = new(30, 26)
    for x in (2, 14):                                                                         # the swing's frame
        line(img, x, 25, x + 3, 2, WOOD); line(img, x + 6, 25, x + 3, 2, WOOD)
    rect(img, 4, 2, 12, 2, WOOD_LIGHT)
    sx = 8 + (2 if f else -2)
    line(img, 9, 4, sx, 16, (200, 190, 160)); line(img, 11, 4, sx + 2, 16, (200, 190, 160))  # the ropes
    rect(img, sx - 1, 16, 5, 2, WOOD)
    rect(img, sx, 12, 3, 4, GREEN_SKIN[2]); put(img, sx + 1, 13, INK)                       # a little one on it
    disk(img, 24, 21, 5, (220, 190, 110), 3); rect(img, 21, 20, 6, 1, (240, 210, 140))      # a sand heap
    rect(img, 25, 15, 1, 5, WOOD); rect(img, 24, 14, 3, 2, G_IRON[1])                          # a toy spade
    return finish(img)


@item("g_lv9_treehouse", G, "樹屋", "tree", 4, frames=2, level=9)
def g_lv9_treehouse(f):
    img = new(36, 48)
    rect(img, 16, 24, 5, 24, T.TRUNK["meadow"]); rect(img, 16, 24, 1, 24, shade(T.TRUNK["meadow"], 1.3))
    put(img, 14, 47, T.TRUNK["meadow"]); put(img, 22, 47, T.TRUNK["meadow"])
    blob(img, 18, 12, 16, 11, T.LEAF["meadow"], R(901))
    rect(img, 8, 20, 20, 10, (150, 110, 70))                                                  # the hut in the branches
    for y in range(20, 30, 3):
        rect(img, 8, y, 20, 1, shade((150, 110, 70), 0.85))
    tri_roof(img, 18, 13, 12, 7, (130, 70, 44), shade((130, 70, 44), 1.2))
    rect(img, 12, 23, 3, 3, (250, 210, 110) if f else (240, 190, 90))                       # a lit window
    rect(img, 6, 30, 26, 2, WOOD)                                                            # the platform
    for y in range(32, 46, 3):                                                               # a rope ladder
        rect(img, 24, y, 4, 1, WOOD_LIGHT)
    line(img, 24, 32, 24, 46, (200, 190, 160)); line(img, 27, 32, 27 + f, 46, (200, 190, 160))
    return finish(img, T.OUTLINE["meadow"])


@item("g_lv9_rockgarden", G, "亂石堆", "scene", 1, level=9)
def g_lv9_rockgarden(f):
    img = new(18, 14)
    blob(img, 6, 9, 5, 4, STONE, R(902)); blob(img, 13, 10, 4, 3, STONE, R(903)); blob(img, 9, 4, 3, 3, STONE, R(904))
    put(img, 11, 2, (120, 180, 80)); put(img, 3, 12, (120, 180, 80)); put(img, 16, 12, (240, 220, 90))  # moss and a flower
    return finish(img)


@item("g_lv9_ratcage", G, "老鼠籠", "pen", 1, frames=2, level=9)
def g_lv9_ratcage(f):
    img = new(16, 18)
    rect(img, 1, 15, 14, 3, WOOD)
    for x in range(2, 15, 3):
        rect(img, x, 3, 1, 12, G_IRON[1])
    rect(img, 1, 2, 14, 2, G_IRON[0]); rect(img, 7, 0, 2, 2, G_IRON[0])
    x = 5 + 4 * f                                                                             # the rat runs about
    rect(img, x, 12, 4, 3, (130, 120, 120)); put(img, x + 4 if f == 0 else x - 1, 12, (130, 120, 120))
    put(img, x + (3 if f == 0 else 0), 12, (240, 80, 80))
    put(img, x - 1 if f == 0 else x + 4, 14, (200, 150, 150))                                  # its tail
    return finish(img)


@item("g_lv9_lanterns", G, "燈籠串", "sign", 2, frames=2, level=9)
def g_lv9_lanterns(f):
    img = new(30, 28)
    for x in (2, 26):
        rect(img, x, 4, 2, 24, WOOD)
    for x in range(4, 26):                                                                    # the sagging string
        put(img, x, 5 + int(3 * math.sin(math.pi * (x - 4) / 22)), (60, 50, 40))
    for k, x in enumerate((8, 15, 22)):
        y = 6 + int(3 * math.sin(math.pi * (x - 4) / 22))
        c = ((240, 130, 50), (230, 80, 60), (240, 190, 60))[k]
        lit = shade(c, 1.15) if (k + f) % 2 else c
        rect(img, x - 2, y + 1, 5, 5, lit); rect(img, x - 1, y + 2, 2, 2, (255, 240, 170))
        put(img, x, y + 6, INK)
    return finish(img)


# ---- level 12 -----------------------------------------------------------------------------------------------------
@item("g_lv12_dummy", G, "練武木人", "scene", 2, frames=2, fn="lv_might", level=12)
def g_lv12_dummy(f):
    img = new(24, 32)
    rect(img, 4, 28, 16, 4, WOOD_DARK)                                                        # the base
    lean = 1 if f else 0
    rect(img, 11 + lean, 8, 3, 21, WOOD)                                                      # the post
    rect(img, 7 + lean, 12, 11, 9, (200, 170, 110)); rect(img, 7 + lean, 15, 11, 1, (150, 120, 70))  # a straw body
    for y in (13, 17):
        line(img, 3 + lean, y, 21 + lean, y + 1, WOOD_LIGHT)                                  # its arms to hit
    disk(img, 12 + lean, 5, 4, (200, 170, 110)); put(img, 10 + lean, 4, INK); put(img, 14 + lean, 4, INK)
    rect(img, 9 + lean, 1, 7, 2, G_IRON[1])                                                     # a dented pot for a helmet
    line(img, 9, 18, 15, 22, (200, 60, 50))                                                   # a scar of red paint
    return finish(img)


@item("g_lv12_warhorn", G, "大號角", "furniture", 1, level=12)
def g_lv12_warhorn(f):
    img = new(22, 20)
    rect(img, 4, 13, 2, 7, WOOD); rect(img, 16, 13, 2, 7, WOOD); rect(img, 2, 12, 18, 2, WOOD_LIGHT)  # a stand
    for x in range(2, 19):                                                                    # the horn, curling up and widening
        r = (x - 2) // 5
        cy = 10 - int(4 * math.sin(math.pi * (x - 2) / 26))
        rect(img, x, cy - r, 1, 2 * r + 2, BONE_SHADE if x % 4 == 0 else BONE)
        put(img, x, cy - r, (252, 248, 236))
    rect(img, 1, 9, 2, 3, WOOD_DARK)                                                          # the mouthpiece
    disk(img, 18, 6, 2, (60, 40, 30), 4)                                                      # its bell, open
    rect(img, 8, 9, 2, 4, CLOTH_RED)                                                          # a red binding
    return finish(img)


@item("g_lv12_maptable", G, "作戰地圖桌", "furniture", 2, level=12)
def g_lv12_maptable(f):
    img = new(26, 16)
    rect(img, 1, 4, 24, 4, WOOD); rect(img, 1, 4, 24, 1, WOOD_LIGHT)
    rect(img, 3, 8, 2, 8, WOOD_DARK); rect(img, 21, 8, 2, 8, WOOD_DARK)
    rect(img, 4, 2, 18, 4, (230, 210, 160))                                                   # the map
    line(img, 6, 5, 18, 3, (200, 60, 50)); put(img, 18, 3, (200, 60, 50))                    # the raid's arrow
    for (x, c) in ((8, (60, 120, 60)), (13, (60, 120, 60)), (19, (180, 50, 40))):            # pieces
        rect(img, x, 1, 1, 2, c)
    rect(img, 22, 0, 2, 4, (200, 150, 90))                                                    # a candle stub
    return finish(img)


@item("g_lv12_wolfstatue", G, "狼王石像", "scene", 2, level=12)
def g_lv12_wolfstatue(f):
    img = new(24, 30)
    rect(img, 3, 22, 18, 8, STONE[0]); rect(img, 3, 22, 18, 2, STONE[2])                     # the plinth
    blob(img, 12, 16, 7, 5, STONE, R(1201))                                                   # the wolf, sitting
    rect(img, 13, 5, 6, 7, STONE[1]); rect(img, 13, 5, 2, 7, STONE[2])
    put(img, 13, 3, STONE[2]); put(img, 14, 4, STONE[2]); put(img, 18, 3, STONE[1]); put(img, 17, 4, STONE[1])  # ears
    rect(img, 18, 8, 3, 2, STONE[1]); put(img, 15, 7, (200, 60, 50))                         # snout, a red eye
    rect(img, 6, 18, 2, 4, STONE[0]); rect(img, 15, 18, 2, 4, STONE[0])
    return finish(img, (40, 40, 48))


@item("g_lv12_stakes", G, "尖樁陣", "scene", 2, level=12)
def g_lv12_stakes(f):
    img = new(30, 20)
    for k, x in enumerate(range(2, 28, 5)):
        h = 12 + (k * 7) % 5
        line(img, x, 19, x + 3, 19 - h, WOOD); line(img, x + 1, 19, x + 4, 19 - h, WOOD_LIGHT)
        put(img, x + 3, 19 - h - 1, (230, 220, 200))
    rect(img, 1, 14, 28, 1, (200, 190, 160))                                                  # a lashing rope
    rect(img, 12, 6, 3, 3, BONE); put(img, 13, 7, INK)                                       # a skull stuck on one
    return finish(img)


# ---- level 15 -----------------------------------------------------------------------------------------------------
@item("g_lv15_guardlizard", G, "看門巨蜥", "creature", 2, frames=2, fn="lv_ward", blocks=False, level=15)
def g_lv15_guardlizard(f):
    img = new(32, 18)
    body = [(60, 120, 60), (86, 150, 70), (120, 180, 90)]
    blob(img, 14, 10, 9, 4, body, R(1501))
    for x in range(1, 7):                                                                     # the tail
        put(img, x, 11 + (x + f) % 2, body[1]); put(img, x, 12 + (x + f) % 2, body[0])
    hy = 7 - f
    rect(img, 22, hy, 8, 5, body[1]); rect(img, 22, hy, 8, 1, body[2])                       # the head, rising
    put(img, 25, hy + 1, (240, 200, 40)); put(img, 25, hy + 2, INK)
    if f:
        rect(img, 28, hy + 3, 3, 2, (200, 60, 60)); put(img, 31, hy + 2, (200, 60, 60))      # its forked tongue
    for x in (9, 13, 17, 20):
        rect(img, x, 14, 2, 3, body[0])
    for x in range(9, 21, 3):
        put(img, x, 6, (200, 170, 70))                                                        # spikes down its back
    rect(img, 12, 8, 6, 1, (120, 80, 40))                                                     # its collar
    return finish(img, (24, 50, 30))


@item("g_lv15_stonetower", G, "石頭哨塔", "building", 4, frames=2, level=15)
def g_lv15_stonetower(f):
    img = new(30, 54)
    for y in range(12, 54):
        half = 8 + (y - 12) // 8
        rect(img, 15 - half, y, 2 * half, 1, STONE[1] if (y // 4) % 2 else shade(STONE[1], 0.92))
        if y % 4 == 0:
            for x in range(15 - half + (y // 4) % 2 * 3, 15 + half, 6):
                put(img, x, y, STONE[0])
    for x in range(5, 26, 4):
        rect(img, x, 8, 3, 4, STONE[2])                                                        # battlements
    rect(img, 5, 11, 20, 2, STONE[0])
    rect(img, 13, 22, 4, 6, (40, 30, 30)); rect(img, 14, 23, 2, 3, (250, 200, 90) if f else (220, 160, 70))  # an arrow slit
    rect(img, 12, 46, 6, 8, (70, 46, 28))                                                     # the door
    rect(img, 22, 0, 1, 9, WOOD)
    rect(img, 23, 1, 5 - f, 3, CLOTH_RED); put(img, 27 - f, 2 + f, CLOTH_RED)                 # a flag
    return finish(img, (40, 40, 48))


@item("g_lv15_trollskull", G, "巨魔頭骨", "bone", 2, level=15)
def g_lv15_trollskull(f):
    img = new(28, 22)
    disk(img, 14, 9, 10, BONE, 8); disk(img, 12, 6, 6, (250, 246, 232), 4)
    disk(img, 9, 10, 3, INK, 3); disk(img, 19, 10, 3, INK, 3)                                 # eye holes
    rect(img, 13, 13, 2, 2, INK)
    rect(img, 7, 16, 14, 4, BONE_SHADE)
    for x in range(8, 21, 3):
        rect(img, x, 16, 2, 3, BONE)                                                          # teeth
    for (x0, x1) in ((7, 1), (21, 27)):                                                       # big tusks curling up past the jaw
        line(img, x0, 19, x1, 11, (250, 246, 232)); line(img, x0, 20, x1, 12, BONE_SHADE)
    line(img, 16, 1, 18, 5, BONE_SHADE)                                                       # a crack
    return finish(img)


@item("g_lv15_still", G, "蒸餾鍋", "furniture", 2, frames=2, level=15)
def g_lv15_still(f):
    img = new(26, 24)
    disk(img, 9, 15, 7, (190, 110, 60), 6); disk(img, 7, 13, 3, (220, 150, 90))             # the copper pot
    rect(img, 7, 4, 4, 6, (190, 110, 60))
    for x in range(10, 21):                                                                    # the coil
        put(img, x, 4 + (x - 10) // 2, (170, 100, 50))
    for y in range(9, 18, 2):
        rect(img, 18, y, 5, 1, (170, 100, 50))
    rect(img, 18, 19, 5, 5, (130, 90, 50)); rect(img, 18, 19, 5, 1, (90, 180, 90))           # a jug of green brew
    put(img, 20, 18 + f, (120, 220, 110))                                                     # a drip
    rect(img, 5, 21, 2, 3, (240, 120, 40)); rect(img, 10, 21, 2, 3, (240, 120 + 50 * f, 40))  # the fire
    return finish(img)


@item("g_lv15_warbanners", G, "戰旗陣", "sign", 2, frames=2, level=15)
def g_lv15_warbanners(f):
    img = new(30, 34)
    for k, (x, c) in enumerate(((3, CLOTH_RED), (13, (60, 100, 50)), (23, (200, 160, 50)))):
        top = 2 + (k % 2) * 3
        rect(img, x, top, 1, 34 - top, WOOD)
        for y in range(top + 2, top + 16):
            w = 6 - (y - top) // 6 + ((f + k) % 2 if y % 3 == 0 else 0)
            rect(img, x + 1, y, w, 1, c if y % 5 else shade(c, 0.8))
        put(img, x + 3, top + 7, BONE); put(img, x + 4, top + 7, BONE)
    return finish(img)


# ---- level 18 -----------------------------------------------------------------------------------------------------
@item("g_lv18_mothershrine", G, "多子神龕", "building", 2, frames=2, fn="lv_birth", level=18)
def g_lv18_mothershrine(f):
    img = new(24, 34)
    rect(img, 2, 28, 20, 6, STONE[0]); rect(img, 2, 28, 20, 1, STONE[2])
    rect(img, 4, 8, 16, 20, STONE[1]); rect(img, 4, 8, 2, 20, STONE[2])                      # the alcove
    tri_roof(img, 12, 1, 11, 8, (130, 70, 44), shade((130, 70, 44), 1.2))
    rect(img, 7, 11, 10, 15, (60, 50, 50))
    disk(img, 12, 19, 4, GREEN_SKIN[1], 5); disk(img, 12, 13, 2, GREEN_SKIN[2])              # a round mother idol
    for (x, y) in ((8, 23), (16, 23), (12, 25)):                                              # babies about her
        rect(img, x - 1, y, 2, 2, GREEN_SKIN[2])
    for x in (6, 17):                                                                         # candles
        rect(img, x, 24, 1, 3, (240, 230, 200)); put(img, x, 23 - f, (255, 200, 80))
    return finish(img)


@item("g_lv18_goldpile", G, "金幣堆", "furniture", 1, frames=2, level=18)
def g_lv18_goldpile(f):
    img = new(18, 12)
    for y in range(4, 12):
        half = 2 + (y - 4)
        rect(img, 9 - half, y, 2 * half, 1, GOLD if y % 2 else GOLD_DARK)
    for (x, y) in ((6, 6), (11, 8), (4, 10), (14, 10)):
        put(img, x, y, GOLD_LIGHT)
    rect(img, 13, 3, 3, 4, (180, 60, 60)); put(img, 14, 2, (250, 200, 210))                  # a ruby goblet on top
    put(img, 7 + f * 5, 4 + f, (255, 255, 230))                                               # a glint
    return finish(img)


@item("g_lv18_shroomgrove", G, "巨菇林", "tree", 4, frames=2, level=18)
def g_lv18_shroomgrove(f):
    img = new(38, 38)
    caps = (((10, 18, 8, 4), (180, 60, 60)), ((26, 10, 10, 5), (150, 90, 170)), ((20, 26, 5, 3), (210, 150, 60)))
    for ((x, top, r, ry), c) in caps:
        rect(img, x - 2, top + ry, 4, 38 - top - ry, (226, 216, 190)); rect(img, x - 2, top + ry, 1, 38 - top - ry, (246, 240, 220))
        disk(img, x, top, r, c, ry); disk(img, x - r // 3, top - ry // 2, r // 3, shade(c, 1.25), max(1, ry // 3))
        for k in range(-r + 2, r - 1, 3):
            put(img, x + k, top - 1 + (k % 2), (250, 240, 220))                                # white spots
    for k in range(4):                                                                         # spores drifting
        put(img, 6 + k * 8 + f, 4 + (k * 5 + f * 2) % 10, (230, 210, 255))
    return finish(img, (40, 30, 30))


@item("g_lv18_blackmarket", G, "黑市攤", "building", 2, frames=2, level=18)
def g_lv18_blackmarket(f):
    img = new(28, 28)
    for x in (2, 24):
        rect(img, x, 6, 2, 22, WOOD)
    for x in range(0, 28):                                                                     # a striped awning
        rect(img, x, 3, 1, 5, (60, 40, 70) if (x // 3) % 2 else (100, 70, 120))
    for x in range(1, 28, 3):
        put(img, x, 8, (60, 40, 70))
    rect(img, 2, 18, 22, 3, WOOD_LIGHT); rect(img, 3, 21, 20, 6, WOOD)
    for (x, c) in ((5, (90, 200, 160)), (10, GOLD), (15, (200, 80, 200)), (20, G_IRON[2])):    # dodgy goods
        rect(img, x, 15, 3, 3, c)
    rect(img, 11, 10, 5, 5, (50, 40, 50)); put(img, 12 + f, 12, (240, 220, 80)); put(img, 14 + f, 12, (240, 220, 80))  # a hooded seller's eyes
    return finish(img)


@item("g_lv18_bearcage", G, "鐵籠熊", "pen", 2, frames=2, level=18)
def g_lv18_bearcage(f):
    img = new(28, 26)
    rect(img, 1, 22, 26, 4, WOOD_DARK)
    fur = [(90, 60, 40), (120, 84, 56), (150, 110, 76)]
    blob(img, 14, 15, 8, 6, fur, R(1801))                                                      # the bear
    disk(img, 14 + f, 8, 4, fur[1]); put(img, 11 + f, 4, fur[0]); put(img, 17 + f, 4, fur[0])
    put(img, 13 + f, 7, INK); put(img, 15 + f, 7, INK); rect(img, 13 + f, 9, 3, 2, (200, 170, 130))
    for x in range(2, 27, 4):                                                                   # the bars in front
        rect(img, x, 2, 1, 20, G_IRON[1]); put(img, x, 2, G_IRON[2])
    rect(img, 1, 1, 26, 2, G_IRON[0])
    return finish(img)


# ---- level 21 -----------------------------------------------------------------------------------------------------
@item("g_lv21_nettrap", G, "大網陷阱", "scene", 2, frames=2, fn="lv_hold", blocks=False, level=21)
def g_lv21_nettrap(f):
    img = new(30, 20)
    disk(img, 15, 14, 13, (120, 96, 60), 5); disk(img, 15, 14, 11, (100, 78, 46), 4)         # the dug patch
    net = (200, 186, 140)
    for x in range(4, 27, 4):                                                                  # the net laid over it
        line(img, x, 10 + f, x + 2, 18, net)
    for y in (12, 15):
        line(img, 3, y + f, 27, y, net)
    rect(img, 1, 2, 2, 16, WOOD); rect(img, 27, 2, 2, 16, WOOD)                                # stakes with ropes
    line(img, 3, 3, 8, 11 + f, net); line(img, 27, 3, 22, 11 + f, net)
    rect(img, 13, 9, 4, 2, (200, 80, 60))                                                      # a bait steak
    return finish(img, (60, 40, 22))


@item("g_lv21_catapult", G, "投石機", "building", 4, frames=2, level=21)
def g_lv21_catapult(f):
    img = new(42, 34)
    rect(img, 4, 24, 32, 4, WOOD); rect(img, 4, 24, 32, 1, WOOD_LIGHT)                         # the frame
    for cx in (9, 31):
        ring(img, cx, 29, 4, WOOD_DARK); disk(img, cx, 29, 1, G_IRON[1])
    line(img, 12, 24, 20, 12, WOOD); line(img, 28, 24, 20, 12, WOOD); rect(img, 18, 11, 5, 2, WOOD_LIGHT)
    if f:                                                                                      # the arm, cocked / thrown
        line(img, 6, 22, 34, 6, WOOD_DARK); line(img, 6, 21, 34, 5, WOOD)
        disk(img, 36, 4, 3, STONE[1])
    else:
        line(img, 8, 6, 30, 22, WOOD_DARK); line(img, 8, 5, 30, 21, WOOD)
        disk(img, 6, 4, 3, STONE[1]); disk(img, 5, 3, 1, STONE[2])
    rect(img, 30, 18, 6, 6, STONE[0])                                                          # the counterweight
    return finish(img)


@item("g_lv21_dragonskull", G, "龍頭骨", "bone", 4, level=21)
def g_lv21_dragonskull(f):
    img = new(46, 26)
    disk(img, 14, 12, 11, BONE, 9); disk(img, 11, 9, 6, (250, 246, 232), 4)                 # the cranium
    for x in range(22, 44):                                                                     # the long snout
        top = 9 + (x - 22) // 6
        rect(img, x, top, 1, 22 - top, BONE if x % 5 else BONE_SHADE)
    disk(img, 16, 11, 3, INK, 4)                                                                # the eye socket
    rect(img, 38, 12, 2, 2, INK)
    for x in range(22, 44, 3):
        rect(img, x, 21, 2, 3, (250, 246, 232))                                                 # teeth
    for (x0, y0, x1, y1) in ((6, 6, 0, 0), (12, 3, 10, 0)):                                     # horns sweeping back
        line(img, x0, y0, x1, y1, BONE_SHADE); line(img, x0 + 1, y0, x1 + 1, y1, BONE_SHADE)
    rect(img, 2, 23, 42, 3, (120, 110, 90))                                                     # sunk in the ground
    return finish(img)


@item("g_lv21_gong", G, "大銅鑼", "furniture", 2, frames=2, level=21)
def g_lv21_gong(f):
    img = new(26, 30)
    rect(img, 2, 2, 2, 28, WOOD); rect(img, 22, 2, 2, 28, WOOD); rect(img, 1, 1, 24, 3, WOOD_LIGHT)
    line(img, 9, 4, 11, 7, (200, 190, 160)); line(img, 17, 4, 15, 7, (200, 190, 160))
    sway = 1 if f else 0
    disk(img, 13 + sway, 15, 8, (200, 150, 60)); ring(img, 13 + sway, 15, 6, (160, 110, 40))
    disk(img, 13 + sway, 15, 2, (240, 200, 110)); put(img, 10 + sway, 11, (255, 230, 150))
    if f:                                                                                       # it rings
        for k in (0, 1):
            put(img, 0, 12 + k * 6, (255, 230, 150)); put(img, 25, 13 + k * 6, (255, 230, 150))
    return finish(img)


@item("g_lv21_crystal", G, "偷來的水晶", "scene", 1, frames=2, level=21)
def g_lv21_crystal(f):
    img = new(16, 22)
    blob(img, 8, 19, 6, 2, STONE, R(2101))
    shine = [(90, 140, 220), (130, 180, 240), (200, 230, 255)]
    for (x, top, w) in ((7, 2, 3), (4, 9, 2), (11, 7, 2)):
        for y in range(top, 19):
            ww = min(w, 1 + (y - top) // 2)
            rect(img, x - ww // 2, y, ww + 1, 1, shine[1])
            put(img, x - ww // 2, y, shine[2])
    put(img, 7, 4 + f * 6, (255, 255, 255)); put(img, 12, 10 - f * 2, (255, 255, 255))      # a glimmer
    return finish(img, (30, 40, 70))


# ---- level 24 -----------------------------------------------------------------------------------------------------
@item("g_lv24_warhall", G, "大酋長戰殿", "building", 4, frames=2, fn="lv_crown", level=24)
def g_lv24_warhall(f):
    img = new(46, 44)
    rect(img, 4, 20, 38, 24, (130, 90, 56))                                                     # log walls
    for y in range(20, 44, 3):
        rect(img, 4, y, 38, 1, shade((130, 90, 56), 0.85))
    tri_roof(img, 23, 4, 22, 16, (110, 60, 40), shade((110, 60, 40), 1.2))
    for x in (4, 41):                                                                           # tusks on the corners
        line(img, x, 22, x + (-3 if x < 20 else 3), 14, BONE); line(img, x + 1, 22, x + (-2 if x < 20 else 4), 14, BONE)
    disk(img, 23, 12, 4, BONE); put(img, 22, 11, INK); put(img, 24, 11, INK)                   # a skull at the peak
    rect(img, 18, 30, 10, 14, (50, 32, 22)); rect(img, 19, 31, 8, 13, (240, 130 + 40 * f, 40))  # the great door, a fire within
    rect(img, 18, 30, 10, 1, GOLD)
    for wx in (8, 34):
        rect(img, wx, 26, 4, 4, (250, 210, 110) if f else (240, 190, 90))
    for x in (12, 32):                                                                          # banners by the door
        rect(img, x, 24, 3, 10, CLOTH_RED); put(img, x + 1, 27, GOLD)
    for k in range(3):                                                                          # smoke from the roof
        put(img, 33 + (k + f) % 2, 6 - k * 2, (190, 190, 190, 200))
    return finish(img)


@item("g_lv24_hoard", G, "金山寶庫", "scene", 4, frames=2, level=24)
def g_lv24_hoard(f):
    img = new(40, 32)
    for y in range(6, 32):                                                                       # a mountain of gold
        half = 3 + (y - 6) * 17 // 26
        rect(img, 20 - half, y, 2 * half, 1, GOLD if (y + half) % 3 else GOLD_DARK)
        put(img, 20 - half, y, GOLD_LIGHT)
    for (x, y) in ((16, 14), (23, 17), (12, 24), (28, 25), (19, 21), (22, 28)):
        rect(img, x, y, 2, 1, GOLD_LIGHT)
    rect(img, 2, 22, 10, 9, (130, 80, 40)); rect(img, 2, 22, 10, 2, (160, 100, 50))           # a chest spilling out
    rect(img, 2, 25, 10, 1, GOLD); rect(img, 6, 24, 2, 3, GOLD_LIGHT)
    rect(img, 29, 9, 2, 13, G_IRON[2]); rect(img, 29, 9, 1, 13, (230, 230, 240))                # a sword stuck in it
    rect(img, 27, 21, 6, 1, GOLD_DARK); rect(img, 29, 22, 2, 3, WOOD_DARK)
    rect(img, 17, 2, 7, 3, GOLD); rect(img, 17, 4, 7, 1, GOLD_DARK)                            # a crown on top
    for x in (17, 20, 23):
        put(img, x, 1, GOLD); put(img, x, 0, GOLD_LIGHT)
    put(img, 20, 3, (200, 40, 50))
    rect(img, 30, 28, 4, 3, (90, 200, 160)); rect(img, 8, 29, 3, 2, (200, 80, 200))           # spilled gems
    put(img, 12 + f * 14, 12 + f * 5, (255, 255, 230)); put(img, 24 - f * 10, 26, (255, 255, 230))  # glints
    return finish(img)


@item("g_lv24_idol", G, "巨型哥布林像", "building", 4, level=24)
def g_lv24_idol(f):
    img = new(32, 52)
    rect(img, 3, 44, 26, 8, STONE[0]); rect(img, 3, 44, 26, 2, STONE[2])                      # the plinth
    rect(img, 10, 22, 12, 22, STONE[1]); rect(img, 10, 22, 3, 22, STONE[2])                   # the body
    rect(img, 6, 24, 4, 12, STONE[1]); rect(img, 22, 24, 4, 12, STONE[1])                      # arms
    rect(img, 23, 10, 2, 26, WOOD_DARK); rect(img, 21, 8, 6, 4, G_IRON[1])                       # a stone club raised
    disk(img, 16, 14, 7, STONE[1], 6); disk(img, 14, 12, 3, STONE[2])                          # the head
    for (x, d) in ((8, -1), (24, 1)):                                                            # long ears
        line(img, x, 13, x + 5 * d, 9, STONE[1]); line(img, x, 14, x + 5 * d, 10, STONE[0])
    put(img, 13, 14, (90, 220, 120)); put(img, 19, 14, (90, 220, 120))                           # emerald eyes
    rect(img, 13, 17, 7, 1, STONE[0]); put(img, 14, 18, (250, 250, 240)); put(img, 18, 18, (250, 250, 240))  # a toothy grin
    rect(img, 13, 46, 6, 2, GOLD)                                                                # a name plate
    return finish(img, (40, 40, 48))


@item("g_lv24_firedrake", G, "馴服小火龍", "creature", 2, frames=2, blocks=False, level=24)
def g_lv24_firedrake(f):
    img = new(30, 24)
    scale = [(170, 60, 40), (210, 90, 50), (240, 140, 70)]
    blob(img, 14, 15, 7, 4, scale, R(2401))
    for x in range(3, 9):                                                                         # the tail
        put(img, x, 16 + (x % 2), scale[1])
    put(img, 2, 15, (240, 200, 60))
    wy = 5 if f else 9                                                                            # the wings flap
    line(img, 12, 12, 7, wy, scale[0]); line(img, 7, wy, 14, 11, scale[0]); line(img, 9, wy + 1, 12, 11, scale[2])
    rect(img, 20, 9, 6, 4, scale[1]); put(img, 22, 10, (250, 230, 80)); put(img, 21, 8, scale[0])  # the head
    if f:
        rect(img, 26, 10, 3, 2, (255, 180, 40)); put(img, 29, 10, (255, 230, 120))              # a puff of fire
    for x in (11, 17):
        rect(img, x, 19, 2, 3, scale[0])
    rect(img, 15, 13, 3, 1, (120, 80, 40))                                                         # a collar: it's ours
    return finish(img, (60, 24, 18))


@item("g_lv24_portal", G, "異界傳送門", "scene", 2, frames=2, level=24)
def g_lv24_portal(f):
    img = new(26, 36)
    rect(img, 1, 32, 24, 4, STONE[0]); rect(img, 1, 32, 24, 1, STONE[2])
    for y in range(4, 33):                                                                         # the stone ring
        half = int(10 * math.sqrt(max(0, 1 - ((y - 18) / 15) ** 2)))
        rect(img, 13 - half - 2, y, 3, 1, STONE[1]); rect(img, 13 + half, y, 3, 1, STONE[0])
        swirl = [(120, 60, 180), (170, 90, 220), (220, 160, 255)]
        for x in range(13 - half + 1, 13 + half):
            put(img, x, y, swirl[(x + y + f * 2) % 3])
    for (x, y) in ((6, 10), (19, 12), (8, 26), (18, 24)):
        put(img, x, y, (255, 230, 255))                                                            # runes
    return finish(img, (40, 30, 50))
