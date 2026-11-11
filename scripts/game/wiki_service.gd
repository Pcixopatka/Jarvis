extends RefCounted
## Довідник по грі (вікі). Збирає розділи з таблиць гри й текстів WikiData, тож довідник завжди такий,
## як гра: нова нечисть, місце чи свято з'являється тут саме. Розділ — {"id", "title", "entries"},
## запис — {"title", "sub", "text", "icon": {"sprite"|"map"|"loot": id}, "head": заголовок групи або ""}.
## Ті самі розділи бере екран довідника (UiWiki) і вивантаження в docs/wiki.md (tools/wiki_export.gd).

const Wiki := preload("res://scripts/data/wiki_data.gd")
const Data := preload("res://scripts/data/data.gd")
const Acts := preload("res://scripts/data/activities.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Classes := preload("res://scripts/data/classes.gd")
const Story := preload("res://scripts/data/story.gd")
const Elites := preload("res://scripts/data/elites.gd")
const Status := preload("res://scripts/game/status.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")

static var _cache: Array = []

## Головна властивість слота й назви властивостей речей словами (для розділу «Речі»).
const SLOT_MAIN := {"flat_dmg": "шкода", "hp": "здоров'я", "armor": "захист", "vit": "витривалість", "speed": "швидкість бігу", "skill_power": "сила вмінь"}
const PROP_NAMES := {"str": "сила", "agi": "спритність", "vit": "витривалість", "spi": "характерництво", "dmg_pct": "шкода у відсотках",
	"crit": "шанс критичного удару", "aspd": "швидкість удару", "hp": "здоров'я", "armor": "захист", "regen": "загоєння",
	"lifesteal": "вампіризм", "speed": "швидкість бігу", "xp": "досвід", "skill_power": "сила вмінь", "skill_cd": "швидша перезарядка вмінь",
	"pickup": "радіус збору", "gold": "гривні з нечисті"}


## Перша літера велика.
static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _svc(name: String):
	return load("res://scripts/game/%s.gd" % name)


## Усі розділи (збираються раз за запуск: таблиці гри не змінюються).
static func sections() -> Array:
	if _cache.is_empty():
		for pair in Wiki.SECTIONS:
			_cache.append({"id": pair[0], "title": pair[1], "entries": _entries(pair[0])})
	return _cache


static func index_of(id: String) -> int:
	var list := sections()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0


static func _entries(id: String) -> Array:
	match id:
		"basics": return _basics()
		"events": return _events()
		"classes": return _classes() + _party()
		"skills": return _skills()
		"enemies": return _enemies()
		"bosses": return _bosses()
		"map": return _map()
		"holidays": return _holidays()
		"camp": return _camp()
		"items": return _items()
		"souls": return _souls()
		"rules": return _rules()
	return []


static func _e(title: String, sub: String, text: String, icon: Dictionary = {}, head: String = "") -> Dictionary:
	return {"title": title, "sub": sub, "text": text, "icon": icon, "head": head}


static var _word_re: RegEx = null


## Слова тексту в нижньому регістрі (апостроф лишається всередині слова: «п'є»).
static func _words(text: String) -> Array:
	if _word_re == null:
		_word_re = RegEx.create_from_string("[\\p{L}\\p{N}'’]+")
	var out := []
	for m in _word_re.search_all(text.to_lower()):
		out.append(m.get_string())
	return out


## Пошук по всьому довіднику: [{"section": назва розділу, "entry": запис}], без огляду на великі й малі літери.
## Кожне слово запиту має бути початком якогось слова запису («Вій» не знаходить «свій»).
## Спершу ті, у кого збіг у назві.
static func search(query: String, limit: int = 40) -> Array:
	var qwords := _words(query)
	if qwords.is_empty() or str(" ".join(qwords)).length() < 2:
		return []
	var found := []
	var n := 0
	for s in sections():
		for e in s["entries"]:
			var title_words := _words(str(e["title"]))
			var all_words: Array = title_words + _words(str(e["sub"]) + " " + str(e["text"]))
			var ok := true
			var in_title := 0
			for w in qwords:
				if not all_words.any(func(x): return x.begins_with(w)):
					ok = false
					break
				if title_words.any(func(x): return x.begins_with(w)):
					in_title += 1
			if ok:
				found.append({"section": s["title"], "entry": e, "score": in_title, "n": n})
				n += 1
	found.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["n"] < b["n"]))
	var out := []
	for f in found.slice(0, limit):
		out.append({"section": f["section"], "entry": f["entry"]})
	return out


# ---------------- Розділи ----------------

