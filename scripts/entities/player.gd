class_name Player
extends Node2D
## Козак — головний герой. Рух, бій, характеристики, вміння і перки.

signal died
signal leveled_up(level: int)

const Data := preload("res://scripts/data/data.gd")
const Status := preload("res://scripts/game/status.gd")
const Classes := preload("res://scripts/data/classes.gd")
const SkillInfo := preload("res://scripts/data/skill_info.gd")
const ATTACK_SLOTS := 3  # кнопки атак праворуч (біля основного удару)
const BUFF_SLOTS := 5  # кнопки бафів знизу посередині

var combat: Combat

# --- Прогрес ---
var level := 1
var xp := 0
var xp_next := Data.xp_for_level(1)
var stats := {"str": Data.STAT_BASE, "agi": Data.STAT_BASE, "vit": Data.STAT_BASE, "spi": Data.STAT_BASE}
var skills := {"whirl": 1}  # id -> ранг
var perks := {}  # id -> ранг
var stat_points := 0
var skill_points := 0  # з рівнів майстерності
var perk_points := 0  # очки Загартування (за рівні героя)
var stat_gifts := {}  # характеристики, подаровані сюжетом (не скидаються Каменем забуття)
var skill_gifts := {}  # вміння, подаровані посвятою
var stones := {}  # камені долі: zabuttia, alatyr (див. StoneService)
var panel := {"attack": ["", "", ""], "buff": ["", "", "", "", ""]}  # що стоїть на кнопках бою
# --- Клас і майстерність (job level) ---
var job := "cossack"  # peasant / cossack / volkhv (нова гра починається селянином)
var job_level := 1
var job_xp := 0
# --- Наснага (мана) ---
var mana := 50.0
var max_mana := 50.0
var mana_regen := 2.0

# --- Спорядження ---
var gold := 0
var rank := ""  # почесне звання (hetman — після фіналу); клас — у job
var potions := Data.POTION_START
var potion_timer := 0.0
var resources := {"wood": 0, "iron": 0, "herbs": 0}  # для будівництва хутора
var trip_buffs := {}  # зілля, випите перед походом: "strength", "antiplague"
var bag_bonus := 0  # від складу на хуторі (не зберігається — рахується з будівель)
var potion_bonus := 0  # від зілляварні
var xp_boost := 1.0  # ×2 за рекламу (виставляє Game, поки діє)
var plague_immune := false
var plague_resist := 0.0  # частка шкоди від зарази, яку козак не отримує (наслідок вибору; не зберігається)
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
# --- Комбо, блок, парирування, заряд ---
const COMBO_WINDOW := 1.0  # скільки чекає серія між ударами
const COMBO_MULT := [1.0, 1.15, 1.8]  # третій удар серії — сильний і широкий
const PARRY_WINDOW := 0.25  # натиснув «Блок» за мить до удару — парирування
const BLOCK_MULT := 0.35  # частка шкоди, що проходить крізь блок
const CHARGE_MIN := 0.6  # з якого часу утримання блоку удар уже заряджений
const CHARGE_FULL := 1.4
var combo_step := 0
var combo_timer := 0.0
var block_held := false
var blocking := false
var block_time := 0.0
var block_cd := 0.0
var swing_reach := 0.0
var statuses := {}  # кровотеча, горіння, зараза, холод, слабкість (див. Status)  # радіус кругового сліду для зарядженого удару (0 — як у Вихору)
var storm_timer := -1.0
var hurt_flash := 0.0
var walk_phase := 0.0
var moving := false
var alive := true
var unbreak_ready := true
# --- Дії вмінь у часі ---
var cry_timer := 0.0  # Бойовий клич
var cry_bonus := 0.0
var ward_hp := 0.0  # Щит-оберіг: скільки шкоди ще поглине
var ward_timer := 0.0
var herb_timer := 0.0  # Цілюща трава: лікування в часі
var herb_rate := 0.0
var stina_timer := 0.0  # Козацька стіна (Запорожець): вороги б'ють лише тебе, шкода менша
var tin_timer := 0.0  # Тінь (Пластун): вороги не бачать, наступний удар — крит
var wolf_timer := 0.0  # Вовча подоба (Характерник)
var zamova_timer := 0.0  # Замовляння шаблі (Характерник)
var zahyst_timer := 0.0  # Оберіг загону (Знахар)
var zahyst_mult := 1.0
var cleanse_timer := 0.0  # Очищення (Знахар): стани не чіпляються
var burya_timer := 0.0  # Буря (Перунів жрець)
var _burya_tick := 0.0
var _chaining := false


func _ready() -> void:
	if equipment.is_empty() and inventory.is_empty():
		var mage := Classes.is_volkhv_line(job)
		var starter := Data.gen_item(1, 0, "weapon", "staff" if mage else "sabre")
		starter["name"] = "Старий посох" if mage else "Стара шабля"
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


func bag_size() -> int:
	return Data.INVENTORY_SIZE + bag_bonus


func bag_full() -> bool:
	return inventory.size() >= bag_size()


func potion_max() -> int:
	return Data.POTION_MAX + potion_bonus


## Додає річ у торбу. Повертає false, якщо місця немає.
func add_item(item: Dictionary) -> bool:
	if not item.has("uid"):
		assign_uid(item)
	if bag_full():
		return false
	inventory.append(item)
	return true


## Чи може цей клас користуватися річчю (зброя обмежена класом).
func can_use(item: Dictionary) -> bool:
	if item.get("slot", "") != "weapon":
		return true
	return item.get("type", "") in Classes.CLASSES[job]["weapons"]


func equip(uid: int) -> bool:
	for i in inventory.size():
		var it: Dictionary = inventory[i]
		if it["uid"] == uid:
			if not can_use(it):
				return false
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
## cost_mult/chance_bonus — бонуси кузні хутора; safe — безпечна заточка (рівень не падає).
func sharpen(uid: int, cost_mult: float = 1.0, chance_bonus: float = 0.0, safe: bool = false) -> String:
	var it := find_item(uid)
	if it.is_empty():
		return "fail"
	if it["up"] >= Data.MAX_UPGRADE:
		return "max"
	var cost := int(Data.sharpen_cost(it) * cost_mult)
	if gold < cost:
		return "nogold"
	gold -= cost
	it["spent"] += cost
	var res := "fail"
	if randf() < minf(1.0, Data.sharpen_chance(it) + chance_bonus):
		it["up"] += 1
		res = "ok"
	elif it["up"] >= Data.SHARPEN_RISK_FROM and not safe:
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
		"gold": gold, "inventory": inventory, "equipment": equipment, "next_uid": next_uid, "potions": potions,
		"resources": resources, "trip_buffs": trip_buffs, "rank": rank, "job": job, "job_level": job_level, "job_xp": job_xp,
		"stat_gifts": stat_gifts, "skill_gifts": skill_gifts, "stones": stones, "panel": panel}


