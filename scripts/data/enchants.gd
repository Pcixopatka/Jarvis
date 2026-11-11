extends RefCounted
## Зачарування речей. На кожній легендарній, золотій чи наборній речі може лежати одне зачарування:
## особлива властивість, якої не буває серед звичайних. Накладає коваль на хуторі за трофеї й ресурси;
## нове зачарування замінює старе. На речах 100-го рівня й вище (здобич надважких печер) воно сильніше.
##   slots — на що лягає; fx — ключ і сила (ті самі ключі, що в пасивних умінь: Classes.FX_TEXT).

const MIN_RARITY := 3  # зачаровують лише легендарне й краще
const STRONG_LEVEL := 100  # з цього рівня речі зачарування сильніше
const STRONG_MULT := 1.5
const ARMOR := ["head", "body", "belt", "boots"]
const ORDER := ["zviroboi", "dobyvach", "naskok", "kat", "krovopyvtsia", "obereh", "kolyuchka", "zhyvytsia", "viter",
	"mudrist", "pospikh", "dzherelo"]
const DEFS := {
	"zviroboi": {"name": "Звіробій", "slots": ["weapon"], "fx": {"big_dmg": 6.0}},
	"dobyvach": {"name": "Добивач", "slots": ["weapon"], "fx": {"execute": 10.0}},
	"naskok": {"name": "Наскок", "slots": ["weapon"], "fx": {"opener": 10.0}},
	"kat": {"name": "Кат", "slots": ["weapon"], "fx": {"status_dmg": 6.0}},
	"krovopyvtsia": {"name": "Кровопивця", "slots": ["weapon"], "fx": {"lifesteal": 1.0}},
	"obereh": {"name": "Оберіг", "slots": ARMOR, "fx": {"ward": 2.0}},
	"kolyuchka": {"name": "Колючка", "slots": ARMOR, "fx": {"thorns": 8.0}},
	"zhyvytsia": {"name": "Живиця", "slots": ARMOR, "fx": {"kill_heal": 0.3}},
	"viter": {"name": "Вітер", "slots": ARMOR, "fx": {"dodge_cd": 6.0}},
	"mudrist": {"name": "Мудрість", "slots": ["amulet"], "fx": {"skill": 5.0}},
	"pospikh": {"name": "Поспіх", "slots": ["amulet"], "fx": {"cd": 4.0}},
	"dzherelo": {"name": "Джерело", "slots": ["amulet"], "fx": {"kill_mana": 2.0}},
}
## Ціна: трофеї, гривні й ресурс за рівень речі.
const TROPHY_BASE := 20
const TROPHY_PER_LEVEL := 0.4
const GOLD_PER_LEVEL := 400
const RES_PER_LEVEL := 6
const RES := {"weapon": "iron", "amulet": "herbs"}  # решта речей просить дерево


static func mult(item: Dictionary) -> float:
	return STRONG_MULT if int(item.get("ilvl", 1)) >= STRONG_LEVEL else 1.0


## Які зачарування лягають на цю річ.
static func options(item: Dictionary) -> Array:
	var out := []
	for id in ORDER:
		if str(item.get("slot", "")) in DEFS[id]["slots"]:
			out.append(id)
	return out


## Сила зачарування id на цій речі: {ключ: значення}.
static func fx_of(item: Dictionary, id: String) -> Dictionary:
	var out := {}
	if not DEFS.has(id):
		return out
	for k in DEFS[id]["fx"]:
		out[k] = float(DEFS[id]["fx"][k]) * mult(item)
	return out


static func cost(item: Dictionary) -> Dictionary:
	var lvl: int = int(item.get("ilvl", 1))
	var res: String = str(RES.get(str(item.get("slot", "")), "wood"))
	return {"gold": GOLD_PER_LEVEL * lvl, "trophy": TROPHY_BASE + int(TROPHY_PER_LEVEL * lvl), res: RES_PER_LEVEL * lvl}
