extends RefCounted
## Заняття поза сюжетом: герць, огляд, Коло Кожум'яки, розшук, варта, торгівля, полювання, шинок, сліди,
## походи побратимів, слава й рекорди, свята, супровід. Записи — у таблицях data/*.json (docs/data.md,
## «Заняття»), логіка — у службах scripts/game/*_service.gd. Тут — зручні виклики над таблицями й робочі
## копії чисел-правил занять (самі числа — у data/settings.json, див. apply_settings()).

const GameDB := preload("res://scripts/core/game_db.gd")

# ======================= Слава =======================
## Слава — мірило козацької честі героя (world.glory). Дають її герць, розшук, варта, полювання.
## Ранги — data/glory_ranks.json, звідки береться — data/glory_sources.json.

# ======================= Герць на майдані =======================
## Суперники — data/rivals.json (ім'я, стиль і механіка бою scripts/mechanics/rival/<стиль>.gd, лист спрайтів,
## порада); кола турніру — data/duel_rounds.json: здоров'я суперника рівня з героєм — скільки секунд чистої шкоди
## еталонного героя цього рівня він тримає, удар — частка здоров'я героя вже після його захисту.
## Вільний герць: поза турніром, до першої поразки. Кожен наступний суперник у серії міцніший.
static var FREE_DUEL_SECONDS: float  # вільний герць: скільки секунд шкоди еталонного героя тримає перший суперник
static var FREE_DUEL_HIT: float  # вільний герць: частка здоров'я героя за удар першого суперника
static var FREE_DUEL_HP_STEP: float  # за кожну перемогу в серії суперник здоровіший на цю частку
static var FREE_DUEL_HIT_STEP: float  # і б'є сильніше на цю частку
static var FREE_DUEL_GOLD: int  # гривень за перемогу × рівень героя (за серію більше, DuelService.free_gold)
static var FREE_DUEL_PAID: int  # скільки перемог вільного герцю на день оплачується
static var FREE_DUEL_GLORY: int  # слава за першу оплачену перемогу дня
## Глядачі на майдані (листи спрайтів; це вигляд, а не дані гри)
const SPECTATORS := ["comp_dzhura", "comp_strilets", "comp_petro", "cossack_sabre", "cossack_pike", "peasant_pike", "comp_znakhar", "comp_oksana", "zaporozhets_sabre", "plastun_pike"]

# ======================= Дошка розшуку =======================
## Ціль — еліта з кількома властивостями, удвічі міцніша. Прізвиська розшукуваної нечисті — у її записі
## («bounty_names» у data/mobs.json).
static var BOUNTY_BOARD: int  # оголошень на дошці міста
static var BOUNTY_ACTIVE: int  # скільки голів можна шукати водночас
static var BOUNTY_REFRESH: int  # через стільки походів дошка оновлюється

# ======================= Гетьманський огляд (Чигирин) =======================
## Тижневі сутички ватаг: герой із побратимами проти сотні. Три сутички, три спроби, смерті нема.
## Сотні — data/muster_teams.json (styles — стилі суперників із герцю; перший — сотник, він виходить у кожній
## сутичці), сутички — data/muster_rounds.json, імена бійців — пул «muster_first» у data/name_pools.json, а
## прізвиська — «nicks» суперника того самого стилю.
const MUSTER_CITY := "chyhyryn"
static var MUSTER_MIN_LEVEL: int  # з якого рівня героя пускають на огляд
static var MUSTER_CAPTAIN: float  # сотник у стільки разів здоровіший за бійців

