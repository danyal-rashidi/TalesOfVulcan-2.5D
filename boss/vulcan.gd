class_name Vulcan extends Actor
# The possessed Vulcan. A kneeling stone statue until C1 runs wake_scripted(); then, once start_fight() gives him a target, he picks
# a move (VulcanBrain), walks up to its range, turns to face, winds up while a dim mark on the floor shows where it lands, strikes and
# stands open. Light blows wear his poise down until he flinches. At half health the crown flares, he roars and is faster (phase two).
# At 0 hp he never dies: he kneels, nothing of his hurts any more, and a heavy blow strikes the crown.
# Numbers are the Unreal boss's (D:\TalesOfVulkan\TalesOfVulkan\Source\TalesOfVulkan\BossVulcan.h unless another file is named), cm into m.

signal woke
signal phase_two
signal knelt
signal crown_struck

enum Mode {STATUE, IDLE, PACE, WINDUP, ACTIVE, RECOVER, FLINCH, ROAR, KNEEL}

const BLADE := preload("res://fx/fire_blade.gd")
const BREATH := preload("res://fx/breath.gd")
const DIVE := preload("res://fx/dive_impact.gd")
const CIRCLE := preload("res://fx/spell_circle.gd")

const POISE_MAX := 100.0        # MaxPoise
const POISE_ARMOURED := 0.5     # PoiseArmouredScale: in his wind-ups and blows a blow costs half the poise and can't break it
const POISE_DELAY := 4.0        # PoiseRegenDelay: seconds after the last blow before his poise comes back
const POISE_REGEN := 25.0       # PoiseRegen, per second
const FLINCH_TIME := 0.75       # FlinchSeconds
const FLINCH_RECOVER := 0.3     # FlinchRecover: then he may attack again
const PHASE_TWO_AT := 0.5       # PhaseTwoAt
const PHASE_TWO_PAUSE := 0.6    # PhaseTwoPause: his pauses between attacks shrink to this
const PHASE_TWO_DAMAGE := 1.15  # PhaseTwoDamage
const ROAR_TIME := 2.0          # Claude's call: Unreal's phase shift (3.8 s) is a kneel, a struggle and a rise; this is only the roar
const APPROACH_SPEED := 5.8     # ApproachSpeed 580 cm/s: walking up to a move's range
const PACE_SPEED := 5.28        # PaceSpeed 330 cm/s x1.6: in his pause he walks up only while the target keeps beyond PACE_DISTANCE x1.5 (TickPace)
const PACE_DISTANCE := 6.5      # PaceDistance 650 cm
const RUN_FROM := 4.5           # RunThreshold 450 cm/s: faster than this he runs, slower he walks
const TURN_RATE := 200.0        # TurnRate, deg/s, outside his wind-ups
const FACE_TO_START := 20.0     # deg: he starts an attack once he faces the target this closely (TickPace)
const PAUSE := Vector2(0.5, 1.2)    # PauseMin, PauseMax: seconds between attacks
const CHAIN_PAUSE := 0.04       # the backswing comes this soon after the slash (FinishAttack)
const AFTER_WAKE := 0.8         # his first attack waits this long (TickWaking)
const SPELL_FIRST := 0.2        # the first fireball this long into the volley, then one every SPELL_GAP (TickSpell)
const SPELL_GAP := 0.3          # SpellGap
const SPELL_BALLS := 4          # SpellBalls
const SPELL_SPREAD := 3.0       # SpellSpread, deg
const SPELL_BEHIND := 1.15      # SpellCircleBehind 115 cm: the circle's centre behind him
const SPELL_HEIGHT := 1.2       # Claude's call: the fireballs fly at chest height, clear of the plinth's top (Unreal's leave the upright circle)
const DIVE_HEIGHT := 2.4        # DiveHeight 240 cm: the leap's top
const DIVE_MARK_SPEED := 5.5    # DiveMarkSpeed 550 cm/s: the landing mark follows the target only this fast until he commits
const BLADE_FROM := 0.8         # StripStart 80 cm: the slam's fire starts this far ahead of him
const MOUTH := 0.45             # Claude's call: the breath starts this far ahead of him
const CHARGE_SPEED := 10.0      # Claude's call: 7 m in the charge's 0.7 s
const REACH := 1.3              # his middle to his sword's hit sphere (radius 1 m): the slash's StartRange 230 cm
const HEAD := 3.5               # m up: the crown, 74 px up his 80 px sprite (Arena.FACE_TPM px per metre of height)
const HAND := 3.9               # m up: his raised hand, where the flame forms the sword
const RISE_TIME := 1.25         # the wake: he rises (RiseFrom 1.0 s of the clip at RiseRate 0.8)
const RAISE_TIME := 0.55        # the empty right hand goes up (SummonRaiseSeconds, BossVulcan.cpp)
const FORGE_TIME := 1.0         # the flame holds, then forms the sword (SummonHoldSeconds 0.4 + SummonForgeSeconds 0.6)
const HOP_TIME := 0.45          # he steps down off the plinth (SummonRiseGap 0.45 s)
const FAST := 0.05              # fast mode: the wake's waits shrink to this (the plan's C1)

