class_name Elvis extends Actor
# The player: run and sprint with smooth starts and stops, a 3.5 m roll with i-frames, a 4-hit light combo, a heavy that lunges
# when tapped and charges into a thrust when held, a timed parry, flasks and lock-on. One press is buffered at a time (never the parry).
# Numbers are the Unreal game's wherever it has one (D:\TalesOfVulkan\TalesOfVulkan\Source\TalesOfVulkan, cm turned into m).

signal parried(info: HitInfo)    # a blow turned aside: the tests count it, and a sound can hang on it later

enum State {MOVE, ROLL, LIGHT, LUNGE, CHARGE, THRUST, DRINK, HURT, DEAD, EQUIP, ABILITY, AIM, CAST, PARRY}

const RUN_SPEED := 5.0          # MaxWalkSpeed 500 cm/s (TalesOfVulkanCharacter.cpp)
const SPRINT_SPEED := 7.5       # SprintSpeed 750 cm/s (TalesOfVulkanCharacter.h)
const ACCEL := 30.0             # m/s², the plan's: Unreal sets no MaxAcceleration of its own
const DECEL := 40.0             # m/s², the plan's: Unreal's BrakingDecelerationWalking (20 m/s²) has ground friction on top, which stops sooner
const TURN_RATE := 720.0        # degrees/s: RotationRate yaw 720 (TalesOfVulkanCharacter.cpp)
const ROLL_DISTANCE := 3.5      # DodgeDistance 350 cm (TalesOfVulkanCharacter.h)
const ROLL_TIME := 0.6          # DodgeTravelTime, the roll without a clip (TalesOfVulkanCharacter.h)
const IFRAMES := Vector2(0.05, 0.40)    # seconds into the roll, the plan's (Unreal makes the whole roll untouchable)
const ROLL_COST := 20.0         # RollStaminaCost (TalesOfVulkanCharacter.h)
const LIGHT_COST := 10.0        # Danyal's call, 31 Oct: less than Unreal's LightAttackStaminaCost 15
const HEAVY_COST := 20.0        # Danyal's call, 31 Oct: less than Unreal's HeavyAttackStaminaCost 30: the lunge, or the charge once as it begins (FStaffCombo)
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
const EQUIP_TIME := 0.4         # Claude's call: drawing or putting away the spear
const DRINK_TIME := 1.2         # FFlaskDrink.DrinkTime (FlaskComponent.h)
const GULP_TIME := 0.55         # the flask works here; a hit before breaks it off and he keeps the flask: FFlaskDrink.GulpTime
const DRINK_WALK := 0.4         # his walk while drinking: FFlaskDrink.WalkSpeedScale
const HURT_TIME := 0.4          # Claude's call
const LOCK_RANGE := 15.0        # the plan
const REACH := 1.1              # metres from his centre to the middle of the spear's hit sphere
const MAX_STAMINA := 150.0      # MaxStamina (StaminaComponent.h); RegenPerSecond 30 is the Stamina default.
const MAX_HEALTH := 100.0       # MaxHP's
const STAMINA_DELAY := 1.0      # RegenDelay (StaminaComponent.h)
const PARRY_WINDOW := 0.2       # s from the press that a blow is turned aside. Sekiro's deflect is about this; there's no sound to time it by yet, so not tighter. Claude's call
const PARRY_RECOVER := 0.4      # s he stands open after a parry that caught nothing, and can't roll: a miss costs 0.6 s for a 0.2 s window, so mashing loses. Claude's call
const PARRY_HOLD := 0.2         # s the deflect pose holds after a catch; any press cuts it (the riposte, or the next parry). Claude's call
const PARRY_POISE := 35.0       # poise a parried blow costs its striker, armour or not: ~4x a light hit's 8. Three break Vulcan's 100 inside his 4 s regen delay; one breaks a jackal's 30. Claude's call
const PARRY_STOP := 0.12        # s of hit-stop: longer than a heavy's 0.09, so a parry is the biggest stop in the fight. Claude's call
const PARRY_SKID := 0.3         # m he slides back off the blow. Claude's call

