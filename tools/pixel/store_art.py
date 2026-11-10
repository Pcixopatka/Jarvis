#!/usr/bin/env python3
"""Банер для сторінки гри в Google Play (feature graphic), 1024×500, без прозорості.
Малюється на сітці 256×125 «великих пікселів» і збільшується вчетверо, щоб лишитися піксельним.
Запуск: python3 tools/pixel/store_art.py  →  docs/store/feature_1024x500.png
Шрифт напису — DejaVu Sans Bold (вільна ліцензія), береться із системи.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SPRITES = os.path.join(ROOT, "assets", "gfx", "sprites")
OUT = os.path.join(ROOT, "docs", "store", "feature_1024x500.png")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
W, H, K = 256, 125, 4

SKY_TOP = (22, 44, 82)
SKY_LOW = (52, 104, 160)
SUN = (246, 198, 50)
SUN_DARK = (226, 160, 36)
RING = (192, 57, 43)
FIELD = (232, 178, 60)
FIELD_DARK = (196, 140, 40)
INK = (16, 26, 48)


def frame(sheet, col=0, row=0, flip=False):
    """Кадр 48×48 з аркуша: row 0 — лицем, 1 — спиною, 2 — боком (ліворуч)."""
    im = Image.open(os.path.join(SPRITES, sheet + ".png")).convert("RGBA").crop((col * 48, row * 48, col * 48 + 48, row * 48 + 48))
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def main():
    im = Image.new("RGBA", (W, H), SKY_TOP + (255,))
    d = ImageDraw.Draw(im)
    for y in range(H):
        k = y / (H - 1)
        d.line([0, y, W, y], fill=tuple(int(SKY_TOP[i] + (SKY_LOW[i] - SKY_TOP[i]) * k) for i in range(3)))
    # Сонце з червоним обідком за героями
    cx, cy, r = 190, 56, 40
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=RING)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN)
    d.ellipse([cx - r + 10, cy - r + 13, cx + r, cy + r], fill=SUN_DARK)
    d.ellipse([cx - r, cy - r, cx + r - 10, cy + r - 10], fill=SUN)
    # Пшеничне поле
    d.rectangle([0, 98, W, H], fill=FIELD)
    d.rectangle([0, 110, W, H], fill=FIELD_DARK)
    for x in range(1, W, 4):
        d.line([x, 98, x, 95 + (x // 4) % 2], fill=FIELD_DARK)
    # Нечисть насувається справа (кадри боком дивляться ліворуч), загін стоїть лицем до нас
    for sheet, x, y, col, row, flip in [
        ("upyr", 240, 56, 2, 2, False), ("chort", 222, 60, 1, 2, False), ("zarazhenyi", 231, 68, 0, 2, False),
        ("comp_znakhar", 140, 57, 0, 0, False), ("volkhv_staff", 157, 61, 0, 0, False),
        ("comp_dzhura", 196, 61, 0, 0, False), ("cossack_sabre", 176, 67, 0, 0, False),
    ]:
        f = frame(sheet, col, row, flip)
        im.alpha_composite(f, (x - 24, y - 6))
    # Назва: без згладжування, щоб після збільшення лишилась піксельною
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    big = ImageFont.truetype(FONT, 20)
    for i, word in enumerate(["КОЗАЦЬКА", "ЗВИТЯГА"]):
        d.text((8, 17 + i * 24), word, font=big, fill=SUN, stroke_width=2, stroke_fill=INK)
    out = im.convert("RGB").resize((W * K, H * K), Image.NEAREST)
    # Підзаголовок дрібний, тож малюється вже на повному розмірі, інакше літери зливаються
    d2 = ImageDraw.Draw(out)
    d2.text((36, 304), "екшн-RPG козацького фентезі", font=ImageFont.truetype(FONT, 26), fill=(244, 238, 220), stroke_width=4, stroke_fill=INK)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("ok", out.size)


if __name__ == "__main__":
    main()
