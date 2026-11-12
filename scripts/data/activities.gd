extends RefCounted
## Заняття поза сюжетом: герць, огляд, Коло Кожум'яки, розшук, варта, торгівля, полювання, шинок, сліди,
## походи побратимів, слава й рекорди, свята, супровід. Записи — у таблицях data/*.json (docs/data.md,
## «Заняття»), логіка — у службах scripts/game/*_service.gd. Тут — зручні виклики над таблицями й
## числа-правила, які збере етап загальних налаштувань.

const GameDB := preload("res://scripts/core/game_db.gd")

# ======================= Слава =======================
## Слава — мірило козацької честі героя (world.glory). Дають її герць, розшук, варта, полювання.
## Ранги — data/glory_ranks.json, звідки береться — data/glory_sources.json.

# ======================= Герць на майдані =======================
## Суперники — data/rivals.json (ім'я, стиль і механіка бою scripts/mechanics/rival/<стиль>.gd, лист спрайтів,
## порада); кола турніру — data/duel_rounds.json: здоров'я суперника рівня з героєм — скільки секунд чистої шкоди
## еталонного героя цього рівня він тримає, удар — частка здоров'я героя вже після його захисту.
## Вільний герць: поза турніром, до першої поразки. Кожен наступний суперник у серії міцніший.
const FREE_DUEL_SECONDS := 20.0  # скільки секунд шкоди еталонного героя тримає перший суперник
const FREE_DUEL_HIT := 0.11  # частка здоров'я героя за удар першого суперника
const FREE_DUEL_HP_STEP := 0.12  # за кожну перемогу в серії суперник на стільки здоровіший
const FREE_DUEL_HIT_STEP := 0.05  # і на стільки сильніше б'є
const FREE_DUEL_GOLD := 15  # × рівень героя; за серію більше (див. DuelService.free_gold)
const FREE_DUEL_PAID := 3  # скільки перемог на день оплачується
const FREE_DUEL_GLORY := 2  # слава за першу оплачену перемогу дня
## Глядачі на майдані (листи спрайтів; це вигляд, а не дані гри)
const SPECTATORS := ["comp_dzhura", "comp_strilets", "comp_petro", "cossack_sabre", "cossack_pike", "peasant_pike", "comp_znakhar", "comp_oksana", "zaporozhets_sabre", "plastun_pike"]

# ======================= Дошка розшуку =======================
## Ціль — еліта з кількома властивостями, удвічі міцніша. Прізвиська розшукуваної нечисті — у її записі
## («bounty_names» у data/mobs.json).
const BOUNTY_BOARD := 2  # оголошень на дошці міста
const BOUNTY_ACTIVE := 2  # скільки голів можна шукати водночас
const BOUNTY_REFRESH := 6  # через стільки походів дошка оновлюється

# ======================= Гетьманський огляд (Чигирин) =======================
## Тижневі сутички ватаг: герой із побратимами проти сотні. Три сутички, три спроби, смерті нема.
## Сотні — data/muster_teams.json (styles — стилі суперників із герцю; перший — сотник, він виходить у кожній
## сутичці), сутички — data/muster_rounds.json, імена бійців — пул «muster_first» у data/name_pools.json, а
## прізвиська — «nicks» суперника того самого стилю.
const MUSTER_CITY := "chyhyryn"
const MUSTER_MIN_LEVEL := 8
const MUSTER_CAPTAIN := 1.5  # сотник у стільки разів здоровіший

