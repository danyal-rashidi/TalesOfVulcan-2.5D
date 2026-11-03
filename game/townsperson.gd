class_name Townsperson extends Node3D
# Someone who lives in Cinerea: walks back and forth along a short path or stands, stops at each end, and answers Vulcan: a talk with choices first (Talks), then short lines. A stand is the walk's
# first frame with a small bob in code, so nobody needs a clip for it.

signal arrived    # the end of a walk_to

const SPEED := 1.5       # Claude's call: m/s, an easy walk, as their sheets are drawn for: one cycle a second
const PAUSE := 2.5       # Claude's call: s at each end of the path
const BOB := 1.0 / Pixel.PX    # one pixel up and down
const BOB_TIME := 1.6    # s

var who := ""            # the name Hud shows
var speed := SPEED
var hitched := false     # in harness: drawn as part of the carriage, and still someone to talk to
var folder := ""
var first_talk: Array = []
var later: PackedStringArray = []
var sprite := CharacterSprite.new()
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _going_to_end := true
var _wait := 0.0
var _talks := 0
var _one_way := false
var _path: Array[Vector3] = []
var _time := 0.0
var _busy := false       # talking: stays put, facing Vulcan
var lift := 0.0          # m above the ground her feet are drawn: on a carriage's sill
var bobs := true         # hops a pixel while standing, feet and all; Cassia doesn't, so she never hovers (Danyal)

func setup(folder_: String, name_: String, at: Vector3, to: Vector3, first: Array, after: PackedStringArray) -> void:
	who = name_
	folder = folder_
	first_talk = first
	later = after
	_from = at
	_to = to
	position = at
	add_child(sprite)
	add_to_group(&"walkers")    # grass bends for them too
	add_child(Steps.new())
	sprite.load_character(folder_)
	sprite.play("idle", Vector2.DOWN)

# What to say this time.
func conversation() -> Array:
	_talks += 1
	return first_talk if _talks == 1 or later.is_empty() else [{"who": who, "line": later[(_talks - 2) % later.size()]}]

# Walks there and stays, by way of the points before it.
func walk_to(points: Array[Vector3]) -> void:
	_path = points.duplicate()
	_next_leg()

func _next_leg() -> void:
	_from = position
	_to = _path.pop_front()
	_going_to_end = true
	_one_way = true
	_wait = 0.0

func walking() -> bool:
	return _one_way

func set_shown(on: bool) -> void:
	sprite.visible = on

func shown() -> bool:
	return sprite.visible or hitched

# Metres above its feet that a sign over its head stands: 21.17 px a metre upward on screen.
func head_up() -> float:
	return sprite._manifest(folder)["cell"][1] / 21.17 + (1.8 if hitched else 0.1)    # in harness she's drawn bigger: art/tools/carriage_pull.py

func hold(face: Vector2) -> void:
	_busy = true
	sprite.play("idle", face)

func release() -> void:
	_busy = false

func _physics_process(delta: float) -> void:
	_time += delta
	if _busy or _from.is_equal_approx(_to):
		sprite.position.y = lift + BOB * (1.0 if fmod(_time, BOB_TIME) < BOB_TIME / 2.0 and lift == 0.0 and bobs else 0.0)
		return
	if _wait > 0.0:
		_wait -= delta
		sprite.position.y = lift + BOB * (1.0 if fmod(_time, BOB_TIME) < BOB_TIME / 2.0 and lift == 0.0 and bobs else 0.0)
		return
	sprite.position.y = lift
	var goal := _to if _going_to_end else _from
	var step := goal - position
	if step.length() <= speed * delta:
		position = goal
		if _one_way:
			if not _path.is_empty():
				_next_leg()
				return
			_from = goal
			_to = goal
			_one_way = false
			arrived.emit.call_deferred()
		_going_to_end = not _going_to_end
		_wait = PAUSE
		sprite.play("idle", Vector2(step.x, step.z).normalized())
		return
	position += step.normalized() * speed * delta
	sprite.play("walk", Vector2(step.x, step.z).normalized())
