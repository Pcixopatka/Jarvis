extends RefCounted
## Далекі краї: Сіверщина, Волинь і Поділля, Слобожанщина й Донеччина, Чорномор'я і Крим.
## Їхні місцевості мають позначку "scale": рівень не нижчий за вказаний у даних і росте разом із героєм.
## Сила нечисті — звичайна мірка її рівня (Data.enemy_std_*), досвід і здобич теж за рівнем. Тому сюди є чого
## ходити і на 20-му рівні, і на 90-му, а краще спорядження тут справді відчувається.
## Героєві, слабшому за позначений рівень, край не піддається: там звичайна нечисть цього рівня.

const GameDB := preload("res://scripts/core/game_db.gd")

const Data := preload("res://scripts/data/data.gd")

## Підлога сили нечисті: частка звичайної мірки для рівня героя (Data.enemy_std_hp і enemy_std_dmg).
## Потрібна там, де місце слабше за героя: він переріс Глибину чи поверх Башти, шукає розшукувану нечисть
## у полі для новачків, зайшов уночі в давню печеру. Нечисть свого рівня й так не слабша за мірку.
## У Глибинах і Башті підлога помітно нижча за повну мірку: мілкіша глибина чи нижчий поверх мають бути
## легшим кроком для героя, якому свій рівень ще не під силу, але не прогулянкою.
static var DEPTH_FLOOR: float  # Глибини: нечисть не слабша за цю частку звичайної мірки для рівня героя
static var TOWER_FLOOR: float  # Башта: те саме
# Події: облоги, набіги, валки, полон, супровід, розшук, сторож скарбу, лігво на стежці, ніч.
static var EVENT_FLOOR: float  # події (облоги, набіги, валки, полон, супровід, розшук, сторож скарбу, лігво, ніч): те саме
static var NIGHT_MULT: float  # уночі мірка подій у стільки разів лютіша
# Новачкам події лишаються як були: мірка вмикається плавно, від EVENT_FROM-го рівня героя до повної сили на EVENT_FULL-му.
static var EVENT_FROM: int  # мірка подій вмикається плавно з цього рівня героя…
static var EVENT_FULL: int  # …до повної сили на цьому
static var GOAL_MAX: int  # більше стількох нечисті на зачистку не просимо, хоч який рівень


static func is_far(L: Dictionary) -> bool:
	return bool(L.get("scale", false))


## Чи герой уже доріс до цього краю (тоді нечисть там його рівня).
static func matched(L: Dictionary, player) -> bool:
	return is_far(L) and player.level >= int(L["level"])


## Додатки до опису місцевості для бою (змішуються з Data.place(id) у combat.enter).
## Нечисть далекого краю має рівень героя. Її сила — звичайна мірка цього рівня (Data.enemy_std_*),
## тож краще вдягненому героєві тут легше, а гірше вдягненому важче.
static func mods(L: Dictionary, player) -> Dictionary:
	if not is_far(L):
		return {}
	var base := int(L["level"])
	var out := {"base_level": base}
	if L["type"] != "dungeon":
		out["goal"] = mini(GOAL_MAX, Data.FIELD_GOAL_BASE + base * Data.FIELD_GOAL_PER_LEVEL)
	if player.level >= base:
		out["level"] = player.level
		out["hero_level"] = player.level
	return out


## Найменша сила нечисті в Глибинах, Башті й подіях: частка share звичайної мірки для рівня героя.
## Формули глибини й поверху діють далі; це лише підлога.
static func floor_mods(player, share: float) -> Dictionary:
	return {"min_std_hp": Data.enemy_std_hp(int(player.level)) * share,
		"min_std_dmg": Data.enemy_std_dmg(int(player.level)) * share}


## Яка частка мірки подій діє на героя цього рівня: 0 до EVENT_FROM, 1 від EVENT_FULL.
static func event_share(level: int) -> float:
	return clampf(float(level - EVENT_FROM) / float(EVENT_FULL - EVENT_FROM), 0.0, 1.0)


## Підлога сили нечисті для бою події: звичайна нечисть свого рівня лишається, якщо вона й так сильніша.
static func event_mods(player, mult: float = 1.0) -> Dictionary:
	return floor_mods(player, EVENT_FLOOR * event_share(int(player.level)) * mult)


## У скільки разів міцніші брама, хати, вози й мандрівник на рівні level. Формули їхнього здоров'я зроблені
## під стару лінійну шкоду нечисті, тож міцність росте разом з ударом нечисті, і ще на GUARD_EXTRA понад те:
## нечисть тепер живе довше й устигає вдарити більше разів. Новачкам (удар не сильніший за старий) без змін.
static var GUARD_EXTRA: float  # брама, хати, вози й мандрівник міцніші ще у стільки разів понад ріст удару нечисті


## Числа-правила вище лежать у data/settings.json (запис «far»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("far")
	DEPTH_FLOOR = S["depth_floor"]
	TOWER_FLOOR = S["tower_floor"]
	EVENT_FLOOR = S["event_floor"]
	NIGHT_MULT = S["night_mult"]
	EVENT_FROM = S["event_from"]
	EVENT_FULL = S["event_full"]
	GOAL_MAX = S["goal_max"]
	GUARD_EXTRA = S["guard_extra"]


static func guard_mult(level: int, _mods: Dictionary = {}) -> float:
	var harder: float = Data.enemy_std_dmg(level) / (Data.STD_DMG * (1.0 + Data.OLD_DMG_PER_LEVEL * (level - 1)))
	return 1.0 + maxf(0.0, harder - 1.0) * GUARD_EXTRA


## Нічний похід: нечисть лютіша за мірку події, а в полі її рівень підтягується до героя
## (разом із досвідом і здобиччю). Обсяг зачистки лишається за рівнем самого місця.
static func night_mods(L: Dictionary, player) -> Dictionary:
	var out := event_mods(player, NIGHT_MULT)
	var base := int(L["level"])
	if L["type"] != "dungeon" and player.level > base:
		out["base_level"] = base
		out["level"] = player.level
		if not L.has("goal"):
			out["goal"] = mini(GOAL_MAX, Data.FIELD_GOAL_BASE + base * Data.FIELD_GOAL_PER_LEVEL)
	return out


## Край за місцем (місто чи місцевість) або "".
static func region_of(id: String) -> String:
	if Data.is_place(id):
		return str(Data.place(id).get("region", ""))
	if Data.is_city(id):
		return str(Data.city(id).get("region", ""))
	return ""


## Усі місця краю: {"cities": [...], "fields": [...], "dungeons": [...]}.
static func places(region: String) -> Dictionary:
	var out := {"cities": [], "fields": [], "dungeons": []}
	for id in Data.city_ids():
		if Data.city(id).get("region", "") == region:
			out["cities"].append(id)
	for id in Data.place_ids():
		if Data.place(id).get("region", "") == region:
			out["dungeons" if Data.place(id)["type"] == "dungeon" else "fields"].append(id)
	return out


## З якого рівня героя край відкривається: найнижчий рівень його місць.
static func open_level(region: String) -> int:
	var lvl := 999
	var p := places(region)
	for id in p["fields"] + p["dungeons"]:
		lvl = mini(lvl, int(Data.place(id)["level"]))
	return lvl
