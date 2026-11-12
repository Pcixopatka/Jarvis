extends RefCounted
## Надважкі печери: п'ять печер у нових землях по краях мапи, нечисть у них від 100-го рівня.
## Вони сильніші за будь-якого героя: стеля рівня героя нижча. Правила суворіші, ніж деінде
## (див. PerilService): вхід із OPEN_LEVEL-го рівня, печери відкриваються по черзі, смерть коштує
## більше досвіду, а бос лютішає, коли бій затягнувся. Самі печери записані серед місць (data/places.json)
## з позначкою "peril" (порядковий номер) і "land", щоб мапа, дорога й бій працювали з ними як зі звичайними.
## Нові землі з іменними звитягами за їхніх босів — у data/lands.json (порядок файлу — порядок печер).

const GameDB := preload("res://scripts/core/game_db.gd")

static var OPEN_LEVEL: int  # з якого рівня героя пускають у першу надважку печеру
static var DEATH_XP_MULT: float  # смерть у надважкій печері забирає у стільки разів більше досвіду (проти death.death_xp_loss)
## Уся нечисть надважкої печери понад звичайну нечисть свого рівня. Мірка — герой 99-го рівня в найкращому
## спорядженні: у першій печері він рубає рядову нечисть близько двох секунд і тримає близько десяти її ударів
## (tools/peril_sim.gd). Далі нечисть росте рівнем, а наздоганяти її треба речами з попередньої печери.
static var HP_MULT: float  # нечисть надважкої печери у стільки разів здоровіша за звичайну свого рівня
static var DMG_MULT: float  # і б'є у стільки разів сильніше
## Кожна наступна печера додає до цих множників ще стільки (понад те, що дає рівень нечисті):
## речі з попередньої печери не встигають за нею, тож потрібні ще й набори, золото, душі та звитяги.
static var HP_STEP: float  # кожна наступна печера додає до hp_mult ще стільки
static var DMG_STEP: float  # і до dmg_mult стільки
static var XP_MULT: float  # досвіду з нечисті надважкої печери у стільки разів більше
## Надважкий бос понад звичайного боса свого рівня
static var BOSS_HP_MULT: float  # надважкий бос у стільки разів здоровіший за звичайного боса свого рівня
static var BOSS_DMG_MULT: float  # і б'є у стільки разів сильніше
## Лють: якщо бос живий довше за ENRAGE_AFTER секунд бою, його удар росте на ENRAGE_DMG кожні ENRAGE_EVERY секунд
static var ENRAGE_AFTER: float  # лють: бос, живий довше за стільки секунд бою…
static var ENRAGE_EVERY: float  # …кожні стільки секунд…
static var ENRAGE_DMG: float  # …б'є сильніше на цю частку
## Табір біля входу: тут герой отямлюється після смерті в печері, відпочиває й купує зілля в маркітанта
static var CAMP_POTION_MARKUP: float  # зілля в маркітанта табору у стільки разів дорожче


## Числа-правила вище лежать у data/settings.json (запис «peril»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("peril")
	OPEN_LEVEL = S["open_level"]
	DEATH_XP_MULT = S["death_xp_mult"]
	HP_MULT = S["hp_mult"]
	DMG_MULT = S["dmg_mult"]
	HP_STEP = S["hp_step"]
	DMG_STEP = S["dmg_step"]
	XP_MULT = S["xp_mult"]
	BOSS_HP_MULT = S["boss_hp_mult"]
	BOSS_DMG_MULT = S["boss_dmg_mult"]
	ENRAGE_AFTER = S["enrage_after"]
	ENRAGE_EVERY = S["enrage_every"]
	ENRAGE_DMG = S["enrage_dmg"]
	CAMP_POTION_MARKUP = S["camp_potion_markup"]


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
