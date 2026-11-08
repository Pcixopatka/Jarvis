class_name Player
extends Node2D
## Козак — головний герой. Рух, бій, характеристики, вміння і перки.

signal died
signal leveled_up(level: int)

const Data := preload("res://scripts/data/data.gd")

var combat: Combat

# --- Прогрес ---
var level := 1
var xp := 0
var xp_next := Data.xp_for_level(1)
var stats := {"str": Data.STAT_BASE, "agi": Data.STAT_BASE, "vit": Data.STAT_BASE, "spi": Data.STAT_BASE}
var skills := {"whirl": 1}  # id -> ранг
var perks := {}  # id -> ранг
var stat_points := 0
var skill_points := 0
var perk_points := 0

# --- Спорядження ---
var gold := 0
var potions := Data.POTION_START
var potion_timer := 0.0
var inventory := []  # речі в торбі
var equipment := {}  # слот -> річ
var next_uid := 1
var _eq := {}  # сумарні бонуси вдягнених речей
var weapon := {"dmg": 1.0, "cd": 1.0, "range": 1.0, "arc": 1.0, "kb": 1.0}
var weapon_type := "sabre"
var gold_mult := 1.0

# --- Обчислені показники (див. recalc) ---
var radius := 22.0
var max_hp := 100.0
var hp := 100.0
var speed := 260.0
var damage := 20.0
var crit_chance := 0.05
var crit_mult := 2.0
var attack_cooldown := 0.42
var attack_range := 95.0
var attack_arc := deg_to_rad(130.0)
var dodge_cooldown := 1.2
var pickup_radius := 120.0
var armor := 0.0
var regen := 0.0
var lifesteal := 0.0
var thorns := 0.0
var xp_mult := 1.0
var skill_cd_mult := 1.0
var skill_power := 1.0
var varenyk_bonus := 0

# --- Стан ---
var facing := Vector2.RIGHT
var attack_held := false
var attack_timer := 0.0
var dodge_timer := 0.0
var skill_timers := {"whirl": 0.0, "lightning": 0.0, "musket": 0.0}
var dodge_time_left := 0.0
var dodge_dir := Vector2.RIGHT
var dodge_hits := []
var invuln := 0.0
var swing_time := 0.0
var swing_duration := 0.18
var swing_full := false
var storm_timer := -1.0
var hurt_flash := 0.0
var walk_phase := 0.0
var moving := false
var alive := true
var unbreak_ready := true


func _ready() -> void:
	if equipment.is_empty() and inventory.is_empty():
		var starter := Data.gen_item(1, 0, "weapon", "sabre")
		starter["name"] = "Стара шабля"
		equip_new(starter)
	recalc()
	hp = max_hp


# ================= Спорядження =================

func assign_uid(item: Dictionary) -> Dictionary:
	item["uid"] = next_uid
	next_uid += 1
	return item


func equip_new(item: Dictionary) -> void:
	assign_uid(item)
	equipment[item["slot"]] = item


func find_item(uid: int) -> Dictionary:
	for it in inventory:
		if it["uid"] == uid:
			return it
	for slot in equipment:
		if equipment[slot]["uid"] == uid:
			return equipment[slot]
	return {}


func is_equipped(uid: int) -> bool:
	for slot in equipment:
		if equipment[slot]["uid"] == uid:
			return true
	return false


func bag_full() -> bool:
	return inventory.size() >= Data.INVENTORY_SIZE


## Додає річ у торбу. Повертає false, якщо місця немає.
func add_item(item: Dictionary) -> bool:
	if not item.has("uid"):
		assign_uid(item)
	if bag_full():
		return false
	inventory.append(item)
	return true


func equip(uid: int) -> bool:
	for i in inventory.size():
		var it: Dictionary = inventory[i]
		if it["uid"] == uid:
			inventory.remove_at(i)
			var slot: String = it["slot"]
			if equipment.has(slot):
				inventory.append(equipment[slot])
			equipment[slot] = it
			recalc()
			return true
	return false


