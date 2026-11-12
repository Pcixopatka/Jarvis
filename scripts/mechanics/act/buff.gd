extends "res://scripts/mechanics/act_mechanic.gd"
## Підсилення на «dur» секунд (10): бонуси «fx» (ключі effects.json) лягають у Player.buffs і діють через
## recalc, поки не спливе час (Player._tick_buffs). «group» — одночасно діє одне підсилення групи (стійки);
## «heal» — лікує відсотків здоров'я (× сила лікування), «invuln» — невразливість, с, «cleanse» — знімає
## стани. Звук типово «roar», напис — «text» чи назва вміння.


func cast(n: Dictionary, A: Dictionary, r: int, _m: float, col: Color) -> bool:
	var id: String = str(n["id"])
	var group: String = str(A.get("group", ""))
	if group != "":
		for bid in p.buffs.keys():
			if str(p.buffs[bid].get("group", "")) == group:
				p.buffs.erase(bid)
	var bfx := {}
	for k in A.get("fx", {}):
		bfx[k] = Classes.val(A["fx"][k], r)
	p.buffs[id] = {"t": Classes.val(A.get("dur", 10.0), r), "fx": bfx, "group": group}
	p.recalc()
	if A.has("heal"):
		p.heal(p.max_hp * Classes.val(A["heal"], r) / 100.0 * p.heal_power())
	if A.has("invuln"):
		p.invuln = maxf(p.invuln, Classes.val(A["invuln"], r))
	if A.get("cleanse", false):
		p.statuses.clear()
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "roar", 0.05, -3.0)
	combat.float_text(p.global_position + Vector2(0, -70), str(A.get("text", n["name"])), col)
	combat.fx.ring(p.global_position, col, 24, 300, 5, 0.4)
	return true
