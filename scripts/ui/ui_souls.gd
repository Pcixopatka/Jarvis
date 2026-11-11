extends RefCounted
## Екрани душ: блок «гніздо й душа» для вибраної речі (у коваля, в кузні й на екрані героя)
## і Пом'яник — список усіх душ із тим, що знайдено й що діє.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Data := preload("res://scripts/data/data.gd")
const Souls := preload("res://scripts/data/souls.gd")
const SoulService := preload("res://scripts/game/soul_service.gd")

const WIDTH := 340


static func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := UI.label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 20, 0)
	return l


## Гніздо й душа вибраної речі. do(action, arg) повертає Callable дії екрана;
## at_smith — чи це коваль або кузня (лише там пробивають гніздо й виймають душу).
static func block(player, item: Dictionary, do: Callable, at_smith: bool, cost_mult: float = 1.0) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if item.is_empty() or not Data.SLOTS.has(item.get("slot", "")):
		return v
	var uid: int = int(item["uid"])
	if not SoulService.has_socket(item):
		var why: String = SoulService.socket_block(item)
		if why != "":
			v.add_child(_wrapped(why + ".", 15, UI.MUTED))
		elif at_smith:
			var cost: Dictionary = SoulService.socket_cost(player, item, cost_mult)
			v.add_child(UI.button("Пробити гніздо для душі\n%s грн • трофеїв %d" % [UI.num(int(cost["gold"])), int(cost["trophy"])], do.call("socket", uid), Vector2(WIDTH, 72), 17, SoulService.can_pay(player, cost)))
		else:
			v.add_child(_wrapped("Гніздо для душі проб'є коваль у місті або своя кузня.", 15, UI.MUTED))
		return v
	var inside: String = SoulService.soul_in(item)
	if inside != "":
		if at_smith:
			var rc: int = SoulService.remove_cost(player, item, cost_mult)
			v.add_child(UI.button("Вийняти душу\n%s грн • вернеться в торбинку" % UI.num(rc), do.call("soul_out", uid), Vector2(WIDTH, 64), 16, int(player.gold) >= rc))
		else:
			v.add_child(_wrapped("Вийняти душу може коваль або своя кузня.", 15, UI.MUTED))
		return v
	# порожнє гніздо: душі з торбинки, що сюди стають
	var any := false
	for id in SoulService.known() + player.souls.keys():
		if int(player.souls.get(id, 0)) <= 0 or (not id in Souls.ORDER and id in SoulService.known()):
			continue
		if any and v.get_child_count() > 40:
			break
		var why2: String = SoulService.insert_block(player, item, id)
		var b := UI.button("Вселити: %s\n%s" % [SoulService.soul_name(id), SoulService.fx_text(id) if why2 == "" else why2], do.call("soul_in", [uid, id]), Vector2(WIDTH, 68), 15, why2 == "")
		b.add_theme_color_override("font_color", SoulService.color(id))
		b.clip_text = true
		v.add_child(b)
		any = true
	if not any:
		v.add_child(_wrapped("Гніздо порожнє, а душ у торбинці нема. Душі вкрай рідко лишає вбита нечисть.", 15, UI.MUTED))
	return v


## Усі бонуси душ, що діють зараз, одним рядком.
static func active_text(player) -> String:
	var parts := []
	for k in player.soul_fx:
		var cap: bool = is_equal_approx(float(player.soul_fx[k]) * 100.0, float(Souls.FX[k]["cap"]))
		parts.append(str(Souls.FX[k]["text"]) % str(roundi(float(player.soul_fx[k]) * 100.0)) + (" (межа)" if cap else ""))
	return ", ".join(parts)


## Пом'яник: що в торбинці, що діє, і всі душі гри (незнайдені — сірим).
static func codex(player) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var all: Array = SoulService.known()
	var seen := 0
	for id in all:
		if int(player.souls.get(id, 0)) > 0 or id in SoulService.active_ids(player):
			seen += 1
	v.add_child(UI.label("Пом'яник душ", 24, UI.GOLD, false))
	v.add_child(_wrapped("У торбинці душ: %d. Маєш видів: %d із %d." % [SoulService.pouch_count(player), seen, all.size()], 16, UI.TEXT))
	var act: Array = SoulService.active_ids(player)
	if act.is_empty():
		v.add_child(_wrapped("Жодна душа не діє. Душа діє у гнізді вдягненої речі; гніздо пробиває коваль.", 15, UI.MUTED))
	else:
		v.add_child(_wrapped("Діють зараз: " + active_text(player) + ".", 16, UI.GOOD))
	var last_tier := 0
	for id in all:
		var t: int = SoulService.tier(id)
		if t != last_tier:
			last_tier = t
			v.add_child(UI.label(str(Souls.TIER_NAMES[t]) + (" • лише зброя й оберіг" if t >= Souls.BOSS_TIER else ""), 17, Souls.TIER_COLORS[t], false))
		var have: int = int(player.souls.get(id, 0))
		var worn: bool = id in act
		var mark := ("  діє" if worn else "") + ("  ×%d у торбинці" % have if have > 0 else "")
		var known_soul: bool = have > 0 or worn
		v.add_child(_wrapped("%s%s" % [SoulService.soul_name(id), mark if known_soul else "  ще не знайдено"], 16, Souls.TIER_COLORS[t] if known_soul else UI.MUTED))
		v.add_child(_wrapped(SoulService.fx_text(id), 14, UI.TEXT if known_soul else UI.MUTED))
	return v
