extends RefCounted
## Опис характеристик, дерева вмінь і дерева пасивних перків.
## Щоб додати новий вузол — достатньо дописати його сюди та реалізувати ефект у player.gd.

const STAT_BASE := 5

# ======================= Баланс (усі ключові числа тут) =======================
# ---- Сила нечисті: мірка від еталонного героя ----
# Раніше здоров'я нечисті росло з рівнем лінійно, а шкода героя приблизно як квадрат рівня. На 20-му рівні
# звичайний ворог падав за чверть секунди, на 75-му за три сотих, і герой міг пропустити понад 60 ударів.
# Тепер уся нечисть рівня L рахується від еталонного героя цього рівня в середньому спорядженні
# (криві REF_* зняті з tools/power_probe.gd): звичайний заражений тримає ENEMY_TTK секунд його чистої шкоди,
# а удар забирає ENEMY_HIT його запасу живучості. Хто вдягнений краще за еталон, тому легше; хто гірше, тому важче.
# Герой у найкращому спорядженні з душами й клейнодами має шкоди в 4–8 разів більше й живучості у 2,5 раза.
const REF_DPS_BASE := 100.0
const REF_DPS_K := 2.7
const REF_DPS_POW := 2.34
const REF_EHP_BASE := 235.0
const REF_EHP_Q := 6.1  # до REF_EHP_KNEE-го рівня запас живучості росте квадратом: набирається захист
const REF_EHP_KNEE := 20
const REF_EHP_LIN := 143.0  # далі лінійно
# Мірка за рівнем, точками [рівень, секунд чистої шкоди еталонного героя на звичайного зараженого,
# частка його запасу живучості за удар]; між точками плавно, після останньої рівно.
# Новачкові м'яко. До 20-го рівня (сюжет) гра вже тверда: у середньому спорядженні поле свого рівня
# проходиться із зіллям, печера свого рівня вбиває. Далі мірка росте ще, бо на високих рівнях герой уже
# має ходити в легендарному: у середньому там дуже важко, у доброму (легендарне із заточкою) суворо,
# а нормально косити нечисть виходить лише в найкращому. Числа перевірено симуляціями (docs/balance.md).
const ENEMY_CURVE := [[1, 0.9, 0.045], [20, 1.4, 0.06], [50, 2.5, 0.10]]
const STD_HP := 70.0  # здоров'я й удар «звичайного зараженого» в таблиці видів (решта видів у пропорції до нього)
const STD_DMG := 13.0
const OLD_DMG_PER_LEVEL := 0.16  # стара лінійна шкода нечисті: під неї зроблені формули брам і возів (див. FarService.guard_mult)


## Башта Кощія й Глибини зарази не мають стелі. До ENDLESS_SOFT-го рівня нечисть росте за звичайною міркою.
## Вище рівень росте далі, а здоров'я й удар ще й множаться за кожен рівень понад межу: так сходинки
## лишаються відчутними, хоч мірка після 50-го рівня вже рівна. Здобич вище за ENDLESS_SOFT-й рівень не росте:
## речі 100–140-го рівня дають лише надважкі печери.
const ENDLESS_SOFT := 99
const ENDLESS_HP_PER_LEVEL := 1.02
const ENDLESS_DMG_PER_LEVEL := 1.015


static func endless_hp(lvl: int) -> float:
	return pow(ENDLESS_HP_PER_LEVEL, float(maxi(0, lvl - ENDLESS_SOFT)))


static func endless_dmg(lvl: int) -> float:
	return pow(ENDLESS_DMG_PER_LEVEL, float(maxi(0, lvl - ENDLESS_SOFT)))


## Шкода за секунду еталонного героя рівня lvl.
static func ref_dps(lvl: int) -> float:
	return REF_DPS_BASE + REF_DPS_K * pow(float(maxi(1, lvl)), REF_DPS_POW)


## Запас живучості еталонного героя: здоров'я з поправкою на захист.
static func ref_ehp(lvl: int) -> float:
	var l := maxi(1, lvl)
	if l <= REF_EHP_KNEE:
		return REF_EHP_BASE + REF_EHP_Q * l * l
	return REF_EHP_BASE + REF_EHP_Q * REF_EHP_KNEE * REF_EHP_KNEE + REF_EHP_LIN * (l - REF_EHP_KNEE)


## Значення мірки для рівня: col 1 — секунди шкоди, col 2 — частка живучості за удар.
static func _enemy_curve(lvl: int, col: int) -> float:
	var pts: Array = ENEMY_CURVE
	if lvl <= int(pts[0][0]):
		return float(pts[0][col])
	for i in range(1, pts.size()):
		if lvl <= int(pts[i][0]):
			var t := float(lvl - int(pts[i - 1][0])) / float(int(pts[i][0]) - int(pts[i - 1][0]))
			return lerpf(float(pts[i - 1][col]), float(pts[i][col]), t)
	return float(pts[-1][col])


