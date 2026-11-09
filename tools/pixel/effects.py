#!/usr/bin/env python3
"""Анімовані ефекти вмінь: листи 64×64 × 6 кадрів. Запуск: python3 tools/pixel/effects.py → assets/gfx/sprites/fx_<назва>.png"""
import os, math, random
from PIL import Image, ImageDraw
S = 64; N = 6
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites")
def hx(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
C = 32
random.seed(7)

def frames(fn):
    sheet = Image.new("RGBA", (S * N, S), (0, 0, 0, 0))
    for i in range(N):
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        fn(d, i / (N - 1), i)
        sheet.paste(im, (i * S, 0))
    return sheet

def slash(d, t, i):  # дуга удару: тонка → широка → гасне (праворуч)
    a0 = -70 + t * 20; a1 = a0 + 60 + t * 80; w = int(3 + 6 * math.sin(t * math.pi))
    for k, col in enumerate((hx("ffffff", int(230 * (1 - t * 0.7))), hx("cfe8ff", int(170 * (1 - t * 0.7))))):
        d.arc([4 + k * 3, 4 + k * 3, S - 5 - k * 3, S - 5 - k * 3], a0, a1, fill=col, width=max(1, w - k * 2))
def fire(d, t, i):
    r = int(10 + 24 * t); a = int(255 * (1 - t * t))
    d.ellipse([C - r, C - r, C + r, C + r], fill=hx("ff5a1a", a // 2))
    r2 = int(r * 0.65); d.ellipse([C - r2, C - r2, C + r2, C + r2], fill=hx("ffb030", a))
    r3 = int(r * 0.3); d.ellipse([C - r3, C - r3, C + r3, C + r3], fill=hx("fff2b0", a))
    for k in range(10):
        ang = k * math.pi * 2 / 10 + t; rr = r + 6 + 10 * t
        x, y = C + math.cos(ang) * rr, C + math.sin(ang) * rr; d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=hx("ff8a2a", a))
def lightning(d, t, i):  # вертикальний розряд згори в центр низу
    a = int(255 * (1 - max(0, t - 0.4) / 0.6)); pts = [(C + random.randint(-6, 6), 0)]
    y = 0
    while y < 56: y += 8; pts.append((C + random.randint(-9, 9), y))
    pts.append((C, 58))
    d.line(pts, fill=hx("9ad0ff", a), width=5); d.line(pts, fill=hx("ffffff", a), width=2)
    r = int(6 + 14 * t); d.ellipse([C - r, 58 - r // 2, C + r, 58 + r // 2], fill=hx("cfe8ff", a // 2))
def heal(d, t, i):  # зелені іскри й хрестики, що летять угору
    a = int(255 * (1 - t))
    for k in range(7):
        x = 10 + k * 7 + (k % 2) * 3; y = int(58 - t * 50 - (k % 3) * 8)
        d.rectangle([x - 1, y - 4, x + 1, y + 4], fill=hx("7fe07a", a)); d.rectangle([x - 4, y - 1, x + 4, y + 1], fill=hx("7fe07a", a))
    r = int(20 + 10 * t); d.ellipse([C - r, 40 - r // 3, C + r, 40 + r // 3], outline=hx("bfffb0", a // 2), width=2)
def shield(d, t, i):  # блакитна куля-оберіг спалахує
    r = int(18 + 10 * math.sin(t * math.pi)); a = int(200 * (1 - t * 0.8))
    d.ellipse([C - r, C - r, C + r, C + r], fill=hx("7ab8ff", a // 3), outline=hx("cfe8ff", a), width=2)
    for k in range(6):
        ang = k * math.pi / 3 + t * 2; x, y = C + math.cos(ang) * r, C + math.sin(ang) * r
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=hx("ffffff", a))
def smoke(d, t, i):  # клуби диму (тінь, відвід очей)
    a = int(200 * (1 - t))
    for k in range(6):
        ang = k * math.pi / 3; rr = 6 + 18 * t; r = int(10 + 6 * t)
        x, y = C + math.cos(ang) * rr, C + math.sin(ang) * rr - 8 * t
        d.ellipse([x - r, y - r, x + r, y + r], fill=hx("4a4455", a))
def shockwave(d, t, i):  # кільце, що розходиться (бойовий клич, стіна)
    r = int(6 + 26 * t); a = int(255 * (1 - t))
    d.ellipse([C - r, C - r // 2, C + r, C + r // 2], outline=hx("ffd27a", a), width=max(1, 5 - int(4 * t)))
    d.ellipse([C - r + 4, C - r // 2 + 2, C + r - 4, C + r // 2 - 2], outline=hx("ffffff", a // 2), width=1)
def earth(d, t, i):  # тріщини й каміння від земного удару
    a = int(255 * (1 - t * 0.8))
    for k in range(8):
        ang = k * math.pi / 4 + 0.3; L = 10 + 20 * t
        d.line([(C, C), (C + math.cos(ang) * L, C + math.sin(ang) * L * 0.6)], fill=hx("3a2a1a", a), width=3)
        x, y = C + math.cos(ang) * (L + 4), C + math.sin(ang) * (L + 4) * 0.6 - 10 * math.sin(t * math.pi)
        d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=hx("8a6a3a", a))
def hail(d, t, i):  # градини падають
    a = int(255 * (1 - max(0, t - 0.6) / 0.4))
    for k in range(9):
        x = 6 + k * 6 + (k % 3); y = int((k * 11 + t * 70) % 64)
        d.ellipse([x - 2, y - 3, x + 2, y + 3], fill=hx("dff4ff", a)); d.point((x - 1, y - 1), fill=hx("ffffff", a))
def curse(d, t, i):  # фіолетовий череп спливає
    a = int(255 * (1 - t)); y = int(40 - 20 * t); r = 9
    d.ellipse([C - r, y - r, C + r, y + r], fill=hx("c080ff", a)); d.rectangle([C - 5, y + 6, C + 5, y + 12], fill=hx("c080ff", a))
    d.ellipse([C - 6, y - 3, C - 2, y + 1], fill=hx("2a1040", a)); d.ellipse([C + 2, y - 3, C + 6, y + 1], fill=hx("2a1040", a))
    for k in range(5):
        ang = k * 1.26 + t * 3; rr = 18 + 8 * t
        d.ellipse([C + math.cos(ang) * rr - 2, y + math.sin(ang) * rr - 2, C + math.cos(ang) * rr + 2, y + math.sin(ang) * rr + 2], fill=hx("9a5ad8", a))
def spirit(d, t, i):  # світлий дух з'являється
    a = int(255 * min(1, t * 2)) if t < 0.5 else int(255 * (1 - (t - 0.5) * 2))
    y = int(36 - 10 * t); r = 10
    d.ellipse([C - r, y - r, C + r, y + r], fill=hx("cfe8ff", a)); d.rectangle([C - r, y, C + r, y + 14], fill=hx("cfe8ff", a))
    for x in (C - 10, C - 3, C + 4): d.polygon([(x, y + 14), (x + 6, y + 14), (x + 3, y + 19)], fill=hx("cfe8ff", a))
    d.ellipse([C - 5, y - 3, C - 2, y], fill=hx("1a2a40", a)); d.ellipse([C + 2, y - 3, C + 5, y], fill=hx("1a2a40", a))
def cry(d, t, i):  # помаранчеві звукові дуги
    a = int(255 * (1 - t))
    for k in range(3):
        r = int(8 + k * 8 + 16 * t); d.arc([C - r, C - r, C + r, C + r], -50, 50, fill=hx("ffb060", a), width=3); d.arc([C - r, C - r, C + r, C + r], 130, 230, fill=hx("ffb060", a), width=3)
def wolf(d, t, i):  # сіра аура й жовті очі (вовча подоба)
    a = int(220 * (1 - t)); r = int(14 + 16 * t)
    d.ellipse([C - r, C - r, C + r, C + r], outline=hx("9a9aa0", a), width=3)
    d.ellipse([C - 7, C - 3, C - 3, C + 1], fill=hx("ffd040", a)); d.ellipse([C + 3, C - 3, C + 7, C + 1], fill=hx("ffd040", a))
def gold(d, t, i):  # золотий спалах (куля не бере, заряджений удар)
    a = int(255 * (1 - t)); r = int(8 + 20 * t)
    for k in range(8):
        ang = k * math.pi / 4 + t
        d.line([(C, C), (C + math.cos(ang) * r, C + math.sin(ang) * r)], fill=hx("ffe080", a), width=3)
    d.ellipse([C - 6, C - 6, C + 6, C + 6], fill=hx("fff6c0", a))
def poison(d, t, i):  # зелені бульбашки
    a = int(230 * (1 - t))
    for k in range(7):
        x = 10 + k * 7; y = int(50 - t * 30 - (k % 3) * 6); r = 3 + (k % 2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=hx("7fd02a", a), outline=hx("3a7a10", a))

FX = {"slash": slash, "fire": fire, "lightning": lightning, "heal": heal, "shield": shield, "smoke": smoke, "shockwave": shockwave,
      "earth": earth, "hail": hail, "curse": curse, "spirit": spirit, "cry": cry, "wolf": wolf, "gold": gold, "poison": poison}
for name, fn in FX.items():
    frames(fn).save(os.path.join(OUT, "fx_%s.png" % name))
print("ok", len(FX), "effects")
