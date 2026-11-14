extends RefCounted
## Камені долі:
##   Камінь забуття — скидає характеристики, Загартування й вміння нинішнього класу (очки повертаються).
##   Алатир-камінь — змінює дорогу на сусідню того самого ступеня (Козак ↔ Волхв, Запорожець → Пластун…);
##     вміння старої дороги забуваються з поверненням очок, майстерність лишається.
## Падають рідко з босів; перша перемога над останнім босом історії (Путіноїд) дає обидва камені гарантовано
## («boss.stones» у data/mobs.json; лік перемог спільний для роду, тож раз на рід).
## Ще дають три ранги слави й останній крок «Шляху козака»; продаються в крамниці за червінці (ShopService).
## Подарунки сюжету (присяга, вміння за посвяту) не скидаються — див. player.stat_gifts / skill_gifts.

const Classes := preload("res://scripts/data/classes.gd")
const Data := preload("res://scripts/data/data.gd")

const GameDB := preload("res://scripts/core/game_db.gd")
## Камені, дію яких пише цей код (reset_points, change_path): у data/stones.json мусять бути саме вони.
const KINDS := ["zabuttia", "alatyr"]


## Назва каменя (data/stones.json: назва, шанс із боса, ціна в крамниці, опис); невідомий — його id.
static func name_of(id: String) -> String:
	return str(GameDB.row("stones", id).get("name", id))


## Чи є такий камінь.
static func has(id: String) -> bool:
	return GameDB.table("stones").has(id)


## Камені, які гарантовано дає перша перемога над цим босом («boss.stones»; порожньо — жодного).
static func first_kill(kind: String) -> Array:
	return GameDB.mob(kind).get("boss", {}).get("stones", [])


static func count(player, id: String) -> int:
	return int(player.stones.get(id, 0))


static func grant(player, id: String, n: int = 1) -> void:
	player.stones[id] = count(player, id) + n


## Бос переможений. first — це перша перемога над таким босом. Повертає повідомлення.
static func on_boss(player, kind: String, first: bool) -> Array:
	var got := []
	if first and not first_kill(kind).is_empty():
		got.append_array(first_kill(kind))
	else:
		for id in GameDB.ids("stones"):
			if randf() < float(GameDB.row("stones", id)["chance"]) * (1.0 + float(player.art.get("stone", 0.0))):
				got.append(id)
	var msgs := []
	for id in got:
		grant(player, id)
		msgs.append("Знайдено: %s!" % name_of(id))
	return msgs


## Скинути очки (Камінь забуття). Повертає false, якщо каменя немає.
static func reset_points(player) -> bool:
	if count(player, "zabuttia") <= 0:
		return false
	player.stones["zabuttia"] -= 1
	for k in player.stats:
		var spent: int = int(player.stats[k]) - Data.STAT_BASE - int(player.stat_gifts.get(k, 0))
		if spent > 0:
			player.stats[k] -= spent
			player.stat_points += spent
	for id in player.perks:
		player.perk_points += int(player.perks[id])
	player.perks = {}
	for c in Classes.lineage(player.job):  # очки можна вкладати в усі дерева дороги, тож і вертаються вони з усіх
		if Classes.has_tree(c):
			_forget_tree(player, c)
	player.recalc()
	return true


## Забути вміння дерева класу (подаровані сюжетом лишаються лише для свого класу).
static func _forget_tree(player, cls: String, keep_gifts: bool = true) -> void:
	for b in Classes.tree(cls):
		for n in b["nodes"]:
			var id: String = n["id"]
			var r: int = player.sk(id)
			if r <= 0:
				continue
			var keep: int = mini(r, int(player.skill_gifts.get(id, 0))) if keep_gifts else 0
			player.skill_points += r - keep
			if keep > 0:
				player.skills[id] = keep
			else:
				player.skills.erase(id)
				if not keep_gifts:
					player.skill_gifts.erase(id)


## Сусідні дороги, на які можна перейти Алатир-каменем.
static func siblings(player) -> Array:
	var info: Dictionary = Classes.info(player.job)
	var parent: String = info.get("parent", "")
	if int(info["tier"]) == 1:
		parent = "peasant"
	if parent == "":
		return []
	return Classes.info(parent)["next"].filter(func(c): return c != player.job)


## Змінити дорогу (Алатир-камінь).
static func change_path(player, cls: String) -> bool:
	if count(player, "alatyr") <= 0 or not cls in siblings(player):
		return false
	player.stones["alatyr"] -= 1
	_forget_tree(player, player.job, false)
	var jl: int = player.job_level
	player.change_class(cls)
	player.job_level = jl  # майстерність лишається — змінюється лише дорога
	return true
