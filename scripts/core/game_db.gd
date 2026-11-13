extends RefCounted
## База даних гри: сталі таблиці (нечисть, загін, речі, світ, уміння, завдання, заняття, свята, хутір, події,
## тексти довідника, звуки, слова для імен) лежать у data/*.json,
## окремо від коду. Цей модуль — єдиний вхід до них: вантажить кожну таблицю раз, коли вона вперше
## потрібна, зводить числа до потрібних типів за схемою й перевіряє записи (див. problems()).
## Записи, які віддає база, лише для читання: їх заморожено, і спроба змінити їх дає помилку.
## Опис полів, проміжки номерів і як додати нечисть чи річ — docs/data.md.

const DIR := "res://data/"
## Схеми налаштувань балансу (data/settings.json): у кожного запису своя (див. settings()).
const SettingsSchema := preload("res://scripts/core/settings_schema.gd")

## Схема запису: поле → {"type": ..., "required": true}. Типи: string, int, float, bool,
## color (масив [r, g, b] або [r, g, b, a] із часток 0..1, стає Color), record (вкладений запис
## зі своїми "fields"), vector (масив [x, y] із двох чисел, стає Vector2: довгота й широта на мапі),
## enum (рядок із переліку "values"), list (масив значень, кожне за описом "of";
## "size" — точна довжина; "sizes" — дозволені довжини; "items" — опис кожного місця окремо, як у [стан, секунд]),
## map (об'єкт {рядковий ключ: значення за описом "of"}; порядок ключів зберігається), rank (число вміння на
## ранзі: одне число або [основа, приріст за ранг]; стає float чи [float, float]), number (число, що буває і
## цілим, і дробовим: ціле стає int, решта — float).
## Порядок полів у схемі — порядок ключів у файлі (див. tools/data_format.gd).
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
	"hit_status": {"type": "string"},  # стан, який може накласти удар (statuses.json)
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
		"stones": {"type": "list", "of": {"type": "string"}},  # камені долі за першу перемогу (stones.json)
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
		"loyalty": {"type": "int", "required": true},  # потрібна лояльність міста: рівень із loyalty_levels.json (0–3)
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

## Репліка розмови: [мовець, текст]; мовець — id із speakers.json.
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
	"forge": {"type": "record", "fields": {  # є, якщо таку річ кують у кузні хутора (CraftService)
		"kuznia": {"type": "int", "required": true},  # потрібний рівень кузні
		"mult": {"type": "float", "required": true},  # множник ціни кування
		"trophy": {"type": "int", "required": true},  # трофеїв за кування
	}},
	"renew": {"type": "float"},  # множник ціни оновлення речі до свого рівня (CraftService.renew_step)
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
	"ranged": {"type": "bool"},  # б'є снарядами, дальність стала («shot_range»)
	"shot_range": {"type": "float"},  # дальність удару тим, що б'є снарядами (замість 95 × «range»)
	"agi": {"type": "bool"},  # сила від Спритності (стрільці)
	"stat": {"type": "enum", "values": ["str", "agi", "spi"]},  # що дає силу удару; без поля — «agi» → Спритність, інакше Сила
	"basic": {"type": "bool"},  # падає, коли гра не задала зброї під клас (Data.weapon_pool порожній)
	"mechanic": {"type": "string", "required": true},  # як б'є: "weapon/<вид>" у scripts/mechanics/ (див. WeaponMechanic)
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
	"mechanic": {"type": "string", "required": true},  # що робить у бою: "power/<id>" у scripts/mechanics/ (див. PowerMechanic)
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
	"fx": {"type": "map", "required": true, "of": {"type": "float"}},  # ключі бонусів (effects.json), як у пасивних умінь
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
	"fx": {"type": "map", "of": {"type": "float"}},  # бойові показники: ключі бонусів (effects.json)
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
	"title_fx": {"type": "map", "required": true, "of": {"type": "int"}},  # вічний бонус звитяги (ключі valor_lines.json), відсотки
}

## Краєвид місця: фоновий шум, ресурс для хутора, значок на мапі. Земля й частинки малюються кодом.
const BIOME_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (6501...)
	"name": {"type": "string", "required": true},
	"ambient": {"type": "string", "required": true},  # фоновий шум (SoundIndex.AMBIENT)
	"resource": {"type": "string"},  # що найчастіше дає хуторові (resources.json); без поля — дерево
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
	"status": {"type": "string"},  # стан, який накладає кожен удар (statuses.json)
	"desc": {"type": "string", "required": true},  # «підпалює»: у розшуку й довіднику
}

# ---------- Класи й уміння ----------

## Ступінь майстерності (0 — Селянин, 1 — клас, 2 — спеціалізація): крива досвіду рівня майстерності.
## Досвід до наступного рівня jl: base + per × jl + square × jl² (див. Classes.job_xp_for).
const JOB_TIER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8401...)
	"tier": {"type": "int", "required": true},
	"name": {"type": "string", "required": true},  # для людей; гра не показує
	"xp": {"type": "record", "required": true, "fields": {
		"base": {"type": "int", "required": true},
		"per": {"type": "int", "required": true},
		"square": {"type": "int", "required": true},
	}},
}

## Клас героя: усе про клас, разом із його власними правилами майстерності й назвами гілок дерева вмінь.
const CLASS_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (7001...)
	"name": {"type": "string", "required": true},
	"tier": {"type": "int", "required": true},  # ступінь (job_tiers.json): крива досвіду майстерності
	"job_max": {"type": "int", "required": true},  # найвищий рівень майстерності
	"change_at": {"type": "int"},  # з якого рівня майстерності можна обрати наступний клас (є лише з «next»)
	"next": {"type": "list", "required": true, "of": {"type": "string"}},  # куди можна піти далі (порядок — порядок показу)
	"parent": {"type": "string"},  # з якого класу спеціалізація (у класів першого ступеня поля нема)
	"weapons": {"type": "list", "required": true, "of": {"type": "string"}},  # дозволена зброя (weapons.json); перша — стартова
	"hp_mult": {"type": "float", "required": true},  # вроджені множники
	"dmg_mult": {"type": "float", "required": true},
	"mana_mult": {"type": "float", "required": true},
	"regen_mult": {"type": "float", "required": true},
	"skill_mult": {"type": "float"},  # множник сили вмінь (класи з посохом, див. docs/balance.md)
	"address": {"type": "string", "required": true},  # як до героя звертаються: «козаче»
	"where": {"type": "string"},  # місто посвяти й наставника (cities.json)
	"mentor": {"type": "string"},  # наставник спеціалізації (speakers.json)
	"branches": {"type": "list", "required": true, "of": {"type": "string"}},  # назви гілок дерева вмінь; «branch» уміння — номер у цьому списку від 1
	"desc": {"type": "string", "required": true},
}

## Число вміння на ранзі: одне число або [основа, приріст за кожен ранг понад перший] (Classes.val).
const RANK := {"type": "rank"}
## Бонуси «fx»: ключ (effects.json) → відсотки (за ранг; у підсиленнях — число чи [основа, приріст]).
const FX_MAP := {"type": "map", "of": RANK}

## Дія активного вміння за даними: шаблон (type) і його числа. Як шаблони діють — Player._act.
const ACT_SCHEMA := {"type": "record", "fields": {
	"type": {"type": "enum", "required": true, "values": ["nova", "leap", "cone", "shots", "zone", "buff", "summon"]},
	"at": {"type": "enum", "values": ["self", "enemy"]},  # де центр: на герої чи на найближчому ворогові
	"color": {"type": "string", "required": true},  # колір дії (hex, «c8a050»); кнопка — він же, темніший на чверть
	"range": RANK,  # як далеко шукати ціль
	"reach": RANK,  # cone: довжина удару
	"arc": RANK,  # cone: ширина в градусах
	"radius": RANK,
	"pct": RANK,  # множник шкоди зброї
	"count": RANK,  # shots: снарядів
	"spread": RANK,  # shots: віяло, радіани
	"explode": RANK,  # shots: радіус вибуху снаряда
	"pierce": {"type": "int"},  # shots: крізь скількох летить
	"stun": RANK,  # приголомшення, с
	"status": {"type": "list", "items": [{"type": "string"}, {"type": "float"}]},  # [стан (statuses.json), секунд]
	"kb": {"type": "float"},  # відкидання
	"pull": {"type": "bool"},  # стягує до центру замість відкидати
	"dur": RANK,  # тривалість, с
	"tick": {"type": "float"},  # zone, summon: с між ударами
	"heal": RANK,  # buff: лікує відсотків здоров'я
	"invuln": RANK,  # buff: невразливість, с
	"cleanse": {"type": "bool"},  # buff: знімає стани
	"group": {"type": "string"},  # buff: діє лише одне підсилення групи (стійки)
	"fx": FX_MAP,  # buff: бонуси на час дії
	"boost": {"type": "string"},  # summon: уміння, що підсилює помічника (+12% за ранг)
	"mark": {"type": "string"},  # summon: уміння, з яким помічник проклинає ціль
	"text": {"type": "string"},  # напис над героєм
	"sound": {"type": "string"},
	"shake": {"type": "float"},  # трусіння екрана
}}

## Вузол дерева вмінь класу. Порядок записів у файлі — порядок показу: клас за класом, гілка за гілкою.
## Ключ запису — id уміння, ранги якого зберігає герой; той самий id в іншому класі має ключ
## «<id>_<клас>» і поле «skill» (вузли ділять ранги, як «Смертельний удар» козака й пластуна).
const SKILL_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (7101...)
	"class": {"type": "string", "required": true},  # чиє дерево (classes.json)
	"branch": {"type": "int", "required": true},  # гілка: номер у «branches» класу, від 1
	"skill": {"type": "string"},  # id уміння, якщо ключ запису інший (див. вище)
	"name": {"type": "string", "required": true},
	"max": {"type": "int", "required": true},  # найвищий ранг
	"req": {"type": "map", "required": true, "of": {"type": "int"}},  # що треба вивчити раніше: id → ранг
	"active": {"type": "bool"},  # кнопка в бою
	"cost": {"type": "int"},  # активне: наснага
	"cd": {"type": "float"},  # активне: перезарядка, с (до поправок героя)
	"label": {"type": "string"},  # активне: підпис на кнопці бою
	"color": {"type": "color"},  # колір кнопки бою (без поля — колір дії «act», темніший)
	"kind": {"type": "enum", "values": ["attack", "buff"]},  # панель: атаки біля «Удару» чи підсилення знизу
	"heals": {"type": "bool"},  # вертає героєві здоров'я (авто-бафи Німба лікують лише пораненого)
	"scales": {"type": "string"},  # картка вміння: від чого росте сила («—» — ні від чого)
	"what": {"type": "string"},  # картка вміння: що робить, без цифр
	"mechanic": {"type": "string"},  # активне з власною дією: "skill/<id>" у scripts/mechanics/ (див. SkillMechanic)
	"act": ACT_SCHEMA,  # активне за даними: дію робить шаблон act/<type> у scripts/mechanics/ (див. ActMechanic)
	"fx": FX_MAP,  # пасивне: бонуси за кожен ранг
	"when": {"type": "record", "fields": {  # пасивне діє лише за умови
		"weapon": {"type": "list", "required": true, "of": {"type": "string"}},  # з такою зброєю в руках
	}},
	"desc": {"type": "string", "required": true},  # опис у дереві ("\n" — розрив рядка)
}

## Ключ бонусу «fx» (пасивні вміння, підсилення, зачарування, божі дари) і його текст: %s — число.
const EFFECT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8001...)
	"text": {"type": "string", "required": true},
}

## Гілка Загартування (спільного для всіх класів дерева).
const PERK_BRANCH_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8091...)
	"name": {"type": "string", "required": true},
}

## Вміння Загартування. Порядок файлу — порядок показу: гілка за гілкою, ярус за ярусом.
const PERK_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8101...)
	"branch": {"type": "string", "required": true},  # гілка (perk_branches.json)
	"tier": {"type": "int", "required": true},  # ярус від 1; ярус N відкривають (N − 1) × Data.PERK_TIER_STEP очок у гілці
	"name": {"type": "string", "required": true},
	"max": {"type": "int", "required": true},
	"desc": {"type": "string", "required": true},
}

## Характеристика героя (Сила, Спритність...): назва й опис на екрані героя. Що вона дає — Player.recalc.
const BASE_STAT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8201...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},
}

## Лінія звитяги (у неї вкладають очки) або бонус, що буває лише в іменних звитяг («named»).
const VALOR_LINE_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8251...)
	"name": {"type": "string"},  # лінія: назва
	"named": {"type": "bool"},  # лише в іменних звитяг (title_fx землі), очок у неї не вкладають
	"text": {"type": "string", "required": true},  # %s — відсотки
	"per": {"type": "float"},  # лінія: відсотків за очко
}

## Картка дороги (вибір класу на Січі) чи спеціалізації (вкладка наставника). Ключ — id класу.
const PATH_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8301...)
	"title": {"type": "string", "required": true},
	"where": {"type": "string", "required": true},
	"style": {"type": "string", "required": true},
	"strong": {"type": "list", "required": true, "of": {"type": "string"}},
	"weak": {"type": "list", "required": true, "of": {"type": "string"}},
	"skills": {"type": "list", "required": true, "of": {"type": "string"}},
	"next": {"type": "list", "required": true, "of": {"type": "string"}},
	"for": {"type": "string", "required": true},
	"rep": {"type": "string"},  # картка вибору дороги: представник на Січі (speakers.json); порядок файлу — порядок карток
	"talk": {"type": "list", "of": LINE},  # його розповідь про дорогу
}

# ---------- Завдання й історія ----------

## Мовець у розмовах: ім'я й роль під іменем (портрет малює код за id).
const SPEAKER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8501...)
	"name": {"type": "string", "required": true},
	"role": {"type": "string", "required": true},  # «кошовий отаман»; "" — без ролі
}

## Репліка розмови завдання: [мовець, текст] або [мовець, текст, "крок=вибір"] — тоді її чути лише після такого вибору.
const QUEST_LINE := {"type": "list", "sizes": [2, 3], "of": {"type": "string"}}
const QUEST_DIALOGUE := {"type": "list", "required": true, "of": QUEST_LINE}
## На які кроки чекає крок: id кроків історії, переказів чи саги (QuestEngine).
const QUEST_AFTER := {"type": "list", "of": {"type": "string"}}

## Мета кроку завдання. Які типи бере кожна таблиця, — QUEST_OBJECTIVES.
const OBJECTIVE_SCHEMA := {"type": "record", "required": true, "fields": {
	"type": {"type": "enum", "required": true, "values": ["clear", "dungeon", "kill", "fetch", "visit", "job", "choose", "elite"]},
	"enemy": {"type": "string"},  # kill, fetch: кого бити (mobs.json; мусить водитися в «loc»)
	"count": {"type": "int"},  # kill, fetch, job, elite: скільки
	"loc": {"type": "string"},  # де: поле (clear), печера (dungeon), місто (visit, choose), місце для зірки (kill, fetch, job)
	"item": {"type": "string"},  # fetch: що здобути
	"chance": {"type": "float"},  # fetch: шанс на кожного переможеного
	"text": {"type": "string", "required": true},  # рядок у журналі й на банері
}}

## Річ у нагороду: Data.gen_item(ilvl, rarity, slot, type) з іменем і заточкою.
const REWARD_ITEM := {"type": "record", "fields": {
	"slot": {"type": "string", "required": true},  # клітинка (gear_slots.json)
	"type": {"type": "string"},  # вид зброї (weapons.json), лише для зброї
	"rarity": {"type": "int", "required": true},  # rank із rarities.json
	"ilvl": {"type": "int"},  # рівень речі (у переказах його нема: річ рівня героя)
	"up": {"type": "int"},  # заточка
	"name": {"type": "string", "required": true},
}}

## Нагорода. Які поля читає служба кожної таблиці, — QUEST_REWARDS.
const REWARD_FIELDS := {
	"gold": {"type": "int"},
	"gold_lvl": {"type": "int"},  # гривень за кожен рівень героя (перекази)
	"xp": {"type": "int"},
	"trophy": {"type": "int"},  # трофеї (ресурс CampData.TROPHY)
	"rank": {"type": "string"},  # звання героя (StoryService.RANKS)
	"class": {"type": "string"},  # новий клас героя (classes.json)
	"banner": {"type": "string"},  # напис на банері, коли змінились клас чи звання
	"skills": {"type": "map", "of": {"type": "int"}},  # уміння (skills.json) → ранг у подарунок
	"stats": {"type": "map", "of": {"type": "int"}},  # характеристика (GameDB.STAT_IDS) → +очок у подарунок
	"loyalty": {"type": "map", "of": {"type": "int"}},  # місто → очки лояльності
	"item": REWARD_ITEM,
}
const REWARD_SCHEMA := {"type": "record", "fields": REWARD_FIELDS}

## Розділ історії (порядок файлу — порядок розділів).
const STORY_CHAPTER_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8451...)
	"title": {"type": "string", "required": true},
	"cleanse": {"type": "list", "of": {"type": "string"}},  # місця, з яких іде зараза, коли розділ пройдено
	"cleanse_all": {"type": "bool"},  # розділ пройдено — зараза зникає всюди
}

## Крок історії. Порядок кроків задає «after» (QuestEngine); порядок файлу — лише порядок показу (розділ за розділом).
const STORY_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8601...)
	"chapter": {"type": "string", "required": true},  # розділ (story_chapters.json)
	"line": {"type": "string", "required": true},  # лінія завдань (quest_lines.json, «story»)
	"after": QUEST_AFTER,  # на які кроки (будь-якої лінії) він чекає; без поля — ні на які (див. docs/data.md)
	"min_level": {"type": "int"},  # з якого рівня героя крок відкривається
	"story": {"type": "bool"},  # чи крок належить сюжетній лінії (без поля — як у лінії, «story» у quest_lines.json)
	"if": {"type": "string"},  # "ключ=вибір": крок лише для тих, хто так обрав (гілка); інакше пропускається
	"giver": {"type": "string", "required": true},  # хто дає крок (speakers.json)
	"city": {"type": "string", "required": true},  # де з ним говорити; "" — крок без розмови на початку
	"intro": {"type": "list", "of": QUEST_LINE},  # вступ нової гри (лише перший крок)
	"start": QUEST_DIALOGUE,  # розмова на початку; [] — крок починається сам
	"objective": OBJECTIVE_SCHEMA,
	"turn_in": {"type": "string", "required": true},  # куди повертатися; "" — крок завершується сам
	"end": QUEST_DIALOGUE,  # розмова наприкінці
	"choices": {"type": "list", "of": {"type": "record", "fields": {  # вибір наприкінці розмови
		"text": {"type": "string", "required": true},
		"reply": {"type": "string"},  # відповідь мовця на вибір
		"class": {"type": "string"},  # вибір дороги: клас, який обирають на екрані «Дорога» (PathService)
		"reward": REWARD_SCHEMA,
		"effects": {"type": "map", "of": {"type": "number"}},  # постійні наслідки (StoryService.EFFECTS, discount_<місто>)
		"memo": {"type": "string"},  # запис у «Літопис»
	}}},
	"choice_key": {"type": "string"},  # під яким ключем вибір лежить у збереженні (world.missions.choices); без поля — id кроку
	"reward": {"type": "record", "required": true, "fields": REWARD_FIELDS},
	"bonus": {"type": "list", "of": {"type": "record", "fields": {  # нагорода за давніший вибір
		"if": {"type": "string", "required": true},
		"reward": {"type": "record", "required": true, "fields": REWARD_FIELDS},
	}}},
}

