extends "res://scripts/mechanics/mechanic.gd"
## Бенкет (Ідолище, Золота Баба): бос сідає й чотири секунди гоїться. Хто встигне за цей час завдати
## йому шкоди на двадцяту частку здоров'я, той переб'є бенкет: бос вдавиться й стане беззахисним.

## Скільки ще бенкетує, с
var feast := 0.0
## Скільки шкоди отримав за цей бенкет
var feast_dmg := 0.0
## Гасла бенкету: [почав, наївся, вдавився] — задає бос
var feast_text: Array = ["", "", ""]


## Сідає бенкетувати (гасло й підказку бос дає сам).
func start_feast() -> void:
	feast = 4.0
	feast_dmg = 0.0
	e.cast_time = 4.0
	e.ability_timer = 5.0


## Бенкет урвано (бос лютішає).
func stop_feast() -> void:
	if feast > 0.0:
		feast = 0.0
		e.cast_time = 0.0


func tick(delta: float) -> void:
	if feast > 0.0:
		feast -= delta
		e.hp = minf(e.max_hp, e.hp + e.max_hp * (0.05 if e.phase2 else 0.04) * delta)
		if randf() < delta * 6.0:
			combat.fx.burst(e.global_position + Vector2(0, -e.radius), Color(0.9, 0.7, 0.3), 5, 120, 4, 0.4)
		if feast <= 0.0:
			e.cast_time = 0.0
			Events.banner.emit(str(feast_text[1]), Color(1.0, 0.6, 0.3))


func on_damage(amount: float) -> void:
	if feast > 0.0:
		feast_dmg += amount
		if feast_dmg >= e.max_hp * 0.05:
			feast = 0.0
			e.cast_time = 0.0
			e.stun = 3.5
			e.exposed = 3.5
			Events.banner.emit(str(feast_text[2]), Color(0.6, 1.0, 0.6))
