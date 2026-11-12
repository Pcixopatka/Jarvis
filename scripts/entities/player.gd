class_name Player
extends Node2D
## Козак — головний герой. Рух, бій, характеристики, вміння і перки.

signal died
signal leveled_up(level: int)

const Data := preload("res://scripts/data/data.gd")
const Status := preload("res://scripts/game/status.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const SkillInfo := preload("res://scripts/data/skill_info.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")
const Costumes := preload("res://scripts/data/costumes.gd")
const Pets := preload("res://scripts/data/pets.gd")
const EnchantService := preload("res://scripts/game/enchant_service.gd")
const Sets := preload("res://scripts/data/sets.gd")
const Valor := preload("res://scripts/data/valor.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")
const Power := preload("res://scripts/game/power.gd")
const NameService := preload("res://scripts/game/name_service.gd")
const HeroMechanic := preload("res://scripts/mechanics/hero_mechanic.gd")
const SkillMechanic := preload("res://scripts/mechanics/skill_mechanic.gd")
const ActMechanic := preload("res://scripts/mechanics/act_mechanic.gd")
const PowerMechanic := preload("res://scripts/mechanics/power_mechanic.gd")
const WeaponMechanic := preload("res://scripts/mechanics/weapon_mechanic.gd")
const ATTACK_SLOTS := 3  # кнопки атак праворуч (біля основного удару)
const BUFF_SLOTS := 5  # кнопки бафів знизу посередині

var combat: Combat

# --- Прогрес ---
var nick := ""  # ім'я героя (не name: це назва вузла); правила в NameService
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
var mana_potions := 0  # зілля наснаги
var petrified := 0.0  # скам'янів від погляду Вія: не рухається, не б'є, не ухиляється
var petrify_guard := 0.0  # щойно скам'янілого вдруге поспіль не скам'янити
var mana_potion_timer := 0.0
var resources := {"wood": 0, "iron": 0, "herbs": 0}  # для будівництва хутора
var trip_buffs := {}  # підсилення на час бою: {"strength": секунд, "antiplague": секунд, "inspired": секунд, "food": страва, "food_t": секунд}
var bag_bonus := 0  # від складу на хуторі (не зберігається — рахується з будівель)
var potion_bonus := 0  # від зілляварні
var xp_boost := 1.0  # ×2 за рекламу (виставляє Game, поки діє)
var festive := {}  # надбавки сезонного свята (ключі — Acts.HOLIDAY_PLAYER_KEYS; виставляє Game, у збереження не йде)
var klein := {}  # надбавки клейнодів роду: {"xp", "dmg", "hp", "crit", "cd"} (виставляє KleinodService, у збереження не йде)
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
var shot_mult := 1.0  # сила звичайного пострілу понад межу швидкості (див. RANGED_MIN_CD)
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
# Душі: торбинка героя (id душі -> скільки), поклик душ і сума бонусів душ у вдягнених речах
var souls := {}
var soul_luck := 0.0
var soul_found := 0
var soul_fx := {}
var leech_pool := 0.0  # скільки здоров'я вампіризм ще може повернути просто зараз
var art := {}  # бонуси артефактів, що лежать у торбі (ключ -> значення; рахує recalc)
var set_fx := {}  # бонуси наборів за вдягненим (ключ -> відсотки; рахує recalc, див. Sets)
## Вміння за даними (див. Classes.passive_fx і _act)
var skill_fx := {}  # пасивні вміння з "fx" у вузлі дерева: {ключ: відсотки} (рахує recalc)
var buffs := {}  # підсилення від умінь на час: id -> {"t": секунд, "fx": {ключ: відсотки}, "group": ""} (у збереження не йде)
var _fx := {}  # skill_fx разом із чинними підсиленнями
var _after_dodge_t := 0.0  # скільки ще діє бонус після перекиду (fx "dodge_dmg")
## Звитяги: поступ після стелі рівня (див. Valor)
var valor := 0  # скільки смуг звитяги заповнено: кожна дала очко (зберігається)
var valor_xp := 0  # досвід у поточній смузі (зберігається)
var valor_spent := {}  # лінія -> вкладені очки (зберігається)
var title_fx := {}  # бонуси іменних звитяг: {ключ: відсотки} (виставляє PerilService.apply, у збереження не йде)
var valor_fx := {}  # сума вкладених очок та іменних звитяг (рахує recalc)
var art_luck := {}  # доля трофея: бос -> скільки перемог поспіль без його артефакта (зберігається)
# Золоті речі: сили вдягнених (id сили -> числа) і їхній стан у бою
var u_pow := {}
var divine := {}  # вдягнені божі дари: {гніздо: id} (див. Divine), зберігається
var divine_fx := {}  # що вони дають: {"bag", "stats", "pickup", "shop", "fx"} (виставляє DivineService, у збереження не йде)
var bag_divine := 0  # місця в торбі від чумацької мажі (не зберігається)
var auto_buffs := true  # перемикач авто-бафів Німба (DivineService.auto_buff_tick), зберігається
var auto_buff_t := 0.0  # скільки ще чекати до наступної перевірки авто-бафів (не зберігається)
var pet := ""  # улюбленець, якого герой бере з собою (див. Pets), зберігається
var pet_fx := {}  # хист цього улюбленця: {"pickup"|"travel"|"xp"|"res": частка} (виставляє PetService, у збереження не йде)
var costume := ""  # вдягнене вбрання з крамниці: лише вигляд (див. Costumes), зберігається
var u_luck := 0  # лічильник Долі: скільки гідних босів поспіль не дали золота (зберігається)
var _u_proc := false  # сила золотої речі саме б'є (блискавка, грім, ядро): її удари інших сил не будять
var push := Vector2.ZERO  # поштовх від босів Башти (посвист, ланцюг)
var dodge_dir := Vector2.RIGHT
var dodge_hits := []
var invuln := 0.0
var swing_time := 0.0
var swing_duration := 0.18
var swing_full := false
# --- Комбо, блок, парирування, заряд ---
const COMBO_WINDOW := 1.0  # скільки чекає серія між ударами
const COMBO_MULT := [1.0, 1.15, 1.8]  # третій удар серії — сильний і широкий
## Стрілець не стріляє частіше за 10 разів на секунду: надлишок швидкості йде в силу пострілу (shot_mult).
## Так шкода за секунду та сама, а екран не тоне в кулях і гра встигає порахувати кожен постріл.
const RANGED_MIN_CD := 0.099
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
var hurt_flash := 0.0
var walk_phase := 0.0
var _foot := 0  # лічильник кроків для звуку ходи
var moving := false
var alive := true
var unbreak_ready := true
var berehynia_ready := true  # Берегиня (Загартування): раз на бій
var ladanka_ready := true  # Материна ладанка (божий дар): раз на бій
# --- Механіки героя (scripts/mechanics/: skill/, act/, power/, weapon/; див. hero_mechanic.gd) ---
var _mechs := {}  # посилання → об'єкт механіки вміння, шаблону, сили чи зброї (раз створений, живе з героєм)
var _hooks: Array = HeroMechanic.empty_hooks()  # хук подій → механіки, що його написали, у черзі order()
var _by_skill := {}  # id вивченого вміння → його механіка (null — уміння без власної дії)
var _acts := {}  # шаблон дії → його механіка
var _probes := {}  # id уміння → механіка без стану для картки й перезарядки невивченого
var weapon_mech  # механіка зброї в руках


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
	return Data.INVENTORY_SIZE + bag_bonus + bag_divine


func bag_full() -> bool:
	return inventory.size() >= bag_size()


func potion_max() -> int:
	return Data.POTION_MAX + potion_bonus + pk("h_flask") + int(art.get("potion_max", 0))


func mana_potion_max() -> int:
	return Data.MANA_POTION_MAX + (1 if is_volkhv() else 0) + int(art.get("mana_potion_max", 0))


## Волхв чи його спеціалізація (за класом, а не за зброєю в руках).
func is_volkhv() -> bool:
	return Classes.is_volkhv_line(job)


## Додає річ у торбу. Повертає false, якщо місця немає.
func add_item(item: Dictionary, force: bool = false) -> bool:
	if not item.has("uid"):
		assign_uid(item)
	if bag_full() and not force:
		return false
	inventory.append(item)
	if Artifacts.is_artifact(item):
		recalc_gear()  # артефакт діє з торби одразу
	return true


## Чи може цей клас користуватися річчю (зброя обмежена класом).
func can_use(item: Dictionary) -> bool:
	if Artifacts.is_artifact(item):
		return false  # артефакт не вдягають: він діє з торби
	if item.get("slot", "") != "weapon":
		return true
	return item.get("type", "") in Classes.info(job)["weapons"]


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
			recalc_gear()
			return true
	return false


## Сила героя з нинішнім спорядженням (для порівняння речей): Power.score і надбавка за золоті речі.
func gear_score() -> float:
	var s: float = Power.score(self)
	for slot in equipment:
		if Uniques.is_unique(equipment[slot]):
			s *= 1.0 + Power.UNIQUE_WORTH
	return s


var _gain_cache := {}  # хеш речі -> приріст сили від неї (gain_from); скидає recalc
var _gain_sim := false  # іде примірка: recalc усередині неї кешу не скидає

## На скільки зміниться сила героя, якщо вдягнути цю річ замість тієї, що зараз у її клітинці.
## Частка: 0.05 — на 5% сильніший, від'ємна — слабший. Нічого не міняє: приміряє й повертає як було.
func gain_from(item: Dictionary) -> float:
	if item.is_empty() or not can_use(item) or not Data.slots().has(item.get("slot", "")):
		return 0.0
	var slot: String = item["slot"]
	if equipment.has(slot) and equipment[slot].get("uid", -1) == item.get("uid", -2):
		return 0.0
	# Примірка коштує двох перерахунків героя, а екрани питають про кожну річ торби після кожного дотику.
	# Тож відповідь пам'ятаємо, доки не зміниться сам герой (recalc) чи ця річ (її хеш).
	var key: int = item.hash()
	if _gain_cache.has(key):
		return float(_gain_cache[key])
	_gain_sim = true
	var hp0 := hp
	var mana0 := mana
	var before := gear_score()
	var had: bool = equipment.has(slot)
	var old: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	recalc()
	var after := gear_score()
	if had:
		equipment[slot] = old
	else:
		equipment.erase(slot)
	recalc()
	hp = hp0  # примірка не лікує й не ранить
	mana = mana0
	_gain_sim = false
	var gain: float = after / maxf(before, 0.001) - 1.0
	_gain_cache[key] = gain
	return gain


## Найкращі речі з торби для кожної клітинки, якщо вони сильніші за вдягнене: {клітинка: річ}.
func best_upgrades() -> Dictionary:
	var best := {}
	var best_gain := {}
	for it in inventory:
		var g := gain_from(it)
		if g > Power.MIN_GAIN and g > float(best_gain.get(it["slot"], 0.0)):
			best_gain[it["slot"]] = g
			best[it["slot"]] = it
	return best


## Вдягнути найкраще з торби в кожну клітинку. Повертає, скільки речей вдягнено.
func equip_best() -> int:
	var n := 0
	for pass_i in 3:  # речі впливають одна на одну, тож після заміни перевіряємо ще раз
		var ups := best_upgrades()
		if ups.is_empty():
			break
		for slot in ups:
			if equip(int(ups[slot]["uid"])):
				n += 1
	return n


func unequip(uid: int) -> bool:
	if bag_full():
		return false
	for slot in equipment:
		if equipment[slot]["uid"] == uid:
			inventory.append(equipment[slot])
			equipment.erase(slot)
			recalc_gear()
			return true
	return false


func remove_from_bag(uid: int) -> Dictionary:
	for i in inventory.size():
		if inventory[i]["uid"] == uid:
			var it: Dictionary = inventory[i]
			inventory.remove_at(i)
			if Artifacts.is_artifact(it):
				recalc_gear()  # артефакт покинув торбу й більше не діє
			return it
	return {}


func add_gold(v: int) -> void:
	gold += maxi(v, roundi(v * gold_mult))


## Заточка: повертає "ok", "fail", "down", "nogold" або "max".
## cost_mult/chance_bonus — бонуси кузні хутора; safe — безпечна заточка (рівень не падає).
func sharpen(uid: int, cost_mult: float = 1.0, chance_bonus: float = 0.0, safe: bool = false) -> String:
	if Artifacts.is_artifact(find_item(uid)):
		return ""
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
	u_pow = {}
	var pow_tier := {}
	for slot in equipment:
		var st := Data.item_stats(equipment[slot])
		for id in st:
			_eq[id] = _eq.get(id, 0.0) + st[id]
		# сила золотої речі; дві однакові сили не складаються — діє сильніша
		var it: Dictionary = equipment[slot]
		if Uniques.is_unique(it):
			var pid := Uniques.power_id(it)
			var t := Uniques.tier(it)
			if t > int(pow_tier.get(pid, 0)):
				pow_tier[pid] = t
				u_pow[pid] = Uniques.params(str(it["unique"]))
	weapon_type = equipment["weapon"]["type"] if equipment.has("weapon") else "sabre"
	weapon = Data.weapon(weapon_type)


func eq(id: String) -> float:
	return _eq.get(id, 0.0)


# ================= Збереження =================

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "xp_next": xp_next, "stats": stats, "skills": skills, "perks": perks,
		"stat_points": stat_points, "skill_points": skill_points, "perk_points": perk_points,
		"gold": gold, "inventory": inventory, "equipment": equipment, "next_uid": next_uid, "potions": potions, "mana_potions": mana_potions,
		"resources": resources, "trip_buffs": trip_buffs, "rank": rank, "job": job, "job_level": job_level, "job_xp": job_xp,
		"stat_gifts": stat_gifts, "skill_gifts": skill_gifts, "stones": stones, "panel": panel, "costume": costume, "pet": pet, "divine": divine, "auto_buffs": auto_buffs, "u_luck": u_luck, "art_luck": art_luck,
		"souls": souls, "soul_luck": soul_luck, "soul_found": soul_found,
		"valor": valor, "valor_xp": valor_xp, "valor_spent": valor_spent, "nick": nick}


