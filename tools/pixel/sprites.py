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
    if d == "up" or c.get("skull") or c.get("one_eye"): return
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
        if style in ("shapka", "straw", "hood", "helmet", "kerchief"):
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
    elif style == "kerchief":  # хустка
        p.ell_sh(CX - 9, hy - 3, 19, 12, hc); p.rect(CX - 9, hy + 3, 19, 3, hc); p.rect(CX - 10, hy + 6, 4, 8, hc); p.rect(CX + 7, hy + 6, 4, 8, hc)
    elif style == "wreath":  # вінок зі стрічками
        p.rect_sh(CX - 8, hy - 1, 17, 7, hair); p.rect(CX - 9, hy + 5, 4, 12, hair); p.rect(CX + 6, hy + 5, 4, 12, hair)
        for i, col in enumerate((hexc("ff5a5a"), hexc("ffd23a"), hexc("5aa0ff"), hexc("ff5a5a"), hexc("ffd23a"))):
            p.rect(CX - 8 + i * 4, hy - 2, 3, 2, col)
        p.rect(CX + 7, hy + 1, 2, 9, hexc("ff5a5a")); p.rect(CX + 9, hy + 1, 2, 7, hexc("5aa0ff"))
    elif style == "crown":  # зубчаста корона
        p.rect(CX - 8, hy - 1, 17, 3, hair)
        for i in range(4):
            p.rect(CX - 8 + i * 5, hy - 5, 2, 5, hc); p.rect(CX - 8 + i * 5, hy - 2, 5, 2, hc)
        p.px(CX, hy - 4, hexc("ff3030"))
    elif style == "monomakh":  # шапка Мономаха: хутро й золотий верх із хрестиком
        p.ell_sh(CX - 8, hy - 7, 17, 10, hc); p.rect(CX - 9, hy - 1, 19, 4, hexc("4a3324")); p.rect(CX - 1, hy - 10, 3, 3, hc); p.px(CX, hy - 11, hc)
    elif style == "pointed":  # гостроверха шапка опричника
        p.poly([(CX - 9, hy + 2), (CX + 9, hy + 2), (CX, hy - 11)], hc); p.rect(CX - 9, hy + 1, 19, 3, mul(hc, 0.7))
    elif style == "ears":  # вовчі вуха
        p.rect_sh(CX - 8, hy - 1, 17, 6, hair)
        for sx in (-1, 1):
            x = CX + sx * 7 - (2 if sx < 0 else 0)
            p.poly([(x, hy + 1), (x + 3, hy + 1), (x + 1, hy - 6)], hair); p.px(x + 1, hy - 2, hexc("e8a0a0"))
    elif style == "wolf_ears":  # вовча подоба: лише вуха й сяйво очей
        for sx in (-1, 1):
            x = CX + sx * 7 - (2 if sx < 0 else 0)
            p.poly([(x, hy + 1), (x + 3, hy + 1), (x + 1, hy - 7)], hc); p.px(x + 1, hy - 2, hexc("e8a0a0"))
        if d != "up":
            if side: p.rect(CX - 6, hy + 8, 2, 2, hexc("ffd040"))
            else: p.rect(CX - 5, hy + 8, 2, 2, hexc("ffd040")); p.rect(CX + 3, hy + 8, 2, 2, hexc("ffd040"))
    elif style == "hutsul":  # гуцульський капелюх мольфара
        p.rect(CX - 11, hy + 0, 23, 2, hc); p.rect_sh(CX - 7, hy - 6, 15, 7, hc); p.rect(CX - 7, hy - 1, 15, 1, hexc("c0302a"))
    elif style == "oak":  # дубовий вінок волхва
        p.rect_sh(CX - 8, hy - 1, 17, 7, hair); p.rect(CX - 9, hy + 5, 4, 10, hair); p.rect(CX + 6, hy + 5, 4, 10, hair)
        for i in range(5): p.rect(CX - 8 + i * 4, hy - 2, 3, 2, hc if i % 2 else mul(hc, 0.8))
    elif style == "moss":  # болотяник: мох і очерет на голові
        p.rect_sh(CX - 9, hy - 2, 19, 7, hair)
        for i in range(4): p.line(CX - 7 + i * 5, hy - 2, CX - 8 + i * 5, hy - 9, hexc("8aa040"), 1); p.px(CX - 8 + i * 5, hy - 10, hexc("6a4a20"))
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
    if c.get("muzzle"):  # вовча паща
        m = c["skin"]
        if side: p.rect(CX - 12, hy + 9, 7, 6, m); p.rect(CX - 13, hy + 11, 3, 2, BLACK); p.px(CX - 9, hy + 14, WHITE); p.px(CX - 7, hy + 14, WHITE)
        else: p.rect(CX - 3, hy + 10, 7, 6, m); p.rect(CX - 1, hy + 11, 3, 2, BLACK); p.px(CX - 2, hy + 15, WHITE); p.px(CX + 2, hy + 15, WHITE)
    if c.get("skull"):  # череп: порожні очниці із зеленим вогнем, зуби
        g = hexc("6fff5a")
        if side: p.rect(CX - 7, hy + 7, 3, 3, BLACK); p.px(CX - 6, hy + 8, g)
        else: p.rect(CX - 6, hy + 7, 3, 3, BLACK); p.rect(CX + 3, hy + 7, 3, 3, BLACK); p.px(CX - 5, hy + 8, g); p.px(CX + 4, hy + 8, g)
        for i in range(4): p.px(CX - 4 + i * 2 - (3 if side else 0), hy + 13, BLACK)
    if c.get("one_eye"):
        p.rect(CX - 4 if not side else CX - 8, hy + 5, 8 if not side else 6, 7, WHITE)
        p.rect(CX - 1 if not side else CX - 6, hy + 7, 3, 3, hexc("d02020")); p.px(CX if not side else CX - 5, hy + 8, BLACK)


