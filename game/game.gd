extends Node3D
# Placeholder until Vulcan (Task 4) and the game flow (Task 5): the arena, Elvis at its entrance and a training dummy beside him,
# followed by the PixelCamera. bot=moves plays a fixed sequence for screenshots: lock on, the light combo, a charged thrust, a roll.
# bot=calm|storm|blood|clear shows the arena in that mood, and bot=fx every effect at its height at SHOW_AT s (Task 3's screenshots).

const ELVIS := preload("res://player/elvis.tscn")
const DUMMY := preload("res://combat/dummy.tscn")
const MOVES := [    # [physics frame, action, pressed]
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

@onready var arena: Arena = $Arena
var _frame := 0
var _t := 0.0

func _ready() -> void:
	var elvis := ELVIS.instantiate() as Elvis
	elvis.position = arena.entrance()
	add_child(elvis)
	var dummy := DUMMY.instantiate() as Node3D
	dummy.position = arena.entrance() + Vector3(1.6, 0, 0)
	add_child(dummy)
	var cam := PixelCamera.new()
	add_child(cam)
	cam.follow(elvis)
	if ShotDriver.bot == "fx":
		cam.focus(Vector3(0, 0, 1.0), 0.01)
		elvis.position = Vector3(-6.5, 0, 7.0)
		dummy.position = Vector3(3.5, 0, 7.0)
	elif ShotDriver.bot in ["calm", "storm", "blood", "clear"]:
		arena.set_mood(StringName(ShotDriver.bot), 0.0)
		cam.focus(Vector3(0, 0, -5.5), 0.01)
		elvis.position = Vector3(-3.0, 0, 1.0)
		dummy.position = Vector3(3.0, 0, 1.0)
		arena.crack(Vector3(-5.5, 0, -1.5), 1.5)
		arena.crack(Vector3(4.5, 0, -3.5), 1.0)

func _physics_process(delta: float) -> void:
	if ShotDriver.bot == "fx":
		for f: Array in SHOW_FX:
			var at: float = SHOW_AT - f[0]
			if _t <= at and at < _t + delta:
				Fx.spawn(f[1], f[2], f[3])
		_t += delta
		if _t >= SHOW_AT:
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