func from_dict(d: Dictionary) -> void:
	# лише ті поля, які герой сам і зберігає: чужий ключ зі зіпсованого чи підробленого файла
	# не має міняти вузол (позицію, скрипт, видимість)
	var known := to_dict()
	for k in d:
		if known.has(k) and k != "nick":
			set(k, d[k])
	# ім'я зі збереження проходить ті самі правила, що й ввід: зіпсоване чи недопустиме стає порожнім
	nick = NameService.from_save(d.get("nick", ""))
	auto_buffs = bool(d.get("auto_buffs", true))  # старе збереження без перемикача: авто-бафи ввімкнено
	# Ціна рівня могла змінитися між версіями: частка пройденого шляху до наступного рівня лишається тією самою
	var want: int = Data.xp_for_level(level)
	if xp_next != want:
		xp = int(float(xp) / maxf(1.0, float(xp_next)) * want)
		xp_next = want
	# Старі збереження могли набрати звитяг понад усі лінії: зайве опускається до стелі, вкладені очки лишаються
	if valor >= Valor.max_valor():
		valor = Valor.max_valor()
		valor_xp = mini(valor_xp, valor_next())
	_normalize_buffs()
	_refund_foreign_skills()
	recalc()
	hp = max_hp
	mana = max_mana


## Клас могли перенести в іншу гілку (Самопальник перейшов від Козака до Стрільця).
## Вміння, що лишилися поза дорогою героя, вертаються очками: їх можна вкласти в нові дерева.
## Подаровані сюжетом ранги (skill_gifts) очок не вертають, а вміння Загартування це не зачіпає.
func _refund_foreign_skills() -> int:
	if not Classes.has_class(job):
		return 0
	var own := {}
	for c in Classes.lineage(job):
		for b in Classes.tree(c):
			for n in b["nodes"]:
				own[n["id"]] = true
	var back := 0
	for id in skills.keys():
		if own.has(id) or Classes.find_node(str(id)).is_empty():
			continue
		back += maxi(0, int(skills[id]) - int(skill_gifts.get(id, 0)))
		skills.erase(id)
		skill_gifts.erase(id)
	skill_points += back
	if back > 0 and Classes.is_strilets_line(job) and sk("strila") <= 0:
		# замість подарованого козацького вміння стрілець має своє перше: «Влучну стрілу»
		skills["strila"] = 1
		skill_gifts["strila"] = 1
	return back


# ---------- Підсилення на час бою: страви з казана, зілля сили, натхнення ----------

## Старі збереження тримали підсилення «на один похід» без часу — даємо їм повний строк.
func _normalize_buffs() -> void:
	for key in trip_buffs.keys():
		if key in ["food", "food_t"]:
			continue
		if typeof(trip_buffs[key]) == TYPE_BOOL:
			trip_buffs[key] = Data.INSPIRED_TIME if key == "inspired" else Data.BREW_TIME
	if trip_buffs.has("food") and not trip_buffs.has("food_t"):
		trip_buffs["food_t"] = Data.MEAL_TIME
	elif trip_buffs.has("food_t") and not trip_buffs.has("food"):
		trip_buffs.erase("food_t")


## Скільки секунд бою ще діє підсилення ("food" — страва).
func buff_left(key: String) -> float:
	if not trip_buffs.has(key):
		return 0.0
	return float(trip_buffs.get("food_t", 0.0)) if key == "food" else float(trip_buffs[key])


## Чи влізе ще одна порція часу під стелю в годину.
func buff_fits(key: String, secs: float) -> bool:
	return buff_left(key) + secs <= Data.BUFF_CAP + 0.5


## Випити зілля «на час»: нова порція додає час до стелі.
func add_buff(key: String, secs: float) -> void:
	trip_buffs[key] = minf(Data.BUFF_CAP, buff_left(key) + secs)
	recalc()


## З'їсти страву: та сама додає час, інша замінює попередню.
func eat(recipe: String, secs: float) -> void:
	var left := buff_left("food") if str(trip_buffs.get("food", "")) == recipe else 0.0
	trip_buffs["food"] = recipe
	trip_buffs["food_t"] = minf(Data.BUFF_CAP, left + secs)
	recalc()


