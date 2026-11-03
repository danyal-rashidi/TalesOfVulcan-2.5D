class_name Cinerea extends Arena
# The road into Cinerea, the village (STORY.md: "Cinerea, the village: the game starts here"): Vulcan wakes by the legionary's tomb with a jackal at it, takes
# the sword and drachma, remembers The Hammer, equips the sword from the inventory, fights his way down the road between the tombs and sees the village.

const ELVIS := preload("res://player/elvis.tscn")
const JACKAL := preload("res://enemy/jackal.tscn")
const HUD := preload("res://ui/hud.tscn")
const WALL_SHADER := preload("res://arena/wall.gdshader")
const LENGTH := 90.0            # the road, north to south
const WIDTH := 5.0             # as the town's main street
const ROAD_MARGIN := 1.0       # m each side in art/floors/road.png, for stones past the edge: art/tools/road_tile.py
const FIELD := 240.0            # the sand round it
const ROAD_TILE := 12.0         # m of road in one repeat of its picture
const BOUND_X := 28.0           # m either side of the road you can go
const TOMB_REACH := 3.0
const CRAG_TOP := 12.0          # m: over the hills
const WAKE_AT := Vector3(1.0, 0.0, -23.0)    # on the road, the tomb and the jackal in view ahead (Danyal: not on top of them)
const TOMB_AT := Vector2(-6.2, -25.8)
const TOMB_FRAMES := 5          # art/props/tomb_big_open.png: its slab slides off the pit
const SHY_AT := 4.5             # Claude's call: m from him that the jackal backs off from the tomb
const SHY_TO := Vector3(-10.0, 0.0, -22.5)
const STORM_FROM := Vector3(1.0, 0.0, -43.0)    # the long walk starts here, in the sandstorm, and comes to the grave (Danyal)
const STORM_WALK := 1.7         # Claude's call: m/s, slowly through it
const STORM_CLEARS := 2.5       # s
const AGGRO := 7.5              # m: scattered foes wake when he's this close
# Scattered about the road, not in packs, and no raiders yet (Danyal): x, z. They sleep until he comes near.
const JACKALS: Array[Vector2] = [Vector2(10.0, -20.0), Vector2(-14.0, -14.5), Vector2(8.5, -9.5), Vector2(-5.5, -8.0), Vector2(19.0, -13.0)]
const SCORPIONS: Array[Vector2] = [Vector2(-9.0, -18.5), Vector2(15.0, -6.5), Vector2(-18.0, -7.0), Vector2(4.5, -15.5)]
const LAKE_FROM := -4.5         # z: the dark comes down, and then the lake (LakeScene)
const GRAVES_TO := -19.0        # z: the graves' stiller light ends here. Claude's call
const LAKE_LIGHT := -8.0        # z: the lake's begins, north of where the dark's walk ends (LakeScene.WALK_TO), so the light holds when he gets control back. Claude's call
const AREA_FADE := 2.5          # s the light takes to change from one stretch to the next. Claude's call
const LAKE_AT := Vector2(14.6, 2.6)       # its middle
const LAKE_HALF := Vector2(8.6, 6.1)      # the water, m each way: the shore can be walked on
const VILLAGE_AT := 23.0        # z: he comes through the gate
# Danyal's plan of the town is docs/refs/town_example.png, its houses docs/refs/house_example.png: a wall of eight sides, gates north and south, a fountain plaza, cobbled streets, houses that face you.
# Everything is to one scale: he is 49 px, a door about 58 px, a wall about 140 px.
const NORTH := 22.0             # z of the north wall, where the road comes in
const SOUTH := 100.0
const FLAT_X := 42.0            # x the north and south walls end at, then 45 degree corners
const SIDE_X := 62.0            # x of the east and west walls
const CORNER := 20.0            # m the corners run in x and in z
const GATE_HALF := 1.7          # m: the gate's arch, 110 px wide: her carriage goes through it
const GATEHOUSE_HALF := 9.2     # m the gatehouse reaches either side
# Where the north wall stops him, as its picture meets the ground: m either side of the road from, to, and m north of its foot. The gatehouse's pillars stand wider than its arch, and its towers further back.
const GATE_FEET: Array[Array] = [[GATE_HALF, 2.97, 0.85], [2.97, 4.2, 0.0], [4.2, GATEHOUSE_HALF, 0.3], [GATEHOUSE_HALF, FLAT_X, 0.0]]
const SIDE_REACH := 0.5         # m the north-south walls keep him off their line
const CORNER_SLICE := 1.0       # m: wall_dr*.png, wall_dl*.png
const BEHIND_WALL := 0.3    # m kept clear north of a wall: he can walk right up to it (Danyal), and it opens a hole round him where its picture would hide him
const HIDES_PAST := 0.54    # m north of the top of a wall's picture that he still opens a hole
const HOLE := 34.0          # px: the hole's radius
const IN_FRONT := 0.05       # m a tower stands before the wall it covers: under half a Pixel.snap step snaps back level, and the two flicker
const WALL_THICK := 1.0
const FLOOR := Rect2(-70.0, 14.0, 140.0, 94.0)    # art/floors/town.png, from art/tools/town_floor.py
const TOWN_SAND := Color8(192, 170, 98)           # yellower than the colosseum's, as the plan is
const FOUNTAIN_AT := Vector2(0.0, 67.0)
const FOUNTAIN_FRAMES := 32     # art/props/fountain_anim.png, from art/tools/fountain_water.py: only the water moves
const FOUNTAIN_FPS := 8.0
const TALK_REACH := 2.4
# name, x, z. What stops him comes from the size of its picture (_block).
const ROADSIDE: Array[Array] = [["tomb_big_open", TOMB_AT.x, TOMB_AT.y], ["cypress", -8.5, -22.0], ["bush", -4.6, -20.0],
	["tomb_small", 4.0, -22.5], ["tomb_broken", 5.5, -17.0], ["milestone", 3.6, -13.5], ["tomb_small", -4.0, -14.0], ["rubble", -3.2, -11.0],
	["cypress", 7.0, -10.0], ["tomb_broken", -5.5, -6.5], ["cypress", -11.5, -1.5],
	["milestone", -3.6, 8.5], ["bush", -6.0, 10.0], ["cypress", 11.5, 14.5], ["carriage", -6.5, 1.0], ["crates", -11.0, 2.4], ["rock_tan", -3.0, 5.0], ["logs", -9.0, 17.5], ["rock_tan", 9.0, 17.0],
	["tomb_broken", -7.0, -36.0], ["rubble", 5.0, -33.0], ["rock_tan", -4.0, -30.0], ["cypress", 8.0, -38.0], ["rock_tan", 13.0, -24.0]]
