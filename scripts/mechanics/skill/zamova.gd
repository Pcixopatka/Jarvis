extends "res://scripts/mechanics/skill_mechanic.gd"
## Замовляння шаблі (Характерник): 10 с кожен удар перескакує блискавкою на двох найближчих сусідів цілі
## (ближче за 260), по 35% шкоди удару й 5% за ранг.

var t := 0.0  # скільки ще діє
var chaining := false  # блискавка саме перескакує: її удари вдруге не перескакують


func order() -> int:
	return 60


func cast() -> bool:
	t = 10.0
	Audio.play("spell", 0.05)
	say("Замовляння шаблі", Color(0.6, 0.8, 1.0))
	combat.spawn_fx("lightning", p.global_position - Vector2(0, 28), 1.2, 0.0, Color(0.8, 0.9, 1.0))
	return true


func tick(delta: float) -> void:
	t = maxf(0.0, t - delta)


func on_hit(e, dmg: float, _crit: bool, _hp_before: float) -> void:
	if t > 0.0 and not chaining:
		_chain(e, dmg)


## Замовлена шабля: удар перескакує блискавкою на двох сусідів.
func _chain(from, dmg: float) -> void:
	chaining = true
	var near := foes().filter(func(e): return e != from and e.global_position.distance_to(from.global_position) < 260.0)
	near.sort_custom(func(a, b): return from.global_position.distance_squared_to(a.global_position) < from.global_position.distance_squared_to(b.global_position))
	var pts := PackedVector2Array([from.global_position])
	for i in mini(2, near.size()):
		var e = near[i]
		pts.append(e.global_position)
		hit(e, dmg * (0.35 + 0.05 * rank()), Vector2.ZERO, false)
	if pts.size() > 1:
		combat.spawn_bolt(pts)
	chaining = false


## Блискавка, що кружляє біля шаблі.
func draw_aura(side: float) -> void:
	if t > 0.0:
		var za: float = p.walk_phase * 0.5 + t * 6.0
		p.draw_line(Vector2(side * 12, -4), Vector2(side * 12, -4) + Vector2.from_angle(za) * 26.0, Color(0.6, 0.85, 1.0, 0.8), 2.0)


func card(r: int) -> Array:
	return [["Шкода блискавки", "%d%% від удару" % roundi((0.35 + 0.05 * r) * 100)], ["Цілей", "2"], ["Тривалість", "10 с"]]