## Минає час бою. Повертає те, що щойно скінчилось: ключі зілля або "food:<страва>".
func tick_buffs(delta: float) -> Array:
	var gone := []
	for key in trip_buffs.keys():
		if key == "food":
			continue
		trip_buffs[key] = float(trip_buffs[key]) - delta
		if float(trip_buffs[key]) <= 0.0:
			gone.append(key)
	var out := []
	for key in gone:
		trip_buffs.erase(key)
		if key == "food_t":
			out.append("food:" + str(trip_buffs.get("food", "")))
			trip_buffs.erase("food")
		else:
			out.append(key)
	if not out.is_empty():
		var part := hp / maxf(1.0, max_hp)
		recalc()
		hp = minf(hp, maxf(1.0, max_hp * part)) if alive else hp
	return out


func revive() -> void:
	statuses.clear()
	if not buffs.is_empty():
		buffs.clear()
		recalc()
	mana = max_mana
	for m in _hooks[HeroMechanic.ON_REVIVE]:
		m.on_revive()
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
	return Classes.info(job)


func class_name_ua() -> String:
	return class_info()["name"]


func job_max() -> int:
	return int(class_info()["job_max"])


func job_next() -> int:
	return Classes.job_xp_for(int(class_info()["tier"]), job_level)


## Чи в руках зброя чарівника (сила від Характерництва): кнопка «Блок» тоді зветься «Оберіг».
func is_mage() -> bool:
	return Data.weapon_stat(weapon_type) == "spi"


## Чи можна вже змінити клас (досить майстерності й є куди рости): «change_at» запису класу.
func can_change_class() -> bool:
	var ci := class_info()
	return not ci["next"].is_empty() and job_level >= int(ci.get("change_at", 999))


## Зміна класу: майстерність з 1, вивчене лишається, невитрачені очки — теж.
func change_class(cls: String) -> bool:
	if not Classes.has_class(cls) or cls == job:
		return false
	var was_volkhv := is_volkhv()
	job = cls
	job_level = 1
	job_xp = 0
	Data.weapon_pool = Classes.info(job)["weapons"]
	recalc()
	mana = max_mana
	if is_volkhv() and not was_volkhv:
		mana_potions = maxi(mana_potions, 2)  # волхви на посвяті дають учневі два зілля наснаги
	return true


## Значення характеристики з урахуванням перків і спорядження.
func stat(id: String) -> int:
	var base: int = stats[id] + 2 * pk("sich") + int(eq(id))
	var wings: float = float(divine_fx.get("stats", 0.0))  # Крила Рарога: частка до всіх характеристик
	return base if wings <= 0.0 else int(round(base * (1.0 + wings)))


func _bonus(id: String) -> int:
	return stat(id) - Data.STAT_BASE


## Перерахунок після зміни спорядження. Частка здоров'я лишається тією самою: зняти й знову вдягти
## річ із запасом здоров'я посеред бою більше не лікує (раніше кожне таке коло додавало різницю).
func recalc_gear() -> void:
	var part := hp / maxf(1.0, max_hp)
	recalc()
	if alive and not _gain_sim:
		hp = minf(hp, maxf(1.0, max_hp * part))


func recalc() -> void:
	if not _gain_sim:
		_gain_cache.clear()  # герой змінився: старі примірки речей більше не чинні
	var old_max := max_hp
	_calc_equipment()
	art = Artifacts.mods(inventory)
	soul_fx = SoulService.fx_of(self)
	set_fx = Sets.fx(equipment)
	Sets.worn = Sets.count(equipment)
	valor_fx = Valor.fx(valor_spent, title_fx)
	skill_fx = Classes.passive_fx(job, skills, weapon_type)
	_fx = skill_fx.duplicate()
	var ench: Dictionary = EnchantService.fx_of_equipment(equipment)  # зачарування вдягнених речей
	for k in ench:
		_fx[k] = float(_fx.get(k, 0.0)) + float(ench[k])
	var dfx: Dictionary = divine_fx.get("fx", {})  # бойові показники божих дарів
	for k in dfx:
		_fx[k] = float(_fx.get(k, 0.0)) + float(dfx[k])
	for bid in buffs:
		for k in buffs[bid]["fx"]:
			_fx[k] = float(_fx.get(k, 0.0)) + float(buffs[bid]["fx"][k])
	var s_str := _bonus("str")
	var s_agi := _bonus("agi")
	var s_vit := _bonus("vit")
	var s_spi := _bonus("spi")

	# Силу удару дає та характеристика, яку каже запис зброї («stat»: посох — Характерництво, стрільці — Спритність)
	var wstat := Data.weapon_stat(weapon_type)
	var s_main := s_spi if wstat == "spi" else (s_agi if wstat == "agi" else s_str)
	var wm = _weapon_for(weapon_type)
	damage = (20.0 + eq("flat_dmg")) * weapon["dmg"] * (1.0 + 0.06 * s_main + 0.08 * pk("sharp") + 0.08 * pk("porokh") + 0.03 * pk("h_hand") + eq("dmg_pct") / 100.0)
	if wm.bits & (1 << HeroMechanic.DAMAGE_MULT):
		damage *= wm.damage_mult()  # свій множник зброї (Майстер булави)
	if trip_buffs.has("strength"):
		damage *= 1.3
	if trip_buffs.has("inspired"):
		damage *= 1.15  # дума кобзаря біля вогнища
	var meal: String = str(trip_buffs.get("food", ""))  # страва з казана (див. OutdoorService)
	if meal == "pechenia":
		damage *= 1.1
	plague_immune = trip_buffs.has("antiplague")
	attack_range = 95.0 * weapon["range"] * (1.0 + 0.08 * pk("reach"))
	if weapon.has("shot_range"):
		attack_range = float(weapon["shot_range"])  # зброя дальнього бою б'є на сталу відстань
	attack_arc = deg_to_rad((130.0 + 20.0 * pk("cleave")) * weapon["arc"])
	var aspd_agi: float = Data.soft_agi_aspd(s_agi) if Data.is_agi(weapon_type) else float(s_agi)
	attack_cooldown = 0.42 * weapon["cd"] / (1.0 + 0.04 * aspd_agi + 0.06 * pk("fury") + 0.04 * pk("h_fast") + eq("aspd") / 100.0)
	if wm.bits & (1 << HeroMechanic.CD_MULT):
		attack_cooldown /= wm.cd_mult()  # свій дільник зброї (Швидке заряджання пищалі)
	attack_cooldown /= (1.0 + float(soul_fx.get("aspd", 0.0))) * (1.0 + float(set_fx.get("aspd", 0.0)) / 100.0) * (1.0 + fx("aspd") / 100.0)
	shot_mult = 1.0
	if Data.is_agi(weapon_type) and attack_cooldown < RANGED_MIN_CD:
		shot_mult = RANGED_MIN_CD / attack_cooldown
		attack_cooldown = RANGED_MIN_CD
	if not Data.is_ranged(weapon_type):
		attack_range *= 1.0 + fx("range") / 100.0
	crit_chance = minf(0.8, 0.05 + 0.015 * s_agi + 0.05 * pk("luck") + 0.04 * pk("oko") + 0.05 * pk("vluchnist") + eq("crit") / 100.0 + float(festive.get("crit", 0.0)) + float(klein.get("crit", 0.0)) + float(set_fx.get("crit", 0.0)) / 100.0 + fx("crit") / 100.0)
	crit_mult = (3.0 if pk("deadly") > 0 else 2.0) + 0.25 * pk("h_crit") + float(soul_fx.get("crit_dmg", 0.0)) + float(set_fx.get("crit_dmg", 0.0)) / 100.0 + fx("crit_dmg") / 100.0
	lifesteal = 0.02 * pk("thirst") + 0.03 * pk("wolf_blood") + eq("lifesteal") / 100.0 + fx("lifesteal") / 100.0

	max_hp = (100.0 + 12.0 * s_vit + 15.0 * pk("tough") + eq("hp")) * (1.0 + 0.06 * pk("hardy") + 0.08 * pk("zaporizka_vytryvalist") + 0.04 * pk("h_body")) * float(class_info().get("hp_mult", 1.0))
	damage *= float(class_info().get("dmg_mult", 1.0)) * (1.0 + float(festive.get("dmg", 0.0))) * (1.0 + float(klein.get("dmg", 0.0))) * (1.0 + float(soul_fx.get("dmg", 0.0)))
	damage *= (1.0 + float(set_fx.get("dmg", 0.0)) / 100.0) * (1.0 + float(valor_fx.get("dmg", 0.0)) / 100.0) * (1.0 + fx("dmg") / 100.0)
	if meal == "kulish":
		max_hp *= 1.15
	elif meal == "borshch":
		max_hp *= 1.1
	max_hp *= (1.0 + float(festive.get("hp", 0.0))) * (1.0 + float(klein.get("hp", 0.0))) * (1.0 + float(soul_fx.get("hp", 0.0))) * (1.0 + float(set_fx.get("hp", 0.0)) / 100.0) * (1.0 + float(valor_fx.get("hp", 0.0)) / 100.0) * (1.0 + fx("hp") / 100.0)
	armor = clampf(0.01 * s_vit + 0.05 * pk("ward") + 0.03 * pk("iron_skin") + 0.02 * pk("h_skin") + eq("armor") / 100.0 + float(festive.get("armor", 0.0)) + float(set_fx.get("armor", 0.0)) / 100.0 + fx("armor") / 100.0, 0.0, Data.ARMOR_CAP)
	regen = 0.6 * pk("regen") + 1.0 * pk("zhyve_slovo") + 0.5 * pk("h_blood") + eq("regen") + (1.0 if meal == "yushka" else 0.0) + max_hp * float(festive.get("regen", 0.0))
	dodge_cooldown = 1.2 * (1.0 - 0.12 * pk("roll")) * (1.0 - 0.15 * pk("stryvok")) * (1.0 - 0.1 * pk("h_roll")) * (1.0 - float(art.get("dodge_cd", 0.0))) * (1.0 - float(soul_fx.get("dodge_cd", 0.0)))
	regen += max_hp * fx("regen_pct") / 100.0
	dodge_cooldown *= maxf(0.4, 1.0 - fx("dodge_cd") / 100.0)
	thorns = 0.25 * pk("thorns") + fx("thorns") / 100.0
	varenyk_bonus = pk("varenyk")

	speed = 260.0 * (1.0 + 0.015 * s_agi + 0.05 * pk("boots") + eq("speed") / 100.0) * (1.0 + float(soul_fx.get("speed", 0.0))) * (1.0 + float(set_fx.get("speed", 0.0)) / 100.0) * (1.0 + fx("speed") / 100.0)
	pickup_radius = 120.0 * (1.0 + 0.25 * pk("purse") + eq("pickup") / 100.0 + float(art.get("pickup", 0.0))) * (1.0 + float(soul_fx.get("pickup", 0.0))) * (1.0 + fx("pickup") / 100.0) * (1.0 + float(pet_fx.get("pickup", 0.0))) * (1.0 + float(divine_fx.get("pickup", 0.0)))
	xp_mult = 1.0 + 0.1 * pk("kobzar") + eq("xp") / 100.0 + (0.15 if trip_buffs.has("inspired") else 0.0) + (0.1 if meal == "borshch" else 0.0) + float(festive.get("xp", 0.0)) + float(klein.get("xp", 0.0)) + float(art.get("xp", 0.0)) + float(pet_fx.get("xp", 0.0)) + float(divine_fx.get("xp", 0.0))
	gold_mult = 1.0 + 0.08 * pk("h_gold") + eq("gold") / 100.0 + float(festive.get("gold", 0.0)) + float(art.get("gold", 0.0)) + float(soul_fx.get("gold", 0.0)) + float(valor_fx.get("gold", 0.0)) / 100.0 + float(divine_fx.get("gold", 0.0))
	skill_cd_mult = maxf(0.3, (1.0 - 0.06 * pk("focus") - 0.05 * pk("h_mind") - eq("skill_cd") / 100.0) / (1.0 + 0.04 * Data.soft_spi(s_spi)) * (1.0 - float(festive.get("cd", 0.0))) * (1.0 - float(klein.get("cd", 0.0))))
	skill_cd_mult = maxf(0.3, skill_cd_mult * (1.0 - float(soul_fx.get("cd", 0.0))) * (1.0 - float(set_fx.get("cd", 0.0)) / 100.0) * (1.0 - fx("cd") / 100.0))
	skill_power = (1.0 + 0.05 * Data.soft_spi(s_spi) + 0.1 * pk("spirit") + 0.05 * pk("h_spirit") + eq("skill_power") / 100.0 + float(festive.get("skill", 0.0))) * (1.0 + float(soul_fx.get("skill", 0.0))) * (1.0 + float(set_fx.get("skill", 0.0)) / 100.0) * (1.0 + float(valor_fx.get("skill", 0.0)) / 100.0) * (1.0 + fx("skill") / 100.0)
	var ci := class_info()
	# Грозові й карпатські чари б'ють по кілька цілей і частіше за інші, тож сила вмінь у цих класів менша:
	# так справжня шкода за секунду виходить як у решти (tools/dps_probe.gd).
	skill_power *= float(ci.get("skill_mult", 1.0))
	var old_mana := max_mana
	max_mana = (40.0 + 5.0 * s_spi) * float(ci["mana_mult"]) * (1.0 + 0.2 * pk("deep_well") + 0.1 * pk("steel_will")) * (1.0 + fx("mana") / 100.0)
	mana_regen = (2.0 + 0.25 * s_spi) * float(ci["regen_mult"]) * (1.0 + 0.25 * pk("mana_flow") + 0.1 * pk("h_breath")) * (1.3 if meal == "yushka" else 1.0) * (1.0 + float(festive.get("mana", 0.0))) * (1.0 + fx("mana_regen") / 100.0)
	if max_mana > old_mana:
		mana += max_mana - old_mana
	mana = minf(mana, max_mana)

	if max_hp > old_max:
		hp += max_hp - old_max
	hp = minf(hp, max_hp)
	if not _gain_sim:
		_sync_mechs()