## Скільки секунд чистої шкоди еталонного героя тримає звичайний заражений рівня lvl.
static func enemy_ttk(lvl: int) -> float:
	return _enemy_curve(lvl, 1)


## Яку частку запасу живучості еталонного героя забирає удар звичайного зараженого рівня lvl.
static func enemy_hit(lvl: int) -> float:
	return _enemy_curve(lvl, 2)


## Здоров'я звичайного зараженого рівня lvl.
static func enemy_std_hp(lvl: int) -> float:
	return ref_dps(lvl) * enemy_ttk(lvl)


## Удар звичайного зараженого рівня lvl (до захисту героя).
static func enemy_std_dmg(lvl: int) -> float:
	return ref_ehp(lvl) * enemy_hit(lvl)


## Множники до табличних здоров'я й удару виду для рівня lvl.
static func enemy_hp_scale(lvl: int) -> float:
	return enemy_std_hp(lvl) / STD_HP


static func enemy_dmg_scale(lvl: int) -> float:
	return enemy_std_dmg(lvl) / STD_DMG
const ENEMY_XP_PER_LEVEL := 0.25  # +25% досвіду з ворога за рівень
const COIN_GOLD_RATIO := 0.34  # скільки гривень дає монета відносно її досвіду
const ITEM_DROP_CHANCE := 0.03  # шанс речі з рядового ворога
const FIELD_GOAL_BASE := 40  # скільки нечисті треба знищити для зачистки
const FIELD_GOAL_PER_LEVEL := 5
const BOSS_HP_MULT := 9.0  # бос у стільки разів «товстіший» за звичайного ворога
const BOSS_XP_MULT := 8
const BOSS_DMG_MULT := 1.6  # бос б'є у стільки разів сильніше за рядового свого виду
const ARMOR_CAP := 0.65  # захист не гасить більше цієї частки удару
const LIFESTEAL_MAX_HPS := 0.015  # вампіризм лікує щонайбільше цю частку здоров'я за секунду
const MANA_ON_HIT := 1.5  # наснаги за влучний удар зі звичайною швидкістю (швидші удари дають стільки ж за секунду)
const MANA_ON_HIT_CD := 0.42  # перезарядка удару, для якої рахується MANA_ON_HIT
const DUNGEON_ROOM_BASE := 6  # ворогів у кімнаті печери: база + за номер кімнати
const DUNGEON_ROOM_PER := 3
const POTION_MAX := 5  # скільки зілля можна нести
const POTION_HEAL := 0.4  # частка здоров'я, яку відновлює зілля
const POTION_CD := 6.0  # секунд між ковтками
const POTION_START := 2
const POTION_DROP_CHANCE := 0.01  # зілля з рядового ворога (до 0.45 було 0,02)
const POTION_ELITE_CHANCE := 0.15  # зілля з еліти (було 0,3); бос лишає одне завжди
## Вареник із нечисті лікує частку здоров'я героя (не менш як VARENYK_MIN): раніше це були ті самі 20
## здоров'я на будь-якому рівні, і на високих рівнях вареник нічого не важив. З боса вареник удвічі ситніший.
const VARENYK_HEAL := 0.08
const VARENYK_MIN := 20
const VARENYK_DROP_CHANCE := 0.03  # до 0.45 було 0,05
## Зілля наснаги: окремий запас, відновлює частку наснаги (здоров'я не лікує).
const MANA_POTION_MAX := 3  # волхви несуть на одне більше
const MANA_POTION_RESTORE := 0.7
const MANA_POTION_CD := 6.0
## Страви з казана й зілля сили діють певний час бою, а не «один похід». Час іде лише в бою.
const MEAL_TIME := 1200.0  # страва, секунд бою
const BREW_TIME := 900.0  # зілля сили й зілля проти зарази
const INSPIRED_TIME := 600.0  # натхнення від кобзаря в дорозі
const BUFF_CAP := 3600.0  # більше години наперед не запасти
const MANA_POTION_DROP_CHANCE := 0.006  # у волхвів удвічі частіше (до 0.45 було 0,012)


static func potion_price(hero_level: int) -> int:
	return 25 + 10 * hero_level


static func mana_potion_price(hero_level: int) -> int:
	return 20 + 8 * hero_level


## Ціна смерті в бою: частка досвіду, потрібного на поточний рівень (рівень не падає), і частка гривень.
## Новачків до DEATH_XP_FROM-го рівня досвідом не караємо. Двобій, варта й вали — випробування, там ціни немає.
const DEATH_XP_LOSS := 0.01
const DEATH_GOLD_LOSS := 0.05
const DEATH_XP_FROM := 10


## З XP_LATE_FROM-го рівня кожен наступний рівень дорожчий ще на XP_LATE_STEP: дорога до останнього має
## відчуватися. У доброму спорядженні в Глибинах рівень на 75-му бере близько півтори години бою,
## останній — близько чотирьох (tools/depth_sim.gd, docs/balance.md).
const XP_LATE_FROM := 50
const XP_LATE_STEP := 0.08


