class_name CarriagePull extends Townsperson
# Cassia's carriage with Fortuna in harness, rolling into town (CassiaScene). It stops nobody while it rolls. Parked it's one still picture and solid, once he isn't standing where it stopped.

const ARCH_SHOWS := 115     # px up the gatehouse's picture: under an arch you see what's in it as far as the portcullis' spikes
const HEADING := 0.61       # rad: where the diagonal sheet is drawn going, from the planted foot's track: 0.7 m down the ground for 1 m across
const REACH := 0.35         # m: his body, and a little more, from something he could be stuck in
const STANDS_ON := 13       # the frame of walk_S her idle is drawn from: art/tools/carriage_pull.py's IDLE_FRAME
# What stops him once it's parked: x, z from where it stands, m along its heading, m across. The wagon, then the shafts and camel. Measured on the sheet's first frame.
const BOXES: Array[Array] = [[-1.05, -1.24, 3.1, 2.0], [0.8, 0.6, 3.0, 0.7]]

var _solid: StaticBody3D    # waiting for him to step clear

func _process(_delta: float) -> void:
	var foot := Pixel.snap(get_global_transform_interpolated().origin).z + sprite._lift.z    # the picture stands here
	var gate := Cinerea.NORTH + Cinerea.IN_FRONT
	var rows: int = sprite._manifest(folder)["cell"][1]
	var shows := ARCH_SHOWS + roundi((foot - gate) * 24.0)
	var in_arch := shows > 0 and shows < rows
	sprite.front_of = gate + 0.05 if in_arch else -INF
	sprite.set_param(&"cut", 1.0 - float(shows) / rows if in_arch else 0.0)

func _physics_process(delta: float) -> void:
	super(delta)
	var c := get_parent() as Cinerea
	if _solid and not _solid.is_inside_tree() and not on_it(c.player.global_position):
		c.add_child(_solid)

# It stops here: its columns stand in for its picture, which goes on throwing the shadow and playing her idle, and they show the frame it's on.
func park() -> void:
	var c := get_parent() as Cinerea
	var at := Pixel.snap(position)
	var cell: Array = sprite._manifest(folder)["cell"]
	var parts := c.columns(sprite._sprite.texture, cell[0], Vector2(at.x, at.z + sprite._lift.z), CharacterSprite.SHADER)
	sprite.frame_changed.connect(func(_key: String, i: int) -> void:
		for s in parts:
			s.region_rect.position.x = fposmod(s.region_rect.position.x, cell[0]) + i * cell[0])
	sprite._sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_solid = StaticBody3D.new()
	for b: Array in BOXES:
		c._town_box(_solid, Vector3(b[2], 2.0, b[3]), Vector3(at.x + b[0], 1.0, at.z + b[1]), -HEADING)

# He's on it, or near enough that it would stop him where he stands.
func on_it(at: Vector3) -> bool:
	for b: Array in BOXES:
		var d := Vector2(at.x - position.x - b[0], at.z - position.z - b[1]).rotated(-HEADING)
		if absf(d.x) < b[2] / 2.0 + REACH and absf(d.y) < b[3] / 2.0 + REACH:
			return true
	return false
