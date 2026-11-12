extends RefCounted
## Козацький хутір. Записи — у таблицях data/*.json (docs/data.md, «Хутір»): сам хутір (camps.json), ресурси
## героя з кольорами (resources.json), будівлі з ціною й тим, що дає кожен рівень (buildings.json), культури
## городу (crops.json), зілля (brews.json), клейноди роду (kleinody.json) і ціни їхніх ступенів
## (kleinod_tiers.json). Тут — зручні виклики над ними й числа-правила.

const GameDB := preload("res://scripts/core/game_db.gd")
const CAMP_ID := "hutir"
## Трофеї — рідкісний матеріал для кування (з еліт, босів, облог); не випадає зі звичайної нечисті
const TROPHY := "trophy"


static var _by_kind := {}  # вид ресурсу (res, trophy, food) → id у порядку файлу


## Хутір на мапі: {"name", "pos", "desc"}.
static func camp() -> Dictionary:
	return GameDB.row("camps", CAMP_ID)


## Будівельні ресурси (дерево, залізо, трави) у порядку файлу.
static func resources() -> Array:
	return _kind("res")


## Провіант (м'ясо, риба, городина) у порядку файлу.
static func food_ids() -> Array:
	return _kind("food")


static func _kind(kind: String) -> Array:
	if _by_kind.is_empty():
		for id in GameDB.ids("resources"):
			var k := str(GameDB.row("resources", id)["kind"])
			if not _by_kind.has(k):
				_by_kind[k] = []
			_by_kind[k].append(id)
		for k in _by_kind:
			_by_kind[k].make_read_only()
	return _by_kind.get(kind, [])


## Чи це будівельний ресурс.
static func is_resource(r: String) -> bool:
	return str(GameDB.row("resources", r).get("kind", "")) == "res"


## Назва ресурсу, трофеїв чи провіанту; невідоме — як є.
static func res_name(r: String) -> String:
	return str(GameDB.row("resources", r).get("name", r))


## Колір ресурсу (підбирачка, значок); невідомого — білий.
static func res_color(r: String) -> Color:
	return GameDB.row("resources", r).get("color", Color.WHITE)


## Який ресурс найчастіше дає краєвид («resource» у data/biomes.json; без нього — дерево).
static func biome_resource(biome: String) -> String:
	return str(GameDB.row("biomes", biome).get("resource", "wood"))

## Скільки добра падає з нечисті. У версії 0.45 усе це вдвічі-втричі рідше: розвинений герой збирав
## ресурси десятками тисяч, і витратити їх було нікуди.
const RESOURCE_DROP_CHANCE := 0.1  # шанс ресурсу з рядового ворога (було 0,25)
const BUNDLE_LEVEL_STEP := 10  # у жмені ресурсів з еліти, боса чи зачистки 1 + рівень/10 одиниць (було рівень/4)
const TROPHY_ELITE_CHANCE := 0.5  # еліта лишає трофей через раз (було завжди)
const TROPHY_BOSS_BASE := 2  # бос: 2 + рівень/10 трофеїв (було 3 + рівень/5)
const TROPHY_BOSS_LEVEL_STEP := 10
const TROPHY_BOUNTY := 1  # голова з дошки розшуку (було 2)


## Скільки одиниць ресурсу в одній жмені на цьому рівні.
static func bundle_amount(level: int) -> int:
	return 1 + level / BUNDLE_LEVEL_STEP


## Скільки трофеїв лишає бос цього рівня.
static func boss_trophies(level: int) -> int:
	return TROPHY_BOSS_BASE + level / TROPHY_BOSS_LEVEL_STEP

# ======================= Будівлі =======================

## Будівля ({} — нема) і будівлі в порядку показу.
static func building(id: String) -> Dictionary:
	return GameDB.row("buildings", id)


static func building_ids() -> Array:
	return GameDB.ids("buildings")


## Число рівня будівлі (bag, rate, beds); рівень 0 — нічого, вище найвищого — як найвищий.
static func level_value(id: String, field: String, level: int) -> int:
	var lv: Array = building(id).get("levels", [])
	if level <= 0 or lv.is_empty():
		return 0
	return int(lv[mini(level, lv.size()) - 1].get(field, 0))


const GARDEN_FAST := 0.75  # на 3-му рівні городу час росту множиться на це
const PASIKA_CAP_HOURS := 12.0

# ======================= Клейноди роду =======================
## Довгі цілі для зароблених гривень, трофеїв і ресурсів (див. KleinodService).
## Сім козацьких клейнодів, у кожного п'ять ступенів. Кожен ступінь додає свій бонус усім персонажам роду.
## Головна ціна — гривні (465 000 за клейнод, 3 255 000 за всі сім): саме їх у пізній грі нема куди подіти.
## Трофеїв і ресурсів треба стільки, щоб вони не стримували покупку сильніше за гривні:
## 300 трофеїв і 2 670 ресурсу на клейнод. Заліза (його дає переплавка) просять чотири клейноди з семи.

## Ціна ступеня, який купують на рівні level (0 — перший): {"gold", "trophy", "res"}; {} — вище нема.
static func kleinod_tier(level: int) -> Dictionary:
	var lad := GameDB.ladder("kleinod_tiers", "tier")
	return lad[level + 1] if level + 1 < lad.size() else {}


## Скільки ступенів у клейнода.
static func kleinod_tiers() -> int:
	return GameDB.ladder("kleinod_tiers", "tier").size() - 1


# ======================= Город, зілляварня, клейноди: записи =======================

## Культура городу ({} — нема) і культури в порядку показу.
static func crop(id: String) -> Dictionary:
	return GameDB.row("crops", id)


static func crop_ids() -> Array:
	return GameDB.ids("crops")


## Зілля із Зілляварні ({} — нема) і всі зілля в порядку показу.
static func brew(id: String) -> Dictionary:
	return GameDB.row("brews", id)


static func brew_ids() -> Array:
	return GameDB.ids("brews")


## Клейнод ({} — нема) і клейноди в порядку показу.
static func kleinod(id: String) -> Dictionary:
	return GameDB.row("kleinody", id)


static func kleinod_ids() -> Array:
	return GameDB.ids("kleinody")
