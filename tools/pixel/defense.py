#!/usr/bin/env python3
"""Мури для оборони: частокіл, брама, вежа міста; тин і ворітця хутора. → assets/gfx/sprites/defense.png
Клітинки (x, y, w, h) у REGIONS записано в scripts/world/gfx.gd (DEFENSE)."""
import os, random
from PIL import Image, ImageDraw
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites", "defense.png")
def hx(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
O = hx("2a1c12"); WOOD = hx("9a6a3a"); WOOD_D = hx("7a5028"); WOOD_L = hx("b88a52"); TIP = hx("c8a070"); IRON = hx("4a4a52"); STRAW = hx("c8a850"); WHITE = hx("f0e6d0")
random.seed(5)

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

def logs(d, x0, y0, w, h, step=8, tips=True):
    for i in range(w // step):
        x = x0 + i * step; top = y0 + random.randint(0, 3)
        d.rectangle([x, top + (4 if tips else 0), x + step - 2, y0 + h], fill=WOOD if i % 2 else WOOD_L)
        d.line([(x + step - 2, top + 4), (x + step - 2, y0 + h)], fill=WOOD_D, width=1)
        if tips: d.polygon([(x, top + 4), (x + step - 2, top + 4), (x + (step - 2) // 2, top)], fill=TIP)

def palisade(broken=False):
    im = Image.new("RGBA", (32, 72), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    logs(d, 0, 2, 32, 68)
    d.rectangle([0, 30, 31, 33], fill=WOOD_D); d.rectangle([0, 56, 31, 59], fill=WOOD_D)
    if broken:
        d.rectangle([8, 0, 23, 34], fill=(0, 0, 0, 0)); d.polygon([(8, 36), (14, 20), (18, 36)], fill=WOOD_D)
    return outline(im)

def gate(state):  # "closed", "broken"
    im = Image.new("RGBA", (96, 88), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    logs(d, 0, 10, 20, 78); logs(d, 76, 10, 20, 78)
    d.rectangle([14, 0, 81, 14], fill=WOOD_D); d.rectangle([16, 2, 79, 6], fill=WOOD_L)
    for x in range(18, 80, 10): d.polygon([(x, 0), (x + 6, 0), (x + 3, -4)], fill=TIP)
    if state == "closed":
        for x in range(20, 76, 7): d.rectangle([x, 16, x + 5, 86], fill=WOOD if (x // 7) % 2 else WOOD_L)
        d.rectangle([20, 34, 75, 38], fill=IRON); d.rectangle([20, 66, 75, 70], fill=IRON); d.rectangle([46, 16, 49, 86], fill=WOOD_D)
        for x in (24, 70): d.rectangle([x, 35, x + 2, 37], fill=hx("8a8a92")); d.rectangle([x, 67, x + 2, 69], fill=hx("8a8a92"))
    else:
        d.polygon([(20, 86), (26, 40), (34, 86)], fill=WOOD_D); d.polygon([(60, 86), (72, 50), (76, 86)], fill=WOOD); d.rectangle([20, 16, 75, 22], fill=WOOD_D)
        d.rectangle([36, 80, 58, 86], fill=WOOD_D)
    return outline(im)

def tower():
    im = Image.new("RGBA", (56, 104), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    logs(d, 4, 30, 48, 74, tips=False)
    d.rectangle([0, 22, 55, 34], fill=WOOD_D); d.rectangle([2, 24, 53, 27], fill=WOOD_L)
    for x in range(2, 54, 10): d.rectangle([x, 14, x + 5, 24], fill=WOOD_L)
    d.polygon([(0, 16), (55, 16), (28, 0)], fill=hx("6a4a2a")); d.rectangle([22, 44, 33, 58], fill=O); d.rectangle([22, 74, 33, 88], fill=O)
    d.rectangle([27, 46, 28, 56], fill=hx("ffb040")); d.rectangle([27, 76, 28, 86], fill=hx("ffb040"))
    return outline(im)

def fence():  # тин хутора
    im = Image.new("RGBA", (32, 44), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for x in (2, 16, 29): d.rectangle([x, 4, x + 2, 42], fill=WOOD_D)
    for y in (12, 22, 32):
        for x in range(0, 32, 6): d.line([(x, y + (x % 12) // 6), (x + 6, y + 1 - (x % 12) // 6)], fill=WOOD_L, width=2)
    return outline(im)

def camp_gate(state):
    im = Image.new("RGBA", (80, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rectangle([6, 0, 10, 62], fill=WOOD_D); d.rectangle([69, 0, 73, 62], fill=WOOD_D); d.rectangle([0, 0, 79, 6], fill=WOOD)
    d.rectangle([34, 0, 45, 4], fill=STRAW)
    if state == "closed":
        for y in (16, 30, 44): d.rectangle([12, y, 67, y + 5], fill=WOOD_L)
        d.line([(12, 16), (67, 49)], fill=WOOD, width=4)
    else:
        d.rectangle([12, 30, 40, 35], fill=WOOD_L); d.polygon([(44, 62), (62, 20), (66, 62)], fill=WOOD)
    return outline(im)

parts = [("palisade", palisade()), ("palisade_broken", palisade(True)), ("gate", gate("closed")), ("gate_broken", gate("broken")),
         ("tower", tower()), ("fence", fence()), ("camp_gate", camp_gate("closed")), ("camp_gate_broken", camp_gate("broken"))]
W = sum(p.width + 2 for _, p in parts); H = max(p.height for _, p in parts)
sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0)); x = 0; regions = {}
for name, p in parts:
    sheet.paste(p, (x, H - p.height)); regions[name] = (x, H - p.height, p.width, p.height); x += p.width + 2
sheet.save(OUT)
print("const DEFENSE := {")
for n, r in regions.items(): print('\t"%s": Rect2(%d, %d, %d, %d),' % ((n,) + r))
print("}")
