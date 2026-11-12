extends "res://scripts/mechanics/hero_mechanic.gd"
## Механіка сили золотої речі: що робить у бою Громовий удар, Звитяга, Покрова… Назва, текст і перелік
## параметрів лежать у data/powers.json, числа — у самій речі (data/golden.json, «params»), запис сили
## називає свій скрипт («mechanic»: "power/hrim"), а дія — код у scripts/mechanics/power/<id>.gd.
##
## Рушій (Player) створює об'єкт сили, коли герой уперше вдягає річ із нею, і більше його не прибирає:
## таймери сили йдуть далі, навіть коли річ знято (так було й раніше). Тому хук сили, якому потрібна
## вдягнена річ, сам питає worn(). Дві однакові сили не складаються — діє сильніша (Player._calc_equipment).
## Сили відгукуються на події бою хуками основи (hero_mechanic.gd), черга — 50 (раніше за вміння).

const BASE_PATH := "res://scripts/mechanics/power_mechanic.gd"

## Id сили (powers.json).
var id := ""
## Параметри вдягненої речі з цією силою (порожньо — не вдягнена).
var P: Dictionary:
	get:
		return p.u_pow.get(id, {})


func order() -> int:
	return 50


## Чи вдягнена зараз річ із цією силою.
func worn() -> bool:
	return p.u_pow.has(id)


# ---------- Завантаження ----------

## Скрипт механіки сили за посиланням ("power/hrim"); null — нема файлу чи не та основа.
static func script_of(ref: String) -> Script:
	return Loader.script_of(ref, BASE_PATH)


## Новий об'єкт сили power_id для героя player (null — посилання нікуди не веде, з гучною помилкою).
static func create(ref: String, power_id: String, power_num: int, player):
	var s: Script = script_of(ref)
	if s == null:
		push_error("Механіка сили «%s» не знайдена (%s)" % [ref, Loader.path_of(ref)])
		return null
	var m = s.new()
	m.p = player
	m.id = power_id
	m.num = power_num
	m.bits = hooks_of(s, BASE_PATH)
	return m
