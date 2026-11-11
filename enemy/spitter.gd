extends Jackal
# A scorpion that keeps its distance: from SPIT_RANGE it lobs venom at where he stands (enemy/venom.gd: a ring on the ground, then
# the splash). The answer is to roll out of the ring and close on it; up close it stings as any hunter bites.
# No class_name: the spawner puts this on the jackal scene with set_script() before it enters the tree.

const VENOM := preload("res://enemy/venom.gd")
const SPIT_RANGE := 6.0    # m: it spits from here and comes no nearer (it wakes at Cinerea.AGGRO 7.5). Claude's call
const SPIT_EVERY := 2.5    # s between globs: time to close on it. Claude's call
const SPIT_POSE := 0.5     # s the sting clip plays as it throws. Claude's call
const TAIL := 0.8          # m up: the glob leaves the tip of its tail. Claude's call

var _cool := 0.0

func _ready() -> void:
	folder = "scorpion"
	run_key = "walk"
	bite_key = "sting"
	hp = 30.0
	bar_up = 1.3
	speed = 2.4    # all as game/cinerea.gd's scorpions were
	super()

func _tick(delta: float) -> void:
	_cool -= delta
	if mode == Mode.CHASE and broken <= 0.0 and is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > BITE_RANGE and to.length() <= SPIT_RANGE:    # it stands its ground; nearer or farther it is the hunter it was
			facing = Vector2(to.x, to.z).normalized()
			if _cool <= 0.0:
				_cool = SPIT_EVERY
				sprite.play_timed(bite_key, facing, SPIT_POSE)
				var glob := VENOM.new()
				glob.position = global_position + Vector3.UP * TAIL
				glob.to = target.global_position
				Fx.add_child(glob)    # as Fx.spawn() does; it is no kind of Fx's, so a glob in the air still lands once the spitter is broken or dead
			elif _cool < SPIT_EVERY - SPIT_POSE:
				sprite.play("idle", facing)
			_slide(Vector3.ZERO, delta)
			return
	super(delta)