func from_dict(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	recalc()
	hp = max_hp
	mana = max_mana


func revive() -> void:
	statuses.clear()
	mana = max_mana
	cry_timer = 0.0
	ward_hp = 0.0
	herb_timer = 0.0
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


## Пасивний бонус: з Загартування або з дерева класу (вузли з тими ж id).
func pk(id: String) -> int:
	return perks.get(id, 0) + skills.get(id, 0)


func class_info() -> Dictionary:
	return Classes.CLASSES[job]


func class_name_ua() -> String:
	return class_info()["name"]


func job_max() -> int:
	return int(class_info()["job_max"])


func job_next() -> int:
	return Classes.job_xp_for(int(class_info()["tier"]), job_level)


func is_mage() -> bool:
	return weapon_type == "staff"


## Чи можна вже змінити клас (досить майстерності й є куди рости).
func can_change_class() -> bool:
	var tier := int(class_info()["tier"])
	return not class_info()["next"].is_empty() and job_level >= int(Classes.JOB_CHANGE_AT.get(tier, 999))


## Зміна класу: майстерність з 1, вивчене лишається, невитрачені очки — теж.
func change_class(cls: String) -> bool:
	if not Classes.CLASSES.has(cls) or cls == job:
		return false
	job = cls
	job_level = 1
	job_xp = 0
	Data.weapon_pool = Classes.CLASSES[job]["weapons"]
	recalc()
	mana = max_mana
	return true


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

	# Волхв із посохом черпає силу з Характерництва, усі інші — із Сили
	var s_main := s_spi if weapon_type == "staff" else (s_agi if weapon_type == "pishchal" else s_str)
	damage = (20.0 + eq("flat_dmg")) * weapon["dmg"] * (1.0 + 0.06 * s_main + 0.08 * pk("sharp") + 0.08 * pk("porokh") + eq("dmg_pct") / 100.0)
	if weapon_type == "mace":
		damage *= 1.0 + 0.1 * pk("mace_master")
	if trip_buffs.has("strength"):
		damage *= 1.3
	if trip_buffs.has("inspired"):
		damage *= 1.15  # дума кобзаря біля вогнища
	plague_immune = trip_buffs.has("antiplague")
	attack_range = 95.0 * weapon["range"] * (1.0 + 0.08 * pk("reach"))
	if weapon_type == "staff":
		attack_range = 430.0  # іскри летять далеко
	elif weapon_type == "pishchal":
		attack_range = 480.0
	attack_arc = deg_to_rad((130.0 + 20.0 * pk("cleave")) * weapon["arc"])
	attack_cooldown = 0.42 * weapon["cd"] / (1.0 + 0.04 * s_agi + 0.06 * pk("fury") + eq("aspd") / 100.0)
	if weapon_type == "pishchal":
		attack_cooldown /= 1.0 + 0.1 * pk("shvydke")
	crit_chance = minf(0.8, 0.05 + 0.015 * s_agi + 0.05 * pk("luck") + 0.04 * pk("oko") + 0.05 * pk("vluchnist") + eq("crit") / 100.0)
	crit_mult = 3.0 if pk("deadly") > 0 else 2.0
	lifesteal = 0.02 * pk("thirst") + 0.03 * pk("wolf_blood") + eq("lifesteal") / 100.0

	max_hp = (100.0 + 12.0 * s_vit + 15.0 * pk("tough") + eq("hp")) * (1.0 + 0.06 * pk("hardy") + 0.08 * pk("zaporizka_vytryvalist")) * float(class_info().get("hp_mult", 1.0))
	damage *= float(class_info().get("dmg_mult", 1.0))
	armor = clampf(0.01 * s_vit + 0.05 * pk("ward") + 0.03 * pk("iron_skin") + eq("armor") / 100.0, 0.0, 0.75)
	regen = 0.6 * pk("regen") + 1.0 * pk("zhyve_slovo") + eq("regen")
	dodge_cooldown = 1.2 * (1.0 - 0.12 * pk("roll")) * (1.0 - 0.15 * pk("stryvok"))
	thorns = 0.25 * pk("thorns")
	varenyk_bonus = pk("varenyk")

	speed = 260.0 * (1.0 + 0.015 * s_agi + 0.05 * pk("boots") + eq("speed") / 100.0)
	pickup_radius = 120.0 * (1.0 + 0.25 * pk("purse") + eq("pickup") / 100.0)
	xp_mult = 1.0 + 0.1 * pk("kobzar") + eq("xp") / 100.0 + (0.15 if trip_buffs.has("inspired") else 0.0)
	gold_mult = 1.0 + eq("gold") / 100.0
	skill_cd_mult = maxf(0.3, (1.0 - 0.06 * pk("focus") - eq("skill_cd") / 100.0) / (1.0 + 0.04 * s_spi))
	skill_power = 1.0 + 0.05 * s_spi + 0.1 * pk("spirit") + eq("skill_power") / 100.0
	var ci := class_info()
	var old_mana := max_mana
	max_mana = (40.0 + 5.0 * s_spi) * float(ci["mana_mult"]) * (1.0 + 0.2 * pk("deep_well") + 0.1 * pk("steel_will"))
	mana_regen = (2.0 + 0.25 * s_spi) * float(ci["regen_mult"]) * (1.0 + 0.25 * pk("mana_flow"))
	if max_mana > old_mana:
		mana += max_mana - old_mana
	mana = minf(mana, max_mana)

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


func is_peasant() -> bool:
	return job == "peasant"


## Вчити можна лише вміння свого нинішнього класу.
func in_class_tree(id: String) -> bool:
	for b in Classes.TREES[job]:
		for n in b["nodes"]:
			if n["id"] == id:
				return true
	return false


func can_learn_skill(node: Dictionary) -> bool:
	return skill_points > 0 and in_class_tree(node["id"]) and sk(node["id"]) < node["max"] and skill_req_met(node)


func learn_skill(id: String) -> bool:
	var node := Classes.find_node(id, job)
	if node.is_empty() or not can_learn_skill(node):
		return false
	skills[id] = sk(id) + 1
	skill_points -= 1
	recalc()
	sync_panel()
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
	var gained := maxi(value, roundi(value * xp_mult * xp_boost))
	_add_job_xp(gained)
	if level >= Classes.BASE_LEVEL_MAX:
		return
	xp += gained
	while xp >= xp_next and level < Classes.BASE_LEVEL_MAX:
		xp -= xp_next
		level += 1
		xp_next = Data.xp_for_level(level)
		stat_points += Data.STAT_POINTS_PER_LEVEL
		if level % Classes.HARDEN_EVERY == 0:
			perk_points += Data.PERK_POINTS_PER_LEVEL
		heal(max_hp * 0.25)
		if _in_combat():
			Audio.play("levelup", 0.0)
			combat.fx.ring(global_position, Color(1.0, 0.85, 0.3), 32, 420, 6, 0.6)
		leveled_up.emit(level)
		Events.level_up.emit(level)


## Досвід майстерності: та сама здобич, окрема смужка. На вершині класу — стоїть.
func _add_job_xp(gained: int) -> void:
	if job_level >= job_max():
		job_xp = 0
		return
	job_xp += gained
	while job_level < job_max() and job_xp >= job_next():
		job_xp -= job_next()
		job_level += 1
		skill_points += Data.SKILL_POINTS_PER_LEVEL
		if _in_combat():
			Audio.play("levelup", 0.05, -4.0)
			combat.float_text(global_position + Vector2(0, -110), "Майстерність %d!" % job_level, Color(0.6, 0.85, 1.0))
		Events.job_level_up.emit(job_level)
	if job_level >= job_max():
		job_xp = 0


# ================= Цикл =================

func _process(delta: float) -> void:
	if not alive:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	mana = minf(max_mana, mana + mana_regen * delta)
	_tick_effects(delta)
	var dot := Status.tick(self, delta)
	if dot > 0.0:
		_take_dot(dot)
		if not alive:
			return
	block_cd = maxf(0.0, block_cd - delta)
	_update_block(delta)
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
		position += input_vec * speed * (0.45 if blocking else 1.0) * Status.speed_mult(self) * (1.2 if cry_timer > 0.0 else 1.0) * (1.4 if wolf_timer > 0.0 else 1.0) * delta
		if input_vec.length() > 0.1:
			moving = true
			if swing_time <= 0.0:
				facing = input_vec.normalized()
			walk_phase += delta * 14.0

	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)

	if attack_held and attack_timer <= 0.0 and not blocking:
		attack()
	queue_redraw()


## Блок: натиснув — щит догори (перша мить — парирування); тримаєш — заряджається удар;
## відпустив після CHARGE_MIN — заряджений удар.
func _update_block(delta: float) -> void:
	if block_held and not blocking and block_cd <= 0.0 and dodge_time_left <= 0.0:
		blocking = true
		block_time = 0.0
	elif blocking and block_held:
		block_time += delta
	elif blocking and not block_held:
		blocking = false
		block_cd = 0.25
		if block_time >= CHARGE_MIN:
			charged_strike(clampf((block_time - CHARGE_MIN) / (CHARGE_FULL - CHARGE_MIN), 0.0, 1.0))


func charge_ratio() -> float:
	if not blocking or block_time < CHARGE_MIN * 0.3:
		return 0.0
	return clampf(block_time / CHARGE_FULL, 0.0, 1.0)


