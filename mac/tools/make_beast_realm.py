#!/usr/bin/env python3
"""Draws the beastfolk's camp (岩壁獸穴, a den in the red rock, three growth stages) and their terrain, a dry red rock valley (RACES_BEAST.md §6),
in the style of tools/make_camps.py and tools/make_realms.py.

    python3 tools/make_beast_realm.py --preview /path/prefix   # writes prefix-camp.png and prefix-valley.png (sample scenes)
    python3 tools/make_beast_realm.py --write                  # writes Resources/Camps/den and Resources/Terrain/*-redrock

The valley scene is only a picture of what a beast camp would look like (red rock walls, a dry riverbed, the howling rock…);
the game lays out its own scenes once the terrain is wired in.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_camps as mc  # noqa: E402
import make_terrain as mt  # noqa: E402
import make_beast as mb  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

put, rect, outline, new = mt.put, mt.rect, mt.outline, mt.new

# --- the camp ------------------------------------------------------------------------------------------------------------
FUR_GREY = [(186, 188, 198), (150, 152, 164), (112, 114, 128), (84, 86, 98)]
OCHRE = [(214, 120, 70), (184, 92, 52), (150, 70, 40)]


def wolf_totem(g, x, base, height):
    """A carved pole: stacked bands of ochre and bark, a wolf's head on top with two ears, a pair of tusks hung below it."""
    g.solid(mc.rect(x - 1, base - height, x + 1, base), mc.BARK[1], mc.OUTLINE)
    for k, y in enumerate(range(base - height + 6, base - 1, 4)):
        g.solid(mc.rect(x - 1, y, x + 1, y + 1), OCHRE[k % 2], None)
    top = base - height
    g.paint(mc.rect(x - 3, top - 5, x + 3, top), FUR_GREY)
    g.solid({(x - 3, top - 7), (x - 3, top - 6), (x - 2, top - 6), (x + 3, top - 7), (x + 3, top - 6), (x + 2, top - 6)},
            FUR_GREY[1], mc.OUTLINE)
    g.put(x - 2, top - 3, (255, 214, 80)); g.put(x + 2, top - 3, (255, 214, 80))      # eyes
    g.solid(mc.rect(x - 1, top - 1, x + 1, top), (230, 230, 236), None)               # muzzle
    g.put(x, top - 1, mc.DARK)
    g.put(x - 4, top + 2, mc.BONE); g.put(x - 4, top + 3, mc.BONE)
    g.put(x + 4, top + 2, mc.BONE); g.put(x + 4, top + 3, mc.BONE)


ROCK = [(196, 122, 80), (166, 96, 64), (136, 74, 50), (104, 56, 40)]     # red rock, light to dark


def beast_skull(g, cx, y):
    """A great horned skull over the den's mouth: a broad bone face, dark sockets, horns curving out and up."""
    g.solid(mc.rect(cx - 3, y, cx + 3, y + 4) - {(cx - 3, y + 4), (cx + 3, y + 4)}, mc.BONE, mc.OUTLINE)
    g.solid(mc.rect(cx - 1, y + 5, cx + 1, y + 6), (214, 206, 186), mc.OUTLINE)       # the snout bone
    for dx in (-2, 2):
        g.put(cx + dx, y + 2, mc.DARK)
    g.put(cx, y + 5, mc.DARK)
    for side in (-1, 1):                                                               # the horns
        pts = [(cx + side * 4, y + 1), (cx + side * 5, y + 1), (cx + side * 6, y), (cx + side * 6, y - 1), (cx + side * 7, y - 2)]
        g.solid(set(pts), mc.BONE, mc.OUTLINE)


def bone_spikes(g, xs, base):
    for x in xs:
        g.solid({(x, base), (x, base - 1), (x, base - 2), (x, base - 3), (x + 1, base), (x + 1, base - 1), (x + 1, base - 2)},
                mc.BONE, mc.OUTLINE)
        g.put(x + 1, base - 2, (214, 206, 186))


