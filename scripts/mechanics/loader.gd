extends RefCounted
## Вантажник механік, спільний для всіх родин: нечисть (mechanic.gd), найманці (companion_mechanic.gd),
## улюбленці (pet_mechanic.gd). Запис у таблиці називає свій скрипт посиланням ("boss/koshchii",
## "companion/dzhura", "pet/pes"), а тут це посилання стає скриптом: раз на всю гру, з кешу.
## Кожна родина має свою основу (скрипт, від якого походять її механіки) і свій перелік хуків.

const DIR := "res://scripts/mechanics/"

static var _scripts := {}  # посилання → скрипт (null — нема такого файлу)
static var _hooks := {}  # скрипт → біти хуків, які він написав


## Шлях до файлу механіки за посиланням із запису ("boss/koshchii" → res://scripts/mechanics/boss/koshchii.gd).
static func path_of(ref: String) -> String:
	return DIR + ref + ".gd"


## Скрипт механіки за посиланням, якщо він походить від основи base_path; інакше null. Вантажиться раз
## на всю гру. Шлях до .gd працює й у збірці для телефона: там скрипти лежать як .gdc, і Godot сам
## іде за переадресуванням (.remap). Тому теки ніколи не переглядаємо під час гри.
static func script_of(ref: String, base_path: String) -> Script:
	if not _scripts.has(ref):
		var s: Script = null
		if ref != "" and ResourceLoader.exists(path_of(ref)):
			s = load(path_of(ref)) as Script
		_scripts[ref] = s
	var out: Script = _scripts[ref]
	if out != null and not extends_base(out, base_path):
		return null
	return out


## Чи скрипт походить від основи (його ланцюг предків доходить до base_path).
static func extends_base(s: Script, base_path: String) -> bool:
	while s != null:
		if s.resource_path == base_path:
			return true
		s = s.get_base_script()
	return false


## Біти хуків (hooks: назва методу → біт), які написав скрипт чи його предки, крім самої основи.
static func hooks_of(s: Script, base_path: String, hooks: Dictionary) -> int:
	if s == null:
		return 0
	if not _hooks.has(s):
		var bits := 0
		var cur := s
		while cur != null and cur.resource_path != base_path:
			# Перелік методів скрипту: спершу власні, далі всіх предків
			var own: Array = cur.get_script_method_list()
			var base := cur.get_base_script()
			var n_base: int = base.get_script_method_list().size() if base != null else 0
			for i in own.size() - n_base:
				bits |= int(hooks.get(own[i]["name"], 0))
			cur = base
		_hooks[s] = bits
	return _hooks[s]
