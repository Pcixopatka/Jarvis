extends RefCounted
## База даних гри: сталі таблиці (нечисть, загін, речі, а згодом світ і вміння) лежать у data/*.json,
## окремо від коду. Цей модуль — єдиний вхід до них: вантажить кожну таблицю раз, коли вона вперше
## потрібна, зводить числа до потрібних типів за схемою й перевіряє записи (див. problems()).
## Записи, які віддає база, лише для читання: їх заморожено, і спроба змінити їх дає помилку.
## Опис полів, проміжки номерів і як додати нечисть чи річ — docs/data.md.

const DIR := "res://data/"

## Схема запису: поле → {"type": ..., "required": true}. Типи: string, int, float, bool,
## color (масив [r, g, b] або [r, g, b, a] із часток 0..1, стає Color), record (вкладений запис
## зі своїми "fields"), vector (масив [x, y] із двох чисел, стає Vector2: довгота й широта на мапі),
## enum (рядок із переліку "values"), list (масив значень, кожне за описом "of";
## "size" — точна довжина), map (об'єкт {рядковий ключ: значення за описом "of"}; порядок ключів
## зберігається). Порядок полів у схемі — порядок ключів у файлі (див. tools/data_format.gd).
const MOB_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер запису (1001...): ніколи не змінюється й не віддається іншому
	"name": {"type": "string"},  # ім'я в однині; без нього нечисть не з'являється на мапі й у завданнях
	"plural": {"type": "string"},  # родовий множини: «Знищ 10 мавок»
	"quest_item": {"type": "string"},  # трофей для завдання «Принеси»
	"feminine": {"type": "bool"},  # ім'я жіночого роду: «Крижана Мавка», «переможена» (див. Elites.title)
	"bounty_names": {"type": "list", "of": {"type": "string"}},  # імена для дошки розшуку; без них вид не розшукують
	"stats": {"type": "record", "required": true, "fields": {
		"hp": {"type": "float", "required": true},  # здоров'я на 1-му рівні до мірки рівня
		"speed": {"type": "float", "required": true},
		"damage": {"type": "float", "required": true},
		"xp": {"type": "int", "required": true},
		"radius": {"type": "float", "required": true},
		"scale": {"type": "float"},  # зріст (1 — звичайний); бос усе одно вдвічі більший
	}},
	"color": {"type": "color", "required": true},
	"blood": {"type": "color"},  # колір бризок від удару (без поля — білі)
	"attack": {"type": "record", "required": true, "fields": {
		"windup": {"type": "float", "required": true},  # замах перед ударом, с
		"ranged": {"type": "bool"},  # стріляє
		"keep_distance": {"type": "float"},  # тримається на такій відстані від цілі
		"shoot_cd": {"type": "float"},  # с між пострілами
		"as_boss": {"type": "record", "fields": {  # що інакше, коли цей вид веде бій як бос чи ватажок
			"ranged": {"type": "bool"},
			"shoot_cd": {"type": "float"},
		}},
	}},
	"hit_status": {"type": "string"},  # стан, який може накласти удар (див. Status.INFO)
	"mechanic": {"type": "string"},  # механіка звичайної форми: "mob/<файл>" у scripts/mechanics/ (див. Mechanic)
	"sounds": {"type": "record", "fields": {
		"death": {"type": "string"},  # голос смерті (без нього — загальний «enemy_die»)
	}},
	"wiki": {"type": "record", "fields": {
		"text": {"type": "string", "required": true},
		"tip": {"type": "string", "required": true},
	}},
	"boss": {"type": "record", "fields": {  # є, якщо вид буває іменним босом
		"num": {"type": "int", "required": true},  # сталий номер боса (2001...), окремий від номера нечисті
		"name": {"type": "string", "required": true},
		"tier": {"type": "int"},  # ступінь золотих речей (без нього — за рівнем лігва, див. LootService)
		"phase2": {"type": "bool"},  # лютішає на половині здоров'я (тоді рушій кличе phase2 механіки)
		"mechanic": {"type": "string"},  # механіка боса: "boss/<файл>" у scripts/mechanics/
		"wiki": {"type": "record", "fields": {
			"text": {"type": "string", "required": true},
			"tip": {"type": "string", "required": true},
		}},
	}},
}

## Найманець із корчми (джура, стрілець, знахарка): ім'я, ціна, сила 1-го рівня, механіка бою.
const COMPANION_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3001...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},  # опис у корчмі ("\n" — розрив рядка)
	"hire": {"type": "record", "required": true, "fields": {
		"cost": {"type": "int", "required": true},  # ціна найму в гривнях до знижки й мірки рівня героя
		"loyalty": {"type": "int", "required": true},  # потрібна лояльність міста: номер у Data.LOYALTY_NAMES
	}},
	"stats": {"type": "record", "required": true, "fields": {
		"hp": {"type": "float", "required": true},  # здоров'я на 1-му рівні (далі росте за еталоном, див. Party.stats)
		"hp_lvl": {"type": "float"},  # приріст за рівень зі старої формули; зараз гра його не читає
		"dmg": {"type": "float", "required": true},
		"dmg_lvl": {"type": "float"},  # так само не читається
		"heal": {"type": "float"},  # лікування на 1-му рівні (знахарка)
		"heal_lvl": {"type": "float"},  # так само не читається
		"range": {"type": "float", "required": true},  # дальність удару
		"cd": {"type": "float", "required": true},  # с між ударами
		"speed": {"type": "float", "required": true},
	}},
	"color": {"type": "color", "required": true},
	"mechanic": {"type": "string"},  # як б'ється: "companion/<файл>" у scripts/mechanics/
}

## Репліка розмови: [мовець, текст]; мовець — id із Story.NPCS.
const LINE := {"type": "list", "size": 2, "of": {"type": "string"}}
const DIALOGUE := {"type": "list", "required": true, "of": LINE}

## Побратим: іменний супутник з історією. Б'ється як найманець свого base, але сильніший.
const HERO_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3101...)
	"name": {"type": "string", "required": true},
	"base": {"type": "string", "required": true},  # рід служби: id із companions.json
	"mult": {"type": "float", "required": true},  # у скільки разів сильніший за найманця
	"color": {"type": "color", "required": true},
	"bio": {"type": "string", "required": true},
	"join": {"type": "record", "required": true, "fields": {  # де й коли зустріти
		"city": {"type": "string", "required": true},  # місто (cities.json)
		"after": {"type": "string", "required": true},  # крок сюжету, який уже пройдено
		"if": {"type": "string"},  # "крок=номер вибору"
	}},
	"meet": DIALOGUE,  # розмова при зустрічі
	"quest_bond": {"type": "int", "required": true},  # від якої дружби дає особисте завдання
	"quest": {"type": "record", "required": true, "fields": {
		"start": DIALOGUE,
		"objective": {"type": "record", "required": true, "fields": {
			"type": {"type": "enum", "required": true, "values": ["kill", "fetch", "clear", "dungeon"]},
			"enemy": {"type": "string"},  # kill, fetch: кого бити (mobs.json)
			"count": {"type": "int"},  # kill, fetch: скільки
			"loc": {"type": "string", "required": true},  # місце (places.json)
			"item": {"type": "string"},  # fetch: що здобути
			"chance": {"type": "float"},  # fetch: шанс на кожного переможеного
			"text": {"type": "string", "required": true},
		}},
		"end": DIALOGUE,
	}},
	"bonded": {"type": "float", "required": true},  # множник сили після особистого завдання
}

## Улюбленець стайні (пес, кіт, ворон, кінь) або супутник із божого дару (Хованець, скакун, мажа).
const PET_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (3201...)
	"name": {"type": "string"},  # улюбленець стайні; у дару ім'я — з самого дару (Divine)
	"desc": {"type": "string"},
	"stable": {"type": "record", "fields": {  # є в улюбленців стайні: хист, ступені, ціна
		"stat": {"type": "enum", "required": true, "values": ["pickup", "travel", "xp", "res"]},
		"base": {"type": "float", "required": true},  # надбавка на 1-му ступені (частка)
		"per": {"type": "float", "required": true},  # приріст за кожен наступний ступінь
		"text": {"type": "string", "required": true},  # опис хисту з %d (відсотки)
		"gold": {"type": "int", "required": true},  # ціна 1-го ступеня; ступінь N коштує в N разів більше
		"res": {"type": "map", "required": true, "of": {"type": "int"}},  # ресурси 1-го ступеня
	}},
	"gift": {"type": "bool"},  # супутник із божого дару з тим самим id (gifts.json)
	"mechanic": {"type": "string"},  # що робить у бою: "pet/<файл>"; без нього в бій не йде (кінь)
}

# ---------- Речі: основи спорядження ----------

## Клітинка спорядження. Клітинки з «primary» вдягаються (зброя, шапка...), без нього — ні (артефакт).
const GEAR_SLOT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4001...)
	"name": {"type": "string", "required": true},  # «Зброя», «Шапка»
	"primary": {"type": "record", "fields": {  # головний бонус речі цієї клітинки
		"stat": {"type": "string", "required": true},  # бонус із bonuses.json
		"base": {"type": "float", "required": true},  # на 0-му рівні речі
		"per_level": {"type": "float"},  # дробовий бонус: приріст за рівень речі (далі × якість рідкості)
		"every": {"type": "int"},  # цілий бонус: +1 за кожні every рівнів речі (і +1 за дві рідкості)
	}},
	"drop": {"type": "int"},  # вага клітинки у випадковій речі (зброя — 2, решта — 1; без поля — не падає)
}

## Рідкість речі. rank — число, яке лежить у речі («rarity»), від 0.
const RARITY_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4051...)
	"rank": {"type": "int", "required": true},  # 0 звичайна ... 5 артефакт; збереження зберігають саме його
	"name": {"type": "string", "required": true},  # «Легендарна»
	"plural": {"type": "string"},  # «Легендарні» — для фільтра автопідбору
	"color": {"type": "color", "required": true},  # колір назви й клітинки речі
	"weight": {"type": "record", "fields": {  # є, якщо така рідкість буває у випадкової речі
		"base": {"type": "float", "required": true},  # вага на 0-му рівні
		"per_level": {"type": "float", "required": true},  # приріст ваги за рівень
	}},
	"epithets": {"type": "list", "of": {"type": "string"}},  # прізвиська легендарної речі: Шабля «Вовча»
}

## Вид зброї: множники до звичайного удару.
const WEAPON_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4101...)
	"name": {"type": "string", "required": true},
	"dmg": {"type": "float", "required": true},  # шкода
	"cd": {"type": "float", "required": true},  # перезарядка удару
	"range": {"type": "float", "required": true},  # дальність
	"arc": {"type": "float", "required": true},  # ширина дуги
	"kb": {"type": "float", "required": true},  # відкидання
	"hint": {"type": "string", "required": true},  # підказка в картці речі
	"ranged": {"type": "bool"},  # б'є снарядами, дальність стала (Player.recalc)
	"agi": {"type": "bool"},  # сила від Спритності (стрільці)
	"basic": {"type": "bool"},  # падає, коли гра не задала зброї під клас (Data.weapon_pool порожній)
}

## Основа обладунку: назва звичайної речі неозброєної клітинки («Кучма», «Черес»).
const ARMOR_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4201...)
	"slot": {"type": "string", "required": true},  # клітинка з gear_slots.json
	"name": {"type": "string", "required": true},
}

## Бонус речі (властивість): текст, точність і кидок.
const BONUS_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4301...)
	"text": {"type": "string", "required": true},  # шаблон: %s — число
	"decimals": {"type": "int"},  # знаків після коми в тексті (без поля — 0)
	"whole": {"type": "bool"},  # ціле число (характеристики): заточка округлює донизу
	"affix": {"type": "bool"},  # буває додатковою властивістю випадкової речі (порядок файлу — порядок кидка)
	"capped": {"type": "bool"},  # досвід і гривні: масштаб і стеля (Data.xp_gold_scale, XP_GOLD_CAP)
	"roll": {"type": "record", "fields": {  # кидок властивості до якості рідкості
		"min": {"type": "float", "required": true},
		"max": {"type": "float", "required": true},
		"per_level": {"type": "float"},  # дробова: + per_level × рівень речі
		"every": {"type": "int"},  # ціла: верхня межа +1 за кожні every рівнів речі й +1 за дві рідкості
	}},
	"mid": {"type": "list", "size": 2, "of": {"type": "float"}},  # середина кидка для золотих речей: [стала, за рівень]
}