## Заряджений удар: сила 0..1. Повний заряд б'є довкола і приголомшує нечисть.
func charged_strike(power: float) -> void:
	if not alive:
		return
	if weapon_type == "staff":
		_charged_spell(power)
		return
	if weapon_type == "pishchal":
		_prytsil_shot((2.0 + 2.5 * power) * skill_power, power >= 0.99)
		Events.charged_hit.emit()
		combo_step = 0
		attack_timer = attack_cooldown
		return
	var mult := 1.6 + 1.6 * power
	var reach := attack_range * (1.2 + 0.6 * power)
	var full := power >= 0.99
	var arc := TAU if full else minf(TAU, attack_arc * 1.6)
	var target: Node2D = combat.nearest_enemy(global_position, reach * 1.5)
	if target:
		facing = (target.global_position - global_position).normalized()
	swing_time = 0.3
	swing_duration = 0.3
	swing_full = full
	swing_reach = reach
	var hits := 0
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() > reach + e.radius:
			continue
		if full or to.length() < 1.0 or absf(facing.angle_to(to)) <= arc * 0.5:
			var r := _roll(mult)
			hit(e, r[0], to.normalized() * 600.0 * (1.0 + power) * weapon["kb"], r[1])
			if not e.dead and not e.is_boss:
				e.stun = maxf(e.stun, 0.4 + 0.8 * power)
			hits += 1
	combo_step = 0
	attack_timer = attack_cooldown
	Audio.play("crit", 0.05)
	combat.shake(6.0 + 6.0 * power)
	combat.fx.ring(global_position, Color(1.0, 0.85, 0.35), 30, reach, 6, 0.35)
	if hits > 0:
		combat.hitstop(0.06 + 0.05 * power)
		Events.charged_hit.emit()
	if full:
		combat.float_text(global_position + Vector2(0, -70), "Козацький удар!", Color(1.0, 0.85, 0.3))


## Ідеальне парирування: ворожий удар зірвано, ворог приголомшений, у відповідь — критичний удар.
func _parry(source) -> void:
	invuln = 0.45
	blocking = false
	block_cd = 0.15
	combo_step = 2  # наступний удар — завершальний
	combo_timer = COMBO_WINDOW
	Audio.play("crit", 0.0)
	combat.hitstop(0.12)
	combat.fx.ring(global_position, Color(1.0, 0.95, 0.6), 20, 120, 5, 0.3)
	combat.float_text(global_position + Vector2(0, -70), "Парирування!" if source != null else "Відбито!", Color(1.0, 0.95, 0.5))
	Events.parried.emit()
	if source != null and is_instance_valid(source) and not source.dead:
		source.windup = 0.0
		source.stun = maxf(source.stun, 0.6 if source.is_boss else 1.5)
		var to: Vector2 = source.global_position - global_position
		hit(source, damage * 1.5 * crit_mult, to.normalized() * 400.0, true)


# ================= Бій =================

func _tick_effects(delta: float) -> void:
	cry_timer = maxf(0.0, cry_timer - delta)
	stina_timer = maxf(0.0, stina_timer - delta)
	tin_timer = maxf(0.0, tin_timer - delta)
	wolf_timer = maxf(0.0, wolf_timer - delta)
	zamova_timer = maxf(0.0, zamova_timer - delta)
	zahyst_timer = maxf(0.0, zahyst_timer - delta)
	cleanse_timer = maxf(0.0, cleanse_timer - delta)
	if burya_timer > 0.0:
		burya_timer -= delta
		_burya_tick -= delta
		if _burya_tick <= 0.0:
			_burya_tick = 0.5
			_burya_strike()
	if ward_timer > 0.0:
		ward_timer -= delta
		if ward_timer <= 0.0:
			ward_hp = 0.0
	if herb_timer > 0.0:
		herb_timer -= delta
		hp = minf(max_hp, hp + herb_rate * Status.heal_mult(self) * delta)


func _roll(mult: float) -> Array:
	var crit := randf() < crit_chance
	if tin_timer > 0.0:
		# Удар із Тіні: гарантований крит і бонус, а Тінь спадає
		crit = true
		mult *= 1.2 + 0.2 * sk("tin")
		tin_timer = 0.0
	var dmg := damage * mult * (crit_mult if crit else 1.0) * randf_range(0.9, 1.1) * (1.0 + (cry_bonus if cry_timer > 0.0 else 0.0))
	if wolf_timer > 0.0:
		dmg *= 1.25
	if pk("nevhamovnyi") > 0:
		dmg *= 1.0 + 0.15 * pk("nevhamovnyi") * clampf(1.0 - hp / maxf(max_hp, 1.0), 0.0, 1.0)
	return [dmg, crit]


## Удар по ворогу з урахуванням вампіризму.
func hit(e, dmg: float, kb: Vector2, crit: bool) -> void:
	if e.dead:
		return
	e.take_damage(dmg, kb, crit)
	if zamova_timer > 0.0 and not _chaining:
		_zamova_chain(e, dmg)
	if wolf_timer > 0.0:
		heal(dmg * 0.08, false)
	if crit and not e.dead:
		Status.apply(e, "bleed", 3.0, dmg * 0.1)  # критичний удар лишає кровотечу
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
	if combo_timer <= 0.0:
		combo_step = 0
	var step := combo_step
	var finisher := step == COMBO_MULT.size() - 1
	var arc := attack_arc * (1.5 if finisher else 1.0)
	if finisher:
		attack_timer = attack_cooldown * 1.3  # після завершального — коротка пауза, як у справжньому ритмі
	if weapon_type == "staff":
		_cast_sparks(step, finisher)
		return
	if weapon_type == "pishchal":
		_fire_pishchal(step, finisher)
		return
	# Автонаведення — на телефоні цілитися пальцем незручно.
	var target: Node2D = combat.nearest_enemy(global_position, attack_range * 1.8)
	if target:
		facing = (target.global_position - global_position).normalized()
	swing_time = 0.18
	swing_duration = 0.18
	swing_full = false
	Audio.play("swing", 0.15, -4.0 if not finisher else 0.0)
	var hits := 0
	var crit_any := false
	var reach := attack_range * (1.15 if finisher else 1.0)
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		var dist := to.length()
		if dist > reach + e.radius:
			continue
		if dist < 1.0 or absf(facing.angle_to(to)) <= arc * 0.5:
			var r := _roll(COMBO_MULT[step])
			hit(e, r[0], to.normalized() * 280.0 * weapon["kb"] * (2.2 if finisher else 1.0), r[1])
			if finisher and weapon_type == "mace" and not e.dead and not e.is_boss:
				e.stun = maxf(e.stun, 0.6)  # завершальний удар булавою оглушує
			hits += 1
			crit_any = crit_any or r[1]
	if hits > 0:
		mana = minf(max_mana, mana + 2.5)  # влучний удар трохи поповнює наснагу
		combo_step = (step + 1) % COMBO_MULT.size()
		combo_timer = COMBO_WINDOW
		if finisher:
			combat.fx.ring(global_position + facing * 40.0, Color(1.0, 0.8, 0.4), 16, reach, 4, 0.25)
			combat.shake(4.0)
	else:
		combo_step = 0
	if hits > 0:
		Audio.play("crit" if crit_any else "hit", 0.12)
		combat.shake(2.5 * weapon["kb"])
		if crit_any:
			combat.hitstop(0.05)


## Ковтнути зілля здоров'я. Повертає true, якщо вдалося.
func use_potion() -> bool:
	if not alive or potions <= 0 or potion_timer > 0.0 or (hp >= max_hp and mana >= max_mana * 0.6):
		return false
	potions -= 1
	potion_timer = Data.POTION_CD
	heal(max_hp * Data.POTION_HEAL)
	mana = minf(max_mana, mana + max_mana * Data.POTION_HEAL)  # зілля відновлює й наснагу
	return true


func add_potion() -> bool:
	if potions >= potion_max():
		return false
	potions += 1
	return true


func dodge() -> void:
	if not alive or dodge_timer > 0.0:
		return
	blocking = false
	combo_step = 0
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
	var base: float = Classes.COOLDOWNS.get(id, 6.0)
	if id in ["lightning", "molot", "burya"]:
		base *= 1.0 - 0.1 * pk("storm_soul")
	match id:
		"whirl":
			base *= 1.0 - 0.1 * sk("whirl_cd")
		"musket":
			base *= 1.0 - 0.12 * sk("reload")
	return base * skill_cd_mult


