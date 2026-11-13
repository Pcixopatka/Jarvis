class_name Game
extends Node2D
## Диригент гри: режими (меню → мапа → місто → похід), збереження, екрани, клавіатура.
## Бій веде Combat, інтерфейс — Hud, логіку міста — CityService; Game лише з'єднує їх.

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const UiCharacter := preload("res://scripts/ui/ui_character.gd")
const UiCity := preload("res://scripts/ui/ui_city.gd")
const MapPanel := preload("res://scripts/ui/map_panel.gd")
const WorldState := preload("res://scripts/game/world_state.gd")
const CityService := preload("res://scripts/game/city_service.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")
const StoryService := preload("res://scripts/game/story_service.gd")
const QuestEngine := preload("res://scripts/game/quest_engine.gd")
const HeroService := preload("res://scripts/game/hero_service.gd")
const PlagueService := preload("res://scripts/game/plague_service.gd")
const TravelService := preload("res://scripts/game/travel_service.gd")
const DefenseService := preload("res://scripts/game/defense_service.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const CraftService := preload("res://scripts/game/craft_service.gd")
const SpecService := preload("res://scripts/game/spec_service.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const DepthService := preload("res://scripts/game/depth_service.gd")
const BossService := preload("res://scripts/game/boss_service.gd")
const TowerService := preload("res://scripts/game/tower_service.gd")
const EventService := preload("res://scripts/game/event_service.gd")
const DuelService := preload("res://scripts/game/duel_service.gd")
const BountyService := preload("res://scripts/game/bounty_service.gd")
const VigilService := preload("res://scripts/game/vigil_service.gd")
const RingService := preload("res://scripts/game/ring_service.gd")
const MusterService := preload("res://scripts/game/muster_service.gd")
const FarService := preload("res://scripts/game/far_service.gd")
const EventsBoard := preload("res://scripts/game/events_board.gd")
const GuideService := preload("res://scripts/game/guide_service.gd")
const WayService := preload("res://scripts/game/way_service.gd")
const QuickService := preload("res://scripts/game/quick_service.gd")
const PerilService := preload("res://scripts/game/peril_service.gd")
const ShopService := preload("res://scripts/game/shop_service.gd")
const UiShop := preload("res://scripts/ui/ui_shop.gd")
const Peril := preload("res://scripts/data/peril.gd")
const Sets := preload("res://scripts/data/sets.gd")
const WikiService := preload("res://scripts/game/wiki_service.gd")
const UiWiki := preload("res://scripts/ui/ui_wiki.gd")
const TradeService := preload("res://scripts/game/trade_service.gd")
const OutdoorService := preload("res://scripts/game/outdoor_service.gd")
const TavernService := preload("res://scripts/game/tavern_service.gd")
const GardenService := preload("res://scripts/game/garden_service.gd")
const ExpeditionService := preload("res://scripts/game/expedition_service.gd")
const RecordService := preload("res://scripts/game/record_service.gd")
const NameService := preload("res://scripts/game/name_service.gd")
const HolidayService := preload("res://scripts/game/holiday_service.gd")
const Sounds := preload("res://scripts/data/sounds.gd")
const Gfx := preload("res://scripts/world/gfx.gd")
const HuntGame := preload("res://scripts/ui/hunt_game.gd")
const FishGame := preload("res://scripts/ui/fish_game.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const EscortService := preload("res://scripts/game/escort_service.gd")
const KleinodService := preload("res://scripts/game/kleinod_service.gd")
const SaveTransfer := preload("res://scripts/core/save_transfer.gd")
const Acts := preload("res://scripts/data/activities.gd")
const PathService := preload("res://scripts/game/path_service.gd")
const Paths := preload("res://scripts/data/paths.gd")
const AccountScript := preload("res://scripts/game/account.gd")
const ClassesData := preload("res://scripts/data/classes.gd")
const Party := preload("res://scripts/game/party.gd")
const CampService := preload("res://scripts/game/camp_service.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const AdRewards := preload("res://scripts/game/ad_rewards.gd")
const PremiumService := preload("res://scripts/game/premium_service.gd")
const CostumeService := preload("res://scripts/game/costume_service.gd")
const PetService := preload("res://scripts/game/pet_service.gd")
const AutoService := preload("res://scripts/game/auto_service.gd")
const DivineService := preload("res://scripts/game/divine_service.gd")
const Clock := preload("res://scripts/core/clock.gd")
const LegendService := preload("res://scripts/game/legend_service.gd")
const SideService := preload("res://scripts/game/side_service.gd")
const UiDivine := preload("res://scripts/ui/ui_divine.gd")
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
## Де герой на мапі. Зазвичай це місце (map_here), та він може стояти й просто на мапі, у вільній точці:
## тоді map_at_point = true, точка лежить у map_point, а map_here тримає найближче місце (для порадника
## й подій). Будь-яке присвоєння map_here означає «герой у цьому місці» й знімає вільну точку.
const POINT_ID := "@point"  # travel_to під час поїздки у вільну точку
var map_at_point := false
var map_point := Vector2.ZERO  # довгота й широта вільної точки
var travel_point := Vector2.ZERO  # куди їдемо, коли travel_to == POINT_ID
var map_here := "sich":
	set(v):
		map_here = v
		map_at_point = false
var map_sel := ""

# Стан екранів (читають ui_character.gd та ui_city.gd)
var char_tab := 0
var wiki_open := false  # відкрито довідник (поверх меню, паузи, мапи чи екрана героя)
var wiki_tab := 0
var wiki_query := ""
var _wiki_back := Callable()
var char_sel_uid := -1
var char_return := State.MAP
var city_tab := 0:
	set(v):
		city_tab = v
		city_tab_key = ""  # номер виставлено напряму: запам'ятана назва більше не чинна
var city_tab_key := ""  # назва відкритої вкладки міста: у кожному місті й після нових відкриттів номери різні
var city_tab_want := ""  # назва вкладки, на якій має відкритися місто (UiCity.build знайде її номер)
var city_sel_uid := -1
var sell_multi := false  # крамниця: режим вибору кількох речей
var sell_marked := {}  # uid -> true
var smith_msg := ""
var smith_msg_color := Color.WHITE
var camp_tab := 0
var craft_tier := 1  # якість у вкладці «Кування»
var confirm_action := ""
var skill_sel := ""
var skill_tree := ""  # яке дерево вмінь показано ("" — дерево нинішнього класу)
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
var chest_sel := ""  # вибрана річ на вкладці «Скриня»: "c:uid" — у скрині, "b:uid" — у торбі ("" — нічого)


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false  # системне «Назад» розбирає go_back(): воно не має мовчки закривати гру посеред бою
	var settings := SaveSystem.load_settings()
	if use_slots:
		slot = int(settings.get("slot", 1))  # останній герой, яким грали
	Audio.set_sound(settings["sound"])
	Audio.set_music(settings["music"])

	combat = CombatScript.new()
	add_child(combat)
	combat.autosell = settings.get("autosell", false)
	combat.pickup_filter = settings.get("pickup", [true, true, true, true]).duplicate()
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
	hud.auto_pressed.connect(toggle_auto)
	hud.map_location_selected.connect(_on_map_select)
	hud.map_view.guide_pressed.connect(_guide_go)
	hud.map_view.legend_pressed.connect(func():
		map_legend = not map_legend
		_build_map_panel())
	hud.map_view.travel_tapped.connect(_travel_speed_up)
	hud.map_view.point_tapped.connect(_go_point)

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
	Events.ring_stage.connect(_on_ring_stage)
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
		# про нову дорогу кажемо раз, коли вона щойно відкрилась («change_at»), а не на кожному рівні далі:
		# хто хоче спершу дорости до вершини майстерності, той не мусить бачити це щоразу
		var opened: bool = player.can_change_class() and jl == int(player.class_info()["change_at"])
		if opened and player.is_peasant():
			hud.show_banner("Майстерність %d!\nЧас обирати дорогу: Січ, Батурин чи Карпати" % jl, UI.GOLD)
		elif opened:
			hud.show_banner("Майстерність %d!\nНаставники на Січі чекають на тебе" % jl, UI.GOLD)
		elif state != State.PLAYING:
			hud.show_banner("Майстерність %d!" % jl, UI.GOLD))
	Events.charged_hit.connect(func(): _record("charged"))
	Events.defense_lost.connect(_on_defense_lost)
	Events.item_found.connect(func(_i): hint("item", "Знайдено річ! Вдягни її: кнопка «Персонаж» (угорі праворуч), торкнись речі в торбі й натисни «Вдягнути»."))
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
		if auto_on and combat.active and AutoService.block_reason(world, combat, combat.loc_id) == "":
			AutoService.drive(self)  # автобій сам тисне всі вміння, тож авто-бафи Німба тоді мовчать
		elif combat.active and not get_tree().paused:
			DivineService.auto_buff_tick(player, combat, delta)
		AdRewards.tick(world, delta)
		for gone in player.tick_buffs(delta):  # страви й зілля сили діють за часом бою
			_buff_gone(gone)
	elif state == State.MAP:
		_travel_tick(delta)
	player.xp_boost = AdRewards.xp_mult(world)
	combat.drop_boost = AdRewards.drop_mult(world)
	# стрілка до мети в бою: розшук, сторож скарбу, сліди, вихід, те, що боронимо
	var goal: Dictionary = combat.objective() if state == State.PLAYING else {}
	if goal.is_empty():
		hud.objective_arrow.show_target(Vector2.ZERO, "")
	else:
		hud.objective_arrow.show_target(goal["pos"] - player.global_position, str(goal["label"]))
	var top := StoryService.objective_line(world)
	for l in HeroService.objective_lines(world):
		top += "\n" + l
	var sl := SpecService.objective_line(world)
	if sl != "":
		top += "\n" + sl
	var buffs := buffs_line()
	if buffs != "":
		top = "%s\n%s" % [buffs, top]
	if AdRewards.xp2_left(world) > 0.0:
		top = "×2 досвіду: %s\n%s" % [AdRewards.format_time(AdRewards.xp2_left(world)), top]
	if AdRewards.drop2_left(world) > 0.0:
		top = "×2 здобичі: %s\n%s" % [AdRewards.format_time(AdRewards.drop2_left(world)), top]
	if holiday_id != "":
		top = "Свято: %s (%s)\n%s" % [Acts.holiday(holiday_id)["name"], Acts.holiday(holiday_id)["bonus_text"], top]
	hud.update(player, world, _combat_info(), delta, top.strip_edges())


const BUFF_NAMES := {"strength": "Зілля сили", "antiplague": "Зілля проти зарази", "inspired": "Натхнення"}


## Рядок під смугами героя: що з'їдено й випито і скільки бою воно ще діє.
func buffs_line() -> String:
	var parts := []
	var meal := OutdoorService.eaten(player)
	if meal != "":
		parts.append("%s %s" % [Acts.recipe(meal)["name"], UiCamp.buff_time(player.buff_left("food"))])
	for key in BUFF_NAMES:
		if player.trip_buffs.has(key):
			parts.append("%s %s" % [BUFF_NAMES[key], UiCamp.buff_time(player.buff_left(key))])
	return "  •  ".join(parts)


## Підсилення вичерпалось посеред бою: тихий напис над героєм.
func _buff_gone(key: String) -> void:
	var text := ""
	if key.begins_with("food:"):
		text = "%s: страва вже не діє" % Acts.recipe(key.substr(5)).get("name", "Страва")
	elif BUFF_NAMES.has(key):
		text = "%s: дія скінчилась" % BUFF_NAMES[key]
	if text != "" and combat.active:
		combat.float_text(player.global_position + Vector2(0, -110), text, UI.MUTED)


func _combat_info() -> Dictionary:
	if state != State.PLAYING or not combat.active:
		return {}
	var L: Dictionary = combat.loc
	var sub := ""
	if combat.is_vigil():
		sub = "Варта %s / %s  •  Вбито %d" % [VigilService.time_text(combat.vigil_time), VigilService.time_text(float(L["goal"])), combat.vigil_kills]
		if combat.vigil_done:
			sub = "Вистояно! %s  •  Вбито %d  •  портал відкрито" % [VigilService.time_text(combat.vigil_time), combat.vigil_kills]
	elif combat.is_ring():
		var n_st := int(Acts.RING_STAGES)
		sub = "Коло %d із %d  •  %s" % [mini(combat.ring_stage + 1, n_st), n_st, RingService.time_text(combat.ring_time)]
		if combat.ring_done:
			sub = "Усі три кола пройдено за %s  •  портал відкрито" % RingService.time_text(combat.ring_time)
	elif combat.is_duel() and L.has("team"):
		sub = "Сутичка %d із %d  •  Суперників на ногах: %d" % [int(L["round"]) + 1, MusterService.ROUNDS, combat.alive_enemy_count()]
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
			sub = "Рівень %d  •  %s" % [L["level"], ("Супербос: %s" % GameDB.boss_name(L["boss"])) if L["boss"] != "" else L["mini_title"]]
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
	Data.weapon_pool = player.Classes.info(player.job)["weapons"]
	StoryService.hero_class = "volkhv" if player.Classes.is_volkhv_line(player.job) else ("strilets" if player.Classes.is_strilets_line(player.job) else player.job)


## Нова гра. nick: ім'я з екрана «Як тебе звати»; без нього (прямий виклик, тести) герой дістає
## випадкове козацьке прізвисько.
func new_game(nick: String = "") -> void:
	_reset_session()
	tower_sel = 1
	depth_sel = 1
	world = WorldState.new()
	meta = {"playtime": 0.0, "created": Time.get_unix_time_from_system()}
	_load_account()
	_attach_account()
	_new_hero({})
	_remember_slot()
	_make_peasant()
	player.nick = NameService.from_save(nick)
	if player.nick == "":
		player.nick = NameService.roll()
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
	meta["place"] = {"here": map_here, "point": map_at_point, "x": map_point.x, "y": map_point.y}  # де стоїть герой
	SaveSystem.save({"player": player.to_dict(), "world": world.to_dict(), "meta": meta}, save_path)
	_save_account()


func _save_account() -> void:
	if account_path == SaveSystem.ACCOUNT_PATH and not use_slots:
		return  # тести без слотів не чіпають справжній акаунт
	SaveSystem.write_var(account_path, account.to_dict())


var account_notice := ""  # що сказати гравцеві, якщо спільне майно не прочиталось


func _load_account() -> void:
	account = AccountScript.new()
	account_notice = ""
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
	# Файл спільного майна є, та не читається ні він, ні його копія. Гра піде з порожнім, але зіпсований
	# файл лишаємо поруч (.broken): так хутір, скриню й червінці ще можна врятувати, і гравець про це знає.
	if FileAccess.file_exists(account_path):
		DirAccess.copy_absolute(account_path, account_path + ".broken")
		account_notice = "Спільне майно роду (хутір, скриня, червінці) не прочиталось.\nЗіпсований файл збережено поруч, гра почала з порожнього."


## Спільне майно підключається до світу персонажа посиланнями.
func _attach_account() -> void:
	account.absorb_from_world(world)  # старе збереження: забрати хутір і досягнення в акаунт
	account.attach(world)


func load_game() -> bool:
	var d := SaveSystem.load_data(save_path)
	if d.is_empty():
		return false
	if not ClassesData.has_class(str(d["player"].get("job", "peasant"))):
		return false  # клас, якого ця версія гри не знає: герой із новішої збірки
	world = WorldState.new()
	world.from_dict(d["world"])
	meta = d.get("meta", meta)
	_load_account()
	_attach_account()
	tower_sel = int(TowerService.state(world)["max"])
	depth_sel = int(DepthService.state(world)["max"])
	Data.sell_mult = 1.0
	fight_notice = ""
	if str(meta.get("fight", "")) != "":
		fight_notice = "Ти покинув бій посеред сутички.\n" + _fight_forfeit()
	theft_notice = EventService.check_theft(world, Clock.now(), CampService.level(world, "kurin"))
	_new_hero(d["player"])
	_sync_class()
	Party.normalize(world, player.level)
	CampService.apply_effects(world, player)
	return true


var fight_notice := ""  # що сказати після завантаження, якщо гру закрили посеред герцю


func _continue_game() -> void:
	if load_game():
		_remember_slot()
		var banners := hud.banner_count  # банери, показані після цього, екран імені може затулити
		_restore_place()
		if fight_notice != "":
			hud.show_banner(fight_notice, UI.BAD)
			fight_notice = ""
			save_game()
		var notes := []  # повідомлення міграцій (SaveSystem.migrate), кожне — раз
		if meta.get("notice", "") == "classes":
			meta.erase("notice")
			notes.append("Нова система класів! Вміння й Загартування скинуто —\nочки повернуто, розподіли їх заново (кнопка «Персонаж»)")
		if int(meta.get("job_bonus", 0)) > 0:
			notes.append(job_bonus_text(int(meta["job_bonus"])))
			meta.erase("job_bonus")
			save_game()  # очки вже записано в героя: удруге ні вони, ні банер не з'являться
		if not notes.is_empty():
			hud.show_banner("\n".join(notes), UI.GOLD)
		if ask_name and player.nick == "":
			_ask_first_name(banners)  # герой зі збереження, де імен ще не було
	elif SaveSystem.exists(save_path):
		# Збереження є, та не читається (зіпсоване чи з новішої версії гри). Нову гру поверх нього
		# не починаємо: вона затерла б героя. Файл лишається, як був.
		_show_main_menu()
		hud.show_banner("Збереження не читається.\nЙого не чіпали. Онови гру або видали героя в «Персонажі».", UI.BAD)
	else:
		new_game()


## Банер для героя, що змінив клас ще за старих меж майстерності (міграція v13): скільки очок умінь додано й чому.
## Нові межі — із записів класів.
func job_bonus_text(got: int) -> String:
	var C = ClassesData
	var first: String = str(C.info("peasant")["next"][0])
	return "Майстерність тепер вища: Селянин росте до %d-го рівня, перший клас — до %d-го.\nТи змінив клас ще за старих меж, тож маєш +%d %s умінь (кнопка «Персонаж»)" % [
		int(C.info("peasant")["job_max"]), int(C.info(first)["job_max"]), got, C.plural(got, "очко", "очки", "очок")]


## Після входу в гру герой стоїть там, де стояв, коли гру закрили. Бій сам не починається: якщо гру
## закрили посеред бою, герой стоїть на мапі біля входу. Старе збереження без цього запису чи незнайоме
## місце: останнє відвідане місто, як раніше.
func _restore_place() -> void:
	# дорога й бій попередньої сесії цьому героєві не належать
	travel_to = ""
	travel_paused = false
	pending_event = {}
	escort_go = ""
	hud.map_view.travel = {}
	if combat.active:
		combat.leave()
	var p = meta.get("place", null)
	var here := ""
	var at_point := false
	var ll := Vector2.ZERO
	if p is Dictionary:
		here = str(p.get("here", ""))
		var x = p.get("x", 0.0)
		var y = p.get("y", 0.0)
		if p.get("point", false) is bool and p.get("point", false) and (x is float or x is int) and (y is float or y is int) and is_finite(float(x)) and is_finite(float(y)):
			var mv = hud.map_view
			at_point = true
			ll = Vector2(clampf(float(x), mv.LON0 + mv.EDGE, mv.LON1 - mv.EDGE), clampf(float(y), mv.LAT0 + mv.EDGE, mv.LAT1 - mv.EDGE))
	var known: bool = Data.is_city(here) or Data.is_place(here) or Acts.is_spot(here) or here == Camp.CAMP_ID
	# після бою, що міг лишити героя чи загін пораненими, вхід у гру лікує, як раніше лікувало місто
	player.revive()
	world.revive_companions()
	if at_point:
		map_here = here if known else _nearest_place(ll)
		map_at_point = true
		map_point = ll
		map_sel = ""
		enter_map()
	elif known and Data.is_city(here):
		map_here = here
		enter_city(here)
	elif here == Camp.CAMP_ID:
		enter_camp(false)  # гру відкрито там, де стояв: це не нова навідина на хутір
	elif known:
		map_here = here
		map_sel = here
		enter_map()
	else:
		map_here = world.last_city
		enter_city(world.last_city)


## Запам'ятати в налаштуваннях героя, яким грають: наступного запуску «Продовжити» пропонує його.
func _remember_slot() -> void:
	if use_slots:
		_save_settings()


## Кого пропонує «Продовжити»: запам'ятований слот, а якщо він порожній чи не читається, перший
## читабельний. 0, коли продовжувати нема ким. sums: список із SaveSystem.slot_summaries().
static func continue_slot(sums: Array, remembered: int) -> int:
	var readable := func(i: int) -> bool:
		return i >= 1 and i <= sums.size() and sums[i - 1] is Dictionary and not sums[i - 1].is_empty() and not sums[i - 1].get("broken", false)
	if readable.call(remembered):
		return remembered
	for i in range(1, sums.size() + 1):
		if readable.call(i):
			return i
	return 0


# ======================= Режими =======================

func _leave_combat() -> void:
	hud.close_dialogue()
	AutoService.stop(self)
	defense_target = ""  # портал після оборони веде в місто лише з цього бою (_on_exit забирає ціль раніше)
	meta.erase("fight")
	if combat.active:
		if combat.is_vigil():
			leave_notice = "\n".join(VigilService.finish(world, player, combat.vigil_time, combat.vigil_kills))
		combat.collect_all()
		combat.leave()


func enter_map() -> void:
	world.hero_level = player.level
	if player.valor > int(world.stats.get("valor", 0)):
		_record("valor", player.valor)
	var from_trip: bool = combat.active and combat.counts_as_trip()
	_leave_combat()
	_price_city("")
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
	mv.current = "" if map_at_point else map_here
	mv.current_ll = null
	if map_at_point:
		mv.current_ll = map_point
	if map_at_point:
		mv.focus_ll(map_point)
	else:
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
	# Місії рушія: сюжетні — зірка, решта — «!» (QuestEngine.mark); бліді — місії, яким бракує рівня героя
	var qm: Dictionary = QuestEngine.map_marks(world)
	for loc in qm["marks"]:
		mv.targets[loc] = true
	mv.stars = qm["stars"]
	mv.dim_stars = qm["dim_stars"]
	mv.dim_targets = qm["dim_marks"]
	mv.turn_ins = {}
	var places: Dictionary = load("res://scripts/game/journal_service.gd").turn_in_places(world)
	for place in places:
		mv.turn_ins[place] = int(places[place]["quests"]) + int(places[place]["heads"])
	mv.story_target = StoryService.target(world)
	mv.plague = PlagueService.state(world)["levels"]
	mv.events = EventService.map_marks(world)
	if theft_notice != "":
		hud.show_banner(theft_notice, UI.BAD)
		theft_notice = ""
	var back := _expedition_news()
	var pay: int = PremiumService.stipend(world)
	if pay > 0:
		back.append("Платня за Гетьманським універсалом: +%d червінців" % pay)
		save_game()
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
		news.append_array(_trip_tick())
		mv.events = EventService.map_marks(world)
		if not news.is_empty():
			hud.show_banner("\n".join(news), Color(1.0, 0.75, 0.4))
	mv.sieges = DefenseService.state(world)["sieges"]
	map_legend = false
	map_bosses = false
	_build_map_panel()
	_refresh_guide()
	_announce_unlocks()
	save_game()
	if not WayService.finished(world):
		hint("way", "Шлях козака: ланцюжок цілей із нагородами, що по черзі вчить усьому в грі. Він угорі вкладки «Журнал», а кнопка «Далі» внизу мапи веде до наступного кроку.")
	hint("map", "Торкнись місця на мапі. «!» позначає мету завдання, зелена галочка — місто, де здати виконане. Почни з Дикого Поля поруч із Січчю.")


## Похід скінчився: світ живе далі. Зараза повзе, облоги й події рахують походи, дошки оновлюються.
## Повертає новини для гравця. Так само рахується й швидкий похід.
func _trip_tick() -> Array:
	var news := []
	var spread := PlagueService.tick(world)
	if not spread.is_empty():
		news.append("Зараза повзе далі: " + ", ".join(spread))
	news.append_array(DefenseService.tick(world, player))
	news.append_array(EventService.tick(world, player))
	BountyService.tick(world)
	TradeService.tick(world)
	OutdoorService.tick(world)
	TavernService.tick(world)
	return news


## Швидкий похід: місце, пройдене кілька разів, зачищається миттю. Плата — перегляд реклами.
func quick_raid(loc_id: String) -> void:
	if state != State.MAP or travel_to != "" or QuickService.block_reason(world, player, loc_id) != "":
		return
	_ad("quick", func(ok: bool):
		if ok:
			_quick_done(loc_id)
		else:
			_build_map_panel())


## Нагорода за рекламу: звичайно показує рекламу, а з Гетьманським універсалом дає нагороду одразу.
func _ad(placement: String, on_done: Callable) -> void:
	if PremiumService.active(world):
		on_done.call(true)
		return
	Ads.show_rewarded(placement, on_done)


func _quick_done(loc_id: String) -> void:
	if QuickService.block_reason(world, player, loc_id) != "":
		return
	world.hero_level = player.level
	var r: Dictionary = QuickService.run(world, player, loc_id, AdRewards.drop_mult(world), HolidayService.combat_mods(), combat.pickup_filter)
	# виклики й досягнення рахують швидкий похід як звичайний
	_record("kill", int(r["kills"]))
	for kind in r["kinds"]:
		_record("kill:" + str(kind), int(r["kinds"][kind]))
	if int(r["elites"]) > 0:
		_record("elite", int(r["elites"]))
	_record("dungeon" if Data.place(loc_id)["type"] == "dungeon" else "field")
	var lines := [QuickService.summary(r)]
	lines.append_array(_trip_tick())
	Audio.play("quest", 0.0)
	enter_map()  # оновити позначки, пораду й панель місця
	hud.show_banner("\n".join(lines), UI.GOLD)
	save_game()


func enter_city(id: String) -> void:
	world.hero_level = player.level  # завдання в далекі краї — за рівнем героя
	_leave_combat()
	hud.close_overlay()
	state = State.CITY
	if city_id != id or Audio.current_music not in ["city", "inn", "festive"]:
		Audio.play("door", 0.05)
	Audio.play_music(_home_music("city"))
	Audio.play_ambient("")
	get_tree().paused = true
	city_id = id
	_price_city(id)
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
	_story_event("visit", id)
	# Розмови самі не починаються: хто має справу до героя, чекає в ратуші (див. hall_rows)
	var waiting := hall_rows(id)
	var names := []
	for r in waiting:
		if str(r["kind"]) == "wait":
			continue  # місія, якій бракує рівня, на героя ще не чекає
		if not str(r["name"]) in names:
			names.append(str(r["name"]))
		if str(r["kind"]) == "story" or str(r["mark"]) == QuestEngine.STAR:
			city_tab_want = Data.hall_name(id)  # історія (і переказ — її ланка) важлива: місто відкривається на вкладці ратуші
	if not names.is_empty():
		back.append("%s: на тебе чекають\n%s" % [Data.hall_name(id), ", ".join(names.slice(0, 3))])
	_build_city()
	if not back.is_empty():
		hud.show_banner("\n".join(back), UI.GOLD)
	save_game()
	hint("city", "Це місто. Хто має до тебе справу, чекає на першій вкладці: підійди й поговори. На вкладці «Завдання» візьми доручення, у «Крамниці» купи спорядження, а потім натисни «На мапу».")


func leave_city() -> void:
	enter_map()


## Надбавка до ціни продажу діє лише в місті, де ярмарок (і в Хованця, що торгує за цінами цього міста).
## Поза містом ціна звичайна: інакше після ярмарку подвійна ціна лишалась на автопродаж і швидкі походи.
func _price_city(id: String) -> void:
	Data.sell_mult = EventService.sell_mult(world, id) if id != "" else 1.0


func enter_location(id: String) -> void:
	map_here = id
	_price_city("")
	for cid in Data.city_ids():
		world.shop_dirty[cid] = true
	hud.clear_screen()
	hud.close_dialogue()
	hud.close_overlay()
	hud.show_map(false)
	combat.boss_revives = 0 if StoryService.effect(world, "koshchii_mortal") > 0.0 else 1
	var extra := EventService.mods_for(world, id)
	extra.merge(BountyService.mods_for(world, id, player))
	if ChallengeService.pending(world, "trail"):
		extra["trail_sure"] = true  # виклик просить стежку слідів — вона буде в цьому ж поході
	if Data.is_place(id):
		var here: Dictionary = Data.place(id)
		# нічний похід підтягується до героя; далекі печери й так ростуть із ним (як і досі, ніч їх не чіпає)
		if extra.get("night", false) and not (FarService.is_far(here) and FarService.grows(here)):
			extra.merge(FarService.night_mods(here, player))
		extra.merge(FarService.mods(here, player))  # печери з босом ростуть із героєм, поле далекого краю — мета зачистки
		extra.merge(PerilService.combat_mods(id))  # надважка печера: міцніший бос і його лють
		var mission: Dictionary = QuestEngine.fight_mods(world, player, id)  # місце місії: бій не нижче рівня місії
		if int(mission.get("level", 0)) > int(extra.get("level", 0)):
			extra.merge(mission, true)  # печеру, що вже виросла з героєм, місія нижчого рівня не послаблює
		var trial_lvl: int = SpecService.fight_level(world, player, id)  # місце випробування: бій не нижче рівня героя
		if trial_lvl > 0:
			extra.merge(QuestEngine.raise_mods(id, maxi(trial_lvl, int(extra.get("level", 0))), player), true)
		if PerilService.is_peril(id):
			extra["peril_first"] = PerilService.cleared(world, id) == 0  # перша перемога дає річ набору напевно
	combat.enter(id, _party_data(), PlagueService.level(world, id), extra)
	hud.set_mode(true, true)
	state = State.PLAYING
	get_tree().paused = false
	Audio.play_music("boss" if combat.is_duel() else "battle")
	Audio.play_ambient(Sounds.ambient_for(str(combat.loc.get("biome", "")), combat.is_vigil() or bool(combat.loc.get("night", false))))
	Audio.play("unsheathe", 0.05)
	_refresh_auto_button()
	hint("combat", "Ліва частина екрана — рух. Тримай «Удар» — козак сам б'є найближчу нечисть. Коли ворог червоніє — він замахується: тисни «Перекид»!")


# ======================= Крамниця Хованця =======================

var trader_open := false
var trader_city := ""  # у якому місті торгує Хованець: останнє, де герой бував
var _trader_back := Callable()
var _trader_prev_city := ""


## Номер вкладки крамниці за назвою (вкладки можуть додаватися, тож шукаємо за іменем).
func _shop_tab_index(title: String) -> int:
	var names := ["Червінці"]
	for kind in ShopService.Shop.kinds():
		names.append(ShopService.Shop.kind_name(kind))
	names.append_array(["Божі дари", "Вбрання", "Універсал"])
	return maxi(0, names.find(title))


## Хованець торгує будь-де. Це та сама крамниця, що й у місті: товари, зілля, продаж поодинці,
## гуртом і кількох вибраних речей. Товар, ціни й знижка беруться з останнього міста, де герой бував.
func open_trader(back: Callable) -> void:
	if not DivineService.remote_shop(player):
		return
	_trader_back = back
	trader_open = true
	trader_city = world.last_city if Data.is_city(world.last_city) else "sich"
	_trader_prev_city = city_id
	city_id = trader_city  # дії крамниці (city_do) рахують ціни цього міста
	_price_city(trader_city)
	city_sel_uid = -1
	sell_multi = false
	sell_marked.clear()
	hud.close_overlay()
	Audio.play("coins", 0.05)
	hud.set_screen(_trader_screen(), "trader")


func _trader_screen() -> Control:
	# крамниця відкривається й посеред бою (з паузи), тож під нею суцільне тло
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", UI.style(Color(0.13, 0.11, 0.08), Color(0.13, 0.11, 0.08), 0, 0))
	bg.add_child(UiDivine.trader(self))
	return bg


func close_trader() -> void:
	if not trader_open:
		return
	trader_open = false
	city_id = _trader_prev_city
	# ціни вертаються до місця, де герой стоїть насправді: у місті — його, деінде — звичайні
	var in_city: bool = state == State.CITY or (state == State.CHARACTER and char_return == State.CITY)
	_price_city(city_id if in_city else "")
	city_sel_uid = -1
	sell_multi = false
	sell_marked.clear()
	hud.clear_screen()
	save_game()
	var back := _trader_back
	_trader_back = Callable()
	if back.is_valid():
		back.call()


# ======================= Автобій =======================

var auto_on := false  # гравець увімкнув автобій; діє лише там, де він дозволений (AutoService)


## Кнопка «Авто» в бою: увімкнути чи вимкнути. Де автобій ще закритий, каже чому.
func toggle_auto() -> void:
	if state != State.PLAYING:
		return
	if auto_on:
		auto_on = false
		AutoService.stop(self)
		hud.show_banner("Автобій вимкнено", UI.TEXT)
	else:
		var why: String = AutoService.block_reason(world, combat, combat.loc_id)
		if why != "":
			hud.show_banner("Автобій: %s" % why, UI.BAD)
			return
		auto_on = true
		hud.show_banner("Автобій увімкнено.\nТоркнись лівої частини екрана, щоб вести героя самому", UI.GOOD)
	_refresh_auto_button()


func _refresh_auto_button() -> void:
	var shown: bool = state == State.PLAYING and combat.active and AutoService.applies(combat, combat.loc_id)
	hud.auto_btn.visible = shown
	var on: bool = auto_on and shown and AutoService.block_reason(world, combat, combat.loc_id) == ""
	hud.auto_btn.text = "Авто: йде" if on else "Авто"
	hud.auto_btn.modulate = Color(0.75, 1.0, 0.75) if on else Color.WHITE
	if not on:
		AutoService.stop(self)


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
	_refresh_auto_button()


# ======================= Події =======================

func _on_enemy_killed(e: Node2D) -> void:
	if combat.is_ring():
		# чудовиська Кола — не ті, що в лігвах: ні сюжету, ні каменів долі, ні досягнень за боса
		_record("kill")
		return
	# Бос дня чи тижня це не господар лігва: сюжет, перекази, камені долі й досягнення за босів лігв
	# на нього не зважають. Інакше крок «здолай Кощія» закривався без походу до Кощія.
	var hunt_boss: bool = e.is_boss and combat.loc.has("hunt")
	if not hunt_boss:
		for m in world.on_kill(e.kind):
			combat.float_text(player.global_position + Vector2(0, -90), m, UI.GOLD)
		_story_event("kill", e.kind)
		_hero_event("kill", e.kind)
		_record("kill:" + e.kind)
		_spec_event("kill", e.kind)
	_record("kill")
	if e.elite:
		_spec_event("elite", "")
	if e.elite:
		_record("elite")
	if e.is_boss and not hunt_boss:
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
	for m in QuestEngine.on_event(world, player, type, arg):  # усі лінії: спершу сюжетні місії, далі перекази
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
	var now := PlagueService.cleanse(world, loc_id, was if Data.place(loc_id)["type"] == "dungeon" else 1)
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


## Остаточний вибір дороги: сюжет іде далі гілкою козака, волхва або стрільця.
func _path_choose(cls: String) -> void:
	var msgs := PathService.choose(world, player, cls)
	if msgs.is_empty():
		return
	Audio.play("quest", 0.0)
	hud.show_banner("Дорогу обрано: %s!" % Paths.card(cls)["title"], UI.GOLD)
	save_game()
	if state == State.CITY:
		city_tab = 0
		_build_city()
		_story_dialogue(city_id)  # кошовий одразу дає посвяту або лист до Велемира


# ======================= Ратуша: хто має справу до героя =======================

## Розмови в місті самі не починаються. Усі, хто має до героя справу (історія, побратими, наставник
## після випробування, оповідачі переказів, доручення), чекають у ратуші: це перша вкладка міста (UiCity._hall).
## Рядок: {"kind": "story"/"spec"/"hero"/"legend"/"side"/"wait", "line": id лінійки переказу (side — id доручення),
## "npc", "name", "role", "what": чого він хоче (місія — з позначкою QuestEngine.mark), "ready": чи чекає з
## нагородою, "id": місія рушія ("" — не місія), "mark": її позначка}. «wait» — місія, якій бракує лише рівня героя:
## той, хто її дасть, уже тут, але відмовляє («need» — потрібний рівень).
func hall_rows(city: String) -> Array:
	var out := []
	if player == null or world == null:
		return out
	world.hero_level = player.level
	var sds: Array = StoryService.city_dialogues(world, city)
	for i in sds.size():
		var sd: Dictionary = sds[i]
		var chapter: String = StoryService.chapter_title(world)
		var what: String = ("Історія. %s" % chapter) if chapter != "" else "Історія"
		if QuestEngine.kind_of(str(sd["id"])) == "story":
			what += ". %s" % QuestEngine.title(str(sd["id"]))  # назва кроку, як у переказу (у саги вона вже в назві розділу)
		# «line» сюжетного рядка: "" — перша сюжетна розмова міста, далі — id кроку (hall_talk)
		out.append(_hall_row("story", "" if i == 0 else str(sd["id"]), sd["lines"], what, str(sd["kind"]) in ["end", "saga_end"], str(sd["id"])))
	var pd := SpecService.city_dialogue(world, city)
	if not pd.is_empty():
		out.append(_hall_row("spec", "", pd["lines"], "Посвята: випробування пройдено", true))
	var hd := HeroService.city_dialogue(world, city)
	if not hd.is_empty():
		var wants := {"meet": "Проситься до тебе в загін", "quest": "Має особисте прохання", "end": "Хоче подякувати за допомогу"}
		out.append(_hall_row("hero", "", hd["lines"], str(wants.get(str(hd["kind"]), "Хоче поговорити")), str(hd["kind"]) == "end"))
	for ld in LegendService.city_dialogues(world, city):
		var line: String = str(ld["line"])
		out.append(_hall_row("legend", line, ld["lines"], "Переказ «%s». %s" % [LegendService.Legends.line(line)["title"], QuestEngine.step(str(ld["id"]))["title"]], str(ld["kind"]) == "legend_end", str(ld["id"])))
	for sd in SideService.city_dialogues(world, city):
		out.append(_hall_row("side", str(sd["id"]), sd["lines"], "Доручення. %s" % QuestEngine.title(str(sd["id"])), str(sd["kind"]) == "side_end", str(sd["id"])))
	# Місії, яким бракує лише рівня героя: той, хто їх дасть, відмовляє й каже, з якого рівня приходити
	for id in QuestEngine.waiting(world):
		var R: Dictionary = QuestEngine.step(id)
		if str(R.get("city", "")) != city:
			continue
		var row := _hall_row("wait", id, [[str(R["giver"]), ""]], _mission_what(id), false, id)
		row["need"] = QuestEngine.level_needed(id)
		out.append(row)
	return out


## Чого хоче той, хто дає місію id (рядок ратуші без позначки): «Історія. Розділ…», «Переказ «…». …», «Доручення. …».
func _mission_what(id: String) -> String:
	match QuestEngine.kind_of(id):
		"story":
			var ci: int = StoryService.Story.chapter_index(str(QuestEngine.step(id).get("chapter", "")))
			return "%s. %s" % [("Історія. %s" % StoryService.Story.chapter_title(ci)) if ci >= 0 else "Історія", QuestEngine.title(id)]
		"saga":
			return "Історія. %s. %s" % [StoryService.SagaService.Saga.title(), QuestEngine.title(id)]
		"legend":
			return "Переказ «%s». %s" % [QuestEngine.line_title(QuestEngine.line_of(id)), QuestEngine.title(id)]
	return "Доручення. %s" % QuestEngine.title(id)


## Хто веде розмову: перший, хто говорить, крім самого героя.
func _hall_npc(lines: Array) -> String:
	for l in lines:
		if not str(l[0]) in ["hero", "hero_volkhv", "selianyn"]:
			return str(l[0])
	return ""


## id — місія рушія, з якою прийшов цей рядок ("" — не місія): її позначка («★» чи «!») стає перед «what».
func _hall_row(kind: String, line: String, lines: Array, what: String, ready: bool, id: String = "") -> Dictionary:
	var npc := _hall_npc(lines)
	var info: Dictionary = StoryService.Story.npc(npc, {"name": "Гонець", "role": ""})
	var mark: String = QuestEngine.mark(id) if id != "" else ""
	return {"kind": kind, "line": line, "npc": npc, "name": str(info["name"]), "role": str(info.get("role", "")),
		"what": ("%s %s" % [mark, what]) if mark != "" else what, "ready": ready, "id": id, "mark": mark}


## Позначка на вкладці ратуші: «★», коли тут чекає сюжетна місія, «!» — інша місія; "" — місій нема.
## Рядки «wait» (місії бракує рівня) не рахуються: справи ще нема.
static func hall_badge(rows: Array) -> String:
	var out := ""
	for r in rows:
		if str(r["kind"]) == "wait" or str(r.get("mark", "")) == "":
			continue
		if str(r["mark"]) == QuestEngine.STAR:
			return QuestEngine.STAR
		out = str(r["mark"])
	return out


## Підійти до того, хто чекає в ратуші (кнопка «Поговорити»).
func hall_talk(kind: String, line: String = "") -> void:
	if state != State.CITY or (hud.dialogue_root != null and is_instance_valid(hud.dialogue_root)):
		return
	match kind:
		"story":
			_story_dialogue(city_id, line)
		"spec":
			_spec_dialogue(city_id)
		"hero":
			_hero_dialogue(city_id)
		"legend":
			_legend_dialogue(city_id, line)
		"side":
			_side_dialogue(city_id, line)


## Після розмови: якщо той самий співрозмовник має що сказати далі (подякував і одразу дає нову справу),
## розмова триває. Інакше герой лишається в ратуші й сам вирішує, до кого підійти.
func _hall_continue(kind: String, npc: String, line: String = "") -> void:
	if state != State.CITY or npc == "":
		return
	for r in hall_rows(city_id):
		if str(r["kind"]) == kind and str(r["npc"]) == npc and (kind != "legend" or str(r["line"]) == line):
			hall_talk(kind, str(r["line"]))
			return


## Посвята в спеціалізацію після випробування. Посвята — мить, коли клас справді змінюється, тож
## нижче вершини майстерності спершу попередження (warned — його вже прийнято).
func _spec_dialogue(city: String, warned: bool = false) -> void:
	var d := SpecService.city_dialogue(world, city)
	if d.is_empty():
		return
	if not warned and class_warn_needed(str(d["spec"])):
		_show_class_warn(str(d["spec"]), _spec_dialogue.bind(city, true))
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


# ---------- Зміна класу раніше вершини майстерності ----------

## Відкрите попередження: {"to": новий клас, "lost": скільки очок умінь пропаде, "yes": що зробити після «Так»}.
var class_warn := {}


## Чи треба попередити перед переходом у клас to: герой іще не доріс до вершини майстерності свого класу,
## тож очки за решту рівнів пропадуть назавжди. На вершині попередження нема.
func class_warn_needed(to: String) -> bool:
	return to != "" and to != player.job and player.job_points_left() > 0


## Вікно-попередження перед ранньою зміною класу: скільки очок умінь пропаде назавжди (вершина майстерності
## мінус нинішня). «Так» робить yes (розмову, що змінює клас), «Ні» чи «Назад» лишає все як було:
## розмова чекає в ратуші, і до неї можна повернутися, коли майстерність доросте.
func _show_class_warn(to: String, yes: Callable) -> void:
	var lost: int = player.job_points_left()
	var left: int = player.job_levels_left()
	var C = player.Classes
	class_warn = {"to": to, "lost": lost, "yes": yes}
	_open_menu("class_warn", true)
	hud.add_title("Змінити клас раніше вершини?", 44)
	hud.add_title("%s: майстерність %d із %d" % [player.class_name_ua(), player.job_level, player.job_max()], 26, UI.GOLD)
	hud.add_title("Новий клас — %s — почне майстерність з 1.\n%s міг би ще вирости на %d %s, а це %d %s умінь.\nВони пропадуть назавжди: їх не поверне ні %s,\nні %s, ні жодне інше скидання." % [
		str(C.info(to)["name"]), player.class_name_ua(), left, C.plural(left, "рівень", "рівні", "рівнів"),
		lost, C.plural(lost, "очко", "очки", "очок"), StoneService.name_of("zabuttia"), StoneService.name_of("alatyr")], 22, UI.TEXT)
	hud.add_title("Відмовишся — усе лишиться як є, а до цієї розмови можна повернутися будь-коли.", 20, UI.MUTED)
	hud.add_button("Так, змінити клас", class_warn_confirm, Vector2(620, 64))
	hud.add_button("Ні, ще наберуся сили", class_warn_cancel, Vector2(620, 64))


func class_warn_confirm() -> void:
	if class_warn.is_empty():
		return
	var yes: Callable = class_warn["yes"]
	class_warn = {}
	hud.close_overlay()
	yes.call()


func class_warn_cancel() -> void:
	if class_warn.is_empty():
		return
	class_warn = {}
	hud.close_overlay()
	if state == State.CITY:
		_build_city()


## Доручення: той, хто дає, у ратуші починає його або дякує за виконане (див. SideService). id — яке доручення.
func _side_dialogue(city: String, id: String) -> void:
	world.hero_level = player.level
	var d: Dictionary = SideService.city_dialogue(world, city, id)
	if d.is_empty():
		return
	var npc := _hall_npc(d["lines"])
	var dlg = DialogueScript.new()
	dlg.setup(StoryService.lines(world, d["lines"]), [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		var texts := []
		for m in SideService.on_dialogue_done(world, player, str(d["kind"]), str(d["id"])):
			texts.append(str(m["text"]))
		if not texts.is_empty():
			hud.show_banner("\n".join(texts.slice(0, 3)), UI.GOLD)
			Audio.play("quest", 0.0)
		save_game()
		if state == State.CITY and city_id == city:
			_build_city()
			_hall_continue("side", npc))  # дав нове доручення одразу — розмова триває
	hud.show_dialogue(dlg)


## Перекази: оповідач у ратуші починає крок лінійки або дякує за виконаний (див. LegendService).
## line — котра лінійка ("" — перша з тих, що чекають у цьому місті).
func _legend_dialogue(city: String, line: String = "") -> void:
	world.hero_level = player.level
	var d: Dictionary = LegendService.city_dialogue(world, city, line)
	if d.is_empty():
		return
	var npc := _hall_npc(d["lines"])
	var dlg = DialogueScript.new()
	dlg.setup(StoryService.lines(world, d["lines"]), [])
	dlg.finished.connect(func(_c):
		hud.close_dialogue()
		var texts := []
		for m in LegendService.on_dialogue_done(world, player, str(d["kind"]), str(d["line"]), str(d["id"])):
			texts.append(str(m["text"]))
		if str(d["kind"]) == "legend_end":
			_record("legend_step")
			_record("legend", LegendService.done_count(world))
		if not texts.is_empty():
			hud.show_banner("\n".join(texts.slice(0, 3)), UI.GOLD)
			Audio.play("quest", 0.0)
		save_game()
		if state == State.CITY and city_id == city:
			_build_city()
			_hall_continue("legend", npc, str(d["line"])))  # подякував за крок — одразу розкаже наступний
	hud.show_dialogue(dlg)


## Почати випробування: наставник пояснює, що робити.
func _start_trial(spec: String) -> void:
	if not SpecService.start(world, player, spec):
		return
	var dlg = DialogueScript.new()
	dlg.setup(SpecService.trial(spec)["start"], [])
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


## Розмова з побратимом у ратуші (зустріч, особисте завдання, його завершення).
func _hero_dialogue(city: String) -> void:
	var d := HeroService.city_dialogue(world, city)
	if d.is_empty():
		return
	var npc := _hall_npc(d["lines"])
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
			_hall_continue("hero", npc))
	hud.show_dialogue(dlg)


## Сюжетна розмова в ратуші. Якщо той самий співрозмовник одразу має наступну справу, розмова триває.
## id — крок розмови ("" — перша сюжетна розмова міста).
## Розмова, що здає крок із новим класом у нагороду (присяга козака, посвята волхва чи стрільця), — мить,
## коли клас справді змінюється: нижче вершини майстерності спершу попередження (warned — його вже прийнято).
func _story_dialogue(city: String, id: String = "", warned: bool = false) -> void:
	var d := StoryService.city_dialogue(world, city, id)
	if d.is_empty():
		return
	var to := StoryService.class_reward(d)
	if not warned and class_warn_needed(to):
		_show_class_warn(to, _story_dialogue.bind(city, str(d["id"]), true))
		return
	var npc := _hall_npc(d["lines"])
	var dlg = DialogueScript.new()
	dlg.setup(d["lines"], d["choices"])
	dlg.finished.connect(func(choice: int):
		hud.close_dialogue()
		var msgs := StoryService.on_dialogue_done(world, player, d["kind"], choice, str(d["id"]))
		if str(d["kind"]) == "saga_end":
			_record("saga", StoryService.SagaService.done_count(world))
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
			_hall_continue("story", npc))
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
	if combat.loc.has("hunt"):
		_on_boss_hunt_won(str(combat.loc["hunt"]))  # бос дня чи тижня: це не печера з мапи
		return
	for m in world.on_dungeon(loc_id):
		combat.float_text(player.global_position + Vector2(0, -110), m, UI.GOLD)
	if loc_id == DepthService.LOC_ID and combat.loc.has("depth"):
		var d: int = combat.loc["depth"]
		hud.show_banner(DepthService.on_clear(world, d), UI.GOLD)
		depth_sel = int(DepthService.state(world)["max"])
		_record("depth", d)
		_record("depth_clear")
		if randf() < 0.15 + 0.005 * d:
			StoneService.grant(player, "zabuttia" if randf() < 0.6 else "alatyr")
			combat.float_text(player.global_position + Vector2(0, -150), "Камінь долі з глибин!", Color(0.85, 0.7, 1.0))
	if PerilService.is_peril(loc_id):
		var pm: Array = PerilService.on_clear(world, player, loc_id, combat.run_time, slot)
		if not pm.is_empty():
			hud.show_banner("\n".join(pm), UI.GOLD)
		_record("peril")
		_record("peril_bosses", PerilService.bosses_down(world))
	_cleanse(loc_id)
	_record("dungeon")
	_spec_event("dungeon", loc_id)
	_story_event("dungeon", loc_id)
	_hero_event("dungeon", loc_id)


## Досягнення за повний набір: усі шість вдягнених речей з одного набору.
func _check_full_set() -> void:
	if int(world.stats.get("set_full", 0)) > 0:
		return
	var worn: Dictionary = Sets.count(player.equipment)
	for sid in worn:
		if int(worn[sid]) >= Data.slots().size():
			_record("set_full", 1)
			return


## Подія для викликів і досягнень; виконані показуються банером.
func _record(stat: String, amount: int = 1) -> void:
	var msgs := ChallengeService.record(world, player, stat, amount)
	if msgs.is_empty():
		return
	hud.show_banner("\n".join(msgs), Color(1.0, 0.85, 0.35))
	Audio.play("quest", 0.0)


func _on_level_up(lvl: int) -> void:
	_record("level", lvl)
	hud.show_banner("Рівень %d!\nВідкрий «Персонаж», щоб прокачатися" % lvl, UI.GOLD)
	hint("levelup", "Новий рівень! Натисни кнопку героя угорі праворуч: вклади очки в характеристики, вміння й перки.")


func _on_player_died() -> void:
	if combat.lost:
		return  # бій уже програно (здався чи впав): вдруге поразку не рахуємо
	if combat.is_duel():
		if combat.duel_over:
			# суперник упав першим: перемога вже зарахована, спроба лишається при героєві
			_soft_defeat("Перемога за тобою, та рани звалили з ніг.\nПобратими донесли тебе до куреня.", str(Acts.MUSTER_CITY) if combat.loc.get("muster", false) else "sich")
			return
		_duel_lost()
		return
	combat.lost = true
	if combat.is_vigil():
		_soft_defeat("Варту знято: нечисть прорвалась.\nПобратими винесли тебе з могили.", world.last_city)
		return
	if combat.is_ring():
		RingService.state(world)["runs"] = int(RingService.state(world)["runs"]) + 1
		_soft_defeat("Чудовисько взяло гору на колі %d.\nПобратими винесли тебе з валів." % (combat.ring_stage + 1), world.last_city)
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
	# Кара за смерть лягає одразу й одразу зберігається: згорнути гру, поки екран темніє, не поможе
	var lost := int(player.gold * Data.DEATH_GOLD_LOSS)
	player.gold -= lost
	# у надважкій печері смерть коштує більше досвіду, а отямлюється герой у таборі біля входу
	var peril_id: String = combat.loc_id if PerilService.is_peril(combat.loc_id) else ""
	var lost_xp: int = player.death_xp_loss(Peril.DEATH_XP_MULT if peril_id != "" else 1.0)
	save_game()
	await get_tree().create_timer(1.4).timeout
	if state != State.DEAD:
		return  # за цю мить гравець уже деінде (тест чи головне меню): екран поразки не потрібен
	_open_menu()
	hud.add_title("Козак поліг", 64, Color(1.0, 0.45, 0.35))
	var price := "Втрачено %d грн." % lost
	if lost_xp > 0:
		price = "Втрачено %d досвіду і %d грн." % [lost_xp, lost]
	hud.add_title("Побратими винесли тебе з бою. %s" % price, 24, UI.TEXT)
	if peril_id != "":
		hud.add_button("Отямитися в таборі біля входу", func(): _wake_at_camp(peril_id))
	else:
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
	map_legend = false
	map_bosses = false
	hud.map_view.selected = id
	_build_map_panel()


# ---------- Порадник ----------

var map_legend := false  # на панелі мапи показано пояснення позначок
var map_bosses := false  # на панелі мапи показано боса дня й боса тижня


## Оновити кнопку «Далі: …» на мапі: головна порада порадника.
func _refresh_guide() -> void:
	var g: Dictionary = GuideService.first(world, player, map_here)
	hud.map_view.set_guide(("Далі: %s  ›" % str(g["text"])) if not g.is_empty() else "")


## Дотик до кнопки «Далі: …»: показати місце поради на мапі або відкрити потрібну вкладку.
func _guide_go() -> void:
	if state != State.MAP or travel_to != "":
		return
	var g: Dictionary = GuideService.first(world, player, map_here)
	if g.is_empty():
		return
	if str(g["place"]) != "":
		_on_map_select(str(g["place"]))
		hud.map_view.focus_on(str(g["place"]))
	else:
		char_tab = int(g["tab"]) if int(g["tab"]) >= 0 else 1
		open_character()


## Сказати про заняття, яке щойно відкрилось героєві (по одному за вихід на мапу).
## Давнім героям про вже відкрите не нагадуємо: перший раз лише запам'ятовуємо, що вони мають.
func _announce_unlocks() -> void:
	var first_time: bool = not world.hints.has("unlocks_seen")
	world.hints["unlocks_seen"] = true
	for e in EventsBoard.Wiki.events():
		var key := "open:" + str(e["id"])
		if e["kind"] == "world" or world.hints.has(key) or EventsBoard.locked_reason(str(e["id"]), world, player) != "":
			continue
		world.hints[key] = true
		if first_time or int(e["level"]) <= 0:
			continue
		hud.show_hint("Відкрито нове заняття: %s. Де: %s. Торкнись його на вкладці «Події», щоб побачити на мапі." % [e["name"], e["where"]], true)
		return


func _build_map_panel() -> void:
	if map_legend and travel_to == "":
		hud.set_map_panel(MapPanel.build_legend(func():
			map_legend = false
			_build_map_panel()), _sponsor_block(), "legend")
		return
	if map_bosses and travel_to == "":
		hud.set_map_panel(MapPanel.build_bosses(world, player, func():
			map_bosses = false
			_build_map_panel(), start_boss), _sponsor_block(), "bosses")
		return
	if travel_to != "":
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.add_child(UI.label("У дорозі", 28, UI.GOLD, false))
		var l := UI.label(("Їдемо навпростець. Торкнись мапи, щоб поквапитись." if travel_to == POINT_ID else "Їдемо: %s. Торкнись мапи, щоб поквапитись." % Data.place_name(travel_to)), 18, UI.TEXT, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		hud.set_map_panel(v, null, "travel:" + travel_to)
		return
	if map_sel == DepthService.LOC_ID:
		# «Спуститися» це теж дорога: герой їде до Глибин мапою, бій починається після прибуття (_arrive)
		hud.set_map_panel(MapPanel.build_depths(world, player, depth_sel, func(d: int):
			depth_sel = d
			_build_map_panel(), func(d: int):
			depth_sel = d
			_go_to(DepthService.LOC_ID)), _sponsor_block(), "depths")
		return
	if map_sel == TowerService.LOC_ID:
		# «Піднятися» так само: спершу дорога до Башти, і лише стоячи під нею герой заходить одразу
		hud.set_map_panel(MapPanel.build_tower(world, player, tower_sel, func(f: int):
			tower_sel = f
			_build_map_panel(), func(f: int):
			tower_sel = f
			_go_to(TowerService.LOC_ID)), _sponsor_block(), "tower")
		return
	if Acts.is_spot(map_sel):
		hud.set_map_panel(MapPanel.build_spot(map_sel, world, player, _go_to), _sponsor_block(), "spot:" + map_sel)
		return
	if PerilService.is_peril(map_sel):
		hud.set_map_panel(MapPanel.build_peril(map_sel, world, player, _at(map_sel), _go_to, enter_peril, peril_camp_do), _sponsor_block(), "peril:" + map_sel)
		return
	hud.set_map_panel(MapPanel.build(map_sel, world, player, _go_to, StoryService.target(world), StoryService.objective_line(world), _go_escort, quick_raid), _sponsor_block(), "place:" + map_sel)


## Подарунки спонсора внизу панелі мапи: видно завжди, хоч би яке місце обране.
func _sponsor_block() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if DivineService.remote_shop(player) and travel_to == "":
		var tb := UI.button("Хованець: крамниця будь-де", func(): open_trader(enter_map), Vector2(340, 46), 16)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(tb)
	if not player.is_peasant() and not map_bosses and travel_to == "":
		var free: int = BossService.available(world, player)
		var bb := UI.button("Боси дня й тижня" + ("  •  чекають: %d" % free if free > 0 else ""), func():
			map_bosses = true
			map_legend = false
			_build_map_panel(), Vector2(340, 50), 17)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if free > 0:
			bb.modulate = Color(1.0, 0.95, 0.7)
		v.add_child(bb)
	if PremiumService.active(world):
		var pl := UI.label("%s: ×2 досвіду й ×2 здобичі діють постійно. Лишилось днів: %d" % [PremiumService.NAME, PremiumService.days_left(world)], 15, UI.GOLD, false)
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pl.custom_minimum_size = Vector2(320, 0)
		v.add_child(pl)
		return v
	v.add_child(UI.label("Подарунки спонсора за рекламу", 16, UI.GOLD, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for id in ["xp2", "drop2"]:
		var b := UI.button(AdRewards.boost_button_text(world, id), _watch_boost.bind(id, _build_map_panel), Vector2(166, 64), 15, AdRewards.can_boost(world, id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	v.add_child(row)
	return v


## Кнопка «Вирушити» на мапі: спершу поїздка фігуркою, прибуття — у _arrive.
## Вирушити з мандрівником: завдання міста на супровід у цій місцевості.
func _go_escort(id: String) -> void:
	_go_to(id, true)


func _go_to(id: String, escort: bool = false) -> void:
	if travel_to != "":
		return  # уже їдемо
	escort_go = id if escort else ""
	if _at(id):
		_arrive(id)
		return
	var a: Vector2 = _here_ll()
	var b: Vector2 = hud.map_view._place_ll(id)
	var dist: float = a.distance_to(b)  # градуси; Січ–Київ ≈ 5.3
	travel_to = id
	travel_t = 0.0
	travel_dur = clampf(1.2 + dist * 0.45, 1.5, 4.0) / (1.0 + 0.15 * player.pk("h_horse") + float(player.art.get("travel", 0.0)))
	travel_boost = 1.0
	travel_paused = false
	# Пригода в дорозі — посеред шляху (не для селянина, не частіше ніж дозволяє TravelService)
	travel_event_at = -1.0
	if not Data.is_city(id) and id != Camp.CAMP_ID and id != DepthService.LOC_ID and id != TowerService.LOC_ID and not Acts.is_spot(id) and not DefenseService.is_besieged(world, id) and EventService.battle_at(world, id).is_empty():
		pending_event = TravelService.roll(world, player)
		if not pending_event.is_empty():
			travel_event_at = randf_range(0.4, 0.65)
	hud.map_view.travel = {"from": map_here, "to": id, "t": 0.0}
	if map_at_point:
		hud.map_view.travel["from_ll"] = map_point  # виїжджаємо з вільної точки, а не з місця
	hud.map_view.selected = ""
	_build_map_panel()
	Audio.play("portal", 0.1, -8.0)


## Чи герой стоїть саме в цьому місці (а не просто десь на мапі неподалік).
func _at(id: String) -> bool:
	return map_here == id and not map_at_point


## Де герой зараз: довгота й широта місця або вільної точки.
func _here_ll() -> Vector2:
	return map_point if map_at_point else hud.map_view._place_ll(map_here)


## Вільне пересування: дотик до порожнього місця мапи, і герой їде просто туди. Пригод дорогою нема,
## бо це не похід. Далі до будь-якого місця він їде вже від цієї точки.
func _go_point(ll: Vector2) -> void:
	if state != State.MAP or travel_to != "" or player == null:
		return
	var mv = hud.map_view
	ll = Vector2(clampf(ll.x, mv.LON0 + mv.EDGE, mv.LON1 - mv.EDGE), clampf(ll.y, mv.LAT0 + mv.EDGE, mv.LAT1 - mv.EDGE))
	var a: Vector2 = _here_ll()
	var dist: float = a.distance_to(ll)
	if dist < 0.05:
		return
	escort_go = ""
	pending_event = {}
	travel_event_at = -1.0
	travel_to = POINT_ID
	travel_point = ll
	travel_t = 0.0
	travel_dur = clampf(0.3 + dist * 0.45, 0.5, 4.0) / (1.0 + 0.15 * player.pk("h_horse") + float(player.art.get("travel", 0.0)))
	travel_boost = 1.0
	travel_paused = false
	mv.travel = {"from": map_here, "to": POINT_ID, "t": 0.0, "from_ll": a, "to_ll": ll}
	mv.current_ll = null
	_build_map_panel()
	Audio.play("portal", 0.1, -14.0)


## Приїхали у вільну точку: герой стоїть просто на мапі.
func _arrive_point() -> void:
	travel_to = ""
	var mv = hud.map_view
	mv.travel = {}
	map_here = _nearest_place(travel_point)  # найближче місце: для порадника й подій
	map_at_point = true
	map_point = travel_point
	mv.current = ""
	mv.current_ll = map_point
	_build_map_panel()
	_refresh_guide()


## Найближче до точки місце мапи: місто, місцевість, хутір чи заняття.
func _nearest_place(ll: Vector2) -> String:
	var best := "sich"
	var best_d := INF
	for id in Data.city_ids() + Data.place_ids() + Acts.spot_ids() + [Camp.CAMP_ID]:
		var d: float = hud.map_view._place_ll(id).distance_to(ll)
		if d < best_d:
			best_d = d
			best = id
	return best


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
	elif Acts.is_spot(id):
		enter_spot(id)
	elif Data.is_city(id):
		if id != world.last_city and TradeService.should_ambush(world):
			start_ambush(id)  # на валку з крамом напали дорогою
		else:
			enter_city(id)
	elif not escort_q.is_empty():
		start_escort(escort_q)  # завдання міста: провести мандрівника
	elif PerilService.is_peril(id):
		_arrive_camp(id)  # надважка печера: спершу табір біля входу, у бій — кнопкою
	else:
		enter_location(id)


# ======================= Надважкі печери =======================

## Герой прибув до табору біля входу в надважку печеру: лишаємось на мапі, панель показує табір.
func _arrive_camp(id: String) -> void:
	map_here = id
	map_sel = id
	hud.map_view.current = id
	hud.map_view.current_ll = null  # приїхали з вільної точки: вершник стоїть у таборі, а не там
	hud.map_view.selected = id
	_build_map_panel()
	_refresh_guide()
	save_game()
	hint("peril_camp", "Табір біля входу до надважкої печери. Тут можна перепочити й купити зілля. Нечисть у печері сильніша за будь-якого героя, смерть коштує втричі більше досвіду, а бос лютішає, коли бій затягнувся.")


## Увійти з табору в печеру (кнопка на панелі мапи).
func enter_peril(id: String) -> void:
	var why: String = PerilService.block_reason(world, player, id)
	if why != "":
		hud.show_banner(why, UI.BAD)
		return
	enter_location(id)


## Справи в таборі біля надважкої печери: перепочинок і маркітант.
func peril_camp_do(action: String) -> void:
	match action:
		"rest":
			player.revive()
			world.revive_companions()
			Audio.play("quest", 0.1, -6.0)
			hud.show_banner("Перепочив біля вогнища: здоров'я й наснага повні", UI.GOOD)
		"potion":
			var price: int = PerilService.potion_price(player)
			if player.gold >= price and player.potions < player.potion_max() and player.add_potion():
				player.gold -= price
				Audio.play("coins", 0.05)
		"mana":
			var mprice: int = PerilService.mana_potion_price(player)
			if player.gold >= mprice and player.mana_potions < player.mana_potion_max() and player.add_mana_potion():
				player.gold -= mprice
				Audio.play("coins", 0.05)
	_build_map_panel()
	save_game()


## Після смерті в надважкій печері герой отямлюється в таборі біля входу, а не в далекому місті.
func _wake_at_camp(id: String) -> void:
	player.revive()
	world.revive_companions()
	map_here = id
	map_sel = id
	enter_map()
	_build_map_panel()


## Крок подорожі (викликається з _process, коли ми на мапі й їдемо).
func _travel_tick(delta: float) -> void:
	if travel_to == "" or travel_paused:
		return
	travel_t += delta / travel_dur * travel_boost * PremiumService.travel_mult(world) * PetService.travel_mult(player)  # універсал і кінь скорочують дорогу
	hud.map_view.travel["t"] = travel_t
	if travel_event_at > 0.0 and travel_t >= travel_event_at:
		travel_event_at = -1.0
		travel_paused = true
		_show_travel_event(pending_event, func():
			travel_paused = false)
		return
	if travel_t >= 1.0:
		if travel_to == POINT_ID:
			_arrive_point()
			return
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
	if not DepthService.unlocked(world, player.level):
		hud.show_banner("Глибини " + DepthService.lock_text(world, player.level, "відкриються").trim_suffix("."), UI.BAD)
		return
	depth = clampi(depth, 1, int(DepthService.state(world)["max"]))
	combat.custom_loc = DepthService.loc_for(depth)
	combat.custom_loc.merge(FarService.floor_mods(player, FarService.DEPTH_FLOOR))
	enter_location(DepthService.LOC_ID)
	hint("depths", "Глибини зарази: що глибше — то сильніші вороги й щедріша здобич. Пройдеш глибину — відкриється наступна.")


# ======================= Бос дня й бос тижня =======================

## Вийти на боса дня ("day") чи тижня ("week"). Бій іде поза мапою: герой лишається там, де стояв.
func start_boss(kind: String) -> void:
	if state != State.MAP or travel_to != "" or BossService.block_reason(world, player, kind) != "":
		return
	map_bosses = false
	var here := map_here
	var was_point := map_at_point
	combat.custom_loc = BossService.loc_for(player, kind)
	enter_location(DepthService.LOC_ID)
	map_here = here
	map_at_point = was_point  # бій із босом іде поза мапою: герой лишається там, де стояв, хоч би й у чистому полі
	Audio.play_music("boss")
	hint("boss_hunt", "Бос дня й бос тижня рівнем дорівнюють тобі й мають особливі властивості, щоразу інші. Перемогти кожного можна раз на день чи тиждень. Поразка спроби не забирає.")


func _on_boss_hunt_won(kind: String) -> void:
	var r: Dictionary = BossService.on_win(world, player, kind, combat.run_time, str(combat.loc.get("boss", "")))
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	var items: Array = r["items"]
	for i in items.size():
		combat.spawn_pickup(pos + Vector2(70.0 * (i - (items.size() - 1) / 2.0), 0), "item", 0, items[i], true)
	hud.show_banner("\n".join(r["msgs"]), UI.GOLD)
	_record("boss_" + kind)
	_record("dungeon")
	save_game()


# ======================= Башта Кощія =======================

func start_tower(floor_: int) -> void:
	if not TowerService.unlocked(player, world):
		hud.show_banner("Башта " + TowerService.lock_text(world, player.level, "відкриється").trim_suffix("."), UI.BAD)
		return
	floor_ = clampi(floor_, 1, int(TowerService.state(world)["max"]))
	tower_sel = floor_
	combat.custom_loc = TowerService.loc_for(floor_)
	combat.custom_loc.merge(FarService.floor_mods(player, FarService.TOWER_FLOOR))
	enter_location(TowerService.LOC_ID)
	hint("tower", "Башта Кощія: кожен поверх — хвилі нечисті й міні-бос, кожен п'ятий — супербос. Пройшов поверх — портал веде вище; вийти можна кнопкою «На мапу», коли поруч нема ворогів.")


func _on_tower_cleared(floor_: int) -> void:
	var r := TowerService.on_clear(world, floor_)
	var first: bool = r[1]
	var msg: String = r[0]
	tower_sel = clampi(floor_ + 1, 1, int(TowerService.state(world)["max"]))
	_record("tower", floor_)
	_record("tower_floor")
	var lvl := TowerService.loot_level(floor_)
	var pos: Vector2 = player.global_position + Vector2(0, -120)
	if first:
		var g := TowerService.first_gold(floor_)
		player.add_gold(g)
		msg += "\n+%d грн за перше проходження" % g
		if TowerService.is_super(floor_):
			var stone := "alatyr" if randf() < 0.4 else "zabuttia"
			StoneService.grant(player, stone)
			combat.spawn_pickup(pos, "item", 0, Data.gen_item(lvl + 1, 3), true)
			combat.float_text(pos + Vector2(0, -40), "Знайдено: %s!" % StoneService.name_of(stone), Color(0.85, 0.7, 1.0))
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
	var next_loc: Dictionary = TowerService.loc_for(nxt)
	next_loc.merge(FarService.floor_mods(player, FarService.TOWER_FLOOR))
	combat.next_floor(next_loc)


# ======================= Оборона =======================

var defense_target := ""  # куди повернутися після виграної оборони


## Бій біля брами обложеного міста чи хутора.
func start_defense(target: String) -> void:
	combat.defense_loc = DefenseService.battle_loc(world, target, player)
	enter_location("defense")
	map_here = target
	hint("defense", "Облога! Нечисть іде хвилями й ламає браму внизу. Стань між ними та брамою — коли брама впаде, оборону програно.")


# ======================= Герць на майдані =======================

## free — вільний герць поза турніром: до першої поразки, спроб не лічать.
func start_duel(free: bool = false) -> void:
	if free:
		if not DuelService.unlocked(player):
			hud.show_banner("На майдан зараз не вийти", UI.BAD)
			return
		combat.defense_loc = DuelService.free_loc(world, player)
	elif not DuelService.can_fight(world, player):
		hud.show_banner("На майдан зараз не вийти", UI.BAD)
		return
	else:
		combat.defense_loc = DuelService.battle_loc(world, player)
	enter_location("duel")
	map_here = "sich"
	_fight_begin("free" if free else "duel")
	hint("duel", "Герць — сам на сам. Червоні зони на землі показують, куди вдарить суперник: виходь із них або відбивай «Блоком». Смерті на майдані нема.")


## Бій на спроби почався: позначка лягає в збереження одразу. Якщо гру закриють посеред герцю,
## при наступному вході він рахується програним (див. load_game), тож спроби так не вберегти.
func _fight_begin(kind: String) -> void:
	meta["fight"] = kind
	save_game()


func _on_duel_won() -> void:
	meta.erase("fight")
	if combat.loc.get("muster", false):
		defense_target = str(Acts.MUSTER_CITY)  # з порталу — назад у Чигирин
		world.revive_companions()  # на огляді б'ються до першої крові: поранених нема
		hud.show_banner("\n".join(MusterService.win(world, player)), UI.GOLD)
		_record("muster")
		if MusterService.is_winner(world):
			_record("muster_champion")
		save_game()
		return
	defense_target = "sich"  # з порталу — назад на Січ
	if combat.loc.get("free", false):
		hud.show_banner("\n".join(DuelService.free_win(world, player)), UI.GOLD)
		_record("duel")
		_record("duel_free")
		_record("duel_streak", int(DuelService.state(world)["streak"]))
		save_game()
		return
	var msgs := DuelService.win(world, player)
	hud.show_banner("\n".join(msgs), UI.GOLD)
	_record("duel")
	if DuelService.is_champion(world):
		_record("duel_champion")
	save_game()


## Поразка чи здача в герці: без втрат, лише мінус спроба; повертаємось на Січ.
func _duel_lost() -> void:
	if combat.lost or state == State.DEAD:
		return  # уже програно: здався, а за мить ще й упав — спроба списується один раз
	meta.erase("fight")
	if combat.loc.get("muster", false):
		world.revive_companions()
		_soft_defeat(MusterService.lose(world), str(Acts.MUSTER_CITY))
		return
	_soft_defeat(DuelService.free_lose(world) if combat.loc.get("free", false) else DuelService.lose(world), "sich")


# ======================= Гетьманський огляд =======================

## Сутичка ватаг у Чигирині: герой із побратимами проти сотні (див. MusterService).
func start_muster() -> void:
	if not MusterService.can_fight(world, player):
		hud.show_banner("На огляд зараз не вийти", UI.BAD)
		return
	combat.defense_loc = MusterService.battle_loc(world, player)
	enter_location("duel")
	map_here = str(Acts.MUSTER_CITY)
	_fight_begin("muster")
	hint("muster", "Огляд: гурт на гурт. Побратими б'ються поруч і відвертають удари на себе. Спершу клади стрільців і тих, хто насідає на знахарку.")


## Поразка без втрат (герць, варта): показати повідомлення й за мить отямитись у місті.
func _soft_defeat(text: String, city: String) -> void:
	combat.lost = true
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
	combat.festive = HolidayService.combat_mods()
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
	var H: Dictionary = Acts.holiday(id)
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
	match str(Acts.spot(id)["kind"]):
		"vigil":
			start_vigil()
		"ring":
			start_ring()
		"hunt":
			start_hunt()
		"fish":
			start_fishing()
		_:
			enter_map()


# ======================= Полювання й рибалка =======================

## Чому зараз не можна полювати чи рибалити ("" — можна).
func _outdoor_block(kind: String) -> String:
	var S: Dictionary = Acts.spot(kind)
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
	if player.costume != "":
		# у вбранні з крамниці герой і на полюванні, і на рибалці
		var cid: String = player.Costumes.sprite(player.costume, "bow") if kind == "hunter" else player.Costumes.plain(player.costume)
		if Gfx.has(cid):
			return cid
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
		hud.show_banner("На варту беруть із %d-го рівня й лише тих, хто обрав дорогу" % int(Acts.spot(VigilService.SPOT_ID)["level"]), UI.BAD)
		return
	combat.defense_loc = VigilService.battle_loc(player)
	enter_location("vigil")
	map_here = VigilService.SPOT_ID
	hint("vigil", "Варта: нечисть суне без упину й щохвилини лютішає. Вистій п'ять хвилин — відкриється портал. Можна стояти й далі, на рекорд. Смерті на варті нема.")


# ======================= Коло Кожум'яки =======================

func start_ring() -> void:
	if not RingService.unlocked(player):
		hud.show_banner("У коло стають із %d-го рівня й лише ті, хто обрав дорогу" % int(Acts.spot(RingService.SPOT_ID)["level"]), UI.BAD)
		return
	combat.defense_loc = RingService.battle_loc(player)
	enter_location("ring")
	map_here = RingService.SPOT_ID
	hint("ring", "Коло Кожум'яки: три чудовиська поспіль. Між ними є кілька секунд, щоб підібрати вареники й перевести дух. Смерті тут нема.")


## Чудовисько кола stage (1..3) здолано: гаманець, слава, а за всі три — річ, трофеї й запис у Літопис.
func _on_ring_stage(stage: int) -> void:
	var first_week: bool = int(RingService.state(world)["paid"]) < int(Acts.RING_STAGES)
	var r := RingService.on_stage(world, player, stage)
	var lines := []
	var head := "Коло %d за тобою!" % stage
	if int(r["gold"]) > 0:
		head += " +%s грн" % UI.num(int(r["gold"]))
		if int(r["glory"]) > 0:
			head += ", +%d слави" % int(r["glory"])
	elif not r["weekly"]:
		head += " (гаманці на сьогодні роздано)"
	lines.append(head)
	lines.append_array(r["msgs"])
	_record("ring")
	if stage >= int(Acts.RING_STAGES):
		var t: float = combat.ring_time
		var f := RingService.finish(world, player, t, first_week)
		lines[0] = "Коло Кожум'яки пройдено за %s!" % RingService.time_text(t) + lines[0].substr(lines[0].find("!") + 1)
		if f["record"]:
			lines.append("Новий рекорд часу")
		if int(f["item"]) >= 0:
			combat.spawn_pickup(player.global_position + Vector2(0, -110), "item", 0, Data.gen_item(player.level, int(f["item"])), true)
			lines.append("Рідкісна річ і %d трофеї" % int(f["trophy"]))
		_record("ring_clear")
		if t < float(Acts.RING_FAST):
			_record("ring_fast")
	hud.show_banner("\n".join(lines), UI.GOLD)
	save_game()


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
			combat.spawn_pickup(pos, "item", 0, Data.gen_item(player.level, int(r["item"])), true)
		for msg in r["msgs"]:
			text += "\n" + msg
	elif m <= goal_min:
		text += "\n(нагороду за цю хвилину сьогодні вже взято)"
	hud.show_banner(text, UI.GOLD)
	_record("vigil", m)
	_record("vigil_min")
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
	combat.defense_loc = EscortService.battle_loc(q, player)
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
		_leave_lost_defense("")
		return
	if combat.loc.get("ambush", false):
		hud.show_banner(TradeService.lose_half(world), UI.BAD)
		save_game()
		_leave_lost_defense(target)
		return
	var ev := EventService.battle_at(world, target)
	if not ev.is_empty():
		hud.show_banner(EventService.lose(world, player, ev), UI.BAD)
		save_game()
		_leave_lost_defense("")
		return
	if not DefenseService.is_besieged(world, target):
		return
	hud.show_banner(DefenseService.lose(world, player, target), UI.BAD)
	save_game()
	_leave_lost_defense("")


## Програну оборону покидаємо за мить: у місто city або на мапу. Якщо саме тоді відкрито паузу чи
## екран героя, чекаємо, поки їх закриють: раніше герой у такому разі лишався в програному бою.
func _leave_lost_defense(city: String) -> void:
	await get_tree().create_timer(2.5).timeout
	while is_inside_tree() and combat.active and combat.is_defense() and combat.defense_over and (state == State.PAUSED or state == State.CHARACTER):
		await get_tree().create_timer(0.25).timeout
	if not is_inside_tree() or state != State.PLAYING or not combat.is_defense() or not combat.defense_over:
		return
	if city != "":
		enter_city(city)
	else:
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
	hud.set_screen(UiCity.build(self, city_id), "city:" + city_id)


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
					hud.show_banner("Лояльність зросла!\n%s: %s" % [Data.place_name(q["city"]), Data.loyalty_name(world.loyalty_level(q["city"]))], UI.GOOD)
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
				city_sel_uid = -1  # куплена річ уже в торбі: другий дотик по тій самій кнопці не має її продати
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
		"sharpen_safe":
			_sharpen(arg, 1.0, 0.0, true)
		"socket", "soul_in", "soul_out":
			_soul_action(action, arg, 1.0)
		"hire":
			CityService.hire(world, player, city_id, arg)
		"buy_potion":
			if CityService.buy_potion(world, player, city_id):
				Audio.play("coins", 0.05)
		"buy_mana_potion":
			if CityService.buy_mana_potion(world, player, city_id):
				Audio.play("coins", 0.05)
		"ad_safe":
			_ad("safe_sharpen", func(ok: bool):
				if ok and AdRewards.grant_safe(world):
					hud.show_banner("+1 безпечна заточка" if PremiumService.active(world) else "Дякуємо! +1 безпечна заточка", UI.GOOD)
				save_game()
				if state == State.CITY:
					_build_city())
			return
		"dismiss":
			CityService.dismiss(world, arg)
		"exp_send":
			if ExpeditionService.send(world, arg[0], arg[1]):
				Audio.play("quest", 0.0)
				hud.show_banner("%s вирушає: %s" % [HeroService.member_name(world.companions[arg[0]]), str(Acts.expedition(arg[1])["name"]).to_lower()], UI.GOLD)
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
		"duel_free":
			start_duel(true)
			return
		"muster_start":
			start_muster()
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
	if trader_open:
		hud.set_screen(_trader_screen(), "trader")  # крамниця Хованця: ті самі дії, інший екран
	else:
		_build_city()
	dice_anim = {}  # анімація кидка стосується лише цього показу


## paid_safe — заточка без ризику за гривні: утричі дорожча, зате невдача не знижує рівень (жетон не витрачається).
func _sharpen(uid: int, cost_mult: float = 1.0, chance_bonus: float = 0.0, paid_safe: bool = false) -> void:
	var before: int = player.find_item(uid).get("up", 0)
	var risky := before >= Data.SHARPEN_RISK_FROM
	var paid := paid_safe and risky
	if paid:
		cost_mult *= Data.SHARPEN_SAFE_MULT
	# Жетон безпечної заточки витрачається лише на ризиковану спробу
	var safe := paid or (risky and AdRewards.use_safe(world))
	match player.sharpen(uid, cost_mult, chance_bonus + HolidayService.bonus("sharpen"), safe):  # на Кузьми й Дем'яна ковалям щастить
		"ok":
			Audio.play("sharpen_ok", 0.03)
			_record("sharpen")
			smith_msg = "Успіх! Тепер +%d" % (before + 1)
			smith_msg_color = UI.GOOD
		"fail":
			Audio.play("sharpen_fail")
			smith_msg = "Не вдалося... Заточка лишилась +%d" % before
			if paid:
				smith_msg += " (заплачено за безпеку)"
			elif safe:
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
	hud.hide_hint()  # підказка «відкрий Персонаж» не має затуляти кнопки на самому екрані
	hud.show_map(false)
	hud.set_mode(false, false)
	char_sel_uid = -1
	Audio.play("page", 0.08)
	RecordService.sync(world, player, slot)  # щоб вкладка «Слава» показувала свіже
	_build_character()


func _build_character() -> void:
	hud.set_screen(UiCharacter.build(self), "character")


func char_do(action: String, arg) -> void:
	if not (action.begins_with("stone_") or action == "destroy"):
		confirm_action = ""
	match action:
		"stat":
			player.add_stat(arg)
		"skill":
			player.learn_skill(arg)
		"perk":
			player.learn_perk(arg)
		"valor":
			player.add_valor(arg)
		"select":
			char_sel_uid = arg
		"divine_toggle":
			# вдягнути чи зняти божий дар у його гнізді
			var dslot: String = str(DivineService.Divine.def(str(arg))["slot"])
			if DivineService.wears(player, str(arg)):
				DivineService.unequip(world, player, dslot)
			else:
				DivineService.equip(world, player, str(arg))
			Audio.play("item", 0.05)
		"auto_buffs":
			# перемикач авто-бафів Німба на картці дару: окремо для кожного героя
			player.auto_buffs = not player.auto_buffs
		"divine_shop":
			# некуплений дар: веде в крамницю на вкладку «Божі дари»
			shop_tab = _shop_tab_index("Божі дари")
			open_shop(_build_character)
			return
		"trader":
			# крамниця Хованця просто з екрана героя: на мапі, в місті, на хуторі й посеред бою
			open_trader(_build_character)
			return
		"equip":
			player.equip(arg)
			_check_full_set()
		"unequip":
			player.unequip(arg)
		"destroy":
			# знищити річ назавжди: другий дотик підтверджує
			if confirm_action != "destroy:%d" % arg:
				confirm_action = "destroy:%d" % arg
			else:
				confirm_action = ""
				SoulService.strip(player, player.remove_from_bag(arg))  # душа зі знищеної речі вертається в торбинку
				char_sel_uid = -1
		"drop":
			# викинути на землю: лише в бою, де є земля; річ можна підняти знову
			if char_return == State.PLAYING:
				var gone: Dictionary = player.remove_from_bag(arg)
				if not gone.is_empty():
					SoulService.strip(player, gone)  # душа з викинутої речі вертається в торбинку
					combat.drop_item(gone)
					char_sel_uid = -1
		"socket", "soul_in", "soul_out":
			_soul_action(action, arg, 1.0)
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
			# вміння вибрано з кнопки бою: показати дерево, де воно росте
			for c in player.Classes.lineage(player.job):
				for br in player.Classes.tree(c):
					for n in br["nodes"]:
						if n["id"] == arg:
							skill_tree = c
		"skill_tree":
			skill_tree = arg
			skill_sel = ""
		"event_show":
			if _show_event_place(str(arg)):
				return  # екран героя закрито, відкрито мапу
		"place_show":
			# arg: [місце, назва завдання]
			if _show_place(str(arg[0]), str(arg[1])):
				return
		"tab_show":
			char_tab = int(arg)  # порада веде на іншу вкладку екрана героя
		"equip_best":
			var worn: int = player.equip_best()
			if worn > 0:
				char_sel_uid = -1
				Audio.play("item", 0.0)
				hud.show_banner("Вдягнено кращих речей: %d" % worn, UI.GOLD)
		"way_claim":
			# «Шлях козака»: забрати все, що вже виконано
			var wm := WayService.claim_all(world, player)
			if not wm.is_empty():
				hud.show_banner("\n".join(wm), UI.GOLD)
				Audio.play("quest", 0.0)
				save_game()
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


## Дотик до події на вкладці «Події»: показати її місце на мапі. Повертає true, якщо мапу відкрито.
func _show_event_place(id: String) -> bool:
	var E: Dictionary = EventsBoard.info(id)
	if id == "challenges":
		char_tab = UiCharacter.TAB_CHALLENGES
		return false
	var place: String = EventsBoard.place(id, world, map_here)
	if place == "":
		hud.show_banner("%s\nОкремого місця на мапі зараз нема: %s" % [E.get("name", ""), str(E.get("where", "")).to_lower()], UI.MUTED)
		return false
	return _show_place(place, str(E.get("name", "")))


## Закрити екран героя й показати місце на мапі: навести на нього й вибрати. title — про що йдеться.
## У бою мапа не відкривається (похід урвався б): гра лише називає місце. Повертає true, якщо мапу відкрито.
func _show_place(place: String, title: String) -> bool:
	if char_return == State.PLAYING:
		hud.show_banner("%s: %s\nМапа покаже це місце після бою" % [title, Data.place_name(place)], UI.GOLD)
		return false
	hud.clear_screen()
	map_sel = place
	enter_map()
	hud.map_view.focus_on(place)
	return true


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

## key і child: див. Hud.open_overlay; меню, що перемальовує себе, і повернення з підменю
## лишають прокрутку на місці.
func _open_menu(key: String = "", child: bool = false) -> void:
	hud.open_overlay(key, child)
	get_tree().paused = true


var _menu_back := Callable()  # куди веде «Назад» із підменю головного меню (порожнє на самому меню)


## Скидає все, що могло лишитись від попереднього екрана чи героя: відкриті крамниці, ціль порталу
## після оборони, вибране на мапі й у крамниці, ціни ярмарку. Без цього воно спливало в наступній грі.
func _reset_session() -> void:
	if trader_open:
		city_id = _trader_prev_city
	trader_open = false
	_trader_back = Callable()
	shop_open = false
	_shop_back = Callable()
	shop_confirm = ""
	wiki_open = false
	defense_target = ""
	leave_notice = ""
	map_sel = ""
	map_legend = false
	city_sel_uid = -1
	char_sel_uid = -1
	camp_sel_uid = -1
	chest_sel = ""
	sell_multi = false
	sell_marked.clear()
	confirm_action = ""
	class_warn = {}
	_name_closed()
	Data.sell_mult = 1.0


func _show_main_menu() -> void:
	state = State.MENU
	_menu_back = Callable()
	_reset_session()
	hud.clear_screen()  # екран, з якого сюди прийшли (крамниця, герой), під меню не лишається
	Audio.play_music("menu")
	Audio.play_ambient("")
	hud.set_mode(false, false)
	hud.show_map(false)  # з привалу на мапі сюди теж приходять: мапа під меню зайва
	if use_slots:
		SaveSystem.migrate_single_to_slots()  # перший запуск після оновлення: hero.save → слот 1
		save_path = SaveSystem.slot_path(slot)
	_open_menu("main")
	hud.add_title("Козацька Звитяга", 72)
	hud.add_title("З Кремля повзе чорна зараза Путіноїда. Козаче, рушай у похід!", 24, UI.TEXT)
	if use_slots:
		var sums := SaveSystem.slot_summaries()
		var any := false
		for s_ in sums:
			if not s_.is_empty():
				any = true
		var pick := continue_slot(sums, slot)
		if any and pick > 0:
			slot = pick  # запам'ятований слот порожній чи не читається: пропонуємо першого читабельного героя
			save_path = SaveSystem.slot_path(slot)
			hud.add_button("Продовжити: " + _slot_title(sums[slot - 1]), _continue_game)
		hud.add_button("Персонажі", _show_heroes_menu)
		if not any:
			hud.add_button("Нова гра", _ask_new_hero.bind(_show_main_menu))
	elif SaveSystem.exists(save_path):
		hud.add_button("Продовжити", _continue_game)
		hud.add_button("Нова гра", _confirm_new_game)
	else:
		hud.add_button("Нова гра", _ask_new_hero.bind(_show_main_menu))
	hud.add_button("Довідник", func(): open_wiki(_show_main_menu))
	if account_notice != "":
		hud.add_title(account_notice, 20, UI.BAD)
	_add_sound_toggles(_show_main_menu)
	hud.add_title("Ліва частина екрана — рух, праворуч — удар, перекид і вміння.\nНа мапі обирай міста, дикі місцевості та печери.", 18, Color(0.8, 0.8, 0.8))


## Підпис слота у два рядки: «Сірко • Козак 12» і «Розділ II • 3 год 20 хв».
## Ім'я стоїть першим і ніколи не обрізається. max_w (ширина тексту кнопки, шрифт font): якщо
## перший рядок не влазить, ім'я йде окремим рядком, а клас переходить у другий замість часу гри.
func _slot_title(s_: Dictionary, max_w: float = 0.0, font: int = 20) -> String:
	var cls: String = ClassesData.info(s_["job"]).get("name", "Герой")
	if s_.get("rank", "") == "hetman":
		cls = "Гетьман"
	var story := "сюжет пройдено" if s_["done"] else ("Пролог" if s_["chapter"] == 0 else "Розділ %s" % ["", "I", "II", "III", "IV", "V"][mini(5, s_["chapter"])])
	var h := int(s_["playtime"]) / 3600
	var m := (int(s_["playtime"]) % 3600) / 60
	var head := "%s %d" % [cls, s_["level"]]
	var tail := "%s • %d год %02d хв" % [story, h, m]
	var nick := str(s_.get("nick", ""))
	if nick == "":
		return head + "\n" + tail
	var one := nick + " • " + head
	if max_w > 0.0 and ThemeDB.fallback_font.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x > max_w:
		return nick + "\n" + head + " • " + story
	return one + "\n" + tail


## Текст кнопки «грати» в меню «Персонажі»: має влізти в HERO_ROW_PLAY шрифтом 20.
func _slot_row_text(s_: Dictionary, current: bool) -> String:
	var lead := "▶ " if current else ""
	var room: float = HERO_ROW_PLAY - HERO_ROW_PAD - ThemeDB.fallback_font.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	return lead + _slot_title(s_, room)


## Екран «Персонажі»: до 5 слотів — грати, новий, видалити.
func _show_heroes_menu() -> void:
	_open_menu("heroes", true)
	_menu_back = _show_main_menu
	hud.add_title("Персонажі", 56)
	hud.add_title("Хутір, скриня, досягнення й виклики — спільні для всіх.", 20, UI.TEXT)
	var sums := SaveSystem.slot_summaries()
	for i in SaveSystem.MAX_SLOTS:
		var s_: Dictionary = sums[i]
		var n := i + 1
		if s_.is_empty():
			hud.add_button("Слот %d — новий персонаж" % n, _ask_new_hero.bind(_show_heroes_menu, n), Vector2(620, 64))
		elif s_.get("broken", false):
			# файл є, та не читається: показуємо як є, а не вільним слотом. Затерти можна лише свідомо, хрестиком.
			var bad := UI.button("Слот %d: збереження не читається" % n, func():
				hud.show_banner("Це збереження зіпсоване або з новішої версії гри.\nОнови гру. Якщо не поможе, слот можна звільнити хрестиком.", UI.BAD), Vector2(520, 64), 20)
			var del_bad := UI.button("✕", func(): _confirm_delete_slot(n), Vector2(84, 64), 24)
			hud.add_row([bad, del_bad])
		else:
			var play := UI.button(_slot_row_text(s_, n == slot), func():
				slot = n
				save_path = SaveSystem.slot_path(n)
				_continue_game(), Vector2(HERO_ROW_PLAY, 64), 20)
			var ren := UI.button("Ім'я", _ask_rename.bind(n), Vector2(84, 64), 20)
			var del := UI.button("✕", func(): _confirm_delete_slot(n), Vector2(84, 64), 24)
			hud.add_row([play, ren, del])
	hud.add_button("Перенести на інший пристрій", _show_transfer_menu, Vector2(620, 56))
	hud.add_button("Назад", _show_main_menu)


# ---------- Перенесення роду між пристроями (див. SaveTransfer) ----------

var transfer_buffer := ""  # початок коду, коли його вставляють частинами


## Файли роду на цьому пристрої: {слот: шлях}.
func _transfer_paths() -> Dictionary:
	var out := {}
	if not use_slots:
		out[1] = save_path
		return out
	for i in range(1, SaveSystem.MAX_SLOTS + 1):
		out[i] = SaveSystem.slot_path(i)
	return out


func _show_transfer_menu(note: String = "", col: Color = UI.TEXT) -> void:
	_open_menu("transfer", true)
	_menu_back = _transfer_back
	hud.add_title("Перенесення роду", 52)
	hud.add_title("Усі персонажі, хутір і скриня одним кодом.\nСкопіюй код тут, надішли його собі (пошта, нотатки, месенджер)\nі встав на іншому пристрої в цьому ж меню.", 20, UI.TEXT)
	if note != "":
		hud.add_title(note, 22, col)
	hud.add_button("Скопіювати код роду", transfer_copy, Vector2(620, 64))
	hud.add_button("Вставити код" if transfer_buffer == "" else "Вставити наступну частину", transfer_paste, Vector2(620, 64))
	if SaveTransfer.has_backup(_transfer_paths(), account_path):
		hud.add_button("Повернути рід, який був до перенесення", transfer_restore, Vector2(620, 56))
	hud.add_button("Назад", _transfer_back)


func _transfer_back() -> void:
	transfer_buffer = ""
	if use_slots:
		_show_heroes_menu()
	else:
		_show_main_menu()


func transfer_copy() -> void:
	if player != null and state != State.MENU:
		save_game()
	var profile := SaveTransfer.collect(_transfer_paths(), account_path)
	if profile["heroes"].is_empty():
		_show_transfer_menu("На цьому пристрої ще немає персонажів.", UI.BAD)
		return
	var code := SaveTransfer.pack(profile)
	SaveTransfer.clipboard_set(code)
	_show_transfer_menu("Код скопійовано: %d знаків, персонажів: %d.\nВстав його в лист чи нотатку й відкрий на іншому пристрої." % [code.length(), profile["heroes"].size()], UI.GOOD)


func transfer_paste() -> void:
	var clip := SaveTransfer.clipboard_get().strip_edges()
	if clip.begins_with("KZ") or transfer_buffer == "":
		transfer_buffer = clip  # новий код із початку
	elif not transfer_buffer.ends_with(clip):
		transfer_buffer += clip  # продовження: месенджер розрізав код на кілька повідомлень
	var r := SaveTransfer.unpack(transfer_buffer)
	if r["partial"]:
		_show_transfer_menu("Вставлено %d із %d знаків.\nСкопіюй наступну частину повідомлення й натисни «Вставити наступну частину»." % [r["have"], r["need"]], UI.GOLD)
		return
	transfer_buffer = ""
	if not r["ok"]:
		_show_transfer_menu(r["error"], UI.BAD)
		return
	_transfer_confirm(r["profile"])


func _transfer_confirm(profile: Dictionary) -> void:
	_open_menu("transfer_confirm", true)
	_menu_back = _show_transfer_menu
	hud.add_title("Замінити рід на цьому пристрої?", 44)
	hud.add_title("У коді:\n" + "\n".join(SaveTransfer.summary(profile)), 22, UI.GOLD)
	hud.add_title("Нинішні персонажі, хутір і скриня на цьому пристрої зникнуть.\nЇх можна буде повернути в цьому ж меню до наступного перенесення.", 20, UI.TEXT)
	hud.add_button("Так, замінити", transfer_apply.bind(profile), Vector2(620, 64))
	hud.add_button("Ні", _show_transfer_menu, Vector2(620, 64))


func transfer_apply(profile: Dictionary) -> void:
	if not SaveTransfer.apply(profile, _transfer_paths(), account_path):
		_show_transfer_menu("Не вдалося записати рід. На пристрої все лишилось, як було.", UI.BAD)
		return
	_forget_hero()
	if use_slots:
		slot = int(profile["heroes"][0]["slot"])
		save_path = SaveSystem.slot_path(slot)
		_remember_slot()
	_show_transfer_menu("Рід перенесено. Персонажів: %d." % profile["heroes"].size(), UI.GOOD)


func transfer_restore() -> void:
	if SaveTransfer.restore(_transfer_paths(), account_path):
		_forget_hero()
		_show_transfer_menu("Повернуто рід, який був до перенесення.", UI.GOOD)
	else:
		_show_transfer_menu("Запасу немає.", UI.BAD)


## Після заміни файлів героя в пам'яті більше не існує: інакше перше ж автозбереження затерло б перенесене.
func _forget_hero() -> void:
	if player != null:
		player.queue_free()
		player = null
		combat.player = null
	account = AccountScript.new()


func _confirm_delete_slot(n: int) -> void:
	_open_menu("delete", true)
	_menu_back = _show_heroes_menu
	hud.add_title("Видалити персонажа зі слота %d?" % n, 44)
	hud.add_title("Хутір і скриня лишаться — вони спільні. Самого героя не повернути.", 22, UI.TEXT)
	hud.add_button("Так, видалити", func():
		SaveSystem.delete(SaveSystem.slot_path(n))
		_show_heroes_menu())
	hud.add_button("Ні", _show_heroes_menu)


func _confirm_new_game() -> void:
	_open_menu("new_game", true)
	_menu_back = _show_main_menu
	hud.add_title("Почати нову гру?", 48)
	hud.add_title("Поточне збереження буде втрачено.", 24, UI.TEXT)
	hud.add_button("Так, нова гра", _ask_new_hero.bind(_show_main_menu))
	hud.add_button("Ні", _show_main_menu)


# ---------- Ім'я героя: «Як тебе звати» (правила в NameService) ----------

const HERO_ROW_PLAY := 420  # ширина кнопки «грати» в рядку слота: з «Ім'я» й «✕» разом 620, як решта меню
const HERO_ROW_PAD := 32.0  # поля кнопки довкола тексту
const NAME_SPACER := 320  # порожнеча під екраном імені: поле й кнопки стоять у верхній половині, над клавіатурою

var ask_name := true  # тести вимикають, щоб старі герої без імені не спинялись на екрані імені
var naming := ""  # відкрито екран імені: "new" (новий герой), "first" (старий герой без імені), "rename"
var name_edit: LineEdit = null
var name_why: Label = null
var _name_done := Callable()  # що зробити з іменем, що пройшло перевірку
var _name_back := Callable()  # куди веде «Назад» (порожнє: вийти без імені не можна)
var _name_paused := false
var _name_overlay := Color(0, 0, 0, 0.72)  # звичайне тло меню, повертається, коли екран імені закрито


## Один екран на три випадки. start: чим одразу заповнене поле.
func _name_screen(kind: String, start: String, back: Callable, done: Callable, sub: String) -> void:
	if naming == "":
		_name_overlay = hud.overlay.color
	naming = kind
	_name_back = back
	_name_done = done
	_name_paused = get_tree().paused
	_open_menu("name", true)
	# суцільне тло: крізь екран імені не просвічують ні мапа, ні банери, ні підказка
	hud.overlay.color = Color(0.03, 0.03, 0.025, 1.0)
	_menu_back = Callable()  # «Назад» тут розбирає go_back за naming
	hud.add_title("Нове ім'я героя" if kind == "rename" else "Як тебе звати?", 44)
	hud.add_title(sub, 20, UI.TEXT)
	name_edit = LineEdit.new()
	# max_length полю не ставимо: Android рахує межу клавіатури один раз, коли вона відкривається,
	# віднімаючи текст, що вже стоїть у полі (жереб), хоч гравець пише поверх нього. Тоді «16» стає «5».
	# Довжину стереже NameService.check: причина червоним під полем, а «Готово» задовге не приймає.
	name_edit.text = start
	name_edit.custom_minimum_size = Vector2(520, 68)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.select_all_on_focus = true  # дотик виділяє запропоноване ім'я: своє пишеться одразу поверх
	name_edit.placeholder_text = "Ім'я героя"
	name_edit.add_theme_font_size_override("font_size", 30)
	name_edit.text_changed.connect(func(_t): _name_hint())
	name_edit.text_submitted.connect(func(_t): name_submit())
	hud.add_row([name_edit, UI.button("Кинути жереб", name_roll, Vector2(230, 68), 22)])
	name_why = UI.label("", 20, UI.TEXT)
	name_why.custom_minimum_size = Vector2(0, 28)
	hud.overlay_box.add_child(name_why)
	var btns := []
	if back.is_valid():
		btns.append(UI.button("Назад", _name_cancel, Vector2(230, 64), 24))
	btns.append(UI.button("Готово", name_submit, Vector2(300, 64), 26))
	hud.add_row(btns)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, NAME_SPACER)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.overlay_box.add_child(spacer)
	_name_hint()


## Рядок під полем: причина, коли ім'я не годиться, інакше коротко правила.
func _name_hint() -> void:
	if name_why == null or not is_instance_valid(name_why) or name_edit == null or not is_instance_valid(name_edit):
		return
	var why := NameService.check(name_edit.text)
	name_why.text = why if why != "" else "Від 3 до 16 знаків: літери, цифри, пробіл, дефіс, апостроф"
	name_why.add_theme_color_override("font_color", UI.BAD if why != "" else UI.MUTED)


## Екран імені закрито (будь-яким шляхом): тло меню знову звичайне.
func _name_closed() -> void:
	if naming != "":
		hud.overlay.color = _name_overlay
	naming = ""
	_name_done = Callable()
	_name_back = Callable()


func name_roll() -> void:
	if name_edit != null and is_instance_valid(name_edit):
		name_edit.text = NameService.roll()
		_name_hint()


## «Готово»: поки ім'я не пройшло перевірку, нічого не робить (причина видна під полем).
func name_submit() -> void:
	if naming == "" or name_edit == null or not is_instance_valid(name_edit):
		return
	var n := NameService.clean(name_edit.text)
	if NameService.check(n) != "":
		_name_hint()
		return
	var done := _name_done
	_name_closed()
	done.call(n)


func _name_cancel() -> void:
	var back := _name_back
	if naming == "" or not back.is_valid():
		return  # старий герой без імені: вийти без імені не можна, жереб уже в полі
	_name_closed()
	back.call()


## Кнопки «Нова гра» й «Слот N: новий персонаж»: спершу ім'я, тоді гра. n: слот (0: нинішній).
func _ask_new_hero(back: Callable, n: int = 0) -> void:
	_name_screen("new", NameService.roll(), back, func(nick: String):
		if n > 0:
			slot = n
			save_path = SaveSystem.slot_path(n)
		new_game(nick), "Ім'я видно в меню героїв і в Літописі слави. Змінити його можна будь-коли.")


## Старий герой без імені: після входу в гру, один раз. Запропоноване прізвисько проходить одним дотиком.
## banners: лічильник банерів перед входом. Банер, показаний відтоді, гравець не бачив за екраном імені,
## тож після «Готово» останній такий банер показується знову.
func _ask_first_name(banners: int = -1) -> void:
	if banners < 0:
		banners = hud.banner_count
	_name_screen("first", NameService.roll(), Callable(), func(nick: String):
		player.nick = nick
		save_game()
		hud.close_overlay()
		get_tree().paused = _name_paused
		if hud.banner_count > banners and not hud.last_banner.is_empty():
			hud.show_banner(hud.last_banner["text"], hud.last_banner["col"]), "У героя ще нема імені. Впиши своє або візьми те, що випав жереб.")


func _slot_file(n: int) -> String:
	return SaveSystem.slot_path(n) if use_slots else save_path


## Перейменування з меню «Персонажі»: ім'я міняється просто у файлі слота, герой може бути й не нинішнім.
func _ask_rename(n: int) -> void:
	var path := _slot_file(n)
	var d := SaveSystem.load_data(path)
	if d.is_empty():
		return
	var cur := NameService.from_save(d["player"].get("nick", ""))
	_name_screen("rename", cur if cur != "" else NameService.roll(), _show_heroes_menu, func(nick: String):
		if not NameService.rename_file(path, nick):
			_show_heroes_menu()
			hud.show_banner("Не вдалося записати ім'я. Збереження лишилось, як було.", UI.BAD)
			return
		if n == slot and player != null:
			player.nick = nick
		_show_heroes_menu(), "Слот %d. Зміна імені безплатна." % n)


func _show_pause() -> void:
	state = State.PAUSED
	hud.set_mode(false, false)
	_open_menu("pause")
	hud.add_title("Пауза")
	hud.add_button("Продовжити", _resume_play)
	# Другорядні кнопки стоять парами: інакше меню не вміщалось на низькому екрані
	hud.add_row([
		UI.button("Персонаж", func():
			if combat.is_duel() and not combat.duel_over:
				hud.show_banner("Під час герцю не до торби", UI.BAD)  # пауза лишається: інакше гра завмирала без кнопок
				return
			hud.close_overlay()
			state = State.PLAYING
			open_character(), HALF_BTN, 22),
		UI.button("Довідник", func(): open_wiki(_show_pause), HALF_BTN, 22),
	])
	var ads := []
	for id in ["xp2", "drop2"]:
		var bname: String = AdRewards.BOOST_NAMES[id]
		if PremiumService.active(world):
			ads.append(UI.button("%s\nдіє: універсал" % bname, func(): pass, HALF_BTN, 18, false))
			continue
		ads.append(UI.button(("%s\nще %s" % [bname, AdRewards.format_time(AdRewards.boost_left(world, id))]) if not AdRewards.can_boost(world, id) else "%s на годину\nза рекламу" % bname, _watch_boost.bind(id, _show_pause), HALF_BTN, 18))
	hud.add_row(ads)
	if DivineService.remote_shop(player):
		hud.add_button("Хованець: крамниця будь-де", func(): open_trader(_show_pause), WIDE_BTN)
	_add_sound_toggles(_show_pause, true)
	var leave_text := "Покинути печеру (прогрес втратиться)" if combat.is_dungeon() else "Повернутися на мапу"
	if combat.is_duel() and not combat.duel_over:
		hud.add_button("Здатися (мінус спроба)", _duel_lost, WIDE_BTN)
	else:
		hud.add_button(leave_text, enter_map, WIDE_BTN)
	hud.add_button("Головне меню", _quit_to_menu, WIDE_BTN)


## З паузи в головне меню. Бій закінчується так само, як вихід на мапу: здобич із землі йде в торбу,
## варта зараховується. Незавершений герць чи огляд рахується поразкою, інакше так берегли б спроби.
func _quit_to_menu() -> void:
	if combat.active and combat.is_duel() and not combat.duel_over and state != State.DEAD:
		_fight_forfeit()
	_leave_combat()
	save_game()
	_show_main_menu()


## Списати спробу за покинутий бій на спроби (герць, огляд, вільний герць). Повертає повідомлення.
func _fight_forfeit() -> String:
	var kind := str(meta.get("fight", ""))
	if kind == "" and combat.active and combat.is_duel():
		kind = "muster" if combat.loc.get("muster", false) else ("free" if combat.loc.get("free", false) else "duel")
	meta.erase("fight")
	match kind:
		"muster":
			return MusterService.lose(world)
		"free":
			return DuelService.free_lose(world)
		"duel":
			return DuelService.lose(world)
	return ""


const HALF_BTN := Vector2(232, 64)  # дві такі кнопки в ряд займають ширину звичайної
const WIDE_BTN := Vector2(480, 68)


## Звук, музика й автопідбір; shop — поруч з автопідбором стоїть кнопка крамниці (там, де є герой).
func _add_sound_toggles(refresh: Callable, shop: bool = false) -> void:
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
	var on := 0
	for v in combat.pickup_filter:
		on += 1 if v else 0
	var pick_text := "Автопідбір: %s" % ("усе" if on == 4 else "%d із 4 рідкостей" % on)
	if shop:
		hud.add_row([
			UI.button(pick_text.trim_suffix(" рідкостей"), func(): _show_pickup_menu(refresh), HALF_BTN, 20),
			UI.button("Крамниця", func(): open_shop(refresh), HALF_BTN, 22),
		])
	else:
		hud.add_button(pick_text, func(): _show_pickup_menu(refresh), Vector2(480, 64))


## Фільтр автопідбору: речі яких рідкостей герой підбирає сам. back — меню, з якого прийшли.
func _show_pickup_menu(back: Callable) -> void:
	_open_menu("pickup", true)
	if state == State.MENU:
		_menu_back = back
	hud.add_title("Фільтр автопідбору")
	hud.add_title("Вимкнена рідкість не підбирається: річ лежить тьмяна,\nа коли йдеш із місця, продається. Золоті речі й артефакти беруться завжди.", 22, UI.TEXT)
	for r in 4:
		var b := hud.add_button(("☑ " if combat.pickup_filter[r] else "☐ ") + "%s речі" % Data.rarity_plural(r), func():
			combat.pickup_filter[r] = not combat.pickup_filter[r]
			_save_settings()
			_show_pickup_menu(back), Vector2(480, 64))
		b.add_theme_color_override("font_color", Data.rarity_color(r))
	var lying: int = combat.ignored_count() if combat.active else 0
	if lying > 0:
		hud.add_button("Підібрати все, що лежить: %d" % lying, func():
			var got: int = combat.collect_ignored()
			hud.show_banner("Підібрано речей: %d" % got if got > 0 else "Торба повна", UI.GOLD if got > 0 else UI.BAD)
			_show_pickup_menu(back), Vector2(480, 64))
	hud.add_button("Назад", back, Vector2(480, 64))


func _save_settings() -> void:
	var s_ := {"sound": Audio.sound_on, "music": Audio.music_on, "autosell": combat.autosell, "pickup": combat.pickup_filter}
	if use_slots:
		s_["slot"] = slot  # тести без слотів запам'ятованого героя не чіпають
	SaveSystem.save_settings(s_)


# ======================= Клавіатура й система =======================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if naming != "" and event.physical_keycode != KEY_ESCAPE:
		return  # літери пишуться в поле імені, а не відкривають екран героя
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
		# У головному меню героя вже нема (його могли щойно видалити чи ще не створити до кінця):
		# зберігати нічого. Інакше видалений герой вертався, а новий записувався ще до першого бою.
		if state != State.MENU and player != null:
			if combat.active:
				combat.secure_loot()  # золоте, наборне й разові нагороди не лишаються на землі, якщо гру закриють
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
	if Ads.is_busy() or Billing.is_busy() or hud.dialogue_root != null:
		return  # рекламу, оплату й розмову з вибором треба довести до кінця
	if naming != "":
		_name_cancel()  # новий герой і перейменування: назад у меню; старий герой без імені лишається тут
		return
	if wiki_open:
		close_wiki()
		return
	# Крамниці лежать поверх будь-якого екрана: «Назад» спершу закриває їх, а не екран під ними
	if shop_open:
		close_shop()
		return
	if trader_open:
		close_trader()
		return
	if not class_warn.is_empty() and hud.overlay.visible:
		class_warn_cancel()  # попередження про ранню зміну класу: «Назад» — це «Ні»
		return
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
			if _menu_back.is_valid():
				var back := _menu_back  # підменю («Персонажі», перенесення): крок назад, а не вихід із гри
				_menu_back = Callable()
				back.call()
			elif from_system:
				_quit_app()


# ======================= Довідник =======================

## Відкрити довідник. back — що показати, коли його закриють (меню, паузу, привал чи екран героя);
## section — з якої вкладки почати (id розділу з data/wiki_sections.json).
func open_wiki(back: Callable, section: String = "") -> void:
	_wiki_back = back
	wiki_open = true
	if section != "":
		wiki_tab = WikiService.index_of(section)
	hud.close_overlay()
	Audio.play("page", 0.08)
	hud.set_screen(UiWiki.build(self), "wiki")


func close_wiki() -> void:
	if not wiki_open:
		return
	wiki_open = false
	hud.clear_screen()
	var back := _wiki_back
	_wiki_back = Callable()
	if back.is_valid():
		back.call()


# ======================= Крамниця за донат =======================

var shop_open := false
var shop_tab := 0
var shop_sel := ""  # вибраний у крамниці товар: ключ "вид:id" (картка праворуч від сітки)
var fair_sel := ""  # вибраний товар ярмарку на хуторі (ключ із FairService.stock)
var shop_confirm := ""  # товар, що чекає другого дотику: покупку за червінці треба підтвердити
var _shop_back := Callable()


## Відкрити крамницю. back — куди вертатись після «Назад» (меню паузи, привал, екран героя).
func open_shop(back: Callable) -> void:
	_shop_back = back
	shop_open = true
	shop_confirm = ""
	hud.close_overlay()
	Audio.play("coins", 0.05)
	hud.set_screen(UiShop.build(self), "shop")


func close_shop() -> void:
	if not shop_open:
		return
	shop_open = false
	shop_confirm = ""
	hud.clear_screen()
	save_game()
	var back := _shop_back
	_shop_back = Callable()
	if back.is_valid():
		back.call()


## Дії в крамниці: "pack" — купити набір червінців за гроші, "buy" — купити товар [вид, id] за червінці,
## "premium" — купити чи продовжити Гетьманський універсал.
func shop_do(action: String, arg) -> void:
	match action:
		"select":
			# дотик до клітинки товару: показати його картку; покупка лишається за кнопкою картки
			shop_sel = str(arg)
			shop_confirm = ""
		"divine":
			# куплений дар вдягається й знімається одним дотиком, купівля просить підтвердження
			var did: String = str(arg)
			shop_sel = "divine:" + did
			if DivineService.owned(world, did):
				if DivineService.wears(player, did):
					DivineService.unequip(world, player, str(DivineService.Divine.def(did)["slot"]))
				else:
					DivineService.equip(world, player, did)
				shop_confirm = ""
				Audio.play("item", 0.05)
				save_game()
			elif DivineService.block_reason(world, did) != "":
				shop_confirm = ""
				if not DivineService.on_sale:
					hud.show_banner(ShopService.OFF_TEXT, UI.BAD)
			elif shop_confirm != "divine:" + did:
				shop_confirm = "divine:" + did
			else:
				shop_confirm = ""
				if DivineService.buy(world, player, did):
					save_game()
					Audio.play("quest", 0.0)
					hud.show_banner("%s тепер у твого роду.\nГерой уже вдягнув: глянь гнізда на екрані героя" % DivineService.Divine.def(did)["name"], UI.GOLD)
		"costume":
			# куплене вбрання вдягається й знімається одним дотиком, купівля просить підтвердження
			var cid: String = str(arg)
			shop_sel = "costume:" + cid
			if CostumeService.owned(world, cid):
				CostumeService.wear(world, player, "" if player.costume == cid else cid)
				shop_confirm = ""
				Audio.play("item", 0.05)
				save_game()
			elif CostumeService.block_reason(world, cid) != "":
				shop_confirm = ""
			elif shop_confirm != "costume:" + cid:
				shop_confirm = "costume:" + cid
			else:
				shop_confirm = ""
				if CostumeService.buy(world, player, cid):
					save_game()
					Audio.play("quest", 0.0)
					hud.show_banner("%s тепер у твого роду.\nГерой уже вдягнув" % player.Costumes.name_of(cid), UI.GOLD)
		"premium":
			if PremiumService.block_reason(world) != "":
				shop_confirm = ""
			elif shop_confirm != "premium":
				shop_confirm = "premium"  # перший дотик лише питає
			else:
				shop_confirm = ""
				if PremiumService.buy(world):
					CampService.apply_effects(world, player)  # торба більшає одразу
					var pay: int = PremiumService.stipend(world)
					save_game()
					Audio.play("quest", 0.0)
					hud.show_banner("%s діє %d днів%s" % [PremiumService.NAME, PremiumService.days_left(world), ("\nПлатня за сьогодні: +%d червінців" % pay) if pay > 0 else ""], UI.GOLD)
		"pack":
			var why: String = ShopService.pack_block_reason(str(arg))
			if why != "":
				# купівлю червінців вимкнено (ShopService.coins_on_sale): Billing не кличемо
				hud.show_banner(why, UI.BAD)
				hud.set_screen(UiShop.build(self), "shop")
				return
			var pid := str(arg)
			var p: Dictionary = ShopService.pack(pid)
			Billing.purchase(pid, "%s: %s червінців" % [p["name"], UI.num(int(p["coins"]))], str(p["price"]), func(paid: bool):
				if paid:
					var n: int = ShopService.grant_pack(world, pid)
					save_game()
					Audio.play("coins", 0.05)
					hud.show_banner("Дякуємо за підтримку!\n+%s червінців" % UI.num(n), UI.GOLD)
				if shop_open:
					hud.set_screen(UiShop.build(self), "shop"))
			return
		"buy":
			var kind: String = str(arg[0])
			var id: String = str(arg[1])
			var key: String = ShopService.key(kind, id)
			shop_sel = key
			if ShopService.block_reason(world, player, kind, id) != "":
				shop_confirm = ""
			elif shop_confirm != key:
				shop_confirm = key  # перший дотик лише питає: червінці коштують справжніх грошей
			else:
				shop_confirm = ""
				var res: Dictionary = ShopService.buy(world, player, kind, id)
				if bool(res["ok"]):
					save_game()
					Audio.play("quest", 0.0)
					_check_full_set()
				hud.show_banner(str(res["msg"]), UI.GOLD if bool(res["ok"]) else UI.BAD)
	hud.set_screen(UiShop.build(self), "shop")


## Привал на мапі: звук, головне меню, вихід. Раніше з мапи до головного меню дороги не було.
func _show_map_menu() -> void:
	if state != State.MAP or travel_to != "":
		return  # у дорозі не спиняємось: поїздка триває кілька секунд
	map_menu = true
	_open_menu("map_menu")
	hud.add_title("Привал")
	hud.add_button("Далі в дорогу", _close_map_menu)
	hud.add_button("Довідник", func(): open_wiki(_show_map_menu))
	_add_sound_toggles(_show_map_menu, true)
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

## arrived — герой справді приїхав на хутір (лічильник «hutir»); false — гру відкрито там, де він стояв.
func enter_camp(arrived: bool = true) -> void:
	_leave_combat()
	_price_city("")
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
	chest_sel = ""
	smith_msg = ""
	confirm_action = ""
	var back := _expedition_news(true)
	# лічильники для викликів і доручень: навідини на хутір і скільки рівнів будівель на ньому стоїть
	if arrived:
		back.append_array(ChallengeService.record(world, player, "hutir"))
	if CampService.total_levels(world) > 0:
		back.append_array(ChallengeService.record(world, player, "camp_level", CampService.total_levels(world)))
	_build_camp()
	if not back.is_empty():
		hud.show_banner("\n".join(back), UI.GOLD)
	save_game()
	# Гривень уже вистачає на перший клейнод, а рід їх іще не має: один раз підказуємо, куди їх подіти
	if world.hints.has("camp") and KleinodService.total(world) == 0 and player.gold >= int(Camp.kleinod_tier(0)["gold"]):
		hint("kleinody", "Гривень назбиралось чимало. Зазирни на вкладку «Клейноди»: козацькі регалії назавжди додають бонуси всім твоїм героям.")
	hint("camp", "Твій хутір! Тут козак і загін відпочивають. Будуй курінь, кузню, зілляварню, склад і пасіку за гривні та ресурси з походів.")


func leave_camp() -> void:
	confirm_action = ""
	enter_map()


## Перемикання вкладки хутора скидає підтвердження переплавки: кузню перебудовуємо, щоб напис не лишився.
func camp_tab_changed(i: int) -> void:
	camp_tab = i
	if confirm_action.begins_with("salvage:"):
		confirm_action = ""
		(func(): if state == State.CAMP: _build_camp()).call_deferred()


## Той самий хутір на тій самій вкладці лишається прогорнутим, як був (див. Hud.set_screen).
func _build_camp() -> void:
	hud.set_screen(UiCamp.build(self), "camp")


func camp_do(action: String, arg) -> void:
	if action != "salvage":
		confirm_action = ""  # будь-яка інша дія скидає підтвердження переплавки
	match action:
		"build":
			if CampService.build(world, player, arg):
				Audio.play("quest", 0.0)
				var built := ["%s: рівень %d!" % [Camp.building(arg)["name"], CampService.level(world, arg)]]
				built.append_array(ChallengeService.record(world, player, "camp_level", CampService.total_levels(world)))
				hud.show_banner("\n".join(built), UI.GOLD)
		"select":
			camp_sel_uid = arg
			smith_msg = ""
		"sharpen":
			_sharpen(arg, CampService.forge_cost_mult(world), CampService.forge_chance_bonus(world))
		"sharpen_safe":
			_sharpen(arg, CampService.forge_cost_mult(world), CampService.forge_chance_bonus(world), true)
		"socket", "soul_in", "soul_out":
			_soul_action(action, arg, CampService.forge_cost_mult(world))
		"kleinod":
			if KleinodService.buy(world, player, arg):
				var kl := KleinodService.level(world, arg)
				Audio.play("quest", 0.0)
				hud.show_banner("%s: ступінь %d!\n%s" % [Camp.kleinod(arg)["name"], kl, KleinodService.bonus_text(arg, kl)], UI.GOLD)
				_record("kleinod")
		"buy_stone":
			if KleinodService.buy_stone(player, arg):
				Audio.play("coin", 0.0)
				hud.show_banner("Куплено: %s" % StoneService.name_of(arg), UI.GOLD)
		"salvage":
			# цінна річ плавиться лише з другого дотику, як «Знищити» на екрані героя
			var sv: Dictionary = player.find_item(arg)
			if not sv.is_empty() and CampService.salvage_precious(sv) and confirm_action != "salvage:%d" % arg:
				confirm_action = "salvage:%d" % arg
				save_game()
				_build_camp()
				return
			confirm_action = ""
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
				smith_msg_color = Data.rarity_color(int(it["rarity"]))
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
		"renew_one":
			if CraftService.renew(world, player, arg, 1):
				Audio.play("sharpen_ok", 0.03)
				smith_msg = "Річ піднято на рівень: тепер %d" % int(player.find_item(arg)["ilvl"])
				smith_msg_color = UI.GOOD
		"chest_select":
			# дотик до клітинки скрині чи торби: показати картку речі; другий дотик переносить її (UiCamp._chest)
			chest_sel = str(arg)
			smith_msg = ""
		"chest_put":
			chest_sel = ""
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
			chest_sel = ""
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
				if BUFF_NAMES.has(arg):
					hud.show_banner("%s випито\nДіє ще %s бою" % [BUFF_NAMES[arg], UiCamp.buff_time(player.buff_left(arg))], UI.GOOD)
				_record("brew")
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
				hud.show_banner("%s готовий! %s\nДіє ще %s бою" % [Acts.recipe(arg)["name"], Acts.recipe(arg)["desc"], UiCamp.buff_time(player.buff_left("food"))], UI.GOOD)
				_record("cook")
				_record("cook:" + str(arg))
		"collect":
			var g := CampService.collect_pasika(world, player)
			if g > 0:
				Audio.play("coin", 0.0)
				hud.show_banner("Мед продано: +%d грн" % g, UI.GOLD)
		"enchant":
			if player.EnchantService.enchant(player, int(arg[0]), str(arg[1])):
				Audio.play("spell", 0.05)
				smith_msg = "Зачаровано: %s" % player.EnchantService.text(player.find_item(int(arg[0])))
				smith_msg_color = Color(0.75, 0.6, 1.0)
				_record("enchant")
		"fair_select":
			fair_sel = str(arg)
		"fair_buy":
			var fr: Dictionary = load("res://scripts/game/fair_service.gd").buy(world, player, str(arg))
			if bool(fr["ok"]):
				Audio.play("coins", 0.05)
				_record("fair")
			hud.show_banner(str(fr["msg"]), UI.GOLD if bool(fr["ok"]) else UI.BAD)
		"pet_up":
			var was: int = PetService.level(world, str(arg))
			if PetService.upgrade(world, player, str(arg)):
				Audio.play("quest", 0.0)
				var PD: Dictionary = player.Pets.def(str(arg))
				hud.show_banner(("%s тепер живе на хуторі" % PD["name"]) if was == 0 else "%s: ступінь %d. %s" % [PD["name"], was + 1, player.Pets.text(str(arg), was + 1).capitalize()], UI.GOLD)
				_record("pet_level")
		"pet_pick":
			if PetService.choose(world, player, "" if str(player.pet) == str(arg) else str(arg)):
				Audio.play("item", 0.05)
		"ad_xp2":
			_watch_boost("xp2", _build_camp)
			return
		"ad_drop2":
			_watch_boost("drop2", _build_camp)
			return
		"ad_safe":
			_ad("safe_sharpen", func(ok: bool):
				if ok and AdRewards.grant_safe(world):
					hud.show_banner("+1 безпечна заточка" if PremiumService.active(world) else "Дякуємо! +1 безпечна заточка", UI.GOOD)
				save_game()
				if state == State.CAMP:
					_build_camp())
			return
	save_game()
	_build_camp()  # той самий хутір: список лишається там, куди його прогорнули


## Гнізда й душі: пробити гніздо (uid), вселити душу ([uid, id душі]), вийняти душу (uid).
func _soul_action(action: String, arg, cost_mult: float) -> void:
	match action:
		"socket":
			if SoulService.make_socket(player, arg, cost_mult):
				Audio.play("quest", 0.0)
				smith_msg = "Гніздо для душі готове"
				smith_msg_color = UI.GOOD
		"soul_in":
			if SoulService.insert(player, arg[0], arg[1]):
				Audio.play("quest", 0.0)
				smith_msg = "%s тепер у речі" % SoulService.soul_name(arg[1])
				smith_msg_color = SoulService.color(arg[1])
		"soul_out":
			if SoulService.remove(player, arg, cost_mult):
				smith_msg = "Душа повернулась у торбинку"
				smith_msg_color = UI.TEXT
	save_game()


## Реклама за годинний подарунок ("xp2" чи "drop2"); refresh перебудовує поточний екран після перегляду.
func _watch_boost(id: String, refresh: Callable) -> void:
	if not AdRewards.can_boost(world, id):
		return
	Ads.show_rewarded(id, func(ok: bool):
		if ok:
			AdRewards.grant_boost(world, id)
			hud.show_banner("Дякуємо! %s: %s" % [AdRewards.BOOST_NAMES[id], AdRewards.format_time(AdRewards.boost_left(world, id))], UI.GOOD)
			save_game()
		refresh.call())
