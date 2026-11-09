extends RefCounted
## Опис характеристик, дерева вмінь і дерева пасивних перків.
## Щоб додати новий вузол — достатньо дописати його сюди та реалізувати ефект у player.gd.

const STAT_BASE := 5

# ======================= Баланс (усі ключові числа тут) =======================
const ENEMY_HP_MULT := 1.5  # загальна «товщина» нечисті
const ENEMY_HP_PER_LEVEL := 0.25  # +25% здоров'я ворога за рівень місцевості
const ENEMY_DMG_PER_LEVEL := 0.12  # +12% шкоди ворога за рівень
const ENEMY_XP_PER_LEVEL := 0.25  # +25% досвіду з ворога за рівень
const COIN_GOLD_RATIO := 0.34  # скільки гривень дає монета відносно її досвіду
const ITEM_DROP_CHANCE := 0.03  # шанс речі з рядового ворога
const FIELD_GOAL_BASE := 40  # скільки нечисті треба знищити для зачистки
const FIELD_GOAL_PER_LEVEL := 5
const BOSS_HP_MULT := 8.0  # бос у стільки разів «товстіший» за звичайного ворога
const BOSS_XP_MULT := 8
const DUNGEON_ROOM_BASE := 6  # ворогів у кімнаті печери: база + за номер кімнати
const DUNGEON_ROOM_PER := 3
const POTION_MAX := 5  # скільки зілля можна нести
const POTION_HEAL := 0.4  # частка здоров'я, яку відновлює зілля
const POTION_CD := 6.0  # секунд між ковтками
const POTION_START := 2
const POTION_DROP_CHANCE := 0.02


static func potion_price(hero_level: int) -> int:
	return 25 + 10 * hero_level


## Досвід, потрібний, щоб перейти з рівня l на l+1.
## До 30-го рівня крива м'яка (сюжет), далі — крутішає: гра після сюжету розрахована на десятки годин.
static func xp_for_level(l: int) -> int:
	var base := 200 + 150 * l + 15 * l * l
	if l < 30:
		return base
	return int(base * pow(1.0 + 0.6 * (l - 29), 0.8))


static func coin_gold(xp_value: int) -> int:
	return maxi(1, roundi(xp_value * COIN_GOLD_RATIO))

const STAT_POINTS_PER_LEVEL := 3
const SKILL_POINTS_PER_LEVEL := 1  # очок вмінь за рівень майстерності
const PERK_POINTS_PER_LEVEL := 1  # очок Загартування за кожні Classes.HARDEN_EVERY рівнів героя
const PERK_TIER_STEP := 2  # скільки очок треба вкласти в гілку, щоб відкрити наступний ярус

const STATS := [
	{"id": "str", "name": "Сила", "desc": "+6% шкоди"},
	{"id": "agi", "name": "Спритність", "desc": "+4% швидкості удару, +1.5% криту, +1.5% бігу"},
	{"id": "vit", "name": "Витривалість", "desc": "+12 здоров'я, +1% захисту"},
	{"id": "spi", "name": "Характерництво", "desc": "+5% сили вмінь, -4% перезарядки вмінь"},
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

const SLOTS := ["weapon", "head", "body", "belt", "boots", "amulet"]
const SLOT_NAMES := {"weapon": "Зброя", "head": "Шапка", "body": "Жупан", "belt": "Пояс", "boots": "Чоботи", "amulet": "Оберіг"}
const INVENTORY_SIZE := 24
const MAX_UPGRADE := 10
const UPGRADE_BONUS := 0.12  # +12% до всіх бонусів речі за кожен рівень заточки
const SHARPEN_CHANCE := [1.0, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.25]
const SHARPEN_RISK_FROM := 6  # з цієї заточки невдача знижує рівень на 1

const RARITY_NAMES := ["Звичайна", "Добротна", "Рідкісна", "Легендарна"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.85), Color(0.45, 0.9, 0.4), Color(0.4, 0.65, 1.0), Color(1.0, 0.6, 0.15)]
const LEGEND_EPITHETS := ["Громовиця", "Вовча", "Чорноморська", "Січова", "Перунова", "Хортицька", "Буревісна", "Сіркова"]