func unequip(uid: int) -> bool:
	if bag_full():
		return false
	for slot in equipment:
		if equipment[slot]["uid"] == uid:
			inventory.append(equipment[slot])
			equipment.erase(slot)
			recalc()
			return true
	return false


func remove_from_bag(uid: int) -> Dictionary:
	for i in inventory.size():
		if inventory[i]["uid"] == uid:
			var it: Dictionary = inventory[i]
			inventory.remove_at(i)
			return it
	return {}


func add_gold(v: int) -> void:
	gold += maxi(v, roundi(v * gold_mult))


## Заточка: повертає "ok", "fail", "down", "nogold" або "max".
func sharpen(uid: int) -> String:
	var it := find_item(uid)
	if it.is_empty():
		return "fail"
	if it["up"] >= Data.MAX_UPGRADE:
		return "max"
	var cost := Data.sharpen_cost(it)
	if gold < cost:
		return "nogold"
	gold -= cost
	it["spent"] += cost
	var res := "fail"
	if randf() < Data.sharpen_chance(it):
		it["up"] += 1
		res = "ok"
	elif it["up"] >= Data.SHARPEN_RISK_FROM:
		it["up"] -= 1
		res = "down"
	recalc()
	return res


func _calc_equipment() -> void:
	_eq = {}
	for slot in equipment:
		var st := Data.item_stats(equipment[slot])
		for id in st:
			_eq[id] = _eq.get(id, 0.0) + st[id]
	weapon_type = equipment["weapon"]["type"] if equipment.has("weapon") else "sabre"
	weapon = Data.WEAPON_TYPES[weapon_type]


func eq(id: String) -> float:
	return _eq.get(id, 0.0)


# ================= Збереження =================

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "xp_next": xp_next, "stats": stats, "skills": skills, "perks": perks,
		"stat_points": stat_points, "skill_points": skill_points, "perk_points": perk_points,
		"gold": gold, "inventory": inventory, "equipment": equipment, "next_uid": next_uid, "potions": potions}


func from_dict(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	recalc()
	hp = max_hp


func revive() -> void:
	alive = true
	hp = max_hp
	invuln = 1.0
	hurt_flash = 0.0
	dodge_time_left = 0.0
	queue_redraw()


# ================= Прогресія =================

## Чи козак зараз на арені (ефекти й звуки бою мають сенс лише там).
func _in_combat() -> bool:
	return combat != null and combat.active and is_inside_tree()


func sk(id: String) -> int:
	return skills.get(id, 0)


func pk(id: String) -> int:
	return perks.get(id, 0)


## Значення характеристики з урахуванням перків і спорядження.
func stat(id: String) -> int:
	return stats[id] + (2 if pk("sich") > 0 else 0) + int(eq(id))


func _bonus(id: String) -> int:
	return stat(id) - Data.STAT_BASE


func recalc() -> void:
	var old_max := max_hp
	_calc_equipment()
	var s_str := _bonus("str")
	var s_agi := _bonus("agi")
	var s_vit := _bonus("vit")
	var s_spi := _bonus("spi")

	damage = (20.0 + eq("flat_dmg")) * weapon["dmg"] * (1.0 + 0.06 * s_str + 0.08 * pk("sharp") + eq("dmg_pct") / 100.0)
	attack_range = 95.0 * weapon["range"] * (1.0 + 0.08 * pk("reach"))
	attack_arc = deg_to_rad((130.0 + 20.0 * pk("cleave")) * weapon["arc"])
	attack_cooldown = 0.42 * weapon["cd"] / (1.0 + 0.04 * s_agi + 0.06 * pk("fury") + eq("aspd") / 100.0)
	crit_chance = minf(0.8, 0.05 + 0.015 * s_agi + 0.05 * pk("luck") + eq("crit") / 100.0)
	crit_mult = 3.0 if pk("deadly") > 0 else 2.0
	lifesteal = 0.02 * pk("thirst") + eq("lifesteal") / 100.0

	max_hp = 100.0 + 12.0 * s_vit + 15.0 * pk("tough") + eq("hp")
	armor = clampf(0.01 * s_vit + 0.05 * pk("ward") + eq("armor") / 100.0, 0.0, 0.75)
	regen = 0.6 * pk("regen") + eq("regen")
	dodge_cooldown = 1.2 * (1.0 - 0.12 * pk("roll"))
	thorns = 0.25 * pk("thorns")
	varenyk_bonus = pk("varenyk")

	speed = 260.0 * (1.0 + 0.015 * s_agi + 0.05 * pk("boots") + eq("speed") / 100.0)
	pickup_radius = 120.0 * (1.0 + 0.25 * pk("purse") + eq("pickup") / 100.0)
	xp_mult = 1.0 + 0.1 * pk("kobzar") + eq("xp") / 100.0
	gold_mult = 1.0 + eq("gold") / 100.0
	skill_cd_mult = maxf(0.3, (1.0 - 0.06 * pk("focus") - eq("skill_cd") / 100.0) / (1.0 + 0.04 * s_spi))
	skill_power = 1.0 + 0.05 * s_spi + 0.1 * pk("spirit") + eq("skill_power") / 100.0

	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)