@export var max_hp := 600.0     # BossHealth

var awake := false
var armed := false
var phase := 1
var kneeling := false
var arena: Arena
var target: Node3D
var brain := VulcanBrain.new()
var fast := false               # the wake's waits x FAST; ShotDriver.fast unless a game or test sets it
var mode: Mode = Mode.STATUE    # for a bot: WINDUP while a blow is coming
var move := &""                 # the attack he is in, or &""

@onready var hitbox: Hitbox = $Hitbox

var _t := 0.0           # seconds in the mode; in an attack, phase one's seconds (sped up in phase two)
var _wait := 0.0        # his pause before the next attack
var _next := &""        # the attack chosen, not yet begun
var _poise := POISE_MAX
var _calm := 0.0        # seconds since the last blow
var _struck := false
var _window := Vector2i(-1, -1)
var _mark: FxTelegraph
var _held: FxEffect     # the breath, ended with the blow
var _shots := 0
var _from := Vector3.ZERO
var _to := Vector3.ZERO     # the dive's landing
var _hop: Tween

func _ready() -> void:
	super()
	fast = ShotDriver.fast
	health.max_hp = max_hp
	health.reset()
	health.changed.connect(_on_health)
	health.died.connect(_kneel)
	hitbox.landed.connect(_on_landed)
	sprite.set_tint(Color(1.0, 0.45, 0.3))    # lava red, so the stand-in (the old human Vulcan sheet) never reads as the unmasked man
	sprite.load_character("vulcan_boss")
	set_statue(true)

# The kneeling stone statue, asleep and unarmed; the `statue` sheet, or whatever he falls back to turned to stone.
func set_statue(on: bool) -> void:
	_abort()
	awake = not on
	armed = not on
	hurtbox.invulnerable = on
	mode = Mode.STATUE if on else Mode.IDLE
	sprite.restart("statue" if on else "idle", facing)
	sprite.set_param(&"stone", 1.0 if on and not sprite.current_key.begins_with("statue") else 0.0)

# C1 awaits it: the stone breaks off, he rises, raises his empty hand, the flame forms the sword (armed), and he steps down off the plinth.
func wake_scripted() -> void:
	var k := FAST if fast else 1.0
	scripted = true
	awake = true
	mode = Mode.IDLE
	sprite.set_param(&"stone", 0.0)
	sprite.play_timed("wake", facing, (RISE_TIME + RAISE_TIME + FORGE_TIME) * k)
	woke.emit()
	await get_tree().create_timer((RISE_TIME + RAISE_TIME) * k, false).timeout
	Fx.spawn(&"flame_summon", global_position + Vector3.UP * HAND)
	await get_tree().create_timer(FORGE_TIME * k, false).timeout
	armed = true
	var down := _floor(global_position)
	if not down.is_equal_approx(global_position):
		_hop = create_tween()
		_hop.tween_method(_hop_at.bind(global_position, down), 0.0, 1.0, HOP_TIME * k)
		await _hop.finished
		global_position = down
		Fx.spawn(&"dust", down)
		Feel.shake(2.0, 0.15)
	hurtbox.invulnerable = false
	scripted = false
	sprite.restart("idle", facing)

func start_fight(t: Node3D) -> void:
	target = t
	_next = &""
	_pace(AFTER_WAKE)

# After Elvis dies: as he was when the fight began, awake and armed, standing at `at` (or the floor beside it, off the plinth).
func reset_fight(at: Vector3) -> void:
	_abort()
	if _hop:
		_hop.kill()
	scripted = false
	global_position = _floor(at)
	velocity = Vector3.ZERO
	phase = 1
	brain.reset()
	health.reset()
	sprite.speed_scale = 1.0
	kneeling = false
	_struck = false
	awake = true
	armed = true
	_poise = POISE_MAX
	_calm = 0.0
	hurtbox.invulnerable = false
	if sprite.character != "vulcan_boss":
		sprite.load_character("vulcan_boss")
	for p: StringName in [&"stone", &"burn", &"cool"]:
		sprite.set_param(p, 0.0)
	facing = Vector2.DOWN
	_next = &""
	_pace(AFTER_WAKE)
	sprite.restart("idle", facing)