# ======================= Коло Кожум'яки =======================
## Три чудовиська поспіль на Змієвих валах (місце "kolo" на мапі); склад міняється щотижня. Хто буває в
## колі — пул «ring» у data/boss_pools.json, кола — data/ring_rounds.json.
## Сила чудовиськ — від рівня героя: здоров'я — секунди чистої шкоди еталонного героя, удар — частка його живучості
## вже після захисту (за колами: перше, друге, третє). Посіпаки чудовиськ — у пропорції до «звичайного зараженого».
static var RING_STAGES: int  # кіл (стільки ж записів у data/ring_rounds.json)
static var RING_CAP: float  # чудовисько не впаде швидше, ніж за цю частку розрахункового часу
static var RING_STD_TTK: float  # посіпаки: секунд чистої шкоди еталонного героя на одного
static var RING_STD_HIT: float  # посіпаки: частка живучості еталонного героя за удар
static var RING_XP: float  # множник досвіду з кола (нагорода тут — гаманець і слава)
static var RING_BREAK: float  # перепочинок між чудовиськами, с
static var RING_REPEAT_GOLD: int  # гривень × рівень героя за чудовисько, коли тижневе вже взято
static var RING_REPEAT_PAID: int  # скільки таких чудовиськ на день оплачується
static var RING_FAST: float  # пройшов коло швидше за стільки секунд бою — досягнення

# ======================= Місця на мапі (не міста й не місцевості) =======================
## data/spots.json: варта, полювання, рибалка, Коло Кожум'яки; level — з якого рівня героя відкрито.

# ======================= Козацька варта =======================
static var VIGIL_GOAL: float  # секунд, які треба вистояти на варті
static var VIGIL_GOLD: int  # гривень × рівень героя × номер хвилини
static var VIGIL_GLORY: int  # слави за кожну хвилину (до мети)
static var VIGIL_GLORY_GOAL: int  # слави додатково за повну варту
## Нечисть на варті — частка звичайної мірки рівня героя (Data.enemy_std_hp, enemy_std_dmg): на першій
## хвилині вона вдвічі кволіша за нечисть свого рівня, бо суне юрбою, і щохвилини міцнішає.
## На п'ятій хвилині здоров'я вже 130% мірки, удар 88%.
static var VIGIL_HP: float  # здоров'я нечисті на першій хвилині: частка звичайної мірки рівня героя
static var VIGIL_HP_STEP: float  # і ще стільки за кожну хвилину
static var VIGIL_HIT: float  # удар нечисті на першій хвилині: частка звичайної мірки
static var VIGIL_HIT_STEP: float  # і ще стільки за кожну хвилину
static var VIGIL_XP: float  # множник досвіду й гривень із ворогів на варті

# ======================= Чумацький шлях (торгівля крамом) =======================
## Крам — data/trade_goods.json (назва й базова ціна одиниці, множиться на «заможність» рівня героя),
## торг у містах — data/trade_cities.json (ціна краму відносно базової: менше 1 — тут його роблять).
static var TRADE_WEALTH: float  # ціни краму ростуть на цю частку за кожен рівень героя
static var TRADE_SPREAD: float  # продаєш за цю частку від ціни, за яку тут купують
static var TRADE_STEP: float  # кожна продана одиниця збиває ціну на цю частку, куплена — піднімає
static var TRADE_STOCK: int  # стільки одиниць кожного краму місто продасть за торговий день
static var TRADE_PERIOD: int  # торговий день триває стільки походів; потім ціни й запаси оновлюються
static var TRADE_CART: int  # місткість воза без Складу
static var TRADE_CART_SKLAD: int  # місткість воза: ще стільки за кожен рівень Складу
static var TRADE_AMBUSH: float  # шанс нападу на валку дорогою до міста
static var TRADE_AMBUSH_UNIT: float  # і ще стільки за кожну одиницю краму (не більше trade_ambush_max)
static var TRADE_AMBUSH_MAX: float  # найбільший шанс нападу на валку

# ======================= Полювання, рибалка й казан =======================
## Провіант (м'ясо, риба, городина) — ресурси героя з data/resources.json («food»). Звірі —
## data/hunt_animals.json, риба — data/fish.json, страви з казана — data/recipes.json (одна страва за раз;
## діє Data.MEAL_TIME секунд бою).
static var HUNT_ARROWS: int  # стріл на одного звіра
static var HUNT_PASSES: int  # скільки звірів пробіжить галявиною за одне полювання
static var HUNT_BULLSEYE: float  # частка радіуса звіра: влучив ближче до серця — «в яблучко»
static var FISH_BAIT: int  # закидів за одну рибалку
static var FISH_ZONE: Array  # [від, до]: у цій смузі натягу (частки) риба йде до берега