func skill_ready_ratio(id: String) -> float:
	return skill_timers.get(id, 0.0) / skill_cooldown(id)


func skill_cost(id: String) -> float:
	return float(Classes.find_node(id).get("cost", 0))


func use_skill(id: String) -> void:
	if not alive or sk(id) <= 0 or skill_timers.get(id, 0.0) > 0.0:
		return
	if mana < skill_cost(id):
		if _in_combat():
			combat.float_text(global_position + Vector2(0, -80), "Бракує наснаги", Color(0.5, 0.65, 1.0))
		return
	var used := false
	match id:
		"whirl":
			used = _whirl()
		"lightning":
			used = _lightning()
		"musket":
			used = _musket()
		"vyly":
			used = _vyly()
		"first_aid":
			used = _first_aid()
		"battle_cry":
			used = _battle_cry()
		"fireball":
			used = _fireball()
		"shield":
			used = _shield()
		"herb":
			used = _herb()
		"zemnyi":
			used = _zemnyi()
		"stina":
			used = _stina()
		"bulava":
			used = _bulava()
		"pastka":
			used = _pastka()
		"tin":
			used = _tin()
		"kydok":
			used = _kydok()
		"kartech":
			used = _kartech()
		"prytsil":
			used = _prytsil_shot((3.8 + 0.9 * (sk("prytsil") - 1)) * skill_power, false)
		"bochka":
			used = _bochka()
		"vovk":
			used = _vovk()
		"kulia":
			used = _kulia()
		"zamova":
			used = _zamova()
		"vidvid":
			used = _vidvid()
		"zhyvytsia":
			used = _zhyvytsia()
		"pidniaty":
			used = combat.revive_companions(0.4 + 0.15 * (sk("pidniaty") - 1)) > 0
		"ochyshchennia":
			used = _ochyshchennia()
		"oberih_zahonu":
			used = _oberih_zahonu()
		"otruta":
			used = _otruta()
		"molot":
			used = _molot()
		"burya":
			used = _burya()
		"grad":
			used = _grad()
		"tuman":
			used = _tuman()
		"proklin":
			used = _proklin()
		"dukh":
			used = _dukh()
	if used:
		mana -= skill_cost(id)
		skill_timers[id] = skill_cooldown(id)


## Усі вивчені активні вміння (свого класу і набуті раніше), у порядку дерев.
func learned_actives() -> Array:
	var out := []
	var lin: Array = Classes.lineage(job)
	lin.reverse()
	for c in lin:
		for b in Classes.TREES[c]:
			for n in b["nodes"]:
				if n.get("active", false) and sk(n["id"]) > 0 and not (n["id"] in out):
					out.append(n["id"])
	return out


## Що стоїть на кнопках бою (атаки й бафи разом, без порожніх) — для перебору вміннями.
func active_skills() -> Array:
	sync_panel()
	var out := []
	for id in panel["attack"] + panel["buff"]:
		if id != "":
			out.append(id)
	return out


func panel_kind(id: String) -> String:
	return SkillInfo.kind(id)


## Прибирає з панелі невивчене й сам ставить нові вивчені вміння у вільні комірки свого типу.
func sync_panel() -> void:
	for kind in ["attack", "buff"]:
		var size := ATTACK_SLOTS if kind == "attack" else BUFF_SLOTS
		var arr: Array = panel.get(kind, [])
		while arr.size() < size:
			arr.append("")
		for i in size:
			var id: String = arr[i]
			if id != "" and (sk(id) <= 0 or panel_kind(id) != kind):
				arr[i] = ""
		panel[kind] = arr
	for id in learned_actives():
		if id in panel["attack"] or id in panel["buff"]:
			continue
		var arr: Array = panel[panel_kind(id)]
		var free := arr.find("")
		if free >= 0:
			arr[free] = id


## Поставити вміння в комірку (або прибрати, якщо id == ""). Якщо воно вже стоїть деінде — переносимо.
func set_panel(kind: String, index: int, id: String) -> bool:
	if not panel.has(kind) or index < 0 or index >= panel[kind].size():
		return false
	if id != "" and (sk(id) <= 0 or panel_kind(id) != kind):
		return false
	var arr: Array = panel[kind]
	var old := arr.find(id) if id != "" else -1
	if old >= 0:
		arr[old] = arr[index]
	arr[index] = id
	return true


# ---------- Селянин ----------

func _vyly() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 300.0)
	if target:
		facing = (target.global_position - global_position).normalized()
	var length := maxf(attack_range * 1.6, 200.0)
	var m := 2.0 * (1.0 + 0.15 * (sk("vyly") - 1)) * skill_power
	for e in _alive_enemies():
		var l: Vector2 = e.global_position - global_position
		var along := l.dot(facing)
		if along >= -10.0 and along <= length + e.radius and absf(l.dot(facing.orthogonal())) <= 45.0 + e.radius:
			var r := _roll(m)
			hit(e, r[0], facing * 520.0, r[1])
	swing_time = 0.22
	swing_duration = 0.22
	swing_full = false
	dodge_dir = facing
	dodge_time_left = 0.1  # короткий випад уперед
	Audio.play("swing", 0.1, 0.0)
	combat.fx.burst(global_position + facing * length * 0.6, Color(0.9, 0.85, 0.7), 10, 220, 4, 0.3, 0, facing.angle(), 0.5)
	combat.shake(4.0)
	return true


func _first_aid() -> bool:
	if hp >= max_hp:
		return false
	heal(max_hp * (0.15 + 0.05 * sk("first_aid")))
	statuses.erase("bleed")
	return true


# ---------- Козак ----------

func _battle_cry() -> bool:
	cry_timer = 8.0
	cry_bonus = 0.15 + 0.05 * (sk("battle_cry") - 1)
	Audio.play("roar", 0.05, -2.0)
	combat.float_text(global_position + Vector2(0, -70), "Гей, козаки!", Color(1.0, 0.7, 0.3))
	combat.fx.ring(global_position, Color(1.0, 0.6, 0.25), 24, 260, 5, 0.4)
	return true


# ---------- Запорожець ----------

func _zemnyi() -> bool:
	var reach := 230.0
	var m := 1.6 * (1.0 + 0.15 * (sk("zemnyi") - 1)) * skill_power
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius:
			var r := _roll(m)
			hit(e, r[0], to.normalized() * 300.0, r[1])
			if not e.dead and not e.is_boss:
				e.stun = maxf(e.stun, 1.0 + 0.2 * sk("zemnyi"))
	swing_time = 0.35
	swing_duration = 0.35
	swing_full = true
	swing_reach = reach
	combat.shake(10.0)
	Audio.play("boom", 0.05, -2.0)
	combat.fx.ring(global_position + Vector2(0, 16), Color(0.6, 0.45, 0.25), 30, reach * 2.0, 8, 0.4)
	combat.fx.burst(global_position + Vector2(0, 16), Color(0.5, 0.4, 0.25), 24, 260, 7, 0.6)
	return true


func _stina() -> bool:
	stina_timer = 6.0
	Audio.play("roar", 0.05, -3.0)
	combat.float_text(global_position + Vector2(0, -70), "Козацька стіна!", Color(0.9, 0.8, 0.5))
	combat.fx.ring(global_position, Color(0.85, 0.75, 0.5), 24, 420, 5, 0.4)
	return true


func _bulava() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 300.0)
	if target:
		facing = (target.global_position - global_position).normalized()
	var reach := maxf(attack_range * 1.5, 190.0)
	var m := 3.0 * (1.0 + 0.2 * (sk("bulava") - 1)) * skill_power
	for e in _alive_enemies():
		var to: Vector2 = e.global_position - global_position
		if to.length() <= reach + e.radius and (to.length() < 1.0 or absf(facing.angle_to(to)) <= 1.05):
			var r := _roll(m)
			hit(e, r[0], to.normalized() * 900.0, r[1])
	swing_time = 0.3
	swing_duration = 0.3
	swing_full = false
	combat.shake(9.0)
	combat.hitstop(0.06)
	Audio.play("crit", 0.05)
	combat.fx.burst(global_position + facing * reach * 0.6, Color(1.0, 0.6, 0.3), 18, 300, 6, 0.4, 0, facing.angle(), 1.2)
	return true


# ---------- Пластун ----------

