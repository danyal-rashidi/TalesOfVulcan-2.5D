class_name VulcanBrain extends RefCounted
# Which attack Vulcan makes next. The opening, then a mix by distance: close up the slash (often chained into the backswing),
# at middle range the slam, the breath or a slash, far off the charge, the spell or the dive; never the same big move twice running.
# Unreal: ABossVulcan::ChooseAttack and FinishAttack (BossVulcanBrain.cpp), with the plan's distance bands instead of its weights.

const OPENING: Array[StringName] = [&"slam", &"spell", &"breath", &"dive"]    # his big moves, the first four in order (Unreal's too)
const CLOSE := 3.0
const FAR := 7.0
const CHAIN := 0.5            # a slash is followed by the backswing: SlashChainChance (BossVulcan.h)
const CHAIN_PHASE_TWO := 0.75 # SlashChainChancePhaseTwo
const PHASE_TWO_RATE := 1.35  # PhaseTwoRate: his clips play this much faster in phase two

var phase := 1

var _rng := RandomNumberGenerator.new()
var _seed := 1
var _step := 0               # opening moves made
var _last := &""
var _chain := false          # the last move was a slash that the backswing follows, if he is still close

func _init(seed_: int = 1) -> void:
	_seed = seed_
	reset()

func reset() -> void:
	phase = 1
	_rng.seed = _seed
	_step = 0
	_last = &""
	_chain = false

func next_move(dist: float) -> StringName:
	var m: StringName
	if _step < OPENING.size():
		m = OPENING[_step]
		_step += 1
	elif _chain and dist < CLOSE:
		m = &"backswing"
	else:
		var pick: Array[StringName] = [&"slash"]
		if dist >= FAR:
			pick = [&"charge", &"spell", &"dive"]
		elif dist >= CLOSE:
			pick = [&"slam", &"breath", &"slash"]
		if _last in OPENING:    # the big moves: never twice running
			pick.erase(_last)
		m = pick[_rng.randi_range(0, pick.size() - 1)]
	_chain = m == &"slash" and _rng.randf() < (CHAIN_PHASE_TWO if phase == 2 else CHAIN)
	_last = m
	return m

func speed_scale() -> float:
	return PHASE_TWO_RATE if phase == 2 else 1.0
