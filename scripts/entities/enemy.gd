class_name Enemy
extends Node2D
## Нечисть: мавка, упир, болотяник, вовкулака; боси — Змій або велетенські різновиди інших.

const Data := preload("res://scripts/data/data.gd")
const TelegraphScript := preload("res://scripts/world/telegraph.gd")
const Status := preload("res://scripts/game/status.gd")
const Elites := preload("res://scripts/data/elites.gd")
## Який стан може накласти удар цього ворога (шанс HIT_STATUS_CHANCE)
const HIT_STATUS := {"zarazhenyi": "plague", "pishchalnyk": "plague", "bolotianyk": "plague", "chaklun": "plague", "putinoid": "plague",
	"vovkulaka": "bleed", "upyr": "bleed", "chort": "burn", "zmii": "burn", "mavka": "chill", "koshchii": "chill"}
const HIT_STATUS_CHANCE := 0.3

var combat: Combat
var kind := "mavka"
var level := 1
var radius := 16.0
var r_draw := 16.0  # радіус для малювання (без урахування масштабу боса)
var max_hp := 30.0
var hp := 30.0
var speed := 150.0
var damage := 8.0
var xp_value := 3
var color := Color.WHITE
var infected := 0  # рівень зарази місцевості: зелена аура, сильніший
var ranged := false
var is_boss := false
var keep_distance := 0.0
var shoot_cd := 2.0
var shoot_timer := 1.5
var knockback := Vector2.ZERO
var flash := 0.0
var slow_timer := 0.0
var contact_cd := 0.0
var lunge_timer := 0.0
var phase := randf() * TAU
var facing := Vector2.LEFT
var dead := false
var dying := 0.0  # анімація смерті
var windup := 0.0  # замах перед ударом: червоніє — час ухилятися
var windup_max := 0.35
var ability_timer := 4.0
var ability_step := 0
var stun := 0.0  # приголомшений: не рухається й не б'є
var statuses := {}  # стани (див. Status)
var elite := false
var affixes := []  # властивості еліти (див. Elites.AFFIXES)
var title := ""  # ім'я еліти над головою
var dmg_taken_mult := 1.0
var base_scale := 1.0
var blink_timer := 2.5  # чорт: телепорт до цілі
var phase2 := false  # боси Кощій і Путіноїд лютішають на половині здоров'я


func setup(k: String, lvl: int, boss: bool = false) -> void:
	kind = k
	level = lvl
	var s := Data.ENEMY_HP_MULT * (1.0 + Data.ENEMY_HP_PER_LEVEL * (lvl - 1))
	match k:
		"mavka":
			radius = 16.0; max_hp = 30.0; speed = 150.0; damage = 8.0; xp_value = 3
			color = Color(0.6, 0.92, 0.65)
		"upyr":
			radius = 22.0; max_hp = 85.0; speed = 92.0; damage = 15.0; xp_value = 6
			color = Color(0.5, 0.1, 0.14)
		"bolotianyk":
			radius = 20.0; max_hp = 45.0; speed = 85.0; damage = 7.0; xp_value = 5
			color = Color(0.33, 0.45, 0.2)
			ranged = true; keep_distance = 320.0; shoot_cd = 2.8
		"vovkulaka":
			radius = 19.0; max_hp = 55.0; speed = 175.0; damage = 12.0; xp_value = 5
			color = Color(0.45, 0.43, 0.42)
		"zarazhenyi":
			radius = 20.0; max_hp = 70.0; speed = 100.0; damage = 13.0; xp_value = 6
			color = Color(0.45, 0.16, 0.13)
		"chaklun":
			radius = 24.0; max_hp = 90.0; speed = 95.0; damage = 22.0; xp_value = 7
			color = Color(0.12, 0.1, 0.14)
			ranged = true; keep_distance = 300.0; shoot_cd = 2.2
		"chort":
			radius = 17.0; max_hp = 50.0; speed = 185.0; damage = 13.0; xp_value = 6
			color = Color(0.42, 0.12, 0.08)
		"pishchalnyk":
			radius = 19.0; max_hp = 55.0; speed = 90.0; damage = 15.0; xp_value = 7
			color = Color(0.4, 0.14, 0.12)
			ranged = true; keep_distance = 340.0; shoot_cd = 2.6
		"koshchii":
			radius = 24.0; max_hp = 170.0; speed = 100.0; damage = 26.0; xp_value = 8
			color = Color(0.1, 0.08, 0.1)
			ranged = true; keep_distance = 220.0; shoot_cd = 2.4
		"putinoid":
			radius = 26.0; max_hp = 260.0; speed = 105.0; damage = 30.0; xp_value = 10
			color = Color(0.45, 0.06, 0.1)
			ranged = true; keep_distance = 260.0; shoot_cd = 2.0
		"zmii":
			radius = 52.0; max_hp = 60.0; speed = 70.0; damage = 17.0; xp_value = 6
			color = Color(0.2, 0.55, 0.25)
			ranged = true; shoot_cd = 2.6
	r_draw = radius
	max_hp *= s
	damage *= 1.0 + Data.ENEMY_DMG_PER_LEVEL * (lvl - 1)
	xp_value = int(xp_value * (1.0 + Data.ENEMY_XP_PER_LEVEL * (lvl - 1)))
	speed *= minf(1.3, 1.0 + 0.02 * (lvl - 1))
	if boss or k == "zmii":
		is_boss = true
		max_hp *= Data.BOSS_HP_MULT
		damage *= 1.5
		xp_value *= Data.BOSS_XP_MULT
		if k != "zmii":
			base_scale = 2.0
			scale = Vector2.ONE * base_scale
			radius *= 2.0
			speed *= 0.85
	shoot_timer = randf_range(1.0, shoot_cd)
	windup_max = {"mavka": 0.3, "upyr": 0.45, "bolotianyk": 0.4, "vovkulaka": 0.25, "zarazhenyi": 0.5, "chaklun": 0.5, "zmii": 0.5,
		"chort": 0.28, "pishchalnyk": 0.45}.get(k, 0.35)
	if is_boss:
		windup_max = 0.55
		ability_timer = 3.0
	hp = max_hp
	add_to_group("enemies")


