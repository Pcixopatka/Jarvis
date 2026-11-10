extends RefCounted
## Коло Кожум'яки на Змієвих валах: три чудовиська поспіль, між ними — короткий перепочинок.
## Склад міняється щотижня (однаковий для всіх героїв). Смерті нема: не встояв — винесли з кола.
## За кожне коло раз на тиждень дають гаманець і славу, за всі три — річ і трофеї.
## Потім можна ходити скільки завгодно: на час, на рекорд і за малий денний гаманець.
## Стан — world.ring: {"week": ключ тижня, "paid": кіл оплачено цього тижня (0..3), "titles": повних проходжень,
##   "best_time": найкращий час бою за три кола (с), "runs": виходів, "day": ключ дня, "day_paid": малих гаманців сьогодні}

const Acts := preload("res://scripts/data/activities.gd")
const Data := preload("res://scripts/data/data.gd")
const ChallengeService := preload("res://scripts/game/challenge_service.gd")
const DuelService := preload("res://scripts/game/duel_service.gd")
const GloryService := preload("res://scripts/game/glory_service.gd")
const Power := preload("res://scripts/game/power.gd")

const SPOT_ID := "kolo"


static func week() -> String:
	return ChallengeService.week_key(ChallengeService._now())


static func state(world) -> Dictionary:
	var s: Dictionary = world.ring
	if s.get("week", "") != week():
		s["week"] = week()
		s["paid"] = 0
	for k in ["paid", "titles", "runs", "day_paid"]:
		if not s.has(k):
			s[k] = 0
	if not s.has("best_time"):
		s["best_time"] = 0.0
	var day := ChallengeService.day_key(ChallengeService._now())
	if s.get("day", "") != day:
		s["day"] = day
		s["day_paid"] = 0
	return s


static func unlocked(player) -> bool:
	return not player.is_peasant() and player.level >= int(Acts.SPOTS[SPOT_ID]["level"])


## Три чудовиська цього тижня, від легшого кола до найтяжчого.
static func lineup(week_key: String = "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("ring:" + (week_key if week_key != "" else week()))
	var ids: Array = Acts.RING_POOL.duplicate()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	return ids.slice(0, int(Acts.RING_STAGES))


## Сила чудовиська в колі stage (0 — перше): {"hp", "dmg"} у справжніх числах і "cap" — яку частку
## здоров'я воно щонайбільше втрачає за секунду (щоб сильний герой не клав його одним вмінням).
static func boss_stats(player, stage: int) -> Dictionary:
	var i := clampi(stage, 0, int(Acts.RING_STAGES) - 1)
	return {"hp": Power.dps(player) * float(Acts.RING_SECONDS[i]),
		"dmg": Power.hit(player, float(Acts.RING_HIT[i]) * DuelService.hit_scale(player.level)),
		"cap": 1.0 / (float(Acts.RING_CAP) * float(Acts.RING_SECONDS[i]))}


## Опис бою (для combat.enter через defense_loc).
static func battle_loc(player) -> Dictionary:
	return {"name": "Коло Кожум'яки", "type": "ring", "biome": "steppe", "level": maxi(1, player.level), "enemies": ["zarazhenyi"],
		"bosses": lineup(), "hero_level": player.level,
		"std_hp": Power.dps(player) * float(Acts.RING_STD_TTK), "std_dmg": Power.hit(player, float(Acts.RING_STD_HIT)),
		"xp_mult": float(Acts.RING_XP), "desc": ""}


static func stage_gold(level: int, stage: int) -> int:
	return int(Acts.RING_GOLD[clampi(stage, 0, int(Acts.RING_STAGES) - 1)]) * level


static func time_text(t: float) -> String:
	var secs := int(t)
	return "%d:%02d" % [secs / 60, secs % 60]


## Чудовисько кола stage (1 — перше) здолано. Повертає {"gold", "glory", "weekly": чи це тижнева нагорода, "msgs"}.
static func on_stage(world, player, stage: int) -> Dictionary:
	var s := state(world)
	var out := {"gold": 0, "glory": 0, "weekly": false, "msgs": []}
	if stage > int(s["paid"]) and stage <= int(Acts.RING_STAGES):
		s["paid"] = stage
		out["weekly"] = true
		out["gold"] = stage_gold(player.level, stage - 1)
		out["glory"] = int(Acts.RING_GLORY[stage - 1])
		out["msgs"] = GloryService.add(world, player, int(out["glory"]))
	elif int(s["day_paid"]) < int(Acts.RING_REPEAT_PAID):
		s["day_paid"] = int(s["day_paid"]) + 1
		out["gold"] = int(Acts.RING_REPEAT_GOLD) * player.level
	player.gold += int(out["gold"])
	return out


## Усі три кола пройдено за time секунд бою. first_week — це перше повне проходження цього тижня
## (тоді ще річ і трофеї). Повертає {"record": чи новий рекорд часу, "item": рідкість речі або -1, "trophy": n}.
static func finish(world, player, time: float, first_week: bool) -> Dictionary:
	var s := state(world)
	s["titles"] = int(s["titles"]) + 1
	s["runs"] = int(s["runs"]) + 1
	var best: float = float(s["best_time"])
	var record: bool = best <= 0.0 or time < best
	if record:
		s["best_time"] = time
	var out := {"record": record, "item": -1, "trophy": 0}
	if first_week:
		out["item"] = 2
		out["trophy"] = 3
		player.resources["trophy"] = int(player.resources.get("trophy", 0)) + 3
	return out


## Скільки днів до нового складу чудовиськ.
static func days_to_reset() -> int:
	return DuelService.days_to_reset()