static func _basics() -> Array:
	var out := []
	for b in Wiki.BASICS:
		out.append(_e(b["title"], "", b["text"]))
	out.append(_e("Екран героя й журнал", "", "Кнопка «Персонаж» відкриває екран героя. На вкладці «Герой» усе одразу: зведення сили, вдягнене шістьма клітинками, очки характеристик із кнопками «+», докладні показники й торба сіткою. Колір клітинки показує рідкість, число в кутку — заточку, зірка — золоту річ, ромб — гніздо для душі. Зелена стрілка в кутку клітинки означає, що річ сильніша за вдягнену, а кнопка «Вдягнути найкраще» сама вдягає найсильніше в кожну клітинку. Сильніша та річ, з якою герой загалом міцніший: рахуються шкода за секунду й запас живучості, а сила золотої речі додає ще %d%%. Торкнись клітинки, щоб побачити картку речі й рядок «Сила героя з цією річчю». Дії стоять над карткою: «Вдягнути» чи «Зняти», «Викинути на землю» і «Знищити». На вкладці «Журнал» зібрано все, що зараз треба зробити: історія, завдання побратимів, завдання міст із нагородами, розшук і події. Угорі вся гілка історії розділами: пройдені з галочкою, нинішній із зіркою, решта попереду. Гілка лишається там і після фіналу. Зелена рамка означає, що завдання вже можна здати. Торкнись завдання в журналі чи події на вкладці «Події», і мапа покаже це місце: мету, а для виконаного завдання місто, де його здати. У бою мапа не відкриється, гра лише назве місце. На вкладці «Вміння» дерево показано значками: число під значком — ранг, лінії ведуть від вміння, яке треба вивчити спершу. Торкнись значка, щоб побачити картку й вивчити. Праворуч кнопки бою: вибери вивчене активне вміння, і кнопки, куди його можна поставити, засвітяться зеленим." % roundi(load("res://scripts/game/power.gd").UNIQUE_WORTH * 100.0)))
	out.append(_e("Порадник: що робити далі", "кнопка «Далі» на мапі", "Не знаєш, куди йти? Унизу мапи стоїть кнопка «Далі» з головною порадою. Торкнись її, і мапа покаже потрібне місце або відкриється потрібна вкладка. Усі поради зібрано на вкладці «Журнал», у розділі «Що робити зараз»: до %d порад від найважливішої. Порядок такий: здати виконане, облоги й події з лічильником походів, історія, вільні очки, кращі речі в торбі, порада зміцнити спорядження (коли нечисть твого рівня тобі смертельна), нагороди за виклики, розшук, завдання міст, справи тижня й дня. Якщо нічого з цього нема, порадник пошле в місцевість твого рівня й до дошки завдань. Кнопка «?» біля масштабу пояснює позначки на мапі. Коли героєві відкривається нове заняття, гра каже про це на мапі." % load("res://scripts/game/guide_service.gd").MAX))
	var Way = load("res://scripts/game/way_service.gd")
	var way_lines := []
	for i in Way.Path.STEPS.size():
		var st: Dictionary = Way.Path.STEPS[i]
		way_lines.append("%d. %s. Нагорода: %s." % [i + 1, st["title"], Way.reward_text(st)])
	out.append(_e("Шлях козака", "ланцюжок перших цілей", "Ланцюжок із %d цілей, що по черзі вчить усьому в грі. Нинішній крок стоїть угорі вкладки «Журнал»: що зробити, як саме й яка нагорода. Виконав умову, і кнопка «Забрати нагороду» відкриє наступний крок. Бувалий герой забирає все вже зроблене одним дотиком. Порадник і кнопка «Далі» на мапі теж ведуть до наступного кроку.\n%s" % [Way.total(), "\n".join(way_lines)]))
	var QS = load("res://scripts/game/quick_service.gd")
	out.append(_e("Швидкий похід", "за перегляд реклами", "Місце, яке ти вже пройшов %d рази, можна зачистити миттю, без бою. На панелі місця з'являється кнопка «Швидкий похід за рекламу»: переглянь рекламу, і герой одразу дістане досвід, гривні, речі й ресурси, як за звичайний похід. Здобич рахується тими самими шансами, що й у бою, реклама «×2 здобичі» й свята на неї діють. Рідкісного з босів тут нема: золоті речі, артефакти, камені долі й душі дає лише справжній бій. Зараза, ніч, розшук і скарб у швидкому поході теж не діють, історія не просувається. Завдання міст на нечисть і печери він зараховує, а світ рахує його як похід: події й облоги чекають на один похід менше. На день дається %d швидких походів. Працює для диких місцевостей і печер, не сильніших за героя." % [QS.MIN_CLEARS, QS.PER_DAY]))
	out.append(_e("Фільтр автопідбору", "щоб не збирати мотлох", "У паузі, на привалі й у головному меню є кнопка «Автопідбір». Там чотири рідкості: %s. Вимкнену рідкість герой сам не підбирає: така річ лежить на землі тьмяна. Коли йдеш із місця, усе, що фільтр не взяв, продається за ціною крамниці, тож гривні не пропадають. Золоті речі й артефакти беруться завжди. Якщо передумав, у бою відкрий «Автопідбір» і натисни «Підібрати все, що лежить». Річ, яку ти сам викинув із торби, фільтр не чіпає: стань на неї, і вона підніметься. Швидкий похід теж слухає фільтр." % ", ".join(Data.RARITY_PLURAL).to_lower()))
	out.append(_e("Повна торба", "здобич не зникає", "Коли в торбі нема місця, річ не підбирається й не продається: вона лежить на землі далі. Звільни місце й підійди до неї знову. На екрані героя торкнись непотрібної речі. «Знищити» прибирає її назавжди, другий дотик підтверджує. «Викинути на землю» кладе річ поруч, це можна лише в бою. Викинута річ сама назад не летить: щоб підняти, стань на неї. Душа зі знищеної чи викинутої речі вертається в торбинку. Золота річ і артефакт лягають понад місце. З автопродажем звичайні речі при повній торбі продаються одразу. Коли йдеш із місця, усе, що лишилось лежати й не вмістилось, продається за ціною крамниці. Зілля при повному запасі теж лежить і чекає, а перед виходом іде за півціни."))
	out.append(_e("Гортання списків", "", "Довгий список гортається пальцем із будь-якої точки екрана: веди просто по картках, кнопках чи клітинках, порожнє місце шукати не треба. Короткий дотик без руху натискає кнопку, як і раніше. Після відпускання список ще трохи їде сам."))
	# Складність, смерть і шлях до останнього рівня: числа з балансу
	var full: int = int(Data.ENEMY_CURVE[Data.ENEMY_CURVE.size() - 1][0])
	var FarS = load("res://scripts/game/far_service.gd")
	out.append(_e("Складність", "гра сувора", "Сила нечисті залежить лише від її рівня й не дивиться на твоє спорядження. За мірку взято героя того самого рівня в середньому спорядженні. На 1-му рівні він рубає звичайного зараженого %s с, а удар зараженого забирає в нього %s%% запасу живучості. З %d-го рівня це вже %s с і %s%%. Решта нечисті лишається у своїй пропорції до зараженого, а еліта, боси й чудовиська множать ці числа далі. Тому в середньому спорядженні нечисть свого рівня небезпечна, у доброму з нею б'ються із зіллям напоготові, а вільно рубати її виходить лише в найкращому: легендарні речі, заточені до +%d, душі в гніздах, артефакти й клейноди роду. Перші рівні м'якші, щоб новачок устиг навчитися. На панелі місця на мапі є рядок «Тобі тут»: легко, під силу, важко чи смертельно. Він рахується з твого спорядження: скільки секунд ти рубаєш звичайну нечисть цього місця й скільки її ударів витримаєш. У Глибинах нечисть не буває слабшою за %d%% сили нечисті твого рівня, у Башті за %d%%: мілкіша глибина чи нижчий поверх легші, але не прогулянка." % [_num(Data.enemy_ttk(1)), _num(Data.enemy_hit(1) * 100.0), full, _num(Data.enemy_ttk(full)), _num(Data.enemy_hit(full) * 100.0), Data.MAX_UPGRADE, roundi(FarS.DEPTH_FLOOR * 100.0), roundi(FarS.TOWER_FLOOR * 100.0)], {}, "Правило"))
	out.append(_e("Смерть", "ціна поразки", "Загинувши в бою, герой отямлюється в останньому місті. Він утрачає %s%% гривень і %s%% досвіду, потрібного на поточний рівень. Рівень від цього не падає, а досвід не опускається нижче нуля. До %d-го рівня досвід не втрачається. Герць, варта, Коло Кожум'яки й гетьманський огляд без смерті: звідти просто виносять, і досвід цілий." % [_num(Data.DEATH_GOLD_LOSS * 100.0), _num(Data.DEATH_XP_LOSS * 100.0), Data.DEATH_XP_FROM], {}, "Правило"))
	var top: int = Data.Classes.BASE_LEVEL_MAX
	out.append(_e("Дорога до %d-го рівня" % top, "що вище, то довше", "Кожен наступний рівень коштує більше досвіду. З 10-го на 11-й треба %s, з 30-го на 31-й %s, з 60-го на 61-й %s, а з %d-го на %d-й аж %s. Досвід дає нечисть і завдання, і що вищий рівень нечисті, то більше з неї досвіду. Тому на високих рівнях ходи туди, де нечисть твого рівня: у далекі краї, Глибини й Башту. Що краще спорядження, то швидше падає нечисть і швидше росте герой. Рахуй на десятки годин до %d-го рівня." % [_big(Data.xp_for_level(10)), _big(Data.xp_for_level(30)), _big(Data.xp_for_level(60)), top - 1, top, _big(Data.xp_for_level(top - 1)), top], {}, "Правило"))
	# Запас сил: числа беруться з балансу, тож довідник не відстає від гри
	out.append(_e("Запас сил", "", "Здоров'я й наснага не вічні. Вампіризм лікує лише від справді завданої шкоди й не більш як %s%% здоров'я за секунду. Влучний удар дає трохи наснаги, але швидкі удари не дають її більше за секунду. Захист гасить щонайбільше %d%% удару. Бос б'є в %s раза сильніше за рядового свого виду й має в %s разів більше здоров'я. Тому бери з собою зілля: воно лікує %d%% здоров'я й потрібне на будь-якому рівні." % [_num(Data.LIFESTEAL_MAX_HPS * 100.0), roundi(Data.ARMOR_CAP * 100.0), _num(Data.BOSS_DMG_MULT), _num(Data.BOSS_HP_MULT), roundi(Data.POTION_HEAL * 100.0)]))
	return out


