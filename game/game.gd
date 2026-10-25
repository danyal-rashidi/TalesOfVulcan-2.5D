class_name Game extends Node3D
# The colosseum snippet from start to end. ENTER: Elvis comes in at the breach. Within WAKE_DISTANCE of the statue, C1 wakes Vulcan
# (WAKE), then the FIGHT, with "Strike the crown." at phase two. Once he kneels, a heavy blow strikes the crown and C3 unmasks him
# (UNMASK), ending on the title card (END). If Elvis dies in the fight: a fade, restart_fight(), a fade back; C1 never plays again.
# Screenshot runs (ShotDriver bot=...): fight (the Bot plays it), unmask (the Bot plays it from the kneel on). The earlier tasks' runs
# skip the flow: moves (lock on, the light combo, a charged thrust, a roll, on a training dummy), calm|storm|blood|clear (that mood),
# fx (every effect frozen at its height), boss (Vulcan wakes at once to fight you), slam|spell|breath|dive (that move frozen late in
# its wind-up, its mark on the floor, Elvis untouchable 5 m off).

enum Flow {ENTER, WAKE, FIGHT, UNMASK, END}

signal flow_changed(flow: Flow)

const WAKE_DISTANCE := 12.0    # STORY.md prologue step 3: the statue wakes when Elvis comes within 12 m
const FAST := 0.05             # the plan: in fast mode every cutscene wait is x0.05
const DEATH_BEAT := 1.2        # Claude's call: s of his death before the fade
const DEATH_FADE := 0.8        # Claude's call: s to black, and back
const LEAD_RUN := 0.75         # Claude's call: m the camera runs ahead of Elvis at his run speed (the spec's "slight lead")
const LEAD_LOCK := 0.25        # Claude's call: locked on, it leans this much of the way toward his target
const LEAD_MAX := 2.0          # m
const LEAD_RATE := 2.5         # 1/s: how quickly the lead swings round

const DUMMY := preload("res://combat/dummy.tscn")
const FREEZE_AT := 0.8    # bot=<move>: the game stops this far into the move's wind-up
const MOVES := [    # bot=moves: [physics frame, action, pressed]
	[5, &"lock_on", true], [6, &"lock_on", false],
	[20, &"attack_light", true], [21, &"attack_light", false], [40, &"attack_light", true], [41, &"attack_light", false],
	[60, &"attack_light", true], [61, &"attack_light", false], [80, &"attack_light", true], [81, &"attack_light", false],
	[125, &"attack_heavy", true], [175, &"attack_heavy", false],
	[214, &"move_left", true], [215, &"roll", true], [216, &"roll", false], [240, &"move_left", false],
]
const SHOW_AT := 1.5    # bot=fx: the game pauses here, every effect at its height, for the screenshot
const SHOW_FX := [    # [seconds before SHOW_AT, kind, at, dir]
	[0.03, &"lightning", Vector3(-8.0, 0, -3.0), Vector3.ZERO],
	[0.2, &"statue_burst", Vector3(-4.5, 0, -3.0), Vector3.ZERO],
	[0.12, &"flame_summon", Vector3(-0.5, 1.4, -3.0), Vector3.ZERO],
	[1.15, &"crown_glow", Vector3(3.0, 1.8, -3.0), Vector3.ZERO],
	[0.5, &"crown_light", Vector3(4.5, 1.0, -3.0), Vector3.RIGHT],
	[0.3, &"fire_blade", Vector3(-9.5, 0, 0.6), Vector3.RIGHT],
	[0.6, &"breath", Vector3(2.2, 0, 0.6), Vector3.RIGHT],
	[0.9, &"spell_circle", Vector3(-7.0, 0, 4.0), Vector3.ZERO],
	[0.3, &"fireball", Vector3(-7.0, 1.0, 4.0), Vector3.RIGHT],
	[0.12, &"dive_impact", Vector3(0.0, 0, 4.2), Vector3.ZERO],
	[0.06, &"sparks", Vector3(4.5, 0.8, 4.0), Vector3.ZERO],
	[0.5, &"embers", Vector3(7.5, 0.3, 4.0), Vector3.ZERO],
	[0.2, &"dust", Vector3(-3.0, 0, 7.0), Vector3.ZERO],
	[1.5, &"ash", Vector3(3.5, 0, 7.0), Vector3.ZERO],    # off the dummy, as off Vulcan's armour
]
const OLD_RUNS := ["moves", "fx", "calm", "storm", "blood", "clear", "boss", "slam", "spell", "breath", "dive"]

