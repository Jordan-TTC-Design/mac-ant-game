#!/usr/bin/env python3
"""Composes guild avatars from mac/Resources/Avatars exactly as the game's renderer should (manifest layer order, key-colour
recolouring, frame indices, outline pass, frame offsets) and lays them out with a hall mock-up from mac/Resources/Guild.

    python3 mac/tools/check_avatars.py      # writes docs/images/guild/avatars_production_check.png

Also checks: no key colour survives recolouring, and each race's default avatar matches the approved front/side/back art.
"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
AV = os.path.join(REPO, "mac", "Resources", "Avatars")
GU = os.path.join(REPO, "mac", "Resources", "Guild")
OUT = os.path.join(REPO, "docs", "images", "guild", "avatars_production_check.png")
FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
M = json.load(open(os.path.join(AV, "manifest.json"), encoding="utf-8"))
FW, FH = M["frameW"], M["frameH"]

# shared/src/guild.ts: AVATAR_OPTIONS and defaultAvatar(), mirrored here for the check
OPTIONS = {
    "goblin": {"hair": {"m": ["tuft", "mohawk", "topknot", "bald_ring", "dreads", "wild", "bun", "spikes"],
                        "f": ["braids", "bun", "dreads", "wild", "tuft", "pigtails", "mohawk", "bob"]},
               "skin": ["light", "grass", "moss", "deep"]},
    "elf": {"hair": {"m": ["neat", "long", "halfup", "ponytail", "side_braid", "waves", "messy", "braided_crown"],
                     "f": ["long_wreath", "braided_crown", "side_braid", "waves", "long", "ponytail", "halfup", "wreath_updo"]},
            "skin": ["fair", "warm", "tan", "bronze"]},
    "undead": {"hair": {"m": ["hood", "bare", "crack", "horns", "long_horns", "ragged_hood", "bone_crown", "candle"],
                        "f": ["drift", "flame", "mist", "wisp_twins", "glass_short", "long_wave", "side_wisp", "flame_crown"]},
               "skin": ["bone", "ivory", "ash", "slate"]},
}
SPIRIT_SKINS = ["pale_blue", "ice", "pale_violet", "lavender"]
EYES = ["round", "narrow", "sparkle", "dot", "sleepy", "sharp", "lashes", "wide"]
BROWS = ["thin", "thick", "faint", "none"]
MOUTHS = ["line", "smile", "smirk", "open", "pout", "cat"]
SKULL = ["teeth", "grin", "gap", "jaw", "fang", "stitch"]
HAIRC = ["black", "darkbrown", "chestnut", "orange", "yellow", "blonde", "silver", "pink", "lavender", "mint", "navy", "forest"]


def default_avatar(race, sex):
    look = {"goblinm": dict(hairColor="darkbrown", skin="grass"), "goblinf": dict(hairColor="orange", skin="grass", eyes="lashes"),
            "elfm": dict(hairColor="chestnut", skin="fair"), "elff": dict(hairColor="blonde", skin="fair", eyes="lashes"),
            "undeadm": dict(hairColor="black", skin="bone", flame="cyan"), "undeadf": dict(hairColor="mint", skin="pale_blue")}
    skins = SPIRIT_SKINS if (race, sex) == ("undead", "f") else OPTIONS[race]["skin"]
    mouth = SKULL[0] if (race, sex) == ("undead", "m") else MOUTHS[0]
    a = dict(race=race, sex=sex, face="round", eyes="round", brows="faint", mouth=mouth, hair=OPTIONS[race]["hair"][sex][0],
             hairColor="black", skin=skins[0])
    if (race, sex) == ("undead", "m"):
        a["flame"] = "cyan"
    a.update(look[race + sex])
    return a


def random_avatar(race, sex, rng):
    a = default_avatar(race, sex)
    skins = SPIRIT_SKINS if (race, sex) == ("undead", "f") else OPTIONS[race]["skin"]
    a.update(face=rng.choice(["round", "pointed", "square"]), eyes=rng.choice(EYES), brows=rng.choice(BROWS),
             mouth=rng.choice(SKULL if (race, sex) == ("undead", "m") else MOUTHS), hair=rng.choice(OPTIONS[race]["hair"][sex]),
             skin=rng.choice(skins), hairColor=rng.choice(HAIRC))
    if "flame" in a:
        a["flame"] = rng.choice(["cyan", "violet", "green", "orange"])
    return a


# --- the renderer ------------------------------------------------------------------------------------------------------------
_cache = {}


def strip(rel):
    if rel not in _cache:
        _cache[rel] = Image.open(os.path.join(AV, rel)).convert("RGBA")
    return _cache[rel]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def recolor_map(a):
    body = f"{a['race']}_{a['sex']}"
    rc = M["recolor"]
    m = {}
    for key, col in zip(rc["skin"]["keys"], rc["skin"]["options"][f"{body}_{a['skin']}"]):
        m[rgb(key)] = rgb(col)
    for key, col in zip(rc["hair"]["keys"], rc["hair"]["options"][a["hairColor"]]):
        m[rgb(key)] = rgb(col)
    if a.get("flame"):
        for key, col in zip(rc["flame"]["keys"], rc["flame"]["options"][a["flame"]]):
            m[rgb(key)] = rgb(col)
    return m


def layer_file(a, layer, hat):
    body = f"{a['race']}_{a['sex']}"
    bt = M["bodyType"][body]
    f = M["files"]
    if layer == "body":
        return f["body"].get(f"{body}_{a['face']}")
    if layer in ("hair_back", "hair_front"):
        name = layer + ("_flat" if hat else "")
        return f.get(name, {}).get(f"{body}_{a['hair']}")
    if layer in ("bottom", "top", "shoes"):
        return f[layer].get(f"{body}_default")
    if layer in ("eyes", "mouth", "brows"):
        return f[layer].get(f"{bt}_{a[layer]}")
    if layer == "hat":
        return f["hat"].get(hat) if hat else None
    if layer == "fx":
        return f["fx"]
    return None


def compose(a, i, hat=None, face_right=False):
    """One frame of avatar `a` (a dict like defaultAvatar()), as the renderer draws it. Returns (image, leftover key pixels)."""
    body = f"{a['race']}_{a['sex']}"
    cmap = recolor_map(a)
    canvas = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    keys = {rgb(k) for ch in M["recolor"].values() for k in ch["keys"]}
    leftover = 0
    fx = None
    for layer in M["layers"]:
        rel = layer_file(a, layer, hat)
        if not rel:
            continue
        fr = strip(rel).crop((i * FW, 0, (i + 1) * FW, FH))
        px = fr.load()
        for y in range(FH):
            for x in range(FW):
                r, g, b, al = px[x, y]
                if al and (r, g, b) in cmap:
                    px[x, y] = cmap[(r, g, b)] + (al,)
        if layer == "fx":
            fx = fr
            continue
        canvas.alpha_composite(fr)
    # the outline pass
    out = canvas.copy()
    src, dst = canvas.load(), out.load()
    oc = rgb(M["outline"][body]) + (255,)
    for y in range(FH):
        for x in range(FW):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < FW and 0 <= ny < FH and src[nx, ny][3]:
                        dst[x, y] = oc
                        break
    if fx:
        out.alpha_composite(fx)
    for y in range(FH):
        for x in range(FW):
            p = out.getpixel((x, y))
            if p[3] and p[:3] in keys:
                leftover += 1
    off = M.get("frameOffset", {}).get(body, [0] * M["frames"])[i]
    if off:
        moved = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
        moved.alpha_composite(out, (0, off)) if off > 0 else moved.paste(out.crop((0, -off, FW, FH)), (0, 0))
        out = moved
    if face_right:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
    return out, leftover


def approved_diff():
    """Each default avatar's idle frames against the approved preview art (front, back, side)."""
    import make_avatars_preview as pv
    ids = {("goblin", "m"): "gob_m", ("goblin", "f"): "gob_f", ("elf", "m"): "elf_m", ("elf", "f"): "elf_f",
           ("undead", "m"): "und_m", ("undead", "f"): "und_f"}
    idle = M["anims"]["idle"]
    res = []
    for (race, sex), aid in ids.items():
        av = next(x for x in pv.AVATARS if x["id"] == aid)
        pal = pv.PALS[aid]
        row = []
        for view, want in (("front", pv.front(av)), ("back", pv.back(av, 0)), ("side", pv.side(av, 0))):
            w = want.image(pal)
            if view == "side":
                w = w.transpose(Image.FLIP_LEFT_RIGHT)
            for brows in ("faint", "none"):
                a = default_avatar(race, sex)
                a["brows"] = brows
                got, _ = compose(a, idle[view]["frames"][0])
                x0 = 4 if view != "side" else FW - 4 - 24
                got = got.crop((x0, 10, x0 + 24, 40))
                d = sum(1 for y in range(30) for x in range(24) if w.getpixel((x, y)) != got.getpixel((x, y)))
                row.append((view, brows, d))
        res.append((aid, row))
    return res