static func _level_text(lvl: int) -> String:
	return "від початку" if lvl <= 0 else "з %d-го рівня" % lvl


static func _events() -> Array:
	var out := []
	var Far = load("res://scripts/game/far_service.gd")
	out.append(_e("Сила нечисті в подіях", "рівень героя", "У подіях нечисть підтягується до героя: її рівень не нижчий за твій, а сила не менша за %d%% звичайної сили нечисті твого рівня. Так у набігах, облогах, на валках, у полоні, біля пораненого, у супроводі й у сутичці з розшукуваною нечистю, сторожем скарбу чи лігвом на стежці. Уночі нечисть на %d%% лютіша, а в полі її рівень, досвід і здобич підтягуються до твого рівня. Те, що ти борониш, міцнішає разом із нечистю. Новачкам події не важчають: правило вмикається з %d-го рівня героя й набирає повну силу на %d-му. Від спорядження сила нечисті не залежить, тож краще вдягненому героєві легше." % [roundi(Far.EVENT_FLOOR * 100.0), roundi((Far.NIGHT_MULT - 1.0) * 100.0), Far.EVENT_FROM, Far.EVENT_FULL], {}, "Правило"))
	for k in Wiki.EVENT_KINDS:
		var head: String = k[1]
		for e in Wiki.EVENTS:
			if e["kind"] != k[0]:
				continue
			out.append(_e(e["name"], "%s • %s" % [e["where"], _level_text(int(e["level"]))], "%s\nНагорода: %s" % [e["text"], e["reward"]], {"map": e["icon"]}, head))
			head = ""
	return out


static func _weapon_names(list: Array) -> String:
	var names := []
	for w in list:
		names.append(str(Data.WEAPON_TYPES.get(w, {}).get("name", w)).to_lower())
	return ", ".join(names)


static func _classes() -> Array:
	var out := []
	var tier_head := {0: "Початок", 1: "Дороги", 2: "Спеціалізації"}
	var last_tier := -1
	for cls in Classes.CLASSES:
		var C: Dictionary = Classes.CLASSES[cls]
		var tier := int(C["tier"])
		var parts := ["зброя: " + _weapon_names(C["weapons"])]
		if C.has("where"):
			parts.append("посвята: " + Data.place_name(str(C["where"])))
		if C.has("mentor"):
			parts.append("наставник: " + str(Story.NPCS.get(C["mentor"], {}).get("name", C["mentor"])))
		var actives := []
		for b in Classes.TREES.get(cls, []):
			for n in b["nodes"]:
				if n.get("active", false):
					actives.append(n["name"])
		var text: String = C["desc"]
		if not actives.is_empty():
			text += "\nВміння-кнопки: " + ", ".join(actives) + "."
		text += "\nЗдоров'я ×%s, шкода ×%s, наснага ×%s. Майстерність до %d-го рівня." % [_num(C["hp_mult"]), _num(C["dmg_mult"]), _num(C["mana_mult"]), int(C["job_max"])]
		if not C["next"].is_empty():
			var nx := []
			for n in C["next"]:
				nx.append(Classes.CLASSES[n]["name"])
			text += "\nДалі: " + ", ".join(nx) + "."
		out.append(_e(C["name"], " • ".join(parts), text, {"sprite": _class_sprite(cls)}, tier_head[tier] if tier != last_tier else ""))
		last_tier = tier
	return out


static func _class_sprite(cls: String) -> String:
	var Gfx = load("res://scripts/world/gfx.gd")
	for id in ["plain_" + cls, cls + "_sabre", cls + "_staff", cls]:
		if Gfx.has(id):
			return id
	return "cossack"


## Велике число з пробілами між розрядами: 1 234 567.
static func _big(v: int) -> String:
	var t := str(v)
	var out := ""
	while t.length() > 3:
		out = " " + t.right(3) + out
		t = t.left(t.length() - 3)
	return t + out


static func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else ("%.2f" % f).rstrip("0").replace(".", ",")


## Де живе нечисть: назви місць, у яких вона трапляється.
static func _homes(kind: String) -> Array:
	var out := []
	for id in Data.LOCATIONS:
		if kind in Data.LOCATIONS[id]["enemies"]:
			out.append(str(Data.LOCATIONS[id]["name"]))
	return out


static func _probe(kind: String, boss: bool) -> Dictionary:
	var e = load("res://scripts/entities/enemy.gd").new()
	e.setup(kind, 1, boss)
	var out := {"hp": e.max_hp, "speed": e.speed, "dmg": e.damage, "ranged": e.ranged}
	e.free()
	return out


static func _enemies() -> Array:
	var out := []
	var Enemy = load("res://scripts/entities/enemy.gd")
	for kind in Wiki.ENEMY_ORDER:
		var W: Dictionary = Wiki.ENEMIES[kind]
		var pr := _probe(kind, false)
		var traits := []
		traits.append("здоров'я " + ("мале" if pr["hp"] < 60.0 else ("велике" if pr["hp"] > 120.0 else "середнє")))
		traits.append("повільний" if pr["speed"] < 90.0 else ("швидкий" if pr["speed"] > 145.0 else "звичайний на хід"))
		if pr["ranged"]:
			traits.append("б'є здалеку")
		var st: String = Enemy.HIT_STATUS.get(kind, "")
		if st != "":
			traits.append("удар: " + str(Status.INFO[st]["name"]).to_lower())
		var homes := _homes(kind)
		var where := ", ".join(homes.slice(0, 5)) + (" та інші" if homes.size() > 5 else "")
		var text: String = W["text"] + "\n" + _cap(", ".join(traits)) + ".\nПорада: " + W["tip"]
		out.append(_e(Data.ENEMY_NAMES[kind], ("Живе: " + where) if where != "" else "", text, {"sprite": kind}))
	return out