## Найближчий союзник (козак або супутник).
func _pick_target():
	var best = null
	var best_d := INF
	for a in combat.allies():
		var d: float = global_position.distance_squared_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _process(delta: float) -> void:
	if dead:
		dying -= delta
		var k := clampf(dying / 0.35, 0.0, 1.0)
		modulate = Color(1.6, 1.6, 1.6, k)
		scale = Vector2.ONE * base_scale * (0.6 + 0.4 * k)
		if dying <= 0.0:
			queue_free()
		return
	var p = _pick_target()
	flash = maxf(0.0, flash - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	contact_cd = maxf(0.0, contact_cd - delta)
	lunge_timer = maxf(0.0, lunge_timer - delta)
	phase += delta * 6.0
	var dot := Status.tick(self, delta)
	if dot > 0.0:
		take_damage(dot, Vector2.ZERO)
		if dead:
			return
	if stun > 0.0:
		stun -= delta
		windup = 0.0
		position += knockback * delta
		knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
		queue_redraw()
		return

	var desired := Vector2.ZERO
	var dist := INF
	var dir := facing
	if p != null:
		var to: Vector2 = p.global_position - global_position
		dist = to.length()
		dir = to / maxf(dist, 0.001)
		facing = dir
		desired = dir
		if keep_distance > 0.0:
			if dist < keep_distance * 0.8:
				desired = -dir
			elif dist < keep_distance * 1.15:
				desired = dir.orthogonal() * sin(phase * 0.15)
		# Вовкулака робить стрибок, коли близько
		if kind == "vovkulaka" and dist < 220.0 and lunge_timer <= 0.0:
			lunge_timer = 2.5
			knockback += dir * 520.0
		# Чорт зникає в клубі диму й вигулькує просто біля цілі
		if kind == "chort":
			blink_timer -= delta
			if blink_timer <= 0.0 and dist > 160.0 and dist < 900.0:
				blink_timer = randf_range(3.5, 5.0)
				combat.fx.burst(global_position, Color(0.3, 0.1, 0.05), 14, 160, 6, 0.4)
				global_position = p.global_position + Vector2.from_angle(randf() * TAU) * 80.0
				combat.fx.burst(global_position, Color(0.9, 0.35, 0.1), 14, 160, 6, 0.4)
				windup = windup_max * 1.6  # даємо мить, щоб ухилитися

	# Розштовхування, щоб нечисть не злипалась в одну купу
	var sep := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or o.dead:
			continue
		var d: Vector2 = global_position - o.global_position
		var min_d: float = radius + o.radius
		var l := d.length()
		if l < min_d and l > 0.01:
			sep += d / l * (min_d - l) / min_d

	var spd := speed * (0.4 if slow_timer > 0.0 else 1.0) * (0.15 if windup > 0.0 else 1.0) * Status.speed_mult(self)
	var vel := desired * spd + sep * speed * 1.5 + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	position += vel * delta
	var pad := Vector2(radius, radius)
	position = position.clamp(combat.arena.position + pad, combat.arena.end - pad)

	# Ближня атака із замахом: ворог червоніє, і за мить б'є, якщо ціль досі поруч
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			contact_cd = 1.0
			if p != null and dist < radius + p.radius + 24.0:
				if p.take_damage(damage * Status.damage_mult(self), self) == true:
					on_hit(p)
	elif p != null and dist < radius + p.radius + 10.0 and contact_cd <= 0.0:
		windup = windup_max

	if is_boss and p != null:
		ability_timer -= delta
		if ability_timer <= 0.0:
			_boss_ability(p)

	if ranged and p != null:
		shoot_timer -= delta * (0.5 if slow_timer > 0.0 else 1.0)
		if shoot_timer <= 0.0 and dist < 750.0:
			shoot_timer = shoot_cd
			if kind == "zmii":
				for a in [-0.35, 0.0, 0.35]:
					_shoot(global_position + dir * 40.0, dir.rotated(a), 300.0, damage * 0.6, Color(1.0, 0.5, 0.1), 13.0)
			elif kind == "pishchalnyk":
				_shoot(global_position + dir * 24.0, dir, 420.0, damage, Color(1.0, 0.75, 0.3), 7.0)
			elif kind == "koshchii":
				for a in [-0.2, 0.0, 0.2]:
					_shoot(global_position, dir.rotated(a), 300.0, damage * 0.55, Color(0.9, 0.9, 0.8), 10.0)
			elif kind == "putinoid":
				var n := 7 if phase2 else 5
				for i in n:
					_shoot(global_position, dir.rotated((i - (n - 1) / 2.0) * 0.18), 270.0, damage * 0.5, Color(0.5, 1.0, 0.2), 11.0)
			elif kind == "chaklun":
				for a in [-0.3, -0.1, 0.1, 0.3]:
					_shoot(global_position, dir.rotated(a), 250.0, damage * 0.5, Color(0.45, 0.95, 0.2), 11.0)
			elif is_boss:
				for a in [-0.25, 0.0, 0.25]:
					_shoot(global_position, dir.rotated(a), 280.0, damage * 0.6, Color(0.55, 0.85, 0.2), 12.0)
			else:
				_shoot(global_position, dir, 220.0, damage, Color(0.55, 0.85, 0.2), 9.0)
	queue_redraw()


func take_damage(amount: float, kb: Vector2, crit: bool = false) -> void:
	if dead:
		return
	amount *= dmg_taken_mult
	if "iron" in affixes:
		kb *= 0.2
	hp -= amount
	flash = 0.12
	knockback += kb * (0.15 if is_boss else 1.0)
	var col := Color(1.0, 0.85, 0.2) if crit else Color.WHITE
	combat.float_text(global_position + Vector2(0, -radius - 14), str(int(amount)) + ("!" if crit else ""), col)
	var blood: Color = {"mavka": Color(0.75, 1.0, 0.75), "upyr": Color(0.55, 0.05, 0.08), "bolotianyk": Color(0.45, 0.55, 0.2),
		"vovkulaka": Color(0.7, 0.1, 0.1), "zarazhenyi": Color(0.25, 0.4, 0.1), "zmii": Color(0.3, 0.8, 0.3)}.get(kind, Color.WHITE)
	combat.fx.burst(global_position + Vector2(0, -radius * 0.5), blood, 7 if crit else 4, 240, 4.0, 0.35, 300, (-kb).angle() + PI if kb.length() > 1 else 0.0, TAU if kb.length() <= 1 else 1.6)
	if crit:
		combat.fx.burst(global_position + Vector2(0, -radius * 0.5), Color(1, 0.95, 0.6), 6, 320, 3.0, 0.2)
	if is_boss and kind in ["koshchii", "putinoid"] and not phase2 and hp < max_hp * 0.5 and hp > 0.0:
		_enter_phase2()
	if hp <= 0.0 and kind == "koshchii" and combat.boss_revives > 0:
		# Кощієва смерть схована в голці — поки голка ціла, він встає знову
		combat.boss_revives -= 1
		hp = max_hp * 0.5
		Events.banner.emit("Кощій встає знову!\nЙого смерть — не тут...", Color(0.75, 1.0, 0.6))
		combat.fx.burst(global_position, Color(0.6, 1.0, 0.3), 40, 300, 8, 0.8)
		Audio.play("roar", 0.0)
		return
	if hp <= 0.0:
		dead = true
		dying = 0.35
		remove_from_group("enemies")
		if kind == "zarazhenyi" or "plague" in affixes:
			combat.spawn_plague(global_position, damage * 0.6)
		if "explosive" in affixes:
			combat.spawn_blast(global_position, 140.0, 0.9, damage * 1.6, Color(1.0, 0.35, 0.1))
		Events.enemy_killed.emit(self)


## Снаряд цього ворога (через нього удар може накласти стан).
func _shoot(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	combat.spawn_projectile(pos, dir, spd, dmg * Status.damage_mult(self), col, r, self)


## Удар ворога влучив і поранив ціль: стани, вампіризм еліти.
func on_hit(target) -> void:
	if dead or not is_instance_valid(target) or not target.has_method("add_status"):
		return
	var st: String = HIT_STATUS.get(kind, "")
	if st != "" and randf() < (HIT_STATUS_CHANCE * 0.5 if is_boss else HIT_STATUS_CHANCE):
		target.add_status(st, 3.0, damage * 0.1)
	for a in affixes:
		var info: Dictionary = Elites.AFFIXES[a]
		if info.has("status"):
			target.add_status(info["status"], 3.5, damage * 0.15)
		if a == "vampire":
			hp = minf(max_hp, hp + damage * 0.8)
			combat.fx.burst(global_position, Color(0.85, 0.1, 0.2), 6, 90, 4, 0.4)


## Перетворює на еліту з властивостями.
func make_elite(affs: Array) -> void:
	elite = true
	affixes = affs
	max_hp *= Elites.HP_MULT
	hp = max_hp
	damage *= Elites.DMG_MULT
	xp_value *= Elites.XP_MULT
	base_scale = 1.25
	scale = Vector2.ONE * base_scale
	radius *= 1.25
	if "swift" in affs:
		speed *= 1.35
		windup_max *= 0.8
	if "iron" in affs:
		dmg_taken_mult = 0.55
	title = Elites.title(kind, Data.ENEMY_NAMES[kind], affs)


# --- Особливі атаки босів ---

func _telegraph(shape: String, pos: Vector2, dur: float, dmg: float):
	var t = TelegraphScript.new()
	t.combat = combat
	t.source = self
	t.shape = shape
	t.position = pos
	t.duration = dur
	t.damage = dmg
	combat.effects.add_child(t)
	return t


func _summon(kinds: Array, count: int) -> void:
	for i in count:
		var pos := global_position + Vector2.from_angle(randf() * TAU) * randf_range(90, 160)
		combat.fx.burst(pos, Color(0.3, 0.25, 0.3), 14, 140, 8, 0.6)
		combat.spawn_enemy(kinds[randi() % kinds.size()], maxi(1, level - 1), false, pos)


func _boss_ability(target) -> void:
	var to_t: Vector2 = (target.global_position - global_position).normalized()
	ability_step += 1
	match kind:
		"zmii":
			# Вогняний подих конусом
			ability_timer = 5.5
			var t = _telegraph("cone", global_position, 1.0, damage * 1.3)
			t.dir = to_t
			t.length = 420.0
			t.half_angle = 0.42
			t.color = Color(1.0, 0.45, 0.1)
			Audio.play("roar", 0.05, -3.0)
		"upyr":
			ability_timer = 6.0
			if ability_step % 2 == 1:
				# Стрибок-удар у місце, де стоїть ціль
				var t = _telegraph("circle", target.global_position, 1.0, damage * 1.4)
				t.radius = 120.0
				t.on_fire = func():
					if not dead:
						global_position = t.global_position
			else:
				Audio.play("roar", 0.05, -4.0)
				_summon(["upyr", "mavka"], 3)
		"vovkulaka":
			ability_timer = 5.0
			if ability_step % 2 == 1:
				# Ривок по прямій
				var t = _telegraph("line", global_position, 0.75, damage * 1.3)
				t.dir = to_t
				t.length = 480.0
				t.width = 90.0
				t.on_fire = func():
					if not dead:
						knockback = to_t * 1900.0
			else:
				Audio.play("roar", 0.05, -2.0)
				_summon(["vovkulaka"], 2)
		"chaklun":
			ability_timer = 4.5
			match ability_step % 3:
				1:
					# Дощ зарази: три зони навколо цілі, після удару лишаються хмари
					Audio.play("lightning", 0.1, -6.0)
					for i in 3:
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 130.0)
						var t = _telegraph("circle", pos, 1.1, damage * 0.9)
						t.radius = 85.0
						t.color = Color(0.45, 0.9, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.5)
				2:
					_summon_infected()
				0:
					# Зникає в зеленому димі й з'являється подалі, розкидаючи кільце снарядів
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					var best := global_position
					for i in 8:
						var cand := Vector2(randf_range(combat.arena.position.x + 120, combat.arena.end.x - 120), randf_range(combat.arena.position.y + 120, combat.arena.end.y - 120))
						if cand.distance_to(target.global_position) > best.distance_to(target.global_position):
							best = cand
					global_position = best
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					for i in 10:
						_shoot(global_position, Vector2.from_angle(TAU * i / 10.0), 220.0, damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)
		"koshchii":
			ability_timer = 3.8 if phase2 else 5.0
			match ability_step % 3:
				1:
					# Кістяні списи: три лінії віялом до цілі
					Audio.play("roar", 0.05, -4.0)
					for a in [-0.45, 0.0, 0.45]:
						var t = _telegraph("line", global_position, 1.0, damage * 1.2)
						t.dir = to_t.rotated(a)
						t.length = 540.0
						t.width = 70.0
						t.color = Color(0.9, 0.9, 0.75)
				2:
					Audio.play("roar", 0.15, -4.0)
					_summon(["pishchalnyk", "zarazhenyi"], 3)
				0:
					# Смертний холод довкола себе — тікай подалі
					var t = _telegraph("circle", global_position, 1.3, damage * 1.6)
					t.radius = 230.0
					t.color = Color(0.55, 0.85, 1.0)
		"putinoid":
			ability_timer = 3.2 if phase2 else 4.5
			match ability_step % 4:
				1:
					# Дощ зарази
					Audio.play("lightning", 0.1, -6.0)
					for i in (5 if phase2 else 4):
						var pos: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * 150.0)
						var t = _telegraph("circle", pos, 1.1, damage * 0.9)
						t.radius = 90.0
						t.color = Color(0.45, 0.9, 0.15)
						t.on_fire = func(): combat.spawn_plague(pos, damage * 0.5)
				2:
					Audio.play("roar", 0.15, -4.0)
					_summon(["zarazhenyi", "pishchalnyk", "chort"], 4 if phase2 else 3)
				3:
					# Ривок трону — по прямій через усю залу
					var t = _telegraph("line", global_position, 0.85, damage * 1.4)
					t.dir = to_t
					t.length = 620.0
					t.width = 110.0
					t.on_fire = func():
						if not dead:
							knockback = to_t * 2000.0
				0:
					# Кільце зарази з-під трону
					combat.fx.burst(global_position, Color(0.35, 0.8, 0.15), 30, 260, 8, 0.6)
					for i in 14:
						_shoot(global_position, Vector2.from_angle(TAU * i / 14.0), 230.0, damage * 0.45, Color(0.45, 0.95, 0.2), 10.0)
		_:
			ability_timer = 6.0
			var t = _telegraph("circle", target.global_position, 1.0, damage * 1.3)
			t.radius = 110.0


