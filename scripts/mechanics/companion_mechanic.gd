extends RefCounted
## Механіка найманця: як цей рід служби б'ється в загоні (джура рубає зблизька, стрілець стріляє,
## знахарка ще й лікує). Ім'я, ціна й сила лежать у data/companions.json, запис називає свій скрипт
## («mechanic»: "companion/dzhura"), а поведінка — код у scripts/mechanics/companion/<рід>.gd.
## Побратим б'ється механікою свого base.
##
## Рушій (Companion) створює один об'єкт механіки на кожного супутника в setup. Спільне — рух за
## героєм, вибір цілі, перезарядку й замах удару — робить рушій; механіка каже лише, де стати біля
## ворога, як ударити й що робити щокадру понад це. Хук tick рушій кличе лише тоді, коли механіка його
## написала. Як додати найманця — docs/data.md.

const Loader := preload("res://scripts/mechanics/loader.gd")
const BASE_PATH := "res://scripts/mechanics/companion_mechanic.gd"

## Хуки, які рушій кличе лише тоді, коли механіка їх написала.
const TICK := 1
const HOOKS := {"tick": TICK}

## Супутник, яким керує механіка (Companion).
var c
## Бій, у якому він б'ється.
var combat:
	get:
		return c.combat


## Де стати, коли ціль target поруч: to — від супутника до цілі, c.facing уже дивиться на неї.
## Типово — на відстані: не ближче, ніж 80% дальності свого удару.
func approach(target, to: Vector2) -> Vector2:
	return target.global_position - c.facing * minf(c.info["stats"]["range"] * 0.8, to.length())


## Удар по цілі в напрямку dir. Перезарядку (stats.cd) і замах рушій уже поставив.
func attack(_target, _dir: Vector2) -> void:
	pass


## Щокадру, поки супутник живий, після руху (лікування знахарки).
func tick(_delta: float) -> void:
	pass


# ---------- Завантаження ----------

## Скрипт механіки найманця за посиланням ("companion/dzhura"); null — нема файлу чи не та основа.
static func script_of(ref: String) -> Script:
	return Loader.script_of(ref, BASE_PATH)


static func hooks_of(s: Script) -> int:
	return Loader.hooks_of(s, BASE_PATH, HOOKS)


## Нова механіка для супутника. Без посилання — типова (стоїть на відстані й не б'є); посилання
## нікуди не веде — теж типова, з гучною помилкою.
static func create(ref: String, companion):
	var s: Script = script_of(ref) if ref != "" else null
	if s == null:
		if ref != "":
			push_error("Механіка найманця «%s» не знайдена (%s)" % [ref, Loader.path_of(ref)])
		s = load(BASE_PATH)
	var m = s.new()
	m.c = companion
	return m