static func _boss_where(kind: String) -> Array:
	var out := []
	for id in Data.LOCATIONS:
		var L: Dictionary = Data.LOCATIONS[id]
		if L.get("boss", "") == kind and not L.get("endless", false):
			out.append(str(L["name"]))
	if kind in _svc("tower_service").SUPER_BOSSES:
		out.append("Башта Кощія (супербос)")
	if kind in Acts.RING_POOL:
		out.append("Коло Кожум'яки")
	if kind in _svc("depth_service").BOSSES:
		out.append("Глибини зарази")
	return out


static func _bosses() -> Array:
	var out := []
	var phase2 := ["koshchii", "putinoid", "baba_yaha", "solovei", "lykho", "oprychnyk", "vidma", "vii", "morskyi_tsar", "shubin", "bila_pani", "pushkar", "lisovyi_did", "idolyshche", "karachun"]
	for kind in Wiki.BOSS_ORDER:
		var W: Dictionary = Wiki.BOSSES[kind]
		var text: String = W["text"]
		if kind in phase2:
			text += " На половині здоров'я лютішає й кличе підмогу."
		var stone: Array = _svc("stone_service").FIRST_KILL.get(kind, [])
		if not stone.is_empty():
			var names := []
			for sid in stone:
				names.append(_svc("stone_service").NAMES[sid])
			text += "\nПерша перемога: " + ", ".join(names) + "."
		text += "\nПорада: " + W["tip"]
		# Змія малюємо кодом (у нього нема листа спрайтів), тож у довіднику — його значок із мапи
		var icon := {"sprite": kind} if load("res://scripts/world/gfx.gd").has(kind) else {"map": "serpent"}
		out.append(_e(Data.BOSS_NAMES[kind], "Де: " + ", ".join(_boss_where(kind)), text, icon))
	return out


static func _loc_entry(id: String, head: String) -> Dictionary:
	var L: Dictionary = Data.LOCATIONS[id]
	var lvl := ("%d+, росте з героєм" % int(L["level"])) if L.get("scale", false) else str(L["level"])
	var sub := ""
	if L.get("tower", false):
		sub = "Башта • з %d-го рівня героя" % int(_svc("tower_service").OPEN_LEVEL)
	elif L.get("endless", false):
		sub = "Печера без дна • після сюжету"
	elif L["type"] == "dungeon":
		sub = "Печера • %d кімнат • бос: %s • рівень %s" % [int(L["rooms"]), Data.BOSS_NAMES[L["boss"]], lvl]
	else:
		sub = "Дика місцевість • рівень %s" % lvl
	var foes := []
	for e in L["enemies"]:
		foes.append(Data.ENEMY_NAMES[e])
	return _e(L["name"], sub, "%s\nНечисть: %s." % [L["desc"], ", ".join(foes)], {"map": _map_icon(L)}, head)


## Той самий значок, що й на мапі (world_map.gd _loc_icon).
static func _map_icon(L: Dictionary) -> String:
	if L.has("icon"):
		return str(L["icon"])
	if L.get("tower", false):
		return "tower"
	if L["type"] == "dungeon":
		return "skull" if L["biome"] == "plague" else "cave"
	return {"forest": "tree", "mountain": "mountain", "swamp": "swamp", "river": "wave", "village": "hut", "sand": "dune", "snow": "pine"}.get(L["biome"], "sabres")


static func _city_entry(id: String, head: String) -> Dictionary:
	var C: Dictionary = Data.CITIES[id]
	var parts := ["Місто", "завдання %d-го рівня" % int(C["level"])]
	if Acts.TRADE_CITIES.has(id):
		parts.append("торг")
	if id == "sich":
		parts.append("майдан")
	if id == Acts.MUSTER_CITY:
		parts.append("огляд")
	for cls in Classes.CLASSES:
		if Classes.CLASSES[cls].get("where", "") == id and Classes.CLASSES[cls].has("mentor"):
			parts.append("наставник")
			break
	return _e(C["name"], " • ".join(parts), C["desc"], {"map": "castle"}, head)


static func _map() -> Array:
	var out := []
	# Землі сюжету: міста й місця без краю, від слабших до сильніших
	var cities := []
	var locs := []
	for id in Data.CITIES:
		if not Data.CITIES[id].has("region"):
			cities.append(id)
	for id in Data.LOCATIONS:
		if not Data.LOCATIONS[id].has("region"):
			locs.append(id)
	cities.sort_custom(func(a, b): return int(Data.CITIES[a]["level"]) < int(Data.CITIES[b]["level"]))
	locs.sort_custom(func(a, b): return int(Data.LOCATIONS[a]["level"]) < int(Data.LOCATIONS[b]["level"]))
	var head := "Землі сюжету"
	for id in cities:
		out.append(_city_entry(id, head))
		head = ""
	out.append(_e(Camp.CAMP["name"], "Твій хутір біля Січі", "Будівлі, скриня, город і клейноди роду, спільні для всіх твоїх героїв.", {"map": "camp"}))
	for id in locs:
		out.append(_loc_entry(id, ""))
	for sid in Acts.SPOTS:
		var S: Dictionary = Acts.SPOTS[sid]
		out.append(_e(S["name"], "Місце заняття • з %d-го рівня" % int(S["level"]), S["desc"], {"map": S["icon"]}))
	# Далекі краї
	for r in Data.REGION_ORDER:
		var R: Dictionary = Data.REGIONS[r]
		head = "%s: %s" % [R["name"], R["desc"]]
		var p: Dictionary = _svc("far_service").places(r)
		for id in p["cities"]:
			out.append(_city_entry(id, head))
			head = ""
		var rl: Array = p["fields"] + p["dungeons"]
		rl.sort_custom(func(a, b): return int(Data.LOCATIONS[a]["level"]) < int(Data.LOCATIONS[b]["level"]))
		for id in rl:
			out.append(_loc_entry(id, head))
			head = ""
	return out


static func _holidays() -> Array:
	var out := []
	var HS = _svc("holiday_service")
	var dates := {}
	for row in HS.calendar():
		dates[row["id"]] = row["dates"]
	for id in Acts.HOLIDAY_ORDER:
		var H: Dictionary = Acts.HOLIDAYS[id]
		var great: bool = HS.rank(id) == "great"
		out.append(_e(("★ " if great else "") + str(H["name"]), "%s • %s свято" % [dates.get(id, ""), "велике" if great else "мале"],
			"%s\nБонус: %s.\nЖетони: %s." % [H["desc"], H["bonus_text"], H["tokens"]], {"loot": "tok_" + id}))
	return out


static func _cost_text(c: Dictionary) -> String:
	var parts := ["%d грн" % int(c.get("gold", 0))]
	for r in Camp.RESOURCES:
		if int(c.get(r, 0)) > 0:
			parts.append("%s %d" % [str(Camp.RESOURCES[r]).to_lower(), int(c[r])])
	return ", ".join(parts)