# Seconds from the swing's start. cancel: the next move may start; hit: when the spear can hit if the sheet has no "active" frames;
# push: the Unreal push in m/s; step: metres each spear attack lunges him forward, before he brakes (Danyal's call, 30 Oct: every one of them carries him).
# light1-4: FStaffCombo.LightSwings (TalesOfVulkanCharacter.h). lunge: HeavySwing (TalesOfVulkanCharacter.cpp), with the plan's 2 m step.
# thrust: FStaffCombo.Thrust, damage x1 to x2 with the charge.
const ATTACKS := {
	"light1": {"cancel": 0.35, "hit": Vector2(0.05, 0.20), "damage": 8.0, "push": 1.2, "step": 1.0},
	"light2": {"cancel": 0.35, "hit": Vector2(0.03, 0.20), "damage": 8.0, "push": 1.2, "step": 1.0},
	"light3": {"cancel": 0.35, "hit": Vector2(0.06, 0.26), "damage": 10.0, "push": 1.4, "step": 1.2},
	"light4": {"cancel": 0.35, "hit": Vector2(0.10, 0.22), "damage": 14.0, "push": 3.0, "step": 1.8},
	"lunge": {"cancel": 0.45, "hit": Vector2(0.28, 0.40), "damage": 30.0, "push": 6.0, "step": 2.0},
	"thrust": {"cancel": 0.40, "hit": Vector2(0.07, 0.22), "damage": 30.0, "push": 6.0, "step": 1.5},
}
# Human Vulcan's own two: a cut down, then a rising finisher with light 4's push, so a swing still averages the 10 his old string of four did. And his heavies.
# No "step": he swings where he stands (see _tick_swing). Claude's call.
# mark: sheet frames before the hit opens that his blade's mark starts: light 1 and the heavy open their hit as the blade arrives, so it runs with the frame on the way there. Light 2's hit rises with its blade.
const VULCAN_ATTACKS := {
	"light1": {"cancel": 0.35, "hit": Vector2(0.05, 0.20), "damage": 8.0, "push": 1.2, "mark": 1},
	"light2": {"cancel": 0.35, "hit": Vector2(0.03, 0.20), "damage": 12.0, "push": 3.0},
	"lunge": {"cancel": 0.45, "hit": Vector2(0.28, 0.40), "damage": 30.0, "push": 6.0, "mark": 1},
	"thrust": {"cancel": 0.40, "hit": Vector2(0.07, 0.22), "damage": 30.0, "push": 6.0, "mark": 1},
}
const VULCAN_LIGHT1_END := 8    # light 1's last frame on its sheet
const VULCAN_LATE := 3          # light 1's last frames, on his way back to his stand: a light 2 pressed on one starts there
const VULCAN_HIGH := 2          # light 2 has at least this many frames left with the sword still high: a light 1 pressed then skips its stand
const PRESSES: Array[StringName] = [&"attack_light", &"attack_heavy", &"flask_red", &"flask_green", &"equip", &"ability_f", &"ability_q"]
const CLICK_REACH := 30.0       # px on screen: a click this close to an enemy locks on to it
const LEAP_HIGH := 1.3          # m at the top of a leap, however far it goes: he always really jumps
const LEAP_CLEAR := 0.4         # m: he lands this clear of anything solid
const PAD_AIM := 9.0            # m/s the mark moves with the stick
const ICE_SKILL := "Ice Spears" # Elvis's F, his one skill (Danyal). In Journey.ABILITIES with Vulcan's, though it's never on Vulcan's keys

var state: State = State.MOVE
var combo_index := 0
var combo_max := COMBO_MAX  # swings in his light string, set per character
var spear_out := true       # with it put away he can't attack (Danyal, 31 Oct). Human Vulcan's iron sword is his "spear": the same moves and the same sheet names
var has_weapon := true      # Vulcan has none until he takes one from the legionary's tomb
var character := "elvis_blue"    # the art/ folder he's drawn from; set it before he enters the tree
var lock_target: Node3D
var walk_speed := RUN_SPEED     # m/s, set per character: he walks as his sheets are drawn, so his feet don't slide
var sprint_speed := SPRINT_SPEED
var accel := ACCEL
var decel := DECEL
var _ability := {}
var _ability_slot := &""
var _landed := false
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_mask := 0
var _aura: FxHammerAura
var _volley: FxIceVolley
var _launched := false
var _head_at := Vector3.ZERO    # where the hammer's head comes down: the point of the blow
var _aim_at := Vector3.ZERO
var _aim_mark: AimMark
var _mouse_aims := true         # the mouse was the last thing moved, not a stick
var _ready_at := {}             # skill -> _clock when it can be used again. By skill, so moving it to the other key doesn't cool it
var input_enabled := true
@onready var stamina: Stamina = $Stamina
@onready var flasks: Flasks = $Flasks
@onready var hitbox: Hitbox = $Hitbox

