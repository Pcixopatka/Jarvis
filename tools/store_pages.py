#!/usr/bin/env python3
"""Публічні сторінки для Google Play із текстів docs/store: політика приватності й видалення облікового запису.
Сторінки лягають у docs/ і відкриваються через GitHub Pages (гілка сховища, тека /docs):
  docs/index.html                  — заголовна, з посиланнями
  docs/privacy/index.html          — з docs/store/privacy-policy.md
  docs/delete-account/index.html   — з docs/store/delete-account.md
  docs/.nojekyll                   — щоб GitHub віддавав файли як є
Береться лише текст після першого рядка «---» (до нього — службова примітка для нас).

Запуск:  python3 tools/store_pages.py          — записати сторінки
         python3 tools/store_pages.py --check  — лише перевірити, що вони свіжі (код виходу 1, якщо ні)
"""
import html, os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
DOCS = os.path.join(ROOT, "docs")
PAGES = [
    ("privacy", "store/privacy-policy.md", "Політика приватності • Козацька Звитяга"),
    ("delete-account", "store/delete-account.md", "Видалення облікового запису • Козацька Звитяга"),
]
CSS = """body{margin:0;background:#14110d;color:#eadfc8;font:17px/1.6 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:24px 18px 64px}
h1{font-size:28px;line-height:1.25;color:#f2c14e;margin:8px 0 20px}
h2{font-size:23px;color:#f2c14e;margin:40px 0 12px;padding-top:16px;border-top:1px solid #4a3d24}
h3{font-size:19px;color:#f2c14e;margin:26px 0 8px}
a{color:#f2c14e}
li{margin:6px 0}
code{background:#241e15;padding:1px 5px;border-radius:4px}
nav{margin:0 0 8px;font-size:15px}
nav a{margin-right:16px}"""


def inline(text):
    out = html.escape(text, quote=False)
    out = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", lambda m: '<a href="%s">%s</a>' % (m.group(2).replace('"', "%22"), m.group(1)), out)
    out = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", out)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    return out


def body_html(md):
    """Мала частина Markdown, якої досить цим текстам: заголовки, абзаци, списки, жирне, посилання."""
    out, para, lst = [], [], None

    def flush():
        nonlocal para, lst
        if para:
            out.append("<p>%s</p>" % inline(" ".join(para)))
            para = []
        if lst:
            out.append("</%s>" % lst)
            lst = None

    for line in md.splitlines():
        s = line.strip()
        m = re.match(r"(#{1,3})\s+(.*)", s)
        item = re.match(r"(?:[-*]|(\d+)\.)\s+(.*)", s)
        if not s:
            flush()
        elif m:
            flush()
            out.append("<h%d>%s</h%d>" % (len(m.group(1)), inline(m.group(2)), len(m.group(1))))
        elif item:
            kind = "ol" if item.group(1) else "ul"
            if para or lst != kind:
                flush()
                out.append("<%s>" % kind)
                lst = kind
            out.append("<li>%s</li>" % inline(item.group(2)))
        else:
            if lst:
                flush()
            para.append(s)
    flush()
    return "\n".join(out)


def page(title, body, up):
    nav = '<nav><a href="%s">Козацька Звитяга</a><a href="%sprivacy/">Політика приватності</a><a href="%sdelete-account/">Видалення облікового запису</a></nav>' % (up or "./", up, up)
    return """<!doctype html>
<html lang="uk">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>
%s
</style>
</head>
<body>
<main>
%s
%s
</main>
</body>
</html>
""" % (html.escape(title), CSS, nav, body)


def source(rel):
    md = open(os.path.join(DOCS, rel), encoding="utf-8").read()
    head, sep, rest = md.partition("\n---\n")
    title = re.match(r"#\s+(.*)", head.strip()).group(1)
    return title, rest


def build():
    files = {".nojekyll": ""}
    for folder, rel, tab in PAGES:
        title, rest = source(rel)
        files[folder + "/index.html"] = page(tab, "<h1>%s</h1>\n%s" % (inline(title), body_html(rest)), "../")
    home = "<h1>Козацька Звитяга</h1>\n<p>Мобільна екшн-RPG про козака, який рушає проти чорної зарази. Розробник: Sich Lab Studio.</p>\n<ul>\n<li><a href=\"privacy/\">Політика приватності</a></li>\n<li><a href=\"delete-account/\">Видалення облікового запису</a></li>\n</ul>\n<p>Зв'язок: sichlab.studio@ukr.net</p>"
    files["index.html"] = page("Козацька Звитяга", home, "")
    return files


def stale():
    """Які сторінки не збігаються з текстами (порожньо — усе свіже)."""
    out = []
    for rel, text in build().items():
        path = os.path.join(DOCS, rel)
        if not os.path.exists(path) or open(path, encoding="utf-8").read() != text:
            out.append(rel)
    return out


def main():
    if "--check" in sys.argv:
        old = stale()
        print("Сторінки свіжі." if not old else "Застарілі сторінки: %s. Запусти python3 tools/store_pages.py" % ", ".join(old))
        sys.exit(1 if old else 0)
    for rel, text in build().items():
        path = os.path.join(DOCS, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "w", encoding="utf-8").write(text)
        print("записано docs/" + rel)


if __name__ == "__main__":
    main()