static func _camp() -> Array:
	var out := []
	var head := "Будівлі"
	for id in Camp.BUILD_ORDER:
		var B: Dictionary = Camp.BUILDINGS[id]
		var lines := []
		for i in B["levels"].size():
			var L: Dictionary = B["levels"][i]
			lines.append("%d. %s (%s)" % [i + 1, L["text"], _cost_text(L)])
		out.append(_e(B["name"], "рівнів: %d" % B["levels"].size(), "%s\n%s" % [B["desc"], "\n".join(lines)], {"map": "hut"}, head))
		head = ""
	head = "Город"
	for id in Camp.CROP_ORDER:
		var C: Dictionary = Camp.CROPS[id]
		out.append(_e(C["name"], "росте %s год • насіння %d грн" % [_num(C["hours"]), int(C["seed"])], _cap(str(C["desc"])) + ".", {"loot": "herbs" if id == "herbs" else ("veg" if id == "veg" else "khmil")}, head))
		head = ""
	head = "Зілляварня"
	for id in Camp.BREW:
		var Bw: Dictionary = Camp.BREW[id]
		var timed: bool = id in ["strength", "antiplague"]
		var need := "трави %d" % int(Bw["herbs"]) + ((", залізо %d" % int(Bw["iron"])) if int(Bw["iron"]) > 0 else "")
		out.append(_e(Bw["name"], "зілляварня %d-го рівня • %s" % [int(Bw["level"]), need], str(Bw["desc"]) + ((". Діє %d хвилин бою." % int(Data.BREW_TIME / 60.0)) if timed else "."), {"loot": "mana" if id == "mana" else "potion"}, head))
		head = ""
	head = "Казан"
	for id in Acts.RECIPE_ORDER:
		var R: Dictionary = Acts.RECIPES[id]
		var need := []
		for k in R["need"]:
			need.append("%s %d" % [str(Camp.res_name(k)).to_lower(), int(R["need"][k])])
		out.append(_e(R["name"], ", ".join(need), "%s на %d хвилин бою. Та сама страва додає час, інша замінює попередню." % [R["desc"], int(Data.MEAL_TIME / 60.0)], {"loot": "meat"}, head))
		head = ""
	out.append(_e("Пасіка", "мед накопичується до %d годин" % int(Camp.PASIKA_CAP_HOURS), "Мед продається сам: %s грн на годину за рівнями пасіки, більше з рівнем героя. Накопичується, навіть коли гра закрита." % " / ".join(PackedStringArray(Camp.PASIKA_RATE.slice(1).map(func(x): return str(x))))))
	out.append(_e("Скриня", "спільна для всіх героїв", "Сюди кладуть гривні, речі й камені долі, щоб забрати іншим персонажем. Місць %d, кожен рівень складу додає ще %d." % [int(_svc("account").CHEST_SIZE), int(_svc("account").CHEST_PER_SKLAD)], {"map": "chest"}))
	head = "Клейноди роду"
	var KS = _svc("kleinod_service")
	var total := 0
	for g in Camp.KLEINOD_GOLD:
		total += int(g)
	for id in Camp.KLEINOD_ORDER:
		var K: Dictionary = Camp.KLEINODY[id]
		out.append(_e(K["name"], "п'ять ступенів • ресурс: %s" % str(Camp.res_name(K["res"])).to_lower(),
			"%s\nКожен ступінь: %s, на п'ятому %s. Ступені коштують %s грн, разом %d грн." % [K["desc"], KS.bonus_text(id, 1), KS.bonus_text(id, 5),
				", ".join(PackedStringArray(Camp.KLEINOD_GOLD.map(func(x): return str(x)))), total], {"loot": "kl_" + id}, head))
		head = ""
	var SS = _svc("stone_service")
	for sid in Camp.STONE_PRICES:
		out.append(_e(SS.NAMES[sid], "у скарбника за %d грн" % int(Camp.STONE_PRICES[sid]), Camp.STONE_TEXT[sid], {"loot": "stone_" + sid}, "Скарбник" if sid == Camp.STONE_PRICES.keys()[0] else ""))
	return out


static func _items() -> Array:
	var out := []
	var slots := []
	for s in Data.SLOTS:
		slots.append("%s (%s)" % [str(Data.SLOT_NAMES[s]).to_lower(), SLOT_MAIN.get(Data.SLOT_PRIMARY[s], "")])
	out.append(_e("Слоти", "шість речей на герої", "Вдягати можна: " + ", ".join(slots) + ". У дужках — головна властивість слота.", {}, "Спорядження"))
	for w in Data.WEAPON_TYPES:
		var W: Dictionary = Data.WEAPON_TYPES[w]
		out.append(_e(W["name"], "зброя", "%s. Шкода ×%s, швидкість ×%s, довжина ×%s." % [W["hint"], _num(W["dmg"]), _num(1.0 / float(W["cd"])), _num(W["range"])]))
	var rar := []
	for i in Data.RARITY_MAX_RANDOM + 1:
		rar.append("%s (%d властив.)" % [Data.RARITY_NAMES[i], i])
	out.append(_e("Рідкість", "колір назви речі", "Від звичайної до легендарної: " + ", ".join(rar) + ". Що рідкісніша річ, то більше в неї властивостей і дорожча вона в продажу."))
	var props := []
	for k in Data.AFFIX_POOL:
		props.append(PROP_NAMES.get(k, k))
	out.append(_e("Властивості", "що буває на речах", _cap(", ".join(props)) + "."))
	var ch := []
	for i in Data.SHARPEN_CHANCE.size():
		ch.append("+%d: %d%%" % [i + 1, roundi(float(Data.SHARPEN_CHANCE[i]) * 100.0)])
	out.append(_e("Заточка", "коваль у місті й кузня на хуторі", "Кожен рівень заточки дає +%d%% до всіх бонусів речі, найвища заточка +%d. Шанс успіху: %s. З +%d невдача знижує заточку на 1, якщо в тебе нема безпечної заточки. Можна точити й без ризику за потрійну ціну." % [roundi(Data.UPGRADE_BONUS * 100), Data.MAX_UPGRADE, ", ".join(ch), Data.SHARPEN_RISK_FROM], {}, "Коваль і кузня"))
	var CrS = _svc("craft_service")
	var tiers := []
	for i in CrS.TIER_NAMES.size():
		tiers.append("%s (кузня %d%s)" % [CrS.TIER_NAMES[i], int(CrS.TIER_KUZNIA[i]), (", трофеїв %d" % int(CrS.TIER_TROPHY[i])) if int(CrS.TIER_TROPHY[i]) > 0 else ""])
	out.append(_e("Кування", "кузня на хуторі", "Можна викувати будь-яку зброю чи одяг свого рівня: " + ", ".join(tiers) + ". Перекування міняє одну властивість. Переплавка (кузня 2) дає залізо."))
	var CR = load("res://scripts/game/craft_service.gd")
	var probe := {"ilvl": 0, "rarity": 3}
	out.append(_e("Оновлення речі", "кузня третього рівня", "Улюблену річ можна підняти до свого рівня: властивості ті самі, сила як у речі вищого рівня, заточка, гніздо й душа лишаються. Кожен рівень речі коштує окремо й щораз дорожче: ціна росте як квадрат рівня, від першого ж рівня. Для легендарної речі рівень 5 коштує %s грн, рівень 20 — %s, рівень 50 — %s, рівень 75 — %s, а рівень 99 — %s грн. До гривень ідуть залізо й трофеї, їх теж треба більше на вищих рівнях. Дешевша якість коштує менше: звичайна %d%% цієї ціни, добротна %d%%, рідкісна %d%%. Золота річ дорожча в півтора раза. Можна підняти річ на один рівень або одразу до свого: тоді ціни всіх рівнів складаються." % [
		_num(CR.renew_step(probe, 5)["gold"]), _num(CR.renew_step(probe, 20)["gold"]), _num(CR.renew_step(probe, 50)["gold"]), _num(CR.renew_step(probe, 75)["gold"]), _num(CR.renew_step(probe, 99)["gold"]),
		roundi(float(CR.RENEW_RARITY[0]) * 100.0), roundi(float(CR.RENEW_RARITY[1]) * 100.0), roundi(float(CR.RENEW_RARITY[2]) * 100.0)]))
	var SS = _svc("stone_service")
	out.append(_e(SS.NAMES["zabuttia"], "камінь долі", Camp.STONE_TEXT["zabuttia"] + " Подарунки сюжету лишаються.", {"loot": "stone_zabuttia"}, "Камені долі"))
	out.append(_e(SS.NAMES["alatyr"], "камінь долі", Camp.STONE_TEXT["alatyr"] + " Козак може стати Волхвом і навпаки, спеціалізація — іншою спеціалізацією своєї гілки.", {"loot": "stone_alatyr"}))
	out.append(_e("Де взяти камені", "", "Рідко падають із босів, перша перемога над сюжетним босом дає камінь напевно. Ще — нагороди рангів слави, великих свят і Башти, а в скарбника на хуторі — за гривні."))
	out.append(_e("Продаж", "крамниця в місті", "Речі продаються в крамниці, кілька разом — кнопками «Продати звичайні» й далі. Під час ярмарку продаж удвічі дорожчий. Можна ввімкнути автопродаж звичайних речей, коли торба повна."))
	return out + _uniques() + _artifacts()