# Steep rock among the hills, too steep to climb: name, x, z of where its picture's bottom meets the ground, and the hidden back of its foot in m from there, measured on its picture. Where they stand is Claude's call.
const CRAGS: Array[Array] = [["plateau2", -13.5, -33.2, [Vector2(0.0, -3.4)]], ["plateau", 12.5, -35.5, [Vector2(0.0, -4.3)]], ["rock_wall", 13.0, -19.5, [Vector2(-2.4, -4.6), Vector2(2.7, -1.9)]], ["plateau2", -13.5, -3.5, [Vector2(0.0, -3.4)]]]
# The town, in metres: name, x, z of where it meets the ground. Houses stand in rows with their doors on a street.
const VILLAGE: Array[Array] = [
	# along the north lane
	["f_narrow", -6.0, 35.0], ["f_plaster", -12.0, 35.0], ["f_half", -20.0, 35.0], ["f_timber", -37.0, 35.0], ["pond", -28.0, 34.5], ["palm", -24.5, 28.5], ["palm", -32.5, 29.0],
	["f_stair", 7.8, 34.8], ["f_white", 15.6, 34.8], ["f_porch", 25.0, 34.6], ["f_half", 42.0, 35.0], ["palm", 32.0, 33.0], ["palm_young", 34.5, 35.0], ["rock_heap", 30.5, 35.0],
	# facing the plaza
	["f_hall", -11.0, 51.0], ["f_tavern", 9.0, 51.0], ["barrels", 14.6, 51.0], ["palm", 16.0, 47.0], ["f_stone", -28.0, 48.0], ["f_tower", 24.5, 50.0], ["f_adobe", 30.6, 50.0],
	# on the plaza, at its edges
	["st_red", -12.0, 57.0], ["st_blue", -6.0, 57.0], ["st_cassia", 7.0, 57.0], ["st_green", 13.0, 57.0], ["st_yellow", -12.0, 72.5], ["st_brown", 12.0, 72.5], ["crates", 10.0, 55.6], ["amphorae", 15.6, 57.0], ["job_board", 15.6, 62.0], ["baskets", -15.0, 72.0], ["pots", -9.2, 56.3],
	["rugs", -5.8, 72.3], ["table", 6.0, 72.3], ["fruit", 8.6, 71.8], ["barrels", -15.4, 60.0], ["lantern_post", -5.0, 65.0], ["lantern_post", 5.0, 65.0],
	# the west lane
	["f_narrow", -23.5, 59.0], ["f_adobe", -31.0, 59.0], ["f_plaster", -36.8, 59.0], ["f_porch", -50.5, 59.0], ["cliff", -52.0, 45.0], ["saguaro", -46.0, 42.0], ["barrel", -56.0, 49.0],
	# south-west
	["f_stone", -31.0, 76.0], ["f_plaster", -40.0, 76.0], ["f_timber", -49.0, 76.0], ["well", -23.0, 74.0], ["palm", -21.5, 66.5], ["statue", -24.5, 69.5], ["bush_flower", -27.5, 65.5],
	["f_stable", -14.0, 93.5], ["hay", -11.5, 86.5], ["trough", -21.5, 93.5], ["f_half", -29.0, 93.5], ["lookout", -41.0, 92.0], ["rail", -36.0, 93.5], ["saguaro", -46.0, 84.5], ["thorn", -30.0, 85.0], ["boulders", -24.0, 85.0],
	# south-east
	["f_smithy", 12.0, 81.0], ["anvil", 6.0, 80.8], ["firewood", 17.3, 80.8], ["f_white", 22.0, 81.0], ["f_narrow", 29.5, 81.0], ["f_adobe", 10.0, 93.5], ["f_stair", 18.0, 93.5], ["f_priest", 27.5, 93.5], ["f_timber", 38.0, 93.5],
	["rock_heap", 45.0, 86.0], ["saguaro", 49.0, 83.0], ["boulders", 42.0, 80.5], ["palm", 3.5, 90.0],
	# the temple, its fire altar and bell
	["f_temple", 50.0, 67.0], ["fire_altar", 50.0, 77.5], ["statue", 43.5, 77.0], ["bell", 56.8, 78.0], ["brazier", 46.5, 78.0], ["brazier", 53.5, 78.0], ["f_priest", 50.5, 50.0], ["plateau", 52.0, 40.0], ["palm", 41.0, 49.0], ["palm_young", 44.5, 52.5], ["barrel", 57.0, 50.5],
	# things by the main street and small things
	["lantern_post", -3.9, 31.0], ["lantern_post", 3.9, 31.0], ["lantern_post", -3.9, 47.0], ["lantern_post", 3.9, 47.0], ["palm", -19.6, 50.8], ["palm", -21.5, 76.0], ["palm", 21.5, 76.0], ["bush_flower", 20.5, 53.5], ["grass", 24.0, 54.0],
	["grass", -33.0, 66.5], ["grass", -55.0, 70.0], ["grass", -9.0, 84.5], ["grass", 41.0, 75.0], ["grass", 57.0, 60.0], ["grass", -52.0, 36.0], ["grass", 8.0, 44.5], ["grass", -22.0, 44.0], ["rocks", -36.0, 43.0], ["rocks", 28.0, 44.0], ["rocks", -5.0, 84.0], ["bush", -36.5, 66.0], ["bush", 39.5, 58.0], ["barrel", -15.0, 44.0], ["thorn", 52.0, 88.5], ["thorn", -56.0, 57.0],
	# outside the walls
	["saguaro", -21.0, 17.0], ["saguaro", 20.0, 16.0], ["barrel", 23.5, 18.0], ["rock_wall", 64.0, 28.0], ["boulders", -66.0, 50.0], ["saguaro", 66.0, 62.0], ["boulders", 66.0, 70.0], ["rock_wall", -64.0, 92.0], ["saguaro", -22.0, 105.0], ["boulders", 24.0, 106.0]]
