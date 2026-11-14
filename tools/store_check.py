#!/usr/bin/env python3
"""Перевірка матеріалів для Google Play: довжини текстів, розміри зображень, узгодженість пресетів збірки.
Запуск: python3 tools/store_check.py   (код виходу 1, якщо щось не вкладається у вимоги магазину)
"""
import os, re, sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
STORE = os.path.join(ROOT, "docs", "store")
LIMITS = {"Назва": 30, "Короткий опис": 80, "Повний опис": 4000, "Що нового": 500, "Title": 30, "Short description": 80, "Full description": 4000}
bad = []


def check(ok, text):
    print(("  гаразд  " if ok else "  ЗАВЕЛИКЕ/ХИБНЕ  ") + text)
    if not ok:
        bad.append(text)


def texts():
    src = open(os.path.join(STORE, "listing.md"), encoding="utf-8").read()
    for m in re.finditer(r"\*\*([^*]+)\*\*[^\n]*\n\n```\n(.*?)\n```", src, re.S):
        name, body = m.group(1), m.group(2)
        if name in LIMITS:
            check(len(body) <= LIMITS[name], "%s: %d знаків із %d" % (name, len(body), LIMITS[name]))


def image(path, size=None, min_side=None, max_side=None, max_ratio=None):
    im = Image.open(os.path.join(STORE, path))
    ok = im.mode == "RGB"
    if size:
        ok = ok and im.size == size
    if min_side:
        ok = ok and min(im.size) >= min_side
    if max_side:
        ok = ok and max(im.size) <= max_side
    if max_ratio:
        ok = ok and max(im.size) / min(im.size) <= max_ratio
    check(ok, "%s: %d×%d, %s, %d КБ" % (path, im.size[0], im.size[1], im.mode, os.path.getsize(os.path.join(STORE, path)) // 1024))


def presets():
    src = open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8").read()
    blocks = re.split(r"\n\[preset\.\d+\]\n", "\n" + src)[1:]
    keys = ["version/code", "version/name", "package/unique_name", "exclude_filter", "launcher_icons/main_192x192"]
    vals = [{k: re.search(re.escape(k) + r"=(.*)", b).group(1) for k in keys} for b in blocks]
    check(len(blocks) == 2 and vals[0] == vals[1], "два пресети збірки (APK і AAB) з однаковими версією, пакетом і значком: %s, код %s" % (vals[0]["version/name"], vals[0]["version/code"]))
    check('export_format=1' in blocks[1] and 'use_gradle_build=true' in blocks[1], "пресет «Google Play» збирає AAB через Gradle")
    check('export_format=0' in blocks[0] and 'use_gradle_build=true' in blocks[0], "пресет «Android» збирає APK через Gradle (у грі плагін реклами)")
    check('custom_features="store"' in blocks[1] and 'custom_features=""' in blocks[0], "справжня реклама (ознака store) лише в пресеті «Google Play», APK — з тестовою")


def main():
    print("Тексти сторінки:")
    texts()
    print("Зображення:")
    image("icon_512.png", size=(512, 512))
    image("feature_1024x500.png", size=(1024, 500))
    shots = sorted(f for f in os.listdir(os.path.join(STORE, "screenshots")) if f.endswith(".png"))
    check(2 <= len(shots) <= 8, "знімків екрана: %d (треба від 2 до 8)" % len(shots))
    for f in shots:
        image(os.path.join("screenshots", f), min_side=320, max_side=3840, max_ratio=2.0)
    print("Збірка:")
    presets()
    print("Усе вкладається у вимоги." if not bad else "Не вкладається: %d" % len(bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