## Одним рядком: опис із таблиць часто розбито на рядки для вузьких карток.
static func _line(text: String) -> String:
	return " ".join(str(text).split("\n"))


## Назва вміння для довідника: якщо така сама є в іншому дереві чи в Загартуванні, додаємо, чиє воно.
static func skill_title(owner: String, name: String, counts: Dictionary) -> String:
	return "%s (%s)" % [name, owner] if int(counts.get(name, 0)) > 1 else name


## Вміння всіх класів за деревами й Загартування за гілками.
static func _skills() -> Array:
	var SkillInfo = load("res://scripts/data/skill_info.gd")
	var out := []
	var counts := {}
	for cls in Classes.TREES:
		for br in Classes.TREES[cls]:
			for node in br["nodes"]:
				counts[node["name"]] = int(counts.get(node["name"], 0)) + 1
	for br in Data.PERK_BRANCHES:
		for tier in br["tiers"]:
			for perk in tier:
				counts[perk["name"]] = int(counts.get(perk["name"], 0)) + 1
	out.append(_e("Дерева вмінь", "у кожного класу своє", "У кожного класу своє дерево з кількох гілок. Деякі вміння вимагають уже вивченого попереднього. Активні вміння коштують наснагу й мають перезарядку, пасивні діють завжди. У бою на панелі до трьох атак і до п'яти підсилень: набір обирають у вкладці «Вміння» на екрані героя. Вивчені вміння селянина лишаються й після вибору дороги. Очки вмінь можна вкладати в дерево нинішнього класу й у пройдені дерева своєї дороги: наприклад, Запорожець довчає вміння Козака й Селянина. Перемикач дерев ліворуч показує, скільки рангів у кожному вже вивчено. Вміння чужої дороги й сусідньої спеціалізації вчити не можна. Камінь забуття вертає очки з усіх дерев дороги.", {}, "Як це працює"))
	out.append(_e("Загартування", "спільне для всіх класів", "Дерево пасивних вмінь, однакове для всіх: очко за кожні %d рівні героя. Гілок три: %s. У гілці кілька ярусів, і щоб відкрити наступний, треба вкласти в гілку по %d очка за кожен попередній ярус." % [Classes.HARDEN_EVERY, ", ".join(Data.PERK_BRANCHES.map(func(b): return b["name"])), Data.PERK_TIER_STEP]))
	for cls in Classes.TREES:
		var cname: String = str(Classes.CLASSES[cls]["name"])
		for br in Classes.TREES[cls]:
			var first := true
			for node in br["nodes"]:
				var id: String = node["id"]
				var sub := "пасивне • рангів %d" % int(node["max"])
				var text := _line(node["desc"]) + "."
				if node.get("active", false):
					sub = "%s • наснага %d • перезарядка %s с • рангів %d" % ["підсилення" if SkillInfo.KIND.get(id, "attack") == "buff" else "атака", int(node.get("cost", 0)), _num(float(Classes.COOLDOWNS.get(id, 0.0))), int(node["max"])]
					text = str(SkillInfo.WHAT.get(id, "")) + " " + text
					if str(SkillInfo.SCALES.get(id, "—")) != "—":
						text += " Росте від: %s." % str(SkillInfo.SCALES[id]).to_lower()
				var need := []
				for r in node.get("req", {}):
					for other in br["nodes"]:
						if other["id"] == r:
							need.append("%s %d" % [other["name"], int(node["req"][r])])
				if not need.is_empty():
					text += " Потрібно: %s." % ", ".join(need)
				out.append(_e(skill_title(cname, node["name"], counts), sub, text.strip_edges(), {}, "%s • %s" % [cname, br["name"]] if first else ""))
				first = false
	for br in Data.PERK_BRANCHES:
		var first2 := true
		for ti in br["tiers"].size():
			for perk in br["tiers"][ti]:
				var sub2 := "ярус %d • рангів %d • %s" % [ti + 1, int(perk["max"]), "відкритий одразу" if ti == 0 else "потрібно %d очок у гілці" % (ti * Data.PERK_TIER_STEP)]
				out.append(_e(skill_title("Загартування", perk["name"], counts), sub2, _line(perk["desc"]) + "." + (" Це за один ранг." if int(perk["max"]) > 1 else ""), {}, "Загартування • %s" % br["name"] if first2 else ""))
				first2 = false
	return out