var flow: Flow = Flow.ENTER
var fast: bool = ShotDriver.fast
var restarts := 0

@onready var arena: Arena = $Arena
@onready var elvis: Elvis = $Elvis
@onready var vulcan: Vulcan = $Vulcan
@onready var camera: PixelCamera = $Camera
@onready var hud: Hud = $Hud

var _restarting := false
var _old_run: bool = ShotDriver.bot in OLD_RUNS
var _frame := 0
var _t := 0.0
var _windup := 0.0
var _lead := Vector3.ZERO

# Physics interpolation is on for the Actors only (Actor._init): everything else here snaps itself to the grid, which drawing between
# ticks would undo.
func _init() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _ready() -> void:
	vulcan.arena = arena
	vulcan.fast = fast
	hud.fast = fast
	elvis.global_position = arena.entrance()
	elvis.facing = Vector2.UP
	elvis.stamina.in_combat = false    # out of combat until the fight: stamina refills 3x as fast (STORY.md)
	vulcan.global_position = arena.plinth()
	elvis.reset_physics_interpolation()
	vulcan.reset_physics_interpolation()
	camera.follow(elvis)
	hud.bind(elvis, vulcan)
	hud.show_boss_bar(false)
	vulcan.phase_two.connect(hud.say.bind("Vulcan", "Strike the crown."))
	vulcan.crown_struck.connect(_unmask)    # Vulcan only emits it while he kneels
	elvis.health.died.connect(_on_elvis_died)
	hud.restart_requested.connect(_on_restart_requested)
	if ShotDriver.bot in ["fight", "unmask"]:
		add_child(Bot.new())
	elif _old_run:
		_old_ready()

# Seconds as the cutscenes wait them: x FAST in fast mode.
func scaled(seconds: float) -> float:
	return seconds * (FAST if fast else 1.0)

# Waits scaled(seconds) of game time: a tween of the Game's, so pausing stops it and freeing the Game drops it.
func wait(seconds: float) -> void:
	await create_tween().tween_interval(scaled(seconds)).finished

# Elvis full at the entrance, Vulcan full and awake in front of the plinth, no effects or cracks, the blood sun, the HUD rebound.
func restart_fight() -> void:
	restarts += 1
	Fx.clear_all()
	arena.clear_cracks()
	arena.set_mood(&"blood", 0.0)
	vulcan.reset_fight(arena.plinth())
	elvis.reset_to(arena.entrance())
	elvis.input_enabled = true
	camera.follow(elvis)
	hud.bind(elvis, vulcan)
	hud.show_boss_bar(true)
	_set_flow(Flow.FIGHT)

# The camera's lead: toward where Elvis runs, or toward his lock target; eased, and in whole pixels.
func _process(delta: float) -> void:
	var want := elvis.velocity / Elvis.RUN_SPEED * LEAD_RUN
	if is_instance_valid(elvis.lock_target):
		want = (elvis.lock_target.global_position - elvis.global_position) * LEAD_LOCK
	want.y = 0.0
	_lead = _lead.lerp(want.limit_length(LEAD_MAX), 1.0 - exp(-LEAD_RATE * delta))
	camera.lead = Pixel.snap(_lead)

func _physics_process(delta: float) -> void:
	if _old_run:
		_old_tick(delta)
		return
	if flow == Flow.ENTER:
		var d := elvis.global_position - arena.plinth()
		if Vector2(d.x, d.z).length() < WAKE_DISTANCE:
			_wake()

