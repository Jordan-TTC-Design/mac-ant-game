"""Small helpers for making pixel-art pictures for the README from the game's own sprite sheets."""
import json
import os
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
RES = os.path.join(ROOT, "Resources")
FONT_CJK = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_LATIN = "/System/Library/Fonts/Supplemental/Courier New Bold.ttf"

BREEDS = ["worker", "scout", "brute", "sage", "golden"]
BREED_NAMES = {"worker": "平民", "scout": "敏捷", "brute": "壯碩", "sage": "聰明", "golden": "金皮"}
OUTFITS = [("queen", "洋裝"), ("queen_gown", "長裙禮服"), ("queen_skirt", "短裙上衣"), ("queen_sport", "運動裝"),
           ("queen_sunny", "草帽洋裝"), ("queen_winter", "冬季外套"), ("queen_pajamas", "睡衣")]


def load(*parts):
    return Image.open(os.path.join(RES, *parts)).convert("RGBA")


def frame(sheet, index, size=16, cols=4):
    col, row = index % cols, index // cols
    return sheet.crop((col * size, row * size, (col + 1) * size, (row + 1) * size))


def goblin(breed="worker", direction="down", step=0):
    """One walking frame of a goblin breed (direction: down, up, side)."""
    sheet = load("Characters", "goblin", breed + ".png")
    base = {"down": 0, "up": 4, "side": 8}[direction]
    return frame(sheet, base + step)


def princess(outfit="queen", pose=None, step=0, direction="down"):
    sheet = load("Characters", "goblin", outfit + ".png")
    if pose:
        poses = {"tea": 12, "exercise": 16, "read": 20, "water": 24, "comb": 28, "sing": 32, "dance": 36, "wave": 40, "yawn": 44, "think": 48}
        return frame(sheet, poses[pose] + step)
    base = {"down": 0, "up": 4, "side": 8}[direction]
    return frame(sheet, base + step)


def animal(kind, step=0):
    return frame(load("Animals", kind, "walk.png"), step, cols=2)


def camp(kind, stage):
    return load("Camps", kind, "stage%d.png" % stage)


def flip(img):
    return img.transpose(Image.FLIP_LEFT_RIGHT)


