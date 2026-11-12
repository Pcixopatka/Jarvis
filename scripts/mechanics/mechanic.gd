extends RefCounted
## Механіка нечисті: як один вид поводиться в бою — прийоми боса, особливий прийом звичайної
## нечисті, власна стрільба, ривки, бенкет, погляд Вія...
##
## Так влаштовано сервери онлайн-ігор: сила, ім'я й номер лежать у базі (data/mobs.json), запис
## лише називає свій скрипт («mechanic»: "boss/koshchii"), а поведінка — код у цьому скрипті.
## Кожен вид має свій файл: scripts/mechanics/boss/<вид>.gd — бос, scripts/mechanics/mob/<вид>.gd —
## звичайна форма. Спільні частини кількох босів (бенкет, хуртовина, каміння) — у parts/.
##
## Рушій (Enemy) створює один об'єкт механіки на кожну нечисть у setup і кличе його хуки. Типовий хук
## нічого не робить, тож механіка пише лише ті, що їй потрібні; хуків, яких механіка не написала,
## рушій навіть не кличе. Нечисть без механіки (mechanic == null) не платить за це нічого.
## Як додати боса чи прийом — docs/data.md.

const Status := preload("res://scripts/game/status.gd")
const DIR := "res://scripts/mechanics/"
const BASE_PATH := DIR + "mechanic.gd"

## Хуки, які рушій кличе лише тоді, коли механіка їх написала (біт на кожен).
const SETUP := 1
const TICK := 2
const CHASE := 4
const ABILITY := 8
const VOLLEY := 16
const PHASE2 := 32
const ON_HIT := 64
const ON_DAMAGE := 128
const ON_LETHAL := 256
const ON_DEATH := 512
const HOOKS := {"setup": SETUP, "tick": TICK, "chase": CHASE, "ability": ABILITY, "volley": VOLLEY, "phase2": PHASE2,
	"on_hit": ON_HIT, "on_damage": ON_DAMAGE, "on_lethal": ON_LETHAL, "on_death": ON_DEATH}

## Нечисть, якою керує механіка (Enemy).
var e
## Бій, у якому вона б'ється.
var combat:
	get:
		return e.combat


# ---------- Хуки ----------

## Вид щойно отримав свої числа (Enemy.setup): рівень і множники боса вже враховано, типові таймери
## боса ще ні. Тут — особливі числа виду.
func setup() -> void:
	pass


## Щокадру, поки нечисть жива, ще до того, як рушій перевірить приголомшення (бенкет, хуртовина,
## погляд, каміння зі стелі, власні таймери).
func tick(_delta: float) -> void:
	pass


## Щокадру, коли нечисть не приголомшена й має ціль: target — ціль, dist — відстань до неї,
## dir — напрямок на неї (ривки, телепорти).
func chase(_target, _dist: float, _dir: Vector2, _delta: float) -> void:
	pass


## Прийом, коли спливе e.ability_timer. Бос: чергове коло обертання (e.ability_step уже збільшено).
## Звичайна нечисть: її особливий прийом (лише не мара й не посеред замаху); перший — через 2–4,5 с.
## Прийом сам ставить e.ability_timer до наступного.
func ability(_target, _dist: float) -> void:
	pass


## Постріл, коли спливе e.shoot_timer (лише для того, хто стріляє, і ціль ближче за 750).
func volley(dir: Vector2) -> void:
	e._default_volley(dir)


## Бос лютішає на половині здоров'я (у записі «boss.phase2»). Спільне — швидкість, частіші постріли
## й прийоми, струс і рев — рушій уже зробив; тут гасло й підмога.
func phase2() -> void:
	e._default_phase2()


## Удар нечисті влучив і поранив ціль (до станів і властивостей еліти).
func on_hit(_target) -> void:
	pass


## Нечисть отримує удар: amount — шкода після всіх множників, ще до того, як здоров'я зменшиться.
func on_damage(_amount: float) -> void:
	pass


## Удар мав би вбити. true — нечисть не вмирає (здоров'я механіка ставить сама).
func on_lethal() -> bool:
	return false


## Нечисть загинула (до властивостей еліти «чума» й «вибухова»).
func on_death() -> void:
	pass


# ---------- Будівельні цеглини ----------

## Ціла й жива: для дій, що спрацьовують згодом (наприклад, коли вдарить попередження).
func alive() -> bool:
	return is_instance_valid(e) and not e.dead


## Напрямок від нечисті на ціль.
func dir_to(target) -> Vector2:
	return (target.global_position - e.global_position).normalized()


## Попередження на землі, яке за dur секунд б'є всіх усередині (див. Telegraph).
func telegraph(shape: String, pos: Vector2, dur: float, dmg: float):
	return e._telegraph(shape, pos, dur, dmg)


