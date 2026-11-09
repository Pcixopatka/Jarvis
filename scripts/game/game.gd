class_name Game
extends Node2D
## Диригент гри: режими (меню → мапа → місто → похід), збереження, екрани, клавіатура.
## Бій веде Combat, інтерфейс — Hud, логіку міста — CityService; Game лише з'єднує їх.

const Data := preload("res://scripts/data/data.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const UiCharacter := preload("res://scripts/ui/ui_character.gd")
const UiCity := preload("res://scripts/ui/ui_city.gd")
const MapPanel := preload("res://scripts/ui/map_panel.gd")
const WorldState := preload("res://scripts/game/world_state.gd")
const CityService := preload("res://scripts/game/city_service.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const HeroService := preload("res://scripts/game/hero_service.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const TravelService := preload("res://scripts/game/travel_service.gd")
const DefenseService := preload("res://scripts/game/defense_service.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const Party := preload("res://scripts/game/party.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const AdRewards := preload("res://scripts/game/ad_rewards.gd")
const UiCamp := preload("res://scripts/ui/ui_camp.gd")
const DialogueScript := preload("res://scripts/ui/dialogue.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")
const PlayerScript := preload("res://scripts/entities/player.gd")
const CombatScript := preload("res://scripts/game/combat.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

enum State { MENU, MAP, CITY, CAMP, PLAYING, CHARACTER, PAUSED, DEAD }

var state := State.MENU
var player: Player = null
var world = WorldState.new()
var combat: Combat
var hud: Hud
var meta := {"playtime": 0.0, "created": 0.0}
var save_path: String = SaveSystem.SAVE_PATH  # тести підміняють, щоб не чіпати справжнє збереження

var city_id := ""
var map_here := "sich"
var map_sel := ""

# Стан екранів (читають ui_character.gd та ui_city.gd)
var char_tab := 0
var char_sel_uid := -1
var char_return := State.MAP
var city_tab := 0
var city_sel_uid := -1
var smith_msg := ""
var smith_msg_color := Color.WHITE
var camp_tab := 0
var camp_sel_uid := -1


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := SaveSystem.load_settings()
	Audio.set_sound(settings["sound"])
	Audio.set_music(settings["music"])

	combat = CombatScript.new()
	add_child(combat)
	combat.move_input = _move_input
	combat.block_input = func() -> bool:
		return hud.btn_block.held or Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_B)
	combat.attack_input = func() -> bool:
		return hud.btn_attack.held or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_SPACE)

	hud = HudScript.new()
	add_child(hud)
	hud.attack_pressed.connect(func(): if state == State.PLAYING: player.attack())
	hud.dodge_pressed.connect(func(): if state == State.PLAYING: player.dodge())
	hud.skill_pressed.connect(func(id): if state == State.PLAYING: player.use_skill(id))
	hud.potion_pressed.connect(func(): if state == State.PLAYING: player.use_potion())
	hud.pause_pressed.connect(func(): if state == State.PLAYING: _show_pause())
	hud.character_pressed.connect(open_character)
	hud.map_pressed.connect(func(): if state == State.PLAYING: _try_leave())
	hud.map_location_selected.connect(_on_map_select)

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.level_up.connect(_on_level_up)
	Events.player_died.connect(_on_player_died)
	Events.companion_down.connect(_on_companion_down)
	Events.field_cleared.connect(_on_location_cleared)
	Events.dungeon_cleared.connect(_on_dungeon_cleared)
	Events.exit_requested.connect(_on_exit)
	Events.defense_won.connect(_on_defense_won)
	Events.parried.connect(func(): _record("parry"))
	Events.charged_hit.connect(func(): _record("charged"))
	Events.defense_lost.connect(_on_defense_lost)
	Events.item_found.connect(func(_i): hint("item", "Знайдено річ! Вдягни її: кнопка «Козак» → вкладка «Спорядження»."))
	Events.boss_spawned.connect(func(_e): hint("boss", "Бос! Червоні зони на землі — місця його удару. Виходь із них, поки вони не заповнились!"))
	Events.hint.connect(hint)
	Events.player_hurt.connect(func():
		if world != null and world.hints.has("combat"):
			hint("block", "Натисни «Блок» саме тоді, коли ворог червоніє, — парируєш удар і приголомшиш його. Тримай «Блок» довше — зарядиш потужний удар, відпусти — вдар!"))
	_show_main_menu()


func _process(delta: float) -> void:
	if player == null:
		return
	if state == State.PLAYING:
		meta["playtime"] = float(meta.get("playtime", 0.0)) + delta
		AdRewards.tick(world, delta)
	player.xp_boost = AdRewards.xp_mult(world)
	var top := StoryService.objective_line(world)
	for l in HeroService.objective_lines(world):
		top += "\n" + l
	if AdRewards.xp2_left(world) > 0.0:
		top = "×2 досвіду: %s\n%s" % [AdRewards.format_time(AdRewards.xp2_left(world)), top]
	hud.update(player, world, _combat_info(), delta, top.strip_edges())


func _combat_info() -> Dictionary:
	if state != State.PLAYING or not combat.active:
		return {}
	var L: Dictionary = combat.loc
	var sub := ""
	if combat.is_defense():
		var gp: int = roundi(100.0 * combat.gate.hp / combat.gate.max_hp) if combat.gate != null and is_instance_valid(combat.gate) else 0
		sub = "Хвиля %d/%d  •  Брама %d%%" % [combat.wave, L["waves"], gp]
		if combat.defense_over and combat.field_cleared:
			sub = "Оборону виграно! Портал веде до брами"
	elif combat.is_dungeon():
		sub = "Кімната %d/%d" % [combat.room, L["rooms"]]
	elif combat.field_cleared:
		sub = "Очищено! Портал веде на мапу"
	else:
		sub = "Рівень %d  •  Зачистка: %d/%d" % [L["level"], combat.field_kills, combat.field_goal]
	return {"name": L["name"], "sub": sub}


func _move_input() -> Vector2:
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if k != Vector2.ZERO:
		return k.normalized()
	return hud.move_vector()


# ======================= Герой і збереження =======================

func _new_hero(data: Dictionary) -> void:
	if player:
		player.queue_free()
	player = PlayerScript.new()
	if not data.is_empty():
		player.from_dict(data)
	combat.set_player(player)


func new_game() -> void:
	world = WorldState.new()
	meta = {"playtime": 0.0, "created": Time.get_unix_time_from_system()}
	_new_hero({})
	_make_peasant()
	CampService.apply_effects(world, player)
	player.gold = 20
	map_here = "ridne_selo"
	# Кобзар розповідає, як усе почалося, — і бій за рідне село
	var dlg = DialogueScript.new()
	dlg.setup(StoryService.intro(world), [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		enter_location("ridne_selo"))
	hud.close_overlay()
	hud.set_mode(false, false)
	hud.show_dialogue(dlg)


## Простий хлопець із хутора: вила, сорочка, жодних козацьких умінь до посвяти.
func _make_peasant() -> void:
	player.rank = "peasant"
	player.skills = {}
	player.inventory.clear()
	player.equipment.clear()
	var vyla := Data.gen_item(1, 0, "weapon", "pike")
	vyla["name"] = "Вила"
	player.equip_new(vyla)
	player.recalc()
	player.hp = player.max_hp


func save_game() -> void:
	if player == null:
		return
	SaveSystem.save({"player": player.to_dict(), "world": world.to_dict(), "meta": meta}, save_path)


func load_game() -> bool:
	var d := SaveSystem.load_data(save_path)
	if d.is_empty():
		return false
	world = WorldState.new()
	world.from_dict(d["world"])
	meta = d.get("meta", meta)
	_new_hero(d["player"])
	Party.normalize(world, player.level)
	CampService.apply_effects(world, player)
	return true


func _continue_game() -> void:
	if load_game():
		map_here = world.last_city
		enter_city(world.last_city)
	else:
		new_game()


# ======================= Режими =======================

func _leave_combat() -> void:
	hud.close_dialogue()
	if combat.active:
		combat.collect_all()
		combat.leave()


func enter_map() -> void:
	var from_trip: bool = combat.active
	_leave_combat()
	hud.clear_screen()
	hud.close_overlay()
	state = State.MAP
	Audio.play_music("calm")
	get_tree().paused = true
	hud.set_mode(true, false)
	hud.show_map(true)
	var mv = hud.map_view
	mv.current = map_here
	mv.focus_on(map_here)
	mv.selected = map_sel
	mv.hero_level = player.level
	mv.targets = world.quest_targets()
	for loc in HeroService.targets(world):
		mv.targets[loc] = true
	mv.story_target = StoryService.target(world)
	mv.plague = PlagueService.state(world)["levels"]
	if from_trip:
		var news := []
		var spread := PlagueService.tick(world)
		if not spread.is_empty():
			news.append("Зараза повзе далі: " + ", ".join(spread))
		news.append_array(DefenseService.tick(world, player))
		if not news.is_empty():
			hud.show_banner("\n".join(news), Color(1.0, 0.75, 0.4))
	mv.sieges = DefenseService.state(world)["sieges"]
	_build_map_panel()
	save_game()
	hint("map", "Торкнись місця на мапі. «!» позначає твоє завдання. Почни з Дикого Поля поруч із Січчю.")


func enter_city(id: String) -> void:
	_leave_combat()
	hud.close_overlay()
	state = State.CITY
	Audio.play_music("calm")
	get_tree().paused = true
	city_id = id
	map_here = id
	world.last_city = id
	player.revive()
	world.revive_companions()
	hud.show_map(false)
	hud.set_mode(false, false)
	city_sel_uid = -1
	smith_msg = ""
	_build_city()
	_story_event("visit", id)
	_story_dialogue(id)
	save_game()
	hint("city", "Це місто. На вкладці «Завдання» візьми доручення, у «Крамниці» купи спорядження, а потім натисни «На мапу».")


func leave_city() -> void:
	enter_map()


func enter_location(id: String) -> void:
	map_here = id
	for cid in Data.CITIES:
		world.shop_dirty[cid] = true
	hud.clear_screen()
	hud.close_dialogue()
	hud.close_overlay()
	hud.show_map(false)
	combat.boss_revives = 0 if StoryService.effect(world, "koshchii_mortal") > 0.0 else 1
	combat.enter(id, _party_data(), PlagueService.level(world, id))
	hud.set_mode(true, true)
	state = State.PLAYING
	get_tree().paused = false
	Audio.play_music("battle")
	hint("combat", "Ліва частина екрана — рух. Тримай «Удар» — козак сам б'є найближчу нечисть. Коли ворог червоніє — він замахується: тисни «Перекид»!")


func _try_leave() -> void:
	if not combat.can_leave():
		hud.show_banner("Нечисть поруч — не втечеш!", UI.BAD)
		return
	enter_map()


func _resume_play() -> void:
	hud.close_overlay()
	hud.clear_screen()
	state = State.PLAYING
	get_tree().paused = false
	hud.set_mode(true, true)


# ======================= Події =======================

func _on_enemy_killed(e: Node2D) -> void:
	for m in world.on_kill(e.kind):
		combat.float_text(player.global_position + Vector2(0, -90), m, UI.GOLD)
	_story_event("kill", e.kind)
	_hero_event("kill", e.kind)
	_record("kill")
	_record("kill:" + e.kind)
	if e.elite:
		_record("elite")
	if e.is_boss:
		_record("boss")
		_record("boss:" + e.kind)
	for up in Party.gain_xp(world, player.level, roundi(e.xp_value * CampService.companion_xp_mult(world) * AdRewards.xp_mult(world))):
		combat.companion_level_up(up[0], up[1])


## Передає подію сюжету й показує гравцеві, що змінилося.
func _story_event(type: String, arg: String) -> void:
	for m in StoryService.on_event(world, player, type, arg):
		if m["big"]:
			hud.show_banner(m["text"], UI.GOLD)
			Audio.play("quest", 0.0)
		elif combat.active:
			combat.float_text(player.global_position + Vector2(0, -110), m["text"], UI.GOLD)


## Зачистка відкидає заразу з місцевості (з печери — повністю: бос був її серцем).
func _cleanse(loc_id: String) -> void:
	var was := PlagueService.level(world, loc_id)
	if was == 0:
		return
	var now := PlagueService.cleanse(world, loc_id, was if Data.LOCATIONS[loc_id]["type"] == "dungeon" else 1)
	var text := "Зараза відступає!" if now > 0 else "Місцевість очищено від зарази!"
	combat.float_text(player.global_position + Vector2(0, -150), text, Color(0.6, 1.0, 0.4))


## Загін для бою: записи світу + сила, ім'я й колір побратимів.
func _party_data() -> Array:
	var out := []
	for c in world.companions:
		var d: Dictionary = c.duplicate()
		var id: String = c.get("hero", "")
		if id != "":
			d["mult"] = HeroService.power(world, id)
			d["name"] = HeroService.info(id)["name"]
			d["color"] = HeroService.info(id)["color"]
		out.append(d)
	return out


func _hero_event(type: String, arg: String) -> void:
	for m in HeroService.on_event(world, type, arg):
		if m["big"]:
			hud.show_banner(m["text"], UI.GOLD)
			Audio.play("quest", 0.0)
		elif combat.active:
			combat.float_text(player.global_position + Vector2(0, -130), m["text"], Color(0.7, 0.9, 1.0))


## Побратим хоче поговорити в цьому місті (зустріч, особисте завдання, його завершення).
func _hero_dialogue(city: String) -> void:
	var d := HeroService.city_dialogue(world, city)
	if d.is_empty():
		return
	var dlg = DialogueScript.new()
	dlg.setup(d["lines"], d["choices"])
	dlg.finished.connect(func(choice: int):
		hud.close_dialogue()
		var texts := []
		for m in HeroService.on_dialogue_done(world, player, d, choice):
			texts.append(m["text"])
		if d["kind"] == "end":
			_record("bond")
		if not texts.is_empty():
			hud.show_banner("\n".join(texts), UI.GOLD)
			Audio.play("quest", 0.0)
		save_game()
		if state == State.CITY and city_id == city:
			_build_city()
			_hero_dialogue(city))
	hud.show_dialogue(dlg)


## Якщо в цьому місті на козака чекає сюжетна розмова — показує її (і наступну, якщо їх кілька поспіль).
func _story_dialogue(city: String) -> void:
	var d := StoryService.city_dialogue(world, city)
	if d.is_empty():
		_hero_dialogue(city)  # сюжет мовчить — може, побратим хоче поговорити
		return
	var dlg = DialogueScript.new()
	dlg.setup(d["lines"], d["choices"])
	dlg.finished.connect(func(choice: int):
		hud.close_dialogue()
		var msgs := StoryService.on_dialogue_done(world, player, d["kind"], choice)
		CampService.apply_effects(world, player)  # вибір міг дати постійний наслідок
		if player.rank == "hetman" and int(world.stats.get("hetman", 0)) == 0:
			_record("hetman")
		var texts := []
		for m in msgs:
			texts.append(m["text"])
		if not texts.is_empty():
			hud.show_banner("\n".join(texts.slice(0, 3)), UI.GOLD)
			Audio.play("quest", 0.0)
		save_game()
		if state == State.CITY and city_id == city:
			_build_city()
			_story_dialogue(city))
	hud.show_dialogue(dlg)


func _on_companion_down(index: int, _name: String) -> void:
	if index < world.companions.size():
		world.companions[index]["downed"] = true


func _on_location_cleared(loc_id: String) -> void:
	world.cleared[loc_id] = world.cleared.get(loc_id, 0) + 1
	_cleanse(loc_id)
	_record("field")
	_story_event("clear", loc_id)
	_hero_event("clear", loc_id)


func _on_dungeon_cleared(loc_id: String) -> void:
	world.on_dungeon(loc_id)
	_cleanse(loc_id)
	_record("dungeon")
	_story_event("dungeon", loc_id)
	_hero_event("dungeon", loc_id)


## Подія для викликів і досягнень; виконані показуються банером.
func _record(stat: String, amount: int = 1) -> void:
	var msgs := ChallengeService.record(world, player, stat, amount)
	if msgs.is_empty():
		return
	hud.show_banner("\n".join(msgs), Color(1.0, 0.85, 0.35))
	Audio.play("quest", 0.0)


func _on_level_up(lvl: int) -> void:
	_record("level", lvl)
	hud.show_banner("Рівень %d!\nВідкрий «Козак», щоб прокачатися" % lvl, UI.GOLD)
	hint("levelup", "Новий рівень! Натисни «Козак» угорі: вклади очки в характеристики, вміння й перки.")


func _on_player_died() -> void:
	if combat.is_defense() and not combat.defense_over:
		combat.defense_over = true
		hud.show_banner(DefenseService.lose(world, player, combat.loc["target"]), UI.BAD)
	state = State.DEAD
	hud.set_mode(true, false)
	hud.char_btn.visible = false
	hud.show_banner("Козак поліг...", Color(1.0, 0.4, 0.35))
	await get_tree().create_timer(1.4).timeout
	var lost := int(player.gold * 0.25)
	player.gold -= lost
	_open_menu()
	hud.add_title("Козак поліг", 64, Color(1.0, 0.45, 0.35))
	hud.add_title("Побратими винесли тебе з бою. Втрачено %d грн." % lost, 24, UI.TEXT)
	hud.add_button("Отямитися: %s" % Data.place_name(world.last_city), func(): enter_city(world.last_city))


## Показує підказку один раз за всю гру.
func hint(id: String, text: String) -> void:
	if world.hints.has(id):
		return
	world.hints[id] = true
	hud.show_hint(text, state == State.MAP)


# ======================= Мапа =======================

func _on_map_select(id: String) -> void:
	map_sel = id
	hud.map_view.selected = id
	_build_map_panel()


func _build_map_panel() -> void:
	var panel := MapPanel.build(map_sel, world, player, _go_to, StoryService.target(world), StoryService.objective_line(world))
	if map_sel == "":
		var left := AdRewards.xp2_left(world)
		panel.add_child(UI.label(("×2 досвіду ще %s" % AdRewards.format_time(left)) if left > 0.0 else "Подарунок спонсора: ×2 досвіду на годину гри", 17, UI.GOLD, false))
		panel.add_child(UI.button("Переглянути рекламу", func(): _watch_xp2(_build_map_panel), Vector2(350, 56), 18, AdRewards.can_xp2(world)))
	hud.set_map_panel(panel)


func _go_to(id: String) -> void:
	if id == Camp.CAMP_ID:
		enter_camp()
	elif DefenseService.is_besieged(world, id):
		start_defense(id)
	elif Data.CITIES.has(id):
		enter_city(id)
	else:
		_travel_to(id)


# ======================= Оборона =======================

var defense_target := ""  # куди повернутися після виграної оборони


## Бій біля брами обложеного міста чи хутора.
func start_defense(target: String) -> void:
	combat.defense_loc = DefenseService.battle_loc(world, target, player)
	enter_location("defense")
	map_here = target
	hint("defense", "Облога! Нечисть іде хвилями й ламає браму внизу. Стань між ними та брамою — коли брама впаде, оборону програно.")


func _on_defense_won(target: String) -> void:
	defense_target = target
	hud.show_banner(DefenseService.win(world, player, target), UI.GOLD)
	_record("defense")
	save_game()


func _on_defense_lost(target: String) -> void:
	if not DefenseService.is_besieged(world, target):
		return
	hud.show_banner(DefenseService.lose(world, player, target), UI.BAD)
	save_game()
	await get_tree().create_timer(2.5).timeout
	if state == State.PLAYING and combat.is_defense():
		enter_map()


## Портал виходу: після оборони — одразу в урятоване місто чи на хутір.
func _on_exit() -> void:
	var t := defense_target
	defense_target = ""
	if t == Camp.CAMP_ID:
		enter_camp()
	elif t != "":
		enter_city(t)
	else:
		enter_map()


## Дорога до місцевості: іноді трапляється пригода, а вже потім — похід.
func _travel_to(id: String) -> void:
	var ev := TravelService.roll(world, player)
	if ev.is_empty():
		enter_location(id)
		return
	var dlg = DialogueScript.new()
	dlg.setup(ev["lines"], ev["choices"])
	dlg.finished.connect(func(choice: int):
		hud.close_dialogue()
		if choice >= 0 and choice < ev["choices"].size():
			var summary := TravelService.apply(world, player, ev["choices"][choice]["outcome"])
			_record("travel")
			if summary != "":
				hud.show_banner(summary, UI.GOLD)
		enter_location(id))
	hud.show_dialogue(dlg)


# ======================= Місто =======================

func _build_city() -> void:
	hud.set_screen(UiCity.build(self, city_id))


func shop_stock(city: String) -> Array:
	return CityService.shop_stock(world, player, city)


func buy_price(city: String, item: Dictionary) -> int:
	return CityService.buy_price(world, city, item)


func hire_price(city: String, type: String) -> int:
	return CityService.hire_price(world, player, city, type)


func city_do(action: String, arg) -> void:
	match action:
		"take":
			world.take(city_id, arg)
		"abandon":
			world.abandon(arg)
		"turn_in":
			var r := CityService.turn_in(world, player, arg)
			if not r.is_empty():
				var q: Dictionary = r["quest"]
				Audio.play("quest", 0.0)
				if r["loyalty_up"]:
					hud.show_banner("Лояльність зросла!\n%s: %s" % [Data.place_name(q["city"]), Data.LOYALTY_NAMES[world.loyalty_level(q["city"])]], UI.GOOD)
				else:
					hud.show_banner("Завдання виконано!\n+%d грн, +%d досвіду" % [q["gold"], q["xp"]], UI.GOLD)
		"select":
			city_sel_uid = arg
			smith_msg = ""
		"buy":
			if CityService.buy(world, player, city_id, arg):
				Audio.play("coin", 0.0)
		"sell":
			CityService.sell(player, arg)
			city_sel_uid = -1
		"sell_junk":
			CityService.sell_junk(player)
		"sharpen":
			_sharpen(arg)
		"hire":
			CityService.hire(world, player, city_id, arg)
		"buy_potion":
			if CityService.buy_potion(world, player, city_id):
				Audio.play("coin", 0.0)
		"ad_safe":
			Ads.show_rewarded("safe_sharpen", func(ok: bool):
				if ok and AdRewards.grant_safe(world):
					hud.show_banner("Дякуємо! +1 безпечна заточка", UI.GOOD)
				save_game()
				if state == State.CITY:
					_build_city())
			return
		"dismiss":
			CityService.dismiss(world, arg)
		"hero_join":
			for m in HeroService.join(world, player, arg):
				hud.show_banner(m["text"], UI.GOLD)
	save_game()
	_build_city()


func _sharpen(uid: int, cost_mult: float = 1.0, chance_bonus: float = 0.0) -> void:
	var before: int = player.find_item(uid).get("up", 0)
	# Жетон безпечної заточки витрачається лише на ризиковану спробу
	var safe := before >= Data.SHARPEN_RISK_FROM and AdRewards.use_safe(world)
	match player.sharpen(uid, cost_mult, chance_bonus, safe):
		"ok":
			Audio.play("sharpen_ok", 0.03)
			_record("sharpen")
			smith_msg = "Успіх! Тепер +%d" % (before + 1)
			smith_msg_color = UI.GOOD
		"fail":
			Audio.play("sharpen_fail")
			smith_msg = "Не вдалося... Заточка лишилась +%d" % before
			if safe:
				smith_msg += " (безпечна заточка вберегла)"
			smith_msg_color = UI.MUTED
		"down":
			Audio.play("sharpen_fail")
			smith_msg = "Лезо тріснуло! Заточка впала до +%d" % (before - 1)
			smith_msg_color = UI.BAD
		"nogold":
			smith_msg = "Бракує гривень."
			smith_msg_color = UI.BAD


# ======================= Екран козака =======================

func open_character() -> void:
	if state == State.CHARACTER or player == null:
		return
	if not (state == State.PLAYING or state == State.MAP or state == State.CITY or state == State.CAMP):
		return
	char_return = state
	state = State.CHARACTER
	get_tree().paused = true
	hud.show_map(false)
	hud.set_mode(false, false)
	char_sel_uid = -1
	_build_character()


func _build_character() -> void:
	hud.set_screen(UiCharacter.build(self))


func char_do(action: String, arg) -> void:
	match action:
		"stat":
			player.add_stat(arg)
		"skill":
			player.learn_skill(arg)
		"perk":
			player.learn_perk(arg)
		"select":
			char_sel_uid = arg
		"equip":
			player.equip(arg)
		"unequip":
			player.unequip(arg)
		"drop":
			player.remove_from_bag(arg)
			char_sel_uid = -1
		"claim":
			var text := ChallengeService.claim(world, player, arg[0], arg[1])
			if text != "":
				hud.show_banner(text, UI.GOLD)
				Audio.play("quest", 0.0)
				save_game()
	_build_character()


func close_character() -> void:
	hud.clear_screen()
	save_game()
	match char_return:
		State.PLAYING:
			_resume_play()
		State.CITY:
			state = State.CITY
			_build_city()
		State.CAMP:
			state = State.CAMP
			_build_camp()
		_:
			enter_map()


# ======================= Меню =======================

func _open_menu() -> void:
	hud.open_overlay()
	get_tree().paused = true


func _show_main_menu() -> void:
	state = State.MENU
	Audio.play_music("calm")
	hud.set_mode(false, false)
	_open_menu()
	hud.add_title("Козацька Звитяга", 72)
	hud.add_title("З Кремля повзе чорна зараза Путіноїда. Козаче, рушай у похід!", 24, UI.TEXT)
	if SaveSystem.exists(save_path):
		hud.add_button("Продовжити", _continue_game)
		hud.add_button("Нова гра", _confirm_new_game)
	else:
		hud.add_button("Нова гра", new_game)
	_add_sound_toggles(_show_main_menu)
	hud.add_title("Ліва частина екрана — рух, праворуч — удар, перекид і вміння.\nНа мапі обирай міста, дикі місцевості та печери.", 18, Color(0.8, 0.8, 0.8))


func _confirm_new_game() -> void:
	_open_menu()
	hud.add_title("Почати нову гру?", 48)
	hud.add_title("Поточне збереження буде втрачено.", 24, UI.TEXT)
	hud.add_button("Так, нова гра", new_game)
	hud.add_button("Ні", _show_main_menu)


func _show_pause() -> void:
	state = State.PAUSED
	hud.set_mode(false, false)
	_open_menu()
	hud.add_title("Пауза")
	hud.add_button("Продовжити", _resume_play)
	hud.add_button("Козак", func():
		hud.close_overlay()
		state = State.PLAYING
		open_character())
	hud.add_button(("×2 досвіду ще %s" % AdRewards.format_time(AdRewards.xp2_left(world))) if not AdRewards.can_xp2(world) else "Реклама: ×2 досвіду на годину", func(): _watch_xp2(_show_pause))
	var leave_text := "Покинути печеру (прогрес втратиться)" if combat.is_dungeon() else "Повернутися на мапу"
	hud.add_button(leave_text, enter_map)
	_add_sound_toggles(_show_pause)
	hud.add_button("Головне меню", func():
		save_game()
		combat.leave()
		_show_main_menu())


func _add_sound_toggles(refresh: Callable) -> void:
	hud.add_row([
		UI.button("Звук: " + ("так" if Audio.sound_on else "ні"), func():
			Audio.set_sound(not Audio.sound_on)
			_save_settings()
			refresh.call(), Vector2(232, 64), 22),
		UI.button("Музика: " + ("так" if Audio.music_on else "ні"), func():
			Audio.set_music(not Audio.music_on)
			_save_settings()
			refresh.call(), Vector2(232, 64), 22),
	])


func _save_settings() -> void:
	SaveSystem.save_settings({"sound": Audio.sound_on, "music": Audio.music_on})


# ======================= Клавіатура й система =======================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var playing := state == State.PLAYING
	match event.physical_keycode:
		KEY_K, KEY_SHIFT:
			if playing:
				player.dodge()
		KEY_L, KEY_1:
			if playing:
				player.use_skill("whirl")
		KEY_I, KEY_2:
			if playing:
				player.use_skill("lightning")
		KEY_O, KEY_3:
			if playing:
				player.use_skill("musket")
		KEY_H, KEY_4:
			if playing:
				player.use_potion()
		KEY_C, KEY_TAB:
			if state == State.CHARACTER:
				close_character()
			elif playing or state == State.MAP or state == State.CITY or state == State.CAMP:
				open_character()
		KEY_M:
			if playing:
				_try_leave()
		KEY_ESCAPE, KEY_P:
			if playing:
				_show_pause()
			elif state == State.PAUSED:
				_resume_play()
			elif state == State.CHARACTER:
				close_character()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == State.PLAYING:
			_show_pause()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and state == State.CHARACTER:
			close_character()


# ======================= Хутір =======================

func enter_camp() -> void:
	_leave_combat()
	hud.close_overlay()
	state = State.CAMP
	Audio.play_music("calm")
	get_tree().paused = true
	map_here = Camp.CAMP_ID
	player.revive()
	world.revive_companions()
	CampService.apply_effects(world, player)
	hud.show_map(false)
	hud.set_mode(false, false)
	camp_sel_uid = -1
	smith_msg = ""
	_build_camp()
	save_game()
	hint("camp", "Твій хутір! Тут козак і загін відпочивають. Будуй курінь, кузню, зілляварню, склад і пасіку за гривні та ресурси з походів.")


func leave_camp() -> void:
	enter_map()


func _build_camp() -> void:
	hud.set_screen(UiCamp.build(self))


func camp_do(action: String, arg) -> void:
	match action:
		"build":
			if CampService.build(world, player, arg):
				Audio.play("quest", 0.0)
				hud.show_banner("%s: рівень %d!" % [Camp.BUILDINGS[arg]["name"], CampService.level(world, arg)], UI.GOLD)
		"select":
			camp_sel_uid = arg
			smith_msg = ""
		"sharpen":
			_sharpen(arg, CampService.forge_cost_mult(world), CampService.forge_chance_bonus(world))
		"salvage":
			var v := CampService.salvage(world, player, arg)
			if v > 0:
				Audio.play("sharpen_ok", 0.1, -6.0)
				smith_msg = "Переплавлено: +%d заліза" % v
				smith_msg_color = UI.GOOD
				camp_sel_uid = -1
		"brew":
			if CampService.brew(world, player, arg):
				Audio.play("heal", 0.0)
		"collect":
			var g := CampService.collect_pasika(world, player)
			if g > 0:
				Audio.play("coin", 0.0)
				hud.show_banner("Мед продано: +%d грн" % g, UI.GOLD)
		"ad_xp2":
			_watch_xp2(_build_camp)
			return
		"ad_safe":
			Ads.show_rewarded("safe_sharpen", func(ok: bool):
				if ok and AdRewards.grant_safe(world):
					hud.show_banner("Дякуємо! +1 безпечна заточка", UI.GOOD)
				save_game()
				if state == State.CAMP:
					_build_camp())
			return
	save_game()
	_build_camp()


## Реклама за ×2 досвіду; refresh перебудовує поточний екран після перегляду.
func _watch_xp2(refresh: Callable) -> void:
	if not AdRewards.can_xp2(world):
		return
	Ads.show_rewarded("xp2", func(ok: bool):
		if ok:
			AdRewards.grant_xp2(world)
			hud.show_banner("Дякуємо! ×2 досвіду: %s" % AdRewards.format_time(AdRewards.xp2_left(world)), UI.GOOD)
			save_game()
		refresh.call())
