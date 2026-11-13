extends RefCounted
## Збереження гри та налаштувань.
## - Кожне збереження має версію; старі версії мігрують до поточної.
## - Запис іде в тимчасовий файл, а потім атомарно замінює основний,
##   попередня версія лишається як .bak — збій під час запису не зіпсує прогрес.

const SAVE_VERSION := 13
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
		var w = load("res://scripts/game/world_state.gd").new()
		w.missions = d.get("world", {}).get("missions", {})
		var SS = load("res://scripts/game/story_service.gd")
		out.append({"slot": i, "job": p.get("job", "cossack"), "level": int(p.get("level", 1)), "job_level": int(p.get("job_level", 1)),
			"rank": p.get("rank", ""), "chapter": int(SS.chapter_index(w)), "done": bool(SS.finished(w)),
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
	if v == 11:
		# v12: завдання всіх ліній веде один рушій (QuestEngine): замість номерів розділу й кроку історії
		# та номерів кроків переказів і саги — id зданих і початих кроків (world.missions).
		migrate_quests(d["world"])
		v = 12
	if v == 12:
		# v13: Селянин росте до 20-ї майстерності (було 10), перший клас — до 50-ї (було 40). Хто вже змінив
		# клас, тих рівнів набрати не міг: за кожен пройдений клас — очки за рівні понад колишню вершину.
		# Лише раз: далі збереження вже v13, а герой, створений на v13, сюди не потрапляє.
		var got := job_bonus_v12(str(d["player"].get("job", "peasant")))
		if got > 0:
			d["player"]["skill_points"] = int(d["player"].get("skill_points", 0)) + got
			d["meta"] = d.get("meta", {})
			d["meta"]["job_bonus"] = got  # банер при першому вході (Game._continue_game)
		v = 13
	d["version"] = v
	refresh_golden(d)
	return d


# ---------- Золоті речі: головний бонус за нинішнім ступенем ----------

## Головний бонус золотої речі несе множник її ступеня (Uniques.make), а ступінь лежить у записі golden.json, не в
## збереженні. Коли ступінь речі змінено в даних (ступені йдуть за рівнями босів), наявна річ того самого id і рівня
## дістає головний бонус нового ступеня. Усе інше (властивості, перекований бонус, заточка) не змінюється. Діє при
## кожному читанні збереження й нічого не міняє, якщо речі вже такі, як треба; версія збереження та сама.
## Повертає, скільки речей змінено.
static func refresh_golden(node) -> int:
	var n := 0
	if node is Array:
		for x in node:
			n += refresh_golden(x)
	elif node is Dictionary:
		if _is_item(node):
			if Uniques.is_unique(node) and Uniques.has(str(node["unique"])):
				var base: Dictionary = Uniques.make(str(node["unique"]), int(node.get("ilvl", 1)))["base"]
				if var_to_str(base) != var_to_str(node["base"]):
					node["base"] = base
					return 1
			return 0
		for k in node:
			n += refresh_golden(node[k])
	return n


# ---------- v13: вища майстерність ----------

## Вершина майстерності за ступенем до v13 (0 — Селянин, 1 — перший клас). Заморожено тут: у таблиці класів
## уже нові числа, а міграція мусить знати старі.
const V12_JOB_MAX := {0: 10, 1: 40}


## Скільки очок умінь додати героєві зі збереження v12 класу job: за кожен клас, який він уже пройшов
## (усі на його дорозі, крім нинішнього), — рівні від колишньої вершини до нинішньої («job_max» запису).
## Селянинові й нинішньому класу нічого: ці рівні герой набере сам.
static func job_bonus_v12(job: String) -> int:
	var C = Data.Classes
	if not C.has_class(job):
		return 0
	var line: Array = C.lineage(job)
	var got := 0
	for i in line.size() - 1:
		var info: Dictionary = C.info(str(line[i]))
		var tier := int(info["tier"])
		if V12_JOB_MAX.has(tier):
			got += maxi(0, int(info["job_max"]) - int(V12_JOB_MAX[tier])) * Data.SKILL_POINTS_PER_LEVEL
	return got


# ---------- v12: завдання за id кроків ----------
# Порядок кроків, яким їх вела гра до v12, заморожено тут: старі номери читаються лише через ці списки,
# тож таблиці можна переставляти й доповнювати, не ламаючи старих збережень.

## Розділи історії до v12 (місце розділу в story_chapters.json) → id кроків у розділі (місце кроку).
const V11_STORY := [
	["village", "flee", "trial", "choose", "oath", "to_carpathians", "volkhv_trial", "back_to_sich", "to_baturyn", "strilets_trial", "back_to_sich_s"],
	["recruit", "legend", "road", "potion", "camp", "lair"],
	["kyiv_call", "crypt", "to_chernihiv", "samples", "scouts", "border", "sorcerer"],
	["west_call", "walls", "opryshky", "dovbush", "tower"],
	["rada", "smolensk", "orders", "gates"],
	["kremlin"],
]
## Кроки гілок прологу до v12 і їхні умови: такий крок, якщо гравець обрав іншу дорогу, гра пропускала.
const V11_STORY_IF := {"oath": "trial=0", "to_carpathians": "trial=1", "volkhv_trial": "trial=1", "back_to_sich": "trial=1",
	"to_baturyn": "trial=2", "strilets_trial": "trial=2", "back_to_sich_s": "trial=2"}
## Перекази до v12: лінійка → id кроків за номером кроку.
const V11_LEGENDS := {
	"kozhumiaka": ["kozhumiaka_1", "kozhumiaka_2"],
	"dovbush": ["dovbush_1", "dovbush_2", "dovbush_3"],
	"solovei": ["solovei_1", "solovei_2", "solovei_3"],
	"vii": ["vii_1", "vii_2", "vii_3"],
	"bila_pani": ["bila_pani_1", "bila_pani_2"],
	"shubin": ["shubin_1", "shubin_2"],
	"morskyi_tsar": ["morskyi_tsar_1", "morskyi_tsar_2"],
	"lykho": ["lykho_1", "lykho_2"],
	"lisovyi_did": ["lisovyi_did_1", "lisovyi_did_2"],
	"idolyshche": ["idolyshche_1", "idolyshche_2", "idolyshche_3"],
	"karachun": ["karachun_1", "karachun_2"],
	"drakula": ["drakula_1", "drakula_2", "drakula_3"],
}
## «Попіл за вітром» до v12: id кроків за номером кроку.
const V11_SAGA := ["saga_dev", "saga_khala", "saga_velnias", "saga_baba", "saga_chornoboh"]


## Світ збереження v11 → v12: world.story / legends / saga (номери) → world.missions (id кроків).
static func migrate_quests(w: Dictionary) -> void:
	w["missions"] = quests_from_v11(w.get("story", {}), w.get("legends", {}), w.get("saga", {}))
	for k in ["story", "legends", "saga"]:
		w.erase(k)


## Стан рушія завдань зі старих станів. story: {"chapter", "step", "stage", "progress", "choices"} ({} — нова
## гра), legends: {лінійка: {"step", "stage", "progress"}}, saga: {"step", "stage"}. stage: offer / active /
## turnin / done. Пройдене стає зданим (крок гілки, якої гравець не обирав, — ні: рушій сам бачить його
## пропущеним), нинішній крок на етапі active чи turnin — початим зі своїм лічильником, offer — нічим
## (рушій сам бачить його відкритим).
static func quests_from_v11(story: Dictionary, legends: Dictionary, saga: Dictionary) -> Dictionary:
	var m := {"done": {}, "active": {}, "choices": {}}
	var made: Dictionary = story.get("choices", {})
	for k in made:
		m["choices"][str(k)] = int(made[k])
	if not story.is_empty():
		var stage := str(story.get("stage", "offer"))
		var at := Vector2i(int(story.get("chapter", 0)), int(story.get("step", 0)))
		if stage == "done":
			at = Vector2i(V11_STORY.size(), 0)
		for c in V11_STORY.size():
			for i in V11_STORY[c].size():
				var id: String = V11_STORY[c][i]
				if c < at.x or (c == at.x and i < at.y):
					var cond: String = V11_STORY_IF.get(id, "")
					if cond == "" or int(m["choices"].get(cond.get_slice("=", 0), -1)) == int(cond.get_slice("=", 1)):
						m["done"][id] = true
				elif c == at.x and i == at.y and stage in ["active", "turnin"]:
					m["active"][id] = {"stage": stage, "progress": int(story.get("progress", 0))}
	for line in V11_LEGENDS:
		if legends.has(line) and legends[line] is Dictionary:
			_v11_line(m, V11_LEGENDS[line], legends[line])
	if not saga.is_empty():
		_v11_line(m, V11_SAGA, saga)
	return m


static func _v11_line(m: Dictionary, ids: Array, s: Dictionary) -> void:
	var stage := str(s.get("stage", "offer"))
	var at := ids.size() if stage == "done" else int(s.get("step", 0))
	for i in ids.size():
		if i < at:
			m["done"][ids[i]] = true
		elif i == at and stage in ["active", "turnin"]:
			m["active"][ids[i]] = {"stage": stage, "progress": int(s.get("progress", 0))}


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
		var def_affixes: Dictionary = Uniques.def(str(item["unique"]))["affixes"]
		for id in Data.capped_stats():
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
