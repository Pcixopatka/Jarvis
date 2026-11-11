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

static func _pct(v: float) -> String:
	var p := v * 100.0
	return (str(int(round(p))) if is_equal_approx(p, round(p)) else ("%.1f" % p).replace(".", ",")) + "%"


## Стаття «Здобич із нечисті»: усі шанси з таблиць гри, тож числа завжди справжні.
static func _loot_entry() -> Dictionary:
	var Camp = load("res://scripts/data/camp_data.gd")
	var Elites = load("res://scripts/data/elites.gd")
	var Uniq = load("res://scripts/data/uniques.gd")
	var Arts = load("res://scripts/data/artifacts.gd")
	var Souls = load("res://scripts/data/souls.gd")
	var shares := []
	for lvl in [20, 60, 99]:
		shares.append("на %d-му рівні звичайна %s, добротна %s, рідкісна %s, легендарна %s" % [lvl, _pct(Data.rarity_share(lvl, 0)), _pct(Data.rarity_share(lvl, 1)), _pct(Data.rarity_share(lvl, 2)), _pct(Data.rarity_share(lvl, 3))])
	var lines := [
		"Річ із рядового ворога: %s. Якою вона буде: %s." % [_pct(Data.ITEM_DROP_CHANCE), "; ".join(shares)],
		"Річ з еліти: %s, не гірша за добротну. Бос лишає дві речі, рідкісні або легендарні." % _pct(Elites.ITEM_CHANCE),
		"Дерево, залізо чи трави з рядового ворога: %s, одна одиниця. Еліта, бос і зачистка дають жмені: в одній жмені 1 + рівень/%d одиниць." % [_pct(Camp.RESOURCE_DROP_CHANCE), Camp.BUNDLE_LEVEL_STEP],
		"Трофеї: еліта лишає один із шансом %s, бос %d + рівень/%d, голова з розшуку %d." % [_pct(Camp.TROPHY_ELITE_CHANCE), Camp.TROPHY_BOSS_BASE, Camp.TROPHY_BOSS_LEVEL_STEP, Camp.TROPHY_BOUNTY],
		"Зілля здоров'я: рядовий ворог %s, еліта %s, бос завжди одне." % [_pct(Data.POTION_DROP_CHANCE), _pct(Data.POTION_ELITE_CHANCE)],
		"Зілля наснаги: %s, у волхвів удвічі частіше." % _pct(Data.MANA_POTION_DROP_CHANCE),
		"Вареник: %s, лікує %s здоров'я; з боса завжди, удвічі ситніший." % [_pct(Data.VARENYK_DROP_CHANCE), _pct(Data.VARENYK_HEAL)],
		"Золота річ із боса: від %s на першому ступені до %s на шостому. Кожні %d босів без золота подвоюють шанс." % [_pct(Uniq.BASE_CHANCE[1]), _pct(Uniq.BASE_CHANCE[Uniq.BASE_CHANCE.size() - 1]), int(Uniq.LUCK_STEP)],
		"Артефакт із боса: %s, у надважкій печері %s." % [_pct(Arts.CHANCE), _pct(Arts.CHANCE_PERIL)],
		"Душа: рядовий ворог %s, еліта %s, бос %s, надважкий бос %s. Невдачі підіймають шанс, найбільше втричі." % [("%.3f" % (float(Souls.CHANCE["regular"]) * 100.0)).replace(".", ",") + "%", ("%.3f" % (float(Souls.CHANCE["elite"]) * 100.0)).replace(".", ",") + "%", _pct(Souls.CHANCE["boss"]), _pct(Souls.CHANCE_PERIL)],
	]
	return _e("Здобич із нечисті", "що й як часто падає", "Усі шанси разом. «×2 здобичі» подвоює шанс речі й ресурсу, а босові додає третю річ; на зілля, трофеї, золото, артефакти й душі воно не діє. Улюбленець ворон додає до шансу ресурсу.\n• %s" % "\n• ".join(lines))


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
	out.append(_loot_entry())
	var QS = load("res://scripts/game/quick_service.gd")
	var hall_other := []
	for hc in Data.HALL_NAMES:
		hall_other.append("%s: «%s»" % [Data.place_name(hc), Data.HALL_NAMES[hc]])
	out.append(_e("Ратуша", "хто має до тебе справу", "Перша вкладка кожного міста. Тут чекають усі, хто має справу до героя: люди з історії, побратими, наставник після випробування й оповідачі переказів. Розмови самі не починаються. Зайшов у місто, і вгорі з'явиться напис, хто на тебе чекає, а біля назви вкладки буде число. Далі сам вирішуй, коли й до кого підійти: кнопка «Поговорити» в рядку. Зелена рамка й напис «Чекає з нагородою» означають, що справу вже зроблено й можна забрати своє. Якщо той самий співрозмовник одразу має наступну справу, розмова триває, а до інших підходиш окремо. Коли на героя чекає історія, місто відкривається одразу на цій вкладці. У містах будівля зветься «%s», в інших місцях по-своєму. %s." % [Data.HALL_DEFAULT, ". ".join(hall_other)], {"map": "castle"}))
	out.append(_e("Крамниця міста", "товари й торба сіткою значків", "Вкладка «Крамниця» в кожному місті. Ліворуч товари, посередині твоя торба, праворуч картка вибраної речі. Усе стоїть клітинками зі значками, так само як торба на екрані героя: колір рамки каже про рідкість, число в кутку про заточку, зірка про золоту річ. Під значком товару написана ціна, під значком твоєї речі те, скільки за неї дадуть. Зелена стрілка означає, що річ сильніша за вдягнену. Торкнись клітинки, і праворуч з'являться бонуси та кнопка «Купити» чи «Продати». Кнопка «Вибрати кілька» дає позначити кілька речей і продати разом: позначені клітинки стають зеленими з галочкою. Над сіткою є продаж гуртом за рідкістю й автопродаж звичайних при повній торбі. Артефакти в торбі видно, але вони не продаються. Таку саму крамницю будь-де відкриває Хованець.", {"map": "castle"}))
	out.append(_e("Подорож мапою", "до кожного місця треба доїхати", "Обери місце на мапі й натисни кнопку на його панелі: «Вирушити», «Увійти до міста», «Спуститися», «Піднятися» чи іншу. Вершник із хоругвою поїде туди пунктирним шляхом, і лише після прибуття почнеться бій чи відчиниться місто. Дорога триває від півтори до чотирьох секунд, залежно від відстані. Дотик по мапі під час поїздки прискорює її втричі. Так герой дістається до кожного місця: міст, хутора, полів, печер, таборів надважких печер, занять, Башти Кощія й Глибин зарази. Одразу він заходить лише туди, де вже стоїть. Їздити можна й без мети: торкнись порожнього місця на мапі, і герой поїде просто туди й стане там. Далі до будь-якого місця він їде вже від цієї точки, тож дорога буде коротша. Над морем і великими озерами замість вершника пливе чайка з прапорцем. У вільній дорозі пригод нема. Дорогою до диких місць трапляються пригоди: поїздка зупиняється на розмову й триває далі. Дорогу скорочують кінь зі стайні, перк вершника, артефакти й Гетьманський універсал, який робить її вдвічі швидшою. Поза мапою лишаються бос дня й бос тижня та швидкий похід: там дороги нема, герой лишається, де стояв. Після смерті герой отямлюється в останньому місті, де бував.", {"map": "castle"}))
	out.append(_e("Швидкий похід", "за перегляд реклами", "Місце, яке ти вже пройшов %d рази, можна зачистити миттю, без бою. На панелі місця з'являється кнопка «Швидкий похід за рекламу»: переглянь рекламу, і герой одразу дістане досвід, гривні, речі й ресурси, як за звичайний похід. Здобич рахується тими самими шансами, що й у бою, реклама «×2 здобичі» й свята на неї діють. Рідкісного з босів тут нема: золоті речі, артефакти, камені долі й душі дає лише справжній бій. Зараза, ніч, розшук і скарб у швидкому поході теж не діють, історія не просувається. Завдання міст на нечисть і печери він зараховує, а світ рахує його як похід: події й облоги чекають на один похід менше. На день дається %d швидких походів. Працює для диких місцевостей і печер, не сильніших за героя." % [QS.MIN_CLEARS, QS.PER_DAY]))
	var LegD = load("res://scripts/data/legends.gd")
	var LegS = _svc("legend_service")
	var leg_names := []
	for lid in LegD.ORDER:
		leg_names.append("«%s» (%s, з %d-го рівня)" % [LegD.LINES[lid]["title"], LegD.LINES[lid]["land"], int(LegD.LINES[lid]["min_level"])])
	out.append(_e("Перекази", "квестові лінійки за легендами", "Кожна земля має свої перекази, і за ними в грі є окремі лінійки завдань. Вони не залежать від головної історії й одна від одної: можна вести кілька одразу. Лінійка відкривається з певного рівня героя: зайди в місто оповідача й підійди до нього в ратуші. Сам він розмови не почне. Крок це розмова, мета й повернення по нагороду. Мета буває така: очистити місцевість, пройти печеру, знищити чи обібрати потрібну нечисть. Нечисть у місці переказу міряється рівнем із героєм, тож стара печера не стає прогулянкою. Нинішні кроки видно в «Журналі», розділ «Перекази», а місце мети позначено на мапі. Останній крок кожної лінійки дає іменну легендарну річ рівня героя.\n• %s" % "\n• ".join(leg_names)))
	for lid in LegD.ORDER:
		var LL: Dictionary = LegD.LINES[lid]
		var step_lines := []
		for i in LL["steps"].size():
			var lst: Dictionary = LL["steps"][i]
			step_lines.append("%d. «%s»: оповідач %s, %s. %s. Нагорода: %s." % [i + 1, lst["title"], Story.NPCS[lst["giver"]]["name"], Data.place_name(str(lst["city"])), lst["objective"]["text"], LegS.reward_text(lst)])
		out.append(_e("Переказ «%s»" % LL["title"], "%s • з %d-го рівня героя" % [LL["land"], int(LL["min_level"])], "Звідки переказ: %s.\n%s" % [LL["source"], "\n".join(step_lines)]))
	var SagaD = load("res://scripts/data/saga.gd")
	var saga_lines := []
	for st in SagaD.STEPS:
		saga_lines.append("«%s»: оповідач %s, %s. %s. Нагорода: %s грн і %d трофеїв." % [st["title"], Story.NPCS[st["giver"]]["name"], Data.place_name(str(st["city"])), st["objective"]["text"], _big(int(st["reward"]["gold"])), int(st["reward"]["trophy"])])
	out.append(_e("«%s»" % SagaD.TITLE, "продовження історії", "Після перемоги над Путіноїдом історія не кінчається. Зелений попіл розлетівся за край мапи й розбудив старе лихо п'яти чужих земель. З %d-го рівня героя кобзар Остап на Січі розповість, куди вітер його заніс. Кроків п'ять, кожен веде до одного з надважких босів. Зірка на мапі й «Журнал» показують, до кого йти. Хто вже здолав того боса раніше, тому крок зараховується одразу після розмови.\n• %s" % [SagaD.MIN_LEVEL, "\n• ".join(saga_lines)]))
	var Auto = _svc("auto_service")
	out.append(_e("Автобій", "у пройдених місцях", "У бою вгорі праворуч є кнопка «Авто». Місце, яке ти сам пройшов %d рази, можна довірити героєві: він сам іде до нечисті, б'є, вживає вміння, ухиляється від замахів, п'є зілля, коли здоров'я менше %d%%, і виходить крізь портал. Досвід, здобич і ціна смерті звичайні. Торкнись лівої частини екрана, і герой знову слухає тебе; відпустиш, і він б'ється далі сам. Автобою нема в надважких печерах, Глибинах, Башті, на босах дня й тижня та в особливих боях: там б'ються власноруч. Із Гетьманським універсалом досить пройти місце один раз." % [Auto.MIN_CLEARS, roundi(Auto.POTION_AT * 100.0)]))
	out.append(_e("Фільтр автопідбору", "щоб не збирати мотлох", "У паузі, на привалі й у головному меню є кнопка «Автопідбір». Там чотири рідкості: %s. Вимкнену рідкість герой сам не підбирає: така річ лежить на землі тьмяна. Коли йдеш із місця, усе, що фільтр не взяв, продається за ціною крамниці, тож гривні не пропадають. Золоті речі й артефакти беруться завжди. Якщо передумав, у бою відкрий «Автопідбір» і натисни «Підібрати все, що лежить». Річ, яку ти сам викинув із торби, фільтр не чіпає: стань на неї, і вона підніметься. Швидкий похід теж слухає фільтр." % ", ".join(Data.RARITY_PLURAL).to_lower()))
	out.append(_e("Повна торба", "здобич не зникає", "Коли в торбі нема місця, річ не підбирається й не продається: вона лежить на землі далі. Звільни місце й підійди до неї знову. На екрані героя торкнись непотрібної речі. «Знищити» прибирає її назавжди, другий дотик підтверджує. «Викинути на землю» кладе річ поруч, це можна лише в бою. Викинута річ сама назад не летить: щоб підняти, стань на неї. Душа зі знищеної чи викинутої речі вертається в торбинку. Золота річ і артефакт лягають понад місце. З автопродажем звичайні речі при повній торбі продаються одразу. Коли йдеш із місця, усе, що лишилось лежати й не вмістилось, продається за ціною крамниці. Зілля при повному запасі теж лежить і чекає, а перед виходом іде за півціни."))
	out.append(_e("Гортання списків", "", "Довгий список гортається пальцем із будь-якої точки екрана: веди просто по картках, кнопках чи клітинках, порожнє місце шукати не треба. Короткий дотик без руху натискає кнопку, як і раніше. Після відпускання список ще трохи їде сам."))
	var Shop = load("res://scripts/data/shop.gd")
	var packs: Array = Shop.PACKS
	out.append(_e("Крамниця", "усе рідкісне за червінці", "Крамниця відкривається з привалу на мапі, з паузи в бою й з екрана героя. За червінці тут продається все рідкісне: усі золоті речі, речі трьох наборів, артефакти всіх босів і душі всієї нечисті. Червінці купують за справжні гроші наборами від %s до %s. Вони спільні для всіх героїв роду й не зникають. Ціни в червінцях: золота річ %d–%d залежно від ступеня, річ набору %d, увесь набір одразу %d, артефакт %d, трофей надважкого боса %d, душа %d–%d залежно від ступеня. Куплена річ має рівень героя, що її купив, і лягає в торбу навіть понад місце. Душа летить у торбинку душ. Зброю, що не до руки твоєму класу, теж можна купити й передати іншому героєві через спільну скриню. Покупку за червінці треба підтвердити другим дотиком. Усе, що є в крамниці, можна здобути й у грі без жодної покупки." % [
		_big(int(packs[0]["coins"])), _big(int(packs[packs.size() - 1]["coins"])), int(Shop.UNIQUE_PRICE[1]), int(Shop.UNIQUE_PRICE[Shop.UNIQUE_PRICE.size() - 1]), Shop.SET_PIECE_PRICE, Shop.SET_FULL_PRICE,
		Shop.ARTIFACT_PRICE, Shop.ARTIFACT_PERIL_PRICE, int(Shop.SOUL_PRICE[1]), int(Shop.SOUL_PRICE[Shop.SOUL_PRICE.size() - 1])]))
	var Ench = load("res://scripts/data/enchants.gd")
	var EnchS = _svc("enchant_service")
	var ench_lines := []
	for eid in Ench.ORDER:
		var slots := []
		for sl in Ench.DEFS[eid]["slots"]:
			slots.append(str(Data.SLOT_NAMES[sl]).to_lower())
		ench_lines.append("%s (%s): %s" % [Ench.DEFS[eid]["name"], ", ".join(slots), Classes.fx_text(Ench.DEFS[eid]["fx"])])
	out.append(_e("Зачарування речей", "особлива властивість", "Коваль на хуторі зачаровує легендарні, золоті й наборні речі: вибери річ у вкладці «Кузня», і під перекуванням з'явиться список. На речі лежить одне зачарування, нове замінює старе. Таких властивостей нема серед звичайних. На речах %d-го рівня й вище, тобто на здобичі надважких печер, зачарування в %s сильніше. Ціна росте з рівнем речі: %d грн і %d ресурсу за рівень, а ще %d трофеїв і %s за рівень. Зброя просить залізо, оберіг трави, решта дерево. Зачарована річ лишається зачарованою у скрині й в іншого героя.\n• %s" % [
		Ench.STRONG_LEVEL, "півтора раза", Ench.GOLD_PER_LEVEL, Ench.RES_PER_LEVEL, Ench.TROPHY_BASE, _num(Ench.TROPHY_PER_LEVEL), "\n• ".join(ench_lines)]))
	var Fair = _svc("fair_service")
	var good_lines := []
	for gid in Fair.GOODS_ORDER:
		good_lines.append("%s: %d трофеїв і %s грн, на тиждень %d" % [Fair.GOODS[gid]["name"], int(Fair.GOODS[gid]["trophy"]), _big(int(Fair.GOODS[gid]["gold"])), int(Fair.GOODS[gid]["limit"])])
	out.append(_e("Трофейний ярмарок", "рідкісне за трофеї", "З %d-го рівня героя на хуторі є вкладка «Ярмарок». Раз на тиждень скупник привозить рідкісне й міняє на трофеї та гривні. У понеділок товар новий, а кожну річ герой бере раз на тиждень.\n• Три золоті речі під твій клас: свого ступеня й на один нижчого. Ціна від %d трофеїв і %s грн за першу ступінь до %d трофеїв і %s грн за п'яту. Шостого ступеня тут нема: він лишається надважким печерам.\n• Один артефакт звичайного боса: %d трофеїв і %s грн.\n• %s" % [
		Fair.MIN_LEVEL, int(Fair.UNIQUE_TROPHY[1]), _big(int(Fair.UNIQUE_GOLD[1])), int(Fair.UNIQUE_TROPHY[5]), _big(int(Fair.UNIQUE_GOLD[5])), Fair.ARTIFACT_TROPHY, _big(Fair.ARTIFACT_GOLD), "\n• ".join(good_lines)]))
	var PetD = load("res://scripts/data/pets.gd")
	var PetS = _svc("pet_service")
	var pet_lines := []
	for pid in PetD.ORDER:
		pet_lines.append("%s: %s, на найвищому ступені %s. Купити: %s." % [PetD.DEFS[pid]["name"], PetD.text(pid, 1), PetD.text(pid, PetD.MAX_LEVEL), PetS.cost_text(PetD.cost(pid, 1))])
	out.append(_e("Улюбленці", "помічники з хутора", "На хуторі є вкладка «Стайня». Там за гривні й ресурси беруть улюбленців, а потім годують: ступенів %d, кожен наступний коштує стільки ж, помножене на свій номер. Улюбленці спільні для роду, а з собою герой бере одного. Сили в бою вони не додають. Пес, кіт і ворон ходять за героєм у бою, кінь чекає на узліссі.\n• %s" % [PetD.MAX_LEVEL, "\n• ".join(pet_lines)]))
	var Div = load("res://scripts/data/divine.gd")
	var div_lines := []
	for did in Div.ORDER:
		div_lines.append("%s, гніздо «%s», %d червінців. %s Дає: %s." % [Div.DEFS[did]["name"], Div.SLOT_NAMES[Div.DEFS[did]["slot"]], int(Div.DEFS[did]["price"]), Div.DEFS[did]["desc"], "; ".join(Div.DEFS[did]["lines"])])
	var slot_names := []
	for dsl in Div.SLOTS:
		slot_names.append(str(Div.SLOT_NAMES[dsl]).to_lower())
	out.append(_e("Божі дари", "власні гнізда під спорядженням", "У крамниці на вкладці «Божі дари» за червінці продається %d дарів. Вони вдягаються не в звичайні клітинки спорядження, а у власні гнізда під ним на екрані героя. Гнізд %d: %s. У гнізді лежить один дар, тож там, де дарів два, герой обирає: Хованець чи скакун, молот чи ладанка. Місця в торбі дари не займають. Купуються раз на весь рід, а вдягає їх кожен герой окремо: торкнись гнізда, і картка покаже кнопки «Вдягнути» й «Зняти». На відміну від вбрання, дари дають силу й зручність. Супутника й мажу видно поруч із героєм у бою, решту видно на ньому самому. Мажу герой тягне за голоблі: сама вона не їде, стоїть, коли стоїть він, і повертає слідом. Із Хованцем над торбою на екрані героя з'являється кнопка «Хованець: крамниця», тож торгувати можна будь-де й будь-коли, навіть посеред бою. Така сама кнопка є на мапі, у паузі й у картці гнізда «Супутник». Це та сама крамниця, що й у місті: товари, зілля, продаж поодинці, гуртом і кнопка «Вибрати кілька». Товар, ціни й знижка беруться з останнього міста, де герой бував.\n• %s" % [Div.ORDER.size(), Div.SLOTS.size(), ", ".join(slot_names), "\n• ".join(div_lines)], {}))
	var Cost = load("res://scripts/data/costumes.gd")
	var cost_lines := []
	for cid in Cost.ORDER:
		cost_lines.append("%s, %d червінців. %s" % [Cost.DEFS[cid]["name"], int(Cost.DEFS[cid]["price"]), Cost.DEFS[cid]["desc"]])
	out.append(_e("Вбрання героя", "лише вигляд", "У крамниці на вкладці «Вбрання» продаються костюми. Вбрання міняє постать героя цілком, однаково для будь-якого класу, а зброя в руці лишається та, що вдягнена. Сили воно не додає. Купується раз на весь рід, а вдягає його кожен герой окремо: там само кнопки «Вдягнути» й «Зняти». У вбранні героя видно в бою, на полюванні й на рибалці.\n• %s" % "\n• ".join(cost_lines), {"sprite": Cost.sprite(Cost.ORDER[Cost.ORDER.size() - 2], "sabre")}))
	var Prem = load("res://scripts/game/premium_service.gd")
	out.append(_e(Prem.NAME, "преміум на %d днів" % Prem.DAYS, "Купується в крамниці на вкладці «Універсал» за %d червінців і діє %d днів для всіх героїв роду одразу. Продовження додає нові дні до решти, нічого не згорає. Сили героя універсал не додає: він знімає рекламу й очікування.\n• %s" % [
		Prem.PRICE, Prem.DAYS, "\n• ".join(Prem.perks(QS.PER_DAY, load("res://scripts/game/ad_rewards.gd").SAFE_PER_DAY))]))
	# Складність, смерть і шлях до останнього рівня: числа з балансу
	var full: int = int(Data.ENEMY_CURVE[Data.ENEMY_CURVE.size() - 1][0])
	var FarS = load("res://scripts/game/far_service.gd")
	out.append(_e("Складність", "гра сувора", "Сила нечисті залежить лише від її рівня й не дивиться на твоє спорядження. За мірку взято героя того самого рівня в середньому спорядженні. На 1-му рівні він рубає звичайного зараженого %s с, а удар зараженого забирає в нього %s%% запасу живучості. З %d-го рівня це вже %s с і %s%%. Решта нечисті лишається у своїй пропорції до зараженого, а еліта, боси й чудовиська множать ці числа далі. Тому в середньому спорядженні нечисть свого рівня небезпечна, у доброму з нею б'ються із зіллям напоготові, а вільно рубати її виходить лише в найкращому: легендарні речі, заточені до +%d, душі в гніздах, артефакти й клейноди роду. Перші рівні м'якші, щоб новачок устиг навчитися. На панелі місця на мапі є рядок «Тобі тут»: легко, під силу, важко чи смертельно. Він рахується з твого спорядження: скільки секунд ти рубаєш звичайну нечисть цього місця й скільки її ударів витримаєш. У Глибинах нечисть не буває слабшою за %d%% сили нечисті твого рівня, у Башті за %d%%: мілкіша глибина чи нижчий поверх легші, але не прогулянка." % [_num(Data.enemy_ttk(1)), _num(Data.enemy_hit(1) * 100.0), full, _num(Data.enemy_ttk(full)), _num(Data.enemy_hit(full) * 100.0), Data.MAX_UPGRADE, roundi(FarS.DEPTH_FLOOR * 100.0), roundi(FarS.TOWER_FLOOR * 100.0)], {}, "Правило"))
	out.append(_e("Характерництво й сила вмінь", "що далі, то менше", "Перші %d вкладених очок Характерництва дають по 5%% сили вмінь і помітно пришвидшують перезарядку. Кожне наступне очко дає вдесятеро менше. Наснаги воно додає завжди однаково, а волхвові ще й підіймає шкоду посохом, тож вкладати його далі варто. Раніше сила вмінь росла без межі, і волхв бив у кілька разів сильніше за воїна в такому самому спорядженні. Тепер усі класи завдають схожої шкоди за секунду, а різняться способом бою." % int(Data.SPI_SOFT), {}, "Правило"))
	out.append(_e("Смерть", "ціна поразки", "Загинувши в бою, герой отямлюється в останньому місті. Він утрачає %s%% гривень і %s%% досвіду, потрібного на поточний рівень. Рівень від цього не падає, а досвід не опускається нижче нуля. До %d-го рівня досвід не втрачається. Герць, варта, Коло Кожум'яки й гетьманський огляд без смерті: звідти просто виносять, і досвід цілий. На останньому рівні смерть забирає ту саму частку зі смуги звитяги. У надважкій печері втрата втричі більша, а отямлюється герой у таборі біля входу." % [_num(Data.DEATH_GOLD_LOSS * 100.0), _num(Data.DEATH_XP_LOSS * 100.0), Data.DEATH_XP_FROM], {}, "Правило"))
	var top: int = Data.Classes.BASE_LEVEL_MAX
	out.append(_e("Дорога до %d-го рівня" % top, "що вище, то довше", "Кожен наступний рівень коштує більше досвіду. З 10-го на 11-й треба %s, з 30-го на 31-й %s, з 60-го на 61-й %s, а з %d-го на %d-й аж %s. Досвід дає нечисть і завдання, і що вищий рівень нечисті, то більше з неї досвіду. Тому на високих рівнях ходи туди, де нечисть твого рівня: у далекі краї, Глибини й Башту. Що краще спорядження, то швидше падає нечисть і швидше росте герой. Рахуй на десятки годин до %d-го рівня. Після нього досвід не пропадає, а йде у звитяги." % [_big(Data.xp_for_level(10)), _big(Data.xp_for_level(30)), _big(Data.xp_for_level(60)), top - 1, top, _big(Data.xp_for_level(top - 1)), top], {}, "Правило"))
	out.append_array(_peril())
	# Запас сил: числа беруться з балансу, тож довідник не відстає від гри
	out.append(_e("Запас сил", "", "Здоров'я й наснага не вічні. Вампіризм лікує лише від справді завданої шкоди й не більш як %s%% здоров'я за секунду. Влучний удар дає трохи наснаги, але швидкі удари не дають її більше за секунду. Захист гасить щонайбільше %d%% удару. Бос б'є в %s раза сильніше за рядового свого виду й має в %s разів більше здоров'я. Тому бери з собою зілля: воно лікує %d%% здоров'я й потрібне на будь-якому рівні." % [_num(Data.LIFESTEAL_MAX_HPS * 100.0), roundi(Data.ARMOR_CAP * 100.0), _num(Data.BOSS_DMG_MULT), _num(Data.BOSS_HP_MULT), roundi(Data.POTION_HEAL * 100.0)]))
	return out


