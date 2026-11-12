extends RefCounted
## Вибір дороги (Козак, Волхв чи Стрілець) після майстерності 10. Стан — world.path_talks:
##   {"cossack": true, "volkhv": true} — з ким уже поговорив.
## Обрати можна лише після всіх розмов; вибір записується як story.choices["trial"] = 0/1/2 (номер вибору
## з «class» цього класу в кроці "choose" data/story.json, ключ — його «choice_key») і завершує сюжетний
## крок "choose", далі сюжет сам іде гілкою oath / to_carpathians / to_baturyn.

const Paths := preload("res://scripts/data/paths.gd")
const Classes := preload("res://scripts/data/classes.gd")
const StoryService := preload("res://scripts/game/story_service.gd")



## Чи зараз герой стоїть перед вибором дороги (крок «choose» активний).
static func choosing(world) -> bool:
	var s := StoryService.state(world)
	if s["stage"] != "active":
		return false
	return StoryService.current(world).get("id", "") == "choose"


static func talked(world, cls: String) -> bool:
	return world.path_talks.get(cls, false)


static func mark_talked(world, cls: String) -> void:
	world.path_talks[cls] = true


## Чи вислухано всіх представників доріг.
static func talked_all(world) -> bool:
	for cls in Paths.order():
		if not talked(world, cls):
			return false
	return true


static func can_choose(world) -> bool:
	return choosing(world) and talked_all(world)


## Розмова з представником дороги.
static func talk_lines(cls: String) -> Array:
	return Paths.talk(cls)


## Обрати дорогу. Записує вибір і закриває крок «choose». Повертає повідомлення сюжету.
static func choose(world, player, cls: String) -> Array:
	if not can_choose(world):
		return []
	var st: Dictionary = StoryService.current(world)
	var ci := -1
	for i in st.get("choices", []).size():
		if str(st["choices"][i].get("class", "")) == cls:
			ci = i
			break
	if ci < 0:
		return []
	world.story["choices"] = world.story.get("choices", {})
	world.story["choices"][StoryService.Story.choice_key(st)] = ci
	return StoryService.on_event(world, player, "choose", cls)