var _clock := 0.0           # game seconds, so a hit-stop holds the buffer too
var _t := 0.0               # seconds in the state
var _input := Vector2.ZERO
var _vel := Vector2.ZERO    # ground velocity (x, z), knockback apart
var _lunge := Vector2.ZERO  # seconds from a swing's start between which its step carries him
var _join := ""             # the sheet a Vulcan slash starts from when pressed where its own first frame would snap him. "": its own
var _marked := false        # this swing's mark is out
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
var _lined := false         # this blow has had its speed lines
var _drink := &""
var _gulped := false
var _caught := false        # this parry turned a blow aside

func _ready() -> void:
	super()
	stamina.max_value = MAX_STAMINA
	stamina.regen_delay = STAMINA_DELAY
	stamina.refill()
	walk_pace = walk_speed
	hitbox.landed.connect(_on_landed)
	health.died.connect(_enter.bind(State.DEAD))
	sprite.set_tint(Color(0.55, 0.7, 1.0))    # blue, so the stand-in reads as Elvis
	sprite.load_character(character)

# Full health, stamina and flasks, standing in MOVE, facing up.
func reset_to(at: Vector3) -> void:
	global_position = at
	reset_physics_interpolation()    # there at once, not drawn gliding from where he died
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
	spear_out = has_weapon
	_ready_at.clear()
	_enter(State.MOVE)
	sprite.restart(_look("idle"), facing)

func take_hit(info: HitInfo) -> void:
	if state == State.PARRY and _t < PARRY_WINDOW and _can_parry(info):
		_deflect(info)
		return
	super(info)
	if state != State.DEAD and info.knockback > 0.0:    # a burn (the breath) pushes nothing and doesn't stun him (Unreal: no hit reaction without a push)
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
		State.EQUIP:
			_brake(delta)
			if _t >= EQUIP_TIME:
				spear_out = not spear_out
				_enter(State.MOVE)
		State.ABILITY:
			_tick_ability(delta)
		State.AIM:
			_tick_aim(delta)
		State.CAST:
			_tick_cast(delta)
		State.PARRY:
			_brake(delta)
			if _t >= PARRY_WINDOW + (PARRY_HOLD if _caught else PARRY_RECOVER):
				_enter(State.MOVE)
	hitbox.position = Vector3(facing.x * REACH, 0.9 + Hills.rise(global_position, facing * REACH), facing.y * REACH)
	_slide(Pixel.ground(_vel), delta)

func _read_input(delta: float) -> void:
	if not input_enabled or state == State.DEAD or Dev.open:    # Dev's panel has the mouse and keys while it's open
		_input = Vector2.ZERO
		_roll_held = -1.0
		return
	@warning_ignore("static_called_on_instance")
	_input = Controls.move_vector()
	for a in PRESSES:
		if Input.is_action_just_pressed(a):
			_press(a)
	if Input.is_action_just_pressed(&"parry") and _accepts(&"parry"):    # never buffered: a parry is all timing, and the buffer would fire it late
		_start(&"parry")
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
			# the roll cancels a swing at any moment (Unreal, Danyal 23 Oct); anything else waits for the cancel point and for the
			# hit to be over, so a sheet whose hit frames come late isn't cut off before it lands
			return a == &"roll" or a == &"parry" or (_t >= float(_attack["cancel"]) and _swung and not hitbox.is_active())
		State.CHARGE, State.EQUIP, State.AIM, State.CAST:
			return a == &"roll" or a == &"parry"
		State.PARRY:
			return _caught    # in the window and a miss's recovery nothing goes, not even a roll; after a catch anything does
	return false