## Досвід, потрібний, щоб перейти з рівня l на l+1.
## До 30-го рівня крива м'яка (сюжет), далі — крутішає: гра після сюжету розрахована на десятки годин.
static func xp_for_level(l: int) -> int:
	var base := 200 + 150 * l + 15 * l * l
	if l < 30:
		return base
	var late := 1.0 + XP_LATE_STEP * maxi(0, l - XP_LATE_FROM + 1)
	return int(base * pow(1.0 + 0.6 * (l - 29), 0.8) * late)


static func coin_gold(xp_value: int) -> int:
	return maxi(1, roundi(xp_value * COIN_GOLD_RATIO))

## Характерництво підсилює вміння щораз слабше: перші SPI_SOFT очок понад початкові повною мірою (+5% сили вмінь, швидша
## перезарядка), кожне наступне — лише часткою SPI_LATE від того. Волхвові Характерництво дає ще й шкоду
## посохом, тож без цього його вміння били вп'ятеро сильніше за воїнові (tools/dps_probe.gd).
const SPI_SOFT := 20.0
const SPI_LATE := 0.1


static func soft_spi(spi: float) -> float:
	return spi if spi <= SPI_SOFT else SPI_SOFT + (spi - SPI_SOFT) * SPI_LATE


## Стрільцям (лук, пістолі, пищаль) Спритність дає і силу пострілу, і його швидкість. Щоб одна характеристика
## не множила сама себе, швидкість пострілу від неї росте повною мірою лише перші AGI_ASPD_SOFT очок,
## далі часткою AGI_ASPD_LATE. Сила пострілу й крит ростуть як і раніше.
const AGI_ASPD_SOFT := 60.0
const AGI_ASPD_LATE := 0.1
## Наснага за звичайний постріл стрільця: частка від того, що дає влучний удар у ближньому бою.
const MANA_ON_SHOT := 0.5


static func soft_agi_aspd(agi: float) -> float:
	return agi if agi <= AGI_ASPD_SOFT else AGI_ASPD_SOFT + (agi - AGI_ASPD_SOFT) * AGI_ASPD_LATE


const STAT_POINTS_PER_LEVEL := 3
const SKILL_POINTS_PER_LEVEL := 1  # очок вмінь за рівень майстерності
const PERK_POINTS_PER_LEVEL := 1  # очок Загартування за кожні Classes.HARDEN_EVERY рівнів героя
const PERK_TIER_STEP := 2  # скільки очок треба вкласти в гілку, щоб відкрити наступний ярус

const STATS := [
	{"id": "str", "name": "Сила", "desc": "+6% шкоди"},
	{"id": "agi", "name": "Спритність", "desc": "+4%% швидкості удару, +1.5%% криту, +1.5%% бігу. Стрільцям ще й +6%% сили пострілу, зате швидкість понад %d очок росте вдесятеро повільніше" % int(AGI_ASPD_SOFT)},
	{"id": "vit", "name": "Витривалість", "desc": "+12 здоров'я, +1% захисту"},
	{"id": "spi", "name": "Характерництво", "desc": "Перші %d вкладених очок: +5%% сили вмінь і -4%% перезарядки, далі вдесятеро менше. Більше наснаги" % int(SPI_SOFT)},
]

# Вміння тепер у деревах класів (див. classes.gd).
const Classes := preload("res://scripts/data/classes.gd")
const ACTIVE_SKILLS: Array = ["vyly", "first_aid", "whirl", "battle_cry", "musket", "fireball", "shield", "herb",
	"zemnyi", "stina", "bulava", "pastka", "tin", "kydok", "kartech", "prytsil", "bochka", "vovk", "kulia", "zamova", "vidvid",
	"zhyvytsia", "pidniaty", "ochyshchennia", "oberih_zahonu", "otruta", "lightning", "molot", "burya", "grad", "tuman", "proklin", "dukh"]
const ACTIVE_LABELS: Dictionary = Classes.ACTIVE_LABELS


static func find_skill(id: String) -> Dictionary:
	return Classes.find_node(id)


static func skill_name(id: String) -> String:
	return Classes.node_name(id)


