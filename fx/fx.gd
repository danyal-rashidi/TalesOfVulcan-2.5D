extends Node
# Autoload Fx: spawns the fight's effects and keeps them as its own children, so count() and clear_all() see every one.
# Each kind is a script here extending FxEffect. The hitting kinds hit `team`'s foes with `info`, or with the Unreal attack's own
# numbers when it is null; their `hitbox` is public, so a spawner can listen to `landed`.

const KINDS := {
	&"fire_blade": preload("res://fx/fire_blade.gd"),
	&"fireball": preload("res://fx/fireball.gd"),
	&"spell_circle": preload("res://fx/spell_circle.gd"),
	&"breath": preload("res://fx/breath.gd"),
	&"dive_impact": preload("res://fx/dive_impact.gd"),
	&"lightning": preload("res://fx/lightning.gd"),
	&"statue_burst": preload("res://fx/statue_burst.gd"),
	&"flame_summon": preload("res://fx/flame_summon.gd"),
	&"crown_glow": preload("res://fx/crown_glow.gd"),
	&"crown_light": preload("res://fx/crown_light.gd"),
	&"ash": preload("res://fx/ash.gd"),
	&"sparks": preload("res://fx/sparks.gd"),
	&"dust": preload("res://fx/dust.gd"),
	&"embers": preload("res://fx/embers.gd"),
	&"telegraph": preload("res://fx/telegraph.gd"),    # Vulcan's wind-up marks: bare until FxTelegraph.mark()
}

func spawn(kind: StringName, at: Vector3, dir := Vector3.ZERO, team := Hitbox.TEAM_BOSS, info: HitInfo = null) -> Node3D:
	if not KINDS.has(kind):
		push_warning("Fx: no effect called %s" % kind)
		return null
	var script: GDScript = KINDS[kind]
	var e: FxEffect = script.new()
	e.position = at
	if dir.length() > 0.001:
		e.dir = dir.normalized()
	e.team = team
	e.info = info
	add_child(e)
	return e

func clear_all() -> void:
	for c in get_children():
		(c as FxEffect).end()

func count() -> int:
	var n := 0
	for c in get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n