## Бонус умінь за даними: пасивні вузли дерева разом із чинними підсиленнями (відсотки).
func fx(key: String) -> float:
	return float(_fx.get(key, 0.0))


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


## Вчити можна вміння своєї дороги: нинішнього класу й тих, які герой уже пройшов
## (Селянин → Козак → Запорожець). Інакше очки, зароблені понад дерево останнього класу, нікуди подіти.
func in_class_tree(id: String) -> bool:
	for c in Classes.lineage(job):
		if Classes.find_node(id, c).get("class", "") == c:
			return true
	return false


## Скільки рангів дерева класу вже вивчено і скільки їх усього: [вивчено, усього].
func tree_progress(cls: String) -> Array:
	var have := 0
	var total := 0
	for b in Classes.tree(cls):
		for n in b["nodes"]:
			have += mini(sk(n["id"]), int(n["max"]))
			total += int(n["max"])
	return [have, total]


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
	for tier in Data.perk_branches()[bi]["tiers"]:
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
		_add_valor_xp(gained)
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


## Досвід на останньому рівні наповнює смугу звитяги; заповнена смуга дає очко (див. Valor).
## На найбільшій звитязі (Valor.max_valor) очок більше нема: смуга лише наповнюється до краю.
func _add_valor_xp(gained: int) -> void:
	valor_xp += gained
	while valor_xp >= valor_next() and valor < Valor.max_valor():
		valor_xp -= valor_next()
		valor += 1
		if _in_combat():
			Audio.play("levelup", 0.0)
			combat.fx.ring(global_position, Color(1.0, 0.7, 0.35), 32, 420, 6, 0.6)
		Events.banner.emit("Звитяга %d!\nНове очко: «Персонаж», вкладка «Загартування»" % valor, Color(1.0, 0.8, 0.4))
	if valor >= Valor.max_valor():
		valor_xp = mini(valor_xp, valor_next())


## Скільки досвіду вміщає нинішня смуга звитяги.
func valor_next() -> int:
	return Valor.bar(valor)


## Вільні очки звитяги.
func valor_points() -> int:
	return maxi(0, valor - Valor.spent_total(valor_spent))


func can_add_valor(line: String) -> bool:
	return Valor.is_line(line) and valor_points() > 0 and int(valor_spent.get(line, 0)) < Valor.LINE_MAX


## Вкласти очко звитяги в лінію.
func add_valor(line: String) -> bool:
	if not can_add_valor(line):
		return false
	valor_spent[line] = int(valor_spent.get(line, 0)) + 1
	recalc()
	return true


## Удача на рідкісну здобич від звитяг: множник шансу золота, артефактів, душ і речей наборів.
func loot_luck() -> float:
	return 1.0 + float(valor_fx.get("luck", 0.0)) / 100.0


## Ціна смерті: забирає частку досвіду поточного рівня (не нижче нуля, рівень не падає). Повертає, скільки втрачено.
## mult — у скільки разів ціна вища за звичайну (надважкі печери: Peril.DEATH_XP_MULT).
func death_xp_loss(mult: float = 1.0) -> int:
	if level < Data.DEATH_XP_FROM:
		return 0
	mult *= 1.0 - clampf(float(art.get("death_xp", 0.0)), 0.0, 0.9)  # «Ланка велетового ланцюга»
	if level >= Classes.BASE_LEVEL_MAX:
		# на останньому рівні смерть забирає ту саму частку зі смуги звитяги; зароблені очки не зникають
		var gone: int = mini(valor_xp, ceili(valor_next() * Data.DEATH_XP_LOSS * mult))
		valor_xp -= gone
		return gone
	var lost: int = mini(xp, ceili(xp_next * Data.DEATH_XP_LOSS * mult))
	xp -= lost
	return lost


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
	leech_pool = minf(max_hp * Data.LIFESTEAL_MAX_HPS * 2.0, leech_pool + max_hp * Data.LIFESTEAL_MAX_HPS * delta)
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
	mana_potion_timer = maxf(0.0, mana_potion_timer - delta)
	petrified = maxf(0.0, petrified - delta)
	petrify_guard = maxf(0.0, petrify_guard - delta)
	for id in skill_timers:
		skill_timers[id] = maxf(0.0, skill_timers[id] - delta)
	_after_dodge_t = maxf(0.0, _after_dodge_t - delta)
	if not buffs.is_empty():
		_tick_buffs(delta)
	invuln = maxf(0.0, invuln - delta)
	swing_time = maxf(0.0, swing_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)

	for m in _hooks[HeroMechanic.TICK_LATE]:
		m.tick_late(delta)

	var input_vec: Vector2 = combat.get_move_input()
	if petrified > 0.0:
		input_vec = Vector2.ZERO
	moving = false
	if dodge_time_left > 0.0:
		dodge_time_left -= delta
		position += dodge_dir * speed * 3.2 * delta
		if pk("dash_strike") > 0:
			_dash_strike()
	else:
		var step: Vector2 = input_vec * speed * (0.45 if blocking else 1.0) * Status.speed_mult(self)
		for m in _hooks[HeroMechanic.SPEED_MULT]:
			step *= m.speed_mult()
		position += step * delta
		if push.length() > 1.0:
			position += push * delta
			push = push.move_toward(Vector2.ZERO, 2600.0 * delta)
		if input_vec.length() > 0.1:
			moving = true
			if swing_time <= 0.0:
				facing = input_vec.normalized()
			walk_phase += delta * 14.0
			var foot := int(walk_phase / PI)  # кожен півкрок анімації — один крок
			if foot != _foot:
				_foot = foot
				Audio.play("step", 0.15)

	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)

	if attack_held and attack_timer <= 0.0 and not blocking and petrified <= 0.0:
		attack()
	queue_redraw()


