extends SceneTree
## Симуляція балансу: бот-козак заданого рівня (з авто-розподілом очок і спорядженням свого рівня)
## проходить кожну місцевість і печеру у справжній грі. Результат — таблиця для налаштування чисел.
##
## Запуск:  godot --headless --path . -s res://tools/balance_sim.gd --fixed-fps 60
## Опції (змінні середовища):
##   SIM_LEVELS="1,3,5"      рівні героя
##   SIM_LOCS="wild_field"   лише ці локації
##   SIM_SEEDS=2             скільки прогонів на клітинку (усереднення)
##   SIM_OUT=user://balance.md   куди записати звіт (Markdown)
##   SIM_CLASS=volkhv        клас героя (cossack за замовчуванням)

const Data := preload("res://scripts/data/data.gd")
const SaveSystem := preload("res://scripts/core/save_system.gd")

const FIELD_LIMIT := 240.0  # секунд гри на зачистку місцевості
const DUNGEON_LIMIT := 420.0

var game
var results = []


func _initialize() -> void:
	_run()


func _env_list(name: String, fallback: Array) -> Array:
	var v = OS.get_environment(name)
	if v == "":
		return fallback
	var out = []
	for p in v.split(","):
		out.append(p.strip_edges())
	return out


func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = "user://balance_sim.save"
	root.add_child(game)
	await process_frame
	var audio = root.get_node("Audio")
	audio.set_sound(false)
	audio.set_music(false)

	var levels = []
	for l in _env_list("SIM_LEVELS", ["1", "2", "3", "4", "6", "8", "10", "12"]):
		levels.append(int(l))
	var locs: Array = _env_list("SIM_LOCS", Data.LOCATIONS.keys())
	var seeds = int(OS.get_environment("SIM_SEEDS")) if OS.get_environment("SIM_SEEDS") != "" else 2
	var t0 = Time.get_ticks_msec()
	for loc_id in locs:
		var L: Dictionary = Data.LOCATIONS[loc_id]
		for lvl in levels:
			# Не ганяємо явно безглузді поєднання
			if lvl < int(L["level"]) - 3 or lvl > int(L["level"]) + 4:
				continue
			var agg = {}
			for s in seeds:
				seed(1000 * s + lvl * 31 + hash(loc_id))
				var r: Dictionary = await _simulate(loc_id, lvl)
				for k in r:
					agg[k] = agg.get(k, 0.0) + float(r[k])
			for k in agg:
				agg[k] /= seeds
			agg["loc"] = loc_id
			agg["hero"] = lvl
			results.append(agg)
			print("%-15s герой %2d | зачищено %3d%% | смерть %3d%% | час %5.0fс | шкода/хв %5.0f | досвід/хв %5.0f | грн/хв %4.0f" % [
				loc_id, lvl, agg["cleared"] * 100, agg["died"] * 100, agg["time"], agg["dmg_min"], agg["xp_min"], agg["gold_min"]])
	_report()
	print("Готово за %.0f с" % ((Time.get_ticks_msec() - t0) / 1000.0))
	SaveSystem.delete("user://balance_sim.save")
	quit()


# ======================= Герой заданого рівня =======================

