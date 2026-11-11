class_name Stamina extends Node
# Spent by moves, refills after regen_delay. Any stamina left lets a move start; at 0 every spend is refused.

signal changed(value: float, max_value: float)

@export var max_value := 100.0
@export var regen_per_s := 30.0
@export var regen_delay := 0.6
var in_combat := true    # out of combat it refills 3x as fast (Unreal StaminaComponent.h OutOfCombatRegenScale 3)
var value: float = max_value

var _wait := 0.0

func _ready() -> void:
	value = max_value

func spend(cost: float) -> bool:
	if Dev.stamina:    # Dev's infinite stamina: only he has a Stamina
		return true
	if value <= 0.0:
		return false
	value = maxf(0.0, value - cost)
	_wait = regen_delay
	changed.emit(value, max_value)
	return true

# As Health.set_max.
func set_max(new_max: float) -> void:
	value = minf(value + maxf(new_max - max_value, 0.0), new_max)
	max_value = new_max
	changed.emit(value, max_value)

func refill() -> void:
	value = max_value
	_wait = 0.0
	changed.emit(value, max_value)

func _physics_process(delta: float) -> void:
	var used := minf(_wait, delta)
	_wait -= used
	if _wait > 0.0 or value >= max_value:
		return
	value = minf(max_value, value + regen_per_s * (1.0 if in_combat else 3.0) * (delta - used))
	changed.emit(value, max_value)