## Найманці з корчми й побратими з історіями.
static func _party() -> Array:
	var Heroes = load("res://scripts/data/heroes.gd")
	var Gfx = load("res://scripts/world/gfx.gd")
	var out := []
	var first := true
	for id in Data.COMPANIONS:
		var C: Dictionary = Data.COMPANIONS[id]
		var icon := {"sprite": "comp_" + id} if Gfx.has("comp_" + id) else {}
		out.append(_e(str(C["name"]), "найманець • %d грн • лояльність від «%s»" % [int(C["cost"]), Data.LOYALTY_NAMES[int(C["loyalty"])]], _line(C["desc"]) + " Наймають у корчмі міста. Ціна росте з рівнем героя, знижка міста діє. Одного виду можна мати лише одного.", icon, "Найманці" if first else ""))
		first = false
	first = true
	for id in Heroes.HEROES:
		var H: Dictionary = Heroes.HEROES[id]
		var icon2 := {"sprite": "comp_" + id} if Gfx.has("comp_" + id) else {}
		var text := str(H["bio"]) + " Де зустріти: %s. Іде в загін безкоштовно. Дружба росте за кожного ворога, здоланого разом; від %d дружби дає особисте завдання: «%s». Після нього стає сильнішим." % [str(Data.CITIES.get(str(H["join"]["city"]), {}).get("name", "у місті")), int(H["quest_bond"]), str(H["quest"]["objective"]["text"])]
		out.append(_e(str(H["name"]), "побратим • б'ється як %s • сила ×%s" % [str(Data.COMPANIONS[H["base"]]["name"]).to_lower(), _num(float(H["mult"]))], text, icon2, "Побратими" if first else ""))
		first = false
	return out


## Усі досягнення з нагородами.
static func _achievements() -> Array:
	var Ach = load("res://scripts/data/achievements.gd")
	var out := []
	var first := true
	for a in Ach.ACHIEVEMENTS:
		var reward := []
		if int(a.get("gold", 0)) > 0:
			reward.append("%d грн" % int(a["gold"]))
		if int(a.get("glory", 0)) > 0:
			reward.append("слави %d" % int(a["glory"]))
		out.append(_e(str(a["name"]), "досягнення" + (" • " + ", ".join(reward) if not reward.is_empty() else ""), _line(a["desc"]) + ".", {}, "Досягнення: усі %d" % Ach.ACHIEVEMENTS.size() if first else ""))
		first = false
	return out


## Душі: правила, гнізда й усі душі за ступенями.
static func _souls() -> Array:
	var Souls = load("res://scripts/data/souls.gd")
	var SS = _svc("soul_service")
	var out := []
	var head := "Як це працює"
	out.append(_e("Душі", "у кожної нечисті своя", "Кожна нечисть і кожен бос мають свою душу. Вбита нечисть вкрай рідко лишає її: душа сама летить у торбинку героя. Душу вселяють у гніздо речі, і вона діє, поки річ вдягнена. Що лютіша нечисть, то сильніша душа. Жодна душа не лікує й не дає наснаги.", {}, head))
	out.append(_e("Гніздо для душі", "пробиває коваль", "Гніздо в речі пробиває коваль у місті або своя кузня (там дешевше). Гніздо буває в добротній речі й кращій, одне на річ, тож діє щонайбільше шість душ. Ціна залежить від рівня речі чи героя й рідкості, ще треба трофеїв: %d. Гніздо лишається в речі назавжди." % Souls.SOCKET_TROPHY))
	out.append(_e("Вселити й вийняти", "торбинка душ", "Вселити душу в порожнє гніздо можна задарма: на екрані героя, у коваля чи в кузні. Вийняти душу може лише коваль чи кузня, за %d%% ціни гнізда: душа ціла вертається в торбинку. Продав, переплавив чи викинув річ із душею, і душа теж вернулась у торбинку. Душі босів стають лише в зброю й оберіг." % roundi(Souls.REMOVE_PART * 100.0)))
	out.append(_e("Шанс душі", "вкрай малий", "Рядова нечисть лишає душу раз на %s убитих, елітна втричі частіше, розшукувані, сторожа скарбу й боси раз на %s. Нечисть, слабша за звичайну нечисть твого рівня, лишає душу рідше, тож давно пройдені місця душами не багаті. Від спорядження це не залежить. Кожна невдача трохи підіймає шанс (поклик душ), щонайбільше втричі. Перша душа героя з %d-го рівня дістається з першого ж елітного чи боса. Реклама «×2 здобичі» на душі не впливає." % [UI_num(int(round(1.0 / float(Souls.CHANCE["regular"])))), UI_num(int(round(1.0 / float(Souls.CHANCE["boss"])))), Souls.FIRST_LEVEL]))
	out.append(_e("Однакові душі й межі", "чесні правила", "Та сама душа діє один раз, навіть якщо вселити дві. Різні душі з однаковим бонусом складаються, але в кожного бонусу є межа. Стан від душі (підпал, холод, слабкість, прокляття, приголомшення) лягає на того самого ворога не частіше ніж раз на %d секунд. Пом'яник душ відкривається кнопкою «Душі» у спорядженні героя." % int(Souls.PROC_LOCK)))
	var last := 0
	for id in SS.known():
		var t: int = SS.tier(id)
		var h := ""
		if t != last:
			last = t
			h = "%s%s" % [Souls.TIER_NAMES[t], " • лише зброя й оберіг" if t >= Souls.BOSS_TIER else ""]
		out.append(_e(SS.soul_name(id), "%s • %s" % [str(Souls.TIER_NAMES[t]).to_lower(), SS.owner_name(id)], "%s.\n%s" % [_cap(SS.fx_text(id)), SS.info(id)["lore"]], {}, h))
	return out


## Число з пробілами між тисячами.
static func UI_num(n: int) -> String:
	return load("res://scripts/ui/ui_kit.gd").num(n)


## Артефакти: правила й усі трофеї босів.
static func _artifacts() -> Array:
	var out := []
	out.append(_e("Артефакти", "діють просто з торби", "Трофеї босів. Артефакт не вдягають: він дає свій бонус, поки лежить у торбі героя. Діють усі різні артефакти разом, але кожен займає місце в торбі. Другий такий самий не діє, у скрині артефакт спить. Заточити, оновити чи переплавити його не можна.", {}, "Артефакти"))
	out.append(_e("Де взяти артефакт", "у кожного боса свій", "Свій трофей лишає господар лігва: шанс %s%% за перемогу, супербос Башти дає %s%%, а бос, значно слабший за героя, лише %s%%. Що вже лежить у торбі, удруге не падає. Реклама «×2 здобичі» на цей шанс не впливає. При повній торбі артефакт лягає понад місце." % [_num(Artifacts.CHANCE * 100.0), _num(Artifacts.CHANCE_TOWER * 100.0), _num(Artifacts.CHANCE_GREY * 100.0)]))
	for id in Artifacts.ORDER:
		var D: Dictionary = Artifacts.DEFS[id]
		out.append(_e(str(D["name"]), "артефакт • %s" % Data.BOSS_NAMES.get(D["boss"], ""), "%s.\n%s" % [D["text"], D["lore"]], {}, "Артефакти: усі %d" % Artifacts.ORDER.size() if id == Artifacts.ORDER[0] else ""))
	return out


