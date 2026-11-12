extends "res://scripts/mechanics/mob/samodiva.gd"
## Чудь: кидає камінь уздовж смуги, як самодива стрілу; влучний камінь знесилює.


func _init() -> void:
	shot_status = "weak"
	shot_color = Color(0.9, 0.9, 0.95)
