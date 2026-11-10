#!/usr/bin/env python3
"""Збирає звукові ресурси гри з вільних наборів (усі — CC0, див. assets/audio/LICENSE.md).

Запуск:
    python3 tools/audio/build_audio.py --src <тека з джерелами> [--only sfx|music|ambient]

Тека джерел (у репозиторій не входить) має три підтеки:
    sfx_src/<набір>/...   розпаковані архіви наборів (PACKS нижче: звідки кожен)
    music_src/            файли мелодій
    ambient_src/          файли фонових шумів
Усі файли беруться з opengameart.org: https://opengameart.org/sites/default/files/<файл>.

Що робить:
  * звуки — зводить шари (удар + дзенькіт тощо), обрізає тишу, вирівнює гучність, пише моно OGG
    у assets/audio/sfx/<назва>_<n>.ogg; кілька варіантів одного звуку гра чергує навмання;
  * музику — обрізає задовгі доріжки, вирівнює гучність (EBU R128), пише стерео OGG у assets/audio/music/;
  * фонові шуми — вирізає відтинок і зшиває кінець із початком, щоб петля не клацала; assets/audio/ambient/;
  * пише scripts/data/sound_index.gd — перелік того, що є (у зібраній грі теки не перелічити).
Потрібні ffmpeg і numpy.
"""
import argparse, os, subprocess, sys
import numpy as np

RATE = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")

# Набори: тека в sfx_src, сторінка на opengameart.org, автор. Усі ліцензії — CC0.
PACKS = {
    "art_rpg": ("rpg_sound_pack", "rpg-sound-pack", "artisticdude"),
    "swishes": ("swishes", "swishes-sound-pack", "artisticdude"),
    "kenney_rpg": ("RPGsounds_Kenney", "50-rpg-sound-effects", "Kenney"),
    "kenney_ui": ("UI_SFX_Set", "51-ui-sound-effects-buttons-switches-and-clicks", "Kenney"),
    "rd_rpg80": ("80-CC0-RPG-SFX_0", "80-cc0-rpg-sfx", "rubberduck"),
    "rd_cr1": ("80-CC0-creature-SFX_0", "80-cc0-creature-sfx", "rubberduck"),
    "rd_cr2": ("80-CC0-creature-sfx-2", "80-cc0-creture-sfx-2", "rubberduck"),
    "rd_100": ("100-CC0-SFX_0", "100-cc0-sfx", "rubberduck"),
    "rd_100v2": ("sfx_100_v2", "100-cc0-sfx-2", "rubberduck"),
    "rd_bang": ("25-CC0-bang-sfx", "25-cc0-bang-firework-sfx", "rubberduck"),
    "rd_water": ("water-splash-slime-sfx", "40-cc0-water-splash-slime-sfx", "rubberduck"),
    "sn_sword": ("sword_-_starninjas_1", "20-sword-sound-effects-attacks-and-clashes", "StarNinjas"),
    "sn_clash": ("sword_clash_-_starninjas_0", "20-sword-sound-effects-attacks-and-clashes", "StarNinjas"),
    "jagged": ("magic_jaggedstone", "magic-spell-sfx", "JaggedStone"),
    "ogrebane": ("teleport_ogrebane", "teleport-spell", "Ogrebane"),
}

# Шар: (набір, файл, підсилення дБ, затримка мс, швидкість). Швидкість < 1 робить звук нижчим і довшим.
def L(pack, name, gain=0.0, delay=0, rate=1.0):
    return (pack, name, gain, delay, rate)