## Золоті (унікальні) речі: правила й усі речі з їхніми силами.
static func _uniques() -> Array:
	var out := []
	var head := "Золоті речі"
	var ch := []
	for t in range(1, Uniques.BASE_CHANCE.size()):
		ch.append("«%s» %s%%" % [Uniques.TIER_NAMES[t], _num(float(Uniques.BASE_CHANCE[t]) * 100.0)])
	out.append(_e("Золоті речі", "унікальні, з власним ім'ям", "Найрідкісніша здобич: назва золота, перед нею зірка. У кожної сталі властивості, сильніші за легендарні, і одна сила, що міняє бій. Падають лише з босів у їхніх лігвах і з супербосів Башти Кощія. Ватажки варти, оборони й чудовиська Кола Кожум'яки золота не дають.", {}, head))
	out.append(_e("Ступені золота", "що лютіший бос, то краща річ", "Ступенів п'ять: " + ", ".join(Uniques.TIER_NAMES.slice(1)) + ". Ступінь боса залежить від того, хто він. У Глибинах зарази ступінь росте на один за кожні 8 глибин, у Башті супербос дає на один більше, а з 40-го поверху на два. Бос дає річ свого ступеня або нижчого, найчастіше свого. Свою улюблену річ бос дає втричі частіше, а ту, що в тебе вже є, вчетверо рідше."))
	out.append(_e("Шанс золота", "малий, але чесний", "За одну перемогу: " + ", ".join(ch) + ". Кожен бос без золота наближає удачу: за %d таких поспіль шанс подвоюється, а %d-й дає річ напевно. Бос має бути не нижчий за героя більш як на %d рівнів, тож старі печери золота не дадуть. Реклама «×2 здобичі», свята й зараза на цей шанс не впливають." % [int(Uniques.LUCK_STEP), Uniques.LUCK_SURE + 1, Uniques.LEVEL_GAP]))
	out.append(_e("Що можна робити із золотом", "заточка, оновлення, продаж", "Золоту річ точать і оновлюють у кузні до свого рівня, як будь-яку іншу: властивості лишаються ті самі, росте лише сила. Масовий продаж і автопродаж її не чіпають, а при повній торбі вона лягає понад місце. Дві речі з однаковою силою не складаються: діє сильніша."))
	for id in Uniques.ORDER:
		var D: Dictionary = Uniques.DEFS[id]
		var kind: String = str(Data.SLOT_NAMES[D["slot"]]).to_lower()
		if D["slot"] == "weapon":
			kind = str(Data.WEAPON_TYPES[D["type"]]["name"]).to_lower()
		var props := []
		for a in D["affixes"]:
			props.append(PROP_NAMES.get(a, a))
		var text := "✦ %s. %s\nВластивості: %s.\nНайчастіше дає: %s.\n%s" % [Uniques.power_name(id), Uniques.power_text(id), ", ".join(props), Uniques.boss_names(id), D["lore"]]
		out.append(_e(str(D["name"]), "«%s» • %s" % [Uniques.TIER_NAMES[int(D["tier"])], kind], text, {}, "Золоті речі: усі %d" % Uniques.ORDER.size() if id == Uniques.ORDER[0] else ""))
	return out


static func _rules() -> Array:
	var out := []
	var head := "Стани"
	for id in Status.INFO:
		out.append(_e(Status.INFO[id]["name"], "стан", _cap(str(Wiki.STATUS_TEXT.get(id, ""))) + ".", {}, head))
		head = ""
	head = "Еліти"
	out.append(_e("Хто такі еліти", "золоте коло довкола ворога", "Сильніші за звичайну нечисть, мають ім'я й одну-три властивості, зате щедріші на здобич і трофеї.", {}, head))
	for a in Elites.AFFIXES:
		out.append(_e(Elites.AFFIXES[a]["m"], "властивість еліти", "Еліта %s." % Elites.AFFIXES[a]["desc"]))
	head = "Зараза"
	var PS = _svc("plague_service")
	for lvl in range(1, int(PS.MAX_LEVEL) + 1):
		var m: Dictionary = PS.mods(lvl)
		out.append(_e("Зараза: %s" % PS.NAMES[lvl], "рівень %d" % lvl, "Нечисть має +%d%% здоров'я й +%d%% шкоди, нагорода на %d%% більша.%s" % [roundi((float(m["hp"]) - 1.0) * 100), roundi((float(m["dmg"]) - 1.0) * 100), roundi((float(m["reward"]) - 1.0) * 100), " З-під землі підіймаються отруйні хмари." if lvl >= 2 else ""], {}, head))
		head = ""
	head = "Лояльність міст"
	for i in Data.LOYALTY_NAMES.size():
		out.append(_e(Data.LOYALTY_NAMES[i], "від %d очок" % int(Data.LOYALTY_THRESHOLDS[i]), "Знижка в місті %d%%." % roundi(float(Data.LOYALTY_DISCOUNT[i]) * 100), {}, head))
		head = ""
	head = "Слава"
	for r in Acts.GLORY_RANKS:
		var SS = _svc("stone_service")
		var extra := (" і %s" % SS.NAMES[r[3]]) if str(r[3]) != "" else ""
		out.append(_e(r[1], "від %d слави" % int(r[0]), ("Нагорода за ранг: %d грн%s." % [int(r[2]), extra]) if int(r[2]) > 0 else "Перший ранг.", {"loot": "glory"}, head))
		head = ""
	var src := "Звідки слава: " + "; ".join(Acts.GLORY_SOURCES) + "."
	out.append(_e("Джерела слави", "", src, {"loot": "glory"}))
	var recs := []
	for k in Acts.RECORD_ORDER:
		recs.append(str(Acts.RECORDS[k]["name"]))
	out.append(_e("Літопис слави", "рекорди роду", "Найкраще серед усіх твоїх персонажів: " + ", ".join(recs) + ". За віхи рекордів дають славу.", {}, "Рекорди й виклики"))
	var A = load("res://scripts/data/achievements.gd")
	out.append(_e("Виклики", "екран героя, вкладка «Виклики»", "Щодня %d виклики, щотижня %d, по %d з них про події й заняття. Нагорода дня — гривні й ресурси, тижня — гривні, рідкісна річ і безпечна заточка." % [int(A.DAILY_COUNT), int(A.WEEKLY_COUNT), int(A.DAILY_EVENTS)]))
	out.append(_e("Досягнення", "спільні для всіх героїв", "Досягнень %d: за бої, босів, заняття, свята й клейноди. Кожне відкривається раз і дає гривні." % A.ACHIEVEMENTS.size()))
	return out + _achievements()


## Увесь довідник одним документом Markdown (для docs/wiki.md, див. tools/wiki_export.gd).
static func to_markdown() -> String:
	var lines := ["# Довідник «Козацької Звитяги»", "",
		"Зібрано з таблиць гри інструментом `tools/wiki_export.gd`: те саме, що в грі на екрані «Довідник».", ""]
	var toc := []
	for s in sections():
		toc.append("[%s](#%s)" % [s["title"], str(s["title"]).to_lower().replace(" ", "-")])
	lines.append("Розділи: " + " • ".join(toc))
	lines.append("")
	for s in sections():
		lines.append("## " + str(s["title"]))
		lines.append("")
		for e in s["entries"]:
			if str(e["head"]) != "":
				lines.append("**%s**" % e["head"])
				lines.append("")
			lines.append("### " + str(e["title"]))
			if str(e["sub"]) != "":
				lines.append("*%s*" % e["sub"])
				lines.append("")
			for para in str(e["text"]).split("\n"):
				lines.append(para)
				lines.append("")
	return "\n".join(lines)
