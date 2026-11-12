extends RefCounted
## Довідник вмінь для картки. Живі цифри за рангом (stats) складає механіка вміння чи шаблону його дії —
## той самий файл, що й сама дія. Решта того, що картка знає про вміння, — у самому вузлі
## (data/skills.json): kind — панель ("attack" — праворуч біля удару, "buff" — знизу), scales — від чого
## росте сила, what — що робить, heals — чи лікує героя.

const Classes := preload("res://scripts/data/classes.gd")
const SKILL_BASE := "res://scripts/mechanics/skill_mechanic.gd"
const ACT_BASE := "res://scripts/mechanics/act_mechanic.gd"


## Панель умінь: "attack" чи "buff". Вузол без «kind» (не активне) — до атак, а вміння за даними без
## нього — за шаблоном дії (підсилення й помічник — знизу).
static func kind(id: String) -> String:
	var n: Dictionary = Classes.find_node(id)
	if n.has("kind"):
		return n["kind"]
	return "buff" if str(Classes.act(id).get("type", "")) in ["buff", "summon"] else "attack"


## Чи вертає вміння здоров'я героєві (поле «heals» вузла; у вміння за даними воно мусить збігатися з
## дією: "heal" — одразу, загоєння "regen_pct" — за час; перевіряє GameDB).
static func heals(id: String) -> bool:
	return bool(Classes.find_node(id).get("heals", false))


## Що робить уміння (для картки й довідника); fallback — коли вузол цього не каже.
static func what(id: String, fallback: String = "") -> String:
	return str(Classes.find_node(id).get("what", fallback))


## Від чого росте сила вміння; fallback — коли вузол цього не каже.
static func scales(id: String, fallback: String = "") -> String:
	return str(Classes.find_node(id).get("scales", fallback))


## Таблиця цифр для рангу r (r може бути 0 — «ще не вивчено», тоді показуємо ранг 1).
## p — герой (щоб перевести множники в шкоду/здоров'я). Повертає [["назва", "значення"], ...].
## Цифри складає механіка вміння (card у scripts/mechanics/skill/<id>.gd) чи шаблону його дії
## (scripts/mechanics/act/<тип>.gd): там же, де й формула дії, тож вони не розходяться.
static func stats(id: String, r: int, p) -> Array:
	r = maxi(1, r)
	var n: Dictionary = Classes.find_node(id)
	var ref := str(n.get("mechanic", ""))
	if ref != "":
		var m = load(SKILL_BASE).create(ref, id, p)
		return m.card(r) if m != null else []
	var A: Dictionary = n.get("act", {})
	if A.is_empty():
		return []
	var am = load(ACT_BASE).create(str(A.get("type", "")), p)
	return am.card(A, r) if am != null else []
