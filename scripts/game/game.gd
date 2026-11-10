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
const CraftService := preload("res://scripts/game/craft_service.gd")
const SpecService := preload("res://scripts/game/spec_service.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const DepthService := preload("res://scripts/game/depth_service.gd")
const TowerService := preload("res://scripts/game/tower_service.gd")
const EventService := preload("res://scripts/game/event_service.gd")
const DuelService := preload("res://scripts/game/duel_service.gd")
const BountyService := preload("res://scripts/game/bounty_service.gd")
const VigilService := preload("res://scripts/game/vigil_service.gd")
const TradeService := preload("res://scripts/game/trade_service.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const TavernService := preload("res://scripts/game/tavern_service.gd")
const GardenService := preload("res://scripts/game/garden_service.gd")
const ExpeditionService := preload("res://scripts/game/expedition_service.gd")
const RecordService := preload("res://scripts/game/record_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")
const Sounds := preload("res://scripts/data/sounds.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const HuntGame := preload("res://scripts/ui/hunt_game.gd")
const FishGame := preload("res://scripts/ui/fish_game.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const EscortService := preload("res://scripts/game/escort_service.gd")
const Acts := preload("res://scripts/data/activities.gd")
const PathService := preload("res://scripts/game/path_service.gd")
const Paths := preload("res://scripts/data/paths.gd")
const AccountScript := preload("res://scripts/game/account.gd")
const ClassesData := preload("res://scripts/data/classes.gd")
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

enum State { MENU, MAP, CITY, CAMP, PLAYING, CHARACTER, PAUSED, DEAD, ACTIVITY }

var state := State.MENU
var player: Player = null
var world = WorldState.new()
var combat: Combat
var hud: Hud
var meta := {"playtime": 0.0, "created": 0.0}
var save_path: String = SaveSystem.SAVE_PATH  # тести підміняють, щоб не чіпати справжнє збереження
var account_path: String = SaveSystem.ACCOUNT_PATH  # тести підміняють
var account := AccountScript.new()  # спільне на всіх персонажів: хутір, скриня, досягнення, виклики
var slot := 1  # активний слот персонажа (1..5)
var use_slots := true  # false у тестах зі своїм save_path

var city_id := ""
var map_here := "sich"
var map_sel := ""

# Стан екранів (читають ui_character.gd та ui_city.gd)
var char_tab := 0
var char_sel_uid := -1
var char_return := State.MAP
var city_tab := 0
var city_sel_uid := -1
var sell_multi := false  # крамниця: режим вибору кількох речей
var sell_marked := {}  # uid -> true
var smith_msg := ""
var smith_msg_color := Color.WHITE
var camp_tab := 0
var craft_tier := 1  # якість у вкладці «Кування»
var confirm_action := ""
var skill_sel := ""
var path_card := "cossack"
# Подорож мапою
var travel_to := ""  # куди їдемо ("" — стоїмо)
var travel_t := 0.0
var travel_dur := 2.0
var travel_boost := 1.0  # дотик по мапі прискорює
var travel_event_at := -1.0  # на якому t чекає пригода (-1 — без пригоди)
var travel_paused := false  # зупинились на пригоду  # яка картка розгорнута на екрані «Дорога»  # вміння, відкрите в картці на вкладці «Вміння»
var depth_sel := 1  # обрана глибина на мапі
var tower_sel := 1  # обраний поверх Башти на мапі
var theft_notice := ""  # крадіжка на хуторі між заходами (показати після завантаження)
var leave_notice := ""  # підсумок бою, який треба показати після виходу з нього (варта тощо)
var dice_anim := {}  # шинок: з якої кості анімувати кидок героя ("mine") і суперника ("theirs"); живе один показ
var holiday_id := ""  # сезонне свято, що йде зараз ("" — будень); оновлюється на порозі мапи, міста й хутора
var camp_sel_uid := -1


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false  # системне «Назад» розбирає go_back(): воно не має мовчки закривати гру посеред бою
	var settings := SaveSystem.load_settings()
	Audio.set_sound(settings["sound"])
	Audio.set_music(settings["music"])

	combat = CombatScript.new()
	add_child(combat)
	combat.autosell = settings.get("autosell", false)
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
	hud.mana_pressed.connect(func(): if state == State.PLAYING: player.use_mana_potion())
	hud.pause_pressed.connect(func():
		if state == State.PLAYING:
			_show_pause()
		elif state == State.MAP:
			_show_map_menu())
	hud.character_pressed.connect(open_character)
	hud.map_pressed.connect(func(): if state == State.PLAYING: _try_leave())
	hud.map_location_selected.connect(_on_map_select)
	hud.map_view.travel_tapped.connect(_travel_speed_up)

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.tower_cleared.connect(_on_tower_cleared)
	Events.tower_next.connect(_on_tower_next)
	Events.treasure_found.connect(func(loc_id: String): EventService.treasure_found(world, loc_id))
	Events.level_up.connect(_on_level_up)
	Events.player_died.connect(_on_player_died)
	Events.companion_down.connect(_on_companion_down)
	Events.companion_revived.connect(func(i: int):
		if i < world.companions.size():
			world.companions[i]["downed"] = false)
	Events.field_cleared.connect(_on_location_cleared)
	Events.dungeon_cleared.connect(_on_dungeon_cleared)
	Events.exit_requested.connect(_on_exit)
	Events.defense_won.connect(_on_defense_won)
	Events.duel_won.connect(_on_duel_won)
	Events.vigil_minute.connect(_on_vigil_minute)
	Events.bounty_killed.connect(func(id: int):
		var m := BountyService.on_kill(world, id)
		if m != "":
			hud.show_banner(m, UI.GOLD)
			_record("bounty_kill"))
	Events.parried.connect(func(): _record("parry"))
	Events.trail_found.connect(func(kind: String):
		_record("trail")
		_record("trail:" + kind))
	Events.holiday_token.connect(_on_holiday_token)
	Events.vii_blinded.connect(func(): _record("vii_blind"))
	Events.job_level_up.connect(func(jl: int):
		_story_event("job", str(jl))
		if player.can_change_class() and player.is_peasant():
			hud.show_banner("Майстерність %d!\nЧас обирати дорогу: Січ чи Карпати" % jl, UI.GOLD)
		elif player.can_change_class() and jl == player.Classes.JOB_CHANGE_AT[1]:
			hud.show_banner("Майстерність %d!\nНаставники на Січі чекають на тебе" % jl, UI.GOLD)
		elif state != State.PLAYING:
			hud.show_banner("Майстерність %d!" % jl, UI.GOLD))
	Events.charged_hit.connect(func(): _record("charged"))
	Events.defense_lost.connect(_on_defense_lost)
	Events.item_found.connect(func(_i): hint("item", "Знайдено річ! Вдягни її: кнопка героя (угорі праворуч) → вкладка «Спорядження»."))
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
	elif state == State.MAP:
		_travel_tick(delta)
	player.xp_boost = AdRewards.xp_mult(world)
	var top := StoryService.objective_line(world)
	for l in HeroService.objective_lines(world):
		top += "\n" + l
	var sl := SpecService.objective_line(world)
	if sl != "":
		top += "\n" + sl
	if AdRewards.xp2_left(world) > 0.0:
		top = "×2 досвіду: %s\n%s" % [AdRewards.format_time(AdRewards.xp2_left(world)), top]
	if holiday_id != "":
		top = "Свято: %s (%s)\n%s" % [Acts.HOLIDAYS[holiday_id]["name"], Acts.HOLIDAYS[holiday_id]["bonus_text"], top]
	hud.update(player, world, _combat_info(), delta, top.strip_edges())


func _combat_info() -> Dictionary:
	if state != State.PLAYING or not combat.active:
		return {}
	var L: Dictionary = combat.loc
	var sub := ""
	if combat.is_vigil():
		sub = "Варта %s / %s  •  Вбито %d" % [VigilService.time_text(combat.vigil_time), VigilService.time_text(float(L["goal"])), combat.vigil_kills]
		if combat.vigil_done:
			sub = "Вистояно! %s  •  Вбито %d  •  портал відкрито" % [VigilService.time_text(combat.vigil_time), combat.vigil_kills]
	elif combat.is_duel():
		var rv = combat.nearest_enemy(player.global_position, 5000.0)
		sub = "Коло %d із %d  •  Суперник: %d%%" % [int(L["round"]) + 1, DuelService.ROUNDS, roundi(100.0 * rv.hp / rv.max_hp) if rv != null else 0]
		if combat.duel_over:
			sub = "Перемога! Портал веде на Січ"
	elif combat.is_defense():
		var gp: int = roundi(100.0 * combat.gate.hp / combat.gate.max_hp) if combat.gate != null and is_instance_valid(combat.gate) else 0
		sub = "Хвиля %d/%d  •  Брама %d%%" % [combat.wave, L["waves"], gp]
		if L.has("escort"):
			sub = "Шлях %d%%  •  %s %d%%" % [roundi(100.0 * combat.escort_part()), combat.gate.label_text() if gp > 0 else "Мандрівник", gp]
		if combat.defense_over and combat.field_cleared:
			sub = "Оборону виграно! Портал веде до брами" if not L.has("escort") else "Довів! Портал веде на мапу"
		elif combat.defense_over and L.has("escort"):
			sub = "Не вберіг. Повертаємось на мапу"
	elif combat.is_tower():
		if combat.field_cleared:
			sub = "Поверх пройдено! Портал веде вище"
		elif combat.tower_boss_spawned:
			sub = "Рівень %d  •  %s" % [L["level"], ("Супербос: %s" % Data.BOSS_NAMES[L["boss"]]) if L["boss"] != "" else L["mini_title"]]
		else:
			sub = "Рівень %d  •  Хвиля %d/%d" % [L["level"], combat.wave, L["waves"]]
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


## Після посвяти: нова зброя з торби — одразу в руки, якщо стара вже не годиться.
func _after_class_change() -> void:
	_sync_class()
	var w: Dictionary = player.equipment.get("weapon", {})
	if not w.is_empty() and player.can_use(w):
		return
	for it in player.inventory:
		if it["slot"] == "weapon" and player.can_use(it):
			player.equip(it["uid"])
			return


## Клас героя впливає на здобич (зброя свого класу) і звертання в розмовах.
func _sync_class() -> void:
	Data.weapon_pool = player.Classes.CLASSES[player.job]["weapons"]
	StoryService.hero_class = "volkhv" if player.Classes.is_volkhv_line(player.job) else player.job


func new_game() -> void:
	world = WorldState.new()
	meta = {"playtime": 0.0, "created": Time.get_unix_time_from_system()}
	_load_account()
	_attach_account()
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


## Вміння з комірки панелі (клавіатура: 1–3 атаки, 5–9 бафи).
func _use_slot(kind: String, i: int) -> void:
	player.sync_panel()
	var arr: Array = player.panel[kind]
	if i < arr.size() and arr[i] != "":
		player.use_skill(arr[i])


## Простий хлопець із хутора: вила, сорочка, лише селянська наука.
func _make_peasant() -> void:
	player.job = "peasant"
	player.job_level = 1
	player.job_xp = 0
	player.rank = ""
	player.skills = {}
	_sync_class()
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
	_save_account()


func _save_account() -> void:
	if account_path == SaveSystem.ACCOUNT_PATH and not use_slots:
		return  # тести без слотів не чіпають справжній акаунт
	var f := FileAccess.open(account_path + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_var(account.to_dict())
	f.close()
	if FileAccess.file_exists(account_path):
		DirAccess.copy_absolute(account_path, account_path + ".bak")
	DirAccess.rename_absolute(account_path + ".tmp", account_path)


func _load_account() -> void:
	account = AccountScript.new()
	if account_path == SaveSystem.ACCOUNT_PATH and not use_slots:
		return  # тести без слотів не читають справжній акаунт
	for p in [account_path, account_path + ".bak"]:
		if FileAccess.file_exists(p):
			var f := FileAccess.open(p, FileAccess.READ)
			if f:
				var d = f.get_var()
				f.close()
				if d is Dictionary and not d.is_empty():
					account.from_dict(d)
					return


## Спільне майно підключається до світу персонажа посиланнями.
func _attach_account() -> void:
	account.absorb_from_world(world)  # старе збереження: забрати хутір і досягнення в акаунт
	account.attach(world)


func load_game() -> bool:
	var d := SaveSystem.load_data(save_path)
	if d.is_empty():
		return false
	world = WorldState.new()
	world.from_dict(d["world"])
	meta = d.get("meta", meta)
	_load_account()
	_attach_account()
	tower_sel = int(TowerService.state(world)["max"])
	depth_sel = int(DepthService.state(world)["max"])
	theft_notice = EventService.check_theft(world, Time.get_unix_time_from_system(), CampService.level(world, "kurin"))
	_new_hero(d["player"])
	_sync_class()
	Party.normalize(world, player.level)
	CampService.apply_effects(world, player)
	return true


func _continue_game() -> void:
	if load_game():
		map_here = world.last_city
		enter_city(world.last_city)
		if meta.get("notice", "") == "classes":
			meta.erase("notice")
			hud.show_banner("Нова система класів! Вміння й Загартування скинуто —\nочки повернуто, розподіли їх заново (кнопка героя)", UI.GOLD)
	else:
		new_game()


# ======================= Режими =======================

func _leave_combat() -> void:
	hud.close_dialogue()
	if combat.active:
		if combat.is_vigil():
			leave_notice = "\n".join(VigilService.finish(world, player, combat.vigil_time, combat.vigil_kills))
		combat.collect_all()
		combat.leave()


func enter_map() -> void:
	var from_trip: bool = combat.active and combat.counts_as_trip()
	_leave_combat()
	hud.clear_screen()
	hud.close_overlay()
	state = State.MAP
	Audio.play_music("map")
	Audio.play_ambient("")
	get_tree().paused = true
	hud.set_mode(true, false)
	hud.pause_btn.visible = true  # на мапі та сама кнопка відкриває привал: звук, головне меню, вихід
	map_menu = false
	hud.show_map(true)
	var mv = hud.map_view
	mv.current = map_here
	mv.focus_on(map_here)
	mv.selected = map_sel
	mv.hero_level = player.level
	mv.targets = world.quest_targets()
	for loc in HeroService.targets(world):
		mv.targets[loc] = true
	var stg := SpecService.target(world)
	if stg != "":
		mv.targets[stg] = true
	for loc in BountyService.targets(world):
		mv.targets[loc] = true
	mv.story_target = StoryService.target(world)
	mv.plague = PlagueService.state(world)["levels"]
	mv.events = EventService.map_marks(world)
	if theft_notice != "":
		hud.show_banner(theft_notice, UI.BAD)
		theft_notice = ""
	var back := _expedition_news()
	if not from_trip and (leave_notice != "" or not back.is_empty()):
		if leave_notice != "":
			back.push_front(leave_notice)
		hud.show_banner("\n".join(back), UI.GOLD)
		leave_notice = ""
	if from_trip:
		var news := []
		if leave_notice != "":
			news.append(leave_notice)
			leave_notice = ""
		news.append_array(back)
		var spread := PlagueService.tick(world)
		if not spread.is_empty():
			news.append("Зараза повзе далі: " + ", ".join(spread))
		news.append_array(DefenseService.tick(world, player))
		news.append_array(EventService.tick(world, player))
		BountyService.tick(world)
		TradeService.tick(world)
		OutdoorService.tick(world)
		TavernService.tick(world)
		mv.events = EventService.map_marks(world)
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
	if city_id != id or Audio.current_music not in ["city", "inn", "festive"]:
		Audio.play("door", 0.05)
	Audio.play_music(_home_music("city"))
	Audio.play_ambient("")
	get_tree().paused = true
	city_id = id
	Data.sell_mult = EventService.sell_mult(world, id)
	map_here = id
	world.last_city = id
	player.revive()
	world.revive_companions()
	hud.show_map(false)
	hud.set_mode(false, false)
	city_sel_uid = -1
	sell_multi = false
	sell_marked.clear()
	smith_msg = ""
	var back := _expedition_news(true)
	_build_city()
	if not back.is_empty():
		hud.show_banner("\n".join(back), UI.GOLD)
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
	var extra := EventService.mods_for(world, id)
	extra.merge(BountyService.mods_for(world, id, player))
	combat.enter(id, _party_data(), PlagueService.level(world, id), extra)
	hud.set_mode(true, true)
	state = State.PLAYING
	get_tree().paused = false
	Audio.play_music("boss" if combat.is_duel() else "battle")
	Audio.play_ambient(Sounds.ambient_for(str(combat.loc.get("biome", "")), combat.is_vigil() or bool(combat.loc.get("night", false))))
	Audio.play("unsheathe", 0.05)
	hint("combat", "Ліва частина екрана — рух. Тримай «Удар» — козак сам б'є найближчу нечисть. Коли ворог червоніє — він замахується: тисни «Перекид»!")


func _try_leave() -> void:
	if combat.is_duel() and not combat.duel_over:
		hud.show_banner("З майдану не тікають. Здатися можна в паузі.", UI.BAD)
		return
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
	_spec_event("kill", e.kind)
	if e.elite:
		_spec_event("elite", "")
	if e.elite:
		_record("elite")
	if e.is_boss:
		_record("boss")
		_record("boss:" + e.kind)
		var stone_msgs := StoneService.on_boss(player, e.kind, int(world.stats.get("boss:" + e.kind, 0)) == 1)
		if not stone_msgs.is_empty():
			combat.float_text(player.global_position + Vector2(0, -150), "\n".join(stone_msgs), Color(0.85, 0.7, 1.0))
			hint("stones", "Камінь долі! Його можна використати у вікні героя, вкладка «Вміння»: Камінь забуття скидає очки, Алатир-камінь змінює дорогу.")
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


## Розмова з представником дороги (екран «Дорога» на Січі).
func _path_talk(cls: String) -> void:
	var dlg = DialogueScript.new()
	dlg.setup(StoryService.lines(world, PathService.talk_lines(cls)), [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		PathService.mark_talked(world, cls)
		path_card = cls
		save_game()
		if state == State.CITY:
			_build_city())
	hud.show_dialogue(dlg)


## Остаточний вибір дороги: сюжет іде далі гілкою козака або волхва.
func _path_choose(cls: String) -> void:
	var msgs := PathService.choose(world, player, cls)
	if msgs.is_empty():
		return
	Audio.play("quest", 0.0)
	hud.show_banner("Дорогу обрано: %s!" % Paths.CARDS[cls]["title"], UI.GOLD)
	save_game()
	if state == State.CITY:
		city_tab = 0
		_build_city()
		_story_dialogue(city_id)  # кошовий одразу дає посвяту або лист до Велемира


## Посвята в спеціалізацію після випробування.
func _spec_dialogue(city: String) -> void:
	var d := SpecService.city_dialogue(world, city)
	if d.is_empty():
		return
	var dlg = DialogueScript.new()
	dlg.setup(d["lines"], [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		var text := SpecService.complete(world, player)
		_after_class_change()
		CampService.apply_effects(world, player)
		if text != "":
			hud.show_banner(text, UI.GOLD)
			Audio.play("levelup", 0.0)
			_record("spec")
		save_game()
		if state == State.CITY and city_id == city:
			_build_city())
	hud.show_dialogue(dlg)


## Почати випробування: наставник пояснює, що робити.
func _start_trial(spec: String) -> void:
	if not SpecService.start(world, player, spec):
		return
	var dlg = DialogueScript.new()
	dlg.setup(SpecService.TRIALS[spec]["start"], [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		hud.show_banner("◆ " + SpecService.objective(world)["text"], UI.GOLD)
		save_game()
		if state == State.CITY:
			_build_city())
	hud.show_dialogue(dlg)


func _spec_event(type: String, arg: String) -> void:
	for m in SpecService.on_event(world, type, arg):
		hud.show_banner(m["text"], UI.GOLD)
		Audio.play("quest", 0.0)


## Загін для бою: записи світу + сила, ім'я й колір побратимів.
func _party_data() -> Array:
	var out := []
	for i in world.companions.size():
		var c: Dictionary = world.companions[i]
		if ExpeditionService.away(c):
			continue  # у власному поході — в бою його нема
		var d: Dictionary = c.duplicate()
		d["index"] = i  # місце в загоні (а не в списку тих, хто пішов у бій)
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
		_spec_dialogue(city)  # побратими мовчать — може, наставник чекає на посвяту
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
		_after_class_change()
		_story_event("job", str(player.job_level))  # мета «майстерність» могла вже бути досягнута
		if player.rank == "hetman" and int(world.stats.get("hetman", 0)) == 0:
			_record("hetman")
			hint("depths_open", "Під Кремлем відкрилися Глибини зарази — печера без дна для найсильніших. Шукай на мапі біля Москви.")
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
	_spec_event("clear", loc_id)
	_story_event("clear", loc_id)
	_hero_event("clear", loc_id)


func _on_dungeon_cleared(loc_id: String) -> void:
	world.on_dungeon(loc_id)
	if loc_id == DepthService.LOC_ID and combat.loc.has("depth"):
		var d: int = combat.loc["depth"]
		hud.show_banner(DepthService.on_clear(world, d), UI.GOLD)
		depth_sel = int(DepthService.state(world)["max"])
		_record("depth", d)
		if randf() < 0.15 + 0.005 * d:
			StoneService.grant(player, "zabuttia" if randf() < 0.6 else "alatyr")
			combat.float_text(player.global_position + Vector2(0, -150), "Камінь долі з глибин!", Color(0.85, 0.7, 1.0))
	_cleanse(loc_id)
	_record("dungeon")
	_spec_event("dungeon", loc_id)
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
	hud.show_banner("Рівень %d!\nВідкрий «%s», щоб прокачатися" % [lvl, player.class_name_ua()], UI.GOLD)
	hint("levelup", "Новий рівень! Натисни кнопку героя угорі праворуч: вклади очки в характеристики, вміння й перки.")


func _on_player_died() -> void:
	if combat.is_duel():
		_duel_lost()
		return
	if combat.is_vigil():
		_soft_defeat("Варту знято: нечисть прорвалась.\nПобратими винесли тебе з могили.", world.last_city)
		return
	if combat.is_defense() and not combat.defense_over:
		combat.defense_over = true
		var ev := EventService.battle_at(world, combat.loc["target"])
		if combat.loc.has("escort"):
			pass  # супровід: завдання лишається, місто нічого не втрачає
		elif combat.loc.get("ambush", false):
			hud.show_banner(TradeService.lose_half(world), UI.BAD)
		elif not ev.is_empty():
			hud.show_banner(EventService.lose(world, player, ev), UI.BAD)
		else:
			hud.show_banner(DefenseService.lose(world, player, combat.loc["target"]), UI.BAD)
	state = State.DEAD
	Audio.jingle("defeat")
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
	if travel_to != "":
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.add_child(UI.label("У дорозі", 28, UI.GOLD, false))
		var l := UI.label("Їдемо: %s. Торкнись мапи, щоб поквапитись." % Data.place_name(travel_to), 18, UI.TEXT, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		hud.set_map_panel(v)
		return
	if map_sel == DepthService.LOC_ID:
		hud.set_map_panel(MapPanel.build_depths(world, player, depth_sel, func(d: int):
			depth_sel = d
			_build_map_panel(), start_depth))
		return
	if map_sel == TowerService.LOC_ID:
		hud.set_map_panel(MapPanel.build_tower(world, player, tower_sel, func(f: int):
			tower_sel = f
			_build_map_panel(), start_tower))
		return
	if Acts.SPOTS.has(map_sel):
		hud.set_map_panel(MapPanel.build_spot(map_sel, world, player, _go_to))
		return
	var panel := MapPanel.build(map_sel, world, player, _go_to, StoryService.target(world), StoryService.objective_line(world), _go_escort)
	if map_sel == "":
		var left := AdRewards.xp2_left(world)
		var gift := UI.label(("×2 досвіду ще %s" % AdRewards.format_time(left)) if left > 0.0 else "Подарунок спонсора: ×2 досвіду на годину гри", 17, UI.GOLD, false)
		gift.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # довгий рядок не має розпирати панель за край екрана
		panel.add_child(gift)
		panel.add_child(UI.button("Переглянути рекламу", func(): _watch_xp2(_build_map_panel), Vector2(350, 56), 18, AdRewards.can_xp2(world)))
	hud.set_map_panel(panel)


## Кнопка «Вирушити» на мапі: спершу поїздка фігуркою, прибуття — у _arrive.
## Вирушити з мандрівником: завдання міста на супровід у цій місцевості.
func _go_escort(id: String) -> void:
	_go_to(id, true)


func _go_to(id: String, escort: bool = false) -> void:
	if travel_to != "":
		return  # уже їдемо
	escort_go = id if escort else ""
	if id == map_here:
		_arrive(id)
		return
	var a: Vector2 = hud.map_view._place_ll(map_here)
	var b: Vector2 = hud.map_view._place_ll(id)
	var dist: float = a.distance_to(b)  # градуси; Січ–Київ ≈ 5.3
	travel_to = id
	travel_t = 0.0
	travel_dur = clampf(1.2 + dist * 0.45, 1.5, 4.0) / (1.0 + 0.15 * player.pk("h_horse"))
	travel_boost = 1.0
	travel_paused = false
	# Пригода в дорозі — посеред шляху (не для селянина, не частіше ніж дозволяє TravelService)
	travel_event_at = -1.0
	if not Data.CITIES.has(id) and id != Camp.CAMP_ID and id != DepthService.LOC_ID and id != TowerService.LOC_ID and not Acts.SPOTS.has(id) and not DefenseService.is_besieged(world, id) and EventService.battle_at(world, id).is_empty():
		pending_event = TravelService.roll(world, player)
		if not pending_event.is_empty():
			travel_event_at = randf_range(0.4, 0.65)
	hud.map_view.travel = {"from": map_here, "to": id, "t": 0.0}
	hud.map_view.selected = ""
	_build_map_panel()
	Audio.play("portal", 0.1, -8.0)


var pending_event := {}
var escort_go := ""  # куди їдемо саме заради супроводу (кнопка «Провести» на мапі)


## Прибуття: те, що раніше робив _go_to одразу.
func _arrive(id: String) -> void:
	travel_to = ""
	hud.map_view.travel = {}
	var escort_q: Dictionary = EscortService.at(world, id) if escort_go == id else {}
	escort_go = ""
	var ev := EventService.battle_at(world, id)
	if not ev.is_empty():
		start_event(ev)  # подія чекає саме тут: набіг, валка, бранці...
	elif DefenseService.is_besieged(world, id):
		start_defense(id)  # обложене місто чи хутір — спершу бій біля брами
	elif id == Camp.CAMP_ID:
		enter_camp()
	elif id == DepthService.LOC_ID:
		start_depth(depth_sel)
	elif id == TowerService.LOC_ID:
		start_tower(tower_sel)
	elif Acts.SPOTS.has(id):
		enter_spot(id)
	elif Data.CITIES.has(id):
		if id != world.last_city and TradeService.should_ambush(world):
			start_ambush(id)  # на валку з крамом напали дорогою
		else:
			enter_city(id)
	elif not escort_q.is_empty():
		start_escort(escort_q)  # завдання міста: провести мандрівника
	else:
		enter_location(id)


## Крок подорожі (викликається з _process, коли ми на мапі й їдемо).
func _travel_tick(delta: float) -> void:
	if travel_to == "" or travel_paused:
		return
	travel_t += delta / travel_dur * travel_boost
	hud.map_view.travel["t"] = travel_t
	if travel_event_at > 0.0 and travel_t >= travel_event_at:
		travel_event_at = -1.0
		travel_paused = true
		_show_travel_event(pending_event, func():
			travel_paused = false)
		return
	if travel_t >= 1.0:
		map_here = travel_to
		_arrive(travel_to)


## Дотик по мапі під час поїздки — їхати втричі швидше.
func _travel_speed_up() -> void:
	if travel_to != "":
		travel_boost = 3.0


## Пригода посеред шляху: діалог із вибором, потім дорога продовжується.
func _show_travel_event(ev: Dictionary, on_done: Callable) -> void:
	var dlg = DialogueScript.new()
	dlg.setup(ev["lines"], ev["choices"])
	dlg.finished.connect(func(choice: int):
		hud.close_dialogue()
		if choice >= 0 and choice < ev["choices"].size():
			var summary := TravelService.apply(world, player, ev["choices"][choice]["outcome"])
			_record("travel")
			if summary != "":
				hud.show_banner(summary, UI.GOLD)
		save_game()
		on_done.call())
	hud.show_dialogue(dlg)


# ======================= Глибини зарази =======================

func start_depth(depth: int) -> void:
	if not DepthService.unlocked(world):
		hud.show_banner("Глибини відкриються після перемоги над Путіноїдом", UI.BAD)
		return
	depth = clampi(depth, 1, int(DepthService.state(world)["max"]))
	combat.custom_loc = DepthService.loc_for(depth)
	enter_location(DepthService.LOC_ID)
	hint("depths", "Глибини зарази: що глибше — то сильніші вороги й щедріша здобич. Пройдеш глибину — відкриється наступна.")


# ======================= Башта Кощія =======================

func start_tower(floor_: int) -> void:
	if not TowerService.unlocked(player):
		hud.show_banner("Башта відкриється з %d-го рівня героя" % TowerService.OPEN_LEVEL, UI.BAD)
		return
	floor_ = clampi(floor_, 1, int(TowerService.state(world)["max"]))
	tower_sel = floor_
	combat.custom_loc = TowerService.loc_for(floor_)
	enter_location(TowerService.LOC_ID)
	hint("tower", "Башта Кощія: кожен поверх — хвилі нечисті й міні-бос, кожен п'ятий — супербос. Пройшов поверх — портал веде вище; вийти можна кнопкою «На мапу», коли поруч нема ворогів.")


func _on_tower_cleared(floor_: int) -> void:
	var r := TowerService.on_clear(world, floor_)
	var first: bool = r[1]
	var msg: String = r[0]
	tower_sel = clampi(floor_ + 1, 1, int(TowerService.state(world)["max"]))
	_record("tower", floor_)
	var lvl := TowerService.level_of(floor_)
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	if first:
		var g := TowerService.first_gold(floor_)
		player.add_gold(g)
		msg += "\n+%d грн за перше проходження" % g
		if TowerService.is_super(floor_):
			var stone := "alatyr" if randf() < 0.4 else "zabuttia"
			StoneService.grant(player, stone)
			combat.spawn_pickup(pos, "item", 0, Data.gen_item(lvl + 1, 3))
			combat.float_text(pos + Vector2(0, -40), "Знайдено: %s!" % StoneService.NAMES[stone], Color(0.85, 0.7, 1.0))
			msg += "\nЛегендарна річ і камінь долі!"
		else:
			combat.spawn_pickup(pos, "item", 0, Data.gen_item(lvl, Data.roll_rarity(lvl, 1)))
	combat._resource_bundle(pos, 3 + floor_ / 5)
	hud.show_banner(msg, UI.GOLD)
	save_game()


func _on_tower_next(floor_: int) -> void:
	var nxt := floor_ + 1
	if nxt > int(TowerService.state(world)["max"]):
		return
	tower_sel = nxt
	combat.next_floor(TowerService.loc_for(nxt))


# ======================= Оборона =======================

var defense_target := ""  # куди повернутися після виграної оборони


## Бій біля брами обложеного міста чи хутора.
func start_defense(target: String) -> void:
	combat.defense_loc = DefenseService.battle_loc(world, target, player)
	enter_location("defense")
	map_here = target
	hint("defense", "Облога! Нечисть іде хвилями й ламає браму внизу. Стань між ними та брамою — коли брама впаде, оборону програно.")


# ======================= Герць на майдані =======================

func start_duel() -> void:
	if not DuelService.can_fight(world, player):
		hud.show_banner("На майдан зараз не вийти", UI.BAD)
		return
	combat.defense_loc = DuelService.battle_loc(world, player)
	enter_location("duel")
	map_here = "sich"
	hint("duel", "Герць — сам на сам. Червоні зони на землі показують, куди вдарить суперник: виходь із них або відбивай «Блоком». Смерті на майдані нема.")


func _on_duel_won() -> void:
	defense_target = "sich"  # з порталу — назад на Січ
	var msgs := DuelService.win(world, player)
	hud.show_banner("\n".join(msgs), UI.GOLD)
	_record("duel")
	if DuelService.is_champion(world):
		_record("duel_champion")
	save_game()


## Поразка чи здача в герці: без втрат, лише мінус спроба; повертаємось на Січ.
func _duel_lost() -> void:
	_soft_defeat(DuelService.lose(world), "sich")


## Поразка без втрат (герць, варта): показати повідомлення й за мить отямитись у місті.
func _soft_defeat(text: String, city: String) -> void:
	hud.close_overlay()
	hud.show_banner(text, UI.BAD)
	state = State.DEAD
	hud.set_mode(true, false)
	get_tree().paused = false
	await get_tree().create_timer(1.6).timeout
	if state == State.DEAD:
		enter_city(city)
		if leave_notice != "":
			hud.show_banner(leave_notice, UI.GOLD)
			leave_notice = ""


## Музика мирного місця: у свято — святкова, інакше своя (city / camp).
func _home_music(usual: String) -> String:
	return "festive" if HolidayService.active() != "" else usual


## Вкладку міста змінено: у корчмі й шинку грає своя мелодія.
func city_tab_changed(title: String) -> void:
	if state != State.CITY:
		return
	Audio.play_music("inn" if title in ["Корчма", "Шинок"] else _home_music("city"))


## Сезонне свято: надбавки герою й привітання (раз на свято). Повертає текст привітання або "".
func _apply_holiday() -> String:
	holiday_id = HolidayService.active()
	var mods := HolidayService.player_mods()
	if mods != player.festive:
		var part: float = player.hp / maxf(1.0, player.max_hp)
		player.festive = mods
		player.recalc()
		player.hp = minf(player.max_hp, player.max_hp * part)
	return HolidayService.greeting(world)


## Жетони свята з убитого ворога: у спільну скарбничку акаунта, напис над місцем, підказка про нагороду.
func _on_holiday_token(amount: int, pos: Vector2) -> void:
	var id := HolidayService.active()
	if id == "":
		return
	var before := HolidayService.tokens(world)
	var now_n := HolidayService.add_tokens(world, amount)
	var H: Dictionary = Acts.HOLIDAYS[id]
	combat.float_text(pos + Vector2(0, -70), "+%d %s" % [amount, H["token"]], Color(1.0, 0.85, 0.5))
	_record("holiday_token", amount)
	for tier in HolidayService.tiers(id):
		if before < int(tier) and now_n >= int(tier):
			hud.show_banner("%s: зібрано %d жетонів!\nНагорода чекає у вкладці «Свята»" % [H["name"], now_n], UI.GOLD)
			Audio.play("quest", 0.0)


## Новини на порозі (мапа, місто, хутір): свято, супутники, що повернулися з власних походів, і побиті рекорди роду.
func _expedition_news(healed: bool = false) -> Array:
	var msgs := []
	var hello := _apply_holiday()
	if hello != "":
		msgs.append(hello)
	msgs.append_array(ExpeditionService.collect(world, player, -1, healed))
	var came: int = msgs.size() - (1 if hello != "" else 0)
	if came > 0:
		Audio.play("quest", 0.0)
		msgs.append_array(ChallengeService.record(world, player, "expedition", came))
	var recs := RecordService.sync(world, player, slot)
	if not recs.is_empty():
		Audio.play("quest", 0.0)
		msgs.append_array(recs)
	msgs.append_array(ChallengeService.record(world, player, "glory", GloryService.glory(world)))
	return msgs


## Партію в кості розсуджено: звук, лічильники для досягнень.
func _dice_done() -> void:
	var dg := TavernService.game(world)
	_record("dice")
	# Звук підсумку — коли кості вже лягли, а не поперед них
	var DiceRow = load("res://scripts/ui/dice_row.gd")
	var wait: float = DiceRow.roll_time(dg["theirs"].size() if dice_anim.has("theirs") else 1) + 0.1
	var result := str(dg["result"])
	get_tree().create_timer(wait).timeout.connect(func():
		if result == "win":
			Audio.play("quest", 0.0)
		elif result == "lose":
			Audio.play("sharpen_fail", 0.1, -4.0))
	match result:
		"win":
			_record("dice_win")
			if dg.get("twelve", false):
				_record("dice_12")


# ======================= Місця занять на мапі =======================

func enter_spot(id: String) -> void:
	map_here = id
	match str(Acts.SPOTS[id]["kind"]):
		"vigil":
			start_vigil()
		"hunt":
			start_hunt()
		"fish":
			start_fishing()
		_:
			enter_map()


# ======================= Полювання й рибалка =======================

## Чому зараз не можна полювати чи рибалити ("" — можна).
func _outdoor_block(kind: String) -> String:
	var S: Dictionary = Acts.SPOTS[kind]
	if player.level < int(S["level"]):
		return "%s: відкриється з %d-го рівня" % [S["name"], int(S["level"])]
	if not OutdoorService.ready(world, kind):
		return "Звір сполоханий. Повернеться після походу" if kind == "hunt" else "Риба сьогодні вже не клює. Повернеться після походу"
	return ""


## Тихе заняття на весь екран (мініігра): бій не йде, мапа схована.
func _open_activity(c: Control) -> void:
	_leave_combat()
	hud.close_overlay()
	state = State.ACTIVITY
	Audio.play_music("map")
	get_tree().paused = true
	hud.show_map(false)
	hud.set_mode(false, false)
	hud.set_screen(c)


## Лист героя для мирних занять: «hunter» — з луком, «plain» — без зброї (вудку домальовує мініігра).
func _peace_sheet(kind: String) -> String:
	var id := "%s_%s" % [kind, player.job]
	return id if Gfx.has(id) else player.sprite_id()


## Кнопка «Назад» на телефоні чи Esc посеред мініігри — те саме, що «Досить».
func _quit_activity() -> void:
	if state == State.ACTIVITY and hud.screen_root != null and hud.screen_root.has_method("_finish"):
		hud.screen_root._finish()


func start_hunt() -> void:
	var why := _outdoor_block("hunt")
	if why != "":
		hud.show_banner(why, UI.BAD)
		enter_map()
		return
	Audio.play_ambient("forest")
	_open_activity(HuntGame.new().setup(OutdoorService.new_hunt(player, -1, OutdoorService.rich(world, "hunt")), _peace_sheet("hunter"), finish_hunt))
	hint("hunt", "Полювання: звірі перебігають галявину. Торкнись звіра, щоб пустити стрілу. Стріл мало, тож бий напевно. Вепра бери в серцевину або двома стрілами.")


func finish_hunt(h: Dictionary) -> void:
	if state != State.ACTIVITY:
		return
	if int(h["shots"]) == 0:
		enter_map()  # передумав і не стріляв: звіра не сполохано
		return
	var msgs := OutdoorService.finish_hunt(world, player, h)
	msgs.append_array(ChallengeService.record(world, player, "hunt", 1))
	if int(h["meat"]) > 0:
		msgs.append_array(ChallengeService.record(world, player, "meat", int(h["meat"])))
	leave_notice = "\n".join(msgs)
	enter_map()


func start_fishing() -> void:
	var why := _outdoor_block("fish")
	if why != "":
		hud.show_banner(why, UI.BAD)
		enter_map()
		return
	Audio.play_ambient("river")
	_open_activity(FishGame.new().setup(OutdoorService.new_fishing(-1, OutdoorService.rich(world, "fish")), _peace_sheet("plain"), finish_fishing))
	hint("fish", "Рибалка: закинь вудку й чекай. Заклювало — тисни «Підсікти». Далі тримай кнопку, щоб тягти, й відпускай, щоб попустити: натяг має бути в зеленій смузі.")


func finish_fishing(f: Dictionary) -> void:
	if state != State.ACTIVITY:
		return
	if int(f["bait"]) >= Acts.FISH_BAIT:
		enter_map()  # вудку так і не закинув: риба не сполохана
		return
	var msgs := OutdoorService.finish_fishing(world, player, f)
	msgs.append_array(ChallengeService.record(world, player, "fishing", 1))
	if int(f["ryba"]) > 0:
		msgs.append_array(ChallengeService.record(world, player, "ryba", int(f["ryba"])))
	if "som" in f["caught"]:
		msgs.append_array(ChallengeService.record(world, player, "som", 1))
	leave_notice = "\n".join(msgs)
	enter_map()


# ======================= Козацька варта =======================

func start_vigil() -> void:
	if not VigilService.unlocked(player):
		hud.show_banner("На варту беруть із %d-го рівня й лише тих, хто обрав дорогу" % int(Acts.SPOTS[VigilService.SPOT_ID]["level"]), UI.BAD)
		return
	combat.defense_loc = VigilService.battle_loc(player)
	enter_location("vigil")
	map_here = VigilService.SPOT_ID
	hint("vigil", "Варта: нечисть суне без упину й щохвилини лютішає. Вистій п'ять хвилин — відкриється портал. Можна стояти й далі, на рекорд. Смерті на варті нема.")


func _on_vigil_minute(m: int) -> void:
	var r := VigilService.on_minute(world, player, m)
	var goal_min := int(Acts.VIGIL_GOAL / 60.0)
	var text := "Хвилина %d вистояна!" % m
	if m == goal_min:
		text = "Варту вистояно!\nПортал відкрито — або стій далі, на рекорд"
	if r["paid"]:
		text += "\n+%d грн, +%d слави" % [r["gold"], r["glory"]]
		var pos: Vector2 = player.global_position + Vector2(0, -110)
		if int(r["item"]) >= 0:
			combat.spawn_pickup(pos, "item", 0, Data.gen_item(player.level, int(r["item"])))
		for msg in r["msgs"]:
			text += "\n" + msg
	elif m <= goal_min:
		text += "\n(нагороду за цю хвилину сьогодні вже взято)"
	hud.show_banner(text, UI.GOLD)
	_record("vigil", m)
	save_game()


## Бій події (набіг, валка, облога Січі, полон, поранений) — як оборона, але з іншою «брамою».
func start_event(ev: Dictionary) -> void:
	combat.defense_loc = EventService.battle_loc(world, ev, player)
	enter_location("defense")
	map_here = ev["target"]
	hint("event_" + ev["kind"], {"village_raid": "Набіг: нечисть палить хати. Стань між нею і селом — коли хати згорять, село втрачено.",
		"caravan": "Валка: вози повільно їдуть ареною, нечисть ламає їх. Відбий усі хвилі; що більше возів уціліє, то більша нагорода.",
		"sich_siege": "Велика облога: шість хвиль і ватажок. Якщо брама впаде, Січ зачиниться, поки не відіб'єш.",
		"captives": "Бранці прив'язані посередині. Відбий три хвилі — і вони вільні.",
		"wounded": "Поранений лежить посередині. Три хвилі — і він урятований."}[ev["kind"]])


## Супровід мандрівника (завдання міста): оборона, де замість брами — людина, що сама йде ареною.
func start_escort(q: Dictionary) -> void:
	combat.defense_loc = EscortService.battle_loc(q)
	enter_location("defense")
	map_here = q["loc"]
	hint("escort", "Супровід: мандрівник сам іде через арену. Коли нечисть поруч, він стоїть і чекає. На шляху три засідки. Тримайся поруч і не дай його скривдити.")


## Напад на валку з крамом дорогою до міста: відбий три хвилі й вбережи вози.
func start_ambush(city: String) -> void:
	combat.defense_loc = TradeService.battle_loc(world, city, player)
	enter_location("defense")
	map_here = city
	hud.show_banner("На валку напали!\nВбережи вози з крамом", UI.BAD)
	hint("ambush", "Нечисть напала на твою валку. Відбий три хвилі: якщо вози розіб'ють, половина краму пропаде.")


func _on_defense_won(target: String) -> void:
	if combat.loc.has("escort"):
		defense_target = ""  # з порталу — на мапу; нагорода за завдання чекає в місті
		var whole: float = combat.gate.hp / maxf(combat.gate.max_hp, 1.0) if combat.gate != null and is_instance_valid(combat.gate) else 1.0
		hud.show_banner(EscortService.win(world, player, int(combat.loc["escort"]), whole), UI.GOLD)
		_record("escort")
		if whole >= 1.0:
			_record("escort_clean")
		save_game()
		return
	if combat.loc.get("ambush", false):
		defense_target = target  # з порталу — у місто, куди їхав
		hud.show_banner("Напад відбито! Крам цілий.", UI.GOLD)
		_record("ambush")
		save_game()
		return
	var ev := EventService.battle_at(world, target)
	if not ev.is_empty():
		defense_target = ""  # з порталу — на мапу
		var part: float = combat.gate.hp / maxf(combat.gate.max_hp, 1.0) if combat.gate != null and is_instance_valid(combat.gate) else 1.0
		hud.show_banner(EventService.win(world, player, ev, part), UI.GOLD)
		_record("event")
		_record("event:" + ev["kind"])
		save_game()
		return
	defense_target = target
	hud.show_banner(DefenseService.win(world, player, target), UI.GOLD)
	_record("defense")
	save_game()


func _on_defense_lost(target: String) -> void:
	if combat.loc.has("escort"):
		hud.show_banner(EscortService.lose(world, int(combat.loc["escort"])), UI.BAD)
		await get_tree().create_timer(2.5).timeout
		if state == State.PLAYING and combat.is_defense():
			enter_map()
		return
	if combat.loc.get("ambush", false):
		hud.show_banner(TradeService.lose_half(world), UI.BAD)
		save_game()
		await get_tree().create_timer(2.5).timeout
		if state == State.PLAYING and combat.is_defense():
			enter_city(target)
		return
	var ev := EventService.battle_at(world, target)
	if not ev.is_empty():
		hud.show_banner(EventService.lose(world, player, ev), UI.BAD)
		save_game()
		await get_tree().create_timer(2.5).timeout
		if state == State.PLAYING and combat.is_defense():
			enter_map()
		return
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
## Миттєвий похід без поїздки (для старих викликів і тестів).
func _travel_to(id: String) -> void:
	map_here = id
	_arrive(id)


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
		"dice_start":
			if TavernService.start(world, player, arg):
				dice_anim = {"mine": 0}
		"dice_roll":
			var dr := TavernService.roll(world, player)
			if dr != "":
				dice_anim = {"mine": TavernService.game(world)["mine"].size() - 1}
				if dr == "bust":
					_dice_done()
		"dice_stand":
			if TavernService.stand(world, player) != "":
				dice_anim = {"theirs": 0}
				_dice_done()
		"dice_clear":
			TavernService.clear(world)
		"rumor":
			var rumor := TavernService.buy_rumor(world, player, city_id)
			if rumor != "":
				Audio.play("quest", 0.0)
				hud.show_banner("Чутка!", UI.GOLD)
				_record("rumor")
		"buy":
			if CityService.buy(world, player, city_id, arg):
				Audio.play("coins", 0.05)
		"sell":
			CityService.sell(player, arg)
			city_sel_uid = -1
		"sell_junk":
			CityService.sell_junk(player)
		"sell_upto":
			var got := CityService.sell_up_to(player, arg)
			if got > 0:
				Audio.play("coins", 0.05)
				hud.show_banner("Продано: +%d грн" % got, UI.GOLD)
			sell_marked.clear()
		"sell_multi":
			sell_multi = not sell_multi
			sell_marked.clear()
			city_sel_uid = -1
		"mark":
			if sell_marked.has(arg):
				sell_marked.erase(arg)
			else:
				sell_marked[arg] = true
		"sell_marked":
			var got := CityService.sell_many(player, sell_marked.keys())
			if got > 0:
				Audio.play("coins", 0.05)
				hud.show_banner("Продано: +%d грн" % got, UI.GOLD)
			sell_marked.clear()
		"autosell":
			combat.autosell = not combat.autosell
			_save_settings()
		"sharpen":
			_sharpen(arg)
		"hire":
			CityService.hire(world, player, city_id, arg)
		"buy_potion":
			if CityService.buy_potion(world, player, city_id):
				Audio.play("coins", 0.05)
		"buy_mana_potion":
			if CityService.buy_mana_potion(world, player, city_id):
				Audio.play("coins", 0.05)
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
		"exp_send":
			if ExpeditionService.send(world, arg[0], arg[1]):
				Audio.play("quest", 0.0)
				hud.show_banner("%s вирушає: %s" % [HeroService.member_name(world.companions[arg[0]]), str(Acts.EXPEDITIONS[arg[1]]["name"]).to_lower()], UI.GOLD)
				_record("expedition_sent")
		"exp_recall":
			ExpeditionService.recall(world, arg)
		"spec_start":
			_start_trial(arg)
			return
		"path_talk":
			_path_talk(arg)
			return
		"path_choose":
			if confirm_action != "path_choose:" + arg:
				confirm_action = "path_choose:" + arg
			else:
				confirm_action = ""
				_path_choose(arg)
		"path_card":
			path_card = arg
		"hero_join":
			for m in HeroService.join(world, player, arg):
				hud.show_banner(m["text"], UI.GOLD)
		"duel_start":
			start_duel()
			return
		"trade_buy":
			if TradeService.buy(world, player, city_id, arg[0], arg[1]) > 0:
				Audio.play("coin", 0.0)
		"trade_sell":
			var tr := TradeService.sell(world, player, city_id, arg[0], arg[1])
			if int(tr["n"]) > 0:
				Audio.play("coin", 0.0)
				hud.show_banner("Продано %d од.: +%d грн (зиск %s%d)" % [tr["n"], tr["gold"], "+" if int(tr["profit"]) >= 0 else "", tr["profit"]], UI.GOLD if int(tr["profit"]) >= 0 else UI.BAD)
				if int(tr["profit"]) > 0:
					_record("trade_profit", int(tr["profit"]))
				_record("trade_sold", int(tr["n"]))
		"bounty_take":
			BountyService.take(world, city_id, arg, player)
		"bounty_drop":
			BountyService.drop(world, arg)
		"bounty_turn_in":
			var bm := BountyService.turn_in(world, player, arg)
			if not bm.is_empty():
				Audio.play("quest", 0.0)
				hud.show_banner("\n".join(bm), UI.GOLD)
				_record("bounty")
	save_game()
	_build_city()
	dice_anim = {}  # анімація кидка стосується лише цього показу


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
	if state == State.PLAYING and combat.is_duel() and not combat.duel_over:
		hud.show_banner("Під час герцю не до торби", UI.BAD)
		return
	if state == State.CHARACTER or player == null:
		return
	if not (state == State.PLAYING or state == State.MAP or state == State.CITY or state == State.CAMP):
		return
	char_return = state
	confirm_action = ""
	state = State.CHARACTER
	get_tree().paused = true
	hud.show_map(false)
	hud.set_mode(false, false)
	char_sel_uid = -1
	Audio.play("page", 0.08)
	RecordService.sync(world, player, slot)  # щоб вкладка «Слава» показувала свіже
	_build_character()


func _build_character() -> void:
	hud.set_screen(UiCharacter.build(self))


func char_do(action: String, arg) -> void:
	if not action.begins_with("stone_"):
		confirm_action = ""
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
		"stone_reset":
			if confirm_action != "stone_reset":
				confirm_action = "stone_reset"
			elif StoneService.reset_points(player):
				confirm_action = ""
				hud.show_banner("Камінь забуття: очки повернуто — розподіли їх заново", Color(0.85, 0.7, 1.0))
				save_game()
		"stone_path":
			if confirm_action != "stone_path:" + arg:
				confirm_action = "stone_path:" + arg
			elif StoneService.change_path(player, arg):
				confirm_action = ""
				_after_class_change()
				hud.show_banner("Алатир-камінь: тепер ти — %s!" % player.class_name_ua().to_lower(), Color(0.85, 0.7, 1.0))
				save_game()
		"skill_pick":
			skill_sel = arg
		"panel_set":
			# arg: [kind, index, id]
			player.set_panel(arg[0], arg[1], arg[2])
		"panel_clear":
			player.set_panel(arg[0], arg[1], "")
		"holiday_claim":
			var hm := HolidayService.claim(world, player, arg)
			if not hm.is_empty():
				hud.show_banner("\n".join(hm), UI.GOLD)
				Audio.play("quest", 0.0)
				_record("holiday_reward")
				if int(arg) == 2:
					_record("holiday_top")
				save_game()
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
	Audio.play_music("menu")
	Audio.play_ambient("")
	hud.set_mode(false, false)
	if use_slots:
		SaveSystem.migrate_single_to_slots()  # перший запуск після оновлення: hero.save → слот 1
		save_path = SaveSystem.slot_path(slot)
	_open_menu()
	hud.add_title("Козацька Звитяга", 72)
	hud.add_title("З Кремля повзе чорна зараза Путіноїда. Козаче, рушай у похід!", 24, UI.TEXT)
	if use_slots:
		var sums := SaveSystem.slot_summaries()
		var any := false
		for s_ in sums:
			if not s_.is_empty():
				any = true
		if any and not sums[slot - 1].is_empty():
			hud.add_button("Продовжити: " + _slot_title(sums[slot - 1]), _continue_game)
		hud.add_button("Персонажі", _show_heroes_menu)
		if not any:
			hud.add_button("Нова гра", new_game)
	elif SaveSystem.exists(save_path):
		hud.add_button("Продовжити", _continue_game)
		hud.add_button("Нова гра", _confirm_new_game)
	else:
		hud.add_button("Нова гра", new_game)
	_add_sound_toggles(_show_main_menu)
	hud.add_title("Ліва частина екрана — рух, праворуч — удар, перекид і вміння.\nНа мапі обирай міста, дикі місцевості та печери.", 18, Color(0.8, 0.8, 0.8))


## Підпис слота: «Козак 12 • Розділ II • 3 год 20 хв».
func _slot_title(s_: Dictionary) -> String:
	var cls: String = ClassesData.CLASSES.get(s_["job"], {}).get("name", "Герой")
	if s_.get("rank", "") == "hetman":
		cls = "Гетьман"
	var story := "сюжет пройдено" if s_["done"] else ("Пролог" if s_["chapter"] == 0 else "Розділ %s" % ["", "I", "II", "III", "IV", "V"][mini(5, s_["chapter"])])
	var h := int(s_["playtime"]) / 3600
	var m := (int(s_["playtime"]) % 3600) / 60
	return "%s %d • %s • %d год %02d хв" % [cls, s_["level"], story, h, m]


## Екран «Персонажі»: до 5 слотів — грати, новий, видалити.
func _show_heroes_menu() -> void:
	_open_menu()
	hud.add_title("Персонажі", 56)
	hud.add_title("Хутір, скриня, досягнення й виклики — спільні для всіх.", 20, UI.TEXT)
	var sums := SaveSystem.slot_summaries()
	for i in SaveSystem.MAX_SLOTS:
		var s_: Dictionary = sums[i]
		var n := i + 1
		if s_.is_empty():
			hud.add_button("Слот %d — новий персонаж" % n, func():
				slot = n
				save_path = SaveSystem.slot_path(n)
				new_game(), Vector2(620, 64))
		else:
			var play := UI.button(("▶ " if n == slot else "") + _slot_title(s_), func():
				slot = n
				save_path = SaveSystem.slot_path(n)
				_continue_game(), Vector2(520, 64), 20)
			var del := UI.button("✕", func(): _confirm_delete_slot(n), Vector2(84, 64), 24)
			hud.add_row([play, del])
	hud.add_button("Назад", _show_main_menu)


func _confirm_delete_slot(n: int) -> void:
	_open_menu()
	hud.add_title("Видалити персонажа зі слота %d?" % n, 44)
	hud.add_title("Хутір і скриня лишаться — вони спільні. Самого героя не повернути.", 22, UI.TEXT)
	hud.add_button("Так, видалити", func():
		SaveSystem.delete(SaveSystem.slot_path(n))
		_show_heroes_menu())
	hud.add_button("Ні", _show_heroes_menu)


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
	hud.add_button(player.class_name_ua(), func():
		hud.close_overlay()
		state = State.PLAYING
		open_character())
	hud.add_button(("×2 досвіду ще %s" % AdRewards.format_time(AdRewards.xp2_left(world))) if not AdRewards.can_xp2(world) else "Реклама: ×2 досвіду на годину", func(): _watch_xp2(_show_pause))
	var leave_text := "Покинути печеру (прогрес втратиться)" if combat.is_dungeon() else "Повернутися на мапу"
	if combat.is_duel() and not combat.duel_over:
		hud.add_button("Здатися (мінус спроба)", _duel_lost)
	else:
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
	SaveSystem.save_settings({"sound": Audio.sound_on, "music": Audio.music_on, "autosell": combat.autosell})


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
				_use_slot("attack", 0)
		KEY_I, KEY_2:
			if playing:
				_use_slot("attack", 1)
		KEY_O, KEY_3:
			if playing:
				_use_slot("attack", 2)
		KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			if playing:
				_use_slot("buff", event.physical_keycode - KEY_5)
		KEY_H, KEY_4:
			if playing:
				player.use_potion()
		KEY_G:
			if playing:
				player.use_mana_potion()
		KEY_C, KEY_TAB:
			if state == State.CHARACTER:
				close_character()
			elif playing or state == State.MAP or state == State.CITY or state == State.CAMP:
				open_character()
		KEY_M:
			if playing:
				_try_leave()
		KEY_P:
			if playing:
				_show_pause()
			elif state == State.PAUSED:
				_resume_play()
		KEY_ESCAPE:
			go_back(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING:
		_show_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back(true)


var map_menu := false  # на мапі відкрито меню привалу
var allow_quit := true  # тести вимикають, щоб «Вийти з гри» не закрило їх самих
var quit_requested := false


## «Назад»: системна кнопка чи жест на Android (from_system) або Esc на комп'ютері.
## Крок назад із будь-якого екрана; із застосунку виходить лише з головного меню й лише системне «Назад».
func go_back(from_system: bool) -> void:
	if Ads.is_busy() or hud.dialogue_root != null:
		return  # рекламу й розмову з вибором треба довести до кінця
	match state:
		State.PLAYING:
			_show_pause()
		State.PAUSED:
			_resume_play()
		State.CHARACTER:
			close_character()
		State.ACTIVITY:
			_quit_activity()
		State.CITY:
			leave_city()
		State.CAMP:
			leave_camp()
		State.MAP:
			if map_menu and hud.overlay.visible:
				_close_map_menu()
			else:
				_show_map_menu()
		State.MENU:
			if from_system:
				_quit_app()


## Привал на мапі: звук, головне меню, вихід. Раніше з мапи до головного меню дороги не було.
func _show_map_menu() -> void:
	if state != State.MAP or travel_to != "":
		return  # у дорозі не спиняємось: поїздка триває кілька секунд
	map_menu = true
	_open_menu()
	hud.add_title("Привал")
	hud.add_button("Далі в дорогу", _close_map_menu)
	_add_sound_toggles(_show_map_menu)
	hud.add_button("Головне меню", func():
		save_game()
		map_menu = false
		_show_main_menu())
	hud.add_button("Вийти з гри", _quit_app)


func _close_map_menu() -> void:
	map_menu = false
	hud.close_overlay()


func _quit_app() -> void:
	if state != State.MENU:
		save_game()
	map_menu = false
	quit_requested = true
	if allow_quit:
		get_tree().quit()


# ======================= Хутір =======================

func enter_camp() -> void:
	_leave_combat()
	hud.close_overlay()
	state = State.CAMP
	Audio.play_music(_home_music("camp"))
	Audio.play_ambient("fire")
	get_tree().paused = true
	map_here = Camp.CAMP_ID
	player.revive()
	world.revive_companions()
	CampService.apply_effects(world, player)
	hud.show_map(false)
	hud.set_mode(false, false)
	camp_sel_uid = -1
	smith_msg = ""
	var back := _expedition_news(true)
	_build_camp()
	if not back.is_empty():
		hud.show_banner("\n".join(back), UI.GOLD)
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
		"craft_tier":
			craft_tier = arg
			smith_msg = ""
		"craft":
			var it := CraftService.forge(world, player, arg[0], arg[1], craft_tier)
			if not it.is_empty():
				Audio.play("sharpen_ok", 0.03)
				smith_msg = "Викувано: %s" % Data.item_title(it)
				smith_msg_color = Data.RARITY_COLORS[it["rarity"]]
				_record("craft")
		"reforge":
			var fresh := CraftService.reforge(world, player, arg[0], arg[1])
			if fresh != "":
				Audio.play("sharpen_ok", 0.03)
				smith_msg = "Перековано: нова властивість!"
				smith_msg_color = UI.GOOD
		"renew":
			if CraftService.renew(world, player, arg):
				Audio.play("sharpen_ok", 0.03)
				smith_msg = "Річ оновлено до твого рівня!"
				smith_msg_color = UI.GOOD
		"chest_put":
			if account.chest_full(CampService.level(world, "sklad")):
				smith_msg = "Скриня повна"
				smith_msg_color = UI.BAD
			elif player.is_equipped(arg):
				smith_msg = "Спершу зніми річ"
				smith_msg_color = UI.BAD
			else:
				var it := player.remove_from_bag(arg)
				if not it.is_empty():
					account.put_item(it, CampService.level(world, "sklad"))
					smith_msg = ""
		"chest_take":
			if player.bag_full():
				smith_msg = "Торба повна"
				smith_msg_color = UI.BAD
			else:
				var it := account.take_item(arg)
				if not it.is_empty():
					player.add_item(it)
					smith_msg = ""
		"chest_put_gold":
			account.put_gold(player, arg)
		"chest_take_gold":
			account.take_gold(player, arg)
		"chest_put_stone":
			account.put_stone(player, arg)
		"chest_take_stone":
			account.take_stone(player, arg)
		"brew":
			if CampService.brew(world, player, arg):
				Audio.play("heal", 0.0)
		"plant":
			if GardenService.plant(world, player, arg[0], arg[1]):
				Audio.play("rustle", 0.1)
				_record("plant")
		"harvest":
			var hm := GardenService.harvest(world, player, arg)
			if hm != "":
				Audio.play("rustle", 0.1)
				hud.show_banner(hm, UI.GOOD)
				_record("harvest")
		"harvest_all":
			var hms := GardenService.harvest_all(world, player)
			if not hms.is_empty():
				Audio.play("rustle", 0.1)
				hud.show_banner("\n".join(hms), UI.GOOD)
				_record("harvest", hms.size())
		"uproot":
			GardenService.uproot(world, arg)
		"cook":
			if OutdoorService.cook(player, arg):
				Audio.play("pot", 0.05)
				hud.show_banner("%s готовий! %s" % [Acts.RECIPES[arg]["name"], Acts.RECIPES[arg]["desc"]], UI.GOOD)
				_record("cook")
				_record("cook:" + str(arg))
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
