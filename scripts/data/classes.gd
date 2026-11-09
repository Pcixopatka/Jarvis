extends RefCounted
## Класи героя (у дусі Ragnarok): Селянин → Козак (Січ) / Волхв (Карпати) → спеціалізації (далі).
## Кожен клас має свій рівень майстерності (job level), дерево вмінь, дозволену зброю
## і вроджені множники здоров'я та шкоди (воїн міцніший, маг — із більшою наснагою).
## Рівень майстерності дає по 1 очку вмінь; після зміни класу він скидається на 1, а вивчене лишається.
##
## Вузол дерева: id, name, max, req {id: ранг}, active (кнопка в бою), cost (наснага), desc.
## Пасивні вузли з id колишніх перків (sharp, tough, ward…) діють так само, як ті перки.

const CLASSES := {
	"peasant": {"name": "Селянин", "tier": 0, "job_max": 10, "next": ["cossack", "volkhv"],
		"weapons": ["pike", "sabre", "mace"], "mana_mult": 0.8, "regen_mult": 0.8, "address": "хлопче", "hp_mult": 1.0, "dmg_mult": 1.0,
		"desc": "Простий хлопець із хутора. Набирається сили, щоб обрати свою дорогу."},
	"cossack": {"name": "Козак", "tier": 1, "job_max": 40, "next": ["zaporozhets", "plastun", "samopalnyk", "kharakternyk"],
		"weapons": ["sabre", "mace", "pike"], "mana_mult": 1.0, "regen_mult": 1.5, "address": "козаче", "hp_mult": 1.3, "dmg_mult": 1.15,
		"where": "sich", "desc": "Воїн Січі: шабля, булава чи спис, самопал і бойовий клич. Влучні удари поповнюють наснагу."},
	"volkhv": {"name": "Волхв", "tier": 1, "job_max": 40, "next": [],
		"weapons": ["staff"], "mana_mult": 2.0, "regen_mult": 2.2, "address": "волхве", "hp_mult": 1.0, "dmg_mult": 1.0,
		"where": "kapyshche", "desc": "Знавець вогню, трав і оберегів із Карпат. Б'є іскрами здалеку; сила — від Характерництва."},
	# ---- Спеціалізації Козака (Січ) ----
	"zaporozhets": {"name": "Запорожець", "tier": 2, "job_max": 50, "next": [], "parent": "cossack",
		"weapons": ["sabre", "mace", "pike"], "mana_mult": 1.0, "regen_mult": 1.6, "address": "козаче", "hp_mult": 1.6, "dmg_mult": 1.25,
		"where": "sich", "mentor": "myron", "desc": "Важкий воїн: тримає ворогів біля себе, оглушує, що слабший — то лютіший."},
	"plastun": {"name": "Пластун", "tier": 2, "job_max": 50, "next": [], "parent": "cossack",
		"weapons": ["sabre", "pike"], "mana_mult": 1.1, "regen_mult": 1.6, "address": "козаче", "hp_mult": 1.35, "dmg_mult": 1.3,
		"where": "sich", "mentor": "sava", "desc": "Розвідник: пастки, Тінь, кидок списа, смертельні криті."},
	"samopalnyk": {"name": "Самопальник", "tier": 2, "job_max": 50, "next": [], "parent": "cossack",
		"weapons": ["pishchal", "sabre"], "mana_mult": 1.1, "regen_mult": 1.6, "address": "козаче", "hp_mult": 1.3, "dmg_mult": 1.1,
		"where": "sich", "mentor": "okhrim", "desc": "Стрілець із пищаллю: картеч, прицільний постріл, бочка пороху. Сила — від Спритності."},
	"kharakternyk": {"name": "Характерник", "tier": 2, "job_max": 50, "next": [], "parent": "cossack",
		"weapons": ["sabre", "pike"], "mana_mult": 1.5, "regen_mult": 1.9, "address": "козаче", "hp_mult": 1.4, "dmg_mult": 1.2,
		"where": "sich", "mentor": "yarema", "desc": "Воїн-чаклун: Вовча подоба, «Куля не бере», замовлена шабля, відвід очей."},
}

