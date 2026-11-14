extends Node2D
## Здобич на землі: гривня (досвід і гроші), вареник (лікування), зілля, зілля наснаги, ресурс, жетон свята
## або річ спорядження. Непідібране за LIFE секунд бою зникає (крім разових нагород і цінних речей); останні
## BLINK секунд блимає.

const GameDB := preload("res://scripts/core/game_db.gd")
const Data := preload("res://scripts/data/data.gd")
const Camp := preload("res://scripts/data/camp_data.gd")
const Gfx := preload("res://scripts/world/gfx.gd")

var combat: Combat
var kind := "coin"  # "coin", "varenyk", "potion", "mana", "res", "token" або "item"
var item := {}
var value := 1
var phase := randf() * TAU
var pull_speed := 0.0
var spawn_vel := Vector2.ZERO
var keep := false  # разова нагорода (бос дня, перше проходження): за повну торбу лягає понад місце, не зникає
var manual := false  # викинута з торби річ: сама до героя не летить, підбирається лише впритул
var hold := 0.0  # скільки секунд викинуту річ ще не можна підібрати
var life := 0.0  # скільки секунд бою лежить, поки не зникне (0 — не зникає); ставить Combat при появі
var age := 0.0  # скільки секунд бою вже лежить
static var LIFE: float  # секунд лежить на землі непідібрана здобич
static var PREMIUM_MULT: float  # з універсалом лежить у стільки разів довше
static var BLINK: float  # останні стільки секунд блимає


## Числа-правила вище лежать у data/settings.json (запис «loot»; docs/data.md, «Налаштування балансу»):
## тут їхні робочі копії. Їх заповнює apply_settings(), щойно скрипт завантажено.
static func _static_init() -> void:
	apply_settings()


## Бере числа з налаштувань (GameDB.settings). GameDB.apply_settings() кличе це знову, коли налаштування
## змінено під час гри.
static func apply_settings() -> void:
	var S := GameDB.settings("loot")
	LIFE = S["ground_life"]
	PREMIUM_MULT = S["ground_premium_mult"]
	BLINK = S["ground_blink"]


## Скільки секунд лежатиме нова здобич: з універсалом довше. Разова нагорода (keep) не зникає: 0.
static func life_for(premium: bool, keep_: bool = false) -> float:
	if keep_:
		return 0.0
	return LIFE * (PREMIUM_MULT if premium else 1.0)


## Скільки секунд лежатиме нова здобич виду kind: цінна річ (Data.is_precious: золота, з набору, артефакт)
## не зникає, як і разова нагорода; решта — як у life_for.
static func life_of(premium: bool, kind_: String, item_: Dictionary, keep_: bool = false) -> float:
	if kind_ == "item" and Data.is_precious(item_):
		return 0.0
	return life_for(premium, keep_)


## Скоро зникне: останні BLINK секунд блимає.
func fading() -> bool:
	return life > 0.0 and age >= life - BLINK


func _process(delta: float) -> void:
	phase += delta * 4.0
	position += spawn_vel * delta
	spawn_vel = spawn_vel.move_toward(Vector2.ZERO, 600.0 * delta)
	if spawn_vel != Vector2.ZERO:
		position = combat._clamp_in(position, 24.0)  # здобич не вилітає за край арени, куди героєві не дійти
	var p = combat.player
	if not p.alive:
		queue_redraw()
		return
	# час на землі йде, лише поки йде бій: у паузі й на екранах поверх бою _process не кличеться,
	# а поки герой лежить мертвий, вихід вище
	if life > 0.0:
		age += delta
		if age >= life:
			queue_free()  # ніхто не підібрав: пропадає, нічого не дає
			return
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	hold = maxf(0.0, hold - delta)
	var block := _block(p)
	var a := 0.45 if block == "filter" else 1.0  # річ, яку фільтр не бере, лежить тьмяна
	modulate.a = _blink(a) if life > 0.0 and age >= life - BLINK else a  # те саме, що fading()
	if block != "":
		# нема куди покласти або фільтр не бере: здобич лежить далі (поки не скінчиться її час)
		pull_speed = 0.0
		if block == "full" and kind == "item" and dist < 70.0:
			combat.note_bag_full()
		queue_redraw()
		return
	if manual:
		if hold > 0.0 or dist > 30.0:
			queue_redraw()
			return
	elif dist < p.pickup_radius:
		pull_speed = minf(pull_speed + 1600.0 * delta, 900.0)
		position += to.normalized() * minf(pull_speed * delta, dist)
	if dist < (30.0 if manual else 22.0):
		combat.take_loot(kind, value, item, global_position)  # те саме робить Хованець одразу з нечисті
		queue_free()
		return
	queue_redraw()


