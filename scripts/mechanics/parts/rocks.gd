extends "res://scripts/mechanics/mechanic.gd"
## Каміння зі стелі (Вій, Шубін у люті): поки бос не приголомшений і не заносить удар, щокілька секунд
## під ногами героя падає камінь. Бос повільний, тож стояти на місці не дає саме підземелля.

## За скільки секунд упаде наступний камінь
var rock_timer := 2.5


## Чи сиплеться каміння зараз (Шубін — лише в люті).
func rocks_falling() -> bool:
	return true


func tick(delta: float) -> void:
	if rocks_falling() and e.stun <= 0.0 and e.cast_time <= 0.0:
		rock_timer -= delta
		if rock_timer <= 0.0:
			rock_timer = 1.6 if e.phase2 else 2.3
			drop_rock()


## Камінь: коло під ногами героя.
func drop_rock() -> void:
	var target = combat.player
	if target == null or not target.alive:
		return
	var t = telegraph("circle", target.global_position, 0.9, e.damage * 0.7)
	t.radius = 85.0
	t.color = Color(0.6, 0.55, 0.5)