# ======================= Шинок: кості й чутки =======================
## Гра «дванадцять»: кидаєш по кості й додаєш очки; понад DICE_LIMIT — перебір. Суперники — data/dice_rivals.json
## (style — як грає, див. TavernService.rival_goes; stake — множник ставки).
static var DICE_LIMIT: int  # гра «дванадцять»: понад стільки очок — перебір
static var DICE_GAMES: int  # партій у кості на день
static var DICE_TWELVE: float  # рівно дванадцять — виграш у стільки разів
static var DICE_GLORY: int  # слава за першу за день перемогу над сотником
## Чутки: скільки походів живе торгова порада й наскільки вона піднімає ціну.
static var RUMOR_TIP_TRIPS: int  # скільки походів живе торгова порада з чуток
static var RUMOR_TIP_BONUS: float  # у стільки разів порада піднімає ціну краму

# ======================= Сліди на арені =======================
## У місцевості трапляється стежка слідів: іди по ній від точки до точки — наприкінці знахідка
## (data/trail_kinds.json: вага появи й підпис; що вона дає — Combat).
static var TRAIL_MIN_LEVEL: int  # з цього рівня героя трапляються сліди (і лігво)
static var TRAIL_CHANCE: float  # шанс стежки слідів у поході
static var TRAIL_CHANCE_SCOUT: float  # шанс стежки в пластуна (він бачить усю стежку одразу)
static var TRAIL_START: float  # як далеко від героя починаються сліди, пікселів
static var TRAIL_STEP: float  # довжина відтинка між точками стежки, пікселів
static var TRAIL_POINTS: int  # точок на стежці (остання — знахідка)
static var TRAIL_REACH: float  # наскільки близько треба підійти до точки, пікселів
static var TRAIL_CACHE_ITEM: float  # шанс речі в схованці

# ======================= Походи побратимів =======================
## Супутника можна відправити у власний похід: він іде сам і повертається зі здобиччю (data/expeditions.json).
## Поки він у поході, в бою його нема.
static var EXPEDITION_GOLD: int  # гривень за одиницю множника походу на 1-му рівні супутника
static var EXPEDITION_LEVEL: float  # здобич походу більша на цю частку за кожен рівень супутника
static var EXPEDITION_HERO: float  # іменні побратими приносять у стільки разів більше

# ======================= Літопис слави: рекорди роду =======================
## Рекорди спільні для всіх персонажів (account.records): data/records.json, порядок файлу — порядок показу.

# ======================= Сезонні свята =======================
## Свята — data/holidays.json (порядок файлу — за календарем, від січня), назви місяців — data/months.json,
## пороги жетонів — data/token_scales.json. Які ключі бонусу вміє гра — HolidayService.
## Жетони: шанс із звичайної нечисті, скільки з еліти й боса.
static var TOKEN_CHANCE: float  # шанс жетона свята зі звичайної нечисті
static var TOKEN_ELITE: int  # жетонів з еліти
static var TOKEN_BOSS: int  # жетонів з боса
static var TOKEN_GLORY: int  # слава за найвищу нагороду великого свята
static var TOKEN_GLORY_SMALL: int  # слава за найвищу нагороду малого свята

# ---------- Супровід: завдання міста «проведи мандрівника» (див. EscortService) ----------
## Мандрівники — data/escorts.json.
static var ESCORT_CHANCE: float  # частка завдань у дику місцевість, що стають супроводом
static var ESCORT_MULT: float  # нагорода за супровід у стільки разів більша за звичайне завдання
static var ESCORT_WAVES: int  # засідок на шляху
static var ESCORT_PACK: int  # нечисті в першій засідці
static var ESCORT_PACK_STEP: int  # і ще стільки за кожну наступну засідку
static var ESCORT_SPEED: float  # крок мандрівника, пікселів за секунду
static var ESCORT_FEAR: float  # нечисть ближче за стільки пікселів — мандрівник стоїть і чекає
static var ESCORT_HP: float  # здоров'я мандрівника: основа
static var ESCORT_HP_LVL: float  # і ще стільки за рівень місцевості
static var ESCORT_TIP: int  # гривень × рівень від вдячного мандрівника, якщо дійшов цілим


