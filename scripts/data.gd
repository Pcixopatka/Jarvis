extends RefCounted
## Опис характеристик, дерева вмінь і дерева пасивних перків.
## Щоб додати новий вузол — достатньо дописати його сюди та реалізувати ефект у player.gd.

const STAT_BASE := 5
const STAT_POINTS_PER_LEVEL := 3
const SKILL_POINTS_PER_LEVEL := 1
const PERK_POINTS_PER_LEVEL := 1
const PERK_TIER_STEP := 2  # скільки очок треба вкласти в гілку, щоб відкрити наступний ярус

const STATS := [
	{"id": "str", "name": "Сила", "desc": "+6% шкоди"},
	{"id": "agi", "name": "Спритність", "desc": "+4% швидкості удару, +1.5% криту, +1.5% бігу"},
	{"id": "vit", "name": "Витривалість", "desc": "+12 здоров'я, +1% захисту"},
	{"id": "spi", "name": "Характерництво", "desc": "+5% сили вмінь, -4% перезарядки вмінь"},
]

# Дерево вмінь: у кожній гілці — активне вміння, покращення і фінальне вміння.
# "req" — які вміння і якого рангу потрібні, щоб вивчити вузол.
const SKILL_BRANCHES := [
	{"name": "Шабля", "nodes": [
		{"id": "whirl", "name": "Вихор", "max": 5, "req": {}, "active": true,
			"desc": "Кругова атака навколо козака.\n+20% шкоди, +8% радіуса за ранг"},
		{"id": "whirl_cd", "name": "Гострий вітер", "max": 3, "req": {"whirl": 2},
			"desc": "-10% перезарядки Вихору\nза ранг"},
		{"id": "storm", "name": "Буревій", "max": 1, "req": {"whirl": 3, "whirl_cd": 1},
			"desc": "Вихор притягує нечисть\nі б'є вдруге"},
	]},
	{"name": "Характерник", "nodes": [
		{"id": "lightning", "name": "Блискавка Перуна", "max": 5, "req": {}, "active": true,
			"desc": "Б'є блискавкою 2+ранг\nнайближчих ворогів"},
		{"id": "chain", "name": "Ланцюг", "max": 2, "req": {"lightning": 2},
			"desc": "+2 цілі блискавки\nза ранг"},
		{"id": "wrath", "name": "Гнів Перуна", "max": 1, "req": {"lightning": 3, "chain": 1},
			"desc": "Блискавка сповільнює\nворогів на 2 с"},
	]},
	{"name": "Самопал", "nodes": [
		{"id": "musket", "name": "Постріл", "max": 5, "req": {}, "active": true,
			"desc": "Куля пробиває ворогів наскрізь.\n+18% шкоди за ранг"},
		{"id": "reload", "name": "Швидке набивання", "max": 3, "req": {"musket": 2},
			"desc": "-12% перезарядки самопала\nза ранг"},
		{"id": "buckshot", "name": "Картеч", "max": 1, "req": {"musket": 3, "reload": 1},
			"desc": "Постріл випускає\n5 куль віялом"},
	]},
]

# Дерево перків: гілки → яруси → перки. Ярус N відкривається, коли у гілку вкладено N * PERK_TIER_STEP очок.
const PERK_BRANCHES := [
	{"name": "Воїн", "tiers": [
		[{"id": "sharp", "name": "Гостра шабля", "max": 3, "desc": "+8% шкоди"},
		 {"id": "reach", "name": "Довга шабля", "max": 3, "desc": "+8% дальності\nудару"}],
		[{"id": "luck", "name": "Козацька вдача", "max": 3, "desc": "+5% шансу\nкриту"},
		 {"id": "fury", "name": "Лють", "max": 3, "desc": "+6% швидкості\nудару"}],
		[{"id": "thirst", "name": "Жага бою", "max": 3, "desc": "2% шкоди\nлікує козака"},
		 {"id": "cleave", "name": "Широкий замах", "max": 2, "desc": "+20° ширина\nудару"}],
		[{"id": "deadly", "name": "Смертельний удар", "max": 1, "desc": "Крит б'є x3\nзамість x2"}],
	]},
	{"name": "Захисник", "tiers": [
		[{"id": "tough", "name": "Міцна шкіра", "max": 3, "desc": "+15 здоров'я"},
		 {"id": "ward", "name": "Оберіг", "max": 3, "desc": "-5% отриманої\nшкоди"}],
		[{"id": "regen", "name": "Загартування", "max": 3, "desc": "+0.6 здоров'я\nза секунду"},
		 {"id": "roll", "name": "Спритний перекид", "max": 2, "desc": "-12% перезарядки\nперекиду"}],
		[{"id": "varenyk", "name": "Бабусині вареники", "max": 2, "desc": "Вареники частіше\nі ситніші"},
		 {"id": "thorns", "name": "Колючий жупан", "max": 2, "desc": "Повертає 25%\nшкоди нападнику"}],
		[{"id": "unbreak", "name": "Незламний", "max": 1, "desc": "Раз за хвилю\nне гине від удару"}],
	]},
	{"name": "Запорожець", "tiers": [
		[{"id": "boots", "name": "Легкі чоботи", "max": 3, "desc": "+5% швидкості\nбігу"},
		 {"id": "purse", "name": "Жадібний гаманець", "max": 2, "desc": "+25% радіус\nзбору дукатів"}],
		[{"id": "kobzar", "name": "Кобзарева наука", "max": 3, "desc": "+10% досвіду"},
		 {"id": "focus", "name": "Зосередженість", "max": 3, "desc": "-6% перезарядки\nвмінь"}],
		[{"id": "dash_strike", "name": "Удар з перекиду", "max": 1, "desc": "Перекид ранить\nворогів на шляху"},
		 {"id": "spirit", "name": "Характерний дух", "max": 3, "desc": "+10% сили\nвмінь"}],
		[{"id": "sich", "name": "Січова закалка", "max": 1, "desc": "+2 до всіх\nхарактеристик"}],
	]},
]

const ACTIVE_SKILLS := ["whirl", "lightning", "musket"]
const ACTIVE_LABELS := {"whirl": "Вихор", "lightning": "Перун", "musket": "Самопал"}


static func find_skill(id: String) -> Dictionary:
	for b in SKILL_BRANCHES:
		for n in b["nodes"]:
			if n["id"] == id:
				return n
	return {}


static func skill_name(id: String) -> String:
	return find_skill(id).get("name", id)


## Повертає [індекс гілки, індекс ярусу] перка або [-1, -1].
static func find_perk(id: String) -> Array:
	for bi in PERK_BRANCHES.size():
		var tiers: Array = PERK_BRANCHES[bi]["tiers"]
		for ti in tiers.size():
			for p in tiers[ti]:
				if p["id"] == id:
					return [bi, ti, p]
	return [-1, -1, {}]
