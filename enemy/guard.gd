extends Jackal
# A raider with his guard up: the hunter (walk up, wind up, slash), but blows from the front spark off him and only wear his break bar.
# He is hurt from behind, while broken, and while he recovers from his own slash; one parry of that slash breaks him.
# No scene of its own: set_script() on a jackal.tscn instance before it enters the tree.

const SLASH_WINDUP := 0.6    # s his sword goes back: his warning, longer than a jackal's 0.4. Claude's call
const GUARD_POISE := 35.0    # Elvis.PARRY_POISE: one parry of his slash breaks him. Claude's call
const BLOCK_WEAR := 0.5      # of a blocked blow's poise goes on his break bar: about seven lights, or a lunge and a light. Claude's call

func _ready() -> void:
	folder = "raider_sword"
	run_key = "walk"
	bite_key = "slash"
	hp = 40.0
	bar_up = 2.7
	speed = 3.0    # the raiders' own numbers (LakeScene)
	super()
	poise_max = GUARD_POISE
	reset_poise()

func _to(m: Mode) -> void:
	super(m)
	if m == Mode.WINDUP:
		_t = WINDUP - SLASH_WINDUP    # the jackal's clock starts 0.2 s behind, so the blow comes at 0.6 s

# The slash sheet over his longer slash: the jackal's timing would draw the swing 0.2 s ahead of the blow.
func _tick(delta: float) -> void:
	var was := mode
	super(delta)
	if mode == Mode.WINDUP and was != Mode.WINDUP:
		sprite.play_timed(bite_key, facing, SLASH_WINDUP + ACTIVE + RECOVER)

func take_hit(info: HitInfo) -> void:
	if _blocks(info):
		Fx.spawn(&"sparks", global_position + Vector3(facing.x * 0.4, FxSlash.CHEST, facing.y * 0.4))    # off his guard, as a blow that does nothing to the kneeling Vulcan
		wear_poise(info.poise * BLOCK_WEAR)
		return
	super(info)

# His guard is up and the blow came from the side he faces. Asleep it's down, so the first blow lands and wakes him.
func _blocks(info: HitInfo) -> bool:
	if mode == Mode.SLEEP or mode == Mode.RECOVER or broken > 0.0 or Dev.one_hit:
		return false
	var from := info.source.global_position if is_instance_valid(info.source) and not info.blast else info.at    # as Actor.take_hit reads where a blow came from
	return Vector2(from.x - global_position.x, from.z - global_position.z).dot(facing) > 0.0