## З якого рівня майстерності можна змінити клас (за ступенем).
const JOB_CHANGE_AT := {0: 10, 1: 30}
const BASE_LEVEL_MAX := 99
const HARDEN_EVERY := 2  # одне очко Загартування за кожні 2 рівні героя


## Досвід майстерності до наступного рівня.
static func job_xp_for(tier: int, jl: int) -> int:
	match tier:
		0:
			return 40 + 30 * jl
		1:
			return 100 + 60 * jl + 6 * jl * jl
	return 300 + 160 * jl + 18 * jl * jl


const TREES := {
	"peasant": [
		{"name": "Селянська наука", "nodes": [
			{"id": "vyly", "name": "Удар вилами", "max": 5, "req": {}, "active": true, "cost": 8,
				"desc": "Сильний випад уперед, б'є всіх на лінії.\n+15% шкоди за ранг"},
			{"id": "first_aid", "name": "Перша допомога", "max": 3, "req": {}, "active": true, "cost": 15,
				"desc": "Перев'язати рани травами:\n+15% здоров'я, +5% за ранг"},
			{"id": "hardy", "name": "Селянська витривалість", "max": 5, "req": {},
				"desc": "+6% здоров'я за ранг"},
			{"id": "roll", "name": "Спритний ривок", "max": 3, "req": {"hardy": 1},
				"desc": "-12% перезарядки\nперекиду за ранг"},
		]},
	],
	"cossack": [
		{"name": "Шабля", "nodes": [
			{"id": "whirl", "name": "Вихор", "max": 5, "req": {}, "active": true, "cost": 12,
				"desc": "Кругова атака навколо козака.\n+20% шкоди, +8% радіуса за ранг"},
			{"id": "sharp", "name": "Шабельна наука", "max": 3, "req": {}, "desc": "+8% шкоди за ранг"},
			{"id": "whirl_cd", "name": "Гострий вітер", "max": 3, "req": {"whirl": 2}, "desc": "-10% перезарядки Вихору"},
			{"id": "reach", "name": "Довга шабля", "max": 3, "req": {"sharp": 1}, "desc": "+8% дальності удару"},
			{"id": "cleave", "name": "Широкий замах", "max": 2, "req": {"sharp": 2}, "desc": "+20° ширина удару"},
			{"id": "storm", "name": "Буревій", "max": 1, "req": {"whirl": 3, "whirl_cd": 1}, "desc": "Вихор притягує нечисть\nі б'є вдруге"},
			{"id": "deadly", "name": "Смертельний удар", "max": 1, "req": {"sharp": 3}, "desc": "Крит б'є x3 замість x2"},
		]},
		{"name": "Козацький дух", "nodes": [
			{"id": "battle_cry", "name": "Бойовий клич", "max": 5, "req": {}, "active": true, "cost": 18,
				"desc": "8 с: +15% шкоди (+5% за ранг)\nі +20% швидкості"},
			{"id": "tough", "name": "Міцна шкура", "max": 3, "req": {}, "desc": "+15 здоров'я за ранг"},
			{"id": "fury", "name": "Лють", "max": 3, "req": {"battle_cry": 1}, "desc": "+6% швидкості удару"},
			{"id": "ward", "name": "Оберіг", "max": 3, "req": {"tough": 1}, "desc": "-5% отриманої шкоди"},
			{"id": "thirst", "name": "Жага бою", "max": 3, "req": {"fury": 1}, "desc": "2% шкоди лікує козака"},
			{"id": "thorns", "name": "Колючий жупан", "max": 2, "req": {"ward": 2}, "desc": "Повертає 25% шкоди нападнику"},
			{"id": "unbreak", "name": "Незламний", "max": 1, "req": {"tough": 3}, "desc": "Раз за похід не гине від удару"},
		]},
		{"name": "Самопал", "nodes": [
			{"id": "musket", "name": "Постріл", "max": 5, "req": {}, "active": true, "cost": 6,
				"desc": "Куля пробиває ворогів наскрізь.\n+18% шкоди за ранг"},
			{"id": "reload", "name": "Швидке набивання", "max": 3, "req": {"musket": 2}, "desc": "-12% перезарядки самопала"},
			{"id": "dash_strike", "name": "Удар з перекиду", "max": 1, "req": {"musket": 1}, "desc": "Перекид ранить ворогів на шляху"},
			{"id": "buckshot", "name": "Картеч", "max": 1, "req": {"musket": 3, "reload": 1}, "desc": "Постріл випускає 5 куль віялом"},
		]},
	],
	"zaporozhets": [
		{"name": "Земля", "nodes": [
			{"id": "zemnyi", "name": "Земний удар", "max": 5, "req": {}, "active": true, "cost": 20,
				"desc": "Б'є об землю: шкода довкола й\nприголомшення. +15% шкоди за ранг"},
			{"id": "bulava", "name": "Булава гніву", "max": 5, "req": {"zemnyi": 1}, "active": true, "cost": 18,
				"desc": "Страшний удар перед собою.\n+20% шкоди за ранг"},
			{"id": "mace_master", "name": "Булавник", "max": 3, "req": {}, "desc": "+10% шкоди булавою\nза ранг"},
		]},
		{"name": "Стіна", "nodes": [
			{"id": "stina", "name": "Козацька стіна", "max": 5, "req": {}, "active": true, "cost": 25,
				"desc": "6 с: вороги б'ють лише тебе,\nшкода −40% (−5% за ранг)"},
			{"id": "iron_skin", "name": "Залізна шкура", "max": 5, "req": {}, "desc": "+3% захисту за ранг"},
			{"id": "nevhamovnyi", "name": "Невгамовний", "max": 3, "req": {"iron_skin": 2}, "desc": "Що менше здоров'я — то\nбільша шкода (до +15% за ранг)"},
			{"id": "zaporizka_vytryvalist", "name": "Січова витривалість", "max": 3, "req": {"stina": 1}, "desc": "+8% здоров'я за ранг"},
		]},
	],
	"plastun": [
		{"name": "Засідка", "nodes": [
			{"id": "pastka", "name": "Пастка", "max": 5, "req": {}, "active": true, "cost": 12,
				"desc": "Капкан під ногами: шкода, приголомшення,\nкровотеча. +20% за ранг"},
			{"id": "tin", "name": "Тінь", "max": 5, "req": {"pastka": 1}, "active": true, "cost": 20,
				"desc": "4 с вороги тебе не бачать; наступний\nудар — крит, +20% за ранг"},
			{"id": "trapper", "name": "Мисливець", "max": 3, "req": {"pastka": 2}, "desc": "+1 пастка одночасно,\n+20% шкоди пасток за ранг"},
		]},
		{"name": "Спис", "nodes": [
			{"id": "kydok", "name": "Кидок списа", "max": 5, "req": {}, "active": true, "cost": 10,
				"desc": "Спис летить крізь ворогів.\n+20% шкоди за ранг"},
			{"id": "oko", "name": "Око пластуна", "max": 5, "req": {}, "desc": "+4% шансу криту за ранг"},
			{"id": "stryvok", "name": "Стрімкий ривок", "max": 3, "req": {"oko": 1}, "desc": "−15% перезарядки перекиду"},
			{"id": "deadly", "name": "Смертельний удар", "max": 1, "req": {"oko": 3}, "desc": "Крит б'є x3 замість x2"},
		]},
	],
	"samopalnyk": [
		{"name": "Пищаль", "nodes": [
			{"id": "kartech", "name": "Картеч", "max": 5, "req": {}, "active": true, "cost": 14,
				"desc": "7 куль віялом.\n+15% шкоди за ранг"},
			{"id": "prytsil", "name": "Прицільний постріл", "max": 5, "req": {"kartech": 1}, "active": true, "cost": 18,
				"desc": "Важка куля крізь усіх.\n+25% шкоди за ранг"},
			{"id": "porokh", "name": "Добрий порох", "max": 5, "req": {}, "desc": "+8% шкоди за ранг"},
			{"id": "shvydke", "name": "Швидке набивання", "max": 3, "req": {"porokh": 1}, "desc": "+10% швидкості пострілу"},
		]},
		{"name": "Порох", "nodes": [
			{"id": "bochka", "name": "Бочка пороху", "max": 5, "req": {}, "active": true, "cost": 25,
				"desc": "Кидає бочку: за мить — великий вибух,\nпідпал. +20% шкоди за ранг"},
			{"id": "vluchnist", "name": "Влучність", "max": 3, "req": {}, "desc": "+5% шансу криту"},
			{"id": "deadly", "name": "Смертельний постріл", "max": 1, "req": {"vluchnist": 3}, "desc": "Крит б'є x3 замість x2"},
		]},
	],
	"kharakternyk": [
		{"name": "Перевертень", "nodes": [
			{"id": "vovk", "name": "Вовча подоба", "max": 5, "req": {}, "active": true, "cost": 30,
				"desc": "10 с вовком: +40% швидкості, +25% шкоди,\nвампіризм. +2 с за ранг"},
			{"id": "kulia", "name": "Куля не бере", "max": 3, "req": {"vovk": 1}, "active": true, "cost": 25,
				"desc": "Невразливість на 2 с\n(+0.5 с за ранг)"},
			{"id": "wolf_blood", "name": "Вовча кров", "max": 3, "req": {"vovk": 2}, "desc": "+3% вампіризму за ранг"},
		]},
		{"name": "Замовляння", "nodes": [
			{"id": "zamova", "name": "Замовляння шаблі", "max": 5, "req": {}, "active": true, "cost": 20,
				"desc": "10 с кожен удар б'є блискавкою\nще 2 ворогів. +15% за ранг"},
			{"id": "vidvid", "name": "Відвід очей", "max": 5, "req": {"zamova": 1}, "active": true, "cost": 20,
				"desc": "Вороги довкола 2 с заціпеніли\nй ослабли. +0.3 с за ранг"},
			{"id": "spirit", "name": "Характерна сила", "max": 3, "req": {}, "desc": "+10% сили вмінь"},
		]},
	],
	"volkhv": [
		{"name": "Вогонь", "nodes": [
			{"id": "fireball", "name": "Вогняна куля", "max": 5, "req": {}, "active": true, "cost": 18,
				"desc": "Вибухає серед ворогів і підпалює.\n+20% шкоди за ранг"},
			{"id": "iskra", "name": "Іскра", "max": 5, "req": {}, "desc": "+10% шкоди звичайних іскор"},
			{"id": "pyre", "name": "Жар", "max": 3, "req": {"fireball": 2}, "desc": "+20% радіуса вибуху,\nсильніше горіння"},
			{"id": "twin_spark", "name": "Подвійна іскра", "max": 1, "req": {"iskra": 3}, "desc": "Кожна атака — дві іскри"},
		]},
		{"name": "Обереги", "nodes": [
			{"id": "shield", "name": "Щит-оберіг", "max": 5, "req": {}, "active": true, "cost": 25,
				"desc": "8 с поглинає шкоду:\n25% здоров'я, +8% за ранг"},
			{"id": "deep_well", "name": "Глибока криниця", "max": 3, "req": {}, "desc": "+20% запасу наснаги"},
			{"id": "mana_flow", "name": "Потік наснаги", "max": 3, "req": {"deep_well": 1}, "desc": "+25% відновлення наснаги"},
			{"id": "spirit", "name": "Сила роду", "max": 3, "req": {"shield": 1}, "desc": "+10% сили вмінь"},
			{"id": "focus", "name": "Зосередженість", "max": 3, "req": {"mana_flow": 1}, "desc": "-6% перезарядки вмінь"},
		]},
		{"name": "Трави", "nodes": [
			{"id": "herb", "name": "Цілюща трава", "max": 5, "req": {}, "active": true, "cost": 20,
				"desc": "6 с лікує: 20% здоров'я (+6% за ранг);\nзагону — одразу"},
			{"id": "regen", "name": "Живе коріння", "max": 3, "req": {}, "desc": "+0.6 здоров'я за секунду"},
			{"id": "tough", "name": "Дубова кора", "max": 3, "req": {"regen": 1}, "desc": "+15 здоров'я за ранг"},
			{"id": "ward", "name": "Оберіг тіла", "max": 3, "req": {"herb": 2}, "desc": "-5% отриманої шкоди"},
		]},
	],
}

