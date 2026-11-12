extends RefCounted
## Надважкі печери: п'ять печер у нових землях по краях мапи, нечисть у них від 100-го рівня.
## Вони сильніші за будь-якого героя: стеля рівня героя нижча. Правила суворіші, ніж деінде
## (див. PerilService): вхід із OPEN_LEVEL-го рівня, печери відкриваються по черзі, смерть коштує
## більше досвіду, а бос лютішає, коли бій затягнувся. Самі печери записані серед місць (data/places.json)
## з позначкою "peril" (порядковий номер) і "land", щоб мапа, дорога й бій працювали з ними як зі звичайними.
## Нові землі з іменними звитягами за їхніх босів — у data/lands.json (порядок файлу — порядок печер).

const GameDB := preload("res://scripts/core/game_db.gd")

const OPEN_LEVEL := 90  # з якого рівня героя пускають у першу печеру
const DEATH_XP_MULT := 3.0  # у скільки разів більше досвіду забирає смерть (проти Data.DEATH_XP_LOSS)
## Уся нечисть надважкої печери понад звичайну нечисть свого рівня. Мірка — герой 99-го рівня в найкращому
## спорядженні: у першій печері він рубає рядову нечисть близько двох секунд і тримає близько десяти її ударів
## (tools/peril_sim.gd). Далі нечисть росте рівнем, а наздоганяти її треба речами з попередньої печери.
const HP_MULT := 5.5
const DMG_MULT := 3.2
## Кожна наступна печера додає до цих множників ще стільки (понад те, що дає рівень нечисті):
## речі з попередньої печери не встигають за нею, тож потрібні ще й набори, золото, душі та звитяги.
const HP_STEP := 0.1
const DMG_STEP := 0.1
const XP_MULT := 4.0  # досвіду з неї теж більше: бій довший
## Надважкий бос понад звичайного боса свого рівня
const BOSS_HP_MULT := 2.0
const BOSS_DMG_MULT := 1.2
## Лють: якщо бос живий довше за ENRAGE_AFTER секунд бою, його удар росте на ENRAGE_DMG кожні ENRAGE_EVERY секунд
const ENRAGE_AFTER := 150.0
const ENRAGE_EVERY := 10.0
const ENRAGE_DMG := 0.08
## Табір біля входу: тут герой отямлюється після смерті в печері, відпочиває й купує зілля в маркітанта
const CAMP_POTION_MARKUP := 1.5

const _EMPTY := {}

static var _by_boss := {}  # бос надважкої печери → земля (складається раз)


## Нова земля (див. GameDB.LAND_SCHEMA): назва, опис, звання й бонус звитяги. Міст у них нема,
## лише табір біля входу до печери.
static func land(id: String) -> Dictionary:
	return GameDB.table("lands").get(id, _EMPTY)


static func is_land(id: String) -> bool:
	return GameDB.table("lands").has(id)


## Землі в порядку печер (порядок файлу).
static func land_ids() -> Array:
	return GameDB.ids("lands")


## Земля, де сидить цей надважкий бос ("" — бос не надважкий).
static func land_of_boss(boss: String) -> String:
	if _by_boss.is_empty():
		var places: Dictionary = GameDB.table("places")
		for id in places:
			if places[id].has("land"):
				_by_boss[str(places[id].get("boss", ""))] = str(places[id]["land"])
		_by_boss.make_read_only()
	return str(_by_boss.get(boss, ""))


## Іменна звитяга: звання героя за першу перемогу над надважким босом ("" — за цього боса нема).
static func boss_title(boss: String) -> String:
	return str(land(land_of_boss(boss)).get("title", ""))


## Вічний бонус іменної звитяги за цього боса (див. Valor); порожній — нема.
static func boss_title_fx(boss: String) -> Dictionary:
	return land(land_of_boss(boss)).get("title_fx", _EMPTY)