# Things that belong on the stones of the plaza. Nothing else may stand on a street (test_nothing_stands_on_the_streets).
const ON_STONES: Array[String] = ["st_red", "st_blue", "st_cassia", "st_green", "st_yellow", "st_brown", "crates", "amphorae", "job_board", "baskets", "pots", "rugs", "table", "fruit", "barrels", "lantern_post"]
# The people, and what they say after their first talk. folder, name, x, z, x to, z to, conversation, later lines
const PEOPLE: Array[Array] = [["tullus", "Old Tullus", -4.0, 40.5, -4.0, 49.5, Talks.TULLUS, ["Steady, steady... You hear that? That's not the wind."]],
	["livia", "Livia", -21.3, 75.2, -21.3, 75.2, Talks.LIVIA, ["It's past the old shrine."]],
	["livia_boy", "A boy", -25.5, 68.5, -25.5, 75.5, Talks.BOY, ["Are you a soldier?"]],
	# They stand where they are: one picture each and the bob, no clips (Danyal: "some idle ones to savecredits"). Their lines are DIALOGUE.md's villagers'; the smith's and the priest's are Claude's call.
	["villager_man", "A villager", -8.5, 60.5, -8.5, 60.5, [{"who": "A villager", "line": "The sky's been blue three days now. Feels wrong, somehow."}], ["Keep walking, stranger."]],
	["villager_woman", "A villager", 13.0, 66.0, 13.0, 66.0, [{"who": "A villager", "line": "That's him. The one Cassia found in the street."}], ["Ignotus! Good day to you."]],
	["villager_old", "An old woman", -30.0, 63.5, -30.0, 63.5, [{"who": "An old woman", "line": "Don't go near the tombs after dark."}], ["Keep walking, stranger."]],
	["villager_child", "A girl", 5.0, 75.5, 5.0, 75.5, [{"who": "A girl", "line": "My gran said the fire god lived in that colosseum. I said, Gran, it's a statue."}], ["Are you a soldier?"]],
	["blacksmith", "The smith", 8.0, 83.0, 8.0, 83.0, [{"who": "The smith", "line": "That old legionary blade? Bring me iron and I'll see what can be done."}], ["Mind the sparks."]],
	["priest", "The priest", 47.0, 72.5, 47.0, 72.5, [{"who": "The priest", "line": "Anything old and red, stranger. I pay well for it."}], ["The fire keeps its own counsel."]]]
# Things he can walk over, and things where only a trunk or a post stops him.
const WALK_OVER: Array[String] = ["grass", "rocks", "spice", "bones_pile", "bush", "thorn"]
const THIN: Array[String] = ["palm", "palm_young", "olive", "cypress", "tree_dead", "lantern_post", "torch", "banner", "signpost", "sign_hammer", "sign_coin", "milestone", "milestone_old", "saguaro"]
# What burns, and where its light hangs from the picture's foot, in m: a lantern hangs to the right of its post. Claude's call
const FIRES := {"brazier": Vector3(0.0, 0.9, 0.0), "fire_altar": Vector3(0.0, 1.5, 0.0), "lantern_post": Vector3(0.35, 1.5, 0.0)}
const FIRE_ENERGY := 0.5    # low: it's day. shortcut: one energy for every mood (Cinerea has no night), tie it to the mood when one comes
const FIRE_REACH := 3.0
const TOMB_HALF := 1.0          # the tomb's scene stands him at its pit, so its box stays as it was
const THIN_SIZE := Vector2(0.5, 0.4)
const DEEP := {"plateau": 4.3, "pond": 4.8, "cliff": 4.8, "boulders": 1.7}    # m of ground, measured on each picture: land with a flat top lies further back than footprint() guesses
const SLANTED := {"rock_wall": [9.7, 1.2, 2.6, -0.58], "rail": [3.3, 0.5, 1.05, 0.69]}    # long things lying across the view: length, thickness, m back from the picture's foot, turn
const FOUNTAIN_BASE: Array[Vector2] = [Vector2(-3.55, -1.75), Vector2(-3.55, -1.35), Vector2(-1.65, -0.12), Vector2(1.65, -0.12), Vector2(3.55, -1.35), Vector2(3.55, -1.75), Vector2(1.7, -3.05), Vector2(-1.7, -3.05)]    # its rim on the ground, m from FOUNTAIN_AT, measured on its picture
const COLUMN := 8                # px: a picture in columns (columns()) is cut this wide, as the fountain is, so he's in front of its rim's slanted sides when he stands in front of them
const FOUNTAIN_W := 232
const LOOT_SIGN := 1.4           # s the sign over a fallen foe stays
const STALL_AT := Vector3(7.0, 0.0, 58.6)         # in front of her stall on the plaza

var fast: bool = ShotDriver.fast
var player: Elvis
var hud: Hud
var menu: GameMenu
var shop: Shop
var camera: PixelCamera
var looted := false
var ended := false

var respawn_at := WAKE_AT
var _holes: Array[Array] = []    # [its material, its foot's z, its x, how far either side a hole could show, has one, how far north its picture hides him] for each piece of town wall
var _sleepers: Array[Jackal] = []
var _the_grass: Grass
var _scattered := false
var _floor_img: Image
var _busy := false       # a line or the flash is playing: no prompts over it
var _first: Jackal
var _busy_tick := 0    # the physics tick _busy was last on
var _people: Array[Townsperson] = []
var _reached := false
var _scorpions := false
var _raiders := false
var _raiders_left := 0
var _cassia: Townsperson
var _fortuna: Townsperson
var met_cassia := false
var _hinted: Townsperson
var _cart: Sprite3D
var _cart_door: Sprite3D
var _cart_body: StaticBody3D    # its own, as it leaves
var pull: CarriagePull          # it with Fortuna in harness, once she's hitched
var _fountain: Array[Sprite3D] = []
var _fountain_frame := -1
var _time := 0.0
var _tomb: Sprite3D
var _shied := false
var _spawned := false
var _hint := ""

func _ready() -> void:
	Hills.start()
	_lights()
	_road()
	set_mood(&"clear", 0.0)
	_player()
	_the_grass.watch = player
	hud = HUD.instantiate() as Hud
	hud.fast = fast
	hud.show_journey = true
	add_child(hud)
	Steps.surface = _on_stone
	menu = GameMenu.new()
	menu.player = player
	menu.allowed = false
	add_child(menu)
	shop = Shop.new()
	shop.player = player
	add_child(shop)
	camera = PixelCamera.new()
	add_child(camera)
	camera.follow(player)
	hud.bind(player, null)
	hud.show_boss_bar(false)
	player.health.died.connect(_on_died)
	Journey.changed.connect(_on_journey_changed)
	Journey.visit(&"desert")    # the colosseum and the long walk
	Journey.visit(&"cinerea")
	_first = _jackal(Vector3(TOMB_AT.x + 1.6, 0.0, TOMB_AT.y + 1.8))
	_first.facing = Vector2.LEFT
	_arrive()