## Лінія завдань: історія, переказ чи сага. Умови, з якими лінія відкривається, — тут.
const QUEST_LINE_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8701...)
	"kind": {"type": "enum", "required": true, "values": ["story", "legend", "saga"]},
	"title": {"type": "string"},
	"land": {"type": "string"},  # переказ: край, звідки він
	"source": {"type": "string"},  # переказ: звідки взято
	"min_level": {"type": "int"},  # з якого рівня героя відкриваються перші кроки лінії (ті, що не чекають на її ж крок)
	"story": {"type": "bool"},  # кроки лінії належать сюжетній лінії (крок може сказати інакше своїм «story»)
}

## Крок переказу чи саги (спільний вигляд кроку лінії; порядок кроків задає «after», порядок файлу — порядок показу).
const LINE_STEP_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (перекази 9251..., сага 8801...)
	"line": {"type": "string", "required": true},  # лінія (quest_lines.json)
	"after": QUEST_AFTER,  # на які кроки (будь-якої лінії) він чекає; без поля — ні на які
	"min_level": {"type": "int"},  # з якого рівня героя крок відкривається
	"story": {"type": "bool"},  # чи крок належить сюжетній лінії (без поля — як у лінії)
	"title": {"type": "string", "required": true},
	"giver": {"type": "string", "required": true},  # оповідач (speakers.json)
	"city": {"type": "string", "required": true},  # де він (cities.json)
	"start": QUEST_DIALOGUE,
	"objective": OBJECTIVE_SCHEMA,
	"end": QUEST_DIALOGUE,
	"reward": {"type": "record", "required": true, "fields": REWARD_FIELDS},
}

## Крок «Шляху козака»: умова (одна з WayService.CHECKS), нагорода й куди веде порада.
const WAY_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (8851...)
	"title": {"type": "string", "required": true},
	"how": {"type": "string", "required": true},
	"check": {"type": "record", "required": true, "fields": {
		"stat": {"type": "string"},  # лічильник (ChallengeService.STATS) не менший за «n»
		"n": {"type": "int"},
		"or": {"type": "string"},  # другий лічильник, що додається до першого
		"equip": {"type": "int"},  # вдягнено стільки клітинок
		"spent": {"type": "enum", "values": ["stat", "skill", "perk"]},  # вкладено хоч одне очко
		"quests": {"type": "int"},  # узято чи здано завдання міста
		"loyalty": {"type": "int"},  # є лояльність міста
		"companions": {"type": "int"},  # стільки в загоні
		"camp": {"type": "int"},  # будівель на хуторі
		"tier": {"type": "int"},  # ступінь класу (1 — дорога, 2 — спеціалізація)
	}},
	"reward": {"type": "record", "required": true, "fields": {
		"gold": {"type": "int"},
		"potions": {"type": "int"},
		"mana": {"type": "int"},
		"res": {"type": "map", "of": {"type": "int"}},  # ресурс (resources.json) → скільки
		"trophy": {"type": "int"},
		"item": {"type": "int"},  # річ рівня героя такої рідкості (rank)
		"stone": {"type": "string"},  # камінь долі (stones.json)
	}},
	"go": {"type": "record", "required": true, "fields": {
		"place": {"type": "string"},  # id міста чи місця або WayService.GO_PLACES
		"tab": {"type": "int"},  # вкладка екрана героя
	}},
}

## Шаблон виклику дня чи тижня.
const CHALLENGE_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (день 8901..., тиждень 8951...)
	"stat": {"type": "string", "required": true},  # лічильник (ChallengeService.STATS)
	"goal": {"type": "list", "required": true, "size": 2, "of": {"type": "int"}},  # [найменше, найбільше]
	"text": {"type": "string", "required": true},  # %d — мета
	"group": {"type": "enum", "values": ["base", "event"]},  # event — події й заняття; без поля — base
	"need": {"type": "string"},  # що має бути відкрито (ChallengeService.NEEDS)
	"where": {"type": "string"},  # підказка, куди йти
}

## Досягнення.
const ACHIEVEMENT_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (9001...)
	"name": {"type": "string", "required": true},
	"desc": {"type": "string", "required": true},
	"stat": {"type": "string", "required": true},  # лічильник (ChallengeService.STATS)
	"goal": {"type": "int", "required": true},
	"gold": {"type": "int", "required": true},
}

## Випробування спеціалізації в наставника. Ключ — id класу-спеціалізації.
const SPEC_TRIAL_SCHEMA := {
	"num": {"type": "int", "required": true},  # сталий номер (9201...)
	"start": DIALOGUE,
	"objective": OBJECTIVE_SCHEMA,
	"end": DIALOGUE,
	"item": {"type": "record", "required": true, "fields": {  # зброя від наставника
		"type": {"type": "string", "required": true},  # вид зброї (weapons.json)
		"name": {"type": "string", "required": true},
	}},
}

# ---------- Заняття ----------

const _NUM := {"type": "int", "required": true}  # сталий номер запису
const _TEXT := {"type": "string", "required": true}
const _WORDS := {"type": "list", "required": true, "of": {"type": "string"}}

## Ранг слави (драбина за «rank»): поріг, назва й нагорода за досягнення.
const GLORY_RANK_SCHEMA := {
	"num": _NUM,
	"rank": {"type": "int", "required": true},  # 0, 1, 2... — місце на драбині
	"from": {"type": "int", "required": true},  # з якої слави
	"name": _TEXT,
	"gold": {"type": "int", "required": true},  # гривні за досягнення
	"stone": {"type": "string"},  # камінь долі за досягнення (stones.json)
}

## Звідки береться слава: рядок підказки (вкладка «Слава», довідник).
const GLORY_SOURCE_SCHEMA := {"num": _NUM, "text": _TEXT}

## Суперник у герці: ім'я, стиль бою й механіка, лист спрайтів, порада, прізвиська бійців цього стилю на огляді.
const RIVAL_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"style": _TEXT,  # стиль бою: так його кличуть сотні огляду (muster_teams.json)
	"mechanic": _TEXT,  # як б'ється: "rival/<стиль>" у scripts/mechanics/
	"sprite": _TEXT,  # лист спрайтів
	"bio": _TEXT,  # порада гравцеві
	"nicks": _WORDS,  # прізвиська бійців цього стилю на Гетьманському огляді
}

## Коло герцю (драбина за «round», від 0): сила суперника й нагорода.
const DUEL_ROUND_SCHEMA := {
	"num": _NUM,
	"round": {"type": "int", "required": true},
	"seconds": {"type": "float", "required": true},  # скільки секунд чистої шкоди еталонного героя тримає суперник
	"hit": {"type": "float", "required": true},  # частка здоров'я героя за удар (після захисту)
	"gold": {"type": "int", "required": true},  # × рівень героя
	"glory": {"type": "int", "required": true},
}

## Сотня Гетьманського огляду: назва, стилі бійців (перший — сотник), порада.
const MUSTER_TEAM_SCHEMA := {"num": _NUM, "name": _TEXT, "styles": _WORDS, "bio": _TEXT}

## Сутичка огляду (драбина за «round», від 0).
const MUSTER_ROUND_SCHEMA := {
	"num": _NUM,
	"round": {"type": "int", "required": true},
	"size": {"type": "int", "required": true},  # бійців сотні, коли в героя двоє й більше побратимів
	"seconds": {"type": "float", "required": true},  # скільки секунд шкоди еталонного героя тримає один боєць
	"hit": {"type": "float", "required": true},  # частка здоров'я героя за удар
	"ally_hit": {"type": "float", "required": true},  # частка здоров'я побратима за удар
	"gold": {"type": "int", "required": true},  # × рівень героя
	"glory": {"type": "int", "required": true},
	"loyalty": {"type": "int", "required": true},  # лояльність міста огляду
}

## Коло Кожум'яки (драбина за «round», від 0): сила чудовиська й тижнева нагорода.
const RING_ROUND_SCHEMA := {
	"num": _NUM,
	"round": {"type": "int", "required": true},
	"seconds": {"type": "float", "required": true},
	"hit": {"type": "float", "required": true},
	"gold": {"type": "int", "required": true},  # × рівень героя
	"glory": {"type": "int", "required": true},
}

## Місце занять на мапі (не місто й не місцевість): варта, полювання, рибалка, Коло Кожум'яки.
const SPOT_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"kind": {"type": "enum", "required": true, "values": ["ring", "vigil", "hunt", "fish"]},
	"pos": {"type": "vector", "required": true},  # довгота й широта
	"icon": _TEXT,  # значок на мапі (WorldMap.ICON_ORDER)
	"level": {"type": "int", "required": true},  # з якого рівня героя відкрито
	"desc": _TEXT,
}

## Крам Чумацького шляху: назва й базова ціна одиниці (множиться на заможність рівня героя).
const TRADE_GOOD_SCHEMA := {"num": _NUM, "name": _TEXT, "base": {"type": "int", "required": true}}

## Торг у місті (ключ — id міста): ціна кожного краму відносно базової (менше 1 — тут його роблять).
const TRADE_CITY_SCHEMA := {"num": _NUM, "prices": {"type": "map", "required": true, "of": {"type": "float"}}}

## Звір на полюванні.
const HUNT_ANIMAL_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"speed": {"type": "float", "required": true},  # пікселів за секунду
	"radius": {"type": "float", "required": true},  # радіус влучання
	"meat": {"type": "int", "required": true},
	"weight": {"type": "int", "required": true},  # вага появи
	"tough": {"type": "bool"},  # від простого влучання лише поранений
}

## Риба на тоні.
const FISH_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"ryba": {"type": "int", "required": true},  # улов
	"window": {"type": "float", "required": true},  # вікно на підсікання, с
	"reel": {"type": "float", "required": true},  # скільки тягнути, с
	"pull": {"type": "float", "required": true},  # сила ривків
	"weight": {"type": "int", "required": true},  # вага появи
}

## Страва з казана: що треба (ресурси) і що дає (текст; дію пише Player.recalc за id страви).
const RECIPE_SCHEMA := {"num": _NUM, "name": _TEXT, "need": {"type": "map", "required": true, "of": {"type": "int"}}, "desc": _TEXT}

## Суперник у кості: як грає (TavernService.rival_goes), множник ставки, опис.
const DICE_RIVAL_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"style": {"type": "enum", "required": true, "values": ["cautious", "reckless", "steady"]},
	"stake": {"type": "int", "required": true},
	"desc": _TEXT,
}

## Знахідка в кінці стежки слідів (що вона дає — Combat).
const TRAIL_KIND_SCHEMA := {"num": _NUM, "name": _TEXT, "weight": {"type": "int", "required": true}, "text": _TEXT}

## Похід побратима.
const EXPEDITION_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"back": _TEXT,  # «з розвідки»
	"hours": {"type": "float", "required": true},
	"gold": {"type": "float", "required": true},  # множник гривень
	"res": {"type": "int", "required": true},  # одиниць ресурсів
	"xp": {"type": "float", "required": true},  # частка рівня досвіду самому супутникові
	"item": {"type": "float", "required": true},  # шанс речі
	"trophy": {"type": "int", "required": true},
	"risk": {"type": "float", "required": true},  # шанс повернутись пораненим
	"desc": _TEXT,
}

## Рекорд роду в Літописі слави (ключ — що рахує RecordService.hero_values).
const RECORD_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"fmt": _TEXT,  # як показати значення ("time" — хвилини:секунди)
	"step": {"type": "int", "required": true},  # за кожні step одиниць нового рекорду роду —
	"glory": {"type": "int", "required": true},  # стільки слави (0 — без слави)
}

## Мандрівник, якого проводять (завдання «Супровід»).
const ESCORT_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"acc": _TEXT,  # знахідний відмінок: «Проведи кобзаря»
	"sheet": _TEXT,  # лист спрайтів
	"she": {"type": "bool"},  # жіночий рід: «дійшла»
	"thanks": _TEXT,
}

# ---------- Свята ----------

## Святковий бонус: які ключі є, вміє HolidayService (PLAYER_KEYS, COMBAT_KEYS, SERVICE_KEYS).
const HOLIDAY_BONUS := {"type": "record", "required": true, "fields": {
	"gold": {"type": "float"}, "xp": {"type": "float"}, "hp": {"type": "float"}, "dmg": {"type": "float"}, "armor": {"type": "float"},
	"crit": {"type": "float"}, "regen": {"type": "float"}, "mana": {"type": "float"}, "skill": {"type": "float"}, "cd": {"type": "float"},
	"potion": {"type": "float"}, "status": {"type": "float"},
	"loot": {"type": "float"}, "rare": {"type": "float"}, "res": {"type": "float"}, "varenyk": {"type": "float"}, "trophy": {"type": "int"},
	"boss": {"type": "float"},
	"glory": {"type": "float"}, "harvest": {"type": "float"}, "dice": {"type": "int"}, "rumor": {"type": "float"}, "loyalty": {"type": "float"},
	"outdoor": {"type": "float"}, "sharpen": {"type": "float"}, "hire": {"type": "float"},
}}

## Сезонне свято. Дата — рівно одне з: from+to ([місяць, день]), easter ([від, до] днів від Великодня),
## nth ([місяць, котрий за ліком, день тижня]) з days.
const HOLIDAY_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"rank": {"type": "enum", "required": true, "values": ["great", "small"]},
	"from": {"type": "list", "size": 2, "of": {"type": "int"}},
	"to": {"type": "list", "size": 2, "of": {"type": "int"}},
	"easter": {"type": "list", "size": 2, "of": {"type": "int"}},
	"nth": {"type": "list", "size": 3, "of": {"type": "int"}},
	"days": {"type": "int"},
	"token": _TEXT,  # жетон свята
	"tokens": _TEXT,  # родовий множини: «зірок»
	"bonus": HOLIDAY_BONUS,
	"bonus_text": _TEXT,
	"desc": _TEXT,
}

## Місяць (порядок файлу — порядок року): назва в родовому відмінку для дат свят.
const MONTH_SCHEMA := {"num": _NUM, "gen": _TEXT}

## Пороги жетонів свята (great — велике, short — велике до трьох днів і мале від чотирьох, tiny — мале до трьох).
const TOKEN_SCALE_SCHEMA := {"num": _NUM, "need": {"type": "list", "required": true, "size": 3, "of": {"type": "int"}}}

# ---------- Хутір ----------

## Хутір на мапі (ключ — CampData.CAMP_ID).
const CAMP_SCHEMA := {"num": _NUM, "name": _TEXT, "pos": {"type": "vector", "required": true}, "desc": _TEXT}

## Ресурс героя: будівельний (res), трофеї (trophy) чи провіант (food).
const RESOURCE_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"kind": {"type": "enum", "required": true, "values": ["res", "trophy", "food"]},
	"color": {"type": "color", "required": true},  # колір підбирачки й значка
}

## Рівень будівлі: ціна (гривні й ресурси), що дає (текст) і числа, які читає код.
const BUILDING_LEVEL := {"type": "record", "fields": {
	"gold": {"type": "int", "required": true},
	"wood": {"type": "int", "required": true},
	"iron": {"type": "int", "required": true},
	"herbs": {"type": "int", "required": true},
	"text": _TEXT,
	"bag": {"type": "int"},  # Склад: місць у торбі на цьому рівні
	"rate": {"type": "int"},  # Пасіка: гривень на годину на цьому рівні
	"beds": {"type": "int"},  # Город: грядок на цьому рівні
}}

## Будівля хутора. Порядок файлу — порядок показу.
const BUILDING_SCHEMA := {"num": _NUM, "name": _TEXT, "desc": _TEXT, "levels": {"type": "list", "required": true, "of": BUILDING_LEVEL}}

## Культура на городі.
const CROP_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"hours": {"type": "float", "required": true},
	"gives": _TEXT,  # ресурс (resources.json) або "gold"
	"amount": {"type": "int", "required": true},
	"seed": {"type": "int", "required": true},  # ціна насіння
	"desc": _TEXT,
}

## Зілля із Зілляварні.
const BREW_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"herbs": {"type": "int", "required": true},
	"iron": {"type": "int", "required": true},
	"level": {"type": "int", "required": true},  # потрібний рівень Зілляварні
	"desc": _TEXT,
}

## Клейнод роду: що росте (stat), приріст за ступінь, ресурс оздоби. Ціни ступенів — kleinod_tiers.json.
const KLEINOD_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"stat": _TEXT,  # xp, dmg, hp, crit, cd (герой; KleinodService.HERO_STATS) чи glory, loyalty (служби)
	"per": {"type": "float", "required": true},
	"res": _TEXT,  # ресурс оздоби (resources.json, будівельний)
	"text": _TEXT,  # «+%d%% досвіду»
	"desc": _TEXT,
}

## Ступінь клейнода (драбина за «tier», від 1): гривні, трофеї й ресурс клейнода.
const KLEINOD_TIER_SCHEMA := {
	"num": _NUM,
	"tier": {"type": "int", "required": true},
	"gold": {"type": "int", "required": true},
	"trophy": {"type": "int", "required": true},
	"res": {"type": "int", "required": true},
}

## Камінь долі: назва, шанс із боса, ціна в скарбника, що робить (текст; саму дію пише StoneService).
const STONE_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"chance": {"type": "float", "required": true},  # шанс із переможеного боса
	"price": {"type": "int", "required": true},  # у скарбника хутора
	"text": _TEXT,
}

## Дрібний товар Трофейного ярмарку: ключ — камінь (stones.json) чи жетон безпечної заточки (safe).
const FAIR_GOOD_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"trophy": {"type": "int", "required": true},
	"gold": {"type": "int", "required": true},
	"limit": {"type": "int", "required": true},  # на тиждень
}

## Рівень лояльності міста (драбина за «level», від 0).
const LOYALTY_LEVEL_SCHEMA := {
	"num": _NUM,
	"level": {"type": "int", "required": true},
	"from": {"type": "int", "required": true},  # з якої кількості очок
	"name": _TEXT,
	"discount": {"type": "float", "required": true},  # знижка в місті
}

# ---------- Події, боси дня, стани ----------

## Дорожня пригода: хто говорить, що каже і тексти виборів (ключ — варіант, який обирає TravelService).
## Умови, ціни й наслідки — код TravelService.prepare. %s і %d заповнює код.
const ROAD_EVENT_SCHEMA := {
	"num": _NUM,
	"speaker": _TEXT,  # мовець (speakers.json)
	"text": _TEXT,
	"choices": {"type": "map", "required": true, "of": {"type": "record", "fields": {"text": _TEXT, "reply": _TEXT}}},
}

