extends RefCounted
## Унікальні (золоті) речі: іменні, зі сталими властивостями й однією силою.
## Падають лише з босів у їхніх лігвах і з супербосів Башти (див. LootService).
## Що лютіший бос, то вищий ступінь речі; у Глибинах і Башті ступінь росте далі.

const Data := preload("res://scripts/data/data.gd")

const RARITY := 4
## Ступені: що вищий, то сильніша головна властивість і рідкісніша річ.
const TIER_NAMES := ["", "Сотницька", "Полковницька", "Кошова", "Гетьманська", "Характерницька", "Заповітна"]
const PRIMARY_MULT := [1.0, 1.0, 1.04, 1.08, 1.12, 1.18, 1.24]
## Шанс золотої речі з боса за його ступенем (малий; росте з лічильником Долі).
const BASE_CHANCE := [0.0, 0.010, 0.014, 0.018, 0.024, 0.032, 0.05]
const TOP_COMMON_TIER := 5  # найвищий ступінь поза надважкими печерами: шостий дають лише їхні боси
const LUCK_STEP := 20.0  # кожні 20 босів без золота подвоюють шанс
const LUCK_SURE := 99  # сотий бос поспіль без золота дає річ напевно
const LEVEL_GAP := 8  # бос має бути не нижчий за героя більш як на стільки рівнів
## Власний ступінь боса. Нового боса без запису оцінюють за рівнем його лігва (див. LootService.boss_tier).
const BOSS_TIER := {"zmii": 1, "upyr": 1, "vovkulaka": 1, "chaklun": 2, "vidma": 2, "baba_yaha": 2, "solovei": 2,
	"koshchii": 3, "bila_pani": 3, "pushkar": 3, "vii": 4, "shubin": 4, "lykho": 4, "morskyi_tsar": 4, "putinoid": 4,
	"oprychnyk": 4, "lisovyi_did": 4, "idolyshche": 4, "karachun": 5, "drakula": 5,
	"dev": 6, "khala": 6, "velnias": 6, "zolota_baba": 6, "chornoboh": 6}

## Середина кидка властивості легендарної речі: [стала, приріст за рівень] (див. Data._roll_value).
const MID := {"dmg_pct": [4.5, 0.4], "crit": [2.5, 0.15], "aspd": [4.5, 0.3], "hp": [12.0, 3.0], "armor": [2.25, 0.2],
	"speed": [3.0, 0.2], "xp": [6.0, 0.4], "skill_power": [5.5, 0.4], "skill_cd": [3.0, 0.2], "pickup": [15.0, 0.0], "gold": [11.5, 1.0]}

## Сили золотих речей. У тексті {назва} підставляється з params речі (частки показуються відсотками).
const POWERS := {
	"hrim": {"name": "Громовий удар", "text": "Завершальний удар серії й повний заряджений удар гримлять на всі боки: {pct}% шкоди всім довкола, нечисть ціпеніє на {stun} с."},
	"zvytiaha": {"name": "Звитяга", "text": "Кожен убитий ворог додає {dmg}% шкоди на {dur} с, до {max} разів."},
	"pokrova": {"name": "Покрова", "text": "Коли здоров'я падає нижче {threshold}%, на {dur} с шкода по тобі менша на {ward}%. Не частіше ніж раз на {cd} с."},
	"vypad": {"name": "Пластунський випад", "text": "{window} с після перекиду кожен твій удар критичний і на {bonus}% сильніший."},
	"vidlunnia": {"name": "Відлуння", "text": "Кожне вміння з шансом {chance}% перезаряджається вдвічі швидше."},
	"perun": {"name": "Перунова блискавка", "text": "Критичний удар із шансом {chance}% б'є блискавкою ще {jumps} ворогів: по {pct}% шкоди."},
	"yadro": {"name": "Вогняне ядро", "text": "Кожні {period} с на найближчого ворога падає ядро й б'є всіх поруч так, як ти за {sec} с бою. Ще й підпалює."},
}
const PCT_KEYS := ["pct", "dmg", "threshold", "ward", "bonus", "chance"]