def humanoid(p, d, frame, c):
    ll, lr, bob, atk, swing = pose(frame)
    side = d == "side"
    if c.get("only_hat"):
        # Накладка: лише шапка/вуха на місці голови (для вдягненої шапки й вовчої подоби)
        hy = GROUND - 25 + bob - 17
        hair_and_hat(p, d, hy, c, side)
        p.outline()
        if frame == "dead": p.rotate_dead()
        return
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
    if c.get("feathers"):
        f = c["feathers"]
        for row in range(3):
            for i in range(4):
                p.poly([(CX - 9 + i * 5 + (row % 2) * 2, by + 2 + row * 5), (CX - 5 + i * 5 + (row % 2) * 2, by + 2 + row * 5), (CX - 7 + i * 5 + (row % 2) * 2, by + 6 + row * 5)], f if (i + row) % 2 else mul(f, 0.8))
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
    if c.get("lids") and d != "up":
        # Вій: залізні повіки до землі. У кадрах удару їх піднято, і видно розпечені очі
        lc = mul(skin, 0.6); fire = hexc("ff4a1a"); glow = hexc("ffd23a")
        if atk:
            if side:
                p.rect(CX - 8, hy + 6, 5, 2, lc); p.rect(CX - 7, hy + 8, 3, 3, fire); p.px(CX - 6, hy + 9, glow)
            else:
                p.rect(CX - 7, hy + 6, 5, 2, lc); p.rect(CX + 3, hy + 6, 5, 2, lc)
                p.rect(CX - 6, hy + 8, 3, 3, fire); p.rect(CX + 4, hy + 8, 3, 3, fire); p.px(CX - 5, hy + 9, glow); p.px(CX + 5, hy + 9, glow)
        else:
            if side:
                p.rect(CX - 8, hy + 7, 5, 16, lc); p.rect(CX - 8, hy + 22, 5, 1, mul(lc, 0.7))
            else:
                p.rect(CX - 7, hy + 7, 5, 17, lc); p.rect(CX + 3, hy + 7, 5, 17, lc)
                p.rect(CX - 7, hy + 23, 5, 1, mul(lc, 0.7)); p.rect(CX + 3, hy + 23, 5, 1, mul(lc, 0.7))
    if c.get("aura"):
        a = c["aura"]
        for i in range(4): p.px(CX - 12 + i * 8, by - 4 - (i % 2) * 3, a)
    # ---- ноша мандрівника ----
    carry(p, d, c, by, side)
    # ---- зброя ----
    weapon(p, d, frame, c, by, atk, side)
    p.outline()
    if hurt:
        # Зірочки від удару
        for (x, y) in ((CX - 12, hy - 4), (CX + 11, hy - 6), (CX + 2, hy - 9)):
            p.px(x, y, (255, 230, 90, 255)); p.px(x + 1, y, (255, 230, 90, 255)); p.px(x, y + 1, (255, 230, 90, 255))
    if frame == "dead":
        p.rotate_dead()


