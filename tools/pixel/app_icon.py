#!/usr/bin/env python3
"""Значок застосунку «Козацької Звитяги» у піксельному стилі гри.
Бере козака з аркуша спрайтів і ставить на тлі сонця й синього неба.
Запуск: python3 tools/pixel/app_icon.py
  →  assets/gfx/icon/icon_192.png            значок для запускача (і значок проєкту)
     assets/gfx/icon/icon_fg_432.png         адаптивний значок: передній шар (козак у безпечній зоні)
     assets/gfx/icon/icon_bg_432.png         адаптивний значок: тло
     assets/gfx/icon/icon_mono_432.png       адаптивний значок: одноколірний шар для тематичних значків Android 13+
     assets/gfx/icon/splash_384.png          заставка під час запуску (на темно-синьому тлі)
     docs/store/icon_512.png                 значок для сторінки в Google Play (512×512, без прозорості)
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SPRITES = os.path.join(ROOT, "assets", "gfx", "sprites")
OUT = os.path.join(ROOT, "assets", "gfx", "icon")
STORE = os.path.join(ROOT, "docs", "store")

SKY_TOP = (22, 44, 82)
SKY_LOW = (44, 92, 150)
SUN = (246, 198, 50)
SUN_DARK = (226, 160, 36)
RING = (192, 57, 43)
FIELD = (232, 178, 60)
FIELD_DARK = (196, 140, 40)
G = 64  # сітка «великих пікселів», у якій малюється тло


def background(r=22, field_y=50):
    """Тло 64×64: небо, сонце з червоним обідком (радіус r), пшеничне поле від рядка field_y."""
    im = Image.new("RGB", (G, G), SKY_TOP)
    d = ImageDraw.Draw(im)
    for y in range(G):
        k = y / (G - 1)
        d.line([0, y, G, y], fill=tuple(int(SKY_TOP[i] + (SKY_LOW[i] - SKY_TOP[i]) * k) for i in range(3)))
    cx, cy = 32, 30
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=RING)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN)
    d.ellipse([cx - r + r // 4, cy - r + r // 3, cx + r, cy + r], fill=SUN_DARK)
    d.ellipse([cx - r, cy - r, cx + r - r // 4, cy + r - r // 4], fill=SUN)
    # Поле: дві смуги й колоски
    d.rectangle([0, field_y, G, G], fill=FIELD)
    d.rectangle([0, field_y + 6, G, G], fill=FIELD_DARK)
    for x in range(1, G, 4):
        d.line([x, field_y, x, field_y - 3 + (x // 4) % 2], fill=FIELD_DARK)
    return im


def hero():
    """Козак лицем до нас (кадр «стоїть»), обрізаний по фігурі."""
    sheet = Image.open(os.path.join(SPRITES, "cossack_sabre.png")).convert("RGBA")
    cell = sheet.crop((0, 0, 48, 48))
    return cell.crop(cell.getbbox())


def compose(size, hero_part, with_bg=True, round_corners=False):
    """size — сторона в пікселях; hero_part — частка висоти, яку займає козак."""
    px = size / G
    base = background().resize((size, size), Image.NEAREST).convert("RGBA") if with_bg else Image.new("RGBA", (size, size), (0, 0, 0, 0))
    h = hero()
    k = max(1, int(round(size * hero_part / h.height)))
    big = h.resize((h.width * k, h.height * k), Image.NEAREST)
    x = (size - big.width) // 2
    y = int(size * (0.5 + hero_part / 2.0)) - big.height + int(px * 1.5)
    base.alpha_composite(big, (x, max(0, y)))
    if round_corners:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.19), fill=255)
        base.putalpha(mask)
    return base


def mono(size, hero_part):
    """Одноколірний шар: світлі частини козака білі, контур, чуб і вуса — прозорі (система сама фарбує значок)."""
    fg = compose(size, hero_part, with_bg=False)
    out = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    src, dst = fg.load(), out.load()
    for y in range(fg.height):
        for x in range(fg.width):
            r, g, b, a = src[x, y]
            if a > 0 and (r * 299 + g * 587 + b * 114) / 1000 > 70:
                dst[x, y] = (255, 255, 255, 255)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(STORE, exist_ok=True)
    compose(192, 0.74, round_corners=True).save(os.path.join(OUT, "icon_192.png"))
    compose(384, 0.74, round_corners=True).save(os.path.join(OUT, "splash_384.png"))
    # Адаптивний значок: система сама обрізає тло маскою, козак — у середніх 66%
    compose(432, 0.50, with_bg=False).save(os.path.join(OUT, "icon_fg_432.png"))
    mono(432, 0.50).save(os.path.join(OUT, "icon_mono_432.png"))
    # (менше сонце й вище поле: у круглій масці телефона видно лише середину тла)
    background(14, 44).resize((432, 432), Image.NEAREST).save(os.path.join(OUT, "icon_bg_432.png"))
    # Google Play: 512×512, 32-бітний PNG; кути магазин заокруглює сам
    compose(512, 0.74).convert("RGB").save(os.path.join(STORE, "icon_512.png"))
    print("ok")


if __name__ == "__main__":
    main()
