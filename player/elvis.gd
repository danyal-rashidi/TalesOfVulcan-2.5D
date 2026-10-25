class_name Elvis extends Actor
# The player: run and sprint with smooth starts and stops, a 3.5 m roll with i-frames, a 4-hit light combo, a heavy that lunges
# when tapped and charges into a thrust when held, flasks and lock-on. One press is buffered at a time.
# Numbers are the Unreal game's wherever it has one (D:\TalesOfVulkan\TalesOfVulkan\Source\TalesOfVulkan, cm turned into m).

enum State {MOVE, ROLL, LIGHT, LUNGE, CHARGE, THRUST, DRINK, HURT, DEAD}

const RUN_SPEED := 5.0          # MaxWalkSpeed 500 cm/s (TalesOfVulkanCharacter.cpp)
const SPRINT_SPEED := 7.5       # SprintSpeed 750 cm/s (TalesOfVulkanCharacter.h)
const ACCEL := 30.0             # m/s², the plan's: Unreal sets no MaxAcceleration of its own
const DECEL := 40.0             # m/s², the plan's: Unreal's BrakingDecelerationWalking (20 m/s²) has ground friction on top, which stops sooner
const TURN_RATE := 720.0        # degrees/s: RotationRate yaw 720 (TalesOfVulkanCharacter.cpp)
const ROLL_DISTANCE := 3.5      # DodgeDistance 350 cm (TalesOfVulkanCharacter.h)
const ROLL_TIME := 0.6          # DodgeTravelTime, the roll without a clip (TalesOfVulkanCharacter.h)
const IFRAMES := Vector2(0.05, 0.40)    # seconds into the roll, the plan's (Unreal makes the whole roll untouchable)
const ROLL_COST := 20.0         # RollStaminaCost (TalesOfVulkanCharacter.h)
const LIGHT_COST := 15.0        # LightAttackStaminaCost
const HEAVY_COST := 30.0        # HeavyAttackStaminaCost: the lunge, or the charge once as it begins (FStaffCombo)
const SPRINT_COST := 15.0       # per second: SprintStaminaPerSecond
const SPRINT_RESUME := 0.2      # after the sprint ran the bar dry it works again from this fraction: SprintResumeFraction
const SPRINT_HOLD := 0.25       # roll held this long sprints instead of rolling (the plan)
const COMBO_MAX := 4            # FStaffCombo.LightSwings has four
const COMBO_RESET := 0.6        # a light press this soon after a light swing goes on to the next: ComboResetDelay
const BUFFER := 0.45            # how long a press waits for its turn: AttackInputWindow (the plan's 0.3 would drop a press made as a swing starts)
const RECOVERY := 0.3           # a swing's recovery after its cancel point: MaxRecoveryTime
const HOLD := 0.2               # a heavy held this long is a charge: FStaffCombo.HoldThreshold
const FULL_CHARGE := 1.2        # seconds in the stance for the strongest thrust: FStaffCombo.FullChargeTime
const MAX_CHARGE_SCALE := 2.0   # the strongest thrust's damage multiplier: FStaffCombo.MaxDamageScale
const HEAVY_POISE := 2.0        # heavy blows do twice their damage to poise: BossVulcan.h HeavyPoiseScale
const DRINK_TIME := 1.2         # FFlaskDrink.DrinkTime (FlaskComponent.h)
const GULP_TIME := 0.55         # the flask works here; a hit before breaks it off and he keeps the flask: FFlaskDrink.GulpTime
const DRINK_WALK := 0.4         # his walk while drinking: FFlaskDrink.WalkSpeedScale
const HURT_TIME := 0.4          # Claude's call
const LOCK_RANGE := 15.0        # the plan
const REACH := 1.1              # metres from his centre to the middle of the spear's hit sphere
const MAX_STAMINA := 150.0      # MaxStamina (StaminaComponent.h); RegenPerSecond 30 is the Stamina default. Max health 100 is MaxHP's.
const STAMINA_DELAY := 1.0      # RegenDelay (StaminaComponent.h)

