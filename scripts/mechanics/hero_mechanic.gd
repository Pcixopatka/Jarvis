extends RefCounted
## Механіка героя: спільна основа чотирьох родин, з яких складається те, що герой уміє в бою.
##   skill_mechanic.gd   — уміння з власною дією: scripts/mechanics/skill/<id>.gd («mechanic» вузла skills.json);
##   act_mechanic.gd     — шаблон дії вмінь за даними: scripts/mechanics/act/<шаблон>.gd («act.type» вузла);
##   power_mechanic.gd   — сила золотої речі: scripts/mechanics/power/<id>.gd («mechanic» запису powers.json);
##   weapon_mechanic.gd  — вид зброї: scripts/mechanics/weapon/<вид>.gd («mechanic» запису weapons.json).
##
## Як і в нечисті, запис несе назву, число й характеристики, а поведінка — код у файлі, на який запис
## посилається. Рушій (Player) створює об'єкти механік, коли змінюється збірка героя (вивчив уміння,
## вдягнув річ, завантажився), а не щокадру. Об'єкт уміння чи сили, раз створений, живе, доки живе герой:
## його таймери йдуть далі, навіть коли річ зняли (так було й тоді, коли цей стан лежав на самому герої).
##
## Події бою рушій розсилає хуками. Механіка пише лише ті, що їй потрібні; хуків, яких не написала жодна
## механіка героя, рушій не кличе зовсім (порожній перелік, нуль роботи щокадру). Як додати — docs/data.md.

const Loader := preload("res://scripts/mechanics/loader.gd")
const Status := preload("res://scripts/game/status.gd")
const Classes := preload("res://scripts/data/classes.gd")
const HERO_BASE := "res://scripts/mechanics/hero_mechanic.gd"

# ---------- Хуки подій (номер — місце в Player._hooks) ----------
const TICK := 0
const TICK_LATE := 1
const ON_ROLL := 2
const DAMAGE_BONUS := 3
const DAMAGE_DEALT := 4
const ON_HIT := 5
const ABSORB := 6
const DAMAGE_TAKEN := 7
const PARTY_DAMAGE := 8
const SPEED_MULT := 9
const ON_DODGE := 10
const ON_FINISHER := 11
const ON_CAST := 12
const BLOCKS_STATUS := 13
const AGGRO := 14
const ON_REVIVE := 15
const TINT := 16
const DRAW_AURA := 17
const DRAW_HEAD := 18
const OVERLAY := 19
## Хуки, які рушій кличе прямо з механіки своєї родини (не розсилає): біти після хуків подій.
const CAST := 20
const COOLDOWN := 21
const ATTACK := 22
const CHARGED := 23
const FINISHER_HIT := 24
const DAMAGE_MULT := 25
const CD_MULT := 26
const EVENTS := 20  # скільки хуків подій (перелік у Player._hooks)
const HOOKS := {"tick": 1 << TICK, "tick_late": 1 << TICK_LATE, "on_roll": 1 << ON_ROLL, "damage_bonus": 1 << DAMAGE_BONUS,
	"damage_dealt": 1 << DAMAGE_DEALT, "on_hit": 1 << ON_HIT, "absorb": 1 << ABSORB, "damage_taken": 1 << DAMAGE_TAKEN,
	"party_damage": 1 << PARTY_DAMAGE, "speed_mult": 1 << SPEED_MULT, "on_dodge": 1 << ON_DODGE, "on_finisher": 1 << ON_FINISHER,
	"on_cast": 1 << ON_CAST, "blocks_status": 1 << BLOCKS_STATUS, "aggro": 1 << AGGRO, "on_revive": 1 << ON_REVIVE,
	"tint": 1 << TINT, "draw_aura": 1 << DRAW_AURA, "draw_head": 1 << DRAW_HEAD, "overlay": 1 << OVERLAY,
	"cast": 1 << CAST, "cooldown": 1 << COOLDOWN, "attack": 1 << ATTACK, "charged": 1 << CHARGED, "finisher_hit": 1 << FINISHER_HIT,
	"damage_mult": 1 << DAMAGE_MULT, "cd_mult": 1 << CD_MULT}

## Герой, якому належить механіка.
var p: Player
## Сталий номер запису (вузла вміння, сили, зброї): разом з order() задає черговість хуків.
var num := 0
## Біти хуків, які написала механіка (рушій ставить, коли створює об'єкт).
var bits := 0
## Посилання, під яким механіка лежить у героя ("skill/whirl", "act/nova"…).
var ref := ""
## Бій, у якому б'ється герой.
var combat:
	get:
		return p.combat


## Місце в черзі, коли кілька механік героя відгукуються на ту саму подію: менше — раніше (за рівного —
## менший номер запису). Сили золотих речей стоять на 50, уміння — на 100, якщо не кажуть іншого. Черга
## важить там, де множники шкоди йдуть один за одним (так числа виходять ті самі до останнього знаку), де
## кілька механік лікують чи б'ють за один кадр, і де їхні малюнки лягають один на одний.
func order() -> int:
	return 100


# ---------- Хуки подій ----------
# Типові нічого не роблять; рушій кличе лише ті, що механіка (чи її предок нижче за основу родини) написала.

## Щокадру, поки герой живий (Player._tick_effects): таймери, лікування в часі, удари з неба.
func tick(_delta: float) -> void:
	pass


## Щокадру пізніше: після відновлення здоров'я, перед рухом героя (другий удар Буревію).
func tick_late(_delta: float) -> void:
	pass


