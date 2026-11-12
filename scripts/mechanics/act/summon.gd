extends "res://scripts/mechanics/act_mechanic.gd"
## Сокіл-помічник на «dur» секунд (20): кружляє над героєм і раз на «tick» с (1,2) пірнає до найближчої
## нечисті й б'є її (pct). «boost» — уміння, що підсилює птаха (+12% за ранг), «mark» — уміння, з яким
## він ще й проклинає ціль (1,5 с + 0,5 с за ранг). Звук типово «swing», напис — «text» чи назва вміння.


func cast(n: Dictionary, A: Dictionary, r: int, m: float, col: Color) -> bool:
	var boost: float = 1.0 + 0.12 * p.sk(str(A.get("boost", "")))
	var z2 = combat.spawn_zone("falcon", p.global_position + Vector2(0, -70), 0.0, Classes.val(A.get("dur", 20.0), r), p.damage * m * boost)
	z2.mech = self
	z2.tick = float(A.get("tick", 1.2))
	z2.color = col
	var mark_rank: int = p.sk(str(A.get("mark", "")))
	if mark_rank > 0:
		z2.status = "curse"
		z2.status_dur = 1.5 + 0.5 * mark_rank
	var snd: String = str(A["sound"]) if A.has("sound") else ""
	Audio.play(snd if snd != "" else "swing", 0.1, -4.0)
	combat.float_text(p.global_position + Vector2(0, -70), str(A.get("text", n["name"])), col)
	return true


## Птах кружляє над героєм, а на удар пірнає до ворога.
func zone_tick(z, delta: float) -> void:
	var hero = z.combat.player
	var home: Vector2 = hero.global_position + Vector2(cos(z._t * 2.4) * 70.0, -80.0 + sin(z._t * 4.8) * 14.0)
	if z._dive > 0.0:
		z._dive -= delta
		z.global_position = z.global_position.lerp(z._dive_to, minf(1.0, delta * 14.0))
	else:
		z.global_position = z.global_position.lerp(home, minf(1.0, delta * 5.0))
	if z._tick <= 0.0:
		z._tick = z.tick
		var prey = z.combat.nearest_enemy(hero.global_position, 560.0)
		if prey:
			z._dive = 0.25
			z._dive_to = prey.global_position + Vector2(0, -10)
			hero.hit(prey, z.damage, Vector2.ZERO, false)
			if z.status != "" and not prey.dead:
				Status.apply(prey, z.status, z.status_dur)
			z.combat.fx.burst(prey.global_position, z.color, 6, 160, 4, 0.25)