# Refused (and dropped) when stamina or the flask is gone.
func _start(a: StringName) -> void:
	match a:
		&"roll":
			if stamina.spend(ROLL_COST):
				_enter(State.ROLL)
		&"parry":
			if spear_out:    # with nothing in his hand there's nothing to turn a blow with
				_enter(State.PARRY)
		&"attack_light":
			if spear_out and stamina.spend(LIGHT_COST):
				_join = _vulcan_join()
				combo_index = combo_index % combo_max + 1
				_enter(State.LIGHT)
		&"attack_heavy":
			if spear_out and stamina.value > 0.0:    # paid when the tap or the hold is known
				_enter(State.CHARGE)
		&"equip":
			if has_weapon:
				_enter(State.EQUIP)
		&"flask_red", &"flask_green":
			if (flasks.red if a == &"flask_red" else flasks.green) > 0:
				_drink = a
				_enter(State.DRINK)
		&"ability_f", &"ability_q":
			_use_ability(a)

# Counted from a sheet's end, since a late light 2 has more frames before it than a plain one.
func _vulcan_join() -> String:
	if not _is_vulcan() or state != State.LIGHT:
		return ""
	var left := sprite.frames_left()
	if combo_index == 1 and left < VULCAN_LATE:
		return "light2_late%d" % (VULCAN_LIGHT1_END - left)
	if combo_index == combo_max and left >= VULCAN_HIGH:
		return "light1_on"
	return ""

func _enter(s: State) -> void:
	if state == State.LIGHT:
		_last_light = _clock
	if state == State.AIM and is_instance_valid(_aim_mark):
		_aim_mark.visible = false
	if state == State.ABILITY:
		collision_mask = _leap_mask
		sprite.position.y = 0.0
	hitbox.deactivate()
	hurtbox.invulnerable = false
	if s != State.LIGHT and (s != State.MOVE or _is_vulcan()):
		combo_index = 0    # any other move starts the string again (Unreal: NextLightSwing). Vulcan's second slash starts from the first's low pose, so once he's back on his feet he starts over
	state = s
	_t = 0.0
	_swung = false
	_marked = false
	_lined = false
	_window = Vector2i(-1, -1)
	match s:
		State.ROLL:
			_roll_dir = _input.normalized() if _input != Vector2.ZERO else facing
			facing = _roll_dir
			_rolled = 0.0
			sprite.play_timed(_look("roll"), facing, ROLL_TIME)
		State.LIGHT:
			_begin("light%d" % combo_index, _join if _join != "" else "light%d" % combo_index)
		State.LUNGE:
			_begin("lunge", "lunge")
		State.THRUST:
			_begin("thrust", "thrust")
		State.CHARGE:
			_charged = false
			_aim()
			if _is_vulcan():    # his stance raises the sword: only once it's a hold, or every tap would flash it
				sprite.play(_look("idle"), facing)
			else:
				sprite.restart("charge", facing)
		State.DRINK:
			_gulped = false
			sprite.play_timed(_look("drink_walk" if _input != Vector2.ZERO else "drink"), facing, DRINK_TIME)
		State.HURT:
			sprite.play_timed(_look("hurt"), facing, HURT_TIME)
		State.PARRY:
			_caught = false
			_aim()
			sprite.restart("charge" if _is_vulcan() else "parry", facing)    # shortcut: Vulcan has no parry clip, the start of his charge stance stands in
		State.DEAD:
			hurtbox.invulnerable = true
			sprite.play_timed(_look("death"), facing, 0.0)
		State.EQUIP:
			sprite.play_timed("unequip" if spear_out else "equip", facing, EQUIP_TIME)
		State.AIM:
			_aim_at = _aim_start()
			if not is_instance_valid(_aim_mark):
				_aim_mark = AimMark.new()
				add_child(_aim_mark)
			sprite.play(_look("idle"), facing)
		State.ABILITY:
			_landed = false
			_leap_from = global_position
			facing = Vector2(-1.0 if _aim_at.x < _leap_from.x else 1.0, 0.0)    # the leap is drawn side on
			_leap_to = _landing(_aim_at)
			_head_at = FxHammerAura.head_from(_leap_to, facing.x)
			hurtbox.invulnerable = true    # in the air
			_leap_mask = collision_mask
			collision_mask = 0             # over whatever's in the way
			sprite.play_timed(_ability["sheet"], facing, float(_ability["time"]))
			_aura = Fx.spawn(&"hammer_aura", global_position) as FxHammerAura
			_aura.follow(self, float(_ability["land"]))
		State.CAST:
			_launched = false
			var foe := ice_target()
			if foe:
				var to := foe.global_position - global_position
				facing = Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 0.01 else facing
			sprite.play_timed(_ability["sheet"], facing, float(_ability["time"]))
			_volley = Fx.spawn(&"ice_volley", global_position) as FxIceVolley
			_volley.follow(self)