# Звук гри -> варіанти; варіант — список шарів. Гучність варіантів вирівнюється сама.
SFX = {
    # --- зброя
    "swing": [[L("swishes", "swish-1.wav")], [L("swishes", "swish-4.wav")], [L("swishes", "swish-6.wav")], [L("swishes", "swish-9.wav")],
              [L("art_rpg", "swing2.wav")], [L("art_rpg", "swing3.wav")]],
    "hit": [[L("kenney_rpg", "chop.ogg")],
            [L("rd_100v2", "sfx100v2_hit_02.ogg"), L("rd_rpg80", "blade_01.ogg", -9)],
            [L("rd_100v2", "sfx100v2_wood_hit_02.ogg"), L("rd_rpg80", "blade_03.ogg", -10)],
            [L("rd_100", "hit_03.ogg")]],
    "crit": [[L("kenney_rpg", "chop.ogg"), L("sn_clash", "sword_clash.5.ogg", -5)],
             [L("rd_100v2", "sfx100v2_hit_02.ogg"), L("sn_clash", "sword_clash.2.ogg", -5)],
             [L("rd_100v2", "sfx100v2_wood_hit_01.ogg"), L("sn_clash", "sword_clash.8.ogg", -6)]],
    "clash": [[L("sn_clash", "sword_clash.1.ogg")], [L("sn_clash", "sword_clash.3.ogg")], [L("sn_clash", "sword_clash.10.ogg")]],
    "slash": [[L("sn_sword", "sword.2.ogg")], [L("sn_sword", "sword.6.ogg")], [L("sn_sword", "sword.4.ogg")]],
    "unsheathe": [[L("art_rpg", "sword-unsheathe.wav")], [L("art_rpg", "sword-unsheathe2.wav")]],
    "shoot": [[L("swishes", "swish-12.wav")], [L("swishes", "swish-13.wav")]],
    "musket": [[L("rd_bang", "shot_02.ogg"), L("rd_bang", "bang_03.ogg", -5)], [L("rd_bang", "shot_01.ogg"), L("rd_bang", "bang_07.ogg", -7)]],
    "boom": [[L("rd_bang", "cannon_02.ogg")], [L("rd_bang", "bang_03.ogg")], [L("rd_bang", "cannon_01.ogg")]],
    "whirl": [[L("swishes", "swish-7.wav"), L("swishes", "swish-3.wav", 0, 130), L("swishes", "swish-8.wav", 0, 260), L("swishes", "swish-9.wav", -2, 390)]],
    "dodge": [[L("kenney_rpg", "cloth1.ogg"), L("swishes", "swish-2.wav", -6)], [L("kenney_rpg", "cloth2.ogg"), L("swishes", "swish-5.wav", -6)]],
    # --- герой і нечисть
    "hurt": [[L("rd_100v2", "sfx100v2_wood_hit_01.ogg"), L("art_rpg", "cloth.wav", -4)],
             [L("rd_100", "hit_04.ogg"), L("art_rpg", "cloth-heavy.wav", -6)],
             [L("rd_100", "slam_04.ogg")]],
    "step": [[L("kenney_rpg", "footstep00.ogg")], [L("kenney_rpg", "footstep01.ogg")], [L("kenney_rpg", "footstep02.ogg")], [L("kenney_rpg", "footstep05.ogg")]],
    "enemy_die": [[L("rd_rpg80", "creature_die_01.ogg")], [L("rd_rpg80", "creature_hurt_01.ogg")], [L("art_rpg", "mnstr4.wav")],
                  [L("art_rpg", "ogre3.wav")], [L("rd_cr2", "die_03.ogg")]],
    "die_beast": [[L("art_rpg", "wolfman.wav")], [L("art_rpg", "mnstr1.wav")], [L("art_rpg", "mnstr3.wav")], [L("rd_cr1", "barking_01.ogg")]],
    "die_undead": [[L("art_rpg", "shade1.wav")], [L("art_rpg", "shade3.wav")], [L("art_rpg", "shade4.wav")], [L("rd_cr2", "die_02.ogg")]],
    "die_slime": [[L("rd_rpg80", "creature_slime_01.ogg")], [L("rd_rpg80", "creature_slime_03.ogg")], [L("rd_rpg80", "creature_slime_02.ogg")]],
    "die_human": [[L("rd_cr2", "human_03.ogg")], [L("rd_cr2", "human_07.ogg")], [L("rd_cr2", "human_05.ogg")]],
    "die_spirit": [[L("art_rpg", "shade5.wav")], [L("art_rpg", "shade6.wav")], [L("rd_cr2", "die_04.ogg")]],
    "roar": [[L("rd_rpg80", "creature_roar_01.ogg", 0, 0, 0.85)], [L("rd_rpg80", "creature_roar_03.ogg", 0, 0, 0.85)], [L("art_rpg", "giant2.wav", 0, 0, 0.8)]],
    # --- чари
    "lightning": [[L("rd_100v2", "sfx100v2_thunder_01.ogg"), L("rd_rpg80", "spell_02.ogg", -3)]],
    "fire": [[L("rd_rpg80", "spell_fire_06.ogg")], [L("rd_rpg80", "spell_fire_07.ogg")], [L("rd_rpg80", "spell_fire_05.ogg")]],
    "spell": [[L("rd_rpg80", "spell_01.ogg")], [L("art_rpg", "magic1.wav")]],
    "zap": [[L("rd_rpg80", "spell_02.ogg")], [L("rd_rpg80", "spell_02.ogg", 0, 0, 1.18)]],
    "heal": [[L("art_rpg", "bubble3.wav"), L("rd_rpg80", "spell_01.ogg", -9)], [L("art_rpg", "bottle.wav"), L("art_rpg", "bubble.wav", -3, 120)]],
    "portal": [[L("ogrebane", "teleport.wav")]],
    # --- здобич і нагороди
    "coin": [[L("art_rpg", "coin3.wav")], [L("rd_rpg80", "item_coins_01.ogg")], [L("rd_rpg80", "item_coins_03.ogg")]],
    "coins": [[L("art_rpg", "coin2.wav")], [L("rd_rpg80", "item_coins_02.ogg")]],
    "item": [[L("art_rpg", "armor-light.wav")], [L("art_rpg", "cloth-heavy.wav")], [L("art_rpg", "chainmail1.wav")]],
    "quest": [[L("rd_rpg80", "item_gem_04.ogg"), L("art_rpg", "coin2.wav", -8, 80)]],
    "levelup": [[L("jagged", "magical_3.ogg"), L("rd_rpg80", "item_gem_04.ogg", -4, 150)]],
    "sharpen_ok": [[L("art_rpg", "metal-ringing.wav"), L("sn_sword", "sword.6.ogg", -7, 60)]],
    "sharpen_fail": [[L("rd_100v2", "sfx100v2_metal_hit_01.ogg"), L("art_rpg", "metal-small3.wav", -4, 40)]],
    # --- інтерфейс і побут
    "click": [[L("kenney_ui", "click3.wav")], [L("kenney_ui", "click1.wav")]],
    "page": [[L("kenney_rpg", "bookFlip1.ogg")], [L("kenney_rpg", "bookFlip2.ogg")]],
    "door": [[L("kenney_rpg", "doorOpen_1.ogg")]],
    "pot": [[L("kenney_rpg", "metalPot1.ogg")]],
    "rustle": [[L("kenney_rpg", "cloth3.ogg")], [L("kenney_rpg", "cloth1.ogg")]],
    "dice": [[L("rd_rpg80", "stones_01.ogg")], [L("rd_rpg80", "stones_04.ogg"), L("rd_rpg80", "stones_02.ogg", -4, 120)]],
    "splash": [[L("rd_water", "splash_02.ogg")], [L("rd_water", "splash_04.ogg")], [L("rd_water", "splash_08.ogg")]],
}
# Найдовша дозволена тривалість (секунди); решта звуку плавно згасає.
MAX_LEN = {"lightning": 1.7, "boom": 1.0, "musket": 0.8, "levelup": 1.9, "portal": 1.3, "roar": 1.1, "quest": 1.0, "coins": 0.8, "pot": 0.9, "door": 0.8}

