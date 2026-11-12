extends "res://scripts/mechanics/mechanic.gd"
## Злидень: тягне гроші. Що поцупив, те й носить при собі, доки його не здолати (див. Enemy.loot_gold).


func on_hit(target) -> void:
	if "gold" in target and int(target.gold) > 0:
		var g: int = mini(int(target.gold), 3 * e.level)
		target.gold -= g
		e.loot_gold += g
		combat.float_text(target.global_position + Vector2(0, -80), "Злидень поцупив %d грн" % g, Color(1.0, 0.8, 0.3))
