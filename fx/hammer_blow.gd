extends FxEffect
# Hammer Blow landing: the hammer's head comes down in front of him and the ground jumps, centred on the head. A ring of force racing out to the blow's edge, the blow over the whole disc for an instant, sand and stone thrown up. No fire until the hammer is upgraded (Journey.hammer_upgraded): he hasn't got it back yet. fx/hammer_aura.gd is the hammer itself.
# Its look is art/pixelfx/, from art/tools/pixelfx_sheets.py. The ring in the sheet is RADIUS round the origin.

const RADIUS := 2.8      # Claude's call
const HIT_TIME := 0.15
const PLAIN := "res://art/pixelfx/hammer_impact.png"
const BURNING := "res://art/pixelfx/hammer_impact_fire.png"
const FRAMES := 26
const FPS := 20.0

var _spr: Sprite3D

func _build() -> void:
	life = FRAMES / FPS
	_spr = _pixelfx(BURNING if Journey.hammer_upgraded else PLAIN, FRAMES)
	_spr.material_override = FxHammerAura.behind_people(_spr.texture)    # as the hammer: whoever's in it stands in front of the dust
	_spr.sorting_offset = 1.0    # over the hammer's own head, which comes down here
	var disc := CylinderShape3D.new()
	disc.radius = RADIUS
	disc.height = 8.0 if Hills.on else 2.0    # up and down a slope: everyone in reach is on the ground anyway
	_hit(disc, Vector3(0.0, 1.0, 0.0), 40.0, 7.0, true, HIT_TIME)

func _step(_delta: float) -> void:
	_spr.frame = mini(int(age * FPS), FRAMES - 1)
