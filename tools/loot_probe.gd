extends SceneTree
## Здобич за годину. Розігрує багато годин бою за правилами самої гри (ті самі сталі й служби, що в Combat._drop_loot):
## речі за рідкістю, золоті речі, артефакти, душі й камені долі в далекому полі та в печері далекого краю.
## Темп узято з симуляцій для героя в доброму спорядженні (docs/balance.md), плюс час на дорогу, здобич і місто.
##
## Запуск:  godot --headless --path . -s res://tools/loot_probe.gd
##   LOOT_LEVELS=20,45,75,98   рівні героя
##   LOOT_HOURS=400            скільки годин розіграти на рядок
##   LOOT_OVERHEAD=40          секунд між походами (дорога, здобич, місто)

const Data := preload("res://scripts/data/data.gd")
const GameDB := preload("res://scripts/core/game_db.gd")
const Elites := preload("res://scripts/data/elites.gd")
const Uniques := preload("res://scripts/data/uniques.gd")
const Artifacts := preload("res://scripts/data/artifacts.gd")
const LootService := preload("res://scripts/game/loot_service.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")
const StoneService := preload("res://scripts/game/stone_service.gd")
const DepthService := preload("res://scripts/game/depth_service.gd")

## Секунд бою на одну зачистку: герой у доброму спорядженні, місце свого рівня (tools/far_sim.gd).
const PACE := {20: {"field": 100.0, "dungeon": 100.0}, 45: {"field": 135.0, "dungeon": 90.0},
	75: {"field": 125.0, "dungeon": 40.0}, 98: {"field": 90.0, "dungeon": 50.0}}
const FIELD_ID := "perekop"
const DUNGEON_ID := "bakhmut_kopalni"
const RARITY := ["звичайні", "добротні", "рідкісні", "легендарні"]


## Найменше, що потрібно службам здобичі від бою: чи це Башта, чи печера і який її опис.
class FakeCombat:
	var loc := {}
	var tower := false
	func is_tower() -> bool:
		return tower
	func is_dungeon() -> bool:
		return not tower


var _enemy_script


func _initialize() -> void:
	_enemy_script = load("res://scripts/entities/enemy.gd")  # не раніше: скриптові потрібні автозавантаження
	load("res://scripts/game/holiday_service.gd").forced = "none"
	var levels := []
	for l in _env("LOOT_LEVELS", "20,45,75,98").split(","):
		levels.append(int(l))
	var hours := int(_env("LOOT_HOURS", "400"))
	var overhead := float(_env("LOOT_OVERHEAD", "40"))
	print("Шанси: річ із рядового %s%%, еліта %s%% нечисті й річ із неї %s%%, золота річ із боса %s, артефакт %s%% (Башта %s%%)." % [
		_pct(Data.ITEM_DROP_CHANCE), _pct(Elites.CHANCE), _pct(Elites.ITEM_CHANCE), str(_tier_chances()), _pct(Artifacts.CHANCE), _pct(Artifacts.CHANCE_TOWER)])
	for lvl in levels:
		_level(lvl, hours, overhead)
	_artifact_luck()
	quit()


## Шанси золота за ступенями 1..6 (golden_tiers.json).
func _tier_chances() -> Array:
	var out := []
	for t in range(1, Uniques.max_tier() + 1):
		out.append(Uniques.tier_chance(t))
	return out


func _env(name: String, fallback: String) -> String:
	var v := OS.get_environment(name)
	return v if v != "" else fallback


func _pct(v: float) -> String:
	return ("%.2f" % (v * 100.0)).rstrip("0").rstrip(".")


func _pace(lvl: int) -> Dictionary:
	var best := 20
	for k in PACE:
		if absi(int(k) - lvl) < absi(best - lvl):
			best = int(k)
	return PACE[best]


func _hero(lvl: int):
	var p = load("res://scripts/entities/player.gd").new()
	p.job = "cossack"
	p.level = lvl
	p.soul_found = 1  # перша душа героя гарантована; міряємо звичайний шанс
	p.recalc()
	return p