## Порядок вивчення вмінь: спершу селянські (9 очок), далі — свого класу
const PEASANT_ORDER := ["vyly", "hardy", "vyly", "first_aid", "hardy", "vyly", "roll", "hardy", "vyly"]
const SKILL_ORDER := {
	"cossack": ["whirl", "sharp", "battle_cry", "whirl", "tough", "sharp", "musket", "whirl_cd", "whirl", "sharp", "storm",
		"fury", "tough", "ward", "battle_cry", "thirst", "deadly", "reach", "cleave", "tough", "unbreak", "fury", "thirst", "ward",
		"musket", "reload", "battle_cry", "whirl", "whirl_cd", "fury", "thirst", "ward", "thorns", "reach", "musket", "buckshot", "whirl_cd", "battle_cry", "reach"],
	"volkhv": ["fireball", "iskra", "shield", "fireball", "iskra", "deep_well", "iskra", "twin_spark", "herb", "fireball", "pyre",
		"regen", "mana_flow", "spirit", "fireball", "pyre", "tough", "iskra", "iskra", "spirit", "focus", "shield", "herb", "tough",
		"deep_well", "mana_flow", "spirit", "focus", "pyre", "regen", "tough", "ward", "focus", "ward", "shield", "herb", "deep_well", "mana_flow", "regen"],
}
## Спеціалізації: порядок вмінь і зброя
const SPEC_ORDER := {
	"zaporozhets": ["zemnyi", "stina", "bulava", "zemnyi", "iron_skin", "bulava", "mace_master", "zemnyi", "iron_skin", "nevhamovnyi",
		"bulava", "zaporizka_vytryvalist", "zemnyi", "mace_master", "iron_skin", "nevhamovnyi", "bulava", "stina", "zaporizka_vytryvalist", "mace_master"],
	"plastun": ["kydok", "oko", "pastka", "kydok", "tin", "oko", "kydok", "deadly", "oko", "trapper", "kydok", "tin", "pastka", "stryvok",
		"oko", "kydok", "tin", "trapper", "pastka", "stryvok"],
	"samopalnyk": ["kartech", "porokh", "prytsil", "kartech", "porokh", "bochka", "shvydke", "prytsil", "vluchnist", "kartech",
		"porokh", "shvydke", "prytsil", "vluchnist", "deadly", "bochka", "kartech", "porokh", "prytsil", "shvydke"],
	"kharakternyk": ["vovk", "zamova", "kulia", "vovk", "zamova", "vidvid", "wolf_blood", "spirit", "vovk", "zamova", "wolf_blood",
		"vidvid", "spirit", "kulia", "vovk", "zamova", "wolf_blood", "spirit", "vidvid", "kulia"],
}
const SPEC_WEAPON := {"zaporozhets": "mace", "plastun": "pike", "samopalnyk": "pishchal", "kharakternyk": "sabre"}
const PERK_ORDER := ["boots", "luck", "kobzar", "luck", "boots", "steel_will", "varenyk", "luck", "kobzar", "steel_will",
	"boots", "purse", "sich", "kobzar", "varenyk", "steel_will", "purse"]


func _build_hero(lvl: int) -> void:
	game.new_game()
	game.hud.close_dialogue()
	var p = game.player
	var cls := OS.get_environment("SIM_CLASS")
	if cls == "":
		cls = "cossack"
	# Селянська наука (9 очок за майстерність 1→10), потім посвята
	p.skill_points = 9
	for id in PEASANT_ORDER:
		p.learn_skill(id)
	var spec := ""
	if SPEC_ORDER.has(cls):
		# Спеціалізація: спершу Козак до 30-ї майстерності (усі його очки), потім посвята
		spec = cls
		cls = "cossack"
	p.change_class(cls)
	game._sync_class()
	while p.level < lvl:
		p.add_xp(p.xp_next - p.xp)
	# Майстерність класу приблизно встигає за рівнем героя
	p.job_level = clampi(lvl, 1, p.job_max()) if spec == "" else 30
	p.skill_points = p.job_level  # (job_level - 1) + 1 вміння в нагороду за посвяту
	# Характеристики: воїн — сила й витривалість, волхв — Характерництво й витривалість
	var cycle = ["str", "vit", "str", "agi", "vit", "str", "vit", "agi", "str", "str"]
	if cls == "volkhv":
		cycle = ["spi", "vit", "spi", "agi", "vit", "spi", "vit", "spi", "spi", "agi"]
	var i = 0
	while p.stat_points > 0:
		p.add_stat(cycle[i % cycle.size()])
		i += 1
	for id in SKILL_ORDER[cls]:
		if p.skill_points <= 0:
			break
		p.learn_skill(id)
	if spec != "":
		p.change_class(spec)
		game._sync_class()
		p.job_level = clampi(lvl - 18, 1, 50)
		p.skill_points = p.job_level
		for id in SPEC_ORDER[spec]:
			if p.skill_points <= 0:
				break
			p.learn_skill(id)
	for id in PERK_ORDER:
		if p.perk_points <= 0:
			break
		p.learn_perk(id)
	# Спорядження свого рівня: добротне, з типовою для цього етапу заточкою
	for slot in Data.SLOTS:
		var wt: String = SPEC_WEAPON.get(spec, "staff" if cls == "volkhv" else "sabre")
		var it = Data.gen_item(lvl, 1, slot, wt if slot == "weapon" else "")
		it["up"] = mini(lvl / 3, 4)
		p.add_item(it)
		p.equip(it["uid"])
	p.recalc()
	p.hp = p.max_hp
	p.mana = p.max_mana


# ======================= Бот =======================