## Подія чи заняття (вкладка «Події», довідник). battle — бойова подія світу (EventService.BATTLE_KINDS).
const EVENT_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"kind": _TEXT,  # група (event_kinds.json)
	"icon": _TEXT,  # значок (WorldMap.ICON_ORDER)
	"where": _TEXT,
	"level": {"type": "int", "required": true},  # з якого рівня героя (0 — від початку)
	"text": _TEXT,
	"reward": _TEXT,
	"battle": {"type": "record", "fields": {
		"deadline": {"type": "int", "required": true},  # скільки походів подія чекає
		"waves": {"type": "int", "required": true},
		"variant": _TEXT,  # вигляд оборони (Combat.enter_defense)
		"gate_hp": {"type": "list", "required": true, "size": 2, "of": {"type": "float"}},  # здоров'я того, що боронять: [основа, за рівень]
	}},
}

## Група подій (порядок файлу — порядок показу).
const EVENT_KIND_SCHEMA := {"num": _NUM, "title": _TEXT}

## Бос дня чи тижня: назви, з якого рівня, сила й нагорода.
const BOSS_HUNT_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,  # «Бос дня»
	"period": _TEXT,  # «сьогодні»
	"next": _TEXT,  # «завтра»
	"min_level": {"type": "int", "required": true},
	"hp_mult": {"type": "float", "required": true},
	"dmg_mult": {"type": "float", "required": true},
	"mods": {"type": "int", "required": true},  # скільки властивостей (boss_mods.json)
	"gold": {"type": "int", "required": true},  # гривень за рівень героя
	"trophies": {"type": "int", "required": true},
	"xp_part": {"type": "float", "required": true},  # частка досвіду поточного рівня
	"item_rarity": {"type": "int", "required": true},
}

## Перелік босів (порядок важить: з нього кидається, хто вийде): hunt — боси дня й тижня, ring — Коло Кожум'яки.
const BOSS_POOL_SCHEMA := {"num": _NUM, "bosses": _WORDS}

## Властивість боса дня чи тижня. Поля, крім name і desc, лягають в опис бою: множники
## (BossService.MULT_KEYS) перемножуються, решта замінюється. Порядок файлу — порядок кидка.
const BOSS_MOD_SCHEMA := {
	"num": _NUM,
	"name": _TEXT,
	"desc": _TEXT,
	"boss_dmg_mult": {"type": "float"},
	"boss_hp_mult": {"type": "float"},
	"minions": {"type": "float"},
	"elite_bonus": {"type": "float"},
	"night": {"type": "bool"},
	"enrage_after": {"type": "float"},
	"boss_speed_mult": {"type": "float"},
}

## Стан на героєві й нечисті: назва, колір, що робить (довідник). Дію пишуть Status і Player.
const STATUS_SCHEMA := {"num": _NUM, "name": _TEXT, "color": {"type": "color", "required": true}, "desc": _TEXT}

# ---------- Довідник, звуки, імена ----------

## Вкладка довідника (порядок файлу — порядок вкладок; що на ній — WikiService).
const WIKI_SECTION_SCHEMA := {"num": _NUM, "title": _TEXT}

## Розділ «Як грати».
const WIKI_BASIC_SCHEMA := {"num": _NUM, "title": _TEXT, "text": _TEXT}

## Порядок у довіднику: enemies — нечисть (з «wiki»), bosses — боси (з «boss.wiki»).
const WIKI_ORDER_SCHEMA := {"num": _NUM, "ids": _WORDS}

## Гучність звуку чи фонового шуму в дБ (додається до гучності місця виклику).
const VOLUME_SCHEMA := {"num": _NUM, "volume": {"type": "float", "required": true}}

## Перелік слів для імен: прізвиська для жеребу, корені лайки, імена служби гри, імена бійців огляду.
const NAME_POOL_SCHEMA := {"num": _NUM, "words": _WORDS}

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
	"job_tiers": {"file": "job_tiers.json", "schema": JOB_TIER_SCHEMA},
	"classes": {"file": "classes.json", "schema": CLASS_SCHEMA},
	"skills": {"file": "skills.json", "schema": SKILL_SCHEMA},
	"effects": {"file": "effects.json", "schema": EFFECT_SCHEMA},
	"perk_branches": {"file": "perk_branches.json", "schema": PERK_BRANCH_SCHEMA},
	"perks": {"file": "perks.json", "schema": PERK_SCHEMA},
	"base_stats": {"file": "base_stats.json", "schema": BASE_STAT_SCHEMA},
	"valor_lines": {"file": "valor_lines.json", "schema": VALOR_LINE_SCHEMA},
	"paths": {"file": "paths.json", "schema": PATH_SCHEMA},
	"speakers": {"file": "speakers.json", "schema": SPEAKER_SCHEMA},
	"story_chapters": {"file": "story_chapters.json", "schema": STORY_CHAPTER_SCHEMA},
	"story": {"file": "story.json", "schema": STORY_SCHEMA},
	"quest_lines": {"file": "quest_lines.json", "schema": QUEST_LINE_SCHEMA},
	"legend_steps": {"file": "legend_steps.json", "schema": LINE_STEP_SCHEMA},
	"saga": {"file": "saga.json", "schema": LINE_STEP_SCHEMA},
	"way": {"file": "way.json", "schema": WAY_SCHEMA},
	"daily": {"file": "daily.json", "schema": CHALLENGE_SCHEMA},
	"weekly": {"file": "weekly.json", "schema": CHALLENGE_SCHEMA},
	"achievements": {"file": "achievements.json", "schema": ACHIEVEMENT_SCHEMA},
	"spec_trials": {"file": "spec_trials.json", "schema": SPEC_TRIAL_SCHEMA},
	"glory_ranks": {"file": "glory_ranks.json", "schema": GLORY_RANK_SCHEMA},
	"glory_sources": {"file": "glory_sources.json", "schema": GLORY_SOURCE_SCHEMA},
	"rivals": {"file": "rivals.json", "schema": RIVAL_SCHEMA},
	"duel_rounds": {"file": "duel_rounds.json", "schema": DUEL_ROUND_SCHEMA},
	"muster_teams": {"file": "muster_teams.json", "schema": MUSTER_TEAM_SCHEMA},
	"muster_rounds": {"file": "muster_rounds.json", "schema": MUSTER_ROUND_SCHEMA},
	"ring_rounds": {"file": "ring_rounds.json", "schema": RING_ROUND_SCHEMA},
	"spots": {"file": "spots.json", "schema": SPOT_SCHEMA},
	"trade_goods": {"file": "trade_goods.json", "schema": TRADE_GOOD_SCHEMA},
	"trade_cities": {"file": "trade_cities.json", "schema": TRADE_CITY_SCHEMA},
	"hunt_animals": {"file": "hunt_animals.json", "schema": HUNT_ANIMAL_SCHEMA},
	"fish": {"file": "fish.json", "schema": FISH_SCHEMA},
	"recipes": {"file": "recipes.json", "schema": RECIPE_SCHEMA},
	"dice_rivals": {"file": "dice_rivals.json", "schema": DICE_RIVAL_SCHEMA},
	"trail_kinds": {"file": "trail_kinds.json", "schema": TRAIL_KIND_SCHEMA},
	"expeditions": {"file": "expeditions.json", "schema": EXPEDITION_SCHEMA},
	"records": {"file": "records.json", "schema": RECORD_SCHEMA},
	"escorts": {"file": "escorts.json", "schema": ESCORT_SCHEMA},
	"holidays": {"file": "holidays.json", "schema": HOLIDAY_SCHEMA},
	"months": {"file": "months.json", "schema": MONTH_SCHEMA},
	"token_scales": {"file": "token_scales.json", "schema": TOKEN_SCALE_SCHEMA},
	"camps": {"file": "camps.json", "schema": CAMP_SCHEMA},
	"resources": {"file": "resources.json", "schema": RESOURCE_SCHEMA},
	"buildings": {"file": "buildings.json", "schema": BUILDING_SCHEMA},
	"crops": {"file": "crops.json", "schema": CROP_SCHEMA},
	"brews": {"file": "brews.json", "schema": BREW_SCHEMA},
	"kleinody": {"file": "kleinody.json", "schema": KLEINOD_SCHEMA},
	"kleinod_tiers": {"file": "kleinod_tiers.json", "schema": KLEINOD_TIER_SCHEMA},
	"stones": {"file": "stones.json", "schema": STONE_SCHEMA},
	"fair_goods": {"file": "fair_goods.json", "schema": FAIR_GOOD_SCHEMA},
	"loyalty_levels": {"file": "loyalty_levels.json", "schema": LOYALTY_LEVEL_SCHEMA},
	"road_events": {"file": "road_events.json", "schema": ROAD_EVENT_SCHEMA},
	"events": {"file": "events.json", "schema": EVENT_SCHEMA},
	"event_kinds": {"file": "event_kinds.json", "schema": EVENT_KIND_SCHEMA},
	"boss_hunts": {"file": "boss_hunts.json", "schema": BOSS_HUNT_SCHEMA},
	"boss_pools": {"file": "boss_pools.json", "schema": BOSS_POOL_SCHEMA},
	"boss_mods": {"file": "boss_mods.json", "schema": BOSS_MOD_SCHEMA},
	"statuses": {"file": "statuses.json", "schema": STATUS_SCHEMA},
	"wiki_sections": {"file": "wiki_sections.json", "schema": WIKI_SECTION_SCHEMA},
	"wiki_basics": {"file": "wiki_basics.json", "schema": WIKI_BASIC_SCHEMA},
	"wiki_orders": {"file": "wiki_orders.json", "schema": WIKI_ORDER_SCHEMA},
	"sounds": {"file": "sounds.json", "schema": VOLUME_SCHEMA},
	"ambients": {"file": "ambients.json", "schema": VOLUME_SCHEMA},
	"name_pools": {"file": "name_pools.json", "schema": NAME_POOL_SCHEMA},
	# Налаштування балансу: запис — розділ гри зі своєю схемою («schemas» замість «schema», див. settings())
	"settings": {"file": "settings.json", "schemas": SettingsSchema.SCHEMAS},
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
	"classes": [7001, 7099], "skills": [7101, 7999], "effects": [8001, 8089], "perk_branches": [8091, 8099],
	"perks": [8101, 8199], "base_stats": [8201, 8249], "valor_lines": [8251, 8299], "paths": [8301, 8399],
	"job_tiers": [8401, 8449], "story_chapters": [8451, 8499], "speakers": [8501, 8599], "story": [8601, 8699],
	"quest_lines": [8701, 8749], "saga": [8801, 8849], "way": [8851, 8899], "daily": [8901, 8949], "weekly": [8951, 8999],
	"achievements": [9001, 9199], "spec_trials": [9201, 9249], "legend_steps": [9251, 9499],
	# заняття
	"glory_ranks": [9501, 9519], "glory_sources": [9521, 9539], "rivals": [9541, 9559], "duel_rounds": [9561, 9569],
	"muster_teams": [9571, 9589], "muster_rounds": [9591, 9599], "ring_rounds": [9601, 9609], "spots": [9611, 9629],
	"trade_goods": [9631, 9649], "trade_cities": [9651, 9699], "hunt_animals": [9701, 9719], "fish": [9721, 9739],
	"recipes": [9741, 9769], "dice_rivals": [9771, 9789], "trail_kinds": [9791, 9809], "expeditions": [9811, 9829],
	"records": [9831, 9869], "escorts": [9871, 9889],
	# свята
	"holidays": [9901, 9949], "months": [9951, 9969], "token_scales": [9971, 9979],
	# хутір
	"camps": [10001, 10009], "resources": [10011, 10039], "buildings": [10041, 10069], "crops": [10071, 10089],
	"brews": [10091, 10109], "kleinody": [10111, 10129], "kleinod_tiers": [10131, 10139], "stones": [10141, 10149],
	"fair_goods": [10151, 10169], "loyalty_levels": [10171, 10179],
	# події, боси дня й тижня, стани
	"road_events": [10201, 10249], "events": [10251, 10299], "event_kinds": [10301, 10309], "boss_hunts": [10311, 10319],
	"boss_pools": [10321, 10329], "boss_mods": [10331, 10349], "statuses": [10351, 10379],
	# довідник, звуки, імена
	"wiki_sections": [10401, 10419], "wiki_basics": [10421, 10469], "wiki_orders": [10471, 10479],
	"sounds": [10501, 10599], "ambients": [10601, 10619], "name_pools": [10701, 10719],
	# налаштування балансу
	"settings": [11001, 11099],
}
const BOSS_NUM_RANGE := [2001, 2999]  # boss.num у mobs.json