# --- the hall mock-up ---------------------------------------------------------------------------------------------------------
def hall_mockup(avatars, scale=3):
    G = json.load(open(os.path.join(GU, "manifest.json"), encoding="utf-8"))
    T = G["tile"]
    cols, rows = 16, 10
    room = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 255))
    load = lambda rel: Image.open(os.path.join(GU, rel)).convert("RGBA")  # noqa: E731
    floor = {k: load(v) for k, v in G["floors"].items()}
    for ty in range(2, rows):
        for tx in range(cols):
            f = "oak"
            if tx >= 11:
                f = "marble"
            if 4 <= tx <= 9 and ty >= 7:
                f = "carpet"
            if tx <= 1 and ty >= 6:
                f = "stone"
            room.alpha_composite(floor[f], (tx * T, ty * T))
    wall = G["walls"]["stone"]
    wimg, corner = load(wall["file"]), load(wall["corner"])
    for tx in range(cols):
        room.alpha_composite(wimg if tx not in (7, 8) else load(G["walls"]["wood"]["file"]), (tx * T, 0))
    room.alpha_composite(corner, ((cols - 1) * T, 0))
    room.alpha_composite(corner.transpose(Image.FLIP_LEFT_RIGHT), (0, 0))
    fur = G["furniture"]

    def frame_of(fid, i=0):
        spec = fur[fid]
        im = load(spec["file"])
        return im.crop((i * spec["w"], 0, (i + 1) * spec["w"], spec["h"]))

    items = []   # (sort y, order, image, x, y)

    def put(fid, fx, fy, i=0):
        spec = fur[fid]
        im = frame_of(fid, i)
        x, y = fx - spec["anchor"]["x"], fy - spec["anchor"]["y"]
        if spec.get("flat"):
            items.append((-1, 0, im, x, y))
        elif spec.get("wall"):
            items.append((0, 0, im, x, y))
        else:
            items.append((fy, 0, im, x, y))
        return x, y

    def avatar(a, anim, d, k, fx, fy, order=1, sort=None, face_right=False):
        i = M["anims"][anim][d]["frames"][k]
        im, _ = compose(a, i, face_right=face_right)
        items.append((fy if sort is None else sort, order, im, fx - M["anchor"]["x"], fy - M["anchor"]["y"]))

    def sit_on(fid, fx, fy, a, anim, d, k, i=0, face_right=False):
        spec = fur[fid]
        x, y = put(fid, fx, fy, i)
        sx, sy = x + spec["seat"]["x"], y + spec["seat"]["y"]
        if face_right:
            sx = x + spec["w"] - spec["seat"]["x"]
        if spec["seat"]["behind"]:
            avatar(a, anim, d, k, sx, sy, order=1, sort=fy, face_right=face_right)
        else:
            items[-1] = (fy, 2) + items[-1][2:]
            avatar(a, anim, d, k, sx, sy, order=1, sort=fy, face_right=face_right)

    A = [a for _, a in avatars]
    put("rug", 7 * T, 9 * T + 8)
    put("fireplace", 7 * T + 16, 2 * T)
    put("bookshelf", 13 * T, 2 * T)
    put("banner", 4 * T, 1 * T + 12)
    put("banner", 11 * T, 1 * T + 12)
    put("plant", 1 * T, 3 * T)
    put("plant", 15 * T + 4, 9 * T)
    sit_on("desk", 3 * T, 4 * T + 6, A[0], "type", "front", 0)
    sit_on("desk", 3 * T, 7 * T + 4, A[5], "doze", "front", 1)
    sit_on("bench", 7 * T + 16, 5 * T, A[2], "sit", "front", 0)
    sit_on("bench", 7 * T + 16, 5 * T, A[3], "sit", "front", 1) if False else None
    sit_on("armchair", 12 * T + 8, 5 * T + 8, A[3], "sit", "front", 1)
    sit_on("stool_side", 14 * T + 4, 7 * T + 8, A[9], "sit", "side", 0)
    x, y = put("water_dispenser", 10 * T, 3 * T + 10, 1)
    u = fur["water_dispenser"]["use"]
    avatar(A[1], "drink", "front", 1, x + u["x"], y + u["y"])
    gap = M["highfive"]["anchorGap"]
    avatar(A[4], "highfive", "side", 1, 7 * T, 9 * T, face_right=True)
    avatar(A[6], "highfive", "side", 1, 7 * T + gap, 9 * T)
    avatar(A[7], "walk", "side", 1, 11 * T + 4, 8 * T + 10)
    avatar(A[8], "chat", "front", 0, 13 * T, 9 * T + 6)
    avatar(A[10], "wave", "front", 1, 2 * T, 9 * T + 4)
    for _sy, _o, im, x, y in sorted(items, key=lambda t: (t[0], t[1])):
        room.alpha_composite(im, (int(x), int(y))) if x >= 0 and y >= 0 else room.paste(im, (int(x), int(y)), im)
    return room.resize((room.width * scale, room.height * scale), Image.NEAREST)


