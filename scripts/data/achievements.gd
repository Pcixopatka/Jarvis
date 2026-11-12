extends RefCounted
## Виклики дня й тижня та постійні досягнення. Шаблони викликів — data/daily.json і data/weekly.json,
## досягнення — data/achievements.json (поля — docs/data.md). Правила — у ChallengeService.
## stat — лічильник із world.stats (перелік тих, що гра рахує, — ChallengeService.STATS і STAT_PREFIXES).
##
## Виклик має групу: "base" (бій і господарство; за замовчуванням) або "event" — проходження подій і занять:
## варта, герць, розшук, супровід, події світу, сліди, Башта, Глибини. Щодня й щотижня частина викликів
## обов'язково з групи подій (DAILY_EVENTS / WEEKLY_EVENTS).
## need — що має бути відкрито гравцеві, щоб виклик міг випасти (ChallengeService.NEEDS, available);
## where — підказка, куди йти. Порядок шаблонів у файлі важить: з нього кидається, що випаде сьогодні.

const GameDB := preload("res://scripts/core/game_db.gd")

## Скільки викликів щодня й щотижня і скільки з них про події й заняття (правила, не записи).
const DAILY_COUNT := 4
const DAILY_EVENTS := 2  # скільки з них про події й заняття
const WEEKLY_COUNT := 3
const WEEKLY_EVENTS := 2

static var _lists := {}  # таблиця → [записи в порядку файлу]


static func _list(name: String) -> Array:
	if not _lists.has(name):
		var out := []
		for id in GameDB.ids(name):
			out.append(GameDB.row(name, id))
		out.make_read_only()
		_lists[name] = out
	return _lists[name]


## Шаблони щоденних викликів у порядку файлу (лише для читання).
static func daily() -> Array:
	return _list("daily")


## Шаблони тижневих викликів.
static func weekly() -> Array:
	return _list("weekly")


## Досягнення в порядку показу; кожне має «id».
static func achievements() -> Array:
	return _list("achievements")