## Блок: натиснув — щит догори (перша мить — парирування); тримаєш — заряджається удар;
## відпустив після CHARGE_MIN — заряджений удар.
func _update_block(delta: float) -> void:
	if petrified > 0.0:
		blocking = false  # камінь не боронить себе
		block_time = 0.0
		return
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


## Заряджений удар: сила 0..1. Як б'є — каже механіка зброї в руках (weapon/<вид>.gd): зблизька повний
## заряд б'є довкола і приголомшує нечисть, посох кидає вогняну кулю, пищаль і лук — важкий постріл.
func charged_strike(power: float) -> void:
	if not alive:
		return
	_weapon_for(weapon_type).charged(power)


## Ідеальне парирування: ворожий удар зірвано, ворог приголомшений, у відповідь — критичний удар.
func _parry(source) -> void:
	invuln = 0.45
	blocking = false
	block_cd = 0.15
	combo_step = 2  # наступний удар — завершальний
	combo_timer = COMBO_WINDOW
	Audio.play("clash", 0.05)
	combat.hitstop(0.12)
	combat.fx.ring(global_position, Color(1.0, 0.95, 0.6), 20, 120, 5, 0.3)
	combat.float_text(global_position + Vector2(0, -70), "Парирування!" if source != null else "Відбито!", Color(1.0, 0.95, 0.5))
	Events.parried.emit()
	if pk("h_parry") > 0:
		heal(max_hp * 0.04 * pk("h_parry"), false)
	if fx("parry_heal") > 0.0:
		heal(max_hp * fx("parry_heal") / 100.0, false)
	if source != null and is_instance_valid(source) and not source.dead:
		source.windup = 0.0
		source.stun = maxf(source.stun, 0.6 if source.is_boss else 1.5)
		var to: Vector2 = source.global_position - global_position
		hit(source, damage * 1.5 * crit_mult * (1.0 + fx("parry_dmg") / 100.0), to.normalized() * 400.0, true)


# ================= Бій =================

## Щокадру: таймери, стан і дії в часі вмінь і сил героя (їхні механіки, хук tick).
func _tick_effects(delta: float) -> void:
	for m in _hooks[HeroMechanic.TICK]:
		m.tick(delta)


func _roll(mult: float) -> Array:
	var crit := randf() < crit_chance
	if not _hooks[HeroMechanic.ON_ROLL].is_empty():
		# механіки можуть зробити удар критичним і сильнішим (удар із Тіні, Пластунський випад)
		var r := [mult, crit]
		for m in _hooks[HeroMechanic.ON_ROLL]:
			m.on_roll(r)
		mult = r[0]
		crit = r[1]
	var bonus := 0.0
	for m in _hooks[HeroMechanic.DAMAGE_BONUS]:
		bonus += m.damage_bonus()
	var dmg := damage * mult * (crit_mult if crit else 1.0) * randf_range(0.9, 1.1) * (1.0 + bonus)
	dmg *= Status.damage_mult(self)
	for m in _hooks[HeroMechanic.DAMAGE_DEALT]:
		dmg = m.damage_dealt(dmg)
	if _after_dodge_t > 0.0:
		dmg *= 1.0 + fx("dodge_dmg") / 100.0
	if pk("nevhamovnyi") > 0:
		dmg *= 1.0 + 0.15 * pk("nevhamovnyi") * clampf(1.0 - hp / maxf(max_hp, 1.0), 0.0, 1.0)
	return [dmg, crit]


## Удар по ворогу з урахуванням вампіризму.
func hit(e, dmg: float, kb: Vector2, crit: bool) -> void:
	if e.dead:
		return
	if pk("h_execute") > 0 and e.hp < e.max_hp * 0.3:
		dmg *= 1.2
	var hp_before: float = maxf(0.0, e.hp)
	if not art.is_empty():
		dmg *= 1.0 + float(art.get("dmg", 0.0))  # «Уламок чорного сонця»
		if e.is_boss:
			dmg *= 1.0 + float(art.get("boss_dmg", 0.0))
		elif e.elite or e.bounty_id > 0:
			dmg *= 1.0 + float(art.get("elite_dmg", 0.0))
	if not soul_fx.is_empty():
		if e.hp < e.max_hp * 0.3:
			dmg *= 1.0 + float(soul_fx.get("execute", 0.0))
		if e.is_boss or e.elite:
			dmg *= 1.0 + float(soul_fx.get("big_dmg", 0.0))
	if not set_fx.is_empty() and (e.is_boss or e.elite):
		dmg *= 1.0 + float(set_fx.get("big_dmg", 0.0)) / 100.0
	if not _fx.is_empty():
		if e.is_boss or e.elite:
			dmg *= 1.0 + fx("big_dmg") / 100.0
		if e.hp < e.max_hp * 0.3:
			dmg *= 1.0 + fx("execute") / 100.0
		elif e.hp > e.max_hp * 0.9:
			dmg *= 1.0 + fx("opener") / 100.0
		if not e.statuses.is_empty():
			dmg *= 1.0 + fx("status_dmg") / 100.0
		if e.stun > 0.0:
			dmg *= 1.0 + fx("stun_dmg") / 100.0
	e.take_damage(dmg, kb, crit)
	if not soul_fx.is_empty():
		_soul_on_hit(e, dmg)
	if not _fx.is_empty():
		_skill_on_hit(e, dmg)
	for m in _hooks[HeroMechanic.ON_HIT]:
		m.on_hit(e, dmg, crit, hp_before)
	# вампіризм лікує лише від справді завданої шкоди й не швидше за Data.LIFESTEAL_MAX_HPS
	var dealt: float = maxf(0.0, hp_before - maxf(0.0, e.hp))
	if crit and not e.dead:
		Status.apply(e, "bleed", 3.0, dmg * 0.1)  # критичний удар лишає кровотечу
	if lifesteal > 0.0:
		_leech(dealt * lifesteal)


## Вміння за даними: стани від удару (не частіше ніж раз на 4 с на ворога) й нагорода за вбивство.
func _skill_on_hit(e, dmg: float) -> void:
	if e.dead:
		if fx("kill_heal") > 0.0:
			heal(max_hp * fx("kill_heal") / 100.0, false)
		if fx("kill_mana") > 0.0:
			mana = minf(max_mana, mana + fx("kill_mana"))
		return
	var now: float = combat._time
	for pair in [["bleed_hit", "bleed", 3.0], ["burn_hit", "burn", 3.0], ["chill_hit", "chill", 2.0], ["weak_hit", "weak", 3.0], ["curse_hit", "curse", 2.0], ["stun_hit", "", 0.6]]:
		var key: String = pair[0]
		var chance: float = fx(key) / 100.0
		if chance <= 0.0 or randf() >= chance or now < float(e.get_meta("sk_" + key, -100.0)):
			continue
		e.set_meta("sk_" + key, now + 4.0)
		if key == "stun_hit":
			if not e.is_boss:
				e.stun = maxf(e.stun, float(pair[2]))
		else:
			Status.apply(e, pair[1], pair[2], dmg * 0.1 if key in ["bleed_hit", "burn_hit"] else 0.0)


func _tick_buffs(delta: float) -> void:
	var ended := false
	for bid in buffs.keys():
		buffs[bid]["t"] = float(buffs[bid]["t"]) - delta
		if float(buffs[bid]["t"]) <= 0.0:
			buffs.erase(bid)
			ended = true
	if ended:
		recalc()


## Чи діє зараз підсилення від уміння.
func buff_on(id: String) -> bool:
	return buffs.has(id)


## Лікування вампіризмом із запасу, що поповнюється з часом (див. _process): не більш як Data.LIFESTEAL_MAX_HPS за секунду.
func _leech(amount: float) -> void:
	var h: float = minf(amount, leech_pool)
	if h <= 0.0:
		return
	leech_pool -= h
	heal(h, false)