func _exit_tree() -> void:
	Steps.surface = Callable()
	Hills.stop()

# On cobbles or the road, for footsteps: no sand flies off stone, and a print barely shows.
func _on_stone(x: float, z: float) -> bool:
	if z < NORTH:
		return absf(x) < WIDTH / 2.0
	if _floor_img == null:
		_floor_img = Image.load_from_file("res://art/floors/town.png")
	if not FLOOR.has_point(Vector2(x, z)):
		return false
	var px := _floor_img.get_pixel(int((x - FLOOR.position.x) / FLOOR.size.x * _floor_img.get_width()), int((z - FLOOR.position.y) / FLOOR.size.y * _floor_img.get_height()))
	return px.a > 0.5 and maxf(px.r, maxf(px.g, px.b)) - minf(px.r, minf(px.g, px.b)) < 0.18

func scaled(seconds: float) -> float:
	return seconds * (0.05 if fast else 1.0)

func _arrive() -> void:
	_busy = true
	player.input_enabled = false
	hud.show_player(false)
	hud.fade(true, 0.0)
	hud.title_card("The Long Walk", "")
	await get_tree().create_timer(scaled(4.2)).timeout
	if not is_inside_tree():
		return
	hud.title_card("", "")
	# Dust going by, and the man coming slowly up through it, until the grave stands out of it.
	var mask := player.collision_mask
	player.collision_mask = 0
	player.global_position = STORM_FROM
	player.reset_physics_interpolation()
	camera.follow(player)
	var storm := Sandstorm.new()
	add_child(storm)
	set_mood(&"dust", 0.0)
	hud.fade(false, scaled(2.0))
	await TombScene._walk_at(self, WAKE_AT, STORM_WALK)
	if not is_inside_tree():
		return
	set_mood(mood_here(), scaled(STORM_CLEARS))
	storm.fade_to(0.0, scaled(STORM_CLEARS))
	await TombScene._beat(self, STORM_CLEARS * 0.5)
	TombScene._face(player, Vector3(TOMB_AT.x, 0.0, TOMB_AT.y))
	player.collision_mask = mask
	hud.show_player(true)
	player.input_enabled = true
	menu.allowed = true
	_busy = false
	await TombScene._beat(self, STORM_CLEARS)
	if is_instance_valid(storm):
		storm.queue_free()

func _player() -> void:
	player = ELVIS.instantiate() as Elvis
	player.character = "vulcan_human"
	player.combo_max = 2
	player.walk_speed = 3.0     # as his walk is drawn: 1.2 m a step, a cycle in 0.8 s
	player.sprint_speed = 6.0   # as his run is drawn
	player.accel = 18.0
	player.decel = 26.0
	player.has_weapon = Journey.has_weapon()
	player.spear_out = player.has_weapon
	add_child(player)
	player.global_position = WAKE_AT
	player.facing = Vector2.LEFT
	player.stamina.in_combat = false
	player.reset_physics_interpolation()

func _jackal(at: Vector3) -> Jackal:
	var j := JACKAL.instantiate() as Jackal
	add_child(j)
	j.global_position = at
	j.reset_physics_interpolation()
	j.dead.connect(_loot.bind(j, &"jackal_pelt"))
	return j

# What it carried goes straight in his bag, for Cassia to buy, and says so over where it fell.
func _loot(foe: Jackal, id: StringName) -> void:
	Journey.add_item(id)
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = foe.global_position
	hud.pop_up(spot, foe.bar_up, "+ %s" % Journey.ITEMS[id]["name"], "", scaled(FxNumber.LIFE))    # after the killing blow's number
	get_tree().create_timer(scaled(FxNumber.LIFE + LOOT_SIGN)).timeout.connect(spot.queue_free)    # the sign goes with it

func _foe(folder: String, run: String, bite: String, hp: float, bar_up: float, at: Vector3, loot_id: StringName, speed := Jackal.SPEED) -> Jackal:
	var j := JACKAL.instantiate() as Jackal
	j.folder = folder
	j.run_key = run
	j.bite_key = bite
	j.hp = hp
	j.bar_up = bar_up
	j.speed = speed
	j.position = at
	add_child(j)
	j.dead.connect(_loot.bind(j, loot_id))
	return j

func _road() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * FIELD
	ground.mesh = plane
	if not _tex.has(&"town_sand"):
		_tex[&"town_sand"] = ImageTexture.create_from_image(_paint(128, 96, TOWN_SAND, 9, "sand"))
		_tex[&"road"] = _floor_tile("road")
	ground.material_override = _mat(_tex[&"town_sand"], Vector2(FIELD * TPM.x / 128.0, FIELD * TPM.y / 96.0))
	add_child(ground)
	var hills := MeshInstance3D.new()
	hills.mesh = Hills.mesh()
	if not _tex.has(&"hills"):
		_tex[&"hills"] = _floor_tile("hills")
	hills.material_override = _mat(_tex[&"hills"])
	hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF    # none is steep enough to throw one: the sun is higher than any slope
	add_child(hills)
	var strip := MeshInstance3D.new()
	var road := PlaneMesh.new()
	road.size = Vector2(WIDTH + ROAD_MARGIN * 2.0, NORTH + LENGTH / 2.0)    # it ends at the town's north gate
	strip.mesh = road
	strip.material_override = _mat(_tex[&"road"], Vector2(1.0, road.size.y / ROAD_TILE))
	strip.position = Vector3(0.0, 0.01, (NORTH - LENGTH / 2.0) / 2.0)
	add_child(strip)
	var body := StaticBody3D.new()
	add_child(body)
	for p: Array in ROADSIDE:
		var prop := prop_sprite(p[0], p[1], p[2])
		if p[0] == "tomb_big_open":
			prop.hframes = TOMB_FRAMES
			_tomb = prop
		elif p[0] == "carriage":
			_cart = prop
			prop.flip_h = true    # it faces the road it leaves by: the harnessed sheet heads that way, so hitching up needs no cut
			_cart_body = StaticBody3D.new()
			add_child(_cart_body)
			_cart_door = Arena.prop_sprite("carriage_door", 0.0, 0.0)
			_cart_door.flip_h = true
			_cart_door.hframes = 4
			_cart_door.scale = Vector3.ONE
			_cart_door.position = Vector3(0.0, 0.0, 0.17)    # in front of her in the doorway: CassiaScene.DOOR_AT
			_cart_door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			prop.add_child(_cart_door)
			# Its shadow stands on the line of its near wheels (Arena.ground_shadow), so its pictures mustn't take it, and it goes when the prop does. Claude's call: measured on the mirrored picture.
			for s: Sprite3D in [prop, _cart_door]:
				(s.material_override as ShaderMaterial).shader = preload("res://arena/prop_unshadowed.gdshader")
			prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var size := prop.texture.get_size()
			var shadow := Arena.ground_shadow(prop.texture, Rect2(Vector2.ZERO, size), Vector2(35.0, 137.0), 31.0 / 65.0, Vector2(size.x / 2.0, size.y))
			shadow.flip_h = true
			shadow.top_level = true
			shadow.position += Pixel.snap(Vector3(p[1], 0.0, p[2]))
			prop.add_child(shadow)
		add_child(prop)
		if p[0] == "tomb_big_open":
			_solid(body, Vector4(p[1], p[2], TOMB_HALF, 2.0))
		else:
			_block(_cart_body if p[0] == "carriage" else body, prop, p[0], p[1], p[2])
	for c: Array in CRAGS:
		_crag(body, c)
	_lake(body)
	var north := -LENGTH / 2.0 + 1.0
	for wall: Rect2 in [Rect2(-BOUND_X - 2.0, north, 2.0, NORTH - north), Rect2(BOUND_X, north, 2.0, NORTH - north), Rect2(-BOUND_X, north - 2.0, BOUND_X * 2.0, 2.0)]:
		_town_box(body, Vector3(wall.size.x, 12.0, wall.size.y), Vector3(wall.get_center().x, 6.0, wall.get_center().y))    # over the hills
	_town_walls(body)
	_village(body)
	_grass()

