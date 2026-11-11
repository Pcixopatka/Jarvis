extends RefCounted
## Артефакти: трофеї босів, що діють, поки просто лежать у торбі героя.
## У кожного боса свій артефакт. Другий такий самий не діє; у скрині артефакт спить.

const RARITY := 5
const SLOT := "artifact"
## Шанс трофея з господаря лігва за одну перемогу. Повторів нема: що вже лежить у торбі, удруге не падає.
const CHANCE := 0.04
const CHANCE_TOWER := 0.06  # супербос Башти
const CHANCE_GREY := 0.02  # бос, значно слабший за героя (див. Uniques.LEVEL_GAP)
const CHANCE_PERIL := 0.08  # надважкий бос у своїй печері
## Доля трофея: кожна перемога над босом без його артефакта наближає удачу саме з цим босом.
## Без цього кожен десятий гравець бив одного боса понад 59 разів, а кожен сотий понад 113 (tools/loot_probe.gd).
## Із цими числами трофей у середньому за 17 перемог (без долі було 25), кожен десятий чекає понад 36,
## найдовше 61.
const LUCK_STEP := 30.0  # за стільки перемог без трофея шанс подвоюється
const LUCK_SURE := 60  # стільки перемог поспіль без трофея, і наступна дає його напевно

const DEFS := {
	"zmiiv_zub": {"name": "Зміїв зуб", "boss": "zmii", "bonus": {"st_burn": 0.35},
		"text": "Горіння на тобі минає на 35% швидше",
		"lore": "Цей зуб уцілів у вогні, що спалив пів печери. Тепер вогонь обходить і тебе."},
	"iklo_upyria": {"name": "Ікло Упиря", "boss": "upyr", "bonus": {"st_bleed": 0.35},
		"text": "Кровотеча на тобі минає на 35% швидше",
		"lore": "Упир-володар сотню літ пив чужу кров. Його ікло замовляє твою."},
	"vovcha_lapa": {"name": "Вовча лапа", "boss": "vovkulaka", "bonus": {"travel": 0.12},
		"text": "Подорож мапою на 12% швидша",
		"lore": "Ватажок вовкулак знав кожну стежку від Карпат до Дикого Поля. Лапа їх пам'ятає."},
	"chorna_knyha": {"name": "Чорна книга", "boss": "chaklun", "bonus": {"plague": 0.25},
		"text": "Зараза шкодить тобі на 25% менше",
		"lore": "У ній записано, як чаклун варив заразу. Хто прочитав, той знає, як від неї вберегтися."},
	"vidmyn_hlechyk": {"name": "Відьмин глечик", "boss": "vidma", "bonus": {"potion_max": 1},
		"text": "+1 зілля здоров'я з собою",
		"lore": "Глечик із Лисої гори: що в нього не наллєш, усе не розхлюпається."},
	"mitla_yahy": {"name": "Мітла Баби Яги", "boss": "baba_yaha", "bonus": {"dodge_cd": 0.08},
		"text": "Перекид перезаряджається на 8% швидше",
		"lore": "Замітає сліди так, що й сама Яга тебе не наздожене."},
	"svystok_soloveia": {"name": "Свисток Солов'я", "boss": "solovei", "bonus": {"elite_dmg": 0.08},
		"text": "+8% шкоди елітам і цілям розшуку",
		"lore": "Від його посвисту в старших над нечистю підгинаються коліна."},
	"koshchieva_skrynka": {"name": "Кощієва скринька", "boss": "koshchii", "bonus": {"stone": 0.25},
		"text": "Камені долі з босів падають на 25% частіше",
		"lore": "Кощій ховав у ній найдорожче. Тепер до неї саме тягнеться все рідкісне."},
	"kliuchi_kremlia": {"name": "Ключі від Кремля", "boss": "putinoid", "bonus": {"gold": 0.08},
		"text": "+8% гривень",
		"lore": "Відмикають комори, куди Путіноїд сто років звозив награбоване."},
	"rozbyti_kaidany": {"name": "Розбиті кайдани", "boss": "oprychnyk", "bonus": {"st_chill": 0.3, "st_weak": 0.3},
		"text": "Холод і слабкість на тобі минають на 30% швидше",
		"lore": "Малюта кував у них людей. Розбиті, вони нікого вже не втримають."},
	"kreidiane_kolo": {"name": "Крейдяне коло", "boss": "vii", "bonus": {"status": 0.15},
		"text": "Усі стани на тобі минають на 15% швидше",
		"lore": "Шматок тієї крейди, якою Хома обвів себе в церкві. Нечисте слово через коло не переступає."},
	"persten_biloi_pani": {"name": "Перстень Білої Пані", "boss": "bila_pani", "bonus": {"glory": 0.08},
		"text": "+8% слави",
		"lore": "Перстень із Підгорецького замку. Про того, хто його носить, говорять у кожному шинку."},
	"lampa_shubina": {"name": "Лампа Шубіна", "boss": "shubin", "bonus": {"res": 0.15},
		"text": "+15% ресурсів із нечисті",
		"lore": "Шахтарська лампа, що світить туди, де лежить добро."},
	"oko_lykha": {"name": "Око Лиха", "boss": "lykho", "bonus": {"unique_luck": 0.15},
		"text": "Шанс золотої речі з боса більший на 15%",
		"lore": "Єдине око Лиха бачило, де чия доля лежить. Тепер воно дивиться для тебе."},
	"perlyna_tsaria": {"name": "Перлина Морського царя", "boss": "morskyi_tsar", "bonus": {"mana_potion_max": 1},
		"text": "+1 зілля наснаги з собою",
		"lore": "Усередині перлини хлюпає море. Його сила не висихає."},
	"yadro_tsar_harmaty": {"name": "Ядро Цар-гармати", "boss": "pushkar", "bonus": {"boss_dmg": 0.06},
		"text": "+6% шкоди босам",
		"lore": "Єдине ядро, що таки вилетіло з Цар-гармати. Велике цабе боїться його й досі."},
	"lisovykova_sopilka": {"name": "Сопілка Лісового Діда", "boss": "lisovyi_did", "bonus": {"pickup": 0.3},
		"text": "Здобич збирається з на 30% більшої відстані",
		"lore": "Заграєш, і все загублене в лісі само котиться до ніг."},
	"kivsh_idolyshcha": {"name": "Ківш Ідолища", "boss": "idolyshche", "bonus": {"trophy": 1},
		"text": "+1 трофей із кожного боса й елітного",
		"lore": "Ківш ненажери: скільки не черпай, усе мало. Трофеїв це теж стосується."},
	"zoria_karachuna": {"name": "Зоря найдовшої ночі", "boss": "karachun", "bonus": {"xp": 0.06},
		"text": "+6% досвіду",
		"lore": "Єдина зоря, що світила в Карачунову ніч. За довгу ніч багато чого навчишся."},
	"persten_drakona": {"name": "Перстень дракона", "boss": "drakula", "bonus": {"st_bleed": 0.35},
		"text": "Кровотеча на герої триває на 35% менше",
		"lore": "Перстень ордену Дракона, який упир зняв із чужої руки разом з іменем. Справжній власник крові не боявся."},
	"lanka_lantsiuha": {"name": "Ланка велетового ланцюга", "boss": "dev", "bonus": {"death_xp": 0.5},
		"text": "Смерть забирає вдвічі менше досвіду",
		"lore": "Ланцюг, яким велета прикували до кавказької скелі. Хто носить ланку, того й смерть тримає не так міцно."},
	"hromovyi_kamin": {"name": "Громовий камінь", "boss": "khala", "bonus": {"enrage": 30},
		"text": "Надважкий бос починає лютішати на 30 с пізніше",
		"lore": "Камінь, що впав із грозової хмари разом із Халою. Поки він у торбі, буря не поспішає."},
	"velniasova_torba": {"name": "Велнясова торба", "boss": "velnias", "bonus": {"soul": 0.25},
		"text": "Душі з нечисті падають на 25% частіше",
		"lore": "У цю торбу господар мертвих складав душі тих, хто програв йому заклад. Вона й досі їх притягує."},
	"zolota_lychyna": {"name": "Золота личина", "boss": "zolota_baba", "bonus": {"set_luck": 0.25},
		"text": "Речі наборів падають на 25% частіше",
		"lore": "Личина ідола з Кам'яного Поясу. Що їй колись жертвували, те вона тепер повертає."},
	"ulamok_chornoho_sontsia": {"name": "Уламок чорного сонця", "boss": "chornoboh", "bonus": {"dmg": 0.05},
		"text": "+5% шкоди по всій нечисті",
		"lore": "Чорнобог збирався загасити ним білий світ. У твоїй торбі він гасить лише нечисть."},
}

