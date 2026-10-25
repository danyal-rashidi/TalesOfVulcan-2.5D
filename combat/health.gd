class_name Health extends Node

signal changed(hp: float, max_hp: float)
signal died    # once, until reset()

@export var max_hp := 100.0
var hp: float = max_hp

func _ready() -> void:
	hp = max_hp    # max_hp may have been set by the scene after hp's default

func take(amount: float) -> void:
	if hp <= 0.0 or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	changed.emit(hp, max_hp)
	if hp == 0.0:
		died.emit()

func heal(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	changed.emit(hp, max_hp)

func reset() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)

func ratio() -> float:
	return hp / max_hp