## Основи механік за родинами: тека в scripts/mechanics/ → скрипт-основа.
const MECHANIC_BASES := {
	"mob": "res://scripts/mechanics/mechanic.gd",
	"boss": "res://scripts/mechanics/mechanic.gd",
	"companion": "res://scripts/mechanics/companion_mechanic.gd",
	"pet": "res://scripts/mechanics/pet_mechanic.gd",
	"skill": "res://scripts/mechanics/skill_mechanic.gd",
	"act": "res://scripts/mechanics/act_mechanic.gd",
	"power": "res://scripts/mechanics/power_mechanic.gd",
	"weapon": "res://scripts/mechanics/weapon_mechanic.gd",
	"rival": "res://scripts/mechanics/mechanic.gd",
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


## Схема запису id таблиці name: спільна для таблиці або, у налаштувань, своя в кожного запису
## (для невідомого запису налаштувань — порожня).
static func schema_of(name: String, id: String) -> Dictionary:
	var T: Dictionary = TABLES[name]
	if T.has("schemas"):
		return T["schemas"].get(id, _EMPTY)
	return T["schema"]


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


## Таблиці, записи яких після завантаження мають поле «id» (у файлі його не пишуть): назва → поле, з
## якого його взяти ("" — ключ запису). Вміння: ранги зберігаються під «skill», якщо воно є, інакше під ключем.
const ID_FIELD := {"skills": "skill", "perks": "", "base_stats": "", "story": "", "legend_steps": "", "saga": "", "way": "", "achievements": "", "events": ""}


## Що таблиця доводить до ладу після схеми, поки записи ще не заморожено.
## Золота річ: параметри сили стають цілими чи дробовими так, як їх оголошує сила (powers.json):
## JSON дає всі числа дробовими, а радіус чи кількість стрибків — цілі.
static func _post(name: String, rows: Dictionary) -> void:
	if ID_FIELD.has(name):
		# Запис, який гра передає як вузол (вміння, Загартування, характеристика), знає свій id
		for id in rows:
			rows[id]["id"] = str(rows[id].get(ID_FIELD[name], id)) if ID_FIELD[name] != "" else str(id)
		return
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
	# Налаштування: кожне поле обов'язкове, кожен запис має свою схему, і всі записи мусять бути
	var every: bool = TABLES[name].has("schemas")
	for id in raw:
		var where := "%s/%s" % [name, id]
		if not id is String or not _is_id(id):
			probs.append("%s: id має бути з малих латинських літер, цифр і «_»" % where)
		if not raw[id] is Dictionary:
			probs.append("%s: запис має бути об'єктом" % where)
			continue
		var schema := schema_of(name, str(id))
		if schema.is_empty():
			probs.append("%s: невідомий запис (описка? записи — %s)" % [where, ", ".join(TABLES[name]["schemas"].keys())])
			continue
		rows[str(id)] = _normalize(raw[id], schema, where, probs, every)
	if every:
		for id in TABLES[name]["schemas"]:
			if not raw.has(id):
				probs.append("%s: немає запису «%s»" % [name, id])
	return [rows, probs]


static func _is_id(id: String) -> bool:
	if id == "":
		return false
	for c in id:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			return false
	return true


## every — кожне поле обов'язкове (налаштування балансу).
static func _normalize(rec: Dictionary, schema: Dictionary, where: String, probs: Array, every: bool = false) -> Dictionary:
	var out := {}
	for k in rec:
		if not schema.has(k):
			probs.append("%s: невідоме поле «%s» (описка?)" % [where, k])
	for k in schema:
		var f: Dictionary = schema[k]
		if not rec.has(k):
			if every or f.get("required", false):
				probs.append("%s: немає обов'язкового поля «%s»" % [where, k])
			continue
		var v = _value(rec[k], f, "%s.%s" % [where, k], probs, every)
		if v != null:
			out[k] = v
	return out


## Одне значення за описом поля; null, якщо воно хибне (тоді проблему вже записано).
static func _value(v, f: Dictionary, where: String, probs: Array, every: bool = false):
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
		"number":
			# Число, що буває і цілим, і дробовим (наслідки вибору: +1 зілля, 0.25 знижки): ціле лишається цілим
			if v is int:
				return v
			if v is float:
				return int(v) if v == floorf(v) and absf(v) < 9.0e15 else v
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
				return _normalize(v, f["fields"], where, probs, every)
		"enum":
			if v is String:
				if v in f["values"]:
					return v
				probs.append("%s: «%s» — не з переліку %s" % [where, v, str(f["values"])])
				return null
		"rank":
			# Число вміння на ранзі: одне число або [основа, приріст за ранг] (Classes.val)
			if v is float or v is int:
				return float(v)
			if v is Array and v.size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
				return [float(v[0]), float(v[1])]
			probs.append("%s: має бути числом або [основа, приріст за ранг]" % where)
			return null
		"list":
			if v is Array:
				# "items" — опис кожного місця окремо (запис різного роду: [стан, секунд])
				var items: Array = f.get("items", [])
				var size: int = items.size() if not items.is_empty() else int(f.get("size", -1))
				if size >= 0 and v.size() != size:
					probs.append("%s: має бути %d значень, а не %d" % [where, size, v.size()])
					return null
				# "sizes" — дозволені довжини (репліка завдання: [мовець, текст] чи з умовою третім)
				if f.has("sizes") and not v.size() in f["sizes"]:
					probs.append("%s: має бути %s значень, а не %d" % [where, " чи ".join(f["sizes"].map(func(x): return str(x))), v.size()])
					return null
				var out := []
				for i in v.size():
					var x = _value(v[i], items[i] if not items.is_empty() else f["of"], "%s[%d]" % [where, i], probs, every)
					if x == null:
						return null
					out.append(x)
				return out
		"map":
			if v is Dictionary:
				var out := {}
				for k in v:
					var x = _value(v[k], f["of"], "%s.%s" % [where, k], probs, every)
					if x != null:
						out[k] = x
				return out
	probs.append("%s: має бути %s, а не %s" % [where, _type_name(t), _type_name_of(v)])
	return null


static func _type_name(t: String) -> String:
	return {"string": "рядком", "bool": "true або false", "int": "цілим числом", "float": "числом", "number": "числом", "record": "об'єктом {...}",
		"enum": "рядком", "list": "масивом [...]", "map": "об'єктом {...}", "vector": "масивом [x, y]", "rank": "числом"}.get(t, t)


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
			elif CLASS_TABLES.has(name):
				out.append_array(_class_rules(name, rows))
				out.append_array(_unique_nums(name, rows))
			elif QUEST_TABLES.has(name):
				out.append_array(_quest_rules(name, rows))
				out.append_array(_unique_nums(name, rows))
			elif LIFE_TABLES.has(name):
				out.append_array(_life_rules(name, rows))
				out.append_array(_unique_nums(name, rows))
			elif name == "settings":
				out.append_array(_settings_rules(rows))
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
				_positive(R, ["dmg", "cd", "range", "arc", "kb", "shot_range"], where, out)
				if R.get("agi", false) and not R.get("ranged", false):
					out.append("%s: «agi» лише в зброї дальнього бою («ranged»)" % where)
				if R.get("ranged", false) != R.has("shot_range"):
					out.append("%s: зброя дальнього бою («ranged») потребує «shot_range», і лише вона" % where)
				if R.has("stat") and R.get("agi", false) != (str(R["stat"]) == "agi"):
					out.append("%s: «stat» «%s» не згоджується з «agi»" % [where, R["stat"]])
				if R.has("mechanic") and not _is_mechanic_ref(str(R["mechanic"]), "weapon"):
					out.append("%s: «mechanic» має бути \"weapon/<файл>\", а не «%s»" % [where, R["mechanic"]])
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
				if R.has("mechanic") and not _is_mechanic_ref(str(R["mechanic"]), "power"):
					out.append("%s: «mechanic» має бути \"power/<файл>\", а не «%s»" % [where, R["mechanic"]])
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
			# Кування й оновлення: «forge» і «renew» мають рідкості підряд від звичайної (CraftService)
			var by_rank := {}
			for id in rows:
				by_rank[int(rows[id].get("rank", -1))] = id
			for k in ["forge", "renew"]:
				var gap := false
				for r in by_rank.size():
					var has: bool = by_rank.has(r) and rows[by_rank[r]].has(k)
					if has and gap:
						out.append("rarities/%s: «%s» мають рідкості підряд від звичайної, а перед нею пропуск" % [by_rank[r], k])
					gap = gap or not has
			for id in rows:
				var F: Dictionary = rows[id].get("forge", _EMPTY)
				_positive(F, ["kuznia", "mult"], "rarities/%s.forge" % id, out)
				_positive(F, ["trophy"], "rarities/%s.forge" % id, out, true)
				_positive(rows[id], ["renew"], "rarities/" + id, out)
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
			elif CLASS_TABLES.has(name):
				out.append_array(_class_links(name, rows))
			elif QUEST_TABLES.has(name):
				out.append_array(_quest_links(name, rows))
			elif LIFE_TABLES.has(name):
				out.append_array(_life_links(name, rows))
			elif name == "settings":
				out.append_array(_settings_links(rows))
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
			for cls in ids("classes"):
				for w in row("classes", cls).get("weapons", []):
					if not rows.has(w):
						out.append("клас %s носить зброю «%s», якої нема у weapons.json" % [cls, w])
			var wused := {}
			for id in rows:
				if rows[id].has("mechanic"):
					_mechanic_ref("weapons/" + id, "mechanic", str(rows[id]["mechanic"]), wused, out)
			out.append_array(_mechanic_orphans(["weapon"], wused, "weapons.json"))
			for w in load("res://scripts/data/costumes.gd").WEAPONS:
				if not rows.has(w):
					out.append("Costumes.WEAPONS: зброї «%s» нема у weapons.json" % w)
		"powers":
			var pused := {}
			for id in rows:
				if rows[id].has("mechanic"):
					_mechanic_ref("powers/" + id, "mechanic", str(rows[id]["mechanic"]), pused, out)
			out.append_array(_mechanic_orphans(["power"], pused, "powers.json"))
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
					if not _has_row("effects", k):
						out.append("enchants/%s: «fx» — ключа «%s» нема в effects.json" % [id, k])
		"gifts":
			for id in rows:
				if rows[id].has("slot") and not _has_row("gift_slots", rows[id]["slot"]):
					out.append("gifts/%s: «slot» — нема гнізда «%s» у gift_slots.json" % [id, rows[id]["slot"]])
				for k in rows[id].get("fx", _EMPTY):
					if not _has_row("effects", k):
						out.append("gifts/%s: «fx» — ключа «%s» нема в effects.json" % [id, k])
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
	for b in row("boss_pools", "ring").get("bosses", []):
		need.call(b, "Коло Кожум'яки", "boss")
	for b in row("boss_pools", "hunt").get("bosses", []):
		need.call(b, "Боси дня й тижня", "boss")
	for id in rows:
		var B: Dictionary = rows[id].get("boss", _EMPTY)
		if B.has("stones") and B["stones"].is_empty():
			out.append("mobs/%s: «boss.stones» порожні (без каменів поле не пишуть)" % id)
		for st in B.get("stones", []):
			if not _has_row("stones", st):
				out.append("mobs/%s: «boss.stones» — нема каменя «%s» у stones.json" % [id, st])
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
	var enemy_order: Array = row("wiki_orders", "enemies").get("ids", [])
	var boss_order: Array = row("wiki_orders", "bosses").get("ids", [])
	for k in enemy_order:
		need.call(k, "довідник (нечисть)", "wiki")
	for k in boss_order:
		need.call(k, "довідник (боси)", "boss")
		if rows.has(k) and rows[k].has("boss") and not rows[k]["boss"].has("wiki"):
			out.append("довідник (боси): у «%s» нема «boss.wiki»" % k)
	out.append_array(_mechanic_links(rows))
	# Зворотні перевірки: те, що є в записі, мусить мати сенс для гри
	var Index = load("res://scripts/data/sound_index.gd")
	for id in rows:
		var R: Dictionary = rows[id]
		if R.has("hit_status") and not _has_row("statuses", R["hit_status"]):
			out.append("mobs/%s: невідомий стан «%s» (див. statuses.json)" % [id, R["hit_status"]])
		var snd := str(R.get("sounds", {}).get("death", ""))
		if snd != "" and not Index.SFX.has(snd):
			out.append("mobs/%s: невідомий звук «%s» (див. SoundIndex.SFX)" % [id, snd])
		if R.has("wiki") and not id in enemy_order:
			out.append("mobs/%s: опис у довіднику є, а в переліку «enemies» (wiki_orders.json) виду нема, тож його не видно" % id)
		if R.has("boss") and R["boss"].has("wiki") and not id in boss_order:
			out.append("mobs/%s: опис боса є, а в переліку «bosses» (wiki_orders.json) його нема, тож його не видно" % id)
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


## Файли механік у теці (mob, boss, companion, pet, skill, act, power, weapon) як посилання ("mob/chort"). Лише для перевірки й
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
		if lv < 0 or lv >= Data.loyalty_levels().size():
			out.append("companions/%s: «hire.loyalty» має бути від 0 до %d (loyalty_levels.json)" % [id, Data.loyalty_levels().size() - 1])
		if R.has("mechanic"):
			_mechanic_ref("companions/" + id, "mechanic", str(R["mechanic"]), used, out)
	out.append_array(_mechanic_orphans(["companion"], used, "companions.json"))
	return out


static func _hero_links(rows: Dictionary) -> Array:
	var out := []
	var keys := _choice_keys(table("story"))  # ключ вибору → [місце кроку, скільки виборів]
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
		if j.has("after") and not _has_row("story", j["after"]):
			out.append("%s: «join.after» — нема кроку сюжету «%s»" % [where, j["after"]])
		if j.has("if"):
			var parts: PackedStringArray = str(j["if"]).split("=")
			if parts.size() != 2 or not parts[1].is_valid_int():
				out.append("%s: «join.if» має бути \"крок=номер вибору\", а не «%s»" % [where, j["if"]])
			elif not keys.has(parts[0]) or int(parts[1]) < 0 or int(parts[1]) >= int(keys[parts[0]][1]):
				out.append("%s: «join.if» — нема кроку «%s» із вибором %s" % [where, parts[0], parts[1]])
		var dl := _hero_dialogues(R)
		for k in dl:
			for i in dl[k].size():
				if not _has_row("speakers", dl[k][i][0]):
					out.append("%s: «%s[%d]» — мовця «%s» нема в speakers.json" % [where, k, i, dl[k][i][0]])
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
	var used := {}
	for id in rows:
		var R: Dictionary = rows[id]
		var where: String = "pets/" + id
		for r in R.get("stable", _EMPTY).get("res", _EMPTY):
			if not str(row("resources", r).get("kind", "")) in ["res", "trophy"]:
				out.append("%s: «stable.res» — невідомий ресурс «%s» (resources.json: будівельний чи трофеї)" % [where, r])
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
			for id in rows:
				var n := 0
				for p in ids("places"):
					if str(row("places", p).get("land", "")) == id:
						n += 1
				if n != 1:
					out.append("lands/%s: у землі має бути рівно одна надважка печера («land» у places.json), а їх %d" % [id, n])
				for k in rows[id].get("title_fx", _EMPTY):
					if not _has_row("valor_lines", k):
						out.append("lands/%s: «title_fx» — ключа «%s» нема у valor_lines.json" % [id, k])
		"biomes":
			var Index = load("res://scripts/data/sound_index.gd")
			var Ground = load("res://scripts/world/ground.gd")
			for id in rows:
				var R: Dictionary = rows[id]
				if R.has("ambient") and not str(R["ambient"]) in Index.AMBIENT:
					out.append("biomes/%s: «ambient» — нема шуму «%s» у SoundIndex.AMBIENT" % [id, R["ambient"]])
				if R.has("resource") and str(row("resources", R["resource"]).get("kind", "")) != "res":
					out.append("biomes/%s: «resource» — невідомий будівельний ресурс «%s» (resources.json)" % [id, R["resource"]])
				for k in ["icon", "dungeon_icon"]:
					if R.has(k) and not str(R[k]) in WM.ICON_ORDER:
						out.append("biomes/%s: «%s» — нема значка «%s» у WorldMap.ICON_ORDER" % [id, k, R[k]])
				if not id in Ground.TILED:
					out.append("biomes/%s: земля цього краєвиду не намальована (Ground.TILED): новий краєвид потребує коду й тайлів" % id)
		"elite_affixes":
			for id in rows:
				if rows[id].has("status") and not _has_row("statuses", rows[id]["status"]):
					out.append("elite_affixes/%s: невідомий стан «%s» (див. statuses.json)" % [id, rows[id]["status"]])
	return out


# ---------- Класи й уміння: правила й посилання ----------

## Таблиці класів і вмінь: їхні правила — _class_rules, посилання — _class_links.
const CLASS_TABLES := ["job_tiers", "classes", "skills", "effects", "perk_branches", "perks", "base_stats", "valor_lines", "paths"]
## Рядкові поля цих записів, які не можуть бути порожні.
const _CLASS_TEXTS := ["name", "desc", "text", "address", "where", "mentor", "label", "scales", "what", "title", "style", "for", "rep", "parent", "class", "skill", "branch"]
## Характеристики героя, які знає код (Player.stats і Player.recalc), у порядку екрана героя.
const STAT_IDS := ["str", "agi", "vit", "spi"]
## Поля активного вміння, яких пасивне не має.
const _ACTIVE_ONLY := ["cost", "cd", "label", "color", "kind", "heals", "scales", "what", "act", "mechanic"]


## Правила таблиць класів і вмінь, що не залежать від інших таблиць.
static func _class_rules(name: String, rows: Dictionary) -> Array:
	var out := []
	var prev_cls := ""
	var prev_branch := 0
	var done_cls := {}
	var own := {}  # клас → id умінь (ранги, які зберігає герой)
	var order := rows.keys()
	for id in rows:
		var R: Dictionary = rows[id]
		var where := "%s/%s" % [name, id]
		_not_blank(R, _CLASS_TEXTS, where, out)
		for k in R:
			if R[k] is bool and not R[k]:
				out.append("%s: «%s» пишеться лише як true" % [where, k])
		match name:
			"job_tiers":
				var X: Dictionary = R.get("xp", _EMPTY)
				_positive(X, ["base"], where + ".xp", out)
				_positive(X, ["per", "square"], where + ".xp", out, true)
			"classes":
				_positive(R, ["job_max", "hp_mult", "dmg_mult", "mana_mult", "regen_mult", "skill_mult"], where, out)
				var nx: Array = R.get("next", [])
				if nx.is_empty() and R.has("change_at"):
					out.append("%s: «change_at» без «next»: далі нема куди йти" % where)
				if not nx.is_empty() and not R.has("change_at"):
					out.append("%s: є «next», а з якого рівня майстерності йти далі («change_at»), не сказано" % where)
				if R.has("change_at") and (int(R["change_at"]) < 1 or int(R["change_at"]) > int(R.get("job_max", 0))):
					out.append("%s: «change_at» %d має бути від 1 до «job_max» (%d)" % [where, int(R["change_at"]), int(R.get("job_max", 0))])
				if id in nx:
					out.append("%s: клас веде сам у себе («next»)" % where)
				for k in ["next", "weapons", "branches"]:
					var seen := {}
					for x in R.get(k, []):
						if str(x).strip_edges() == "":
							out.append("%s: порожнє значення в «%s»" % [where, k])
						if seen.has(x):
							out.append("%s: «%s» двічі в «%s»" % [where, x, k])
						seen[x] = true
				if R.get("weapons", []).is_empty():
					out.append("%s: «weapons» порожні" % where)
			"skills":
				var cls := str(R.get("class", ""))
				var sid := str(R.get("skill", id))
				if R.has("skill") and id != "%s_%s" % [R["skill"], cls]:
					out.append("%s: вузол зі «skill» має ключ «%s_%s»" % [where, R["skill"], cls])
				if R.has("skill") and (not rows.has(R["skill"]) or order.find(R["skill"]) > order.find(id)):
					out.append("%s: «skill» — нема раніше у файлі вузла з ключем «%s»" % [where, R["skill"]])
				if cls != prev_cls:
					if done_cls.has(cls):
						out.append("%s: вузли класу «%s» мають іти у файлі підряд" % [where, cls])
					done_cls[cls] = true
					prev_cls = cls
					prev_branch = 0
				if int(R.get("branch", 0)) < prev_branch:
					out.append("%s: гілка %d після гілки %d: вузли йдуть гілка за гілкою" % [where, int(R.get("branch", 0)), prev_branch])
				prev_branch = int(R.get("branch", 0))
				if not own.has(cls):
					own[cls] = {}
				if own[cls].has(sid):
					out.append("%s: уміння «%s» двічі в дереві класу «%s»" % [where, sid, cls])
				own[cls][sid] = true
				_positive(R, ["max", "branch"], where, out)
				for r in R.get("req", _EMPTY):
					if int(R["req"][r]) < 1:
						out.append("%s: «req.%s» має бути від 1" % [where, r])
					if r == sid:
						out.append("%s: уміння вимагає саме себе" % where)
				var A: Dictionary = R.get("act", _EMPTY)
				if R.get("active", false):
					for k in ["cost", "cd", "label", "kind"]:
						if not R.has(k):
							out.append("%s: активному вмінню потрібне «%s»" % [where, k])
					_positive(R, ["cost", "cd"], where, out)
					if not R.has("color") and not A.has("color"):
						out.append("%s: кнопці бою потрібен колір («color» чи «act.color»)" % where)
					if R.has("act"):
						var heals: bool = A.has("heal") or A.get("fx", _EMPTY).has("regen_pct")
						if R.get("heals", false) != heals:
							out.append("%s: «heals» має бути %s: уміння за даними лікує, коли в «act» є «heal» чи «fx.regen_pct»" % [where, "true" if heals else "відсутнім"])
						if A.has("color") and not Color.html_is_valid(str(A["color"])):
							out.append("%s: «act.color» — не колір («%s»)" % [where, A["color"]])
						if A.has("status") and float(A["status"][1]) <= 0.0:
							out.append("%s: «act.status» — секунд має бути більше нуля" % where)
						if str(A.get("type", "")) == "buff" and A.has("at"):
							out.append("%s: «act.at» не має сенсу для підсилення" % where)
						if R.has("mechanic"):
							out.append("%s: «mechanic» і «act» разом: дію робить або механіка вміння, або шаблон" % where)
					else:
						for k in ["what", "scales", "mechanic"]:
							if not R.has(k):
								out.append("%s: уміння з коду потребує «%s» (картка, механіка)" % [where, k])
					if R.has("mechanic") and not _is_mechanic_ref(str(R["mechanic"]), "skill"):
						out.append("%s: «mechanic» має бути \"skill/<файл>\", а не «%s»" % [where, R["mechanic"]])
				else:
					for k in _ACTIVE_ONLY:
						if R.has(k):
							out.append("%s: «%s» буває лише в активного вміння («active»)" % [where, k])
				if R.has("act") and R.has("fx"):
					out.append("%s: «fx» пасивного вміння й «act» разом: пасивний бонус не діяв би" % where)
				if R.has("when") and not R.has("fx"):
					out.append("%s: «when» без «fx»" % where)
				if R.has("when") and R["when"]["weapon"].is_empty():
					out.append("%s: «when.weapon» порожній" % where)
			"effects":
				if R.has("text") and not "%s" in str(R["text"]):
					out.append("%s: «text» має містити %%s (число)" % where)
			"perks":
				_positive(R, ["max", "tier"], where, out)
			"valor_lines":
				if R.get("named", false):
					for k in ["name", "per"]:
						if R.has(k):
							out.append("%s: бонус іменних звитяг («named») не має «%s»: очок у нього не вкладають" % [where, k])
				else:
					for k in ["name", "per"]:
						if not R.has(k):
							out.append("%s: лінії звитяги потрібне «%s»" % [where, k])
					_positive(R, ["per"], where, out)
				if R.has("text") and not "%s" in str(R["text"]):
					out.append("%s: «text» має містити %%s (відсотки)" % where)
			"paths":
				if R.has("rep") != R.has("talk"):
					out.append("%s: картка вибору дороги має і «rep» (хто розповідає), і «talk» (що)" % where)
				if R.has("talk") and R["talk"].is_empty():
					out.append("%s: «talk» порожній" % where)
				for i in R.get("talk", []).size():
					if str(R["talk"][i][0]).strip_edges() == "" or str(R["talk"][i][1]).strip_edges() == "":
						out.append("%s: «talk[%d]»: порожній мовець чи текст" % [where, i])
				for k in ["strong", "weak", "skills"]:
					if R.get(k, []).is_empty():
						out.append("%s: «%s» порожні" % [where, k])
				for k in ["strong", "weak", "skills", "next"]:
					for x in R.get(k, []):
						if str(x).strip_edges() == "":
							out.append("%s: порожній рядок у «%s»" % [where, k])
	match name:
		"job_tiers":
			out.append_array(_contiguous(name, rows, "tier", 0))
		"valor_lines":
			var lines := 0
			for id in rows:
				lines += 0 if rows[id].get("named", false) else 1
			if not rows.is_empty() and lines == 0:
				out.append("valor_lines: жодної лінії, у яку можна вкласти очко")
	return out


## Ланцюжок класів від першого до cls за записами класів (як Classes.lineage).
static func _lineage_in(classes: Dictionary, cls: String) -> Array:
	var out := [cls]
	var guard := 0
	var c := cls
	while guard < 20:
		guard += 1
		var up := ""
		for p in classes:
			if c in classes[p].get("next", []):
				up = p
				break
		if up == "" or up in out:
			break
		out.push_front(up)
		c = up
	return out


## Посилання таблиць класів і вмінь на інші таблиці й на код гри.
static func _class_links(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"classes":
			var from := {}  # клас → хто веде до нього («next»)
			for id in rows:
				for x in rows[id].get("next", []):
					if from.has(x):
						out.append("classes/%s: до «%s» уже веде «%s»: у класу один попередник" % [id, x, from[x]])
					else:
						from[x] = id
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "classes/" + id
				if R.has("tier") and not _tier_exists("job_tiers", int(R["tier"])):
					out.append("%s: «tier» %d — нема такого ступеня в job_tiers.json" % [where, int(R["tier"])])
				for x in R.get("next", []):
					if not rows.has(x):
						out.append("%s: «next» — нема класу «%s»" % [where, x])
					elif int(rows[x].get("tier", 0)) <= int(R.get("tier", 0)):
						out.append("%s: «next» — «%s» не вищого ступеня" % [where, x])
					elif rows[x].has("parent") and str(rows[x]["parent"]) != id:
						out.append("%s: «next» — у «%s» інший «parent» (%s)" % [where, x, rows[x]["parent"]])
					elif not rows[x].has("parent") and R.has("parent"):
						out.append("%s: «next» — «%s» без «parent»: спеціалізація має знати, чия вона" % [where, x])
				if R.has("parent"):
					if not rows.has(R["parent"]):
						out.append("%s: «parent» — нема класу «%s»" % [where, R["parent"]])
					elif not id in rows[R["parent"]].get("next", []):
						out.append("%s: «parent» — «%s», а в його «next» цього класу нема" % [where, R["parent"]])
					for k in ["where", "mentor"]:
						if not R.has(k):
							out.append("%s: спеціалізації потрібне «%s» (наставник і місто посвяти)" % [where, k])
				if not from.has(id) and id != "peasant":
					out.append("%s: до класу не веде жоден «next» (нова гра починається Селянином, «peasant»)" % where)
				for w in R.get("weapons", []):
					if not _has_row("weapons", w):
						out.append("клас %s носить зброю «%s», якої нема у weapons.json" % [id, w])
				if R.has("where") and not _has_row("cities", R["where"]):
					out.append("%s: «where» — нема міста «%s» у cities.json" % [where, R["where"]])
				if R.has("mentor") and not _has_row("speakers", R["mentor"]):
					out.append("%s: «mentor» — нема «%s» у speakers.json" % [where, R["mentor"]])
				var used := {}
				for s in ids("skills"):
					if str(row("skills", s).get("class", "")) == id:
						used[int(row("skills", s).get("branch", 0))] = true
				for i in R.get("branches", []).size():
					if not used.has(i + 1):
						out.append("%s: у гілці «%s» (%d) нема жодного вузла в skills.json" % [where, R["branches"][i], i + 1])
			for s in ids("skills"):
				if not rows.has(str(row("skills", s).get("class", ""))):
					out.append("skills/%s: «class» — нема класу «%s» у classes.json" % [s, row("skills", s).get("class", "")])
			if not rows.is_empty() and not rows.has("peasant"):
				out.append("classes: нема класу «peasant», а нова гра починається з нього")
			elif rows.has("peasant") and (from.has("peasant") or rows["peasant"].has("parent")):
				out.append("classes/peasant: перший клас не має попередника")
		"skills":
			var Icons = load("res://scripts/data/skill_icon_index.gd")
			var Index = load("res://scripts/data/sound_index.gd")
			var classes: Dictionary = table("classes")
			var nodes := {}  # клас → {id уміння: найвищий ранг}
			var sused := {}  # посилання на механіки вмінь і шаблонів дії
			for id in rows:
				var c := str(rows[id].get("class", ""))
				if not nodes.has(c):
					nodes[c] = {}
				nodes[c][str(rows[id].get("skill", id))] = int(rows[id].get("max", 0))
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "skills/" + id
				var cls := str(R.get("class", ""))
				var sid := str(R.get("skill", id))
				if not classes.has(cls):
					out.append("%s: «class» — нема класу «%s» у classes.json" % [where, cls])
					continue
				var nb: int = classes[cls].get("branches", []).size()
				if int(R.get("branch", 0)) > nb:
					out.append("%s: «branch» %d, а в класу «%s» гілок %d («branches»)" % [where, int(R.get("branch", 0)), cls, nb])
				var lin := _lineage_in(classes, cls)
				for r in R.get("req", _EMPTY):
					var top := 0
					for c in lin:
						top = maxi(top, int(nodes.get(c, _EMPTY).get(r, 0)))
					if top == 0:
						out.append("%s: «req» — уміння «%s» нема на дорозі класу %s" % [where, r, str(lin)])
					elif int(R["req"][r]) > top:
						out.append("%s: «req.%s» %d, а найвищий ранг «%s» — %d" % [where, r, int(R["req"][r]), r, top])
				var A: Dictionary = R.get("act", _EMPTY)
				for k in R.get("fx", _EMPTY).keys() + A.get("fx", _EMPTY).keys():
					if not _has_row("effects", k):
						out.append("%s: «fx» — ключа «%s» нема в effects.json" % [where, k])
				for w in R.get("when", _EMPTY).get("weapon", []):
					if not _has_row("weapons", w):
						out.append("%s: «when.weapon» — нема зброї «%s» у weapons.json" % [where, w])
				if A.has("status") and not _has_row("statuses", str(A["status"][0])):
					out.append("%s: «act.status» — невідомий стан «%s» (див. statuses.json)" % [where, A["status"][0]])
				if A.has("sound") and not Index.SFX.has(str(A["sound"])):
					out.append("%s: «act.sound» — нема звуку «%s» у SoundIndex.SFX" % [where, A["sound"]])
				for k in ["boost", "mark"]:
					if A.has(k) and not nodes.get(cls, _EMPTY).has(str(A[k])):
						out.append("%s: «act.%s» — нема вміння «%s» у дереві класу" % [where, k, A[k]])
				if not Icons.INDEX.has(sid):
					out.append("%s: уміння «%s» без значка (tools/pixel/skill_icons.py → SkillIconIndex.INDEX)" % [where, sid])
				if R.has("mechanic"):
					_mechanic_ref(where, "mechanic", str(R["mechanic"]), sused, out)
				if A.has("type"):
					_mechanic_ref(where, "act.type", "act/" + str(A["type"]), sused, out)
			out.append_array(_mechanic_orphans(["skill", "act"], sused, "skills.json"))
		"perks":
			var branches: Array = ids("perk_branches")
			var last := {}  # гілка → останній ярус у файлі
			var at := -1
			for id in rows:
				var R: Dictionary = rows[id]
				var b := str(R.get("branch", ""))
				var bi := branches.find(b)
				if bi < 0:
					out.append("perks/%s: «branch» — нема гілки «%s» у perk_branches.json" % [id, b])
					continue
				if bi < at:
					out.append("perks/%s: Загартування йде у файлі гілка за гілкою, як у perk_branches.json" % id)
				at = bi
				var t := int(R.get("tier", 0))
				if t < int(last.get(b, 1)) or t > int(last.get(b, 0)) + 1:
					out.append("perks/%s: ярус %d після ярусу %d гілки «%s»: яруси йдуть підряд від 1" % [id, t, int(last.get(b, 0)), b])
				last[b] = maxi(t, int(last.get(b, 0)))
			for b in branches:
				if not last.has(b):
					out.append("perk_branches/%s: у гілці нема жодного вміння (perks.json)" % b)
		"perk_branches":
			for b in rows:
				var n := 0
				for p in ids("perks"):
					n += 1 if str(row("perks", p).get("branch", "")) == b else 0
				if n == 0:
					out.append("perk_branches/%s: у гілці нема жодного вміння (perks.json)" % b)
			for p in ids("perks"):
				if not rows.has(str(row("perks", p).get("branch", ""))):
					out.append("perks/%s: «branch» — нема гілки «%s» у perk_branches.json" % [p, row("perks", p).get("branch", "")])
		"job_tiers":
			for c in ids("classes"):
				var t := int(row("classes", c).get("tier", 0))
				var found := false
				for id in rows:
					found = found or int(rows[id].get("tier", -1)) == t
				if not found:
					out.append("classes/%s: «tier» %d — нема такого ступеня в job_tiers.json" % [c, t])
		"effects":
			# Ключі «fx» умінь, зачарувань і божих дарів (ті самі тексти, що й у їхніх таблицях)
			for id in ids("skills"):
				var R: Dictionary = row("skills", id)
				for k in R.get("fx", _EMPTY).keys() + R.get("act", _EMPTY).get("fx", _EMPTY).keys():
					if not rows.has(k):
						out.append("skills/%s: «fx» — ключа «%s» нема в effects.json" % [id, k])
			for t in ["enchants", "gifts"]:
				for id in ids(t):
					for k in row(t, id).get("fx", _EMPTY):
						if not rows.has(k):
							out.append("%s/%s: «fx» — ключа «%s» нема в effects.json" % [t, id, k])
		"valor_lines":
			for l in ids("lands"):
				for k in row("lands", l).get("title_fx", _EMPTY):
					if not rows.has(k):
						out.append("lands/%s: «title_fx» — ключа «%s» нема у valor_lines.json" % [l, k])
		"base_stats":
			if rows.keys() != STAT_IDS:
				out.append("base_stats: характеристики %s, а код знає %s (GameDB.STAT_IDS): нова характеристика потребує коду в Player (stats, recalc)" % [str(rows.keys()), str(STAT_IDS)])
		"paths":
			var first: Array = row("classes", "peasant").get("next", [])
			for id in rows:
				var R: Dictionary = rows[id]
				if not _has_row("classes", id):
					out.append("paths/%s: нема класу «%s» у classes.json" % [id, id])
				if R.has("rep") and not _has_row("speakers", R["rep"]):
					out.append("paths/%s: «rep» — нема «%s» у speakers.json" % [id, R["rep"]])
				for i in R.get("talk", []).size():
					if not _has_row("speakers", R["talk"][i][0]):
						out.append("paths/%s: «talk[%d]» — мовця «%s» нема в speakers.json" % [id, i, R["talk"][i][0]])
				if R.has("rep") != (id in first):
					out.append("paths/%s: картку вибору дороги («rep», «talk») мають саме класи з «next» Селянина %s" % [id, str(first)])
			for c in first:
				if not rows.has(c):
					out.append("paths: клас «%s» обирають на Січі, а картки дороги в paths.json нема" % c)
	return out


# ---------- Завдання й історія: правила й посилання ----------

## Таблиці завдань: їхні правила — _quest_rules, посилання — _quest_links.
const QUEST_TABLES := ["speakers", "story_chapters", "story", "quest_lines", "legend_steps", "saga", "way", "daily", "weekly", "achievements", "spec_trials"]
## Рядкові поля записів завдань, які не можуть бути порожні («city», «turn_in» і «role» бувають порожні навмисно).
const _QUEST_TEXTS := ["name", "title", "how", "desc", "land", "source", "text", "where", "need", "stat", "giver", "chapter", "line", "if", "choice_key"]
## Які типи мети вміє служба кожної таблиці.
const QUEST_OBJECTIVES := {
	"story": ["clear", "dungeon", "kill", "fetch", "visit", "job", "choose"],
	"legend_steps": ["clear", "dungeon", "kill", "fetch"],
	"saga": ["dungeon"],
	"spec_trials": ["clear", "dungeon", "kill", "elite"],
}
## Які поля нагороди читає служба кожної таблиці (нагорода кроку, вибору й бонусу) і чи річ має свій рівень («ilvl»).
const QUEST_REWARDS := {
	"story": {"keys": ["gold", "xp", "rank", "class", "banner", "skills", "stats", "loyalty", "item"], "ilvl": true},
	"legend_steps": {"keys": ["gold_lvl", "trophy", "item"], "ilvl": false},
	"saga": {"keys": ["gold", "trophy", "xp", "item"], "ilvl": true},
}
## Яка лінія (kind у quest_lines.json) у кроків кожної таблиці.
const QUEST_LINE_KIND := {"story": "story", "legend_steps": "legend", "saga": "saga"}


## Правила таблиць завдань, що не залежать від інших таблиць.
static func _quest_rules(name: String, rows: Dictionary) -> Array:
	var out := []
	var stats := {}
	var keys := rows.keys()
	for i in keys.size():
		var id: String = keys[i]
		var R: Dictionary = rows[id]
		var where := "%s/%s" % [name, id]
		_not_blank(R, _QUEST_TEXTS, where, out)
		for k in R:
			# «story» кроку може й вимкнути сюжетність, яку дає лінія
			if R[k] is bool and not R[k] and not (k == "story" and QUEST_LINE_KIND.has(name)):
				out.append("%s: «%s» пишеться лише як true" % [where, k])
		if QUEST_OBJECTIVES.has(name) and R.has("objective"):
			_objective_rules(where, R["objective"], QUEST_OBJECTIVES[name], out)
		for k in ["start", "end", "intro"]:
			for j in R.get(k, []).size():
				var ln: Array = R[k][j]
				if str(ln[0]).strip_edges() == "" or str(ln[1]).strip_edges() == "":
					out.append("%s: «%s[%d]»: порожній мовець чи текст" % [where, k, j])
				if ln.size() > 2 and not _is_cond(str(ln[2])):
					out.append("%s: «%s[%d]»: умова має бути \"ключ=номер вибору\", а не «%s»" % [where, k, j, ln[2]])
		if QUEST_LINE_KIND.has(name):
			# Крок лінії: «after» — список кроків, на які він чекає (посилання й цикли — _quest_graph_problems)
			var seen_after := {}
			for a in R.get("after", []):
				if str(a).strip_edges() == "":
					out.append("%s: «after»: порожній id кроку" % where)
				elif str(a) == id:
					out.append("%s: «after»: крок не може чекати сам на себе" % where)
				elif seen_after.has(a):
					out.append("%s: «after»: «%s» двічі" % [where, a])
				seen_after[a] = true
			if R.has("after") and R["after"].is_empty():
				out.append("%s: «after» порожній (перший крок лінії пишуть без поля)" % where)
			_positive(R, ["min_level"], where, out)
			var RW: Dictionary = QUEST_REWARDS[name]
			_reward_rules(where + ".reward", R.get("reward", _EMPTY), RW["keys"], RW["ilvl"], out)
			if R.has("start") and R["start"].is_empty() and name != "story":
				out.append("%s: «start» порожній: оповідачеві нема що сказати" % where)
			if R.has("end") and R["end"].is_empty() and name != "story":
				out.append("%s: «end» порожній" % where)
		match name:
			"speakers":
				pass
			"story_chapters":
				if R.has("cleanse") and R["cleanse"].is_empty():
					out.append("%s: «cleanse» порожній" % where)
				if R.has("cleanse") and R.get("cleanse_all", false):
					out.append("%s: «cleanse» разом із «cleanse_all»: зараза й так зникає всюди" % where)
			"story":
				if str(R.get("city", "")) == "" and not R.get("start", []).is_empty():
					out.append("%s: «city» порожнє, а розмова «start» є: її ніде почути" % where)
				if R.has("intro") and not R.get("after", []).is_empty():
					out.append("%s: «intro» читає лише крок, з якого історія починається (без «after»): вступ нової гри" % where)
				if R.has("if") and not _is_cond(str(R["if"])):
					out.append("%s: «if» має бути \"ключ=номер вибору\", а не «%s»" % [where, R["if"]])
				if R.has("choice_key") and R.get("choices", []).is_empty():
					out.append("%s: «choice_key» без «choices»" % where)
				var with_class := 0
				for j in R.get("choices", []).size():
					var C: Dictionary = R["choices"][j]
					var cw := "%s.choices[%d]" % [where, j]
					_not_blank(C, ["text", "reply", "memo", "class"], cw, out)
					_reward_rules(cw + ".reward", C.get("reward", _EMPTY), QUEST_REWARDS["story"]["keys"], true, out)
					with_class += 1 if C.has("class") else 0
				if with_class > 0 and with_class != R["choices"].size():
					out.append("%s: «class» мають або всі вибори (вибір дороги), або жоден" % where)
				for j in R.get("bonus", []).size():
					var B: Dictionary = R["bonus"][j]
					if not _is_cond(str(B.get("if", ""))):
						out.append("%s.bonus[%d]: «if» має бути \"ключ=номер вибору\"" % [where, j])
					_reward_rules("%s.bonus[%d].reward" % [where, j], B.get("reward", _EMPTY), QUEST_REWARDS["story"]["keys"], true, out)
			"quest_lines":
				var kind := str(R.get("kind", ""))
				var need: Array = {"story": [], "legend": ["title", "land", "source", "min_level"], "saga": ["title", "min_level"]}.get(kind, [])
				var allow: Array = {"story": ["title"], "legend": need, "saga": need}.get(kind, [])
				for k in need:
					if not R.has(k):
						out.append("%s: лінії «%s» потрібне «%s»" % [where, kind, k])
				for k in ["title", "land", "source", "min_level"]:
					if R.has(k) and not k in allow:
						out.append("%s: лінія «%s» не має «%s» (рушій його не читає)" % [where, kind, k])
				_positive(R, ["min_level"], where, out)
			"way":
				var C: Dictionary = R.get("check", _EMPTY)
				var main := []
				for k in C:
					if not k in ["n", "or"]:
						main.append(k)
				if main.size() != 1:
					out.append("%s: «check» має бути рівно одна умова з %s, а тут %s" % [where, str(load("res://scripts/game/way_service.gd").CHECKS), str(main)])
				if C.has("stat") != C.has("n"):
					out.append("%s: «check.stat» і «check.n» ідуть разом" % where)
				if C.has("or") and not C.has("stat"):
					out.append("%s: «check.or» буває лише з «stat»" % where)
				_positive(C, ["n", "equip", "quests", "loyalty", "companions", "camp", "tier"], where + ".check", out)
				_positive(R.get("reward", _EMPTY), ["gold", "potions", "mana", "trophy"], where + ".reward", out, true)
				for r in R.get("reward", _EMPTY).get("res", _EMPTY):
					if int(R["reward"]["res"][r]) <= 0:
						out.append("%s: «reward.res.%s» має бути більшим за нуль" % [where, r])
				var G: Dictionary = R.get("go", _EMPTY)
				if G.has("place") == G.has("tab"):
					out.append("%s: «go» — або «place», або «tab»" % where)
			"daily", "weekly":
				var g: Array = R.get("goal", [])
				if g.size() == 2 and (int(g[0]) < 1 or int(g[0]) > int(g[1])):
					out.append("%s: «goal» має бути [найменше ≥ 1, найбільше ≥ найменшого]" % where)
				if g.size() == 2 and int(g[0]) != int(g[1]) and not "%d" in str(R.get("text", "")):
					out.append("%s: мета буває різна, а в «text» нема %%d" % where)
				var st := str(R.get("stat", ""))
				if stats.has(st):
					out.append("%s: лічильник «%s» уже має «%s» (з двох однакових випаде лише один)" % [where, st, stats[st]])
				stats[st] = id
			"achievements":
				_positive(R, ["goal"], where, out)
				_positive(R, ["gold"], where, out, true)
	return out


## Умова "ключ=номер вибору" (ключ — id кроку чи його «choice_key»).
static func _is_cond(cond: String) -> bool:
	var parts := cond.split("=")
	return parts.size() == 2 and _is_id(parts[0]) and parts[1].is_valid_int() and int(parts[1]) >= 0


## Мета кроку: тип, який служба вміє, і поля, які цей тип читає.
static func _objective_rules(where: String, o: Dictionary, types: Array, out: Array) -> void:
	var t := str(o.get("type", ""))
	if not t in types:
		out.append("%s: мета «%s» — служба вміє лише %s" % [where, t, str(types)])
		return
	var reads: Dictionary = {"clear": ["loc"], "dungeon": ["loc"], "visit": ["loc"], "choose": ["loc"], "job": ["count", "loc"],
		"kill": ["enemy", "count", "loc"], "fetch": ["enemy", "count", "item", "chance", "loc"], "elite": ["count"]}
	for k in reads[t]:
		if not o.has(k):
			out.append("%s: мета «%s» потребує «objective.%s»" % [where, t, k])
	for k in ["enemy", "count", "loc", "item", "chance"]:
		if o.has(k) and not k in reads[t]:
			out.append("%s: мета «%s» не читає «objective.%s»" % [where, t, k])
	if o.has("count") and int(o["count"]) < 1:
		out.append("%s: «objective.count» має бути від 1" % where)
	if o.has("chance") and (float(o["chance"]) <= 0.0 or float(o["chance"]) > 1.0):
		out.append("%s: «objective.chance» має бути від 0 до 1" % where)
	_not_blank(o, ["enemy", "loc", "item", "text"], where + ".objective", out)


## Нагорода: лише ті поля, які служба читає; числа не від'ємні; клас і звання з написом.
static func _reward_rules(where: String, r: Dictionary, allowed: Array, ilvl: bool, out: Array) -> void:
	for k in r:
		if not k in allowed:
			out.append("%s: служба не читає «%s» (читає %s)" % [where, k, str(allowed)])
	_positive(r, ["gold", "gold_lvl", "xp", "trophy"], where, out, true)
	for m in ["skills", "stats", "loyalty"]:
		for k in r.get(m, _EMPTY):
			if int(r[m][k]) <= 0:
				out.append("%s: «%s.%s» має бути більшим за нуль" % [where, m, k])
	if r.has("class") and r.has("rank"):
		out.append("%s: «class» і «rank» разом: банер один" % where)
	if (r.has("class") or r.has("rank")) != r.has("banner"):
		out.append("%s: «banner» пишуть тоді й лише тоді, коли є «class» чи «rank»" % where)
	_not_blank(r, ["class", "rank", "banner"], where, out)
	if r.has("item"):
		var it: Dictionary = r["item"]
		_not_blank(it, ["slot", "type", "name"], where + ".item", out)
		if it.has("ilvl") != ilvl:
			out.append("%s.item: «ilvl» %s" % [where, "потрібен" if ilvl else "не пишуть: річ рівня героя"])
		_positive(it, ["ilvl"], where + ".item", out)
		_positive(it, ["up", "rarity"], where + ".item", out, true)


## Ключ вибору → [id кроку, скільки виборів]: так умови "ключ=вибір" знаходять свій крок.
static func _choice_keys(steps: Dictionary) -> Dictionary:
	var out := {}
	for id in steps:
		var R: Dictionary = steps[id]
		if not R.get("choices", []).is_empty():
			out[str(R.get("choice_key", id))] = [str(id), R["choices"].size()]
	return out


## Умова "ключ=вибір": крок із такими виборами є. before — id кроків, на які чекає крок з умовою
## (усі попередники за «after»): вибір мусить бути зроблений на одному з них. null — порядок не перевіряти.
static func _cond_problem(cond: String, keys: Dictionary, before) -> String:
	if not _is_cond(cond):
		return "умова має бути \"ключ=номер вибору\", а не «%s»" % cond
	var parts := cond.split("=")
	if not keys.has(parts[0]):
		return "умова «%s» — нема кроку з виборами під ключем «%s»" % [cond, parts[0]]
	if int(parts[1]) >= int(keys[parts[0]][1]):
		return "умова «%s» — у кроку «%s» лише %d вибори" % [cond, parts[0], int(keys[parts[0]][1])]
	if before is Dictionary and not before.has(str(keys[parts[0]][0])):
		return "умова «%s» — вибір робить крок «%s», а він не серед тих, на які цей крок чекає («after»)" % [cond, keys[parts[0]][0]]
	return ""


## Розмова: мовці є в speakers.json, умови реплік — справжні вибори (зроблені на кроках із before, якщо дано).
static func _dialogue_links(where: String, field: String, lines: Array, keys: Dictionary, before, out: Array) -> void:
	for j in lines.size():
		if not _has_row("speakers", lines[j][0]):
			out.append("%s: «%s[%d]» — мовця «%s» нема в speakers.json" % [where, field, j, lines[j][0]])
		if lines[j].size() > 2:
			var p := _cond_problem(str(lines[j][2]), keys, before)
			if p != "":
				out.append("%s: «%s[%d]»: %s" % [where, field, j, p])


## Таблиці кроків завдань (у порядку показу) і вид лінії, яку веде кожна.
const QUEST_STEP_TABLES := ["story", "legend_steps", "saga"]


## Кроки всіх ліній: id → запис, у порядку QUEST_STEP_TABLES і файлів. over — {таблиця: записи},
## що підміняють таблиці бази (перевірка запису до того, як його записати; тести).
static func quest_steps(over: Dictionary = {}) -> Dictionary:
	var out := {}
	for t in QUEST_STEP_TABLES:
		var rows: Dictionary = over[t] if over.has(t) else table(t)
		for id in rows:
			out[id] = rows[id]
	return out


## Усі попередники кроків за «after» (на кого крок чекає прямо чи через інших): id → {id: true}.
## Цикли не зависають: крок, до якого повернулись, просто не дає нових попередників.
static func quest_ancestors(steps: Dictionary) -> Dictionary:
	var out := {}
	for id in steps:
		_ancestors_of(steps, str(id), out, {})
	return out


static func _ancestors_of(steps: Dictionary, id: String, memo: Dictionary, busy: Dictionary) -> Dictionary:
	if memo.has(id):
		return memo[id]
	var got := {}
	if busy.has(id) or not steps.has(id):
		return got
	busy[id] = true
	for a in steps[id].get("after", []):
		got[str(a)] = true
		for x in _ancestors_of(steps, str(a), memo, busy):
			got[x] = true
	busy.erase(id)
	memo[id] = got
	return got


## Граф завдань: кожен крок належить лінії, «after» веде на справжні кроки, циклів нема, кожен крок
## досяжний від кроку без «after», id кроків не повторюються між таблицями, умови («if», репліки, бонуси)
## читають вибір, зроблений на кроці-попереднику. lines — записи quest_lines, tables — {таблиця кроків: записи}
## (будь-які з QUEST_STEP_TABLES; так граф можна перевірити й на даних, що в пам'яті).
static func quest_graph_problems(lines: Dictionary, tables: Dictionary) -> Array:
	var out := []
	var steps := {}
	var where := {}
	for t in QUEST_STEP_TABLES:
		for id in tables.get(t, _EMPTY):
			if steps.has(id):
				out.append("%s/%s: такий id кроку вже є в %s" % [t, id, str(where[id]).get_slice("/", 0)])
				continue
			steps[id] = tables[t][id]
			where[id] = "%s/%s" % [t, id]
	var kids := {}
	for id in steps:
		var R: Dictionary = steps[id]
		if not lines.has(str(R.get("line", ""))):
			out.append("%s: «line» — нема лінії «%s» у quest_lines.json" % [where[id], R.get("line", "")])
		for a in R.get("after", []):
			if not steps.has(str(a)):
				out.append("%s: «after» — нема кроку «%s»" % [where[id], a])
			else:
				if not kids.has(str(a)):
					kids[str(a)] = []
				kids[str(a)].append(id)
	# Цикли: обхід углиб, сірий — крок на шляху зараз
	var color := {}
	for id in steps:
		if not color.has(id):
			_find_cycles(steps, id, color, [], where, out)
	# Досяжність: від кроків без «after» униз за «after»
	var seen := {}
	var queue := []
	for id in steps:
		if steps[id].get("after", []).is_empty():
			seen[id] = true
			queue.append(id)
	while not queue.is_empty():
		var id: String = queue.pop_back()
		for k in kids.get(id, []):
			if not seen.has(k):
				seen[k] = true
				queue.append(k)
	for id in steps:
		if not seen.has(id):
			out.append("%s: крок недосяжний: від жодного кроку без «after» до нього не дійти" % where[id])
	# Умови: вибір робиться на попереднику
	var keys := _choice_keys(steps)
	var anc := quest_ancestors(steps)
	for id in steps:
		var R: Dictionary = steps[id]
		var before: Dictionary = anc.get(id, _EMPTY)
		if R.has("if"):
			var p := _cond_problem(str(R["if"]), keys, before)
			if p != "":
				out.append("%s: «if»: %s" % [where[id], p])
		for k in ["intro", "start", "end"]:
			for j in R.get(k, []).size():
				if R[k][j].size() > 2:
					var p := _cond_problem(str(R[k][j][2]), keys, before)
					if p != "":
						out.append("%s: «%s[%d]»: %s" % [where[id], k, j, p])
		for j in R.get("bonus", []).size():
			var p := _cond_problem(str(R["bonus"][j].get("if", "")), keys, before)
			if p != "":
				out.append("%s.bonus[%d]: %s" % [where[id], j, p])
	return out


static func _find_cycles(steps: Dictionary, id: String, color: Dictionary, path: Array, where: Dictionary, out: Array) -> void:
	color[id] = 1
	path.append(id)
	for a in steps[id].get("after", []):
		var x := str(a)
		if not steps.has(x):
			continue
		if int(color.get(x, 0)) == 1:
			var loop: Array = path.slice(path.find(x)) + [x]
			out.append("%s: «after» замикає коло (крок → той, на кого він чекає): %s" % [where[x], " → ".join(loop)])
		elif not color.has(x):
			_find_cycles(steps, x, color, path, where, out)
	path.pop_back()
	color[id] = 2


## Граф завдань із підміненою таблицею name (для validate: перевірка запису до того, як його записати).
static func _quest_graph_links(name: String, rows: Dictionary) -> Array:
	var tables := {}
	for t in QUEST_STEP_TABLES:
		tables[t] = rows if t == name else table(t)
	return quest_graph_problems(rows if name == "quest_lines" else table("quest_lines"), tables)


## Мета: місце є й підходить меті, ворог водиться там, місто — справжнє місто.
static func _objective_links(where: String, o: Dictionary, out: Array) -> void:
	var t := str(o.get("type", ""))
	if o.has("enemy") and not has_mob(str(o["enemy"])):
		out.append("%s: «objective.enemy» посилається на нечисть «%s», якої немає в mobs.json" % [where, o["enemy"]])
	if not o.has("loc"):
		return
	var loc := str(o["loc"])
	if t in ["visit", "choose"]:
		if not _has_row("cities", loc):
			out.append("%s: «objective.loc» — нема міста «%s» у cities.json" % [where, loc])
		return
	var L: Dictionary = row("places", loc)
	if L.is_empty():
		if not (t == "job" and _has_row("cities", loc)):
			out.append("%s: «objective.loc» — нема місця «%s» у places.json" % [where, loc])
		return
	if t == "clear" and str(L.get("type", "")) != "field":
		out.append("%s: «%s» — печера, її проходять метою «dungeon», а не «clear»" % [where, loc])
	if t == "dungeon" and str(L.get("type", "")) != "dungeon":
		out.append("%s: «%s» — не печера" % [where, loc])
	if o.has("enemy") and not o["enemy"] in L.get("enemies", []):
		out.append("%s: «%s» не водиться в «%s»" % [where, o["enemy"], loc])


## Нагорода: клас, уміння, характеристики, міста, звання й річ — ті, що є в грі.
static func _reward_links(where: String, r: Dictionary, out: Array) -> void:
	if r.has("class") and not _has_row("classes", r["class"]):
		out.append("%s: «class» — нема класу «%s» у classes.json" % [where, r["class"]])
	if r.has("rank") and not str(r["rank"]) in load("res://scripts/game/story_service.gd").RANKS:
		out.append("%s: «rank» — звання «%s» гра не знає (StoryService.RANKS)" % [where, r["rank"]])
	var skills := {}
	if r.has("skills"):
		for s in ids("skills"):
			skills[str(row("skills", s).get("skill", s))] = true
	for k in r.get("skills", _EMPTY):
		if not skills.has(k):
			out.append("%s: «skills» — нема вміння «%s» у skills.json" % [where, k])
	for k in r.get("stats", _EMPTY):
		if not k in STAT_IDS:
			out.append("%s: «stats» — нема характеристики «%s» (GameDB.STAT_IDS)" % [where, k])
	for k in r.get("loyalty", _EMPTY):
		if not _has_row("cities", k):
			out.append("%s: «loyalty» — нема міста «%s» у cities.json" % [where, k])
	if r.has("item"):
		_reward_item_links(where + ".item", r["item"], out)


## Річ у нагороду: клітинка вдягається, вид зброї — лише для зброї, рідкість і заточка — ті, що є.
static func _reward_item_links(where: String, it: Dictionary, out: Array) -> void:
	var slot := str(it.get("slot", ""))
	if not slot in _worn_slots():
		out.append("%s: «slot» — «%s» не клітинка спорядження" % [where, slot])
	if it.has("type"):
		if not _has_row("weapons", it["type"]):
			out.append("%s: «type» — нема зброї «%s» у weapons.json" % [where, it["type"]])
		if slot != "weapon":
			out.append("%s: «type» пишуть лише для зброї" % where)
	var rank := int(it.get("rarity", -1))
	var lad := ladder("rarities", "rank")
	if rank < 0 or rank >= lad.size() or lad[rank].is_empty():
		out.append("%s: «rarity» %d — нема такої рідкості в rarities.json" % [where, rank])
	if int(it.get("up", 0)) > int(load("res://scripts/data/data.gd").MAX_UPGRADE):
		out.append("%s: «up» більша за найвищу заточку (Data.MAX_UPGRADE)" % where)


## Посилання таблиць завдань на інші таблиці й на код гри.
static func _quest_links(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"speakers":
			for id in load("res://scripts/data/story.gd").CODE_SPEAKERS:
				if not rows.has(id):
					out.append("speakers: нема мовця «%s», а код гри його знає (Story.CODE_SPEAKERS)" % id)
		"story_chapters":
			var used := {}
			for s in ids("story"):
				used[str(row("story", s).get("chapter", ""))] = true
			for id in rows:
				if not used.has(id):
					out.append("story_chapters/%s: у розділі нема жодного кроку (story.json)" % id)
				for p in rows[id].get("cleanse", []):
					if not _has_row("places", p):
						out.append("story_chapters/%s: «cleanse» — нема місця «%s» у places.json" % [id, p])
		"story":
			var chapters: Array = ids("story_chapters")
			var keys := _choice_keys(rows)
			var order := rows.keys()
			var at := -1  # місце розділу останнього кроку
			for i in order.size():
				var id: String = order[i]
				var R: Dictionary = rows[id]
				var where: String = "story/" + id
				var ci := chapters.find(str(R.get("chapter", "")))
				if ci < 0:
					out.append("%s: «chapter» — нема розділу «%s» у story_chapters.json" % [where, R.get("chapter", "")])
				elif ci != at and ci != at + 1:
					out.append("%s: розділ «%s» не на своєму місці: кроки йдуть розділ за розділом у порядку story_chapters.json" % [where, R["chapter"]])
				else:
					at = ci
				if str(row("quest_lines", str(R.get("line", ""))).get("kind", "")) != "story":
					out.append("%s: «line» — «%s» не лінія історії в quest_lines.json" % [where, R.get("line", "")])
				if not _has_row("speakers", R.get("giver", "")):
					out.append("%s: «giver» — нема мовця «%s» у speakers.json" % [where, R.get("giver", "")])
				for k in ["city", "turn_in"]:
					if str(R.get(k, "")) != "" and not _has_row("cities", R[k]):
						out.append("%s: «%s» — нема міста «%s» у cities.json" % [where, k, R[k]])
				for k in ["intro", "start", "end"]:
					_dialogue_links(where, k, R.get(k, []), keys, null, out)  # чи вибір зроблено раніше — _quest_graph_links
				_objective_links(where, R.get("objective", _EMPTY), out)
				_reward_links(where + ".reward", R.get("reward", _EMPTY), out)
				var first: Array = row("classes", "peasant").get("next", [])
				for j in R.get("choices", []).size():
					var C: Dictionary = R["choices"][j]
					var cw := "%s.choices[%d]" % [where, j]
					_reward_links(cw + ".reward", C.get("reward", _EMPTY), out)
					if C.has("class") and not str(C["class"]) in first:
						out.append("%s: «class» — «%s» не обирають на Січі («next» Селянина %s)" % [cw, C["class"], str(first)])
					var SS = load("res://scripts/game/story_service.gd")
					for k in C.get("effects", _EMPTY):
						var ok: bool = k in SS.EFFECTS or (str(k).begins_with("discount_") and _has_row("cities", str(k).trim_prefix("discount_")))
						if not ok:
							out.append("%s: «effects» — наслідку «%s» гра не знає (StoryService.EFFECTS, discount_<місто>)" % [cw, k])
				for j in R.get("bonus", []).size():
					var B: Dictionary = R["bonus"][j]
					_reward_links("%s.bonus[%d].reward" % [where, j], B.get("reward", _EMPTY), out)
			var seen := {}
			for id in rows:
				if not rows[id].get("choices", []).is_empty():
					var k := str(rows[id].get("choice_key", id))
					if seen.has(k):
						out.append("story/%s: вибір під ключем «%s» уже записує «%s»" % [id, k, seen[k]])
					seen[k] = id
			if not rows.is_empty() and at != chapters.size() - 1:
				out.append("story: не всі розділи story_chapters.json мають кроки")
			out.append_array(_quest_graph_links(name, rows))
		"quest_lines":
			for need in [[load("res://scripts/data/story.gd").LINE, "story"], [load("res://scripts/data/saga.gd").LINE, "saga"]]:
				if str(rows.get(need[0], _EMPTY).get("kind", "")) != need[1]:
					out.append("quest_lines: нема лінії «%s» з «kind» «%s», а код гри її знає" % need)
			for id in rows:
				var R: Dictionary = rows[id]
				var kind := str(R.get("kind", ""))
				var table_of: String = {"story": "story", "legend": "legend_steps", "saga": "saga"}.get(kind, "")
				var n := 0
				for s in (ids(table_of) if table_of != "" else []):
					n += 1 if str(row(table_of, s).get("line", "")) == id else 0
				if n == 0:
					out.append("quest_lines/%s: у лінії нема жодного кроку (%s.json)" % [id, table_of])
			out.append_array(_quest_graph_links(name, rows))
		"legend_steps", "saga":
			var story_keys := _choice_keys(table("story"))
			out.append_array(_quest_graph_links(name, rows))
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "%s/%s" % [name, id]
				if str(row("quest_lines", str(R.get("line", ""))).get("kind", "")) != QUEST_LINE_KIND[name]:
					out.append("%s: «line» — «%s» не лінія «%s» у quest_lines.json" % [where, R.get("line", ""), QUEST_LINE_KIND[name]])
				if not _has_row("speakers", R.get("giver", "")):
					out.append("%s: «giver» — нема мовця «%s» у speakers.json" % [where, R.get("giver", "")])
				if not _has_row("cities", R.get("city", "")):
					out.append("%s: «city» — нема міста «%s» у cities.json" % [where, R.get("city", "")])
				for k in ["start", "end"]:
					_dialogue_links(where, k, R.get(k, []), story_keys, null, out)
				_objective_links(where, R.get("objective", _EMPTY), out)
				_reward_links(where + ".reward", R.get("reward", _EMPTY), out)
		"way":
			var WS = load("res://scripts/game/way_service.gd")
			var CS = load("res://scripts/game/challenge_service.gd")
			var Camp = load("res://scripts/data/camp_data.gd")
			var last_tab: int = load("res://scripts/ui/ui_character.gd").TAB_CHALLENGES
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "way/" + id
				var C: Dictionary = R.get("check", _EMPTY)
				for k in ["stat", "or"]:
					if C.has(k) and not CS.is_stat(str(C[k])):
						out.append("%s: «check.%s» — лічильника «%s» гра не рахує (ChallengeService.STATS)" % [where, k, C[k]])
				if C.has("tier") and not _tier_exists("job_tiers", int(C["tier"])):
					out.append("%s: «check.tier» %d — нема такого ступеня в job_tiers.json" % [where, int(C["tier"])])
				var W: Dictionary = R.get("reward", _EMPTY)
				for r in W.get("res", _EMPTY):
					if str(row("resources", r).get("kind", "")) != "res":
						out.append("%s: «reward.res» — невідомий будівельний ресурс «%s» (resources.json)" % [where, r])
				if W.has("item"):
					var lad := ladder("rarities", "rank")
					if int(W["item"]) < 0 or int(W["item"]) >= lad.size() or lad[int(W["item"])].is_empty():
						out.append("%s: «reward.item» %d — нема такої рідкості в rarities.json" % [where, int(W["item"])])
				if W.has("stone") and not _has_row("stones", W["stone"]):
					out.append("%s: «reward.stone» — нема каменя «%s» у stones.json" % [where, W["stone"]])
				var G: Dictionary = R.get("go", _EMPTY)
				if G.has("place"):
					var p := str(G["place"])
					if not (p in WS.GO_PLACES or _has_row("cities", p) or _has_row("places", p) or p == Camp.CAMP_ID or _has_row("spots", p)):
						out.append("%s: «go.place» — нема міста, місця чи заняття «%s» (і це не %s)" % [where, p, str(WS.GO_PLACES)])
				if G.has("tab") and (int(G["tab"]) < 0 or int(G["tab"]) > last_tab):
					out.append("%s: «go.tab» %d — у екрана героя вкладки 0–%d" % [where, int(G["tab"]), last_tab])
		"daily", "weekly":
			var CS = load("res://scripts/game/challenge_service.gd")
			for id in rows:
				var R: Dictionary = rows[id]
				if R.has("stat") and not CS.is_stat(str(R["stat"])):
					out.append("%s/%s: «stat» — лічильника «%s» гра не рахує (ChallengeService.STATS)" % [name, id, R["stat"]])
				if R.has("need") and not str(R["need"]) in CS.NEEDS:
					out.append("%s/%s: «need» — «%s» не з переліку ChallengeService.NEEDS" % [name, id, R["need"]])
		"achievements":
			var CS = load("res://scripts/game/challenge_service.gd")
			for id in rows:
				if rows[id].has("stat") and not CS.is_stat(str(rows[id]["stat"])):
					out.append("achievements/%s: «stat» — лічильника «%s» гра не рахує (ChallengeService.STATS)" % [id, rows[id]["stat"]])
		"spec_trials":
			for id in rows:
				var R: Dictionary = rows[id]
				var where: String = "spec_trials/" + id
				var C: Dictionary = row("classes", id)
				if C.is_empty() or not C.has("parent"):
					out.append("%s: «%s» — не спеціалізація в classes.json (нема «parent»)" % [where, id])
				var wt := str(R.get("item", _EMPTY).get("type", ""))
				if not _has_row("weapons", wt):
					out.append("%s: «item.type» — нема зброї «%s» у weapons.json" % [where, wt])
				elif not C.is_empty() and not wt in C.get("weapons", []):
					out.append("%s: «item.type» — «%s» не зброя класу «%s»" % [where, wt, id])
				for k in ["start", "end"]:
					_dialogue_links(where, k, R.get(k, []), {}, null, out)
				_objective_links(where, R.get("objective", _EMPTY), out)
			for c in ids("classes"):
				if row("classes", c).has("parent") and not rows.has(c):
					out.append("classes/%s: спеціалізація без випробування в spec_trials.json: її не можна обрати" % c)
	return out


# ---------- Заняття, свята, хутір, події, довідник, звуки, імена: правила й посилання ----------

## Таблиці цього етапу: їхні правила — _life_rules, посилання — _life_links.
const LIFE_TABLES := ["glory_ranks", "glory_sources", "rivals", "duel_rounds", "muster_teams", "muster_rounds", "ring_rounds", "spots",
	"trade_goods", "trade_cities", "hunt_animals", "fish", "recipes", "dice_rivals", "trail_kinds", "expeditions", "records", "escorts",
	"holidays", "months", "token_scales",
	"camps", "resources", "buildings", "crops", "brews", "kleinody", "kleinod_tiers", "stones", "fair_goods", "loyalty_levels",
	"road_events", "events", "event_kinds", "boss_hunts", "boss_pools", "boss_mods", "statuses",
	"wiki_sections", "wiki_basics", "wiki_orders", "sounds", "ambients", "name_pools"]
## Ресурси, які код називає прямо (казан, город, зілляварня, пригоди): id → вид.
const CODE_RESOURCES := {"wood": "res", "iron": "res", "herbs": "res", "trophy": "trophy", "meat": "food", "ryba": "food", "veg": "food"}
## Будівлі, які код називає прямо (CampService, GardenService), і поле рівня, яке читає код (bag, rate, beds).
const CODE_BUILDINGS := {"kurin": "", "kuznia": "", "zillia": "", "sklad": "bag", "pasika": "rate", "horod": "beds"}
## Драбини «round» і скільки кіл чекає код: [запис налаштувань, поле] (data/settings.json).
const _ROUND_TABLES := {"duel_rounds": ["duel", "rounds"], "muster_rounds": ["muster", "rounds"], "ring_rounds": ["ring", "ring_stages"]}


## Усі рядки запису (і вкладених записів і списків) не порожні.
static func _no_blank_strings(v, where: String, out: Array) -> void:
	if v is String:
		if v.strip_edges() == "":
			out.append("%s: порожній рядок" % where)
	elif v is Dictionary:
		for k in v:
			_no_blank_strings(v[k], "%s.%s" % [where, k], out)
	elif v is Array:
		for i in v.size():
			_no_blank_strings(v[i], "%s[%d]" % [where, i], out)


## Правила таблиць цього етапу, що не залежать від інших таблиць.
static func _life_rules(name: String, rows: Dictionary) -> Array:
	var out := []
	for id in rows:
		var R: Dictionary = rows[id]
		var where := "%s/%s" % [name, id]
		_no_blank_strings(R, where, out)
		for k in R:
			if R[k] is bool and not R[k]:
				out.append("%s: «%s» пишеться лише як true" % [where, k])
		match name:
			"glory_ranks":
				_positive(R, ["gold"], where, out, true)
			"rivals":
				if str(R.get("mechanic", "")) != "rival/" + str(R.get("style", "")):
					out.append("%s: «mechanic» має бути \"rival/%s\": стиль бою — це ім'я файлу механіки" % [where, R.get("style", "")])
				if R.get("nicks", []).is_empty():
					out.append("%s: «nicks» порожні (бійцям огляду цього стилю нема прізвиськ)" % where)
			"duel_rounds", "muster_rounds", "ring_rounds":
				_positive(R, ["seconds", "hit", "size"], where, out)
				_positive(R, ["gold", "glory", "loyalty", "ally_hit"], where, out, true)
				if float(R.get("hit", 0.0)) >= 1.0 or float(R.get("ally_hit", 0.0)) >= 1.0:
					out.append("%s: удар — частка здоров'я, менша за 1" % where)
			"muster_teams":
				if R.get("styles", []).is_empty():
					out.append("%s: «styles» порожні" % where)
			"spots":
				_positive(R, ["level"], where, out)
				if R.has("pos") and not _in_map(R["pos"]):
					out.append("%s: «pos» %s поза мапою (WorldMap.LON0..LON1, LAT0..LAT1)" % [where, R["pos"]])
			"trade_goods":
				_positive(R, ["base"], where, out)
			"trade_cities":
				for g in R.get("prices", _EMPTY):
					if float(R["prices"][g]) <= 0.0:
						out.append("%s: ціна «%s» має бути більшою за нуль" % [where, g])
			"hunt_animals":
				_positive(R, ["speed", "radius", "meat", "weight"], where, out)
			"fish":
				_positive(R, ["ryba", "window", "reel", "pull", "weight"], where, out)
			"recipes":
				if R.get("need", _EMPTY).is_empty():
					out.append("%s: «need» порожній" % where)
				for r in R.get("need", _EMPTY):
					if int(R["need"][r]) <= 0:
						out.append("%s: «need.%s» має бути більшим за нуль" % [where, r])
			"dice_rivals":
				_positive(R, ["stake"], where, out)
			"trail_kinds":
				_positive(R, ["weight"], where, out)
			"expeditions":
				_positive(R, ["hours", "gold"], where, out)
				_positive(R, ["res", "xp", "item", "trophy", "risk"], where, out, true)
				for k in ["item", "risk"]:
					if float(R.get(k, 0.0)) > 1.0:
						out.append("%s: «%s» — шанс, не більший за 1" % [where, k])
			"records":
				_positive(R, ["step", "glory"], where, out, true)
				if (int(R.get("step", 0)) > 0) != (int(R.get("glory", 0)) > 0):
					out.append("%s: «step» і «glory» або обидва більші за нуль, або обидва нуль" % where)
				if str(R.get("fmt", "")) != "time" and not "%d" in str(R.get("fmt", "")):
					out.append("%s: «fmt» — \"time\" або рядок із %%d" % where)
			"holidays":
				var ways := int(R.has("from") or R.has("to")) + int(R.has("easter")) + int(R.has("nth"))
				if ways != 1:
					out.append("%s: дата — рівно одне з: «from»+«to», «easter», «nth»" % where)
				if R.has("from") != R.has("to"):
					out.append("%s: «from» і «to» ідуть разом" % where)
				for k in ["from", "to"]:
					var d: Array = R.get(k, [1, 1])
					if int(d[0]) < 1 or int(d[0]) > 12 or int(d[1]) < 1 or int(d[1]) > 31:
						out.append("%s: «%s» має бути [місяць 1–12, день 1–31]" % [where, k])
				if R.has("easter") and int(R["easter"][0]) > int(R["easter"][1]):
					out.append("%s: «easter» — [від, до], від не пізніше до" % where)
				if R.has("nth"):
					var n: Array = R["nth"]
					if int(n[0]) < 1 or int(n[0]) > 12 or int(n[1]) < 1 or int(n[1]) > 5 or int(n[2]) < 0 or int(n[2]) > 6:
						out.append("%s: «nth» має бути [місяць 1–12, котрий 1–5, день тижня 0–6]" % where)
				if R.has("days") != R.has("nth"):
					out.append("%s: «days» буває лише з «nth» і тоді обов'язковий" % where)
				_positive(R, ["days"], where, out)
				if R.get("bonus", _EMPTY).is_empty():
					out.append("%s: «bonus» порожній" % where)
				for k in R.get("bonus", _EMPTY):
					if float(R["bonus"][k]) <= 0.0:
						out.append("%s: «bonus.%s» має бути більшим за нуль" % [where, k])
			"token_scales":
				var need: Array = R.get("need", [])
				for i in need.size():
					if int(need[i]) <= 0 or (i > 0 and int(need[i]) <= int(need[i - 1])):
						out.append("%s: «need» — додатні пороги за зростанням" % where)
						break
			"camps":
				if R.has("pos") and not _in_map(R["pos"]):
					out.append("%s: «pos» поза мапою" % where)
			"buildings":
				var lv: Array = R.get("levels", [])
				if lv.is_empty():
					out.append("%s: «levels» порожні" % where)
				for i in lv.size():
					_positive(lv[i], ["gold"], "%s.levels[%d]" % [where, i], out)
					_positive(lv[i], ["wood", "iron", "herbs", "bag", "rate", "beds"], "%s.levels[%d]" % [where, i], out, true)
				for f in ["bag", "rate", "beds"]:
					var n := 0
					for L in lv:
						n += 1 if L.has(f) else 0
					if n != 0 and n != lv.size():
						out.append("%s: «%s» мають або всі рівні, або жоден" % [where, f])
			"crops":
				_positive(R, ["hours", "amount"], where, out)
				_positive(R, ["seed"], where, out, true)
			"brews":
				_positive(R, ["level"], where, out)
				_positive(R, ["herbs", "iron"], where, out, true)
			"kleinody":
				_positive(R, ["per"], where, out)
				if not "%d" in str(R.get("text", "")):
					out.append("%s: «text» має мати %%d — бонус ступеня" % where)
			"kleinod_tiers":
				_positive(R, ["gold", "trophy", "res"], where, out)
			"stones":
				_positive(R, ["price", "chance"], where, out)
				if float(R.get("chance", 0.0)) > 1.0:
					out.append("%s: «chance» не більший за 1" % where)
			"fair_goods":
				_positive(R, ["limit"], where, out)
				_positive(R, ["trophy", "gold"], where, out, true)
			"loyalty_levels":
				_positive(R, ["from", "discount"], where, out, true)
				if float(R.get("discount", 0.0)) >= 1.0:
					out.append("%s: «discount» — частка, менша за 1" % where)
			"road_events":
				if R.get("choices", _EMPTY).is_empty():
					out.append("%s: «choices» порожні" % where)
			"events":
				_positive(R, ["level"], where, out, true)
				var B: Dictionary = R.get("battle", _EMPTY)
				_positive(B, ["deadline", "waves"], where + ".battle", out)
				for v in B.get("gate_hp", []):
					if float(v) <= 0.0:
						out.append("%s: «battle.gate_hp» має бути більшим за нуль" % where)
			"boss_hunts":
				_positive(R, ["min_level", "hp_mult", "dmg_mult", "gold", "xp_part"], where, out)
				_positive(R, ["mods", "trophies", "item_rarity"], where, out, true)
			"boss_pools", "wiki_orders":
				var list: Array = R.get("bosses", R.get("ids", []))
				if list.is_empty():
					out.append("%s: перелік порожній" % where)
				var seen := {}
				for b in list:
					if seen.has(b):
						out.append("%s: «%s» двічі" % [where, b])
					seen[b] = true
			"boss_mods":
				var fx := 0
				for k in R:
					fx += 0 if k in ["num", "name", "desc"] else 1
				if fx == 0:
					out.append("%s: властивість нічого не робить (нема жодного поля, крім назви й опису)" % where)
				_positive(R, ["boss_dmg_mult", "boss_hp_mult", "boss_speed_mult", "minions", "enrage_after"], where, out)
				_positive(R, ["elite_bonus"], where, out, true)
			"name_pools":
				if R.get("words", []).is_empty():
					out.append("%s: «words» порожні" % where)
	match name:
		"glory_ranks":
			out.append_array(_contiguous(name, rows, "rank", 0))
			out.append_array(_ascending(name, _ladder_of(rows, "rank"), "рангу"))
		"duel_rounds", "muster_rounds", "ring_rounds":
			out.append_array(_contiguous(name, rows, "round", 0))
		"kleinod_tiers":
			out.append_array(_contiguous(name, rows, "tier", 1))
		"loyalty_levels":
			out.append_array(_contiguous(name, rows, "level", 0))
			out.append_array(_ascending(name, _ladder_of(rows, "level"), "рівня"))
		"months":
			if rows.size() != 12:
				out.append("months: місяців має бути 12, а не %d" % rows.size())
		"holidays":
			# Схема знає ключі бонусу; усі вони мусять бути з тих, що вміє HolidayService, і навпаки
			var HS = load("res://scripts/game/holiday_service.gd")
			for k in HOLIDAY_BONUS["fields"]:
				if not (k in HS.PLAYER_KEYS or k in HS.COMBAT_KEYS or k in HS.SERVICE_KEYS):
					out.append("holidays: ключ бонусу «%s» у схемі, а HolidayService його не вміє" % k)
			for k in HS.PLAYER_KEYS + HS.COMBAT_KEYS + HS.SERVICE_KEYS:
				if not HOLIDAY_BONUS["fields"].has(k):
					out.append("holidays: HolidayService вміє ключ «%s», а схема бонусу (HOLIDAY_BONUS) його не знає" % k)
	return out


## Записи за числовим полем (як ladder(), але з сирих записів перевірки).
static func _ladder_of(rows: Dictionary, field: String) -> Array:
	var out := []
	for id in rows:
		var i := int(rows[id].get(field, -1))
		if i < 0:
			continue
		while out.size() <= i:
			out.append(_EMPTY)
		out[i] = rows[id]
	return out


## Драбина порогів «from»: перший — з нуля, далі пороги ростуть.
static func _ascending(name: String, lad: Array, what: String) -> Array:
	var out := []
	for i in lad.size():
		if lad[i].is_empty():
			continue
		if (i == 0) != (int(lad[i].get("from", -1)) == 0):
			out.append("%s: з нуля («from» 0) починається лише перший щабель" % name)
		if i > 0 and not lad[i - 1].is_empty() and int(lad[i]["from"]) <= int(lad[i - 1]["from"]):
			out.append("%s: пороги («from») мають рости від %s до %s" % [name, what, what])
	return out


## Чи ids таблиці — рівно ті, що знає код: що зайве і чого бракує.
static func _same_ids(name: String, rows: Dictionary, want: Array, who: String, out: Array) -> void:
	for id in rows:
		if not id in want:
			out.append("%s/%s: такого код не вміє (%s)" % [name, id, who])
	for id in want:
		if not rows.has(id):
			out.append("%s: нема «%s», а код його знає (%s)" % [name, id, who])


## Посилання таблиць цього етапу на інші таблиці й на код гри.
static func _life_links(name: String, rows: Dictionary) -> Array:
	var out := []
	match name:
		"glory_ranks":
			for id in rows:
				if rows[id].has("stone") and not _has_row("stones", rows[id]["stone"]):
					out.append("glory_ranks/%s: «stone» — нема каменя «%s» у stones.json" % [id, rows[id]["stone"]])
		"rivals":
			var Gfx = load("res://scripts/world/gfx.gd")
			var used := {}
			for id in rows:
				var R: Dictionary = rows[id]
				_mechanic_ref("rivals/" + id, "mechanic", str(R.get("mechanic", "")), used, out)
				if not Gfx.has(str(R.get("sprite", ""))):
					out.append("rivals/%s: «sprite» — нема листа спрайтів «%s»" % [id, R.get("sprite", "")])
			out.append_array(_mechanic_orphans(["rival"], used, "rivals.json"))
		"duel_rounds", "muster_rounds", "ring_rounds":
			var src: Array = _ROUND_TABLES[name]
			var want := int(settings(src[0]).get(src[1], 0))
			if rows.size() != want:
				out.append("%s: кіл %d, а налаштування чекають %d (settings.json: %s.%s)" % [name, rows.size(), want, src[0], src[1]])
		"muster_teams":
			var styles := {}
			for r in ids("rivals"):
				styles[str(row("rivals", r).get("style", ""))] = true
			var most := 0
			for r in ids("muster_rounds"):
				most = maxi(most, int(row("muster_rounds", r).get("size", 0)))
			for id in rows:
				for st in rows[id].get("styles", []):
					if not styles.has(st):
						out.append("muster_teams/%s: «styles» — стилю «%s» нема в жодного суперника rivals.json" % [id, st])
				if rows[id].get("styles", []).size() < most:
					out.append("muster_teams/%s: бійців %d, а найбільша сутичка (muster_rounds.json) — %d" % [id, rows[id].get("styles", []).size(), most])
			if not _has_row("cities", load("res://scripts/data/activities.gd").MUSTER_CITY):
				out.append("muster_teams: місто огляду (Activities.MUSTER_CITY) — нема в cities.json")
		"spots":
			var WM = load("res://scripts/ui/world_map.gd")
			for id in rows:
				if not str(rows[id].get("icon", "")) in WM.ICON_ORDER:
					out.append("spots/%s: «icon» — значка «%s» нема (WorldMap.ICON_ORDER)" % [id, rows[id].get("icon", "")])
				if _has_row("cities", id) or _has_row("places", id) or id == load("res://scripts/data/camp_data.gd").CAMP_ID:
					out.append("spots/%s: id збігається з містом, місцем чи хутором" % id)
			for need in [[load("res://scripts/game/ring_service.gd").SPOT_ID, "ring"], [load("res://scripts/game/vigil_service.gd").SPOT_ID, "vigil"], ["hunt", "hunt"], ["fish", "fish"]]:
				if str(rows.get(need[0], _EMPTY).get("kind", "")) != need[1]:
					out.append("spots: нема місця «%s» з «kind» «%s», а код гри його знає" % need)
		"trade_cities":
			var goods: Array = ids("trade_goods")
			for id in rows:
				if not _has_row("cities", id):
					out.append("trade_cities/%s: нема такого міста в cities.json" % id)
				var P: Dictionary = rows[id].get("prices", _EMPTY)
				for g in P:
					if not g in goods:
						out.append("trade_cities/%s: «prices.%s» — нема такого краму в trade_goods.json" % [id, g])
				for g in goods:
					if not P.has(g):
						out.append("trade_cities/%s: нема ціни краму «%s»" % [id, g])
		"trade_goods":
			for c in ids("trade_cities"):
				for g in rows:
					if not row("trade_cities", c).get("prices", _EMPTY).has(g):
						out.append("trade_goods/%s: у місті «%s» (trade_cities.json) нема ціни цього краму" % [g, c])
		"recipes":
			for id in rows:
				for r in rows[id].get("need", _EMPTY):
					if not _has_row("resources", r):
						out.append("recipes/%s: «need.%s» — нема такого ресурсу в resources.json" % [id, r])
		"trail_kinds":
			_same_ids(name, rows, load("res://scripts/game/trail_service.gd").KINDS, "TrailService.KINDS, Combat._trail_found", out)
		"records":
			var keys: Array = load("res://scripts/game/record_service.gd").KEYS
			for id in rows:
				if not id in keys:
					out.append("records/%s: такого рекорду гра не рахує (RecordService.KEYS)" % id)
		"escorts":
			var Gfx = load("res://scripts/world/gfx.gd")
			for id in rows:
				if not Gfx.has(str(rows[id].get("sheet", ""))):
					out.append("escorts/%s: «sheet» — нема листа спрайтів «%s»" % [id, rows[id].get("sheet", "")])
		"token_scales":
			_same_ids(name, rows, ["great", "short", "tiny"], "HolidayService.tiers", out)
		"camps":
			var Camp = load("res://scripts/data/camp_data.gd")
			if not rows.has(Camp.CAMP_ID):
				out.append("camps: нема хутора «%s» (CampData.CAMP_ID)" % Camp.CAMP_ID)
		"resources":
			for id in CODE_RESOURCES:
				if str(rows.get(id, _EMPTY).get("kind", "")) != CODE_RESOURCES[id]:
					out.append("resources: нема ресурсу «%s» виду «%s», а код гри його знає" % [id, CODE_RESOURCES[id]])
		"buildings":
			for id in CODE_BUILDINGS:
				if not rows.has(id):
					out.append("buildings: нема будівлі «%s», а код гри її знає" % id)
			for id in rows:
				var want: String = CODE_BUILDINGS.get(id, "")
				for L in rows[id].get("levels", []):
					for f in ["bag", "rate", "beds"]:
						if L.has(f) and want != f:
							out.append("buildings/%s: «%s» читає лише %s" % [id, f, CODE_BUILDINGS.find_key(f)])
					if want != "" and not L.has(want):
						out.append("buildings/%s: кожен рівень має мати «%s» (його читає код)" % [id, want])
		"crops":
			for id in rows:
				var g := str(rows[id].get("gives", ""))
				if g != "gold" and not _has_row("resources", g):
					out.append("crops/%s: «gives» — «%s» не ресурс із resources.json і не \"gold\"" % [id, g])
		"brews":
			var top: int = row("buildings", "zillia").get("levels", []).size()
			for id in rows:
				if int(rows[id].get("level", 0)) > top:
					out.append("brews/%s: «level» %d — у Зілляварні лише %d рівні" % [id, int(rows[id]["level"]), top])
			for id in ["heal", "mana"]:
				if not rows.has(id):
					out.append("brews: нема зілля «%s», а код гри його знає (CampService.brew)" % id)
		"kleinody":
			var KS = load("res://scripts/game/kleinod_service.gd")
			for id in rows:
				var R: Dictionary = rows[id]
				if not (str(R.get("stat", "")) in KS.HERO_STATS or str(R.get("stat", "")) in KS.SERVICE_STATS):
					out.append("kleinody/%s: «stat» — «%s» клейнод не вміє (KleinodService.HERO_STATS, SERVICE_STATS)" % [id, R.get("stat", "")])
				if str(row("resources", str(R.get("res", ""))).get("kind", "")) != "res":
					out.append("kleinody/%s: «res» — «%s» не будівельний ресурс із resources.json" % [id, R.get("res", "")])
		"stones":
			_same_ids(name, rows, load("res://scripts/game/stone_service.gd").KINDS, "StoneService.KINDS", out)
		"fair_goods":
			var safe: String = load("res://scripts/game/fair_service.gd").SAFE
			for id in rows:
				if id != safe and not _has_row("stones", id):
					out.append("fair_goods/%s: це не камінь зі stones.json і не жетон «%s»" % [id, safe])
		"road_events":
			var CH: Dictionary = load("res://scripts/game/travel_service.gd").CHOICES
			_same_ids(name, rows, CH.keys(), "TravelService.CHOICES", out)
			for id in rows:
				if not _has_row("speakers", rows[id].get("speaker", "")):
					out.append("road_events/%s: «speaker» — нема мовця «%s» у speakers.json" % [id, rows[id].get("speaker", "")])
				if CH.has(id):
					for k in rows[id].get("choices", _EMPTY):
						if not k in CH[id]:
							out.append("road_events/%s: варіанта «%s» prepare() не бере" % [id, k])
					for k in CH[id]:
						if not rows[id].get("choices", _EMPTY).has(k):
							out.append("road_events/%s: нема варіанта «%s», а prepare() його бере" % [id, k])
		"events":
			var WM = load("res://scripts/ui/world_map.gd")
			var battle: Array = load("res://scripts/game/event_service.gd").BATTLE_KINDS
			for id in rows:
				var R: Dictionary = rows[id]
				if not _has_row("event_kinds", R.get("kind", "")):
					out.append("events/%s: «kind» — нема групи «%s» в event_kinds.json" % [id, R.get("kind", "")])
				if not str(R.get("icon", "")) in WM.ICON_ORDER:
					out.append("events/%s: «icon» — значка «%s» нема (WorldMap.ICON_ORDER)" % [id, R.get("icon", "")])
				if R.has("battle") != (id in battle):
					out.append("events/%s: «battle» мають рівно бойові події (EventService.BATTLE_KINDS)" % id)
			for id in battle:
				if not rows.has(id):
					out.append("events: нема бойової події «%s», а код гри її знає (EventService.BATTLE_KINDS)" % id)
		"event_kinds":
			for id in ["weekly", "world"]:
				if not rows.has(id):
					out.append("event_kinds: нема групи «%s», а код гри її знає (EventsBoard)" % id)
		"boss_hunts":
			_same_ids(name, rows, load("res://scripts/game/boss_service.gd").KINDS, "BossService.KINDS", out)
			for id in rows:
				if int(rows[id].get("mods", 0)) > ids("boss_mods").size():
					out.append("boss_hunts/%s: властивостей %d, а в boss_mods.json лише %d" % [id, int(rows[id]["mods"]), ids("boss_mods").size()])
		"boss_pools":
			for id in ["hunt", "ring"]:
				if not rows.has(id):
					out.append("boss_pools: нема переліку «%s», а код гри його знає" % id)
			for id in rows:
				for b in rows[id].get("bosses", []):
					if not mob(b).has("boss"):
						out.append("boss_pools/%s: «%s» — нема боса з таким видом у mobs.json" % [id, b])
		"statuses":
			_same_ids(name, rows, load("res://scripts/game/status.gd").TINT_ORDER, "Status.TINT_ORDER", out)
		"wiki_sections":
			_same_ids(name, rows, load("res://scripts/game/wiki_service.gd").SECTION_IDS, "WikiService.SECTION_IDS", out)
		"wiki_orders":
			for need in [["enemies", "wiki"], ["bosses", "boss"]]:
				if not rows.has(need[0]):
					out.append("wiki_orders: нема переліку «%s»" % need[0])
				var list: Array = rows.get(need[0], _EMPTY).get("ids", [])
				for k in list:
					var M := mob(k)
					if M.is_empty() or (need[1] == "wiki" and not M.has("wiki")) or (need[1] == "boss" and not M.get("boss", _EMPTY).has("wiki")):
						out.append("wiki_orders/%s: «%s» — нема в mobs.json або в нього нема опису для довідника" % [need[0], k])
				for k in mob_ids():
					var has_wiki: bool = mob(k).has("wiki") if need[1] == "wiki" else mob(k).get("boss", _EMPTY).has("wiki")
					if has_wiki and not k in list:
						out.append("wiki_orders/%s: опис «%s» є, а в переліку його нема, тож його не видно" % [need[0], k])
		"sounds":
			_same_ids(name, rows, load("res://scripts/data/sound_index.gd").SFX.keys(), "SoundIndex.SFX", out)
		"ambients":
			_same_ids(name, rows, load("res://scripts/data/sound_index.gd").AMBIENT, "SoundIndex.AMBIENT", out)
		"name_pools":
			for id in load("res://scripts/data/names_data.gd").POOLS + ["muster_first"]:
				if not rows.has(id):
					out.append("name_pools: нема переліку «%s», а код гри його знає" % id)
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


# ---------- Налаштування балансу ----------

## Запис налаштувань балансу (data/settings.json): числа-правила одного розділу гри («enemies», «loot»…;
## поля й межі — SettingsSchema). Лише для читання; для невідомого запису — порожній. Модулі тримають робочі
## копії цих чисел у static var (їх заповнює apply_settings() модуля), тож бій читає змінну, а не словник.
static func settings(domain: String) -> Dictionary:
	return row("settings", domain)


## Ставить нові налаштування замість теперішніх (усі записи разом, як у файлі) і роздає їх модулям: так число
## гри можна змінити без нової збірки (згодом — із сервера). Спершу перевіряє (типи, межі, зв'язки з таблицями);
## якщо щось не так, нічого не змінює й повертає перелік проблем. check = false — лише типи й повнота (для тестів).
static func put_settings(raw: Dictionary, check: bool = true) -> Array:
	var res := _normalize_rows("settings", raw)
	var probs: Array = validate("settings", raw) if check else res[1]
	if not probs.is_empty():
		return probs
	var rows: Dictionary = res[0]
	_freeze(rows)
	var keys := rows.keys()
	keys.make_read_only()
	_tables["settings"] = rows
	_ids["settings"] = keys
	apply_settings()
	return []


## Роздає налаштування всім модулям, що тримають їхні робочі копії (SettingsSchema.MODULES; у кожного apply_settings()).
static func apply_settings() -> void:
	var done := {}
	for d in SettingsSchema.MODULES:
		for m in SettingsSchema.MODULES[d]:
			if not done.has(m[0]):
				done[m[0]] = true
				load(m[0]).apply_settings()


## Роди ворога, за якими падає душа (Souls.CHANCE; так їх називає SoulService).
const SOUL_KINDS := ["regular", "elite", "named", "boss"]


## Межі чисел налаштувань («check» у SettingsSchema) і зв'язки між ними.
static func _settings_rules(rows: Dictionary) -> Array:
	var out := []
	var cap := int(rows.get("experience", _EMPTY).get("base_level_max", 0))
	for id in rows:
		_settings_checks(rows[id], SettingsSchema.SCHEMAS.get(id, _EMPTY), "settings/" + id, cap, out)
	var pairs := [  # [запис, менше чи рівне, більше чи рівне]
		["quests", "daily_events", "daily_count"], ["quests", "weekly_events", "weekly_count"],
		["sharpening", "sharpen_risk_from", "max_upgrade"], ["hero_combat", "charge_min", "charge_full"],
		["ads", "xp2_seconds", "xp2_max"], ["ads", "drop2_seconds", "drop2_max"], ["far", "event_from", "event_full"],
		["tower", "mini_affixes", "mini_affixes_top"], ["depths", "rooms_base", "rooms_max"], ["tower", "waves_base", "waves_max"],
	]
	for P in pairs:
		var R: Dictionary = rows.get(P[0], _EMPTY)
		if R.has(P[1]) and R.has(P[2]) and float(R[P[1]]) > float(R[P[2]]):
			out.append("settings/%s: «%s» (%s) більше за «%s» (%s)" % [P[0], P[1], R[P[1]], P[2], R[P[2]]])
	return out


static func _settings_checks(R: Dictionary, schema: Dictionary, where: String, cap: int, out: Array) -> void:
	for k in schema:
		if not R.has(k) or k == "num":
			continue
		var f: Dictionary = schema[k]
		var v = R[k]
		var at := "%s.%s" % [where, k]
		if f["type"] == "record":
			_settings_checks(v, f["fields"], at, cap, out)
			continue
		match str(f.get("check", "")):
			"chance":
				if float(v) < 0.0 or float(v) > 1.0:
					out.append("%s: шанс чи частка — від 0 до 1, а не %s" % [at, v])
			"pos":
				if float(v) <= 0.0:
					out.append("%s: має бути більшим за нуль, а не %s" % [at, v])
			"nonneg":
				if float(v) < 0.0:
					out.append("%s: має бути не від'ємним, а не %s" % [at, v])
			"count":
				if int(v) < 1:
					out.append("%s: має бути не менше 1, а не %s" % [at, v])
			"level":
				if int(v) < 0 or int(v) > cap:
					out.append("%s: рівень від 0 до стелі рівня героя (experience.base_level_max = %d), а не %s" % [at, cap, v])
			"mults":
				if v.is_empty():
					out.append("%s: перелік порожній" % at)
				for x in v:
					if float(x) <= 0.0:
						out.append("%s: множник має бути більшим за нуль, а не %s" % [at, x])
			"zone":
				if v.size() != 2 or float(v[0]) < 0.0 or float(v[0]) >= float(v[1]) or float(v[1]) > 1.0:
					out.append("%s: має бути [від, до], 0 ≤ від < до ≤ 1, а не %s" % [at, v])
			"curve":
				if v.is_empty():
					out.append("%s: мірка без точок" % at)
				var prev := 0
				for i in v.size():
					var P: Dictionary = v[i]
					if not P.has("level") or not P.has("ttk") or not P.has("hit"):
						continue  # про брак поля вже сказала схема
					if int(P["level"]) <= prev:
						out.append("%s[%d]: рівні точок мають рости, від 1" % [at, i])
					prev = int(P["level"])
					if float(P["ttk"]) <= 0.0 or float(P["hit"]) <= 0.0 or float(P["hit"]) >= 1.0:
						out.append("%s[%d]: ttk має бути більшим за нуль, hit — між 0 і 1" % [at, i])
			"soul_chance":
				if v.keys() != SOUL_KINDS:
					out.append("%s: роди мають бути саме %s, по порядку, а не %s" % [at, str(SOUL_KINDS), str(v.keys())])
				for x in v.values():
					if float(x) < 0.0 or float(x) > 1.0:
						out.append("%s: шанс — від 0 до 1, а не %s" % [at, x])


## Зв'язки налаштувань з таблицями: номери рідкостей і ступенів, скільки кіл і викликів є в таблицях,
## скільки місць у строю загону.
static func _settings_links(rows: Dictionary) -> Array:
	var out := []
	var counts := {"rarity": ladder("rarities", "rank").size() - 1, "tier": ladder("golden_tiers", "tier").size() - 1,
		"soul_tier": ladder("soul_tiers", "tier").size() - 1}
	var what := {"rarity": "номер рідкості rarities.json", "tier": "ступінь golden_tiers.json", "soul_tier": "ступінь soul_tiers.json"}
	for id in rows:
		var schema: Dictionary = SettingsSchema.SCHEMAS.get(id, _EMPTY)
		for k in schema:
			var c := str(schema[k].get("check", ""))
			if counts.has(c) and rows[id].has(k):
				var lo := 0 if c == "rarity" else 1
				if int(rows[id][k]) < lo or int(rows[id][k]) > int(counts[c]):
					out.append("settings/%s.%s: %s від %d до %d, а не %s" % [id, k, what[c], lo, counts[c], rows[id][k]])
	for P in [["duel", "rounds", "duel_rounds"], ["muster", "rounds", "muster_rounds"], ["ring", "ring_stages", "ring_rounds"]]:
		var R: Dictionary = rows.get(P[0], _EMPTY)
		if R.has(P[1]) and int(R[P[1]]) != ids(P[2]).size():
			out.append("settings/%s.%s: %d, а в %s.json кіл %d" % [P[0], P[1], int(R[P[1]]), P[2], ids(P[2]).size()])
	var Q: Dictionary = rows.get("quests", _EMPTY)
	for kind in ["daily", "weekly"]:
		var groups := {"base": 0, "event": 0}
		for t in ids(kind):
			groups[str(row(kind, t).get("group", "base"))] += 1
		var n := int(Q.get(kind + "_count", 0))
		var ev := int(Q.get(kind + "_events", 0))
		if ev > int(groups["event"]):
			out.append("settings/quests.%s_events: %d, а шаблонів групи event у %s.json лише %d" % [kind, ev, kind, groups["event"]])
		if n - ev > int(groups["base"]):
			out.append("settings/quests.%s_count: решта %d, а шаблонів групи base у %s.json лише %d" % [kind, n - ev, kind, groups["base"]])
	# Курінь додає до двох місць у загоні (CampService.max_companions), а стрій має місця для всіх (Companion.OFFSETS)
	var spots: int = load("res://scripts/entities/companion.gd").OFFSETS.size()
	var most := int(rows.get("party", _EMPTY).get("max_companions", 0)) + 2
	if most > spots:
		out.append("settings/party.max_companions: з Куренем супутників буде %d, а в строю загону місць %d (Companion.OFFSETS)" % [most, spots])
	return out
