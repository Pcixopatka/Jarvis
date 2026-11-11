#!/usr/bin/env python3
"""Значки вмінь 24×24 (малюються ×2–×3). Запуск: python3 tools/pixel/skill_icons.py
→ assets/gfx/sprites/skill_icons.png і scripts/data/skill_icon_index.gd (id → клітинка)."""
import os, math
from PIL import Image, ImageDraw

S = 24
OUT_PNG = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "gfx", "sprites", "skill_icons.png")
OUT_GD = os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "data", "skill_icon_index.gd")
O = (27, 20, 32, 255); W = (250, 248, 240, 255); K = (30, 24, 34, 255)

def hx(h): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
def mul(c, k): return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), c[3])

RED = hx("d8402e"); ORANGE = hx("f08a2a"); GOLD = hx("f2c23a"); GREEN = hx("5fc04a"); BLUE = hx("4a90e8"); ICE = hx("a8dcff")
PURPLE = hx("9a5ad8"); GREY = hx("b8bcc8"); STEEL = hx("dfe4ee"); BROWN = hx("8a5a2a"); DARK = hx("3a3340"); SKIN = hx("f1c9a0")

# рамка за типом: атака — червона, баф — синя, пасивне — золотава
FRAME = {"attack": (hx("5a1a18"), hx("c84a3a")), "buff": (hx("16304a"), hx("3a7ac8")), "passive": (hx("3a2e14"), hx("a88a3a"))}

class G:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); self.d = ImageDraw.Draw(self.im)
    def line(self, a, b, c, w=2): self.d.line([a, b], fill=c, width=w)
    def circ(self, x, y, r, c): self.d.ellipse([x - r, y - r, x + r, y + r], fill=c)
    def ring(self, x, y, r, c, w=2): self.d.ellipse([x - r, y - r, x + r, y + r], outline=c, width=w)
    def rect(self, x0, y0, x1, y1, c): self.d.rectangle([x0, y0, x1, y1], fill=c)
    def poly(self, pts, c): self.d.polygon(pts, fill=c)
    def px(self, x, y, c):
        if 0 <= x < S and 0 <= y < S: self.im.putpixel((int(x), int(y)), c)

def sabre(g, c=STEEL, long=False):
    L = 17 if long else 14
    g.line((5, 19), (5 + L * 0.75, 19 - L * 0.75), c, 3); g.line((7, 19), (5 + L * 0.75 + 1, 19 - L * 0.75 + 1), mul(c, 0.6), 1)
    g.line((3, 17), (7, 21), BROWN, 3); g.line((2, 20), (8, 16), GOLD, 2)
def pitchfork(g):
    g.line((12, 22), (12, 8), BROWN, 3); g.line((6, 9), (18, 9), GREY, 2)
    for x in (6, 12, 18): g.line((x, 9), (x, 2), GREY, 2)
def cross(g, c=RED):
    g.rect(9, 3, 14, 20, W); g.rect(3, 9, 20, 14, W); g.rect(10, 4, 13, 19, c); g.rect(4, 10, 19, 13, c)
def heart(g, c=RED):
    g.circ(8, 9, 5, c); g.circ(16, 9, 5, c); g.poly([(3, 11), (21, 11), (12, 21)], c); g.px(7, 7, W); g.px(8, 6, W)
def boots(g):
    g.rect(6, 3, 11, 14, hx("a3231f")); g.rect(6, 14, 18, 19, hx("a3231f")); g.rect(6, 17, 18, 19, mul(hx("a3231f"), 0.7))
    for i in range(3): g.line((2, 6 + i * 4), (4, 6 + i * 4), W, 1)
def swirl(g, c=ICE):
    for i in range(3):
        r = 9 - i * 3
        g.d.arc([12 - r, 12 - r, 12 + r, 12 + r], 20 + i * 60, 300 + i * 60, fill=c, width=2)
def wind(g, c=ICE):
    for i, y in enumerate((6, 12, 18)): g.line((3 + i * 2, y), (18 - i * 2, y), c, 2); g.px(19 - i * 2, y - 1, c)
def arc_wide(g, c=STEEL):
    g.d.arc([2, 2, 22, 22], 200, 340, fill=c, width=3); sabre(g, c)
