# The beastfolk's decorations a race level unlocks (DESKTOP.md §5.5): five every three levels, from 3 to 24, the later the
# grander. Run inside make_decor.py's namespace (its helpers and the beasts' B_… colours, bx_rock, bx_wolf, bx_wolfhead,
# bx_oxskull, bx_head, bx_hand, bx_boar, bx_flames…), so no imports. One a tier does something (fn "lv_…", Decor.swift);
# the other four are for looks. Rugged and wild (RACES_BEAST.md): red rock, hide, bone, meat and war paint.

B_MOON = [(226, 222, 200), (250, 244, 214), (255, 255, 240)]


def bx_lion(img, cx, cy, flip=1, frame=0):
    """A mountain lion side on, tawny, its long tail curling."""
    def r(x0, y0, w, h, c):
        rect(img, cx + x0 if flip > 0 else cx - x0 - w + 1, y0, w, h, c)
    r(-6, cy - 3, 11, 4, B_TAWNY[1]); r(-6, cy - 3, 11, 1, B_TAWNY[2])
    for lx in (-5, -3, 2, 4):
        r(lx, cy + 1, 1, 3, B_TAWNY[0])
    r(5, cy - 6 + frame, 4, 4, B_TAWNY[1]); r(8, cy - 4 + frame, 2, 2, (236, 220, 196))
    put(img, cx + 7 * flip, cy - 5 + frame, INK); put(img, cx + 5 * flip, cy - 7 + frame, B_TAWNY[1])
    for k in range(5):
        put(img, cx - (7 + k // 2) * flip, cy - 2 - k + (frame if k > 2 else 0), B_TAWNY[0])


# ---- level 3 ------------------------------------------------------------------------------------------------------
@item("b_lv3_sunrock", B, "曬背石", "furniture", 1, frames=2, fn="lv_rest", level=3)
def b_lv3_sunrock(f):
    img = new(22, 14)
    bx_rock(img, 11, 10, 9, 3, 501, strata=False)
    rect(img, 4, 6, 13, 2, B_TAWNY[1]); rect(img, 4, 6, 13, 1, B_TAWNY[2]); put(img, 3, 8, B_TAWNY[1]); put(img, 17, 8, B_TAWNY[1])  # a pelt on the warm rock
    finish(img, B_OUT)
    for k in range(3):                                                                         # the heat shimmering off it
        put(img, 6 + k * 4 + f, 3 - (k + f) % 2, (255, 236, 200, 150))
    return img


@item("b_lv3_bonechime", B, "骨風鈴", "sign", 1, frames=2, level=3)
def b_lv3_bonechime(f):
    img = new(16, 26)
    rect(img, 7, 2, 2, 24, B_BARK); rect(img, 7, 2, 1, 24, B_BARK_LIGHT)
    rect(img, 2, 4, 12, 1, B_BARK)
    for k, x in enumerate((3, 6, 10, 13)):                                                     # bones on cords, knocking in the wind
        sx = x + (f if k % 2 else -f)
        line(img, x, 5, sx, 8 + k % 2 * 2, (200, 180, 140))
        rect(img, sx, 9 + k % 2 * 2, 1, 5, BONE); put(img, sx - 1, 9 + k % 2 * 2, BONE); put(img, sx + 1, 13 + k % 2 * 2, BONE)
    return finish(img, B_OUT)


@item("b_lv3_sage", B, "山艾叢", "flower", 1, level=3)
def b_lv3_sage(f):
    img = new(18, 12)
    blob(img, 9, 7, 7, 4, B_SAGE, R(503))
    for (x, y) in ((4, 4), (9, 3), (13, 5), (7, 7)):
        put(img, x, y, (214, 196, 120))                                                        # little yellow flowers
    return finish(img, B_OUT)


@item("b_lv3_kindling", B, "柴薪堆", "scene", 1, level=3)
def b_lv3_kindling(f):
    img = new(20, 14)
    for k in range(7):                                                                         # a bundle of dry brush, tied
        line(img, 2 + k, 13 - k % 2, 13 + k, 4 + k % 3, B_BARK if k % 2 else B_BARK_LIGHT)
    rect(img, 8, 6, 2, 6, B_HIDE[0])
    rect(img, 15, 4, 1, 9, B_BARK); rect(img, 14, 2, 3, 3, B_ROCK[0]); put(img, 14, 2, B_ROCK[2])  # a stone axe stuck in
    return finish(img, B_OUT)


@item("b_lv3_hidepole", B, "曬皮竿", "scene", 2, frames=2, level=3)
def b_lv3_hidepole(f):
    img = new(30, 28)
    for x in (2, 26):
        rect(img, x, 4, 2, 24, B_BARK); put(img, x - 1, 4, B_BARK); put(img, x + 2, 4, B_BARK)
    rect(img, 1, 5, 28, 1, B_BARK_LIGHT)
    for (x, w, h, c) in ((5, 7, 12, B_HIDE), (13, 5, 9, B_FUR), (19, 6, 13, B_TAWNY)):        # hides drying, swaying
        for y in range(h):
            sx = x + (f if y > h // 2 else 0)
            rect(img, sx, 6 + y, w - (1 if y in (0, h - 1) else 0), 1, c[1] if y % 4 else c[2])
        put(img, x + (f), 6 + h, c[0])
    return finish(img, B_OUT)


# ---- level 6 ------------------------------------------------------------------------------------------------------
@item("b_lv6_grindstone", B, "磨骨石輪", "furniture", 2, frames=2, fn="lv_whet", level=6)
def b_lv6_grindstone(f):
    img = new(26, 22)
    rect(img, 3, 12, 2, 10, B_BARK); rect(img, 19, 12, 2, 10, B_BARK)
    disk(img, 12, 11, 7, B_ROCK[1]); disk(img, 11, 10, 5, B_ROCK[2]); disk(img, 12, 11, 2, B_ROCK[0])  # a red stone wheel
    for k in range(4):                                                                         # its grain turns
        a = k * math.pi / 2 + f * math.pi / 4
        put(img, round(12 + math.cos(a) * 5), round(11 + math.sin(a) * 5), B_ROCK[0])
    rect(img, 2, 11, 21, 1, B_BARK_LIGHT)
    line(img, 20, 11, 24, 7 + f * 6, B_BARK)                                                   # the crank
    rect(img, 6, 4, 9, 2, BONE); put(img, 5, 3, BONE); put(img, 15, 3, BONE)                  # a bone blade held to it
    rect(img, 2, 20, 20, 2, B_DUST[0])
    finish(img, B_OUT)
    put(img, 16 + f, 4 - f, (255, 236, 180)); put(img, 18, 6 + f, (255, 236, 180))           # dust flying
    return img


@item("b_lv6_axerack", B, "雙刃斧架", "furniture", 1, level=6)
def b_lv6_axerack(f):
    img = new(22, 28)
    rect(img, 2, 14, 18, 2, B_BARK); rect(img, 3, 14, 2, 14, B_BARK); rect(img, 17, 14, 2, 14, B_BARK)
    rect(img, 10, 1, 2, 27, B_BARK_LIGHT)                                                      # a minotaur's double axe
    for d in (-1, 1):                                                                          # two crescent blades
        for y in range(11):
            w = 2 + round(5 * math.sin(y / 10 * math.pi))
            x0 = 12 if d > 0 else 10 - w
            rect(img, x0, 1 + y, w, 1, B_ROCK[0])
            put(img, x0 + (w - 1 if d > 0 else 0), 1 + y, (210, 190, 170))                     # the edge
    rect(img, 9, 12, 4, 2, B_HIDE[0])
    return finish(img, B_OUT)


@item("b_lv6_boarpen", B, "野豬圈", "pen", 2, frames=2, level=6)
def b_lv6_boarpen(f):
    def boar(cx, cy, flip):
        def draw(img, frame):
            bx_boar(img, cx + (frame if flip > 0 else -frame), cy, flip)
        return draw
    img = pen(38, 22, BONE_SHADE, B_HIDE[1], [boar(10, 13, 1), boar(27, 12, -1)], f, ground=B_DUST[0])
    return finish(img, B_OUT)


@item("b_lv6_cairn", B, "指路石堆", "sign", 1, level=6)
def b_lv6_cairn(f):
    img = new(16, 24)
    for (y, rx) in ((20, 6), (15, 5), (11, 4), (7, 3)):                                        # stacked red stones
        disk(img, 8 + (y % 3) - 1, y, rx, B_ROCK[1], 2); rect(img, 8 - rx + (y % 3), y - 2, rx, 1, B_ROCK[2])
    bx_oxskull(img, 8, 2)
    rect(img, 12, 13, 1, 6, B_PAINT)                                                           # a smear pointing the way
    return finish(img, B_OUT)


@item("b_lv6_travois", B, "拖橇", "scene", 2, level=6)
def b_lv6_travois(f):
    img = new(32, 20)
    line(img, 2, 18, 28, 4, B_BARK); line(img, 4, 19, 30, 6, B_BARK)                          # two poles dragged behind
    line(img, 10, 14, 13, 17, B_BARK_LIGHT); line(img, 17, 11, 20, 14, B_BARK_LIGHT)
    rect(img, 8, 8, 12, 6, B_HIDE[1]); rect(img, 8, 8, 12, 1, B_HIDE[2])                       # a bundle of hides tied on
    rect(img, 14, 5, 6, 4, B_TAWNY[1]); put(img, 20, 6, B_TAWNY[1]); line(img, 19, 4, 21, 1, BONE_SHADE)  # a deer's head lolling over
    line(img, 11, 8, 13, 14, B_HIDE[0]); line(img, 17, 8, 15, 14, B_HIDE[0])
    return finish(img, B_OUT)


# ---- level 9 ------------------------------------------------------------------------------------------------------
@item("b_lv9_cubpit", B, "幼崽沙坑", "scene", 2, frames=2, fn="lv_nursery", level=9)
def b_lv9_cubpit(f):
    img = new(30, 18)
    disk(img, 15, 11, 13, B_DUST[0], 6); disk(img, 15, 11, 11, B_DUST[2], 4)                    # a soft sandy hollow
    for (x, y) in ((6, 10), (9, 13), (21, 9), (24, 12)):                                       # paw prints
        put(img, x, y, B_DUST[0]); put(img, x - 1, y - 1, B_DUST[0]); put(img, x + 1, y - 1, B_DUST[0])
    rect(img, 10, 9, 5, 1, BONE); put(img, 9, 8, BONE); put(img, 15, 10, BONE)                # a gnawed bone
    disk(img, 19 + f * 2, 11 - f, 2, B_HIDE[1]); put(img, 18 + f * 2, 10 - f, B_HIDE[2])      # a hide ball, batted about
    rect(img, 5, 7, 3, 2, B_FUR[1]); put(img, 4, 6, B_FUR[1])                                 # a pup's chewed tail toy
    return finish(img, B_OUT)


@item("b_lv9_bigsnag", B, "巨枯木", "tree", 4, frames=2, level=9)
def b_lv9_bigsnag(f):
    img = new(40, 46)
    for y in range(20, 46):                                                                    # a great dead trunk, split
        half = 3 + (y - 20) // 8 + (2 if y > 42 else 0)
        rect(img, 20 - half, y, 2 * half, 1, B_BARK); put(img, 20 - half, y, B_BARK_LIGHT)
        if y % 5 == 0:
            put(img, 20 + half - 2, y, shade(B_BARK, 0.8))
    for (x1, y1) in ((4, 8), (10, 2), (30, 4), (37, 12), (20, 0)):                              # bare limbs
        line(img, 20, 22, x1, y1, B_BARK); line(img, 21, 22, x1 + 1, y1, B_BARK)
        line(img, x1, y1, x1 + (3 if x1 < 20 else -3), y1 - 2, B_BARK)
    disk(img, 19, 30, 2, B_HOLE, 3)                                                             # a hollow
    rect(img, 30, 0 + f, 5, 4, (60, 46, 42)); rect(img, 31, -1 + f, 3, 2, (200, 120, 110))     # a vulture on top
    if f:
        line(img, 30, 2, 25, 0, (60, 46, 42)); line(img, 34, 2, 39, 0, (60, 46, 42))
    return finish(img, B_OUT)


@item("b_lv9_rockpile", B, "亂石堆", "scene", 1, level=9)
def b_lv9_rockpile(f):
    img = new(20, 14)
    for (x, y, rx, ry, k) in ((6, 9, 5, 3, 1), (14, 10, 5, 3, 2), (10, 5, 4, 3, 3)):
        bx_rock(img, x, y, rx, ry, 510 + k, strata=False)
    return finish(img, B_OUT)


@item("b_lv9_harecage", B, "野兔籠", "pen", 1, frames=2, level=9)
def b_lv9_harecage(f):
    img = new(18, 18)
    rect(img, 1, 3, 16, 2, B_BARK); rect(img, 1, 15, 16, 3, B_BARK)
    rect(img, 6 + f, 10, 5, 4, B_TAWNY[2]); put(img, 10 + f, 9, B_TAWNY[2]); put(img, 10 + f, 7 + f, B_TAWNY[2]); put(img, 11 + f, 7, B_TAWNY[2])  # a hare, ears up
    put(img, 10 + f, 11, INK)
    for x in range(2, 17, 3):
        rect(img, x, 5, 1, 10, BONE if x % 2 else B_BARK_LIGHT)
    return finish(img, B_OUT)


@item("b_lv9_fangstring", B, "獸牙串", "sign", 2, frames=2, level=9)
def b_lv9_fangstring(f):
    img = new(32, 26)
    for x in (2, 28):
        rect(img, x, 4, 2, 22, B_BARK); put(img, x, 3, BONE)
    for x in range(4, 28):                                                                     # a cord of fangs and claws, swaying
        y = 6 + round(5 * math.sin((x - 4) / 24 * math.pi)) + (f if 8 < x < 24 else 0)
        put(img, x, y, (200, 180, 140))
        if x % 3 == 0:
            rect(img, x, y + 1, 1, 3, BONE); put(img, x, y + 4, BONE_SHADE)
        if x % 6 == 2:
            put(img, x, y + 1, B_PAINT)
    return finish(img, B_OUT)


# ---- level 12 -----------------------------------------------------------------------------------------------------
@item("b_lv12_clawpost", B, "練爪木樁", "scene", 2, frames=2, fn="lv_might", level=12)
def b_lv12_clawpost(f):
    img = new(24, 34)
    rect(img, 8, 8, 8, 26, B_BARK); rect(img, 8, 8, 2, 26, B_BARK_LIGHT); rect(img, 14, 8, 2, 26, shade(B_BARK, 0.8))
    for y in (14, 24):
        rect(img, 7, y, 10, 2, B_HIDE[1])                                                      # hide wrapped round it
    for k in range(4):                                                                         # deep slashes
        line(img, 9 + k * 2, 17, 10 + k * 2, 23, B_HOLE)
    rect(img, 4, 10, 16, 2, B_BARK)                                                            # arms to swing at
    bx_oxskull(img, 12, 4)
    rect(img, 6, 31, 12, 3, B_DUST[0])
    finish(img, B_OUT)
    if f:
        for k in range(3):
            put(img, 19 + k, 18 + k * 2, (240, 230, 210)); put(img, 3 - k // 2, 20 + k, (240, 230, 210))  # splinters flying
    return img


@item("b_lv12_warhorn", B, "牛角號", "furniture", 1, level=12)
def b_lv12_warhorn(f):
    img = new(22, 18)
    rect(img, 4, 12, 2, 6, B_BARK); rect(img, 15, 12, 2, 6, B_BARK); rect(img, 3, 11, 15, 2, B_BARK_LIGHT)
    for i in range(16):                                                                        # a great curling horn on a stand
        x = 3 + i
        y = 9 - round(5 * math.sin(i / 15 * math.pi * 0.8))
        w = 1 + i // 5
        rect(img, x, y - w // 2, 1, w, (230, 214, 176) if i % 4 else (180, 150, 110))
    rect(img, 18, 2, 2, 6, (200, 180, 140))
    rect(img, 8, 6, 2, 3, B_HIDE[0])
    return finish(img, B_OUT)


@item("b_lv12_hidemap", B, "獸皮地圖架", "furniture", 2, level=12)
def b_lv12_hidemap(f):
    img = new(28, 22)
    rect(img, 3, 12, 2, 10, B_BARK); rect(img, 23, 12, 2, 10, B_BARK)
    bx_poly(img, [(2, 6), (26, 5), (27, 13), (1, 14)], B_HIDE[2])                              # a hide spread out on a stand
    line(img, 4, 11, 12, 8, B_PAINT); line(img, 12, 8, 20, 10, B_PAINT); line(img, 20, 10, 24, 7, B_PAINT)  # the hunt's way, in paint
    put(img, 6, 8, B_OCHRE[0]); put(img, 22, 11, B_OCHRE[0])
    bx_oxskull(img, 16, 8)
    rect(img, 10, 13, 2, 3, B_ROCK[0])                                                         # a stone holding it down
    return finish(img, B_OUT)


@item("b_lv12_minostatue", B, "牛頭人石像", "scene", 2, level=12)
def b_lv12_minostatue(f):
    img = new(26, 40)
    rect(img, 3, 33, 20, 7, B_ROCK[1]); rect(img, 3, 33, 20, 2, B_ROCK[2]); rect(img, 19, 33, 4, 7, B_ROCK[0])
    rect(img, 8, 24, 4, 9, B_SAND[1]); rect(img, 14, 24, 4, 9, B_SAND[0])
    rect(img, 5, 12, 16, 12, B_SAND[1]); rect(img, 5, 12, 4, 12, B_SAND[2]); rect(img, 17, 12, 4, 12, B_SAND[0])  # a great chest
    rect(img, 9, 4, 8, 9, B_SAND[1]); rect(img, 9, 4, 2, 9, B_SAND[2]); rect(img, 10, 10, 6, 3, B_SAND[2])  # the bull's head, its muzzle
    put(img, 11, 7, INK); put(img, 15, 7, INK); put(img, 11, 11, INK); put(img, 14, 11, INK)
    ring(img, 13, 13, 1, (200, 180, 90))                                                       # a nose ring
    for d in (-1, 1):                                                                          # the horns
        line(img, 13 + d * 4, 5, 13 + d * 8, 3, B_SAND[2]); line(img, 13 + d * 8, 3, 13 + d * 9, 0, B_SAND[2])
    rect(img, 2, 14, 3, 10, B_SAND[1]); rect(img, 21, 14, 3, 10, B_SAND[0])                    # arms
    rect(img, 23, 6, 2, 24, B_SAND[0]); bx_poly(img, [(24, 6), (20, 4), (20, 11), (24, 9)], B_SAND[2])  # its axe
    rect(img, 8, 16, 1, 5, B_OCHRE[1]); rect(img, 12, 16, 1, 5, B_OCHRE[1]); rect(img, 16, 16, 1, 5, B_OCHRE[1])
    return finish(img, B_OUT)


@item("b_lv12_stakes", B, "尖骨陣", "scene", 2, level=12)
def b_lv12_stakes(f):
    img = new(30, 20)
    for k, x in enumerate(range(3, 28, 4)):                                                    # sharpened bones angled outward
        h = 10 + (k % 3) * 3
        line(img, x, 19, x + 3, 19 - h, BONE); line(img, x + 1, 19, x + 4, 19 - h, BONE_SHADE)
    line(img, 1, 14, 29, 14, B_HIDE[0])
    put(img, 12, 6, B_BLOOD[0]); put(img, 13, 5, B_BLOOD[0]); put(img, 20, 8, B_BLOOD[1])     # blood on the points
    rect(img, 1, 18, 28, 2, B_DUST[0])
    return finish(img, B_OUT)


# ---- level 15 -----------------------------------------------------------------------------------------------------
@item("b_lv15_direwolf", B, "巨狼守衛", "creature", 2, frames=2, fn="lv_ward", blocks=False, level=15)
def b_lv15_direwolf(f):
    img = new(34, 26)
    fur = B_FUR
    rect(img, 7, 9, 16, 8, fur[1]); rect(img, 7, 9, 16, 2, fur[2]); rect(img, 7, 16, 16, 1, fur[0])  # a huge grey wolf, standing guard
    for (x, y) in ((9, 8), (12, 7), (15, 8), (18, 7)):
        put(img, x, y, fur[2])                                                                  # hackles up
    rect(img, 19, 6, 6, 12, fur[2]); rect(img, 19, 6, 6, 1, B_WHITE[1])                        # a thick ruff
    for (x, h) in ((8, 6), (11, 5), (19, 6), (22, 5)):
        rect(img, x, 17, 3, h - (f if x == 11 else 0), fur[0]); rect(img, x, 17 + h - 1, 4, 1, fur[0])
    for k in range(7):                                                                         # a bushy tail, low
        rect(img, 6 - k, 11 + k // 2, 2, 2, fur[1]); put(img, 6 - k, 13 + k // 2, fur[0])
    rect(img, 23, 7, 6, 5, fur[1]); rect(img, 23, 7, 6, 1, fur[2])                             # the head held low
    rect(img, 29, 9, 4, 3, B_WHITE[1]); put(img, 32, 9, INK)                                  # a long muzzle
    put(img, 23, 5, fur[1]); put(img, 23, 6, fur[1]); put(img, 24, 6, fur[1]); put(img, 26, 5, fur[1]); put(img, 26, 6, fur[1]); put(img, 27, 6, fur[1])  # pointed ears
    put(img, 27, 8, B_EYE)
    if f:                                                                                      # a snarl, fangs out
        rect(img, 29, 12, 4, 1, B_MEAT[0]); put(img, 30, 12, BONE); put(img, 32, 12, BONE)
    for (x, y) in ((10, 11), (14, 12)):
        line(img, x, y, x + 2, y + 2, B_PAINT)                                                 # war paint on its flank
    return finish(img, B_OUT)


@item("b_lv15_rocktower", B, "紅岩哨塔", "building", 4, frames=2, level=15)
def b_lv15_rocktower(f):
    img = new(36, 50)
    for y in range(14, 50):                                                                    # a red rock spire, banded
        half = 6 + (y - 14) // 5
        rect(img, 18 - half, y, 2 * half, 1, B_ROCK[2] if (y // 5) % 2 else B_ROCK[1])
        rect(img, 18 + half - 3, y, 3, 1, B_ROCK[0])
    for y in range(18, 48, 4):                                                                 # a ladder of poles up it
        rect(img, 10, y, 5, 1, B_BARK_LIGHT)
    rect(img, 10, 16, 1, 32, B_BARK); rect(img, 14, 16, 1, 32, B_BARK)
    rect(img, 6, 12, 24, 3, B_BARK); rect(img, 6, 12, 24, 1, B_BARK_LIGHT)                      # a platform on top
    for x in (7, 28):
        rect(img, x, 4, 1, 8, B_BARK)
    bx_poly(img, [(4, 5), (18, 1), (32, 5), (32, 6), (4, 6)], B_HIDE[1])                       # a hide awning
    rect(img, 16, 7, 4, 5, B_TAWNY[1]); put(img, 16, 6, B_TAWNY[1]); put(img, 19, 6, B_TAWNY[1])  # a red fox on the lookout
    put(img, 17 + f, 8, INK); put(img, 19, 9, (236, 220, 196))
    bx_oxskull(img, 18, 18)
    return finish(img, B_OUT)


@item("b_lv15_mammothskull", B, "猛獁頭骨", "bone", 2, level=15)
def b_lv15_mammothskull(f):
    img = new(34, 26)
    disk(img, 17, 10, 8, BONE, 8); rect(img, 13, 3, 8, 2, (250, 246, 232))                    # a great domed skull
    disk(img, 14, 10, 2, (70, 56, 44)); disk(img, 20, 10, 2, (70, 56, 44))
    rect(img, 15, 15, 5, 6, BONE_SHADE); put(img, 17, 19, (120, 110, 96))
    for d in (-1, 1):                                                                          # tusks sweeping out and up
        for i in range(16):
            a = i / 15 * math.pi * 0.8
            x = 17 + d * (3 + round(11 * math.sin(a)))
            y = 20 - round(14 * (1 - math.cos(a)) * 0.9)
            rect(img, x, y, 2, 2 if i < 12 else 1, (236, 226, 196) if d < 0 else BONE_SHADE)
    rect(img, 4, 22, 26, 3, B_DUST[0])
    return finish(img, B_OUT)


@item("b_lv15_bloodpot", B, "血酒鍋", "furniture", 2, frames=2, level=15)
def b_lv15_bloodpot(f):
    img = new(24, 22)
    for x in (3, 19):                                                                          # a stone pot slung over a fire
        line(img, x, 21, 12, 2, B_BARK)
    disk(img, 12, 13, 7, B_ROCK[0], 5); disk(img, 11, 12, 5, B_ROCK[1], 3)
    rect(img, 5, 8, 14, 2, B_ROCK[1]); rect(img, 6, 8, 12, 1, B_BLOOD[0])                      # dark red brew
    rect(img, 12, 2, 1, 7, (200, 180, 140))
    bx_flames(img, 12, 21, 3, f, 3)
    finish(img, B_OUT)
    for k in range(3):                                                                         # it bubbles
        put(img, 8 + k * 3 + f, 6 - (k + f) % 2, (180, 40, 40))
    return img


@item("b_lv15_banners", B, "戰旗陣", "sign", 2, frames=2, level=15)
def b_lv15_banners(f):
    img = new(30, 38)
    for k, (x, c) in enumerate(((3, B_HIDE), (13, B_FUR), (23, B_TAWNY))):
        rect(img, x, 6 + k % 2 * 3, 2, 32 - k % 2 * 3, B_BARK)
        if k == 1:
            bx_wolfhead(img, x + 1, 0, snarl=True)
        else:
            bx_oxskull(img, x + 1, 2 + k % 2 * 3)
        for y in range(10 + k % 2 * 2, 22 + k % 2 * 2):
            w = 6 - (y - 10) // 5
            rect(img, x + 2, y + (1 if (y + f + k) % 4 < 2 and y > 14 else 0), w, 1, c[1] if y % 3 else c[2])
        put(img, x + 4, 15 + k % 2 * 2, B_PAINT); put(img, x + 4, 16 + k % 2 * 2, B_PAINT)
    return finish(img, B_OUT)


# ---- level 18 -----------------------------------------------------------------------------------------------------
@item("b_lv18_wolfmother", B, "母狼神龕", "building", 2, frames=2, fn="lv_birth", level=18)
def b_lv18_wolfmother(f):
    img = new(28, 34)
    bx_rock(img, 14, 18, 13, 15, 520)
    disk(img, 14, 22, 8, B_HOLE, 9); rect(img, 6, 31, 17, 3, (0, 0, 0, 0)); rect(img, 3, 31, 22, 3, B_ROCK[0])  # a niche in the rock
    bx_wolf(img, 13, 30, "lie", fur=B_SAND)                                                    # a carved she-wolf, lying
    for x in (8, 20):                                                                          # her pups, curled at her side
        disk(img, x, 29, 2, B_SAND[1], 1); put(img, x + 1, 27, B_SAND[2])
    glow = B_MOON[2] if f else B_MOON[1]
    disk(img, 14, 6, 3, glow); put(img, 15, 5, B_MOON[0])                                      # the moon over her
    for x in (5, 23):                                                                          # tallow lamps
        rect(img, x, 28, 2, 3, B_FAT); put(img, x, 26 + f, B_FIRE[2]); put(img, x + 1, 27, B_FIRE[1])
    bx_hand(img, 3, 12, B_OCHRE[2]); bx_hand(img, 22, 10, B_OCHRE[2])
    return finish(img, B_OUT)


@item("b_lv18_furpile", B, "毛皮山", "furniture", 1, level=18)
def b_lv18_furpile(f):
    img = new(22, 16)
    for (y, rx, c, k) in ((12, 9, B_HIDE, 1), (9, 7, B_FUR, 2), (6, 6, B_TAWNY, 3), (3, 4, B_WHITE, 4)):  # pelts piled up
        blob(img, 11 + (k % 2), y, rx, 2, c, R(530 + k))
    put(img, 2, 13, B_HIDE[0]); put(img, 19, 10, B_FUR[0]); put(img, 17, 7, B_TAWNY[0])       # tails hanging out
    return finish(img, B_OUT)


@item("b_lv18_baobab", B, "猴麵包樹", "tree", 4, level=18)
def b_lv18_baobab(f):
    img = new(40, 44)
    for y in range(16, 44):                                                                    # a great swollen trunk
        half = 6 + round(3 * math.sin((y - 16) / 28 * math.pi)) + (2 if y > 40 else 0)
        rect(img, 20 - half, y, 2 * half, 1, (150, 120, 100)); rect(img, 20 - half, y, 3, 1, (180, 150, 128))
        rect(img, 20 + half - 3, y, 3, 1, (120, 94, 78))
    for (x1, y1) in ((6, 8), (12, 4), (20, 2), (28, 4), (34, 9)):                              # stubby branches like roots
        line(img, 20, 17, x1, y1, (150, 120, 100)); line(img, 20, 18, x1 + (1 if x1 < 20 else -1), y1 + 1, (130, 104, 86))
        blob(img, x1, y1, 3, 2, B_SAGE, R(540 + x1))
    for y in range(22, 40, 6):
        line(img, 17, y, 18, y + 3, (120, 94, 78))
    return finish(img, B_OUT)


@item("b_lv18_vulturestall", B, "禿鷹商攤", "building", 2, frames=2, level=18)
def b_lv18_vulturestall(f):
    img = new(30, 30)
    for x in (2, 26):
        rect(img, x, 8, 2, 22, B_BARK)
    bx_poly(img, [(0, 9), (15, 3), (29, 9), (29, 11), (0, 11)], B_HIDE[1])
    for x in range(1, 29, 4):
        rect(img, x, 11, 2, 2, B_PAINT if x % 8 == 1 else B_OCHRE[2])                         # a fringe
    rect(img, 4, 20, 22, 4, B_BARK_LIGHT); rect(img, 4, 24, 22, 6, B_BARK)                     # the counter, goods on it
    for (x, c) in ((6, BONE), (10, B_MEAT[1]), (15, (90, 170, 200)), (19, B_FUR[1]), (23, (220, 180, 60))):
        rect(img, x, 18, 3, 2, c)
    rect(img, 12, 12, 6, 6, (60, 46, 42)); rect(img, 13, 10 + f, 4, 3, (200, 120, 110)); put(img, 16, 11 + f, INK)  # the vulture trader
    rect(img, 12, 12, 6, 1, (236, 226, 210)); put(img, 17, 12 + f, (220, 200, 160))
    return finish(img, B_OUT)


@item("b_lv18_lioncage", B, "山獅籠", "pen", 2, frames=2, level=18)
def b_lv18_lioncage(f):
    img = new(32, 24)
    rect(img, 2, 3, 28, 2, B_BARK); rect(img, 2, 21, 28, 3, B_BARK)
    bx_lion(img, 15, 16, 1 if f == 0 else -1, f)
    for x in range(3, 30, 4):                                                                  # bars of lashed poles and bones
        rect(img, x, 4, 1, 18, B_BARK_LIGHT if x % 8 == 3 else BONE)
        put(img, x, 9, B_HIDE[0]); put(img, x, 16, B_HIDE[0])
    return finish(img, B_OUT)


# ---- level 21 -----------------------------------------------------------------------------------------------------
@item("b_lv21_snare", B, "套索陷阱", "scene", 2, frames=2, fn="lv_hold", blocks=False, level=21)
def b_lv21_snare(f):
    img = new(28, 30)
    rect(img, 4, 18, 2, 12, B_BARK)
    if f == 0:                                                                                 # a sapling bent down, a noose on the ground
        for i in range(18):
            put(img, 5 + i, 18 - round(14 * math.sin(i / 17 * math.pi * 0.5)) + i // 3, B_BARK_LIGHT)
        line(img, 22, 10, 20, 24, (200, 180, 140))
        ring(img, 18, 26, 4, (200, 180, 140), 1)
    else:                                                                                      # sprung: whipped up, the noose tight
        line(img, 5, 18, 8, 2, B_BARK_LIGHT); line(img, 6, 18, 9, 2, B_BARK_LIGHT)
        line(img, 8, 2, 14, 10, (200, 180, 140)); disk(img, 14, 12, 2, (200, 180, 140), 1)
    rect(img, 12, 27, 4, 1, B_BARK); rect(img, 22, 26, 2, 2, B_ROCK[1])
    return finish(img, B_OUT)


@item("b_lv21_longhouse", B, "獸骨長屋", "building", 4, frames=2, level=21)
def b_lv21_longhouse(f):
    img = new(50, 34)
    for y in range(10, 34):                                                                    # a long low house of hides on a bone frame
        half = 23 if y > 16 else int(23 * math.sqrt(max(0, 1 - ((17 - y) / 8) ** 2)))
        for x in range(-half, half):
            c = B_HIDE[1] if (x // 6) % 2 else shade(B_HIDE[1], 1.08)
            if x > half - 5:
                c = B_HIDE[0]
            put(img, 25 + x, y, c)
    for x in range(4, 47, 6):                                                                  # mammoth ribs arching over it
        for y in range(10, 34):
            if img.getpixel((x, y))[3]:
                put(img, x, y, BONE); put(img, x + 1, y, BONE_SHADE)
                break
        rect(img, x, 20, 1, 14, BONE_SHADE)
    for y in range(22, 34):                                                                    # a door at each end
        half = 2 + (y - 22) // 4
        rect(img, 12 - half, y, 2 * half + 1, 1, B_HOLE); rect(img, 37 - half, y, 2 * half + 1, 1, B_HOLE)
    for x in range(3, 47):
        put(img, x, 18 + (1 if (x + 40) % 4 < 2 else 0), B_PAINT)
    bx_oxskull(img, 25, 13)
    finish(img, B_OUT)
    for k in range(3):                                                                         # smoke from two holes
        put(img, 14 + (k + f) % 2, 7 - k * 3, (200, 196, 190, 170)); put(img, 36 - (k + f) % 2, 7 - k * 3, (200, 196, 190, 170))
    return img


@item("b_lv21_skullwall", B, "頭骨牆", "bone", 4, level=21)
def b_lv21_skullwall(f):
    img = new(44, 26)
    rect(img, 1, 18, 42, 8, B_ROCK[1]); rect(img, 1, 18, 42, 1, B_ROCK[2]); rect(img, 1, 25, 42, 1, B_ROCK[0])  # a low wall of red stones
    for x in range(2, 42, 6):
        put(img, x, 21, B_ROCK[0]); put(img, x + 3, 23, B_ROCK[0])
    for k, x in enumerate(range(5, 42, 7)):                                                    # skulls of every kind set along it
        if k % 2 == 0:
            bx_oxskull(img, x, 13)
        else:
            rect(img, x - 2, 11, 5, 5, BONE); rect(img, x - 1, 16, 3, 2, BONE_SHADE)
            put(img, x - 1, 13, INK); put(img, x + 1, 13, INK); put(img, x, 15, INK)
    rect(img, 3, 7, 1, 11, B_BARK); rect(img, 40, 7, 1, 11, B_BARK)
    bx_head(img, 4, 0, B_HAIR[0]); bx_head(img, 41, 0, B_HAIR[2])                             # a head on a stake at each end
    put(img, 3, 9, B_BLOOD[0]); put(img, 40, 10, B_BLOOD[0])
    return finish(img, B_OUT)


@item("b_lv21_greatdrum", B, "大戰鼓", "furniture", 2, frames=2, level=21)
def b_lv21_greatdrum(f):
    img = new(30, 28)
    rect(img, 5, 10, 20, 16, B_BARK); rect(img, 5, 10, 4, 16, B_BARK_LIGHT); rect(img, 21, 10, 4, 16, shade(B_BARK, 0.8))
    for x in range(5, 25, 4):                                                                  # lashings
        line(img, x, 11, x + 3, 25, B_HIDE[2])
    for x in range(5, 25):
        put(img, x, 18 + (1 if x % 4 < 2 else 0), B_PAINT)
    disk(img, 15, 10, 10, B_HIDE[2], 3); disk(img, 13, 9, 5, shade(B_HIDE[2], 1.08), 1)
    bx_hand(img, 14, 7, B_PAINT)                                                               # a red hand on the hide
    for (x, d) in ((3, 1), (27, -1)):                                                          # two great thigh-bone beaters
        if f:
            line(img, x, 2, x + d * 6, 8, BONE)
        else:
            line(img, x, 0, x + d * 2, 7, BONE)
    rect(img, 7, 26, 2, 2, B_BARK); rect(img, 21, 26, 2, 2, B_BARK)
    return finish(img, B_OUT)


@item("b_lv21_amber", B, "琥珀", "scene", 1, frames=2, level=21)
def b_lv21_amber(f):
    img = new(18, 18)
    bx_rock(img, 9, 14, 7, 3, 550, strata=False)
    for (x, h, w) in ((6, 9, 3), (11, 12, 3), (14, 6, 2)):                                     # a lump of amber, a beetle caught in it
        for y in range(h):
            half = max(0, min(w // 2 + 1, (h - y + 1) // 2))
            rect(img, x - half, 13 - y, 2 * half + 1, 1, (220, 140, 40) if (x + y) % 3 else (250, 190, 70))
    put(img, 11, 8, (60, 30, 20)); put(img, 10, 9, (60, 30, 20))
    put(img, 5 + f * 6, 4 + f * 2, (255, 240, 200))
    return finish(img, B_OUT)


# ---- level 24 -----------------------------------------------------------------------------------------------------
@item("b_lv24_moonhall", B, "月狼王殿", "building", 4, frames=2, fn="lv_crown", level=24)
def b_lv24_moonhall(f):
    img = new(50, 46)
    bx_rock(img, 25, 28, 23, 17, 560)                                                           # a great crag
    for (x, h) in ((8, 14), (42, 16)):                                                         # two red rock spires either side
        for y in range(h):
            rect(img, x - 3 + (y < 3), 46 - 18 - h + y, 6 - 2 * (y < 3), 1, B_ROCK[2] if (y // 4) % 2 else B_ROCK[1])
    for y in range(26, 46):                                                                    # its great door, a wolf's open jaws
        half = 4 + (y - 26) // 3
        rect(img, 25 - half, y, 2 * half + 1, 1, B_HOLE)
    for x in range(19, 32, 3):
        put(img, x, 26 + abs(x - 25) // 3, BONE); put(img, x, 27 + abs(x - 25) // 3, BONE)    # fangs over it
    bx_wolfhead(img, 25, 13, fur=B_WHITE, snarl=True)                                          # the white wolf king's head carved above
    for d in (-1, 1):
        line(img, 25 + d * 5, 13, 25 + d * 11, 5, BONE); line(img, 25 + d * 8, 9, 25 + d * 8, 5, BONE)  # antlers crowning it
    glow = B_MOON[2] if f else B_MOON[1]
    disk(img, 25, 4, 3, glow); put(img, 26, 3, B_MOON[0])                                      # the full moon on top
    bx_hand(img, 8, 32, B_OCHRE[2]); bx_hand(img, 38, 34, B_OCHRE[2])
    for x in (13, 36):                                                                         # fires at the door
        rect(img, x - 2, 43, 5, 3, B_ROCK[0]); bx_flames(img, x, 43, 4, f, 2)
    return finish(img, B_OUT)


@item("b_lv24_huntpile", B, "獵物山", "scene", 4, frames=2, level=24)
def b_lv24_huntpile(f):
    img = new(44, 28)
    blob(img, 22, 20, 19, 7, B_HIDE, R(570))                                                   # a heap of the hunt
    bx_boar(img, 12, 17, 1)
    disk(img, 28, 15, 6, B_TAWNY[1], 3); rect(img, 33, 12, 4, 3, B_TAWNY[1]); line(img, 34, 11, 36, 6, BONE_SHADE); line(img, 36, 11, 39, 7, BONE_SHADE)  # a stag
    for (x0, x1) in ((24, 22), (29, 31)):
        line(img, x0, 18, x1, 22, B_TAWNY[0])
    rect(img, 18, 10, 5, 4, B_FUR[2]); put(img, 18, 9, B_FUR[2])                               # a hare on top
    for (x, y) in ((6, 22), (36, 21), (22, 24)):
        rect(img, x, y, 4, 1, BONE)
    rect(img, 14, 23, 6, 1, B_BLOOD[1])
    finish(img, B_OUT)
    for k in range(4):                                                                         # flies
        put(img, 8 + k * 8 + f * 2, 4 + (k + f) % 2 * 3, (30, 24, 24))
    return img


@item("b_lv24_wolfidol", B, "巨狼石像", "building", 4, level=24)
def b_lv24_wolfidol(f):
    img = new(40, 50)
    rect(img, 4, 40, 32, 10, B_ROCK[1]); rect(img, 4, 40, 32, 2, B_ROCK[2]); rect(img, 30, 40, 6, 10, B_ROCK[0])  # a red plinth
    for x in range(6, 30, 5):
        bx_hand(img, x, 43, B_OCHRE[2] if x % 2 else B_PAINT)
    S = B_SAND
    bx_poly(img, [(5, 30), (35, 30), (37, 40), (3, 40)], S[1]); bx_poly(img, [(5, 30), (12, 30), (9, 40), (3, 40)], S[2])  # the ruff
    bx_poly(img, [(8, 16), (32, 16), (31, 27), (25, 35), (15, 35), (9, 27)], S[1])            # a great wolf's head, carved
    bx_poly(img, [(8, 16), (14, 16), (13, 30), (9, 27)], S[2]); bx_poly(img, [(28, 16), (32, 16), (31, 27), (27, 32)], S[0])
    for d in (-1, 1):                                                                          # tall ears
        bx_poly(img, [(20 + d * 12, 17), (20 + d * 11, 3), (20 + d * 5, 15)], S[1] if d < 0 else S[0])
        bx_poly(img, [(20 + d * 10, 14), (20 + d * 10, 8), (20 + d * 7, 14)], (130, 120, 112))
    bx_poly(img, [(16, 24), (24, 24), (23, 36), (17, 36)], S[2])                              # the muzzle
    rect(img, 18, 35, 4, 2, INK)
    rect(img, 16, 38, 8, 2, B_HOLE); put(img, 16, 38, BONE); put(img, 23, 38, BONE)          # the jaw, fangs bared
    for d in (-1, 1):                                                                          # eyes under a heavy brow, ochre in them
        line(img, 20 + d * 3, 21, 20 + d * 7, 19, INK); put(img, 20 + d * 5, 21, B_OCHRE[2]); put(img, 20 + d * 6, 21, B_OCHRE[2])
        line(img, 20 + d * 6, 25, 20 + d * 8, 29, B_PAINT); line(img, 20 + d * 4, 26, 20 + d * 6, 30, B_PAINT)  # war paint on the cheeks
    put(img, 12, 34, (90, 100, 70)); put(img, 30, 37, (90, 100, 70))                           # lichen
    return finish(img, B_OUT)


@item("b_lv24_moonwolf", B, "月狼", "creature", 2, frames=2, blocks=False, level=24)
def b_lv24_moonwolf(f):
    img = new(30, 30)
    fur = [(170, 186, 210), (210, 222, 240), (240, 246, 255)]
    bx_rock(img, 14, 26, 11, 3, 590, strata=False)                                             # on a red rock
    bx_wolf(img, 15, 24, "howl" if f else "sit", fur=fur)                                       # a pale wolf that came down with the moon
    finish(img, B_OUT)
    for k in range(5):                                                                         # moonlight round it
        a = k / 5 * 2 * math.pi + f * 0.6
        put(img, round(15 + math.cos(a) * 11), round(15 + math.sin(a) * 9), (220, 236, 255, 200))
    return img


@item("b_lv24_moonstone", B, "滿月石", "scene", 2, frames=2, level=24)
def b_lv24_moonstone(f):
    img = new(24, 26)
    bx_rock(img, 12, 22, 10, 3, 580, strata=False)
    disk(img, 12, 11, 8, B_MOON[1] if f else B_MOON[0])                                         # a great pale round stone on red rock
    disk(img, 9, 9, 2, (200, 196, 176)); disk(img, 15, 14, 1, (200, 196, 176)); put(img, 14, 7, (200, 196, 176))  # its seas
    put(img, 8, 6, (255, 255, 255))
    bx_hand(img, 4, 19, B_OCHRE[2])
    finish(img, B_OUT)
    if f:
        for (x, y) in ((2, 4), (21, 6), (12, 1)):
            put(img, x, y, (255, 250, 220))
    return img