## Кнопки вмінь у бою (усі активні вміння всіх класів) і короткі підписи.
const ACTIVE_LABELS := {"vyly": "Вила", "first_aid": "Рани", "whirl": "Вихор", "battle_cry": "Клич", "musket": "Самопал",
	"fireball": "Вогонь", "shield": "Щит", "herb": "Трава",
	"zemnyi": "Земля", "stina": "Стіна", "bulava": "Гнів",
	"pastka": "Пастка", "tin": "Тінь", "kydok": "Спис",
	"kartech": "Картеч", "prytsil": "Приціл", "bochka": "Бочка",
	"vovk": "Вовк", "kulia": "Куля", "zamova": "Замова", "vidvid": "Відвід"}
const ACTIVE_COLORS := {"vyly": Color(0.55, 0.42, 0.25), "first_aid": Color(0.3, 0.6, 0.3), "whirl": Color(0.55, 0.3, 0.8),
	"battle_cry": Color(0.75, 0.35, 0.15), "musket": Color(0.45, 0.4, 0.3), "fireball": Color(0.85, 0.35, 0.1),
	"shield": Color(0.35, 0.55, 0.85), "herb": Color(0.3, 0.7, 0.35),
	"zemnyi": Color(0.5, 0.35, 0.2), "stina": Color(0.6, 0.55, 0.45), "bulava": Color(0.7, 0.2, 0.15),
	"pastka": Color(0.45, 0.4, 0.25), "tin": Color(0.25, 0.25, 0.35), "kydok": Color(0.55, 0.5, 0.35),
	"kartech": Color(0.5, 0.45, 0.4), "prytsil": Color(0.35, 0.35, 0.5), "bochka": Color(0.6, 0.3, 0.1),
	"vovk": Color(0.45, 0.45, 0.45), "kulia": Color(0.75, 0.65, 0.25), "zamova": Color(0.35, 0.5, 0.9), "vidvid": Color(0.5, 0.3, 0.6)}