# The lake lies on the ground, not standing up like a prop, so he can walk round it on its shore. The water stops him.
func _lake(body: StaticBody3D) -> void:
	var s := Arena.prop_sprite("lake", 0.0, 0.0)
	s.axis = Vector3.AXIS_Y
	s.scale = Vector3(1.0, 1.0, 4.0 / 3.0)    # 24 px a metre of ground, not 32
	s.position = Vector3(LAKE_AT.x, 0.02, LAKE_AT.y)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	var outline: Array[Vector2] = []
	for i in 12:
		var a := TAU * i / 12.0
		outline.append(Vector2(cos(a) * LAKE_HALF.x, sin(a) * LAKE_HALF.y))
	_town_prism(body, LAKE_AT, outline)

# Grass on the sand, as in Danyal's picture: not on a street, the road, the lake or anything standing.
func _grass() -> void:
	var grass := Grass.new()
	_the_grass = grass
	add_child(grass)
	var free_ground := func(x: float, z: float) -> bool:
		if _on_stone(x, z) or Vector2((x - LAKE_AT.x) / (LAKE_HALF.x + 2.0), (z - LAKE_AT.y) / (LAKE_HALF.y + 2.0)).length() < 1.0:
			return true
		if z >= NORTH - 8.0 and z <= NORTH + 1.0:
			return true    # under the wall's picture
		for p: Array in VILLAGE + ROADSIDE:
			if Vector2(p[1] - x, (p[2] - z) * 1.5).length() < 3.2:
				return true
		return false
	grass.strew(110, Rect2(-BOUND_X, -LENGTH / 2.0 + 2.0, BOUND_X * 2.0, NORTH + LENGTH / 2.0 - 4.0), 11, free_ground)
	grass.strew(150, Rect2(-SIDE_X + 2.0, NORTH + 2.0, (SIDE_X - 2.0) * 2.0, SOUTH - NORTH - 4.0), 12, free_ground)

func _process(delta: float) -> void:
	_time += delta
	var frame := int(_time * FOUNTAIN_FPS) % FOUNTAIN_FRAMES
	if frame != _fountain_frame:
		_fountain_frame = frame
		for s in _fountain:
			s.region_rect.position.x = fmod(s.region_rect.position.x, FOUNTAIN_W) + frame * FOUNTAIN_W

# He can walk behind a wall now: the piece he's behind opens a hole round him where he'd be hidden.
func _see_him_through_walls() -> void:
	var z := player.global_position.z
	var at := camera.unproject_position(player.global_position + Vector3.UP * 0.8)
	for h: Array in _holes:
		var behind: bool = z < h[1] and h[1] - z < h[5] and absf(player.global_position.x - h[2]) < h[3]
		var m: ShaderMaterial = h[0]
		if behind != h[4]:
			h[4] = behind
			m.set_shader_parameter(&"hole_r", HOLE if behind else 0.0)
		if behind:
			m.set_shader_parameter(&"hole_at", at)

func _see_through(s: Sprite3D, foot_z: float) -> void:
	var m := s.material_override as ShaderMaterial
	m.shader = WALL_SHADER
	_holes.append([m, foot_z, s.position.x, s.texture.get_width() / Pixel.PX / 2.0 + HOLE / Pixel.PX, false, s.texture.get_height() / 24.0 + HIDES_PAST])    # only the piece he's behind needs to know

# The jackals and scorpions are done with when the dark comes down.
func clear_desert() -> void:
	for f in _sleepers:
		if is_instance_valid(f):
			f.queue_free()
	_sleepers.clear()
	if is_instance_valid(_first):
		_first.queue_free()

func _scatter() -> void:
	for at in JACKALS:
		_sleepers.append(_jackal(Vector3(at.x, Hills.height_at(at.x, at.y), at.y)))
	for at in SCORPIONS:
		_sleepers.append(_foe("scorpion", "walk", "sting", 30.0, 1.3, Vector3(at.x, Hills.height_at(at.x, at.y), at.y), &"scorpion_sting", 2.4))

