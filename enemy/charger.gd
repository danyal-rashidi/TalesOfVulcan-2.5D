extends Jackal
# A charger, on the jackal's body: it pulls up short, a red line lies along its path, then it runs that line without turning.
# Step off the line, or parry the dash (it breaks); after a miss it stands open. No class_name: put on jackal.tscn with set_script() before it enters the tree.
# Jackal.Mode is reused: WINDUP is the warning, BITE the dash, RECOVER the opening.

const STOP := 5.0          # m: it pulls up this far off and aims. Claude's call
const WARN := 0.7          # s the line lies on the ground before it goes. Claude's call
const LINE_FORMS := 0.2    # s the line takes to draw: whole for the last 0.5 s. Claude's call
const LINE_WIDTH := 1.1    # m to each side at its feet: the strip tapers (fx/ground_fire.gdshader) to the hitbox's 0.6 m at STOP, where he stands. Claude's call
const DASH_SPEED := 11.0   # m/s. Claude's call: faster than his run, so he sidesteps or parries, not outruns
const DASH_TIME := 0.6     # s: 6.6 m, through where he stood and past. Claude's call
const OPEN := 1.2          # s it stands open after the dash. Claude's call: about two light swings
const DASH_DAMAGE := 12.0  # Claude's call: nearly two bites
const DASH_PUSH := 3.0     # m/s. Claude's call

var _mark: FxTelegraph

func _tick(delta: float) -> void:
	if broken > 0.0 or mode == Mode.SLEEP:    # the jackal's own: it stands while broken, idles asleep
		super(delta)
		return
	_t += delta
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
				if to.length() <= STOP:
					_to(Mode.WINDUP)
					sprite.play("idle", facing)
					_mark = Fx.spawn(&"telegraph", global_position, Vector3(facing.x, 0.0, facing.y)) as FxTelegraph    # the boss's charge strip
					_mark.mark(0, DASH_SPEED * DASH_TIME, LINE_WIDTH, LINE_FORMS)
				else:
					v = to.normalized() * speed
					sprite.play(run_key, facing)
		Mode.WINDUP:    # facing is set once, above: the dash can't turn
			if is_instance_valid(_mark):
				_mark.global_position = global_position    # a shove moves the line with it
			if _t >= WARN:
				_to(Mode.BITE)
				_end_mark()
				hitbox.position = Vector3(facing.x * 0.5, 0.5 + Hills.rise(global_position, facing * 0.5), facing.y * 0.5)
				hitbox.activate(_bite(), DASH_TIME)
				sprite.play(run_key, facing)
		Mode.BITE:
			v = Vector3(facing.x, 0.0, facing.y) * DASH_SPEED
			if _t >= DASH_TIME:
				hitbox.deactivate()
				_to(Mode.RECOVER)
				sprite.play("idle", facing)
		Mode.RECOVER:
			if _t >= OPEN:
				_to(Mode.CHASE)
	_slide(v, delta)

func _bite() -> HitInfo:
	var info := super()
	info.damage = DASH_DAMAGE
	info.poise = DASH_DAMAGE
	info.knockback = DASH_PUSH * DASH_PUSH / (2.0 * KNOCK_DECEL)
	return info

func _stagger() -> void:
	_end_mark()
	super()

func _die() -> void:
	_end_mark()
	super()

# Freed mid-warning (the road unloads): the line must not lie on in the next place.
func _exit_tree() -> void:
	_end_mark()

func _end_mark() -> void:
	if is_instance_valid(_mark):
		_mark.end()
	_mark = null
