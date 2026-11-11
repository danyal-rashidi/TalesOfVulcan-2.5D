class_name Jackal extends Actor
# A desert jackal: it lopes at its target, stops to bite and backs off a moment. Asleep (gnawing at whatever it's by) until wake().

signal dead

const HP := 24.0               # Claude's call: three light hits
const SPEED := 4.2             # Claude's call: slower than his run, so he can break away
const BITE_RANGE := 1.3        # Claude's call
const WINDUP := 0.4            # Claude's call: long enough to see and roll
const ACTIVE := 0.15
const RECOVER := 0.8
const DAMAGE := 7.0            # Claude's call
const PUSH := 1.5              # m/s, as Elvis.ATTACKS' push
const BURN_TIME := 0.5
const POISE := 30.0            # Claude's call: more than its 24 hp of light hits, so hits alone rarely break one before it dies; one parry (Elvis.PARRY_POISE 35) does

enum Mode {SLEEP, CHASE, WINDUP, BITE, RECOVER, DEAD}

@onready var hitbox: Hitbox = $Hitbox

var bar_up := 1.6        # m above its feet that Hud draws its health bar
var folder := "jackal"   # the same hunter in another body: a scorpion or a raider
var run_key := "run"
var bite_key := "bite"
var hp := HP
var speed := SPEED       # as its legs look right: a scorpion scuttles, a raider runs
var target: Node3D
var mode := Mode.SLEEP
var _t := 0.0

func _ready() -> void:
	super()
	add_to_group(&"enemies")
	health.max_hp = hp
	health.reset()
	health.died.connect(_die)
	poise_max = POISE
	reset_poise()
	sprite.load_character(folder)
	sprite.play("idle", facing)

func wake(at: Node3D) -> void:
	target = at
	mode = Mode.CHASE

func take_hit(info: HitInfo) -> void:
	super(info)
	if mode == Mode.SLEEP and is_instance_valid(info.source):
		wake(info.source)

func _tick(delta: float) -> void:
	_t += delta
	if broken > 0.0:    # staggered: it stands, open, and can't bite
		_slide(Vector3.ZERO, delta)
		return
	var v := Vector3.ZERO
	match mode:
		Mode.CHASE:
			if not is_instance_valid(target):
				mode = Mode.SLEEP
			else:
				var to := target.global_position - global_position
				to.y = 0.0
				if to.length() > 0.01:
					facing = Vector2(to.x, to.z).normalized()
				if to.length() <= BITE_RANGE:
					_to(Mode.WINDUP)
					sprite.play_timed(bite_key, facing, WINDUP + ACTIVE + RECOVER)
				else:
					v = to.normalized() * speed
					sprite.play(run_key, facing)
		Mode.WINDUP:
			if _t >= WINDUP:
				_to(Mode.BITE)
				hitbox.position = Vector3(facing.x * 0.8, 0.5 + Hills.rise(global_position, facing * 0.8), facing.y * 0.8)
				hitbox.activate(_bite(), ACTIVE)
				v = Vector3(facing.x, 0.0, facing.y) * speed
		Mode.BITE:
			v = Vector3(facing.x, 0.0, facing.y) * speed
			if _t >= ACTIVE:
				_to(Mode.RECOVER)
		Mode.RECOVER:
			if _t >= RECOVER:
				_to(Mode.CHASE)
		Mode.SLEEP:
			sprite.play("idle", facing)
	_slide(v, delta)

# Broken: the bite stops and it stands; after the break it comes straight back. Asleep, it stays so for take_hit to wake it.
func _stagger() -> void:
	hitbox.deactivate()
	sprite.play("idle", facing)
	if mode != Mode.SLEEP:
		_to(Mode.CHASE)

func _to(m: Mode) -> void:
	mode = m
	_t = 0.0

func _bite() -> HitInfo:
	var info := HitInfo.new()
	info.damage = DAMAGE
	info.poise = DAMAGE
	info.knockback = PUSH * PUSH / (2.0 * KNOCK_DECEL)
	info.source = self
	info.at = global_position
	info.parryable = true
	return info

func _die() -> void:
	mode = Mode.DEAD
	scripted = true
	hurtbox.invulnerable = true
	hitbox.deactivate()
	dead.emit()
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: sprite.set_param(&"burn", x), 0.0, 1.0, BURN_TIME)
	tw.tween_callback(queue_free)
