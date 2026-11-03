class_name FxIceVolley extends FxEffect
# Elvis's F from the press to the launch: the magic circle round him with its five small circles, a giant spear over each, then, on his sheet's snap frame, icicles out of the break into the spears, which shine; launch() sends them. It hits nothing itself. Stopped before the launch, it all breaks. Its sheet's "active" names the snap and the seal (art/tools/ice_snap_clips.py).
# Fx.spawn() makes it bare; follow() starts it.

const SPEARS := 5
const RING := 2.1          # m: the big circle's radius, and the small ones are on it. Clear of him, so the spears stand round him. Claude's call
const SMALL := 0.45        # m
const FIRST := 0.15        # s to the first small circle, then GAP to each of the others
const GAP := 0.12
const SPEAR_AFTER := 0.2   # s from a small circle to its spear
const STAND_AT := 5.1      # m up that a spear's tip is: its butt just over its circle
const SHARDS := "res://art/ice_spear/shards.png"
const EACH := 4            # icicles to a spear
const SHARD_GAP := 0.04    # s between them
const SHARD_TIME := 0.22   # s to reach it
const LAUNCH_GAP := 0.07   # s between the spears as they go
const BREAK := {"F": Vector2(1, 2), "S": Vector2(19, -5), "B": Vector2(-1, 0), "L": Vector2(-21, -5)}    # px from the middle of his frame, y down, to where his fists break it on the snap frame

static var _shard_sheet: Texture2D

var _who: Elvis
var _circles: Array[FxIceCircle] = []
var _spears: Array[FxIceSpear] = []
var _shards: Array[Dictionary] = []    # {"spr", "spear", "start"}
var _snap_frame := 0
var _seal_frame := 0
var _snapped_at := -1.0
var _launched := false
var _sealed := false
var _from := Vector3.ZERO    # the break

func _build() -> void:
	process_priority = 1
	life = 12.0
	if _shard_sheet == null:
		_shard_sheet = ImageTexture.create_from_image(Image.load_from_file(SHARDS))

# `who` has started the cast, and his sheet has too.
func follow(who: Elvis) -> void:
	_who = who
	var window := who.sprite.active_window(who.sprite.current_key)
	_snap_frame = window.x
	_seal_frame = window.y
	var big := Fx.spawn(&"ice_circle", global_position + Vector3.UP * 0.005) as FxIceCircle
	big.draw_out(3, RING, 0.05, FIRST)
	_circles.append(big)

# The spears go, one after another, for `target`; null: on along the way they first go.
func launch(target: Actor) -> void:
	_launched = true
	_shine_all()
	for i in _spears.size():
		_spears[i].launch(target, i * LAUNCH_GAP)
	for c in _circles:
		if is_instance_valid(c):
			c.fade()

func _on_ring(i: int) -> Vector3:
	var a := TAU * i / SPEARS - PI / 2.0
	return global_position + Vector3(cos(a), 0.0, sin(a)) * RING

func _step(_delta: float) -> void:
	if not is_instance_valid(_who) or _who.state != Elvis.State.CAST:
		if not _launched:
			for s in _spears:
				if is_instance_valid(s):
					s.shatter()
			for c in _circles:
				if is_instance_valid(c):
					c.fade()
		end()
		return
	while _circles.size() <= SPEARS and age >= FIRST + (_circles.size() - 1) * GAP:
		var c := Fx.spawn(&"ice_circle", _on_ring(_circles.size() - 1) + Vector3.UP * 0.01) as FxIceCircle
		c.draw_out(3, SMALL, 0.04, 0.1, -0.2)
		_circles.append(c)
	while _spears.size() < SPEARS and age >= FIRST + SPEAR_AFTER + _spears.size() * GAP:
		var s := Fx.spawn(&"ice_spear", _on_ring(_spears.size()) + Vector3.UP * STAND_AT, Vector3.ZERO, Hitbox.TEAM_PLAYER, _blow()) as FxIceSpear
		s.stands_for(_who, global_position.y)
		_spears.append(s)
	if _snapped_at < 0.0 and _who.sprite.frame >= _snap_frame:
		_snap()
	if not _sealed and _who.sprite.frame >= _seal_frame:
		_sealed = true    # frost closes the break: his spear is whole again
		Fx.spawn(&"ice_splash", _break_at())
		Feel.shake(1.0, 0.1)

func _break_at() -> Vector3:
	var px: Vector2 = BREAK[_view()]
	return _who.sprite.drawn_at() + Vector3(px.x, -px.y * Pixel.sprite_scale_y(), 0.0) / Pixel.PX

func _view() -> String:
	return _who.sprite.current_key.right(1)

func _blow() -> HitInfo:
	var a: Dictionary = Journey.ABILITIES[Elvis.ICE_SKILL]
	var hit := HitInfo.new()
	hit.damage = float(a["damage"]) / SPEARS
	hit.poise = hit.damage * Elvis.HEAVY_POISE    # as Hammer Blow's, over the five: but not `heavy`, or a spear would strike the crown
	hit.knockback = 1.0 * 1.0 / (2.0 * Actor.KNOCK_DECEL)    # 1 m/s: the shake of it. Claude's call
	hit.slow = float(a["slow"])
	hit.source = _who
	hit.at = _who.global_position
	return hit

func _snap() -> void:
	_snapped_at = age
	_from = _break_at()
	Fx.spawn(&"ice_splash", _from)
	Feel.shake(2.0, 0.15)
	for i in _spears.size():
		for j in EACH:
			var spr := _sprite_of(_shard_sheet, true)
			spr.hframes = FxIceSpear.ANGLES
			spr.visible = false
			_shards.append({"spr": spr, "spear": _spears[i], "start": _snapped_at + i * 0.02 + j * SHARD_GAP})

func _shine_all() -> void:
	for s in _spears:
		s.shine()

func _process(_delta: float) -> void:
	for d: Dictionary in _shards:
		var spr: Sprite3D = d["spr"]
		var spear = d["spear"]    # untyped: it may have been freed
		var x: float = (age - float(d["start"])) / SHARD_TIME
		spr.visible = x >= 0.0 and x < 1.0 and is_instance_valid(spear)
		if spr.visible:
			var to: Vector3 = spear.global_position + Vector3.DOWN * FxIceSpear.LENGTH * 0.5 / (Pixel.PX * cos(deg_to_rad(Pixel.PITCH_DEG)))    # its middle
			spr.global_position = snap3(_from.lerp(to, x))
			spr.frame = posmod(roundi(FxIceSpear.on_screen(to - _from).angle() / TAU * FxIceSpear.ANGLES), FxIceSpear.ANGLES)
		elif x >= 1.0 and is_instance_valid(spear):
			spear.shine()
