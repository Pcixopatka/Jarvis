extends RefCounted
## Звитяги: поступ героя після стелі рівня. Досвід на останньому рівні не пропадає, а наповнює смугу
## звитяги; заповнена смуга дає очко. Очки вкладають у п'ять ліній малих вічних бонусів.
## Смерть на останньому рівні забирає частку смуги (див. Player.death_xp_loss), тож ціна смерті лишається.
## Іменні звитяги — звання за першу перемогу над надважким босом із власним бонусом («title» і «title_fx» землі в data/lands.json, див. Peril.boss_title).

const Data := preload("res://scripts/data/data.gd")
const Classes := preload("res://scripts/data/classes.gd")
const GameDB := preload("res://scripts/core/game_db.gd")

const BAR_PART := 0.1  # перша смуга: ця частка досвіду останнього рівня героя
const BAR_STEP := 0.02  # кожна наступна смуга дорожча на стільки від першої
const LINE_MAX := 30  # найбільше очок в одну лінію

## Лінії звитяги (назва, текст бонусу й скільки відсотків дає одне очко) і бонуси, що бувають лише в
## іменних звитяг («named»), лежать у data/valor_lines.json (docs/data.md, «Класи й уміння»).
static var _order: Array = []


## Лінії, у які вкладають очки, у порядку файлу (так їх показує екран героя й довідник).
static func order() -> Array:
	if _order.is_empty():
		for id in GameDB.ids("valor_lines"):
			if not GameDB.row("valor_lines", id).get("named", false):
				_order.append(id)
		_order.make_read_only()
	return _order


## Запис лінії чи бонусу іменної звитяги; для невідомого — порожній.
static func line(id: String) -> Dictionary:
	return GameDB.row("valor_lines", id)


## Чи це лінія, у яку можна вкласти очко.
static func is_line(id: String) -> bool:
	return GameDB.table("valor_lines").has(id) and not line(id).get("named", false)


## Усі ключі звитяг (лінії й бонуси іменних звитяг).
static func keys() -> Array:
	return GameDB.ids("valor_lines")


## Найбільша звитяга героя: усі лінії заповнені до краю. Далі смуга лише стоїть повна, очок не дає.
static func max_valor() -> int:
	return order().size() * LINE_MAX


## Скільки досвіду вміщає смуга, коли вже заповнено filled смуг.
static func bar(filled: int) -> int:
	return int(Data.xp_for_level(Classes.BASE_LEVEL_MAX - 1) * BAR_PART * (1.0 + BAR_STEP * maxi(0, filled)))


static func spent_total(spent: Dictionary) -> int:
	var n := 0
	for k in spent:
		n += int(spent[k])
	return n


## Сума бонусів: вкладені очки плюс іменні звитяги. {ключ: відсотки}.
static func fx(spent: Dictionary, named: Dictionary) -> Dictionary:
	var out := {}
	for k in spent:
		if is_line(k) and int(spent[k]) > 0:
			out[k] = float(line(k)["per"]) * int(spent[k])
	for k in named:
		out[k] = float(out.get(k, 0.0)) + float(named[k])
	return out


## Число без зайвого нуля: 3.0 → «3», 1.5 → «1,5».
static func num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


## Бонус словами: «+3% шкоди».
static func text(key: String, value: float) -> String:
	return str(line(key).get("text", "%s")) % num(value)


## Бонуси іменної звитяги словами.
static func fx_text(named: Dictionary) -> String:
	var parts := []
	for k in named:
		parts.append(text(k, float(named[k])))
	return ", ".join(parts)
