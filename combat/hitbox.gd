class_name Hitbox extends Area3D
# A blow's reach. While active it hits each overlapping Hurtbox of the other team at most once per activation.

signal landed(target: Hurtbox, info: HitInfo)

const TEAM_PLAYER := 0
const TEAM_BOSS := 1

@export var team: int

var _info: HitInfo
var _left := 0.0
var _hit: Array[Hurtbox] = []

func _init() -> void:
	collision_layer = 0
	collision_mask = Hurtbox.LAYER
	monitorable = false    # always monitoring, so overlaps are known the moment it activates

func activate(info: HitInfo, seconds: float) -> void:
	_info = info
	_left = seconds
	_hit.clear()

func deactivate() -> void:
	_info = null

func is_active() -> bool:
	return _info != null

func _physics_process(delta: float) -> void:
	if _info == null:
		return
	for a in get_overlapping_areas():
		var h := a as Hurtbox
		if h and h.team != team and not h.invulnerable and not _hit.has(h):
			_hit.append(h)
			var info := _info
			h.hurt.emit(info)
			landed.emit(h, info)
			if _info == null:    # a handler ended it
				return
	_left -= delta    # game time, so a hit-stop holds it open too
	if _left <= 0.0:
		deactivate()