class Art:
    """A picture drawn on a coarse grid: `scale` output pixels per art pixel, so everything stays blocky."""

    def __init__(self, width, height, scale=4, color=(0, 0, 0, 255)):
        self.w, self.h, self.s = width, height, scale
        self.img = Image.new("RGBA", (width * scale, height * scale), color)
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x, y, w, h, color):
        s = self.s
        self.d.rectangle([x * s, y * s, (x + w) * s - 1, (y + h) * s - 1], fill=color)

    def dot(self, x, y, color):
        self.rect(x, y, 1, 1, color)

    def sprite(self, image, x, y, scale=1, bottom_center=True):
        """Pastes a sprite (art-pixel units). With bottom_center, (x, y) is the middle of its feet."""
        s = self.s * scale
        big = image.resize((image.width * s, image.height * s), Image.NEAREST)
        px = int(x * self.s - (big.width / 2 if bottom_center else 0))
        py = int(y * self.s - (big.height if bottom_center else 0))
        self.img.alpha_composite(big, (px, py)) if px >= 0 and py >= 0 else self.img.paste(big, (px, py), big)

    def shadow(self, x, y, w=12, alpha=70):
        for i in range(w // 2 + 1):
            pass
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        s = self.s
        d.ellipse([(x - w / 2) * s, (y - 1.5) * s, (x + w / 2) * s, (y + 1.5) * s], fill=(0, 0, 0, alpha))
        self.img.alpha_composite(layer)

    def text(self, string, x, y, size=12, color=(255, 255, 255, 255), outline=None, font=FONT_CJK, scale=1, anchor="l"):
        """Text drawn without smoothing at `size` art pixels tall, then blown up, so the letters are pixels too."""
        f = ImageFont.truetype(font, size)
        probe = Image.new("L", (10, 10))
        box = ImageDraw.Draw(probe).textbbox((0, 0), string, font=f)
        w, h = box[2] + 2, box[3] + 2
        mask = Image.new("L", (w + 2, h + 2), 0)
        md = ImageDraw.Draw(mask)
        md.fontmode = "1"
        md.text((1, 1), string, font=f, fill=255)
        s = self.s * scale
        rgba = Image.new("RGBA", mask.size, (0, 0, 0, 0))
        big = mask.resize((mask.width * s, mask.height * s), Image.NEAREST)
        if anchor == "c":
            x = x - (w / scale) / 2
        elif anchor == "r":
            x = x - w / scale
        px, py = int(x * self.s), int(y * self.s)
        if outline:
            o = Image.new("RGBA", big.size, (0, 0, 0, 0))
            o.paste(Image.new("RGBA", big.size, outline), (0, 0), big)
            for dx, dy in [(-s, 0), (s, 0), (0, -s), (0, s), (-s, -s), (s, s), (-s, s), (s, -s)]:
                self.img.alpha_composite(o, (max(0, px + dx), max(0, py + dy)))
        fill = Image.new("RGBA", big.size, (0, 0, 0, 0))
        fill.paste(Image.new("RGBA", big.size, color), (0, 0), big)
        self.img.alpha_composite(fill, (max(0, px), max(0, py)))
        return w / scale

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.img.convert("RGBA").save(path, optimize=True)
        print("wrote", os.path.relpath(path, ROOT), self.img.size)


def dither_gradient(art, top, bottom, y0, y1, colors_top, colors_bottom, steps=8):
    """Vertical gradient in bands, with a checkerboard between neighbouring bands."""
    def mix(a, b, t):
        return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)
    height = y1 - y0
    for band in range(steps):
        c = mix(colors_top, colors_bottom, band / max(1, steps - 1))
        nxt = mix(colors_top, colors_bottom, min(1, (band + 1) / max(1, steps - 1)))
        by0 = y0 + height * band // steps
        by1 = y0 + height * (band + 1) // steps
        art.rect(0, by0, art.w, by1 - by0, c)
        for x in range(0, art.w):  # dither the last two rows of the band into the next colour
            for dy, phase in ((by1 - 2, 1), (by1 - 1, 0)):
                if (x + phase) % 2 == 0 and dy >= y0:
                    art.dot(x, dy, nxt)


def tree(art, x, y, fruit=6, unit=2):
    """The game's fruit tree, drawn from its blocks. (x, y) is the foot of the trunk."""
    def px(dx, dy, w, h, c):
        art.rect(x + dx * unit, y - (dy + h) * unit, w * unit, h * unit, c)
    trunk, dark, leaf, light = (107, 69, 36, 255), (41, 107, 51, 255), (69, 158, 69, 255), (107, 194, 92, 255)
    px(-1, 0, 2, 4, trunk)
    px(-4, 4, 8, 5, dark); px(-5, 5, 10, 3, dark); px(-3, 8, 6, 3, dark)
    px(-4, 5, 7, 4, leaf); px(-3, 8, 5, 2, leaf); px(-3, 8, 2, 1, light); px(-4, 7, 1, 1, light)
    spots = [(-3, 5), (2, 6), (0, 8), (-1, 6), (3, 4), (-4, 7)]
    for i in range(min(fruit, len(spots))):
        px(spots[i][0], spots[i][1], 1, 1, (230, 46, 41, 255))