# Музика: назва в грі -> (файл, початок с, кінець с або 0 — до кінця, згасання наприкінці с). Автор — RandomMind, крім «boss».
MUSIC = {
    "menu": ("The_Bards_Tale.mp3", 0, 0, 3.0),
    "map": ("Exploration_0.mp3", 0, 180, 5.0),
    "city": ("Market_Day.mp3", 0, 0, 3.0),
    "inn": ("The_Old_Tower_Inn.mp3", 0, 0, 3.0),
    "camp": ("harvestseason_2.mp3", 0, 150, 5.0),
    "battle": ("battle_8.mp3", 0, 0, 1.5),
    "boss": ("determined_pursuit_loop.wav", 0, 0, 0.0),  # Emma_MA; петля вже безшовна
    "festive": ("Rejoicing_0.mp3", 0, 0, 3.0),
    "victory": ("victory_0.mp3", 0, 7.0, 1.5),  # лише перша фраза: мотив перемоги на кілька секунд
    "defeat": ("defeat_0.mp3", 0, 8.5, 3.0),
}
MUSIC_PAGES = {"menu": "medieval-the-bards-tale", "map": "medieval-exploration", "city": "medieval-market-day", "inn": "medieval-the-old-tower-inn",
               "camp": "medieval-harvest-season", "battle": "medieval-battle", "boss": "determined-pursuit-epic-orchestra-loop",
               "festive": "medieval-rejoicing", "victory": "medieval-victory-theme", "defeat": "medieval-defeat-theme"}