func _begin(anim: String, sheet: String) -> void:
	_attack = VULCAN_ATTACKS.get(anim, ATTACKS[anim]) if _is_vulcan() else ATTACKS[anim]
	_aim()
	sprite.play_timed(sheet, facing, float(_attack["cancel"]) + RECOVERY)
	_window = sprite.active_window(sprite.current_key)
	var hit: Vector2 = _attack["hit"]
	# he surges with the spear: with hit frames, from the frame before them to their end, so he doesn't skate through the wind-up
	_lunge = Vector2(sprite.seconds_to_frame(_window.x - 1), sprite.seconds_to_frame(_window.y + 1)) if _window.x >= 0 else Vector2(0.0, hit.y)

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
	var top := (sprint_speed if _sprinting else walk_speed) * (Dev.FAST_WALK if Dev.fast_walk else 1.0)
	_vel = _vel.move_toward(_input * top, (accel if _input != Vector2.ZERO else decel) * delta)
	var look := _to_target() if _locked() and not _sprinting else _input
	if look != Vector2.ZERO:
		facing = Vector2.from_angle(rotate_toward(facing.angle(), look.angle(), deg_to_rad(TURN_RATE) * delta))
	var anim := "idle"
	if _vel.length() > 0.25:
		anim = "sprint" if _sprinting else "run"
	# his feet keep pace with the ground: a sheet plays as fast as he moves for it. Without a run of his own, he runs his walk faster.
	sprite.speed_scale = clampf(_vel.length() / (sprint_speed if _sprinting and _has_run() else walk_speed), 0.4, 1.6) if anim != "idle" else 1.0
	sprite.play(_look(anim), facing)

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
	var step: float = _attack.get("step", 0.0)
	var length := float(_attack["cancel"]) + RECOVERY
	if _is_vulcan():
		_vel = Vector2.ZERO    # his clips step within the sheet with the other foot planted on its pixels, so any move of him slides it, and with the camera on him the ground jumps. What he ran in with stops too
	elif step > 0.0 and _t >= _lunge.x and _t < _lunge.y:
		_vel = facing * step / (_lunge.y - _lunge.x)
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
	if not _marked and (on or (_window.x >= 0 and sprite.frame >= _window.x - int(_attack.get("mark", 0)))):
		_marked = true
		_mark_swing()
	if _t >= length:
		_enter(State.MOVE)

# What's on a key. Elvis has only the ice on F; Vulcan has what he's put there.
func skill_on(slot: StringName) -> String:
	var skill: String = Journey.ability_slots.get(slot, "")
	return ICE_SKILL if skill == "" and slot == &"ability_f" and not _is_vulcan() else skill

# A skill on F or Q: it needs the sword out, the stamina, and to have cooled down. Its key held, he chooses where; let go, he goes. The ice needs someone to go for, or the press does nothing and costs nothing, and it starts at once.
func _use_ability(slot: StringName) -> void:
	var skill := skill_on(slot)
	if skill == "" or not spear_out or not Journey.ABILITIES.has(skill) or ability_left(slot) > 0.0:
		return
	var a: Dictionary = Journey.ABILITIES[skill]
	if stamina.value >= float(a["cost"]):
		_ability = a
		_ability_slot = slot
		if skill != ICE_SKILL:
			_enter(State.AIM)
		elif ice_target():
			_enter(State.CAST)