## Душі у вдягнених речах: стани від удару (не частіше ніж раз на Souls.PROC_LOCK с на ворога) і вибух убитого.
func _soul_on_hit(e, dmg: float) -> void:
	var now: float = combat._time
	for pair in [["burn_hit", "burn", 3.0], ["chill_hit", "chill", 2.0], ["weak_hit", "weak", 3.0], ["curse_hit", "curse", 2.0], ["stun_hit", "", 0.6]]:
		var key: String = pair[0]
		if e.dead or not soul_fx.has(key) or randf() >= float(soul_fx[key]):
			continue
		if now < float(e.get_meta("sl_" + key, -100.0)):
			continue
		e.set_meta("sl_" + key, now + SoulService.Souls.PROC_LOCK)
		if key == "stun_hit":
			if not e.is_boss:
				e.stun = maxf(e.stun, float(pair[2]))
		else:
			Status.apply(e, pair[1], pair[2], dmg * 0.1 if key == "burn_hit" else 0.0)
	if e.dead and soul_fx.has("kill_blast") and randf() < float(soul_fx["kill_blast"]):
		var c: Vector2 = e.global_position
		for o in _alive_enemies():
			if o.global_position.distance_to(c) <= 120.0 + o.radius:
				o.take_damage(e.max_hp * 0.2, (o.global_position - c).normalized() * 200.0, false)
		combat.fx.burst(c, Color(1.0, 0.6, 0.2), 22, 240, 7, 0.45)
		Audio.play("clash", 0.1, -6.0)


func _alive_enemies() -> Array:
	var out := []
	for e in combat.enemies_now():
		if not e.dead:
			out.append(e)
	return out


## Звичайний удар серії (третій — завершальний). Як б'є — каже механіка зброї в руках (weapon/<вид>.gd).
func attack() -> void:
	if not alive or attack_timer > 0.0 or dodge_time_left > 0.0 or petrified > 0.0:
		return
	attack_timer = attack_cooldown
	if combo_timer <= 0.0:
		combo_step = 0
	var step := combo_step
	var finisher := step == COMBO_MULT.size() - 1
	if finisher:
		attack_timer = attack_cooldown * 1.3  # після завершального — коротка пауза, як у справжньому ритмі
	_weapon_for(weapon_type).attack(step, finisher)


## Ковтнути зілля здоров'я. Повертає true, якщо вдалося.
func use_potion() -> bool:
	if not alive or potions <= 0 or potion_timer > 0.0 or (hp >= max_hp and mana >= max_mana * 0.6):
		return false
	potions -= 1
	potion_timer = Data.POTION_CD * (1.0 - 0.15 * pk("h_sip"))
	var part := Data.POTION_HEAL * (1.0 + 0.1 * pk("h_potion")) * (1.0 + float(festive.get("potion", 0.0)))  # на Водохреще зілля дужче
	heal(max_hp * part)
	mana = minf(max_mana, mana + max_mana * part)  # зілля відновлює й наснагу
	return true


func add_potion() -> bool:
	if potions >= potion_max():
		return false
	potions += 1
	return true


## Погляд Вія: герой кам'яніє на dur секунд. Перекид саме в цю мить, оберіг чи недавнє скам'яніння рятують.
## Коротка невразливість після удару не рятує: погляд і б'є, і кам'янить одним махом.
func petrify(dur: float) -> bool:
	if not alive or petrify_guard > 0.0 or blocks_status() or dodge_time_left > 0.0:
		return false
	petrified = dur
	petrify_guard = dur + 6.0
	blocking = false
	if combat:
		combat.float_text(global_position + Vector2(0, -90), "Скам'янів!", Color(0.8, 0.82, 0.85))
		combat.fx.ring(global_position, Color(0.75, 0.75, 0.8), 18, 160, 5, 0.4)
	return true


## Ковтнути зілля наснаги: відновлює частку наснаги. Повертає true, якщо вдалося.
func use_mana_potion() -> bool:
	if not alive or mana_potions <= 0 or mana_potion_timer > 0.0 or mana >= max_mana * 0.95:
		return false
	mana_potions -= 1
	mana_potion_timer = Data.MANA_POTION_CD * (1.0 - 0.15 * pk("h_sip"))
	var got := max_mana * Data.MANA_POTION_RESTORE
	mana = minf(max_mana, mana + got)
	Audio.play("heal", 0.05, -4.0)
	if combat:
		combat.float_text(global_position + Vector2(0, -70), "+%d наснаги" % roundi(got), Color(0.5, 0.75, 1.0))
		combat.fx.ring(global_position, Color(0.4, 0.65, 1.0), 16, 150, 4, 0.4)
	return true


func add_mana_potion() -> bool:
	if mana_potions >= mana_potion_max():
		return false
	mana_potions += 1
	return true


func dodge() -> void:
	if not alive or dodge_timer > 0.0 or petrified > 0.0:
		return
	blocking = false
	combo_step = 0
	dodge_timer = dodge_cooldown
	var input_vec: Vector2 = combat.get_move_input()
	dodge_dir = input_vec.normalized() if input_vec.length() > 0.1 else facing
	dodge_time_left = 0.18
	dodge_hits.clear()
	invuln = maxf(invuln, 0.32)
	for m in _hooks[HeroMechanic.ON_DODGE]:
		m.on_dodge()
	_after_dodge_t = 2.0
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

## Перезарядка вміння з поправками героя: свої поправки вміння (cooldown механіки), тоді загальні.
func skill_cooldown(id: String) -> float:
	var base: float = Classes.cooldown(id)
	var m = _skill_probe(id)
	if m != null and m.bits & (1 << HeroMechanic.COOLDOWN):
		base = m.cooldown(base)
	return base * skill_cd_mult


func skill_ready_ratio(id: String) -> float:
	return skill_timers.get(id, 0.0) / skill_cooldown(id)


func skill_cost(id: String) -> float:
	return float(Classes.find_node(id).get("cost", 0))


func use_skill(id: String) -> void:
	if not alive or sk(id) <= 0 or skill_timers.get(id, 0.0) > 0.0 or petrified > 0.0:
		return
	if mana < skill_cost(id):
		if _in_combat():
			combat.float_text(global_position + Vector2(0, -80), "Бракує наснаги", Color(0.5, 0.65, 1.0))
		return
	var m = _skill_mech(id)
	var used: bool = m.cast() if m != null else _act(id)
	if used:
		mana -= skill_cost(id)
		skill_timers[id] = skill_cooldown(id)
		for hm in _hooks[HeroMechanic.ON_CAST]:
			hm.on_cast(id)


# ---------- Вміння за даними ----------

## Виконує активне вміння, описане у вузлі дерева полем "act": дію робить механіка його шаблону
## (scripts/mechanics/act/<act.type>.gd), числа беруться із запису.
func _act(id: String) -> bool:
	var n: Dictionary = Classes.find_node(id)
	var A: Dictionary = n.get("act", {})
	if A.is_empty():
		return false
	var am = _act_mech(str(A.get("type", "")))
	if am == null:
		return false
	var r := sk(id)
	var col := Color(str(A.get("color", "ffd24a")))
	var m: float = Classes.val(A.get("pct", 0.0), r) * skill_power
	return am.cast(n, A, r, m, col)


# ---------- Механіки героя ----------

## Механіка героя за посиланням ("skill/whirl", "act/nova", "power/hrim", "weapon/sabre"), якщо герой її вже має.
func mech(ref: String):
	return _mechs.get(ref)


## Збирає механіки за збіркою героя: вивчені вміння з власною дією, шаблони вмінь за даними, сили
## вдягнених золотих речей, зброя в руках. Нові об'єкти з'являються лише тут (і раз на героя).
func _sync_mechs() -> void:
	var changed := false
	for id in skills:
		if int(skills[id]) > 0 and _ensure_skill(str(id)):
			changed = true
	for pid in u_pow:
		var ref: String = Uniques.power_mechanic(str(pid))
		if ref != "" and not _mechs.has(ref):
			var pm = PowerMechanic.create(ref, str(pid), Uniques.power_num(str(pid)), self)
			if pm != null:
				pm.ref = ref
				_mechs[ref] = pm
				changed = true
	var wm = _weapon_for(weapon_type)
	if wm != weapon_mech:
		weapon_mech = wm
		changed = true
	if changed:
		_rebuild_hooks()


## Механіка вміння id (чи його шаблону) для героя, якщо її ще нема. true — з'явився новий об'єкт.
func _ensure_skill(id: String) -> bool:
	if _by_skill.has(id):
		return false
	var n: Dictionary = Classes.find_node(id)
	var ref := str(n.get("mechanic", ""))
	_by_skill[id] = null
	if ref != "":
		var m = SkillMechanic.create(ref, id, self)
		if m == null:
			return false
		m.ref = ref
		_by_skill[id] = m
		_mechs[ref] = m
		return true
	if n.has("act"):
		var t := str(n["act"].get("type", ""))
		if not _acts.has(t):
			return _act_mech(t) != null
	return false


## Механіка шаблону дії t (раз на героя).
func _act_mech(t: String):
	if not _acts.has(t):
		var am = ActMechanic.create(t, self)
		_acts[t] = am
		if am != null:
			am.ref = ActMechanic.DIR + t
			_mechs[am.ref] = am
	return _acts[t]


