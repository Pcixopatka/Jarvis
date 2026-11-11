extends RefCounted
## Звитяги: поступ героя після стелі рівня. Досвід на останньому рівні не пропадає, а наповнює смугу
## звитяги; заповнена смуга дає очко. Очки вкладають у п'ять ліній малих вічних бонусів.
## Смерть на останньому рівні забирає частку смуги (див. Player.death_xp_loss), тож ціна смерті лишається.
## Іменні звитяги — звання за першу перемогу над надважким босом із власним бонусом (Peril.TITLES, TITLE_FX).

const Data := preload("res://scripts/data/data.gd")
const Classes := preload("res://scripts/data/classes.gd")

const BAR_PART := 0.1  # перша смуга: ця частка досвіду останнього рівня героя
const BAR_STEP := 0.02  # кожна наступна смуга дорожча на стільки від першої
const LINE_MAX := 30  # найбільше очок в одну лінію

## Лінії: назва, текст бонусу й скільки відсотків дає одне очко.
const LINES := {
	"dmg": {"name": "Лють", "text": "+%s%% шкоди", "per": 1.0},
	"hp": {"name": "Гарт", "text": "+%s%% здоров'я", "per": 1.0},
	"ward": {"name": "Оберіг", "text": "шкода по тобі менша на %s%%", "per": 0.5},
	"skill": {"name": "Слово", "text": "+%s%% сили вмінь", "per": 1.0},
	"luck": {"name": "Талан", "text": "золото, артефакти, душі й речі наборів падають на %s%% частіше", "per": 1.0},
}
const ORDER := ["dmg", "hp", "ward", "skill", "luck"]
## Бонуси, які бувають лише в іменних звитяг
const EXTRA_TEXT := {"gold": "+%s%% гривень"}


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
		if LINES.has(k) and int(spent[k]) > 0:
			out[k] = float(LINES[k]["per"]) * int(spent[k])
	for k in named:
		out[k] = float(out.get(k, 0.0)) + float(named[k])
	return out


## Число без зайвого нуля: 3.0 → «3», 1.5 → «1,5».
static func num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


## Бонус словами: «+3% шкоди».
static func text(key: String, value: float) -> String:
	var t: String = str(LINES[key]["text"]) if LINES.has(key) else str(EXTRA_TEXT.get(key, "%s"))
	return t % num(value)


## Бонуси іменної звитяги словами.
static func fx_text(named: Dictionary) -> String:
	var parts := []
	for k in named:
		parts.append(text(k, float(named[k])))
	return ", ".join(parts)