## Числа-правила вище лежать у data/settings.json (записи «duel», «muster», «ring», «vigil», «bounty», «trade», «hunting», «tavern», «trails», «expeditions», «holidays», «escort»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S_duel := GameDB.settings("duel")
	FREE_DUEL_SECONDS = S_duel["free_duel_seconds"]
	FREE_DUEL_HIT = S_duel["free_duel_hit"]
	FREE_DUEL_HP_STEP = S_duel["free_duel_hp_step"]
	FREE_DUEL_HIT_STEP = S_duel["free_duel_hit_step"]
	FREE_DUEL_GOLD = S_duel["free_duel_gold"]
	FREE_DUEL_PAID = S_duel["free_duel_paid"]
	FREE_DUEL_GLORY = S_duel["free_duel_glory"]
	var S_muster := GameDB.settings("muster")
	MUSTER_MIN_LEVEL = S_muster["muster_min_level"]
	MUSTER_CAPTAIN = S_muster["muster_captain"]
	var S_ring := GameDB.settings("ring")
	RING_STAGES = S_ring["ring_stages"]
	RING_CAP = S_ring["ring_cap"]
	RING_STD_TTK = S_ring["ring_std_ttk"]
	RING_STD_HIT = S_ring["ring_std_hit"]
	RING_XP = S_ring["ring_xp"]
	RING_BREAK = S_ring["ring_break"]
	RING_REPEAT_GOLD = S_ring["ring_repeat_gold"]
	RING_REPEAT_PAID = S_ring["ring_repeat_paid"]
	RING_FAST = S_ring["ring_fast"]
	var S_vigil := GameDB.settings("vigil")
	VIGIL_GOAL = S_vigil["vigil_goal"]
	VIGIL_GOLD = S_vigil["vigil_gold"]
	VIGIL_GLORY = S_vigil["vigil_glory"]
	VIGIL_GLORY_GOAL = S_vigil["vigil_glory_goal"]
	VIGIL_HP = S_vigil["vigil_hp"]
	VIGIL_HP_STEP = S_vigil["vigil_hp_step"]
	VIGIL_HIT = S_vigil["vigil_hit"]
	VIGIL_HIT_STEP = S_vigil["vigil_hit_step"]
	VIGIL_XP = S_vigil["vigil_xp"]
	var S_bounty := GameDB.settings("bounty")
	BOUNTY_BOARD = S_bounty["bounty_board"]
	BOUNTY_ACTIVE = S_bounty["bounty_active"]
	BOUNTY_REFRESH = S_bounty["bounty_refresh"]
	var S_trade := GameDB.settings("trade")
	TRADE_WEALTH = S_trade["trade_wealth"]
	TRADE_SPREAD = S_trade["trade_spread"]
	TRADE_STEP = S_trade["trade_step"]
	TRADE_STOCK = S_trade["trade_stock"]
	TRADE_PERIOD = S_trade["trade_period"]
	TRADE_CART = S_trade["trade_cart"]
	TRADE_CART_SKLAD = S_trade["trade_cart_sklad"]
	TRADE_AMBUSH = S_trade["trade_ambush"]
	TRADE_AMBUSH_UNIT = S_trade["trade_ambush_unit"]
	TRADE_AMBUSH_MAX = S_trade["trade_ambush_max"]
	var S_hunting := GameDB.settings("hunting")
	HUNT_ARROWS = S_hunting["hunt_arrows"]
	HUNT_PASSES = S_hunting["hunt_passes"]
	HUNT_BULLSEYE = S_hunting["hunt_bullseye"]
	FISH_BAIT = S_hunting["fish_bait"]
	FISH_ZONE = S_hunting["fish_zone"]
	var S_tavern := GameDB.settings("tavern")
	DICE_LIMIT = S_tavern["dice_limit"]
	DICE_GAMES = S_tavern["dice_games"]
	DICE_TWELVE = S_tavern["dice_twelve"]
	DICE_GLORY = S_tavern["dice_glory"]
	RUMOR_TIP_TRIPS = S_tavern["rumor_tip_trips"]
	RUMOR_TIP_BONUS = S_tavern["rumor_tip_bonus"]
	var S_trails := GameDB.settings("trails")
	TRAIL_MIN_LEVEL = S_trails["trail_min_level"]
	TRAIL_CHANCE = S_trails["trail_chance"]
	TRAIL_CHANCE_SCOUT = S_trails["trail_chance_scout"]
	TRAIL_START = S_trails["trail_start"]
	TRAIL_STEP = S_trails["trail_step"]
	TRAIL_POINTS = S_trails["trail_points"]
	TRAIL_REACH = S_trails["trail_reach"]
	TRAIL_CACHE_ITEM = S_trails["trail_cache_item"]
	var S_expeditions := GameDB.settings("expeditions")
	EXPEDITION_GOLD = S_expeditions["expedition_gold"]
	EXPEDITION_LEVEL = S_expeditions["expedition_level"]
	EXPEDITION_HERO = S_expeditions["expedition_hero"]
	var S_holidays := GameDB.settings("holidays")
	TOKEN_CHANCE = S_holidays["token_chance"]
	TOKEN_ELITE = S_holidays["token_elite"]
	TOKEN_BOSS = S_holidays["token_boss"]
	TOKEN_GLORY = S_holidays["token_glory"]
	TOKEN_GLORY_SMALL = S_holidays["token_glory_small"]
	var S_escort := GameDB.settings("escort")
	ESCORT_CHANCE = S_escort["escort_chance"]
	ESCORT_MULT = S_escort["escort_mult"]
	ESCORT_WAVES = S_escort["escort_waves"]
	ESCORT_PACK = S_escort["escort_pack"]
	ESCORT_PACK_STEP = S_escort["escort_pack_step"]
	ESCORT_SPEED = S_escort["escort_speed"]
	ESCORT_FEAR = S_escort["escort_fear"]
	ESCORT_HP = S_escort["escort_hp"]
	ESCORT_HP_LVL = S_escort["escort_hp_lvl"]
	ESCORT_TIP = S_escort["escort_tip"]


