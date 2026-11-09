#!/usr/bin/env python3
"""Генератор піксельних спрайтів 48×48 для «Козацької Звитяги».
Кожен лист: 3 ряди (вниз, вгору, вбік-ліворуч) × 8 кадрів: стоїть, крок 1–4, удар 1–3.
Запуск: python3 tools/pixel/sprites.py  →  assets/gfx/sprites/<id>.png
"""
import os, sys
from PIL import Image, ImageDraw

S = 48
FRAMES = ["idle", "walk0", "walk1", "walk2", "walk3", "atk0", "atk1", "atk2"]
DIRS = ["down", "up", "side"]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites")

def hexc(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

SKIN = hexc("f1c9a0"); SKIN_D = hexc("c8956a"); OUT_C = hexc("1b1420")

class Px:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); self.d = ImageDraw.Draw(self.im)
    def rect(self, x, y, w, h, c):
        if w <= 0 or h <= 0: return
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
    def ell(self, x, y, w, h, c):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)
    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line([x0, y0, x1, y1], fill=c, width=w)
    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S: self.im.putpixel((x, y), c)
    def poly(self, pts, c):
        self.d.polygon(pts, fill=c)
    def shade(self):
        """Світло зліва-зверху: правий край кожного горизонтального ряду трохи темніший."""
        px = self.im.load()
        for y in range(S):
            x = 0
            while x < S:
                if px[x, y][3] == 0:
                    x += 1; continue
                x0 = x
                while x < S and px[x, y][3] > 0 and px[x, y] == px[x0, y]:
                    x += 1
                n = x - x0
                if n >= 4:
                    for k in range(x - max(1, n // 4), x):
                        r, g, b, a = px[k, y]; px[k, y] = (int(r * 0.82), int(g * 0.82), int(b * 0.82), a)
    def outline(self):
        src = self.im.load(); out = self.im.copy(); o = out.load()
        for y in range(S):
            for x in range(S):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < S and 0 <= ny < S and src[nx, ny][3] > 0 and src[nx, ny] != OUT_C:
                            o[x, y] = OUT_C; break
        self.im = out

# ---------- кадр: поза ----------
def pose(frame):
    """Повертає (зсув лівої ноги, зсув правої ноги, підскок, фаза удару 0..3)."""
    if frame.startswith("walk"):
        i = int(frame[4]); legs = [(-3, 3), (0, 0), (3, -3), (0, 0)][i]; bob = [0, -1, 0, -1][i]
        return legs[0], legs[1], bob, 0
    if frame.startswith("atk"):
        return 0, 0, 0, int(frame[3]) + 1
    return 0, 0, 0, 0

def humanoid(p, d, frame, c):
    """Базова людська фігура. c — словник кольорів і прикмет."""
    ll, lr, bob, atk = pose(frame)
    cx = 24; ground = 42
    side = d == "side"
    # Ноги / штани
    pants = c["pants"]; boots = c["boots"]
    if side:
        p.rect(cx - 5 + ll // 2, ground - 12 + bob, 6, 9, pants); p.rect(cx - 1 + lr // 2, ground - 12 + bob, 6, 9, pants)
        p.rect(cx - 6 + ll // 2, ground - 4 + bob, 7, 4, boots); p.rect(cx - 1 + lr // 2, ground - 4 + bob, 7, 4, boots)
    else:
        p.rect(cx - 9, ground - 12 + bob + ll // 3, 8, 9, pants); p.rect(cx + 1, ground - 12 + bob + lr // 3, 8, 9, pants)
        p.rect(cx - 10, ground - 4 + bob + ll // 3, 9, 4, boots); p.rect(cx + 1, ground - 4 + bob + lr // 3, 9, 4, boots)
    # Тулуб
    body = c["body"]; by = ground - 26 + bob
    if c.get("robe"):
        p.poly([(cx - 8, by), (cx + 8, by), (cx + 11, ground - 6 + bob), (cx - 11, ground - 6 + bob)], body)
    else:
        p.rect(cx - 8, by, 16, 15, body)
    if c.get("sash"):
        p.rect(cx - 8, by + 10, 16, 3, c["sash"])
    if c.get("trim") and not side:
        p.rect(cx - 1, by, 2, 10, c["trim"])
    if c.get("cape") and (d == "up" or side):
        p.poly([(cx - 9, by + 1), (cx + 9, by + 1), (cx + 7, ground - 7 + bob), (cx - 7, ground - 7 + bob)], c["cape"])
    # Руки
    arm = c.get("sleeve", body)
    if side:
        p.rect(cx - 2, by + 2, 5, 11, arm); p.rect(cx - 2, by + 12, 5, 3, SKIN)
    else:
        p.rect(cx - 12, by + 2, 4, 11, arm); p.rect(cx + 8, by + 2, 4, 11, arm)
        p.rect(cx - 12, by + 12, 4, 3, SKIN); p.rect(cx + 8, by + 12, 4, 3, SKIN)
    # Голова (велика, «чібі»)
    hy = by - 15
    skin = c.get("skin", SKIN)
    p.ell(cx - 8, hy - 1, 17, 17, skin)
    if d != "up":
        ex = cx - 3 if not side else cx - 5
        p.px(ex, hy + 7, OUT_C); p.px(ex + (6 if not side else 0), hy + 7, OUT_C)
        if side: p.px(cx - 5, hy + 7, OUT_C)
        if c.get("mustache"):
            p.rect(cx - 4 if not side else cx - 7, hy + 10, 8 if not side else 5, 1, c["hair"])
        if c.get("beard"):
            p.rect(cx - 5, hy + 11, 10, 5, c["beard"])
        if c.get("red_eyes"):
            ex2 = cx - 3 if not side else cx - 5
            p.px(ex2, hy + 7, (255, 40, 40, 255)); p.px(ex2 + (6 if not side else 0), hy + 7, (255, 40, 40, 255))
    # Зачіска / шапка
    hair = c["hair"]
    if c.get("hat") == "shapka":
        p.rect(cx - 8, hy - 3, 16, 6, c["hat_col"]); p.rect(cx - 7, hy - 5, 14, 3, c["hat_col"])
        if c.get("shlyk"): p.rect(cx + 3 if not side else cx - 9, hy - 7, 4, 5, c["shlyk"])
    elif c.get("hat") == "straw":
        p.ell(cx - 11, hy - 1, 22, 6, c["hat_col"]); p.rect(cx - 6, hy - 5, 12, 5, c["hat_col"])
    elif c.get("hat") == "horns":
        p.rect(cx - 8, hy - 4, 2, 6, c["hat_col"]); p.rect(cx + 6, hy - 4, 2, 6, c["hat_col"])
        p.px(cx - 8, hy - 5, c["hat_col"]); p.px(cx + 7, hy - 5, c["hat_col"])
        p.rect(cx - 5, hy - 1, 10, 3, hair)
    elif c.get("hat") == "oseledets":
        p.rect(cx - 2, hy - 3, 4, 3, hair)
        if side: p.line(cx - 1, hy - 2, cx + 5, hy + 2, hair, 2)
        else: p.line(cx + 1, hy - 2, cx + 5, hy + 3, hair, 2)
    elif c.get("hat") == "hood":
        p.ell(cx - 8, hy - 2, 16, 10, c["hat_col"]); p.rect(cx - 8, hy + 3, 16, 4, c["hat_col"])
    else:
        p.rect(cx - 7, hy - 1, 14, 5, hair)
    if d == "up":
        p.ell(cx - 8, hy - 1, 17, 17, skin); p.rect(cx - 8, hy - 1, 17, 10, hair if c.get("hat") not in ("shapka", "straw", "hood") else c["hat_col"])
    # Зброя
    weapon(p, d, frame, c, cx, by, atk)
    p.shade()
    p.outline()

def weapon(p, d, frame, c, cx, by, atk):
    kind = c.get("weapon")
    if not kind: return
    side = d == "side"
    hx = (cx - 1) if side else cx + 10
    hy = by + 13
    col = c.get("weapon_col", hexc("d9dde6")); handle = hexc("6b4a2a")
    if kind == "sabre":
        # Шабля: у спокої опущена, під час удару — дуга
        if atk == 0:
            p.line(hx, hy, hx + (-10 if side else 6), hy + 12, col, 2)
        elif atk == 1:
            p.line(hx, hy, hx + (-4 if side else 10), hy - 16, col, 2)
        elif atk == 2:
            p.line(hx, hy, hx + (-18 if side else 16), hy - 6, col, 2)
        else:
            p.line(hx, hy, hx + (-16 if side else 12), hy + 10, col, 2)
        p.rect(hx - 1, hy - 1, 3, 3, handle)
    elif kind == "pike":
        if atk == 0:
            p.line(hx, hy + 8, hx + (-6 if side else 2), hy - 22, handle, 2)
            p.poly([(hx + (-6 if side else 2), hy - 24), (hx + (-8 if side else 0), hy - 19), (hx + (-4 if side else 4), hy - 19)], col)
        else:
            dx = -22 if side else 14
            p.line(hx, hy, hx + dx, hy - 2 - atk * 3, handle, 2)
            p.poly([(hx + dx + (-4 if side else 4), hy - 3 - atk * 3), (hx + dx, hy - 6 - atk * 3), (hx + dx, hy + 1 - atk * 3)], col)
    elif kind == "staff":
        p.line(hx, hy + 8, hx, hy - 26, handle, 2)
        p.ell(hx - 3, hy - 30, 6, 6, hexc("ffb347"))
    elif kind == "claws":
        if atk:
            for i in range(3):
                p.line(hx, hy, hx + (-10 if side else 8) - i * 2, hy - 4 + i * 4, col, 1)

CHARS = {
    "cossack": dict(pants=hexc("2e4fb0"), boots=hexc("a3231f"), body=hexc("f3eadb"), sash=hexc("c6281e"), trim=hexc("c6281e"),
                    hair=hexc("3a2518"), hat="oseledets", mustache=True, weapon="sabre"),
    "peasant": dict(pants=hexc("b9a98a"), boots=hexc("6e4b2a"), body=hexc("efe6d2"), sash=hexc("7a4a1f"),
                    hair=hexc("5a3a1e"), hat="straw", hat_col=hexc("d8b35c"), weapon="pike", weapon_col=hexc("8c8c8c")),
    "volkhv": dict(pants=hexc("e8e2d4"), boots=hexc("6e4b2a"), body=hexc("f6f1e6"), robe=True, sash=hexc("b8261c"),
                   hair=hexc("d9d2c4"), beard=hexc("d9d2c4"), weapon="staff"),
    "zarazhenyi": dict(pants=hexc("4a2a22"), boots=hexc("2a1a14"), body=hexc("7a1f1d"), sleeve=hexc("6a1a18"), sash=hexc("3d2b1a"),
                       skin=hexc("a8c48a"), hair=hexc("2a1a10"), hat="shapka", hat_col=hexc("3a2a22"), weapon="pike", weapon_col=hexc("9a9a9a"), red_eyes=True),
    "chort": dict(pants=hexc("6b2412"), boots=hexc("3a1208"), body=hexc("8e2f14"), sleeve=hexc("8e2f14"),
                  skin=hexc("b84a22"), hair=hexc("3a1208"), hat="horns", hat_col=hexc("2a1208"), weapon="claws", weapon_col=hexc("e8d8c0"), tail=True),
    "upyr": dict(pants=hexc("2a1a2a"), boots=hexc("1a0f1a"), body=hexc("5a1020"), sleeve=hexc("5a1020"), cape=hexc("3a0a18"),
                 skin=hexc("d8d0dc"), hair=hexc("1a1018"), weapon="claws", weapon_col=hexc("eeeeee"), red_eyes=True),
}

def build(cid):
    c = CHARS[cid]
    sheet = Image.new("RGBA", (S * len(FRAMES), S * len(DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for f, frame in enumerate(FRAMES):
            p = Px(); humanoid(p, d, frame, c)
            sheet.paste(p.im, (f * S, r * S))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, cid + ".png"))

if __name__ == "__main__":
    ids = sys.argv[1:] or list(CHARS.keys())
    for cid in ids:
        build(cid); print("ok", cid)
