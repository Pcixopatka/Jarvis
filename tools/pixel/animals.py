#!/usr/bin/env python3
"""Звірі для полювання й риба для рибалки.
→ assets/gfx/sprites/animals.png: 3 ряди (заєць, олень, вепр) × 3 кадри 48×32 (біг 1, біг 2, лежить), дивляться праворуч.
→ assets/gfx/sprites/fishing.png: ряд 48×24: карась, щука, сом, поплавок, поплавок під водою, сплеск."""
import os
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites")
def hx(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
O = hx("2a1c12")

def outline(im):
    src = im.load(); out = im.copy(); o = out.load(); w, h = im.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0 and src[nx, ny] != O:
                        o[x, y] = O; break
    return out

def hare(f):
    im = Image.new("RGBA", (48, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    c = hx("a8906a"); c2 = hx("8a7250"); w = hx("efe6d6")
    if f == 2:
        d.ellipse([12, 20, 34, 29], fill=c); d.ellipse([30, 19, 40, 27], fill=c); d.rectangle([36, 15, 43, 18], fill=c2); d.ellipse([9, 22, 14, 27], fill=w)
        return outline(im)
    stretch = 3 if f == 0 else 0
    d.ellipse([12 - stretch, 16, 32, 26], fill=c); d.ellipse([28, 11, 39, 20], fill=c)
    d.rectangle([32, 3, 34, 12], fill=c2); d.rectangle([36, 4, 38, 12], fill=c)
    d.ellipse([8 - stretch, 17, 13 - stretch, 22], fill=w); d.point((36, 14), fill=O)
    if f == 0:
        d.line([(14, 25), (6, 28)], fill=c2, width=3); d.line([(28, 25), (36, 29)], fill=c2, width=3)
    else:
        d.line([(16, 25), (20, 30)], fill=c2, width=3); d.line([(27, 25), (24, 30)], fill=c2, width=3)
    return outline(im)

def deer(f):
    im = Image.new("RGBA", (48, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    c = hx("a8703a"); c2 = hx("86562a"); w = hx("efe0c8"); horn = hx("d8c8a0")
    if f == 2:
        d.ellipse([6, 18, 34, 29], fill=c); d.ellipse([30, 20, 42, 28], fill=c); d.line([(40, 20), (45, 14)], fill=horn, width=1); d.line([(42, 22), (47, 18)], fill=horn, width=1)
        d.line([(10, 28), (4, 30)], fill=c2, width=2); d.line([(26, 28), (32, 31)], fill=c2, width=2)
        return outline(im)
    d.ellipse([6, 12, 32, 23], fill=c); d.polygon([(28, 14), (36, 6), (40, 9), (33, 18)], fill=c); d.ellipse([34, 4, 44, 11], fill=c)
    d.line([(37, 4), (35, 0)], fill=horn, width=1); d.line([(35, 2), (32, 0)], fill=horn, width=1); d.line([(40, 4), (42, 0)], fill=horn, width=1); d.line([(42, 2), (45, 1)], fill=horn, width=1)
    d.ellipse([4, 12, 9, 17], fill=w); d.point((41, 7), fill=O)
    if f == 0:
        for (x0, x1) in ((9, 4), (14, 12), (26, 30), (30, 37)): d.line([(x0, 22), (x1, 31)], fill=c2, width=2)
    else:
        for (x0, x1) in ((9, 11), (14, 15), (26, 25), (30, 31)): d.line([(x0, 22), (x1, 31)], fill=c2, width=2)
    return outline(im)

def boar(f):
    im = Image.new("RGBA", (48, 32), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    c = hx("4a3a30"); c2 = hx("332820"); t = hx("f0ead8")
    if f == 2:
        d.ellipse([6, 16, 38, 30], fill=c); d.ellipse([32, 18, 45, 29], fill=c); d.line([(42, 24), (46, 21)], fill=t, width=2)
        d.line([(12, 29), (8, 31)], fill=c2, width=3); d.line([(28, 29), (33, 31)], fill=c2, width=3)
        return outline(im)
    d.ellipse([5, 9, 36, 25], fill=c); d.ellipse([30, 11, 45, 24], fill=c); d.polygon([(8, 9), (30, 9), (24, 5), (12, 5)], fill=c2)
    d.rectangle([43, 17, 46, 21], fill=hx("6a5448")); d.line([(41, 21), (44, 17)], fill=t, width=2); d.point((39, 15), fill=hx("ff4030"))
    d.line([(5, 14), (2, 10)], fill=c2, width=2)
    if f == 0:
        for (x0, x1) in ((10, 6), (15, 13), (28, 31), (33, 37)): d.line([(x0, 24), (x1, 31)], fill=c2, width=3)
    else:
        for (x0, x1) in ((10, 11), (15, 16), (28, 27), (33, 33)): d.line([(x0, 24), (x1, 31)], fill=c2, width=3)
    return outline(im)

sheet = Image.new("RGBA", (48 * 3, 32 * 3), (0, 0, 0, 0))
for r, fn in enumerate((hare, deer, boar)):
    for f in range(3):
        sheet.paste(fn(f), (f * 48, r * 32))
sheet.save(os.path.join(OUT, "animals.png"))

def fish(kind):
    im = Image.new("RGBA", (48, 24), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    if kind == "karas":
        c = hx("c8a850"); d.ellipse([10, 5, 34, 19], fill=c); d.polygon([(32, 12), (42, 5), (42, 19)], fill=hx("a88a3a")); d.polygon([(18, 5), (26, 5), (22, 1)], fill=hx("a88a3a")); d.point((15, 10), fill=O)
    elif kind == "shchuka":
        c = hx("6a8a50"); d.ellipse([4, 8, 38, 17], fill=c); d.polygon([(2, 12), (10, 9), (10, 15)], fill=hx("56723e")); d.polygon([(36, 12), (46, 6), (46, 18)], fill=hx("56723e"))
        for x in range(14, 34, 5): d.point((x, 11), fill=hx("d8e0b0"))
        d.point((9, 11), fill=O)
    elif kind == "som":
        c = hx("4a5560"); d.ellipse([2, 4, 36, 20], fill=c); d.polygon([(32, 12), (47, 4), (44, 12), (47, 20)], fill=hx("3a444e")); d.ellipse([4, 12, 30, 20], fill=hx("8a96a0"))
        d.line([(4, 13), (0, 18)], fill=O, width=1); d.line([(6, 15), (3, 21)], fill=O, width=1); d.point((9, 9), fill=hx("f0f0f0"))
    elif kind == "float":
        d.line([(24, 0), (24, 8)], fill=hx("3a2a1a"), width=1); d.ellipse([19, 6, 29, 16], fill=hx("d8402e")); d.rectangle([19, 11, 29, 16], fill=hx("f0f0f0")); d.ellipse([19, 12, 29, 18], fill=hx("f0f0f0"))
        d.arc([12, 14, 36, 22], 0, 180, fill=hx("cfe8ff"), width=1)
    elif kind == "float_dip":
        d.line([(24, 6), (24, 12)], fill=hx("3a2a1a"), width=1); d.pieslice([19, 10, 29, 20], 180, 360, fill=hx("d8402e"))
        d.arc([8, 12, 40, 22], 0, 180, fill=hx("ffffff"), width=1); d.arc([14, 14, 34, 21], 0, 180, fill=hx("cfe8ff"), width=1)
    elif kind == "splash":
        for (x, y) in ((10, 14), (16, 6), (24, 3), (32, 6), (38, 14), (20, 12), (28, 12)): d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=hx("cfe8ff"))
        d.arc([6, 12, 42, 24], 0, 180, fill=hx("ffffff"), width=2)
    return outline(im)

kinds = ["karas", "shchuka", "som", "float", "float_dip", "splash"]
fs = Image.new("RGBA", (48 * len(kinds), 24), (0, 0, 0, 0))
for i, k in enumerate(kinds): fs.paste(fish(k), (i * 48, 0))
fs.save(os.path.join(OUT, "fishing.png"))
print("ok animals & fishing")