# ======================= Коло Кожум'яки =======================
## Три чудовиська поспіль на Змієвих валах (місце "kolo" на мапі); склад міняється щотижня. Хто буває в
## колі — пул «ring» у data/boss_pools.json, кола — data/ring_rounds.json.
## Сила чудовиськ — від рівня героя: здоров'я — секунди чистої шкоди еталонного героя, удар — частка його живучості
## вже після захисту (за колами: перше, друге, третє). Посіпаки чудовиськ — у пропорції до «звичайного зараженого».
const RING_STAGES := 3  # кіл (стільки ж записів у data/ring_rounds.json)
const RING_CAP := 0.7  # чудовисько не впаде швидше, ніж за цю частку розрахункового часу
const RING_STD_TTK := 1.1
const RING_STD_HIT := 0.035
const RING_XP := 0.3  # досвіду з кола менше: нагорода тут — гаманець і слава
const RING_BREAK := 5.0  # перепочинок між чудовиськами, с
const RING_REPEAT_GOLD := 10  # × рівень: за чудовисько, коли тижневе вже взято
const RING_REPEAT_PAID := 3  # скільки таких на день оплачується
const RING_FAST := 90.0  # швидше за стільки секунд бою — досягнення

# ======================= Місця на мапі (не міста й не місцевості) =======================
## data/spots.json: варта, полювання, рибалка, Коло Кожум'яки; level — з якого рівня героя відкрито.

# ======================= Козацька варта =======================
const VIGIL_GOAL := 300.0  # секунд, які треба вистояти
const VIGIL_GOLD := 5  # гривень × рівень × номер хвилини
const VIGIL_GLORY := 3  # слави за хвилину (до мети)
const VIGIL_GLORY_GOAL := 10  # додатково за повну варту
## Нечисть на варті — частка звичайної мірки рівня героя (Data.enemy_std_hp, enemy_std_dmg): на першій
## хвилині вона вдвічі кволіша за нечисть свого рівня, бо суне юрбою, і щохвилини міцнішає.
## На п'ятій хвилині здоров'я вже 130% мірки, удар 88%.
const VIGIL_HP := 0.5
const VIGIL_HP_STEP := 0.2
const VIGIL_HIT := 0.4
const VIGIL_HIT_STEP := 0.12
const VIGIL_XP := 0.3  # множник досвіду й гривень із ворогів на варті

# ======================= Чумацький шлях (торгівля крамом) =======================
## Крам — data/trade_goods.json (назва й базова ціна одиниці, множиться на «заможність» рівня героя),
## торг у містах — data/trade_cities.json (ціна краму відносно базової: менше 1 — тут його роблять).
const TRADE_WEALTH := 0.15  # ціни ростуть із рівнем героя: +15% за рівень
const TRADE_SPREAD := 0.9  # продаєш на 10% дешевше, ніж тут купують
const TRADE_STEP := 0.06  # кожна продана одиниця збиває ціну на 6%, куплена — піднімає
const TRADE_STOCK := 6  # стільки одиниць кожного краму місто продасть за один торговий день
const TRADE_PERIOD := 3  # торговий день триває стільки походів; потім ціни й запаси оновлюються
const TRADE_CART := 6  # місткість воза; кожен рівень Складу додає TRADE_CART_SKLAD
const TRADE_CART_SKLAD := 4
const TRADE_AMBUSH := 0.1  # шанс нападу на валку дорогою до міста
const TRADE_AMBUSH_UNIT := 0.02  # і ще стільки за кожну одиницю краму (не більше TRADE_AMBUSH_MAX)
const TRADE_AMBUSH_MAX := 0.4

# ======================= Полювання, рибалка й казан =======================
## Провіант (м'ясо, риба, городина) — ресурси героя з data/resources.json («food»). Звірі —
## data/hunt_animals.json, риба — data/fish.json, страви з казана — data/recipes.json (одна страва за раз;
## діє Data.MEAL_TIME секунд бою).
const HUNT_ARROWS := 3
const HUNT_PASSES := 6  # скільки звірів пробіжить галявиною за одне полювання
const HUNT_BULLSEYE := 0.45  # частка радіуса: влучив ближче — «в яблучко»
const FISH_BAIT := 5  # закидів за одну рибалку
const FISH_ZONE := [0.3, 0.75]  # у цій смузі натягу риба йде до берега

