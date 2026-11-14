extends RefCounted
## Опис характеристик, дерева вмінь і дерева пасивних перків.
## Щоб додати новий вузол — достатньо дописати його сюди та реалізувати ефект у player.gd.

static var STAT_BASE: int  # початкове значення кожної характеристики героя

## Числа-правила лежать у data/settings.json (записи «enemies», «experience», «hero_combat», «battle», «loot»,
## «potions», «buffs», «death», «sharpening», «quests», «party»; docs/data.md, «Налаштування балансу»). Нижче — їхні
## робочі копії (static var): читати їх так само дешево, як сталі. Заповнює їх apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S_enemies := GameDB.settings("enemies")
	REF_DPS_BASE = S_enemies["ref_dps"]["base"]
	REF_DPS_K = S_enemies["ref_dps"]["k"]
	REF_DPS_POW = S_enemies["ref_dps"]["pow"]
	REF_EHP_BASE = S_enemies["ref_ehp"]["base"]
	REF_EHP_Q = S_enemies["ref_ehp"]["q"]
	REF_EHP_KNEE = S_enemies["ref_ehp"]["knee"]
	REF_EHP_LIN = S_enemies["ref_ehp"]["lin"]
	var curve := []
	for P in S_enemies["enemy_curve"]:
		curve.append([P["level"], P["ttk"], P["hit"]])
	GameDB._freeze(curve)
	ENEMY_CURVE = curve
	STD_HP = S_enemies["std_hp"]
	STD_DMG = S_enemies["std_dmg"]
	OLD_DMG_PER_LEVEL = S_enemies["old_dmg_per_level"]
	ENDLESS_SOFT = S_enemies["endless_soft"]
	ENDLESS_HP_PER_LEVEL = S_enemies["endless_hp_per_level"]
	ENDLESS_DMG_PER_LEVEL = S_enemies["endless_dmg_per_level"]
	ENEMY_XP_PER_LEVEL = S_enemies["enemy_xp_per_level"]
	BOSS_HP_MULT = S_enemies["boss_hp_mult"]
	BOSS_XP_MULT = S_enemies["boss_xp_mult"]
	BOSS_DMG_MULT = S_enemies["boss_dmg_mult"]
	var S_experience := GameDB.settings("experience")
	XP_BASE = S_experience["xp"]["base"]
	XP_PER_LEVEL = S_experience["xp"]["per_level"]
	XP_PER_LEVEL_SQ = S_experience["xp"]["per_level_sq"]
	XP_STEEP_FROM = S_experience["xp"]["steep_from"]
	XP_STEEP_K = S_experience["xp"]["steep_k"]
	XP_STEEP_POW = S_experience["xp"]["steep_pow"]
	XP_LATE_FROM = S_experience["xp"]["late_from"]
	XP_LATE_STEP = S_experience["xp"]["late_step"]
	STAT_BASE = S_experience["stat_base"]
	STAT_POINTS_PER_LEVEL = S_experience["stat_points_per_level"]
	SKILL_POINTS_PER_LEVEL = S_experience["skill_points_per_level"]
	PERK_POINTS_PER_LEVEL = S_experience["perk_points_per_level"]
	PERK_TIER_STEP = S_experience["perk_tier_step"]
	MISSION_XP = S_experience["mission_xp"]
	BOSS_MISSION_XP = S_experience["boss_mission_xp"]
	CITY_QUEST_XP = S_experience["city_quest_xp"]
	var S_hero_combat := GameDB.settings("hero_combat")
	ARMOR_CAP = S_hero_combat["armor_cap"]
	LIFESTEAL_MAX_HPS = S_hero_combat["lifesteal_max_hps"]
	MANA_ON_HIT = S_hero_combat["mana_on_hit"]
	MANA_ON_HIT_CD = S_hero_combat["mana_on_hit_cd"]
	MANA_ON_SHOT = S_hero_combat["mana_on_shot"]
	SPI_SOFT = S_hero_combat["spi_soft"]
	SPI_LATE = S_hero_combat["spi_late"]
	AGI_ASPD_SOFT = S_hero_combat["agi_aspd_soft"]
	AGI_ASPD_LATE = S_hero_combat["agi_aspd_late"]
	var S_battle := GameDB.settings("battle")
	FIELD_GOAL_BASE = S_battle["field_goal_base"]
	FIELD_GOAL_PER_LEVEL = S_battle["field_goal_per_level"]
	DUNGEON_ROOM_BASE = S_battle["dungeon_room_base"]
	DUNGEON_ROOM_PER = S_battle["dungeon_room_per"]
	FIELD_OPEN_ABOVE = S_battle["field_open_above"]
	var S_loot := GameDB.settings("loot")
	ITEM_DROP_CHANCE = S_loot["item_drop_chance"]
	COIN_GOLD_RATIO = S_loot["coin_gold_ratio"]
	RARITY_MAX_RANDOM = S_loot["rarity_max_random"]
	RARITY_QUALITY = S_loot["rarity_quality"]
	INVENTORY_SIZE = S_loot["inventory_size"]
	ITEM_PRICE_BASE = S_loot["item_price_base"]
	ITEM_PRICE_LEVEL = S_loot["item_price_level"]
	ITEM_PRICE_SPENT = S_loot["item_price_spent"]
	XP_GOLD_MAX_TOP = S_loot["xp_gold_max_top"]
	XP_GOLD_TOP_LEVEL = S_loot["xp_gold_top_level"]
	XP_GOLD_TOP_RARITY = S_loot["xp_gold_top_rarity"]
	var S_potions := GameDB.settings("potions")
	POTION_MAX = S_potions["potion_max"]
	POTION_HEAL = S_potions["potion_heal"]
	POTION_CD = S_potions["potion_cd"]
	POTION_START = S_potions["potion_start"]
	POTION_DROP_CHANCE = S_potions["potion_drop_chance"]
	POTION_ELITE_CHANCE = S_potions["potion_elite_chance"]
	POTION_PRICE_BASE = S_potions["potion_price_base"]
	POTION_PRICE_PER_LEVEL = S_potions["potion_price_per_level"]
	VARENYK_HEAL = S_potions["varenyk_heal"]
	VARENYK_MIN = S_potions["varenyk_min"]
	VARENYK_DROP_CHANCE = S_potions["varenyk_drop_chance"]
	MANA_POTION_MAX = S_potions["mana_potion_max"]
	MANA_POTION_RESTORE = S_potions["mana_potion_restore"]
	MANA_POTION_CD = S_potions["mana_potion_cd"]
	MANA_POTION_DROP_CHANCE = S_potions["mana_potion_drop_chance"]
	MANA_POTION_PRICE_BASE = S_potions["mana_potion_price_base"]
	MANA_POTION_PRICE_PER_LEVEL = S_potions["mana_potion_price_per_level"]
	var S_buffs := GameDB.settings("buffs")
	MEAL_TIME = S_buffs["meal_time"]
	BREW_TIME = S_buffs["brew_time"]
	INSPIRED_TIME = S_buffs["inspired_time"]
	BUFF_CAP = S_buffs["buff_cap"]
	var S_death := GameDB.settings("death")
	DEATH_XP_LOSS = S_death["death_xp_loss"]
	DEATH_GOLD_LOSS = S_death["death_gold_loss"]
	DEATH_XP_FROM = S_death["death_xp_from"]
	var S_sharpening := GameDB.settings("sharpening")
	MAX_UPGRADE = S_sharpening["max_upgrade"]
	UPGRADE_BONUS = S_sharpening["upgrade_bonus"]
	SHARPEN_RISK_FROM = S_sharpening["sharpen_risk_from"]
	SHARPEN_SAFE_MULT = S_sharpening["sharpen_safe_mult"]
	SHARPEN_COST_BASE = S_sharpening["sharpen_cost_base"]
	SHARPEN_COST_RARITY = S_sharpening["sharpen_cost_rarity"]
	SHARPEN_COST_LEVEL = S_sharpening["sharpen_cost_level"]
	var S_quests := GameDB.settings("quests")
	MAX_ACTIVE_QUESTS = S_quests["max_active_quests"]
	var S_party := GameDB.settings("party")
	MAX_COMPANIONS = S_party["max_companions"]
	# Похідне число: стеля властивості xp чи gold на речі без заточки
	XP_GOLD_CAP = XP_GOLD_MAX_TOP / (1.0 + UPGRADE_BONUS * MAX_UPGRADE)