# Фонові шуми: назва -> (файл, початок с, довжина с, сторінка, автор).
AMBIENT = {
    "forest": ("birds-isaiah658_0.ogg", 0.5, 29.0, "ambient-bird-sounds", "isaiah658"),
    "wind": ("wind1.wav", 5.0, 24.0, "wind1", "Luke.RUSTLTD"),
    "night": ("crickets_1.mp3", 0.2, 11.0, "crickets-ambient-noise-loopable", "Wolfgang_"),
    "cave": ("dungeon_ambient_1_0.ogg", 10.0, 30.0, "loopable-dungeon-ambience", "JaggedStone"),
    "river": ("VistulaShort_0.mp3", 60.0, 24.0, "sea-and-river-wave-sounds", "RandomMind"),
    "fire": ("fire.wav", 2.0, 12.0, "fireplace-sound-loop", "PagDev"),
    "crowd": ("crowd_shouting_0.ogg", 0.5, 26.0, "crowd-shoutingspeaking-ambience", "StarNinjas"),
}


def decode(path, channels=1):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", str(channels), "-ar", str(RATE), "-f", "f32le", "-"], capture_output=True).stdout
    x = np.frombuffer(raw, dtype=np.float32).copy()
    return x.reshape(-1, channels) if channels > 1 else x


def encode(x, path, quality=5):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    channels = 1 if x.ndim == 1 else x.shape[1]
    data = np.clip(x, -1.0, 1.0).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", str(channels), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), "-map_metadata", "-1", path], input=data, check=True)


def trim_silence(x, thr=0.02):
    """Обрізати тишу на початку (до першого помітного звуку) й наприкінці."""
    if x.size == 0:
        return x
    peak = float(np.max(np.abs(x))) + 1e-9
    idx = np.where(np.abs(x) > peak * thr)[0]
    if idx.size == 0:
        return x
    a = max(0, idx[0] - int(0.002 * RATE))
    b = min(x.size, idx[-1] + int(0.03 * RATE))
    return x[a:b]


def speed(x, rate):
    if abs(rate - 1.0) < 1e-3:
        return x
    n = int(x.size / rate)
    return np.interp(np.linspace(0, x.size - 1, n), np.arange(x.size), x).astype(np.float32)