## Заточка: шанс удачі з нинішнього рівня up на наступний.
const SHARPEN_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4401...)
	"up": {"type": "int", "required": true},  # з якої заточки (0 — ще не точена)
	"chance": {"type": "float", "required": true},
}

## Сила золотої речі: назва, опис і параметри, які пише кожна річ із цією силою.
const POWER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4501...)
	"name": {"type": "string", "required": true},
	"text": {"type": "string", "required": true},  # {параметр} підставляється з речі
	"params": {"type": "map", "required": true, "of": {"type": "enum", "values": ["int", "float", "pct"]}},  # pct — частка, у тексті відсотки
}

## Ступінь золотої речі (1..6).
const GOLDEN_TIER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4601...)
	"tier": {"type": "int", "required": true},
	"name": {"type": "string", "required": true},  # «Сотницька»
	"primary_mult": {"type": "float", "required": true},  # множник головного бонусу (дробового)
	"chance": {"type": "float", "required": true},  # шанс золотої речі з боса цього ступеня
	"price": {"type": "int", "required": true},  # у крамниці, червінців
	"fair": {"type": "record", "fields": {  # на трофейному ярмарку (шостого там нема)
		"trophy": {"type": "int", "required": true},
		"gold": {"type": "int", "required": true},
	}},
}

## Бонус набору (ключ, який читає Player.recalc) і його текст: число у відсотках.
const SET_EFFECT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4701...)
	"text": {"type": "string", "required": true},
}

## Бонус душі: текст і межа суми всіх душ разом (у відсотках).
const SOUL_EFFECT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4801...)
	"text": {"type": "string", "required": true},
	"cap": {"type": "int", "required": true},
}

## Ступінь душі (1..7).
const SOUL_TIER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4901...)
	"tier": {"type": "int", "required": true},
	"name": {"type": "string", "required": true},
	"color": {"type": "color", "required": true},
	"price": {"type": "int", "required": true},  # у крамниці, червінців
}

# ---------- Речі ----------

## Золота (унікальна) річ: іменна, зі сталими властивостями й однією силою.
const GOLDEN_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5001...)
	"name": {"type": "string", "required": true},
	"slot": {"type": "string", "required": true},  # клітинка (gear_slots.json)
	"type": {"type": "string"},  # вид зброї (weapons.json), лише для зброї
	"tier": {"type": "int", "required": true},  # ступінь (golden_tiers.json)
	"bosses": {"type": "list", "required": true, "of": {"type": "string"}},  # хто з босів дає її втричі частіше
	"affixes": {"type": "map", "required": true, "of": {"type": "float"}},  # бонус → множник
	"power": {"type": "string", "required": true},  # сила (powers.json)
	"params": {"type": "map", "required": true, "of": {"type": "float"}},  # параметри сили (ціле чи частка — за силою)
	"lore": {"type": "string", "required": true},
}

## Набір із шести речей.
const SET_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5101...)
	"name": {"type": "string", "required": true},  # «Спадок Святогора»
	"of": {"type": "string", "required": true},  # родовий: «Шабля Святогора»
	"stat": {"type": "string", "required": true},  # головна риса класу, під яку набір зібрано
	"affixes": {"type": "list", "required": true, "of": {"type": "string"}},  # з цих бонусів кидаються три на річ
	"bonus": {"type": "list", "required": true, "of": {"type": "record", "fields": {
		"pieces": {"type": "int", "required": true},  # від скількох вдягнених речей
		"fx": {"type": "map", "required": true, "of": {"type": "int"}},  # бонус (set_effects.json) → відсотки
	}}},
	"lore": {"type": "string", "required": true},
}

## Артефакт: трофей боса, діє з торби.
const ARTIFACT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5201...)
	"name": {"type": "string", "required": true},
	"boss": {"type": "string", "required": true},  # чий трофей (mobs.json, вид із «boss»)
	"bonus": {"type": "map", "required": true, "of": {"type": "float"}},  # ключ → значення (читає Player, служби)
	"text": {"type": "string", "required": true},
	"lore": {"type": "string", "required": true},
}

## Душа: id — вид нечисті, а для боса "b_" + вид.
const SOUL_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5301...)
	"name": {"type": "string", "required": true},
	"tier": {"type": "int", "required": true},  # ступінь (soul_tiers.json)
	"fx": {"type": "map", "required": true, "of": {"type": "int"}},  # бонус (soul_effects.json) → відсотки
	"lore": {"type": "string", "required": true},
}

## Зачарування речі.
const ENCHANT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5401...)
	"name": {"type": "string", "required": true},
	"slots": {"type": "list", "required": true, "of": {"type": "string"}},  # на які клітинки лягає
	"fx": {"type": "map", "required": true, "of": {"type": "float"}},  # ключі як у пасивних умінь (Classes.FX_TEXT)
}

## Гніздо божих дарів.
const GIFT_SLOT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4951...)
	"name": {"type": "string", "required": true},
}

## Божий дар із крамниці за червінці (поля див. DivineService.fx_of).
const GIFT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5501...)
	"slot": {"type": "string", "required": true},  # гніздо (gift_slots.json)
	"name": {"type": "string", "required": true},
	"icon": {"type": "string", "required": true},  # значок (tools/pixel/icons.py)
	"price": {"type": "int", "required": true},  # червінців
	"pickup": {"type": "float"},  # у скільки разів більший радіус збору (надбавка)
	"shop": {"type": "bool"},  # крамниця будь-де
	"loot": {"type": "bool"},  # здобич одразу в торбу
	"bag": {"type": "int"},  # місць у торбі
	"trade": {"type": "int"},  # одиниць краму на возі
	"stats": {"type": "float"},  # частка до всіх характеристик
	"fx": {"type": "map", "of": {"type": "float"}},  # бойові показники (Classes.FX_TEXT)
	"revive": {"type": "float"},  # з якою часткою здоров'я раз на бій піднімає
	"xp": {"type": "float"},
	"gold": {"type": "float"},
	"auto_buffs": {"type": "bool"},
	"party": {"type": "float"},  # частка до шкоди й здоров'я загону
	"sight": {"type": "bool"},  # стрілка до еліти
	"light": {"type": "float"},  # у скільки разів далі світить
	"desc": {"type": "string", "required": true},
	"lines": {"type": "list", "required": true, "of": {"type": "string"}},  # рядки опису
}

## Вбрання: лише вигляд.
const COSTUME_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5601...)
	"name": {"type": "string", "required": true},
	"price": {"type": "int", "required": true},  # червінців
	"desc": {"type": "string", "required": true},
}

## Набір червінців: id — назва товару в магазині застосунків.
const COIN_PACK_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (5701...)
	"name": {"type": "string", "required": true},
	"coins": {"type": "int", "required": true},
	"bonus": {"type": "int", "required": true},  # відсотків понад найменший набір
	"price": {"type": "string", "required": true},  # орієнтовна ціна (справжню показує магазин)
}

## Розділ крамниці за червінці (вкладка). Ціни золота й душ — у їхніх ступенях.
const SHOP_KIND_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (4981...)
	"name": {"type": "string", "required": true},
	"price": {"type": "int"},  # артефакт, річ набору
	"peril_price": {"type": "int"},  # артефакт надважкого боса
	"full_price": {"type": "int"},  # увесь набір разом
}

# ---------- Світ ----------

## Далекий край (Сіверщина, Слобожанщина...): об'єднує міста й місця з «region». Порядок файлу — порядок показу.
const REGION_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6001...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},
}

## Місто на мапі.
const CITY_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6101...)
	"name": {"type": "string", "required": true},
	"pos": {"type": "vector", "required": true},  # [довгота, широта]
	"level": {"type": "int", "required": true},  # рівень міста: завдання, розшук, хто туди ходить
	"region": {"type": "string"},  # далекий край (regions.json); без нього — стара мапа
	"hall": {"type": "string", "required": true},  # як зветься будівля, де чекають ті, хто має справу до героя
	"desc": {"type": "string", "required": true},
}

## Безкінечне місце (Башта, Глибини): з кого складаються поверхи чи глибини.
const FLOORS_SCHEMA := {"type": "record", "fields": {
	"pool": {"type": "list", "required": true, "of": {"type": "string"}},  # рядова нечисть, з якої кидаються поверхи
	"bosses": {"type": "list", "required": true, "of": {"type": "string"}},  # боси по черзі
	"titles": {"type": "list", "of": {"type": "string"}},  # прізвиська міні-босів Башти по черзі
}}

## Місце на мапі: поле (field) чи печера (dungeon).
const PLACE_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6201...)
	"name": {"type": "string", "required": true},
	"type": {"type": "enum", "required": true, "values": ["field", "dungeon"]},
	"biome": {"type": "string", "required": true},  # краєвид (biomes.json): земля, шум, ресурс, значок
	"pos": {"type": "vector", "required": true},  # [довгота, широта]
	"level": {"type": "int", "required": true},  # рівень нечисті (для «scale» — найнижчий)
	"scale": {"type": "bool"},  # далекий край: рівень росте разом із героєм (Data.loc_level)
	"region": {"type": "string"},  # далекий край (regions.json)
	"land": {"type": "string"},  # нова земля надважкої печери (lands.json)
	"peril": {"type": "int"},  # надважка печера: порядковий номер (1...), відкриваються по черзі
	"goal": {"type": "int"},  # поле: скільки нечисті знищити для зачистки (без поля — за рівнем, Data.FIELD_GOAL_*)
	"rooms": {"type": "int"},  # печера: кімнат
	"enemies": {"type": "list", "required": true, "of": {"type": "string"}},  # нечисть (mobs.json)
	"boss": {"type": "string"},  # печера: бос (mobs.json, вид із «boss»)
	"night": {"type": "bool"},  # вічна ніч
	"endless": {"type": "bool"},  # безкінечне місце (Глибини, Башта): опис бою складає служба
	"tower": {"type": "bool"},  # Башта: бій поверхами
	"floors": FLOORS_SCHEMA,
	"icon": {"type": "string"},  # особливий значок на мапі (без поля — за краєвидом, biomes.json)
	"plague_start": {"type": "int"},  # зараза на початку гри (1–3)
	"desc": {"type": "string", "required": true},
}

## Нова земля надважкої печери: назва, опис і іменна звитяга за її боса.
const LAND_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6401...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},
	"title": {"type": "string", "required": true},  # звання героя за першу перемогу над босом печери цієї землі
	"title_fx": {"type": "map", "required": true, "of": {"type": "int"}},  # вічний бонус звитяги (ключі Valor.LINES чи EXTRA_TEXT), відсотки
}

## Краєвид місця: фоновий шум, ресурс для хутора, значок на мапі. Земля й частинки малюються кодом.
const BIOME_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6501...)
	"name": {"type": "string", "required": true},
	"ambient": {"type": "string", "required": true},  # фоновий шум (SoundIndex.AMBIENT)
	"resource": {"type": "string"},  # що найчастіше дає хуторові (CampData.RESOURCES); без поля — дерево
	"icon": {"type": "string", "required": true},  # значок поля на мапі (WorldMap.ICON_ORDER)
	"dungeon_icon": {"type": "string", "required": true},  # значок печери
}

## Властивість елітної нечисті: прикметник в обох родах, колір, стан від удару. Що вона робить — код (Enemy).
const ELITE_AFFIX_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6601...)
	"name": {"type": "record", "required": true, "fields": {
		"m": {"type": "string", "required": true},  # «Вогняний»
		"f": {"type": "string", "required": true},  # «Вогняна» (нечисть із «feminine»)
	}},
	"color": {"type": "color", "required": true},
	"status": {"type": "string"},  # стан, який накладає кожен удар (Status.INFO)
	"desc": {"type": "string", "required": true},  # «підпалює»: у розшуку й довіднику
}