# Типи зброї: множники шкоди, перезарядки удару, дальності, ширини дуги та відкидання.
const WEAPON_TYPES := {
	"sabre": {"name": "Шабля", "dmg": 1.0, "cd": 1.0, "range": 1.0, "arc": 1.0, "kb": 1.0,
		"hint": "Збалансована"},
	"mace": {"name": "Булава", "dmg": 1.45, "cd": 1.35, "range": 0.9, "arc": 1.1, "kb": 1.8,
		"hint": "Повільна, б'є сильно і далеко відкидає"},
	"pike": {"name": "Спис", "dmg": 1.1, "cd": 1.15, "range": 1.5, "arc": 0.55, "kb": 1.2,
		"hint": "Довгий, але вузький удар"},
	"staff": {"name": "Посох", "dmg": 1.0, "cd": 1.1, "range": 1.0, "arc": 1.0, "kb": 0.5,
		"hint": "Волхвів: б'є іскрами здалеку, сила — від Характерництва"},
	"pishchal": {"name": "Пищаль", "dmg": 1.1, "cd": 1.5, "range": 1.0, "arc": 1.0, "kb": 1.2,
		"hint": "Самопальника: куля пробиває ворогів, сила — від Спритності"},
}
## Яку зброю генерувати в здобичі й крамницях (виставляє гра під клас героя; порожньо — будь-яку).
static var weapon_pool: Array = []

const ARMOR_TYPES := {
	"head": ["Смушкова шапка", "Кучма", "Козацька шапка"],
	"body": ["Жупан", "Кунтуш", "Кольчуга"],
	"belt": ["Пояс", "Шовковий пояс", "Черес"],
	"boots": ["Чоботи", "Сап'янці", "Похідні чоботи"],
	"amulet": ["Оберіг", "Ладанка", "Мотанка"],
}

# Основний бонус кожного слота
const SLOT_PRIMARY := {"weapon": "flat_dmg", "head": "hp", "body": "armor", "belt": "vit", "boots": "speed", "amulet": "skill_power"}

# Шаблон тексту, кількість знаків після коми
const STAT_FMT := {
	"str": ["+%s до Сили", 0], "agi": ["+%s до Спритності", 0], "vit": ["+%s до Витривалості", 0],
	"spi": ["+%s до Характерництва", 0], "flat_dmg": ["+%s шкоди", 0], "dmg_pct": ["+%s%% шкоди", 0],
	"crit": ["+%s%% шансу криту", 1], "aspd": ["+%s%% швидкості удару", 0], "hp": ["+%s здоров'я", 0],
	"armor": ["+%s%% захисту", 1], "regen": ["+%s здоров'я/с", 1], "lifesteal": ["+%s%% вампіризму", 1],
	"speed": ["+%s%% швидкості бігу", 0], "xp": ["+%s%% досвіду", 0], "skill_power": ["+%s%% сили вмінь", 0],
	"skill_cd": ["-%s%% перезарядки вмінь", 0], "pickup": ["+%s%% радіусу збору", 0], "gold": ["+%s%% гривень", 0],
}
const INT_STATS := ["str", "agi", "vit", "spi"]
const AFFIX_POOL := ["str", "agi", "vit", "spi", "dmg_pct", "crit", "aspd", "hp", "armor", "regen",
	"lifesteal", "speed", "xp", "skill_power", "skill_cd", "pickup", "gold"]


static func fmt_stat(id: String, value: float) -> String:
	var f: Array = STAT_FMT[id]
	var num := ("%.1f" % value) if f[1] == 1 else str(roundi(value))
	return f[0] % num