func _wake() -> void:
	_set_flow(Flow.WAKE)
	await C1Wake.run(self)
	_set_flow(Flow.FIGHT)
	vulcan.start_fight(elvis)

func _unmask() -> void:
	if flow != Flow.FIGHT or _restarting:
		return
	_set_flow(Flow.UNMASK)
	await C3Unmasking.run(self)
	_set_flow(Flow.END)

func _on_elvis_died() -> void:
	if flow == Flow.FIGHT:
		_fade_restart(DEATH_BEAT)

func _on_restart_requested() -> void:
	if flow == Flow.FIGHT:
		_fade_restart(0.0)

# Once, however he died and whatever was in flight: everything is reset behind the black.
func _fade_restart(beat: float) -> void:
	if _restarting:
		return
	_restarting = true
	elvis.input_enabled = false
	await wait(beat)
	hud.fade(true, scaled(DEATH_FADE))
	await hud.fade_done
	restart_fight()
	hud.fade(false, scaled(DEATH_FADE))
	await hud.fade_done
	_restarting = false

func _set_flow(f: Flow) -> void:
	if f == flow:
		return
	flow = f
	elvis.stamina.in_combat = f == Flow.FIGHT
	flow_changed.emit(f)

# The earlier tasks' screenshot runs.
func _old_ready() -> void:
	var dummy := DUMMY.instantiate() as Node3D
	dummy.position = arena.entrance() + Vector3(1.6, 0, 0)
	add_child(dummy)
	if ShotDriver.bot == "fx":
		camera.focus(Vector3(0, 0, 1.0), 0.01)
		elvis.position = Vector3(-6.5, 0, 7.0)
		dummy.position = Vector3(3.5, 0, 7.0)
	elif ShotDriver.bot in ["calm", "storm", "blood", "clear"]:
		arena.set_mood(StringName(ShotDriver.bot), 0.0)
		camera.focus(Vector3(0, 0, -5.5), 0.01)
		elvis.position = Vector3(-3.0, 0, 1.0)
		dummy.position = Vector3(3.0, 0, 1.0)
		arena.crack(Vector3(-5.5, 0, -1.5), 1.5)
		arena.crack(Vector3(4.5, 0, -3.5), 1.0)
	elif ShotDriver.bot == "boss" or StringName(ShotDriver.bot) in VulcanBrain.OPENING:
		dummy.queue_free()
		vulcan.reset_fight(arena.plinth())    # on the floor in front of the plinth
		elvis.position = Vector3(0, 0, 7.5)
		hud.show_boss_bar(true)
		if ShotDriver.bot != "boss":
			vulcan.reset_fight(Vector3(-2.5, 0, 3.5))    # clear of the plinth, so the spell's circle behind him shows
			for i in VulcanBrain.OPENING.find(StringName(ShotDriver.bot)):
				vulcan.brain.next_move(5.0)
			elvis.position = Vector3(2.0, 0, 6.5)        # to one side, so his sprite hides less of the mark
			elvis.input_enabled = false
			elvis.hurtbox.invulnerable = true
			camera.focus(Vector3(-0.25, 0, 5.0), 0.01)
		vulcan.start_fight(elvis)

func _old_tick(delta: float) -> void:
	if ShotDriver.bot == "fx":
		for f: Array in SHOW_FX:
			var at: float = SHOW_AT - f[0]
			if _t <= at and at < _t + delta:
				Fx.spawn(f[1], f[2], f[3])
		_t += delta
		if _t >= SHOW_AT:
			Engine.time_scale = 0.0
	if vulcan.mode == Vulcan.Mode.WINDUP and vulcan.move == StringName(ShotDriver.bot):
		_windup += delta
		if _windup >= FREEZE_AT * float(VulcanMoves.MOVES[vulcan.move]["windup"]):
			Engine.time_scale = 0.0
	if ShotDriver.bot != "moves":
		return
	_frame += 1
	for m: Array in MOVES:
		if m[0] == _frame:
			if m[2]:
				Input.action_press(m[1])
			else:
				Input.action_release(m[1])
