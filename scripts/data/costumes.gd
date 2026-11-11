extends RefCounted
## Вбрання героя: лише вигляд, сили не додає. Купується в крамниці за червінці раз на весь рід,
## вдягає його кожен герой окремо (Player.costume). Вбрання міняє постать цілком, однаково для
## будь-якого класу; зброя в руці лишається та, що вдягнена.
## Листи малює tools/pixel/sprites.py (COSTUMES, ті самі id): costume_<id>_<зброя> і plain_costume_<id>.

const ORDER := ["chumak", "hutsul", "sotnyk", "chernets", "hetman", "zoloto"]
const DEFS := {
	"chumak": {"name": "Чумацька свита", "price": 150, "desc": "Бриль, біла сорочка й темні шаровари: як у чумака на Муравському шляху."},
	"hutsul": {"name": "Гуцульський стрій", "price": 200, "desc": "Крисаня, вишита сорочка й червоні гачі з Верховини."},
	"sotnyk": {"name": "Сотницький кунтуш", "price": 200, "desc": "Синій кунтуш зі срібним поясом і смушкова шапка."},
	"chernets": {"name": "Чернеча ряса", "price": 250, "desc": "Чорна ряса з каптуром: вигляд ченця-самітника з печер."},
	"hetman": {"name": "Гетьманський жупан", "price": 350, "desc": "Малиновий жупан із золотим поясом і шапка з червоним шликом."},
	"zoloto": {"name": "Золоті шати", "price": 600, "desc": "Парчевий жупан, що сяє золотом. Його видно здалеку."},
}
## Для якої зброї є лист кожного вбрання.
const WEAPONS := ["sabre", "mace", "pike", "staff", "pishchal", "bow", "pistols"]


static func has(id: String) -> bool:
	return DEFS.has(id)


static func name_of(id: String) -> String:
	return str(DEFS[id]["name"]) if DEFS.has(id) else "Свій одяг"


## Лист вбрання для зброї в руці ("" — такого листа нема).
static func sprite(id: String, weapon_type: String) -> String:
	if not DEFS.has(id):
		return ""
	return "costume_%s_%s" % [id, weapon_type if weapon_type in WEAPONS else "sabre"]


## Лист без зброї: для рибалки й мирних занять.
static func plain(id: String) -> String:
	return "plain_costume_" + id if DEFS.has(id) else ""