func _physics_process(_delta: float) -> void:
	if is_instance_valid(player) and camera:
		_see_him_through_walls()
	if ended or _busy or not is_instance_valid(player):
		_busy_tick = Engine.get_physics_frames()
		return
	if player.state == Elvis.State.ABILITY:
		return    # no story starts under a leap: it holds his collision mask at 0, and a scene would save that and give it back at its end, leaving him walking through everything
	if mood != mood_here():
		set_mood(mood_here(), scaled(AREA_FADE))
	var at := Vector2(player.global_position.x, player.global_position.z)
	var near := _nearest(at)
	if near != _hinted:
		_hinted = near
		if near:
			hud.pop_up(near, near.head_up(), "E: talk to %s" % near.who, "")
		else:
			hud.pop_down()
	if near:
		_say_hint("")
		if _e_pressed():
			_hinted = null
			hud.pop_down()
			_talk(near)
			return
	elif _reached:
		_say_hint("")
	elif not looted:
		if not _shied and is_instance_valid(_first) and at.distance_to(Vector2(_first.global_position.x, _first.global_position.z)) < SHY_AT:
			_shied = true
			_shy()
		if at.distance_to(TOMB_AT) < TOMB_REACH:
			_say_hint("")
			hud.pop_up(_tomb, 1.8, "E: open the tomb", "")
			if _e_pressed():
				hud.pop_down()
				loot()
		else:
			hud.pop_down()
			_say_hint("WASD or arrows: move. Something is at the tomb.")
	elif not Journey.has_weapon():
		_say_hint("I or Tab: open your things, and equip the sword")
	elif is_instance_valid(_first):
		_say_hint("Left click: attack, and lock on to what you click. Space: roll. Hold F to aim Hammer Blow, let go to leap. R: put the sword away.")
	elif not _raiders:
		_say_hint("1: drink to heal. Tab, again in the menu: Memory Paths and the map. The road runs south.")
	else:
		_say_hint("")
	if looted and not _scattered:
		_scattered = true
		_scatter()
	for f in _sleepers:
		if is_instance_valid(f) and f.mode == Jackal.Mode.SLEEP and f.global_position.distance_to(player.global_position) < AGGRO:
			f.wake(player)
	if not _raiders and looted and player.global_position.z > LAKE_FROM:
		_raiders = true
		LakeScene.run(self)
		return
	if not _reached and player.global_position.z > VILLAGE_AT:
		_arrive_village()

# The light of the stretch he's on, north to south. The story's scenes set their own while they play; this takes over when they end.
func mood_here() -> StringName:
	var z := player.global_position.z
	if z < GRAVES_TO:
		return &"grave"
	if z < LAKE_LIGHT:
		return &"clear"
	return &"lake" if z < NORTH else &"town"

func _say_hint(text: String) -> void:
	if text != _hint:
		_hint = text
		hud.hint(text)

# The legionary's tomb: the sword, the drachma and the hammer head that brings back The Hammer (STORY.md).
func loot() -> void:
	if looted:
		return
	looted = true
	_busy = true
	_say_hint("")
	Journey.add_item(&"iron_sword")
	Journey.add_item(&"hammer_head")
	Journey.drachma += 5
	if not _shied:    # it's out of the way of the scene, however he came
		_shied = true
		_shy()
	await TombScene.run(self)
	_busy = false
	if is_instance_valid(_first):
		_first.wake(player)

# He's coming: it backs off the tomb and watches him. It comes for him once he has opened it.
func _shy() -> void:
	_first.move_to(SHY_TO, Jackal.SPEED)
	await _first.arrived
	if is_instance_valid(_first) and is_instance_valid(player):
		var at_him := player.global_position - _first.global_position
		_first.facing = Vector2(at_him.x, at_him.z).normalized()

func _on_journey_changed() -> void:
	if not is_instance_valid(player):
		return
	player.wear_gear()
	if player.sprite.character != Journey.look():
		player.sprite.load_character(Journey.look())
	if player.has_weapon != Journey.has_weapon():
		player.set_weapon(Journey.has_weapon())

func _on_died() -> void:
	_busy = true
	menu.allowed = false
	await get_tree().create_timer(scaled(1.5)).timeout
	if not is_inside_tree():
		return
	hud.fade(true, scaled(0.6))
	await hud.fade_done
	player.reset_to(respawn_at)
	player.input_enabled = true
	hud.bind(player, null)
	hud.fade(false, scaled(0.6))
	menu.allowed = true
	_busy = false

func _arrive_village() -> void:
	_reached = true
	_say_hint("")
	hud.title_card("Cinerea", "")
	await get_tree().create_timer(scaled(2.5)).timeout
	if is_inside_tree():
		hud.title_card("", "")

# Not the press that ended a talk: it still reads as just pressed on the tick after, and would open another at once.
func _e_pressed() -> bool:
	return Input.is_action_just_pressed(&"confirm") and Engine.get_physics_frames() > _busy_tick + 2    # two ticks: no one presses twice that fast

func _nearest(at: Vector2) -> Townsperson:
	var best: Townsperson = null
	var reach := TALK_REACH
	for p in _people:
		var d := at.distance_to(Vector2(p.position.x, p.position.z))
		if p.shown() and d < reach and not (p == _cassia and p.walking()):    # her lines are for her stall, not the road there
			reach = d
			best = p
	return best

func _talk(person: Townsperson) -> void:
	_busy = true
	_say_hint("")
	player.input_enabled = false
	var to := player.global_position - person.position
	person.hold(Vector2(to.x, to.z).normalized())
	player.facing = -Vector2(to.x, to.z).normalized()
	player.sprite.play(player._look("idle"), player.facing)
	if person == _cassia:
		await Talks.play(hud, Talks.at_stall(int(Journey.trust.get(person.who, 0)), _open_shop), person.who)
	else:
		await Talks.play(hud, person.conversation(), person.who)
	if not is_inside_tree():
		return
	person.release()
	player.input_enabled = true
	_busy = false

func _open_shop(page: int) -> void:
	shop.open(page)
	await shop.closed

func _village(body: StaticBody3D) -> void:
	var floor_ := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = FLOOR.size
	floor_.mesh = plane
	floor_.material_override = _mat(_floor_tile("town"))
	floor_.position = Vector3(FLOOR.get_center().x, 0.012, FLOOR.get_center().y)
	add_child(floor_)
	for p: Array in VILLAGE:
		var prop := prop_sprite(p[0], p[1], p[2])
		add_child(prop)
		_block(body, prop, p[0], p[1], p[2])
		if FIRES.has(p[0]):
			var fire := OmniLight3D.new()    # no shadow, as an OmniLight3D starts
			fire.light_color = FxEffect.FIRE[2]
			fire.light_energy = FIRE_ENERGY
			fire.omni_range = FIRE_REACH
			fire.position = Vector3(p[1], Hills.height_at(p[1], p[2]), p[2]) + FIRES[p[0]]
			add_child(fire)
	_fountain_columns()
	_town_prism(body, FOUNTAIN_AT, FOUNTAIN_BASE)
	for p: Array in PEOPLE:
		var person := Townsperson.new()
		add_child(person)
		person.setup(p[0], p[1], Vector3(p[2], 0.0, p[3]), Vector3(p[4], 0.0, p[5]), p[6], PackedStringArray(p[7]))
		_people.append(person)
	_cassia = _waiting("cassia", "Cassia", CassiaScene.DOOR_AT)
	_cassia.bobs = false
	_fortuna = _waiting("fortuna", "Fortuna", CassiaScene.FORTUNA_FROM)
	_fortuna.first_talk = Talks.FORTUNA
	_fortuna.later = PackedStringArray(["She goes on chewing."])

