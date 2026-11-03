class_name FxIceSpear extends FxEffect
# One of Elvis's five giant ice spears, its look from art/tools/ice_spear.py. The node is at its tip, and so is the middle of every cell. It stands upright in frost over its small circle; shine() is the break's icicles reaching it; launch() sends it tracking its target with an icy trail; on a hit, or at the target if they can't be hit, it splashes.
# The hit's `info` comes from Fx.spawn(), so it carries the slow. fx/ice_volley.gd sets all this going.

const SHEET := "res://art/ice_spear/spears.png"
const ANGLES := 32
const LENGTH := 96.0       # px, tip to butt: art/tools/ice_spear.py
const UPRIGHT := 24        # the column pointing straight up the screen
const FROST := 0           # its rows
const SHINING := 1         # and the next
const FLASH := 3
const FORM := 0.2          # s to come up to full strength
const FADE_STEPS := 3.0    # in hard steps, like the rest of the pixel art
const FLASH_FOR := 0.06    # s white as the icicles reach it
const GLINT := 10.0        # shines swapped a second
const SPEED_FROM := 5.0    # m/s: it lifts off, then flies
const SPEED := 17.0        # m/s, so about a second across the arena. Claude's call
const ACCEL := 40.0
const TURN_FROM := 240.0   # deg/s, and it tightens as it flies, so it can't circle whoever it's after. Claude's call
const TURN_GAIN := 1200.0  # deg/s per second of flight
const FLY_MAX := 3.0       # s, then it splashes wherever it is
const CHEST := 0.7         # m up the target it goes for: in reach of a jackal's body and Vulcan's alike
const REACHED := 0.45      # m from there: they couldn't be hit (a roar), so it splashes without a blow
const RADIUS := 0.6        # m

static var _sheet: Texture2D

var _who: Elvis
var _target: Actor
var _way := Vector3.UP
var _speed := SPEED_FROM
var _flying := false
var _go_in := -1.0         # s until it goes; < 0 not told yet
var _flown := 0.0
var _floor := 0.0
var _lit_at := -1.0        # age it was lit
var _spr: Sprite3D

func _build() -> void:
	process_priority = 1
	life = 12.0    # its volley or its flight ends it
	if _sheet == null:
		_sheet = ImageTexture.create_from_image(Image.load_from_file(SHEET))
	_spr = _sprite_of(_sheet, true)
	_spr.material_override = FxHammerAura.behind_people(_sheet)
	_spr.hframes = ANGLES
	_spr.vframes = FLASH + 1
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	_hit(ball, Vector3.ZERO, 0.0, 0.0, false, 0.0)
	hitbox.landed.connect(_on_landed)

func stands_for(who: Elvis, ground: float) -> void:
	_who = who
	_floor = ground
	_process(0.0)

func shine() -> void:
	if _lit_at < 0.0:
		_lit_at = age

func launch(target: Actor, delay: float) -> void:
	shine()
	_target = target
	_go_in = delay

# His cast was stopped: it falls apart where it stands.
func shatter() -> void:
	_splash()

func _step(delta: float) -> void:
	if not is_instance_valid(_who):
		end()    # the scene went
	elif _go_in >= 0.0 and not _flying:
		_go_in -= delta
		if _go_in < 0.0:
			_flying = true
			var to := _aim() - global_position
			_way = (to.normalized() + Vector3.UP * 0.3).normalized()    # up off its circle, and round
			hitbox.activate(info, FLY_MAX)
			(Fx.spawn(&"ice_wake", global_position) as FxIceWake).follow(self)
	elif _flying:
		_fly(delta)

func _fly(delta: float) -> void:
	_flown += delta
	if _flown >= FLY_MAX:
		_splash()
		return
	_speed = move_toward(_speed, SPEED, ACCEL * delta)
	if not is_instance_valid(_target) or _target.health.ratio() <= 0.0:
		_target = _who.ice_target()    # the last one felled it: on to the next
	if _target:
		var to := _aim() - global_position
		if to.length() < REACHED:
			_splash()
			return
		var angle := _way.angle_to(to)
		var can := deg_to_rad(TURN_FROM + TURN_GAIN * _flown) * delta
		if angle > 0.001:
			_way = _way.slerp(to.normalized(), minf(can / angle, 1.0)).normalized()
	global_position += _way * _speed * delta

func _aim() -> Vector3:
	return _target.global_position + Vector3.UP * CHEST if is_instance_valid(_target) else global_position + _way

func _on_landed(_h: Hurtbox, _i: HitInfo) -> void:
	Feel.shake(1.5, 0.15)
	_splash()

func _splash() -> void:
	if is_queued_for_deletion():
		return
	Fx.spawn(&"ice_splash", global_position, _way if _flying else Vector3.ZERO)
	var ring := Fx.spawn(&"ice_circle", Vector3(global_position.x, _floor + 0.01, global_position.z)) as FxIceCircle
	ring.draw_out(2, 1.1, 0.22, 0.2, 0.0)
	ring.fade()
	end()

# Where its picture goes on screen for a way through the world, in px a metre.
static func on_screen(way: Vector3) -> Vector2:
	var pitch := deg_to_rad(Pixel.PITCH_DEG)
	return Vector2(way.x, way.z * sin(pitch) - way.y * cos(pitch)) * Pixel.PX

func _process(_delta: float) -> void:
	var col := UPRIGHT
	var row := FROST
	if _flying:
		col = posmod(roundi(on_screen(_way).angle() / TAU * ANGLES), ANGLES)
	if _lit_at >= 0.0:
		row = FLASH if age - _lit_at < FLASH_FOR else SHINING + int(age * GLINT) % 2
	_spr.frame = row * ANGLES + col
	_spr.modulate.a = minf((floorf(age / FORM * FADE_STEPS) + 1.0) / FADE_STEPS, 1.0)
	_spr.global_position = snap3(global_position)

# Where its aura comes off, whichever way it points: a screen px a metre differs with the way.
func butt() -> Vector3:
	return global_position - _way * LENGTH / maxf(on_screen(_way).length(), 8.0)