def carry(p, d, c, by, side):
    """Ноша мандрівника за спиною: кобза, мішок із сіллю, торба гінця."""
    kind = c.get("carry")
    if not kind: return
    strap = hexc("4a3020")
    if kind == "kobza":
        wood = hexc("b47a3c"); dark = mul(wood, 0.7); neck = hexc("6b4a2a")
        if d == "up":
            # Зі спини кобзу видно всю: корпус на попереку, гриф над плечем
            p.line(CX + 3, by + 6, CX + 10, by - 9, neck, 2)
            p.rect(CX + 9, by - 12, 3, 4, dark)
            p.ell_sh(CX - 7, by + 3, 13, 12, wood)
            p.px(CX - 1, by + 8, dark); p.px(CX, by + 8, dark); p.px(CX - 1, by + 9, dark)
            p.line(CX - 9, by + 1, CX + 7, by + 13, strap, 1)
        elif side:
            p.ell_sh(CX + 4, by + 2, 8, 12, wood)
            p.line(CX + 8, by + 3, CX + 11, by - 9, neck, 2)
            p.rect(CX + 10, by - 12, 3, 4, dark)
        else:
            # Спереду: ремінь через груди й гриф над плечем
            p.line(CX - 8, by + 1, CX + 7, by + 11, strap, 1)
            p.line(CX - 10, by + 1, CX - 12, by - 9, neck, 2)
            p.rect(CX - 14, by - 12, 3, 4, dark)
            p.rect(CX + 9, by + 9, 3, 6, wood); p.rect(CX + 11, by + 10, 1, 4, dark)
    elif kind == "sack":
        cloth = hexc("c9b48a"); dark = mul(cloth, 0.72)
        if d == "up":
            p.ell_sh(CX - 8, by - 3, 16, 17, cloth)
            p.rect(CX - 2, by - 5, 4, 3, dark); p.line(CX - 3, by - 3, CX + 2, by - 3, strap, 1)
            p.rect(CX - 5, by + 5, 3, 3, dark)  # латка
        elif side:
            p.ell_sh(CX + 3, by - 3, 10, 16, cloth); p.rect(CX + 6, by - 5, 4, 3, dark)
        else:
            p.rect(CX - 8, by + 1, 2, 9, strap); p.rect(CX + 6, by + 1, 2, 9, strap)
            p.rect(CX - 11, by - 3, 4, 4, cloth); p.rect(CX + 8, by - 3, 4, 4, cloth)
    elif kind == "bag":
        leather = hexc("8a5a2a"); dark = mul(leather, 0.7)
        if d == "up":
            p.line(CX + 8, by + 1, CX - 7, by + 12, strap, 1)
            p.rect_sh(CX - 11, by + 10, 7, 7, leather)
        elif side:
            p.line(CX - 2, by + 1, CX + 3, by + 11, strap, 1)
            p.rect_sh(CX + 1, by + 10, 7, 7, leather); p.px(CX + 4, by + 12, hexc("d4a63a"))
        else:
            p.line(CX - 8, by + 1, CX + 7, by + 12, strap, 1)
            p.rect_sh(CX + 5, by + 10, 7, 7, leather); p.rect(CX + 5, by + 10, 7, 2, dark); p.px(CX + 8, by + 13, hexc("d4a63a"))


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
    elif kind == "axe":
        dx, dy = ({0: (-5, 10), 1: (-4, -18), 2: (-17, -8), 3: (-15, 8)} if side else {0: (5, 10), 1: (8, -18), 2: (16, -6), 3: (13, 8)})[atk]
        p.line(hx, hy, hx + dx, hy + dy, handle, 3)
        ex, ey = hx + dx, hy + dy
        p.poly([(ex - 6, ey - 3), (ex + 6, ey - 3), (ex + 4, ey + 5), (ex - 4, ey + 5)], col); p.px(ex, ey, dark)
    elif kind == "broom":
        dx, dy = ({0: (-6, 12), 1: (-6, -14), 2: (-18, -4), 3: (-16, 10)} if side else {0: (6, 12), 1: (10, -14), 2: (17, -4), 3: (13, 10)})[atk]
        p.line(hx, hy, hx + dx, hy + dy, handle, 2)
        ex, ey = hx + dx, hy + dy
        for i in range(-3, 4): p.line(ex, ey, ex + i * 2 + (dx // 3), ey + 6 + abs(i), hexc("d9b25c"), 1)
    elif kind == "bow":
        # Лук для полювання: 0 — опущений, 1 — натягнутий зі стрілою, 2 і 3 — щойно спущений
        wood = hexc("8a5a2a"); string = hexc("e8e2d0")
        up = 0 if atk == 0 else 10
        bx = hx + (-3 if side else 1)
        top = (bx, hy - 14 - up); bot = (bx, hy + 10 - up)
        belly = bx + (-5 if side else 5)
        p.line(top[0], top[1], belly, hy - 8 - up, wood, 2); p.line(belly, hy - 8 - up, belly, hy + 4 - up, wood, 2); p.line(belly, hy + 4 - up, bot[0], bot[1], wood, 2)
        if atk == 1 and d == "up":
            # Зі спини: тятива відтягнута до щоки, а стріла дивиться від нас, углиб галявини
            pull = bx - 5
            p.line(top[0], top[1], pull, hy - 4 - up, string, 1); p.line(pull, hy - 4 - up, bot[0], bot[1], string, 1)
            p.line(bx + 2, hy - 3 - up, bx + 2, top[1] - 1, hexc("d8c8a0"), 1)
            p.px(bx + 2, top[1] - 2, hexc("dfe4ee"))
        elif atk == 1:
            pull = bx + (6 if side else -6)
            p.line(top[0], top[1], pull, hy - 2 - up, string, 1); p.line(pull, hy - 2 - up, bot[0], bot[1], string, 1)
            p.line(pull, hy - 2 - up, belly + (-7 if side else 7), hy - 2 - up, hexc("d8c8a0"), 1)
            p.px(belly + (-8 if side else 8), hy - 2 - up, hexc("dfe4ee"))
        else:
            p.line(top[0], top[1], bot[0], bot[1], string, 1)
    elif kind == "stick":
        # Ціпок: палиця від руки до землі з гулькою нагорі
        p.line(hx + (-3 if side else 2), hy - 9, hx + (-4 if side else 3), GROUND - 1, handle, 2)
        p.rect(hx + (-5 if side else 1), hy - 11, 3, 3, mul(handle, 1.25))
    elif kind == "letter":
        # Лист із сургучем у руці
        lx = hx + (-6 if side else -1)
        p.rect(lx, hy - 3, 7, 5, hexc("f4eeda")); p.rect(lx, hy + 1, 7, 1, hexc("cfc6aa")); p.px(lx + 3, hy - 1, hexc("c6281e")); p.px(lx + 4, hy - 1, hexc("c6281e"))
    elif kind == "basket":
        # Кошик із зіллям
        wick = hexc("b08a4a"); bx = hx + (-7 if side else -3)
        p.line(bx + 1, hy + 1, bx + 4, hy - 3, mul(wick, 0.7), 1); p.line(bx + 4, hy - 3, bx + 7, hy + 1, mul(wick, 0.7), 1)
        p.rect_sh(bx, hy + 1, 9, 6, wick); p.rect(bx, hy + 3, 9, 1, mul(wick, 0.7))
        for i, gc in enumerate((hexc("5aa040"), hexc("7fc85a"), hexc("5aa040"))):
            p.rect(bx + 1 + i * 3, hy - 1, 2, 2, gc)
        p.px(bx + 4, hy - 2, hexc("ffd23a"))
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

CHARS.update({
    "pishchalnyk": dict(CHARS["zarazhenyi"], weapon="musket", hat_col=hexc("2a2a30")),
    "mavka": dict(pants=hexc("5fa868"), boots=hexc("3f7a48"), body=hexc("eaf6dc"), sleeve=hexc("eaf6dc"), robe=True, vyshyvka=hexc("3a9a4a"),
                  skin=hexc("d8f0c8"), hair=hexc("3f9a4a"), hat="wreath", eye=hexc("1a6a2a"), brows=False),
    "bolotianyk": dict(pants=hexc("3e4a22"), boots=hexc("2a3016"), body=hexc("55642a"), sleeve=hexc("4a5826"), hump=True,
                       skin=hexc("6f7e3a"), hair=hexc("4a6a2a"), hat="moss", eye=hexc("ffe24a"), brows=False),
    "vovkulaka": dict(pants=hexc("5a5450"), boots=hexc("2e2a28"), body=hexc("6e6660"), sleeve=hexc("6e6660"), hump=True,
                      skin=hexc("8a827c"), hair=hexc("5a5450"), hat="ears", eye=hexc("ffd040"), muzzle=True, gloves=hexc("3e3a38"),
                      weapon="claws", weapon_col=hexc("f0e8dc")),
    "chaklun": dict(pants=hexc("1e1a24"), boots=hexc("141018"), body=hexc("221c2a"), sleeve=hexc("221c2a"), robe=True, sash=hexc("9a1a1a"),
                    skin=hexc("c9c0b8"), hair=hexc("1e1a24"), hat="hood", hat_col=hexc("2a2432"), eye=hexc("6fff5a"), brows=True,
                    weapon="staff", orb=hexc("6fff5a"), aura=hexc("6fd63a")),
    "koshchii": dict(pants=hexc("16121a"), boots=hexc("0e0a10"), body=hexc("1c1620"), sleeve=hexc("1c1620"), robe=True, sash=hexc("3a3010"),
                     skin=hexc("ece8dc"), hair=hexc("ece8dc"), hat="crown", hat_col=hexc("d4a63a"), skull=True,
                     weapon="sabre", weapon_col=hexc("c8ccd6")),
    "putinoid": dict(pants=hexc("4a1218"), boots=hexc("2a0a0e"), body=hexc("7a1424"), sleeve=hexc("7a1424"), cape=hexc("5a0e1a"), sash=hexc("d4a63a"),
                     skin=hexc("c9ccc4"), hair=hexc("3a3230"), hat="monomakh", hat_col=hexc("d4a63a"), eye=hexc("ff2020"), brows=True,
                     weapon="mace", weapon_col=hexc("6fff5a"), aura=hexc("6fd63a")),
    "baba_yaha": dict(pants=hexc("5a4a3a"), boots=hexc("3a2a1a"), body=hexc("6a5a48"), sleeve=hexc("6a5a48"), robe=True, sash=hexc("3a2a1a"),
                      skin=hexc("cdb595"), hair=hexc("bdb3a3"), hat="kerchief", hat_col=hexc("8a2a2a"), eye=hexc("ffb020"), brows=True,
                      weapon="broom"),
    "solovei": dict(pants=hexc("3a3a22"), boots=hexc("2a2214"), body=hexc("4a5a2a"), sleeve=hexc("4a5a2a"), feathers=hexc("6a7a38"),
                    skin=hexc("d9b48a"), hair=hexc("4a3220"), hat="shapka", hat_col=hexc("5a4a30"), beard=hexc("4a3220"), brows=True),
    "lykho": dict(pants=hexc("3e3644"), boots=hexc("241e2a"), body=hexc("4e4458"), sleeve=hexc("4e4458"), hump=True,
                  skin=hexc("8e8498"), hair=hexc("3e3644"), hat="bald", one_eye=True, gloves=hexc("6e6478"), weapon="claws", weapon_col=hexc("d8d0e0")),
    "oprychnyk": dict(pants=hexc("141010"), boots=hexc("0c0808"), body=hexc("1c1414"), sleeve=hexc("1c1414"), sash=hexc("8a1a1a"),
                      skin=hexc("d9b48a"), hair=hexc("2a1a10"), hat="pointed", hat_col=hexc("141010"), eye=hexc("ff3030"), beard=hexc("2a1a10"),
                      weapon="axe", weapon_col=hexc("c8ccd6")),
})

def coss(coat, extra=None, **kw):
    base = dict(CHARS["cossack"]); base.update(body=coat, sleeve=coat); base.update(kw)
    if extra: base.update(extra)
    return base

SPEC_COATS = {"zaporozhets": hexc("8c1418"), "plastun": hexc("5a6638"), "samopalnyk": hexc("33407a"), "kharakternyk": hexc("2a2226")}
for _job, _coat in SPEC_COATS.items():
    for _w in ("sabre", "mace", "pike"):
        CHARS[_job + "_" + _w] = coss(_coat, weapon=_w, sash=hexc("f2c23a"), vyshyvka=None if _job != "zaporozhets" else hexc("f2c23a"),
                                      hat="oseledets" if _job != "kharakternyk" else "long", hair=hexc("3a2518") if _job != "kharakternyk" else hexc("6a6a6e"))
CHARS["samopalnyk_pishchal"] = dict(CHARS["samopalnyk_sabre"], weapon="musket")
for _w in ("mace", "pike"):
    CHARS["cossack_" + _w] = coss(hexc("f6efe0"), weapon=_w, vyshyvka=hexc("c6281e"))
CHARS["cossack_sabre"] = dict(CHARS["cossack"])
CHARS["peasant_pike"] = dict(CHARS["peasant"])
CHARS["volkhv_staff"] = dict(CHARS["volkhv"], hat="oak", hat_col=hexc("4a9a3a"), hair=hexc("b08a4a"), beard=None)
CHARS["znakhar_staff"] = dict(CHARS["volkhv"], hat="oak", hat_col=hexc("6ab84a"), hair=hexc("b08a4a"), beard=None, sash=hexc("3a9a4a"), vyshyvka=hexc("3a9a4a"), orb=hexc("7fe07a"))
CHARS["perun_zhrets_staff"] = dict(CHARS["volkhv"], hat="oak", hat_col=hexc("d8dce8"), hair=hexc("b08a4a"), beard=hexc("b08a4a"), sash=hexc("3a4ab8"), body=hexc("dfe4f2"), sleeve=hexc("dfe4f2"), orb=hexc("8ad0ff"))
CHARS["molfar_staff"] = dict(CHARS["volkhv"], hat="hutsul", hat_col=hexc("141010"), hair=hexc("3a2a1a"), beard=hexc("3a2a1a"), sash=hexc("c0302a"), body=hexc("e8dcc4"), sleeve=hexc("4a2a1a"), orb=hexc("c080ff"))
# Побратими й найманці
CHARS["comp_dzhura"] = coss(hexc("c43a2a"), hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("d4a63a"), mustache=False, brows=True)
CHARS["comp_petro"] = coss(hexc("8c3f33"), hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("4a90d8"), mustache=True, brows=True)
CHARS["comp_strilets"] = dict(CHARS["cossack"], body=hexc("5a6638"), sleeve=hexc("5a6638"), vyshyvka=None, hat="shapka", hat_col=hexc("2a2220"), mustache=False, weapon="musket")
CHARS["comp_oksana"] = dict(CHARS["cossack"], body=hexc("596633"), sleeve=hexc("596633"), vyshyvka=hexc("e8c04a"), hat="long", hair=hexc("3a2518"), mustache=False, pants=hexc("8a3a2a"), weapon="musket")
CHARS["comp_znakhar"] = dict(CHARS["mavka"], skin=SKIN, hair=hexc("6a4a2a"), body=hexc("f6efe0"), sleeve=hexc("f6efe0"), vyshyvka=hexc("c6281e"), pants=hexc("b03a3a"), eye=BLACK, weapon=None)
CHARS["comp_yaryna"] = dict(CHARS["comp_znakhar"], hair=hexc("d8b060"), vyshyvka=hexc("3a9a4a"), pants=hexc("3a6a9a"))
# Суперники в герці на майдані
CHARS["rival_ostap"] = coss(hexc("b02a2a"), weapon="sabre", hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("c6281e"), sash=hexc("f2c23a"), vyshyvka=None)
CHARS["rival_danylo"] = coss(hexc("3f6a3a"), weapon="pike", sash=hexc("c6281e"), pants=hexc("7a3a2a"), vyshyvka=None)
CHARS["rival_hnat"] = coss(hexc("2f4f8a"), weapon="musket", hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("4a90d8"), sash=hexc("d8d8d8"), vyshyvka=None, mustache=False)
CHARS["rival_marko"] = coss(hexc("1e1a22"), weapon="sabre", hat="long", hair=hexc("9a9aa2"), sash=hexc("5a2a8a"), pants=hexc("2a2a3a"), eye=hexc("6fd0ff"), vyshyvka=None, weapon_col=hexc("a8d8ff"))
CHARS["rival_taras"] = coss(hexc("7a4a22"), weapon="mace", beard=hexc("3a2518"), sash=hexc("2a2220"), vyshyvka=None)
# Боси печер поза сюжетом
CHARS["vidma"] = dict(pants=hexc("2a1830"), boots=hexc("1a1020"), body=hexc("3c2050"), sleeve=hexc("3c2050"), robe=True, sash=hexc("a040d0"),
                      skin=hexc("e2dcc6"), hair=hexc("17101c"), hat="long", eye=hexc("6fe07a"), brows=True, aura=hexc("b868ff"), weapon="broom")
CHARS["vii"] = dict(pants=hexc("382c20"), boots=hexc("1c1510"), body=hexc("4c3c2a"), sleeve=hexc("4c3c2a"), hump=True, sash=hexc("2a2018"),
                    skin=hexc("747a80"), hair=hexc("3a3020"), hat="moss", lids=True, gloves=hexc("565c62"), eye=hexc("ff4a1a"), weapon=None)
# Нечисть і боси далеких країв (версія 0.29)
CHARS["potopelnyk"] = dict(pants=hexc("3a5a6a"), boots=hexc("2a4450"), body=hexc("5a7f8a"), sleeve=hexc("4f7480"), hump=True,
                           skin=hexc("9fc4c0"), hair=hexc("2f6a5a"), hat="moss", eye=hexc("e8ffff"), brows=False, weapon="claws", weapon_col=hexc("cfe8e8"))
CHARS["pesyholovets"] = dict(pants=hexc("5a3a22"), boots=hexc("2e1e12"), body=hexc("8a5a30"), sleeve=hexc("8a5a30"), hump=True, sash=hexc("3a2414"),
                             skin=hexc("b07a48"), hair=hexc("6a4426"), hat="ears", eye=hexc("ff5a20"), muzzle=True, gloves=hexc("5a3a22"),
                             weapon="axe", weapon_col=hexc("c8ccd6"))
CHARS["kamiana_baba"] = dict(pants=hexc("7a7a74"), boots=hexc("5a5a56"), body=hexc("8c8c86"), sleeve=hexc("8c8c86"), robe=True, sash=hexc("6a6a64"),
                             skin=hexc("a4a49c"), hair=hexc("8c8c86"), hat="bald", eye=hexc("ffd040"), brows=False, gloves=hexc("9a9a92"), weapon=None)
CHARS["mara"] = dict(pants=hexc("c8d0e0"), boots=hexc("a8b0c4"), body=hexc("e4e8f4"), sleeve=hexc("e4e8f4"), robe=True,
                     skin=hexc("e8ecf6"), hair=hexc("f4f6fc"), hat="long", eye=hexc("60b0ff"), brows=False, aura=hexc("a8c8ff"), weapon=None)
CHARS["zlyden"] = dict(pants=hexc("3a3428"), boots=hexc("1e1a12"), body=hexc("5a5038"), sleeve=hexc("5a5038"), hump=True,
                       skin=hexc("9a8a5a"), hair=hexc("2a2418"), hat="horns", hat_col=hexc("2a2418"), eye=hexc("ffe24a"), snout=True,
                       tail=hexc("3a3428"), weapon="claws", weapon_col=hexc("e8d8c0"))
CHARS["morskyi_tsar"] = dict(pants=hexc("1e4a5a"), boots=hexc("12303c"), body=hexc("2a6a7a"), sleeve=hexc("2a6a7a"), robe=True, cape=hexc("1a4450"), sash=hexc("d4a63a"),
                             skin=hexc("8fc8c0"), hair=hexc("e8f4f0"), beard=hexc("e8f4f0"), hat="crown", hat_col=hexc("d4a63a"), eye=hexc("40e0ff"), brows=True,
                             weapon="pike", weapon_col=hexc("d4a63a"), aura=hexc("60c8e0"))
CHARS["shubin"] = dict(pants=hexc("2a2420"), boots=hexc("14100e"), body=hexc("3a322c"), sleeve=hexc("3a322c"), hump=True, sash=hexc("1a1614"),
                       skin=hexc("5a504a"), hair=hexc("1e1a18"), hat="hood", hat_col=hexc("2a2420"), beard=hexc("8a8a86"), eye=hexc("ffb030"), brows=True,
                       gloves=hexc("2a2420"), weapon="axe", weapon_col=hexc("a8a8a8"), aura=hexc("ff9a30"))
CHARS["bila_pani"] = dict(pants=hexc("dfe4ee"), boots=hexc("c0c6d4"), body=hexc("f4f6fb"), sleeve=hexc("f4f6fb"), robe=True, cape=hexc("d8deea"), sash=hexc("b8c4e0"),
                          skin=hexc("f0f2f8"), hair=hexc("1c1c28"), hat="long", eye=hexc("9ad0ff"), brows=True, aura=hexc("cfe0ff"), weapon=None)
# Московія
CHARS["vedmid"] = dict(pants=hexc("4a3020"), wide_pants=True, boots=hexc("2a1a10"), body=hexc("5a3a22"), sleeve=hexc("5a3a22"), hump=True, skin=hexc("7a5232"), hair=hexc("4a3020"), hat="ears", eye=hexc("ffb020"), muzzle=True, fangs=True, gloves=hexc("3a2414"), weapon="claws", weapon_col=hexc("f0e8dc"))
CHARS["kikimora"] = dict(pants=hexc("4a5440"), boots=hexc("2a3020"), body=hexc("5a6a50"), sleeve=hexc("4e5c46"), hump=True, sash=hexc("7a3a2a"), skin=hexc("a8b49a"), hair=hexc("3a4a2a"), hat="kerchief", hat_col=hexc("6a2a2a"), eye=hexc("ffe24a"), brows=False, weapon="stick")
CHARS["mertvyi_strilets"] = dict(pants=hexc("6a1a14"), boots=hexc("3a2a1a"), body=hexc("b0281e"), sleeve=hexc("b0281e"), robe=True, sash=hexc("d4a63a"), skin=hexc("e4e0d0"), hair=hexc("e4e0d0"), hat="shapka", hat_col=hexc("7a5a3a"), skull=True, weapon="musket")
CHARS["kromeshnyk"] = dict(pants=hexc("141010"), boots=hexc("0c0808"), body=hexc("1c1414"), sleeve=hexc("1c1414"), cape=hexc("2a1a1a"), sash=hexc("8a1a1a"), skin=hexc("d9b48a"), hair=hexc("2a1a10"), hat="pointed", hat_col=hexc("141010"), eye=hexc("ffd040"), mustache=True, brows=True, weapon="broom")  # Малюта: борода, сокира, без плаща
CHARS["boyaryn"] = dict(pants=hexc("3a1a20"), boots=hexc("2a1a10"), body=hexc("6a2a3a"), sleeve=hexc("6a2a3a"), robe=True, sash=hexc("d4a63a"), skin=hexc("c8c0b8"), hair=hexc("8a8278"), hat="shapka", hat_col=hexc("4a3324"), beard=hexc("8a8278"), eye=hexc("ff3030"), fangs=True, brows=True, gloves=hexc("d4a63a"), weapon="stick", aura=hexc("6fd63a"))
CHARS["lisovyk"] = dict(pants=hexc("4a3a26"), boots=hexc("2a2014"), body=hexc("5a4a30"), sleeve=hexc("4a3a26"), robe=True, sash=hexc("3a5a2a"), skin=hexc("8a7a5a"), hair=hexc("3a5a2a"), hat="horns", hat_col=hexc("5a4028"), beard=hexc("4a6a2a"), eye=hexc("a0ff60"), brows=False, gloves=hexc("5a4a30"), weapon="stick")  # роги-гілки, моховита борода
CHARS["pushkar"] = dict(pants=hexc("3a2a20"), wide_pants=True, boots=hexc("1e1610"), body=hexc("5a4030"), sleeve=hexc("8a1e1e"), sash=hexc("2a1a10"), skin=hexc("c8a880"), hair=hexc("2a2018"), hat="shapka", hat_col=hexc("2a2420"), beard=hexc("5a4030"), mustache=True, brows=True, eye=hexc("ffb030"), gloves=hexc("3a2a1a"), weapon="staff", orb=hexc("ff9a30"), aura=hexc("ff9a30"))  # посох із жаринкою = пальник
CHARS["lisovyi_did"] = dict(pants=hexc("3a2c1c"), boots=hexc("1e160e"), body=hexc("4a3a24"), sleeve=hexc("3a2c1c"), robe=True, cape=hexc("2f4a1e"), skin=hexc("7a6a4a"), hair=hexc("2f5a22"), hat="oak", hat_col=hexc("4a7a2a"), beard=hexc("3a6a2a"), eye=hexc("a0ff60"), brows=True, gloves=hexc("4a3a24"), weapon="staff", orb=hexc("a0ff60"), aura=hexc("8acf5a"))
CHARS["idolyshche"] = dict(pants=hexc("4a3a2a"), wide_pants=True, boots=hexc("2a1a10"), body=hexc("7a5a3a"), sleeve=hexc("7a5a3a"), hump=True, sash=hexc("c8a040"), skin=hexc("b89a78"), hair=hexc("3a2a1a"), hat="bald", beard=hexc("5a3a1a"), mustache=True, eye=hexc("ff6a20"), fangs=True, brows=True, gloves=hexc("b89a78"), weapon="mace", weapon_col=hexc("e8e0c8"))  # булава кольору кістки = обгризений маслак
CHARS["karachun"] = dict(pants=hexc("1a2234"), boots=hexc("0e1420"), body=hexc("2a3448"), sleeve=hexc("2a3448"), robe=True, cape=hexc("1a2234"), sash=hexc("6a8ab0"), skin=hexc("9aaabb"), hair=hexc("e8f0ff"), beard=hexc("e8f0ff"), hat="crown", hat_col=hexc("a8d8ff"), eye=hexc("40c8ff"), brows=True, weapon="staff", orb=hexc("a8e8ff"), aura=hexc("9ad0ff"))
# Мисливці з луком і беззбройні постаті для мирних занять (полювання, рибалка): по одній на клас
_LOOKS = {"peasant": "peasant", "cossack": "cossack_sabre", "volkhv": "volkhv_staff", "zaporozhets": "zaporozhets_sabre", "plastun": "plastun_sabre",
          "samopalnyk": "samopalnyk_sabre", "kharakternyk": "kharakternyk_sabre", "znakhar": "znakhar_staff", "perun_zhrets": "perun_zhrets_staff", "molfar": "molfar_staff"}
for _job, _src in _LOOKS.items():
    CHARS["hunter_" + _job] = dict(CHARS[_src], weapon="bow")
    CHARS["plain_" + _job] = dict(CHARS[_src], weapon=None)
# Мандрівники для завдань на супровід: кобзар, чумак, гонець, знахарка
CHARS["trav_kobzar"] = dict(pants=hexc("8a8478"), boots=hexc("5a4030"), body=hexc("7a6a58"), sleeve=hexc("7a6a58"), robe=True, sash=hexc("b8261c"),
                            hair=hexc("d9d2c4"), hat="straw", hat_col=hexc("c9a85a"), beard=hexc("d9d2c4"), mustache=True, brows=True, weapon="stick", carry="kobza")
CHARS["trav_chumak"] = dict(pants=hexc("2a2a34"), wide_pants=True, boots=hexc("3a2a20"), body=hexc("f2ecdc"), sleeve=hexc("f2ecdc"), vyshyvka=hexc("2a2a34"),
                            sash=hexc("3a6a9a"), hair=hexc("3a2518"), hat="straw", hat_col=hexc("e0c070"), mustache=True, brows=True, weapon="stick", carry="sack")
CHARS["trav_honets"] = coss(hexc("a8322a"), hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("f2c23a"), mustache=False, brows=True, sash=hexc("f2c23a"),
                            vyshyvka=None, weapon="letter", carry="bag")
CHARS["trav_znakharka"] = dict(pants=hexc("7a2f3a"), boots=hexc("5a3020"), body=hexc("f6efe0"), sleeve=hexc("f6efe0"), robe=True, vyshyvka=hexc("c6281e"),
                               sash=hexc("3a9a4a"), hair=hexc("6a4a2a"), hat="kerchief", hat_col=hexc("b8343a"), brows=True, weapon="basket")
# Накладки на голову
CHARS["overlay_hat"] = dict(only_hat=True, hat="shapka", hat_col=hexc("2a2220"), shlyk=hexc("ffffff"), hair=hexc("2a2220"))
CHARS["overlay_wolf"] = dict(only_hat=True, hat="wolf_ears", hat_col=hexc("7a7a7e"), hair=hexc("7a7a7e"))

if __name__ == "__main__":
    ids = sys.argv[1:] or list(CHARS.keys())
    for cid in ids:
        build(cid, CHARS[cid]); print("ok", cid)
