extends RefCounted
## Історія: зручні виклики над таблицями data/story.json (кроки), data/story_chapters.json (розділи) і
## data/speakers.json (мовці розмов). Самих даних тут нема: поля кроку описано в docs/data.md і в
## GameDB.STORY_SCHEMA, що відкрито — вирішує QuestEngine за «after», розмови й нагороди — StoryService.
##
## Порядок записів у файлах — лише порядок показу (розділи в журналі, «Літопис»); збереження тримає id
## кроків. Покажчики (кроки розділу, місце кроку) складаються раз і лише для читання.

const GameDB := preload("res://scripts/core/game_db.gd")

## Лінія історії в quest_lines.json.
const LINE := "story"
## Мовці, яких знає сам код: герой і його голос волхва (StoryService.lines), селянин (Game._hall_npc),
## дорожні пригоди (TravelService). Їхні записи мусять бути в speakers.json.
const CODE_SPEAKERS := ["hero", "hero_volkhv", "selianyn", "chumak", "gonets", "koval", "bizhenka", "doroha"]

static var _steps := []  # номер розділу → [записи кроків]
static var _pos := {}  # id кроку → Vector2i(розділ, крок у розділі)


static func _index() -> void:
	if not _steps.is_empty():
		return
	var chapters: Array = GameDB.ids("story_chapters")
	var out := []
	for c in chapters:
		out.append([])
	for id in GameDB.ids("story"):
		var R: Dictionary = GameDB.row("story", id)
		var ci := chapters.find(str(R["chapter"]))
		_pos[id] = Vector2i(ci, out[ci].size())
		out[ci].append(R)
	for a in out:
		a.make_read_only()
	out.make_read_only()
	_pos.make_read_only()
	_steps = out


# ---------- Мовці ----------

## Мовець {name, role}; невідомий — fallback (порожній, якщо не дано).
static func npc(id: String, fallback: Dictionary = {}) -> Dictionary:
	return GameDB.table("speakers").get(id, fallback)


static func has_npc(id: String) -> bool:
	return GameDB.table("speakers").has(id)


static func npc_name(id: String) -> String:
	return str(npc(id)["name"])


# ---------- Розділи й кроки ----------

static func chapter_count() -> int:
	return GameDB.ids("story_chapters").size()


## Запис розділу за номером ({} — нема такого).
static func chapter(i: int) -> Dictionary:
	var c: Array = GameDB.ids("story_chapters")
	return GameDB.row("story_chapters", c[i]) if i >= 0 and i < c.size() else {}


## Номер розділу за id (-1 — нема такого).
static func chapter_index(id: String) -> int:
	return GameDB.ids("story_chapters").find(id)


static func chapter_title(i: int) -> String:
	return str(chapter(i)["title"])


## Кроки розділу в порядку показу (лише для читання).
static func steps(i: int) -> Array:
	_index()
	return _steps[i]


## Крок за id ({} — нема такого).
static func step(id: String) -> Dictionary:
	return GameDB.row("story", id)


## Усі кроки в порядку показу.
static func step_ids() -> Array:
	return GameDB.ids("story")


## Де крок: Vector2i(номер розділу, номер у розділі); (-1, -1) — нема такого.
static func position(id: String) -> Vector2i:
	_index()
	return _pos.get(id, Vector2i(-1, -1))


## Під яким ключем зберігається вибір кроку (world.missions.choices, див. QuestEngine).
static func choice_key(st: Dictionary) -> String:
	return str(st.get("choice_key", st["id"]))