## Надважкі печери й звитяги: правила з числами балансу.
static func _peril() -> Array:
	var Peril = load("res://scripts/data/peril.gd")
	var PS = _svc("peril_service")
	var Sets = load("res://scripts/data/sets.gd")
	var Valor = load("res://scripts/data/valor.gd")
	var Souls = load("res://scripts/data/souls.gd")
	var ids: Array = PS.ids()
	var first: String = ids[0]
	var last: String = ids[ids.size() - 1]
	var lands := []
	for land in Peril.LAND_ORDER:
		lands.append(str(Peril.LANDS[land]["name"]))
	var out := []
	out.append(_e("Надважкі печери", "п'ять печер за краєм мапи", "П'ять печер у нових землях по краях мапи: %s. Нечисть у них від %d-го до %d-го рівня, вища за стелю рівня героя. До того ж вона у %s–%s раза міцніша за звичайну нечисть свого рівня й б'є у %s–%s раза сильніше: що далі печера, то лютіша. Пускають із %d-го рівня героя. Печери відкриваються по черзі: щоб увійти в наступну, здолай боса попередньої. Міст у нових землях нема. Біля входу стоїть табір: там можна перепочити й купити зілля в маркітанта, у %s раза дорожче, ніж у місті. Розраховано на героя в найкращому спорядженні. Для кожної наступної печери потрібні речі з попередньої, набори, золото шостого ступеня й звитяги." % [
		", ".join(lands), int(Data.LOCATIONS[first]["level"]), int(Data.LOCATIONS[last]["level"]), _num(PS.hp_mult(first)), _num(PS.hp_mult(last)), _num(PS.dmg_mult(first)), _num(PS.dmg_mult(last)), Peril.OPEN_LEVEL, _num(Peril.CAMP_POTION_MARKUP)], {}, "Надважкі печери"))
	out.append(_e("Суворі правила", "смерть і лють боса", "Смерть у надважкій печері забирає %s%% досвіду рівня замість %s%%, а на останньому рівні стільки ж зі смуги звитяги. Отямлюється герой у таборі біля входу. Надважкий бос у %s раза міцніший за звичайного боса свого рівня. Якщо бій із ним триває довше за %s хв, бос лютішає: його удар росте на %d%% кожні %d с, і приголомшенням цей час не відтягнеш. Нечисть, яку бос прикликає, досвіду не дає. Зілля й побратими працюють як завжди. Доручень, розшуку й швидкого походу в надважких печерах нема." % [
		_num(Data.DEATH_XP_LOSS * Peril.DEATH_XP_MULT * 100.0), _num(Data.DEATH_XP_LOSS * 100.0), _num(Peril.BOSS_HP_MULT), _num(Peril.ENRAGE_AFTER / 60.0), roundi(Peril.ENRAGE_DMG * 100.0), int(Peril.ENRAGE_EVERY)]))
	out.append(_e("Нагороди надважких печер", "заради чого туди ходити", "Речі з нечисті мають рівень печери, від %d до %d. Вищих у грі нема, і коваль до такого рівня річ не оновить. Досвіду з цієї нечисті в %s раза більше. Бос дає золото шостого ступеня «%s» із шансом %s%%, свій артефакт із шансом %s%% і душу сьомого ступеня з шансом %s%%. Перша перемога над кожним босом дає річ набору напевно й іменну звитягу: звання з вічним бонусом. Далі бос дає річ набору з шансом %d%%, а елітна нечисть печери з шансом %d%%. Найкращий час проходження записується героєві й роду." % [
		int(Data.LOCATIONS[first]["level"]), int(Data.LOCATIONS[last]["level"]), _num(Peril.XP_MULT), Uniques.TIER_NAMES[6], _num(float(Uniques.BASE_CHANCE[6]) * 100.0), _num(Artifacts.CHANCE_PERIL * 100.0), _num(Souls.CHANCE_PERIL * 100.0), roundi(Sets.BOSS_CHANCE * 100.0), roundi(Sets.ELITE_CHANCE * 100.0)]))
	var lines := []
	for id in Valor.ORDER:
		lines.append("%s: %s за очко" % [Valor.LINES[id]["name"], Valor.text(id, float(Valor.LINES[id]["per"]))])
	var top: int = Data.Classes.BASE_LEVEL_MAX
	out.append(_e("Звитяги", "поступ після %d-го рівня" % top, "На %d-му рівні досвід не пропадає: він наповнює смугу звитяги. Заповнена смуга дає очко. Перша смуга вміщає %s досвіду, кожна наступна на %s%% більше від першої. Очки вкладають на екрані героя, вкладка «Загартування», у п'ять ліній. %s. В одну лінію можна вкласти до %d очок. Бонуси вічні й малі: звитяги не зроблять надважку печеру легкою, але дають рости й після стелі рівня. Смерть забирає частку смуги, та зароблені очки не зникають." % [
		top, _big(Valor.bar(0)), _num(Valor.BAR_STEP * 100.0), ". ".join(lines), Valor.LINE_MAX], {}, "Звитяги"))
	var named := []
	for id in ids:
		var boss: String = str(Data.LOCATIONS[id]["boss"])
		named.append("«%s» за боса печери «%s»: %s" % [Peril.TITLES[boss], Data.LOCATIONS[id]["name"], Valor.fx_text(Peril.TITLE_FX[boss])])
	out.append(_e("Іменні звитяги", "звання за надважких босів", "Перша перемога над надважким босом дає героєві звання й вічний бонус. %s. Звання за найдальшого з подоланих босів стоїть біля назви класу на екрані героя, а бонуси всіх здобутих звань діють разом." % ". ".join(named)))
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
		var mults := "Здоров'я ×%s, шкода ×%s, наснага ×%s" % [_num(C["hp_mult"]), _num(C["dmg_mult"]), _num(C["mana_mult"])]
		if C.has("skill_mult"):
			mults += ", сила вмінь ×%s (чари б'ють по кілька цілей)" % _num(C["skill_mult"])
		text += "\n%s. Майстерність до %d-го рівня." % [mults, int(C["job_max"])]
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
	var BS = _svc("boss_service")
	var mod_lines := []
	for m in BS.MOD_ORDER:
		mod_lines.append("%s: %s" % [BS.MODS[m]["name"], BS.MODS[m]["desc"]])
	var pool := []
	for b in BS.POOL:
		pool.append(Data.BOSS_NAMES[b])
	out.append(_e("Бос дня й бос тижня", "раз на день і раз на тиждень", "На мапі внизу панелі є кнопка «Боси дня й тижня». Щодня й щотижня виходить один із відомих босів, той самий для всіх гравців. Рівнем він дорівнює героєві, тож не буває ні заслабким, ні задужим. Бос дня відкривається з %d-го рівня героя, бос тижня з %d-го. Перемогти кожного можна раз на період, а герой рахує своїх окремо. Поразка спроби не забирає, але ціна смерті звичайна.\nБос дня має у %s більше здоров'я за звичайного боса свого рівня й одну властивість. Бос тижня має у %s більше здоров'я, б'є на %d%% сильніше й має дві властивості. Властивості щоразу інші:\n• %s\nНагорода боса дня: %d грн за кожен рівень героя, %d трофеїв, %d%% досвіду рівня й легендарна річ. Бос тижня дає %d грн за рівень, %d трофеїв, %d%% досвіду рівня, %d легендарні речі й золоту річ напевно. Крім того, бос кидає звичайну здобич: шанс на золоту річ, трофей-артефакт і душу. Найкращий час на кожного боса запам'ятовується, а перемоги йдуть у «Літопис слави».\nХто може вийти: %s. Надважких босів серед них нема." % [
		int(BS.MIN_LEVEL["day"]), int(BS.MIN_LEVEL["week"]), _num(BS.HP_MULT["day"]) + " раза", _num(BS.HP_MULT["week"]) + " раза", roundi((float(BS.DMG_MULT["week"]) - 1.0) * 100.0),
		"\n• ".join(mod_lines), int(BS.GOLD_PER_LEVEL["day"]), int(BS.TROPHIES["day"]), roundi(float(BS.XP_PART["day"]) * 100.0),
		int(BS.GOLD_PER_LEVEL["week"]), int(BS.TROPHIES["week"]), roundi(float(BS.XP_PART["week"]) * 100.0), int(BS.WEEK_ITEMS), ", ".join(pool)], {}))
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
	elif L.has("peril"):
		sub = "Надважка печера • %d кімнат • бос: %s • рівень %s • з %d-го рівня героя" % [int(L["rooms"]), Data.BOSS_NAMES[L["boss"]], lvl, int(load("res://scripts/data/peril.gd").OPEN_LEVEL)]
	elif L["type"] == "dungeon":
		sub = "Печера • %d кімнат • бос: %s • рівень %s" % [int(L["rooms"]), Data.BOSS_NAMES[L["boss"]], lvl]
	else:
		sub = "Дика місцевість • рівень %s" % lvl
	var foes := []
	for e in L["enemies"]:
		foes.append(Data.ENEMY_NAMES[e])
	var more := ""
	if L.get("endless", false):
		# Башта й Глибини: стелі нема, складність росте з кожною сходинкою
		var tower: bool = L.get("tower", false)
		var svc = _svc("tower_service") if tower else _svc("depth_service")
		var step := "поверх" if tower else "глибину"
		more = "\nСтелі нема: нечисть росте на %d %s за кожну наступну %s і стає лютішою понад це. До %d-го рівня сходинки помірні; далі за кожен рівень її здоров'я множиться на %s, а удар на %s, тож рано чи пізно впирається кожен герой. Наприклад, %s %d це %d-й рівень, а %s %d уже %d-й. Здобич вище за %d-й рівень не росте (речі 100–140-го рівня дають лише надважкі печери), зате досвід і гривні ростуть далі." % [
			1 if tower else 2, "рівень" if tower else "рівні", step, Data.ENDLESS_SOFT, _num(Data.ENDLESS_HP_PER_LEVEL), ("%.3f" % Data.ENDLESS_DMG_PER_LEVEL).replace(".", ","),
			"поверх" if tower else "глибина", 50, int(svc.level_of(50)), "поверх" if tower else "глибина", 150, int(svc.level_of(150)), Data.ENDLESS_SOFT]
	return _e(L["name"], sub, "%s\nНечисть: %s.%s" % [L["desc"], ", ".join(foes), more], {"map": _map_icon(L)}, head)


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
		if not Data.LOCATIONS[id].has("region") and not Data.LOCATIONS[id].has("peril"):
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
	# Нові землі: надважкі печери
	var Peril = load("res://scripts/data/peril.gd")
	for land in Peril.LAND_ORDER:
		for id in _svc("peril_service").ids():
			if str(Data.LOCATIONS[id].get("land", "")) == land:
				out.append(_loc_entry(id, "%s: %s" % [Peril.LANDS[land]["name"], Peril.LANDS[land]["desc"]]))
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
	out.append(_e("Скриня", "спільна для всіх героїв", "Сюди кладуть гривні, речі й камені долі, щоб забрати іншим персонажем. Місць %d, кожен рівень складу додає ще %d. Скриня й торба показані двома сітками значків, як торба на екрані героя. Торкнись речі, і праворуч з'явиться її картка з кнопкою «%s» або «%s». Другий дотик по тій самій клітинці переносить річ одразу." % [int(_svc("account").CHEST_SIZE), int(_svc("account").CHEST_PER_SKLAD), load("res://scripts/ui/ui_camp.gd").CHEST_TAKE, load("res://scripts/ui/ui_camp.gd").CHEST_PUT], {"map": "chest"}))
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
	out.append_array(_sets())
	# Шанси здобичі: числа з балансу (Data.ITEM_DROP_CHANCE, Elites, Data.rarity_share)
	var leg := []
	var rare := []
	for lv in [1, 50, 99]:
		leg.append("%s%%" % _num(snappedf(Data.rarity_share(lv, 3) * 100.0, 0.1)))
		rare.append("%s%%" % _num(snappedf(Data.rarity_share(lv, 2) * 100.0, 0.1)))
	out.append(_e("Шанси здобичі", "що й як часто падає", "Рядова нечисть лишає річ із шансом %s%%. Еліта, а це %s%% нечисті, лишає річ у %s%% випадків, і не гіршу за добротну. Бос завжди дає дві речі, не гірші за рідкісну, а з рекламою «×2 здобичі» три. Зачистка місцевості додає ще дві речі, не гірші за добротну. Серед речей із рядової нечисті легендарних %s на 1-му, 50-му й 99-му рівнях, рідкісних %s. З боса на 75-му рівні легендарною буває кожна %d-та річ. Легендарних із рівнем більшає повільно, тож така річ лишається подією. Золоті речі, артефакти, душі й камені долі мають власні правила, дивись статті про них." % [
		_num(Data.ITEM_DROP_CHANCE * 100.0), _num(Elites.CHANCE * 100.0), _num(Elites.ITEM_CHANCE * 100.0), ", ".join(leg), ", ".join(rare), roundi(1.0 / Data.rarity_share(75, 3, 2))], {}, "Правило"))
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
## Набори речей: правила й кожен набір зі щаблями.
static func _sets() -> Array:
	var Sets = load("res://scripts/data/sets.gd")
	var out := []
	out.append(_e("Набори речей", "бонуси за 2, 4 й 6 речей", "Набір — це шість речей одного імені: зброя, шапка, жупан, пояс, чоботи й оберіг. Назва речі набору фіолетова, перед нею стоїть %s. Сама річ як легендарна: три властивості, але лише з переліку свого набору. Вдягнені разом речі одного набору дають бонуси за 2, 4 й 6 речей, і бонуси складаються. Набори падають лише в надважких печерах: перша перемога над кожним босом дає річ напевно, далі бос дає її з шансом %d%%, елітна нечисть із шансом %d%%. Набір під головну рису твого класу й річ, якої в тебе ще нема, трапляються вчетверо частіше. Рівень речі дорівнює рівню печери. Зброя набору завжди до руки твого класу. Масовий продаж речей наборів не чіпає. Шість речей набору займають усі клітинки, тож доведеться обирати між повним набором і золотими речами з їхніми силами." % [Sets.MARK, roundi(Sets.BOSS_CHANCE * 100.0), roundi(Sets.ELITE_CHANCE * 100.0)], {}, "Набори речей"))
	for sid in Sets.ORDER:
		var S: Dictionary = Sets.SETS[sid]
		var props := []
		for a in S["affixes"]:
			props.append(PROP_NAMES.get(a, a))
		var steps := []
		for step in Sets.STEPS:
			steps.append("%d %s: %s." % [step, "речі" if int(step) < 5 else "речей", Sets.step_text(sid, step)])
		out.append(_e(str(S["name"]), "набір • під %s" % PROP_NAMES.get(S["stat"], S["stat"]), "%s\nВластивості речей: %s.\n%s" % ["\n".join(steps), ", ".join(props), S["lore"]]))
	return out


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
	out.append(_e("Очок менше, ніж умінь", "доведеться обирати", "На вершині герой має 97 очок умінь, а в деревах його дороги близько півтори сотні рангів. Вивчити все не вийде: кожен збирає свого героя. Є майстерність під окрему зброю, що діє лише з нею в руках. Є стійки: підсилення на 20 с із платою за нього, і діє лише одна стійка. Є прийоми у відповідь, що спрацьовують після парирування чи перекиду. Є вершинні вміння на один ранг: вони вимагають двох інших умінь на п'ятому ранзі й мають довгу перезарядку. Активних умінь більше, ніж кнопок бою, тож набір на панелі теж обирають."))
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
					sub = "%s • наснага %d • перезарядка %s с • рангів %d" % ["підсилення" if SkillInfo.kind(id) == "buff" else "атака", int(node.get("cost", 0)), _num(Classes.cooldown(id)), int(node["max"])]
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
	out.append(_e("Душі", "у кожної нечисті своя", "Кожна нечисть і кожен бос мають свою душу. Вбита нечисть вкрай рідко лишає її: душа сама летить у торбинку героя. Душу вселяють у гніздо речі, і вона діє, поки річ вдягнена. Що лютіша нечисть, то сильніша душа. Найсильніші душі, сьомого ступеня, мають боси надважких печер: там душа боса падає з шансом %s%%. Жодна душа не лікує й не дає наснаги." % _num(Souls.CHANCE_PERIL * 100.0), {}, head))
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
	out.append(_e("Де взяти артефакт", "у кожного боса свій", "Свій трофей лишає господар лігва: шанс %s%% за перемогу, супербос Башти дає %s%%, бос надважкої печери %s%%, а бос, значно слабший за героя, лише %s%%. Кожна перемога над босом без його трофея наближає удачу саме з ним: за %d таких поспіль шанс подвоюється, а після %d наступна дає трофей напевно. Що вже лежить у торбі, удруге не падає. Реклама «×2 здобичі» на цей шанс не впливає. При повній торбі артефакт лягає понад місце." % [_num(Artifacts.CHANCE * 100.0), _num(Artifacts.CHANCE_TOWER * 100.0), _num(Artifacts.CHANCE_PERIL * 100.0), _num(Artifacts.CHANCE_GREY * 100.0), int(Artifacts.LUCK_STEP), Artifacts.LUCK_SURE]))
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
	out.append(_e("Золоті речі", "унікальні, з власним ім'ям", "Найрідкісніша здобич: назва золота, перед нею зірка. У кожної сталі властивості, сильніші за легендарні, і одна сила, що міняє бій. Падають лише з босів у їхніх лігвах, із супербосів Башти Кощія й із босів надважких печер. Ватажки варти, оборони й чудовиська Кола Кожум'яки золота не дають.", {}, head))
	out.append(_e("Ступені золота", "що лютіший бос, то краща річ", "Ступенів шість: " + ", ".join(Uniques.TIER_NAMES.slice(1)) + ". Ступінь боса залежить від того, хто він. У Глибинах зарази ступінь росте на один за кожні 8 глибин, у Башті супербос дає на один більше, а з 40-го поверху на два, але не вище п'ятого. Шостий ступінь дають лише боси надважких печер. Бос дає річ свого ступеня або нижчого, найчастіше свого. Свою улюблену річ бос дає втричі частіше, а ту, що в тебе вже є, вчетверо рідше."))
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
