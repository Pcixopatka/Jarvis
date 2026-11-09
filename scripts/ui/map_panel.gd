extends RefCounted
## Бічна панель мапи: опис вибраного міста чи місцевості й кнопка вирушити.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const CampService := preload("res://scripts/game/camp_service.gd")


## on_go(id) викликається кнопкою «Вирушити» / «Увійти до міста».
static func build(sel: String, world, player: Player, on_go: Callable, story_target: String = "", story_line: String = "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if story_line != "" and (sel == "" or sel == story_target):
		v.add_child(_wrapped(story_line, 18, UI.GOLD))
	if sel == "":
		v.add_child(UI.label("Мапа земель", 28, UI.GOLD, false))
		v.add_child(UI.label("Торкнись місця на мапі.\nЩипок або +/− — масштаб,\nпалець — рух мапою.", 19, UI.TEXT, false))
		for t in ["Фортеця — місто: крамниця, коваль,\nкорчма, завдання", "Хата з прапором — твій хутір", "Шаблі — дика місцевість", "Арка — печера з босом", "★ — куди веде історія", "«!» — тут твоє завдання", "Червоне коло — небезпечно\nдля твого рівня", "(число) — рівень місцевості"]:
			v.add_child(UI.label(t, 16, UI.MUTED, false))
		return v
	if sel == Camp.CAMP_ID:
		v.add_child(UI.label(Camp.CAMP["name"], 28, UI.GOLD, false))
		v.add_child(_wrapped(Camp.CAMP["desc"], 18, UI.TEXT))
		var built := []
		for id in Camp.BUILD_ORDER:
			if CampService.level(world, id) > 0:
				built.append("%s %d" % [Camp.BUILDINGS[id]["name"], CampService.level(world, id)])
		v.add_child(_wrapped("Будівлі: " + (", ".join(built) if not built.is_empty() else "ще нічого не збудовано"), 16, UI.MUTED))
		var honey := CampService.pasika_ready(world, player.level)
		if honey > 0:
			v.add_child(UI.label("Пасіка: готово %d грн" % honey, 17, UI.GOOD, false))
		v.add_child(UI.button("Увійти на хутір", on_go.bind(sel), Vector2(350, 70), 26))
		return v
	if Data.CITIES.has(sel):
		var C: Dictionary = Data.CITIES[sel]
		v.add_child(UI.label(C["name"], 28, UI.GOLD, false))
		v.add_child(UI.label("Місто", 18, UI.MUTED, false))
		v.add_child(_wrapped(C["desc"], 18, UI.TEXT))
		v.add_child(UI.label("Лояльність: %s (%d)" % [Data.LOYALTY_NAMES[world.loyalty_level(sel)], world.loyalty_points(sel)], 18, UI.TEXT, false))
		var done := 0
		for q in world.quests:
			if q["city"] == sel and world.is_done(q):
				done += 1
		if done > 0:
			v.add_child(UI.label("Можна здати завдань: %d" % done, 18, UI.GOOD, false))
		v.add_child(UI.button("Увійти до міста", on_go.bind(sel), Vector2(350, 70), 26))
		return v
	var L: Dictionary = Data.LOCATIONS[sel]
	v.add_child(UI.label(L["name"], 28, UI.GOLD, false))
	var kind_text: String = ("Печера • %d кімнат • бос: %s" % [L["rooms"], Data.BOSS_NAMES[L["boss"]]]) if L["type"] == "dungeon" else "Дика місцевість"
	v.add_child(UI.label(kind_text, 17, UI.MUTED, false))
	var danger: bool = L["level"] > player.level + 2
	v.add_child(UI.label("Рівень місцевості: %d%s" % [L["level"], "  — небезпечно!" if danger else ""], 19, UI.BAD if danger else UI.TEXT, false))
	v.add_child(_wrapped(L["desc"], 18, UI.TEXT))
	var pl: int = load("res://scripts/game/plague_service.gd").level(world, sel)
	if pl > 0:
		v.add_child(_wrapped("Зараза: %s (%d/3). Вороги сильніші, нагорода більша на %d%%. Зачисти — і зараза відступить." % [
			["", "слабка", "сильна", "чорна"][pl], pl, 25 * pl], 17, Color(0.6, 1.0, 0.35)))
	var names := []
	for e in L["enemies"]:
		names.append(Data.ENEMY_NAMES[e])
	v.add_child(_wrapped("Нечисть: " + ", ".join(names), 17, UI.MUTED))
	var times: int = world.cleared.get(sel, 0)
	var rep := "Можна проходити повторно для прокачки"
	if times > 0:
		rep += " • пройдено: %d" % times
	v.add_child(_wrapped(rep, 16, UI.GOOD))
	for q in world.quests:
		if q["loc"] == sel and not world.is_done(q):
			v.add_child(_wrapped("! " + q["text"], 16, UI.GOLD))
	v.add_child(UI.button("Вирушити", on_go.bind(sel), Vector2(350, 70), 26))
	return v


static func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	return l