func _enter_phase2() -> void:
	phase2 = true
	speed *= 1.2
	shoot_cd *= 0.75
	ability_timer = 1.0
	combat.shake(12.0)
	Audio.play("roar", 0.0)
	var text := "Путіноїд скидає личину!" if kind == "putinoid" else "Кощій лютує!"
	Events.banner.emit(text, Color(1.0, 0.4, 0.3))
	_summon(["zarazhenyi", "pishchalnyk"] if kind == "koshchii" else ["zarazhenyi", "pishchalnyk", "chort"], 3)


func _summon_infected() -> void:
	Audio.play("roar", 0.15, -4.0)
	_summon(["zarazhenyi"], 3)


# --- Малювання ---

func _c(c: Color) -> Color:
	if flash > 0.0:
		return Color(1, 1, 1, c.a)
	if not statuses.is_empty():
		c = c.lerp(Color(Status.tint(self), c.a), 0.3)
	if windup > 0.0:
		return c.lerp(Color(1.0, 0.25, 0.2, c.a), 0.55 * (1.0 - windup / windup_max))
	return c


func _draw() -> void:
	draw_set_transform(Vector2(0, r_draw * 0.9), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, r_draw * 1.1, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var side := 1.0 if facing.x >= 0.0 else -1.0
	if infected > 0:
		var pulse := 0.5 + 0.5 * sin(phase * 1.3)
		draw_circle(Vector2(0, -r_draw * 0.4), r_draw * (1.15 + 0.1 * pulse), Color(0.45, 0.85, 0.15, 0.07 + 0.05 * infected))
	if windup > 0.0:
		var w := 1.0 - windup / windup_max
		draw_circle(Vector2(0, -r_draw * 0.4), r_draw * (1.3 + 0.4 * w), Color(1.0, 0.15, 0.1, 0.18 + 0.3 * w))
	match kind:
		"mavka":
			_draw_mavka(side)
		"upyr":
			_draw_upyr(side)
		"bolotianyk":
			_draw_bolotianyk(side)
		"vovkulaka":
			_draw_vovkulaka(side)
		"zarazhenyi":
			_draw_zarazhenyi(side)
		"pishchalnyk":
			_draw_zarazhenyi(side, true)
		"chort":
			_draw_chort(side)
		"koshchii":
			_draw_koshchii(side)
		"putinoid":
			_draw_putinoid(side)
		"chaklun":
			_draw_chaklun(side)
		"zmii":
			_draw_zmii()
	if slow_timer > 0.0:
		draw_arc(Vector2(0, -r_draw * 0.5), r_draw * 1.4, 0.0, TAU, 32, Color(0.55, 0.8, 1.0, 0.7), 3.0)
	if elite:
		var ac: Color = Elites.AFFIXES[affixes[0]]["color"]
		draw_arc(Vector2(0, r_draw * 0.6), r_draw * 1.25, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.8), 2.5)
		draw_arc(Vector2(0, r_draw * 0.6), r_draw * 1.05, 0.0, TAU, 32, Color(ac, 0.6), 2.0)
		var font := ThemeDB.fallback_font
		var ty := -r_draw * 2.0 - 22.0
		draw_string_outline(font, Vector2(-130, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 11, 3, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-130, ty), title, HORIZONTAL_ALIGNMENT_CENTER, 260, 11, Color(1.0, 0.85, 0.35))
	if not statuses.is_empty():
		Status.draw_icons(self, -r_draw * 2.0 - 4.0)
	if stun > 0.0:
		# Зірочки довкола голови
		for i in 3:
			var a := phase * 0.6 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * r_draw * 0.9, -r_draw * 2.0 + sin(a) * 4.0), 3.0, Color(1.0, 0.9, 0.3))
	if hp < max_hp and kind != "zmii":
		var w := r_draw * 2.2
		var y := -r_draw * 2.0 - 14.0
		draw_rect(Rect2(-w / 2, y, w, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 5), Color(0.9, 0.2, 0.2))