def lcd_clock(art, x, y, text="24:59", rest=False, alarm=False, label="專注"):
    """The pomodoro clock from the game: dark body, LCD glass, seven-segment digits. (x, y) is its top-left corner."""
    body_w, body_h = 46, 24
    art.rect(x, y, body_w, body_h, (36, 36, 36, 255))
    art.rect(x + 1, y - 1, body_w - 2, 1, (36, 36, 36, 255))
    glass = (179, 219, 240, 255) if rest else (189, 214, 158, 255)
    ink = (26, 77, 115, 255) if rest else ((179, 20, 20, 255) if alarm else (26, 56, 26, 255))
    art.rect(x + 3, y + 8, body_w - 6, body_h - 11, glass)
    art.text(label, x + 3, y - 2, size=10, color=(255, 255, 255, 255))
    art.rect(x + 26, y + 4, body_w - 30, 1, (90, 90, 90, 255))
    art.rect(x + 26, y + 4, (body_w - 30) // 3, 1, (128, 217, 102, 255) if not rest else (102, 191, 242, 255))
    segs = [[1, 1, 1, 0, 1, 1, 1], [0, 0, 1, 0, 0, 1, 0], [1, 0, 1, 1, 1, 0, 1], [1, 0, 1, 1, 0, 1, 1], [0, 1, 1, 1, 0, 1, 0],
            [1, 1, 0, 1, 0, 1, 1], [1, 1, 0, 1, 1, 1, 1], [1, 0, 1, 0, 0, 1, 0], [1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 0, 1, 1]]
    dx = x + 6
    dy = y + 10
    for ch in text:
        if ch == ":":
            art.rect(dx, dy + 3, 1, 1, ink); art.rect(dx, dy + 7, 1, 1, ink)
            dx += 3
            continue
        on = segs[int(ch)]
        w, h = 5, 10
        if on[0]: art.rect(dx + 1, dy, w - 2, 1, ink)
        if on[1]: art.rect(dx, dy + 1, 1, 4, ink)
        if on[2]: art.rect(dx + w - 1, dy + 1, 1, 4, ink)
        if on[3]: art.rect(dx + 1, dy + 5, w - 2, 1, ink)
        if on[4]: art.rect(dx, dy + 6, 1, 3, ink)
        if on[5]: art.rect(dx + w - 1, dy + 6, 1, 3, ink)
        if on[6]: art.rect(dx + 1, dy + 9, w - 2, 1, ink)
        dx += w + 1
    hand = (92, 158, 61, 255)
    art.rect(x - 1, y + body_h - 1, 4, 3, hand)
    art.rect(x + body_w - 3, y + body_h - 1, 4, 3, hand)


def bubble(art, x, y, lines, accent=(242, 140, 26, 255), tail_x=None, width=None, size=12, title=None, foot=None, extra=0):
    """A speech bubble (top-left at x, y in art pixels) with a pointer at the bottom, like the game's popups."""
    line_h = size + 2
    f = ImageFont.truetype(FONT_CJK, size)
    probe = ImageDraw.Draw(Image.new("L", (10, 10)))
    text_w = max(probe.textbbox((0, 0), s, font=f)[2] for s in lines + ([title] if title else []) + ([foot] if foot else []))
    w = width or text_w + 12
    rows = len(lines) + (1 if title else 0) + (1 if foot else 0)
    h = rows * line_h + 8 + extra
    art.rect(x, y, w, h, accent)
    art.rect(x + 1, y + 1, w - 2, h - 2, (255, 255, 255, 255))
    art.rect(x, y, 1, 1, (0, 0, 0, 0)); art.dot(x + w - 1, y, (0, 0, 0, 0))
    tx = tail_x if tail_x is not None else x + w - 12
    art.rect(tx, y + h, 6, 1, (255, 255, 255, 255)); art.rect(tx, y + h - 1, 6, 1, (255, 255, 255, 255))
    art.rect(tx + 1, y + h + 1, 4, 1, accent); art.rect(tx + 2, y + h + 2, 2, 1, accent)
    art.rect(tx + 1, y + h, 4, 1, (255, 255, 255, 255)); art.rect(tx + 2, y + h + 1, 2, 1, (255, 255, 255, 255))
    cy = y + 4
    if title:
        art.text(title, x + 6, cy, size=size, color=accent); cy += line_h
    for s in lines:
        art.text(s, x + 6, cy, size=size, color=(30, 30, 30, 255)); cy += line_h
    if foot:
        art.text(foot, x + 6, cy, size=size - 2, color=(120, 120, 120, 255))
    return w, h
