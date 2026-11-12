extends RefCounted
## Картки доріг для екрана «Дорога» (вибір класу після майстерності 10) і для спеціалізацій
## у вкладці наставників. Представники розповідають про свою дорогу; обрати можна лише
## після розмов з усіма трьома.
##
## Картки лежать у data/paths.json (ключ — id класу; docs/data.md, «Класи й уміння»). Картка вибору
## дороги має ще й «rep» (представник на Січі: осавул Мирон — про козаків, посланниця волхвів
## Зореслава — про волхвів, сотник сердюків Лесь — про стрільців) і «talk» (його розповідь);
## порядок цих карток у файлі — порядок на екрані вибору.

const GameDB := preload("res://scripts/core/game_db.gd")
const _EMPTY_LIST := []

static var _order: Array = []


## Картки вибору дороги (з представником), у порядку екрана.
static func order() -> Array:
	if _order.is_empty():
		for id in GameDB.ids("paths"):
			if GameDB.row("paths", id).has("rep"):
				_order.append(id)
		_order.make_read_only()
	return _order


## Усі картки (вибір дороги й спеціалізації) у порядку файлу.
static func ids() -> Array:
	return GameDB.ids("paths")


static func has_card(cls: String) -> bool:
	return GameDB.table("paths").has(cls)


## Картка класу: title, where, style, strong, weak, skills, next, for; для невідомого — порожня.
static func card(cls: String) -> Dictionary:
	return GameDB.row("paths", cls)


## Хто розповідає про дорогу ("" — картка не з вибору дороги).
static func rep(cls: String) -> String:
	return str(card(cls).get("rep", ""))


## Розповідь представника: [[мовець, текст], ...].
static func talk(cls: String) -> Array:
	return card(cls).get("talk", _EMPTY_LIST)