func _bot(p, c) -> void:
	var hud = game.hud
	var en = c.nearest_enemy(p.global_position, 5000.0)
	var dir = Vector2.ZERO
	if en:
		var to: Vector2 = en.global_position - p.global_position
		# Стрільців переслідуємо, ближній бій тримаємо на відстані удару
		dir = to.normalized() if to.length() > p.attack_range * 0.7 else Vector2.ZERO
	# Ухилення: ворог поруч замахується або козак у червоній зоні боса
	for e in c.get_tree().get_nodes_in_group("enemies"):
		if e.windup > 0.0 and e.windup < 0.2 and p.global_position.distance_to(e.global_position) < e.radius + 60.0:
			p.dodge()
	for t in c.effects.get_children():
		if t.has_method("contains") and t.contains(p.global_position):
			dir = (p.global_position - t.global_position).normalized()
			if t.duration - t._t < 0.35:
				p.dodge()
	hud.joystick.vector = dir
	hud.btn_attack.held = en != null
	if en:
		for id in p.active_skills():
			if id == "first_aid" and p.hp > p.max_hp * 0.6:
				continue
			p.use_skill(id)
	if c.portal != null and is_instance_valid(c.portal) and (c.room_cleared or c.field_cleared):
		p.global_position = c.portal.global_position


func _simulate(loc_id: String, lvl: int) -> Dictionary:
	_build_hero(lvl)
	var p = game.player
	var xp0 = _total_xp(p)
	var gold0: int = p.gold
	var dmg = 0.0
	var hp_prev: float = p.hp
	game.enter_location(loc_id)
	var c = game.combat
	var limit = DUNGEON_LIMIT if c.is_dungeon() else FIELD_LIMIT
	var t = 0.0
	var dt = 1.0 / 60.0
	var cleared = false
	while t < limit:
		if game.state == game.State.PLAYING:
			_bot(p, c)
		await process_frame
		t += dt
		if p.hp < hp_prev:
			dmg += hp_prev - p.hp
		hp_prev = p.hp
		if not p.alive or game.state == game.State.DEAD:
			break
		if c.field_cleared or game.world.cleared.get(loc_id, 0) > 0 or game.state == game.State.MAP:
			cleared = true
			break
	var died = not p.alive
	if died:
		# Дочекатися меню смерті (воно ставить гру на паузу), щоб не зачепити наступний прогін
		for i in 120:
			await process_frame
	var mins = maxf(t, 1.0) / 60.0
	var r = {
		"cleared": 1.0 if cleared else 0.0, "died": 1.0 if died else 0.0, "time": t,
		"dmg_min": dmg / mins, "dmg_pct": dmg / p.max_hp,
		"xp_min": (_total_xp(p) - xp0) / mins, "gold_min": (p.gold - gold0) / mins,
		"lvl_minutes": 0.0,
	}
	# Скільки хвилин на наступний рівень при такій швидкості досвіду
	r["lvl_minutes"] = float(p.xp_next) / maxf(r["xp_min"], 1.0)
	if game.state == game.State.PLAYING:
		game.enter_map()
	game.world = load("res://scripts/game/world_state.gd").new()
	return r


func _total_xp(p) -> float:
	var total = float(p.xp)
	for l in range(1, p.level):
		total += Data.xp_for_level(l)
	return total


# ======================= Звіт =======================

func _report() -> void:
	var lines = [
		"# Звіт симуляції балансу", "",
		"Бот-козак заданого рівня з авто-розподілом очок і добротним спорядженням свого рівня.",
		"Ліміт: %d с на місцевість, %d с на печеру. Значення усереднені." % [FIELD_LIMIT, DUNGEON_LIMIT], "",
		"| Локація (рів.) | Герой | Зачищено | Смерть | Час, с | Шкода за похід, % здоров'я | Досвід/хв | Гривні/хв | Хв до рівня |",
		"|---|---|---|---|---|---|---|---|---|",
	]
	for r in results:
		var L: Dictionary = Data.LOCATIONS[r["loc"]]
		lines.append("| %s (%d) | %d | %d%% | %d%% | %.0f | %.0f%% | %.0f | %.0f | %.1f |" % [
			L["name"], L["level"], r["hero"], r["cleared"] * 100, r["died"] * 100, r["time"],
			r["dmg_pct"] * 100, r["xp_min"], r["gold_min"], r["lvl_minutes"]])
	var path = OS.get_environment("SIM_OUT")
	if path == "":
		path = "user://balance.md"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
		print("Звіт: ", ProjectSettings.globalize_path(path))
