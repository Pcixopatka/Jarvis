extends RefCounted
## Вибір дороги (Козак, Волхв чи Стрілець) після майстерності 10. Стан — world.path_talks:
##   {"cossack": true, "volkhv": true} — з ким уже поговорив.
## Обрати можна лише після всіх розмов; вибір записується як story.choices["trial"] = 0/1/2
## і завершує сюжетний крок "choose", далі сюжет сам іде гілкою oath / to_carpathians.

const Paths := preload("res://scripts/data/paths.gd")
const Classes := preload("res://scripts/data/classes.gd")
const StoryService := preload("res://scripts/game/story_service.gd")

const CHOICE_INDEX := {"cossack": 0, "volkhv": 1, "strilets": 2}


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
	for cls in Paths.ORDER:
		if not talked(world, cls):
			return false
	return true


static func can_choose(world) -> bool:
	return choosing(world) and talked_all(world)


## Розмова з представником дороги.
static func talk_lines(cls: String) -> Array:
	return Paths.TALKS.get(cls, [])


## Обрати дорогу. Записує вибір і закриває крок «choose». Повертає повідомлення сюжету.
static func choose(world, player, cls: String) -> Array:
	if not can_choose(world) or not CHOICE_INDEX.has(cls):
		return []
	world.story["choices"] = world.story.get("choices", {})
	world.story["choices"]["trial"] = CHOICE_INDEX[cls]
	return StoryService.on_event(world, player, "choose", cls)