func _draw_mavka(side: float) -> void:
	var sway := sin(phase) * 3.0
	# Сукня
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6, -10), Vector2(6, -10), Vector2(15 + sway, 14), Vector2(-15 + sway, 14)
	]), _c(Color(0.85, 0.95, 0.85, 0.9)))
	# Довге зелене волосся
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, -22), Vector2(10, -22), Vector2(9 - side * 4 + sway, 4), Vector2(-9 - side * 4 + sway, 4)
	]), _c(Color(0.2, 0.5, 0.3)))
	draw_circle(Vector2(0, -20), 8.0, _c(color))
	draw_circle(Vector2(side * 3, -21), 1.6, Color(0.1, 0.3, 0.2))
	# Вінок
	for i in 5:
		var a := PI + i * PI / 4.0
		var fc: Color = [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.5, 0.6, 1.0)][i % 3]
		draw_circle(Vector2(0, -22) + Vector2.from_angle(a) * 9.0, 2.6, _c(fc))


func _draw_upyr(side: float) -> void:
	# Темний плащ
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -16), Vector2(14, -16), Vector2(22, 16), Vector2(0, 10), Vector2(-22, 16)
	]), _c(Color(0.15, 0.05, 0.08)))
	draw_circle(Vector2(0, -2), 15.0, _c(color))
	draw_circle(Vector2(side * 4, -24), 11.0, _c(Color(0.75, 0.75, 0.72)))
	draw_circle(Vector2(side * 8, -26), 2.4, Color(1, 0.1, 0.1))
	draw_circle(Vector2(side * 1, -26), 2.4, Color(1, 0.1, 0.1))
	draw_line(Vector2(side * 3, -17), Vector2(side * 3, -13), Color.WHITE, 2.0)
	draw_line(Vector2(side * 7, -17), Vector2(side * 7, -13), Color.WHITE, 2.0)


