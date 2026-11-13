extends RefCounted
## «Попіл за вітром»: продовження історії після Кремля. Зелений попіл Путіноїда розлетівся за край мапи
## й розбудив старе лихо п'яти чужих земель. Кожен крок веде до одного з надважких босів.
## Лінія — запис «saga» у data/quest_lines.json (назва, з якого рівня героя), кроки — data/saga.json
## (перший чекає на Кремль, кожен наступний — на попередній: «after»; поля — docs/data.md). Мета кроку завжди одна: здолати боса
## печери «loc». Хто вже переміг того боса раніше, тому крок зараховується одразу після розмови (SagaService).

const GameDB := preload("res://scripts/core/game_db.gd")

## Лінія саги в quest_lines.json.
const LINE := "saga"

static var _steps := []


## Назва продовження.
static func title() -> String:
	return str(GameDB.row("quest_lines", LINE)["title"])


## З якого рівня героя продовження відкривається.
static func min_level() -> int:
	return int(GameDB.row("quest_lines", LINE)["min_level"])


## Кроки в порядку показу (лише для читання).
static func steps() -> Array:
	if _steps.is_empty():
		var out := []
		for id in GameDB.ids("saga"):
			out.append(GameDB.row("saga", id))
		out.make_read_only()
		_steps = out
	return _steps