func unspent_points() -> int:
	return stat_points + skill_points + perk_points


func add_stat(id: String) -> bool:
	if stat_points <= 0:
		return false
	stats[id] += 1
	stat_points -= 1
	recalc()
	return true


func skill_req_met(node: Dictionary) -> bool:
	for r in node["req"]:
		if sk(r) < node["req"][r]:
			return false
	return true


func can_learn_skill(node: Dictionary) -> bool:
	return skill_points > 0 and sk(node["id"]) < node["max"] and skill_req_met(node)


func learn_skill(id: String) -> bool:
	var node := Data.find_skill(id)
	if node.is_empty() or not can_learn_skill(node):
		return false
	skills[id] = sk(id) + 1
	skill_points -= 1
	recalc()
	return true


func branch_perk_points(bi: int) -> int:
	var total := 0
	for tier in Data.PERK_BRANCHES[bi]["tiers"]:
		for p in tier:
			total += pk(p["id"])
	return total


func perk_tier_open(bi: int, ti: int) -> bool:
	return branch_perk_points(bi) >= ti * Data.PERK_TIER_STEP


func can_learn_perk(id: String) -> bool:
	var f := Data.find_perk(id)
	if f[0] < 0:
		return false
	return perk_points > 0 and pk(id) < f[2]["max"] and perk_tier_open(f[0], f[1])


func learn_perk(id: String) -> bool:
	if not can_learn_perk(id):
		return false
	perks[id] = pk(id) + 1
	perk_points -= 1
	recalc()
	return true


func add_xp(value: int) -> void:
	xp += maxi(value, roundi(value * xp_mult))
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = Data.xp_for_level(level)
		stat_points += Data.STAT_POINTS_PER_LEVEL
		skill_points += Data.SKILL_POINTS_PER_LEVEL
		perk_points += Data.PERK_POINTS_PER_LEVEL
		heal(max_hp * 0.25)
		if _in_combat():
			Audio.play("levelup", 0.0)
			combat.fx.ring(global_position, Color(1.0, 0.85, 0.3), 32, 420, 6, 0.6)
		leveled_up.emit(level)
		Events.level_up.emit(level)


# ================= Цикл =================