const ORDER := ["zmiiv_zub", "iklo_upyria", "vovcha_lapa", "chorna_knyha", "vidmyn_hlechyk", "mitla_yahy", "svystok_soloveia", "koshchieva_skrynka", "kliuchi_kremlia", "rozbyti_kaidany", "kreidiane_kolo", "persten_biloi_pani", "lampa_shubina", "oko_lykha", "perlyna_tsaria", "yadro_tsar_harmaty", "lisovykova_sopilka", "kivsh_idolyshcha", "zoria_karachuna",
	"persten_drakona", "lanka_lantsiuha", "hromovyi_kamin", "velniasova_torba", "zolota_lychyna", "ulamok_chornoho_sontsia"]


static func is_artifact(item: Dictionary) -> bool:
	return item.has("artifact") and DEFS.has(str(item["artifact"]))


static func make(id: String) -> Dictionary:
	return {"slot": SLOT, "type": "", "name": DEFS[id]["name"], "rarity": RARITY, "ilvl": 1, "up": 0, "spent": 0,
		"artifact": id, "base": {}, "affixes": {}}


## Артефакт цього боса ("" — у боса свого трофея нема).
static func by_boss(kind: String) -> String:
	for id in ORDER:
		if DEFS[id]["boss"] == kind:
			return id
	return ""


## Які артефакти діють: кожен вид один раз.
static func active_ids(inventory: Array) -> Array:
	var out := []
	for it in inventory:
		if is_artifact(it) and not str(it["artifact"]) in out:
			out.append(str(it["artifact"]))
	return out


## Сума бонусів усіх різних артефактів у торбі: {ключ: значення}.
static func mods(inventory: Array) -> Dictionary:
	var out := {}
	for id in active_ids(inventory):
		var b: Dictionary = DEFS[id]["bonus"]
		for k in b:
			out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out


static func has(inventory: Array, id: String) -> bool:
	return id in active_ids(inventory)
