extends RefCounted
## Бічна панель мапи: опис вибраного міста чи місцевості й кнопка вирушити.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")


## on_go(id) викликається кнопкою «Вирушити» / «Увійти до міста».
static func build(sel: String, world, player: Player, on_go: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	if sel == "":
		v.add_child(UI.label("Мапа земель", 28, UI.GOLD, false))
		v.add_child(UI.label("Торкнись місця на мапі.\nЩипок або +/− — масштаб,\nпалець — рух мапою.", 19, UI.TEXT, false))
		for t in ["Фортеця — місто: крамниця, коваль,\nкорчма, завдання", "Шаблі — дика місцевість", "Арка — печера з босом", "«!» — тут твоє завдання", "Червоне коло — небезпечно\nдля твого рівня", "(число) — рівень місцевості"]:
			v.add_child(UI.label(t, 16, UI.MUTED, false))
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
	var names := []
	for e in L["enemies"]:
		names.append(Data.ENEMY_NAMES[e])
	v.add_child(UI.label("Нечисть: " + ", ".join(names), 17, UI.MUTED, false))
	for q in world.quests:
		if q["loc"] == sel and not world.is_done(q):
			v.add_child(_wrapped("! " + q["text"], 16, UI.GOLD))
	v.add_child(UI.button("Вирушити", on_go.bind(sel), Vector2(350, 70), 26))
	return v


static func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