func _process(delta: float) -> void:
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	potion_timer = maxf(0.0, potion_timer - delta)
	for id in skill_timers:
		skill_timers[id] = maxf(0.0, skill_timers[id] - delta)
	invuln = maxf(0.0, invuln - delta)
	swing_time = maxf(0.0, swing_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)

	if storm_timer >= 0.0:
		storm_timer -= delta
		if storm_timer < 0.0:
			_whirl_hit(0.7, 480.0)

	var input_vec: Vector2 = combat.get_move_input()
	moving = false
	if dodge_time_left > 0.0:
		dodge_time_left -= delta
		position += dodge_dir * speed * 3.2 * delta
		if pk("dash_strike") > 0:
			_dash_strike()
	else:
		position += input_vec * speed * delta
		if input_vec.length() > 0.1:
			moving = true
			if swing_time <= 0.0:
				facing = input_vec.normalized()
			walk_phase += delta * 14.0

	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)

	if attack_held and attack_timer <= 0.0:
		attack()
	queue_redraw()


# ================= Бій =================

func _roll(mult: float) -> Array:
	var crit := randf() < crit_chance
	var dmg := damage * mult * (crit_mult if crit else 1.0) * randf_range(0.9, 1.1)
	return [dmg, crit]


## Удар по ворогу з урахуванням вампіризму.
func hit(e, dmg: float, kb: Vector2, crit: bool) -> void:
	if e.dead:
		return
	e.take_damage(dmg, kb, crit)
	if lifesteal > 0.0:
		heal(dmg * lifesteal, false)


func _alive_enemies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			out.append(e)
	return out


func attack() -> void:
	if not alive or attack_timer > 0.0 or dodge_time_left > 0.0:
		return
	attack_timer = attack_cooldown
	# Автонаведення — на телефоні цілитися пальцем незручно.
	var target: Node2D = combat.nearest_enemy(global_position, attack_range * 1.8)
	if target:
		facing = (target.global_position - global_position).normalized()
	swing_time = 0.18
	swing_duration = 0.18
	swing_full = false
	Audio.play("swing", 0.15, -4.0)
	var hits := 0
	var crit_any := false
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		var dist := to.length()
		if dist > attack_range + e.radius:
			continue
		if dist < 1.0 or absf(facing.angle_to(to)) <= attack_arc * 0.5:
			var r := _roll(1.0)
			hit(e, r[0], to.normalized() * 280.0 * weapon["kb"], r[1])
			hits += 1
			crit_any = crit_any or r[1]
	if hits > 0:
		Audio.play("crit" if crit_any else "hit", 0.12)
		combat.shake(2.5 * weapon["kb"])
		if crit_any:
			combat.hitstop(0.05)


## Ковтнути зілля здоров'я. Повертає true, якщо вдалося.
func use_potion() -> bool:
	if not alive or potions <= 0 or potion_timer > 0.0 or hp >= max_hp:
		return false
	potions -= 1
	potion_timer = Data.POTION_CD
	heal(max_hp * Data.POTION_HEAL)
	return true


func add_potion() -> bool:
	if potions >= Data.POTION_MAX:
		return false
	potions += 1
	return true


func dodge() -> void:
	if not alive or dodge_timer > 0.0:
		return
	dodge_timer = dodge_cooldown
	var input_vec: Vector2 = combat.get_move_input()
	dodge_dir = input_vec.normalized() if input_vec.length() > 0.1 else facing
	dodge_time_left = 0.18
	dodge_hits.clear()
	invuln = maxf(invuln, 0.32)
	Audio.play("dodge", 0.1)
	combat.fx.burst(global_position + Vector2(0, 16), Color(0.75, 0.7, 0.55, 0.7), 10, 160, 7, 0.45, 0, (-dodge_dir).angle(), 1.4)


func _dash_strike() -> void:
	for e in _alive_enemies():
		if e.get_instance_id() in dodge_hits:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() < radius + e.radius + 14.0:
			dodge_hits.append(e.get_instance_id())
			var r := _roll(0.8)
			hit(e, r[0], to.normalized() * 200.0, r[1])


# ================= Активні вміння =================