## Базова перезарядка (с)
const COOLDOWNS := {"vyly": 4.0, "first_aid": 14.0, "whirl": 8.0, "battle_cry": 20.0, "musket": 4.0,
	"fireball": 3.5, "shield": 16.0, "herb": 12.0,
	"zemnyi": 7.0, "stina": 16.0, "bulava": 6.0,
	"pastka": 6.0, "tin": 14.0, "kydok": 4.0,
	"kartech": 5.0, "prytsil": 7.0, "bochka": 12.0,
	"vovk": 25.0, "kulia": 20.0, "zamova": 15.0, "vidvid": 12.0}


## Вузол дерева вмінь будь-якого класу (перший знайдений) і клас, якому він належить.
static func find_node(id: String, cls: String = "") -> Dictionary:
	var order: Array = [cls] if cls != "" else []
	order.append_array(TREES.keys())
	for c in order:
		if not TREES.has(c):
			continue
		for b in TREES[c]:
			for n in b["nodes"]:
				if n["id"] == id:
					return n
	return {}


static func node_name(id: String) -> String:
	return find_node(id).get("name", id)


## Ланцюжок класів від Селянина до цього (для «набутих раніше» вмінь).
static func lineage(cls: String) -> Array:
	var out := [cls]
	for c in CLASSES:
		if cls in CLASSES[c]["next"]:
			out = lineage(c) + out
			break
	return out