const DEFS := {
	"kotyhoroshko": {"name": "Булава Котигорошка", "slot": "weapon", "type": "mace", "tier": 1, "bosses": ["zmii"],
		"affixes": {"str": 1.0, "dmg_pct": 1.0, "hp": 1.0}, "power": "hrim", "params": {"radius": 200, "pct": 0.8, "stun": 0.3},
		"lore": "Дванадцять пудів заліза. Котигорошко підкинув її під хмари, а вона впала Змієві просто на голови."},
	"osykovyi_spys": {"name": "Осиковий спис", "slot": "weapon", "type": "pike", "tier": 1, "bosses": ["upyr"],
		"affixes": {"agi": 1.0, "aspd": 1.0, "crit": 0.8}, "power": "zvytiaha", "params": {"dmg": 0.02, "max": 6, "dur": 6},
		"lore": "Осику зрубали на Купала й загартували на свяченому вогні. Упирі чують її за версту."},
	"kozhukh_kozhumiaky": {"name": "Кожух Кожум'яки", "slot": "body", "type": "", "tier": 1, "bosses": ["zmii"],
		"affixes": {"vit": 1.0, "hp": 1.0, "dmg_pct": 0.8}, "power": "pokrova", "params": {"threshold": 0.5, "ward": 0.2, "dur": 6, "cd": 25},
		"lore": "Кирило обмотався коноплями, обмазався смолою і так пішов на Змія. Смола досі тримає удар."},
	"vovcha_kuchma": {"name": "Вовча кучма", "slot": "head", "type": "", "tier": 1, "bosses": ["vovkulaka"],
		"affixes": {"agi": 1.0, "crit": 1.0, "speed": 0.8}, "power": "vypad", "params": {"window": 1.5, "bonus": 0.15},
		"lore": "Пошита зі шкури вовкулаки-ватажка. Хто її носить, той стрибає раніше, ніж ворог замахнеться."},
	"lishchynova_palytsia": {"name": "Ліщинова палиця", "slot": "weapon", "type": "staff", "tier": 1, "bosses": ["upyr", "vovkulaka"],
		"affixes": {"spi": 1.0, "skill_power": 1.0, "skill_cd": 0.9}, "power": "vidlunnia", "params": {"chance": 0.15},
		"lore": "Ліщину зрізали в купальську ніч, коли цвіте папороть. Замовляння з неї відлунюють двічі."},
	"poias_baidy": {"name": "Пояс Байди", "slot": "belt", "type": "", "tier": 2, "bosses": ["solovei"],
		"affixes": {"str": 1.1, "crit": 1.1, "dmg_pct": 1.0}, "power": "perun", "params": {"chance": 0.25, "jumps": 3, "pct": 0.5, "icd": 0.5},
		"lore": "Байда висів на гаку, а таки влучив тричі: у царя, у царицю й у їхню доньку. Пояс пам'ятає ті три стріли."},
	"choboty_skorokhody": {"name": "Чоботи-скороходи", "slot": "boots", "type": "", "tier": 2, "bosses": ["baba_yaha"],
		"affixes": {"agi": 1.1, "aspd": 1.0, "armor": 0.9}, "power": "vypad", "params": {"window": 1.5, "bonus": 0.2},
		"lore": "Один крок — верста, другий — дві. Баба Яга ховала їх під піччю, та не вберегла."},
	"samopal_morozenka": {"name": "Самопал Морозенка", "slot": "weapon", "type": "pishchal", "tier": 2, "bosses": ["chaklun"],
		"affixes": {"agi": 1.1, "crit": 1.0, "aspd": 1.1}, "power": "zvytiaha", "params": {"dmg": 0.025, "max": 8, "dur": 6},
		"lore": "«Ой Морозе, Морозенку...» Кажуть, він стріляв не перезаряджаючи, аж поки біля ніг не виростала гора нечисті."},
	"namysto_lysoi_hory": {"name": "Намисто з Лисої гори", "slot": "amulet", "type": "", "tier": 2, "bosses": ["vidma"],
		"affixes": {"spi": 1.1, "skill_cd": 1.0, "hp": 1.0}, "power": "vidlunnia", "params": {"chance": 0.18},
		"lore": "Дванадцять намистин — дванадцять відьом із шабашу. Кожна шепче замовляння слідом за тобою."},
	"posokh_chornoknyzhnyka": {"name": "Посох Чорнокнижника", "slot": "weapon", "type": "staff", "tier": 2, "bosses": ["chaklun", "vidma"],
		"affixes": {"spi": 1.1, "dmg_pct": 1.0, "crit": 1.0}, "power": "yadro", "params": {"period": 6, "sec": 0.5, "r": 130},
		"lore": "Чаклун Путіноїда труїв ним криниці. Волхви очистили посох, і тепер він кидає вогонь на тих, хто його кував."},
	"pernach_sahaidachnoho": {"name": "Пернач Сагайдачного", "slot": "weapon", "type": "mace", "tier": 3, "bosses": ["oprychnyk", "koshchii", "pushkar"],
		"affixes": {"str": 1.0, "dmg_pct": 1.0, "armor": 0.9, "hp": 0.9}, "power": "hrim", "params": {"radius": 250, "pct": 1.1, "stun": 0.5},
		"lore": "Під Хотином Сагайдачний підняв пернач, і полки рушили, як одна хвиля."},
	"koshchieva_holka": {"name": "Кощієва голка", "slot": "amulet", "type": "", "tier": 3, "bosses": ["koshchii"],
		"affixes": {"vit": 1.0, "hp": 1.1, "armor": 1.0, "skill_cd": 0.8}, "power": "pokrova", "params": {"threshold": 0.5, "ward": 0.25, "dur": 6, "cd": 22},
		"lore": "Кажуть, Кощієва смерть ховалася на кінці голки. Ця голка з того самого заліза, і смерть обходить її власника стороною."},
	"kolchuha_bohuna": {"name": "Кольчуга Богуна", "slot": "body", "type": "", "tier": 3, "bosses": ["oprychnyk"],
		"affixes": {"vit": 1.0, "hp": 1.0, "dmg_pct": 0.9, "crit": 0.8}, "power": "zvytiaha", "params": {"dmg": 0.03, "max": 8, "dur": 6},
		"lore": "Іван Богун вивів військо з облоги по гаті з возів і сідел. Кольчуга важка, та в бою легшає з кожним ворогом."},
	"shapka_nalyvaika": {"name": "Шапка Наливайка", "slot": "head", "type": "", "tier": 3, "bosses": ["koshchii", "bila_pani", "pushkar"],
		"affixes": {"str": 1.0, "crit": 1.0, "dmg_pct": 1.0, "armor": 0.8}, "power": "yadro", "params": {"period": 6, "sec": 0.6, "r": 140},
		"lore": "Северин Наливайко сам лив гармати й сам із них бив. Його шапка досі пахне порохом."},
	"posokh_velesa": {"name": "Посох Велеса", "slot": "weapon", "type": "staff", "tier": 3, "bosses": ["bila_pani"],
		"affixes": {"spi": 1.0, "skill_power": 1.0, "skill_cd": 0.9, "crit": 0.9}, "power": "vidlunnia", "params": {"chance": 0.2},
		"lore": "Велес пасе душі на тому боці. Хто тримає його посох, тому відгукуються предки: слово лунає двічі."},
	"shablia_sirka": {"name": "Шабля Сірка", "slot": "weapon", "type": "sabre", "tier": 4, "bosses": ["putinoid", "lykho"],
		"affixes": {"str": 1.1, "crit": 1.0, "aspd": 1.0, "dmg_pct": 0.8}, "power": "zvytiaha", "params": {"dmg": 0.03, "max": 10, "dur": 6},
		"lore": "Іван Сірко вийшов переможцем із шістдесяти битв. Кажуть, його шабля після кожного ворога просить ще."},
	"osten_morskoho_tsaria": {"name": "Остень Морського царя", "slot": "weapon", "type": "pike", "tier": 4, "bosses": ["morskyi_tsar"],
		"affixes": {"str": 1.0, "agi": 1.0, "dmg_pct": 1.1, "hp": 1.0}, "power": "hrim", "params": {"radius": 290, "pct": 1.3, "stun": 0.6},
		"lore": "Морський цар здіймав ним бурі над Зміїним. Удар остня й на суші котиться хвилею."},
	"cheres_shubina": {"name": "Черес Шубіна", "slot": "belt", "type": "", "tier": 4, "bosses": ["shubin", "idolyshche"],
		"affixes": {"str": 1.0, "hp": 1.1, "armor": 1.0, "gold": 1.0}, "power": "yadro", "params": {"period": 5, "sec": 0.75, "r": 150},
		"lore": "Широкий шахтарський черес із кишенями для пороху. Шубін підривав штреки над головами непроханих гостей."},
	"pyshchal_kryvonosa": {"name": "Пищаль Кривоноса", "slot": "weapon", "type": "pishchal", "tier": 4, "bosses": ["lykho", "idolyshche"],
		"affixes": {"agi": 1.1, "crit": 1.1, "dmg_pct": 1.0, "speed": 0.8}, "power": "perun", "params": {"chance": 0.3, "jumps": 4, "pct": 0.6, "icd": 0.5},
		"lore": "Максим Кривоніс бив із неї так, що куля летіла з іскрами. Лихо досі мружить єдине око, коли чує її постріл."},
	"shapka_nevydymka": {"name": "Шапка-невидимка", "slot": "head", "type": "", "tier": 4, "bosses": ["vii", "shubin", "lisovyi_did"],
		"affixes": {"agi": 1.1, "crit": 1.0, "aspd": 1.0, "speed": 0.8}, "power": "vypad", "params": {"window": 2.0, "bonus": 0.3},
		"lore": "Хома сховався від Вія в крейдяному колі, та Вій його побачив. У цій шапці не побачить."},
	"posokh_molfara": {"name": "Посох мольфара", "slot": "weapon", "type": "staff", "tier": 4, "bosses": ["vii", "morskyi_tsar", "lisovyi_did"],
		"affixes": {"spi": 1.1, "skill_power": 1.0, "crit": 1.0, "vit": 0.9}, "power": "vidlunnia", "params": {"chance": 0.24},
		"lore": "Вирізаний із громовиці: смереки, в яку вдарила блискавка. Кожне замовляння з ним звучить двічі."},
	"bulava_mazepy": {"name": "Булава Мазепи", "slot": "weapon", "type": "mace", "tier": 5, "bosses": ["putinoid", "karachun"],
		"affixes": {"str": 1.0, "vit": 1.0, "dmg_pct": 1.0, "hp": 1.0, "crit": 0.9}, "power": "hrim", "params": {"radius": 330, "pct": 1.6, "stun": 0.8},
		"lore": "Гетьманська булава з бірюзою й перлами. Під Полтавою вона не схилилась і досі б'є так, що земля гуде."},
	"shablia_bohdana": {"name": "Шабля Богдана", "slot": "weapon", "type": "sabre", "tier": 5, "bosses": ["oprychnyk"],
		"affixes": {"str": 1.0, "agi": 1.0, "crit": 1.0, "dmg_pct": 1.0, "aspd": 0.9}, "power": "perun", "params": {"chance": 0.35, "jumps": 5, "pct": 0.7, "icd": 0.4},
		"lore": "З нею Хмельницький пішов із Січі, а повернувся з цілою Україною. Блискає так, що грім іде слідом."},
	"zhupan_polubotka": {"name": "Жупан Полуботка", "slot": "body", "type": "", "tier": 5, "bosses": ["koshchii", "karachun"],
		"affixes": {"vit": 1.0, "hp": 1.1, "skill_cd": 0.8, "dmg_pct": 0.7, "crit": 0.8}, "power": "pokrova", "params": {"threshold": 0.5, "ward": 0.3, "dur": 6, "cd": 20},
		"lore": "Павло Полуботок не схилився перед царем навіть у казематі. Цього жупана не порвати ні катові, ні смерті."},
	"ladanka_mamaia": {"name": "Ладанка Мамая", "slot": "amulet", "type": "", "tier": 5, "bosses": ["lykho", "karachun"],
		"affixes": {"spi": 1.0, "str": 1.0, "hp": 1.0, "xp": 1.0, "skill_cd": 0.9}, "power": "vidlunnia", "params": {"chance": 0.28},
		"lore": "Козак Мамай сидить під дубом і грає на кобзі, а кінь його пасеться поруч. Його ладанка береже характерницьку силу: вміння вертаються швидше."},
	"posokh_dazhboha": {"name": "Посох Дажбога", "slot": "weapon", "type": "staff", "tier": 5, "bosses": ["chaklun", "karachun"],
		"affixes": {"spi": 1.0, "skill_power": 1.0, "crit": 1.0, "dmg_pct": 1.0, "skill_cd": 0.9}, "power": "yadro", "params": {"period": 4, "sec": 1.0, "r": 170},
		"lore": "Дажбог щоранку котить сонце небом. Його посох скидає жмені того сонця на нечисть, що ховається в пітьмі."},
	"luk_popovycha": {"name": "Лук Олешка Поповича", "slot": "weapon", "type": "bow", "tier": 1, "bosses": ["zmii", "vovkulaka"],
		"affixes": {"agi": 1.0, "crit": 1.0, "aspd": 0.9}, "power": "vypad", "params": {"window": 1.5, "bonus": 0.15},
		"lore": "Олешко Попович не мірявся зі Змієм силою. Він відскочив і пустив стрілу, поки той розвертався."},
	"pistoli_karmeliuka": {"name": "Пістолі Кармелюка", "slot": "weapon", "type": "pistols", "tier": 2, "bosses": ["solovei", "chaklun"],
		"affixes": {"agi": 1.1, "aspd": 1.0, "crit": 1.0}, "power": "zvytiaha", "params": {"dmg": 0.025, "max": 8, "dur": 6},
		"lore": "Устим Кармелюк тікав із каторги чотири рази, і щоразу пани знову чули два постріли під вікном."},
	"luk_sahaidachnoho": {"name": "Сагайдак гетьмана", "slot": "weapon", "type": "bow", "tier": 3, "bosses": ["koshchii", "bila_pani"],
		"affixes": {"agi": 1.0, "dmg_pct": 1.0, "crit": 1.0, "speed": 0.8}, "power": "perun", "params": {"chance": 0.28, "jumps": 3, "pct": 0.55, "icd": 0.5},
		"lore": "Петра Конашевича прозвали Сагайдачним за лук, з яким він не розлучався. Його стріли знали дорогу й через море."},
	"pistoli_paliia": {"name": "Пістолі Палія", "slot": "weapon", "type": "pistols", "tier": 4, "bosses": ["lykho", "shubin"],
		"affixes": {"agi": 1.1, "crit": 1.0, "dmg_pct": 1.0, "hp": 0.9}, "power": "hrim", "params": {"radius": 260, "pct": 1.2, "stun": 0.5},
		"lore": "Семен Палій тримав Фастів проти трьох держав. Два його пістолі гриміли так, що здавалося, ніби б'є гармата."},
	"luk_baidy": {"name": "Лук Байди", "slot": "weapon", "type": "bow", "tier": 5, "bosses": ["karachun", "putinoid"],
		"affixes": {"agi": 1.0, "crit": 1.0, "dmg_pct": 1.0, "aspd": 1.0, "hp": 0.9}, "power": "yadro", "params": {"period": 4, "sec": 1.0, "r": 170},
		"lore": "Байда висів на гаку й попросив лук. Три стріли, і цар, цариця та їхня донька вже не сміялися."},
	"para_zalizniaka": {"name": "Пара Залізняка", "slot": "weapon", "type": "pistols", "tier": 6, "bosses": ["velnias", "zolota_baba"],
		"affixes": {"agi": 1.1, "crit": 1.1, "dmg_pct": 1.1, "aspd": 1.0, "hp": 1.0}, "power": "zvytiaha", "params": {"dmg": 0.035, "max": 10, "dur": 7},
		"lore": "Максим Залізняк освятив ножі під Холодним Яром, а пістолі лишив несвяченими: казав, що вони й так знають, у кого цілити."},
	"mech_kladenets": {"name": "Меч-кладенець", "slot": "weapon", "type": "sabre", "tier": 6, "bosses": ["dev", "chornoboh"],
		"affixes": {"str": 1.1, "agi": 1.0, "crit": 1.1, "dmg_pct": 1.1, "aspd": 1.0}, "power": "perun", "params": {"chance": 0.4, "jumps": 6, "pct": 0.8, "icd": 0.4},
		"lore": "Лежав під каменем, доки не прийшов той, кому він до руки. Сам рубає, щойно витягнеш із піхов."},
	"palytsia_vernyhory": {"name": "Палиця Вернигори", "slot": "weapon", "type": "mace", "tier": 6, "bosses": ["dev", "zolota_baba"],
		"affixes": {"str": 1.1, "vit": 1.1, "dmg_pct": 1.1, "hp": 1.1, "crit": 1.0}, "power": "hrim", "params": {"radius": 360, "pct": 1.9, "stun": 0.9},
		"lore": "Вернигора зсував нею гори з дороги. Де вдарить, там яр."},
	"spys_zmiiebortsia": {"name": "Спис змієборця", "slot": "weapon", "type": "pike", "tier": 6, "bosses": ["khala"],
		"affixes": {"str": 1.0, "agi": 1.1, "dmg_pct": 1.1, "crit": 1.1, "aspd": 1.0}, "power": "zvytiaha", "params": {"dmg": 0.035, "max": 10, "dur": 7},
		"lore": "Таким списом на старих іконах колють змія. Хала його впізнала."},
	"kris_dovbusha": {"name": "Кріс Довбуша", "slot": "weapon", "type": "pishchal", "tier": 6, "bosses": ["velnias"],
		"affixes": {"agi": 1.1, "crit": 1.1, "dmg_pct": 1.1, "aspd": 1.0, "speed": 0.9}, "power": "vypad", "params": {"window": 2.2, "bonus": 0.38},
		"lore": "Олексу Довбуша не брала жодна куля, крім срібної. Його власний кріс б'є без промаху і пана, і чорта."},
	"posokh_svaroha": {"name": "Посох Сварога", "slot": "weapon", "type": "staff", "tier": 6, "bosses": ["khala", "chornoboh"],
		"affixes": {"spi": 1.1, "skill_power": 1.1, "crit": 1.0, "dmg_pct": 1.0, "skill_cd": 1.0}, "power": "yadro", "params": {"period": 4, "sec": 1.25, "r": 185},
		"lore": "Сварог викував сонце й навчив людей кувати залізо. З його посоха на нечисть сиплеться небесна кузня."},
	"bronia_sviatoslava": {"name": "Броня Святослава", "slot": "body", "type": "", "tier": 6, "bosses": ["velnias", "chornoboh"],
		"affixes": {"vit": 1.1, "hp": 1.2, "dmg_pct": 0.9, "crit": 0.9, "skill_cd": 0.8}, "power": "pokrova", "params": {"threshold": 0.5, "ward": 0.35, "dur": 6, "cd": 18},
		"lore": "«Іду на ви». Князь Святослав не возив за собою ні возів, ні казанів, а броні не знімав і вві сні."},
	"oberih_berehyni": {"name": "Оберіг Берегині", "slot": "amulet", "type": "", "tier": 6, "bosses": ["zolota_baba"],
		"affixes": {"spi": 1.1, "vit": 1.0, "hp": 1.1, "skill_cd": 1.0, "xp": 1.0}, "power": "vidlunnia", "params": {"chance": 0.32},
		"lore": "Берегиня стереже рід від початку світу. З її оберегом кожне слово лунає двічі."},
	"sholom_oleha": {"name": "Шолом Віщого Олега", "slot": "head", "type": "", "tier": 6, "bosses": ["dev", "velnias"],
		"affixes": {"vit": 1.0, "crit": 1.1, "dmg_pct": 1.1, "armor": 1.0, "skill_power": 1.0}, "power": "vypad", "params": {"window": 2.2, "bonus": 0.38},
		"lore": "Олег прибив щит на брамі Царгорода, а шолом лишив удома. Хто його вдягне, той б'є першим."},
}