# ======================= Баланс (числа — у data/settings.json) =======================
# ---- Сила нечисті: мірка від еталонного героя ----
# Раніше здоров'я нечисті росло з рівнем лінійно, а шкода героя приблизно як квадрат рівня. На 20-му рівні
# звичайний ворог падав за чверть секунди, на 75-му за три сотих, і герой міг пропустити понад 60 ударів.
# Тепер уся нечисть рівня L рахується від еталонного героя цього рівня в середньому спорядженні
# (криві REF_* зняті з tools/power_probe.gd): звичайний заражений тримає ENEMY_TTK секунд його чистої шкоди,
# а удар забирає ENEMY_HIT його запасу живучості. Хто вдягнений краще за еталон, тому легше; хто гірше, тому важче.
# Герой у найкращому спорядженні з душами й клейнодами має шкоди в 4–8 разів більше й живучості у 2,5 раза.
static var REF_DPS_BASE: float  # шкода за секунду еталонного героя: основа
static var REF_DPS_K: float  # шкода за секунду: множник при рівні в степені pow
static var REF_DPS_POW: float  # шкода за секунду: степінь рівня (ref_dps = base + k × рівень^pow)
static var REF_EHP_BASE: float  # запас живучості еталонного героя: основа
static var REF_EHP_Q: float  # до рівня knee запас росте квадратом: + q × рівень²
static var REF_EHP_KNEE: int  # рівень, після якого запас росте лінійно
static var REF_EHP_LIN: float  # після knee: + lin за кожен рівень
# Мірка за рівнем, точками [рівень, секунд чистої шкоди еталонного героя на звичайного зараженого,
# частка його запасу живучості за удар]; між точками плавно, після останньої рівно.
# Новачкові м'яко. До 20-го рівня (сюжет) гра вже тверда: у середньому спорядженні поле свого рівня
# проходиться із зіллям, печера свого рівня вбиває. Далі мірка росте ще, бо на високих рівнях герой уже
# має ходити в легендарному: у середньому там дуже важко, у доброму (легендарне із заточкою) суворо,
# а нормально косити нечисть виходить лише в найкращому. Числа перевірено симуляціями (docs/balance.md).
static var ENEMY_CURVE: Array  # мірка за рівнем: точки {level, ttk — секунд чистої шкоди еталонного героя на звичайного зараженого, hit — частка його живучості за удар}; між точками плавно, після останньої рівно
static var STD_HP: float  # здоров'я «звичайного зараженого» в таблиці видів mobs.json (решта видів у пропорції до нього)
static var STD_DMG: float  # удар «звичайного зараженого» в таблиці видів (решта видів у пропорції до нього)
static var OLD_DMG_PER_LEVEL: float  # стара лінійна шкода нечисті за рівень: під неї зроблені формули міцності брам і возів (FarService.guard_mult)


## Башта Кощія й Глибини зарази не мають стелі. До ENDLESS_SOFT-го рівня нечисть росте за звичайною міркою.
## Вище рівень росте далі, а здоров'я й удар ще й множаться за кожен рівень понад межу: так сходинки
## лишаються відчутними, хоч мірка після 50-го рівня вже рівна. Здобич вище за ENDLESS_SOFT-й рівень не росте:
## речі 100–140-го рівня дають лише надважкі печери.
static var ENDLESS_SOFT: int  # Башта й Глибини: до цього рівня нечисть росте за звичайною міркою, вище — ще й множиться; здобич вище не росте
static var ENDLESS_HP_PER_LEVEL: float  # множник здоров'я за кожен рівень понад endless_soft
static var ENDLESS_DMG_PER_LEVEL: float  # множник удару за кожен рівень понад endless_soft


static func endless_hp(lvl: int) -> float:
	return pow(ENDLESS_HP_PER_LEVEL, float(maxi(0, lvl - ENDLESS_SOFT)))


static func endless_dmg(lvl: int) -> float:
	return pow(ENDLESS_DMG_PER_LEVEL, float(maxi(0, lvl - ENDLESS_SOFT)))


## Шкода за секунду еталонного героя рівня lvl.
static func ref_dps(lvl: int) -> float:
	return REF_DPS_BASE + REF_DPS_K * pow(float(maxi(1, lvl)), REF_DPS_POW)


## Запас живучості еталонного героя: здоров'я з поправкою на захист.
static func ref_ehp(lvl: int) -> float:
	var l := maxi(1, lvl)
	if l <= REF_EHP_KNEE:
		return REF_EHP_BASE + REF_EHP_Q * l * l
	return REF_EHP_BASE + REF_EHP_Q * REF_EHP_KNEE * REF_EHP_KNEE + REF_EHP_LIN * (l - REF_EHP_KNEE)