func _pastka() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 260.0)
	var pos: Vector2 = target.global_position if target else global_position + facing * 80.0
	var r := _roll(2.2 * (1.0 + 0.2 * (sk("pastka") - 1)) * (1.0 + 0.2 * pk("trapper")) * skill_power)
	combat.spawn_trap(pos, r[0], r[1], 2 + pk("trapper"))
	Audio.play("sharpen_ok", 0.1, -8.0)
	return true


func _tin() -> bool:
	tin_timer = 4.0
	combat.fx.burst(global_position, Color(0.2, 0.2, 0.25), 20, 160, 7, 0.5)
	combat.float_text(global_position + Vector2(0, -70), "Тінь", Color(0.6, 0.6, 0.75))
	return true


func _kydok() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 650.0)
	var dir := facing
	if target:
		dir = (target.global_position - global_position).normalized()
		facing = dir
	var r := _roll(3.0 * (1.0 + 0.2 * (sk("kydok") - 1)) * skill_power)
	combat.spawn_bullet(global_position + Vector2(0, -12) + dir * 30.0, dir, r[0], r[1])
	combat.last_projectile().color = Color(0.85, 0.8, 0.7)
	combat.last_projectile().spear = true
	Audio.play("swing", 0.05, 0.0)
	return true


# ---------- Самопальник ----------

## Звичайна атака пищаллю: куля навиліт, завершальний постріл — три кулі.
func _fire_pishchal(step: int, finisher: bool) -> void:
	var target: Node2D = combat.nearest_enemy(global_position, attack_range * 1.3)
	if target == null:
		combo_step = 0
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	var angles := [-0.12, 0.0, 0.12] if finisher else [0.0]
	for a in angles:
		var r := _roll(COMBO_MULT[step] * (0.7 if angles.size() > 1 else 1.0))
		combat.spawn_bullet(global_position + Vector2(0, -10) + dir * 34.0, dir.rotated(a), r[0], r[1])
		combat.last_projectile().pierce = 2  # звичайна куля пищалі пробиває двох
	Audio.play("musket", 0.15, -8.0)
	combat.fx.burst(global_position + Vector2(0, -10) + dir * 44.0, Color(0.85, 0.85, 0.8, 0.6), 8, 120, 7, 0.6, -40, dir.angle(), 0.8)
	combat.shake(1.5)
	combo_step = (step + 1) % COMBO_MULT.size()
	combo_timer = COMBO_WINDOW


func _kartech() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 600.0)
	var dir := facing
	if target:
		dir = (target.global_position - global_position).normalized()
		facing = dir
	var m := 0.65 * (1.0 + 0.15 * (sk("kartech") - 1)) * skill_power
	for i in 7:
		var r := _roll(m)
		combat.spawn_bullet(global_position + Vector2(0, -10) + dir * 34.0, dir.rotated(-0.42 + i * 0.14), r[0], r[1])
		combat.last_projectile().pierce = 1  # картеч не пробиває
	Audio.play("musket", 0.05, 0.0)
	combat.shake(5.0)
	combat.fx.burst(global_position + Vector2(0, -10) + dir * 44.0, Color(1.0, 0.8, 0.3), 14, 300, 5, 0.2, 0, dir.angle(), 0.9)
	return true


func _prytsil_shot(mult: float, stun: bool) -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 900.0)
	var dir := facing
	if target:
		dir = (target.global_position - global_position).normalized()
		facing = dir
	var r := _roll(mult)
	combat.spawn_bullet(global_position + Vector2(0, -10) + dir * 34.0, dir, r[0], true)
	var b = combat.last_projectile()
	b.velocity = dir * 1500.0
	b.radius = 9.0
	b.life = 1.2
	b.stun_all = stun
	Audio.play("musket", 0.0, 2.0)
	combat.shake(6.0)
	combat.hitstop(0.04)
	return true


func _bochka() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 450.0)
	var pos: Vector2 = target.global_position if target else global_position + facing * 220.0
	var r := _roll(2.8 * (1.0 + 0.2 * (sk("bochka") - 1)) * skill_power)
	combat.spawn_barrel(pos, r[0], r[1], 150.0, r[0] * 0.1)
	Audio.play("swing", 0.05, -2.0)
	return true


# ---------- Характерник ----------

func _vovk() -> bool:
	wolf_timer = 10.0 + 2.0 * (sk("vovk") - 1)
	Audio.play("roar", 0.0, 0.0)
	combat.float_text(global_position + Vector2(0, -70), "Вовча подоба!", Color(0.8, 0.8, 0.85))
	combat.fx.burst(global_position, Color(0.5, 0.5, 0.5), 26, 220, 8, 0.6)
	return true


func _kulia() -> bool:
	invuln = maxf(invuln, 2.0 + 0.5 * (sk("kulia") - 1))
	combat.float_text(global_position + Vector2(0, -70), "Куля не бере!", Color(1.0, 0.85, 0.3))
	combat.fx.ring(global_position, Color(1.0, 0.85, 0.3), 20, 100, 4, 0.4)
	return true


func _zamova() -> bool:
	zamova_timer = 10.0
	Audio.play("lightning", 0.05, -6.0)
	combat.float_text(global_position + Vector2(0, -70), "Замовляння шаблі", Color(0.6, 0.8, 1.0))
	return true


## Замовлена шабля: удар перескакує блискавкою на двох сусідів.
func _zamova_chain(from, dmg: float) -> void:
	_chaining = true
	var near := _alive_enemies().filter(func(e): return e != from and e.global_position.distance_to(from.global_position) < 260.0)
	near.sort_custom(func(a, b): return from.global_position.distance_squared_to(a.global_position) < from.global_position.distance_squared_to(b.global_position))
	var pts := PackedVector2Array([from.global_position])
	for i in mini(2, near.size()):
		var e = near[i]
		pts.append(e.global_position)
		hit(e, dmg * (0.35 + 0.05 * sk("zamova")), Vector2.ZERO, false)
	if pts.size() > 1:
		combat.spawn_bolt(pts)
	_chaining = false


func _vidvid() -> bool:
	var dur := 2.0 + 0.3 * (sk("vidvid") - 1)
	var n := 0
	for e in _alive_enemies():
		if global_position.distance_to(e.global_position) <= 300.0 + e.radius:
			Status.apply(e, "weak", dur + 2.0)
			if not e.is_boss:
				e.stun = maxf(e.stun, dur)
			n += 1
	if n == 0:
		return false
	Audio.play("lightning", 0.1, -4.0)
	combat.fx.ring(global_position, Color(0.6, 0.4, 0.8), 28, 600, 5, 0.5)
	return true


# ---------- Знахар ----------

func heal_power() -> float:
	return skill_power * (1.0 + 0.12 * pk("travnyk"))


func _zhyvytsia() -> bool:
	var pct := (0.3 + 0.05 * (sk("zhyvytsia") - 1)) * heal_power()
	heal(max_hp * pct)
	for c in combat.companion_nodes:
		if is_instance_valid(c) and c.alive:
			c.heal(c.max_hp * pct)
	combat.fx.ring(global_position, Color(0.5, 1.0, 0.55), 24, 260, 5, 0.5)
	Audio.play("heal", 0.0)
	return true


func _ochyshchennia() -> bool:
	statuses.clear()
	cleanse_timer = 2.0 + 1.0 * (sk("ochyshchennia") - 1)
	combat.fx.ring(global_position, Color(0.8, 0.95, 1.0), 20, 160, 4, 0.4)
	combat.float_text(global_position + Vector2(0, -70), "Очищення", Color(0.8, 0.95, 1.0))
	return true


func _oberih_zahonu() -> bool:
	zahyst_timer = 8.0
	zahyst_mult = 1.0 - (0.25 + 0.05 * (sk("oberih_zahonu") - 1))
	combat.fx.ring(global_position, Color(0.5, 0.7, 1.0), 24, 320, 5, 0.5)
	combat.float_text(global_position + Vector2(0, -70), "Оберіг загону", Color(0.6, 0.8, 1.0))
	Audio.play("heal", 0.0, -3.0)
	return true