func take_hit(info: HitInfo) -> void:
	if kneeling:
		if not info.heavy:
			Fx.spawn(&"sparks", info.at)
		elif not _struck:
			_struck = true
			crown_struck.emit()
		return
	if not awake or mode == Mode.ROAR:
		return
	health.take(info.damage)    # no knockback: Unreal's boss takes none
	sprite.flash(0.08)
	_calm = 0.0
	if kneeling or mode == Mode.ROAR:    # this blow did it
		return
	var armoured := mode == Mode.WINDUP or mode == Mode.ACTIVE
	_poise -= info.poise * (POISE_ARMOURED if armoured else 1.0)
	if _poise <= 0.0:
		if armoured:
			_poise = 1.0    # a sliver is left: the first blow after his swing breaks it (ApplyDamage)
		else:
			_flinch()

func _tick(delta: float) -> void:
	_calm += delta
	if _calm >= POISE_DELAY:
		_poise = minf(POISE_MAX, _poise + POISE_REGEN * delta)
	var v := Vector2.ZERO
	match mode:
		Mode.IDLE:
			sprite.play("idle", facing)
		Mode.PACE:
			v = _tick_pace(delta)
		Mode.WINDUP, Mode.ACTIVE, Mode.RECOVER:
			v = _tick_attack(delta * brain.speed_scale(), delta)
		Mode.FLINCH:
			_t += delta
			if _t >= FLINCH_TIME:
				_pace(FLINCH_RECOVER)
		Mode.ROAR:
			_t += delta
			if _t >= ROAR_TIME:
				hurtbox.invulnerable = false
				_pace(0.2)    # EndPhaseShift
	_slide(Pixel.ground(v), delta)

# His pause, then the chosen attack's range, facing the target. Returns his ground velocity.
func _tick_pace(delta: float) -> Vector2:
	if not is_instance_valid(target):
		mode = Mode.IDLE
		return Vector2.ZERO
	var to := _offset()
	var dist := to.length()
	var s := brain.speed_scale()
	var off := _turn(to, TURN_RATE, delta)
	var v := Vector2.ZERO
	_wait -= delta
	if _wait > 0.0:
		if dist > PACE_DISTANCE * 1.5:
			v = to.normalized() * PACE_SPEED * s
	else:
		if _next == &"":
			_next = brain.next_move(dist)
		if dist > float(VulcanMoves.MOVES[_next]["range"]):
			v = to.normalized() * APPROACH_SPEED * s
		elif off < FACE_TO_START:
			_begin(_next)
			return Vector2.ZERO
	var speed := v.length()
	sprite.play("run" if speed >= RUN_FROM * s else ("walk" if speed > 0.0 else "idle"), facing)
	return v

func _begin(m_name: StringName) -> void:
	var m: Dictionary = VulcanMoves.MOVES[m_name]
	_next = &""
	move = m_name
	mode = Mode.WINDUP
	_t = 0.0
	_shots = 0
	sprite.play_timed(m["anim"], facing, (float(m["windup"]) + float(m["active"]) + float(m["recover"])) / brain.speed_scale())
	_window = sprite.active_window(sprite.current_key)
	var windup := float(m["windup"]) / brain.speed_scale()
	match m_name:
		&"slam":
			_telegraph(0, BLADE.LENGTH, BLADE.HALF_WIDTH, windup)
		&"breath":
			_telegraph(1, BREATH.LENGTH, deg_to_rad(BREATH.HALF_ANGLE), windup)
		&"charge":
			_telegraph(0, CHARGE_SPEED * float(m["active"]), 0.5, windup)
		&"dive":
			_to = _floor(target.global_position) if is_instance_valid(target) else global_position
			_telegraph(2, DIVE.RADIUS, 0.15, windup)
		&"spell":
			var circle := Fx.spawn(&"spell_circle", global_position - _f3() * SPELL_BEHIND) as FxEffect
			circle.life = windup + float(m["active"]) / brain.speed_scale()    # it lasts the volley, then fades
	_place_mark()