# --- the sheet -----------------------------------------------------------------------------------------------------------------
def text(d, xy, s, size, fill=(60, 36, 20), anchor="la"):
    d.text(xy, s, font=ImageFont.truetype(FONT, size), fill=fill, anchor=anchor)


def wood(img):
    d = ImageDraw.Draw(img)
    planks = [(228, 198, 152), (220, 188, 142), (232, 204, 160), (216, 184, 138)]
    for r, y in enumerate(range(0, img.height, 24)):
        d.rectangle([0, y, img.width, y + 23], fill=planks[r % 4])
        d.line([0, y + 23, img.width, y + 23], fill=(186, 150, 104), width=2)
        for x in range((r * 148) % 212, img.width, 212):
            d.line([x, y, x, y + 22], fill=(186, 150, 104), width=2)


def anim_order():
    out = []
    for name, dirs in M["anims"].items():
        for d, spec in dirs.items():
            out.append((f"{name}/{d}", spec["frames"]))
    return out


def main():
    diffs = approved_diff()
    for aid, row in diffs:
        print("approved vs default", aid, row)
    rng = random.Random(11)
    avatars = [("哥布林・男 預設", default_avatar("goblin", "m")), ("哥布林・女 預設", default_avatar("goblin", "f")),
               ("精靈・男 預設", default_avatar("elf", "m")), ("精靈・女 預設", default_avatar("elf", "f")),
               ("死靈・男 預設", default_avatar("undead", "m")), ("死靈・女 預設", default_avatar("undead", "f"))]
    for race, sex in (("goblin", "f"), ("elf", "m"), ("undead", "m"), ("undead", "f"), ("goblin", "m"), ("elf", "f")):
        avatars.append(("隨機", random_avatar(race, sex, rng)))
    S = 2
    groups = anim_order()
    per_line = 28
    seq = [(lab, i) for lab, idx in groups for i in idx]
    lines = [seq[k:k + per_line] for k in range(0, len(seq), per_line)]
    cell = FW * S + 2
    row_h = FH * S + 18
    hall_h = 0
    hall = None
    if os.path.exists(os.path.join(GU, "manifest.json")):
        hall = hall_mockup(avatars)
        hall_h = hall.height + 40
    hats = []
    for lab, a in avatars[:6]:
        for i in (M["anims"]["idle"]["front"]["frames"][0], M["anims"]["walk"]["side"]["frames"][1],
                  M["anims"]["idle"]["back"]["frames"][0], M["anims"]["sit"]["front"]["frames"][0]):
            hats.append(compose(a, i, hat="feather_cap")[0])
    width = 160 + per_line * cell + 10
    height = 50 + len(avatars) * (row_h * len(lines) + 10) + row_h + 40 + hall_h
    img = Image.new("RGBA", (width, height), (228, 198, 152, 255))
    wood(img)
    d = ImageDraw.Draw(img)
    text(d, (10, 8), f"公會分身 正式素材檢查：{FW}×{FH}、{M['frames']} 格、圖層 {' → '.join(M['layers'])}（照 manifest 組合、換色、描邊）",
         24)
    y = 50
    leftovers = 0
    for lab, a in avatars:
        desc = f"{a['face']}/{a['eyes']}/{a['mouth']}/{a['brows']}/{a['hair']}/{a['hairColor']}/{a['skin']}" + \
               (f"/{a['flame']}" if a.get("flame") else "")
        text(d, (8, y + 10), lab, 18)
        text(d, (8, y + 34), desc.replace("/", "\n", 3) if False else "", 12)
        for li, line in enumerate(lines):
            x = 160
            prev = None
            for lab2, i in line:
                im, lo = compose(a, i)
                leftovers += lo
                img.alpha_composite(im.resize((FW * S, FH * S), Image.NEAREST), (x, y + li * row_h))
                if lab2 != prev:
                    text(d, (x + 2, y + li * row_h + FH * S + 1), lab2, 12, (90, 60, 34))
                    prev = lab2
                x += cell
        text(d, (8, y + 36), a["hair"], 13, (90, 60, 34))
        text(d, (8, y + 52), f"{a['hairColor']} · {a['skin']}", 13, (90, 60, 34))
        text(d, (8, y + 68), f"{a['eyes']} · {a['mouth']} · {a['brows']}", 13, (90, 60, 34))
        text(d, (8, y + 84), a["face"] + (f" · {a['flame']}" if a.get("flame") else ""), 13, (90, 60, 34))
        y += row_h * len(lines) + 10
    text(d, (8, y + 10), "戴帽子（壓扁前髮）", 18)
    x = 160
    for im in hats:
        img.alpha_composite(im.resize((FW * S, FH * S), Image.NEAREST), (x, y))
        x += cell
    y += row_h + 30
    if hall:
        text(d, (8, y), "據點示意（家具、地板、牆，分身照座位點坐下）", 20)
        img.alpha_composite(hall, (10, y + 30))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("leftover key pixels:", leftovers, "| wrote", os.path.relpath(OUT, REPO), img.size)


if __name__ == "__main__":
    main()