# Загартування — спільне для всіх класів дерево пасивних вмінь (очко за кожні 2 рівні героя).
# Ярус N відкривається, коли у гілку вкладено N * PERK_TIER_STEP очок.
const PERK_BRANCHES := [
	{"name": "Тіло", "tiers": [
		[{"id": "h_body", "name": "Міцна кістка", "max": 5, "desc": "+4% здоров'я"},
		 {"id": "boots", "name": "Легкі чоботи", "max": 3, "desc": "+5% швидкості\nбігу"}],
		[{"id": "h_skin", "name": "Дублена шкіра", "max": 3, "desc": "+2% захисту"},
		 {"id": "h_blood", "name": "Живуча кров", "max": 3, "desc": "+0.5 здоров'я/с"}],
		[{"id": "varenyk", "name": "Бабусині вареники", "max": 2, "desc": "Вареники частіше\nі ситніші"},
		 {"id": "h_potion", "name": "Міцне зілля", "max": 3, "desc": "Зілля лікує\nна 10% більше"}],
		[{"id": "h_roll", "name": "Спритний перекид", "max": 2, "desc": "Перекид готовий\nна 10% швидше"},
		 {"id": "h_parry", "name": "Тверда рука", "max": 2, "desc": "Парирування\nлікує 4% здоров'я"}],
		[{"id": "sich", "name": "Загартований", "max": 3, "desc": "+2 до всіх\nхарактеристик"}],
	]},
	{"name": "Удар", "tiers": [
		[{"id": "luck", "name": "Вдача", "max": 3, "desc": "+5% шансу\nкриту"},
		 {"id": "h_hand", "name": "Важкий удар", "max": 5, "desc": "+3% шкоди"}],
		[{"id": "h_fast", "name": "Швидка рука", "max": 3, "desc": "+4% швидкості\nудару"},
		 {"id": "h_crit", "name": "Жорстокий крит", "max": 2, "desc": "+25% шкоди\nкриту"}],
		[{"id": "steel_will", "name": "Сталева воля", "max": 3, "desc": "+10% наснаги"},
		 {"id": "h_breath", "name": "Рівне дихання", "max": 3, "desc": "+10% відновлення\nнаснаги"}],
		[{"id": "h_spirit", "name": "Сила духу", "max": 3, "desc": "+5% сили вмінь"},
		 {"id": "h_mind", "name": "Швидкий розум", "max": 2, "desc": "-5% перезарядки\nвмінь"}],
		[{"id": "h_execute", "name": "Добивання", "max": 1, "desc": "+20% шкоди ворогам\nнижче 30% здоров'я"}],
	]},
	{"name": "Похід", "tiers": [
		[{"id": "purse", "name": "Жадібний гаманець", "max": 2, "desc": "+25% радіус\nзбору здобичі"},
		 {"id": "kobzar", "name": "Кобзарева наука", "max": 3, "desc": "+10% досвіду"}],
		[{"id": "h_gold", "name": "Торгова жилка", "max": 3, "desc": "+8% гривень"},
		 {"id": "h_eye", "name": "Зіркий погляд", "max": 3, "desc": "+15% шансу подвійного\nресурсу"}],
		[{"id": "h_flask", "name": "Запасна баклага", "max": 2, "desc": "+1 зілля\nз собою"},
		 {"id": "h_horse", "name": "Швидкий кінь", "max": 2, "desc": "Подорож мапою\nна 15% швидша"}],
		[{"id": "h_sip", "name": "Швидкий ковток", "max": 2, "desc": "Зілля готове\nна 15% швидше"},
		 {"id": "h_trophy", "name": "Мисливець", "max": 2, "desc": "+1 трофей\nз боса й еліти"}],
		[{"id": "h_berehynia", "name": "Берегиня", "max": 1, "desc": "Раз на бій смертельний удар\nлишає 1 здоров'я й лікує 30%"}],
	]},
]


## Повертає [індекс гілки, індекс ярусу, перк] або [-1, -1, {}].
static func find_perk(id: String) -> Array:
	for bi in PERK_BRANCHES.size():
		var tiers: Array = PERK_BRANCHES[bi]["tiers"]
		for ti in tiers.size():
			for p in tiers[ti]:
				if p["id"] == id:
					return [bi, ti, p]
	return [-1, -1, {}]


# ======================= Спорядження =======================
# Основи речей лежать у таблицях (docs/data.md, «Речі»): клітинки (data/gear_slots.json), рідкості
# (rarities.json), види зброї (weapons.json), основи обладунків (armors.json), бонуси (bonuses.json) і
# заточка (sharpening.json). Тут правила: як із них складається випадкова річ, ціни, заточка.

const GameDB := preload("res://scripts/core/game_db.gd")
const _EMPTY := {}

const INVENTORY_SIZE := 24
const MAX_UPGRADE := 10
const UPGRADE_BONUS := 0.12  # +12% до всіх бонусів речі за кожен рівень заточки
const SHARPEN_RISK_FROM := 6  # з цієї заточки невдача знижує рівень на 1
const SHARPEN_SAFE_MULT := 3.0  # заточка без ризику за гривні: у стільки разів дорожча

## Найбільший бонус досвіду чи гривень від однієї речі при найвищій заточці (+MAX_UPGRADE), у відсотках.
## Шість речей із найкращою такою властивістю разом дають близько 100%. До версії 0.50 одна легендарна
## шапка 99-го рівня на +10 давала +152% досвіду, а сума по всьому спорядженню сягала кількасот відсотків.
const XP_GOLD_MAX_TOP := 16.7
## Стеля самої властивості xp чи gold на речі (без заточки): заточка множить її до XP_GOLD_MAX_TOP.
## Які властивості так рахуються — «capped» у bonuses.json, їхній кидок — там само («roll»).
const XP_GOLD_CAP := XP_GOLD_MAX_TOP / (1.0 + UPGRADE_BONUS * MAX_UPGRADE)
## Найкраща звичайна річ, від якої рахується масштаб: легендарна цього рівня з найвищим кидком дає рівно стелю.
const XP_GOLD_TOP_LEVEL := 99
const XP_GOLD_TOP_RARITY := 3

