extends RefCounted
## Козацький хутір: ресурси, будівлі, ціни і що дає кожен рівень.

const CAMP_ID := "hutir"
const CAMP := {"name": "Козацький хутір", "pos": Vector2(35.9, 47.45),
	"desc": "Твій власний хутір під Січчю. Тут відпочивають і будуються."}

const RESOURCES := {"wood": "Дерево", "iron": "Залізо", "herbs": "Трави"}
const RESOURCE_COLORS := {"wood": Color(0.6, 0.4, 0.2), "iron": Color(0.65, 0.68, 0.72), "herbs": Color(0.35, 0.75, 0.3)}

# Який ресурс найчастіше дає ландшафт
const BIOME_RESOURCE := {"steppe": "wood", "river": "herbs", "forest": "wood", "swamp": "herbs",
	"mountain": "iron", "cave": "iron", "plague": "iron"}
const RESOURCE_DROP_CHANCE := 0.25

# Будівлі: назва, опис, ціни рівнів (гривні + ресурси) і що дає кожен рівень
const BUILDINGS := {
	"kurin": {"name": "Курінь", "desc": "Тут живе й тренується твій загін.",
		"levels": [
			{"gold": 200, "wood": 15, "iron": 0, "herbs": 0, "text": "Загін до 3 супутників"},
			{"gold": 600, "wood": 30, "iron": 10, "herbs": 0, "text": "Тренування: +50% досвіду супутникам"},
			{"gold": 1500, "wood": 50, "iron": 25, "herbs": 0, "text": "Загін до 4 супутників"},
		]},
	"kuznia": {"name": "Кузня", "desc": "Власний коваль: заточка й переплавка.",
		"levels": [
			{"gold": 250, "wood": 10, "iron": 10, "herbs": 0, "text": "Заточка на хуторі на 20% дешевше"},
			{"gold": 700, "wood": 15, "iron": 25, "herbs": 0, "text": "Переплавка непотрібних речей на залізо"},
			{"gold": 1800, "wood": 25, "iron": 50, "herbs": 0, "text": "+10% до шансу заточки"},
		]},
	"zillia": {"name": "Зілляварня", "desc": "Варіння зілля з трав.",
		"levels": [
			{"gold": 200, "wood": 10, "iron": 0, "herbs": 10, "text": "Варити зілля здоров'я з трав"},
			{"gold": 650, "wood": 15, "iron": 5, "herbs": 25, "text": "Зілля з собою +2, «Зілля сили» на похід"},
			{"gold": 1600, "wood": 25, "iron": 10, "herbs": 50, "text": "«Зілля проти зарази» на похід"},
		]},
	"sklad": {"name": "Склад", "desc": "Більше місця для здобичі.",
		"levels": [
			{"gold": 150, "wood": 20, "iron": 0, "herbs": 0, "text": "Торба +8 місць"},
			{"gold": 500, "wood": 40, "iron": 10, "herbs": 0, "text": "Торба +16 місць"},
		]},
	"pasika": {"name": "Пасіка", "desc": "Мед продається сам, поки ти в поході.",
		"levels": [
			{"gold": 300, "wood": 20, "iron": 0, "herbs": 5, "text": "Дохід 20 грн/год (росте з рівнем козака)"},
			{"gold": 800, "wood": 35, "iron": 5, "herbs": 15, "text": "Дохід 40 грн/год"},
			{"gold": 2000, "wood": 60, "iron": 15, "herbs": 30, "text": "Дохід 60 грн/год"},
		]},
}
const BUILD_ORDER := ["kurin", "kuznia", "zillia", "sklad", "pasika"]

# Варіння (Зілляварня)
const BREW := {
	"heal": {"name": "Зілля здоров'я", "herbs": 3, "iron": 0, "level": 1, "desc": "+1 зілля в торбу"},
	"strength": {"name": "Зілля сили", "herbs": 6, "iron": 1, "level": 2, "desc": "+30% шкоди на наступний похід"},
	"antiplague": {"name": "Зілля проти зарази", "herbs": 8, "iron": 2, "level": 3, "desc": "Хмари зарази не шкодять, -20% шкоди від ворогів на похід"},
}

const PASIKA_RATE := [0, 20, 40, 60]  # грн/год на рівнях пасіки
const PASIKA_CAP_HOURS := 12.0