func _otruta() -> bool:
	var e: Node2D = combat.nearest_enemy(global_position, 450.0)
	if e == null:
		return false
	combat.spawn_zone("otruta", e.global_position, 110.0, 5.0, damage * 0.5 * (1.0 + 0.2 * (sk("otruta") - 1)) * skill_power)
	Audio.play("swing", 0.1, -6.0)
	return true


# ---------- Перунів жрець ----------

func _molot() -> bool:
	var e: Node2D = combat.nearest_enemy(global_position, 600.0)
	if e == null:
		return false
	var pos: Vector2 = e.global_position
	var m := 3.5 * (1.0 + 0.2 * (sk("molot") - 1)) * (1.0 + 0.1 * pk("grim")) * skill_power
	for t in _alive_enemies():
		var to: Vector2 = t.global_position - pos
		if to.length() <= 160.0 + t.radius:
			var r := _roll(m)
			hit(t, r[0], to.normalized() * 320.0, r[1])
			if not t.dead and not t.is_boss:
				t.stun = maxf(t.stun, 0.8)
	combat.spawn_bolt(PackedVector2Array([pos + Vector2(10, -460), pos + Vector2(-20, -200), pos]))
	combat.fx.ring(pos, Color(0.75, 0.85, 1.0), 30, 320, 6, 0.35)
	combat.shake(10.0)
	Audio.play("lightning", 0.0, 2.0)
	return true


func _burya() -> bool:
	burya_timer = 6.0 + 1.0 * (sk("burya") - 1)
	_burya_tick = 0.0
	combat.float_text(global_position + Vector2(0, -70), "Буря!", Color(0.7, 0.8, 1.0))
	return true


func _burya_strike() -> void:
	var near := _alive_enemies().filter(func(e): return global_position.distance_to(e.global_position) <= 450.0)
	if near.is_empty():
		return
	var e = near[randi() % near.size()]
	var r := _roll(1.3 * (1.0 + 0.15 * (sk("burya") - 1)) * (1.0 + 0.1 * pk("grim")) * skill_power)
	hit(e, r[0], Vector2.ZERO, r[1])
	combat.spawn_bolt(PackedVector2Array([e.global_position + Vector2(randf_range(-40, 40), -420), e.global_position]))
	Audio.play("lightning", 0.2, -8.0)


# ---------- Мольфар ----------

func _grad() -> bool:
	var e: Node2D = combat.nearest_enemy(global_position, 550.0)
	if e == null:
		return false
	var k := 1.0 + 0.2 * pk("khmara")
	combat.spawn_zone("grad", e.global_position, 140.0 * k, 3.0, damage * 0.45 * (1.0 + 0.2 * (sk("grad") - 1)) * k * skill_power)
	Audio.play("lightning", 0.2, -10.0)
	return true


func _tuman() -> bool:
	combat.spawn_zone("tuman", global_position, 230.0, 6.0, 0.0)
	return true


func _proklin() -> bool:
	var e: Node2D = combat.nearest_enemy(global_position, 500.0)
	if e == null:
		return false
	for t in _alive_enemies():
		if t.global_position.distance_to(e.global_position) <= 150.0:
			Status.apply(t, "curse", 8.0)
			Status.apply(t, "weak", 8.0)
	combat.fx.ring(e.global_position, Color(0.5, 0.2, 0.5), 20, 300, 5, 0.5)
	Audio.play("roar", 0.3, -10.0)
	return true


func _dukh() -> bool:
	combat.spawn_zone("spirit", global_position + Vector2(0, -60), 0.0, 15.0, damage * 0.8 * (1.0 + 0.2 * (sk("dukh") - 1)) * skill_power)
	combat.float_text(global_position + Vector2(0, -70), "Духу гір, прийди!", Color(0.6, 0.9, 1.0))
	return true


# ---------- Волхв ----------

## Звичайна атака волхва: іскри з посоха летять у найближчого ворога.
func _cast_sparks(step: int, finisher: bool) -> void:
	var target: Node2D = combat.nearest_enemy(global_position, attack_range * 1.3)
	if target == null:
		combo_step = 0
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	swing_time = 0.15
	swing_duration = 0.15
	swing_full = false
	var angles := [0.0]
	if finisher:
		angles = [-0.22, 0.0, 0.22]
	elif sk("twin_spark") > 0:
		angles = [-0.08, 0.08]
	var mult: float = COMBO_MULT[step] * (1.0 + 0.1 * sk("iskra")) * (0.75 if angles.size() > 1 else 1.0)
	for a in angles:
		var r := _roll(mult)
		combat.spawn_spark(global_position + Vector2(0, -24) + dir * 26.0, dir.rotated(a), r[0], r[1])
	Audio.play("lightning", 0.2, -14.0)
	combo_step = (step + 1) % COMBO_MULT.size()
	combo_timer = COMBO_WINDOW


func _fireball() -> bool:
	var target: Node2D = combat.nearest_enemy(global_position, 650.0)
	if target == null:
		return false
	var dir: Vector2 = (target.global_position - global_position).normalized()
	facing = dir
	var r := _roll(2.4 * (1.0 + 0.2 * (sk("fireball") - 1)) * skill_power)
	combat.spawn_fireball(global_position + Vector2(0, -24) + dir * 30.0, dir, r[0], r[1], 95.0 * (1.0 + 0.2 * sk("pyre")), r[0] * (0.12 + 0.04 * sk("pyre")))
	Audio.play("musket", 0.1, -6.0)
	return true


func _shield() -> bool:
	ward_hp = max_hp * (0.2 + 0.05 * (sk("shield") - 1)) * skill_power
	ward_timer = 8.0
	Audio.play("heal", 0.0, -2.0)
	combat.float_text(global_position + Vector2(0, -70), "Щит-оберіг!", Color(0.6, 0.85, 1.0))
	combat.fx.ring(global_position, Color(0.5, 0.75, 1.0), 20, 90, 4, 0.4)
	return true


func _herb() -> bool:
	herb_timer = 6.0
	herb_rate = max_hp * (0.2 + 0.06 * (sk("herb") - 1)) * skill_power / 6.0
	for c in combat.companion_nodes:
		if is_instance_valid(c) and c.alive:
			c.heal(c.max_hp * 0.3)
	statuses.erase("plague")
	Audio.play("heal", 0.0)
	combat.fx.burst(global_position, Color(0.5, 1.0, 0.5), 16, 120, 5, 0.8, -60)
	return true


## Заряджене закляття: велика вогняна куля у найближчого ворога.
func _charged_spell(power: float) -> void:
	var target: Node2D = combat.nearest_enemy(global_position, 700.0)
	var dir: Vector2 = facing if target == null else (target.global_position - global_position).normalized()
	facing = dir
	var r := _roll((1.6 + 1.6 * power) * skill_power)
	combat.spawn_fireball(global_position + Vector2(0, -24) + dir * 30.0, dir, r[0], r[1], 120.0 * (1.0 + power), r[0] * 0.1, power >= 0.99)
	combo_step = 0
	attack_timer = attack_cooldown
	combat.shake(4.0 + 4.0 * power)
	Audio.play("lightning", 0.05, -3.0)
	Events.charged_hit.emit()
	if power >= 0.99:
		combat.float_text(global_position + Vector2(0, -70), "Гнів Роду!", Color(1.0, 0.7, 0.3))


func whirl_reach() -> float:
	return attack_range * 1.8 * (1.0 + 0.08 * (sk("whirl") - 1))


func _whirl() -> bool:
	var storm := sk("storm") > 0
	swing_time = 0.4
	swing_duration = 0.4
	swing_full = true
	swing_reach = 0.0
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
	swing_reach = 0.0
	combat.shake(9.0)


func _lightning() -> bool:
	var targets := _alive_enemies().filter(func(e): return global_position.distance_to(e.global_position) <= 480.0 + e.radius)
	if targets.is_empty():
		return false
	targets.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	var count := 2 + sk("lightning") + 2 * sk("chain")
	var m := (1.2 + 0.25 * sk("lightning")) * skill_power * (1.0 + 0.1 * pk("grim"))
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