def fade(x, head_ms=2.0, tail_ms=25.0):
    x = x.copy()
    h = min(x.shape[0] // 2, int(head_ms * RATE / 1000))
    t = min(x.shape[0] // 2, int(tail_ms * RATE / 1000))
    if h > 0:
        ramp = np.linspace(0.0, 1.0, h, dtype=np.float32)
        x[:h] = x[:h] * (ramp if x.ndim == 1 else ramp[:, None])
    if t > 0:
        ramp = np.linspace(1.0, 0.0, t, dtype=np.float32)
        x[-t:] = x[-t:] * (ramp if x.ndim == 1 else ramp[:, None])
    return x


def normalize(x, rms_db=-18.0, peak_db=-1.5):
    """Вирівняти за середньою гучністю, але не вище заданого піку."""
    peak = float(np.max(np.abs(x))) + 1e-9
    rms = float(np.sqrt(np.mean(x ** 2))) + 1e-9
    gain = min(rms_db - 20 * np.log10(rms), peak_db - 20 * np.log10(peak))
    return x * (10 ** (gain / 20.0))


class Sources:
    def __init__(self, src):
        self.src = src
        self.index = {}

    def find(self, pack, name):
        if pack not in self.index:
            base = os.path.join(self.src, "sfx_src", PACKS[pack][0])
            files = {}
            for root, _, names in os.walk(base):
                for n in names:
                    if not n.startswith("._"):
                        files[n] = os.path.join(root, n)
            self.index[pack] = files
        if name not in self.index[pack]:
            sys.exit("Нема файлу %s у наборі %s (%s)" % (name, pack, PACKS[pack][0]))
        return self.index[pack][name]


def build_sfx(src):
    S = Sources(src)
    out_dir = os.path.join(OUT, "sfx")
    os.makedirs(out_dir, exist_ok=True)
    for f in os.listdir(out_dir):
        if f.endswith(".ogg"):
            os.remove(os.path.join(out_dir, f))
    counts = {}
    used = {}
    print("%-16s %5s %6s %6s %6s" % ("звук", "трив", "пік", "rms", "центр"))
    for name, variants in SFX.items():
        for i, layers in enumerate(variants):
            parts = []
            total = 0
            for pack, fname, gain, delay, rate in layers:
                x = speed(trim_silence(decode(S.find(pack, fname))), rate)
                x = x / (float(np.max(np.abs(x))) + 1e-9) * (10 ** (gain / 20.0))  # кожен шар спершу до повного піку, тоді своє підсилення
                at = int(delay * RATE / 1000)
                parts.append((at, x))
                total = max(total, at + x.size)
                used.setdefault(pack, set()).add(fname)
            mix = np.zeros(total, dtype=np.float32)
            for at, x in parts:
                mix[at:at + x.size] += x
            limit = MAX_LEN.get(name, 0.0)
            tail = 25.0
            if limit > 0 and mix.size > limit * RATE:
                mix = mix[:int(limit * RATE)]
                tail = 250.0
            mix = normalize(fade(trim_silence(mix), 2.0, tail))
            path = os.path.join(out_dir, "%s_%d.ogg" % (name, i + 1))
            encode(mix, path, 5)
            spec = np.abs(np.fft.rfft(mix * np.hanning(mix.size)))
            cen = float(np.sum(spec * np.fft.rfftfreq(mix.size, 1.0 / RATE)) / (np.sum(spec) + 1e-9))
            print("%-16s %5.2f %6.1f %6.1f %6.0f" % ("%s_%d" % (name, i + 1), mix.size / RATE, 20 * np.log10(np.max(np.abs(mix)) + 1e-9),
                                                 20 * np.log10(np.sqrt(np.mean(mix ** 2)) + 1e-9), cen))
        counts[name] = len(variants)
    return counts, used


def build_music(src):
    out_dir = os.path.join(OUT, "music")
    os.makedirs(out_dir, exist_ok=True)
    for name, (fname, start, end, fade_out) in MUSIC.items():
        path = os.path.join(src, "music_src", fname)
        if not os.path.exists(path):
            sys.exit("Нема мелодії " + path)
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path], capture_output=True, text=True).stdout)
        stop = end if end > 0 else dur
        af = ["atrim=%g:%g" % (start, stop), "asetpts=PTS-STARTPTS", "loudnorm=I=-19:TP=-1.5:LRA=11"]
        if fade_out > 0:
            af.append("afade=t=out:st=%g:d=%g" % (stop - start - fade_out, fade_out))
        out = os.path.join(out_dir, name + ".ogg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-af", ",".join(af), "-ar", str(RATE), "-ac", "2",
                        "-c:a", "libvorbis", "-q:a", "1", "-map_metadata", "-1", out], check=True)
        print("%-10s %6.1f с  %5.2f МБ" % (name, stop - start, os.path.getsize(out) / 1e6))
    return list(MUSIC.keys())


