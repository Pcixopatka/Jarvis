extends RefCounted
## Набори речей у грі: коли падає річ набору й яка саме (дані — у Sets).
## Речі наборів дають лише надважкі печери: бос, елітна нечисть і перша перемога над кожним босом.

const Data := preload("res://scripts/data/data.gd")
const Sets := preload("res://scripts/data/sets.gd")
const Classes := preload("res://scripts/data/classes.gd")


## Які речі наборів герой уже має (вдягнені й у торбі): {"набір:клітинка": true}.
static func owned(player) -> Dictionary:
	var out := {}
	for it in player.inventory:
		if Sets.is_set(it):
			out["%s:%s" % [it["set"], it["slot"]]] = true
	for slot in player.equipment:
		var it: Dictionary = player.equipment[slot]
		if Sets.is_set(it):
			out["%s:%s" % [it["set"], it["slot"]]] = true
	return out


## Головна риса класу героя: посох — Характерництво, лук, пістолі й пищаль — Спритність, решта — Сила.
static func main_stat(player) -> String:
	var weapons: Array = Classes.CLASSES[player.job].get("weapons", [])
	if weapons.has("staff"):
		return "spi"
	for wt in Data.AGI_WEAPONS:
		if weapons.has(wt):
			return "agi"
	if str(player.job) == "plastun":
		return "agi"
	return "str"


## Яку річ дати: [набір, клітинка]. Набір під клас і річ, якої ще нема, трапляються частіше.
static func pick(player) -> Array:
	var have := owned(player)
	var main := main_stat(player)
	var opts := []
	var weights := []
	var total := 0.0
	for id in Sets.ORDER:
		for slot in Data.SLOTS:
			var w := 1.0
			if str(Sets.SETS[id]["stat"]) == main:
				w *= Sets.W_CLASS
			if not have.has("%s:%s" % [id, slot]):
				w *= Sets.W_NEW
			opts.append([id, slot])
			weights.append(w)
			total += w
	var r := randf() * total
	for i in opts.size():
		r -= float(weights[i])
		if r <= 0.0:
			return opts[i]
	return opts[opts.size() - 1]


## Річ набору для героя: рівень речі — рівень печери, зброя — з тих, що до руки класу.
static func roll(player, ilvl: int) -> Dictionary:
	var p := pick(player)
	var type := ""
	if str(p[1]) == "weapon":
		var weapons: Array = Classes.CLASSES[player.job].get("weapons", ["sabre"])
		type = str(weapons[randi() % weapons.size()])
	return Sets.make(str(p[0]), str(p[1]), ilvl, type)


static func _luck(player) -> float:
	return (1.0 + float(player.art.get("set_luck", 0.0))) * player.loot_luck()  # артефакт «Золота личина» і звитяга «Талан»


## Надважкий бос упав у своїй печері. first — це перша перемога героя над ним: тоді річ напевно.
static func on_boss(combat, player, e, first: bool) -> Dictionary:
	if not combat.loc.has("peril") or not e.is_boss or e.illusion or str(e.kind) != str(combat.loc.get("boss", "")):
		return {}
	if first or randf() < Sets.BOSS_CHANCE * _luck(player):
		return roll(player, int(combat.loc["level"]))
	return {}


## Елітна нечисть надважкої печери.
static func on_elite(combat, player, e) -> Dictionary:
	if not combat.loc.has("peril") or not e.elite:
		return {}
	if randf() < Sets.ELITE_CHANCE * _luck(player):
		return roll(player, int(combat.loc["level"]))
	return {}