## Блимання перед зникненням: світла фаза — звична яскравість, темна — майже прозоро (тож видно й на
## тьмяній речі), під кінець частіше, а останні півсекунди тане.
func _blink(a: float) -> float:
	var left := life - age
	var per := 0.3 if left < 3.0 else 0.6
	var out := a if fmod(left, per) > per * 0.45 else a * 0.15
	return out * clampf(left / 0.5, 0.0, 1.0)


## Чому це не підбирається: "" — підбирається, "full" — нема куди покласти (повна торба чи повний
## запас зілля), "filter" — фільтр автопідбору не бере речі такої рідкості.
func _block(_p) -> String:
	return combat.loot_block(kind, item, manual)


func _wanted(p) -> bool:
	return _block(p) == ""


func _draw() -> void:
	var hover := sin(phase) * 3.0
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2(0, hover - 4), 0.0, Vector2.ONE)
	if Gfx.has("icons"):
		_draw_icon()
		return
	if kind == "item":
		var col: Color = Data.item_color(item)
		draw_circle(Vector2.ZERO, 20.0 + sin(phase * 2.0) * 3.0, Color(col, 0.25))
		# Вузлик зі здобиччю
		draw_circle(Vector2(0, 2), 11.0, Color(0.55, 0.38, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(0, -2)]), Color(0.45, 0.3, 0.15))
		draw_line(Vector2(-7, -6), Vector2(7, -6), col, 3.0)
		draw_circle(Vector2(6, -10), 2.5, Color(1, 1, 0.9))
		return
	if kind == "res":
		var col: Color = Camp.res_color(item["res"])
		match item["res"]:
			"wood":
				draw_rect(Rect2(-10, -4, 20, 8), col)
				draw_circle(Vector2(10, 0), 4.0, col.lightened(0.3))
			"iron":
				draw_colored_polygon(PackedVector2Array([Vector2(-9, 4), Vector2(-5, -5), Vector2(9, -5), Vector2(5, 4)]), col)
				draw_line(Vector2(-5, -5), Vector2(9, -5), col.lightened(0.4), 2.0)
			_:
				for i in 3:
					draw_line(Vector2(-4 + i * 4, 6), Vector2(-6 + i * 6, -8), col, 3.0)
				draw_circle(Vector2(0, -8), 3.0, Color(0.95, 0.85, 0.3))
		return
	if kind == "potion":
		# Пляшечка з червоним зіллям
		draw_circle(Vector2(0, 2), 9.0, Color(0.85, 0.12, 0.15))
		draw_circle(Vector2(-3, -1), 3.0, Color(1, 0.6, 0.6, 0.8))
		draw_rect(Rect2(-3, -12, 6, 6), Color(0.75, 0.8, 0.85))
		draw_rect(Rect2(-4, -15, 8, 3), Color(0.5, 0.3, 0.15))
		return
	if kind == "coin":
		var r := 6.0 + minf(value, 20) * 0.35
		draw_circle(Vector2.ZERO, r, Color(0.95, 0.75, 0.15))
		draw_circle(Vector2.ZERO, r * 0.65, Color(1.0, 0.88, 0.35))
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 0.9))
	else:
		# Вареник: півмісяць із защипами
		var pts := PackedVector2Array()
		for i in 13:
			pts.append(Vector2.from_angle(PI + i * PI / 12.0) * 13.0)
		draw_colored_polygon(pts, Color(0.98, 0.93, 0.8))
		for i in 7:
			draw_circle(Vector2.from_angle(PI + i * PI / 6.0) * 13.0, 2.5, Color(0.92, 0.85, 0.7))
		draw_line(Vector2(-13, 0), Vector2(13, 0), Color(0.85, 0.78, 0.62), 2.0)


## Нова графіка: значки з атласу замість малюнків кодом.
func _draw_icon() -> void:
	match kind:
		"item":
			var col: Color = Data.item_color(item)
			draw_circle(Vector2.ZERO, 20.0 + sin(phase * 2.0) * 3.0, Color(col, 0.25))
			Gfx.icon(self, "chest", Vector2(0, -2), 2.0)
			draw_circle(Vector2(10, -12), 3.0, col)
		"res":
			Gfx.icon(self, item["res"], Vector2(0, -2), 2.0)
		"potion":
			Gfx.icon(self, "potion", Vector2(0, -2), 2.0)
		"mana":
			Gfx.icon(self, "mana", Vector2(0, -2), 2.0)
		"token":
			draw_circle(Vector2.ZERO, 17.0 + sin(phase * 2.5) * 2.5, Color(1.0, 0.85, 0.4, 0.28))
			Gfx.icon(self, str(item.get("icon", "glory")), Vector2(0, -2), 2.0)
		"coin":
			Gfx.icon(self, "coin" if value >= 8 else "coin_small", Vector2.ZERO, 1.5 + minf(value, 20) * 0.03)
		_:
			Gfx.icon(self, "varenyk", Vector2(0, -2), 2.0)