func _draw_bolotianyk(side: float) -> void:
	var squash := 1.0 + sin(phase * 0.8) * 0.06
	draw_set_transform(Vector2(0, -6), 0.0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, r_draw, _c(color))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Мох і багнюка
	draw_circle(Vector2(-9, -16), 6.0, _c(Color(0.25, 0.38, 0.12)))
	draw_circle(Vector2(8, -18), 5.0, _c(Color(0.42, 0.55, 0.2)))
	draw_line(Vector2(-12, 6), Vector2(-13, 16 + sin(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_line(Vector2(10, 6), Vector2(11, 15 + cos(phase) * 3.0), _c(Color(0.3, 0.4, 0.15)), 3.0)
	draw_circle(Vector2(side * 6 - 4, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 6 + 5, -8), 4.0, Color(1, 0.95, 0.4))
	draw_circle(Vector2(side * 7 - 4, -8), 1.8, Color.BLACK)
	draw_circle(Vector2(side * 7 + 5, -8), 1.8, Color.BLACK)


func _draw_chaklun(side: float) -> void:
	var hover := sin(phase * 0.6) * 3.0 - 4.0
	draw_set_transform(Vector2(0, hover), 0.0, Vector2.ONE)
	# Чорна ряса з червоною облямівкою
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -18), Vector2(10, -18), Vector2(18, 16), Vector2(-18, 16)]), _c(color))
	draw_polyline(PackedVector2Array([Vector2(-18, 16), Vector2(18, 16)]), _c(Color(0.6, 0.05, 0.08)), 3.0)
	draw_line(Vector2(0, -18), Vector2(0, 16), _c(Color(0.6, 0.05, 0.08)), 2.0)
	# Каптур і обличчя
	draw_circle(Vector2(0, -24), 11.0, _c(color.lightened(0.05)))
	draw_circle(Vector2(side * 2, -22), 7.0, _c(Color(0.75, 0.78, 0.72)))
	var glow := 0.6 + 0.4 * sin(phase * 2.5)
	draw_circle(Vector2(side * 2 - 3, -23), 1.8, Color(0.5, 1.0, 0.2, glow))
	draw_circle(Vector2(side * 2 + 3, -23), 1.8, Color(0.5, 1.0, 0.2, glow))
	# Палиця з зеленою кулею
	var hand := Vector2(side * 14, -6)
	draw_line(hand + Vector2(0, 20), hand + Vector2(0, -26), _c(Color(0.3, 0.2, 0.15)), 3.0)
	draw_circle(hand + Vector2(0, -30), 9.0, Color(0.45, 0.95, 0.2, 0.25 * glow))
	draw_circle(hand + Vector2(0, -30), 5.0, Color(0.6, 1.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-side * 10, -36 + sin(phase) * 4.0), 3.0, Color(0.45, 0.95, 0.2, 0.4))


