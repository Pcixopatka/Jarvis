extends RefCounted
## Перекази: квестові лінійки за легендами земель, які вже є на мапі. Кожна лінійка незалежна від
## сюжету й від інших лінійок: герой може вести кілька одразу. Відкривається з min_level-го рівня героя.
## Лінійка — запис із «kind»: «legend» у data/quest_lines.json (title, land, source, min_level; порядок
## файлу — порядок показу), її кроки — data/legend_steps.json з «line» (у якому порядку вони йдуть, задає
## «after», див. QuestEngine; порядок файлу — порядок показу).
## Мета кроку: clear, dungeon, kill, fetch; нагорода: gold_lvl (гривень за рівень героя), trophy, item
## рівня героя. Поля — docs/data.md.
## Нечисть у місці переказу міряється рівнем із героєм (LegendService.mods_for), тож стара печера
## не стає прогулянкою. Каталог переказів усієї Європи й план наступних лінійок: docs/legends.md.
## Кощієву голку розказує головна історія, а п'ять надважких земель — сага «Попіл за вітром» (Saga),
## тому окремих лінійок про них тут нема.

const GameDB := preload("res://scripts/core/game_db.gd")

static var _order := []  # id лінійок у порядку файлу
static var _steps := {}  # лінійка → [записи кроків]


static func _index() -> void:
	if not _order.is_empty():
		return
	var steps := {}
	for id in GameDB.ids("quest_lines"):
		if str(GameDB.row("quest_lines", id)["kind"]) == "legend":
			_order.append(id)
			steps[id] = []
	for id in GameDB.ids("legend_steps"):
		var R: Dictionary = GameDB.row("legend_steps", id)
		if steps.has(str(R["line"])):
			steps[str(R["line"])].append(R)
	for k in steps:
		steps[k].make_read_only()
	steps.make_read_only()
	_order.make_read_only()
	_steps = steps


## Лінійки переказів у порядку показу.
static func order() -> Array:
	_index()
	return _order


static func has_line(id: String) -> bool:
	_index()
	return _steps.has(id)


## Запис лінійки {title, land, source, min_level} ({} — нема такої).
static func line(id: String) -> Dictionary:
	return GameDB.row("quest_lines", id) if has_line(id) else {}


## Кроки лінійки в порядку показу (лише для читання).
static func steps(id: String) -> Array:
	_index()
	return _steps.get(id, [])
