class_name Bot extends Node
# Plays Elvis for screenshots (ShotDriver bot=fight; bot=unmask also takes all of Vulcan's health once the fight starts, so the run
# goes on to C3). It walks to Vulcan, locks on, swings light hits, rolls away from his wind-ups within 4 m, below 35% health backs
# off and drinks red whenever he isn't winding up or striking, and uses a heavy when he kneels. It presses the real actions, so
# Elvis plays exactly as he does with a pad.

const CLOSE := 1.6           # m: close enough to swing
const DODGE := 4.0           # the plan: it rolls from wind-ups this close
const ROLL_LEAD := 0.3       # s before his blow: inside the roll's i-frames (0.05-0.40 s)
const RUN_OFF := 0.8         # s it keeps running away after a roll
const DRINK_BELOW := 0.35    # the plan
const SWING_GAP := 0.3       # s between light presses
const HEAVY_GAP := 1.0

var _g: Game
var _taps: Array[StringName] = []    # pressed last frame, released this one
var _gap := 0.0
var _windup := 0.0
var _rolled := false
var _away := 0.0
var _drained := false

func _ready() -> void:
	process_physics_priority = -1    # before Elvis, so he reads its presses in the same physics frame
	_g = get_parent() as Game

func _physics_process(delta: float) -> void:
	for a in _taps:
		Input.action_release(a)
	_taps.clear()
	var e := _g.elvis
	var v := _g.vulcan
	if _g.flow != Game.Flow.FIGHT or not e.input_enabled:
		_steer(Vector2.ZERO)
		return
	if ShotDriver.bot == "unmask" and not _drained:
		_drained = true
		v.health.take(v.health.max_hp)
	var to := Vector2(v.global_position.x - e.global_position.x, v.global_position.z - e.global_position.z)
	var dist := to.length()
	_gap -= delta
	_away -= delta
	if v.mode == Vulcan.Mode.WINDUP:
		_windup += delta
	else:
		_windup = 0.0
		_rolled = false
	if e.lock_target == null and dist < Elvis.LOCK_RANGE:
		_tap(&"lock_on")
	if v.kneeling:
		_steer(to if dist > CLOSE else Vector2.ZERO)
		if dist <= CLOSE and _gap <= 0.0:
			_tap(&"attack_heavy")
			_gap = HEAVY_GAP
		return
	var strike := float(VulcanMoves.MOVES[v.move]["windup"]) / v.brain.speed_scale() if v.move != &"" else INF
	if v.mode == Vulcan.Mode.WINDUP and dist < DODGE and not _rolled and _windup >= strike - ROLL_LEAD:
		_rolled = true
		_away = RUN_OFF
		_steer(-to)
		_tap(&"roll")
	elif _away > 0.0:
		_steer(-to)
	elif e.health.ratio() < DRINK_BELOW and e.flasks.red > 0:
		_steer(-to)
		# he outruns Elvis, so it can't wait for a gap: it drinks while he isn't winding up or striking (mostly just after a roll).
		# Spaced presses: pressed every frame (released and pressed again in one frame) the drink started up to 0.65 s late.
		if e.state == Elvis.State.MOVE and v.mode != Vulcan.Mode.WINDUP and v.mode != Vulcan.Mode.ACTIVE and _gap <= 0.0:
			_tap(&"flask_red")
			_gap = SWING_GAP
	elif dist > CLOSE:
		_steer(to)
	else:
		_steer(Vector2.ZERO)
		if _gap <= 0.0:
			_tap(&"attack_light")
			_gap = SWING_GAP

func _tap(a: StringName) -> void:
	Input.action_press(a)
	_taps.append(a)

# The left stick pushed toward `dir` (zero lets go).
func _steer(dir: Vector2) -> void:
	var d := dir.normalized()
	for pair: Array in [[&"move_right", d.x], [&"move_left", -d.x], [&"move_down", d.y], [&"move_up", -d.y]]:
		var s: float = pair[1]
		if s > 0.0:
			Input.action_press(pair[0], s)
		else:
			Input.action_release(pair[0])