func _foe(kind: String, lvl: int, boss: bool, elite: bool = false):
	var e = _enemy_script.new()
	e.setup(kind, lvl, boss)
	if elite:
		e.elite = true
		e.max_hp *= Elites.HP_MULT
	return e


func _level(lvl: int, hours: int, overhead: float) -> void:
	var pace: Dictionary = _pace(lvl)
	var p = _hero(lvl)
	# ---- Поле далекого краю ----
	var FL: Dictionary = Data.place(FIELD_ID)
	var goal: int = mini(110, Data.FIELD_GOAL_BASE + int(FL["level"]) * Data.FIELD_GOAL_PER_LEVEL)
	var field_runs: float = 3600.0 / (float(pace["field"]) + overhead)
	var reg = _foe("zarazhenyi", lvl, false)
	var eli = _foe("zarazhenyi", lvl, false, true)
	var items := [0, 0, 0, 0]
	var souls := 0
	var kills := 0
	var runs: int = roundi(field_runs * hours)
	for r in runs:
		for k in goal:
			kills += 1
			if randf() < Elites.chance(lvl, 0):
				if randf() < Elites.ITEM_CHANCE:
					items[Data.roll_rarity(lvl, 1)] += 1
				souls += _soul(p, eli)
			else:
				if randf() < Data.ITEM_DROP_CHANCE:
					items[Data.roll_rarity(lvl)] += 1
				souls += _soul(p, reg)
		for i in 2:  # нагорода за зачистку
			items[Data.roll_rarity(lvl, 1)] += 1
	print("\n== Герой %d рівня ==" % lvl)
	print("Поле далекого краю: %.0f зачисток і %.0f нечисті за годину (бій %.0f с + %.0f с між походами)" % [field_runs, float(kills) / hours, float(pace["field"]), overhead])
	print("  речей за годину: %s" % _rar(items, hours))
	print("  душа з рядової нечисті: раз на %s" % _per(souls, hours))
	# ---- Печера далекого краю ----
	var DL: Dictionary = Data.place(DUNGEON_ID)
	var fake := FakeCombat.new()
	fake.loc = DL.duplicate()
	fake.loc["level"] = lvl
	var room_kills := 0
	for room in range(1, int(DL["rooms"]) + 1):
		room_kills += Data.DUNGEON_ROOM_BASE + room * Data.DUNGEON_ROOM_PER
	var dun_runs: float = 3600.0 / (float(pace["dungeon"]) + overhead)
	var boss = _foe(str(DL["boss"]), lvl, true)
	items = [0, 0, 0, 0]
	souls = 0
	var gold := 0
	var art := 0
	var stones := 0
	var boss_souls := 0
	var bosses := 0
	runs = roundi(dun_runs * hours)
	for r in runs:
		for k in room_kills:
			if randf() < Elites.chance(lvl, 0):
				if randf() < Elites.ITEM_CHANCE:
					items[Data.roll_rarity(lvl, 1)] += 1
				souls += _soul(p, eli)
			else:
				if randf() < Data.ITEM_DROP_CHANCE:
					items[Data.roll_rarity(lvl)] += 1
				souls += _soul(p, reg)
		bosses += 1
		for i in 2:
			items[Data.roll_rarity(lvl, 2)] += 1
		if not LootService.on_boss(fake, p, boss).is_empty():
			gold += 1
		var trophy: Dictionary = LootService.artifact_on_boss(fake, p, boss)
		if not trophy.is_empty():
			art += 1  # у торбу не кладемо: міряємо шанс за одну перемогу
		stones += StoneService.on_boss(p, str(boss.kind), false).size()
		p.stones.clear()
		boss_souls += _soul(p, boss)
	var tier: int = LootService.boss_tier(fake, boss)
	print("Печера далекого краю (%s, бос %s, ступінь %d): %.0f походів за годину, у кожному %d нечисті й бос" % [DL["name"], GameDB.boss_name(DL["boss"]), tier, dun_runs, room_kills])
	print("  речей за годину: %s" % _rar(items, hours))
	print("  золота річ: раз на %.0f босів, тобто раз на %s" % [float(bosses) / maxf(gold, 1.0), _per(gold, hours)])
	print("  артефакт цього боса: шанс за перемогу %.1f%%, перший у середньому за %s" % [100.0 * art / maxf(bosses, 1.0), _per(art, hours)])
	print("  камінь долі: раз на %s;  душа боса: раз на %s;  душа з рядових: раз на %s" % [_per(stones, hours), _per(boss_souls, hours), _per(souls, hours)])
	# ---- Глибини й Башта: ступінь і шанс золота ----
	var depth: int = maxi(1, (lvl - 22) / 2 + 1)
	fake.loc = DepthService.loc_for(depth)
	var dboss = _foe(str(fake.loc["boss"]), int(fake.loc["level"]), true)
	var dt: int = LootService.boss_tier(fake, dboss)
	print("  Глибина %d (бос %s): ступінь золота %d, шанс %s%% за боса" % [depth, GameDB.boss_name(fake.loc["boss"]), dt, _pct(LootService.chance(dt, 0))])
	for e in [reg, eli, boss, dboss]:
		e.free()
	p.free()


