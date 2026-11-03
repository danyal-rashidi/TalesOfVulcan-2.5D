class_name HitInfo extends RefCounted
# One blow, handed from a Hitbox to every Hurtbox it lands on.

var damage := 0.0
var poise := 0.0         # what it does to the target's poise; heavies are already x2 (Unreal BossVulcan.h HeavyPoiseScale)
var knockback := 0.0     # metres the target slides, braked at Actor.KNOCK_DECEL
var heavy := false
var source: Node3D
var at := Vector3.ZERO
var blast := false      # it pushes away from `at`, not from whoever struck
var slow := 0.0         # seconds it slows them for (Actor._chill)