# The spears go for whoever he's locked on to, or the nearest enemy in reach, if they can be hit at all: not the statue or the kneeling boss.
func ice_target() -> Actor:
	if _locked() and lock_target is Actor and not (lock_target as Actor).hurtbox.invulnerable:
		return lock_target
	var best: Actor = null
	var near := LOCK_RANGE
	for n in get_tree().get_nodes_in_group(&"actors"):
		var a := n as Actor
		if a and a.hurtbox.team != hurtbox.team and a.health.ratio() > 0.0 and not a.hurtbox.invulnerable:
			var d := a.global_position.distance_to(global_position)
			if d <= near:
				near = d
				best = a
	return best

# He stands and can be hit: a blow with a push stops it, as a roll does, the spears break, and it costs neither stamina nor the cooldown (FxIceVolley). Only the launch spends them. Claude's call.
func _tick_cast(delta: float) -> void:
	_brake(delta)
	if not input_enabled:
		_enter(State.MOVE)    # a scene has started
	elif not _launched and _t >= float(_ability["launch"]):
		_launched = true
		stamina.spend(float(_ability["cost"]))
		_ready_at[ICE_SKILL] = _clock + float(_ability["cooldown"])
		if is_instance_valid(_volley):
			_volley.launch(ice_target())
	elif _t >= float(_ability["time"]):
		_enter(State.MOVE)

func _tick_aim(delta: float) -> void:
	_brake(delta)
	if _mouse_aims:
		var at := _ground_under_mouse()
		if at != Vector3.INF:
			_aim_at = at
	elif _input != Vector2.ZERO:
		_aim_at += Pixel.ground(_input * PAD_AIM * delta)
	var reach := float(_ability["range"])
	var way := _aim_at - global_position
	way.y = 0.0
	if way.length() > reach:
		_aim_at = global_position + way.normalized() * reach
	_aim_at.y = 0.0
	if way.length() > 0.2:
		facing = Vector2(way.x, way.z).normalized()
		sprite.play(_look("idle"), facing)
	_aim_mark.show_from(global_position, _aim_at)
	if not input_enabled:
		_enter(State.MOVE)    # a scene has started: he doesn't go
	elif not Input.is_action_pressed(_ability_slot):
		if stamina.spend(float(_ability["cost"])):
			_ready_at[skill_on(_ability_slot)] = _clock + float(_ability["cooldown"])
			_enter(State.ABILITY)
		else:
			_enter(State.MOVE)

# Where the mark starts: under the mouse, or with a stick a little ahead of him.
func _aim_start() -> Vector3:
	var at := _ground_under_mouse() if _mouse_aims else Vector3.INF
	return at if at != Vector3.INF else global_position + Pixel.ground(facing * 3.0)

func _ground_under_mouse() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if absf(dir.y) < 0.001:
		return Vector3.INF
	if Hills.on:
		return Hills.on_ray(from, dir)
	var at := from + dir * (-from.y / dir.y)
	return Vector3(at.x, 0.0, at.z)