## Значення мірки для рівня: col 1 — секунди шкоди, col 2 — частка живучості за удар.
static func _enemy_curve(lvl: int, col: int) -> float:
	var pts: Array = ENEMY_CURVE
	if lvl <= int(pts[0][0]):
		return float(pts[0][col])
	for i in range(1, pts.size()):
		if lvl <= int(pts[i][0]):
			var t := float(lvl - int(pts[i - 1][0])) / float(int(pts[i][0]) - int(pts[i - 1][0]))
			return lerpf(float(pts[i - 1][col]), float(pts[i][col]), t)
	return float(pts[-1][col])


## Скільки секунд чистої шкоди еталонного героя тримає звичайний заражений рівня lvl.
static func enemy_ttk(lvl: int) -> float:
	return _enemy_curve(lvl, 1)


## Яку частку запасу живучості еталонного героя забирає удар звичайного зараженого рівня lvl.
static func enemy_hit(lvl: int) -> float:
	return _enemy_curve(lvl, 2)


## Здоров'я звичайного зараженого рівня lvl.
static func enemy_std_hp(lvl: int) -> float:
	return ref_dps(lvl) * enemy_ttk(lvl)


## Удар звичайного зараженого рівня lvl (до захисту героя).
static func enemy_std_dmg(lvl: int) -> float:
	return ref_ehp(lvl) * enemy_hit(lvl)


## Множники до табличних здоров'я й удару виду для рівня lvl.
static func enemy_hp_scale(lvl: int) -> float:
	return enemy_std_hp(lvl) / STD_HP


static func enemy_dmg_scale(lvl: int) -> float:
	return enemy_std_dmg(lvl) / STD_DMG
static var ENEMY_XP_PER_LEVEL: float  # досвіду з ворога більше на цю частку за кожен його рівень
static var COIN_GOLD_RATIO: float  # скільки гривень дає монета відносно її досвіду
static var ITEM_DROP_CHANCE: float  # шанс речі з рядового ворога
static var FIELD_GOAL_BASE: int  # скільки нечисті треба знищити для зачистки: основа
static var FIELD_GOAL_PER_LEVEL: int  # і ще стільки за кожен рівень місцевості
static var FIELD_OPEN_ABOVE: int  # у поле пускають, коли воно не вище за героя більш як на стільки рівнів
static var BOSS_HP_MULT: float  # бос у стільки разів здоровіший за звичайного ворога свого виду
static var BOSS_XP_MULT: int  # бос дає у стільки разів більше досвіду (ціле)
static var BOSS_DMG_MULT: float  # бос б'є у стільки разів сильніше за рядового свого виду
static var ARMOR_CAP: float  # захист не гасить більше цієї частки удару
static var LIFESTEAL_MAX_HPS: float  # вампіризм лікує щонайбільше цю частку здоров'я за секунду
static var MANA_ON_HIT: float  # наснаги за влучний удар зі звичайною швидкістю (швидші удари дають стільки ж за секунду)
static var MANA_ON_HIT_CD: float  # перезарядка удару, с, для якої рахується mana_on_hit
static var DUNGEON_ROOM_BASE: int  # ворогів у кімнаті печери: основа
static var DUNGEON_ROOM_PER: int  # і ще стільки за кожен номер кімнати
static var POTION_MAX: int  # скільки зілля можна нести
static var POTION_HEAL: float  # частка здоров'я, яку відновлює зілля
static var POTION_CD: float  # секунд між ковтками зілля
static var POTION_START: int  # скільки зілля в нового героя
static var POTION_DROP_CHANCE: float  # шанс зілля з рядового ворога
static var POTION_ELITE_CHANCE: float  # шанс зілля з еліти (бос лишає одне завжди)
## Вареник із нечисті лікує частку здоров'я героя (не менш як VARENYK_MIN): раніше це були ті самі 20
## здоров'я на будь-якому рівні, і на високих рівнях вареник нічого не важив. З боса вареник удвічі ситніший.
static var VARENYK_HEAL: float  # вареник лікує цю частку здоров'я героя (з боса — удвічі більше)
static var VARENYK_MIN: int  # але не менше стількох здоров'я
static var VARENYK_DROP_CHANCE: float  # шанс вареника з рядового ворога
## Зілля наснаги: окремий запас, відновлює частку наснаги (здоров'я не лікує).
static var MANA_POTION_MAX: int  # скільки зілля наснаги можна нести (волхви — на одне більше)
static var MANA_POTION_RESTORE: float  # зілля наснаги відновлює цю частку наснаги
static var MANA_POTION_CD: float  # секунд між ковтками зілля наснаги
## Страви з казана й зілля сили діють певний час бою, а не «один похід». Час іде лише в бою.
static var MEAL_TIME: float  # страва з казана діє стільки секунд бою
static var BREW_TIME: float  # зілля сили й зілля проти зарази, секунд бою
static var INSPIRED_TIME: float  # натхнення від кобзаря в дорозі, секунд бою
static var BUFF_CAP: float  # більше стількох секунд наперед не запасти
static var MANA_POTION_DROP_CHANCE: float  # шанс зілля наснаги з рядового ворога (у волхвів удвічі більший)
static var POTION_PRICE_BASE: int  # ціна зілля: основа + per_level × рівень героя
static var POTION_PRICE_PER_LEVEL: int  # приріст ціни зілля за рівень героя
static var MANA_POTION_PRICE_BASE: int  # ціна зілля наснаги: основа + per_level × рівень героя
static var MANA_POTION_PRICE_PER_LEVEL: int  # приріст ціни зілля наснаги за рівень героя


static func potion_price(hero_level: int) -> int:
	return POTION_PRICE_BASE + POTION_PRICE_PER_LEVEL * hero_level


static func mana_potion_price(hero_level: int) -> int:
	return MANA_POTION_PRICE_BASE + MANA_POTION_PRICE_PER_LEVEL * hero_level


## Ціна смерті в бою: частка досвіду, потрібного на поточний рівень (рівень не падає), і частка гривень.
## Новачків до DEATH_XP_FROM-го рівня досвідом не караємо. Двобій, варта й вали — випробування, там ціни немає.
static var DEATH_XP_LOSS: float  # частка досвіду, потрібного на поточний рівень, яку забирає смерть (рівень не падає)
static var DEATH_GOLD_LOSS: float  # частка гривень, яку забирає смерть
static var DEATH_XP_FROM: int  # до цього рівня досвідом не караємо


## З XP_LATE_FROM-го рівня кожен наступний рівень дорожчий ще на XP_LATE_STEP: дорога до останнього має
## відчуватися. У доброму спорядженні в Глибинах рівень на 75-му бере близько півтори години бою,
## останній — близько чотирьох (tools/depth_sim.gd, docs/balance.md).

