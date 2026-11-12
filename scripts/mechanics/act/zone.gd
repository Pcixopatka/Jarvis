extends "res://scripts/mechanics/act_mechanic.gd"
## Зона на найближчому ворогові (у межах «range», типово 550; з «"at": "self"» — на герої): коло «radius»
## (150) на «dur» секунд (4), що раз на «tick» с (0,5) б'є всіх усередині (pct) і накладає стан «status».
## Звук типово «spell». На картці шкода — за кожен удар зони.


func cast(_n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var pos: Vector2 = p.global_position
	if str(A.get("at", "enemy")) == "enemy":
		var tz: Node2D = nearest(Classes.val(A.get("range", 550.0), r))
		if tz == null:
			return false
		pos = tz.global_position
	var z = combat.spawn_zone("skill", pos, Classes.val(A.get("radius", 150.0), r), Classes.val(A.get("dur", 4.0), r), p.damage * m)
	z.mech = self
	z.tick = float(A.get("tick", 0.5))
	z.color = col
	if A.has("status"):
		z.status = str(A["status"][0])
		z.status_dur = float(A["status"][1])
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "spell", 0.15, -2.0)
	combat.fx.ring(pos, col, 20, Classes.val(A.get("radius", 150.0), r) * 2.0, 5, 0.4)
	return true


## Раз на z.tick с б'є всіх у колі й накладає стан.
func zone_tick(z, _delta: float) -> void:
	if z._tick > 0.0:
		return
	z._tick = z.tick
	var hero = z.combat.player
	for e in z.combat.enemies_now():
		if not in_zone(z, e):
			continue
		if z.damage > 0.0:
			hero.hit(e, z.damage, Vector2.ZERO, false)
		if z.status != "" and not e.dead:
			Status.apply(e, z.status, z.status_dur, z.damage * 0.2 if z.status in ["bleed", "burn", "plague"] else 0.0)


func damage_label() -> String:
	return "Шкода за удар"