func _draw_chort(side: float) -> void:
	var hop := absf(sin(phase * 1.4)) * 3.0
	var body := Vector2(0, -6 - hop)
	# Хвіст із китицею
	draw_polyline(PackedVector2Array([body + Vector2(-side * 10, 6), body + Vector2(-side * 22, 2), body + Vector2(-side * 26, -10 + sin(phase) * 3)]), _c(color.darkened(0.2)), 3.0)
	draw_circle(body + Vector2(-side * 26, -12 + sin(phase) * 3), 4.0, _c(Color(0.1, 0.05, 0.05)))
	# Ноги з копитцями
	draw_line(body + Vector2(-5, 8), Vector2(-6, 14), _c(color.darkened(0.3)), 4.0)
	draw_line(body + Vector2(5, 8), Vector2(6, 14), _c(color.darkened(0.3)), 4.0)
	draw_rect(Rect2(Vector2(-9, 13), Vector2(6, 3)), _c(Color.BLACK))
	draw_rect(Rect2(Vector2(3, 13), Vector2(6, 3)), _c(Color.BLACK))
	# Тулуб і голова
	draw_circle(body, 12.0, _c(color))
	var h := body + Vector2(side * 3, -14)
	draw_circle(h, 9.0, _c(color.lightened(0.1)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-7, -5), h + Vector2(-11, -16), h + Vector2(-3, -8)]), _c(Color(0.9, 0.85, 0.7)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(7, -5), h + Vector2(11, -16), h + Vector2(3, -8)]), _c(Color(0.9, 0.85, 0.7)))
	draw_circle(h + Vector2(side * 6, 3), 3.5, _c(Color(0.65, 0.3, 0.3)))  # п'ятачок
	draw_circle(h + Vector2(side * 2 - 3, -3), 1.8, Color(1.0, 0.85, 0.1))
	draw_circle(h + Vector2(side * 2 + 3, -3), 1.8, Color(1.0, 0.85, 0.1))


