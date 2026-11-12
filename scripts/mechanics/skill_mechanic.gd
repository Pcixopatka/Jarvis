extends "res://scripts/mechanics/hero_mechanic.gd"
## Механіка вміння з власною дією (того, чого шаблони дії за даними не вміють). Назва, ціна, перезарядка,
## підпис і опис лежать у вузлі data/skills.json, вузол називає свій скрипт («mechanic»: "skill/whirl"),
## а дія, її таймери й стан, відгуки на події бою і цифри картки — код у scripts/mechanics/skill/<id>.gd.
## Формула дії й текст, що її описує, лежать в одному файлі, тож розійтися не можуть.
##
## Рушій (Player) створює один об'єкт на вміння, коли герой його вивчив (recalc). Ціну наснаги й
## перезарядку списує рушій, якщо cast() повернув true. Для картки ще не вивченого вміння рушій бере
## тимчасовий об'єкт без стану: card() і cooldown() мусять залежати лише від героя й рангу.

const BASE_PATH := "res://scripts/mechanics/skill_mechanic.gd"

## Id уміння (під ним герой зберігає ранг).
var id := ""


## Ранг уміння в героя.
func rank() -> int:
	return p.sk(id)


## Дія вміння. true — спрацювало (рушій спише наснагу й поставить перезарядку), false — ні (нема цілі…).
func cast() -> bool:
	return false


## Перезарядка до загальних поправок героя: base — із вузла («cd»). Повертає нову.
func cooldown(base: float) -> float:
	return base


## Цифри картки на ранзі r (r ≥ 1): [["назва", "значення"], ...]. Числа беруться з тих самих формул, що й дія.
func card(_r: int) -> Array:
	return []


# ---------- Завантаження ----------

## Скрипт механіки вміння за посиланням ("skill/whirl"); null — нема файлу чи не та основа.
static func script_of(ref: String) -> Script:
	return Loader.script_of(ref, BASE_PATH)


## Новий об'єкт механіки вміння id для героя player (null — посилання нікуди не веде, з гучною помилкою).
static func create(ref: String, skill_id: String, player):
	var s: Script = script_of(ref)
	if s == null:
		push_error("Механіка вміння «%s» не знайдена (%s)" % [ref, Loader.path_of(ref)])
		return null
	var m = s.new()
	m.p = player
	m.id = skill_id
	m.num = int(Classes.find_node(skill_id).get("num", 0))
	m.bits = hooks_of(s, BASE_PATH)
	return m
