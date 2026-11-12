extends RefCounted
## Збереження гри та налаштувань.
## - Кожне збереження має версію; старі версії мігрують до поточної.
## - Запис іде в тимчасовий файл, а потім атомарно замінює основний,
##   попередня версія лишається як .bak — збій під час запису не зіпсує прогрес.

const SAVE_VERSION := 11
const Data := preload("res://scripts/data/data.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const SAVE_PATH := "user://hero.save"  # старий єдиний файл — стає слотом 1 при першому запуску
const ACCOUNT_PATH := "user://account.save"  # спільне на всіх персонажів
const MAX_SLOTS := 5


static func slot_path(slot: int) -> String:
	return "user://hero_%d.save" % slot


## Короткі відомості про кожен слот для екрана персонажів (порожній словник — слот вільний).
static func slot_summaries() -> Array:
	var out := []
	for i in range(1, MAX_SLOTS + 1):
		var d := load_data(slot_path(i))
		if d.is_empty():
			# файл є, та не читається (зіпсований чи з новішої версії гри): слот не вільний,
			# інакше новий герой затер би його
			out.append({"slot": i, "broken": true} if exists(slot_path(i)) else {})
			continue
		var p: Dictionary = d.get("player", {})
		var w: Dictionary = d.get("world", {})
		var st: Dictionary = w.get("story", {})
		out.append({"slot": i, "job": p.get("job", "cossack"), "level": int(p.get("level", 1)), "job_level": int(p.get("job_level", 1)),
			"rank": p.get("rank", ""), "chapter": int(st.get("chapter", 0)), "done": st.get("stage", "") == "done",
			"playtime": float(d.get("meta", {}).get("playtime", 0.0)),
			"nick": load("res://scripts/game/name_service.gd").from_save(p.get("nick", ""))})
	return out


## Перший запуск після оновлення: hero.save → hero_1.save.
static func migrate_single_to_slots() -> void:
	if exists(SAVE_PATH) and not exists(slot_path(1)):
		for suffix in ["", ".bak"]:
			if FileAccess.file_exists(SAVE_PATH + suffix):
				DirAccess.rename_absolute(SAVE_PATH + suffix, slot_path(1) + suffix)


const SETTINGS_PATH := "user://settings.cfg"


static func exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func save(data: Dictionary, path: String = SAVE_PATH) -> bool:
	data["version"] = SAVE_VERSION
	return write_var(path, data)


## Безпечний запис: спершу тимчасовий файл, і лише коли він записався повністю, ним заміняється
## справжній (а попередній лишається копією .bak). Якщо місце на телефоні скінчилось і запис
## обірвався, добрий файл ніхто не чіпає: раніше його заміняли й недописаним.
static func write_var(path: String, data) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Не вдалося відкрити %s для запису" % tmp)
		return false
	var stored: bool = f.store_var(data)
	var werr := f.get_error()
	var size := f.get_length()
	f.close()
	if not stored or werr != OK or size <= 0:
		push_error("Запис %s обірвався, попереднє збереження лишилось як було" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Не вдалося замінити збереження: %s" % error_string(err))
		return false
	return true


## Повертає мігровані дані або порожній словник, якщо збереження нема чи воно зіпсоване.
static func load_data(path: String = SAVE_PATH) -> Dictionary:
	for p in [path, path + ".bak"]:
		var d := _read(p)
		if d.is_empty():
			continue
		var m := migrate(d)
		if not m.is_empty():
			return m
	return {}


static func delete(path: String = SAVE_PATH) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	if typeof(d) != TYPE_DICTIONARY or not d.has("player") or not d.has("world"):
		return {}
	return d


## Ланцюжок міграцій: кожен крок піднімає версію на одиницю.
static func migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	if v < 2 or v > SAVE_VERSION:
		return {}  # формат прототипу-арени або збереження з новішої версії гри
	if v == 2:
		# v3: метадані (час гри, дата створення); підказки — обов'язкове поле світу
		d["meta"] = {"playtime": 0.0, "created": Time.get_unix_time_from_system()}
		var w: Dictionary = d["world"]
		if not w.has("hints"):
			w["hints"] = {}
		v = 3
	if v == 3:
		# v4: нова крива досвіду — перераховуємо поріг рівня, накопичене не губимо понад поріг
		var p: Dictionary = d["player"]
		var lvl: int = int(p.get("level", 1))
		p["xp_next"] = Data.xp_for_level(lvl)
		p["xp"] = mini(int(p.get("xp", 0)), p["xp_next"] - 1)
		v = 4
	if v == 4:
		# v5: сюжет. Наявні герої починають перший розділ спочатку.
		if not d["world"].has("story"):
			d["world"]["story"] = {}
		v = 5
	if v == 5:
		# v6: хутір, ресурси, нагороди за рекламу
		var w6: Dictionary = d["world"]
		for k in ["camp", "boosts", "ads"]:
			if not w6.has(k):
				w6[k] = {}
		var p6: Dictionary = d["player"]
		if not p6.has("resources"):
			p6["resources"] = {"wood": 0, "iron": 0, "herbs": 0}
		v = 6
	if v == 6:
		# v7: на початку з'явився пролог — номери розділів у збереженнях зсуваються на один
		var st: Dictionary = d["world"].get("story", {})
		if not st.is_empty() and st.get("stage", "") != "done":
			st["chapter"] = int(st.get("chapter", 0)) + 1
		v = 7
	if v == 7:
		# v8: класи й рівень майстерності. Колишні козаки стають класом «Козак»;
		# вміння й перки скидаються з поверненням очок (дерева змінились), перки → Загартування.
		var p: Dictionary = d["player"]
		var rank: String = p.get("rank", "cossack")
		var lvl := int(p.get("level", 1))
		if rank == "peasant":
			p["job"] = "peasant"
			p["job_level"] = 1
			p["skills"] = {}
			p["skill_points"] = 0
			p["rank"] = ""
		else:
			p["job"] = "cossack"
			p["job_level"] = clampi(lvl, 1, 40)
			p["skills"] = {"whirl": 1}
			p["skill_points"] = int(p["job_level"]) - 1 + 9  # + очки, які дав би Селянин
			p["rank"] = "hetman" if rank == "hetman" else ""
		p["job_xp"] = 0
		p["perks"] = {}
		p["perk_points"] = lvl / 2
		# Пролог отримав розвилку: колишня «посвята» — тепер крок «присяга» на козацькій дорозі
		var st: Dictionary = d["world"].get("story", {})
		if not st.is_empty() and st.get("stage", "") != "done" and int(st.get("chapter", 0)) == 0 and int(st.get("step", 0)) >= 2:
			st["step"] = 3
			var ch: Dictionary = st.get("choices", {})
			ch["trial"] = 0
			if ch.has("initiation"):
				ch["oath"] = ch["initiation"]
				ch.erase("initiation")
			st["choices"] = ch
		elif not st.is_empty() and st.has("choices") and st["choices"].has("initiation"):
			st["choices"]["trial"] = 0
			st["choices"]["oath"] = st["choices"]["initiation"]
			st["choices"].erase("initiation")
		d["meta"] = d.get("meta", {})
		d["meta"]["notice"] = "classes"
		v = 8
	if v == 8:
		# v9: у пролозі з'явився крок «Обери дорогу» (індекс 3). Хто стояв на присязі чи далі —
		# зсувається на один; хто ще чекав на вибір у розмові з кошовим — отримує цей крок і йде
		# розмовляти з Мироном та Зореславою.
		var st: Dictionary = d["world"].get("story", {})
		if not st.is_empty() and st.get("stage", "") != "done" and int(st.get("chapter", 0)) == 0 and int(st.get("step", 0)) >= 3:
			st["step"] = int(st["step"]) + 1
		elif not st.is_empty() and st.get("stage", "") != "done" and int(st.get("chapter", 0)) == 0 and int(st.get("step", 0)) == 2 and st.get("stage", "") == "turnin":
			# стояв перед вибором у розмові: trial здається, далі — крок choose
			st["step"] = 3
			st["stage"] = "active"
			st["progress"] = 0
		v = 9
	if v == 9:
		# v10: зі світом зберігається товар крамниць, у метаданих — позначка незавершеного герцю,
		# в акаунті — годинник гри. Старому збереженню нічого доробляти: нові поля мають типові значення.
		v = 10
	if v == 10:
		# v11: досвід і гривні на речах не більші за Data.XP_GOLD_MAX_TOP при +10. Усі речі героя й світу
		# (вдягнені, у торбі, у крамницях і будь-де ще) перераховуються під нові числа.
		rescale_items_xp_gold(d)
		v = 11
	d["version"] = v
	return d


## Чи це річ спорядження (а не, скажімо, оголошення розшуку з масивом "affixes").
static func _is_item(n: Dictionary) -> bool:
	return typeof(n.get("affixes")) == TYPE_DICTIONARY and typeof(n.get("base")) == TYPE_DICTIONARY and n.has("rarity")


## Перерахувати досвід і гривні на всіх речах усередині node (словники й масиви будь-якої глибини).
## Кожна річ перераховується раз: на ній лишається позначка Data.XP_GOLD_MARK. Золота річ дістає
## рівно ті значення, що й Uniques.make на її рівні. Повертає, скільки речей змінено.
static func rescale_items_xp_gold(node) -> int:
	var n := 0
	if node is Array:
		for x in node:
			n += rescale_items_xp_gold(x)
	elif node is Dictionary:
		if _is_item(node):
			return 1 if _rescale_item(node) else 0
		for k in node:
			n += rescale_items_xp_gold(node[k])
	return n


static func _rescale_item(item: Dictionary) -> bool:
	if not Data.rescale_xp_gold(item):
		return false
	if Uniques.is_unique(item):
		var def_affixes: Dictionary = Uniques.DEFS[str(item["unique"])]["affixes"]
		for id in Data.XP_GOLD_ROLL:
			if item["affixes"].has(id) and def_affixes.has(id):
				item["affixes"][id] = Uniques.value(id, int(item.get("ilvl", 1)), float(def_affixes[id]))
	return true


# ---------- Налаштування ----------

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {"sound": true, "music": true, "autosell": false, "pickup": [true, true, true, true], "slot": 1}
	if cfg.load(SETTINGS_PATH) == OK:
		out["sound"] = cfg.get_value("audio", "sound", true)
		out["music"] = cfg.get_value("audio", "music", true)
		out["autosell"] = cfg.get_value("game", "autosell", false)
		# фільтр автопідбору: рядок із чотирьох знаків, «1» — рідкість підбирається
		var mask: String = str(cfg.get_value("game", "pickup", "1111"))
		for i in 4:
			out["pickup"][i] = i >= mask.length() or mask[i] != "0"
		out["slot"] = slot_num(cfg.get_value("game", "slot", 1))
	return out


## Номер слота з налаштувань: будь-яке сміття дає 1, число поза межами затискається в 1..MAX_SLOTS.
static func slot_num(v) -> int:
	var n := 1
	if v is int:
		n = v
	elif v is float and is_finite(v):
		n = int(v)
	elif v is String and v.strip_edges().is_valid_int():
		n = v.strip_edges().to_int()
	return clampi(n, 1, MAX_SLOTS)


static func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", settings.get("sound", true))
	cfg.set_value("audio", "music", settings.get("music", true))
	cfg.set_value("game", "autosell", settings.get("autosell", false))
	var mask := ""
	var pick: Array = settings.get("pickup", [true, true, true, true])
	for i in 4:
		mask += "1" if i >= pick.size() or bool(pick[i]) else "0"
	cfg.set_value("game", "pickup", mask)
	# останній герой, яким грали; без номера в словнику лишається записаний раніше
	cfg.set_value("game", "slot", slot_num(settings["slot"]) if settings.has("slot") else int(load_settings()["slot"]))
	cfg.save(SETTINGS_PATH)
