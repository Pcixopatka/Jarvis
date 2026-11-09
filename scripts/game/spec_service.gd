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
	var mentor: String = Classes.CLASSES[s["spec"]]["mentor"]
	return [{"text": "Випробування пройдено!\nПовертайся на Січ до наставника", "big": true, "mentor": mentor}]


## Розмова-посвята на Січі, коли випробування пройдене: {"spec", "lines"} або {}.
static func city_dialogue(world, city: String) -> Dictionary:
	var s := state(world)
	if s.is_empty() or s["stage"] != "turnin" or city != Classes.CLASSES[s["spec"]]["where"]:
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
	return "Ти — %s!\nОтримано: %s" % [Classes.CLASSES[spec]["name"].to_lower(), it["name"]]


static func objective_line(world) -> String:
	var s := state(world)
	if s.is_empty():
		return ""
	if s["stage"] == "turnin":
		return "◆ Повертайся на Січ: посвята в %s" % Classes.CLASSES[s["spec"]]["name"].to_lower()
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
		return Classes.CLASSES[s["spec"]]["where"]
	return objective(world).get("loc", "")