# The fountain's picture, in columns.
func _fountain_columns() -> void:
	var whole := Arena.prop_sprite("fountain_anim", 0.0, 0.0)
	_fountain = columns(whole.texture, FOUNTAIN_W, FOUNTAIN_AT, preload("res://arena/prop_unshadowed.gdshader"))
	whole.position = Pixel.snap(Vector3(FOUNTAIN_AT.x, 0.0, FOUNTAIN_AT.y)) + Vector3(0.0, whole.texture.get_height() / Pixel.PX / 2.0 * whole.scale.y, 0.0)
	whole.hframes = FOUNTAIN_FRAMES
	whole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(whole)

# A picture `w` px wide standing at `at`, cut into columns. Each stands where its own part meets the ground, drawn just as low on screen as that puts it back, so the picture is unchanged but he's drawn in front of the parts he's in front of. They throw no shadow: something else must throw the whole picture's.
func columns(tex: Texture2D, w: int, at: Vector2, shader: Shader) -> Array[Sprite3D]:
	var out: Array[Sprite3D] = []
	var img := tex.get_image()
	var high := img.get_height()
	for sx in range(0, w, COLUMN):
		var lowest := -1
		for x in range(sx, sx + COLUMN):
			for y in range(high - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.5:
					lowest = maxi(lowest, y)
					break
		if lowest < 0:
			continue
		var back := float(high - 1 - lowest)    # px up the picture to where this column meets the ground
		var s := Arena.texture_sprite(tex, 0.0, 0.0)
		s.region_enabled = true
		s.region_rect = Rect2(sx, 0, COLUMN, high)
		s.position = Vector3(at.x + (sx + COLUMN / 2.0 - w / 2.0) / Pixel.PX, (high / 2.0 - back) / Pixel.PX * s.scale.y, at.y - back / 24.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF    # each would throw one on the next, in stripes
		(s.material_override as ShaderMaterial).shader = shader
		add_child(s)
		out.append(s)
	return out

# A rock, its picture cut into columns as the fountain's is, so he's in front of whichever part of its foot he's in front of. The same foot, all along it, is what stops him.
func _crag(body: StaticBody3D, c: Array) -> void:
	var whole := Arena.prop_sprite(c[0], c[1], c[2])
	var tex := whole.texture
	var img := tex.get_image()
	var high := img.get_height()
	var wide := img.get_width()
	var foot := PackedVector3Array()
	for corner: Vector2 in c[3]:
		foot.append(Vector3(c[1] + corner.x, 0.0, c[2] + corner.y))
		foot.append(Vector3(c[1] + corner.x, CRAG_TOP, c[2] + corner.y))
	for sx in range(0, wide, COLUMN):
		var lowest := -1
		for x in range(sx, mini(sx + COLUMN, wide)):
			for y in range(high - 1, -1, -1):
				if img.get_pixel(x, y).a > 0.5:
					lowest = maxi(lowest, y)
					break
		if lowest < 0:
			continue
		var back := float(high - 1 - lowest)
		var s := Arena.texture_sprite(tex, 0.0, 0.0)
		s.region_enabled = true
		s.region_rect = Rect2(sx, 0, mini(COLUMN, wide - sx), high)
		var at := Vector2(c[1] + (sx + s.region_rect.size.x / 2.0 - wide / 2.0) / Pixel.PX, c[2] - back / 24.0)
		s.position = Vector3(at.x, (high / 2.0 - back) / Pixel.PX * s.scale.y, at.y)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(s.material_override as ShaderMaterial).shader = preload("res://arena/prop_unshadowed.gdshader")
		add_child(s)
		foot.append(Vector3(at.x, 0.0, at.y))
		foot.append(Vector3(at.x, CRAG_TOP, at.y))
	whole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(whole)
	var solid := ConvexPolygonShape3D.new()
	solid.points = foot
	var shape := CollisionShape3D.new()
	shape.shape = solid
	body.add_child(shape)

# Someone who stays out of sight until Cassia's scene: only their picture hides, so the node keeps its place under physics interpolation.
func _waiting(folder: String, who: String, at: Vector3) -> Townsperson:
	var person := Townsperson.new()
	add_child(person)
	person.setup(folder, who, at, at, [], PackedStringArray())
	person.set_shown(false)
	_people.append(person)
	return person

func _raider_down() -> void:
	_raiders_left -= 1
	if _raiders_left == 0:
		CassiaScene.run(self)

# What stops him at a prop. A picture stands with its bottom edge at z and the object goes back from there. A house facing you is as deep as its roof shows, about half its height on screen; 24 px a metre that way, 32 across.
func _block(body: StaticBody3D, prop: Sprite3D, prop_name: String, x: float, z: float) -> void:
	if SLANTED.has(prop_name):
		var s: Array = SLANTED[prop_name]
		_town_box(body, Vector3(s[0], 2.0, s[1]), Vector3(x, 1.0, z - s[2]), s[3])
		return
	var size := footprint(prop_name, prop.texture)
	if size == Vector2.ZERO:
		return
	var at_x := x + foot_x(prop.texture) if prop_name in THIN else x
	var ground := Hills.height_at(x, z)
	_town_box(body, Vector3(size.x, 2.0 if ground == 0.0 else 6.0, size.y), Vector3(at_x, 1.0 + ground, z - size.y / 2.0))    # on a hill it has to meet him from up or down the slope

func cart_sprite() -> Sprite3D:
	return _cart

func cart_door() -> Sprite3D:
	return _cart_door

static func footprint(prop_name: String, tex: Texture2D) -> Vector2:
	if prop_name in WALK_OVER or tex == null:
		return Vector2.ZERO
	if prop_name in THIN:
		return THIN_SIZE
	var w := tex.get_width() * 0.92 / Pixel.PX
	if prop_name.begins_with("f_"):
		return Vector2(w, tex.get_height() * 0.55 / 24.0)
	return Vector2(w, DEEP.get(prop_name, maxf(tex.get_height() * 0.45 / 24.0, 0.4)))

# Where a picture meets the ground, in m from its middle: a lantern's post stands off to one side.
static func foot_x(tex: Texture2D) -> float:
	var img := tex.get_image()
	var bottom := img.get_used_rect().end.y - 1
	var left := img.get_width()
	var right := 0
	for y in range(bottom - 3, bottom + 1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				left = mini(left, x)
				right = maxi(right, x)
	return ((left + right + 1) / 2.0 - img.get_width() / 2.0) / Pixel.PX

# A solid with this outline on the ground, for what a box doesn't fit.
func _town_prism(body: StaticBody3D, at: Vector2, outline: Array[Vector2]) -> void:
	var points := PackedVector3Array()
	for p in outline:
		points.append(Vector3(p.x, 0.0, p.y))
		points.append(Vector3(p.x, 2.0, p.y))
	var solid := ConvexPolygonShape3D.new()
	solid.points = points
	var c := CollisionShape3D.new()
	c.shape = solid
	c.position = Vector3(at.x, 0.0, at.y)
	body.add_child(c)

func _town_box(body: StaticBody3D, size: Vector3, at: Vector3, yaw := 0.0) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var c := CollisionShape3D.new()
	c.shape = box
	c.position = at
	c.rotation.y = yaw
	body.add_child(c)

# The wall of eight sides: one long picture for each straight run so no join can show, 45 degree corners, the top of the wall east and west where the camera sees little face, towers at its corners, a gatehouse north and south.
func _town_walls(body: StaticBody3D) -> void:
	for z: float in [NORTH, SOUTH]:
		for run: Sprite3D in [_wall_run(GATEHOUSE_HALF - 0.5, FLAT_X, z), _wall_run(-FLAT_X, -GATEHOUSE_HALF + 0.5, z)]:
			add_child(run)
			_see_through(run, z)
		var gate := prop_sprite("gatehouse", 0.0, z + IN_FRONT)
		add_child(gate)
		_see_through(gate, z + IN_FRONT)
	var slices := roundi(CORNER / CORNER_SLICE)
	for i in slices:
		var along := (i + 0.5) * CORNER_SLICE
		var down := (i + 1.0) * CORNER_SLICE
		_corner_slice("wall_dr%d" % (i % 8), FLAT_X + along, NORTH + down)             # north-east
		_corner_slice("wall_dl%d" % (i % 8), -FLAT_X - along, NORTH + down)            # north-west
		_corner_slice("wall_dl%d" % (i % 8), SIDE_X - along, SOUTH - CORNER + down)    # south-east
		_corner_slice("wall_dr%d" % (i % 8), -SIDE_X + along, SOUTH - CORNER + down)   # south-west
	var z := NORTH + CORNER + 1.0
	while z <= SOUTH - CORNER + 0.01:
		var east := prop_sprite("wall_ve", SIDE_X, z)
		var west := prop_sprite("wall_vw", -SIDE_X, z)
		east.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		west.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(east)
		add_child(west)
		z += 1.0
	for corner: Vector2 in [Vector2(FLAT_X, NORTH), Vector2(SIDE_X, NORTH + CORNER), Vector2(SIDE_X, SOUTH - CORNER), Vector2(FLAT_X, SOUTH)]:
		for x: float in [corner.x, -corner.x]:
			var tower := prop_sprite("tower", x, corner.y + IN_FRONT)
			add_child(tower)
			_see_through(tower, corner.y + IN_FRONT)
	var deep := WALL_THICK + BEHIND_WALL    # the wall's picture stands north of its foot and would hide him there, so he is kept out
	for f: Array in GATE_FEET:
		var size := Vector3(f[1] - f[0], 4.0, deep - f[2])
		for side: float in [1.0, -1.0]:
			_town_box(body, size, Vector3(side * (f[0] + f[1]) / 2.0, 2.0, NORTH - f[2] - size.z / 2.0))
	_town_box(body, Vector3(FLAT_X * 2.0, 4.0, deep), Vector3(0.0, 2.0, SOUTH - deep / 2.0))    # its south gate stays shut until there's a road beyond it
	var side := Vector3(SIDE_REACH + WALL_THICK, 4.0, SOUTH - NORTH - CORNER * 2.0)
	_town_box(body, side, Vector3(SIDE_X - SIDE_REACH + side.x / 2.0, 2.0, (NORTH + SOUTH) / 2.0))
	_town_box(body, side, Vector3(-SIDE_X + SIDE_REACH - side.x / 2.0, 2.0, (NORTH + SOUTH) / 2.0))
	var run := Vector3(CORNER * sqrt(2.0), 4.0, WALL_THICK)
	var mid := FLAT_X + CORNER / 2.0
	for c: Array in [[mid, NORTH + CORNER / 2.0, -PI / 4.0], [-mid, NORTH + CORNER / 2.0, PI / 4.0], [mid, SOUTH - CORNER / 2.0, PI / 4.0], [-mid, SOUTH - CORNER / 2.0, -PI / 4.0]]:
		var north := Vector3(sin(c[2]), 0.0, cos(c[2])) * -BEHIND_WALL * cos(PI / 4.0) / 2.0
		_town_box(body, Vector3(run.x, 4.0, WALL_THICK + BEHIND_WALL * cos(PI / 4.0)), Vector3(c[0], 2.0, c[1]) + north, c[2])
		var shadow := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(run.x, 4.0, 0.3)
		shadow.mesh = mesh
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.position = Vector3(c[0], 2.0, c[1])
		shadow.rotation.y = c[2]
		add_child(shadow)

# A straight run of wall from x0 to x1, cut from the seamless strip as one picture.
func _wall_run(x0: float, x1: float, z: float) -> Sprite3D:
	var strip := Image.load_from_file("res://art/props/wall_strip.png")
	strip.convert(Image.FORMAT_RGBA8)
	var w := roundi((x1 - x0) * Pixel.PX)
	var img := Image.create(w, strip.get_height(), false, Image.FORMAT_RGBA8)
	var at := 0
	while at < w:
		img.blit_rect(strip, Rect2i(0, 0, mini(strip.get_width(), w - at), strip.get_height()), Vector2i(at, 0))
		at += strip.get_width()
	return texture_sprite(ImageTexture.create_from_image(img), (x0 + x1) / 2.0, z)

# One short slice of a corner. They'd each throw a shadow on the next, in stripes, so the corner throws one whole shadow instead.
func _corner_slice(pic: String, x: float, z: float) -> void:
	var s := prop_sprite(pic, x, z)
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	_see_through(s, z)

func _floor_tile(pic: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file("res://art/floors/%s.png" % pic))