## Крива досвіду (Data.xp_for_level): основа, приріст за рівень і за його квадрат; з XP_STEEP_FROM-го рівня крутішає.
static var XP_BASE: int  # досвід на рівень l: base + per_level × l + per_level_sq × l²
static var XP_PER_LEVEL: int  # приріст досвіду на рівень за кожен рівень
static var XP_PER_LEVEL_SQ: int  # приріст досвіду на рівень за квадрат рівня
static var XP_STEEP_FROM: int  # з цього рівня крива крутішає: × (1 + steep_k × (l − steep_from + 1))^steep_pow
static var XP_STEEP_K: float  # крутість кривої після steep_from
static var XP_STEEP_POW: float  # степінь кривої після steep_from
static var XP_LATE_FROM: int  # з цього рівня кожен наступний дорожчий ще на late_step
static var XP_LATE_STEP: float  # надбавка до ціни рівня за кожен рівень від late_from


## Досвід, потрібний, щоб перейти з рівня l на l+1.
## До 30-го рівня крива м'яка (сюжет), далі — крутішає: гра після сюжету розрахована на десятки годин.
static func xp_for_level(l: int) -> int:
	var base := XP_BASE + XP_PER_LEVEL * l + XP_PER_LEVEL_SQ * l * l
	if l < XP_STEEP_FROM:
		return base
	var late := 1.0 + XP_LATE_STEP * maxi(0, l - XP_LATE_FROM + 1)
	return int(base * pow(1.0 + XP_STEEP_K * (l - (XP_STEEP_FROM - 1)), XP_STEEP_POW) * late)


static func coin_gold(xp_value: int) -> int:
	return maxi(1, roundi(xp_value * COIN_GOLD_RATIO))

## Характерництво підсилює вміння щораз слабше: перші SPI_SOFT очок понад початкові повною мірою (+5% сили вмінь, швидша
## перезарядка), кожне наступне — лише часткою SPI_LATE від того. Волхвові Характерництво дає ще й шкоду
## посохом, тож без цього його вміння били вп'ятеро сильніше за воїнові (tools/dps_probe.gd).
static var SPI_SOFT: float  # Характерництво: стільки очок підсилює вміння повною мірою
static var SPI_LATE: float  # кожне очко Характерництва понад spi_soft діє лише цією часткою


static func soft_spi(spi: float) -> float:
	return spi if spi <= SPI_SOFT else SPI_SOFT + (spi - SPI_SOFT) * SPI_LATE


## Стрільцям (лук, пістолі, пищаль) Спритність дає і силу пострілу, і його швидкість. Щоб одна характеристика
## не множила сама себе, швидкість пострілу від неї росте повною мірою лише перші AGI_ASPD_SOFT очок,
## далі часткою AGI_ASPD_LATE. Сила пострілу й крит ростуть як і раніше.
static var AGI_ASPD_SOFT: float  # Спритність стрільця: стільки очок прискорюють постріл повною мірою
static var AGI_ASPD_LATE: float  # кожне очко Спритності понад agi_aspd_soft прискорює постріл лише цією часткою
## Наснага за звичайний постріл стрільця: частка від того, що дає влучний удар у ближньому бою.
static var MANA_ON_SHOT: float  # наснага за звичайний постріл стрільця: частка від влучного удару в ближньому бою


static func soft_agi_aspd(agi: float) -> float:
	return agi if agi <= AGI_ASPD_SOFT else AGI_ASPD_SOFT + (agi - AGI_ASPD_SOFT) * AGI_ASPD_LATE


static var STAT_POINTS_PER_LEVEL: int  # очок характеристик за рівень героя
static var SKILL_POINTS_PER_LEVEL: int  # очок умінь за рівень майстерності класу
static var PERK_POINTS_PER_LEVEL: int  # очок Загартування за кожні harden_every рівнів героя
static var PERK_TIER_STEP: int  # скільки очок треба вкласти в гілку Загартування, щоб відкрити наступний ярус
## Досвід за місію — частка смуги нинішнього рівня (і смуги майстерності), без надбавок: Player.add_mission_xp.
static var MISSION_XP: float  # крок історії, переказу чи доручення (reward.xp «mission»)
static var BOSS_MISSION_XP: float  # крок, мети якого не досягти без боса (reward.xp «boss»)
static var CITY_QUEST_XP: float  # завдання міста, до множника завдання


## Частка смуги за місію виду kind: позначка reward.xp кроку («mission», «boss») чи «city» (завдання міста); інше — 0.
static func mission_share(kind: String) -> float:
	match kind:
		"mission":
			return MISSION_XP
		"boss":
			return BOSS_MISSION_XP
		"city":
			return CITY_QUEST_XP
	return 0.0

# Характеристики героя (назва й опис) лежать у data/base_stats.json, Загартування — у
# data/perk_branches.json і perks.json (docs/data.md, «Класи й уміння»); що вони дають — Player.recalc.
const Classes := preload("res://scripts/data/classes.gd")

static var _stats: Array = []  # записи характеристик у порядку екрана героя
static var _perk_tree: Array = []  # [{"name": гілка, "tiers": [[вміння ярусу 1], ...]}]
static var _perk_at := {}  # id → [гілка, ярус, запис]


## Характеристики героя: записи base_stats.json (з «id») у порядку файлу.
static func base_stats() -> Array:
	if _stats.is_empty():
		for id in GameDB.ids("base_stats"):
			_stats.append(GameDB.row("base_stats", id))
		_stats.make_read_only()
	return _stats


# Загартування — спільне для всіх класів дерево пасивних вмінь (очко за кожні 2 рівні героя).
# Ярус N (від 0) відкривається, коли у гілку вкладено N * PERK_TIER_STEP очок.

## Гілки Загартування: [{"name": назва, "tiers": [[записи perks.json ярусу], ...]}] (лише для читання).
static func perk_branches() -> Array:
	if _perk_tree.is_empty():
		var bi := {}
		for b in GameDB.ids("perk_branches"):
			bi[b] = _perk_tree.size()
			_perk_tree.append({"name": GameDB.row("perk_branches", b)["name"], "tiers": []})
		for id in GameDB.ids("perks"):
			var P: Dictionary = GameDB.row("perks", id)
			if not bi.has(P["branch"]):
				continue
			var tiers: Array = _perk_tree[bi[P["branch"]]]["tiers"]
			var ti := int(P["tier"]) - 1
			while tiers.size() <= ti:
				tiers.append([])
			tiers[ti].append(P)
			_perk_at[id] = [bi[P["branch"]], ti, P]
		GameDB._freeze(_perk_tree)
	return _perk_tree


