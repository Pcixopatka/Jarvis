extends RefCounted
## Спеціалізації: випробування в наставників. Стан — world.spec_trial:
##   {"spec": id класу, "stage": "active"/"turnin", "progress": n}
## Козак із майстерністю 30+ іде на Січ, обирає наставника у вкладці «Наставники»,
## проходить випробування й повертається — наставник посвячує в спеціалізацію.

const Classes := preload("res://scripts/data/classes.gd")
const Data := preload("res://scripts/data/data.gd")

const TRIALS := {
	"zaporozhets": {
		"start": [
			["myron", "Хочеш стати запорожцем? Запорожець — це стіна, об яку розбивається орда."],
			["myron", "Пройди Смоленський шлях від краю до краю. Не відступай ні на крок — і я назву тебе братом."],
		],
		"objective": {"type": "clear", "loc": "smolensk_road", "text": "Випробування запорожця: пройди Смоленський шлях"},
		"end": [
			["myron", "Пройшов. Не зігнувся. Бачу — ти з тих, хто стоїть, коли інші тікають."],
			["myron", "Відтепер ти запорожець. Тримай булаву — нехай лягає важко."],
		],
		"item": {"type": "mace", "name": "Булава осавула"},
	},
	"plastun": {
		"start": [
			["sava", "Пластун не б'ється в лоб. Пластун чекає, вистежує — і б'є раз, але наповал."],
			["sava", "Вполюй вісім найлютіших — еліту нечисті. Як вистежиш їх усіх, приходь."],
		],
		"objective": {"type": "elite", "count": 8, "text": "Випробування пластуна: вполюй 8 еліт"},
		"end": [
			["sava", "Вісім. Тихо й чисто. Ти вже ходиш, як пластун."],
			["sava", "Ось мій спис. Він знає дорогу до серця будь-якого ворога."],
		],
		"item": {"type": "pike", "name": "Спис пластуна"},
	},
	"samopalnyk": {
		"start": [
			["okhrim", "Шабля — це добре, але порох — краще! Хочеш до гармашів?"],
			["okhrim", "Заражені пищальники носять добрий порох. Поклади двадцять п'ять — і принеси мені їхні порохівниці."],
		],
		"objective": {"type": "kill", "enemy": "pishchalnyk", "count": 25, "loc": "smolensk_road", "text": "Випробування самопальника: поклади заражених пищальників"},
		"end": [
			["okhrim", "Ха! Пахне порохом — значить, свій! Відтепер ти самопальник."],
			["okhrim", "Тримай пищаль. Сам кував ствол. Б'є так, що аж у Москві чути."],
		],
		"item": {"type": "pishchal", "name": "Пищаль Охріма"},
	},
	"kharakternyk": {
		"start": [
			["yarema", "Характерником не стають — характерником народжуються. Та я бачу в тобі іскру."],
			["yarema", "Іди в Кощієву вежу. Подивися смерті в очі — і не відведи погляду. Тоді вовк у тобі прокинеться."],
		],
		"objective": {"type": "dungeon", "loc": "koshchii_tower", "text": "Випробування характерника: пройди Кощієву вежу"},
		"end": [
			["yarema", "Повернувся. І очі в тебе вже інші — вовчі."],
			["yarema", "Тепер ти характерник. Бери замовлену шаблю — куля тебе не візьме, а шабля не підведе."],
		],
		"item": {"type": "sabre", "name": "Замовлена шабля"},
	},
	"sahaidachnyk": {
		"start": [
			["oryna", "Лук любить терплячих. Натягнеш зарано — схибиш, запізно — тебе вже гризуть."],
			["oryna", "Пройди Путивльську пущу від краю до краю. Там темно й тісно: саме те, щоб навчитися бити напевно."],
		],
		"objective": {"type": "clear", "loc": "putyvl_pushcha", "text": "Випробування сагайдачника: пройди Путивльську пущу"},
		"end": [
			["oryna", "Вийшов із пущі, і сагайдак не порожній. Отже, не марнував стріл."],
			["oryna", "Бери мій лук. Тятива туга, зате співає. Відтепер ти сагайдачник."],
		],
		"item": {"type": "bow", "name": "Лук Орини"},
	},
	"opryshok": {
		"start": [
			["opryshok", "Опришком не стають у корчмі. Опришком стають у горах, коли нема куди відступати."],
			["opryshok", "Іди в Печеру Довбуша. Хто вийде звідти живим, тому Олексина бартка до руки."],
		],
		"objective": {"type": "dungeon", "loc": "dovbush_cave", "text": "Випробування опришка: пройди Печеру Довбуша"},
		"end": [
			["opryshok", "Живий. І вовчий ватажок лежить. Гори тебе прийняли, легеню."],
			["opryshok", "Ось тобі пара пістолів. Кріси лишай панам, а опришок б'є з двох рук."],
		],
		"item": {"type": "pistols", "name": "Пістолі Чорногорця"},
	},
	"sokolnyk": {
		"start": [
			["tymish", "Сокіл не слуга. Він летить із тим, кого поважає, а поважає він добрих ловців."],
			["tymish", "Вполюй шість найлютіших із нечисті. Птах дивитиметься згори й сам вирішить."],
		],
		"objective": {"type": "elite", "count": 6, "text": "Випробування сокольника: вполюй 6 еліт"},
		"end": [
			["tymish", "Шість. Він увесь час кружляв над тобою, ти помітив?"],
			["tymish", "Підстав руку. Бачиш, сів. Відтепер ви вдвох, сокольнику. І лук візьми, ловецький."],
		],
		"item": {"type": "bow", "name": "Ловецький лук"},
	},
	"znakhar": {
		"start": [
			["paraska", "Знахар не той, хто вбиває заразу, а той, хто повертає людей до життя."],
			["paraska", "Брянські ліси — серце хвороби. Пройди їх наскрізь і вийди живим — тоді я передам тобі свої трави."],
		],
		"objective": {"type": "clear", "loc": "bryansk_forest", "text": "Випробування знахаря: пройди Брянські ліси"},
		"end": [
			["paraska", "Живий, і руки не тремтять. Значить, і чужу рану втримаєш."],
			["paraska", "Відтепер ти знахар. Ось мій посох із калини — він пам'ятає тисячу зцілень."],
		],
		"item": {"type": "staff", "name": "Калиновий посох"},
	},
	"perun_zhrets": {
		"start": [
			["hromobii", "Перун не любить боягузів. Чорти — тим паче: вони ховаються від грому по болотах і щілинах."],
			["hromobii", "Вибий двадцять п'ять чортів — і небо визнає тебе своїм."],
		],
		"objective": {"type": "kill", "enemy": "chort", "count": 25, "loc": "kamianets_walls", "text": "Випробування жерця: вибий чортів (Кам'янецькі мури)"},
		"end": [
			["hromobii", "Чуєш? Грім над Попом Іваном. Це Перун тебе вітає."],
			["hromobii", "Ти — Перунів жрець. Бери посох із дуба, в який тричі била блискавка."],
		],
		"item": {"type": "staff", "name": "Посох громового дуба"},
	},
	"molfar": {
		"start": [
			["yakym", "Мольфарство — це розмова з горами. А гори говорять із тими, хто не боїться темряви."],
			["yakym", "Спустися в печеру Довбуша й здолай вовкулаку-ватажка. Тоді й поговоримо."],
		],
		"objective": {"type": "dungeon", "loc": "dovbush_cave", "text": "Випробування мольфара: пройди Печеру Довбуша"},
		"end": [
			["yakym", "Гори тебе пропустили. Не кожного вони випускають."],
			["yakym", "Ти — мольфар. Тримай мій топірець-посох: ним я колись розігнав градову хмару над Жаб'єм."],
		],
		"item": {"type": "staff", "name": "Мольфарський посох"},
	},
}


