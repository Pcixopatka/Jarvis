#!/usr/bin/env python3
"""Значки здобичі 16×16 (малюються ×2): зілля, дерево, залізо, трави, трофей, вареник.
Запуск: python3 tools/pixel/icons.py → assets/gfx/sprites/icons.png (один ряд, порядок як в ORDER)."""
import os
from PIL import Image, ImageDraw
ORDER = ["potion", "wood", "iron", "herbs", "trophy", "varenyk"]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites", "icons.png")
O = (27, 20, 32, 255)

def outline(im):
    src = im.load(); out = im.copy(); o = out.load()
    for y in range(16):
        for x in range(16):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 16 and 0 <= ny < 16 and src[nx, ny][3] > 0 and src[nx, ny] != O:
                        o[x, y] = O; break
    return out

def draw(kind):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if kind == "potion":
        d.rectangle([6, 1, 9, 4], fill=(170, 180, 190, 255)); d.rectangle([5, 0, 10, 1], fill=(110, 70, 40, 255))
        d.ellipse([3, 4, 12, 14], fill=(200, 30, 40, 255)); d.ellipse([5, 6, 7, 8], fill=(255, 140, 140, 255))
    elif kind == "wood":
        d.rectangle([1, 5, 14, 10], fill=(140, 95, 50, 255)); d.rectangle([1, 6, 14, 6], fill=(170, 120, 70, 255)); d.ellipse([12, 4, 15, 11], fill=(210, 170, 110, 255)); d.ellipse([13, 6, 14, 9], fill=(150, 105, 60, 255))
    elif kind == "iron":
        d.polygon([(2, 11), (5, 5), (14, 5), (11, 11)], fill=(150, 155, 165, 255)); d.line([(5, 5), (14, 5)], fill=(210, 215, 225, 255)); d.rectangle([3, 11, 12, 12], fill=(100, 105, 115, 255))
    elif kind == "herbs":
        for i, x in enumerate((4, 7, 10)):
            d.line([(x, 14), (x + (i - 1) * 2, 3)], fill=(60, 150, 60, 255), width=2)
            d.ellipse([x + (i - 1) * 2 - 2, 1, x + (i - 1) * 2 + 2, 5], fill=(110, 200, 90, 255))
        d.ellipse([6, 0, 10, 4], fill=(240, 220, 90, 255))
    elif kind == "trophy":
        d.rectangle([5, 1, 10, 5], fill=(190, 40, 50, 255)); d.polygon([(5, 5), (10, 5), (8, 8), (7, 8)], fill=(150, 30, 40, 255))
        d.ellipse([3, 6, 12, 15], fill=(230, 185, 60, 255)); d.ellipse([5, 8, 10, 13], fill=(250, 220, 120, 255)); d.point((7, 9), fill=(255, 255, 230, 255))
    elif kind == "varenyk":
        d.pieslice([1, 3, 15, 17], 180, 360, fill=(250, 238, 205, 255))
        for x in range(2, 15, 3): d.point((x, 9), fill=(225, 205, 160, 255))
        d.line([(2, 9), (14, 9)], fill=(225, 205, 160, 255))
    return outline(im)

sheet = Image.new("RGBA", (16 * len(ORDER), 16), (0, 0, 0, 0))
for i, k in enumerate(ORDER):
    sheet.paste(draw(k), (i * 16, 0))
sheet.save(OUT); print("ok icons")