## Таблиці бази: назва → файл і схема. Нова таблиця (уміння, речі...) додається сюди одним рядком,
## а її власні правила й перехресні посилання — у _rules() і _links().
const TABLES := {
	"mobs": {"file": "mobs.json", "schema": MOB_SCHEMA},
	"companions": {"file": "companions.json", "schema": COMPANION_SCHEMA},
	"heroes": {"file": "heroes.json", "schema": HERO_SCHEMA},
	"pets": {"file": "pets.json", "schema": PET_SCHEMA},
	"gear_slots": {"file": "gear_slots.json", "schema": GEAR_SLOT_SCHEMA},
	"rarities": {"file": "rarities.json", "schema": RARITY_SCHEMA},
	"weapons": {"file": "weapons.json", "schema": WEAPON_SCHEMA},
	"armors": {"file": "armors.json", "schema": ARMOR_SCHEMA},
	"bonuses": {"file": "bonuses.json", "schema": BONUS_SCHEMA},
	"sharpening": {"file": "sharpening.json", "schema": SHARPEN_SCHEMA},
	"powers": {"file": "powers.json", "schema": POWER_SCHEMA},
	"golden_tiers": {"file": "golden_tiers.json", "schema": GOLDEN_TIER_SCHEMA},
	"set_effects": {"file": "set_effects.json", "schema": SET_EFFECT_SCHEMA},
	"soul_effects": {"file": "soul_effects.json", "schema": SOUL_EFFECT_SCHEMA},
	"soul_tiers": {"file": "soul_tiers.json", "schema": SOUL_TIER_SCHEMA},
	"gift_slots": {"file": "gift_slots.json", "schema": GIFT_SLOT_SCHEMA},
	"shop_kinds": {"file": "shop_kinds.json", "schema": SHOP_KIND_SCHEMA},
	"golden": {"file": "golden.json", "schema": GOLDEN_SCHEMA},
	"sets": {"file": "sets.json", "schema": SET_SCHEMA},
	"artifacts": {"file": "artifacts.json", "schema": ARTIFACT_SCHEMA},
	"souls": {"file": "souls.json", "schema": SOUL_SCHEMA},
	"enchants": {"file": "enchants.json", "schema": ENCHANT_SCHEMA},
	"gifts": {"file": "gifts.json", "schema": GIFT_SCHEMA},
	"costumes": {"file": "costumes.json", "schema": COSTUME_SCHEMA},
	"coin_packs": {"file": "coin_packs.json", "schema": COIN_PACK_SCHEMA},
	"regions": {"file": "regions.json", "schema": REGION_SCHEMA},
	"cities": {"file": "cities.json", "schema": CITY_SCHEMA},
	"places": {"file": "places.json", "schema": PLACE_SCHEMA},
	"lands": {"file": "lands.json", "schema": LAND_SCHEMA},
	"biomes": {"file": "biomes.json", "schema": BIOME_SCHEMA},
	"elite_affixes": {"file": "elite_affixes.json", "schema": ELITE_AFFIX_SCHEMA},
}

## Проміжки сталих номерів за таблицями: [перший, останній]. Номер запису мусить лежати у своєму
## проміжку (так номер одразу каже, з якої він таблиці). Нова таблиця бере вільний проміжок (docs/data.md).
const NUM_RANGES := {
	"mobs": [1001, 1999], "companions": [3001, 3099], "heroes": [3101, 3199], "pets": [3201, 3299],
	"gear_slots": [4001, 4049], "rarities": [4051, 4099], "weapons": [4101, 4199], "armors": [4201, 4299],
	"bonuses": [4301, 4399], "sharpening": [4401, 4499], "powers": [4501, 4599], "golden_tiers": [4601, 4699],
	"set_effects": [4701, 4799], "soul_effects": [4801, 4899], "soul_tiers": [4901, 4949], "gift_slots": [4951, 4979],
	"shop_kinds": [4981, 4999], "golden": [5001, 5099], "sets": [5101, 5199], "artifacts": [5201, 5299],
	"souls": [5301, 5399], "enchants": [5401, 5499], "gifts": [5501, 5599], "costumes": [5601, 5699],
	"coin_packs": [5701, 5799], "regions": [6001, 6099], "cities": [6101, 6199], "places": [6201, 6399],
	"lands": [6401, 6499], "biomes": [6501, 6599], "elite_affixes": [6601, 6699],
}
const BOSS_NUM_RANGE := [2001, 2999]  # boss.num у mobs.json

## Основи механік за родинами: тека в scripts/mechanics/ → скрипт-основа.
const MECHANIC_BASES := {
	"mob": "res://scripts/mechanics/mechanic.gd",
	"boss": "res://scripts/mechanics/mechanic.gd",
	"companion": "res://scripts/mechanics/companion_mechanic.gd",
	"pet": "res://scripts/mechanics/pet_mechanic.gd",
}

## Гнізда божих дарів, у яких лежать супутники, що ходять за героєм у бою (Хованець, скакун, мажа).
const PET_GIFT_SLOTS := ["pet", "cart"]

const _EMPTY := {}
const _EMPTY_LIST := []

static var _tables := {}  # назва → заморожені записи
static var _ids := {}  # назва → заморожений масив id у порядку файлу
static var _load_problems := {}  # назва → що не так із файлом
static var _nums := {}  # покажчики за номером записів (див. _num_index)


# ---------- Загальний доступ ----------

## Уся таблиця: id → запис (лише для читання). Вантажиться раз, при першому зверненні.
static func table(name: String) -> Dictionary:
	if not _tables.has(name):
		_load(name)
	return _tables[name]


## Перелік id таблиці в порядку файлу (лише для читання).
static func ids(name: String) -> Array:
	if not _ids.has(name):
		_load(name)
	return _ids[name]


## Запис таблиці; для невідомого id — порожній словник (теж лише для читання).
static func row(name: String, id: String) -> Dictionary:
	return table(name).get(id, _EMPTY)


## Шлях до файлу таблиці.
static func path_of(name: String) -> String:
	return DIR + str(TABLES[name]["file"])


static func _load(name: String) -> void:
	var file_probs := []
	var raw := _read(name, file_probs)
	var res := _normalize_rows(name, raw)
	# Гучно: зламана чи загублена таблиця не має пройти тихо (повний перелік — problems())
	for p in file_probs + res[1]:
		push_error("GameDB: %s" % p)
	var rows: Dictionary = res[0]
	_post(name, rows)
	_freeze(rows)
	var keys := rows.keys()
	keys.make_read_only()
	_tables[name] = rows
	_ids[name] = keys
	_load_problems[name] = file_probs


