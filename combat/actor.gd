class_name Actor extends CharacterBody3D
# A character on the ground: children Health, Hurtbox and Sprite (a CharacterSprite). Hits flash it and knock it back.
# Subclasses act in _tick(); cutscenes walk it with move_to() or set `scripted` to stop _tick() altogether. play_once() also stops it while it plays.

signal arrived

const KNOCK_DECEL := 20.0    # m/s², how knockback is braked: Unreal BrakingDecelerationWalking 2000 cm/s² (TalesOfVulkanCharacter.cpp)

@onready var sprite: CharacterSprite = $Sprite
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
var facing := Vector2.DOWN
var scripted := false

var _push := Vector3.ZERO    # knockback velocity, braked to zero
var _goal := Vector3.ZERO
var _goal_speed := 0.0       # > 0 while walking to a move_to point
var _once := 0              # play_once() calls still waiting for `finished`

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING    # top-down: no gravity or floor needed
	hurtbox.hurt.connect(take_hit)
	add_to_group(&"actors")

# Walks there at `speed` playing "walk"; `arrived` follows on a later physics frame.
func move_to(at: Vector3, speed: float) -> void:
	_goal = at
	_goal_speed = maxf(speed, 0.01)

# Holds _tick() off while it plays (as `scripted` does), or _tick()'s own play() would replace the one-shot and `finished` never come.
func play_once(anim: String) -> void:
	_once += 1
	sprite.play_timed(anim, facing, 0.0)
	await sprite.finished
	_once -= 1

# A blow landed on the Hurtbox: damage, the white flash and the knockback. Subclasses add their reaction.
func take_hit(info: HitInfo) -> void:
	health.take(info.damage)
	sprite.flash(0.08)
	var from := info.source.global_position if is_instance_valid(info.source) else info.at
	var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
	if away.length() > 0.001 and info.knockback > 0.0:
		_push = away.normalized() * sqrt(2.0 * KNOCK_DECEL * info.knockback)    # slides exactly info.knockback m

func _physics_process(delta: float) -> void:
	if _goal_speed > 0.0:
		_walk(delta)
	elif not scripted and _once == 0:
		_tick(delta)
	else:
		_slide(Vector3.ZERO, delta)

func _tick(delta: float) -> void:
	_slide(Vector3.ZERO, delta)
	sprite.play("idle", facing)

# Moves with velocity v plus whatever knockback is left.
func _slide(v: Vector3, delta: float) -> void:
	_push = _push.move_toward(Vector3.ZERO, KNOCK_DECEL * delta)
	velocity = v + _push
	move_and_slide()

func _walk(delta: float) -> void:
	var d := Vector3(_goal.x - global_position.x, 0.0, _goal.z - global_position.z)
	if d.length() <= _goal_speed * delta:
		global_position = Vector3(_goal.x, global_position.y, _goal.z)
		velocity = Vector3.ZERO
		_goal_speed = 0.0
		sprite.play("idle", facing)
		arrived.emit()
		return
	facing = Vector2(d.x, d.z).normalized()
	sprite.play("walk", facing)
	_slide(d.normalized() * _goal_speed, delta)