## Повертає true, якщо удар таки поранив (не блок-парирування, не невразливість).
func take_damage(amount: float, source = null) -> bool:
	if not alive or invuln > 0.0:
		return false
	if blocking:
		if block_time <= PARRY_WINDOW:
			_parry(source)
			return false
		amount *= BLOCK_MULT
		combat.float_text(global_position + Vector2(0, -70), "Блок", Color(0.75, 0.85, 1.0))
	if ward_hp > 0.0:
		var absorbed := minf(ward_hp, amount)
		ward_hp -= absorbed
		amount -= absorbed
		combat.fx.ring(global_position, Color(0.5, 0.75, 1.0), 12, 70, 3, 0.2)
		if amount <= 0.0:
			combat.float_text(global_position + Vector2(0, -70), "Оберіг", Color(0.6, 0.85, 1.0))
			return false
	if stina_timer > 0.0:
		amount *= 1.0 - (0.4 + 0.05 * (sk("stina") - 1))
	if zahyst_timer > 0.0:
		amount *= zahyst_mult
	if source != null and thorns > 0.0 and not source.dead:
		source.take_damage(amount * thorns, Vector2.ZERO, false)
	amount *= (1.0 - armor)
	if trip_buffs.has("antiplague"):
		amount *= 0.8
	hp -= amount
	hurt_flash = 0.2
	invuln = 0.35
	combat.shake(7.0)
	Audio.play("hurt", 0.1)
	Events.player_hurt.emit()
	combat.float_text(global_position + Vector2(0, -50), str(int(amount)), Color(1.0, 0.35, 0.3))
	_check_death()
	return true


## Шкода від станів: оминає блок і невразливість, але не броню.
func _take_dot(amount: float) -> void:
	amount *= (1.0 - armor * 0.5)
	hp -= amount
	combat.float_text(global_position + Vector2(randf_range(-20, 20), -40), str(maxi(1, int(amount))), Status.tint(self))
	_check_death()


func _check_death() -> void:
	if hp > 0.0:
		return
	if pk("unbreak") > 0 and unbreak_ready:
		unbreak_ready = false
		hp = 1.0
		invuln = 1.5
		statuses.clear()
		Events.banner.emit("Незламний!", Color(1.0, 0.85, 0.3))
		return
	hp = 0.0
	alive = false
	queue_redraw()
	died.emit()
	Events.player_died.emit()


## Накласти стан на козака (від удару ворога).
func add_status(id: String, dur: float, dps: float = 0.0) -> void:
	if not alive or cleanse_timer > 0.0:
		return
	if id == "plague":
		if plague_immune:
			return
		dps *= 1.0 - plague_resist
	var fresh := not statuses.has(id)
	Status.apply(self, id, dur, dps)
	if fresh and _in_combat():
		combat.float_text(global_position + Vector2(0, -95), Status.INFO[id]["name"] + "!", Status.INFO[id]["color"])


