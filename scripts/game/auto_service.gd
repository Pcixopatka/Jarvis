extends RefCounted
## Автобій: у місцях, які герой уже проходив сам, бій можна довірити йому. Герой сам іде до нечисті,
## б'є, вживає вміння, ухиляється від замахів, п'є зілля й виходить крізь портал. Пальцем по лівій
## частині екрана керування можна будь-якої миті забрати назад.
## Доступний у звичайній місцевості чи печері, пройденій MIN_CLEARS разів (із Гетьманським універсалом
## досить одного). У надважких печерах, Глибинах, Башті, на босах дня й тижня та в особливих боях його нема.

const Data := preload("res://scripts/data/data.gd")
const Premium := preload("res://scripts/game/premium_service.gd")

const MIN_CLEARS := 3
const POTION_AT := 0.4  # нижче цієї частки здоров'я герой п'є зілля
const MANA_AT := 0.2
const AID_AT := 0.6  # «Перша допомога» лише коли здоров'я нижче


## Чи буває автобій у цьому бою взагалі (тоді показуємо кнопку).
static func applies(combat, loc_id: String) -> bool:
	if not Data.LOCATIONS.has(loc_id) or combat.loc.has("hunt"):
		return false
	var L: Dictionary = Data.LOCATIONS[loc_id]
	return L["type"] in ["field", "dungeon"] and not L.get("endless", false) and not L.has("peril")


static func need_clears(world) -> int:
	return 1 if Premium.active(world) else MIN_CLEARS


## Чому автобій зараз недоступний ("" — доступний).
static func block_reason(world, combat, loc_id: String) -> String:
	if not applies(combat, loc_id):
		return "тут б'ються власноруч"
	var times: int = int(world.cleared.get(loc_id, 0))
	var need := need_clears(world)
	if times < need:
		return "відкриється, коли пройдеш це місце сам %d %s (зараз %d)" % [need, "раз" if need == 1 else "рази", times]
	return ""


## Один крок автобою: куди йти й що тиснути. Викликається щокадру, поки бій іде.
static func drive(game) -> void:
	var p = game.player
	var c = game.combat
	var hud = game.hud
	if not p.alive:
		hud.auto_vector = Vector2.ZERO
		hud.btn_attack.held = false
		return
	var en = c.nearest_enemy(p.global_position, 5000.0)
	var dir := Vector2.ZERO
	if en != null:
		var to: Vector2 = en.global_position - p.global_position
		var keep: float = p.attack_range * 0.7
		if to.length() > keep:
			dir = to.normalized()
		elif str(p.weapon_type) in Data.RANGED_WEAPONS and to.length() < keep * 0.45:
			dir = -to.normalized()  # стрілець і волхв тримають відстань
	elif c.portal != null and is_instance_valid(c.portal) and (c.room_cleared or c.field_cleared):
		var tp: Vector2 = c.portal.global_position - p.global_position
		if tp.length() > 12.0:
			dir = tp.normalized()
	# Ухилення: ворог поруч замахується або герой стоїть у червоній зоні
	for e in c.enemies_now():
		if e.windup > 0.0 and e.windup < 0.2 and p.global_position.distance_to(e.global_position) < e.radius + 60.0:
			p.dodge()
	for t in c.effects.get_children():
		if t.has_method("contains") and t.contains(p.global_position):
			dir = (p.global_position - t.global_position).normalized()
			if t.duration - t._t < 0.35:
				p.dodge()
	hud.auto_vector = dir
	hud.btn_attack.held = en != null
	if p.hp < p.max_hp * POTION_AT:
		p.use_potion()
	if p.mana < p.max_mana * MANA_AT:
		p.use_mana_potion()
	if en != null:
		for id in p.active_skills():
			if id == "first_aid" and p.hp > p.max_hp * AID_AT:
				continue
			p.use_skill(id)


static func stop(game) -> void:
	game.hud.auto_vector = Vector2.ZERO
	game.hud.btn_attack.held = false