const ORDER := ["kotyhoroshko", "osykovyi_spys", "kozhukh_kozhumiaky", "vovcha_kuchma", "lishchynova_palytsia", "poias_baidy", "choboty_skorokhody", "samopal_morozenka", "namysto_lysoi_hory", "posokh_chornoknyzhnyka", "pernach_sahaidachnoho", "koshchieva_holka", "kolchuha_bohuna", "shapka_nalyvaika", "posokh_velesa", "shablia_sirka", "osten_morskoho_tsaria", "cheres_shubina", "pyshchal_kryvonosa", "shapka_nevydymka", "posokh_molfara", "bulava_mazepy", "shablia_bohdana", "zhupan_polubotka", "ladanka_mamaia", "posokh_dazhboha",
	"luk_popovycha", "pistoli_karmeliuka", "luk_sahaidachnoho", "pistoli_paliia", "luk_baidy", "para_zalizniaka",
	"mech_kladenets", "palytsia_vernyhory", "spys_zmiiebortsia", "kris_dovbusha", "posokh_svaroha", "bronia_sviatoslava", "oberih_berehyni", "sholom_oleha"]


static func is_unique(item: Dictionary) -> bool:
	return item.has("unique") and DEFS.has(str(item["unique"]))


## Значення властивості: стале, без випадковості. Цілі характеристики рівні найкращому кидку легендарної,
## решта — середина кидка з якістю золотої речі (1,6 проти 1,45 у легендарної).
static func value(stat: String, ilvl: int, m: float) -> float:
	if stat in Data.INT_STATS:
		return floorf(m * (2 + ilvl / 3))
	var mid: Array = MID[stat]
	return 1.6 * (float(mid[0]) + float(mid[1]) * ilvl) * m