func skill_cooldown(id: String) -> float:
	match id:
		"whirl":
			return 8.0 * (1.0 - 0.1 * sk("whirl_cd")) * skill_cd_mult
		"lightning":
			return 6.0 * skill_cd_mult
		"musket":
			return 4.0 * (1.0 - 0.12 * sk("reload")) * skill_cd_mult
	return 1.0


func skill_ready_ratio(id: String) -> float:
	return skill_timers.get(id, 0.0) / skill_cooldown(id)


func use_skill(id: String) -> void:
	if not alive or sk(id) <= 0 or skill_timers.get(id, 0.0) > 0.0:
		return
	var used := false
	match id:
		"whirl":
			used = _whirl()
		"lightning":
			used = _lightning()
		"musket":
			used = _musket()
	if used:
		skill_timers[id] = skill_cooldown(id)


func whirl_reach() -> float:
	return attack_range * 1.8 * (1.0 + 0.08 * (sk("whirl") - 1))


func _whirl() -> bool:
	var storm := sk("storm") > 0
	swing_time = 0.4
	swing_duration = 0.4
	swing_full = true
	invuln = maxf(invuln, 0.4)
	if storm:
		# Притягуємо нечисть до козака, а за мить — другий удар.
		for e in _alive_enemies():
			var to: Vector2 = e.global_position - global_position
			if to.length() <= whirl_reach() * 1.6 + e.radius:
				e.knockback = -to.normalized() * minf(to.length() * 5.0, 900.0)
		storm_timer = 0.3
		_whirl_hit(1.0, 0.0)
	else:
		_whirl_hit(1.0, 480.0)
	combat.float_text(global_position + Vector2(0, -60), "Буревій!" if storm else "Вихор!", Color(0.6, 0.85, 1.0))
	Audio.play("whirl")
	combat.fx.ring(global_position, Color(0.7, 0.9, 1.0, 0.8), 28, whirl_reach() * 2.2, 5, 0.35)
	return true


func _whirl_hit(mult: float, kb: float) -> void:
	var m := 1.8 * (1.0 + 0.2 * (sk("whirl") - 1)) * skill_power * mult
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() <= whirl_reach() + e.radius:
			var r := _roll(m)
			hit(e, r[0], to.normalized() * kb, r[1])
	swing_time = 0.4
	swing_duration = 0.4
	swing_full = true
	combat.shake(9.0)


func _lightning() -> bool:
	var targets := _alive_enemies().filter(func(e): return global_position.distance_to(e.global_position) <= 480.0 + e.radius)
	if targets.is_empty():
		return false
	targets.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var count := 2 + sk("lightning") + 2 * sk("chain")
	var m := (1.2 + 0.25 * sk("lightning")) * skill_power
	var pts := PackedVector2Array([global_position + Vector2(0, -30)])
	for i in mini(count, targets.size()):
		var e = targets[i]
		pts.append(e.global_position)
		var r := _roll(m)
		hit(e, r[0], Vector2.ZERO, r[1])
		if sk("wrath") > 0 and not e.dead:
			e.slow_timer = 2.0
	combat.spawn_bolt(pts)
	combat.shake(5.0)
	Audio.play("lightning")
	for i in range(1, pts.size()):
		combat.fx.burst(pts[i], Color(0.75, 0.9, 1.0), 8, 260, 3.5, 0.3)
	return true


func _musket() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 750.0)
	var dir := facing
	if target:
		dir = (target.global_position - global_position).normalized()
		facing = dir
	var m := (2.2 + 0.4 * (sk("musket") - 1)) * skill_power
	var angles := [-0.3, -0.15, 0.0, 0.15, 0.3] if sk("buckshot") > 0 else [0.0]
	for a in angles:
		var r := _roll(m * (0.6 if angles.size() > 1 else 1.0))
		combat.spawn_bullet(global_position + Vector2(0, -10) + dir * 30.0, dir.rotated(a), r[0], r[1])
	combat.shake(4.0)
	Audio.play("musket")
	combat.fx.burst(global_position + Vector2(0, -10) + dir * 40.0, Color(0.85, 0.85, 0.8, 0.6), 14, 140, 9, 0.8, -40, dir.angle(), 0.9)
	combat.fx.burst(global_position + Vector2(0, -10) + dir * 40.0, Color(1.0, 0.8, 0.3), 6, 300, 4, 0.15, 0, dir.angle(), 0.6)
	return true