static func _roll_value(id: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + 0.15 * rarity
	match id:
		"str", "agi", "vit", "spi":
			return float(randi_range(1, 1 + ilvl / 3 + rarity / 2))
		"dmg_pct": return (randf_range(3, 6) + 0.4 * ilvl) * q
		"crit": return (randf_range(1.5, 3.5) + 0.15 * ilvl) * q
		"aspd": return (randf_range(3, 6) + 0.3 * ilvl) * q
		"hp": return (randf_range(8, 16) + 3.0 * ilvl) * q
		"armor": return (randf_range(1.5, 3.0) + 0.2 * ilvl) * q
		"regen": return (randf_range(0.3, 0.7) + 0.05 * ilvl) * q
		"lifesteal": return (randf_range(0.8, 1.6) + 0.05 * ilvl) * q
		"speed": return (randf_range(2, 4) + 0.2 * ilvl) * q
		"xp": return (randf_range(4, 8) + 0.4 * ilvl) * q
		"skill_power": return (randf_range(4, 7) + 0.4 * ilvl) * q
		"skill_cd": return (randf_range(2, 4) + 0.2 * ilvl) * q
		"pickup": return randf_range(10, 20) * q
		"gold": return (randf_range(8, 15) + ilvl) * q
	return 0.0


static func _primary_value(slot: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + 0.15 * rarity
	match slot:
		"weapon": return (3.0 + 1.2 * ilvl) * q
		"head": return (10.0 + 4.0 * ilvl) * q
		"body": return (3.0 + 0.4 * ilvl) * q
		"belt": return float(1 + ilvl / 4 + rarity / 2)
		"boots": return (3.0 + 0.3 * ilvl) * q
		"amulet": return (5.0 + 0.6 * ilvl) * q
	return 0.0


static func roll_rarity(wave: int, min_rarity: int = 0) -> int:
	var w := [60.0, 28.0, 10.0 + 0.8 * wave, 2.0 + 0.3 * wave]
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
	if slot == "":
		slot = ["weapon", "weapon", "head", "body", "belt", "boots", "amulet"][randi() % 7]
	var name := ""
	if slot == "weapon":
		if type == "":
			var pool: Array = weapon_pool if not weapon_pool.is_empty() else ["sabre", "mace", "pike"]
			type = pool[randi() % pool.size()]
		name = WEAPON_TYPES[type]["name"]
	else:
		var names: Array = ARMOR_TYPES[slot]
		name = names[mini(names.size() - 1, randi() % names.size())]
	if rarity == 3:
		name += " «%s»" % LEGEND_EPITHETS[randi() % LEGEND_EPITHETS.size()]
	var primary: String = SLOT_PRIMARY[slot]
	var affixes := {}
	var pool := AFFIX_POOL.duplicate()
	pool.erase(primary)
	pool.shuffle()
	for i in rarity:
		affixes[pool[i]] = _roll_value(pool[i], ilvl, rarity)
	return {
		"slot": slot, "type": type, "name": name, "rarity": rarity, "ilvl": ilvl, "up": 0, "spent": 0,
		"base": {primary: _primary_value(slot, ilvl, rarity)}, "affixes": affixes,
	}


static func item_title(item: Dictionary) -> String:
	return item["name"] + (" +%d" % item["up"] if item["up"] > 0 else "")


## Усі бонуси речі з урахуванням заточки.
static func item_stats(item: Dictionary) -> Dictionary:
	var mult: float = 1.0 + UPGRADE_BONUS * item["up"]
	var out := {}
	for src in [item["base"], item["affixes"]]:
		for id in src:
			var v: float = src[id] * mult
			if id in INT_STATS:
				v = floorf(v)
			out[id] = out.get(id, 0.0) + v
	return out


static func sharpen_cost(item: Dictionary) -> int:
	return int(20 * (item["up"] + 1) * (1.0 + 0.5 * item["rarity"]) * (1.0 + 0.25 * item["ilvl"]))


static func sharpen_chance(item: Dictionary) -> float:
	return SHARPEN_CHANCE[mini(item["up"], SHARPEN_CHANCE.size() - 1)]


## Множник ціни продажу (ярмарок у місті — ×2; виставляє гра при вході в місто).
static var sell_mult: float = 1.0


static func sell_price(item: Dictionary) -> int:
	return int((8 * (1 + item["rarity"]) * (1.0 + 0.35 * item["ilvl"]) + item["spent"] * 0.3) * sell_mult)


# ======================= Світ =======================
# Позиції — реальні географічні координати (довгота, широта); мапа проєктує їх на екран.

const CITIES := {
	"sich": {"name": "Запорозька Січ", "pos": Vector2(35.1, 47.75), "level": 1,
		"desc": "Козацька столиця за порогами. Тут усе починається."},
	"chyhyryn": {"name": "Чигирин", "pos": Vector2(32.66, 49.08), "level": 2,
		"desc": "Гетьманська столиця над Тясмином."},
	"poltava": {"name": "Полтава", "pos": Vector2(34.55, 49.6), "level": 3,
		"desc": "Полкове місто на Ворсклі."},
	"kyiv": {"name": "Київ", "pos": Vector2(30.52, 50.45), "level": 4,
		"desc": "Стародавня столиця на Дніпрових кручах."},
	"chernihiv": {"name": "Чернігів", "pos": Vector2(31.3, 51.5), "level": 6,
		"desc": "Княже місто серед поліських лісів."},
	"kamianets": {"name": "Кам'янець", "pos": Vector2(26.58, 48.68), "level": 7,
		"desc": "Неприступна фортеця над Смотричем."},
	"kapyshche": {"name": "Капище на Говерлі", "pos": Vector2(24.5, 48.16), "level": 3,
		"desc": "Осідок волхвів Карпатського кола на схилах Говерли. Тут посвячують у волхви."},
	"verkhovyna": {"name": "Верховина", "pos": Vector2(25.35, 47.95), "level": 6,
		"desc": "Гуцульське село серед полонин. Тут живе знахарка Параска — наставниця знахарів."},
	"pip_ivan": {"name": "Піп Іван", "pos": Vector2(24.75, 47.5), "level": 8,
		"desc": "Найгрозовіша вершина Чорногори. На ній — капище Перуна й жрець Громобій."},
	"molfar_hut": {"name": "Хата мольфара", "pos": Vector2(23.75, 47.45), "level": 8,
		"desc": "Самотня хата на чорногірських схилах. Мольфар Яким кличе дощ і проганяє град."},
	"lviv": {"name": "Львів", "pos": Vector2(24.03, 49.84), "level": 9,
		"desc": "Багате торгове місто, ворота на захід."},
}

const LOCATIONS := {
	"ridne_selo": {"name": "Рідне село", "type": "field", "biome": "village", "pos": Vector2(36.3, 49.75), "level": 1, "goal": 15,
		"enemies": ["zarazhenyi", "mavka"], "desc": "Твоє рідне село на Слобожанщині, біля самого московського кордону. Заражені прийшли сюди першими."},
	"wild_field": {"name": "Дике Поле", "type": "field", "biome": "steppe", "pos": Vector2(37.6, 48.15), "level": 1,
		"enemies": ["mavka", "upyr", "zarazhenyi"], "desc": "Безкраї степи, куди першими докотилися заражені загони з півночі."},
	"rapids": {"name": "Дніпрові пороги", "type": "field", "biome": "river", "pos": Vector2(34.5, 48.75), "level": 2,
		"enemies": ["mavka", "bolotianyk"], "desc": "Бурхливі пороги, де мавки заманюють у воду."},
	"zmii_cave": {"name": "Змієва печера", "type": "dungeon", "biome": "cave", "pos": Vector2(33.6, 47.2), "level": 3,
		"rooms": 4, "enemies": ["mavka", "upyr", "bolotianyk"], "boss": "zmii",
		"desc": "Глибоке лігво під кручами. Там спить Триголовий Змій."},
	"black_forest": {"name": "Чорний ліс", "type": "field", "biome": "forest", "pos": Vector2(32.2, 48.45), "level": 4,
		"enemies": ["mavka", "vovkulaka", "zarazhenyi"], "desc": "Темна пуща, де стали табором заражені московити і виють вовкулаки."},
	"crypt": {"name": "Упирячий склеп", "type": "dungeon", "biome": "cave", "pos": Vector2(33.0, 50.85), "level": 6,
		"rooms": 5, "enemies": ["upyr", "vovkulaka"], "boss": "upyr",
		"desc": "Старі підземелля, де править Упир-володар."},
	"polissia": {"name": "Поліські болота", "type": "field", "biome": "swamp", "pos": Vector2(27.6, 51.35), "level": 6,
		"enemies": ["bolotianyk", "upyr", "zarazhenyi"], "desc": "Трясовина, туман і болотяники. Тут пройшли заражені загони."},
	"pidstupy": {"name": "Підступи до Чорногори", "type": "field", "biome": "mountain", "pos": Vector2(25.5, 49.15), "level": 3, "goal": 25,
		"enemies": ["zarazhenyi", "vovkulaka", "mavka"], "desc": "Гірські стежки до капища волхвів. Заражені шукають тут дорогу на Говерлу."},
	"chornohora": {"name": "Чорногора", "type": "field", "biome": "mountain", "pos": Vector2(23.4, 47.85), "level": 9,
		"enemies": ["vovkulaka", "upyr", "bolotianyk"], "desc": "Високі Карпати, сніг і вовчі зграї."},
	"bilovezha": {"name": "Біловезька пуща", "type": "field", "biome": "forest", "pos": Vector2(23.9, 52.7), "level": 8,
		"enemies": ["vovkulaka", "mavka", "upyr"], "desc": "Прадавня пуща на межі з Польщею. Тут водяться найлютіші вовкулаки."},
	"bryansk_forest": {"name": "Брянські ліси", "type": "field", "biome": "forest", "pos": Vector2(34.0, 53.1), "level": 11,
		"enemies": ["zarazhenyi", "vovkulaka", "upyr"], "desc": "Прикордонні ліси на московських землях — звідси розповзається зараза."},
	"chaklun_lair": {"name": "Лігво чаклуна", "type": "dungeon", "biome": "plague", "pos": Vector2(35.4, 53.7), "level": 12,
		"rooms": 6, "enemies": ["zarazhenyi", "vovkulaka", "upyr"], "boss": "chaklun",
		"desc": "Отруєні печери на московських землях. Звідси чаклун Путіноїда розсилає заразу."},
	"dovbush_cave": {"name": "Печера Довбуша", "type": "dungeon", "biome": "cave", "pos": Vector2(23.0, 49.05), "level": 10,
		"rooms": 6, "enemies": ["vovkulaka", "upyr", "bolotianyk"], "boss": "vovkulaka",
		"desc": "Скарби опришків стереже Вовкулака-ватажок."},
	# ---- Розділ III: Карпатська варта ----
	"kamianets_walls": {"name": "Кам'янецькі мури", "type": "field", "biome": "mountain", "pos": Vector2(27.6, 48.05), "level": 13,
		"enemies": ["zarazhenyi", "pishchalnyk", "chort"], "desc": "Під мурами фортеці стала облогою Кощієва рать: пищальники й чорти."},
	"koshchii_tower": {"name": "Кощієва вежа", "type": "dungeon", "biome": "plague", "pos": Vector2(30.4, 54.4), "level": 16,
		"rooms": 6, "enemies": ["zarazhenyi", "pishchalnyk", "chort"], "boss": "koshchii",
		"desc": "Кістяна вежа на білоруських болотах. Тут сидить Кощій — воєвода Путіноїда, якого не бере смерть."},
	# ---- Розділ IV: Похід на Північ ----
	"smolensk_road": {"name": "Смоленський шлях", "type": "field", "biome": "forest", "pos": Vector2(33.6, 54.6), "level": 18,
		"enemies": ["zarazhenyi", "pishchalnyk", "chort", "vovkulaka"], "desc": "Старий шлях на Москву. Кожна верста тут полита кров'ю."},
	"mozhaisk": {"name": "Можайські болота", "type": "field", "biome": "swamp", "pos": Vector2(35.9, 55.5), "level": 20,
		"enemies": ["pishchalnyk", "bolotianyk", "chort", "zarazhenyi"], "desc": "Останні болота перед Москвою. Зараза тут така густа, що її видно оком."},
	# ---- Після сюжету ----
	"hlybyny": {"name": "Глибини зарази", "type": "dungeon", "biome": "plague", "pos": Vector2(38.6, 55.35), "level": 22,
		"rooms": 4, "enemies": ["zarazhenyi", "pishchalnyk", "chort"], "boss": "putinoid", "endless": true,
		"desc": "Корені зарази під Кремлем: печера без дна. Відкривається після перемоги над Путіноїдом."},
	"bashta": {"name": "Башта Кощія", "type": "dungeon", "biome": "cave", "pos": Vector2(36.9, 56.05), "level": 15,
		"rooms": 2, "enemies": ["zarazhenyi", "pishchalnyk", "chort"], "boss": "koshchii", "endless": true, "tower": true,
		"desc": "Кістяна башта посеред Москви: безкінечний підйом. Відкривається з 15-го рівня героя."},
	# ---- Розділ V: Кремль ----
	"kremlin": {"name": "Кремль", "type": "dungeon", "biome": "plague", "pos": Vector2(37.62, 55.75), "level": 22,
		"rooms": 7, "enemies": ["zarazhenyi", "pishchalnyk", "chort", "upyr"], "boss": "putinoid",
		"desc": "Червоні мури, за якими сто років сидить Путіноїд. Серце зарази."},
}

const ENEMY_NAMES := {"mavka": "Мавка", "upyr": "Упир", "bolotianyk": "Болотяник", "vovkulaka": "Вовкулака", "zarazhenyi": "Заражений московит",
	"zmii": "Змій", "chaklun": "Чаклун Путіноїда", "chort": "Чорт", "pishchalnyk": "Заражений пищальник", "koshchii": "Кощій", "putinoid": "Путіноїд",
	"baba_yaha": "Баба Яга", "solovei": "Соловей-розбійник", "lykho": "Лихо Однооке", "oprychnyk": "Опричник-кат"}
const ENEMY_PLURAL := {"mavka": "мавок", "upyr": "упирів", "bolotianyk": "болотяників", "vovkulaka": "вовкулак", "zarazhenyi": "заражених",
	"zmii": "зміїв", "chaklun": "чаклунів", "chort": "чортів", "pishchalnyk": "пищальників", "koshchii": "кощіїв", "putinoid": "путіноїдів",
	"baba_yaha": "бабів яг", "solovei": "солов'їв", "lykho": "лих", "oprychnyk": "опричників"}
const BOSS_NAMES := {"zmii": "Триголовий Змій", "upyr": "Упир-володар", "vovkulaka": "Вовкулака-ватажок", "chaklun": "Чаклун Путіноїда",
	"koshchii": "Кощій Безсмертний", "putinoid": "Путіноїд, кремлівський упир-цар",
	"baba_yaha": "Баба Яга Кістяна Нога", "solovei": "Соловей-розбійник", "lykho": "Лихо Однооке", "oprychnyk": "Малюта, опричник-кат"}
const QUEST_ITEMS := {"mavka": "Вінок мавки", "upyr": "Ікло упиря", "bolotianyk": "Болотяна твань", "vovkulaka": "Вовча шкура", "zarazhenyi": "Зразок зарази",
	"chort": "Чортів ріг", "pishchalnyk": "Наказ воєводи"}

const LOYALTY_THRESHOLDS := [0, 100, 250, 500]
const LOYALTY_NAMES := ["Чужинець", "Знайомий", "Шанований", "Побратим"]
const LOYALTY_DISCOUNT := [0.0, 0.05, 0.1, 0.2]
const MAX_ACTIVE_QUESTS := 5
const MAX_COMPANIONS := 2

const COMPANIONS := {
	"dzhura": {"name": "Джура", "desc": "Молодий козак із шаблею.\nБ'ється пліч-о-пліч.", "cost": 120, "loyalty": 0,
		"hp": 90.0, "hp_lvl": 15.0, "dmg": 8.0, "dmg_lvl": 2.0, "range": 55.0, "cd": 0.7, "speed": 250.0,
		"color": Color(0.2, 0.45, 0.75)},
	"strilets": {"name": "Стрілець", "desc": "Влучно стріляє з рушниці\nз безпечної відстані.", "cost": 250, "loyalty": 1,
		"hp": 60.0, "hp_lvl": 10.0, "dmg": 14.0, "dmg_lvl": 3.0, "range": 420.0, "cd": 1.6, "speed": 230.0,
		"color": Color(0.3, 0.5, 0.25)},
	"znakhar": {"name": "Знахарка", "desc": "Лікує козака й загін\nцілющими травами.", "cost": 400, "loyalty": 2,
		"hp": 55.0, "hp_lvl": 9.0, "dmg": 5.0, "dmg_lvl": 1.0, "range": 300.0, "cd": 1.4, "speed": 240.0,
		"heal": 10.0, "heal_lvl": 2.5, "color": Color(0.85, 0.85, 0.9)},
}


static func loyalty_level(points: int) -> int:
	var lvl := 0
	for i in LOYALTY_THRESHOLDS.size():
		if points >= LOYALTY_THRESHOLDS[i]:
			lvl = i
	return lvl


static func place_name(id: String) -> String:
	if CITIES.has(id):
		return CITIES[id]["name"]
	if LOCATIONS.has(id):
		return LOCATIONS[id]["name"]
	if id == "hutir":
		return "Козацький хутір"
	return id
