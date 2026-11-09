extends RefCounted
## Збереження гри та налаштувань.
## - Кожне збереження має версію; старі версії мігрують до поточної.
## - Запис іде в тимчасовий файл, а потім атомарно замінює основний,
##   попередня версія лишається як .bak — збій під час запису не зіпсує прогрес.

const SAVE_VERSION := 7
const Data := preload("res://scripts/data/data.gd")
const SAVE_PATH := "user://hero.save"
const SETTINGS_PATH := "user://settings.cfg"


static func exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func save(data: Dictionary, path: String = SAVE_PATH) -> bool:
	data["version"] = SAVE_VERSION
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Не вдалося відкрити %s для запису" % tmp)
		return false
	f.store_var(data)
	f.close()
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
	d["version"] = v
	return d


# ---------- Налаштування ----------

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var out := {"sound": true, "music": true}
	if cfg.load(SETTINGS_PATH) == OK:
		out["sound"] = cfg.get_value("audio", "sound", true)
		out["music"] = cfg.get_value("audio", "music", true)
	return out


static func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", settings.get("sound", true))
	cfg.set_value("audio", "music", settings.get("music", true))
	cfg.save(SETTINGS_PATH)