## Створює золоту річ за її id для вказаного рівня.
static func make(id: String, ilvl: int) -> Dictionary:
	var D: Dictionary = DEFS[id]
	var slot: String = D["slot"]
	var primary: String = Data.SLOT_PRIMARY[slot]
	var base: float = Data._primary_value(slot, ilvl, RARITY)
	if not primary in Data.INT_STATS:
		base *= float(PRIMARY_MULT[int(D["tier"])])
	var affixes := {}
	for a in D["affixes"]:
		affixes[a] = value(a, ilvl, float(D["affixes"][a]))
	return {"slot": slot, "type": D["type"], "name": D["name"], "rarity": RARITY, "ilvl": ilvl, "up": 0, "spent": 0,
		"unique": id, "base": {primary: base}, "affixes": affixes}


## Перерахувати річ на новий рівень (оновлення в кузні): ті самі властивості, сила нового рівня.
static func rescale(item: Dictionary, ilvl: int) -> void:
	var fresh := make(str(item["unique"]), ilvl)
	item["ilvl"] = ilvl
	item["base"] = fresh["base"]
	item["affixes"] = fresh["affixes"]


static func tier(item: Dictionary) -> int:
	return int(DEFS[str(item["unique"])]["tier"]) if is_unique(item) else 0


static func power_id(item: Dictionary) -> String:
	return str(DEFS[str(item["unique"])]["power"]) if is_unique(item) else ""


static func power_name(id: String) -> String:
	return str(POWERS[str(DEFS[id]["power"])]["name"])


## Опис сили з числами цієї речі.
static func power_text(id: String) -> String:
	var D: Dictionary = DEFS[id]
	var vals := {}
	for k in D["params"]:
		var v: float = float(D["params"][k])
		if k in PCT_KEYS:
			vals[k] = str(roundi(v * 100.0))
		else:
			vals[k] = str(int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
	return str(POWERS[str(D["power"])]["text"]).format(vals)


## Назви босів, що найчастіше носять цю річ.
static func boss_names(id: String) -> String:
	var out := []
	for b in DEFS[id]["bosses"]:
		out.append(str(Data.BOSS_NAMES.get(b, b)))
	return ", ".join(out)
