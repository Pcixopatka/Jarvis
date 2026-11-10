extends RefCounted
## Звукова мапа гри: гучність кожного звуку, голоси нечисті, фон за ландшафтом.
## Самі файли — assets/audio (збирає tools/audio/build_audio.py), перелік — sound_index.gd.

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

## Голос смерті за видом нечисті (решта — загальний «enemy_die»).
const DEATH := {
	"vovkulaka": "die_beast", "chort": "die_beast",
	"upyr": "die_undead", "zarazhenyi": "die_undead",
	"mavka": "die_spirit",
	"bolotianyk": "die_slime",
	"pishchalnyk": "die_human", "chaklun": "die_human", "rival": "die_human", "vidma": "die_spirit", "vii": "die_undead",
	"potopelnyk": "die_undead", "pesyholovets": "die_beast", "kamiana_baba": "die_undead", "mara": "die_spirit", "zlyden": "die_beast",
	"morskyi_tsar": "die_slime", "shubin": "die_undead", "bila_pani": "die_spirit",
}

## Фоновий шум за ландшафтом ("" — тиша).
const AMBIENT := {
	"steppe": "wind", "mountain": "wind", "forest": "forest", "village": "forest", "river": "river", "swamp": "night",
	"cave": "cave", "plague": "cave", "maidan": "crowd", "sand": "wind",
}
## Гучність фонових шумів у дБ (щоб вітер не перекрикував бій, а юрба було чути).
const AMBIENT_VOLUME := {"forest": -2.0, "wind": 0.0, "night": -4.0, "cave": 0.0, "river": -3.0, "fire": -3.0, "crowd": -6.0}


static func death(kind: String) -> String:
	return DEATH.get(kind, "enemy_die")


static func ambient_for(biome: String, night: bool = false) -> String:
	if night and biome != "cave":
		return "night"
	return AMBIENT.get(biome, "")
