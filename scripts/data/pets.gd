extends RefCounted
## Улюбленці героя. Живуть на хуторі (спільні для роду), кожен герой бере з собою одного.
## Улюбленця купують за гривні й ресурси, а потім годують: кожен ступінь (до MAX_LEVEL) підсилює його хист.
## Сили в бою улюбленець не додає: він помічник у дорозі й у господарстві.
##   stat — що дає: pickup (радіус збору), travel (швидкість дороги мапою), xp (досвід), res (шанс ресурсу з нечисті);
##   base — надбавка на першому ступені, per — приріст за кожен наступний (частки);
##   gold, res — ціна першого ступеня; кожен наступний коштує стільки ж, помножене на номер ступеня.

const MAX_LEVEL := 5
const ORDER := ["pes", "kit", "voron", "kin"]
const DEFS := {
	"pes": {"name": "Пес Сірко", "stat": "pickup", "base": 0.4, "per": 0.2, "gold": 15000, "res": {"trophy": 20, "herbs": 100},
		"text": "радіус збору здобичі +%d%%", "desc": "Вірний пес бігає за героєм і зносить до нього монети, речі й ресурси здалеку."},
	"kit": {"name": "Кіт Воркіт", "stat": "xp", "base": 0.03, "per": 0.02, "gold": 20000, "res": {"trophy": 30, "herbs": 200},
		"text": "досвід +%d%%", "desc": "Кіт приносить удачу: з ним наука йде швидше."},
	"voron": {"name": "Ворон Карк", "stat": "res", "base": 0.2, "per": 0.15, "gold": 30000, "res": {"trophy": 40, "iron": 300},
		"text": "ресурси з нечисті падають на %d%% частіше", "desc": "Ворон здалеку бачить, де лежить добро, і каже про це господареві."},
	"kin": {"name": "Кінь Гнідко", "stat": "travel", "base": 0.3, "per": 0.15, "gold": 40000, "res": {"trophy": 50, "wood": 300},
		"text": "дорога мапою швидша на %d%%", "desc": "Добрий кінь скорочує дорогу. У бій героя не супроводжує: чекає на узліссі."},
}
## Хто ходить за героєм у бою (кінь лишається на узліссі).
const FOLLOWERS := ["pes", "kit", "voron"]


static func value(id: String, level: int) -> float:
	if not DEFS.has(id) or level <= 0:
		return 0.0
	return float(DEFS[id]["base"]) + float(DEFS[id]["per"]) * (mini(level, MAX_LEVEL) - 1)


static func text(id: String, level: int) -> String:
	return str(DEFS[id]["text"]) % roundi(value(id, level) * 100.0)


## Ціна ступеня level (1 — купівля): {"gold", ресурс: скільки}.
static func cost(id: String, level: int) -> Dictionary:
	var D: Dictionary = DEFS[id]
	var out := {"gold": int(D["gold"]) * level}
	for r in D["res"]:
		out[r] = int(D["res"][r]) * level
	return out