## Повертає [індекс гілки, індекс ярусу, перк] або [-1, -1, {}].
static func find_perk(id: String) -> Array:
	perk_branches()
	return _perk_at.get(id, [-1, -1, _EMPTY])


# ======================= Спорядження =======================
# Основи речей лежать у таблицях (docs/data.md, «Речі»): клітинки (data/gear_slots.json), рідкості
# (rarities.json), види зброї (weapons.json), основи обладунків (armors.json), бонуси (bonuses.json) і
# заточка (sharpening.json). Тут правила: як із них складається випадкова річ, ціни, заточка.

const GameDB := preload("res://scripts/core/game_db.gd")
const _EMPTY := {}

static var INVENTORY_SIZE: int  # місць у торбі
static var MAX_UPGRADE: int  # найвища заточка
static var UPGRADE_BONUS: float  # бонуси речі більші на цю частку за кожен рівень заточки
static var SHARPEN_RISK_FROM: int  # з цієї заточки невдача знижує рівень на 1
static var SHARPEN_SAFE_MULT: float  # заточка без ризику за гривні у стільки разів дорожча
static var SHARPEN_COST_BASE: int  # ціна заточки: base × (заточка + 1) × (1 + cost_rarity × рідкість) × (1 + cost_level × рівень речі)
static var SHARPEN_COST_RARITY: float  # приріст ціни заточки за щабель рідкості
static var SHARPEN_COST_LEVEL: float  # приріст ціни заточки за рівень речі
static var ITEM_PRICE_BASE: int  # ціна речі: base × (1 + рідкість) × (1 + price_level × рівень) + price_spent × вкладене в заточку
static var ITEM_PRICE_LEVEL: float  # приріст ціни речі за кожен її рівень
static var ITEM_PRICE_SPENT: float  # частка гривень, вкладених у заточку, що вертається в ціні

## Найбільший бонус досвіду чи гривень від однієї речі при найвищій заточці (+MAX_UPGRADE), у відсотках.
## Шість речей із найкращою такою властивістю разом дають близько 100%. До версії 0.50 одна легендарна
## шапка 99-го рівня на +10 давала +152% досвіду, а сума по всьому спорядженню сягала кількасот відсотків.
static var XP_GOLD_MAX_TOP: float  # найбільший бонус досвіду чи гривень від однієї речі при найвищій заточці, %
## Стеля самої властивості xp чи gold на речі (без заточки): заточка множить її до XP_GOLD_MAX_TOP.
## Які властивості так рахуються — «capped» у bonuses.json, їхній кидок — там само («roll»).
static var XP_GOLD_CAP: float  # = XP_GOLD_MAX_TOP / (1 + UPGRADE_BONUS × MAX_UPGRADE), рахує apply_settings()
## Найкраща звичайна річ, від якої рахується масштаб: легендарна цього рівня з найвищим кидком дає рівно стелю.
static var XP_GOLD_TOP_LEVEL: int  # рівень найкращої звичайної речі, від якої рахується масштаб досвіду й гривень
static var XP_GOLD_TOP_RARITY: int  # і її рідкість

static var RARITY_MAX_RANDOM: int  # найвища рідкість випадкової речі (вище — лише іменні: золоті, набори, артефакти)
static var RARITY_QUALITY: float  # якість рідкості: бонуси речі × (1 + rarity_quality × номер рідкості)

## Яку зброю генерувати в здобичі й крамницях (виставляє гра під клас героя; порожньо — будь-яку «basic»).
static var weapon_pool: Array = []

# Похідні переліки з таблиць: складаються раз, коли вперше потрібні, і лише для читання.
static var _slots: Array = []  # клітинки, що вдягаються (з «primary»), у порядку файлу
static var _drop_slots: Array = []  # кидок клітинки випадкової речі: кожна стільки разів, яка її «drop»
static var _armor_names := {}  # клітинка → назви основ обладунку
static var _basic: Array = []  # типовий пул зброї
static var _agi: Array = []  # зброя від Спритності
static var _affix_pool: Array = []  # бонуси-властивості в порядку кидка
static var _whole := {}  # цілі бонуси (характеристики)
static var _capped: Array = []  # досвід і гривні
static var _rarity: Array = []  # записи рідкостей за rank
static var _rarity_colors: Array = []
static var _sharpen: Array = []  # шанс заточки за нинішнім рівнем


## Клітинки спорядження, що вдягаються: ["weapon", "head", ...].
static func slots() -> Array:
	if _slots.is_empty():
		for id in GameDB.ids("gear_slots"):
			var R: Dictionary = GameDB.gear_slot(id)
			if R.has("primary"):
				_slots.append(id)
				for i in int(R.get("drop", 0)):
					_drop_slots.append(id)
		_slots.make_read_only()
		_drop_slots.make_read_only()
	return _slots


## Чи вдягається річ цієї клітинки (артефакт — ні).
static func is_slot(id: String) -> bool:
	return GameDB.gear_slot(id).has("primary")


## Назва клітинки: «Зброя», «Шапка», «Артефакт».
static func slot_name(id: String) -> String:
	return str(GameDB.gear_slot(id)["name"])


## Головний бонус речі цієї клітинки (flat_dmg, hp...).
static func slot_primary(slot: String) -> String:
	return str(GameDB.gear_slot(slot)["primary"]["stat"])


## Вид зброї: {name, dmg, cd, range, arc, kb, hint...} (weapons.json).
static func weapon(type: String) -> Dictionary:
	return GameDB.weapon(type)


static func has_weapon(type: String) -> bool:
	return GameDB.table("weapons").has(type)


static func weapon_name(type: String) -> String:
	return str(GameDB.weapon(type)["name"])


## Усі види зброї в порядку файлу.
static func weapon_ids() -> Array:
	return GameDB.ids("weapons")


## Зброя дальнього бою: б'є снарядами, дальність стала (див. Player.recalc).
static func is_ranged(type: String) -> bool:
	return bool(GameDB.weapon(type).get("ranged", false))


## Яка характеристика дає силу удару цією зброєю: «stat» запису, а без нього — Спритність для «agi»,
## інакше Сила ("str", "agi", "spi").
static func weapon_stat(type: String) -> String:
	var W: Dictionary = GameDB.weapon(type)
	return str(W.get("stat", "agi" if bool(W.get("agi", false)) else "str"))


## Зброя, сила якої йде від Спритності.
static func is_agi(type: String) -> bool:
	return bool(GameDB.weapon(type).get("agi", false))


