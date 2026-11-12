extends RefCounted
## Звукова мапа гри: гучність кожного звуку, голоси нечисті, фон за ландшафтом.
## Голос смерті кожного виду записаний у data/mobs.json (sounds.death), фоновий шум краєвиду — у
## data/biomes.json (ambient).
## Самі файли — assets/audio (збирає tools/audio/build_audio.py), перелік — sound_index.gd.

const GameDB := preload("res://scripts/core/game_db.gd")

## Базова гучність звуку в дБ: додається до гучності, вказаної в місці виклику.
## Усі файли вирівняні за гучністю, тож тут задано, наскільки помітним має бути кожен звук у грі.
const VOLUME := {
	"step": -15.0, "click": -7.0, "page": -3.0, "door": -5.0, "rustle": -5.0, "pot": -6.0, "dice": -1.0,
	"swing": -6.0, "shoot": -7.0, "hit": -2.0, "crit": 0.0, "slash": -1.0, "clash": -1.0, "unsheathe": -6.0,
	"whirl": -4.0, "dodge": -5.0, "hurt": -1.0, "musket": 0.0, "boom": 0.0, "lightning": -2.0,
	"fire": -3.0, "spell": -5.0, "zap": -8.0, "heal": -4.0, "portal": -4.0,
	"coin": -4.0, "coins": -3.0, "item": -3.0, "quest": 0.0, "levelup": -2.0,
	"sharpen_ok": -3.0, "sharpen_fail": -3.0, "roar": -1.0, "splash": -2.0,
	"enemy_die": -5.0, "die_beast": -5.0, "die_undead": -6.0, "die_slime": -5.0, "die_human": -6.0, "die_spirit": -6.0,
}

## Гучність фонових шумів у дБ (щоб вітер не перекрикував бій, а юрба було чути).
const AMBIENT_VOLUME := {"forest": -2.0, "wind": 0.0, "night": -4.0, "cave": 0.0, "river": -3.0, "fire": -3.0, "crowd": -6.0}


## Голос смерті нечисті: свій із data/mobs.json (sounds.death), решта — загальний «enemy_die».
static func death(kind: String) -> String:
	var s := GameDB.death_sound(kind)
	return s if s != "" else "enemy_die"


## Фоновий шум краєвиду ("" — тиша): свій із data/biomes.json, а вночі (крім печери) — нічний.
static func ambient_for(biome: String, night: bool = false) -> String:
	if night and biome != "cave":
		return "night"
	return str(GameDB.row("biomes", biome).get("ambient", ""))
