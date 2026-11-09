extends RefCounted
## Бічна панель мапи: опис вибраного міста чи місцевості й кнопка вирушити.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const CampService := preload("res://scripts/game/camp_service.gd")


## Панель Глибин зарази: вибір глибини й спуск.
static func build_depths(world, player, sel: int, on_change: Callable, on_go: Callable) -> Control:
	var DS = load("res://scripts/game/depth_service.gd")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Глибини зарази", 28, UI.GOLD, false))
	if not DS.unlocked(world):
		v.add_child(_wrapped("Корені зарази під Кремлем. Відкриються після перемоги над Путіноїдом.", 18, UI.MUTED))
		return v
	var s: Dictionary = DS.state(world)
	var mx: int = s["max"]
	sel = clampi(sel, 1, mx)
	var L: Dictionary = DS.loc_for(sel)
	v.add_child(_wrapped("Печера без дна. Пройдеш глибину — відкриється наступна. Найглибше пройдено: %d." % s["best"], 17, UI.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.button("◂", func(): on_change.call(sel - 1), Vector2(70, 60), 26, sel > 1))
	var lab := UI.label("Глибина %d" % sel, 24, UI.GOLD)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	row.add_child(UI.button("▸", func(): on_change.call(sel + 1), Vector2(70, 60), 26, sel < mx))
	v.add_child(row)
	var danger: bool = int(L["level"]) > player.level + 2
	v.add_child(UI.label("Рівень %d  •  кімнат: %d" % [L["level"], L["rooms"]], 19, UI.BAD if danger else UI.TEXT, false))
	var names := []
	for e in L["enemies"]:
		names.append(Data.ENEMY_NAMES[e])
	v.add_child(_wrapped("Нечисть: %s. Бос: %s. Еліти: +%d%%." % [", ".join(names), Data.BOSS_NAMES[L["boss"]], roundi(L["elite_bonus"] * 100)], 16, UI.MUTED))
	v.add_child(UI.button("Спуститися", func(): on_go.call(sel), Vector2(350, 70), 26))
	return v


## Панель місця занять: варта, полювання, рибалка.
static func build_spot(sel: String, world, player, on_go: Callable) -> Control:
	var Acts = load("res://scripts/data/activities.gd")
	var S: Dictionary = Acts.SPOTS[sel]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label(S["name"], 28, UI.GOLD, false))
	v.add_child(_wrapped(S["desc"], 18, UI.TEXT))
	if player.level < int(S["level"]):
		v.add_child(_wrapped("Відкриється з %d-го рівня героя." % int(S["level"]), 18, UI.BAD))
		return v
	match str(S["kind"]):
		"vigil":
			var VS = load("res://scripts/game/vigil_service.gd")
			if not VS.unlocked(player):
				v.add_child(_wrapped("На варту беруть лише тих, хто вже обрав свою дорогу.", 18, UI.BAD))
				return v
			var s: Dictionary = VS.state(world)
			var goal_min := int(Acts.VIGIL_GOAL / 60.0)
			v.add_child(_wrapped("Вистій %d хвилин: нечисть суне без упину й щохвилини лютішає. Смерті нема — варту просто знято." % goal_min, 17, UI.TEXT))
			v.add_child(UI.label("Рекорд: %s  •  убитих: %d" % [VS.time_text(float(s["best_time"])), int(s["best_kills"])], 19, UI.GOLD, false))
			var paid := int(s["paid"])
			if paid >= goal_min:
				v.add_child(_wrapped("Сьогоднішню нагороду вже взято (хвилин: %d). Стій далі — на рекорд і нові хвилини." % paid, 16, UI.MUTED))
			else:
				var total := 0
				for m in range(paid + 1, goal_min + 1):
					total += int(VS.minute_reward(player.level, m)["gold"])
				v.add_child(_wrapped("Нагорода сьогодні: до %d грн, слава за кожну хвилину, речі на 3-й і %d-й, 2 трофеї за повну варту." % [total, goal_min], 16, UI.GOLD))
			v.add_child(UI.button("Стати на варту", on_go.bind(sel), Vector2(350, 70), 26))
		"hunt", "fish":
			var OS = load("res://scripts/game/outdoor_service.gd")
			var hunt: bool = str(S["kind"]) == "hunt"
			if hunt:
				v.add_child(_wrapped("Звірі перебігають галявину. Торкнись звіра, щоб пустити стрілу. Стріл: %d, тож бий напевно." % OS.arrows_for(player), 17, UI.TEXT))
				for id in Acts.HUNT_ANIMALS:
					var a: Dictionary = Acts.HUNT_ANIMALS[id]
					v.add_child(_wrapped("• %s: %d м'яса%s" % [a["name"], int(a["meat"]), " (лише в серцевину або з двох стріл)" if a["tough"] else ""], 16, UI.MUTED))
			else:
				v.add_child(_wrapped("Закинь вудку, дочекайся клювання й підсічи. Далі тримай натяг у зеленій смузі. Закидів: %d." % Acts.FISH_BAIT, 17, UI.TEXT))
				for id in Acts.FISH:
					var fi: Dictionary = Acts.FISH[id]
					v.add_child(_wrapped("• %s: %d риби" % [fi["name"], int(fi["ryba"])], 16, UI.MUTED))
			if OS.rich(world, str(S["kind"])):
				v.add_child(_wrapped("Чутка з шинку: сьогодні тут повно великого звіра." if hunt else "Чутка з шинку: сом вийшов на плесо, клює велика риба.", 17, UI.GOOD))
			v.add_child(_wrapped("У запасі: м'ясо %d  •  риба %d" % [OS.food(player, "meat"), OS.food(player, "ryba")], 19, UI.GOLD))
			v.add_child(_wrapped("Зі здобичі на хуторі варять страви в казані: вони додають сили на цілий похід.", 16, UI.MUTED))
			if OS.ready(world, str(S["kind"])):
				v.add_child(UI.button("Полювати" if hunt else "Рибалити", on_go.bind(sel), Vector2(350, 70), 26))
			else:
				v.add_child(_wrapped("Звір сполоханий: повернеться після походу." if hunt else "Риба вже не клює: повернеться після походу.", 17, UI.BAD))
		_:
			v.add_child(UI.button("Вирушити", on_go.bind(sel), Vector2(350, 70), 26))
	return v