static func agi_weapons() -> Array:
	if _agi.is_empty():
		for id in weapon_ids():
			if is_agi(id):
				_agi.append(id)
		_agi.make_read_only()
	return _agi


## Зброя, що падає, коли гра не задала пулу під клас.
static func basic_weapons() -> Array:
	if _basic.is_empty():
		for id in weapon_ids():
			if GameDB.weapon(id).get("basic", false):
				_basic.append(id)
		_basic.make_read_only()
	return _basic


## Назви основ обладунку клітинки в порядку файлу.
static func armor_names(slot: String) -> Array:
	if _armor_names.is_empty():
		for id in GameDB.ids("armors"):
			var R: Dictionary = GameDB.row("armors", id)
			if not _armor_names.has(R["slot"]):
				_armor_names[R["slot"]] = []
			_armor_names[R["slot"]].append(R["name"])
		for s in _armor_names:
			_armor_names[s].make_read_only()
		_armor_names.make_read_only()
	return _armor_names.get(slot, [])


## Бонуси, що бувають властивостями випадкової речі, у порядку кидка.
static func affix_pool() -> Array:
	if _affix_pool.is_empty():
		for id in GameDB.ids("bonuses"):
			if GameDB.bonus(id).get("affix", false):
				_affix_pool.append(id)
		_affix_pool.make_read_only()
	return _affix_pool


## Усі бонуси речей у порядку файлу.
static func stat_ids() -> Array:
	return GameDB.ids("bonuses")


## Цілий бонус (Сила, Спритність...): заточка округлює його донизу.
static func is_whole(id: String) -> bool:
	if _whole.is_empty():
		for b in GameDB.ids("bonuses"):
			if GameDB.bonus(b).get("whole", false):
				_whole[b] = true
		_whole.make_read_only()
	return _whole.has(id)


## Цілі бонуси в порядку файлу.
static func whole_stats() -> Array:
	var out := []
	for id in stat_ids():
		if is_whole(id):
			out.append(id)
	return out


## Властивості з масштабом і стелею (досвід, гривні).
static func capped_stats() -> Array:
	if _capped.is_empty():
		for id in GameDB.ids("bonuses"):
			if GameDB.bonus(id).get("capped", false):
				_capped.append(id)
		_capped.make_read_only()
	return _capped


static func is_capped(id: String) -> bool:
	return capped_stats().has(id)


static func _rarities() -> Array:
	if _rarity.is_empty():
		_rarity = GameDB.ladder("rarities", "rank")
		for R in _rarity:
			_rarity_colors.append(R.get("color", Color.WHITE))
		_rarity_colors.make_read_only()
	return _rarity


## Назва рідкості: «Легендарна».
static func rarity_name(r: int) -> String:
	return str(_rarities()[r]["name"])


## Множина рідкості для фільтра автопідбору: «Легендарні».
static func rarity_plural(r: int) -> String:
	return str(_rarities()[r]["plural"])


## Колір рідкості (назва й клітинка речі).
static func rarity_color(r: int) -> Color:
	if _rarity_colors.is_empty():
		_rarities()
	return _rarity_colors[r]


## Множини рідкостей випадкових речей: «Звичайні», «Добротні»...
static func rarity_plurals() -> Array:
	var out := []
	for R in _rarities():
		if R.has("plural"):
			out.append(R["plural"])
	return out


## Скільки всього рідкостей (від звичайної до артефакта).
static func rarity_count() -> int:
	return _rarities().size()


## Шанси заточки: [з +0, з +1, ...].
static func sharpen_chances() -> Array:
	if _sharpen.is_empty():
		for R in GameDB.ladder("sharpening", "up"):
			_sharpen.append(float(R["chance"]))
		_sharpen.make_read_only()
	return _sharpen


## Шаблон тексту бонусу (%s — число) і скільки в ньому знаків після коми.
static func stat_text(id: String) -> String:
	return str(GameDB.bonus(id)["text"])


static func stat_decimals(id: String) -> int:
	return int(GameDB.bonus(id).get("decimals", 0))


static func fmt_stat(id: String, value: float) -> String:
	var B: Dictionary = GameDB.bonus(id)
	var num := ("%.1f" % value) if int(B.get("decimals", 0)) == 1 else str(roundi(value))
	return str(B["text"]) % num


## Масштаб властивості досвіду чи гривень: найвищий кидок легендарної речі XP_GOLD_TOP_LEVEL-го рівня
## дорівнює XP_GOLD_CAP. Так само множаться й ці властивості на речах зі старих збережень.
static func xp_gold_scale(id: String) -> float:
	var r: Dictionary = GameDB.bonus(id)["roll"]
	return XP_GOLD_CAP / ((float(r["max"]) + float(r["per_level"]) * XP_GOLD_TOP_LEVEL) * (1.0 + RARITY_QUALITY * XP_GOLD_TOP_RARITY))


## Значення властивості під стелею: досвід і гривні не більші за XP_GOLD_CAP, решта як є.
static func cap_affix(id: String, value: float) -> float:
	return minf(value, XP_GOLD_CAP) if is_capped(id) else value


## Позначка на речі: її досвід і гривні вже перераховано під стелю (див. rescale_xp_gold).
const XP_GOLD_MARK := "xg"


## Перерахувати досвід і гривні старої речі на нові числа: той самий масштаб, що й у формулі, потім стеля.
## Річ позначається, тож удруге не зменшиться, де б вона не лежала. Повертає true, якщо щось змінилося.
## Золоту річ перераховує Uniques.value (див. SaveSystem.rescale_items_xp_gold).
static func rescale_xp_gold(item: Dictionary) -> bool:
	if item.has(XP_GOLD_MARK):
		return false
	var changed := false
	for src in [item.get("base", {}), item.get("affixes", {})]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for id in capped_stats():
			if src.has(id):
				src[id] = cap_affix(id, float(src[id]) * xp_gold_scale(id))
				changed = true
	if changed:
		item[XP_GOLD_MARK] = 1
	return changed