# ======================= Зручні виклики над таблицями =======================
# Записи заморожені й віддаються без копій: читати їх щокадру — звичайне читання словника.

static var _sources: Array = []  # тексти «звідки слава» в порядку файлу
static var _by_style := {}  # стиль бою → перший суперник із ним


## Ранги слави за порядком (драбина за «rank»): [{"from", "name", "gold", "stone"?}, ...].
static func glory_ranks() -> Array:
	return GameDB.ladder("glory_ranks", "rank")


## Звідки береться слава: рядки підказки в порядку файлу.
static func glory_sources() -> Array:
	if _sources.is_empty():
		for id in GameDB.ids("glory_sources"):
			_sources.append(str(GameDB.row("glory_sources", id)["text"]))
		_sources.make_read_only()
	return _sources


## Суперник у герці ({} — нема).
static func rival(id: String) -> Dictionary:
	return GameDB.row("rivals", id)


## Суперники в порядку файлу.
static func rival_ids() -> Array:
	return GameDB.ids("rivals")


## Перший суперник із цим стилем бою ({} — нема): так бійці сотень огляду беруть вигляд, механіку й прізвиська.
static func style_rival(style: String) -> Dictionary:
	if _by_style.is_empty():
		for id in rival_ids():
			var st := str(rival(id)["style"])
			if not _by_style.has(st):
				_by_style[st] = rival(id)
		_by_style.make_read_only()
	return _by_style.get(style, {})


## Коло герцю (0 — перше), сутичка огляду, коло Кожум'яки: записи драбин за «round».
static func duel_round(i: int) -> Dictionary:
	return GameDB.ladder("duel_rounds", "round")[i]


static func muster_round(i: int) -> Dictionary:
	return GameDB.ladder("muster_rounds", "round")[i]


static func ring_round(i: int) -> Dictionary:
	return GameDB.ladder("ring_rounds", "round")[i]


## Сотня огляду ({} — нема) і сотні в порядку файлу.
static func muster_team(id: String) -> Dictionary:
	return GameDB.row("muster_teams", id)


