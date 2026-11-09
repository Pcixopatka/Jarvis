#!/usr/bin/env python3
"""Значки мапи світу (24×24) у стилі старовинної мапи + текстура пергаменту.
Запуск: python3 tools/pixel/map_icons.py → assets/gfx/sprites/map_icons.png, map_parchment.png"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter
S = 24
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites")
def hx(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
INK = hx("3a2a1a"); INK2 = hx("5a4030"); PAPER = hx("e8d7b0"); GREEN = hx("5a7a3a"); GREEN2 = hx("7a9a4a"); GREY = hx("8a8278"); RED = hx("a83a2a"); BLUE = hx("4a7aa8"); GOLD = hx("c8a040")
ORDER = ["castle", "hut", "tree", "pine", "mountain", "swamp", "cave", "tower", "skull", "sabres", "wave", "camp", "ship", "rider", "flag", "town", "raid", "wagon", "chains", "wounded", "tent", "moon", "chest"]

def outline(im, col=INK):
    src = im.load(); out = im.copy(); o = out.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0 and src[nx, ny] != col:
                        o[x, y] = col; break
    return out

def icon(kind):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if kind == "castle":
        d.rectangle([4, 10, 19, 21], fill=hx("b8a080")); d.rectangle([2, 6, 7, 21], fill=hx("c8b090")); d.rectangle([16, 6, 21, 21], fill=hx("c8b090"))
        for x in (2, 5, 16, 19): d.rectangle([x, 4, x + 1, 6], fill=hx("c8b090"))
        d.rectangle([10, 15, 13, 21], fill=INK); d.rectangle([8, 2, 15, 10], fill=hx("c8b090")); d.polygon([(7, 3), (16, 3), (11, 0)], fill=RED)
        d.rectangle([4, 12, 5, 13], fill=INK); d.rectangle([18, 12, 19, 13], fill=INK)
    elif kind == "town":
        d.rectangle([5, 12, 18, 21], fill=hx("c8b090")); d.polygon([(4, 12), (19, 12), (12, 5)], fill=RED); d.rectangle([10, 16, 13, 21], fill=INK)
    elif kind == "hut":
        d.rectangle([5, 13, 18, 21], fill=hx("f0e6d0")); d.polygon([(3, 13), (20, 13), (12, 5)], fill=hx("c8a850")); d.rectangle([10, 16, 13, 21], fill=INK2); d.rectangle([6, 15, 8, 17], fill=BLUE)
    elif kind == "tree":
        d.ellipse([4, 3, 19, 17], fill=GREEN); d.ellipse([7, 1, 17, 11], fill=GREEN2); d.rectangle([10, 15, 13, 22], fill=INK2)
    elif kind == "pine":
        d.polygon([(12, 1), (20, 12), (4, 12)], fill=GREEN); d.polygon([(12, 7), (21, 19), (3, 19)], fill=GREEN2); d.rectangle([10, 18, 13, 22], fill=INK2)
    elif kind == "mountain":
        d.polygon([(1, 22), (9, 6), (17, 22)], fill=GREY); d.polygon([(10, 22), (17, 9), (23, 22)], fill=hx("6a6258")); d.polygon([(6, 12), (9, 6), (12, 12)], fill=hx("f0f0f0")); d.polygon([(15, 13), (17, 9), (19, 13)], fill=hx("f0f0f0"))
    elif kind == "swamp":
        d.ellipse([2, 13, 21, 22], fill=hx("6a8a60"))
        for x in (6, 11, 16): d.line([(x, 20), (x + (x - 11) // 3, 5)], fill=GREEN, width=2); d.ellipse([x + (x - 11) // 3 - 1, 3, x + (x - 11) // 3 + 2, 8], fill=hx("6a4a20"))
    elif kind == "cave":
        d.polygon([(2, 22), (5, 10), (12, 3), (19, 10), (22, 22)], fill=hx("6a5a48")); d.ellipse([7, 10, 17, 22], fill=INK); d.rectangle([7, 16, 17, 22], fill=INK)
    elif kind == "tower":
        d.rectangle([7, 6, 16, 22], fill=hx("d8d0b8")); d.rectangle([7, 10, 16, 11], fill=hx("b8b098")); d.rectangle([7, 16, 16, 17], fill=hx("b8b098"))
        for x in (7, 11, 15): d.rectangle([x, 3, x + 1, 6], fill=hx("d8d0b8"))
        d.rectangle([10, 12, 13, 14], fill=hx("6fd63a")); d.rectangle([10, 18, 13, 22], fill=INK)
    elif kind == "skull":
        d.ellipse([5, 3, 18, 16], fill=hx("f0ead8")); d.rectangle([8, 14, 15, 19], fill=hx("f0ead8")); d.ellipse([8, 8, 11, 11], fill=INK); d.ellipse([13, 8, 16, 11], fill=INK)
        for x in (9, 12, 15): d.rectangle([x, 17, x, 19], fill=INK)
    elif kind == "sabres":
        d.line([(4, 20), (19, 5)], fill=hx("d8dce6"), width=3); d.line([(19, 20), (4, 5)], fill=hx("d8dce6"), width=3); d.rectangle([3, 18, 7, 22], fill=GOLD); d.rectangle([16, 18, 20, 22], fill=GOLD)
    elif kind == "wave":
        for y in (8, 14, 20): d.arc([2, y - 4, 10, y + 2], 180, 360, fill=BLUE, width=2); d.arc([9, y - 4, 17, y + 2], 0, 180, fill=BLUE, width=2); d.arc([16, y - 4, 24, y + 2], 180, 360, fill=BLUE, width=2)
    elif kind == "camp":
        d.rectangle([4, 13, 17, 21], fill=hx("f0e6d0")); d.polygon([(2, 13), (19, 13), (10, 6)], fill=hx("c8a850")); d.rectangle([9, 16, 12, 21], fill=INK2)
        d.line([(18, 14), (18, 2)], fill=INK2, width=1); d.rectangle([19, 2, 23, 4], fill=BLUE); d.rectangle([19, 5, 23, 7], fill=GOLD)
    elif kind == "ship":
        d.polygon([(2, 15), (22, 15), (18, 21), (6, 21)], fill=hx("7a4a28")); d.line([(12, 15), (12, 2)], fill=INK2, width=1); d.polygon([(13, 3), (21, 12), (13, 12)], fill=hx("f0e6d0")); d.polygon([(11, 4), (4, 12), (11, 12)], fill=hx("f0e6d0"))
    elif kind == "rider":
        # кінь праворуч, козак із хоругвою
        d.ellipse([4, 11, 18, 19], fill=hx("6a4426")); d.ellipse([15, 7, 22, 13], fill=hx("6a4426")); d.polygon([(19, 7), (21, 4), (22, 8)], fill=hx("6a4426"))
        for x in (6, 10, 14): d.rectangle([x, 18, x + 1, 23], fill=hx("4a2e16"))
        d.rectangle([9, 5, 13, 12], fill=hx("c8281e")); d.ellipse([9, 1, 13, 5], fill=hx("f1c9a0")); d.rectangle([11, 0, 12, 1], fill=INK)
        d.line([(6, 12), (6, 0)], fill=INK2, width=1); d.rectangle([1, 0, 5, 2], fill=BLUE); d.rectangle([1, 3, 5, 5], fill=GOLD)
    elif kind == "raid":  # палаюча хата
        d.rectangle([5, 14, 18, 22], fill=hx("6a5a48")); d.polygon([(3, 14), (20, 14), (12, 7)], fill=hx("4a3a28"))
        for x, h in ((7, 6), (12, 3), (16, 7)): d.polygon([(x - 3, 14), (x + 3, 14), (x, h)], fill=hx("ff8a2a")); d.polygon([(x - 1, 14), (x + 1, 14), (x, h + 4)], fill=hx("ffd040"))
    elif kind == "wagon":
        d.rectangle([3, 8, 19, 15], fill=hx("8a5a2a")); d.ellipse([3, 3, 19, 10], fill=hx("f0e6d0")); d.ellipse([3, 14, 9, 20], fill=INK2); d.ellipse([13, 14, 19, 20], fill=INK2); d.line([(19, 11), (23, 9)], fill=INK2, width=2)
    elif kind == "chains":
        for i in range(3): d.ellipse([3 + i * 6, 6 + (i % 2) * 6, 9 + i * 6, 12 + (i % 2) * 6], outline=GREY, width=2)
        d.rectangle([9, 15, 15, 21], fill=hx("c8c8c8")); d.rectangle([11, 17, 13, 19], fill=INK)
    elif kind == "wounded":
        d.ellipse([3, 10, 21, 20], fill=hx("c8281e")); d.ellipse([4, 8, 10, 14], fill=hx("f1c9a0")); d.rectangle([13, 2, 16, 11], fill=hx("f0f0f0")); d.rectangle([10, 5, 19, 8], fill=hx("f0f0f0"))
    elif kind == "tent":
        d.polygon([(2, 21), (22, 21), (12, 4)], fill=hx("c8281e")); d.polygon([(6, 21), (18, 21), (12, 9)], fill=hx("f0e6d0")); d.rectangle([10, 15, 14, 21], fill=INK2); d.rectangle([11, 0, 13, 5], fill=GOLD)
    elif kind == "moon":
        d.ellipse([3, 3, 21, 21], fill=hx("f0e0a0")); d.ellipse([8, 1, 24, 17], fill=(0, 0, 0, 0)); d.point((7, 14), fill=hx("c8b070")); d.point((10, 18), fill=hx("c8b070"))
    elif kind == "chest":
        d.rectangle([3, 9, 20, 20], fill=hx("8a5a2a")); d.rectangle([3, 6, 20, 11], fill=hx("a87a3a")); d.rectangle([10, 10, 13, 14], fill=GOLD); d.rectangle([3, 12, 20, 13], fill=INK2)
    elif kind == "flag":
        d.line([(8, 22), (8, 2)], fill=INK2, width=2); d.polygon([(9, 2), (20, 6), (9, 10)], fill=RED)
    return outline(im)

sheet = Image.new("RGBA", (S * len(ORDER), S), (0, 0, 0, 0))
for i, k in enumerate(ORDER): sheet.paste(icon(k), (i * S, 0))
sheet.save(os.path.join(OUT, "map_icons.png"))

# Пергамент: шум + плями, безшовна плитка 256×256
random.seed(3)
P = 256
par = Image.new("RGB", (P, P), (232, 214, 176)); px = par.load()
for y in range(P):
    for x in range(P):
        n = random.randint(-10, 10); px[x, y] = (232 + n, 214 + n, 176 + n - 4)
d = ImageDraw.Draw(par)
for i in range(40):
    cx, cy, r = random.randint(0, P), random.randint(0, P), random.randint(10, 40); c = random.randint(-14, -4)
    for ox in (0, -P, P):
        for oy in (0, -P, P):
            d.ellipse([cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r], fill=(232 + c, 214 + c, 176 + c - 6))
par = par.filter(ImageFilter.GaussianBlur(1.2))
par.save(os.path.join(OUT, "map_parchment.png"))
print("ok map icons", len(ORDER))
