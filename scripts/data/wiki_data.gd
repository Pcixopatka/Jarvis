extends RefCounted
## Тексти довідника по грі. Усе, що є в таблицях гри (класи, місця, свята, будівлі, клейноди, речі,
## стани, еліти), довідник бере звідти сам (див. WikiService), тож він не розходиться з грою.
## Вдача нечисті й прийоми босів — у data/mobs.json. Власні тексти довідника теж лежать у таблицях
## (docs/data.md, «Тексти довідника»): вкладки (wiki_sections.json), «Як грати» (wiki_basics.json), порядок
## нечисті й босів (wiki_orders.json), групи подій (event_kinds.json) і самі події й заняття (events.json).
## Тут — зручні виклики над ними.

const GameDB := preload("res://scripts/core/game_db.gd")

static var _events: Array = []  # записи подій у порядку файлу (з полем «id»)
static var _basics: Array = []


## Вкладки довідника за порядком: id (його вміст складає WikiService) і назви.
static func section_ids() -> Array:
	return GameDB.ids("wiki_sections")


static func section_title(id: String) -> String:
	return str(GameDB.row("wiki_sections", id).get("title", ""))


## Розділ «Як грати»: [{"title", "text"}] у порядку файлу.
static func basics() -> Array:
	if _basics.is_empty():
		for id in GameDB.ids("wiki_basics"):
			_basics.append(GameDB.row("wiki_basics", id))
		_basics.make_read_only()
	return _basics


## Порядок нечисті й босів у довіднику.
static func enemy_order() -> Array:
	return GameDB.row("wiki_orders", "enemies").get("ids", [])


static func boss_order() -> Array:
	return GameDB.row("wiki_orders", "bosses").get("ids", [])


## Групи подій за порядком і заголовок групи.
static func event_kinds() -> Array:
	return GameDB.ids("event_kinds")


static func event_kind_title(id: String) -> String:
	return str(GameDB.row("event_kinds", id).get("title", ""))


## Події й заняття: [{"id", "name", "kind", "icon", "where", "level", "text", "reward", "battle"?}] у порядку
## файлу. kind — група (event_kinds.json); icon — значок мапи (WorldMap.ICON_ORDER); level — з якого рівня
## героя (0 — від початку). Живий стан кожної дає EventsBoard.
static func events() -> Array:
	if _events.is_empty():
		for id in GameDB.ids("events"):
			_events.append(GameDB.row("events", id))
		_events.make_read_only()
	return _events


## Подія за id ({} — нема).
static func event(id: String) -> Dictionary:
	return GameDB.row("events", id)