# Seconds from the swing's start. cancel: the next move may start; hit: when the spear can hit if the sheet has no "active" frames;
# push: the Unreal push in m/s; step: metres he travels until the hit ends.
# light1-4: FStaffCombo.LightSwings (TalesOfVulkanCharacter.h). lunge: HeavySwing (TalesOfVulkanCharacter.cpp), with the plan's 2 m step.
# thrust: FStaffCombo.Thrust, damage x1 to x2 with the charge.
const ATTACKS := {
	"light1": {"cancel": 0.35, "hit": Vector2(0.05, 0.20), "damage": 8.0, "push": 1.2, "step": 0.0},
	"light2": {"cancel": 0.35, "hit": Vector2(0.03, 0.20), "damage": 8.0, "push": 1.2, "step": 0.0},
	"light3": {"cancel": 0.35, "hit": Vector2(0.06, 0.26), "damage": 10.0, "push": 1.4, "step": 0.0},
	"light4": {"cancel": 0.35, "hit": Vector2(0.10, 0.22), "damage": 14.0, "push": 3.0, "step": 0.0},
	"lunge": {"cancel": 0.45, "hit": Vector2(0.28, 0.40), "damage": 30.0, "push": 6.0, "step": 2.0},
	"thrust": {"cancel": 0.40, "hit": Vector2(0.07, 0.22), "damage": 30.0, "push": 6.0, "step": 0.5},
}
const PRESSES: Array[StringName] = [&"attack_light", &"attack_heavy", &"flask_red", &"flask_green"]

var state: State = State.MOVE
var combo_index := 0
var lock_target: Node3D
var input_enabled := true
@onready var stamina: Stamina = $Stamina
@onready var flasks: Flasks = $Flasks
@onready var hitbox: Hitbox = $Hitbox

var _clock := 0.0           # game seconds, so a hit-stop holds the buffer too
var _t := 0.0               # seconds in the state
var _input := Vector2.ZERO
var _vel := Vector2.ZERO    # ground velocity (x, z), knockback apart
var _buffered := &""
var _buffered_at := 0.0
var _roll_held := -1.0      # seconds the roll button has been down; -1 when up
var _sprinting := false
var _winded := false
var _last_light := -INF     # when the last light swing ended
var _attack := {}
var _window := Vector2i(-1, -1)
var _swung := false
var _roll_dir := Vector2.DOWN
var _rolled := 0.0
var _charged := false
var _charge_scale := 1.0
var _drink := &""
var _gulped := false

func _ready() -> void:
	super()
	stamina.max_value = MAX_STAMINA
	stamina.regen_delay = STAMINA_DELAY
	stamina.refill()
	hitbox.landed.connect(_on_landed)
	health.died.connect(_enter.bind(State.DEAD))
	sprite.set_tint(Color(0.55, 0.7, 1.0))    # blue, so the stand-in reads as Elvis
	sprite.load_character("elvis")

