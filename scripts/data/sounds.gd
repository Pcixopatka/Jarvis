extends RefCounted
## Звукова мапа гри: гучність кожного звуку, голоси нечисті, фон за ландшафтом.
## Голос смерті кожного виду записаний у data/mobs.json (sounds.death), фоновий шум краєвиду — у
## data/biomes.json (ambient), гучність кожного звуку — у data/sounds.json, фонового шуму — у data/ambients.json.
## Самі файли — assets/audio (збирає tools/audio/build_audio.py), перелік — sound_index.gd.

const GameDB := preload("res://scripts/core/game_db.gd")

static var _volume := {}
static var _ambient := {}


## Базова гучність звуку в дБ: {звук: дБ}, додається до гучності, вказаної в місці виклику. Усі файли
## вирівняні за гучністю, тож тут задано, наскільки помітним має бути кожен звук у грі. Складається раз
## із data/sounds.json; Audio тримає цей словник у себе, тож гучність звуку — одне читання словника.
static func volumes() -> Dictionary:
	if _volume.is_empty():
		_volume = _flat("sounds")
	return _volume


## Гучність фонових шумів у дБ (щоб вітер не перекрикував бій, а юрбу було чути): data/ambients.json.
static func ambient_volumes() -> Dictionary:
	if _ambient.is_empty():
		_ambient = _flat("ambients")
	return _ambient


static func _flat(table: String) -> Dictionary:
	var out := {}
	for id in GameDB.ids(table):
		out[id] = float(GameDB.row(table, id)["volume"])
	out.make_read_only()
	return out


## Голос смерті нечисті: свій із data/mobs.json (sounds.death), решта — загальний «enemy_die».
static func death(kind: String) -> String:
	var s := GameDB.death_sound(kind)
	return s if s != "" else "enemy_die"


## Фоновий шум краєвиду ("" — тиша): свій із data/biomes.json, а вночі (крім печери) — нічний.
static func ambient_for(biome: String, night: bool = false) -> String:
	if night and biome != "cave":
		return "night"
	return str(GameDB.row("biomes", biome).get("ambient", ""))