func _draw_koshchii(side: float) -> void:
	var sway := sin(phase * 0.6) * 2.0
	# Чорна мантія
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -20), Vector2(10, -20), Vector2(18 + sway, 16), Vector2(-18 + sway, 16)]), _c(color))
	draw_line(Vector2(-10, -20), Vector2(-18 + sway, 16), _c(Color(0.35, 0.3, 0.1)), 2.0)
	draw_line(Vector2(10, -20), Vector2(18 + sway, 16), _c(Color(0.35, 0.3, 0.1)), 2.0)
	# Кістлява рука з мечем
	var hand := Vector2(side * 13, -8)
	draw_line(Vector2(side * 6, -16), hand, _c(Color(0.9, 0.88, 0.8)), 2.5)
	draw_line(hand, hand + facing * 30.0, _c(Color(0.7, 0.75, 0.8)), 3.0)
	# Череп із зеленим вогнем в очницях
	var h := Vector2(0, -30)
	draw_circle(h, 10.0, _c(Color(0.92, 0.9, 0.82)))
	draw_rect(Rect2(h + Vector2(-5, 6), Vector2(10, 5)), _c(Color(0.92, 0.9, 0.82)))
	var glow := 0.6 + 0.4 * sin(phase * 2.0)
	draw_circle(h + Vector2(-4, -1), 2.8, Color(0.05, 0.05, 0.05))
	draw_circle(h + Vector2(4, -1), 2.8, Color(0.05, 0.05, 0.05))
	draw_circle(h + Vector2(-4, -1), 1.6, Color(0.5, 1.0, 0.3, glow))
	draw_circle(h + Vector2(4, -1), 1.6, Color(0.5, 1.0, 0.3, glow))
	# Зубчаста корона
	for i in 5:
		var x := -8.0 + i * 4.0
		draw_colored_polygon(PackedVector2Array([h + Vector2(x - 2, -8), h + Vector2(x + 2, -8), h + Vector2(x, -15)]), _c(Color(0.85, 0.7, 0.2)))
	if phase2:
		draw_arc(Vector2(0, -10), 30.0, 0.0, TAU, 24, Color(0.6, 1.0, 0.3, 0.5), 2.0)


func _draw_putinoid(side: float) -> void:
	var sway := sin(phase * 0.5) * 1.5
	# Зелена аура зарази
	draw_circle(Vector2(0, -12), 34.0 + sin(phase) * 2.0, Color(0.4, 0.9, 0.15, 0.12 if not phase2 else 0.22))
	# Царська мантія з хутряною облямівкою
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -18), Vector2(12, -18), Vector2(20 + sway, 16), Vector2(-20 + sway, 16)]), _c(color))
	draw_rect(Rect2(Vector2(-21 + sway, 12), Vector2(42, 5)), _c(Color(0.92, 0.9, 0.85)))
	draw_line(Vector2(0, -18), Vector2(0, 12), _c(Color(0.85, 0.65, 0.2)), 2.0)
	# Скіпетр
	var hand := Vector2(side * 15, -6)
	draw_line(hand + Vector2(0, 12), hand + Vector2(0, -22), _c(Color(0.85, 0.65, 0.2)), 3.0)
	draw_circle(hand + Vector2(0, -24), 4.5, Color(0.5, 1.0, 0.2, 0.9))
	# Мертвотно-бліде обличчя, червоні очі
	var h := Vector2(0, -28)
	draw_circle(h, 10.0, _c(Color(0.78, 0.8, 0.76)))
	draw_circle(h + Vector2(-4, -1), 1.8, Color(0.95, 0.05, 0.05))
	draw_circle(h + Vector2(4, -1), 1.8, Color(0.95, 0.05, 0.05))
	draw_line(h + Vector2(-3, 5), h + Vector2(3, 5), Color(0.4, 0.3, 0.3), 1.5)
	# Шапка Мономаха
	draw_colored_polygon(PackedVector2Array([h + Vector2(-10, -6), h + Vector2(10, -6), h + Vector2(7, -16), h + Vector2(0, -20), h + Vector2(-7, -16)]), _c(Color(0.85, 0.65, 0.2)))
	draw_rect(Rect2(h + Vector2(-11, -8), Vector2(22, 4)), _c(Color(0.35, 0.25, 0.2)))
	draw_line(h + Vector2(0, -20), h + Vector2(0, -27), _c(Color(0.85, 0.65, 0.2)), 2.0)
	draw_line(h + Vector2(-3, -24), h + Vector2(3, -24), _c(Color(0.85, 0.65, 0.2)), 2.0)