# The wind-up (turning after the target until he commits), the blow, the recovery. dt is attack time; returns his ground velocity.
func _tick_attack(dt: float, delta: float) -> Vector2:
	var m: Dictionary = VulcanMoves.MOVES[move]
	_t += dt
	match mode:
		Mode.WINDUP:
			if _t < float(m["commit"]) and is_instance_valid(target):
				_turn(_offset(), float(m["turn"]), delta)
				if move == &"dive":
					_to = _to.move_toward(_floor(target.global_position), DIVE_MARK_SPEED * delta)
				_place_mark()
			var strike := _t >= float(m["windup"])
			if _window.x >= 0:    # the sheet names its hit frames: they win over the fixed time
				strike = sprite.frame >= _window.x
			if strike:
				_strike(m)
		Mode.ACTIVE:
			var v := _tick_blow(m)
			if _t >= float(m["active"]):
				_end_blow(m)
			return v
		Mode.RECOVER:
			if _t >= float(m["recover"]):
				_finish()
	return Vector2.ZERO

func _strike(m: Dictionary) -> void:
	mode = Mode.ACTIVE
	_t = 0.0
	if is_instance_valid(_mark):
		_mark.end()
	var f := _f3()
	var at := global_position
	match move:
		&"slam":
			_listen(Fx.spawn(&"fire_blade", at + f * BLADE_FROM, f, Hitbox.TEAM_BOSS, _blow(m)))
			_crack(at + f * 1.6, 1.2)
			Feel.shake(2.0, 0.15)
		&"breath":
			_held = Fx.spawn(&"breath", at + f * MOUTH, f, Hitbox.TEAM_BOSS, _blow(m)) as FxEffect
			_listen(_held)
		&"dive":
			_from = at
		&"charge", &"slash", &"backswing":
			hitbox.position = f * (0.7 if move == &"charge" else REACH) + Vector3.UP
			hitbox.activate(_blow(m), 10.0)    # _end_blow ends it

func _tick_blow(m: Dictionary) -> Vector2:
	match move:
		&"spell":
			while _shots < SPELL_BALLS and _t >= SPELL_FIRST + _shots * SPELL_GAP:
				_shoot(m)
				_shots += 1
		&"dive":
			var x := clampf(_t / float(m["active"]), 0.0, 1.0)
			global_position = _from.lerp(_to, x) + Vector3.UP * DIVE_HEIGHT * 4.0 * x * (1.0 - x)
		&"charge":
			return facing * CHARGE_SPEED * brain.speed_scale()
	return Vector2.ZERO

func _end_blow(m: Dictionary) -> void:
	mode = Mode.RECOVER
	_t = 0.0
	hitbox.deactivate()
	if is_instance_valid(_held):
		_held.end()
	match move:
		&"dive":
			global_position = _to
			_listen(Fx.spawn(&"dive_impact", _to, Vector3.ZERO, Hitbox.TEAM_BOSS, _blow(m)))
			_crack(_to, 2.0)
			Feel.shake(3.0, 0.25)
		&"slash", &"backswing":
			_crack(global_position + _f3() * 2.0, 0.7)    # the sword's point strikes the floor

# The attack is over: the next is chosen now, so a backswing can follow the slash at once (FinishAttack).
func _finish() -> void:
	move = &""
	_next = brain.next_move(_offset().length()) if is_instance_valid(target) else &""
	_pace(CHAIN_PAUSE if _next == &"backswing" else randf_range(PAUSE.x, PAUSE.y) * (PHASE_TWO_PAUSE if phase == 2 else 1.0))

func _pace(wait: float) -> void:
	mode = Mode.PACE
	_t = 0.0
	_wait = wait

# The attack stops at once: its blow, its mark and its breath. Mid-dive he drops where he is.
func _abort() -> void:
	if hitbox:
		hitbox.deactivate()
	for e in [_mark, _held]:    # untyped: either may be freed already
		if is_instance_valid(e):
			(e as FxEffect).end()
	if move == &"dive" and mode == Mode.ACTIVE:
		global_position = _floor(global_position)
	move = &""

func _flinch() -> void:
	_abort()
	mode = Mode.FLINCH
	_t = 0.0
	_poise = POISE_MAX
	sprite.play_timed("flinch", facing, FLINCH_TIME)

