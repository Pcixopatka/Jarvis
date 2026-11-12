extends RefCounted
## «Шлях козака»: ланцюжок перших цілей, що по черзі вчить кожній системі гри.
## Кроки — data/way.json у порядку проходження: що зробити (title), як саме (how), умова (check),
## нагорода (reward) і куди йти (go). Поля — docs/data.md і GameDB.WAY_SCHEMA; правила перевірки й
## нагороди — у WayService. Новий крок додається одним записом; довідник, журнал і порадник підхоплять
## його самі. Збереження тримає номер нинішнього кроку (місце у файлі).
##
## check — одна з умов (WayService.CHECKS):
##   {"stat": лічильник із world.stats, "n": скільки, "or": ще один лічильник, що додається}
##   {"equip": скільки клітинок вдягнено}
##   {"spent": "stat" | "skill" | "perk"}   — вкладено хоч одне очко
##   {"quests": 1}       — узято чи вже здано завдання міста
##   {"loyalty": 1}      — здано завдання (є лояльність якогось міста)
##   {"companions": 1}   — у загоні є побратим
##   {"camp": 1}         — на хуторі є будівля
##   {"tier": 1 | 2}     — обрано дорогу (1) чи спеціалізацію (2)
## reward — {"gold", "potions", "mana", "res": {назва: скільки}, "trophy", "item": рідкість, "stone": id каменя}
## go — куди веде порада: {"place": id | "city" (найближче місто) | "spot" (місцевість по силі) | "dungeon" (перша печера)}
##      або {"tab": номер вкладки екрана героя}

const GameDB := preload("res://scripts/core/game_db.gd")

static var _steps := []


## Кроки в порядку проходження (лише для читання).
static func steps() -> Array:
	if _steps.is_empty():
		var out := []
		for id in GameDB.ids("way"):
			out.append(GameDB.row("way", id))
		out.make_read_only()
		_steps = out
	return _steps