func _draw_zarazhenyi(side: float, musket: bool = false) -> void:
	var step := sin(phase) * 2.0
	var skin := Color(0.55, 0.62, 0.5)
	# Ноги в чоботях
	draw_rect(Rect2(Vector2(-8, 8 + step), Vector2(6, 10)), _c(Color(0.15, 0.12, 0.1)))
	draw_rect(Rect2(Vector2(2, 8 - step), Vector2(6, 10)), _c(Color(0.15, 0.12, 0.1)))
	# Довгий каптан стрільця
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -16), Vector2(11, -16), Vector2(15, 12), Vector2(-15, 12)]), _c(color))
	draw_line(Vector2(0, -16), Vector2(0, 12), _c(color.darkened(0.4)), 2.0)
	draw_line(Vector2(-13, 2), Vector2(13, 2), _c(Color(0.3, 0.25, 0.1)), 3.0)
	var hand := Vector2(side * 13, -4)
	if musket:
		# Пищаль, наведена на ціль
		draw_line(hand - facing * 10.0, hand + facing * 34.0, _c(Color(0.35, 0.22, 0.1)), 4.0)
		draw_line(hand + facing * 14.0, hand + facing * 36.0, _c(Color(0.55, 0.55, 0.58)), 2.5)
	else:
		# Бердиш
		draw_line(hand + Vector2(0, 16), hand + Vector2(0, -30), _c(Color(0.4, 0.28, 0.15)), 3.0)
		draw_colored_polygon(PackedVector2Array([hand + Vector2(0, -30), hand + Vector2(side * 12, -24), hand + Vector2(side * 10, -8), hand + Vector2(0, -12)]), _c(Color(0.6, 0.62, 0.6)))
	# Голова: сіро-зелена шкіра, чорні жили, світлі очі
	var h := Vector2(0, -24)
	draw_circle(h, 9.0, _c(skin))
	draw_line(h + Vector2(-6, 2), h + Vector2(-2, 8), Color(0.1, 0.15, 0.05), 1.5)
	draw_line(h + Vector2(5, -4), h + Vector2(7, 4), Color(0.1, 0.15, 0.05), 1.5)
	var glow := 0.6 + 0.4 * sin(phase * 2.0)
	draw_circle(h + Vector2(side * 3 - 3, -1), 2.2, Color(0.6, 1.0, 0.2, glow))
	draw_circle(h + Vector2(side * 3 + 3, -1), 2.2, Color(0.6, 1.0, 0.2, glow))
	# Висока шапка
	draw_colored_polygon(PackedVector2Array([h + Vector2(-9, -5), h + Vector2(9, -5), h + Vector2(7, -18), h + Vector2(-7, -18)]), _c(Color(0.35, 0.12, 0.1)))
	draw_rect(Rect2(h + Vector2(-10, -7), Vector2(20, 4)), _c(Color(0.25, 0.2, 0.15)))
	# Зелений сморід зарази
	draw_circle(Vector2(sin(phase * 0.7) * 6.0, -38), 5.0, Color(0.4, 0.8, 0.2, 0.25))


func _draw_vovkulaka(side: float) -> void:
	var run := sin(phase * 1.5) * 3.0
	# Задні лапи та хвіст
	draw_line(Vector2(-6, 8), Vector2(-8, 16 + run), _c(color.darkened(0.3)), 5.0)
	draw_line(Vector2(6, 8), Vector2(8, 16 - run), _c(color.darkened(0.3)), 5.0)
	draw_line(Vector2(-side * 14, 2), Vector2(-side * 26, -6 + run), _c(color.darkened(0.15)), 6.0)
	# Тулуб
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.15, 1.0))
	draw_circle(Vector2.ZERO, 15.0, _c(color))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(0, 2), 9.0, _c(color.lightened(0.25)))
	# Голова з вухами і пащею
	var h := Vector2(side * 10, -20)
	draw_colored_polygon(PackedVector2Array([h + Vector2(-8, -6), h + Vector2(-5, -18), h + Vector2(-1, -7)]), _c(color.darkened(0.2)))
	draw_colored_polygon(PackedVector2Array([h + Vector2(1, -7), h + Vector2(5, -18), h + Vector2(8, -6)]), _c(color.darkened(0.2)))
	draw_circle(h, 10.0, _c(color))
	draw_colored_polygon(PackedVector2Array([h + Vector2(side * 4, -4), h + Vector2(side * 17, 2), h + Vector2(side * 4, 6)]), _c(color.lightened(0.1)))
	draw_circle(h + Vector2(side * 17, 2), 2.2, Color.BLACK)
	draw_circle(h + Vector2(side * 3, -3), 2.2, Color(1, 0.85, 0.1))
	# Пазурі
	draw_line(Vector2(side * 12, 0), Vector2(side * 20, 6), _c(Color(0.9, 0.9, 0.85)), 2.0)


func _draw_zmii() -> void:
	# Крила
	var flap := sin(phase * 0.7) * 10.0
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(s * 30, -20), Vector2(s * 100, -60 - flap), Vector2(s * 90, 0), Vector2(s * 40, 10)
		]), _c(Color(0.15, 0.4, 0.2, 0.9)))
	# Тіло
	draw_circle(Vector2(0, 0), radius, _c(color))
	draw_circle(Vector2(0, 8), radius * 0.6, _c(Color(0.75, 0.7, 0.35)))
	# Три голови на шиях, що тягнуться до козака
	for i in 3:
		var a := facing.angle() + (i - 1) * 0.6
		var sway := sin(phase * 0.5 + i) * 6.0
		var neck_end := Vector2.from_angle(a) * 70.0 + Vector2(0, -30 + sway)
		draw_line(Vector2(0, -20), neck_end, _c(color.darkened(0.15)), 16.0)
		draw_circle(neck_end, 17.0, _c(color.lightened(0.1)))
		var eye := neck_end + Vector2.from_angle(a) * 8.0
		draw_circle(eye + Vector2(0, -5), 3.5, Color(1, 0.85, 0.1))
		draw_circle(eye + Vector2(0, -5), 1.5, Color.BLACK)
	# Смуга здоров'я боса
	var w := 160.0
	draw_rect(Rect2(-w / 2, -radius - 70, w, 9), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, -radius - 70, w * hp / max_hp, 9), Color(0.95, 0.35, 0.1))
