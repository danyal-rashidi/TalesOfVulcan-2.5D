class_name Actor extends CharacterBody3D
# A character on the ground: children Health, Hurtbox and Sprite (a CharacterSprite). Hits flash it and knock it back.
# Subclasses act in _tick(); cutscenes walk it with move_to() or set `scripted` to stop _tick() altogether. play_once() also stops it while it plays.

signal arrived

const KNOCK_DECEL := 20.0    # m/s², how knockback is braked: Unreal BrakingDecelerationWalking 2000 cm/s² (TalesOfVulkanCharacter.cpp)
const SLOW_PACE := 0.5       # a slowed actor moves, attacks and animates at this much of its speed. Claude's call

@onready var sprite: CharacterSprite = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
var facing := Vector2.DOWN
var scripted := false
var walk_pace := 3.0         # m/s the walk sheet is drawn for
var slow_left := 0.0         # seconds of slow left, in game time whatever it's doing
var pace := 1.0              # 1, or SLOW_PACE while slowed: everything it does runs on delta x this, so moves, attacks and sheets stay in step

var _push := Vector3.ZERO    # knockback velocity, braked to zero
var _goal := Vector3.ZERO
var _goal_speed := 0.0       # > 0 while walking to a move_to point
var _then: Array[Vector3] = []    # the points after it
var _once := 0              # play_once() calls still waiting for `finished`

# Drawn between physics ticks (the Sprite reads the interpolated position), so on a 144 Hz screen it moves every frame, not 60 times a second.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING    # top-down: no gravity or floor needed
	axis_lock_linear_y = true    # sliding never changes his height, since nothing would bring it back. Setting global_position still does: the boss's dive and hop
	hurtbox.hurt.connect(_chill)    # first: a blow that kills or starts a new phase ends the slow it brought
	hurtbox.hurt.connect(take_hit)
	health.died.connect(end_slow)
	add_to_group(&"actors")
	add_child(Steps.new())

# Walks there at `speed` playing "walk", and on through `then` without stopping; `arrived` follows on a later physics frame.
func move_to(at: Vector3, speed: float, then: Array[Vector3] = []) -> void:
	_goal = at
	_goal_speed = maxf(speed, 0.01)
	_then = then

# Holds _tick() off while it plays (as `scripted` does), or _tick()'s own play() would replace the one-shot and `finished` never come.
func play_once(anim: String) -> void:
	_once += 1
	sprite.play_timed(anim, facing, 0.0)
	await sprite.finished
	_once -= 1

# A blow landed on the Hurtbox: damage, the white flash and the knockback. Subclasses add their reaction.
func take_hit(info: HitInfo) -> void:
	var from := info.source.global_position if is_instance_valid(info.source) and not info.blast else info.at
	var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
	if away.length() > 0.001 and info.knockback > 0.0:
		_push = away.normalized() * sqrt(2.0 * KNOCK_DECEL * info.knockback)    # slides exactly info.knockback m
	_lose_health(info)    # after the push: its number has to clear the slide
	sprite.flash(0.08)

# The blow's damage, and its number over the head if it really cost any health: nothing for 0 damage or the already dead.
func _lose_health(info: HitInfo) -> void:
	var was := health.hp
	health.take(info.damage)
	if health.hp < was:
		var up: float = get("bar_up") if get("bar_up") != null else 2.6    # just over its health bar or its head, as Hud's lock mark
		var at := global_position + Vector3.UP * up
		if is_in_group(&"enemies") and health.ratio() > 0.0:    # it has a bar, which Hud draws over all of the 3D: start over where a slide north ends, or the bar rides up across the number
			at.z += minf(_push.z, 0.0) * _push.length() / (2.0 * KNOCK_DECEL)
		Fx.spawn(&"number", at, Vector3.ZERO, hurtbox.team, info)

func _physics_process(delta: float) -> void:
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			end_slow()
	var dt := delta * pace
	if _goal_speed > 0.0:
		_walk(dt)
	elif not scripted and _once == 0:
		_tick(dt)
	else:
		_slide(Vector3.ZERO, dt)

# A blow that slows: fresh frost starts its time again, it doesn't add up. It shows on the sprite for exactly as long.
func _chill(info: HitInfo) -> void:
	if info.slow > 0.0 and health.ratio() > 0.0:
		slow_left = info.slow
		pace = SLOW_PACE
		sprite.pace = SLOW_PACE
		sprite.set_param(&"frost", 1.0)

func end_slow() -> void:
	slow_left = 0.0
	pace = 1.0
	sprite.pace = 1.0
	sprite.set_param(&"frost", 0.0)

func _tick(delta: float) -> void:
	_slide(Vector3.ZERO, delta)
	sprite.play(_look("idle"), facing)

# The sheet for a move: a subclass may have more than one look of it.
func _look(anim: String) -> String:
	return anim

# Moves with velocity v plus whatever knockback is left.
func _slide(v: Vector3, delta: float) -> void:
	_push = _push.move_toward(Vector3.ZERO, KNOCK_DECEL * delta / pace)    # a push is the blow's, not its legs': it slides as far when slowed
	velocity = v * pace + _push
	move_and_slide()
	_stand()

# On the ground, where there are hills. Where there are none his height is left alone: the boss's dive and hop raise his body.
func _stand() -> void:
	if Hills.on:
		global_position.y = Hills.height_at(global_position.x, global_position.z)

func _walk(delta: float) -> void:
	var d := Vector3(_goal.x - global_position.x, 0.0, _goal.z - global_position.z)
	if d.length() <= _goal_speed * delta:
		global_position = Vector3(_goal.x, global_position.y, _goal.z)
		_stand()
		if not _then.is_empty():    # through a corner without a frame of idle
			_goal = _then.pop_front()
			return
		velocity = Vector3.ZERO
		_goal_speed = 0.0
		sprite.speed_scale = 1.0
		sprite.play(_look("idle"), facing)
		arrived.emit()
		return
	facing = Vector2(d.x, d.z).normalized()
	sprite.speed_scale = clampf(_goal_speed / walk_pace, 0.35, 3.0)    # his feet keep up with the ground
	sprite.play(_look("walk"), facing)
	_slide(d.normalized() * _goal_speed, delta)