# He comes down short of where he chose, so the hammer's head reaches it, or as near as there's room: neither he nor the head inside a wall. facing is the way he'll swing.
func _landing(want: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var stand := FxHammerAura.feet_for(want, facing.x)
	var way := stand - global_position
	way.y = 0.0
	var steps := int(way.length() / 0.25) + 1
	for i in steps + 1:
		var at := stand - way * (float(i) / steps)
		at.y = Hills.height_at(at.x, at.z) if Hills.on else global_position.y
		if _clear(space, at) and _clear(space, FxHammerAura.head_from(at, facing.x)):
			return at
	return global_position

func _clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	for off: Vector3 in [Vector3.ZERO, Vector3(LEAP_CLEAR, 0, 0), Vector3(-LEAP_CLEAR, 0, 0), Vector3(0, 0, LEAP_CLEAR), Vector3(0, 0, -LEAP_CLEAR)]:
		q.position = at + off + Vector3.UP
		if not space.intersect_point(q, 1).is_empty():
			return false
	return true

# Seconds until a slot's skill can be used again. Any skill in Journey.ABILITIES with a "cooldown" gets this, and its icon on the HUD.
func ability_left(slot: StringName) -> float:
	return 0.0 if Dev.no_cooldowns else maxf(float(_ready_at.get(skill_on(slot), 0.0)) - _clock, 0.0)

# How much of a slot's cooldown is left, 0 to 1, for the HUD.
func ability_wait(slot: StringName) -> float:
	var skill := skill_on(slot)
	if skill == "" or not Journey.ABILITIES.has(skill):
		return 0.0
	return clampf(ability_left(slot) / float(Journey.ABILITIES[skill]["cooldown"]), 0.0, 1.0)

func _tick_ability(delta: float) -> void:
	var land := float(_ability["land"])
	if _t < land:
		var at := _leap_from.lerp(_leap_to, _t / land)
		global_position = Vector3(at.x, global_position.y, at.z)
		_vel = Vector2.ZERO
		sprite.position.y = sin(PI * _t / land) * LEAP_HIGH
	else:
		_brake(delta)
		sprite.position.y = 0.0
		if not _landed:
			_landed = true
			hurtbox.invulnerable = false
			global_position = Vector3(_leap_to.x, global_position.y, _leap_to.z)
			collision_mask = _leap_mask
			var info := HitInfo.new()
			info.damage = float(_ability["damage"]) * Journey.sword_scale()
			info.poise = info.damage * HEAVY_POISE
			if Journey.hammer_upgraded:    # it bites harder, and only that
				info.damage = float(_ability["fire_damage"]) * Journey.sword_scale()
			info.knockback = 7.0 * 7.0 / (2.0 * KNOCK_DECEL)
			info.heavy = true
			info.source = self
			info.at = _head_at
			info.blast = true
			var blow := Fx.spawn(&"hammer_blow", _head_at, Vector3.ZERO, Hitbox.TEAM_PLAYER, info) as FxEffect
			blow.hitbox.landed.connect(_on_hammer_landed)
			if is_instance_valid(_aura):
				_aura.strike()
			Feel.hit_stop(0.1)
			Feel.shake(4.0, 0.3)
	if _t >= float(_ability["time"]):
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
			elif _is_vulcan():
				sprite.restart("charge", facing)
	elif not held:
		_charge_scale = lerpf(1.0, MAX_CHARGE_SCALE, clampf((_t - HOLD) / FULL_CHARGE, 0.0, 1.0))
		_enter(State.THRUST)

# Only a blow its striker marked parryable (a sword or teeth, never fire, a blast or a burn), from someone in front of him.
func _can_parry(info: HitInfo) -> bool:
	if not info.parryable or info.blast or not is_instance_valid(info.source):
		return false
	var to := info.source.global_position - global_position
	return Vector2(to.x, to.z).normalized().dot(facing) >= 0.0

# Turned aside: no damage, the fight's biggest hit-stop, a flash, sparks where they met, and a big poise hit on whoever struck.
func _deflect(info: HitInfo) -> void:
	_caught = true
	_t = PARRY_WINDOW    # the window shuts: one catch per press
	var away := global_position - info.source.global_position
	away.y = 0.0
	if away.length() > 0.001:
		_push = away.normalized() * sqrt(2.0 * KNOCK_DECEL * PARRY_SKID)
	sprite.flash(0.08)
	Fx.spawn(&"sparks", (global_position + info.source.global_position) / 2.0 + Vector3.UP * FxSlash.CHEST)
	Feel.hit_stop(PARRY_STOP)
	Feel.shake(2.0, 0.15)
	var foe := info.source as Actor
	if foe:
		foe.wear_poise(PARRY_POISE)
	parried.emit(info)

# Given a weapon or left without one, from the inventory: it's in his hand at once.
func set_weapon(on: bool) -> void:
	has_weapon = on
	spear_out = on
	sprite.restart(_look("idle"), facing)

# What he wears changes how much he can take.
func wear_gear() -> void:
	health.set_max(MAX_HEALTH + Journey.gear_bonus("health"))
	stamina.set_max(MAX_STAMINA + Journey.gear_bonus("stamina"))

# Human Vulcan has a real run. Elvis's run is the one he's always had, played faster.
func _has_run() -> bool:
	return _is_vulcan()

func _is_vulcan() -> bool:
	return character.begins_with("vulcan")

# With the spear out every move but the attacks (their sheets always have it) has its own sheet; it runs at any speed.
func _look(anim: String) -> String:
	if anim == "sprint" and _has_run():
		return "sprint_spear" if spear_out else "sprint"
	if not spear_out:
		return anim
	return ("run" if anim in ["walk", "sprint"] else anim) + "_spear"

func _tick_drink(delta: float) -> void:
	_vel = _vel.move_toward(_input * RUN_SPEED * DRINK_WALK, (ACCEL if _input != Vector2.ZERO else DECEL) * delta)
	var look := _to_target() if _locked() else _input
	if look != Vector2.ZERO:
		facing = Vector2.from_angle(rotate_toward(facing.angle(), look.angle(), deg_to_rad(TURN_RATE) * delta))
	sprite.swap_timed(_look("drink_walk" if _input != Vector2.ZERO else "drink"), facing, DRINK_TIME)
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
	info.damage = float(_attack["damage"]) * (_charge_scale if state == State.THRUST else 1.0) * Journey.sword_scale()
	info.poise = info.damage * (HEAVY_POISE if info.heavy else 1.0)
	var push: float = _attack["push"]
	info.knockback = push * push / (2.0 * KNOCK_DECEL)    # how far Unreal's push slides at Unreal's braking
	info.source = self
	info.at = hitbox.global_position
	return info

# Its mark in the air as the blow's hit window opens: a straight stab for the lunge and the thrust, an arc for a light, each light sweeping the other way.
# A sheet with its own trail keeps it: only light 4 still draws, its bigger arc going round the drawn one the same way. Vulcan's sheets name the way their blade cuts, and the mark follows it.
func _mark_swing() -> void:
	var stab := state != State.LIGHT
	var last := combo_index == combo_max
	if sprite.draws_trail() and not stab and not last:
		return
	var mark := Fx.spawn(&"slash", global_position) as FxSlash
	var way := 1 if combo_index % 2 == 1 else -1
	if sprite.cut_arc().is_empty():
		mark.swing(self, facing, way, last, stab, FxSlash.STEEL if _is_vulcan() else FxSlash.ICE)
	else:
		mark.cut(sprite, way, last, stab, FxSlash.STEEL)

# The shake runs in real time and the hit-stop takes the first 0.07 s of it, so a light hit's has to outlast that to be felt with the world moving. Times are Claude's call.
func _on_landed(target: Hurtbox, info: HitInfo) -> void:
	Feel.hit_stop(0.09 if info.heavy else 0.07)
	var foe := target.get_parent() as Actor
	if info.heavy:
		Feel.shake(3.0, 0.2)
	elif foe and foe.health.ratio() <= 0.0:
		Feel.shake(2.0, 0.2)    # a kill
	else:
		Feel.shake(1.0, 0.18)
	if state != State.LIGHT or combo_index == combo_max:
		_speed_lines(target.global_position + Vector3.UP * FxSlash.CHEST)

func _on_hammer_landed(_target: Hurtbox, _info: HitInfo) -> void:
	_speed_lines(_head_at + Vector3.UP * FxSlash.CHEST)

# Out from where a finisher struck, once for a blow however many it hits.
func _speed_lines(at: Vector3) -> void:
	if not _lined:
		_lined = true
		Fx.spawn(&"speed_lines", at)

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

# The mouse: a left click on an enemy locks on to it, and the click still swings. Middle click or the stick lets go.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_aims = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_mouse_aims = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and input_enabled and state != State.DEAD and not Dev.open:
		_lock_at(get_viewport().get_mouse_position())

func _lock_at(mouse: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var best := CLICK_REACH
	for n in get_tree().get_nodes_in_group(&"actors"):
		var a := n as Actor
		if a and a != self and a.hurtbox.team != hurtbox.team and a.health.ratio() > 0.0:
			var d := cam.unproject_position(a.global_position + Vector3.UP * 0.7).distance_to(mouse)
			if d < best:
				best = d
				lock_target = a

func _locked() -> bool:
	if not is_instance_valid(lock_target) or (lock_target is Actor and (lock_target as Actor).health.ratio() <= 0.0):
		lock_target = null
	return lock_target != null

func _to_target() -> Vector2:
	var d := lock_target.global_position - global_position
	return Vector2(d.x, d.z).normalized()