## Кидок властивості (bonuses.json, «roll»): дробова — (min..max + per_level × рівень) × якість рідкості,
## ціла — від min до max + рівень/every + рідкість/2, досвід і гривні — ще й масштаб і стеля.
static func _roll_value(id: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + RARITY_QUALITY * rarity
	var B: Dictionary = GameDB.bonus(id)
	var R: Dictionary = B.get("roll", _EMPTY)
	if R.is_empty():
		return 0.0
	if B.get("capped", false):
		return cap_affix(id, (randf_range(float(R["min"]), float(R["max"])) + float(R["per_level"]) * ilvl) * q * xp_gold_scale(id))
	if B.get("whole", false):
		return float(randi_range(int(R["min"]), int(R["max"]) + ilvl / int(R["every"]) + rarity / 2))
	return (randf_range(float(R["min"]), float(R["max"])) + float(R.get("per_level", 0.0)) * ilvl) * q


## Головний бонус речі (gear_slots.json, «primary»): дробовий — (base + per_level × рівень) × якість,
## цілий — base + рівень/every + рідкість/2.
static func _primary_value(slot: String, ilvl: int, rarity: int) -> float:
	var q := 1.0 + RARITY_QUALITY * rarity
	var P: Dictionary = GameDB.gear_slot(slot).get("primary", _EMPTY)
	if P.is_empty():
		return 0.0
	if P.has("every"):
		return float(int(P["base"]) + ilvl / int(P["every"]) + rarity / 2)
	return (float(P["base"]) + float(P["per_level"]) * ilvl) * q


## Ваги рідкості випадкової речі (rarities.json, «weight»): звичайна, добротна, рідкісна, легендарна.
## Рідкісних і легендарних із рівнем більшає, але повільно. Стара крива (10 + 0,8 і 2 + 0,3 за рівень)
## робилася для гри до 22-го рівня: на 75-му кожна восьма річ була легендарною, і за годину їх падало
## від 25 до 50 (tools/loot_probe.gd). Тепер легендарна на 75-му — кожна тридцята з рядової нечисті.
static func rarity_weights(level: int) -> Array:
	var w := []
	for R in _rarities():
		if R.has("weight"):
			w.append(float(R["weight"]["base"]) + float(R["weight"]["per_level"]) * level)
	return w


## Частка рідкості rarity серед речей рівня level, якщо рідкість не нижча за min_rarity (0..1).
static func rarity_share(level: int, rarity: int, min_rarity: int = 0) -> float:
	var w := rarity_weights(level)
	if rarity < min_rarity or rarity >= w.size():
		return 0.0
	var total := 0.0
	for i in range(min_rarity, w.size()):
		total += float(w[i])
	return float(w[rarity]) / total


static func roll_rarity(wave: int, min_rarity: int = 0) -> int:
	var w := rarity_weights(wave)
	var total := 0.0
	for i in range(min_rarity, 4):
		total += w[i]
	var r := randf() * total
	for i in range(min_rarity, 4):
		r -= w[i]
		if r <= 0.0:
			return i
	return 3


## Створює випадкову річ. slot/type можна задати явно.
static func gen_item(ilvl: int, rarity: int, slot: String = "", type: String = "") -> Dictionary:
	rarity = mini(rarity, RARITY_MAX_RANDOM)
	if slot == "":
		slots()
		slot = _drop_slots[randi() % _drop_slots.size()]
	var name := ""
	if slot == "weapon":
		if type == "":
			var pool: Array = weapon_pool if not weapon_pool.is_empty() else basic_weapons()
			type = pool[randi() % pool.size()]
		name = weapon_name(type)
	else:
		var names: Array = armor_names(slot)
		name = names[mini(names.size() - 1, randi() % names.size())]
	var epithets: Array = _rarities()[rarity].get("epithets", [])
	if not epithets.is_empty():
		name += " «%s»" % epithets[randi() % epithets.size()]
	var primary: String = slot_primary(slot)
	var affixes := {}
	var pool := affix_pool().duplicate()
	pool.erase(primary)
	pool.shuffle()
	for i in rarity:
		affixes[pool[i]] = _roll_value(pool[i], ilvl, rarity)
	return {
		"slot": slot, "type": type, "name": name, "rarity": rarity, "ilvl": ilvl, "up": 0, "spent": 0,
		"base": {primary: _primary_value(slot, ilvl, rarity)}, "affixes": affixes,
	}


## Колір назви й клітинки речі: за рідкістю, а в речі набору свій (див. Sets.COLOR).
const SET_COLOR := Color(0.88, 0.55, 1.0)


static func item_color(item: Dictionary) -> Color:
	if item.has("set"):
		return SET_COLOR
	return rarity_color(int(item["rarity"]))


static func item_title(item: Dictionary) -> String:
	return item["name"] + (" +%d" % item["up"] if item["up"] > 0 else "")


## Усі бонуси речі з урахуванням заточки.
static func item_stats(item: Dictionary) -> Dictionary:
	var mult: float = 1.0 + UPGRADE_BONUS * item["up"]
	var out := {}
	for src in [item["base"], item["affixes"]]:
		for id in src:
			var v: float = src[id] * mult
			if is_whole(id):
				v = floorf(v)
			out[id] = out.get(id, 0.0) + v
	return out


static func sharpen_cost(item: Dictionary) -> int:
	return int(SHARPEN_COST_BASE * (item["up"] + 1) * (1.0 + SHARPEN_COST_RARITY * item["rarity"]) * (1.0 + SHARPEN_COST_LEVEL * item["ilvl"]))


## Ціна заточки без ризику: звичайна (зі знижкою своєї кузні) × SHARPEN_SAFE_MULT.
static func sharpen_safe_cost(item: Dictionary, cost_mult: float = 1.0) -> int:
	return int(sharpen_cost(item) * (cost_mult * SHARPEN_SAFE_MULT))


static func sharpen_chance(item: Dictionary) -> float:
	var ch := sharpen_chances()
	return ch[mini(item["up"], ch.size() - 1)]


## Множник ціни продажу (ярмарок у місті — ×2; виставляє гра при вході в місто).
static var sell_mult: float = 1.0


## Ціна речі без надбавки ярмарку: від неї рахується, за скільки річ продає крамниця.
static func base_price(item: Dictionary) -> int:
	return int(ITEM_PRICE_BASE * (1 + item["rarity"]) * (1.0 + ITEM_PRICE_LEVEL * item["ilvl"]) + item["spent"] * ITEM_PRICE_SPENT)


## Цінна річ: золота, іменна чи з набору. Її не можна ні купити, ні викувати, тож за повну торбу
## вона не продається й не лишається на землі, а лягає понад місце.
static func is_precious(item: Dictionary) -> bool:
	return int(item.get("rarity", 0)) > RARITY_MAX_RANDOM or item.has("unique") or item.has("set")


static func sell_price(item: Dictionary) -> int:
	return int(base_price(item) * sell_mult)


# ======================= Світ =======================
# Краї, міста й місця лежать у таблицях (docs/data.md, «Світ»): data/regions.json, cities.json, places.json.
# Позиції — справжні географічні координати (довгота, широта) як Vector2; мапа проєктує їх на екран.
# Записи лише для читання: бій, що хоче змінити опис місця, бере собі копію (Combat.enter).

## Усі місця (поля й печери): id → запис.
static func places() -> Dictionary:
	return GameDB.table("places")


## Місце на мапі (див. GameDB.PLACE_SCHEMA); для невідомого id — порожній запис.
static func place(id: String) -> Dictionary:
	return GameDB.table("places").get(id, _EMPTY)


static func is_place(id: String) -> bool:
	return GameDB.table("places").has(id)


## Місця в порядку файлу (лише для читання).
static func place_ids() -> Array:
	return GameDB.ids("places")


## Місто (див. GameDB.CITY_SCHEMA); для невідомого id — порожній запис.
static func city(id: String) -> Dictionary:
	return GameDB.table("cities").get(id, _EMPTY)


static func is_city(id: String) -> bool:
	return GameDB.table("cities").has(id)


## Міста в порядку файлу (лише для читання).
static func city_ids() -> Array:
	return GameDB.ids("cities")


## Далекий край (див. GameDB.REGION_SCHEMA); для невідомого id — порожній запис.
static func region(id: String) -> Dictionary:
	return GameDB.table("regions").get(id, _EMPTY)


static func is_region(id: String) -> bool:
	return GameDB.table("regions").has(id)


## Далекі краї в порядку показу (порядок файлу): чотири сторони світу довкола старої мапи,
## три краї Московії та Семигород за Карпатами. Місце краю має «region» (див. FarService.is_far).
static func region_ids() -> Array:
	return GameDB.ids("regions")


## Значок місця на мапі й у довіднику: свій («icon»: замок, шахта, острів), Башта, а інакше —
## за краєвидом (biomes.json: «icon» поля чи «dungeon_icon» печери).
static func place_icon(L: Dictionary) -> String:
	if L.has("icon"):
		return str(L["icon"])
	if L.get("tower", false):
		return "tower"
	var dungeon: bool = L["type"] == "dungeon"
	return str(GameDB.row("biomes", str(L["biome"])).get("dungeon_icon" if dungeon else "icon", "cave" if dungeon else "sabres"))


## Де в місті чекають ті, хто має справу до героя (вкладка міста, див. Game.hall_rows): міста мають
## ратушу, а Січ, козацький стан і святі місця називають цю будівлю по-своєму («hall» у записі міста).
static func hall_name(city_id: String) -> String:
	return str(city(city_id).get("hall", ""))


## Мета зачистки поля L (запис місця): «goal» самого запису, а без нього FIELD_GOAL_BASE + FIELD_GOAL_PER_LEVEL ×
## рівень місця, але не більше far.goal_max (FarService.GOAL_MAX). Одне правило для бою, швидкого походу, місії й ночі:
## рахується від рідного рівня місця, тож бій, підтягнутий місією чи ніччю, мети не роздуває.
static func field_goal(L: Dictionary) -> int:
	if L.has("goal"):
		return int(L["goal"])
	var cap: int = load("res://scripts/game/far_service.gd").GOAL_MAX
	return mini(cap, FIELD_GOAL_BASE + int(L["level"]) * FIELD_GOAL_PER_LEVEL)


## Рівень бою в місці для героя. Печера з босом («scale») росте разом із ним: рівень не нижчий за позначений,
## тож бос дає золоту річ до кінця гри. Поле має сталий рівень (бій за місією підтягує QuestEngine.fight_mods).
static func loc_level(L: Dictionary, hero_level: int) -> int:
	return maxi(int(L["level"]), hero_level) if L.get("scale", false) else int(L["level"])



## З якого рівня героя пускають у місце id. Поле — на FIELD_OPEN_ABOVE рівнів вище за героя (рівень поля − 3, не нижче
## 1-го); печера з босом — лише з власного рівня (для «N+» — N), без жодної надбавки. Місто, хутір, місця занять,
## Башта, Глибини й надважкі печери мають свої замки (або їх не мають): тут для них 1. Одне правило на всю гру:
## мапа й панель, Game.enter_location, завдання, розшук, випробування, події, порадник і довідник.
static func open_from(id: String) -> int:
	if not is_place(id):
		return 1
	var L: Dictionary = place(id)
	if L.get("endless", false) or L.has("peril"):
		return 1  # Башта, Глибини й надважкі печери — за своїми правилами (TowerService, DepthService, PerilService)
	if L["type"] == "dungeon":
		return maxi(1, int(L["level"]))
	return maxi(1, int(L["level"]) - FIELD_OPEN_ABOVE)


## Чи пускають героя рівня hero_level у місце id (див. open_from). Слабші за героя місця відкриті завжди.
static func place_open(id: String, hero_level: int) -> bool:
	return hero_level >= open_from(id)


## Чому місце закрите, одним реченням: «Відкриється з 4-го рівня героя.» ("" — відкрите).
static func open_text(id: String, hero_level: int) -> String:
	return "" if place_open(id, hero_level) else "Відкриється з %d-го рівня героя." % open_from(id)

## Імена, множини й трофеї нечисті — у data/mobs.json (див. GameDB).

static var MAX_ACTIVE_QUESTS: int  # скільки завдань можна взяти водночас
static var MAX_COMPANIONS: int  # супутників у загоні без Куреня (Курінь додає до двох)



## Найманці (ім'я, ціна, сила, механіка бою) — у data/companions.json (див. GameDB).


## Рівні лояльності міста — драбина data/loyalty_levels.json за «level» (0 — Чужинець):
## з якої кількості очок, назва й знижка в місті.
static func loyalty_levels() -> Array:
	return GameDB.ladder("loyalty_levels", "level")


static func loyalty_level(points: int) -> int:
	var lvl := 0
	var lad := loyalty_levels()
	for i in lad.size():
		if points >= int(lad[i]["from"]):
			lvl = i
	return lvl


## Назва рівня лояльності («Шанований»).
static func loyalty_name(level: int) -> String:
	return str(loyalty_levels()[level]["name"])


## З якої кількості очок починається рівень.
static func loyalty_from(level: int) -> int:
	return int(loyalty_levels()[level]["from"])


## Знижка в місті на цьому рівні лояльності.
static func loyalty_discount(level: int) -> float:
	return float(loyalty_levels()[level]["discount"])


static func place_name(id: String) -> String:
	if is_city(id):
		return city(id)["name"]
	if is_place(id):
		return place(id)["name"]
	var Camp = load("res://scripts/data/camp_data.gd")
	if id == Camp.CAMP_ID:
		return Camp.camp()["name"]
	if GameDB.table("spots").has(id):
		return GameDB.row("spots", id)["name"]
	return id
