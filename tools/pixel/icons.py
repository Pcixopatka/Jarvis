#!/usr/bin/env python3
"""Значки здобичі 16×16 (малюються ×2): зілля, ресурси, вареник, зілля наснаги, провіант, жетони свят, слава.
Запуск: python3 tools/pixel/icons.py → assets/gfx/sprites/icons.png (один ряд, порядок як в ORDER)."""
import os
from PIL import Image, ImageDraw
ORDER = ["potion", "wood", "iron", "herbs", "trophy", "varenyk", "mana", "meat", "ryba", "veg",
         "tok_rizdvo", "tok_velykden", "tok_kupala", "tok_spas", "tok_nezalezhnist", "tok_pokrova", "tok_andrii", "glory", "khmil",
         # жетони свят, доданих у 0.28: нові значки дописуються в кінець, щоб старі не зсувались
         "tok_malanka", "tok_vodokhreshche", "tok_sobornist", "tok_stritennia", "tok_masnytsia", "tok_shevchenko", "tok_blahovishchennia",
         "tok_verbna", "tok_yurii", "tok_vyshyvanka", "tok_zeleni", "tok_petra", "tok_derzhavnist", "tok_illi", "tok_obzhynky",
         "tok_zdvyzhennia", "tok_didy", "tok_mykhaila", "tok_kuzma", "tok_kateryny", "tok_mykolai"]
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
    elif kind == "mana":  # зілля наснаги: та сама пляшечка, але синя
        d.rectangle([6, 1, 9, 4], fill=(170, 180, 190, 255)); d.rectangle([5, 0, 10, 1], fill=(110, 70, 40, 255))
        d.ellipse([3, 4, 12, 14], fill=(45, 105, 225, 255)); d.ellipse([5, 6, 7, 8], fill=(160, 205, 255, 255))
        d.point((9, 11), fill=(120, 170, 255, 255))
    elif kind == "meat":  # окіст із кісткою
        d.ellipse([2, 3, 11, 12], fill=(170, 65, 50, 255)); d.ellipse([4, 5, 8, 9], fill=(215, 110, 85, 255))
        d.line([(10, 11), (13, 14)], fill=(235, 230, 215, 255), width=2); d.ellipse([12, 12, 15, 15], fill=(245, 240, 225, 255))
    elif kind == "ryba":
        d.ellipse([1, 5, 11, 11], fill=(110, 145, 175, 255)); d.rectangle([3, 9, 9, 10], fill=(190, 210, 225, 255))
        d.polygon([(10, 8), (15, 4), (15, 12)], fill=(85, 115, 150, 255)); d.point((3, 7), fill=(20, 20, 30, 255))
        d.line([(6, 5), (8, 4)], fill=(85, 115, 150, 255))
    elif kind == "veg":  # буряк із гичкою
        d.ellipse([3, 6, 12, 14], fill=(150, 35, 75, 255)); d.ellipse([5, 8, 7, 10], fill=(200, 80, 120, 255)); d.line([(7, 14), (8, 15)], fill=(120, 25, 60, 255))
        d.line([(7, 6), (4, 1)], fill=(70, 160, 60, 255), width=2); d.line([(8, 6), (11, 1)], fill=(95, 185, 75, 255), width=2); d.line([(7, 6), (7, 2)], fill=(60, 140, 55, 255))
    elif kind == "tok_rizdvo":  # зірка колядників
        d.polygon([(8, 0), (10, 5), (15, 5), (11, 9), (13, 15), (8, 11), (3, 15), (5, 9), (1, 5), (6, 5)], fill=(245, 200, 60, 255))
        d.ellipse([6, 5, 10, 9], fill=(255, 240, 160, 255)); d.point((8, 7), fill=(210, 60, 50, 255))
    elif kind == "tok_velykden":  # писанка
        d.ellipse([4, 1, 12, 15], fill=(200, 45, 45, 255))
        for x, y in ((4, 8), (6, 7), (8, 8), (10, 7), (12, 8)): d.point((x, y), fill=(250, 215, 80, 255))
        d.line([(4, 9), (12, 9)], fill=(250, 215, 80, 255)); d.line([(5, 5), (11, 5)], fill=(30, 30, 40, 255)); d.line([(5, 12), (11, 12)], fill=(255, 250, 240, 255))
        d.point((8, 3), fill=(255, 250, 240, 255))
    elif kind == "tok_kupala":  # цвіт папороті
        d.line([(8, 15), (8, 8)], fill=(50, 130, 55, 255), width=2)
        for dx, dy in ((-4, 12), (4, 12), (-3, 10), (3, 10)): d.line([(8, dy + 1), (8 + dx, dy - 1)], fill=(80, 170, 70, 255))
        for cx, cy in ((8, 3), (5, 5), (11, 5), (6, 8), (10, 8)): d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(240, 90, 40, 255))
        d.ellipse([6, 4, 10, 8], fill=(255, 220, 90, 255))
    elif kind == "tok_spas":  # яблуко
        d.ellipse([2, 4, 13, 15], fill=(205, 45, 45, 255)); d.ellipse([4, 6, 7, 9], fill=(250, 130, 120, 255))
        d.line([(8, 5), (8, 1)], fill=(100, 65, 35, 255)); d.ellipse([9, 1, 13, 4], fill=(90, 175, 70, 255))
    elif kind == "tok_nezalezhnist":  # синьо-жовта стрічка
        d.polygon([(1, 3), (15, 3), (12, 8), (1, 8)], fill=(0, 87, 183, 255)); d.polygon([(1, 8), (12, 8), (15, 13), (1, 13)], fill=(255, 215, 0, 255))
        d.rectangle([1, 3, 2, 13], fill=(230, 230, 235, 255))
    elif kind == "tok_pokrova":  # козацький хрест
        g = (235, 190, 70, 255)
        d.polygon([(6, 1), (10, 1), (9, 6), (7, 6)], fill=g); d.polygon([(6, 15), (10, 15), (9, 10), (7, 10)], fill=g)
        d.polygon([(1, 6), (1, 10), (6, 9), (6, 7)], fill=g); d.polygon([(15, 6), (15, 10), (10, 9), (10, 7)], fill=g)
        d.ellipse([6, 6, 10, 10], fill=(175, 40, 45, 255)); d.point((8, 8), fill=(255, 235, 150, 255))
    elif kind == "tok_andrii":  # калита
        d.ellipse([1, 2, 14, 15], fill=(205, 150, 70, 255)); d.ellipse([5, 6, 10, 11], fill=(0, 0, 0, 0)); d.ellipse([3, 4, 6, 6], fill=(240, 200, 120, 255))
        for x, y in ((8, 3), (12, 6), (12, 11), (8, 14), (3, 11)): d.point((x, y), fill=(120, 75, 35, 255))
        d.line([(8, 0), (8, 2)], fill=(200, 40, 50, 255), width=2)
    elif kind == "tok_malanka":  # маска Кози
        fur = (226, 200, 150, 255); horn = (110, 80, 50, 255)
        d.polygon([(4, 4), (12, 4), (10, 12), (8, 15), (6, 12)], fill=fur)
        d.line([(5, 4), (3, 0)], fill=horn, width=2); d.line([(11, 4), (13, 0)], fill=horn, width=2)
        d.polygon([(4, 5), (1, 6), (4, 7)], fill=fur); d.polygon([(12, 5), (15, 6), (12, 7)], fill=fur)
        d.point((6, 7), fill=O); d.point((10, 7), fill=O); d.rectangle([7, 10, 9, 11], fill=(150, 90, 80, 255)); d.line([(8, 13), (8, 15)], fill=(245, 240, 225, 255))
    elif kind == "tok_vodokhreshche":  # глечик йорданської води
        clay = (178, 106, 62, 255)
        d.ellipse([3, 5, 12, 15], fill=clay); d.rectangle([6, 2, 9, 5], fill=clay); d.rectangle([5, 1, 10, 2], fill=(140, 80, 45, 255))
        d.arc([10, 5, 15, 11], 270, 90, fill=(140, 80, 45, 255), width=1)
        d.line([(4, 8), (11, 8)], fill=(110, 180, 235, 255)); d.line([(7, 10), (7, 13)], fill=(245, 245, 250, 255)); d.line([(6, 11), (8, 11)], fill=(245, 245, 250, 255))
    elif kind == "tok_sobornist":  # дві ланки ланцюга: синя й жовта
        d.ellipse([1, 4, 9, 12], outline=(0, 87, 183, 255), width=2); d.ellipse([6, 4, 14, 12], outline=(255, 215, 0, 255), width=2)
        d.point((7, 6), fill=(0, 87, 183, 255)); d.point((7, 10), fill=(0, 87, 183, 255))
    elif kind == "tok_stritennia":  # громнична свічка
        d.rectangle([6, 6, 9, 13], fill=(242, 228, 176, 255)); d.rectangle([9, 7, 9, 13], fill=(210, 190, 130, 255))
        d.ellipse([5, 0, 10, 6], fill=(245, 150, 40, 255)); d.ellipse([6, 2, 9, 6], fill=(255, 235, 120, 255))
        d.rectangle([4, 13, 11, 14], fill=(140, 95, 50, 255))
    elif kind == "tok_masnytsia":  # вареник із сиром і сметаною
        dough = (246, 232, 190, 255)
        d.pieslice([1, 3, 14, 19], 180, 360, fill=dough); d.line([(1, 11), (14, 11)], fill=(215, 190, 135, 255))
        for x in (3, 5, 7, 9, 11): d.point((x, 5 if x in (5, 7, 9) else 7), fill=(215, 190, 135, 255))
        d.ellipse([5, 6, 10, 9], fill=(255, 255, 255, 255)); d.point((7, 7), fill=(250, 215, 90, 255))
    elif kind == "tok_shevchenko":  # сторінка «Кобзаря»: книга із золотим тисненням
        d.rectangle([2, 2, 12, 14], fill=(122, 58, 40, 255)); d.rectangle([12, 3, 13, 13], fill=(240, 232, 205, 255)); d.rectangle([2, 2, 3, 14], fill=(90, 40, 28, 255))
        gold = (235, 195, 80, 255)
        d.line([(6, 5), (6, 9)], fill=gold); d.line([(6, 7), (9, 5)], fill=gold); d.line([(6, 7), (9, 9)], fill=gold); d.line([(5, 12), (10, 12)], fill=gold)
    elif kind == "tok_blahovishchennia":  # жайворонок із тіста
        bake = (218, 162, 82, 255); dark = (165, 110, 50, 255)
        d.ellipse([3, 6, 12, 13], fill=bake); d.ellipse([9, 3, 14, 8], fill=bake); d.polygon([(4, 9), (0, 5), (0, 12)], fill=bake)
        d.polygon([(14, 5), (15, 6), (14, 7)], fill=dark); d.point((12, 5), fill=O)
        d.line([(5, 9), (9, 11)], fill=dark); d.line([(5, 11), (8, 12)], fill=dark)
    elif kind == "tok_verbna":  # вербова гілка з котиками
        d.line([(3, 15), (11, 1)], fill=(130, 85, 45, 255), width=1)
        for cx, cy in ((10, 2), (7, 4), (10, 6), (5, 8), (8, 10), (3, 12)): d.ellipse([cx - 1, cy - 2, cx + 2, cy + 1], fill=(232, 232, 222, 255))
        for cx, cy in ((10, 2), (10, 6), (8, 10)): d.point((cx + 1, cy - 1), fill=(255, 255, 255, 255))
    elif kind == "tok_yurii":  # змієва луска
        d.polygon([(8, 1), (13, 5), (12, 11), (8, 15), (4, 11), (3, 5)], fill=(58, 150, 84, 255))
        d.polygon([(8, 3), (11, 6), (10, 10), (8, 12)], fill=(40, 115, 62, 255)); d.line([(6, 4), (5, 8)], fill=(140, 215, 150, 255))
    elif kind == "tok_vyshyvanka":  # клапоть вишивки: червоне й чорне на білому
        d.rectangle([2, 2, 13, 13], fill=(246, 240, 226, 255))
        red = (200, 40, 40, 255)
        for x, y in ((7, 3), (8, 3), (6, 4), (9, 4), (5, 5), (10, 5), (4, 6), (11, 6), (4, 9), (11, 9), (5, 10), (10, 10), (6, 11), (9, 11), (7, 12), (8, 12)): d.point((x, y), fill=red)
        for x, y in ((7, 6), (8, 6), (6, 7), (9, 7), (6, 8), (9, 8), (7, 9), (8, 9)): d.point((x, y), fill=O)
        d.point((3, 3), fill=red); d.point((12, 3), fill=red); d.point((3, 12), fill=red); d.point((12, 12), fill=red)
    elif kind == "tok_zeleni":  # русалчин вінок
        d.ellipse([1, 2, 14, 14], outline=(60, 150, 70, 255), width=3)
        for x, y in ((3, 3), (12, 4), (2, 9), (13, 10), (7, 13)): d.point((x, y), fill=(95, 190, 95, 255))
        for (x, y), col in (((7, 2), (235, 70, 70, 255)), ((12, 7), (250, 215, 80, 255)), ((3, 12), (110, 160, 240, 255)), ((11, 12), (240, 240, 245, 255)), ((2, 6), (240, 240, 245, 255))):
            d.rectangle([x, y, x + 1, y + 1], fill=col)
    elif kind == "tok_petra":  # мандрика: сирна паляничка
        d.ellipse([2, 4, 13, 13], fill=(236, 190, 100, 255)); d.ellipse([4, 5, 9, 8], fill=(250, 220, 150, 255))
        for x, y in ((6, 10), (9, 9), (11, 11), (5, 12), (8, 12)): d.point((x, y), fill=(180, 125, 55, 255))
    elif kind == "tok_derzhavnist":  # Володимирів срібник із тризубом
        d.ellipse([1, 1, 14, 14], fill=(200, 205, 215, 255)); d.ellipse([2, 2, 13, 13], outline=(150, 155, 168, 255))
        ink = (70, 75, 95, 255)
        d.line([(8, 4), (8, 11)], fill=ink); d.line([(5, 4), (5, 9)], fill=ink); d.line([(11, 4), (11, 9)], fill=ink)
        d.line([(5, 9), (11, 9)], fill=ink); d.point((8, 12), fill=ink); d.point((6, 10), fill=ink); d.point((10, 10), fill=ink)
    elif kind == "tok_illi":  # громова стріла
        d.polygon([(9, 0), (3, 8), (7, 8), (5, 15), (13, 6), (9, 6), (11, 0)], fill=(250, 215, 70, 255))
        d.line([(9, 1), (5, 8)], fill=(255, 245, 190, 255))
    elif kind == "tok_obzhynky":  # обжинковий сніп
        straw = (226, 182, 72, 255); dark = (180, 135, 45, 255)
        d.polygon([(1, 1), (14, 1), (9, 8), (6, 8)], fill=straw); d.polygon([(6, 8), (9, 8), (12, 15), (3, 15)], fill=straw)
        for x in (3, 6, 9, 12): d.line([(x, 1), (7 if x < 8 else 8, 8)], fill=dark)
        d.rectangle([5, 7, 10, 8], fill=(200, 45, 45, 255)); d.line([(5, 15), (7, 9)], fill=dark); d.line([(10, 15), (8, 9)], fill=dark)
    elif kind == "tok_zdvyzhennia":  # зміїна корона
        gold = (236, 192, 70, 255)
        d.polygon([(2, 13), (2, 5), (5, 9), (8, 3), (11, 9), (13, 5), (13, 13)], fill=gold); d.rectangle([2, 11, 13, 13], fill=(196, 150, 45, 255))
        d.rectangle([7, 9, 8, 10], fill=(60, 175, 95, 255)); d.point((2, 4), fill=(255, 240, 170, 255)); d.point((8, 2), fill=(255, 240, 170, 255)); d.point((13, 4), fill=(255, 240, 170, 255))
    elif kind == "tok_didy":  # лампадка
        d.polygon([(4, 7), (11, 7), (10, 14), (5, 14)], fill=(172, 40, 46, 255)); d.line([(5, 9), (5, 12)], fill=(225, 100, 100, 255))
        d.ellipse([6, 1, 9, 7], fill=(245, 150, 40, 255)); d.ellipse([7, 3, 8, 6], fill=(255, 235, 120, 255))
        d.rectangle([4, 14, 11, 15], fill=(200, 160, 60, 255)); d.rectangle([3, 6, 12, 7], fill=(200, 160, 60, 255))
    elif kind == "tok_mykhaila":  # архангелове перо
        d.polygon([(12, 1), (14, 3), (7, 12), (3, 14), (4, 10)], fill=(242, 242, 250, 255))
        d.line([(13, 2), (2, 15)], fill=(170, 175, 195, 255)); d.line([(10, 5), (12, 6)], fill=(205, 208, 222, 255)); d.line([(7, 8), (9, 10)], fill=(205, 208, 222, 255))
        d.point((13, 1), fill=(240, 200, 80, 255)); d.point((14, 2), fill=(240, 200, 80, 255))
    elif kind == "tok_kuzma":  # ковальська підкова
        iron = (150, 155, 168, 255)
        d.arc([2, 1, 13, 14], 180, 360, fill=iron, width=3); d.rectangle([2, 7, 4, 14], fill=iron); d.rectangle([11, 7, 13, 14], fill=iron)
        for x, y in ((3, 9), (3, 12), (12, 9), (12, 12), (5, 3), (10, 3)): d.point((x, y), fill=(60, 62, 75, 255))
        d.line([(3, 2), (6, 1)], fill=(215, 220, 232, 255))
    elif kind == "tok_kateryny":  # вишнева гілочка в цвіту
        d.line([(2, 15), (12, 3)], fill=(120, 75, 45, 255), width=1); d.line([(7, 9), (4, 6)], fill=(120, 75, 45, 255))
        for cx, cy in ((12, 3), (4, 5), (9, 7), (6, 11)):
            d.ellipse([cx - 2, cy - 2, cx + 1, cy + 1], fill=(252, 200, 215, 255)); d.point((cx - 1, cy - 1), fill=(255, 250, 235, 255))
        d.ellipse([10, 9, 13, 11], fill=(90, 170, 75, 255))
    elif kind == "tok_mykolai":  # миколайчик: медяник із глазур'ю
        cake = (190, 122, 62, 255)
        d.ellipse([2, 2, 8, 9], fill=cake); d.ellipse([7, 2, 13, 9], fill=cake); d.polygon([(2, 6), (13, 6), (8, 14)], fill=cake)
        ice = (255, 250, 240, 255)
        for x, y in ((4, 5), (5, 6), (6, 5), (7, 6), (8, 5), (9, 6), (10, 5), (11, 6)): d.point((x, y), fill=ice)
        d.point((7, 9), fill=(215, 60, 60, 255)); d.point((8, 9), fill=(215, 60, 60, 255)); d.point((7, 11), fill=ice); d.point((8, 11), fill=ice)
    elif kind == "khmil":  # шишка хмелю з листком
        for i, (cx, cy, r) in enumerate(((8, 5, 3), (6, 8, 3), (10, 8, 3), (8, 11, 3), (8, 13, 2))):
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(150, 195, 80, 255) if i % 2 == 0 else (120, 170, 65, 255))
        d.line([(8, 2), (8, 0)], fill=(90, 120, 50, 255)); d.ellipse([10, 0, 14, 3], fill=(70, 150, 60, 255))
    elif kind == "glory":  # козацька слава: зоря на стрічці
        d.polygon([(5, 0), (11, 0), (9, 6), (7, 6)], fill=(175, 40, 45, 255))
        d.polygon([(8, 5), (10, 9), (14, 9), (11, 12), (12, 16), (8, 13), (4, 16), (5, 12), (2, 9), (6, 9)], fill=(240, 195, 60, 255))
        d.point((8, 10), fill=(255, 245, 190, 255))
    return outline(im)

sheet = Image.new("RGBA", (16 * len(ORDER), 16), (0, 0, 0, 0))
for i, k in enumerate(ORDER):
    sheet.paste(draw(k), (i * 16, 0))
sheet.save(OUT); print("ok icons")