const RARITY_MAX_RANDOM := 3  # випадкова річ не буває унікальною: золоті речі іменні (див. Uniques)

## Яку зброю генерувати в здобичі й крамницях (виставляє гра під клас героя; порожньо — будь-яку «basic»).
static var weapon_pool: Array = []

# Похідні переліки з таблиць: складаються раз, коли вперше потрібні, і лише для читання.
static var _slots: Array = []  # клітинки, що вдягаються (з «primary»), у порядку файлу
static var _drop_slots: Array = []  # кидок клітинки випадкової речі: кожна стільки разів, яка її «drop»
static var _armor_names := {}  # клітинка → назви основ обладунку
static var _basic: Array = []  # типовий пул зброї
static var _agi: Array = []  # зброя від Спритності
static var _affix_pool: Array = []  # бонуси-властивості в порядку кидка
static var _whole := {}  # цілі бонуси (характеристики)
static var _capped: Array = []  # досвід і гривні
static var _rarity: Array = []  # записи рідкостей за rank
static var _rarity_colors: Array = []
static var _sharpen: Array = []  # шанс заточки за нинішнім рівнем


## Клітинки спорядження, що вдягаються: ["weapon", "head", ...].
static func slots() -> Array:
	if _slots.is_empty():
		for id in GameDB.ids("gear_slots"):
			var R: Dictionary = GameDB.gear_slot(id)
			if R.has("primary"):
				_slots.append(id)
				for i in int(R.get("drop", 0)):
					_drop_slots.append(id)
		_slots.make_read_only()
		_drop_slots.make_read_only()
	return _slots


## Чи вдягається річ цієї клітинки (артефакт — ні).
static func is_slot(id: String) -> bool:
	return GameDB.gear_slot(id).has("primary")


## Назва клітинки: «Зброя», «Шапка», «Артефакт».
static func slot_name(id: String) -> String:
	return str(GameDB.gear_slot(id)["name"])


## Головний бонус речі цієї клітинки (flat_dmg, hp...).
static func slot_primary(slot: String) -> String:
	return str(GameDB.gear_slot(slot)["primary"]["stat"])


## Вид зброї: {name, dmg, cd, range, arc, kb, hint...} (weapons.json).
static func weapon(type: String) -> Dictionary:
	return GameDB.weapon(type)


static func has_weapon(type: String) -> bool:
	return GameDB.table("weapons").has(type)


static func weapon_name(type: String) -> String:
	return str(GameDB.weapon(type)["name"])


## Усі види зброї в порядку файлу.
static func weapon_ids() -> Array:
	return GameDB.ids("weapons")


## Зброя дальнього бою: б'є снарядами, дальність стала (див. Player.recalc).
static func is_ranged(type: String) -> bool:
	return bool(GameDB.weapon(type).get("ranged", false))


## Зброя, сила якої йде від Спритності.
static func is_agi(type: String) -> bool:
	return bool(GameDB.weapon(type).get("agi", false))


static func agi_weapons() -> Array:
	if _agi.is_empty():
		for id in weapon_ids():
			if is_agi(id):
				_agi.append(id)
		_agi.make_read_only()
	return _agi


## Зброя, що падає, коли гра не задала пулу під клас.
static func basic_weapons() -> Array:
	if _basic.is_empty():
		for id in weapon_ids():
			if GameDB.weapon(id).get("basic", false):
				_basic.append(id)
		_basic.make_read_only()
	return _basic


## Назви основ обладунку клітинки в порядку файлу.
static func armor_names(slot: String) -> Array:
	if _armor_names.is_empty():
		for id in GameDB.ids("armors"):
			var R: Dictionary = GameDB.row("armors", id)
			if not _armor_names.has(R["slot"]):
				_armor_names[R["slot"]] = []
			_armor_names[R["slot"]].append(R["name"])
		for s in _armor_names:
			_armor_names[s].make_read_only()
		_armor_names.make_read_only()
	return _armor_names.get(slot, [])


## Бонуси, що бувають властивостями випадкової речі, у порядку кидка.
static func affix_pool() -> Array:
	if _affix_pool.is_empty():
		for id in GameDB.ids("bonuses"):
			if GameDB.bonus(id).get("affix", false):
				_affix_pool.append(id)
		_affix_pool.make_read_only()
	return _affix_pool


## Усі бонуси речей у порядку файлу.
static func stat_ids() -> Array:
	return GameDB.ids("bonuses")


## Цілий бонус (Сила, Спритність...): заточка округлює його донизу.
static func is_whole(id: String) -> bool:
	if _whole.is_empty():
		for b in GameDB.ids("bonuses"):
			if GameDB.bonus(b).get("whole", false):
				_whole[b] = true
		_whole.make_read_only()
	return _whole.has(id)


