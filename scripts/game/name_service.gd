extends RefCounted
## Ім'я героя (нік). Належить героєві, а не роду; унікальності не вимагаємо.
## Правила: 3–16 знаків; українські й латинські літери, цифри, пробіл, дефіс, апостроф (' і ’);
## пробіли по краях зрізаються, кілька поспіль стискаються в один; хоч одна літера обов'язкова.
## Лайку й імена служби гри шукаємо в нормалізованому рядку: обхідні написання (латинка замість
## кирилиці, цифри замість літер, повтори, пробіли й дефіси всередині) не допомагають.
## Без стану: слова — у data/name_pools.json (NamesData.words).

const Names := preload("res://scripts/data/names_data.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")

const MIN_LEN := 3
const MAX_LEN := 16
const UA_LETTERS := "абвгґдеєжзиіїйклмнопрстуфхцчшщьюяАБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"
const LAT_LETTERS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS := "0123456789"
const MARKS := " -'’"

const BAD_TEXT := "Таке ім'я не годиться, вибери інше"

## Латинські літери й цифри, схожі на кириличні (після нижнього регістру).
const TO_CYR := {
	"a": "а", "b": "б", "c": "с", "d": "д", "e": "е", "f": "ф", "g": "г", "h": "н", "i": "и", "j": "й",
	"k": "к", "l": "л", "m": "м", "n": "п", "o": "о", "p": "р", "r": "г", "s": "с", "t": "т", "u": "у",
	"v": "в", "w": "ш", "x": "х", "y": "у", "z": "з",
	"0": "о", "1": "и", "3": "з", "4": "ч", "6": "б", "8": "в",
	"і": "и", "ї": "и", "є": "е", "ґ": "г", "ь": "",
}

## Кирилиця латинкою (як її пишуть в обхід) і цифри, схожі на латинські літери.
const TO_LAT := {
	"а": "a", "б": "b", "в": "v", "г": "g", "ґ": "g", "д": "d", "е": "e", "є": "ye", "ж": "zh", "з": "z",
	"и": "y", "і": "i", "ї": "yi", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p",
	"р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "h", "ц": "ts", "ч": "ch", "ш": "sh", "щ": "shch",
	"ь": "", "ю": "yu", "я": "ya",
	"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t",
}


## Очистити ввід: «ʼ» з української розкладки стає «’», пробіли по краях зрізаються, кілька поспіль
## стискаються в один. Не рядок (зіпсоване збереження) дає порожній.
static func clean(text) -> String:
	if typeof(text) != TYPE_STRING and typeof(text) != TYPE_STRING_NAME:
		return ""
	var t := str(text).replace("ʼ", "’")
	var rx := RegEx.create_from_string("\\s+")
	return rx.sub(t, " ", true).strip_edges()


## Чи годиться ім'я. Порожній рядок: так; інакше коротка причина для гравця.
static func check(text) -> String:
	var n := clean(text)
	if n.length() < MIN_LEN:
		return "Закоротке: треба від %d знаків" % MIN_LEN
	if n.length() > MAX_LEN:
		return "Задовге: щонайбільше %d знаків" % MAX_LEN
	var letters := 0
	for ch in n:
		if UA_LETTERS.contains(ch) or LAT_LETTERS.contains(ch):
			letters += 1
		elif not (DIGITS.contains(ch) or MARKS.contains(ch)):
			return "Такі знаки в імені не можна: %s" % ch
	if letters == 0:
		return "Ім'я має мати хоч одну літеру"
	if is_reserved(n):
		return "Це ім'я для служби гри, вибери інше"
	if is_rude(n):
		return BAD_TEXT
	return ""


static func is_valid(text) -> bool:
	return check(text) == ""


## Ім'я зі збереження чи коду роду: очищене, якщо годиться, інакше порожнє.
static func from_save(v) -> String:
	var n := clean(v)
	return n if check(n) == "" else ""


# ---------- Нормалізація ----------

## Повтори однієї літери стискаються: «хууууй» → «хуй».
static func squeeze(s: String) -> String:
	var out := ""
	for ch in s:
		if out == "" or out[out.length() - 1] != ch:
			out += ch
	return out


## Кирилична кістка імені: нижній регістр, без пробілів, дефісів і апострофів, схожа латинка й цифри
## зведені до кирилиці, і/ї → и, є → е, без ь, повтори стиснуті.
static func skeleton_cyr(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if MARKS.contains(ch):
			continue
		out += TO_CYR.get(ch, ch)
	return squeeze(out)


## Латинська кістка: кирилиця латинкою, цифри як схожі латинські літери, без розділових, повтори стиснуті.
static func skeleton_lat(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		if MARKS.contains(ch):
			continue
		out += TO_LAT.get(ch, ch)
	return squeeze(out)


static func _has_root(s: String, roots: Array) -> bool:
	for r in roots:
		if s.contains(squeeze(r)):
			return true
	return false


static func is_rude(text: String) -> bool:
	var cyr := skeleton_cyr(text)
	var lat := skeleton_lat(text)
	var whole := Names.words("bad_whole")
	if cyr in whole or lat in whole:
		return true
	return _has_root(cyr, Names.words("bad_cyr")) or _has_root(lat, Names.words("bad_lat"))


## Ім'я служби гри: ціле ім'я чи його початок («Адмін», «Admin_Taras», «Модератор Петро»).
static func is_reserved(text: String) -> bool:
	var lat := skeleton_lat(clean(text))
	for r in Names.words("reserved"):
		if lat.begins_with(squeeze(r)):
			return true
	# коротке («GM») лише окремим словом на початку: «GM Тарас», «GM1», але не «Гмиря»
	var first := ""
	for ch in clean(text).to_lower():
		if not (UA_LETTERS.contains(ch) or LAT_LETTERS.contains(ch)):
			break
		first += ch
	return skeleton_lat(first) in Names.words("reserved_word")


# ---------- Жереб ----------

## Козацьке прізвисько: готове або складене з наказового дієслова й іменника (Вернидуб, Крутивус).
## rng: свій генератор для відтворюваних тестів; без нього береться загальний випадок.
static func roll(rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	for _try in 20:
		var n: String
		if rng.randf() < 0.25:
			var ready := Names.words("ready")
			n = ready[rng.randi_range(0, ready.size() - 1)]
		else:
			var verbs := Names.words("verbs")
			var nouns := Names.words("nouns")
			n = verbs[rng.randi_range(0, verbs.size() - 1)] + nouns[rng.randi_range(0, nouns.size() - 1)]
		if check(n) == "":
			return n
	return Names.words("ready")[0]


# ---------- Збереження ----------

## Перейменувати героя просто у файлі збереження (герой може бути й не тим, яким зараз грають).
## Решта збереження не міняється. false: ім'я не годиться або файл не читається чи не записався.
static func rename_file(path: String, nick: String) -> bool:
	var n := clean(nick)
	if check(n) != "":
		return false
	var d := SaveSystem.load_data(path)
	if d.is_empty():
		return false
	d["player"]["nick"] = n
	return SaveSystem.save(d, path)