## Панель Башти Кощія: вибір поверху й підйом.
static func build_tower(world, player, sel: int, on_change: Callable, on_go: Callable) -> Control:
	var TS = load("res://scripts/game/tower_service.gd")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UI.label("Башта Кощія", 28, UI.GOLD, false))
	if not TS.unlocked(player):
		v.add_child(_wrapped("Кістяна башта посеред Москви: безкінечний підйом. Відкриється з %d-го рівня героя." % TS.OPEN_LEVEL, 18, UI.MUTED))
		return v
	var s: Dictionary = TS.state(world)
	var mx: int = s["max"]
	sel = clampi(sel, 1, mx)
	var L: Dictionary = TS.loc_for(sel)
	v.add_child(_wrapped("Поверх — хвилі нечисті й міні-бос; кожен п'ятий — супербос. Пройшов — відкривається вищий. Рекорд: поверх %d." % s["best"], 17, UI.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.button("◂", func(): on_change.call(sel - 1), Vector2(70, 60), 26, sel > 1))
	var lab := UI.label("Поверх %d" % sel, 24, UI.GOLD)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	row.add_child(UI.button("▸", func(): on_change.call(sel + 1), Vector2(70, 60), 26, sel < mx))
	v.add_child(row)
	var danger: bool = int(L["level"]) > player.level + 2
	v.add_child(UI.label("Рівень %d  •  хвиль: %d" % [L["level"], L["waves"]], 19, UI.BAD if danger else UI.TEXT, false))
	var names := []
	for e in L["enemies"]:
		names.append(Data.ENEMY_NAMES[e])
	var boss_line: String = ("СУПЕРБОС: %s." % Data.BOSS_NAMES[L["boss"]]) if L["boss"] != "" else ("%s: %s." % [L["mini_title"], Data.ENEMY_NAMES[L["mini"]]])
	v.add_child(_wrapped("Нечисть: %s. %s Еліти: +%d%%." % [", ".join(names), boss_line, roundi(L["elite_bonus"] * 100)], 16, UI.MUTED))
	if sel > int(s["best"]):
		v.add_child(_wrapped("Перше проходження: +%d грн%s." % [TS.first_gold(sel), ", легендарна річ і камінь долі" if TS.is_super(sel) else " і річ"], 16, UI.GOLD))
	v.add_child(UI.button("Піднятися", func(): on_go.call(sel), Vector2(350, 70), 26))
	return v


## Подія в цьому місці (true — є бойова подія, кнопка «На поміч!» уже додана).
static func _event_note(v: Control, world, sel: String, on_go: Callable) -> bool:
	var ES = load("res://scripts/game/event_service.gd")
	for n in ES.notes_for(world, sel):
		v.add_child(_wrapped(n[0], 16, UI.GOLD if n[1] != "burned" else UI.BAD))
	if ES.fair_city(world) == sel:
		v.add_child(_wrapped("ЯРМАРОК: продаж удвічі дорожчий, у крамниці рідкісні речі (ще %d походи)." % int(ES.state(world)["fair"]["left"]), 16, UI.GOLD))
	var ev: Dictionary = ES.battle_at(world, sel)
	if ev.is_empty():
		return false
	var text: String = {"village_raid": "НАБІГ! Заражені палять село. Устигни за %d походи.", "caravan": "Чумаки чекають супроводу (ще %d походи).",
		"sich_siege": "ВЕЛИКА ОБЛОГА СІЧІ! Шість хвиль і ватажок. Протримаються %d походи.", "captives": "Конвой із бранцями ще тут (%d походи), далі піде в Московію.",
		"wounded": "Поранений козак чекає на поміч (%d походи)."}[ev["kind"]] % int(ev["left"])
	v.add_child(_wrapped(text, 18, UI.BAD))
	v.add_child(UI.button("На поміч!", on_go.bind(sel), Vector2(350, 70), 24))
	return true


## Попередження про облогу (true — місто/хутір в облозі).
static func _siege_note(v: Control, world, sel: String) -> bool:
	var DS = load("res://scripts/game/defense_service.gd")
	if DS.markup(world, sel) > 0.0:
		v.add_child(_wrapped("Місто пограбоване після облоги — ціни вищі.", 16, UI.BAD))
	if not DS.is_besieged(world, sel):
		return false
	v.add_child(_wrapped("ОБЛОГА! Заражені під брамою. Протримаються ще %d походи — далі впадуть." % DS.trips_left(world, sel), 18, UI.BAD))
	return true


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
		if _event_note(v, world, sel, on_go):
			return v
		if _siege_note(v, world, sel):
			v.add_child(UI.button("На оборону хутора!", on_go.bind(sel), Vector2(350, 70), 24))
			return v
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
		if _event_note(v, world, sel, on_go):
			return v
		if _siege_note(v, world, sel):
			v.add_child(UI.button("На оборону міста!", on_go.bind(sel), Vector2(350, 70), 24))
			return v
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
	var bt: Dictionary = load("res://scripts/game/bounty_service.gd").target_at(world, sel)
	if not bt.is_empty():
		v.add_child(_wrapped("Розшук: тут ходить %s." % bt["name"], 17, UI.GOLD))
	if _event_note(v, world, sel, on_go):
		return v
	v.add_child(UI.button("Вирушити", on_go.bind(sel), Vector2(350, 70), 26))
	return v


static func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	return l
