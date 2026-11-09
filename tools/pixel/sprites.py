#!/usr/bin/env python3
"""Генератор піксельних спрайтів 48×48 для «Козацької Звитяги» (v2).
Лист: 3 ряди (вниз, вгору, вбік-ліворуч) × 10 кадрів: стоїть, крок 1–4, удар 1–3, поранений, лежить.
Запуск: python3 tools/pixel/sprites.py [id ...]  →  assets/gfx/sprites/<id>.png
"""
import os, sys
from PIL import Image, ImageDraw

S = 48
FRAMES = ["idle", "walk0", "walk1", "walk2", "walk3", "atk0", "atk1", "atk2", "hurt", "dead"]
DIRS = ["down", "up", "side"]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites")
CX, GROUND = 24, 43
OUT_C = (27, 20, 32, 255)
WHITE = (250, 250, 250, 255)
BLACK = (20, 16, 24, 255)

def hexc(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def mul(c, k):
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), c[3])

class Px:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); self.d = ImageDraw.Draw(self.im)
    def rect(self, x, y, w, h, c):
        if w > 0 and h > 0: self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)
    def rect_sh(self, x, y, w, h, c, k=0.78):
        """Прямокутник із тінню праворуч і внизу."""
        self.rect(x, y, w, h, c)
        if w >= 4: self.rect(x + w - max(1, w // 4), y, max(1, w // 4), h, mul(c, k))
        if h >= 4: self.rect(x, y + h - 1, w, 1, mul(c, k))
    def ell(self, x, y, w, h, c):
        self.d.ellipse([x, y, x + w - 1, y + h - 1], fill=c)
    def ell_sh(self, x, y, w, h, c, k=0.78):
        self.ell(x, y, w, h, c)
        shade = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sd = ImageDraw.Draw(shade)
        sd.ellipse([x, y, x + w - 1, y + h - 1], fill=mul(c, k))
        mask = Image.new("L", (S, S), 0); md = ImageDraw.Draw(mask)
        md.ellipse([x + w // 3, y + h // 3, x + w - 1, y + h - 1], fill=255)
        md.ellipse([x, y, x + w - 2 - w // 5, y + h - 2 - h // 5], fill=0)
        self.im.paste(shade, (0, 0), mask); self.d = ImageDraw.Draw(self.im)
    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line([x0, y0, x1, y1], fill=c, width=w)
    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S: self.im.putpixel((x, y), c)
    def poly(self, pts, c):
        self.d.polygon(pts, fill=c)
    def outline(self):
        src = self.im.load(); out = self.im.copy(); o = out.load()
        for y in range(S):
            for x in range(S):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < S and 0 <= ny < S and src[nx, ny][3] > 0 and src[nx, ny] != OUT_C:
                            o[x, y] = OUT_C; break
        self.im = out; self.d = ImageDraw.Draw(self.im)
    def flip(self):
        self.im = self.im.transpose(Image.FLIP_LEFT_RIGHT); self.d = ImageDraw.Draw(self.im)
    def rotate_dead(self):
        """Лежить: повернути на 90° і опустити на землю."""
        im = self.im.rotate(90, resample=Image.NEAREST, expand=False)
        bbox = im.getbbox()
        if bbox:
            dy = (GROUND + 2) - bbox[3]
            im = im.transform(im.size, Image.AFFINE, (1, 0, 0, 0, 1, -dy))
        self.im = im; self.d = ImageDraw.Draw(self.im)


# ---------- поза ----------
def pose(frame):
    """(зсув лівої ноги, зсув правої ноги, підскок, фаза удару 0..3, мах рук)."""
    if frame.startswith("walk"):
        i = int(frame[4]); legs = [(-3, 3), (0, 0), (3, -3), (0, 0)][i]; bob = [0, -1, 0, -1][i]
        return legs[0], legs[1], bob, 0, [1, 0, -1, 0][i]
    if frame.startswith("atk"):
        return 0, 0, 0, int(frame[3]) + 1, 0
    if frame == "hurt":
        return 0, 0, 1, 0, 0
    return 0, 0, 0, 0, 0


def eyes(p, d, hy, c, side):
    """Очі 2×2 з білком; у «вбік» одне око."""
    col = c.get("eye", BLACK)
    if d == "up": return
    if side:
        p.rect(CX - 6, hy + 8, 2, 2, WHITE); p.px(CX - 6, hy + 9, col)
    else:
        p.rect(CX - 5, hy + 8, 2, 2, WHITE); p.rect(CX + 3, hy + 8, 2, 2, WHITE)
        p.px(CX - 4, hy + 9, col); p.px(CX + 3, hy + 9, col)
    if c.get("brows"):
        if side: p.rect(CX - 7, hy + 6, 4, 1, c["hair"])
        else: p.rect(CX - 6, hy + 6, 4, 1, c["hair"]); p.rect(CX + 2, hy + 6, 4, 1, c["hair"])


def hair_and_hat(p, d, hy, c, side):
    hair = c["hair"]; style = c.get("hat", "hair")
    hc = c.get("hat_col", hair)
    if d == "up":
        if style in ("shapka", "straw", "hood", "helmet"):
            p.rect_sh(CX - 9, hy - 2, 19, 11, hc)
        else:
            p.rect_sh(CX - 8, hy - 1, 17, 10, hair)
        if style == "oseledets":
            p.rect(CX - 2, hy - 4, 4, 4, hair); p.line(CX, hy - 3, CX + 5, hy + 1, hair, 2)
        if style == "shapka" and c.get("shlyk"):
            p.rect(CX - 2, hy - 7, 5, 6, c["shlyk"])
        return
    if style == "shapka":  # смушкова шапка зі шликом
        p.rect_sh(CX - 9, hy - 3, 19, 8, hc)
        p.rect(CX - 8, hy - 5, 17, 3, hc)
        if c.get("shlyk"):
            p.rect(CX - 9 if side else CX + 4, hy - 9, 5, 6, c["shlyk"]); p.rect(CX - 8 if side else CX + 5, hy - 10, 3, 2, mul(c["shlyk"], 0.8))
    elif style == "straw":  # бриль
        p.ell(CX - 12, hy + 0, 25, 6, mul(hc, 0.85)); p.rect_sh(CX - 7, hy - 5, 15, 6, hc); p.rect(CX - 7, hy + 1, 15, 1, mul(hc, 0.6))
    elif style == "hood":
        p.ell_sh(CX - 9, hy - 3, 19, 12, hc); p.rect(CX - 9, hy + 3, 19, 4, hc)
    elif style == "helmet":
        p.ell_sh(CX - 9, hy - 3, 19, 12, hc); p.rect(CX - 9, hy + 3, 19, 2, mul(hc, 0.7))
        p.rect(CX - 1, hy - 7, 3, 5, mul(hc, 0.9))
    elif style == "oseledets":  # голений чуб
        p.rect(CX - 3, hy - 3, 6, 4, hair)
        if side: p.line(CX - 2, hy - 2, CX + 6, hy + 3, hair, 3)
        else: p.line(CX + 1, hy - 2, CX + 7, hy + 4, hair, 3)
    elif style == "horns":
        p.rect(CX - 6, hy - 1, 13, 4, hair)
        for sx in (-1, 1):
            x = CX + sx * 8 - (1 if sx < 0 else 0)
            p.rect(x, hy - 4, 2, 7, hc); p.px(x + (0 if sx < 0 else 1), hy - 5, hc); p.px(x + (-1 if sx < 0 else 2), hy - 6, hc)
    elif style == "bald":
        p.rect(CX - 8, hy - 1, 17, 2, mul(c.get("skin", (0, 0, 0, 0)), 0.9))
    elif style == "long":  # довге волосся
        p.rect_sh(CX - 8, hy - 1, 17, 7, hair); p.rect(CX - 9, hy + 5, 4, 10, hair); p.rect(CX + 6, hy + 5, 4, 10, hair)
    else:
        p.rect_sh(CX - 8, hy - 1, 17, 6, hair)


def face(p, d, hy, c, side):
    if d == "up": return
    if c.get("mustache"):
        m = c.get("mustache_col", c["hair"])
        if side: p.rect(CX - 8, hy + 12, 6, 2, m); p.px(CX - 9, hy + 13, m)
        else: p.rect(CX - 6, hy + 12, 5, 2, m); p.rect(CX + 2, hy + 12, 5, 2, m); p.px(CX - 7, hy + 13, m); p.px(CX + 7, hy + 13, m)
    if c.get("beard"):
        b = c["beard"]
        p.rect(CX - 6, hy + 13, 13, 6, b); p.rect(CX - 4, hy + 19, 9, 3, b)
    if c.get("fangs"):
        p.px(CX - 2 if not side else CX - 5, hy + 14, WHITE); p.px(CX + 2 if not side else CX - 4, hy + 14, WHITE)
    if c.get("snout"):  # чортяча пика: ніс п'ятачком
        p.rect(CX - 1 if not side else CX - 8, hy + 11, 3, 2, mul(c["skin"], 0.75))


def humanoid(p, d, frame, c):
    ll, lr, bob, atk, swing = pose(frame)
    side = d == "side"
    pants = c["pants"]; boots = c["boots"]; body = c["body"]; skin = c.get("skin", hexc("f1c9a0"))
    hurt = frame == "hurt"
    by = GROUND - 25 + bob  # верх тулуба
    hy = by - 17            # верх голови
    # ---- хвіст (чорт) ----
    if c.get("tail") and (side or d == "up"):
        p.line(CX + (6 if side else 0), by + 12, CX + (16 if side else 10), by + 18, c["tail"], 2); p.px(CX + (17 if side else 11), by + 19, c["tail"])
    # ---- плащ позаду ----
    if c.get("cape") and d == "down":
        p.poly([(CX - 11, by + 1), (CX + 11, by + 1), (CX + 13, GROUND - 4), (CX - 13, GROUND - 4)], mul(c["cape"], 0.85))
    # ---- ноги ----
    if side:
        p.rect_sh(CX - 5 + ll // 2, GROUND - 12 + bob, 7, 9, pants); p.rect_sh(CX - 1 + lr // 2, GROUND - 12 + bob, 7, 9, pants)
        p.rect(CX - 6 + ll // 2, GROUND - 4 + bob, 8, 4, boots); p.rect(CX - 1 + lr // 2, GROUND - 4 + bob, 8, 4, boots)
    else:
        wide = c.get("wide_pants", False)
        w = 9 if wide else 8
        p.rect_sh(CX - w - 1, GROUND - 12 + bob + ll // 3, w, 9, pants); p.rect_sh(CX + 1, GROUND - 12 + bob + lr // 3, w, 9, pants)
        p.rect(CX - w - 2, GROUND - 4 + bob + ll // 3, w + 1, 4, boots); p.rect(CX + 1, GROUND - 4 + bob + lr // 3, w + 1, 4, boots)
    # ---- тулуб ----
    if c.get("robe"):
        p.poly([(CX - 9, by), (CX + 9, by), (CX + 12, GROUND - 5 + bob), (CX - 12, GROUND - 5 + bob)], body)
        p.rect(CX + 8, by + 2, 3, 16, mul(body, 0.8))
    elif c.get("hump"):
        p.ell_sh(CX - 10, by - 2, 20, 18, body)
    else:
        p.rect_sh(CX - 9, by, 18, 15, body)
    if c.get("vyshyvka") and d == "down":  # вишивка на грудях
        v = c["vyshyvka"]
        for i in range(3):
            p.px(CX - 1, by + 2 + i * 3, v); p.px(CX + 1, by + 3 + i * 3, v)
        p.rect(CX - 1, by + 1, 3, 1, v)
    if c.get("sash"):
        p.rect(CX - 9, by + 10, 18, 3, c["sash"]); p.rect(CX - 9, by + 12, 18, 1, mul(c["sash"], 0.7))
        if d == "down": p.rect(CX + 4, by + 13, 2, 5, c["sash"])
    if c.get("cape") and d != "down":
        p.poly([(CX - 10, by + 1), (CX + 10, by + 1), (CX + 9, GROUND - 6 + bob), (CX - 9, GROUND - 6 + bob)], c["cape"])
        p.rect(CX - 10, by + 1, 20, 2, mul(c["cape"], 1.2))
    # ---- руки ----
    arm = c.get("sleeve", body); hand = skin if not c.get("gloves") else c["gloves"]
    if side:
        ay = by + 3 + (atk and -4) + swing
        p.rect_sh(CX - 3, ay, 5, 10, arm); p.rect(CX - 3, ay + 10, 5, 3, hand)
    else:
        p.rect_sh(CX - 13, by + 2 - swing, 4, 11, arm); p.rect_sh(CX + 9, by + 2 + swing - (4 if atk else 0), 4, 11, arm)
        p.rect(CX - 13, by + 13 - swing, 4, 3, hand); p.rect(CX + 9, by + 13 + swing - (4 if atk else 0), 4, 3, hand)
    # ---- голова ----
    p.ell_sh(CX - 8, hy, 17, 17, skin, 0.85)
    if hurt:
        p.rect(CX - 5, hy + 8, 2, 1, BLACK); p.rect(CX + 3, hy + 8, 2, 1, BLACK)  # заплющені очі
    else:
        eyes(p, d, hy, c, side)
    face(p, d, hy, c, side)
    hair_and_hat(p, d, hy, c, side)
    if c.get("aura"):
        a = c["aura"]
        for i in range(4): p.px(CX - 12 + i * 8, by - 4 - (i % 2) * 3, a)
    # ---- зброя ----
    weapon(p, d, frame, c, by, atk, side)
    p.outline()
    if hurt:
        # Зірочки від удару
        for (x, y) in ((CX - 12, hy - 4), (CX + 11, hy - 6), (CX + 2, hy - 9)):
            p.px(x, y, (255, 230, 90, 255)); p.px(x + 1, y, (255, 230, 90, 255)); p.px(x, y + 1, (255, 230, 90, 255))
    if frame == "dead":
        p.rotate_dead()


def weapon(p, d, frame, c, by, atk, side):
    kind = c.get("weapon")
    if not kind: return
    hx = (CX - 1) if side else CX + 11
    hy = by + 14 - (4 if atk and not side else 0) - (4 if atk and side else 0)
    col = c.get("weapon_col", hexc("dfe4ee")); handle = hexc("6b4a2a"); dark = mul(col, 0.7)
    if kind == "sabre":
        # кут леза за фазою
        pts = {0: (-9, 12), 1: (-5, -16), 2: (-18, -7), 3: (-17, 9)} if side else {0: (6, 12), 1: (10, -16), 2: (17, -6), 3: (13, 10)}
        dx, dy = pts[atk]
        p.line(hx, hy, hx + dx, hy + dy, col, 3)
        p.line(hx + (dx and (1 if dx > 0 else -1)), hy, hx + dx, hy + dy, dark, 1)
        p.rect(hx - 1, hy - 2, 3, 4, handle); p.rect(hx - 2, hy - 1, 5, 1, hexc("d4a63a"))
    elif kind == "mace":
        dx, dy = ({0: (-6, 10), 1: (-4, -16), 2: (-16, -8), 3: (-14, 8)} if side else {0: (5, 10), 1: (8, -16), 2: (15, -6), 3: (12, 8)})[atk]
        p.line(hx, hy, hx + dx, hy + dy, handle, 3); p.ell(hx + dx - 4, hy + dy - 4, 8, 8, col); p.px(hx + dx - 2, hy + dy - 2, WHITE)
    elif kind == "pike":
        if atk == 0:
            p.line(hx, hy + 8, hx + (-5 if side else 2), hy - 24, handle, 2)
            tip = (hx + (-5 if side else 2), hy - 24)
            p.poly([(tip[0], tip[1] - 5), (tip[0] - 2, tip[1] + 2), (tip[0] + 2, tip[1] + 2)], col)
        else:
            dx = (-26 if side else 16) - atk * 2
            p.line(hx + 4, hy, hx + dx, hy - 2, handle, 2)
            p.poly([(hx + dx + (-5 if side else 5), hy - 2), (hx + dx, hy - 5), (hx + dx, hy + 1)], col)
    elif kind == "staff":
        p.line(hx, hy + 8, hx + (atk and (-6 if side else 6)), hy - 26, handle, 3)
        p.ell(hx - 4 + (atk and (-6 if side else 6)), hy - 31, 8, 8, c.get("orb", hexc("ffb347"))); p.px(hx - 2 + (atk and (-6 if side else 6)), hy - 29, WHITE)
    elif kind == "musket":
        p.line(hx - 4, hy + 2, hx + (-24 if side else 20), hy - 4 - atk * 2, handle, 4)
        p.line(hx - 2, hy + 1, hx + (-24 if side else 20), hy - 5 - atk * 2, hexc("8a8f99"), 2)
    elif kind == "claws":
        if atk:
            for i in range(3):
                p.line(hx, hy, hx + (-11 if side else 9) - i, hy - 6 + i * 5, col, 2)
    elif kind == "scythe":
        p.line(hx, hy + 8, hx + (atk and (-6 if side else 6)), hy - 24, handle, 2)
        tip = (hx + (atk and (-6 if side else 6)), hy - 24)
        p.line(tip[0], tip[1], tip[0] + (-14 if side else 14), tip[1] + 4, col, 3)


def build(cid, c):
    sheet = Image.new("RGBA", (S * len(FRAMES), S * len(DIRS)), (0, 0, 0, 0))
    for r, d in enumerate(DIRS):
        for f, frame in enumerate(FRAMES):
            p = Px(); humanoid(p, d, frame, c)
            sheet.paste(p.im, (f * S, r * S))
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, cid + ".png"))


SKIN = hexc("f1c9a0")
CHARS = {
    "cossack": dict(pants=hexc("2f55c2"), wide_pants=True, boots=hexc("b3261e"), body=hexc("f6efe0"), sleeve=hexc("f6efe0"), vyshyvka=hexc("c6281e"),
                    sash=hexc("c6281e"), hair=hexc("3a2518"), hat="oseledets", mustache=True, brows=True, weapon="sabre"),
    "peasant": dict(pants=hexc("b9a98a"), boots=hexc("6e4b2a"), body=hexc("efe6d2"), sleeve=hexc("efe6d2"), sash=hexc("7a4a1f"), vyshyvka=hexc("8a2a1a"),
                    hair=hexc("5a3a1e"), hat="straw", hat_col=hexc("d8b35c"), brows=True, weapon="pike", weapon_col=hexc("9a9a9a")),
    "volkhv": dict(pants=hexc("e8e2d4"), boots=hexc("6e4b2a"), body=hexc("f6f1e6"), sleeve=hexc("f6f1e6"), robe=True, sash=hexc("b8261c"),
                   hair=hexc("d9d2c4"), hat="long", beard=hexc("d9d2c4"), brows=True, weapon="staff", orb=hexc("ffb347")),
    "zarazhenyi": dict(pants=hexc("4a2a22"), boots=hexc("2a1a14"), body=hexc("7a1f1d"), sleeve=hexc("6a1a18"), sash=hexc("3d2b1a"),
                       skin=hexc("a8c48a"), hair=hexc("2a1a10"), hat="shapka", hat_col=hexc("3a2a22"), eye=hexc("ff3030"),
                       weapon="pike", weapon_col=hexc("9a9a9a"), aura=hexc("6fd63a")),
    "chort": dict(pants=hexc("5a1e10"), boots=hexc("2a0e06"), body=hexc("8e2f14"), sleeve=hexc("8e2f14"), hump=True,
                  skin=hexc("b84a22"), hair=hexc("3a1208"), hat="horns", hat_col=hexc("2a1208"), eye=hexc("ffd040"), snout=True,
                  tail=hexc("5a1e10"), weapon="claws", weapon_col=hexc("e8d8c0")),
    "upyr": dict(pants=hexc("2a1a2a"), boots=hexc("1a0f1a"), body=hexc("5a1020"), sleeve=hexc("5a1020"), cape=hexc("3a0a18"), sash=hexc("2a0a14"),
                 skin=hexc("d8d0dc"), hair=hexc("1a1018"), eye=hexc("ff3030"), fangs=True, brows=True, weapon="claws", weapon_col=hexc("eeeeee")),
}

if __name__ == "__main__":
    ids = sys.argv[1:] or list(CHARS.keys())
    for cid in ids:
        build(cid, CHARS[cid]); print("ok", cid)
