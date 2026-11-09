extends RefCounted
## Шаблони щоденних і тижневих викликів та постійні досягнення.
## stat — лічильник із world.stats (kill, kill:<вид>, elite, boss, boss:<вид>, field, dungeon, parry,
## charged, defense, travel, sharpen, bond, level — найвищий рівень, hetman).

const DAILY := [
	{"stat": "kill", "goal": [30, 60], "text": "Здолай %d ворогів"},
	{"stat": "kill:zarazhenyi", "goal": [10, 25], "text": "Здолай %d заражених"},
	{"stat": "elite", "goal": [2, 4], "text": "Здолай %d еліт"},
	{"stat": "field", "goal": [1, 2], "text": "Очисти місцевості: %d"},
	{"stat": "dungeon", "goal": [1, 1], "text": "Пройди печеру до боса"},
	{"stat": "parry", "goal": [3, 6], "text": "Відбий %d ударів парируванням"},
	{"stat": "charged", "goal": [3, 6], "text": "Влуч зарядженим ударом %d разів"},
]
const WEEKLY := [
	{"stat": "kill", "goal": [300, 500], "text": "Здолай %d ворогів за тиждень"},
	{"stat": "boss", "goal": [3, 5], "text": "Здолай босів: %d"},
	{"stat": "elite", "goal": [15, 25], "text": "Здолай %d еліт"},
	{"stat": "defense", "goal": [1, 2], "text": "Відстой облоги: %d"},
	{"stat": "travel", "goal": [4, 6], "text": "Переживи %d пригод у дорозі"},
	{"stat": "sharpen", "goal": [3, 5], "text": "Вдало нагостри зброю %d разів"},
]
const DAILY_COUNT := 3
const WEEKLY_COUNT := 2

const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "Перша кров", "desc": "Здолай першого ворога", "stat": "kill", "goal": 1, "gold": 20},
	{"id": "kills_100", "name": "Гроза нечисті", "desc": "Здолай 100 ворогів", "stat": "kill", "goal": 100, "gold": 100},
	{"id": "kills_1000", "name": "Козацька слава", "desc": "Здолай 1000 ворогів", "stat": "kill", "goal": 1000, "gold": 600},
	{"id": "kills_5000", "name": "Легенда степу", "desc": "Здолай 5000 ворогів", "stat": "kill", "goal": 5000, "gold": 2500},
	{"id": "elite_10", "name": "Мисливець на еліту", "desc": "Здолай 10 еліт", "stat": "elite", "goal": 10, "gold": 200},
	{"id": "elite_100", "name": "Жах еліти", "desc": "Здолай 100 еліт", "stat": "elite", "goal": 100, "gold": 1500},
	{"id": "zmii", "name": "Змієборець", "desc": "Здолай Триголового Змія", "stat": "boss:zmii", "goal": 1, "gold": 150},
	{"id": "koshchii", "name": "Смерть Кощієва", "desc": "Здолай Кощія Безсмертного", "stat": "boss:koshchii", "goal": 1, "gold": 800},
	{"id": "putinoid", "name": "Кінець упиря-царя", "desc": "Здолай Путіноїда в Кремлі", "stat": "boss:putinoid", "goal": 1, "gold": 3000},
	{"id": "parry_50", "name": "Сталеве зап'ястя", "desc": "Відбий 50 ударів парируванням", "stat": "parry", "goal": 50, "gold": 300},
	{"id": "charged_50", "name": "Козацький удар", "desc": "50 разів влуч зарядженим ударом", "stat": "charged", "goal": 50, "gold": 300},
	{"id": "defense_5", "name": "Оборонець", "desc": "Відстой 5 облог", "stat": "defense", "goal": 5, "gold": 600},
	{"id": "travel_10", "name": "Чумацький шлях", "desc": "Переживи 10 пригод у дорозі", "stat": "travel", "goal": 10, "gold": 250},
	{"id": "sharpen_10", "name": "Майстер точила", "desc": "10 разів вдало нагостри зброю", "stat": "sharpen", "goal": 10, "gold": 250},
	{"id": "bond_3", "name": "Побратими навіки", "desc": "Пройди особисті історії трьох побратимів", "stat": "bond", "goal": 3, "gold": 1000},
	{"id": "level_10", "name": "Бувалий козак", "desc": "Досягни 10 рівня", "stat": "level", "goal": 10, "gold": 300},
	{"id": "level_20", "name": "Сивий вояка", "desc": "Досягни 20 рівня", "stat": "level", "goal": 20, "gold": 1200},
	{"id": "hetman", "name": "Гетьман", "desc": "Пройди всю історію", "stat": "hetman", "goal": 1, "gold": 5000},
]
