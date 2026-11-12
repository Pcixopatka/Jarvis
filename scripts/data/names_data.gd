extends RefCounted
## Слова для імен героїв — у data/name_pools.json (docs/data.md, «Імена»): готові козацькі прізвиська
## («ready»), половинки складених — наказове дієслово («verbs») й іменник («nouns»), корені лайки в
## кириличній кістці («bad_cyr»: і, ї → и; є → е; ґ → г; без ь; повтори стиснуті, див. NameService.skeleton_cyr)
## і латинській («bad_lat»), цілі імена-лайка, закороткі для пошуку всередині слова («bad_whole»), імена
## служби гри латинкою — ні цілим іменем, ні початком («reserved»), і закороткі, заборонені лише цілим
## першим словом («reserved_word»). Ті самі таблиці читатиме сервер: правила імен однакові всюди.
## Правила й перевірка: scripts/game/name_service.gd. Таблиця вантажиться, коли вперше потрібна.

const GameDB := preload("res://scripts/core/game_db.gd")
## Пули, які читає NameService (у name_pools.json мусять бути всі).
const POOLS := ["ready", "verbs", "nouns", "bad_cyr", "bad_lat", "bad_whole", "reserved", "reserved_word"]


## Слова пулу (лише для читання); невідомий пул — порожній.
static func words(pool: String) -> Array:
	return GameDB.row("name_pools", pool).get("words", [])