static func muster_team_ids() -> Array:
	return GameDB.ids("muster_teams")


## Імена бійців огляду (пул «muster_first»).
static func muster_names() -> Array:
	return GameDB.row("name_pools", "muster_first").get("words", [])


## Хто буває в Колі Кожум'яки (пул «ring» у boss_pools.json).
static func ring_pool() -> Array:
	return GameDB.row("boss_pools", "ring").get("bosses", [])


## Місце занять на мапі ({} — нема), усі такі місця в порядку файлу, чи це воно.
static func spot(id: String) -> Dictionary:
	return GameDB.row("spots", id)


static func spot_ids() -> Array:
	return GameDB.ids("spots")


static func is_spot(id: String) -> bool:
	return GameDB.table("spots").has(id)


## Свято ({} — нема) і свята в порядку календаря.
static func holiday(id: String) -> Dictionary:
	return GameDB.row("holidays", id)


static func holiday_ids() -> Array:
	return GameDB.ids("holidays")


## Назва місяця в родовому відмінку (1 — січня).
static func month_gen(month: int) -> String:
	return str(GameDB.row("months", GameDB.ids("months")[month - 1])["gen"])


## Пороги жетонів свята: great, short чи tiny.
static func token_need(scale: String) -> Array:
	return GameDB.row("token_scales", scale)["need"]


## Торг: чи є торг у місті, міста з торгом у порядку файлу, ціна краму в місті відносно базової.
static func has_trade(city: String) -> bool:
	return GameDB.table("trade_cities").has(city)


static func trade_city_ids() -> Array:
	return GameDB.ids("trade_cities")


static func trade_mult(city: String, good: String) -> float:
	return float(GameDB.row("trade_cities", city)["prices"][good])


## Крам ({"name", "base"}) і весь крам у порядку показу.
static func trade_good(id: String) -> Dictionary:
	return GameDB.row("trade_goods", id)


static func trade_good_ids() -> Array:
	return GameDB.ids("trade_goods")


## Звірі й риба: уся таблиця (для кидка за вагою) і один запис.
static func hunt_animals() -> Dictionary:
	return GameDB.table("hunt_animals")


static func animal(id: String) -> Dictionary:
	return GameDB.row("hunt_animals", id)


static func fishes() -> Dictionary:
	return GameDB.table("fish")


static func fish(id: String) -> Dictionary:
	return GameDB.row("fish", id)


## Страва з казана ({} — нема), страви в порядку показу, чи є така.
static func recipe(id: String) -> Dictionary:
	return GameDB.row("recipes", id)


static func recipe_ids() -> Array:
	return GameDB.ids("recipes")


static func is_recipe(id: String) -> bool:
	return GameDB.table("recipes").has(id)


## Суперник у кості ({} — нема) і суперники в порядку показу.
static func dice_rival(id: String) -> Dictionary:
	return GameDB.row("dice_rivals", id)


static func dice_rival_ids() -> Array:
	return GameDB.ids("dice_rivals")


## Знахідки в кінці стежки: уся таблиця (для кидка за вагою) і одна знахідка.
static func trail_kinds() -> Dictionary:
	return GameDB.table("trail_kinds")


static func trail_kind(id: String) -> Dictionary:
	return GameDB.row("trail_kinds", id)


## Похід побратима ({} — нема), походи в порядку показу, чи є такий.
static func expedition(id: String) -> Dictionary:
	return GameDB.row("expeditions", id)


static func expedition_ids() -> Array:
	return GameDB.ids("expeditions")


static func is_expedition(id: String) -> bool:
	return GameDB.table("expeditions").has(id)


## Мандрівник для супроводу ({} — нема) і мандрівники в порядку кидка.
static func escort(id: String) -> Dictionary:
	return GameDB.row("escorts", id)


static func escort_ids() -> Array:
	return GameDB.ids("escorts")


## Ціни краму в місті відносно базової: {крам: множник} ({} — у місті нема торгу).
static func trade_city_prices(city: String) -> Dictionary:
	return GameDB.row("trade_cities", city).get("prices", {})