## Цілі бонуси в порядку файлу.
static func whole_stats() -> Array:
	var out := []
	for id in stat_ids():
		if is_whole(id):
			out.append(id)
	return out


## Властивості з масштабом і стелею (досвід, гривні).
static func capped_stats() -> Array:
	if _capped.is_empty():
		for id in GameDB.ids("bonuses"):
			if GameDB.bonus(id).get("capped", false):
				_capped.append(id)
		_capped.make_read_only()
	return _capped


static func is_capped(id: String) -> bool:
	return capped_stats().has(id)


static func _rarities() -> Array:
	if _rarity.is_empty():
		_rarity = GameDB.ladder("rarities", "rank")
		for R in _rarity:
			_rarity_colors.append(R.get("color", Color.WHITE))
		_rarity_colors.make_read_only()
	return _rarity


## Назва рідкості: «Легендарна».
static func rarity_name(r: int) -> String:
	return str(_rarities()[r]["name"])


## Множина рідкості для фільтра автопідбору: «Легендарні».
static func rarity_plural(r: int) -> String:
	return str(_rarities()[r]["plural"])


## Колір рідкості (назва й клітинка речі).
static func rarity_color(r: int) -> Color:
	if _rarity_colors.is_empty():
		_rarities()
	return _rarity_colors[r]


## Множини рідкостей випадкових речей: «Звичайні», «Добротні»...
static func rarity_plurals() -> Array:
	var out := []
	for R in _rarities():
		if R.has("plural"):
			out.append(R["plural"])
	return out


## Скільки всього рідкостей (від звичайної до артефакта).
static func rarity_count() -> int:
	return _rarities().size()


## Шанси заточки: [з +0, з +1, ...].
static func sharpen_chances() -> Array:
	if _sharpen.is_empty():
		for R in GameDB.ladder("sharpening", "up"):
			_sharpen.append(float(R["chance"]))
		_sharpen.make_read_only()
	return _sharpen


## Шаблон тексту бонусу (%s — число) і скільки в ньому знаків після коми.
static func stat_text(id: String) -> String:
	return str(GameDB.bonus(id)["text"])


static func stat_decimals(id: String) -> int:
	return int(GameDB.bonus(id).get("decimals", 0))


static func fmt_stat(id: String, value: float) -> String:
	var B: Dictionary = GameDB.bonus(id)
	var num := ("%.1f" % value) if int(B.get("decimals", 0)) == 1 else str(roundi(value))
	return str(B["text"]) % num


## Масштаб властивості досвіду чи гривень: найвищий кидок легендарної речі XP_GOLD_TOP_LEVEL-го рівня
## дорівнює XP_GOLD_CAP. Так само множаться й ці властивості на речах зі старих збережень.
static func xp_gold_scale(id: String) -> float:
	var r: Dictionary = GameDB.bonus(id)["roll"]
	return XP_GOLD_CAP / ((float(r["max"]) + float(r["per_level"]) * XP_GOLD_TOP_LEVEL) * (1.0 + 0.15 * XP_GOLD_TOP_RARITY))


## Значення властивості під стелею: досвід і гривні не більші за XP_GOLD_CAP, решта як є.
static func cap_affix(id: String, value: float) -> float:
	return minf(value, XP_GOLD_CAP) if is_capped(id) else value


## Позначка на речі: її досвід і гривні вже перераховано під стелю (див. rescale_xp_gold).
const XP_GOLD_MARK := "xg"


## Перерахувати досвід і гривні старої речі на нові числа: той самий масштаб, що й у формулі, потім стеля.
## Річ позначається, тож удруге не зменшиться, де б вона не лежала. Повертає true, якщо щось змінилося.
## Золоту річ перераховує Uniques.value (див. SaveSystem.rescale_items_xp_gold).
static func rescale_xp_gold(item: Dictionary) -> bool:
	if item.has(XP_GOLD_MARK):
		return false
	var changed := false
	for src in [item.get("base", {}), item.get("affixes", {})]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for id in capped_stats():
			if src.has(id):
				src[id] = cap_affix(id, float(src[id]) * xp_gold_scale(id))
				changed = true
	if changed:
		item[XP_GOLD_MARK] = 1
	return changed