func _soul(p, e) -> int:
	var id: String = SoulService.roll(p, e)
	if id == "":
		return 0
	p.soul_luck = 0.0  # як після SoulService.grant, але торбинку не наповнюємо
	return 1


func _rar(items: Array, hours: int) -> String:
	var parts := []
	var total := 0
	for i in items.size():
		total += int(items[i])
		parts.append("%s %.1f" % [RARITY[i], float(items[i]) / hours])
	return "%.0f (%s)" % [float(total) / hours, ", ".join(parts)]


## «раз на N годин» чи «раз на N хвилин».
func _per(count: int, hours: int) -> String:
	if count <= 0:
		return "понад %d год" % hours
	var h: float = float(hours) / count
	return "%.1f год" % h if h >= 1.0 else "%.0f хв" % (h * 60.0)


## Скільки перемог над одним босом треба до його артефакта: середнє, кожен десятий і кожен сотий гравець.
func _artifact_luck() -> void:
	var p = _hero(75)
	var fake := FakeCombat.new()
	fake.loc = Data.place(DUNGEON_ID).duplicate()
	fake.loc["level"] = 75
	var boss = _foe(str(fake.loc["boss"]), 75, true)
	var tries := []
	for t in 4000:
		p.inventory.clear()
		if "art_luck" in p:
			p.art_luck = {}
		var n := 0
		while true:
			n += 1
			if not LootService.artifact_on_boss(fake, p, boss).is_empty() or n >= 2000:
				break
		tries.append(n)
	tries.sort()
	var sum := 0
	for n in tries:
		sum += int(n)
	print("\nАртефакт одного боса, перемог до першого: у середньому %.0f, кожен десятий гравець чекає понад %d, кожен сотий понад %d" % [
		float(sum) / tries.size(), int(tries[int(tries.size() * 0.9)]), int(tries[int(tries.size() * 0.99)])])
	# те саме для золота найвищого й найнижчого ступеня
	for tier in [1, 4]:
		var waits := []
		for t in 4000:
			var luck := 0
			while randf() >= LootService.chance(tier, luck):
				luck += 1
			waits.append(luck + 1)
		waits.sort()
		var s := 0
		for n in waits:
			s += int(n)
		print("Золота річ, ступінь %d (%s): босів до неї в середньому %.0f, кожен десятий чекає понад %d, найдовше %d" % [
			tier, Uniques.tier_name(tier), float(s) / waits.size(), int(waits[int(waits.size() * 0.9)]), int(waits[waits.size() - 1])])
	boss.free()
	p.free()
