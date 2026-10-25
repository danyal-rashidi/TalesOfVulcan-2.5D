class_name Flasks extends Node
# 4 red (heal 40%) and 2 green (refill stamina): Unreal FlaskComponent.h MaxHealthFlasks, MaxStaminaFlasks, HealFraction.

signal changed(red: int, green: int)

const RED_MAX := 4
const GREEN_MAX := 2
const RED_HEAL := 0.4

var red := RED_MAX
var green := GREEN_MAX

func drink_red(h: Health) -> bool:
	if red <= 0:
		return false
	red -= 1
	h.heal(RED_HEAL * h.max_hp)
	changed.emit(red, green)
	return true

func drink_green(s: Stamina) -> bool:
	if green <= 0:
		return false
	green -= 1
	s.refill()
	changed.emit(red, green)
	return true

func refill() -> void:
	red = RED_MAX
	green = GREEN_MAX
	changed.emit(red, green)
