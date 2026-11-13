extends RefCounted
## Історія без інтерфейсу: розмови, нагороди й тексти кроків лінії «story». Що відкрито й що пройдено,
## вирішує QuestEngine (стан — world.missions, вибори там само). Для ратуші, журналу, порадника й мапи ця
## служба збирає всі сюжетні лінії (історія й «Попіл за вітром», SagaService) у порядку місій рушія.
## Етапи кроку: offer (чекає розмови в місті) → active (виконується мета) → turnin (повернутися до того,
## хто дав) → здано. Крок без розмови на початку стає активним сам; без «turn_in» — здається сам.

const Story := preload("res://scripts/data/story.gd")
const Data := preload("res://scripts/data/data.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const SagaService := preload("res://scripts/game/saga_service.gd")
const QuestEngine := preload("res://scripts/game/quest_engine.gd")

## Постійні наслідки виборів, які гра вміє (крім знижки міста «discount_<місто>»): хто їх читає —
## CampService.apply_effects (зілля, опір заразі), Game (Кощій смертний).
const EFFECTS := ["potion_max", "plague_resist", "koshchii_mortal"]
## Звання, які може дати нагорода («rank»).
const RANKS := ["hetman"]
## Види ліній, які журнал, ратуша й мапа показують як історію.
const KINDS := ["story", "saga"]

## Клас героя — для звертань у розмовах («козаче» / «волхве»). Виставляє гра.
static var hero_class := "cossack"


## Рідне село з прологу й крок «Утеча на Січ»: до нього поразка вдома нічого не коштує.
const HOME_ID := "ridne_selo"
const FLEE_ID := "flee"


## Чи впалий у бою герой лишається в рідному селі (ще не дійшов до Січі), а не отямлюється в місті.
static func wakes_at_home(world, loc_id: String) -> bool:
	return loc_id == HOME_ID and not QuestEngine.is_finished(world, FLEE_ID)


## Чи головну історію пройдено (усі кроки лінії «story» здано чи пропущено).
static func finished(world) -> bool:
	return QuestEngine.line_finished(world, Story.LINE)


## Скільки розділів поспіль від початку вже пройдено: номер нинішнього розділу (усі — коли історію пройдено).
static func chapter_index(world) -> int:
	for i in Story.chapter_count():
		for st in Story.steps(i):
			if not QuestEngine.is_finished(world, str(st["id"])):
				return i
	return Story.chapter_count()


## Нинішній крок історії або порожній словник, якщо історію пройдено.
static func current(world) -> Dictionary:
	var id := QuestEngine.line_next(world, Story.LINE)
	return Story.step(id) if id != "" else {}


## Етап нинішнього кроку історії: offer / active / turnin; "done" — історію пройдено.
static func stage(world) -> String:
	var st := current(world)
	if st.is_empty():
		return "done"
	var s := QuestEngine.stage(world, str(st["id"]))
	return s if s in ["active", "turnin"] else "offer"


## Сюжетні місії (історія й сага), відкриті зараз, у порядку рушія.
static func missions(world) -> Array:
	return QuestEngine.missions_of(world, KINDS)


## Ланки сюжетного ланцюжка, відкриті зараз: місії історії й саги та сюжетні перекази (переказ — ланка
## історії між розділами), у порядку рушія. Доручення сюди не йдуть: у них свої рядки.
static func chain(world) -> Array:
	return QuestEngine.missions(world).filter(func(id): return _is_link(str(id)))


## Ланки ланцюжка, яким бракує лише рівня героя (QuestEngine.waiting), у порядку рушія.
static func chain_waiting(world) -> Array:
	return QuestEngine.waiting(world).filter(func(id): return _is_link(str(id)))


static func _is_link(id: String) -> bool:
	var k := QuestEngine.kind_of(id)
	return k in KINDS or (k == "legend" and QuestEngine.is_story(id))


static func chapter_title(world) -> String:
	if finished(world):
		return SagaService.title(world) if SagaService.unlocked(world) else ""  # після Кремля — «Попіл за вітром»
	return Story.chapter_title(chapter_index(world))


static func _count(st: Dictionary) -> int:
	return int(st["objective"].get("count", 1))


# ---------- Діалоги ----------

## Вступна розповідь поточного кроку (пролог): показується на початку нової гри.
static func intro(world) -> Array:
	return lines(world, current(world).get("intro", []))


## Чи гравець колись обрав такий варіант. cond: "id_кроку=номер_вибору".
static func chose(world, cond: String) -> bool:
	return QuestEngine.chose(world, cond)


## Репліки, які має почути саме цей гравець (з урахуванням його минулих виборів і класу).
static func lines(world, src: Array) -> Array:
	var out := []
	for l in src:
		if l.size() < 3 or chose(world, l[2]):
			var npc: String = l[0]
			var text: String = l[1]
			if hero_class == "volkhv":
				text = text.replace("козаче", "волхве").replace("Козаче", "Волхве")
				if npc == "hero":
					npc = "hero_volkhv"
			elif hero_class == "strilets":
				text = text.replace("козаче", "стрільче").replace("Козаче", "Стрільче")
			out.append([npc, text])
	return out


static func _find_step(id: String) -> Dictionary:
	return Story.step(id)


## Постійні наслідки всіх зроблених виборів: {"discount_kyiv": 0.2, "potion_max": 1, ...}.
static func effects(world) -> Dictionary:
	var out := {}
	var made: Dictionary = QuestEngine.choices(world)
	for id in made:
		var choices: Array = _find_step(id).get("choices", [])
		var ci := int(made[id])
		if ci < 0 or ci >= choices.size():
			continue
		var eff: Dictionary = choices[ci].get("effects", {})
		for k in eff:
			out[k] = out.get(k, 0.0) + float(eff[k])
	return out


static func effect(world, key: String) -> float:
	return float(effects(world).get(key, 0.0))


## «Літопис»: записи про зроблені вибори в порядку показу кроків.
static func chronicle(world) -> Array:
	var out := []
	var made: Dictionary = QuestEngine.choices(world)
	for i in Story.chapter_count():
		for st in Story.steps(i):
			var key: String = Story.choice_key(st)  # вибір дороги зберігається як trial («choice_key»)
			if not made.has(key) or st.get("choices", []).is_empty():
				continue
			var choices: Array = st["choices"]
			var ci := int(made[key])
			if ci >= 0 and ci < choices.size():
				out.append({"chapter": Story.chapter_title(i), "text": choices[ci].get("memo", choices[ci]["text"])})
	return out


## Що сказати в цьому місті: {"kind": "start"/"end"/"saga_start"/"saga_end", "lines", "choices", "id"} або {}.
## Перша з сюжетних місій, що чекають тут розмови (id — саме ця місія).
static func city_dialogue(world, city: String, id: String = "") -> Dictionary:
	for d in city_dialogues(world, city):
		if id == "" or str(d["id"]) == id:
			return d
	return {}


## Новий клас, який дасть розмова з city_dialogue (здача кроку з «class» у нагороді), або "".
static func class_reward(d: Dictionary) -> String:
	if d.is_empty() or str(d.get("kind", "")) != "end":
		return ""
	return str(QuestEngine.step(str(d["id"])).get("reward", {}).get("class", ""))


## Усі сюжетні розмови, що чекають у цьому місті, у порядку місій.
static func city_dialogues(world, city: String) -> Array:
	var out := []
	for mid in missions(world):
		var d: Dictionary = QuestEngine.service(QuestEngine.kind_of(mid)).dialogue_of(world, mid, city)
		if not d.is_empty():
			out.append({"kind": d["kind"], "lines": lines(world, d["lines"]), "choices": d.get("choices", []), "id": mid})
	return out


## Розмова кроку історії id в цьому місті ({"kind", "lines" сирі, "choices"} або {}).
static func dialogue_of(world, id: String, city: String) -> Dictionary:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
		"offer":
			if str(st["city"]) == city:
				return {"kind": "start", "lines": st["start"], "choices": []}
		"turnin":
			if str(st["turn_in"]) == city:
				return {"kind": "end", "lines": st["end"], "choices": st.get("choices", [])}
	return {}


## Викликається, коли гравець дочитав діалог. Повертає повідомлення для гравця.
## id — крок розмови (з city_dialogue); "" — нинішній крок історії.
static func on_dialogue_done(world, player, kind: String, choice: int = -1, id: String = "") -> Array:
	if kind.begins_with("saga_"):
		return SagaService.on_dialogue_done(world, player, kind, id)
	if id == "":
		id = str(current(world).get("id", ""))
	if id == "" or not QuestEngine.is_open(world, id):
		return []
	if kind == "start":
		QuestEngine.start(world, id)
		var msgs := [{"text": "%s %s" % [QuestEngine.mark(id), QuestEngine.step(id)["objective"]["text"]], "big": true}]
		msgs.append_array(QuestEngine.check_stat(world, player, id))  # мета «stat»: «найвищого» міг досягти й раніше
		return msgs
	if kind == "end" and QuestEngine.stage(world, id) == "turnin":
		return _complete(world, player, id, choice)
	return []


# ---------- Події гри ----------

## Подія гри для сюжетних місій (історія й сага). Усі лінії разом — QuestEngine.on_event.
## type: clear / dungeon / visit (arg = id місця) або kill (arg = вид ворога).
static func on_event(world, player, type: String, arg: String) -> Array:
	return QuestEngine.on_event(world, player, type, arg, KINDS)


## Мету «принести» поповнено (QuestEngine.on_event).
static func fetch_msg(world, id: String) -> Dictionary:
	var st := QuestEngine.step(id)
	return {"text": "%s %s %d/%d" % [QuestEngine.mark(id), st["objective"]["item"], QuestEngine.progress(world, id), _count(st)], "big": false}


## Мету кроку виконано: повернутися до того, хто дав, або (без «turn_in») здати одразу.
static func objective_met(world, player, id: String) -> Array:
	var st := QuestEngine.step(id)
	if str(st["turn_in"]) == "":
		var msgs := [{"text": "%s Виконано: %s" % [QuestEngine.mark(id), st["objective"]["text"]], "big": true}]
		msgs.append_array(_complete(world, player, id, -1))
		return msgs
	QuestEngine.set_stage(world, id, "turnin")
	return [{"text": "%s Мету виконано!\nПовертайся: %s" % [QuestEngine.mark(id), Data.place_name(st["turn_in"])], "big": true}]


# ---------- Нагороди ----------

static func _complete(world, player, id: String, choice: int) -> Array:
	var st := QuestEngine.step(id)
	var msgs := []
	_apply_reward(world, player, st.get("reward", {}), msgs)
	var choices: Array = st.get("choices", [])
	if choice < 0 and not choices.is_empty():
		choice = 0  # розмову пропущено — перший варіант (інакше розгалуження загубиться)
	if choice >= 0 and choice < choices.size():
		_apply_reward(world, player, choices[choice].get("reward", {}), msgs)
		QuestEngine.set_choice(world, id, choice)  # під id кроку, як завжди (вибір дороги ще й під «choice_key», PathService)
	for b in st.get("bonus", []):
		if chose(world, b["if"]):
			_apply_reward(world, player, b["reward"], msgs)
	QuestEngine.complete(world, id)
	_chapter_done(world, st, msgs)
	return msgs


## Розділ завершено, коли здано його останню ланку (крок, на який не чекає жоден інший крок розділу) і
## всі кроки розділу пройдено: зараза відступає з краю («cleanse» розділу).
static func _chapter_done(world, st: Dictionary, msgs: Array) -> void:
	var ci := Story.chapter_index(str(st.get("chapter", "")))
	if ci < 0:
		return
	for other in Story.steps(ci):
		if str(st["id"]) in QuestEngine.after(str(other["id"])) or not QuestEngine.is_finished(world, str(other["id"])):
			return
	var ch: Dictionary = Story.chapter(ci)
	msgs.append({"text": "%s — завершено!" % ch["title"], "big": true})
	if ch.has("cleanse") or ch.get("cleanse_all", false):
		PlagueService.on_chapter_done(world, ci)
		msgs.append({"text": "Зараза відступає з цілого краю!", "big": true})


static func _apply_reward(world, player, r: Dictionary, msgs: Array) -> void:
	if r.has("class"):
		player.change_class(r["class"])
		hero_class = r["class"]
		msgs.append({"text": str(r.get("banner", "")), "big": true})
	if r.has("rank"):
		player.rank = r["rank"]
		msgs.append({"text": str(r.get("banner", "")), "big": true})
	if r.has("skills"):
		for id in r["skills"]:
			player.skills[id] = maxi(player.sk(id), int(r["skills"][id]))
			player.skill_gifts[id] = maxi(int(player.skill_gifts.get(id, 0)), int(r["skills"][id]))
	if r.has("stats"):
		for id in r["stats"]:
			player.stats[id] = int(player.stats.get(id, 0)) + int(r["stats"][id])
			player.stat_gifts[id] = int(player.stat_gifts.get(id, 0)) + int(r["stats"][id])
		player.recalc()
	if r.has("gold"):
		player.gold += int(r["gold"])
	if r.has("xp"):
		player.add_xp(int(r["xp"]))
	if r.has("loyalty"):
		for city in r["loyalty"]:
			world.add_loyalty(city, int(r["loyalty"][city]))
	if r.has("item"):
		var d: Dictionary = r["item"]
		var it := Data.gen_item(int(d["ilvl"]), int(d["rarity"]), d["slot"], d.get("type", ""))
		it["name"] = d["name"]
		it["up"] = int(d.get("up", 0))
		if not player.add_item(it):
			player.inventory.append(it)  # сюжетну нагороду не губимо навіть із повною торбою
		if r.has("class") and it["slot"] == "weapon":
			player.equip(it["uid"])  # зброя посвяти — одразу в руки
		msgs.append({"text": "Отримано: %s" % Data.item_title(it), "big": false})


# ---------- Для інтерфейсу ----------

## Рядок мети для списку завдань (із зіркою) або "": перша ланка ланцюжка (chain; переказ теж).
static func objective_line(world) -> String:
	var ms := chain(world)
	return mission_line(world, str(ms[0])) if not ms.is_empty() else ""


## Куди зараз веде сюжет (id міста чи місцевості) — для зірки на мапі: перша ланка ланцюжка.
static func target(world) -> String:
	var ms := chain(world)
	return QuestEngine.target(world, str(ms[0])) if not ms.is_empty() else ""


## Рядок мети місії id з позначкою (QuestEngine.mark: «★» — сюжетна, «!» — ні).
static func mission_line(world, id: String) -> String:
	if QuestEngine.kind_of(id) == "legend":  # рядок переказу — без позначки й назви лінії: додаємо їх тут
		return "%s Переказ «%s»: %s" % [QuestEngine.mark(id), QuestEngine.line_title(QuestEngine.line_of(id)), QuestEngine.service("legend").mission_line(world, id)]
	if QuestEngine.kind_of(id) != "story":
		return QuestEngine.service(QuestEngine.kind_of(id)).mission_line(world, id)
	var st := QuestEngine.step(id)
	var m := QuestEngine.mark(id)
	match QuestEngine.stage(world, id):
		"offer":
			return "%s Поговори: %s (%s)" % [m, Story.npc_name(st["giver"]), Data.place_name(st["city"])]
		"turnin":
			return "%s Повертайся: %s" % [m, Data.place_name(st["turn_in"])]
	var obj: Dictionary = st["objective"]
	var line: String = "%s %s" % [m, obj["text"]]
	if _count(st) > 1:
		line += " %d/%d" % [QuestEngine.progress(world, id), _count(st)]
	return line


## Куди веде крок історії id: до того, хто дає, до мети чи туди, де здати.
static func mission_target(world, id: String) -> String:
	var st := QuestEngine.step(id)
	match QuestEngine.stage(world, id):
		"offer":
			return st["city"]
		"turnin":
			return st["turn_in"]
	return st["objective"]["loc"]