## Кидок удару (Player._roll), ще до шкоди: r = [множник, крит]. Можна зробити удар критичним і сильнішим.
func on_roll(_r: Array) -> void:
	pass


## Надбавка до шкоди кожного удару, частка (усередині формули кидка, разом із критом і розкидом).
func damage_bonus() -> float:
	return 0.0


## Шкода кидка після станів героя: повертає нову (заряди Звитяги, вовча подоба).
func damage_dealt(dmg: float) -> float:
	return dmg


## Удар героя влучив (Player.hit): e — ціль, dmg — шкода удару, hp_before — здоров'я цілі до удару
## (скільки вона справді втратила — hp_before − e.hp, не менше нуля).
func on_hit(_e, _dmg: float, _crit: bool, _hp_before: float) -> void:
	pass


## Удар по героєві після блоку: скільки шкоди лишилось; від'ємне — удар поглинуто весь (щит).
func absorb(amount: float) -> float:
	return amount


## Шкода по героєві після поглинання, до шипів і броні: повертає нову (Стіна, Покрова, Оберіг загону).
func damage_taken(amount: float) -> float:
	return amount


## Шкода по побратимові загону (Companion.take_damage): повертає нову.
func party_damage(amount: float) -> float:
	return amount


## Множник швидкості бігу щокадру (1.0 — без змін).
func speed_mult() -> float:
	return 1.0


## Герой щойно перекинувся.
func on_dodge() -> void:
	pass


## Завершальний удар серії чи повний заряджений удар зблизька влучив хоч когось.
func on_finisher() -> void:
	pass


## Уміння id щойно спрацювало: наснагу списано, перезарядку поставлено.
func on_cast(_id: String) -> void:
	pass


## Чи стани зараз не чіпляються до героя (і погляд Вія не кам'янить).
func blocks_status() -> bool:
	return false


## Як нечисть бачить героя: 1 — б'є лише його (близьких), −1 — не бачить, 0 — як завжди.
func aggro() -> int:
	return 0


## Героя підняли після смерті: що скинути.
func on_revive() -> void:
	pass


## Колір, яким малюється герой (тінь, вовча подоба): повертає новий.
func tint(c: Color) -> Color:
	return c


## Малюнок довкола героя поверх нього (обереги, кличі): малює на самому герої (p.draw_*).
func draw_aura(_side: float) -> void:
	pass


## Голова героя, коли він малюється без спрайту: head — центр голови, side — куди дивиться.
func draw_head(_head: Vector2, _side: float, _tint: Color) -> void:
	pass


## Накладка поверх спрайту героя (лист Gfx); не порожня ховає шапку.
func overlay() -> String:
	return ""


## Щокадру для зони чи помічника, яких поставила механіка (Combat.spawn_zone, z.mech = self): z — сама зона,
## її z._t (скільки живе) і z._tick (скільки до наступного удару) рушій зони вже посунув.
func zone_tick(_z, _delta: float) -> void:
	pass


## Пастка t, яку поставила механіка (Combat.spawn_trap / spawn_barrel, t.mech = self), спрацювала: e — хто
## потрапив у капкан, null — бочка вибухнула. Прибирає пастку рушій.
func trap_fire(_t, _e) -> void:
	pass


# ---------- Цеглини ----------

## Чи жива нечисть e усередині кола зони z.
static func in_zone(z, e) -> bool:
	return not (e.dead or z.global_position.distance_to(e.global_position) > z.radius + e.radius)


## Кидок удару героя: [шкода, крит].
func roll(mult: float) -> Array:
	return p._roll(mult)


## Удар героя по ворогу (вампіризм, стани, механіки — усе як у звичайного удару).
func hit(e, dmg: float, kb: Vector2, crit: bool) -> void:
	p.hit(e, dmg, kb, crit)


## Жива нечисть бою.
func foes() -> Array:
	return p._alive_enemies()


## Найближча жива нечисть до героя в межах r (чи null).
func nearest(r: float):
	return combat.nearest_enemy(p.global_position, r)


## Напис над героєм.
func say(text: String, color: Color) -> void:
	combat.float_text(p.global_position + Vector2(0, -70), text, color)


## Важкий постріл навиліт (Прицільний постріл, заряджений постріл з пищалі й лука): куля летить швидко,
## пробиває всіх; stun — приголомшує кожного.
func heavy_shot(mult: float, stun: bool) -> bool:
	var target: Node2D = combat.nearest_enemy(p.global_position, 900.0)
	var dir: Vector2 = p.facing
	if target:
		dir = (target.global_position - p.global_position).normalized()
		p.facing = dir
	var r := roll(mult)
	combat.spawn_bullet(p.global_position + Vector2(0, -10) + dir * 34.0, dir, r[0], true)
	var b = combat.last_projectile()
	b.velocity = dir * 1500.0
	b.radius = 9.0
	b.life = 1.2
	b.stun_all = stun
	Audio.play("musket", 0.0, 2.0)
	combat.shake(6.0)
	combat.hitstop(0.04)
	return true


## Шкода для картки: ціле число.
static func dmg_text(v: float) -> String:
	return "%d" % int(v)


## Секунди для картки: ціле без коми, інакше один знак після коми.
static func sec_text(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


# ---------- Завантаження ----------

## Біти хуків, які написав скрипт механіки героя (від основи family_base, не враховуючи її саму).
static func hooks_of(s: Script, family_base: String) -> int:
	return Loader.hooks_of(s, family_base, HOOKS)


## Порожній перелік механік для кожного хука подій (Player._hooks).
static func empty_hooks() -> Array:
	var out := []
	for i in EVENTS:
		out.append([])
	return out