## Кидок властивості (bonuses.json, «roll»): дробова — (min..max + per_level × рівень) × якість рідкості,
## ціла — від min до max + рівень/every + рідкість/2, досвід і гривні — ще й масштаб і стеля.
static func _roll_value(id: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + 0.15 * rarity
	var B: Dictionary = GameDB.bonus(id)
	var R: Dictionary = B.get("roll", _EMPTY)
	if R.is_empty():
		return 0.0
	if B.get("capped", false):
		return cap_affix(id, (randf_range(float(R["min"]), float(R["max"])) + float(R["per_level"]) * ilvl) * q * xp_gold_scale(id))
	if B.get("whole", false):
		return float(randi_range(int(R["min"]), int(R["max"]) + ilvl / int(R["every"]) + rarity / 2))
	return (randf_range(float(R["min"]), float(R["max"])) + float(R.get("per_level", 0.0)) * ilvl) * q


## Головний бонус речі (gear_slots.json, «primary»): дробовий — (base + per_level × рівень) × якість,
## цілий — base + рівень/every + рідкість/2.
static func _primary_value(slot: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + 0.15 * rarity
	var P: Dictionary = GameDB.gear_slot(slot).get("primary", _EMPTY)
	if P.is_empty():
		return 0.0
	if P.has("every"):
		return float(int(P["base"]) + ilvl / int(P["every"]) + rarity / 2)
	return (float(P["base"]) + float(P["per_level"]) * ilvl) * q


## Ваги рідкості випадкової речі (rarities.json, «weight»): звичайна, добротна, рідкісна, легендарна.
## Рідкісних і легендарних із рівнем більшає, але повільно. Стара крива (10 + 0,8 і 2 + 0,3 за рівень)
## робилася для гри до 22-го рівня: на 75-му кожна восьма річ була легендарною, і за годину їх падало
## від 25 до 50 (tools/loot_probe.gd). Тепер легендарна на 75-му — кожна тридцята з рядової нечисті.
static func rarity_weights(level: int) -> Array:
	var w := []
	for R in _rarities():
		if R.has("weight"):
			w.append(float(R["weight"]["base"]) + float(R["weight"]["per_level"]) * level)
	return w


## Частка рідкості rarity серед речей рівня level, якщо рідкість не нижча за min_rarity (0..1).
static func rarity_share(level: int, rarity: int, min_rarity: int = 0) -> float:
	var w := rarity_weights(level)
	if rarity < min_rarity or rarity >= w.size():
		return 0.0
	var total := 0.0
	for i in range(min_rarity, w.size()):
		total += float(w[i])
	return float(w[rarity]) / total


static func roll_rarity(wave: int, min_rarity: int = 0) -> int:
	var w := rarity_weights(wave)
	var total := 0.0
	for i in range(min_rarity, 4):
		total += w[i]
	var r := randf() * total
	for i in range(min_rarity, 4):
		r -= w[i]
		if r <= 0.0:
			return i
	return 3


## Створює випадкову річ. slot/type можна задати явно.
static func gen_item(ilvl: int, rarity: int, slot: String = "", type: String = "") -> Dictionary:
	rarity = mini(rarity, RARITY_MAX_RANDOM)
	if slot == "":
		slots()
		slot = _drop_slots[randi() % _drop_slots.size()]
	var name := ""
	if slot == "weapon":
		if type == "":
			var pool: Array = weapon_pool if not weapon_pool.is_empty() else basic_weapons()
			type = pool[randi() % pool.size()]
		name = weapon_name(type)
	else:
		var names: Array = armor_names(slot)
		name = names[mini(names.size() - 1, randi() % names.size())]
	var epithets: Array = _rarities()[rarity].get("epithets", [])
	if not epithets.is_empty():
		name += " «%s»" % epithets[randi() % epithets.size()]
	var primary: String = slot_primary(slot)
	var affixes := {}
	var pool := affix_pool().duplicate()
	pool.erase(primary)
	pool.shuffle()
	for i in rarity:
		affixes[pool[i]] = _roll_value(pool[i], ilvl, rarity)
	return {
		"slot": slot, "type": type, "name": name, "rarity": rarity, "ilvl": ilvl, "up": 0, "spent": 0,
		"base": {primary: _primary_value(slot, ilvl, rarity)}, "affixes": affixes,
	}


## Колір назви й клітинки речі: за рідкістю, а в речі набору свій (див. Sets.COLOR).
const SET_COLOR := Color(0.88, 0.55, 1.0)


static func item_color(item: Dictionary) -> Color:
	if item.has("set"):
		return SET_COLOR
	return rarity_color(int(item["rarity"]))


static func item_title(item: Dictionary) -> String:
	return item["name"] + (" +%d" % item["up"] if item["up"] > 0 else "")


## Усі бонуси речі з урахуванням заточки.
static func item_stats(item: Dictionary) -> Dictionary:
	var mult: float = 1.0 + UPGRADE_BONUS * item["up"]
	var out := {}
	for src in [item["base"], item["affixes"]]:
		for id in src:
			var v: float = src[id] * mult
			if is_whole(id):
				v = floorf(v)
			out[id] = out.get(id, 0.0) + v
	return out


static func sharpen_cost(item: Dictionary) -> int:
	return int(20 * (item["up"] + 1) * (1.0 + 0.5 * item["rarity"]) * (1.0 + 0.25 * item["ilvl"]))


## Ціна заточки без ризику: звичайна (зі знижкою своєї кузні) × SHARPEN_SAFE_MULT.
static func sharpen_safe_cost(item: Dictionary, cost_mult: float = 1.0) -> int:
	return int(sharpen_cost(item) * (cost_mult * SHARPEN_SAFE_MULT))


static func sharpen_chance(item: Dictionary) -> float:
	var ch := sharpen_chances()
	return ch[mini(item["up"], ch.size() - 1)]


## Множник ціни продажу (ярмарок у місті — ×2; виставляє гра при вході в місто).
static var sell_mult: float = 1.0


## Ціна речі без надбавки ярмарку: від неї рахується, за скільки річ продає крамниця.
static func base_price(item: Dictionary) -> int:
	return int(8 * (1 + item["rarity"]) * (1.0 + 0.35 * item["ilvl"]) + item["spent"] * 0.3)


## Цінна річ: золота, іменна чи з набору. Її не можна ні купити, ні викувати, тож за повну торбу
## вона не продається й не лишається на землі, а лягає понад місце.
static func is_precious(item: Dictionary) -> bool:
	return int(item.get("rarity", 0)) > RARITY_MAX_RANDOM or item.has("unique") or item.has("set")


static func sell_price(item: Dictionary) -> int:
	return int(base_price(item) * sell_mult)


# ======================= Світ =======================
# Краї, міста й місця лежать у таблицях (docs/data.md, «Світ»): data/regions.json, cities.json, places.json.
# Позиції — справжні географічні координати (довгота, широта) як Vector2; мапа проєктує їх на екран.
# Записи лише для читання: бій, що хоче змінити опис місця, бере собі копію (Combat.enter).

## Усі місця (поля й печери): id → запис.
static func places() -> Dictionary:
	return GameDB.table("places")


## Місце на мапі (див. GameDB.PLACE_SCHEMA); для невідомого id — порожній запис.
static func place(id: String) -> Dictionary:
	return GameDB.table("places").get(id, _EMPTY)


static func is_place(id: String) -> bool:
	return GameDB.table("places").has(id)


## Місця в порядку файлу (лише для читання).
static func place_ids() -> Array:
	return GameDB.ids("places")


## Місто (див. GameDB.CITY_SCHEMA); для невідомого id — порожній запис.
static func city(id: String) -> Dictionary:
	return GameDB.table("cities").get(id, _EMPTY)


static func is_city(id: String) -> bool:
	return GameDB.table("cities").has(id)


## Міста в порядку файлу (лише для читання).
static func city_ids() -> Array:
	return GameDB.ids("cities")


## Далекий край (див. GameDB.REGION_SCHEMA); для невідомого id — порожній запис.
static func region(id: String) -> Dictionary:
	return GameDB.table("regions").get(id, _EMPTY)


static func is_region(id: String) -> bool:
	return GameDB.table("regions").has(id)


## Далекі краї в порядку показу (порядок файлу): чотири сторони світу довкола старої мапи,
## три краї Московії та Семигород за Карпатами. Їхні місцевості ростуть із рівнем героя ("scale").
static func region_ids() -> Array:
	return GameDB.ids("regions")


## Значок місця на мапі й у довіднику: свій («icon»: замок, шахта, острів), Башта, а інакше —
## за краєвидом (biomes.json: «icon» поля чи «dungeon_icon» печери).
static func place_icon(L: Dictionary) -> String:
	if L.has("icon"):
		return str(L["icon"])
	if L.get("tower", false):
		return "tower"
	var dungeon: bool = L["type"] == "dungeon"
	return str(GameDB.row("biomes", str(L["biome"])).get("dungeon_icon" if dungeon else "icon", "cave" if dungeon else "sabres"))


## Де в місті чекають ті, хто має справу до героя (вкладка міста, див. Game.hall_rows): міста мають
## ратушу, а Січ, козацький стан і святі місця називають цю будівлю по-своєму («hall» у записі міста).
static func hall_name(city_id: String) -> String:
	return str(city(city_id).get("hall", ""))


## Рівень місцевості для героя. Далекі краї ("scale") ростуть разом із ним: рівень не нижчий за позначений.
static func loc_level(L: Dictionary, hero_level: int) -> int:
	return maxi(int(L["level"]), hero_level) if L.get("scale", false) else int(L["level"])

## Імена, множини й трофеї нечисті — у data/mobs.json (див. GameDB).

const LOYALTY_THRESHOLDS := [0, 100, 250, 500]
const LOYALTY_NAMES := ["Чужинець", "Знайомий", "Шанований", "Побратим"]
const LOYALTY_DISCOUNT := [0.0, 0.05, 0.1, 0.2]
const MAX_ACTIVE_QUESTS := 5
const MAX_COMPANIONS := 2

## Найманці (ім'я, ціна, сила, механіка бою) — у data/companions.json (див. GameDB).


static func loyalty_level(points: int) -> int:
	var lvl := 0
	for i in LOYALTY_THRESHOLDS.size():
		if points >= LOYALTY_THRESHOLDS[i]:
			lvl = i
	return lvl


static func place_name(id: String) -> String:
	if is_city(id):
		return city(id)["name"]
	if is_place(id):
		return place(id)["name"]
	if id == "hutir":
		return "Козацький хутір"
	var spots: Dictionary = load("res://scripts/data/activities.gd").SPOTS
	if spots.has(id):
		return spots[id]["name"]
	return id