## Механіка виду зброї t (без стану: одна на вид).
func _weapon_for(t: String):
	var W: Dictionary = Data.weapon(t)
	var ref := str(W.get("mechanic", ""))
	var key := ref if ref != "" else "weapon:" + t
	if not _mechs.has(key):
		var wm = WeaponMechanic.create(ref, t, int(W.get("num", 0)), self)
		wm.ref = key
		_mechs[key] = wm
	return _mechs[key]


## Механіка вміння id для картки й перезарядки: вивчена, а як ні — тимчасова без стану (null — уміння без
## власної дії).
func _skill_probe(id: String):
	var m = _by_skill.get(id)
	if m != null:
		return m
	if not _probes.has(id):
		var ref := str(Classes.find_node(id).get("mechanic", ""))
		_probes[id] = SkillMechanic.create(ref, id, self) if ref != "" else null
	return _probes[id]


## Переписує переліки хуків: усі механіки вмінь, шаблонів і сил героя та зброя в руках, у черзі order()
## (за рівного — номер запису, тоді посилання).
func _rebuild_hooks() -> void:
	var all := []
	for ref in _mechs:
		var m = _mechs[ref]
		if m is WeaponMechanic and m != weapon_mech:
			continue
		all.append(m)
	all.sort_custom(func(a, b):
		if a.order() != b.order():
			return a.order() < b.order()
		if a.num != b.num:
			return a.num < b.num
		return a.ref < b.ref)
	_hooks = HeroMechanic.empty_hooks()
	for m in all:
		for i in HeroMechanic.EVENTS:
			if m.bits & (1 << i):
				_hooks[i].append(m)


## Усі вивчені активні вміння (свого класу і набуті раніше), у порядку дерев.
func learned_actives() -> Array:
	var out := []
	var lin: Array = Classes.lineage(job)
	for i in range(lin.size() - 1, -1, -1):
		for b in Classes.tree(lin[i]):
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


# ---------- Сила лікування, радіус Вихору ----------









## Сила лікування вмінь: сила вмінь героя з «Травником» (Живиця, підсилення за даними з «heal»).
func heal_power() -> float:
	return skill_power * (1.0 + 0.12 * pk("travnyk"))






## Радіус сліду кругового удару, коли вміння його не сказало (swing_reach == 0 лишає Вихор): радіус Вихору.
func whirl_reach() -> float:
	return _skill_probe("whirl").reach()


# ================= Отримання шкоди =================

## Повертає true, якщо удар таки поранив (не блок-парирування, не невразливість).
## area — шкода від хмари чи калюжі: її не парирують і вона не дає миті невразливості.
func take_damage(amount: float, source = null, area: bool = false) -> bool:
	if not alive or invuln > 0.0:
		return false
	if blocking and not area:
		if block_time <= PARRY_WINDOW:
			_parry(source)
			return false
		amount *= BLOCK_MULT * (1.0 - float(soul_fx.get("block", 0.0))) * (1.0 - minf(60.0, fx("block")) / 100.0)
		combat.float_text(global_position + Vector2(0, -70), "Блок", Color(0.75, 0.85, 1.0))
	for m in _hooks[HeroMechanic.ABSORB]:
		amount = m.absorb(amount)
		if amount < 0.0:
			return false  # щит поглинув увесь удар
	for m in _hooks[HeroMechanic.DAMAGE_TAKEN]:
		amount = m.damage_taken(amount)
	if source != null and thorns > 0.0 and not source.dead:
		source.take_damage(amount * thorns, Vector2.ZERO, false)
	amount *= (1.0 - armor)
	amount *= 1.0 - float(valor_fx.get("ward", 0.0)) / 100.0  # звитяга «Оберіг»
	amount *= 1.0 - minf(40.0, fx("ward")) / 100.0  # вміння за даними
	if trip_buffs.has("antiplague"):
		amount *= 0.8
	hp -= amount
	hurt_flash = 0.2
	if not area:
		invuln = 0.35
		combat.shake(7.0)
	Audio.play("hurt", 0.1)
	Events.player_hurt.emit()
	combat.float_text(global_position + Vector2(0, -50), str(int(amount)), Color(1.0, 0.35, 0.3))
	_check_death()
	return true


## Шкода від хмари зарази чи відьминого зілля. Перекид її оминає, броня й обереги зменшують, та миті
## невразливості вона не дає й не парирується: раніше в хмарі герой був невразливий до ударів дві третини часу.
func take_area(amount: float) -> bool:
	return take_damage(amount, null, true)


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
	if pk("h_berehynia") > 0 and berehynia_ready:
		berehynia_ready = false
		hp = 1.0
		invuln = 1.5
		statuses.clear()
		heal(max_hp * 0.3, false)
		Events.banner.emit("Берегиня вберегла!", Color(0.6, 0.9, 1.0))
		return
	var revive: float = float(divine_fx.get("revive", 0.0))
	if revive > 0.0 and ladanka_ready:
		# Материна ладанка: раз на бій підіймає героя з часткою здоров'я
		ladanka_ready = false
		hp = 1.0
		invuln = 2.0
		statuses.clear()
		heal(max_hp * revive, false)
		Events.banner.emit("Ладанка вберегла!", Color(1.0, 0.82, 0.4))
		return
	hp = 0.0
	alive = false
	queue_redraw()
	died.emit()
	Events.player_died.emit()


## Накласти стан на козака (від удару ворога).
func add_status(id: String, dur: float, dps: float = 0.0) -> void:
	if not alive or blocks_status():
		return
	if id == "plague":
		if plague_immune:
			return
		dps *= (1.0 - plague_resist) * (1.0 - float(art.get("plague", 0.0)))
	var fresh := not statuses.has(id)
	# на Здвиження пристріт слабне; артефакти теж скорочують стани, разом не більш як на 60%
	var shorter: float = minf(0.6, float(festive.get("status", 0.0)) + float(art.get("status", 0.0)) + float(art.get("st_" + id, 0.0)) + float(soul_fx.get("status_res", 0.0)))
	Status.apply(self, id, dur * (1.0 - shorter), dps)
	if fresh and _in_combat():
		combat.float_text(global_position + Vector2(0, -95), Status.INFO[id]["name"] + "!", Status.INFO[id]["color"])


## Чи стани зараз не чіпляються до героя (Очищення).
func blocks_status() -> bool:
	for m in _hooks[HeroMechanic.BLOCKS_STATUS]:
		if m.blocks_status():
			return true
	return false


## Як нечисть бачить героя (Enemy._pick_target): 1 — б'є лише його, хто близько (Козацька стіна),
## −1 — не бачить (Тінь), 0 — як завжди.
func aggro() -> int:
	for m in _hooks[HeroMechanic.AGGRO]:
		var a: int = m.aggro()
		if a != 0:
			return a
	return 0


## Шкода по побратимові загону з урахуванням умінь героя (Оберіг загону): Companion.take_damage.
func party_damage(amount: float) -> float:
	for m in _hooks[HeroMechanic.PARTY_DAMAGE]:
		amount = m.party_damage(amount)
	return amount


## Завершальний удар серії чи повний заряджений удар зблизька влучив: сили на кшталт Громового удару.
func finisher_blow() -> void:
	for m in _hooks[HeroMechanic.ON_FINISHER]:
		m.on_finisher()


## Механіка вивченого вміння id (з'являється, якщо ще нема); null — уміння без власної дії.
func _skill_mech(id: String):
	if not _by_skill.has(id) and _ensure_skill(id):
		_rebuild_hooks()
	return _by_skill.get(id)