# ======================= Шинок: кості й чутки =======================
## Гра «дванадцять»: кидаєш по кості й додаєш очки; понад DICE_LIMIT — перебір. Суперники — data/dice_rivals.json
## (style — як грає, див. TavernService.rival_goes; stake — множник ставки).
const DICE_LIMIT := 12
const DICE_GAMES := 8  # партій на день
const DICE_TWELVE := 1.5  # рівно дванадцять — виграш у півтора раза
const DICE_GLORY := 1  # слава за першу за день перемогу над сотником
## Чутки: скільки походів живе торгова порада й наскільки вона піднімає ціну.
const RUMOR_TIP_TRIPS := 3
const RUMOR_TIP_BONUS := 1.15

# ======================= Сліди на арені =======================
## У місцевості трапляється стежка слідів: іди по ній від точки до точки — наприкінці знахідка
## (data/trail_kinds.json: вага появи й підпис; що вона дає — Combat).
const TRAIL_MIN_LEVEL := 3  # новачкові в перших походах не до слідів (і лігво йому зарано)
const TRAIL_CHANCE := 0.35  # шанс стежки в поході
const TRAIL_CHANCE_SCOUT := 0.6  # пластун помічає сліди частіше (і бачить усю стежку одразу)
const TRAIL_START := 200.0  # як далеко від героя починаються сліди
const TRAIL_STEP := 380.0  # довжина відтинка між точками
const TRAIL_POINTS := 4  # точок на стежці (остання — знахідка)
const TRAIL_REACH := 70.0  # наскільки близько треба підійти до точки
const TRAIL_CACHE_ITEM := 0.45  # шанс речі в схованці

# ======================= Походи побратимів =======================
## Супутника можна відправити у власний похід: він іде сам і повертається зі здобиччю (data/expeditions.json).
## Поки він у поході, в бою його нема.
const EXPEDITION_GOLD := 25  # гривень за одиницю множника на 1-му рівні супутника
const EXPEDITION_LEVEL := 0.15  # приріст здобичі за кожен рівень супутника
const EXPEDITION_HERO := 1.25  # іменні побратими приносять більше

# ======================= Літопис слави: рекорди роду =======================
## Рекорди спільні для всіх персонажів (account.records): data/records.json, порядок файлу — порядок показу.

# ======================= Сезонні свята =======================
## Свята — data/holidays.json (порядок файлу — за календарем, від січня), назви місяців — data/months.json,
## пороги жетонів — data/token_scales.json. Які ключі бонусу вміє гра — HolidayService.
## Жетони: шанс із звичайної нечисті, скільки з еліти й боса.
const TOKEN_CHANCE := 0.08
const TOKEN_ELITE := 2
const TOKEN_BOSS := 5
const TOKEN_GLORY := 15  # слава за найвищу нагороду великого свята
const TOKEN_GLORY_SMALL := 8  # і малого

# ---------- Супровід: завдання міста «проведи мандрівника» (див. EscortService) ----------
## Мандрівники — data/escorts.json.
const ESCORT_CHANCE := 0.22  # частка завдань у дику місцевість, що стають супроводом
const ESCORT_MULT := 1.6  # нагорода проти звичайного завдання
const ESCORT_WAVES := 3  # засідок на шляху
const ESCORT_PACK := 2  # нечисті в засідці: основа й приріст за кожну наступну (4, 6, 8)
const ESCORT_PACK_STEP := 2
const ESCORT_SPEED := 46.0  # крок мандрівника, пікселів за секунду
const ESCORT_FEAR := 250.0  # нечисть ближче — мандрівник стоїть і чекає
const ESCORT_HP := 260.0  # здоров'я мандрівника: основа й приріст за рівень місцевості
const ESCORT_HP_LVL := 45.0
const ESCORT_TIP := 6  # гривень за рівень від вдячного мандрівника, якщо дійшов цілим


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
