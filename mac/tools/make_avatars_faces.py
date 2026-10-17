"""The avatar maker's second batch of looks (GUILD.md §2, 2026-10-17: 「捏臉選項：髮型、五官、臉型的選擇還不多」): six more
hairstyles for each race and sex, four more eyes, two more brows, three more mouths (and three more for the skull), two more
skins for each race, and two more face shapes. make_avatars.py calls register() with its own namespace, so these draw with
the same rig, helpers and palettes, and land in the same strips and manifest; the option lists shared/src/guild.ts and the
Mac's AvatarKit offer must match (a new id there needs its art here)."""


def register(g):
    C, heads = g["C"], g["heads"]
    short_front, side_cap, back_cap, bangs_front = g["short_front"], g["side_cap"], g["back_cap"], g["bangs_front"]
    braid, sides, behind_side, down_back = g["braid"], g["sides"], g["behind_side"], g["down_back"]
    long_style, ponytail, bob, bun_top, simple = g["long_style"], g["ponytail"], g["bob"], g["bun_top"], g["simple"]
    tone = g["tone"]

    # --- face shapes (rows of the 12-row head: x0, x1; the rest are 6…17) ------------------------------------------------
    g["FACES"].update({
        "heart": {0: (7, 16), 9: (7, 16), 10: (8, 15), 11: (10, 13)},                       # wide brow, small chin
        "chubby": {0: (8, 15), 1: (7, 16), 6: (5, 18), 7: (5, 18), 8: (5, 18), 11: (7, 16)},  # round cheeks
    })

    # --- skins (three tones each: shadow, base, highlight) -------------------------------------------------------------
    S = g["SKINS"]
    S["goblin"].update(olive=tone((156, 176, 84)), teal=tone((78, 160, 128)))
    S["elf"].update(rosy=tone((248, 216, 210), (226, 180, 176), (255, 236, 232)), umber=tone((148, 102, 74)))
    S["bone"].update(moss_bone=tone((200, 208, 172)), dusk=tone((128, 122, 140)))
    S["spirit"].update(pale_green=tone((222, 248, 232)), rose=tone((250, 228, 240)))

    # --- hairstyles ------------------------------------------------------------------------------------------------------
    def blob(c, cx, cy, rx, ry, keep=lambda x, yy: True):
        """A puffy mass of hair: an ellipse with a bumpy edge, shaded at the bottom, lit at the top left."""
        for yy in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(0, 24):
                d = ((x - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
                if d <= 1 + (0.18 if (x + yy) % 3 == 0 else 0) and keep(x, yy):
                    c.put(x, yy, "J" if yy - cy > ry * 0.6 or (x - cx) > rx * 0.75 else ("h" if d < 0.45 and x < cx and yy < cy else "H"))

    def curls(c, cx, cy, rx, ry):
        """Little dark curls all over a puff, so it reads as a big round head of curls rather than a cap."""
        for yy in range(int(cy - ry) + 1, int(cy + ry)):
            for x in range(int(cx - rx) + 1, int(cx + rx)):
                if (x * 3 + yy * 5) % 7 == 0 and c.px[yy][x] == "H":
                    c.put(x, yy, "J")

    def afro(view, layer, c, y):
        # (the hairline is curved: round over the brow, down to the cheeks at the sides)
        line = lambda x: y + 4 + (0 if 9 <= x <= 14 else 1 if 7 <= x <= 16 else 4)
        if view == "front":
            if layer == "back":
                blob(c, 11.5, y + 5, 10, 8)
            else:
                blob(c, 11.5, y + 5, 10, 8, lambda x, yy: yy <= line(x))
            curls(c, 11.5, y + 5, 10, 8)
        elif view == "side":
            if layer == "back":
                blob(c, 9.5, y + 5, 9.5, 8)
            else:
                blob(c, 9.5, y + 5, 9.5, 8, lambda x, yy: (yy <= y + 4 and x <= 16) or (x <= 9 and yy <= y + 10))
            curls(c, 9.5, y + 5, 9.5, 8)
        elif layer == "front":
            blob(c, 11.5, y + 5, 10, 8)
            curls(c, 11.5, y + 5, 10, 8)

    def two_buns(view, c, y):
        """Two round buns on the sides of the crown, each with a little ribbon under it."""
        for x0 in ((4, 16) if view != "side" else (5,)):
            c.rect(x0 + 1, y, x0 + 2, y, "H"); c.rect(x0, y + 1, x0 + 3, y + 2, "H"); c.rect(x0 + 1, y + 3, x0 + 2, y + 3, "J")
            c.cells([(x0 + 3, y + 2), (x0 + 3, y + 1)], "J"); c.put(x0 + 1, y + 1, "h")
            c.put(x0 + (2 if x0 < 12 else 1), y + 4, "k")

    def twin_buns(view, layer, c, y):
        if layer != "front":
            return
        (bangs_front if view == "front" else (lambda c, y: side_cap(c, y, 9)) if view == "side" else (lambda c, y: back_cap(c, y, 11)))(c, y)
        two_buns(view, c, y)

    def long_braid(view, layer, c, y):
        if view == "front":
            if layer == "front":
                bangs_front(c, y)
                braid(c, 5, 6, y + 8, y + 17, "A")                     # over the shoulder
        elif view == "side":
            if layer == "back":
                braid(c, 4, 5, y + 9, y + 18, "A")
            else:
                side_cap(c, y, 9)
        elif layer == "front":
            back_cap(c, y, 11)
            braid(c, 11, 12, y + 12, y + 19, "A")

    def ragged(c, pts):
        c.cells(pts, "H")

    def shaggy(view, c, y):
        if view == "front":
            short_front(c, y, False)
            ragged(c, [(5, y + 5), (5, y + 6), (5, y + 8), (18, y + 5), (18, y + 7), (18, y + 8), (7, y + 1), (10, y + 1),
                       (13, y + 1), (16, y + 2), (9, y + 7), (14, y + 7), (6, y + 9), (17, y + 9)])
            c.cells([(5, y + 8), (18, y + 8)], "J")
        elif view == "side":
            side_cap(c, y, 11)
            ragged(c, [(5, y + 6), (5, y + 8), (5, y + 10), (8, y + 1), (11, y + 1), (14, y + 1), (17, y + 7), (16, y + 7)])
        else:
            back_cap(c, y, 13)
            ragged(c, [(5, y + 6), (5, y + 9), (18, y + 7), (18, y + 10), (8, y + 14), (11, y + 15), (14, y + 14)])

    def bowl(view, c, y):
        if view == "front":
            c.rect(8, y + 1, 15, y + 1, "H"); c.rect(6, y + 2, 17, y + 5, "H"); c.rect(5, y + 6, 18, y + 6, "J")
            c.rect(5, y + 3, 5, y + 9, "H"); c.rect(18, y + 3, 18, y + 9, "H"); c.cells([(5, y + 9), (18, y + 9)], "J")
            c.cells([(8, y + 2), (9, y + 2), (7, y + 3)], "h")
        elif view == "side":
            side_cap(c, y, 10)
            c.rect(6, y + 1, 15, y + 1, "H"); c.rect(14, y + 2, 17, y + 5, "H"); c.rect(14, y + 6, 17, y + 6, "J")
            c.cells([(8, y + 2), (9, y + 2)], "h")
        else:
            c.rect(8, y + 1, 15, y + 1, "H"); c.rect(5, y + 2, 18, y + 10, "H"); c.rect(5, y + 11, 18, y + 11, "J")
            c.cells([(8, y + 2), (9, y + 2), (7, y + 3)], "h")

    def side_shave(view, c, y):
        if view == "front":
            c.rect(7, y + 1, 13, y + 1, "H"); c.rect(6, y + 2, 15, y + 3, "H"); c.rect(6, y + 4, 12, y + 5, "H")
            c.rect(6, y + 6, 8, y + 7, "H"); c.cells([(13, y + 4), (14, y + 4)], "J")
            c.cells([(8, y + 2), (9, y + 2), (7, y + 3)], "h")
            c.cells([(15, y + 5), (17, y + 5), (16, y + 6), (17, y + 7)], "J")         # the shaved side
        elif view == "side":
            c.rect(7, y + 0, 15, y + 1, "H"); c.rect(6, y + 2, 17, y + 3, "H"); c.rect(16, y + 4, 17, y + 4, "H")
            c.cells([(8, y + 0), (9, y + 0), (10, y + 1)], "h")
            c.cells([(7, y + 5), (9, y + 5), (8, y + 6), (7, y + 7), (9, y + 7), (11, y + 5)], "J")
        else:
            c.rect(8, y + 0, 15, y + 1, "H"); c.rect(9, y + 2, 14, y + 6, "H"); c.rect(9, y + 7, 14, y + 7, "J")
            c.cells([(7, y + 4), (16, y + 4), (7, y + 6), (16, y + 6), (8, y + 8), (15, y + 8)], "J")

    def short_crop(view, c, y):
        if view == "front":
            short_front(c, y, False)
            c.clear([(6, y + 8)])
        elif view == "side":
            side_cap(c, y, 8)
        else:
            back_cap(c, y, 10)

    def twin_braids(view, layer, c, y):
        if layer != "front":
            return
        if view == "front":
            short_front(c, y, False)
            braid(c, 4, 5, y + 7, y + 16); braid(c, 18, 19, y + 7, y + 16)
        elif view == "side":
            side_cap(c, y, 9)
            braid(c, 7, 8, y + 9, y + 17)
        else:
            back_cap(c, y, 11)
            braid(c, 7, 8, y + 11, y + 17); braid(c, 15, 16, y + 11, y + 17)

    def circlet(view, layer, c, y):
        long_style(view, layer, c, y, 18)
        if layer == "front":
            x0, x1 = (6, 17) if view != "side" else (7, 16)
            c.rect(x0, y + 4, x1, y + 4, "N")
            if view == "front":
                c.cells([(11, y + 4), (12, y + 4)], "f"); c.cells([(11, y + 3), (12, y + 3)], "a")
            elif view == "side":
                c.put(15, y + 4, "f")

    def hime(view, layer, c, y):
        if view == "front":
            if layer == "back":
                sides(c, y, 7, 18)
            else:
                c.rect(8, y + 2, 15, y + 2, "H"); c.rect(6, y + 3, 17, y + 6, "H"); c.rect(6, y + 7, 17, y + 7, "J")
                c.rect(5, y + 5, 6, y + 12, "H"); c.rect(17, y + 5, 18, y + 12, "H"); c.rect(5, y + 12, 6, y + 12, "J")
                c.rect(17, y + 12, 18, y + 12, "J")
                c.cells([(9, y + 3), (10, y + 3), (8, y + 4)], "h")
        elif view == "side":
            if layer == "back":
                behind_side(c, y, 18)
            else:
                side_cap(c, y, 10)
                c.rect(14, y + 3, 17, y + 6, "H"); c.rect(14, y + 7, 17, y + 7, "J"); c.rect(13, y + 6, 13, y + 12, "H")
                c.put(13, y + 12, "J")
        elif layer == "front":
            back_cap(c, y, 14); down_back(c, y, 18)

    def low_tail(view, layer, c, y):
        if view == "front":
            if layer == "front":
                short_front(c, y, False)
        elif view == "side":
            if layer == "back":
                c.rect(4, y + 10, 5, y + 10, "k"); c.rect(3, y + 11, 5, y + 18, "H"); c.rect(3, y + 11, 3, y + 18, "J")
                c.put(4, y + 19, "H")
            else:
                side_cap(c, y, 10)
        elif layer == "front":
            back_cap(c, y, 12)
            c.rect(10, y + 12, 13, y + 12, "k"); c.rect(10, y + 13, 13, y + 19, "H"); c.rect(13, y + 13, 13, y + 19, "J")
            c.rect(11, y + 20, 12, y + 20, "H"); c.put(10, y + 14, "h")

    def pixie(view, c, y):
        if view == "front":
            c.rect(8, y + 2, 15, y + 2, "H"); c.rect(7, y + 3, 16, y + 4, "H"); c.rect(6, y + 5, 11, y + 5, "H")
            c.cells([(6, y + 6), (7, y + 6), (8, y + 6), (7, y + 7), (16, y + 5), (17, y + 5), (17, y + 6)], "H")
            c.cells([(12, y + 4), (13, y + 5)], "J"); c.cells([(9, y + 3), (10, y + 3)], "h")
        elif view == "side":
            side_cap(c, y, 8)
            c.cells([(16, y + 6), (17, y + 7)], "H")
        else:
            back_cap(c, y, 9)
            c.cells([(8, y + 10), (11, y + 10), (14, y + 10)], "H")

    def flower_bun(view, c, y):
        if view == "front":
            short_front(c, y, False)
        elif view == "side":
            side_cap(c, y, 9)
        else:
            back_cap(c, y, 11)
        bun_top(view, c, y)
        if view == "side":
            c.cells([(8, y - 1), (11, y + 1)], "k"); c.put(10, y - 2, "A")
        else:
            c.cells([(10, y - 1), (13, y + 1)], "k"); c.put(12, y - 2, "A")

    # what is on a skull (fixed colours: bone W w, iron n N, moss l, soul f Z)
    def antlers(view, c, y):
        def one(x, lean):
            for i, yy in enumerate(range(y + 2, y - 5, -1)):
                c.put(x + (lean * (i // 3)), yy, "W" if i % 2 else "w")
            c.cells([(x + lean * 2 + lean, y - 1), (x + lean * 2 + 2 * lean, y - 2), (x - lean, y - 2), (x - lean, y - 3)], "W")
        if view == "side":
            one(9, -1)
            return
        one(8, -1); one(15, 1)

    def unicorn_horn(view, c, y):
        x = 13 if view == "side" else 11
        for i, yy in enumerate(range(y + 2, y - 5, -1)):
            w = 1 if i > 3 else 2
            c.rect(x + (i // 4 if view == "side" else 0), yy, x + (i // 4 if view == "side" else 0) + w - 1, yy, "w" if i % 2 else "W")
        c.put(x + (1 if view == "side" else 0), y - 5, "a")

    def bone_ridge(view, c, y):
        """Separate horn-like spikes of bone down the middle of the skull, each two wide at the base and shaded on one side."""
        def spike(x, h):
            c.rect(x, y + 3 - h, x, y + 2, "W"); c.rect(x + 1, y + 4 - h, x + 1, y + 2, "w")
        if view == "side":
            for x, h in ((6, 2), (9, 4), (12, 3), (15, 2)):
                spike(x, h)
        else:
            spike(11, 5)
            for x, h in ((8, 2), (14, 2)):
                spike(x, h)

    def soul_flame(view, c, y):
        x = 10 if view == "side" else 11
        shape = [(0, 2, 3), (-1, 2, 4), (-2, 1, 4), (-3, 1, 3), (-4, 2, 3), (-5, 2, 2)]
        for dy, a, b in shape:
            c.rect(x - 2 + a, y + 2 + dy, x - 2 + b, y + 2 + dy, "f")
        c.cells([(x, y), (x, y + 1), (x + 1, y + 1)], "Z")

    def iron_circlet(view, c, y):
        x0, x1 = (7, 16) if view == "side" else (6, 17)
        c.rect(x0, y + 5, x1, y + 5, "n"); c.rect(x0, y + 4, x1, y + 4, "N")
        for x in range(x0 + 1, x1, 3):
            c.put(x, y + 5, "N")
        if view == "front":
            c.cells([(11, y + 3), (12, y + 3)], "n"); c.cells([(11, y + 2), (12, y + 2)], "F")

    def mossy(view, c, y):
        pts = [(8, y + 2), (9, y + 2), (10, y + 2), (13, y + 2), (14, y + 2), (7, y + 3), (8, y + 3), (14, y + 3), (15, y + 3),
               (16, y + 4), (7, y + 4), (11, y + 1), (12, y + 2)]
        if view == "side":
            pts = [(8, y + 2), (9, y + 2), (10, y + 1), (11, y + 2), (13, y + 2), (7, y + 3), (6, y + 4), (6, y + 5), (6, y + 6),
                   (14, y + 3)]
        c.cells(pts, "l")
        c.cells([pts[0], pts[3]], "A")

    def veil(view, layer, c, y):
        if view == "front":
            if layer == "back":
                sides(c, y, 7, 16)
                c.rect(3, y + 5, 3, y + 17, "Z"); c.rect(20, y + 5, 20, y + 17, "Z")
            else:
                bangs_front(c, y)
                c.rect(8, y + 0, 15, y + 0, "Z"); c.rect(6, y + 1, 17, y + 2, "Z"); c.rect(5, y + 3, 5, y + 9, "Z")
                c.rect(18, y + 3, 18, y + 9, "Z"); c.cells([(7, y + 1), (16, y + 1)], "f")
        elif view == "side":
            if layer == "back":
                behind_side(c, y, 16)
                c.rect(3, y + 3, 4, y + 17, "Z")
            else:
                side_cap(c, y, 10)
                c.rect(6, y + 0, 15, y + 0, "Z"); c.rect(5, y + 1, 16, y + 2, "Z"); c.rect(5, y + 3, 5, y + 10, "Z")
        elif layer == "front":
            back_cap(c, y, 14); down_back(c, y, 16)
            c.rect(8, y + 0, 15, y + 0, "Z"); c.rect(5, y + 1, 18, y + 3, "Z")
            for yy in range(y + 4, y + 18, 2):
                c.cells([(5, yy), (18, yy), (9, yy + 1), (14, yy + 1)], "Z")

    def star_crown(view, layer, c, y):
        long_style(view, layer, c, y, 20, wavy=True, accent="f")
        if layer == "front":
            pts = [(8, y + 1), (11, y + 0), (12, y + 0), (15, y + 1)] if view != "side" else [(9, y + 0), (12, y + 0), (15, y + 1)]
            c.cells(pts, "R"); c.cells([(p[0], p[1] - 1) for p in pts[1:2]], "a")

    ST = g["STYLE"]
    goblin = {"afro": afro, "twin_buns": twin_buns, "long_braid": long_braid, "shaggy": simple(shaggy), "bowl": simple(bowl),
              "warrior_tail": lambda v, l, c, y: ponytail(v, l, c, y, cowlick=True), "side_shave": simple(side_shave)}
    elf = {"short_crop": simple(short_crop), "twin_braids": twin_braids, "circlet": circlet, "hime": hime, "low_tail": low_tail,
           "pixie": simple(pixie), "flower_bun": simple(flower_bun)}
    bone = {"antlers": simple(antlers), "unicorn_horn": simple(unicorn_horn), "bone_ridge": simple(bone_ridge),
            "soul_flame": simple(soul_flame), "iron_circlet": simple(iron_circlet), "mossy": simple(mossy)}
    spirit = {"veil": veil, "short_wisp": bob, "ponytail_wisp": ponytail, "star_crown": star_crown, "twin_buns": twin_buns, "hime": hime}
    for group, table in (("goblin", goblin), ("elf", elf), ("bone", bone), ("spirit", spirit)):
        for k, fn in table.items():
            ST[(group, k)] = fn
    H = g["HAIRS"]
    H["goblin_m"] += ["afro", "side_shave", "warrior_tail", "bowl", "shaggy", "long_braid"]
    H["goblin_f"] += ["twin_buns", "long_braid", "afro", "shaggy", "bowl", "warrior_tail"]
    H["elf_m"] += ["short_crop", "low_tail", "circlet", "pixie", "twin_braids", "flower_bun"]
    H["elf_f"] += ["hime", "flower_bun", "twin_braids", "circlet", "pixie", "low_tail"]
    H["undead_m"] += ["antlers", "unicorn_horn", "bone_ridge", "soul_flame", "iron_circlet", "mossy"]
    H["undead_f"] += ["veil", "short_wisp", "ponytail_wisp", "star_crown", "twin_buns", "hime"]

    # --- eyes ------------------------------------------------------------------------------------------------------------
    NEW_EYES = ["droopy", "cat_eye", "smiley", "big"]
    g["EYES"] += NEW_EYES
    eyes_was = g["eyes_layer"]
    SKULL_LIKE = {"droopy": "narrow", "cat_eye": "sharp", "big": "wide"}

    def eyes_layer(bt, style, fr):
        if style not in NEW_EYES:
            return eyes_was(bt, style, fr)
        if style == "smiley":                                              # always smiling, closed when blinking
            return eyes_was(bt, "round", dict(fr, eye="happy") if fr["eye"] == "open" else fr)
        if bt == "skeleton" or fr["eye"] != "open" or fr["view"] == "back":
            return eyes_was(bt, SKULL_LIKE[style] if bt == "skeleton" else "round", fr)
        c = C()
        _oy, _u, y = heads(fr)
        view = fr["view"]
        for x0, left in ([(8, True), (14, False)] if view == "front" else [(14, False)]):
            out = x0 - 1 if left else x0 + 2
            glint_x = x0 if view == "front" else x0 + 1
            if style == "droopy":
                c.rect(x0, y + 8, x0 + 1, y + 8, "L"); c.put(out, y + 9, "L")
                c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I"); c.put(glint_x, y + 9, "w")
            elif style == "cat_eye":
                c.rect(x0, y + 8, x0 + 1, y + 8, "L"); c.put(out, y + 7, "L"); c.put(out, y + 8, "L")
                c.rect(x0, y + 9, x0 + 1, y + 10, "i"); c.rect(x0 + (0 if left else 1), y + 9, x0 + (0 if left else 1), y + 10, "L")
            else:                                                          # big
                c.rect(x0, y + 7, x0 + 1, y + 7, "L"); c.put(out, y + 7, "L")
                c.rect(x0, y + 8, x0 + 1, y + 10, "i"); c.rect(x0, y + 10, x0 + 1, y + 10, "I")
                c.put(glint_x, y + 8, "w"); c.put(x0 + 1 if glint_x == x0 else x0, y + 9, "w")
        return c
    g["eyes_layer"] = eyes_layer

    # --- brows -----------------------------------------------------------------------------------------------------------
    NEW_BROWS = ["arched", "angry"]
    g["BROWS"][-1:-1] = NEW_BROWS                                          # (before "none", which stays last)
    brows_was = g["brows_layer"]

    def brows_layer(bt, style, fr):
        if style not in NEW_BROWS or fr["view"] == "back" or bt == "skeleton":
            return brows_was(bt, style, fr)
        c = C()
        _oy, _u, y = heads(fr)
        dy = -1 if fr["eye"] == "happy" else 0
        if fr["view"] == "front":
            if style == "arched":
                c.cells([(7, y + 7 + dy), (8, y + 6 + dy), (9, y + 6 + dy), (14, y + 6 + dy), (15, y + 6 + dy), (16, y + 7 + dy)], "J")
            else:
                c.cells([(7, y + 6 + dy), (8, y + 6 + dy), (9, y + 7 + dy), (14, y + 7 + dy), (15, y + 6 + dy), (16, y + 6 + dy)], "J")
        else:
            if style == "arched":
                c.cells([(14, y + 6 + dy), (15, y + 6 + dy), (16, y + 7 + dy)], "J")
            else:
                c.cells([(14, y + 7 + dy), (15, y + 6 + dy), (16, y + 6 + dy)], "J")
        return c
    g["brows_layer"] = brows_layer

    # --- mouths ----------------------------------------------------------------------------------------------------------
    NEW_MOUTHS = ["tongue", "toothy", "wavy"]
    NEW_SKULL = ["crooked", "buck", "toothless"]
    g["MOUTHS"] += NEW_MOUTHS
    g["SKULL_MOUTHS"] += NEW_SKULL
    mouth_was = g["mouth_layer"]

    def mouth_layer(bt, style, fr):
        view, state = fr["view"], fr["mouth"]
        if bt == "skeleton" and style in NEW_SKULL and view != "back":
            c = C()
            _oy, _u, y = heads(fr)
            if view == "front":
                if state == "open":
                    c.rect(10, y + 12, 13, y + 12, "d")
                if style == "toothless":
                    c.rect(10, y + 13, 13, y + 13, "d"); c.cells([(9, y + 13), (14, y + 13)], "S")
                else:
                    c.rect(9, y + 13, 14, y + 13, "S"); c.cells([(10, y + 13), (13, y + 13)], "s")
                    if style == "crooked":
                        c.put(12, y + 12, "s"); c.put(11, y + 13, "d")
                    else:
                        c.cells([(11, y + 14), (12, y + 14)], "s")
                if state == "happy":
                    c.cells([(8, y + 12), (15, y + 12)], "S")
            else:
                if state == "open":
                    c.rect(14, y + 12, 17, y + 12, "d")
                if style == "toothless":
                    c.rect(14, y + 13, 17, y + 13, "d")
                else:
                    c.rect(13, y + 13, 17, y + 13, "S"); c.put(15, y + 13, "s")
                    c.put(*((15, y + 12) if style == "crooked" else (17, y + 14)), "s")
            return c
        c = mouth_was(bt, style, fr)
        if style not in NEW_MOUTHS or view == "back" or state != "closed":
            return c
        _oy, _u, y = heads(fr)

        def put(pts, k):
            for x, yy in pts:
                if c.px[yy][x] != "t":                                     # (the goblins' tusks stay in front)
                    c.put(x, yy, k)
        if view == "front":
            if style == "tongue":
                put([(10, y + 12), (11, y + 12), (12, y + 12), (13, y + 12)], "m"); put([(12, y + 13)], "p")
            elif style == "toothy":
                put([(10, y + 12), (13, y + 12), (11, y + 13), (12, y + 13)], "m"); put([(11, y + 12), (12, y + 12)], "w")
            else:
                put([(10, y + 12), (11, y + 13), (12, y + 12), (13, y + 13)], "m")
        else:
            if style == "tongue":
                put([(16, y + 13)], "p")
            elif style == "toothy":
                put([(15, y + 12)], "w")
            else:
                put([(15, y + 13)], "m")
        return c
    g["mouth_layer"] = mouth_layer