func heal(amount: float, show: bool = true) -> void:
	amount *= Status.heal_mult(self) * (1.0 - float(soul_fx.get("heal_taken", 0.0)))
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
	for m in _hooks[HeroMechanic.TINT]:
		tint = m.tint(tint)  # Тінь, вовча подоба

	# Тінь
	draw_set_transform(Vector2(0, 20), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if not alive:
		draw_set_transform(Vector2(0, 8), PI / 2.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	if petrified > 0.0:
		tint = Color(0.62, 0.63, 0.66)  # сірий камінь
	if Gfx.has(sprite_id()):
		_draw_sprite(tint)
	else:
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
			var hc: Color = Data.rarity_color(int(equipment["head"]["rarity"]))
			draw_colored_polygon(PackedVector2Array([
				head + Vector2(side * 6, -10), head + Vector2(-side * 4, -24), head + Vector2(-side * 14, -18), head + Vector2(-side * 8, -9)
			]), hc.darkened(0.25) * tint)
			draw_rect(Rect2(head + Vector2(-12, -14), Vector2(24, 8)), Color(0.25, 0.18, 0.12) * tint)
		for m in _hooks[HeroMechanic.DRAW_HEAD]:
			m.draw_head(head, side, tint)  # вовча подоба: вуха й сяйво очей
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
		var metals := [Color(0.86, 0.9, 0.95), Color(0.85, 0.95, 0.85), Color(0.75, 0.88, 1.0), Color(1.0, 0.85, 0.45), Color(1.0, 0.92, 0.35)]
		var metal: Color = metals[clampi(rarity, 0, metals.size() - 1)]
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
	# Що вміння малюють довкола героя: щит-оберіг, клич, стіна, замовлена шабля, трава
	for m in _hooks[HeroMechanic.DRAW_AURA]:
		m.draw_aura(side)

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


# ---------------- Спрайт (нова графіка) ----------------

## Який лист спрайтів у героя: селянин, козацька чи волхівська дорога.
func sprite_id() -> String:
	if costume != "":
		# вбрання з крамниці міняє постать цілком; зброя в руці та, що вдягнена
		var cid: String = Costumes.sprite(costume, "pike" if is_peasant() else weapon_type)
		if cid != "" and Gfx.has(cid):
			return cid
	if is_peasant():
		return "peasant"
	var wt := "pishchal" if weapon_type == "pishchal" else ("staff" if weapon_type == "staff" else weapon_type)
	var id := "%s_%s" % [job, wt]
	if Gfx.has(id):
		return id
	if Classes.is_volkhv_line(job):
		return "volkhv_staff" if Gfx.has("volkhv_staff") else "volkhv"
	if Classes.is_strilets_line(job):
		var sid := "strilets_%s" % wt
		return sid if Gfx.has(sid) else "strilets_bow"
	return "cossack_%s" % wt if Gfx.has("cossack_%s" % wt) else "cossack"


const DIVINE_OUTLINE := Color(0.106, 0.078, 0.125)


## Крила Рарога за спиною героя: два білі крила із золотою крайкою, що повільно махають.
func _draw_wings(tint: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var flap := sin(t * 3.2) * 3.0
	var d := Gfx.dir_of(facing)
	var white := Color(0.95, 0.95, 1.0) * tint
	var gold := Color(0.92, 0.72, 0.25) * tint
	var sides := [-1.0, 1.0]
	if d[0] == "side":
		sides = [-1.0 if d[1] else 1.0]  # збоку видно одне крило, за спиною
	for sgn in sides:
		var root := Vector2(sgn * 5.0, -10.0)
		var tip := root + Vector2(sgn * 20.0, -12.0 - flap)
		var low := root + Vector2(sgn * 16.0, 10.0 + flap * 0.5)
		var mid := root + Vector2(sgn * 8.0, 8.0)
		var shape := PackedVector2Array([root, tip, low, mid])
		var edge := PackedVector2Array()
		for v in shape:
			edge.append(v + (v - (root + Vector2(sgn * 10.0, 0.0))).normalized() * 1.6)
		draw_colored_polygon(edge, DIVINE_OUTLINE)
		draw_colored_polygon(shape, white)
		draw_line(root, tip, gold, 2.0)
		draw_line(root + Vector2(sgn * 4.0, 4.0), low, Color(0.75, 0.78, 0.9) * tint, 1.5)


## Громовий молот на поясі героя, час від часу по ньому пробігає іскра.
func _draw_relic(tint: Color) -> void:
	var d := Gfx.dir_of(facing)
	var sx := 12.0 if (d[0] != "side" or d[1]) else -12.0
	var at := Vector2(sx, 0.0)
	draw_rect(Rect2(at + Vector2(-5, -9), Vector2(10, 7)), DIVINE_OUTLINE)
	draw_rect(Rect2(at + Vector2(-2, -3), Vector2(4, 11)), DIVINE_OUTLINE)
	draw_rect(Rect2(at + Vector2(-4, -8), Vector2(8, 5)), Color(0.6, 0.62, 0.7) * tint)
	draw_rect(Rect2(at + Vector2(-4, -6), Vector2(8, 1)), Color(0.92, 0.72, 0.25) * tint)
	draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 9)), Color(0.5, 0.32, 0.18) * tint)
	var t := fmod(Time.get_ticks_msec() / 1000.0, 2.4)
	if t < 0.25:
		var c := Color(0.5, 0.85, 1.0, 1.0 - t * 4.0)
		draw_line(at + Vector2(4, -10), at + Vector2(7, -15), c, 1.5)
		draw_line(at + Vector2(7, -15), at + Vector2(5, -17), c, 1.5)
		draw_line(at + Vector2(-4, -10), at + Vector2(-7, -14), c, 1.5)


## Материна ладанка на грудях героя.
func _draw_ladanka(tint: Color) -> void:
	if Gfx.dir_of(facing)[0] == "up":
		return  # зі спини її не видно
	draw_rect(Rect2(-3, -9, 6, 7), DIVINE_OUTLINE)
	draw_rect(Rect2(-2, -8, 4, 5), Color(0.7, 0.18, 0.18) * tint)
	draw_rect(Rect2(-2, -8, 4, 1), Color(0.92, 0.72, 0.25) * tint)


## Бойовий стяг за плечем: держак і малинове полотнище, що тріпоче.
func _draw_banner(tint: Color) -> void:
	var d := Gfx.dir_of(facing)
	var sx := -13.0 if (d[0] != "side" or d[1]) else 13.0
	var wave := sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 1.5
	var dir := -1.0 if sx < 0.0 else 1.0
	draw_rect(Rect2(sx - 1.5, -37, 3, 34), DIVINE_OUTLINE)
	draw_rect(Rect2(sx - 0.5, -36, 1, 32), Color(0.5, 0.32, 0.18) * tint)
	var cloth := PackedVector2Array([Vector2(sx, -36), Vector2(sx + dir * 14.0, -34 + wave), Vector2(sx + dir * 11.0, -30), Vector2(sx + dir * 14.0, -26 - wave), Vector2(sx, -25)])
	var edge := PackedVector2Array()
	for v in cloth:
		edge.append(v + (v - Vector2(sx + dir * 7.0, -30.5)).normalized() * 1.4)
	draw_colored_polygon(edge, DIVINE_OUTLINE)
	draw_colored_polygon(cloth, Color(0.68, 0.14, 0.24) * tint)
	draw_rect(Rect2(sx + dir * 6.0 - 1.5, -32, 3, 3), Color(0.92, 0.72, 0.25) * tint)


## Чарівний ліхтар у руці: скляний, із живим вогником.
func _draw_lantern(tint: Color) -> void:
	var d := Gfx.dir_of(facing)
	var sx := -15.0 if (d[0] != "side" or d[1]) else 15.0
	var glow := 0.75 + sin(Time.get_ticks_msec() / 1000.0 * 7.0) * 0.15
	draw_circle(Vector2(sx, 3), 9.0, Color(1.0, 0.85, 0.4, 0.16 * glow))
	draw_rect(Rect2(sx - 3.5, -2, 7, 10), DIVINE_OUTLINE)
	draw_rect(Rect2(sx - 2.5, 0, 5, 6), Color(1.0, 0.85, 0.42) * tint)
	draw_rect(Rect2(sx - 1.0, 1, 2, 4), Color(1.0, 0.98, 0.85) * tint)
	draw_rect(Rect2(sx - 2.5, -1, 5, 1), Color(0.4, 0.42, 0.48) * tint)


## Німб праведника над головою: золоте кільце, що ледь мерехтить.
func _draw_halo(tint: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var c := Vector2(0, -33 + sin(t * 2.0) * 1.0)
	var pts := PackedVector2Array()
	for i in 17:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * 9.0, sin(a) * 3.2))
	draw_polyline(pts, DIVINE_OUTLINE, 4.0)
	draw_polyline(pts, Color(1.0, 0.82, 0.3, 0.85 + sin(t * 4.0) * 0.15) * tint, 2.0)


func _draw_sprite(tint: Color) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # лежачий кадр уже намальовано на листі
	var frame := Gfx.IDLE
	if not alive:
		frame = Gfx.DEAD
	elif hurt_flash > 0.0 and swing_time <= 0.0:
		frame = Gfx.HURT
	elif swing_time > 0.0 and swing_duration > 0.0:
		frame = Gfx.attack_frame(1.0 - swing_time / swing_duration)
	elif moving:
		frame = Gfx.walk_frame(walk_phase)
	# Крила Рарога: за спиною, тож спершу малюються вони, а коли герой стоїть спиною до нас, то поверх нього
	var winged: bool = alive and str(divine.get("wings", "")) != ""
	var back_view: bool = Gfx.dir_of(facing)[0] == "up"
	if winged and not back_view:
		_draw_wings(tint)
	Gfx.draw(self, sprite_id(), facing, frame, Vector2(-24, -30), tint)
	if winged and back_view:
		_draw_wings(tint)
	if alive and str(divine.get("relic", "")) == "molot":
		_draw_relic(tint)
	elif alive and str(divine.get("relic", "")) == "ladanka":
		_draw_ladanka(tint)
	if alive and str(divine.get("banner", "")) != "":
		_draw_banner(tint)
	if alive and str(divine.get("lantern", "")) != "":
		_draw_lantern(tint)
	if alive and str(divine.get("halo", "")) != "":
		_draw_halo(tint)
	# Накладки: вдягнена шапка (шлик кольору рідкості) і накладка вміння (вовча подоба), що шапку ховає
	var over := ""
	for m in _hooks[HeroMechanic.OVERLAY]:
		over = m.overlay()
		if over != "":
			break
	if equipment.has("head") and costume == "" and not Classes.is_volkhv_line(job) and over == "" and Gfx.has("overlay_hat"):
		var hc: Color = Data.rarity_color(int(equipment["head"]["rarity"]))
		Gfx.draw(self, "overlay_hat", facing, frame, Vector2(-24, -30), hc * tint)
	if over != "" and Gfx.has(over):
		Gfx.draw(self, over, facing, frame, Vector2(-24, -30), tint)