# Full health, stamina and flasks, standing in MOVE, facing up.
func reset_to(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_vel = Vector2.ZERO
	_push = Vector3.ZERO
	_goal_speed = 0.0
	health.reset()
	stamina.refill()
	flasks.refill()
	combo_index = 0
	lock_target = null
	_buffered = &""
	_roll_held = -1.0
	_winded = false
	_last_light = -INF
	facing = Vector2.UP
	_enter(State.MOVE)
	sprite.restart("idle", facing)

func take_hit(info: HitInfo) -> void:
	super(info)
	if state != State.DEAD:
		_enter(State.HURT)

func _tick(delta: float) -> void:
	_clock += delta
	_t += delta
	_read_input(delta)
	_use_buffer()
	match state:
		State.MOVE:
			_tick_move(delta)
		State.ROLL:
			_tick_roll(delta)
		State.LIGHT, State.LUNGE, State.THRUST:
			_tick_swing(delta)
		State.CHARGE:
			_tick_charge(delta)
		State.DRINK:
			_tick_drink(delta)
		State.HURT:
			_brake(delta)
			if _t >= HURT_TIME:
				_enter(State.MOVE)
		State.DEAD:
			_brake(delta)
	hitbox.position = Vector3(facing.x * REACH, 0.9, facing.y * REACH)
	_slide(Pixel.ground(_vel), delta)

func _read_input(delta: float) -> void:
	if not input_enabled or state == State.DEAD:
		_input = Vector2.ZERO
		_roll_held = -1.0
		return
	@warning_ignore("static_called_on_instance")
	_input = Controls.move_vector()
	for a in PRESSES:
		if Input.is_action_just_pressed(a):
			_press(a)
	if Input.is_action_just_pressed(&"roll"):
		_roll_held = 0.0
	if _roll_held >= 0.0:
		if Input.is_action_pressed(&"roll"):
			_roll_held += delta
		else:
			if _roll_held < SPRINT_HOLD:    # a tap rolls, on release
				_press(&"roll")
			_roll_held = -1.0
	if Input.is_action_just_pressed(&"lock_on"):
		_toggle_lock()

# The one buffered press: a newer one replaces it.
func _press(a: StringName) -> void:
	_buffered = a
	_buffered_at = _clock

func _use_buffer() -> void:
	if _buffered == &"":
		return
	if _clock - _buffered_at > BUFFER:
		_buffered = &""
	elif _accepts(_buffered):
		var a := _buffered
		_buffered = &""
		_start(a)

func _accepts(a: StringName) -> bool:
	match state:
		State.MOVE:
			return true
		State.LIGHT, State.LUNGE, State.THRUST:
			return a == &"roll" or _t >= float(_attack["cancel"])    # the roll cancels a swing at any moment (Unreal, Danyal 23 Oct)
		State.CHARGE:
			return a == &"roll"
	return false

# Refused (and dropped) when stamina or the flask is gone.
func _start(a: StringName) -> void:
	match a:
		&"roll":
			if stamina.spend(ROLL_COST):
				_enter(State.ROLL)
		&"attack_light":
			if stamina.spend(LIGHT_COST):
				combo_index = combo_index % COMBO_MAX + 1
				_enter(State.LIGHT)
		&"attack_heavy":
			if stamina.value > 0.0:    # paid when the tap or the hold is known
				_enter(State.CHARGE)
		&"flask_red", &"flask_green":
			if (flasks.red if a == &"flask_red" else flasks.green) > 0:
				_drink = a
				_enter(State.DRINK)

func _enter(s: State) -> void:
	if state == State.LIGHT:
		_last_light = _clock
	hitbox.deactivate()
	hurtbox.invulnerable = false
	if s != State.LIGHT and s != State.MOVE:
		combo_index = 0    # any other move starts the string again (Unreal: NextLightSwing)
	state = s
	_t = 0.0
	_swung = false
	_window = Vector2i(-1, -1)
	match s:
		State.ROLL:
			_roll_dir = _input.normalized() if _input != Vector2.ZERO else facing
			facing = _roll_dir
			_rolled = 0.0
			sprite.play_timed("roll", facing, ROLL_TIME)
		State.LIGHT:
			_begin("light%d" % combo_index)
		State.LUNGE:
			_begin("lunge")
		State.THRUST:
			_begin("thrust")
		State.CHARGE:
			_charged = false
			_aim()
			sprite.restart("charge", facing)
		State.DRINK:
			_gulped = false
			sprite.play_timed("drink", facing, DRINK_TIME)
		State.HURT:
			sprite.play_timed("hurt", facing, HURT_TIME)
		State.DEAD:
			hurtbox.invulnerable = true
			sprite.play_timed("death", facing, 0.0)

func _begin(anim: String) -> void:
	_attack = ATTACKS[anim]
	_aim()
	sprite.play_timed(anim, facing, float(_attack["cancel"]) + RECOVERY)
	_window = sprite.active_window(sprite.current_key)

func _aim() -> void:
	var want := _to_target() if _locked() else _input.normalized()
	if want != Vector2.ZERO:
		facing = want

func _tick_move(delta: float) -> void:
	if _clock - _last_light > COMBO_RESET:
		combo_index = 0
	if _winded and stamina.value >= SPRINT_RESUME * stamina.max_value:
		_winded = false
	_sprinting = _roll_held >= SPRINT_HOLD and _input != Vector2.ZERO and not _winded
	if _sprinting and not stamina.spend(SPRINT_COST * delta):
		_sprinting = false
		_winded = true
	var top := SPRINT_SPEED if _sprinting else RUN_SPEED
	_vel = _vel.move_toward(_input * top, (ACCEL if _input != Vector2.ZERO else DECEL) * delta)
	var look := _to_target() if _locked() and not _sprinting else _input
	if look != Vector2.ZERO:
		facing = Vector2.from_angle(rotate_toward(facing.angle(), look.angle(), deg_to_rad(TURN_RATE) * delta))
	var anim := "idle"
	if _vel.length() > 0.25:
		anim = "sprint" if _sprinting else "run"
	sprite.play(anim, facing)

func _tick_roll(delta: float) -> void:
	var x := clampf(_t / ROLL_TIME, 0.0, 1.0)
	var at := ROLL_DISTANCE * 4.0 / 3.0 * (x - x * x * x * x / 4.0)    # fast, easing to a stop: Unreal's dash (TalesOfVulkanCharacter.cpp UpdateDodge)
	_vel = _roll_dir * (at - _rolled) / maxf(delta, 1e-6)
	_rolled = at
	hurtbox.invulnerable = _t >= IFRAMES.x and _t <= IFRAMES.y
	if _t >= ROLL_TIME:
		_enter(State.MOVE)

func _tick_swing(delta: float) -> void:
	var hit: Vector2 = _attack["hit"]
	var step: float = _attack["step"]
	var length := float(_attack["cancel"]) + RECOVERY
	if step > 0.0 and _t < hit.y:
		_vel = facing * step / hit.y
	else:
		_brake(delta)
	var on := _t >= hit.x and _t < hit.y
	if _window.x >= 0:    # the sheet names its hit frames: they win over the fixed times
		on = sprite.frame >= _window.x and sprite.frame <= _window.y
	if on and not _swung:
		_swung = true
		hitbox.activate(_blow(), length)
	elif not on and _swung and hitbox.is_active():
		hitbox.deactivate()
	if _t >= length:
		_enter(State.MOVE)

func _tick_charge(delta: float) -> void:
	_brake(delta)
	var held := input_enabled and Input.is_action_pressed(&"attack_heavy")
	if not _charged:
		if not held:
			_enter(State.LUNGE if stamina.spend(HEAVY_COST) else State.MOVE)
		elif _t >= HOLD:
			_charged = stamina.spend(HEAVY_COST)
			if not _charged:
				_enter(State.MOVE)
	elif not held:
		_charge_scale = lerpf(1.0, MAX_CHARGE_SCALE, clampf((_t - HOLD) / FULL_CHARGE, 0.0, 1.0))
		_enter(State.THRUST)

func _tick_drink(delta: float) -> void:
	_vel = _vel.move_toward(_input * RUN_SPEED * DRINK_WALK, (ACCEL if _input != Vector2.ZERO else DECEL) * delta)
	if not _gulped and _t >= GULP_TIME:
		_gulped = true
		if _drink == &"flask_red":
			flasks.drink_red(health)
		else:
			flasks.drink_green(stamina)
	if _t >= DRINK_TIME:
		_enter(State.MOVE)

func _brake(delta: float) -> void:
	_vel = _vel.move_toward(Vector2.ZERO, DECEL * delta)

func _blow() -> HitInfo:
	var info := HitInfo.new()
	info.heavy = state != State.LIGHT
	info.damage = float(_attack["damage"]) * (_charge_scale if state == State.THRUST else 1.0)
	info.poise = info.damage * (HEAVY_POISE if info.heavy else 1.0)
	var push: float = _attack["push"]
	info.knockback = push * push / (2.0 * KNOCK_DECEL)    # how far Unreal's push slides at Unreal's braking
	info.source = self
	info.at = hitbox.global_position
	return info

func _on_landed(_target: Hurtbox, info: HitInfo) -> void:
	Feel.hit_stop(0.09 if info.heavy else 0.07)
	if info.heavy:
		Feel.shake(3.0, 0.2)
	else:
		Feel.shake(1.0, 0.1)

# The nearest Actor of the other team within LOCK_RANGE, or off again.
func _toggle_lock() -> void:
	if _locked():
		lock_target = null
		return
	var best := LOCK_RANGE
	for n in get_tree().get_nodes_in_group(&"actors"):
		var a := n as Actor
		if a and a != self and a.hurtbox.team != hurtbox.team:
			var d := a.global_position.distance_to(global_position)
			if d <= best:
				best = d
				lock_target = a

func _locked() -> bool:
	if not is_instance_valid(lock_target):
		lock_target = null
	return lock_target != null

func _to_target() -> Vector2:
	var d := lock_target.global_position - global_position
	return Vector2(d.x, d.z).normalized()
