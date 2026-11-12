extends RefCounted
## Душі нечисті. У кожної нечисті й кожного боса своя душа; падає вкрай рідко.
## Душу вселяють у гніздо речі (його пробиває коваль), і вона діє, поки річ вдягнена.
## Жодна душа не лікує й не дає наснаги; однакові душі разом не діють, у кожного бонусу є межа.

const GameDB := preload("res://scripts/core/game_db.gd")

## Шанс душі за одне вбивство (до поправки на гідність ворога й поклик душ).
static var CHANCE: Dictionary  # шанс душі за одне вбивство за родом ворога (до поправки на гідність і поклик душ)
static var CHANCE_PERIL: float  # шанс душі з надважкого боса в його печері
static var W_MIN: float  # найменша гідність рядового ворога, набагато слабшого за нечисть рівня героя (множник шансу)
static var W_MIN_BOSS: float  # найменша гідність боса
static var PITY_MAX: float  # поклик душ: невдачі підіймають шанс щонайбільше в (1 + стільки) разів
static var FIRST_LEVEL: int  # перша душа героя — з першого ж елітного, розшукуваного чи боса від цього рівня (0 — вимкнено)
static var PROC_LOCK: float  # той самий стан від душі лягає на того самого ворога не частіше ніж раз на стільки секунд
static var BOSS_TIER: int  # душі від цього ступеня стають лише в зброю й оберіг
const BOSS_SLOTS := ["weapon", "amulet"]
static var SOCKET_TROPHY: int  # трофеїв за пробите гніздо
static var REMOVE_PART: float  # вийняти душу коштує цю частку ціни гнізда


## Числа-правила вище лежать у data/settings.json (запис «souls»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("souls")
	CHANCE = S["chance"]
	CHANCE_PERIL = S["chance_peril"]
	W_MIN = S["w_min"]
	W_MIN_BOSS = S["w_min_boss"]
	PITY_MAX = S["pity_max"]
	FIRST_LEVEL = S["first_level"]
	PROC_LOCK = S["proc_lock"]
	BOSS_TIER = S["boss_tier"]
	SOCKET_TROPHY = S["socket_trophy"]
	REMOVE_PART = S["remove_part"]


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