func heal(amount: float, show: bool = true) -> void:
	amount *= Status.heal_mult(self)
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
	if alive and tin_timer > 0.0:
		tint = Color(0.6, 0.6, 0.75, 0.4)  # Тінь: пластун ледь видно
	elif alive and wolf_timer > 0.0:
		tint = tint * Color(0.75, 0.75, 0.8)

	# Тінь
	draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		draw_set_transform(Vector2(0, 8), PI / 2.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	var bob := sin(walk_phase) * 3.0 if moving else 0.0

	var peasant := is_peasant()
	var volkhv := Classes.is_volkhv_line(job)
	# Ноги: козак — широкі сині шаровари й червоні чоботи; селянин — полотняні штани й постоли
	var leg_l := Vector2(-7, 10 + bob)
	var leg_r := Vector2(7, 10 - bob)
	var pants := Color(0.72, 0.68, 0.58) if peasant else (Color(0.9, 0.88, 0.8) if volkhv else Color(0.18, 0.3, 0.7))
	var boots := Color(0.45, 0.32, 0.2) if peasant or volkhv else Color(0.6, 0.1, 0.1)
	draw_rect(Rect2(leg_l - Vector2(6, 2), Vector2(11, 10)), pants * tint)
	draw_rect(Rect2(leg_r - Vector2(5, 2), Vector2(11, 10)), pants * tint)
	draw_rect(Rect2(leg_l + Vector2(-5, 7), Vector2(10, 6)), boots * tint)
	draw_rect(Rect2(leg_r + Vector2(-4, 7), Vector2(10, 6)), boots * tint)

	if volkhv:
		# Волхв: довга біла сорочка до колін, червоний пояс, бурий плащ за плечима
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -16), Vector2(14, -16), Vector2(18, 16), Vector2(-18, 16)]), Color(0.45, 0.32, 0.2) * tint)
		draw_colored_polygon(PackedVector2Array([Vector2(-11, -16), Vector2(11, -16), Vector2(14, 14), Vector2(-14, 14)]), Color(0.96, 0.95, 0.9) * tint)
		draw_line(Vector2(0, -15), Vector2(0, 12), Color(0.8, 0.12, 0.12) * tint, 2.0)
		draw_rect(Rect2(-13, 2, 26, 3), Color(0.8, 0.15, 0.12) * tint)
		match job:
			"znakhar":
				draw_line(Vector2(-11, -15), Vector2(-14, 14), Color(0.3, 0.6, 0.25) * tint, 2.5)  # зелене шиття
				draw_line(Vector2(11, -15), Vector2(14, 14), Color(0.3, 0.6, 0.25) * tint, 2.5)
				draw_circle(Vector2(-side * 12, 8), 5.0, Color(0.55, 0.4, 0.2) * tint)  # торбинка з травами
				draw_circle(Vector2(-side * 12, 4), 2.5, Color(0.35, 0.7, 0.3) * tint)
			"perun_zhrets":
				draw_rect(Rect2(-13, 2, 26, 3), Color(0.25, 0.4, 0.85) * tint)  # синій пояс
				draw_polyline(PackedVector2Array([Vector2(-3, -12), Vector2(3, -6), Vector2(-2, -3), Vector2(4, 3)]), Color(1.0, 0.85, 0.2) * tint, 2.0)
			"molfar":
				# Гуцульський кептар поверх сорочки
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -15), Vector2(-3, -15), Vector2(-5, 10), Vector2(-14, 10)]), Color(0.65, 0.35, 0.15) * tint)
				draw_colored_polygon(PackedVector2Array([Vector2(12, -15), Vector2(3, -15), Vector2(5, 10), Vector2(14, 10)]), Color(0.65, 0.35, 0.15) * tint)
	elif peasant:
		# Тулуб: біла сорочка з вишивкою і мотузяний пояс
		draw_circle(Vector2(0, -2), 15.0, Color(0.95, 0.94, 0.9) * tint)
		draw_line(Vector2(-6, -14), Vector2(-6, 6), Color(0.8, 0.12, 0.12) * tint, 2.0)
		draw_line(Vector2(6, -14), Vector2(6, 6), Color(0.8, 0.12, 0.12) * tint, 2.0)
		draw_rect(Rect2(-14, 4, 28, 3), Color(0.55, 0.4, 0.25) * tint)
	else:
		# Тулуб: жупан кольору спеціалізації і пояс
		var coat: Color = {"zaporozhets": Color(0.55, 0.08, 0.1), "plastun": Color(0.35, 0.4, 0.22),
			"samopalnyk": Color(0.2, 0.25, 0.45), "kharakternyk": Color(0.15, 0.12, 0.14)}.get(job, Color(0.78, 0.14, 0.14))
		draw_circle(Vector2(0, -2), 16.0, coat * tint)
		draw_rect(Rect2(-15, 3, 30, 5), Color(0.95, 0.75, 0.15) * tint)
		if job == "zaporozhets":
			draw_arc(Vector2(0, -2), 16.0, PI * 1.1, PI * 1.9, 12, Color(0.95, 0.75, 0.2) * tint, 3.0)  # золоте шиття
		elif job == "kharakternyk":
			draw_arc(Vector2(0, -6), 15.0, PI * 1.05, PI * 1.95, 12, Color(0.55, 0.55, 0.55) * tint, 6.0)  # вовча шкура на плечах
		elif job == "samopalnyk":
			draw_line(Vector2(-10, -12), Vector2(8, 4), Color(0.6, 0.45, 0.25) * tint, 3.0)  # ремінь порохівниці
			draw_circle(Vector2(9, 5), 4.0, Color(0.75, 0.6, 0.3) * tint)

	var head := Vector2(0, -26)
	draw_circle(head, 11.0, Color(0.96, 0.8, 0.65) * tint)
	if volkhv:
		# Довге русяве волосся й вінок із дубового листя
		draw_colored_polygon(PackedVector2Array([head + Vector2(-12, 8), head + Vector2(-11, -6), head + Vector2(0, -13), head + Vector2(11, -6), head + Vector2(12, 8), head + Vector2(7, -4), head + Vector2(-7, -4)]), Color(0.7, 0.55, 0.3) * tint)
		if job == "molfar":
			# Чорний гуцульський капелюх замість вінка
			draw_rect(Rect2(head + Vector2(-15, -12), Vector2(30, 4)), Color(0.1, 0.08, 0.08) * tint)
			draw_rect(Rect2(head + Vector2(-8, -20), Vector2(16, 9)), Color(0.1, 0.08, 0.08) * tint)
			draw_line(head + Vector2(-8, -13), head + Vector2(8, -13), Color(0.8, 0.2, 0.15) * tint, 2.0)
		else:
			var leaf := Color(0.35, 0.65, 0.25) if job != "perun_zhrets" else Color(0.8, 0.82, 0.9)
			draw_arc(head + Vector2(0, -4), 11.0, PI * 1.05, PI * 1.95, 10, leaf.darkened(0.2) * tint, 4.0)
			for i in 4:
				draw_circle(head + Vector2(-8 + i * 5.3, -12 + absf(i - 1.5) * 1.5), 2.2, leaf * tint)
		draw_circle(head + Vector2(side * 4, -1), 1.8, Color(0.1, 0.1, 0.1) * tint)
	elif peasant:
		# Звичайна чуприна, без вусів — ще зовсім молодий
		draw_colored_polygon(PackedVector2Array([head + Vector2(-11, -2), head + Vector2(-9, -11), head + Vector2(0, -14), head + Vector2(9, -11), head + Vector2(11, -2), head + Vector2(side * 3, -8)]), Color(0.45, 0.3, 0.15) * tint)
		draw_circle(head + Vector2(side * 4, -2), 1.8, Color(0.1, 0.1, 0.1) * tint)
	else:
		# Оселедець і вуса
		var chub := PackedVector2Array([
			head + Vector2(0, -11), head + Vector2(-side * 6, -17),
			head + Vector2(-side * 13, -14), head + Vector2(-side * 15, -6),
		])
		draw_polyline(chub, Color(0.25, 0.15, 0.08) * tint, 4.0, true)
		draw_circle(head + Vector2(side * 4, -2), 1.8, Color(0.1, 0.1, 0.1) * tint)
		draw_line(head + Vector2(side * 2, 4), head + Vector2(side * 10, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
		draw_line(head + Vector2(side * 2, 4), head + Vector2(-side * 5, 8), Color(0.3, 0.18, 0.08) * tint, 2.5)
	# Шапка (якщо вдягнена): хутряна кучма з кольоровим шликом за рідкістю (волхв — без шапки, у вінку)
	if equipment.has("head") and not volkhv:
		var hc: Color = Data.RARITY_COLORS[equipment["head"]["rarity"]]
		draw_colored_polygon(PackedVector2Array([
			head + Vector2(side * 6, -10), head + Vector2(-side * 4, -24), head + Vector2(-side * 14, -18), head + Vector2(-side * 8, -9)
		]), hc.darkened(0.25) * tint)
		draw_rect(Rect2(head + Vector2(-12, -14), Vector2(24, 8)), Color(0.25, 0.18, 0.12) * tint)
	if wolf_timer > 0.0:
		# Вовча подоба: вуха й сяйво очей
		draw_colored_polygon(PackedVector2Array([head + Vector2(-9, -8), head + Vector2(-12, -22), head + Vector2(-3, -11)]), Color(0.5, 0.5, 0.52) * tint)
		draw_colored_polygon(PackedVector2Array([head + Vector2(9, -8), head + Vector2(12, -22), head + Vector2(3, -11)]), Color(0.5, 0.5, 0.52) * tint)
		draw_circle(head + Vector2(side * 4, -2), 2.6, Color(1.0, 0.85, 0.2))
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
		"pishchal":
			# Пищаль: довгий ствол на ложі
			draw_line(hand - dir * 14.0, hand + dir * 18.0, Color(0.45, 0.28, 0.12), 6.0)
			draw_line(hand + dir * 4.0, hand + dir * 52.0, metal.darkened(0.35), 3.5)
			draw_circle(hand + dir * 52.0, 2.5, Color(0.2, 0.2, 0.22))
		"staff":
			# Посох: довга палиця з живим вогником на верхівці
			var top := hand + Vector2(0, -38)
			draw_line(hand + Vector2(0, 22), top, Color(0.45, 0.3, 0.15), 4.0)
			draw_circle(top, 6.0, metal.lerp(Color(1.0, 0.6, 0.2), 0.5))
			draw_circle(top, 10.0 + sin(walk_phase * 0.7 + mana) * 1.5, Color(1.0, 0.7, 0.3, 0.25 + 0.25 * (mana / maxf(max_mana, 1.0))))
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
			var rr := swing_reach if swing_reach > 0.0 else whirl_reach()
			draw_arc(Vector2.ZERO, rr * 0.85, 0.0, TAU, 64, Color(0.7, 0.9, 1.0, 0.55 * alpha), 22.0)
			draw_arc(Vector2.ZERO, rr * 0.6, 0.0, TAU, 64, Color(1, 1, 1, 0.4 * alpha), 8.0)
		else:
			var a0 := facing.angle() - attack_arc * 0.5
			draw_arc(Vector2.ZERO, attack_range * 0.75, a0, a0 + attack_arc, 24, Color(1, 1, 1, 0.6 * alpha), 16.0)

	if not statuses.is_empty():
		Status.draw_icons(self, -76.0)
	# Щит-оберіг і бойовий клич
	if ward_hp > 0.0:
		draw_circle(Vector2(0, -8), 36.0, Color(0.5, 0.75, 1.0, 0.12))
		draw_arc(Vector2(0, -8), 36.0, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.6), 2.5)
	if cry_timer > 0.0:
		draw_arc(Vector2(0, 16), 28.0, 0.0, TAU, 32, Color(1.0, 0.6, 0.25, 0.5), 3.0)
	if stina_timer > 0.0:
		draw_arc(Vector2(0, -6), 44.0, 0.0, TAU, 40, Color(0.95, 0.8, 0.45, 0.7), 4.0)
	if zamova_timer > 0.0:
		var za := walk_phase * 0.5 + zamova_timer * 6.0
		draw_line(Vector2(side * 12, -4), Vector2(side * 12, -4) + Vector2.from_angle(za) * 26.0, Color(0.6, 0.85, 1.0, 0.8), 2.0)
	if herb_timer > 0.0:
		for i in 3:
			var a := walk_phase * 0.3 + herb_timer * 2.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 22.0, -10 + sin(a) * 8.0), 2.5, Color(0.5, 1.0, 0.5, 0.8))

	# Блок: схрещена шабля перед козаком; заряд — золоте кільце, що наповнюється
	if blocking:
		var fa := facing.angle()
		var parry := block_time <= PARRY_WINDOW
		draw_arc(Vector2(0, -8), 34.0, fa - 0.9, fa + 0.9, 16, Color(1.0, 1.0, 0.8, 0.9) if parry else Color(0.7, 0.85, 1.0, 0.7), 6.0)
		var cr := charge_ratio()
		if cr > 0.0:
			var ready := block_time >= CHARGE_MIN
			var col := Color(1.0, 0.85, 0.3, 0.9) if ready else Color(1.0, 1.0, 1.0, 0.45)
			draw_arc(Vector2(0, 8), 40.0, -PI / 2, -PI / 2 + TAU * cr, 40, col, 4.0)
			if cr >= 1.0:
				draw_circle(Vector2(0, 8), 44.0, Color(1.0, 0.8, 0.3, 0.15 + 0.1 * sin(walk_phase * 3.0 + block_time * 20.0)))

	# Індикатор готовності Вихору
	if skill_timers["whirl"] <= 0.0:
		draw_arc(Vector2(0, 20), 26.0, 0.0, TAU, 32, Color(0.6, 0.85, 1.0, 0.5), 2.0)
