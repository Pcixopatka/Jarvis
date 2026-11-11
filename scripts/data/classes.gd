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
	"volkhv": {"name": "Волхв", "tier": 1, "job_max": 40, "next": ["znakhar", "perun_zhrets", "molfar"],
		"weapons": ["staff"], "mana_mult": 2.0, "regen_mult": 2.2, "address": "волхве", "hp_mult": 1.0, "dmg_mult": 1.0, "skill_mult": 0.7,
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
	# ---- Спеціалізації Волхва (Карпати, кожна — у свого наставника) ----
	"znakhar": {"name": "Знахар", "tier": 2, "job_max": 50, "next": [], "parent": "volkhv",
		"weapons": ["staff"], "mana_mult": 2.4, "regen_mult": 2.7, "address": "волхве", "hp_mult": 1.35, "dmg_mult": 1.05, "skill_mult": 0.7,
		"where": "verkhovyna", "mentor": "paraska", "desc": "Лікар і берегиня загону: Живиця, Очищення, Оберіг загону, Підняти побратима, отруйне зілля."},
	"perun_zhrets": {"name": "Перунів жрець", "tier": 2, "job_max": 50, "next": [], "parent": "volkhv",
		"weapons": ["staff"], "mana_mult": 2.2, "regen_mult": 2.4, "address": "волхве", "hp_mult": 1.05, "dmg_mult": 1.3, "skill_mult": 0.35,
		"where": "pip_ivan", "mentor": "hromobii", "desc": "Повелитель грози: Блискавка, Ланцюг, Громовий молот, Буря."},
	"molfar": {"name": "Мольфар", "tier": 2, "job_max": 50, "next": [], "parent": "volkhv",
		"weapons": ["staff"], "mana_mult": 2.3, "regen_mult": 2.5, "address": "волхве", "hp_mult": 1.2, "dmg_mult": 1.15, "skill_mult": 0.5,
		"where": "molfar_hut", "mentor": "yakym", "desc": "Карпатський чарівник: Град, Туман, Прокляття, Виклик духа."},
}