## Кличе count нечисті з kinds довкола себе.
func summon(kinds: Array, count: int) -> void:
	e._summon(kinds, count)


## Кличе нечисть, що не дає ні досвіду, ні душі (надважкі боси).
func summon_free(kinds: Array, count: int) -> void:
	e._summon_free(kinds, count)


## Снаряд нечисті.
func shoot(pos: Vector2, dir: Vector2, spd: float, dmg: float, col: Color, r: float) -> void:
	e._shoot(pos, dir, spd, dmg, col, r)


## Гасло люті й підмога з трьох (для phase2).
func rage(text: String, kinds: Array) -> void:
	Events.banner.emit(text, Color(1.0, 0.4, 0.3))
	e._summon(kinds, 3)


## Мари (Відьма, Біла Пані, Велняс): бос зникає в диму й з'являється деінде, а поруч постають дві
## мари — з виду такі самі, лише трохи прозоріші. Мара розсипається від першого ж удару.
func cast_illusions(target) -> void:
	Audio.play("portal", 0.1, -2.0)
	combat.fx.burst(e.global_position, Color(0.6, 0.3, 0.9), 30, 260, 8, 0.6)
	var spots := []
	for i in 3:
		var best: Vector2 = e.global_position
		for attempt in 8:
			var cand := Vector2(randf_range(combat.arena.position.x + 140, combat.arena.end.x - 140), randf_range(combat.arena.position.y + 140, combat.arena.end.y - 140))
			var ok: bool = cand.distance_to(target.global_position) > 240.0
			for s in spots:
				ok = ok and cand.distance_to(s) > 200.0
			if ok:
				best = cand
				break
		spots.append(best)
	e.global_position = spots[0]
	combat.fx.burst(e.global_position, Color(0.6, 0.3, 0.9), 24, 240, 8, 0.5)
	for i in range(1, 3):
		combat.spawn_enemy(e.kind, e.level, false, spots[i])
		var m = combat._last_enemy()
		if m != null and m != e:
			m.make_illusion(e)
			combat.fx.burst(spots[i], Color(0.6, 0.3, 0.9), 24, 240, 8, 0.5)


# ---------- Завантаження (рушій і перевірка бази) ----------

static var _scripts := {}  # посилання → скрипт механіки (null — нема такого файлу)
static var _hooks := {}  # скрипт → біти хуків, які він написав


## Шлях до файлу механіки за посиланням із запису ("boss/koshchii" → res://scripts/mechanics/boss/koshchii.gd).
static func path_of(ref: String) -> String:
	return DIR + ref + ".gd"


## Скрипт механіки за посиланням; вантажиться раз на всю гру. Шлях до .gd працює й у збірці для
## телефона: там скрипти лежать як .gdc, і Godot сам іде за переадресуванням (.remap). Тому теки
## ніколи не переглядаємо під час гри — лише вантажимо за посиланням із запису.
static func script_of(ref: String) -> Script:
	if not _scripts.has(ref):
		var s: Script = null
		if ref != "" and ResourceLoader.exists(path_of(ref)):
			s = load(path_of(ref)) as Script
		if s != null and not extends_base(s):
			s = null
		_scripts[ref] = s
	return _scripts[ref]


## Чи скрипт — механіка (його ланцюг предків доходить до цього файлу).
static func extends_base(s: Script) -> bool:
	while s != null:
		if s.resource_path == BASE_PATH:
			return true
		s = s.get_base_script()
	return false


## Біти хуків, які написав скрипт механіки чи його предки (крім самої основи).
static func hooks_of(s: Script) -> int:
	if s == null:
		return 0
	if not _hooks.has(s):
		var bits := 0
		var cur := s
		while cur != null and cur.resource_path != BASE_PATH:
			# Перелік методів скрипту: спершу власні, далі всіх предків
			var own: Array = cur.get_script_method_list()
			var base := cur.get_base_script()
			var n_base: int = base.get_script_method_list().size() if base != null else 0
			for i in own.size() - n_base:
				bits |= int(HOOKS.get(own[i]["name"], 0))
			cur = base
		_hooks[s] = bits
	return _hooks[s]


## Чи механіка за посиланням пише хук (наприклад, "ability").
static func has_hook(ref: String, hook: String) -> bool:
	return hooks_of(script_of(ref)) & int(HOOKS.get(hook, 0)) != 0


## Нова механіка для нечисті; null — посилання нікуди не веде (тоді нечисть б'ється без неї).
static func create(ref: String, enemy):
	var s := script_of(ref)
	if s == null:
		push_error("Механіка «%s» не знайдена (%s)" % [ref, path_of(ref)])
		return null
	var m = s.new()
	m.e = enemy
	return m