# ================= Отримання шкоди =================

func take_damage(amount: float, source = null) -> void:
	if not alive or invuln > 0.0:
		return
	if source != null and thorns > 0.0 and not source.dead:
		source.take_damage(amount * thorns, Vector2.ZERO, false)
	amount *= (1.0 - armor)
	hp -= amount
	hurt_flash = 0.2
	invuln = 0.35
	combat.shake(7.0)
	Audio.play("hurt", 0.1)
	Events.player_hurt.emit()
	combat.float_text(global_position + Vector2(0, -50), str(int(amount)), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		if pk("unbreak") > 0 and unbreak_ready:
			unbreak_ready = false
			hp = 1.0
			invuln = 1.5
			Events.banner.emit("Незламний!", Color(1.0, 0.85, 0.3))
			return
		hp = 0.0
		alive = false
		queue_redraw()
		died.emit()
		Events.player_died.emit()


func heal(amount: float, show: bool = true) -> void:
	var before := hp
	hp = minf(max_hp, hp + amount)
	var gained := int(hp - before)
	if show and gained > 0 and _in_combat():
		combat.float_text(global_position + Vector2(0, -50), "+%d" % gained, Color(0.4, 1.0, 0.45))
		Audio.play("heal", 0.05, -4.0)
		combat.fx.burst(global_position + Vector2(0, -10), Color(0.5, 1.0, 0.5), 10, 90, 4, 0.7, -80)


# ================= Малювання козака (без зовнішніх спрайтів) =================

func _draw() -> void:
	var tint := Color.WHITE
	if not alive:
		tint = Color(0.5, 0.5, 0.5, 0.8)
	elif hurt_flash > 0.0:
		tint = Color(1.0, 0.45, 0.45)
	elif dodge_time_left > 0.0:
		tint = Color(1, 1, 1, 0.55)

	# Тінь
	draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		draw_set_transform(Vector2(0, 8), PI / 2.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	var bob := sin(walk_phase) * 3.0 if moving else 0.0

	# Ноги: широкі сині шаровари та червоні чоботи
	var leg_l := Vector2(-7, 10 + bob)
	var leg_r := Vector2(7, 10 - bob)
	draw_rect(Rect2(leg_l - Vector2(6, 2), Vector2(11, 10)), Color(0.18, 0.3, 0.7) * tint)
	draw_rect(Rect2(leg_r - Vector2(5, 2), Vector2(11, 10)), Color(0.18, 0.3, 0.7) * tint)
	draw_rect(Rect2(leg_l + Vector2(-5, 7), Vector2(10, 6)), Color(0.6, 0.1, 0.1) * tint)
	draw_rect(Rect2(leg_r + Vector2(-4, 7), Vector2(10, 6)), Color(0.6, 0.1, 0.1) * tint)

	# Тулуб: червоний жупан і жовтий пояс
	draw_circle(Vector2(0, -2), 16.0, Color(0.78, 0.14, 0.14) * tint)
	draw_rect(Rect2(-15, 3, 30, 5), Color(0.95, 0.75, 0.15) * tint)

	# Голова, оселедець, вуса
	var head := Vector2(0, -26)
	draw_circle(head, 11.0, Color(0.96, 0.8, 0.65) * tint)
	var chub := PackedVector2Array([
		head + Vector2(0, -11), head + Vector2(-side * 6, -17),
		head + Vector2(-side * 13, -14), head + Vector2(-side * 15, -6),
	])
	draw_polyline(chub, Color(0.25, 0.15, 0.08) * tint, 4.0, true)
	draw_circle(head + Vector2(side * 4, -2), 1.8, Color(0.1, 0.1, 0.1) * tint)
	draw_line(head + Vector2(side * 2, 4), head + Vector2(side * 10, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
	draw_line(head + Vector2(side * 2, 4), head + Vector2(-side * 5, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
	# Шапка (якщо вдягнена): хутряна кучма з кольоровим шликом за рідкістю
	if equipment.has("head"):
		var hc: Color = Data.RARITY_COLORS[equipment["head"]["rarity"]]
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(side * 6, -10), head + Vector2(-side * 4, -24), head + Vector2(-side * 14, -18), head + Vector2(-side * 8, -9)
		]), hc.darkened(0.25) * tint)
		draw_rect(Rect2(head + Vector2(-12, -14), Vector2(24, 8)), Color(0.25, 0.18, 0.12) * tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		return

	# Зброя
	var blade_angle := facing.angle()
	if swing_time > 0.0:
		var t := 1.0 - swing_time / swing_duration
		if swing_full:
			blade_angle += t * TAU * 1.5
		else:
			blade_angle += lerpf(-attack_arc * 0.5, attack_arc * 0.5, t)
	var hand := Vector2(side * 12, -4)
	var dir := Vector2.from_angle(blade_angle)
	var rarity: int = equipment["weapon"]["rarity"] if equipment.has("weapon") else 0
	var metal: Color = [Color(0.86, 0.9, 0.95), Color(0.85, 0.95, 0.85), Color(0.75, 0.88, 1.0), Color(1.0, 0.85, 0.45)][rarity]
	match weapon_type:
		"mace":
			var head_pos := hand + dir * 36.0
			draw_line(hand - dir * 6.0, head_pos, Color(0.45, 0.28, 0.1), 5.0)
			for k in 6:
				var a := blade_angle + k * TAU / 6.0
				draw_line(head_pos, head_pos + Vector2.from_angle(a) * 11.0, metal.darkened(0.2), 4.0)
			draw_circle(head_pos, 8.0, metal)
		"pike":
			var tip := hand + dir * 70.0
			draw_line(hand - dir * 22.0, tip - dir * 12.0, Color(0.5, 0.33, 0.15), 4.0)
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 16.0 + dir.orthogonal() * 6.0, tip - dir * 16.0 - dir.orthogonal() * 6.0]), metal)
		_:
			var tip := hand + dir * 44.0
			var curve := hand + dir * 26.0 + dir.orthogonal() * 5.0
			draw_polyline(PackedVector2Array([hand, curve, tip]), metal, 4.0, true)
			draw_line(hand - dir * 8.0, hand, Color(0.45, 0.28, 0.1), 5.0)
			draw_line(hand + dir.orthogonal() * 6.0, hand - dir.orthogonal() * 6.0, Color(0.85, 0.7, 0.2), 3.0)
	if rarity == 3:
		draw_circle(hand + dir * 30.0, 14.0, Color(1.0, 0.7, 0.2, 0.18))

	# Слід удару
	if swing_time > 0.0:
		var alpha := swing_time / swing_duration
		if swing_full:
			var rr := whirl_reach()
			draw_arc(Vector2.ZERO, rr * 0.85, 0.0, TAU, 64, Color(0.7, 0.9, 1.0, 0.55 * alpha), 22.0)
			draw_arc(Vector2.ZERO, rr * 0.6, 0.0, TAU, 64, Color(1, 1, 1, 0.4 * alpha), 8.0)
		else:
			var a0 := facing.angle() - attack_arc * 0.5
			draw_arc(Vector2.ZERO, attack_range * 0.75, a0, a0 + attack_arc, 24, Color(1, 1, 1, 0.6 * alpha), 16.0)

	# Індикатор готовності Вихору
	if skill_timers["whirl"] <= 0.0:
		draw_arc(Vector2(0, 20), 26.0, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.5), 2.0)
