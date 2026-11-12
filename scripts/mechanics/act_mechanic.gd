extends "res://scripts/mechanics/hero_mechanic.gd"
## Шаблон дії вмінь за даними: що робить уміння, яке описано у вузлі data/skills.json записом «act»
## (удар довкола, стрибок, удар перед собою, снаряди, зона, підсилення, помічник). Посилання — сам
## «act.type»: шаблон "nova" — це scripts/mechanics/act/nova.gd, спільний для всіх умінь із цим шаблоном.
## Числа (шкода, радіус, тривалість…) лежать у записі «act», шаблон лише читає їх.
##
## Рушій (Player) тримає один об'єкт на шаблон у героя. Ціну наснаги й перезарядку списує рушій, якщо
## cast() повернув true. Новий шаблон — новий файл тут і нове значення в переліку «act.type» схеми
## (GameDB.ACT_SCHEMA). Як додати — docs/data.md.
##
## Спільні поля й типові значення: pct (множник шкоди зброї), radius, stun, status [стан, секунд], kb,
## color, sound, text. Число можна задати як [основа, приріст за ранг] (Classes.val).

const BASE_PATH := "res://scripts/mechanics/act_mechanic.gd"
const DIR := "act/"

## Шаблон ("nova").
var type := ""


## Дія вміння за даними. n — вузол уміння, A — його «act», r — ранг, m — множник шкоди
## (pct на цьому ранзі × сила вмінь героя), col — колір дії. true — спрацювало.
func cast(_n: Dictionary, _A: Dictionary, _r: int, _m: float, _col: Color) -> bool:
	return false


## Цифри картки на ранзі r: рядки з тих полів «act», що є у вміння. Шаблон, якому треба інакше, переписує
## card чи лише damage_label.
func card(A: Dictionary, r: int) -> Array:
	var out := []
	var d: float = p.damage
	var sp: float = p.skill_power
	if A.has("pct") and Classes.val(A["pct"], r) > 0.0:
		out.append([damage_label(), dmg_text(d * Classes.val(A["pct"], r) * sp)])
	if A.has("count"):
		out.append(["Снарядів", "%d" % int(Classes.val(A["count"], r))])
	if A.has("radius"):
		out.append(["Радіус", "%d" % int(Classes.val(A["radius"], r))])
	if A.has("stun"):
		out.append(["Приголомшення", "%s с" % sec_text(Classes.val(A["stun"], r))])
	if A.has("status"):
		out.append(["Стан", "%s на %s с" % [str(Status.INFO.get(str(A["status"][0]), {}).get("name", "")).to_lower(), sec_text(float(A["status"][1]))]])
	if A.has("dur"):
		out.append(["Тривалість", "%s с" % sec_text(Classes.val(A["dur"], r))])
	if A.has("heal"):
		out.append(["Лікування", "%s%% здоров'я" % sec_text(Classes.val(A["heal"], r))])
	if A.has("fx"):
		out.append(["Дія", Classes.fx_text(A["fx"], r)])
	return out


## Назва рядка шкоди на картці.
func damage_label() -> String:
	return "Шкода"


# ---------- Цеглини шаблонів ----------

## Удар по одному ворогу: шкода, відкидання, приголомшення, стан.
func strike(A: Dictionary, r: int, m: float, e, dir: Vector2) -> void:
	var kb: float = float(A.get("kb", 250.0))
	if m > 0.0:
		var rl := roll(m)
		hit(e, rl[0], dir * kb, rl[1])
	if e.dead:
		return
	if A.has("stun") and not e.is_boss:
		e.stun = maxf(e.stun, Classes.val(A["stun"], r))
	if A.has("status"):
		var st: String = str(A["status"][0])
		Status.apply(e, st, float(A["status"][1]), p.damage * maxf(m, 0.5) * 0.1 if st in ["bleed", "burn", "plague"] else 0.0)


## Удар по всіх у колі з центром center (з «pull» — стягує до центру).
func area(A: Dictionary, r: int, m: float, col: Color, center: Vector2) -> bool:
	var reach: float = Classes.val(A.get("radius", 200.0), r)
	for e in foes():
		var to: Vector2 = e.global_position - center
		if to.length() <= reach + float(e.radius):
			strike(A, r, m, e, (-to.normalized() if A.get("pull", false) else to.normalized()))
	if center.distance_to(p.global_position) < 1.0:
		p.swing_time = 0.35
		p.swing_duration = 0.35
		p.swing_full = true
		p.swing_reach = reach
	combat.shake(float(A.get("shake", 8.0)))
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "boom", 0.05, -2.0)
	combat.fx.ring(center + Vector2(0, 16), col, 30, reach * 2.0, 8, 0.4)
	combat.fx.burst(center + Vector2(0, 16), col, 20, 240, 7, 0.5)
	return true


# ---------- Завантаження ----------

## Скрипт шаблону ("nova"); null — нема файлу чи не та основа.
static func script_of(t: String) -> Script:
	return Loader.script_of(DIR + t, BASE_PATH)


## Новий об'єкт шаблону t для героя player (null — нема такого шаблону, з гучною помилкою).
static func create(t: String, player):
	var s: Script = script_of(t)
	if s == null:
		push_error("Шаблон дії «%s» не знайдений (%s)" % [t, Loader.path_of(DIR + t)])
		return null
	var m = s.new()
	m.p = player
	m.type = t
	m.bits = hooks_of(s, BASE_PATH)
	return m