def claw_marks(g, x, y):
    for k in range(3):                                                                 # three scratches, raked down
        for i in range(4):
            g.put(x + k * 2 + i // 2, y + i, ROCK[3])


def camp_den(s):
    """The beastfolk's camp: a den dug into a red rock outcrop, a horned skull over its mouth, claw marks raked into the rock,
    a fence of sharpened bones; bigger each stage, with a second den, a wolf totem and a campfire."""
    w, h = mc.SIZES[s]
    w, h = w + 14, h + 10
    g = mc.Grid(w, h)
    cx, base = w // 2 + 2, h - 3
    rx, ry = [12, 15, 18][s], [14, 18, 22][s]

    def crag(x, half, height):
        """An angular block of layered red rock: stepped shoulders, a flat top with a notch, a shaded right face."""
        top = base - height
        pts = [(x - half, base + 1), (x - half, top + height // 2), (x - half + 2, top + height // 3), (x - half + 3, top + 3),
               (x - 2, top + 1), (x - 1, top), (x + half // 2, top), (x + half // 2 + 1, top + 2), (x + half - 1, top + 3),
               (x + half, top + height // 2), (x + half, base + 1)]
        body = mc.poly(pts)
        g.paint(body, ROCK, dither=0.12)
        for y in range(top + 3, base, 4):                                              # the strata
            g.solid({(xx, y) for xx, yy in body if yy == y and (xx + y) % 9 != 0}, ROCK[0])
        g.solid({(xx, yy) for xx, yy in body if xx >= x + half - 3}, ROCK[3])            # its shaded side
    if s >= 2:                                                                         # a smaller crag beside it, with its own den
        crag(cx + rx + 4, 7, 12)
        g.solid(mc.ellipse(cx + rx + 3, base - 2, 2.5, 3.2, below=base), mc.HOLE, mc.OUTLINE)
    crag(cx, rx, ry)
    rim = mc.ellipse(cx, base - 3, 5 + s, 6 + s, below=base)
    mouth = mc.ellipse(cx, base - 3, 4 + s, 5 + s, below=base)
    g.solid(rim, ROCK[3])                                                              # the worn rim of the mouth
    g.solid(mouth, mc.HOLE, mc.OUTLINE)
    if s >= 1:
        beast_skull(g, cx, base - 14 - 2 * s)
        claw_marks(g, cx - rx + 4, base - ry + 7)
        bone_spikes(g, [cx - 9 - s, cx + 8 + s], base)
    if s >= 2:
        claw_marks(g, cx + 7, base - 10)
        wolf_totem(g, 3, base, 14)
        mc.campfire(g, 11, base)
    mc.crumbs(g, cx, base, rx + 2, 6 + 2 * s, ROCK)
    return g, (cx, base - 3)


# --- the red rock valley ----------------------------------------------------------------------------------------------
# Dry wild country (the user: 「獸人應該是住在比較乾燥的荒野谷地那種感覺」): a dusty valley floor between red rock walls,
# a cracked dry riverbed, sagebrush and dead trees, rock pillars, bleached skulls, and one waterhole the animals come to.
RV_OUT = (52, 30, 22)
RV_GROUND = [(200, 160, 112), (186, 146, 100), (212, 176, 128), (176, 132, 90)]
RV_GRASS = [(196, 172, 104), (170, 146, 84), (222, 200, 130)]
RV_ROCK = [(150, 84, 56), (186, 110, 72), (116, 62, 44)]          # mid, light, dark
RV_SAGE = [(112, 128, 96), (140, 156, 116), (88, 100, 76)]
RV_BARK = (110, 82, 60)


def rv_ground(rnd):
    img = Image.new("RGBA", (32, 32), RV_GROUND[0] + (255,))
    for _ in range(120):
        put(img, rnd.randrange(32), rnd.randrange(32), rnd.choice(RV_GROUND))
    for _ in range(4):                                                     # pebbles
        put(img, rnd.randrange(32), rnd.randrange(32), (150, 120, 96))
    for _ in range(5):                                                     # a few dry blades
        x, y = rnd.randrange(1, 31), rnd.randrange(1, 31)
        put(img, x, y, RV_GRASS[0]); put(img, x, y - 1, RV_GRASS[2])
    return img


def dry_grass(rnd):
    img = new(10, 10)
    for k in range(5):
        x = 1 + k * 2
        h = rnd.randint(4, 8)
        for i in range(h):
            put(img, x + (1 if i > h - 3 and k % 2 else 0), 9 - i, RV_GRASS[1] if i < 2 else RV_GRASS[0] if i < h - 2 else RV_GRASS[2])
    return img


def sagebrush(rnd, size=6):
    img = new(size * 2 + 6, size + 6)
    mt.blob(img, size + 3, size // 2 + 3, size, size // 2 + 1, [RV_SAGE[2], RV_SAGE[0], RV_SAGE[1]], rnd)
    for _ in range(3):
        put(img, rnd.randint(4, size * 2), rnd.randint(2, size // 2 + 3), (214, 196, 120))   # little yellow flowers
    outline(img, RV_OUT)
    return img


def dead_snag(rnd, height):
    img = new(height, height + 2)
    cx, base = height // 2, height
    x = cx
    for y in range(base, base - height * 2 // 3, -1):
        if y % 5 == 0:
            x += rnd.choice((0, 1, -1))
        rect(img, x - 1, y, 2, 1, RV_BARK)
    top = base - height * 2 // 3
    for side in (-1, 1):
        bx, by = x, top + 3
        for k in range(rnd.randint(4, 7)):
            bx += side; by -= k % 2
            put(img, bx, by, RV_BARK)
    outline(img, RV_OUT)
    return img


def boulder(rnd, size):
    img = new(size * 2 + 6, size + 6)
    mt.blob(img, size + 3, size // 2 + 3, size, size // 2 + 1, [RV_ROCK[2], RV_ROCK[0], RV_ROCK[1]], rnd)
    outline(img, RV_OUT)
    return img


BLOOD = [(150, 20, 24), (110, 12, 18)]


def rock_pillar(rnd, height, trophy=False):
    """A tall red rock stack, banded, with a flat cap — the valley's landmarks. A `trophy` pillar has a severed human head set
    on top and blood run down its side: a warning to whoever comes into the valley (the user: 「石柱可以是人頭有血」「真人頭」)."""
    w = 18
    top = 8 if trophy else 0
    img = new(w + 4, height + 2 + top)
    for y in range(height):
        half = 6 + (2 if y > height - 6 else 0) - (1 if y < 4 else 0)
        band = RV_ROCK[1] if (y // 5) % 2 == 0 else RV_ROCK[0]
        rect(img, w // 2 + 2 - half, y + 1 + top, half * 2, 1, band)
        rect(img, w // 2 + 2 + half - 3, y + 1 + top, 3, 1, RV_ROCK[2])   # the shaded side
    if trophy:
        cx = w // 2 + 2
        hair = rnd.choice([(96, 64, 40), (60, 44, 36), (200, 160, 90), (140, 70, 40)])
        rect(img, cx - 3, 1, 6, 6, (226, 186, 156)); rect(img, cx - 2, 7, 4, 1, (206, 164, 136))  # a human head
        rect(img, cx - 3, 0, 6, 2, hair); put(img, cx - 3, 2, hair); put(img, cx + 2, 2, hair)     # its hair
        rect(img, cx - 2, 3, 2, 1, (60, 40, 40)); rect(img, cx + 1, 3, 2, 1, (60, 40, 40))         # eyes shut
        rect(img, cx - 1, 5, 2, 1, (130, 60, 60))                                                  # the mouth slack
        put(img, cx + 2, 4, (196, 156, 130))                                                       # pale cheek shading
        rect(img, cx - 2, 7, 4, 1, BLOOD[0]); put(img, cx - 1, 6, BLOOD[0])                       # the cut neck
        put(img, cx - 3, 5, BLOOD[1])
        rect(img, cx - 6, top, 12, 1, BLOOD[1])                                                    # blood pooled on the cap
        for dx in (-5, -2, 1, 3):                                                                  # and run down the side
            for y in range(top, top + rnd.randint(5, height * 2 // 3)):
                put(img, cx + dx, y + 1, BLOOD[0] if y % 4 else BLOOD[1])
    outline(img, RV_OUT)
    return img


def howling_rock(rnd):
    """A red rock spur with a flat lip jutting out, where the wolves stand to howl at the full moon."""
    img = new(64, 48)
    d = ImageDraw.Draw(img)
    d.polygon([(6, 47), (10, 24), (18, 12), (52, 10), (56, 16), (44, 20), (50, 47)], fill=RV_ROCK[0] + (255,))
    d.polygon([(44, 20), (56, 16), (50, 47), (40, 47)], fill=RV_ROCK[2] + (255,))
    d.line([(18, 12), (52, 10)], fill=RV_ROCK[1] + (255,), width=2)
    for y in range(18, 46, 6):                                             # its layers
        d.line([(10, y), (42, y - 1)], fill=RV_ROCK[1] + (255,))
    outline(img, RV_OUT)
    return img


def skull(rnd):
    """A bleached ox skull with long horns, half in the dust."""
    img = new(16, 8)
    rect(img, 5, 2, 6, 4, (236, 228, 206)); rect(img, 6, 6, 4, 1, (210, 200, 176))
    put(img, 6, 3, (60, 44, 36)); put(img, 9, 3, (60, 44, 36))
    for k in range(4):
        put(img, 4 - k, 2 - (k > 1), (236, 228, 206)); put(img, 11 + k, 2 - (k > 1), (236, 228, 206))
    outline(img, RV_OUT)
    return img


def riverbed(scene, rnd):
    """A dry riverbed winding down the valley: cracked mud, pebbles along its banks."""
    d = ImageDraw.Draw(scene)
    x = 240
    for y in range(40, scene.height, 2):
        x += rnd.choice((-1, 0, 0, 1, 1))
        d.rectangle([x - 9, y, x + 9, y + 1], fill=(166, 128, 92))
        d.rectangle([x - 7, y, x + 7, y + 1], fill=(184, 150, 112))
        if y % 6 == 0:
            d.line([(x - 6 + rnd.randint(0, 4), y), (x + rnd.randint(0, 6), y + 1)], fill=(140, 104, 74))   # cracks
        if rnd.random() < 0.3:
            put(scene, x + rnd.choice((-10, 10)), y, (150, 130, 112))


def sprite_of(sheet, sx, sy, flip=False):
    img = Image.new("RGBA", (mb.SIZE, mb.SIZE))
    for y in range(mb.SIZE):
        for x in range(mb.SIZE):
            px = sheet[sy + y][sx + (mb.SIZE - 1 - x if flip else x)]
            if px[3]:
                img.putpixel((x, y), px)
    return img


def resident(i, view=0, phase=0, flip=False):
    b = mb.BREEDS[i]
    return sprite_of(mb.breed_sheet(b[7], b[8]), phase * mb.SIZE, view * mb.SIZE, flip)


def runner(i, phase, flip=False):
    _name, pal, draw = mb.FRENZY[i]
    return sprite_of(mb.frenzy_sheet(draw, pal), phase * mb.SIZE, 2 * mb.SIZE, flip)


def valley_scene(full_moon=False):
    rnd = random.Random(4)
    W, H = 320, 200
    scene = Image.new("RGBA", (W, H))
    from make_realms import tile, stand, nightfall, terrace, pond  # noqa: E402
    tile(scene, rv_ground(random.Random(3)))
    terrace(scene, rnd, 56, None, [RV_ROCK[0], RV_ROCK[2], (96, 50, 36)], RV_ROCK[1], steps_at=[])   # the valley wall
    for _ in range(140):                                                   # rubble fallen from the wall, scree everywhere
        x, y = rnd.randrange(W), rnd.randrange(64, H)
        if rnd.random() < 0.5 or y < 100:
            put(scene, x, y, rnd.choice([(150, 110, 84), (128, 92, 70), (170, 128, 96)]))
    riverbed(scene, random.Random(8))
    pond(scene, 214, 176, 16, 7, [(84, 128, 140), (120, 170, 176)], (150, 120, 90), rnd)              # the waterhole
    camp = camp_den(2)[0].image()
    camp = Image.frombytes("RGBA", (len(camp[0]), len(camp)), bytes(v for row in camp for px in row for v in px))
    items = [(camp, 150, 84), (howling_rock(rnd), 48, 116)]
    for x, h in [(20, 44), (300, 52), (226, 40), (96, 30)]:                # rock pillars rising from the wall
        items.append((rock_pillar(rnd, h), x, 58 + rnd.randint(-2, 2)))
    items += [(rock_pillar(rnd, 34, trophy=True), 296, 150), (rock_pillar(rnd, 26), 20, 196), (rock_pillar(rnd, 22), 270, 196)]
    items += [(rock_pillar(rnd, 20, trophy=True), 108, 92), (rock_pillar(rnd, 22, trophy=True), 226, 104)]   # flanking the den
    for x, y in [(110, 70), (280, 100), (30, 180)]:
        items.append((dead_snag(rnd, rnd.randint(18, 24)), x, y))
    for x, y in [(200, 120), (96, 172), (36, 160), (300, 120), (170, 192), (110, 104), (190, 98), (248, 170), (130, 150),
                 (62, 196), (220, 86)]:
        items.append((boulder(rnd, rnd.choice((3, 4, 6, 8))), x, y))
    for k in range(26):
        x, y = rnd.randint(6, W - 6), rnd.randint(70, H - 2)
        if abs(x - 150) < 34 and 60 < y < 100:
            continue
        items.append((sagebrush(rnd, rnd.choice((4, 5, 6))) if k % 3 == 0 else dry_grass(rnd), x, y))
    items += [(skull(rnd), 250, 140), (skull(rnd), 80, 190)]
    items.append((mt.drying_rack("meadow", rnd), 196, 102))
    if full_moon:
        items += [(runner(0, 0), 40, 78), (runner(0, 1), 58, 80), (runner(1, 2, flip=True), 120, 156),
                  (runner(0, 3, flip=True), 236, 130), (runner(2, 1), 180, 178), (runner(3, 0), 170, 100),
                  (runner(4, 1), 126, 100)]
    else:
        items += [(resident(0, 0, 0), 122, 100), (resident(1, 2, 1), 182, 140), (resident(2, 0, 0), 178, 96),
                  (resident(3, 0, 1), 104, 92), (resident(4, 0, 0), 150, 102), (resident(0, 2, 0, True), 220, 150)]
    for sprite, x, y in sorted(items, key=lambda t: t[2]):
        stand(scene, sprite, x, y)
    if full_moon:
        scene = nightfall(scene, (30, 30, 76), 0.45)
        light = Image.new("RGBA", scene.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(light)
        d.ellipse([4, 40, 96, 100], fill=(220, 230, 255, 40))              # moonlight on the howling rock
        d.ellipse([110, 70, 170, 110], fill=(255, 170, 80, 44))            # the fire before the den
        scene = Image.alpha_composite(scene, light)
        sky = ImageDraw.Draw(scene)
        sky.ellipse([284, 6, 308, 30], fill=(250, 246, 220, 255))          # the full moon over the valley wall
        sky.ellipse([290, 12, 296, 18], fill=(226, 222, 196, 255))
    return scene


def camp_preview(path, zoom=6):
    imgs = [camp_den(s)[0].image() for s in range(3)]
    cell_w = max(len(i[0]) for i in imgs) + 4
    cell_h = max(len(i) for i in imgs) + 2
    out = Image.new("RGBA", (cell_w * 3, cell_h), (196, 186, 150, 255))
    for k, img in enumerate(imgs):
        im = Image.frombytes("RGBA", (len(img[0]), len(img)), bytes(v for row in img for px in row for v in px))
        out.alpha_composite(im, (k * cell_w + 2, cell_h - len(img) - 1))
    out.resize((out.width * zoom, out.height * zoom), Image.NEAREST).save(path)


def register_palettes():
    """Teach tools/make_terrain.py the red rock valley's colours, so its rocks, logs, stumps, plots, racks… come out in them."""
    mt.OUTLINE.update(redrock=RV_OUT)
    mt.GROUND.update(redrock=RV_GROUND)
    mt.LEAF.update(redrock=[RV_SAGE[2], RV_SAGE[0], RV_SAGE[1]])
    mt.TRUNK.update(redrock=RV_BARK)
    mt.STONE.update(redrock=[RV_ROCK[0], RV_ROCK[1], RV_ROCK[2]])
    mt.HIDE.update(redrock=(176, 120, 80))
    mt.SOIL.update(redrock=[(150, 104, 70), (128, 86, 58), (172, 124, 86)])


def sprites():
    """Everything the red rock valley needs under its own name (the game looks sprites up as kind-biome[-n]): make_realms's
    full set in these colours, then the valley's own — dry snags for trees, sagebrush for bushes, boulders for rocks, rock
    pillars (some with a head and blood), ox skulls, the howling rock."""
    import make_realms as mr
    register_palettes()
    out = mr.full_set("redrock")
    rnd = random.Random(21)
    out["ground-redrock"] = rv_ground(random.Random(3))
    for i, hgt in enumerate((20, 24, 28)):
        out[f"tree-redrock-{i}"] = dead_snag(rnd, hgt)
    for v in (0, 1):
        out[f"young-redrock-{v}"] = dead_snag(rnd, 16 + 4 * v)
        out[f"sapling-redrock-{v}"] = dry_grass(rnd)
    for i, size in enumerate((5, 7)):
        out[f"bush-redrock-{i}"] = sagebrush(rnd, size)
    for i, size in enumerate((4, 6, 9)):
        out[f"rock-redrock-{i}"] = boulder(rnd, size)
    for i, hgt in enumerate((26, 34, 44)):
        out[f"pillar-redrock-{i}"] = rock_pillar(rnd, hgt)
    for i, hgt in enumerate((20, 26)):
        out[f"trophy-redrock-{i}"] = rock_pillar(rnd, hgt, trophy=True)
    out["menhir-redrock"] = rock_pillar(rnd, 22)
    out["tuft-redrock"] = dry_grass(rnd)
    out["oxskull-redrock"] = skull(rnd)
    out["howl-redrock"] = howling_rock(rnd)
    return out


def main():
    if "--write" in sys.argv:
        res = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources")
        for name, img in sprites().items():
            img.save(os.path.join(res, "Terrain", name + ".png"))
        camp = os.path.join(res, "Camps", "den")
        os.makedirs(camp, exist_ok=True)
        stages = []
        for k in range(3):
            g, entrance = camp_den(k)
            mc.write_png(os.path.join(camp, f"stage{k + 1}.png"), g.image())
            stages.append({"sheet": f"stage{k + 1}.png", "minCount": mc.MIN_COUNT[k], "entrance": list(entrance)})
        import json
        with open(os.path.join(camp, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump({"id": "den", "name": "岩壁獸穴", "blurb": "紅岩上挖出來的獸穴，洞口掛著長角的獸頭骨，門口一圈尖骨圍籬。",
                       "pixelScale": 1.5, "stages": stages}, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print("wrote", os.path.normpath(camp), "and the redrock terrain")
    if "--preview" in sys.argv:
        prefix = sys.argv[sys.argv.index("--preview") + 1]
        camp_preview(prefix + "-camp.png")
        day, night = valley_scene(), valley_scene(full_moon=True)
        both = Image.new("RGBA", (day.width * 2 + 6, day.height), (0, 0, 0, 255))
        both.paste(day, (0, 0)); both.paste(night, (day.width + 6, 0))
        both.resize((both.width * 3, both.height * 3), Image.NEAREST).save(prefix + "-valley.png")
        print("wrote", prefix + "-camp.png", prefix + "-valley.png")


if __name__ == "__main__":
    main()