func _on_health(hp: float, max_value: float) -> void:
	if phase != 1 or hp <= 0.0 or hp > max_value * PHASE_TWO_AT:
		return
	phase = 2
	brain.phase = 2
	sprite.speed_scale = brain.speed_scale()
	_abort()
	mode = Mode.ROAR
	_t = 0.0
	_poise = POISE_MAX
	hurtbox.invulnerable = true    # the phase shift: blows pass through him
	sprite.play_timed("roar", facing, ROAR_TIME)
	Fx.spawn(&"crown_glow", global_position + Vector3.UP * HEAD)
	phase_two.emit()

func _kneel() -> void:
	_abort()
	kneeling = true
	mode = Mode.KNEEL
	hurtbox.invulnerable = false
	Fx.clear_all()
	sprite.play_timed("kneel", facing, 0.0)
	knelt.emit()

func _shoot(m: Dictionary) -> void:
	var f := _f3()
	var side := f.cross(Vector3.UP) * lerpf(-0.8, 0.8, _shots / maxf(SPELL_BALLS - 1.0, 1.0)) * CIRCLE.RADIUS    # across the circle, side to side (LaunchBall)
	var from := global_position - f * SPELL_BEHIND + side + Vector3.UP * SPELL_HEIGHT
	var aim := f
	if is_instance_valid(target):
		aim = Vector3(target.global_position.x - from.x, 0.0, target.global_position.z - from.z).normalized()
	aim = aim.rotated(Vector3.UP, deg_to_rad(randf_range(-SPELL_SPREAD, SPELL_SPREAD)))
	_listen(Fx.spawn(&"fireball", from, aim, Hitbox.TEAM_BOSS, _blow(m)))

func _telegraph(shape: int, size: float, width: float, seconds: float) -> void:
	_mark = Fx.spawn(&"telegraph", global_position, _f3()) as FxTelegraph
	_mark.mark(shape, size, width, seconds)

# The mark keeps up with him (and the dive's with its landing) until he commits.
func _place_mark() -> void:
	if not is_instance_valid(_mark):
		return
	var f := _f3()
	_mark.basis = Basis.looking_at(f)
	match move:
		&"dive":
			_mark.global_position = _to
		&"slam":
			_mark.global_position = global_position + f * BLADE_FROM
		&"breath":
			_mark.global_position = global_position + f * MOUTH
		_:
			_mark.global_position = global_position

func _blow(m: Dictionary) -> HitInfo:
	var info := HitInfo.new()
	var push: float = m["push"]
	info.damage = float(m["damage"]) * (PHASE_TWO_DAMAGE if phase == 2 else 1.0)
	info.poise = float(m["poise"])
	info.heavy = push >= VulcanMoves.HEAVY_PUSH
	info.knockback = push * push / (2.0 * KNOCK_DECEL)    # how far Unreal's push slides at Unreal's braking, as Elvis's blows
	info.source = self
	info.at = global_position
	return info

func _listen(e: Node3D) -> void:
	var fx := e as FxEffect
	if fx and fx.hitbox:
		fx.hitbox.landed.connect(_on_landed)

func _on_landed(_target: Hurtbox, info: HitInfo) -> void:
	if info.heavy:
		Feel.hit_stop(0.09)
		Feel.shake(3.0, 0.2)

func _crack(at: Vector3, radius: float) -> void:
	if arena:
		arena.crack(at, radius)

# Turns toward `to` at `rate` deg/s; returns the degrees still to turn.
func _turn(to: Vector2, rate: float, delta: float) -> float:
	if to.length() < 0.001:
		return 0.0
	facing = Vector2.from_angle(rotate_toward(facing.angle(), to.angle(), deg_to_rad(rate) * delta))
	return rad_to_deg(absf(angle_difference(facing.angle(), to.angle())))

func _offset() -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	return Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z)

func _f3() -> Vector3:
	return Vector3(facing.x, 0.0, facing.y)

func _hop_at(x: float, a: Vector3, b: Vector3) -> void:
	global_position = a.lerp(b, x) + Vector3.UP * 0.6 * 4.0 * x * (1.0 - x)

# A floor point he can stand on: y 0, off the plinth (to its nearest side, 1 m clear) and inside the wall. The arena is at the origin.
static func _floor(p: Vector3) -> Vector3:
	var q := Vector3(p.x, 0.0, p.z)
	var keep := Arena.PLINTH + 1.0
	if absf(q.x) < keep and absf(q.z) < keep:
		if absf(q.x) > absf(q.z):
			q.x = signf(q.x) * keep
		else:
			q.z = keep if q.z >= 0.0 else -keep
	var r := Arena.RADIUS - 1.0
	if Vector2(q.x, q.z).length() > r:
		q *= r / Vector2(q.x, q.z).length()
	return q