## Чи належить клас до волхвівської гілки (для звертань «волхве», вигляду тощо).
static func is_volkhv_line(cls: String) -> bool:
	return cls == "volkhv" or CLASSES.get(cls, {}).get("parent", "") == "volkhv"

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
		{"name": "Гарт", "nodes": [
			{"id": "khvatka", "name": "Міцна хватка", "max": 5, "req": {}, "fx": {"block": 6}, "desc": "Крізь Блок проходить\nна 6% менше шкоди за ранг"},
			{"id": "kontrudar", "name": "Контрудар", "max": 3, "req": {"khvatka": 2}, "fx": {"parry_dmg": 30}, "desc": "Удар у відповідь після парирування\nсильніший на 30% за ранг"},
			{"id": "pidsichka", "name": "Підсічка", "max": 5, "req": {}, "active": true, "cost": 12, "act": {"type": "cone", "cd": 8, "label": "Підсічка", "color": "c8a050", "reach": 170, "arc": 140, "pct": [1.4, 0.2], "stun": 0.5, "status": ["weak", 4.0]}, "desc": "Удар по ногах перед собою: знесилює\nй збиває з ніг. +15% шкоди за ранг"},
			{"id": "pobratymstvo", "name": "Побратимство", "max": 3, "req": {}, "fx": {"hp": 2, "regen_pct": 0.1}, "desc": "+2% здоров'я й загоєння\n0,1% за секунду за ранг"},
		]},
	],
	"zaporozhets": [
		{"name": "Земля", "nodes": [
			{"id": "zemnyi", "name": "Земний удар", "max": 5, "req": {}, "active": true, "cost": 20,
				"desc": "Б'є об землю: шкода довкола й\nприголомшення. +15% шкоди за ранг"},
			{"id": "bulava", "name": "Булава гніву", "max": 5, "req": {"zemnyi": 1}, "active": true, "cost": 18,
				"desc": "Страшний удар перед собою.\n+20% шкоди за ранг"},
			{"id": "taran", "name": "Таран", "max": 5, "req": {"zemnyi": 3}, "active": true, "cost": 16,
				"act": {"type": "leap", "cd": 9, "label": "Таран", "color": "d08a3a", "range": 420, "radius": 150, "pct": [2.0, 0.3], "stun": [0.6, 0.1]},
				"desc": "Стрибок до ворога й удар довкола\nмісця приземлення. +15% шкоди за ранг"},
			{"id": "hrim_zemli", "name": "Грім землі", "max": 1, "req": {"zemnyi": 5, "bulava": 5}, "active": true, "cost": 40,
				"act": {"type": "nova", "cd": 40, "label": "Грім", "color": "f2c23a", "radius": 340, "pct": 5.0, "stun": 2.0, "shake": 16},
				"desc": "Вершинне вміння: земля репається\nдалеко довкола, усі ціпеніють на 2 с"},
		]},
		{"name": "Стіна", "nodes": [
			{"id": "stina", "name": "Козацька стіна", "max": 5, "req": {}, "active": true, "cost": 25,
				"desc": "6 с: вороги б'ють лише тебе,\nшкода −40% (−5% за ранг)"},
			{"id": "iron_skin", "name": "Залізна шкура", "max": 5, "req": {}, "desc": "+3% захисту за ранг"},
			{"id": "nevhamovnyi", "name": "Невгамовний", "max": 3, "req": {"iron_skin": 2}, "desc": "Що менше здоров'я — то\nбільша шкода (до +15% за ранг)"},
			{"id": "zaporizka_vytryvalist", "name": "Січова витривалість", "max": 3, "req": {"stina": 1}, "desc": "+8% здоров'я за ранг"},
			{"id": "kremin", "name": "Кремінь", "max": 5, "req": {"iron_skin": 3}, "fx": {"ward": 1.5},
				"desc": "Шкода по тобі менша\nна 1,5% за ранг"},
			{"id": "vidsich", "name": "Відсіч", "max": 3, "req": {"stina": 2}, "fx": {"parry_dmg": 40, "parry_heal": 1},
				"desc": "Після парирування удар у відповідь\nсильніший на 40% і лікує 1% за ранг"},
		]},
		{"name": "Зброя", "nodes": [
			{"id": "mace_master", "name": "Булавник", "max": 3, "req": {}, "desc": "+10% шкоди булавою\nза ранг"},
			{"id": "shablia_master", "name": "Шабельний бій", "max": 5, "req": {}, "fx": {"aspd": 3, "crit": 1.5}, "when": {"weapon": ["sabre"]},
				"desc": "Із шаблею: +3% швидкості удару\nй +1,5% криту за ранг"},
			{"id": "spys_master", "name": "Списова наука", "max": 5, "req": {}, "fx": {"dmg": 3, "range": 4}, "when": {"weapon": ["pike"]},
				"desc": "Зі списом: +3% шкоди\nй +4% дальності за ранг"},
			{"id": "dvobii", "name": "Двобій", "max": 3, "req": {}, "fx": {"big_dmg": 4},
				"desc": "+4% шкоди елітам\nі босам за ранг"},
			{"id": "kryvavyi_zamakh", "name": "Кривавий замах", "max": 3, "req": {"dvobii": 1}, "fx": {"bleed_hit": 6},
				"desc": "Удар із шансом 6% за ранг\nпускає кров"},
		]},
		{"name": "Дух", "nodes": [
			{"id": "navala", "name": "Стійка: навала", "max": 3, "req": {}, "active": true, "cost": 10,
				"act": {"type": "buff", "cd": 24, "label": "Навала", "color": "d8402e", "group": "stance", "dur": 20, "fx": {"dmg": [10, 3], "ward": -5}, "text": "Навала!"},
				"desc": "20 с: +10% шкоди (+3% за ранг), але по тобі\nб'ють на 5% сильніше. Діє одна стійка"},
			{"id": "mur", "name": "Стійка: мур", "max": 3, "req": {}, "active": true, "cost": 10,
				"act": {"type": "buff", "cd": 24, "label": "Мур", "color": "4a90e8", "group": "stance", "dur": 20, "fx": {"ward": [8, 2], "dmg": -5}, "text": "Мур!"},
				"desc": "20 с: шкода по тобі менша на 8% (+2% за ранг),\nале твоя шкода −5%. Діє одна стійка"},
			{"id": "khoruhva", "name": "Хоругва куреня", "max": 5, "req": {}, "active": true, "cost": 22,
				"act": {"type": "buff", "cd": 30, "label": "Хоругва", "color": "f2c23a", "dur": 12, "fx": {"dmg": [6, 2], "regen_pct": [0.6, 0.1]}, "text": "За Січ!"},
				"desc": "12 с: +6% шкоди (+2% за ранг)\nй загоєння 0,6% здоров'я за секунду"},
			{"id": "druhe_dykhannia", "name": "Друге дихання", "max": 3, "req": {}, "fx": {"kill_heal": 0.3},
				"desc": "Кожне вбивство лікує\n0,3% здоров'я за ранг"},
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
		{"name": "Леза", "nodes": [
			{"id": "zazubrene_lezo", "name": "Зазубрене лезо", "max": 5, "req": {}, "fx": {"bleed_hit": 6}, "desc": "Удар із шансом 6% за ранг\nпускає кров"},
			{"id": "udar_u_spynu", "name": "Удар у спину", "max": 3, "req": {}, "fx": {"opener": 10}, "desc": "+10% шкоди нечисті з повним\nздоров'ям за ранг"},
			{"id": "dvi_shabli", "name": "Шабельний танець", "max": 5, "req": {}, "fx": {"aspd": 4, "crit_dmg": 4}, "when": {"weapon": ["sabre"]}, "desc": "Із шаблею: +4% швидкості удару\nй +4% шкоди криту за ранг"},
			{"id": "zlyva_udariv", "name": "Злива ударів", "max": 5, "req": {"zazubrene_lezo": 2}, "active": true, "cost": 14, "act": {"type": "cone", "cd": 7, "label": "Злива", "color": "dfe4ee", "reach": 150, "arc": 100, "pct": [2.4, 0.4], "kb": 100}, "desc": "Серія швидких ударів перед собою.\n+17% шкоди за ранг"},
		]},
		{"name": "Рух", "nodes": [
			{"id": "perekotypole", "name": "Перекотиполе", "max": 3, "req": {}, "fx": {"dodge_cd": 8, "dodge_dmg": 8}, "desc": "Перекид готовий на 8% швидше,\n2 с після нього +8% шкоди за ранг"},
			{"id": "lehka_khoda", "name": "Легка хода", "max": 3, "req": {}, "fx": {"speed": 4}, "desc": "+4% швидкості бігу за ранг"},
			{"id": "dymova_zavisa", "name": "Димова завіса", "max": 3, "req": {"lehka_khoda": 1}, "active": true, "cost": 15, "act": {"type": "buff", "cd": 28, "label": "Дим", "color": "b8bcc8", "dur": [4, 1], "fx": {"ward": [30, 5]}, "cleanse": true, "text": "Дим!", "sound": "dodge"}, "desc": "4 с: шкода по тобі менша на 30%,\nзнімає всі стани"},
			{"id": "stiika_myslyvtsia", "name": "Стійка: мисливець", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Мисливець", "color": "f2c23a", "group": "stance", "dur": 20, "fx": {"crit": [8, 2], "ward": -8}, "text": "На лови!"}, "desc": "20 с: +8% шансу криту (+2% за ранг),\nале по тобі б'ють на 8% сильніше"},
			{"id": "stiika_tini", "name": "Стійка: тінь", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Тінь", "color": "9a5ad8", "group": "stance", "dur": 20, "fx": {"speed": [10, 3], "dodge_cd": [15, 5], "dmg": -5}, "text": "Як тінь"}, "desc": "20 с: +10% бігу й швидший перекид,\nале шкода −5%. Діє одна стійка"},
		]},
		{"name": "Полювання", "nodes": [
			{"id": "mitka", "name": "Мітка", "max": 3, "req": {}, "active": true, "cost": 14, "act": {"type": "nova", "at": "enemy", "cd": 18, "label": "Мітка", "color": "9a5ad8", "radius": [120, 15], "pct": [0.6, 0.1], "status": ["curse", 6.0], "sound": "spell", "shake": 3}, "desc": "Мітить ворогів у колі: прокляті\nотримують більше шкоди 6 с"},
			{"id": "terpinnia", "name": "Терпіння мисливця", "max": 3, "req": {}, "fx": {"big_dmg": 4}, "desc": "+4% шкоди елітам\nі босам за ранг"},
			{"id": "dobyvannia", "name": "Добивання", "max": 5, "req": {"terpinnia": 1}, "fx": {"execute": 5}, "desc": "+5% шкоди нечисті нижче\n30% здоров'я за ранг"},
			{"id": "vovcha_yama", "name": "Вовча яма", "max": 1, "req": {"pastka": 5, "kydok": 5}, "active": true, "cost": 30, "act": {"type": "zone", "cd": 40, "label": "Яма", "color": "8a5a2a", "radius": 200, "dur": 6, "tick": 0.5, "pct": 0.5, "status": ["bleed", 3.0]}, "desc": "Вершинне вміння: яма під ворогом\n6 с рве всіх, хто в ній, до крові"},
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
		{"name": "Вогонь", "nodes": [
			{"id": "zapalna_kulia", "name": "Запальна куля", "max": 5, "req": {}, "fx": {"burn_hit": 6}, "desc": "Постріл із шансом 6% за ранг\nпідпалює"},
			{"id": "hranata", "name": "Граната", "max": 5, "req": {"bochka": 2}, "active": true, "cost": 18, "act": {"type": "shots", "cd": 9, "label": "Граната", "color": "f08a2a", "count": 1, "pct": [2.0, 0.3], "explode": [130, 10], "pierce": 1}, "desc": "Летить у ворога й вибухає.\n+15% шкоди за ранг"},
			{"id": "dymnyi_porokh", "name": "Димний порох", "max": 3, "req": {}, "active": true, "cost": 14, "act": {"type": "buff", "cd": 26, "label": "Дим", "color": "b8bcc8", "dur": [4, 1], "fx": {"ward": [25, 5]}, "text": "Дим!", "sound": "musket"}, "desc": "4 с у диму: шкода по тобі\nменша на 25% (+5% за ранг)"},
			{"id": "zalp", "name": "Залп", "max": 1, "req": {"kartech": 5, "prytsil": 5}, "active": true, "cost": 35, "act": {"type": "shots", "cd": 35, "label": "Залп", "color": "f2c23a", "count": 9, "spread": 1.2, "pct": 1.6}, "desc": "Вершинне вміння: дев'ять важких куль\nвіялом, кожна пробиває навиліт"},
		]},
		{"name": "Око", "nodes": [
			{"id": "dalekyi_postril", "name": "Далекий постріл", "max": 5, "req": {}, "fx": {"opener": 8}, "desc": "+8% шкоди нечисті з повним\nздоров'ям за ранг"},
			{"id": "tverda_ruka", "name": "Тверда рука стрільця", "max": 5, "req": {}, "fx": {"crit_dmg": 6}, "desc": "+6% шкоди криту за ранг"},
			{"id": "na_zvira", "name": "Мисливець на звіра", "max": 3, "req": {}, "fx": {"big_dmg": 4}, "desc": "+4% шкоди елітам\nі босам за ранг"},
			{"id": "nabii", "name": "Набій напоготові", "max": 3, "req": {}, "fx": {"cd": 3}, "desc": "Вміння відновлюються\nна 3% швидше за ранг"},
			{"id": "stiika_vluchnyka", "name": "Стійка: влучник", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Влучник", "color": "f2c23a", "group": "stance", "dur": 20, "fx": {"crit": [8, 2], "speed": -10}, "text": "Цілюсь"}, "desc": "20 с: +8% шансу криту (+2% за ранг),\nале біг −10%. Діє одна стійка"},
			{"id": "stiika_rukhlyva", "name": "Стійка: рухливий", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Рухливий", "color": "a8dcff", "group": "stance", "dur": 20, "fx": {"speed": [12, 3], "aspd": [6, 2], "dmg": -5}, "text": "У русі"}, "desc": "20 с: +12% бігу й +6% швидкості пострілу,\nале шкода −5%. Діє одна стійка"},
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
		{"name": "Звір", "nodes": [
			{"id": "vovche_vyttia", "name": "Вовче виття", "max": 5, "req": {"vovk": 2}, "active": true, "cost": 18, "act": {"type": "nova", "cd": 12, "label": "Виття", "color": "b8bcc8", "radius": [220, 10], "pct": [1.0, 0.15], "stun": 0.5, "status": ["weak", 5.0], "sound": "roar"}, "desc": "Виття довкола: шкода, слабкість\nі заціпеніння. +15% шкоди за ранг"},
			{"id": "zviryna_syla", "name": "Звірина сила", "max": 5, "req": {}, "fx": {"hp": 2, "lifesteal": 0.4}, "desc": "+2% здоров'я й +0,4%\nвампіризму за ранг"},
			{"id": "nichnyi_zir", "name": "Нічний зір", "max": 3, "req": {}, "fx": {"crit": 2}, "desc": "+2% шансу криту за ранг"},
			{"id": "stiika_vovka", "name": "Стійка: вовк", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Вовк", "color": "d8402e", "group": "stance", "dur": 20, "fx": {"aspd": [10, 3], "ward": -6}, "text": "Вовча лють"}, "desc": "20 с: +10% швидкості удару (+3% за ранг),\nале по тобі б'ють на 6% сильніше"},
		]},
		{"name": "Слово", "nodes": [
			{"id": "zamova_krovi", "name": "Замовляння крові", "max": 3, "req": {}, "active": true, "cost": 20, "act": {"type": "buff", "cd": 25, "label": "Кров", "color": "d8402e", "dur": 10, "heal": [8, 3], "fx": {"regen_pct": [0.8, 0.2]}, "text": "Кров, стань!", "sound": "spell"}, "desc": "Лікує 8% здоров'я (+3% за ранг)\nй 10 с гоїть рани"},
			{"id": "slovo_i_shablia", "name": "Слово й шабля", "max": 5, "req": {}, "fx": {"skill": 2, "dmg": 1.5}, "desc": "+2% сили вмінь і\n+1,5% шкоди за ранг"},
			{"id": "vidvernennia", "name": "Відвернення", "max": 3, "req": {"vidvid": 2}, "fx": {"status_dmg": 5}, "desc": "+5% шкоди нечисті\nзі станами за ранг"},
			{"id": "stiika_slova", "name": "Стійка: слово", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Слово", "color": "4a90e8", "group": "stance", "dur": 20, "fx": {"skill": [12, 4], "dmg": -5}, "text": "Слово міцне"}, "desc": "20 с: +12% сили вмінь (+4% за ранг),\nале шкода зброї −5%. Діє одна стійка"},
		]},
		{"name": "Химера", "nodes": [
			{"id": "morok", "name": "Морок", "max": 5, "req": {}, "active": true, "cost": 18, "act": {"type": "zone", "at": "self", "cd": 16, "label": "Морок", "color": "9a5ad8", "radius": [200, 10], "dur": 5, "tick": 0.5, "pct": [0.25, 0.05], "status": ["chill", 1.5]}, "desc": "Туман довкола тебе 5 с: нечисть у ньому\nмерзне й отримує шкоду"},
			{"id": "dvi_dushi", "name": "Дві душі", "max": 3, "req": {}, "fx": {"mana": 8, "mana_regen": 8}, "desc": "+8% наснаги й +8%\nїї відновлення за ранг"},
			{"id": "zahovorenyi", "name": "Заговорений", "max": 1, "req": {"kulia": 3, "zamova": 5}, "active": true, "cost": 35, "act": {"type": "buff", "cd": 60, "label": "Заговір", "color": "f2c23a", "dur": 8, "fx": {"ward": 30, "dmg": 15}, "text": "Заговорений!"}, "desc": "Вершинне вміння: 8 с шкода по тобі\nменша на 30%, а твоя більша на 15%"},
		]},
	],
	"znakhar": [
		{"name": "Лікування", "nodes": [
			{"id": "zhyvytsia", "name": "Живиця", "max": 5, "req": {}, "active": true, "cost": 30,
				"desc": "Лікує тебе й загін: 30% здоров'я\n(+5% за ранг)"},
			{"id": "pidniaty", "name": "Підняти побратима", "max": 3, "req": {"zhyvytsia": 2}, "active": true, "cost": 40,
				"desc": "Поранені побратими встають\nіз 40% здоров'я (+15% за ранг)"},
			{"id": "travnyk", "name": "Травник", "max": 5, "req": {}, "desc": "+12% сили лікування за ранг"},
		]},
		{"name": "Берегиня", "nodes": [
			{"id": "ochyshchennia", "name": "Очищення", "max": 3, "req": {}, "active": true, "cost": 15,
				"desc": "Знімає всі стани з тебе й загону;\n2 с (+1 за ранг) — без станів"},
			{"id": "oberih_zahonu", "name": "Оберіг загону", "max": 5, "req": {"ochyshchennia": 1}, "active": true, "cost": 30,
				"desc": "8 с тобі й загону шкода −25%\n(−5% за ранг)"},
			{"id": "otruta", "name": "Отруйне зілля", "max": 5, "req": {}, "active": true, "cost": 15,
				"desc": "Склянка з отрутою: хмара, що\nз'їдає ворогів. +20% за ранг"},
			{"id": "zhyve_slovo", "name": "Живе слово", "max": 3, "req": {"travnyk": 1}, "desc": "+1 здоров'я за секунду\nза ранг"},
		]},
		{"name": "Отрути", "nodes": [
			{"id": "chorna_khvoroba", "name": "Чорна хвороба", "max": 5, "req": {"otruta": 2}, "active": true, "cost": 20, "act": {"type": "zone", "cd": 14, "label": "Хвороба", "color": "5fc04a", "radius": [150, 10], "dur": 6, "tick": 0.5, "pct": [0.3, 0.06], "status": ["plague", 3.0]}, "desc": "Хмара зарази під ворогом 6 с.\n+20% шкоди за ранг"},
			{"id": "yid", "name": "Їдь", "max": 5, "req": {}, "fx": {"status_dmg": 4}, "desc": "+4% шкоди нечисті\nзі станами за ранг"},
			{"id": "blekota", "name": "Блекота", "max": 3, "req": {}, "active": true, "cost": 16, "act": {"type": "nova", "at": "enemy", "cd": 14, "label": "Блекота", "color": "9a5ad8", "radius": 140, "pct": 0.5, "stun": [1.2, 0.3], "status": ["weak", 4.0], "sound": "spell", "shake": 3}, "desc": "Дурман у колі під ворогом:\nприголомшує й знесилює"},
			{"id": "smertelna_doza", "name": "Смертельна доза", "max": 1, "req": {"otruta": 5, "chorna_khvoroba": 3}, "fx": {"execute": 25}, "desc": "Вершинне вміння: +25% шкоди\nнечисті нижче 30% здоров'я"},
		]},
		{"name": "Зело", "nodes": [
			{"id": "tsiliushche_kolo", "name": "Цілюще коло", "max": 5, "req": {}, "active": true, "cost": 24, "act": {"type": "buff", "cd": 18, "label": "Коло", "color": "5fc04a", "dur": 8, "heal": [6, 2], "fx": {"regen_pct": [1.2, 0.3]}, "text": "Зело гоїть", "sound": "spell"}, "desc": "Лікує 6% здоров'я (+2% за ранг)\nй 8 с гоїть рани"},
			{"id": "hirka_trava", "name": "Гірка трава", "max": 5, "req": {}, "fx": {"weak_hit": 5}, "desc": "Удар із шансом 5% за ранг\nзнесилює"},
			{"id": "polyn", "name": "Полин", "max": 3, "req": {}, "fx": {"ward": 2}, "desc": "Шкода по тобі менша\nна 2% за ранг"},
			{"id": "syla_zela", "name": "Сила зела", "max": 5, "req": {}, "fx": {"skill": 2, "mana_regen": 4}, "desc": "+2% сили вмінь і +4%\nвідновлення наснаги за ранг"},
			{"id": "stiika_tsilytelia", "name": "Стійка: цілитель", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Цілитель", "color": "5fc04a", "group": "stance", "dur": 20, "fx": {"regen_pct": [0.6, 0.2], "skill": -8}, "text": "Гою", "sound": "spell"}, "desc": "20 с: загоєння 0,6% за секунду (+0,2% за ранг),\nале сила вмінь −8%. Діє одна стійка"},
			{"id": "stiika_otruinyka", "name": "Стійка: отруйник", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Отруйник", "color": "9a5ad8", "group": "stance", "dur": 20, "fx": {"skill": [10, 3], "ward": -6}, "text": "Труїти!", "sound": "spell"}, "desc": "20 с: +10% сили вмінь (+3% за ранг),\nале по тобі б'ють на 6% сильніше"},
		]},
	],
	"perun_zhrets": [
		{"name": "Блискавка", "nodes": [
			{"id": "lightning", "name": "Блискавка Перуна", "max": 5, "req": {}, "active": true, "cost": 18,
				"desc": "Б'є блискавкою 2+ранг\nнайближчих ворогів"},
			{"id": "chain", "name": "Ланцюг", "max": 2, "req": {"lightning": 2}, "desc": "+2 цілі блискавки\nза ранг"},
			{"id": "wrath", "name": "Гнів Перуна", "max": 1, "req": {"lightning": 3, "chain": 1}, "desc": "Блискавка сповільнює\nворогів на 2 с"},
			{"id": "grim", "name": "Громовиця", "max": 5, "req": {}, "desc": "+10% шкоди блискавок і грому"},
		]},
		{"name": "Гроза", "nodes": [
			{"id": "molot", "name": "Громовий молот", "max": 5, "req": {}, "active": true, "cost": 30,
				"desc": "Удар грому в ціль: шкода довкола,\nприголомшення. +20% за ранг"},
			{"id": "burya", "name": "Буря", "max": 5, "req": {"molot": 2}, "active": true, "cost": 45,
				"desc": "6 с блискавки б'ють ворогів\nдовкола. +1 с за ранг"},
			{"id": "storm_soul", "name": "Душа грози", "max": 3, "req": {"molot": 1}, "desc": "−10% перезарядки вмінь\nгрози за ранг"},
		]},
		{"name": "Небо", "nodes": [
			{"id": "kulova", "name": "Кульова блискавка", "max": 5, "req": {"lightning": 2}, "active": true, "cost": 20, "act": {"type": "shots", "cd": 8, "label": "Куля", "color": "f2c23a", "count": 1, "pct": [2.6, 0.4], "explode": [110, 10], "pierce": 1, "sound": "spell"}, "desc": "Куля летить у ворога й вибухає.\n+15% шкоди за ранг"},
			{"id": "naelektryzovanyi", "name": "Наелектризований", "max": 5, "req": {}, "fx": {"stun_hit": 2}, "desc": "Удар із шансом 2% за ранг\nприголомшує"},
			{"id": "blyskavychnyi_krok", "name": "Блискавичний крок", "max": 3, "req": {}, "active": true, "cost": 16, "act": {"type": "leap", "cd": 12, "label": "Крок", "color": "a8dcff", "range": 460, "radius": 120, "pct": [1.5, 0.3], "stun": 0.5, "sound": "spell"}, "desc": "Миттю переносить до ворога\nй б'є довкола. +20% шкоди за ранг"},
			{"id": "syla_neba", "name": "Сила неба", "max": 5, "req": {}, "fx": {"skill": 2.5}, "desc": "+2,5% сили вмінь за ранг"},
			{"id": "perunovyi_sud", "name": "Перунів суд", "max": 1, "req": {"lightning": 5, "molot": 5}, "active": true, "cost": 45, "act": {"type": "nova", "cd": 45, "label": "Суд", "color": "f2c23a", "radius": 380, "pct": 4.0, "stun": 1.5, "shake": 16}, "desc": "Вершинне вміння: грім б'є далеко\nдовкола, усі ціпеніють на 1,5 с"},
		]},
		{"name": "Жрець", "nodes": [
			{"id": "hromovyi_shchyt", "name": "Громовий щит", "max": 3, "req": {}, "active": true, "cost": 18, "act": {"type": "buff", "cd": 25, "label": "Щит", "color": "4a90e8", "dur": 10, "fx": {"thorns": [40, 15], "ward": [8, 2]}, "text": "Грім береже", "sound": "spell"}, "desc": "10 с: кривдник отримує 40% своєї шкоди\nназад, а по тобі б'ють на 8% слабше"},
			{"id": "zapakh_hrozy", "name": "Запах грози", "max": 3, "req": {}, "fx": {"cd": 3}, "desc": "Вміння відновлюються\nна 3% швидше за ранг"},
			{"id": "hromovidvid", "name": "Громовідвід", "max": 3, "req": {}, "fx": {"ward": 2, "mana": 5}, "desc": "Шкода по тобі менша на 2%\nй +5% наснаги за ранг"},
			{"id": "stiika_buri", "name": "Стійка: буря", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Буря", "color": "f2c23a", "group": "stance", "dur": 20, "fx": {"skill": [12, 4], "mana_regen": -20}, "text": "Буря!", "sound": "spell"}, "desc": "20 с: +12% сили вмінь (+4% за ранг),\nале наснага відновлюється на 20% повільніше"},
			{"id": "stiika_tyshi", "name": "Стійка: тиша", "max": 3, "req": {}, "active": true, "cost": 5, "act": {"type": "buff", "cd": 24, "label": "Тиша", "color": "a8dcff", "group": "stance", "dur": 20, "fx": {"mana_regen": [40, 10], "skill": -8}, "text": "Тиша перед бурею", "sound": "spell"}, "desc": "20 с: наснага відновлюється на 40% швидше\n(+10% за ранг), але сила вмінь −8%"},
		]},
	],
	"molfar": [
		{"name": "Погода", "nodes": [
			{"id": "grad", "name": "Град", "max": 5, "req": {}, "active": true, "cost": 28,
				"desc": "3 с град б'є ворогів у колі\nй морозить. +20% за ранг"},
			{"id": "tuman", "name": "Туман", "max": 5, "req": {"grad": 1}, "active": true, "cost": 25,
				"desc": "6 с туман довкола: вороги в ньому\nсповільнені й ослаблені"},
			{"id": "khmara", "name": "Хмарник", "max": 3, "req": {"grad": 2}, "desc": "+20% радіуса й шкоди граду"},
		]},
		{"name": "Чари", "nodes": [
			{"id": "proklin", "name": "Прокляття", "max": 5, "req": {}, "active": true, "cost": 18,
				"desc": "Ціль і сусіди 8 с отримують +30%\nшкоди й слабшають. +5% за ранг"},
			{"id": "dukh", "name": "Виклик духа", "max": 5, "req": {"proklin": 1}, "active": true, "cost": 35,
				"desc": "15 с дух-помічник б'є ворогів\nвогниками. +20% за ранг"},
			{"id": "spirit", "name": "Сила гір", "max": 3, "req": {}, "desc": "+10% сили вмінь"},
		]},
		{"name": "Негода", "nodes": [
			{"id": "moroz", "name": "Мороз", "max": 5, "req": {}, "fx": {"chill_hit": 6}, "desc": "Удар із шансом 6% за ранг\nстудить"},
			{"id": "vykhor_molfara", "name": "Гірський вихор", "max": 5, "req": {"grad": 2}, "active": true, "cost": 18, "act": {"type": "nova", "cd": 10, "label": "Вихор", "color": "a8dcff", "radius": [190, 10], "pct": [1.1, 0.2], "pull": true, "status": ["chill", 3.0], "sound": "spell"}, "desc": "Вихор стягує нечисть до тебе\nй студить. +18% шкоди за ранг"},
			{"id": "kryha", "name": "Крига", "max": 3, "req": {}, "fx": {"status_dmg": 4}, "desc": "+4% шкоди нечисті\nзі станами за ранг"},
			{"id": "stiika_nehody", "name": "Стійка: негода", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Негода", "color": "4a90e8", "group": "stance", "dur": 20, "fx": {"skill": [12, 4], "ward": -6}, "text": "Негода!", "sound": "spell"}, "desc": "20 с: +12% сили вмінь (+4% за ранг),\nале по тобі б'ють на 6% сильніше"},
			{"id": "stiika_skeli", "name": "Стійка: скеля", "max": 3, "req": {}, "active": true, "cost": 10, "act": {"type": "buff", "cd": 24, "label": "Скеля", "color": "b8bcc8", "group": "stance", "dur": 20, "fx": {"ward": [10, 3], "speed": -10}, "text": "Як скеля", "sound": "spell"}, "desc": "20 с: шкода по тобі менша на 10% (+3% за ранг),\nале біг −10%. Діє одна стійка"},
		]},
		{"name": "Гори", "nodes": [
			{"id": "kamenepad", "name": "Каменепад", "max": 5, "req": {}, "active": true, "cost": 20, "act": {"type": "zone", "cd": 12, "label": "Каміння", "color": "b8bcc8", "radius": 130, "dur": 3, "tick": 0.3, "pct": [0.5, 0.1], "status": ["weak", 2.0]}, "desc": "Каміння сиплеться на ворога 3 с\nй знесилює. +20% шкоди за ранг"},
			{"id": "navrok", "name": "Наврок", "max": 5, "req": {}, "fx": {"curse_hit": 3}, "desc": "Удар із шансом 3% за ранг\nпроклинає"},
			{"id": "trembita", "name": "Трембіта", "max": 3, "req": {}, "active": true, "cost": 15, "act": {"type": "buff", "cd": 28, "label": "Трембіта", "color": "f2c23a", "dur": 12, "fx": {"skill": [10, 3], "speed": [8, 2]}, "text": "Трембіта кличе"}, "desc": "12 с: +10% сили вмінь і\n+8% бігу"},
			{"id": "hirska_voda", "name": "Гірська вода", "max": 3, "req": {}, "fx": {"mana_regen": 8, "regen_pct": 0.1}, "desc": "+8% відновлення наснаги й загоєння\n0,1% за секунду за ранг"},
			{"id": "sertse_hir", "name": "Серце гір", "max": 1, "req": {"grad": 5, "dukh": 3}, "active": true, "cost": 40, "act": {"type": "buff", "cd": 60, "label": "Серце", "color": "5fc04a", "dur": 10, "fx": {"skill": 30, "cd": 20}, "text": "Гори зі мною", "sound": "spell"}, "desc": "Вершинне вміння: 10 с вміння сильніші\nна 30% і відновлюються на 20% швидше"},
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
				"desc": "8 с поглинає шкоду:\n20% здоров'я, +5% за ранг"},
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
		{"name": "Знання", "nodes": [
			{"id": "vohniane_kolo", "name": "Вогняне коло", "max": 5, "req": {}, "active": true, "cost": 22, "act": {"type": "nova", "cd": 10, "label": "Коло", "color": "f08a2a", "radius": [170, 10], "pct": [1.2, 0.2], "status": ["burn", 4.0], "sound": "spell"}, "desc": "Вогонь довкола тебе: шкода\nй горіння. +15% шкоди за ранг"},
			{"id": "krynytsia_syly", "name": "Криниця сили", "max": 3, "req": {}, "fx": {"skill": 3}, "desc": "+3% сили вмінь за ранг"},
			{"id": "shvydke_slovo", "name": "Швидке слово", "max": 3, "req": {"krynytsia_syly": 1}, "fx": {"cd": 3}, "desc": "Вміння відновлюються\nна 3% швидше за ранг"},
			{"id": "zamova_vohniu", "name": "Замовляння вогню", "max": 3, "req": {}, "fx": {"burn_hit": 6}, "desc": "Удар із шансом 6% за ранг\nпідпалює"},
			{"id": "dukh_predkiv", "name": "Дух предків", "max": 3, "req": {}, "active": true, "cost": 5, "act": {"type": "buff", "cd": 30, "label": "Предки", "color": "a8dcff", "dur": 15, "fx": {"mana_regen": [30, 10], "skill": [6, 2]}, "text": "Предки з тобою", "sound": "spell"}, "desc": "15 с: наснага відновлюється на 30%\nшвидше, вміння сильніші на 6%"},
		]},
	],
}

## Кнопки вмінь у бою (усі активні вміння всіх класів) і короткі підписи.
const ACTIVE_LABELS := {"vyly": "Вила", "first_aid": "Рани", "whirl": "Вихор", "battle_cry": "Клич", "musket": "Самопал",
	"fireball": "Вогонь", "shield": "Щит", "herb": "Трава",
	"zemnyi": "Земля", "stina": "Стіна", "bulava": "Гнів",
	"pastka": "Пастка", "tin": "Тінь", "kydok": "Спис",
	"kartech": "Картеч", "prytsil": "Приціл", "bochka": "Бочка",
	"vovk": "Вовк", "kulia": "Куля", "zamova": "Замова", "vidvid": "Відвід",
	"zhyvytsia": "Живиця", "pidniaty": "Підняти", "ochyshchennia": "Чисто", "oberih_zahonu": "Загін", "otruta": "Отрута",
	"lightning": "Перун", "molot": "Молот", "burya": "Буря",
	"grad": "Град", "tuman": "Туман", "proklin": "Клятва", "dukh": "Дух"}
const ACTIVE_COLORS := {"vyly": Color(0.55, 0.42, 0.25), "first_aid": Color(0.3, 0.6, 0.3), "whirl": Color(0.55, 0.3, 0.8),
	"battle_cry": Color(0.75, 0.35, 0.15), "musket": Color(0.45, 0.4, 0.3), "fireball": Color(0.85, 0.35, 0.1),
	"shield": Color(0.35, 0.55, 0.85), "herb": Color(0.3, 0.7, 0.35),
	"zemnyi": Color(0.5, 0.35, 0.2), "stina": Color(0.6, 0.55, 0.45), "bulava": Color(0.7, 0.2, 0.15),
	"pastka": Color(0.45, 0.4, 0.25), "tin": Color(0.25, 0.25, 0.35), "kydok": Color(0.55, 0.5, 0.35),
	"kartech": Color(0.5, 0.45, 0.4), "prytsil": Color(0.35, 0.35, 0.5), "bochka": Color(0.6, 0.3, 0.1),
	"vovk": Color(0.45, 0.45, 0.45), "kulia": Color(0.75, 0.65, 0.25), "zamova": Color(0.35, 0.5, 0.9), "vidvid": Color(0.5, 0.3, 0.6),
	"zhyvytsia": Color(0.35, 0.75, 0.4), "pidniaty": Color(0.85, 0.75, 0.4), "ochyshchennia": Color(0.75, 0.9, 1.0), "oberih_zahonu": Color(0.4, 0.6, 0.9), "otruta": Color(0.45, 0.7, 0.2),
	"lightning": Color(0.25, 0.55, 0.9), "molot": Color(0.4, 0.45, 0.8), "burya": Color(0.3, 0.35, 0.6),
	"grad": Color(0.7, 0.85, 0.95), "tuman": Color(0.6, 0.62, 0.68), "proklin": Color(0.45, 0.2, 0.45), "dukh": Color(0.5, 0.8, 0.9)}
## Базова перезарядка (с)
const COOLDOWNS := {"vyly": 4.0, "first_aid": 14.0, "whirl": 8.0, "battle_cry": 20.0, "musket": 4.0,
	"fireball": 3.5, "shield": 18.0, "herb": 12.0,
	"zemnyi": 7.0, "stina": 16.0, "bulava": 6.0,
	"pastka": 6.0, "tin": 14.0, "kydok": 4.0,
	"kartech": 5.0, "prytsil": 7.0, "bochka": 12.0,
	"vovk": 25.0, "kulia": 20.0, "zamova": 15.0, "vidvid": 12.0,
	"zhyvytsia": 12.0, "pidniaty": 60.0, "ochyshchennia": 8.0, "oberih_zahonu": 20.0, "otruta": 5.0,
	"lightning": 6.0, "molot": 9.0, "burya": 22.0,
	"grad": 10.0, "tuman": 16.0, "proklin": 8.0, "dukh": 25.0}


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


static var _actives: Array = []


## Усі активні вміння гри за порядком дерев (кнопки бою будуються з цього переліку).
static func actives() -> Array:
	if _actives.is_empty():
		for c in TREES:
			for b in TREES[c]:
				for n in b["nodes"]:
					if n.get("active", false) and not n["id"] in _actives:
						_actives.append(n["id"])
	return _actives


## Опис активного вміння за даними ("act" у вузлі) або порожній словник.
static func act(id: String) -> Dictionary:
	return find_node(id).get("act", {})


## Підпис на кнопці бою.
static func label(id: String) -> String:
	if ACTIVE_LABELS.has(id):
		return str(ACTIVE_LABELS[id])
	return str(act(id).get("label", node_name(id)))


## Колір кнопки бою.
static func color(id: String) -> Color:
	if ACTIVE_COLORS.has(id):
		return ACTIVE_COLORS[id]
	return Color(str(act(id).get("color", "8a6a3a"))).darkened(0.25)


## Перезарядка вміння в секундах до поправок героя.
static func cooldown(id: String) -> float:
	if COOLDOWNS.has(id):
		return float(COOLDOWNS[id])
	return float(act(id).get("cd", 6.0))


## Значення параметра вміння для рангу: число або [основа, приріст за кожен ранг понад перший].
static func val(v, rank: int) -> float:
	if v is Array:
		return float(v[0]) + float(v[1]) * maxi(0, rank - 1)
	return float(v)


## Пасивні бонуси вмінь за даними: вузли дерева з "fx" (без "act") дають fx[ключ] × ранг.
## "when": {"weapon": [...]} — бонус діє лише з такою зброєю в руках. Повертає {ключ: сума}.
static func passive_fx(job: String, skills: Dictionary, weapon_type: String) -> Dictionary:
	var out := {}
	if skills.is_empty():
		return out
	for c in lineage(job):
		for b in TREES.get(c, []):
			for n in b["nodes"]:
				if not n.has("fx") or n.has("act"):
					continue
				var r := int(skills.get(n["id"], 0))
				if r <= 0:
					continue
				var w: Dictionary = n.get("when", {})
				if w.has("weapon") and not weapon_type in w["weapon"]:
					continue
				for k in n["fx"]:
					out[k] = float(out.get(k, 0.0)) + float(n["fx"][k]) * r
	return out


## Тексти бонусів за даними (число у відсотках, якщо не сказано інше).
const FX_TEXT := {
	"dmg": "+%s%% шкоди", "hp": "+%s%% здоров'я", "armor": "+%s%% захисту", "aspd": "+%s%% швидкості удару",
	"crit": "+%s%% шансу криту", "crit_dmg": "+%s%% шкоди криту", "speed": "+%s%% швидкості бігу",
	"skill": "+%s%% сили вмінь", "cd": "вміння відновлюються на %s%% швидше", "mana": "+%s%% наснаги",
	"mana_regen": "+%s%% відновлення наснаги", "regen_pct": "відновлює %s%% здоров'я за секунду",
	"lifesteal": "+%s%% вампіризму", "dodge_cd": "перекид готовий на %s%% швидше", "range": "+%s%% дальності удару",
	"thorns": "повертає кривдникові %s%% шкоди", "pickup": "+%s%% радіусу збору",
	"ward": "шкода по тобі менша на %s%%", "block": "крізь Блок проходить на %s%% менше шкоди",
	"big_dmg": "+%s%% шкоди елітам і босам", "execute": "+%s%% шкоди нечисті нижче 30%% здоров'я",
	"opener": "+%s%% шкоди нечисті з повним здоров'ям", "status_dmg": "+%s%% шкоди нечисті зі станами",
	"stun_dmg": "+%s%% шкоди приголомшеним", "bleed_hit": "%s%% шансу пустити кров ударом",
	"burn_hit": "%s%% шансу підпалити ударом", "chill_hit": "%s%% шансу застудити ударом",
	"weak_hit": "%s%% шансу знесилити ударом", "curse_hit": "%s%% шансу проклясти ударом",
	"stun_hit": "%s%% шансу приголомшити ударом", "kill_heal": "вбивство лікує %s%% здоров'я",
	"kill_mana": "вбивство вертає %s наснаги", "parry_dmg": "удар у відповідь після парирування сильніший на %s%%",
	"parry_heal": "парирування лікує %s%% здоров'я", "dodge_dmg": "2 с після перекиду +%s%% шкоди",
}


## Бонуси словами: «+8% шкоди, +4% захисту».
static func fx_text(fx: Dictionary, rank: int = 1) -> String:
	var parts := []
	for k in fx:
		var v: float = val(fx[k], rank)
		var num := str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")
		var t: String = str(FX_TEXT.get(k, "%s"))
		if k == "ward" and v < 0.0:
			parts.append("шкода по тобі більша на %s%%" % num.trim_prefix("-"))
			continue
		if v < 0.0 and t.begins_with("+"):
			t = t.substr(1)  # «−5% захисту», а не «+−5%»
			num = "−" + num.trim_prefix("-")
		parts.append(t % num)
	return ", ".join(parts)


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
