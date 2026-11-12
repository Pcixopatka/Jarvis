extends RefCounted
## Душі нечисті. У кожної нечисті й кожного боса своя душа; падає вкрай рідко.
## Душу вселяють у гніздо речі (його пробиває коваль), і вона діє, поки річ вдягнена.
## Жодна душа не лікує й не дає наснаги; однакові душі разом не діють, у кожного бонусу є межа.

const GameDB := preload("res://scripts/core/game_db.gd")

## Шанс душі за одне вбивство (до поправки на гідність ворога й поклик душ).
const CHANCE := {"regular": 0.00005, "elite": 0.00015, "named": 0.005, "boss": 0.005}
const CHANCE_PERIL := 0.03  # надважкий бос у своїй печері: бій довгий і лютий, тож душа падає частіше
const W_MIN := 0.1  # найменша гідність рядового ворога, набагато слабшого за нечисть рівня героя
const W_MIN_BOSS := 0.25
const PITY_MAX := 2.0  # поклик душ: невдачі підіймають шанс щонайбільше втричі
const FIRST_LEVEL := 10  # перша душа героя: з першого ж елітного, розшукуваного чи боса від цього рівня (0 — вимкнено)
const PROC_LOCK := 8.0  # той самий стан від душі лягає на того самого ворога не частіше ніж раз на стільки секунд
const BOSS_TIER := 4  # душі від цього ступеня стають лише в зброю й оберіг
const BOSS_SLOTS := ["weapon", "amulet"]
const SOCKET_TROPHY := 3
const REMOVE_PART := 0.1  # вийняти душу коштує цю частку ціни гнізда

## Записи — у data/souls.json (душі: назва, ступінь, бонуси «fx» у відсотках, переказ), data/soul_effects.json
## (тексти бонусів і межа суми всіх душ разом) і data/soul_tiers.json (ступені: назва, колір, ціна).
## id душі: для рядової нечисті — її вид, для боса — "b_" + вид.

## Ключі, яких у душ бути не може: гра не має ставати легшою (перевіряє GameDB.problems()).
const FORBIDDEN := ["regen", "lifesteal", "mana", "mana_regen", "heal"]

static var _tiers: Array = []  # записи ступенів за номером (0 — порожній)
static var _colors: Array = []


## Запис душі (souls.json); для невідомої — порожній.
static func def(id: String) -> Dictionary:
	return GameDB.soul(id)


static func has(id: String) -> bool:
	return GameDB.table("souls").has(id)


## Усі душі в порядку файлу.
static func ids() -> Array:
	return GameDB.ids("souls")


## Бонус душі: {text, cap} (soul_effects.json).
static func fx(key: String) -> Dictionary:
	return GameDB.row("soul_effects", key)


static func _tier(t: int) -> Dictionary:
	if _tiers.is_empty():
		_tiers = GameDB.ladder("soul_tiers", "tier")
		for R in _tiers:
			_colors.append(R.get("color", Color.WHITE))
		_colors.make_read_only()
	return _tiers[t] if t >= 0 and t < _tiers.size() else {}


## Найвищий ступінь душі.
static func max_tier() -> int:
	_tier(0)
	return _tiers.size() - 1


static func tier_name(t: int) -> String:
	return str(_tier(t).get("name", ""))


static func tier_color(t: int) -> Color:
	_tier(0)
	return _colors[t]


## Ціна душі цього ступеня в крамниці, червінців.
static func tier_price(t: int) -> int:
	return int(_tier(t).get("price", 0))
