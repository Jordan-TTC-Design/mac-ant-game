#!/usr/bin/env python3
"""Builds the app icon (Resources/AppIcon.icns) from the goblin face.

    python3 tools/make_icons.py [--preview /path/icon.png]

The icon is drawn as 64x64 pixel art (a rounded tile, a soft glow, the goblin face at 2x) and scaled up with
nearest-neighbour to 1024, then box-filtered down for the smaller sizes. `iconutil` (part of macOS) packs the
iconset into an .icns.
"""
import os
import shutil
import subprocess
import sys

from make_goblin import SIZE, WORKER, goblin_face, write_png

ART = 64


def tile():
    img = [[(0, 0, 0, 0)] * ART for _ in range(ART)]
    x0, y0, x1, y1, r = 4, 3, 59, 58, 9

    def inside(x, y, ox=0, oy=0):
        x, y = x - ox, y - oy
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        cx = min(max(x, x0 + r), x1 - r)      # rounded corners, drawn as pixel steps
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r

    bands = [(24, 58, 66), (22, 52, 62), (19, 46, 58), (16, 40, 52)]           # dusk teal, darker toward the bottom
    for y in range(ART):
        for x in range(ART):
            if inside(x, y, 0, 2) and not inside(x, y):
                img[y][x] = (0, 0, 0, 70)                                      # soft drop shadow
            if inside(x, y):
                img[y][x] = bands[min(3, (y - y0) * 4 // (y1 - y0 + 1))] + (255,)
                if (x - 32) ** 2 + (y - 30) ** 2 <= 23 ** 2:
                    img[y][x] = (44, 92, 92, 255) if (x + y) % 2 == 0 or (x - 32) ** 2 + (y - 30) ** 2 <= 19 ** 2 else img[y][x]
    return img


def compose():
    img = tile()
    face = goblin_face()
    ox, oy = 16, 14
    for y in range(SIZE):
        for x in range(SIZE):
            key = face.px[y][x]
            if key:
                for dy in range(2):
                    for dx in range(2):
                        img[oy + y * 2 + dy][ox + x * 2 + dx] = WORKER[key] + (255,)
    return img


def scale_nearest(img, factor):
    return [[px for px in row for _ in range(factor)] for row in img for _ in range(factor)]


def box_down(img, size):
    n = len(img) // size
    out = []
    for by in range(size):
        row = []
        for bx in range(size):
            acc = [0, 0, 0, 0]
            for y in range(by * n, by * n + n):
                for x in range(bx * n, bx * n + n):
                    r, g, b, a = img[y][x]
                    acc[0] += r * a; acc[1] += g * a; acc[2] += b * a; acc[3] += a   # weight colour by alpha
            total = acc[3]
            row.append((acc[0] // total, acc[1] // total, acc[2] // total, total // (n * n)) if total else (0, 0, 0, 0))
        out.append(row)
    return out


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    big = scale_nearest(compose(), 16)                       # 1024x1024
    if "--preview" in sys.argv:
        write_png(sys.argv[sys.argv.index("--preview") + 1], big)
    iconset = os.path.join(root, "AppIcon.iconset")
    shutil.rmtree(iconset, ignore_errors=True)
    os.makedirs(iconset)
    for base in (16, 32, 128, 256, 512):
        for factor in (1, 2):
            px = base * factor
            name = f"icon_{base}x{base}{'@2x' if factor == 2 else ''}.png"
            write_png(os.path.join(iconset, name), big if px == 1024 else box_down(big, px))
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(root, "Resources", "AppIcon.icns")], check=True)
    shutil.rmtree(iconset)
    print("wrote Resources/AppIcon.icns")


if __name__ == "__main__":
    main()