def build_ambient(src):
    out_dir = os.path.join(OUT, "ambient")
    os.makedirs(out_dir, exist_ok=True)
    for name, (fname, start, length, _page, _author) in AMBIENT.items():
        path = os.path.join(src, "ambient_src", fname)
        if not os.path.exists(path):
            sys.exit("Нема шуму " + path)
        x = decode(path)
        a = int(start * RATE)
        x = x[a:a + int(length * RATE)]
        # Зшити петлю: хвіст плавно переходить у початок
        n = min(int(1.5 * RATE), x.size // 4)
        ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)
        head = x[:n] * ramp + x[-n:] * (1.0 - ramp)
        loop = np.concatenate([head, x[n:-n]])
        loop = normalize(loop, -26.0, -3.0)
        out = os.path.join(out_dir, name + ".ogg")
        encode(loop, out, 2)
        seam = abs(float(loop[0]) - float(loop[-1]))
        print("%-8s %5.1f с  %4.0f КБ  шов %.4f" % (name, loop.size / RATE, os.path.getsize(out) / 1e3, seam))
    return list(AMBIENT.keys())


def write_index(sfx_counts, music, ambient):
    path = os.path.join(ROOT, "scripts", "data", "sound_index.gd")
    lines = ["extends RefCounted", "## Перелік звукових файлів (пише tools/audio/build_audio.py; руками не правити).",
             "## Звук <назва> має варіанти res://assets/audio/sfx/<назва>_<1..n>.ogg.", "",
             "const SFX := {"]
    for name in sorted(sfx_counts):
        lines.append('\t"%s": %d,' % (name, sfx_counts[name]))
    lines.append("}")
    lines.append("const MUSIC := [%s]" % ", ".join('"%s"' % m for m in music))
    lines.append("const AMBIENT := [%s]" % ", ".join('"%s"' % a for a in ambient))
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def write_license(used):
    lines = ["# Звук і музика", "",
             "Усе в цій теці взято з вільних наборів на opengameart.org з ліцензією **CC0 1.0** (суспільне надбання):",
             "можна вільно використовувати, змінювати й поширювати, зокрема в комерційних проєктах, без зазначення авторства.",
             "Авторів названо на знак подяки. Файли зведено, обрізано й вирівняно за гучністю скриптом `tools/audio/build_audio.py`.", "",
             "## Звукові ефекти (`sfx/`)", "", "| Набір | Автор | Сторінка | Узято файлів |", "|---|---|---|---|"]
    seen = {}
    for pack in sorted(used):
        folder, page, author = PACKS[pack]
        key = (page, author)
        seen[key] = seen.get(key, 0) + len(used[pack])
    for (page, author), n in sorted(seen.items(), key=lambda kv: kv[0][1].lower()):
        lines.append("| %s | %s | https://opengameart.org/content/%s | %d |" % (page, author, page, n))
    lines += ["", "## Музика (`music/`)", "", "| Доріжка | Автор | Сторінка |", "|---|---|---|"]
    for name in MUSIC:
        lines.append("| %s | %s | https://opengameart.org/content/%s |" % (name, "Emma_MA" if name == "boss" else "RandomMind", MUSIC_PAGES[name]))
    lines += ["", "## Фонові шуми (`ambient/`)", "", "| Шум | Автор | Сторінка |", "|---|---|---|"]
    for name, (_f, _s, _l, page, author) in AMBIENT.items():
        lines.append("| %s | %s | https://opengameart.org/content/%s |" % (name, author, page))
    open(os.path.join(OUT, "LICENSE.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True)
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    counts, used = build_sfx(args.src) if args.only in ("", "sfx") else ({}, {})
    music = build_music(args.src) if args.only in ("", "music") else []
    ambient = build_ambient(args.src) if args.only in ("", "ambient") else []
    if args.only == "":
        write_index(counts, music, ambient)
        write_license(used)


if __name__ == "__main__":
    main()
