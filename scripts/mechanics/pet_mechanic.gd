extends RefCounted
## Механіка улюбленця: що робить у бою той, хто ходить за героєм (пес, кіт, ворон, а з божих дарів —
## Хованець, вороний скакун, чумацька мажа). Ім'я, ціна й хист лежать у data/pets.json, запис називає
## свій скрипт («mechanic»: "pet/pes"), а поведінка — код у scripts/mechanics/pet/<id>.gd. Запис без
## механіки в бій не йде (кінь чекає на узліссі).
##
## Рушій (Pet) створює один об'єкт механіки на кожного улюбленця в setup. Типово улюбленець біжить до
## свого місця біля героя (home), а якщо механіка каже fetches(), то ще й до здобичі поруч. Хто їздить
## інакше (мажа на голоблях), пише хук move: тоді рушій сам улюбленця не веде. Як додати — docs/data.md.

const Loader := preload("res://scripts/mechanics/loader.gd")
const BASE_PATH := "res://scripts/mechanics/pet_mechanic.gd"

## Хуки, які рушій кличе лише тоді, коли механіка їх написала.
const MOVE := 1
const HOOKS := {"move": MOVE}

## Улюбленець, яким керує механіка (Pet).
var p
## Герой, за яким він ходить.
var player:
	get:
		return p.player
## Бій.
var combat:
	get:
		return p.combat


## Чи бігає до здобичі, що лежить поруч і яку герой зараз може взяти. Рушій питає раз, у setup.
func fetches() -> bool:
	return false


## Де стоїть біля героя. carted — у героя за спиною мажа: тоді тримаються збоку й нижче, щоб не лізти
## під голоблі. Типово — позаду героя.
func home(carted: bool) -> Vector2:
	return player.position - player.facing * (22.0 if carted else 46.0) + Vector2(0, 42 if carted else 22)


## Власний рух щокадру замість типового (мажа). Малювання рушій оновить сам.
func move(_delta: float) -> void:
	pass


# ---------- Завантаження ----------

## Скрипт механіки улюбленця за посиланням ("pet/pes"); null — нема файлу чи не та основа.
static func script_of(ref: String) -> Script:
	return Loader.script_of(ref, BASE_PATH)


static func hooks_of(s: Script) -> int:
	return Loader.hooks_of(s, BASE_PATH, HOOKS)


## Нова механіка для улюбленця. Без посилання — типова (ходить позаду героя); посилання нікуди не
## веде — теж типова, з гучною помилкою.
static func create(ref: String, pet):
	var s: Script = script_of(ref) if ref != "" else null
	if s == null:
		if ref != "":
			push_error("Механіка улюбленця «%s» не знайдена (%s)" % [ref, Loader.path_of(ref)])
		s = load(BASE_PATH)
	var m = s.new()
	m.p = pet
	return m