static func state(world) -> Dictionary:
	return world.spec_trial


## Спеціалізації, які зараз відкриті для героя (порожньо, якщо ще рано).
static func available(player) -> Array:
	if not player.can_change_class():
		return []
	return player.class_info()["next"].filter(func(c): return TRIALS.has(c))


static func start(world, player, spec: String) -> bool:
	if not spec in available(player):
		return false
	world.spec_trial = {"spec": spec, "stage": "active", "progress": 0}
	return true


static func objective(world) -> Dictionary:
	var s := state(world)
	if s.is_empty():
		return {}
	return TRIALS[s["spec"]]["objective"]


## Подія в поході. elite — чи вбитий ворог був елітою.
static func on_event(world, type: String, arg: String) -> Array:
	var s := state(world)
	if s.is_empty() or s["stage"] != "active":
		return []
	var obj := objective(world)
	var done := false
	match type:
		"clear", "dungeon":
			done = obj["type"] == type and obj["loc"] == arg
		"kill":
			if obj["type"] == "kill" and obj["enemy"] == arg:
				s["progress"] = int(s["progress"]) + 1
				done = int(s["progress"]) >= int(obj["count"])
		"elite":
			if obj["type"] == "elite":
				s["progress"] = int(s["progress"]) + 1
				done = int(s["progress"]) >= int(obj["count"])
	if not done:
		return []
	s["stage"] = "turnin"
	var mentor: String = Classes.info(s["spec"])["mentor"]
	return [{"text": "Випробування пройдено!\nНаставник чекає: %s" % Data.place_name(str(Classes.info(s["spec"])["where"])), "big": true, "mentor": mentor}]


## Розмова-посвята на Січі, коли випробування пройдене: {"spec", "lines"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	var s := state(world)
	if s.is_empty() or s["stage"] != "turnin" or city != Classes.info(s["spec"])["where"]:
		return {}
	return {"spec": s["spec"], "lines": TRIALS[s["spec"]]["end"]}


## Посвята: новий клас, зброя від наставника. Повертає текст для банера.
static func complete(world, player) -> String:
	var s := state(world)
	if s.is_empty() or s["stage"] != "turnin":
		return ""
	var spec: String = s["spec"]
	var t: Dictionary = TRIALS[spec]
	player.change_class(spec)
	var it := Data.gen_item(maxi(player.level, 1), 2, "weapon", t["item"]["type"])
	it["name"] = t["item"]["name"]
	if not player.add_item(it):
		player.inventory.append(it)
	player.equip(it["uid"])
	world.spec_trial = {}
	return "Ти — %s!\nОтримано: %s" % [Classes.info(spec)["name"].to_lower(), it["name"]]


static func objective_line(world) -> String:
	var s := state(world)
	if s.is_empty():
		return ""
	if s["stage"] == "turnin":
		return "◆ Повертайся до наставника (%s): посвята в %s" % [Data.place_name(str(Classes.info(s["spec"])["where"])), Classes.info(s["spec"])["name"].to_lower()]
	var obj := objective(world)
	var line: String = "◆ " + obj["text"]
	if obj.has("count"):
		line += " %d/%d" % [s["progress"], obj["count"]]
	return line


static func target(world) -> String:
	var s := state(world)
	if s.is_empty():
		return ""
	if s["stage"] == "turnin":
		return Classes.info(s["spec"])["where"]
	return objective(world).get("loc", "")