def tornado(g, c=ICE):
    for i, w in enumerate((18, 14, 10, 6, 3)): g.line((12 - w // 2 + (i % 2) * 2, 3 + i * 4), (12 + w // 2 + (i % 2) * 2, 3 + i * 4), c, 2)
def skull(g, c=W):
    g.circ(12, 10, 7, c); g.rect(8, 15, 16, 19, c); g.circ(9, 10, 2, K); g.circ(15, 10, 2, K); g.rect(11, 13, 13, 14, K)
    for x in (9, 12, 15): g.px(x, 18, K)
def shout(g, c=ORANGE):
    g.circ(8, 12, 5, SKIN); g.circ(8, 12, 2, K)
    for i in range(3): g.d.arc([8 - 2 + i * 0, 12 - 5 - i * 3, 8 + 6 + i * 3, 12 + 5 + i * 3], -40, 40, fill=c, width=2)
def shield(g, c=BLUE, inner=None):
    g.poly([(4, 3), (20, 3), (20, 12), (12, 21), (4, 12)], mul(c, 0.6)); g.poly([(6, 5), (18, 5), (18, 11), (12, 18), (6, 11)], c)
    if inner: g.rect(11, 7, 13, 14, inner); g.rect(9, 9, 15, 11, inner)
def fist_fire(g):
    fire(g, ORANGE, 6); g.rect(6, 12, 18, 21, SKIN); g.line((6, 15), (18, 15), mul(SKIN, 0.7), 1); g.line((6, 18), (18, 18), mul(SKIN, 0.7), 1)
def drop(g, c=RED):
    g.poly([(12, 2), (19, 14), (5, 14)], c); g.circ(12, 15, 7, c); g.px(9, 13, W); g.px(10, 12, W)
def thorns(g):
    g.rect(5, 8, 19, 20, hx("c6281e"))
    for x in (4, 9, 14, 19): g.poly([(x, 9), (x + 2, 2), (x + 4, 9)], STEEL)
def chain(g, c=GREY):
    for i in range(3): g.ring(5 + i * 7, 12 + (i % 2) * 3, 4, c, 2)
def anvil(g):
    g.rect(3, 8, 21, 12, DARK); g.rect(8, 12, 16, 18, DARK); g.rect(5, 18, 19, 21, DARK); g.line((3, 8), (21, 8), GREY, 1)
def musket(g):
    g.line((2, 20), (21, 7), BROWN, 4); g.line((5, 18), (21, 7), GREY, 2); g.rect(2, 17, 7, 21, BROWN); g.circ(21, 6, 2, GOLD)
def bullets(g, n=3):
    for i in range(n): g.rect(5 + i * 6, 6, 8 + i * 6, 18, GREY); g.poly([(5 + i * 6, 6), (8 + i * 6, 6), (6 + i * 6, 2)], STEEL)
def dash_arrow(g):
    g.line((3, 12), (18, 12), ICE, 3); g.poly([(16, 6), (22, 12), (16, 18)], ICE); g.line((3, 7), (8, 7), mul(ICE, 0.7), 1); g.line((3, 17), (8, 17), mul(ICE, 0.7), 1)
def spread(g, c=GOLD):
    for i in range(5):
        a = -0.6 + i * 0.3; x = 12 + math.cos(a - math.pi / 2) * 0; g.circ(int(4 + 16 * (i + 1) / 6), int(6 + abs(i - 2) * 4), 2, c)
    g.line((3, 20), (12, 12), BROWN, 3)
def crack(g):
    g.rect(2, 14, 22, 22, BROWN); g.d.line([(4, 22), (9, 15), (12, 19), (15, 11), (19, 16), (21, 8)], fill=K, width=2); g.poly([(12, 2), (16, 10), (8, 10)], ORANGE)
def mace(g, star=False):
    g.line((4, 21), (14, 9), BROWN, 3); g.circ(16, 7, 6, GREY)
    for a in range(0, 360, 60): g.px(16 + math.cos(math.radians(a)) * 7, 7 + math.sin(math.radians(a)) * 7, STEEL)
    if star: g.px(16, 7, GOLD); g.px(15, 6, GOLD); g.px(17, 8, GOLD)
def wall(g):
    for r in range(3):
        for i in range(3): g.rect(2 + i * 7 + (r % 2) * 3, 5 + r * 6, 7 + i * 7 + (r % 2) * 3, 9 + r * 6, hx("c08a5a"))
    g.rect(2, 4, 21, 21, (0, 0, 0, 0)) if False else None
def armor(g, c=GREY):
    g.poly([(5, 4), (19, 4), (21, 10), (18, 21), (6, 21), (3, 10)], c); g.rect(10, 4, 14, 21, mul(c, 0.7)); g.line((5, 4), (19, 4), STEEL, 1)
def trap(g):
    g.ring(12, 13, 8, GREY, 2)
    for a in range(0, 360, 45): g.line((12 + math.cos(math.radians(a)) * 8, 13 + math.sin(math.radians(a)) * 8), (12 + math.cos(math.radians(a)) * 4, 13 + math.sin(math.radians(a)) * 4), STEEL, 2)
    g.circ(12, 13, 2, BROWN)
def eye(g, c=W, closed=False):
    if closed: g.d.arc([3, 6, 21, 18], 20, 160, fill=c, width=2); return
    g.poly([(2, 12), (12, 5), (22, 12), (12, 19)], c); g.circ(12, 12, 4, BLUE); g.circ(12, 12, 2, K); g.px(11, 11, W)
def shadow(g):
    g.circ(12, 12, 9, DARK); g.circ(10, 10, 2, PURPLE); g.circ(15, 10, 2, PURPLE)
def spear(g):
    g.line((3, 21), (18, 6), BROWN, 2); g.poly([(14, 4), (21, 3), (20, 10)], STEEL)
def crosshair(g):
    g.ring(12, 12, 8, GOLD, 2); g.line((12, 2), (12, 22), GOLD, 1); g.line((2, 12), (22, 12), GOLD, 1); g.circ(12, 12, 2, RED)
def barrel(g):
    g.rect(6, 4, 18, 21, BROWN); g.line((6, 9), (18, 9), DARK, 2); g.line((6, 16), (18, 16), DARK, 2); g.line((12, 4), (15, 1), GREY, 1); g.circ(16, 1, 2, ORANGE)
def wolf(g):
    g.poly([(4, 4), (9, 10), (15, 10), (20, 4), (20, 14), (12, 21), (4, 14)], hx("7a7a7e")); g.circ(9, 12, 1, GOLD); g.circ(15, 12, 1, GOLD); g.poly([(10, 16), (14, 16), (12, 19)], K)
def bullet_x(g):
    g.rect(9, 5, 15, 17, GREY); g.poly([(9, 5), (15, 5), (12, 1)], STEEL); g.line((4, 4), (20, 20), RED, 2); g.line((20, 4), (4, 20), RED, 2)
def bolt(g, c=GOLD):
    g.poly([(14, 1), (6, 13), (12, 13), (9, 23), (19, 9), (13, 9)], c)
def sabre_bolt(g):
    sabre(g); bolt(g, ICE)
def star(g, c=GOLD):
    pts = []
    for i in range(10):
        r = 10 if i % 2 == 0 else 4; a = -math.pi / 2 + i * math.pi / 5
        pts.append((12 + math.cos(a) * r, 12 + math.sin(a) * r))
    g.poly(pts, c)
def leaf(g, c=GREEN):
    g.poly([(4, 20), (8, 6), (20, 4), (16, 18)], c); g.line((4, 20), (20, 4), mul(c, 0.6), 1)
def hand_up(g):
    g.rect(8, 10, 16, 21, SKIN)
    for i, x in enumerate((8, 11, 14)): g.rect(x, 4 + (i == 1) * -2, x + 2, 11, SKIN)
    g.rect(17, 7, 19, 13, SKIN); g.rect(10, 1, 14, 2, GREEN); g.rect(11, 0, 13, 3, GREEN)
def herbs(g):
    for i, x in enumerate((6, 12, 18)): g.line((x, 21), (x + (i - 1) * 3, 6), GREEN, 2); g.circ(x + (i - 1) * 3, 5, 3, hx("8ad86a"))
def sparkle(g, c=ICE):
    g.poly([(12, 2), (14, 10), (22, 12), (14, 14), (12, 22), (10, 14), (2, 12), (10, 10)], c); g.circ(12, 12, 2, W)
def flask(g, c=GREEN):
    g.rect(10, 2, 14, 7, GREY); g.circ(12, 15, 8, c); g.rect(6, 12, 18, 16, c); g.px(9, 12, W); g.px(10, 11, W)
def pulse(g):
    g.d.line([(2, 13), (7, 13), (9, 6), (12, 19), (14, 10), (16, 13), (22, 13)], fill=RED, width=2)
def storm(g):
    cloud(g, GREY); bolt(g, GOLD)
def cloud(g, c=GREY):
    g.circ(8, 11, 5, c); g.circ(13, 8, 6, c); g.circ(18, 11, 5, c); g.rect(4, 11, 22, 15, c)
def hammer(g):
    g.line((5, 21), (14, 10), BROWN, 3); g.rect(11, 2, 21, 11, GREY); g.rect(11, 2, 21, 4, STEEL)
def hail(g):
    cloud(g, GREY)
    for i, x in enumerate((6, 11, 16)): g.circ(x, 19 + (i % 2) * 2, 2, ICE)
def fog(g):
    for i in range(3): g.d.ellipse([3 + i, 5 + i * 6, 21 - i, 11 + i * 6], fill=(220, 225, 235, 140 + i * 30))
def ghost(g):
    g.circ(12, 10, 7, ICE); g.rect(5, 10, 19, 20, ICE)
    for x in (5, 10, 15): g.poly([(x, 20), (x + 4, 20), (x + 2, 23)], ICE)
    g.circ(9, 10, 1, K); g.circ(15, 10, 1, K)
def fire(g, c=ORANGE, base=None):
    g.poly([(12, 1), (19, 10), (18, 19), (12, 22), (6, 19), (5, 10)], c); g.poly([(12, 8), (16, 14), (12, 20), (8, 14)], GOLD); g.px(12, 15, W)
def spark(g, n=1):
    for i in range(n):
        x = 12 if n == 1 else 7 + i * 10
        g.poly([(x, 3), (x + 2, 10), (x + 8, 12), (x + 2, 14), (x, 21), (x - 2, 14), (x - 8, 12), (x - 2, 10)], GOLD)
def well(g):
    g.rect(4, 10, 20, 21, GREY); g.rect(6, 12, 18, 19, BLUE); g.line((3, 10), (21, 10), BROWN, 2); g.poly([(2, 10), (22, 10), (12, 2)], BROWN)
def wave(g, c=BLUE):
    for i in range(3): g.d.arc([2 + (i % 2) * 2, 4 + i * 6, 12 + (i % 2) * 2, 12 + i * 6], 180, 360, fill=c, width=2); g.d.arc([11 + (i % 2) * 2, 4 + i * 6, 21 + (i % 2) * 2, 12 + i * 6], 0, 180, fill=c, width=2)
def root(g):
    g.line((12, 3), (12, 12), GREEN, 3); g.d.line([(12, 12), (6, 18), (4, 22)], fill=BROWN, width=2); g.d.line([(12, 12), (18, 17), (20, 22)], fill=BROWN, width=2); g.d.line([(12, 14), (12, 22)], fill=BROWN, width=2)
def link(g):
    chain(g, ICE); bolt(g, GOLD)
def ring_people(g):
    shield(g, BLUE); g.circ(9, 10, 2, W); g.circ(15, 10, 2, W); g.rect(7, 12, 11, 15, W); g.rect(13, 12, 17, 15, W)
def long_sabre(g): sabre(g, STEEL, True)
def keg(g): barrel(g); g.rect(8, 6, 16, 8, GOLD)
def mace_star(g): mace(g, True)
def eye_closed(g): eye(g, PURPLE, True)
def spark2(g): spark(g, 2)
def heart_fire(g): heart(g); fire(g, ORANGE)
def trap_hunter(g): trap(g); g.circ(18, 6, 3, GOLD)
def bolt_cloud(g): cloud(g, DARK); bolt(g, GOLD)
def hourglass(g):
    g.poly([(5, 3), (19, 3), (12, 12), (5, 21), (19, 21), (12, 12)], GOLD); g.rect(5, 2, 19, 3, BROWN); g.rect(5, 21, 19, 22, BROWN)

def banner(g, c=RED):
    g.line((6, 22), (6, 2), BROWN, 2); g.poly([(7, 3), (20, 5), (17, 9), (20, 13), (7, 13)], c); g.rect(9, 7, 13, 9, GOLD)
def bow(g, c=BROWN):
    g.d.arc([2, 2, 18, 22], 270, 90, fill=c, width=2); g.line((10, 3), (10, 21), W, 1)
def arrow(g, c=STEEL, y=12):
    g.line((3, y), (19, y), BROWN, 1); g.poly([(19, y - 3), (23, y), (19, y + 3)], c); g.line((3, y - 2), (5, y), W, 1); g.line((3, y + 2), (5, y), W, 1)
def pistol(g, c=GREY, x=0, y=0):
    g.rect(4 + x, 8 + y, 18 + x, 11 + y, c); g.rect(4 + x, 11 + y, 8 + x, 17 + y, BROWN); g.px(19 + x, 7 + y, GOLD); g.line((9 + x, 12 + y), (11 + x, 14 + y), DARK, 1)
def falcon(g, c=BROWN):
    g.poly([(12, 7), (3, 4), (8, 12)], c); g.poly([(12, 7), (21, 4), (16, 12)], c); g.circ(12, 11, 4, mul(c, 1.3)); g.circ(12, 6, 3, hx("e0d2b0")); g.line((12, 7), (12, 10), GOLD, 2)
def axe(g, c=STEEL):
    g.line((6, 21), (15, 5), BROWN, 2); g.poly([(13, 3), (21, 5), (20, 12), (14, 9)], c); g.line((19, 6), (19, 11), W, 1)
def feather(g, c=W):
    g.poly([(6, 20), (10, 8), (17, 3), (15, 12)], c); g.line((6, 20), (16, 5), GREY, 1)
def both(*fns):
    def run(g):
        for fn in fns: fn(g)
    return run

ICONS = {
    # селянин
    "vyly": ("attack", pitchfork), "first_aid": ("buff", cross), "hardy": ("passive", heart), "roll": ("passive", boots),
    # козак
    "whirl": ("attack", swirl), "sharp": ("passive", sabre), "whirl_cd": ("passive", wind), "reach": ("passive", long_sabre), "cleave": ("passive", arc_wide),
    "storm": ("passive", tornado), "deadly": ("passive", skull), "battle_cry": ("buff", shout), "tough": ("passive", shield), "fury": ("passive", fist_fire),
    "ward": ("passive", lambda g: shield(g, GREEN)), "thirst": ("passive", drop), "thorns": ("passive", thorns), "unbreak": ("passive", anvil),
    "musket": ("attack", musket), "reload": ("passive", bullets), "dash_strike": ("passive", dash_arrow), "buckshot": ("passive", spread),
    # запорожець
    "zemnyi": ("attack", crack), "bulava": ("attack", mace), "mace_master": ("passive", mace_star), "stina": ("buff", wall), "iron_skin": ("passive", armor),
    "nevhamovnyi": ("passive", heart_fire), "zaporizka_vytryvalist": ("passive", lambda g: heart(g, hx("8c1418"))),
    "taran": ("attack", dash_arrow), "hrim_zemli": ("attack", both(crack, bolt)), "kremin": ("passive", lambda g: armor(g, GOLD)),
    "vidsich": ("passive", lambda g: shield(g, GOLD)), "shablia_master": ("passive", arc_wide), "spys_master": ("passive", spear),
    "dvobii": ("passive", lambda g: skull(g, GOLD)), "kryvavyi_zamakh": ("passive", both(sabre, drop)), "navala": ("buff", fist_fire),
    "mur": ("buff", wall), "khoruhva": ("buff", banner), "druhe_dykhannia": ("passive", pulse),
    # пластун
    "pastka": ("attack", trap), "tin": ("buff", shadow), "trapper": ("passive", trap_hunter), "kydok": ("attack", spear), "oko": ("passive", eye), "stryvok": ("passive", dash_arrow),
    # самопальник
    "kartech": ("attack", spread), "prytsil": ("attack", crosshair), "porokh": ("passive", keg), "shvydke": ("passive", bullets), "bochka": ("attack", barrel), "vluchnist": ("passive", crosshair),
    # характерник
    "vovk": ("buff", wolf), "kulia": ("buff", bullet_x), "wolf_blood": ("passive", lambda g: drop(g, hx("8a1020"))), "zamova": ("buff", sabre_bolt), "vidvid": ("attack", eye_closed), "spirit": ("passive", star),
    # знахар
    "zhyvytsia": ("buff", lambda g: (leaf(g), drop(g, hx("f2c23a")))), "pidniaty": ("buff", hand_up), "travnyk": ("passive", herbs), "ochyshchennia": ("buff", sparkle),
    "oberih_zahonu": ("buff", ring_people), "otruta": ("attack", flask), "zhyve_slovo": ("passive", pulse),
    # перунів жрець
    "lightning": ("attack", bolt), "chain": ("passive", link), "wrath": ("passive", storm), "grim": ("passive", bolt_cloud), "molot": ("attack", hammer), "burya": ("buff", storm), "storm_soul": ("passive", cloud),
    # нові вміння: Козак і Волхв
    "khvatka": ("passive", lambda g: shield(g, STEEL)), "kontrudar": ("passive", both(lambda g: shield(g, STEEL), sabre)), "pidsichka": ("attack", arc_wide),
    "pobratymstvo": ("passive", ring_people),
    "vohniane_kolo": ("attack", lambda g: (g.ring(12, 12, 9, ORANGE, 3), fire(g))), "krynytsia_syly": ("passive", lambda g: star(g, ICE)),
    "shvydke_slovo": ("passive", hourglass), "zamova_vohniu": ("passive", lambda g: fire(g, RED)), "dukh_predkiv": ("buff", ghost),
    # нові вміння: Пластун
    "zazubrene_lezo": ("passive", both(sabre, drop)), "udar_u_spynu": ("passive", both(shadow, sabre)), "dvi_shabli": ("passive", lambda g: (sabre(g), g.line((19, 19), (8, 6), STEEL, 2))),
    "zlyva_udariv": ("attack", lambda g: [g.line((4 + i * 5, 20), (10 + i * 5, 4), STEEL, 2) for i in range(3)]),
    "perekotypole": ("passive", dash_arrow), "lehka_khoda": ("passive", boots), "dymova_zavisa": ("buff", fog),
    "stiika_myslyvtsia": ("buff", crosshair), "stiika_tini": ("buff", lambda g: eye(g, PURPLE, True)),
    "mitka": ("attack", lambda g: (g.ring(12, 12, 8, PURPLE, 2), g.circ(12, 12, 3, RED))), "terpinnia": ("passive", lambda g: skull(g, GOLD)),
    "dobyvannia": ("passive", both(skull, lambda g: drop(g, RED))), "vovcha_yama": ("attack", lambda g: (g.d.ellipse([3, 9, 21, 21], fill=K), trap(g))),
    # нові вміння: Самопальник
    "zapalna_kulia": ("passive", both(bullets, lambda g: fire(g, RED))), "hranata": ("attack", lambda g: (g.circ(12, 14, 6, DARK), g.line((12, 8), (15, 4), BROWN, 2), g.circ(16, 3, 2, ORANGE))),
    "dymnyi_porokh": ("buff", lambda g: cloud(g, GREY)), "zalp": ("attack", lambda g: [g.line((3, 20), (6 + i * 3, 4), GOLD, 1) for i in range(6)]),
    "dalekyi_postril": ("passive", both(crosshair, lambda g: star(g, GOLD))), "tverda_ruka": ("passive", hand_up), "na_zvira": ("passive", lambda g: skull(g, ORANGE)),
    "nabii": ("passive", lambda g: bullets(g, 3)), "stiika_vluchnyka": ("buff", lambda g: (g.ring(12, 12, 8, GOLD, 2), g.circ(12, 12, 2, RED))),
    "stiika_rukhlyva": ("buff", both(boots, lambda g: wind(g, ICE))),
    # Стрілець
    "strila": ("attack", arrow), "luk_master": ("passive", bow), "podviinyi_postril": ("attack", lambda g: (arrow(g, STEEL, 8), arrow(g, STEEL, 16))),
    "dalekyi_bii": ("passive", both(bow, lambda g: star(g, GOLD))), "pistol_master": ("passive", pistol), "postril_vprytul": ("attack", both(pistol, lambda g: fire(g, ORANGE))),
    "shvydki_ruky": ("passive", lambda g: (pistol(g, GREY, 0, -4), pistol(g, STEEL, 0, 5))), "vidskok": ("buff", dash_arrow), "zirke_oko": ("passive", lambda g: eye(g, GOLD)),
    "lehkyi_krok": ("passive", boots), "serdiutska_vypravka": ("passive", lambda g: heart(g, hx("3a6ab8"))), "povnyi_sahaidak": ("passive", lambda g: [arrow(g, STEEL, y) for y in (6, 12, 18)]),
    "navodka": ("attack", lambda g: (g.ring(12, 12, 8, PURPLE, 2), g.line((12, 2), (12, 22), PURPLE, 1), g.line((2, 12), (22, 12), PURPLE, 1))),
    "stiika_zasidky": ("buff", lambda g: (leaf(g, GREEN), eye(g, W))), "stiika_nalotu": ("buff", both(dash_arrow, lambda g: fire(g, RED))),
    # Сагайдачник
    "vohniana_strila": ("attack", both(arrow, lambda g: fire(g, ORANGE))), "otruina_strila": ("attack", lambda g: (arrow(g, GREEN), drop(g, GREEN))),
    "viialo_stril": ("attack", lambda g: [g.line((3, 20), (8 + i * 4, 4), STEEL, 1) for i in range(4)]), "zlyva_stril": ("attack", lambda g: [g.line((4 + i * 5, 3), (2 + i * 5, 20), STEEL, 1) for i in range(4)]),
    "khmara_stril": ("attack", lambda g: (cloud(g, DARK), [g.line((6 + i * 4, 12), (5 + i * 4, 22), GOLD, 1) for i in range(4)])),
    "tuha_tiatyva": ("passive", lambda g: bow(g, hx("b07a3a"))), "shvydka_tiatyva": ("passive", both(bow, lambda g: wind(g, ICE))), "probyvna_strila": ("passive", lambda g: (armor(g, GREY), arrow(g, GOLD))),
    "zazubreni_vistria": ("passive", both(arrow, drop)), "zapasna_tiatyva": ("passive", hourglass), "viter_u_spynu": ("passive", lambda g: wind(g, ICE)),
    "oko_yastruba": ("passive", lambda g: (eye(g, GOLD), feather(g, GREY))), "pidranok": ("passive", lambda g: skull(g, RED)),
    "stiika_vezhi": ("buff", wall), "stiika_vitru": ("buff", lambda g: tornado(g, ICE)),
    # Опришок
    "dva_stvoly": ("attack", lambda g: (pistol(g, GREY, 0, -4), pistol(g, STEEL, 0, 5))), "viialo_kul": ("attack", spread), "kulia_v_lob": ("passive", crosshair),
    "shvydkyi_zariad": ("passive", lambda g: bullets(g, 3)), "sribna_kulia": ("attack", lambda g: (g.circ(12, 12, 6, STEEL), g.circ(10, 10, 2, W), sparkle(g, W))),
    "bartka": ("attack", axe), "kydok_bartky": ("attack", both(axe, lambda g: wind(g, GREY))), "arkan": ("attack", lambda g: (g.ring(12, 12, 9, RED, 2), axe(g))),
    "hirskyi_hart": ("passive", lambda g: heart(g, hx("3a8a3a"))), "vidchaidukh": ("passive", lambda g: drop(g, RED)), "zasidka_v_skeliakh": ("passive", both(shadow, pistol)),
    "vtecha_horamy": ("buff", lambda g: (g.poly([(2, 21), (9, 6), (14, 14), (18, 8), (22, 21)], GREY), dash_arrow(g))), "zdobychnyk": ("passive", lambda g: star(g, GOLD)),
    "vpertist": ("passive", lambda g: shield(g, hx("3a8a3a"))), "stiika_rozbiinyka": ("buff", lambda g: skull(g, RED)), "stiika_vatazhka": ("buff", banner),
    # Сокольник
    "sokil": ("buff", falcon), "kihti": ("passive", lambda g: [g.line((6 + i * 5, 4), (4 + i * 5, 19), STEEL, 2) for i in range(3)]), "sokolyna_mitka": ("passive", lambda g: (falcon(g), g.ring(12, 12, 10, PURPLE, 1))),
    "pike": ("attack", lambda g: (falcon(g), g.line((12, 14), (12, 22), RED, 2))), "zhraia": ("attack", lambda g: [g.poly([(x, y), (x - 5, y - 3), (x - 2, y + 2)], BROWN) or g.poly([(x, y), (x + 5, y - 3), (x + 2, y + 2)], BROWN) for x, y in ((7, 7), (16, 6), (11, 14), (18, 16), (5, 18))]),
    "strila_lovchoho": ("attack", lambda g: (arrow(g), feather(g, GREY))), "lovcha_nauka": ("passive", both(bow, arrow)), "syltsia": ("attack", lambda g: (g.ring(12, 14, 7, BROWN, 2), g.line((12, 7), (12, 2), BROWN, 1))),
    "znannia_zvira": ("passive", lambda g: wolf(g)), "zviryne_chuttia": ("passive", lambda g: eye(g, GREEN)), "pokhidnyi_dukh": ("passive", lambda g: heart(g, hx("b07a3a"))),
    "ptashyna_mova": ("passive", lambda g: (feather(g), sparkle(g, GOLD))), "lehka_ruka": ("passive", hand_up), "sokolyne_oko": ("passive", lambda g: (eye(g, GOLD), star(g, GOLD))),
    "stiika_lovtsia": ("buff", both(bow, crosshair)), "stiika_ptakha": ("buff", lambda g: (falcon(g), sparkle(g, GOLD))),
    # нові вміння: Характерник
    "vovche_vyttia": ("attack", both(wolf, lambda g: wind(g, GREY))), "zviryna_syla": ("passive", lambda g: heart(g, hx("8a1020"))), "nichnyi_zir": ("passive", lambda g: eye(g, GOLD)),
    "stiika_vovka": ("buff", lambda g: (wolf(g), g.px(20, 3, RED), g.px(21, 3, RED))), "zamova_krovi": ("buff", lambda g: drop(g, RED)),
    "slovo_i_shablia": ("passive", both(sabre, lambda g: star(g, ICE))), "vidvernennia": ("passive", eye_closed), "stiika_slova": ("buff", lambda g: star(g, BLUE)),
    "morok": ("attack", lambda g: fog(g)), "dvi_dushi": ("passive", lambda g: (g.circ(8, 12, 5, ICE), g.circ(16, 12, 5, PURPLE))), "zahovorenyi": ("buff", lambda g: shield(g, GOLD, RED)),
    # нові вміння: Знахар
    "chorna_khvoroba": ("attack", lambda g: cloud(g, GREEN)), "yid": ("passive", lambda g: flask(g, PURPLE)), "blekota": ("attack", lambda g: (leaf(g, PURPLE), sparkle(g, W))),
    "smertelna_doza": ("passive", lambda g: (flask(g, RED), g.px(12, 8, W))), "tsiliushche_kolo": ("buff", lambda g: (g.ring(12, 12, 9, GREEN, 2), cross(g, GREEN))),
    "hirka_trava": ("passive", lambda g: leaf(g, hx("8a9a3a"))), "polyn": ("passive", herbs), "syla_zela": ("passive", lambda g: (leaf(g), sparkle(g, GOLD))),
    "stiika_tsilytelia": ("buff", lambda g: heart(g, GREEN)), "stiika_otruinyka": ("buff", lambda g: flask(g, GREEN)),
    # нові вміння: Перунів жрець
    "kulova": ("attack", lambda g: (g.circ(12, 12, 7, GOLD), g.circ(12, 12, 4, W), bolt(g, BLUE))), "naelektryzovanyi": ("passive", lambda g: spark(g, 2)),
    "blyskavychnyi_krok": ("attack", both(dash_arrow, lambda g: bolt(g, GOLD))), "syla_neba": ("passive", lambda g: (cloud(g, ICE), star(g, GOLD))),
    "perunovyi_sud": ("attack", both(hammer, bolt)), "hromovyi_shchyt": ("buff", lambda g: (shield(g, BLUE), bolt(g, GOLD))),
    "zapakh_hrozy": ("passive", lambda g: wind(g, GOLD)), "hromovidvid": ("passive", lambda g: (g.line((12, 22), (12, 4), GREY, 2), bolt(g, GOLD))),
    "stiika_buri": ("buff", bolt_cloud), "stiika_tyshi": ("buff", lambda g: cloud(g, ICE)),
    # нові вміння: Мольфар
    "moroz": ("passive", lambda g: sparkle(g, ICE)), "vykhor_molfara": ("attack", lambda g: tornado(g, ICE)), "kryha": ("passive", lambda g: (g.poly([(12, 2), (19, 12), (12, 22), (5, 12)], ICE), g.line((12, 4), (12, 20), W, 1))),
    "stiika_nehody": ("buff", storm), "stiika_skeli": ("buff", lambda g: (g.poly([(3, 21), (9, 7), (14, 13), (18, 5), (22, 21)], GREY), g.poly([(9, 7), (11, 11), (7, 12)], W))),
    "kamenepad": ("attack", lambda g: [g.circ(x, y, r, GREY) for x, y, r in ((7, 7, 3), (15, 5, 2), (12, 13, 4), (18, 16, 3), (6, 18, 2))]),
    "navrok": ("passive", lambda g: eye(g, PURPLE)), "trembita": ("buff", lambda g: (g.line((3, 19), (20, 5), BROWN, 3), g.circ(20, 5, 2, GOLD))),
    "hirska_voda": ("passive", lambda g: wave(g, ICE)), "sertse_hir": ("buff", lambda g: (heart(g, GREEN), sparkle(g, W))),
    # мольфар
    "grad": ("attack", hail), "tuman": ("buff", fog), "khmara": ("passive", cloud), "proklin": ("attack", lambda g: skull(g, PURPLE)), "dukh": ("buff", ghost),
    # волхв
    "fireball": ("attack", fire), "iskra": ("passive", spark), "pyre": ("passive", lambda g: fire(g, RED)), "twin_spark": ("passive", spark2), "shield": ("buff", lambda g: shield(g, ICE, BLUE)),
    "deep_well": ("passive", well), "mana_flow": ("passive", wave), "focus": ("passive", lambda g: eye(g, ICE)), "herb": ("buff", leaf), "regen": ("passive", root),
}

def frame(g, kind):
    bg, bd = FRAME[kind]
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(base)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=5, fill=bg, outline=bd, width=1)
    d.rounded_rectangle([1, 1, S - 2, S // 2], radius=4, fill=mul(bg, 1.35))
    base.alpha_composite(g.im)
    d2 = ImageDraw.Draw(base); d2.rounded_rectangle([0, 0, S - 1, S - 1], radius=5, outline=O, width=1)
    return base

ids = list(ICONS.keys())
cols = 12; rows = (len(ids) + cols - 1) // cols
sheet = Image.new("RGBA", (S * cols, S * rows), (0, 0, 0, 0))
for i, cid in enumerate(ids):
    kind, fn = ICONS[cid]
    g = G(); fn(g)
    sheet.paste(frame(g, kind), ((i % cols) * S, (i // cols) * S))
sheet.save(OUT_PNG)
with open(OUT_GD, "w") as f:
    f.write("extends RefCounted\n## Згенеровано tools/pixel/skill_icons.py — клітинка значка кожного вміння на листі skill_icons.png.\n\nconst SIZE := %d\nconst COLS := %d\nconst INDEX := {\n" % (S, cols))
    for i, cid in enumerate(ids): f.write('\t"%s": %d,\n' % (cid, i))
    f.write("}\n")
print("ok", len(ids), "icons")
