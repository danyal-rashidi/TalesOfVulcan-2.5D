class_name Hurtbox extends Area3D
# Where an Actor can be hit. Hitboxes of the other team find it on LAYER and emit `hurt` on it.

signal hurt(info: HitInfo)

const LAYER := 16    # physics layer 5, used only by hurtboxes

@export var team: int
var invulnerable := false

func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
