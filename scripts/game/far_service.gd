extends RefCounted
## Далекі краї: Сіверщина, Волинь і Поділля, Слобожанщина й Донеччина, Чорномор'я і Крим.
## Їхні місцевості мають позначку "scale": рівень не нижчий за вказаний у даних і росте разом із героєм,
## а нечисть міряється з ним силою (як на варті й у герці). Тому сюди є чого ходити і на 20-му рівні,
## і на 90-му: здобич, досвід і завдання завжди під стать герою.
## Героєві, слабшому за позначений рівень, край не піддається: там звичайна нечисть цього рівня.

const Data := preload("res://scripts/data/data.gd")
const Power := preload("res://scripts/game/power.gd")

## Скільки секунд чистої шкоди героя тримає «звичайний заражений» і яку частку здоров'я героя забирає його удар.
## Решта нечисті й боси — у своїй пропорції до нього (кам'яна баба втричі міцніша, злидень утричі кволіший).
const TTK := 1.1
const HIT := 0.035
const DUNGEON_TTK := 1.2
const DUNGEON_HIT := 0.032
# Підлога сили нечисті в Глибинах і Башті для героя, що їх переріс (кімнат і хвиль там більше, тож трохи м'якше за печеру краю)
const DEPTH_FLOOR_TTK := 1.0
const DEPTH_FLOOR_HIT := 0.028
const TOWER_FLOOR_TTK := 0.9
const TOWER_FLOOR_HIT := 0.028
# Події (облоги, набіги, валки, полон, супровід, розшук, сторож скарбу, лігво на стежці, ніч): нечисть не слабша
# проти героя за цю мірку. Трохи м'якше за далекий край, бо там ще хвилі й те, що треба вберегти.
const EVENT_TTK := 0.9
const EVENT_HIT := 0.028
const NIGHT_MULT := 1.3  # уночі мірка лютіша
# Новачкам події лишаються як були: мірка вмикається плавно, від EVENT_FROM-го рівня героя до повної сили на EVENT_FULL-му.
const EVENT_FROM := 10
const EVENT_FULL := 30
const GOAL_MAX := 110  # більше стількох на зачистку не просимо, хоч який рівень
## Нечисть тут легша за глибинну, тож бувалому героєві даємо надбавку до досвіду й гривень:
## +6% за кожен рівень понад рівень краю, але не більше ніж учетверо з половиною.
## На 66-му рівні це близько половини того, що дають Глибини (див. tools/far_sim.gd і depth_sim.gd).
const XP_PER_LEVEL := 0.06
const XP_MAX := 4.5


## Надбавка до досвіду й гривень для героя рівня hero у краї рівня base.
static func xp_mult(base: int, hero: int) -> float:
	return minf(XP_MAX, 1.0 + XP_PER_LEVEL * maxi(0, hero - base))


static func is_far(L: Dictionary) -> bool:
	return bool(L.get("scale", false))


## Чи герой уже доріс до цього краю (тоді нечисть міряється з ним).
static func matched(L: Dictionary, player) -> bool:
	return is_far(L) and player.level >= int(L["level"])


## Додатки до опису місцевості для бою (змішуються з Data.LOCATIONS[id] у combat.enter).
static func mods(L: Dictionary, player) -> Dictionary:
	if not is_far(L):
		return {}
	var base := int(L["level"])
	var out := {"base_level": base}
	if L["type"] != "dungeon":
		out["goal"] = mini(GOAL_MAX, Data.FIELD_GOAL_BASE + base * Data.FIELD_GOAL_PER_LEVEL)
	if player.level >= base:
		var dungeon: bool = L["type"] == "dungeon"
		out["level"] = player.level
		out["hero_level"] = player.level
		out["std_hp"] = Power.dps(player) * (DUNGEON_TTK if dungeon else TTK)
		out["std_dmg"] = Power.hit(player, DUNGEON_HIT if dungeon else HIT)
		out["xp_mult"] = xp_mult(base, player.level)
	return out


## Найменша сила нечисті в Глибинах і Башті: не слабша проти героя, ніж у печері далекого краю.
## Формули глибини й поверху діють далі; це лише підлога для героя, що їх переріс.
static func floor_mods(player, ttk: float, hit_frac: float) -> Dictionary:
	return {"min_std_hp": Power.dps(player) * ttk, "min_std_dmg": Power.hit(player, hit_frac)}


## Яка частка мірки подій діє на героя цього рівня: 0 до EVENT_FROM, 1 від EVENT_FULL.
static func event_share(level: int) -> float:
	return clampf(float(level - EVENT_FROM) / float(EVENT_FULL - EVENT_FROM), 0.0, 1.0)


## Підлога сили нечисті для бою події: звичайна нечисть свого рівня лишається, якщо вона й так сильніша.
static func event_mods(player, mult: float = 1.0) -> Dictionary:
	var share := event_share(int(player.level)) * mult
	return floor_mods(player, EVENT_TTK * share, EVENT_HIT * share)


## У скільки разів удар підтягнутої нечисті сильніший за звичайний для її рівня (не менше 1).
## На стільки ж міцнішає те, що герой боронить: брама, вози, мандрівник. Інакше воно падало б за кілька ударів.
static func guard_mult(level: int, mods: Dictionary) -> float:
	return maxf(1.0, float(mods.get("min_std_dmg", 0.0)) / (13.0 * (1.0 + Data.ENEMY_DMG_PER_LEVEL * (level - 1))))


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
	if Data.LOCATIONS.has(id):
		return str(Data.LOCATIONS[id].get("region", ""))
	if Data.CITIES.has(id):
		return str(Data.CITIES[id].get("region", ""))
	return ""


## Усі місця краю: {"cities": [...], "fields": [...], "dungeons": [...]}.
static func places(region: String) -> Dictionary:
	var out := {"cities": [], "fields": [], "dungeons": []}
	for id in Data.CITIES:
		if Data.CITIES[id].get("region", "") == region:
			out["cities"].append(id)
	for id in Data.LOCATIONS:
		if Data.LOCATIONS[id].get("region", "") == region:
			out["dungeons" if Data.LOCATIONS[id]["type"] == "dungeon" else "fields"].append(id)
	return out


## З якого рівня героя край відкривається: найнижчий рівень його місць.
static func open_level(region: String) -> int:
	var lvl := 999
	var p := places(region)
	for id in p["fields"] + p["dungeons"]:
		lvl = mini(lvl, int(Data.LOCATIONS[id]["level"]))
	return lvl