## Сирий вміст файлу таблиці (числа — як їх дав JSON, тобто дробові).
static func _read(name: String, probs: Array) -> Dictionary:
	var path := path_of(name)
	if not FileAccess.file_exists(path):
		probs.append("немає файлу таблиці %s (чи не випав він зі збірки? див. include_filter в export_presets.cfg)" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		probs.append("%s, рядок %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		probs.append("%s: на верхньому рівні має бути об'єкт {id: запис}" % path)
		return {}
	return json.data


## Що таблиця доводить до ладу після схеми, поки записи ще не заморожено.
## Золота річ: параметри сили стають цілими чи дробовими так, як їх оголошує сила (powers.json):
## JSON дає всі числа дробовими, а радіус чи кількість стрибків — цілі.
static func _post(name: String, rows: Dictionary) -> void:
	if name != "golden":
		return
	for id in rows:
		var R: Dictionary = rows[id]
		var kinds: Dictionary = row("powers", str(R.get("power", ""))).get("params", _EMPTY)
		var P: Dictionary = R.get("params", {})
		for k in P:
			if str(kinds.get(k, "")) == "int" and float(P[k]) == floorf(float(P[k])):
				P[k] = int(P[k])


## Заморожує словники й масиви на всю глибину.
static func _freeze(v) -> void:
	if v is Dictionary:
		for k in v:
			_freeze(v[k])
		v.make_read_only()
	elif v is Array:
		for x in v:
			_freeze(x)
		v.make_read_only()


# ---------- Перевірка ----------

## Усе, що не так із базою: помилки файлів, полів, типів, невідомі ключі й посилання з коду гри
## на нечисть, якої в базі нема. Порожній масив — усе гаразд.
static func problems() -> Array:
	var out := []
	for name in TABLES:
		table(name)
		out.append_array(_load_problems[name])
		var raw := _read(name, [])
		for p in validate(name, raw):
			if not p in out:  # те саме посилання перевіряють обидві таблиці (річ → бос і бос ← річ)
				out.append(p)
	return out


## Перевіряє сирі записи таблиці так само, як файл (схема, власні правила, посилання).
## Нічого не змінює й не вантажить у базу: зручно, щоб перевірити запис до того, як його записати.
static func validate(name: String, raw: Dictionary) -> Array:
	var res := _normalize_rows(name, raw)
	var out: Array = res[1]
	out.append_array(_rules(name, res[0]))
	out.append_array(_links(name, res[0]))
	return out


## Зводить усі записи таблиці до схеми. Повертає [записи, проблеми]; хибні поля пропускає.
static func _normalize_rows(name: String, raw: Dictionary) -> Array:
	var probs := []
	var rows := {}
	var schema: Dictionary = TABLES[name]["schema"]
	for id in raw:
		var where := "%s/%s" % [name, id]
		if not id is String or not _is_id(id):
			probs.append("%s: id має бути з малих латинських літер, цифр і «_»" % where)
		if not raw[id] is Dictionary:
			probs.append("%s: запис має бути об'єктом" % where)
			continue
		rows[str(id)] = _normalize(raw[id], schema, where, probs)
	return [rows, probs]


static func _is_id(id: String) -> bool:
	if id == "":
		return false
	for c in id:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			return false
	return true


static func _normalize(rec: Dictionary, schema: Dictionary, where: String, probs: Array) -> Dictionary:
	var out := {}
	for k in rec:
		if not schema.has(k):
			probs.append("%s: невідоме поле «%s» (описка?)" % [where, k])
	for k in schema:
		var f: Dictionary = schema[k]
		if not rec.has(k):
			if f.get("required", false):
				probs.append("%s: немає обов'язкового поля «%s»" % [where, k])
			continue
		var v = _value(rec[k], f, "%s.%s" % [where, k], probs)
		if v != null:
			out[k] = v
	return out


## Одне значення за описом поля; null, якщо воно хибне (тоді проблему вже записано).
static func _value(v, f: Dictionary, where: String, probs: Array):
	var t: String = f["type"]
	match t:
		"string":
			if v is String:
				return v
		"bool":
			if v is bool:
				return v
		"int":
			# JSON дає всі числа дробовими: 3 приходить як 3.0. Ціле поле мусить бути цілим.
			if v is int:
				return v
			if v is float:
				if v == floorf(v) and absf(v) < 9.0e15:
					return int(v)
				probs.append("%s: має бути цілим числом, а не %s" % [where, var_to_str(v)])
				return null
		"float":
			if v is float or v is int:
				return float(v)
		"color":
			if v is Array and (v.size() == 3 or v.size() == 4):
				var ok := true
				for c in v:
					ok = ok and (c is float or c is int) and c >= 0.0 and c <= 1.0
				if ok:
					return Color(v[0], v[1], v[2], v[3] if v.size() == 4 else 1.0)
			probs.append("%s: колір має бути масивом [r, g, b] із чисел від 0 до 1" % where)
			return null
		"vector":
			if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
				return Vector2(v[0], v[1])
			probs.append("%s: має бути масивом [x, y] із двох чисел" % where)
			return null
		"record":
			if v is Dictionary:
				return _normalize(v, f["fields"], where, probs)
		"enum":
			if v is String:
				if v in f["values"]:
					return v
				probs.append("%s: «%s» — не з переліку %s" % [where, v, str(f["values"])])
				return null
		"list":
			if v is Array:
				if f.has("size") and v.size() != int(f["size"]):
					probs.append("%s: має бути %d значень, а не %d" % [where, int(f["size"]), v.size()])
					return null
				var out := []
				for i in v.size():
					var x = _value(v[i], f["of"], "%s[%d]" % [where, i], probs)
					if x == null:
						return null
					out.append(x)
				return out
		"map":
			if v is Dictionary:
				var out := {}
				for k in v:
					var x = _value(v[k], f["of"], "%s.%s" % [where, k], probs)
					if x != null:
						out[k] = x
				return out
	probs.append("%s: має бути %s, а не %s" % [where, _type_name(t), _type_name_of(v)])
	return null


static func _type_name(t: String) -> String:
	return {"string": "рядком", "bool": "true або false", "int": "цілим числом", "float": "числом", "record": "об'єктом {...}",
		"enum": "рядком", "list": "масивом [...]", "map": "об'єктом {...}", "vector": "масивом [x, y]"}.get(t, t)


static func _type_name_of(v) -> String:
	if v is String:
		return "рядком"
	if v is bool:
		return "true/false"
	if v is float or v is int:
		return "числом"
	if v is Array:
		return "масивом"
	if v is Dictionary:
		return "об'єктом"
	return "null" if v == null else type_string(typeof(v))


## Власні правила таблиці (поза типами полів).
static func _rules(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"mobs":
			for id in rows:
				var R: Dictionary = rows[id]
				var at: Dictionary = R.get("attack", {})
				if at.get("ranged", false) and not at.has("shoot_cd"):
					out.append("mobs/%s: стрілець без «attack.shoot_cd»" % id)
				var ab: Dictionary = at.get("as_boss", {})
				if ab.get("ranged", false) and not ab.has("shoot_cd") and not at.has("shoot_cd"):
					out.append("mobs/%s: стрілець-бос без «attack.as_boss.shoot_cd»" % id)
				for k in ["hp", "speed", "damage", "radius", "scale"]:
					if float(R.get("stats", {}).get(k, 1.0)) <= 0.0:
						out.append("mobs/%s: «stats.%s» має бути більшим за нуль" % [id, k])
				if int(R.get("stats", {}).get("xp", 0)) < 0:
					out.append("mobs/%s: «stats.xp» не може бути від'ємним" % id)
				if R.has("boss") and R["boss"].has("tier") and (int(R["boss"]["tier"]) < 1 or int(R["boss"]["tier"]) > 6):
					out.append("mobs/%s: «boss.tier» має бути від 1 до 6" % id)
				for k in ["name", "plural", "quest_item"]:
					if R.has(k) and str(R[k]).strip_edges() == "":
						out.append("mobs/%s: «%s» порожнє" % [id, k])
				if R.has("feminine") and not R["feminine"]:
					out.append("mobs/%s: «feminine» пишеться лише як true" % id)
				if R.has("bounty_names"):
					if R["bounty_names"].is_empty():
						out.append("mobs/%s: «bounty_names» порожні (без розшуку поле не пишуть)" % id)
					if not R.has("name"):
						out.append("mobs/%s: «bounty_names» без «name»: розшук показує ім'я виду" % id)
					for b in R["bounty_names"]:
						if str(b).strip_edges() == "":
							out.append("mobs/%s: порожнє ім'я в «bounty_names»" % id)
				# Механіка: звичайна форма — лише з теки mob/, бос — лише з boss/
				if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "mob"):
					out.append("mobs/%s: «mechanic» має бути \"mob/<файл>\", а не «%s»" % [id, R["mechanic"]])
				if R.has("boss") and R["boss"].has("mechanic") and not _is_mechanic_ref(R["boss"]["mechanic"], "boss"):
					out.append("mobs/%s: «boss.mechanic» має бути \"boss/<файл>\", а не «%s»" % [id, R["boss"]["mechanic"]])
			out.append_array(_unique_nums(name, rows))
		"companions":
			for id in rows:
				var R: Dictionary = rows[id]
				_not_blank(R, ["name", "desc"], "companions/" + id, out)
				var st: Dictionary = R.get("stats", {})
				for k in ["hp", "dmg", "range", "cd", "speed"]:
					if st.has(k) and float(st[k]) <= 0.0:
						out.append("companions/%s: «stats.%s» має бути більшим за нуль" % [id, k])
				for k in ["hp_lvl", "dmg_lvl", "heal", "heal_lvl"]:
					if st.has(k) and float(st[k]) < 0.0:
						out.append("companions/%s: «stats.%s» не може бути від'ємним" % [id, k])
				if int(R.get("hire", {}).get("cost", 0)) < 0:
					out.append("companions/%s: «hire.cost» не може бути від'ємним" % id)
				if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "companion"):
					out.append("companions/%s: «mechanic» має бути \"companion/<файл>\", а не «%s»" % [id, R["mechanic"]])
			out.append_array(_unique_nums(name, rows))
		"heroes":
			for id in rows:
				out.append_array(_hero_rules("heroes/" + id, rows[id]))
			out.append_array(_unique_nums(name, rows))
		"pets":
			for id in rows:
				out.append_array(_pet_rules("pets/" + id, rows[id]))
			out.append_array(_unique_nums(name, rows))
		_:
			if ITEM_TABLES.has(name):
				out.append_array(_item_rules(name, rows))
				out.append_array(_unique_nums(name, rows))
			elif WORLD_TABLES.has(name):
				out.append_array(_world_rules(name, rows))
				out.append_array(_unique_nums(name, rows))
	return out


static func _not_blank(R: Dictionary, keys: Array, where: String, out: Array) -> void:
	for k in keys:
		if R.has(k) and str(R[k]).strip_edges() == "":
			out.append("%s: «%s» порожнє" % [where, k])


## Розмови побратима: назва → масив реплік.
static func _hero_dialogues(R: Dictionary) -> Dictionary:
	var q: Dictionary = R.get("quest", _EMPTY)
	return {"meet": R.get("meet", []), "quest.start": q.get("start", []), "quest.end": q.get("end", [])}


static func _hero_rules(where: String, R: Dictionary) -> Array:
	var out := []
	_not_blank(R, ["name", "bio"], where, out)
	if R.has("mult") and float(R["mult"]) <= 0.0:
		out.append("%s: «mult» має бути більшим за нуль" % where)
	if R.has("bonded") and R.has("mult") and float(R["bonded"]) < float(R["mult"]):
		out.append("%s: «bonded» менший за «mult», а після особистого завдання побратим має сильнішати" % where)
	if R.has("quest_bond") and int(R["quest_bond"]) <= 0:
		out.append("%s: «quest_bond» має бути більшим за нуль" % where)
	var dl := _hero_dialogues(R)
	for k in dl:
		var lines: Array = dl[k]
		if lines.is_empty() and (k == "meet" and R.has("meet") or R.get("quest", _EMPTY).has(k.trim_prefix("quest."))):
			out.append("%s: розмова «%s» порожня" % [where, k])
		for i in lines.size():
			if str(lines[i][0]).strip_edges() == "" or str(lines[i][1]).strip_edges() == "":
				out.append("%s: «%s[%d]»: порожній мовець чи текст" % [where, k, i])
	var o: Dictionary = R.get("quest", _EMPTY).get("objective", _EMPTY)
	var ot := str(o.get("type", ""))
	if ot in ["kill", "fetch"]:
		if not o.has("enemy") or not o.has("count"):
			out.append("%s: мета «%s» потребує «enemy» і «count»" % [where, ot])
		elif int(o["count"]) < 1:
			out.append("%s: «quest.objective.count» має бути від 1" % where)
	if ot == "fetch":
		if not o.has("item") or not o.has("chance"):
			out.append("%s: мета «fetch» потребує «item» і «chance»" % where)
		elif float(o["chance"]) <= 0.0 or float(o["chance"]) > 1.0:
			out.append("%s: «quest.objective.chance» має бути від 0 до 1" % where)
	for k in ["enemy", "count", "item", "chance"]:
		if o.has(k) and not (ot == "fetch" or (ot == "kill" and k in ["enemy", "count"])):
			out.append("%s: мета «%s» не читає «%s»" % [where, ot, k])
	return out


static func _pet_rules(where: String, R: Dictionary) -> Array:
	var out := []
	if R.has("stable") == R.has("gift"):
		out.append("%s: має бути або «stable» (улюбленець стайні), або «gift» (супутник із божого дару)" % where)
	if R.has("gift") and not bool(R["gift"]):
		out.append("%s: «gift» пишеться лише як true" % where)
	if R.has("stable"):
		for k in ["name", "desc"]:
			if not R.has(k):
				out.append("%s: улюбленцю стайні потрібне «%s»" % [where, k])
		_not_blank(R, ["name", "desc"], where, out)
		var D: Dictionary = R["stable"]
		if D.has("text") and not "%d" in str(D["text"]):
			out.append("%s: «stable.text» має містити %%d (відсотки хисту)" % where)
		if D.has("base") and float(D["base"]) <= 0.0:
			out.append("%s: «stable.base» має бути більшим за нуль" % where)
		if D.has("per") and float(D["per"]) < 0.0:
			out.append("%s: «stable.per» не може бути від'ємним" % where)
		if D.has("gold") and int(D["gold"]) <= 0:
			out.append("%s: «stable.gold» має бути більшим за нуль" % where)
		for r in D.get("res", _EMPTY):
			if int(D["res"][r]) <= 0:
				out.append("%s: «stable.res.%s» має бути більшим за нуль" % [where, r])
	if R.has("gift"):
		for k in ["name", "desc"]:
			if R.has(k):
				out.append("%s: у супутника з дару «%s» береться з самого дару (gifts.json), тут його не пишуть" % [where, k])
		if not R.has("mechanic"):
			out.append("%s: супутник із дару без «mechanic» у бою нічого не робить" % where)
	if R.has("mechanic") and not _is_mechanic_ref(R["mechanic"], "pet"):
		out.append("%s: «mechanic» має бути \"pet/<файл>\", а не «%s»" % [where, R["mechanic"]])
	return out


## Таблиці речей: їхні правила — _item_rules, посилання — _item_links.
const ITEM_TABLES := ["gear_slots", "rarities", "weapons", "armors", "bonuses", "sharpening", "powers", "golden_tiers",
	"set_effects", "soul_effects", "soul_tiers", "gift_slots", "shop_kinds", "golden", "sets", "artifacts", "souls",
	"enchants", "gifts", "costumes", "coin_packs"]
## Рядкові поля записів речей, які не можуть бути порожні.
const _ITEM_TEXTS := ["name", "text", "lore", "desc", "hint", "of", "icon", "plural"]


## Номери-ступені (rank рідкості, tier, up заточки) ідуть підряд від first без пропусків і повторів.
static func _contiguous(name: String, rows: Dictionary, field: String, first: int) -> Array:
	var out := []
	var seen := {}
	for id in rows:
		if rows[id].has(field):
			var v := int(rows[id][field])
			if seen.has(v):
				out.append("%s/%s: «%s» %d уже має «%s»" % [name, id, field, v, seen[v]])
			seen[v] = id
	for i in seen.size():
		if not seen.has(first + i):
			out.append("%s: «%s» мають іти підряд від %d, а %d бракує" % [name, field, first, first + i])
			break
	return out


static func _positive(R: Dictionary, keys: Array, where: String, out: Array, zero_ok: bool = false) -> void:
	for k in keys:
		if R.has(k) and (float(R[k]) < 0.0 or (not zero_ok and float(R[k]) == 0.0)):
			out.append("%s: «%s» має бути %s" % [where, k, "не від'ємним" if zero_ok else "більшим за нуль"])


## Правила таблиць речей, що не залежать від інших таблиць.
static func _item_rules(name: String, rows: Dictionary) -> Array:
	var out := []
	for id in rows:
		var R: Dictionary = rows[id]
		var where := "%s/%s" % [name, id]
		_not_blank(R, _ITEM_TEXTS, where, out)
		for k in R:
			if R[k] is bool and not R[k]:
				out.append("%s: «%s» пишеться лише як true" % [where, k])
		match name:
			"gear_slots":
				var P: Dictionary = R.get("primary", _EMPTY)
				if R.has("primary") and P.has("per_level") == P.has("every"):
					out.append("%s: у «primary» має бути або «per_level» (дробовий бонус), або «every» (цілий)" % where)
				if P.has("every") and int(P["every"]) < 1:
					out.append("%s: «primary.every» має бути від 1" % where)
				_positive(P, ["base"], where + ".primary", out, true)
				_positive(R, ["drop"], where, out, true)
				if R.has("drop") and not R.has("primary"):
					out.append("%s: «drop» без «primary»: така річ не вдягається" % where)
			"rarities":
				if R.has("weight"):
					_positive(R["weight"], ["base"], where + ".weight", out)
					_positive(R["weight"], ["per_level"], where + ".weight", out, true)
					if not R.has("plural"):
						out.append("%s: випадкова рідкість потребує «plural» (фільтр автопідбору)" % where)
				for e in R.get("epithets", []):
					if str(e).strip_edges() == "":
						out.append("%s: порожнє прізвисько в «epithets»" % where)
			"weapons":
				_positive(R, ["dmg", "cd", "range", "arc", "kb"], where, out)
				if R.get("agi", false) and not R.get("ranged", false):
					out.append("%s: «agi» лише в зброї дальнього бою («ranged»)" % where)
			"bonuses":
				if R.has("text") and not "%s" in str(R["text"]):
					out.append("%s: «text» має містити %%s (число)" % where)
				if int(R.get("decimals", 0)) < 0 or int(R.get("decimals", 0)) > 1:
					out.append("%s: «decimals» буває 0 або 1" % where)
				var roll: Dictionary = R.get("roll", _EMPTY)
				if R.has("roll"):
					if float(roll["min"]) > float(roll["max"]):
						out.append("%s: «roll.min» більший за «roll.max»" % where)
					if R.get("whole", false) != roll.has("every"):
						out.append("%s: цілий бонус («whole») кидається з «roll.every», дробовий — без нього" % where)
					if roll.has("every") and int(roll["every"]) < 1:
						out.append("%s: «roll.every» має бути від 1" % where)
				for k in ["affix", "capped"]:
					if R.get(k, false) and not R.has("roll"):
						out.append("%s: «%s» потребує «roll»" % [where, k])
			"sharpening":
				if R.has("chance") and (float(R["chance"]) <= 0.0 or float(R["chance"]) > 1.0):
					out.append("%s: «chance» має бути від 0 до 1" % where)
			"powers":
				if R.get("params", _EMPTY).is_empty():
					out.append("%s: «params» порожні" % where)
				for k in _placeholders(str(R.get("text", ""))):
					if not R.get("params", _EMPTY).has(k):
						out.append("%s: у тексті {%s}, а такого параметра в «params» нема" % [where, k])
			"golden_tiers":
				_positive(R, ["primary_mult", "price"], where, out)
				if R.has("chance") and (float(R["chance"]) < 0.0 or float(R["chance"]) > 1.0):
					out.append("%s: «chance» має бути від 0 до 1" % where)
				_positive(R.get("fair", _EMPTY), ["trophy", "gold"], where + ".fair", out)
			"set_effects":
				if R.has("text") and not "%s" in str(R["text"]):
					out.append("%s: «text» має містити %%s (відсотки)" % where)
			"soul_effects":
				if R.has("text") and not "%s" in str(R["text"]):
					out.append("%s: «text» має містити %%s (відсотки)" % where)
				_positive(R, ["cap"], where, out)
			"soul_tiers":
				_positive(R, ["price"], where, out)
			"shop_kinds":
				_positive(R, ["price", "peril_price", "full_price"], where, out)
			"golden":
				if R.get("affixes", _EMPTY).is_empty():
					out.append("%s: «affixes» порожні" % where)
				for k in R.get("affixes", _EMPTY):
					if float(R["affixes"][k]) <= 0.0:
						out.append("%s: множник «affixes.%s» має бути більшим за нуль" % [where, k])
				if R.get("bosses", []).is_empty():
					out.append("%s: «bosses» порожні" % where)
				if R.has("slot") and (str(R["slot"]) == "weapon") != R.has("type"):
					out.append("%s: «type» (вид зброї) пишеться у зброї й лише в неї" % where)
			"sets":
				if R.get("affixes", []).is_empty():
					out.append("%s: «affixes» порожні" % where)
				var steps := []
				for st in R.get("bonus", []):
					steps.append(int(st["pieces"]))
					if st["fx"].is_empty():
						out.append("%s: бонус за %d речей порожній" % [where, int(st["pieces"])])
					for k in st["fx"]:
						if int(st["fx"][k]) <= 0:
							out.append("%s: бонус «%s» за %d речей має бути більшим за нуль" % [where, k, int(st["pieces"])])
				if R.has("bonus") and steps != load("res://scripts/data/sets.gd").STEPS:
					out.append("%s: щаблі бонусу %s, а мають бути %s (Sets.STEPS)" % [where, str(steps), str(load("res://scripts/data/sets.gd").STEPS)])
			"artifacts":
				if R.get("bonus", _EMPTY).is_empty():
					out.append("%s: «bonus» порожній" % where)
				for k in R.get("bonus", _EMPTY):
					if float(R["bonus"][k]) == 0.0:
						out.append("%s: «bonus.%s» нульовий" % [where, k])
			"souls":
				if R.get("fx", _EMPTY).is_empty():
					out.append("%s: «fx» порожні" % where)
				for k in R.get("fx", _EMPTY):
					if int(R["fx"][k]) <= 0:
						out.append("%s: «fx.%s» має бути більшим за нуль" % [where, k])
			"enchants":
				if R.get("slots", []).is_empty():
					out.append("%s: «slots» порожні" % where)
				if R.get("fx", _EMPTY).is_empty():
					out.append("%s: «fx» порожні" % where)
				for k in R.get("fx", _EMPTY):
					if float(R["fx"][k]) <= 0.0:
						out.append("%s: «fx.%s» має бути більшим за нуль" % [where, k])
			"gifts":
				_positive(R, ["price", "pickup", "bag", "trade", "stats", "revive", "xp", "gold", "party", "light"], where, out)
				if R.get("lines", []).is_empty():
					out.append("%s: «lines» порожні" % where)
				for ln in R.get("lines", []):
					if str(ln).strip_edges() == "":
						out.append("%s: порожній рядок у «lines»" % where)
			"costumes":
				_positive(R, ["price"], where, out)
			"coin_packs":
				_not_blank(R, ["price"], where, out)
				_positive(R, ["coins"], where, out)
				_positive(R, ["bonus"], where, out, true)
	match name:
		"rarities":
			out.append_array(_contiguous(name, rows, "rank", 0))
		"sharpening":
			out.append_array(_contiguous(name, rows, "up", 0))
		"golden_tiers", "soul_tiers":
			out.append_array(_contiguous(name, rows, "tier", 1))
		"weapons":
			var basic := false
			for id in rows:
				basic = basic or rows[id].get("basic", false)
			if not rows.is_empty() and not basic:
				out.append("weapons: жодна зброя не «basic», а без пулу класу річ бере зброю з них")
	return out


## Назви {параметрів} у тексті сили.
static func _placeholders(text: String) -> Array:
	var out := []
	var parts := text.split("{")
	for i in range(1, parts.size()):
		var k := parts[i].get_slice("}", 0)
		if k != "" and not k in out:
			out.append(k)
	return out


static func _is_mechanic_ref(ref: String, folder: String) -> bool:
	return ref.begins_with(folder + "/") and _is_id(ref.substr(folder.length() + 1))


## Номери записів не повторюються в межах таблиці (а в нечисті — ще й окремо серед босів).
static func _unique_nums(name: String, rows: Dictionary) -> Array:
	var out := []
	var seen := {}
	var seen_boss := {}
	var span: Array = NUM_RANGES.get(name, [])
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("num"):
			var n := int(R["num"])
			if n <= 0:
				out.append("%s/%s: «num» має бути додатним" % [name, id])
			elif not span.is_empty() and (n < int(span[0]) or n > int(span[1])):
				out.append("%s/%s: номер %d поза проміжком таблиці %d–%d (NUM_RANGES)" % [name, id, n, int(span[0]), int(span[1])])
			elif seen.has(n):
				out.append("%s/%s: номер %d уже має «%s»" % [name, id, n, seen[n]])
			else:
				seen[n] = id
		if name == "mobs" and R.has("boss") and R["boss"].has("num"):
			var n := int(R["boss"]["num"])
			if n <= 0:
				out.append("mobs/%s: «boss.num» має бути додатним" % id)
			elif n < int(BOSS_NUM_RANGE[0]) or n > int(BOSS_NUM_RANGE[1]):
				out.append("mobs/%s: номер боса %d поза проміжком %d–%d" % [id, n, int(BOSS_NUM_RANGE[0]), int(BOSS_NUM_RANGE[1])])
			elif seen_boss.has(n):
				out.append("mobs/%s: номер боса %d уже має «%s»" % [id, n, seen_boss[n]])
			else:
				seen_boss[n] = id
	return out


## Посилання з інших частин гри на записи таблиці: чи є все, на що посилаються.
static func _links(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"mobs":
			out.append_array(_mob_links(rows))
		"companions":
			out.append_array(_companion_links(rows))
		"heroes":
			out.append_array(_hero_links(rows))
		"pets":
			out.append_array(_pet_links(rows))
		_:
			if ITEM_TABLES.has(name):
				out.append_array(_item_links(name, rows))
			elif WORLD_TABLES.has(name):
				out.append_array(_world_links(name, rows))
	return out


## Чи є в таблиці name запис id (для перевірки посилань: таблиця вантажиться, як у грі).
static func _has_row(name: String, id) -> bool:
	return table(name).has(str(id))


## Клітинки, що вдягаються (мають «primary»), у порядку файлу.
static func _worn_slots() -> Array:
	var out := []
	for id in ids("gear_slots"):
		if row("gear_slots", id).has("primary"):
			out.append(id)
	return out


## Посилання таблиць речей на інші таблиці й на код гри.
static func _item_links(name: String, rows: Dictionary) -> Array:
	var out := []
	var worn := _worn_slots()
	var Classes = load("res://scripts/data/classes.gd")
	match name:
		"gear_slots":
			var any_worn := false
			for id in rows:
				var P: Dictionary = rows[id].get("primary", _EMPTY)
				any_worn = any_worn or not P.is_empty()
				if P.has("stat"):
					var B: Dictionary = row("bonuses", str(P["stat"]))
					if B.is_empty():
						out.append("gear_slots/%s: «primary.stat» — нема бонусу «%s» у bonuses.json" % [id, P["stat"]])
					elif bool(B.get("whole", false)) != P.has("every"):
						out.append("gear_slots/%s: «%s» %s, тож у «primary» потрібне %s" % [id, P["stat"], "цілий" if B.get("whole", false) else "дробовий", "«every»" if B.get("whole", false) else "«per_level»"])
			for need in ["weapon", load("res://scripts/data/artifacts.gd").SLOT]:
				if not rows.has(need):
					out.append("gear_slots: нема клітинки «%s», а код гри її знає" % need)
			if not any_worn:
				out.append("gear_slots: жодна клітинка не вдягається (нема «primary»)")
		"rarities":
			var Data = load("res://scripts/data/data.gd")
			var by_rank := {}
			for id in rows:
				by_rank[int(rows[id].get("rank", -1))] = rows[id]
			for r in by_rank:
				if by_rank[r].has("weight") != (r <= Data.RARITY_MAX_RANDOM):
					out.append("rarities: вагу («weight») мають рідкості 0–%d (Data.RARITY_MAX_RANDOM), і лише вони (ранг %d)" % [Data.RARITY_MAX_RANDOM, r])
			for r in [Data.RARITY_MAX_RANDOM, load("res://scripts/data/uniques.gd").RARITY, load("res://scripts/data/artifacts.gd").RARITY]:
				if not by_rank.has(r):
					out.append("rarities: нема рідкості з рангом %d, а код гри її знає" % r)
			if by_rank.has(Data.RARITY_MAX_RANDOM) and by_rank[Data.RARITY_MAX_RANDOM].get("epithets", []).is_empty():
				out.append("rarities: найвища випадкова рідкість (ранг %d) потребує «epithets»" % Data.RARITY_MAX_RANDOM)
		"weapons":
			for cls in Classes.CLASSES:
				for w in Classes.CLASSES[cls].get("weapons", []):
					if not rows.has(w):
						out.append("клас %s носить зброю «%s», якої нема у weapons.json" % [cls, w])
			for w in load("res://scripts/data/costumes.gd").WEAPONS:
				if not rows.has(w):
					out.append("Costumes.WEAPONS: зброї «%s» нема у weapons.json" % w)
		"armors":
			var have := {}
			for id in rows:
				var s := str(rows[id].get("slot", ""))
				have[s] = true
				if not s in worn or s == "weapon":
					out.append("armors/%s: «slot» — «%s» не клітинка обладунку (gear_slots.json з «primary», не зброя)" % [id, s])
			for s in worn:
				if s != "weapon" and not have.has(s):
					out.append("armors: клітинка «%s» без жодної основи, випадкова річ для неї не складеться" % s)
		"bonuses":
			var pool := 0
			for id in rows:
				pool += 1 if rows[id].get("affix", false) else 0
			if not rows.is_empty() and pool < load("res://scripts/data/data.gd").RARITY_MAX_RANDOM + 1:
				out.append("bonuses: замало «affix» — легендарна річ кидає %d властивості після головної" % load("res://scripts/data/data.gd").RARITY_MAX_RANDOM)
		"sharpening":
			var Data = load("res://scripts/data/data.gd")
			if rows.size() != Data.MAX_UPGRADE:
				out.append("sharpening: %d записів, а заточка має %d щаблів (Data.MAX_UPGRADE)" % [rows.size(), Data.MAX_UPGRADE])
		"golden_tiers":
			var U = load("res://scripts/data/uniques.gd")
			if rows.size() < U.TOP_COMMON_TIER:
				out.append("golden_tiers: менше ступенів, ніж Uniques.TOP_COMMON_TIER (%d)" % U.TOP_COMMON_TIER)
		"soul_tiers":
			var S = load("res://scripts/data/souls.gd")
			if rows.size() < S.BOSS_TIER:
				out.append("soul_tiers: менше ступенів, ніж Souls.BOSS_TIER (%d)" % S.BOSS_TIER)
		"soul_effects":
			for id in rows:
				if id in load("res://scripts/data/souls.gd").FORBIDDEN:
					out.append("soul_effects/%s: душі не дають такого (Souls.FORBIDDEN): гра не має ставати легшою" % id)
		"shop_kinds":
			var SS = load("res://scripts/game/shop_service.gd")
			for id in rows:
				if SS.ids(id).is_empty():
					out.append("shop_kinds/%s: крамниця не знає такого розділу (ShopService.ids порожній)" % id)
			for need in [["set", "price"], ["set", "full_price"], ["artifact", "price"], ["artifact", "peril_price"]]:
				if rows.has(need[0]) and not rows[need[0]].has(need[1]):
					out.append("shop_kinds/%s: потрібна «%s»" % need)
		"golden":
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "golden/" + id
				if R.has("slot") and not str(R["slot"]) in worn:
					out.append("%s: «slot» — «%s» не клітинка спорядження" % [where, R["slot"]])
				if R.has("type") and not _has_row("weapons", R["type"]):
					out.append("%s: «type» — нема зброї «%s» у weapons.json" % [where, R["type"]])
				if R.has("tier") and not _tier_exists("golden_tiers", int(R["tier"])):
					out.append("%s: «tier» %d — нема такого ступеня в golden_tiers.json" % [where, int(R["tier"])])
				for b in R.get("bosses", []):
					_need_boss(b, "золота річ %s" % id, out)
				var P: Dictionary = row("powers", str(R.get("power", "")))
				if P.is_empty():
					out.append("%s: «power» — нема сили «%s» у powers.json" % [where, R.get("power", "")])
				else:
					var kinds: Dictionary = P["params"]
					for k in R.get("params", _EMPTY):
						if not kinds.has(k):
							out.append("%s: сила «%s» не має параметра «%s»" % [where, R["power"], k])
						elif str(kinds[k]) == "int" and float(R["params"][k]) != floorf(float(R["params"][k])):
							out.append("%s: «params.%s» має бути цілим (так каже сила «%s»)" % [where, k, R["power"]])
					for k in kinds:
						if not R.get("params", _EMPTY).has(k):
							out.append("%s: бракує параметра «%s» сили «%s»" % [where, k, R["power"]])
				for k in R.get("affixes", _EMPTY):
					var B: Dictionary = row("bonuses", k)
					if B.is_empty():
						out.append("%s: «affixes» — нема бонусу «%s» у bonuses.json" % [where, k])
					elif not B.get("whole", false) and not B.has("mid"):
						out.append("%s: бонус «%s» не має «mid» (середини кидка для золотих речей)" % [where, k])
		"sets":
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "sets/" + id
				if R.has("stat") and not _has_row("bonuses", R["stat"]):
					out.append("%s: «stat» — нема бонусу «%s»" % [where, R["stat"]])
				for k in R.get("affixes", []):
					if not row("bonuses", str(k)).has("roll"):
						out.append("%s: «affixes» — бонус «%s» не кидається (нема в bonuses.json чи без «roll»)" % [where, k])
				for st in R.get("bonus", []):
					for k in st["fx"]:
						if not _has_row("set_effects", k):
							out.append("%s: бонус «%s» — нема в set_effects.json" % [where, k])
		"artifacts":
			var by_boss := {}
			for id in rows:
				var b := str(rows[id].get("boss", ""))
				_need_boss(b, "артефакт %s" % id, out)
				if by_boss.has(b):
					out.append("artifacts/%s: у боса «%s» уже є артефакт «%s» (діє лише перший)" % [id, b, by_boss[b]])
				by_boss[b] = id
		"souls":
			for id in rows:
				var R: Dictionary = rows[id]
				if R.has("tier") and not _tier_exists("soul_tiers", int(R["tier"])):
					out.append("souls/%s: «tier» %d — нема такого ступеня в soul_tiers.json" % [id, int(R["tier"])])
				for k in R.get("fx", _EMPTY):
					if not _has_row("soul_effects", k):
						out.append("souls/%s: «fx» — бонусу «%s» нема в soul_effects.json" % [id, k])
				if str(id).begins_with("b_"):
					_need_boss(str(id).substr(2), "душа %s" % id, out)
				elif not has_mob(id):
					out.append("душа %s посилається на нечисть «%s», якої немає в mobs.json" % [id, id])
				elif not mob(id).has("name"):
					out.append("душа %s: у «%s» нема поля «name»" % [id, id])
		"enchants":
			for id in rows:
				for s in rows[id].get("slots", []):
					if not s in worn:
						out.append("enchants/%s: «slots» — «%s» не клітинка спорядження" % [id, s])
				for k in rows[id].get("fx", _EMPTY):
					if not Classes.FX_TEXT.has(k):
						out.append("enchants/%s: «fx» — ключа «%s» нема в Classes.FX_TEXT" % [id, k])
		"gifts":
			for id in rows:
				if rows[id].has("slot") and not _has_row("gift_slots", rows[id]["slot"]):
					out.append("gifts/%s: «slot» — нема гнізда «%s» у gift_slots.json" % [id, rows[id]["slot"]])
				for k in rows[id].get("fx", _EMPTY):
					if not Classes.FX_TEXT.has(k):
						out.append("gifts/%s: «fx» — ключа «%s» нема в Classes.FX_TEXT" % [id, k])
	return out


## Чи є ступінь t у таблиці ступенів (golden_tiers, soul_tiers).
static func _tier_exists(name: String, t: int) -> bool:
	for id in ids(name):
		if int(row(name, id).get("tier", -1)) == t:
			return true
	return false


## Посилання речі на боса: вид є в mobs.json і має запис «boss» (той самий текст, що й у _mob_links).
static func _need_boss(kind, what: String, out: Array) -> void:
	if not has_mob(str(kind)):
		out.append("%s посилається на нечисть «%s», якої немає в mobs.json" % [what, kind])
	elif not has_boss(str(kind)):
		out.append("%s: «%s» тут бос, але в mobs.json у нього нема запису «boss»" % [what, kind])


static func _mob_links(rows: Dictionary) -> Array:
	var out := []
	var need := func(id, what: String, field: String = "") -> void:
		var R: Dictionary = rows.get(str(id), {})
		if R.is_empty():
			out.append("%s посилається на нечисть «%s», якої немає в mobs.json" % [what, id])
		elif field == "boss" and not R.has("boss"):
			out.append("%s: «%s» тут бос, але в mobs.json у нього нема запису «boss»" % [what, id])
		elif field != "" and field != "boss" and not R.has(field):
			out.append("%s: у «%s» нема поля «%s»" % [what, id, field])
	# Місця (поля, печери, поверхи Башти й Глибин) — та сама перевірка, що й у таблиці місць (_world_links)
	out.append_array(_place_mob_links(table("places"), rows))
	var Acts = load("res://scripts/data/activities.gd")
	var BossS = load("res://scripts/game/boss_service.gd")
	for b in Acts.RING_POOL:
		need.call(b, "Коло Кожум'яки", "boss")
	for b in BossS.POOL:
		need.call(b, "Боси дня й тижня", "boss")
	for k in load("res://scripts/game/stone_service.gd").FIRST_KILL:
		need.call(k, "камінь за першу перемогу", "boss")
	# Речі, що посилаються на нечисть (ті самі перевірки є й у самих таблицях речей, див. _item_links)
	for u in ids("golden"):
		for b in row("golden", u).get("bosses", []):
			need.call(b, "золота річ %s" % u, "boss")
	for a in ids("artifacts"):
		need.call(row("artifacts", a).get("boss", ""), "артефакт %s" % a, "boss")
	for s in ids("souls"):
		if str(s).begins_with("b_"):
			need.call(str(s).substr(2), "душа %s" % s, "boss")
		else:
			need.call(s, "душа %s" % s, "name")
	var Wiki = load("res://scripts/data/wiki_data.gd")
	for k in Wiki.ENEMY_ORDER:
		need.call(k, "довідник (нечисть)", "wiki")
	for k in Wiki.BOSS_ORDER:
		need.call(k, "довідник (боси)", "boss")
		if rows.has(k) and rows[k].has("boss") and not rows[k]["boss"].has("wiki"):
			out.append("довідник (боси): у «%s» нема «boss.wiki»" % k)
	out.append_array(_mechanic_links(rows))
	# Зворотні перевірки: те, що є в записі, мусить мати сенс для гри
	var Status = load("res://scripts/game/status.gd")
	var Index = load("res://scripts/data/sound_index.gd")
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("hit_status") and not Status.INFO.has(R["hit_status"]):
			out.append("mobs/%s: невідомий стан «%s» (див. Status.INFO)" % [id, R["hit_status"]])
		var snd := str(R.get("sounds", {}).get("death", ""))
		if snd != "" and not Index.SFX.has(snd):
			out.append("mobs/%s: невідомий звук «%s» (див. SoundIndex.SFX)" % [id, snd])
		if R.has("wiki") and not id in Wiki.ENEMY_ORDER:
			out.append("mobs/%s: опис у довіднику є, а в Wiki.ENEMY_ORDER виду нема, тож його не видно" % id)
		if R.has("boss") and R["boss"].has("wiki") and not id in Wiki.BOSS_ORDER:
			out.append("mobs/%s: опис боса є, а в Wiki.BOSS_ORDER його нема, тож його не видно" % id)
	return out


## Механіки нечисті: кожне посилання веде на файл, що походить від Mechanic, і кожен файл у mob/ і
## boss/ має запис, який на нього посилається (без сиріт).
static func _mechanic_links(rows: Dictionary) -> Array:
	var out := []
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("mechanic"):
			_mechanic_ref("mobs/" + id, "mechanic", str(R["mechanic"]), used, out)
		if R.has("boss") and R["boss"].has("mechanic"):
			_mechanic_ref("mobs/" + id, "boss.mechanic", str(R["boss"]["mechanic"]), used, out)
	out.append_array(_mechanic_orphans(["mob", "boss"], used, "mobs.json"))
	return out


## Одне посилання на механіку: файл є й походить від основи своєї теки (MECHANIC_BASES).
## Лише для перевірки: під час гри теки не переглядаються.
static func _mechanic_ref(where: String, field: String, ref: String, used: Dictionary, out: Array) -> void:
	used[ref] = true
	var Loader = load("res://scripts/mechanics/loader.gd")
	var path: String = Loader.path_of(ref)
	if not ResourceLoader.exists(path):
		out.append("%s: «%s» посилається на %s, а такого файлу нема" % [where, field, path])
		return
	var base: String = MECHANIC_BASES.get(ref.get_slice("/", 0), "")
	var s = load(path)
	if base == "" or not s is Script or not Loader.extends_base(s, base):
		out.append("%s: %s — не механіка (має походити від %s)" % [where, path, base])


## Файли механік у теках, на які не посилається жоден запис таблиці (сироти).
static func _mechanic_orphans(folders: Array, used: Dictionary, file: String) -> Array:
	var out := []
	var Loader = load("res://scripts/mechanics/loader.gd")
	for folder in folders:
		for ref in mechanic_files(folder):
			if not used.has(ref):
				out.append("механіка %s нікому не потрібна: жоден запис %s на неї не посилається" % [Loader.path_of(ref), file])
	return out


## Файли механік у теці (mob, boss, companion, pet) як посилання ("mob/chort"). Лише для перевірки й
## інструментів: у збірці теки містять .gdc і .remap, тож гра механік так не шукає.
static func mechanic_files(folder: String) -> Array:
	var out := []
	var dir := "res://scripts/mechanics/" + folder
	for f in DirAccess.get_files_at(dir):
		f = f.trim_suffix(".remap")
		if f.ends_with(".gd") or f.ends_with(".gdc"):
			var ref := folder + "/" + f.get_basename()
			if not ref in out:
				out.append(ref)
	out.sort()
	return out


static func _companion_links(rows: Dictionary) -> Array:
	var out := []
	var Data = load("res://scripts/data/data.gd")
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		var lv := int(R.get("hire", _EMPTY).get("loyalty", 0))
		if lv < 0 or lv >= Data.LOYALTY_NAMES.size():
			out.append("companions/%s: «hire.loyalty» має бути від 0 до %d (Data.LOYALTY_NAMES)" % [id, Data.LOYALTY_NAMES.size() - 1])
		if R.has("mechanic"):
			_mechanic_ref("companions/" + id, "mechanic", str(R["mechanic"]), used, out)
	out.append_array(_mechanic_orphans(["companion"], used, "companions.json"))
	return out


static func _hero_links(rows: Dictionary) -> Array:
	var out := []
	var Story = load("res://scripts/data/story.gd")
	var steps := {}  # id кроку сюжету → скільки в нього виборів
	for ch in Story.CHAPTERS:
		for st in ch["steps"]:
			steps[st["id"]] = st.get("choices", []).size()
	for id in rows:
		var R: Dictionary = rows[id]
		var where: String = "heroes/" + id
		if R.has("base") and not table("companions").has(R["base"]):
			out.append("%s: «base» посилається на найманця «%s», якого немає в companions.json" % [where, R["base"]])
		if table("companions").has(id):
			out.append("%s: id збігається з найманцем (вигляд comp_<id> був би спільний)" % where)
		var j: Dictionary = R.get("join", _EMPTY)
		if j.has("city") and not _has_row("cities", j["city"]):
			out.append("%s: «join.city» — невідоме місто «%s»" % [where, j["city"]])
		if j.has("after") and not steps.has(j["after"]):
			out.append("%s: «join.after» — нема кроку сюжету «%s»" % [where, j["after"]])
		if j.has("if"):
			var parts: PackedStringArray = str(j["if"]).split("=")
			if parts.size() != 2 or not parts[1].is_valid_int():
				out.append("%s: «join.if» має бути \"крок=номер вибору\", а не «%s»" % [where, j["if"]])
			elif not steps.has(parts[0]) or int(parts[1]) < 0 or int(parts[1]) >= int(steps[parts[0]]):
				out.append("%s: «join.if» — нема кроку «%s» із вибором %s" % [where, parts[0], parts[1]])
		var dl := _hero_dialogues(R)
		for k in dl:
			for i in dl[k].size():
				if not Story.NPCS.has(dl[k][i][0]):
					out.append("%s: «%s[%d]» — мовця «%s» нема в Story.NPCS" % [where, k, i, dl[k][i][0]])
		var o: Dictionary = R.get("quest", _EMPTY).get("objective", _EMPTY)
		if o.has("loc"):
			var L: Dictionary = row("places", str(o["loc"]))
			if L.is_empty():
				out.append("%s: «quest.objective.loc» — нема місця «%s»" % [where, o["loc"]])
			else:
				var ot := str(o.get("type", ""))
				if ot == "clear" and str(L.get("type", "")) == "dungeon":
					out.append("%s: «%s» — печера, її проходять метою «dungeon», а не «clear»" % [where, o["loc"]])
				if ot == "dungeon" and str(L.get("type", "")) != "dungeon":
					out.append("%s: «%s» — не печера" % [where, o["loc"]])
				if o.has("enemy") and not o["enemy"] in L.get("enemies", []):
					out.append("%s: «%s» не водиться в «%s»" % [where, o["enemy"], o["loc"]])
		if o.has("enemy") and not has_mob(str(o["enemy"])):
			out.append("%s: «quest.objective.enemy» посилається на нечисть «%s», якої немає в mobs.json" % [where, o["enemy"]])
	return out


static func _pet_links(rows: Dictionary) -> Array:
	var out := []
	var Camp = load("res://scripts/data/camp_data.gd")
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		var where: String = "pets/" + id
		for r in R.get("stable", _EMPTY).get("res", _EMPTY):
			if not Camp.RESOURCES.has(r) and r != Camp.TROPHY:
				out.append("%s: «stable.res» — невідомий ресурс «%s» (див. CampData.RESOURCES)" % [where, r])
		if R.has("gift"):
			if not _has_row("gifts", id):
				out.append("%s: божого дару «%s» нема в gifts.json" % [where, id])
			elif not str(row("gifts", id).get("slot", "")) in PET_GIFT_SLOTS:
				out.append("%s: дар «%s» лежить у гнізді «%s», а супутники бувають лише в %s" % [where, id, row("gifts", id).get("slot", ""), str(PET_GIFT_SLOTS)])
		if R.has("mechanic"):
			_mechanic_ref(where, "mechanic", str(R["mechanic"]), used, out)
	# Кожен дар-супутник (гнізда «Супутник» і «Віз») має запис, інакше в бою його не видно
	for d in ids("gifts"):
		if str(row("gifts", d).get("slot", "")) in PET_GIFT_SLOTS and not rows.has(d):
			out.append("божий дар «%s» (гніздо «%s») не має запису в pets.json, тож у бою його не видно" % [d, row("gifts", d).get("slot", "")])
	out.append_array(_mechanic_orphans(["pet"], used, "pets.json"))
	return out


# ---------- Світ: правила й посилання ----------

## Таблиці світу: їхні правила — _world_rules, посилання — _world_links.
const WORLD_TABLES := ["regions", "cities", "places", "lands", "biomes", "elite_affixes"]
## Рядкові поля записів світу, які не можуть бути порожні.
const _WORLD_TEXTS := ["name", "desc", "hall", "title", "ambient", "icon", "dungeon_icon", "status", "resource", "region", "land", "boss", "biome"]


## Правила таблиць світу, що не залежать від інших таблиць.
static func _world_rules(name: String, rows: Dictionary) -> Array:
	var out := []
	for id in rows:
		var R: Dictionary = rows[id]
		var where := "%s/%s" % [name, id]
		_not_blank(R, _WORLD_TEXTS, where, out)
		for k in R:
			if R[k] is bool and not R[k]:
				out.append("%s: «%s» пишеться лише як true" % [where, k])
		match name:
			"cities":
				_positive(R, ["level"], where, out)
			"places":
				_positive(R, ["level", "goal", "rooms", "peril"], where, out)
				if R.get("enemies", []).is_empty():
					out.append("%s: «enemies» порожні" % where)
				var dungeon := str(R.get("type", "")) == "dungeon"
				for k in ["rooms", "boss"]:
					if dungeon and not R.has(k):
						out.append("%s: печера потребує «%s»" % [where, k])
					if not dungeon and R.has(k):
						out.append("%s: «%s» буває лише в печери" % [where, k])
				if R.has("goal") and dungeon:
					out.append("%s: «goal» (зачистка) буває лише в поля" % where)
				if R.has("peril") != R.has("land"):
					out.append("%s: надважка печера має і «peril», і «land»" % where)
				if R.has("peril") and not dungeon:
					out.append("%s: надважкою буває лише печера" % where)
				if R.has("region") != R.get("scale", false):
					out.append("%s: місце далекого краю має і «region», і «scale» (росте з героєм), а інші — жодного" % where)
				if R.get("endless", false) != R.has("floors"):
					out.append("%s: безкінечне місце («endless») описує поверхи в «floors», і лише воно" % where)
				if R.get("tower", false) and not R.get("endless", false):
					out.append("%s: «tower» буває лише в безкінечного місця" % where)
				var F: Dictionary = R.get("floors", _EMPTY)
				if F.has("titles") != R.get("tower", false):
					out.append("%s: прізвиська міні-босів («floors.titles») має Башта («tower»), і лише вона" % where)
				for k in ["pool", "bosses", "titles"]:
					if F.has(k) and F[k].is_empty():
						out.append("%s: «floors.%s» порожні" % [where, k])
				if F.has("pool") and F["pool"].size() < 4:
					out.append("%s: «floors.pool» — замало нечисті: поверх бере трьох рядових і міні-боса" % where)
				if R.has("plague_start"):
					var PS = load("res://scripts/game/plague_service.gd")
					if int(R["plague_start"]) < 1 or int(R["plague_start"]) > PS.MAX_LEVEL:
						out.append("%s: «plague_start» має бути від 1 до %d" % [where, PS.MAX_LEVEL])
					if R.get("endless", false) or R.has("peril"):
						out.append("%s: зараза не осідає в безкінечних і надважких місцях" % where)
			"lands":
				if R.get("title_fx", _EMPTY).is_empty():
					out.append("%s: «title_fx» порожній" % where)
				for k in R.get("title_fx", _EMPTY):
					if int(R["title_fx"][k]) <= 0:
						out.append("%s: «title_fx.%s» має бути більшим за нуль" % [where, k])
	if name == "places":
		out.append_array(_contiguous(name, rows, "peril", 1))
	return out


## Межі мапи (довгота, широта): WorldMap.LON0..LON1, LAT0..LAT1.
static func _in_map(p: Vector2) -> bool:
	var WM = load("res://scripts/ui/world_map.gd")
	return p.x >= WM.LON0 and p.x <= WM.LON1 and p.y >= WM.LAT0 and p.y <= WM.LAT1


## Посилання місць на нечисть: рядова має ім'я, множину й трофей (завдання), бос — запис «boss».
## Ту саму перевірку роблять і таблиця нечисті (зникла нечисть), і таблиця місць (хибне посилання).
static func _place_mob_links(places: Dictionary, mobs: Dictionary) -> Array:
	var out := []
	for lid in places:
		var L: Dictionary = places[lid]
		var F: Dictionary = L.get("floors", _EMPTY)
		var groups := [["місце %s" % lid, L.get("enemies", []), ["name", "plural", "quest_item"]],
			["місце %s (поверхи)" % lid, F.get("pool", []), ["name"]],
			["місце %s (бос)" % lid, [L["boss"]] if L.has("boss") else [], ["boss"]],
			["місце %s (боси поверхів)" % lid, F.get("bosses", []), ["boss"]]]
		for g in groups:
			for e in g[1]:
				var R: Dictionary = mobs.get(str(e), _EMPTY)
				if R.is_empty():
					out.append("%s посилається на нечисть «%s», якої немає в mobs.json" % [g[0], e])
					continue
				for f in g[2]:
					if f == "boss" and not R.has("boss"):
						out.append("%s: «%s» тут бос, але в mobs.json у нього нема запису «boss»" % [g[0], e])
					elif f != "boss" and not R.has(f):
						out.append("%s: у «%s» нема поля «%s»" % [g[0], e, f])
	return out


## Посилання таблиць світу на інші таблиці й на код гри.
static func _world_links(name: String, rows: Dictionary) -> Array:
	var out := []
	var WM = load("res://scripts/ui/world_map.gd")
	match name:
		"regions":
			for id in rows:
				var used := false
				for t in ["cities", "places"]:
					for x in ids(t):
						used = used or str(row(t, x).get("region", "")) == id
				if not used:
					out.append("regions/%s: у краї нема жодного міста чи місця" % id)
		"cities":
			for id in rows:
				var R: Dictionary = rows[id]
				if R.has("region") and not _has_row("regions", R["region"]):
					out.append("cities/%s: «region» — нема краю «%s» у regions.json" % [id, R["region"]])
				if R.has("pos") and not _in_map(R["pos"]):
					out.append("cities/%s: «pos» %s поза мапою (WorldMap.LON0..LON1, LAT0..LAT1)" % [id, str(R["pos"])])
				if _has_row("places", id):
					out.append("cities/%s: місце з таким самим id уже є в places.json" % id)
		"places":
			out.append_array(_place_mob_links(rows, table("mobs")))
			var land_order: Array = ids("lands")
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "places/" + id
				if R.has("biome") and not _has_row("biomes", R["biome"]):
					out.append("%s: «biome» — нема краєвиду «%s» у biomes.json" % [where, R["biome"]])
				if R.has("region") and not _has_row("regions", R["region"]):
					out.append("%s: «region» — нема краю «%s» у regions.json" % [where, R["region"]])
				if R.has("land"):
					var i := land_order.find(str(R["land"]))
					if i < 0:
						out.append("%s: «land» — нема землі «%s» у lands.json" % [where, R["land"]])
					elif R.has("peril") and int(R["peril"]) != i + 1:
						out.append("%s: «peril» %d, а земля «%s» стоїть у lands.json %d-ю: печери відкриваються в порядку земель" % [where, int(R["peril"]), R["land"], i + 1])
				if R.has("icon") and not str(R["icon"]) in WM.ICON_ORDER:
					out.append("%s: «icon» — нема значка «%s» у WorldMap.ICON_ORDER" % [where, R["icon"]])
				if R.has("pos") and not _in_map(R["pos"]):
					out.append("%s: «pos» %s поза мапою (WorldMap.LON0..LON1, LAT0..LAT1)" % [where, str(R["pos"])])
		"lands":
			var Valor = load("res://scripts/data/valor.gd")
			for id in rows:
				var n := 0
				for p in ids("places"):
					if str(row("places", p).get("land", "")) == id:
						n += 1
				if n != 1:
					out.append("lands/%s: у землі має бути рівно одна надважка печера («land» у places.json), а їх %d" % [id, n])
				for k in rows[id].get("title_fx", _EMPTY):
					if not Valor.LINES.has(k) and not Valor.EXTRA_TEXT.has(k):
						out.append("lands/%s: «title_fx» — ключа «%s» нема ні у Valor.LINES, ні у Valor.EXTRA_TEXT" % [id, k])
		"biomes":
			var Index = load("res://scripts/data/sound_index.gd")
			var Camp = load("res://scripts/data/camp_data.gd")
			var Ground = load("res://scripts/world/ground.gd")
			for id in rows:
				var R: Dictionary = rows[id]
				if R.has("ambient") and not str(R["ambient"]) in Index.AMBIENT:
					out.append("biomes/%s: «ambient» — нема шуму «%s» у SoundIndex.AMBIENT" % [id, R["ambient"]])
				if R.has("resource") and not Camp.RESOURCES.has(R["resource"]):
					out.append("biomes/%s: «resource» — невідомий ресурс «%s» (CampData.RESOURCES)" % [id, R["resource"]])
				for k in ["icon", "dungeon_icon"]:
					if R.has(k) and not str(R[k]) in WM.ICON_ORDER:
						out.append("biomes/%s: «%s» — нема значка «%s» у WorldMap.ICON_ORDER" % [id, k, R[k]])
				if not id in Ground.TILED:
					out.append("biomes/%s: земля цього краєвиду не намальована (Ground.TILED): новий краєвид потребує коду й тайлів" % id)
		"elite_affixes":
			var Status = load("res://scripts/game/status.gd")
			for id in rows:
				if rows[id].has("status") and not Status.INFO.has(rows[id]["status"]):
					out.append("elite_affixes/%s: невідомий стан «%s» (див. Status.INFO)" % [id, rows[id]["status"]])
	return out


# ---------- Нечисть ----------

## Запис нечисті (див. MOB_SCHEMA); для невідомого виду — порожній словник.
static func mob(id: String) -> Dictionary:
	return table("mobs").get(id, _EMPTY)


static func has_mob(id: String) -> bool:
	return table("mobs").has(id)


## Усі види нечисті в порядку файлу.
static func mob_ids() -> Array:
	return ids("mobs")


## Вид нечисті за сталим номером запису ("" — такого нема).
static func mob_by_num(n: int) -> String:
	return by_num("mobs", n)


## Вид нечисті за сталим номером її боса ("" — такого нема).
static func boss_by_num(n: int) -> String:
	return str(_num_index("mobs", "boss").get(n, ""))


## Id запису таблиці за його сталим номером ("" — такого нема).
static func by_num(name: String, n: int) -> String:
	return str(_num_index(name, "").get(n, ""))


## Покажчик номер → id: за «num» запису, а sub — за «num» його вкладеного запису (боса).
static func _num_index(name: String, sub: String) -> Dictionary:
	var key := name + "/" + sub
	if not _nums.has(key):
		var idx := {}
		for id in ids(name):
			var R: Dictionary = row(name, id)
			var n = R.get("num") if sub == "" else R.get(sub, _EMPTY).get("num")
			if n != null and not idx.has(n):
				idx[n] = id
		idx.make_read_only()
		_nums[key] = idx
	return _nums[key]


## Види, що бувають іменними босами (мають запис «boss»).
static func boss_ids() -> Array:
	var out := []
	for id in mob_ids():
		if mob(id).has("boss"):
			out.append(id)
	return out


static func mob_name(id: String, fallback: String = "") -> String:
	return str(mob(id).get("name", fallback))


static func mob_plural(id: String, fallback: String = "") -> String:
	return str(mob(id).get("plural", fallback))


static func quest_item(id: String, fallback: String = "") -> String:
	return str(mob(id).get("quest_item", fallback))


static func has_boss(id: String) -> bool:
	return mob(id).has("boss")


static func boss_name(id: String, fallback: String = "") -> String:
	return str(mob(id).get("boss", _EMPTY).get("name", fallback))


## Ступінь боса для золотих речей; 0 — власного нема.
static func boss_tier(id: String) -> int:
	return int(mob(id).get("boss", _EMPTY).get("tier", 0))


static func is_phase2_boss(id: String) -> bool:
	return bool(mob(id).get("boss", _EMPTY).get("phase2", false))


## Стан, який накладає удар цього виду ("" — жодного).
## Імена для дошки розшуку (порожньо — вид не розшукують).
static func bounty_names(id: String) -> Array:
	return mob(id).get("bounty_names", _EMPTY_LIST)


static func hit_status(id: String) -> String:
	return str(mob(id).get("hit_status", ""))


## Посилання на механіку виду ("" — нема): boss — бойової форми боса, інакше звичайної.
static func mechanic(id: String, boss: bool = false) -> String:
	var R: Dictionary = mob(id).get("boss", _EMPTY) if boss else mob(id)
	return str(R.get("mechanic", ""))


## Голос смерті ("" — свого нема).
static func death_sound(id: String) -> String:
	return str(mob(id).get("sounds", _EMPTY).get("death", ""))


## Опис для довідника {text, tip}; порожній, якщо нема.
static func mob_wiki(id: String) -> Dictionary:
	return mob(id).get("wiki", _EMPTY)


static func boss_wiki(id: String) -> Dictionary:
	return mob(id).get("boss", _EMPTY).get("wiki", _EMPTY)


# ---------- Загін і улюбленці ----------

## Найманець (див. COMPANION_SCHEMA); для невідомого — порожній запис.
static func companion(id: String) -> Dictionary:
	return table("companions").get(id, _EMPTY)


## Найманці в порядку файлу (так їх показує корчма й довідник).
static func companion_ids() -> Array:
	return ids("companions")


## Побратим (див. HERO_SCHEMA); для невідомого — порожній запис.
static func hero(id: String) -> Dictionary:
	return table("heroes").get(id, _EMPTY)


## Побратими в порядку файлу.
static func hero_ids() -> Array:
	return ids("heroes")


## Улюбленець або супутник із дару (див. PET_SCHEMA); для невідомого — порожній запис.
static func pet(id: String) -> Dictionary:
	return table("pets").get(id, _EMPTY)


## Усі записи pets.json у порядку файлу (і стайня, і дари).
static func pet_ids() -> Array:
	return ids("pets")


# ---------- Речі ----------
# Записи речей (див. docs/data.md, «Речі»); для невідомого id — порожній запис. Зручні виклики поверх
# них — у модулях Data, Uniques, Sets, Artifacts, Souls, Enchants, Divine, Costumes, Shop.

## Клітинка спорядження (gear_slots.json).
static func gear_slot(id: String) -> Dictionary:
	return table("gear_slots").get(id, _EMPTY)


## Вид зброї (weapons.json).
static func weapon(id: String) -> Dictionary:
	return table("weapons").get(id, _EMPTY)


## Бонус речі (bonuses.json).
static func bonus(id: String) -> Dictionary:
	return table("bonuses").get(id, _EMPTY)


## Сила золотої речі (powers.json).
static func power(id: String) -> Dictionary:
	return table("powers").get(id, _EMPTY)


## Золота річ (golden.json).
static func golden(id: String) -> Dictionary:
	return table("golden").get(id, _EMPTY)


## Набір (sets.json).
static func item_set(id: String) -> Dictionary:
	return table("sets").get(id, _EMPTY)


## Артефакт (artifacts.json).
static func artifact(id: String) -> Dictionary:
	return table("artifacts").get(id, _EMPTY)


## Душа (souls.json).
static func soul(id: String) -> Dictionary:
	return table("souls").get(id, _EMPTY)


## Зачарування (enchants.json).
static func enchant(id: String) -> Dictionary:
	return table("enchants").get(id, _EMPTY)


## Божий дар (gifts.json).
static func gift(id: String) -> Dictionary:
	return table("gifts").get(id, _EMPTY)


## Вбрання (costumes.json).
static func costume(id: String) -> Dictionary:
	return table("costumes").get(id, _EMPTY)


## Записи таблиці-драбини за числовим полем: [запис для 0, для 1, ...]; пропуск — порожній запис.
## Так рідкість (rank), ступінь (tier) і заточка (up) читаються за числом, яке лежить у речі.
## Масив складається раз і заморожується; модулі тримають його в себе, тож у бою це читання з масиву.
static func ladder(name: String, field: String) -> Array:
	var key := name + "#" + field
	if not _nums.has(key):
		var out := []
		for id in ids(name):
			var R: Dictionary = row(name, id)
			if not R.has(field) or int(R[field]) < 0:
				continue
			var i := int(R[field])
			while out.size() <= i:
				out.append(_EMPTY)
			out[i] = R
		out.make_read_only()
		_nums[key] = out
	return _nums[key]
