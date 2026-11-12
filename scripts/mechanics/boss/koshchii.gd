extends "res://scripts/mechanics/mechanic.gd"
## Кощій Безсмертний: кістяні списи віялом, кличе пищальників і заражених, смертний холод довкола
## себе. Стріляє трьома кістками. Його смерть схована в голці: поки голку не знайдено (історія),
## після смертельного удару він раз устає знову з половиною здоров'я.


func ability(target, _dist: float) -> void:
	var to_t := dir_to(target)
	e.ability_timer = 3.8 if e.phase2 else 5.0
	match e.ability_step % 3:
		1:
			# Кістяні списи: три лінії віялом до цілі
			Audio.play("roar", 0.05, -4.0)
			for a in [-0.45, 0.0, 0.45]:
				var t = telegraph("line", e.global_position, 1.0, e.damage * 1.2)
				t.dir = to_t.rotated(a)
				t.length = 540.0
				t.width = 70.0
				t.color = Color(0.9, 0.9, 0.75)
		2:
			Audio.play("roar", 0.15, -4.0)
			summon(["pishchalnyk", "zarazhenyi"], 3)
		0:
			# Смертний холод довкола себе — тікай подалі
			var t = telegraph("circle", e.global_position, 1.3, e.damage * 1.6)
			t.radius = 230.0
			t.color = Color(0.55, 0.85, 1.0)


func volley(dir: Vector2) -> void:
	for a in [-0.2, 0.0, 0.2]:
		shoot(e.global_position, dir.rotated(a), 300.0, e.damage * 0.55, Color(0.9, 0.9, 0.8), 10.0)


func phase2() -> void:
	rage("Кощій лютує!", ["zarazhenyi", "pishchalnyk"])


func on_lethal() -> bool:
	if combat.boss_revives <= 0:
		return false
	# Кощієва смерть схована в голці — поки голка ціла, він встає знову
	combat.boss_revives -= 1
	e.hp = e.max_hp * 0.5
	Events.banner.emit("Кощій встає знову!\nЙого смерть — не тут...", Color(0.75, 1.0, 0.6))
	combat.fx.burst(e.global_position, Color(0.6, 1.0, 0.3), 40, 300, 8, 0.8)
	Audio.play("roar", 0.0)
	return true
